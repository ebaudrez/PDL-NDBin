package PDL::NDBin;

=head1 NAME

PDL::NDBin - multidimensional binning & histogramming

=cut

use strict;
use warnings;
use Exporter;
use List::Util qw( reduce );
use Math::Round qw( nlowmult nhimult );
use PDL::Lite;		# do not import any functions into this namespace
use PDL::NDBin::Iterator;
use Log::Any;
use Data::Dumper;
use UUID::Tiny qw( :std );

=head1 VERSION

Version 0.002

=cut

our $VERSION = "0.002";
$VERSION = eval $VERSION;

=head1 SYNOPSIS

	# returns a one-dimensional histogram
	#    long( 0,2,1 )
	my $histogram = ndbinning( pdl( 1,1,2 ), 1, 0, 3 );

	# returns a two-dimensional histogram
	#    long( [0,0,0],
	#	   [0,2,2],
	#	   [0,1,0] );
	$x = pdl( 1,1,1,2,2 );
	$y = pdl( 2,1,1,1,1 );
	my $histogram = ndbinning( $x => (1,0,3),
				   $y => (1,0,3) );

For more detailed usage examples, consult the documentation of ndbin() and
ndbinning() below.

=head1 DESCRIPTION

PDL::NDBin is multidimensional binning and histogramming made easy.

=head1 SUBROUTINES

=cut

#
# TODO must check what happens for bad values and for bad coordinate values
# e.g., what happens when you're taking means inside the bins, and some of the
# values are bad? you want cdo behaviour, i.e., skip bad values so you can
# calculate a meaningful statistic
#

our @ISA = qw( Exporter );
our @EXPORT = qw( );
our @EXPORT_OK = qw( ndbinning ndbin process_axes make_labels );
our %EXPORT_TAGS = ( all => [ qw( ndbinning ndbin process_axes make_labels ) ] );

# the list of valid keys
my %valid_key = map { $_ => 1 } qw( AXES VARS DEFAULT_ACTION SKIP_EMPTY );

=head2 ndbinning()

The low-level function implementing the core loop. This function does minimal
error checking, and argument parsing is simple. For a high-level interface with
sophisticated argument parsing and more options, use ndbin().

All data equal to or less than the minimum (either supplied or automatically
determined) will be binned in the lowest bin. All data equal to or larger than
the maximum (either supplied or automatically determined) will be binned in the
highest bin. This is a slight asymmetry, as all other bins contain their lower
bound but not their upper bound. However, it does the right thing when binning
floating-point data.

There are as many output piddles as variables, and exactly one output piddle if
no variables have been supplied. The output piddles take the type of the
variables. All values in the output piddles are initialized to the bad value,
so missing bins can be distinguished from zero.

=head2 Argument parsing

The arguments must be specified (almost) like in histogram() and histogram2d().
That is, each axis must be followed by its three specifications I<step>, I<min>
and I<n>, being the step size, the minimum value, and the number of bins,
respectively. The difference with histogram2d() is that the axis specifications
follow the piddle immediately, instead of coming at the end.

	ndbinning( $pdl, $step, $min, $n
		  [ , $pdl, $step, $min, $n ]
		  [ ... ]
		  [ , $variable, $action ]
		  [ , $variable, $action ]
		  [ ... ] )
	## TODO!!! must at least mention the concepts of I<axis> and I<variable>

If no variables are supplied, we emulate the behaviour of histogram() and
histogram2d(), i.e., an I<n>-dimensional histogram is produced. This function,
although more flexible than the former two, is likely slower. If all you need
is a one- or two-dimensional histogram, use histogram() and histogram2d()
instead. Note that, when no variables are supplied, the returned histogram is
of type I<long>, in contrast with histogram() and histogram2d(). The
histogramming is achieved by passing an action which simply counts the number
of elements in the bin by calling nelem().

=head2 Implementation details

In PDL, the first dimension is the contiguous dimension, so we have to work
back from the last axis to the first when building the hashed bin number.

Here are some examples of hashing multidimensional bins into one dimension:

	(i) = i
	(i,j) = j*I + i
	(i,j,k) = (k*J + j)*I + i = k*J*I + j*I + i
	(i,j,k,l) = ((l*K + k)*J + j)*I + i = l*K*J*I + k*J*I + j*I + i

=cut

