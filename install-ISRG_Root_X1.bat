@echo off
setlocal
set "WORKDIR=%TMP%\isrgrootx1"

echo Welcome to ISRG Root X1 Installer!

net.exe session 1>NUL 2>NUL && (
    goto as_admin
) || (
    goto not_admin
)

:as_admin
rmdir /s /q "%WORKDIR%" 2>NUL
mkdir "%WORKDIR%" || goto error

certutil.exe -urlcache -split -f http://x1.i.lencr.org/ "%WORKDIR%\ISRGRootX1.crt" || goto error
certutil.exe -addstore "Root" "%WORKDIR%\ISRGRootX1.crt" || goto error

echo Successful installation!

goto end

:not_admin
echo "ERROR! Please Run it as Administrator!"
goto end

:error
echo "ERROR! Installation failed."
goto end

:end
rmdir /s /q "%WORKDIR%" 2>NUL
pause
