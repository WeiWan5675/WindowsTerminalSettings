#Requires -RunAsAdministrator
#Requires -Version 6

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Default', 'Flat', 'Mini')]
    [string] $Layout = 'Default',
    [Parameter()]
    [ValidateSet('simple', 'intelligent')]
    [string] $Edition = 'simple',
    [Parameter()]
    [switch] $PreRelease
)

function Get-EditionMeta(
    [Parameter(Mandatory=$true)]
    [string]$Edition)
{
    if ($Edition -eq 'simple') {
        return @{
            PackagePattern      = 'Microsoft.WindowsTerminal_*__*'
            PreviewPattern      = 'Microsoft.WindowsTerminalPreview_*__*'
            StablePackageName   = 'Microsoft.WindowsTerminal_8wekyb3d8bbwe'
            PreviewPackageName  = 'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe'
            Executable          = 'wt.exe'
            MenuKey             = 'MenuTerminal'
            DisplayName         = 'Windows Terminal'
            IconBaseName        = 'wt'
            ExcludeProfileGuids = @()
        }
    } else {
        return @{
            PackagePattern      = 'Microsoft.IntelligentTerminal_*__*'
            PreviewPattern      = $null
            StablePackageName   = 'Microsoft.IntelligentTerminal_8wekyb3d8bbwe'
            PreviewPackageName  = $null
            Executable          = 'wtai.exe'
            MenuKey             = 'MenuIntelligentTerminal'
            DisplayName         = '智能终端'
            IconBaseName        = 'wtai'
            # 智能终端把 AI 侧栏注册成了普通 Profile,但它不是 shell 会话,从右键启动没意义,固定 GUID 来自 defaults.json
            ExcludeProfileGuids = @('{fd19208a-412b-4857-8a2d-9ca592b4b16e}')
        }
    }
}

