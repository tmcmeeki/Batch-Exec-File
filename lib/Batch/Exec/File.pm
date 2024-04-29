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

=item OBJ->quote

Get ot set the enforcement of quotes around fields in a CSV.  A default applies.

=item OBJ->munge

Get ot set the munge_column_names option for CSV input.  A default applies.

=item OBJ->type

Get ot set the file type, e.g. csv or txt.  A default applies.

=back

=cut

use strict;

use parent 'Batch::Exec';

# --- includes ---
use Carp qw(cluck confess);
use Data::Dumper;

use Batch::Exec::Null;
use Text::CSV;
use Path::Tiny;


# --- package constants ---
use constant MASK_BITWISE_ON => 077777;


# --- package globals ---
our $AUTOLOAD;
#our @EXPORT = qw();
#our @ISA = qw(Exporter);
our @ISA;
our $VERSION = sprintf "%d.%03d", q[_IDE_REVISION_] =~ /(\d+)/g;


# --- package locals ---
my $_n_objects = 0;

my %_attribute = (	# _attributes are restricted; no direct get/set
	Oben => undef,	# for Batch::Exec::Null object (created on new)
	Ocsv => undef,	# for CSV object (created on new)
	quote => 0,
	munge => "lc",
	type => undef,
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
	my $f_force = $self->quote;

	$self->Oben(Batch::Exec::Null->new);
	$self->Ocsv(Text::CSV->new({binary => 1, auto_diag => 1, always_quote => $f_force}));

	my %lovt = (
		"csv" => "Comma-Separated Variable length",
		"txt" => "ASCII text",
	);

	$self->lov(qw/_register type/, \%lovt);
	$self->lov(qw/_default type/, $self, qw/ type csv /);

	$self->log->debug(sprintf "self [%s]", Dumper($self));

	return $self;
}

=head2 METHODS

=over 4

=item OBJ->closeout

Close all output files and report

=cut

sub closeout {
	my $self = shift;

	$self->log->trace(sprintf "_file [%s]", Dumper($self->{'_file'}))
		if ($self->Alive());

	my $count = 0; while (my ($path, $fh) = each %{ $self->{'_file'} }) {

                $self->log->info("output in [$path]")
			if ($self->Alive());

		next unless ($self->is_stdio($fh) == 0);

                close($fh) || $self->log->warn("close [$path] failed");

		delete $self->{'_file'}->{$path};

		$count++;
	}
	$self->log->info("created $count output files")
		if ($count && $self->Alive());

	return $count;
}

=item OBJ->file

Add description here

=cut

sub file { 
	my $self = shift;
	my $path = shift;

	my $fh; if (defined $path) {

		$fh = IO::File->new();

		$self->log->logconfess("invalid (blank) filename")
			if ($self->Oben->is_blank($path));

		$self->log->info("opening output [$path]");

		$fh->open(">$path") || $self->log->logconfess("open($path) failed");

		$self->register($path, $fh);

		$self->header($fh);

	 } else {
		$self->log->info("outputting to stdout");

		$fh = \*STDOUT;
	}

	return $fh;
}

=item OBJ->csv

Add description here

=cut

sub csv { 
	my $self = shift;
	my $fh = shift;
	confess "SYNTAX: csv(FILEHANDLE)" unless defined($fh);

	my @str = map { (defined $_) ? $_ : $self->Oben->null; } @_;

	my $msg = "combine failed on [%s] error [%s]";

	my $status = $self->Ocsv->combine(@str);

	my $error = $self->Oben->null
		unless defined($self->Ocsv->error_input);

	$self->log->logconfess(sprintf $msg, Dumper(\@str), $error)
		unless ($status);

	my $str = $self->Ocsv->string;

	$self->log->trace("str [$str]");

	print $fh "$str\n";

	return $str;
}

=item OBJ->catalog_keys

Look for all possible keys across an array of hashes.

=cut

sub catalog_keys {
	my $self = shift;
	my $ra = shift;
	confess "SYNTAX: catalog_keys(ARRAYREF)" unless (
		defined($ra) && ref($ra) eq 'ARRAY'
	);
	my $msg = "structure is not a hash [%s]";

	my %column; for my $rh (@$ra) {

		$self->log->logconfess(sprintf $msg, Dumper($rh))
			unless (ref($rh) eq 'HASH');

		map {
			if (exists $column{$_}) {
				$column{$_}++;
			} else {
				$column{$_} = 1;
			}
		} keys %$rh;
	}

	$self->log->trace(sprintf "column [%s]", Dumper(\%column));

	my @columns = sort(keys %column);

	$self->log->debug(sprintf "columns [%s]", Dumper(\@columns));

	return @columns;
}

=item OBJ->write

Dump an arbitrary data structure to a CSV file.
Can pass an array of hashes or a hash of hashes.

=cut

sub write {
	my ($self, $pn, $rd) = @_;
	my $type = ref($rd);	# this should resolve undef okay
	confess "SYNTAX: write([EXPR], HASHREF|ARRAYREF)" unless (
		defined($rd) && ($type eq 'HASH' || $type eq 'ARRAY')
	);
	my $msg = "record is not a hash [%s]";
	my $fho = $self->file($pn);
	my $rows = 0;

	my @data = ($type eq 'HASH') ? values(%$rd) : @$rd;

	my @columns = $self->catalog_keys(\@data);

	for my $rh (@data) {

		$self->log->logconfess(sprintf $msg, Dumper($rh))
			unless (ref($rh) eq 'HASH');

		$self->csv($fho, @columns)
			unless ($rows++);

		my @values = map { $rh->{$_} } @columns;
		
		$self->csv($fho, @values);
	}
	close($fho) unless ($self->is_stdio($fho));

	$self->log->info("wrote $rows records");

	return $rows;
}

