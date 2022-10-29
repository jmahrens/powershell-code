Connect-ExchangeOnline 

$UserID = Read-Host -Prompt "Enter User's email"

Get-InboxRule -Mailbox $UserID | Select-Object Description,Enabled,Identity,RuleIdentity | Export-Csv C:\path\to\list.csv

foreach ($rule in $(Get-InboxRule -Mailbox $UserID)){
    Write-Host $Rule.Name
    Write-Host $Rule.Description

    $Prompt = Read-Host -Prompt "Remove $($Rule.Name)? (y/N)"

    if ($Prompt -like 'y'){
        Remove-InboxRule -Identity $Rule.RuleIdentity
    }

    Start-Sleep -Seconds 1 
}