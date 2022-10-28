Connect-ExchangeOnline
Connect-IPPSSession -UserPrincipalName 'user@contoso.com'

$BlockedEmail = Read-Host 'Enter Email to be blocked:'
$Date = Get-Date -Format 'MM/dd/yyyy'
$ComplianceName = "Delete Phishing Email $Date"

Set-HostedContentFilterPolicy -Identity Default -BlockedSenders @{Add="$BlockedEmail"}
New-ComplianceSearch -Name $ComplianceName -ExchangeLocation All -ContentMatchQuery "From:$BlockedEmail"
Start-ComplianceSearch -Identity $ComplianceName
Start-Sleep -Seconds 300
New-ComplianceSearch -SearchName $ComplianceName -Purge -PurgeType SoftDelete