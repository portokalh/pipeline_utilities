################################################################################
# James Cook.
# use perldoc agilent to get easily info on functions
=head1 agilent.pm

module to hold functions for looking at agilent data from our civm
agilent scanner.

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
# agilent format definition estimation
#  identifiable types array of arrays of scalars or strings, array of arrays of string
#  variable names are always on a single line with space immediatly following them. 
#  further followed by a space separated sequence of float and int numbers
# 
# strings are always enclosed in quotes even when empty
# ints and floats are mixed in arrays
# floats can be in scientific notation
# arrays of strings are newline separated
# arrays of chars are space separated
# 
# Examples, array of arrays with only one being populated with 1 element.
##int
# gssf 1 1 9.99999984307e+17 -9.99999984307e+17 0 2 1 0 1 64
# 1 1
# 0 
##float
# B0 1 1 1000000 -1000000 0 2 1 0 1 64
# 1 93987.8736591
# 0 
# bvalrp 1 1 9.99999984307e+17 -9.99999984307e+17 0 3 1 0 1 64
# 7 0 773.668440162 0 0 -773.668440162 0 -0
# 0 
##empty string
# aipFid 2 2 8 0 0 2 1 0 1 64
# 1 ""
# 0 
##string
# console 2 2 8 0 0 2 1 0 1 64
# 1 "vnmrs"
# 0 
# actionid 2 2 8 0 0 4 1 0 1 64
# 1 "n006"
# 0 
## array of arrays of single strings
# alock 2 2 8 0 0 2 1 0 1 64
# 1 "n"
# 5 "a" "n" "s" "u" "y"
# axis 4 2 4 0 0 4 1 0 1 64
# 1 "cc"
# 11 "c" "d" "1" "2" "3" "h" "k" "m" "n" "p" "u"
# cp 2 2 1 0 0 2 1 0 1 64
# 1 "y"
# 2 "y" "n"
# Example, array , (of mixed arrays?), 
# ap 2 2 1023 0 0 4 1 6 1 64
# 12 "1:SAMPLE:date,file;"
# "1:NUCLEUS:tn,sfrq:3,resto:1;"
# "1:ACQUISITION:sw:1,at:3,np:0,nv:0,nt:0,gain:0,dp;"
# "1:DELAYS:tr:4,te:4,tspoil:4;"
# "1:RF PULSES:rfcoil,p1:1,p1pat,tpwr1:0,p2:1,p2pat,tpwr2:0;"
# "1:GRADIENTS:gcoil,pilot,gro:3,gpe:3,gss:3,gror(pilot='n'):3,gssr(pilot='n'):3;"
# "1:FIELD OF VIEW:orient,lro:2,lpe:2,pro:2;"
# "2:SLICE SELECTION:ns:0,thk:2,pss:2;"
# "2:DISPLAY:sp:1,wp:1,vs:0,sc:0,wc:0,hzmm:2,is:2,rfl:1,rfp:1,th:0,ins:3,aig*,dcg*,dmg*;"
# "2:2D DISPLAY:sp1:1,wp1:1,sc2:0,wc2:0,rfl1:1,rfp1:1;"
# "2:PROCESSING:lb(lb):2,sb(sb):3,sbs(sb):3,gf(gf):3,gfs(gf):3,awc(awc):3,lsfid(lsfid):0,phfid(phfid):1,fn:0,werr,wexp,wbs,wnt;"
# "2(ni):2D PROCESSING:lb1(lb1):2,sb1(sb1):3,sbs1(sb1):3,gf1(gf1):3,gfs1(gf1):3,awc1(awc1):3,fn1:0;"
# 0
# birthday 2 2 8 0 0 3 1 0 1 64
# 4 ""
# ""
# ""
# ""
# 0
# gcoil 2 2 8 0 0 2 1 9 1 64
# 1 "BFG_73_45_100"
# 0
# go_Options 2 2 8 0 0 2 1 7 1 64
# 4 "au"
# "sync"
# "vp"
# "noop"
# 0

