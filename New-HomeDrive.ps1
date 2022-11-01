<#
.SYNOPSIS
    Creates a new directory on the file server with default permissions
.DESCRIPTION
    Creates a user's home drive on the a file server similar to entering in the file server in the Active Directory Users and Computers GUI
.EXAMPLE
    PS C:\> New-HomeDrive -UserName JTest -Path "\\10.0.0.1\HomeDrive" -Credential (Get-Credential)
.EXAMPLE
    PS C:\> New-HomeDrive -UserName JTest -Path \\10.0.0.1\HomeDrive\test -Credential $ADCredential
        VERBOSE: Performing the operation "New drive" on target "Name: HomeDriveFileServer Provider: Microsoft.PowerShell.Core\FileSystem Root: \\10.0.0.1\HomeDrive\test".
        Name           Used (GB)     Free (GB) Provider      Root                                                                                                                                                                                                                            CurrentLocation
        ----           ---------     --------- --------      ----                                                                                                                                                                                                                            --------------- 
        HomeDrive…                             FileSystem    \\10.0.0.1\HomeDrive\Test    
        VERBOSE: Performing the operation "Set-Acl" on target "HomeDriveFileServer:\jtest".
        VERBOSE: Performing the operation "Remove Drive" on target "Name: HomeDriveFileServer Provider: Microsoft.PowerShell.Core\FileSystem Root: \\10.0.0.1\HomeDrive\test".              
.INPUTS
    Username(s), root directory path, file server credentials
.OUTPUTS
    Output (if any)
.NOTES
    2022 April 21 Jonathan Ahrens
#>
function New-HomeDrive{
    [CmdletBinding()]
    param(
        #First Initial, Last Name of user 'JTest'     
        [Parameter(
            Position = 0,
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [String[]]
        $UserName,
        
        # UNC location of the file server. Must use IP Address if already connected to X: drive
        [Parameter(
            Mandatory,
            Position = 1)]
        [ValidateScript (
            {Test-path $_}
            )]
        [string]
        $Path,

        # AD Credential for access to write on the file server
        [Parameter(
            Position =2,
            Mandatory)]
        [System.Management.Automation.PSCredential]
        $Credential        
    )
    Begin{
        #Connect to file server with AD Credentials and store as a PSDrive
        $PSDriveName = 'HomeDriveFileServer'
        New-PSDrive -Name $PSDriveName -PSProvider FileSystem -Root $Path -Credential $Credential -Verbose
        #Setup security ACLs for new directory
        $Rights = [System.Security.AccessControl.FileSystemRights]'FullControl' #Other options: [enum]::GetValues('System.Security.AccessControl.FileSystemRights')
        $Inheritance = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit' #Other options: [enum]::GetValues('System.Security.AccessControl.InheritanceFlags')
        $Propagation = [System.Security.AccessControl.PropagationFlags]'None' #Other options: [enum]::GetValues('System.Security.AccessControl.PropagationFlags')
        $Type = [System.Security.AccessControl.AccessControlType]'Allow' #Other options: [enum]::GetValues('System.Security.AccessControl.AccessControlType')
        #Setup admin ACLs for new diretory
        $Admins = Get-ADGroup -Identity "Administrators"
        $AdminsAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule ($Admins.SID, $Rights, $Inheritance, $Propagation, $Type)
    }
    Process{
        #Create new directory for User
        $HomeDirPath = ($PSDriveName + ':\' + $UserName)
        $_homeDirObj = New-Item -path $HomeDirPath -ItemType Directory -force
        #Store current ACL
        $_acl = Get-Acl $_homeDirObj
        #Create new ACL for User
        $Identity = "Contoso\$UserName"
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Identity,$Rights,$Inheritance,$Propagation,$Type)
        #Add new ACLs to the ACL object
        $_acl.AddAccessRule($AccessRule)
        $_acl.AddAccessRule($AdminsAccessRule)
        #Apply new ACL permissions to new directory
        Set-Acl -path $HomeDirPath -AclObject $_acl -ErrorAction Stop -Verbose
    }
    End{
        Remove-PSDrive -Name $PSDriveName -Verbose
    }
}