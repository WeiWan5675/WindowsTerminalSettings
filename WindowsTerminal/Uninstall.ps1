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

# Based on @nerdio01's version in https://github.com/microsoft/terminal/issues/1060

if ((Get-Process -Id $pid).Path -like "*WindowsApps*") {
    Write-Error "PowerShell installed via Microsoft Store is not supported. Learn other ways to install it from https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7 . Exit.";
    exit 1
}

if ($Edition -eq 'simple') {
    $menuKey     = 'MenuTerminal'
    $displayName = 'Windows Terminal'
    $iconBase    = 'wt'
} else {
    $menuKey     = 'MenuIntelligentTerminal'
    $displayName = '智能终端'
    $iconBase    = 'wtai'
}

$menuKeyAdmin     = "${menuKey}Admin"
$menuKeyMini      = "${menuKey}Mini"
$menuKeyAdminMini = "${menuKey}AdminMini"

if ($Edition -eq 'simple') {
    if ((Test-Path "Registry::HKEY_CLASSES_ROOT\Directory\shell\$menuKey") -and
        -not (Test-Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKey")) {
        Write-Error "Please execute Uninstall.old.ps1 to remove previous installation."
        exit 1
    }
}

# remove edition-specific cache files only (per-profile guid icons and helper.vbs may be shared between editions)
$localCache = "$Env:LOCALAPPDATA\Microsoft\WindowsApps\Cache"
if (Test-Path $localCache) {
    Remove-Item "$localCache\$iconBase.ico" -ErrorAction SilentlyContinue
    Remove-Item "$localCache\$iconBase.png" -ErrorAction SilentlyContinue
}

Write-Host "Edition: $displayName. Layout: $Layout."

if ($Layout -eq "Default") {
    Remove-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKey" -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuKey" -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\ContextMenus\$menuKey" -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKeyAdmin" -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuKeyAdmin" -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\ContextMenus\$menuKeyAdmin" -Recurse -ErrorAction Ignore | Out-Null
} elseif ($Layout -eq "Flat") {
    $rootKey = 'HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell'
    foreach ($key in Get-ChildItem -Path "Registry::$rootKey") {
       if (($key.Name -like "$rootKey\${menuKey}_*") -or ($key.Name -like "$rootKey\${menuKeyAdmin}_*")) {
          Remove-Item "Registry::$key" -Recurse -ErrorAction Ignore | Out-Null
       }
    }

    $rootKey = 'HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell'
    foreach ($key in Get-ChildItem -Path "Registry::$rootKey") {
       if (($key.Name -like "$rootKey\${menuKey}_*") -or ($key.Name -like "$rootKey\${menuKeyAdmin}_*")) {
          Remove-Item "Registry::$key" -Recurse -ErrorAction Ignore | Out-Null
       }
    }
} elseif ($Layout -eq "Mini") {
    Remove-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKeyMini" -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\$menuKeyAdminMini" -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuKeyMini" -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\$menuKeyAdminMini" -Recurse -ErrorAction Ignore | Out-Null
}

Write-Host "$displayName uninstalled from Windows Explorer context menu."
