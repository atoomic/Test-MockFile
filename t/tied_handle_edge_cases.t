#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Fcntl qw( O_RDONLY O_WRONLY O_CREAT O_TRUNC O_RDWR O_APPEND SEEK_SET SEEK_CUR SEEK_END );
use Errno qw( EBADF );

use Test::MockFile qw< nostrict >;

# ============================================================
# getc edge cases
# ============================================================

{
    note "--- getc after seek to middle of file ---";

    my $mock = Test::MockFile->file( '/fake/getc_seek', "ABCDE" );
    open( my $fh, '<', '/fake/getc_seek' ) or die;

    seek( $fh, 2, SEEK_SET );
    my $ch = getc($fh);
    is( $ch, 'C', "getc after seek(2) returns 3rd character" );
    is( tell($fh), 3, "tell is 3 after getc" );

    $ch = getc($fh);
    is( $ch, 'D', "next getc returns 4th character" );
    is( tell($fh), 4, "tell is 4 after second getc" );

    close $fh;
}

{
    note "--- getc after seek to end of file returns undef ---";

    my $mock = Test::MockFile->file( '/fake/getc_eof', "AB" );
    open( my $fh, '<', '/fake/getc_eof' ) or die;

    seek( $fh, 0, SEEK_END );
    my $ch = getc($fh);
    ok( !defined $ch, "getc at EOF returns undef" );

    close $fh;
}

{
    note "--- getc reads one byte at a time across full file ---";

    my $mock = Test::MockFile->file( '/fake/getc_full', "XYZ" );
    open( my $fh, '<', '/fake/getc_full' ) or die;

    my @chars;
    while ( defined( my $c = getc($fh) ) ) {
        push @chars, $c;
    }
    is( \@chars, [qw( X Y Z )], "getc iterates all 3 characters" );
    ok( !defined getc($fh), "getc returns undef after last character" );

    close $fh;
}

{
    note "--- getc on write-only handle warns and returns undef ---";

    my $mock = Test::MockFile->file('/fake/getc_writeonly');
    open( my $fh, '>', '/fake/getc_writeonly' ) or die;

    my @warns;
    local $SIG{__WARN__} = sub { push @warns, $_[0] };

    my $ch = getc($fh);
    ok( !defined $ch, "getc on write-only handle returns undef" );
    ok( @warns >= 1, "warning emitted for getc on write-only handle" );
    like( $warns[0], qr/opened only for output/, "warning mentions output-only" );

    close $fh;
}

{
    note "--- getc after partial readline ---";

    my $mock = Test::MockFile->file( '/fake/getc_after_read', "Hello\nWorld\n" );
    open( my $fh, '<', '/fake/getc_after_read' ) or die;

    my $line = <$fh>;
    is( $line, "Hello\n", "readline gets first line" );

    my $ch = getc($fh);
    is( $ch, 'W', "getc after readline continues from correct position" );

    close $fh;
}

{
    note "--- getc on empty file returns undef ---";

    my $mock = Test::MockFile->file( '/fake/getc_empty', '' );
    open( my $fh, '<', '/fake/getc_empty' ) or die;

    my $ch = getc($fh);
    ok( !defined $ch, "getc on empty file returns undef" );

    close $fh;
}

# ============================================================
# printf edge cases
# ============================================================

{
    note "--- printf with various format specifiers ---";

    my $mock = Test::MockFile->file('/fake/printf_formats');
    open( my $fh, '>', '/fake/printf_formats' ) or die;

    printf $fh "%05d", 42;
    printf $fh "|%-10s|", "left";
    printf $fh "%.2f", 3.14159;

    close $fh;
    is( $mock->contents, "00042|left      |3.14", "printf handles numeric and string formats" );
}

{
    note "--- printf with %% literal percent ---";

    my $mock = Test::MockFile->file('/fake/printf_pct');
    open( my $fh, '>', '/fake/printf_pct' ) or die;

    printf $fh "100%%";

    close $fh;
    is( $mock->contents, "100%", "printf %% produces literal percent" );
}

{
    note "--- printf on read-only handle returns undef with EBADF ---";

    my $mock = Test::MockFile->file( '/fake/printf_rdonly', "data" );
    open( my $fh, '<', '/fake/printf_rdonly' ) or die;

    $! = 0;
    my $ret = printf $fh "hello";
    ok( !$ret, "printf on read-only handle returns false" );
    is( $! + 0, EBADF, "errno is EBADF" );

    close $fh;
}

{
    note "--- printf advances tell correctly ---";

    my $mock = Test::MockFile->file('/fake/printf_tell');
    open( my $fh, '>', '/fake/printf_tell' ) or die;

    printf $fh "AB";
    is( tell($fh), 2, "tell is 2 after printf 'AB'" );

    printf $fh "%03d", 7;
    is( tell($fh), 5, "tell is 5 after printf '%03d' (writes '007')" );

    close $fh;
    is( $mock->contents, "AB007", "final contents correct" );
}

{
    note "--- printf returns 1 on success (boolean, like print) ---";

    my $mock = Test::MockFile->file('/fake/printf_retval');
    open( my $fh, '>', '/fake/printf_retval' ) or die;

    my $ret = printf $fh "%s", "test";
    is( $ret, 1, "printf returns 1 on success" );

    close $fh;
}

# ============================================================
# eof() state tracking
# ============================================================

{
    note "--- eof becomes false after seek back from EOF ---";

    my $mock = Test::MockFile->file( '/fake/eof_seek', "AB" );
    open( my $fh, '<', '/fake/eof_seek' ) or die;

    my $buf;
    read( $fh, $buf, 10 );
    ok( eof($fh), "eof is true after reading all content" );

    seek( $fh, 0, SEEK_SET );
    ok( !eof($fh), "eof becomes false after seeking back to start" );

    close $fh;
}

