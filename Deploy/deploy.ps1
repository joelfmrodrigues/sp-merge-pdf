
#region Parameters
Param(
    [Parameter(Mandatory)]
    [String] $TenantName,

    [Parameter(Mandatory)]
    [String] $TenantId,
    
    [Parameter(Mandatory)]
    [String] $SubscriptionId,
    
    [Parameter(Mandatory)]
    [String] $SPOTenantId,
    
    [Parameter(Mandatory)]
    [String] $CertificatePassword,

    [Parameter(Mandatory)]
    [ValidateSet("loc", "dev", "qa", "uat", "prod")]
    [string] $Environment,
    
    [Parameter(Mandatory)]
    [string] $InstanceNumber,

    [Parameter(Mandatory)]
    [String] $AppName,

    [Parameter()]
    [String] $ResourceGroupName,

    [Parameter()]
    [String] $Location,

    [Parameter()]
    [switch] $SkipDependenciesInstall,

    [Parameter()]
    [switch] $SkipAzADAppCreation,
    
    [Parameter()]
    [switch] $SkipAllAzResourcesDeployment,

    [Parameter()]
    [switch] $SkipAzResourceGroupCreation,

    [Parameter()]
    [switch] $SkipAzFunctionDeployment
    
)
#endregion Parameters


#region Imports

# import utils
. $PSScriptRoot/Utils/Azure.ps1
. $PSScriptRoot/Utils/DependenciesChecker.ps1

#endregion Imports


#region Dependencies

if (!$SkipDependenciesInstall) {   
    GetModules -ModuleToCheck PnP.PowerShell
    GetModules -ModuleToCheck Az
}

#endregion Dependencies


#region Variables

# Handle spaces in variables
$AppName = $AppName.Replace(" ", "").ToLower()
$AzADAppName = "$AppName-$Environment-$InstanceNumber"
$Location = $Location.Replace(" ", "").ToLower()
$ResourceGroupName = $ResourceGroupName.Replace(" ", "")

$appId = $null

#endregion Variables


######################
## Start deployment ##
######################

Write-Host "Governance App" -ForegroundColor Magenta
Write-Host "### DEPLOYMENT SCRIPT STARTED ###" -ForegroundColor Magenta


#region AAD App

# Create/update app registration if required
if (!$SkipAzADAppCreation) {
    .\DeployAzADApp.ps1 `
        -TenantName $TenantName `
        -AppName $AzADAppName `
        -CertificatePassword $CertificatePassword `

}

# logout of any previous sessions
Write-Host "Trying to disconnect previously open connections..." -ForegroundColor White
az logout
Write-Host "Azure CLI sign-in for the SharePoint tenant..." -ForegroundColor Yellow
$spocliLogin = az login --allow-no-subscriptions

# check if app with same name already exists
$appRegistrationCollection = az ad app list --display-name $AzADAppName
$appRegistration = $appRegistrationCollection | ConvertFrom-Json
Write-Host "Found $($appRegistration.Count) Azure AD app registrations with the name specified" -ForegroundColor Green

# App already exists -> set AppId variable
if ($appRegistration.Count -gt 0) {
    $appId = $appRegistration.appId
    Write-Host "AppId: $appId"
}
else {
    exit
}

#endregion AAD App


#region Azure

if (!$SkipAllAzResourcesDeployment) {   

    #region azure Connections

    # Initialise connection if SPO and Azure tenants are different - Azure CLI
    if ($TenantId -ne $SPOTenantId) {   
        Write-Host "Trying to disconnect previously open connections..." -ForegroundColor White
        az logout
        Write-Host "Azure CLI sign-in..." -ForegroundColor Yellow
        $cliLogin = az login --allow-no-subscriptions
    }
    az account set --subscription $SubscriptionId # set subscription
    
    # validate azure location
    ValidateAzureLocation -Location $Location
    Write-Host "Connected to Azure" -ForegroundColor Green

    #endregion azure Connections

    # Create resource group if required
    if (!$SkipAzResourceGroupCreation) {
        
        Write-Host "Creating resource group $ResourceGroupName..." -ForegroundColor Yellow
        az group create -l $Location -n $ResourceGroupName
        Write-Host "Created resource group" -ForegroundColor Green
    }
    
    # Deploy Function
    if (!$SkipAzFunctionDeployment) {

        # array of additional template parameters
        $functionTemplateParameters = @(
            "spoTenantId=$SPOTenantId"
            "authId=$appId"
            "authSecret=$CertificatePassword"
            "appId=$AppId"
            "appName=$AppName"
            "environment=$Environment"
            "instanceNumber=$InstanceNumber"
        )
        # array of additional app settings
        $functionAppSettings = @(
            "AuthType=AzureADAppOnly"
            "SPOTenantId=$SPOTenantId"
            "SPOTenantName=$TenantName"
        )
        .\DeployAzFunction.ps1 `
            -SubscriptionId $SubscriptionId `
            -Environment $Environment `
            -InstanceNumber $InstanceNumber `
            -CertificatePassword $CertificatePassword `
            -TemplateParameters $functionTemplateParameters `
            -AppSettings $functionAppSettings `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -AppName $AppName 
    }

    Write-Host "Azure resources deployed`n### AZURE RESOURCES DEPLOYMENT COMPLETE ###" -ForegroundColor Green
}
#endregion Azure

Write-Host "DEPLOYMENT COMPLETED SUCCESSFULLY" -ForegroundColor Green