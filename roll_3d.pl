#!/usr/bin/perl
#  simplish script to roll and restack image directories. 
#  takes a run number, (hopefulyl understaning channel runnos and _m series and combinations of those)
# 
#
#

#my $PROGRAM_NAME = "radish.pl";
#my $VERSION_DATE = "140115";

# to check command line parameter indicating dasource:
#my @KNOWN_SCANNERS = ("onnes","kamy","heike","lx-ron1");
#my $PULL_NEWEST_PFILE = '+'; # pfile name place holder on cmd line to map to newest on scanner	
use strict;
use warnings;

my $GOODEXIT = 0;
my $BADEXIT = 1;
my $ERROR_EXIT = $BADEXIT;
#my $ARCHIVE_TAG = 1;   # select write of archive_tag file (READY_) used by CIVM archive 
#my $READY_ARCHIVE_TAG = "READY_";  # name of file ready to be chosen for archive 
#my $skip_gui_boolean = 0; # if 1 engage test mode and skip gui
#my $gCIVMID ='';
# ENV var is used to indicate where radish recon code is located 
#   e.g. like "/recon_home/script/dir_radish"
use Env qw(WORKSTATION_HOME);
if (! defined($WORKSTATION_HOME)) {
    print STDERR "Environment variable WORKSTATION_HOME must be set. Are you user omega?\n";
    print STDERR "   CIVM HINT setenv WORKSTATION_HOME /recon_home/script/dir_radish\n";
    print STDERR "Bye.\n";
    exit $ERROR_EXIT;
}
#use lib "$WORKSTATION_HOME/modules/script";
use Cwd qw(abs_path);
use File::Basename;
use lib dirname(abs_path($0));


use File::Basename;
use lib dirname(abs_path($0));
use Env qw(RADISH_PERL_LIB WORKSTATION_HOSTNAME WKS_SETTINGS);
if (! defined($RADISH_PERL_LIB)) {
    print STDERR "Cannot find good perl directories, quiting\n";
    exit $ERROR_EXIT;
}
use lib split(':',$RADISH_PERL_LIB);

use Getopt::Std;
use File::Path;
use File::Spec;
use English;
use civm_simple_util qw(printd $debug_val);
use pipeline_utilities qw($HfResult);
$debug_val=100;

#use shared;
require Headfile;

if (! defined($WORKSTATION_HOSTNAME)) {
    print STDERR "Environment variable WORKSTATION_HOSTNAME must be set.";
    exit $ERROR_EXIT;
}


#   my $engine_constants_dir = "$PIPELINE_HOME/dependencies";
#   if (! -d $engine_constants_dir) {
#       $engine_constants_dir = "$WKS_SETTINGS/engine_deps/";
#   }
#   if (! -d $engine_constants_dir) {
#       error_out ("$engine_constants_dir does not exist.");
#   }
#   my $engine_file ;
#   my $engine_constants_path = "$engine_constants_dir/".join("_","engine","$PIPELINE_HOSTNAME","pipeline_dependencies");
#   if ( ! -f $engine_constants_path ) { 
#       $engine_constants_path = "$engine_constants_dir/".join("_","engine","$PIPELINE_HOSTNAME","dependencies"); 
#   }

###
# handle engine consts
##
my $engine_const_name = join("_","engine","$WORKSTATION_HOSTNAME","dependencies");
my $engine_const_dir  = join("/",$WKS_SETTINGS,'engine_deps' ); #$engine_const_name
my $EC = new Headfile ('ro', $engine_const_dir.'/'.$engine_const_name);
my @error_m=("Unable to "," engine constants file at $engine_const_dir.'/'.$engine_const_name\n");
if (! $EC->check()) { error_out(join("open",@error_m)); } 
if (! $EC->read_headfile) { error_out(join("read",@error_m)); }




###
# main 
###
#    if (! getopts('abc:d:ek:op:r:s:tu:', \%options)) {
my %opts=  (
    'x' => 0,
    'y' => 0,
    'z' => 0 );
printd(0, "Roll_3d Calls roller_radish and restack_radish on your behalf with your specifed xyz corner information. \n".
       "This information is then added to your headfile and it looks up tag files to give a proper archivme prompt.\n".
       "Usage: roll_3d [-x #] [-y #] [-z #] RUNNUMBER1 RUNNUMBER2... RUNNUMBERN\n".
       "Valid options are \n\t-x $opts{'x'} \n\t-y $opts{'y'} \n\t-z $opts{'z'}\n");
