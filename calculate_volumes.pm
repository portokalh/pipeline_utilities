#!/usr/local/pipeline-link/perl
# calculate_volumes.pm 
# utility pm for getting the volume of structure data and saving it to a text file. 
# calls a matlab function to do the real work. 
# the matlab function also compacts the label range to 0-nlabels. 
# ANTS likes to put out scalled labels from 1-255(8-bit max). 
# Avizo doesnt like labels in that format, so while we're loaded for the volume 
# calculation, we fix that. 
# 
# created 2012/04/06 by james cook for civm.



use strict;

my  $CALC_MFUNCTION = 'write_vols2';  # an mfile function in matlab directory, but no .m here 
my $ggo = 1;
my $debug_val=35;

# ------------------
sub calculate_volumes {
# ------------------
  my ($go, $Hf_out) = @_;
  $ggo=$go;
  # pull a setid-nii key from a head file and calculate volumes for that.
  my @channel_array=split(',',$Hf_out->get_value('runno_ch_commalist'));
  my $channel1=@channel_array[0];
  my $atlas_id  = $Hf_out->get_value('reg-target-atlas-id');
  my $hf_nii_id="${channel1}-reg2-${atlas_id}-label-path";
#  $Hf->set_value("${channel1}-reg2-${atlas_id}-label-file",$result_file);
#  $Hf->set_value("${channel1}-reg2-${atlas_id}-label-path", ${rpath} . ${result_file} . ${rext});
  my $in_nii    = $Hf_out->get_value("${hf_nii_id}");

  #my $initfile=$in_nii;
  my ($name,$path,$ext)=fileparts($in_nii);
  my $out_nii=$path . $name . "_cr" . $ext;
  my $volumefile = $path . $name . "_vols" . ".txt"; 
  log_info("calculate_volumes\n\tinput:$in_nii\n\toutput:$volumefile:\n\toutlabels:$out_nii") if ($debug_val>=35);
  calculate_label_nii_volumes($in_nii,$out_nii,$volumefile,$atlas_id,$Hf_out);
#  $Hf->set_value("${channel1}-reg2-${atlas_id}-label-file",$result_file);
  $Hf_out->set_value("${channel1}-labels-consecutive-range-path"        ,"$out_nii");
  $Hf_out->set_value("${channel1}-labels-consecutive-range-volumes-path","$volumefile");
  


  return;
}

# ------------------
sub calculate_label_nii_volumes
# ------------------
{
    my ( $in_nii,$out_nii,$vol_out,$atlas_id, $Hf_out) = @_;

    my $args = "\'$in_nii\',\'$out_nii\',\'$vol_out\',\'$atlas_id$\'";
    
    my $cmd =  make_matlab_command ($CALC_MFUNCTION, $args, "volume_calc", $Hf_out); 
    if (! execute($ggo, "label volume calculation", $cmd) ) {
    error_out("Matlab could not calculate volums of labels in nifti file: ${in_nii}.\n  using $cmd\n");
    }
    if (! -e $out_nii) {
	error_out("Matlab did not create nifti file $out_nii.\n  using $cmd\n");
    }
    


    return;
}

1;

