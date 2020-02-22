# Copyright (c) 2008, 2011, Oracle and/or its affiliates. All rights
# reserved.
# Copyright (c) 2018, 2019 MariaDB Corporation
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

## Handling of config properties and options
## 
## default: Default values
## options: The hashgenerated by Getoptions
## required: required properties
## legal: additional legal properties. The final set of legal
##        properties is the union between default, options, required
##        and legal. 
## legal and required is not (yet) recursive defined.
##
## Usage:
## my $options = {}
## GetOptions($options,'config=s'................);
## my $config=GenTest::Properties->new(options=>$options......);

##
package GenTest::Properties;

@ISA = qw(GenTest);

use strict;
use Carp;
use GenTest;
use GenTest::Constants;

use Data::Dumper;

use constant PROPS_NAME => 0;
use constant PROPS_DEFAULTS => 1; ## Default values
use constant PROPS_OPTIONS => 2;  ## Legal options to check for
use constant PROPS_HELP => 3;     ## Help text
use constant PROPS_LEGAL => 4;    ## List of legal properies
use constant PROPS_LEGAL_HASH => 5; ## Hash of legal propertis
use constant PROPS_REQUIRED => 6; ## Required properties
use constant PROPS_PROPS => 7;    ## the actual properties

1;

##
## AUTOLOAD function intercepts all calls to undefined methods. Use
## (if defined) PROPS_LEGAL_HASH to decide if the wanted property is
## legal. All intercpeted method calls will return
## $self->[PROPS_PROPS]->{$name}

sub AUTOLOAD {
    my ($self,$arg) = @_;
    my $name = our $AUTOLOAD;
    $name =~ s/.*:://;
    
    ## Avoid catching DESTRY et.al. (no intercepted calls to methods
    ## starting with an uppercase letter)
    return unless $name =~ /[^A-Z]/;
    
    if (defined $self->[PROPS_LEGAL_HASH]) {
        croak("Illegal property '$name' caught by AUTOLOAD ") 
            if not $self->[PROPS_LEGAL_HASH]->{$name};
    }
    
    $self->[PROPS_PROPS]->{$name} = $arg if defined $arg;
    return $self->[PROPS_PROPS]->{$name};
}

## Constructor

sub new {
    my $class = shift;
    
	my $props = $class->SUPER::new({
	    'name' => PROPS_NAME,
	    'defaults'	=> PROPS_DEFAULTS,
	    'required'	=> PROPS_REQUIRED,
	    'options' => PROPS_OPTIONS,
	    'legal' => PROPS_LEGAL,
	    'help' => PROPS_HELP ## disabled since I get weird warning....
       }, @_);
    
    ## List of legal properties, if no such list, all properties are
    ## legal. The PROPS_LEGAL_HASH becomes the union of PROPS_LEGAL,
    ## PROPS_REQURED, PROPS_OPTIONS (specified on command line and
    ## decided from argument to getoptions) and PROPS_DEFAULTS

    if (defined $props->[PROPS_LEGAL]) {
        foreach my $legal (@{$props->[PROPS_LEGAL]}) {
            $props->[PROPS_LEGAL_HASH]->{$legal}=1;
        }
    }
    
    if (defined $props->[PROPS_REQUIRED]) {
        foreach my $legal (@{$props->[PROPS_REQUIRED]}) {
            $props->[PROPS_LEGAL_HASH]->{$legal}=1;
        }
    }
    
    if (defined $props->[PROPS_OPTIONS]) {
        foreach my $legal (keys %{$props->[PROPS_OPTIONS]}) {
            $props->[PROPS_LEGAL_HASH]->{$legal}=1;
        }
    }
    if (defined $props->[PROPS_DEFAULTS]) {
        foreach my $legal (keys %{$props->[PROPS_DEFAULTS]}) {
            $props->[PROPS_LEGAL_HASH]->{$legal}=1;
        }
    }
    

    ## Pick up defaults
    
    my $defaults = $props->[PROPS_DEFAULTS];
    $defaults = {} if not defined $defaults;
    
    ## Pick op command line uptions
    
    my $from_cli = $props->[PROPS_OPTIONS];
    $from_cli = {} if not defined $from_cli;
    
    ## Pick up settings from config file if present

    my $from_file = {};
    
    if ($from_cli->{config}) {
        $from_file = _readProps($from_cli->{config});
    }
    
    ## Calculate settings.
    ## 1: Let defaults be overridden by configfile
    $props->[PROPS_PROPS] = _mergeProps($defaults, $from_file);
    ## 2: Let the command line options override the mege of the two
    ## above
    $props->[PROPS_PROPS] = _mergeProps($props->[PROPS_PROPS], $from_cli);
    
    ## Check for illegal properties
    ## 
    my @illegal;
    if (defined $props->[PROPS_LEGAL_HASH]) {
        foreach my $p (keys %{$props->[PROPS_PROPS]}) {
            if (not exists $props->[PROPS_LEGAL_HASH]->{$p}) {
                push(@illegal,$p);
            }
        }
    }
    ## Check if all required properties are set.
    my @missing;
    if (defined $props->[PROPS_REQUIRED]) {
        foreach my $p (@{$props->[PROPS_REQUIRED]}) {
            push (@missing, $p) if not exists $props->[PROPS_PROPS]->{$p};
        }
    }
    
    my $message;
    $message .= "The following properties are not legal: ".
        join(", ", map {"'--".$_."'"} sort @illegal). ". " if $#illegal >= 0;

    $message .= "The following required properties  are missing: ".
        join(", ", map {"'--".$_."'"} sort @missing). ". " if $#missing >= 0;

    if (defined $message) {
        $props->_help();
        croak($message);
    }
    
    return $props;
}

