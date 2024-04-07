#!/usr/bin/env bash
#-------------------------------------------------------
# Requirement:  `openssl`
# Note:         `openssl` commond is used.
#-------------------------------------------------------
# Function:     Use OpenSSL to generate a CRL from a
#               configuration file.
# Platform:     Compatible, all OS and arch.
#
# Filename:     autoCreateCrl.sh
# Revision:     1.0.1
# Date:         February 22, 2023
# Author:       Signaliks
# Email:        i@iks.moe
#-------------------------------------------------------

# `-out` is the output path of the CRL file, and `-config` is the path of the root certificate PKI config file.
openssl ca -gencrl -out /www/wwwroot/pki.iks.moe/static/crl/YoungdoRootCA.crl -config /root/CA/RootCA/rootca.cnf
openssl ca -gencrl -out /www/wwwroot/pki.iks.moe/static/crl/YoungdoSecureCodeSigningCAR2.crl -config /root/CA/codesignov/powerca.cnf
