# read_paramfile.pm
#
# created 4/11/00 Sally Gewalt CIVM 
#  
# Read a file of parameters in standard form to a hash
# named by argument
# so that the parameters can be used (e.g. add them to a headfile). 

# The standard form for the file is:
#  text  name=value    one per line
#  lines starting with # are ok 

# This package has routines to:
# * Read the param file into associative array
# * print the current associative array as text for documentation.

package read_paramfile; # avoid main's globals
use headers_main; # for parse_line sub.

my $version = "000411";
my $debug = 0;
my @header_comments;     # list of comments encountered or added 

sub readfile 
{
# Turns text of file into associative array.  
# Text is added to array passed in.
# Throws away comments.
# Returns the hash.

  my ($param_file) = @_;
 #  %here_hash = %$hash_ref};

  #--- get header off file to plain list form
  #    or get header info from .headfile text file = "civm_headfile" type.

  # assume the file itself is in the right format 
  $status = open (SESAME, $param_file);
  if ($status != 0) { $status=1; } # good 

  if ($status) {
  # stream to list
  @all_lines = <SESAME>;
  close (SESAME);

  #--- convert list form to hash

  my $l;
  @header_comments = ();
  foreach $l (@all_lines) {

     ($is_empty, $field, $value, $is_comment, $the_comment, $error) =
          headers_main::parse_line($l);

     if ($error) { return 0;} 


     if (! $is_empty) {
        if ($is_comment) {
            push (@header_comments, $l);
        }
        else {
            $here_hash{$field} = $value;
         }
     }

   }
  }
  $here_hash{status} = $status;

  return  (%here_hash) ;
}

sub print_array
{
  my %myhash = @_;
  print "# Printed by read_paramfile.pm::print_array $version.\n";
  foreach $c (@header_comments) {
     print "$c";
  }
  # sort the keys before printing
  @k = keys %myhash;
  @sk = sort (@k);

  for $k (@sk) {
     print "$k=$myhash{$k}\n";
  }
} 

sub file_array
# send array info to file provided
# return ok
{
  ($outfile, %param_hash) = @_;

  if (! defined open SESAME2, ">$outfile") {
    print "   * Unable to open file $outfile to write array info.\n";
    return 0;
  }

  # sort the keys before printing
  @k = keys %param_hash;
  @sk = sort (@k);

  for $k (@sk) {
     print SESAME2 "$k=$param_hash{$k}\n";
  }

  close SESAME2;
  return 1;
}

return 1;
