#!/usr/local/pipeline-link/perl

# retrieve_archived_data.pm 

# created 2009/10/28 Sally Gewalt CIVM
# assumes ssh identity is all set up
# base use is for user omega to run this and connect to atlasdb:/atlas1 as omega

use strict;
use Env qw(PIPELINE_SCRIPT_DIR);
#require Headfile;
use lib "$PIPELINE_SCRIPT_DIR/utility_pms";
require pipeline_utilities;

# ------------------
sub retrieve_archive_dir {
# ------------------
# Retrieve runno (image) directory from archive.
# assumes data is archived in subproject/runno dir ()
# gets entire directory
# returns name of local directory of result set

# e.g. project naming convention 11.alex.01
# e.g. filename: N38848t9imx.0109.raw
# e.g. location /Volumes/cretespace/N38848Labels-inputs/N38848/N38848t9imx.0109.raw 
# e.g. location /Volumes/cretespace/N38848Labels-inputs/N38849FIC/N38849FIC.054.raw
# e.g. location /Volumes/cretespace/N38848Labels-inputs/N38850/N38850t9imx.0109.raw

  my ($do_pull, $subproject, $runno, $local_dest_dir) = @_;
  if (! -d $local_dest_dir) {
     mkdir $local_dest_dir;
  }
  # add -q for quiet
  my $final_dir = "$local_dest_dir/$runno";
  my $cmd = "scp -qr omega\@atlasdb:/atlas1/$subproject/$runno/ $local_dest_dir";
  
  #print ("DO_PULL = $do_pull\n");
  my $ok = execute($do_pull, "archive retrieve", $cmd);
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

1;

