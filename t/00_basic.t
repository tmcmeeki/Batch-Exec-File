#!/usr/bin/perl
#
# 00_basic.t - test harness for the Batch::Exec::File class: basics
#
use strict;

use Data::Dumper;
use Logfer qw/ :all /;
#use Log::Log4perl qw/ :easy /;
use Test::More tests => 105;

BEGIN { use_ok('Batch::Exec::File') };


# -------- constants --------


# -------- global variables --------
my $log = get_logger(__FILE__);

my $cycle = 1;


# -------- subroutines --------


# -------- main --------
my $obn1 = Batch::Exec::File->new;
isa_ok($obn1, "Batch::Exec::File",	"class check $cycle"); $cycle++;

my $obn2 = Batch::Exec::File->new(global => 0);
isa_ok($obn2, "Batch::Exec::File",	"class check $cycle"); $cycle++;

my $obn3 = Batch::Exec::File->new;
isa_ok($obn3, "Batch::Exec::File",	"class check $cycle"); $cycle++;


# -------- simple attributes --------
my @attr = $obn1->Attributes;
my $attrs = 22;
is(scalar(@attr), $attrs,		"class attributes");
is(shift @attr, "Batch::Exec::File",	"class okay");

for my $attr (@attr) {

	my $dfl = $obn1->$attr;

	my ($set, $type); if (defined $dfl && $dfl =~ /^[\-\d\.]+$/) {
		$set = -1.1;
		$type = "f`";
	} else {
		$set = "_dummy_";
		$type = "s";
	}

	is($obn1->$attr($set), $set,	"$attr set cycle $cycle");
	isnt($obn1->$attr, $dfl,	"$attr check");

	$log->debug(sprintf "attr [$attr]=%s", $obn1->$attr);

	if ($type eq "s") {
		my $ck = (defined $dfl) ? $dfl : "_null_";

		ok($obn1->$attr ne $ck,	"$attr string");
	} else {
		ok($obn1->$attr < 0,	"$attr number");
	}
	is($obn1->$attr($dfl), $dfl,	"$attr reset");

        $cycle++;
}


# -------- Inherit --------
is($obn1->Inherit($obn2), $attrs - 1,	"inherit same attribute count");


# -------- global --------
is($obn1->global, 1, 		"global default");
is($obn2->global, 0, 		"global set $cycle"); $cycle++;
is($obn3->global, 1, 		"global set $cycle"); $cycle++;


# -------- null --------
my $ren = qr/nul/;

is($obn1->null, $obn2->null, 		"null consistent $cycle"); $cycle++;
is($obn2->null, $obn3->null, 		"null consistent $cycle"); $cycle++;

like($obn1->null, $ren, 		"null matches $cycle"); $cycle++;
like($obn2->null, $ren, 		"null matches $cycle"); $cycle++;
like($obn3->null, $ren, 		"null matches $cycle"); $cycle++;


# -------- global versus local behaviour --------
my $rex = qr/xxx/;
is($obn2->null("xxx"), "xxx",		"global null override");

isnt($obn1->null, $obn2->null, 		"local differentiated from global");
is($obn1->null, $obn3->null, 		"global null consistent");

like($obn1->null, $ren, 		"null matches $cycle"); $cycle++;
like($obn2->null, $rex, 		"null matches $cycle"); $cycle++;
like($obn3->null, $ren, 		"null matches $cycle"); $cycle++;

__END__

=head1 DESCRIPTION

00_basic.t - test harness for the Batch::Exec::File class: basics

=head1 VERSION

_IDE_REVISION_

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

L<perl>, L<Batch::Exec>.

=cut

