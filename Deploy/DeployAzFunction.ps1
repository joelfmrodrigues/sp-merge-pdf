
# Parameters
Param(

    [Parameter(Mandatory)]
    [String] $SubscriptionId,
    
    [Parameter(Mandatory)]
    [ValidateSet("loc", "dev", "qa", "uat", "prod")]
    [string] $Environment,
    
    [Parameter(Mandatory)]
    [string] $InstanceNumber,

    [Parameter()]
    [String] $CertificatePassword,
    
    [Parameter()]
    [String[]]$TemplateParameters = @(),

    [Parameter()]
    [String[]]$AppSettings = @(),

    [Parameter(Mandatory)]
    [String] $ResourceGroupName,

    [Parameter(Mandatory)]
    [String] $Location,

    [Parameter(Mandatory)]
    [String] $AppName,

    [Parameter()]
    [switch] $SkipARMTemplateDeployment,

    [Parameter()]
    [switch] $SkipCertificateDeployment,
    
    [Parameter()]
    [switch] $SkipAppSettingsDeployment,

    [Parameter()]
    [switch] $SkipMSBuild,
    
    [Parameter()]
    [switch] $SkipZipDeployment

)

# import utils
. $PSScriptRoot/Utils/MSBuildTools.ps1

# Global variables
# Handle spaces in variables
$AppName = $AppName.Replace(" ", "").ToLower()
$Location = $Location.Replace(" ", "").ToLower()
$ResourceGroupName = $ResourceGroupName.Replace(" ", "").ToLower()

$certificate = $null
$certificateAppSetting = $null

# Azure variables
$AzureTemplatesPath = "./Azure"
$FunctionZipPath = "$AzureTemplatesPath/Function/assets"
$certificatesPath = "../Certificates"
$functionSolutionPath = "../Solution"
$functionName = "func-$AppName-$Environment-$InstanceNumber"
$keyVaultName = "kv-$AppName-$Environment-$InstanceNumber"


######################
## Start deployment ##
######################

Write-Host "Deploying Azure Function..." -ForegroundColor Yellow

if (!$SkipARMTemplateDeployment) {
    
    # get objectId of current user account
    $userObjectId = az ad signed-in-user show --query "objectId"
    Write-Host "User ObjectId: $userObjectId" -ForegroundColor Green
    # add user objectId as parameter to the template
    $TemplateParameters = @("userObjectId=$userObjectId") + $TemplateParameters
    
    # deploy resources
    az deployment group create `
        --resource-group $ResourceGroupName `
        --subscription $SubscriptionId `
        --template-file "$AzureTemplatesPath\Function\functionTemplate.json" `
        --parameters "$AzureTemplatesPath\Function\function-parameters-$Environment.json" `
        --parameters $TemplateParameters
}
    

if (!$SkipCertificateDeployment) {
    
    $CertificateName = "$AppName-$Environment-$InstanceNumber"
    $CertificateFilePath = "$certificatesPath/$CertificateName.pfx"
    
    Write-Host "Uploading certificate $CertificateFilePath to KeyVault..." -ForegroundColor Yellow
    # upload certificate to Key Vault
    az keyvault certificate import `
        --vault-name $keyVaultName `
        --file $CertificateFilePath `
        --name $CertificateName `
        --password $CertificatePassword
        
    # get certificate reference from KeyVault and generate app setting
    $certificate = az keyvault certificate show --vault-name $keyVaultName --name $CertificateName | ConvertFrom-Json
    $certificateAppSetting = "@Microsoft.KeyVault^^(SecretUri=" + $certificate.sid + "^^)"
    # add certificate info to app settings
    $AppSettings += @("Certificate=$certificateAppSetting")
}
    
if (!$SkipAppSettingsDeployment) {
    
    Write-Host "Updating Function app settings..." -ForegroundColor Yellow
    # add extra function app settings not included on ARM template as they are SharePoint specific
    az functionapp config appsettings set `
        --resource-group $ResourceGroupName `
        --name $functionName `
        --settings $AppSettings
}

$FunctionZipFilePath = "$FunctionZipPath/Function.zip"
if ($SkipMSBuild) {
    # create Zip Package from function files
    # for PowerShell solutions
    Compress-Archive -Path "$functionSolutionPath/*" -DestinationPath $FunctionZipFilePath -Force
}
else {
    # build solution and create zip package
    # for C# solutions
    $solutionFilePath = "$functionSolutionPath/MergePDF/MergePDF.csproj"
    $solutionFilePath
    Build-Solution -PrjFilePath $solutionFilePath -OutDir $FunctionZipPath
}

if (!$SkipZipDeployment) {
    
    # deploy Zip Package to function
    az webapp deployment source config-zip --resource-group $ResourceGroupName --name $functionName --src $FunctionZipFilePath
}

Write-Host "Finished deploying Azure Function" -ForegroundColor Green
