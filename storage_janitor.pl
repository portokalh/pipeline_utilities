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
use POSIX;
use DateTime;

use Data::Dumper qw(Dumper);

use File::Path qw(make_path);
use File::Basename;
use Filesys::Df;

use Net::OpenSSH;

#use civm_simple_util qw(printd $debug_val);
#require ssh_call;
#use GetOpt::Long;
#use File::stat;
#use ENV;# qw(BIGGUS_DISKUS);



# input handling here.

##### inputs
my $test_age="7";      #test age in days, starting with 1 week.
my $max_intervals="5"; #max file age in test_age intervals.
my $min_size="5M";     #minimum size. If there are no small files present, will change min size.
my $files_found=0;     #result, number of files matching criteria. a scan count.
my $disk_safety_threshold=0.8;  # disk must be at least this % full before we start moving.
my $disk_cleaning_threshold=0.5;   # if disk is at least this % full email users to clean up with the summary of who's the biggest.

my $SCAN_DIR=$ENV{'BIGGUS_DISKUS'}; # directory we're testing for old files.
if( ! defined $SCAN_DIR && defined $ARGV[0] ){ 
    $SCAN_DIR=$ARGV[0];
}
    
my $HOST=$ENV{'HOSTNAME'};



##### globals
my $interval_seconds=($test_age*24*60*60);
my $current_epoc_time=time;
my $dt = DateTime->from_epoch(epoch => $current_epoc_time );

my $debug_val=40;
my $ref=df($SCAN_DIR);
my $TOTALKS=0;
my $USEDKS=0;
if ( defined $ref ) {
    $TOTALKS=$ref->{'blocks'};
    $USEDKS =$ref->{'used'};
}
my $unit="G";
my %disk_units=(
    "E" => 1024**6,
    "P" => 1024**5,
    "T" => 1024**4,
    "G" => 1024**3,
    "M" => 1024**2,
    "K" => 1024,
    "B" => 1,
    );

# user definitions
# where do we put data.
# remote user, remote host, remote location.
my %user_definitions=( 
    "abadea" => [ qw(alex rhodos.duhs.duke.edu /Users/alex/) ], 
    "edc15" => [ qw(edc15 trinity.duhs.duke.edu /Users/edc15) ], 
    "hw133" => [ qw(hj hj hj) ], 
    "jjc29" => [ qw(james panorama.duhs.duke.edu /Users/BiGDATADUMP) ], 
    "ksd15" => [ qw(kyle wheezy.duhs.duke.edu /Volumes/wheezyspace) ], 
    "lucy" => [ qw(lucy wytyspy.duhs.duke.edu /Users/lucy) ], 
    "lx21" => [ qw(lx21 andromeda.duhs.duke.edu /Volumes/andromedaspace) ], 
    "mf177" => [ qw(mf177 milos.duhs.duke.edu /Volumes/milosspace) ], 
    "rja20" => [ qw(rja20 atlasdb.duhs.duke.edu /atlas3/rja20) ], 
    "rmd22" => [ qw(rmd22 atlasdb.duhs.duke.edu /atlas3/rmd22) ], 
    );
if ( 0 ) {
print(%user_definitions);
print("\n");

print($user_definitions{"jjc29"});
print("\n");

print(%user_definitions."\n\n");
print($user_definitions{"jjc29"}."\n\n");

print(join(" ", keys %user_definitions)."\n\n");
#print(join(" ",@{$user_definitions{"jjc29"}})."\n\n");
print("\n");
print("\n");
print Dumper %user_definitions;
print("\n");print("\n");
exit;
}
my %admins =(
    "jjc29" => "James Cook",
    "upchu005" => "Lucy Upchurch",
    );
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
    my ($scan_dir,$out_dir)=@_;
    #my $scan_dir="$out_dir../";
    my $cmd="find $scan_dir -size +$min_size -mtime +$test_age -type f -printf \"%TY-%Tm-%Td-%Tw_%TT|%T@|%AY-%Am-%Ad-%Aw_%AT|%A@|%s|%u|%h/%f\n\" ";
