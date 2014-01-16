#!/usr/local/pipeline-link/perl

# retrieve_archived_data.pm 
# 2012/04/26  james cook, modified tring to accomidate any archived data we know about. 
#             Uses data type id to guess the right kinda of data.
# created 2009/10/28 Sally Gewalt CIVM
# assumes ssh identity is all set up
# base use is for user omega to run this and connect to atlasdb:/atlas1 as omega

use strict;
use Env qw(PIPELINE_SCRIPT_DIR);
#require Headfile;
use lib "$PIPELINE_SCRIPT_DIR/pipeline_utilities";
require pipeline_utilities;
my $PM="retrieve_archived_data";


# ------------------
sub locate_data { # compatbility stub to call locate_data_util
# ------------------
    funct_obsolete("locate_data","locate_data_util");
    locate_data(@_);
}

# ------------------
sub locate_data_util {
# ------------------
  # Retrieve a source image set from image subproject on atlasdb
  # Also sets the dest dir for each set in the headfile so
  # you need to call this even if $pull_images is false.

  my ($pull_images, $ch_id, $Hf)=@_;
  # $ch_id should be T1, T2, T2star (current CIVM MR SOP for seg),
  # or can be  adc, dwi, fa, e1 for DTI derrived data in research archive
  # for Tensor pipe will be DW0...DW(n-1)

# check set against allowed types, T1, T2W, T2star
  my $dest       = $Hf->get_value('dir-input');
  my $useunderscore=0;
  if ($dest eq "NO_KEY" ) { $dest = $Hf->get_value("dir_input"); 
			  $useunderscore=1;}
  my $subproject = $Hf->get_value('subproject-source');
  if ($subproject eq "NO_KEY" ) { $subproject = $Hf->get_value("subproject_source"); }
  if ($subproject eq "NO_KEY" ) { error_out("cannot see subproject something bad happened"); }
  my $runno_flavor = "$ch_id\-runno";
 
  my $runno = $Hf->get_value($runno_flavor);
  if ($runno eq "NO_KEY" ) { $runno_flavor="${ch_id}_runno"; $runno = $Hf->get_value("$runno_flavor"); } 
  if ($runno eq "NO_KEY" ) { error_out ("couldnt find Id tag for runno:$runno only got <${runno_flavor}>\n"); } 
  my $ret_set_dir;
  my ($image_name, $digits, $suffix);
  if ( $ch_id =~ m/(T1)|(T2W)|(T2star)|(DW[0-9]+)/ ) { # should move this to global options, as archivechannels
#elsif ( $ch_id =~ m/DW[0-9]+/) {
    $ret_set_dir = retrieve_archive_dir_util($pull_images, $subproject, $runno, $dest);  
    my $first_image_name = first_image_name($ret_set_dir, $runno,1); # the 1 ignores missing first image
    ($image_name, $digits, $suffix) = split ('\.', "$first_image_name");
    $Hf->set_value("$ch_id\-image-padded-digits", $digits);
  } elsif ( $ch_id =~ m/(adc)|(dwi)|(e1)|(e2)|(e3)|(fa)/){ # should move this to global options, dtiresearchchannels
    print STDERR "label channel passed to locate_data not a standard image format, Assuming DTI archive format.\n";
    ($ret_set_dir,$image_name) = retrieve_DTI_research_image($pull_images, $subproject, $runno, $ch_id, $dest);
    ($image_name, $suffix) = split ('\.', "$image_name");
  } else {
    error_out("$PM->locate_data: Unreconized channel type: $ch_id, sorry i dont support that yet.\n\tOnly support T1,T2W,T2star,adc,dwi,e1,e2,e3,fa.");
  }
  if($useunderscore==0) {
    $Hf->set_value("$ch_id\-path", $ret_set_dir);
    $Hf->set_value("$ch_id\-image-basename"     , $image_name);
    $Hf->set_value("$ch_id\-image-suffix"       , $suffix);
  }elsif($useunderscore==1){
    $Hf->set_value("$ch_id\_path", $ret_set_dir);
    $Hf->set_value("$ch_id\_image_basename"     , $image_name);
    $Hf->set_value("$ch_id\_image_suffix"       , $suffix);
  }
}



