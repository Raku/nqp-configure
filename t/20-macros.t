use strict;
use warnings;
use lib 'lib';
use NQP::Macros;
use NQP::Config;
use NQP::Config::Test;
use Test::More;
use v5.10;

nqp_config->configure_paths;
my $slash      = nqp_config->cfg('slash');
my $qchar      = nqp_config->cfg('quote');
my $platform   = nqp_config->cfg('platform');
my $ucplatform = uc $platform;

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

my $result = <<RESULT;
Platform $platform

PLATFORM $ucplatform
RESULT

expands <<'EOT', $result, 'Multiline';
Platform @platform@

@uc(pLatform @platform@)@
EOT

expands "\@uc(foO BaR)\@", "FOO BAR";
expands "\@lc(foO BaR)\@", "foo bar";

expands q<@nfpq(/A Path/With/Spaces)@>,
  qq<$qchar${slash}A Path${slash}With${slash}Spaces$qchar>;

expands q<@nfp(/A Path/With/Spaces)@>,
  qq<${slash}A Path${slash}With${slash}Spaces>;

expand_dies(
    q<@include(no-file)@>,
    "no file for include",
    message => qr/aaaaaa/
);

expands q<@?include(no-file)@>, "", "ignore macro error returns empty string";

expand_dies q<@?include(@include(failed-nested-include)@)@>,
  "nested macro error is not ignored",
  message => qr/File 'failed-nested-include' not found in base directory/;

expands q<@?include(@?include(failed-nested-include)@)@>, "", "nested ignore";

expand_dies
q<Text with @nop(some macros)@ to prepend @?include(@?nclude(failed-nested-include))@>,
  "unclosed )@",
  message => qr<\QCan't find closing )@ for macro 'include'\E>;

done_testing;
