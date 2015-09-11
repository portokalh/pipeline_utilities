#pipeline_utilites.pm
#
# utilities for pipelines including matlab calls from perl 
# should probably split up into separate library functions to make 
# the distinctions easier. 
# propose, a log_utilities, maybe a matlab_utilities, maybe an external call utilities
#
# created 09/10/15  Sally Gewalt CIVM
#                   based on t2w pipeline  
# 110308 slg open_log returns log path
# 130731 james, added new function new_get_engine_dependencies, to replace that chunk of code used all the damn time.
#               takes an output identifier, and an array of required values in the constants file to be checked. 
#               should add a standard headfile settings file for the required values in an engine_dependencie headfile 
#               returns the three directories  in work result, outhf_path, and the engine_constants headfile.
# 140717 added exporter line with list of functions
# 141125 moved registration.pm to here, modified as necessary. Also added sbath capabilities for when running on cluster. BJA
# be sure to change version:
my $VERSION = "141125";

my $log_open = 0;
my $pipeline_info_log_path = "UNSET";

my @outheadfile_comments = ();  # this added to by log_pipeline_info so define early
#my $BADEXIT = 1;
#my $debug_val = 5;
use File::Path;
use POSIX;
#use strict; #temporarily turned off for sub cluster_exec
use warnings;
use English;
#use seg_pipe;
use Getopt::Long qw(GetOptionsFromString); # For use with antsRegistration_memory_estimator

no warnings qw(uninitialized bareword);

use vars qw($HfResult $BADEXIT $GOODEXIT $test_mode $debug_val $valid_formats_string);
$valid_formats_string = 'hdr|img|nii';


if (! $debug_val) {
    $debug_val = 5;
}
my $PM="pipeline_utilities";
use civm_simple_util qw(load_file_to_array write_array_to_file);

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
make_matlab_command_V2
rp_key_insert
make_matlab_command_V2_OBSOLETE
execute
execute_heart
execute_indep_forks
executeV2
start_pipe_script
load_engine_deps
make_process_dirs
new_get_engine_dependencies
make_list_of_files
my_ls
writeTextFile
remove_dot_suffix
depath_annot
depath
defile
fileparts
funct_obsolete
create_transform
apply_affine_transform
apply_tranform
cluster_exec
cluster_check
execute_log
cluster_wait_for_jobs
cluster_check_for_jobs
get_nii_from_inputs
compare_headfiles
symbolic_link_cleanup
headfile_list_handler
find_temp_headfile_pointer
headfile_alt_keys
data_double_check
antsRegistration_memory_estimator
format_transforms_for_command_line
get_bounding_box_from_header
read_refspace_txt
write_refspace_txt
compare_two_reference_spaces
hash_summation
memory_estimator
make_identity_warp
get_spacing_from_header
get_bounding_box_and_spacing_from_header
get_slurm_job_stats
write_stats_for_pm
convert_time_to_seconds
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
   open PIPELINE_INFO, ">$pipeline_info_log_path" or die "Can't open pipeline_info file";
   my $time = scalar localtime;
   print("# Logfile is: $pipeline_info_log_path\n");
   $log_open = 1;

   log_info(" Log opened at $time.");
   return($pipeline_info_log_path);
}

# -------------
sub close_log {
# -------------
  my ($Hf) = @_;
  my $time = scalar localtime;
  if ($log_open) { 
    log_info("close at $time");
    close(PIPELINE_INFO);
  }
  else {
    print ("Close at $time");
  }
  $log_open = 0;
  foreach my $comment (@outheadfile_comments) {
       $Hf->set_comment($comment);
  }
  print "result logfile is: $pipeline_info_log_path\n";
}

