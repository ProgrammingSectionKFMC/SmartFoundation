param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '../SmartFoundation.Mvc/appsettings.json')
)

# Executes the production query/guard text against session-local fixture tables.
# No permanent objects, resident records, or bills are written.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$functionSql = Get-Content (Join-Path $repo 'SmartFoundation.Database/Housing/Functions/fn_BuildingOccupancyPeriods.sql') -Raw
$queryStart = $functionSql.IndexOf('WITH OccupancyChain AS')
$periodQuery = $functionSql.Substring($queryStart, $functionSql.LastIndexOf(');') - $queryStart)
$periodQuery = $periodQuery.Replace('Housing.BuildingAction', '#Actions').Replace(
    'FROM OccupancyChain occupancy', 'INTO #Periods FROM OccupancyChain occupancy')
$periodQuery += ' OPTION (MAXRECURSION 32767);'

$exitSql = Get-Content (Join-Path $repo 'SmartFoundation.Database/Housing/Stored Procedures/HousingExitSP.sql') -Raw
$guardStart = $exitSql.IndexOf('-- Keep physical vacancy independent')
$guardEnd = $exitSql.IndexOf("IF @Action IN(N'HOUSINGEXIT',N'EditExtend'", $guardStart)
if ($queryStart -lt 0 -or $guardStart -lt 0 -or $guardEnd -lt 0) { throw 'Production test markers not found.' }
$guard = $exitSql.Substring($guardStart, $guardEnd - $guardStart)
$guard = $guard.Replace('Housing.BuildingAction', '#Actions').Replace(
    'Housing.fn_BuildingAction_ChainToRoot(TRY_CONVERT(BIGINT, @LastActionID))', '#History').Replace(
    'Housing.fn_BuildingOccupancyPeriods(@BuildingDetailsID_BIGINT, @IdaraID_INT)', '#Periods')

$residentSql = Get-Content (Join-Path $repo 'SmartFoundation.Database/Housing/Stored Procedures/HousingResidentSP.sql') -Raw
$overlapStart = $residentSql.IndexOf(';WITH PreviousOccupancies AS')
$overlapEnd = $residentSql.IndexOf('SELECT TOP (1)', $overlapStart)
$overlapQuery = $residentSql.Substring($overlapStart, $overlapEnd - $overlapStart).Replace(
    'Housing.fn_BuildingOccupancyPeriods(TRY_CONVERT(BIGINT, @buildingDetailsID), @IdaraID_INT)', '#Periods')
$overlapQuery += 'SELECT @ConflictCount = COUNT(*) FROM PreviousOccupancies;'

$setup = @'
SET NOCOUNT ON;
CREATE TABLE #Actions
(
    buildingActionID BIGINT, buildingActionParentID BIGINT NULL,
    buildingActionTypeID_FK INT, residentInfoID_FK BIGINT,
    buildingDetailsID_FK BIGINT, IdaraId_FK BIGINT, buildingActionActive BIT,
    OccupentDate DATETIME NULL, ExitDate DATETIME NULL,
    buildingActionDate DATETIME NULL, entryDate DATETIME NULL
);
INSERT #Actions VALUES (1,NULL,2,485,-1629,-1,1,'20210131',NULL,'20210131','20210131');
DECLARE @BuildingDetailsID BIGINT = -1629, @IdaraID BIGINT = -1;
DECLARE @Action NVARCHAR(200) = @TestAction, @LastActionID NVARCHAR(100) = @TestLastActionID;
DECLARE @IdaraID_INT INT = -1, @BuildingDetailsID_BIGINT BIGINT = -1629, @ResidentInfoID_BIGINT BIGINT = 485;
DECLARE @ExitDate_DATE DATE = @TestExitDate, @ExitDate NVARCHAR(1000) = @TestExitDate;
DECLARE @OccupentDate_DATE DATE = '20210131', @OccupentDate NVARCHAR(1000) = '2021-01-31';
DECLARE @residentInfoID NVARCHAR(100) = '874';
DECLARE @OccupentDateValue DATE = @TestMoveInDate, @ConflictCount INT;
'@

