#!/bin/bash

#    Copyright 2015-2017 Gilbert Standen
#    This file is part of orabuntu-lxc.

#    Orabuntu-lxc is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.

#    Orabuntu-lxc is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with orabuntu-lxc.  If not, see <http://www.gnu.org/licenses/>.

#    v2.4 GLS 20151224
#    v2.8 GLS 20151231
#    v3.0 GLS 20160710 Updates for Ubuntu 16.04
#    v4.0 GLS 20161025 DNS DHCP services moved into an LXC container

clear

MajorRelease=$1
OracleRelease=$1$2
OracleVersion=$1.$2
OR=$OracleRelease
Config=/var/lib/lxc/$SeedContainerName/config

function GetSeedContainerName {
        sudo lxc-ls -f | grep oel$OracleRelease | cut -f1 -d' '
}
SeedContainerName=$(GetSeedContainerName)

GetLinuxFlavors(){
if   [[ -e /etc/oracle-release ]]
then
        LinuxFlavors=$(cat /etc/oracle-release | cut -f1 -d' ')
elif [[ -e /etc/redhat-release ]]
then
        LinuxFlavors=$(cat /etc/redhat-release | cut -f1 -d' ')
elif [[ -e /usr/bin/lsb_release ]]
then
        LinuxFlavors=$(lsb_release -d | awk -F ':' '{print $2}' | cut -f1 -d' ')
elif [[ -e /etc/issue ]]
then
        LinuxFlavors=$(cat /etc/issue | cut -f1 -d' ')
else
        LinuxFlavors=$(cat /proc/version | cut -f1 -d' ')
fi
}
GetLinuxFlavors

function TrimLinuxFlavors {
echo $LinuxFlavors | sed 's/^[ \t]//;s/[ \t]$//'
}
LinuxFlavor=$(TrimLinuxFlavors)

if   [ $LinuxFlavor = 'Oracle' ]
then
        function GetOracleDistroRelease {
                sudo cat /etc/oracle-release | cut -f5 -d' ' | cut -f1 -d'.'
        }
        OracleDistroRelease=$(GetOracleDistroRelease)
        Release=$OracleDistroRelease
        LF=$LinuxFlavor
        RL=$Release
elif [ $LinuxFlavor = 'CentOS' ]
then
        function GetCentOSDistroRelease {
                sudo cat /etc/centos-release | cut -f4 -d' ' | cut -f1 -d'.'
        }
        CentOSDistroRelease=$(GetCentOSDistroRelease)
        Release=$CentOSDistroRelease
        LF=$LinuxFlavor
        RL=$Release
elif [ $LinuxFlavor = 'Red' ]
then
        function GetRedHatVersion {
                sudo cat /etc/redhat-release | cut -f7 -d' ' | cut -f1 -d'.'
        }
        RedHatVersion=$(GetRedHatVersion)
        Release=$RedHatVersion
        LF=$LinuxFlavor
        RL=$Release
fi

echo ''
echo "=============================================="
echo "Script: lxcentos-services-5.sh                  "
echo "=============================================="
echo ''
echo "=============================================="
echo "This script is re-runnable.                   "
echo "=============================================="
echo ''
echo "=============================================="
echo "This script starts lxc clones                 "
echo "=============================================="

sleep 5

clear



echo "=============================================="
echo "Create additonal OpenvSwitch networks...      "
echo "=============================================="
echo ''

sleep 5

clear

SwitchList='sw2 sw3 sw4 sw5 sw6 sw7 sw8 sw9'
for k in $SwitchList
do
	echo ''
	echo "=============================================="
	echo "Create systemd OpenvSwitch $k service...      "
	echo "=============================================="

        if [ ! -f /etc/systemd/system/$k.service ]
        then
                sudo sh -c "echo '[Unit]'						 > /etc/systemd/system/$k.service"
                sudo sh -c "echo 'Description=$k Service'				>> /etc/systemd/system/$k.service"
                sudo sh -c "echo 'After=network-online.target'				>> /etc/systemd/system/$k.service"
                sudo sh -c "echo ''							>> /etc/systemd/system/$k.service"
                sudo sh -c "echo '[Service]'						>> /etc/systemd/system/$k.service"
                sudo sh -c "echo 'Type=oneshot'						>> /etc/systemd/system/$k.service"
                sudo sh -c "echo 'User=root'						>> /etc/systemd/system/$k.service"
                sudo sh -c "echo 'RemainAfterExit=yes'					>> /etc/systemd/system/$k.service"
                sudo sh -c "echo 'ExecStart=/etc/network/openvswitch/crt_ovs_$k.sh' 	>> /etc/systemd/system/$k.service"
                sudo sh -c "echo ''							>> /etc/systemd/system/$k.service"
                sudo sh -c "echo '[Install]'						>> /etc/systemd/system/$k.service"
                sudo sh -c "echo 'WantedBy=multi-user.target'				>> /etc/systemd/system/$k.service"
	fi
	
	echo ''
	echo "=============================================="
	echo "Start OpenvSwitch $k ...            "
	echo "=============================================="
	echo ''

        sudo chmod 644 /etc/systemd/system/$k.service
        sudo systemctl enable $k.service
	sudo service $k start
	sudo service $k status

	echo ''
	echo "=============================================="
	echo "OpenvSwitch $k is up.                         "
	echo "=============================================="
	
	sleep 3

	clear