sub new
{
	my $class = shift;
	my $log = Log::Any->get_logger( category => (caller 0)[3] );
	my %args = @_;
	$log->debug( 'arguments = ' . Dumper \%args ) if $log->is_debug;
	PDL::Core::barf( 'no arguments' ) unless %args;
	PDL::Core::barf( "too few arguments for axis: @$_" ) for grep { @$_ != 4 } @{ $args{axes} };
	if( ref $args{vars} ) {
		PDL::Core::barf( "too few arguments for variable: @$_" ) for grep { @$_ != 2 } @{ $args{vars} };
	}
	my $self = {
		axes => $args{axes},
		vars => $args{vars},
	};
	return bless $self, $class;
}

# stolen from Log::Dispatch
sub _require_dynamic
{
	my $class = shift;
	my $log = Log::Any->get_logger( category => (caller 0)[3] );
	if( $class->VERSION ) {
		$log->info( "$class already loaded" );
		return;
	}
	local $@;
	eval "require $class";
	die $@ if $@;
}

sub _make_instance
{
	my( $N, $arg ) = @_;
	my $log = Log::Any->get_logger( category => (caller 0)[3] );
	if( ref $arg eq 'CODE' ) {
		my $class = "PDL::NDBin::Action::CodeRef";
		_require_dynamic( $class );
		return $class->new( $N, $arg );
	}
	else {
		my $class = substr( $arg, 0, 1 ) eq '+'
			? substr( $arg, 1 )
			: "PDL::NDBin::Action::$arg";
		_require_dynamic( $class );
		return $class->new( $N );
	}
}

sub process
{
	my $self = shift;
	my $log = Log::Any->get_logger( category => (caller 0)[3] );
	my %pdls = @_;

	# process axes
	my $hash = 0;		# hashed bin number
	my @n;			# number of bins in each direction
	# find the last axis and hash all axes into one dimension, working our
	# way backwards from the last to the first axis
	for my $axis ( reverse @{ $self->{axes} } ) {
		my( $name, $step, $min, $n ) = @$axis;
		my $pdl = $pdls{ $name };
		$log->debug( 'input (' . $pdl->info . ') = ' . $pdl ) if $log->is_debug;
		$log->debug( "bin with parameters step=$step, min=$min, n=$n" ) if $log->is_debug;
		unshift @n, $n;				# remember that we are working backwards!
		my $binned = PDL::long( ($pdl - $min)/$step );
		$binned->inplace->clip( 0, $n-1 );
		$hash = $hash * $n + $binned;
		$log->debug( 'binned coordinates (' . $binned->info . ') = ' . $binned ) if $log->is_debug;
	}
	$log->debug( 'hash (' . $hash->info . ') = ' . $hash ) if $log->is_debug;
	$self->{n} = \@n;

	my $N = reduce { $a * $b } @n; # total number of bins
	PDL::Core::barf( 'I need at least one bin' ) unless $N;
	# for compatibility with existing code
	# XXX this should be removed
	my( @vars, @instances );
	if( $self->{vars} && @{ $self->{vars} } ) {
		@vars = map { $pdls{ $_ } } map { $_->[0] } @{ $self->{vars} };
		@instances = map { _make_instance $N, $_->[1] } @{ $self->{vars} };
	}
	else {
		@vars = ( $hash );
		@instances = ( _make_instance $N, 'Count' );
	}
	$self->{instances} = \@instances;

	# now visit all the bins
	my $iter = PDL::NDBin::Iterator->new( \@n, \@vars, $hash );
	$log->debug( 'iterator object created: ' . Dumper $iter );
	while( my( $bin, $i ) = $iter->next ) { $instances[ $i ]->process( $iter ) }

	return $self;
}

=head2 output()

Return the output computed by the previous steps. Each output variable is
reshaped to make the number of dimensions equal to the number of axes, and the
extent of each dimension equal to the number of bins along the axis.

=cut

sub output
{
	my $self = shift;
	my $log = Log::Any->get_logger( category => (caller 0)[3] );
	# reshape output
	return unless defined wantarray;
	my $n = $self->{n};
	my @output = map { $_->result } @{ $self->{instances} };
	for my $pdl ( @output ) { $pdl->reshape( @$n ) }
	if( $log->is_debug ) { $log->debug( 'output (' . $_->info . ') = ' . $_ ) for @output }
	return wantarray ? @output : $output[0];
}

# generate a random, hopefully unique name for a pdl
sub _random_name { create_uuid( UUID_RANDOM ) }

