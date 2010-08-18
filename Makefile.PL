use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Podcats::Markup',
    AUTHOR              => q{Altreus <altreus@perl.org>},
    VERSION_FROM        => 'lib/Podcats/Markup.pm',
    ABSTRACT_FROM       => 'lib/Podcats/Markup.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Podcats-Markup-*' },
);
