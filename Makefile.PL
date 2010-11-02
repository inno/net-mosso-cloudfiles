#!perl
use strict;
use warnings;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'Net::Mosso::CloudFiles',
    VERSION_FROM => 'lib/Net/Mosso/CloudFiles.pm',
    ABSTRACT     => 'Interface to Swift CloudFiles service',
    AUTHOR       => 'Leon Brocard <acme@astray.com>',
    LICENSE      => 'perl',
    PREREQ_PM    => {
        'Crypt::SSLeay'                        => '0',
        'DateTime::Format::HTTP'               => '0',
        'Digest::MD5'                          => '0',
        'URI::QueryParam'                      => '0',
        'LWP'                                  => '0',
        'LWP::ConnCache'                       => '0',
        'LWP::UserAgent'                       => '0',
        'Test::Exception'                      => '0',
    }
);