#1970time->%A@

    my %out_hash; # a hash of open fileid's in theory we can have a lot of open file identifiers. 
    # the keys are user(warning|critical)_weeks_old

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
#    return 0;    #exit;
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

    my $access_age=($current_epoc_time-$access_epoc);
    my $interval_a=floor($access_age/$interval_seconds);

    #my $interval=min($interval_a,$interval_m);
    my $interval=$interval_a<$interval_m ? $interval_a : $interval_m ;

    if ( $interval > $max_intervals) {
	$interval = "critical_$interval";
    } elsif ( $interval > ($max_intervals/2)  ||   $interval_m > ($max_intervals/2) ) {
	$interval = "warning_$interval";
    } 
    my $info_dir=$out_dir."/$user/";
    my $out_file="${info_dir}filelist_$interval.txt";
    

    if ( ! defined ($out_hash{"$user$interval"} ) ) {
	if(  -d $info_dir ) {
	    move( $info_dir, $info_dir.$current_epoc_time);
	}
	open ( $out_hash{"$user$interval"},  '>', "$out_file") or die "Cannot open $out_file.";
	make_path($info_dir);
    } elsif (defined($out_hash{"$user$interval"} ) ) {
	# if we're defined we'll print later.
    } else {
        #effectively if( 0 ) never run. this is the old way of pringting;
	#print("Dumping info to $out_file\n");
	open(my $fh, '>>', "$out_file") or die "Cannot open $out_file.";
	my @f_stats=stat($fh);
	#my $log_modtime=(stat($fh))[9];
	#if ( ! defined $log_modtime) { 
	#$log_modtime=$f_stats[9];
	#}
	#print (join(':',@f_stats)." f stat\n");
	#if ( ( $current_epoc_time-$log_modtime) < 0 ) {
	if ( ( $f_stats[9]-$current_epoc_time) < 0 ) { # this handles make new vs old file
	    close($fh);
	    #print("clearing last file\n");
	    open($fh, '>', "$out_file") or die "Cannot open $out_file.";
	}
    }
    #print("$f_stats[9]-$current_epoc_time=".($f_stats[9]-$current_epoc_time));
    my $c_fh=$out_hash{"$user$interval"};
    print $c_fh ("$bytesize\|$path\n"); #    print $fh ("$path\|$bytesize\n");
    #print $fh ("$path\n");
    }
    close $CID;

    foreach (keys %out_hash) {
	print("Closing file $_");
	close $out_hash{"$_"};
    }
    return $files_found;
}


