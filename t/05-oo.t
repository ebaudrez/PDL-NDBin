# multidimensional binning & histogramming - tests of the object-oriented interface

use strict;
use warnings;
use Test::More tests => 85;
use Test::PDL;
use Test::Exception;
use Test::NoWarnings;
use Test::Deep;
use PDL;
use PDL::NDBin;
use List::Util qw( reduce );
use Module::Pluggable sub_name    => 'actions',
		      require     => 1,
		      search_path => [ 'PDL::NDBin::Action' ];

# variable declarations
my ( $expected, $got, $binner, $x, $y );
our ( $a, $b );

#
# SETUP
#
note 'SETUP';

# test argument parsing
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', step=>0, min=>0, n=>1 ] ] ) } 'correct arguments: one axis';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', step=>0, min=>0, n=>1 ],
				      [ 'dummy', step=>0, min=>0, n=>1 ] ] ) } 'correct arguments: two axes';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', step=>0, min=>0, n=>1 ],
				      [ 'dummy', step=>0, min=>0, n=>1 ],
				      [ 'dummy', step=>0, min=>0, n=>1 ] ] ) } 'correct arguments: three axes';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', step=>0, min=>0, n=>1 ],
				      [ 'dummy', step=>0, min=>0, n=>1 ],
				      [ 'dummy', step=>0, min=>0, n=>1 ] ],
			    vars => [ [ 'dummy', sub {} ] ] ) } 'correct arguments: three axes, one variable';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', step=>0, min=>0, n=>1 ],
				      [ 'dummy', step=>0, min=>0, n=>1 ],
				      [ 'dummy', step=>0, min=>0, n=>1 ] ],
			    vars => [ [ 'dummy', sub {} ],
				      [ 'dummy', sub {} ] ] ) } 'correct arguments: three axes, two variables';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', step=>0, min=>0, n=>1 ],
				      [ 'dummy', step=>0, min=>0, n=>1 ],
				      [ 'dummy', step=>0, min=>0, n=>1 ] ],
			    vars => [ [ 'dummy', sub {} ],
				      [ 'dummy', sub {} ],
				      [ 'dummy', sub {} ] ] ) } 'correct arguments: three axes, three variables';
dies_ok { PDL::NDBin->new() } 'no arguments';
dies_ok { PDL::NDBin->new( axes => [ [ 0 ] ] ) } 'no axis name';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy' ] ] ) } 'no specs';
dies_ok { PDL::NDBin->new( axes => [ [ 'dummy', 0 ] ] ) } 'wrong specs';
dies_ok { PDL::NDBin->new( axes => [ [ 'dummy', 0, 0, 1 ] ] ) } 'oldstyle specs';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', step=>0 ] ] ) } 'no full specs';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', min=>0 ] ] ) } 'no full specs';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', n=>0 ] ] ) } 'no full specs';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', step=>0, min=>0 ] ] ) } 'no full specs';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', step=>0, n=>0 ] ] ) } 'no full specs';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', min=>0, n=>0 ] ] ) } 'no full specs';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', step=>0, min=>0, n=>1 ],
				     [ 'dummy' ] ] ) } 'no full specs for second axis';
lives_ok { PDL::NDBin->new( axes => [ [ 'dummy', step=>0, min=>0, n=>1 ],
				     [ 'dummy', step=>0 ] ] ) } 'no full specs for second axis';
TODO: {
	local $TODO = 'needs to wait until full Params::Validate validation';
	dies_ok { PDL::NDBin->new( axes => [ [ 'dummy', unknown=>3 ] ] ) } 'unknown key in axis spec';
}

# return values
$binner = PDL::NDBin->new( axes => [ [ u => (step=>1,min=>0,n=>10) ] ] );
ok $binner, 'constructor returns a value';
isa_ok $binner, 'PDL::NDBin', 'return value from new()';
isa_ok $binner->process( u => sequence(10) ), 'PDL::NDBin', 'return value from process()';
isa_ok $binner->process( u => sequence(10) )->process( u => sequence(10) ), 'PDL::NDBin', 'return value from chained calls to process()';

# context
my $anon_sub = sub {};
$binner = PDL::NDBin->new( axes => [ [ u => (step=>1,min=>0,n=>10) ] ],
			   vars => [ [ v => $anon_sub ] ] );
