#!/usr/bin/perl
#
# 03_write.t - test harness for the Batch::Exec::File class: output handling
#
use strict;

use Data::Compare;
use Data::Dumper;
use Logfer qw/ :all /;

use Test::More;
use lib 't';
use tester;

my $ot = tester->new;
$ot->planned(50);

use_ok($ot->this);


# -------- constants --------


# -------- global variables --------
my $log = get_logger(__FILE__);


# -------- sub-routines --------
# -------- main --------
my $obf1 = $ot->object;

my $obf2 = $ot->object('autoheader' => 1);


# ---- outfile and header -----
my $pn1 = File::Spec->catfile(".", $obf1->prefix . ".tmp-1");
my $pn2 = File::Spec->catfile(".", $obf2->prefix . ".tmp-2");

ok(defined($obf1->outfile),		$ot->cond("outfile stdout open"));

my $fh1 = $obf1->outfile($pn1);
ok(defined($fh1),			$ot->cond("outfile path nohead open"));
is( $obf1->is_stdio($fh1), 0,		$ot->cond("is_stdio normal"));

my $fh2 = $obf2->outfile($pn2);
ok(defined($fh2),			$ot->cond("outfile path header open"));
is( $obf1->is_stdio($fh2), 0,		$ot->cond("is_stdio normal"));

is($obf1->closeout, 1,			$ot->cond("closeout count"));
is($obf2->closeout, 1,			$ot->cond("closeout count"));

$ot->grepper($pn1, 0);
$ot->grepper($pn2, 1);


# ---- csv -----
open(my $fh3, ">$pn1");
like($obf1->csv($fh3, "csv1", "csv2"), qr/csv1.*csv2/,	$ot->cond("csv return"));
close($fh3);
$ot->grepper($pn1, 1, "csv1");
$ot->grepper($pn1, 1, "csv2");
#system("cat $pn1");


# ---- catalog keys -----
my %rec1 = ( 'key1' => 'value1', 'key2' => 'value2', 'key3' => 'value3' );
my %rec2 = ( 'key3' => 'value3', 'key4' => 'value4', 'key5' => 'value5' );

my @str1 = ( { %rec1 }, { %rec2 } );			# array of hashes
my %str2 = ( 'id1' => { %rec1 }, 'id2' => { %rec2 } );	# hash of hashes

$log->trace(sprintf "str1 [%s]", Dumper(\@str1));
$log->trace(sprintf "str2 [%s]", Dumper(\%str2));

my @col1 = $obf1->catalog_keys(\@str1);
ok(scalar(@col1) == 5,		$ot->cond("str1 key total"));

my @col2 = $obf1->catalog_keys([values(%str2)]);
ok(scalar(@col2) == 5,		$ot->cond("str2 key total"));


# ---- write files -----
my $pn3 = File::Spec->catfile(".", $obf1->prefix . ".tmp-3");
my $pn4 = File::Spec->catfile(".", $obf2->prefix . ".tmp-4");
my $pn5 = File::Spec->catfile(".", $obf2->prefix . ".tmp-5");

is($obf1->write($pn3, \@str1), 2,	$ot->cond("write rows]"));
is($obf1->lines($pn3), 3,		$ot->cond("linecount]"));
#system("cat $pn3");
is($obf2->write($pn4, \%str2), 2,	$ot->cond("write rows"));
is($obf1->lines($pn4), 5,		$ot->cond("linecount]"));
#system("cat $pn4");

# the write above will actually close the output files, so closeout
# will have nothing to do.
is($obf1->closeout, 0,			$ot->cond("closeout zero"));
$obf2->outfile($pn5);	# changes the closeout behaviour
is($obf2->closeout, 1,			$ot->cond("closeout one"));

$ot->grepper($pn3, 0);
$ot->grepper($pn4, 1);

my @grep = qw/ key1 value1 key5 value5 /;
for my $grep (@grep) {
	$ot->grepper($pn3, 1, $grep);
	$ot->grepper($pn4, 1, $grep);
}
$ot->grepper($pn3, 2, "value3");
$ot->grepper($pn4, 2, "value3");

$ot->grepper($pn3, 0, "invalid");
$ot->grepper($pn4, 0, "invalid");


# ---- read files -----
my ($ra1, $ra2) = $obf1->read($pn3);
is( ref($ra1), "ARRAY",		$ot->cond("read rv1 type"));
is( ref($ra2), "ARRAY",		$ot->cond("read rv2 type"));
is( scalar(@$ra1), 5,		$ot->cond("column count"));
is( scalar(@$ra2), 2,		$ot->cond("row count"));
#is( $obf1->lines($pn3), 3,	$ot->cond("linecount again"));


# ---- cleanup -----
for my $pn ($pn1, $pn2, $pn3, $pn4, $pn5) {

	$obf1->delete($pn);

	ok(! -f $pn,		$ot->cond("delete path [$pn]"));
}

__END__

=head1 DESCRIPTION

03_write.t - test harness for the Batch::Exec::File.pm module: output handling

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

