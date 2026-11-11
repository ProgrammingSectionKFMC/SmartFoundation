$ErrorActionPreference='Stop'
$dir='C:/Projects/SmartFoundation/.backups/validate-migration-20261107-210353'
Add-Type -AssemblyName System.Data
$cfg=Get-Content -Raw -LiteralPath C:/Projects/SmartFoundation/SmartFoundation.Mvc/appsettings.json | ConvertFrom-Json
$b=[System.Data.SqlClient.SqlConnectionStringBuilder]::new([string]$cfg.ConnectionStrings.Default)
$b['Initial Catalog']='DATACORE';$b['Connect Timeout']=10
function Read-Sql([string]$sql){
 $cn=[System.Data.SqlClient.SqlConnection]::new($b.ConnectionString)
 try{$cn.Open();$cmd=$cn.CreateCommand();$cmd.CommandTimeout=240;$cmd.CommandText=$sql;$rd=$cmd.ExecuteReader();$sets=[System.Collections.Generic.List[object]]::new();do{$rows=[System.Collections.Generic.List[object]]::new();while($rd.Read()){$r=[ordered]@{};for($i=0;$i -lt $rd.FieldCount;$i++){$r[$rd.GetName($i)]=$rd.GetValue($i)};$rows.Add([pscustomobject]$r)};$sets.Add($rows.ToArray())}while($rd.NextResult());$rd.Close();return ,$sets}finally{$cn.Dispose()}
}
try{
 # Compare-and-swap: never overwrite a concurrent change to either live procedure.
 $cn=[System.Data.SqlClient.SqlConnection]::new($b.ConnectionString)
 try{
  $cn.Open();$tx=$cn.BeginTransaction();$cmd=$cn.CreateCommand();$cmd.Transaction=$tx;$cmd.CommandTimeout=240
  $cmd.CommandText="SELECT o.name,m.definition FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id JOIN sys.sql_modules m ON m.object_id=o.object_id WHERE s.name=N'MoveData' AND o.name IN(N'usp_ValidateMigration',N'usp_MigrateBuildingActions');"
  $rd=$cmd.ExecuteReader();$seen=0;while($rd.Read()){$seen++;$name=$rd.GetString(0);if($rd.GetString(1) -cne [IO.File]::ReadAllText("$dir/$name.before.sql")){throw 'Concurrent live definition change; no ALTER.'}};$rd.Close();if($seen -ne 2){throw 'Missing procedure; no ALTER.'}
  $candidate=[IO.File]::ReadAllText("$dir/usp_ValidateMigration.corrected.sql")
  if($candidate -notmatch '^ALTER PROCEDURE \[MoveData\]\.\[usp_ValidateMigration\]'){throw 'Unexpected ALTER target.'}
  $cmd.CommandText=$candidate;[void]$cmd.ExecuteNonQuery()
  $cmd.CommandText="SELECT OBJECT_DEFINITION(OBJECT_ID(N'MoveData.usp_ValidateMigration'));"
  $readback=[string]$cmd.ExecuteScalar()
  [IO.File]::WriteAllText("$dir/usp_ValidateMigration.after.sql",$readback)
  function Normalize-Definition([string]$value){ return (($value -replace '^\s*(CREATE(\s+OR\s+ALTER)?|ALTER)\s+PROCEDURE','PROCEDURE') -replace "`r`n","`n").TrimEnd() }
  $expectedText=Normalize-Definition $candidate; $actualText=Normalize-Definition $readback
  if($actualText -cne $expectedText){
   $position=0;while($position -lt [Math]::Min($actualText.Length,$expectedText.Length) -and $actualText[$position] -ceq $expectedText[$position]){$position++}
   Write-Output "Definition mismatch position=$position expectedLength=$($expectedText.Length) actualLength=$($actualText.Length)"
   throw 'Post-ALTER definition mismatch; rolled back.'
  }
  $tx.Commit();Write-Output 'ALTER_SUCCESS: MoveData.usp_ValidateMigration; definition readback verified.'
  $results=Read-Sql 'EXEC MoveData.usp_ValidateMigration @IdaraId=1;'
  $allChecks=@(foreach($set in $results){foreach($row in $set){if($row.PSObject.Properties['CheckName']){$row}}})
  $fail=@($allChecks | Where-Object Result -eq 'FAIL')
  [IO.File]::WriteAllText("$dir/validation-test-results.json",($allChecks | ConvertTo-Json -Depth 6))
  Write-Output ('InstalledValidator: checks='+$allChecks.Count+' FAIL='+$fail.Count)
  foreach($row in $allChecks){if($row.Result -eq 'FAIL' -or $row.CheckName -like 'Building actions*' -or $row.Category -eq 'Building actions'){[pscustomobject]@{Category=$row.Category;CheckName=$row.CheckName;Expected=$row.ExpectedValue;Actual=$row.ActualValue;Result=$row.Result} | ConvertTo-Json -Compress}}
 }catch{if($tx){try{$tx.Rollback()}catch{}};throw}finally{$cn.Dispose()}
}catch{if($_.Exception.InnerException -is [System.Data.SqlClient.SqlException]){$e=$_.Exception.InnerException;Write-Output "SQL error $($e.Number), line $($e.LineNumber): $($e.Message)"}else{Write-Output $_.Exception.Message};exit 1}