sub init {
  my ($class, $props)= @_;
  my $gentestProps= $class->new(
    legal => ['grammar',
              'skip-recursive-rules',
              'dsn',
              'engine',
              'gendata',
              'gendata-advanced',
              'generator',
              'redefine',
              'threads',
              'queries',
              'duration',
              'help',
              'debug',
              'rpl_mode',
              'validators',
              'reporters',
              'transformers',
              'seed',
              'mask',
              'mask-level',
              'metadata',
              'rows',
              'varchar-length',
              'xml-output',
              'vcols',
              'views',
              'start-dirty',
              'filter',
              'notnull',
              'short_column_names',
              'strict_fields',
              'freeze_time',
              'valgrind',
              'valgrind-xml',
              'testname',
              'sqltrace',
              'querytimeout',
              'report-xml-tt',
              'report-xml-tt-type',
              'report-xml-tt-dest',
              'logfile',
              'logconf',
              'debug_server',
              'report-tt-logdir',
              'servers',
              'multi-master',
              'annotate-rules',
              'restart-timeout',
              'ps-protocol',
              'partitions',
      ]
  );

  $gentestProps->property('annotate-rules',$props->{annotate_rules}) if defined $props->{annotate_rules};
  $gentestProps->property('debug',1) if defined $props->{debug};
  $gentestProps->property('debug_server',$props->{debug_server}) if $props->{debug_server};
  $gentestProps->property('dsn',$props->{dsns}) if $props->{dsns};
  $gentestProps->property('duration',$props->{duration}) if defined $props->{duration};
  $gentestProps->property('engine',$props->{engine}) if $props->{engine};
  $gentestProps->property('filter',$props->{filter}) if defined $props->{filter};
  $gentestProps->property('freeze_time',$props->{freeze_time}) if defined $props->{freeze_time};
  $gentestProps->property('gendata',$props->{gendata}) if exists $props->{gendata};
  $gentestProps->property('gendata-advanced',1) if defined $props->{gendata_advanced};
  $gentestProps->property('generator','FromGrammar') if not defined $gentestProps->property('generator');
  $gentestProps->property('grammar',$props->{grammar});
  $gentestProps->property('queries',$props->{queries}) if defined $props->{queries};
  $gentestProps->property('logconf',$props->{logconf}) if defined $props->{logconf};
  $gentestProps->property('logfile',$props->{logfile}) if defined $props->{logfile};
  $gentestProps->property('mask',$props->{mask}) if (exists $props->{mask});
  $gentestProps->property('mask-level',$props->{mask_level}) if defined $props->{mask_level};
  $gentestProps->property('metadata',(defined $props->{metadata} ? $props->{metadata} : 1)); # By default metadata is loaded
  $gentestProps->property('multi-master',1) if $props->{'multi-master'};
  $gentestProps->property('notnull',$props->{notnull}) if defined $props->{notnull};
  $gentestProps->property('ps-protocol',1) if $props->{ps_protocol};
  $gentestProps->property('querytimeout',$props->{querytimeout}) if defined $props->{querytimeout};
  $gentestProps->property('redefine',$props->{redefine}) if $props->{redefine};
  $gentestProps->property('report-tt-logdir',$props->{report_tt_logdir}) if defined $props->{report_tt_logdir};
  $gentestProps->property('report-xml-tt',1) if defined $props->{report_xml_tt};
  $gentestProps->property('report-xml-tt-dest',$props->{report_xml_tt_dest}) if defined $props->{report_xml_tt_dest};
  $gentestProps->property('report-xml-tt-type',$props->{report_xml_tt_type}) if defined $props->{report_xml_tt_type};
  $gentestProps->property('reporters',$props->{reporters}) if $props->{reporters};
  $gentestProps->property('restart-timeout',$props->{restart_timeout}) if defined $props->{restart_timeout};
  $gentestProps->property('rows',$props->{rows}) if defined $props->{rows};
  $gentestProps->property('rpl_mode',$props->{rpl_mode}) if defined $props->{rpl_mode};
  $gentestProps->property('seed',$props->{seed}) if defined $props->{seed};
  $gentestProps->property('servers',$props->{server}) if $props->{server};
  $gentestProps->property('short_column_names',$props->{short_column_names}) if defined $props->{short_column_names};
  $gentestProps->property('skip-recursive-rules',$props->{skip_recursive_rules});
  $gentestProps->property('sqltrace',$props->{sqltrace}) if $props->{sqltrace};
  $gentestProps->property('start-dirty',1) if defined $props->{start_dirty};
  $gentestProps->property('strict_fields',$props->{strict_fields}) if defined $props->{strict_fields};
  $gentestProps->property('testname',$props->{testname}) if $props->{testname};
  $gentestProps->property('threads',$props->{threads}) if defined $props->{threads};
  $gentestProps->property('transformers',$props->{transformers}) if $props->{transformers};
  $gentestProps->property('valgrind',1) if $props->{valgrind};
  $gentestProps->property('validators',$props->{validators}) if $props->{validators};
  $gentestProps->property('varchar-length',$props->{varchar_len}) if defined $props->{varchar_len};
  $gentestProps->property('vcols',$props->{vcols}) if $props->{vcols};
  $gentestProps->property('views',$props->{views}) if $props->{views};
  $gentestProps->property('xml-output',$props->{xml_output}) if defined $props->{xml_output};
  $gentestProps->property('partitions',$props->{partitions}) if defined $props->{partitions};

  # In case of multi-master topology (e.g. Galera with multiple "masters"),
  # we don't want to compare results after each query.
  # Instead, we want to run the flow independently and only compare dumps at the end.
  # If GenTest gets 'multi-master' property, it won't run ResultsetComparator

  $gentestProps->property('multi-master',1) if (defined $props->{galera} and scalar(@{$props->{dsns}})>1);

  return $gentestProps;
}


