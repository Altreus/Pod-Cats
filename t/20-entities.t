#!/usr/bin/perl

use strict;
use warnings;

my $pc = Pod::Cats::Test->new();
chomp(my @lines = <DATA>);
$pc->parse_lines(@lines);

package Pod::Cats::Test;

use Data::Dumper;
use Test::More 'no_plan';

use parent 'Pod::Cats';

sub handle_I_entity {
    my $self = shift;
    my $content = shift;
    is($content, 'simple', 'I entity contains "simple"' );

    return $content;
}

sub handle_C_entity {
    my $self = shift;
    my $content = shift;
    
    is( $content, 'Z<>', 'C entity contains Z<>' );
}

sub handle_Z_entity {
    fail('Z entity should not be passed off for user handling');
}

1;

package main;

__DATA__
This paragraph contains a I<simple> entity.

This paragraph explains how C<<Z<>>> works.
