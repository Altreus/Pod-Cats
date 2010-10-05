#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Pod::Cats' ) || print "Bail out!
";
}

diag( "Testing Pod::Cats $Podcats::Markup::VERSION, Perl $], $^X" );
