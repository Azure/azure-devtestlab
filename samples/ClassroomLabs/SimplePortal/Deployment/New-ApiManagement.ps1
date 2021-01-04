[CmdletBinding()]
param
(
    [Parameter(Mandatory=$true, HelpMessage="Resource Group to deploy the API management service")]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName,

    [Parameter(Mandatory=$true, HelpMessage="New API Management Service name")]
    [ValidateNotNullOrEmpty()]
    [string] $ApimServiceName,

    [Parameter(Mandatory=$false, HelpMessage="If we're creating a new API management service, need to provide the organization name")]
    [ValidateNotNullOrEmpty()]
    [string] $OrganizationName,

    [Parameter(Mandatory=$false, HelpMessage="If we're creating a new API management service, need to provide the AdministratorEmail address")]
    [ValidateNotNullOrEmpty()]
    [string] $AdministratorEmail,

    [Parameter(Mandatory=$true, HelpMessage="Open API Spec JSON file name")]
    [ValidateNotNullOrEmpty()]
    [string] $OpenApiSpecsFilename,

    [Parameter(Mandatory=$false, HelpMessage="The name of the API to create in the API Management Service")]
    [ValidateNotNullOrEmpty()]
    [string] $ApiName = "SimplePortal",

    [Parameter(Mandatory=$true, HelpMessage="The name of the Azure AD Application, will be used if it exists - or created if it doesn't")]
    [ValidateNotNullOrEmpty()]
    [string] $AzureAdApplicationName,

    [Parameter(Mandatory=$false, HelpMessage="The client secret for the Azure AD application.  Only needed if using an existing AAD application")]
    [ValidateNotNullOrEmpty()]
    [string] $AzureAdApplicationClientSecret

)

# Lets stop the script for any errors
$ErrorActionPreference = "Stop"

# --------------  SOME DEFAULT VALUES  ----------------------
$tenantId = (Get-AzContext).Tenant.Id
$ApiPath = "simpleportal"

# --------------  CHECK PARAMETERS --------------------------

# Confirm already connected to Azure AD (this should throw an error if not connected
Get-AzureAdUser -Top 1 | Out-Null

# Check if the AAD Application already exists
$azureAdApplication = Get-AzureADApplication -SearchString $AzureAdApplicationName

if ($azureAdApplication) {
    # since we have the AAD application, we need to make sure parameters are correct
    if (-not $AzureAdApplicationClientSecret) {
        Write-Error "[PARAMETER VALIDATION] Azure AD Application exists (won't be created), so AzureAdApplicationClientSecret parameter must be provided"
    }
}


# ---------------------- INITIAL CREATE----------------------

# First confirm the resource group exists
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if (-not $rg) {
    Write-Error "[INITIAL CREATE] Unable to find resource group '$ResourceGroupName'"
}

