package rsh_call;

# calls for rsh
# Sally Gewalt civm 2/15/2007
# 090211 slg changed most_recent_pfile to look for P*.7 vs P*.
#            no I did not: this would affect group scripts now that get PN12345 and cut off the
#            P to get the runno.  This change would be a good one to make tho.
#            Or else make radish notice when a file probably has no reasonable header and may be
#            a regular file
use strict;
my $DEBUG = 1;

sub works {
# is rsh working at all?


  my ($remote_system) = @_;

    #print STDERR "trying rsh_call::works(): rsh $remote_system date\n" if $DEBUG; 
    my $date = `rsh $remote_system date`;

    if ($date eq "") {
       print STDERR "  Problem:\n";
       print STDERR "  * Unable to remotely access system $remote_system.\n";
       print STDERR "  * Remote system must allow rsh, rcp.  User omega should have permissions.\n
";
       my $who = `whoami`;
       print STDERR "  * You are running this script as: $who\n";

       return 0;
    }
    return 1;
}

sub get_file {
  my ($system, $source_dir, $file, $local_dest_dir)  =@_;

    my $date = `rsh $system date`;
    chop ($date);
    my $src = "$system:$source_dir/$file";
    print STDERR "   Beginning rcp of $src at $date...";
    my $dest = "$local_dest_dir/$file";
    my @args = ("rcp", $src, $dest);
    my $start = time;
    my $rc = system (@args);
    my $msg = $?;
    my $end = time;
    my $xfer_time = $end - $start;

    if ($rc != 0) {
       print STDERR "\n  * Remote copy failed: @args\n";
       print STDERR "  * Couldn't copy file $src\n";
       print STDERR "  * to $dest.\n";
       return 0;
    }
    print STDERR "Successful rcp took $xfer_time second(s).\n";
    return 1;
}

sub most_recent_pfile {
  #  figure out latest pfile name (Signa)
  my ($system, $Pdirectory)  =@_;

      # ls appears to now be in /bin/ls
      ### not yet so specific ## my $lscmd = "unalias ls; ls -rt $Pdirectory/P*\.7 | tail -1";
      my $lscmd = "unalias ls; ls -rt $Pdirectory/P* | tail -1";

      my $cmd = "rsh $system \"$lscmd\" ";
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

sub exists {
# does a remote path exist?
  my ($system, $path)  =@_;
  #my $lscmd = "/bin/ls -rt $path | tail -1";
  my $lscmd = "unalias ls; ls -rt $path | tail -1";

  my $cmd = "rsh $system \"$lscmd\" ";
  my $result = `$cmd`;
  if ($result eq "") {
        return 0;
  } 
  return 1;
}
1;
