@echo off
echo Deploying Jekyll site...

bundle exec jekyll build

git subtree split --prefix _site -b site

echo.
echo Deployment completed!
pause