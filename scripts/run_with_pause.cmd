@echo off
setlocal
set "REPO=%USERPROFILE%\hecate-nautilus"
set "LOG=%REPO%\scripts\auto_fix_and_test.log"
if exist "%ProgramFiles%\Git\bin\bash.exe" (
  set "GITBASH=%ProgramFiles%\Git\bin\bash.exe"
) else if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" (
  set "GITBASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
) else (
  echo [ERRO] Git Bash nao encontrado.
  pause
  exit /b 1
)
cd /d "%REPO%"
echo [*] Rodando run_fix.sh (log em %LOG%) ...
"%GITBASH%" -lc "cd \"$REPO\"; ./scripts/run_fix.sh 2>&1 | tee \"$LOG\" ; echo ; echo 'PRESS ENTER TO CLOSE'; read _ < /dev/tty || true"
echo.
pause
