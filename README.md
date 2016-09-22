# centos-build-iso

Script to build unattended install ISO's for Centos 7, optionally with updates, extras and Cockpit or native Docker. Useful for deploying a CentOS 7 based host, optionally with Docker, Cockpit and a selection of tools from a single ISO on servers without internet access.


## Features:

Starring:
 - Latest Docker
 - Cockpit with Red Hat Docker version (1.10.3 up)
 - devicemapper storage for Docker with Direct LVM thin pool 
 - VMware tools

Network tools:
- arp-scan
- bind-utils
- nmap
- tcpdump
- traceroute
- telnet
- whois
- wget

System tools:
- iftop
- lsof
- mkisofs
- mlocate
- ntp
- nfs-utils
- open-vm-tools
- yum-utils


## Prerequisites

The script needs Enterprise Linux to run. To build a Centos ISO with COckpit, Docker and the tools a clean install is required (see known issues). 

## Usage

To build a Centos ISO, run the script and specify the ISO flavor you need (vanilla, docker or cockpit). 

## Best practice

Best practice is to build a plain vanilla ISO first, install it in a hypervisor and use the script again to build a Docker or Cockpit ISO. 

Don't install any packages on the vanilla vm, as this may interfere with the building process. Git for example installs dependencies that are also required by arp-scan. The script won't download these dependencies for the ISO if Git already installed them. 

## Credentials

Default username/password for all images is root/password

## Configuration

You should at least change the default password 'password' by replacing the current salt and hash in the kickstart part of the script. In some cases a custom NTP configuration is necessary, e.g. enterprise environments

## Notes

Docker reverts to loopback when available space for Direct-LVM is less than 1GB.

## Known issues

- updates and packages are downloaded relative to OS version the scripts run on. Workaround is to unattended install a clean system first, and run the scripts on the clean system (perhaps make a snapshot first ;)

- when using Git client, git and arp-scan package dependencies fail to download due to existing Git and Perl packages. This can be solved using something like 'yum install --downloadonly --downloaddir=deps $(repoquery --requires --recursive --alldeps $1)'

(Please email me if you encounter a bug)


