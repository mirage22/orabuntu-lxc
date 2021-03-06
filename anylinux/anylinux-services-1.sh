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
#    v4.3 GLS 20161126 Additional enhancements for multi-distro (Redhat-based and Debian-based)
#    v5.0 GLS 20170924 Orabuntu-LXC Multi-Host

#    Usage:   anylinux-services-1.sh $major_version $minor_version $Domain1 $Domain2 $NameServer $OSMemRes
#    Example: anylinux-services-1.sh 7 2 yourdomain1.[com|net|us|info|...] yourdomain2.[com|net|us|info|...] yournameserver MemoryReservation(Kb)
#    Example: anylinux-services-1.sh 7 2 bostonlox.com realcrumpets.info nycnsa

#    Note that this software builds a conntainerized DNS DHCP solution for the Ubuntu Desktop environment.
#    The nameserver should NOT be the name of an EXISTING nameserver but an arbitrary name because this software is CREATING a new LXC-containerized nameserver.
#    The domain names can be arbitrary fictional names or they can be a domain that you actually own and operate.
#    There are two domains and two networks because the "seed" LXC containers are on a separate network from the production LXC containers.
#    If the domain is an actual domain, you will need to change the subnet though (a feature this software does not yet support - it's on the roadmap) to match your subnet manually.

MajorRelease=$1
PointRelease=$2
OracleRelease=$1$2
OracleVersion=$1.$2
Domain1=$3
Domain2=$4
NameServer=$5
OSMemRes=$6
NumCon=$7
MultiHost=$8
LxcOvsVersion=$9

function GetLxcVersion {
echo $LxcOvsVersion | cut -f1 -d':'
}
LxcVersion=$(GetLxcVersion)

function GetOvsVersion {
echo $LxcOvsVersion | cut -f2 -d':'
}
OvsVersion=$(GetOvsVersion)

function GetMultiHostVar1 {
	echo $MultiHost | cut -f1 -d':'
}
MultiHostVar1=$(GetMultiHostVar1)

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
elif [ $LinuxFlavor = 'Red' ]
then
        function GetRedHatVersion {
                sudo cat /etc/redhat-release | cut -f7 -d' ' | cut -f1 -d'.'
        }
        RedHatVersion=$(GetRedHatVersion)
        Release=$RedHatVersion
        LF=$LinuxFlavor'Hat'
        RL=$Release
elif [ $LinuxFlavor = 'Ubuntu' ]
then
    	function GetUbuntuVersion {
               	cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -f2 -d'='
       	}
       	UbuntuVersion=$(GetUbuntuVersion)
	LF=$LinuxFlavor
	RL=$UbuntuVersion
       	function GetUbuntuMajorVersion {
               	cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -f2 -d'=' | cut -f1 -d'.'
       	}
       	UbuntuMajorVersion=$(GetUbuntuMajorVersion)
fi

echo ''
echo "=============================================="
echo "Oracle container automation.                  "
echo "=============================================="
echo ''
echo 'Author:  Gilbert Standen                      '
echo 'Email :  gilbert@orabuntu-lxc.com             '
echo ''
echo 'Motto :  Any Oracle on Any Linux (sm)         '
echo ''
echo "=============================================="
echo "Oracle container automation.                  "
echo "=============================================="
echo ''

sleep 5

clear

echo ''
echo "==============================================" 
echo "Establish sudo privileges...                  "
echo "=============================================="
echo ''

sudo date

echo ''
echo "==============================================" 
echo "Privileges established.                       "
echo "=============================================="

sleep 5

clear

echo ''
echo "==============================================" 
echo "Verify networking up...                       "
echo "=============================================="
echo ''

ping -c 3 yum.oracle.com

function CheckNetworkUp {
ping -c 3 yum.oracle.com | grep packet | cut -f3 -d',' | sed 's/ //g'
}
NetworkUp=$(CheckNetworkUp)

while [ "$NetworkUp" !=  "0%packetloss" ] && [ "$n" -lt 5 ]
do
	NetworkUp=$(CheckNetworkUp)
	let n=$n+1
done

if [ "$NetworkUp" != '0%packetloss' ]
then
	echo ''
	echo "=============================================="
	echo "Networking is not up or is hiccuping badly:   "
	echo "archive.ubuntu.com ping test must succeed.    "
	echo "Exiting script...                             "
	echo "Address network issues/hiccups & rerun script."
	echo "=============================================="

	sleep 15

	exit
else
	echo ''
	echo "=============================================="
	echo "Network ping test verification complete.      "
	echo "=============================================="
	echo ''
fi

sleep 5 

clear

echo ''
echo "=============================================="
echo "Check Kernel Version of running kernel...     "
echo "=============================================="
echo ''

uname -a

# GLS 20151126 Added function to get kernel version of running kernel to support linux 4.x kernels in Ubuntu Wily Werewolf etc.
# GLS 20160924 SCST 3.1 does not require a custom kernel build for kernels >= 2.6.30 so now we check that kernel is >= 2.6.30.
# GLS 20160924 If the kernel version is lower than 2.6.30 and if you use the options SCST Linux SAN archive it will be necessary to compile a custom kernel.

function VersionKernelPassFail () {
    ./anylinux/vercomp | cut -f1 -d':'
}
KernelPassFail=$(VersionKernelPassFail)

