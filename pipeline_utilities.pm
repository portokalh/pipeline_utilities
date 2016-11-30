
#pipeline_utilites.pm
#
# utilities for pipelines including matlab calls from perl 
# should probably split up into separate library functions to make 
# the distinctions easier. 
# propose, a log_utilities, maybe a matlab_utilities, maybe an external call utilities
#
# created 09/10/15  Sally Gewalt CIVM
#                   based on t2w pipemline  
# 110308 slg open_log returns log path
# 130731 james, added new function new_get_engine_dependencies, to replace that chunk of code used all the damn time.
#               takes an output identifier, and an array of required values in the constants file to be checked. 
#               should add a standard headfile settings file for the required values in an engine_dependencie headfile 
#               returns the three directories  in work result, outhf_path, and the engine_constants headfile.
# 140717 added exporter line with list of functions
# be sure to change version:
my $VERSION = "140917";

my $log_open = 0;
my $pipeline_info_log_path = "UNSET";

my @outheadfile_comments = ();  # this added to by log_pipeline_info so define early
#my $BADEXIT = 1;
#my $debug_val = 5;
use File::Path;
use POSIX;
use strict;
use warnings;
use English;
use Carp;
#use seg_pipe;

#scrapped from xml reader slicer_read_xml thingy... 
#use lib ".";
#use PDL;
#use PDL::NiceSLice;
#use FindBin;
#use lib $FindBin::Bin;
#use XML::Parser;
#use LWP::Simple;
# xml rules moved to the xml functions in a require/import pair so when it doesnt exist, we dont fail here.
#use XML::Rules;


use vars qw($HfResult $BADEXIT $GOODEXIT $debug_val);
if ( ! defined $debug_val){
    $debug_val=5;
    
}
my $PM="pipeline_utilities";
use civm_simple_util qw(load_file_to_array write_array_to_file is_empty);
our $PIPELINE_INFO; #=0; # needstobe undef.#pipeline log fid. All kinds of possible trouble? should only be one log open at a time, but who knows how this'll work out.
my $custom_q = 0; # Default is to assume that the cluster queue is not specified.
my $my_queue = '';

$my_queue = $ENV{'PIPELINE_QUEUE'} or $my_queue= '';

if ((defined $ENV{'PIPELINE_QUEUE'}) && ($my_queue ne '') ) {
    $custom_q = 1;
}


BEGIN {
    use Exporter;
    our @ISA = qw(Exporter); # perl cricit wants this replaced with use base; not sure why yet.
    our @EXPORT_OK = qw(
open_log
close_log
log_info
close_log_on_error
error_out
make_matlab_m_file
make_matlab_m_file_quiet
make_matlab_command
make_matlab_command_nohf
get_matlab_fifo
start_fifo_program
stop_fifo_program
restart_fifo_program
isopen_fifo_program
get_image_suffix
matlab_fifo_cleanup
file_over_ttl
data_integrity
file_checksum
link_checksum
make_matlab_command_V2
rp_key_insert
make_matlab_command_V2_OBSOLETE
execute
execute_heart
execute_indep_forks
executeV2
start_pipe_script
load_engine_deps
load_deps
new_get_engine_dependencies
make_list_of_files
my_ls
writeTextFile
xml_read
mrml_find_by_id
mrml_find_by_name
mrml_attr_search
mrml_node_diff
remove_dot_suffix
depath_annot
depath
defile
fileparts
funct_obsolete

); 
}


# -------------
sub open_log {
# -------------
   my ($result_dir) = @_;
   print("open_log: $result_dir\n") if ($debug_val>=35);
   if (! -d $result_dir) {
       print ("no such dir for log: $result_dir");
       exit $BADEXIT;
   }
   if (! -w $result_dir) {  
       print("\n\ndir for log: $result_dir not writeable\n\n\n");
       exit $BADEXIT;
   }
   $pipeline_info_log_path = "$result_dir/pipeline_info_$PID.txt";
   open $PIPELINE_INFO, ">$pipeline_info_log_path" or die "Can't open pipeline_info file $pipeline_info_log_path, error $!\n";
   my $time = scalar localtime;
   print("# Logfile is: $pipeline_info_log_path\n");
   $log_open = 1;

   log_info(" Log opened at $time");
   return($pipeline_info_log_path);
}

# -------------
sub close_log {
# -------------
  my ($Hf) = @_;
  my $time = scalar localtime;
  if ($log_open) { 
    log_info("close at $time");
    close($PIPELINE_INFO);
    undef($PIPELINE_INFO);
  }
  else {
    print ("Close at $time");
  }
  $log_open = 0;
  if ( defined $Hf && $Hf != 0) {
  foreach my $comment (@outheadfile_comments) {
      $Hf->set_comment($comment);
      
  }
  }
  print "result logfile is: $pipeline_info_log_path\n";
}

# -------------
sub log_info {
# -------------
   my ($log_me) = @_;

   if ($log_open) {
     # also write this info to headfile later, so save it up
     my $to_headfile = "# PIPELINE: " . $log_me;
     push @outheadfile_comments, "$to_headfile";  

     # show to user:
     print( "#LOG: $log_me\n");

     # send to pipeline file:
     print( $PIPELINE_INFO "$log_me\n");
   }
   else {
    print(STDERR "LOG NOT OPEN!\n");
    print(STDERR  "  You tried to send this info to the log file, but the log file is not available:\n");
    print(STDERR  "  attempted log msg: $log_me\n");
   }
}


# -------------
sub close_log_on_error  {
# -------------
  my ($msg) = @_;
  # possible you may call this before the log is open
  if ($log_open) {
      my $exit_time = scalar localtime;
      log_info("Error cause: $msg");
      log_info("Log close at $exit_time.");

      # emergency close log (w/o log dumping to headfile)
      close($PIPELINE_INFO);
      $log_open = 0;
      print(STDERR "  Log is: $pipeline_info_log_path\n");
      return (1);
  } else {
      print(STDERR "NOTE: log file was not open at time of error.\n");
      return (0);     
  }
}

# -------------
sub error_out
# -------------
{
  my ($msg) = @_;
  print STDERR "\n<~Pipeline failed.\n";
  my @callstack=(caller(1));
  my $pm;
#  $pm=$callstack[1] || $pm="UNDEFINED"; #||die "caller failure in error_out for message $msg";
  $pm=$callstack[1] || die "caller failure in error_out with message: $msg";
  my $sn;
#  $sn=$callstack[3] || $sn="UNDEFINED";#||die "caller failure in error_out for message $msg";
  $sn=$callstack[3] || die "caller failure in error_out with message: $msg";
  print STDERR "  Failure cause: ".$pm.'|'.$sn." ".$msg."\n";
  print STDERR "  Please note the cause.\n";
  

  close_log_on_error($msg);
  my $hf_path='';
  if (defined $HfResult && $HfResult ne "unset") {
      $hf_path = $HfResult->get_value('headfile_dest_path');
      if($hf_path eq "NO_KEY"){ $hf_path = $HfResult->get_value('headfile-dest-path'); }
      if($hf_path eq "NO_KEY"){ $hf_path = $HfResult->get_value('result-headfile-path'); }
      #my ($n,$p,$e) = fileparts($hf_path);
      my ($p,$n,$e) = fileparts($hf_path,2);
      my $hf_path = $p.$n.'.err'.$e;
    $HfResult->write_headfile($hf_path);
    $HfResult = "unset";
  }
  exit $BADEXIT;
}

# -------------
sub make_matlab_m_file {
# -------------
#simple utility to save an mfile with a contents of function_call at mfile_path
# logs the information to the log file, and calls make_matlab_m_file_quiet to do work
   my ($mfile_path, $function_call) = @_;
   log_info("Matlab function call mfile created: $mfile_path");
   log_info("  mfile contains: $function_call");
   make_matlab_m_file_quiet($mfile_path,$function_call);
   return;
}

