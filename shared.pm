package shared;

# Sally Gewalt civm 2/24/2007

use strict;
# 070618 slg changed too big/too small messages
# 080523 slg skip_and_glom_create binary needs to be found in architecture dependent directory


my $SKIP_AND_GLOM_CREATE = "skip_and_glom_create";
my $MY_STAT64 = "stat64my";
my $DEBUG = 0;

sub skip_and_glom {
  # from source to dest
  my ($binary_path, $source_path, $src_skip_bytes, $nbytes, $dest_path, $dest_skip_bytes) = @_;

  my $binary = "$binary_path" . "$SKIP_AND_GLOM_CREATE";
  if (! -e $binary) {
       return (0, "Unable to copy header: no program $binary");
  }

  # usage: skip_and_glom_create source_path src_skip_bytes nbytes dest_path dest_skip_bytes 
  my $cmd =
  "$binary $source_path $src_skip_bytes $nbytes $dest_path $dest_skip_bytes"
;
  print STDERR "    $cmd\n" if $DEBUG;
  my $ret = `$cmd`;
  my $status = $?;
  my $mod = $status % 255;
  if ($mod != 0) {
       return (0, "shared::skip_and_glom failed: $cmd");
  }
  else {
       return (1, "skip and glom ok");
  }
}


sub copy_header {
  # from source to dest
  my ($binary_path, $source_path, $dest_path, $headerbytes) = @_;

  my $src_skip_bytes = 0;
  my $dest_skip_bytes = 0;

  my ($code, $msg) = 
    skip_and_glom ($binary_path, $source_path, $src_skip_bytes, $headerbytes, $dest_path, $dest_skip_bytes);
  if ($code != 1) {
       print STDERR "$msg\n";
       return (0, "shared::copy_header: Unable to copy header of $headerbytes bytes from $source_path to $dest_path");
  }
  else {
       return (1, "Header copy ok");
  }
}

sub old_copy_header {
  # from source to dest
  my ($binary_path, $source_path, $dest_path, $headerbytes) = @_;

  my $src_skip_bytes = 0;
  my $dest_skip_bytes = 0;
  my $binary = "$binary_path" . "$SKIP_AND_GLOM_CREATE";
  if (! -e $binary) {
       return (0, "Unable to copy header:\n  no program $binary");
  }
  my $cmd =
  "$binary $source_path $src_skip_bytes $headerbytes $dest_path $dest_skip_bytes"
;
  print STDERR "  $cmd\n";
  my $ret = `$cmd`;
  my $status = $?;
  my $mod = $status % 255;
  if ($mod != 0) {
       return (0, "Unable to copy header:\n  $cmd");
  }
  else {
       return (1, "Header copy ok");
  }
}


sub bytes_in_file {
# returns 0 if error
# number of bytes in file otherwise

  my ($binary_path, $file_path) = @_;
  if (! -e $file_path) { return (0) };

  # my @list = stat $file_path;
  # but no such: my @list = stat64 $file_path;
  # return ($list[7]); # size in bytes
  my $binary = "$binary_path" . $MY_STAT64;

  if (! -e $binary) {
       print STDERR "Unable calculate 64 bit file size:\n  no program $binary\n";
       return 0;
  }
  #$cmd = "/recon_home/source/dir_stat64my/a.out $file_path";
  my $cmd = "$binary $file_path";
  my $result = `$cmd`;
  my $status = $?;
  my $mod = $status % 255;
  #print STDERR "   Found (status $status:zero is good) size of file $file_path\n";
  #print STDERR "     size = $result bytes:  $cmd\n";
  if ($mod != 0) {
       return 0;
  }
  else {
     return ($result); # size in bytes
  }
}

sub filesize_differs {
# return 0 if file is expected size 
# +1 if file is bigger than expected
# -1 if file is smaller than expected 
  my ($file_path, $expected_bytes, $binary_app_dir) = @_;
  my $found_bytes = bytes_in_file($binary_app_dir, $file_path); 
  if ($expected_bytes ne $found_bytes) {
     my $diff = $found_bytes - $expected_bytes;
     if ($diff > 0) {
       print STDERR "  File too big: $file_path expected to have $expected_bytes bytes not $found_bytes bytes found.\n    size diff = $diff\n";
       return +1;
     }
     else {
       print STDERR "  File too small: $file_path expected to have $expected_bytes bytes not $found_bytes bytes found.\n    size diff = $diff\n";
       print STDERR "         (possibly out of disk space?)\n";
       return -1 
     }
  }  
  print STDERR "     File size for $file_path is $found_bytes bytes as expected.\n";
  return 0;
}

