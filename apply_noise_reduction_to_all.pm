#!/usr/local/pipeline-link/perl
# apply_noise_reduction_to_all.pm
# should take a seg_pipe  headfile and apply coilbias to each input using the utility apply_noise_reduction
# requires a runno_ch_commalist key in headfile, will tell noise_reduciton to look up each ch_id in that array.
# 
# created 2012/04/02 James cook


use strict;
require apply_noise_reduction;
my $debug_val=5;


# ------------------
sub apply_noise_reduction_to_all {
# ------------------
  my ($go, $Hf_out)  = @_;
### coil bias inputs.
###  my ($go, $data_setid, $HfResult, $HfInput) = @_; # apparently doesnt nead hfinput
  my @channel_array=split(',',$Hf_out->get_value('runno_ch_commalist'));


# -- open, read headfile belonging to  each runno for image params
  my @cmd_list;
  my $nii_ch_id;
  for my $ch_id (@channel_array) {
      print "noise reduction for channel $ch_id\n"; 
      apply_noise_reduction($go, $ch_id, $Hf_out);
  }

}


1;

