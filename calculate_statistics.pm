#!/usr/local/pipeline-link/perl
# calculate_statistics.pm 
# utility pm for getting the volume of structure data and saving it to a text file. 
# calls a matlab function to do the real work. 
# the matlab function also compacts the label range to 0-nlabels. 
# ANTS likes to put out scalled labels from 1-255(8-bit max). 
# Avizo doesnt like labels in that format, so while we're loaded for the volume 
# calculation, we fix that. 
# 
# created 2012/04/06 by james cook for civm.



use strict;

my  $CALC_MFUNCTION = 'write_stats';  # an mfile function in matlab directory, but no .m here 
my $ggo = 1;
my $debug_val=35;

# ------------------
sub calculate_statistics {
# ------------------
  my ($go, $Hf_out) = @_;
  $ggo=$go;
  # pull a setid-nii key from a head file and calculate statistics for that.
  my @channel_array=split(',',$Hf_out->get_value('runno_ch_commalist'));


  my @nii_file_array=();
  my $atlas_id  = $Hf_out->get_value('reg-target-atlas-id');
  my $label_path;
  push(@nii_file_array,$Hf_out->get_value("${channel_array[0]}-reg2-${atlas_id}-label-path"));
  for my $channel (@channel_array) {
    #e1-reg2-DTI-path
    my $hf_nii_id="${channel}-reg2-${atlas_id}-path";
    #
    #  $Hf->set_value("${channel}-reg2-${atlas_id}-label-file",$result_file);
    #  $Hf->set_value("${channel}-reg2-${atlas_id}-label-path", ${rpath} . ${result_file} . ${rext});
    my $in_nii    = $Hf_out->get_value("${hf_nii_id}");
    push(@nii_file_array,$in_nii);
  }
  print(' List of files to work on:'.join(' ',@nii_file_array)."\n");


 #my $initfile=$in_nii;
   my ($name,$path,$ext)=fileparts($nii_file_array[0]);
   my $out_nii=$path . $name . "_cr" . $ext;
   my $stat_file = $path . $name . "_stats" . ".txt"; 
  log_info("calculate_statistics\n\tinput:".join(',',@nii_file_array)."\n\tout_labels:$out_nii\n\tout_stats:$stat_file\n") if ($debug_val>=35);
  calculate_label_nii_statistics($out_nii,$stat_file,$atlas_id,$Hf_out,@nii_file_array);
# #  $Hf->set_value("${channel1}-reg2-${atlas_id}-label-file",$result_file);
#   $Hf_out->set_value("${channel1}-labels-consecutive-range-path"        ,"$out_nii");
#   $Hf_out->set_value("${channel1}-labels-consecutive-range-statistics-path","$volumefile");
  


  return;
}

# ------------------
sub calculate_label_nii_statistics
# ------------------
{
    my ($out_labels,$stat_out,$atlas_id, $Hf_out,  @nifti_files) = @_;
    my @arg_a=();
    push(@arg_a,"\{\'".join("\',\'",@nifti_files)."\'\}");
    push(@arg_a,"\'$out_labels\'");
    push(@arg_a,"\'$stat_out\'");
    push(@arg_a,"\'$atlas_id$\'");
    my $args=join(',',@arg_a);
    print("$args\n");
    my $cmd =  make_matlab_command ($CALC_MFUNCTION, $args, "stat_calc", $Hf_out); 
    if (! execute($ggo, "label volume calculation", $cmd) ) {
      error_out("Matlab could not calculate stats for images: ".join(',',@nifti_files).".\n  using $cmd\n");
    }
    if (! -e $out_labels) {
	error_out("Matlab did not create nifti file $out_labels.\n  using $cmd\n");
    }
    


    return;
}

1;