package agilent;
use strict;
use warnings;
use Carp;
use List::MoreUtils qw(uniq);
#require civm_simple_util;


use Env qw(RADISH_PERL_LIB);
if (! defined($RADISH_PERL_LIB)) {
    print STDERR "Cannot find good perl directories, quiting\n";
#    exit $ERROR_EXIT;
}
use lib split(':',$RADISH_PERL_LIB);
use hoaoa qw(aoaref_to_printline aoaref_to_singleline aoaref_get_subarray aoaref_get_single printline_to_aoa);
use civm_simple_util qw(printd whoami whowasi debugloc $debug_val $debug_locator);
use hoaoa;
#my (@ISA,@Export,@EXPORT_OK);
BEGIN { #require Exporter;
    use Exporter(); #
    our @ISA = qw(Exporter);
#    our @Export = qw();
    our @EXPORT_OK = qw(
parse_header
determine_volume_type
read_til_next_keyline
@knownmethods
);
}    

my $Hfile = 0;
my $NAME = "agilent lib";
my $VERSION = "2013/03/04";
my $COMMENT = "Agilent meta data functions";
my @knownmethods= qw(  ); # tested acquisition methods for agilent extract. might be good to pull this out to configuration variables. 


###
sub parse_header {   #( \@agilentheaderarrayoflines,$debug_val )
###
=item parse_header($array_ref,$debug_val)

takes an array reference to the header loaded as one line per element

=cut
    my (@input)=@_;
    my $agilent_array_ref = shift @input;
    my $old_debug=$debug_val;
    $debug_val = shift @input or $debug_val=$old_debug;
    debugloc();
#    my @agilent_header = @{$agilent_array_ref};
    # hfile is and always is a ref
    my %agilenthash;
### Parse agilent header into civm header info, dump to agilenthash
    my $arraydefregex;
#     $arraydefregex="".
#         "^[(]".         # begning of line is with (
#         "[ ][0-9]+".    # a space and integer value follows
#         "(?:,".         # open character class which will be optional, it opens with a comma
#         "[ ][0-9]+".    # a space and integer value follows
#         ")*".           # close character class
#         "[ ][)]\$";   # line ends with a space ) 

# hope to match data ~
# 5 "y" "a" "B" "x" "z"
# 1 "a"
# 1 1
$arraydefregex="".
    "^[0-9]+".       # begining of line data is a integer number followed by a space
#     "(:?".           # open grouping
#     "[ ]".        # data elements start with(are separated by) space.
#     "\"".            # a double quote
#     "[^\\t\\r\\n\\f\"]+".      # followed by anthing but a quote or whitespaec
#     "\")".           # followed by a quote close grouping
#     "|".             # or
#    "(".           # open grouping
#    "[ ]".        # data elements start with(are separated by) space.
#    "[^\\t\\r\\n\\f]+".        # followed by anthing but a quote or whitespaec
#    ")".             # close grouping
    "";
    
    
    printd(90,"array def regex is <$arraydefregex>\n");

### process headers one line at time
    while ( $#{$agilent_array_ref} >= 0 ) {
        # eat agilent header lines one at a time. 
        # place header in array(of arrays) as we process it, 
        my $keyline = shift (@{$agilent_array_ref});
        chomp $keyline;
        printd(75,"Key Line $keyline\n"); 
        my $dataline = "";
        my $rawvalue = "";
        my @dataarray = ('BLANK');
### Separate lines , if the output variable has a $ it is important data, otherwise its meta
	my ( $varname, $val) = ( $keyline =~ /^([\w]+)(.*)$/x );
        # varname should be the name or the $name of the hash element to use, 
	# not sure that val is useful information very unclear its purpose
	if (defined $varname ) { 
	    $val=read_til_next_keyline($agilent_array_ref); #### get the array data
	}
        if (! defined $varname || "$varname" eq "" ) { $varname="BLANK"; }      #### fix bad values from regex
        if (! defined $val || "$val" eq ""         ) { $val="BLANK"; }          #### fix bad values from regex
        printd(65, "\trawname = $varname \n\t\trawvalue = $val\n" ); 


        if ( "$varname" eq "BLANK" || "$val" eq "BLANK" )  { 
            if ( $varname ne "END" ) {
                printd(50,"WARNING: Blanks found! keyline $keyline\n"); 
            }
            $dataarray[0]=( [$val] );
        } elsif ( $val !~ m/$arraydefregex/x ) {
	    printd(25,"WARNING: couldnt recognize data type\n");
        } elsif ( $val =~ $arraydefregex ) {                #### array
	    printd(75,"Detected array\n");
	    @dataarray=parse_array($val);
	    #foreach element in dataarray?
            if ( $dataarray[0]==1 ) { #1 is an error code
                confess "error with $varname=$val, $dataarray[1]\n";
            }
            $varname="${varname}";                          #### put the $ back on varname.
        } else {
            printd(90,"Cannot understand keyline: $keyline\n");
        }# end of line processing
	
        if ( defined $varname && $varname ne "BLANK" )  { 
#            ($varname) = $varname =~ m/^\$?(.*)$/x;          #### take the $ off varname
            if ( ! defined $varname ) {
                confess ( "varname failure\n");
            }
            if ($dataarray[0] ne 'BLANK' ) {
                $agilenthash{${varname}}=\@dataarray; #must store as ref, cannot pass as array between functions
                my $data=aoaref_to_singleline($agilenthash{$varname});
#                printd(45,"\tAssignment Sucessful!\n\t\$varname=<$data> \n");
                printd(45,"\tData:\n");
                if ( $debug_val >=45 ) { 
                    display_header_entry($data,"\t\tsub:"); 
                }
                
            } else {
                confess ("varname:<$varname> value undefined\n $val\n");
#                $agilenthash{"${varname}"}=( [""] );
            }
            $varname="\$$varname";                              #### put the $ back on varname.
        }# end store info in hash
    } # @agilentheader out of lines
    $debug_val=$old_debug;
    return \%agilenthash;
} # end of parse_head function

