#!/usr/bin/perl
use strict;
use warnings;
use Env qw(PIPELINE_SCRIPT_DIR);
# generic incldues
use Cwd qw(abs_path);
use File::Basename;
use Data::Dump qw(dump);
use lib dirname(abs_path($0));
use Env qw(RADISH_PERL_LIB);
use vars qw($PIPELINE_VERSION $PIPELINE_NAME $PIPELINE_DESC $HfResult $GOODEXIT $BADEXIT ); #$test_mode
if (  ! defined($BADEXIT) ) {
    $BADEXIT=1;
}
if (  ! defined($GOODEXIT) ) {
    $GOODEXIT=0;
}
if (! defined($RADISH_PERL_LIB)) {
    print STDERR "Cannot find good perl directories, quiting\n";
    exit $BADEXIT;
}

use lib split(':',$RADISH_PERL_LIB);

require pipeline_utilities ;
#require retrieve_archived_data;
require Headfile;



use civm_simple_util qw(sleep_with_countdown  $debug_val mod_time);
$debug_val=25;


my %opt;
use Getopt::Std;
if (! getopts('ud:', \%opt)) {
    usage_message("Problem with command line options.\n");
}



#my $file_pat='((.*\.nii(?:\.gz)?)|(.*\.txt)|(.*\.xml))$';
#my $file_pat="((.*\.nii(?:\.gz)?)|(.*\.txt)|(.*\.xml))\$";
#my $file_pat="((.*\.nii(\.gz)?)|(.*\.txt)|(.*\.xml)|(.*\.am))\$";
my $file_pat="((.*\.nii(\.gz)?)|(.*\.txt)|(.*xls)|(.*xlsx)|(.*\.xml)|(.*\.am))\$";
#  my ($identifier,@required_values) = @_;#runno
#my ($local_input_dir, $local_work_dir, $local_result_dir, $result_headfile, $EC)=new_get_engine_dependencies('PU_TEST',());
my $EC      =load_engine_deps();
#my @runs = ('/Users/BiGDATADUMP/14.gaj.33/S65177.nii','/Users/BiGDATADUMP/14.gaj.33/S65180.nii','/Users/BiGDATADUMP/14.gaj.33/S65183.nii');
my @list=();

#print($EC->get_value("engine_data_directory")."\n");

foreach (make_list_of_files($EC->get_value("engine_data_directory")."/atlas",$file_pat) ) { push(@list,$EC->get_value("engine_data_directory")."/atlas/$_"); }

my @atlas_dir_contents=make_list_of_files($EC->get_value("engine_data_directory")."/atlas","[^.]+");
my @dirs_to_check=();
push(@dirs_to_check,@ARGV);
for(my $fn=0;$fn<=$#atlas_dir_contents;$fn++){
    my $thing=$EC->get_value("engine_data_directory")."/atlas".'/'.$atlas_dir_contents[$fn];
    if ( -d $thing && !  -l $thing ) {
	if (-r $thing ){ 
	    # Directory, and readable
	    push(@dirs_to_check,$thing);
	} else {
	    # Directory, but unreadable
	    print("Ignoring $thing: could not read.\n");
	}
    } else {
	# File, but its a link, check same as files.
	if ( -l $thing) {
	    print("Adding link $thing\n");
	    push (@list,$thing);
	}
    }
}
print(join(" ",@dirs_to_check)."\n");
#print($#dirs_to_check."\n");
#engine_data_directory
while($#dirs_to_check>=0 ) { 
    my $t_dir=shift @dirs_to_check;
    print("Adding contents of dir $t_dir\n");
    my @filenames=make_list_of_files($t_dir,$file_pat);
    for(my $fn=0;$fn<=$#filenames;$fn++){
	push(@list,$t_dir.'/'.$filenames[$fn]);
    }
}


