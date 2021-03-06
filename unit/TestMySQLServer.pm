# Copyright (c) 2010,2012 Oracle and/or its affiliates. All rights reserved.
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

package TestMySQLServer;

use base qw(Test::Unit::TestCase);
use lib 'lib','lib/DBServer';
use Cwd;
use GenTest;
use DBServer::DBServer;
use DBServer::MySQL::MySQLd;
use GenTest::Executor;
use GenTest::Properties;
use GenTest::Reporter;
use GenTest::Reporter::Backtrace;

use Data::Dumper;
use File::Path qw(mkpath rmtree);

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

sub set_up {
}

my @pids;

sub tear_down {
    if (osWindows) {
        ## Need to ,kill leftover processes if there are some
        foreach my $p (@pids) {
            Win32::Process::KillProcess($p,-1);
        }
    } else {
        ## Need to ,kill leftover processes if there are some
        kill 9 => @pids;
    }
    rmtree("unit/tmpwd");
}

sub create_server {
    my ($self, $debug_server) = @_;
    
    my $vardir= cwd()."/unit/tmpwd";

    my $portbase = 20 + ($ENV{TEST_PORTBASE}?int($ENV{TEST_PORTBASE}):22120);

    $self->assert(defined $ENV{RQG_MYSQL_BASE},"RQG_MYSQL_BASE not defined");

    my $server = DBServer::MySQL::MySQLd->new(basedir => $ENV{RQG_MYSQL_BASE},
                                              debug_server => $debug_server,
                                              vardir => $vardir,
                                              port => $portbase);
    $self->assert_not_null($server);

    my ($major, $minor, $build) = $server->versionNumbers;

    say("Major: $major, Minor: $minor, Build: $build");
    
    $self->assert(-f $vardir."/data/mysql/db.MYD","No ".$vardir."/data/mysql/db.MYD");
    
    $server->startServer;
    push @pids,$server->serverpid;
    
    my $dsn = $server->dsn("mysql");
    $self->assert_not_null($dsn);
    
    my $executor = GenTest::Executor->newFromDSN($dsn);
    $self->assert_not_null($executor);
    $executor->init();
    
    my $result = $executor->execute("show tables");
    $self->assert_not_null($result);
    $self->assert_equals($result->status, 0);
    
    say(join(',',map{$_->[0]} @{$result->data}));
    
    $self->assert(-f $vardir."/mysql.pid") if not osWindows();
    $self->assert(-f $vardir."/mysql.err");

    $server->stopServer;

    sayFile($server->errorlog);

    $server = DBServer::MySQL::MySQLd->new(basedir => $ENV{RQG_MYSQL_BASE},
                                           vardir => $vardir,
                                           debug_server => $debug_server,
                                           port => $portbase,
                                           start_dirty => 1);
    
    $self->assert_not_null($server);

    my $status=$server->startServer;
    $self->assert_not_null($status);   

    push @pids,$server->serverpid;
    $server->stopServer;

    sayFile($server->errorlog);
}

# Start server
sub test_create_server {
    my $self=shift;
    $self->create_server();
}

# Start a debug type server.
# Bug: 14155724 
sub test_create_debug_server {
    if (defined $ENV{RQG_TEST_DEBUG_SERVER}) {
        my $self = shift;
        $self->create_server(1);
    }
}

1;
