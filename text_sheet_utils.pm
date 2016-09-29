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
    $line =~ s/[\r\n]//gx; # found some hanging \r's and some \n's. This'll fix those right up.
    chomp($line);
    #trim($line); #NO SUCH THING!
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
    my %out_header;
    @out_header{keys(%$h_hash)}=values(%$h_hash);
    foreach my $t_line (@text_lines) {
	$t_line_num++;# keep track of the color table line so we can reference it later.
	#if ($t_line_num>30) { next;} # this is a short curcuit for testing, to only do a few lines
	#if ( $t_line !~ /^#.*/ ) {# if not comment.
	if ( $t_line !~ /$line_format/ ) {# if not comment.
	    $t_line =~ s/[\r\n]//gx; # found some hanging \r's and some \n's. This'll fix those right up.
	    my @tt_entry=split($separator,$t_line);
	    if ( scalar(@tt_entry) != scalar(keys(%$h_hash)) ) {
		print("Bailing on bad entry with ($separator)\n");
		print("\t".scalar (@tt_entry)." != ".scalar(keys(%$h_hash))."(".join(":",@tt_entry).")\n");
		dump($h_hash);
		next;
	    }
	    # color table is form of,
	    # VALUE NAME RED GREEN BLUE ALPHA
	    
	    # the expected format of our colortable comes from the avizo name format of alex. 
	    # the names used in avizo were "_?abbreviation__(_?)fullterribly_long_structure_name"
	    # some names add additional instances of double underscore. its uncertain what that was about.
	    my %newbits;
	    if( not defined $splitter) {
		warn("No splitters found, using defacto one. This should just be omitted. ");
		#@newbits{qw(Abbrev Name)} =  $tt_entry[1] =~/^_?(.+?)(?:___?(.*))$/;
	    } else {
		# foreach splitter
		if (not defined($h_hash->{$splitter->{"Input"}[0]}) ){
		    dump(@tt_entry);
		    next;
		}
		my $in_index=$h_hash->{$splitter->{"Input"}[0]};
		$newbits{$splitter->{"Input"}[1]}=$tt_entry[$in_index];
		my $regex=$splitter->{"Regex"};
		my @field_keys=@{$splitter->{"Output"}};# get the count ofexpected elementes
		my $field_val=$tt_entry[$in_index] ;# for readablilty pulled this out.
		my @field_temp = $field_val  =~ /$regex/x;
		if ( scalar(@field_keys) != scalar(@field_temp) ) {
		    if ( 1 ) {
		    } else {
			# high verbosity.
			warn("entry seems incomplele or badly formed. The splitter didnt work.\n"
			     ."fields = ".join("  ",@field_keys)."\n"
			     ."expected fields=".(scalar(@field_keys))."  != found_fields".(scalar(@field_temp)).".\n"
			     ." ($t_line)");
		    }
		    # since we didnt find the requisite number of parts, just replicate the parts we did find the requisite number of times. 
		    while( ( $#field_temp<$#field_keys ) && ( length($field_val)>0) ) {
			push(@field_temp, $field_val);
		    }
		} else {
		    #print("fields = ".join("  ",@field_keys)."\n");
		}
		if ( scalar(@field_keys) == scalar(@field_temp) ) {
		    @newbits{@field_keys} = @field_temp;
		}
	    }
	    my %entry_hash;
	    @entry_hash{keys(%$h_hash)}=@tt_entry[values(%$h_hash)];
	    @entry_hash{keys(%newbits)}=values(%newbits);
	    $entry_hash{"t_line"} = $t_line_num;
	    for my $sub_tree (keys %entry_hash) {
		$t_table->{$sub_tree}->{$entry_hash{$sub_tree}}=\%entry_hash;
	    }
	}
    }
    $t_table->{"Header"}=\%out_header;
    return $t_table;
}





1;
