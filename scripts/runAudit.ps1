# Using all paths relative to root of the git repository
$root   = git rev-parse --show-toplevel;

Import-Module "$root/modules/network.psm1";
Import-Module "$root/modules/credentials.psm1";

$audit_resp = . ./authenticate.ps1;

$list_url   = "{0}/audit/list.html" -f $audit_url;
$list_resp  = Invoke-GetRequest $list_url $session;
$old_read_link  = Get-TargetString $list_resp.Content "(?<=href=`").*read.html.*(?=`")";

$create_url = Get-AbsoluteURI $audit_resp;
$create_data    = @{
    "includeInProgressCourses"  ='true';
    'includePlannedCourses'     ='';
    'sysIn.evalsw'              ='S';
    'auditTemplate'             ='htm!!!!htm';
    'sysIn.fdpmask'             ='';
    'useDefaultDegreePrograms'  ='true';
    'pageRefresh'               ='false';
}
$create_resp = Invoke-PostRequest $create_url $session $create_data;

$reload_url = Get-AbsoluteUri $create_resp;
do{
    $reload_resp = Invoke-GetRequest $reload_url $session;
    $read_link = Get-TargetString $reload_resp.Content "(?<=href=`").*read.html.*(?=`")";
    Start-Sleep 1;
} while($old_read_link -eq $read_link);

$read_url   = "{0}/audit/{1}" -f $audit_url, $read_link;
$read_resp  = Invoke-GetRequest $read_url $session;
$read_resp.Content > "$root/audit.html";