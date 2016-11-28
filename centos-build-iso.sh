#!/bin/bash

# centos-build-iso
#
#	Unattended installation ISO builder for Centos 7.2 
#	with optionally updates, tools, Docker and Cockpit

#-------------------------------------------------------------------------------	Parameters

# selected flavor
ISO_FLAVOR=$1

# download mirror (1511 release = Centos 7.2)
ISO_URL=http://buildlogs.centos.org/rolling/7/isos/x86_64/CentOS-7-x86_64-Minimal-1511.iso
ISO_NAME=$(echo $ISO_URL|rev|cut -d/ -f1|rev)

# name of the target ISO file
ISO_TITLE=centos72-$ISO_FLAVOR


#-------------------------------------------------------------------------------	Helper functions

function yumpreload {
	# pre-download a package for unattended installation from iso

	TARGETDIR=$1
	shift
	# pre-download specified package
	while (( "$#" )); do
		yum install --downloadonly --downloaddir=$TARGETDIR/$1 $1
		shift
	done
}

#-------------------------------------------------------------------------------	Functions

function prepare_iso {	
	# load base image and modify boot menu

	# download baseimage if not present
	if [ ! -e $PWD/../$ISO_NAME ]
	then 
		curl -o ../$ISO_NAME $ISO_URL
	fi

	# create iso directory
	mkdir -p $PWD/iso

	# mount ISO to /media
	mount -o loop $PWD/../$ISO_NAME /media

	# copy base iso files from /media to working directory
	cp -r /media/* $PWD/iso
	cp /media/.treeinfo $PWD/iso
	cp /media/.discinfo $PWD/iso
	umount /media

	# remove menu default
	grep -v "menu default" $PWD/iso/isolinux/isolinux.cfg > $PWD/iso/isolinux/isolinux.cfg.new; \
		mv $PWD/iso/isolinux/isolinux.cfg.new $PWD/iso/isolinux/isolinux.cfg
	# add menu option ’Unattended Install’ to isolinux.cfg 
	cat $PWD/iso/isolinux/isolinux.cfg \
		| sed 's/label linux/label unattended\n  menu label ^Unattended Install\n  menu default\n  \
			kernel vmlinuz\n  append ks=cdrom:\/isolinux\/ui\/ks.cfg initrd=initrd.img\nlabel linux/' \
		| sed 's/timeout 600/timeout 100/'>$PWD/iso/isolinux/isolinux.cfg.new
	mv $PWD/iso/isolinux/isolinux.cfg.new $PWD/iso/isolinux/isolinux.cfg

	# create UnattendedInstall directory
	mkdir $PWD/iso/isolinux/ui

}

function download_updates {
	# download updates and extra packages

	# pre-install and install latest updates 
	yum clean all
	yum update --downloadonly --downloaddir=$PWD/iso/updates
	# install updates for identical baseline as during installation
	rpm -Uvh --replacepkgs $PWD/iso/updates/*.rpm	

}

function download_dependencies {
	# install dependencies like repositories 

	# pre-download and install epel-release as dependency
	yumpreload $PWD/iso/deps \
		epel-release
	# install epel-release
	yum install -y $PWD/iso/deps/epel-release/*.rpm

}

function download_cockpit {
	# pre-download Cockpit with related Docker engine

	yumpreload $PWD/iso/extras \
		cockpit

	# postinstall: enable cockpit and docker
	cat > $PWD/iso/extras/cockpit/post-install.sh <<-'EOF'
	#!/bin/bash	
	systemctl enable docker
	systemctl enable cockpit.socket
	EOF
	chmod +x $PWD/iso/extras/cockpit/post-install.sh
}

function download_docker {
	# download latest Docker release from Docker repo

	# pre-install Docker: first add Docker repo
	mkdir -p $PWD/iso/extras/docker-engine
	cat > $PWD/iso/extras/docker-engine/pre-install.sh <<-'EOF'
	#!/bin/bash
	cat > /etc/yum.repos.d/docker.repo <<-'EOF2'
	[dockerrepo]
	name=Docker Repository
	baseurl=https://yum.dockerproject.org/repo/main/centos/$releasever/
	enabled=1
	gpgcheck=1
	gpgkey=https://yum.dockerproject.org/gpg
	EOF2

	# add thin pool configuration
	mkdir -p /etc/docker
	cat > /etc/docker/daemon.json <<-'EOF2'
	 {
		"storage-driver": "devicemapper",
		"storage-opts": [
			"dm.thinpooldev=/dev/mapper/vg_01-thinpool",
			"dm.use_deferred_removal=true"
		]
	}
	EOF2
	EOF
	chmod +x $PWD/iso/extras/docker-engine/pre-install.sh
	# add the repo in order to pre-download Docker
	source $PWD/iso/extras/docker-engine/pre-install.sh

	# postinstall: enable docker in systemd
	cat > $PWD/iso/extras/docker-engine/post-install.sh <<-'EOF'
	#!/bin/bash	
	systemctl enable docker
	EOF
	chmod +x $PWD/iso/extras/docker-engine/post-install.sh

	# pre-install latest Docker engine
	yumpreload $PWD/iso/extras \
		docker-engine
}


function download_dockercompose {
	# download docker-compose v1.9.0
	mkdir -p $PWD/iso/extras/docker-compose
	curl -L https://github.com/docker/compose/releases/download/1.9.0/docker-compose-`uname -s`-`uname -m` > $PWD/iso/extras/docker-compose/docker-compose
	chmod +x $PWD/iso/extras/docker-compose/docker-compose

	# post-installation: copy docker-compose to local OS
	cat > $PWD/iso/extras/docker-compose/post-install.sh <<-'EOF'
	#!/bin/bash	
	cp -f /media/extras/docker-compose/docker-compose /usr/local/bin
	EOF
	chmod +x $PWD/iso/extras/docker-compose/post-install.sh
}


function download_extras {
	# download selected tools

	# pre-download network tools	
	yumpreload $PWD/iso/extras \
		arp-scan \
		bind-utils \
		iftop \
		nmap \
		tcpdump \
		traceroute \
		telnet \
		whois \
		wget

	# pre-install other tools
	yumpreload $PWD/iso/extras \
		git \
		lsof \
		mkisofs \
		mlocate \
		ntp \
		nfs-utils \
		yum-utils

	# pre-install VMware tools
	yumpreload $PWD/iso/extras \
		open-vm-tools
	# post-install: enable vmtoold 
	cat > $PWD/iso/extras/open-vm-tools/post-install.sh <<-'EOF'
	#!/bin/bash
	systemctl enable vmtoolsd
	EOF
	chmod +x $PWD/iso/extras/open-vm-tools/post-install.sh
}


function download_firewalld {
	# pre-download FirewallD
	yumpreload $PWD/iso/extras \
		firewalld
}


function disable_networkmanager {
	# disable the service by default
	mkdir -p $PWD/iso/extras/networkmanager
	cat > $PWD/iso/extras/networkmanager/post-install.sh <<-'EOF'
	#!/bin/bash	
	systemctl disable NetworkManager
	EOF
	chmod +x $PWD/iso/extras/firewalld/post-install.sh
}

function add_kickstart_script {
	## add kickstart script

	cat > $PWD/iso/isolinux/ui/ks.cfg <<-'EOF'
	#version=RHEL7
	# System authorization information
	auth --enableshadow --passalgo=sha512

	logging --level=debug

	# open the Cockpit port from ks
	firewall --enable --port=9090

	# Use CDROM installation media
	cdrom
	# Run the Setup Agent on first boot
	firstboot --enable
	ignoredisk --only-use=sda
	# Keyboard layouts
	keyboard --vckeymap=us --xlayouts='us'
	# System language
	lang en_US.UTF-8

	# Network information
	network  --bootproto=dhcp --device=ens32 --ipv6=auto --activate
	network  --hostname=centos72.local

	# default credentials: root/password
	rootpw --iscrypted \$6\$m8EiTs1A\$1k.2BJUslIR6oXoyckalPu6KBfi608WPFHWMnNqaoQ71XBNSn85cpQvYPe.ITMxZRsNYhZqtppPUxfkuOwkiF1

	# System timezone
	timezone Europe/Amsterdam --isUtc --nontp

	# selinux setting
	selinux --permissive

	# install in textmode
	text

	# --- Disk partitioning and configuration

	# System bootloader configuration
	bootloader --location=mbr --boot-drive=sda
	# Partition clearing information
	zerombr
	clearpart --all --initlabel 

	# Disk partitioning information

	# create 500MB boot partition
	part /boot --fstype="ext4" --ondisk=sda --size=500

	# use all remaining diskspace for LVM
	part pv.1 --fstype="lvmpv" --ondisk=sda --size=1 --grow

	# create a volume group 
	volgroup vg_01 --pesize=4096 pv.1

	# Create logical volumes (min space required 20GB)
	logvol /  --fstype="ext4" --size=5000 --name=root --vgname=vg_01
	logvol swap  --fstype="swap" --size=4000 --name=swap --vgname=vg_01
	logvol /var --fstype="ext4" --size=6000 --name=var --vgname=vg_01


	%packages --nobase
	@core
	%end




	%post --log=/root/ks-post.log
	#!/bin/bash
	EOF
}

function add_thin_pools2kickstart {
	# add thin pools for native Docker installation

	cat >> $PWD/iso/isolinux/ui/ks.cfg <<-'EOF'

	# define Docker direct-lvm thin pool storage
	lvcreate -l 90%FREE -T vg_01/thinpool
	EOF
}

function add_postinstall2kickstart {
	# add script to install extras during postinstall

	cat >> $PWD/iso/isolinux/ui/ks.cfg <<-'EOF'

	# mount iso 
	mount -r -t iso9660 /dev/sr0 /media

	# install updates
	if [ -d /media/updates ]; then 
		echo - Installing OS updates
		rpm  -Uvh /media/updates/*.rpm
	fi


	# install extra's from iso
	for i in /media/deps/* /media/extras/*; do
		if [ -d $i ]; then 

			# packages in subdirectories are considered requirements for main package
			for j in $i/*; do
				if [ -d $j ]; then 			
					rpm -Uvh --replacepkgs $j/*.rpm
				fi
			done

			# run pre-install script
			if [ -f $i/pre-install.sh ]; then
				source $i/pre-install.sh
			fiq

			# main package
			package=$(echo $i|cut -d"/" -f4)
			echo $package >> /root/installed-extras

			echo - Installing $package
			rpm -Uvh --replacepkgs $i/*.rpm 2>&1 

			# run post-install script
			if [ -f $i/post-install.sh ]; then
				source $i/post-install.sh
			fi
		fi
	done
EOF
}

function add_settings2kickstart {
	# add script to configure default settings during postinstall 
	cat >> $PWD/iso/isolinux/ui/ks.cfg <<-'EOF'

	## configure settings


	# send a null packet to the server every minute to keep the ssh connection alive
	echo "ServerAliveInterval 60" >> /etc/ssh/ssh_config


	# mount with noatime to prevent excessive SSD wear
	cat /etc/fstab |sed 's/defaults/defaults,noatime/g' >/tmp/fstab; mv -f /tmp/fstab /etc/fstab

	# disable NetworkManager by default
	systemctl disable NetworkManager

	# disable FirewallD by default
	systemctl disable firewalld

	# disable IPv6
	cat >> /etc/sysctl.conf <<-"EOF2"
	net.ipv6.conf.all.disable_ipv6 = 1
	net.ipv6.conf.default.disable_ipv6 = 1
	EOF2
	# change setting here as well
	cat >> /etc/sysconfig/network <<-"EOF2"
	NETWORKING_IPV6=no
	EOF2
	# prevent breaking ssh x-forwarding with ipv6
	cat /etc/ssh/sshd_config | \
		sed 's/#AddressFamily/AddressFamily/g' | \
		sed 's/AddressFamily any/AddressFamily inet/g' | \
		sed 's/#ListenAddress/ListenAddress/g' |\
		grep -v "ListenAddress ::" \
		> /etc/ssh/.sshd_config; mv -f /etc/ssh/.sshd_config /etc/ssh/sshd_config


	# set local timeserver
	if [ -f /etc/ntp.conf ]; then
		# - first, remove old timeservers
		cat /etc/ntp.conf |grep -v "^server " > /etc/.ntp.conf; mv -f /etc/.ntp.conf /etc/ntp.conf 
		# - next, add custom NTP server (change if needed)
		NTPSERVER=pool.ntp.org
		echo "server $NTPSERVER" >> /etc/ntp.conf
		# enable NTP timesync
		systemctl enable ntpd
		timedatectl set-ntp yes
	fi


	%end

	# reboot the machine after installation
	reboot
EOF
}

function create_iso {
	## create ISO file

	yum install -y mkisofs
	mkisofs -r -T -J \
		-V “CentOS-v7.2-$ISO_FLAVOR” \
		-b isolinux/isolinux.bin \
		-c isolinux/boot.cat \
		-no-emul-boot \
		-boot-load-size 4 \
		-boot-info-table \
		-o ~/$ISO_TITLE.iso \
		$PWD/iso/

	# delete iso. Disable this line to save time during development
	rm -rf $PWD/iso

	# show result
	echo $ISO_TITLE.iso is ready in your homedir
}


#---------------------------------------------------------------------------------  Main script

	
# build the selected iso flavor. Note that the indented statements are what separates the flavors from Vanilla.

case "$ISO_FLAVOR" in 
	vanilla)
		# create vanilla CentOS 7.2 image (only add kickstart for unattended install)

		# download and unpack base image
		prepare_iso
		# download and DISABLE firewalld
			download_firewalld
		# add kickstart script to iso
		add_kickstart_script 
		# add default settings to kickstart
		add_settings2kickstart
		# create unattended install iso from workspace
		create_iso
		;;

	update)
		# create vanilla CentOS 7.2 image with latest updates

		# download and unpack base image
		prepare_iso
		# download updates
			download_updates
		# download and DISABLE firewalld
			download_firewalld
		# add kickstart script to iso
		add_kickstart_script 
		# add post-install to kickstart
			add_postinstall2kickstart 		
		# add default settings to kickstart
		add_settings2kickstart
		# create unattended install iso from workspace
		create_iso
		;;

	tools)
		# CentOS 7.2 image with latest updates and tools

		# download and unpack base image
		prepare_iso
		# download updates
			download_updates
		# download dependencies like repositories etc
			download_dependencies
		# download extra tools
			download_extras
		# download firewalld
			download_firewalld
		# add kickstart script to iso
		add_kickstart_script
		# add post-install to kickstart
			add_postinstall2kickstart 
		# add default settings to kickstart
		add_settings2kickstart
		# create unattended install iso from workspace
		create_iso		
		;;


	docker)
		# create CentOS 7.2 image with latest updates, latest Docker package and tools

		# download and unpack base image
		prepare_iso
		# download updates
			download_updates
		# download dependencies like repositories etc
			download_dependencies
		# install latest Docker release
			download_docker
		# download extra tools
			download_extras
		# download firewalld
			download_firewalld
		# add kickstart script to iso
		add_kickstart_script
		# add thin pools to kickstart
			add_thin_pools2kickstart 
		# add post-install to kickstart
			add_postinstall2kickstart 
		# add default settings to kickstart
		add_settings2kickstart
		# create unattended install iso from workspace
		create_iso		
		;;

	cockpit)
		# create CentOS 7.2 image with latest updates, Cockpit with Red Hat Docker package and tools

		# download and unpack base image
		prepare_iso
		# create CentOS 7.2 image with Cockpit and Docker (latest Red Hat Docker release)
			download_updates
		# download dependencies like repositories etc
			download_dependencies
		# install Cockpit with Red Hat's Docker package
			download_cockpit
		# download extra tools
			download_extras
		# download firewalld
			download_firewalld
		# add kickstart script to iso
		add_kickstart_script 
		# add post-install to kickstart
			add_postinstall2kickstart 
		# add default settings to kickstart
		add_settings2kickstart
		# create unattended install iso from workspace
		create_iso
		;;

	*)
		# no parameter specified, show usage
		echo "Usage: $0 {vanilla|update|tools|docker|cockpit}"
		exit 1;
esac


#-------------------------------------------------------------------------------	End