if( ! getopts('x:y:z:',\%opts)) {
    printd(0,	   "ERROR: bad options specified,\n");
    exit $ERROR_EXIT;
} else { 
    printd (0, "proceeding to adding roll[channel]_(corner/first)_(xyz) keys to each headfile processed\n");
}

my $dims=0;
for my $dim ( qw (x y z) ) {
    if (  $opts{$dim} !=0 ) {
	$dims++;
	printd(45,"$dim -> $opts{$dim}\n");
    } else {
    }
}
if ( $dims==0 ) { 
    error_out("No need to restack/roll with 0 rolling values");
} else { 
    printd(5,"rolling in $dims dims\n");
}
    
#if ($#ARGV+1 < 3) { usage_message("Wrong number of arguments on command line");}
my @runnos=@ARGV;
printd(25, "INFO: Processing run numbers: ".join(" ",@runnos)."\n");

my $cmd='';
@error_m=("Unable to "," headfile ");
my @missing_runnos;
my @found_runnos;
my $civm_id='';
###
# check headfiles exist and make al list of present and non-present hf's
###
for my $runno (@runnos) {
    #find headfile.
    my $r_base_path = $EC->get_value('engine_work_directory').'/'.$runno.'/';
    my ($hfpath,$stat)=`find $r_base_path -iname \"$runno.headfile\"`;
    if ( !defined $hfpath) {
#	print("no hf $runno\n");
	push( @missing_runnos,"$runno");
    } else { 
	push (@found_runnos,"$runno");
    }
}
if ($#found_runnos>=0) { 
    my $stat_m="Found hf ";
    printd(0,$stat_m.join("\n".$stat_m,@found_runnos)."\n");
}
if ($#missing_runnos>=0) {
    my $err=join ("find",@error_m);
    printd(0,$err.join("\n".$err,@missing_runnos)."\n");
    exit $BADEXIT;
}

