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
use hoaoa qw(aoaref_to_printline aoaref_to_singleline aoaref_get_subarray aoaref_get_single printline_to_aoa);
use agilent qw( @knownmethods);
use civm_simple_util qw(printd whoami whowasi debugloc sleep_with_countdown $debug_val $debug_locator);
#use vars qw($debug_val $debug_locator);
use Headfile;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(set_volume_type copy_relevent_keys);
#my $debug=100;

our $num_ex="[-]?[0-9]+(?:[.][0-9]+)?(?:e[-]?[0-9]+)?"; # positive or negative floating point or integer number in scientific notation.
our $plain_num="[-]?[0-9]+(?:[.][0-9]+)?"; # positive or negative number 

=item set_volume_type($bruker_headfile[,$debug_val])

looks at variables and detmines the volume output type from the
different posibilities.  2D, or 3D if 2d, multi position or single
position 2d, single or multi echo, or multi time (maybe multiecho is
same as multi time.)  3D are there multi volumes? may have to check
for each kind of multivolume are there multi echo's?  (time and or
dti) or slab?

sets headfile values 
    vol_type
    vol_detail 
    vol_num 
    x 
    y 
    z 
    timepoints  
    bit_depth   # expectecd recon type 
    data_type   # expected  recon type
    input_type  # input bit depth and type
    order       # report order of y and x, 
    raworder    # sets order of dimensions in raw data, xyzct, generally its fcept  (order determins if f is y or x, and same for p