=item determine_volume_type($agilent_header_hash_ref)

looks at variables and detmines the volume output type from the
different posibilities.  2D, or 3D if 2d, multi position or single
position 2d, single or multi echo, or multi time (maybe multiecho is
same as multi time.)  3D are there multi volumes? may have to check
for each kind of multivolume are there multi echo's?  (time and or
dti) or slab?

returns info as "${vol_type}:${vol_detail}:${vol_num}:${x}:${y}:${z}:${bit_depth}:${data_type}:${order}";
$vol_type=(2D|3D|4D);# text
$vol_detail=(single|DTI|MOV|slab)|(multi(-vol|-echo)?); #text
$vol_num=[0-9]+; #total number of volumes, 
$bit_depth=(16|32|64);
$data_type=(Signed|Unsigned|Real); # ij data type for datatype string Real means float
$order=(H_F|A_P); # not sure what this is supposed to be for non-bruker scans, it comes from PVM_SPackArrReadOrient


=cut
###
sub determine_volume_type { # ( \%agilent_header_ref )
###
    my (@input)=@_;
    my $agilent_header_ref = shift @input;
    my $old_debug=$debug_val;
    $debug_val = shift @input or $debug_val=$old_debug;
    my $vol_type=1; # 2D 3D 4D
    my $vol_detail="single"; # DTI MOV slab mutlti-vol multi-echo, perhaps add multi-echo-non_interleave
    my $vol_num=1; # total number of volumes, 
    my $time_pts=1; # number timepoints, currently only used for dti
    my $channels=1;
    my $x=1;
    my $y=1;
    my $z=1; # slices per volume
    my $ne=1; #number of echos per volume
    my $slices=1;#total z dimension 
    my $order="NA"; # dimension report order code from scanner, may not be used under agilent, was used to determine if frequency or phase info was first on bruker. 
### keys which may help
### multi2d
### multi3d, dti
### multislab
### multi echo
#ne is number of echos, looks to hold true for two of test volumes
    
### 3d single

    
# for epi images, there are navigator echos, which
# should be subtracted from the number of lines.
# this can be known from the name of the petable
# the petable name should be something like
# "epi132alt8k". We want the second number
# r means that it is a sense petable
# t means t-sense acc factor

# the number of shots should now be read from the field nseg rather than from the petable
# if navecho is not set by now, then there were no navecho's
# compute the number of echoes with
#    procpar.navechoes = procpar.navecho*procpar.numshots/procpar.accfactor;

### get volume_type
    $ne=aoaref_get_single($agilent_header_ref->{ne});

### get the dimensions 
    $x=aoaref_get_single($agilent_header_ref->{np})/2;
    $y=aoaref_get_single($agilent_header_ref->{nv});
    $z=aoaref_get_single($agilent_header_ref->{nv2});
    $ne=aoaref_get_single($agilent_header_ref->{ne});
    if ($z == 0 ){
	$z=aoaref_get_single($agilent_header_ref->{ns});
	$vol_type="2D"; # chan
	if( $z == 0 ) { 
	    printd(25,"cannot get n slices");
	}
    } else { 
	$vol_type="3D";
    }

### get bit depth
# just faking this for now with agilent, will work on that later. 
    my $bit_depth=32;
    my $data_type="Real";
#     if ( defined $agilent_header_ref->{"RECO_wordtype"} ) {
# 	my $input_type=aoaref_get_single($agilent_header_ref->{"RECO_wordtype"});
# 	if ( ! defined $input_type ) { 
# 	    croak("Required field missing from agilent header:\"RECO_wordtype\"");
# 	}
# 	if    ( $input_type =~ /.*_16BIT_.*/x ) { $bit_depth = 16; }
# 	elsif ( $input_type =~ /.*_32BIT_.*/x ) { $bit_depth = 32; }
# 	elsif ( $input_type =~ /.*_64BIT_.*/x ) { $bit_depth = 64; }
# 	else  { error_out("Unhandled bit depth in $input_type"); }
# 	if    ( $input_type =~ /.*_SGN_/x ) { $data_type = "Signed"; }
# 	elsif ( $input_type =~ /.*_USGN_.*/x ) { $data_type = "Unsigned"; }
# 	elsif (  $input_type =~ /.*_FLOAT_.*/x ) { $data_type = "Real"; }
# 	else  { error_out("Unhandled data_type in $input_type"); }
#     } else { 
# 	error_out("cannot find bit depth at RECO_wordtype, bailing.");
#     } 
    
### if both spatial phases, slab data? use spatial_phase_1 as x?y?
### for 3d sequences ss2 is n slices, for 2d seqences it is dim2, thats annoying..... unsure of this

###### determine dimensions and volumes
###### set time_pts    
    $vol_num=aoaref_get_single($agilent_header_ref->{volumes});
    if ( $vol_num > 1 ) { 
	$vol_detail='multi';
    }
    if ( $ne > 1 ) { 
	$vol_detail=$vol_detail.'-echo';
    }
    $debug_val=$old_debug;
    return "${vol_type}:${vol_detail}:${vol_num}:${x}:${y}:${z}:${bit_depth}:${data_type}:${order}";
}