done

echo ''
echo "=============================================="
echo "Openvswitch networks installed & configured.  "
echo "=============================================="
echo ''

sleep 5

clear

echo ''
echo "=============================================="
echo "Starting LXC cloned containers for Oracle...  "
echo "=============================================="

function CheckClonedContainersExist {
sudo ls /var/lib/lxc | grep "ora$OracleRelease" | sort -V | sed 's/$/ /' | tr -d '\n' 
}
ClonedContainersExist=$(CheckClonedContainersExist)

for j in $ClonedContainersExist
do
	# GLS 20160707 updated to use lxc-copy instead of lxc-clone for Ubuntu 16.04
	# GLS 20160707 continues to use lxc-clone for Ubuntu 15.04 and 15.10

	sudo /etc/network/openvswitch/veth_cleanups.sh $j > /dev/null 2>&1

	echo ''
	echo "Starting container $j ..."
	echo ''
	if [ $Release = '7' ] || [ $Release = '6' ]
	then
	function CheckPublicIPIterative {
	sudo lxc-ls -f | sed 's/  */ /g' | grep $j | grep RUNNING | cut -f2 -d'-' | sed 's/^[ \t]*//;s/[ \t]*$//' | cut -f1 -d' ' | cut -f1-2 -d'.' | sed 's/\.//g'
	}
	fi
	PublicIPIterative=$(CheckPublicIPIterative)
	echo $j | grep oel > /dev/null 2>&1
	if [ $? -eq 0 ]
	then
	sudo bash -c "cat $Config|grep ipv4|cut -f2 -d'='|sed 's/^[ \t]*//;s/[ \t]*$//'|cut -f4 -d'.'|sed 's/^/\./'|xargs -I '{}' sed -i "/ipv4/s/\{}/\.1$OR/g" $Config"
#	sudo sed -i "s/\.39/\.$OracleRelease/g" /var/lib/lxc/$SeedContainerName/config
#	sudo sed -i "s/\.40/\.$OracleRelease/g" /var/lib/lxc/$SeedContainerName/config
	fi
	sudo lxc-start -n $j > /dev/null 2>&1
	sleep 5
	i=1
	while [ "$PublicIPIterative" != 10207 ] && [ "$i" -le 10 ]
	do
		echo "Waiting for $j Public IP to come up..."
		sleep 20
		PublicIPIterative=$(CheckPublicIPIterative)
		if [ $i -eq 5 ]
		then
			sudo lxc-stop -n $j
			sleep 2
			echo ''
			sudo /etc/network/openvswitch/veth_cleanups.sh $j
			echo ''
			sleep 2
			sudo lxc-start -n $j
			sleep 5
			if [ $MajorRelease -eq 6 ] || [ $MajorRelease -eq 5 ]
			then
				sudo lxc-attach -n $j -- ntpd -x
			fi
		fi
	sleep 1
	i=$((i+1))
	done
done

echo ''
echo "=============================================="
echo "LXC clone containers for Oracle started.      "
echo "=============================================="
echo ''

sleep 5

clear

echo ''
echo "=============================================="
echo "LXC containers for Oracle started.            "
echo "=============================================="
echo ''

sudo lxc-ls -f

echo ''
echo "=============================================="

sleep 5

clear

echo ''
echo "=============================================="
echo "Management links directory creation...        "
echo "Location is:  /home/ubuntu/Play-The-Uekulele  "
echo "Step creates pointers to relevant files for   "
echo "quickly locating Orabuntu-LXC config files.   "
echo "=============================================="
echo ''

sleep 5

if [ ! -e /home/ubuntu/Play-The-Uekulele ]
then
mkdir /home/ubuntu/Play-The-Uekulele
fi

cd /home/ubuntu/Play-The-Uekulele
sudo chmod 755 /etc/orabuntu-lxc-scripts/crt_links.sh 
sudo /etc/orabuntu-lxc-scripts/crt_links.sh

