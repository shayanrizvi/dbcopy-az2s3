$ErrorActionPreference = "STOP"
$WarningPreference = 'SilentlyContinue'

<#temp log parameters#>

$directory = $(($pwd).path)
$templog =  $directory + "\templog.txt"
$temptoaddress = "devops@domain.com"
$tempfromaddress = "transferservice@domain.com"
$tempsmtpserver = "smtpserver.domain.com"

<#start temp log#>

Start-Transcript -Path $templog

<#fetch config#>

write-output "`n - FETCHING CONFIGURATION FROM config.json - `n"

try {
	$config = Get-Content -Path C:\transfer\config.json | ConvertFrom-Json
	$printtime = Get-Date -AsUTC -Format "yyyy-MM-ddTHH-mmZ"
	$logpath = $config.LogPath
	$transcriptpath = $logpath + "transfer_log_" + $printtime + ".txt"
} catch {
	"`n***************** ERROR *****************`n"
	$subject = "CONFIGURATION ERROR"
	$transcript = Get-Content $templog | out-string
	Send-MailMessage -To $temptoaddress -From $tempfromaddress -Subject $subject -Body $transcript -SmtpServer $tempsmtpserver -Port 25
	Stop-Transcript
	Exit 1
}

<#start custom log#>

write-output "`n - CONFIGURATION SAVED - `n - CLOSING templog.txt - `n"
Stop-Transcript
Start-Transcript -Path $transcriptpath

<#enable AWS support#>

Set-PSRepository "PSGallery" -InstallationPolicy Trusted
install-module aws.tools.common
import-module aws.tools.common
install-module aws.tools.s3
import-module aws.tools.s3

<#time parameters#>

$currenttime = Get-Date -AsUTC
$starttime = $currenttime
$restoretime = $currenttime
$year = ($currenttime).Year
$month = ($currenttime).Month
$day = ($currenttime).Day
$hour = ($currenttime).Hour

<#time logic#>

if ($hour -ge 7 -And $hour -lt 18) {
	write-output "`n - Timeslot: 07:00 - 17:59 - `n"
	$restoretime = Get-Date -Year $year -Month $month -Day $day -Hour "07" -Minute "00" -Second "00"
	if ($month -lt 10) {
		$month = "0" + [string]$month
	}
	if ($day -le 10) {
		$day = "0" + [string]$day
	}
	<#
	if ($currenttime.IsDaylightSavingTime()) {
		$restoretime  = Get-Date -Hour "07" -Minute "00" -Second "00"
		} else {
			$restoretime  = Get-Date -Hour "07" -Minute "00" -Second "00"
		}
	#>
	$printtime = [string]$year + "-" + $month + "-" + $day + "T07-00Z"
} elseif ($hour -ge 18) {
	write-output "`n - Timeslot: 18:00 - 23:59 - `n"
	$restoretime  = Get-Date -Year $year -Month $month -Day $day -Hour "18" -Minute "00" -Second "00"
	if ($month -lt 10) {
		$month = "0" + [string]$month
	}
	if ($day -le 10) {
		$day = "0" + [string]$day
	}
	<#
	if ($currenttime.IsDaylightSavingTime()) {
		$restoretime  = Get-Date -Hour "18" -Minute "00" -Second "00"
		} else {
			$restoretime  = Get-Date -Hour "18" -Minute "00" -Second "00"
		}
	#>
	$printtime = [string]$year + "-" + $month + "-" + $day + "T18-00Z"
} else {
	write-output "`n - Timeslot: 00:00 - 06:59 - `n"
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
	$restoretime  = Get-Date -Year $year -Month $month -Day $day -Hour "18" -Minute "00" -Second "00"
	if ($month -lt 10) {
		$month = "0" + [string]$month
	}
	if ($day -le 10) {
		$day = "0" + [string]$day
	}
	<#
	if ($currenttime.IsDaylightSavingTime()) {
		$restoretime  = Get-Date -Hour "18" -Minute "00" -Second "00"
		} else {
			$restoretime  = Get-Date -Hour "18" -Minute "00" -Second "00"
		}
	#>
	$printtime = [string]$year + "-" + $month + "-" + $day + "T18-00Z"
}

<#initialize config#>

$appid = $config.AppId
$password = ConvertTo-SecureString $config.Password -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PScredential($appid, $password)
$tenantid = $config.TenantId

$resourcegroup = $config.ResourceGroup
$server = $config.Server
$sourcedatabase = $config.SourceDatabase
$serviceaccount = $config.ServiceAccount
$sapass = $config.SaPass

$accesskey = $config.AccessKey
$secretkey = $config.SecretKey
$bucketname = $config.BucketName

$newdbName = $sourcedatabase + "-" + $printtime
$bacpac = $newdbName + ".bacpac"
$filepath = $config.FilePath + $bacpac
$subject = $config.Subject + " - " + $newdbName
$toaddress = $config.ToAddress
$fromaddress = $config.FromAddress
$smtpserver = $config.SMTPServer
$destination = $config.Destination
$daysback = $config.DaysBack
$datetoDelete = $currenttime.AddDays($daysback)

<#Azure connect#>

