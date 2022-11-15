Connect-ExchangeOnline
Connect-IPPSSession

$BlockedEmail = Read-Host 'Enter email to be blocked'
$Date = Get-Date -Format 'MM/dd/yyyy'

Set-HostedContentFilterPolicy -Identity Default -BlockedSenders @{Add="$BlockedEmail"}

$ComplianceName = "Delete Phishing email $Date"
New-ComplianceSearch -Name $ComplianceName -ExchangeLocation All -ContentMatchQuery "From:$BlockedEmail"
Start-ComplianceSearch -Identity $ComplianceName
Start-Sleep -Seconds 300
New-ComplianceSearchAction -SearchName $ComplianceName -Purge -PurgeType SoftDelete