function Generate-HelperScript(
        # The cache folder
        [Parameter(Mandatory=$true)]
        [string]$cache)
{
    $content =
    "Set shell = WScript.CreateObject(`"Shell.Application`")
     executable = WSCript.Arguments(0)
     folder = WScript.Arguments(1)
     If Wscript.Arguments.Count > 2 Then
         profile = WScript.Arguments(2)
         ' 0 at the end means to run this command silently
         shell.ShellExecute `"powershell`", `"Start-Process \`"`"`" & executable & `"\`"`" -ArgumentList \`"`"-p \`"`"\`"`"`" & profile & `"\`"`"\`"`" -d \`"`"\`"`"`" & folder & `"\`"`"\`"`" \`"`" `", `"`", `"runas`", 0
     Else
         ' 0 at the end means to run this command silently
         shell.ShellExecute `"powershell`", `"Start-Process \`"`"`" & executable & `"\`"`" -ArgumentList \`"`"-d \`"`"\`"`"`" & folder & `"\`"`"\`"`" \`"`" `", `"`", `"runas`", 0
     End If
    "
    Set-Content -Path "$cache/helper.vbs" -Value $content
}

# https://github.com/Duffney/PowerShell/blob/master/FileSystems/Get-Icon.ps1

Function Get-Icon {

    [CmdletBinding()]

    Param (
        [Parameter(Mandatory=$True, Position=1, HelpMessage="Enter the location of the .EXE file")]
        [string]$File,

        # If provided, will output the icon to a location
        [Parameter(Position=1, ValueFromPipelineByPropertyName=$true)]
        [string]$OutputFile
    )

    [System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')  | Out-Null

    [System.Drawing.Icon]::ExtractAssociatedIcon($File).ToBitmap().Save($OutputFile)
}

# https://gist.github.com/darkfall/1656050
function ConvertTo-Icon
{
    <#
    .Synopsis
        Converts image to icons
    .Description
        Converts an image to an icon
    .Example
        ConvertTo-Icon -File .\Logo.png -OutputFile .\Favicon.ico
    #>
    [CmdletBinding()]
    param(
    # The file
    [Parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
    [Alias('Fullname')]
    [string]$File,

    # If provided, will output the icon to a location
    [Parameter(Position=1, ValueFromPipelineByPropertyName=$true)]
    [string]$OutputFile
    )

    begin {
        Add-Type -AssemblyName System.Drawing
    }

    process {
        #region Load Icon
        $resolvedFile = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($file)
        if (-not $resolvedFile) { return }
        $inputBitmap = [Drawing.Image]::FromFile($resolvedFile)
        $width = $inputBitmap.Width
        $height = $inputBitmap.Height
        $size = New-Object Drawing.Size $width, $height
        $newBitmap = New-Object Drawing.Bitmap $inputBitmap, $size
        #endregion Load Icon

        #region Icon Size bound check
        if ($width -gt 255 -or $height -gt 255) {
            $ratio = ($height, $width | Measure-Object -Maximum).Maximum / 255
            $width /= $ratio
            $height /= $ratio
        }
        #endregion Icon Size bound check

        #region Save Icon
        $memoryStream = New-Object System.IO.MemoryStream
        $newBitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)

        $resolvedOutputFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputFile)
        $output = [IO.File]::Create("$resolvedOutputFile")

        $iconWriter = New-Object System.IO.BinaryWriter($output)
        # 0-1 reserved, 0
        $iconWriter.Write([byte]0)
        $iconWriter.Write([byte]0)

        # 2-3 image type, 1 = icon, 2 = cursor
        $iconWriter.Write([short]1);

        # 4-5 number of images
        $iconWriter.Write([short]1);

        # image entry 1
        # 0 image width
        $iconWriter.Write([byte]$width);
        # 1 image height
        $iconWriter.Write([byte]$height);

        # 2 number of colors
        $iconWriter.Write([byte]0);

        # 3 reserved
        $iconWriter.Write([byte]0);

        # 4-5 color planes
        $iconWriter.Write([short]0);

        # 6-7 bits per pixel
        $iconWriter.Write([short]32);

        # 8-11 size of image data
        $iconWriter.Write([int]$memoryStream.Length);

        # 12-15 offset of image data
        $iconWriter.Write([int](6 + 16));

        # write image data
        # png data must contain the whole png data file
        $iconWriter.Write($memoryStream.ToArray());

        $iconWriter.Flush();
        $output.Close()
        #endregion Save Icon

        #region Cleanup
        $memoryStream.Dispose()
        $newBitmap.Dispose()
        $inputBitmap.Dispose()
        #endregion Cleanup
    }
}

function GetProgramFilesFolder(
    [Parameter(Mandatory=$true)]
    [hashtable]$meta,
    [Parameter(Mandatory=$true)]
    [bool]$includePreview)
{
    $root = "$Env:ProgramFiles\WindowsApps"
    $versionFolders = (Get-ChildItem $root | Where-Object {
            if ($includePreview -and $meta.PreviewPattern) {
                $_.Name -like $meta.PackagePattern -or
                $_.Name -like $meta.PreviewPattern
            } else {
                $_.Name -like $meta.PackagePattern
            }
        })
    $foundVersion = $null
    $result = $null
    foreach ($versionFolder in $versionFolders) {
        if ($versionFolder.Name -match "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+") {
            $version = [version]$Matches.0
            Write-Host "Found $($meta.DisplayName) version $version."
            if ($null -eq $foundVersion -or $version -gt $foundVersion) {
                $foundVersion = $version
                $result = $versionFolder.FullName
            }
        } else {
            Write-Warning "Found $($meta.DisplayName) unsupported version in $versionFolder."
        }
    }

    if ($null -eq $result) {
        $hint = if ($meta.PreviewPattern) { 'To install menu items for Preview version, run with "-PreRelease" switch.' } else { '' }
        Write-Error "Failed to find $($meta.DisplayName) actual folder under $root. $hint Exit."
        exit 1
    }

    if ($foundVersion -lt [version]"0.11") {
        Write-Warning "The latest version found is less than 0.11, which is not tested. The install script might fail in certain way."
    }

    return $result
}

function GetTerminalIcon(
    [Parameter(Mandatory=$true)]
    [hashtable]$meta,
    [Parameter(Mandatory=$true)]
    [string]$folder,
    [Parameter(Mandatory=$true)]
    [string]$localCache)
{
    $base = $meta.IconBaseName
    $icon = "$localCache\$base.ico"
    $actual = $folder + "\WindowsTerminal.exe"
    if (Test-Path $actual) {
        # use app icon directly.
        Write-Host "Found actual executable $actual."
        $temp = "$localCache\$base.png"
        Get-Icon -File $actual -OutputFile $temp
        ConvertTo-Icon -File $temp -OutputFile $icon
    } else {
        # download from GitHub
        Write-Warning "Didn't find actual executable $actual so download icon from GitHub."
        Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/microsoft/terminal/master/res/terminal.ico" -OutFile $icon
    }

    return $icon
}

function GetActiveProfiles(
    [Parameter(Mandatory=$true)]
    [hashtable]$meta,
    [Parameter(Mandatory=$true)]
    [bool]$isPreview)
{
    $pkg = if ($isPreview -and $meta.PreviewPackageName) { $meta.PreviewPackageName } else { $meta.StablePackageName }
    $file = "$env:LocalAppData\Packages\$pkg\LocalState\settings.json"
    if (-not (Test-Path $file)) {
        Write-Error "Couldn't find profiles for $($meta.DisplayName). Please run $($meta.DisplayName) at least once after installing it. Exit."
        exit 1
    }

    $settings = Get-Content $file | Out-String | ConvertFrom-Json
    if ($settings.profiles.PSObject.Properties.name -match "list") {
        $list = $settings.profiles.list
    } else {
        $list = $settings.profiles
    }

    $excluded = @($meta.ExcludeProfileGuids) | ForEach-Object { $_.ToLowerInvariant() }
    return $list `
        | Where-Object { -not $_.hidden } `
        | Where-Object { ($null -eq $_.source) -or -not ($settings.disabledProfileSources -contains $_.source) } `
        | Where-Object {
            if ($_.guid -and ($excluded -contains $_.guid.ToLowerInvariant())) {
                Write-Host "Skip built-in profile '$($_.name)' ($($_.guid))."
                $false
            } else {
                $true
            }
        }
}

