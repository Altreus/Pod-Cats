#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Podcats::Markup' ) || print "Bail out!
";
}

diag( "Testing Podcats::Markup $Podcats::Markup::VERSION, Perl $], $^X" );
