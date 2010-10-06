package Pod::Cats;

use warnings;
use strict;
use 5.010;

use Data::Dumper;
use Text::Balanced qw(extract_bracketed);
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

    # TODO: Currently this is being built piecemeal, which allows for mistakes
    # such as imbalanced tags. A better solution would be to build an object
    # model out of it, and process this depth-first, to make a consistent
    # output. this will still always rely on the user's begin/end handlers 
    # producing balanced tags but that's up to them.

    my $result = "";

    # The buffer type goes in the first element, and its
    # contents, if any, in the rest.
    my @buffer;

    # Special lines are:
    #  - a blank line except when in a verbatim paragraph. Process the buffer
    #    and start a new one.
    #  - A line starting with =, + or -. Command paragraph. Process the previous
    #    buffer and start a new one with this.
    #  - Anything else continues the previous buffer, or starts a normal paragraph

    shift @lines while $lines[0] !~ /\S/; # shift off leading blank lines!

    for my $line (@lines) {
        if ($line =~ /^\s*$/ && @buffer) {
            if ($buffer[0] eq 'verbatim') {
                push @buffer, $line;
            }
            else {
                $result .= $self->_process_buffer(@buffer);
                @buffer = ();
            }
        }
        elsif (my ($type) = $line =~ /^([=+-])/) {
            if (@buffer) {
                warn "$type command found without leading blank line.";

                $result .= $self->_process_buffer(@buffer);
                @buffer = ();
            }

            push @buffer, {
                '+' => 'begin',
                '-' => 'end',
                '=' => 'tag',
            }->{$type} or die "Don't know what to do with $type";

            push @buffer, grep {$_} ($line =~ /^\Q$type\E(.+?)\b\s*(.*)$/);
        }
        elsif ($line =~ /^\s+\S/){
            # TODO: Check leading whitespace is at least the length of the prev.
            push @buffer, "verbatim" if !@buffer;
            push @buffer, $line;
        }
        else {
            # Nothing special, continue previous buffer or start a paragraph.
            push @buffer, "paragraph" if !@buffer;
            push @buffer, $line;
        }
    }

    $result .= $self->_process_buffer(@buffer) if @buffer;

    return $result;
}

# The workhorse, except it's really just a dispatcher.
sub _process_buffer {
    my ($self, @buffer) = @_;

    return '' unless @buffer;

    my $buffer_type = shift @buffer;
    my $result;

    return {
        paragraph => sub {
            my $para = join " ", @buffer;
            $para =~ s/\s{2,}/ /g;
            $self->_handle_paragraph($para);
        },
        verbatim => sub {
            $self->_handle_verbatim(join "\n", @buffer);
        },
        tag      => sub {
            $self->_handle_tag(shift @buffer, join " ", @buffer);
        },
        end      => sub {
            $self->_handle_end(shift @buffer, join " ", @buffer);
        },
        begin    => sub {
            $self->_handle_begin(shift @buffer, join " ", @buffer);
        }
    }->{$buffer_type}->();
}

sub _handle_verbatim {
    my ($self, @buffer) = @_;

    my ($indentation) = $buffer[0] =~ /^(\s+)/;

    for (@buffer) {
        s/^$indentation//;
    }

    return $self->handle_verbatim(@buffer);
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
sub _handle_paragraph {
    my ($self, $para) = @_;

    # 1. replace POD-like Z<...> with user-defined functions.
    # Z itself is the only actual exception to that.
    my ($match, $remainder, $prefix) 
        = extract_bracketed($para, "<>", qr/^[^<>]+/);

    while ($match) {
        my ($open) = $match =~ /^(<+)/;
        my $close = ">" x length $open;

        $match =~ s/$open//; $match =~ s/$close//;
        $prefix =~ s/(.)$//; my $letter = $1;     

        if ($letter eq 'Z') {
            warn "Z<> should not contain any text" if $match;
            $match = "";
            next;
        }

        # $match is now just the content of the element.
        $match = $self->handle_entity($letter, $match);

        $para = join "", $prefix, $match, $remainder;

        ($match, $remainder, $prefix) 
            = extract_bracketed($para, "<>", qr/^[^<>]+/);
    }

    return $self->handle_paragraph($para);
}

=head2 handle_paragraph

You get a paragraph, which has had its C<< X<> >> entities handled already.
Do what you wish, and then return it. It is all on one line.

=cut

sub handle_paragraph {
    my $self = shift;
    return shift;
}

=head2 handle_tag

For each tag (C<=foo>) encountered, it is passed to C<handle_tag> along with the
content of the tag with its whitespace collapsed. Do with it as you will.

=cut

sub _handle_tag {
    my ($self, $tag, $content) = @_;

    $content =~ s/\s+/ /g;

    return $self->handle_tag($tag, $content);
}

=head2 handle_begin

When a begin command (C<+foo>) is encountered, it is passed to this function for
processing. The first argument (after C<$self>) will be the tag name ("foo");
the second will be the content of the command with the whitespace collapsed.

=cut

sub _handle_begin {
    my ($self, $tag, $content) = @_;

    $self->{begin_stack} ||= [];

    # Do this whether or not it is handled, so we can check for balance.
    push @{$self->{begin_stack}}, $tag;

    return $self->handle_begin($tag, $content);
}

=head2 handle_end

The counterpart to the begin handler. This handles your C<-foo> commands. Note
that if you close a tag that is not opened, or is simply out of order, you will 
receive a warning and the command will be ignored. The handler is passed the tag
name; end tags accept no content.

=cut

sub _handle_end {
    my ($self, $tag, $content) = @_;

    # Do this whether or not it is handled, so we can check for balance.
    warn "$tag is ended out of sync!" if pop @{$self->{begin_stack}} ne $tag;

    return $self->handle_end($tag, $content);
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
