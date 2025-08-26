if "%~1"=="" (
    set COMMIT_MSG=Update site
) else (
    set COMMIT_MSG=%~1
)

git add .
git commit -m "%COMMIT_MSG%"
git push origin main