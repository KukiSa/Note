# introduce

This directory stores the configuration files of the two reverse proxy nodes of MoeLink.

## environmental needs
Nginx 1.18 and above
LNMP.org One Click Package 1.16 and above

## Directory Structure
The files `lnmp-listen80` and `lnmp-listen443` are part of the file `/usr/bin/lnmp`.
The file `nginx.conf` is the main Nginx configuration file, and the files `fproxy.conf` and `sslproxy.conf` should be placed in the same directory.
The file `website.conf` is a sample final configuration for the site.
