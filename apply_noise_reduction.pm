#!/usr/local/pipeline-link/perl

# convert_to_nifti_util.pm 

# created 2009/10/28 Sally Gewalt CIVM

# consider this library for nifti? http://nifti.nimh.nih.gov/pub/dist/src/
# http://afni.nimh.nih.gov/pub/dist/doc/program_help/nifti_tool.html

use strict;

my  $NIFTI_MFUNCTION = 'civm_to_nii_may';  # an mfile function in matlab directory, but no .m here 
# _may version includes flip_z (_feb does not)
  # note: nii conversion function requires big endian input image data at this time
  # note: function handles up to 999 images in each set now
my $ggo = 1;

# ------------------
sub apply_noise_reduction {
# ------------------
# convert the source image volumes used in this SOP to nifti format (.nii)
# could use image name (suffix) to figure out datatype
# takes 4 inputs, 
#  ($go, $data_setid, $HfResult, $HfInput) 
# $go          , should this run or not.
# $data_setid  , prefix for required 2 keys in head file, 
# $HfResult    , headfile which we READ and write, (so its kind of a misnomer here)
# $HfInput     , headfile which we started the pipelien with, probably not used in this function, but unsure 
# engine-app-fsl-dir     - location of fsl binarys
# ${data_setid}-nii-path - full path to nii to apply noise reduction.
# in addition to nii-path will overwrite 2 other keys on completion
# ${data_setid}-nii_file - the nii filename which will be overwritten in the output headfile

  my ($go, $data_setid, $HfResult, $HfInput) = @_;
  $ggo=$go;
### in the future data_setid could be array, which we look through and apply noise reduction  to any given element.

  my $fsl_dir      = $HfResult->get_value("engine-app-fsl-dir");
  my $noise_reduction_program = "susan";
  my $noise_reduction_program_path = "${fsl_dir}/${noise_reduction_program}";
  my $dimensions = 3;

  my $in_nii = $HfResult->get_value("${data_setid}-nii-path");
  my @keys= $HfResult->get_keys();
  if($fsl_dir eq "NO_KEY" || $fsl_dir eq "EMPTY_VALUE" || $fsl_dir eq "UNDEFINED_VALUE")
  {
      error_out("$fsl_dir, could not find fsl path in headfile. KEY:  engine-app-fsl-dir\nkeylist is @keys");
  }
  if($in_nii eq "NO_KEY" || $in_nii eq "EMPTY_VALUE" || $in_nii eq "UNDEFINED_VALUE")
  {
      error_out("$in_nii, could not find input nii in headfile. KEY:  ${data_setid}-nii-path");
  }
  my @parts = split '\.', $in_nii;
  my $found_suffix = pop @parts;
  my $front = join '.', @parts;
  @parts = split '/', $front; 
  my $file = pop @parts;  
  my $suffix="SUSAN";
  $file = $file . "_${suffix}.nii";
  my $out_nii = $front . "_${suffix}" . ".nii";
#  my $out_field = $front . "_${suffix}_field" . ".nii";
## need to set ${data_setid}-nii-file and ${data-setid}-nii-path
  $HfResult->set_value("${data_setid}-nii-file",$file);
  $HfResult->set_value("${data_setid}-nii-path",$out_nii);
#  $HfResult->set_value("${data_setid}-${suffix}-field-path",$out_field);
  my $out_nigz = $out_nii . ".gz"; 
  
#  my $params = "$dimensions -i $in_nii -o [ $out_nii,$out_field ] -s 2 -c [ 1000x1000x1000,0.0002] ";
  my $params ="$in_nii -1 -1 $dimensions 0 0 $out_nii";
  my $cmd = "$noise_reduction_program_path " . "$params";
  #./ImageMath ImageDimension  OutputImage.ext   Operator   Image1.ext   Image2.extOrFloat
  if(!execute($ggo,"$data_setid Noise reduction correction", $cmd))
  {
      error_out("  $data_setid noise reduction failed.");
  }
  my $gzcmd = "gunzip -f " . $out_nigz;
  if(-e $out_nigz)
  {
      if(!execute(1,"gunzipping noise corrected nifti",$gzcmd))
      {
	  error_out("Failed to unzip noise corrected nifti $out_nigz\n with command $gzcmd");
      }
  }
  if(! $ggo){
      log_info("Noise redduction function run but not applied");
  }
  return ;
  
}

1;
