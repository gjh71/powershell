function Disable-SslVerification
{
    #UGLY workaround: https://www.craig-tolley.co.uk/2016/02/09/using-add-type-in-a-powershell-script-that-is-run-as-a-scheduled-task/
    $copyTmp = $env:TMP
    $env:TMP = "C:\TMP"
    if (!(Test-Path $env:TMP))
    {
        New-Item -Path $env:TMP -ItemType Directory | Sort-Object | Out-Null #added dummy 'sort-object' to prevent warning "an empty pipe is not allowed"
    }
    if (-not ([System.Management.Automation.PSTypeName]"TrustEverything").Type)
    {
        Add-Type -TypeDefinition  @"
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public static class TrustEverything
{
    private static bool ValidationCallback(object sender, X509Certificate certificate, X509Chain chain,
        SslPolicyErrors sslPolicyErrors) { return true; }
    public static void SetCallback() { System.Net.ServicePointManager.ServerCertificateValidationCallback = ValidationCallback; }
    public static void UnsetCallback() { System.Net.ServicePointManager.ServerCertificateValidationCallback = null; }
}
"@
    }
    [TrustEverything]::SetCallback()
    $env:TMP = $copyTmp
}
function Enable-SslVerification
{
    if (([System.Management.Automation.PSTypeName]"TrustEverything").Type)
    {
        [TrustEverything]::UnsetCallback()
    }
}

function Set-TlsSecurityProtocol
{
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

function Get-BasicAuthenticationHeader
{
    param(
        [string] $usernm,
        [string] $userpwd
    )
    $credstring = "{0}:{1}" -f $usernm, $userpwd
    $credbytes = [System.Text.Encoding]::ASCII.GetBytes($credstring)
    $credbase64 = [System.Convert]::ToBase64String($credbytes)
    $credAuthValue = "Basic {0}" -f $credbase64
    $header = @{ Authorization = $credAuthValue}
    return $header
}

Function Get-AADToken {
    # https://blog.tyang.org/2017/06/12/powershell-function-to-get-azure-ad-token/       
      [CmdletBinding()]
      [OutputType([string])]
      PARAM (
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateScript({
              try 
              {
                [System.Guid]::Parse($_) | Out-Null
                $true
              } 
              catch 
              {
                $false
              }
        })]
        [Alias('tID')]
        [String]$TenantID,
    
        [Parameter(Position=1,Mandatory=$true)][Alias('cred')]
        [pscredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential,
        
        [Parameter(Position=0,Mandatory=$false)][Alias('type')]
        [ValidateSet('UserPrincipal', 'ServicePrincipal')]
        [String]$AuthenticationType = 'UserPrincipal'
      )
      Try
      {
        $Username       = $Credential.Username
        $Password       = $Credential.Password

        Import-Module "C:\Program Files\WindowsPowerShell\Modules\AzureRM.profile"
    
        If ($AuthenticationType -ieq 'UserPrincipal')
        {
          # Set well-known client ID for Azure PowerShell
          $clientId = '1950a258-227b-4e31-a9cf-717495945fc2'
    
          # Set Resource URI to Azure Service Management API
          $resourceAppIdURI = 'https://management.azure.com/'
    
          # Set Authority to Azure AD Tenant
          $authority = 'https://login.microsoftonline.com/common/' + $TenantID
          Write-Verbose "Authority: $authority"
    
          $AADcredential = [Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential]::new($UserName, $Password)
          $authContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new($authority)
          $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$clientId,$AADcredential)
          $Token = $authResult.Result.CreateAuthorizationHeader()
        } else {
          # Set Resource URI to Azure Service Management API
          $resourceAppIdURI = 'https://management.core.windows.net/'
    
          # Set Authority to Azure AD Tenant
          $authority = 'https://login.windows.net/' + $TenantId
    
          $ClientCred = [Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential]::new($UserName, $Password)
          $authContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new($authority)
          $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$ClientCred)
          $Token = $authResult.Result.CreateAuthorizationHeader()
        }
        
      }
      Catch
      {
        Throw $_
        $ErrorMessage = 'Failed to aquire Azure AD token.'
        Write-Error -Message $ErrorMessage
      }
      $Token
    }
    
    function Get-AzureApiHeader
    {
        param(
            [Parameter(Mandatory=$true)]
            $token
        )
        $rv = @{ Authorization = $token;'Accept'='application/json'}
        return $rv
    }
    
