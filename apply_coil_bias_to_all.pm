#!/usr/local/pipeline-link/perl
# apply_coil_bias_to_all.pm
# should take a seg_pipe  headfile and apply coilbias to each input using the utility apply_coil_bias
# requires a runno_ch_commalist key in headfile, will tell coil_bias to look up each ch_id in that array.
# 
# created 2012/04/02 James cook


use strict;
require apply_coil_bias;
my $debug_val=5;


# ------------------
sub apply_coil_bias_to_all {
# ------------------
  my ($go, $Hf_out)  = @_;
### coil bias inputs.
###  my ($go, $data_setid, $HfResult, $HfInput) = @_; # apparently doesnt nead hfinput
  my @channel_array=split(',',$Hf_out->get_value('runno_ch_commalist'));


# -- open, read headfile belonging to  each runno for image params
  my @cmd_list;
  my $nii_ch_id;
  for my $ch_id (@channel_array) {
      print "coil biasing calculating on channel $ch_id\n"; 
      apply_coil_bias($go, $ch_id, $Hf_out);
  }

}


1;