=cut
###
sub set_volume_type { # ( agilent_headfile[,$debug_val] )
###
    my (@input)=@_;
    my $hf = shift @input;
    my $old_debug=$debug_val;
    $debug_val = shift @input or $debug_val=$old_debug;
    my $vol_type=1;
    my $vol_detail="single";
    my $vol_num=1; # total number of volumes, 
    my $time_pts=1; # number timepoints
    my $channels=1;
    my $channel_mode='separate'; # separate or integrate, if integrate use math per channel to add to whole image. 
    # this doesnt have much meaning in the reconstruction end of things.
    my $x=0;
    my $y=0;
    my $z=0; # slices per volume
    my $slices=1;#total z dimension 

    my $s_tag=$hf->get_value('S_tag');
    my $data_prefix=$hf->get_value('U_prefix');
    my $extraction_mode_bool=$hf->get_value("R_extract_mode");
    if ( $extraction_mode_bool eq 'NO_KEY') { $extraction_mode_bool=0; }
    my $method;
#     $method = $hf->get_value($data_prefix."ACQ_method");
#     if ( $method eq 'NO_KEY' ) {
# 	croak "Required field missing from bruker header:\"${data_prefix}ACQ_method\" ";
#     }
#     printd(45, "Method:$method\n");
#     my $method_ex="<(".join("|",@knownmethods).")>";
#     if ( $method !~ m/^$method_ex$/x ) { 
#         croak("NEW METHOD USED: $method\nNot known type in (@knownmethods), did not match $method_ex\n TELL JAMES\n"); 
# #\\nMAKE SURE TO CHECK OUTPUTS THROUGHLY ESPECIALLY THE NUMBER OF VOLUMES THEIR DIMENSIONS, ESPECIALLY Z\n");
#     }
#     if ( $method =~ m/MDEFT/x ) {
# 	printd(5,"WARNING WARNING WARNING MDEFT DETECTED!\n".
# 	       "MDEFT PRETENDS TO BE A 2D SEQUENCE WHEN IT IS IN FACT 3D!\n".
# 	       "rad_mat will require special options to run!\n\tvol_type_override=3D\n\tU_dimension_order=xcpyzt\n");
# 	sleep_with_countdown(8);
#     }
### keys which may help
### multi2d
### -arrays 9
###   ACQ_O1B_list ACQ_O1_list ACQ_grad_matrix ACQ_obj_order ACQ_phase1_offset ACQ_phase2_offset ACQ_read_offset ACQ_slice_offset
###   PVM_ObjOrderList PVM_SPackArrGradOrient
### -singles 9
###   ACQ_O1B_list_size ACQ_O1_list_size NI NSLICES
###   PVM_SPackArrNSlices
### multi3d, dti
### -arrays 7
###   ACQ_movie_descr ACQ_time_points
###   PVM_DwBMat PVM_DwEffBval PVM_DwEffGradTraj PVM_DwGradPhase PVM_DwGradRead PVM_DwGradSlice PVM_DwGradVec PVM_DwSpDir
### -singles 7
###  ACQ_n_movie_frames ACQ_nr_completed NR
###  PVM_DwNDiffExp
### multislab
### -arrays 20
###   ACQ_O1B_list ACQ_O1_list ACQ_grad_matrix ACQ_obj_order ACQ_phase1_offset ACQ_phase2_offset ACQ_read_offset ACQ_slice_angle ACQ_slice_offset ACQ_slice_sepn
###   PVM_ObjOrderList PVM_SPackArrGradOrient(20x3x3) PVM_SPackArrNSlices PVM_SPackArrPhase1Offset PVM_SPackArrPhase2Offset PVM_SPackArrReadOffset PVM_SPackArrReadOrient PVM_SPackArrSliceDistance PVM_SPackArrSliceGap PVM_SPackArrSliceGapMode PVM_SPackArrSliceOffset PVM_SPackArrSliceOrient
### -arrays 288
###   ACQ_spatial_phase_1 
###   PVM_EncSteps1
### -singles 20
###   ACQ_O1B_list_size ACQ_O1_list_size DSPFVS NAE NI NSLICES 
###   PVM_FovSatSpoilGrad PVM_InFlowSatSpoilGrad PVM_NAverages PVM_NSPacks
### -single 288
###   ACQ_spatial_size_1   
### 3d single
### -arrays which appear to have length(1) based on above information(its hard to sepearate important places wehre values of 1, or all places with only one element)
###   ACQ_O1B_list ACQ_O1_list ACQ_grad_matrix ACQ_obj_order ACQ_phase1_offset ACQ_phase2_offset ACQ_read_offset ACQ_slice_angle ACQ_slice_offset ACQ_slice_sepn
###   PVM_ObjOrderList PVM_SPackArrGradOrient(01x3x3) PVM_SPackArrNSlices PVM_SPackArrPhase1Offset PVM_SPackArrPhase2Offset 

# 4d dti
# ACQ_time_points array of time points or 0 if only one time point, dti has 7 entries, might be in minutes from start, not really sure
# ACQ_nr_completed should equal ACQ_time_points.
# ACQ_movie_descr, should describe what each timepoint was. For dti, will contain "Dir [1-ACQ_time_points]"

# 3(4?)d slab
# ACQ_spacial_size_1, total size, wont exist for other types?
# ACQ_spacial_size_2, slab size

### collect multivars to check on.
# n_echo_images, never seen not sur what it'll do or how to incorporate
# movie_frames only seen with dti so far. indicates multi volume for sure
# n_dwi_exp, only dti, indicates multi volume, should be linked to movie_frames.
# list_size & list_sie_B indicate multi_volume.
# n_slice_packs, could mean a few things, either multi volume or, that we much multiply slices*nslicepacks, to get the whole volume's worth of slices.
    my $n_echos;
    $n_echos=$hf->get_value($data_prefix.'ACQ_n_echo_images');
    if ( $n_echos eq 'NO_KEY')  {
	$n_echos=1;
    }
    printd(45,"n_echos:$n_echos\n");
#    my $movie_frames;
#     $movie_frames=$hf->get_value($data_prefix."ACQ_n_movie_frames"); # ntimepoints=length, or 0 if only one time point
#     if ( $movie_frames ne "NO_KEY" && $movie_frames>1 ) {  
# 	## set dim_t, perhpas time_pts?
# 	$time_pts=$time_pts*$movie_frames;
# 	printd(45,"movie_frames:$movie_frames\n");
#     }
#     my $n_dwi_exp;
#     $n_dwi_exp=$hf->get_value($data_prefix."PVM_DwNDiffExp");
#     if ( $n_dwi_exp ne 'NO_KEY'  && $n_dwi_exp>1) { 
# 	     printd(45,"n_diffusion_gradients:$n_dwi_exp\n");
#     }
#     my $b_slices;
#     if ( defined $hf->get_value($data_prefix."NSLICES") ) { 
# 	$b_slices=$hf->get_value($data_prefix."NSLICES");
# 	printd(45,"bslices:$b_slices\n");
#     }
#     my $list_sizeB;#(2dslices*echos*time)
#     my $list_size;
#     $list_sizeB=$hf->get_value($data_prefix."ACQ_O1B_list_size");  # appears to be total "volumes" for 2d multi slice acquisitions will be total slices acquired. matches NI, (perhaps ni is number of images and images may be 2d or 3d), doesent appear to accout for channel data.
#     $list_size=$hf->get_value($data_prefix."ACQ_O1_list_size");    # appears to be nvolumes/echos matches NSLICES most of the time, notably does not match on 2d me(without multi slice), looks like its nslices*echos for 2d ms me
#     if ( $list_size ne 'NO_KEY' ) {
# 	printd(45,"List_size:$list_size\n"); # is this a multi acquisition of some kind. gives nvolumes for 2d multislice and 3d(i think) 
# 	printd(45,"List_sizeB:$list_sizeB\n"); 
#     }
#     my @lists=qw(ACQ_O2_list_size ACQ_O3_list_size ACQ_vd_list_size ACQ_vp_list_size);
#     for my $list_s (@lists) { 
# 	if ($hf->get_value($data_prefix.$list_s) != 1 ) { confess("never saw $list_s value other than 1 Unsure how to continue"); }
#     }

    my @slice_offsets;
    my $n_slice_packs=1;
    my $slice_pack_size=1;
   
    my $s_offsets=$hf->get_value($data_prefix."ACQ_slice_offset");
    if ( $s_offsets ne 'NO_KEY') {
#	@slice_offsets=split('test','s'); # MORE WORK TO DO HERE!
	@slice_offsets=printline_to_aoa($hf->get_value($data_prefix."ACQ_slice_offset"));
	shift @slice_offsets;
    }
    
#     $n_slice_packs=$hf->get_value($data_prefix."PVM_NSPacks"); 
#     if ($n_slice_packs ne 'NO_KEY') { 
       
# 	if ( ! defined $n_slice_packs ) {        
#             croak "Required field missing from bruker header:\"PVM_NSPacks\" ";
#         }
#     }
#     $slice_pack_size=$hf->get_value($data_prefix."PVM_SPackArrNSlices");
#     if ($slice_pack_size ne 'NO_KEY' ) {
#        $slice_pack_size=$hf->get_value($data_prefix."PVM_SPackArrNSlices");
#     } else { 
# 	$slice_pack_size=$hf->get_value($data_prefix."NI");
# 	carp("No ${data_prefix}PVM_SPackArrNSlices, using NI instead, could be wrong value ") ;
# 	sleep_with_countdown(4);
#     }
    printd(45,"n_spacks:$n_slice_packs\n");        
    printd(45,"spack_size:$slice_pack_size\n");
### get the dimensions 
# matrix 2 or 3 element vector containing the dimensions, shows wether we're 2d or 3d 
# ACQ_size=2,400 200 pvm_matrix not defined for acquisition only so we'll go with acq size if pvm_matrix undefined. 
# spatial_phase_1, either frequency or phase dimension, only defined in 2d or slab data on rare sequence, unsure for others
# spatial_size_2, 3rd dimension size, should match $matrix[1] if its defined.;
    my @matrix; #get 2/3D matix size
    my $order= "UNDEFINED";  #report_order for matricies
#     if ( $hf->get_value($data_prefix."PVM_EncMatrix") ne 'NO_KEY' ||  $hf->get_value($data_prefix."ACQ_size")ne 'NO_KEY' ) {

# 	( @matrix ) =printline_to_aoa($hf->get_value($data_prefix."PVM_EncMatrix"));
# 	if ( $#matrix == 0 ) { 
	    
# 	}
#         if ( $#matrix > 0 ) { 
# 	     @matrix=@{$hf->{"PVM_EncMatrix"}->[0]};
# 	}

# 	if( ! defined $matrix[0] ) {
# 	    printd(45,"PVM_EncMatrix undefined, or empty, using ACQ_size\n"); ### ISSUES HERE, f direction of acq_size is doubled. 
# 	    @matrix=@{$hf->{"ACQ_size"}->[0]};
# 	} 
# 	if (defined $matrix[0]) { 
# 	    #shift @matrix;
# 	    if ($#matrix>2) { croak("PVM_EncMatrix too big, never had more than 3 entries before, what has happened"); }
# 	    printd(45,"Matrix=".join('|',@matrix)."\n");
# 	}
#     }
#     if (! defined $matrix[0]) {
#         croak "Required field missing from bruker header:\"PVM_EncMatrix|ACQ_size\" ";
#     }
#     # use absence of pvm variables to set the default to UNDEFINED orientation which is x=acq1, y=acq2.
#     if ( defined $hf->{"PVM_SPackArrReadOrient"} ) { 
#         $order=$hf->get_value($data_prefix."PVM_SPackArrReadOrient" );
#         if ( $order eq 'NO_KEY' && $matrix[0]) { 
#             croak("Required field missing from bruker header:\"PVM_SPackArrReadOrient\"");
#         }
#     } else { 
	
#     } 
### get channels
#     if ($hf->get_value($data_prefix."PVM_EncActReceivers") ne 'NO_KEY') { 
# 	$channels=$hf->get_value($data_prefix."PVM_EncNReceivers");
# #	$channel_mode='integrate';
#     }
### get bit depth
    my $bit_depth=32;
    my $data_type="Real";
    my @bd_strings=split(',',$hf->get_value($data_prefix."dp")); #( @bd_lines) 
    my ($bd_code, @bd_opts) = $bd_strings[1] =~ m/([yn])/gx ;
    printd(45,"BitDepth code parsing, input is <".join(",",@bd_strings)."> parsed into bd_code <$bd_code> of possibilities <@bd_opts>\n");
    if ($bd_code eq 'n' ) {
	$bit_depth=16;
	$data_type="Signed";
    }
#     my $recon_type=$hf->get_value($data_prefix."RECO_wordtype");
#     my $raw_type=$hf->get_value($data_prefix."GO_raw_data_format");
#     if ( $recon_type ne 'NO_KEY' || $raw_type ne 'NO_KEY') {
# 	my $input_type;
# 	if ( $recon_type ne 'NO_KEY' && $extraction_mode_bool) { 
# 	    $input_type=$recon_type;
# 	} elsif ( $raw_type ne 'NO_KEY' ) { 
# 	    $input_type=$raw_type;
# 	} else { 
# 	    croak("input_type undefined, did not find either GO_raw_data_format or RECO_wordtype found. ");
# 	}
# 	if ( ! defined $input_type ) { 
# 	    warn("Required field missing from bruker header:\"RECO_wordtype\"");
# 	} else {
# 	    if    ( $input_type =~ /.*_16BIT_.*/x ) { $bit_depth = 16; }
# 	    elsif ( $input_type =~ /.*_32BIT_.*/x ) { $bit_depth = 32; }
# 	    elsif ( $input_type =~ /.*_64BIT_.*/x ) { $bit_depth = 64; }
# 	    else  { warn("Unhandled bit depth in $input_type"); }
# 	    if    ( $input_type =~ /.*_SGN_/x ) { $data_type = "Signed"; }
# 	    elsif ( $input_type =~ /.*_USGN_.*/x ) { $data_type = "Unsigned"; }
# 	    elsif (  $input_type =~ /.*_FLOAT_.*/x ) { $data_type = "Real"; }
# 	    else  { warn("Unhandled data_type in $input_type"); }
# 	}
#     } else { 
# 	warn("cannot find bit depth at RECO_wordtype");
#     }
    
### if both spatial phases, slab data? use spatial_phase_1 as x?y?
### for 3d sequences ss2 is n slices, for 2d seqences it is dim2, thats annoying..... unsure of this
#     my $ss2 = $hf->get_value($data_prefix."ACQ_spatial_size_2");
#     if (  $ss2 ne 'NO_KEY' ) { # exists in 3d, dti, and slab, seems to be the Nslices per vol,
# 	printd(45,"spatial_size2:$ss2\n");
#     } elsif($#matrix==1 && $ss2 eq 'NO_KEY') { #if undefined, there is only one slice. 
#         $ss2=1;
#     }

###### determine dimensions and volumes
#     if ( $order =~  m/^H_F|A_P$/x  ) { 
#         $order ='yx'; 
#         $x=$matrix[1];
#         $y=$matrix[0];
#     } else { 
        $order='xy';
#        $x=$matrix[0];
#        $y=$matrix[1];


### dimX dimY dimX are field of view not voxels
#     $x=$hf->get_value($data_prefix.$hf->get_value($data_prefix."dimX"))/2;    
#     $y=$hf->get_value($data_prefix.$hf->get_value($data_prefix."dimY"));
#     $z=$hf->get_value($data_prefix.$hf->get_value($data_prefix."dimZ")

    $x=$hf->get_value($data_prefix."np")/2;
    $y=$hf->get_value($data_prefix."nv");
    $z=$hf->get_value($data_prefix."nv2");

    if ( $z eq 'NO_KEY' ) { 
     	$z=$hf->get_value("${data_prefix}ns");
    }
# 	if ( ! defined $hf->{"PVM_EncMatrix"}->[0]) {
# 	    $x=$x/2;
# 	    printd(45, "halving x\n");
# 	}
#     }
    printd(45,"order is $order\n");
#     if ( $#matrix ==1 ) {
#         $vol_type="2D";
# 	$slices=$b_slices;
# 	printd(90,"Setting type 2D, slices are b_slices->slices\n");
# 	#should find detail here, not sure how, could be time or could be space, if space want to set slices, if time want to set vols
#     } elsif ( $#matrix == 2 )  {#2 becaues thats max index eg, there are three elements 0 1 2 
	$vol_type="3D";
    my $cycles=$hf->get_value($data_prefix."acqcycles");
    if ( $cycles ne 1  && $hf->get_value("ray_blocks")==1 ) { 
#	$vol_type="2D";
	$hf->set_value("ray_blocks",$cycles);
	carp("\n\nwarning:\n\tCIVM RECONSTRUCTION HAS NEVER HAD SUCESS RECONSTRUCTING IMAGES WITH acqcycles > 1!\n\n");# JAMES HAS FORCED THIS TO BE A FAILURE.\n\n");
    } elsif ( $cycles > 1 && $hf->get_value("ray_blocks") > 1 )  { 
	carp("acqcycles>1 and ray_blocks>1, un expected condition see JAMES!");
#	$hf->set_value("rays_per_block",$hf->get_value("rays_per_block")*$cycles); # this isnt it.
    } else { 
	
    }
# 	if ( defined $ss2 ) { 
# 	    $slices=$ss2;
# 	} else {
# 	    $slices = $matrix[2];
# 	}
#         if ( $slices ne $matrix[2] ) {
#             croak "n slices in question, hard to determing correct number, either2 $slices or $matrix[2]\n";
#         }
#     }   
###### set time_pts    
#     if ( defined $movie_frames && $movie_frames > 1) {  #&& ! defined $sp1 
#         $time_pts=$movie_frames;
    $time_pts=$hf->get_value($data_prefix."volumes");
#         $vol_type="4D";
#         if ( defined $n_dwi_exp ) { 
#             printd(45,"diffusion exp with $n_dwi_exp frames\n");
#             if ( $movie_frames!=$n_dwi_exp) { 
#                 croak "ACQ_n_movie_frames not equal to PVM_DwNDiffExp we have never seen that before.\nIf this is a new method its fesable that ACQ_spatial_phase1 would be defined.";
#             }
#             $vol_detail="DTI";
#         } else { 
#             $vol_detail="MOV";
#         }
#     }
###### set z and volume number
#     printd(45,"LIST:$list_sizeB $slice_pack_size\n");
### if listsize<listsizeb we're multi acquisition we hope. if list_size >1 we might be multi multi 
#     if ( $list_sizeB > 1 ) { 
#         $vol_detail='multi';
#         if($n_slice_packs >1 ) { 
#             $z=$slices*$n_slice_packs*$slice_pack_size; #thus far slice_pack_size has always been 1 for slab data, but we dont want to miss out on the chance to explode when itsnot 1, see below for error 
#             $vol_detail='slab';
# 	    if ("$n_slice_packs" ne "$b_slices") { 
# 		croak "PVM_NSPacks should equal NSLICES"; 
# 	    }
# 	    if ("$slice_pack_size" ne "1" ) {
# 		confess "Slab data never saw PVM_SPackArrNSlcies array with values other than 1";
# 	    }
# 	    if ("$n_slice_packs" ne "$list_size" ){
# 		confess "PVM_NSPacks should equal ACQ_O1_list_size with slab data";
#                 ### there is potential for multi-slab type, but we'll assume that wont happen for now and just die.
#             }
#         } elsif( $list_sizeB <= $slice_pack_size ) {
# should check the slice_offset, makeing sure that they're all the same incrimenting by uniform size.
# If they are then we have a 2d multi acq volume, not points in time. so for each value in ACQ_slice_offset,
# for 2D acq, get difference between first and second, and so long as they're the same, we have slices not volumes
# 	    printd(45,"slice_offsets:".join(',',@slice_offsets)."\n");
# 	    my $offset_num=1;
# 	    my $num_a=sprintf("%.9f",$slice_offsets[($offset_num-1)]);
# 	    my $num_b=sprintf("%.9f",$slice_offsets[$offset_num]);
# 	    my $first_offset=$num_b-$num_a;
# 	    $first_offset=sprintf("%.9f",$first_offset);
# 	    printd(75,"\tfirst diff $first_offset\n");
# 	    for($offset_num=1;$offset_num<$#slice_offsets;$offset_num++) {
# 		my $num_a=sprintf("%.9f",$slice_offsets[($offset_num-1)]);
# 		my $num_b=sprintf("%.9f",$slice_offsets[$offset_num]);
# 		my $current_offset=$num_b-$num_a;
# 		$current_offset=sprintf("%.9f",$current_offset);
# 		printd(85,"num_a:$num_a, num_b:$num_b\n");
		
# 		if("$first_offset" ne "$current_offset") { # for some reason numeric comparison fails for this set, i dont understnad why.
# 		    printd(85,"diff bad  num:$offset_num  out of cur, <$current_offset> first, <$first_offset>\n");
# 		    $first_offset=-1000; #force bad for rest
# 		} else { 
# 		    printd(85,"diff checks out of $current_offset $first_offset\n");
# 		}
# 	    }
# 	    if( ($first_offset==-1000) &&  ( $list_sizeB == $slice_pack_size) ){
# 		printd(45,"list b and slice_pack size equal and first offset -1000, z using b_slices ");
# 		$z=$slices;
# 		$vol_num=$list_sizeB;
# 	    } elsif ( $list_sizeB == $slice_pack_size) { 
# 		printd(45,"list b and slice_pack size equal, z using b_slices ");
# 		#list_sizeB seems to be number of slices in total, 
# 		$vol_num=$list_sizeB/$list_size;
# 		$z=$slices;
# 	    }
	    
# 	    if ($z > 1 ){
# 		$vol_detail=$vol_detail.'-vol';
# 	    } 
# 	    if ($n_echos >1 ) {
# 		$vol_detail=$vol_detail.'-echo';		    
# 	    }
# 	} else { 
#             $vol_num=$list_sizeB;
#         }
#     } elsif ( $slice_pack_size>1 ) {
# 	if ( $list_sizeB == $slice_pack_size) { 
# 	    printd(45,"list b and slice_pack size equal, z using b_slices ");
# 	    #list_sizeB seems to be number of slices in total, 
# 	    $vol_num=$list_sizeB/$list_size;
# 	    $z=$slices;
# 	} elsif ($list_sizeB < $slice_pack_size )  {
# 		printd(45,"z using PVM_SPackArrNSlices");
# 		$vol_num=$list_sizeB/$list_size;
# 		$z=$slice_pack_size;
# 	    }
# 	else {
# 	    printd(10,"Unknown error in setting $z size");
# 	}
#     } else { 
       
#         $z=$slices;
#     }
#     if ( $channels>1 ) { 
# 	$vol_detail=$vol_detail.'-channel'."-$channel_mode";

 	$vol_num=$vol_num*$channels;
	
#     }

    $vol_num=$time_pts*$vol_num;# not perfect
    if ( $vol_num>1) { 
	$vol_type="4D";
    }

###### handle xy swapping
    

    printd(45,"Set X=$x, Y=$y, Z=$z, vols=$vol_num\n");
    printd(45,"vol_type:$vol_type, $vol_detail\n");
    $debug_val=$old_debug;
    return "${vol_type}:${vol_detail}:${vol_num}:${x}:${y}:${z}:${bit_depth}:${data_type}:${order}";
}

