#!/bin/bash

a=1; c=0
a=1; c=0
# Gather system information, can e.g. be sent to | mail in a cronjob
f_() { while read l; do echo $l; done < $f ; }
#
f_() { while read l; do echo $l; done < $f ; }
# TODO
# ----
# * Netstat output
# * Memory/swap information
# * ifconfig information
# * Make output dependent on argv
# * md5sum checks                               (done)
# * Keep previeous values and compare
# * How to
# * chmod a+x sysinfo.sh
# * ./sysinfo.sh
####################### DO NOT EDIT UNDER THIS LINE ###########################

siheader() {
        echo "================================================================"
        echo -e "* System statistics for: \t`hostname`.`dnsdomainname`"
        echo -e "* Generated on: \t\t`date`"
        echo -e "* Running as: \t\t\t`whoami`"
        echo
}

fuptime() {
        upSeconds=$(cat /proc/uptime | tr "." " " | awk '{print $1}')
        secs=$((${upSeconds}%60))
        mins=$((${upSeconds}/60%60))
        hours=$((${upSeconds}/3600/24))
        days=$((${upSeconds}/86400))
        if [ "${days}" -ne "0" ]
        then
                echo -n "${days} days, "
        fi
        echo "`printf '%02d' ${hours}`:`printf '%02d' ${mins}`:`printf '%02d' ${secs}`"
}

siuptime() {
        echo "=================== Uptime ====================================="
        echo -e "* Uptime: \t\t\t`fuptime`"
        if [ -x /usr/bin/uprecords ];
        then
                echo -e "* High score: \t\t\t`uprecords | tail -n1 | cut -d'|' -f1 | cut -d'n' -f3 | sed 's/^[[:blank:]]*//'`"
        fi
        echo -e "* Load average: \t\t`cat /proc/loadavg | head -c14`"
        echo
}

fw () {
        OFS=${IFS}
        IFS=$'\n'
        CNT=$(echo `w | wc -l`-1 | bc)

        w | tail -n ${CNT} | while read -r a;
        do
                echo -e "\t${a}"
        done

        IFS=${OFS}
}

siusers() {
        echo "=================== Users ======================================"
        echo -e "* Active users: \t\t`who | wc -l`"
        echo "* User information"
        fw
        echo
}

fpstree() {
        OFS=${IFS}
        IFS=$'\n'
        pstree | while read -r a;
        do
                echo -e "\t${a}"
        done
        IFS=${OFS}
}

fcomms() {
        ps -eo comm | sort | uniq | grep -v ^COMMAND | column
        echo

        IFS=${OFS}
}

fprocs() {
        echo `TERM=Linux top -n1 -b | grep "Tasks" | awk '{print $4,$6,$8,$10}'`
        echo -e "==================================Tasks process and memory utilization=============================\n"
    echo "`top -n1 -b`"
}


sitasks() {
        echo "=================== Tasks ======================================"
        echo -e "* Number of running tasks: \t$(echo `ps ax | wc -l` - 1 | bc)"
        #This screws up the email
        #echo "* PS Tree:"
        #fpstree
        echo "* Running programs:"
        fcomms
        echo -e "* CPU load: \t\t\t`TERM=linux top -n2 -b | grep 'Cpu' | tail -n1 | awk '{print $2+$4+$6}'`%"
        PROCS=`fprocs`
        echo "* Process state:"
        echo -e "\tRunning: \t\t`echo ${PROCS} | awk '{print $1}'`"
        echo -e "\tSleeping: \t\t`echo ${PROCS} | awk '{print $2}'`"
        echo -e "\tZombie: \t\t`echo ${PROCS} | awk '{print $3}'`"
        echo -e "\tStopped: \t\t`echo ${PROCS} | awk '{print $4}'`"
        echo
}

froute() {
        OFS=${IFS}
        IFS=$'\n'

        CNT=$(echo `/sbin/route | wc -l` - 1 | bc)
        /sbin/route | tail -n ${CNT} | while read -r a;
        do
                echo -e "\t${a}"
        done

        IFS=${OFS}
}

sinetwork() {
        echo "=================== Networking ================================"
        echo "* Routing table:"
        froute
        echo
}

simemory() {
        echo "=================== Memory ===================================="
        RAMTOTAL=`echo $(($(cat /proc/meminfo | grep MemTotal | awk '{print $2}')/1024))`
        echo "* Ram:\t\t\t free of ${RAMTOTAL}Mb"
}

sidiskstats() {
        echo "=================== Hard Disc ================================="
        echo "* Disk Information:"
        OFS=${IFS}
        IFS=$'\n'
        df -h | grep -v ^none | while read -r a;
        do
                echo -e "\t${a}"
        done
        IFS=${OFS}
        echo
        echo "* Mounts:"
        OFS=${IFS}
        IFS=$'\n'
        mount | while read -r a;
        do
                echo -e "\t${a}"
        done
        IFS=${OFS}
        echo
}

simd5() {
        if [ ! -e md5sums.lst ];
        then
                return
        fi

        echo "=================== MD5Sum Check =============================="

        OFS=${IFS}
        IFS=$'\n'

        echo "* Checking MD5 Sums"

        cat md5sums.lst | grep "^/" | while read -r a;
        do
                F=`echo ${a} | cut -d':' -f1`
                S=`echo ${a} | cut -d':' -f2`
                S2=`md5sum ${F} | cut -d' ' -f1`
                echo -n -e "\t${F}: \t\t\t\t"
                if [ "${S}" = "${S2}" ];
                then
                        echo "[OK]"
                else
                        echo "[INVALID]"
                fi                        
        done

        IFS=${OFS}
        echo
}


##For finding CPU model, cores and 
cpuinfo() {
    echo "=================== CPU Details for Xen =============================="
    echo -e "CPU Details: \n`cat /proc/cpuinfo | sed -n '1,/^$/p'`"
    echo -e "No of Cores: \n`cat /proc/cpuinfo | grep processor | wc -l`"
    if [ "egrep '(vmx|svm)' /proc/cpuinfo >/dev/null 2>/dev/null" ];
    then
        echo -e "\n===============================================================\nServer supports Full-virtualization"
    else
        echo -e "\n===============================================================\nEither server does not support Full-virtualization or it is turned off in BIOS"
    fi

    if [ "egrep 'pae' /proc/cpuinfo >/dev/null 2>/dev/null" ];
    then
        echo -e "\n===============================================================\nServer supports Para-virtualization"
    else
        echo -e "\n===============================================================\nServer does not support Para-virtualization"
    fi
}

##For disk info
diskinfo() {
        echo "=================== Disk usage =============================="
        echo -e "Disk Usage details: \n`df -h`"
}   
##Distro info
distroinfo() {
        echo "=================== Distro Info =============================="
        echo -e "Distro details: \n`lsb_release -a`"
        echo -e "Kernel details: \n`uname -a`"
}   

##Distro info
deviceinfo() {
        echo "=================== Device Info =============================="
        echo -e "Device details: \n`lspci -v`"
        echo -e "Kernel details: \n`uname -a`"
}   
summary() {
        siheader
        siuptime
        siusers
        sitasks
        sinetwork

        simemory
        sidiskstats
    fprocs
        simd5
    deviceinfo
    cpuinfo
    distroinfo
        echo "==============================================================="
        echo "* Brought to you by Taashee- http://www.taashee.com"
}

summary
