function Remove-RetrieveUser {
    <#
        .SYNOPSIS
            Connects to Retrieve Public API and removes specific user
        .DESCRIPTION
            Retrieve Public API docs : https://api.retrieve.com/public-api-docs/
            Using HTTP Basic Authentcation : https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication
            Requires key:secret to be UTF-8 encoded
        
        .EXAMPLE
            Remove-RetrieveUser -Email 'test@contoso.com'
        .INPUTS
            String - Email
        .NOTES
            v1
            11/1/2022
            Jonathan Ahrens
    
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [string]
        $Email        
    )
    
    begin {
        $Vault = 'KPVaultJA'
        $KeyID = (Get-Secret -Name 'Retrieve API Key' -AsPlainText -Vault $Vault)
        $AppSecret = (Get-Secret -Name 'Retrieve API Secret' -AsPlainText -Vault $Vault)
        $KeyIDPassword = $KeyID + ':' + $AppSecret
        $EncodedKey = 'Basic' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($KeyIDPassword))
        $Header = @{
            'Authorization' = $EncodedKey
        }
    }
    
    process {
        $Url = 'https://api.retrieve.com/api/v1/users?filterBy=email' + [System.Web.HttpUtility]::UrlEncode("=$Email")
        $RetrieveUser = Invoke-RestMethod -Method 'Get' -Uri $Url -Headers $Header
        $Url = 'https://api.retrieve.com/api/v1/users/' + $($RetrieveUser.users.id)
        Invoke-RestMethod -Method 'Delete' -Uri $Url -Headers $Header       
    }
    
    end {
        
    }
}