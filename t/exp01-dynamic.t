#!/usr/bin/perl

use strict;
$^W = 1;	# use warnings core since 5.6

use Test::More tests => 11;

BEGIN {
    $ENV{TEXT_CSV_XS} = 0;
    use_ok "Text::CSV", '-dynamic';
}



my $csv = Text::CSV->new({module => 'Text::CSV_PP'});

isa_ok($csv, 'Text::CSV');
isa_ok($csv->{_MODULE}, 'Text::CSV_PP');
is($csv->module, 'Text::CSV_PP');

$csv = Text::CSV->new({module => 'Text::CSV_PP'});
isa_ok($csv, 'Text::CSV');


can_ok($csv, 'is_xs');
can_ok($csv, 'is_pp');
can_ok($csv, 'is_dynamic');

ok($csv->is_pp);
ok($csv->is_dynamic);
ok(Text::CSV->is_pp);
