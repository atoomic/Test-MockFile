#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Errno qw( ENOENT ELOOP );
use Test::MockFile qw( nostrict );

# ===========================================================================
# Relative symlink targets must resolve relative to the directory
# containing the symlink, not relative to cwd.
# This matches POSIX semantics for symlink resolution.
# ===========================================================================

subtest 'simple relative symlink target' => sub {
    my $file = Test::MockFile->file( '/mock/dir/target.txt', 'hello world' );
    my $link = Test::MockFile->symlink( 'target.txt', '/mock/dir/link' );

    ok( -l '/mock/dir/link', 'link exists' );
    is( readlink('/mock/dir/link'), 'target.txt', 'readlink returns relative target' );

    # The key test: open via the symlink should find the target
    ok( open( my $fh, '<', '/mock/dir/link' ), 'open through relative symlink succeeds' )
      or diag "open failed: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    is( $content, 'hello world', 'read correct content through relative symlink' );
};

subtest 'relative symlink with .. in target' => sub {
    my $file = Test::MockFile->file( '/base/real_file.txt', 'found it' );
    my $link = Test::MockFile->symlink( '../base/real_file.txt', '/other/link' );

    ok( open( my $fh, '<', '/other/link' ), 'open through relative symlink with .. succeeds' )
      or diag "open failed: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    is( $content, 'found it', 'read correct content through ../ symlink' );
};

subtest 'relative symlink chain' => sub {
    my $file  = Test::MockFile->file( '/data/actual.txt', 'chained' );
    my $link1 = Test::MockFile->symlink( 'actual.txt', '/data/step1' );
    my $link2 = Test::MockFile->symlink( 'step1', '/data/step2' );

    ok( open( my $fh, '<', '/data/step2' ), 'open through chain of relative symlinks' )
      or diag "open failed: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    is( $content, 'chained', 'read correct content through chained relative symlinks' );
};

subtest 'stat follows relative symlink' => sub {
    my $file = Test::MockFile->file( '/statdir/real.txt', 'stat me' );
    my $link = Test::MockFile->symlink( 'real.txt', '/statdir/link' );

    ok( -e '/statdir/link', '-e follows relative symlink' );
    ok( -f '/statdir/link', '-f follows relative symlink to file' );
    ok( !-l '/statdir/real.txt', 'real file is not a symlink' );

    my @link_stat = stat('/statdir/link');
    my @file_stat = stat('/statdir/real.txt');
    is( $link_stat[7], $file_stat[7], 'stat size matches through relative symlink' );
};

subtest 'broken relative symlink' => sub {
    my $link = Test::MockFile->symlink( 'nonexistent.txt', '/broken/link' );

    ok( -l '/broken/link', 'broken relative symlink exists as link' );
    ok( !-e '/broken/link', 'broken relative symlink target does not exist' );

    my $ok = open( my $fh, '<', '/broken/link' );
    ok( !$ok, 'open on broken relative symlink fails' );
};

subtest 'write through relative symlink' => sub {
    my $file = Test::MockFile->file( '/wdir/target.txt', '' );
    my $link = Test::MockFile->symlink( 'target.txt', '/wdir/link' );

    ok( open( my $fh, '>', '/wdir/link' ), 'open for write through relative symlink' )
      or diag "open failed: $!";
    print $fh "written via link";
    close $fh;

    is( $file->contents(), 'written via link', 'write through relative symlink updates target' );
};

subtest 'unlink through relative symlink path' => sub {
    my $file = Test::MockFile->file( '/udir/target.txt', 'data' );
    my $link = Test::MockFile->symlink( 'target.txt', '/udir/link' );

    # unlink on a symlink removes the symlink, not the target
    ok( unlink('/udir/link'), 'unlink on relative symlink succeeds' );
    ok( !-l '/udir/link', 'symlink is removed' );
    ok( -f '/udir/target.txt', 'target file still exists' );
};

done_testing();