sub summarize_data {
    # make a hash of users of files and total size in file?
    my ($janitor_dir,$user)=@_;
    my $user_regex;
    if ( ! defined $user || $user eq '' ) {
	$user_regex=".*";
    } else {
	$user_regex="$user";
    }

    my %user_totals;
    my %user_usage;
    my $used_size=$USEDKS*1024;
    my $total_size=$TOTALKS*1024;
##    my %user_intervals;# for each user an array of the intervals worth of data. This is a work around to the naming problem.
    ###
    # find all users storage janitor dir and get their size.
    opendir(my $DIR, "$janitor_dir") or die $!;
    #declare user summary vars
    #for each user dir, 
    printf("Summary Processing\n");
    while ( my $d_name=readdir($DIR) ) {
	if ( $d_name !~ /^[.]+$/ ) {
	    my $sum=0;
	    printf("  $d_name\n");
	    #    for each interval category
	    if ($d_name =~ /($user_regex)/ ) {
		$user_usage{$d_name}=sum_files($janitor_dir.'/'.$d_name,"filelist");
		#$user_usage{$d_name."warning"}=sum_files($janitor_dir.'/'.$d_name,"filelist_warning");
		#$user_usage{$d_name."critical"}=sum_files($janitor_dir.'/'.$d_name,"filelist_critical");
		#my $user_sum=hash_sum($user_usage{$d_name."warning"})+hash_sum($user_usage{$d_name."critical"});
		#$user_totals{$d_name}=hash_sum($user_usage{$d_name."warning"})+hash_sum($user_usage{$d_name."critical"});
		#$user_totals{$d_name}=hash_sum($user_usage{$d_name});
		${$user_usage{"TOTAL"}}{$d_name}=hash_sum($user_usage{$d_name});
		if( 0 ) {
		    printf("  Total ( %i b ) %s's: %0.2f. pct of used : %0.2f. pct of total %0.2f.\n",
		       $user_totals{$d_name},$unit,
		       ($user_totals{$d_name}/$disk_units{$unit}),
		       ($user_totals{$d_name}/$used_size*100),
		       ($user_totals{$d_name}/$total_size*100));
		}
	    } 
	}
    }
    closedir($DIR);
    #make_summary(\%user_usage);
    #print("summary_return\n");
    
    return \%user_usage;

    while ( 1 ) {
	printf("THE NEVER NEVER LAND OF DEEP SLEEP\n");
	printf(".");
	sleep 1;
    }

    if ( 0 ) { 
	for my $user (keys %user_usage) {
	    $user_totals{$user}=0;
	    for my $file (keys %{$user_usage{$user}}) {
		$user_totals{$user}=$user_totals{$user}+$user_usage{$user}{$file};
	    }
	    printf("%s -> %0.2f%s\n",$user,($user_totals{$user}/$disk_units{$unit}),$unit );
	}
    }    
    my @users;
    my @usage;
    my @biggest;
    my @second;
    # duplcate user_usage so we can play more later.
    #my %end_usage=%user_usage; # simple copy is just a reference copy!
    #use Storable qw(dclone); # intheory more complete than clone, but slower.
    #my %copy = %{ clone (\%hash) };
    use Clone qw(clone);
    #my %copy = %{ clone (\%hash) };
    my %end_usage=%{ clone ( \%user_usage) };

    # duplcaate user totals so we can play more later. 
    #my %end_totals=%user_totals; # simple copy is just a reference copy!
    my %end_totals=%{ clone ( \%user_totals) };
    #my $used_size=$USEDKS*1024;
    #my $total_size=$TOTALKS*1024;
    sort_users(\@users,\@usage,\%end_totals);
    set_top_users(\@users,\@usage,\@biggest,\@second);
    my $cleanable_size=hash_sum(\%end_totals);
    printf("Total cleanable %0.2f%s. pct of used : %0.2f. pct of total %0.2f.\n",
	   $cleanable_size/$disk_units{$unit},$unit,
	   $cleanable_size/$used_size*100,
	   $cleanable_size/$total_size*100);

    my @remove_list;     # list of files to have their contents transfered and removed.
    my %remove_summary;  # summary of how much data is being removed per user.
    if ( $used_size/$total_size > $disk_cleaning_threshold) {
	printf("Disk cleaning engaged, used/total threshold exceeded.\n");
	#if (  $biggest[1]/$second[1]> 1.3 ) {
	    #printf("Bigest user is going to get cut.\n");
	    #my @remove_order=native_order_strings(keys(%{$user_usage{$biggest[0]}}));
	    my $ending_size=$used_size;
	    # process biggest user

	my $cleanable=1;
	while ( $ending_size/$total_size > $disk_cleaning_threshold 
		&& $biggest[1]>$second[1] && $cleanable ) {
	    printf("Big ratio : %0.2f. Cleaning up $biggest[0].\n",$biggest[1]/$second[1]);
	    
	    my @test_order=reverse sort by_number grep (/critical/, keys(%{$end_usage{$biggest[0]}}) );
	    
	    if ( $#test_order>=0 && ( $test_order[0] =~ /critical/x )  ) {
# if there are files&& those filesa re on the critical list.
		my $b_file=shift(@test_order);
		my $file_path=$janitor_dir.'/'.$biggest[0].'/'.$b_file;
		if ( $b_file =~ /critical/x ) {
		    my %fhash=%{$end_usage{$biggest[0]}};
		    #printf("  contents of %s set for transfer ( %4.2f%s ) \n",$file_path,$fhash{$b_file}/$disk_units{$unit},$unit);
		    printf("  ( %4.2f%s ) set for transfer  \n",$fhash{$b_file}/$disk_units{$unit},$unit);
		    $biggest[1]=$biggest[1]-$fhash{$b_file};
		    push(@remove_list,$file_path);
		    # remove summary, a hash with a hash per user of removed files and their sums.
		    ${$remove_summary{$biggest[0]}}{$b_file}=$fhash{$b_file};
		    delete ${$end_usage{$biggest[0]}}{$b_file};
		    $end_totals{$biggest[0]}=hash_sum($end_usage{$biggest[0]});
		}
	    } 
	    if ($#test_order<0)  { 
		printf("Ran out of test files\n");
		delete ${end_usage{$biggest[0]}};
		delete ${end_totals{$biggest[0]}};
		#sleep 5; 
	    }
	    if ( $biggest[1]/$second[1] <  1.3 ) {
		#printf(" %s\n",join(' ',@test_order));
		printf("Set new top user\n");
		sort_users(\@users,\@usage,\%end_totals);
		set_top_users(\@users,\@usage,\@biggest,\@second);
		#sleep 1; 
	    }
	    if ( $#users<=0 ) { 
		printf("\n\nCannot clean any more right now\n\n");
		$cleanable=0;
	    }
	    
	    #}
	} 
	

	#while ( $ending_size/$total_size > $disk_cleaning_threshold ) {
	#	$cleanable_size=hash_sum(\%end_totals);
	#}
    } else {
	printf("not worth cleaning\n");
    }

#
#
    #        for each interval file
    #            open file, add size to summary
    #            if file past critical move files to deep storage.
    #                save reversal commands on deepstorage device?
    # save user summary
    # save group summaryies
    return (%user_totals,%user_usage);
    return 0;

}

