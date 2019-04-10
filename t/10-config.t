use lib 'lib';
use NQP::Config::Test;
use Test::More;

subtest "Contexts" => sub {

    subtest "Single" => sub {
        my $config = NQP::Config::Test->new;

        my $sc;

        isnt $config->cfg('level1'), 'ok',
          "variable doesn't exists before context is added";
        is scalar( $config->contexts ), 0, "no contexts defined yet";

        $sc = $config->push_ctx( { configs => [ { level1 => "ok", } ] } );

        is scalar( $config->contexts ), 1, "one context found";
        is $config->cfg('level1'), 'ok', "context sets a variable";

        undef $sc;

        is scalar( $config->contexts ), 0,
          "no contexts left after destroying scoping object";
        isnt $config->cfg('level1'), 'ok',
          "destroying scoping object removes context";
    };

    subtest "Multiple" => sub {
        my $config = NQP::Config::Test->new;

        my @ctx_sc;

        for my $l ( 1 .. 10 ) {
            push @ctx_sc,
              $config->push_ctx(
                {
                    configs => [
                        {
                            "level$l" => "ok",
                            level     => $l,
                        }
                    ],
                }
              );
        }

        is scalar( $config->contexts ), 10, "all 10 contexts are in place";
        is $config->cfg('level'), 10, "last added context is dominant";
        for my $l ( 1 .. 10 ) {
            is $config->cfg("level$l"), "ok", "level $l context variable ok";
        }

        pop @ctx_sc;
        is scalar( $config->contexts ), 9, "... and then there were nine";
        is $config->cfg('level'), 9,
          "now, as level 10 context is gone, 9 takes over";

        splice( @ctx_sc, 2, 1 );
        is scalar( $config->contexts ), 8, "... and then there were eight";
        isnt $config->cfg('level3'), "ok", "level 3 context is gone";
    };
};

done_testing;
