#! /usr/local/radish-link/perl
# small perl script to parse a header from some instrement  and save it back to disk
# this is for use in our matlab reconstruction such chat we can have the same input
#  data format for the subsequent functions andget data forming ou tof the way. 

# dumpHeader scanner dir
# finds first header in directory for scanner of type $scanner loads scanner values from scanner dependencies.

use strict;
use warnings;
my $ERROR_EXIT = 1;
my $GOOD_EXIT  = 0;
use Env qw(RADISH_RECON_DIR);
if (! defined($RADISH_RECON_DIR)) {
    print STDERR "Environment variable RADISH_RECON_DIR must be set. Are you user omega?\n";
    print STDERR "   CIVM HINT setenv RADISH_RECON_DIR /recon_home/script/dir_radish\n";
    print STDERR "Bye.\n";
    exit $ERROR_EXIT;
}
#use lib "$RADISH_RECON_DIR/modules/script";
use Env qw(RADISH_PERL_LIB);
if (! defined($RADISH_PERL_LIB)) {
    print STDERR "Cannot find good perl directories, quiting\n";
    exit $ERROR_EXIT;
}
use lib split(':',$RADISH_PERL_LIB);
use Env qw(RECON_HOSTNAME);
if (! defined($RECON_HOSTNAME)) {
    print STDERR "Environment variable RECON_HOSTNAME must be set.";
    exit $ERROR_EXIT;
}

require Headfile;
#require shared;
require pipeline_utilities;
use civm_simple_util qw(load_file_to_array printd whoami whowasi debugloc sleep_with_countdown $debug_val $debug_locator);# debug_val debug_locator);
use agilent;
use bruker;
use English;
use Getopt::Std;

### parse input
our %opt;
our $scanner;
our $directory;
our $hf_path;


our $overwrite_ok = 0;
# our $data_exists=0; 
our $cmdopts='';
our $verbose=0;
{ # optcheck
    if (! getopts('od:', \%opt)) {
	usage_message("Problem with command line options.\n");
    }
    if ( defined $opt{d} ) { # -d debug mins
	$debug_val=$debug_val+$opt{d};
    }
    $scanner    = shift(@ARGV) || usage_message("No scanner specified");
    $directory  = shift(@ARGV) || usage_message("No data directory speciified");
    $hf_path    = shift(@ARGV) || "AUTO"; # should be input as just the name
    if (defined $opt{o}) {  # -o
	$overwrite_ok = 1;
	$cmdopts="${cmdopts}o";
	print("\nOverwrite enabled!\n") if $verbose;
    }
#     if (defined $opt{e}) { # -e
# 	$data_exists = 1; # if data has already been copied, we'll work with local data
# 	$cmdopts="${cmdopts}e";
#     }
}

