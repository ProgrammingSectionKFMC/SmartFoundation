param([Parameter(Mandatory=$true)][string]$SqlFile)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Data
$cfg=Get-Content -Raw -LiteralPath C:/Projects/SmartFoundation/SmartFoundation.Mvc/appsettings.json | ConvertFrom-Json
$b=[System.Data.SqlClient.SqlConnectionStringBuilder]::new([string]$cfg.ConnectionStrings.Default)
$b['Initial Catalog']='DATACORE'
$b['Connect Timeout']=10
$cn=[System.Data.SqlClient.SqlConnection]::new($b.ConnectionString)
try {
 $cn.Open(); $cmd=$cn.CreateCommand();$cmd.CommandTimeout=180
 $cmd.CommandText=[System.IO.File]::ReadAllText($SqlFile)
 $rd=$cmd.ExecuteReader(); $result=0
 do { $result++; $rows=0; while($rd.Read()){ $rows++; if($rows -le 20){ $item=[ordered]@{ResultSet=$result};for($i=0;$i -lt $rd.FieldCount;$i++){ $item[$rd.GetName($i)]=$rd.GetValue($i) };[pscustomobject]$item | ConvertTo-Json -Compress }; }; if($rows -gt 20){Write-Output "ResultSet=$result Rows=$rows (first 20 shown)"} }while($rd.NextResult())
 $rd.Close()
} catch { if($_.Exception.InnerException -is [System.Data.SqlClient.SqlException]){ $e=$_.Exception.InnerException; Write-Output "SQL error $($e.Number), line $($e.LineNumber): $($e.Message)" }else{Write-Output $_.Exception.Message}; exit 1 } finally { $cn.Dispose() }
