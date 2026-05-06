#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Errno qw/ENOENT/;

use Test::MockFile qw< nostrict >;

# Test that IO::File handles are tracked in the 'fhs' array (not singular 'fh').
# Previously, _io_file_mock_open stored handles in $mock->{'fh'} (singular)
# while __open/__sysopen used $mock->{'fhs'} (array). This meant:
# 1. Multiple IO::File handles to same file overwrote each other's tracking
# 2. CLOSE didn't clean up the handle (CLOSE only cleans 'fhs')

note "-------------- Multiple IO::File handles to same mock file --------------";
{
    my $mock = Test::MockFile->file( '/fake/multi_handle', "shared data\n" );

    my $fh1 = IO::File->new( '/fake/multi_handle', 'r' );
    my $fh2 = IO::File->new( '/fake/multi_handle', 'r' );

    ok( defined $fh1, "First IO::File handle opens" );
    ok( defined $fh2, "Second IO::File handle opens" );

    # Both should be independently readable
    my $line1 = <$fh1>;
    my $line2 = <$fh2>;
    is( $line1, "shared data\n", "First handle reads correctly" );
    is( $line2, "shared data\n", "Second handle reads correctly" );

    $fh1->close;
    $fh2->close;
}

note "-------------- IO::File handle tracked in fhs array --------------";
{
    my $mock = Test::MockFile->file( '/fake/fhs_tracking', "test content\n" );

    my $fh = IO::File->new( '/fake/fhs_tracking', 'r' );
    ok( defined $fh, "IO::File handle opens" );

    # The handle should be in the 'fhs' array, not just 'fh' singular
    ok( $mock->{'fhs'}, "Mock has 'fhs' array after IO::File open" );
    is( scalar @{ $mock->{'fhs'} || [] }, 1, "fhs array has exactly 1 entry" );

    $fh->close;
}

note "-------------- IO::File CLOSE cleans up from fhs array --------------";
{
    my $mock = Test::MockFile->file( '/fake/close_cleanup', "cleanup test\n" );

    my $fh = IO::File->new( '/fake/close_cleanup', 'r' );
    ok( defined $fh, "IO::File handle opens" );
    is( scalar @{ $mock->{'fhs'} || [] }, 1, "fhs has 1 entry before close" );

    $fh->close;

    # After close, the handle should be removed from fhs
    my @live = grep { defined $_ } @{ $mock->{'fhs'} || [] };
    is( scalar @live, 0, "fhs cleaned up after close" );
}

note "-------------- IO::File write mode and reopen --------------";
{
    my $mock = Test::MockFile->file( '/fake/write_reopen', "original\n" );

    # Open for write (truncates), write something, close
    my $fh1 = IO::File->new( '/fake/write_reopen', 'w' );
    ok( defined $fh1, "IO::File write mode opens" );
    print $fh1 "written\n";
    $fh1->close;

    is( $mock->contents(), "written\n", "Write via IO::File updates mock contents" );

    # Reopen for read — should see updated contents
    my $fh2 = IO::File->new( '/fake/write_reopen', 'r' );
    ok( defined $fh2, "IO::File reopen for read works" );
    my $line = <$fh2>;
    is( $line, "written\n", "Reopen reads updated content" );
    $fh2->close;
}

note "-------------- IO::File write-open sets creation timestamps --------------";
{
    my $mock = Test::MockFile->file( '/fake/timestamps_new' );

    # Non-existent mock — timestamps should be 0 initially
    $mock->{'atime'} = 0;
    $mock->{'mtime'} = 0;
    $mock->{'ctime'} = 0;

    my $before = time;
    my $fh = IO::File->new( '/fake/timestamps_new', 'w' );
    my $after = time;
    ok( defined $fh, "IO::File write creates non-existent file" );
    print $fh "created\n";
    $fh->close;

    is( $mock->contents(), "created\n", "File contents set" );

    # All three timestamps should be updated for new file creation
    ok( $mock->{'atime'} >= $before && $mock->{'atime'} <= $after, "atime set on creation" );
    ok( $mock->{'mtime'} >= $before && $mock->{'mtime'} <= $after, "mtime set on creation" );
    ok( $mock->{'ctime'} >= $before && $mock->{'ctime'} <= $after, "ctime set on creation" );
}

note "-------------- IO::File truncate-open updates mtime/ctime --------------";
{
    my $mock = Test::MockFile->file( '/fake/timestamps_trunc', "existing data\n" );

    # Backdate timestamps so we can detect updates
    $mock->{'mtime'} = 1000;
    $mock->{'ctime'} = 1000;
    $mock->{'atime'} = 1000;

    my $before = time;
    my $fh = IO::File->new( '/fake/timestamps_trunc', 'w' );
    my $after = time;
    ok( defined $fh, "IO::File truncate-open works" );
    $fh->close;

    is( $mock->contents(), '', "Contents truncated" );

    # mtime and ctime updated on truncation of existing file
    ok( $mock->{'mtime'} >= $before && $mock->{'mtime'} <= $after, "mtime updated on truncate" );
    ok( $mock->{'ctime'} >= $before && $mock->{'ctime'} <= $after, "ctime updated on truncate" );

    # atime NOT updated on truncation (only on creation) — matches __open behavior
    is( $mock->{'atime'}, 1000, "atime unchanged on truncate" );
}

done_testing;
