# Webservices.pm

# created sally gewalt 2010/9/8 

package Webservices;

my $version = "2010/09/08";
use strict;
use English;
## Carp:Heavy needed to detaint perl's own carp for DBI:Oracle
#use lib '/usr/local/lib/perl5/5.8.6/Carp';
#use Heavy;

# Indicate where archive related modules are found
# ##use lib '/Users/oracle/Source/perl/dir_dbi';
# use Env qw(ATLAS_SCRIPT_DIR);
# if (! defined($ATLAS_SCRIPT_DIR)) {
#     print ("Environment variable ATLAS_SCRIPT_DIR must be set.", 4);
# }
# use lib "$ATLAS_SCRIPT_DIR/dir_dbi";
my $ERROR_EXIT=0;
use Env qw(RADISH_PERL_LIB);
if (! defined($RADISH_PERL_LIB)) {
    print STDERR "Cannot find good perl directories, quiting\n";
    exit $ERROR_EXIT;
}
use lib split(':',$RADISH_PERL_LIB);
use Query;
use base_dbi;

#$ENV{'PATH'} = ''; # for -T

my $WEBSERVICES_ORACLE_USER = "webservice_user";  
   # this user needs access to both scan and spec schemas:
   # select only privs on several tables 
   # scan.item, specowner.animal, specowner.project, scan.rdarchiveinfo ;

my $BADEXIT = 1;
my $GOODEXIT = 0;

# command line settings affecting action
my $DUNSEL = 0; # runs thru all code (for testing really)
my $CHECK = 0;  # check headfile as possible: but no archive/db action 

my $db_open = 0;

# ------------
sub new {
# ------------
  # constructor of object of webservice class
  # When you call, the first argument is automatically added to the argument list
  # and contains the class name, so use no explicit $classname in call.

  my ($classname) = @_;
  # ----first argument is automatically added to the calling param list
  #     and contains the class name, so use no explicit $classname in call.

  my $self = {};
  $self->{'__oracle_connected'}  = 0;
  $self->{'__dbh'}               = 'not_connected';

  my $login = "$WEBSERVICES_ORACLE_USER/handyview"; # read only user on scan 
  my $instance = "orcl";
  my ($dbh, $msg) = base_dbi::connect_deepthought_db($login,$instance);
  if (!$dbh) {
     # is your perl the single threaded perl with dbi installed?
     my $msg2  = "Webservices.pm: Unable to open database:\n   $msg";
     print stderr $msg2;
     print $msg2;
  }
  $db_open = 1;
  $self->{'__oracle_connected'}  = 1;
  $self->{'__dbh'} = $dbh;

  bless $self, $classname; # Tell self it contains the address of an object of "package classname"
  return ($self);
}


# ------------
sub Close {
# ------------
  my ($self, $runno) = @_;
# disconnect from db
  if (! $self->{'__oracle_connected'}) {
     print stderr "Webservices::Close: NOT CONNECTION TO ORACLE, already closed\n";
  }
  else {
    base_dbi::rollback_dbhandle($self->{'__dbh'});  # should have made no changes 
    base_dbi::close_dbhandle   ($self->{'__dbh'});
    $self->{'__oracle_connected'} = 0;
    $self->{'__dbh'} = 'not_connected';
    print stderr "Webservices::Close successful\n";
  }
}

# ------------
sub RunnoExists {
# ------------
  my ($self, $runno) = @_;
  if (! $self->{'__oracle_connected'}) {
     print stderr "NO CONNECTION TO ORACLE, try Webservices->new()\n";
     return (0,"NO ORACLE");
  }
  my $oracle_msg1;
  my $oracle_msg2;
  my $result;
  ($result, $oracle_msg1) = exists_in_db ($self->{'__dbh'}, 'runno', $runno, 'scan.itemrun'); 
  my $query1_ok_bool    = $oracle_msg1 eq "ok" ? 1 : 0;
  my $runno_exists_bool = ($result eq $runno ) ? 1 : 0;
#  print "runno:      $runno, $result==$runno_exists_bool, $oracle_msg1, meok=$query1_ok_bool\n";

  ($result, $oracle_msg2) = exists_in_db ($self->{'__dbh'}, 'uniquename', $runno, 'scan.rdarchiveinfo'); 
  my $query_ok_bool     = ($oracle_msg2 eq "ok") && $query1_ok_bool ? 1 : 0;
  my $runno_exists_bool = ($result eq $runno) || $runno_exists_bool ? 1 : 0;
#  print "uniquename: $runno, $result==$runno_exists_bool, $oracle_msg2, bothok=$query_ok_bool \n";

#  print "final:     $runno, exists=$runno_exists_bool, query=$query_ok_bool\n";

  return ($query_ok_bool, $runno_exists_bool, "$oracle_msg1, $oracle_msg2\n ");
}

