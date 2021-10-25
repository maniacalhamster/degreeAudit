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
