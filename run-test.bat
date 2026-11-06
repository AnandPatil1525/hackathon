@echo off
set "PATH=C:\Program Files\nodejs;%PATH%"
echo Running PS-14 Constraint Verification Suite...
call npm run test:constraints
pause

