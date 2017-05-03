#!/bin/bash
function disp_help()  {
    echo " Simple memory graph which works under linux.";
    echo " Graphs specified pid as pct of total, ";
    echo " or pct of free before proc started ";
    echo " or as pct of some specified max";
    echo " max can be specifed using GMk for GB, MB, or kB";
    return;
}

proc="$1";
mode="$2";
interval="$3";
if [ -z "$interval" ] ; then 
    interval=1;
fi
if [ -z "$proc" ]; 
then
    proc=100000000;
    mode="";
    disp_help;
fi;
kb_limit=1;

top -bn1 -p "$proc" > ~/.tout.txt &
res=$(ps -p "$proc" -o rss,%mem,%cpu,cmd|tail -n 1);
prog_used=$(echo "$res"|cut -d ' ' -f1); 
if [ -z "$prog_used" ]; then
    echo "program not found or not specified";
    prog_used=0;
fi;
awk '/Mem/ {  prog_used = '"$prog_used"'
                      total = $2 * 1
                      used = $4 * 1
                      free = $6 * 1
                      other_mem = used - prog_used
                      prog_pct = 100 * prog_used / total
                      other_pct = 100 * other_mem / total
                      free_pct = 100 * free / total
                      pf_pct = 100 * prog_used / '"$kb_limit"'
                      if( pf_pct > 100 ) { pf_pct = 0 }  }; 
             END   { print total
                     print used
                     print free
                     print other_mem
                     print prog_used
                     print prog_pct
                     print other_pct
                     print free_pct 
                     print pf_pct };' ~/.tout.txt  > ~/.tmem_out.txt
NUM=1;  totalKB=$(sed "${NUM}q;d" ~/.tmem_out.txt );
NUM=2;   usedKB=$(sed "${NUM}q;d" ~/.tmem_out.txt );
NUM=3;   freeKB=$(sed "${NUM}q;d" ~/.tmem_out.txt );
NUM=4;  otherKB=$(sed "${NUM}q;d" ~/.tmem_out.txt );
NUM=5;   progKB=$(sed "${NUM}q;d" ~/.tmem_out.txt );
NUM=6; pct_prog=$(sed "${NUM}q;d" ~/.tmem_out.txt | cut -d '.' -f1);
NUM=7;pct_other=$(sed "${NUM}q;d" ~/.tmem_out.txt | cut -d '.' -f1);
NUM=8; pct_free=$(sed "${NUM}q;d" ~/.tmem_out.txt | cut -d '.' -f1);
NUM=9;   pf_pct=$(sed "${NUM}q;d" ~/.tmem_out.txt | cut -d '.' -f1);
if [ ! -z "$mode" ] ; then
    mul=1;
    num=$mode;
    lim="${mode: -1}";
    lp=0;
    if [ "${mode: -1}" == G ]; then
	lp=1;
	mul=1024*1024;
	num="${mode%?}";
    elif [ "${mode: -1}" == M ]; then
	lp=1;
	mul=1024*1024;
	num="${mode%?}";
    elif [ "${mode: -1}" == k ]; then
	num="${mode%?}";
    fi
    if [ $lp -eq 1 ]; then
	echo "Limit specified in $lim";
    fi
    mode=`awk "BEGIN{ print $num * $mul }"`;
    if [ $mode -eq 1 -o $mode = "free" ]; then
	kb_limit="$freeKB";
    elif [ $mode -gt 1 ]; then echo -n ""; #-o $mode = "max" ]; then
	kb_limit=$mode;
    fi
fi
#echo $kb_limit;exit;
while [ 1 ] ; do 
    top -bn1 -p "$proc" > ~/.tout.txt & 
    res=$(ps -p "$proc" -o rss,%mem,%cpu,cmd|tail -n 1);
    prog_used=$(echo "$res"|cut -d ' ' -f1); 
    if [ -z "$prog_used" ]; then
	prog_used=0;
    fi;
    wait;
#top -bn1 -p $proc > ~/.tout.txt
#
#top - 16:21:53 up 91 days,  7:21, 18 users,  load average: 0.09, 0.43, 0.50
#Tasks:   1 total,   0 running,   1 sleeping,   0 stopped,   0 zombie
#Cpu(s):  2.6%us,  1.1%sy,  0.0%ni, 95.6%id,  0.6%wa,  0.0%hi,  0.1%si,  0.0%st
#Mem:  264471840k total, 126189572k used, 138282268k free,   990272k buffers
#Swap: 15999924k total,  1615340k used, 14384584k free, 73509496k cached
#
#   PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND
#
#120862 jjc29     20   0 76.7g 1.6g 110m S  0.0  0.6  64:07.50 MATLAB
#
#
#
#top -bn1 | awk '/Mem/ { mem = "Memory in Use: " $6 / $2 * 100 "%" };
#                /Cpu/ { cpu = "CPU in Use: " 100 - $5 "%" };
#                END   { print mem "\n" cpu }'
#
    if [ "a" == "a" ]; then
