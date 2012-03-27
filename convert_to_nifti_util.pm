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
my $debug_val=15;

# ------------------
sub convert_to_nifti_util {
# ------------------
# convert the source image volumes used in this SOP to nifti format (.nii)
# could use image name (suffix) to figure out datatype

  my ($go, $data_setid, $nii_raw_data_type_code, $flip_y, $flip_z, $Hf, $Hf_in) = @_;
  $ggo=$go;


  # the input headfile has image description
  # the second value is a more generic version, this was specifically added to support the brukerextract code and bruker images.
  my $xdim    = $Hf_in->get_value('S_xres_img');
  if ($xdim eq "NO_KEY") {
      $xdim    = $Hf_in->get_value('dim_X');
  }
  my $ydim    = $Hf_in->get_value('S_yres_img');
  if ($ydim eq "NO_KEY") {
      $ydim    = $Hf_in->get_value('dim_Y');
  }
  my $zdim    = $Hf_in->get_value('S_zres_img');
  if ($zdim eq "NO_KEY") {
      $zdim    = $Hf_in->get_value('dim_Z');
  }
  my $xfov_mm = $Hf_in->get_value('RH_xfov');
  if ($xfov_mm eq "NO_KEY") {
      $xfov_mm    = $Hf_in->get_value('B_xfov');
  }
  if ($xfov_mm eq "NO_KEY") {
      $xfov_mm    = $Hf_in->get_value('fovx');
  }
  my $yfov_mm = $Hf_in->get_value('RH_yfov');
  if ($yfov_mm eq "NO_KEY") {
      $yfov_mm    = $Hf_in->get_value('B_yfov');
  }
  if ($yfov_mm eq "NO_KEY") {
      $yfov_mm    = $Hf_in->get_value('fovy');
  } 
  my $zfov_mm = $Hf_in->get_value('RH_zfov');
  if ($zfov_mm eq "NO_KEY") {
      $zfov_mm    = $Hf_in->get_value('B_zfov');
  }
  if ($zfov_mm eq "NO_KEY") {
      $zfov_mm    = $Hf_in->get_value('fovz');
  } 
 
  if ($xdim eq "NO_KEY" || $zdim eq "NO_KEY" || $ydim eq "NO_KEY" || $xfov_mm eq "NO_KEY"|| $yfov_mm eq "NO_KEY"|| $zfov_mm eq "NO_KEY") {
      error_out("Could not find good value for xyz or xyz fov\n\tx=$xdim, y=$ydim, z=$zdim, xfov=$xfov_mm\n");
  }


  my $iso_vox_mm = $xfov_mm/$xdim;
  $iso_vox_mm = sprintf("%.4f", $iso_vox_mm);#  
  print ("convert to nifti util \n\txdim:$xdim\txfov:$xfov_mm\n\tydim:$ydim\tzfov:$zfov_mm\n\tzdim:$zdim\tyfov:$yfov_mm\n") if ($debug_val>20);
  print ("ISO_VOX_MM: $iso_vox_mm\n");

#  my $nii_raw_data_type_code = 4; # civm .raw  (short - big endian)
#  my $nii_i32_data_type_code = 8; # .i32 output of t2w image set creator 

  my $nii_setid = 
      nifti_ize_util ($data_setid, $xdim, $ydim, $zdim, $nii_raw_data_type_code, $iso_vox_mm, $flip_y, $flip_z, $Hf);

  ## dimensions are for the SOP acquisition. 
  ##nifti_ize ("input", 512, 256, 256, $nii_raw_data_type_code, 2, $flip_y, $flip_z, $Hf);
  #should become
  #nifti_ize ("T2star", 512, 256, 256, $nii_raw_data_type_code, 0.043, $flip_y, $Hf);
}

# ------------------
sub nifti_ize_util
# ------------------
{

  my ( $setid, $xdim, $ydim, $zdim, $nii_datatype_code, $voxel_size, $flip_y, $flip_z, $Hf) = @_;
  my $runno          = $Hf->get_value("$setid\-runno");  # runno of civmraw format scan 
  my $src_image_path = $Hf->get_value("$setid\-path");
  my $dest_dir       = $Hf->get_value("dir-work");
  my $image_base     = $Hf->get_value("$setid\-image-basename");
  my $padded_digits  = $Hf->get_value("$setid\-image-padded-digits");
  my $image_suffix   = $Hf->get_value("$setid\-image-suffix");
  my $sliceselect    = $Hf->get_value_like("slice-selection");  # using get_value like is experimental, should be switched to get_value if this fails.
  if ($image_suffix ne 'raw') { error_out("nifti_ize: image suffix $image_suffix not known to be handled by matlab nifti converter (just \.raw)");}
#  $Hf->set_value("$setid\_image_suffix", $image_suffix);  # wtf mates? we just read this value out?
  
  my $dest_nii_file = "$runno\.nii";
  my $dest_nii_path = "$dest_dir/$dest_nii_file";
  print("srcpath:$src_image_path\trunno:$runno\n\tdest:$dest_dir\n\timage_name:$image_base\tdigits:$padded_digits\tsuffix:$image_suffix\n") if ($debug_val >10);
  # --- handle image filename number padding (.0001, .001).
  # --- figure out the img prefix that the case stmt for the filename will need (inside the nifti.m function)
  #     something like: 'N12345fsimx.0'
  my $ndigits = length($padded_digits);
  if ($ndigits < 3) { error_out("nifti_ize needs fancier padder"); }
  my $padder;
  if ($ndigits > 3) {
    $padder = 0 x ($ndigits - 3);
  }
  else { $padder = ''; }

  my $image_prefix = $image_base . '.' . $padder;
  my $args;
  if ( $sliceselect eq "all" || $sliceselect eq "NO_KEY" || $sliceselect eq "UNDEFINED_VALUE" || $sliceselect eq "EMPTY_VALUE" ) {        $args =   "\'$src_image_path\', \'$image_prefix\', \'$image_suffix\', \'$dest_nii_path\', $xdim, $ydim, $zdim, $nii_datatype_code, $voxel_size, $flip_y, $flip_z";
  } else {
      my ($zstart, $zstop) = split('-',$sliceselect);
      $args = "\'$src_image_path\', \'$image_prefix\', \'$image_suffix\', \'$dest_nii_path\', $xdim, $ydim, $zdim, $nii_datatype_code, $voxel_size, $flip_y, $flip_z, $zstart, $zstop";
  }
  my $cmd =  make_matlab_command_V2 ($NIFTI_MFUNCTION, $args, "$setid\_", $Hf); 
  if (! execute($ggo, "nifti conversion", $cmd) ) {
    error_out("Matlab could not create nifti file from runno $runno:\n  using $cmd\n");
  }
  if (! -e $dest_nii_path) {
    error_out("Matlab did not create nifti file $dest_nii_path from runno $runno:\n  using $cmd\n");
  }

  # --- required return and setups -----

  my $nii_setid = "$setid\-nii";
  $Hf->set_value("$nii_setid\-file" , $dest_nii_file);
  $Hf->set_value("$nii_setid\-path", $dest_nii_path);
  print "** nifti-ize created [$nii_setid\-path]=$dest_nii_path\n";
  return ($nii_setid);
}

1;

