# Copyright (C) 2018 MariaDB Corporation Ab. All rights reserved.
# Use is subject to license terms.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

package GenTest::Reporter::SecondaryIndexConsistency;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use DBI;
use GenTest;
use GenTest::Constants;
use GenTest::Reporter;
use GenTest::Comparator;
use Data::Dumper;
use IPC::Open2;
use IPC::Open3;

my $interval= 90;
my $first_reporter;
my $last_run= 0;

# Check that secondary indexes on InnoDB tables don't have orphan or missing records
# comparing to the PRIMARY key

sub monitor {
    my $reporter = shift;
    
    $first_reporter = $reporter if not defined $first_reporter;
    return STATUS_OK if $reporter ne $first_reporter;

    # Don't run the monitor too often, it's expensive
    return STATUS_OK if (time() - $last_run) < $interval;

    my $dbh = DBI->connect($reporter->dsn());

    say("Testing consistency of secondary indexes");

    my $tables = $dbh->selectcol_arrayref("SELECT CONCAT('`',table_schema,'`.`',table_name,'`') FROM information_schema.tables WHERE engine='InnoDB'");

    $dbh->do("SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED");
    foreach my $table (@$tables) {
        my $sth_keys = $dbh->prepare("SHOW KEYS FROM $table");
        $sth_keys->execute();

        # collect all columns included into the primary key and all names of secondary keys

        my @pk_columns;
        my %secondary_keys;

        while (my $key_hashref = $sth_keys->fetchrow_hashref()) {
            my $key_name = $key_hashref->{Key_name};
            if ($key_name eq 'PRIMARY') {
                push @pk_columns, '`'.$key_hashref->{Column_name}.'`';
            } else {
                $secondary_keys{'`'.$key_name.'`'}= 1;
            }
        }
        unless (scalar(@pk_columns)) {
          say("Table $table doesn't have a PRIMARY KEY, skipping");
          next;
        }
        my $pk_columns= join ',', @pk_columns;

        say("Verifying table: $table, PK columns: $pk_columns, indexes: ".join ',', keys %secondary_keys);

        $dbh->do("LOCK TABLE $table READ");
        my $pk_data= get_all_rows($dbh,"SELECT $pk_columns FROM $table FORCE INDEX(PRIMARY) ORDER BY $pk_columns");
        next unless defined $pk_data;
        
        KEY:
        foreach my $ind (keys %secondary_keys) {
            my $ind_data= get_all_rows($dbh,"SELECT $pk_columns FROM $table FORCE INDEX($ind) ORDER BY $pk_columns");
            next unless defined $ind_data;
            
            my $diff= GenTest::Comparator::dumpDiff($pk_data, $ind_data);
            if ($diff) {
                sayError("$diff");
                sayError("Found above difference for indexes PRIMARY and $ind for table $table");
                return STATUS_INNODB_INDEX_CORRUPTION;
            } else {
                say("Indexes PRIMARY and $ind produced identical data");
            }
        }
        $dbh->do("UNLOCK TABLES");
    }
    return STATUS_OK;
}

sub type {
    return REPORTER_TYPE_PERIODIC;
}

sub get_all_rows {
    my ($dbh, $stmt)= @_;
    my $sth= $dbh->prepare($stmt);
    if ($sth->err or $dbh->err) {
        sayError("Prepare for $stmt failed: ". ($sth->err ? $sth->errstr : $dbh->errstr));
        return undef;
    }
    $sth->execute;
    if ($sth->err or $dbh->err) {
        sayError("Execute for $stmt failed: ". ($sth->err ? $sth->errstr : $dbh->errstr));
        return undef;
    }
    return GenTest::Result->new(
            data => $sth->fetchall_arrayref);
}

1;