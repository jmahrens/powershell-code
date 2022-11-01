<#
    .SYNOPSIS
        Connects to Retrieve Public API, creates new user and adds them to specific office group
    .DESCRIPTION
        Using the api documents at https://api.retrieve.com/public-api-docs/#
        Authenicate using unique keyId and secret using HTTP Basic authentication. 
        This requires the key:secret to be UTF-8 encoded
    .EXAMPLE
        New-RetrieveUser -Email 'Jtest@contoso.com' -FullName 'John Test' -Office 'San Francisco'

        user
        ----
        @{id=000001; email=jtest@contoso.com}

    .EXAMPLE
        New-RetrieveUser 'Joetest@contoso.com' 'Joe Test' 'New York'   

        user
        ----
        @{id=000001; email=Joetest@contoso.com}

    .EXAMPLE
        CSV Template:
        Email,      FullName, Office
        j@test.com, J Test,   New York
        h@test.com, H Test,   San Francisco
        l@test.com, L Test,   New York
        PS C:\> Import-Csv -Path 'C:\Path\to\data.csv'
        PS C:\> Foreach($user in $ImportedUsers){
        >>     New-RetrieveUser -Email $user.email -FullName $user.fullname -Office $user.office
        >> }

        user
        ----
        @{id=000001; email=j@test.com}
        @{id=000002; email=h@test.com}
        @{id=000003; email=l@test.com}
    .INPUTS
        String
    .NOTES
        V1.0
        11/1/2022
        Jonathan Ahrens
#>
function New-RetrieveUser {

    [CmdletBinding()]
    param (
        [CmdletBinding()]

        [Parameter(
            Mandatory,
            ValueFromPipeline
            )]
        [String]
        $Email,

        [Parameter(
            Mandatory,
            ValueFromPipeline
            )]
        [String]
        $FullName,

        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [String]
        $Office

    )

    begin {
        $Vault = 'KPVaultJA'
        $KeyId = (Get-Secret -Name 'Retrieve API Key' -AsPlainText -Vault $Vault)
        $AppSecret = (get-Secret -Name 'Retrieve API Secret' -AsPlainText -Vault $Vault)
        $KeyIdPassword = $KeyId + ':' + $appSecret
        $EncodedKey = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($KeyIdPassword))
        $Header =@{
            'Authorization' = $EncodedKey
        }
    }

    process {
        $Body = @{
            'email' = $Email
            'fullName' = $FullName
        }
        $Url = "https://api.retrieve.com/api/v1/users/add"
        Invoke-RestMethod -Method 'Post' -Uri $Url -Body $Body -Headers $Header -OutVariable Retrieveuser
        Write-Verbose -Message "Created Retrive account for $FullName"

        $Body = @{
            'userId' = $RetrieveUser.user.id
        }
        switch ($office) {
            'San Francisco' { $Url = "https://api.retrieve.com/api/v1/user-groups/<Insert Group ID>>/users/add"
            Invoke-RestMethod -Method 'Post' -Uri $Url -Body $Body -Headers $header}
            'New York' { $Url = "https://api.retrieve.com/api/v1/user-groups/<Insert Group ID>/users/add"
            Invoke-RestMethod -Method 'Post' -Uri $Url -Body $Body -Headers $header}
        } 
        Write-Verbose -Message "Added $FullName to $office Group" 
    }

    end {

    }
}