# If the API management service doesn't exist, create a new one
if (-not (Get-AzResource -Name $ApimServiceName -ResourceType "Microsoft.ApiManagement/service" -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue))
{
    Write-Host "[INITIAL CREATE] Creating the API Management Service - it takes time to activate the service, please wait..." -Foreground Green
    $APIM = New-AzApiManagement -ResourceGroupName $ResourceGroupName `
                                -Name $ApimServiceName `
                                -Location $rg.Location `
                                -Organization $OrganizationName `
                                -AdminEmail $AdministratorEmail `
                                -Sku Developer

    if (-not $APIM) {
        Write-Error "[INITIAL CREATE] Unable to create a new API management service.."
    }

    # Let's remove the Echo API that comes with the default
    Get-AzApiManagementApi -Context $context -Name "Echo API" | ForEach-Object {
        Remove-AzApiManagementApi -Context $context -ApiId $_.ApiId | Out-Null
    }
}

# Create the API Management context
$context = New-AzApiManagementContext -ResourceGroupName $ResourceGroupName -ServiceName $ApimServiceName

# ---------------------- APIs ----------------------

# First see if the API already exists, if so - delete it
$api = Get-AzApiManagementApi -Context $context -Name $apiName
if ($api) {
    Write-Host "[IMPORT] The API '$apiName' already exists, removing it so we can re-apply latest..."
    $result = Remove-AzApiManagementApi -Context $context -ApiId $api.ApiId
}

# import api from OpenAPI Specs
Write-Host  "[IMPORT] Importing OpenAPI: $OpenApiSpecsFilename "
$api = Import-AzApiManagementApi -Context $context `
                                 -SpecificationPath $OpenApiSpecsFilename `
                                 -SpecificationFormat OpenApi `
                                 -Path $apiPath

Write-Host  "[IMPORT] Imported API: $apiName with ApiId: $($api.ApiId) " 

# ---------------------- PRODUCTS ----------------------

Write-Host "[PRODUCTS] Checking for existing 'simpleportal' product..."
$apimProduct = Get-AzApiManagementProduct -Context $context | Where-Object {$_.ProductId -ieq "SimplePortal"}
if (-not $apimProduct) {
    Write-Host "[PRODUCTS]  'SimplePortal' product in APIM service does not exist, creating it..."
    $result = New-AzApiManagementProduct -Context $context `
                                         -ProductId "SimplePortal" `
                                         -Title "SimplePortal" `
                                         -Description "Simple Portal APIs" `
                                         -SubscriptionRequired $true `
                                         -ApprovalRequired $false `
                                         -SubscriptionsLimit 1 `
                                         -State Published

    $result = Add-AzApiManagementApiToProduct -Context $context `
                                              -ProductId $apimProduct.ProductId `
                                              -ApiId $api.ApiId

}

# -------------- AAD APPLICATION ENTRY -----------------

# Have the name & secret - let's see if it already exists (search by name).  If not, create it.
Write-Host "[AAD AAP IDENTITY] Checking for existing '' application in AAD..."
$azureAdApplication = Get-AzureADApplication -SearchString $AzureAdApplicationName

if (-not $azureAdApplication) {
    Write-Host "[AAD AAP IDENTITY] Application doesn't exist, creating it... "

    $replyURLs = @("https://localhost:44344",
                   "http://localhost:3000",
                   "$($APIM.DeveloperPortalUrl)/signin-oauth/code/callback/simpleportaluser",
                   "$($APIM.DeveloperPortalUrl)/signin-oauth/implicit/callback",
                   "$($APIM.PortalUrl)/signin-aad")

    $azureAdApplication = New-AzureADApplication -DisplayName $AzureAdApplicationName `
                                                 -ReplyUrls $replyURLs `
                                                 -Oauth2AllowImplicitFlow $true

    Write-Host "[AAD AAP IDENTITY] Updating settings for Application... "
    
    # Update some key properties on the AzureAD Application
    Set-AzureADApplication -ObjectId $azureAdApplication.ObjectId -IdentifierUris @("api://$($azureAdApplication.AppId)")

    # Adding in the Oauth2 Permission Scopes is tricky
    $Scopes = @"
    [
        {
            "Description": "Full access to simple portal",
            "DisplayName": "Full access",
            "Value": "SimplePortal.All"
        },
        {
            "Description": "Create, read, update and delete class templates",
            "DisplayName": "All class templates operations",
            "Value": "SimplePortal.ClassTemplates.All"
        },
        {
            "Description": "Read available classes and create labs for those classes.",
            "DisplayName": "Read and create classes",
            "Value": "SimplePortal.Classes.All"
        },
        {
            "Description": "Create classes using Simple Portal",
            "DisplayName": "Create classes",
            "Value": "SimplePortal.Classes.Create"
        },
        {
            "Description": "Read which classes can be created.",
            "DisplayName": "Read classes",
            "Value": "SimplePortal.Classes.Read"
        },
        {
            "Description": "Allows the app to read class templates",
            "DisplayName": "Read class templates",
            "Value": "SimplePortal.ClassTemplates.Read"
        },
        {
            "Description": "Allow users to write class templates",
            "DisplayName": "Write class templates",
            "Value": "SimplePortal.ClassTemplates.Write"
        }
    ]

"@ | ConvertFrom-Json

    $Scopes | ForEach-Object {
        $azureAdApplication.Oauth2Permissions.Add((New-Object -TypeName "Microsoft.Open.AzureAD.Model.OAuth2Permission" -ArgumentList $_.Description, $_.DisplayName, (New-Guid).Guid, $true, "User", $_.Description, $_.DisplayName, $_.Value))
    }

    Set-AzureADApplication -ObjectId $azureAdApplication.ObjectId -Oauth2Permissions $azureAdApplication.Oauth2Permissions

    $passwordCredential = New-AzureADApplicationPasswordCredential -ObjectId $azureAdApplication.ObjectId
    $AzureAdApplicationClientSecret = $passwordCredential.Value

    Write-Host "[AAD AAP IDENTITY] Application '$($azureAdApplication.DisplayName)' created & updated, password is '$AzureAdApplicationClientSecret'.  Please save this!" -ForegroundColor Yellow

}

# NOTE:  I didn't configure the developer portal identity, since we shouldn't need it via these scripts


# -------------- AUTHORIZATION SERVER (OAUTH 2.0) -----------------

Write-Host "[AUTHORIZATION SERVERS] Checking for Auth Servers in APIM..."

$authServers = @"
    [
        {
            "Name": "SimplePortal-Admin",
            "Description": "Simple Portal Admin",
            "DefaultScope": "SimplePortal.ClassTemplates.Write"
        },
        {
            "Name": "SimplePortal-User",
            "Description": "Simple Portal User",
            "DefaultScope": "SimplePortal.All"
        }
    ]

"@ | ConvertFrom-Json

$authServers | ForEach-Object {
    $authServerName = $_.Name
    $authServer = Get-AzApiManagementAuthorizationServer -Context $context | Where-Object {$_.Name -ieq $authServerName}
    if (-not $authServer) {
        Write-Host "[AUTHORIZATION SERVERS] Auth Server '$($_.Description)' in doesn't exist, creating it..."
    
        $authServer = New-AzApiManagementAuthorizationServer -Context $context `
                               -Name $_.Name `
                               -Description $_.Description `
                               -ClientRegistrationPageUrl "http://localhost" `
                               -GrantTypes "Implicit" `
                               -AuthorizationEndpointUrl "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize" `
                               -AuthorizationRequestMethods @("GET", "POST") `
                               -TokenEndpointUrl "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
                               -ClientAuthenticationMethods "Body" `
                               -AccessTokenSendingMethods "AuthorizationHeader" `
                               -DefaultScope "api://$($azureAdApplication.AppId)/$($_.DefaultScope)" `
                               -ClientId $azureAdApplication.AppId `
                               -ClientSecret $AzureAdApplicationClientSecret
    }
}

# Wire-up the Auth Server in case it's not already connected
Set-AzApiManagementApi -Context $context -ApiId $api.ApiId -AuthorizationServerId $authServer.ServerId


# -------------- APIM BACK END APIs -----------------