sub ndbinning
{
	my $log = Log::Any->get_logger( category => (caller 0)[3] );
	# store the mapping from name to pdl
	my %pdls;
	# consume and process axes
	# axes require three numerical specifications following it
	my @axes;
	while( @_ > 3 && eval { $_[0]->isa('PDL') } && ! grep ref, @_[ 1 .. 3 ] ) {
		my( $pdl, $step, $min, $n ) = splice @_, 0, 4;
		my $name = _random_name;
		$pdls{ $name } = $pdl;
		push @axes, [ $name, $step, $min, $n ];
	}
	# consume and process variables
	my @vars;
	if( @_ ) {
		# consume variables
		# variables require an action following it
		while( @_ >= 2 && eval { $_[0]->isa('PDL') } && ! eval { $_[1]->isa('PDL') } ) {
			my( $pdl, $action ) = splice @_, 0, 2;
			my $name = _random_name;
			$pdls{ $name } = $pdl;
			push @vars, [ $name, $action ];
		}
	}
	# any arguments left indicate a usage error
	if( @_ ) { PDL::Core::barf( "error parsing arguments in `@_'" ) }
	my $binner = __PACKAGE__->new( axes => \@axes, vars => \@vars );
	$binner->process( %pdls );
	return $binner->output;
}

=head2 consume()

	consume BLOCK LIST

Shift and return (zero or more) leading items from I<LIST> meeting the
condition in I<BLOCK>. Sets C<$_> for each item of I<LIST> in turn.

For internal use.

=cut

sub consume (&\@)
{
	my ( $f, $list ) = @_;
	for my $i ( 0 .. $#$list ) {
		local *_ = \$list->[$i];
		if( not $f->() ) { return splice @$list, 0, $i }
	}
	# If we get here, either the list is empty, or all values in the list
	# meet the condition. In either case, splicing the entire list does
	# what we want.
	return splice @$list;
}

=head2 convert_to_hash()

A function to normalize the arguments: we have to end up with a hash
reference containing C<< key => value >> pairs with the arguments

For internal use.

=cut

sub convert_to_hash
{
	PDL::Core::barf( 'need at least one axis to bin along' ) unless @_;
	if( ref $_[0] eq 'HASH' ) {
		PDL::Core::barf( 'when supplying an anonymous hash, it must be the only parameter' ) if @_ > 1;
		return shift;
	}
	# technical note: PDL overloads the `eq' and `ne' operators; by
	# checking for a PDL first, we avoid (invalid) comparisons between
	# piddles and strings in the `grep'
	if( my @axes = consume { eval { $_->isa('PDL') } || ! $valid_key{ $_ } } @_ ) {
		# all leading arguments which are not valid key names are
		# assumed to be axis coordinates and parameters
		return { AXES => [ @axes ], @_ };
	}
	# no arguments matched the previous two conditions, so the argument
	# list consists entirely of key-value pairs
	return { @_ };
}

=head2 expand_value()

For internal use.

=cut

sub expand_value
{
	return unless @_;
	if( ! defined $_[0] ) { return }
	elsif( ref $_[0] eq 'ARRAY' ) {
		PDL::Core::barf( 'when supplying an anonymous array, it must be the only element' ) if @_ > 1;
		return @{ +shift };
	}
	else { return @_ }
}

=head2 expand_axes()

For internal use.

=cut

sub expand_axes
{
	my ( @out, $hash, @num );
	while( @_ ) {
		if( eval { $_[0]->isa('PDL') } ) {
			# a new axis; push the existing one on the output list
			push @out, $hash if $hash;
			$hash = { pdl => shift };
		}
		elsif( ref $_[0] eq 'HASH' ) {
			# the user has supplied a hash directly, which may or
			# may not yet contain a key-value pair pdl => $pdl
			$hash = { } unless $hash;
			push @out, { %$hash, %{ +shift } };
			undef $hash; # do not collapse consecutive hashes into one, too confusing
		}
		elsif( @num = consume { /^[-+]?(\d+(\.\d*)?|\.\d+)([Ee][-+]?\d+)?$/ } @_ ) {
			PDL::Core::barf( 'no axis given' ) unless $hash;
			PDL::Core::barf( "too many arguments to axis in `@num'" ) if @num > 3;
			# a series of floating-point numbers
			$hash->{min}  = $num[0] if @num > 0;
			$hash->{max}  = $num[1] if @num > 1;
			$hash->{step} = $num[2] if @num > 2;
		}
		#elsif( @num = ( $_[0] =~ m{^((?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][-+]?\d+)?/)+$}g ) and shift ) {
		#	DOES NOT WORK YET - TODO
		#	print "GMT-style axis spec found! (@num)\n";
		#	PDL::Core::barf( 'no axis given' ) unless $hash;
		#	PDL::Core::barf( "too many arguments to axis in `@num'" ) if @num > 3;
		#	# a string specification of the form 'min/max/step', a la GMT
		#	$hash->{min}  = $num[0] if @num > 0;
		#	$hash->{max}  = $num[1] if @num > 1;
		#	$hash->{step} = $num[2] if @num > 2;
		#}
		else {
			PDL::Core::barf( "while expanding axes: invalid argument at `@_'" );
		}
	}
	push @out, $hash if $hash;
	return @out;
}

