# CSV functions
# csv_loader - Loads a csv with header from disk and makes a multi_linked hash structure.
# 
#

package text_sheet_utils;
use strict;
use warnings;
use Carp;
BEGIN {
    use Exporter;
    our @ISA = qw(Exporter); # perl cricit wants this replaced with use base; not sure why yet.
    our @EXPORT_OK = qw(
loader
text_header_parse
$debug_val 
$debug_locator
)
};
use civm_simple_util qw(load_file_to_array write_array_to_file printd whoami whowasi debugloc sleep_with_countdown $debug_val $debug_locator);# debug_val debug_locator);di

use Data::Dump qw(dump);

sub text_header_parse {
    my ($line,$separator)=@_;
    my $h_hash={};
    # standard separators
    my @separators=();
    push(@separators,sprintf("\t"));
    push(@separators,',');
    push(@separators,' ');
    
    #$line =~ s/[ ]/_/gx; #exchange space for underscore.
    chomp($line);
    
    if (defined ($separator) ) {
	@separators=($separator);
    } else {	
	warn("No separator defined");
    }
    dump($line,@separators);
    my @parts;
    my $sep_i=0;
    while(scalar (@parts) < 2 && $sep_i < scalar(@separators) ) {
	$separator=$separators[$sep_i];
	#@parts = $line =~ /([^$separator]+)/gx;
	@parts=split($separator,$line);
	$sep_i++;
    }
    $h_hash->{"Separator"}=$separator;
    #print("h_columns assign:".join(" ",@parts)."\n");
    #@h_columns=@parts;
    my $colN=0;# could do a +1 here to start at 1 instead.
    foreach (@parts){
	$h_hash->{$_}=$colN;
	$colN++;
    }
    return $h_hash;
}


