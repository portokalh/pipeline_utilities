#!/usr/bin/perl
# Fid archiver.
# presumably we have a fid and appropriate file on the system to archive,
# This will create the bare bones headfile equired for a directory research archive.
# 
#usage
# fid_archive runno (engine optionlal)












my $ERROR_EXIT = 1;
my $GOOD_EXIT  = 0;

use strict;
use warnings;
use English;
use Getopt::Std;
use File::Basename;
use File::Glob qw(:globally :nocase);

use Env qw(RADISH_PERL_LIB RADISH_RECON_DIR WORKSTATION_HOME WKS_SETTINGS RECON_HOSTNAME WORKSTATION_HOSTNAME); # root of radish pipeline folders
if (! defined($RADISH_PERL_LIB)) {
    print STDERR "Cannot find good perl directories, quiting\n";
    exit $ERROR_EXIT;
}
if (! defined($RADISH_RECON_DIR) && ! defined ($WORKSTATION_HOME)) {
    print STDERR "Environment variable RADISH_RECON_DIR must be set. Are you user omega?\n";
    print STDERR "   CIVM HINT setenv RADISH_RECON_DIR /recon_home/script/dir_radish\n";
    print STDERR "Bye.\n";
    exit $ERROR_EXIT;
}
if (! defined($RECON_HOSTNAME) && ! defined($WORKSTATION_HOSTNAME)) {
    print STDERR "Environment variable RECON_HOSTNAME or WORKSTATION_HOSTNAME must be set.";
    exit $ERROR_EXIT;
}

if ( ! defined($WORKSTATION_HOSTNAME)) {
    $WORKSTATION_HOSTNAME=$RECON_HOSTNAME;
}


use lib split(':',$RADISH_PERL_LIB);
require Headfile;
#require hoaoa;
#import hoaoa qw(aoa_hash_to_headfile);
use hoaoa qw(aoa_hash_to_headfile);
#require shared;
require pipeline_utilities;
use civm_simple_util qw(load_file_to_array get_engine_constants_path printd whoami whowasi debugloc sleep_with_countdown $debug_val $debug_locator);# debug_val debug_locator);
# use agilent;
# use aspect;
# use bruker;

### parse input
our %opt;
our $scanner;
our $directory;
our $person;
our $runno;
our $root_runno;
our $archive_suffix="_fid";
our $scanner_vendor;
our $outrunno;
our @infiles;
our $hf_path;


our $overwrite_ok = 0;
# our $data_exists=0; 
our $cmdopts='';
our $verbose=0;

