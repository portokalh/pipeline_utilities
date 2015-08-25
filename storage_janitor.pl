#!/usr/bin/perl
# Storage janitor. 
# runs on a given directory, ENV{BIGGUS_DISKUS} by default.
# checks files against test age. 
# Bins files into groups one interval(default one week) big.
# any older than 1/2 max age(max intervals) are added to a warning list.
# any older than max age are added to critical list, 
#
# compiles a summary of disk usage by user.
# while the largest offender has more than 1.3 times the next user and 
# there is less than 30% free disk space moves off their oldest file group
# and adds to the elimination queue
# 
# while there is less than 30% free moves off their oldest file group for each user and 
# adds to the elimnination queue. 
#
# checks the elimination queue, emails every user about files in there and how long,
# If they've been in there more than five intervals they will be eliminted from secondary storage.
 

# 
use warnings;
use strict;
use DateTime;
use File::Path qw(make_path);
use POSIX;
#use GetOpt::Long;
#use File::stat;
#use ENV;# qw(BIGGUS_DISKUS);


my $test_age="7";      #test age in days, starting with 1 week.
my $max_intervals="5"; #max file age in test_age intervals.
my $min_size="5M";     #minimum size. If there are no small files present, will change min size.
my $files_found=0;
my $SCAN_DIR=$ENV{'BIGGUS_DISKUS'}; # directory we're testing for old files.
my $interval_seconds=($test_age*24*60*60);
my $current_epoc_time=time;
my $dt = DateTime->from_epoch(epoch => $current_epoc_time );






=begin comment
sub option_process {
    if ( 
	!GetOptions( 'test_age=s' => \$test_age,
		   'max_intervals=s' => \$max_intervals,
		   'min_size=s' => \$min_size,
 		   'SCAN_DIR=s' => \$SCAN_DIR
# 		   'd' => \$options{d},
# 		   'f' => \$options{f},
# 		   'n' => \$options{n},
# 		   'r' => \$options{r},
#		   's=s' => \$options{s},
#		   't=s' => \$options{t},
#		   'reg-parallel!' => \$options{regparallel},
		   #'reg-serial' => \$options{regserial},
#		   'rigid-affine=s' => \$rigid_affine,
#		   'suffix=s' => \$extra_runno_suffix
		     
	) ) {
	die ("Option processing failure\n") ;
    }
    
}
=end comment
    
=cut

sub file_discovery { 
#$SCAN_DIR="/glusterspace"
    #option_process;
    my ($out_dir)=@_;
    my $cmd="find $SCAN_DIR -size +$min_size -mtime +$test_age -type f -printf \"%TY-%Tm-%Td-%Tw_%TT|%T@|%AY-%Am-%Ad-%Aw_%AT|%A@|%s|%u|%h/%f\n\" ";
#1970time->%A@

    my %OUT_HASH;

###
# find the files and parse to one interval long groups
###

#open command
# while output
# split output into the parts
#\"%TY-%Tm-%Td-%Tw_%TT|%AY-%Am-%Ad-%Aw_%AT|%s|%u|%h/%f
#modtime|accesstime|bytesize|user|path/file
#modtime1970sec|accesstime1970sec

#        my $pid = open(PH, "$c 3>&1 1>&2 2>&3 3>&-|");
#        while (<PH>) {

print("Staring search command\n$cmd\n");
    return;    #exit;
my $pid = open( my $CID,"-|", "$cmd"  ) ;

print("PID:$pid\n");


while ( my $line=<$CID> ) {
    #my $line=$_;
    $files_found++;
    chomp $line;
    my ($mod_time,$mod_epoc,$accesstime,$access_epoc,$bytesize,$user,$path,@rest)=split('\|',$line);
    #my @line_c=split('|',$line);
    #my ($mod_time,$accesstime,$bytesize,$user,$path,@rest)=@line_c;
    #print(join(':',@line_c));
    #print("\t$line\n\t$path:$user:$bytesize");
    my ($yr,$mo,$day,$hr,$min,$sec,$sec_frac)=time_spliter($mod_time);
    #print("$bytesize\n\t$user\n\t$mod_time\n\t$accesstime\n\tfile:$path\n");
    my $age_in_sec=($current_epoc_time-$mod_epoc);
    my $interval_m=floor($age_in_sec/$interval_seconds);

    my $access_age=($current_epoc_time-$accesstime);
    my $interval_a=floor($access_age/$interval_seconds);

    my $interval=min($interval_a,$interval_m);

    if ( $interval > $max_intervals) {
	$interval = "critical_$interval";
    } elsif ( $interval > ($max_intervals/2) ) ||  ( $interval_m > ($max_intervals/2) ) {
	$interval = "warning_$interval";
    } 
    my $info_dir=$out_dir."/$user/";
    my $out_file="${info_dir}filelist_$interval.txt";

    make_path($info_dir);
    #print("Dumping info to $out_file\n");
    open(my $fh, '>>', "$out_file") or die "Cannot open $out_file.";
    my @f_stats=stat($fh);
    #my $log_modtime=(stat($fh))[9];
    #if ( ! defined $log_modtime) { 
    #$log_modtime=$f_stats[9];
    #}
    #print (join(':',@f_stats)." f stat\n");
    #if ( ( $current_epoc_time-$log_modtime) < 0 ) {
    if ( ( $f_stats[9]-$current_epoc_time) < 0 ) {
	close($fh);
	#print("clearing last file\n");
	open($fh, '>', "$out_file") or die "Cannot open $out_file.";
    }
    #print("$f_stats[9]-$current_epoc_time=".($f_stats[9]-$current_epoc_time));
    print $fh ("$bytesize\|$path\n"); #    print $fh ("$path\|$bytesize\n");
    #print $fh ("$path\n");
    close $fh;
    
}
    close $CID;

    return $files_found;
}