{ # main
###
# Read Dependencies
###
    my $engine_file = join("_","engine","$RECON_HOSTNAME","radish_dependencies");
    my $this_engine_constants_path = join("/",$RADISH_RECON_DIR, $engine_file);
    
    my $Engine_constants = new Headfile ('ro', $this_engine_constants_path);
    if (! $Engine_constants->check())       { 
	error_out("Unable to open recon engine constants file $this_engine_constants_path\n"); }
    if (! $Engine_constants->read_headfile) { 
	error_out("Unable to read recon engine constants from file $this_engine_constants_path\n"); }
    my $Engine_binary_path    = $Engine_constants->get_value('engine_radish_bin_directory') . '/';
    my $Engine_work_dir = $Engine_constants->get_value('engine_work_directory');
#Engine_work_directory.'/'.$local_dest_dir
    
    my $scanner_file_name               = join("_","scanner",$scanner,"radish_dependencies");
    my $the_scanner_constants_path = join("/",$RADISH_RECON_DIR, $scanner_file_name);
    
    my $Scanner_constants = new Headfile ('ro', $the_scanner_constants_path);
    if (! $Scanner_constants->check())       { 
	error_out("Unable to open scanner constants file $the_scanner_constants_path\n"); }
    if (! $Scanner_constants->read_headfile) { 
	error_out("Unable to read scanner constants from file $the_scanner_constants_path\n"); }
    
    my $scanner_vendor;
    $scanner_vendor               = $Scanner_constants->get_value('scanner_vendor') or $scanner_vendor="";
    
###
# set output
###
    my $Hfile ;
    if ($hf_path eq "AUTO" ) {
	$hf_path = "$directory/$scanner_vendor.headfile";
    } else { 
	$hf_path = "$directory/".$hf_path;
    }
    if ( $overwrite_ok  && -e $hf_path ) {
	`rm  -f $hf_path`
    }
    $Hfile = Headfile->new('new', $hf_path);
    if (! $Hfile->check()) {
	error_out("Unable to open file $hf_path\n");
    }

###
# load files
###
    my @header_lines;
    my @infiles;#=$directory;
    my $hf_prefix;
    my $hf_name_prefix="";
    if( $scanner_vendor eq 'agilent') { 
	push(@infiles,$directory.'/'."procpar");
	$hf_prefix='z_Agilent_';
	$hf_name_prefix="A_";
	require agilent;
	import agilent qw(parse_header determine_volume_type );
	require agilent::hf ;
	import agilent::hf qw(agilent_hash_to_headfile copy_relevent_keys);
    } elsif($scanner_vendor eq 'bruker') {
	push(@infiles,$directory.'/'."subject");
	push(@infiles,$directory.'/'."acqp");
	push(@infiles,$directory.'/'."method");
	$hf_prefix='z_bruker_';
	$hf_name_prefix="B_";
	require bruker ;
	import bruker qw(parse_header determine_volume_type );
	require bruker::hf ;
	import bruker::hf qw(bruker_hash_to_headfile copy_relevent_keys);
    } else {
	error_out("scanner_vendor unspecifed");
    }
    foreach (@infiles) {
	load_file_to_array($_,\@header_lines);
    }

###
# parse files
###
    my $hfhashref = parse_header(\@header_lines,25 ); # loads mr scanner header to a hash.
    my %hfhash=%{$hfhashref};
    my $volinfotext=determine_volume_type(\%hfhash);
    my ($vol_type, $vol_detail, $vols,$x,$y,$z,$bit_depth,$data_type,$reportorder)=split(':',$volinfotext);
    $Hfile->set_value("S_scanner_tag","${hf_name_prefix}");
    $Hfile->set_value("${hf_name_prefix}vol_type",$vol_type);
    $Hfile->set_value("${hf_name_prefix}vol_type_detail",$vol_detail);
    $Hfile->set_value("${hf_name_prefix}input_bit_depth",$bit_depth);
    $Hfile->set_value("${hf_name_prefix}input_data_type",$data_type);
    if ( $reportorder ne "" ){ 
	$Hfile->set_value("${hf_name_prefix}axis_report_order",$reportorder);
    }
#    $HFile->set_values("${hf_name_prefix}bytes_per_pix",int($bit_depth/8));# really unnnecessary, can figure that out just fine when we need it from this value
    $Hfile->set_value("dim_X",$x);
    $Hfile->set_value("dim_Y",$y);
    $Hfile->set_value("dim_Z",$z);
#    $Hfile->set_value("${hf_name_prefix}volumes",$vols);
#    $Hfile->set_value("${hf_name_prefix}echos",$vols);
# i feel like this could be improved. better to dive back into the  header and look up what kind of repetitions if that is relevent, then set mutli scan appropriately.
    if( $vol_detail eq "DTI" ) {
	$Hfile->set_value("${hf_name_prefix}diffusion_scans",$vols);
	#$multiscan{"diffusion"}=$vols; 
    } elsif ( $vol_detail =~ /.*?echo.*?/x ) { 
	$Hfile->set_value("${hf_name_prefix}echos",$vols);
	#$multiscan{"echos"}=$vols; 
    } else {
	$Hfile->set_value("${hf_name_prefix}volumes",$vols);
	#$multiscan{"volumes"}=$vols; 
    }
    $Hfile->set_value("U_prefix",${hf_prefix});
    if( $scanner_vendor eq 'agilent') {     
	agilent_hash_to_headfile($hfhashref,$Hfile,$hf_prefix); #puts all variables from scanner to hf as $prefix$name keys
    } elsif($scanner_vendor eq 'bruker') {
	bruker_hash_to_headfile($hfhashref,$Hfile,$hf_prefix); #puts all variables from scanner to hfas $prefix$name keys
    }
    my $cpkeys_status=copy_relevent_keys(\%hfhash,$Hfile,0);
###
# save header
###
    if (! $Hfile->write_headfile ($hf_path)) {
	error_out("Could not write Headfile -> $hf_path");
    }
    
}

sub usage_message  {
    my ($msg)=@_;
    print( STDERR "\nPROBLEM: $msg\n");
    print STDERR "".
	"$0 scanner directory outputname\n";
    
    exit $ERROR_EXIT;
}

