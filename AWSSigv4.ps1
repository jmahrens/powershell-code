$AwsAccessKeyId = ''
$AwsSecretAccessKey = ''
$AwsRegion = 'us-east-1'
$AwsServiceName = 'execute-api'

<#
    .SYNOPSIS
        Converts current time to Universal time for AWS Signature v4
#>
function Get-UniversalTime {
    ([datetime]::UtcNow).ToString("yyyyMMddTHHmmssZ")
}

<#
    .SYNOPSIS
        Converts current time to shortened Universal time for AWS Signature v4
#>
function Get-CurrentDate {
    ([datetime]::UtcNow).ToString("yyyyMMdd")
}

<#
    .SYNOPSIS
        Converts string to SHA256 hash for AWS Signature v4
#>
function Get-Sha256{
    param (
        $Body
    )
    $Sha256 = [System.Security.Cryptography.SHA256]::Create()
    $Utf8 = [System.Text.UTF8Encoding]::new()
    $Bytes = $Utf8.GetBytes($Body)

    $Hash = $sha256.ComputeHash($Bytes)
    $Hex = [System.BitConverter]::ToString($Hash) -replace '-' 

    return $Hex.ToLower()
    
}

<#
    .SYNOPSIS
        HMACSHA256 function for building AWS Signature v4
#>
function Get-HmacSha256Hash {
    param (
        [byte[]] $Key,
        [string] $Data
    )
    $HmacSha = New-Object System.Security.Cryptography.HMACSHA256
    $HmacSha.key = $Key
    return $HmacSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Data))

}
$TestKey = [System.Text.Encoding]::UTF8.GetBytes("secretKey")
$TestData = "Hello World"

<#
    .SYNOPSIS
        Converts current time to Universal time for AWS Signature v4
#>
function Get-AwsSignatureKey {
    param (
        [string] $AccessKey,
        [string] $Region,
        [string] $ServiceName
    )

    $Date = Get-CurrentDate
    $SecretKey = [System.Text.Encoding]::UTF8.GetBytes("AWS4$AccessKey")
    $DateKey = Get-HmacSha256Hash -Key $SecretKey -Data $Date
    $RegionKey = Get-HmacSha256Hash -Key $DateKey -Data $Region
    $ServiceKey = Get-HmacSha256Hash -Key $RegionKey -Data $ServiceName
    $SigningKey = Get-HmacSha256Hash -Key $ServiceKey -Data "aws4_request"

    return $SigningKey
}

function Get-CanonicalHeaders($Headers){
    return $Headers.GetEnumerator() | Sort-Object -Property Name | ForEach-Object {"$($_.Key):$($_.Value)"
}

function Invoke-AwsWebRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0,
            HelpMessage = "HTTP method (POST / GET / PUT / DELETE)"
        )]
        [string] $Method,

        [Parameter(Mandatory, Position = 1,
            HelpMessage = "AWS URI"
        )]
        [string] $Uri,

        [Parameter(Mandatory,Position = 2)]
        [string] $AWSAccessID,
        
        [Parameter(Mandatory, Position = 3)]
        [string] $AWSAccessKey,

        [Parameter(Position = 4)]
        [string] $AwsServiceName = 'execute-api'
    )

    DynamicParam {
        if ($Method -eq 'POST' -or 'PUT'){
            $parameterAttribute = New-Object System.Management.Automation.ParameterAttribute
            $parameterAttribute.ParameterSetName = "Body"
            $parameterAttribute.Mandatory = $true
            $parameterAttribute.HelpMessage = "Payload of your POST request"
        }
    }

    #Set Current Date variable in AWS format
    $CurrentDate = Get-CurrentDate
    
    #Set Current time variable in UTC AWS format
    $UniversalTime = Get-UniversalTime
    
    #Length of the payload/body for encoding in the header
    $BodyBytes = ([System.Text.Encoding]::Utf8.getbytes($Body).Length)
    
    #Cast the URI into a digestable format
    $RequestUri = [System.Uri]$Uri
    $ResourcePath = $RequestUri.Localpath
    
    #If querying mulitple items, format into a single line joined by '&'
    $QueryParams = [System.Web.HttpUtility]::ParseQueryString($RequestUri.Query)
    $CanonicalQuery = ($QueryParams.Keys | ForEach-Object {
        "$($_)=" + [System.Web.HttpUtility]::UrlEncode($QueryParams.Item($_))
    }) -join '&'
    switch ($Method) {
        {'GET' -or 'DELETE'} { $Body = ""}
        {'PUT' -or 'POST'} {$CanonicalHeaders = Get-CanonicalHeaders @{
            "content-length" = $BodyBytes
            "content-type" = "application/json"
        }}
    }
    $CanonicalHeaders = $CanonicalHeaders + (Get-CanonicalHeaders @{
        "host" = $requestUri.Authority
        "x-amz-date" = $UniversalTime
    })
    #TODO Add Custom Header(s) // param + functionality // use .toLower()
    
    #Build CanonicalRequest
    $CanonicalRequestBuilder = [System.Text.StringBuilder]::new()
    $CanonicalRequestBuilder.AppendLine($Method)
    $CanonicalRequestBuilder.AppendLine($ResourcePath)
    $CanonicalRequestBuilder.AppendLine($CanonicalQuery)
    $CanonicalHeaders | ForEach-Object { $CanonicalRequestBuilder.AppendLine($_) }
    #Grab used headers for signed headers (alphabetical required)
    $Headers = [System.Collections.Generic.List[string]]::new()
    $CanonicalHeaders | ForEach-Object { $Headers.add( $_.split(":")[0]) }
    $SignedHeaders = $Headers -join ';'
    $CanonicalRequestBuilder.AppendLine($SignedHeaders)
    #Hash payload
    $CanonicalRequestBuilder.AppendLine( (Get-Sha256 -Body $Body))
    $CanonicalRequest = $CanonicalRequestBuilder.ToString()

    #Signed String
    $CredentialScope = "$($CurrentDate)/$($AwsRegion)/$($AwsServiceName)/aws4_request"
    $CanonicalRequestSha = Get-Sha256 -Body $CanonicalRequest
    $CanonicalRequestHex = [System.BitConverter]::ToString($CanonicalRequestSha)
    $SignedString = ("AWS4-HMAC-SHA256",
                    $UniversalTime,
                    $CredentialScope,
                    $CanonicalRequestSha) -join "`n"

}