# benchmark PDL::NDBin

use strict;
use warnings;
use blib;				# prefer development version of PDL::NDBin
use Benchmark qw( cmpthese timethese );
use Fcntl;
use PDL;
use PDL::NetCDF;
use PDL::NDBin;
use Path::Class;
use Getopt::Long qw( :config bundling );
use Text::TabularDisplay;
use Math::SimpleHisto::XS;

my $iter = 1;
my @functions;
my $multi;
my $n = 25;
my $output;
my $usage = <<EOF;
Usage:  $0  [ options ]  input_file
        $0  --multi  [ options ]  input_file  [ input_file... ]

Options:
  --bins <n>         | -n <n>   use <n> bins along every dimension (default: $n)
  --function <func>             select <func> to benchmark; may be specified more than once
                                and may use comma-separated values (default: @functions)
  --iters <n>        | -i <n>   perform <n> iterations for better accuracy (default: $iter)
  --multi            | -m       engage multi-mode to process multiple files
  --output           | -o       do output actual return value from functions

EOF
GetOptions( 'bins|n=i'    => \$n,
	    'function=s'  => \@functions,
	    'iter|i=i'    => \$iter,
	    'multi|m'     => \$multi,
	    'output|o'    => \$output ) or die $usage;

unless( @functions ) { @functions = qw( histogram want count ) }
@functions = split /,/ => join ',' => @functions;
my %selected = map { $_ => 1 } @functions;

#
my $file;
if( $multi ) {
	@ARGV or die $usage;
}
else {
	$file = shift;
	-f $file or die $usage;
	@ARGV and die $usage;
}

# we're going to bin latitude and longitude from -70 .. 70
my( $min, $max, $step ) = ( -70, 70, 140/$n );

#
my( $lat, $lon, $flux, @lat_list );
unless( $multi ) {
	print "Reading $file ... ";
	my $nc = PDL::NetCDF->new( $file, { MODE => O_RDONLY } );
	( $lat, $lon, $flux ) = map $nc->get( $_ ), qw( latitude longitude gerb_flux );
	undef $nc;
	my $n = do {
		# Perl Cookbook, 2nd Ed., p. 84 ;-)
		my $text = reverse $lat->nelem;
		$text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
		scalar reverse $text
	};
	@lat_list = $lat->list;
	print "done ($n data points)\n";
}

