#!/bin/bash
# simple script to run and have each engine update data directories 
if [ -z $WORKSTATION_HOME ]; then
    echo "WORKSTATION_HOME must be set!";
    exit
else
    source $WORKSTATION_HOME/pipeline_settings/bash/bashrc_pipeline_setup
fi
if [ ! -d $WORKSTATION_HOME/logs ] ; then 
    mkdir $WORKSTATION_HOME/logs;
fi
HOST_TYPE=`uname`;
time_suffix="m";
time_switch="mtime";
if [ $HOST_TYPE != "Darwin" ]; then 
    echo "ONLY WORKS ON MAC ";
exit;
fi
if [ $HOST_TYPE == "Linux" ]; then
time_suffix="";
time_switch="mmin";
fi
hostlist="$@"
if [ -z "$hostlist" ] 
then
    hostlist=`get_workstation_hosts`
    if [ -z "$hostlist" ] ; then
	echo "could not get host list"
	exit;
    fi
fi

# put names in a file one line at a time
for host in $hostlist ;
do echo $host >>temphost.list; 
    hostlist_regex="$hostlist_regex|`echo -n $host `";
done 
skip_check_age=5; # data update log files younger than this number
ssh_opts=" -o BatchMode=yes -o ConnectionAttempts=1 -o ConnectTimeout=1 -o IdentitiesOnly=yes -o NumberOfPasswordPrompts=0 -o PasswordAuthentication=no";
# get only uniq elements from file list
for host in `cat temphost.list | sort -u`
do
    dir=`pwd`
    if [ test `find "$WORKSTATION_HOME/logs/data_status_${host}.log" -${time_switch} -${skip_check_age}${time_suffix}` ]; then
	echo " --- updating host $host : $dir ---"
	bash_cmd_string="$WORKSTATION_HOME/shared/pipeline_utilities/workstation_data_update.pl;"
	echo "ssh $ssh_opts $host bash -c \"'$bash_cmd_string'\" 2>&1 > $WORKSTATION_HOME/logs/data_update_${host}.log &"
	ssh $ssh_opts $host bash -c "'$bash_cmd_string'" 2>&1 > $WORKSTATION_HOME/logs/data_update_${host}.log &
    fi
done
rm temphost.list
wait;
# look for files created recently, but not necessarily the same time max age as above.
#for file in `find $WORKSTATION_HOME/logs -mtime -10m -iname "data_status*.log"`; do 
if [ $skip_check_age -lt 5 ]; then
    skip_check_age=15;# if low age set reasonable max age(15 min old)
fi
echo $hostlist_regex
for file in `find $WORKSTATION_HOME/logs -${time_switch} -${skip_check_age}${time_suffix} -iname "data_update_*.log" | grep -Ee "($hostlist_regex)"`; do 
    echo "----- $file -----"; 
    cat $file;
done
