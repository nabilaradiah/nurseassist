@echo off
set PATH=C:\Program Files\nodejs;%PATH%

cd /d "C:\Users\ADMIN\Desktop\Backup\Desktop\class\UG\FYP\nurseassist dupe"

echo.
echo Step 1: Logging in to Firebase...
echo Your browser will open - sign in with Google.
echo.
npx firebase-tools@latest login
if %errorlevel% neq 0 ( echo Login failed. & pause & exit /b 1 )

echo.
echo Step 2: Deploying Firestore rules and indexes...
npx firebase-tools@latest deploy --only firestore --project nurseassist-b8242
if %errorlevel% equ 0 (
    echo.
    echo SUCCESS - Firestore configured!
) else (
    echo Deploy failed. Check error above.
)

echo.
pause