###
# proceed to do work.
###
my @rm_paths;
my %taglist;
my $find_tags=1;
for my $runno (@runnos) {
    printd(5,"#---$runno\n");
    #find headfile.
    my $r_base_path = $EC->get_value('engine_work_directory').'/'.$runno;
    my ($hfpath,$stat)=`find $r_base_path -iname \"$runno.headfile\" | grep -vE '(last|orig)'`;
    chomp $hfpath;
    my $HF= new Headfile ( 'rw',$hfpath);
    if (! $HF->check()) { error_out(join("open",@error_m).' '.$hfpath."\n"); } 
    if (! $HF->read_headfile) { error_out(join("read",@error_m).' '.$hfpath."\n"); }
    $civm_id=$HF->get_value("U_civmid");
    $HF->set_value("roll_corner_X",$opts{'x'});
    $HF->set_value("roll_corner_Y",$opts{'y'});
    $HF->set_value("roll_first_Z",$opts{'z'});
    my ($name,$hfdir,$suffix)=fileparts($hfpath);    
    my $tc=$HF->get_value("scanner_tesla_image_code");
    my $ic=$HF->get_value("output_image_code");
    if ($ic !~ /NO_KEY/x) {
	$tc=$ic; # hack to fix US images not showing correcltly.
    }
    if ( $find_tags) {
	$cmd="grep $runno ".$EC->get_value("engine_work_directory")."/Archive_tags/* | cut -d ':' -f1";
	printd(35,"find_tags using $cmd\n");
	my $tag_file=`$cmd`;
	chomp $tag_file;
	if ( defined $tag_file ) { 
	    my ($n,$p,$ext)=fileparts($tag_file);
	    $n=$ext;
	    printd(75,"path $p: name $n: \n");
	    my @np=split('_',$n);
	    printd(45,'filename bits are '.join(':',@np)."\n");
	    my $tag_type=shift @np;
	    $tag_file=join('_',@np);
	    if ( ! defined ($taglist{$tag_file}) ){
		$taglist{$tag_file}=1;
	    } else {
		$taglist{$tag_file}++;
	    }
	} else { 
	    printd(0,"WARNING: No tag file found for scan $runno\n");
	}
    }
    if ( -e "${hfdir}orig" ) {
	printd(5,"Duplicate roll run called, checking for original images in orig folder to roll those instead\n");
	$cmd="mkdir -p ${hfdir}last";
	if ( ! -e "${hfdir}last") {
	    `$cmd`;
	} else {
	    #`rm -fr ${hfdir}last`;
	    printd(5,"WARNING: Re-run multiple times, behavior uncertain!\n");
	    `$cmd`;
	    $cmd="cp ${hfpath} ${hfdir}last/.";
	    `$cmd`;
	}
	$cmd="mv ${hfdir}orig/* ${hfdir}last/.";
	printd(45,"$cmd\n");
	`$cmd`;
	$cmd="mv ${hfdir}/*.raw ${hfdir}last/.";
	printd(45,"$cmd\n");
	`$cmd`;

	$cmd="mv ${hfdir}/last/$runno${tc}imx.*.raw ${hfdir}";
	printd(45,"$cmd\n");
	`$cmd`;
	if ( ! -e "$hfdir".$runno.$tc."imx.0001.raw") {
	    printd(15,"Moving original out of way\n");
	    $cmd="mv -f $hfdir"."last/".$runno.$tc."*.*.raw ${hfdir}/.";
	    `$cmd`;
	}
    }
    my ($st,$img_suffix,@erros)=get_image_suffix($hfdir,$runno);
    if ( ! -e "$hfdir".$runno.$tc."imx.0001.raw") {
	printd(5,"image code did not follow standard, had to set to $img_suffix\n");
	$HF->set_value("output_image_code",$img_suffix);
	$tc=$img_suffix;
    } 

    if ( $opts{'x'} > 0 || $opts{'y'} > 0 ) { 
	$cmd='roller_radish '.$runno.' '.$opts{'x'}.' '.$opts{'y'};
	printd (15, $cmd."\n");
	`$cmd`;

	$cmd="mkdir -p ${hfdir}orig";
	if ( ! -e "${hfdir}orig" ) { 
	    `$cmd`;
	}
	if ( -e "$hfdir".$runno.$tc."imx.0001.raw") {
	    printd(15,"Moving original out of way\n");
	    $cmd="mv -f $hfdir".$runno.$tc."*.*.raw ${hfdir}orig/.";
	    `$cmd`;
	} elsif ( -e "$hfdir".$runno."rsimx.0001.raw") {
	    printd(15,"Moving rolled out of way\n");
	    $cmd="mv -f $hfdir".$runno."rs*.*.raw ${hfdir}orig/.";
	    `$cmd`;
	} else {
	    printd(45,"no \n\t$hfdir".$runno.$tc."imx.0001.raw or \n\t$hfdir".$runno."rsimx.0001.raw\n");
	}
    }
    my $dim_z=$HF->get_value("dim_Z");
    if ($HF->get_value("RH_xres") ne 'NO_KEY' ) {
	$dim_z=$HF->get_value("RH_zres");
    }
    if ( $dim_z eq 'NO_KEY' || $dim_z<=1) {
	if ( $opts{'z'} > 0 ) {
	    printd(0,"WARNING: NO_Z Ignoring z rolls. YOU ASKED FOR a z Roll of $opts{'z'} ");
	    if ( $dim_z eq 'NO_KEY' )  {
		printd(0,"BUT CANNOT PULL dim_Z|RH_Zres FROM HEADFILE $hfpath\n");
	    } else {
		printd(0,"BUT Z is <=1 IN HEADFILE $hfpath\n");
	    }
	}
    } else {
	if ( $opts{'z'} > 0 ) {
	    $cmd='restack_radish '.$runno." ".$opts{'z'}." $dim_z ".$EC->get_value("engine_work_directory");
	    printd (15, $cmd."\n");
	    `$cmd`;
	    $cmd="mkdir -p ${hfdir}orig";
	    if ( ! -e "${hfdir}orig" ) { 
		`$cmd`;
	    }	
	    if ( -e "$hfdir".$runno.$tc."imx.0001.raw") {
		printd(15,"Moving original out of way\n");
		$cmd="mv -f $hfdir".$runno.$tc."*.*.raw ${hfdir}orig/.";
		`$cmd`;
	    } elsif ( -e "$hfdir".$runno."roimx.0001.raw") {
		printd(15,"Moving rolled out of way\n");
		$cmd="mv -f $hfdir".$runno."ro*.*.raw ${hfdir}orig/.";
		`$cmd`;
	    } else {
		printd(45,"no \n\t$hfdir".$runno.$tc."*.*001.raw or \n\t$hfdir".$runno."ro*.*001.raw\n");
	    }
	}
    }
    $HF->write_headfile($hfpath);
    print("#-- Finished $runno\n");
}

printd(5,"Finished all numbers with rolls x=$opts{x} y=$opts{y} z=$opts{z}, Original files stashed into RUNNOimages/orig\n");
if ( $find_tags ) {
printd(0,"initiate archive using \n\narchiveme $civm_id ".join(" ",keys(%taglist))."\n\n");
}
exit $GOODEXIT;