try {
	Connect-AzAccount -ServicePrincipal -credential $pscredential -Tenant $tenantid
} catch {
    "`n***************** CONNECT-AZACCOUNT ERROR *****************`n"
	$transcript = Get-Content $transcriptpath | out-string
	Send-MailMessage -To $toaddress -From $fromaddress -Subject $subject -Body $transcript -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}

<#restore database#>

write-output "`n - TRANSFER COMMENCING - `n"
write-output "`n - START TIME - `n" $starttime
write-output "`n - RESTORE TIME - `n" $restoretime
write-output "`n - PRINT TIME - `n" $printtime
write-output "`n - RESTORE COMMENCING - `n"

start-sleep 3

try {
	$pointintime = [DateTime]::SpecifyKind($restoretime,[DateTimeKind]::Utc)
	$Database = Get-AzSqlDatabase -ResourceGroupName $resourcegroup -ServerName $server -DatabaseName $sourcedatabase
	Restore-AzSqlDatabase -FromPointInTimeBackup -PointInTime $pointintime -ResourceGroupName $resourcegroup -ServerName $Database.ServerName -TargetDatabaseName $newdbName -ResourceId $Database.ResourceID
	write-output "`n - RESTORE COMPLETE - `n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - `n"
	write-output $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds "`n"
} catch {
    "`n***************** RESTORE ERROR *****************`n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - `n"
	write-output $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds "`n"
	$transcript = Get-Content $transcriptpath | out-string
	Send-MailMessage -To $toaddress -From $fromaddress -Subject $subject -Body $transcript -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}

<#export database#>

write-output "`n - EXPORT COMMENCING - `n"

try {
	$exportCommand = '"C:\Program Files\Microsoft SQL Server\150\DAC\bin\sqlpackage.exe" /a:Export /tf:' + $bacpac + ' /scs:"Data Source=' + $server + '.database.windows.net;Initial Catalog=' + $newdbName + ';User ID=' + $serviceaccount + ';Password=' + $sapass + '"'
	cmd.exe /c $exportCommand
	write-output "`n - EXPORT COMPLETE - `n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - `n"
	write-output $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds "`n"
} catch {
    "`n***************** EXPORT ERROR *****************`n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - `n"
	write-output $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds "`n"
	$transcript = Get-Content $transcriptpath | out-string
	Send-MailMessage -To $toaddress -From $fromaddress -Subject $subject -Body $transcript -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}

<#upload database#>

write-output "`n - UPLOAD COMMENCING - `n"

try {
	Set-AWSCredential -AccessKey $accesskey -SecretKey $secretkey
	Write-S3Object -BucketName $bucketname -File $filepath -Key $bacpac
	write-output "`n - UPLOAD COMPLETE - `n"
	write-output "`n - TRANSFER SUCCESSFUL - `n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - `n"
	write-output $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds "`n"
	$subject = "TRANSFER SUCCESSFUL - " + $newdbName
	$body = $newdbName + ".bacpac has been uploaded successfully. - ELAPSED TIME - " + $elapsedtime
	Send-MailMessage -To $toaddress -From $fromaddress -Subject $subject -Body $body -SmtpServer $smtpserver -Port 25
} catch {
    "`n***************** UPLOAD ERROR *****************`n"
	$currenttime = Get-Date -AsUTC
	$elapsedtime = New-TimeSpan $starttime $currenttime
	write-output "`n - ELAPSED TIME - `n"
	write-output $elapsedtime.Hours ":" $elapsedtime.Minutes ":" $elapsedtime.Seconds "`n"
	$transcript = Get-Content $transcriptpath | out-string
	Send-MailMessage -To $toaddress -From $fromaddress -Subject $subject -Body $transcript -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}

<#delete database#>

write-output "`n - DELETE COMMENCING - `n"

try {
	Remove-AzSqlDatabase -DatabaseName $newdbName -ServerName $server -ResourceGroupName $resourcegroup
	write-output "`n - DELETE COMPLETE - `n"
} catch {
    "`n***************** ERROR *****************`n"
	$subject = "`n - DELETE FAILED - " + $newdbName
	$transcript = Get-Content $transcriptpath | out-string
	Send-MailMessage -To $toaddress -From $fromaddress -Subject $subject -Body $transcript -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}

<#archive bacpac#>

try {
	Move-Item -Path $filepath -Destination $destination
} catch {
	"`n***************** ERROR *****************`n"
	$subject = "`n - ARCHIVE FAILED - " + $newdbName
	$transcript = Get-Content $transcriptpath | out-string
	Send-MailMessage -To $toaddress -From $fromaddress -Subject $subject -Body $subject -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}

<#cleanup bacpac & logs#>

try {
	Get-ChildItem $destination -Recurse | Where-Object {$_.LastWriteTime -lt $datetoDelete} | Remove-Item
	Get-ChildItem $logpath -Recurse | Where-Object {$_.LastWriteTime -lt $datetoDelete} | Remove-Item
	Remove-Item $templog
} catch {
	"`n***************** ERROR *****************`n"
	$subject = "`n - CLEANUP FAILED - " + $newdbName
	$transcript = Get-Content $transcriptpath | out-string
	Send-MailMessage -To $toaddress -From $fromaddress -Subject $subject -Body $subject -SmtpServer $smtpserver -Port 25
	Stop-Transcript
	Exit 1
}

Stop-Transcript
