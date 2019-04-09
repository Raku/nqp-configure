use lib 'lib';
use NQP::Macros;
use NQP::Config;
use Test::More;

use v5.12;

my $config = tie my %config, 'NQP::Config', lang => 'Test';

my $macros = NQP::Macros->new(config => $config);

sub expands {
  my ($snippet, $expected) = @_;
  my $got = $macros->expand($snippet);
  is $got, $expected, $snippet;
}

expands '@sp_escape(foo bar)@', 'foo\\ bar';

done_testing;
