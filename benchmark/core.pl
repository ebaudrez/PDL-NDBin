# benchmark core loop

use strict;
use warnings;
use Benchmark qw( cmpthese );
use Fcntl;
use PDL;
use PDL::NetCDF;
use Inline 'Pdlpp';

my $nc = PDL::NetCDF->new( 'nosync/20040707.nc', { MODE => O_RDONLY } );
my ( $i, $j, $g ) = map $nc->get( $_ ), qw( i j gerb_ratio );

# i: range = 1032   [ 63 : 1094 inclusive ]
# j: range = 1102   [ 68 : 1169 inclusive ]
my ( $ni, $nj ) = ( 10, 10 );
my ( $di, $dj ) = ( 1032/$ni, 1102/$nj );
my $N = $ni * $nj;
my ( $hash, $pdl ) = 0;
$pdl = long( ( $j - 68 )/$dj );
$hash = $hash * $nj + $pdl;
$pdl = long( ( $i - 63 )/$di );
$hash = $hash * $ni + $pdl;
#print $hash->info;

my $default_iterator = sub {
	my ( $N, $hash, $vars, $actions, $results ) = @_;
	for my $bin ( 0 .. $N-1 ) {
		my $want = which $hash == $bin;
		for my $i ( 0 .. $#$vars ) {
			my ( $var, $action, $out ) = map { $_->[$i] } $vars, $actions, $results;
			my $selection = $var->index( $want );
			my $value = $action->( $selection );
			$out->set( $bin, $value ) if defined $out && defined $value;
		}
	}
};

my $skip_empty_iterator = sub { };
my $pass_bin_number_iterator = sub { };
# honour skip_empty, pass_bin_numbers, ...
sub iterator_factory
{

}

my $var_loop = sub {
	my ( $N, $hash, $vars, $actions, $results ) = @_;
	for my $i ( 0 .. $#$vars ) {
		my ( $var, $action, $out ) = map { $_->[$i] } $vars, $actions, $results;
		$action->( $var, $hash, $out );
	}
};

my $action = \&avg;
my $out = zeroes( double, $N )->inplace->setvaltobad( 0 );
cmpthese( 1,
	{
		# preallocation doesn't seem to help
		'operator ==' => sub {
			for my $bin ( 0 .. $N-1 ) {
				my $equal = $hash == $bin;
			}
		},
		'which' => sub {
			for my $bin ( 0 .. $N-1 ) {
				my $want = which $hash == $bin;
			}
		},
#		'which/prealloc' => sub {
#			# inoperative (PDL::which complains)
#			my $equal = PDL->null; # this is the right way (see PP.pod)
#			my $want = PDL->null;
#			for my $bin ( 0 .. $N-1 ) {
#				PDL::eq( $hash, $bin, $equal, 0 );
#				PDL::which( $equal, $want );
#			}
#		},
#		'in' => sub {
#			for my $bin ( 0 .. $N-1 ) {
#				my $want = which $hash->in( $bin );
#			}
#		},
#		'nelem' => sub {
#			for my $bin ( 0 .. $N-1 ) {
#				my $want = which $hash == $bin;
#				my $n = $want->nelem;
#			}
#		},
#		'index' => sub {
#			for my $bin ( 0 .. $N-1 ) {
#				my $want = which $hash == $bin;
#				my $selection = $g->index( $want );
#			}
#		},
#		'action' => sub {
#			for my $bin ( 0 .. $N-1 ) {
#				my $want = which $hash == $bin;
#				my $selection = $g->index( $want );
#				my $value = $action->( $selection );
#			}
#		},
#		'set+where' => sub {
#			for my $bin ( 0 .. $N-1 ) {
#				my $selection = where( $g, $hash == $bin );
#				my $value = $selection->avg;
#				$out->set( $bin, $value );
#			}
#		},
		'set' => sub {
			for my $bin ( 0 .. $N-1 ) {
				my $want = which $hash == $bin;
				my $selection = $g->index( $want );
				my $value = $selection->avg;
				$out->set( $bin, $value );
			}
		},
		'set/prealloc' => sub {
			my $equal = PDL->null; # this is the right way (see PP.pod)
			for my $bin ( 0 .. $N-1 ) {
				PDL::eq( $hash, $bin, $equal, 0 );
				my $want = which $equal;
				my $selection = $g->index( $want );
				my $value = $action->( $selection );
				$out->set( $i, $value );
			}
		},
#		'set/prealloc2' => sub {
#			my $bin = PDL->null; # no gain, really
#			my $equal = PDL->null;
#			$bin = 0;
#			for( my $i = 0; $i < $N; $bin++, $i++ ) {
#				PDL::eq( $hash, $bin, $equal, 0 );
#				my $want = which $equal;
#				my $selection = $g->index( $want );
#				my $value = $action->( $selection );
#				$out->set( $i, $value );
#			}
#		},
		'default_iterator' => sub {
			$default_iterator->( $N, $hash, [ $g ], [ \&avg ], [ $out ] );
		},
		'var_loop' => sub {
			$var_loop->( $N, $hash, [ $g ], [ \&PDL::iavg2p ], [ $out ] );
		},
	}
);
#$out->reshape( $ni, $nj );
#print $out;

__DATA__

__Pdlpp__

# at least the following two can be collapsed into a generator

# indirect count
pp_def( 'icount',
	Pars => 'in(n); int ind(n); [o] out(m)',
	Code => '
		loop(n) %{
			int j = $ind();
			( $out(m => j) )++;
		%}
	',
);

# indirect sum
pp_def( 'isum',
	Pars => 'in(n); int ind(n); [o] out(m)',
	Code => '
		loop(n) %{
			int j = $ind();
			( $out(m => j) ) += $in();
		%}
	',
);

# indirect average, two pass
# but see F<primitive.pd> line 2706
pp_def( 'iavg2p',
	Pars => 'in(n); int ind(n); int count(m); [o] out(m)',
	PMCode => '
		sub iavg2p
		{
			my ( $var, $ind, $out ) = @_;
			$out = $var->nullcreate unless defined $out;
			my $count = $var->icount( $ind );
			PDL::_iavg2p_int( $var, $ind, $count, $out );
			return $out;
		}
		*PDL::iavg2p = \&iavg2p;
	',
	Code => '
		loop(n) %{
			int j = $ind();
			( $out(m => j) ) += $in()/$count(m => j);
		%}
	',
);

# indirect average, one pass
pp_def( 'iavg1p',
	Pars => 'in(n); int ind(n); [o] out(m)',
	Code => '
	',
);
