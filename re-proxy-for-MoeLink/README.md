# Introduction
This directory stores the configs of the two reverse proxy points for MoeLink.

## Environmental Requirements
Nginx version 1.18.1 and above installed through LNMP.org one-click script.

## Directory Structure
The files `lnmp-listen80` and `lnmp-listen443` are part of the file `/usr/bin/lnmp`.

The file `nginx.conf` is the main Nginx configuration file, and the files `fproxy.conf` and `sslproxy.conf` should be placed in the same directory.

The file `website.conf` is a sample of final config for the site.
