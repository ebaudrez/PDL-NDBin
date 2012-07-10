# multidimensional binning & histogramming - tests

use strict;
use warnings;
use Test::More tests => 31;
use Test::PDL;
use Test::Exception;
use Test::NoWarnings;

BEGIN {
	use_ok( 'PDL' ) or BAIL_OUT( 'Could not load PDL' );
	use_ok( 'PDL::NDBin::Func' );
}

sub apply
{
	my ( $x, $y, $N, $f ) = @_;
	my $pdl = zeroes $N;
	for my $bin ( 0 .. $N-1 ) {
		my $want = which $y == $bin;
		$pdl->set( $bin, $f->( $x->index($want) ) );
	}
	$pdl;
}

# variable declarations
my ( $expected, $got, $N, $x, $y, @u, @v, $obj );

#
# OUTPUT PIDDLE RETURN TYPE
#
note 'OUTPUT PIDDLE RETURN TYPE';

#
$N = 4;
@u = ( 4,5,6,7,8,9 );	# data values
@v = ( 0,0,0,1,3,0 );	# bin numbers
$x = pdl( @u );
$y = long( @v );

# 
note '   function = PDL::NDBin::Func::icount';
$expected = long( 4,1,0,1 );
$got = PDL::NDBin::Func::icount( $x, $y, $N );
is_pdl( $got, $expected, "output piddle set by return value" );