sub make_summary {
#my %user_totals=%{$_};
    #my (%user_totals,%user_usage)=@_;
    my ($min_pct,$hr)=@_;
    my %user_usage=%{$hr};
    my %user_totals=%{$user_usage{"TOTAL"}};
    printf("----------\n");
    printf("make_summary\n");
    printf("----------\n");
    my @users;
    my @usage;
    sort_users(\@users,\@usage,\%user_totals);

    my $used_size=$USEDKS*1024; # used disk space in bytes
    my $total_size=$TOTALKS*1024; # total disk space in bytes
    my $summary="";
    for my $d_name ( reverse @users ) { #keys(%user_usage)
	#$user_totals{$d_name}=hash_sum($user_usage{$d_name});
	if ( $d_name !~ /TOTAL/x ) {
	    if ( ($user_totals{$d_name}/$used_size*100) > $min_pct ) {# the primary summary is only for users taking up more than 5% of the used space.
		$summary=sprintf("%sUser %s Total ( %ib ), %0.2f%s's. pct of used : %0.2f. pct of total %0.2f.\n",
				 $summary,$d_name,$user_totals{$d_name},
				 ($user_totals{$d_name}/$disk_units{$unit}),$unit,
				 ($user_totals{$d_name}/$used_size*100),
				 ($user_totals{$d_name}/$total_size*100));
	    }
	}
    }

#    my $d_name="TOTAL";
    $summary=sprintf("%sTOTAL ( %ib ), %0.2f%s's. pct of used : %0.2f. pct of total %0.2f.\n",
		     $summary,hash_sum(\%user_totals),
		     (hash_sum(\%user_totals)/$disk_units{$unit}),$unit,
		     (hash_sum(\%user_totals)/$used_size*100),
		     (hash_sum(\%user_totals)/$total_size*100));
    return $summary;
}

