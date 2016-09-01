################################################################################
# James Cook.
# 2012 
# simple utilities with some minor pod documentation
# helpful for much and many perl projects
#
# file_exists  check for file existence allowing regex in name
# printd(print only if devbugval high enough)
# load_file_to_array(loads a file at path, to an array of lines at ref)
# write_array_to_file inverse of load_file_to_array
#get_engine_constants_path  these two may be better suited to pipeline_utilities
#get_engine_hosts
# get_script_loc
# whoami(functname)
# whowasi(callingfunctionname)
# debugloc(show partofcallstack if debug_val>debug_loc)
# sleep_with_countdown(good for warnings so people see them during consol spam)
#
################################################################################
package civm_simple_util;
use strict;
use warnings;
use Carp;
#use bruker;
use Scalar::Util qw(looks_like_number);
use File::Find;
use File::Basename;
#use Devel::CheckOS qw(die_unsupported os_is);
#require Exporter;

BEGIN {
    use Exporter;
    our @ISA = qw(Exporter); # perl cricit wants this replaced with use base; not sure why yet.
    our @EXPORT_OK = qw(
load_file_to_array 
write_array_to_file
get_engine_constants_path
get_engine_hosts
get_script_loc
file_exists
mod_time
is_empty
get_busy_char
printd 
whoami 
whowasi 
debugloc 
sleep_with_countdown 
$debug_val 
$debug_locator
); 
}
use vars qw($debug_val $debug_locator);
$debug_val=0 unless defined $debug_val;
$debug_locator=80 unless defined $debug_locator;




=item load_file_to_array($path,$array_ref[,$debug_val])

loads a text file to an array of lines located at array_ref and returns number of lines loaded

=cut
###
sub load_file_to_array { # (path,array_ref[,debug_val]) loads text to array ref, returns number of lines loaded.
###
    my (@input)=@_;
#    my ($file,$array_ref)=@_;
    my $file=shift @input;
    my $array_ref=shift @input; 
    my $old_debug=$debug_val;
    $debug_val = shift @input or $debug_val=$old_debug;
    civm_simple_util::debugloc();
    my @all_lines =();
    civm_simple_util::whoami();
    civm_simple_util::printd(30,"Opening file $file.\n");
    open my $text_fid, "<", "$file" or croak "could not open $file";
    croak "file <$file> not Text\n" unless -T $text_fid ;
    @all_lines =  <$text_fid> ;
    close  $text_fid;
    push (@{$array_ref}, @all_lines);
    return $#all_lines+1;
}
=item write_array_to_file($path,$array_ref[,$debug_val])

writes an array of strings to a text file located at path 

=cut
###
sub write_array_to_file { # (path,array_ref[,debug_val]) writes text to array ref.
###
    my (@input)=@_;
#    my ($file,$array_ref)=@_;
    my $file=shift @input;
    my $array_ref=shift @input; 
    my $old_debug=$debug_val;
    $debug_val = shift @input or $debug_val=$old_debug;
    civm_simple_util::debugloc();
    my @all_lines =@{$array_ref};
    civm_simple_util::whoami();
    civm_simple_util::printd(30,"Opening file $file.\n");
    open my $text_fid, ">", "$file" or croak "could not open $file";
    croak "file <$file> not Text\n" unless -T $text_fid ;
    foreach ( @all_lines ) {
	print  $text_fid $_;  # write out every line modified or not 
    }
    close  $text_fid;

    return;
}

