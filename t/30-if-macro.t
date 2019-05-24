use v5.10.1;
use lib 'lib';
use utf8;
use NQP::Macros;
use NQP::Config;
use NQP::Config::Test;
use Test::More;

plan tests => 2;

my $cfg = nqp_config;

subtest "if macro" => sub {
    plan tests => 8;
    my $s = $cfg->push_ctx(
        {
            configs => [
                {
                    cond_var       => 42,
                    undef_var      => undef,
                    'compound:var' => 'ok',
                },
            ],
        }
    );

    expands(
        q<@if(cond_var The Answer is out there!)@>,
        q<The Answer is out there!>,
        "defined variable"
    );
    expands(
        q<@if(cond_var==42 The Answer is out there!)@>,
        q<The Answer is out there!>,
        "value equals"
    );
    expands(
        q<@if(cond_var!=41 There is no Answer)@>,
        q<There is no Answer>,
        "value not equals"
    );
    expands( q<@if(cond_var==41 There is no Answer)@>,
        q<>, "condition doesn't match" );
    expands(
        q<@if(!undef_var The Answer is not defined)@>,
        q<The Answer is not defined>,
        "match on undefined"
    );
    expands(
        q<@if(!missing_var The Answer is not found)@>,
        q<The Answer is not found>,
        "missing is like undefined"
    );
    expands( q<@if(!cond_var The Answer is not there)@>,
        q<>, "missing is like undefined" );
    expands(
        q<@if(compound:var The Answer is compound)@>,
        q<The Answer is compound>,
        "compound variable match"
    );
};

subtest "if macro failures" => sub {
    plan tests => 3;
    expand_dies( q<@if(notext)@>, "no text",
        message => qr/Invalid input of macro 'if'/ );
    expand_dies(
        q<@if(bad:var:==1 text)@>,
        "bad var",
        message => qr/Invalid input of macro 'if'/
    );
    expand_dies( q<@if(var=1 text)@>,
        "bad op", message => qr/Malformed condition of macro 'if'/ );
};

done-testing;

