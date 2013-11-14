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
# 130731 james, added new function new_get_engine_dependenceis, to replace that chunk of code used all the damn time.
#               takes an output identifier, and an array of required values in the constants file to be checked. 
#               should add a standard headfile settings file for the required values in an engine_dependencie headfile 
#               returns the three directories  in work result, outhf_path, and the engine_constants headfile.
# be sure to change version:
my $VERSION = "130731";

my $log_open = 0;
my $pipeline_info_log_path = "UNSET";

my @outheadfile_comments = ();  # this added to by log_pipeline_info so define early
#my $BADEXIT = 1;
my $debug_val = 5;
use File::Path;
use strict;
use English;
#use seg_pipe;

use vars qw($HfResult $BADEXIT $GOODEXIT);
my $PM="pipeline_utilities";

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
   my ($log_me) = @_;

   if ($log_open) {
     # also write this info to headfile later, so save it up
     my $to_headfile = "# PIPELINE: " . $log_me;
     push @outheadfile_comments, "$to_headfile";  

     # show to user:
     print( "#LOG: $log_me\n");

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
  my ($msg) = @_;
  # possible you may call this before the log is open
  if ($log_open) {
      my $exit_time = scalar localtime;
      log_info("Error cause: $msg");
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
    $HfResult->write_headfile($hf_path);
    $HfResult = "unset";
  }
  exit $BADEXIT;
}

# -------------
sub make_matlab_m_file {
# -------------
#simple utility to save an mfile with a contents of function_call at mfile_path
# logs the information to the log file, and calls make_matalb_m_file_quiet to do work
   my ($mfile_path, $function_call) = @_;
   log_info("Matlab function call mfile created: $mfile_path");
   log_info("  mfile contains: $function_call");
   make_matlab_m_file_quiet($mfile_path,$function_call);
}

# -------------
sub make_matlab_m_file_quiet {
# -------------
#simple utility to save an mfile with a contents of function_call at mfile_path
   my ($mfile_path, $function_call) = @_;
   open MATLAB_M, ">$mfile_path" or die "Can't open mfile $mfile_path";
   # insert startup.m call here.
   use Env qw(WKS_SHARED);

   if ( defined $WKS_SHARED) { 
       if ( -e "$WKS_SHARED/pipeline_utilities/startup.m") 
       {
	   print MATLAB_M "run('$WKS_SHARED/pipeline_utilities/startup.m');\n";
       }
   }
   print MATLAB_M "$function_call";
   close MATLAB_M;
}

# -------------
sub make_matlab_command {
# -------------
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
   
   my $mfile_path = "$work_dir/${short_unique_purpose}${function_m_name}";
   my $function_call = "$function_m_name ( $args )";
   make_matlab_m_file ($mfile_path, $function_call);
   my $logpath="$work_dir/matlab_${function_m_name}";
   my $cmd_to_execute = "$matlab_app $matlab_opts < $mfile_path > $logpath";
   return ($cmd_to_execute);
}

