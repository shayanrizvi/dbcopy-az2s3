$date = Get-Date -AsUTC -Format "yyyy-MM-ddTHH-mmZ"
$transcriptpath = "C:\transfer\export_logs\export_log_" + $date + ".txt"
Start-Transcript -Path $transcriptpath

$ErrorActionPreference = "STOP"
$WarningPreference = 'SilentlyContinue'

Set-PSRepository "PSGallery" -InstallationPolicy Trusted
install-module aws.tools.common
import-module aws.tools.common
install-module aws.tools.s3
import-module aws.tools.s3

$credential = Get-Content -Path C:\transfer\credential.json | ConvertFrom-Json
$password = ConvertTo-SecureString $credential.Password -AsPlainText -Force
$sapass = ConvertTo-SecureString $credential.SaPass -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PScredential($credential.AppId, $password)

$accesskey = "accesskey"
$secretkey = "secretkey"
$bucketname = "bucketname"
$resourcegroup = "resourcegroup"
$server = "server"
$sourcedatabase = "sourcedatabase"
$serviceaccount = "transferservice"
$newdbName = $sourcedatabase + "-" + $printtime
$bacpac = $newdbName + ".bacpac"
$filepath = "C:\transfer\" + $bacpac
$subject = "TRANSFER FAILED - " + $newdbName
$toaddress = "transfer@service.com"
$fromaddress = "transfer@service.com"
$smtpserver = "smtpserver.domain.com"
$destination = "C:\transfer\bacpac_archive"

Connect-AzAccount -ServicePrincipal -credential $pscredential -Tenant $credential.TenantId

$currenttime = Get-Date -AsUTC
$starttime = $currenttime
$restoretime = $currenttime
$printtime = Get-Date -AsUTC -Format "yyyy-MM-ddTHH-mmZ"
$year = ($currenttime).Year
$month = ($currenttime).Month
$day = ($currenttime).Day
$hour = ($currenttime).Hour

if ($hour -ge 7 -And $hour -lt 18) {
	
	write-output "`n - Hours: 7 - 17 - `n"
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
	
	write-output "`n - Hours: 18 - 23 - `n"
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
	
	write-output "`n - Hours: 0 - 6 - `n"
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

start-sleep 3

write-output "`n - TRANSFER COMMENCING - `n"
write-output "`n - START TIME - `n" $starttime
write-output "`n - RESTORE TIME - `n" $restoretime



<#restore#>

$currenttime = Get-Date -AsUTC -Format "yyyy-MM-ddTHH-mmZ"
write-output "`n - RESTORE COMMENCING - `n"

try {
	$pointintime = [DateTime]::SpecifyKind($restoretime,[DateTimeKind]::Utc)
	$Database = Get-AzSqlDatabase -ResourceGroupName $resourcegroup -ServerName $server -DatabaseName $sourcedatabase
	Restore-AzSqlDatabase -FromPointInTimeBackup -PointInTime $pointintime -ResourceGroupName $resourcegroup -ServerName $Database.ServerName -TargetDatabaseName $newdbName -ResourceId $Database.ResourceID
	write-output "`n - RESTORE COMPLETE - `n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - "
	write-host $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds "`n"
} catch {
    "`n***************** RESTORE ERROR *****************`n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - "
	write-host $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds "`n"
	$transcript = Get-Content $transcriptpath | out-string
	Send-MailMessage -To $toaddress -From $fromaddress  -Subject $subject -Body $transcript -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}



<#export#>

write-output "`n - EXPORT COMMENCING - `n"

try {
	$exportCommand = '"C:\Program Files\Microsoft SQL Server\150\DAC\bin\sqlpackage.exe" /a:Export /tf:' + $bacpac + ' /scs:"Data Source=" + $server + ".database.windows.net;Initial Catalog=' + $newdbName + ';User ID=" + $serviceaccount + ";Password=" +$sapass'
	cmd.exe /c $exportCommand
	write-output "`n - EXPORT COMPLETE - `n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - "
	write-host $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds "`n"
} catch {
    "`n***************** EXPORT ERROR *****************`n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - "
	write-host $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds "`n"
	$transcript = Get-Content $transcriptpath | out-string
	Send-MailMessage -To $toaddress -From $fromaddress  -Subject $subject -Body $transcript -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}



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
	write-host $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds "`n"
	$subject = "TRANSFER SUCCESSFUL - " + $newdbName
	$body = $newdbName + ".bacpac has been uploaded successfully. - ELAPSED TIME - " + $elapsedtime
	Send-MailMessage -To $toaddress -From $fromaddress -Subject $subject -Body $body -SmtpServer $smtpserver -Port 25
} catch {
    "`n***************** UPLOAD ERROR *****************`n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - "
	write-host $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds "`n"
	$transcript = Get-Content $transcriptpath | out-string
	Send-MailMessage -To $toaddress -From $fromaddress -Subject $subject -Body $transcript -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}



<#delete#>

write-output "`n - DELETE COMMENCING - `n"

try {
	Remove-AzSqlDatabase -DatabaseName $newdbName -ServerName $server -ResourceGroupName $resourcegroup
	write-output "`n - DELETE COMPLETE - `n"
} catch {
    "`n***************** ERROR *****************`n"
	$subject = "DELETE FAILED - " + $newdbName
	$transcript = Get-Content $transcriptpath | out-string
	Send-MailMessage -To $toaddress -From $fromaddress  -Subject $subject -Body $transcript -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}

try {
	Move-Item -Path $filepath -Destination $destination
} catch {
	"`n***************** ERROR *****************`n"
	$subject = "NEW BACPAC FILE MOVE FAILED - " + $newdbName
	$transcript = Get-Content $transcriptpath | out-string
	Send-MailMessage -To $toaddress -From $fromaddress  -Subject $subject -Body $subject -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}

try {
	$Path = "C:\export\export_logs"
	$Daysback = "-30"
	$CurrentDate = Get-Date
	$DatetoDelete = $CurrentDate.AddDays($Daysback)
	Get-ChildItem $Path -Recurse  | Where-Object { $_.LastWriteTime -lt $DatetoDelete } | Remove-Item
} catch {
	"`n***************** ERROR *****************`n"
	$subject = "OLD BACPAC FILE DELETE FAILED - " + $newdbName
	$transcript = Get-Content $transcriptpath | out-string
	Send-MailMessage -To $toaddress -From $fromaddress  -Subject $subject -Body $subject -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}
