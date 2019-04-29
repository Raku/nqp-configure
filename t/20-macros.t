use lib 'lib';
use NQP::Macros;
use NQP::Config;
use NQP::Config::Test;
use Test::More;

use v5.12;

my $config = NQP::Config::Test->new;
my $slash  = $config->cfg('slash');
my $qchar  = $config->cfg('quote');

my $macros = NQP::Macros->new( config => $config );

sub expands {
    my ( $snippet, $expected ) = @_;
    my $got = $macros->expand($snippet);
    is $got, $expected, $snippet;
}

expands "\@sp_escape(foo bar\n)\@",      "foo\\ bar\n";
expands "\@nl_escape(foo bar\n)\@",      "foo bar\\\n";
expands "\@unescape(fo\\o b\\\\a\\r)\@", "foo b\\ar";

expands "\@uc(foO BaR)\@", "FOO BAR";
expands "\@lc(foO BaR)\@", "foo bar";

expands q<@nfp(/A Path/With/Spaces)@>,
  qq<$qchar${slash}A Path${slash}With${slash}Spaces$qchar>;

done_testing;
