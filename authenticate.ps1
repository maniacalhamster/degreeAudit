# Load the Auxiliary scripts with network call & user credential related helper functions
. ./credentials.ps1;
. ./network.ps1;

# Helper function to handle parsing response contents for a pattern
function Get-TargetString($source, $pattern)
{
    return ($source | Select-String $pattern).Matches.Value;
}

# Target URL that requires authentication is the UCSD Student Degree Audit page
#  - Start the process with a GET request, storing the session in a variable
$audit_url  = "https://act.ucsd.edu/studentDarsSelfservice";
$audit_resp = Invoke-WebRequest -UseBasicParsing -Uri $audit_url -SessionVariable session;

# Step 2: Initiate the login process (A) by POSTing user credentials to the redirected url
#  - On Success: redirects to DUO (B) portion of login url
#  - Response contains data[host, sig_request, post_action] info
$auth_one_url   = Get-AbsoluteURI $audit_resp;
$data           = Get-Credentials;
$auth_one_data  = @{
    'urn:mace:ucsd.edu:sso:username' = $data.username;
    'urn:mace:ucsd.edu:sso:password' = $data.password;
    '_eventId_proceed' = '';
};
$auth_one_resp  = Invoke-PostRequest -url $auth_one_url -session $session -payload $auth_one_data;
$auth_two_url   = Get-AbsoluteURI $auth_one_resp;

# Step 3: Continue with DUO portion (B) of login by
#  - Generate payload with TX (first 1/2 of sig_request), parent(post_action), version
#  - Initiate DUO part 1 with POST
#  - On Success: Server responds with form data for endpoint-health-form and login-form
$content            = $auth_one_resp.Content;
$data_host          = Get-TargetString $content "(?<=data-host=`").*(?=`")";
$data_sig_request   = Get-TargetString $content "(?<=data-sig-request=`").*(?=`")";
$data_post_action   = Get-TargetString $content "(?<=data-post-action=`").*(?=`")";

$tx         = Get-TargetString $data_sig_request "TX.*(?=:)";
$version    = "2.3";

$duo_url    = 'https://{0}/frame/web/v1/auth?tx={1}&parent={2}&v={3}';
$duo_url    = $duo_url -f $data_host, $tx, $(Get-URLEncoding $auth_two_url), $version;

$duo_data   = @{
    'tx'        = $tx;
    'parent'    = $auth_two_url;
}

$null       = Invoke-GetRequest $duo_url;
$duo_resp   = Invoke-PostRequest $duo_url $session $duo_data;

# Step 4: Continue DUO portion by sending push notification (B2) by 
#  - Generate payload with eh_data from prev response
#  - Initiate DUO part 2 with eh-form POST, then login-form POST
#  - On Success: Returns prompt Status & TXID in JSON format
#  - On Failure: Notify user of failure to send duo push notification
$duo_resp_content   = Get-HTMLFile $duo_resp.content;
$eh_data            = @{};
$duo_resp_content.getElementById('endpoint-health-form').getElementsByTagName('input') | ForEach-Object {
    if (-not ($eh_data.Contains($_.Name))) {
        $eh_data.Add($_.Name, $_.DefaultValue);
    }
} 
$eh_resp        = Invoke-PostRequest $duo_url $session $eh_data;

$prompt_url     = ((Get-AbsoluteURI $eh_resp) -split ".sid=");
$sid            = Get-URLDecoding $prompt_url[1];
$prompt_url     = $prompt_url[0];
$prompt_data    = @{
    'sid' = $sid;
    'device' = 'phone1';
    'factor' = 'Duo Push';
    'out_of_date' = 'False';
    'days_out_of_date' = 0;
    'days_to_block' = 'None';
};
$prompt_resp    = Invoke-PostRequest $prompt_url $session $prompt_data;
$prompt_content = $prompt_resp.content | ConvertFrom-Json;
if (!($prompt_content.response.txid)) {
    Write-Error "Missing TXID response from DUO prompt request`n$prompt_content" -ErrorAction Stop;
}
Write-Host -ForegroundColor Green "Succesfully initiated DUO authentication";

# Step 5: Begin a 3-part sequence of POST requests to check on status of push request
#  - on Failure: notify user of issue with DUO Push prompt and stop the script
#
#    5.1: First POST (status) checks if prompt was sent 
#  - on Failure: notify user of issue with 
# 
#    5.2: second POST (status) waits until user responds on device (until timeout)
#  - on Failure: notify user of timeout and stop the script
#
#    5.3: Third POST (result = status_url/TXID) response contains AUTH portion of sig_response
#  - on Failure: notify user of missing sig_response (AUTH is null)
$status_url = $prompt_url -replace 'prompt', 'status';
$status_data    = @{
    'sid'   = $sid;
    'txid'  = $prompt_content.response.txid;
}
$status_resp_one    = Invoke-PostRequest $status_url $session $status_data;
$status_content_one = $status_resp_one.content | ConvertFrom-Json;
if ($status_content_one.response.status_code -ne 'pushed') {
    Write-Error "Issue with sending DUO Push prompt`n$status_content_one" -ErrorAction Stop;
}
Write-Host -ForegroundColor Green $status_content_one.response.status;

$status_resp_two    = Invoke-PostRequest $status_url $session $status_data;
$status_content_two = $status_resp_two.content | ConvertFrom-Json;
if ($status_content_two.response.result -eq 'FAILURE') {
    Write-Error "Timeout on DUO Push prompt`n$status_content_two" -ErrorAction Stop;
}
Write-Host -ForegroundColor Green $status_content_two.response.status;

$result_url     = "$status_url/{0}" -f $prompt_content.response.txid;
$result_data    = @{'sid'=$sid};
$result_resp    = Invoke-PostRequest $result_url $session $result_data;
$result_content = $result_resp | ConvertFrom-Json;
if ($null -eq $result_content.response.cookie) {
    Write-Error "Missing AUTH from sig_response on result (special status) request`n$result_content" -ErrorAction Stop;
}
Write-Host -ForegroundColor Green "Succesfully completed DUO authentication";

# Part 6: Finish DUO portion by piecing together the signal response to auth_two_url (B)
#  - sig_response = AUTH (result_resp) + APP (data_sig_request from auth_one_resp)
#  - On Success: Response contains a url (shibboleth) and data (SAMLResponse)
$sig_resp       = "{0}:{1}" -f $result_content.response.cookie, $(Get-TargetString $data_sig_request 'APP.*');
$auth_two_data  = @{
    '_eventId'      = 'proceed';
    'sig_response'  = $sig_resp;
}
$auth_two_resp  = Invoke-PostRequest $auth_two_url $session $auth_two_data;

# Part 7: Finalize the authentication process and access target url contents
$auth_two_content   = Get-HTMLFile $auth_two_resp.Content;
$shibboleth_url     = $auth_two_content.getElementsByTagName('form')[0].action;
$shibboleth_data    = @{
    RelayState      = $auth_two_content.getElementsByName('RelayState')[0].value;
    SAMLResponse    = $auth_two_content.getElementsByName('SAMLResponse')[0].value;
}
$shibboleth_resp    = Invoke-PostRequest $shibboleth_url $session $shibboleth_data;

return $session;