echo ''
sudo ls -l /home/ubuntu/Play-The-Uekulele
echo ''

echo ''
echo "=============================================="
echo "Management links directory created.           "
echo "=============================================="
echo ''

sleep 10

clear

echo ''
echo "=============================================="
echo "Create selinux-lxc.sh file...                 "
echo "=============================================="
echo ''

mkdir -p ./lxcentos/selinux
touch ./lxcentos/selinux/selinux-lxc.sh
ls -l ./lxcentos/selinux/selinux-lxc.sh
sudo chmod 775 ./lxcentos/selinux/selinux-lxc.sh
echo ''
cd ./lxcentos/selinux

echo 'sudo ausearch -c 'lxcattach' --raw | audit2allow -M my-lxcattach'			>  ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-lxcattach.pp'							>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo ausearch -c 'dhclient' --raw | audit2allow -M my-dhclient'			>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-dhclient.pp'							>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo ausearch -c 'passwd' --raw | audit2allow -M my-passwd'			>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-passwd.pp'							>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo ausearch -c 'sedispatch' --raw | audit2allow -M my-sedispatch'		>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-sedispatch.pp'						>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo ausearch -c 'systemd-sysctl' --raw | audit2allow -M my-systemdsysctl'	>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-systemdsysctl.pp'						>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo ausearch -c 'ovs-vsctl' --raw | audit2allow -M my-ovsvsctl'			>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-ovsvsctl.pp'							>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo ausearch -c 'sshd' --raw | audit2allow -M my-sshd'				>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-sshd.pp'							>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo ausearch -c 'gdm-session-wor' --raw | audit2allow -M my-gdmsessionwor'	>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-gdmsessionwor.pp'						>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo ausearch -c 'pickup' --raw | audit2allow -M my-pickup'			>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-pickup.pp'							>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo ausearch -c 'sedispatch' --raw | audit2allow -M my-sedispatch'		>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-sedispatch.pp'						>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo ausearch -c 'iscsid' --raw | audit2allow -M my-iscsid'			>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-iscsid.pp'							>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo ausearch -c 'dhclient' --raw | audit2allow -M my-dhclient'			>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-dhclient.pp'							>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo ausearch -c 'ovs-vsctl' --raw | audit2allow -M my-ovsvsctl'			>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-ovsvsctl.pp'							>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo ausearch -c 'chpasswd' --raw | audit2allow -M my-chpasswd'			>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-chpasswd.pp'							>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo ausearch -c 'colord' --raw | audit2allow -M my-colord'			>> ./lxcentos/selinux/selinux-lxc.sh
echo 'sudo semodule -i my-colord.pp'							>> ./lxcentos/selinux/selinux-lxc.sh

echo ''
echo "=============================================="
echo "Created selinux-lxc.sh file.                  "
echo "=============================================="

clear

sleep 5

echo ''
echo "=============================================="
echo "Apply selected selinux adjustments for lxc... "
echo "=============================================="
echo ''

