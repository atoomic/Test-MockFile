#!/usr/bin/perl

# Test that glob falls through to real filesystem when no files are mocked
# Regression test for GH #158: Test::MockFile corrupts glob

use strict;
use warnings;

use Test::More;
use File::Temp;

use Test::MockFile qw(nostrict);

subtest 'glob returns real filesystem results when nothing is mocked' => sub {
    my $dir = File::Temp->newdir();

    my $log_file = "$dir/file.log";

    open( my $fh, '>', $log_file ) or die "Cannot create $log_file: $!";
    print $fh "test content";
    close $fh;

    my @logs = glob("$dir/*.log");
    is_deeply( \@logs, [$log_file], "glob returns real file when T::MF loaded but unused" );
};

subtest 'glob returns real files alongside mocked files' => sub {
    my $dir = File::Temp->newdir();

    # Create a real file
    my $real_file = "$dir/real.txt";
    open( my $fh, '>', $real_file ) or die "Cannot create $real_file: $!";
    print $fh "real";
    close $fh;

    # Create a mocked file in the same directory
    my $mock_file = "$dir/mocked.txt";
    my $mock = Test::MockFile->file( $mock_file, "mocked content" );

    my @files = sort glob("$dir/*.txt");
    is_deeply( \@files, [ sort( $mock_file, $real_file ) ],
        "glob returns both real and mocked files" );
};

subtest 'mocked non-existent file hides real file from glob' => sub {
    my $dir = File::Temp->newdir();

    # Create a real file
    my $real_file = "$dir/hidden.txt";
    open( my $fh, '>', $real_file ) or die "Cannot create $real_file: $!";
    print $fh "should be hidden";
    close $fh;

    # Mock the same path as non-existent (undef contents)
    my $mock = Test::MockFile->file( $real_file, undef );

    my @files = glob("$dir/*.txt");
    is_deeply( \@files, [], "real file hidden when mocked as non-existent" );
};

subtest 'glob with angle brackets works on real files' => sub {
    my $dir = File::Temp->newdir();

    my $file = "$dir/data.csv";
    open( my $fh, '>', $file ) or die "Cannot create $file: $!";
    print $fh "a,b,c";
    close $fh;

    my @files = <$dir/*.csv>;
    is_deeply( \@files, [$file], "angle bracket glob returns real file" );
};

done_testing();
