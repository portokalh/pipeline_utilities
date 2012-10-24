################################################################################
# James Cook.

################################################################################
package civm_simple_util;
use strict;
use warnings;
#use bruker;
#require Exporter;

BEGIN {
    use Exporter;
    our @ISA = qw(Exporter); # perl cricit wants this replaced with use base; not sure why yet.
    our @EXPORT_OK = qw(printd whoami whowasi debugloc sleep_with_countdown $debug_val $debug_locator); # debug_val debug_locator);
}
use vars qw($debug_val $debug_locator);
$debug_val=0;
$debug_locator=80;

=item printd
    
prints if globaldebug >= debuglevel

=cut
sub printd { my ($debuglevel,$msg)=@_; if ($debug_val>=$debuglevel) { print "$msg";  } return;}

#sub debugcall { my ($debuglevel,

=item whoami
    
gets function name from call stack

=cut
sub whoami {  return ( caller(1) )[3]; }

=item whowasi

gets calling functions name from call stack

=cut
sub whowasi { return ( caller(2) )[3]; }

=item debugloc
    
prints current function if gobaldebug >= debuglocator

=cut
sub debugloc { if ($debug_val>=$debug_locator ) { print "->", whowasi(), "\n"; } return; }

=item sleep_with_countdown

input: ($sleep_length)

sleeps for sleep_length seconds tiking off the seconds

=cut
sub sleep_with_countdown { 
    my ($sleep_length)=@_;
    my $previous_default=select(STDOUT);
    $| ++;
    for(my $t=$sleep_length;$t>0;$t--) {
	print(" $t"); 
	sleep 1;
	
    }	
    print(" 0.\n");
    select($previous_default);
    return;
}


1;