# -------------
sub make_matlab_m_file_quiet {
# -------------
#simple utility to save an mfile with a contents of function_call at mfile_path
   my ($mfile_path, $function_call) = @_;
   open MATLAB_M, ">$mfile_path" or die "Can't open mfile $mfile_path, error $!\n";
   # insert startup.m call here.
   use Env qw(WKS_SHARED);
   #print MATLAB_M 'fprintf([datestr(now, \'HH:MM:SS\'),\'\n\n\']);'."\n";
   print MATLAB_M 'fprintf(\'%s\n\n\',datestr(now, \'HH:MM:SS\'));'."\n";
   my ($fn) = $function_call =~ /^\s*([^ (]+).*$/x ;
   if ( defined $WKS_SHARED) { 
       if ( -e "$WKS_SHARED/pipeline_utilities/startup.m") 
       {
	   print MATLAB_M "run('$WKS_SHARED/pipeline_utilities/startup.m');\n";
       }
   }
   print MATLAB_M 'path=which(\''.$fn.'\');'."\n";
   print MATLAB_M 'fprintf(\'calling %s \n\',path);'."\n";
   print MATLAB_M "$function_call\;"."\n";
   print MATLAB_M 'fprintf(['."\'${mfile_path}_DONE\'".' \'\n\']);'."\n";
   close MATLAB_M;
   return;
}

# -------------
sub make_matlab_command {
# -------------
# this calls the nohf version so we can control how matlab is launched at all times through just that function.
   my ($function_m_name, $args, $short_unique_purpose, $Hf) = @_;
# short_unique_purpose is to make the name of the mfile produced unique over the pipeline (they all go to same dir) 
   my $work_dir   = $Hf->get_value('dir_work');
   if ( $work_dir eq "NO_KEY" ) { $work_dir=$Hf->get_value('dir-work'); }
   my $matlab_app  = $Hf->get_value('engine_app_matlab');
   my $matlab_opts = $Hf->get_value('engine_app_matlab_opts');
   if ($matlab_app  eq "NO_KEY" ) { $matlab_app  = $Hf->get_value('engine-app-matlab'); }
   if ($matlab_opts eq "NO_KEY" ) { $matlab_opts = $Hf->get_value('engine-app-matlab-opts'); }
   if ($matlab_opts eq "NO_KEY" ) { # app = $Hf->get_value('engine-app-matlab'); 
       print("Could not find matlab opts\n");
       $matlab_opts="";
   } 
   print("make_matlab_command:\n\tengine_matlab_path:${matlab_app}\n\twork_dir:$work_dir\n") if($debug_val>=25);
   
   my $mfile_path = "$work_dir/${short_unique_purpose}${function_m_name}.m";
   my $function_call = "$function_m_name ( $args )";
   #make_matlab_m_file ($mfile_path, $function_call); # this seems superfluous.


   my $logpath="$work_dir/matlab_${function_m_name}";


   #my $cmd_to_execute = "$matlab_app $matlab_opts < $mfile_path > $logpath";
   my $cmd_to_execute = make_matlab_command_nohf($function_m_name,$args,$short_unique_purpose,$work_dir,$matlab_app,$logpath,$matlab_opts);

   return ($cmd_to_execute);
}

# -------------
sub make_matlab_command_nohf {
# -------------
#  my $matlab_cmd=make_matlab_command_nohf($mfilename, $mat_args, $purpose, $local_dest_dir, $Engine_matlab_path);
   my ($function_m_name, $args, $short_unique_purpose, $work_dir, $matlab_app,$logpath,$matlab_opts) = @_;
   print("make_matlab_command:\n\tengine_matlab_path:${matlab_app}\n\twork_dir:$work_dir\n") if($debug_val>=25);
   my $mfile_path = "$work_dir/${short_unique_purpose}${function_m_name}".".m";
   my $function_call = "$function_m_name ( $args )";
   if (! defined $matlab_opts) { 
       $matlab_opts="";
   }
   if (! defined $logpath) { 
#       $logpath = '> /tmp/matlab_pipe_stuff';
#   } else {  
       $logpath='> '."$work_dir/matlab_${function_m_name}";
   }

   make_matlab_m_file ($mfile_path, $function_call); # this seems superfluous.
   #make_matlab_m_file_quiet ($mfile_path, $function_call); #### RECENTLY COMMENTED<-POSSIBLE UNNECESSARY EFFORT
   

  #my $cmd_to_execute = "$matlab_app < $mfile_path $logpath"; 
    
   my $cmd_to_execute = "$matlab_app $matlab_opts < $mfile_path > $logpath "; #; echo 'Matlab_Done' > $logpath 
   # we want to weave in our fifo support here, in doing that the returned command HAS 
   # to block until the current function finishes
   # To accomplish this we write a dynamic shell script that blocks until the logpath
   # prints a mfile_DONE
   # I THINK this breaks execute independent forks for matlab calls, however that shouldnt be terribly necessary any longer.

   #$PID
   ### temporaray cluster disable mode for now.
   my $fifo_mode=`hostname -s`=~ "civmcluster1" ? 0 : 1;
   if ( $fifo_mode ) { 
       my ($fifo_path,$fifo_log) = get_matlab_fifo($work_dir,$logpath);
       print STDERR ( "FIFO Log set to $fifo_log\n");
       my $fifo_start = start_fifo_program($matlab_app,$matlab_opts,$fifo_path,$fifo_log);
       $logpath=$fifo_log;
       my $n_closed = matlab_fifo_cleanup();
       print STDERR ( "FIFO cleanup closed $n_closed.\n");
       my $shell_file = "$work_dir/${short_unique_purpose}${function_m_name}"."_fifo_bash_wrapper.bash";
       #sed -e '1,/TERMINATE/d' # make a start line
       my @fifo_cmd_wrapper=();
       my $script_version="bash";
       if ( $script_version eq "bash" ) {
       push (@fifo_cmd_wrapper, "#!/bin/bash\n") ;
       push (@fifo_cmd_wrapper, "#THIS FILE IS AUTOGENERATED BY THE PIPELINE\n#ANY MODIFICATIONS WILL BE LOST\n#logpath is the path to our fifo log\n#donecode is the line of text we expect to find when complete\n#skey var is semi-unique identifier for log file so w can cleanly find info from this matlab call in log\n#line var is the next line to check\n#lastline var is the previous line checked\n"); # label our bash file
       push (@fifo_cmd_wrapper, "echo \"MATLAB_FIFO_PASS_STUB\"\n");
       push (@fifo_cmd_wrapper, "logpath=$logpath;\n");
       push (@fifo_cmd_wrapper, "donecode=${mfile_path}_DONE;\n");
       push (@fifo_cmd_wrapper, "echo \"stub::\${0##*/}\"  >> \$logpath\n");
       push (@fifo_cmd_wrapper, "skey=`head -c 10 /dev/urandom | base64 | tr -dc \"[:alnum:]\" | head -c64`\n");# get a uniqueish, psuedo-random identifier for the log file so we can get only data after we started this run.
       push (@fifo_cmd_wrapper, "lastline=\$skey;\n");
       push (@fifo_cmd_wrapper, "echo \"fprintf\(\'\%s\',\'\$skey\'\)\;\" >> $fifo_path\n") ;
       #push (@fifo_cmd_wrapper, "echo \"\$skey\"  >> \$logpath\n");
       push (@fifo_cmd_wrapper, "mat_done=`sed -e \"1,/\$skey/d\" \$logpath | grep -c \$donecode`;\n");#\$logpath
       push (@fifo_cmd_wrapper, "mat_err=`sed -e \"1,/\$skey/d\" \$logpath | grep -c \"Error\"`;\n");
       push (@fifo_cmd_wrapper, "echo \"\tWait for completion line:\$donecode in log \$logpath\"\n");
       push (@fifo_cmd_wrapper, "echo \"run\(\'$mfile_path\'\)\;\" >> $fifo_path\n") ;
       
       ### begin bash while
       push (@fifo_cmd_wrapper, "nl=0;#newline before print flag. to make printing prettier\n");
       push (@fifo_cmd_wrapper, "while [ \"\$mat_done\" -lt \"1\" -a \"\$mat_err\" -lt \"1\" ]; do \n");
       push (@fifo_cmd_wrapper, "    line=`awk \"/\$skey/{y=1;}y\" \$logpath | grep -A 1 -m 100 -F \"\$lastline\" `;\n");
       push (@fifo_cmd_wrapper, "    nmatches=`echo \"\$line\" | grep -c '\\-\\-' `;\n");
       push (@fifo_cmd_wrapper, "    if [ \$nmatches -ge 1 ]; then\n");
       push (@fifo_cmd_wrapper, "        for((n=\$nmatches;\$n>0;)); do \n");
       push (@fifo_cmd_wrapper, "            line=`echo \"\$line\" | awk '/\\-\\-/{y=1;next}y'` ;\n");
       push (@fifo_cmd_wrapper, "            n=`echo \"\$line\" | grep -c '\\-\\-' `;\n");
       push (@fifo_cmd_wrapper, "        done;\n");
       push (@fifo_cmd_wrapper, "    fi;\n");
       push (@fifo_cmd_wrapper, "    declare -i lc;\n");
       push (@fifo_cmd_wrapper, "    lc=`echo \"\$line\" | wc -l`;\n");
       push (@fifo_cmd_wrapper, "    lc=\$lc-1;\n");
       push (@fifo_cmd_wrapper, "    line=`echo \"\$line\" | tail -n \$lc`;\n");
       #push (@fifo_cmd_wrapper, "    sleep .05;\n");

       push (@fifo_cmd_wrapper, "    if [ \"\$line\" != \"\$lastline\" ] \n");
       push (@fifo_cmd_wrapper, "    then\n");
       push (@fifo_cmd_wrapper, "        if [ ! -z \"\$line\" ]; then \n");
       push (@fifo_cmd_wrapper, "            if [ \$nl -eq 1 ]; then \n");
       push (@fifo_cmd_wrapper, "                echo \"\";\n");
       push (@fifo_cmd_wrapper, "            fi;\n"); 
       push (@fifo_cmd_wrapper, "            echo \"\$line\" | awk '{print \"\tMATLAB:\"\$0;}' || echo -n \"\";\n");
       push (@fifo_cmd_wrapper, "            nl=0; \n");
       push (@fifo_cmd_wrapper, "            declare -i inc=1;\n");
       push (@fifo_cmd_wrapper, "            lastline=`echo \"\$line\" |tail -n \$inc|head -n1 `;\n");
       push (@fifo_cmd_wrapper, "            while [ -z \"\$lastline\" ]; do\n");
       push (@fifo_cmd_wrapper, "                inc=\$inc+1;\n");
       push (@fifo_cmd_wrapper, "                lastline=`echo \"\$line\" |tail -n \$inc|head -n1 `;\n");
       push (@fifo_cmd_wrapper, "                echo -n \"\\\\\";\n");
       push (@fifo_cmd_wrapper, "                nl=1; \n");
       push (@fifo_cmd_wrapper, "            done;\n");
       push (@fifo_cmd_wrapper, "        else \n");
       push (@fifo_cmd_wrapper, "            echo -n \".\";\n");
       push (@fifo_cmd_wrapper, "            nl=1; \n");
       push (@fifo_cmd_wrapper, "            sleep 0.5;\n");
       push (@fifo_cmd_wrapper, "        fi;\n");
       push (@fifo_cmd_wrapper, "    else \n");
       push (@fifo_cmd_wrapper, "        nl=1; \n");
       push (@fifo_cmd_wrapper, "        echo -n \".\";\n");
       push (@fifo_cmd_wrapper, "        sleep 0.5;\n");
       push (@fifo_cmd_wrapper, "    fi\n");
       push (@fifo_cmd_wrapper, "    mat_done=`sed -e \"1,/\$skey/d\" \$logpath | grep -c \$donecode`;\n");#\$logpath
       #push (@fifo_cmd_wrapper, "    mat_done=`echo \$line | grep -c \$donecode `;\n");
       push (@fifo_cmd_wrapper, "    mat_err=`sed -e \"1,/\$skey/d\" \$logpath | grep -c \"Error\"`;\n");

       push (@fifo_cmd_wrapper, "done;\n");
       #### end bash while
       push (@fifo_cmd_wrapper, "if [ \"\$mat_err\" -ge \"1\" ]; then\n");
       push (@fifo_cmd_wrapper, "    echo \"MATLAB_ERRORS:\$mat_err\";\n");
       push (@fifo_cmd_wrapper, "    sed -e \"1,/\$skey/d\" \$logpath |grep -m 1 \"Error\";\n");#$logpath
       push (@fifo_cmd_wrapper, "fi;\n");
       } elsif ($script_version eq "perl" ) {
	   die "DO NOT USE PERL VERSION< IT NEEDS TO BE UPDATED FROM BASH VERSION\n";
	   push (@fifo_cmd_wrapper, "#!/usr/bin/perl\n") ;
	   push (@fifo_cmd_wrapper, "print(\"MATLAB_FIFO_PASS_STUB\\n\n\");\n");
	   push (@fifo_cmd_wrapper, "my \$LOGHDL;\n");
	   push (@fifo_cmd_wrapper, "open (\$LOGHDL, '>>', 'log.txt');");
	   push (@fifo_cmd_wrapper, "my \$logpath=$logpath;\n");
	   push (@fifo_cmd_wrapper, "print \$LOGHDL, (\"stub::\${0##*/}\")  >> \$logpath\n");
	   push (@fifo_cmd_wrapper, "#skey var is semi-unique identifier for log file so w can cleanly find info from this matlab call in log\n#line var is the next line to check\n#lastline var is the previous line checked\n#logpath is the path to our fifo log\n"); # label our bash file
	   push (@fifo_cmd_wrapper, "skey=`head -c 10 /dev/urandom | base64 | tr -dc \"[:alnum:]\" | head -c64`\n");# get a uniqueish, psuedo-random identifier for the log file so we can get only data after we started this run.
	   push (@fifo_cmd_wrapper, "lastline=\$skey;\n");
	   push (@fifo_cmd_wrapper, "echo \"\$skey\"  >> \$logpath\n");
	   push (@fifo_cmd_wrapper, "mat_done=`sed -e \"1,/\$skey/d\" \$logpath | grep -c ${mfile_path}_DONE`;\n");#\$logpath
	   push (@fifo_cmd_wrapper, "mat_err=`sed -e \"1,/\$skey/d\" \$logpath | grep -c \"Error\"`;\n");
	   push (@fifo_cmd_wrapper, "echo \"\tWait for completion line:${mfile_path}_DONE in log \$logpath\"\n");
	   push (@fifo_cmd_wrapper, "echo \"run\(\'$mfile_path\'\)\;\" >> $fifo_path\n") ;

	   
	   ### begin bash while
	   push (@fifo_cmd_wrapper, "while [ \"\$mat_done\" -lt \"1\" -a \"\$mat_err\" -lt \"1\" ]\n");
	   push (@fifo_cmd_wrapper, "do \n");
	   push (@fifo_cmd_wrapper, "\tif [ ! -z \"\$line\" ]; then \n\t" ); # sed returns a blank on no match, so we need to account for that properly. 
	   push (@fifo_cmd_wrapper, "\tlastline=\$line;\n");
	   push (@fifo_cmd_wrapper, "\tfi;\n");
	   push (@fifo_cmd_wrapper, "\tline=`sed -e \"1,/\\\"\$lastline\\\"/d\" \$logpath`;\n");
	   #push (@fifo_cmd_wrapper, "\tif [ -z \"\$line\" ]; then line=BLANK; echo \"last line err on \$lastline\"; echo endlerr;\n fi;\n");
	   #push (@fifo_cmd_wrapper, "\tif [ \"\$line\" != \"\$lastline\" -a \"\$lastline\" != \"BLANK\" ] \n");
	   push (@fifo_cmd_wrapper, "\tif [ \"\$line\" != \"\$lastline\" -a ! -z \"\$line\"  ] \n");
	   push (@fifo_cmd_wrapper, "\tthen\n");
	   push (@fifo_cmd_wrapper, "\t\techo \"\tMATLAB:\$line\";\n");
	   push (@fifo_cmd_wrapper, "\tfi\n");
	   push (@fifo_cmd_wrapper, "\tmat_done=`sed -e \"1,/\$skey/d\" \$logpath | grep -c ${mfile_path}_DONE`;\n");
	   push (@fifo_cmd_wrapper, "\tmat_err=`sed -e \"1,/\$skey/d\" \$logpath | grep -c \"Error\"`;\n");
	   push (@fifo_cmd_wrapper, "\tsleep 1\n"); #sleep at least 0.1 seconds per iteration of loop so loop doesnt demand too much cpu

	   push (@fifo_cmd_wrapper, "done;\n");
	   #### end bash while
	   push (@fifo_cmd_wrapper, "if [ \"\$mat_err\" -ge \"1\" ];\n");
	   push (@fifo_cmd_wrapper, "then\n");
	   push (@fifo_cmd_wrapper, "\techo \"MATLAB_ERRORS:\$mat_err\";\n");
	   push (@fifo_cmd_wrapper, "\tsed -e \"1,/\$skey/d\" \$logpath |grep -m 1 \"Error\";\n");#$logpath
	   push (@fifo_cmd_wrapper, "fi;\n");
	   
	   
       

       }
       write_array_to_file($shell_file,\@fifo_cmd_wrapper);
       chmod( 0755, $shell_file );
       #$cmd_to_execute=("bash","-c","$shell_file");
       $cmd_to_execute="bash -c $shell_file"
#       exit(0);
   } else {
       print STDERR ("FIFO Not enabled\n");
   }
   return ($cmd_to_execute);
}
# -------------
sub get_matlab_fifo {
# -------------
# calculates the name and path a fifo should use,
# checks against a registry of fifo names in the /matlab_fifo dir in worstation_home
# We do this to better allow fifo sharing on non fifo optimized pipeline processes
# if that fifo name is registered it gets the path from there instead of using the
# calculated path. 
# If the fito name is registered this function registers it and then returns the path
    my ( $work_dir,$logpath ) = @_;
    use Env qw(WORKSTATION_HOME WORKSTATION_HOSTNAME FIFO_NAME);
    my $fifo_registry=$WORKSTATION_HOME."/../matlab_fifos/";
    my $fifo_dir=$work_dir."";
    if ( $fifo_dir !~ m/^.*[\/]$/x ) {
	#print STDERR ("FIFO Dir check added a slash\n");
	$fifo_dir=$fifo_dir."/";
    } else {
	#print STDERR ("FIFO Dir check found trailing slash\n");
    }
###
#   get FIFO_NAME
###
    if (! defined($FIFO_NAME)) {
	my ($path,$name,$suffix);
	my @w_p;

	    @w_p=split('/',$work_dir);
	    do {
		my $temp=pop @w_p;
		if ( $temp ne '' ) {
		    $name=$temp;
		} else {
		    print STDERR ("FIFO_NAME: Skipped assigning <$temp> to name\n");
		}
		#print STDERR ("name:$name\n");
	    } while( ($name !~ m/^.*\work/x ) && $#w_p>0);
	    ($name,$suffix)=split('\.',$name);

#	print STDERR ("name:$name");
#	print STDERR (":$suffix\n");
	
	my $runno_regex="[A-Z][0-9]{5,}[^-]*"; 
	# match Letter followed by at least 5 digits followed by anything
	
	my $multi_suffix="_m[0-9]+.*";
	# match _m followed by at least 1 digit followed by anything
	# if name matches an _m runno use the base runno for name
	if ( $name =~ m/${runno_regex}${multi_suffix}/x ) {
	    $name =~ m/^(.*)(${runno_regex}${multi_suffix})(.*)$/x ;
	    ($FIFO_NAME,@w_p)=split("_",$2);
	}
	# if name matches a standard runno use it as name
	elsif ( $name =~ m/$runno_regex/x ) {
	    $name =~ m/^(.*)($runno_regex)(.*)$/x;
	    $FIFO_NAME=$2;
	} else { 
	    $FIFO_NAME=$name;
	    #$fifo_dir=$WORKSTATION_HOME."/../matlab_fifos/";
	}
#	print STDERR ("name:$name");
#	print STDERR (":$suffix\n");
	if ($FIFO_NAME ne '' ) {
	    $FIFO_NAME=$FIFO_NAME."_fifo";
	    print STDERR ("FIFO_NAME: undefined. NOW defined using work_dir singular default <$FIFO_NAME>\n");
	} else { 
	    print STDERR ("FIFO_NAME: undefined, and <$work_dir> failed to generate a new one\n");
	}

    } else { 
	print STDERR ("FIFO_NAME: Found! $FIFO_NAME\n");
	#$fifo_dir=$WORKSTATION_HOME."/../matlab_fifos/";
    }
    if ( $FIFO_NAME eq "") {
	print STDERR ("Adding stuff to fifo name\n");
	$FIFO_NAME="matlab".$WORKSTATION_HOSTNAME."_fifo";
	$fifo_dir=$WORKSTATION_HOME."/../matlab_fifos/";
    }
###
#   See that FIFO is REGISTERED or get FIFO from registry
###
    #my $name=
    my $matlab_fifo=$fifo_dir.$FIFO_NAME;
    my $fifo_log;#=$logpath;
    if ( ! defined ($fifo_log) ) { 
	$fifo_log=$matlab_fifo.".log";    
    }
    my @fifo_reg_path;
    my $lines=0;
    if ( -e $fifo_registry.$FIFO_NAME && ! -p $fifo_registry.$FIFO_NAME ) { 
	$lines=load_file_to_array($fifo_registry.$FIFO_NAME,\@fifo_reg_path);
	chomp(@fifo_reg_path);
    } elsif ( -p $fifo_registry.$FIFO_NAME ) {
	# should check for a running matlab and pass it an exit, and then unlink.
	print STDERR "Warning: FIFO in registry, but registry is a fifo. Unlinked before proceding.\n";
	unlink $fifo_registry.$FIFO_NAME;
    }
    if ( $lines ) { 
	#print STDERR "Get_matlab_fifo fifo load location true\n";
	$matlab_fifo=$fifo_reg_path[0]; # get first line of the reg file and put return that instead of the calculated file.
	$fifo_log=$fifo_reg_path[1];
    } else { 
	#print STDERR "Get_matlab_fifo fifo load location false\n";
	push(@fifo_reg_path,$matlab_fifo."\n");
	push(@fifo_reg_path,$fifo_log."\n");
	write_array_to_file($fifo_registry.$FIFO_NAME,\@fifo_reg_path);
    }
    print("get_matlab_fifo:<~$matlab_fifo\n");
    return $matlab_fifo,$fifo_log;

}
# -------------
sub start_fifo_program {
# -------------
# created to run a copy of matlab all the time and pass it commands via fifo special file
# some portions are matlab explicit, (the usage options mostly,) and therfore could use work.    
    my ($app,$opts,$stdin_fifo,$logpath) = @_;
    my $retval=0;
    if ( ! -p $stdin_fifo ) {
	print STDERR ("FIFO not found at $stdin_fifo, creating. \n");
	my $cmd="mkfifo $stdin_fifo";
	execute(1,'FIFO_create',$cmd);
    } else {
	$retval=isopen_fifo_program($app,$opts,$stdin_fifo,$logpath);
	#print STDERR ( "RET from is open is <$retval>\n");
	my $cmd="touch -m $stdin_fifo";
	execute(1,'FIFO_reset_ttl',$cmd);
    }
    #my $logpath=$stdin_fifo.".log";
    if ( ! -e $logpath ) {
	my $cmd="touch $logpath";
	execute(1,'FIFO_Log_create',$cmd);
    }
    if ( ( -e $stdin_fifo && -e $logpath  ) && $retval==0  ) {
	print STDERR ("FIFO starting attached to $stdin_fifo\n");
        #my $cmd="( $app $opts -logfile $logpath <> $stdin_fifo 2>&1 >> $logpath ) 2>&1 > /dev/null & ";
	# should not double into logpath here because -logfile does nearly the same thing as >> $logpath
	my $cmd="( $app $opts -logfile $logpath <> $stdin_fifo 2>&1 > /dev/null ) 2>&1 > /dev/null & ";
	#system(1,"$cmd");
	#my $PID_CHECK;
	if (! defined( my $PID_CHECK=fork) ) { #fork fail
	    print STDERR ("ERROR: could not start fifo progrm $cmd\n");
	} elsif ( $PID_CHECK == 0 ) { # child process
	    close STDIN;
	    close STDERR;
	    close STDOUT;
	    #setsid or die "Cant start new session : $!";
	    #NAUGHTY NAUGHTY!
	    #umask(0027); 
	    chdir '/' or die "fifo start couldnt chdir to / : $!";
	    open STDIN, '<', '/dev/null' or die $!; 
	    open STDERR, '>', '/dev/null' or die $!; 
	    open STDOUT, '>>', $logpath or die $!; 
	    my $fifo_parent;
	    defined ( $fifo_parent = fork ) or die "Failed to start fifo program: $!\n";
	    if ( $fifo_parent) { # childs fork which we exit right away.
		exit(0);
	    } else { # child's child, which turns itself into our fifo command
		exec($cmd);
		exit;
	    }
	} else { #parent process
	    print STDERR ("FIFO forked off as background daemon with $cmd\n");
	}
	#my $retval=execute(1,'',$cmd);
    } else {
	print STDERR ("FIFO program running\n");
    }
    return $retval;
}
# -------------
sub stop_fifo_program {
# -------------
    my ( $app,$stdin_fifo,$logpath) = @_;


#    pids=`ps -ax | grep -i matlab | grep fifo |awk '{print $1}'`;
#    if [ "X_$pids" != "X_" ]; 
#    then
#	kill $pids
#    fi
#    # alt call
#    # kill `ps -ax | grep -i matlab | grep fifo | cut -d ' ' -f1`
#    rm /Volumes/workstation_home/matlab_fifos/*fifo*
    print STDERR ("FIFO_Stop: $stdin_fifo -> $logpath ...\n");
    my $oldway=0;
    my $file_path;
    my $stopped=-1;
    if ( $oldway){
	# find app that is running, by logpath, these should all show up in a ps call.
	my $cmd="fuser $logpath 2>&1"; # Get the PID's of processes looking at the logpath. Put stderr to stdout.
        # This has some issus with network mounts.
	#    may work as a way to find the process attached to a given log, which should work well.
	
	#print STDERR ($cmd."\n" );
	my $o_string = `$cmd `;
	chomp($o_string);
	#print STDERR ( "\tfuser_string:$o_string\n");
	my @out=split("\n",$o_string);
	chomp(@out);
	@out=split(':',$out[0]);
	#print STDERR ("\tfuser_out = ".join(',', @out)."\n");
	
	$file_path=shift(@out);
	@out = split(' ',$out[0]);

	print STDERR ("\twatched_file = $file_path\n");
	# <= BUG ?
	for (my $on=0;$on<$#out;$on++){ 
	    if ($out[$on]!~ m/[0-9]+/x ) {
		shift(@out);
		$on--;
	    }
	}
	if ($#out>=0 && $file_path eq "$logpath") {
	    print STDERR ("PID's to kill.\n\t".join("\n\t",@out)."\n");
	    if ( $#out>0 ) {
		print STDERR ( "WARNING: More than one process attached to the watched file!\n NOTIFY JAMES \n");
	    }
	    $stopped=kill 'KILL',@out;
	} else {
	    print STDERR ("No process open for $logpath or fuser fail.\n");
	    $stopped=0;
	}
    }else{
	my $cmd="fuser $logpath 2> /dev/null"; # Get the PID's of processes looking at the logpath. Put stderr to stdout.
	my $o_string = `$cmd `;
	chomp($o_string);
	# o_string should now be the pid.
	print STDERR ("PID's to kill.\n\t".join("\n\t",$o_string)."\n");
	$stopped=kill 'KILL',$o_string;

    }

    return $stopped;
}
# -------------
sub restart_fifo_program {
# -------------
    my ( $app,$opts,$stdin_fifo,$logpath) = @_;
    if (  ! stop_fifo_program($app,$stdin_fifo,$logpath) ){
	print("error stopping program $app attached to $stdin_fifo.\n");
    } elsif ( ! start_fifo_program($app,$opts,$stdin_fifo,$logpath) ){
	print("error starting program $app with opts $opts, attached to $stdin_fifo\n\tMaybe the permissions on $stdin_fifo or $logpath are incorrect?");
    } else {
	# fifo restart successfully.
    }
    return 0;
}
# -------------
sub isopen_fifo_program {
# -------------
    my ( $app,$opts,$stdin_fifo,$logpath) = @_;
    my $is_running=0;
    my $shell_method=1;
    if ( ! $shell_method ) {
	# "correct" code to check process table
# 	use Proc::ProcessTable;
# 	my $t = Proc::ProcessTable->new;
# 	$is_running = grep { $_->{cmndline} =~ /^dtllst $myNode/ } @{$t->table};
    } else { 
	my @app_p = split(' ', $app) ;
	$app=$app_p[0];
	#print STDERR ( "$app\n");
	@app_p = split('/',$app);
	$app=$app_p[$#app_p];
	#print STDERR ( "$app\n");

	my $cmd="ps -ax ";
	#$cmd = $opts eq "" ? $cmd : "$cmd | grep \'$opts\' ";
	$cmd = $stdin_fifo  eq "" ? $cmd : "$cmd | grep \'$stdin_fifo\' ";
	#$cmd = $logpath  eq "" ? $cmd : "$cmd | grep \'$logpath\' ";
	my $cmd2 = "$cmd | grep -i \'$app\' ";
	$cmd = "$cmd | grep -ci \'$app\' ";
	#print STDERR ("$cmd\n");
	my $out=`$cmd`;
	#`$cmd`;
	if ( $out>=2 ) { 
	    $is_running=1; } 
	#my $check_text=`$cmd2`;
	#print STDERR (" fifo check grep_ret:$! output:$out check_status:$is_running\ncheck_output:$check_text\n");
	
    }
    
    return $is_running;
}

# -------------
sub get_image_suffix {
# -------------
    my ($runno_headfile_dir,$runno)=@_;
    my ($ok,$img_suffix);
    my @err_buffer;
    printd(15,"get_image_suffix dirty function Please notify james if you see this.\n "); 
    my @files = glob("$runno_headfile_dir/${runno}*.*.*"); # lists all files named $runnosomething.something.something. This should match any civm formated images, and only their images.
    #@first_imgs=grep(/$runno${tc}imx[.][0]+[1]?[.]raw/, @imgs);
    my @first_files=grep (/^$runno_headfile_dir\/$runno.*[sim|imx][.][0]+[1]?[.].*$/x, @files ) ;
    #print("\n\n".join(' ',@first_files)."\n\n\n");
    if( $#first_files>0 ) {
	print STDERR "found files \n-> ".join ("\n-> ",@files)."\n";
	print STDERR "WARNING: \n";
	print STDERR "\tToo many first files found in archiveme\n";
	print STDERR "\tdid you forget to remove your rolled or resampled images?\n";
	print STDERR "Continuing anyway WHeeeeeeEEEEeeee!\n";
    } elsif ($#first_files < 0) {
	@first_files = glob("$runno_headfile_dir.*[sim|imx]\.[0]+1\..*");
	if( $#first_files!=0 ) {
	    push (@err_buffer, "\tERROR: $runno Did not find image files\n");
	    $ok =0;
	}
    }
    my ($file_vol,$file_path,$firstfile) =
	File::Spec->splitpath( $first_files[0] );
    my @parts=split('[.]',$firstfile);
    #print("\n\n".join(' ',@parts)."\n\n\n");
    # <= BUG ?
    for (my $iter=0;$iter<3 ;$iter++) {
	$img_suffix = pop @parts;
    }
    if ( length($img_suffix) >= 5 ){
	$img_suffix=substr($img_suffix,-5,2);
    } else {
	$ok=1;
    }
    return $ok,$img_suffix,@err_buffer;
}
# -------------
sub matlab_fifo_cleanup {
# -------------
    use Env qw(WORKSTATION_HOME WORKSTATION_HOSTNAME FIFO_TTL);
    # fifo time to live in minutes, default here is 30 minutes

    if (! defined($FIFO_TTL)) {
	$FIFO_TTL=30;
    }

#    my $fifo_log;
    my $fifo_registry=$WORKSTATION_HOME."/../matlab_fifos/";
    my $n_removed=0;
    if ( ! -d $fifo_registry ) { 
	print STDERR ("SETUP NOT COMPLETE FOR FIFO MODE\n NOTIFY JAMES!\n");
	exit();
    } else { 
	print STDERR "FIFO Cleanup Running on dir, $fifo_registry\n";
	my @fifo_registry_contents = <$fifo_registry/*>; # GLOB SUBSTITUE?
	# <= BUG ?
	for (my $fnum=0;$fnum<$#fifo_registry_contents;$fnum++) {
	    my $FIFO_regfile =$fifo_registry_contents[$fnum];
	    if ( $FIFO_regfile =~ m/^.*_fifo$/x ) {
		my @fifo_reg_path;
		my $lines=0;
		my $stdin_fifo;
		if ( -e $FIFO_regfile && ! -p $FIFO_regfile ) { 
		    $lines=load_file_to_array($FIFO_regfile,\@fifo_reg_path);
		    chomp(@fifo_reg_path);
		} elsif ( -p $FIFO_regfile ) {
		    # should check for a running matlab and pass it an exit, and then unlink.
		    print STDERR "Warning: FIFO in registry, but registry is a fifo. Unlinked before proceding.\n";
		    unlink $FIFO_regfile;
		}

		if ( $lines ) { 
		    #print STDERR "Get_matlab_fifo fifo load location true\n";
		    $stdin_fifo=$fifo_reg_path[0]; # get first line of the reg file and put return that instead of the calculated file.
		} else { 
		    print STDERR "Get_matlab_fifo fifo load location false\n";
		    #push(@fifo_reg_path,$stdin_fifo."\n");
		    #write_array_to_file($FIFO_regfile,\@fifo_reg_path);
		}
		
		if ( defined( $stdin_fifo) && ! -e $stdin_fifo ){ 
		    # this will occur when a new fifo is checked before its created.
		    print STDERR ("FIFO registered in $FIFO_regfile -> $stdin_fifo but the fifo doens't exit\n");
		    my $FIFO_reg_ttl=(($FIFO_TTL / 2 ) * 60 );
		    if ( file_over_ttl($FIFO_regfile, $FIFO_reg_ttl) ) {
			print STDERR ("\tUnlinking old reg file $FIFO_regfile\n");
			unlink $FIFO_regfile;
		    }
		    
		} elsif ( ! defined ($stdin_fifo) ){ 
		    print STDERR ("");
		} elsif( -e $stdin_fifo ) { 
		    ### peel off for function
		    #if( file_over_ttl($file,$ttl) )
		    
#     my $file_timestamp=0;
#     $file_timestamp = (stat($stdin_fifo))[9];
#     if ( "<$file_timestamp>" eq "<>" ) { 
# 	#print STDERR ( $stdin_fifo." FAILED TO GET TIMESTAMP< using method 1, trying method2\n");
# 	$file_timestamp= stat($stdin_fifo)->mtime;
# 		    }
#     #my $difference     = $^T - $file_timestamp;
#     my $difference     = time - $file_timestamp;
#     if ( "<$file_timestamp>" eq "<>" ) {
# 	$difference = 0 ;
# 	print STDERR ( $stdin_fifo." FAILED TO GET TIMESTAMP< ALLOWING TO STAY ALIVE\n");
#     }
#     my @n_p=split('/',$stdin_fifo);
#     my $n=$n_p[-1] unless $#n_p<0;
#     print STDERR ("\t$n, Epoc timestamp(s):$file_timestamp Current age(s):$difference, ");

		    if ( file_over_ttl($stdin_fifo,$FIFO_TTL * 60 ) ) { 
			print STDERR ( " >= ". $FIFO_TTL * 60 ." (max age) cleaning...\n");
			my $fifo_log=$stdin_fifo.".log";    
			my $stop_status=-1;
			if ( -e $fifo_log ){
			    $stop_status=stop_fifo_program('matlab',$stdin_fifo,$fifo_log) ;
			} else { 
			    $stop_status=0;
			}
			if ( $stop_status >=0) { 
			    #unlink $fifo_log;
			    unlink $stdin_fifo; #the actual fifo to remove ( so long as its not opened by anyone)
			    unlink $FIFO_regfile;  #the registry of the fifo to remove
			    $n_removed++;
			} else { 
			    print STDERR ( "WARNING: Stop failed for fifo $stdin_fifo at reg $FIFO_regfile\n");
			}
		    } else {
			print STDERR ( " < ". $FIFO_TTL * 60 ." (max age).\n");
		    }
		}
	    }
	    
	}
    }
    
    return $n_removed;
}
# -------------
sub file_over_ttl { # ( $path,$ttl )
# -------------
# checks if a file is older than the time to live value passed.
# path is file to look at
# ttl is in seconds old
# returns boolean true if old file
    my ($path,$ttl) = @_;
    my $isold=0;
    use File::stat;
#    use Time::localtime;
#    my $timestamp = ctime(stat($fh)->mtime);
#    my $epoch_timestamp = (stat($fh))[9];
#    my $timestamp       = localtime($epoch_timestamp)

    my $file_timestamp=0;
    $file_timestamp = (stat($path))[9];
    if (  !defined $file_timestamp ) {
    #if ( "$file_timestamp" eq "" ) { 
	#print STDERR ( $path." FAILED TO GET TIMESTAMP< using method 1, trying method2\n");
	$file_timestamp= stat($path)->mtime;
    }
    #my $difference     = $^T - $file_timestamp;
    my $difference     = time - $file_timestamp;
    if ( "<$file_timestamp>" eq "<>" ) {
	$difference = 0 ;
	print STDERR ( $path." FAILED TO GET TIMESTAMP.\n");
    }
    my @n_p=split('/',$path);
    my $n=$n_p[-1] unless $#n_p<0;
    print STDERR ("\t$n, Epoc timestamp(s):$file_timestamp Current age(s):$difference, ");
    if ( $difference >= ( $ttl ) ) { 
	$isold=1;
    }
    return $isold;
}


# add three related data integrity functions
# data_check, a boolean returning function
# checksum_calc, to calculate checksum and store in array
 
# -------------
sub data_integrity {
# -------------
# calc checksum of file, and if file.md5 exists load and compare, else save file.md5.

    my ($file,$ver) = @_;
    if( ! defined $ver){
	$ver=1;
    }
    my $data_check=0;

    #my ($n,$p,$ext) = fileparts($file);
    my ($p,$n,$e) = fileparts($file,3);
    my $checksumfile=$p.$n.$e.".md5"; #new format, accepting the inelegant file names.
    my $o_checksumfile=$p.$n.".md5";  #previous checksum format where we dropped the file extension.

    # TODO CHECK FOR NEW FILE AND OLD FILE< IF OLD EXISTS< MOVE IT TO NEW THEN PROCEEDE!
    if ( -f $o_checksumfile && ! -f $checksumfile ) {
	rename($o_checksumfile, $checksumfile) ;
    } elsif (  -f $o_checksumfile && -f $checksumfile && length($e)!=0 ) {
	warn("both checksum file name conventions present, an error may have occured. $o_checksumfile, and $checksumfile present!");
    }
    my $md5 ;
    
    if (! -l $file ) {
	$md5=file_checksum($file);
    } else {
	$md5=link_checksum($file);
    }
    my $stored_md5;
    my @f_cont;#  beacuse my function reads into and array, this'll have to be an array.
    if ( ! -e $checksumfile ) { 
	write_array_to_file($checksumfile,[$md5]);# becasue the function writes an array, we have to make our value an array here.
	$data_check=1;
    } else {
	load_file_to_array($checksumfile,\@f_cont);
	$stored_md5=$f_cont[0];
	if ( $stored_md5 eq $md5 ) { 
	    $data_check=1;
	    #print("GOOD! ($file:$md5)\n");
	} else {
	    print ("BADCHECKSUM! $md5($file) NOT $stored_md5") ;
	}
    }
    
    # If we failed our data check
    if ( ! $data_check ){
	if ($ver == 1) {
	    funct_obsolete("data_integrity","data_integrity(\$file,2). this is the simple bool version with true for good.");
	    # version 1, let us return 0
	} else {
	    if ( $ver !=2 ) {
		#version other than 2 describe failure but keep operating in new mode.
		funct_obsolete("data_integrity","1 simple bool sucess, 2 return md5.");
	    }
	    # reutrn our md5 as array ref.
	    #$data_check = $md5[0];
	    $data_check = $md5;
	}
    }
    # return ( $data_check ) ; #this emulates previous behavior well, If we return null on failure;
    return $data_check; 
}
# -------------
sub file_checksum {
# -------------
    # run checksum on file and return checksum result.
    my ($file) = @_;
    #use Digest::MD5 qw(md5 md5_hex md5_base64); 
    require Digest::MD5;
    # THIS LINE BREAKS ON NEW MACS! Known functional perl 5.12(mac OS 10.7)
    #Digest::MD5->import qw(md5 md5_hex md5_base64); # works on old, but not new
    #Digest::MD5 import qw(md5 md5_hex md5_base64);  # works on new and old
    #Digest::MD5 import; #FAILS on new!!!! WTF!!!!
    Digest::MD5->import(qw(md5 md5_hex md5_base64));  #works everwhere.

    
    # These two tests are syntax errors
    #Digest::MD5::import qw(md5 md5_hex md5_base64); 
    #Digest->MD5->import qw(md5 md5_hex md5_base64); 

   
    open  my $data_fid, "<", "$file" or die "could not open $file, error $!\n";
    #print("md5 calc on $file\n");
    my $md_calc=Digest::MD5->new ;
    $md_calc->addfile($data_fid);
    #my $md5 = $md_calc->b64digest;
    #my $md5 = $md_calc->digest;
    my $md5 = $md_calc->hexdigest;
    close $data_fid or warn "error on file close $file";
    #print("md5:$md5\n");
    return $md5;
}

# -------------
sub link_checksum {
# -------------
    # run checksum on link and return checksum result.
    my ($file) = @_;
    #use Digest::MD5 qw(md5 md5_hex md5_base64); 
    require Digest::MD5;
    # THIS LINE BREAKS ON NEW MACS! Known functional perl 5.12(mac OS 10.7)
    #Digest::MD5->import qw(md5 md5_hex md5_base64); 
    Digest::MD5->import( qw(md5 md5_hex md5_base64)); 
    my $data = readlink $file or die "could not read link $file, error $!\n";
    #print("md5 calc on $file\n");
    my $md_calc=Digest::MD5->new ;
    $md_calc->add($data);
    #my $md5 = $md_calc->b64digest;
    #my $md5 = $md_calc->digest;
    my $md5 = $md_calc->hexdigest;
    #print("md5:$md5\n");
    return $md5;
}


# -------------
sub static_data_update{
# -------------
    
    #foreach local file, md5
    #scp remote md5 to temp place
    # compare.

    
    return;
}



# -------------
sub make_matlab_command_V2 { 
# -------------
# small wrapper for make_matlab_command, the v2 functionality has been integrated into the original. 
# This is just to contain cases where we called the v2 version and they havnt been found yet.
    funct_obsolete("make_matlab_command_V2","make_matlab_command");
    my $cmd_to_execute = make_matlab_command(@_);
    return ($cmd_to_execute);
}


# -------------
sub rp_key_insert { 
# -------------
# takes key pfile and inserts it into keyhole pfile using matlab script evan made
# my $rp_insert_status=rp_key_insert($keyhole_pfile_path,  $final_output_pfile_path, $Engine_matlab_path);	
#    my ($keyhole_runno,$result_pfile_basename,$final_output_pfile_path, $result_pfile_extension_dot,$keyhole_pfile_path,$local_dest_dir,$Engine_matlab_path,@other)=@_;
    my ($keyhole_rpfile_path, $key_rpfile_path,$local_dest_dir,$Engine_matlab_path)=@_;
    my $mfilename="cartesian_keyhole";
    my $mat_args="'$keyhole_rpfile_path','$key_rpfile_path'"; # will insert final into keyhole, and save to final.
    my $purpose='insert_key';
    my $matlab_cmd=make_matlab_command_nohf($mfilename, $mat_args, $purpose, $local_dest_dir, $Engine_matlab_path);
    my $result_status=1;
    if ( ! -e "${key_rpfile_path}.bak" ) {
	use File::Copy "cp";
	cp("${key_rpfile_path}","${key_rpfile_path}.bak");
	print ("<~ executing matlab command to insert keyhole $matlab_cmd\n");
	$result_status=qx/$matlab_cmd/;    # do matlab call
    } else { 
	print("RP file already inserted into keyhole\n"); 
    }
#	my $w
#engine_app_matlab=/usr/bin/matlab
    sleep 30;

    return $result_status;
}

# -------------
sub make_matlab_command_V2_OBSOLETE {
# -------------
# this funcion has identicle functionalaity to make_matlab_command,  the only difference is in the HF keys looked up, they use - separators instead of _, updated make_malab_command to look for first one then the other
   my ($function_m_name, $args, $short_unique_purpose, $Hf) = @_;
# short_unique_purpose is to make the name of the mfile produced unique over the pipeline (they all go to same dir) 
   my $work_dir   = $Hf->get_value('dir-work');
   my $matlab_app = $Hf->get_value('engine-app-matlab');
   my $matlab_opts = $Hf->get_value('engine_app_matlab_opts');
   my $mfile_path = "$work_dir/$short_unique_purpose$function_m_name";
   my $function_call = "$function_m_name ( $args )";
   make_matlab_m_file ($mfile_path, $function_call);
   my $logpath="$work_dir/matlab_${function_m_name}";
   my $cmd_to_execute = "$matlab_app < $mfile_path > $logpath";
#   my $cmd_to_execute = "$matlab_app $matlab_opts < $mfile_path > /tmp/matlab_pipe_stuff";
   return ($cmd_to_execute);
}

# -------------
sub execute {
# -------------
# returns 0 if error

    my ($do_it, $annotation, @commands) = @_;
    my $rc;
    my $i = 0;
    my $ret;
    #my $hostynamey=`hostname -s`;
    #pchomp($hostynamey);
    foreach my $c (@commands) {
	$i++;
	if (`hostname -s` =~ /civmcluster1/ ) {
	    #if ($hostynamey eq  "civmcluster1") { # fixme: this will need to be generalized for any given cluster name(BJA

	    # For running Matlab, run on Master Node for now until we figure out how to handle the license issue. Otherwise, run with SLURM
	    if ($c =~ /matlab/) {
		$c = $c;
	    } else {
		if ($custom_q == 1) {
		    $c = "srun -s -p $my_queue ".$c;
		} else {
		    $c = "srun -s ".$c;
		}
		print("SLURM MODE ENGAGED\n");
	    }
	} else {
	    $c = $c;
	    #print("SLURM MODE DISABLED:$hostynamey\n");
	}

	    
	$ret = execute_heart($do_it, $annotation, $c);

	if (0) { ################
	    # -- log the info and the specific command: on separate lines
	    my $msg;
	    #print "Logfile is: $pipeline_info_log_path\n";
	    my $skip = $do_it ? "" : "Skipped ";
	    my $info = $annotation eq '' ? ": " : " $annotation: "; 
	    my $time = scalar localtime;
	    $msg = join '', $skip, "EXECUTING",$info, "--", $time , "--";
	    my $cmsg = "   $c";
	    log_info($msg);
	    log_info($cmsg);
	    if (0) {  # this shows imperfect shortened version of command; I think it's confusing 
		my $simple_cmd = depath_annot($c);
		log_info(" $simple_cmd");
	    }

	    if ($do_it) {
		$rc = system ($c);
	    } else {
		$rc = 0; # fake ok
	    }

	    # print "------ system returned: $rc -------\n";
	    # note: ANTS returns 0 even when it says: "Exception thrown: ANTS";
	    if ($rc != 0) {
		print STDERR "  Problem:   system() returned $rc\n";
		print STDERR "  * Command was: $c\n";
		print STDERR "  * Execution of command failed.\n";
		return 0;
	    }
	} #######################

    }
    ##return 1;
    return $ret;
}

# -------------
sub execute_heart {
# -------------

    my ($do_it, $annotation, $single_command) = @_;
    my $rc;

    # -- log the info and the specific command: on separate lines
    my $msg;
    #print "Logfile is: $pipeline_info_log_path\n";
    my $skip = $do_it ? "" : "Skipped ";
    my $info = $annotation eq '' ? ": " : " $annotation: ";
    my $time = scalar localtime;
    $msg = join '', $skip, "EXECUTING",$info, "--", $time , "--";
    my $cmsg = "   $single_command";
    log_info($msg);
    log_info($cmsg);

    if (0) {
	my $simple_cmd = depath_annot($single_command);
	log_info(" $simple_cmd");
    }

    if ($do_it) {
	#if ($do_it<=1){
	    $rc = system ($single_command);
	#} else {
	#    exec($single_command);
	#}
	#$rc=$rc/256;
    }
    else {
	$rc = 0; # fake ok
    }

    #print "------ system returned: $rc -------\n";
    # note: ANTS returns 0 even when it says: "Exception thrown: ANTS";
    if ($rc != 0) {
	print STDERR "  Problem:  system() returned: $rc\n";
	print STDERR "  * Command was: $single_command\n";
	print STDERR "  * Execution of command failed.\n";
	return 0;
    }
    return 1;
}

# -------------
sub execute_indep_forks {
# -------------
# returns 0 if error

  my ($do_it, $annotation, @commands) = @_;
  my @children;
  my $nforked=0;
  my $total_forks =0;

  my $ncores=2;
  if ( "$OSNAME" =~ 'darwin' ){
      $ncores=`sysctl -n hw.ncpu 2>/dev/null`;
  } elsif ("$OSNAME" =~ 'Linux' ){
   warn('indep_fork linux handling incomplete');   
  } elsif ("$OSNAME" =~ 'MSWin32' ){
   warn('indep_fork windows handling incomplete');   
  } else {
      warn('indep_fork unknown os handling incomplete('.$OSNAME.')');   
  }
  #$ncores=20000000; # fail conditional for many procs.
##### 
#INDEP FORK REAPER
  $SIG{CHLD} = sub {
# this reaps ALL COMPLETED children each time a child completes,
# this means sometimes it will run with no children because an earlier run cleaned up all the children.
# THIS DOES NOT wait for uncompleted children
      my $completed=0;
      while () {
	  #waitpid returns child PID if child has stopped.
	  #waitpid returns -1 on a failure
	  #waitpid returns 0 on child still running. 
	  # this is a sig chld handler, so it should never still be running.
	  my $child = waitpid -1, POSIX::WNOHANG;
	  last if $child <= 0;
	  my $ev=$?>> 8;
	  #print "Parent: Child $child was reaped - $localtime. \n";
	  my $localtime = localtime;
	  if ( $ev ) {
	      error_out( "Parent: Child ended with error code! $localtime - $child was reaped with error code:$ev \n");
	      #error_out( "Parent: Child $child was reaped - $localtime with error code:$ev \n");
	  }
	  $nforked-=1;
	  $completed++;
      }
      my $endtime = localtime;
      print("\tcollected $completed finished process(es). - $endtime \n"); # test print to show when the reaper has killed a child.
  };
#####
  print("forking with up to ".(2*$ncores)." processes");
  while($#commands>=0) {
      #foreach my $c (@commands) {
      my $c=shift(@commands);
      my $msg;
      #print "Logfile is: $pipeline_info_log_path\n";
      my $skip = $do_it ? "" : "Skipped ";
      my $info = $annotation eq '' ? ": " : " $annotation: ";
      my $time = scalar localtime;
      $msg = join '', $skip, "EXECUTING",$info, "--", $time , "--";
      my $cmsg = "   $c";
      my $pid = fork();
      if ($pid) { 
# parent
	  push(@children, $pid);
	  $total_forks ++;
	  $nforked ++;
	  while ($nforked > $ncores ) # this will allow about twice the number of cores worth of work to be scheduled.
	  {
# 	      $SIG{CHLD} = sub {# this reaps all COMPLETED children but does not wait on uncompleted
# 		  while () {
# 		      my $child = waitpid -1, POSIX::WNOHANG;
# 		      last if $child <= 0;
# 		      my $localtime = localtime;
# 		      print "Parent: Child $child was reaped - $localtime.\n";
# 		      $nforked-=1;
# 		  }
# 	      };
#	      print('.');
	  } 
####

      } elsif ($pid == 0) { 
# child
#	  print "child fork $$\n";
	  #sleep(5+int(rand(10)));# a test sleep of 5-15 seconds to make sure our children all end at different times.
	  if ( 1 ) {
#### cut execute_heart
#execute_heart DIT NOT perform well here for fast tasks.	      
	      if ($do_it) {
		  log_info($msg);
		  log_info($cmsg);      
		  #if ($do_it<=1){
		  exec($c); 
		  exit 0;
	      }
	  } else {
	      my $ret = execute_heart($do_it, $annotation, $c);
	      exit 0;
	  }
	  #print "Forked child $$ finishes ret = $ret\n";
	  exit 0;
####
      }else {
	  warn "couldn\'t fork: $!\n";
	  push (@commands,$c);
	  #### change this to a warn condition, and push command back on stack?
	  $SIG{CHLD} = sub {#reap any available children? or reap all open children?
	      while () {# this reaps all COMPLETED children but does not wait on uncompleted
		  my $child = waitpid -1, POSIX::WNOHANG;
		  last if $child <= 0;
		  my $localtime = localtime;
		  print "nf:Parent: Child $child was reaped - $localtime.\n";
		  print("ERROR CONDITION< ALTENRATE CHILD REAPER USED\n\t SLEEPING FOR 60!!!!!!\n");
		  sleep(60);
		  $nforked-=1;
	      }
	  };
      }
  } # end of commmand dispatch


  #print "All $nforked command forks made, parent to assure all childen have finished...\n";
# if i'm reading this loop right it will wait for each child in turn for it to finish, meaning it wont say anything until the first cihld finishes, and will report closed children in order of opening not in their order of closing, essentially it will hang on waitpid for the first kid to finish, then it will check the second, and so on until its' checked each child exaclty once. 
# suffice it to say, not the perfect loop for childre checkup, but certainly functional
  if ( 0  ) {
      foreach (@children) {
	  print "  parent checking/waiting on child pid $_ ...";
	  my $tmp = waitpid($_, 0);
	  $nforked -= 1;
	  print "pid $tmp done, $nforked child forks left.\n";
      }
  }
  #wait 1 second at a time for any remaining children to finish.
  while ( $nforked> 0 ) {
      sleep(1);
      #print STDERR ("."); # just too keep us interested. bad idea, some of our commands have valid output to look at.
  }
  print "Execute: waited for all $total_forks command forks to finish; fork queue remainder $nforked. \n";
  
  return($$);
}




# -------------
sub executeV2 {
# -------------
# ANTS returns status=0 (ok) via system even when ANTS say it has an error: 
# "Exception thrown: ANTS", before it quits.
# executeV2 tries to catch both system return and program text output
# and look in the output for the line containing "Exception thrown",
# to return error==0 to the caller.
#
# Returns 0 if error.

  my ($do_it, $annotation, @commands) = @_;
  my $rc;
  my $i = 0;
  foreach my $c (@commands) {
    $i++;

    # -- log the info and the specific command: on separate lines
    my $msg;
    #print "Logfile is: $pipeline_info_log_path\n";
    my $skip = $do_it ? "" : "Skipped ";
    my $info = $annotation eq '' ? " " : " command $annotation ";
    my $time = scalar localtime;
    $msg = join '', $skip, "EXECUTING (v2)",$info, "--", $time , "--";
    my $cmsg = "   $c";
    log_info($msg);
    log_info($cmsg);
if (0) {
    my $simple_cmd = depath_annot($c);
    log_info(" $simple_cmd\n");
}

    my $output;
    my @what;
    if ($do_it) {
      if (0) { # old way when you trust return status 
        $rc = system ($c);
      }
      # --- examine both status and output, since ANTS returns status ok when there is an error 
      #@what = reverse ($_ = qx{$c 2>&1}, $? >> 8); 
      #@what = reverse (qx{$c 2>&1}, $? >> 8); 
      if (0) {
        #@what = (qx{$c 2>&1});  # capture stderr and stdout together 
        @what = qx{$c 3>&1 1>&2 2>&3 3>&-};
      }
      else {
         #To exchange a command's STDOUT and STDERR in order to capture the STDERR but leave its STDOUT to come out our old STDERR:
         # It looks like ANTS "Exception thrown" output comes out on STDERR and other msgs on STDOUT -- good.
         # This command lets STDOUT get shown to alex as it is created, and sends the STDERR for my checking 
        my $something_on_stderr = 0;
        my $pid = open(PH, "$c 3>&1 1>&2 2>&3 3>&-|");
        while (<PH>) {
           $something_on_stderr = 1;
           print "Executed command sent this message to STDERR: $_\n";
           if (/Exception thrown/) {  # checks $_
              print "  Execute recognized this ANTS error msg: $_\n";
           }
        }
	if ($pid ) { waitpid $pid, 0 ; }# ensure the open finishes.

        $rc = $?;
        if ($something_on_stderr) {
          print STDERR "  Problem:\n";
          #print STDERR "  * Command was: $c\n";
          print STDERR "  * Execution of command failed.\n";
          print STDERR "  * Reason: command output included message(s) on STDERR, (although) return status=$rc (0==ok))"; 
          return 0;  # not ok
        }
      }
    }
    else {
      print "  Not really executing command: do_it = 0\n";
      $rc = 0;   # a fake ok
    }

    if ($rc != 0) {  
      # --- status denotes a problem
      print STDERR "  Problem:\n";
      #print STDERR "  * Command was: $c\n";
      print STDERR "  * Execution of command failed; status = $rc.\n";
      return 0;  # 0 not ok;
    }
  }
  return 1; # ok = 1
}

# -------------
sub start_pipe_script {
# -------------
#my $version = "20130725";
#my $BADEXIT = 1;
#my $GOODEXIT = 0;

# use Env qw(RADISH_RECON_DIR);
# if (! defined($RADISH_RECON_DIR)) {
#   print STDERR "Environment variable RADISH_RECON_DIR must be set. Are you user omega?\n";
#   print STDERR "   CIVM HINT setenv RADISH_RECON_DIR /recon_home/script/dir_radish\n";
#   print STDERR "Bye.\n";
#   exit $BADEXIT;
# }

#use lib "$RADISH_RECON_DIR/modules/script";
use Env qw(RADISH_PERL_LIB);
if (! defined($RADISH_PERL_LIB)) {
    print STDERR "Cannot find good perl directories, quiting\n";
#    exit $ERROR_EXITA;
}
use lib split(':',$RADISH_PERL_LIB);

#use Getopt::Std;
#use File::Path;
#use File::Spec;

#require shared;
#require Headfile;
return 1; 
}

# ------------------
sub load_engine_deps {
# ------------------
    my ($engine) = @_;
    return load_deps($engine,"engine");
}

# ------------------
sub load_deps {
# ------------------
# load local engine_deps, OR load an arbitrary one, return the engine constants headfile
    my ($device,$type) = @_;
  
    my @errors;
    my @warnings;
    use Env qw(PIPELINE_HOSTNAME PIPELINE_HOME WKS_SETTINGS WORKSTATION_HOSTNAME);
    
    # alternate way to get the path to the device constants file
    # if ( defined $WKS_SETTINGS) { $this_device_constants_path = get_device_constants_path($WKS_SETTINGS,$WORKSTATION_HOSTNAME); }
    
    ### set the host
    if  ( ! defined($WORKSTATION_HOSTNAME)) { 
	push(@warnings,"WARNING: obsolete variable PIPELINE_HOSTNAME used.");
	$WORKSTATION_HOSTNAME=$PIPELINE_HOSTNAME;
    }
    if ( defined($device)) { $WORKSTATION_HOSTNAME=$device; };
    if (! defined($WORKSTATION_HOSTNAME)) { push(@warnings, "Environment variable WORKSTATION_HOSTNAME not set."); }
    
    ### set the dir
    my $device_constants_dir;
    if ( ! defined($WKS_SETTINGS) ) { 
	if (! -d $PIPELINE_HOME) { push(@errors, "unable to find $PIPELINE_HOME"); }
	print("WARNING: obsolete variable PIPELINE_HOME used to find dependenceis");
	$WKS_SETTINGS=$PIPELINE_HOME;
	$device_constants_dir="$WKS_SETTINGS/dependencies";
    } else { 
	$device_constants_dir="$WKS_SETTINGS/".$type."_deps";
    }
    if (! -d $device_constants_dir) { push(@errors, "$device_constants_dir does not exist."); }
    
    ### set the file name
    my $device_file =join("_","$type","$device","dependencies"); 
    my $device_constants_path = "$device_constants_dir/".$device_file;

    # if ( ! -f $the_device_constants_path ){
    # 	$device_type='nas';
    # 	$device_file_name            = join("_",$device_type,$device,"radish_dependencies");
    # 	print("Using nas device settings\n");
    # 	$the_device_constants_path = join("/",$WKS_SETTINGS."/".$device_type."_deps/", $device_file_name); 
    # }

    if ( ! -f $device_constants_path ) {
	push(@warnings,"WARNING: first constants path $device_constants_path missing");
	$device_file=join("_","$type","$device","radish_dependencies");
	$device_constants_path = "$device_constants_dir/".$device_file;
	if ( ! -f $device_constants_path ) {
	    push(@warnings,"WARNING: second constants path $device_constants_path missing");
	    $device_file=join("_","$type","$device","pipeline_dependencies");
	    $device_constants_path = "$device_constants_dir/".$device_file;
	    if ( -f $device_constants_path ) {
		push(@warnings,"WARNING: OBSOLETE SETTINGS FILE USED, $device_file\n\tConsider updating system!");
	    } 
	}
    }
    my $device_constants ;
    if (-f $device_constants_path ) {
	### load device_deps
	$device_constants = new Headfile ('ro', $device_constants_path);
	if (! $device_constants->check()) {
	    push(@errors, "Unable to open device constants file $device_constants_path");
	}
	if (! $device_constants->read_headfile) {
	    push(@errors, "Unable to read device constants from headfile form file $device_constants_path");
	}
    }
    if (scalar(@warnings)>0) {
	print(join("\n",@warnings)."\n");
    }
    if (scalar(@errors)>0) {
	print(join(", ",@errors)."\n");
    }
    return $device_constants;
}

# ------------------
sub make_process_dirs {
# ------------------
    my ( $identifier) =@_;

    use Env qw(BIGGUS_DISKUS);
    my @errors;
    if (! defined($BIGGUS_DISKUS))       { push(@errors, "Environment variable BIGGUS_DISKUS must be set."); }
    if (! -d $BIGGUS_DISKUS)             { push(@errors, "unable to find disk location: $BIGGUS_DISKUS"); }
    if (! -w $BIGGUS_DISKUS)             { push(@errors, "unable to write to disk location: $BIGGUS_DISKUS"); }

    my @dirs;
    foreach ( qw/inputs work results/ ){
	push(@dirs,"$BIGGUS_DISKUS/$identifier\-$_"); }
    foreach (@dirs ){
	if (! -d ){
	    mkdir( $_,0777) or push(@errors,"couldnt create dir $_");}}
    

#   if (! -e $local_work_dir) {
#     mkdir $local_work_dir;
#   }
#   if (! -e $local_result_dir) {
#     mkdir $local_result_dir;
#   }
    
    if ( $#errors >= 0 ) { 
	error_out(join(", ",@errors));
    }
    
    my $local_input_dir = "$BIGGUS_DISKUS/$identifier\-inputs"; # may not exist yet
    my $local_work_dir  = "$BIGGUS_DISKUS/$identifier\-work";
    my $local_result_dir  = "$BIGGUS_DISKUS/$identifier\-results";
    my $result_headfile = "$local_result_dir/$identifier\.headfile"; 
    return ($local_input_dir, $local_work_dir, $local_result_dir, $result_headfile);

}

# ------------------
sub new_get_engine_dependencies {
# ------------------
# finds and reads engine dependency file 
# error checks required values passed in addition to the standard required things.
  my ($identifier,@required_values) = @_;

  my @errors;

  use Env qw(PIPELINE_HOSTNAME PIPELINE_HOME BIGGUS_DISKUS WKS_SETTINGS WORKSTATION_HOSTNAME);


  if (! defined($BIGGUS_DISKUS))       { push(@errors, "Environment variable BIGGUS_DISKUS must be set."); }
  if (! -d $BIGGUS_DISKUS)             { push(@errors, "unable to find disk location: $BIGGUS_DISKUS"); }
  if (! -w $BIGGUS_DISKUS)             { push(@errors, "unable to write to disk location: $BIGGUS_DISKUS"); }
  if (! defined($PIPELINE_HOME))       { push(@errors, "Environment variable WKS_SETTINGS must be set."); }
  if  ( ! defined($WORKSTATION_HOSTNAME)) { 
      print("WARNING: obsolete variable PIPELINE_HOSTNAME used.\n");
      $WORKSTATION_HOSTNAME=$PIPELINE_HOSTNAME;
  }
  if (! defined($WORKSTATION_HOSTNAME)) { push(@errors, "Environment variable WORKSTATION_HOSTNAME must be set."); }
  my $engine_constants_dir ;
  if ( ! defined($WKS_SETTINGS) ) { 
      if (! -d $PIPELINE_HOME)             { push(@errors, "unable to find $PIPELINE_HOME"); }
      print("WARNING: obsolete variable PIPELINE_HOME used to find dependenceis\n");
      $WKS_SETTINGS=$PIPELINE_HOME;
      $engine_constants_dir="$WKS_SETTINGS/dependencies";
  } else { 
      $engine_constants_dir="$WKS_SETTINGS/engine_deps";
  }

  if (! -d $engine_constants_dir)      { push(@errors, "$engine_constants_dir does not exist."); }

  my $engine_file =join("_","engine","$WORKSTATION_HOSTNAME","dependencies"); 
  my $engine_constants_path = "$engine_constants_dir/".$engine_file;
  if ( ! -f $engine_constants_path ) { 
      $engine_file=join("_","engine","$WORKSTATION_HOSTNAME","pipeline_dependencies");
      $engine_constants_path = "$engine_constants_dir/".$engine_file;
      print("WARNING: OBSOLETE SETTINGS FILE USED, $engine_file\n")
  }
  
  my $engine_constants = new Headfile ('ro', $engine_constants_path);
  if (! $engine_constants->check()) {
    push(@errors, "Unable to open engine constants file $engine_constants_path\n");
  }
  if (! $engine_constants->read_headfile) {
     push(@errors, "Unable to read engine constants from headfile form file $engine_constants_path\n");
  }

  foreach (@required_values) { 
      print("$_: ".$engine_constants->get_value($_)."\n");      
      if ( ! defined ( $engine_constants->get_value($_) ) ){ 
	  push(@errors," Unable to find required value $_"); 
      } elsif ( $engine_constants->get_value($_) =~ /\//x && ! -e $engine_constants->get_value($_) ) { 
	  #if it starts with a slash, its probably a path, so we can check for its existence.
	  push(@errors," Required value set but file not found : $_=$engine_constants->get_value($_)");
      }
  }
  my $local_input_dir = "$BIGGUS_DISKUS/$identifier\-inputs"; # may not exist yet
  my $local_work_dir  = "$BIGGUS_DISKUS/$identifier\-work";
  my $local_result_dir= "$BIGGUS_DISKUS/$identifier\-results";

#   if (! -e $local_work_dir) {
#     mkdir $local_work_dir;
#   }
#   if (! -e $local_result_dir) {
#     mkdir $local_result_dir;
#   }

  if ( $#errors >= 0 ) { 
      error_out(join(", ",@errors));
  }
  my $result_headfile = "$local_result_dir/$identifier\.headfile"; 
  return($local_input_dir, $local_work_dir, $local_result_dir, $result_headfile, $engine_constants);
}


# -------------
sub make_list_of_files {
# -------------
  my ($directory, $file_template) = @_;
  # make a list of all files in directory fitting template
  # don't use unix ls for checks, since it can't bring back list of 512
  # this can handle 512, probably any
  # I hope pc "dir" can handle 512

  #print "make_list: $directory, $file_template\n";
  my @flist = ();
  my ($ok, @allfiles) = my_ls($directory);
  if (! $ok) {
    print ("  make_list_of_files: Error unable to list dir=$directory\n");
    my $msg = pop @allfiles;
    print ("      list error msg: $msg\n");
    @flist = ();
    return (@flist);
  }
  my $file = "";
  foreach my $f (@allfiles) {
    $file = $f;
    my $thing;
    $thing = $f =~ /$file_template/;
    #print ("  Checking $f against $file_template, yes/no=$thing\n");
    if ($thing) { push (@flist, $file) }
  }
  #print "  found LIST= @flist\n";
  return (@flist);
}

# -------------
sub my_ls {
# -------------
  # returns (code, @filelist)
  my ($unixy_dir) = @_;
  my @allfiles =  ("error");
  my $result = 0;
  opendir THISDIR, $unixy_dir or error_out("open dir failure, $!");;
  @allfiles = readdir THISDIR;
  closedir THISDIR;
  $result = 1;
  return ($result, @allfiles);
}

# -------------
sub writeTextFile {
# -------------
  # returns 1 or 0
  my ($filepath, @msg) = @_;
  # assumes containing directory exists
    if (open SESAME, ">$filepath") {
      foreach my $line (@msg) {
        print SESAME $line;
      }
      close SESAME;
      print STDERR "  Wrote or re-wrote $filepath.\n";
    }
    else {
      print STDERR  "ERROR: Cannot open file $filepath, can\'t writeTextFile\n";
      return 0;
    }
  if (! -e $filepath) { return 0; }
  else { return 1; }  # OK
}

# -------------
sub xml_read {
# -------------
    require XML::Rules;
    # Imports similar to this BROKE ON NEW MACS! Those used qw(list of things). It is known functional perl 5.12(mac OS 10.7). 
    #XML::Rules->import;
    XML::Rules->import();
    my ($xml_file,$options)=@_;

    if ( 1 ) {
	#my $rules = XML::Rules::inferRulesFromExample( <xml_example> ); 
	# replace basename of file? grab all xml files there? ! 
	my $rules = XML::Rules::inferRulesFromExample( $xml_file );# could pass many xml files here to form rules, might be good to grab all xml's we know about.
	#print Data::Dump::dump( $rules );# dump not found :(
	# now refine the rules skeleton
	my $parser = XML::Rules->new( rules => $rules );
	my $data = $parser->parsefile( $xml_file );
	
	if($options =~ /giveparser/) {
	    return($data,$parser);
	} else {
	    return($data);
	}
	
    } elsif(0) {
	
	#my $parser = XML::Rules->new( %{XML::Rules::inferRulesFromExample( $xml_file )} );
	#my $data = $parser->parsefile( $xml_file );
	#return $data;
    } else {
    my $parser = XML::Rules->new(
	stripspaces =>7,
	rules => { 
	    Slice => sub {
		my ($tag,$atts)=@_;
		return;
	    },
	    'INFO,CHATTER' => 'pass',
	}
	);
    my $data=$parser->parsefile($xml_file);
    return ($data,\$parser);
    }
}

sub xml_to_string {
    require XML::Rules;
    # Imports similar to this BROKE ON NEW MACS! Those used qw(list of things). It is known functional perl 5.12(mac OS 10.7). 
    #XML::Rules->import;
    XML::Rules->import();
    my ( $xml_ref,$xml_file,$outpath) = @_;
    my $rules = XML::Rules::inferRulesFromExample( $xml_file );# could pass many xml files here to form rules, might be good to grab all xml's we know about.
    my $parser = XML::Rules->new( rules => $rules );
    my $xml=$parser->ToXML('',$xml_ref);
    my $sucess=0;
    return $xml;
}

####
# mrml support should be in its own pm, we're just stuffing it here for brevity right now. 
###
# mrml, xml structure as loaded is a hash of arrays of hashes of scalars. For sanity we could convert this to a hash of hashes of scalars.
# current strucutre has one element per MRML tag in the primary hash. each element found adds a new element to the array for that element.
# could change structure to more directly represent the mrml structure using a hash of mrml nodes, with a hash of values per node.

# 
sub mrml_find_by_id {
# 
# find the mrml node in the loaded xml tree by id
# get a reference to the mrml hash, given specific name, and optionally given a type.
    my ($mrml_tree,$value,$type)=@_;
    my @arr=mrml_attr_search($mrml_tree,"id",$value,$type);
    #my @arr=@{$a_ref};
    if ($#arr<0){
	@arr=mrml_attr_search($mrml_tree,"id",$value,$type."Node");
    }
    return @arr;
}
# 
sub mrml_find_by_name {
# 
# get a reference to the mrml hash, given specific name, and optionally given a type.
    my ($mrml_tree,$value,$type)=@_;
    #ref to mrml tree.

#     if(defined $mrml_tree) {
# 	print("mrlm_tree:".ref($mrml_tree)."\n");
#     }
#     if(defined $value) {
# 	print("id:".ref($value)."\n");
#     }
#     #ref to mrml tree.
#     if(defined $type) {
# 	print("type:".ref($type)."\n");
#     }
    return mrml_attr_search($mrml_tree,"name",$value,$type);
}
# 
sub mrml_find_by_type {
# 
# find the mrml node in the loaded xml tree by id
# get a reference to the mrml hash, given specific name, and optionally given a type.
    my ($mrml_tree,$type)=@_;
    my $value=".*";
    my @arr=mrml_attr_search($mrml_tree,"id",$value,$type);
    #my @arr=@{$a_ref};
    if ($#arr<0){
	@arr=mrml_attr_search($mrml_tree,"id",$value,$type."Node");
    }
    return @arr;
}
# 
sub mrml_attr_search {
# 
# find the mrml node in the loaded xml tree by attr and its value
    my ($mrml_tree,$attr,$value,$type)=@_;
    #ref to mrml tree. when 
    #$mrml_tree->{"MRML"};
    my @mrml_types;
    my @refs;
    die unless ( defined $attr);# print("attr undef") 
    die unless ( defined $value);# print("attr undef") 

    if ( defined $mrml_tree->{"MRML"} && keys %{$mrml_tree} <=1  ) {
	$mrml_tree=$mrml_tree->{"MRML"};
    }
    if ( ! defined $type ) { 
	@mrml_types=keys %{$mrml_tree};
    } else {
	push(@mrml_types,$type);
    }
    for $type (@mrml_types) {
	my $a_ref=ref($mrml_tree->{$type});
	my @hash_array;
	if ( $a_ref eq 'ARRAY') {
	     @hash_array=@{$mrml_tree->{$type}};
	} else{ 
	    print("$type Singleton.\n") if ($debug_val>=95);
	    push(@hash_array,$a_ref);
	}
	#for ( my $ha_i=0; $ha_i<$#{$mrml_tree->{$type}};$ha_i++ ){#when all arrays this works, but some are not so we trick this by makeing those cases arrays also.
	for ( my $ha_i=0; $ha_i<=$#hash_array;$ha_i++ ){
	    #foreach my $ref (@hash_array) {
	    my $ref=$hash_array[$ha_i];# this is just to simplify reading the code.
	    if ( ref($ref) eq 'HASH' && defined $ref->{$attr}) {
		if ( $ref->{$attr} =~ /$value/x) { 
		    #print($ref." ".$ref->{$attr}."\n");
		    #push(@refs,${$mrml_tree->{$type}}[$ha_i]);#when all ar arrays this works, but some are not. 
		    push(@refs,$hash_array[$ha_i]);
		} 
 	    }
	}
    }
    my $count=$#refs+1;
    print("got ".$count." match(es)\n")if ($debug_val>=50);;
    return @refs; #ref to mrml tree.
}
sub mrml_clear_nodes { 
    my ($mrml_tree,@saved_types)=@_;

    my @mrml_types;
    my @refs;

    if ( defined $mrml_tree->{"MRML"} && keys %{$mrml_tree} <=1  ) {
	$mrml_tree=$mrml_tree->{"MRML"};
    }

    my $node_match="(".join("|",@saved_types).")";
    @mrml_types=keys %{$mrml_tree};
    for my $type (@mrml_types) {# for each type of mrml_node
	my $a_ref=ref($mrml_tree->{$type});
	my @hash_array;
	if ($type !~ /^$node_match$/x ){
	    delete $mrml_tree->{$type};
	}

# 	if ( $a_ref eq 'ARRAY') {
# 	     @hash_array=@{$mrml_tree->{$type}};
# 	} else{ 
# 	    print("$type Singleton.\n") if ($debug_val>=95);
# 	    push(@hash_array,$a_ref);
# 	}
# 	#for ( my $ha_i=0; $ha_i<$#{$mrml_tree->{$type}};$ha_i++ ){#when all arrays this works, but some are not so we trick this by makeing those cases arrays also.
# 	for ( my $ha_i=0; $ha_i<$#hash_array;$ha_i++ ){
# 	    #foreach my $ref (@hash_array) {
# 	    my $ref=$hash_array[$ha_i];# this is just to simplify reading the code.
# 	    if ( defined $ref->{$attr}) {
# 		if ( $ref->{$attr} =~ /$id/x) { 
# 		    #print($ref." ".$ref->{$attr}."\n");
# 		    #push(@refs,${$mrml_tree->{$type}}[$ha_i]);#when all ar arrays this works, but some are not. 
# 		    push(@refs,$hash_array[$ha_i]);
		    
#  		} 
#  	    }
    }
    return; 
}

sub mrml_find_attrs {
# returns matching values for array of regular expressions
# values returned in a hash of arrays. with one hash element per referenc found.
    my ( $mrml_ref1,@attrs) =@_;
    if ( ref($mrml_ref1) eq "HASH") {
	
    }
    my @mrml_keys=keys %{$mrml_ref1};
    my %mrml_attrs=();
    my $regex=join('|',@attrs);
    
    for my $attr (@mrml_keys) {
	
	#print("check $attr\n");
	if ($attr=~ /($regex)/ ) {
	    if ( ! defined( $mrml_attrs{$attr} ) ) { 
		$mrml_attrs{$attr}=();
	    }
	    push(@{$mrml_attrs{$attr}},$mrml_ref1->{$attr});
	}
    }
    return \%mrml_attrs;
}

sub mrml_get_refs {
# get mrml ids referneced in mrml node, and perhaps its child nodes
    use List::MoreUtils qw/uniq/;
    my ($mrml_tree,$node)=@_;
    if ( defined $mrml_tree->{"MRML"} && keys %{$mrml_tree} <=1  ) {
	$mrml_tree=$mrml_tree->{"MRML"};
    }
    my %mrml_refs=();
    my $mrml_subrefs={};
    my %nodelinks=();
    my @all_nodes;
#    dump($node);
    my $attrhref=mrml_find_attrs($node,"(^ref.*|.*Ref\$)");
    my %refmatches=%{$attrhref};

#    dump(%refmatches);
#     if ( keys(%refmatches) > 1 ) { 
# 	dump(%refmatches);
#     }
        
    for my $mrml_attr ( keys(%refmatches)){
	print("procesing $mrml_attr\n");
#	my $mrml_refids=$node->{"references"};# old way of getting reference bits.
	my @refa=@{$refmatches{$mrml_attr}};
	#dump(@refa);
	if ($#refa>0){
	    warn("More than one entry found in hash\n");
	}
	for my $mrml_refids (@refa) {
	    #dump($mrml_refids);
	    # split reference list in pieces, reference type will have : after it
	    # reference list
	    #my @mrml_id_list = $mrml_refids =~ /([[:alnum:]]+[:])([[:alnum:]]+)([\s]+[[:alnum:]]+)?/xg;
	    my @mrml_id_list = $mrml_refids =~ /(?:([[:alnum:]]+[:])([[:alnum:]]+)([\s]+[[:alnum:]]+)?)|([[:alnum:]]+)/xg;

#	my $node_reftype='';
	foreach my $rn (@mrml_id_list){
	    if ( defined $rn ) {
		if (my(@vars)=$rn =~ /[\s]*([[:alnum:]]+)[:]/) {
		    print("name colon\n");
#		    $node_reftype=$1;
		    #dump(@vars);
		} else { #we're a node id lets find the mmrl node typel
		    $rn =~ s/[\s:]//gx;# remove spaces or colons from the text
		    print("id=$rn\n");
		    my ($snode)=mrml_find_by_id($mrml_tree,$rn);
		    my ($mrml_type) = $rn =~ /vtkMRML(.*?)Node/x;
#		    if ( ! defined $nodelinks{$node_reftype}) {# clever way to build hierarchy hash on fly. 
#			$nodelinks{$node_reftype}=(); 
#		    }
		    if ( ! defined $mrml_refs{$mrml_type}) {# clever way to build hierarchy hash on fly. 
			$mrml_refs{$mrml_type}=();
			print("Adding mrml_type $mrml_type\n");
		    }
#		    push(@{$nodelinks{$node_reftype}},$rn);
		    push(@{$mrml_refs{$mrml_type}},$rn);
		    push(@all_nodes,$rn);
		    #my $max_id=$#{$mrml_refs{$mrml_type}};
		    @{$mrml_refs{$mrml_type}}=uniq(@{$mrml_refs{$mrml_type}});
		    #print("uniq removed ".($max_id-$#{$mrml_refs{$mrml_type}})." elements\n");

		    if ( 1 ) {
		    my $mrml_subrefs=mrml_get_refs($mrml_tree,$snode);
		    #print("dump_subrefs\n");
		    #dump(%{$mrml_subrefs});
		    for my $sub_mrml_type (keys(%{$mrml_subrefs})){
			print("ids=".join(" ",@{$mrml_subrefs->{$sub_mrml_type}})."\n");
			#my ($sub_mrml_type) = $rn =~ /vtkMRML(.*?)Node/x;
			if ( ! defined $mrml_refs{$sub_mrml_type}) {# clever way to build hierarchy hash on fly. 
			    print("Adding mrml_type $sub_mrml_type\n");
			    $mrml_refs{$sub_mrml_type}=();
			}
			push(@{$mrml_refs{$sub_mrml_type}},@{$mrml_subrefs->{$sub_mrml_type}});
			push(@all_nodes,@{$mrml_subrefs->{$sub_mrml_type}});
			#my $max_id=$#{$mrml_refs{$sub_mrml_type}};
			@{$mrml_refs{$sub_mrml_type}}=uniq(@{$mrml_refs{$sub_mrml_type}});
			#print("uniq removed ".($max_id-$#{$mrml_refs{$sub_mrml_type}})." elements\n");
		    }
		    }
		    
		}
	    }  else {
		#for whatever reason we end up with one undefined at the end of theses lists every time.
		#print("somehow this wasnt defined...\n");
	    }
	}
	}
    }
    
    return \%mrml_refs;
}

sub mrml_node_diff {
    my ( $mrml_ref1, $mrml_ref2) =@_;

    my @mrml_keys=keys %{$mrml_ref1};
#    print("found ".($#mrml_keys)." attrs to compare");
    my $diff_count=0;
    my @diff_message;
    for my $attr (@mrml_keys) {
	#print("check $attr\n");
	if ( ! defined $mrml_ref2 ->{$attr} ) {
	    $diff_count++;
	    #print("undef");
	    push(@diff_message,"mrml_ref1($mrml_ref1->{name}) $attr not found in mrml_ref2($mrml_ref1->{name})");
	} elsif ($mrml_ref1->{$attr} ne $mrml_ref2->{$attr} ) { 
	    $diff_count++;
	    push(@diff_message,"attr  $attr differ : ".${mrml_ref1}->{$attr}." ,\t ".${mrml_ref2}->{$attr}."");
	} else {
	    #print("same! $mrml_ref1->{$attr} eq $mrml_ref2->{$attr} \n")
	    
	}

    }
    if ($#diff_message>-1){
	print("found differences: \n\t".join("\n\t",@diff_message)."\n");
    }
    return $diff_count;
}


sub mrml_write { 

    my ($data_struct_ref,$file)=@_;
    my($itxt,$i_level,$format)=('  ',0,'mrml');
     
    my $mrml_string=mmrl_to_string($data_struct_ref,$itxt,$i_level,$format);
    return ;
}
sub isfilehandle { 
    my ($FH)=@_;
    if (! defined $FH) { print("UNDEF_FH");return 0;}
    my $reft=ref($FH);
    #print($reft);
    #return 0;
    if ( $reft =~ /IO|GLOB|HASH/x || $FH =~ /GLOB/) {
	#print(".");
	return 1;
    } else { 
	return 0;
    }
}

sub mrml_to_file { # ( $hash_ref,$indentext,$indent_level,$format,$pathtowrite ) 
###
    use Scalar::Util qw(looks_like_number);

    my ($data_struct_ref,$itxt,$i_level,$format,$open_tag,$FH)=@_;
    if(! defined $itxt ) { $itxt='  ';}
    if(! defined $i_level ) { $i_level=0} else { $i_level++};
    if(! defined $format ) { $format='';}
    if(! defined $open_tag) { $open_tag='';}
    my $FH_close_bool=0;
    my $file;
    if(! defined $FH ) {
	exit("no file or file handle specified\n");
    } elsif ( ! isfilehandle($FH) ) { 
	$file=$FH;
	if( $file !~ /GLOB/ ) {
	    undef $FH;
	    open $FH, ">","$file" or die ;
	    $FH_close_bool=1;
	} else {
	    warn "Filename reported glob! this is not ok!\n";
	    return;
	    #die "Filename reported glob! this is not ok!\n";
	}
    } elsif ( isfilehandle($FH) )  { 
	#print("ISHANDLE");
    } else { 
	exit("bad path for file, or broken filehandle");
    }
    #my $debug_val=66;
    my $indent=$itxt;
    ### expand indent to level, we dont include i_level because we start with one indent.
    for (my $ind=0;$ind<$i_level;$ind++) {
	$indent=$indent.$itxt; 
    }
    debugloc();
#    printd(75,"Data_Struct_Ref:<$data_struct_ref>\n");
    my $reftype=ref($data_struct_ref); 
    if ( ! $reftype ) {
	$reftype='NOTREF';
    }
    # expected structure hashref->HASHOFNODETYPES->ARRAYOFELEMENTS->HASHOFATTRIBUTES
    my $delete_parts=0;
    if ( 1 ) { $delete_parts=0;}
	
    # expect a full mrml tree to print.
    if( $reftype eq "HASH" ) {
	#print( "$indent\{\n");
	my $pc=0;

#	while (keys %{$data_struct_ref} ) { 
	my $sc_count=0;
	my $attr_count=0;
	for my $k (keys %{$data_struct_ref}){
	    my $kreftype=ref($data_struct_ref->{$k});		
	    $attr_count++;
	    if ( $kreftype eq 'SCALAR' ){
		#mrml_to_file($d_ref,$itxt,$i_level,$format,$open_tag);
		print("$k=\"${$data_struct_ref->{$k}}\"   ") if ($debug_val>=65);
		print $FH ( "$k=${$data_struct_ref->{$k}}   "); 
		delete $data_struct_ref->{$k} if ( $delete_parts) ;
		$sc_count++;
	    } elsif ( ! $kreftype ) { 
		print("$k=\"$data_struct_ref->{$k}\"   ") if ($debug_val>=65);
		print $FH ( "$k=\"$data_struct_ref->{$k}\"   "); 
		delete $data_struct_ref->{$k} if ( $delete_parts) ;
		$sc_count++;
	    }
	}
	#if ( $sc_count>0) {#this prints too often
	#if ( $sc_count == $attr_count ) {#if all scalars, or if no attribs we should print close?
	if ( $open_tag ne '' ) {#this prints too often
	    print("\>\n")if ($debug_val>=65);
	    print $FH ( "\>");
	} # end attribs mrml , or does it...
	for my $k (keys %{$data_struct_ref}){
	    my $kreftype=ref($data_struct_ref->{$k});

	    if ( $kreftype eq 'HASH' ){
		print("$indent<$k\n") if ($debug_val>=65);
		print $FH ( "$indent<$k\n" ); 
		#$FH=$FH.mrml_to_file($data_struct_ref->{$k},$itxt,$i_level,$format,$k,$FH);
		mrml_to_file($data_struct_ref->{$k},$itxt,$i_level,$format,$k,$FH);
		#            ($data_struct_ref,      $itxt,$i_level,$format,$open_tag,$FH)=@_;
		delete $data_struct_ref->{$k} if ( $delete_parts) ;
		print("$indent\></$k\>\n") if ($debug_val>=65);
		#print $FH ( "$indent\></$k\>\n"); 
		print $FH ( "$indent\</$k\>\n"); 
	    }
	}

	for my $k (keys %{$data_struct_ref}){
	    my $kreftype=ref($data_struct_ref->{$k});		
	    if ( $kreftype eq 'ARRAY' ){
		#print("ARRAY:$k\n") if ($debug_val>=65);
		foreach (@{$data_struct_ref->{$k}}) {
		    print("$indent<$k\n") if ($debug_val>=65);
		    print $FH ( "$indent<$k\n"); 
		    #$FH=$FH.mrml_to_file($_,$itxt,$i_level,$format,$k,$FH);
		    mrml_to_file($_,$itxt,$i_level,$format,$k,$FH);
		    #($data_struct_ref,$itxt,$i_level,$format,$open_tag,$FH)=@_;
		    print("$indent\></$k\>\n") if ($debug_val>=65);
		    #}print $FH ( "$indent\></$k\>\n"); 
		    print $FH ( "$indent\</$k\>\n"); 
		}
		delete $data_struct_ref->{$k} if ( $delete_parts) ;
	    }
	}

#	}
    }
    if ( $FH_close_bool ){
	close $FH;
	print("Finished writing $file.\n");
    }
    return 0;
}



sub mrml_to_string { # ( $hash_ref,$indentext,$indent_level,$format,$pathtowrite ) 
###
    use Scalar::Util qw(looks_like_number);

    my ($data_struct_ref,$itxt,$i_level,$format,$open_tag,$xml_string)=@_;
    if(! defined $itxt ) { $itxt='  ';}
    if(! defined $i_level ) { $i_level=0} else { $i_level++};
    if(! defined $format ) { $format='';}
    if(! defined $open_tag) { $open_tag='';}
    if(! defined $xml_string) { $xml_string=''; }
    #my $debug_val=66;
    my $indent=$itxt;
    ### expand indent to level, we dont include i_level because we start with one indent.
    for (my $ind=0;$ind<$i_level;$ind++) {
	$indent=$indent.$itxt; 
    }
    debugloc();
#    printd(75,"Data_Struct_Ref:<$data_struct_ref>\n");
    my $reftype=ref($data_struct_ref); 
    if ( ! $reftype ) {
	$reftype='NOTREF';
    }
    # expected structure hashref->HASHOFNODETYPES->ARRAYOFELEMENTS->HASHOFATTRIBUTES
    my $delete_parts=0;
    if ( 1 ) { $delete_parts=0;}
	
    # expect a full mrml tree to print.
    if( $reftype eq "HASH" ) {
	#print( "$indent\{\n");
	my $pc=0;

#	while (keys %{$data_struct_ref} ) { 
	my $sc_count=0;
	for my $k (keys %{$data_struct_ref}){
	    my $kreftype=ref($data_struct_ref->{$k});		
	    if ( $kreftype eq 'SCALAR' ){
		#mrml_to_string($d_ref,$itxt,$i_level,$format,$open_tag);
		print("$k=\"${$data_struct_ref->{$k}}\"   ") if ($debug_val>=65);
		$xml_string=$xml_string."$k=${$data_struct_ref->{$k}}   ";
		delete $data_struct_ref->{$k} if ( $delete_parts) ;
		$sc_count++;
	    } elsif ( ! $kreftype ) { 
		print("$k=\"$data_struct_ref->{$k}\"   ") if ($debug_val>=65);
		$xml_string=$xml_string."$k=\"$data_struct_ref->{$k}\"   ";
		delete $data_struct_ref->{$k} if ( $delete_parts) ;
		$sc_count++;
	    }
	}
	if ( $sc_count>0) {print("\>\n")if ($debug_val>=65);$xml_string=$xml_string."\>\n";} # end attribs mrml
	for my $k (keys %{$data_struct_ref}){
	    my $kreftype=ref($data_struct_ref->{$k});

	    if ( $kreftype eq 'HASH' ){
		print("$indent<$k\n") if ($debug_val>=65);
		$xml_string=$xml_string."$indent<$k\n";
		$xml_string=$xml_string.mrml_to_string($data_struct_ref->{$k},$itxt,$i_level,$format,$k,$xml_string);
		delete $data_struct_ref->{$k} if ( $delete_parts) ;
		print("$indent\></$k\>\n") if ($debug_val>=65);
		$xml_string=$xml_string."$indent\></$k\>\n";
	    }
	}

	for my $k (keys %{$data_struct_ref}){
	    my $kreftype=ref($data_struct_ref->{$k});		
	    if ( $kreftype eq 'ARRAY' ){
		#print("ARRAY:$k\n") if ($debug_val>=65);
		foreach (@{$data_struct_ref->{$k}}) {
		    print("$indent<$k\n") if ($debug_val>=65);
		    $xml_string=$xml_string."$indent<$k\n";
		    $xml_string=$xml_string.mrml_to_string($_,$itxt,$i_level,$format,$k,$xml_string);
		    print("$indent\></$k\>\n") if ($debug_val>=65);
		    $xml_string=$xml_string."$indent\></$k\>\n";
		}
		delete $data_struct_ref->{$k} if ( $delete_parts) ;
	    }
	}

#	}
    }

return $xml_string;
}

=item mrml_to_string

displays an entire more complex data structure "prettily" from reference structure

=cut
###
sub mrml_to_string1 { # ( $hash_ref,$indentext,$indent_level,$format,$pathtowrite ) 
###
    use Scalar::Util qw(looks_like_number);
    my ($data_struct_ref,$itxt,$i_level,$format,$open_tag)=@_;
    if(! defined $itxt ) { $itxt='  ';}
    if(! defined $i_level ) { $i_level=0} else { $i_level++};
    if(! defined $format ) { $format='';}
    if(! defined $open_tag) { $open_tag='';}
    my $indent=$itxt;
    my $xml_string='';
    ### expand indent to level, we dont include i_level because we start with one indent.
    for (my $ind=0;$ind<$i_level;$ind++) {
	$indent=$indent.$itxt; 
    }
    debugloc();
    printd(75,"Data_Struct_Ref:<$data_struct_ref>\n");
    my $reftype=ref($data_struct_ref); 
    if ( ! $reftype ) {
	$reftype='NOTREF';
    }
    # expected structure hashref->HASHOFNODETYPES->ARRAYOFELEMENTS->HASHOFATTRIBUTES
    if ( 1 ) { 
	# expect a full mrml tree to print.
	
	if( $reftype eq "HASH" ) {
	    #print( "$indent\{\n");
	    my $pc=0;
	    
	    my @s_refs;
	    my @a_refs;
	    my %h_refs;

	    foreach my $key (keys %{$data_struct_ref} ) {#sort 
		my $kreftype=ref($data_struct_ref->{$key});
		if ( ! $kreftype ) {
		    $kreftype='NOTREF';
		}
		if ( $kreftype eq 'ARRAY' ) {
		    push(@a_refs,$data_struct_ref->{$key});
		} elsif ( $kreftype eq 'HASH'){
		    $h_refs{$key}=$data_struct_ref->{$key};
		    
		} elsif ( $kreftype eq 'SCALAR' ){
		    push(@s_refs,$data_struct_ref->{$key});
		} elsif (  $kreftype eq 'NOTREF'){
		    push(@s_refs,\$data_struct_ref->{$key});
		} else { 
		    #mrml_to_string($,$itxt,$i_level,$format,$open_tag);
		    print("$key not known ref($kreftype)");
		}
	    }
	    print("s:".($#s_refs+1)."a:".($#a_refs+1)."h:".((keys %h_refs)+1)."\n");
	    if ( 1 ) { 
		foreach my $d_ref ( @s_refs) {
		    #print("<$open_tag");
		    mrml_to_string($d_ref,$itxt,$i_level,$format,$open_tag);
		}
		foreach my $h_key ( keys %h_refs) {
		    #print("$indent\<$open_tag");
		    my $d_ref=$h_refs{$h_key};
		    mrml_to_string($d_ref,$itxt,$i_level,$format,$h_key);
		}
		foreach my $d_ref ( @a_refs) {
		    #mrml_to_string($d_ref,$itxt,$i_level,$format,$open_tag);
		}


	    } else {
		foreach my $key (keys %{$data_struct_ref} ) {#sort 
		    #if any of my children are arrays then i'm done printing myself.
		    my $kreftype=ref($data_struct_ref);
		    if ( $kreftype eq 'ARRAY' ){$pc=1;}#maybe we need to handle in order, scalar's first, then hashes?
		}
		
		foreach my $key (keys %{$data_struct_ref} ) {#sort 
		    print( "$indent\<$key ");
		    if ($pc ){
			print("\>");
		    }
		    mrml_to_string($data_struct_ref->{$key},$itxt,$i_level,$format,$key);
		    if ( ! $pc) {print("$indent\>\</$key\>\n");}
		}
	    }
	    #print( "$indent}\n");
	} elsif( $reftype eq "ARRAY" ) {
	    print("$indent");
	    foreach ( @{$data_struct_ref} ) {
		#mrml_to_string($_,$itxt,$i_level,$format);
		#print("$indent\n");	
	    }

	} elsif( ( $reftype eq "SCALAR"|| $reftype eq 'NOTREF' ) && $format ne 'noleaves' ) {
	    #print( "SCALAR\n"); if($text_fid>-1) { print($text_fid  "SCALAR\n"); }
	    my $value=$data_struct_ref;
	    if ( $reftype eq 'SCALAR') {
		$value=${$data_struct_ref};
	    }	
	    if ( defined $value ) { 
		print( "$open_tag=$value   ");# if($text_fid>-1) { print($text_fid  "$value.\n"); }
	    } else { 
		print("UNDEF \n");
	    }
	} elsif( $reftype eq "CODE" ) {
	    print( $indent.$reftype."\n");# if($text_fid>-1) { print($text_fid  $indent.$reftype."\n"); }
	} else {
	    print( "REFTYPEUNKNOWN\n");# if($text_fid>-1) { print($text_fid  "REFTYPEUNKNOWN\n"); }
	}
	
    } else {
    if( $reftype eq "HASH" ) {
	#print( "$indent\{\n");
	foreach my $key (keys %{$data_struct_ref} ) {#sort 
	    #print( "$indent\<$key ");
	    mrml_to_string($data_struct_ref->{$key},$itxt,$i_level,$format,$key);
	    #print("$indent\>\</$key\>\n");
	}
	#print( "$indent}\n");
    } elsif( $reftype eq "ARRAY" ) {
	print("$indent\<$open_tag   ");
	foreach ( @{$data_struct_ref} ) {
	    mrml_to_string($_,$itxt,$i_level,$format,$open_tag);
	}
	print("\>\</$open_tag\>\n");	

    } elsif( ( $reftype eq "SCALAR"|| $reftype eq 'NOTREF' ) && $format ne 'noleaves' ) {
	#print( "SCALAR\n"); if($text_fid>-1) { print($text_fid  "SCALAR\n"); }
	my $value=$data_struct_ref;
	if ( $reftype eq 'SCALAR') {
	    $value=${$data_struct_ref};
	}	
	if ( defined $value ) { 
	    print( "$open_tag = \"$value\"   ");# if($text_fid>-1) { print($text_fid  "$value.\n"); }
	} else { 
	    print("UNDEF \n");
	}
    } elsif( $reftype eq "CODE" ) {
	print( $indent.$reftype."\n");# if($text_fid>-1) { print($text_fid  $indent.$reftype."\n"); }
    } else {
	print( "REFTYPEUNKNOWN\n");# if($text_fid>-1) { print($text_fid  "REFTYPEUNKNOWN\n"); }
    }
    }
    return $xml_string;
}

sub mrml_types { 
    my ($mrml_tree,@any)=@_;
    #return atrib hash of mrml node.
    if ( defined $mrml_tree->{"MRML"} && keys %{$mrml_tree} <=1  ) {
	$mrml_tree=$mrml_tree->{"MRML"};
    }
    return keys %{$mrml_tree};
    
}


# -------------
sub xml_read2 {
# -------------
    my ( $xml_file)=@_;
    #use XML::Simple qw(XMLin);
    require XML::Simple;
    XML::Simple->import(qw(XMLin));
    #use File::Slurp qw(read_file);
    require File::Slurp;
    File::Slurp->import( qw(read_file));
    require Data::Dumper;
    Data::Dumper->import(qw(Dumper)); 
    print Dumper XMLin scalar(read_file $xml_file),
    KeyAttr => undef, ForceArray => 1, StrictMode => 1;
    #Instead, learn XPath and access the elements you actually need:
}

# -------------
sub xml_read3 {
# -------------
    my ( $xml_file)=@_;
    use XML::LibXML qw();
    my $xml = XML::LibXML->load_xml(location => $xml_file);
    for ($xml->findnodes('//entry[@name="cpd:C00103"]')) {
	print $_->getAttribute('link');
    }
}


=item display_complex_data_structure

displays an entire more complex data structure "prettily" from reference structure

=cut
###
sub display_complex_data_structure { # ( $hash_ref,$indentext,$indent_level,$format,$pathtowrite ) 
###
    use Scalar::Util qw(looks_like_number);
    my ($data_struct_ref,$itxt,$i_level,$format,$file)=@_;
    if(! defined $itxt ) { $itxt='  ';}
    if(! defined $i_level ) { $i_level=0} else { $i_level++};
    if(! defined $format ) { $format='';}
    my $indent=$itxt;
    ### expand indent to level, we dont include i_level because we start with one indent.
    for (my $ind=0;$ind<$i_level;$ind++) {
	$indent=$indent.$itxt; 
    }
    debugloc();
#    my $value="test";
    printd(75,"Data_Struct_Ref:<$data_struct_ref>\n");
    #printd(55,"keys @hash_keys\n");
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
    my $reftype=ref($data_struct_ref); 
    if ( ! $reftype ) {
	$reftype='NOTREF';
    }
    
    if( $reftype eq "HASH" ) {
	print( "$indent\{\n");
	foreach my $key (keys %{$data_struct_ref} ) {#sort 
	    print( "$indent$key = ");
	    display_complex_data_structure($data_struct_ref->{$key},$itxt,$i_level,$format);
	}
	print( "$indent}\n");
    } elsif( $reftype eq "ARRAY" ) {
	print("\[");	
	foreach ( @{$data_struct_ref} ) {
	    display_complex_data_structure($_,$itxt,$i_level,$format);
	}
	print("$indent\]\n");
    } elsif( ( $reftype eq "SCALAR"|| $reftype eq 'NOTREF' ) && $format ne 'noleaves' ) {
	#print( "SCALAR\n"); if($text_fid>-1) { print($text_fid  "SCALAR\n"); }
	my $value=$data_struct_ref;
	if ( $reftype eq 'SCALAR') {
	    $value=${$data_struct_ref};
	}	
	if ( defined $value ) { 
	    print( "$value \n");# if($text_fid>-1) { print($text_fid  "$value.\n"); }
	} else { 
	    print("UNDEF \n");
	}
    } elsif( $reftype eq "CODE" ) {
	print( $indent.$reftype."\n");# if($text_fid>-1) { print($text_fid  $indent.$reftype."\n"); }
    } elsif( defined $reftype && $reftype ne '' ) {
	print( "REFTYPEUNKNOWN:$reftype.\n");# if($text_fid>-1) { print($text_fid  "REFTYPEUNKNOWN\n"); }
    } else {
	print("NOT_REF\n");
    } 

    if ( $text_fid > -1 && -f $file  ){
        close $text_fid;
    }
    return ;

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

# -------------
sub remove_dot_suffix {
# -------------
  my ($path) = @_;
  my @dotless = split('\.', "$path");
  #@dotless = split /\./, $path;  #changed to be easier to read by prevent emacs from breadking code highlighting, 
  my $suffix = pop @dotless;
  my $suffix_less = join('.', @dotless);
  #my  $suffix_less = join /\./,@dotless;  #changed to be easier to read by prevent emacs from breadking code highlighting, 
  if ($suffix_less eq '') {
    print "couldnt get suffix off $path: $suffix_less dot $suffix\n";
    error_out( "couldnt get suffix off $path: $suffix_less dot $suffix");
  } 
  return ($suffix_less);
}

# -------------
sub depath_annot {
# -------------
  my ($command_line) = @_;
  my $r = depath($command_line);
  return ("Simplified:  $r"); # add some text that makes it inexecutable
}

# -------------
sub depath {
# -------------
  my ($command_line) = @_;
  # remove the path info from every element in a command line

  my @l = split /\s/, $command_line;
  my $r = "";
  foreach my $t (@l) {
     my @d = split '/', $t; 
     my $last = pop @d;
     $r .= "$last ";
  }
  chomp $r; # off last space
  return ($r);
}

# -------------
sub defile {
# -------------
  my ($path) = @_;
  # remove the file from a path, return the path  

  my @l = split '/', $path;
  pop @l;
  my $defiled = join '/', @l;
  return ($defiled);
}

# ------------------
sub fileparts { 
# ------------------
# ala matlab file parts, take filepath, return path name ext
    my ($fullname,$ver) = @_;
    if( ! defined $ver){
	$ver=1;
    }
    
    use File::Basename;
#    ($name,$path,$suffix) = fileparse($fullname,@suffixlist);
    my ($name,$path,$suffix) = fileparse($fullname,qr/\.([^.].*)+$/);#qr/\.[^.]*$/)
    if ( ! defined $fullname || $fullname eq "") { 
	
	return("","","");
    }
    if ($ver ==3){
	($name,$path,$suffix) = fileparse($fullname,qr/\.[^.]*$/);
    }
    if ($ver == 1) {
	funct_obsolete("fileparts","basename for name, dirname for dir");
    	return($name,$path,$suffix);
    } else {
	if ( $ver !=2 && $ver !=3) {
	    funct_obsolete("fileparts","1 for bad version, 2 for correct matlab emulation,3 for matlab emulation with single trailing file extension.");
	}
	return($path,$name,$suffix);
    }
}

# ------------------
sub funct_obsolete {
# ------------------
# simple function to print that we've called an obsolete function
    my ($funct_name,$new_funct_name)=@_;
    print("\n\nWARNING: obsolete function called, <${funct_name}>, should change call to <${new_funct_name}>\n\n\n");
    sleep(1);
}


1;
