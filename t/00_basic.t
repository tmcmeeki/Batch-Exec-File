#!/usr/bin/perl
#
# 00_basic.t - test harness for the Batch::Exec::File class: basics
#
use strict;

use Data::Dumper;
use Logfer qw/ :all /;
#use Log::Log4perl qw/ :easy /;
use Test::More tests => 70;

BEGIN { use_ok('Batch::Exec::File') };


# -------- constants --------


# -------- global variables --------
my $log = get_logger(__FILE__);

my $cycle = 1;


# -------- subroutines --------


# -------- main --------
my $obn1 = Batch::Exec::File->new;
isa_ok($obn1, "Batch::Exec::File",	"class check $cycle"); $cycle++;

my $obn2 = Batch::Exec::File->new(mcn => "uc");
isa_ok($obn2, "Batch::Exec::File",	"class check $cycle"); $cycle++;


# -------- simple attributes --------
my @attr = $obn1->Attributes;
my $attrs = 17;
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

