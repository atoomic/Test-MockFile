#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Encode ();

use Test::MockFile qw< nostrict >;

# ===== Test 1: binmode with :utf8 layer via open mode =====
note "--- open with :utf8 layer ---";
{
    # UTF-8 encoded bytes for "café" (c a f U+00E9)
    my $utf8_bytes = "caf\xc3\xa9\n";
    my $mock = Test::MockFile->file( '/tmp/utf8_test.txt', $utf8_bytes );

    open( my $fh, '<:utf8', '/tmp/utf8_test.txt' ) or die "open failed: $!";
    my $line = <$fh>;
    close $fh;

    ok( utf8::is_utf8($line), "Reading with :utf8 produces a UTF-8 flagged string" );
    is( $line, "caf\x{e9}\n", "Content is correctly decoded from UTF-8" );
}

# ===== Test 2: binmode with :utf8 layer via binmode() call =====
note "--- binmode(\$fh, ':utf8') after open ---";
{
    my $utf8_bytes = "caf\xc3\xa9\n";
    my $mock = Test::MockFile->file( '/tmp/binmode_test.txt', $utf8_bytes );

    open( my $fh, '<', '/tmp/binmode_test.txt' ) or die "open failed: $!";
    binmode( $fh, ':utf8' );
    my $line = <$fh>;
    close $fh;

    ok( utf8::is_utf8($line), "binmode :utf8 after open decodes on read" );
    is( $line, "caf\x{e9}\n", "Content correctly decoded via binmode" );
}

# ===== Test 3: Writing with :utf8 encodes to bytes =====
note "--- write with :utf8 layer ---";
{
    my $mock = Test::MockFile->file( '/tmp/write_utf8.txt', '' );

    open( my $fh, '>:utf8', '/tmp/write_utf8.txt' ) or die "open failed: $!";
    print $fh "caf\x{e9}\n";
    close $fh;

    # Contents should be UTF-8 encoded bytes
    my $contents = $mock->contents();
    is( $contents, "caf\xc3\xa9\n", "Writing with :utf8 encodes characters to UTF-8 bytes" );
}

# ===== Test 4: binmode with :encoding(UTF-8) =====
note "--- :encoding(UTF-8) layer ---";
{
    my $utf8_bytes = "caf\xc3\xa9\n";
    my $mock = Test::MockFile->file( '/tmp/encoding_test.txt', $utf8_bytes );

    open( my $fh, '<:encoding(UTF-8)', '/tmp/encoding_test.txt' ) or die "open failed: $!";
    my $line = <$fh>;
    close $fh;

    ok( utf8::is_utf8($line), ":encoding(UTF-8) decodes on read" );
    is( $line, "caf\x{e9}\n", "Content correctly decoded via :encoding(UTF-8)" );
}

# ===== Test 5: binmode with :raw removes layers =====
note "--- :raw layer ---";
{
    my $utf8_bytes = "caf\xc3\xa9\n";
    my $mock = Test::MockFile->file( '/tmp/raw_test.txt', $utf8_bytes );

    open( my $fh, '<:utf8', '/tmp/raw_test.txt' ) or die "open failed: $!";
    binmode( $fh, ':raw' );
    my $line = <$fh>;
    close $fh;

    # After :raw, data should come through as-is (bytes, not decoded)
    ok( !utf8::is_utf8($line), ":raw removes utf8 layer — no UTF-8 flag" );
    is( $line, "caf\xc3\xa9\n", "Content is raw bytes after :raw" );
}

# ===== Test 6: binmode with no args (= :raw) =====
note "--- binmode(\$fh) with no layer arg ---";
{
    my $utf8_bytes = "caf\xc3\xa9\n";
    my $mock = Test::MockFile->file( '/tmp/noarg_test.txt', $utf8_bytes );

    open( my $fh, '<:utf8', '/tmp/noarg_test.txt' ) or die "open failed: $!";
    binmode($fh);
    my $line = <$fh>;
    close $fh;

    ok( !utf8::is_utf8($line), "binmode with no args = :raw" );
    is( $line, "caf\xc3\xa9\n", "Content is raw bytes after bare binmode" );
}

# ===== Test 7: sysread with :utf8 layer =====
note "--- sysread with :utf8 ---";
{
    my $utf8_bytes = "caf\xc3\xa9";
    my $mock = Test::MockFile->file( '/tmp/sysread_utf8.txt', $utf8_bytes );

    open( my $fh, '<:utf8', '/tmp/sysread_utf8.txt' ) or die "open failed: $!";
    my $buf;
    my $n = read( $fh, $buf, 100 );
    close $fh;

    ok( defined $n, "read() with :utf8 layer succeeds" );
    ok( utf8::is_utf8($buf), "read() buffer has UTF-8 flag when :utf8 active" );
}

