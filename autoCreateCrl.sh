#!/bin/bash

# ONLY for OpenSSL
# `-out` is the output path of the CRL file, and `-config` is the path of the root certificate PKI config file.
openssl ca -gencrl -out /www/wwwroot/pki.iks.moe/static/crl/YoungdoRootCA.crl -config /root/CA/RootCA/rootca.cnf
openssl ca -gencrl -out /www/wwwroot/pki.iks.moe/static/crl/YoungdoSecureCodeSigningCAR2.crl -config /root/CA/codesignov/powerca.cnf
