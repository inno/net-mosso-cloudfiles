package WebService::CloudFiles::Container;

use strict;
use warnings;
use Carp;
use URI;
use HTTP::Request;
use JSON::XS;

sub cloudfiles {$_[0]->{'cloudfiles'}}
sub name {$_[0]->{'name'}}

sub new {
    my $class = shift;
    my %args  = @_;

    # XXX Should really limit what we're allowing here
    my $self = \%args;
    bless $self, $class;
    return $self;
}

sub _url {
    my ( $self, $name ) = @_;
    my $url = $self->cloudfiles->storage_url . '/' . $self->name;
    utf8::downgrade($url);
    return $url;
}

sub object_count {
    my $self    = shift;
    my $request = HTTP::Request->new( 'HEAD', $self->_url,
        [ 'X-Auth-Token' => $self->cloudfiles->token ] );
    my $response = $self->cloudfiles->_request($request);
    confess 'Unknown error' if $response->code != 204;
    return $response->header('X-Container-Object-Count');
}

sub bytes_used {
    my $self    = shift;
    my $request = HTTP::Request->new( 'HEAD', $self->_url,
        [ 'X-Auth-Token' => $self->cloudfiles->token ] );
    my $response = $self->cloudfiles->_request($request);
    confess 'Unknown error' if $response->code != 204;
    return $response->header('X-Container-Bytes-Used');
}

sub delete {
    my $self    = shift;
    my $request = HTTP::Request->new( 'DELETE', $self->_url,
        [ 'X-Auth-Token' => $self->cloudfiles->token ] );
    my $response = $self->cloudfiles->_request($request);
    confess 'Not empty' if $response->code == 409;
    confess 'Unknown error' if $response->code != 204;
}

sub objects {
    my ( $self, %args ) = @_;

    my $url = URI->new( $self->_url );
    $url->query_param('format' => 'json');
    $url->query_param('prefix' => $args{'prefix'}) if defined $args{'prefix'};
    $url->query_param('path' => $args{'path'}) if defined $args{'path'};

    my $request = HTTP::Request->new( 'GET', $url,
        [ 'X-Auth-Token' => $self->cloudfiles->token ] );
    my $response = $self->cloudfiles->_request($request);
    return 0 if $response->code == 204;
    confess 'Unknown error' if $response->code != 200;
    return undef unless $response->content;

    my @bits = ();
    my @objects = ();

    if ($JSON::XS::VERSION < 2) {
        @bits = @{ from_json($response->content()) };
    }
    else {
        @bits = @{ decode_json($response->content()) };
    }

    foreach my $bit (@bits) {
        push @objects, WebService::CloudFiles::Object->new(
                cloudfiles    => $self->cloudfiles,
                container     => $self,
                name          => $bit->{name},
                etag          => $bit->{hash},
                size          => $bit->{bytes},
                content_type  => $bit->{content_type},
                last_modified => $bit->{last_modified},
            );
    }
    return @objects;
}

sub object {
    my ( $self, %conf ) = @_;
    confess 'Missing name' unless $conf{name};
    return WebService::CloudFiles::Object->new(
        cloudfiles => $self->cloudfiles,
        container  => $self,
        %conf,
    );
}

1;

__END__

=head1 NAME

WebService::CloudFiles::Container - Represent a Cloud Files container

=head1 DESCRIPTION

This class represents a container in Cloud Files. It is created by
calling new_container or container on a L<WebService::CloudFiles> object.

=head1 METHODS

=head2 name

Returns the name of the container:

  say 'have container ' . $container->name;

=head2 object_count

Returns the total number of objects in the container:

  my $object_count = $container->object_count;

=head2 bytes_used

Returns the total number of bytes used by objects in the container:

  my $bytes_used = $container->bytes_used;

=head2 objects

Returns a list of objects in the container as
L<WebService::CloudFiles::Object> objects. As the API only returns
ten thousand objects per request, this module may have to do multiple
requests to fetch all the objects in the container. This is exposed
by using a L<Data::Stream::Bulk> object. You can also pass in a
prefix:

  foreach my $object ($container->objects->all) {
    ...
  }

  my @objects = $container->objects(prefix => 'dir/')->all;

=head2 object

This returns a <WebService::CloudFiles::Object> representing
an object.

  my $xxx = $container->object( name => 'XXX' );
  my $yyy = $container->object( name => 'YYY', content_type => 'text/plain' );

=head2 delete

Deletes the container, which should be empty:

  $container->delete;

=head1 SEE ALSO

L<WebService::CloudFiles>, L<WebService::CloudFiles::Object>.

=head1 AUTHOR

Leon Brocard <acme@astray.com>.

=head1 COPYRIGHT

Copyright (C) 2008-9, Leon Brocard

=head1 LICENSE

This module is free software; you can redistribute it or modify it
under the same terms as Perl itself.
