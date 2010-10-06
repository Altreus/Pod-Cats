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

sub handle_entity {
    my $self = shift;
    
    my $entity = shift;
    my $content = shift;

    if ( $entity eq 'I' ) {
        is($content, 'simple', 'I entity contains "simple"' );
    }
    elsif ($entity eq 'C') {
        is( $content, 'Z<>', 'C entity contains Z<>' );
    }
    elsif ($entity eq 'Z') {
        fail('Z entity should not be passed off for user handling');
    }
    else {
        fail('this is not I<>!') and return unless shift eq 'I';
    }

    return $content;
}

1;

package main;

__DATA__
This paragraph contains a I<simple> entity.

This paragraph explains how C<<Z<>>> works.
