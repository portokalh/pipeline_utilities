#!/usr/bin/perl
my $ERROR_EXIT = 1;
my $GOOD_EXIT  = 0;

use strict;
use warnings;
use English;
use Getopt::Std;
use File::Basename;
use File::Glob qw(:globally :nocase);
use Data::Dump qw(dump);


use Env qw(RADISH_PERL_LIB RADISH_RECON_DIR WORKSTATION_HOME WKS_SETTINGS RECON_HOSTNAME WORKSTATION_HOSTNAME); # root of radish pipeline folders
if (! defined($RADISH_PERL_LIB)) {
    print STDERR "Cannot find good perl directories, quiting\n";
    exit $ERROR_EXIT;
}
use text_sheet_utils;

if ( 0 )
{
my $test_line=sprintf("taco,libre\n");
my $h_hash=text_sheet_utils::text_header_parse($test_line);
#dump($h_hash);

$test_line=sprintf("taco\tlibre\n");
$h_hash=text_sheet_utils::text_header_parse($test_line);
dump($h_hash);

$test_line=sprintf("taco libre\n");
$h_hash=text_sheet_utils::text_header_parse($test_line);
dump($h_hash);


$test_line=sprintf("taco,libre\n");
$h_hash=text_sheet_utils::text_header_parse($test_line,",");
dump($h_hash);

$test_line=sprintf("taco\tlibre\n");
$h_hash=text_sheet_utils::text_header_parse($test_line,sprintf("\t"));
dump($h_hash);

$test_line=sprintf("taco libre\n");
$h_hash=text_sheet_utils::text_header_parse($test_line,' ');
dump($h_hash);


$test_line=sprintf("taco,libre\n");
$h_hash=text_sheet_utils::text_header_parse($test_line,sprintf("\t"));
dump($h_hash);

$test_line=sprintf("taco\tlibre\n");
$h_hash=text_sheet_utils::text_header_parse($test_line,sprintf("\t"));
dump($h_hash);

$test_line=sprintf("taco libre\n");
$h_hash=text_sheet_utils::text_header_parse($test_line,sprintf("\t"));
dump($h_hash);
}


# VALUE NAME RED GREEN BLUE ALPHA
my $header={};
#$header->{"Structure"}=-1;
#$header->{"Abbrev"}=-1;
$header->{"Value"}=0;
$header->{"Name"}=1;
$header->{"c_R"}=2;
$header->{"c_B"}=3;
$header->{"c_G"}=4;
$header->{"c_A"}=5;

my $splitter={};#
# a aplitter to split a field into alternat parts. 
#	my ($c_Abbrev,$c_name)= $tt_entry[1] =~/^_?(.+?)(?:___?(.*))$/;
### This splitter Regex is for the alex badea style color tables.
$splitter->{"Regex"}='^_?(.+?)(?:___?(.*))$';# taking this regex
#$splitter->{"Regex"}='^.*$';# taking this regex
$splitter->{"Input"}=[qw(Name Structure)];# reformulate this var, keeping original in other
$splitter->{"Output"}=[qw(Abbrev Name)];  # generating these two
#$header->{"t_line"}={};
#dump($splitter);
#exit;
#$header->{"Splitter"}=$splitter;
$header->{"LineFormat"}='^#.*';
$header->{"Separator"}=" ";
my $table_path="/Users/james/gitworkspaces/Slicer_DevSupportCode/ontology_convert_example_input/ex_data_and_xml/ex_color_table.txt";
#$table_path="/Volumes/l\$/Libraries/Brain/Rattus_norvegicus/Wistar/Developmental/00006912000/NewLabelset/Developmental_00006912000_RBSC_labels_lookup.txt";
my $data_file=text_sheet_utils::loader($table_path,$header);
#dump ($data_file);
#dump($data_file->{"Name"});
#dump($data_file->{"Structure"})
#dump($data_file->{"Abbrev"});;


my $csv_path="/Users/james/gitworkspaces/Slicer_DevSupportCode/ontology_convert_example_input/ex_hierarchy.csv";
$csv_path="/Volumes/l\$/Libraries/Brain/Rattus_norvegicus/Wistar/Developmental/00006912000/NewLabelset/rat_fullfield_labels_lookup5_cleanup_POSTcsv_renum.csv";
$splitter->{"Regex"}='^_?(.+?)(?:___?(.*))$';# taking this regex
#$splitter->{"Regex"}='^.*$';# taking this regex
$splitter->{"Input"}=[qw(Structure Structure)];# reformulate this var, keeping original in other
$splitter->{"Output"}=[qw(Abbrev Name)];  # generating these two

my $h_info={};
$h_info->{"Splitter"}=$splitter;
$header->{"LineFormat"}='^#.*';
#$header->{"Separator"}=" ";
my $csv_data_file=text_sheet_utils::loader($csv_path,$h_info);
#dump($csv_data_file->{"Name"});
dump($csv_data_file->{"Structure"})
#dump($csv_data_file->{"Abbrev"});;