# shortcuts
my @axis = ( $step, $min, $n );
my %data = ( lat => $lat, lon => $lon, flux => $flux );
my $want = sub { shift->want->nelem };
my $selection = sub { shift->selection->nelem };
my $avg = sub { $_[0]->want->nelem ? shift->selection->avg : undef };
my %functions = (
	# one-dimensional histograms
	hist         => sub { hist $lat, $min, $max, $step },
	histogram    => sub { histogram $lat, $step, $min, $n },
	want         => sub {
				my $binner = PDL::NDBin->new(
					axes => [[ lat => @axis ]],
					vars => [[ lat => $want ]] );
				$binner->process( %data )->output
			},
	# $iter->selection->nelem is bound to be slower than $iter->want->nelem, but the purpose here is to compare
	selection    => sub {
				my $binner = PDL::NDBin->new(
					axes => [[ lat => @axis ]],
					vars => [[ lat => $selection ]] );
				$binner->process( %data )->output
			},
	count        => sub {
				my $binner = PDL::NDBin->new(
					axes => [[ lat => @axis ]],
					vars => [[ lat => 'Count' ]] );
				$binner->process( %data )->output
			},
	MSHXS        => sub {
				my $hist = Math::SimpleHisto::XS->new(
					min => $min,
					max => $max,
					nbins => $n );
				$hist->fill( \@lat_list );
				$hist->all_bin_contents
			},

	# two-dimensional histograms
	histogram2d  => sub { histogram2d $lat, $lon, $step, $min, $n, $step, $min, $n },
	want2d       => sub {
				my $binner = PDL::NDBin->new(
					axes => [[ lat => @axis ], [ lon => @axis ]],
					vars => [[ lat => $want ]] );
				$binner->process( %data )->output
			},
	count2d      => sub {
				my $binner = PDL::NDBin->new(
					axes => [[ lat => @axis ], [ lon => @axis ]],
					vars => [[ lat => 'Count' ]] );
				$binner->process( %data )->output
			},

	# average flux using either a coderef or a class (XS-optimized)
	coderef      => sub {
				my $binner = PDL::NDBin->new(
					axes => [[ lat => @axis ], [ lon => @axis ]],
					vars => [[ flux => $avg ]] );
				$binner->process( %data )->output
			},
	class        => sub {
				my $binner = PDL::NDBin->new(
					axes => [[ lat => @axis ], [ lon => @axis ]],
					vars => [[ flux => 'Avg' ]] );
				$binner->process( %data )->output
			},

	# one-dimensional histograms by concatenating multiple data files
	'histogram_multi' =>
			sub {
				my $hist = zeroes( $n );
				for my $file ( @ARGV ) {
					my $nc = PDL::NetCDF->new( $file, { MODE => O_RDONLY } );
					my $lat = $nc->get( 'latitude' );
					$hist += histogram $lat, $step, $min, $n;
				}
				$hist
			},
	'count_multi' =>
			sub {
				my $binner = PDL::NDBin->new(
					axes => [[ lat => @axis ]],
					vars => [[ lat => 'Count' ]] );
				for my $file ( @ARGV ) {
					my $nc = PDL::NetCDF->new( $file, { MODE => O_RDONLY } );
					my $lat = $nc->get( 'latitude' );
					$binner->process( lat => $lat );
				}
				$binner->output
			},

	# two-dimensional histograms by concatenating multiple data files
	'histogram_multi2d' =>
			sub {
				my $hist = zeroes( $n, $n );
				for my $file ( @ARGV ) {
					my $nc = PDL::NetCDF->new( $file, { MODE => O_RDONLY } );
					my $lat = $nc->get( 'latitude' );
					my $lon = $nc->get( 'longitude' );
					$hist += histogram2d $lat, $lon, $step, $min, $n, $step, $min, $n;
				}
				$hist
			},
	'count_multi2d' =>
			sub {
				my $binner = PDL::NDBin->new(
					axes => [[ lat => @axis ], [ lon => @axis ]],
					vars => [[ lat => 'Count' ]] );
				for my $file ( @ARGV ) {
					my $nc = PDL::NetCDF->new( $file, { MODE => O_RDONLY } );
					my $lat = $nc->get( 'latitude' );
					my $lon = $nc->get( 'longitude' );
					$binner->process( lat => $lat, lon => $lon );
				}
				$binner->output
			},
);

my %output;
my $results = timethese( $iter,
			 { map  { my $f = $_; $_ => sub { $output{ $f } = $functions{ $f }->() } }
			   grep { $selected{ $_ } }
			   keys  %functions
			 } );
print "\nRelative performance:\n";
cmpthese( $results );
print "\n";
if( $output ) {
	print "Actual output:\n";
	while( my( $func, $out ) = each %output ) { printf "%20s: %s\n", $func, $out }
	print "\n";
}
print "Norm of difference between output piddles:\n";
# Math::SimpleHisto::XS returns an arrayref: for a fair comparison, we need to
# convert the arrayref to a PDL after the benchmark
for my $key ( keys %output ) {
	my $val = $output{ $key };
	next if eval { $val->isa('PDL') };
	if( ref $val eq 'ARRAY' ) { $output{ $key } = pdl( $val ) }
}
my $table = Text::TabularDisplay->new( '', keys %output );
for my $row ( keys %output ) {
	$table->add( $row, map { my $diff = $output{ $row } - $_; $diff->abs->max } values %output );
}
print $table->render, "\n\n";
