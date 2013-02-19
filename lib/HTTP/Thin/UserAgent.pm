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

    use Throwable::Factory
        UnexpectedResponse => [qw($response)],
        ;

    has ua => (
        is      => 'ro',
        default => sub { HTTP::Thin->new() },
    );

    has request  => ( is => 'ro' );
    has on_error => ( is => 'rw', default => sub { sub { die $_->message } } );
    has decoder  => ( is => 'rw' );

    sub decoded_content {
        my $self = shift;
        return $self->decoder->( $self->response );
    }

    sub response {
        my $self    = shift;
        my $ua      = $self->ua;
        my $request = $self->request;
        return $ua->request($request);
    }

    sub as_json {
        my $self    = shift;
        my $request = $self->request;

        $request->header(
            'Accept'       => 'application/json',
            'Content-Type' => 'application/json',
        );

        if ( my $data = shift ) {
            $request->content( JSON::Any->encode($data) );
        }

        $self->decoder(
            sub {
                my $res = shift;
                my $content_type = $res->header('Content-Type');
                unless ( $content_type =~ m'application/json' )
                {
                    my $error = UnexpectedResponse->new(
                        message  => "Content-Type was $content_type not application/json",
                        response => $res,
                    );
                    for ($error) {
                        $self->on_error->($error);
                    }
                }
                JSON::Any->decode( $res->decoded_content );
            }
        );

        return $self;
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

=head1 SYNOPSIS

    use HTTP::Thin::UserAgent;

    my $data = http(GET http://api.metacpan.org/v0/author/PERIGRIN?join=favorite)->as_json->decode;

=head1 DESCRIPTION

WARNING this code is still *alpha* quality. While it will work as advertised on the tin, API breakage will likely be common until things settle down a bit. 

C<HTTP::Thin::UserAgent> provides what I hope is a thin layer over L<HTTP::Thin>. It exposes an functional API that hopefully makes writing HTTP clients easier. Right now it's in *very* alpha stage and really only helps for writing JSON clients. The intent is to expand it to be more generally useful but a JSON client was what I needed first.

=head1 EXPORTS

=over 4

=item http

A function that returns a new C<HTTP::Thin::UserAgent::Client> object, which does the actual work for the request. You pas in an L<HTTP::Request> object.

=item GET / PUT / POST 

Exports from L<HTTP::Request::Common> to make generating L<HTTP::Request> objects easier.

=back