sub make_user_summary {

    my ($out_dir,$user)=@_;    
    my $user_regex;
    if ( ! defined $user || $user eq '' ) {
	$user_regex="*";
    } else {
	$user_regex="$user";
    }
    # find all the files in the storage janitor dir and get their size.
    opendir(DIR, "$output_dir") or die $!;
#    my @matches = grep(/^$n$s/, readdir(DIR));
    closedir(DIR);
 

   #for each user dir, 
    #    declare user summary vars
    #    for each interval category
    #        for each interval file
    #            open file, add size to summary
    #            if file past critical move files to deep storage.
    #                save reversal commands on deepstorage device?
    # save user summary
    # save group summaryies
    

    return;


}

#
sub notify_users {
    # for each user
    #make email
    return ;
}

sub main {
    my $out_dir=$SCAN_DIR."/Storage_janitor";
    my $files_found=file_discovery($out_dir);
    my $summary = make_user_summary($out_dir);
    my $transfer_status = transfer_user_data($out_data);
    print("files $files_found found at least $test_age days old\n");
    


}


### MAIN RUNS HERE .
main ;



sub time_spliter {
    #change time to 1970 seconds.
    my ($intime)=@_;
    my ($date,$time)=split("_",$intime);
    my ($yr,$mo,$day)=split("-",$date);
    my ($hr,$min,$secwf)=split(":",$time);
    my ($sec,$sec_frac)=split('.',$secwf);
#    my $yrsecs=($yr-1970)*365*24*60*60;
#    my $leapsecs=leapdays($yr)*24*60*60;#($yr-1970)
#    print("leap:$leapsecs\n");
#    my $mosecs=d_p_mo($mo)*24*60*60;
#    my $daysecs=$day*24*60*60;
    #print("date:$date,time:$time\n");
    #print("y:$yr,m:$mo,d:$day h:$hr,m:$min,swf:$secwf s:$sec,$sec_frac\n");
#    my $outtime = $yrsecs+$leapsecs+$mosecs+$daysecs+$hr*60+$sec;
#    return $outtime;
    return($yr,$mo,$day,$hr,$min,$sec,$sec_frac);
}



sub d_p_mo { # obsolete function.
# days per month function
    my ($month)=@_;
    my %month_days=( 
	"1" => 31, #jan
	"2" => 28, #feb
	"3" => 31, #mar
	"4" => 30, #apr
	"5" => 31, #may
	"6" => 30, #jun
	"7" => 31, #jul
	"8" => 31, #aug
	"9" => 30, #sept
	"10" => 31, #oct
	"11" => 30, #nov
	"12" => 31, #dec
	);
    my $days=0;
    for(my $i=1;$i<$month;$i++) {
	$days=$month_days{$i}+$days;
    }	

    return $days;
}


sub leapdays { #obsolete function
# n leap days to add to our nyears*days
    my ($startyear)=@_;
    my $leap_days=0;
    while($startyear % 4 && $startyear>1970) {
	$startyear -- ;
    }
    
    while($startyear > 1970) {
	#print("$startyear\n");
	$startyear = $startyear-4;
	$leap_days++;
    }
    return $leap_days;
        
}
