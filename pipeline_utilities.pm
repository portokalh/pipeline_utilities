#pipeline_utilites.pm
#
# utilities for pipelines including matlab calls from perl 
#
# created 09/10/15  Sally Gewalt CIVM
#                   based on t2w pipeline  
# 110308 slg open_log returns log path

# be sure to change version:
my $VERSION = "12/03/21";

my $log_open = 0;
my $pipeline_info_log_path = "UNSET";

my @outheadfile_comments = ();  # this added to by log_pipeline_info so define early
my $BADEXIT = 1;
my $debug_val=30;
use File::Path;
use strict;
use English;
#use seg_pipe;
use vars qw($HfResult);
# -------------
sub open_log {
# -------------
   my ($result_dir) = @_;
   if (! -d $result_dir) {
       print ("no such dir for log: $result_dir");
       exit $BADEXIT;
   }
   if (! -w $result_dir) {  
       ("dir for log: $result_dir not writeable");
       exit $BADEXIT;
   }

   $pipeline_info_log_path = "$result_dir/pipeline_info_$PID.txt";
   open PIPELINE_INFO, ">$pipeline_info_log_path" or die "Can't open pipeline_info file";
   my $time = scalar localtime;
   print "Logfile is: $pipeline_info_log_path\n";
   $log_open = 1;

   log_info("Log opened at $time.");
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
     print "LOG: $log_me\n";

     # send to pipeline file:
     print PIPELINE_INFO "$log_me\n";
   }
   else {
    print "LOG NOT OPEN!\n";
    print "  You tried to send this info to the log file, but the log file is not available:\n";
    print "  attempted log msg: $log_me\n";
   }
}


# -------------
sub error_out
# -------------
{
  my ($msg) = @_;
  print STDERR "\n<~Pipeline failed.\n";
  print STDERR "  Failure cause: ", $msg,"\n";
  print STDERR "  Please note the cause.\n";

  close_log_on_error($msg);
  if ($HfResult ne "unset") {
    my $hf_path = $HfResult->get_value('headfile_dest_path');
    if($hf_path eq "NO_KEY"){ $hf_path = $HfResult->get_value('headfile-dest-path'); }
    $HfResult->write_headfile($hf_path);
    $HfResult = "unset";
  }
  exit $BADEXIT;
}

# -------------
sub close_log_on_error  {
# -------------
  my ($err_msg) = @_;
  # possible you may call this before the log is open
  if ($log_open) {
      my $exit_time = scalar localtime;
      log_info("Error cause: $err_msg");
      log_info("Log close at $exit_time.");

      # emergency close log (w/o log dumping to headfile)
      close(PIPELINE_INFO);
      $log_open = 0;
      print "  Log is: $pipeline_info_log_path\n";
      return (1);
  }
  else {
      print "  NOTE: log file was not open at time of error.\n";
      return (0);     
  }
}

# -------------
sub make_matlab_m_file {
# -------------
#simple utility to save an mfile with a contents of function_call at mfile_path
   my ($mfile_path, $function_call) = @_;
   open MATLAB_M, ">$mfile_path" or die "Can't open mfile $mfile_path";
   log_info("Matlab function call mfile created: $mfile_path");
   log_info("  mfile contains: $function_call");
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
   my $matlab_app = $Hf->get_value('engine_app_matlab');
   if ($matlab_app eq "NO_KEY" ) { $matlab_app = $Hf->get_value('engine-app-matlab'); }
   print("make_matlab_command:\n\tengine_matlab_path:${matlab_app}\n\twork_dir:$work_dir\n") if($debug_val>=25);
   
   my $mfile_path = "$work_dir/${short_unique_purpose}${function_m_name}";
   my $function_call = "$function_m_name ( $args )";
   make_matlab_m_file ($mfile_path, $function_call);
   my $cmd_to_execute = "$matlab_app < $mfile_path > /tmp/matlab_pipe_stuff";
   return ($cmd_to_execute);
}
# -------------
sub make_matlab_command_v2 { 
# -------------
# small wrapper for make_matlab_command, the v2 functionality has been integrated into the original. 
# This is just to contain cases where we called the v2 version and they havnt been found yet.
    $cmd_to_execute = make_matlab_command(@_);
    return ($cmd_to_execute);
}