sub queue_transfers {
    
    my ($janitor_dir,$usage_ref,%user_totals)=@_;
    my %user_usage=%{$usage_ref};
    %user_totals=%{$user_usage{"TOTAL"}};
    my @remove_list;     # list of files to have their contents transfered and removed.
    my %remove_summary;  # summary of how much data is being removed per user.

    my @users; # holding var for users sorted by disk space used low to high
    my @usage; # holding var for space used by users low to high(matching @users)
    my @biggest; # dumb array of username,usage for largest
    my @second;  # dumb array of username,useage for second largest


    # duplcate user_usage so we can play more later.
    #my %end_usage=%user_usage; # simple copy is just a reference copy!
    #use Storable qw(dclone); # intheory more complete than clone, but slower.
    #my %copy = %{ clone (\%hash) };
    use Clone qw(clone);
    #my %copy = %{ clone (\%hash) };
    my %end_usage=%{ clone ( \%user_usage) };
    # duplcaate user totals so we can play more later. 
    #my %end_totals=%user_totals; # simple copy is just a reference copy!
    my %end_totals=%{ clone ( \%user_totals) };
        
    my $used_size=$USEDKS*1024; # used disk space in bytes
    my $total_size=$TOTALKS*1024; # total disk space in bytes
    my $cleanable_size=hash_sum(\%end_totals);
    printf("Total cleanable %0.2f%s. pct of used : %0.2f. pct of total %0.2f.\n",
	   $cleanable_size/$disk_units{$unit},$unit,
	   $cleanable_size/$used_size*100,
	   $cleanable_size/$total_size*100);


    if ( $used_size/$total_size > $disk_safety_threshold) {
	printf("Disk cleaning engaged, used/total threshold exceeded.\n");
	#if (  $biggest[1]/$second[1]> 1.3 ) {
	    #printf("Bigest user is going to get cut.\n");
	    #my @remove_order=native_order_strings(keys(%{$user_usage{$biggest[0]}}));
	my $ending_size=$used_size;
	# process biggest user
	#
	my $reorder_users=1;
	@biggest=("",0);
	@second=("",1);
	my $cleanable=1;
	my @test_order=();
	do {
	    if ($reorder_users==1) {
		$reorder_users=0;
		sort_users(\@users,\@usage,\%end_totals);
		set_top_users(\@users,\@usage,\@biggest,\@second);
		printf("Next top two user ratio : %0.2f.  (%s/%s).\n",$biggest[1]/$second[1],$biggest[0],$second[0]);
		printf("  Remaining users: %s\n",join(" ",@users));
		#test order is a sorted list of file groups owned by the biggest user. It is sorted oldest to newest.
		@test_order=reverse sort by_number grep (/critical/, keys(%{$end_usage{$biggest[0]}}) );
		#@test_order=keys(%{$end_usage{$biggest[0]}});
	    }
	    
	    if ( $#test_order>=0 && ( $test_order[0] =~ /critical/x )  ) {
            # if there are files&& those files are critical list.
		my $b_file=shift(@test_order);
		my $file_path=$janitor_dir.'/'.$biggest[0].'/'.$b_file;
		if ( $b_file =~ /critical/x ) {#we're only looking at critical files so this is redundant.
		    my %fhash=%{$end_usage{$biggest[0]}}; # get the list of files for the biggest user.

		    $biggest[1]=$biggest[1]-$fhash{$b_file};  # take 
		    $ending_size=$fhash{$b_file};
		    push(@remove_list,$file_path);
		    # remove summary, a hash with a hash per user of removed files and their sums.
		    ${$remove_summary{$biggest[0]}}{$b_file}=$fhash{$b_file};
		    $end_totals{$biggest[0]}=hash_sum($end_usage{$biggest[0]});

		    delete ${$end_usage{$biggest[0]}}{$b_file};
		    printf("\tqueued %04.2f%s \n",${$remove_summary{$biggest[0]}}{$b_file}/$disk_units{$unit},$unit);
		    #printf("\t%s\n",$remove_list[$#remove_list]);
		    #printf("%0.2f.",$biggest[1]/$second[1]);
		    #sleep 1;
		}
	    } 
	    # if there are are no remaininf files, or the oldest remaining is a warning
	    if (@test_order==0 || ( $test_order[0] =~ /warning/x ) )  { 
		printf("\t$biggest[0] Ran out of old files.\n");
		delete ${end_usage{$biggest[0]}};
		delete ${end_totals{$biggest[0]}};
		#printf("  Remaining users: %s (TO trip)\n",join(" ",keys(%end_totals)));
		$reorder_users=1;
		#sleep 2; 
	    }
	    my $remaining=keys(%end_totals) ;
	    if ( $remaining<=0 ) { 
		printf("\n\nCannot clean any more right now\n\n");
		$cleanable=0;
	    }
	    if ( $biggest[1]<$second[1] ) {
		$reorder_users=1;
	    }
	    #$ending_size=hash_sum(\%end_totals);# only works when we process all
	} while ( $ending_size/$total_size > $disk_cleaning_threshold 
		  && $cleanable ) ;

	printf("Ending free space %0.2f%s. pct of used : %0.2f. pct of total %0.2f.\n",
	       $ending_size/$disk_units{$unit},$unit,
	       $ending_size/$used_size*100,
	       $ending_size/$total_size*100);
	#printf("Ending free space %0.2f ( \n", $ending_size/$total_size*100);
	sleep 2; 
	
	#while ( $ending_size/$total_size > $disk_cleaning_threshold ) {
	#	$cleanable_size=hash_sum(\%end_totals);
	#}
    } else {
	printf("not worth cleaning\n");
    }

    $remove_summary{"remove_list"}=[@remove_list];
    #printf("Transfer queue is %i files\n", $remove_summary{"remove_list"});
    
    #printf("Transfer queue is %i files\n", ($#remove_list+1));
    if ( 0 ) { 
	printf("origarray\n");
	for my $transfer_file (@remove_list) { #(@transfer_info{"remove_list"}) {
	    printf("\t queued $transfer_file \n");
	}
	printf("hash elemnarray\n");
	for my $transfer_file (@{$remove_summary{"remove_list"}}) { #(@transfer_info{"remove_list"}) {
	    printf("\t queued $transfer_file \n");
	}
    }
    return \%remove_summary;

}

sub sum_files {
# makes a sum of my file discovery files, or a sum of all file discovery files in a directory and returns a hash ref. 
    my ($input,$pattern)=@_;
    if ( ! defined $pattern ) {
	$pattern=".*";
    }
    
    if ( defined $input && $input ne "" && -d $input ) {
	my %sum;
	opendir(my $DIR, "$input") or die $!;
	while (my $e_name = readdir($DIR) ) {
	    if ( $e_name !~ /^[.]+$/ && $e_name =~ /$pattern/ ) {
		#printf("  Check file $e_name\n");
		#$sum=$sum+sum_files($input.'/'.$e_name);
		$sum{$e_name}=sum_files($input.'/'.$e_name);
	    }
	}
	closedir($DIR);
	return \%sum;
    } elsif ( defined $input && $input ne "" && -f $input )  {
	my $sum=0;
	open ( my $FILE,  '<', "$input") or die $!;	
	while (my $entry = readline($FILE) ) {
	    chomp($entry);
	    #my ($size,$path) =(0,"/testfile.txt");#= split('|',$_);
	    my ($size,$path) = split('\|',$entry);
	    if (! defined $path ) {
		$path=$size;
		#$size=stat($path)->$size;
		$size= -s $path || 0 ;
	    }
	    #printf("    add file $path\n");
	    $sum=$sum+$size;
	}
	close( $FILE);
	return $sum;
    } else {
	printf(" summation problem\n");
	return 0 ; 
    }
}

