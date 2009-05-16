#!/usr/bin/perl

# tests for bug report fixes or patches.

use strict;
$^W = 1;

use Test::More tests => 7;


BEGIN { $ENV{PERL_TEXT_CSV} = $ARGV[0] || 0; }

BEGIN {
    require_ok "Text::CSV";
    plan skip_all => "Cannot load Text::CSV" if $@;
}

my $csv = Text::CSV->new( { sep_char => "\t", blank_is_undef => 1, allow_whitespace => 1 } );

ok $csv->parse(qq|John\t\t"my notes"|);

is_deeply ([ $csv->fields ], [ "John", undef, "my notes" ], "Tab with allow_white_space");



# 2009-04-23 rt#45215

my $str = "this,is,some,csv,data\n";

$csv = Text::CSV->new;
$csv->parse($str);

is( $csv->string, $str );


# 2009-05-16
# getline() handles having escaped null

my $opts = {
  'escape_char' => '"',
  'quote_char' => '"',
  'binary' => 1,
  'sep_char' => ','
};

my $eol  = "\r\n";
my $blob = ( join "", map { chr $_ } 0 .. 255 ) x 1;

$csv = Text::CSV->new( $opts );

open( FH, '>__test.csv' ) or die $!;
binmode FH;

# writting
ok( $csv->print( *FH, [ $blob ] ) );
close( FH );

# reading
open( FH, "__test.csv" ) or die $!;
binmode FH;

$opts->{eol} = $eol;
$csv = Text::CSV->new( $opts );

ok( my $colref = $csv->getline( *FH ) );

is( $colref->[0], $blob, "blob" );

close( FH );
unlink( '__test.csv' );

