#! perl -l

# TODO - type of `step' and `min'

# DONE - handle bad values
#      - find a way not to have to start with $hash = zeroes( ... )

use strict;
use warnings;
use PDL;
use Inline Pdlpp => <<'EOF';
pp_def( 'hash_into',
	Pars => 'in(m); int b(m); int [o] hash(m)',
	OtherPars => 'double step; double min; int n',
	HandleBad => 1,
	Code => '
		register double min = $COMP( min );
		register double step = $COMP( step );
		register int j;
		register int maxj = $COMP( n ) - 1;
		loop(m) %{
			j = (( $in() - min )/step);
			if( j < 0 ) j = 0;
			if( j > maxj ) j = maxj;
			$hash() = j + $COMP( n ) * $b();
		%}
	',
	BadCode => '
		register double min = $COMP( min );
		register double step = $COMP( step );
		register int j;
		register int maxj = $COMP( n ) - 1;
		loop(m) %{
			if( $ISGOOD( in() ) && $ISGOOD( b() ) ) {
				j = (( $in() - min )/step);
				if( j < 0 ) j = 0;
				if( j > maxj ) j = maxj;
				$hash() = j + $COMP( n ) * $b();
			}
			else {
				$SETBAD( hash() );
			}
		%}
	',
);
EOF

my $x = sequence 10;
print 'x=', $x->info, ': ', $x;
my $y = sequence 10;
$y->inplace->setvaltobad( 5 );
print 'y=', $y->info, ': ', $y;

my $a = $x->hash_into( zeroes($x), 2,1,4 );
print 'a=', $a->info, ': ', $a;
my $b = $y->hash_into( $a, 2,1,4 );
print 'b=', $b->info, ': ', $b;

my $hash = 0;
print 'hash=', $hash;
$hash = $x->hash_into( $hash, 2,1,4 );
print 'hash=', $hash->info, ': ', $hash;
$hash = $y->hash_into( $hash, 2,1,4 );
print 'hash=', $hash->info, ': ', $hash;

__END__

for(
    {Name => 'histogram',
     WeightPar => '',
     HistType => 'int+',
     HistOp => '++',
     Doc => $histogram_doc,
     },
    {Name => 'whistogram',
     WeightPar => 'float+ wt(n);',
     HistType => 'float+',
     HistOp => '+= $wt()',
     Doc => $whistogram_doc,
     }
    )
{
pp_def($_->{Name},
       Pars => 'in(n); '.$_->{WeightPar}.$_->{HistType}.  '[o] hist(m)',
       # set outdim by Par!
       OtherPars => 'double step; double min; int msize => m',
       HandleBad => 1,
       Code => 
       'register int j;
	register int maxj = $SIZE(m)-1;
	register double min  = $COMP(min);
	register double step = $COMP(step);
	threadloop %{
	   loop(m) %{ $hist() = 0; %}
	%}
	threadloop %{
	   loop(n) %{
	      j = (int) (($in()-min)/step);
	      if (j<0) j=0;
	      if (j > maxj) j = maxj;
	      ($hist(m => j))'.$_->{HistOp}.';
	   %}
	%}',
       BadCode => 
       'register int j;
	register int maxj = $SIZE(m)-1;
	register double min  = $COMP(min);
	register double step = $COMP(step);
	threadloop %{
	   loop(m) %{ $hist() = 0; %}
	%}
	threadloop %{
	   loop(n) %{
              if ( $ISGOOD(in()) ) {
	         j = (int) (($in()-min)/step);
	         if (j<0) j=0;
	         if (j > maxj) j = maxj;
	         ($hist(m => j))'.$_->{HistOp}.';
              }
	   %}
	%}',
	Doc=>$_->{Doc});
}
