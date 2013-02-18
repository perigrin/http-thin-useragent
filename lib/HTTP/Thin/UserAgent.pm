package HTTP::Thin::UserAgent;
use 5.12.1;
use warnings;

# ABSTRACT: A Thin UserAgent around some useful modules.

{

    package HTTP::Thin::UserAgent::Client;
    use Moo;
    use MooX::late;
    use HTTP::Thin;
    use JSON::Any;

    has ua => (
        is      => 'ro',
        default => sub { HTTP::Thin->new() },
    );

    has request => ( is => 'ro' );

    sub as_raw {
        my $self   = shift;
        my $ua     = $self->ua;
        my $request = $self->request;
        return $ua->request($request);
    }

    sub as_json {
        my $self = shift;
        my $request = $self->request;
        $request->header( 'Accept' => 'application/json' );
        if ( my $data = shift ) {
            $request->content( JSON::Any->encode($data) );
        }
        my $res = $self->as_raw;
        return JSON::Any->decode( $res->content ) if $res->is_success;
        return;
    }
}

use parent qw(Exporter);
use Import::Into;
use HTTP::Request::Common;

our @EXPORT = qw(http);

sub import {
    shift->export_to_level(1);
    HTTP::Request::Common->import::into( scalar caller );
}

sub http { HTTP::Thin::UserAgent::Client->new( request => shift ) }

1;
__END__

=head1 NAME - HTTP::Thin::UserAgent

=head1 SYNOPSIS

    use HTTP::Thin::UserAgent;

    my $data = http(GET http://api.metacpan.org/v0/author/PERIGRIN?join=favorite)->as_json;

=head1 DESCRIPTION

C<HTTP::Thin::UserAgent> provides what I hope is a thin layer over L<HTTP::Thin>. It exposes an functional API that hopefully makes writing HTTP clients easier. 

