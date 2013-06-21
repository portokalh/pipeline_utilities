# Skip_and_glom.pm

# created 1/26/2010 Sally Gewalt 
# emulate skip_and_glom_create c program in Perl
# But no buffering of nbyte chunks so this is appropriate only
# for small nbytes (like view by view pinwheel).
# So I warn if nbytes is "too big", an arb value.
# For small copies from perl using this avoids repetitive invoking of C routine.

package Skip_and_glom;
use strict;
use warnings;
use Fcntl;

my $g_open_src_path  ="_UNDEF_src";
my $g_open_dest_path ="_UNDEF_dest";
my $g_buf;
my $S = "Skip_and_glom.pm:";
my $TOO_BIG_NBYTES = 8192;

#------------
sub go 
#------------
{
# Copy nbytes from source location to dest location.
# Limit how big nbytes can be, cause this doesn't buffer, like c program skip_and_glom_create does.
  my ($src_path, $src_skip_bytes, $nbytes, $dest_path, $dest_skip_bytes) = @_;

  my $ok;
  if ($g_open_src_path ne $src_path) {
    if (! -e $src_path) {
      print STDERR " ***source file $src_path does not exist\n";
      return (0); 
    }
    if ($nbytes > $TOO_BIG_NBYTES) {
      print STDERR " ***$S I think nbytes is too big; my limit is $TOO_BIG_NBYTES, increase limit or use the buffered C program\n";
      return (0); 
    }
    # open SRC for read only
    $ok = sysopen SRC, $src_path, O_RDONLY;
    if (!$ok) { 
      print STDERR " ***$S Can't open source file $src_path\n";
      return (0); 
    }
    $g_open_src_path = $src_path;
  } 

  if ($g_open_dest_path ne $dest_path) {
    if ($nbytes > $TOO_BIG_NBYTES) {
      print STDERR " ***$S I think nbytes is too big; my limit is $TOO_BIG_NBYTES, increase limit or use the buffered C program\n";
      return (0); 
    }
    # when first opening dest path use O_TRUNC to clean it out
    # open DEST for write 
    if (-e $dest_path) {
      $ok = sysopen DEST, $dest_path, O_RDWR | O_TRUNC;
    }
    else {
      $ok = sysopen DEST, $dest_path, O_RDWR | O_CREAT | O_TRUNC;
    }
    if (!$ok) { 
      print STDERR "  ***$S Can't open dest file $dest_path\n";
      return (0); 
    }
    $g_open_dest_path = $dest_path;
  } 

  # -- seek to src
  my $sook;
  $sook = sysseek (SRC, $src_skip_bytes, 0);
  if ((!defined $sook) || ($sook != $src_skip_bytes)) {
      print STDERR "  ***$S Can't seek to $src_skip_bytes bytes in $g_open_src_path\n";
      return (0); 
  }

  # -- read from src
  my $nread = sysread SRC, $g_buf, $nbytes; 
  if ((!defined $nread) || ($nread != $nbytes)) {
      print STDERR "  ***$S Can't read $nbytes bytes from $g_open_src_path from byte $src_skip_bytes\n";
      return (0); 
  }

  # -- seek to dest 
  $sook =sysseek (DEST, $dest_skip_bytes, 0);
  if ((!defined $sook) || ($sook != $dest_skip_bytes)) {
      print STDERR "  ***$S Can't seek to $dest_skip_bytes bytes in $g_open_dest_path\n";
      return (0); 
  }

  # -- write to dest
  my $nwrote = syswrite DEST, $g_buf, $nbytes;
  if ((!defined $nwrote) || ($nbytes != $nwrote)) {
      print STDERR "   ***$S Can't write $nbytes bytes to $g_open_dest_path\n";
      return (0); 
  }

  return (1);
}

1;



