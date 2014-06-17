#!/usr/local/pipeline-link/perl
# apply_noise_reduction.pm
# 
# 2012/04/02 cleaned up code lint, used better filename code
# created 2011 james cook



use strict;
require Headfile;
require pipeline_utilities; # not sure if i should do this include, might break stuff
my  $BILATERAL_MFUNCTION = 'Bilateral_Point_Filter';  # an mfile function in matlab directory, but no .m here 
use vars qw($GOODEXIT $test_mode);
my $ggo = 1;
my $debug_val=5;
# ------------------
sub apply_noise_reduction {
# ------------------
  my ($go, $hf_nii_id, $Hf_out )= @_; #, $HfInput)
  $ggo=$go;
### in the future hf_nii_id could be array, which we look through and apply noise reduction  to any given element.
### instad use the apply_coil_bias_to_all script, it looks for the runno_ch_commalist key in the headfile and
### runs for each element in there.
  my $dimensions = 3;
  my $in_nii = $Hf_out->get_value("${hf_nii_id}-nii-path");
  if($in_nii eq "NO_KEY" || $in_nii eq "EMPTY_VALUE" || $in_nii eq "UNDEFINED_VALUE") {
      error_out("$in_nii, could not find input nii in headfile. KEY:  ${hf_nii_id}-nii-path");
  }

## need to set ${hf_nii_id}-nii-file and ${data-setid}-nii-path
#  $Hf_out->set_value("${hf_nii_id}-${suffix}-field-path",$out_field);
#  my $params = "$dimensions -i $in_nii -o [ $out_nii,$out_field ] -s 2 -c [ 1000x1000x1000,0.0002] ";

  #./ImageMath ImageDimension  OutputImage.ext   Operator   Image1.ext   Image2.extOrFloat
  my @cmd=();
  $cmd[0] = 'NO NOISE CORRECTION FOUND';
  my $noise_reduction_type = $Hf_out->get_value('noise_reduction');
  if ( $noise_reduction_type eq 'SUSAN') {
      @cmd=fsl_noise_reduction($in_nii, $hf_nii_id,$Hf_out);
  } elsif ( $noise_reduction_type eq 'Bilateral'){
      @cmd=matlab_noise_reduction($in_nii, $hf_nii_id, $Hf_out);
  } elsif ( $noise_reduction_type eq 'ANTS'){
      @cmd=ants_noise_reduction($in_nii, $hf_nii_id, $Hf_out);
  } else {
      error_out("noise correction atempted, but dont recognise noise reduction type <$noise_reduction_type>");
  }
  log_info("Using noise reduction command: @cmd\n");
  if(!execute($ggo,"$hf_nii_id Noise reduction correction", @cmd)) {
      error_out("  $hf_nii_id noise reduction failed.");
  } else { # only set values on sucess, not sure i like this syntax.
#      print("Noise reduction success\n");
      my ($name,$path,$extension)=fileparts($in_nii);
      $name = $name . "_${noise_reduction_type}${extension}";
      my $out_nii = $path . $name ;
      $Hf_out->set_value("${hf_nii_id}-noise-reduction-input-nii-path",$in_nii);
      $Hf_out->set_value("${hf_nii_id}-noise-reduction-applied","true");
      $Hf_out->set_value("${hf_nii_id}-nii-file",$name);
      $Hf_out->set_value("${hf_nii_id}-nii-path",$out_nii);   
  }
  if(! $ggo) {
      log_info("Noise redduction function run but not applied");
  }

#  sleep(15);
  return $GOODEXIT;
  
}
# ------------------
sub matlab_noise_reduction {
# ------------------
    my ( $in_nii, $hf_nii_id, $Hf_out) = @_;
    my @cmdlist=();
    my ($name,$path,$extension)=fileparts($in_nii);
    print("File parts returned path:$path  $name  $extension\n") if( $debug_val>=35);
    my $suffix="Bilateral"; # could make this variable by setting a hf key.
    my $out_nii = $path . $name . "_${suffix}${extension}";
    
    
#    $params = "\'$src_image_path\', \'$image_prefix\', \'$image_suffix\', \'$dest_nii_path\', $xdim, $ydim, $zdim, $nii_datatype_code, $voxel_size, $flip_y, $flip_z, $zstart, $zstop";
    my $params = "\'$in_nii\', \'\', \'$out_nii\'";
    my $cmd =  make_matlab_command ($BILATERAL_MFUNCTION, $params, "$hf_nii_id\_", $Hf_out); 
    push @cmdlist, $cmd;
    return @cmdlist
}

# ------------------
sub fsl_noise_reduction {
# ------------------
    my ( $in_nii, $hf_nii_id, $Hf_out) = @_;
    my $fsl_dir = $Hf_out->get_value("engine-app-fsl-dir");
    my ($name,$path,$extension)=fileparts($in_nii);
    print("File parts returned path:$path  $name  $extension\n") if( $debug_val>=35);
    my $dimensions = 3;
    
    my $noise_reduction_program = "susan";
    my $noise_reduction_program_path = "${fsl_dir}/${noise_reduction_program}";
    if($fsl_dir eq "NO_KEY" || $fsl_dir eq "EMPTY_VALUE" || $fsl_dir eq "UNDEFINED_VALUE") {
	error_out("$fsl_dir, could not find fsl path in headfile. KEY:  engine-app-fsl-dir");
    }
    my $suffix="SUSAN"; # could make this variable by setting a hf key.
    my $out_nii = $path . $name . "_${suffix}${extension}";
    my $out_nigz = $out_nii . ".gz"; 
    my @cmdlist=();
    if ( $suffix eq 'SUSAN' ) {
	my $params ="$in_nii -1 -1 $dimensions 0 0 $out_nii";
	my $cmd = "$noise_reduction_program_path " . "$params";
	my $gzcmd = "gunzip -f " . $out_nigz;
	push @cmdlist, $cmd ;
	push @cmdlist, $gzcmd ;
	# dump the output info anticipating success
    } else {
	error_out("FSL noise reduction program unrecognized, Currently only SUSAN is supported");
    }
    
    return @cmdlist;
}

# ------------------
sub ants_noise_reduction {
# ------------------
    my ( $in_nii, $hf_nii_id, $Hf_out) = @_;
    my @cmdlist=();
    error_out("no ants noise reduction yet");
    return @cmdlist
}


1;
