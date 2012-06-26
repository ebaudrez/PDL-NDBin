# benchmark

use strict;
use warnings;
use PDL;
use PDL::NetCDF;
use PDL::NDBin qw( ndbin process_axes );
use List::Util qw( reduce );
use Fcntl;
use Term::ProgressBar::Simple;
use Benchmark;
use Data::Dumper;

my $nc = PDL::NetCDF->new( 'nosync/20040707.nc', { MODE => O_RDONLY } );
my $i = $nc->get( 'i' );
my $j = $nc->get( 'j' );
my $gerb_ratio = $nc->get( 'gerb_ratio' );

my @axes = process_axes(
	$i, { n => 100 },
	$j, { n => 100 }
);
print Dumper \@axes;

sub mynorm
{
	my $pdl = shift;
	return $pdl->abs->max;
}

if( grep $_ eq '-p', @ARGV ) {
	our( $a, $b );
	my $N = reduce { $a * $b } map { int $_->{n} } @axes;
	my $progress = Term::ProgressBar::Simple->new( $N );
	my $average = ndbin
		AXES => \@axes,
		VARS => [ $gerb_ratio, \&avg,
			  null, sub { $progress++; return },
			];
}
else {
	my ( $avg1, $avg2 );
	timethese( 1, {
		default_loop => sub {
			$avg1 = ndbin
				AXES => \@axes,
				VARS => [ $gerb_ratio, \&avg ]
		},
		fast_loop => sub {
			$avg2 = ndbin
				AXES => \@axes,
				VARS => [ $gerb_ratio, \&PDL::NDBin::Func::iavg ],
				INDEXER => 0
		},
	} );
#print $avg2;
	print 'norm of difference: ', mynorm( $avg1 - $avg2 ), "\n";
}
