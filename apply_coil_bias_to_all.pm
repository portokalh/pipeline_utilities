#!/usr/local/pipeline-link/perl
# apply_coil_bias_to_all.pm
# should take a seg_pipe  headfile and apply coilbias to each input using the utility apply_coil_bias
# 
# created 2012/04/02 James cook


use strict;
require apply_coil_bias;
my $debug_val=35;


# ------------------
sub apply_coil_bias_to_all {
# ------------------
  my ($go, $Hf_out)  = @_;
  return 0;
### coil bias inputs.
###  my ($go, $data_setid, $HfResult, $HfInput) = @_; # apparently doesnt nead hfinput
  my @channel_array=split(',',$Hf_out->get_value('runno_ch_commalist'));
  my @runno_array=split(',',$Hf_out->get_value('runno_commalist'));


# -- open, read headfile belonging to  each runno for image params
  my @cmd_list;
  my $nii_ch_id;
  for my $ch_id (@channel_array) {
      print "coil biasing calculating on channel $ch_id\n"; 
      apply_coil_bias($go, $ch_id, $Hf_out, $Hf_out); # the second $hf_out is just a placeholder, we dont use it in apply_coil_bias, it should be cleand out of there. 
  }

}


1;

