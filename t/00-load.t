# multidimensional binning & histogramming - test module loading

use strict;
use warnings;
use Test::More tests => 3;

foreach my $pkg ( qw( PDL::NDBin PDL::NDBin::Actions_PP PDL::NDBin::Iterator ) ) {
	require_ok( $pkg ) or BAIL_OUT( "Cannot load $pkg" );
}