{ # optcheck
    if (! getopts('od:s:x:', \%opt)) {
	usage_message("Problem with command line options.\n");
    }
    if ( defined $opt{d} ) { # -d debug mins
	$debug_val=$debug_val+$opt{d};
    } else { 
	$debug_val=5;
    }
# person runno
#    $scanner    = shift(@ARGV) || usage_message("No scanner specified");
#    $directory  = shift(@ARGV) || usage_message("No data directory speciified");
#    $hf_path    = shift(@ARGV) || "AUTO"; # should be input as just the name
    $person = shift(@ARGV) || usage_message("No person specified");
    $runno = shift(@ARGV) || usage_message("No runno specified");
    $root_runno=$runno;
    if (defined $opt{o}) {  # -o
	$overwrite_ok = 1;
	$cmdopts="${cmdopts}o";
	print("\nOverwrite enabled!\n") if $verbose;
    }
    $outrunno="${runno}$archive_suffix";
    if (defined $opt{s}) {  # -s suffix
	print("\nAlternate suffix specified.\n".
	      "OutputRunno was     $outrunno ( preliminary )\n");
	$archive_suffix=$opt{'s'};
	$cmdopts="${cmdopts}s $archive_suffix";
	$outrunno="${runno}$archive_suffix";
	print("OutputRunno will be $outrunno ( preliminary )\n");
    }
    if (defined $opt{x}) {  # -s suffix
	print("\nAlternate scanner_vendor specified.\n");
	$scanner_vendor=$opt{'x'};
	$cmdopts="${cmdopts}s $scanner_vendor";
	print("\tusing $scanner_vendor\n");
    }
#     if (defined $opt{e}) { # -e
# 	$data_exists = 1; # if data has already been copied, we'll work with local data
# 	$cmdopts="${cmdopts}e";
#     }
}
{ # main
    printd(50,"Person is $person\n");
    printd(50,"Runno is $runno\n");
    printd(15,"Looking up runno in local dir...\n");
###
# Read Dependencies
###
    my $engine_file ;
    $engine_file = join("_","engine","$RECON_HOSTNAME","radish_dependencies");
    my $this_engine_constants_path ;
#    my $scanner_file_name               = join("_","scanner",$scanner,"radish_dependencies");
#    my $the_scanner_constants_path = join("/",$RADISH_RECON_DIR, $scanner_file_name);
    if ( defined $WKS_SETTINGS) {
	$this_engine_constants_path = get_engine_constants_path($WKS_SETTINGS,$WORKSTATION_HOSTNAME);
#	$the_scanner_constants_path = join("/",$WKS_SETTINGS."/scanner_deps/", $scanner_file_name); 
#    printd(5,"found constants $this_engine_constants_path\n");
    } else { 
	$this_engine_constants_path = join("/",$RADISH_RECON_DIR, $engine_file);
#    printd(5,"using old constants $this_engine_constants_path\n");
    }

    my $Engine_constants = new Headfile ('ro', $this_engine_constants_path);
    if (! $Engine_constants->check())       { 
	error_out("Unable to open recon engine constants file $this_engine_constants_path\n"); }
    if (! $Engine_constants->read_headfile) { 
	error_out("Unable to read recon engine constants from file $this_engine_constants_path\n"); }
    my $Engine_binary_path    = $Engine_constants->get_value('engine_radish_bin_directory') . '/';
    my $Engine_work_dir = $Engine_constants->get_value('engine_work_directory');
#Engine_work_directory.'/'.$local_dest_dir

    my $rm_hfpath='NULL';
    ### check if directory is the scanner header file instead of the directory from the magnet
    my ($name,$extension);
    if ( -f $runno){ # && ! -d $directory) { 
	#printd(15,"You specifid the scanner header file directly instead of the directory it sits in. This is an unproven method best suited for testing different ways to fool the header parse script \n");
	#push (@infiles,$directory);

	$rm_hfpath="$runno";
	($name,$directory,$extension)=fileparts( $runno); # directory not used, ... bad idea?.
	if ( $extension ne '.headfile' ) {
	    warn(" strange extension $extension proceeding with runno = $runno");
	}
	# what if its an output run number.
	$runno=$name;
	#archrun if glob dir of raw > 0 
	my @imgs=glob($directory."*.raw*");
	if ($#imgs > 0 ) {
	    $root_runno=$runno;
	} else {
	    printd(1,"root_runno indetermintate will use output runno");
	    $root_runno="USEOUT";
	}
    } elsif ( ! -d "$Engine_work_dir/$runno") {
	my @dirs=glob("$Engine_work_dir/$runno*");
	@dirs=grep(!/$runno(?:\.work|_fid)/, @dirs);
	#print(join("\n", @dirs)."\n");
	($name,$directory,$extension)= fileparts($dirs[0]);
	#print("$name,$directory,$extension\n");
	if ( $name ne $runno && defined $name && $name ne "" ) { 
	    $runno=$name;
	    $root_runno=$name;
	}
    } else {
	#error_out("runno $runno not found in $Engine_work_dir, and wasnt a headfile specifed direclty");
	printd(60,"runno $runno not found in $Engine_work_dir, and wasnt a headfile specifed direclty");
    }
    $directory="$Engine_work_dir/$runno.work/"; 
    # check if runno was an m0(or other suffix) directory, if it was, and the .work doesnt exist, try a base run dir.
    my $insuffix='';
    if ( ! -e $directory && ! -f $runno) {
	printd(25,"not exist $directory, and not file $runno\n");
	my $ldir=$directory;
	($runno,$insuffix)=$runno =~ /([A-Za-z][0-9]{5,})(.*)/x;
	$directory="$Engine_work_dir/$runno.work/";
	#$root_runno=$runno;
	if ( ! -e $directory ) {
	    usage_message("Couldnt find recon work dir, $ldir or $directory");
	}
	$rm_hfpath="$directory/rad_mat.headfile";
    } else {
	printd(25,"found $directory, or $runno\n");
    }
    # make sure the input headfile exists
    if ( ! -f $rm_hfpath ) {
	printd(5,"Switching to image dir headfile\n");
	$rm_hfpath="$Engine_work_dir/$runno/${runno}images/$runno.headfile";
    }
    if ( $runno.$archive_suffix ne $outrunno ) {
	$outrunno=$runno.$archive_suffix;
	print("OutputRunno will be $outrunno\n");
    }
    if ( $root_runno eq "USEOUT" ) {
	$root_runno=$outrunno;
    }
    
#    my $Scanner_constants = new Headfile ('ro', $the_scanner_constants_path);
#    if (! $Scanner_constants->check())       { 
#	error_out("Unable to open scanner constants file $the_scanner_constants_path\n"); }
#    if (! $Scanner_constants->read_headfile) { 
#	error_out("Unable to read scanner constants from file $the_scanner_constants_path\n"); }
    
#    my $scanner_vendor;
#    $scanner_vendor               = $Scanner_constants->get_value('scanner_vendor') or $scanner_vendor="";
    

    my $input_headfile = new Headfile ('ro', $rm_hfpath);
    if (! $input_headfile->check())       { 
	error_out("Unable to open recon headfile $rm_hfpath\n"); }
    if (! $input_headfile->read_headfile) { 
	error_out("Unable to read from file $rm_hfpath\n"); }

    if ( ! defined ($scanner_vendor) ) {
	$scanner_vendor               = $input_headfile->get_value('scanner_vendor') or $scanner_vendor="";
    }
    
###
# check for unexpected scanner_vendor
###    
# agilent,aspect,bruker are expected
    my @scanner_vendors= qw/agilent aspect bruker ge/;
    my $odd_scanner;
    my $scanner_regex=join('|',@scanner_vendors);
    if ( $scanner_vendor !~  /^($scanner_regex)$/ ) {
	printd(5,"UNEXPECTED SCANNER VENDOR!($scanner_vendor), TRYING AGILENT\n");
	printd(30,"scanner regex match was $scanner_regex\n");
	$odd_scanner=$scanner_vendor;
	$scanner_vendor="agilent";
    }

###
# set output
###
    my @errors=();
    my $Hfile ;
    my $out_dir = "$Engine_work_dir/${outrunno}/";
    $hf_path = "$out_dir${outrunno}.headfile";
    if ( ! -d "$out_dir" ) {
	mkdir( "$out_dir",0777) or push(@errors,"couldnt create dir $_");}
    if ( $overwrite_ok  && -f $hf_path ) {
	unlink($hf_path) or push(@errors, "old hf existed, overwrite ok, but could not remove");
    } elsif ( -f $hf_path )  { 
	push(@errors, "old hf existed, but overwrite not ok.");
    }
    $Hfile = Headfile->new('new', $hf_path);
    if (! $Hfile->check()) {
	push(@errors,"Unable to open file $hf_path\n");
    }
    if ( $#errors>=0) {
	error_out(join('\n',@errors));
    }

###
# load files
###
    my @header_lines;
    my $hf_prefix;
    my $hf_short_prefix="";
    my $data_filename="";
    if( $scanner_vendor eq 'agilent') { 
	$hf_prefix='z_Agilent_';
	$hf_short_prefix="A_";
	#$data_filename="fid";
	require agilent;
	import agilent qw(parse_header input_files );
	require agilent::hf ;
	@infiles=input_files();
	if ($#infiles == -1 ) { 
	    push(@infiles,$directory.'/'."procpar");
	} else { 
	    printd(15,"You specifid the scanner header file directly instead of the directory it sits in. This is an unproven method best suited for testing different ways to fool the header parse script \n"); 
	}
    }elsif( $scanner_vendor eq 'aspect') { 
	error_out("fid archive doesnt support $scanner_vendor yet");
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
	import aspect qw(parse_header input_files);
	require aspect::hf ;
    } elsif($scanner_vendor eq 'bruker') {
	error_out("fid archive doesnt support $scanner_vendor yet");
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
	require bruker;
	import bruker qw(parse_header input_files);
	require bruker::hf ;
    } elsif($scanner_vendor eq 'ge') {
	if ($#infiles == -1 ) { 
	    push(@infiles,glob($directory.'/'."P*"));
#	    push(@infiles,$directory.'/'."acqp");
#	    push(@infiles,$directory.'/'."method");
	} else {
	    printd(15,"You specifid the scanner header file directly instead of the directory it sits in. This is an unproven method best suited for testing different ways to fool the header parse script \n"); 
	}
#	$hf_prefix='z_Bruker_';
	$hf_short_prefix="S_";
	$data_filename="*.rp";

    } else {
	error_out("unexpected scanner_vendor OR scanner_vendor unspecifed!");
    }
    #my @candidate_dirs=glob("$spacedir/$runno*");
    #if ($#candidate_dirs!=0){
    #error_out("Too many possibliities found, you need to be more specific.");
    #}
    
###
# parse files
###
    #my @errors=();
    foreach ( @infiles) {
	my ($fname,$fdir)=fileparse( $_);
	my $dtmp="";
	if ( ! -f $_ ) {
	    $dtmp=$directory;
	}
	my $ipath=$dtmp.$_;
	if ( -f $ipath ) {
	link ( $ipath,$out_dir.$fname );
	print ( "$ipath -> $out_dir$fname \n");
	} else {
	    #printd(5,"WARNING: file $ipath not found\n");
	    push(@errors,"file $ipath not found");
	}
    }

    
#    $Hfile->get_value("kspace_data_path")); # glob resolves the * in aspectnames  : )
#    $Hfile->set_value("U_prefix",${hf_prefix});
#    $Hfile->set_value("S_tag",$hf_short_prefix);
    
###
# cleanup tasks
###
    $Hfile->set_value("U_civmid",$person); # U_civmid=lu
    $Hfile->set_value('U_db_insert_type','research'); # U_db_insert_type=research
    $Hfile->set_value('U_root_runno',$root_runno);# U_root_runno=N51667_m0
    $Hfile->set_value('U_specid',$input_headfile->get_value('U_specid'));# U_specid=141209-1:1
    $Hfile->set_value('U_stored_file_format','raw');# U_stored_file_format=raw
    $Hfile->set_value('archivesource_headfile_creator',$person);# archivesource_headfile_creator=lu
    $Hfile->set_value('archivesource_item_form','directory-set');# archivesource_item_form=directory-set
    $Hfile->set_value('archivesource_computer',$WORKSTATION_HOSTNAME);# archivesource_computer=andros
    $Hfile->set_value('archivesource_directory',$Engine_work_dir);# archivesource_directory=/androsspace
    $Hfile->set_value('archivesource_item',$outrunno);# archivesource_item=N51667_fid
    $Hfile->set_value('archivedestination_project_directory_name',$input_headfile->get_value('U_code'));
    #                   archivedestination_project_directory_name=13.gaj.32
    $Hfile->set_value('archivedestination_unique_item_name',$outrunno);# archivedestination_unique_item_name=N51667_DTI_FIDRaw
    $Hfile->set_value('U_date',strftime("%F",localtime));# U_date=15-03-05
    my $opt_text=$input_headfile->get_value('U_optional');
    if ( $opt_text eq '' || $opt_text eq 'NOKEY' || $opt_text eq 'UNDEFINED_VALUE') {
	$opt_text='$scanner_vendor fid archive for $scanner';
    }
    $opt_text =sprintf('%s', substr($opt_text,0,80));
    $Hfile->set_value('U_optional',$opt_text);  # U_optional=DTI of half mouse brain 130 directions
    my $s_tag=$input_headfile->get_value('S_tag');
    my $vt=$input_headfile->get_value("${s_tag}vol_type");
    my $vtd=$input_headfile->get_value("${s_tag}vol_type_detail");
    my $modality='research';
    if ( $vtd =~ /[Dd][Tt][Ii]/x ) {
	$modality=$modality." DTI";
    } else { 
	$modality=$modality." MRM";
    }
    $Hfile->set_value('U_rd_modality',$modality);# U_rd_modality=research DTI;
    
    $Hfile->print_headfile($outrunno);
    if ( $#errors>=0 ) {
	error_out("process stop before write headfile".join("\n",@errors));
    }
###
# save header
###
    if (! $Hfile->write_headfile ($hf_path)) {
	error_out("Could not write Headfile -> $hf_path");
    } else { 
	print("\nStart archive with command\n\n");
	print("ssh safe\@deepthought archiveresearch $person $hf_path\n\n");

    }
    
}

sub usage_message  {
    my ($msg)=@_;
    print( STDERR "\ndumpHeader PROBLEM: $msg\n");
    print STDERR "$0 <options> person runno\n".
	" person= you, \n".
	" runno= runno to attach raw data to\n".
	"fid_archive : . \n".
	" Options: \n".
	"  -o overwrite enable\n".
	"  -d #   \tdebug level\n".
	"  -s suffix   \tout runno suffix\n".
	"";
    
    exit $ERROR_EXIT;
}

