################################################################################
# james cook
# agilent::hf hf.pm
=head1 hf.pm

module to hold functions for dealing with agilent to hf conversion and details

=cut

=head1 sub's
=cut
=over 1
=cut

################################################################################
package agilent::hf;
use strict;
use warnings;
use Carp;
use List::MoreUtils qw(uniq);
use agilent qw(aoaref_to_printline aoaref_to_singleline aoaref_get_subarray aoaref_get_single);
use civm_simple_util qw(printd whoami whowasi debugloc sleep_with_countdown $debug_val $debug_locator);
#use vars qw($debug_val $debug_locator);
use Headfile;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(agilent_hash_to_headfile copy_relevent_keys);
#my $debug=100;


=item agilent_hash_to_headfile

input: ($agilent_header_hash_ref, $headfile_ref , $prefix_for_elements)

 agilent_header_hash_ref - hashreference for the agilent header this module
creates.
 headfile_ref - ref to civm headfile opend by sally's headfile code 
 preffix_for_elements -prefix to put onto each key from agilent_header

output: status maybe?

=cut
###
sub agilent_hash_to_headfile {  # ( $agilent_header_ref, $hf , $prefix_for_elements)
###
    my ($agilent_header_ref,$hf,$prefix) = @_; debugloc();
    if ( ! defined $prefix ) { 
        carp "Prefix undefined when converting agilent header hash to CIVM headfile";
    }
    my @hash_keys=();#qw/a b/;
    @hash_keys=keys(%{$agilent_header_ref});
    my $value="test";
    printd(75,"Hashref:<$agilent_header_ref>\n");
    printd(55,"keys @hash_keys\n");
    if ( $#hash_keys == -1 ) { 
        print ("No keys found in hash\n");
    } else {
        foreach my $key (keys %{$agilent_header_ref} ) {
            $value=aoaref_to_printline(${$agilent_header_ref}{$key});
	    if ( $value eq "BLANK" ) { 
		$value = '';
	    }
            $hf->set_value("$prefix$key",$value);
        }
    }
    return;
}

=item copy_relvent_keys
  
input:($agilent_header_hash_ref, $headfile_ref)

 agilent_header_hash_ref - hashreference for the agilent header this module
creates.
 headfile_ref - ref to civm headfile opend by sally's headfile code 
      
Grabs all the important keys from the agilent header and puts them into
the civm headfile format.  Has hash of hfkey agilentaliaslist. Will run
foreach hfkey, and then check each agilentalias. Making sure that
agilentaliaslist agrees. Then will check at end of aliaslist that key
is defined.

Runs in two stages, first stage grabs the variables, second stage fixes 
up selected values to what we expect in civm headers.

output: status maybe?