#	awk '/Mem/ { total = $2 * 1 
#                     used = $4 * 1 
#                     free = $6 * 1 }; END { print "t=" total ":\n" "u=" used ":\n" "f=" free ":\n" "\n\n" };' ~/.tout.txt
#	echo "awkend";
	awk '/Mem/ {  prog_used = '"$prog_used"'
                      total = $2 * 1
                      used = $4 * 1
                      free = $6 * 1
                      other_mem = used - prog_used
                      prog_pct = 100 * prog_used / total
                      other_pct = 100 * other_mem / total
                      free_pct = 100 * free / total
                      pf_pct = 100 * prog_used / '"$kb_limit"'
                      if( pf_pct > 100 ) { pf_pct = 100 }  }; 
             END   { print total
                     print used
                     print free
                     print other_mem
                     print prog_used
                     print prog_pct
                     print other_pct
                     print free_pct 
                     print pf_pct };' ~/.tout.txt  > ~/.tmem_out.txt
	NUM=1;  totalKB=$(sed "${NUM}q;d" ~/.tmem_out.txt );
	NUM=2;   usedKB=$(sed "${NUM}q;d" ~/.tmem_out.txt );
	NUM=3;   freeKB=$(sed "${NUM}q;d" ~/.tmem_out.txt );
	NUM=4;  otherKB=$(sed "${NUM}q;d" ~/.tmem_out.txt );
	NUM=5;   progKB=$(sed "${NUM}q;d" ~/.tmem_out.txt );
	NUM=6; pct_prog=$(sed "${NUM}q;d" ~/.tmem_out.txt | cut -d '.' -f1);
	NUM=7;pct_other=$(sed "${NUM}q;d" ~/.tmem_out.txt | cut -d '.' -f1);
	NUM=8; pct_free=$(sed "${NUM}q;d" ~/.tmem_out.txt | cut -d '.' -f1);
	# get prog as pct of free
	NUM=9;   pf_pct=$(sed "${NUM}q;d" ~/.tmem_out.txt | cut -d '.' -f1);
#	NUM=10;pct=$(sed "${NUM}q;d" ~/.tmem_out.txt | cut -d '.' -f1);
#	NUM=11;pct=$(sed "${NUM}q;d" ~/.tmem_out.txt | cut -d '.' -f1);
#	NUM=12;pct=$(sed "${NUM}q;d" ~/.tmem_out.txt | cut -d '.' -f1);
#	NUM=13;pct=$(sed "${NUM}q;d" ~/.tmem_out.txt | cut -d '.' -f1);
#	NUM=14;pct=$(sed "${NUM}q;d" ~/.tmem_out.txt | cut -d '.' -f1);
#	NUM=15;pct=$(sed "${NUM}q;d" ~/.tmem_out.txt | cut -d '.' -f1);
	if [ "$kb_limit" -eq 1 ]; then
	    if [ ! -z "$mode" ]; then
		if [ "$mode" -eq 1 -o "$mode" = "free" ]; then echo -n "";
		    kb_limit="$freeKB"; fi;
	    fi;
	elif [ $mode -eq 2 -o $mode = "max" ]; then echo -n "";
	    
	fi
    else
	system_kb=$(cat ~/.tout.txt | awk '/Mem/ { mem = $2 * 1 }; END {print mem}');
	current_used_kb=$(cat ~/.tout.txt | awk '/Mem/ { mem = $6 * 1 }; END {print mem}');
	other_used_kb=$(awk "BEGIN{ print $current_used_kb-$prog_used }");
	pct_prog=$(awk "BEGIN{ print $prog_used/$system_kb }" | cut -d '.' -f1); # int rounding cuz why not.
      	pct_other=$(awk "BEGIN{ print $other_used_kb / $system_kb }"|cut -d '.' -f1);
	pct_free=$(awk "BEGIN{ print ($system_kb-$current_used_kb) / $system_kb }"|cut -d '.' -f1);
    fi;
    #printf '=%.0s' {1..100}
    if [ -z "$mode" ]; then echo -n "";
	pct_total=$(( $pct_prog + $pct_other + $pct_free ));
	pct_err=$(( 100 - $pct_total ));
	c_total=$(( $pct_prog + $pct_other + $pct_free + $pct_err ));
    else echo -n "";
	# we're in floating scale mode. 
	pct_prog=$pf_pct;
	pct_free=$(( 100 - $pf_pct ));
	pct_other=0;
	pct_err=0;
	pct_total=$(( $pct_prog + $pct_other + $pct_free ));
	c_total=$(( $pct_prog + $pct_other + $pct_free + $pct_err ));
    fi
    ptxt="";
    if [ "$pct_prog" != 0 ]; then echo -n "";
	eval "printf '+%.0s' {1..$pct_prog}";
	ptxt="p$pct_prog";
    fi
    otxt="";
    if [ "$pct_other" != 0 ]; then echo -n "";
	eval "printf 'o%.0s' {1..$pct_other}";
	otxt="+ p$pct_other";
    fi
    if [ "$pct_free" != 0 ]; then echo -n "";
	eval "printf '_%.0s' {1..$pct_free}";
    fi
    etxt="";
    if [ "$pct_err" != 0 ]; then echo -n "";
	eval "printf 'x%.0s' {1..$pct_err}";
	etxt="+ e$pct_err";
    fi
    echo "  p$pct_prog $otxt + f$pct_free $etxt = $c_total";
    sleep $interval;
done