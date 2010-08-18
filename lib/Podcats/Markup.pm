package Podcats::Markup;

use warnings;
use strict;

=head1 NAME

Podcats::Markup - The POD-like markup language written for podcats.in

=head1 VERSION

Version 0.01

=head1 DESCRIPTION

There's a sad lack of decent markup languages. Those that give you the power
to do arbitrary or strange things also are so bloated or complex that you might
as well just write out your HTML and parse that. Those that make simple things
simple also fail to include the power to do complicated things.

POD uses commands to insert semantic sections, and syntax to do common tasks
easily.

Podcats::Markup is designed to be extended and doesn't implement any default
commands.

=head1 SYNTAX

Podcats::Markup syntax borrows ideas from POD and adds its own.

=over
    
=item C<=COMMAND>

A line beginning with the C<=> symbol denotes a single command. Usually this
will be some sort of header, perhaps the equivalent of a C<< <hr> >>, something
like that. In essence, it is a single tag rather than a block.

=item C<+COMMAND>

A line beginning with C<+> is the start of a named block. The C<COMMAND> is
arbitrary and is handled by the method C<begin_COMMAND> in your subclass.

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

=cut

our $VERSION = '0.01';

=head1 AUTHOR

Altreus, C<< <altreus at perl.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-podcats-markup at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Podcats-Markup>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Podcats::Markup


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Podcats-Markup>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Podcats-Markup>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Podcats-Markup>

=item * Search CPAN

L<http://search.cpan.org/dist/Podcats-Markup/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Altreus.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Podcats::Markup
