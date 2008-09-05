#!/usr/bin/perl

# tests for bug report fixes or patches.

use strict;
$^W = 1;

use Test::More tests => 3;


BEGIN { $ENV{PERL_TEXT_CSV} = $ARGV[0] || 0; }

BEGIN {
    require_ok "Text::CSV";
    plan skip_all => "Cannot load Text::CSV" if $@;
}

my $csv = Text::CSV->new( { sep_char => "\t", blank_is_undef => 1, allow_whitespace => 1 } );

ok $csv->parse(qq|John\t\t"my notes"|);

is_deeply ([ $csv->fields ], [ "John", undef, "my notes" ], "Tab with allow_white_space");