sub write_lines_to_file {
  # appends lines
  my ($file_path, @message) = @_;
  if (open SESAME, ">>$file_path") {
     print STDERR "writing lines to $file_path\n";
     foreach my $line (@message) {
       print SESAME $line;
       #print STDERR "    $line";
     }
     close SESAME;
     return 1;
   }
   else {
      print STDERR "Unable to open $file_path to write text lines\n";
      return 0;
   }
}

sub old_processStep_xml_lines { 
# provenance information stored in xcede xml format along BIRN lines   
# see: http://www.loni.ucla.edu/twiki/bin/view/MouseBIRN/MouseXCEDE

my ($progname,$progcmdline,$progversion,$timestamp,
    $user,$machine,$platform,$platformversion,$cvs,
    $desc, $input_desc, $output_desc, $input_files, $output_files) = @_;
  my @message;
  push @message, "    <processStep>\n";
  push @message, "      <ProgramName>$progname</ProgramName>\n";
  push @message, "      <ProgramArgument>$progcmdline</ProgramArgument>\n";
  push @message, "      <version>$progversion</version>\n";
  push @message, "      <timeStamp>$timestamp</timeStamp>\n";
  push @message, "      <user>$user</user>\n";
  push @message, "      <machine>$machine</machine>\n";
  push @message, "      <platform>$platform</platform>\n";
  push @message, "      <platformVersion>$platformversion</platformVersion>\n";
  push @message, "      <cvs>$cvs</cvs>\n";
  push @message, "      <!--  additional $progname processStep description:\n";
  push @message, "$progname $desc\n";
  push @message, "$progname input description=$input_desc\n";
  push @message, "$progname output description=$output_desc\n";
  push @message, "$progname input file(s)=$input_files\n";
  push @message, "$progname output file(s)=$output_files\n";
  push @message, "      -->\n";
  push @message, "    </processStep>\n";
  return (@message);
}

sub processStep_xml_hash {
# Keys in hash you provide need to be consistant with
# provenance information stored in xcede xml format along BIRN lines.
# see: http://www.loni.ucla.edu/twiki/bin/view/MouseBIRN/MouseXCEDE
# You can add (valid) keys as needed.  Keys starting with "desc" are
# recorded inside a comment.

my (%xml) = @_;
  my @xml_elements;
  my @comments;
  if (!exists $xml{prov_programName}) {return ("processStep xml creation failed: programName not defined\n");}
  my $programName = $xml{prov_programName};

  my @key = keys %xml;
  foreach my $k (@key) {

     if ($k =~ /^prov_/) {
       # hash elements for processStep start with prov_ 
       my $xml_key = $k;
       $xml_key =~ s/prov_//; # remove prov_ prefix 
       #print STDERR "   processing xml key = $xml_key from $k\n";
       if ($xml_key =~ /^desc/) {
          # any element starting with desc is inserted in a comment  
          push @comments, "$programName $xml_key=$xml{$k}\n";
       }
       else {
          # all other keys should be valid <processStep> xml elements
          #  this doesn't check validity
          push @xml_elements, "      <$xml_key>$xml{$k}</$xml_key>\n";
       }
     }
  }

  my @message;
  push @message, "    <processStep>\n";
  push @message, @xml_elements;
  push @message, "      <!--  additional $programName processStep description:\n";
  push @message, @comments;
  push @message, "      -->\n";
  push @message, "    </processStep>\n";
  return (@message);
}

sub add_to_provenance_file {
# call above 2 routines to append xml processStep to path given
  my (%xml_orig) = @_;
  my %xml = %xml_orig; 

  if (defined $xml{'has_provenance_elements'}) {
    if (! $xml{'has_provenance_elements'}) {
        print STDERR 
    "step $xml{'step_name'} is calling add_to_provenance_file , but says it does not have xml elements.\n";
    }
  }
  my $provenance_file_path =  $xml{"provenance_file_path"}; 
  #print STDERR "HI!!! $xml{'prov_programName'} provenance stuff...to $provenance_file_path\n";

  my @xml_lines = processStep_xml_hash(%xml);
  print STDERR "  Provenance documentation for $xml{'prov_programName'}: ";
  return(write_lines_to_file($provenance_file_path, @xml_lines));
}

sub old_add_to_provenance_file {
# call above 2 routines to append xml processStep to path given
  my ($provenance_file_path,
    $progname,$progcmdline,$progversion,$timestamp,
    $user,$machine,$platform,$platformversion,$cvs,
    $input_desc, $output_desc, $input_files, $output_files) = @_;

  my @xml = old_processStep_xml_lines(
    $progname,$progcmdline,$progversion,$timestamp,
    $user,$machine,$platform,$platformversion,$cvs,
    $input_desc, $output_desc, $input_files, $output_files);
  print STDERR "  Provenance documentation for $progname: ";
  return(write_lines_to_file($provenance_file_path, @xml));
}

1;
