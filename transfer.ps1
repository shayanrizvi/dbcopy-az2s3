Start-Transcript "C:\transfer\transfer_log.txt"
write-output "Executing line 2"
$ErrorActionPreference = "STOP"
$WarningPreference = 'SilentlyContinue'
write-output "Executing line 5"
Set-PSRepository "PSGallery" -InstallationPolicy Trusted
install-module aws.tools.common
import-module aws.tools.common
install-module aws.tools.s3
import-module aws.tools.s3
write-output "Executing line 11"
$credential = Get-Content -Path C:\transfer\credential.json | ConvertFrom-Json
$password = ConvertTo-SecureString $credential.Password -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PScredential($credential.AppId, $password)
$accesskey = "accesskey"
$secretkey = "secretkey"
$bucketname = "bucketname"
write-output "Executing line 18"
Connect-AzAccount -ServicePrincipal -credential $pscredential -Tenant $credential.TenantId
write-output "Executing line 20"
$currenttime = Get-Date -AsUTC
$starttime = $currenttime
$restoretime = $currenttime
$printtime = Get-Date -AsUTC -Format "yyyy-MM-ddTHH-mmZ"
$year = ($currenttime).Year
$month = ($currenttime).Month
$day = ($currenttime).Day
$hour = ($currenttime).Hour
write-output "Executing line 29"
if ($hour -ge 7 -And $hour -lt 18) {
	write-output "Executing line 31"
	write-output "Hours: 7 - 17"
	$printtime = [string]$year + "-" + [string]$month + "-" + [string]$day + "T07-00Z"
	$restoretime = Get-Date -Year $year -Month $month -Day $day -Hour "07" -Minute "00" -Second "00"
	<#
	if ($currenttime.IsDaylightSavingTime()) {
		$restoretime  = Get-Date -Hour "07" -Minute "00" -Second "00"
		} else {
			$restoretime  = Get-Date -Hour "07" -Minute "00" -Second "00"
		}
	#>
} elseif ($hour -ge 18) {
	write-output "Executing line 43"
	write-output "Hours: 18 - 23"
	$printtime = [string]$year + "-" + [string]$month + "-" + [string]$day + "T18-00Z"
	$restoretime  = Get-Date -Year $year -Month $month -Day $day -Hour "18" -Minute "00" -Second "00"
	<#
	if ($currenttime.IsDaylightSavingTime()) {
		$restoretime  = Get-Date -Hour "18" -Minute "00" -Second "00"
		} else {
			$restoretime  = Get-Date -Hour "18" -Minute "00" -Second "00"
		}
	#>
} else {
	write-output "Executing line 55"
	write-output "Hours: 0 - 6"
	if ($day -eq 1) {
		if($month -eq 1) {
			$month = 12
			$year = $year - 1
		} else {
			$month = $month - 1
		}
		$day = [DateTime]::DaysInMonth($year, $month)
	} else {
		$day = $day -1
	}
	$printtime = [string]$year + "-" + [string]$month + "-" + [string]$day + "T18-00Z"
	$restoretime  = Get-Date -Year $year -Month $month -Day $day -Hour "18" -Minute "00" -Second "00"
	<#
	if ($currenttime.IsDaylightSavingTime()) {
		$restoretime  = Get-Date -Hour "18" -Minute "00" -Second "00"
		} else {
			$restoretime  = Get-Date -Hour "18" -Minute "00" -Second "00"
		}
	#>
}
write-output "Executing line 78"
$resourcegroup = "resourcegroup"
$server = "server"
$sourcedatabase = "sourcedatabase"
$newdbName = $sourcedatabase + "-" + $printtime
$bacpac = $newdbName + ".bacpac"
$filepath = "C:\transfer\" + $bacpac
$subject = "TRANSFER FAILED - " + $newdbName
write-output "Executing line 86"
start-sleep 3
write-output "Executing line 88"
write-output "`n - TRANSFER COMMENCING - `n"
write-output "`n - START TIME - `n" $starttime
write-output "`n - RESTORE TIME - `n" $restoretime