# ------------------
sub retrieve_archive_dir { # stub to call new version
# ------------------
    funct_obsolete("retrieve_archive_dir","retriveve_archive_dir_util");
    my $final_dir=retrieve_archive_dir_util(@_);
    return($final_dir);
}

# ------------------
sub retrieve_archive_dir_util {
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
  my $final_dir = "$local_dest_dir/$runno";
  my $cmd = "scp -qr omega\@atlasdb:/atlas1/$subproject/$runno/  $final_dir";

  #print ("DO_PULL = $do_pull\n");
  my $ok =0;
  if ( ! -d "$final_dir" ) { 
      $ok = execute($do_pull, "archive retrieve", $cmd);
  } else { 
      print STDERR "Found $final_dir, assuming complete, and not pulling. \n\tErrors will occur if nifti-creation is attempted with incomplete copies.\n";
      $ok=1;
      
  }
  if (! $ok) {
    error_out("Could not retrieve archived images for $runno: $cmd\n");
  }
  return ($final_dir);
}
# ------------------
sub retrieve_DTI_research_image {
# ------------------
# Retrieve research derrived data from archive.
# assumes data is archived in subproject/runno/research/tensor$runno.
# tries to pull out a single dti image matching the input tag, 
#  as though it were created by the DTI pipeline.
# returns the directory output and the filename as the result.. 

# e.g. project naming convention 11.alex.01
# e.g. filename: N38848_DTI_fa.nii
# e.g. atlasdb location /atlas1/11.alex.01/research/tensorN38848/

  my ($do_pull, $subproject, $runno, $filetag, $local_dest_dir) = @_;
  if (! -d $local_dest_dir) {
     mkdir $local_dest_dir;
  }
  my $final_dir = "$local_dest_dir/$runno";
  if (! -d $final_dir) {
      mkdir "${final_dir}" or error_out("Unable to make output dir $final_dir");
  }
  # add -q for quiet
  my $basepath = "/atlas1/$subproject/research/tensor$runno";
  my $filename = "${runno}_DTI_${filetag}.nii";
  my $hfname   = "tensor${runno}.headfile";
#  my $filename = "ssh -qr omeaga\@atalsdb: ls $basepath/$filename";
  my @cmd=();
  push @cmd , "scp -qr omega\@atlasdb:$basepath/$filename  $final_dir";
  push @cmd , "scp -qr omega\@atlasdb:$basepath/$hfname  $final_dir/$hfname";

  #print ("DO_PULL = $do_pull\n");
  my $ok = execute($do_pull, "research archive retrieve", @cmd);
  if (! $ok) {
    error_out("Could not retrieve archived images for $runno: @cmd\nFile missing: $filename\n    from path: $basepath");
  }
  return ($final_dir,$filename);
}


# ------------------
sub first_image_name {
# ------------------
# returns complete first (.001., .01, .0001, etc) image name in directory
# note: suffix of civm images can be raw or rawl, i32...
# you may parse this to figure out base image name (e.g. N12345fsimx, etc)
# padding, etc.

  my ($image_set_dir, $runno,$ignore_error) = @_;
  if ( ! defined $ignore_error) {
      $ignore_error=0;
  }
  my $template = "^$runno\\w*\\.0+1\\.\\w+\$";  # note perl eats many of the \
  #print "TEMPLATE: $template\n";
  my @list = make_list_of_files ($image_set_dir, $template);
  my $count_found = $#list + 1;
  if ($count_found != 1) { 
    foreach my $l (@list) {
       print "Found image: $l\n";
     }
     error_out ("Couldn't find unique first image in $image_set_dir (found $count_found, template $template)") unless $ignore_error; 
  }
  my $image = pop @list;
  return ($image);
}

1;

