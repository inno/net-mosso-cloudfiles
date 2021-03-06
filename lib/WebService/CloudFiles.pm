package WebService::CloudFiles;

use strict;
use warnings;
use Carp;
use HTTP::Request;
use LWP::UserAgent;
use LWP::ConnCache;
use URI::QueryParam;
use WebService::CloudFiles::Container;
use WebService::CloudFiles::Object;
our $VERSION = '0.44';

my $DEBUG = 0;

sub user {$_[0]->{'user'}}
sub key {$_[0]->{'key'}}
sub timeout {$_[0]->{'timeout'} || 30}

sub ua {
    my $self = shift;
    my $data = shift;
    $self->{'ua'} = $data if $data;
    return $self->{'ua'};
}

sub storage_url {
    my $self = shift;
    my $data = shift;
    $self->{'storage_url'} = $data if $data;
    return $self->{'storage_url'};
}

sub token {
    my $self = shift;
    my $data = shift;
    $self->{'token'} = $data if $data;
    return $self->{'token'};
}


sub new {
    my $class = shift;
    my %args  = @_;

    my $self = bless {}, $class;

    $self->{'url'} = $args{'url'} or die 'url argument is required';
    $self->{'user'} = $args{'user'} or die 'user argument is required';
    $self->{'key'} = $args{'key'} if defined $args{'key'};
    $self->{'pass'} = $args{'pass'} if defined $args{'pass'};
    $self->{'timeout'} = $args{'timeout'} if defined $args{'timeout'};

    if (not defined $self->{'key'} and not defined $self->{'pass'}) {
        die "A key or pass argument is required!";
    }

    my $ua   = LWP::UserAgent->new(
        keep_alive            => 10,
        requests_redirectable => [qw(GET HEAD DELETE PUT)],
    );
    $ua->conn_cache(
        LWP::ConnCache->new(
            total_capacity => 10,
        )
    );
#    my $http_codes_hr = $ua->codes_to_determinate();
#    $http_codes_hr->{422} = 1; # used by cloudfiles for upload data corruption
    $ua->timeout( $self->timeout );
    $ua->env_proxy;
    $self->ua($ua);

    $self->_authenticate;

    return $self;
}

sub _authenticate {
    my $self = shift;

    my $request = HTTP::Request->new('GET' => $self->{'url'});

    if (defined $self->{'key'}) {
        $request->header('X-Auth-User' => $self->{'user'});
        $request->header('X-Auth-Key'  => $self->{'key'});
    }
    else {
        $request->header('X-Storage-User' => $self->{'user'});
        $request->header('X-Storage-Pass' => $self->{'pass'});
    }

    my $response = $self->_request($request);

    confess 'Unauthorized'  if $response->code == 401;
    confess "Unknown response: ".$response->code if $response->code != 204;

    my $storage_url = $response->header('X-Storage-Url')
        || confess 'Missing storage url';
    my $token = $response->header('X-Auth-Token')
        || confess 'Missing auth token';

    $self->storage_url($storage_url);
    $self->token($token);
}

sub _request {
    my ( $self, $request, $filename ) = @_;
    warn $request->as_string if $DEBUG;
    my $response = $self->ua->request( $request, $filename );
    warn $response->as_string if $DEBUG;
    if ( $response->code == 401 && $request->header('X-Auth-Token') ) {

        # http://trac.cyberduck.ch/ticket/2876
        # Be warned that the token will expire over time (possibly as short
        # as an hour). The application should trap a 401 (Unauthorized)
        # response on a given request (to either storage or cdn system)
        # and then re-authenticate to obtain an updated token.
        $self->_authenticate;
        $request->header( 'X-Auth-Token', $self->token );
        warn $request->as_string if $DEBUG;
        $response = $self->ua->request( $request, $filename );
        warn $response->as_string if $DEBUG;
    }
    return $response;
}

sub containers {
    my $self    = shift;
    my $request = HTTP::Request->new( 'GET', $self->storage_url,
        [ 'X-Auth-Token' => $self->token ] );
    my $response = $self->_request($request);
    return if $response->code == 204;
    confess 'Unknown error' if $response->code != 200;
    my @containers;

    foreach my $name ( split "\n", $response->content ) {
        push @containers,
            WebService::CloudFiles::Container->new(
            cloudfiles => $self,
            name       => $name,
            );
    }
    return @containers;
}

# Not sure why this isn't returning anything in Swift
sub total_bytes_used {
    my $self    = shift;
    my $request = HTTP::Request->new( 'HEAD', $self->storage_url,
        [ 'X-Auth-Token' => $self->token ] );
    my $response = $self->_request($request);
    confess 'Unknown error' if $response->code != 204;
    my $total_bytes_used = $response->header('X-Account-Bytes-Used');
    $total_bytes_used = 0 if $total_bytes_used eq 'None';
    return $total_bytes_used;
}

sub container {
    my ( $self, %conf ) = @_;
    my $name = $conf{name};
    confess 'Missing name' unless $name;

    return WebService::CloudFiles::Container->new(
        cloudfiles => $self,
        name       => $name,
    );
}