{
    note "--- eof on empty file ---";

    my $mock = Test::MockFile->file( '/fake/eof_empty', '' );
    open( my $fh, '<', '/fake/eof_empty' ) or die;

    ok( eof($fh), "eof is true on empty file immediately" );

    close $fh;
}

{
    note "--- eof after write extends content ---";

    my $mock = Test::MockFile->file( '/fake/eof_write', "A" );
    open( my $fh, '+<', '/fake/eof_write' ) or die;

    read( $fh, my $buf, 1 );
    ok( eof($fh), "eof true after reading 1 byte of 1-byte file" );

    print $fh "BC";
    ok( eof($fh), "eof still true: tell(3) >= length('ABC')=3" );

    seek( $fh, 0, SEEK_SET );
    ok( !eof($fh), "eof false after seeking to start of now-3-byte file" );

    close $fh;
}

# ============================================================
# Interleaved read + write in +< mode
# ============================================================

{
    note "--- read, seek, overwrite, read back ---";

    my $mock = Test::MockFile->file( '/fake/rw_interleave', "AABBCC" );
    open( my $fh, '+<', '/fake/rw_interleave' ) or die;

    # Read first 2 bytes
    read( $fh, my $buf, 2 );
    is( $buf, "AA", "initial read" );

    # Overwrite bytes 2-3 with XX
    print $fh "XX";
    is( tell($fh), 4, "tell after overwrite" );

    # Seek back and read the whole thing
    seek( $fh, 0, SEEK_SET );
    read( $fh, $buf, 6 );
    is( $buf, "AAXXCC", "overwritten bytes visible on re-read" );

    close $fh;
    is( $mock->contents, "AAXXCC", "mock contents reflect overwrite" );
}

{
    note "--- print then getc in +< mode ---";

    my $mock = Test::MockFile->file( '/fake/rw_print_getc', "Hello" );
    open( my $fh, '+<', '/fake/rw_print_getc' ) or die;

    # Overwrite first char
    print $fh "J";
    is( tell($fh), 1, "tell is 1 after print 'J'" );

    # getc reads next char
    my $ch = getc($fh);
    is( $ch, 'e', "getc reads 2nd character after print" );

    close $fh;
    is( $mock->contents, "Jello", "contents reflect 'Hello' -> 'Jello'" );
}

{
    note "--- syswrite then readline in +< mode ---";

    my $mock = Test::MockFile->file( '/fake/rw_sysw_read', "line1\nline2\n" );
    sysopen( my $fh, '/fake/rw_sysw_read', O_RDWR ) or die;

    syswrite( $fh, "LINE", 4 );
    is( tell($fh), 4, "tell after syswrite" );

    # Seek back to read everything
    sysseek( $fh, 0, 0 );
    my @lines = <$fh>;
    is( \@lines, ["LINE1\n", "line2\n"], "overwritten start visible via readline" );

    close $fh;
}

# ============================================================
# Append mode: tell always at end
# ============================================================

{
    note "--- append mode print always writes to end ---";

    my $mock = Test::MockFile->file( '/fake/append_print', "START" );
    open( my $fh, '>>', '/fake/append_print' ) or die;

    print $fh "A";
    is( tell($fh), 6, "tell is 6 (5 + 1) after append" );

    # Seek to start — in append, next write still goes to end
    seek( $fh, 0, SEEK_SET );
    print $fh "B";
    is( $mock->contents, "STARTAB", "print in append mode goes to end even after seek" );

    close $fh;
}

{
    note "--- append mode printf writes to end ---";

    my $mock = Test::MockFile->file( '/fake/append_printf', "X" );
    open( my $fh, '>>', '/fake/append_printf' ) or die;

    printf $fh "%d", 42;
    is( $mock->contents, "X42", "printf in append mode appends to end" );

    close $fh;
}

# ============================================================
# Multiple handles to same file
# ============================================================

{
    note "--- two read handles maintain independent tell positions ---";

    my $mock = Test::MockFile->file( '/fake/multi_read', "ABCDEF" );
    open( my $fh1, '<', '/fake/multi_read' ) or die;
    open( my $fh2, '<', '/fake/multi_read' ) or die;

    read( $fh1, my $buf1, 3 );
    is( $buf1, "ABC", "fh1 reads first 3 bytes" );
    is( tell($fh1), 3, "fh1 tell is 3" );

    read( $fh2, my $buf2, 2 );
    is( $buf2, "AB", "fh2 reads first 2 bytes (independent)" );
    is( tell($fh2), 2, "fh2 tell is 2" );

    # fh1 continues from its own position
    read( $fh1, $buf1, 2 );
    is( $buf1, "DE", "fh1 continues from position 3" );

    close $fh1;
    close $fh2;
}

{
    note "--- write through one handle visible via another ---";

    my $mock = Test::MockFile->file( '/fake/multi_write', "AAAA" );
    open( my $reader, '<',  '/fake/multi_write' ) or die;
    open( my $writer, '+<', '/fake/multi_write' ) or die;

    print $writer "XX";

    # Reader should see the updated contents
    seek( $reader, 0, SEEK_SET );
    read( $reader, my $buf, 4 );
    is( $buf, "XXAA", "reader sees writer's changes via shared contents" );

    close $reader;
    close $writer;
}

# ============================================================
# Cleanup check
# ============================================================

is( \%Test::MockFile::files_being_mocked, {}, "No mock files left in cache" );

done_testing();
exit;
