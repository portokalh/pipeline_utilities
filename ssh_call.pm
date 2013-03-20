package ssh_call;

# calls for ssh
# 121119 james copied to ssh_call, hackish, but we'll see about it working
# 090211 slg changed most_recent_pfile to look for P*.7 vs P*.
#            no I did not: this would affect group scripts now that get PN12345 and cut off the
#            P to get the runno.  This change would be a good one to make tho.
#            Or else make radish notice when a file probably has no reasonable header and may be
#            a regular file
# Sally Gewalt civm 2/15/2007
use strict;
use warnings;
my $DEBUG = 1;

sub works {
# is ssh working at all?


  my ($remote_system) = @_;

    #print STDERR "trying ssh_call::works(): ssh $remote_system date\n" if $DEBUG; 
    my $date = `ssh -Y $remote_system date`;

    if ($date eq "") {
       print STDERR "  Problem:\n";
       print STDERR "  * Unable to remotely access system $remote_system.\n";
       print STDERR "  * Remote system must allow ssh, scp.  User omega should have permissions.\n
";
       my $who = `whoami`;
       print STDERR "  * You are running this script as: $who\n";

       return 0;
    }
    return 1;
}

sub get_file {
  my ($system, $source_dir, $file, $local_dest_dir)  =@_;

    my $date = `ssh -Y $system date`;
    chop ($date);
    my $src = "$system:$source_dir/$file";
    print STDERR "Beginning scp of $src at $date...";
    my $dest  = "$local_dest_dir/$file/";
    my @args  = ("scp", $src, $dest);
    my $start = time;
    my $rc    = system (@args);
    my $msg   = $?;
    my $end   = time;
    my $xfer_time = $end - $start;

    if ($rc != 0) {
       print STDERR "\n  * Remote copy failed: @args\n";
       print STDERR "  * Couldn't copy file $src\n";
       print STDERR "  * to $dest.\n";
       return 0;
    }
    print STDERR "Successful scp took $xfer_time second(s).\n";
    return 1;
}

###
# scp's contents of a dir 
###
#at source_dir/$dir on system to local_dest_dir/   
# cleans any separators from dir and returns that 
# can switch out user by adding user@ to system name/ip
sub get_dir_contents {
    my ($system, $source_dir, $dir, $local_dest_dir)  =@_;

    my $date  = `ssh -Y $system date`;
    chop ($date);
    my $src   = "$system:$source_dir/$dir/*";
    my $dest  = "$local_dest_dir/";
    my @args  = ("scp", "-r", $src, $dest);
    my $start = time;
    print STDERR "   Beginning ".join(" ",@args)." at $date...\n";
    !system (@args) or 
 	( print STDERR 
	  "  * Remote copy failed: ".join(" ",@args)."\n",
	  "  * Couldn't copy files at $src\n",
	  "  * to $dest.\n" and return 0); 
    my $msg   = $?;
    my $end   = time;
    my $xfer_time = $end - $start;
    print(STDERR "Successful scp took $xfer_time second(s).\n");
    return 1;
}

###
# scp dir 
###
#at source_dir/$dir on system to local_dest_dir/dir
# cleans any separators from dir and returns that 
sub get_dir {
    my ($system, $source_dir, $dir, $local_dest_dir)  =@_;
    my $date  = `ssh -Y $system date`;
    chop ($date);
    my $src   = "$system:$source_dir/$dir/";
    my $cdir=$dir; # clean any path separators from the path.
    $cdir    =~ s|/|_|g;
    my $dest  = "$local_dest_dir/$cdir";
    my @args  = ("scp", "-r", $src, $dest);
    my $start = time;
    print STDERR "   Beginning scp of $src at $date...\n";
    !system (@args) or 
 	( print STDERR 
	  "  * Remote copy failed: ".join(" ",@args)."\n",
	  "  * Couldn't copy dir $src\n",
	  "  * to $dest.\n" and return 0); # old way, not functional now for some reason
    
#    my $rc=qx/$cmd/;
    my $msg   = $?;
    my $end   = time;
    my $xfer_time = $end - $start;
    print(STDERR "Successful scp took $xfer_time second(s).\n");
    return 1;
}
sub most_recent_pfile {
  #  figure out latest pfile name (Signa)
  my ($system, $Pdirectory)  =@_;

      # ls appears to now be in /bin/ls
      ### not yet so specific ## my $lscmd = "unalias ls; ls -rt $Pdirectory/P*\.7 | tail -1";
      my $lscmd = "unalias ls; ls -rt $Pdirectory/P* | tail -1";

      my $cmd = "ssh -Y $system \"$lscmd\" ";
      my $last_Pno_withDir = `$cmd`;
      if ($last_Pno_withDir eq "") {
        print STDERR "  Problem:\n";
        print STDERR "  * You specified recon of the newest P file on scanner.\n";
        print STDERR "  * There are no Pfiles on scanner $system.\n";
        print STDERR "  * cmd was: $cmd\n";
        return "";
       }
       chop ($last_Pno_withDir);
       my @parts = split ("/",$last_Pno_withDir);
       my $pfile = pop @parts;
       return $pfile; 
} 

sub most_recent_file {
  #  figure out latest file to transfer
  my ($system, $directory)  =@_;

      # ls appears to now be in /bin/ls
      ### not yet so specific ## my $lscmd = "unalias ls; ls -rt $directory/P*\.7 | tail -1";
      my $lscmd = "unalias ls; ls -rt $directory/* | tail -1";

      my $cmd = "ssh -Y $system \"$lscmd\" ";
      my $last_Pno_withDir = `$cmd`;
      if ($last_Pno_withDir eq "") {
        print STDERR "  Problem:\n";
        print STDERR "  * You specified recon of the newest file on scanner.\n";
        print STDERR "  * There are no files to recon on the scanner $system.\n";
        print STDERR "  * cmd was: $cmd\n";
        return "";
       }
       chop ($last_Pno_withDir);
       my @parts = split ("/",$last_Pno_withDir);
       my $pfile = pop @parts;
       return $pfile; 
} 

sub most_recent_directory {
  #  figure out latest file to transfer
  my ($system, $directory)  =@_;

      my $lscmd = "unalias ls; ls -drt $directory/*/ | tail -1";

      my $cmd = "ssh -Y $system \"$lscmd\" ";
      my $last_Pno_withDir = `$cmd`;
      if ($last_Pno_withDir eq "") {
        print STDERR "  Problem:\n";
        print STDERR "  * You specified recon of the newest file on scanner.\n";
        print STDERR "  * There are no files to recon on the scanner $system.\n";
        print STDERR "  * cmd was: $cmd\n";
        return "";
       }
       chop ($last_Pno_withDir);
       my @parts = split ("/",$last_Pno_withDir);
       my $pfile = pop @parts;
       return $pfile; 
} 

sub exists {
# does a remote path exist?
  my ($system, $path)  =@_;
  #my $lscmd = "/bin/ls -rt $path | tail -1";
  my $lscmd = "unalias ls; ls -rt $path | tail -1";

  my $cmd = "ssh -Y $system \"$lscmd\" ";
  my $result = `$cmd`;
  if ($result eq "") {
        return 0;
  } 
  return 1;
}
1;
