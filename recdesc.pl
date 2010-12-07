#!/usr/bin/perl

use strict;
use warnings;

use Parse::RecDescent;
use Data::Dumper;

$::RD_TRACE = 1;
$::RD_HINT = 1;
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
    begin_para section(s) end_para { $return = $item[1] }
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
    OPENING_DELIMITER 
    { 
        my $letter = substr $item[1], 0, 1, '';

        push @entity_scope, $letter;
        $item[1];
        1;
    }

entity_end:
    <reject: !$cd> <commit>
  | CLOSING_DELIMITER
  | <error: could not find matching closing delimiter $item[1]>

entity:
    entity_begin text entity_end
    {
        $return = {
            type => 'entity',
            entity => pop @entity_scope,
            text => join '', @{$item[2]},
        };
    }

# So text either starts with an entity, is everything up to the current closing
# delimiter, or is everything up to the next entity
text: <rulevar: local $stop_greedy_words>
  | entity
  | WORD(s) { $return = join '', @{$item[1]} }

OPENING_DELIMITER:
    <reject: !$od> "$od" <commit> { $return = $item[1]; }
  | /\S([\[{(<])\1*/ { $return = $cd = $od = $item[1]; $cd =~ tr/{[<(/}]>)/; }

CLOSING_DELIMITER:
    "$cd"

LETTER:
    /[[:alpha:]]/

# consume everthing up to the start of the next word, or a newline. If the
# closing delimiter is found in our word, don't consume it.
WORD:
    <reject:$stop_greedy_words>
    /(\S+\s?)/ {
        $return = $1;
        $return =~ s/\n/ /;
        if ($cd && (my $idx = index $return, $cd) > -1) {
            $return = substr $return, 0, $idx;
            $stop_greedy_words = 1;
        }
        1;
    }

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