# ------------
sub SpecidExists {
# ------------
  my ($self, $specid) = @_;
  if (! $self->{'__oracle_connected'}) {
     print stderr "NO CONNECTION TO ORACLE, try Webservices->new()\n";
     return (0,"NO ORACLE");
  }
  my ($result, $oracle_msg) = exists_in_db ($self->{'__dbh'}, 'labspecimenid', $specid, 'specowner.specimen'); 
  my $query_ok_bool     = $oracle_msg eq "ok" ? 1 : 0;
  my $exists_bool = $result             ? 1 : 0;

  return ($query_ok_bool, $exists_bool, $oracle_msg);
}
# ------------
sub ProjectExists {
# ------------
  my ($self, $project) = @_;
  if (! $self->{'__oracle_connected'}) {
     print stderr "NO CONNECTION TO ORACLE, try Webservices->new()\n";
     return (0,"NO ORACLE");
  }
  my ($result, $oracle_msg) = exists_in_db ($self->{'__dbh'}, 'projectcode', $project, 'specowner.project');
  my $query_ok_bool = $oracle_msg eq "ok" ? 1 : 0;
  my $exists_bool   = $result             ? 1 : 0;

  return ($query_ok_bool, $exists_bool, $oracle_msg);
}
# ------------
sub SpecidMatchProject {
# ------------
    #assuming specid exists, look to see if it matches the project specified...
    # doesnt check if the project you asked for exists, just that your specimen references it.
    my ($self, $project,$specid) = @_;
    if (! $self->{'__oracle_connected'}) {
	print stderr "NO CONNECTION TO ORACLE, try Webservices->new()\n";
      return (0,"NO ORACLE");
    } 
    my ($result, $oracle_msg) = db_listing ($self->{'__dbh'}, 'projectcode','labspecimenid', $specid, 'specowner.specimen');
    my $query_ok_bool = $oracle_msg eq "ok" ? 1 : 0;
    my $match_bool    = $result     eq "$project" ? 1 : 0;    
    #if ( ! $match_bool ) { print ( "$project is not $result\n");}

    return ($query_ok_bool, $match_bool, $oracle_msg,$result);
}

# --- local subs
# ------------
sub QueryTest {
    my ($self) = @_;#, $out_column, $column, $value, $full_table_name) = @_;
    my $dbh=$self->{'__dbh'};
    #my $sql = "select $out_column from $full_table_name where $column=\'$value\'";
    my $sql = "select projectcode from specowner.specimen where labspecimenid=\'140227-5:0\'";
    print "sql = $sql\n";
    my $query = new Query ($dbh);
    #my ( $msg,@result) = $query->sql_on_fly_single_result_multiple_rows($sql);#_multiple_rows
    my ($result, $msg) = $query->sql_on_fly_single_result($sql);#_multiple_rows
    if ($msg ne "ok") {
        print "QueryTest: SQL Statement failure<$sql>\n $msg";
    } else {
	#print join("\n",@result);
	print $result;
    }
	
    
    return ;#($result, $msg);
}

#
sub db_listing {
# ------------
  my ($dbh, $out_column, $column, $value, $full_table_name) = @_;
  my $sql = "select $out_column from $full_table_name where $column=\'$value\'";
  #print "sql = $sql\n";
  my $query = new Query ($dbh);
  my ($result, $msg) = $query->sql_on_fly_single_result($sql); #multiple_rows
  if ($msg ne "ok") {
        print "exists_in_db: Unable to $sql\n $msg";
  }
  return ($result, $msg); 
}

# ------------
sub exists_in_db {
# ------------
  my ($dbh, $column, $value, $full_table_name) = @_;

  my $sql ;
  if ( $value =~ /%/x) {
      $sql = "select $column from $full_table_name where $column like \'$value\'";
  } else {
      $sql = "select $column from $full_table_name where $column=\'$value\'";
  }

  #print "sql = $sql\n";
  my $query = new Query ($dbh);
  my ($result, $msg) = $query->sql_on_fly_single_result($sql);
  if ($msg ne "ok") {
        print "exists_in_db: Unable to $sql\n $msg";
  }
  return ($result, $msg); 
}

1;