$historyQuery = @'
;WITH Ancestors AS
(
    SELECT *, 0 AS Depth FROM #Actions WHERE buildingActionID = TRY_CONVERT(BIGINT, @LastActionID)
    UNION ALL
    SELECT parent.*, child.Depth + 1 FROM Ancestors child
    JOIN #Actions parent ON parent.buildingActionID = child.buildingActionParentID
    WHERE child.Depth < 100
)
SELECT *, -Depth AS Lvl INTO #History FROM Ancestors OPTION(MAXRECURSION 32767);
'@

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$connection = [System.Data.SqlClient.SqlConnection]::new($config.ConnectionStrings.Default)
$connection.Open()
$script:passed = 0
function Test-Case {
    param([string]$Name, [string]$Rows, [string]$Assert, [string]$Action = '',
          [int]$LastActionID = 2, [string]$ExitDate = '2023-09-21',
          [string]$MoveInDate = '2023-09-22', [string]$ExpectedError = '')
    $transaction = $connection.BeginTransaction()
    try {
        $command = $connection.CreateCommand()
        $command.Transaction = $transaction
        $command.CommandTimeout = 20
        $command.CommandText = $setup + "`n" + $Rows + "`n" + $periodQuery + "`n" + $historyQuery
        if ($Action) { $command.CommandText += "`n" + $guard }
        $command.CommandText += "`n" + $overlapQuery + "`n" + $Assert
        [void]$command.Parameters.AddWithValue('@TestAction', $Action)
        [void]$command.Parameters.AddWithValue('@TestLastActionID', $LastActionID.ToString())
        [void]$command.Parameters.AddWithValue('@TestExitDate', $ExitDate)
        [void]$command.Parameters.AddWithValue('@TestMoveInDate', $MoveInDate)
        try {
            [void]$command.ExecuteNonQuery()
            if ($ExpectedError) { throw "Expected business rejection: $ExpectedError" }
        }
        catch [System.Data.SqlClient.SqlException] {
            if (-not $ExpectedError -or $_.Exception.Number -ne 50001 -or
                -not $_.Exception.Message.Contains($ExpectedError)) { throw }
        }
        $script:passed++
        Write-Output "PASS: $Name"
    }
    finally { $transaction.Rollback() }
}