function GetProfileIcon (
    [Parameter(Mandatory=$true)]
    $profile,
    [Parameter(Mandatory=$true)]
    [hashtable]$meta,
    [Parameter(Mandatory=$true)]
    [string]$folder,
    [Parameter(Mandatory=$true)]
    [string]$localCache,
    [Parameter(Mandatory=$true)]
    [string]$defaultIcon,
    [Parameter(Mandatory=$true)]
    [bool]$isPreview)
{
    $guid = $profile.guid
    $name = $profile.name
    $result = $null
    $profilePng = $null
    $icon = $profile.icon

    $stablePkgPath = "$Env:LOCALAPPDATA\Packages\$($meta.StablePackageName)"
    $previewPkgPath = if ($meta.PreviewPackageName) { "$Env:LOCALAPPDATA\Packages\$($meta.PreviewPackageName)" } else { $stablePkgPath }
    $pkgPath = if ($isPreview -and $meta.PreviewPackageName) { $previewPkgPath } else { $stablePkgPath }

    if ($null -ne $icon) {
        if (Test-Path $icon) {
            # use user setting
            $profilePng = $icon
        } elseif ($profile.icon -like "ms-appdata:///Roaming/*") {
            #resolve roaming cache
            $profilePng = $icon -replace "ms-appdata:///Roaming", "$pkgPath\RoamingState" -replace "/", "\"
        } elseif ($profile.icon -like "ms-appdata:///Local/*") {
            #resolve local cache
            $profilePng = $icon -replace "ms-appdata:///Local", "$pkgPath\LocalState" -replace "/", "\"
        } elseif ($profile.icon -like "ms-appx:///*") {
            # resolve app cache
            $profilePng = $icon -replace "ms-appx://", $folder -replace "/", "\"
        } elseif ($profile.icon -like "*%*") {
            $profilePng = [System.Environment]::ExpandEnvironmentVariables($icon)
        } else {
            Write-Host "Invalid profile icon found $icon. Please report an issue at https://github.com/lextm/windowsterminal-shell/issues ."
        }
    }

    if (($null -eq $profilePng) -or -not (Test-Path $profilePng)) {
        # fallback to profile PNG
        $profilePng = "$folder\ProfileIcons\$guid.scale-200.png"
        if (-not (Test-Path($profilePng))) {
            if ($profile.source -eq "Windows.Terminal.Wsl") {
                $profilePng = "$folder\ProfileIcons\{9acb9455-ca41-5af7-950f-6bca1bc9722f}.scale-200.png"
            }
        }
    }

    if (Test-Path $profilePng) {
        if ($profilePng -like "*.png") {
            # found PNG, convert to ICO
            $result = "$localCache\$guid.ico"
            ConvertTo-Icon -File $profilePng -OutputFile $result
        } elseif ($profilePng -like "*.ico") {
            $result = $profilePng
        } else {
            Write-Warning "Icon format is not supported by this script $profilePng. Please use PNG or ICO format."
        }
    } else {
        Write-Warning "Didn't find icon for profile $name."
    }

    if ($null -eq $result) {
        # final fallback
        $result = $defaultIcon
    }

    return $result
}

