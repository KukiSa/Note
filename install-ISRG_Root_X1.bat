@echo off

echo Welcome to ISRG Root X1 Installer!

net.exe session 1>NUL 2>NUL && (
    goto as_admin
) || (
    goto not_admin
)

:as_admin
mkdir %TMP%\isrgrootx1\

certutil.exe -urlcache -split -f http://x1.i.lencr.org/ %TMP%\isrgrootx1\ISRGRootX1.crt || goto error
certutil.exe -addstore "Root" %TMP%\isrgrootx1\ISRGRootX1.crt || goto error

echo Successful installation!

goto end

:not_admin
echo "ERROR! Please Run it as Administrator!"
goto end

:error
echo "ERROR! Access Denied."
goto end

:end
del /q %TMP%\isrgrootx1\
pause