$expected = [ { name => 'u', min => 0, n => 10, step => 1 } ];
$got = $binner->axes;
cmp_deeply $got, $expected, 'axes in scalar context';
$got = [ $binner->axes ];
cmp_deeply $got, $expected, 'axes in list context';
$expected = [ { name => 'v', action => $anon_sub } ];
$got = $binner->vars;
cmp_deeply $got, $expected, 'vars in scalar context';
$got = [ $binner->vars ];
cmp_deeply $got, $expected, 'vars in list context';

#
# SUPPORT STUFF
#
note 'SUPPORT STUFF';

# axis processing
$x = pdl( -65,13,31,69 );
$y = pdl( 3,30,41,-66.9 );
$expected = [ { name => ignore, pdl => ignore, min => -65, max => 69, n => 4, step => 33.5 } ];
$binner = PDL::NDBin->new( axes => [[ 'x' ]] );
$binner->autoscale( x => $x );
$got = $binner->axes;
is_pdl $got->[0]->{pdl}, $x;
cmp_deeply $got, $expected, 'autoscale() with auto parameters';
$expected = [ { name => ignore, pdl => ignore, min => -70, max => 70, n => 7, step => 20 } ];
$binner = PDL::NDBin->new( axes => [[ x => (min => -70, max => 70, step => 20) ]] );
$binner->autoscale( x => $x );
$got = $binner->axes;
is_pdl $got->[0]->{pdl}, $x;
cmp_deeply $got, $expected, 'autoscale() with manual parameters';
$expected = [ { name => ignore, pdl => ignore, min => -70, max => 70, n => 7, step => 20, round => 10 },
	      { name => ignore, pdl => ignore, min => -70, max => 50, n => 6, step => 20, round => 10 } ];
$binner = PDL::NDBin->new( axes => [[ x => ( round => 10, step => 20 ) ],
				    [ y => ( round => 10, step => 20 ) ]] );
$binner->autoscale( x => $x, y => $y );
$got = $binner->axes;
is_pdl $got->[0]->{pdl}, $x;
is_pdl $got->[1]->{pdl}, $y;
cmp_deeply $got, $expected, 'autoscale() with two axes and rounding';

# labels
$expected = [ [ { range => [0,4] }, { range => [4,8] }, { range => [8,12] } ] ];
$got = PDL::NDBin->new( axes => [[ x => (min=>0, max=>12, step=>4) ]] )->labels( x => pdl );
is_deeply $got, $expected, 'labels() with one axis, range 0..12, step = 4';
$expected = [ [ { range => [0,7]  },  { range => [7,14] } ],
	      [ { range => [0,11]  }, { range => [11,22] }, { range => [22,33] } ] ];
$got = PDL::NDBin->new( axes => [[ x => ( n => 2 ) ],
				 [ y => ( n => 3 ) ]] )->labels( x => pdl( 0,14 ), y => pdl( 0,33 ) );
is_deeply $got, $expected, 'labels() with two axes, range 0..14 x 0..33, n = 2 x 3';
$expected = [ [ { range => [-3,-2] }, { range => [-1,0] }, { range => [1,2] } ] ];
$got = PDL::NDBin->new( axes => [[ x => ( n => 3 ) ]] )->labels( x => short( -3,2 ) );
is_deeply $got, $expected, 'labels() with one axis, integral data, range -3..2, n = 3';
$expected = [ [ { range => [-3,0] }, { range => [1,3] } ] ];
$got = PDL::NDBin->new( axes => [[ x => ( n => 2 ) ]] )->labels( x => short( -3,3 ) );
is_deeply $got, $expected, 'labels() with one axis, integral data, range -3..3, n = 2';
$expected = [ [ { range => [-3,-1] }, { range => [0,1] }, { range => [2,3] } ] ];
$got = PDL::NDBin->new( axes => [[ x => ( n => 3 ) ]] )->labels( x => short( -3,3 ) );
is_deeply $got, $expected, 'labels() with one axis, integral data, range -3..3, n = 3';
$expected = [ [ { range => 1 }, { range => 2 }, { range => 3 }, { range => 4 } ] ];
$got = PDL::NDBin->new( axes => [[ x => ( step => 1 ) ]] )->labels( x => short( 1,2,3,4 ) );
is_deeply $got, $expected, 'labels() with one axis, integral data, range 1..4, step = 1';

