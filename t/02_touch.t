#!/usr/bin/perl
#
# 02_touch.t - test harness for the Batch::Exec::File.pm module: perms / modes
#
use strict;

use Data::Dumper;
use File::chmod qw( getmod );
use File::chmod qw( getmod );
use Logfer qw/ :all /;
use Test::More tests => 61;

BEGIN { use_ok('Batch::Exec::File') };


# -------- constants --------
use constant MODE_SKIP => "abc";
use constant STAT_PERMS => 2;
use constant STAT_MTIME => 9;


# -------- global variables --------
my $log = get_logger(__FILE__);
my $cycle = 1;
my $g_windows = 0;


sub ck_octal {
	my ($pn,$o_exp,$desc)=@_;

	$desc = sprintf "cycle %d", $cycle++ unless defined($desc);

	my $o_act = getmod($pn);

	my $oo_act = sprintf "%o", $o_act;
	my $oo_exp = sprintf "%o", $o_exp;

	$log->debug("oo_exp [$oo_exp] oo_act [$oo_act]");

	is($oo_act, $oo_exp,	"$desc ck_octal");

	return $oo_act;
}


sub ck_perms {
	my $pn = shift;
	my $wanted = shift;
	my $desc = shift;

	$desc = sprintf "cycle %d", $cycle++ unless defined($desc);

	my $perms; if ($g_windows) {

		$wanted = MODE_SKIP;
		$perms = $wanted;
	} else {
		$perms = get_perms($pn);
	}
	my $re = qr/$wanted/;

	like($perms, $re,	"$desc ck_perms");

	return $perms;
}


sub get_perms {
	my ($pn,$len)=@_;

	system("sync");
	system("sync");
	my $pipe = readpipe("ls -ld \'$pn\'");
	chomp $pipe;
	$log->trace("pipe [$pipe]");

#	my $template = "x1a$len";
#	my $retval = unpack $template, $pipe;
	my @pipe = split(/\s+/, $pipe);

	my $perm = shift @pipe;
	$perm =~ s/^\-//;
	$perm =~ s/\+$//;
	$perm =~ s/\-/0/g;

	$log->trace(sprintf "perm [$perm] pipe [%s]", Dumper(\@pipe));

	return $perm;
}


# -------- main --------
my $ofp = Batch::Exec::File->new;
isa_ok($ofp, "Batch::Exec::File",	"class check $cycle"); $cycle++;

my $tf2 = $ofp->mktmpfile;
ok(-f $tf2,				"file exists 1");
my $tf4 = $ofp->mktmpfile;
ok(-f $tf4,				"file exists 2");

$g_windows = 1 if ($ofp->on_windows);


# ----- chmod: basic -----
ck_perms($tf2, '^rw',		"default verify");

is($ofp->chmod(0700, $tf2), 1,	"chmod exec apply");
ck_perms($tf2, "^rwx",		"text exec");
ck_octal($tf2, 0700,		"octal exec");
is(getmod($tf2), 0700,		"getmod exec");

is($ofp->chmod("a+rwx", $tf2), 1,	"chmod allexec");
ck_perms($tf2, "rwxrwxrwx",	"text allexec");
ck_octal($tf2, 0777,		"octal allexec");

is($ofp->chmod("og-x", $tf2), 1,"chmod remove exec");
ck_perms($tf2, "rwxrw0rw0",	"text noexec");
ck_octal($tf2, 0766,		"octal noexec");

is($ofp->chmod(0600, $tf2), 1,	"chmod reset");
if($ofp->on_cygwin || $ofp->on_windows) {
	diag("chmod user execute bit removal does not appear to work on cygwin");
	#  $ touch x
	#  -rw-r--r--+ 1 tomby tmcme 0 Dec 10 18:34 x
	#  $ chmod u+x x
	#  -rwxr--r--+ 1 tomby tmcme 0 Dec 10 18:34 x
	#  $ chmod u-x x
	#  -rw-r--r--+ 1 tomby tmcme 0 Dec 10 18:34 x

	is(0, 0, 			"text reset skipped");
	ok(1,				"octal reset skipped");
} else {
	ck_perms($tf2, "^rw00",		"text reset checked");
	ck_octal($tf2, 0600,		"octal reset checked");
}