write-output "Executing line 93"

<#restore#>

$currenttime = Get-Date -AsUTC -Format "yyyy-MM-ddTHH-mmZ"
write-output "`n - RESTORE COMMENCING - `n"

try {
	$pointintime = [DateTime]::SpecifyKind($restoretime,[DateTimeKind]::Utc)
	$Database = Get-AzSqlDatabase -ResourceGroupName $resourcegroup -ServerName $server -DatabaseName $sourcedatabase
	Restore-AzSqlDatabase -FromPointInTimeBackup -PointInTime $pointintime -ResourceGroupName $resourcegroup -ServerName $Database.ServerName -TargetDatabaseName $newdbName -ResourceId $Database.ResourceID
	$currenttime = Get-Date -AsUTC -Format "yyyy-MM-ddTHH-mmZ"
	write-output "`n - RESTORE COMPLETE - `n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - "
	write-host $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds
} catch {
    "`n***************** RESTORE ERROR *****************`n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - "
	write-host $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds
	$transcript = Get-Content C:\transfer\export_log.txt | out-string
	Send-MailMessage -To “transfer@service.com” -From “transfer@service.com”  -Subject $subject -Body $transcript -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}

write-output "Executing line 122"

<#export#>

write-output "`n - EXPORT COMMENCING - `n"

try {
	$exportCommand = '"C:\Program Files\Microsoft SQL Server\150\DAC\bin\sqlpackage.exe" /a:Export /tf:' + $bacpac + ' /scs:"Data Source=sqlserver.database.windows.net;Initial Catalog=' + $newdbName + ';User ID=transferservice;Password=transferservicepw"'
	cmd.exe /c $exportCommand
	$currenttime = Get-Date -AsUTC -Format "yyyy-MM-ddTHH-mmZ"
	write-output "`n - EXPORT COMPLETE - `n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - "
	write-host $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds
} catch {
    "`n***************** EXPORT ERROR *****************`n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - "
	write-host $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds
	$transcript = Get-Content C:\transfer\export_log.txt | out-string
	Send-MailMessage -To “transfer@service.com” -From “transfer@service.com”  -Subject $subject -Body $transcript -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}

write-output "Executing line 149"

<#upload#>

write-output "`n - UPLOAD COMMENCING - `n"

try {
	Set-AWSCredential -AccessKey $accesskey -SecretKey $secretkey
	Write-S3Object -BucketName $bucketname -File $filepath -Key $bacpac
	write-output "`n - UPLOAD COMPLETE - `n"
	write-output "`n - TRANSFER COMPLETE - `n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - "
	write-host $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds
	$subject = "TRANSFER SUCCESSFUL - " + $newdbName
	Send-MailMessage -To “transfer@service.com” -From “transfer@service.com”  -Subject $subject -Body $elapsedtime -SmtpServer $smtpserver -Port 25
} catch {
    "`n***************** UPLOAD ERROR *****************`n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - "
	write-host $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds
	$transcript = Get-Content C:\transfer\export_log.txt | out-string
	Send-MailMessage -To “transfer@service.com” -From “transfer@service.com”  -Subject $subject -Body $transcript -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}

write-output "Executing line 178"

<#delete#>

write-output "`n - DELETE COMMENCING - `n"

try {
	Remove-AzSqlDatabase -DatabaseName $newdbName -ServerName "sqlserver" -ResourceGroupName "resourcegroup"
	write-output "`n - DELETE COMPLETE - `n"
	try {
		$destination = "C:\transfer\database_bacpac_archive"
		Move-Item -Path $filepath -Destination $destination
	} catch {
		"`n***************** ERROR *****************`n"
		write-output "`n - BACPAC FILE MOVE FAILED - `n"
	}
	Stop-Transcript
} catch {
    "`n***************** ERROR *****************`n"
	$subject = "DELETE FAILED - " + $newdbName
	$transcript = Get-Content C:\transfer\export_log.txt | out-string
	Send-MailMessage -To “transfer@service.com” -From “transfer@service.com”  -Subject $subject -Body $transcript -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}
