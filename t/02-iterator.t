# multidimensional binning & histogramming - iterator tests

use strict;
use warnings;
use Test::More tests => 50;
use Test::PDL;
use Test::Exception;
use Test::NoWarnings;

BEGIN {
	use_ok( 'PDL' ) or BAIL_OUT( 'Could not load PDL' );
	use_ok( 'PDL::NDBin::Iterator' );
}

# variable declarations
my( $iter, @bins, @variables, $hash, $bin, $var, @expected, @got, $k );

#
@bins = ( 4 );
@variables = ( PDL->null );
$hash = PDL->null;
$iter = PDL::NDBin::Iterator->new( \@bins, \@variables, $hash );
isa_ok $iter, 'PDL::NDBin::Iterator', 'return value from constructor';

# test iteration
@bins = ( 4 );
@variables = ( PDL->null );
$hash = PDL->null;
$iter = PDL::NDBin::Iterator->new( \@bins, \@variables, $hash );
$k = 4;
while( my @return = $iter->next ) { last if $k-- == 0 }
is $k, 0, 'next in list context';
ok $iter->done, 'iteration complete';
is_deeply [ $iter->next ], [], "doesn't reset";
$iter = PDL::NDBin::Iterator->new( \@bins, \@variables, $hash );
$k = 4;
while( my $return = $iter->next ) { last if $k-- == 0 }
is $k, 0, 'next in scalar context';
ok $iter->done, 'iteration complete';
is_deeply [ $iter->next ], [], "doesn't reset";
$iter = PDL::NDBin::Iterator->new( \@bins, \@variables, $hash );
$k = 4;
while( $iter->next ) { last if $k-- == 0 }
is $k, 0, 'next in boolean context';
ok $iter->done, 'iteration complete';
is_deeply [ $iter->next ], [], "doesn't reset";

#
@bins = ( 4 );
@variables = ( 'one', 'two', 'three' );
$hash = 'this is my secret hash';
$iter = PDL::NDBin::Iterator->new( \@bins, \@variables, $hash );
is $iter->nbins, 4, 'number of bins';
is $iter->nvars, 3, 'number of variables';
@got = ();
@expected = (
	[ 0, 0, 'one',   $hash ],
	[ 0, 1, 'two',   $hash ],
	[ 0, 2, 'three', $hash ],
	[ 1, 0, 'one',   $hash ],
	[ 1, 1, 'two',   $hash ],
	[ 1, 2, 'three', $hash ],
	[ 2, 0, 'one',   $hash ],
	[ 2, 1, 'two',   $hash ],
	[ 2, 2, 'three', $hash ],
	[ 3, 0, 'one',   $hash ],
	[ 3, 1, 'two',   $hash ],
	[ 3, 2, 'three', $hash ],
);
$k = 12;
while( ( $bin, $var ) = $iter->next ) {
	push @got, [ $bin, $var, $iter->data, $iter->hash ];
	last if $k-- == 0; # prevent endless loops
};
ok $k == 0 && $iter->done, 'number of iterations';
is_deeply \@got, \@expected, 'data(), hash()';

#
@bins = ( 3, 2 );
@variables = ( sequence(20), 20-sequence(20) );
$hash = 2*sequence( 20 )->long;
$iter = PDL::NDBin::Iterator->new( \@bins, \@variables, $hash );
is $iter->nbins, 6, 'number of bins';
is $iter->nvars, 2, 'number of vars';
@got = ();
@expected = (
	[ 0, 0, [ 0, 0 ] ],
	[ 0, 1, [ 0, 0 ] ],
	[ 1, 0, [ 1, 0 ] ],
	[ 1, 1, [ 1, 0 ] ],
	[ 2, 0, [ 2, 0 ] ],
	[ 2, 1, [ 2, 0 ] ],
	[ 3, 0, [ 0, 1 ] ],
	[ 3, 1, [ 0, 1 ] ],
	[ 4, 0, [ 1, 1 ] ],
	[ 4, 1, [ 1, 1 ] ],
	[ 5, 0, [ 2, 1 ] ],
	[ 5, 1, [ 2, 1 ] ],
);
$k = 12;
while( ( $bin, $var ) = $iter->next ) {
	push @got, [ $bin, $var, [ $iter->unhash ] ];
	last if $k-- == 0; # prevent endless loops
};
ok $k == 0 && $iter->done, 'number of iterations';
is_deeply \@got, \@expected, 'unhash()';

#
@bins = ( 3, 2 );
@variables = ( sequence(20) );
$hash = sequence( 20 )->long % 6;
$iter = PDL::NDBin::Iterator->new( \@bins, \@variables, $hash );
is $iter->nbins*$iter->nvars, 6, 'nbins() * nvars()';
@got = ();
@expected = (
	long( 0,6,12,18 ),
	long( 1,7,13,19 ),
	long( 2,8,14 ),
	long( 3,9,15 ),
	long( 4,10,16 ),
	long( 5,11,17 ),
);
$k = 6;
while( ( $bin, $var ) = $iter->next ) {
	push @got, $iter->want;
	last if $k-- == 0; # prevent endless loops
};
ok $k == 0 && $iter->done, 'number of iterations';
for( 0 .. $#got ) {
	is_pdl $got[ $_ ], $expected[ $_ ], "want() iteration $_";
}

#
@bins = ( 2, 4 );
@variables = ( sequence(20), 20-sequence(20) );
# idx   0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19
# hash  0  1  2  3  4  5  6  7  0  1  2  3  4  5  6  7  0  1  2  3
# var1  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19
# var2 20 19 18 17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1
$hash = sequence( 20 )->long % 8;
$iter = PDL::NDBin::Iterator->new( \@bins, \@variables, $hash );
is $iter->nbins*$iter->nvars, 16, 'nbins() * nvars()';
@got = ();
@expected = (
	pdl( 0,8,16 ),
	pdl( 20,12,4 ),
	pdl( 1,9,17 ),
	pdl( 19,11,3 ),
	pdl( 2,10,18 ),
	pdl( 18,10,2 ),
	pdl( 3,11,19 ),
	pdl( 17,9,1 ),
	pdl( 4,12 ),
	pdl( 16,8 ),
	pdl( 5,13 ),
	pdl( 15,7 ),
	pdl( 6,14 ),
	pdl( 14,6 ),
	pdl( 7,15 ),
	pdl( 13,5 ),
);
$k = 16;
while( ( $bin, $var ) = $iter->next ) {
	push @got, $iter->selection;
	last if $k-- == 0; # prevent endless loops
};
ok $k == 0 && $iter->done, 'number of iterations';
for( 0 .. $#got ) {
	is_pdl $got[ $_ ], $expected[ $_ ], "selection() iteration $_";
}

# test variable deactivation
@bins = ( 2, 4, 3 );
@variables = ( random(20), random(20), random(20), random(20) );
$hash = 24*random( 20 )->long;
$iter = PDL::NDBin::Iterator->new( \@bins, \@variables, $hash );
is $iter->nbins*$iter->nvars, 96, 'nbins() * nvars()';
my @visited = (0) x @variables;
$k = 4;
while( ( $bin, $var ) = $iter->next ) {
	$visited[ $var ]++;
	$iter->var_active( 0 );
	last if $k-- == 0; # prevent endless loops
};
ok $k == 0 && $iter->done, 'number of iterations';
is_deeply \@visited, [ (1) x @variables ], 'all variables visited once';
