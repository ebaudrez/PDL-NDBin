# compare PDL::NDBin with PDL's hist(), histogram() and histogram2d()

use strict;
use warnings;
use Benchmark qw( cmpthese );
use Fcntl;
use PDL;
use PDL::NetCDF;

my $nc = PDL::NetCDF->new( 'nosync/20040707.nc', { MODE => O_RDONLY } );
my ( $i, $j, $g ) = map $nc->get( $_ ), qw( i j gerb_ratio );

cmpthese( 1,
	{
		'which' => sub {
			for my $bin ( 0 .. $N-1 ) {
				#my $want = which $hash == $bin;
			}
		},
	}
);
