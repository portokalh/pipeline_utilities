#!/usr/local/pipeline-link/perl
# apply_coil_bias.pm
# 2011/09/08 James Cook
# one main function, apply_coil_bias, see usage notes below
use strict;
require headfile;
my $ggo = 1;

# ------------------
sub apply_coil_bias {
# ------------------
# takes 4 inputs, 
#  ($go, $data_setid, $HfResult, $HfInput) 
# $go          , should this run or not.
# $data_setid  , prefix for required 2 keys in head file, 
# $HfResult    , headfile which we READ and write, (so its kind of a misnomer here)
# $HfInput     , headfile which we started the pipelien with, probably not used in this function, but unsure 
# engine-app-ants-dir    - location of N4BiasFieldCorrection binary
# ${data_setid}-nii-path - full path to nii to apply coil bias.
# in addition to nii-path will overwrite 2 other keys on completion
# ${data_setid}-nii_file - the nii filename which will be overwritten in the output headfile
# ${data_setid}_bias-field-path - output path of the bias field.

  my ($go, $data_setid, $HfResult, $HfInput) = @_;
  $ggo=$go;
### in the future data_setid could be array, which we look through and apply coilbias to any given element.

  my $ants_app_dir      = $HfResult->get_value("engine-app-ants-dir");
  my $coil_bias_program = "N4BiasFieldCorrection";
  my $coil_bias_program_path = "${ants_app_dir}/${coil_bias_program}";
  my $dimensions = 3;

  my $in_nii = $HfResult->get_value("${data_setid}-nii-path");
  if($ants_app_dir eq "NO_KEY" || $ants_app_dir eq "EMPTY_VALUE" || $ants_app_dir eq "UNDEFINED_VALUE")
  {
      error_out("$ants_app_dir, could not find ants path in headfile. KEY:  engine-app-ants-dir");
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
  my $suffix="bias";
  $file = $file . "_${suffix}.nii";
  my $out_nii = $front . "_${suffix}" . ".nii";
  my $out_field = $front . "_${suffix}_field" . ".nii";
## need to set ${data_setid}-nii-file and ${data-setid}-nii-path
  $HfResult->set_value("${data_setid}-nii-file",$file);
  $HfResult->set_value("${data_setid}-nii-path",$out_nii);
  $HfResult->set_value("${data_setid}-${suffix}-field-path",$out_field);
 

#./N4BiasFieldCorrection 3 -i /Volumes/xtrinity/orig.nii -s 2 -c [ 1000x1000x1000,0.0002] -o [ /Volumes/xtrinity/orig_bias.nii,/Volumes/xtrinity/orig_field.nii]
  my $params = "$dimensions -i $in_nii -o [ $out_nii,$out_field ] -s 2 -c [ 1000x1000x1000,0.0002] ";
  my $cmd = "$coil_bias_program_path " . "$params";
#./ImageMath ImageDimension  OutputImage.ext   Operator   Image1.ext   Image2.extOrFloat
  if(!execute($ggo,"$data_setid Coil Bias correction", $cmd))
  {
      error_out("  $data_setid Coil Bias failed.");
  }
  
  if(! $ggo){
      log_info("Coil Bias function run but not applied");
  }
  return ;
  
}

1;

