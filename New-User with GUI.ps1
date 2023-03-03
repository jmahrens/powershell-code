# Load the Active Directory module
Import-Module ActiveDirectory, Microsoft.Graph
Add-Type -AssemblyName System.Windows.Forms


# Create the GUI form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Create New User"
$form.Size = New-Object System.Drawing.Size(350, 250)
$form.StartPosition = "CenterScreen"

# Add labels and text boxes for the user information
$labelFirstname = New-Object System.Windows.Forms.Label
$labelFirstname.Text = "First Name:"
$labelFirstname.Location = New-Object System.Drawing.Point(10, 20)
$labelFirstname.AutoSize = $true
$form.Controls.Add($labelFirstname)

$textboxFirstname = New-Object System.Windows.Forms.TextBox
$textboxFirstname.Location = New-Object System.Drawing.Point(100, 20)
$textboxFirstname.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($textboxFirstname)

$labelLastname = New-Object System.Windows.Forms.Label
$labelLastname.Text = "Last Name:"
$labelLastname.Location = New-Object System.Drawing.Point(10, 50)
$labelLastname.AutoSize = $true
$form.Controls.Add($labelLastname)

$textboxLastname = New-Object System.Windows.Forms.TextBox
$textboxLastname.Location = New-Object System.Drawing.Point(100, 50)
$textboxLastname.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($textboxLastname)

$labelUsername = New-Object System.Windows.Forms.Label
$labelUsername.Text = "Username:"
$labelUsername.Location = New-Object System.Drawing.Point(10, 80)
$labelUsername.AutoSize = $true
$form.Controls.Add($labelUsername)

$textboxUsername = New-Object System.Windows.Forms.TextBox
$textboxUsername.Location = New-Object System.Drawing.Point(100, 80)
$textboxUsername.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($textboxUsername)

$labelPassword = New-Object System.Windows.Forms.Label
$labelPassword.Text = "Password:"
$labelPassword.Location = New-Object System.Drawing.Point(10, 110)
$labelPassword.AutoSize = $true
$form.Controls.Add($labelPassword)

$textboxPassword = New-Object System.Windows.Forms.TextBox
$textboxPassword.PasswordChar = '*'
$textboxPassword.Location = New-Object System.Drawing.Point(100, 110)
$textboxPassword.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($textboxPassword)

$labelOffice = New-Object System.Windows.Forms.Label
$labelOffice.Text = "Office:"
$labelOffice.Location = New-Object System.Drawing.Point(10, 140)
$labelOffice.AutoSize = $true
$form.Controls.Add($labelOffice)

$textboxOffice = New-Object System.Windows.Forms.TextBox
$textboxOffice.Location = New-Object System.Drawing.Point(100, 140)
$textboxOffice.Size = New-Object System.Drawing.Size(200, 20)
$form.Controls.Add($textboxOffice)

# Add a button to create the new user
$buttonCreate = New-Object System.Windows.Forms.Button
$buttonCreate.Text = "Create User"
$buttonCreate.Location = New-Object System.Drawing.Point(140, 170)
$buttonCreate.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $buttonCreate
$form.Controls.Add($buttonCreate)

