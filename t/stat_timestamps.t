#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Fcntl qw< O_WRONLY O_RDWR O_CREAT O_TRUNC O_RDONLY >;

use Test::MockFile qw< nostrict >;

# Assures testers don't mess up with our hard coded perms expectations.
umask 022;

# Helper: freeze a mock's timestamps to a known past value (Jan 1982),
# so any time() call will produce a value far above it — no sleep needed.
sub _freeze_timestamps {
    my ($mock, $epoch) = @_;
    $epoch //= 1_000_000;
    $mock->atime($epoch);
    $mock->mtime($epoch);
    $mock->ctime($epoch);
    return $epoch;
}

subtest(
    'write via print updates mtime and ctime' => sub {
        my $mock = Test::MockFile->file( '/ts/print', '' );
        my $old  = _freeze_timestamps($mock);
        my $before = time;

        open my $fh, '>>', '/ts/print' or die "open: $!";
        print $fh "hello";
        close $fh;

        my @stat = stat('/ts/print');
        ok( $stat[9] >= $before,  'mtime updated after print' );
        ok( $stat[10] >= $before, 'ctime updated after print' );
        is( $stat[8], $old,       'atime unchanged after print (write-only)' );
    }
);

subtest(
    'write via syswrite updates mtime and ctime' => sub {
        my $mock = Test::MockFile->file( '/ts/syswrite', '' );
        my $old  = _freeze_timestamps($mock);
        my $before = time;

        sysopen my $fh, '/ts/syswrite', O_WRONLY | O_CREAT or die "sysopen: $!";
        syswrite $fh, "data";
        close $fh;

        my @stat = stat('/ts/syswrite');
        ok( $stat[9] >= $before,  'mtime updated after syswrite' );
        ok( $stat[10] >= $before, 'ctime updated after syswrite' );
        is( $stat[8], $old,       'atime unchanged after syswrite (write-only)' );
    }
);

subtest(
    'read via sysread updates atime' => sub {
        my $mock = Test::MockFile->file( '/ts/sysread', 'content here' );
        my $old  = _freeze_timestamps($mock);
        my $before = time;

        sysopen my $fh, '/ts/sysread', O_RDONLY or die "sysopen: $!";
        my $buf;
        sysread $fh, $buf, 5;
        close $fh;

        my @stat = stat('/ts/sysread');
        ok( $stat[8] >= $before, 'atime updated after sysread' );
        is( $stat[9], $old,      'mtime unchanged after sysread (read-only)' );
    }
);

subtest(
    'read via readline updates atime' => sub {
        my $mock = Test::MockFile->file( '/ts/readline', "line1\nline2\n" );
        my $old  = _freeze_timestamps($mock);
        my $before = time;

        open my $fh, '<', '/ts/readline' or die "open: $!";
        my $line = <$fh>;
        close $fh;

        my @stat = stat('/ts/readline');
        ok( $stat[8] >= $before, 'atime updated after readline' );
        is( $stat[9], $old,      'mtime unchanged after readline (read-only)' );
    }
);

subtest(
    'slurp via readline in list context updates atime' => sub {
        my $mock = Test::MockFile->file( '/ts/slurp', "a\nb\nc\n" );
        my $old  = _freeze_timestamps($mock);
        my $before = time;

        open my $fh, '<', '/ts/slurp' or die "open: $!";
        my @lines = <$fh>;
        close $fh;

        my @stat = stat('/ts/slurp');
        ok( $stat[8] >= $before, 'atime updated after slurp' );
        is( $stat[9], $old,      'mtime unchanged after slurp' );
    }
);

subtest(
    'chmod updates ctime only' => sub {
        my $mock = Test::MockFile->file( '/ts/chmod', 'x' );
        my $old  = _freeze_timestamps($mock);
        my $before = time;

        chmod 0755, '/ts/chmod';

        my @stat = stat('/ts/chmod');
        ok( $stat[10] >= $before, 'ctime updated after chmod' );
        is( $stat[8], $old,       'atime unchanged after chmod' );
        is( $stat[9], $old,       'mtime unchanged after chmod' );
    }
);

