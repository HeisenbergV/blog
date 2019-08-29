rm -r public
hugo 
rm favicon.ico
rm -r js
rm -r series
rm -r about
rm -r categories
rm -r fonts
rm -r page
rm -r css
rm -r images
rm -r tags
rm -r posts
rm mstile-150x150.png
rm site.webmanifest
rm android-chrome-192x192.png
rm android-chrome-384x384.png
rm favicon-16x16.png
cp -r public/* .
git add .
git commit -m  "new blog $(date "+%Y%m%d-%H:%M:%S")"
git push origin master