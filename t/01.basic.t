#!usr/bin/env perl
use strict;
use Test::More;

use HTTP::Thin::UserAgent;
use Test::Requires::Env qw(
  LIVE_HTTP_TESTS
);

{
    my $uri  = 'http://api.metacpan.org/v0/author/PERIGRIN/';
    my $resp = http( GET $uri )->as_json->response;
    ok $resp->is_success, 'request was successful';

    my $data = http( GET $uri )->as_json->decode;
    ok defined $data, 'got data';
}

{
    my $uri = 'http://api.metacpan.org/v0/release/_search';
    ok defined http( POST $uri)->as_json(
        {
            query  => { match_all => {} },
            size   => 5000,
            fields => ['distribution'],
            filter => {
                and => [
                    {
                        term => {
                            'release.dependency.module' => 'MooseX::NonMoose'
                        }
                    },
                    { term => { 'release.maturity' => 'released' } },
                    { term => { 'release.status'   => 'latest' } }
                ]
            }
        }
    )->decode;
}
{
    my $uri = 'http://www.imdb.com/find?q=Kevin+Bacon';
    ok my $data = http( GET $uri )->scraper(
        scraper {
            process '.findResult', 'results[]' => scraper {
                process '.result_text',       text => 'TEXT';
                process '.result_text > a',  link => '@href';
            };
        }
    )->decode, 'scraped IMDB';
    ok grep( { $_->{text} =~ /^\QKevin Bacon (I) (Actor,\E/ } @{$data->{results}} ), 'found Kevin Bacon';
}
done_testing;
