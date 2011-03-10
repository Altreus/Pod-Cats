package Pod::Cats;

use warnings;
use strict;
use 5.010;

use Data::Dumper;
use Parser::MGC;
use List::Utils qw(min);
use Carp;

=head1 NAME

Pod::Cats - The POD-like markup language written for podcats.ign

=head1 VERSION

Version 0.01

=head1 DESCRIPTION

There's a sad lack of decent markup languages. Those that give you the power
to do arbitrary or strange things also are so bloated or complex that you might
as well just write out your HTML and parse that. Those that make simple things
simple also fail to include the power to do complicated things.

POD uses commands to insert semantic sections, and syntax to do common tasks
easily.

Pod::Cats is designed to be extended and doesn't implement any default
commands.

=head1 SYNTAX

Pod::Cats syntax borrows ideas from POD and adds its own.

=over
    
=item C<=COMMAND CONTENT>

A line beginning with the C<=> symbol denotes a single command. Usually this
will be some sort of header, perhaps the equivalent of a C<< <hr> >>, something
like that. In essence, it is a single tag rather than a block. The function of
C<CONTENT> is up to you.

=item C<+COMMAND CONTENT>

A line beginning with C<+> is the start of a named block. The C<COMMAND> is
arbitrary and is handled by the method C<begin_COMMAND> in your subclass.

What you do with C<CONTENT> is up to you.

This command is not considered complete until a blank line is encountered. This
is to allow you to extend a lot of C<CONTENT> across multiple lines.

=item C<-COMMAND>

A line beginning with C<-> is the end of the named block previously started.

=item C<< X<> >>

As with POD, you can create inline formatting codes using the C<< X<> >> syntax,
except in this, the X is any arbitrary letter and you define it yourself. Also
as with POD, you can use any number of C<< <> >> characters as a form of
escaping text that itself contains them.

The only exception to the X being arbitrary is C<< Z<> >>, which has the same
functionality as in POD, i.e. is a non-printing, empty character used entirely
as a separator to divide ambiguous syntax.

=item Paragraphs

Any solid block of text is considered to be a single paragraph. Newlines are
ignored, except where there is a blank line. A blank line separates paragraphs.

In paragraphs, multiple whitespace is I<collapsed> before it gets to you. This
simply means that your entire paragraph is consistenly spaced. Run a subs. on it
if you want to alter the whitespace again but since this is primarily designed 
for web use it's largely irrelevant.

This includes newlines. Lines are joined into one long one.

=item Verbatim paragraphs

Lines beginning with a blank line are considered to be verbatim paragraphs.
Unlike many POD parsers, the correct behaviour of this format is to remove the
leading whitespace once the entire paragraph has been collected.

Due to the expected purpose of verbatim paragraphs (code, usually), blank lines
will not separate them, but will instead be part of the long paragraph. A
verbatim paragraph is not considered to have ended until a C<=> or C<+> command
or a normal paragraph is encountered.

A useful trick to note is that you can separate verbatim paragraphs by putting
a C<< Z<> >> on its own on a line with I<no> whitespace, basically in order to
create an empty normal paragraph between the two verbatim paragraphs.

=back

=head1 METHODS

=cut

our $VERSION = '0.01';

=head2 new

Create a new parser. Currently, no options.

=cut

sub new {
    my $class = shift;
    my $opts = shift || {};
    my $self = bless $opts, $class; # FIXME

    return $self;
}

=head2 parse

Parses a string containing whatever Pod::Cats code you have.

=cut

sub parse {
    my ($self, $string) = @_;

    return $self->parse_lines(split /\n/, $string);
}

=head2 parse_file 

Opens the file given by filename and reads it all in and then parses that.

=cut

sub parse_file {
    my ($self, $filename) = @_;
    
    carp "File not found: " . $filename unless -e $filename;

    open my $fh, "<", $filename;
    chomp(my @lines = <$fh>);
    close $fh;

    return $self->parse_lines(@lines);
}

=head2 parse_lines

