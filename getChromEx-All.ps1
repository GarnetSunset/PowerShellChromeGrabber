param([String]$OutputFolder=$null,[String]$ExtensionId=$null,[Switch]$Remove, [Switch]$WhatIf)
## James Duarte 10/3/2018
##: Globals
$retval = $false
$Destination = "##SERVER-HERE##"

##: If OutputFolder param wasn't given, output the audit file to the desktop
if(!$OutputFolder -or !(Test-Path -Path $OutputFolder)) {
    $auditfolderpath = "$($env:TEMP)"
} else {
    $auditfolderpath = $OutputFolder
}
$folders = Get-ChildItem C:/Users/ | ?{ $_.PSIsContainer } | Select-Object -ExpandProperty Name
foreach ($user in $folders) {
$auditfilepath = "$($auditfolderpath)\Extensions-$($user)-$($env:COMPUTERNAME).txt"
if( !(Test-Path -Path $auditfilepath) ) {
    echo "Creating: [$auditfilepath]"
    if(!($WhatIf)) {
        echo "" | Out-File -FilePath $auditfilepath
    }
}
if(!($WhatIf)) {
    Clear-Content $auditfilepath
}
if ((Test-Path "C:\Users\$($user)\AppData\Local\Google\Chrome\User Data\Default\Extensions") -eq $true)
{
##: The extensions folder is in local appdata 
$extension_folders = Get-ChildItem -Path "C:\Users\$($user)\AppData\Local\Google\Chrome\User Data\Default\Extensions"
##: Loop through each extension folder
foreach ($extension_folder in $extension_folders ) {

    ##: Get the version specific folder within this extension folder
    $version_folders = Get-ChildItem -Path "$($extension_folder.FullName)"

    ##: Loop through the version folders found
    foreach ($version_folder in $version_folders) {
        ##: The extension folder name is the app id in the Chrome web store
        $appid = $extension_folder.BaseName

        ##: First check the manifest for a name
        $name = ""
        if( (Test-Path -Path "$($version_folder.FullName)\manifest.json") ) {
            try {
                $json = Get-Content -Raw -Path "$($version_folder.FullName)\manifest.json" | ConvertFrom-Json
                $name = $json.name
            } catch {
                #$_
                $name = ""
            }
        }

        ##: If we find _MSG_ in the manifest it's probably an app
        if( $name -like "*MSG*" ) {
            ##: Sometimes the folder is en
            if( Test-Path -Path "$($version_folder.FullName)\_locales\en\messages.json" ) {
                try { 
                    $json = Get-Content -Raw -Path "$($version_folder.FullName)\_locales\en\messages.json" | ConvertFrom-Json
                    $name = $json.appName.message
                    ##: Try a lot of different ways to get the name
                    if(!$name) {
                        $name = $json.extName.message
                    }
                    if(!$name) {
                        $name = $json.extensionName.message
                    }
                    if(!$name) {
                        $name = $json.app_name.message
                    }
                    if(!$name) {
                        $name = $json.application_title.message
                    }
                } catch { 
                    #$_
                    $name = ""
                }
            }
            ##: Sometimes the folder is en_US
            if( Test-Path -Path "$($version_folder.FullName)\_locales\en_US\messages.json" ) {
                try {
                    $json = Get-Content -Raw -Path "$($version_folder.FullName)\_locales\en_US\messages.json" | ConvertFrom-Json
                    $name = $json.appName.message
                    ##: Try a lot of different ways to get the name
                    if(!$name) {
                        $name = $json.extName.message
                    }
                    if(!$name) {
                        $name = $json.extensionName.message
                    }
                    if(!$name) {
                        $name = $json.app_name.message
                    }
                    if(!$name) {
                        $name = $json.application_title.message
                    }
                } catch {
                    #$_
                    $name = ""
                }
            }
        }

        ##: If we can't get a name from the extension use the app id instead
        if( !$name ) {
            $name = "[$($appid)]"
        }

        ##: App id given on command line and this one matched it
        if( $ExtensionId -and ($appid -eq $ExtensionId) ) {
            if( $Remove ) {
                echo "Removing item: [$appid] at path: [$($extension_folder.FullName)]"
                if(!($WhatIf)) {
                    ##: Remove the extension folder
                    if (Test-Path -Path $extension_folder.FullName) { 
                        Remove-Item -Path $extension_folder.FullName -Recurse -Force            
                    }

                    ##: Remove the extension registry key
                    if (Test-Path -Path "HKCU:\SOFTWARE\Google\Chrome\PreferenceMACs\Default\extensions.settings") {
                        if( Get-ItemProperty -Name "$appid" -Path "HKCU:\SOFTWARE\Google\Chrome\PreferenceMACs\Default\extensions.settings" ) {
                            Remove-ItemProperty -Name "$appid" -Path "HKCU:\SOFTWARE\Google\Chrome\PreferenceMACs\Default\extensions.settings"
                        }
                    }
                }
            } else {
                ##: Dump to a file
                echo "Appending: [$name ($($version_folder)) - $appid] to audit file: [$auditfilepath]"
                if(!($WhatIf)) {
                    echo "$name ($($version_folder)) - $appid" | Out-File -Append $auditfilepath
                }
                ##: Exit with a TRUE value if the given extension id was found
                $retval = $true
            }

        ##: App id given on command line and this did NOT match it
        } elseif( $ExtensionId -and ($appid -ne $ExtensionId) ) {
            ##: NOP
            #echo "Skipping: [$appid] output"
        ##: App id not given on command line
        } else {
            ##: Dump to audit file
            echo "[$name ($($version_folder)) - $appid]"
            if(!($WhatIf)) {
                echo "$name ($($version_folder)) - $appid" | Out-File -Append $auditfilepath
            }
        }

    }

}

if(Test-Connection -Cn ##SERVER-HERE## -BufferSize 16 -Count 1 -ea 0 -quiet) ## Checks if server is up then copies the file over
{
Copy-Item $auditfilepath -Destination $Destination -Force
Remove-Item $auditfilepath
}
}
}
exit($retval)