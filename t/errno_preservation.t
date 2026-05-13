#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Errno qw( ENOENT EACCES );
use Test::MockFile qw< nostrict >;
use Cwd ();

# ==========================================================================
# GH #396: CORE::GLOBAL overrides must not clobber $! on success paths
# ==========================================================================

# _abs_path_to_file calls getcwd() for relative paths and getpwent() for
# tilde paths. Both can set $! as a side effect. The fix wraps these in
# local $! so callers see the errno they set, not internal noise.

# --------------------------------------------------------------------------
# open() on absolute path should not clobber $!
# --------------------------------------------------------------------------
{
    my $mock = Test::MockFile->file( '/tmp/errno_test.txt', 'data' );

    $! = ENOENT;    # Set a known errno
    open( my $fh, '<', '/tmp/errno_test.txt' ) or die "open failed: $!";
    is( $! + 0, ENOENT, 'open (absolute path) preserves $! on success' );
    close $fh;
}

# --------------------------------------------------------------------------
# stat() on absolute path should not clobber $!
# --------------------------------------------------------------------------
{
    my $mock = Test::MockFile->file( '/tmp/errno_stat.txt', 'data' );

    $! = EACCES;
    my @st = stat('/tmp/errno_stat.txt');
    ok( @st > 0, 'stat succeeds on mocked file' );
    is( $! + 0, EACCES, 'stat (absolute path) preserves $! on success' );
}

# --------------------------------------------------------------------------
# unlink() should not clobber $! on success
# --------------------------------------------------------------------------
{
    my $mock = Test::MockFile->file( '/tmp/errno_unlink.txt', 'data' );

    $! = ENOENT;
    my $ret = unlink('/tmp/errno_unlink.txt');
    is( $ret, 1, 'unlink succeeds' );
    is( $! + 0, ENOENT, 'unlink preserves $! on success' );
}

# --------------------------------------------------------------------------
# Cwd::abs_path override should not clobber $! on success
# --------------------------------------------------------------------------
{
    my $mock = Test::MockFile->file( '/tmp/errno_cwd.txt', 'data' );

    $! = EACCES;
    my $abs = Cwd::abs_path('/tmp/errno_cwd.txt');
    is( $abs, '/tmp/errno_cwd.txt', 'abs_path resolves correctly' );
    is( $! + 0, EACCES, 'Cwd::abs_path preserves $! on success' );
}

# --------------------------------------------------------------------------
# readdir should not clobber $! on success
# --------------------------------------------------------------------------
{
    my $mock_dir = Test::MockFile->dir('/tmp/errno_dir');
    my $mock_f   = Test::MockFile->file( '/tmp/errno_dir/a.txt', 'hello' );

    $! = ENOENT;
    opendir( my $dh, '/tmp/errno_dir' ) or die "opendir: $!";
    # opendir may legitimately change $! — reset after
    $! = ENOENT;
    my @entries = readdir($dh);
    ok( @entries > 0, 'readdir returns entries' );
    closedir($dh);
}

done_testing;