## Basic set/get method. Note that $x->property('string') is the same
## as $x->string and that $x->property('string', value) is the same as
## $x->string(value). Useful for propertys that can't be perl
## subroutine names.

sub property {
    my ($self, $name, $arg) = @_;

    if (defined $self->[PROPS_LEGAL_HASH]) {
        croak("Illegal property '$name' caught by AUTOLOAD ") 
            if not $self->[PROPS_LEGAL_HASH]->{$name};
    }
    
    $self->[PROPS_PROPS]->{$name} = $arg if defined $arg;
    return $self->[PROPS_PROPS]->{$name};
    
}
# Since the basic set/get cannot set a property to 'undef',
# we need a separate method to unset an existing property
sub unsetProperty {
    my ($self, $name) = @_;

    if (defined $self->[PROPS_LEGAL_HASH]) {
        croak("Illegal property '$name' caught by AUTOLOAD ")
            if not $self->[PROPS_LEGAL_HASH]->{$name};
    }

    $self->[PROPS_PROPS]->{$name} = undef;
    return $self->[PROPS_PROPS]->{$name};
}
## Read properties from a given file
sub _readProps {
    my ($file) = @_;
    open(PFILE, $file) or croak "Unable to read properties file '$file': $!";
    read(PFILE, my $propfile, -s $file);
    close PFILE;
    my $props = eval($propfile);
    croak "Unable to load $file: $@" if $@;
    return $props;
}