=head2 expand_vars()

For internal use.

=cut

sub expand_vars
{
	my ( @out, $hash );
	while( @_ ) {
		if( eval { $_[0]->isa('PDL') } ) {
			# a new variable; push the existing one on the output list
			push @out, $hash if $hash;
			$hash = { pdl => shift };
		}
		elsif( ref $_[0] eq 'HASH' ) {
			# the user has supplied a hash directly, which may or
			# may not yet contain a key-value pair pdl => $pdl
			$hash = { } unless $hash;
			push @out, { %$hash, %{ +shift } };
			undef $hash; # do not collapse consecutive hashes into one, too confusing
		}
		elsif( ref $_[0] eq 'CODE' ) {
			PDL::Core::barf( 'no variable given' ) unless $hash;
			# an action to perform on this variable
			$hash->{action} = shift;
		}
		elsif( $_[0] =~ /^(\w+::)*\w+$/ ) {
			# if it looks like a package name, consider the argument
			# to be the name of a class implementing the action
			PDL::Core::barf( 'no variable given' ) unless $hash;
			$hash->{action} = shift;
		}
		else {
			PDL::Core::barf( "while expanding variables: invalid argument at `@_'" );
		}
	}
	push @out, $hash if $hash;
	return @out;
}

=head2 process_axes()

Process the axes. This is the function that ndbin() will call when you give it
axis specifications. This function has been separated from ndbin() so that you
can call it, and feed its output to make_labels() and ndbin() afterwards,
without needing to reparse your arguments.

process_axes() returns a list that should be fed into ndbin() as follows:

	my @axes = process_axes( ... );
	ndbin( AXES => \@axes, ... );

This function is useful if you want to find out exactly how ndbin() is going to
process your data. For example, to find the total number of bins:

	my @axes = process_axes( ... );
	my $N = List::Util::reduce { $a * $b } map { int $_->{n} } @axes;

Note the use of I<int> inside the I<map>. I<n> may be fractional, for reasons
explained in the documentation of ndbin() (see L<Number of bins>).

=cut

