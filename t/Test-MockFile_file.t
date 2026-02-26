#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Errno qw/ENOENT EBADF/;
use Fcntl qw(:mode);

use Test::MockFile ();

subtest 'file() creates non-existent mock placeholder' => sub {
    my $mock = Test::MockFile->file('/fake/nonexistent');

    ok( $mock, 'file() returns an object' );
    is( $mock->exists(), 0, 'file does not exist' );
    is( $mock->contents(), undef, 'contents is undef' );
    ok( !-e '/fake/nonexistent', '-e returns false' );
    ok( !-f '/fake/nonexistent', '-f returns false' );
    ok( !-d '/fake/nonexistent', '-d returns false' );

    # stat should fail with ENOENT
    $! = 0;
    ok( !stat('/fake/nonexistent'), 'stat fails for non-existent mock' );
};

subtest 'file() with contents creates existing mock' => sub {
    my $mock = Test::MockFile->file( '/fake/hello.txt', 'Hello World' );

    ok( $mock, 'file() with contents returns an object' );
    is( $mock->exists(), 1, 'file exists' );
    is( $mock->contents(), 'Hello World', 'contents matches' );
    ok( -e '/fake/hello.txt', '-e returns true' );
    ok( -f '/fake/hello.txt', '-f returns true' );
    ok( !-d '/fake/hello.txt', '-d returns false for a file' );
    ok( !-l '/fake/hello.txt', '-l returns false for a file' );

    is( -s '/fake/hello.txt', 11, '-s returns correct file size' );
};

subtest 'file() with empty string contents' => sub {
    my $mock = Test::MockFile->file( '/fake/empty.txt', '' );

    is( $mock->exists(), 1, 'file with empty string exists' );
    is( $mock->contents(), '', 'contents is empty string' );
    ok( -e '/fake/empty.txt', '-e returns true for empty file' );
    ok( -f '/fake/empty.txt', '-f returns true for empty file' );
    is( -s '/fake/empty.txt', 0, '-s returns 0 for empty file' );
    ok( -z '/fake/empty.txt', '-z returns true for empty file' );
};

subtest 'file() default stat values' => sub {
    my $now  = time;
    my $mock = Test::MockFile->file( '/fake/defaults.txt', 'data' );
    my @stat = $mock->stat;

    # dev, ino, mode, nlink, uid, gid, rdev, size, atime, mtime, ctime, blksize, blocks
    is( scalar @stat, 13, 'stat returns 13 elements' );

    # mode: should be regular file + default perms (0666 ^ umask)
    my $expected_perms = 0666 & ~umask;
    is( $stat[2] & S_IFMT, S_IFREG, 'mode has S_IFREG type' );
    is( $stat[2] & S_IFPERMS, $expected_perms, 'mode has expected permissions' );

    # size matches contents
    is( $stat[7], 4, 'size in stat matches contents length' );

    # timestamps should be recent
    ok( $stat[8] >= $now, 'atime is recent' );
    ok( $stat[9] >= $now, 'mtime is recent' );
    ok( $stat[10] >= $now, 'ctime is recent' );
};

subtest 'file() with custom stat overrides' => sub {
    my $mock = Test::MockFile->file(
        '/fake/custom.txt', 'data',
        {
            mode  => 0644,
            uid   => 1000,
            gid   => 1000,
            mtime => 1_000_000,
            atime => 1_000_000,
            ctime => 1_000_000,
        }
    );

    my @stat = $mock->stat;
    is( $stat[2] & S_IFPERMS, 0644, 'mode perms match override' );
    is( $stat[2] & S_IFMT, S_IFREG, 'mode still has S_IFREG type' );
    is( $stat[4], 1000, 'uid matches override' );
    is( $stat[5], 1000, 'gid matches override' );
    is( $stat[9], 1_000_000, 'mtime matches override' );
    is( $stat[8], 1_000_000, 'atime matches override' );
    is( $stat[10], 1_000_000, 'ctime matches override' );
};