## Merge properties recursively
sub _mergeProps {
    my ($a,$b) = @_;
    
    # First recursively deal with hashes
    my $mergedHashes = {};
    foreach my $h (keys %$a) {
        if (UNIVERSAL::isa($a->{$h},"HASH")) {
            if (defined $b->{$h}) {
                $mergedHashes->{$h} = _mergeProps($a->{$h},$b->{$h});
            }
        }
    }
    # The merge
    my $result = {%$a, %$b};
    $result = {%$result,  %$mergedHashes};
    return $result;
}

sub printHelp {
    $_[0]->_help;
}

## Global print method
sub printProps {
    my ($self) = @_;
    _printProps($self->[PROPS_PROPS]);
}

## Internal print method
sub _printProps {
    my ($props,$indent) = @_;
    $indent = 1 if not defined $indent;
    my $x = join(" ", map {undef} (1..$indent*3));
    foreach my $p (sort keys %$props) {
        if (UNIVERSAL::isa($props->{$p},"HASH")) {
            say ($x .$p." => ");
            _printProps($props->{$p}, $indent+1);
	} elsif  (UNIVERSAL::isa($props->{$p},"ARRAY")) {
        say ($x .$p." => ['".join("', '",@{$props->{$p}})."']");
        } else {
            say ($x.$p." => ".$props->{$p});
        }
    }
}

## Remove proerties set to defined
sub _purgeProps {
    my ($props) = @_;
    my $purged = {};
    foreach my $key (keys %$props) {
        $purged->{$key} = $props->{$key} if defined $props->{$key};
    }
    return $purged;
}

## Generate a option list from a hash. The hash may be tha name of a
## property. The prefix may typically be '--' or '--mysqld=--' for
## Mysql and friends use.
sub genOpt {
    my ($self, $prefix, $options) = @_;

    my $hash;
    if (UNIVERSAL::isa($options,"HASH")) {
        $hash = $options;
    } else {
        $hash = $self->$options;
    }
    
    return join(' ', map {$prefix.$_.(defined $hash->{$_}?
                                      ($hash->{$_} eq ''?
                                       '':'='.$hash->{$_}):'')} keys %$hash);
}

## Collect all or specified non-hash/array options into new option string where
## options are separated by a single space.
## If an array of strings is passed as second argument, only options specified
## in the array will be included.
## If such an array is omitted, all top-level options will be included.
## A prefix is added to each option, similar to sub genOpt.
sub collectOpt {
    # @include is an array specifying property keys to include.
    # If such a list is not provided, all non-complex properties are included.
    my ($self, $prefix, @include) = @_;
    my $props = $self->[PROPS_PROPS];       # all properties (options)
    my @opts;                               # properties (options) to collect

    if (@include) {
        foreach my $key (@include) {
            if (exists $props->{$key}) {
                if (UNIVERSAL::isa($props->{$key}, "HASH")) {
                } elsif (UNIVERSAL::isa($props->{$key}, "ARRAY")) {
                } else {
                    if (defined $props->{$key} and $props->{$key} ne '') {
                        push(@opts, $prefix.$key.'='.$props->{$key});
                    } else {
                        push(@opts, $prefix.$key);
                    }
                }
            }
        }
    } else {
        # No list of options to include was specified.
        # Inlcude all top-level options.
        foreach my $key (keys %$props) {
            if (UNIVERSAL::isa($props->{$key},"HASH")) {
            } elsif  (UNIVERSAL::isa($props->{$key},"ARRAY")) {
            } else {
            if (defined $props->{$key} and $props->{$key} ne '') {
                    push(@opts, $prefix.$key.'='.$props->{$key});
                } else {
                    push(@opts, $prefix.$key);
                }
            }
        }
    }
    
    return join(' ',@opts);
}

## Help routine!
sub _help {
    my ($self) = @_;

    if (defined $self->[PROPS_HELP]) {
        if (UNIVERSAL::isa($self->[PROPS_HELP],"CODE")) {
            ## Help routine provided
            &{$self->[PROPS_HELP]};
        } else {
            ## Help text provided
            print $self->[PROPS_HELP]."\n";
        }
    } else {
        ## Generic help (not very helpful, but better than nothing).
        print "$0 - Legal properties/options:\n";
        my $required = {map {$_=>1} @{$self->[PROPS_REQUIRED]}};
        foreach my $k (sort keys %{$self->[PROPS_LEGAL_HASH]}) {
            ## Required, command line options etc should be marked.
            print "    --$k ".(defined $required->{$k}?"(required)":"").",\n";
        }
    }
}

1;
