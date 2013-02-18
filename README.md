HTTP::Thin::UserAgent
===================

HTTP::Thin::UserAgent --  A Thin Wrapper around HTTP::Thin


    use HTTP::Thin::UserAgent;
    my $uri = 'http://api.metacpan.org/v0/release/_search';
    my $data = http( POST $uri)->as_json(
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

