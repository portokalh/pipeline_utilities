#!/usr/bin/perl
use strict;
use warnings;
use Env qw(PIPELINE_SCRIPT_DIR);
# generic incldues
use Cwd qw(abs_path);
use File::Basename;
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
require retrieve_archived_data;
require Headfile;
#require image_math;
#require registration;

require apply_coil_bias_to_all;
require apply_noise_reduction_to_all;


my $file_pat=".*\.nii(?:[.].*)?";

#  my ($identifier,@required_values) = @_;#runno
#my ($local_input_dir, $local_work_dir, $local_result_dir, $result_headfile, $EC)=new_get_engine_dependencies('PU_TEST',());
my $EC      =load_engine_deps();
#my @runs = ('/Users/BiGDATADUMP/14.gaj.33/S65177.nii','/Users/BiGDATADUMP/14.gaj.33/S65180.nii','/Users/BiGDATADUMP/14.gaj.33/S65183.nii');
my @list=();
my @canon_images=make_list_of_files($EC->get_value('engine_waxholm_canonical_images_dir'),$file_pat);
foreach (@canon_images){push(@list,$EC->get_value('engine_waxholm_canonical_images_dir')."/$_"); }
my @canon_labels=make_list_of_files($EC->get_value('engine_waxholm_labels_dir'),$file_pat);
foreach (@canon_labels){push(@list,$EC->get_value('engine_waxholm_labels_dir')."/$_"); }

if ( $#list < 0  ) {
    print("Dir empty:".$EC->get_value('engine_waxholm_canonical_images_dir')." and ".$EC->get_value('engine_waxholm_canonical_images_dir').".\n");
}

#print($EC->get_value("engine_data_directory")."\n");


foreach (make_list_of_files($EC->get_value("engine_data_directory")."/atlas",$file_pat) ) { push(@list,$EC->get_value("engine_data_directory")."/atlas/$_"); }

my @atlas_dir_contents=make_list_of_files($EC->get_value("engine_data_directory")."/atlas","[^.]+");
my @dirs_to_check=();
for(my $fn=0;$fn<=$#atlas_dir_contents;$fn++){
    if ( -d $EC->get_value("engine_data_directory")."/atlas".'/'.$atlas_dir_contents[$fn] ) {
	push(@dirs_to_check,$EC->get_value("engine_data_directory")."/atlas".'/'.$atlas_dir_contents[$fn]);
    } else {
    }
}
print(join(" ",@dirs_to_check)."\n");
#print($#dirs_to_check."\n");
push(@dirs_to_check,@ARGV);
#engine_data_directory
while($#dirs_to_check>=0 ) { 
    my $t_dir=shift @dirs_to_check;
    print("Adding contents of dir $t_dir\n");
    my @filenames=make_list_of_files($t_dir,$file_pat);
    for(my $fn=0;$fn<=$#filenames;$fn++){
	push(@list,$t_dir.'/'.$filenames[$fn]);
    }
}

if ( $#list < 0  ) {
    print("All dirs empty\n");
} else {
    print(join(" ",@list)."\n");
}
    

for my $file (@list ) {
    #print("Test, checksum of file $file\n");
    my $exit_code=data_integrity($file);
    if ( ! $exit_code ) {
	print(" failure ".$file."\n");
	
    } else { 
	print("$file good!\n"); 
    }
}