=item aoa_hash_to_headfile

input: ($aoa_header_hash_ref, $headfile_ref , $prefix_for_elements)

 aoa_header_hash_ref - hashreference for the agilent header this module
creates.
 headfile_ref - ref to civm headfile opend by sally's headfile code 
 preffix_for_elements -prefix to put onto each key from aoa_header

output: status maybe?

=cut
###
sub moved_aoa_hash_to_headfile {  # ( $aoa_header_ref, $hf , $prefix_for_elements)
###
    my ($header_ref,$hf,$prefix) = @_; 
    debugloc();
    if ( ! defined $prefix ) { 
        carp "Prefix undefined when converting header hash to CIVM headfile";
    }
    my @hash_keys=();#qw/a b/;
    @hash_keys=keys(%{$header_ref});
    my $value="test";
    printd(75,"Hashref:<$header_ref>\n");
    printd(55,"keys @hash_keys\n");
    if ( $#hash_keys == -1 ) { 
        print ("No keys found in hash\n");
    } else {
        foreach my $key (keys %{$header_ref} ) {
            $value=aoaref_to_printline(${$header_ref}{$key});
	    if ( $value eq "BLANK" ) { 
		$value = '';
	    }
            $hf->set_value("$prefix$key",$value);
        }
    }
    return;
}

