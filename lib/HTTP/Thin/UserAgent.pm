package HTTP::Thin::UserAgent;
use 5.16.1;
use warnings;

# ABSTRACT: A Thin UserAgent around some useful modules.

use mop;

use HTTP::Thin;
use JSON::Any;
use Try::Tiny;
use Throwable::Factory
  UnexpectedResponse => [qw($response)],
  ;

class Client {

    has $ua = do { HTTP::Thin->new };

    has $request is ro;

    has $on_error is rw = do { sub { die $_->message } };

    has $decoder is rw;

    # has $response is ro, lazy = sub { ${^SELF}->_response };
    has $response is ro, lazy(sub { ${^SELF}->_response });

    method _response { $ua->request($request); }

    # has $tree is ro, lazy = sub { ${^SELF}->_tree };
    has $tree is ro, lazy(sub { ${^SELF}->_tree });

    method _tree {
        my $t = HTML::TreeBuilder::XPath->new;
        $t->store_comments(1) if ( $t->can('store_comments') );
        $t->ignore_unknown(0);
        $t->parse( $self->content );
        return $t;
    };

    method decode { $decoder->($self->response) }
    method decoded_content { $self->decode }
    method handles { $response->decoded_content }

    method as_json($data) {
        $request->header(
            'Accept'       => 'application/json',
            'Content-Type' => 'application/json',
        );

        if (defined $data) {
            $request->content( JSON::Any->encode($data) );
        }

        $decoder = sub {
            my $res          = shift;
            my $content_type = $res->header('Content-Type');
            unless ( $content_type =~ m'application/json' ) {
                my $error = UnexpectedResponse->new(
                    message =>
                      "Content-Type was $content_type not application/json",
                    response => $res,
                );
                for ($error) {
                    $self->on_error->($error);
                }
            }
            JSON::Any->decode( $res->content );
        };

        return $self;
    }

    method dump {
        require Data::Dumper;
          return Data::Dumper::Dumper($self)
    }

    method scraper($scraper) {
        $decoder = sub {
            my $res = shift;
            my $data = try { $scraper->scrape( $res->content ) }
            catch {
                my $error = UnexpectedResponse->new(
                    message  => $_,
                    response => $res
                );
                for ($error) { $self->on_error->($error); }
            };
            return $data;
        };
        return $self;
    }

    
    method find($exp) {

        my $xpath = $exp =~ m!^(?:/|id\()!
          ? $exp
          : HTML::Selector::XPath::selector_to_xpath($exp);

        my @nodes = try { $tree->findnodes($xpath) }
        catch {
            for ($_) { $self->on_error($_) }
        };
        return unless @nodes;
        return \@nodes;
    }

}

use parent qw(Exporter);
use Import::Into;
use HTTP::Request::Common;
use Web::Scraper;

our @EXPORT = qw(http);

sub import {
    shift->export_to_level(1);
    HTTP::Request::Common->import::into( scalar caller );
    Web::Scraper->import::into( scalar caller );
}

sub http { HTTP::Thin::UserAgent::Client->new( request => shift ) }

1;
__END__

=head1 SYNOPSIS

    use HTTP::Thin::UserAgent;

    my $favorites = http(GET 'http://api.metacpan.org/v0/author/PERIGRIN?join=favorite')->as_json->decode;

    my $results = http(GET 'http://www.imdb.com/find?q=Kevin+Bacon')->scraper(
        scraper {
            process '.findResult', 'results[]' => scraper {
                process '.result_text', text => 'TEXT';
                process '.result_text > a', link => '@href';
            }
        }
    );

=head1 DESCRIPTION

WARNING this code is still *alpha* quality. While it will work as advertised on the tin, API breakage will likely be common until things settle down a bit. 

C<HTTP::Thin::UserAgent> provides what I hope is a thin layer over L<HTTP::Thin>. It exposes an functional API that hopefully makes writing HTTP clients easier. Right now it's in *very* alpha stage and really only helps for writing JSON clients. The intent is to expand it to be more generally useful but a JSON client was what I needed first.

=head1 EXPORTS

=over 4

=item http

A function that returns a new C<HTTP::Thin::UserAgent::Client> object, which does the actual work for the request. You pas in an L<HTTP::Request> object.

=item GET / PUT / POST 

Exports from L<HTTP::Request::Common> to make generating L<HTTP::Request> objects easier.

=item scraper / process

Exports from L<Web::Scraper> to assist in building scrapers for HTML documents.

=back

=head1 Methods

C<HTTP::Thin::UserAgent::Client> has the following methods.

=over 4

=item response( )

Returns the L<HTTP::Response> object returned by L<HTTP::Thin>

=item as_json( $data )

This sets the request up to use C<application/json> and then adds a decoder to decode the L<HTTP::Response> content. If data is passed in it will be encoded into JSON and supplied in as the request data.

=item scraper( $scraper )

Sets up the request to process the response through the L<Web::Scraper> object supplied. It will return the data (if any) returned by the scraper object.

=item decode( )

Returns the decoded content, currently we only support HTML (in which case we return scraped content) and JSON (in which case we decode the JSON using JSON::Any).

=item tree( )

Returns a L<HTML::Treebuilder::XPath> object. 

=item find( $exp ) 

Takes a CSS or XPath expression and returns an arrayref of L<HTML::Treebuilder::XPath> nodes.

=item on_error( $coderef )

A code reference that if there is an error in fetching the HTTP response handles that error. C<$_> will be set to the error being handled.

=back
