function Get-NewformaCloudSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $LoginURL,
        # Newforma Cloud Access Key
        [Parameter(Mandatory)]
        [string]
        $AccessKey,
        # Newforma Cloud Access Secret
        [Parameter(Mandatory)]
        [string]
        $AccessSecret
    )
    begin {
        $Header = @{
            "Content-Type" = "application/json"
        }
        $Body = @{
            'accessKey' = $AccessKey
            'secret' = $AccessSecret
        } | ConvertTo-Json
    }
    process {
        try{
            $Response = Invoke-WebRequest -Method 'Post' -Body $Body -Headers $Header -Uri $LoginURL
            if ($Response.StatusCode -eq 200) {
                return $Response.Content | ConvertFrom-Json
            }
            else {
                throw [System.Exception]::new("Failed to login. Error Code "+ $Response.StatusCode)
            }
        }
        catch {
            throw $_
        }
    }    
}
