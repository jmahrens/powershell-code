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

    $Hash = $Sha256.ComputeHash($Bytes)
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
<#
    .SYNOPSIS
        Sort the headers into alphebetical order and format them into a key:value string
#>
function Get-CanonicalHeaders($Headers){
    $SortedHeaders = [Ordered]@{}
    $Headers.Keys | Sort-Object | ForEach-Object {
        $Key = $_.ToLower()
        $SortedHeaders[$Key] = $Headers[$_] }
    return $SortedHeaders.GetEnumerator() | ForEach-Object {"$($_.Key):$($_.Value)"}
}

<#
    .SYNOPSIS
        Make AWS web request using 
#>
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
        
        [Parameter(Mandatory, Position = 4)]
        [string] $SessionToken,

        [Parameter(Position = 5)]
        [string]$AwsRegion = 'us-east-1',

        [Parameter(Position = 6)]
        [string] $AwsServiceName = 'execute-api',

        [Parameter(Position = 7,
            HelpMessage = "Optional additional headers, key-value pair"
        )]
        [hashtable] $Header,

        [Parameter(Position = 8)]
        [string] $Body
    )

    process{
        # Date formats
        $CurrentDate = ([datetime]::UtcNow).ToString("yyyyMMdd")
        $UniversalTime = ([datetime]::UtcNow).ToString("yyyyMMddTHHmmssZ")
        
        #Length of the payload/body for encoding in the header
        $BodyBytes = ([System.Text.Encoding]::Utf8.getbytes($Body).Length)
        
        #Cast the URI into a digestable format
        $RequestUri = [System.Uri]$Uri
        $ResourcePath = $RequestUri.Localpath
        
        #If querying mulitple items, format into a single line joined by '&'
        $QueryString = $RequestUri.Query
        if (-not [string]::IsNullOrEmpty($QueryString)){
            #Split the query into each key:value
            $QueryParams = $QueryString.TrimStart('?') -split '&' | ForEach-Object {
                $query = $_.split('=')
                $EncodedKey = [System.Web.HttpUtility]::UrlEncode($query[0])
                #If using a query without a value (http://s3.amazonaws.com/examplebucket?acl) set value to null (acl='')
                if ($query.Length -eq 1){
                    "$EncodedKey=''"
                }
                else{
                    $EncodedValue = [System.Web.HttpUtility]::UrlEncode($query[1])
                    "$EncodedKey=$EncodedValue"
                }
            } | Sort-Object
            $CanonicalQuery = $queryParams -join '&'
        }

        #Create a hashtable to accommodate custom headers & the ability to sort them
        $CanonicalHeaders = @{}
        #Required Headers    
        $CanonicalHeaders["host"] = $requestUri.Authority
        $CanonicalHeaders["x-amz-date"] = $UniversalTime
        $CanonicalHeaders["x-amz-security-token"] = $SessionToken
        #Modify headers/body depending on the method
        switch ($Method) {
            {'GET', 'DELETE' -eq $_} { $Body = ""}
            {'PUT', 'POST' -eq $_} {
                $CanonicalHeaders["content-length"] = $BodyBytes
                $CanonicalHeaders["content-type"] = "application/json"
            }
        }

        #If custom headers are required, add them to the hashtable
        if ($null -ne $Header) {
            $header.GetEnumerator().ForEach({$CanonicalHeaders[$($_.Key)]=$($_.Value)})
        }
        $SortedCanonicalHeaders = Get-CanonicalHeaders($Canonicalheaders)
        #Create a list of the header's keys joined with ';'
        $HeaderKeys = [System.Collections.Generic.List[string]]::new()
        $SortedCanonicalHeaders | ForEach-Object { $HeaderKeys.add( $_.split(":")[0]) }
        $HeaderKeys = $HeaderKeys -join ';'

        #Put the required Canonical Request together and converted to Hex SHA256
        $CanonicalRequest = @(
            $Method
            $ResourcePath
            $CanonicalQuery
            $SortedCanonicalHeaders
            ''
            $HeaderKeys
            Get-Sha256 -Body $Body
        ) -join "`n"

        $CanonicalRequestSha = Get-Sha256 -Body $CanonicalRequest

        #HMAC SHA256 the Scope/SignedString together
        $CredentialScope = "$($CurrentDate)/$($AwsRegion)/$($AwsServiceName)/aws4_request"
        $SignedString = ("AWS4-HMAC-SHA256",
                        $UniversalTime,
                        $CredentialScope,
                        $CanonicalRequestSha) -join "`n"
        $SigningKey = Get-AwsSignatureKey -AccessKey $AwsAccessKey -Region $AwsRegion -ServiceName $AwsServiceName
        $EncodedSignedKey = Get-HmacSha256Hash -Key $SigningKey -Data $SignedString
        
        #Format the signed key into the signature
        $Signature = [System.BitConverter]::ToString($EncodedSignedKey).Replace('-', '').ToLower()

        #Format the request header, skipping host key
        $RequestHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $SortedCanonicalHeaders | ForEach-Object {
            $key = $_.Split(":")[0]
            $value = $_.Split(":")[1]
            if ($key -ne "host"){
                $RequestHeaders.add($key,$value)
            }
        }
        
        #Put all the pieces together in the header
        $RequestHeaders.add("authorization", "AWS4-HMAC-SHA256 Credential=$($AWSAccessID)/$($CurrentDate)/$($AwsRegion)/$($AwsServiceName)/aws4_request, SignedHeaders=$($HeaderKeys), Signature=$($Signature)")
        
        #Attach the body if using PUT/POST
        switch ($Method) {
            {'GET', 'DELETE' -eq $_} { $Result = Invoke-RestMethod -Uri $Uri -Method $Method -Headers $RequestHeaders -SkipHeaderValidation }
            {'PUT', 'POST' -eq $_} { $Result = Invoke-RestMethod -Uri $Uri -Body $Body -Method $Method -Headers $RequestHeaders -SkipHeaderValidation}
        }
        return $Result
    }
}