#!/usr/bin/perl

use strict;
$^W = 1;

use Test::More;

BEGIN { $ENV{TEXT_CSV_XS} = 0; }

eval "use Test::Pod::Coverage tests => 2";
plan skip_all => "Test::Pod::Covarage required for testing POD Coverage" if $@;
pod_coverage_ok ("Text::CSV", { also_private => [ qr/^[A-Z_]+$/ ], }, "Text::CSV is covered");
pod_coverage_ok ("Text::CSV_PurePerl", { also_private => [ qr/^[A-Z_]+$/ ], }, "Text::CSV_PurePerl is covered");

