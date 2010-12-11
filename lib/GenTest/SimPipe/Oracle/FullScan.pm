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
#

package GenTest::SimPipe::Oracle::FullScan;

require Exporter;
@ISA = qw(GenTest::SimPipe::Oracle GenTest);
@EXPORT = qw();

use strict;
use DBI;
use GenTest;
use GenTest::SimPipe::Oracle;
use GenTest::Constants;
use GenTest::Executor;
use GenTest::Comparator;

1;

my %option_defaults = (
        'optimizer_use_mrr'             => 'disable',
        'mrr_buffer_size'               => 262144,
        'join_cache_level'              => 0,
        'join_buffer_size'              => 131072,
        'join_buffer_space_limit'       => 1048576,
        'rowid_merge_buff_size'         => 8388608,
	'storage_engine'		=> 'MyISAM',
        'optimizer_switch'              => 'index_merge=off,index_merge_union=off,index_merge_sort_union=off,index_merge_intersection=off,index_condition_pushdown=off,firstmatch=off,loosescan=off,materialization=off,semijoin=off,partial_match_rowid_merge=off,partial_match_table_scan=off,subquery_cache=off,join_cache_incremental=off,join_cache_hashed=off,join_cache_bka=off,table_elimination=off,outer_join_with_cache=off'
);


sub oracle {
	my ($oracle, $testcase) = @_;

	my $executor = GenTest::Executor->newFromDSN($oracle->dsn());
	$executor->init();
	
	my $dbh = $executor->dbh();

	foreach my $option_name (keys %option_defaults) {
		if ($option_defaults{$option_name} =~ m{^\d+$}sio) {
			$dbh->do("SET SESSION $option_name = ".$option_defaults{$option_name});
		} else {
			$dbh->do("SET SESSION $option_name = '".$option_defaults{$option_name}."'");
		}
	}

	my $testcase_string = join("\n", (
		"CREATE DATABASE IF NOT EXISTS fullscan$$;",
		"USE fullscan$$;",
		$testcase->mysqldOptionsToString(),
		$testcase->dbObjectsToString()
        ));

	open (LD, '>/tmp/last_dump.test');
	print LD $testcase_string;
	close LD;

	$dbh->do($testcase_string, { RaiseError => 1 , mysql_multi_statements => 1 });

	my $original_query = $testcase->queries()->[0];
	my $original_result = $executor->execute($original_query);
        $testcase_string .= "\n$original_query;\n";

	my @table_names = @{$dbh->selectcol_arrayref("SHOW TABLES")};
	foreach my $table_name (@table_names) {
		$dbh->do("ALTER TABLE $table_name DISABLE KEYS");
	}

	$dbh->do("SET SESSION join_cache_level = 0");
	$dbh->do("SET SESSION optimizer_use_mrr = 'disable'");
	$dbh->do("SET SESSION optimizer_switch='".$option_defaults{'optimizer_switch'}."'");

	my $fullscan_result = $executor->execute($original_query);

	$dbh->do("DROP DATABASE fullscan$$");

        my $compare_outcome = GenTest::Comparator::compare($original_result, $fullscan_result);

	if (
		($original_result->status() != STATUS_OK) ||
		($fullscan_result->status() != STATUS_OK) ||
		($compare_outcome == STATUS_OK)
	) {
		return ORACLE_ISSUE_NO_LONGER_REPEATABLE;
	} else {
		open (LR, '>/tmp/last_repeatable.test');
		print LR $testcase_string;
		close LR;
		return ORACLE_ISSUE_STILL_REPEATABLE;
	}	
}

1;