subtest 'file() is_file / is_dir / is_link checks' => sub {
    my $file = Test::MockFile->file( '/fake/regular.txt', 'content' );
    is( $file->is_file(), 1, 'is_file returns 1 for file mock' );
    is( $file->is_dir(),  0, 'is_dir returns 0 for file mock' );
    is( $file->is_link(), 0, 'is_link returns 0 for file mock' );
};

subtest 'file() contents can be modified' => sub {
    my $mock = Test::MockFile->file( '/fake/mutable.txt', 'original' );

    is( $mock->contents(), 'original', 'initial contents' );
    is( -s '/fake/mutable.txt', 8, 'initial size' );

    $mock->contents('new content');
    is( $mock->contents(), 'new content', 'contents updated' );
    is( -s '/fake/mutable.txt', 11, 'size updated after contents change' );
};

subtest 'file() open read works' => sub {
    my $mock = Test::MockFile->file( '/fake/readable.txt', "line1\nline2\nline3\n" );

    ok( open( my $fh, '<', '/fake/readable.txt' ), 'open for reading succeeds' );
    my @lines = <$fh>;
    is( scalar @lines, 3, 'read 3 lines' );
    is( $lines[0], "line1\n", 'first line correct' );
    is( $lines[1], "line2\n", 'second line correct' );
    is( $lines[2], "line3\n", 'third line correct' );
    close $fh;
};

subtest 'file() open write truncates' => sub {
    my $mock = Test::MockFile->file( '/fake/writable.txt', 'old data' );

    ok( open( my $fh, '>', '/fake/writable.txt' ), 'open for writing succeeds' );
    print $fh "new data";
    close $fh;

    is( $mock->contents(), 'new data', 'contents replaced after > open + write' );
};

subtest 'file() open append works' => sub {
    my $mock = Test::MockFile->file( '/fake/appendable.txt', 'first' );

    ok( open( my $fh, '>>', '/fake/appendable.txt' ), 'open for append succeeds' );
    print $fh ' second';
    close $fh;

    is( $mock->contents(), 'first second', 'contents appended' );
};

subtest 'file() open read non-existent fails with ENOENT' => sub {
    my $mock = Test::MockFile->file('/fake/missing.txt');

    $! = 0;
    ok( !open( my $fh, '<', '/fake/missing.txt' ), 'open < on non-existent fails' );
    is( $! + 0, ENOENT, '$! is ENOENT' );
};

subtest 'file() open write creates non-existent file' => sub {
    my $mock = Test::MockFile->file('/fake/will_create.txt');

    is( $mock->exists(), 0, 'file does not exist initially' );

    ok( open( my $fh, '>', '/fake/will_create.txt' ), 'open > on non-existent succeeds' );
    print $fh "created";
    close $fh;

    is( $mock->exists(), 1, 'file now exists' );
    is( $mock->contents(), 'created', 'contents correct' );
};

subtest 'file() unlink makes file non-existent' => sub {
    my $mock = Test::MockFile->file( '/fake/to_delete.txt', 'data' );

    is( $mock->exists(), 1, 'file exists before unlink' );
    is( unlink('/fake/to_delete.txt'), 1, 'unlink returns 1' );
    is( $mock->exists(), 0, 'file does not exist after unlink' );
    ok( !-e '/fake/to_delete.txt', '-e returns false after unlink' );
};

subtest 'file() unlink on non-existent returns ENOENT' => sub {
    my $mock = Test::MockFile->file('/fake/already_gone.txt');

    $! = 0;
    is( unlink('/fake/already_gone.txt'), 0, 'unlink on non-existent returns 0' );
    is( $! + 0, ENOENT, '$! is ENOENT' );
};

subtest 'file() path method returns the path' => sub {
    my $mock = Test::MockFile->file( '/fake/path_test.txt', 'x' );
    is( $mock->path(), '/fake/path_test.txt', 'path() returns correct path' );
};