function CreateMenuItem(
    [Parameter(Mandatory=$true)]
    [string]$rootKey,
    [Parameter(Mandatory=$true)]
    [string]$name,
    [Parameter(Mandatory=$true)]
    [string]$icon,
    [Parameter(Mandatory=$true)]
    [string]$command,
    [Parameter(Mandatory=$true)]
    [bool]$elevated
)
{
    New-Item -Path $rootKey -Force | Out-Null
    New-ItemProperty -Path $rootKey -Name 'MUIVerb' -PropertyType String -Value $name | Out-Null
    New-ItemProperty -Path $rootKey -Name 'Icon' -PropertyType String -Value $icon | Out-Null
    if ($elevated) {
        New-ItemProperty -Path $rootKey -Name 'HasLUAShield' -PropertyType String -Value '' | Out-Null
    }

    New-Item -Path "$rootKey\command" -Force | Out-Null
    New-ItemProperty -Path "$rootKey\command" -Name '(Default)' -PropertyType String -Value $command | Out-Null
}

function CreateProfileMenuItems(
    [Parameter(Mandatory=$true)]
    $profile,
    [Parameter(Mandatory=$true)]
    [hashtable]$meta,
    [Parameter(Mandatory=$true)]
    [string]$executable,
    [Parameter(Mandatory=$true)]
    [string]$folder,
    [Parameter(Mandatory=$true)]
    [string]$localCache,
    [Parameter(Mandatory=$true)]
    [string]$icon,
    [Parameter(Mandatory=$true)]
    [string]$layout,
    [Parameter(Mandatory=$true)]
    [bool]$isPreview)
{
    $guid = $profile.guid
    $name = $profile.name
    $command = """$executable"" -p ""$name"" -d ""%V."""
    $elevated = "wscript.exe ""$localCache/helper.vbs"" ""$executable"" ""%V."" ""$name"""
    $profileIcon = GetProfileIcon $profile $meta $folder $localCache $icon $isPreview
    $menuKey = $meta.MenuKey
    $menuKeyAdmin = "${menuKey}Admin"

    if ($layout -eq "Default") {
        $rootKey = "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\ContextMenus\$menuKey\shell\$guid"
        $rootKeyElevated = "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\ContextMenus\$menuKeyAdmin\shell\$guid"
        CreateMenuItem $rootKey $name $profileIcon $command $false
        CreateMenuItem $rootKeyElevated $name $profileIcon $elevated $true
    } elseif ($layout -eq "Flat") {
        CreateMenuItem "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\${menuKey}_$guid" "$name here" $profileIcon $command $false
        CreateMenuItem "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\${menuKeyAdmin}_$guid" "$name here as administrator" $profileIcon $elevated $true
        CreateMenuItem "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\${menuKey}_$guid" "$name here" $profileIcon $command $false
        CreateMenuItem "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\${menuKeyAdmin}_$guid" "$name here as administrator" $profileIcon $elevated $true
    }
}

