@echo off
echo Deploying Jekyll site...

REM 빌드 결과를 gh-pages 브랜치에 푸시
git subtree push --prefix=_site origin site

echo.
echo Deployment completed!
pause