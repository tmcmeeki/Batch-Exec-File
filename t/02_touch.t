#!/usr/bin/perl
#
# 02_touch.t - test harness for the Batch::Exec::File class: perms / modes
#
use strict;

use Data::Dumper;
use Logfer qw/ :all /;

use Test::More;
use lib 't';
use tester;

my $ot = tester->new;
$ot->planned(60);

use_ok($ot->this);


# -------- constants --------


# -------- global variables --------
my $log = get_logger(__FILE__);


# -------- main --------
my $ofp = $ot->object;

my $tf2 = $ot->mkfile;
ok(-f $tf2,				$ot->cond("file exists"));
my $tf4 = $ot->mkfile;
ok(-f $tf4,				$ot->cond("file exists"));


# ----- chmod: basic -----
$ot->ck_perms($tf2, '^rw',		$ot->cond("default verify"));

is($ofp->chmod(0700, $tf2), 1,	$ot->cond("chmod exec apply"));
$ot->ck_perms($tf2, "^rwx",		$ot->cond("text exec"));
$ot->ck_octal($tf2, 0700,		$ot->cond("octal exec"));

is($ofp->chmod("a+rwx", $tf2), 1,	$ot->cond("chmod allexec"));
$ot->ck_perms($tf2, "rwxrwxrwx",	$ot->cond("text allexec"));
$ot->ck_octal($tf2, 0777,		$ot->cond("octal allexec"));

is($ofp->chmod("og-x", $tf2), 1,	$ot->cond("chmod remove exec"));
$ot->ck_perms($tf2, "rwxrw0rw0",	$ot->cond("text noexec"));
$ot->ck_octal($tf2, 0766,		$ot->cond("octal noexec"));

is($ofp->chmod(0600, $tf2), 1,	$ot->cond("chmod reset"));
if($ofp->on_cygwin || $ofp->on_windows) {
	diag("chmod user execute bit removal does not appear to work on cygwin");
	#  $ touch x
	#  -rw-r--r--+ 1 tomby tmcme 0 Dec 10 18:34 x
	#  $ chmod u+x x
	#  -rwxr--r--+ 1 tomby tmcme 0 Dec 10 18:34 x
	#  $ chmod u-x x
	#  -rw-r--r--+ 1 tomby tmcme 0 Dec 10 18:34 x

	is(0, 0, 			$ot->cond("text reset skipped"));
	ok(1,				$ot->cond("octal reset skipped"));
} else {
	$ot->ck_perms($tf2, "^rw00",		$ot->cond("text reset checked"));
	$ot->ck_octal($tf2, 0600,		$ot->cond("octal reset checked"));
}

is($ofp->chmod("u+x", $tf2), 1, 	$ot->cond("chmod uexec"));
$ot->ck_perms($tf2, "rwx000",		$ot->cond("text uexec"));
$ot->ck_octal($tf2, 0700,			$ot->cond("octal uexec"));


# ----- chmod: multiple -----
ok($ofp->chmod(0444, $tf2, $tf4) == 2,	$ot->cond("chmod multi"));
$ot->ck_perms($tf2, "r0.r0.r0.",		$ot->cond("chmod multi"));
$ot->ck_perms($tf4, "r0.r0.r0.",		$ot->cond("chmod multi"));

ok($ofp->chmod(0777, $tf2, $tf4) == 2,	$ot->cond("chmod multi"));
$ot->ck_perms($tf2, "rwxrwxrwx",		$ot->cond("chmod multi"));
$ot->ck_perms($tf4, "rwxrwxrwx",		$ot->cond("chmod multi"));

ok($ofp->chmod(0550, $tf2, $tf4) == 2,	$ot->cond("chmod multi"));
$ot->ck_perms($tf2, "r0xr0x000",		$ot->cond("chmod multi"));
$ot->ck_perms($tf4, "r0xr0x000",		$ot->cond("chmod multi"));


# ---- mkro -----
ok($ofp->chmod(0666, $tf4),	$ot->cond("mkro start"));
$ot->ck_perms($tf4, "rw.rw.rw.",	$ot->cond("mkro before"));
is( $ofp->mkro($tf4), 1,	$ot->cond("mkro change"));
$ot->ck_perms($tf4, "r0.r0.r0.",	$ot->cond("mkro after"));


# ---- mkwrite -----
ok($ofp->chmod(0444, $tf2),	$ot->cond("mkwrite start"));
$ot->ck_perms($tf2, "^r0",		$ot->cond("mkwrite"));
ok( $ofp->mkwrite($tf2),	$ot->cond("mkwrite change"));
$ot->ck_perms($tf2, "^rw",		$ot->cond("mkwrite verify"));


# ---- mkexec -----
ok($ofp->chmod(0444, $tf2),	$ot->cond("mkexec start"));
$ot->ck_perms($tf2, "r0.r00r00",	$ot->cond("mkexec"));
ok( $ofp->mkexec($tf2),		$ot->cond("mkexec on"));
$ot->ck_perms($tf2, "r0xr0xr0x",	$ot->cond("mkexec verify"));


# ---- cloner: basic -----
is($ofp->toucher(undef, $tf2), 1,	$ot->cond("clone init"));
is($ofp->chmod(0700, $tf2), 1,		$ot->cond("clone init"));
sleep(2);
is($ofp->toucher(undef, $tf4), 1,	$ot->cond("clone init"));
is($ofp->chmod(0770, $tf4), 1,		$ot->cond("clone init"));
$ot->diff($tf2, $tf4);

is($ofp->cloner($tf2, $tf4), 1,		$ot->cond("cloner"));
$ot->diff($tf2, $tf4, 1);


# ---- cloner: erase -----
sleep(2);
is($ofp->toucher(undef, $tf4), 1,	$ot->cond("clone init"));
is($ofp->chmod(0770, $tf4), 1,		$ot->cond("clone init"));
$ot->diff($tf2, $tf4);

my $sf2_perms = (stat($tf2))[$ot->perms];
my $sf2_mtime = (stat($tf2))[$ot->mtime];
is($ofp->cloner($tf2, $tf4, 1), 1,		$ot->cond("cloner"));
is($sf2_perms, (stat($tf4))[$ot->perms],	$ot->cond("clone check"));
is($sf2_mtime, (stat($tf4))[$ot->mtime],	$ot->cond("clone check"));
ok(!-f $tf2, 					$ot->cond("clone check"));


# ---- cleanup -----
ok( $ofp->delete($tf2) == 0,	$ot->cond("cleanup"));
ok( $ofp->delete($tf4) == 0,	$ot->cond("cleanup"));


__END__

=head1 DESCRIPTION

02_touch.t - test harness for the Batch::Exec::File.pm module: perms / modes

=head1 VERSION

$Revision: 1.1 $

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

