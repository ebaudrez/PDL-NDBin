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
	$i, { step => 1 },
	$j, { step => 1 }
);
print Dumper \@axes;

timethese( 1, {
	fast_loop => sub {
		my $average = ndbin
			AXES => \@axes,
			VARS => [ $gerb_ratio, \&PDL::NDBin::Func::iavg ],
			INDEXER => 0
	},
} );
