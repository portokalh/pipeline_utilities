#! /usr/local/radish-link/perl

#retrieve_archive_dir.pm

# created 2009/10/28 Sally Gewalt CIVM
# assumes ssh identity is all set up
# base use is for user omega to run this and connect to atlasdb:/atlas1 as omega

use strict;
my $PROGRAM_NAME = "retrieve_archive_dir.pm";
my $VERSION_DATE = "100104";
my $DEBUG = 0;
my $VERBOSE = 0;
my $GOODEXIT = 0;
my $ERROR_EXIT = 1;

# ENV var is used to indicate where radish recon code is located
#   e.g. like "/recon_home/script/dir_radish"
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

use Getopt::Std;
use strict;
use English;
require Headfile; # for engine dependencies

# --- read recon engine dependency file to get current engine's work directory
# ENV var HOSTNAME is used to identify this recon ENGINE's constant file:
use Env qw(RECON_HOSTNAME);
if (! defined($RECON_HOSTNAME)) {
  print STDERR "Environment variable RECON_HOSTNAME must be set.";
  exit $ERROR_EXIT;
}
my $engine_file = join("_","engine","$RECON_HOSTNAME","radish_dependencies");
my $this_engine_constants_path = join("/",$RADISH_RECON_DIR, $engine_file);

my $Engine_constants = new Headfile ('ro', $this_engine_constants_path);
if (! $Engine_constants->check()) {
  error_out("Unable to open recon engine constants file $this_engine_constants_path\n");
}
if (! $Engine_constants->read_headfile) {
  error_out("Unable to read recon engine constants from file $this_engine_constants_path\n");
}

my $recon_dir = $Engine_constants->get_value('engine_work_directory');
if (! -e $recon_dir) {
      error_out("recon_dir not available $recon_dir");
}


# -- cmd line
# get source subproject dir and runno to get
my ($subproject, $runno) =  handle_command_line();

# -- make local destination directory in civm layout
# make  /bigdisk/<runno> home for runno dir
my $runno_dir = "$recon_dir/$runno";
#if (! -e $runno_dir) {
#  if (! mkdir($runno_dir,0777)) {
#    error_out("Unable to create destination directory $runno_dir\n");
#  }
#} 

# get whole runno dir into runno_images 
my $doit = 1;
my $final_dir = retrieve_archive_dir ($doit, $subproject, $runno, $runno_dir);

my $what = $doit ? "Restored" : "Did not restore (doit=0)";
print "  $what images into $final_dir\n";


exit $GOODEXIT;

# ----- subroutines

# ------------------
sub retrieve_archive_dir {
# ------------------
# Retrieve runno (image) directory from archive.
# assumes data is archived in subproject/runno dir
# gets entire directory
# returns name of local directory of result set
  my ($do_pull, $subproject, $runno, $local_dest_dir) = @_;
  if (! -d $local_dest_dir) {
     mkdir $local_dest_dir;
  }
  # add -q for quiet
  my $final_dir = "$local_dest_dir/$runno\images";
  my $cmd = "scp -qr omega\@atlasdb:/atlas1/$subproject/$runno  $final_dir";
  my $ok = execute($do_pull, "archive retrieve", $cmd);
  if (! $ok) {
    error_out("Could not retrieve archived images for $runno: $cmd\n");
  }
  return ($final_dir);
}

# ------------------
sub first_image_name {
# ------------------
# returns complete first (.001., .01, .0001, etc) image name in directory
# note: suffix of civm images can be raw or rawl, i32...
# you may parse this to figure out base image name (e.g. N12345fsimx, etc)
# padding, etc.

  my ($image_set_dir, $runno) = @_;
  my $template = "^$runno\\w*\\.0+1\\.\\w+\$";  # note perl eats many of the \
  #print "TEMPLATE: $template\n";
  my @list = make_list_of_files ($image_set_dir, $template);
  my $count_found = $#list + 1;
  if ($count_found != 1) {
    foreach my $l (@list) {
       print "Found image: $l\n";
     }
     error_out ("Couldn't find unique first image in $image_set_dir (found $count_found, template $template)");
  }
  my $image = pop @list;
  return ($image);
}

# -------------
sub execute {
# -------------
# returns 0 if error

  my ($do_it, $annotation, @commands) = @_;
  my $rc;
  my $i = 0;
  foreach my $c (@commands) {
    $i++;

    if (0) {
    # -- log the info and the specific command: on separate lines
    my $msg;
    #print "Logfile is: $pipeline_info_log_path\n";
    my $skip = $do_it ? "" : "Skipped ";
    my $info = $annotation eq '' ? ": " : " $annotation: ";
      #$msg = join '', $skip, "EXECUTING",$info, $c, " -------------------------" ;
      #log_info($msg);
    my $time = scalar localtime;
    $msg = join '', $skip, "EXECUTING",$info, " ------- ", $time , " --------";
    my $cmsg = "   $c";
    #log_info($msg);
    #log_info($cmsg);
    }

    print " executing ($do_it): $c\n";

    if ($do_it) {
      $rc = system ($c);
    }
    else {
      $rc = 0; # fake ok
    }

    if ($rc != 0) {
      print STDERR "  Problem:\n";
      print STDERR "  * Command was: $c\n";
      print STDERR "  * Execution of command failed.\n";
      return 0;
    }
  }
  return 1;
}

#------------
sub error_out {
#------------
  my ($msg) = @_;
  print "\n--> $PROGRAM_NAME exiting:\n  $msg\n";
  print "Sorry, bye.\n";
  exit $ERROR_EXIT;
}


#------------
sub handle_command_line {
#------------
  # exit with usage message if problem detected

  my $need = 2;
  if ($#ARGV+1 < $need) { usage_message("need $need arguments");}

  my %options = ();
  #if (! getopts('c:y:', \%options)) {
  if (! getopts('', \%options)) {
    print "Problem with command line options.\n";
    usage_message("problem with getopts");
  }

  # -- handle required params
  #foreach my $a (@ARGV) {  # save the cmd line for annotation
    ## print "ARG $a\n";
  #  $cmd_line_args = $cmd_line_args . " " . $a;
  #}

  my $one = shift @ARGV;
  my $two = shift @ARGV;

  #  -- handle cmd line options...
  #if (defined $options{c}) {  # -c
  #   $pull_boolean = 0;
  #}

  return ($one, $two);
}

#------------
sub usage_message {
#------------
  my ($msg)  = @_;

  print STDERR "\n$msg\n\nusage: $PROGRAM_NAME subproject runno

  Gets the runno from /atlas1 archive, and stores it in civm type $recon_dir/runno/runnoimages dir.

  2 args required:
  subproject : the subproject this runno is archived under. 
  runno      : the Radish runno.  The runno you provided to Radish.

  no options.

  $PROGRAM_NAME version: $VERSION_DATE\n";

  exit ($ERROR_EXIT);
}



1;