subtest 'file() size method' => sub {
    my $mock = Test::MockFile->file( '/fake/sized.txt', 'abcde' );

    is( $mock->size(), 5, 'size() returns content length' );
    is( -s '/fake/sized.txt', 5, '-s matches size()' );

    $mock->contents('');
    is( $mock->size(), 0, 'size() is 0 for empty contents' );

    my $gone = Test::MockFile->file('/fake/nosize.txt');
    is( $gone->size(), undef, 'size() is undef for non-existent' );
};

subtest 'file() blocks method' => sub {
    my $mock = Test::MockFile->file( '/fake/blocks.txt', 'a' x 8192 );

    my $blocks = $mock->blocks();
    ok( $blocks > 0, "blocks() returns positive value for file with data ($blocks)" );

    my @stat = stat('/fake/blocks.txt');
    is( $stat[12], $blocks, 'blocks from stat matches blocks()' );
};

subtest 'file() multiple mocks dont interfere' => sub {
    my $mock_a = Test::MockFile->file( '/fake/file_a.txt', 'aaa' );
    my $mock_b = Test::MockFile->file( '/fake/file_b.txt', 'bbb' );

    is( $mock_a->contents(), 'aaa', 'file_a has its own contents' );
    is( $mock_b->contents(), 'bbb', 'file_b has its own contents' );

    ok( -e '/fake/file_a.txt', 'file_a exists' );
    ok( -e '/fake/file_b.txt', 'file_b exists' );

    # Modify one, ensure other is untouched
    $mock_a->contents('AAA');
    is( $mock_a->contents(), 'AAA', 'file_a updated' );
    is( $mock_b->contents(), 'bbb', 'file_b unchanged' );
};

subtest 'file() scope cleanup removes mock' => sub {
    {
        my $mock = Test::MockFile->file( '/fake/scoped.txt', 'temporary' );
        ok( -e '/fake/scoped.txt', 'file exists in scope' );
    }
    # After scope exit, mock is destroyed — falls through to real FS
    # Since /fake/scoped.txt doesnt exist on disk, this should fail
    ok( !-e '/fake/scoped.txt', 'file no longer mocked after scope exit' );
};

subtest 'file() sysopen and syswrite/sysread' => sub {
    my $mock = Test::MockFile->file( '/fake/sysio.txt', 'initial' );

    my $fh;
    ok( sysopen( $fh, '/fake/sysio.txt', O_RDONLY ), 'sysopen O_RDONLY succeeds' );
    my $buf;
    my $nread = sysread( $fh, $buf, 100 );
    is( $nread, 7, 'sysread returns byte count' );
    is( $buf, 'initial', 'sysread gets correct data' );
    close $fh;
};

subtest 'file() stat via filehandle' => sub {
    my $mock = Test::MockFile->file( '/fake/fh_stat.txt', 'content' );

    open( my $fh, '<', '/fake/fh_stat.txt' ) or die "open failed: $!";
    my @stat = stat($fh);
    is( scalar @stat, 13, 'stat on filehandle returns 13 elements' );
    is( $stat[7], 7, 'size from fh stat matches content length' );
    close $fh;
};

subtest 'file() touch on non-existent creates it' => sub {
    my $mock = Test::MockFile->file('/fake/touch_target.txt');

    is( $mock->exists(), 0, 'does not exist before touch' );

    my $now = time;
    $mock->touch();

    is( $mock->exists(), 1, 'exists after touch' );
    ok( $mock->mtime() >= $now, 'mtime updated by touch' );
};

subtest 'file() read-write mode (+<)' => sub {
    my $mock = Test::MockFile->file( '/fake/readwrite.txt', 'ABCDE' );

    ok( open( my $fh, '+<', '/fake/readwrite.txt' ), 'open +< succeeds' );

    # Read first
    my $line = <$fh>;
    is( $line, 'ABCDE', 'read gets full contents' );

    # Write at end
    seek( $fh, 0, 2 );    # seek to end
    print $fh 'FG';
    close $fh;

    is( $mock->contents(), 'ABCDEFG', 'write appended after read in +< mode' );
};

done_testing();
