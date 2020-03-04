function Get-AzureRmCachedAccessToken() {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Off

    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if (-not $azureRmProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."
    }

    $currentAzureContext = Get-AzureRmContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Subscription.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Subscription.TenantId)
    return $token.AccessToken
}

function GetHeaderWithAuthToken {

    $authToken = Get-AzureRmCachedAccessToken
    Write-Debug $authToken

    $header = @{
        'Content-Type'  = 'application/json'
        "Authorization" = "Bearer " + $authToken
        "Accept"        = "application/json;odata=fullmetadata"
    }

    return $header
}

$ApiVersion = 'api-version=2019-01-01-preview'


$authHeaders = GetHeaderWithAuthToken

$Uri = 'https://management.azure.com/subscriptions/d5e481ac-7346-47dc-9557-f405e1b3dcb0/providers/Microsoft.LabServices/labaccounts'
$fullUri = $Uri + '?' + $ApiVersion

$result = Invoke-WebRequest -Uri $FullUri -Method 'GET' -Headers $authHeaders  -UseBasicParsing
$result.Content | Out-File "accounts.json"
$resObj = $result.Content | ConvertFrom-Json

return $resObj.Value | Sort-Object -Property id