sub create_container {
    my ( $self, %conf ) = @_;
    my $name = $conf{name};
    confess 'Missing name' unless $name;

    my $request = HTTP::Request->new(
        'PUT',
        $self->storage_url . '/' . $name,
        [ 'X-Auth-Token' => $self->token ]
    );
    my $response = $self->_request($request);

    confess 'Unknown error'
        if $response->code != 201 && $response->code != 202;
    return WebService::CloudFiles::Container->new(
        cloudfiles => $self,
        name       => $name,
    );
}

1;

__END__

=head1 NAME

WebService::CloudFiles - Interface to Mosso CloudFiles service

=head1 SYNOPSIS

  use WebService::CloudFiles;
  use Perl6::Say;

  my $cloudfiles = WebService::CloudFiles->new(
      user => 'myusername',
      key  => 'mysecretkey',
  );

  # list all containers
  my @containers = $cloudfiles->containers;
  foreach my $container (@containers) {
      say 'have container ' . $container->name;
  }

  # create a new container
  my $container = $cloudfiles->create_container(name => 'testing');

  # use an existing container
  my $existing_container = $cloudfiles->container(name => 'testing');

  my $total_bytes_used = $cloudfiles->total_bytes_used;
  say "used $total_bytes_used";

  my $object_count = $container->object_count;
  say "$object_count objects";

  my $bytes_used = $container->bytes_used;
  say "$bytes_used bytes";

  # returns a Data::Stream::Bulk object
  # as it may have to make multiple HTTP requests
  my @objects = $container->objects->all;
  foreach my $object (@objects) {
      say 'have object ' . $object->name;
      # also size, etag, content_type, last_modified
  }
  my @objects2 = $container->objects(prefix => 'dir/')->all;

  # To create a new object
  my $xxx = $container->object( name => 'XXX' );
  $xxx->put('this is the value');

  # To set metadata of an object:
  $xxx->object_metadata({
	  description => 'this is a description',
	  useful_number => 17
  });
  
  # To create a new object with the contents of a local file
  my $yyy = $container->object( name => 'YYY', content_type => 'text/plain' );
  $yyy->put_filename('README');

  # To fetch an object:
  my $xxx2 = $container->object( name => 'XXX' );
  my $value = $xxx2->get;
  say 'has name ' . $xxx2->name;
  say 'has md5 ' . $xxx2->etag;
  say 'has size ' . $xxx2->size;
  say 'has content type ' . $xxx2->content_type;
  say 'has last_modified ' . $xxx2->last_modified;

  # To fetch metadata of an object:
  say 'metadata description ' . $xxx2->object_metadata->{'description'};
  say 'metadata useful_number ' . $xxx2->object_metadata->{'useful_number'};
  
  # To download an object to a local file
  $yyy->get_filename('README.downloaded');

  $object->delete;

  $container->delete;

=head1 DESCRIPTION

This module provides a simple interface to the Mosso Cloud Files
service. "Cloud Files is reliable, scalable and affordable web-based
storage for backing up and archiving all your static content".
Find out more at L<http://www.mosso.com/cloudfiles.jsp>.

To use this module you will need to sign up to Mosso Cloud Files
and provide a "user" and "key". If you use this module, you will
incurr costs as specified by Mosso. Please check the costs. If
you use this module with your user and key you will be responsible
for these costs.

I highly recommend reading all about Cloud Files, but in a nutshell
data is stored in objects. Objects are referenced by names and objects
are stored in containers.

=head1 METHODS

=head2 new

The constructor logs you into Cloud Files:

  my $cloudfiles = WebService::CloudFiles->new(
      user => 'myusername',
      key  => 'mysecretkey',
  );

=head2 containers

List all the containers and return them as L<WebService::CloudFiles::Container> objects:

  my @containers = $cloudfiles->containers;

=head2 create_container

Create a new container and return it as a L<WebService::CloudFiles::Container> object:

  my $container = $cloudfiles->create_container(name => 'testing');

=head2 container

Use an existing container and return it as a L<WebService::CloudFiles::Container> object:

  my $existing_container = $cloudfiles->container(name => 'testing');

=head2 total_bytes_used

Returns the total amount of bytes used in your Cloud Files account:

  my $total_bytes_used = $cloudfiles->total_bytes_used;

=head1 TESTING

Testing CloudFiles is a tricky thing. Mosso charges you a bit of
money each time you use their service. And yes, testing counts as using.
Because of this, this module's test suite skips testing unless
you set the following three environment variables, along the lines of:

  CLOUDFILES_EXPENSIVE_TESTS=1 CLOUDFILES_USER=username CLOUDFILES_KEY=15bf43... perl t/simple.t

=head1 SEE ALSO

L<WebService::CloudFiles::Container>, L<WebService::CloudFiles::Object>.

=head1 AUTHOR

Leon Brocard <acme@astray.com>.

=head1 COPYRIGHT

Copyright (C) 2008-9, Leon Brocard

=head1 LICENSE

This module is free software; you can redistribute it or modify it
under the same terms as Perl itself.
