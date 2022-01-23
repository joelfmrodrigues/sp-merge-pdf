function Build-Solution {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $PrjFilePath,

        [Parameter()]
        [string]
        $OutDir
    )
    
    begin {
        Write-Output "Requires Visual Studio 2019 and Visual Studio 2019 Build Tools to be installed on the machine"
        [string] $msbuildFilePath = 'C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\msbuild.exe'
        [string] $VSToolsPath = 'C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\MSBuild\Microsoft\VisualStudio\v16.0'
    }
    
    process {
        $methodName = "[Build-Solution]"
        $tempPath = $env:TEMP + '\._build_app_' + (Get-Date).ToString("yyyyMMdd_HHmmsss")
        
        Write-Output "$methodName Temporary folder is $tempPath"
        Write-Output "$methodName   MsBuild Start "
        Write-Output "path: $PrjFilePath"

        & $msbuildFilePath $PrjFilePath `
            /p:IsPackaging=false /p:DeployOnBuild=true `
            /p:Configuration=Release  `
            /p:outdir=$tempPath `
            /p:VSToolsPath=$VSToolsPath 
        Write-Output "$methodName   MsBuild End "
                
        $webZipFile = $tempPath + "\Function.zip"
        Compress-Archive -Path "$tempPath/*" -DestinationPath $webZipFile -Force
        Write-Output ("$methodName   Webzip [Function.zip] created on $tempPath")

        Move-Item -Path $webZipFile -Destination $OutDir	-Force
        Remove-Item  -path $tempPath -Recurse -Force
        Write-Output "$methodName End "
    }
    
    end {
        
    }
}