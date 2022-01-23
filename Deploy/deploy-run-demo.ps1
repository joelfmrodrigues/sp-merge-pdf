$CertificatePassword = Read-Host "Please enter the certificate password" #-AsSecureString

.\deploy.ps1 `
    -TenantName "xxxxxxxxxxxxxx" `
    -TenantId "xxxxxxxxxxxxxx" `
    -SubscriptionId "xxxxxxxxxxxxxx" `
    -SPOTenantId "xxxxxxxxxxxxxx" `
    -CertificatePassword $CertificatePassword `
    -Environment "dev" `
    -InstanceNumber "123" `
    -AppName "sp-merge-pdf" `
    -ResourceGroupName "rg-xxxxxxxxxxxxxx-dev-001" `
    -Location "northeurope" `
    # -SkipAzResourceGroupCreation `
    # -SkipAzFunctionDeployment `
    # -SkipAzADAppCreation `
    # -SkipDependenciesInstall `
    # -SkipAllAzResourcesDeployment `
