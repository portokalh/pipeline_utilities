#!/usr/bin/perl 
################################################################################
# James Cook.
# use perldoc aspect to get easily info on functions
=head1 aspect.pm

module to hold functions for looking at aspect data from our civm
aspect scanner.

=cut

# =head2 head2 head2
# =cut
# =head3 head3 head3
# =cut
# =head4 head4 head4

# =cut
=head1 sub's
=cut
=over 1
=cut
#=item stuff
#=back
#=cut

################################################################################
#
################################################################################

package aspect;
use strict;
use warnings;
use Carp;
use List::MoreUtils qw(uniq);
#require civm_simple_util;
use civm_simple_util qw(printd whoami whowasi debugloc sleep_with_countdown $debug_val $debug_locator);
use hoaoa qw(aoaref_to_printline aoaref_to_singleline aoaref_get_subarray aoaref_get_single printline_to_aoa array_find_by_length single_find_by_value display_header_entry printline_to_aoa);
#my (@ISA,@Export,@EXPORT_OK);
BEGIN { #require Exporter;
    use Exporter(); #
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(
parse_header
display_header
read_til_next_keyline
@knownsequences
@TwoDsequences
@ThreeDsequences
@FourDsequences
);
}    
# determine_volume_type
# aoaref_get_single
# aoaref_get_subarray
# aoaref_get_length
# aoaref_get_sub_length
# aoaref_to_singleline
# aoaref_to_printline

my $Hfile = 0;
my $NAME = "aspect lib";
my $VERSION = "2013/05/29";
my $COMMENT = "Aspect meta data functions";
use vars qw(@knownsequences @TwoDsequences @ThreeDsequences @FourDsequences);
@TwoDsequences=qw(SE_ ME_SE_);
@ThreeDsequences=qw(GRE_EXT_  gre_sp_ GRE_SP_ GRE_SS_ );
@FourDsequences=qw();
push(@knownsequences,@TwoDsequences);
push(@knownsequences,@ThreeDsequences);
push(@knownsequences,@FourDsequences);
 # tested acquisition sequences for aspect extract. might be good to pull this out to configuration variables. 
###
sub parse_header {   #( \@aspectheaderarrayoflines,$debug_valval )
###

=item parse_header($array_ref,$debug_valval)

takes an array reference to the header loaded as one line per element

=cut

    my (@input)=@_;
    my $aspect_array_ref = shift @input;
    my $old_debug=$debug_val;
    $debug_val = shift @input or $debug_val=$old_debug;
    debugloc();
#    my @aspect_header = @{$aspect_array_ref};
    # hfile is and always is a ref
#    my $aspectmultidimcode = 0;
    my %aspecthash;
### Parse aspect header into civm header info, dump to aspecthash
    my $arraydefregex; # not arrays evident in aspect so far, we'll keep this for now.
    $arraydefregex="";  # .
#         "^[(]".         # begning of line is with (
#         "[ ][0-9]+".    # a space and integer value follows
#         "(?:,".         # open character class which will be optional, it opens with a comma
#         "[ ][0-9]+".    # a space and integer value follows
#         ")*".           # close character class
#         "[ ][)]\$";   # line ends with a space ) 
    printd(90,"array def regex is <$arraydefregex>\n");
    my $section_keyline='^====[ ](.*?)[ ]====';
    my $meta_info_keyline   ='^([^=[:cntrl:]]+?)[ ]=[ ](.+?)$'; # any characters
    my $parameter_keyline   ='^(.+?[A-Z])[ ]=[ ](.+?)$'; # NAME = value  
    my $macro_params_keyline='^(.+?Parameter[ ][0-9]+)[ ]=[ ](.+?)$'; # NAME = value 
    my $used_sections='Parameters|study_info'; 
    my $section  = "study_info";# this assumes the stud info is always first, which it has been so far.
### process headers one line at time
    while ( $#{$aspect_array_ref} >= 0 ) {
        # eat aspect header lines one at a time. looking for special variables
        # place header in new array as we process it, 1 to 1 values and lines, or a hash.
        # non data linse start with '==== '
        my $keyline = shift (@{$aspect_array_ref});
        chomp $keyline;
        printd(75,"Key Line $keyline\n"); 
        my $dataline = "";
        my $rawvalue = "";

	my @commentlines=();
        my @dataarray = ('BLANK');
        my ( $varname, $val)= ('','');
	if (  $keyline=~ /$section_keyline/x ) {
	    $section = $1;
	    printd(65,"Section \"$section\"\n");
	} elsif ( $keyline=~ /^\#(.*)/x ) {
	    push( @commentlines,$keyline);
	    printd(65,"New comment line\"$commentlines[$#commentlines]\"\n");
	} elsif ( $keyline=~ /^$macro_params_keyline/x ) { 
	    ($varname, $val) = ($1, $2);
	} elsif ( $keyline=~ /^$parameter_keyline/x ) { 
	    ($varname, $val) = ($1, $2);
	} elsif ( $keyline=~ /^$meta_info_keyline/x ) { 
	    ($varname, $val) = ($1, $2);
	} else { 
	    printd(55,"Line did not match any expected format $keyline\n");
	}
        # varname should be the name or the $name of the hash element to use, $val should be the unprocessed value, before turning it has been turned into an array.
        if (! defined $varname || "$varname" eq "" ) { $varname="BLANK"; }      #### fix bad values from regex
        if (! defined $val || "$val" eq ""         ) { $val="BLANK"; }          #### fix bad values from regex
        printd(65, "\trawname = $varname; \n\t\trawvalue = $val;\n" ); 
        if ( $varname =~ /[^a-zA-Z_][a-zA-Z_0-9]*/x  ) {  #### fix any bad varnames to be only standard characters, that is, start with letter, followed by any number of letters numbers or underscores.
	    printd(45,"  -->changing non alpha-nums to _ varname\n");
	    $varname =~ s/[^a-zA-Z_0-9]/_/gx;
        } # end varname cleanup
 	printd(35,"\tName:$varname\n");
	if ($val =~ /[[:cntrl:]]/x ){ 
	    printd(75,"\t->Eating control chars from value\n");
	    $val =~ s/[[:cntrl:]]//gx;
	}
	$dataarray[0]=( [1, $val] ); 
	printd(35, "\tType: single\n");
	printd(45,"\tData: $val\n");
	if ( defined $varname && $varname ne "BLANK" )  { 
	    if ($dataarray[0] ne 'BLANK' ) {
		if ($section =~ /$used_sections/x) {
		    $aspecthash{${varname}}=\@dataarray; #must store as ref, cannot pass as array between functions
		} else {
		    printd(45,"Ignoring var $section:$varname with data $val\n");
		}		
	    } else {
		confess ("varname:<$varname> value undefined\n");
             }
        }# end store info in hash
    } # @aspectheader out of lines
    $debug_val=$old_debug;
    return \%aspecthash;
} # end of parse_header function


