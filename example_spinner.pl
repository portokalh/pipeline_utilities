#!/usr/bin/perl
use strict;
use warnings;

use Env qw(RADISH_PERL_LIB);
if (! defined($RADISH_PERL_LIB)) {
    print STDERR "Cannot find good perl directories, quiting\n";
#    exit $ERROR_EXITA;
}
use lib split(':',$RADISH_PERL_LIB);


require pipeline_utilities;
require shared;
require Headfile;

use civm_simple_util qw(get_busy_char);

my $count=0;
print("starting count\n ");
#my $ofh = select STDOUT;
use IO::Handle;
STDERR->autoflush(1);
STDOUT->autoflush(1);
while ($count<1000) {
	printf("\b%s",get_busy_char($count));
	$count=$count+1;
	sleep 1;
}

exit 1;;