# Show the GUI and wait for input
$result = $form.ShowDialog()
$ADCredential = Get-Credential -Message 'Enter AD credentials'

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    # Retrieve the user information from the text boxes
    $firstname = $textboxFirstname.Text
    $lastname = $textboxLastname.Text
    $username = $textboxUsername.Text
    $password = $(ConvertTo-SecureString $textboxPassword.Text -AsPlainText -Force)
    $displayname = $($firstname + ' ' + $lastname)
    $email = $($username + '@contoso.com')
    $office = $textboxOffice.Text
    # Set user information as the new user parameter
    $parameters = @{
                'Name' = $displayname
                'GivenName' = $firstname
                'Surname' = $lastname
                'DisplayName' = $displayname 
                'Office' = $office 
                'UserPrincipalName' = $email
                'SamAccountName' = $username
                'ChangePasswordAtLogon' = $False 
                'Enabled' = $True 
                'AccountPassword' = $password 
                'homeDrive' = 'X:'
                }
    # Set OU and logon script based on office location
    switch($office){
        'Office1' {
            $path = 'OU=Office1, OU=Users, DC=Contoso, DC=com'
            $scriptPath = 'logonscript1.bat'
            }
        'Office2'{
            $path = 'OU=Office2, OU=Users, DC=Harthowerton, DC=com'
            $scriptPath = 'logonscript2.bat'
            }
         }
    
    if($Null -eq (Get-Aduser -Filter {SamAccountName -eq $username})){
        $S1 = New-PSSession -ConfigurationName Microsoft.exchange -ConnectionUri http://mail.contoso.com/powershell/ -Authentication Kerberos -Credential $ADCredential
        $S2 = New-PSSession -ComputerName 'AADC_Server' -Credential $ADCredential
        Import-PSSession -Session $S1 
        Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"
        # Create user
        New-ADUser @parameters -Path $path -ScriptPath $scriptPath -Credential $ADCredential
        Write-Output "$displayname has been created in AD"
        
        # Create user's home drive and add them to office specific groups
        switch($user.Office){
            'OFfice1' {
                $FileServerPath = '\\Fileserver\Office1'
                $HomeDirPath = ($FileServerPath + '\' + $username)
                Add-ADGroupMember -Identity 'Group1' -Members $username -Credential $ADCredential 
                Add-ADGroupMember -Identity 'Group2' -Members $username -Credential $ADCredential
                Write-Output "Added $username to Groups"
                Start-Sleep -Seconds 1
                #Custom cmdlet to create home drive on local file server
                New-HomeDrive -UserName $username -path $FileServerPath -Credential $ADCredential | Out-Null
                Write-Host "Home Drive created for $username"
                }
            'Office2'{
                $FileServerPath = '\\Fileserver\Office2'
                $HomeDirPath = ($FileServerPath + '\' + $($username + '$'))
                Add-ADGroupMember -Identity 'Group3' -Members $username -Credential $ADCredential
                Write-Output "Added $username to Group"
                Start-Sleep -Seconds 2
                # Custom cmdlet to create home drive on local file server
                New-HomeDrive -UserName $username -path $FileServerPath -Credential $ADCredential | Out-Null
                Write-Host "Home Drive created for $username"
                }
            }
        
        # Set newly created home drive to user
        Set-ADUser -Identity $username -HomeDirectory $HomeDirPath -Credential $ADCredential
        Write-Output "$displayname has been set for $office"
        
        # Create remote mailbox for user
        Enable-RemoteMailbox -Identity $username -RemoteRoutingAddress ($username + '@contoso.mail.onmicrosoft.com') | Out-Null
        Write-Output "Remote mailbox added for $displayname"
               
        # Sync on-premise AD user with Azure AD
        Invoke-Command -Session $S2 -ScriptBlock {
            Import-Module AzureADConnectHealthSync
            Start-ADSyncSyncCycle -PolicyType Delta
        }
        Write-Host "Starting 1 minute sleep for AD Sync"
        Start-Sleep -Seconds 60
        Write-Host "Assigning Licenses"

        # Current license SKU for HH tenent
        $O365LicenseSku ="LicenseSKU#1234"
        $AudioConfSkuId="LicenseSKU@2345"
        # Grab Azure AD user
        $MgUser = Get-MgUser -UserId $email
        # Set user's location to US
        Update-MgUser -UserId $MgUser.Id -UsageLocation US
        # Add licenses to user
        Set-MgUserLicense -UserId $MgUser.Id -AddLicenses @{SkuID = "$O365LicenseSku"} -RemoveLicenses @()
        Set-MgUserLicense -UserId $MgUser.Id -AddLicenses @{SkuID = "$AudioConfSkuId"} -RemoveLicenses @()
        # Script cleanup by disconnecting from Azure, Exchange On-prem and Azure AD Sync server
        Write-Output "Assigned MS licenses for $displayname"
        Disconnect-MgGraph
        Get-PSSession | Remove-PSSession
        Read-Host -Prompt 'Press Enter to close'
    }
}
