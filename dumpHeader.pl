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
require hoaoa;
#require shared;
require pipeline_utilities;
use civm_simple_util qw(load_file_to_array printd whoami whowasi debugloc sleep_with_countdown $debug_val $debug_locator);# debug_val debug_locator);
# use agilent;
# use aspect;
# use bruker;
use English;
use Getopt::Std;
use File::Basename;

### parse input
our %opt;
our $scanner;
our $directory;
our @infiles;
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
    } else { 
	$debug_val=5;
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
    ### check if dirctory is the scanner header file instead of the directory from the magnet
    if ( -f $directory ){ # && ! -d $directory) { 
	printd(15,"You specifid the scanner header file directly instead of the directory it sits in. This is an unproven method best suited for testing different ways to fool the header parse script \n");
	push (@infiles,$directory);
	my $name;
	($name,$directory)=fileparse( $directory);
    }
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
    my $hf_prefix;
    my $hf_short_prefix="";
    my $data_filename="";
    if( $scanner_vendor eq 'agilent') { 
	if ($#infiles == -1 ) { 
	    push(@infiles,$directory.'/'."procpar");
	} else { 
	    printd(15,"You specifid the scanner header file directly instead of the directory it sits in. This is an unproven method best suited for testing different ways to fool the header parse script \n"); 
	}
	$hf_prefix='z_Agilent_';
	$hf_short_prefix="A_";
	$data_filename="fid";
	import hoaoa qw(aoa_hash_to_headfile);
	require agilent;
	import agilent qw(parse_header determine_volume_type );
	require agilent::hf ;
	import agilent::hf qw( copy_relevent_keys);

    }elsif( $scanner_vendor eq 'aspect') { 
	my @files=glob( $directory.'/'."*.DAT");
	if ($#infiles == -1 ) { 
	    push(@infiles,$files[0]);
	} else { 
	    printd(15,"You specifid the scanner header file directly instead of the directory it sits in. This is an unproven method best suited for testing different ways to fool the header parse script \n"); 
	}
	$hf_prefix='z_Aspect_';
	$hf_short_prefix="A_";
	$data_filename="*tnt";
	require aspect;
	import aspect qw(parse_header determine_volume_type );
	require aspect::hf ;
	import aspect::hf qw(aoa_hash_to_headfile copy_relevent_keys);
    } elsif($scanner_vendor eq 'bruker') {
	if ($#infiles == -1 ) { 
	    push(@infiles,$directory.'/'."subject");
	    push(@infiles,$directory.'/'."acqp");
	    push(@infiles,$directory.'/'."method");
	} else {
	    printd(15,"the scanner input file was specified directly, bruker headers are normally in three parts, you need to have combined those into one to specify the headfile to use directly.(subject,acqp,method)");
	}
	$hf_prefix='z_Bruker_';
	$hf_short_prefix="B_";
	$data_filename="fid";
	import hoaoa qw(aoa_hash_to_headfile);
	require bruker ;
	import bruker qw(parse_header determine_volume_type );
	require bruker::hf ;
	import bruker::hf qw(copy_relevent_keys);
    } else {
	error_out("scanner_vendor unspecifed");
    }
    foreach (@infiles) {
	load_file_to_array($_,\@header_lines);
    }

###
# parse files
###
    my $hfhashref = parse_header(\@header_lines,$debug_val ); # loads mr scanner header to a hash.
    my %hfhash=%{$hfhashref};
#    my $volinfotext=determine_volume_type(\%hfhash);
#    my $volinfotext=determine_volume_type($hfhashref); # only determines the output volume type, need alternate to determine the kspace data and its orientations and orders.
 #   my ($vol_type, $vol_detail, $vols,$x,$y,$z,$bit_depth,$data_type,$reportorder)=split(':',$volinfotext);
#    printd(45,$volinfotext."\n");
    $Hfile->set_value("kspace_data_path",glob($directory.'/'.$data_filename)); # glob resolves the * in aspectnames  : )
    $Hfile->set_value("S_scanner_tag","${hf_short_prefix}");
# i feel like this could be improved. better to dive back into the  header and look up what kind of repetitions if that is relevent, then set mutli scan appropriately.

    $Hfile->set_value("U_prefix",${hf_prefix});
    $Hfile->set_value("S_tag",$hf_short_prefix);
    aoa_hash_to_headfile($hfhashref,$Hfile,$hf_prefix); #puts all variables from scanner to hf $prefix$name keys
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

