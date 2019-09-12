use strict;
use utf8;
use warnings;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
    NAME           => 'Bot::BasicBot::Pluggable::Module::NollNioNoll',
    AUTHOR         => 'Simon Sawert <simon@sawert.se>',
    LICENSE        => 'MIT',
    ABSTRACT_FROM  => 'lib/Bot/BasicBot/Pluggable/Module/NollNioNoll.pm',
    VERSION_FROM   => 'lib/Bot/BasicBot/Pluggable/Module/NollNioNoll.pm',
    EXE_FILES      => [qw( noll9noll.example )],
    BUILD_REQUIRES => {},
    TEST_REQUIRES  => {},
    PREREQ_PM      => {
        'Bot::BasicBot::Pluggable::Module' => '>=1.20',
        'DateTime::Format::Strptime'       => '>=1.76',
        'JSON'                             => '>=4.02',
        'Mojo::UserAgent'                  => 0,
        'Net::Twitter'                     => '>=4.01043',
        'YAML::XS'                         => 0,
    },
    META_MERGE => {
        'dynamic_config' => 0,
        'meta-spec'      => { version => 2 },
        'resources'      => {
            bugtracker => { web => 'https://github.com/bombsimon/noll-9-noll/issues' },
            homepage   => 'https://github.com/bombsimon/noll-9-noll',
            repository => {
                type => 'git',
                url  => 'https://github.com/bombsimon/noll-9-noll.git',
                web  => 'https://github.com/bombsimon/noll-9-noll',
            },
        },
        'x_contributors' => ['Simon Sawert'],
    },
    test => {},
);

WriteMakefile( %WriteMakefileArgs );