# 
note '   function = PDL::NDBin::Func::isum';
$expected = long( 24,7,-1,8 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::isum( $x, $y, $N );
is_pdl( $got, $expected->double, "output piddle set by return value" );

#
note '   function = PDL::NDBin::Func::iavg';
$expected = long( 6,7,-1,8 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::iavg( $x, $y, $N );
is_pdl( $got, $expected->double, "output piddle set by return value" );

#
note '   function = PDL::NDBin::Func::istddev';
$expected = pdl( sqrt(3.5),0,-1,0 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::istddev( $x, $y, $N );
is_pdl( $got, $expected->double, "output piddle set by return value" );

#
# FUNCTIONALITY
#
note 'FUNCTIONALITY';

#
$N = 4;
@u = ( 4,5,6,7,8,9 );	# data values
@v = ( 0,0,0,1,3,0 );	# bin numbers
$x = short( @u );
$y = long( @v );

# PDL::NDBin::Func::icount
$expected = long( 4,1,0,1 );
$got = PDL::NDBin::Func::icount( $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::icount, input type short" );
$got = PDL::NDBin::Func::icount( $x->float, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::icount, input type float" );

# PDL::NDBin::Func::isum
$expected = long( 24,7,-1,8 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::isum( $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::isum, input type short" );
$got = PDL::NDBin::Func::isum( $x->float, $y, $N );
is_pdl( $got, $expected->float, "PDL::NDBin::Func::isum, input type float" );

# PDL::NDBin::Func::iavg
$expected = pdl( 6,7,-1,8 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::iavg( $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::iavg, input type short" );
$got = PDL::NDBin::Func::iavg( $x->float, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::iavg, input type float" );
$got = PDL::NDBin::Func::iavg( $x->double, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::iavg, input type double" );

# PDL::NDBin::Func::istddev
$expected = pdl( sqrt(3.5),0,-1,0 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::istddev( $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::istddev, input type short" );
$got = PDL::NDBin::Func::istddev( $x->float, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::istddev, input type float" );
$got = PDL::NDBin::Func::istddev( $x->double, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::istddev, input type double" );

#
#
#
note 'BAD VALUE FUNCTIONALITY';

#
$N = 4;
@u = ( 4,5,-1,7,8,9 );	# data values
@v = ( 0,0, 0,1,3,0 );	# bin numbers
$x = short( @u )->inplace->setvaltobad( -1 );
$y = long( @v );

# PDL::NDBin::Func::icount
$expected = long( 3,1,0,1 );
$got = PDL::NDBin::Func::icount( $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::icount with bad values, input type short" );
$got = PDL::NDBin::Func::icount( $x->float, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::icount with bad values, input type float" );

# PDL::NDBin::Func::isum
$expected = long( 18,7,-1,8 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::isum( $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::isum with bad values, input type short" );
$got = PDL::NDBin::Func::isum( $x->float, $y, $N );
is_pdl( $got, $expected->float, "PDL::NDBin::Func::isum with bad values, input type float" );

# PDL::NDBin::Func::iavg
$expected = pdl( 6,7,-1,8 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::iavg( $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::iavg with bad values, input type short" );
$got = PDL::NDBin::Func::iavg( $x->float, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::iavg with bad values, input type float" );
$got = PDL::NDBin::Func::iavg( $x->double, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::iavg with bad values, input type double" );

# PDL::NDBin::Func::istddev
$expected = pdl( sqrt(14/3),0,-1,0 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::istddev( $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::istddev with bad values, input type short" );
$got = PDL::NDBin::Func::istddev( $x->float, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::istddev with bad values, input type float" );
$got = PDL::NDBin::Func::istddev( $x->double, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::istddev with bad values, input type double" );

#
#
#
note 'CONCATENATION';

#
$N = 4;
$obj = PDL::NDBin::Func::ICount->new( $N );

#
@u = ( 4,5,6,7,8,9 );	# data values
@v = ( 0,0,0,1,3,0 );	# bin numbers
$obj->process( pdl(@u), long(@v) );

#
@u = ( 3,2,1,0,-1,-2 );	# data values
@v = ( 3,3,1,1, 3, 0 );	# bin numbers
$obj->process( pdl(@u), long(@v) );

#
$expected = long( 5,3,0,4 );
$got = $obj->result;
is_pdl( $got, $expected, "PDL::NDBin::Func::ICount by concatenation" );

# TODO test other functions with concatenation

#
#
#
note 'CROSS-CHECK';

#
$N = 10;
@u = ( 0.380335783193917, 0.431569737239869, 0.988228581651253,
	0.369529166348862, 0.015659808076709, 0.0128772388998044,
	0.574823006425813, 0.307950317667824, 0.203820671877484,
	0.689137032780081, 0.196232563366532, 0.673725380087014,
	0.338351708168364, 0.618128376628889, 0.0686126943478449,
	0.467397968837865, 0.24772883995394, 0.908459824625453,
	0.385466358455641, 0.694874773806994, 0.890462725956144,
	0.654082910438362, 0.455010756187814, 0.477250284962928,
	0.701090630071324, 0.357419784470324, 0.454056307535307,
	0.410569424644144, 0.660074882361915, 0.780762636481384,
	0.861702069810971, 0.363648213432661, 0.293263267962747,
	0.0660826236986338, 0.144319047939245, 0.180976557519053,
	0.0723328240807923, 0.242442573592697, 0.530066073796629,
	0.443430523052676, 0.638280157347285, 0.639442502229826,
	0.171132424601108, 0.400188119465021, 0.0354213266424388,
	0.901766545993169, 0.782722425788162, 0.929661711654482,
	0.681530382655584, 0.176795809007814, 0.060310253781676,
	0.31484578272751, 0.146810627367376, 0.0628804433014665,
	0.10484333107004, 0.269269937203966, 0.334614366845788,
	0.264327566086138, 0.476430402530905, 0.954407831713674,
	0.292588191733945, 0.820185941055982, 0.800810910512549,
	0.259212208736521, 0.404729444075432, 0.742845270762444,
	0.47288595927547, 0.829338451370127, 0.971328329171531,
	0.92029402745014, 0.544243289524811, 0.840123135946975,
	0.351696919494916, 0.969196552715403, 0.406499583422413,
	0.29666399706705, 0.67883388679569, 0.156984244484207,
	0.152108402156724, 0.350192598762412, 0.238750000928182,
	0.587758585597186, 0.22486143436954, 0.266754888566773,
	0.60121706210079, 0.132452114236727, 0.0825898169904598,
	0.937056760726044, 0.482459799706223, 0.407488755034649,
	0.456621392813172, 0.230855833154955, 0.681169188125796,
	0.812853783458721, 0.481564203962133, 0.771775912520233,
	0.652684410419059, 0.840377647492318, 0.513286599743889,
	0.425801145512487 ); # 100 random values
@v = ( 6, 7, 3, 3, 7, 1, 8, 3, 2, 0, 6, 0, 5, 3, 3, 8, 7, 2, 7, 9, 2, 7, 4, 6,
	0, 6, 3, 1, 5, 2, 4, 5, 8, 3, 8, 7, 8, 1, 4, 9, 4, 6, 3, 1, 4, 0, 4, 4,
	0, 3, 8, 6, 0, 3, 4, 8, 0, 7, 3, 9, 3, 2, 3, 7, 6, 9, 0, 9, 2, 3, 3, 0,
	3, 5, 3, 6, 0, 1, 8, 1, 5, 4, 1, 7, 4, 7, 1, 9, 8, 7, 8, 1, 1, 8, 5, 1,
	3, 6, 4, 4 ); # 100 random bins
$x = pdl( @u );
$x = $x->setbadif( $x < .5 );
$y = long( @v );

#
$expected = apply( $x, $y, $N, \&sum );
$got = PDL::NDBin::Func::isum( $x, $y, $N );
is_pdl( $got, $expected, "cross-check PDL::NDBin::Func::isum with sum()" );
$expected = apply( $x, $y, $N, sub { ($_[0]->stats)[0] } );
$got = PDL::NDBin::Func::iavg( $x, $y, $N );
is_pdl( $got, $expected, "cross-check PDL::NDBin::Func::iavg with stats()" );
# the docs of `stats' are actually wrong on this one:
# the population rms is in [1], and the rms is in [6]
$expected = apply( $x, $y, $N, sub { ($_[0]->stats)[6] } );
$got = PDL::NDBin::Func::istddev( $x, $y, $N );
is_pdl( $got, $expected, "cross-check PDL::NDBin::Func::istddev with stats()" );
