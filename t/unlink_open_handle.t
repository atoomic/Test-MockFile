#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Test::MockFile qw< nostrict >;

# POSIX guarantee: open file descriptors survive unlink().
# The file data remains accessible through the handle until close().

subtest 'read after unlink preserves data' => sub {
    my $mock = Test::MockFile->file( '/fake/file', 'hello world' );

    open( my $fh, '<', '/fake/file' ) or die "open: $!";

    is( unlink('/fake/file'), 1, 'unlink succeeds' );
    ok( !-e '/fake/file', 'file no longer exists on filesystem' );

    my $buf;
    my $bytes = read( $fh, $buf, 100 );
    is( $bytes, 11,            'read returns correct byte count after unlink' );
    is( $buf,   'hello world', 'read returns correct data after unlink' );

    close $fh;
};

subtest 'readline after unlink preserves data' => sub {
    my $mock = Test::MockFile->file( '/fake/lines', "line1\nline2\nline3\n" );

    open( my $fh, '<', '/fake/lines' ) or die "open: $!";

    # Read first line before unlink
    my $first = <$fh>;
    is( $first, "line1\n", 'first line read before unlink' );

    is( unlink('/fake/lines'), 1, 'unlink succeeds' );

    # Remaining lines should still be readable
    my $second = <$fh>;
    is( $second, "line2\n", 'second line readable after unlink' );

    my $third = <$fh>;
    is( $third, "line3\n", 'third line readable after unlink' );

    my $eof = <$fh>;
    is( $eof, undef, 'EOF after all lines read' );

    close $fh;
};

subtest 'write after unlink preserves data in handle' => sub {
    my $mock = Test::MockFile->file( '/fake/writable', '' );

    open( my $fh, '+>', '/fake/writable' ) or die "open: $!";

    is( unlink('/fake/writable'), 1, 'unlink succeeds' );

    print $fh "written after unlink";

    seek( $fh, 0, 0 );
    my $content = do { local $/; <$fh> };
    is( $content, 'written after unlink', 'data written after unlink is readable from same handle' );

    close $fh;
};

subtest 'multiple handles survive unlink independently' => sub {
    my $mock = Test::MockFile->file( '/fake/multi', 'shared data' );

    open( my $fh1, '<', '/fake/multi' ) or die "open fh1: $!";
    open( my $fh2, '<', '/fake/multi' ) or die "open fh2: $!";

    # Advance fh1 past first 7 bytes
    read( $fh1, my $buf1, 7 );
    is( $buf1, 'shared ', 'fh1 reads first 7 bytes' );

    is( unlink('/fake/multi'), 1, 'unlink succeeds' );

    # fh2 should read from beginning (tell=0)
    read( $fh2, my $buf2, 11 );
    is( $buf2, 'shared data', 'fh2 reads full content after unlink' );

    # fh1 should continue from where it left off
    read( $fh1, my $buf3, 4 );
    is( $buf3, 'data', 'fh1 continues reading from offset after unlink' );

    close $fh1;
    close $fh2;
};

subtest 'tell and eof work after unlink' => sub {
    my $mock = Test::MockFile->file( '/fake/telleof', 'abcde' );

    open( my $fh, '<', '/fake/telleof' ) or die "open: $!";
    read( $fh, my $buf, 3 );

    is( unlink('/fake/telleof'), 1, 'unlink succeeds' );

    is( tell($fh), 3, 'tell preserved after unlink' );
    ok( !eof($fh), 'not at eof after unlink (data remaining)' );

    read( $fh, my $rest, 100 );
    is( $rest, 'de', 'remaining data readable' );
    ok( eof($fh), 'at eof after reading all data' );

    close $fh;
};

done_testing;
