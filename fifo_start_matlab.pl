#!/usr/bin/perl
$|++; # auto flush

# simple matlab fifo starting program so we can bounce do some matlab.
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

use lib split(':',$RADISH_PERL_LIB);
require Headfile;
#require hoaoa;
#import hoaoa qw(aoa_hash_to_headfile);
use hoaoa qw(aoa_hash_to_headfile);
#require shared;
require pipeline_utilities;
use civm_simple_util qw(load_file_to_array get_engine_constants_path printd whoami whowasi debugloc sleep_with_countdown $debug_val $debug_locator);# debug_val debug_locator);

my %opt;
my $work_dir;
my $log_path;
{ # optcheck
  if (! getopts('md:', \%opt)) {
	usage_message("Problem with command line options.\n");
    }
    if ( defined $opt{d} ) { # -d debug mins
	$debug_val=$debug_val+$opt{d};
    } else { 
	$debug_val=5;
    }
    $work_dir  = shift(@ARGV) || usage_message("No data directory speciified");
    $log_path    = shift(@ARGV) || "AUTO"; # should be input as just the name
}

if (! defined $log_path) { 
#       $log_path = '> /tmp/matlab_pipe_stuff';
#   } else {  
#
#    $log_path='> '."$work_dir/matlab_${function_m_name}";
    $log_path='> '."$work_dir/matlab_generic";
}


if ( defined $opt{m} &&! -d $work_dir) {
    mkpath($work_dir);
}

my ($fifo_path,$fifo_log) = get_matlab_fifo($work_dir,$log_path);
my $Hf=load_engine_deps($WORKSTATION_HOSTNAME);
my $matlab_app  = $Hf->get_value('engine_app_matlab');
my $matlab_opts = $Hf->get_value('engine_app_matlab_opts');
if ($matlab_app  eq "NO_KEY" ) { $matlab_app  = $Hf->get_value('engine-app-matlab'); }
if ($matlab_opts eq "NO_KEY" ) { $matlab_opts = $Hf->get_value('engine-app-matlab-opts'); }

my $fifo_start = start_fifo_program($matlab_app,$matlab_opts,$fifo_path,$fifo_log);
print("$fifo_path\n");


sub usage_message  {
    my ($msg)=@_;
    print( STDERR " Problem starting matlab fifo!");
    exit $ERROR_EXIT;
}
