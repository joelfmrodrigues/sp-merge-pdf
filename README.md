# SharePoint PDF Merge Function

A solution to merge PDF files stored in SharePoint sites.

Contributions are welcome!

<br/>

## Introduction

An Azure Function solution that connects to SharePoint using an Azure AD app registration and merges PDF files based on the file URLs provided. The Function is triggered from an Azure Storage queue and can accept an array of file URLs. Files are merged based on the order provided.

The Azure Function reads the contents of the files using memory streams, merges them all in memory and uploads the memory stream as a new file in SharePoint. Copies of the files are **never** stored in the Function file system.

Please note that if your PDF files contain page numbers as part of the page content, these numbers will also be displayed on the resulting file.

<br/>

### Examples of use cases

- From an Azure Logic App using an action to add a message to an Azure storage queue
- From a PowerAutomate Flow using an action to add a message to an Azure storage queue
- From an Azure Function or Web Application (C#, Node.js, etc) solution, adding a message to a queue
- From a SharePoint Framework solution, using a backend service to interact with the storage queue
- Any solution that can add a message to an Azure storage queue ...

<br/>

### Sample request

```JSON
{
  "SiteUrl": "https://contoso.sharepoint.com/sites/contoso",
  "FolderPath": "https://contoso.sharepoint.com/sites/contoso/Shared%20Documents/Test",
  "FileName": "result.pdf",
  "FilesPathArray": [
    "https://contoso.sharepoint.com/sites/contoso/Shared%20Documents/Test/file1.pdf",
    "https://contoso.sharepoint.com/sites/contoso/Shared%20Documents/Test/file2.pdf"
  ]
}
```

`SiteUrl` - The URL of the SharePoint site collection where files are stored. At present, the solution does not support merging files from different site collections, but could be extended to support this as there is no technical limitation.

`FolderPath` - The SharePoint folder path where the resulting file will be created.

`FileName` - The name of the file to create as the result of the merge.

`FilesPathArray` - An array containing the path in SharePoint of the PDF files to be merged.

<br/>

## Requirements

- Azure subscription
- Microsoft 365 subscription
- Global admin for Azure and Microsoft 365
- PowerShell 7
- Az PowerShell (automatically installed if not available)
- PnP.PowerShell (automatically installed if not available)
- Azure CLI
- [Visual Studio 2019 \*](https://my.visualstudio.com/Downloads?q=visual%20studio%202019&wt.mc_id=o~msft~vscom~older-downloads)
- [MS Build \*](https://my.visualstudio.com/Downloads?q=visual%20studio%202019%20build&wt.mc_id=o~msft~vscom~older-downloads)

Visual Studio 2019 and MS Build are currently required to dynamically build the solution and generate the ZIP package for Function deployment. If this causes too many issues, an alternative approach can be considered.

Also, the script to build the solution (`MSBuildTools.ps1`) has a dependency on Visual Studio 2019 and Build Tools being installed on the default path. You may need to check/update the paths if you get errors with the script. Please let me know if you find issues and I can look for a better way to handle this if required.

<br/>

## Deployment

To deploy the solution, create a copy of the `deploy-run-demo.ps1` script and update the parameters as required for the target environment.

For local/test deployments, you can name the file deploy-run-loc.ps1 and it will be automatically ignored by Git.

### Script parameters

- `TenantName` - name of the Microsoft 365 tenant, for example, contoso
- `TenantId` - tenant Id used for the Azure subscription where Azure resources will be deployed
- `SubscriptionId` - Id of the Azure subscription where resources will be deployed
- `SPOTenantId` - tenant ID of the Azure subscription associated with the M365 subscription - may or may not be the same as above
- `CertificatePassword` - No need to specify. When running the script, you will be asked for a password to the self-signed certificate that will be created for the Azure AD application registration
- `Environment` - solution environment: loc|dev|uat|prod
- `InstanceNumber` - unique number identified that will be used as part of the naming convention for Azure resources (examples: 001, 100, 555, etc)
- `AppName` - name of the application, which will be used for creating the Azure AD app and Azure resource names (example: sp-merge-pdf)
- `ResourceGroupName` - name of the resource group to deploy the resources to. Will be created if not available yet. Example: rg-sp-merge-pdf-dev-555
- `Location` - Azure location for resource group and resources. Example: northeurope. Check [Azure location options](https://azure.microsoft.com/en-gb/global-infrastructure/locations/)

<br/>

## Authentication

The solution authenticates to SharePoint using Azure AD application permissions (`Sites.ReadWrite.All`) and a certificate. The certificate is a self-signed certificate generated during deployment and using the password provided when running the script.

The public part of this certificate will be uploaded to the Azure AD app and the private part will be uploaded to Key Vault.

The Azure AD application Id is also securely stored in Key Vault as a secret and is used in combination with the certificate when requesting an access token for SharePoint.

Key Vault secrets are available to the Azure Function via Key Vault references in Function App Settings, and the Function (with Managed Identity enabled) is granted explicit permissions to **only read** the secrets from Key Vault.

<br/>

## Run solution locally

Add the following properties to `local.settings.json` - some parameters may need to be replaced for your specific scenario.

```JSON
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME_VERSION": "~7",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet",
    "WEBSITE_SLOT_NAME": "Development",
    "WEBSITE_LOAD_USER_PROFILE": 1,
    "AppId": "", // requires update - Id of the Azure AD app registration
    "AuthId": "", // requires update - Id of the Azure AD app registration
    "AuthSecret": "", //requires update - certificate password
    "AuthType": "AzureADAppOnly",
    "Certificate": "XXXXXXXXXXXXXXXX", // In Azure, contains the link to certificate from KeyVault. In local dev, contains the certificate base 64 string
    "SPOTenantId": "XXXXXXXXXXXXXXXX", //requires update | Id of the tenant
    "SPOTenantName": "", //requires update | Example: contoso
  }
}
```