# -------------
sub make_matlab_command_nohf {
# -------------
#  my $matlab_cmd=make_matlab_command_nohf($mfilename, $mat_args, $purpose, $local_dest_dir, $Engine_matlab_path);
   my ($function_m_name, $args, $short_unique_purpose, $work_dir, $matlab_app,$logpath) = @_;
   print("make_matlab_command:\n\tengine_matlab_path:${matlab_app}\n\twork_dir:$work_dir\n") if($debug_val>=25);
   my $mfile_path = "$work_dir/${short_unique_purpose}${function_m_name}";
   my $function_call = "$function_m_name ( $args )";

   if (! defined $logpath) { 
#       $logpath = '> /tmp/matlab_pipe_stuff';
#   } else {  
       $logpath='> '."$work_dir/matlab_${function_m_name}";
   }

   make_matlab_m_file_quiet ($mfile_path, $function_call);
   my $cmd_to_execute = "$matlab_app < $mfile_path $logpath"; 
   return ($cmd_to_execute);
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
sub new_get_engine_dependencies {
# ------------------
# finds and reads engine dependency file 
  my ($identifier,@required_values) = @_;


  use Env qw(PIPELINE_HOSTNAME PIPELINE_HOME BIGGUS_DISKUS WKS_SETTINGS WORKSTATION_HOSTNAME);
  
  if (! defined($BIGGUS_DISKUS)) { error_out ("Environment variable BIGGUS_DISKUS must be set."); }
  if (!-d $BIGGUS_DISKUS)        { error_out ("unable to find $BIGGUS_DISKUS"); }
  if (!-w $BIGGUS_DISKUS)        { error_out ("unable to write to $BIGGUS_DISKUS"); }
  if  ( ! defined($WORKSTATION_HOSTNAME)) { 
      print("WARNING: obsolete variable PIPELINE_HOSTNAME used.\n");
  } else { 
      $PIPELINE_HOSTNAME=$WORKSTATION_HOSTNAME;
  }
  my $engine_constants_dir ;
  if ( ! defined($WKS_SETTINGS) ) { 
      print("WARNING: obsolete variable PIPELINE_HOME used to find dependenceis\n");
      $engine_constants_dir="$PIPELINE_HOME/dependencies";
  } else { 
      $PIPELINE_HOME=$WKS_SETTINGS;
      $engine_constants_dir="$PIPELINE_HOME/engine_deps";
  }
  if (! defined($PIPELINE_HOSTNAME)) { error_out ("Environment variable WORKSTATION_HOSTNAME must be set."); }
  if (! defined($PIPELINE_HOME)) { error_out ("Environment variable WKS_SETTINGS must be set."); }
  if (!-d $PIPELINE_HOME)        { error_out ("unable to find $PIPELINE_HOME"); }
  if (! -d $engine_constants_dir) {
      error_out ("$engine_constants_dir does not exist.");
  }
  my $engine_file =join("_","engine","$PIPELINE_HOSTNAME","dependencies"); 
  my $engine_constants_path = "$engine_constants_dir/".$engine_file;
  if ( ! -f $engine_constants_path ) { 
      $engine_file=join("_","engine","$PIPELINE_HOSTNAME","pipeline_dependencies");
      $engine_constants_path = "$engine_constants_dir/".$engine_file;
      print("WARNING: OBSOLETE SETTINGS FILE USED, $engine_file\n")
  }
  
  my $Engine_constants = new Headfile ('ro', $engine_constants_path);
  if (! $Engine_constants->check()) {
    error_out("Unable to open engine constants file $engine_constants_path\n");
  }
  if (! $Engine_constants->read_headfile) {
     error_out("Unable to read engine constants from headfile form file $engine_constants_path\n");
  }
  my @errors;
  foreach (@required_values) { 
      print("$_: ".$Engine_constants->get_value($_)."\n");      
      if ( ! defined ( $Engine_constants->get_value($_) ) ){ 
	  push(@errors," Unable to find required value $_"); 
      } elsif ( ! -e $Engine_constants->get_value($_) ) { 
	  push(@errors," Required value set but file not found : $_=$Engine_constants->get_value($_)");
      }
  }
  my $conventional_input_dir = "$BIGGUS_DISKUS/$identifier\-inputs"; # may not exist yet
  
  my $conventional_work_dir  = "$BIGGUS_DISKUS/$identifier\-work";
  if (! -e $conventional_work_dir) {
    mkdir $conventional_work_dir;
  }
  my $conventional_result_dir  = "$BIGGUS_DISKUS/$identifier\-results";
  if (! -e $conventional_result_dir) {
    mkdir $conventional_result_dir;
  }

  my $conventional_headfile = "$conventional_result_dir/$identifier\.headfile"; 
  return($conventional_input_dir, $conventional_work_dir, $conventional_result_dir, $conventional_headfile, $Engine_constants);
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
    my ($name,$path,$suffix) = fileparse($fullname,qr/.[^.]*$/);
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

# ------------------
sub get_ssh_auth {
# ------------------

}
