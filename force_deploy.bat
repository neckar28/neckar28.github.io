git subtree split --prefix=_site -b temp-gh-pages
git push origin temp-gh-pages:gh-pages --force
git branch -D temp-gh-pages
