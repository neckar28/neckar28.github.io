@echo off
echo Building and deploying Jekyll site...

REM Jekyll 빌드
bundle exec jekyll build

REM 빌드 결과를 gh-pages 브랜치에 푸시
git subtree push --prefix=_site origin gh-pages

echo.
echo Deployment completed!
pause