# multidimensional binning & histogramming - tests of the object-oriented interface

# XXX TODO replace $got by $binner->output??

use strict;
use warnings;
use Test::More tests => 36;
use Test::PDL;
use Test::Exception;
use Test::NoWarnings;

BEGIN {
	use_ok( 'PDL' ) or BAIL_OUT( 'Could not load PDL' );
	use_ok( 'PDL::NDBin' );
	use_ok( 'PDL::NDBin::Func', qw( iavg icount ) );
}

# variable declarations
my ( $expected, $got, $binner, $x, $y );

#
# LOW-LEVEL INTERFACE
#
note 'LOW-LEVEL INTERFACE';

# test argument parsing
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', 0, 0, 1 ] ] ) } 'correct arguments: one axis';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', 0, 0, 1 ],
				      [ 'dummy', 0, 0, 1 ] ] ) } 'correct arguments: two axes';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', 0, 0, 1 ],
				      [ 'dummy', 0, 0, 1 ],
				      [ 'dummy', 0, 0, 1 ] ] ) } 'correct arguments: three axes';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', 0, 0, 1 ],
				      [ 'dummy', 0, 0, 1 ],
				      [ 'dummy', 0, 0, 1 ] ],
			    loop => sub {},
			    vars => [ [ 'dummy', sub {} ] ] ) } 'correct arguments: three axes, one variable';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', 0, 0, 1 ],
				      [ 'dummy', 0, 0, 1 ],
				      [ 'dummy', 0, 0, 1 ] ],
			    loop => sub {},
			    vars => [ [ 'dummy', sub {} ],
				      [ 'dummy', sub {} ] ] ) } 'correct arguments: three axes, two variables';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', 0, 0, 1 ],
				      [ 'dummy', 0, 0, 1 ],
				      [ 'dummy', 0, 0, 1 ] ],
			    loop => sub {},
			    vars => [ [ 'dummy', sub {} ],
				      [ 'dummy', sub {} ],
				      [ 'dummy', sub {} ] ] ) } 'correct arguments: three axes, three variables';
dies_ok { PDL::NDBin->new() } 'no arguments';
dies_ok { PDL::NDBin->new( axes => [ [ 0 ] ] ) } 'wrong arguments: 0';
dies_ok { PDL::NDBin->new( axes => [ [ 'dummy' ] ] ) } 'wrong arguments: null';
dies_ok { PDL::NDBin->new( axes => [ [ 'dummy', 0 ] ] ) } 'wrong arguments: null, 0';
dies_ok { PDL::NDBin->new( axes => [ [ 'dummy', 0, 0 ] ] ) } 'wrong arguments: null, 0, 0';
dies_ok { PDL::NDBin->new( axes => [ [ 'dummy', 0, 0, 1 ],
				     [ 'dummy' ] ] ) } 'wrong arguments: null, 0, 0, 1, null';
dies_ok { PDL::NDBin->new( axes => [ [ 'dummy', 0, 0, 1 ],
				     [ 'dummy', 0 ] ] ) } 'wrong arguments: null, 0, 0, 1, null, 0';

# return values
$binner = PDL::NDBin->new( axes => [ [ u => (1,0,10) ] ] );
ok( $binner, 'constructor returns a value' );
isa_ok( $binner, 'PDL::NDBin', 'return value from new()' );
isa_ok( $binner->process( u => sequence(10) ), 'PDL::NDBin', 'return value from process()' );
isa_ok( $binner->process( u => sequence(10) )->process( u => sequence(10) ), 'PDL::NDBin', 'return value from chained calls to process()' );

