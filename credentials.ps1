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
        username=$([System.Uri]::EscapeDataString($username));
        password=$(Get-URLEncodedPlainText $password);
    }
}

# Helper function for reading data from file
#  - Uses a helper function to read encryped data
#  - Returns url-encoded data
function Read-FileData($filename)
{
    $data = Get-Content $filename | ConvertFrom-Json;

    $unameSecure = $data.username | ConvertTo-SecureString;
    $data.username = Get-URLEncodedPlaintext $unameSecure;

    $passSecure = $data.password | ConvertTo-SecureString;
    $data.password = Get-URLEncodedPlaintext $passSecure;

    return $data;
}

# Helper function for writing data to file
#  - Encrypts plaintext as a secure-string before writing
function Write-FileData($filename, $username, $password) {
    @{
        username=$($username | ConvertFrom-SecureString);
        password=$($password | ConvertFrom-SecureString);
     } | ConvertTo-Json > $filename;
}

# Helper function for consistently converting a secure-string into plaintext
# - additionally apply URL-encoding as well
function Get-URLEncodedPlaintext($sec)
{
    if ((Get-Host).Version.Major -gt 5) {
        $plaintext = $sec | ConvertFrom-SecureString -AsPlainText;
    } else {
        $plaintext = [System.Net.NetworkCredential]::new('', $sec).Password;
    }

    return [System.Uri]::EscapeDataString($plaintext);
}
