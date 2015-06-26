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
use File::Basename;
#my $DEBUG = 1;

sub works {
# is ssh working at all?


  my ($remote_system,$DEBUG) = @_;
  if(! defined($DEBUG) ){
      $DEBUG=1;
  }
    #print STDERR "trying ssh_call::works(): ssh $remote_system date\n" if $DEBUG; 
  #my $date = `ssh -Y -o PasswordAuthentication=false $remote_system date`;
  #my $date = `ssh -qY -o BatchMode=true $remote_system date`;
    my $date = `ssh -qY -o BatchMode=yes -o ConnectionAttempts=1 -o ConnectTimeout=1 -o IdentitiesOnly=yes -o NumberOfPasswordPrompts=0 -o PasswordAuthentication=no $remote_system date`;

    if ($date eq "") {
       print STDERR "  Problem:\n" if($DEBUG>=0); 
       print STDERR "  * Unable to remotely access system $remote_system.\n" if($DEBUG>=0);
       print STDERR "  * Remote system must allow ssh, scp.  User omega should have permissions.\n" if($DEBUG>=0);
       my $who = `whoami` if($DEBUG>=0);
       print STDERR "  * You are running this script as: $who\n" if($DEBUG>=0);

       return 0;
    }
    return 1;
}

sub get_file {
    my ($system, $source_dir, $file, $local_dest_dir,$verbose)  =@_;
    
    my $date = `ssh -Y $system date`;
    chop ($date);
    my $src = "$system:$source_dir";
    my $dest  = "$local_dest_dir";
    if ( !defined $verbose) { 
	$verbose=1;
    }
    if ( $file ne "" ) {
	$src="$src/$file"; 
	$dest="$dest/".basename($file);
    } #allow empty file, in case we have the full path in our sourcedir

    # this scp does not preserve links, here is an example of preserving links.
    # this example sends a file, to retrieve a file
    #$ tar cf - /usr/local/bin | ssh server.example.com tar xf -
    # i think this would retrieve remote.
    # ssh server.example.com tar cf - /usr/local/bin | tar -xf -
    # ssh crete '(cd /Volumes/workstation_data/data/atlas/rat/; tar -pcjf - rat_labels.nii.gz )' | tar -xjf -
    my @args  = ("scp","-C", $src, $dest); #the former solution which duplicated linked files, 
    @args  = ("cd $local_dest_dir; ssh $system '(cd $source_dir ; tar -pcjf - $file )'| tar -xjf - ";# the new solution which does not duplicate links.
    my $cmd=join(" ",@args);
    print STDERR "   Beginning ".$cmd." at $date...\n" if $verbose>0;#    print STDERR "Beginning scp of $src at $date...";
    my $start = time;

#         my $pid = open(PH, "$c 3>&1 1>&2 2>&3 3>&-|");
#         while (<PH>) {
#            $something_on_stderr = 1;
#            print "Executed command sent this message to STDERR: $_\n";
#            if (/Exception thrown/) {  # checks $_
#               print "  Execute recognized this ANTS error msg: $_\n";
#            }
#         }   
    if ( 0 ) {
	my $rc    = system ($cmd);#i think i want to conver this to an open | and while.
	    my $msg   = $?;
	if ($rc != 0 && $verbose>0) {
	    print STDERR "\n  * Remote copy failed: @args\n";
	    print STDERR "  * Couldn't copy file $src\n";
	    print STDERR "  * to $dest.\n";
	}
	if ($rc != 0) {
	    return 0;
	}
	
    } elsif ( 0 ) {    
	my $pid = open (my $CMD_FID,"$cmd 3>&1 1>&2 2>&3 3>&-|");
	#my $pid = open(CMD_FID, "$c 3>&1 1>&2 2>&3 3>&-|");
	my $something_on_stderr;
	while (<CMD_FID>) {
	    $something_on_stderr = 1;
	    print "Executed command sent this message to STDERR: $_\n";
	    if (/Exception thrown/) {  # checks $_
		print "  Execute recognized this ANTS error msg: $_\n";
	    }
	}   
    } elsif ( 1 ) {
	
	my $pid = open (my $CMD_FID,"$cmd 2>&1 |");
	if ( defined $pid) {
	    #print("PID$pid\n");
	    while (<$CMD_FID>){
		print if $verbose>0;
	    }
	    close ($CMD_FID) or print "command close failure\n" and return 0;
	} else {
	    return 0; 
	}
	#print("CMDEND\n");
    }
    my $end   = time;
    my $xfer_time = $end - $start;


    print STDERR "Successful scp took $xfer_time second(s).\n" if $xfer_time > 5;
    return 1;
}

###
# get_dir_listing sys, source, pattern
###
sub get_dir_listing {
    my ($system, $source_dir, $pattern)  =@_;
    my $date  = `ssh -Y $system date`;
    chop ($date);
    my $src   = "$system";
    my $cmd = "\"find -E $source_dir -iregex \'$pattern\'\"";
    #my $cmd = "ls -A $source_dir | grep -E -iregex \"$pattern\"";
    my @args;
    unshift(@args,"ssh");# put scp(our program name) on beginning of arglist
    push(@args,$src);   # put our src at the end of the arglist
    push(@args,$cmd); # put ls command at end of the arglist
    #@args = ("scp", $src, $dest);
    my $start = time;
    #print STDERR "   Beginning ".join(" ",@args)." at $date...\n";
    my @dir_listing=qx/@args/; #or 
#  	( print STDERR 
# 	  "  * Remote listing failed: ".join(" ",@args)."\n",
# 	  "  * Couldn't find files at $source_dir\n",
# 	  "  * with pattern $pattern.\n" and return 0); 
    my $msg   = $?;
    my $end   = time;
    my $xfer_time = $end - $start;
    chomp @dir_listing;
    #print(STDERR "Successful listing took $xfer_time second(s).\n");
    
    return @dir_listing;
}

###
# scp dir or contents of dir
###
#at source_dir/$dir on system to local_dest_dir/   
# cleans any separators from dir and returns that 
# can switch out user by adding user@ to system name/ip
sub get_dir_contents {
    my ($system, $source_dir, $dir, $local_dest_dir)  =@_;
    return get_dir_i($system, $source_dir, $dir.'/*', $local_dest_dir);
}
sub get_dir {
    my ($system, $source_dir, $dir, $local_dest_dir)  =@_;
    return get_dir_i($system, $source_dir, $dir.'/', $local_dest_dir);
}
sub get_dir_i { # the internal get_dir which does either the dir or its contents
    my ($system, $source_dir, $dir, $local_dest_dir)  =@_;
    my $date  = `ssh -Y $system date`;
    chop ($date);
    my $src   = "$system:$source_dir/$dir";
    my $dest;
    if ( $src =~ /\*$/) {
#	print STDERR "CONTENTS MODE";
	$dest  = "$local_dest_dir/";
    } else {
#	print STDERR "COMPLETE MODE";
	my $cdir=$dir;
	$cdir = $1 if($cdir=~/(.*)\/$/);
	$cdir    =~ s|/|_|g;
	$dest  = "$local_dest_dir/$cdir";
    }
    my @args ;
    if ( $src =~ /\s/x ) { # there are spaces in the source, implying there are options hiding in the source to add to our ssh call.
	print STDERR "adjust src from $src :\n";
	my @parts=split(" ",$src);
	#$src=join(' ',@parts[0,$#parts-1]);
	#$src=$src.' -r '.$parts[$#parts];
	push(@args,@parts);
	print STDERR "adjusted src to".join(@args)." :\n";
    } else {
	push( @args,$src);
    }
    
    unshift(@args,"-r"); # put -r on beinning of arglist,
    unshift(@args,"-C"); # add the compression.
    unshift(@args,"scp");# put scp(our program name) on beginning of arglist
    push(@args,$dest);   # put our destination at the end of the arglist
    #@args = ("scp", $src, $dest);
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
# scp dir  OLD
###
#at source_dir/$dir on system to local_dest_dir/dir
# cleans any separators from dir and returns that 
sub get_dir_OLD {
    my ($system, $source_dir, $dir, $local_dest_dir)  =@_;
    my $date  = `ssh -Y $system date`;
    chop ($date);
    my $src   = "$system:$source_dir/$dir/";
    my $cdir=$dir; # clean any path separators from the path.
    $cdir    =~ s|/|_|g;
    my $dest  = "$local_dest_dir/$cdir";
    # if ( $src =~ /\s/x ) {
    # 	print STDERR "adjust src from $src :\n";
    # 	my @parts=split(" ",$src);
    # 	$src=join(' ',@parts[0,$#parts-1]);
    # 	$src=$src.' -r '.$parts[$#parts];
    # 	print STDERR "adjust src to $src :\n";
    # } else {
    # 	$src="-r ".$src;
    # }
    my @args  = ("scp","-r", $src, $dest);
    my $start = time;
    print STDERR "   Beginning ".join(" ",@args)." at $date...\n";#    print STDERR "   Beginning scp of $src at $date...\n";
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

###
# get_ssh_ident
###
# fora given remote host try to get the ssh auth file via waiting on a password prompt
# if the $system contains an @ sign assume we're trying to get an other users ident.
# name our output ident accordingly with user_ONSYS_system 
# do a split on @.
sub get_ssh_ident {
    my ($system,$local_dest_dir)  =@_;
    
    my ($source_dir, $file,$outfile);
    my $cleanup = 0 ;
    $source_dir=".ssh";#$ENV{"HOME"}."/
    if ( ! defined $local_dest_dir ) {
	$local_dest_dir=$ENV{"HOME"}." /tmp/"; }
    if ( $system =~ m/@/x ) {
	my $user;
	($user,$system)=split("@",$system);
	if ( $system =~ m/\s/x){
	    print STDERR "no options supported in get_ssh_ident\n";
	    exit 1;
	}
	my $out_fn=$user."_ONSYS_".$system;
	$outfile=$local_dest_dir."/".$out_fn;
	$system="$user\@$system";
    }
    if ( ! -d $local_dest_dir ) {
	if ( $local_dest_dir eq $ENV{"HOME"}." /tmp/" ) {
	    $cleanup=1;
	}
	print("Making local dir $local_dest_dir\n");
	mkdir $local_dest_dir or die $!;
    }
    my @files=qw /id_rsa id_dsa identity/;
    $file=shift @files;
    #print( "outfile not found$outfile");
    #	$ident_store=$ENV{"HOME"}." /.ssh/wks_idents";
    while ( (! -f $outfile || ! -r $outfile) && ! get_file ($system, $source_dir, $file, $local_dest_dir) && $#files>=0 && ! -e $local_dest_dir.'/'.$file ) {
	$file=shift @files;
    }
    if ( -f $local_dest_dir.'/'.$file ){
	rename($local_dest_dir.'/'.$file,$outfile);
	`chmod g+r $outfile`;
	`chmod go-rxw $local_dest_dir`;
	`chmod -R go-rxw $local_dest_dir`;
    } else { 
	
    }
    if ($cleanup ) {
	rmdir $local_dest_dir;
    }    
#    print status ? true : false
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
       chomp ($last_Pno_withDir);
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
       chomp ($last_Pno_withDir);
       my @parts = split ("/",$last_Pno_withDir);
       my $pfile = pop @parts;
       return $pfile; 
} 


sub resolve_wildcards { 
  #  resolves a wildcard path to a single latest file
  my ($system, $wild_card_path)  =@_;

  my $lscmd = "unalias ls; ls -dtr $wild_card_path | tail -1";
  
  my $cmd   = "ssh -Y $system \"$lscmd\" ";
#  print ("$cmd\n");
  my $plain_path = `$cmd`;
  chomp $plain_path;
  if ($plain_path eq "") { #||$plain_path eq '/..') { 
  #if ($plain_path =~ m/(\|..)/x {
      print STDERR "  Problem:\n";
      print STDERR "  * You specified recon with wildcards in the name.\n";
      print STDERR "  * But couldn't find match.\n";
      print STDERR "  * cmd was: $cmd\n";
      return "";
  }
#       chop ($last_Pno_withDir);
#       my @parts = split ("/",$last_Pno_withDir);
#       my $pfile = pop @parts;
  return $plain_path; 
} 

sub resolve_wildcards_multi { 
  # resolves a wildcard path to a list of files
  my ($system, $wild_card_path,$count)  =@_;
 #  ssh nmrsu@nemo find /opt/PV5.1/data/nmrsu/nmr/ -iname "20120115*" -exec 'grep Rat -H {}/subject  \;' | cut -d ':' -f1
  my $lscmd = "unalias ls; ls -drt $wild_card_path";
  my $cmd   = "ssh -Y $system \"$lscmd\" ";
  print ("$cmd\n");
  my $plain_path = `$cmd`; #translates to blank
#  print STDERR $plain_path."\n";
  chomp $plain_path;

#  my (@paths)= $plain_path =~ m/([^[:cntrl:][:space:]]+)/gx ;
#  $plain_path=join(@paths," ");

  if ($plain_path eq "") {
      print STDERR "  Problem:\n";
      print STDERR "  * You specified recon with wildcards in the name.\n";
      print STDERR "  * But couldn't find match.\n";
      print STDERR "  * cmd was: $cmd\n";
      return "";
  }

#       chop ($last_Pno_withDir);
#       my @parts = split ("/",$last_Pno_withDir);
#       my $pfile = pop @parts;
  return $plain_path; 
} 

sub most_recent_directory {
  #  figure out latest file to transfer
  my ($system, $directory)  =@_;

  # excluding Old and Unarchiveahble is a hack that should be improved with some sort of exclusion list.
      my $lscmd = "unalias ls; ls -drt $directory/*/ | grep -v Old| grep -v Unarchiveable | tail -1";

      my $cmd = "ssh -Y $system \"$lscmd\" ";
      my $last_Pno_withDir = `$cmd`;
      if ($last_Pno_withDir eq "") {
        print STDERR "  Problem:\n";
        print STDERR "  * You specified recon of the newest file on scanner.\n";
        print STDERR "  * There are no files to recon on the scanner $system.\n";
        print STDERR "  * cmd was: $cmd\n";
        return "";
       }
       chomp ($last_Pno_withDir);
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
