# centos-build

Script to build unattended install ISO's for Centos 7, optionally with updates, extras and Cockpit or native Docker. Useful for deploying a CentOS 7 based host, optionally with Docker, Cockpit and a selection of tools from a single ISO on servers without internet access.

## Features:

Starring:
 - Latest Docker/Cockpit (with older Red Hat Docker version) (1.10.3 up)
 - devicemapper storage for Docker with Direct LVM thin pool 
 - VMware tools

Network tools:
	arp-scan
	bind-utils
	nmap
	tcpdump
	traceroute
	telnet
	whois
	wget

System tools:
	iftop
	lsof
	mkisofs
	mlocate
	ntp
	nfs-utils
	open-vm-tools
	yum-utils

## Credentials

Default username/password for all images is root/password


## Notes

Docker reverts to loopback when available space for Direct-LVM is less than 1GB.

## Known issues

- updates and packages are downloaded relative to OS version the scripts run on. Workaround is to unattended install a clean system first, and run the scripts on the clean system (perhaps make a snapshot first ;)

- when using Git client, git and arp-scan package dependencies fail to download due to existing Git and Perl packages. This can be solved using something like 'yum install --downloadonly --downloaddir=deps $(repoquery --requires --recursive --alldeps $1)'

(Please email me if you encounter a bug)


