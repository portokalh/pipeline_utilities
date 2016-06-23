#!/usr/bin/perl


use strict;
use warnings;
use Env qw(RADISH_PERL_LIB);# RADISH_RECON_DIR WORKSTATION_HOME WKS_SETTINGS RECON_HOSTNAME WORKSTATION_HOSTNAME); # root of radish pip
 
use lib split(':',$RADISH_PERL_LIB);
require Headfile;

my $archive_path="/Volumes/atlas2";

my @list=();


    
my $project_code=shift(@ARGV);


my @hfs=();
my @runnos=();
my $field_width=8;

if ($#ARGV>0) { 
#    try to use as headfilepaths
    
    for my $headfile (@ARGV) {
	if ( -f $headfile ) {
	    printf("%s\n",$headfile);
	    push(@hfs,new Headfile ('ro', $headfile));
	    $hfs[$#hfs]->check() or error_out("Unable to open $headfile\n");
	    $hfs[$#hfs]->read_headfile or error_out("Unable to read $headfile\n");
	    push(@runnos,$hfs[$#hfs]->get_value('U_runno'));#sprintf("%".$field_width."s",$run));
	} else {
	    die ("dont know what to dowith this runformat");
	}

    }
} else {

    
    my @run_def=split('-',shift(@ARGV));
    if( $#run_def!=1){
	die ("dont know what to dowith this runformat");
    } else {
	# lets assume run_def are a dash list for now.
	my $r_width=length $run_def[0];
	
	#substr($run_def[0],1);$num<substr($run_def[1],1)
	for( my $num=substr($run_def[0],1);$num<substr($run_def[1],1);$num++){
	    my $run=sprintf("W%0".($r_width-1)."i",$num);
	    
	    my $image_folder=sprintf("%s/%s/%s",$archive_path,$project_code,$run);
	    my $headfile=sprintf("%s/%s.headfile",$image_folder,$run);
	    
	    if ( -f $headfile ) {
		printf("%s\n",$headfile);
		push(@runnos,sprintf("%".$field_width."s",$run));
		push(@hfs,new Headfile ('ro', $headfile));
		$hfs[$#hfs]->check() or error_out("Unable to open $headfile\n");
		$hfs[$#hfs]->read_headfile or error_out("Unable to read $headfile\n");
		
	    } else {
		printf("no run %s\n",$run);
	    }
	    
	}
    }
}
my @keys=$hfs[0]->get_keys();
#printf("%8s = %s\n","Runnos",join(", ",@runnos));
printf("%".$field_width."s = %s\n","Runnos",join(", ",@runnos));
foreach my $key(@keys){
    my @vals=();
    my $val='';
    my $first_val;
    for(my $hn=0;$hn<=$#hfs;$hn++){
	$val=$hfs[$hn]->get_value($key);
	if ( defined $first_val) {
	    if ($val eq $first_val ) {
		$val='';
	    } 
	} else {
	    $first_val=$val;
	}

	push(@vals,sprintf("%".$field_width."s",substr($val,0,$field_width)));
    }
    # cleaning the keys a bit, for scanner keys, remove z_scanner from the key
    if(  $key =~ /z_.*/x ) {
	($key)=$key=~/z_[^_]+_(.*)/x;
	# further cleaning for bruker bits, remove acq_ and pvm_
	if ($key =~ /ACQ_.*/x ) { 
	    ($key)=$key=~/ACQ_(.*)/x;
	}elsif ($key =~ /PVM_.*/x ) { 
	    ($key)=$key=~/PVM_(.*)/x;
	}
    }
    if( 1
	#&& ( $key !~ /z_.*/x ) 
	&& ( $key !~ /rad_mat_.*/x ) 
	&& ( $key !~ /scanner_.*/x ) 
	&& ( $key !~ /engine_.*/x ) ){
	printf("%".$field_width."s = %s\n",substr($key,0,$field_width),join(", ",@vals));
    }
}