sub hash_sum {
# sum up the values of a hash and return the sum(via reference). 
    my $hr;
    my %hash;
    ($hr)=@_;
    %hash=%{$hr};	
    my $sum=0;
    #print("debug:$debug_val\n");
    for my $file (keys %hash) {
	printf($file."\n") if $debug_val >90;
	$sum=$sum+$hash{$file};
    }
    return $sum;
}

# function never finished, by_number does the job.
sub native_order_strings {
    # takes a list of strings and puts them in a native order.. eg 
    # test_1 test_10 test_2 test_3 test_4 test_5 test_6 test_7 test_8 test_9
    # becomesp
    # test_1 test_2 test_3 test_4 test_5 test_6 test_7 test_8 test_9 test_10
    my @strings=@_;
    my @comp_strings;
    my @comp_numbers;

    for my $string (@strings) {
	my ($string,$num) = $string =~ /^([a-zA-Z_]*)([0-9]*)$/x;
	push(@comp_strings,$string);
	push(@comp_numbers,$num);
    }
    #foreach my $name (sort { $user_totals{$a} <=> $user_totals{$b} } keys %user_totals) {

#	push(@users,$name);
#	push(@usage,$user_totals{$name});
 #   }
#    return sort({$b cmp $a} );
    return ();
}

# sorts mixed strings eg, blablabla3 blablabla1 blablabla2 
# shamelessly ripped from 
# http://perlmaven.com/sorting-mixed-strings
# usage  my @sorted = sort by_number @unsorted;
sub by_number {
    my ( $anum ) = $a =~ /(\d+)/;
    my ( $bnum ) = $b =~ /(\d+)/;
    ( $anum || 0 ) <=> ( $bnum || 0 );
}