function GetFacter {
facter virtual
}
Facter=$(GetFacter)
if [ $Facter = 'physical' ]
then
	sudo setenforce 0
	echo ''
	sudo getenforce
	echo ''
	if [ -f /etc/sysconfig/selinux ]
	then
		echo ''
		echo "=============================================="
		echo "Set SELINUX to Permissive mode.               "
		echo "=============================================="
		echo ''
		sudo sed -i '/\([^T][^Y][^P][^E]\)\|\([^#]\)/ s/enforcing/permissive/' /etc/sysconfig/selinux
	fi
	sudo ausearch -c 'lxcattach' --raw | audit2allow -M my-lxcattach > /dev/null 2>&1
	sudo semodule -i my-lxcattach.pp > /dev/null 2>&1
	sudo ausearch -c 'dhclient' --raw | audit2allow -M my-dhclient > /dev/null 2>&1
	sudo semodule -i my-dhclient.pp > /dev/null 2>&1
	sudo ausearch -c 'passwd' --raw | audit2allow -M my-passwd > /dev/null 2>&1
	sudo semodule -i my-passwd.pp > /dev/null 2>&1
	sudo ausearch -c 'sedispatch' --raw | audit2allow -M my-sedispatch > /dev/null 2>&1
	sudo semodule -i my-sedispatch.pp > /dev/null 2>&1
	sudo ausearch -c 'systemd-sysctl' --raw | audit2allow -M my-systemdsysctl > /dev/null 2>&1
	sudo semodule -i my-systemdsysctl.pp > /dev/null 2>&1
	sudo ausearch -c 'ovs-vsctl' --raw | audit2allow -M my-ovsvsctl > /dev/null 2>&1
	sudo semodule -i my-ovsvsctl.pp > /dev/null 2>&1
	sudo ausearch -c 'sshd' --raw | audit2allow -M my-sshd > /dev/null 2>&1
	sudo semodule -i my-sshd.pp > /dev/null 2>&1
	sudo ausearch -c 'gdm-session-wor' --raw | audit2allow -M my-gdmsessionwor > /dev/null 2>&1
	sudo semodule -i my-gdmsessionwor.pp > /dev/null 2>&1
	sudo ausearch -c 'pickup' --raw | audit2allow -M my-pickup > /dev/null 2>&1
	sudo semodule -i my-pickup.pp > /dev/null 2>&1
	sudo ausearch -c 'sedispatch' --raw | audit2allow -M my-sedispatch > /dev/null 2>&1
	sudo semodule -i my-sedispatch.pp > /dev/null 2>&1
	sudo ausearch -c 'iscsid' --raw | audit2allow -M my-iscsid > /dev/null 2>&1
	sudo semodule -i my-iscsid.pp > /dev/null 2>&1
	sudo ausearch -c 'dhclient' --raw | audit2allow -M my-dhclient > /dev/null 2>&1
	sudo semodule -i my-dhclient.pp > /dev/null 2>&1
	sudo ausearch -c 'ovs-vsctl' --raw | audit2allow -M my-ovsvsctl > /dev/null 2>&1
	sudo semodule -i my-ovsvsctl.pp > /dev/null 2>&1
	sudo ausearch -c 'chpasswd' --raw | audit2allow -M my-chpasswd > /dev/null 2>&1
	sudo semodule -i my-chpasswd.pp > /dev/null 2>&1
	sudo ausearch -c 'colord' --raw | audit2allow -M my-colord > /dev/null 2>&1
	sudo semodule -i my-colord.pp > /dev/null 2>&1
	sudo ausearch -c 'ntpd' --raw | audit2allow -M my-ntpd > /dev/null 2>&1
	sudo semodule -i my-ntpd.pp > /dev/null 2>&1
else
	sudo setenforce 0
	echo ''
	sudo getenforce
	echo ''
	if [ -f /etc/sysconfig/selinux ]
	then
		echo ''
		echo "=============================================="
		echo "Set SELINUX to Permissive mode.               "
		echo "=============================================="
		echo ''
		sudo sed -i '/\([^T][^Y][^P][^E]\)\|\([^#]\)/ s/enforcing/permissive/' /etc/sysconfig/selinux
	fi
	sudo ausearch -c 'passwd' --raw | audit2allow -M my-passwd > /dev/null 2>&1
	sudo semodule -i my-passwd.pp > /dev/null 2>&1
	sudo ausearch -c 'chpasswd' --raw | audit2allow -M my-chpasswd > /dev/null 2>&1
	sudo semodule -i my-chpasswd.pp > /dev/null 2>&1
fi

echo ''
echo "=============================================="
echo "Set selinux to permissive & set rules.        "
echo "=============================================="

sleep 5

clear

echo ''
echo "=============================================="
echo "Create /etc/orabuntu-lxc-release file...          "
echo "=============================================="
echo ''

if [ ! -f /etc/orabuntu-lxc-release ]
then
	sudo touch /etc/orabuntu-lxc-release
	sudo sh -c "echo 'Orabuntu-LXC v4.0' > /etc/orabuntu-lxc-release"
fi
sudo ls -l /etc/orabuntu-lxc-release

echo ''
echo "=============================================="
echo "Create /etc/orabuntu-lxc-release file complete.   "
echo "=============================================="

sleep 5

clear

echo ''
echo "=============================================="
echo "Next step is to setup storage e.g. for a DB   "
echo "That step is optional and is done as follows: "
echo "tar -xvf scst-files.tar                       "
echo "cd scst-files                                 "
echo "cat README                                    "
echo "follow the instructions in the README         "
echo "Builds the SCST Linux SAN.                    "
echo "                                              "
echo "Note that deployment management links are     "
echo "in /home/ubuntu/Play-The-Uekulele   "
echo "where you can learn more about what files and "
echo "configurations are used for the Orabuntu-LXC  "
echo "project.                                      "
echo "=============================================="

sleep 5 

clear

echo ''
echo "=============================================="
echo " A reboot is recommended (but not required!)  "
echo "=============================================="

echo ''
echo "=============================================="
echo "                                              "
read -e -p "Reboot Now ? [Y/N]                      " -i "Y" Reboot
echo "                                              "
echo "=============================================="
echo ''

if [ $Reboot = 'y' ] || [ $Reboot = 'Y' ]
then
	sudo reboot
fi

sleep 5

clear
