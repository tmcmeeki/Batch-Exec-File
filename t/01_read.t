#!/usr/bin/perl
#
# 01_read.t - test harness for the Batch::Exec::File.pm module: output handling
#
use strict;

use Data::Compare;
use Data::Dumper;
use Logfer qw/ :all /;
use Test::More tests => 50;

BEGIN { use_ok('Batch::Exec::File') };


# -------- constants --------


# -------- global variables --------
my $log = get_logger(__FILE__);
my $cycle = 1;


# -------- sub-routines --------
sub grepper {
	my $fn = shift;
	my $expected = shift;
	my $re = shift;

	my $desc; if (defined($re)) {
		$desc = "grep $re";
	} else {
		$re = "generated" ;
		$desc = "autohead";
	}

	open(my $fh, "<$fn");
	my $found = 0; while (<$fh>) { $found += grep(/$re/, $_); }
	close($fh);
	is($found, $expected,			"$desc cycle [$cycle]");
	$cycle++;
}


# -------- main --------
my $ofu1 = Batch::Exec::File->new;
isa_ok($ofu1, "Batch::Exec::File",	"class check $cycle"); $cycle++;

my $ofu2 = Batch::Exec::File->new('autoheader' => 1);
isa_ok($ofu2, "Batch::Exec::File",	"class check $cycle"); $cycle++;


# ---- is_stdio -----
my $fio = \*STDIN;
is( $ofu1->is_stdio($fio), 1,	"is_stdio stdin");
$fio = \*STDOUT;
is( $ofu1->is_stdio($fio), 1,	"is_stdio stdout");
$fio = \*STDERR;
is( $ofu1->is_stdio($fio), 1,	"is_stdio stderr");
$fio = "null";
ok( $ofu1->is_stdio($fio) < 0,	"is_stdio failsafe");


# ---- outfile and header -----
my $pn1 = File::Spec->catfile(".", $ofu1->prefix . ".tmp-1");
my $pn2 = File::Spec->catfile(".", $ofu2->prefix . ".tmp-2");

ok(defined($ofu1->outfile),		"outfile stdout open");

my $fh1 = $ofu1->outfile($pn1);
ok(defined($fh1),			"outfile path nohead open");
is( $ofu1->is_stdio($fh1), 0,		"is_stdio normal [$cycle]"); $cycle++;

my $fh2 = $ofu2->outfile($pn2);
ok(defined($fh2),			"outfile path header open");
is( $ofu1->is_stdio($fh2), 0,		"is_stdio normal [$cycle]"); $cycle++;

is($ofu1->closeout, 1,			"closeout count [$cycle]"); $cycle++;
is($ofu2->closeout, 1,			"closeout count [$cycle]"); $cycle++;

grepper $pn1, 0;
grepper $pn2, 1;


# ---- csv -----
open(my $fh3, ">$pn1");
like($ofu1->csv($fh3, "csv1", "csv2"), qr/csv1.*csv2/,	"csv return");
close($fh3);
grepper $pn1, 1, "csv1";
grepper $pn1, 1, "csv2";
#system("cat $pn1");


# ---- catalog keys -----
my %rec1 = ( 'key1' => 'value1', 'key2' => 'value2', 'key3' => 'value3' );
my %rec2 = ( 'key3' => 'value3', 'key4' => 'value4', 'key5' => 'value5' );

my @str1 = ( { %rec1 }, { %rec2 } );			# array of hashes
my %str2 = ( 'id1' => { %rec1 }, 'id2' => { %rec2 } );	# hash of hashes

$log->trace(sprintf "str1 [%s]", Dumper(\@str1));
$log->trace(sprintf "str2 [%s]", Dumper(\%str2));

my @col1 = $ofu1->catalog_keys(\@str1);
ok(scalar(@col1) == 5,		"str1 key total");

my @col2 = $ofu1->catalog_keys([values(%str2)]);
ok(scalar(@col2) == 5,		"str2 key total");


# ---- dump_csv files -----
my $pn3 = File::Spec->catfile(".", $ofu1->prefix . ".tmp-3");
my $pn4 = File::Spec->catfile(".", $ofu2->prefix . ".tmp-4");
my $pn5 = File::Spec->catfile(".", $ofu2->prefix . ".tmp-5");

is($ofu1->dump_csv($pn3, \@str1), 2,	"dump_csv rows [$cycle]");
is($ofu1->lines($pn3), 3,		"linecount [$cycle]"); $cycle++;
#system("cat $pn3");
is($ofu2->dump_csv($pn4, \%str2), 2,	"dump_csv rows [$cycle]");
is($ofu1->lines($pn4), 5,		"linecount [$cycle]"); $cycle++;
#system("cat $pn4");

# the dump_csv above will actually close the output files, so closeout
# will have nothing to do.
is($ofu1->closeout, 0,			"closeout zero");
$ofu2->outfile($pn5);	# changes the closeout behaviour
is($ofu2->closeout, 1,			"closeout one");

grepper $pn3, 0;
grepper $pn4, 1;

my @grep = qw/ key1 value1 key5 value5 /;
for my $grep (@grep) {
	grepper $pn3, 1, $grep;
	grepper $pn4, 1, $grep;
}
grepper $pn3, 2, "value3";
grepper $pn4, 2, "value3";

grepper $pn3, 0, "invalid";
grepper $pn4, 0, "invalid";


# ---- read_csv files -----
my ($ra1, $ra2) = $ofu1->read_csv($pn3);
is( ref($ra1), "ARRAY",		"read_csv rv1 type");
is( ref($ra2), "ARRAY",		"read_csv rv2 type");
is( scalar(@$ra1), 5,		"column count");
is( scalar(@$ra2), 2,		"row count");
#is( $ofu1->lines($pn3), 3,	"linecount again");


# ---- cleanup -----
for my $pn ($pn1, $pn2, $pn3, $pn4, $pn5) {

	$ofu1->delete($pn);

	ok(! -f $pn,		"delete path [$pn]");
}

__END__

=head1 DESCRIPTION

Batch::Exec::File-4.t - test harness for the Batch::Exec::File.pm module: output handling

=head1 VERSION

$Revision: 1.2 $

=head1 AUTHOR

B<Tom McMeekin> tmcmeeki@cpan.org

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published
by the Free Software Foundation; either version 2 of the License,
or any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

=head1 SEE ALSO

L<perl>, L<Batch::Exec::File>.

=cut

