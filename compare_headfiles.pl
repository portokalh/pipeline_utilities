#!/usr/bin/perl
# compare_headfile.pl 
# script to write bunch of headfiles together as csv file.
# displays output to terminal ommitting fields with the same value.

use strict;
use warnings;
use Env qw(RADISH_PERL_LIB BIGGUS_DISKUS);# RADISH_RECON_DIR WORKSTATION_HOME WKS_SETTINGS RECON_HOSTNAME WORKSTATION_HOSTNAME); # root of radish pip
use Getopt::Std;
use List::Uniq ':all';
use lib split(':',$RADISH_PERL_LIB);
use civm_simple_util qw(write_array_to_file );
require Headfile;



#<<<<<<< HEAD
my %opt;
if (! getopts('c:o:p:t:', \%opt)) {
    error('Options not understood, expecting nothing, OR -c project_code -o output_csv -p base_path -t template_headfile');
}
my $base_path="$BIGGUS_DISKUS";
my $output_path="NO_OUTPUT";
my $project_code="00.QA.00";
my $template_path="NO_TEMPLATE";
if ( defined $opt{'c'} ) {
    $project_code=$opt{'c'};
}
if ( defined $opt{'o'} ) {
    $output_path=$opt{'o'};
}
if ( defined $opt{'p'} ) {
    $base_path=$opt{'p'};
}
if ( defined $opt{'t'} ) {
    $template_path=$opt{'t'};
}

my @headfile_paths=(); # array of headfile paths
my @hfs=(); # array of headfiles
#=======#>>>>>>> 96f21654430e44f2fa9cb3fa8a2c8198f8a733a1
my @runnos=();
my $field_width=8;
my @keys=();
my @hf_errors=();

#<<<<<<< HEAD
while(my $in_bit = shift(@ARGV) ){
    if ( $in_bit =~ /\/.*\.headfile/) {
	# try to use as headfilepaths
	
	my $hf_path=$in_bit;
	if ( -f $hf_path ) {
	    push(@headfile_paths,$hf_path);
	} else { 
	    push(@hf_errors,"didnt find headfile, $in_bit\n");
	}
    } elsif ( $in_bit =~ /.*\.headfile/) {
	# try to use as headfile name
	my @run_def=split('\.',$in_bit);
	my $run=$run_def[0];
	my $image_folder=sprintf("%s/%s/%simages",$base_path,$run,$run);
	if ( ! -d $image_folder ) {
	    $image_folder=sprintf("%s/%s/%s",$base_path,$project_code,$run);
	}
	my $hf_path=sprintf("%s/%s.headfile",$image_folder,$run);
	if ( -f $hf_path ) {
	    push(@headfile_paths,$hf_path);
	} else { 
	    push(@hf_errors,"didnt find headfile, $in_bit\n");
	}
    } elsif( $in_bit !~/.{5,}-.{5,}/)  { 
	# try out single runno
	my $run=$in_bit;
	my $image_folder=sprintf("%s/%s/%simages",$base_path,$run,$run);
	if ( ! -d $image_folder ) {
	    $image_folder=sprintf("%s/%s/%s",$base_path,$project_code,$run);
	}
	my $hf_path=sprintf("%s/%s.headfile",$image_folder,$run);
	if ( -f $hf_path ) {
	    push(@headfile_paths,$hf_path);
	} else { 
	    push(@hf_errors,"dont know what to do with this runformat, $run\n");
	}
#=======#>>>>>>> 96f21654430e44f2fa9cb3fa8a2c8198f8a733a1
    } else {
	# presume a dash separted range.
	my @run_def=split('-',$in_bit);
	if( $#run_def!=1){
	    push(@hf_errors,"dont know what to do with this runformat, $in_bit\n");
	} else {
	    # lets assume run_def are a dash list for now. find headfile with local path, or with archivepath.
	    my $r_width=length $run_def[0];
	    my $scanner_letter=substr($run_def[0],0,1);
	    for( my $num=substr($run_def[0],1);$num<substr($run_def[1],1);$num++){
		my $run=sprintf("%s%0".($r_width-1)."i",$scanner_letter,$num);
		my $image_folder=sprintf("%s/%s/%simages",$base_path,$run,$run);
		if ( ! -d $image_folder ) {
		    $image_folder=sprintf("%s/%s/%s",$base_path,$project_code,$run);
		}
		my $hf_path=sprintf("%s/%s.headfile",$image_folder,$run);
		if ( -f $hf_path ) {
		    push(@headfile_paths,$hf_path);
		    #push(@runnos,sprintf("%".$field_width."s",$run)); # runno as opened
		} else {
		    push(@hf_errors,"No headfile for $run.\n");
		}
	    }
	}
    }
}
    

#read in all headfiles found.
if ( $#headfile_paths>=0 ){
    printf("Loading ");
}
foreach my $hf_path (sort @headfile_paths) {
    printf("%s ",$hf_path);
    push(@hfs,new Headfile ('ro', $hf_path));
    $hfs[$#hfs]->check() or push(@hf_errors,"Unable to open $hf_path\n");
    $hfs[$#hfs]->read_headfile or push(@hf_errors,"Unable to read $hf_path\n");
    push(@runnos,$hfs[$#hfs]->get_value_like('._runno')); # runno as read back.
    #push(@runnos,sprintf("%".$field_width."s",$run)); # runno as opened
    push(@keys,$hfs[$#hfs]->get_keys());
}
if ( $#headfile_paths>=0 ){
    printf("\t<--- done\n\n");
}

@keys=sort(uniq( @keys));
my $template = new Headfile ('ro',$template_path);
if ( -f $template_path ) {
    $template->check() or unshift(@hf_errors,"Unable to open template,  $template_path.\n");
    $template->read_headfile or unshift(@hf_errors,"Unable to read template, $template_path.\n");
    @keys=$template->get_keys();
} else {
    unshift(@hf_errors,"Unable to find template, $template_path.\n") unless ( $template_path=~/NO_TEMPLATE/ );
}

if ($#hf_errors>0) 
{
    #print("Error_dump$#hf_errors\n");
    printf(join('',@hf_errors));
    sleep 4;
}
my @out_array=();# array of output lines 
#printf("%".$field_width."s = %s\n","Runnos",join(", ",@runnos));
my $print_format="%".$field_width."s";
printf($print_format." = %s\n","Runnos",sprintf(($print_format.', ') x @runnos,@runnos));
push(@out_array,sprintf("%s\t%s\n","Runnos",join("\t",@runnos)));
foreach my $key(@keys){
    my @vals=();
    my @vals_full=();
    my $val='';
    my $first_val;
    for(my $hn=0;$hn<=$#hfs;$hn++){
	$val=$hfs[$hn]->get_value($key);
	if($output_path !~/NO_OUTPUT/){
	    push(@vals_full,$val);
	}
	if ( defined $first_val) {
	    if ($val eq $first_val ) {
		$val='<---';
	    } 
	} else {
	    $first_val=$val;
	}
	push(@vals,sprintf($print_format,substr($val,0,$field_width)));
    }
    # cleaning the keys a bit, for scanner keys, remove z_scanner from the key
    if ( -f $template ) { # if we have a template, use it for key replacement.
	$key=$template->get_value($key);
    }
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
	if($output_path !~/NO_OUTPUT/){
	    push(@out_array,sprintf("%s\t%s\n",$key,join("\t",@vals_full)));
	}
	printf($print_format." = %s\n",substr($key,0,$field_width),sprintf(($print_format.', ') x @vals,@vals));
    }
}
write_array_to_file($output_path,\@out_array);
