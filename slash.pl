#!/usr/local/pipeline-link/perl

# slash.pl

# created 2009/12/1 Sally Gewalt CIVM
#
use strict;
use Env qw(PIPELINE_SCRIPT_DIR);
use lib "$PIPELINE_SCRIPT_DIR/pipeline_utilities";
my $GOODEXIT = 0;
my $BADEXIT  = 1;


# ---- main ------------

print "paste in the unslashed ants command line (found in pipeline traces):\n";
my $line = <STDIN>;

#print "START: $line\n";
$line =~ s/\[/\\\[/g;
$line =~ s/\]/\\\]/g;
print "\n\nNow you can run this on the unix command line (paste it):\n";
print "\n\n$line\n";

exit $GOODEXIT;