sub sort_users {
    #my (@user,@usage,%user_totals)=@_
    
    my ($user_ref,$usage_ref,$summary_ref)=@_;
    @{$user_ref} =();
    @{$usage_ref}=();
    foreach my $name (sort { ${$summary_ref}{$a} <=> ${$summary_ref}{$b} } keys %{$summary_ref}) {
	#printf "%-8s %s\n", $name, ${$summary_ref}{$name};
	push(@{$user_ref},$name);
	push(@{$usage_ref},${$summary_ref}{$name});
	# if ( 0 ) {
	# if (! defined $biggest[0] ) {
	#     printf("No biggest now $name\n");
	#     @biggest=($name,${$summary_ref}{$name});
	#     #@second=@biggest;
	# } elsif ( $biggest[1]<${$summary_ref}{$name} ) {
	    
	#     #$second[0]=$biggest[0];	    $second[1]=$biggest[1];
	#     @second=@biggest;
	#     @biggest=($name,${$summary_ref}{$name});
	#     printf("New biggest $biggest[0], second $second[0]\n");
	# } elsif( $second[1]<${$summary_ref}{$name} ) {
	#     printf("New second $name\n");
	#     @second=($name,${$summary_ref}{$name});
	# }
	# }
    }
    return;
}
sub set_top_users {

    my ($user_ref,$usage_ref,$big_ref,$sec_ref)=@_;

    @{$big_ref}=(${$user_ref}[$#{$user_ref}],${$usage_ref}[$#{$usage_ref}]);
    if ($#{$user_ref} > 0 ) {
	@{$sec_ref}=(${$user_ref}[$#{$user_ref}-1],${$usage_ref}[$#{$usage_ref}-1]);
    } else {
	@{$sec_ref}=("LAST_USER",1);
    }
    #printf("Biggest user is %s at %0.2f$unit\n",${$big_ref}[0],${$big_ref}[1]/$disk_units{$unit},$unit);
    #printf("Second biggest user is %s at %0.2f$unit\n",${$sec_ref}[0],${$sec_ref}[1]/$disk_units{$unit},$unit);


}



sub transfer_user_data {
    my ($elimination_queue,$t_ref)=@_;
    my %transfer_info=%{$t_ref};
    
#    my @remove_list=$transfer_info{"remove_list"};
    #nmy @remove_list=@transfer_info{"remove_list"};
    
    #for my $transfer_file (@remove_list) { #(@transfer_info{"remove_list"}) {
    printf("Transfer queue is %i files\n", ( $#{$transfer_info{"remove_list"}}+1));
    sleep 1;
    for my $transfer_file (@{$transfer_info{"remove_list"}}) {
	printf("moving contents of $transfer_file \n");
	if ( ! -e $transfer_file) { 
	    printf("bad file name\n");
	} else {
	#my($p,$n,$e)=fileparts($transfer_file);
	my ($n,$p,$e) = fileparse($transfer_file,qr/\.[^.]*$/);
	my $u=basename($p);
	my $status_file= $elimination_queue."/".$u.$n."_transfered".$e;

	#printf("Looking up filesize with %s, %s\n", $u, $n.$e);
	my $s=${$transfer_info{$u}}{$n.$e};
	if ( defined $s ) {
	    #my $status=transfer_data_group($u,$s,$transfer_file,$status_file);
	    my $status=1;
	    printf("( %0.2f%s ) ",$s/$disk_units{$unit},$unit);
	    if ( $status ) {
		printf("  transfer sucess!\n");
		delete ${$transfer_info{$u}}{$transfer_file};
	    } else { 
		printf("  transfer failed??!?!\n");
	    }
	} else {
	    printf("\n\tCannot transfer %s/%s%s because cannot find details.\n",$p,$n,$e);
	}
	}
    }
    
    
    return 0;
}

sub transfer_data_group {
    my ($u,$s,$input,$output) =@_;
    my $sum=0;
    if ( ! defined $output ) {
	my ($p,$n,$e) = fileparse($input,qr/\.[^.]*$/);	
	$output=$p.$u.$n."_transfer".$e;
    }
	
    my ($rname,$rhost,$rdest)=@{$user_definitions{$u}};
    #my ($rname,$rhost,$rdest)=$user_definitions{$u};
    
    #$rname,$rhost,$rdest,
    my $ossh = Net::OpenSSH->new($rhost, user => $rname);
    my %ssh_opts=(
	copy_attrs => 1 );
    $ossh->error and warn "Couldnt establish SSH Connection: ". $ossh->error and return 0;
    my $scp_start=remote_check_free($s,$rdest,$ossh);
    if ( ! $scp_start) {
	printf("Not enough space on %s for user %s at path %s .\n",$rhost,$rname,$rdest);
	sleep 1;
	return 0 ;
    } elsif(1) {
	open ( my $FILE,  '<', "$input") or die $!;
	open ( my $OFILE,  '>', "$output") or die $!;
	while (my $entry = readline($FILE) ) {
	    chomp($entry);
	    #my ($size,$path) =(0,"/testfile.txt");#= split('|',$_);
	    my ($size,$path) = split('\|',$entry);
	    if (! defined $path ) {
		$path=$size;
		#$size=stat($path)->$size;
		$size= -s $path || 0 ;
	    }
	    my $d_path=$rdest."/Storage_janitor/".$path;
	    #printf("    add file $path\n");
	    $sum=$sum+$size;
	    #if ( remote_check_free($rname,$rhost,$rdest,$size,$ossh) ) {
	    if ( remote_check_free($size,$rdest,$ossh) ) {
		my $r_dir=dirname($d_path);
		my $status=0;
		my @capture=$ossh->capture("mkdir -p $r_dir") and $status=1;
		if (! $status ) {
		    printf("%s",join(' ',@capture)); 
		    warn "ssh mkdir issue: " . $ossh->error;  } 
		#printf("scp $path $rname\@$rhost:$d_path\n");
		$status=0;
		$ossh->scp_put(\%ssh_opts,"$path", "$d_path") and $status=1 ;
		if ( $status ) {
		    #printf $OFILE ("scp -p %s %s@%s:%s/%s \n",$path,$rname,$rhost,$rdest,$path)
		    printf $OFILE ("%s\|%s\|%s\n",$size,$d_path,$path);

		} else { 
		    warn "scp failed: " . $ossh->error;  } 
	    }
	    
	}
	close( $FILE);
	#close( $OFILE);
    } else {
    }
    return 1;
}
#
sub notify_users {
    # for each user
    my ($out_dir,$summary_txt,$t_ref)=@_;
    
    #my %user_usage=%{$hr};
    #my %user_totals=%{$user_usage{"TOTAL"}};
    
    my %transfer_info=%{$t_ref};
    my $used_size=$USEDKS*1024; # used disk space in bytes
    my $total_size=$TOTALKS*1024; # total disk space in bytes
    $out_dir="/tmp/";
    my %out_hash; # a hash of open fileid's in theory we can have a lot of open file identifiers. 
    printf("Notify Users\n");
    for my $d_name ( keys(%transfer_info) ) {
	if ( $d_name !~ /remove_list/x ) {
	    printf("Preparing email to %s.\n",$d_name);
	    my $out_file=sprintf("%s/disk_info_%s.txt",$out_dir,$d_name);
	    my $c_fh=-1;
	    if ( ! defined ($out_hash{"$d_name"} ) ) {
		open ( $out_hash{"$d_name"},  '>', "$out_file") or die "Cannot open $out_file.  ".$!;
		$c_fh=$out_hash{"$d_name"};
	    } elsif (defined $out_hash{"$d_name"}) {
		$c_fh=$out_hash{"$d_name"};
	    }
	    #open ( $out_hash{"$user$interval"},  '>', "$out_file") or die "Cannot open $out_file.";
	    #moving files 
	    my @tfiles=reverse sort by_number keys(%{$transfer_info{$d_name}});
	    printf $c_fh ( "%s %s is nearly full! \n"
			   ."%s\n"
			   ."moving contents of files: %s\n",
			   $d_name,$SCAN_DIR,$summary_txt, join("\n\t",@tfiles) ) ;
	    
	    #use diagnostics;
	    #print ${out_hash{$d_name}} ($txt) unless ! defined ($out_hash{$d_name} );


	}
    }

    foreach (keys %out_hash) {
	print("Closing file $_\n");
	close $out_hash{"$_"};
    }
    for my $d_name ( keys(%transfer_info) ) {
	if ( $d_name !~ /remove_list/x ) {
	#"$user$interval"
	my $out_file=sprintf("%s/disk_info_%s.txt",$out_dir,$d_name);
	my $email_address=sprintf("%s\@duke.edu",$d_name);
	my $subject=sprintf( "%s_%s",$HOST,$SCAN_DIR);
	printf "mail:$email_address:$subject:$out_file\n";
	#mail $email_address $subject $out_file 
	}
    }
    return ;
}

sub process_elimination_queue { 
    my ($elimination_queue) =@_;
	
    my $max_eliminations=5;

    # cycle the elimination dirs
    for(my $elim=$max_eliminations;$elim>0; $elim--) {
	my $cur = $elimination_queue."_".$elim;
	my $nxt = $elimination_queue."_".($elim+1);
	if ( -d $cur ) { 
	    move $cur,$nxt;
	}
    }

    # remove any elimination dirs over max
    my $found=$max_eliminations+1;
    while ( -d $elimination_queue."_".$found ) {
	hunt_and_kill_remote($elimination_queue."_".$found);
	$found++;
    }
    return; 
}

sub hunt_and_kill_remote {
    my ($filedir)=@_;
    print("Killing remote files in $filedir\n");
    return;
}
sub remote_check_free {
#    my ($rn,$rh,$rd,$s)=@_;
    #my $ssh = NET::OpenSSH->new($rh);

    #my ($user,$host,$remote_path,$size)=@_;

    my ($size,$remote_path,$ssh)=@_;
    my $remote_cmd="df -hk $remote_path ".'| grep -oP \'.* \K\d+(?=\s+\d+%)\' ';
    my @output=$ssh->capture($remote_cmd);
    if ($#output>0 ) {
	printf("WARNING: multiple remote locations found.\n");
    }
    my $remote_free=$output[0]*1024;
    if ( $remote_free>$size ) {
	return 1;
    }
    printf("%s\n",join(" ",@output));
    printf("%i matches",($#output+1));
    sleep 6;

    return 0;
}

sub main {
    my ($inputs)=@_;
    my $min_pct=5;
    my $out_dir=$SCAN_DIR."/Storage_janitor";
    my $elimination_queue=$out_dir."/Elimination";
    #my $files_found=file_discovery($SCAN_DIR,$out_dir);
    print("files $files_found found at least $test_age days old\n");
    #my $summary_ref = summarize_data($out_dir);# while testing use jjc29|hw|luc
    #my $summary_ref = summarize_data($out_dir,'jjc29|hw|luc|abade');# while testing use jjc29|hw|luc
    my $summary_ref = summarize_data($out_dir,'jjc29');# while testing use jjc29|hw|luc
    
    my $summary_txt=make_summary($min_pct,$summary_ref);# this is more for the cronjob output to lucy and james.
    print("\n".$summary_txt);
    #sleep 2;
    my $transfer_info_ref = queue_transfers($out_dir,$summary_ref);
    #sleep 2;
    # NOTIFIY USERS!!!!!
    #notify_users($summary_ref);
    notify_users($out_dir,$summary_txt,$transfer_info_ref);
    #sleep 2;

    my $status = transfer_user_data($elimination_queue,$transfer_info_ref);
    #sleep 2;
    process_elimination_queue($elimination_queue);

    print("storage janitor complete!");
}


###############
# MAIN RUNS HERE .
###############
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
