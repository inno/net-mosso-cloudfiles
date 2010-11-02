#!perl
use strict;
use warnings;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'WebService::CloudFiles',
    VERSION_FROM => 'lib/WebService/CloudFiles.pm',
    ABSTRACT     => 'Interface to any Swift CloudFiles service',
    AUTHOR       => 'Clif Bratcher <cpan@conta.minate.com>',
    PREREQ_PM    => {
        'Crypt::SSLeay'          => '0',
        'DateTime::Format::HTTP' => '0',
        'Digest::MD5'            => '0',
        'URI::QueryParam'        => '0',
        'JSON::XS'               => '0',
        'LWP'                    => '0',
        'LWP::ConnCache'         => '0',
        'LWP::UserAgent'         => '0',
        'Test::Exception'        => '0',
    }
);

