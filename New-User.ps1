#Requires -Module ActiveDirectory, ExchangeOnlineManagement, AzureAD, MgGraph, New-HomeDrive, New-RetrieveUser
#Requires -Version 7


$ImportUsers = Import-Csv -Path "C:\Path\to\data.csv"
<# CSV Structure:
First, Last, UserName,      Phone,    Office
Joe,   Test,    JTest, 212-123-4567, New York
Jane,  Anne,    JAnne, 415-123-4567, San Francisco
#>
$SecretVault = 'KPVaultJA'
$ADCredential = (Get-Secret -Name 'Server_Admin' -Vault $SecretVault)

$Session1 = New-PSSession -ComputerName 'AzureADConnect@contoso.com' -Credential $ADCredential
$Session2 = New-PSSession -ComputerName 'Mail@Contoso.com' -Credential $ADCredential

Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"

$FileServerPath = '10.0.0.1\HomeDrive'

$CreatedUsers = foreach ($User in $ImportUsers){

    $SAM = $User.UserName
    $HomeDirPath = ($FileServerPath + '\' + $SAM)
    $FullName = $($User.First + ' ' +$User.Last)

    if($Null -eq (Get-ADUser -Filter {SamAccountName -eq $SAM})){
        $Parameters = @{
            'Name' = $FullName
            'GivenName' = $($User.First)
            'Surname' = $User.Last
            'DisplayName' = $FullName
            'Office' = $User.Office
            'UserPrincipalName' = $($SAM + '@contoso.com')
            'SamAccountName' = $SAM
            'ChangePasswordAtLogon' = $false
            'Enabled' = $true
            'AccountPassword' = $(ConvertTo-SecureString '<Starting Password Here>' -AsPlainText -Force)
            'Path' = 'OU = User, DC=Contoso, DC=com'
            'homeDrive' = 'A:'
            'homeDirectory' = $HomeDirPath
            'scriptPath' = 'logon.bat'
            'officePhone' =  $User.Phone
        }
        New-ADUser @Parameters -Credential $ADCredential
        Add-ADGroupMember -Identity "$($User.OFfice)" -Members $SAM -Credential $ADCredential
        Add-ADGroupMember -Identity "$($User.Office)" -Members $SAM -Credential $ADCredential

        Invoke-Command -Session $Session2 -ScriptBlock {
            Enable-RemoteMailbox -Identity $SAM -RemoteRoutingAddress ($SAM + 'contoso.mail.onmicrosoft.com')
        }
        New-HomeDrive -UserName $SAM -Path $FileServerPath -Credential $ADCredential
        New-RetrieveUser -Email "$SAM@contoso.com" -FullName $FullName -Office $User.Office
        Write-Output $SAM
    }
    else{
        Write-Error "$SAM already exists"
    }
}
Invoke-Command -Session $Session1 -ScriptBlock {
    Start-ADSyncSyncCycle -PolicyType Delta
}
Start-Sleep -Seconds 120

$Office365SKU = "4321"
$AzureSKU = "1234"

foreach ($User in $CreatedUsers){
    $UPN = $($User + "@contoso.com")
    $MgUser = Get-MgUser -UserId $UPN
    Update-MgUser -UserId $MgUser.Id -UsageLocation US
    Set-MgUserLicense -UserId $MgUser.Id -AddLicenses @(SkuID = "$Office365SKU") -RemoveLicenses @()
    Set-MgUserLicense -UserId $MgUser.Id -AddLicenses @(SkuID = "$AzureSKU") -RemoveLicenses @()
}

Disconnect-MgGraph
Get-PSSession | Remove-PSSession