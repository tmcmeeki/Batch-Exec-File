package tester;
#
# tester.pm - test harness for the Batch::Exec::File class: common routines
#
use strict;
use warnings;

use Carp qw(cluck confess);     # only use stack backtrace within class
use Data::Dumper;
use File::Basename;
use File::chmod qw( getmod );
use Log::Log4perl qw/ :easy /;
use Test::More;

use constant MY_CLASS => 'Batch::Exec::File';
use constant MODE_SKIP => "abc";
use constant STAT_PERMS => 2;
use constant STAT_MTIME => 9;

our $AUTOLOAD;

my %attribute = (
	_planned => 0,
	condition => {},
	cycle => 0,
	executed => 0,
	files => [],
	log => get_logger(MY_CLASS),
	mtime => STAT_MTIME,
	perms => STAT_PERMS,
	this => MY_CLASS,
	windows => undef,
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

	$self->{'executed'}++;

	return $cond;
}

sub object {
	my $self = shift;
	my $class = $self->this;

	my $cond = $self->cond("class [$class]");

	$self->log->info(sprintf "instantiating $cond %s args", (@_) ? "with" : "without");

	my $obj = $class->new(@_);
	$self->windows($obj->on_windows);

	isa_ok($obj, $class,	$self->cond($cond));

	return $obj;
}

sub planned {
	my $self = shift;
	my $n_tests = shift;

	confess "SYNTAX plan(tests)" unless defined ($n_tests);

	$self->{'_planned'} = $n_tests;

	plan tests => $n_tests;
}


# -------- custom routines here --------
sub mkfn {
	my $self = shift;

	my $fn = basename($0);
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

sub ck_octal {
	my $self = shift;
	my ($pn,$o_exp,$desc)=@_;

	my $o_act = getmod($pn);

	my $oo_act = sprintf "%o", $o_act;
	my $oo_exp = sprintf "%o", $o_exp;

	$self->log->debug("oo_exp [$oo_exp] oo_act [$oo_act]");

	is($oo_act, $oo_exp,	$self->cond("ck_octal"));

	return $oo_act;
}

sub diff {
	my $self = shift;
	my $pn1 = shift;
	my $pn2 = shift;
	my $polarity = shift; $polarity = 0 unless defined($polarity);
	confess "SYNTAX diff(PATH, PATH)" unless (
		defined($pn1) && defined($pn2));

	my $value1 = (stat($pn1))[$self->perms];
	my $value2 = (stat($pn2))[$self->perms];

	if ($polarity) {
		is($value1, $value2,		$self->cond("diff perms"));
	} else {
		isnt($value1, $value2,		$self->cond("diff perms"));
	}

	$value1 = (stat($pn1))[$self->mtime];
	$value2 = (stat($pn2))[$self->mtime];

	if ($polarity) {
		is($value1, $value2,		$self->cond("diff mtime"));
	} else {
		isnt($value1, $value2,		$self->cond("diff mtime"));
	}
}

sub ck_perms {
	my $self = shift;
	my $pn = shift;
	my $wanted = shift;
	my $desc = shift;

	my $perms; if ($self->windows) {

		$wanted = MODE_SKIP;
		$perms = $wanted;
	} else {
		$perms = $self->get_perms($pn);
	}
	my $re = qr/$wanted/;

	like($perms, $re,	$self->cond("ck_perms"));

	return $perms;
}

sub get_perms {
	my $self = shift;
	my ($pn,$len)=@_;

	system("sync");
	system("sync");
	my $pipe = readpipe("ls -ld \'$pn\'");
	chomp $pipe;
	$self->log->trace("pipe [$pipe]");

#	my $template = "x1a$len";
#	my $retval = unpack $template, $pipe;
	my @pipe = split(/\s+/, $pipe);

	my $perm = shift @pipe;
	$perm =~ s/^\-//;
	$perm =~ s/\+$//;
	$perm =~ s/\-/0/g;

	$self->log->trace(sprintf "perm [$perm] pipe [%s]", Dumper(\@pipe));

	return $perm;
}

sub mkfile {
	my $self = shift;
	my $pn = $self->mkfn;

	$self->log->debug("creating [$pn]");

	open(my $fh, ">$pn") || die("open($pn) failed");
	close($fh);

	return $pn;
}


DESTROY {
	my $self = shift;

#	$self->log->debug(Dumper($self));
};

#END { }

1;

__END__


