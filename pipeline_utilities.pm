
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
my $debug_val = 5;
use File::Path;
use POSIX;
use strict;
use warnings;
use English;
#use seg_pipe;

use vars qw($HfResult $BADEXIT $GOODEXIT);
my $PM="pipeline_utilities";
use civm_simple_util qw(load_file_to_array write_array_to_file);
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
   open $PIPELINE_INFO, ">$pipeline_info_log_path" or die "Can't open pipeline_info file";
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
      my ($n,$p,$e) = fileparts($hf_path);
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
    for(my $iter=0;$iter<3 ;$iter++) {
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
    
    my @md5 = (); 
    if (! -l $file ) {
	@md5=(file_checksum($file));	
    } else {
	@md5=(link_checksum($file));	
    }
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
sub link_checksum {
# -------------
    # run checksum on link and return checksum result.
    my ($file) = @_;
    use Digest::MD5 qw(md5 md5_hex md5_base64); 
    my $data = readlink $file or die "could not open $file";
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
  $SIG{CHLD} = sub {# this reaps all COMPLETED children but does not wait on uncompleted
      while () {
	  my $child = waitpid -1, POSIX::WNOHANG;
	  last if $child <= 0;
	  my $localtime = localtime;
	  my $ev=$?>> 8;
	  #print "Parent: Child $child was reaped - $localtime. \n";
	  if ( $ev ) {
	      error_out( "Parent: Child $child was reaped - $localtime with error code:$ev \n");
	  }
	  $nforked-=1;
      }
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
    #requried_values=engine==hostname -s
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
    my ($name,$path,$suffix) = fileparse($fullname,qr/\.[^.]*$/);
    return($name,$path,$suffix);
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
