#!perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use File::Temp;

use Test::MockFile qw< nostrict >;

my $dir = File::Temp->newdir;

my $log_file = "$dir/file.log";

open( my $fh, '>', $log_file );
print {$fh} "...";
close $fh;

my @logs = glob "$dir/*.log";
is \@logs, [$log_file];

done_testing;
