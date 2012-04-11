#!/usr/local/pipeline-link/perl

# retrieve_archive_dir_util.pm 

# created 2009/10/28 Sally Gewalt CIVM
# assumes ssh identity is all set up
# base use is for user omega to run this and connect to atlasdb:/atlas1 as omega

use strict;
use Env qw(PIPELINE_SCRIPT_DIR);
#require Headfile;
use lib "$PIPELINE_SCRIPT_DIR/pipeline_utilities";
require pipeline_utilities;

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
  my $cmd = "scp -qr omega\@atlasdb:/atlas1/$subproject/$runno  $local_dest_dir/$runno";
  my $final_dir = "$local_dest_dir/$runno";
  #print ("DO_PULL = $do_pull\n");
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

1;

