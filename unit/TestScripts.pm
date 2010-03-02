# Copyright (C) 2009-2010 Sun Microsystems, Inc. All rights reserved.
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

# Do a simple run of scripts to see that they're sound
#
package TestScripts;
use base qw(Test::Unit::TestCase);
use lib 'lib';

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

my $generator;
sub set_up {
}

sub tear_down {
    # clean up after test
}

sub test_gensql {
    my $self = shift;

    my $status = system("perl gensql.pl --grammar=conf/examples/example.yy --dsn=dummy --queries=1");

    $self->assert_equals(0, $status);

    my $status = system("perl gensql.pl --grammar=unit/testStack.yy --dsn=dummy --queries=5");

    $self->assert_equals(0, $status);

}

sub test_gendata {
    my $self = shift;

    my $status = system("perl gendata.pl --spec=conf/examples/example.zz --dsn=dummy");

    $self->assert_equals(0, $status);
}

sub test_gendata_old {
    my $self = shift;

    my $status = system("perl gendata-old.pl --dsn=dummy");

    $self->assert_equals(0, $status);
}

sub test_gentest {
    my $self = shift;

    my $status = system("perl gentest.pl --dsn=dummy --grammar=conf/examples/example.yy --threads=1 --queries=1");

    $self->assert_equals(0, $status);

    $status = system("perl gentest.pl --dsn=dummy --grammar=conf/examples/example.yy --threads=1 --queries=1 --mask=10 --mask-level=2");

    $self->assert_equals(0, $status);
}

sub test_runall {
    return if $ENV{MYSQL_BUILD_OUT_OF_SOURCE}; ## runall does not work with out of source builds
    my $self = shift;
    ## This test requires RQG_MYSQL_BASE to point to a in source Mysql database
    if ($ENV{RQG_MYSQL_BASE}) {
        $ENV{LD_LIBRARY_PATH}=join(":",map{"$ENV{RQG_MYSQL_BASE}".$_}("/libmysql/.libs","/libmysql","/lib/mysql"));
        my $status = system("perl ./runall.pl --grammar=conf/examples/example.yy --gendata=conf/examples/example.zz --queries=1 --threads=1 --basedir=".$ENV{RQG_MYSQL_BASE});
        $self->assert_equals(0, $status);
    }
}

sub test_runall_new {
    my $self = shift;
    ## This test requires RQG_MYSQL_BASE to point to a Mysql database (in source, out of source or installed)
    if ($ENV{RQG_MYSQL_BASE}) {
        $ENV{LD_LIBRARY_PATH}=join(":",map{"$ENV{RQG_MYSQL_BASE}".$_}("/libmysql/.libs","/libmysql","/lib/mysql"));
        my $status = system("perl ./runall-new.pl --mtr-build-thread=1212 --grammar=conf/examples/example.yy --gendata=conf/examples/example.zz --queries=1 --threads=1 --basedir=".$ENV{RQG_MYSQL_BASE});
        $self->assert_equals(0, $status);
    }
}

1;