subtest(
    'chown updates ctime only' => sub {
        my $mock = Test::MockFile->file( '/ts/chown', 'x' );
        my $old  = _freeze_timestamps($mock);
        my $before = time;

        chown $>, $), '/ts/chown';

        my @stat = stat('/ts/chown');
        ok( $stat[10] >= $before, 'ctime updated after chown' );
        is( $stat[8], $old,       'atime unchanged after chown' );
        is( $stat[9], $old,       'mtime unchanged after chown' );
    }
);

subtest(
    'open with > (truncate) updates mtime and ctime' => sub {
        my $mock = Test::MockFile->file( '/ts/trunc', 'existing content' );
        my $old  = _freeze_timestamps($mock);
        my $before = time;

        open my $fh, '>', '/ts/trunc' or die "open: $!";
        close $fh;

        my @stat = stat('/ts/trunc');
        ok( $stat[9] >= $before,  'mtime updated after truncating open' );
        ok( $stat[10] >= $before, 'ctime updated after truncating open' );
        is( $stat[8], $old,       'atime unchanged after truncating open' );
    }
);

subtest(
    'sysopen with O_TRUNC updates mtime and ctime' => sub {
        my $mock = Test::MockFile->file( '/ts/systrunc', 'existing content' );
        my $old  = _freeze_timestamps($mock);
        my $before = time;

        sysopen my $fh, '/ts/systrunc', O_WRONLY | O_TRUNC or die "sysopen: $!";
        close $fh;

        my @stat = stat('/ts/systrunc');
        ok( $stat[9] >= $before,  'mtime updated after O_TRUNC sysopen' );
        ok( $stat[10] >= $before, 'ctime updated after O_TRUNC sysopen' );
        is( $stat[8], $old,       'atime unchanged after O_TRUNC sysopen' );
    }
);

subtest(
    'sysopen with O_CREAT on new file updates mtime and ctime' => sub {
        my $mock = Test::MockFile->file('/ts/creat');    # non-existent mock
        my $old  = _freeze_timestamps($mock);
        my $before = time;

        sysopen my $fh, '/ts/creat', O_WRONLY | O_CREAT or die "sysopen: $!";
        close $fh;

        my @stat = stat('/ts/creat');
        ok( $stat[9] >= $before,  'mtime updated after O_CREAT sysopen' );
        ok( $stat[10] >= $before, 'ctime updated after O_CREAT sysopen' );
    }
);

subtest(
    'open with >> (append) does not update mtime until write' => sub {
        my $mock = Test::MockFile->file( '/ts/append', 'old' );
        my $old  = _freeze_timestamps($mock);
        my $before = time;

        open my $fh, '>>', '/ts/append' or die "open: $!";

        # Just opening in append mode shouldn't change mtime.
        my @stat_before_write = stat('/ts/append');
        is( $stat_before_write[9], $old, 'mtime unchanged after opening in append mode' );

        # Writing should update mtime.
        print $fh "new";
        close $fh;

        my @stat_after_write = stat('/ts/append');
        ok( $stat_after_write[9] >= $before, 'mtime updated after writing in append mode' );
    }
);

subtest(
    'writing empty string does not update mtime' => sub {
        my $mock = Test::MockFile->file( '/ts/empty_write', 'content' );
        my $old  = _freeze_timestamps($mock);

        open my $fh, '>>', '/ts/empty_write' or die "open: $!";
        print $fh '';    # zero-length write
        close $fh;

        my @stat = stat('/ts/empty_write');
        is( $stat[9], $old, 'mtime unchanged after zero-length write' );
    }
);

subtest(
    'read+write mode updates both atime and mtime' => sub {
        my $mock = Test::MockFile->file( '/ts/rw', 'original' );
        my $old  = _freeze_timestamps($mock);
        my $before = time;

        open my $fh, '+<', '/ts/rw' or die "open: $!";
        my $line = <$fh>;    # read — should update atime
        print $fh "added";   # write — should update mtime
        close $fh;

        my @stat = stat('/ts/rw');
        ok( $stat[8] >= $before,  'atime updated after read in +< mode' );
        ok( $stat[9] >= $before,  'mtime updated after write in +< mode' );
        ok( $stat[10] >= $before, 'ctime updated after write in +< mode' );
    }
);

done_testing();
exit;
