# Streamlines making a POST request
# - Logs request type and url
# - Maintains a session
function Invoke-POST($url, $session, $payload)
{
    Write-Host ("POST to:`t{0}" -f $url);
    $header = @{"Content-Type" = "application/x-www-form-urlencoded"};
    return Invoke-WebRequest -UseBasicParsing -Uri $url -WebSession $session -Method POST -Headers $header -Body $payload;
}

# Streamlines making a GET request
# - Logs request type and url
# - Maintains a session
function Invoke-GET($url, $session)
{
    Write-Host ("GET from:`t{0}" -f $url);
    return Invoke-WebRequest -UseBasicParsing -Uri $url -WebSession $session;
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