sub loader {
    my ($path_text_table,$h_hash,@junkybits)=@_;
    my @text_lines;
    load_file_to_array($path_text_table,\@text_lines);
    # get splitter out of the header_hash
    my $splitter=$h_hash->{"Splitter"};
    if (defined $splitter ) {
	delete ($h_hash->{"Splitter"});# the if def check for splitter happens later.
    }
    #get separator out of the header hash
    my $separator=$h_hash->{"Separator"};
    if (defined $separator ) {
	delete ($h_hash->{"Separator"});# the if def check for separator happens later.
    }
    # get line_format out of the header hash
    my $line_format=$h_hash->{"LineFormat"};
    if ( not defined $line_format) {
	warn("Had to guess line format, we're going with, omit any line starting with a pound('#') sign");
	$line_format='^#.*';
    } else {
	delete ($h_hash->{"LineFormat"});
    }
    my $t_table={};
    my $t_line_num=0;
    if (scalar(keys(%$h_hash))<2 ) {
	#while line doesnt match $line_format
	if ( defined $separator ){
	    $h_hash=text_header_parse(shift(@text_lines),$separator);
	} else {
	    $h_hash=text_header_parse(shift(@text_lines));
	}
	$t_line_num++;
	#dump($h_hash);
	#exit;
    } elsif ( 0 ) {
	my @ontology_color_fields;
	my @parts;
	my @h_fields;
	
	my $name=$parts[$h_hash->{"Structure"}];
	#my $Abbrev=shift(@parts);
	my $Abbrev=$parts[$h_hash->{"Abbrev"}];
	#my $value=pop(@parts);
	my $value=$parts[$h_hash->{"Value"}];
	my $color='NULL';
	if ( not defined( $value ) ) {
	    warn("NO Value $name");
	    $value=100000;
	}
	if ( $#ontology_color_fields==3 ) { # the case this is fixes should NEVER happen,
	    # its just bugging out on test data.
	    #$color=join(@parts[@h_hash{@ontology_color_fields}]);
	}
	#@parts=@parts[@h_hash{@h_fields}];
    } elsif ( 0 )   {
	$h_hash->{"Value"}=0;
	$h_hash->{"Name"}=1;
	$h_hash->{"c_R"}=2;
	$h_hash->{"c_B"}=3;
	$h_hash->{"c_G"}=4;
	$h_hash->{"c_A"}=5;
	#$h_hash->{"Abbrev"}=-1;
	#$h_hash->{"Structure"}=-1;
    }
    #get separator out of the header hash
    if (not defined $separator ) {
	$separator=$h_hash->{"Separator"};
	if ( defined $separator ) {
	    delete ($h_hash->{"Separator"});# the if def check for separator happens later.
	}
    }
    # this loop sets up a nice comprehensive lookup structure for the color table.
    # for the primary keys of "structure Abbreviation and name", make a hash of primary
    # key to the colortable info for each color table entry
    foreach my $t_line (@text_lines) {
	$t_line_num++;# keep track of the color table line so we can reference it later.
	if ($t_line_num>3) { next;}
	#if ( $t_line !~ /^#.*/ ) {# if not comment.
	if ( $t_line !~ /$line_format/ ) {# if not comment.
	    my @tt_entry=split($separator,$t_line);
	    #dump(scalar(@tt_entry)."$t_line");
	    #dump($h_hash);
	    #exit;
	    if ( scalar(@tt_entry) != scalar(keys(%$h_hash)) ) {
		print("Bailing on bad entry with ($separator)\n");
		print("\t".scalar (@tt_entry)." != ".scalar(keys(%$h_hash))."(".join(":",@tt_entry).")\n");#scalar (%{$h_hash}) );
		#sleep_with_countdown(5);
		#continue;
		dump($h_hash);
		next;
		#last;
	    }
	    # color table is form of,
	    # VALUE NAME RED GREEN BLUE ALPHA
	    
	    # the expected format of our colortable comes from the avizo name format of alex. 
	    # the names used in avizo were "_?abbreviation__(_?)fullterribly_long_structure_name"
	    # some names add additional instances of double underscore. its uncertain what that was about.
	    my %newbits;#{$splitter->{"Input"}(0)}	
	    if( not defined $splitter) {
		warn("No splitters found, using defacto one. This should just be omitted. ");
		#@newbits{qw(Abbrev Name)} =  $tt_entry[1] =~/^_?(.+?)(?:___?(.*))$/;
	    } else {
		# foreach splitter
		my $in_index=$h_hash->{$splitter->{"Input"}[0]};
		$newbits{$splitter->{"Input"}[1]}=$tt_entry[$in_index];

		use Data::Dumper;# qw/Dumper/;
		#print("Regex:".sprintf Dumper($splitter->{"Regex"}));
		my $regex=$splitter->{"Regex"};
		#print("Output:".sprintf Dumper(@{$splitter->{"Output"}}));
		my @field_keys=@{$splitter->{"Output"}};# get the count ofexpected elementes
		
		#print("field_keys:".sprintf(Dumper(@field_keys)));
		#print("field_keys:".join(":",@field_keys));
		      
		#print("field_val:".sprintf Dumper($tt_entry[$in_index]));
		my $field_val=$tt_entry[$in_index] ;# for readablilty pulled this out.
		
		my @field_temp = $field_val  =~ /$regex/x;
		
		#print("Parts:".Dumper(@field_temp));
		@newbits{@field_keys} = @field_temp;
	    }
	    if ( 1 ) {
		my %entry_hash;
		@entry_hash{keys(%$h_hash)}=@tt_entry[values(%$h_hash)];
		@entry_hash{keys(%newbits)}=values(%newbits);
		$entry_hash{"t_line"} = $t_line_num;
		#dump(\%entry_hash);
		#exit;
		#my $Value = $tt_entry[0];
		#my $c_R = $tt_entry[2];
		#my $c_G = $tt_entry[3];
		#my $c_B = $tt_entry[4];
		#my $c_A = $tt_entry[5];
		#my @stv{qw(Structure Abbrev name)}=($tt_entry[1], $c_Abbrev, $c_name);
		#my @stv{qw[Structure Abbrev name]}=($tt_entry[1], $c_Abbrev, $c_name);
		#my %stv=qw(Structure Abbrev name)[$tt_entry[1], $c_Abbrev, $c_name];
		#my @stv=qw(Structure Abbrev name)[$tt_entry[1], $c_Abbrev, $c_name];

		#dump(\%stv);
		#exit;
		# advanced lookups.

		if ( 1 ) {
		    #my $c_t_e = {
		    #"t_line" => $t_line,
		    #};
		    # combine hash overwriting values using this example. My usage and setup here is rather complicated.
		    #my %t = %target;
		    #@t{keys %source} = values %source;
		    #@{$c_t_e}{(keys %entry_hash)} =values %entry_hash;
		    #delete($t_table->{$sub_tree}->{$stv{$sub_tree}}->{$sub_tree});

		    for my $sub_tree (keys %entry_hash) {
			$t_table->{$sub_tree}->{$entry_hash{$sub_tree}}=\%entry_hash;
		    }
		} else {
		    warn('DIRTY OLD CODE !!!!!!!');
		    my %stv;
		    #@stv{qw(Structure Abbrev Name Value c_R c_G c_B c_A )}=($tt_entry[1], $c_Abbrev, $c_name, $Value, $c_R, $c_G, $c_B, $c_A);
		    for my $sub_tree (keys %stv) {
			$t_table->{$sub_tree}->{$stv{$sub_tree}} = {
			    "Value" => $tt_entry[0], 
			    "c_R" => $tt_entry[2],
			    "c_G" => $tt_entry[3],
			    "c_B" => $tt_entry[4],
			    "c_A" => $tt_entry[5],
			};
			# combine hash overwriting values using this example. My usage and setup here is rather complicated.
			#my %t = %target;
			#@t{keys %source} = values %source;
			@{$t_table->{$sub_tree}->{$stv{$sub_tree}}}{(keys %stv)} =values %stv;
			delete($t_table->{$sub_tree}->{$stv{$sub_tree}}->{$sub_tree});
		    }
		}
	    }
	}
    }
    
    return $t_table;
}




1;
