#!usr/bin/env perl
use strict;
use Test::More;

use HTTP::Thin::UserAgent;
use Test::Requires::Env qw(
    LIVE_HTTP_TESTS
);

{
    my $uri = 'http://api.metacpan.org/v0/author/PERIGRIN/';
    ok defined http( GET $uri)->as_json, 'got data';
}

{
    my $uri = 'http://api.metacpan.org/v0/release/_search';
    ok defined http( POST $uri)->as_json(
        {   query  => { match_all => {} },
            size   => 5000,
            fields => ['distribution'],
            filter => {
                and => [
                    {   term => {
                            'release.dependency.module' => 'MooseX::NonMoose'
                        }
                    },
                    { term => { 'release.maturity' => 'released' } },
                    { term => { 'release.status'   => 'latest' } }
                ]
            }
        }
    );
}

done_testing;
