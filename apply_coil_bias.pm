#!/usr/local/pipeline-link/perl
# apply_coil_bias.pm
#
# one main function, apply_coil_bias, see usage notes below
# 2012/04/02 james cook, added logging of the coil bias command to output headfile, also added other headfile keys, to record the input image, and a true flag for when coil bias is applied, 
# 2011/09/08 James Cook
# 
# needs engine[-_]app[-_]ants[-_]dir
# ${hf_id}[-_]nii[-_]]path
# 
use strict;
require Headfile;
require pipeline_utilities; # not sure if i should do this include, might break stuff
use vars qw($GOODEXIT $test_mode);
my $ggo = 1;
my $debug_val=15;


# ------------------
sub apply_coil_bias {
# ------------------
  my ($go, $hf_nii_id, $Hf_out) = @_;
  $ggo=$go;
### in the future hf_nii_id could be array, which we use to create array of image for bias calculation
  my $ants_app_dir      = $Hf_out->get_value("engine-app-ants-dir");

  if($ants_app_dir eq "NO_KEY" || $ants_app_dir eq "EMPTY_VALUE" || $ants_app_dir eq "UNDEFINED_VALUE") {
      $ants_app_dir      = $Hf_out->get_value("engine_app_ants_dir");
      #error_out("$ants_app_dir, could not find ants path in headfile. KEY:  engine-app-ants-dir");
  }
  my $in_nii = $Hf_out->get_value("${hf_nii_id}-nii-path");
  if($in_nii eq "NO_KEY" || $in_nii eq "EMPTY_VALUE" || $in_nii eq "UNDEFINED_VALUE") {
      $in_nii=$Hf_out->get_value("${hf_nii_id}_nii_path");
  }

  if($ants_app_dir eq "NO_KEY" || $ants_app_dir eq "EMPTY_VALUE" || $ants_app_dir eq "UNDEFINED_VALUE") {
      error_out("$ants_app_dir, could not find ants path in headfile. KEY:  engine-app-ants-dir");
  }
  if($in_nii eq "NO_KEY" || $in_nii eq "EMPTY_VALUE" || $in_nii eq "UNDEFINED_VALUE") {
      error_out("$in_nii, could not find input nii in headfile. KEY:  ${hf_nii_id}-nii-path or ${hf_nii_id}_nii_path");
  }


  # 
  my ($status,$out_nii,$out_field)=apply_coil_bias_nohf($go, $ants_app_dir,$in_nii);
  my $suffix="bias";
  my ($name,$path,$extension)=fileparts($out_nii);
  if ( ! $status ) {
      error_out("What a strangly impossible error condidtion you've found");
  } else {  # only set values on sucess, not sure i like this syntax.
    print( "Setting HF Keys\n") if ( $debug_val>=10);
    $Hf_out->set_value("${hf_nii_id}-coil-bias-input-nii-path",$in_nii);
    $Hf_out->set_value("${hf_nii_id}-coil-bias-applied","true");
    $Hf_out->set_value("${hf_nii_id}-nii-file",$name);
    $Hf_out->set_value("${hf_nii_id}-nii-path",$out_nii);
    $Hf_out->set_value("${hf_nii_id}-${suffix}-field-path",$out_field);
    print("\t". join ("\n\t",("${hf_nii_id}-coil-bias-input-nii-path".$Hf_out->get_value("${hf_nii_id}-coil-bias-input-nii-path"),
			      "${hf_nii_id}-coil-bias-applied".$Hf_out->get_value("${hf_nii_id}-coil-bias-applied"),
			      "${hf_nii_id}-nii-file:".$Hf_out->get_value("${hf_nii_id}-nii-file"),
			      "${hf_nii_id}-nii-path".$Hf_out->get_value("${hf_nii_id}-nii-path"),
			      "${hf_nii_id}-${suffix}-field-path".$Hf_out->get_value("${hf_nii_id}-${suffix}-field-path"))
	  )."\n" );
  }

  return($GOODEXIT);
  
}

