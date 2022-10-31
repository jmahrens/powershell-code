function Remove-MsLicense {
    [CmdletBinding()]
    param (
        # User Principal Name
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]
        $UserPrincipalName  
    )
    begin {
        Connect-MgGraph -Scopes 'User.ReadWrite.all'
    }
    
    process {
        try {
            $MgUser = Get-MgUser -UserID $UserPrincipalName -ErrorAction Stop            
        }
        catch {
            Write-Error "$UserPrincipalName was not found."
            Continue
        }
        $SKUs = @(Get-MgUserLicenseDetail -UserId $MgUser.Id)
        if (!$SKUs){
            Write-Error "No Licenses assigned to $UserPrincipalName"
        }
        foreach ($SKU in $SKUs){
            Set-MgUserLicense -UserId $MgUser.Id -AddLicense @() -RemoveLicenses $SKU
        }
    }
    
    end {
        Disconnect-MgGraph
    }
    
}