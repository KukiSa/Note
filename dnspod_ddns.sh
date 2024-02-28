#!/bin/sh

__ddns_wan_ip=$(ifconfig pppoe-wan | awk '/inet addr/{print substr($2,6)}')
echo WAN IP Address is $__ddns_wan_ip.

# [DNSAPIID] A short number. Create and cpoy it from https://console.dnspod.cn/account/token/token.
# [APIToken] A UUID string without delimiters, generated in the previous step.
# [DomainID] A short number. Get it from https://console.dnspod.cn/dns/[YourDomain]/set.
# [RecordID] Get it from https://docs.dnspod.cn/api/record-list/.

curl -d 'login_token=[DNSAPIID],[APIToken]&format=json&domain_id=[DomainID]&record_id=[RecordID]&record_line_id=0' https://dnsapi.cn/Record.Ddns
unset __ddns_wan_ip
return $?
exit
