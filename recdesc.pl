#!/usr/bin/perl

use strict;
use warnings;

use Parse::RecDescent;
use Data::Dumper;

$::RD_TRACE = 1;

undef $Parse::RecDescent::skip;

my $grammar = <<'EOGRAMMAR';

{ 
    use Data::Dumper;
    my $indent = 0;
    my @begin_scope;
    my @entity_scope;
    my ($od, $cd);  #open/close delimiter
    my $delimiters = '[{<(';
}

document: 
    section(s)

section: 
    begin_para section(s) end_para
  | command_para
  | verbatim_para(s) { $indent = 0; $return = $item[1]; }
  | text_para

begin_para: 
    /^\+/ text BLANK_LINE
    { 
        my @stuff = split ' ', $item[2]; 
        push @begin_scope, \@stuff;
        1;
    }

end_para: 
    /^-/ WORD <reject: { (pop @begin_scope)->[0] ne $item[2] }>
  | <error: Unexpected -$item[2] on line $thisline>

command_para:
    /^=/ WORD(s) BLANK_LINE
    {
        +{
            type => 'command',
            command => shift @{$item[2]},
            arguments => join '', @{$item[2]},
        };
    }

verbatim_para:
    verbatim_line(s) (BLANK_LINE|EOF)
    {
        +{
            type => 'verbatim',
            text => join "", @{$item[1]},
        };
    }

# It is part of a verbatim paragraph if:
#   1 - It starts with the same indentation level as the previous line
#   2 - There is no indentation level, so we set one
#   3 - It is a blank line with a verbatim line after it
# This allows it to end at a blank line when said blank line is followed by a
# different paragraph type.

verbatim_line:
    "$indent" RAWTEXT
  | /[^\S\n]+/ RAWTEXT { $indent = $item[1]; $return = $item[2]; }
  | <reject: !$indent> BLANK_LINE ...verbatim_line { $return = $item[2] }

text_para:
    text(s) BLANK_LINE
    {
        +{
            type => 'text',
            text => join '', @{$item[1]},
        };
    }

entity_begin:
    LETTER OPENING_DELIMITER 
    { 
        push @entity_scope, $item[1];
        1;
    }

entity_end:
    CLOSING_DELIMITER
  | <error: could not find matching closing delimiter $item[1]>

entity:
    entity_begin text entity_end[$item[1]]
    {
        +{
            type => 'entity',
            entity => pop @entity_scope,
            text => join '', @{$item[2]},
        };
    }

text:
    entity
  | WORD(s) ...!entity { $return = join '', @{$item[1]} }

OPENING_DELIMITER:
    <reject: !$od> "$od" <commit> { $cd = $od; $cd =~ tr/{[<(/}]>)/ }
  | /([\Q$delimiters\E])\1*/ { $od = $item[1] }

CLOSING_DELIMITER:
    "$cd"

LETTER:
    /[[:alpha:]]/

WORD:
    /\S[^\Q$delimiters\E]+?\s?/ { ( $return = $item[1] ) =~ tr/\n/ /; }

RAWTEXT:
    /.+?\n/

BLANK_LINE:   # Since WORD consumes a \n, then if we start with \n we had \n\n!
    /^\n/
  | EOF

EOF:
    /\Z/

EOGRAMMAR

undef $/;
my $rd = Parse::RecDescent->new($grammar)->document(<>);

print Dumper $rd;
