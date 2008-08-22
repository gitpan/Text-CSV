#!/usr/bin/perl

# tests for bug report fixes or patches.

use strict;
$^W = 1;

use Test::More tests => 3;
#use Test::More "no_plan";


BEGIN { $ENV{PERL_TEXT_CSV} = $ARGV[0] || 0; }

BEGIN {
    require_ok "Text::CSV";
    plan skip_all => "Cannot load Text::CSV" if $@;
}

#print Text::CSV->backend, "\t", Text::CSV->backend->VERSION, "\n";

my $csv = Text::CSV->new( { sep_char => "\t", blank_is_undef => 1, allow_whitespace => 1 } );

ok $csv->parse(qq|John\t\t"my notes"|);

is( 'John,undef,my notes', join( ',', map { ! defined $_ ? 'undef' : $_ } $csv->fields ) );