# -------------
sub log_info {
# -------------
   my ($log_me,$verbose) = @_;
   if (! defined $verbose) {
       $verbose = 1;
   }

   if ($log_open) {
     # also write this info to headfile later, so save it up
     my $to_headfile = "# PIPELINE: " . $log_me;
     push @outheadfile_comments, "$to_headfile";  

     # show to user:
     if ($verbose) {
	 print( "#LOG: $log_me\n");
     }
     # send to pipeline file:
     print( PIPELINE_INFO "$log_me\n");
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
  my ($msg,$verbose) = @_;

  if (! defined $verbose) {$verbose = 1;}

  # possible you may call this before the log is open
  if ($log_open) {
      my $exit_time = scalar localtime;
      log_info("Error cause: $msg",$verbose);
      log_info("Log close at $exit_time.");

      # emergency close log (w/o log dumping to headfile)
      close(PIPELINE_INFO);
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
  my ($msg,$verbose) = @_;

  if (! defined $verbose) {$verbose = 1;}

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
  
  if (! $verbose) {
      print "Errors have been logged\n";
  }
  close_log_on_error($msg,$verbose);

  my $hf_path='';
  if (defined $HfResult && $HfResult ne "unset") {
      $hf_path = $HfResult->get_value('headfile_dest_path');
      if($hf_path eq "NO_KEY"){ $hf_path = $HfResult->get_value('headfile-dest-path'); }
      if($hf_path eq "NO_KEY"){ $hf_path = $HfResult->get_value('result-headfile-path'); }
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
   my ($mfile_path, $function_call,$verbose) = @_;
   if (! defined $verbose) {$verbose = 1;}
   log_info("Matlab function call mfile created: $mfile_path",$verbose);
   log_info("  mfile contains: $function_call",$verbose);
   make_matlab_m_file_quiet($mfile_path,$function_call);
   return;
}

# -------------
sub make_matlab_m_file_quiet {
# -------------
#simple utility to save an mfile with a contents of function_call at mfile_path
   my ($mfile_path, $function_call) = @_;
   open MATLAB_M, ">$mfile_path" or die "Can't open mfile $mfile_path";
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
   my ($function_m_name, $args, $short_unique_purpose, $Hf,$verbose) = @_;
# short_unique_purpose is to make the name of the mfile produced unique over the pipeline (they all go to same dir)
   if (! defined $verbose) {$verbose =1;}
   my ($work_dir)   = headfile_alt_keys($Hf,'dir_work','dir-work','work_dir');
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
   my ($function_m_name, $args, $short_unique_purpose, $work_dir, $matlab_app,$logpath,$matlab_opts,$verbose) = @_;
   print("make_matlab_command:\n\tengine_matlab_path:${matlab_app}\n\twork_dir:$work_dir\n") if($debug_val>=25);
   if (! defined $verbose) {$verbose =1;}  
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

   make_matlab_m_file ($mfile_path, $function_call,$verbose); # this seems superfluous.
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
   my $fifo_mode=`hostname -s`=~ "civmcluster1" ? 0 : 1; # Debug--change back to civmcluster1
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
    # find app that is running, with stdin_fifo, and logpath, these should all show up in a ps call.
    my $stopped=-1;
    my $cmd="fuser $logpath 2>&1"; # may work as a way to find the process attached to a given log, which should work well.
    print STDERR ("FIFO_Stop: $stdin_fifo...\n");
    #print STDERR ($cmd."\n" );
    my $o_string = `$cmd `;
    chomp($o_string);
    #print STDERR ( "\tfuser_string:$o_string\n");
    my @out=split("\n",$o_string);
    chomp(@out);
    @out=split(':',$out[0]);
    #print STDERR ("\tfuser_out = ".join(',', @out)."\n");

    my $file_path=shift(@out);
    @out = split(' ',$out[0]);
    print STDERR ("\twatched_file = $file_path\n");
    for (my $on=0;$on<$#out;$on++){ 
	if ($out[$on]!~ m/[0-9]+/x ) {
	    shift(@out);
	    $on--;
	}
    }
    if ($#out>=0) {
	print STDERR ("PID's to kill.\n\t".join("\n\t",@out)."\n");
	if ( $#out>0 ) {
	    print STDERR ( "WARNING: More than one process attached to the watched file!\n NOTIFY JAMES \n");
	}
	$stopped=kill 'KILL',@out;
    } else {
	print STDERR ("No process open for $file_path.\n");
	$stopped=0;
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

    my @files = glob("$runno_headfile_dir/${runno}*.*.*"); # lists all files named $runnosomething.something.something. This should match any civm formated images, and only their images.
    my @first_files=grep (/^$runno_headfile_dir\/$runno.*[sim|imx][.][0]*[1][.].*$/x, @files ) ;
    if( $#first_files>0 ) {
	print STDERR "found files \n-> ".join ("\n-> ",@files)."\n";
	print STDERR "WARNING: \n";
	print STDERR "\tToo many 001 files found in archiveme\n";
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
    my @parts=split('\.',$firstfile);
    for(my $iter=0;$iter<3 ;$iter++) {
	$img_suffix = pop @parts;
    }
    $img_suffix=substr($img_suffix,-5,2);
    if ( 0 ){ #length suffix 
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
	my @fifo_registry_contents = <$fifo_registry/*>;
	for(my $fnum=0;$fnum<$#fifo_registry_contents;$fnum++) {
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

    my ($file) = @_;
    my $data_check=0;

    my ($n,$p,$ext) = fileparts($file);
    my $checksumfile=$p.$n.".md5";

    my @md5 = (file_checksum($file));
    my @stored_md5;
    if ( ! -e $checksumfile ) { 
	write_array_to_file($checksumfile,\@md5);
	$data_check=1;
    } else {
	load_file_to_array($checksumfile,\@stored_md5);
	if ( $stored_md5[0] eq $md5[0] ) { 
	    $data_check=1;
	    #print("GOOD! ($file:$md5[0])\n");
	} else {
	    print ("BADCHECKSUM! $md5[0]($file)") ;
	}
    }
    return $data_check;
}
# -------------
sub file_checksum {
# -------------
    # run checksum on file and return checksum result.
    my ($file) = @_;
    use Digest::MD5 qw(md5 md5_hex md5_base64); 
    open  my $data_fid, "<", "$file" or die "could not open $file";
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

    foreach my $c (@commands) {
	$i++;
	if ( cluster_check() ) {
	    # For running Matlab, run on Master Node for now until we figure out how to handle the license issue. Otherwise, run with SLURM
	    if ($c =~ /matlab/) {
		$c = $c;
	    } else {
		if ($custom_q == 1) {
		    $c = "srun -s --memory 20480 -p $my_queue ".$c;
		} else {
		    $c = "srun ".$c;
		}
		print("SLURM MODE ENGAGED\n");
	    }
	} else {
	    $c = $c;
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
    execute_log($do_it,$annotation,$single_command);

    if ($do_it) {
	$rc = system ($single_command);
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
  my @child;
  my $nforked=0;

  foreach my $c (@commands) {

        my $pid = fork();
        if ($pid) { # parent
          push(@child, $pid);
        } elsif ($pid == 0) { # child
                print "child fork $$\n";
                my $ret = execute_heart($do_it, $annotation, $c);
                #print "Forked child $$ finishes ret = $ret\n";
                exit 0;
        } else {
                die "couldn\'t fork: $!\n";
        }
        $nforked ++;
  }
  my $total_forks = $nforked;
  #print "All $nforked command forks made, parent to assure all childen have finished...\n";
# if i'm reading this loop right it will wait for each child in turn for it to finish, meaning it wont say anything until the first cihld finishes, and will report closed children in order of opening not in their order of closing, essentially it will hang on waitpid for the first kid to finish, then it will check the second, and so on until its' checked each child exaclty once. 
# suffice it to say, not the perfect loop for childre checkup, but certainly functional
  foreach (@child) {
        print "  parent checking/waiting on child pid $_ ...";
        my $tmp = waitpid($_, 0);
        $nforked -= 1;
        print "pid $tmp done, $nforked child forks left.\n";
  }
  print "Execute: waited for all $total_forks command forks to finish; fork queue size $nforked...zombies eliminated.\n";

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
# load local engine_deps, OR load an arbitrary one, return the engine constants headfile
    my ($engine) = @_;
    #required_values=engine==hostname -s
    #$engine=thishost.
    
    my @errors;
    my @warnings;
    use Env qw(PIPELINE_HOSTNAME PIPELINE_HOME WKS_SETTINGS WORKSTATION_HOSTNAME);
    

    # alternate way to get the path to the engine constants file
    #    if ( defined $WKS_SETTINGS) { $this_engine_constants_path = get_engine_constants_path($WKS_SETTINGS,$WORKSTATION_HOSTNAME); }

    
#    if (! defined($PIPELINE_HOSTNAME))       { push(@errors, "Environment variable WORKSTATION_HOSTNAME must be set."); }
    
    ### set the host
    if  ( ! defined($WORKSTATION_HOSTNAME)) { 
	print("WARNING: obsolete variable PIPELINE_HOSTNAME used.\n");
	$WORKSTATION_HOSTNAME=$PIPELINE_HOSTNAME;
    }
    if ( defined($engine)) { $WORKSTATION_HOSTNAME=$engine; };
    if (! defined($WORKSTATION_HOSTNAME)) { push(@warnings, "Environment variable WORKSTATION_HOSTNAME not set."); }
    
    ### set the dir
    my $engine_constants_dir;
    if ( ! defined($WKS_SETTINGS) ) { 
	if (! -d $PIPELINE_HOME)             { push(@errors, "unable to find $PIPELINE_HOME"); }
	print("WARNING: obsolete variable PIPELINE_HOME used to find dependenceis\n");
	$WKS_SETTINGS=$PIPELINE_HOME;
	$engine_constants_dir="$WKS_SETTINGS/dependencies";
    } else { 
      $engine_constants_dir="$WKS_SETTINGS/engine_deps";
    }
    
    if (! -d $engine_constants_dir)      { push(@errors, "$engine_constants_dir does not exist."); }
    
    ### set the file name
    my $engine_file =join("_","engine","$WORKSTATION_HOSTNAME","dependencies"); 
    my $engine_constants_path = "$engine_constants_dir/".$engine_file;
    if ( ! -f $engine_constants_path ) { 
	$engine_file=join("_","engine","$WORKSTATION_HOSTNAME","pipeline_dependencies");
	$engine_constants_path = "$engine_constants_dir/".$engine_file;
	print("WARNING: OBSOLETE SETTINGS FILE USED, $engine_file\n")
    }
    
    ### load engine_deps
    my $engine_constants = new Headfile ('ro', $engine_constants_path);
    if (! $engine_constants->check()) {
	push(@errors, "Unable to open engine constants file $engine_constants_path\n");
    }
    if (! $engine_constants->read_headfile) {
	push(@errors, "Unable to read engine constants from headfile form file $engine_constants_path\n");
    }
    
    return $engine_constants;
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
  my $local_result_dir  = "$BIGGUS_DISKUS/$identifier\-results";

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
  # make a list of all files in directory fitting template  # don't use unix ls for checks, since it can't bring back list of 512
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
  opendir THISDIR, $unixy_dir;
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
    my ($fullname) = @_;
    use File::Basename;
#    ($name,$path,$suffix) = fileparse($fullname,@suffixlist);
    my $gz='';
    if ($fullname =~ s/\.gz$//) {
	$gz=".gz";
    }
    my ($name,$path,$suffix) = fileparse($fullname,qr/.[^.]*$/);
    return($name,$path,$suffix.$gz);
}

# ------------------
sub funct_obsolete {
# ------------------
# simple function to print that we've called an obsolete function
    my ($funct_name,$new_funct_name)=@_;
    print("\n\nWARNING: obsolete function called, <${funct_name}>, should change call to <${new_funct_name}>\n\n\n");
    sleep(1);
}


# ------------------
sub create_affine_transform {
# ------------------
  my ($go, $xform_code, $A_path, $B_path, $result_transform_path_base, $ants_app_dir,$mod,$q,$r) = @_;

  my ($q_string,$r_string) = ('','');
  if ((defined $q) && ($q ne '')) {
      $q_string = "-q $q";
  }
  if ((defined $r) && ($r ne '')) {
      $r_string = "-r $r";
  }
  
  my $affine_iter="3000x3000x0x0";
  print " Test mode : ${test_mode}\n";
  if (defined $test_mode) {
      if ($test_mode==1) {
	  $affine_iter="1x0x0x0";
      }
  }
  my $cmd;
  if ($xform_code eq 'rigid1') {
      my $opts1 = "-i 0 --use-Histogram-Matching --rigid-affine true --MI-option 32x8000 -r Gauss[3,0.5]";
      my $opts2 = "--number-of-affine-iterations $affine_iter --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4 -v";  
      
      $cmd = "${ants_app_dir}antsRegistration -d 3 -r [$A_path,$B_path,1] ". 
	  "-m Mattes[$A_path,$B_path,1,32,random,0.3] -t rigid[0.1] -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 ".
	  " ${q_string} ${r_string} ".
	  " -u 1 -z 1 -o $result_transform_path_base --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4";
     
  } elsif ( $xform_code eq 'nonrigid_MSQ' ) {

      my $opts1 = "-i 0 ";
      my $opts2 = "--number-of-affine-iterations $affine_iter --affine-metric-type MSQ";  
     $cmd = "${ants_app_dir}antsRegistration -d 3 -r [$A_path,$B_path,1] ".
	 " -m MeanSquares[$A_path,$B_path,1,32,random,0.3] -t translation[0.1] -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 -l 1 ".
	 " -m MeanSquares[$A_path,$B_path,1,32,random,0.3] -t rigid[0.1]       -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 -l 1 ".
	 " -m MeanSquares[$A_path,$B_path,1,32,random,0.3] -t affine[0.1]      -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 -l 1 ".
	 " ${q_string} ${r_string} ".
	 "  -u 1 -z 1 -o $result_transform_path_base --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4";
  } elsif ($xform_code eq 'full_affine') {

     $cmd = "${ants_app_dir}antsRegistration -d 3 -r [$A_path,$B_path,1] ".
	 " -m Mattes[$A_path,$B_path,1,32,random,0.3] -t affine[0.1]      -c [$affine_iter,1.e-8,20] -s 4x2x1x0.5vox -f 6x4x2x1 -l 1 ".
	 " ${q_string} ${r_string} ".
	 "  -u 1 -z 1 -o $result_transform_path_base --affine-gradient-descent-option 0.05x0.5x1.e-4x1.e-4";

  }
  else {
      error_out("$mod create_transform: don't understand xform_code: $xform_code\n");
  }

  my @list = split '/', $A_path;
  my $A_file = pop @list;
  my $jid = 0;
  if ((cluster_check) && ($mod =~ /.*vbm\.pm$/ )) {
      my ($dummy1,$home_path,$dummy2) = fileparts($result_transform_path_base);
      my ($home_base,$dummy3,$dummy4) = fileparts($B_path);
      my @home_base = split(/[_-]+/,$home_base);
      my $Id_base = $home_base[0];
      my $Id= "${Id_base}_create_affine_registration";
      my $verbose = 2; # Will print log only for work done.
      $jid = cluster_exec($go, "create $xform_code transform for $A_file", $cmd,$home_path,$Id,$verbose);     
      if (! $jid) {
	  error_out("$mod create_transform: could not make transform: $cmd\n");
      }
  } else {
      if (! execute($go, "create $xform_code transform for $A_file", $cmd) ) {
	  error_out("$mod create_transform: could not make transform: $cmd\n");
      }
  }
 # my $transform_path = "${result_transform_path_base}Affine.txt"; # From previous version of Ants, perhaps?

  my $transform_path="${result_transform_path_base}0GenericAffine.mat";

  if (!-e $transform_path && $go && ($jid == 0)) {
    error_out("$mod create_transform: did not find result xform: $transform_path");
    print "** $mod create_transform $xform_code created $transform_path\n";
  }
  return($transform_path,$jid);
}

# ------------------
sub apply_affine_transform {
# ------------------

  my ($go, $to_deform_path, $result_path, $do_inverse_bool, $transform_path, $warp_domain_path, $ants_app_dir, $interp, $mod,$native_reference_space) =@_; 
  my $i_opt = $do_inverse_bool ? '-i' : ''; 
  if ($go) {
      print "i_opt: $i_opt\n";
  }

  if ((! defined $mod) || ($mod eq '')) {
      $mod = "registration_pm_living_in_pipeline_utilties.pm";
  }
  if ((! defined $native_reference_space) || ($native_reference_space eq '')) {
      $native_reference_space = 0; # Not sure if we want atlas space to be our default reference space.
  }

  my $reference='';
  my $i_opt1;

  if ($i_opt=~ m/i/) {
    $i_opt1=1;
    $reference=$warp_domain_path;
  } else {
    $i_opt1=0;
    $reference=$to_deform_path;
  } 
  
  if ($mod =~ /.*vbm\.pm$/ ) {
      if ($native_reference_space) {
       $reference=$to_deform_path;
      } else {
       $reference=$warp_domain_path;
      }
  }

  if ($go) {
      print "interp: $interp\n\n";
  }

  if ((! defined $interp) || ($interp eq '')) {
      $interp="LanczosWindowedSinc";
      $interp="Linear";
  } else {
      $interp="NearestNeighbor";
  }

  if ($go) {
      print "i_opt number: $i_opt1\n";
      print "interpolation: $interp\n";
      print "reference: $reference\n";
  }
  my $cmd="${ants_app_dir}antsApplyTransforms --float -d 3 -i $to_deform_path -o $result_path -t [$transform_path, $i_opt1] -r $reference -n $interp";

  if ($go) {
      print " \n";
      print "****applying affine registration:\n $cmd\n";
  }
  my @list = split '/', $transform_path;
  my $transform_file = pop @list;
  
  my $jid = 0;
  if  ((cluster_check) && ($mod =~ /.*vbm\.pm$/ )) {
      my ($dummy1,$home_path,$dummy2) = fileparts($transform_path);
      my ($home_base,$dummy3,$dummy4) = fileparts($to_deform_path);
      my @home_base = split(/[_-]+/,$home_base);
      my $Id_base = $home_base[0];
      my $Id= "${Id_base}_apply_affine_registration";
      my $verbose = 2; # Will print log only for work done.
      $jid = cluster_exec($go, "$mod: apply transform $transform_file", $cmd ,$home_path,$Id,$verbose);     
      if (! $jid) {
	  error_out("$mod apply_affine_transform: could not apply transform to $to_deform_path: $cmd\n");
      }
  } else {
      if (! execute($go, "$mod: apply_affine_transform $transform_file", $cmd) ) {
	  error_out("$mod apply_affine_transform: could not apply transform to $to_deform_path: $cmd\n");
      }
  }

  if (!-e $result_path  && $go && ($jid == 0)) {
    error_out("$mod apply_affine_transform: missing transformed result $result_path");
  }
  if ($go) {
      print "** $mod apply_affine_transform created $result_path\n";
  }
  
  return($jid);

}

# ------------------
sub apply_transform {
# ------------------
    funct_obsolete("apply_transform", "apply_affine_transform");

    apply_affine_transform(@_);
}


# ------------------
sub cluster_exec {
# ------------------
    my ($do_it,$annotation,$cmd,$work_dir,$Id,$verbose,$memory,$test,$node) = @_;
   # my $memory=25600;
    my $node_command=''; # Was a one-off ---> now turned on for handling diffeo identity warps.
 
    my $queue_command='';
    my $memory_command='';
    my $time_command = '';
    my $default_memory = 24870;#int(154000);# 40960; # This is arbitrarily set at 40 Gb at first, now 150 Gb for Premont study.
    if (! defined $verbose) {$verbose = 1;}

    if ($test) {
	$queue_command = "-p overload";
	$time_command = "-t 15";     
    } elsif ($custom_q == 1) {
	$queue_command = "-p $my_queue";
    }

    if (defined $node) {
	$node_command = "-w $node";
    }


    if (! defined $memory) {
	$memory_command = " --mem ${default_memory} ";
    } else {
	$memory_command = " --mem $memory ";
    }


    my $sharing_is_caring = ' -s ';  # Not sure if this is still needed.
    my ($batch_path,$batch_file,$b_file_name);
    my $msg = '';
    my $jid=1;
    if (! $test) {
	execute_log($do_it,$annotation,$cmd,$verbose);
    }
    if ($do_it) {
	$batch_path = "${work_dir}/sbatch/";
	$b_file_name = $Id.'.bash';
	$batch_file = $batch_path.$b_file_name;
	if (! -e $batch_path) {
	    mkdir($batch_path,0777);
	} 
	my $slurm_out_command = " --output=${batch_path}".'/slurm-%j.out ';
#	my $open_jobs_path = "${batch_path}/open_jobs.txt";

	open($Id,'>',$batch_file);
	print($Id "#!/bin/bash\n");
        print($Id 'echo \#'."\n");
	print($Id "$cmd \n");
	close($Id);

	my $test_size = -s $batch_file;
	my $no_escape = 1;
	my $num_checks = 0;
	my $flag = 0;
	while (($test_size < 30) && $no_escape) {
	    $num_checks++;
	    sleep(0.1);
	    $test_size = -s $batch_file;
	    if ($num_checks > 20) {
		$no_escape=0;
		$flag =1;
	    }
	}

	if ($flag) {
	    log_info("batch file: ${batch_file} does not appear to have been created. Expect sbatch failure.")
	}
	
	# this works, but alternate call might be nicer.
	my $bash_call = "sbatch ${slurm_out_command} ${sharing_is_caring} ${node_command} ${queue_command} ${memory_command} ${time_command} ${batch_file}";
	print "sbatch command is: ${bash_call}\n";
	($msg,$jid)=`$bash_call` =~  /([^0-9]+)([0-9]+)/x;
	if ( $msg !~  /.*(Submitted batch job).*/) {
	    $jid = 0;
	    error_out("Bad batch submit to slurm with output: $msg\n");
	    exit;
	}
    }

    if ($jid == 0) {
	print STDERR "  Problem:  system() returned: $msg\n";
	print STDERR "  * Command was: $cmd\n";
	print STDERR "  * Execution of command failed.\n";
	return 0;
    }
    if ($jid > 1) {
	print STDOUT " Job Id = $jid.\n";
	if ($batch_file ne '') {
	    my $new_name = $batch_path.'/'.$jid."_".$b_file_name;
	    print "batch_file = ${batch_file}\nnew_name = ${new_name};\n\n";
	    rename($batch_file, $new_name); 		
        }
    }
    return($jid);
}


# ------------------
sub cluster_check {
# ------------------
   if (`hostname -s` =~ /civmcluster1/) {
       return(1);
   } else {
       return(0);
   }
}


# ------------------
sub execute_log {
# ------------------
    ($do_it,$annotation,$command,$verbose)=@_;
    if (! defined $verbose) {$verbose = 1;}
    my $skip = $do_it ? "" : "Skipped ";
    my $info = $annotation eq '' ? ": " : " $annotation: "; 
    my $time = scalar localtime;
    my $msg = join '', $skip, "EXECUTING",$info, "--", $time , "--";
    my $cmsg = "   $command";
    if (($verbose == 2)) {
	if (! $do_it) {
	    $verbose = 0;
	} else {
	    $verbose = 1;
	}
    }
	    log_info($msg,$verbose);
	    log_info($cmsg,$verbose);
}

# ------------------
sub cluster_wait_for_jobs {
# ------------------
    my ($interval,$verbose,$sbatch_location,@job_ids)=@_;
   
    my $jobs = join(',',@job_ids);
    my $check_for_slurm_out = 1;

    if (! -d $sbatch_location) {
	$jobs=$sbatch_location.','.$jobs;
	$check_for_slurm_out = 0;
    }
    
    my $completed = 0;
    if ($jobs ne '') {
	print STDOUT "SLURM: Waiting for multiple jobs to complete";
	#print "jobs = $jobs\n\n"; ##	
	while ($completed == 0) {
	    if (`squeue -j $jobs -o "%i %t"` =~ /(CG|PD|R)/) {
		if ($verbose) {print STDOUT ".";}
		my $throw_error=0;
		if ($check_for_slurm_out) {
		    my @bad_jobs;
		    my $missing_files;
		    my @job_list=split(',',$jobs);
		    foreach my $job (@job_list) {
			#print "Job = $job\t"; ##
			if (`squeue -j $job -o "%i %t"` =~ /R/){   
			    my $slurm_out_file = "${sbatch_location}/slurm-${job}.out";
			    if (! -e $slurm_out_file) {
				$throw_error = 1;
				push(@bad_jobs,$job);
				$missing_files=$missing_files."${slurm_out_file}\n";
			    }
			}
		    }
		    
		    if ($throw_error) {
			my $bad_jobs=join(' ',@bad_jobs);
			my $bad_jobs_string = join('_',@bad_jobs);
			
			use civm_simple_util qw(whowasi whoami);	
			my $process = whowasi();
			my @split = split('::',$process);
			$process = pop(@split);
			log_info("sbatch existence error generated by process: $process\n");
			my $error_message ="UNRESOLVED ERROR! No slurm-out file created for job(s): ${bad_jobs}. Job will run but will not save output!\n".
			    "It is suspected that this is due to unhealthy nodes or a morbidly obese glusterspace.\n".
			    "Expected file:\n${missing_files} does not exist.\nCancelling bad jobs ${bad_jobs}.\n\n\n";
			my $time = time;			
			my $email_file="${sbatch_location}/Error_email_for_${time}.txt";
			
			my $time_stamp = "Failure time stamp = ${time} seconds since January 1, 1970 (or some equally asinine date).\n";
			my $subject_line = "Subject: cluster slurm out error.\n";

			
			my $email_content = $subject_line.$error_message.$time_stamp;
			`echo "${email_content}" > ${email_file}`;
			`sendmail -f $process.civmcluster1\@dhe.duke.edu rja20\@duke.edu < ${email_file}`;
			`scancel ${bad_jobs}`;
			log_info($error_message);
		    }
		}
		sleep($interval);
	    } else {
		$completed = 1;
		print STDOUT "\n";
	    }


	    











	}
    } else {
	$completed = 1;
    }
    return($completed);
}

sub cluster_check_for_jobs {
# ------------------
    my (@job_ids)=@_;
    my $jobs = join(',',@job_ids);
    my $completed = 0;
    if ($jobs ne '') {
	if (`squeue -j $jobs -o "%i %t"` =~ /(CG|PD|R)/) {
	    return(0);	
	} else {
	    return(1);
	}
    } else {
	return(1);
    }
    
}

# ------------------
sub get_nii_from_inputs {
# ------------------
# Update to only return hdr/img/nii/nii.gz formats.
# Case insensitivity added.
# Order of selection (using contrast = 'T2' and 'nii' as an example):
#        1)  ..._contrast.nii     S12345_T2.nii         but not...   S12345_T2star.nii 
#        2)  ..._contrast_*.nii   S12345_T2_masked.nii  but not...   S12345_T2star.nii or S12345_T2star.nii
#        3)  ..._contrast*.nii    S12345_T2star.nii  or S12345_T2star_masked.nii, etc
#        4)  Returns error if nothing matches any of those formats

    my ($inputs_dir,$runno,$contrast) = @_;
    my $error_msg='';
    
    if (-d $inputs_dir) {
	opendir(DIR, $inputs_dir);
	my @input_files_1= grep(/($runno).*_($contrast)\.(${valid_formats_string}){1}(\.gz)?$/i ,readdir(DIR));

	my $input_file = $input_files_1[0];
	if (($input_file eq '') || (! defined $input_file)) {
	opendir(DIR, $inputs_dir);
	my @input_files_2= grep(/($runno).*_($contrast)_.*\.(${valid_formats_string}){1}(\.gz)?$/i ,readdir(DIR));
	    $input_file = $input_files_2[0];
	    if (($input_file eq '') || (! defined $input_file)) {
		opendir(DIR, $inputs_dir);
		my @input_files_3= grep(/($runno).*_($contrast).*\.(${valid_formats_string}){1}(\.gz)?$/i ,readdir(DIR));
		$input_file = $input_files_3[0];
	    }
	}

	if ($input_file ne '') {
	    my $path= $inputs_dir.'/'.$input_file;
	    return($path);
	} else {
	    $error_msg="pipeline_utilities function get_nii_from_inputs: Unable to locate file using the input criteria:\n\t\$inputs_dir: ${inputs_dir}\n\t\$runno: $runno\n\t\$contrast: $contrast.\n";
	    return($error_msg);
	}
    } else {
	$error_msg="pipeline_utilities function get_nii_from_inputs: The input directory $inputs_dir does not exist.\n";
	return($error_msg);
    }
}

# ------------------
sub compare_headfiles {
# ------------------
    my ($Hf_A, $Hf_B, $include_or_exclude, @keys_of_note) = @_;
    my @errors=();
    my $error_msg = '';
    my $include = $include_or_exclude;
 


    foreach my $testHf ($Hf_A,$Hf_B) {	
	if (! $testHf->check()) { # It seems that it should be assumed that the headfile is coming checked already. If not, that aint on us!
	   # push(@errors, "Unable to open headfile referenced by ${testHf}\n");
	}
	if ( 0 ) {  # this causes errors for a reason which is un clear. Both headfiles have already been checked and read external to this call.
	    if (! $testHf->read_headfile) {
		push(@errors, "Unable to read contents from headfile referenced by ${testHf}\n");
	    }
	}
	if ($errors[0] ne '') {
	    $error_msg = join('\n',@errors);
	    return($error_msg);
      	}
    }
	
    my @key_array = ();
    if ($include) {
	@key_array = @keys_of_note;
    } else {
	my @A_keys = $Hf_A->get_keys;
	my @B_keys = $Hf_B->get_keys;;
	my @all_keys = keys %{{map {($_ => undef)} (@A_keys,@B_keys)}}; # This trick is from http://www.perlmonks.org/?node_id=383950.
	foreach my $this_key (@all_keys) {
	    my $pattern = '('.join('|',@keys_of_note).')';
	    if ($this_key !~ m/$pattern/) {
		push(@key_array,$this_key) unless (($this_key eq 'hfpmcnt') || ($this_key eq 'version_pm_Headfile'));
	    }
	}
    }

    if ($key_array[0] ne '') {
	foreach my $Key (@key_array) {
	    my $A_val = $Hf_A->get_value($Key);
	    my $B_val = $Hf_B->get_value($Key);
	    if ($A_val ne $B_val) {
		my $msg = "Non-matching values for key \"$Key\":\n\tValue 1 = ${A_val}\n\tValue 2 = ${B_val}\n";
		push (@errors,$msg);
	    }
	}
    }
  
    if ($errors[0] ne '') {
	$error_msg = join("\n",@errors);
	$error_msg = "Headfile comparison complete, headfiles are not considered identical in this context.\n".$error_msg."\n";
    }
    
    return($error_msg); # Returns '' if the headfiles are found to be "equal", otherwise returns message with unequal values.
}

# ------------------
sub symbolic_link_cleanup {
#
    my ($folder,$log) = @_;
    if (! defined $log) {$log=0;}
    if ($folder !~ /\/$/) {
	$folder=$folder.'/';
    }
    my $link_path;
    my $temp_path = "$folder/temp_file";
    if (! -d $folder) {
	print " Folder $folder does not exist.  No work was done to cleanup symbolic links in non-existent folder.\n";
	return;
    }
    opendir(DIR,$folder);
    my @files = grep(/.*/,readdir(DIR));
    foreach my $file (@files) {
	$file_path = "$folder/$file";
	if (-l $file_path) {
	    $link_path = readlink($file_path);
	    my ($dummy1,$link_folder,$dummy2)=fileparts($link_path);
	    my $action;
	    if ($link_folder ne $folder) {
		$action = "cp";
		# print "\$link_folder ${link_folder}  ne \$folder ${folder}\n";
	    } else {
		# print "\$link_folder ${link_folder}  eq \$folder ${folder}\n";
		$action = "mv";
	    }
	    my $echo = `${action} ${link_path} ${file_path}`;
	    if ($log) {
		my $annotation = "Cleaning up symbolic links.";
		my $command =  "${action} ${link_path} ${file_path}";
		$command = $command.$echo;
		execute(1,$annotation,$command,$verbose);
	    }
	}
    }

}


# ------------------
sub headfile_list_handler {
# ------------------
    my ($current_Hf,$key,$new_value,$invert) = @_;
    if (! defined $invert) { $invert = 0;}

    my $list_string = $current_Hf->get_value($key);
    if ($list_string eq 'NO_KEY') {
	$list_string = '';
    }

    my @list_array = split(',',$list_string);
   
    if ($invert) {
	push(@list_array,$new_value);
	#$list_string=$list_string.",".$new_value;
    } else {
	unshift(@list_array,$new_value);
	#$list_string=$new_value.",".$list_string;
    }

    $list_string = join(',',@list_array);
    $current_Hf->set_value($key,$list_string);
}
# ------------------
sub find_temp_headfile_pointer {
# ------------------
    my ($location) = @_;
    if (! -e  $location) {
	return(0);
    } else {
	opendir(DIR,$location);
	my @headfile_list = grep(/.*\.headfile$/ ,readdir(DIR));
	if ($#headfile_list > 0) {
	    error_out(" $PM: more than one temporary headfile found in folder: ${current_path}.  Unsure of which one accurately reflects previous work done.\n"); 
	}
	if ($#headfile_list < 0) {
	    print " $PM: No temporary headfile found in folder ${current_path}.  Any existing data will be removed and regenerated.\n";
	    return(0);
	} else {
	    my $tempHf = new Headfile ('rw', "${location}/${headfile_list[0]}");
	    if (! $tempHf->check()) {
		print " Unable to open temporary headfile ${headfile_list[0]}. Any existing data in ${current_path} will be removed and regenerated.\n";
		return(0);
	    }
	    if (! $tempHf->read_headfile) {
		print " Unable to read temporary headfile ${headfile_list[0]}. Any existing data in ${current_path} will be removed and regenerated.\n";
		return(0);
	    }
    
	    return($tempHf); 
	}
    }
}

# ------------------
sub headfile_alt_keys { # Takes a list of headfile keys to try and returns the first value found.
# ------------------
    my ($local_Hf,@keys)=@_;
    my $value="NO_KEY";
    my $counter = 0;
    for (my $key = shift(@keys); ($value eq  "NO_KEY") ; $key = shift(@keys)) {
	$counter++;
	if ($#keys == -1) {
	    return("NO_KEY",0);
	}
	$value  =  $local_Hf->get_value($key);
    }
    return($value,$counter);
}

sub data_double_check { # Checks a list of files; if a file is a link, double checks to make sure that it eventually lands on a real file.
# ------------------    # Subroutine returns number of files which point to null data; "0" is a successful test.
    my (@file_list)=@_;
    my $number_of_bad_files = 0;
 
    for (my $file_to_check = shift(@file_list); ($file_to_check ne '') ; $file_to_check = shift(@file_list)) {
	my ($name,$path,$ext) = fileparts($file_to_check);
#  The following is based on: http://snipplr.com/view/67842/perl-recursive-loop-symbolic-link-final-destination-using-unix-readlink-command/
	if ($file_to_check =~/[\n]+/) {
	    $number_of_bad_files++;
	} else {
	    while (-l $file_to_check) {
		($name,$path,$ext) = fileparts($file_to_check);
		$file_to_check = readlink($file_to_check);
		if ($file_to_check !~ /^\//) {
		    $file_to_check = $path.$file_to_check;
		}
	    }
	    
	    if (! -e $file_to_check) {
		$number_of_bad_files++;
	    }
	}
    }
 
    return($number_of_bad_files);
}

sub antsRegistration_memory_estimator { # Takes in an antsRegistration command, converts to test mode, sbatchs, and returns the MaxRSS used by the job.
# ------------------    
    my ($ants_command,$test_downsample)=@_;
    if (! defined $test_downsample) {$test_downsample=8;}
    my $mod = 'tester';
    my $memory;

    my $total_free = `free -m | grep Mem`;
    my @total_free = split(" ",$total_free);
    $total_free = $total_free[2];    
    $memory = int($total_free * 0.8);
#    print "Memory = $memory\n";

#    print "\n\nOld ants command = ${ants_command}\n";
#    $test_downsample = 1;
    $ants_command =~ s/(?<=-f\s)(.*?)(?=[\s]+-[A-Za-z-])/${test_downsample}/;
    my $boblob = $1;
    my @boblob = split('x',$boblob);
    print "Boblob = $boblob\n";
    my $lowest_downsample = pop(@boblob);
    my $ratio = ($test_downsample/$lowest_downsample);
    my $memory_ratio = ($ratio*$ratio*$ratio);
#    print "Memory ratio = ${memory_ratio}\nTest downsample = ${test_downsample}\n";

    $ants_command =~ s/(?<=-s\s)(.*x)([0-9]+.*?)(?=[\s]+-[A-Za-z-])/$2/;
    
    $ants_command =~ s/(?<=\[) ([\sx0-9]*) (?=,) /2000/x;
   #    my $blah = $1;   


   # $blah =~ s/[0]*[1-9]+[0-9]*/1/g;
   # $blah =~ s/[0]+/0/g;
   # $ants_command =~ s/marytylermoore/$blah/;

    $ants_command =~ s/(?<=-o)([\s]+)(\/|~\/|)(([^\/\s]*\/)+)([^\s]*)(?=\s)/ $2$3pilot_/xg;
    my $temp_path = "$2/$3";
    $ants_command =~ s/;[.\n]*//;

    print "\nNew ants command = ${ants_command}\n";
    
    if (cluster_check()) {
	my $cmd = $ants_command.";\n".
	    "rm ${temp_path}/pilot*;\n";
	my $go_message = "Estimating memory needs for $mod. Running antsRegistration in test mode.";
	my $stop_message = "Unable to estimate memory needs for $mod. antsRegistration has failed in test mode."; 
	my $home_path = $temp_path;
	my $Id= "${mod}_antsRegistration_pilot_run";
	my $verbose = 2; # Will print log only for work done.
	my $test = 1;
	print " temp_path = $temp_path\n";
	$jid = cluster_exec(1,$go_message , $cmd ,$home_path,$Id,$verbose,$memory,$test);     

	print "Job ID = $jid\n";
	if (! $jid) {
	    error_out($stop_message);
	}
	my $interval = 1;
	#my $verbose = 0;
	my $done_waiting = cluster_wait_for_jobs($interval,0,$jid);

	if ($done_waiting) {
	   sleep(1);
	   my $kilos =`sacct -j $jid -o MaxRSS | grep K | sed 's/K//g'`;
	   my $megas = int($kilos / 1024);
	   my $predicted_memory = $megas*$memory_ratio;
#	   print "kilos = $kilos\n";
#	   print "megas = $megas\n";
#	   print "predicted_memory = ${predicted_memory}\n";

	   return($megas);	
	}

    
    #' -p overload ';
    } else {

	`rm ${temp_path}/pilot*`;
    }
}

# ------------------
sub format_transforms_for_command_line {
# ------------------    
    my ($comma_string,$option_letter,$start,$stop) = @_;
    my $command_line_string='';
    my @transforms = split(',',$comma_string);
    my $total = $#transforms + 1;

    if (defined $option_letter) {
	$command_line_string = "-${option_letter} ";
    }

    if (! defined $start) {
	$start = 1;
	#$stop = $total;
    }

    if (! defined $stop) {
	$stop = $total;
    }

    my $count = 0;
#for(count=start;cont<stop&&count<maxn;count++)
#trans=transforms[count]
    foreach my $transform (@transforms) {
	$count++;
	if (($count >= $start) && ($count <= $stop)) {
	    if (($transform =~ /\.nii$/) || ($transform =~ /\.nii\.gz$/)) { # We assume diffeos are in the format of .nii or .nii.gz
		$command_line_string = $command_line_string." $transform ";	
	    } elsif (($transform =~ /\.mat$/) || ($transform =~ /\.txt$/)) { # We assume affines are in .mat or .txt formats
		if ($transform =~ m/-i[\s]+(.+)/) {
		    $command_line_string = $command_line_string." [$1,1] "; 
		} else {
		    $command_line_string = $command_line_string." [$transform,0] ";
		}
	    }
	}
    }
    return($command_line_string);
}

#---------------------
sub get_bounding_box_from_header {  ## This may still hang out in older VBM_pipeline code, so we support it be invoking get_bounding_box_and_spacing_from_header
#---------------------
    my ($in_file) = @_;

    my $bounding_box;
    my $bb_and_spacing = get_bounding_box_and_spacing_from_header($in_file);
    my @array = split(' ',$bb_and_spacing);
    my $sp = pop(@array);
    $bounding_box = join(' ',@array);

    return($bounding_box);
}

#---------------------
sub read_refspace_txt {
#---------------------
    my ($refspace_folder,$split_string,$custom_filename)=@_;
    my $refspace_file;
    my ($existing_refspace,$existing_refname);

    if (defined $custom_filename) {
	$refspace_file = "${refspace_folder}/${custom_filename}";
    } else { 
	$refspace_file = "${refspace_folder}/refspace.txt";
    }
   # print "$refspace_file\n\n";
    if (! data_double_check($refspace_file)) {
	my @existing_refspace_and_name =();
	my $array_ref = load_file_to_array($refspace_file, \@existing_refspace_and_name);

	($existing_refspace,$existing_refname) = split("$split_string",$existing_refspace_and_name[0]); 
    } else {
	$existing_refspace=0;
	$existing_refname=0;
    }
    return($existing_refspace,$existing_refname);
}

#---------------------
sub write_refspace_txt {
#---------------------
    my ($refspace,$refname,$refspace_folder,$split_string,$custom_filename)=@_;
    my $refspace_file;
    my $contents;

    my $array = join("$split_string",($refspace,$refname));

    
    if (defined $custom_filename) {
	$refspace_file = "${refspace_folder}/${custom_filename}";
    } else { 
	$refspace_file = "${refspace_folder}/refspace.txt";
    }
    #my @array = ($array);
    $contents = [$array];
    write_array_to_file($refspace_file,$contents);
    return(0);
}


#---------------------
sub compare_two_reference_spaces {
#---------------------
    my ($file_1,$file_2) = @_; #Refspace may be entered instead of file path and name.
    my ($bb_and_sp_1,$bb_and_sp_2);
 #   my ($sp_1,$sp_2);
    
    if (data_double_check($file_1)){
	$bb_and_sp_1 = $file_1;
#	$sp_1 = pop(@array);
#	$bb_1 = join(' ',@array);
    } else {
	$bb_and_sp_1 = get_bounding_box_and_spacing_from_header($file_1);
#	$sp_1 = get_spacing_from_header($file_1);
#	chomp($sp_1);
   }


   if (data_double_check($file_2)){
       $bb_and_sp_2 = $file_2;
#       $sp_2 = pop(@array);
#       $bb_2 = join(' ',@array);
   } else {
       $bb_and_sp_2 = get_bounding_box_and_spacing_from_header($file_2);
   }

    my $result=0;

    if ($bb_and_sp_1 eq $bb_and_sp_2) {
	$result = 1;
    }

    return($result);
}


#---------------------
sub recenter_nii_function {
#---------------------
    my ($file,$out_path,$skip,$temp_Hf,$verbose)= @_;
    if (! defined $skip) {$skip = 0 ;}
    if (! defined $verbose) {$verbose=1;}

    my ($name,$in_path,$ext) = fileparts($file);	
    my $nifti_args = "\'${in_path}\', \'$name\', \'nii\', \'${out_path}/$name$ext\', 0, 0, ".
	" 0, 0, 0,0,0, ${flip_x}, ${flip_z},0,0";
    if (! $skip) {
	my $nifti_command = make_matlab_command('civm_to_nii',$nifti_args,"${name}_",$temp_Hf,0); # 'center_nii'
	execute(1, "Recentering nifti images from tensor inputs", $nifti_command);	         
    }
}

#---------------------
sub hash_summation {
#---------------------

    my ($hash_pointer)=@_;
    my %hashish = %$hash_pointer;
    my $sum = 0;
    my $errors = 0;
    foreach my $k (keys %hashish) {
	if (ref($hashish{$k}) eq "HASH") {
	    foreach my $j (keys %{$hashish{$k}}) {
		my $string = $hashish{$k}{$j};
		if ($string =~ /^[0-9]*$/) {
		    $sum = $sum + $string;
		} else {
		    $errors++;
		}
	    }
	} else {
	    my $string = $hashish{$k};
	    if ($string =~ /^[0-9]*$/) {
		$sum = $sum + $string;
	    } else {
		$errors++;
	    }
	}
    }
    return($sum,$errors);
}

#---------------------
sub memory_estimator {
#---------------------

    my ($jobs,$nodes) = @_;
    if ((! defined $nodes) || ($nodes eq '') || ($nodes == 0)) { $nodes = 1;}

    my $node_mem = 244000;
    my $memory;
    my $jobs_per_node = int($jobs/$nodes + 0.99999);
    if ($jobs) {


	$memory =int($node_mem/$jobs_per_node);
	my $limit = 0.9*$node_mem;
	if ($memory > $limit) {
	    $memory = $limit;
	} 
	print "Memory requested per job: $memory MB\n";
    } else {
	$memory = 2440; # This number is not expected to be used so it can be arbitrary.
    }
    return($memory);
}


#---------------------
sub make_identity_warp {
#---------------------

    my ($source_image,$Hf,$optional_dir,$optional_name) = @_;
    my $output_name='';

    if (defined $optional_name) {
	$output_name = $optional_dir.'/'.$optional_name;
    } elsif (defined $optional_dir) {
	$output_name = $optional_dir.'/';
    }


    my $nifti_args;
    if ($output_name ne '') {
	$nifti_args="\'${source_image}\', \'${output_name}\'";
    } else {
	$nifti_args="\'${source_image}\'";
    }

    my $nifti_command = make_matlab_command('create_identity_warp',$nifti_args,"",$Hf,0);
    execute(1, "Creating identity warp from  ${source_image}", $nifti_command);

    return(0);
}



#---------------------
sub get_spacing_from_header { ## Easier to just call bb_and_spacing code and then take what we need.
#---------------------
    my ($in_file) = @_;
    my $spacing;
    my $bb_and_spacing = get_bounding_box_and_spacing_from_header($in_file);
    my @array = split(' ',$bb_and_spacing);
    $spacing = pop(@array);
   
    return($spacing);
}

#---------------------
sub get_bounding_box_and_spacing_from_header {
#---------------------

    my ($file,$ants_not_fsl) = @_;
    my $bb_and_spacing;
    my ($spacing,$bb_0,$bb_1);
    my $success = 0;
    my $header_output;

    if (! defined $ants_not_fsl) {
	$ants_not_fsl = 0;
    }
    #$ants_not_fsl = 1;
    if (! $ants_not_fsl) {
	my $fsl_cmd = "fslhd $file";
       
	$header_output = `${fsl_cmd}`;#`fslhd $file`;

	my $dim = 3;
	my @spacings;
	my @bb_0;
	my @bb_1;

	if ($header_output =~ /^dim0[^0-9]([0-9]{1})/) {
	    $dim = $1;

	}
	for (my $i = 1;$i<=$dim;$i++) {
	    my $spacing_i;
	    my $bb_0_i;
	    my $array_size_i;
	    if ($header_output =~ /pixdim${i}[\s]*([0-9\.\-]+)/) {
		$spacing_i = $1;
		$spacing_i =~ s/([0]+)$//;
		$spacing_i =~ s/(\.)$/\.0/;
		$spacings[($i-1)]=$spacing_i;
	    }
	   
	    if ($header_output =~ /sto_xyz\:${i}([\s]*[0-9\.\-]+)+/) {
		$bb_0_i = $1;
		$bb_0_i =~ s/([0]+)$//;
		$bb_0_i =~ s/(\.)$/\.0/;
		$bb_0_i =~ s/^(\s)+//;
		$bb_0[($i-1)]=$bb_0_i;
	    }
	    if ($header_output =~ /dim${i}[\s]*([0-9]+)/) {
		$array_size_i = $1;
		$array_size[($i-1)] = $array_size_i;
	    }
	    $bb_1_i= $bb_0[($i-1)]+$array_size[($i-1)]*$spacings[($i-1)];
	    $bb_1_i =~ s/([0]+)$//;
	    $bb_1_i =~ s/(\.)$/\.0/;
	    $bb_1_i =~ s/^(\s)+//;
	    $bb_1[($i-1)]= $bb_1_i;
	}

	$bb_0 = join(' ',@bb_0);
	$bb_1 = join(' ',@bb_1);
	$spacing = join('x',@spacings);
	
	$bb_and_spacing = "\{\[${bb_0}\], \[${bb_1}\]\} $spacing"; 

	if ($spacing eq '') {
	    $success = 0;
	} else {
	    $success = 1;
	}
    }

    if ($ants_not_fsl || (! $success)) {
	#Use ANTs (slow version)
	my $bounding_box;
	$header_output = `PrintHeader $file`;
	if ($header_output =~ /(\{[^}]*\})/) {	    $bounding_box = $1;
	    chomp($bounding_box);
	    $success = 1;
	} else {
	    $bounding_box = 0;
	}
	$spacing = `PrintHeader $file 1`;
	chomp($spacing);

	$bb_and_spacing = join(' ',($bounding_box,$spacing));
    }
    return($bb_and_spacing);
}


#---------------------
sub get_slurm_job_stats {
#---------------------
    my ($PM_code,@jobs) = @_;
  
    my $stats_string='';
    my $requested_stats = 'Node%25,TotalCPU%25,CPUTimeRaw%25,MaxRSS%25';
    foreach my $job (@jobs) {
	my $out_string='';
	my $current_stat_string = `sacct -Pan  -j $job.batch -o ${requested_stats}`;
	#print "Current_stat_string = ${current_stat_string}\n\n";
	my @raw_stats = split('\|',$current_stat_string);
	my $Node_string = $raw_stats[0];
	my $TotalCPU_string = $raw_stats[1];
	my $CPURaw_string = $raw_stats[2];
	my $MaxRSS_string = $raw_stats[3];

	my $node;
	if ($Node_string =~ /civmcluster1-0([1-6]{1})G?/) {
	    $node = $1;
	} else {
	    $node = 0;
	}
	
	my $total_cpu_raw = convert_time_to_seconds($TotalCPU_string);
	my $memory_in_kb = 0;
	chomp($MaxRSS_string);
	if ($MaxRSS_string =~ s/K$//) {
	    $memory_in_kb = $MaxRSS_string; 
	} 
	
	$out_string = "${PM_code},${job},${node},${total_cpu_raw},${CPURaw_string},${memory_in_kb}\n";
	$stats_string=$stats_string.$out_string;
    }
    #print "Stats string:\n${stats_string}\n";
    return($stats_string);
}

#---------------------
sub write_stats_for_pm {
#---------------------
    my ($PM,$Hf,$start_time,@jobs) = @_;
    my $PM_code;
    if (! defined $PM) { 
	$PM = 0;
    } elsif ($PM =~ s/\.pm$//) {
	$PM = $PM;
    }

    use Switch;
    switch ($PM) {
	case ('load_study_data_vbm') {$PM_code = 11;} 
	case ('convert_all_to_nifti_vbm') {$PM_code = 12;} 
	case ('create_rd_from_e2_and_e3_vbm') {$PM_code = 13;} 
	case ('mask_images_vbm') {$PM_code = 14;}
	case ('set_reference_space_vbm') {$PM_code = 15;}

	case ('create_rigid_reg_to_atlas_vbm'){$PM_code = 21;} 

	case ('create_affine_reg_to_atlas_vbm'){$PM_code = 39;} ## Intend to use a pairwise registration based module for the affine reg, analoguous to the MDT creation. 

	case ('pairwise_reg_vbm') {$PM_code = 41;}
	case ('calculate_mdt_warps_vbm') {$PM_code = 42;} 
	case ('apply_mdt_warps_vbm') {$PM_code = 43;}
	case ('mdt_apply_mdt_warps_vbm') {$PM_code = 43;}
	case ('calculate_mdt_images_vbm') {$PM_code = 44;} 
	case ('mask_for_mdt_vbm') {$PM_code = 45;}
	case ('calculate_jacobians_vbm') {$PM_code = 46;}
	case ('calculate_jacobians_mdtGroup_vbm') {$PM_code = 47;}


	case ('compare_reg_to_mdt_vbm') {$PM_code = 51;}
	case ('reg_apply_mdt_warps_vbm') {$PM_code = 52;}
	case ('calculate_jacobians_regGroup_vbm') {$PM_code = 53;}

	case ('mdt_create_affine_reg_to_atlas_vbm') {$PM_code = 61;}
	case ('mdt_reg_to_atlas_vbm') {$PM_code = 62;}
	case ('warp_atlas_labels_vbm') {$PM_code = 63;}
	case ('label_images_apply_mdt_warps_vbm') {$PM_code = 64;}
	case ('label_statistics_vbm') {$PM_code = 65;}

	case ('smooth_images_vbm') {$PM_code = 71;}
	case ('vbm_analysis_vbm') {$PM_code = 72;}

	case(/[0-9]{2}/) {$PM_code = $PM;}

#	case ('') {$PM_code = 19;}
#	case ('') {$PM_code = 19;}

	else  {$PM_code = 0;}
    }

    my $end_time = time;
    my $real_time = ($end_time - $start_time);
    my $pm_string = "${PM_code},0,0,${start_time},${real_time},0";
    my $stats_file = $Hf->get_value('stats_file');
    if ($stats_file ne 'NO_KEY') {
	`echo "${pm_string}" >> ${stats_file}`;
    }

    if  ($#jobs != -1) {
	my $stats =  get_slurm_job_stats($PM_code,@jobs);
	chomp($stats);
	if ($stats_file ne 'NO_KEY') {
	    `echo "$stats" >> ${stats_file}`;
	}
    }

    return($real_time);

}

#---------------------
sub convert_time_to_seconds {
#---------------------
    my ($time_and_date_string) = @_;
    my ($days,$hours,$minutes,$seconds);
    my $time_in_seconds = 0;
    
    
    my @colon_split = split(':',$time_and_date_string);
    my $categories = $#colon_split; 
 
    $seconds = $colon_split[$categories];
    $seconds = int($seconds + 0.9999999);
    $time_in_seconds = $time_in_seconds + $seconds;
    
    if ($categories > 0) {
	$minutes = $colon_split[($categories-1)];
	$time_in_seconds = $time_in_seconds + ($minutes*60);
    }
    
    if ($categories > 1) {
	my $hours_and_days = $colon_split[($categories-2)];
	if ($hours_and_days =~ /-/) {
	    ($days,$hours) = split('-',$hours_and_days);
	   
	} else {
	    $days = 0;
	    $hours = $hours_and_days;
	}
	
	$time_in_seconds = $time_in_seconds + ($hours*60*60);
	$time_in_seconds = $time_in_seconds + ($days*24*60*60);
	
    }
	
   # print "For ${time_and_date_string}, time in seconds is ${time_in_seconds}\n";

    return($time_in_seconds);

}


1;