L<parse> and L<parse_file> both come here, which just takes the markup text
as an array of lines and parses them. So it just takes the result of a
slurp or a split /\n/ and parses it. This is where the logic happens.

=cut

sub parse_lines {
    my ($self, @lines) = @_;

    my $result = "";

    # The buffer type goes in the first element, and its
    # contents, if any, in the rest.
    my @buffer;
    $self->{dom} = [];

    # Special lines are:
    #  - a blank line. An exception is between verbatim paragraphs, so we will
    #    simply re-merge verbatim paras later on
    #  - A line starting with =, + or -. Command paragraph. Process the previous
    #    buffer and start a new one with this.
    #  - Anything else continues the previous buffer, or starts a normal paragraph

    shift @lines while $lines[0] !~ /\S/; # shift off leading blank lines!

    for my $line (@lines) {
        given ($line) {
            when (/^\s*$/) {
                $self->_process_buffer(@buffer);
                @buffer = ();
            }
            when (/^([=+-])/) {
                my $type = $1;
                if (@buffer) {
                    warn "$type command found without leading blank line.";

                    $self->_process_buffer(@buffer);
                    @buffer = ();
                }

                push @buffer, {
                    '+' => 'begin',
                    '-' => 'end',
                    '=' => 'tag',
                }->{$type} or die "Don't know what to do with $type";

                # find and push the command name onto it; the rest is the first
                # bit of buffer contents.
                push @buffer, grep {$_} ($line =~ /^\Q$type\E(.+?)\b\s*(.*)$/);
            }
            when (/^\s+\S/) {
                push @buffer, "verbatim" if !@buffer;
                push @buffer, $line;
            }
            default {
                # Nothing special, continue previous buffer or start a paragraph.
                push @buffer, "paragraph" if !@buffer;
                push @buffer, $line;
            }
        }
    }

    $self->_process_buffer(@buffer) if @buffer;
    $self->_postprocess_dom();

    $self->_postprocess_paragraphs();
    return $self->{dom};
}

# Adds the buffer and some metadata to the DOM, returning nothing.
sub _process_buffer {
    my ($self, @buffer) = @_;

    return '' unless @buffer;

    my $buffer_type = shift @buffer;
    
    my $node = {
        type => $buffer_type;
    };

    given ($buffer_type) {
        when('paragraph') {
            # concatenate the lines and normalise whitespace.
            my $para = join " ", @buffer;
            $para =~ s/(\s){2,}/$1/g;
            $node->{content} = $para;
        }
        when('verbatim') {
            # find the lowest level of indentation in this buffer and strip it
            my $indent_level = min { /^(\s+)/; length $1 } @buffer;
            s/^\s{$indent_level}// for @buffer;
            $node->{content} = join "\n", @buffer;
            $node->{indent_level} = $indent_level;
        }
        when('tag' || 'begin') {
            $node->{name} = shift @buffer;
            my $content = join " ", @buffer;
            $content =~ s/(\s){2,}/$1/g;
            $node->{content} = $content;
        }
        when('end') {
            $node->{name} = shift @buffer; # end tags take no content
        }
    }

    push @{$self->{dom}}, $node;
}

# This is basically just to merge verbatims together
sub _postprocess_dom {
    my $self = shift;

    my @new_dom;
    my $last_node;
    for my $node (@{$self->{dom}}) {
        $last_node = $node and next unless defined $last_node;

        # Don't change the last node until we stop finding verbatims.
        # That way we can keep using it as the concatenated node.
        if ($last_node->{type} eq 'verbatim' && $node->{type} eq 'verbatim') {
            my $to_remove = 
                max( $last_node->{indent_level}, $node->{indent_level})
              - min( $last_node->{indent_level}, $node->{indent_level});
            $last_node->{content} .= "\n" . $node->{content};

            # If the min indent has gone down, raze more spaces off.
            $last_node->{content} =~ s/^\s{$to_remove}//mg if $to_remove;
        } else {
            # Node type changed, push old one
            push @new_dom, $last_node;
            $last_node = $node;
        }
    }

    push @new_dom, $last_node;
}

