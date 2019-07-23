#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Errno qw/ENOENT EISDIR EPERM/;

use File::Temp qw/tempfile tempdir/;

use Test::MockFile;

my $file = '/tmp/file';

my $mocked_file  = Test::MockFile->file( $file, "something" );
#qx{touch $file}; qx{chmod 0666 $file};

#umask 0177;

ok -f $file, "file exists";

my $perms = ( stat( $file ) ) [2] & 0777;

is $perms, 0644, 'perms set to 420';

chmod( 0755, $file );

note "perms: ", 0755;

$perms = ( stat( $file ) ) [2] & 0777;
is $perms, 0755, 'perms changed to 755';

done_testing;