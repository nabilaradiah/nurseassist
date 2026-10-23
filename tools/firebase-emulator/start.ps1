# Starts the local Firebase Emulator Suite (Auth, Firestore, Storage) for
# NurseAssist. Data is kept between runs in tools/firebase-emulator/data.
#
#   powershell -ExecutionPolicy Bypass -File tools/firebase-emulator/start.ps1
#
# Leave this window open while testing. Press Ctrl+C to stop; the data is
# saved automatically on exit.

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root

# The emulators need Java 11+. Use Android Studio's bundled Java if none is set.
if (-not $env:JAVA_HOME) {
    $jbr = 'C:\Program Files\Android\Android Studio\jbr'
    if (Test-Path $jbr) { $env:JAVA_HOME = $jbr }
}
if ($env:JAVA_HOME) { $env:PATH = "$env:JAVA_HOME\bin;$env:PATH" }

$data = 'tools/firebase-emulator/data'
$emulatorArgs = @(
    'emulators:start',
    '--project', 'nurseassist-b8242',
    '--only', 'auth,firestore,storage',
    '--export-on-exit', $data
)
if (Test-Path $data) { $emulatorArgs += @('--import', $data) }

firebase @emulatorArgs
