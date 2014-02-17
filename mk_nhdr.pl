#!/usr/bin/perl
# mk_nhdr.pl
# simple make nrrd header program taking either a nifti or a civm headfile

# example to work from
#unu make -h -i ./aneurism.raw.gz -t uchar -s 256 256 256 -sp 1 1 1 \
#-c aneurism -e gzip -o aneur.nhdr



use strict;
use warnings;
my $ERROR_EXIT   = 1; 
my $GOOD_EXIT    = 0; 

our $num_ex="[-]?[0-9]+(?:[.][0-9]+)?(?:e[-]?[0-9]+)?"; # positive or negative floating point or integer number in scientific notation.
our $plain_num="[-]?[0-9]+(?:[.][0-9]+)?"; # positive or negative number 
our $data_prefix ="";
use File::Basename;
use POSIX;

use Env qw(RADISH_PERL_LIB RADISH_RECON_DIR WORKSTATION_HOME WKS_SETTINGS RECON_HOSTNAME WORKSTATION_HOSTNAME); # root of radish pipeline folders
if (! defined($RADISH_PERL_LIB)) {
    print STDERR "Cannot find good perl directories, quiting\n";
    exit $ERROR_EXIT;
}
use lib split(':',$RADISH_PERL_LIB);
use Headfile;
use hoaoa qw(printline_to_aoa aoaref_to_singleline aoaref_to_printline aoaref_get_subarray);
use civm_simple_util qw(load_file_to_array write_array_to_file get_engine_constants_path printd whoami whowasi debugloc sleep_with_countdown $debug_val $debug_locator);

$debug_val=5;
my $reset_origin=0;
my $re_make_headfile=1;

my  $engine_settings_path = get_engine_constants_path($RADISH_RECON_DIR,$WORKSTATION_HOSTNAME);
my $EC = new Headfile ('ro', $engine_settings_path);
if (! $EC->check())       { error_out("Unable to open recon engine constants file $engine_settings_path\n"); }
if (! $EC->read_headfile) { error_out("Unable to read recon engine constants from file $engine_settings_path\n"); }
#my $Engine_binary_path    = $EC->get_value('engine_radish_bin_directory') . '/';
my $ants_dir= $EC->get_value('engine_app_ants_dir');
if ($ants_dir =~ m/NO_KEY/x ){
    exit;
}

#print "received ". ($#ARGV+1) ." args <".join(" ",@ARGV).">\n";

