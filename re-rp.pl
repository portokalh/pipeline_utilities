#! /usr/local/radish-link/perl

use File::Spec;
use English;
use strict;
use Switch;

use Env qw(BIGGUS_DISKUS);
if (! defined($BIGGUS_DISKUS)) {
  print STDERR "Environment variable BIGGUS_DISKUS must be set.";
  exit 1;
}
if ($#ARGV+1 < 1) { usage_message("Need 1 or more runnos on cmd line.  These have already been pulled to $BIGGUS_DISKUS");}


my @runnos = ();
if ($#ARGV < 0) {usage_message("Missing required argument on command line");}
  push @runnos, shift @ARGV;
while ($#ARGV+1 > 0) {
  push @runnos, shift @ARGV;
}

my $n = $#runnos+1;
print ("Found $n runnos\n");

my @rdone = ();
foreach my $r (@runnos) {
  my $workdir = "$BIGGUS_DISKUS/$r.work";
  print "======================================\n";
  print "  in $workdir:\n";
  if (! -e $workdir) {
    error_out("For runno $r there is no work dir $workdir");
  }
  my @Pfiles = glob ("$workdir/P*");
  print "@Pfiles\n";
  if ($#Pfiles<0) { error_out("no Pfiles in $workdir");}
  my $count = $#Pfiles+1;

  my $lscmd = "ls -rt $workdir/P* | tail -1";
  my $last_pfile_path = `$lscmd`;
  chomp $last_pfile_path;


  if ($count > 1) {
    print "  note there may be wrap around of signa chosen pfile names!...\n"; 
    print "Please enter \"last\" pno of the set:";
    $last_pfile_path = <STDIN>;
  }

  
  my ($volume,$directories,$last_pfile) = File::Spec->splitpath( $last_pfile_path );

  print "\n  Last Pfile of $count for runno $r is $last_pfile\n";
  
  my @letters = split '', $r;
  my $first_letter = shift @letters;
  my $mag;
  switch ($first_letter) {
    case "T" { $mag = "onnes"; }
    case "S" { $mag = "kamy"; }
    case "N" { $mag = "heike"; }
    else {error_out("I don't know runno first letter $first_letter\n");}
  }

  my $app = "cd /Volumes/recon_home/script/dir_radish/dir_pipeline; ./radish.pl";
  my $radish = "$app -p sally.param -eo -c 999 $mag $r $last_pfile";
  print "re-doing: $radish\n";
  `$radish`;
  push @rdone, $r;
  print "======================================\n\n";
}
print ("re-rp'd  @rdone\n");
exit 0;

sub usage_message {
  my ($msg)  = @_;
  print "\n$msg\n";
  print "Usage: re-rp runno
    runno or runnos: each must be present as a work directory as pulled by radish, containing its orig Pfile.
    Each runno gets its rp file remade by radish.  That is all.
    Useful for replacer keyhole.
";
  exit 1;
}

sub error_out {
  my ($msg)  = @_;
  print "\nerror: $msg\n";
  exit 1;
}


