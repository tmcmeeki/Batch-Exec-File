#!/usr/bin/perl
#
# 01_read.t - test harness for the Batch::Exec::File.pm module: input handling
#
use strict;

use Data::Compare;
use Data::Dumper;
use Logfer qw/ :all /;

use Test::More;
use lib 't';
use tester;

my $ot = tester->new;
$ot->planned(54);

use_ok($ot->this);


# -------- constants --------


# -------- global variables --------
my $log = get_logger(__FILE__);
my $cycle = 1;


# -------- sub-routines --------


# -------- main --------
my $obf1 = $ot->object;


# ---- csv -----
my $fn1 = $ot->mkfn;
open(my $fh, ">$fn1");

like($obf1->csv($fh, "csv1", "csv2"), qr/csv/,	$ot->cond("csv pair"));
like($obf1->csv($fh, "csv3"), qr/csv3/,		$ot->cond("csv third"));
like($obf1->csv($fh, "csv4"), qr/csv4/,		$ot->cond("csv fourth"));

close($fh);

$ot->grepper($obf1, 1, "csv1");
$ot->grepper($obf1, 1, "csv2");
$ot->grepper($obf1, 1, "csv3");
$ot->grepper($obf1, 1, "csv4");
$ot->grepper($obf1, 3, "csv");


# ---- catalog -----
my %rec1 = ( 'key1' => 'value1', 'key2' => 'value2', 'key3' => 'value3' );
my %rec2 = ( 'key3' => 'value3', 'key4' => 'value4', 'key5' => 'value5' );

my @str1 = ( { %rec1 }, { %rec2 } );			# array of hashes
my %str2 = ( 'id1' => { %rec1 }, 'id2' => { %rec2 } );	# hash of hashes

$log->trace(sprintf "str1 [%s]", Dumper(\@str1));
$log->trace(sprintf "str2 [%s]", Dumper(\%str2));

my @col1 = $obf1->catalog(\@str1);
ok(scalar(@col1) == 5,			$ot->cond("str1 key total"));
is(scalar(grep(/key\d/, @col1)), 5,	$ot->cond("str1 key names"));

my @col2 = $obf1->catalog_keys([values(%str2)]);	# test the alias
ok(scalar(@col2) == 5,			$ot->cond("str2 key total"));
is(scalar(grep(/key\d/, @col2)), 5,	$ot->cond("str2 key names"));


# ---- read -----
my $fn2 = $ot->mkfn;
open($fh, ">$fn2");

like($obf1->csv($fh, sort keys %rec1), qr/key/,		$ot->cond("csv keys"));
like($obf1->csv($fh, sort values %rec1), qr/value/,	$ot->cond("csv val1"));
like($obf1->csv($fh, sort values %rec2), qr/value/,	$ot->cond("csv val2"));

close($fh);

$ot->grepper($obf1, 1, "key");
$ot->grepper($obf1, 1, "key1");
$ot->grepper($obf1, 1, "key2");
$ot->grepper($obf1, 1, "key3");

$ot->grepper($obf1, 1, "value1");
$ot->grepper($obf1, 1, "value2");
$ot->grepper($obf1, 2, "value3");
$ot->grepper($obf1, 1, "value4");
$ot->grepper($obf1, 1, "value5");
$ot->grepper($obf1, 2, "value");

my ($ra1, $ra2) = $obf1->read($fn2);

is(ref($ra1), "ARRAY",		$ot->cond("read type"));
is(ref($ra2), "ARRAY",		$ot->cond("read type"));

is(scalar(@$ra1), 3,		$ot->cond("column count"));
is(scalar(@$ra2), 2,		$ot->cond("row count"));

is_deeply([sort keys %rec1], [sort @$ra1],	$ot->cond("read keys"));

is($ra2->[0]->[0], "value1",	$ot->cond("cell"));
is($ra2->[0]->[1], "value2",	$ot->cond("cell"));
is($ra2->[0]->[2], "value3",	$ot->cond("cell"));

is($ra2->[1]->[0], "value3",	$ot->cond("cell"));
is($ra2->[1]->[1], "value4",	$ot->cond("cell"));
is($ra2->[1]->[2], "value5",	$ot->cond("cell"));

# ---- done -----
$ot->cleanup($obf1);

__END__

=head1 DESCRIPTION

01_read.t - test harness for the Batch::Exec::File.pm module: output handling

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