=cut
###
sub copy_relevent_keys  { # ($agilent_header_hash_ref, $hf)
###
# array sizes are mentioned for the test data, may break for other data
# array dimensions are not frequcney,phase,slices(encodes), which is x any y must be figure out through the orietnation codeds and others.
    my (@input)=@_;
    my $old_debug=$debug_val;
    my $agilent_header_hash_ref=shift @input;
    my $hf=shift @input;
    $debug_val = shift @input or $debug_val=$old_debug;
#   my ( $agilent_header_hash_ref,$hf,$debug_val) = @input; 
    debugloc();
    my $agilent_prefix=$hf->get_value("U_prefix");
    my $report_order=$hf->get_value("B_axis_report_order");
    my $vol_type=$hf->get_value("B_vol_type");
    my $vol_detail=$hf->get_value("B_vol_type_detail");
    
    my %hfkey_baliaslist=( # hfkey=>[multiplier,alias1,alias2,aliasn] 
			   "unix scan date"=>[
			       1,
			       'ACQ_abs_time',            # starting or ending acquision time in a unix time stamp
			   ],
			   "alpha"=>[
			       1,
			       'flip1',                   # seems to be consistent place to pick up the flip angle.,
			                                  # Might need to look at flip2 as well. 
			   ],
			   "agilent scan date"=>[
			       1,
			       'date',                # starting or ending acquision time , but its bad, it is  listed as an array but it only has one value, so the agilent parsecolonecomma function breaks on this one, should ignore and just abs time 
			   ],
			   "navgs"=>[
			       1,
#			       'UNKNOWN', 
			   ],
			   "nex"=>[
			       1,
#			       'UNKNOWN',     
			   ],
			   "bw"=>[
			       (1/2),
			       'sw',
			   ],
#			   "B_NRepetitions"=>[
#			       1,
#			       'UNKNOWN',     			       
#			   ],
			   "tr"=>[
			       1000000,
			       'tr',
			   ],
			   "te"=>[
			       1000,
			       'first_te',
			   ],
			   "S_PSDname"=>[
			       1,
			       'seqfil',
			   ],
			   "te2"=>[
			       1000,
			       'te_spacing',
			   ],
			   "ne"=>[
			       1,
			       'nechos',
			   ],
#			   "PVM_NEchoImages"=>[
#			       1,
#			       'PVM_NEchoImages',
#			   ],         # might be part of the nav nex nrepetitions problem., moved to special omit keys as it is not specified for mge sequences
#"B_axis_report_order";
#       'PVM_SPackArrReadOrient',  # tells which of the read out orientations we're in. We think there are only 3, so H_F, A_P, and L_R
#         "rplane"=> [
#             1,
#             'PVM_SPackArrSliceOrient', # (sag|cor|ax), could easily convert those and not use the param file value. 
#                                        # acq orientation for for the xy plane. ex, sagital coronal axial
#         ],
#       'PVM_ScanTimeStr',         # how long the whole scan was( i think, hope it isnt per volume)
#"slthick";

# we'll get bit deptha nd data typre right away from the detmine type function, that seems more appropriate.
#"B_input_bit_depth"
#"B_input_data_type"
#       'RECO_wordtype',           # bit depth and type
#       'PVM_DwBMat',              # DtiEpi key, 7 subarrays of 3x3 
#       'PVM_DwBvalEach',          # DtiEpi key, bvalue per item, the set number? but not the actuall?(guesssing due to the dwmaxbvalkey
#       'PVM_DwMaxBval',           # DtiEpi key, bvalue maximum? unsure...
#       'PVM_DwDir',               # DtiEpi key, 7 subarrays of 3 each
#       'PVM_DwGradVec',           # DtiEpi key, 7 subarrays of 3x3, this should be the bvalue matrix.
#       'PVM_DwNDiffExp',          # DtiEpi key, n diffusion experiments, 
#       'PVM_DwNDiffExpEach',      # DtiEpi key, n diffusion scans per experiment, (not sure if this is going to be discreet volumes or what, so we'll error if this is over 1 until that happens. 
        );
    
    my @agilentkeys=( #for now this information is largly out of date, still reflecting bruker data
#"unix scan date";      
        'time_run',            # starting or ending acquision time in a unix time stamp
#"alpha";
        'flip1',          # seems to be consistent place to pick up the flip angle.
#"scan date";   
        'date',                # starting or ending acquision time , but its bad, it is  listed as an array but it only has one value, so the agilent parsecolonecomma function breaks on this one, should ignore and just abs time 
#
        'NA',                      # navgs? its just a guesss for now, so far always 1   
#"nex";
        'NAE',                     # nex

        'PVM_NAverages',           # nex?, seems to be the same as NAE, not right, something else, probably NA
#"bw";
        'SW_h',                    # this seems to be in all scan types, not sure about that. this is reported in Hz and we'd like it reported in KHz, so divide by 1000
        'PVM_BandWidths',          # this only happens in some scan types, not sure the what when of this.
#"B_NRepetitions";
#       'NR',                      # repetitions, from ACQ,  not sure on these two keys...
        'PVM_NRepetitions',        # repetitions, from method
#"tr";
#       'ACQ_RepetitionTime',      # tr
        'PVM_RepetitionTime',      # tr
        'PVM_EchoTime',            # te
#"fov_x","fov_y","fov_z"
        'PVM_Fov',                 # fov is handled at the same time as matrix, they are reported in order, frequency phase, the same as dimension. not relevent, because we check it when we look at the pvm matrix size
#"fov_z" 
        'PVM_FovSatThick',         # for 2d acq the slice thickness, should be multiplied by nslices for to calc fov, which will be missing., also should look up slice gap if there is one. 
#"dim_X","dim_Y","dim_Z"
        'PVM_Matrix',              # frequency, phase, encodes(only for 3d sequences, guessing on name encodes)
        'PVM_SPackArrNSlices',     # number of slices per volume if 2dvolume, not relevent, because we check it when we look at the pvm matrix size

#       'PVM_NEchoImages',         # might be part of the nav nex nrepetitions problem., moved to special omit keys as it is not specified for mge sequences
#"B_axis_report_order";
        'PVM_SPackArrReadOrient',  # tells which of the read out orientations we're in. We think there are only 3, so H_F, A_P, and L_R
#"rplane" (sag|cor|ax), could easily convert those and not use the param file value.    
        'PVM_SPackArrSliceOrient', # acq orientation for for the xy plane. ex, sagital coronal axial
        'PVM_ScanTimeStr',         # how long the whole scan was( i think, hope it isnt per volume)
#"slthick";
#"fov_z";
        'PVM_SliceThick',          # thickness of each slice, for 2d acquisitions should multiply by the SPackArrNSlices, not relevent, because we check it when we look at the pvm matrix size
#       'PVM_SpatResol',           # spatial resolution, must look at slice thickness for 2d acquisionts, 

        'Method',                  # acquisition(sequence) type 
#"B_input_bit_depth"
#"B_input_data_type"
        'RECO_wordtype',           # bit depth and type
        'PVM_DwBMat',              # DtiEpi key, 7 subarrays of 3x3 
        'PVM_DwBvalEach',          # DtiEpi key, bvalue per item, the set number? but not the actuall?(guesssing due to the dwmaxbvalkey
        'PVM_DwMaxBval',           # DtiEpi key, bvalue maximum? unsure...
        'PVM_DwDir',               # DtiEpi key, 7 subarrays of 3 each
        'PVM_DwGradVec',           # DtiEpi key, 7 subarrays of 3x3, this should be the bvalue matrix.
        'PVM_DwNDiffExp',          # DtiEpi key, n diffusion experiments, 
        'PVM_DwNDiffExpEach',      # DtiEpi key, n diffusion scans per experiment, (not sure if this is going to be discreet volumes or what, so we'll error if this is over 1 until that happens. 
        );

### clean up keys which are inconsistent for some acq types.    
    
#     if($vol_type eq "2D") {
#         my $temp=pop(@{$hfkey_baliaslist{"nex"}});
#     }
#     if($vol_type eq "4D" && $vol_detail eq "DTI") { 
# 	my $temp=pop(@{$hfkey_baliaslist{"B_NRepetitions"}});
#     }
    
### insert standard keys * multiplier into civm headfile
    for my $hfkey (keys %hfkey_baliaslist) { 
        printd(55,"civmheadfilekey=$hfkey\n");
	my $multiplier=shift @{$hfkey_baliaslist{$hfkey}};
        for my $alias (@{$hfkey_baliaslist{$hfkey}}) {
            #$hf->set_value($key,$1);
            my $hfval=$hf->get_value($hfkey);
            if (defined $agilent_header_hash_ref->{$alias}) {
                my $aval=aoaref_to_printline($agilent_header_hash_ref->{$alias}); #need to do better job than this of getting value.
#                printd(25,"\t$alias=$aval\n");
		if ($multiplier ne "1" ) { $aval=$aval*$multiplier; }
                printd(25,"\t$alias=$aval\n");
                if ($hfval =~ m/^UNDEFINED_VALUE|NO_KEY$/x) {
                    $hf->set_value("$hfkey",$aval);
                } elsif($hfval ne $aval) {
                    confess("$hfkey value $hfval, from alias $alias $aval not the same as prevoious values, alias definition must be erroneous!");
                }
            }
            
        }
    }

### sort out fov
    my $fov_x; 
    my $fov_y;
    my $fov_z;
    my $dx=$hf->get_value("dim_X");
    my $dy=$hf->get_value("dim_Y");
    my $dz=$hf->get_value("dim_Z");
    #dimY stores procpar variable name of dimx fov  Y and X are reversed some or all the time so far
    $fov_x=$hf->get_value($agilent_prefix.$hf->get_value($agilent_prefix."dimY"))*10;
    #dimX stores procpar variable name of dimy fov
    $fov_y=$hf->get_value($agilent_prefix.$hf->get_value($agilent_prefix."dimX"))*10;
    #dimZ stores procpar variable name of dimz fov
    $fov_z=$hf->get_value($agilent_prefix.$hf->get_value($agilent_prefix."dimZ"))*10;
    print("fov_x:$fov_x, fov_y:$fov_y, fov_z:$fov_z\n");
    if (! defined $dx || ! defined $dy ||! defined $dz ) {#||! defined $thick_f ||! defined $thick_p ||! defined $thick_z ){
	croak("Problem resolving FOV!\n");
    } else { 
	$hf->set_value("fovx","$fov_x");
	$hf->set_value("fovy","$fov_y");
	$hf->set_value("fovz","$fov_z");
#	$hf->set_value("volumes","");
    }

### fix up te, 

    my $te1=$hf->get_value("first_te");
    my $te_spacing=$hf->get_value("te_spacing");
#    my $channel_number=$hf->get_value("");
#    my $te="te1";

### individual handling.
    my $specified_orient=$hf->get_value("U_rplane");
#     my $orientation_list_agilent=aoaref_to_printline($agilent_header_hash_ref->{"vorient"}); #need to do better job than this of getting value.
#     my @orientation_agilent=split(',',$orientation_list_agilent);
#     if($#orientation_agilent == 1 ){#multi orientation, should 
# 	@orientation_agilent=split(' ',$orientation_agilent[1]);
#     } elsif($#orientation_agilent == 0) { # single orientation wont specify lengt, will be one value
	
#     }
#     my %orient_alias=( # hfkey=>[multiplier,alias1,alias2,aliasn] 
# 		       "U_rplane"=> [
# 			   'PVM_SPackArrSliceOrient', # (sag|cor|ax), could easily convert those and not use the param file value. 
# 			   # acq orientation for for the xy plane. ex, sagital coronal axial
# 		       ],
# 	);
    my %orientation_alias=(
	"axial"=>"ax",
	"coronal"=>"cor",
	"sagital"=>"sag",
	);
#     foreach (@orientation_agilent) {#error check orientation code
# 	if ($_ ne $orientation_agilent[0]){
# 	    error_out("multile orientations, totally confused, explodenow\n");
# 	}
#     }
#     if ($orientation_alias{$orientation_agilent[0]} ne $specified_orient ) {
# 	my $previous_default=select(STDOUT);
# 	printd(5,"WARNING: recongui orientation does not match header!, Ignoreing recon gui orientation! using $orientation_alias{$orientation_agilent[0]} instead!\ncontinuing in ");
# 	sleep_with_countdown(4);
#     } else { 
# 	printd(25,"INFO: Orientation check sucess!\n");
#     }
#     $hf->set_value("U_rplane",$orientation_alias{$orientation_agilent[0]});
#    $hf->set_value("U_rplane",$bval);
    
#### DTI keys
#### PVM_DwBMat, make a key foreach matrix, and put each matrix in headfileas DwBMat[n]
#     if($vol_type eq "4D" && $vol_detail eq "DTI") { 
# 	my $key="PVM_DwBMat";
# 	if ( defined  $agilent_header_hash_ref->{$key} ) {
# #	    ##$PVM_DwBMat=( 7, 3, 3 )
# 	    my $diffusion_scans=aoaref_get_single($agilent_header_hash_ref->{"PVM_DwNDiffExp"});
# 	    for my $bval (1..$diffusion_scans) {
# 		my @subarray=aoaref_get_subarray($bval,$agilent_header_hash_ref->{$key});
# 		my $text=$subarray[0].','.join(' ',@subarray[1..$#subarray]);
# 		my $bnum=$bval-1;
# 		my $hfilevar="B_${key}_${bnum}";
# 		printd(20,"  INFO: For Diffusion scan $bval key $hfilevar bmat is $text \n") ; 
# 		$hf->set_value("$hfilevar",$text); 
# 	    }
# 	} 
#     }




### clean up keys post insert
    
    return 1;
}

1;
