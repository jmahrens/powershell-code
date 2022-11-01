function Verb-Noun {
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
        $Vault = 'KPVault'
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
        $RetreiveUser = Invoke-RestMethod -Method 'Get' -Uri $Url -Headers $Header
        $Url = 'https://api.retrieve.com/api/v1/users/' + $(RetriveUser.users.id)
        Invoke-RestMethod -Method 'Delete' -Uri $Url -Headers $Header       
    }
    
    end {
        
    }
}