if [ $KernelPassFail = 'Pass' ] # $KernelPassFail = 'Pass'
then
	echo ''
	echo "=============================================="
	echo "Kernel Version is greater than 2.6.30 - Pass  "
	echo "=============================================="
	echo ''

	sleep 5

	clear

	if [ $LinuxFlavor = 'CentOS' ] # $LinuxFlavor = 'CentOS'
	then
		function GetCentOSVersion {
		cat /etc/redhat-release | cut -f4 -d' ' | cut -f1 -d'.'
		}
		CentOSVersion=$(GetCentOSVersion)

		if [ $CentOSVersion -ge 7 ] # $CentOSVersion -ge 7
		then
 			echo ''
			echo "=============================================="
			echo "Script:  anylinux-services-1.sh               "
			echo "=============================================="

			sleep 5
			
			clear
			
			echo ''
			echo "=============================================="
			echo "Linux OS version check...                     "
			echo "=============================================="
			echo ''
  
			if [ -f /etc/oracle-release ] # 1
			then
				cat /etc/oracle-release
			else
				cat /etc/redhat-release
			fi #OK 1

			echo ''
			echo "=============================================="
			echo "Linux OS version displayed.                   "
			echo "=============================================="
			echo ''	
			echo "=============================================="
			echo "OS Versions Compabtibility Notice Begin       "
			echo "=============================================="
			echo ''
			echo "=============================================="
			echo "              !!! NOTICE !!!                  "
			echo "                                              "
			echo "All OS version compabibility tests shown below"
			echo "done on NEW FRESH INSTALL physical or VM hosts"
			echo "AFTER ALL UPDATES applied.                    "
			echo "=============================================="
			echo ''
			echo "=============================================="
			echo "DISTRO               REL   KERN TYPE  EDITION "
			echo "Tested: Oracle Linux 7.x   UEK4 (VM)  Server  "
			echo "Tested: Oracle Linux 7.x   UEK4 (PH)  Server  "
			echo "Tested: Oracle Linux 7.x   RHEL (VM)  Server  "
			echo "Tested: Oracle Linux 7.x   RHEL (PH)  Server  "
			echo "Tested: Ubuntu Linux 16.x  ALL  (VM)  Desktop "
			echo "Tested: Ubuntu Linux 16.x  ALL  (VM)  Server  "
			echo "Tested: Ubuntu Linux 16.x  ALL  (PH)  Desktop "
			echo "Tested: Ubuntu Linux 16.x  ALL  (PH)  Server  "
			echo "Tested: Ubuntu Linux 17.x  ALL  (VM)  Desktop "
			echo "Tested: Ubuntu Linux 17.x  ALL  (VM)  Server  "
			echo "Tested: Ubuntu Linux 17.x  ALL  (PH)  Desktop "
			echo "Tested: Ubuntu Linux 17.x  ALL  (PH)  Server  "
			echo "                                              "
			echo "Legend:                                       "
			echo "                                              "
			echo "	VM=Virtual  Host                            "
			echo "	PH=Physical Host                            "
			echo "	REL=Release                                 "
			echo "	KERN=Kernel Version                         "
			echo "=============================================="
			echo ''
			echo "=============================================="
			echo "OS Versions Compatibility Notice End          "
			echo "=============================================="
		
			echo ''	
			read -n 1 -s -p "Press any key to continue"

			clear

			if [ ! -f /etc/orabuntu-lxc-terms ] # 2
			then
				echo ''
				echo "=========================================================================================="
				echo "Please answer 'Y' below to signify that you understand that the above fresh install       "
				echo "OS/physical and OS/VM combination(s) are the only combinations that have been tested with "
				echo "this software.                                                                            "
				echo "                                                                                          "
				echo "By answering 'Y' you also understand that while every effort has been made to certify this"
				echo "software on the OS/VM and OS/physical combos above, the above-listed combos do not        "
				echo "constitute a guarantee of results as stated in the GPL 3.0 license YMMV.                  "
				echo "                                                                                          "
				echo "It is recommended to first create a fresh VM of one of the supported versions listed above"
				echo "and test out this software on the VM before doing an install on a physical host.  This is "
				echo "so that you can get experience with this software first on a VM.  The installation of this"
				echo "software takes about 15-20  minutes so such a VM test is fairly low-cost in terms of time "
				echo "and effort on your part (of course building the VM takes a little while too).             "
				echo "                                                                                          "
				echo "Note that this software was designed to be as minimally invasive as possible and so every "
				echo "effort has been made to minimize the risk of loss of service(s) due to installing this    "
				echo "software.  However not all outcomes on all systems can be anticipated if installing on a  "
				echo "system that has been running for awhile and has been customized or if installing on an OS "
				echo "not listed above. The list of files touched by Orabuntu-LXC is in ubuntu-host.tar archive."
			        echo "                                                                                          "	
				echo "You can extract that file using this command (you may need to use sudo privilege):        "
				echo "tar -vP --extract --file=ubuntu-host.tar /etc/orabuntu-lxc-scripts/ubuntu-host-backup.sh  "
				echo "                                                                                          "
				echo "You can choose to answer 'Y' below also if you wish to try this software on an OS/VM or   "
				echo "OS/physical combination that is not listed above understanding that there may be results  "
				echo "that are unexpected in that case. If you have a Linux OS that you would like to add to the"
			        echo "list of tested systems above, you are free to fork this software under the GNU3 license   "
				echo "which governs this open source software, or you can send an email to:                     "
				echo "                                                                                          " 
				echo "gilbert@orabuntu-lxc.com                                                                  "
				echo "                                                                                          "
				echo "and request that support for that OS be developed into this software and also supported.  "
				echo "=========================================================================================="	
				echo "                                                                                          "
				echo "=========================================================================================="	
				echo "                                                                                          " 
				read -e -p "Accept installation terms? [Y/N]     " -i "Y" InstallationTerms
				echo "                                                                                          "
				echo "=========================================================================================="
				echo ''
			else
				InstallationTerms=Y
			fi #OK 2

			if [ $InstallationTerms = 'y' ] || [ $InstallationTerms = 'Y' ] && [ ! -f /etc/orabuntu-lxc-terms ] # 3
			then
				clear

				echo ''
				echo "=============================================="	
				echo "Install terms accepted.                       "
				echo "=============================================="

				sudo su -c "echo 'Orabuntu-LXC terms accepted' > /etc/orabuntu-lxc-terms"

				sleep 5

				clear

			elif [ -f /etc/orabuntu-lxc-terms ]
			then
				clear

				echo ''
				echo "=============================================="	
				echo "Install Terms previously accepted.            "
				echo "=============================================="
				echo ''
				sudo ls -l /etc/orabuntu-lxc-terms
				echo ''
				sudo cat /etc/orabuntu-lxc-terms
				echo ''
				echo "=============================================="	
				echo "Install terms file information displayed.     "
				echo "=============================================="

				sleep 5

				clear
			else
				echo ''
				echo "=============================================="	
				echo "Terms Not Accepted. Terminating Installation. "
				echo "=============================================="	
				exit
			fi #OK 3
			
			function CheckUser {
			id | cut -f1 -d' ' | cut -f2 -d'(' | cut -f1 -d')'
			}
			User=$(CheckUser)

			if [ $User = 'root' ] # 4
			then
				echo ''
				echo "=============================================="
				echo "Check if install user is root...              "
				echo "=============================================="
				echo ''
				echo "For $LF Linux $RL Linux user must be ubuntu.  "
				echo "Connect as ubuntu and run the scripts again.  "
				echo ''
				echo "=============================================="
				echo "Install user check completed.                 "
				echo "=============================================="
				echo ''
				exit
			fi #OK 4

			echo ''
			echo "=============================================="
			echo "Check if host is physical or virtual...       "
			echo "=============================================="
			echo ''
	
			sleep 5
	
			clear
	
			echo ''
			echo "=============================================="
			echo "Facter package required for phys/VM check...  "
			echo "=============================================="
			echo ''
	
			sleep 5
	
			clear
	
			function CheckFacterInstalled {
				sudo which facter > /dev/null 2>&1; echo $?
			}
			FacterInstalled=$(CheckFacterInstalled)

			if [ $FacterInstalled -ne 0 ] # 5
			then
       			 	echo ''
       			 	echo "=============================================="
       			 	echo "Install package prerequisites for facter...   "
       			 	echo "=============================================="
       			 	echo ''

				sudo yum clean all
       			 	sudo yum -y install which ruby curl tar
        	
				echo ''
       			 	echo "=============================================="
       			 	echo "Facter package prerequisites installed.       "
       			 	echo "=============================================="

				sleep 5

				clear

       			 	echo ''
       			 	echo "=============================================="
       			 	echo "Build and install Facter from source...       "
       			 	echo "=============================================="
       			 	echo ''

				sleep 5

				mkdir -p ./lxcentos/facter
				cd ./lxcentos/facter
				curl -s http://downloads.puppetlabs.com/facter/facter-2.4.4.tar.gz | sudo tar xz; sudo ruby facter*/install.rb

				echo ''
       			 	echo "=============================================="
       			 	echo "Build and install Facter completed.           "
       			 	echo "=============================================="

			else
       			 	echo ''
       			 	echo "=============================================="
       			 	echo "Facter already installed.                     "
       			 	echo "=============================================="
       			 	echo ''
			fi #OK 5

			function GetFacter {
			facter virtual
			}
			Facter=$(GetFacter)
			
			sleep 5

			clear

			if [ $Facter != 'physical' ] # 6
			then
 				echo ''
				echo "=============================================="
				echo "Orabuntu-LXC $LF Linux $RL on $Facter.        "
				echo "=============================================="
				echo ''

				sleep 5

				clear

				if [ -f /etc/orabuntu-lxc-terms ] && [ -f /etc/orabuntu-lxc-release ] # 7
				then
					echo ''
					echo "=============================================="
					echo "                                              "
					echo "If you already have an Orabuntu-LXC install   "
					echo "on this host and want to add more containers  "
					echo "then answer 'Y' to this.                      "
					echo "                                              "
					echo "If you are doing a complete Orabuntu-LXC      "
					echo "reinstall then answer 'N' to this.            "
					echo "                                              "
					echo "=============================================="
					echo "                                              " 
				read -e -p   "Adding Orabuntu-LXC containers? [Y/N]         " -i "Y" CloningAdditional
					echo "                                              "
					echo "=============================================="
					
					sleep 5
	
					clear

					if [ $CloningAdditional = 'n' ] || [ $CloningAdditional = 'N' ] # 8
					then
 						./lxcentos/lxcentos-services-1.sh $MajorRelease $PointRelease $Domain1 $Domain2 $NameServer $OSMemRes $MultiHost
 						./lxcentos/lxcentos-services-2.sh $MajorRelease $PointRelease $Domain1 $Domain2 $MultiHost
 						./lxcentos/lxcentos-services-3.sh $MajorRelease $PointRelease 
						./lxcentos/lxcentos-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost 
						./lxcentos/lxcentos-services-5.sh $MajorRelease $PointRelease 
					fi # OK 8

					if [ $CloningAdditional = 'y' ] || [ $CloningAdditional = 'Y' ] || [ $MultiHostVar1 = 'addclones' ] # 9
					then
						./lxcentos/lxcentos-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost
						./lxcentos/lxcentos-services-5.sh $MajorRelease $PointRelease
					fi # OK 9
				fi # OK 7

				if [ ! -f /etc/orabuntu-lxc-release ] # 10
				then
					./lxcentos/lxcentos-services-1.sh $MajorRelease $PointRelease $Domain1 $Domain2 $NameServer $OSMemRes $MultiHost
					./lxcentos/lxcentos-services-2.sh $MajorRelease $PointRelease $Domain1 $Domain $MultiHost
					./lxcentos/lxcentos-services-3.sh $MajorRelease $PointRelease 
					./lxcentos/lxcentos-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost 
					./lxcentos/lxcentos-services-5.sh $MajorRelease $PointRelease 
				fi # OK 10

 				echo ''
				echo "=============================================="
				echo "Orabuntu-LXC $LF Linux $RL complete.          "
				echo "=============================================="

				sleep 5
	
 			else # OK 6

				echo ''
				echo "=============================================="
				echo "Orabuntu-LXC $LF Linux $RL on $Facter         "
				echo "=============================================="
				echo ''
	
				sleep 5

				clear

				if [ -f /etc/orabuntu-lxc-terms ] && [ -f /etc/orabuntu-lxc-release ] # 11
				then
					echo ''
					echo "=============================================="
					echo "                                              "
					echo "If you already have an Orabuntu-LXC install  "
					echo "on this host and want to add more containers  "
					echo "then answer 'Y' to this.                      "
					echo "                                              "
					echo "If you are doing a complete Orabuntu-LXC      "
					echo "reinstall then answer 'N' to this.            "
					echo "                                              "
					echo "=============================================="
					echo "                                              " 
				read -e -p   "Adding Orabuntu-LXC containers? [Y/N]  " -i "Y" CloningAdditional
					echo "                                              "
					echo "=============================================="
					echo ''
	
					sleep 5

					clear

					if [ $CloningAdditional = 'n' ] || [ $CloningAdditional = 'N' ] # 12
					then
 						./lxcentos/lxcentos-services-1.sh $MajorRelease $PointRelease $Domain1 $Domain2 $NameServer $OSMemRes $MultiHost
 						./lxcentos/lxcentos-services-2.sh $MajorRelease $PointRelease $Domain1 $Domain2 $MultiHost
 						./lxcentos/lxcentos-services-3.sh $MajorRelease $PointRelease 
						./lxcentos/lxcentos-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost 
						./lxcentos/lxcentos-services-5.sh $MajorRelease $PointRelease 
					fi # OK 12

					if [ $CloningAdditional = 'y' ] || [ $CloningAdditional = 'Y' ] || [ $MultiHostVar1 = 'addclones' ] # 13
					then
						./lxcentos/lxcentos-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost
						./lxcentos/lxcentos-services-5.sh $MajorRelease $PointRelease
					fi # OK 13
				fi # OK 10

				if [ ! -f /etc/orabuntu-lxc-release ] # 14
				then
					./lxcentos/lxcentos-services-1.sh $MajorRelease $PointRelease $Domain1 $Domain2 $NameServer $OSMemRes $MultiHost
					./lxcentos/lxcentos-services-2.sh $MajorRelease $PointRelease $Domain1 $Domain $MultiHost
					./lxcentos/lxcentos-services-3.sh $MajorRelease $PointRelease 
					./lxcentos/lxcentos-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost 
					./lxcentos/lxcentos-services-5.sh $MajorRelease $PointRelease 
				fi # OK 14

				sleep 5

				clear
			
				echo ''
				echo "=============================================="
				echo "Orabuntu-LXC for $LF Linux $RL complete.      "
				echo "=============================================="

			fi # OK 6

 		fi # $CentOSVersion -ge 7

	fi # OK $LinuxFlavor = 'CentOS'

	if [ $LinuxFlavor = 'RedHat' ] || [ $LinuxFlavor = 'Oracle' ] # $LinuxFlavor = 'Red'
	then
		function GetRedHatVersion {
		cat /etc/redhat-release  | cut -f7 -d' ' | cut -f1 -d'.'
		}
		RedHatVersion=$(GetRedHatVersion)

		if [ $RedHatVersion -ge 6 ] # [ $RedHatVersion -ge 6 ]
		then
 			echo ''
			echo "=============================================="
			echo "Script:  anylinux-services-1.sh               "
			echo "=============================================="

			sleep 5
			
			clear
			
			echo ''
			echo "=============================================="
			echo "Linux OS version check...                     "
			echo "=============================================="
			echo ''
  
			if [ -f /etc/oracle-release ] # 1
			then
				cat /etc/oracle-release
			else
				cat /etc/redhat-release
			fi # OK 1

			echo ''
			echo "=============================================="
			echo "Linux OS version displayed.                   "
			echo "=============================================="
			echo ''	
			echo "=============================================="
			echo "OS Versions Compabtibility Notice Begin       "
			echo "=============================================="
			echo ''
			echo "=============================================="
			echo "              !!! NOTICE !!!                  "
			echo "                                              "
			echo "All OS version compabibility tests shown below"
			echo "done on NEW FRESH INSTALL physical or VM hosts"
			echo "AFTER ALL UPDATES applied.                    "
			echo "=============================================="
			echo ''
			echo "=============================================="
			echo "DISTRO               REL   KERN TYPE  EDITION "
			echo "Tested: Oracle Linux 7.x   UEK4 (VM)  Server  "
			echo "Tested: Oracle Linux 7.x   UEK4 (PH)  Server  "
			echo "Tested: Oracle Linux 7.x   RHEL (VM)  Server  "
			echo "Tested: Oracle Linux 7.x   RHEL (PH)  Server  "
			echo "Tested: Ubuntu Linux 16.x  ALL  (VM)  Desktop "
			echo "Tested: Ubuntu Linux 16.x  ALL  (VM)  Server  "
			echo "Tested: Ubuntu Linux 16.x  ALL  (PH)  Desktop "
			echo "Tested: Ubuntu Linux 16.x  ALL  (PH)  Server  "
			echo "Tested: Ubuntu Linux 17.x  ALL  (VM)  Desktop "
			echo "Tested: Ubuntu Linux 17.x  ALL  (VM)  Server  "
			echo "Tested: Ubuntu Linux 17.x  ALL  (PH)  Desktop "
			echo "Tested: Ubuntu Linux 17.x  ALL  (PH)  Server  "
			echo "                                              "
			echo "Legend:                                       "
			echo "                                              "
			echo "	VM=Virtual  Host                            "
			echo "	PH=Physical Host                            "
			echo "	REL=Release                                 "
			echo "	KERN=Kernel Version                         "
			echo "=============================================="
			echo ''
			echo "=============================================="
			echo "OS Versions Compatibility Notice End          "
			echo "=============================================="
		
			echo ''	
			read -n 1 -s -p "Press any key to continue"

			clear

			if [ ! -f /etc/orabuntu-lxc-terms ] # 2
			then
				echo ''
				echo "=========================================================================================="
				echo "Please answer 'Y' below to signify that you understand that the above fresh install       "
				echo "OS/physical and OS/VM combination(s) are the only combinations that have been tested with "
				echo "this software.                                                                            "
				echo "                                                                                          "
				echo "By answering 'Y' you also understand that while every effort has been made to certify this"
				echo "software on the OS/VM and OS/physical combos above, the above-listed combos do not        "
				echo "constitute a guarantee of results as stated in the GPL 3.0 license YMMV.                  "
				echo "                                                                                          "
				echo "It is recommended to first create a fresh VM of one of the supported versions listed above"
				echo "and test out this software on the VM before doing an install on a physical host.  This is "
				echo "so that you can get experience with this software first on a VM.  The installation of this"
				echo "software takes about 15-20  minutes so such a VM test is fairly low-cost in terms of time "
				echo "and effort on your part (of course building the VM takes a little while too).             "
				echo "                                                                                          "
				echo "Note that this software was designed to be as minimally invasive as possible and so every "
				echo "effort has been made to minimize the risk of loss of service(s) due to installing this    "
				echo "software.  However not all outcomes on all systems can be anticipated if installing on a  "
				echo "system that has been running for awhile and has been customized or if installing on an OS "
				echo "not listed above. The list of files touched by Orabuntu-LXC is in ubuntu-host.tar archive."
			        echo "                                                                                          "	
				echo "You can extract that file using this command (you may need to use sudo privilege):        "
				echo "tar -vP --extract --file=ubuntu-host.tar /etc/orabuntu-lxc-scripts/ubuntu-host-backup.sh  "
				echo "                                                                                          "
				echo "You can choose to answer 'Y' below also if you wish to try this software on an OS/VM or   "
				echo "OS/physical combination that is not listed above understanding that there may be results  "
				echo "that are unexpected in that case. If you have a Linux OS that you would like to add to the"
			        echo "list of tested systems above, you are free to fork this software under the GNU3 license   "
				echo "which governs this open source software, or you can send an email to:                     "
				echo "                                                                                          " 
				echo "gilbert@orabuntu-lxc.com                                                                  "
				echo "                                                                                          "
				echo "and request that support for that OS be developed into this software and also supported.  "
				echo "=========================================================================================="	
				echo "                                                                                          "
				echo "=========================================================================================="	
				echo "                                                                                          " 
				read -e -p "Accept installation terms? [Y/N]     " -i "Y" InstallationTerms
				echo "                                                                                          "
				echo "=========================================================================================="
				echo ''
			else
				InstallationTerms=Y
			fi # OK 2

			if [ $InstallationTerms = 'y' ] || [ $InstallationTerms = 'Y' ] && [ ! -f /etc/orabuntu-lxc-terms ] # 3
			then
				clear

				echo ''
				echo "=============================================="	
				echo "Install terms accepted.                       "
				echo "=============================================="

				sudo su -c "echo 'Orabuntu-LXC terms accepted' > /etc/orabuntu-lxc-terms"

				sleep 5

				clear

			elif [ -f /etc/orabuntu-lxc-terms ]
			then
				clear

				echo ''
				echo "=============================================="	
				echo "Install Terms previously accepted.            "
				echo "=============================================="
				echo ''
				sudo ls -l /etc/orabuntu-lxc-terms
				echo ''
				sudo cat /etc/orabuntu-lxc-terms
				echo ''
				echo "=============================================="	
				echo "Install terms file information displayed.     "
				echo "=============================================="

				sleep 5

				clear
			else
				echo ''
				echo "=============================================="	
				echo "Terms Not Accepted. Terminating Installation. "
				echo "=============================================="	
				exit
			fi # OK 3
		
			function CheckUser {
				id | cut -f1 -d' ' | cut -f2 -d'(' | cut -f1 -d')'
			}
			User=$(CheckUser)

			if [ $User = 'root' ] # 4
			then
				echo ''
				echo "=============================================="
				echo "Check if install user is root...              "
				echo "=============================================="
				echo ''
				echo "For $LF Linux $RL user must be ubuntu.        "
				echo "Connect as ubuntu and run the scripts again.  "
				echo ''
				echo "=============================================="
				echo "Install user check completed.                 "
				echo "=============================================="
				echo ''
				exit
			fi # OK 4

			echo ''
			echo "=============================================="
			echo "Check if host is physical or virtual...       "
			echo "=============================================="
			echo ''

			sleep 5

			clear

			echo ''
			echo "=============================================="
			echo "Facter package required for phys/VM check...  "
			echo "=============================================="
			echo ''

			sleep 5

			clear

			function CheckFacterInstalled {
				sudo which facter > /dev/null 2>&1; echo $?
			}
			FacterInstalled=$(CheckFacterInstalled)

			if [ $FacterInstalled -ne 0 ] # 5
			then
       			 	echo ''
       			 	echo "=============================================="
       			 	echo "Install package prerequisites for facter...   "
       			 	echo "=============================================="
       			 	echo ''
	
       			 	sudo yum -y install which ruby curl tar
       	 	
				echo ''
       			 	echo "=============================================="
       			 	echo "Facter package prerequisites installed.       "
       		 		echo "=============================================="
	
				sleep 5

				clear

       			 	echo ''
       			 	echo "=============================================="
       			 	echo "Build and install Facter from source...       "
       			 	echo "=============================================="
       			 	echo ''

				sleep 5

				mkdir -p ./uekulele/facter
				cd ./uekulele/facter
				curl -s http://downloads.puppetlabs.com/facter/facter-2.4.4.tar.gz | sudo tar xz; sudo ruby facter*/install.rb

				echo ''
       			 	echo "=============================================="
       			 	echo "Build and install Facter completed.           "
       			 	echo "=============================================="

			else
       			 	echo ''
       			 	echo "=============================================="
       			 	echo "Facter already installed.                     "
       			 	echo "=============================================="
       			 	echo ''
	
			fi # OK 5

			function GetFacter {
				facter virtual
			}
			Facter=$(GetFacter)
			
			sleep 5

			clear

			if [ $Facter != 'physical' ] # 6
			then
 				echo ''
				echo "=============================================="
				echo "Orabuntu-LXC $LF Linux $RL on $Facter.        "
				echo "=============================================="
				echo ''

				sleep 5

				clear

				if [ -f /etc/orabuntu-lxc-terms ] && [ -f /etc/orabuntu-lxc-release ] # 7
				then
					echo ''
					echo "=============================================="
					echo "                                              "
					echo "If you already have an Orabuntu-LXC install   "
					echo "on this host and just want to add more        "
					echo "containers then answer 'Y' to this.           "
					echo "                                              "
					echo "If you are doing a complete Orabuntu-LXC      "
					echo "reinstall then answer 'N' to this.            "
					echo "                                              "
					echo "=============================================="
					echo "                                              " 
				read -e -p   "Adding Orabuntu-LXC containers? [Y/N]         " -i "Y" CloningAdditional
					echo "                                              "
					echo "=============================================="
					
					sleep 5
	
					clear

					if [ $CloningAdditional = 'n' ] || [ $CloningAdditional = 'N' ] # 8
					then
 						./uekulele/uekulele-services-1.sh $MajorRelease $PointRelease $Domain1 $Domain2 $NameServer $OSMemRes $MultiHost $LxcOvsVersion
 						./uekulele/uekulele-services-2.sh $MajorRelease $PointRelease $Domain1 $Domain2 $MultiHost
 						./uekulele/uekulele-services-3.sh $MajorRelease $PointRelease $Domain2 $MultiHost
						./uekulele/uekulele-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost 
						./uekulele/uekulele-services-5.sh $MajorRelease $PointRelease 
					fi # OK 8

					if [ $CloningAdditional = 'y' ] || [ $CloningAdditional = 'Y' ] || [ $MultiHostVar1 = 'addclones' ] # 9
					then
						./uekulele/uekulele-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost
						./uekulele/uekulele-services-5.sh $MajorRelease $PointRelease
					fi # OK 9
				fi # OK 7

				if [ ! -f /etc/orabuntu-lxc-release ] # 10
				then
					./uekulele/uekulele-services-1.sh $MajorRelease $PointRelease $Domain1 $Domain2 $NameServer $OSMemRes $MultiHost $LxcOvsVersion
					./uekulele/uekulele-services-2.sh $MajorRelease $PointRelease $Domain1 $Domain2 $MultiHost
					./uekulele/uekulele-services-3.sh $MajorRelease $PointRelease $Domain2 $MultiHost
					./uekulele/uekulele-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost 
					./uekulele/uekulele-services-5.sh $MajorRelease $PointRelease 
				fi # OK 10

 				echo ''
				echo "=============================================="
				echo "Orabuntu-LXC for $LF Linux $RL complete.      "
				echo "=============================================="
	
				sleep 5

 			else # OK 6

				echo ''
				echo "=============================================="
				echo "Orabuntu-LXC $LF Linux $RL on $Facter.        " 
				echo "=============================================="
				echo ''

				sleep 5

				clear

				if [ -f /etc/orabuntu-lxc-terms ] && [ -f /etc/orabuntu-lxc-release ] # 11
				then
					echo ''
					echo "=============================================="
					echo "                                              "
					echo "If you already have an Orabuntu-LXC install   "
					echo "on this host and just want to add more        "
					echo "containers then answer 'Y' to this.           "
					echo "                                              "
					echo "If you are doing a complete Orabuntu-LXC      "
					echo "reinstall then answer 'N' to this.            "
					echo "                                              "
					echo "=============================================="
					echo "                                              " 
				read -e -p   "Adding Orabuntu-LXC containers? [Y/N]  " -i "Y" CloningAdditional
					echo "                                              "
					echo "=============================================="
					echo ''

					sleep 5

					clear

					if [ $CloningAdditional = 'n' ] || [ $CloningAdditional = 'N' ] # 12
					then
 						./uekulele/uekulele-services-1.sh $MajorRelease $PointRelease $Domain1 $Domain2 $NameServer $OSMemRes $MultiHost $LxcOvsVersion
 						./uekulele/uekulele-services-2.sh $MajorRelease $PointRelease $Domain1 $Domain2 $MultiHost 
 						./uekulele/uekulele-services-3.sh $MajorRelease $PointRelease $Domain2 $MultiHost
						./uekulele/uekulele-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost 
						./uekulele/uekulele-services-5.sh $MajorRelease $PointRelease 
					fi # OK 12

					if [ $CloningAdditional = 'y' ] || [ $CloningAdditional = 'Y' ] || [ $MultiHostVar1 = 'addclones' ] # 13
					then
						./uekulele/uekulele-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost
						./uekulele/uekulele-services-5.sh $MajorRelease $PointRelease
					fi # OK 13
				fi # OK 11
		
				if [ ! -f /etc/orabuntu-lxc-release ] # 14
				then
					./uekulele/uekulele-services-1.sh $MajorRelease $PointRelease $Domain1 $Domain2 $NameServer $OSMemRes $MultiHost $LxcOvsVersion
					./uekulele/uekulele-services-2.sh $MajorRelease $PointRelease $Domain1 $Domain2 $MultiHost 
					./uekulele/uekulele-services-3.sh $MajorRelease $PointRelease $Domain2 $MultiHost
					./uekulele/uekulele-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost 
					./uekulele/uekulele-services-5.sh $MajorRelease $PointRelease 
				fi # OK 14

				sleep 5

				clear
			
				echo ''
				echo "=============================================="
				echo "Orabuntu-LXC for $LF Linux $RL complete.      "
				echo "=============================================="

			fi # OK 6

 		fi # [ $RedHatVersion -ge 6 ]

	fi # $LinuxFlavor = 'Red'

	if [ $LinuxFlavor = 'Ubuntu' ] # $LinuxFlavor = 'Ubuntu'
	then
		function GetUbuntuVersion {
		cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -f2 -d'='
		}
		UbuntuVersion=$(GetUbuntuVersion)

		function GetUbuntuMajorVersion {
			cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -f2 -d'=' | cut -f1 -d'.'
		}
		UbuntuMajorVersion=$(GetUbuntuMajorVersion)

		if [ $UbuntuMajorVersion -ge 15 ] # $UbuntuMajorVersion -ge 15
		then
 			echo ''
			echo "=============================================="
			echo "Script:  anylinux-services-1.sh               "
			echo "=============================================="

			sleep 5

			clear

			echo ''
			echo "=============================================="
			echo "Ubuntu Release Version Check....              "
			echo "=============================================="
			echo ''

			sudo cat /etc/lsb-release # 1 OK 1

			echo ''
			echo "=============================================="
			echo "Linux OS version displayed.                   "
			echo "=============================================="
			echo ''	
			echo "=============================================="
			echo "OS Versions Compabtibility Notice Begin       "
			echo "=============================================="
			echo ''
			echo "=============================================="
			echo "              !!! NOTICE !!!                  "
			echo "                                              "
			echo "All OS version compabibility tests shown below"
			echo "done on NEW FRESH INSTALL physical or VM hosts"
			echo "AFTER ALL UPDATES applied.                    "
			echo "=============================================="
			echo ''
			echo "=============================================="
			echo "DISTRO               REL   KERN TYPE  EDITION "
			echo "Tested: Oracle Linux 7.x   UEK4 (VM)  Server  "
			echo "Tested: Oracle Linux 7.x   UEK4 (PH)  Server  "
			echo "Tested: Oracle Linux 7.x   RHEL (VM)  Server  "
			echo "Tested: Oracle Linux 7.x   RHEL (PH)  Server  "
			echo "Tested: Ubuntu Linux 16.x  ALL  (VM)  Desktop "
			echo "Tested: Ubuntu Linux 16.x  ALL  (VM)  Server  "
			echo "Tested: Ubuntu Linux 16.x  ALL  (PH)  Desktop "
			echo "Tested: Ubuntu Linux 16.x  ALL  (PH)  Server  "
			echo "Tested: Ubuntu Linux 17.x  ALL  (VM)  Desktop "
			echo "Tested: Ubuntu Linux 17.x  ALL  (VM)  Server  "
			echo "Tested: Ubuntu Linux 17.x  ALL  (PH)  Desktop "
			echo "Tested: Ubuntu Linux 17.x  ALL  (PH)  Server  "
			echo "                                              "
			echo "Legend:                                       "
			echo "                                              "
			echo "	VM=Virtual  Host                            "
			echo "	PH=Physical Host                            "
			echo "	REL=Release                                 "
			echo "	KERN=Kernel Version                         "
			echo "=============================================="
			echo ''
			echo "=============================================="
			echo "OS Versions Compatibility Notice End          "
			echo "=============================================="
		
			echo ''	
			read -n 1 -s -p "Press any key to continue"

			clear

			if [ ! -f /etc/orabuntu-lxc-terms ] # 2
			then
				echo ''
				echo "=========================================================================================="
				echo "Please answer 'Y' below to signify that you understand that the above fresh install       "
				echo "OS/physical and OS/VM combination(s) are the only combinations that have been tested with "
				echo "this software.                                                                            "
				echo "                                                                                          "
				echo "By answering 'Y' you also understand that while every effort has been made to certify this"
				echo "software on the OS/VM and OS/physical combos above, the above-listed combos do not        "
				echo "constitute a guarantee of results as stated in the GPL 3.0 license YMMV.                  "
				echo "                                                                                          "
				echo "It is recommended to first create a fresh VM of one of the supported versions listed above"
				echo "and test out this software on the VM before doing an install on a physical host.  This is "
				echo "so that you can get experience with this software first on a VM.  The installation of this"
				echo "software takes about 15-20  minutes so such a VM test is fairly low-cost in terms of time "
				echo "and effort on your part (of course building the VM takes a little while too).             "
				echo "                                                                                          "
				echo "Note that this software was designed to be as minimally invasive as possible and so every "
				echo "effort has been made to minimize the risk of loss of service(s) due to installing this    "
				echo "software.  However not all outcomes on all systems can be anticipated if installing on a  "
				echo "system that has been running for awhile and has been customized or if installing on an OS "
				echo "not listed above. The list of files touched by Orabuntu-LXC is in ubuntu-host.tar archive."
			        echo "                                                                                          "	
				echo "You can extract that file using this command (you may need to use sudo privilege):        "
				echo "tar -vP --extract --file=ubuntu-host.tar /etc/orabuntu-lxc-scripts/ubuntu-host-backup.sh  "
				echo "                                                                                          "
				echo "You can choose to answer 'Y' below also if you wish to try this software on an OS/VM or   "
				echo "OS/physical combination that is not listed above understanding that there may be results  "
				echo "that are unexpected in that case. If you have a Linux OS that you would like to add to the"
			        echo "list of tested systems above, you are free to fork this software under the GNU3 license   "
				echo "which governs this open source software, or you can send an email to:                     "
				echo "                                                                                          " 
				echo "gilbert@orabuntu-lxc.com                                                                  "
				echo "                                                                                          "
				echo "and request that support for that OS be developed into this software and also supported.  "
				echo "=========================================================================================="	
				echo "                                                                                          "
				echo "=========================================================================================="	
				echo "                                                                                          " 
				read -e -p "Accept installation terms? [Y/N]     " -i "Y" InstallationTerms
				echo "                                                                                          "
				echo "=========================================================================================="
				echo ''
			else
				InstallationTerms=Y
			fi # OK 2

			if [ $InstallationTerms = 'y' ] || [ $InstallationTerms = 'Y' ] && [ ! -f /etc/orabuntu-lxc-terms ] # 3
			then
				clear

				echo ''
				echo "=============================================="	
				echo "Install terms accepted.                       "
				echo "=============================================="
	
				sudo su -c "echo 'Orabuntu-LXC terms accepted' > /etc/orabuntu-lxc-terms"

				sleep 5

				clear

			elif [ -f /etc/orabuntu-lxc-terms ]
			then
				clear

				echo ''
				echo "=============================================="	
				echo "Install terms previously accepted.            "
				echo "=============================================="
				echo ''
				sudo ls -l /etc/orabuntu-lxc-terms
				echo ''
				sudo cat /etc/orabuntu-lxc-terms
				echo ''
				echo "=============================================="	
				echo "Install terms file information displayed.     "
				echo "=============================================="

				sleep 5

				clear
			else
				echo ''
				echo "=============================================="	
				echo "Terms Not Accepted. Terminating Installation. "
				echo "=============================================="	
				exit
			fi # OK 3

			function CheckUser {
				id | cut -f1 -d' ' | cut -f2 -d'(' | cut -f1 -d')'
			}
			User=$(CheckUser)

			if [ $User = 'root' ] # 4
			then
				echo ''
				echo "=============================================="
				echo "Check if install user is root...              "
				echo "=============================================="
				echo ''
				echo "For $LF Linux $RL user CANNOT be root.        "
				echo "Connect as the linux ubuntu user and rerun    "
				echo "installer.                                    "
				echo ''
				echo "=============================================="
				echo "Install user check completed.                 "
				echo "=============================================="
				echo ''
				exit

			fi # OK 4

			echo ''
			echo "=============================================="
			echo "Check if host is physical or virtual...       "
			echo "=============================================="
			echo ''

			sleep 5

			clear

			echo ''
			echo "=============================================="
			echo "Facter package required for phys/VM check...  "
			echo "=============================================="
			echo ''

			sleep 5

			clear

			function CheckFacterInstalled {
				sudo which facter > /dev/null 2>&1; echo $?
			}
			FacterInstalled=$(CheckFacterInstalled)

			if [ $FacterInstalled -ne 0 ] # 5
			then
       				echo ''
       				echo "=============================================="
       				echo "Install facter package...                     "
       				echo "=============================================="
       				echo ''
       	 	
				sudo apt-get -y install facter

				echo ''
       			 	echo "=============================================="
       			 	echo "Done:  Install facter package.                "
       			 	echo "=============================================="
				
				sleep 5

				clear
			else
       			 	echo ''
       			 	echo "=============================================="
       			 	echo "Facter already installed.                     "
       			 	echo "=============================================="
       			 	echo ''

				sleep 5

				clear

			fi # OK 5
	
			function GetFacter {
				facter virtual
			}
			Facter=$(GetFacter)

			if [ $Facter != 'physical' ] # 6
			then
 				echo ''
				echo "=============================================="
				echo "Orabuntu-LXC $LF Linux $RL on $Facter.        "
				echo "=============================================="
				echo ''

				sleep 5

				clear

				if [ -f /etc/orabuntu-lxc-terms ] && [ -f /etc/orabuntu-lxc-release ] # 7
				then
					echo ''
					echo "=============================================="
					echo "                                              "
					echo "If you already have an Orabuntu-LXC install   "
					echo "on this host and just want to add more        "
					echo "containers then answer 'Y' to this.           "
					echo "                                              "
					echo "If you are doing a complete Orabuntu-LXC      "
					echo "reinstall then answer 'N' to this.            "
					echo "                                              "
					echo "=============================================="
					echo "                                              "
					echo "=============================================="
					echo "                                              " 
				read -e -p   "Adding Orabuntu-LXC containers? [Y/N]  " -i "Y" CloningAdditional
					echo "                                              "
					echo "=============================================="
				
					sleep 5

					clear

					if [ $CloningAdditional = 'n' ] || [ $CloningAdditional = 'N' ] # 8
					then
 						./orabuntu/orabuntu-services-1.sh $MajorRelease $PointRelease $Domain1 $Domain2 $NameServer $OSMemRes $MultiHost
 						./orabuntu/orabuntu-services-2.sh $MajorRelease $PointRelease $Domain1 $Domain2 $MultiHost $NameServer
 						./orabuntu/orabuntu-services-3.sh $MajorRelease $PointRelease $Domain2
						./orabuntu/orabuntu-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost
						./orabuntu/orabuntu-services-5.sh $MajorRelease $PointRelease 
					fi # OK 8

					if [ $CloningAdditional = 'y' ] || [ $CloningAdditional = 'Y' ] || [ $MultiHostVar1 = 'addclones' ] # 9
					then
						./orabuntu/orabuntu-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost
						./orabuntu/orabuntu-services-5.sh $MajorRelease $PointRelease
					fi # OK 9

				fi # OK 7
		
				if [ ! -f /etc/orabuntu-lxc-release ] # 10
				then
					./orabuntu/orabuntu-services-1.sh $MajorRelease $PointRelease $Domain1 $Domain2 $NameServer $OSMemRes $MultiHost
					./orabuntu/orabuntu-services-2.sh $MajorRelease $PointRelease $Domain1 $Domain2 $MultiHost $NameServer
					./orabuntu/orabuntu-services-3.sh $MajorRelease $PointRelease $Domain2
					./orabuntu/orabuntu-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost
					./orabuntu/orabuntu-services-5.sh $MajorRelease $PointRelease 
				fi # OK 10

				clear

 				echo ''
				echo "=============================================="
				echo "Orabuntu-LXC $LF Linux $RL complete.          "
				echo "=============================================="
	
				sleep 5

 			else # OK 6

				echo ''
				echo "=============================================="
				echo "Orabuntu-LXC $LF Linux $RL on $Facter.        "
				echo "=============================================="
				echo ''

				sleep 5

				clear

				if [ -f /etc/orabuntu-lxc-terms ] && [ -f /etc/orabuntu-lxc-release ] # 11
				then
					echo ''
					echo "=============================================="
					echo "                                              "
					echo "If you already have an Orabuntu-LXC install   "
					echo "on this host and just want to add more        "
					echo "containers then answer 'Y' to this.           "
					echo "                                              "
					echo "If you are doing a complete Orabuntu-LXC      "
					echo "reinstall then answer 'N' to this.            "
					echo "                                              "
					echo "=============================================="
					echo "                                              "
					echo "=============================================="
					echo "                                              " 
				read -e -p   "Adding Orabuntu-LXC containers? [Y/N]  " -i "Y" CloningAdditional
					echo "                                              "
					echo "=============================================="
				
					sleep 5

					clear

					if [ $CloningAdditional = 'n' ] || [ $CloningAdditional = 'N' ] # 12
					then
 						./orabuntu/orabuntu-services-1.sh $MajorRelease $PointRelease $Domain1 $Domain2 $NameServer $OSMemRes $MultiHost
 						./orabuntu/orabuntu-services-2.sh $MajorRelease $PointRelease $Domain1 $Domain2 $MultiHost $NameServer
 						./orabuntu/orabuntu-services-3.sh $MajorRelease $PointRelease $Domain2
						./orabuntu/orabuntu-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost  
						./orabuntu/orabuntu-services-5.sh $MajorRelease $PointRelease 
					fi # OK 12

					if [ $CloningAdditional = 'y' ] || [ $CloningAdditional = 'Y' ] || [ $MultiHostVar1 = 'addclones' ] # 13
					then
						./orabuntu/orabuntu-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost
						./orabuntu/orabuntu-services-5.sh $MajorRelease $PointRelease
					fi # OK 13
				fi # OK 11
		
				if [ ! -f /etc/orabuntu-lxc-release ] # 14
				then
					./orabuntu/orabuntu-services-1.sh $MajorRelease $PointRelease $Domain1 $Domain2 $NameServer $OSMemRes $MultiHost
					./orabuntu/orabuntu-services-2.sh $MajorRelease $PointRelease $Domain1 $Domain2 $MultiHost $NameServer
					./orabuntu/orabuntu-services-3.sh $MajorRelease $PointRelease $Domain2
					./orabuntu/orabuntu-services-4.sh $MajorRelease $PointRelease $NumCon $NameServer $MultiHost 
					./orabuntu/orabuntu-services-5.sh $MajorRelease $PointRelease 
				fi # OK 14

				sleep 5

				clear
			
				echo ''
				echo "=============================================="
				echo "Orabuntu-LXC for $LF Linux $RL complete.      "
				echo "=============================================="
	
				sleep 5

			fi # OK 6

 		fi # $UbuntuMajorVersion -ge 15

	fi # $LinuxFlavor = 'Ubuntu'

fi # OK $KernelPassFail = 'Pass'
