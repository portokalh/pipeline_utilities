################################################################################
# James Cook
# hoaoa.pm 
# "hash of arrays of arrays" package.
# functions to handle a hash structure with "2D" arrays for values. 
# all values are 2D including singles. 
# 
# this is used by civm header parsing routines to look at store and convert 
# data to signle lines from scanner headers
################################################################################
package hoaoa;
use strict;
use warnings;
use Carp;
use List::MoreUtils qw(uniq);

use Env qw(RADISH_PERL_LIB);
if (! defined($RADISH_PERL_LIB)) {
    print STDERR "Cannot find good perl directories, quiting\n";
#    exit $ERROR_EXIT;
}
use lib split(':',$RADISH_PERL_LIB);

use civm_simple_util qw(printd whoami whowasi debugloc $debug_val $debug_locator);
use hoaoa;
use Headfile;


BEGIN { #require Exporter;
    use Exporter(); #
    our @ISA = qw(Exporter);
#    our @Export = qw();
    our @EXPORT_OK = qw(
aoaref_get_single
aoaref_get_subarray
aoaref_get_length
aoaref_get_sub_length
aoaref_to_singleline
aoaref_to_printline
array_find_by_length
aoa_hash_to_headfile
display_header
display_header_entry
single_find_by_value
printline_to_aoa
);
} 
#display_complex_data_structure1 old version, current version moved to pipeline_utilities

###
sub printline_to_aoa {  # ( $string )    
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
    if ( ! defined $values || ! defined $dims ) { 
	#printd(25,"Printline <$printline> did not split properly.\n");
	if ( ! defined $values ) { $values="$printline"; $dims=1;}
	if ( ! defined $dims ) { $dims="1"; }
	carp("WARN: Printline <$printline> did not split as expected.\n\tDims will be $dims\n\tValues will be $printline");
    }

    @dim_array=  ( $dims =~ m/([0-9]+[:+]?[ ]?)+/gx  );#(:?:([0-9]+)?)*
#    @dim_array=  ( $dims =~ m/([0-9]+[:+]?[ ]?)+/gx  );#(:?:([0-9]+)?)*

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

#    my $data='';
#    @val_array = ( $values =~ m/$element_ex/gx ) ;
    @val_array = ( $values =~ m/$num_ex/gx ) ;
    
    printd(90," nvalues$#val_array,  text->array  $values -> ".join('|',@val_array)."\n");
#     for my $aref ( @dataarray) {
#         my @subarray=@{$aref}; 
#         if ($dims eq "0" ) {
#             $dims=$subarray[0];
#         } elsif ( $dims ne $subarray[0] ) {
#             confess "Inconsisitent subarray dims current $dims, next $subarray[0]\n" ;
#         } elsif ( $dims eq "" ) { 
#             confess "No dims found \n";
#         }
#         @subarray=@subarray[1..$#subarray];
#         my $subjoin=join(" ",@subarray);
#         push(@text_array,"$subjoin");
#         printd(75, "\t ($subjoin) \n");
#     }

#     if  ( $#text_array>0 ) { 
#         $dims=($#text_array+1).":$dims,";
#     } elsif ("$dims" ne "1" ) { 
#         $dims=$dims.',';
#     } else { 
#         $dims="";
#     }
#    my $data=$dims.join (' ',@text_array);

    return @val_array;
}
}


=item aoa_hash_to_headfile

input: ($aoa_hashheader_ref, $headfile_ref , $prefix_for_elements)

 aoa_hashheader_ref - hashreference for the bruker header this module
creates.
 headfile_ref - ref to civm headfile opend by sally's headfile code 
 preffix_for_elements -prefix to put onto each key from aoa_hashheader

output: status maybe?