=item determine_volume_type($aspect_header_hash_ref[,$debug_val])

looks at variables and detmines the volume output type from the
different posibilities.  2D, or 3D if 2d, multi position or single
position 2d, single or multi echo, or multi time (maybe multiecho is
same as multi time.)  3D are there multi volumes? may have to check
for each kind of multivolume are there multi echo's?  (time and or
dti) or slab?

returns info as "${vol_type}:${vol_detail}:${vol_num}:${x}:${y}:${z}:${bit_depth}:${data_type}:${order}";

=cut
###
sub old_determine_volume_type { # ( \%aspect_header_ref[,$debug_val] )
###
    my (@input)=@_;
    my $aspect_header_ref = shift @input;
    my $old_debug=$debug_val;
    $debug_val = shift @input or $debug_val=$old_debug;
    my $vol_type=1;
    my $vol_detail="single";
    my $vol_num=1; # total number of volumes, 
    my $time_pts=1; # number timepoints, currently only used for dti
    my $channels=1;
    my $channel_mode='separate'; # separate or integrate, if integrate use math per channel to add to whole image. 
    my $x=1;
    my $y=1;
    my $z=1; # slices per volume
    my $slices=1;#total z dimension 

#    my ($aspect_header_ref)=@_;
#    my $sequence = ${$aspect_header_ref}{"ACQ_method"}->[0]->[1]; ### get value of single ...
    my $sequence='';
    if ( defined $aspect_header_ref->{'ACQ_method'}->[0] )  {
	$sequence = aoaref_get_single($aspect_header_ref->{"ACQ_method"});
    } else { 
	croak "Required field missing from aspect header:\"ACQ_method\" ";
    }
    printd(45, "Sequence:$sequence\n");
    my $sequence_ex="<(".join("|",@knownsequences).")>";
    if ( $sequence !~ m/^$sequence_ex$/x ) { 
        croak("NEW SEQUENCE USED: $sequence\nNot known type in (@knownsequences), did not match $sequence_ex\n TELL JAMES\n"); #\\nMAKE SURE TO CHECK OUTPUTS THROUGHLY ESPECIALLY THE NUMBER OF VOLUMES THEIR DIMENSIONS, ESPECIALLY Z\n");
    }
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
    my $n_echoes;
    if ( defined $aspect_header_ref->{'ACQ_n_echo_images'} )  {
        $n_echoes=aoaref_get_single($aspect_header_ref->{'ACQ_n_echo_images'});
#         if ($n_echoes>1){ 
#             croak("Never delt with echos, failing now.");           
#         }
	printd(45,"n_echoes:$n_echoes\n");
	
    }
    my $movie_frames;
    if ( defined $aspect_header_ref->{"ACQ_n_movie_frames"} ) {  
    $movie_frames=aoaref_get_single($aspect_header_ref->{"ACQ_n_movie_frames"}); # ntimepoints=length, or 0 if only one time point
    }
    my $n_dwi_exp;
    if ( defined $aspect_header_ref->{"PVM_DwNDiffExp"}) { 
        $n_dwi_exp=aoaref_get_single($aspect_header_ref->{"PVM_DwNDiffExp"});
    }
    my $b_slices;
#    if ( defined aoaref_get_single($aspect_header_ref->{"NSLICES"}) ) { 
    if ( defined $aspect_header_ref->{"NSLICES"} ) { 
	$b_slices=aoaref_get_single($aspect_header_ref->{"NSLICES"});
	printd(45,"bslices:$b_slices\n");
    }
    my $list_sizeB;
    my $list_size;
    if (defined $aspect_header_ref->{"ACQ_O1B_list_size"} ) {
        $list_sizeB=aoaref_get_single($aspect_header_ref->{"ACQ_O1B_list_size"});  # appears to be total "volumes" for 2d multi slice acquisitions will be total slices acquired. matches NI, (perhaps ni is number of images and images may be 2d or 3d)
        $list_size=aoaref_get_single($aspect_header_ref->{"ACQ_O1_list_size"}); # appears to be nvolumes/echos matches NSLICES most of the time, notably does not match on 2d me(without multi slice
#         if ("$list_size" ne "$list_sizeB") { 
#             croak "ACQ_O1B_list_size ACQ_O1_list_size missmatch. This has never been seen before and probably should not happen\n";
#         } else {
            printd(45,"List_size:$list_size\n"); # is this a multi acquisition of some kind. gives nvolumes for 2d multislice and 3d(i think) 
            printd(45,"List_sizeB:$list_sizeB\n"); 
#        }
    }
    my @lists=qw(ACQ_O2_list_size ACQ_O3_list_size ACQ_vd_list_size ACQ_vp_list_size);
    for my $list_s (@lists) { 
	if (aoaref_get_single($aspect_header_ref->{$list_s}) != 1 ) { confess("never saw $list_s value other than 1 Unsure how to fontinue"); }
    }
    my @slice_offsets;
    my $n_slice_packs=1;
    my $slice_pack_size=1;
    if (defined $aspect_header_ref->{"ACQ_slice_offset"} ) {
       @slice_offsets=@{$aspect_header_ref->{"ACQ_slice_offset"}->[0]};
       shift @slice_offsets;
    }
    
    
    if (defined $aspect_header_ref->{"PVM_NSPacks"}->[0] ) { 
        $n_slice_packs=aoaref_get_single($aspect_header_ref->{"PVM_NSPacks"}); 
	if ( ! defined $n_slice_packs ) {        
            croak "Required field missing from aspect header:\"PVM_NSPacks\" ";
        }
    }
    if (defined $aspect_header_ref->{"PVM_SPackArrNSlices"} ->[0]) {
#       $slice_pack_size=$aspect_header_ref->{"PVM_SPackArrNSlices"}->[0]->[1];
       $slice_pack_size=aoaref_get_single($aspect_header_ref->{"PVM_SPackArrNSlices"});
    } else { 
    # $list_size == $slice_pack_size
	$slice_pack_size=aoaref_get_single($aspect_header_ref->{"NI"});
	carp("No PVM_SPackArrNSlices, using NI instead, could be wrong value ") ;
	sleep_with_countdown(4);
    }

    printd(45,"n_spacks:$n_slice_packs\n");        
    printd(45,"spack_size:$slice_pack_size\n");
### get the dimensions 
# matrix 2 or 3 element vector containing the dimensions, shows wether we're 2d or 3d 
# ACQ_size=2,400 200 pvm_matrix not defined for acquisition only so we'll go with acq size if pvm_matrix undefined. 
# spatial_phase_1, either frequency or phase dimension, only defined in 2d or slab data on rare sequence, unsure for others
# spatial_size_2, 3rd dimension size, should match $matrix[1] if its defined.;
    my @matrix; #get 2/3D matix size
    my $order= "UNDEFINED";  #report_order for matricies
    if (defined $aspect_header_ref->{"PVM_Matrix"} || defined $aspect_header_ref->{"ACQ_size"} ) {
        if ( $#{$aspect_header_ref->{"PVM_Matrix"}} >= 0 ) { 
	     @matrix=@{$aspect_header_ref->{"PVM_Matrix"}->[0]};
	}
# 	if( ! defined $matrix[0] ) {
# 	    printd(45,"PVM_Matrix undefined, or empty, using ACQ_size\n"); ### ISSUES HERE, f direction of acq_size is doubled. 
# 	    @matrix=@{$aspect_header_ref->{"ACQ_size"}->[0]};
# 	} 
	if (defined $matrix[0]) { 
	    shift @matrix;
	    if ($#matrix>2) { croak("PVM_Matrix too big, never had more than 3 entries before, what has happened"); }
	    printd(45,"Matrix=@matrix\n");
	}
    }
    if (! defined $matrix[0]) {
        croak "Required field missing from aspect header:\"PVM_Matrix|ACQ_size\" ";
    }
    # use absence of pvm variables to set the default to UNDEFINED orientation which is x=acq1, y=acq2.
    if ( defined $aspect_header_ref->{"PVM_SPackArrReadOrient"} ) { 
        $order=aoaref_get_single($aspect_header_ref->{"PVM_SPackArrReadOrient"} );
        if ( ! defined $order && defined $aspect_header_ref->{"PVM_matrix"} ) { 
            croak("Required field missing from aspect header:\"PVM_SPackArrReadOrient\"");
        }
    } else { 
	
    } 
### get channels
    if (defined $aspect_header_ref->{"PVM_EncActReceivers"}->[0] ) { 
	$channels=aoaref_get_single($aspect_header_ref->{"PVM_EncNReceivers"});
	
#	$channel_mode='integrate';
    }
### get bit depth
    my $bit_depth;
    my $data_type;
    if ( defined $aspect_header_ref->{"RECO_wordtype"} || defined $aspect_header_ref->{"GO_raw_data_format"}) {
	my $input_type;
	if ( defined $aspect_header_ref->{"RECO_wordtype"} ) { 
	    $input_type=aoaref_get_single($aspect_header_ref->{"RECO_wordtype"});
	}
	if ( ! defined $input_type ) { 
	    $input_type=aoaref_get_single($aspect_header_ref->{"GO_raw_data_format"});
	}
	if ( ! defined $input_type ) { 
	    warn("Required field missing from aspect header:\"RECO_wordtype\"");
	} else {
	    if    ( $input_type =~ /.*_16BIT_.*/x ) { $bit_depth = 16; }
	    elsif ( $input_type =~ /.*_32BIT_.*/x ) { $bit_depth = 32; }
	    elsif ( $input_type =~ /.*_64BIT_.*/x ) { $bit_depth = 64; }
	    else  { warn("Unhandled bit depth in $input_type"); }
	    if    ( $input_type =~ /.*_SGN_/x ) { $data_type = "Signed"; }
	    elsif ( $input_type =~ /.*_USGN_.*/x ) { $data_type = "Unsigned"; }
	    elsif (  $input_type =~ /.*_FLOAT_.*/x ) { $data_type = "Real"; }
	    else  { warn("Unhandled data_type in $input_type"); }
	}
    } else { 
	warn("cannot find bit depth at RECO_wordtype");
    }
    
### if both spatial phases, slab data? use spatial_phase_1 as x?y?
### for 3d sequences ss2 is n slices, for 2d seqences it is dim2, thats annoying..... unsure of this
    my $ss2;
    if ( defined $aspect_header_ref->{'ACQ_spatial_size_2'}) { # exists in 3d, dti, and slab, seems to be the Nslices per vol,
        $ss2=aoaref_get_single($aspect_header_ref->{'ACQ_spatial_size_2'});  
        printd(45,"spatial_size2:$ss2\n");
    } elsif($#matrix==1 && !defined $aspect_header_ref->{'ACQ_spatial_size_2'}) { #if undefined, there is only one slice. 
        $ss2=1;
#    } else { 
#	$ss2=0;
    }

###### determine dimensions and volumes
    if ( $order =~  m/^H_F|A_P$/x  ) { 
        $order ='yx'; 
        $x=$matrix[1];
        $y=$matrix[0];
	if ( ! defined $aspect_header_ref->{"PVM_Matrix"}->[0]) {
	    $y=$y/2;
	    printd(45, "halving y\n");
	}
    } else { 
        $order='xy';
        $x=$matrix[0];
        $y=$matrix[1];
	if ( ! defined $aspect_header_ref->{"PVM_Matrix"}->[0]) {
	    $x=$x/2;
	    printd(45, "halving x\n");
	}
    }
    printd(45,"Set X=$x, Y=$y, Z=$z\n");
    printd(45,"order is $order\n");
    if ( $#matrix ==1 ) {
        $vol_type="2D";
	$slices=$b_slices;
	#should find detail here, not sure how, could be time or could be space, if space want to set slices, if time want to set vols
    } elsif ( $#matrix == 2 )  {#2 becaues thats max index eg, there are three elements 0 1 2 
        $vol_type="3D";
	if ( defined $ss2 ) { 
	    $slices=$ss2;
	} else {
	    $slices = $matrix[2];
	}
        if ( $slices ne $matrix[2] ) {
            croak "n slices in question, hard to determing correct number, either2 $slices or $matrix[2]\n";
        }
    }   
###### set time_pts    
    if ( defined $movie_frames && $movie_frames > 1) {  #&& ! defined $sp1 
        $time_pts=$movie_frames;
        $vol_type="4D";
        if ( defined $n_dwi_exp ) { 
            printd(45,"diffusion exp with $n_dwi_exp frames\n");
            if ( $movie_frames!=$n_dwi_exp) { 
                croak "ACQ_n_movie_frames not equal to PVM_DwNDiffExp we have never seen that before.\nIf this is a new sequence its fesable that ACQ_spatial_phase1 would be defined.";
            }
            $vol_detail="DTI";
        } else { 
            $vol_detail="MOV";
        }
    }
###### set z and volume number
    printd(45,"LIST:$list_sizeB $slice_pack_size\n");
### if listsize<listsizeb we're multi acquisition we hope. if list_size >1 we might be multi multi 
    if ( $list_sizeB > 1 ) { 
        $vol_detail='multi';
        if($n_slice_packs >1 ) { 
            $z=$slices*$n_slice_packs*$slice_pack_size; #thus far slice_pack_size has always been 1 for slab data, but we dont want to miss out on the chance to explode when itsnot 1, see below for error 
            $vol_detail='slab';
	    if ("$n_slice_packs" ne "$b_slices") { 
		croak "PVM_NSPacks should equal NSLICES"; 
	    }
	    if ("$slice_pack_size" ne "1" ) {
		confess "Slab data never saw PVM_SPackArrNSlcies array with values other than 1";
	    }
	    if ("$n_slice_packs" ne "$list_size" ){
		confess "PVM_NSPacks should equal ACQ_O1_list_size with slab data";
                ### there is potential for multi-slab type, but we'll assume that wont happen for now and just die.
            }
        } elsif( $list_size == $slice_pack_size) {
# should check here the slice_offset, makeing sure that they're all the same incrimenting by uniform size. If they are then we have a 2d multi acq volume, not points in time. 
# so for each value in ACQ_slice_offset, for 2D acq, get difference between first and second, and so long as they're the same, we have slices not volumes
	    printd(45,"slice_offsets:".join(',',@slice_offsets)."\n");
	    my $offset_num=1;
	    my $num_a=sprintf("%.9f",$slice_offsets[($offset_num-1)]);
	    my $num_b=sprintf("%.9f",$slice_offsets[$offset_num]);
	    my $first_offset=$num_b-$num_a;
	    $first_offset=sprintf("%.9f",$first_offset);
	    printd(75,"\tfirst diff $first_offset\n");
	    for($offset_num=1;$offset_num<$#slice_offsets;$offset_num++) {
		my $num_a=sprintf("%.9f",$slice_offsets[($offset_num-1)]);
		my $num_b=sprintf("%.9f",$slice_offsets[$offset_num]);
		my $current_offset=$num_b-$num_a;
		$current_offset=sprintf("%.9f",$current_offset);
#		printd(85,"num1 (".($slice_offsets[$offset_num]).")  num-1(".($slice_offsets[($offset_num-1)]).")\n");
		printd(85,"num_a:$num_a, num_b:$num_b\n");
		
		if("$first_offset" ne "$current_offset") { # for some reason numeric comparison fails for this set, i dont understnad why.
		    printd(85,"diff bad  num:$offset_num  out of cur, <$current_offset> first, <$first_offset>\n");
		    $first_offset=-1000; #force bad for rest
		} else { 
		    printd(85,"diff checks out of $current_offset $first_offset\n");
		}
	    }
	    if ($first_offset==-1000) {
		$vol_num=$list_sizeB;
	    } else { 
		#list_sizeB seems to be number of slices in total, 
		$vol_num=$list_sizeB/$list_size;
		$z=$slices;
		if ($z > 1 ){
		    $vol_detail=$vol_detail.'-vol';
		} 
		if ($n_echoes >1 ) {
		    $vol_detail=$vol_detail.'-echo';		    
		}
	    }
	} else { 
            $vol_num=$list_sizeB;
        }
    } else { 
       
        $z=$slices;
    }
    if ( $channels>1 ) { 
	$vol_detail=$vol_detail.'-channel'."-$channel_mode";
	$vol_num=$vol_num*$channels;
    }

    $vol_num=$time_pts*$vol_num;# not perfect


###### handle xy swapping
    


    $debug_val=$old_debug;
    return "${vol_type}:${vol_detail}:${vol_num}:${x}:${y}:${z}:${bit_depth}:${data_type}:${order}";
}


=item aoaref_get_single ( $ref_to_AoA )

get single value from aspect ehader.

=cut
###
sub old_aoaref_get_single { # ( $ref_to_AoA )
###
    my ($dataarray_ref) = @_;
    my $reftype=ref($dataarray_ref); 
    my $err_cause;
    my $data;
    if ( $dataarray_ref ne "" && $reftype eq 'ARRAY' ) {
        $data=aoa_to_singleline(@$dataarray_ref,'single');
    } elsif ( $reftype ne 'ARRAY' ) { 
        $err_cause="ref type $reftype wrong";
        confess "ref type $reftype wrong";
    } else {
        printd(35, "wierd problem with array ref in aoaref_to_singleline\n");
        $data="ERROR";
    }
    return $data;
}

###
sub old_aoaref_get_length { # ( $ref_to_AoA )
###
=item aoaref_get_length ( $ref_to_AoA )

get length of aoa at aoareference

=cut
    my ($dataarray_ref) = @_;
    my $reftype=ref($dataarray_ref); 
    my $err_cause;
    my $data;
    if ( $dataarray_ref ne "" && $reftype eq 'ARRAY' ) {
        $data=$#{$dataarray_ref->[0]};
#       $data=aoa_to_singleline(@$dataarray_ref,'length');
    } elsif ( $reftype ne 'ARRAY' ) { 
        $err_cause="ref type $reftype wrong";
        confess "ref type $reftype wrong";
    } else {
        printd(35, "wierd problem with array ref in aoaref_to_singleline\n");
        $data="ERROR";
    }
    return $data;    
}

=item aoaref_get_sub_length

input: ( $ref_to_AoA )

get length of subarray in first element of aoa at aoareference

=cut
###
sub old_aoaref_get_sub_length { # ( $ref_to_AoA )
###
    my ($dataarray_ref) = @_;
    my $reftype=ref($dataarray_ref); 
    my $err_cause;
    my $data;
    if ( $dataarray_ref ne "" && $reftype eq 'ARRAY' ) {
        $data=$#{$dataarray_ref->[0]->[0]};
#       $data=aoa_to_singleline(@$dataarray_ref,'length');
    } elsif ( $reftype ne 'ARRAY' ) { 
        $err_cause="ref type $reftype wrong";
        confess "ref type $reftype wrong";
    } else {
        printd(35, "wierd problem with array ref in aoaref_get_sub_length\n");
        $data="ERROR";
    }
    return $data;    
}


=item aoaref_get_subarray

input: ($n, $ref_to_AoA )

get subarray $n of aoa at aoareference, n starts counting at 1 to length of aoa at ref_to_AoA

=cut
###
sub old_aoaref_get_subarray { # ( $ref_to_AoA )
###
    my ($n, $dataarray_ref) = @_;
    my $reftype=ref($dataarray_ref); 
    my $err_cause;
    my @data;
    my @subarrays;
    if ( $dataarray_ref ne "" && $reftype eq 'ARRAY' ) {
        @data=@{$dataarray_ref->[($n-1)]};
#	my $temp=shift(@data); # not sure this is a good idea.
# 	my $line=aoa_to_singleline(@$dataarray_ref,'whole');
# 	@subarrays=split(':',$line);
# 	my ($elements) = $subarrays[($n-1)] =~ m/[(](.*)[)]/x;
# 	@data=split(',',$elements);
#	print("getsubarray:@data\n");
    } elsif ( $reftype ne 'ARRAY' ) { 
        $err_cause="ref type $reftype wrong";
        confess "ref type $reftype wrong";
    } else {
        printd(35, "wierd problem with array ref in aoaref_get_subarray\n");
        $data[0]="ERROR";
    }

    return @data;    
}


=item aoaref_to_singleline( $ref_to_AoA ) 

taking reference to array of arrays builds back a string which is easy
to parse. It separats subarrays elemtns with commmas and suarrays with
ex, a 2 element array with 3 element subarrays would be converted to
(1,2,3):(4,5,6)
# does some reference error checking, calls aoa_to_singleline to do the work

=cut
###
sub old_aoaref_to_singleline { # ( $ ref_to_AoA ) 
###
    my ($dataarray_ref) = @_;
    my $reftype=ref($dataarray_ref); 
    my $err_cause;
    my $data;
    if ( $dataarray_ref ne "" && $reftype eq 'ARRAY' ) {
        $data=aoa_to_singleline(@$dataarray_ref,'whole');
    } elsif ( $reftype ne 'ARRAY' ) { 
        $err_cause="ref type $reftype wrong";
        confess "ref type $reftype wrong, at aoaref to singleline";
    } else {
        printd(35, "wierd problem with array ref in aoaref_to_singleline\n");
        $data="ERROR";
    }
    return $data;
}

###
sub old_aoa_to_singleline {  # ( @AoA, mode )    
###
=item aoa_to_singleline ( @AoA, mode )    

internal function doing the work of aoaref_to_singleline
mode 'whole' get whole
mode 'sub' get (first)subarray
mode 'single' get single, (first element of first subarray)

=cut
    my (@dataarray)=@_;
    debugloc();
    printd(90,"@dataarray\n");
    my @text_array;
    my $dims="0";
    my $data;
    my $mode=pop @dataarray;
    
    if ($mode ne 'whole' && $mode ne 'sub' && $mode ne 'single' ) { push @dataarray,$mode; $mode='whole'; }
    if ($mode eq 'whole' ) {
        for my $aref ( @dataarray) {
            my @subarray=@{$aref}; 
            if ($dims eq "0" ) {
                $dims=$subarray[0];
            } elsif ( $dims ne $subarray[0] ) {
                confess "Inconsisitent subarray dims current $dims, next $subarray[0]\n" ;
            }
            @subarray=@subarray[1..$#subarray];
            my $subjoin=join(",",@subarray); #@{$aref}); #[1..-1]
            push(@text_array,"($subjoin)");
            printd(75, "\t ($subjoin) \n");
        }
        $data=join (':',@text_array);
    } elsif ( $mode eq 'sub' ) { 
        my $aref=$dataarray[0];
        my @subarray=@{$aref}; 
        @subarray=@subarray[1..$#subarray];
        $data=join(",",@subarray);
    } elsif ( $mode eq 'single' ) {
        my $aref=$dataarray[0];
        my @subarray=@{$aref}; 
        @subarray=@subarray[1..$#subarray];
        $data=$subarray[0];
    }

    return $data;
}
###
sub old_aoa_to_printline {  # ( @AoA )    
###
=item aoa_to_printline ( @AoA )    

internal function doing the work of aoaref_to_printline

=cut
    my (@dataarray)=@_;
    debugloc();
    printd(90,"@dataarray\n");
    my @text_array; #array containing the text for each sub array, 
    #my $subarrayelements; #=$#{$dataarray[0]};
    my $dims=0;
    for my $aref ( @dataarray) {
        my @subarray=@{$aref}; 
        if ($dims eq "0" ) {
            $dims=$subarray[0];
        } elsif ( $dims ne $subarray[0] ) {
            confess "Inconsisitent subarray dims current $dims, next $subarray[0]\n" ;
        } elsif ( $dims eq "" ) { 
            confess "No dims found \n";
        }
        @subarray=@subarray[1..$#subarray];
#       $subarrayelements=$#subarray;
        my $subjoin=join(" ",@subarray);
#       if ( $#subarray != $dims ) {#$#{$aref}
#           @subdims=shift(@dataarray
#           my $temptext=aoa_to_singleline(@dataarray);
#           croak ("Sub array elements mismatch, We expect subarrays to be the same size. First subaray length was $subarrayelements current is $#{$aref}. Data dump follows this line.\n$temptext");
#       }
        push(@text_array,"$subjoin");
        printd(75, "\t ($subjoin) \n");
    }

    if  ( $#text_array>0 ) { 
        $dims=($#text_array+1).":$dims,";
    } elsif ("$dims" ne "1" ) { 
        $dims=$dims.',';
    } else { 
        $dims="";
    }
        
    my $data=$dims.join (' ',@text_array);
    return $data;
}
###
sub old_printline_to_aoa {  # ( $string )    
###
=item printline_to_aoa ( $string )    

internal function doing the work of printline_to_aoa

=cut
{
    my ($printline)=@_;
    debugloc();
    printd(90,"parsing $printline back to array\n");
    my @text_array; #array containing the text for each sub array, 
    my $dims=0;
    my @dim_array=();
    my $values=0;
    my @val_array=();
#    split($printline
    ($dims, $values)=split(',',$printline);
    
    @dim_array=  ( $dims =~ m/([0-9]+[:]?[ ]?)+/gx  );#(:?:([0-9]+)?)*

#    my $nsubarrays=shift@dim_array;
    my $subarraysize;
    if ($#dim_array==0 ) { 
	$subarraysize=$dim_array[0];
    } elsif( $#dim_array == 1 ) { 
	if ( $dim_array[0] == 1 ) { 
	    $subarraysize=$dim_array[1]; 
	} else { 
	    $subarraysize=$dim_array[0];
	}
    } else { 
	$subarraysize=$dim_array[1]*$dim_array[2]; 
    }
    
    printd(90," dimensions text->array $dims -> @dim_array\n");
    my $num_ex="[-]?[0-9]+(?:[.][0-9]+)?(?:e[-]?[0-9]+)?"; # positive or negative floating point or integer number
    my $num_sa_ex="((?:$num_ex)(?:[ ]$num_ex){$subarraysize})"; 
#    my $element_ex="[a-zA-Z0-9.-_]+";

    my $data='';
#    @val_array = ( $values =~ m/$element_ex/gx ) ;
    @val_array = ( $values =~ m/$num_ex/gx ) ;

    printd(90," nvalues$#val_array,  text->array  $values -> ".join('|',@val_array)."\n");
    return @val_array;
}
}
=item aoaref_to_printline ($ref_to_AoA

taking reference to array of arrays builds back a string which is easy
to parse, and doenst contain additional special characters. It
separats subarrays elemtns with commmas and suarrays with ex, a 2
element array with 3 element subarrays which would be single lined as
(1,2,3):(4,5,6) would be converted to 2: 3, 1 2 3 4 5 6 does some
reference error checking, calls aoa_to_printline to do the work

=cut
###
sub old_aoaref_to_printline { # ( $ ref_to_AoA ) 
###
    my ($dataarray_ref) = @_;
    my $reftype=ref($dataarray_ref); 
#    my $err_cause;
    my $data;
    if ( $dataarray_ref ne "" && $reftype eq 'ARRAY' ) {
        $data=aoa_to_printline(@$dataarray_ref);
    } elsif ( $reftype ne 'ARRAY' ) { 
#        $err_cause="ref type $reftype wrong";
        confess "ref type $reftype wrong, at aoaref to singleline";
    } else {
        printd(35, "wierd problem with array ref in aoaref_to_singleline\n");
        $data="ERROR";
    }
    return $data;
}


=item display_header

displays the whole aspect header all pretty froma aspect_header_ref
print keys
headfile or pretty

=cut
###
sub display_header { # ( $aspecthash_ref,$indent,$format,$pathtowrite ) 
###
    my ($aspect_header_ref,$indent,$format,$file)=@_;
    debugloc();
    my @bfkeys=qw/a b/;
    @bfkeys=keys(%{$aspect_header_ref});
    my $value="test";
    printd(75,"Aspect_Header_Ref:<$aspect_header_ref>\n");
    printd(55,"keys @bfkeys\n");
    my $text_fid;
    if ( defined $file ){ 
        open $text_fid, ">", "$file" or croak "could not open $file" ;
    }

    if ( $#bfkeys == -1 ) { 
        print ("No keys found in hash\n");
    } else {
        foreach my $key (sort keys %{$aspect_header_ref} ) {
            if ( $format eq "headfile" ) {
                 $value=aoaref_to_printline($aspect_header_ref->{$key});
                 my $string="$key=$value\n";
                 if (  $text_fid > -1 ) {
                     print($text_fid "$string");
                 }
                 print "$string";
            } elsif ( $format eq "pretty") {
                if (  $text_fid > -1 ) {
                    print($text_fid "${indent}$key =\n");
                }
                print "${indent}$key =\n";
                $value=aoaref_to_singleline($aspect_header_ref->{$key});
                display_header_entry("$value","${indent}\t",$text_fid);
            }
            
        }
    }
    if ( $text_fid > -1 ){
        close $text_fid;
    }
    return;
}

###
sub old_array_find_by_length { # ( $aspecthash_ref,$arraylength)
###
=item array_find_by_length

searches the whole aspect header from a aspect_header_ref for arrays
$arraylength

=cut

    my ($aspect_header_ref,$indent,$arraylength)=@_;
    debugloc();
    my @bfkeys=qw/a b/;
    @bfkeys=keys(%{$aspect_header_ref});
    my $value="test";
    printd(75,"Aspect_Header_Ref:<$aspect_header_ref>\n");
    printd(55,"keys @bfkeys\n");
    my @matching_keys;

    if ( $#bfkeys == -1 ) { 
        print ("No keys found in hash\n");
    } else {
        foreach my $key (sort keys %{$aspect_header_ref} ) {
            my $aoaref=$$aspect_header_ref{$key};
            my $aoalength=$#{$aoaref}+1;
            my $subarraylength=$#{$aoaref->[0]};
#           print("aoaref$aoaref\n");
#           my $temp=$#{${aspect_header_ref}{$key}};
#           ($#{$aspect_header_ref->$key} +1)
            if ( $arraylength == $aoalength|| $arraylength == $subarraylength ) {
                $value=aoaref_to_singleline($aspect_header_ref->{$key});
                push(@matching_keys,$key);
                print "${indent}$key =\n";
                display_header_entry("$value","${indent}\t");
                }
            }
        print("There were ".($#matching_keys+1)." Keys which match=@matching_keys\n");
    }
    return @matching_keys;
}

###
sub old_single_find_by_value { # ( $aspecthash_ref,$arraylength)
###
=item single_find_by_value

searches the whole aspect header from a aspect_header_ref for value
$value

=cut
    my ($aspect_header_ref,$indent,$testvalue)=@_;
    debugloc();
    my @bfkeys=qw/a b/;
    @bfkeys=keys(%{$aspect_header_ref});
    my $value="test";
    printd(75,"Aspect_Header_Ref:<$aspect_header_ref>\n");
    printd(55,"keys @bfkeys\n");
    my @matching_keys;

    if ( $#bfkeys == -1 ) { 
        print ("No keys found in hash\n");
    } else {
        foreach my $key (sort keys %{$aspect_header_ref} ) {
            my $aoaref=$$aspect_header_ref{$key};
            my $aoalength=$#{$aoaref}+1;
            my $subarraylength=$#{$aoaref->[0]};
#           print("aoaref$aoaref\n");
#           my $temp=$#{${aspect_header_ref}{$key}};
#           ($#{$aspect_header_ref->$key} +1)
            if ( 1 == $aoalength && 1 == $subarraylength ) {
                $value=aoaref_to_singleline($aspect_header_ref->{$key});
                if ( "($testvalue)" eq "$value" ) { 
                    push(@matching_keys,$key);
                    print "${indent}$key =\n";
                    display_header_entry("$value","${indent}\t");
                }
            }
        }
        print("There were ".($#matching_keys+1)." Keys which match=@matching_keys\n");
    }
    return @matching_keys;
}


###
sub old_display_header_entry { # ( $ref_to_aoa
###
=item display_header_entry { # ( $ref_to_aoa

prints the output of aoaref_to_singleline nicely

=cut

    my ($value,$prefix,$text_fid)=@_;
#    my $value="test";
    my @subarrays=split(':',$value);  # this has a bug with info display liness that is non critical in that is splits on the time string. 
    for my $subarray (@subarrays) {
        if (defined $text_fid && $text_fid > -1 ) {
            print($text_fid "$prefix$subarray\n");
        }
        print("$prefix$subarray\n");
    }
    return;
}

###
sub parse_array { # ( $elementsstring, @dimesions)
###
=item parse_array { # ( $elementsstring, @dimesions)

build data array for arrays.
returns the array

=cut
    my (@dimensions) = @_;
    debugloc();
    printd(99,"input <".join(':',@dimensions).">\n");
    if ($#dimensions<=0) { 
        return (1,'get dimension error');
#       confess "Cannot separate data from array dimensions\n";
    }
    my $subarray_text=pop(@dimensions); # cannot check for error here, not sure why. 
### pick dimension settings
#   Assumptions! there will at max be 3 dimensions worth of header information, 
# we'll error if there is more.
#   If there are less than 3 dimensions worth of header information for a 
# given key, we'll want the outer dimesnsion to be 1.
#   The reasoning behind this assumption is that the outer dimension seems 
# to be related to the number of volumes in a given acquisition/experiment.
    my $outer_dim    = 1; # number of subarrays we should have, dimension one of our array of arrays.
    my $subarraysize = 1; # totalsize of remaining data fields once major dimension is missing.
    my $dimstring    = "";# string containing the dimensions of the subarray, will be 1 or 2 values separated by acolon :
    if ( $#dimensions >2 || $#dimensions < 0 ) { # more than 3 less than 1 dimensions error.
        return(1,"Bad dimenssions specified. Never saw more than 3 dimensions to a header array bailing now with dimensions @dimensions and data $subarray_text\n");
    } 
    if ( $#dimensions == 2 ) { 
        $outer_dim=shift @dimensions;
        $dimstring=join(':',@dimensions);
        foreach (@dimensions) {
            $subarraysize=$_*$subarraysize;
        }
    } else {
        $dimstring=$dimensions[-1];
        $subarraysize=$dimensions[-1]; # last element
    } 
    $subarraysize=$subarraysize-1;# have to take one off because our subarray matches are 1 element optionally followed by separator $element up to subarraysize
    my $varchar_length=$subarraysize+2; # special for varchar strings, just makes syntax easier below
### pick regex
# foreach thing there are two regexs, one which matches a single element of the subarrays, 
# and antoehr which is matches an entire subarray.
    my $regex;       #### var to store a single subarray match into.
    my $single_element_regex;
    my $subseparator;
    my $num_ex="[-]?[0-9]+(?:[.][0-9]+)?(?:e[-]?[0-9]+)?"; # positive or negative floating point or integer number
    my $num_sa_ex="((?:$num_ex)(?:[ ]$num_ex){$subarraysize})"; 
    my $string_ex="(?:\\w+)"; #single string withonly good characters
    my $string_sa_ex="((?:$string_ex)(?:[ ]$string_ex){$subarraysize})";
    my $varchar_ex="(?:<[^>]{0,$varchar_length}>)" ; #string enclosed in < > with any character in between, had a comma in side list, took that out now, we'll see if this causes trouble.
    my $varchar_sa_ex="((?:$varchar_ex)(?:[ ]$varchar_ex)*?)";  #  this one isnt substringsize long, its somthing else, probably outerdim, but for now we'll allow it to be anything long{$subarraysize}
    my $mixed_ex="(?:[(](.*?)[)])"; 
    my $mixed_sa_ex=$mixed_ex;
#    my $mixed_sa_ex="((?:$mixed_ex)(?:[ ]$mixed_ex)*)"; #{$subarraysize}
    my @array_of_subarrays;
    my $type='';
    if ( $subarray_text =~ m/^$num_sa_ex/x) { #(?:[ ]$num_sa_ex){$subarraysize} #^($num_sa_ex[ ]?)+$
        $subseparator=' ';
        $single_element_regex="($num_ex)";
        $regex="$num_sa_ex";
    } elsif ( $subarray_text =~ m/^$string_sa_ex/x) { 
        $subseparator=' ';
        $single_element_regex="($string_ex)";
        $regex="$string_sa_ex";
    } elsif ( $subarray_text =~ m/^$varchar_sa_ex/x) {
        $subseparator=' ';
        $single_element_regex="($varchar_ex)";
        $regex="$varchar_sa_ex";
        $subarraysize=-1; # because of tricks we need to set the subarraysize inside the loop.
    } elsif ( $subarray_text =~ m/^$mixed_sa_ex/x ) {                 #### subarrays, detects data surrounded in ( ) which subarrays will be.
        $type='mixed';
        $subseparator=',';
        $single_element_regex="($mixed_ex)";
        $regex="$mixed_sa_ex";
        $subarraysize=-1; # because of tricks we need to set the subarraysize inside the loop.
    } else {
        confess "Unknown data format for array ($subarray_text) outerdim=$outer_dim, subsize=".($subarraysize+1)."\n".
            "regexes----\n".
            "\tnumber: $num_sa_ex\n".
            "\tstring: $string_sa_ex\n".
            "\tvarchar:$varchar_sa_ex\n".
            "\tmixed:  $mixed_sa_ex\n".
            "----\n\n";
    }
### separate subarrays
    printd(90,"   ->parsing $outer_dim x ($dimstring) array, subarraysize of ".($subarraysize+1)."\n");    
    if (  @array_of_subarrays = ( $subarray_text =~ m/$regex/gx ) ) { #( @array_of_subarrays )
        printd(90,"\t ".($#array_of_subarrays+1)." subarrays matched $regex\n");
        for(my $s=0;$s<=$#array_of_subarrays;$s++) {
            my $subarray=$array_of_subarrays[$s];
            my @parts; 
#           if ( $subarray =~ m/<.*?>/x ) {
            if ( $type eq 'mixed') {
                @parts=split("$subseparator",$subarray); # $subsseparator is to switch between a space or a comma as the separator between subarrays. 
            } else { 
                (@parts)= $subarray=~ m/$single_element_regex/gx;
            }
            printd(90,"\t\tsubarray:$subarray\n\t\t".($#parts+1)." parts: @parts\n");
            for(my $p=0;$p<=$#parts;$p++) {
                printd(99,"\t\t\telementin:\t<$parts[$p]>\n");
                my ($val) = $parts[$p] =~ m/^[ ]?(<?.*?>?)[ ]?$/x;
                warn "error with text in subarray $array_of_subarrays[$s]".
                    " which is part of array subarray chain $subarray_text\n" unless ( defined $val );
                if ( $val eq "" || ! defined $val ) { $val="BLANK"; } 
                $parts[$p]= $val ;
                printd(99,"\t\t\telementout:\t<$parts[$p]>\n");
            }
            if ( $subarraysize == -1 ) { 
                $subarraysize=$#parts+1;
                $dimstring=$subarraysize;
            }
            unshift(@parts,$dimstring);# adds dimensions to each substring.
            $subarray=join(',',@parts);
#            printd(90 ,"\t\t\tsubout:\t$subarray\n");
            $array_of_subarrays[$s]=\@parts;
        }
        return @array_of_subarrays;
    } else { 
        croak "BAD Sub array text <$subarray_text> sent to parse_array function\n";
    }
    return (1,'generic error');
}

###
sub parse_subarrays { # ( elements, subarray_datastring )
###
=item parse_subarrays { # ( elements, subarray_datastring )

takes the number of sub arrays and the sub array data 
takes the sub array data string, 
returns the array

=cut
    my ($elements, @input)=@_;
    my $subarray_text=join('',@input);
    debugloc();
    printd(90,"   ->parsing $elements elements long sub array list , $subarray_text\n");
    my @array_of_subarrays; 
    my $regex;
    my $singlesubregex="[(](.*?)[)]"; # mixed subarray regex
    $regex="$singlesubregex";
    if (  @array_of_subarrays = ( $subarray_text =~ m/$regex/gx ) ) { #( @array_of_subarrays )
        printd(90,"\tsubarraymatched $singlesubregex\n");
        for(my $s=0;$s<=$#array_of_subarrays;$s++) {
            my $subarray=$array_of_subarrays[$s];
            my @parts=split(',',$subarray);
            printd(90,"\t\tsubarray:$subarray\n");
            for(my $p=0;$p<=$#parts;$p++) {
                printd(99,"\t\t\telementin: $parts[$p]\n");
                my ($val) = $parts[$p] =~ m/^[ ]?<?(.*?)>?[ ]?$/x;
                warn "error with text in subarray $array_of_subarrays[$s]".
                    " which is part of array subarray chain $subarray_text\n" unless ( defined $val );
                if ( $val eq "" || ! defined $val ) { $val="BLANK"; } 
                $parts[$p]= $val ;
                printd(99,"\t\t\telementout:$parts[$p]\n");
            }
            $subarray=join(',',@parts);
            printd(90 ,"\t\t\t$subarray\n");
            $array_of_subarrays[$s]=\@parts;
        }
        return @array_of_subarrays;
    } else { 
        croak "BAD Sub array text <$subarray_text> sent to parse_subarray function\n";
    }
    return 1;
}


### 
sub read_til_next_keyline { # ( \@aspect header
###
=item read_til_next_keyline { # ( \@aspect header

reads from array until line starting with ## or $$

=cut
    my ( $aspect_header_ref) = @_;
    debugloc();
    my @data=();
    my $line;
    do {
        $line = shift(@{$aspect_header_ref}) or confess " could not get line";                #### get new line
        if ( defined $line ) {
            chomp($line);
            printd(90,"adding line $line to data\n");
            push(@data,$line); 
        } 
    } until ( $line =~ /^(?:[#]{2})|(?:[$]{2})/x ) ;     #### read until line starts with ## or $$ and ends with )
#|| ( ! defined $line )
    unshift(@{$aspect_header_ref},$line);                   #### put non matching line back
    $line=pop(@data);
    printd(90,"removed keyline $line to data\n");
    $line=join('',@data);
    return $line;
}

#           if( $aspectmultidimcode == 1  ) {
#               print("EXPERIMENTAL MULTI DIM CODE ACTIVE\n");
#               # check dimensionsizes, this is the dimeensions of the data in the aspect header, only 3 have have been observed, but we'll check for up to 4.
#               my $aspect_header_dimensionamax=1;
#               my $aspect_header_dimensionbmax=1;
#               my $aspect_header_dimensioncmax=1;
#               my $aspect_header_dimensiondmax=1;
#               my @dimensionsizes;
#               my @dataarray;
#               if($#dimensionsizes == 3 ) # 4 dims
#               {
#                   ( $aspect_header_dimensionamax,$aspect_header_dimensionbmax,$aspect_header_dimensioncmax,$aspect_header_dimensiondmax )= @dimensionsizes;
#               }
#               elsif($#dimensionsizes == 2 ) # 3 dims
#               {
#                   ( $aspect_header_dimensionbmax,$aspect_header_dimensioncmax,$aspect_header_dimensiondmax )= @dimensionsizes;
#               }
#               elsif($#dimensionsizes == 1 ) # 2 dims
#               {
#                   ( $aspect_header_dimensioncmax,$aspect_header_dimensiondmax )= @dimensionsizes;
#               }
#               elsif($#dimensionsizes == 0 ) # 1 dim
#               {
#                   ( $aspect_header_dimensiondmax )= @dimensionsizes;
#               }
#               else
#               {
#                   @dataarray=($data);
#                   die ("Unforseen error, $varname value unexpected number of values\n");
#               }
#               # may have to swap dima and dimd, we'll see...
#               for(my $dima=1;$dima<=$aspect_header_dimensionamax;$dima++){
#                   for(my $dimb=1;$dimb<=$aspect_header_dimensionbmax;$dimb++){
#                       for(my $dimc=1;$dimc<=$aspect_header_dimensioncmax;$dimc++){
#                           for(my $dimd=1;$dimd<=$aspect_header_dimensiondmax;$dimd++){
#                               $aspecthash{"$varname"}[$dima][$dimb][$dimc][$dimd]=@dataarray[$dima*$dimb*$dimc*$dimd-1];
#                           }
#                       }
#                   }
#               }
#           }
#           else {
=back
=cut
1;