=item constant_path=get_engine_constants_path { # (hostname[,debug_val])

=cut
###
sub get_engine_constants_path { # (search_base,hostname[,debug_val])
###
# 
    my (@input)=@_;
    my $search_base=shift @input;
    my $hostname=shift @input;
    if ( looks_like_number($hostname) ) {
	unshift(@input,$hostname);
    }
    my $old_debug=$debug_val;
    $debug_val =   shift @input or $debug_val=$old_debug;
    civm_simple_util::debugloc();
#    my @all_lines =();
    civm_simple_util::whoami();
    if ( $hostname eq ""  or ! defined ($hostname)) {
	$hostname=qx/ hostname -s/;
	civm_simple_util::printd(5,"host was undefined.\n");
    }
    civm_simple_util::printd(5,"using hostname=$hostname\n");
#find( sub { print $File::Find::name."\n" if ( $_ =~ /engine_$hostname.*dependencies/ ); } , "$search_base");
    my %files;
    find( sub { ${files{$File::Find::name}} = 1 if ($_ =~  m/^engine.*$hostname.*dependencies$/x ) ; },$search_base);
    my @fnames=sort(keys(%files));
    if ($#fnames==-1 ) { push(@fnames,""); } 
#     if(os_is('MicrosoftWindows') ) { 
#  	printd(55,"fixing path for windows\n\n");
#  	$fnames[0]=~ s:\\\\:/:gx;
#     }
    civm_simple_util::printd(30,"Found constants File $fnames[0].\n");

    return ($fnames[0]);
}
=item constant_path=get_engine_hosts_path { # (search_base[,debug_val])

=cut
###
sub get_engine_hosts { # (search_base,
###
# 
    my (@input)=@_;
    my $search_base=shift @input;
    my $old_debug=$debug_val;
    $debug_val =   shift @input or $debug_val=$old_debug;
    civm_simple_util::debugloc();
    civm_simple_util::whoami();
    my %files;
    find( sub { ${files{$File::Find::name}} = 1 if ($_ =~  m/^engine_.*_dependencies$/x ) ; },$search_base);
    #nasty clever perl this is, have to cleanup the name->host condition below.
    my @fnames=sort(keys(%files));
    undef %files;
    while($#fnames>0 ) {
	my $n=basename(shift @fnames);
	civm_simple_util::printd(90,"name $n.\n");
	if ( $n =~ m/^engine_(.*)_.*dependencies/x  ) {
	    if ( defined $files{$1} ){
		$files{$1}=$files{$1}+1 
	    }else {
		$files{$1}=1;
	}
	    printd(50,"added host:$1 to list\n");#
	}
    } 
    @fnames=sort(keys(%files)); 
    if ($#fnames==-1 ) { push(@fnames,""); } 
#     if(os_is('MicrosoftWindows') ) { 
#  	printd(55,"fixing path for windows\n\n");
#  	$fnames[0]=~ s:\\\\:/:gx;
#     }
    civm_simple_util::printd(30,"Found constants File $fnames[0].\n");
    $debug_val=$old_debug;
#    print(@fnames);
    return @fnames;
}
=item real_script_path=get_script_loc { # (search_base[,debug_val])

=cut
###
sub get_script_loc { # ($script_path,[debug_val])
###
# 
    my (@input)=@_;
    my $script_path=shift(@input);
    my $old_debug=$debug_val;
    $debug_val =   shift @input or $debug_val=$old_debug;
    civm_simple_util::debugloc();
    civm_simple_util::whoami();
    #$script_path=__FILE__;
    use Cwd 'abs_path';
    while( -f $script_path && -l $script_path ) {
	printd(25,"path was a link, resolving from $script_path");
	$script_path=abs_path($script_path);
	printd(25,"to  $script_path.\n");
    }
    return $script_path;
}

=get_busy_char

gets the next char for a busy indicator.

=cut
sub get_busy_char {
    my ($count)=@_;
    my @chars=('|','/','-','\\');
    return ($chars[$count%($#chars)]);
}
=item file_exists

check if a files exists using read dir 
filepath can include regular expession bits except for / because we use basename to get the directory.

=cut

sub file_exists { 
    my ($fullname)=@_; 
    my $status = 0;
#    use File::Basename;
#    ($name,$path,$suffix) = fileparse($fullname,@suffixlist);
    my ($n,$p,$s) = fileparse($fullname,qr/\.[^.]*$/);

    opendir(DIR, "$p") or die $!;
    my @matches = grep(/^$n$s/, readdir(DIR));
    closedir(DIR);

    if ($#matches>=0) {
	$status=1;
    }
    
    return $status;
}

=item mod_time 

get modiy time in seconds of a file. 

=cut

sub mod_time {
    #use File::stat;
    my($file)=@_;
    return (stat($file))[9];
}
=item is_empty 

check if a directory is empty using read dir 
filepath can include regular expession bits except for / because we use basename to get the directory.

# 1 - empty
# 0 - not empty
# -1 - doesn't exist
# Definition of "empty" -- no files/folders/links except . and ..

=cut
sub is_empty {
    my ($dir) = @_;
    my $file;
    if (opendir my $dfh, $dir){
	while (defined($file = readdir $dfh)){
	    next if $file eq '.' or $file eq '..';
	    closedir $dfh;
	    return 0;
	}
	closedir $dfh;
	return 1;
    }else{
	#die "$dir not exist";
	return -1;
    }
}

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
	sleep 1 unless $debug_val==0;
	
    }	
    print(" 0.\n");
    select($previous_default);
    return;
}


1;
