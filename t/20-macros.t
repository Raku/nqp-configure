use lib 'lib';
use NQP::Macros;
use NQP::Config;
use NQP::Config::Test;
use Test::More;

use v5.12;

my $config     = NQP::Config::Test->new;
my $slash      = $config->cfg('slash');
my $qchar      = $config->cfg('quote');
my $platform   = $config->cfg('platform');
my $ucplatform = uc $platform;

my $macros = NQP::Macros->new( config => $config );

sub expands {
    my ( $snippet, $expected, $name ) = @_;
    my $got = $macros->expand($snippet);
    is $got, $expected, $name || $snippet;
}

expands "\@sp_escape(fo\\o bar\n)\@",         "fo\\\\o\\ bar\n", 'sp_escape';
expands "\@nl_escape(foo bar\n)\@",           "foo bar\\\n",     'nl_escape';
expands "\@sp_unescape(fo\\o\\ b\\\\a\\r)\@", "fo\\o b\\a\\r",   'sp_unescape';

expands q<@lc(Line @sp_escape(with spaces)@)@>, q<line with\\ spaces>,
  'Nested call';
expands q<\@lc(Line @sp_escape(with spaces)@)@>, q<@lc(Line with\\ spaces)@>,
  'Escaping @';
expands q<@lc(Line @sp_escape(with spaces)@)\\@)@>, q<line with\\ spaces)@>,
  ')\\@ escaping';
expands q<@lc(Line @sp_escape(with spaces)@)\\\\@)@>,
  q<line with\\ spaces)\\@>, 'Escaping \\';
expands q<@lc(Line \@sp_escape(with spaces)@)@>,
  q<line @sp_escape(with spaces)@>, 'Escaping nested @';

expands q<This \text would rem@in unchanged>,
  q<This \text would rem@in unchanged>, 'No escaping when not needed';

expands <<'EOT', <<RESULT, 'Multiline';
Platform @platform@

@uc(pLatform @platform@)@
EOT
Platform $platform

PLATFORM $ucplatform
RESULT

expands "\@uc(foO BaR)\@", "FOO BAR";
expands "\@lc(foO BaR)\@", "foo bar";

expands q<@nfpq(/A Path/With/Spaces)@>,
  qq<$qchar${slash}A Path${slash}With${slash}Spaces$qchar>;

expands q<@nfp(/A Path/With/Spaces)@>,
  qq<${slash}A Path${slash}With${slash}Spaces>;

done_testing;