# Now is the sax-like bit, where it goes through and fires the user's events for
# the various types.
sub _postprocess_paragraphs {
    my $self = shift;

    for my $node ($self->{dom}) {
        given ($node->{type}) {
            when ('paragraph') {
                $node->{content} = $self->_process_entities($node->{content});
                $self->handle_paragraph($node->{content});
            }
            when ('begin') {
                $node->{content} = $self->_process_entities($node->{content});
                # Check for balance later
                push @{$self->{begin_stack}}, $node->{name};

                $self->handle_begin($node->{name}, $node->{content});
            }
            when ('end') {
                warn "$node->{name} is ended out of sync!" 
                    if pop @{$self->{begin_stack}} ne $node->{name}

                $self->handle_end($node->{name});
            }
            when ('command') {
                $node->{content} = $self->_process_entities($node->{content});
                $self->handle_command($node->{name}, $node->{content});
            }
            when ('verbatim') {
                $self->handle_verbatim($node->{content});
            }
        }
    }
}

=head2 handle_verbatim

You are given the verbatim paragraph as an array. It has had the leading 
whitespace removed already. It's not joined into one string yet because you 
will probably want to know the separate lines.

=cut

sub handle_verbatim {
    shift;
    return @_;
}

=head2 handle_entity

For any entity (C<< Z<> >>) encountered, its letter is provided to the
handle_entity method, along with the contents inside it.

Entites are recognised by their C<< < > >>. As long as they balance, you can use
any number of them to surround the content of the entity. This allows you to use
these characters themselves in the content.

The C<< Z<> >> entity is special. This is not passed off to this handler. The
C<< Z<> >> entity allows you to do something like C<< CZ<><> >> in order to
"escape" the entity from being recognised. In short, it does nothing except be
there in the source.

=cut

# preprocess paragraph before giving it to the user.
sub _process_entities {
    my ($self, $para) = @_;

    # 1. replace POD-like Z<...> with user-defined functions.
    # Z itself is the only actual exception to that.
    $self->{parser} ||= Pod::Cats::Parser::MGC->new();


    return $self->handle_paragraph($para);
}

=head2 handle_paragraph

You get a paragraph, which has had its C<< X<> >> entities handled already.
Do what you wish, and then return it. It is all on one line.

=cut

sub handle_paragraph {
    shift; shift;
}

=head2 handle_tag

For each tag (C<=foo>) encountered, it is passed to C<handle_tag> along with the
content of the tag with its whitespace collapsed. Do with it as you will.

=cut

sub handle_tag {
    shift; shift;
}

=head2 handle_begin

When a begin command (C<+foo>) is encountered, it is passed to this function for
processing. The first argument (after C<$self>) will be the tag name ("foo");
the second will be the content of the command with the whitespace collapsed.

=cut

sub _handle_begin {
    shift; shift; shift;
}

=head2 handle_end

The counterpart to the begin handler. This handles your C<-foo> commands. Note
that if you close a tag that is not opened, or is simply out of order, you will 
receive a warning and the command will be ignored. The handler is passed the tag
name; end tags accept no content.

=cut

sub handle_end {
    shift; shift; shift;
}

=head1 TODO

The only difference between this and POD is that it doesn't have the C<=cut> tag
to allow it to be inserted into other files. That's because I've developed it as
a markup language for articles rather than documentation. Shouldn't be hard to 
implement this, however, so I will get around to it.

I would rather do this in a nested way, since it has nestable commands.
Currently the matching of begin/end commands is a bit naive.

Line numbers of errors are not yet reported.

=head1 AUTHOR

Altreus, C<< <altreus at perl.org> >>

=head1 BUGS

Bug reports to github please: http://github.com/Altreus/Pod-Cats/issues

=head1 SUPPORT

You are reading the only documentation for this module.

For more help, give me a holler on irc.freenode.com #perl

=head1 ACKNOWLEDGEMENTS

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Altreus.

This module is released under the MIT licence.

=cut

1;