=item copy_relevent_keys
  
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
    my $s_tag=$hf->get_value('S_tag');
    my $data_prefix=$hf->get_value('U_prefix');
    my $extraction_mode_bool=$hf->get_value("R_extract_mode");
#    my $data_prefix=$hf->get_value("U_prefix");
    my $report_order=$hf->get_value("${s_tag}axis_report_order");
#    my $vol_type=$hf->get_value("B_vol_type");
#    my $vol_detail=$hf->get_value("B_vol_type_detail");

    my $block_header_size=28;                   ; # one block header per file block. Blocks may be volumes or slices.
    #my $binary_header_size=32+$block_header_size; # one binary header per file
    my $binary_header_size=32; # one binary header per file
    $hf->set_value("binary_header_size",$binary_header_size);
    $hf->set_value("block_header_size",$block_header_size);



    my %hfkey_aliaslist=( # hfkey=>[multiplier,alias1,alias2,aliasn] 
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
			   "tr"=>[                   # in us
			       1000000,
			       'tr',                 # in ms
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
			   "EchoTimes"=>[
			       1000,
			       'TE',
			   ],
			   "ray_length"=>[  # number of samples along a ray *2 (real,imaginary)
			       0.5,  # might want to divide by two as these are separted real/imaginary points
			       'np',
			   ],
			   "rays_per_block"=>[ 
			       1, 
			       'nf',
			   ],
			   "ray_blocks"=>[ #ray_blocks_per_volume, need to get per slices also
			       1,
			       'nblocks',
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
#         my $temp=pop(@{$hfkey_aliaslist{"nex"}});
#     }
#     if($vol_type eq "4D" && $vol_detail eq "DTI") { 
# 	my $temp=pop(@{$hfkey_aliaslist{"B_NRepetitions"}});
#     }
    
    if (defined $agilent_header_hash_ref->{"channels"}->[0] ) { 
	$hf->set_value('A_channels', aoaref_get_single($agilent_header_hash_ref->{"channels"}));
    } else {
	$hf->set_value('A_channels', 1);
    }


### insert standard keys * multiplier into civm headfile
    for my $hfkey (keys %hfkey_aliaslist) { 
        printd(55,"civmheadfilekey=$hfkey\n");
	my $multiplier=shift @{$hfkey_aliaslist{$hfkey}};
        for my $alias (@{$hfkey_aliaslist{$hfkey}}) {
            #$hf->set_value($key,$1);
            my $hfval=$hf->get_value($hfkey);
	    my $aval=$hf->get_value($data_prefix."$alias");
	    if ($aval ne 'NO_KEY') { #if (defined $agilent_header_hash_ref->{$alias}) {
#                my $aval=aoaref_to_printline($agilent_header_hash_ref->{$alias}); #need to do better job than this of getting value.
                printd(25,"\t$alias=$aval\n");

		if ($multiplier ne "1" && $aval =~ /^$plain_num$/ ) { $aval=$aval*$multiplier; }
                if ($hfval =~ m/^UNDEFINED_VALUE|NO_KEY$/x) {
		    printd(25,"\t$hfkey \t$alias=$aval\n");
                    $hf->set_value("$hfkey",$aval);
                } elsif($hfval ne $aval) {
                    confess("$hfkey value $hfval, from alias $alias $aval not the same as prevoious values, alias definition must be erroneous!");
                } else { 
		    printd(25,", $alias");
		}
            }
	}
	printd(25,"\n");
    }


    my $volinfotext=set_volume_type($hf); # only determines the output volume type, need alternate to determine the kspace data and its orientations and orders.
    my ($vol_type, $vol_detail, $vols,$x,$y,$z,$bit_depth,$data_type);
    ($vol_type, $vol_detail, $vols,$x,$y,$z,$bit_depth,$data_type,$report_order)=split(':',$volinfotext);
#    my $vol_type=$hf->get_value("${s_tag}vol_type");
#    my $vol_detail=$hf->get_value("${s_tag}vol_type_detail");
    $hf->set_value("dim_X",$x);
    $hf->set_value("dim_Y",$y);
    $hf->set_value("dim_Z",$z);
    $hf->set_value("${s_tag}image_bit_depth",$bit_depth);
    $hf->set_value("${s_tag}image_data_type",$data_type);
    printd(75,"echos before set_volume_type".$hf->get_value($s_tag."echos")."\n");
    $hf->set_value("${s_tag}volumes",$vols);
    $hf->set_value("${s_tag}echos",$hf->get_value('ne'));
    $hf->set_value("${s_tag}vol_type",$vol_type);
    $hf->set_value("${s_tag}vol_type_detail",$vol_detail);
    printd(75,"echos after set_volume_type = ".$hf->get_value($s_tag."echos").".\n");
    my $dim_order='xyzptc';
    $hf->set_value("${s_tag}dimension_order",$dim_order);


### set kspace bit depth and type    
#    my $bit_depth=32;
#    my $data_type="Real";
    $hf->set_value($s_tag."kspace_bit_depth",$bit_depth);
    $hf->set_value($s_tag."kspace_data_type",$data_type);
    $hf->set_value($s_tag."kspace_endian","big");
### sort out fov
    my $fov_x; 
    my $fov_y;
    my $fov_z;
    my $dx=$hf->get_value("dim_X");
    my $dy=$hf->get_value("dim_Y");
    my $dz=$hf->get_value("dim_Z");
    #dimY stores procpar variable name of dimx fov  Y and X are reversed some or all the time so far
    $fov_x=$hf->get_value($data_prefix.$hf->get_value($data_prefix."dimY"))*10;
    #dimX stores procpar variable name of dimy fov
    $fov_y=$hf->get_value($data_prefix.$hf->get_value($data_prefix."dimX"))*10;
    #dimZ stores procpar variable name of dimz fov
    $fov_z=$hf->get_value($data_prefix.$hf->get_value($data_prefix."dimZ"))*10;
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
#   $hf->set_value("te_sequence",);
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