if ($#ARGV < 0 ) {
    print "No args found";
    exit;
} else {
    foreach ( @ARGV ) {
	my $fullname=$_;
	my $data_type;
	my $encoding='raw';
	# figureout input
	my ($name,$path,$suffix) = fileparse($fullname,qr/.[^.]*$/);
	if ( $suffix =~ m/\.gz/x) {
	    #print "GZ\n";
	    $encoding='gzip'; 
	    $fullname="$path$name";
	    ($name,$path,$suffix) = fileparse($fullname,qr/.[^.]*$/);
	    $suffix=$suffix.".gz";
	}
	#load_headfile or print header.
	my $hf ;
	my $hfpath=$path.$name.".headfile";
	if ( -e $hfpath && $re_make_headfile) { 
	    print STDERR "WARNING: Headfile existed but we're re-creating!\n";
	    #sleep_with_countdown( 1);
	}
	if ( ! -e $hfpath || $re_make_headfile) { 
	    print "Creating new headfile\n";
	    $hf = new Headfile ('nii', $_);
	    if ( ! $hf->check() ) { 
		print "nii check error\n";
	    }
	    my $ret;
# 	if (! ($ret = $hf->read_nii_header($ants_dir.'/PrintHeader', 0))) {
# 	    #error_out("unable to read latest pfile's header using $pfile_header_reader_app_path", $PHEADER_READ_PROBLEM);
# 	} else {
# 	    $hf->print_headfile("$name");
# 	}
	    if (! ($ret = $hf->read_nii_header($WORKSTATION_HOME.'/../fsl/bin/fslhd', 0))) {
		#error_out("unable to read latest pfile's header using $pfile_header_reader_app_path", $PHEADER_READ_PROBLEM);
	    } 
	    my %hfkey_aliaslist=( # hfkey=>[multiplier,alias1,alias2,aliasn] 
				  "dim_X"=>[
				      1,
				      'dim1',            # 
				  ],
				  "dim_Y"=>[
				      1,
				      'dim2',            # 
				  ],
				  "dim_Z"=>[
				      1,
				      'dim3',            # 
				  ],
				  "junk_var"=>[
				      1,
				      'exinkey',            # 
				  ],
				  "binary_header_size"=>[
				      1,
				      'vox_offset',
				  ],
				  "nifti_type"=>[
				      1,
				      'data_type',
				  ],
				  "transform1"=>[
				      1,
				      "sto_xyz:1"
				  ],
				  "transform2"=>[
				      1,
				      "sto_xyz:2"
				  ],
				  "transform3"=>[
				      1,
				      "sto_xyz:3"
				  ],
				  "fov_dim"=>[
				      1,
				      "vox_units",
				  ],
		);
	    
	    #print  join (' ', keys %hfkey_aliaslist )."\n";

	    hf_aliasinsert($hf,\%hfkey_aliaslist);
	    $hf->set_value("fovx",round($hf->get_value("dim_X")*$hf->get_value('pixdim1'),0));
	    $hf->set_value("fovy",round($hf->get_value("dim_Y")*$hf->get_value('pixdim2'),0));
	    $hf->set_value("fovz",round($hf->get_value("dim_Z")*$hf->get_value('pixdim3'),0));
	    #hf_aliasinsert(1,2,3);

	    $hf->write_headfile($hfpath); # this should be enabled once we figure out our orientation bits

	    if ( $hf->get_value("nifti_type") =~ m/^[fF][lL][oO][aA][tT]/x ) {
		$data_type="float";
	    } elsif ( $hf->get_value("nifti_type") =~ m/[iI][nN][tT]/x ) {
		if ( $hf->get_value("nifti_type") =~ m/^[uU][iI][nN][tT]/x ) {
		} else {
		    $data_type="int";
		}
	    } else {
		exit "error with hf";
	    }
	    if ( $hf->get_value("fov_dim") =~ m/Unknown/x ) {
		print STDERR "WARNING:unknown dimension units, ASSUMING mm!\n";
		$hf->set_value("fov_dim","mm");
	    }

# 	    my $transform="4:3,".$hf->get_value("transform1")." ".$hf->get_value("transform2")." ".$hf->get_value("transform3");
# 	    $hf->set_value("transform",$transform);
# 	    my @trans=hoaoa::printline_to_aoa($hf->get_value("transform"));
# 	    my @info;
# 	    for (my $i=1;$i<=$#trans;$i++) {
# 		@info=aoaref_get_subarray($i,@trans);
# 		print join(" ".@info);
# 	    }
#####
# convert using some kinda alias thingy.
#####
	    {
		$hf->print_headfile("$name");
	    }
	} else {
	    undef $hf;
	    print "Opening headfile\n";
	    $hf = new Headfile('ro',$hfpath);
	    $hf->read_headfile();
	    
	}
	
	my $out_nhdr=$path.$name.".nhdr";
	`echo '' > $out_nhdr`;
	#print "$name:$path:$suffix\n";

	#unu make -h -i "./$name".$suffix -t $type
#unu make -h -i ./aneurism.raw.gz -t uchar -s 256 256 256 -sp 1 1 1 \
#-c aneurism -e gzip -o aneur.nhdr
	my $center_volume_string="";
	my @origin=(
 	    -(split / /,$hf->get_value("transform1") )[3],
 	    -(split / /,$hf->get_value("transform2") )[3],
 	    (split / /,$hf->get_value("transform3") )[3]
	    );
	#@origin=(0,0,0);
	if ( $origin[0] == 0 && $origin[1] == 0 && $origin[2] == 0 ) {
	    @origin = (
		0-floor($hf->get_value('fovx')/2),
		0-floor($hf->get_value('fovy')/2),
		0-floor($hf->get_value('fovz')/2)
		);
	} #else {
	#$center_volume_string=" -orig  '(".
	#(split / /,$hf->get_value("transform1") )[3].",".
	#(split / /,$hf->get_value("transform2") )[3].",".
	#(split / /,$hf->get_value("transform3") )[3].")".
 	    #"'";
	#}
	## some orientaion tom foollery here, not sure why its required.
	my @t1=(split / /,$hf->get_value("transform1") )[0, 1, 2];
	my @t2=(split / /,$hf->get_value("transform2") )[0, 1, 2];
	my @t3=(split / /,$hf->get_value("transform3") )[0, 1, 2];
	$t1[0]=-$t1[0];
	$t2[1]=-$t2[1];
	#$t3[2]=-$t3[2];
	$center_volume_string=" -orig  '(".join(',',@origin).")'";
	
	my $cmd="unu make -bs ".
	    $hf->get_value('binary_header_size').
	    " -h -i ".$name.$suffix.
	    " -t ".$data_type.
	    " -s ".
	    $hf->get_value('dim_X')." ".
	    $hf->get_value('dim_Y')." ".
	    $hf->get_value('dim_Z')." ".
# 	    " -sp ".
# 	    round($hf->get_value('fovx')/$hf->get_value('dim_X'),4).
# 	    " ".
# 	    round($hf->get_value('fovy')/$hf->get_value('dim_Y'),4).
# 	    " ".
# 	    round($hf->get_value('fovz')/$hf->get_value('dim_Z'),4).
	    #" -spc RAS". # what slicer wants me to tell them,
	    #" -spc ARS". # our general reality, tottally fails
	    # " -spc anterior-right-superior". # our general reality, totally fails
	    " -spc 3".
	    $center_volume_string.
	    " -spu \"".$hf->get_value("fov_dim")."\" \"".
	    $hf->get_value("fov_dim")."\" \"".
	    $hf->get_value("fov_dim")."\" ".
	    " -k \"domain\" \"domain\" \"domain\"".
	     " -dirs ".
 	    "'".
 	    "(".join(",", @t1).") ".
 	    "(".join(",", @t2).") ".
 	    "(".join(",", @t3).") ".
 	    "'".
	    #print("transform_code$transform_code\n");
	    
	    " -e ".$encoding.
	    " -en little".
	    " -c inputfilename".$fullname.
	    " -o ".$out_nhdr.
	    " -kv test:=testdata".
	    "\n"; 
	print $cmd."\n";
	`$cmd`;

# unu crop -min 20 50 40 -max 820 390 400 -i /DataLibraries/Brain/Rattus_norvegicus/Wistar/average/00000172800/00000172800_average_fa.nhdr -o /DataLibraries/Brain/Rattus_norvegicus/Wistar/average/00000172800/00000172800_average_fa_c.nhdr

	my @all_lines;
	print("");
	if ( -e $out_nhdr ) {
	    load_file_to_array($out_nhdr,\@all_lines);
	    #chomp(@all_lines);
	    print(@all_lines."\n");
# 	    push (@all_lines,"min: 0\n");
# 	    push (@all_lines,"max: 1.22\n");
	    #push (@all_lines,'space units: "mm" "mm" "mm"'."\n");
	    #push (@all_lines,"space directions: ".$dir_vectors."\n");
	    print(@all_lines);
	    write_array_to_file($out_nhdr,\@all_lines);
	}
	

    }
}

#
sub round { 
    my( $val,$digs) = @_;
    if ( ! defined $digs){ 
	$digs=0
    }
#    printf "round $val => ";
    my $result=sprintf("%.".$digs."f",$val);
    #$result=sprintf("%.1f",$val);
#    printf "$result\n";
    return $result;
}
#
sub hf_aliasinsert { 
    my (@input) =( @_);
    #print("$#input args\n");
    my $old_debug=$debug_val;
    my $hf=shift @input;
    my $alias_ref  = shift @input;
    $debug_val = shift @input or $debug_val=$old_debug;
    if ( ! $hf->check() ) { 
	printd(25,"hfcheck fail in aliasinsert");
    }

    my @hash_keys=keys(%{$alias_ref});
    my $value="test";
    printd(75,"Hashref:<$alias_ref>\n");
    printd(55,"keys @hash_keys\n");

    my %hfkey_aliaslist=%{$alias_ref};
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
    return;
}