# -------------
sub make_matlab_command_V2_OBSOLETE {
# -------------
# this seems identicle to make_matlab_command, was there some plan to edit this that wasnt implimented?
   my ($function_m_name, $args, $short_unique_purpose, $Hf) = @_;
# short_unique_purpose is to make the name of the mfile produced unique over the pipeline (they all go to same dir) 
   my $work_dir   = $Hf->get_value('dir-work');
   my $matlab_app = $Hf->get_value('engine-app-matlab');
   my $mfile_path = "$work_dir/$short_unique_purpose$function_m_name";
   my $function_call = "$function_m_name ( $args )";
   make_matlab_m_file ($mfile_path, $function_call);
   my $cmd_to_execute = "$matlab_app < $mfile_path > /tmp/matlab_pipe_stuff";
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
	    }
	    else {
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
sub locate_data {
# ------------------
  # Retrieve a source image set from image subproject on atlasdb
  # Also sets the dest dir for each set in the headfile so
  # you need to call this even if $pull_images is false.

  my ($pull_images, $ch_id, $Hf)=@_;
  # $ch_id should be T1, T2, T2star (current CIVM MR SOP for seg), 
  # or can be  adc, dwi, fa, e1 for DTI derrived data in research archive

# check set against allowed types, T1, T2W, T2star
  my $dest       = $Hf->get_value('dir-input');
  my $useunderscore=0;
  if ($dest eq "NO_KEY" ) { $dest = $Hf->get_value("dir_input"); 
			  $useunderscore=1;}
  my $subproject = $Hf->get_value('subproject-source-runnos');
  if ($subproject eq "NO_KEY" ) { $subproject = $Hf->get_value("subproject_source_runnos"); }
  my $runno_flavor = "$ch_id\-runno";

  
  my $runno = $Hf->get_value($runno_flavor);
  if ($runno eq "NO_KEY" ) { $runno_flavor="${ch_id}_runno"; $runno = $Hf->get_value("$runno_flavor"); }
  if ($runno eq "NO_KEY") { error_out ("ouch $runno $runno_flavor\n"); }
  my $ret_set_dir;
  my ($image_name, $digits, $suffix);
  if ( $ch_id =~ m/(T1)|(T2W)|(T2star)/ ) {
    $ret_set_dir = retrieve_archive_dir($pull_images, $subproject, $runno, $dest);  
    my $first_image_name = first_image_name($ret_set_dir, $runno);
    ($image_name, $digits, $suffix) = split ('\.', "$first_image_name");
    $Hf->set_value("$ch_id\-image-padded-digits", $digits);
  } elsif ( $ch_id =~ m/(adc)|(dwi)|(e1)|(fa)/){
    print STDERR "label channel passed to locate_data not a standard image format, Assuming DTI archive format.\n";
    ($ret_set_dir,$image_name) = retrieve_DTI_research_image($pull_images, $subproject, $runno, $ch_id, $dest);
    ($image_name, $suffix) = split ('\.', "$image_name");
  } else {
    print STDERR "Unreconized channel type: $ch_id, sorry i dont support that yet.\n";
  }
  if($useunderscore==0) {
    $Hf->set_value("$ch_id\-path", $ret_set_dir);
    $Hf->set_value("$ch_id\-image-basename"     , $image_name);
    $Hf->set_value("$ch_id\-image-suffix"       , $suffix);
  }elsif($useunderscore==1){
    $Hf->set_value("$ch_id\_path", $ret_set_dir);
    $Hf->set_value("$ch_id\_image_basename"     , $image_name);
    $Hf->set_value("$ch_id\_image_suffix"       , $suffix);
  }
}