# ===== Test 8: syswrite with :utf8 layer =====
note "--- syswrite with :utf8 ---";
{
    my $mock = Test::MockFile->file( '/tmp/syswrite_utf8.txt', '' );

    open( my $fh, '>:utf8', '/tmp/syswrite_utf8.txt' ) or die "open failed: $!";
    my $data = "caf\x{e9}";
    syswrite( $fh, $data, length($data) );
    close $fh;

    my $contents = $mock->contents();
    is( $contents, "caf\xc3\xa9", "syswrite with :utf8 encodes to UTF-8 bytes" );
}

# ===== Test 9: :bytes layer removes encoding =====
note "--- :bytes layer ---";
{
    my $utf8_bytes = "caf\xc3\xa9\n";
    my $mock = Test::MockFile->file( '/tmp/bytes_test.txt', $utf8_bytes );

    open( my $fh, '<:utf8', '/tmp/bytes_test.txt' ) or die "open failed: $!";
    binmode( $fh, ':bytes' );
    my $line = <$fh>;
    close $fh;

    ok( !utf8::is_utf8($line), ":bytes removes utf8 layer" );
}

# ===== Test 10: binmode on non-mocked filehandle passes through =====
note "--- binmode passthrough for non-mocked handles ---";
{
    open( my $fh, '<', '/dev/null' ) or die "open failed: $!";
    my $ret = binmode( $fh, ':raw' );
    ok( $ret, "binmode on non-mocked filehandle passes through to CORE" );
    close $fh;
}

# ===== Test 11: Multiple encoding changes =====
note "--- multiple binmode calls ---";
{
    my $utf8_bytes = "caf\xc3\xa9\n";
    my $mock = Test::MockFile->file( '/tmp/multi_binmode.txt', $utf8_bytes );

    open( my $fh, '<', '/tmp/multi_binmode.txt' ) or die "open failed: $!";

    # Start without layer — raw read
    binmode( $fh, ':utf8' );    # Add utf8
    binmode( $fh, ':raw' );     # Remove it
    binmode( $fh, ':utf8' );    # Add it back

    my $line = <$fh>;
    close $fh;

    ok( utf8::is_utf8($line), "Multiple binmode calls — last :utf8 wins" );
    is( $line, "caf\x{e9}\n", "Content correctly decoded after binmode dance" );
}

# ===== Test 12: :crlf layer =====
note "--- :crlf layer ---";
{
    my $crlf_content = "line1\r\nline2\r\n";
    my $mock = Test::MockFile->file( '/tmp/crlf_test.txt', $crlf_content );

    open( my $fh, '<', '/tmp/crlf_test.txt' ) or die "open failed: $!";
    binmode( $fh, ':crlf' );
    my $line1 = <$fh>;
    my $line2 = <$fh>;
    close $fh;

    is( $line1, "line1\n", ":crlf translates \\r\\n to \\n on read (line 1)" );
    is( $line2, "line2\n", ":crlf translates \\r\\n to \\n on read (line 2)" );
}

# ===== Test 13: Write with :crlf layer =====
note "--- write with :crlf ---";
{
    my $mock = Test::MockFile->file( '/tmp/write_crlf.txt', '' );

    open( my $fh, '>', '/tmp/write_crlf.txt' ) or die "open failed: $!";
    binmode( $fh, ':crlf' );
    print $fh "line1\nline2\n";
    close $fh;

    is( $mock->contents(), "line1\r\nline2\r\n", ":crlf translates \\n to \\r\\n on write" );
}

# ===== Test 14: binmode return value =====
note "--- binmode return values ---";
{
    my $mock = Test::MockFile->file( '/tmp/ret_test.txt', 'data' );

    open( my $fh, '<', '/tmp/ret_test.txt' ) or die "open failed: $!";
    my $ret1 = binmode($fh);
    ok( $ret1, "binmode() with no args returns true" );

    my $ret2 = binmode( $fh, ':utf8' );
    ok( $ret2, "binmode(:utf8) returns true" );

    my $ret3 = binmode( $fh, ':raw' );
    ok( $ret3, "binmode(:raw) returns true" );

    close $fh;
}

done_testing();