# ------------------
sub apply_coil_bias_nohf {
# ------------------
  #my ($go, $hf_nii_id, $Hf_out) = @_;
  my ($go, $ants_app_dir, $in_nii) = @_;  
  $ggo=$go;
### in the future hf_nii_id could be array, which we look through and apply coilbias to any given element.
### instad use the apply_coil_bias_to_all script, it looks for the runno_ch_commalist key in the headfile and
### runs for each element in there.

#   my $ants_app_dir      = $Hf_out->get_value("engine-app-ants-dir");

#   if($ants_app_dir eq "NO_KEY" || $ants_app_dir eq "EMPTY_VALUE" || $ants_app_dir eq "UNDEFINED_VALUE") {
#       $ants_app_dir      = $Hf_out->get_value("engine_app_ants_dir");
#       #error_out("$ants_app_dir, could not find ants path in headfile. KEY:  engine-app-ants-dir");
#   }
  my $coil_bias_program = "N4BiasFieldCorrection";
  my $coil_bias_program_path = "${ants_app_dir}/${coil_bias_program}";
  my $dimensions = 3;
#   my $in_nii = $Hf_out->get_value("${hf_nii_id}-nii-path");
#   if($in_nii eq "NO_KEY" || $in_nii eq "EMPTY_VALUE" || $in_nii eq "UNDEFINED_VALUE") {
#       $in_nii=$Hf_out->get_value("${hf_nii_id}_nii_path");
#   }

  my $iterations="1000x1000";
  my $shrink="4x2";

  if ( defined($test_mode)) {
      if ($test_mode==1) {
	  $iterations="1";
	  $shrink="1";
	  print STDERR "  TESTMODE enabled, will do very fast (incomplete) coil bias calc! (-t)\n" if ($debug_val>=5);
      }
  }  
  my ($name,$path,$extension)=fileparts($in_nii);
  print("File parts returned path:$path  $name  $extension\n") if( $debug_val>=35);
  my $suffix="bias"; 
  my $out_nii = $path . $name . "_${suffix}${extension}";
  my $out_field = $path . $name . "_${suffix}_field${extension}";

## need to set ${hf_nii_id}-nii-file and ${hf_nii_id}-nii-path
#./N4BiasFieldCorrection 3 -i /Volumes/xtrinity/orig.nii -s 2 -c [ 1000x1000x1000,0.0002] -o [ /Volumes/xtrinity/orig_bias.nii,/Volumes/xtrinity/orig_field.nii]
#tighter convergence added 0, added two level its
  my $params = "-d $dimensions -i $in_nii -o [ $out_nii,$out_field ] -s ${shrink} -c [ ${iterations},0.00002] ";
  my $cmd = "$coil_bias_program_path " . "$params";
#./ImageMath ImageDimension  OutputImage.ext   Operator   Image1.ext   Image2.extOrFloat
  log_info("Useing coil bias comand: $cmd\n");
  if(!execute($ggo,"$name Coil Bias correction", $cmd)) {
      error_out("  $name Coil Bias failed.");
  } else {  # only set values on sucess, not sure i like this syntax.
      if (! -f $out_nii ) { 
	  my $prog="$ants_app_dir/ImageMath ";
	  my $dimensions = 3;
	  my $params=" $dimensions  $out_nii   / $in_nii     $out_field";
	  my $cmd=$prog  . $params;
	  my @cmd_list;
	  push @cmd_list, $cmd;
	  log_info("  $name Coil Bias apply command is $cmd");
          my $ok = execute_indep_forks(1, "Apply Coil bias to each image", @cmd_list);
	  if (! $ok) {
	      error_out("coil bias apply failed -> $out_nii\n");
	  }
      }
#       print( "Setting HF Keys\n") if ( $debug_val>=10);
#       $Hf_out->set_value("${hf_nii_id}-coil-bias-input-nii-path",$in_nii);
#       $Hf_out->set_value("${hf_nii_id}-coil-bias-applied","true");
#       $Hf_out->set_value("${hf_nii_id}-nii-file",$name."_".$suffix.$extension);
#       $Hf_out->set_value("${hf_nii_id}-nii-path",$out_nii);
#       $Hf_out->set_value("${hf_nii_id}-${suffix}-field-path",$out_field);
# >>>>>>> .r2241
#       print("\t". join ("\n\t",("${hf_nii_id}-coil-bias-input-nii-path".$Hf_out->get_value("${hf_nii_id}-coil-bias-input-nii-path"),
# 				"${hf_nii_id}-coil-bias-applied".$Hf_out->get_value("${hf_nii_id}-coil-bias-applied"),
# 				"${hf_nii_id}-nii-file:".$Hf_out->get_value("${hf_nii_id}-nii-file"),
# 				"${hf_nii_id}-nii-path".$Hf_out->get_value("${hf_nii_id}-nii-path"),
# 				"${hf_nii_id}-${suffix}-field-path".$Hf_out->get_value("${hf_nii_id}-${suffix}-field-path") )
#	    )."\n" );
  }

  if(! $ggo) {
      log_info("Coil Bias function run but not applied");
  }
  return ($GOODEXIT,$out_nii,$out_field);
  
}

1;