sub process_axes
{
	my @axes = expand_axes( expand_value @_ );
	my $length;
	for my $axis ( @axes ) {
		# first get & sanify the arguments
		PDL::Core::barf( 'need coordinates' ) unless defined $axis->{pdl};
		$length = $axis->{pdl}->nelem unless defined $length;
		if( $axis->{pdl}->nelem != $length ) {
			PDL::Core::barf( join '', 'number of coordinates (',
				$axis->{pdl}->nelem,
				') along this axis is different from previous',
				" ($length)" );
		}
		$axis->{min} = $axis->{pdl}->min unless defined $axis->{min};

=for comment
		# allow options the way histogram() and histogram2d() do, but
		# warn if a maximum has been given, because it is not possible
		# to honour four constraints
		if( defined $axis->{step} && defined $axis->{min} && defined $axis->{n} ) {
			if( defined $axis->{max} ) {
				my $warning = join '',
					'step size, minimum value and number of bins are given; ',
					'the given maximum value will be ignored';
				if( $axis->{pdl}->type < PDL::float ) {
					if( $axis->{max} != $axis->{min} + $axis->{n} * $axis->{step} - 1 ) {
						carp $warning;
					}
				}
				else {
					if( $axis->{max} != $axis->{min} + $axis->{n} * $axis->{step} ) {
						carp $warning;
					}
				}
			}
		}

=cut

		$axis->{max} = $axis->{pdl}->max unless defined $axis->{max};
		if( defined $axis->{round} and $axis->{round} > 0 ) {
			$axis->{min} = nlowmult( $axis->{round}, $axis->{min} );
			$axis->{max} = nhimult(  $axis->{round}, $axis->{max} );
		}
		PDL::Core::barf( 'max < min is invalid' ) if $axis->{max} < $axis->{min};
		if( $axis->{pdl}->type >= PDL::float ) {
			PDL::Core::barf( 'cannot bin with min = max' ) if $axis->{min} == $axis->{max};
		}
		# if step size has been supplied by user, check it
		if( defined $axis->{step} ) {
			PDL::Core::barf( 'step size must be > 0' ) unless $axis->{step} > 0;
			if( $axis->{pdl}->type < PDL::float && $axis->{step} < 1 ) {
				PDL::Core::barf( "step size = $axis->{step} < 1 is not allowed when binning integral data" );
			}
		}
		# number of bins I<n>
		if( defined $axis->{n} ) {
			PDL::Core::barf( 'number of bins must be > 0' ) unless $axis->{n} > 0;
		}
		else {
			if( defined $axis->{step} ) {
				# data range and step size were verified above,
				# so the result of this calculation is
				# guaranteed to be > 0
				# XXX CORE:: is ugly -- but can be remedied
				# later when we reimplement the hashing in PP
				$axis->{n} = CORE::int( ( $axis->{max} - $axis->{min} ) / $axis->{step} );
				if( $axis->{pdl}->type < PDL::float ) { $axis->{n} += 1 }
			}
			else {
				# if neither number of bins nor step size is
				# defined, take the default behaviour of hist()
				# (see F<Basic.pm>)
				$axis->{n} = $axis->{pdl}->nelem > 100 ? 100 : $axis->{pdl}->nelem;
			}
		}
		# step size I<step>
		# if we get here, the data range is certain to be larger than
		# zero, and I<n> is sure to be defined and valid (either
		# because it was supplied explicitly and verified to be valid,
		# or because it was calculated automatically)
		if( ! defined $axis->{step} ) {
			if( $axis->{pdl}->type < PDL::float ) {
				# result of this calculation is guaranteed to be >= 1
				$axis->{step} = ( $axis->{max} - $axis->{min} + 1 ) / $axis->{n};
				PDL::Core::barf( 'there are more bins than distinct values' ) if $axis->{step} < 1;
			}
			else {
				# result of this calculation is guaranteed to be > 0
				$axis->{step} = ( $axis->{max} - $axis->{min} ) / $axis->{n};
			}
		}
	}
	return @axes;
}

=head2 make_labels()

Make the labels for the bins.

=cut

sub make_labels
{
	my @axes = process_axes @_;
	map {
		my $axis = $_;
		my ( $pdl, $min, $step ) = @{ $axis }{ qw( pdl min step ) };
		[ map {
			{ # anonymous hash
				range => $pdl->type() >= PDL::float()
					? [ $min + $step*$_, $min + $step*($_+1) ]
					: $step > 1
						? [ nhimult( 1, $min + $step*$_ ), nhimult( 1, $min + $step*($_+1) - 1 ) ]
						: $min + $step*$_
			}
		} 0 .. $axis->{n}-1 ];
	} @axes;
}

=head2 ndbin()

A high-level function with sophisticated argument parsing.

All data equal to or less than the minimum (either supplied or automatically
determined) will be binned in the lowest bin. All data equal to or larger than
the maximum (either supplied or automatically determined) will be binned in the
highest bin. This is a slight asymmetry, as all other bins contain their lower
bound but not their upper bound. However, it does the right thing when binning
floating-point data.

=head2 Argument parsing

The arguments to ndbin() should be specified as one or more key-value pairs:

	ndbin(  KEY => VALUE
	       [ , KEY => VALUE ]
	       [ ... ] );

The argument list can optionally be enclosed by braces (i.e., an anonymous
hash). The recognized keys are C<AXES>, C<VARS>, C<DEFAULT_ACTION>, and
C<SKIP_EMPTY>. They are described in more detail below. Any key requiring more
than one value, e.g., C<AXES>, must be paired with an array reference.

