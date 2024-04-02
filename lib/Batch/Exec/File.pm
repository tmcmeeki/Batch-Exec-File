package Batch::Exec::File;

=head1 NAME

Batch::Exec::File - general file handling for the Batch Executive Framework.

=head1 AUTHOR

Copyright (C) 2024  B<Tom McMeekin> tmcmeeki@cpan.org

=head1 SYNOPSIS

  use Batch::Exec::File;


=head1 DESCRIPTION

Add description here.

=head2 ATTRIBUTES

=over 4

=item OBJ->attribute1

Get ot set the blah blah blah.  A default applies.

=item OBJ->attribute2

Get ot set the blah blah blah.  A default applies.

=item OBJ->attribute3

Get ot set the blah blah blah.  A default applies.

=back

=cut

use strict;

use parent 'Batch::Exec';

# --- includes ---
use Carp qw(cluck confess);
use Data::Dumper;


# --- package constants ---
#use constant RE_DUMMY => qr/^\s*$/;


# --- package globals ---
our $AUTOLOAD;
#our @EXPORT = qw();
#our @ISA = qw(Exporter);
our @ISA;
our $VERSION = sprintf "%d.%03d", q[_IDE_REVISION_] =~ /(\d+)/g;


# --- package locals ---
my $_n_objects = 0;

my %_attribute = (	# _attributes are restricted; no direct get/set
	_hidden => 1,		# boolean: class global bar value
	attribute1 => "dummy",
	attribute2 => RE_DUMMY,
	attribute3 => undef,
);

#sub INIT { };

sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) or confess "$self is not an object";

	my $attr = $AUTOLOAD;
	$attr =~ s/.*://;   # strip fully−qualified portion

	confess "FATAL older attribute model"
		if (exists $self->{'_permitted'} || !exists $self->{'_have'});

	confess "FATAL no attribute [$attr] in class [$type]"
		unless (exists $self->{'_have'}->{$attr} && $self->{'_have'}->{$attr});
	if (@_) {
		return $self->{$attr} = shift;
	} else {
		return $self->{$attr};
	}
}


sub DESTROY {
	local($., $@, $!, $^E, $?);
	my $self = shift;

	#printf "DEBUG destroy object id [%s]\n", $self->{'_id'});

	-- ${ $self->{_n_objects} };
}


sub new {
	my ($class) = shift;
	my %args = @_;	# parameters passed via a hash structure

	my $self = $class->SUPER::new;	# for sub-class
	my %attr = ('_have' => { map{$_ => ($_ =~ /^_/) ? 0 : 1 } keys(%_attribute) }, %_attribute);

	bless ($self, $class);

	map { push @{$self->{'_inherent'}}, $_ if ($attr{"_have"}->{$_}) } keys %{ $attr{"_have"} };

	while (my ($attr, $dfl) = each %attr) { 

		unless (exists $self->{$attr} || $attr eq '_have') {
			$self->{$attr} = $dfl;
			$self->{'_have'}->{$attr} = $attr{'_have'}->{$attr};
		}
	}

	while (my ($method, $value) = each %args) {

		confess "SYNTAX new(, ...) value not specified"
			unless (defined $value);

		$self->log->debug("method [self->$method($value)]");

		$self->$method($value);
	}
	# ___ additional class initialisation here ___
#	$self->log->debug(sprintf "self [%s]", Dumper($self));

	return $self;
}

=head2 METHODS

=over 4

=item OBJ->method1(EXPR, ...)

Returns ___

=cut

sub method1 {
	my $self = shift;
	my $expr = shift;

	$self->log->logconfess("SYNTAX method1(EXPR)") unless (
		defined($expr));

	return ___;
}

=back

=head2 ALIASED METHODS

The following method aliases have also been defined:

	alias		base method
	------------	------------	
	isnt_foo	is_notfoo
	isnt_bar	is_notbar

=cut

#*isnt_foo = \&is_notfoo;
#*isnt_bar = \&is_notbar;

#sub END { }

1;

__END__


=head1 VERSION

_IDE_REVISION_

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published
by the Free Software Foundation; either version 3 of the License,
or any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 SEE ALSO

L<perl>.

=cut