=item OBJ->read

Add description here

=cut

sub read { 
	my $self = shift;
	my $pn = shift;
	confess "SYNTAX: read(PATH)" unless defined($pn);

	my $lc = $self->lines($pn);
	my $o_csv = Text::CSV->new({ binary => 1, auto_diag => 1 });

	$self->log->info("slurping $lc lines from csv [$pn]");

	open(my $fh, "<:encoding(utf8)", $pn) || $self->log->logconfess("open($pn) failed");

	if (eof $fh) {
		$self->log->logwarn("WARNING possible empty CSV file [$pn]");

		return undef;
	}

	my @cols = $o_csv->header($fh, { detect_bom => 1, munge_column_names => $self->munge });

	$self->log->debug(sprintf "cols [%s]", Dumper(\@cols));

	my @data; my $rows = 0; while (my $row = $o_csv->getline($fh)) {

		$rows++;

		$self->log->trace(sprintf "row $rows row [%s]", Dumper($row));

		push @data, $row;
	}

	$self->log->info("slurped $rows records");

	$self->cough("expected [$lc] records but read [$rows]")
		unless ($lc - 1 == $rows);

	$self->log->debug(sprintf "data [%s]", Dumper(\@data));

	return (\@cols, \@data);
}

=item OBJ->header

Add description here

=cut

sub header {
	my $self = shift;
	my $fh = shift;
	confess "SYNTAX: header(FILEHANDLE)" unless defined ($fh);

	printf $fh "# ---- automatically generated by %s ----\n", $self->{'prefix'};

	printf $fh "# ---- timestamp %s ---- \n", scalar(localtime(time));
}

=item OBJ->lines(PATH)

Perform a line count of the file specified by PATH.

=cut

sub lines {
	my $self = shift;
	my $pn = shift;
	confess "SYNTAX: lines(EXPR)" unless defined ($pn);

	if ($self->extant($pn, "f")) {

		my $lc = scalar( path($pn)->lines );

		$self->log->debug("lc [$lc]");

		return $lc;
	}

	return 0;
}

=item OBJ->register

Add description here

=cut

sub register {
	my $self = shift;
	my $path = shift;
	my $fh = shift;
	confess "SYNTAX: register(EXPR, EXPR)"
		unless (defined($fh) && defined($path));

	if (defined $self->{'_file'}) {

		my $emsg = "attempting to open [$path] more than once";

		$self->log->logconfess($emsg)
			if (exists $self->{'_file'}->{$path});

		$self->{'_file'}->{$path} = $fh;

	} else {
		$self->{'_file'} = { $path => $fh };
	}

	$self->log->trace(sprintf "_file [%s]", Dumper($self->{'_file'}));

	return $path;
}

=item OBJ->toucher

Add description here

=cut

sub toucher {
	my $self = shift;
	my $from = shift;
#	i. apply the timestamp of one file others, or ii. apply local time or
#	actual time passed (which is per the localtime struct).
	confess "SYNTAX: toucher([EXPR|PATH], PATH, ...)" unless (@_);

	my $time;
	my $verb;

	if (defined $from) {
		if (-f $from) {

			my $stat = path($from)->stat;

			$time = $stat->mtime;
			$verb = "cloning";

		} elsif ($from =~ /^\d+$/) {	# integer (time)

			$time = $from;
			$verb = "applying";

		} else {
			return $self->cough("invalid file or time [$from]");
		}
	} else {
		$time = time();
		$verb = "touching";
	}
	$self->log->debug("time [$time]");

	$self->log->debug(sprintf "$verb timestamps to [%d] files", scalar(@_));

	my $count = 0; for (@_) {
		$count++ if defined( path($_)->touch($time) );
	}
	return $count;
}

=item OBJ->cloner

Replicate mode / time between two files optionally erasing first.

=cut

sub cloner {
	my $self = shift;
	my ($old,$new,$erase)=@_;
	confess "SYNTAX: cloner(PATH, PATH, [EXPR])" unless (
		defined($old) && defined($new));

	my $mode = path($old)->stat->mode;
	my $ptn = path($new); 

	$erase = 0 unless defined($erase);

	$self->log->debug("old [$old] mode [$mode] new [$new] erase [$erase]");

	$mode = $mode & MASK_BITWISE_ON;

	$self->log->debug(sprintf "chmodding [$new] mode [%04o]", $mode);

 	$self->log->logconfess("chmod($mode, $new) failed")
		unless ($ptn->chmod($mode, $new) == 1);

	my $rv = $self->toucher($old, $new);

	$self->delete($old)
		if ($erase);

	return $rv;
}

=back

=head2 ALIASED METHODS

The following method aliases have also been defined:

	alias		base method (or attribute)
	------------	------------	
	dump_csv	write
	force_quote	quote
	mcn		munge
	outfile		file
	read_csv	read

=cut

*dump_csv = \&write;
*force_quote = \&quote;
*outfile = \&file;
*read_csv = \&read;

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

