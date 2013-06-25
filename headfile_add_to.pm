# headfile_add_to.pm
#
# Sally Gewalt civm 4/7/2009
#  Add items stored in a hash to headfile noted by path
# return number of items added.  0 added (probably) means error.

package headfile_add_to;
use strict;
##3use IO qw(Handle File);
use Headfile;

my $DEBUG = 0;
my $NO_ITEMS_ADDED = 0;
my $SCRIPT_NAME = "add_to_headfile.pm";

sub add_item_hash {
# the headfile must exist.  This does not create a new headfile.  It's for adding to existing headfiles.
  my ($headfile_path, %item_hash) = @_;
  my $nitems_added = 0;
  my $SESAME;
  if (!-e $headfile_path) {
     print STDERR "$SCRIPT_NAME ERROR: $headfile_path does not exist\n"; 
     return ($NO_ITEMS_ADDED);
  } 

  my $Hf = new Headfile ('rw', $headfile_path);
  my $ok = $Hf->check;
  if (! $ok ) {
     print STDERR "$SCRIPT_NAME add items ERROR: headfile $headfile_path not opened properly.\n"; 
     return ($NO_ITEMS_ADDED);
  }
  else {
    print STDERR "$SCRIPT_NAME headfile $headfile_path OK.\n" if $DEBUG; 
  }
  $ok = $Hf->read_headfile;

  my @item_list = keys %item_hash;
  foreach my $item (@item_list) {
    print STDERR "   adding $item = $item_hash{$item}\n" if $DEBUG;
    $Hf->set_value($item, $item_hash{$item});
    $nitems_added++;
  }
  $ok = $Hf->write_headfile($headfile_path);
  if (! $ok ) {
     print STDERR "$SCRIPT_NAME add items ERROR: headfile $headfile_path not written properly.\n"; 
     return ($NO_ITEMS_ADDED);
  }

  print STDERR "$SCRIPT_NAME added $nitems_added items to headfile $headfile_path.\n" if $DEBUG; 
  return ($nitems_added)
  
} 
 
sub add_comments {
  my ($headfile_path, @comment_list) = @_;
  my $nitems_added = 0;
  my $SESAME;
  if (!-e $headfile_path) {
     print STDERR "$SCRIPT_NAME ERROR: $headfile_path does not exist\n";
     return ($NO_ITEMS_ADDED);
  }

  my $Hf = new Headfile ('rw', $headfile_path);
  my $ok = $Hf->check;
  if (! $ok ) {
     print STDERR "$SCRIPT_NAME ERROR add comments: headfile $headfile_path not opened properly.\n";
     return ($NO_ITEMS_ADDED);
  }
  else {
    print STDERR "$SCRIPT_NAME headfile $headfile_path OK.\n" if $DEBUG;
  }
  $ok = $Hf->read_headfile;

  foreach my $comment (@comment_list) {
    print STDERR "   adding comment:  $comment\n" if $DEBUG;
    $Hf->set_comment($comment);
    $nitems_added++;
  }
  $ok = $Hf->write_headfile($headfile_path);
  if (! $ok ) {
     print STDERR "$SCRIPT_NAME add items ERROR: headfile $headfile_path not written properly.\n"; 
     return ($NO_ITEMS_ADDED);
  }
  print STDERR "$SCRIPT_NAME added $nitems_added comments to headfile $headfile_path.\n" if $DEBUG;
  return ($nitems_added)
}

1;


