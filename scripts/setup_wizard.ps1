# EliteMeet setup wizard (Windows). Run from the project root:
#   powershell -ExecutionPolicy Bypass -File scripts\setup_wizard.ps1
#
# See scripts/setup_wizard.sh for the full explanation of what this does
# and does not do — this is the same wizard, PowerShell version.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "=== EliteMeet Setup Wizard ==="
Write-Host "Press Enter at any prompt to accept the default shown in [brackets]."
Write-Host ""

function Prompt-Value($question, $default) {
    $input = Read-Host "$question [$default]"
    if ([string]::IsNullOrWhiteSpace($input)) { return $default }
    return $input
}

$Domain = Prompt-Value "Production domain" "elitemeet.net"
$BuildEnv = Prompt-Value "Environment to build for (dev/staging/production)" "production"
$AndroidAppId = Prompt-Value "Android application ID" "net.elitemeet.app"
$IosBundleId = Prompt-Value "iOS bundle ID" "net.elitemeet.app"
$AppName = Prompt-Value "App display name" "EliteMeet"
$GoogleServicesJson = Prompt-Value "Path to google-services.json (from your Firebase project)" ""
$GoogleServiceInfoPlist = Prompt-Value "Path to GoogleService-Info.plist (from your Firebase project)" ""

Write-Host ""
Write-Host "--- Applying values ---"

$configFile = "lib\config\app_config.dart"
if (Test-Path $configFile) {
    (Get-Content $configFile) `
        -replace "https://elitemeet.net", "https://$Domain" `
        -replace "appName = 'EliteMeet'", "appName = '$AppName'" `
        -replace "applicationId = 'net.elitemeet.app'", "applicationId = '$AndroidAppId'" |
        Set-Content $configFile
    Write-Host "Updated $configFile"
} else {
    Write-Host "$configFile not found - skipped"
}

$androidGradle = "android\app\build.gradle"
if (Test-Path $androidGradle) {
    (Get-Content $androidGradle) `
        -replace 'applicationId = "net.elitemeet.app"', "applicationId = `"$AndroidAppId`"" `
        -replace 'namespace = "net.elitemeet.app"', "namespace = `"$AndroidAppId`"" |
        Set-Content $androidGradle
    Write-Host "Updated $androidGradle"
} else {
    Write-Host "$androidGradle not found - run 'flutter create .' first"
}

$iosPlist = "ios\Runner\Info.plist"
if (Test-Path $iosPlist) {
    (Get-Content $iosPlist) `
        -replace "<string>net.elitemeet.app</string>", "<string>$IosBundleId</string>" `
        -replace "<string>EliteMeet</string>", "<string>$AppName</string>" |
        Set-Content $iosPlist
    Write-Host "Updated $iosPlist"
} else {
    Write-Host "$iosPlist not found"
}

if ($GoogleServicesJson -ne "") {
    if (Test-Path $GoogleServicesJson) {
        New-Item -ItemType Directory -Force -Path "android\app" | Out-Null
        Copy-Item $GoogleServicesJson "android\app\google-services.json" -Force
        Write-Host "Copied google-services.json into android\app\"
    } else {
        Write-Host "File not found at $GoogleServicesJson - skipped"
    }
} else {
    Write-Host "Skipped google-services.json (no path given) - Firebase/FCM won't work until this exists"
}

if ($GoogleServiceInfoPlist -ne "") {
    if (Test-Path $GoogleServiceInfoPlist) {
        New-Item -ItemType Directory -Force -Path "ios\Runner" | Out-Null
        Copy-Item $GoogleServiceInfoPlist "ios\Runner\GoogleService-Info.plist" -Force
        Write-Host "Copied GoogleService-Info.plist into ios\Runner\"
    } else {
        Write-Host "File not found at $GoogleServiceInfoPlist - skipped"
    }
} else {
    Write-Host "Skipped GoogleService-Info.plist (no path given) - iOS push won't work until this exists"
}

Write-Host ""
Write-Host "=== What's still manual (console-only steps) ==="
Write-Host "  1. Run: flutterfire configure   (regenerates lib\firebase_options.dart with real values)"
Write-Host "  2. Create the 4 IAP products in Google Play Console and App Store Connect - docs\BILLING.md"
Write-Host "  3. Create the Android upload keystore and android\key.properties - docs\SIGNING.md"
Write-Host "  4. Host assetlinks.json and apple-app-site-association on $Domain - docs\DEEP_LINKS.md"
Write-Host "  5. Drop real branding assets into assets\branding\, then run:"
Write-Host "       dart run flutter_launcher_icons"
Write-Host "       dart run flutter_native_splash:create"
Write-Host ""
Write-Host "Full sequence: docs\00_START_HERE.md"
Write-Host "Build environment selected: $BuildEnv (pass via --dart-define=ELITEMEET_ENV=$BuildEnv when running/building)"
