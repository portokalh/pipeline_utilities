#!/usr/bin/perl
use strict;
use warnings;
use Env qw(PIPELINE_SCRIPT_DIR);
# generic incldues
use Cwd qw(abs_path);
use File::Basename;
use lib dirname(abs_path($0));
use Env qw(RADISH_PERL_LIB WKS_SETTINGS);
use vars qw($PIPELINE_VERSION $PIPELINE_NAME $PIPELINE_DESC $HfResult $GOODEXIT $BADEXIT ); #$test_mode
if (  ! defined($BADEXIT) ) {
    $BADEXIT=1;
}
if (  ! defined($GOODEXIT) ) {
    $GOODEXIT=0;
}
if (! defined($RADISH_PERL_LIB)) {
    print STDERR "Cannot find good perl directories, quiting\n";
    exit $BADEXIT;
}

use lib split(':',$RADISH_PERL_LIB);

require pipeline_utilities ;
require Headfile;
require ssh_call;
use civm_simple_util qw(get_engine_hosts);

my $file_pat=".*\.nii.*";
my $lead_data_system="crete";#take this in via variable?
my @eng_hosts=get_engine_hosts($WKS_SETTINGS);
my $EC      =load_engine_deps();

#my ($local_input_dir, $local_work_dir, $local_result_dir, $result_headfile, $EC)=new_get_engine_dependencies('PU_TEST',());
while(!ssh_call::works($lead_data_system ) && $#eng_hosts>=0) {
    $lead_data_system=shift @eng_hosts;
    while( $lead_data_system eq $EC->get_value("engine") ){
	$lead_data_system=shift @eng_hosts;}
    print("Choice of lead data system was unavailable.\nChanging lead system to $lead_data_system.\n");
}

if (!ssh_call::works($lead_data_system) ) {
    print("No other data systems available, unable to update workstation_data\n");
    exit 1 ;
}

my $data_EC=load_engine_deps($lead_data_system);

my $remote_data_dir=$data_EC->get_value("engine_data_directory");
my $local_data_dir=$EC->get_value("engine_data_directory");

print("local engine from dep is ".$EC->get_value("engine")."\n");
print("remote engine from dep is ".$data_EC->get_value("engine")."\n");
print("Checking data directories\n".
$data_EC->get_value('engine_waxholm_canonical_images_dir')."\n".
    $data_EC->get_value('engine_waxholm_labels_dir')."\n");

my @list;
@list=ssh_call::get_dir_listing($data_EC->get_value('engine'),
				$data_EC->get_value('engine_waxholm_canonical_images_dir'),
				$file_pat);
if ( $data_EC->get_value('engine_waxholm_canonical_images_dir') ne $data_EC->get_value('engine_waxholm_labels_dir') ){
    push(@list,ssh_call::get_dir_listing($data_EC->get_value('engine'),
					 $data_EC->get_value('engine_waxholm_labels_dir'),
					 $file_pat)); }
if ( $#list < 0  ) {
    print("Dir empty:".
	  $data_EC->get_value('engine_waxholm_canonical_images_dir')." and ".
	  $data_EC->get_value('engine_waxholm_labels_dir').".\n"); }


my @dirs_to_check=ssh_call::get_dir_listing($data_EC->get_value('engine'),
					    $remote_data_dir."/atlas"." -type d",
					    "[^.]*");

for(my $fn=0;$fn<=$#dirs_to_check;$fn++){
    if ( $dirs_to_check[$fn] =~ /$data_EC->get_value(engine_waxholm_canonical_images_dir)|$data_EC->get_value(engine_waxholm_labels_dir)/ ) {
	print("found");
    }
}

print(join(" ",@dirs_to_check)."\n");
#print($#dirs_to_check."\n");
push(@dirs_to_check,@ARGV);
#engine_data_directory
while($#dirs_to_check>=0 ) { 
    my $t_dir=shift @dirs_to_check;
    print("Adding contents of dir $t_dir\n");
    my @filepaths=ssh_call::get_dir_listing($data_EC->get_value('engine'),$t_dir,$file_pat);
    
#     for(my $fn=0;$fn<=$#filepaths;$fn++){
# 	$filepaths[$fn]=$t_dir.'/'.$filepaths[$fn];
#     }
    push(@list,@filepaths);
}

if ( $#list < 0  ) {
    print("All dirs empty\n"); 
} else {
    print(join(" ",@list)."\n");
}
    

#}

my ( $in, $work,$res)=make_process_dirs("data_update");

#WKS_SETTINGS/engine_deps/";
for my $remote_data_file (@list ) {
   # strip remote path to relative path to engine_data_dir
    my ($rel_path)=  $remote_data_file =~ /$remote_data_dir(.*)$/x;
    
    my ($data_name,$p,$s)=fileparts($rel_path);
    my $rel_md5="$p$data_name.md5";

    #print("rel path $rel_path\n");
    #print("rel  md5 $rel_md5\n");

    # 
    # get md5 remote file
    #
    my $fp=$in.dirname($rel_md5);
    if ( ! -d $fp ) {
	#print("mkdir $fp\n");
	mkdir($fp,0777) or die("couldnt make dest folder $fp");
    }

    if ( -f $in.$rel_md5) { # rm file if it exists
	unlink $in.$rel_md5 or warn("Coudlnt remove last copy of md5 file.\n"); }
    my $skip_file=0;
#  get_file ($system, $source_dir, $file, $local_dest_dir);
    ssh_call::get_file($data_EC->get_value("engine"),$data_EC->get_value("engine_data_directory").$rel_md5,'',$fp,1) or $skip_file=1;
    

    if ( ! $skip_file) {
	my @remote_md5;
	load_file_to_array($in.$rel_md5,\@remote_md5);
	# integrity check local file if exist.
	my $integrity=data_integrity($local_data_dir.$rel_path);
	my @local_md5;
	if ( $integrity ) {
	    # in integrity same, check against remote.	
	    load_file_to_array($local_data_dir.$rel_md5,\@local_md5);
	    if ( $remote_md5[0] eq $local_md5[0]) {
	    #no work
		print("$local_data_dir$rel_path is same as remote.\n");
	    } else {
		# if different from remote, move to file.date.ext and file.date.md5, scp remote to local.
		#my $last_mod_time = (stat ($file))[9];
		my $last_mod_time = (stat ($local_data_dir.$rel_path))[9];
		#my $epoch_timestamp = (stat($fh))[9];
		print("Last mod was $last_mod_time\n");
		my ($l_p,$l_n,$l_e)=fileparts($local_data_dir.$rel_path);
		#rename($local_data_dir.$rel_path,$l_p.$last_mod_time.$l_e);
		#($l_p,$l_n,$l_e)=fileparts($local_data_dir.$rel_md5);
		#rename($local_data_dir.$rel_path,$l_p.$last_mod_time.$l_e);
		#ssh_call::get_file($data_EC->get_vlaau
	    }
	} else { 
	# if integrity change warning
	    warn("local file lost integrity.");
	}
	
	
	
	#$local_data_dir
	#my $exit_code=1;
	#if ( ! $exit_code ) {
	#print("Test, checksum of file $file\n");
    } else {
	warn("cannot data check $rel_path\n");
    }
    

}