function CreateMenuItems(
    [Parameter(Mandatory=$true)]
    [hashtable]$meta,
    [Parameter(Mandatory=$true)]
    [string]$executable,
    [Parameter(Mandatory=$true)]
    [string]$layout,
    [Parameter(Mandatory=$true)]
    [bool]$includePreview)
{
    $folder = GetProgramFilesFolder $meta $includePreview
    $localCache = "$Env:LOCALAPPDATA\Microsoft\WindowsApps\Cache"

    if (-not (Test-Path $localCache)) {
        New-Item $localCache -ItemType Directory | Out-Null
    }

    Generate-HelperScript $localCache
    $icon = GetTerminalIcon $meta $folder $localCache

    $menuKey = $meta.MenuKey
    $menuKeyAdmin = "${menuKey}Admin"
    $menuKeyMini = "${menuKey}Mini"
    $menuKeyAdminMini = "${menuKey}AdminMini"
    $displayName = $meta.DisplayName
    $openText = "在此处打开 $displayName"
    $openAdminText = "在此处以管理员身份打开 $displayName"

    if ($layout -eq "Default") {
        # default layout creates two menus
        New-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKey" -Force | Out-Null
        New-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKey" -Name 'MUIVerb' -PropertyType String -Value $openText | Out-Null
        New-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKey" -Name 'Icon' -PropertyType String -Value $icon | Out-Null
        New-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKey" -Name 'ExtendedSubCommandsKey' -PropertyType String -Value "Directory\\ContextMenus\\$menuKey" | Out-Null

        New-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuKey" -Force | Out-Null
        New-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuKey" -Name 'MUIVerb' -PropertyType String -Value $openText | Out-Null
        New-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuKey" -Name 'Icon' -PropertyType String -Value $icon | Out-Null
        New-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuKey" -Name 'ExtendedSubCommandsKey' -PropertyType String -Value "Directory\\ContextMenus\\$menuKey" | Out-Null

        New-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\ContextMenus\$menuKey\shell" -Force | Out-Null

        New-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKeyAdmin" -Force | Out-Null
        New-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKeyAdmin" -Name 'MUIVerb' -PropertyType String -Value $openAdminText | Out-Null
        New-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKeyAdmin" -Name 'Icon' -PropertyType String -Value $icon | Out-Null
        New-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKeyAdmin" -Name 'ExtendedSubCommandsKey' -PropertyType String -Value "Directory\\ContextMenus\\$menuKeyAdmin" | Out-Null

        New-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuKeyAdmin" -Force | Out-Null
        New-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuKeyAdmin" -Name 'MUIVerb' -PropertyType String -Value $openAdminText | Out-Null
        New-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuKeyAdmin" -Name 'Icon' -PropertyType String -Value $icon | Out-Null
        New-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuKeyAdmin" -Name 'ExtendedSubCommandsKey' -PropertyType String -Value "Directory\\ContextMenus\\$menuKeyAdmin" | Out-Null

        New-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\ContextMenus\$menuKeyAdmin\shell" -Force | Out-Null
    } elseif ($layout -eq "Mini") {
        $command = """$executable"" -d ""%V."""
        $elevated = "wscript.exe ""$localCache/helper.vbs"" ""$executable"" ""%V."""
        CreateMenuItem "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKeyMini" $openText $icon $command $false
        CreateMenuItem "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKeyAdminMini" $openAdminText $icon $elevated $true
        CreateMenuItem "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuKeyMini" $openText $icon $command $false
        CreateMenuItem "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuKeyAdminMini" $openAdminText $icon $elevated $true
        return
    }

    $isPreview = $false
    if ($meta.PreviewPattern) {
        $folderName = Split-Path $folder -Leaf
        $isPreview = $folderName -like $meta.PreviewPattern
    }
    $profiles = GetActiveProfiles $meta $isPreview
    foreach ($profile in $profiles) {
        CreateProfileMenuItems $profile $meta $executable $folder $localCache $icon $layout $isPreview
    }
}

# Based on @nerdio01's version in https://github.com/microsoft/terminal/issues/1060

if ((Get-Process -Id $pid).Path -like "*WindowsApps*") {
    Write-Error "PowerShell installed via Microsoft Store is not supported. Learn other ways to install it from https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7 . Exit.";
    exit 1
}

$meta = Get-EditionMeta -Edition $Edition

if ($Edition -eq 'simple') {
    if ((Test-Path "Registry::HKEY_CLASSES_ROOT\Directory\shell\$($meta.MenuKey)") -and
        -not (Test-Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$($meta.MenuKey)")) {
        Write-Error "Please execute uninstall.old.ps1 to remove previous installation."
        exit 1
    }
}

if ($PSVersionTable.PSVersion.Major -lt 6) {
    Write-Error "Must be executed in PowerShell 6 and above. Learn how to install it from https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7 . Exit."
    exit 1
}

if ($PreRelease -and -not $meta.PreviewPattern) {
    Write-Warning "$($meta.DisplayName) has no Preview channel; -PreRelease will be ignored."
}

$executable = "$Env:LOCALAPPDATA\Microsoft\WindowsApps\$($meta.Executable)"
if (-not (Test-Path $executable)) {
    Write-Error "$($meta.DisplayName) not detected at $executable. Make sure $($meta.DisplayName) is installed. Exit."
    exit 1
}

Write-Host "Edition: $($meta.DisplayName). Layout: $Layout."

CreateMenuItems $meta $executable $Layout $PreRelease

Write-Host "$($meta.DisplayName) installed to Windows Explorer context menu."