=cut
###
sub aoa_hash_to_headfile {  # ( $aoa_hashheader_ref, $hf , $prefix_for_elements)
###
    my ($header_ref,$hf,$prefix) = @_;
    debugloc();
    if ( ! defined $prefix ) { 
        carp "Prefix undfined when converting header hash to CIVM headfile";
    }
    my @hash_keys=(); #qw/a b/;
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

=item aoaref_get_single ( $ref_to_AoA )

get single value from agilent header.

=cut
###
sub aoaref_get_single { # ( $ref_to_AoA )
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
sub aoaref_get_length { # ( $ref_to_AoA )
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
sub aoaref_get_sub_length { # ( $ref_to_AoA )
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
sub aoaref_get_subarray { # ( $ref_to_AoA )
###
    my ($n, $dataarray_ref) = @_;
    my $reftype=ref($dataarray_ref); 
    my $err_cause;
    my @data;
    my @subarrays;
#defined  $bruker_header_ref->{$key} 
#    if ( $#{$dataarray_ref} >=1 ){
    if ( $dataarray_ref ne "" && $reftype eq 'ARRAY' ) {
	if ( defined @{$dataarray_ref->[($n-1)]} ) #depreciated warning, perhaps just omit defined keyword?
	{
	    @data=@{$dataarray_ref->[($n-1)]};
	} else {
	    @data="ERROR";
	}
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
#    } else {
#	$data[0]="ERROR";
#    }
    return @data;    
}


=item aoaref_to_singleline( $ref_to_AoA ) 

taking reference to array of arrays builds back a string which is easy
to parse. It separats subarrays elemtns with commmas and subarrays with :
ex, a 2 element array with 3 element subarrays would be converted to
(1,2,3):(4,5,6)
# does some reference error checking, calls aoa_to_singleline to do the work

=cut
###
sub aoaref_to_singleline { # ( $ ref_to_AoA ) 
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
sub aoa_to_singleline {  # ( @AoA, mode )    
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
	my $inconsistent_bool=0;
        for my $aref ( @dataarray) {
            my @subarray=@{$aref}; 
###
# why was ita  requirement for subarrays to match in length?
             if ($dims eq "0" ) {
                 $dims=$subarray[0];
	     } elsif ( $dims ne $subarray[0] ) { 
                 carp "\tINFO:Inconsistent subarray dims current $dims, next $subarray[0]\n" unless $debug_val < 75;
		     $inconsistent_bool=1;
	     }
            @subarray=@subarray[1..$#subarray];
            my $subjoin=join(",",@subarray); #@{$aref}); #[1..-1]
            push(@text_array,"($subjoin)");
            printd(75, "\t ($subjoin) \n");
        }
	if ( ! $inconsistent_bool) {
	    $data=join (':',@text_array);
	} else {
	    $data=join ('+',@text_array);
	}
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
sub aoa_to_printline {  # ( @AoA )    
###
=item aoa_to_printline ( @AoA )    

internal function doing the work of aoaref_to_printline

=cut
    my (@dataarray)=@_;
    debugloc();
    printd(90,"$dataarray[0]\n");
    my @text_array; #array containing the text for each sub array, 
    #my $subarrayelements; #=$#{$dataarray[0]};
    my @dims=();
    my $dim_string=""; 
    my $inconsistent_bool=0;
    for my $aref ( @dataarray) {
        my @subarray=@{$aref}; 
	push(@dims,$subarray[0]);
	#if ( $dims[$#dims] ne $subarray[0] ) {
	if ( $dims[$#dims] ne $dims[0] ) {
	    $inconsistent_bool=1;
###
# why was ita  requirement for subarrays to match in length? because of how we layed things out.
	    carp "\tINFO:Inconsistent subarray dims current $dims[$#dims], next $subarray[0]\n" unless $debug_val < 75;
         } elsif ( $dims[$#dims] eq "" ) { 
             confess "No dims found \n";
	}

        @subarray=@subarray[1..$#subarray];
#       $subarrayelements=$#subarray;
        my $subjoin=join(" ",@subarray);
        push(@text_array,"$subjoin");
        printd(75, "\t ($subjoin) \n");
    }
    if  ( $#text_array>0 ) {       # if the textarray has multiple elements
	if($inconsistent_bool) {
	    $dim_string=join('+',@dims).','; #($#text_array+1).":$dims,"; # add the dimension
	} else { 
	    $dim_string=($#text_array+1).":$dims[0],"; # add the dimension
	}
    } elsif ("$dims[0]" ne "1" ) {  # only one element, just put its dim string out
        $dim_string=$dims[0].',';
    } else {                        # only one array with only one element. 
        $dim_string="";
    }
        
    my $data=$dim_string.join (' ',@text_array);
    return $data;
}
=item aoaref_to_printline ($ref_to_AoA

taking reference to array of arrays builds back a string which is easy
to parse, and doenst contain additional special characters. It
separats subarrays elemtns with commmas and suarrays with : ex, a 2
element array with 3 element subarrays which would be single lined as
(1,2,3):(4,5,6) would be converted to 2: 3, 1 2 3 4 5 6 does some
reference error checking, calls aoa_to_printline to do the work

=cut
###
sub aoaref_to_printline { # ( $ ref_to_AoA ) 
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

displays the whole agilent header all pretty froma agilent_header_ref
print keys
headfile or pretty

=cut
###
sub display_header { # ( $agilenthash_ref,$indent,$format,$pathtowrite ) 
###
    my ($agilent_header_ref,$indent,$format,$file)=@_;
    debugloc();
    my @hash_keys=qw/a b/;
    @hash_keys=keys(%{$agilent_header_ref});
    my $value="test";
    printd(75,"Agilent_Header_Ref:<$agilent_header_ref>\n");
    printd(55,"keys @hash_keys\n");
    my $text_fid;#=-1;
    #my $FH='OUT';
    if ( defined $file ){ 
        open $text_fid, ">", "$file" or croak "could not open $file" ;
    } else {
	$text_fid=-1;
    }
    if ( $#hash_keys == -1 ) { 
        print ("No keys found in hash\n");
    } else {
        foreach my $key (sort keys %{$agilent_header_ref} ) {
            if ( $format eq "headfile" ) {
                 $value=aoaref_to_printline($agilent_header_ref->{$key});
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
                $value=aoaref_to_singleline($agilent_header_ref->{$key});
                display_header_entry("$value","${indent}\t",$text_fid);
            }
            
        }
    }
    if ( $text_fid > -1 ){
        close $text_fid;
    }
    return;
}


=item display_complex_data_structure1

displays the whole agilent header all pretty froma agilent_header_ref
print keys
headfile or pretty

=cut
###
sub display_complex_data_structure1 { # ( $agilenthash_ref,$indent,$format,$pathtowrite ) 
###
    use Scalar::Util qw(looks_like_number);
    my ($data_struct_ref,$indent,$format,$file)=@_;
    debugloc();
    my @hash_keys=qw/a b/;
    @hash_keys=keys(%{$data_struct_ref});
    my $value="test";
    printd(75,"Data_Struct_Ref:<$data_struct_ref>\n");
    printd(55,"keys @hash_keys\n");
    my $text_fid;#=-1;
    #my $FH='OUT';
    if ( defined $file ){ 
	if ( ! looks_like_number($file) ) { 
	    open $text_fid, ">", "$file" or croak "could not open $file" ;
	} else {
	    $text_fid=$file;
	    print("PREVIOUSLY OPEN FILE\n");
	}
    } else {
	$text_fid=-1;
    }
    if ( $#hash_keys == -1 ) { 
        print ("No keys found in hash\n");
    } else {
	#print( join(' ',sort keys %{$data_struct_ref})."\n"); if($text_fid>-1) { print($text_fid  join(' ',sort keys %{$data_struct_ref})."\n"); }
        foreach my $key (sort keys %{$data_struct_ref} ) {
	    my $reftype=ref($data_struct_ref->{$key}); 
	    if ( ! $reftype ) {
		$reftype='NOTREF';
	    }
	    print( "$indent$key:$reftype = "); if($text_fid>-1) { print($text_fid  "$indent$key:$reftype = "); }
	    if( $reftype eq "HASH" ) {
		#print( "$indent$key:$reftype\n");n if($text_fid>-1) { print($text_fid  "$indent$key:$reftype\n");n }
		if ( keys %{$data_struct_ref->{$key}}> 0 ) {
		    print( "{\n"); if($text_fid>-1) { print($text_fid  "{\n"); }
		    if ($text_fid>-1) {display_complex_data_structure1($data_struct_ref->{$key},$indent.$indent,'pretty',$text_fid);
		    } else { display_complex_data_structure1($data_struct_ref->{$key},$indent.$indent,'pretty');}
		    print( "$indent}\n"); if($text_fid>-1) { print($text_fid  "$indent}\n"); }
		} else {
		    print( "$indent${indent}EMPTY}\n"); if($text_fid>-1) { print($text_fid  "$indent${indent}EMPTY}\n"); }
		}
	    } elsif( $reftype eq "ARRAY" ) {
		my @A_TYPE=@{$data_struct_ref->{$key}};
		print( "\n"); if($text_fid>-1) { print($text_fid  "\n"); }
		if ( $#A_TYPE>=0){
		    print( "$indent${indent}elements:"); if($text_fid>-1) { print($text_fid  "$indent${indent}elements:"); }
		    for (my $el_i=0;$el_i<$#A_TYPE;$el_i++) {
			if ( defined $A_TYPE[$el_i] ){
			    print( " '",$A_TYPE[$el_i],"'"); if($text_fid>-1) { print($text_fid  " '",$A_TYPE[$el_i],"'"); }
			} else{ 
			    print( " UNDEFINED"); if($text_fid>-1) { print($text_fid  " UNDEFINED"); }
			}
		    }
		    print( "\n"); if($text_fid>-1) { print($text_fid  "\n"); }
		} else { 
		    print( "$indent${indent}EMPTY\n"); if($text_fid>-1) { print($text_fid  "$indent${indent}EMPTY\n"); }
		}
		#my $ref=$data_struct_ref->{$key};
		#print( $indent.join(' ',@A_TYPE)."\n"); if($text_fid>-1) { print($text_fid  $indent.join(' ',@A_TYPE)."\n"); }
	    } elsif( $reftype eq "SCALAR"|| $reftype eq 'NOTREF' ) {
		#print( "SCALAR\n"); if($text_fid>-1) { print($text_fid  "SCALAR\n"); }
		my $value=$data_struct_ref->{$key};
		if ( $reftype eq 'SCALAR') {
		    $value=${$data_struct_ref->{$key}};
		} else {
		}
		
		#print( $indent.${$data_struct_ref->{$key}}."\n"); if($text_fid>-1) { print($text_fid  $indent.${$data_struct_ref->{$key}}."\n"); }
		print( "$value.\n"); if($text_fid>-1) { print($text_fid  "$value.\n"); }
	    } elsif( $reftype eq "CODE" ) {
		print( $indent.$reftype."\n"); if($text_fid>-1) { print($text_fid  $indent.$reftype."\n"); }
	    } else {
		print( "REFTYPEUNKNOWN\n"); if($text_fid>-1) { print($text_fid  "REFTYPEUNKNOWN\n"); }
		#print ("$indent New type->$key:$reftype\n");
	    }
	    
#             if ( $format eq "headfile" ) {
#                  $value=aoaref_to_printline($data_struct_ref->{$key});
#                  my $string="$key=$value\n";
#                  if (  $text_fid > -1 ) {
#                      print( $text_fid "$string"); if($text_fid>-1) { print($text_fid  $text_fid "$string"); }
#                  }
#                  print "$string";
#             } elsif ( $format eq "pretty") {
#                 if (  $text_fid > -1 ) {
#                     print( $text_fid "${indent}$key =\n"); if($text_fid>-1) { print($text_fid  $text_fid "${indent}$key =\n"); }
#                 }
#                 print "${indent}$key =\n";
#                 $value=aoaref_to_singleline($data_struct_ref->{$key});
#                 display_header_entry("$value","${indent}\t",$text_fid);
#             }
            
        }
    }
    if ( $text_fid > -1 && -f $file  ){
        close $text_fid;
    }
    return;

#     my ($dataarray_ref) = @_;
#     my $reftype=ref($dataarray_ref); 
#     my $data;
#     if ( $dataarray_ref ne "" && $reftype eq 'ARRAY' ) {
#         $data=aoa_to_printline(@$dataarray_ref);
#     } elsif ( $reftype ne 'ARRAY' ) { 
#         confess "ref type $reftype wrong, at aoaref to singleline";
#     } else {
#         printd(35, "wierd problem with array ref in aoaref_to_singleline\n");
#         $data="ERROR";
#     }
#     return $data;
}


###
sub array_find_by_length { # ( $agilenthash_ref,$arraylength)
###
=item array_find_by_length

searches the whole agilent header from a agilent_header_ref for arrays
$arraylength

=cut

    my ($agilent_header_ref,$indent,$arraylength)=@_;
    debugloc();
    my @hash_keys=qw/a b/;
    @hash_keys=keys(%{$agilent_header_ref});
    my $value="test";
    printd(75,"Agilent_Header_Ref:<$agilent_header_ref>\n");
    printd(55,"keys @hash_keys\n");
    my @matching_keys;

    if ( $#hash_keys == -1 ) { 
        print ("No keys found in hash\n");
    } else {
        foreach my $key (sort keys %{$agilent_header_ref} ) {
            my $aoaref=$$agilent_header_ref{$key};
            my $aoalength=$#{$aoaref}+1;
            my $subarraylength=$#{$aoaref->[0]};
#           print("aoaref$aoaref\n");
#           my $temp=$#{${agilent_header_ref}{$key}};
#           ($#{$agilent_header_ref->$key} +1)
            if ( $arraylength == $aoalength|| $arraylength == $subarraylength ) {
                $value=aoaref_to_singleline($agilent_header_ref->{$key});
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
sub single_find_by_value { # ( $agilenthash_ref,$arraylength)
###
=item single_find_by_value

searches the whole agilent header from a agilent_header_ref for value
$value

=cut
    my ($agilent_header_ref,$indent,$testvalue)=@_;
    debugloc();
    my @hash_keys=qw/a b/;
    @hash_keys=keys(%{$agilent_header_ref});
    my $value="test";
    printd(75,"Agilent_Header_Ref:<$agilent_header_ref>\n");
    printd(55,"keys @hash_keys\n");
    my @matching_keys;

    if ( $#hash_keys == -1 ) { 
        print ("No keys found in hash\n");
    } else {
        foreach my $key (sort keys %{$agilent_header_ref} ) {
            my $aoaref=$$agilent_header_ref{$key};
            my $aoalength=$#{$aoaref}+1;
            my $subarraylength=$#{$aoaref->[0]};
#           print("aoaref$aoaref\n");
#           my $temp=$#{${agilent_header_ref}{$key}};
#           ($#{$agilent_header_ref->$key} +1)
            if ( 1 == $aoalength && 1 == $subarraylength ) {
                $value=aoaref_to_singleline($agilent_header_ref->{$key});
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
sub display_header_entry { # ( $ref_to_aoa
###
=item display_header_entry { # ( $ref_to_aoa

prints the output of aoaref_to_singleline nicely

=cut

    my ($value,$prefix,$text_fid)=@_;
#    my $value="test";
    #m/$regex/gx
#    my @subarrays=split(':',$value);  # this has a bug with info display liness that is non critical in that is splits on the time string. 
    my (@subarrays) = $value =~ /([\(].+[\)])/gx;
    for my $subarray (@subarrays) {
        if (defined $text_fid && $text_fid > -1 ) {
            print($text_fid "$prefix$subarray\n");
        }
        print("$prefix$subarray\n");
    }
    return;
}

=back
=cut
1;