# the example from PDL::histogram
$x = pdl( 1,1,2 );
# by default I<histogram> returns a piddle of the same type as the axis,
# but I<output> returns a piddle of type I<long> when histogramming
$expected = long( 0,2,1 );
$binner = PDL::NDBin->new( axes => [ [ 'x', 1, 0, 3 ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl( $got, $expected, 'example from PDL::histogram' );
$binner = PDL::NDBin->new( axes => [ [ 'x', 1, 0, 3 ] ],
			   loop => \&PDL::NDBin::default_loop,
			   vars => [ [ 'z', sub { shift->nelem } ] ] );
$binner->process( x => $x, z => zeroes( long, $x->nelem ) );
$got = $binner->output;
is_pdl( $got, $expected, 'variable and action specified explicitly' );
$expected = pdl( 0,2,1 );	# this is an exception, because the type is
				# locked to double by `$x => sub { ... }'
$binner = PDL::NDBin->new( axes => [ [ x => ( 1, 0, 3 ) ] ],
			   loop => \&PDL::NDBin::default_loop,
			   vars => [ [ x => sub { shift->nelem } ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl( $got, $expected, 'different syntax' );
$expected = long( 0,2,1 );
$binner = PDL::NDBin->new( axes => [ [ x => ( 1, 0, 3 ) ] ],
			   loop => \&PDL::NDBin::fast_loop,
			   vars => [ [ x => \&icount ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl( $got, $expected, 'different syntax, using fast loop' );

# this idiom with only chained calls should work
$x = pdl( 1,1,2 );
$expected = long( 0,2,1 );
$got = PDL::NDBin->new( axes => [ [ v => (1,0,3) ] ] )->process( v => $x )->output;
is_pdl( $got, $expected, 'all calls chained' );

# the example from PDL::histogram2d
$x = pdl( 1,1,1,2,2 );
$y = pdl( 2,1,1,1,1 );
$expected = long( [0,0,0], 
		  [0,2,2],
		  [0,1,0] );
$binner = PDL::NDBin->new( axes => [ [ x => (1,0,3) ],
				     [ y => (1,0,3) ] ] );
$binner->process( x => $x, y => $y );
$got = $binner->output;
is_pdl( $got, $expected, 'example from PDL::histogram2d' );

#
$x = pdl( 1,1,1,2,2,1,1 );
$y = pdl( 2,1,3,4,1,4,4 );
$expected = long( [1,1],
		  [1,0],
		  [1,0],
		  [2,1] );
$binner = PDL::NDBin->new( axes => [ [ 'x', 1, 1, 2 ],
				     [ 'y', 1, 1, 4 ] ] );
$binner->process( x => $x, y => $y );
$got = $binner->output;
is_pdl( $got, $expected, 'nonsquare two-dimensional histogram' );

# binning integer data
$x = byte(1,2,3,4);
$expected = long(1,1,1,1);
$binner = PDL::NDBin->new( axes => [ [ x => (1,1,4) ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl( $got, $expected, 'binning integer data: base case' );
$x = short( 0,-1,3,9,6,3,1,0,1,3,7,14,3,4,2,-6,99,3,2,3,3,3,3 ); # contains out-of-range data
$expected = short( 8,9,1,0,5 );
$binner = PDL::NDBin->new( axes => [ [ x => (1,2,5) ] ],
			   loop => \&PDL::NDBin::default_loop,
			   vars => [ [ x => sub { shift->nelem } ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl( $got, $expected, 'binning integer data: step = 1' );
$expected = long( 18,1,1,1,2 );
$binner = PDL::NDBin->new( axes => [ [ x => (2,3,5) ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl( $got, $expected, 'binning integer data: step = 2' );

# more actions & missing/undefined/invalid stuff
$x = sequence 21;
$expected = double( 1,4,7,10,13,16,19 );
$binner = PDL::NDBin->new( axes => [ [ 'x', 3, 0, 7 ] ],
			   loop => \&PDL::NDBin::default_loop,
			   vars => [ [ 'x', sub { shift->avg } ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl( $got, $expected, 'variable with action = average' );
$binner = PDL::NDBin->new( axes => [ [ 'x', 3, 0, 7 ] ],
			   loop => \&PDL::NDBin::fast_loop,
			   vars => [ [ 'x', \&iavg ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl( $got, $expected, 'variable with action = average, using fast loop' );
$x = 5+sequence 3; # 5 6 7
$expected = double( 0,0,1,1,1 )->inplace->setvaltobad( 0 );
$binner = PDL::NDBin->new( axes => [ [ 'x', 1,3,5 ] ],
			   loop => \&PDL::NDBin::default_loop,
			   vars => [ [ 'x', sub { shift->nelem || undef } ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl( $got, $expected, 'empty bins unset' ); # cannot be achieved with fast loop

# cross-check with hist and some random data
$x = pdl( 0.7143, 0.6786, 0.9214, 0.5065, 0.9963, 0.9703, 0.1574, 0.4718,
	0.4099, 0.7701, 0.1881, 0.9412, 0.0034, 0.4440, 0.9423, 0.2065, 0.9656,
	0.5672, 0.2300, 0.5300, 0.1842 );
$y = pdl( 0.7422, 0.0299, 0.6629, 0.9118, 0.1224, 0.6173, 0.9203, 0.9999,
	0.1480, 0.4297, 0.5000, 0.9637, 0.1148, 0.2922, 0.0846, 0.0954, 0.1379,
	0.3187, 0.1655, 0.5777, 0.3047 );
$expected = histogram( $x, .1, 0, 10 )->long;
$binner = PDL::NDBin->new( axes => [ [ 'x', .1, 0, 10 ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl( $got, $expected, 'cross-check with histogram' );
$expected = histogram2d( $x, $y, .1, 0, 10, .1, 0, 10 )->long;
$binner = PDL::NDBin->new( axes => [ [ 'x', .1, 0, 10 ],
				     [ 'y', .1, 0, 10 ] ] );
$binner->process( x => $x, y => $y );
$got = $binner->output;
is_pdl( $got, $expected, 'cross-check with histogram2d' );
