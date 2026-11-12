# scripts/create_release_key.ps1
#
# Creates the Android release signing key for this app — once, ever.
#
# WHY YOU MUST RUN THIS. Android only accepts an update signed with the SAME key as the app
# already installed. Without a key of your own, `flutter build apk --release` is refused
# (android/app/build.gradle.kts), because a debug-signed APK can never be upgraded by a
# properly signed one: every shop would have to uninstall. See RELEASE.md.
#
# WHAT IT CREATES
#   * a keystore OUTSIDE the repo  (default: %USERPROFILE%\drinkquick-keys\)
#   * android/key.properties       (excluded by android/.gitignore AND the root .gitignore)
# The password is generated here and printed ONCE. Save it, with the .jks file, in a password
# manager and on an offline backup: losing the key means every shop uninstalls for ever.
#
# USAGE
#   powershell -ExecutionPolicy Bypass -File scripts/create_release_key.ps1
#   powershell ... -File scripts/create_release_key.ps1 -KeyDir D:\keys -Force
#
# After it:  flutter build apk --release

[CmdletBinding()]
param(
    [string]$KeyDir = (Join-Path $env:USERPROFILE 'drinkquick-keys'),
    [string]$FileName = 'drinkquick-release.jks',
    [string]$Alias = 'drinkquick',
    [int]$ValidityDays = 10000,
    [string]$DName = 'CN=Drink Quick Cal, O=Drink Quick Cal, C=CM',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$propertiesPath = Join-Path (Join-Path $repoRoot 'android') 'key.properties'
$keystorePath = Join-Path $KeyDir $FileName

if ((Test-Path $propertiesPath) -and -not $Force) {
    throw "android/key.properties already exists. If you are replacing it on purpose, re-run with -Force (the old key stops being usable for updates)."
}
if ((Test-Path $keystorePath) -and -not $Force) {
    throw "$keystorePath already exists. Re-run with -Force only if you mean to replace the app's signing key."
}

$keytool = (Get-Command keytool -ErrorAction SilentlyContinue)
if (-not $keytool) {
    throw "keytool not found. It ships with a JDK - Android Studio includes one. Install it, reopen this terminal, and run this again."
}

# A password that survives being typed, pasted and stored: base64 minus the three characters
# that mean something to keytool or to a Java properties file.
$bytes = New-Object byte[] 24
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$password = ([Convert]::ToBase64String($bytes)) -replace '[+/=]', 'x'

New-Item -ItemType Directory -Force -Path $KeyDir | Out-Null

# keytool writes its progress ("Generating 2048-bit RSA key pair...") to STDERR, and with
# $ErrorActionPreference = 'Stop' PowerShell turns a native command's stderr into a fatal error
# record — the script died here the first time it ran. The exit code and the file are the
# truth instead.
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'

# -dname keeps keytool non-interactive; PKCS12 (the modern default) uses one password for both.
& $keytool.Source -genkeypair -keystore $keystorePath -alias $Alias -keyalg RSA -keysize 2048 `
    -validity $ValidityDays -storepass $password -keypass $password -dname $DName 2>&1 |
    Out-Null
$keytoolExit = $LASTEXITCODE

$ErrorActionPreference = $previousPreference

if ($keytoolExit -ne 0 -or -not (Test-Path $keystorePath)) {
    throw "keytool failed (exit $keytoolExit) and $keystorePath was not created."
}

# Forward slashes: a Java properties file treats '\' as an escape character.
$storeFile = $keystorePath -replace '\\', '/'
@(
    "# Written by scripts/create_release_key.ps1. NOT in git (android/.gitignore + the root one).",
    "# Back up the .jks AND this password: Android only upgrades an app signed by the same key.",
    "storePassword=$password",
    "keyPassword=$password",
    "keyAlias=$Alias",
    "storeFile=$storeFile"
) | Set-Content -LiteralPath $propertiesPath -Encoding Ascii

Write-Host ""
Write-Host "Keystore   : $keystorePath"
Write-Host "Wrote      : $propertiesPath"
Write-Host "Fingerprint:"
& $keytool.Source -list -v -keystore $keystorePath -storepass $password -alias $Alias |
    Select-String -Pattern 'SHA256:', 'Valid from' | ForEach-Object { "  $($_.Line.Trim())" }
Write-Host ""
Write-Host "PASSWORD (shown once - save it in your password manager, with the .jks):"
Write-Host "  $password"
Write-Host ""
Write-Host "Next: flutter build apk --release"
