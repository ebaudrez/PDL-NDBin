# multidimensional binning & histogramming - tests of the functional interface

use strict;
use warnings;
use Test::More tests => 90;
use Test::PDL;
use Test::Exception;
use Test::NoWarnings;

BEGIN {
	use_ok( 'PDL' ) or BAIL_OUT( 'Could not load PDL' );
	use_ok( 'PDL::NDBin', qw( ndbinning ndbin process_axes make_labels ) );
}

# because PDL overloads the comparison operators, it is no fun to run
# is_deeply() on piddles; as a workaround, we remove them
#
# XXX actually we should delete the `pdl' key only in a private, deep copy of
# $got, instead of messing up the original
sub is_deeply_without_pdl
{
	my ( $got, $expected, $name ) = @_;
	for( @$got, @$expected ) { delete $_->{pdl} }
	is_deeply( $got, $expected, $name );
}

sub debug_action
{
	my $iter = shift;
	# Piddle operations can be dangerous: when applying them to the result
	# of an index operation on an empty piddle, they may throw an
	# exception. Empty piddles are used, among others, when an ordinary
	# histogram is required. So, just to be safe, we wrap all potentially
	# dangerous calls in an `eval'.
	#
	# Remember that the actual operations are delayed until required, so
	# the exception will be raised here, rather than in the code that does
	# the indexing.
	#
	# As a side note, so far the use of `nelem' seems to have escaped the
	# above problem for a reason I do not know. However, taking minimum and
	# maximum and stringification may cause problems. It seems I cannot
	# prevent min() and max() from throwing, even when made conditional
	# with isempty() :-(
	my $n = $iter->want->nelem;
	my ( $min, $max ) = ( '-' x 10, '-' x 10 );
	if( $n ) {
		$min = eval { sprintf '%10.4f', $iter->selection->min } // $min;
		$max = eval { sprintf '%10.4f', $iter->selection->max } // $min;
	}
	note "bin (",
	     join( ',', map { sprintf "%3d", $_ } @_ ),
	     sprintf( "): #elements = %6s, ", $n // '<UNDEF>' ),
	     "range = ($min,$max), elements in bin: ",
	     eval { sprintf '%s', $iter->selection } // '<N/A>';
	return $n;
}

# create a pdl filled with bad values, of the type and length specified
sub create_bad
{
	my ( $type, $n ) = @_;
	zeroes( $type, $n )->inplace->setvaltobad( 0 )
}

# variable declarations
my ( $expected, $got, $x, $y, $z, $arg );

#
# SUPPORT STUFF
#
note 'SUPPORT STUFF';

# axis processing
$x = pdl( -65,13,31,69 );
$y = pdl( 3,30,41,-66.9 );
$expected = [ { min => -65, max => 69, n => 4, step => 33.5 } ];
$got = [ process_axes $x ];
is_deeply_without_pdl( $got, $expected, 'process_axes with auto parameters' );
$expected = [ { min => -70, max => 70, n => 7, step => 20 } ];
$got = [ process_axes $x, -70, 70, 20 ];
is_deeply_without_pdl( $got, $expected, 'process_axes with manual parameters' );
$expected = [ { min => -70, max => 70, n => 7, step => 20, round => 10 },
	      { min => -70, max => 50, n => 6, step => 20, round => 10 } ];
$got = [ process_axes $x => { round => 10, step => 20 },
		      $y => { round => 10, step => 20 } ];
is_deeply_without_pdl( $got, $expected, 'process_axes with two axes and rounding' );
$arg = [ process_axes $x ];
is_deeply_without_pdl( $arg, [ process_axes( $arg ) ], 'process_axes is idempotent' );
$arg = [ process_axes $x->long ];
is_deeply_without_pdl( $arg, [ process_axes( $arg ) ], 'process_axes is idempotent, integral data' );

# labels
$expected = [ [ { range => [0,4] }, { range => [4,8] }, { range => [8,12] } ] ];
$got = [ make_labels pdl(), 0, 12, 4 ];
is_deeply( $got, $expected, 'make_labels with one axis, range 0..12, step = 4' );
$expected = [ [ { range => [0,7]  },  { range => [7,14] } ],
	      [ { range => [0,11]  }, { range => [11,22] }, { range => [22,33] } ] ];
$got = [ make_labels pdl( 0,14 ), { n => 2 }, pdl( 0,33 ), { n => 3 } ];
is_deeply( $got, $expected, 'make_labels with two axes, range 0..14 x 0..33, n = 2 x 3' );
$expected = [ [ { range => [-3,-2] }, { range => [-1,0] }, { range => [1,2] } ] ];
$got = [ make_labels short( -3,2 ), { n => 3 } ];
is_deeply( $got, $expected, 'make_labels with one axis, integral data, range -3..2, n = 3' );
$expected = [ [ { range => [-3,0] }, { range => [1,3] } ] ];
$got = [ make_labels short( -3,3 ), { n => 2 } ];
is_deeply( $got, $expected, 'make_labels with one axis, integral data, range -3..3, n = 2' );
$expected = [ [ { range => [-3,-1] }, { range => [0,1] }, { range => [2,3] } ] ];
$got = [ make_labels short( -3,3 ), { n => 3 } ];
is_deeply( $got, $expected, 'make_labels with one axis, integral data, range -3..3, n = 3' );
$expected = [ [ { range => 1 }, { range => 2 }, { range => 3 }, { range => 4 } ] ];
$got = [ make_labels short( 1,2,3,4 ), { step => 1 } ];
is_deeply( $got, $expected, 'make_labels with one axis, integral data, range 1..4, step = 1' );

#
# LOW-LEVEL INTERFACE
#
note 'LOW-LEVEL INTERFACE';

# test argument parsing
lives_ok { ndbinning( null, 0, 0, 1 ) } 'correct arguments: one axis';
lives_ok { ndbinning( null, 0, 0, 1, null, 0, 0, 1 ) } 'correct arguments: two axes';
lives_ok { ndbinning( null, 0, 0, 1, null, 0, 0, 1, null, 0, 0, 1 ) } 'correct arguments: three axes';
lives_ok { ndbinning( null, 0, 0, 1, null, 0, 0, 1, null, 0, 0, 1, sub {}, null, sub {} ) } 'correct arguments: three axes, one variable, one action';
lives_ok { ndbinning( null, 0, 0, 1, null, 0, 0, 1, null, 0, 0, 1, sub {}, null, sub {}, null, sub {} ) } 'correct arguments: three axes, two variables, two actions';
lives_ok { ndbinning( null, 0, 0, 1, null, 0, 0, 1, null, 0, 0, 1, sub {}, null, sub {}, null, sub {}, null, sub {} ) } 'correct arguments: three axes, three variables, three actions';
dies_ok { ndbinning() } 'no arguments';
dies_ok { ndbinning( 0 ) } 'wrong arguments: 0';
dies_ok { ndbinning( null ) } 'wrong arguments: null';
dies_ok { ndbinning( null, 0 ) } 'wrong arguments: null, 0';
dies_ok { ndbinning( null, 0, 0 ) } 'wrong arguments: null, 0, 0';
dies_ok { ndbinning( null, 0, 0, null ) } 'wrong arguments: null, 0, 0, null';
dies_ok { ndbinning( null, 0, 0, 1, null ) } 'wrong arguments: null, 0, 0, 1, null';
dies_ok { ndbinning( null, 0, 0, 1, null, 0 ) } 'wrong arguments: null, 0, 0, 1, null, 0';

# the example from PDL::histogram
$x = pdl( 1,1,2 );
# by default I<histogram> returns a piddle of the same type as the axis,
# but I<ndbinning> returns a piddle of type I<long> when histogramming
$expected = long( 0,2,1 );
$got = ndbinning( $x, 1, 0, 3 );
is_pdl( $got, $expected, 'example from PDL::histogram' );
$got = ndbinning( $x, 1, 0, 3,
		  \&PDL::NDBin::default_loop,
		  zeroes( long, $x->nelem ), sub { shift->want->nelem } );
is_pdl( $got, $expected, 'variable and action specified explicitly' );
$expected = pdl( 0,2,1 );	# this is an exception, because the type is
				# locked to double by `$x => sub { ... }'
$got = ndbinning( $x => ( 1, 0, 3 ),
		  \&PDL::NDBin::default_loop,
		  $x => sub { shift->want->nelem } );
is_pdl( $got, $expected, 'different syntax' );
$expected = long( 0,2,1 );
$got = ndbinning( $x => ( 1, 0, 3 ),
		  \&PDL::NDBin::fast_loop,
		  $x => 'Count' );
is_pdl( $got, $expected, 'different syntax, using fast loop' );

# the example from PDL::histogram2d
$x = pdl( 1,1,1,2,2 );
$y = pdl( 2,1,1,1,1 );
$expected = long( [0,0,0],
		  [0,2,2],
		  [0,1,0] );
$got = ndbinning( $x => (1,0,3),
	          $y => (1,0,3) );
is_pdl( $got, $expected, 'example from PDL::histogram2d' );

#
$x = pdl( 1,1,1,2,2,1,1 );
$y = pdl( 2,1,3,4,1,4,4 );
$expected = long( [1,1],
		  [1,0],
		  [1,0],
		  [2,1] );
$got = ndbinning( $x, 1, 1, 2,
		  $y, 1, 1, 4 );
is_pdl( $got, $expected, 'nonsquare two-dimensional histogram' );

# binning integer data
$x = byte(1,2,3,4);
$expected = long(1,1,1,1);
$got = ndbinning( $x => (1,1,4) );
is_pdl( $got, $expected, 'binning integer data: base case' );
$x = short( 0,-1,3,9,6,3,1,0,1,3,7,14,3,4,2,-6,99,3,2,3,3,3,3 ); # contains out-of-range data
$expected = short( 8,9,1,0,5 );
$got = ndbinning( $x => (1,2,5), \&PDL::NDBin::default_loop, $x => sub { shift->want->nelem } );
is_pdl( $got, $expected, 'binning integer data: step = 1' );
$expected = long( 18,1,1,1,2 );
$got = ndbinning( $x => (2,3,5) );
is_pdl( $got, $expected, 'binning integer data: step = 2' );

# more actions & missing/undefined/invalid stuff
$x = sequence 21;
$expected = double( 1,4,7,10,13,16,19 );
$got = ndbinning( $x, 3, 0, 7, \&PDL::NDBin::default_loop, $x, sub { shift->selection->avg } );
is_pdl( $got, $expected, 'variable with action = average' );
$got = ndbinning( $x, 3, 0, 7, \&PDL::NDBin::fast_loop, $x, 'Avg' );
is_pdl( $got, $expected, 'variable with action = average, using fast loop' );
$x = 5+sequence 3; # 5 6 7
$expected = double( 0,0,1,1,1 )->inplace->setvaltobad( 0 );
$got = ndbinning( $x, 1,3,5, \&PDL::NDBin::default_loop, $x, sub { shift->want->nelem || undef } );
is_pdl( $got, $expected, 'empty bins unset' ); # cannot be achieved with fast loop

#
# HIGH-LEVEL INTERFACE
#
note 'HIGH-LEVEL INTERFACE';

# test argument parsing
dies_ok { ndbin() } 'no arguments';
dies_ok { ndbin( null ) } 'wrong arguments: null';
lives_ok { ndbin( pdl( 1,2 ) ) } 'correct arguments: one axis without parameters';
lives_ok { ndbin( null, '9.', 11, 1 ) } 'correct arguments: one axis with parameters';
dies_ok { ndbin( null, '9.', 11, 1, 3 ) } 'wrong arguments: one axis + extra parameter';
TODO: {
	local $TODO = 'yet to implement slash syntax';
	lives_ok { ndbin( null, '9./11' ) } 'correct arguments: one axis, slash syntax, two args';
	lives_ok { ndbin( null, '9./11/1' ) } 'correct arguments: one axis, slash syntax, three args';
}
TODO: {
	local $TODO = 'yet to implement colon syntax';
	lives_ok { ndbin( null, '9:1' ) } 'correct arguments: one axis, colon syntax, two args';
	lives_ok { ndbin( null, '9:1:11' ) } 'correct arguments: one axis, colon syntax, three args';
}
lives_ok { ndbin( AXES => pdl( 1,2 ) ) } 'keyword AXES';
lives_ok { ndbin( pdl( 1,2 ), VARS => pdl( 3,4 ) ) } 'keyword VALS';
lives_ok { ndbin( pdl( 1,2 ), DEFAULT_ACTION => sub {} ) } 'keyword DEFAULT_ACTION';
lives_ok { ndbin( pdl( 1,2 ), SKIP_EMPTY => 0 ) } 'keyword SKIP_EMPTY';
lives_ok { ndbin( pdl( 1,2 ), INDEXER => 0 ) } 'keyword INDEXER';
dies_ok  { ndbin( pdl( 1,2 ), INVALID_KEY => 3 ) } 'invalid keys are detected and reported';

# the example from PDL::hist
$x = pdl( 13,10,13,10,9,13,9,12,11,10,10,13,7,6,8,10,11,7,12,9,11,11,12,6,12,7 );
$expected = long( 0,0,0,0,0,0,2,3,1,3,5,4,4,4,0,0,0,0,0,0 );
$got = ndbin( $x, 0, 20, 1 );
is_pdl( $got, $expected, 'example from PDL::hist' );

# test variables and actions
$x = pdl( 13,10,13,10,9,13,9,12,11,10,10,13,7,6,8,10,11,7,12,9,11,11,12,6,12,7 );
$expected = double( 0,0,0,0,0,0,2,3,1,3,5,4,4,4,0,0,0,0,0,0 );
$got = ndbin( $x, 0,20,1, VARS => $x );
is_pdl( $got, $expected, 'variable with default action' );
$expected = pdl( 0,0,0,0,0,0,6,7,8,9,10,11,12,13,0,0,0,0,0,0 )->inplace->setvaltobad( 0 );
$got = ndbin( $x, 0,20,1, VARS => [ $x => sub { my $iter = shift; $iter->want->nelem ? $iter->selection->avg : undef } ], INDEXER => 1 );
is_pdl( $got, $expected, 'variable with action = average, default loop' );
$got = ndbin( $x, 0,20,1, VARS => [ $x => 'Avg' ], INDEXER => 0 );
is_pdl( $got, $expected, 'variable with action = average, fast loop' );
$x = pdl( 1,1,1,2,2,1,1,1,2 );
$y = pdl( 2,1,3,4,1,4,4,4,1 );
$z = pdl( 0,1,2,3,4,5,6,7,8 );
$expected = pdl( [1,2],
		 [1,0],
		 [1,0],
		 [3,1] );
$got = ndbin( $x, { step=>1, min=>1, n=>2 },
	      $y, { step=>1, min=>1, n=>4 },
	      VARS => [ $z => \&debug_action ],
	      SKIP_EMPTY => 0 );
is_pdl( $got, $expected, 'variable with action = debug_action' );
$got = ndbin( AXES => [ { pdl => $x, step=>1, min=>1, n=>2 },
			{ pdl => $y, step=>1, min=>1, n=>4 } ],
	      VARS => [ { pdl => PDL::null->double, action => \&debug_action } ],
	      SKIP_EMPTY => 0 );
is_pdl( $got, $expected, 'variable with action = debug_action, null PDL, and full spec' );

# binning integer data
$x = short( 1,2,3,4 );
$expected = long( 1,1,1,1 ); # by default ndbin chooses n(bins)=n(data el.) if n(data el.) < 100
$got = ndbin( $x );
is_pdl( $got, $expected, 'binning integer data: range = 1..4, auto parameters' );
$x = short( 1,2,3,4,5,6,7,8 );
$expected = long( 2,2,2,2 );
$got = ndbin( $x, { step => 2 } );
is_pdl( $got, $expected, 'binning integer data: range = 1..4, step = 2' );
$got = ndbin( $x, { n => 4 } );
is_pdl( $got, $expected, 'binning integer data: range = 1..4, n = 4' );
$x = short( -3,-2,-1,0,1,2 );
$expected = long( 2,2,2 );
$got = ndbin( $x => { n => 3 } );
is_pdl( $got, $expected, 'binning integer data: range = -3..2, n = 3' );
$x = short( -3,-2,-1,0,1,2,3 );
$expected = long( 4,3 );
$got = ndbin( $x => { n => 2 } );
is_pdl( $got, $expected, 'binning integer data: range = -3..3, n = 2' );
$x = short( -3,-2,-1,0,1,2,3 );
$expected = long( 3,2,2 );
$got = ndbin( $x => { n => 3 } );
is_pdl( $got, $expected, 'binning integer data: range = -3..3, n = 3' );
$x = short( 3,4,5,6,7,8,9,10,11 );
$expected = long( [9] );
$got = ndbin( $x, { step => 10 } );
is_pdl( $got, $expected, 'binning integer data: range = 3..11, step = 10' );
$got = ndbin( $x, { n => 1 } );
is_pdl( $got, $expected, 'binning integer data: range = 3..11, n = 1' );
$x = short( 3,4,5,6,7,8,9,10,11,12 );
$expected = long( [10] );
$got = ndbin( $x, { step => 10 } );
is_pdl( $got, $expected, 'binning integer data: range = 3..12, step = 10' );
$got = ndbin( $x, { n => 1 } );
is_pdl( $got, $expected, 'binning integer data: range = 3..12, n = 1' );
$expected = long( 5,5 );
$got = ndbin( $x, { n => 2 } );
is_pdl( $got, $expected, 'binning integer data: range = 3..12, n = 2' );
$x = short( 3,4,5,6,7,8,9,10,11,12,13 );
$expected = long( 10,1 );
$got = ndbin( $x, { step => 10 } );
is_pdl( $got, $expected, 'binning integer data: range = 3..13, step = 10' );
$expected = long( 6,5 );
$got = ndbin( $x, { n => 2 } );
is_pdl( $got, $expected, 'binning integer data: range = 3..13, n = 2' );

# test with weird data
dies_ok { ndbin( pdl( 3,3,3 ) ) } 'data range = 0';
$expected = long( [3] );
$got = ndbin( short( 1,1,1 ), { n => 1 } );
is_pdl( $got, $expected, 'data range = 0 BUT integral data and n = 1 (corner case)' );
dies_ok { ndbin( short( 1,2 ), { n => 4 } ) } 'invalid data: step size < 1 for integral data';

# test exceptions in actions
$x = pdl( 1,2,3 );
$expected = create_bad long, 3;
lives_ok { $got = ndbin( $x, DEFAULT_ACTION => sub { die } ) } 'exceptions in actions caught properly ...';
is_pdl( $got, $expected, '... and all values are unset' );

# test action arguments
$x = pdl( 1,3,3 );
$y = pdl( 1,3,3 );
$z = pdl( 9,0,1 );
$expected = zeroes(2,3,4)->long + 1;
$got = ndbin( $x => { n => 2 },
	      $y => { n => 3 },
	      $z => { n => 4 },
	      DEFAULT_ACTION => sub { @_ } );
is_pdl( $got, $expected, 'number of arguments for actions' );

# test unhashed bin numbers
$x = sequence 10;
$y = sequence 10;
$z = sequence 10;
$expected = sequence( 2*5*3 )->long->reshape( 2, 5, 3 );
$got = ndbin( $x => { n => 2 },
	      $y => { n => 5 },
	      $z => { n => 3 },
	      DEFAULT_ACTION => sub { my @u = shift->unhash; $u[0] + 2*$u[1] + 2*5*$u[2] } );
is_pdl( $got, $expected, 'bin numbers returned from iterator' );

# test SKIP_EMPTY
$x = pdl( 1,3,3 );		# 3 bins, but middle bin will be empty
$expected = long( 1,0,2 );
$got = ndbin( $x, SKIP_EMPTY => 0 );
is_pdl( $got, $expected, 'SKIP_EMPTY = 0' );
$expected->inplace->setvaltobad( 0 );
$got = ndbin( $x, SKIP_EMPTY => 1 );
is_pdl( $got, $expected, 'SKIP_EMPTY = 1' );

# cross-check with hist and some random data
$x = pdl( 0.7143, 0.6786, 0.9214, 0.5065, 0.9963, 0.9703, 0.1574, 0.4718,
	0.4099, 0.7701, 0.1881, 0.9412, 0.0034, 0.4440, 0.9423, 0.2065, 0.9656,
	0.5672, 0.2300, 0.5300, 0.1842 );
$y = pdl( 0.7422, 0.0299, 0.6629, 0.9118, 0.1224, 0.6173, 0.9203, 0.9999,
	0.1480, 0.4297, 0.5000, 0.9637, 0.1148, 0.2922, 0.0846, 0.0954, 0.1379,
	0.3187, 0.1655, 0.5777, 0.3047 );
$expected = hist( $x )->long;		# reference values computed by PDL's built-in `hist'
$got = ndbin( $x );
is_pdl( $got, $expected, 'cross-check $x with hist' );
$expected = hist( $y )->long;
$got = ndbin( $y );
is_pdl( $got, $expected, 'cross-check $y with hist' );
$expected = hist( $x, 0, 1, 0.1 )->long;
$got = ndbin( $x, 0, 1, 0.1 );
is_pdl( $got, $expected, 'cross-check $x with hist, with (min,max,step) supplied' );
$expected = hist( $y, 0, 1, 0.1 )->long;
$got = ndbin( $y, 0, 1, 0.1 );
TODO: {
	local $TODO = 'fails on 32-bit';
	is_pdl( $got, $expected, 'cross-check $y with hist, with (min,max,step) supplied' );
}
$expected = histogram( $x, .1, 0, 10 )->long;
$got = ndbin( $x, { step => .1, min => 0, n => 10 } );
is_pdl( $got, $expected, 'cross-check $x with histogram' );
$expected = histogram( $y, .1, 0, 10 )->long;
$got = ndbin( $y, { step => .1, min => 0, n => 10 } );
TODO: {
	local $TODO = 'fails on 32-bit';
	is_pdl( $got, $expected, 'cross-check $y with histogram' );
}
$expected = histogram2d( $x, $y, .1, 0, 10, .1, 0, 10 )->long;
$got = ndbin( $x, { step => .1, min => 0, n => 10 },
	      $y, { step => .1, min => 0, n => 10 } );
TODO: {
	local $TODO = 'fails on 32-bit';
	is_pdl( $got, $expected, 'cross-check with histogram2d' );
}
