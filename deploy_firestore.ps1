$node     = "C:\Program Files\nodejs\node.exe"
$firebase = "$env:APPDATA\npm\node_modules\firebase-tools\lib\bin\firebase.js"
$project  = "C:\Users\ADMIN\Desktop\Backup\Desktop\class\UG\FYP\nurseassist dupe"

Write-Host "Firebase.js path: $firebase"
Write-Host "Exists: $(Test-Path $firebase)"
Write-Host ""

Set-Location $project

Write-Host "Step 1: Logging in to Firebase..." -ForegroundColor Yellow
Write-Host "Your browser will open. Sign in with the Google account that owns nurseassist-b8242." -ForegroundColor Gray
& $node $firebase login
if ($LASTEXITCODE -ne 0) {
    Write-Host "Login failed. Please try again." -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "Step 2: Selecting project nurseassist-b8242..." -ForegroundColor Yellow
& $node $firebase use nurseassist-b8242
if ($LASTEXITCODE -ne 0) {
    Write-Host "Could not select project." -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "Step 3: Deploying Firestore rules and indexes..." -ForegroundColor Yellow
& $node $firebase deploy --only firestore

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "SUCCESS - Firestore configured!" -ForegroundColor Green
    Write-Host "Security rules : deployed" -ForegroundColor Green
    Write-Host "Composite index: building (check Firebase Console in 1 min)" -ForegroundColor Green
} else {
    Write-Host "Deploy failed. Check the error above." -ForegroundColor Red
}

pause