For convenience, and for compatibility with hist(), a lot of abbreviations and
shortcuts are allowed, though. It is allowed to omit the key C<AXES> and the
array reference, and to specify the axes followed by their specifications as
ordinary parameters, provided they come first in the argument list. Thus, it is
allowed to write

	ndbin(  $pdl [ , $min [ , $max [ , $step ] ] ]
	       [ , $pdl [ , $min [ , $max [ , $step ] ] ] ]
	       [ ... ]
	       [ , KEY => VALUE ]
	       [ , KEY => VALUE ]
	       [ ... ]

Each of the specifications I<min>, I<max> and I<step> are optional; only the
piddles are required. Any subsequent keys, such as C<VARS> or
C<DEFAULT_ACTION>, must be specified again as key-value pairs. More
abbreviations and shortcuts are allowed inside the values of C<AXES> and
C<VARS>. For more information, refer to the description of the keys below. See
also L<Usage examples> below.

=head2 Valid keys

=over 4

=item C<AXES>

Specifies the axes along which to bin. The axes are supplied as an arrayref
containing anonymous hashes, as follows:

	AXES => [
			{
				pdl => $pdl,
				step => $step,
				min => $min,
				max => $max,
				n => $n,
				round => $round
			},
			...
		]

Only the piddle is required. All other specifications are optional and will be
determined automatically as required. Note that you cannot specify all
specifications at the same time, because some may conflict.

As a further convenience, the hashes may be omitted, and specifications may be
written as follows:

	AXES => [ $pdl, $min, $max, $step, $pdl, $min, $max, $step, ... ]

Again all specifications other than the piddle itself, i.e., I<min>, I<max> and
I<step>, are optional. Their order, when given, is important, though.

At least one axis is required.

=item C<VARS>

Specifies the values to bin. The variables are supplied as an arrayref
containing anonymous hashes, as follows:

	VARS => [
			{
				pdl => $pdl,
				action => $action
			},
			...
		]

Only the piddle is required. The action may be omitted and will be substituted
by the default action if supplied (see C<DEFAULT_ACTION> below), or by a
counting function to produce a histogram.

As a further convenience, the hashes may be omitted, and the variables may be
given as follows:

	VARS => [ $pdl, $action, $pdl, $action, ... ]

The action may again be omitted.

There can be zero or more variables. If no variables are supplied, the
behaviour of hist() is emulated, i.e., an I<n>-dimensional histogram is
produced (unless C<DEFAULT_ACTION> is specified). This function, although more
flexible than the former, is likely slower. If all you need is a
one-dimensional histogram, use hist() instead. Note that, when no variables are
supplied, the returned histogram is of type I<long>, in contrast with hist().

=item C<DEFAULT_ACTION>

The action to execute for a variable lacking an action. By default the number
of values in each bin is counted to produce a histogram.

=item C<SKIP_EMPTY>

Whether to skip empty bins. By default, empty bins are not skipped. You may
want to use this if the action associated with a variable cannot handle empty
piddles well.

=back

=head2 Usage examples

A one-dimensional histogram of height of individuals, binned between 0 and 2
metres, with the step size determined automatically:

	my $histogram = ndbin(
		AXES => [ { pdl => $height, min => 0, max => 2 } ]
	);

This example can be expressed concisely using the abbreviated form:

	my $histogram = ndbin( $height, 0, 2 );

If you wanted to specify the step size manually, you can do so by adding one
key-value pair to the hash in the first example, or by just adding the step
size in second example:

	my $histogram = ndbin(
		AXES => [ { pdl => $height,
			    min => 0, max => 2, step => 0.1 } ]
	);
	my $histogram = ndbin( $height, 0, 2, 0.1 );

Not all parameters can be specified in the abbreviated interface, however. To
have your minimum and maximum rounded before binning requires using the full
notation. For example, to get a one-dimensional histogram of particle size,
with the sizes rounded to 0.01, the step size equal to 0.01, and minimum and
maximum determined automatically, you must write:

	my $histogram = ndbin(
		AXES => [ { pdl => $particle_size,
			    round => 0.01, step => 0.01 } ]
	);

Two- or multidimensional histograms are specified by enumerating the axes one
by one. The coordinates must be followed immediately by their parameters.

	my $histogram = ndbin(
		AXES => [ { pdl => $longitude },
			  { pdl => $latitude } ]
	);

$histogram will be a two-dimensional piddle! Using the abbreviated interface,
this can be written as:

	my $histogram = ndbin( $longitude, $latitude );

Extra parameters for the axes are specified as follows:

	my $histogram = ndbin( $longitude, -70, 70, 20,
			       $latitude,  -70, 70, 20 );

A rather complete example of the interface:

	ndbin( AXES => [ { pdl => $longitude, min => -70, max => 70, step => 20 },
			 { pdl => $latitude,  min => -70, max => 70, step => 20 } ],
	       VARS => [ { pdl => $ceres_flux, action => \&do_ceres_flux },
			 { pdl => $gl_flux,    action => \&do_gl_flux    },
			 { pdl => $gerb_flux,  action => \&do_gerb_flux  } ],
	       SKIP_EMPTY => 0,		# do not skip empty bins (which is the default)
	     );

Note that there is no assignment of the return value (in fact, there is none).
The actions are supposed to have meaningful side-effects. To achieve the same
using the abbreviated interface, write:

	ndbin( $longitude, -70, 70, 20,
	       $latitude,  -70, 70, 20,
	       VARS => [ $ceres_flux, \&do_ceres_flux,
			 $gl_flux,    \&do_gl_flux,
			 $gerb_flux,  \&do_gerb_flux ],
	       SKIP_EMPTY => 0,		# do not skip empty bins
	     );

More simple examples:

 	my $histogram = ndbin( $x );
 	my $histogram = ndbin( $x, $y );
 	my $histogram = ndbin( AXES => [ { pdl => $x, min => 0, max => 10, n => 5 } ] );

And an example where the result does not contain the count, but rather the
averages of the binned fluxes:

	my $result = ndbin(
			AXES => [ { pdl => $longitude, round => 10, step => 20 },
				  { pdl => $latitude,  round => 10, step => 20 } ],
			VARS => [ $flux ],
			DEFAULT_ACTION => sub { shift->selection->avg },
	 	      );

=cut

=head2 Actions

You can, but are not required to, supply an action with every variable. If you
don't supply an action, the default action will be used, as given by the
C<DEFAULT_ACTION> key.

An action can be either a code reference (i.e., a reference to a subroutine, or
an anonymous subroutine), or the name of a class that implements the methods
new(), process() and result().

It is important to note that the actions will be called in the order they are
given for each bin, before proceeding to the next bin. You can depend on this
behaviour, for instance, when you have an action that depends on the result of
a previous action within the same bin.

By default, ndbin() will loop over all bins, and create a piddle per bin
holding only the values in that bin. This piddle will be passed to your
actions. This ensures that every action will only see the data in one bin at a
time. You need to do this when, e.g., you are taking the average of the values
in a bin with the standard PDL function avg(). However, the selection and
extraction of the data is time-consuming. If you have an action that knows how
to deal with indirection, you can do away with the selection and extraction.
Examples of such actions are: PDL::NDBin::Action::Count,
PDL::NDBin::Action::Sum, etc. They take the original data and the hashed bin
numbers and produce an output piddle in one step.

=head3 Code reference

In case the action specifies a code reference, this subroutine will be called
with the following argument:

	$coderef->( $iterator )

$iterator is an object of the class PDL::NDBin::Iterator, which will have been
instantiated for you. Important to note is that the action will be called for
every bin, with the given variable. The iterator must be used to retrieve
information about the current bin and variable. With $iterator->selection(),
for instance, you can access the elements that belong to this variable and this
bin.

=head3 Class name

In case the action specifies a class name, an object of the class will be
instantiated with

	$object = $class->new( $N )

where $N signifies the total number of bins. The variables will be processed by
calling

	$object->process( $iterator )

where $iterator again signifies an iterator object. Results will be collected
by calling

	$object->result

The object is responsible for correct bin traversal, and for storing the result
of the operation. The class must implement the three methods.

When supplying a class instead of an action reference, it is possible to
compute multiple bins at once in one call to process(). This can be much more
efficient than calling the action for every bin, especially if the loop can be
coded in PP/XS.

=head2 Automatic parameter calculation

=head3 Range

The range, when not given explicitly, is calculated from the data by calling
min() and max(). ndbin() will throw an exception if the data range is zero.

=head3 Number of bins

The number of bins I<n>, when not given explicitly, is determined automatically
by ndbin(). If the step size is not defined, ndbin() assumes the default
behaviour of hist(). If the number of elements of data is 100 or less,
the number of bins equals the number of elements. Otherwise, the number of bins
defaults to 100.

If the step size is defined and positive, the number of bins is calculated from
the range and the step size. The calculation is different for floating-point
data and integral data.

For floating-point data, I<n> is calculated as follows:

	n = range / step

The calculation is slightly different for integral data. When binning an
integral number, say 4, it really belongs in a bin that spans the range 4
through 4.99...; to bin a list of data values with, say, I<min> = 3 and I<max>
= 8, we must consider the range to be 9-3 = 6. A step size of 3 would yield 2
bins, one containing the values (3, 4, 5), and another containing the values
(6, 7, 8). However, I<n> calculated in this way may well be fractional. When
I<n> is ultimately used in ndbinning(), it is converted to I<int> by
truncating. To have sufficient bins, I<n> must be rounded up to the next
integer. The correct formula for calculating the number of bins is therefore

	n = ceil( ( range + 1 ) / step )

In the implementation, however, it is easier to calculate I<n> as it is done
for floating-point data, and increment it by one, before it is truncated. The
following formula is how I<n> is calculated by the code:

	n = floor( range/step + 1 )

Using the following identity from
L<http://en.wikipedia.org/wiki/Floor_and_ceiling_functions>, both formulas can
be proved to be equivalent.

	ceil( x/y ) = floor( (x+y-1)/y )

	XXX the docs are out of sync here: we truncate in process_axes()
	because we were having trouble with PDL doing conversion to double on
	$hash = $hash * $n + $binned
	when $n is fractional (i.e., PDL doesn't truncate); but this is
	expected to go away when we reimplement the hashing in PP, since in
	OtherPars we will specify `int'

=head3 Step size

The step size, when not given explicitly, is determined from the range and the
number of bins I<n> as follows

	step = range / n

The step size may be fractional, even for integral data. Although this may seem
strange, it yields more natural results. Consider the data (3, 4, 5, 6).
Binning with I<n> = 2 yields the histogram (2, 2), which is what you expect,
although the step size in this example is 1.5. The step size must not be less
than one, however. If this happens, there are more bins than there are distinct
numbers in the data, and the function will abort.

Note that when the number of I<n> is not given either, a default value is used
by ndbin(), as described above.

=cut

sub ndbin
{
	my $log = Log::Any->get_logger( category => (caller 0)[3] );
	# parameters
	my $args = convert_to_hash( @_ );
	$log->debug( 'parameters: ' . Dumper $args ) if $log->is_debug;
	my @invalid_keys = grep ! $valid_key{ $_ }, keys %$args;
	PDL::Core::barf( "invalid key(s) @invalid_keys" ) if @invalid_keys;

	# axes
	my @axes = process_axes $args->{AXES};
	$log->debug( 'axes: ' . Dumper \@axes ) if $log->is_debug;

	# variables
	my $default_action = $args->{DEFAULT_ACTION} || sub { shift->want->nelem };
	my $skip_empty = $args->{SKIP_EMPTY};			# by default is false
	my @vars = expand_vars( expand_value $args->{VARS} );
	# the presence of any of these keys requires a variable
	if( ! @vars and grep { /^(SKIP_EMPTY|DEFAULT_ACTION)$/ } keys %$args ) {
		@vars = ( { pdl => PDL->null->long } );
	}
	for my $var ( @vars ) {
		my $action = $var->{action} || $default_action;
		if( $skip_empty ) {
			# wrap $action if $skip_empty differs from its default value
			$var->{action} = sub {
				return unless $_[0]->want->nelem;
				$action->( @_ );
			};
		}
		else { $var->{action} = $action }
	}
	$log->debug( 'vars: ' . Dumper \@vars ) if $log->is_debug;

	# the real work is done by ndbinning()
	if( @vars ) {
		ndbinning( ( map { $_->{pdl}, $_->{step}, $_->{min}, $_->{n} } @axes ),
			   ( map { $_->{pdl}, $_->{action} } @vars ) );
	}
	else {
		ndbinning map { $_->{pdl}, $_->{step}, $_->{min}, $_->{n} } @axes;
	}
}

1;

=head1 USEFUL EXTRA'S

To hook a progress bar to ndbin():

	use Term::ProgressBar::Simple;
	my @axes = process_axes( ... );
	my $N = List::Util::reduce { $a * $b } map { int $_->{n} } @axes;
	my $progress = Term::ProgressBar::Simple->new( $N );
	ndbin(
		AXES => \@axes,
		VARS => [ ...,
			  PDL::null => sub { $progress++; return } ]
	);

In this case, you want C<SKIP_EMPTY> to be zero (the default) for the progress
bar to work correctly. Note that the progress bar updater returns I<undef>. You
probably do not want to return the result of C<$progress++>! If you were to
capture the return value of ndbin(), a piddle would be returned that holds the
return values of the progress bar updater. You probably do not want this
either. By putting the progress bar updater last, you can simply ignore that
piddle.

=head1 BUGS

None reported.

=head1 TODO

This documentation is unfortunately quite incomplete, due to lack of time.

=head1 AUTHOR

Edward Baudrez, ebaudrez@cpan.org, 2011.

=head1 SEE ALSO

L<PDL>, L<PDL::Basic, L<PDL::Primitive>, L<PDL::NDBin::Action>

=head1 COPYRIGHT and LICENSE

=cut
