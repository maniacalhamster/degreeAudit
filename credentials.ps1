# Main function to get user login credentials
#  - Tries to read from a datafile first
#  - Otherwise, prompts user for login creds --> saves to file --> returns data
function Get-Credentials() 
{
    $datafile = "logincreds.json";

    if (Test-Path $datafile) {
        return Read-FileData $datafile;
    }

    $username = Read-Host -Prompt "Username";
    $password = Read-Host -Prompt "Password" -AsSecureString;

    Write-FileData $datafile $($username | ConvertTo-SecureString -AsPlaintext -Force) $password;

    return @{
        username=$username;
        password=$(Get-PlainText $password);
    }
}

# Helper function for reading data from file
#  - Uses a helper function to read encryped data
function Read-FileData($filename)
{
    $data = Get-Content $filename | ConvertFrom-Json;

    $unameSecure = $data.username | ConvertTo-SecureString;
    $data.username = Get-Plaintext $unameSecure;

    $passSecure = $data.password | ConvertTo-SecureString;
    $data.password = Get-Plaintext $passSecure;

    return $data;
}

# Helper function for writing data to file
#  - Encrypts plaintext as a secure-string before writing
function Write-FileData($filename, [SecureString] $username, [SecureString] $password) {
    @{
        username=$($username | ConvertFrom-SecureString);
        password=$($password | ConvertFrom-SecureString);
     } | ConvertTo-Json > $filename;
}

# Helper function for consistently converting a secure-string into plaintext
function Get-Plaintext($sec)
{
    if ((Get-Host).Version.Major -gt 5) {
        $plaintext = $sec | ConvertFrom-SecureString -AsPlainText;
    } else {
        $plaintext = [System.Net.NetworkCredential]::new('', $sec).Password;
    }

    return $plaintext;
}

# Helper function for setting cookie data by writing to file
#  - written as a secure-string after serializing from a CookieContainer obj
function Set-Cookies($cookies) {
    $stream     = [System.IO.MemoryStream]::new();
    [System.Runtime.Serialization.Formatters.Binary.BinaryFormatter]::new().Serialize($stream, $cookies);
    $bytes      = [byte[]]::new($stream.Length);
    $stream.Position = 0;
    $stream.Read($bytes, 0, $stream.Length);
    [System.Convert]::ToBase64String($bytes) | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString > 'cookies.dat';
}

# Helper function for getting cookie data by reading from file
#  - converted back to plaintext and deserialized back into a CookieContainer ob
function Get-Cookies() {
    $bytes  = [System.Convert]::FromBase64String($(Get-Plaintext $(Get-Content 'cookies.dat' | ConvertTo-SecureString)));
    $stream = [System.IO.MemoryStream]::new($bytes);
    return [System.Runtime.Serialization.Formatters.Binary.BinaryFormatter]::new().Deserialize($stream);
}