is($ofp->chmod("u+x", $tf2), 1, 	"chmod uexec");
ck_perms($tf2, "rwx000",		"text uexec");
ck_octal($tf2, 0700,			"octal uexec");


# ----- chmod: multiple -----
ok($ofp->chmod(0444, $tf2, $tf4) == 2,	"chmod multi 1a");
ck_perms($tf2, "r0.r0.r0.",		"chmod multi 1b");
ck_perms($tf4, "r0.r0.r0.",		"chmod multi 1c");

ok($ofp->chmod(0777, $tf2, $tf4) == 2,	"chmod multi 2a");
ck_perms($tf2, "rwxrwxrwx",		"chmod multi 2b");
ck_perms($tf4, "rwxrwxrwx",		"chmod multi 2c");

ok($ofp->chmod(0550, $tf2, $tf4) == 2,	"chmod multi 3a");
ck_perms($tf2, "r0xr0x000",		"chmod multi 3b");
ck_perms($tf4, "r0xr0x000",		"chmod multi 3c");


# ---- mkro -----
ok($ofp->chmod(0666, $tf4),	"mkro start");
ck_perms($tf4, "rw.rw.rw.",	"mkro before");
is( $ofp->mkro($tf4), 1,	"mkro change");
ck_perms($tf4, "r0.r0.r0.",	"mkro after");


# ---- mkwrite -----
ok($ofp->chmod(0444, $tf2),	"mkwrite start");
ck_perms($tf2, "^r0",		"mkwrite");
ok( $ofp->mkwrite($tf2),	"mkwrite change");
ck_perms($tf2, "^rw",		"mkwrite verify");


# ---- mkexec -----
ok($ofp->chmod(0444, $tf2),	"mkexec start");
ck_perms($tf2, "r0.r00r00",	"mkexec");
ok( $ofp->mkexec($tf2),		"mkexec on");
ck_perms($tf2, "r0xr0xr0x",	"mkexec verify");


# ---- cloner: basic -----
is($ofp->toucher(undef, $tf2), 1,	"clone init 1a");
is($ofp->chmod(0700, $tf2), 1,		"clone init 1b");
sleep(2);
is($ofp->toucher(undef, $tf4), 1,	"clone init 1c");
is($ofp->chmod(0770, $tf4), 1,		"clone init 1d");
isnt((stat($tf2))[STAT_PERMS], (stat($tf4))[STAT_PERMS], "clone check 1a");
isnt((stat($tf2))[STAT_MTIME], (stat($tf4))[STAT_MTIME], "clone check 1b");

is($ofp->cloner($tf2, $tf4), 1,		"cloner 1");
is((stat($tf2))[STAT_PERMS], (stat($tf4))[STAT_PERMS], "clone check 1c");
is((stat($tf2))[STAT_MTIME], (stat($tf4))[STAT_MTIME], "clone check 1d");

# ---- cloner: erase -----
sleep(2);
is($ofp->toucher(undef, $tf4), 1,	"clone init 2a");
is($ofp->chmod(0770, $tf4), 1,		"clone init 2b");
isnt((stat($tf2))[STAT_PERMS], (stat($tf4))[STAT_PERMS], "clone check 2a");
isnt((stat($tf2))[STAT_MTIME], (stat($tf4))[STAT_MTIME], "clone check 2b");

my $sf2_perms = (stat($tf2))[STAT_PERMS];
my $sf2_mtime = (stat($tf2))[STAT_MTIME];
is($ofp->cloner($tf2, $tf4, 1), 1,		"cloner 2");
is($sf2_perms, (stat($tf4))[STAT_PERMS],	"clone check 2c");
is($sf2_mtime, (stat($tf4))[STAT_MTIME],	"clone check 2d");
ok(!-f $tf2, 					"clone check 2e");


# ---- cleanup -----
ok( $ofp->delete($tf2) == 0,	"cleanup 1");
ok( $ofp->delete($tf4) == 0,	"cleanup 2");


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

