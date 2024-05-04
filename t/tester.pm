package tester;
#########################
# This module assist in testing the Tk dialog functions, by issuing
# button events and thus allowing the dialog to be seen "briefly".
#
# tester.pm - test harness for module Batch::Exec::File
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 2 of the License,
# or any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#########################
use strict;
use warnings;

use Carp qw(cluck confess);     # only use stack backtrace within class
use Data::Dumper;
use File::Basename;
use Log::Log4perl qw/ :easy /;
use Test::More;

use constant MY_CLASS => 'Batch::Exec::File';

our $AUTOLOAD;

my %attribute = (
	_planned => 0,
	condition => {},
	cycle => 0,
	executed => 0,
	files => [],
	log => get_logger(MY_CLASS),
	this => MY_CLASS,
);

# -------- standard routines --------
#INIT {
#	srand(time);
#};

sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) or confess "$self is not an object";

	my $name = $AUTOLOAD;
	$name =~ s/.*://;   # strip fully−qualified portion

	unless (exists $self->{_permitted}->{$name} ) {
		confess "no attribute [$name] in class [$type]";
	}

	if (@_) {
		return $self->{$name} = shift;
	} else {
		return $self->{$name};
	}
}


sub new {
	my ($class) = shift;
#	my ($test_class) = shift;
	my $self = { _permitted => \%attribute, %attribute };

	bless ($self, $class);

#	confess "SYNTAX new(TEST_CLASS) value not specified" unless (defined $test_class);

	my %args = @_;  # start processing any parameters passed
	my ($method,$value);
	while (($method, $value) = each %args) {

		confess "SYNTAX new(method => value, ...) value not specified"
			unless (defined $value);

		$self->log->debug("method [self->$method($value)]");

		$self->$method($value);
	}
#	$self->{'this'} = $test_class;

	return $self;
}


sub done {
	my $self = shift; 
	my $extra = shift;
 
	$self->{'executed'} += $extra
		if (defined $extra);

	done_testing($self->executed);
}

sub cond {
	my $self = shift;
	my $args = join(' ', @_);

	if (exists $self->condition->{$args}) {

		$self->condition->{$args}++;

	} else {

		$self->condition->{$args} = 1;
	}
	my $cycle = $self->condition->{$args};
#	my $cond = sprintf "%s cycle [%d]", $args, $self->cycle;
	my $cond = sprintf "%s cycle [%d]", $args, $cycle;

#	$self->log->debug(sprintf "condition [%s]", Dumper($self->condition));

	return $cond;
}

sub object {
	my $self = shift;
	my $class = $self->this;

	my $cond = $self->cond("class [$class]");

	$self->log->info(sprintf "instantiating $cond %s args", (@_) ? "with" : "without");

	my $obj = $class->new(@_);

	isa_ok($obj, $class,      "object $cond");

	return $obj;
}

sub planned {
	my $self = shift;
	my $n_tests = shift;

	confess "SYNTAX: plan(tests)" unless defined ($n_tests);

	$self->{'_planned'} = $n_tests;

	plan tests => $n_tests;
}


# -------- custom routines here --------
sub mkfn {
	my $self = shift;

#	my $fn = basename(__FILE__);
	my $fn = basename($0);
#	my $ext = sprintf "%03d", int(rand(1000));
	my $ext = scalar(@{ $self->files }) + 1;

	$fn =~ s/\.t$/_$ext/;
	$fn .= ".tmp";

	push @{ $self->files }, $fn;

	$self->log->debug(sprintf "files [%s]", Dumper($self->files));

	return $fn;
}

sub grepper {
	my $self = shift;
	my $obj = shift;
	my $got = shift;
	my $re = shift;
	confess "SYNTAX grepper(OBJ)" unless (
		defined($obj) && defined($got) && defined($re));

	my $fn = $self->files->[-1];
	$self->log->trace("fn [$fn]");

	my @lines = $obj->c2l("cat $fn");
	$self->log->trace(sprintf "lines [%s]", Dumper(\@lines));

	# ---- lines -----
	is(scalar(@lines), $obj->lines($fn),	$self->cond("lines"));

	my @found = grep(/$re/, @lines);
	$self->log->debug(sprintf "found [%s]", Dumper(\@found));

	is(scalar(@found), $got,	$self->cond("grep got"));
}

sub cleanup {
	my $self = shift;
	my $obj = shift;
	confess "SYNTAX cleanup(OBJ)" unless defined($obj);

	ok($obj->delete(@{ $self->files }) == 0,	$self->cond("cleanup"));
}


DESTROY {
	my $self = shift;

#	$self->log->debug(Dumper($self));
};

#END { }

1;

__END__


