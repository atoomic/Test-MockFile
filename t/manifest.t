#!perl
use 5.016;
use strict;
use warnings;
use Test::More;

unless ( $ENV{RELEASE_TESTING} ) {
    plan( skip_all => "Author tests not required for installation" );
}

# Use ExtUtils::Manifest (core module) instead of the broken Test::CheckManifest.
# This catches files listed in MANIFEST that don't exist on disk (manicheck)
# and files on disk that aren't listed in MANIFEST (filecheck).

use ExtUtils::Manifest qw( manicheck filecheck );

my @missing = manicheck();
is( scalar @missing, 0, "All files in MANIFEST exist on disk" )
  or diag( "Missing from disk: $_" ) for @missing;

my @extra = filecheck();
is( scalar @extra, 0, "No extra files found outside MANIFEST" )
  or diag( "Not in MANIFEST: $_" ) for @extra;

done_testing();
