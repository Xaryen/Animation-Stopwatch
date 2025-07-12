@echo off

set "COMMIT_MESSAGE=".."

if NOT "%~1"=="" (
   set "COMMIT_MESSAGE=%~1"
)

git add .
git commit -a -m %COMMIT_MESSAGE%
git push