$requested = "INSERT #Actions VALUES (2,1,54,485,-1629,-1,1,'20210131','20230921','20230921','20230921');"
$migrated = $requested.Replace(',54,', ',57,')
$next = "INSERT #Actions VALUES (10,NULL,2,999,-1629,-1,1,'20231001',NULL,'20231001','20231001');"
try {
    Test-Case 'No exit remains occupied' '' "IF @ConflictCount <> 1 THROW 51000,'Expected occupied',1;"
    Test-Case 'Physical exit frees next day before finance' $requested "IF @ConflictCount <> 0 THROW 51000,'Expected vacant',1;"
    Test-Case 'Exit day is still occupied' $requested "IF @ConflictCount <> 1 THROW 51000,'Expected same-day conflict',1;" -MoveInDate '2023-09-21'
    Test-Case 'Migrated finance-only exit frees next day' $migrated "IF @ConflictCount <> 0 THROW 51000,'Expected migrated exit',1;"
    Test-Case 'Missing financial exit date does not free house' ($migrated.Replace("'20230921','20230921','20230921'", "NULL,'20230921','20230921'")) "IF @ConflictCount <> 1 THROW 51000,'Missing physical date',1;"
    Test-Case 'Indirect edit supersedes original date' ($requested + "INSERT #Actions VALUES (3,2,56,485,-1629,-1,1,'20210131','20230925','20230925','20230925');") "IF (SELECT ExitDate FROM #Periods WHERE OccupancyActionID=1) <> '20230925' THROW 51000,'Expected edited date',1;"
    Test-Case 'Finance carried date cannot undo explicit edit' ($requested + "INSERT #Actions VALUES (3,2,56,485,-1629,-1,1,'20210131','20230925','20230925','20230925'),(4,3,57,485,-1629,-1,1,'20210131','20230921','20230926','20230926');") "IF (SELECT ExitDate FROM #Periods WHERE OccupancyActionID=1) <> '20230925' THROW 51000,'Finance overwrote edit',1;"
    Test-Case 'Cancellation restores occupancy' ($requested + "INSERT #Actions VALUES (3,2,55,485,-1629,-1,1,'20210131','20230921','20230921','20230921'),(4,3,2,485,-1629,-1,1,'20210131',NULL,'20210131','20230921');") "IF EXISTS(SELECT 1 FROM #Periods WHERE ExitDate IS NOT NULL) THROW 51000,'Cancelled exit accepted',1;"
    Test-Case 'New exit after cancellation closes restored period' ($requested + "INSERT #Actions VALUES (3,2,55,485,-1629,-1,1,'20210131','20230921','20230921','20230921'),(4,3,2,485,-1629,-1,1,'20210131',NULL,'20210131','20230921'),(5,4,54,485,-1629,-1,1,'20210131','20230925','20230925','20230925');") "IF EXISTS(SELECT 1 FROM #Periods WHERE ExitDate IS NULL OR ExitDate <> '20230925') THROW 51000,'Restored period not closed',1;"
    Test-Case 'Inactive exit is ignored' ($requested.Replace(',-1,1,', ',-1,0,')) "IF @ConflictCount <> 1 THROW 51000,'Inactive exit accepted',1;"
    Test-Case 'Other administration is isolated' ($requested.Replace(',-1,1,', ',-2,1,')) "IF @ConflictCount <> 1 THROW 51000,'Wrong administration accepted',1;"
    Test-Case 'Other house is isolated' ($requested.Replace(',-1629,', ',-1630,')) "IF @ConflictCount <> 1 THROW 51000,'Wrong house accepted',1;"
    Test-Case 'Other resident exit is isolated' ($requested.Replace(',485,', ',777,')) "IF @ConflictCount <> 1 THROW 51000,'Wrong resident accepted',1;"
    Test-Case 'Different period of same resident stays open' ($requested + "INSERT #Actions VALUES (3,2,2,485,-1629,-1,1,'20240101',NULL,'20240101','20240101');") "IF (SELECT ExitDate FROM #Periods WHERE OccupancyActionID=1) <> '20230921' OR EXISTS(SELECT 1 FROM #Periods WHERE OccupancyActionID=3 AND ExitDate IS NOT NULL) THROW 51000,'Periods mixed',1;"
    Test-Case 'Extended occupancy links back to original stay' ("INSERT #Actions VALUES (2,1,24,485,-1629,-1,1,'20210131',NULL,'20220101','20220101'),(3,2,54,485,-1629,-1,1,'20210131','20230921','20230921','20230921');") "IF @ConflictCount <> 0 THROW 51000,'Extension hid exit',1;"
    Test-Case 'Cycle terminates without losing exit' ($requested + 'UPDATE #Actions SET buildingActionParentID=2 WHERE buildingActionID=1;') "IF @ConflictCount <> 0 THROW 51000,'Cycle hid exit',1;"
    Test-Case 'Future occupancy is checked on requested date' ($requested + $next.Replace('20231001','20990101')) "IF @ConflictCount <> 1 THROW 51000,'Future overlap missed',1;" -MoveInDate '2099-01-01'
    Test-Case 'Later occupancy still blocks historical request' ($requested + $next) "IF @ConflictCount <> 1 THROW 51000,'Later occupancy missed',1;"
    Test-Case 'Edit to day before next occupancy allowed' ($requested + $next) '' -Action 'EDITHOUSINGEXIT' -ExitDate '2023-09-30'
    Test-Case 'Edit to same day rejected' ($requested + $next) '' -Action 'EDITHOUSINGEXIT' -ExitDate '2023-10-01' -ExpectedError 'يجب أن يكون قبل'
    Test-Case 'Edit beyond next occupancy rejected' ($requested + $next) '' -Action 'EDITHOUSINGEXIT' -ExitDate '2023-10-02' -ExpectedError 'يجب أن يكون قبل'
    Test-Case 'Edit before original occupancy rejected' $requested '' -Action 'EDITHOUSINGEXIT' -ExitDate '2021-01-30' -ExpectedError 'يسبق تاريخ التسكين'
    Test-Case 'Malformed date rejected' $requested '' -Action 'EDITHOUSINGEXIT' -ExitDate '' -ExpectedError 'تاريخ الإخلاء غير صحيح'
    Test-Case 'Cancellation without later occupancy allowed' $requested '' -Action 'CANCELHOUSINGEXIT'
    Test-Case 'Cancellation after later occupancy rejected' ($requested + $next) '' -Action 'CANCELHOUSINGEXIT' -ExpectedError 'لا يمكن إلغاء الإخلاء'
    Test-Case 'Later resident exit does not permit cancellation' ($requested + $next + "INSERT #Actions VALUES (11,10,3,999,-1629,-1,1,'20231001','20241001','20241001','20241001');") '' -Action 'CANCELHOUSINGEXIT' -ExpectedError 'لا يمكن إلغاء الإخلاء'
    Test-Case 'Inactive later occupancy does not block cancellation' ($requested + $next.Replace(',-1,1,', ',-1,0,')) '' -Action 'CANCELHOUSINGEXIT'
    Test-Case 'Final approval carries server date not posted date' ($migrated + $next) "IF @ExitDate_DATE <> '20230921' THROW 51000,'Posted hidden date used',1;" -Action 'APPROVEHOUSINGEXIT' -ExitDate '2025-01-01'
    Test-Case 'Stale exit form rejected' ($requested + "INSERT #Actions VALUES (3,2,56,485,-1629,-1,1,'20210131','20230925','20230925','20230925');") '' -Action 'EDITHOUSINGEXIT' -ExpectedError 'تغيرت حالة طلب الإخلاء'
    Test-Case 'Later period of same resident is protected' ($requested + $next.Replace(',999,', ',485,')) '' -Action 'CANCELHOUSINGEXIT' -ExpectedError 'لا يمكن إلغاء الإخلاء'

    # Exercise the actual shared lock blocks on separate connections. The second
    # operation must be refused while the first holds the building transaction.
    $lockStart = $residentSql.IndexOf('DECLARE @OccupancyLockResult INT;')
    $lockEnd = $residentSql.IndexOf('IF (SELECT COUNT(*)', $lockStart)
    $residentLock = $residentSql.Substring($lockStart, $lockEnd - $lockStart).Replace('@LockTimeout = 10000', '@LockTimeout = 0')
    $exitLockStart = $guard.IndexOf('DECLARE @OccupancyLockResult INT;')
    $exitLockEnd = $guard.IndexOf('-- Reject stale', $exitLockStart)
    $exitLock = $guard.Substring($exitLockStart, $exitLockEnd - $exitLockStart).Replace('@LockTimeout = 10000', '@LockTimeout = 0')
    $otherConnection = [System.Data.SqlClient.SqlConnection]::new($config.ConnectionStrings.Default)
    $otherConnection.Open()
    $firstTransaction = $connection.BeginTransaction()
    $secondTransaction = $otherConnection.BeginTransaction()
    try {
        $firstCommand = $connection.CreateCommand()
        $firstCommand.Transaction = $firstTransaction
        $firstCommand.CommandText = 'DECLARE @IdaraID_INT INT=-1,@buildingDetailsID BIGINT=-1629;' + $residentLock
        [void]$firstCommand.ExecuteNonQuery()
        $secondCommand = $otherConnection.CreateCommand()
        $secondCommand.Transaction = $secondTransaction
        $secondCommand.CommandText = 'DECLARE @IdaraID_INT INT=-1,@BuildingDetailsID_BIGINT BIGINT=-1629;' + $exitLock
        try {
            [void]$secondCommand.ExecuteNonQuery()
            throw 'Concurrent exit was not blocked by occupancy transaction.'
        }
        catch [System.Data.SqlClient.SqlException] {
            if ($_.Exception.Number -ne 50001 -or -not $_.Exception.Message.Contains('تجري معالجة أخرى')) { throw }
        }
        $firstTransaction.Rollback()
        $firstTransaction = $null
        [void]$secondCommand.ExecuteNonQuery()
        $script:passed++
        Write-Output 'PASS: Occupancy and exit serialize until transaction completes'
    }
    finally {
        if ($firstTransaction) { $firstTransaction.Rollback() }
        $secondTransaction.Rollback()
        $otherConnection.Dispose()
    }
    Write-Output "Passed $script:passed housing occupancy regression cases. All fixture transactions rolled back."
}
finally { $connection.Dispose() }
