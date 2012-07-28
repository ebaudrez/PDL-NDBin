# multidimensional binning & histogramming - tests

use strict;
use warnings;
use Test::More tests => 73;
use Test::PDL;
use Test::Exception;
use Test::NoWarnings;

BEGIN {
	use_ok( 'PDL' ) or BAIL_OUT( 'Could not load PDL' );
	use_ok( 'PDL::NDBin::Func' );
	use_ok( 'PDL::NDBin::Iterator' );
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

# create a temporary iterator with the given arguments
sub iter
{
	my( $var, $hash, $N ) = @_;
	PDL::NDBin::Iterator->new( [ $N ], [ $var ], $hash );
}

# variable declarations
my ( $expected, $got, $N, $x, $y, @u, @v, $obj );

#
#
#
note 'SETUP';
{
	my %plugins = map { $_ => 1 } PDL::NDBin::Func->plugins;
	note 'registered plugins: ', join ', ' => keys %plugins;
	for my $p ( qw(	PDL::NDBin::Func::ICount  PDL::NDBin::Func::ISum
			PDL::NDBin::Func::IAvg    PDL::NDBin::Func::IStdDev ) )
	{
		ok( $plugins{ $p }, "$p is there" );
		delete $plugins{ $p };
	}
	ok( ! %plugins, 'no more unknown plugins left' ) or diag 'remaining plugins: ', join ', ' => keys %plugins;
}

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
cmp_ok( PDL::NDBin::Func::icount( iter $x->byte, $y, $N )->type, '==', long, 'return type is long for input type byte' );
cmp_ok( PDL::NDBin::Func::icount( iter $x->short, $y, $N )->type, '==', long, 'return type is long for input type short' );
cmp_ok( PDL::NDBin::Func::icount( iter $x->ushort, $y, $N )->type, '==', long, 'return type is long for input type ushort' );
cmp_ok( PDL::NDBin::Func::icount( iter $x->long, $y, $N )->type, '==', long, 'return type is long for input type long' );
cmp_ok( PDL::NDBin::Func::icount( iter $x->longlong, $y, $N )->type, '==', long, 'return type is long for input type longlong' );
cmp_ok( PDL::NDBin::Func::icount( iter $x->float, $y, $N )->type, '==', long, 'return type is long for input type float' );
cmp_ok( PDL::NDBin::Func::icount( iter $x->double, $y, $N )->type, '==', long, 'return type is long for input type double' );

#
note '   function = PDL::NDBin::Func::isum';
cmp_ok( PDL::NDBin::Func::isum( iter $x->byte, $y, $N )->type, '==', long, 'return type is long for input type byte' );
cmp_ok( PDL::NDBin::Func::isum( iter $x->short, $y, $N )->type, '==', long, 'return type is long for input type short' );
cmp_ok( PDL::NDBin::Func::isum( iter $x->ushort, $y, $N )->type, '==', long, 'return type is long for input type ushort' );
cmp_ok( PDL::NDBin::Func::isum( iter $x->long, $y, $N )->type, '==', long, 'return type is long for input type long' );
cmp_ok( PDL::NDBin::Func::isum( iter $x->longlong, $y, $N )->type, '==', longlong, 'return type is longlong for input type longlong' );
cmp_ok( PDL::NDBin::Func::isum( iter $x->float, $y, $N )->type, '==', float, 'return type is float for input type float' );
cmp_ok( PDL::NDBin::Func::isum( iter $x->double, $y, $N )->type, '==', double, 'return type is double for input type double' );

#
note '   function = PDL::NDBin::Func::iavg';
cmp_ok( PDL::NDBin::Func::iavg( iter $x->byte, $y, $N )->type, '==', double, 'return type is double for input type byte' );
cmp_ok( PDL::NDBin::Func::iavg( iter $x->short, $y, $N )->type, '==', double, 'return type is double for input type short' );
cmp_ok( PDL::NDBin::Func::iavg( iter $x->ushort, $y, $N )->type, '==', double, 'return type is double for input type ushort' );
cmp_ok( PDL::NDBin::Func::iavg( iter $x->long, $y, $N )->type, '==', double, 'return type is double for input type long' );
cmp_ok( PDL::NDBin::Func::iavg( iter $x->longlong, $y, $N )->type, '==', double, 'return type is double for input type longlong' );
cmp_ok( PDL::NDBin::Func::iavg( iter $x->float, $y, $N )->type, '==', double, 'return type is double for input type float' );
cmp_ok( PDL::NDBin::Func::iavg( iter $x->double, $y, $N )->type, '==', double, 'return type is double for input type double' );

#
note '   function = PDL::NDBin::Func::istddev';
cmp_ok( PDL::NDBin::Func::istddev( iter $x->byte, $y, $N )->type, '==', double, 'return type is double for input type byte' );
cmp_ok( PDL::NDBin::Func::istddev( iter $x->short, $y, $N )->type, '==', double, 'return type is double for input type short' );
cmp_ok( PDL::NDBin::Func::istddev( iter $x->ushort, $y, $N )->type, '==', double, 'return type is double for input type ushort' );
cmp_ok( PDL::NDBin::Func::istddev( iter $x->long, $y, $N )->type, '==', double, 'return type is double for input type long' );
cmp_ok( PDL::NDBin::Func::istddev( iter $x->longlong, $y, $N )->type, '==', double, 'return type is double for input type longlong' );
cmp_ok( PDL::NDBin::Func::istddev( iter $x->float, $y, $N )->type, '==', double, 'return type is double for input type float' );
cmp_ok( PDL::NDBin::Func::istddev( iter $x->double, $y, $N )->type, '==', double, 'return type is double for input type double' );

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
$got = PDL::NDBin::Func::icount( iter $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::icount, input type short" );
$got = PDL::NDBin::Func::icount( iter $x->float, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::icount, input type float" );

# PDL::NDBin::Func::isum
$expected = long( 24,7,-1,8 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::isum( iter $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::isum, input type short" );
$got = PDL::NDBin::Func::isum( iter $x->float, $y, $N );
is_pdl( $got, $expected->float, "PDL::NDBin::Func::isum, input type float" );

# PDL::NDBin::Func::iavg
$expected = pdl( 6,7,-1,8 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::iavg( iter $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::iavg, input type short" );
$got = PDL::NDBin::Func::iavg( iter $x->float, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::iavg, input type float" );
$got = PDL::NDBin::Func::iavg( iter $x->double, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::iavg, input type double" );

# PDL::NDBin::Func::istddev
$expected = pdl( sqrt(3.5),0,-1,0 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::istddev( iter $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::istddev, input type short" );
$got = PDL::NDBin::Func::istddev( iter $x->float, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::istddev, input type float" );
$got = PDL::NDBin::Func::istddev( iter $x->double, $y, $N );
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
$got = PDL::NDBin::Func::icount( iter $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::icount with bad values, input type short" );
$got = PDL::NDBin::Func::icount( iter $x->float, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::icount with bad values, input type float" );

# PDL::NDBin::Func::isum
$expected = long( 18,7,-1,8 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::isum( iter $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::isum with bad values, input type short" );
$got = PDL::NDBin::Func::isum( iter $x->float, $y, $N );
is_pdl( $got, $expected->float, "PDL::NDBin::Func::isum with bad values, input type float" );

# PDL::NDBin::Func::iavg
$expected = pdl( 6,7,-1,8 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::iavg( iter $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::iavg with bad values, input type short" );
$got = PDL::NDBin::Func::iavg( iter $x->float, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::iavg with bad values, input type float" );
$got = PDL::NDBin::Func::iavg( iter $x->double, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::iavg with bad values, input type double" );

# PDL::NDBin::Func::istddev
$expected = pdl( sqrt(14/3),0,-1,0 )->inplace->setvaltobad( -1 );
$got = PDL::NDBin::Func::istddev( iter $x, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::istddev with bad values, input type short" );
$got = PDL::NDBin::Func::istddev( iter $x->float, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::istddev with bad values, input type float" );
$got = PDL::NDBin::Func::istddev( iter $x->double, $y, $N );
is_pdl( $got, $expected, "PDL::NDBin::Func::istddev with bad values, input type double" );

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
$expected = apply( $x, $y, $N, \&ngood )->long;
$got = PDL::NDBin::Func::icount( iter $x, $y, $N );
is_pdl( $got, $expected, "cross-check PDL::NDBin::Func::icount with ngood()" );
$expected = apply( $x, $y, $N, \&sum );
$got = PDL::NDBin::Func::isum( iter $x, $y, $N );
is_pdl( $got, $expected, "cross-check PDL::NDBin::Func::isum with sum()" );
$expected = apply( $x, $y, $N, sub { ($_[0]->stats)[0] } );
$got = PDL::NDBin::Func::iavg( iter $x, $y, $N );
is_pdl( $got, $expected, "cross-check PDL::NDBin::Func::iavg with stats()" );
# the docs of `stats' are actually wrong on this one:
# the population rms is in [1], and the rms is in [6]
$expected = apply( $x, $y, $N, sub { ($_[0]->stats)[6] } );
$got = PDL::NDBin::Func::istddev( iter $x, $y, $N );
is_pdl( $got, $expected, "cross-check PDL::NDBin::Func::istddev with stats()" );

#
#
#
note 'CONCATENATION';
{
	my $u0 = pdl( -18.3183390661739, 27.3974706788376, 35.7153786154491,
		47.8258388108234, -35.1588200253218, 26.4152568315506 ); # 6 random values [-50:50]
	my $v0 = long( 4, 4, 8, 1, 5, 0 ); # 6 random bins [0:9]
	my $u1 = pdl( -49.573940365601, -5.71788528168433 ); # 2 random values [-50:50]
	my $v1 = long( 6, 5 ); # 2 random bins [0:9]
	my $u2 = pdl( 13.9010951470269, -26.6426081230296, -20.4758828884117,
		-47.0451825792392, 6.76251455434169, 25.0398394482954,
		-14.1263729818995, -34.3005011256633, 11.4501997177783,
		14.2397334136742 ); # 10 random values [-50:50]
	my $v2 = long( 8, 6, 5, 1, 2, 9, 9, 5, 9, 0 ); # 10 random bins [0:9]
	my $u3 = pdl( 29.4897695519602, -12.8522886035878, 46.9800168006543,
		47.5442131843106, -48.242720133063, -49.9047087352846 ); # 6 random values [-50:50]
	my $v3 = long( 4, 1, 4, 2, 0, 4 ); # 6 random bins [0:9]
	my $u4 = pdl( 33.9285663707713, -19.4440970026509, 25.3297021599046,
		8.22183510796357, -31.2812362886149, -22.397819555157,
		-33.5881440926578, -46.7164828941616, -16.4592034011449,
		-10.2272980921985, -25.3017491996424 ); # 11 random values [-50:50]
	my $v4 = long( 1, 0, 1, 5, 2, 0, 4, 0, 4, 2, 6 ); # 11 random bins [0:9]
	my $N = 35;
	my $u = $u0->append( $u1 )->append( $u2 )->append( $u3 )->append( $u4 );
	my $v = $v0->append( $v1 )->append( $v2 )->append( $v3 )->append( $v4 );
	cmp_ok( $N, '>', 0, 'there are values to test' ) or BAIL_OUT( 'test is corrupt' );
	ok( $u->nelem == $N && $v->nelem == $N, 'number of values is consistent' ) or BAIL_OUT( 'test is corrupt' );
	for my $class ( 'PDL::NDBin::Func::ICount',
			'PDL::NDBin::Func::ISum',
			'PDL::NDBin::Func::IAvg',
			'PDL::NDBin::Func::IStdDev' )
	{
		my $obj = $class->new( $N );
		$obj->process( iter $u0, $v0, $N );
		$obj->process( iter $u1, $v1, $N );
		$obj->process( iter $u2, $v2, $N );
		$obj->process( iter $u3, $v3, $N );
		$obj->process( iter $u4, $v4, $N );
		my $got = $obj->result;
		$obj = $class->new( $N );
		$obj->process( iter $u, $v, $N );
		my $expected = $obj->result;
		is_pdl( $got, $expected, "repeated invocation of $class equal to concatenation" );
	}
}

SKIP: {
	skip 'no bad value support', 6 unless $PDL::Bad::Status;
	my $u0 = pdl( -44.7319945183754, 2.14679136319411, -101,
		32.2078360467891, 2.42312479183653, 24.961636154341,
		16.7449041152423, -101, 15.135123983227, 18.8232267311516,
		-15.3718944013033, 17.2185903975429 )->inplace->setvaltobad( -101 ); # 12 random values [-50:50]
	my $v0 = long( 8, 0, 7, 5, 4, 9, 6, 1, 6, 7, 7, 5 ); # 12 random bins [0:9]
	my $u1 = pdl( -101, 22.876731972822, 22.0445472500778,
		-26.5999303520772, 27.1019424052675, -26.3532958054284, -101,
		-29.0518405732623, 23.9856347894982, -29.1397313934237,
		7.3252320197863, -27.4562734240643 )->inplace->setvaltobad( -101 ); # 12 random values [-50:50]
	my $v1 = long( 8, 1, 2, 6, 9, 5, 5, 7, 5, 4, 5, 2 ); # 12 random bins [0:9]
	my $u2 = pdl( 40.4673256586715, -101, -30.3275242788303, -101,
		39.7762903332339, -38.4575329560239, 1.74879500859113,
		-4.78760502460922 )->inplace->setvaltobad( -101 ); # 8 random values [-50:50]
	my $v2 = long( 7, 7, 3, 9, 7, 3, 2, 2 ); # 8 random bins [0:9]
	my $u3 = pdl( -28.3032696453798, -101, -39.0345665405043,
		30.4407977872174, -101, 20.1915655828689, -38.1173555823768,
		-38.3656423025752, -5.98602407355919, -31.3445025843915,
		2.0134617981693, -26.869783026164 )->inplace->setvaltobad( -101 ); # 12 random values [-50:50]
	my $v3 = long( 1, 8, 9, 6, 8, 8, 5, 2, 3, 6, 1, 4 ); # 12 random bins [0:9]
	my $u4 = pdl( 34.9733702362666, -101, -101, -101, 38.7278135049009,
		0.494848736214237, 25.3478221389223 )->inplace->setvaltobad( -101 ); # 7 random values [-50:50]
	my $v4 = long( 4, 1, 2, 3, 1, 5, 8 ); # 7 random bins [0:9]
	my $N = 51;
	my $u = $u0->append( $u1 )->append( $u2 )->append( $u3 )->append( $u4 );
	my $v = $v0->append( $v1 )->append( $v2 )->append( $v3 )->append( $v4 );
	cmp_ok( $N, '>', 0, 'there are values to test' ) or BAIL_OUT( 'test is corrupt' );
	ok( $u->nelem == $N && $v->nelem == $N, 'number of values is consistent' ) or BAIL_OUT( 'test is corrupt' );
	for my $class ( 'PDL::NDBin::Func::ICount',
			'PDL::NDBin::Func::ISum',
			'PDL::NDBin::Func::IAvg',
			'PDL::NDBin::Func::IStdDev' )
	{
		my $obj = $class->new( $N );
		$obj->process( iter $u0, $v0, $N );
		$obj->process( iter $u1, $v1, $N );
		$obj->process( iter $u2, $v2, $N );
		$obj->process( iter $u3, $v3, $N );
		$obj->process( iter $u4, $v4, $N );
		my $got = $obj->result;
		$obj = $class->new( $N );
		$obj->process( iter $u, $v, $N );
		my $expected = $obj->result;
		is_pdl( $got, $expected, "repeated invocation of $class equal to concatenation (bad values present)" );
	}
}
