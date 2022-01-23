#region Functions

#region Parameters
Param(
    [Parameter(Mandatory)]
    [String] $TenantName,

    [Parameter()]
    [String] $AppName,

    [Parameter(Mandatory)]
    [String] $CertificatePassword
    
)
#endregion Parameters


$tenant = "$TenantName.onmicrosoft.com"
$tenantAdminUrl = "https://$TenantName-admin.sharepoint.com"
# Certificate variables
$certificatesPath = "../Certificates"


try {
    Write-Host "### AZURE AD APP CREATION ###`nCreating Azure AD App - '$appName'..." -ForegroundColor Yellow
        
    $securedCertificatePassword = $CertificatePassword | ConvertTo-SecureString -Force -AsPlainText
        
    Write-Host "Connect to SharePoint admin portal using admin account for context" -ForegroundColor Yellow
    Connect-PnPOnline -Url $tenantAdminUrl -Interactive
    Register-PnPAzureADApp -ApplicationName $AppName `
        -Tenant $tenant `
        -CertificatePassword $securedCertificatePassword `
        -OutPath $certificatesPath `
        -SharePointApplicationPermissions "Sites.ReadWrite.All" `
        -DeviceLogin

    # get app instance
    $appRegistrationCollection = az ad app list --display-name $AppName
    $appRegistration = $appRegistrationCollection | ConvertFrom-Json

    # update App
    if ($appRegistration.Count -gt 0) {
        Write-Host "Updating app properties..."
        $appId = $appRegistration.appId
        Write-Host "AppId: $appId"
        az ad app update --id $appId --set publicClient=false --identifier-uris "api://$appId"
        Write-Host "Updated public client and identifier URIs properties"
    }

    Write-Host "### AZURE AD APP CREATION FINISHED ###" -ForegroundColor Green
}
catch {
    $errorMessage = $_.Exception.Message
    Write-Host "Error occured while creating an Azure AD App: $errorMessage" -ForegroundColor Red
}


#endregion Functions