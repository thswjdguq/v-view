param(
    [string]$DeviceId,
    [ValidateRange(1, 65535)][int]$Port = 8080,
    [switch]$SoftwareRendering
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$appRoot = Join-Path $projectRoot 'v_view'

try {
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 3
    if ($health.service -ne 'v-view-local-ai') { throw 'Unexpected local service.' }
} catch {
    throw 'PC AI is not running. In server/, run: npm run local:setup, then npm start. Keep that terminal open.'
}

$sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME }
    elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
    else { Join-Path $env:LOCALAPPDATA 'Android/sdk' }
$adbPath = Join-Path $sdkRoot 'platform-tools/adb.exe'
if (!(Test-Path -LiteralPath $adbPath)) { throw 'Android SDK platform-tools were not found.' }
$connected = @(& $adbPath devices | ForEach-Object {
    if ($_ -match '^(\S+)\s+device$') { $Matches[1] }
})
if (!$DeviceId) {
    if ($connected.Count -ne 1) {
        throw 'Connect one USB-debugging Android device or start an emulator. With multiple devices, pass -DeviceId.'
    }
    $DeviceId = $connected[0]
}
if ($connected -notcontains $DeviceId) { throw 'The selected Android device is not ready or has not authorized USB debugging.' }

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterRoot = if ($env:FLUTTER_ROOT) { $env:FLUTTER_ROOT }
    elseif ($flutterCommand) { Split-Path -Parent (Split-Path -Parent $flutterCommand.Source) }
    else { Join-Path $env:USERPROFILE 'flutter' }
$dartPath = Join-Path $flutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
$flutterTool = Join-Path $flutterRoot 'bin/cache/flutter_tools.snapshot'
if (!(Test-Path -LiteralPath $dartPath) -or !(Test-Path -LiteralPath $flutterTool)) {
    throw 'Flutter SDK was not found. Set FLUTTER_ROOT to your Flutter SDK folder.'
}

& $adbPath -s $DeviceId reverse "tcp:$Port" "tcp:$Port"
if ($LASTEXITCODE -ne 0) { throw 'Could not connect the Android device to the PC API.' }
$flutterArgs = @($flutterTool, 'run', '-d', $DeviceId, '-t', 'lib/main_local.dart',
    "--dart-define=LOCAL_AI_URL=http://127.0.0.1:$Port/v1")
if ($SoftwareRendering) { $flutterArgs += @('--enable-software-rendering', '--no-enable-impeller') }
Push-Location $appRoot
try {
    & $dartPath @flutterArgs
    if ($LASTEXITCODE -ne 0) { throw 'Flutter could not run the local app. Check the build output above.' }
} finally {
    Pop-Location
}