###
sub parse_array { # ( $elementsstring)
###
# =item parse_array { # ( $elementsstring)

# build data array for arrays.
# returns the array

# =cut
    my ($subarray_text) = @_;
    debugloc();
### pick dimension settings
#   Assumptions! All agilent data is an array of arrays
# Subarrays elements are separated by spaces or newlines.
# Subarrays are spearated by their lenght on the beginning of a line.
# Subarrays can have length 0, but that should be the last one specified.
# Subarray elements which are not numbers are in double quotes "
# Subarrays separated by newlines have each element contained in double quotes
# 
    my $outer_dim    = 1; # number of subarrays we should have, dimension one of our array of arrays.
    my $subarraysize = 1; # totalsize of remaining data fields once major dimension is missing.
    my $dimstring    = "";# string containing the dimensions of the subarray, will be 1 or 2 values separated by acolon :
#     $subarraysize=$subarraysize-1;# have to take one off because our subarray matches are 1 element optionally followed by separator $element up to subarraysize
### pick regex
# foreach thing there are two regexs, one which matches a single element of the subarrays, 
# and antoehr which is matches an entire subarray.
    my $regex;       #### var to store a single subarray match into.
    my $single_element_regex;
    my $array_length_regex="(?:[0-9]+)";  #single int at beginning of line
    my $subseparator; # either space or newline
    my $num_ex="[-]?[0-9]+(?:[.][0-9]+)?(?:e[-]?[0-9]+)?"; # positive or negative floating point or integer number including scientricic notation.
    my $num_sa_ex="(${array_length_regex}[ ](?:${num_ex}[ ])+)"; 
#    my $string_ex="(?:\\w+)"; #single string withonly good characters
########    my $string_sa_ex="((?:$string_ex)(?:[ \n]$string_ex){$subarraysize})";
    my $string_ex="(?:\"(?:[^\"]|[\n])*\")"; #single string anything in double quotes ( can also be empty)
    my $string_sa_ex="(${array_length_regex}[ ](?:${string_ex}(?:[ ]|[\n])?)+)";
    my $mixed_ex="(?:$string_ex|$num_ex)"; 
    my $mixed_sa_ex="(${array_length_regex}[ ](?:${mixed_ex}[ ]|\n)+)";
    my @array_of_subarrays;
#    my $type='';
    if ( $subarray_text =~ m/^$num_sa_ex/x) { #(?:[ ]$num_sa_ex){$subarraysize} #^($num_sa_ex[ ]?)+$
        $subseparator=' ';
        $single_element_regex="($num_ex)";
        $regex="$num_sa_ex";
    } elsif ( $subarray_text =~ m/^$string_sa_ex/x) { 
        $subseparator='/[ \n]/';
        $single_element_regex="($string_ex)";
        $regex="$string_sa_ex";
        $subarraysize=-1; # because of tricks we need to set the subarraysize inside the loop.
    } elsif ( $subarray_text =~ m/^$mixed_sa_ex/x ) {                 #### subarrays, detects data surrounded in ( ) which subarrays will be.
#        $type='mixed';
#        $subseparator=',';
        $single_element_regex="($mixed_ex)";
        $regex="$mixed_sa_ex";
        $subarraysize=-1; # because of tricks we need to set the subarraysize inside the loop.
    } else {
        confess "Unknown data format for array ($subarray_text) \n". #outerdim=$outer_dim,  subsize=".($subarraysize+1)
            "regexes----\n".
            "\tnumber: $num_sa_ex\n".
            "\tstring: $string_sa_ex\n".
#            "\tmixed:  $mixed_sa_ex\n".
            "----\n\n";
    }
### separate subarrays 
   printd(90,"   ->parsing $outer_dim x ($dimstring) array, subarraysize of ".($subarraysize+1)."\n");    
    if (  @array_of_subarrays = ( $subarray_text =~ m/$regex/gx ) ) { #( @array_of_subarrays )
        printd(90,"\t ".($#array_of_subarrays+1)." subarrays matched $regex\n");
	
	###
	# split out sub elemetns of arrays
	###
	my $last_subarraysize=-1;
        for(my $s=0;$s<=$#array_of_subarrays;$s++) {
            my $subarray=$array_of_subarrays[$s];
	    printd(99,"\t working on subarray $subarray\n");
	    ###
	    # remove lenght element from beginning(and error check that)
	    ### 
	    ($subarraysize, $subarray) = $subarray =~ /^($array_length_regex)[ ](.*)$/x;
	    if ( ! defined $subarraysize || ! defined $subarray ) {
		carp ("Subarray did not split properly with using length expression $array_length_regex and item expression $single_element_regex\n got sub size of <$subarraysize> and subarray of <$subarray>\n");
	    }
	    
   	    printd(99,"\tpulled out subarraysize:<$subarraysize> with data <$subarray>\n");
	    if($subarray eq "" ) {
		printd(99, "INFO: no elements to sub array\n");
	    }
	    my @parts; 
	    (@parts)= $subarray=~ m/$single_element_regex/gx;
	    
	    if ($#parts == -1 ) {
		printd(99, "INFO: no elements to array\n");
	    }
	    if ($subarraysize != $#parts+1) {
		croak "Subarraysize did not match expected length $subarraysize != $#parts";
	    } else { 
	    }

            printd(90,"\t\tsubarray:$subarray\n\t\t".($#parts+1)." parts: @parts\n");
            for(my $p=0;$p<=$#parts;$p++) {
                printd(99,"\t\t\telementin:\t<$parts[$p]>\n");
                my ($val) = $parts[$p] =~ m/^[ ]?\"?(<?.*?>?)\"?[ ]?$/x; # extraneous character stripper, pulls off <> and " (double quotes
#                my ($val) = $parts[$p] =~ m/^[ ]?(<?.*?>?)[ ]?$/x; # extraneous character stripper, pulls off <> 
		#### check for bad characters, : , ; and put those in  ()
		if( $val =~ m/(?:[,:;])/x ) {
		    printd(85,"INFO: special characters, replacing with url encoding\n");
		}
		#encode characters only if we're an array
		if($#parts>0) {
		    $val =~ s/:/%58/gx;
		    $val =~ s/,/%44/gx;
		    $val =~ s/[ ]/%20/gx;
		}
		warn "error with text in subarray $array_of_subarrays[$s]".
                    " which is part of array subarray chain $subarray_text\n" unless ( defined $val );
                if ( $val eq "" || ! defined $val | $val eq "\"\"" ) { $val="BLANK"; } 
                $parts[$p]= $val ;
                printd(99,"\t\t\telementout:\t<$parts[$p]>\n");
            }
#            if ( $subarraysize == -1 ) { #agilent data always has to set 
	    $subarraysize=$#parts+1;
	    $dimstring=$subarraysize;
#             } else { 
# 	    }
	    unshift(@parts,$dimstring);# adds dimensions to each substring.
            $subarray=join(',',@parts);
#            printd(90 ,"\t\t\tsubout:\t$subarray\n");
            $array_of_subarrays[$s]=\@parts;
	    $last_subarraysize=$subarraysize;
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
sub read_til_next_keyline { # ( \@agilent header
###
=item read_til_next_keyline { # ( \@agilent header

reads from array until line contains single 0 or text followed by space separated floats and ints.

=cut
    my ( $agilent_header_ref) = @_;
    debugloc();
    my @data=();
    my $line;
#    my $array_end="(?:0[ ])";
####  (?:^[0][ ]$)|read until line starts with unquoted char string or is blank
    do {
        $line = shift(@{$agilent_header_ref}) or confess " could not get line";                #### get new line, not an errror in agilent to end on last element.
        if ( defined $line ) {
            chomp($line);
            printd(90,"adding line $line to data\n");
            push(@data,$line); 
        }	
    } until( ( $line =~ m/(?:^[a-zA-Z][\w]*[ ].*$)/x ) || ($#{$agilent_header_ref}==-1) );    
    if ($line =~ m/(?:^[a-zA-Z][\w]*[ ].*$)/x ) {
	$line=pop(@data); # always want to take off the last line, as we run past the end and have to  replace the keyline, 
	unshift(@{$agilent_header_ref},$line);                   #### put non matching line back only if it isnt a 0
	printd(90,"removed keyline $line from data\n");
    } else {
	printd(90,"kept last keyline $data[-1]\n");
    }
	

#    my $data_length=0;
#    ($data_length,$data[0]) = $data[0]=~ /^([0-9]+)( [ ].*)/x;
#    if($data_length-1 != $#data) {
#	printd(70,"WARNING: Did not find enough elements in array.\n");
#    }
    $line=join(" ",@data);
    return $line;
}


=back
=cut
1;


