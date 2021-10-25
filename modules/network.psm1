# Streamlines making a POST request
# - Logs request type and url
# - Maintains a session
function Invoke-PostRequest($url, $session, $payload)
{
    Write-Host ("POST to:`t{0}" -f $url);
    $header = @{"Content-Type" = "application/x-www-form-urlencoded"};
    try {
        $resp = Invoke-WebRequest -UseBasicParsing -Uri $url -WebSession $session -Method POST -Headers $header -Body $payload;
    } catch {
        Write-Error "Error encountered`n$($Error[0])" -ErrorAction Stop;
    }
    return $resp;
}

# Streamlines making a GET request
# - Logs request type and url
# - Maintains a session
function Invoke-GetRequest($url, $session)
{
    Write-Host ("GET from:`t{0}" -f $url);
    try {
        $resp = Invoke-WebRequest -UseBasicParsing -Uri $url -WebSession $session;
    } catch {
        Write-Error "Error encountered`n$($Error[0])" -ErrorAction Stop;
    }
    return $resp;
}

# Performs URL-Encoding on input
function Get-URLEncoding($inp)
{
    Write-Host -ForegroundColor Yellow "Encoding:`t$inp";
    return [System.Web.HttpUtility]::UrlEncode($inp);
}

# Decodes a URL-Encoded input
function Get-URLDecoding($inp)
{
    Write-Host -ForegroundColor Yellow "Decoding: $inp";
    return [System.Web.HttpUtility]::UrlDecode($inp);
}

# Get Requested URI from Response
function Get-AbsoluteURI($response)
{
    if((Get-Host).Version.Major -eq 5){
        return $response.BaseResponse.ResponseUri.AbsoluteUri;
    } else {
        return $response.BaseResponse.RequestMessage.RequestUri.AbsoluteUri;
    }
}

# Get Authority/Base of URI from Response
function Get-AuthorityURI($response)
{
    if((Get-Host).Version.Major -eq 5){
        return $response.BaseResponse.ResponseUri.Authority;
    } else {
        return $response.BaseResponse.RequestMessage.RequestUri.Authority;
    }
}

# Get an HTML object from message stream
function Get-HTMLFile($content) {
    $html = New-Object -ComObject HTMLFile;
    $html.write([ref]'');
    $html.write([System.Text.Encoding]::Unicode.GetBytes($content));
    return $html;
}

Export-ModuleMember -Function Invoke-GetRequest;
Export-ModuleMember -Function Invoke-PostRequest;
Export-ModuleMember -Function Get-URLEncoding;
Export-ModuleMember -Function Get-URLDecoding;
Export-ModuleMember -Function Get-AbsoluteURI;
Export-ModuleMember -Function Get-AuthorityURI;
Export-ModuleMember -Function Get-HTMLFile;