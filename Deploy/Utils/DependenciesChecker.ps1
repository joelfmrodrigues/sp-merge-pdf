# Check for presence of Azure CLI
try {
    az > $null
}
catch {
    #Write-Host
    throw "AZ cli was not found. Script will install this dependency. Please complete the installation..."
}
function GetModules {
    
    Param(
        [Parameter(Mandatory = $true)]
        [String[]]
        $ModuleToCheck
    )
    
    try {
        if (Get-Module -ListAvailable -Name $ModuleToCheck) {
            Write-Host "Module exists $ModuleToCheck"
        }
        else {
            Install-Module $ModuleToCheck -Scope CurrentUser -Force
        }
    }
    catch {
        #Install-Module $ModuleToCheck -Scope CurrentUser
    }    
}