#
# BASIC FUNCTIONALITY
#
note 'BASIC FUNCTIONALITY';

# the example from PDL::histogram
$x = pdl( 1,1,2 );
# by default histogram() returns a piddle of the same type as the axis,
# but output() returns a piddle of type I<long> when histogramming
$expected = long( 0,2,1 );
$binner = PDL::NDBin->new( axes => [ [ 'x', step=>1, min=>0, n=>3 ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl $got, $expected, 'example from PDL::histogram';
$binner = PDL::NDBin->new( axes => [ [ 'x', step=>1, min=>0, n=>3 ] ],
			   vars => [ [ 'z', sub { shift->want->nelem } ] ] );
$binner->process( x => $x, z => zeroes( long, $x->nelem ) );
$got = $binner->output;
is_pdl $got, $expected, 'variable and action specified explicitly';
$expected = pdl( 0,2,1 );	# this is an exception, because the type is
				# locked to double by `$x => sub { ... }'
$binner = PDL::NDBin->new( axes => [ [ x => ( step=>1, min=>0, n=>3 ) ] ],
			   vars => [ [ x => sub { shift->want->nelem } ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl $got, $expected, 'different syntax';
$expected = long( 0,2,1 );
$binner = PDL::NDBin->new( axes => [ [ x => ( step=>1, min=>0, n=>3 ) ] ],
			   vars => [ [ x => 'Count' ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl $got, $expected, 'different syntax, using action class name';

# this idiom with only chained calls should work
$x = pdl( 1,1,2 );
$expected = long( 0,2,1 );
$got = PDL::NDBin->new( axes => [ [ v => (step=>1,min=>0,n=>3) ] ] )->process( v => $x )->output;
is_pdl $got, $expected, 'all calls chained';

# the example from PDL::histogram2d
$x = pdl( 1,1,1,2,2 );
$y = pdl( 2,1,1,1,1 );
$expected = long( [0,0,0],
		  [0,2,2],
		  [0,1,0] );
$binner = PDL::NDBin->new( axes => [ [ x => (step=>1,min=>0,n=>3) ],
				     [ y => (step=>1,min=>0,n=>3) ] ] );
$binner->process( x => $x, y => $y );
$got = $binner->output;
is_pdl $got, $expected, 'example from PDL::histogram2d';

#
$x = pdl( 1,1,1,2,2,1,1 );
$y = pdl( 2,1,3,4,1,4,4 );
$expected = long( [1,1],
		  [1,0],
		  [1,0],
		  [2,1] );
$binner = PDL::NDBin->new( axes => [ [ 'x', step=>1, min=>1, n=>2 ],
				     [ 'y', step=>1, min=>1, n=>4 ] ] );
$binner->process( x => $x, y => $y );
$got = $binner->output;
is_pdl $got, $expected, 'nonsquare two-dimensional histogram';

# binning integer data
$x = byte(1,2,3,4);
$expected = long(1,1,1,1);
$binner = PDL::NDBin->new( axes => [ [ x => (step=>1,min=>1,n=>4) ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl $got, $expected, 'binning integer data: base case';
$x = short( 0,-1,3,9,6,3,1,0,1,3,7,14,3,4,2,-6,99,3,2,3,3,3,3 ); # contains out-of-range data
$expected = short( 8,9,1,0,5 );
$binner = PDL::NDBin->new( axes => [ [ x => (step=>1,min=>2,n=>5) ] ],
			   vars => [ [ x => sub { shift->want->nelem } ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl $got, $expected, 'binning integer data: step = 1';
$expected = long( 18,1,1,1,2 );
$binner = PDL::NDBin->new( axes => [ [ x => (step=>2,min=>3,n=>5) ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl $got, $expected, 'binning integer data: step = 2';

# more actions & missing/undefined/invalid stuff
$x = sequence 21;
$expected = double( 1,4,7,10,13,16,19 );
$binner = PDL::NDBin->new( axes => [ [ 'x', step=>3, min=>0, n=>7 ] ],
			   vars => [ [ 'x', sub { shift->selection->avg } ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl $got, $expected, 'variable with action = average';
$binner = PDL::NDBin->new( axes => [ [ 'x', step=>3, min=>0, n=>7 ] ],
			   vars => [ [ 'x', 'Avg' ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl $got, $expected, 'variable with action = average, using action class name';
$x = 5+sequence 3; # 5 6 7
$expected = double( 0,0,1,1,1 )->inplace->setvaltobad( 0 );
$binner = PDL::NDBin->new( axes => [ [ 'x', step=>1,min=>3,n=>5 ] ],
			   vars => [ [ 'x', sub { shift->want->nelem || undef } ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl $got, $expected, 'empty bins unset'; # cannot be achieved with action classes

# cross-check with histogram and some random data
$x = pdl( 0.7143, 0.6786, 0.9214, 0.5065, 0.9963, 0.9703, 0.1574, 0.4718,
	0.4099, 0.7701, 0.1881, 0.9412, 0.0034, 0.4440, 0.9423, 0.2065, 0.9656,
	0.5672, 0.2300, 0.5300, 0.1842 );
$y = pdl( 0.7422, 0.0299, 0.6629, 0.9118, 0.1224, 0.6173, 0.9203, 0.9999,
	0.1480, 0.4297, 0.5000, 0.9637, 0.1148, 0.2922, 0.0846, 0.0954, 0.1379,
	0.3187, 0.1655, 0.5777, 0.3047 );
$expected = histogram( $x, .1, 0, 10 )->long;
$binner = PDL::NDBin->new( axes => [ [ 'x', step=>.1, min=>0, n=>10 ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl $got, $expected, 'cross-check with histogram';
$expected = histogram2d( $x, $y, .1, 0, 10, .1, 0, 10 )->long;
$binner = PDL::NDBin->new( axes => [ [ 'x', step=>.1, min=>0, n=>10 ],
				     [ 'y', step=>.1, min=>0, n=>10 ] ] );
$binner->process( x => $x, y => $y );
$got = $binner->output;
is_pdl $got, $expected, 'cross-check with histogram2d';

# the example from PDL::hist
$x = pdl( 13,10,13,10,9,13,9,12,11,10,10,13,7,6,8,10,11,7,12,9,11,11,12,6,12,7 );
$expected = long( 0,0,0,0,0,0,2,3,1,3,5,4,4,4,0,0,0,0,0,0 );
$binner = PDL::NDBin->new( axes => [ [ x => min=>0, max=>20, step=>1 ] ] );
$binner->process( x => $x );
$got = $binner->output;
is_pdl $got, $expected, 'example from PDL::hist';

#
# DATA FEEDING & AUTOSCALING
#
note 'DATA FEEDING & AUTOSCALING';

#
$x = random( 30 );
$y = random( 30 );
$binner = PDL::NDBin->new( axes => [[ x => (step=>.1,min=>0,n=>10) ],
				    [ y => (step=>.1,min=>0,n=>10) ]] );
$got = $binner->axes;
is_deeply $got, [ { name => 'x',
		    step => .1,min=>0,n=>10 },
		  { name => 'y',
		    step => .1,min=>0,n=>10 } ], 'contents of axes() before feeding';
$binner->feed( x => $x );
$got = $binner->axes;
# is_deeply(), is(), cmp_ok(), etc., don't handle piddles well, hence this workaround
is_pdl $got->[0]->{pdl}, $x, '{pdl} for \'x\' in $self->axes after feeding x';
cmp_deeply $got, [ { name => 'x',
		     pdl  => ignore(),
		     step => .1, min => 0, n => 10 },
		   { name => 'y',
		     step => .1, min => 0, n => 10 } ], 'contents of axes() after feeding x';
$binner->feed( y => $y );
$got = $binner->axes;
is_pdl $got->[0]->{pdl}, $x, '{pdl} for \'x\' in $self->axes after feeding y';
is_pdl $got->[1]->{pdl}, $y, '{pdl} for \'y\' in $self->axes after feeding y';
cmp_deeply $got, [ { name => 'x',
		     pdl  => ignore(),
		     step => .1, min => 0, n => 10 },
		   { name => 'y',
		     pdl  => ignore(),
		     step => .1, min => 0, n => 10 } ], 'contents of axes() after feeding y';

#
$x = random( 30 );
$y = random( 30 );
$binner = PDL::NDBin->new( axes => [[ x => (step=>.1,min=>0,n=>10) ],
				    [ y => (step=>.1,min=>0,n=>10) ]] );
$got = $binner->axes;
is_deeply $got, [ { name => 'x',
		    step => .1,min=>0,n=>10 },
		  { name => 'y',
		    step => .1,min=>0,n=>10 } ], 'contents of axes() before feeding';
$binner->feed( x => $x,
	       y => $y );
$got = $binner->axes;
is_pdl $got->[0]->{pdl}, $x, '{pdl} for \'x\' in $self->axes after feeding x and y at once';
is_pdl $got->[1]->{pdl}, $y, '{pdl} for \'y\' in $self->axes after feeding x and y at once';
cmp_deeply $got, [ { name => 'x',
		     pdl  => ignore(),
		     step => .1, min => 0, n => 10 },
		   { name => 'y',
		     pdl  => ignore(),
		     step => .1, min => 0, n => 10 } ], 'contents of axes() after feeding x and y at once';
$y = random( 30 );
$binner->feed( y => $y );
is_pdl $got->[0]->{pdl}, $x, '{pdl} for \'x\' in $self->axes after feeding x and y at once';
is_pdl $got->[1]->{pdl}, $y, '{pdl} for \'y\' in $self->axes after feeding x and y at once';
cmp_deeply $got, [ { name => 'x',
		     pdl  => ignore(),
		     step => .1, min => 0, n => 10 },
		   { name => 'y',
		     pdl  => ignore(),
		     step => .1, min => 0, n => 10 } ], 'contents of axes() after re-feeding y';

# test auto axes
$x = pdl( 13,10,13,10,9,13,9,12,11,10,10,13,7,6,8,10,11,7,12,9,11,11,12,6,12,7 );
$binner = PDL::NDBin->new( axes => [[ x => (step=>1, min=>0, n=>10) ]] );
$binner->autoscale( x => $x );
$got = $binner->axes;
is_pdl $got->[0]->{pdl}, $x, 'returns early if step,min,n are known (1)';
cmp_deeply $got, [ { name => 'x',
		     pdl  => ignore(),
		     step => 1,
		     min  => 0,
		     n    => 10 } ], 'returns early if step,min,n are known (2)';
$got = reduce { $a * $b } map { $_->{n} } $binner->axes;
is $got, 10, 'number of bins';

#
# MIXED CODEREFS/CLASSES
#
note 'MIXED CODEREFS/CLASSES';

# The point here is to check that it is OK to mix action coderefs (which get
# called many times, i.e., once per bin) and action classes (which get called
# only once and compute all the bins at the same time) in the same call to
# process().
#
# For this to work properly, we rely on the actions having been cross-checked
# for correctness with regular PDL functions in t/01-actions.t.
$x = pdl( 0.665337628832283, -0.629370177449402, -0.611923922242319,
	0.146148441539381, -0.965210860804142, -0.821292959182784,
	0.497487420955331, -0.695206422742402, 0.0690564401273335,
	0.660776787555278, 0.790259459088325, 0.412517377156249,
	-0.912338356893109, -0.85339648912165, -0.307537768821028,
	0.329217496502892, 0.115705397854647, -0.416813576362927,
	0.707663545047488, -0.0639842132495545, 0.707644934900408,
	0.86550561953581, 0.219006175713098, -0.164623503609349,
	0.0103715544978016, 0.131996097622164, 0.961809571556124,
	-0.761399714469846, -0.78839870139236, 0.104065357533415,
	-0.706695560024293, -0.583065692362325, -0.215110521289482,
	0.14993000571593, 0.402443117969163, -0.34965346572595,
	-0.52588798019368, 0.311159910978148, 0.136275080812929,
	0.979419053792682, -0.13846015488155, 0.328787991194758,
	-0.960724071158587, 0.987148387986238, 0.894432391743273,
	0.0591228267492454, -0.21633965680099, 0.326279066456195,
	0.821408439770387, -0.576806894616027, -0.406264558618069,
	-0.437032097904861, 0.683982381247041, 0.0650105325215407,
	-0.87634868260961, 0.209158747497483, -0.450902524229882,
	-0.389235584171843, 0.0296209443781308, 0.425369106352562,
	-0.0599898385381934, -0.736890222190681, 0.0852026748151431,
	0.935228950924838, -0.033503261379785, -0.597415309439896,
	-0.0717940806291395, -0.873103418410764, -0.831668656566158,
	-0.0961553125630701, 0.61308484597901, 0.329484482065411,
	-0.578162294191024, -0.458964287625349, 0.192466739861707,
	0.831187999483021, -0.0721876364182421, -0.281304756157596,
	0.0911116286692888, 0.617499436710872, -0.533730589828217,
	-0.0822228979863553, -0.503241470666218, 0.101537910496077,
	-0.90846789091821, 0.817692139620334, 0.212871839737822,
	-0.375790772114854, 0.228710441558128, 0.702847654168295,
	0.142399603867226, -0.669041809862776, -0.145678511800632,
	0.175506066710255, 0.94968424874434, -0.423133727109544,
	0.890747106335546, 0.596571315205153, 0.536266550130698,
	-0.553391321294256 ); # 100 random values in the range [-1:1]
$binner = PDL::NDBin->new( axes => [ [ data => step=>2,min=>-1,n=>1 ] ],
			   vars => [ [ data => sub { shift->selection->avg } ],
				     [ data => 'Avg' ] ] );
$binner->process( data => $x );
$got = [ $binner->output ];
is @$got, 2;
cmp_ok abs( $got->[0]->at(0) ), '<', 1e-2, 'average of 100 random numbers in the range [-1:1] should be (more or less) close to 0';
is_pdl $got->[0], $got->[1], 'mixed coderef/class with one bin, average';

$binner = PDL::NDBin->new( axes => [ [ data => step=>.1,min=>-1,n=>20 ] ],
			   vars => [ [ data => sub { (shift->selection->stats)[6] } ],
				     [ data => 'StdDev' ] ] );
$binner->process( data => $x );
$got = [ $binner->output ];
is @$got, 2;
is_pdl $got->[0], $got->[1], 'mixed coderef/class with 20 bins, standard deviation';

#
# CONCATENATION
#
note 'CONCATENATION';
{
	my $u0 = pdl( -39.5879651748746, -1.61266445735144, -101, -101,
		14.8418955069236, -101, -8.26646389031183, 25.088753865478,
		23.8853755713542, -101, -21.6533850376752 )->inplace->setvaltobad( -101); # 11 random values [-50:50]
	my $u1 = pdl( 45.610085425162, -44.8090783225684, -27.334777692904,
		34.0608028167306, -101, -101, -2.56326878236344,
		-20.1093765242415, -36.7126503801988 )->inplace->setvaltobad( -101 ); # 9 random values [-50:50]
	my $u2 = pdl( -23.9802424215636, -45.4591971834436, -1.27709553320408,
		36.9333932550145, -101, -23.1580394609267 )->inplace->setvaltobad( -101 ); # 6 random values [-50:50]
	my $u3 = pdl( 15.3884236956522, -17.9424192631203, -10.0026229609036,
		-4.13046468116249, 40.3056552926195, -13.8882183825032,
		26.2092994583604, -28.9333103012069, -101, 47.7954550755687,
		42.5291780050966, -101, 12.06914489876 )->inplace->setvaltobad( -101 ); # 13 random values [-50:50]
	my $u4 = pdl( 8.28086562230297, 46.8340738920247, -37.15661354396 ); # 3 random values [-50:50]
	my $N = 42;
	my $u = $u0->append( $u1 )->append( $u2 )->append( $u3 )->append( $u4 );
	cmp_ok( $N, '>', 0, 'there are values to test' ) or BAIL_OUT( 'test is corrupt' );
	ok( $u->nelem == $N, 'number of values is consistent' ) or BAIL_OUT( 'test is corrupt' );
	for my $class ( __PACKAGE__->actions ) {
		# CodeRef is not supposed to be able to concatenate results
		next if $class eq 'PDL::NDBin::Action::CodeRef';
		my $binner = PDL::NDBin->new( axes => [ [ u => (step=>4,min=>-50,n=>25) ] ],
					      vars => [ [ u => "+$class" ] ] );
		for my $var ( $u0, $u1, $u2, $u3, $u4 ) { $binner->process( u => $var ) };
		my $got = $binner->output;
		my $expected = PDL::NDBin->new( axes => [ [ u => (step=>4,min=>-50,n=>25) ] ],
						vars => [ [ u => "+$class" ] ] )
					 ->process( u => $u )
					 ->output;
		is_pdl $got, $expected, "repeated invocation of process() equal to concatenation with action $class";
	}
}