my @canon_images=make_list_of_files($EC->get_value('engine_waxholm_canonical_images_dir'),$file_pat);
foreach (@canon_images){push(@list,$EC->get_value('engine_waxholm_canonical_images_dir')."/$_"); }
my @canon_labels=make_list_of_files($EC->get_value('engine_waxholm_labels_dir'),$file_pat);
foreach (@canon_labels){push(@list,$EC->get_value('engine_waxholm_labels_dir')."/$_"); }

if ( $#list < 0  ) {
    print("Dir empty:".$EC->get_value('engine_waxholm_canonical_images_dir')." and ".$EC->get_value('engine_waxholm_canonical_images_dir').".\n");
}


if ( $#list < 0  ) {
    print("All dirs empty\n");
} else {
    print(join(" ",@list)."\n");
}
    
my @fail_lists=();

{ 

=pod 

hoaoa.pm
aoaref_get_single
aoaref_get_subarray
aoaref_get_length
aoaref_get_sub_length
aoaref_to_singleline
aoaref_to_printline
array_find_by_length
aoa_hash_to_headfile
display_header
display_header_entry
single_find_by_value
printline_to_aoa

=cut 

}

# lets orgaznize failures by directory. 
# for each directory, lets make an array as we go. 
# After we've looked at all fo them, we'll dump that file to a failure file in the the directory.
# Then we'll dump the commands to rename current md5's 
my $fail_dirs; # this'll be a hash_ref to hash of arrays, I guess it could just be a hash proper...
print("checking ".scalar(@list)." files\n"); 
#exit;
#for my $file (@list[0..60] ) {
for my $file (@list ) {
    #print("Test, checksum of file $file\n");
    #my $exit_code=data_integrity($file);
    my $integrity=data_integrity($file,2);
    # if( ! $integrity ) { 	print(" failure ".$file."\n"); }
    if ( length($integrity)>1 || ! $integrity ) {
	print(" failure ".$file."\n");
	my ($p,$n,$e)=fileparts($file,2);
	#push(@{$fail_dirs->{$p}},$n.$e);
	$fail_dirs->{$p}->{$n.$e}=$integrity;
    } else { 
	print("$file good!\n"); 
    }
}

#dump($fail_dirs);
print("Waiting to proceed with auto fix of move md5 to mod date, and save new\n");
#$debug_val=10;
if ( defined $opt{u} ) { # -u update md5's
    sleep_with_countdown(8);
}
for my $dir (keys %$fail_dirs){
    #my $files=$fail_dirs->{$dir};
    my @files=keys( %{$fail_dirs->{$dir}});
    #dump(@files);
    #next;
    ##### INSERT FAILURE HANDLING HERE!
    print("$dir had ".scalar(@files)." failures\n");
    if ( 1 || defined $opt{u} ) { # -u update md5's
	for my $ne (@files) {
	    my ($p,$n,$e)=fileparts($dir.$ne,3);
	    #my $chk_file=$p.$n.'.md5'; #previous checksum format where we dropped the file extension.
	    my $chk_file=$p.$n.$e.".md5";
	    #Headfile.pm:    #my ($s,$m,$h,$mday,$mon,$year,$wd,$yd,$is) = localtime(time);
	    #my ($s,$m,$h,$mday,$mon,$year,$w,$y,$isdst) = localtime(mod_time($chk_file));
	    print("checking file $chk_file ");
	    my ($sec, $min, $hour, $day,$month,$year) = (localtime(mod_time($chk_file)))[0,1,2,3,4,5]; 
	    $year+=1900;
	    #use DateTime;
	    #my $dt = DateTime->from_epoch( epoch => mod_time($chk_file));
	    #my $year= $dt->year;
	    #my $month=$dt->month;
	    #my $day=$dt->day;
	    #my $hour=$dt->hour;
	    #my $min=$dt->min;
	    #my $sec=$dt->sec;

	    print("-> $p$n.$year-$month-$day.md5\n");# $year-$month-$day $hour:$min:$sec \n");
	    
	}

    }
}
