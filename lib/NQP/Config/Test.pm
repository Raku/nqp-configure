use v5.10.1;
use strict;
use warnings;
use utf8;

package NQP::Config::Test;
use Test::More;
use base qw<Exporter>;

use base qw<NQP::Config>;

our @EXPORT = qw<expands expand_dies nqp_config macros>;

my ( $config, $macros );

sub nqp_config {
    $config = $_[0] if @_;
    $config = __PACKAGE__->new unless $config;
    return $config;
}

sub macros {
    $macros = $_[0] if @_;
    $macros =
      NQP::Macros->new( config => nqp_config, on_fail => sub { die shift } )
      unless $macros;
    return $macros;
}

sub expands {
    my ( $snippet, $expected, $name ) = @_;
    my $got;
    eval { $got = macros->expand($snippet); };
    if ($@) {
        if ( ref($@) eq 'NQP::Macros::_Err' ) {
            BAIL_OUT( $@->message );
        }
        else {
            BAIL_OUT($@);
        }
    }
    is $got, $expected, $name || $snippet;
}

sub expand_dies {
    my ( $snippet, $name, %profile ) = @_;

    subtest "$name" => sub {
        eval { macros->expand($snippet); };
        my $err = $@;
        if ($err) {
            subtest "exception type" => sub {
                if ( ref($err) && $err->isa('NQP::Macros::_Err') ) {
                    pass "type is NQP::Macros::_Err";
                    my $msg = $profile{message};
                    if ($msg) {
                        my $errmsg = $err->message;
                        like $errmsg, $profile{message}, "exception message";
                    }
                }
                else {
                    fail "unexpected exception type: "
                      . ( ref($err) || 'plain scalar' );
                    diag $err;
                }
            };
        }
        else {
            fail( q<"> . $name . q<" test didn't die> );
        }
    };
}

1;
