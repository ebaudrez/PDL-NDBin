package PDL::NDBin;

=head1 NAME

PDL::NDBin - multidimensional binning & histogramming

=cut

use strict;
use warnings;
use Exporter;
use List::Util qw( reduce );
use List::MoreUtils qw( pairwise );
use Math::Round qw( nlowmult nhimult );
use PDL::Lite;		# do not import any functions into this namespace
use PDL::NDBin::Iterator;
use PDL::NDBin::Actions_PP;
use Log::Any qw( $log );
use Data::Dumper;
use UUID::Tiny qw( :std );

=head1 VERSION

Version 0.003

=cut

our $VERSION = "0.003";
$VERSION = eval $VERSION;

=head1 SYNOPSIS

	# bin the values
	#    pdl( 1,1,2 )
	# in 3 bins with a width of 1, starting at 0:
	my $histogram = ndbinning( pdl( 1,1,2 ), 1, 0, 3 );
	# returns the one-dimensional histogram
	#    long( 0,2,1 )

	# bin the values
	$x = pdl( 1,1,1,2,2 );
	$y = pdl( 2,1,1,1,1 );
	# along two dimensions, with 3 bins per dimension:
	my $histogram = ndbinning( $x => (1,0,3),
				   $y => (1,0,3) );
	# returns the two-dimensional histogram
	#    long( [0,0,0],
	#	   [0,2,2],
	#	   [0,1,0] )

These examples only illustrate how to make a one- and a two-dimensional
histogram. For more advanced usage, read on.

=head1 DESCRIPTION

In scientific (and other) applications, it is frequently necessary to classify
a series of values in a number of bins. For instance, particles may be
classified according to particle size in a number of bins of, say, 0.01 mm
wide, yielding a histogram. Or, to take an example from my own work: satellite
measurements taken all over the globe must often be classified in
latitude/longitude boxes for further processing.

L<PDL> has a dedicated function to make histograms, hist(). To create a
histogram of particle size from 0 mm to 10 mm, in bins of 0.1 mm, you would
write:

	my $histogram = hist $particles, 0, 10, 0.1;

This will count the number of particles in every bin, yielding the 100 counts
that form the histogram. But what if you wanted to perform other computations
on the values in the bins? It is actually not that difficult to perform the
binning by hand. The key is to associate a bin number with every data value.
With fixed-size bins of 0.1 mm wide, that is accomplished with

	my $bin_numbers = PDL::long( $particles/0.1 );

(Note that the formulation above does not take care of data beyond 10 mm, but
PDL::NDBin does.) We now have two arrays of data: the actual particle sizes in
$particles, and the bin number associated with every data value. The histogram
could now be produced with the following loop:

	my $histogram = zeroes( long, $N );
	for my $bin ( 0 .. $N-1 ) {
		my $want = which( $bin_numbers == $bin );
		$histogram->set( $bin, $want->nelem );
	}

But, once we have the indices of the data values corresponding to any bin, it
is a small matter to extend the loop to actually extract the data values in the
bin. A user-supplied subroutine can then be invoked on the values in every bin:

	my $output = zeroes( long, $N )->setbadif( 1 );
	for my $bin ( 0 .. $N-1 ) {
		my $want = which( $bin_numbers == $bin );
		my $selection = $particles->index( $want );
		my $value = eval { $coderef->( $selection ) };
		if( defined $value ) { $output->set( $bin, $value ) }
	}

(This is how early versions of PDL::NDBin were implemented.) The user
subroutine could do anything with the values in the currently selected bin,
$selection, including counting. But the subroutine could also output the data
to disk, or to a plot. Or the data could be collected to perform a regression.
Anything that can be expressed with a subroutine, can now easily be plugged
into this core loop.

This basic idea can even be extended by noticing that it is also possible to do
multidimensional binning with the same core loop. The solution is to 'flatten'
the bins, much like C and Perl flatten multidimensional arrays to a
one-dimensional array in memory. So, you could perfectly bin satellite data
along both latitude and longitude:

	my( $latitude, $longitude ); # somehow get these data as 1-D vars
	my $flattened = 0;
	for my $var ( $latitude, $longitude ) {
		my $bin_numbers = long( ($var - $min)/$step );
		$bin_numbers->inplace->clip( 0, $n-1 );
		$flattened = $flattened * $n + $bin_numbers;
	}

$flattened now contains pseudo-one-dimensional bin numbers, and can be used
in the core loop shown above.

I've left out many details to illustrate the idea. The basic idea is very
simple, but the implementation does get a bit messy when multiple variables are
binned in multiple dimensions, with user-defined actions. Of course, ideally,
you'd like this to be very performant, so you can handle several millions of
data values without hitting memory constraints or running out of time.
PDL::NDBin is there to handle the details for you, so you can write

	my $average_flux = ndbin( $longitude, min => -70, max => 70, step => 20,
				  $latitude,  min => -70, max => 70, step => 20,
				  vars => [ [ $flux => 'Avg' ] ] );

to obtain the average of the flux, binned in boxes of 20x20 degrees latitude
and longitude.

=cut

#
# TODO must check what happens for bad values and for bad coordinate values
# e.g., what happens when you're taking means inside the bins, and some of the
# values are bad? you want cdo behaviour, i.e., skip bad values so you can
# calculate a meaningful statistic
#

our @ISA = qw( Exporter );
our @EXPORT = qw( );
our @EXPORT_OK = qw( ndbinning ndbin );
our %EXPORT_TAGS = ( all => [ qw( ndbinning ndbin ) ] );

# the list of valid keys
my %valid_key = map { $_ => 1 } qw( axes vars );

=head1 METHODS

=head2 add_axis()

Add an axis to the current object, with optional axis specifications. The
argument list must be a list of key-value pairs. The name of the axis is
mandatory.

	$self->add_axis( name => 'longitude', min => -70, max => 70, n => 14 );

=cut

sub add_axis
{
	my $self = shift;
	PDL::Core::barf( "odd number of elements for axis specification (did you use key => value?): @_" ) if @_ % 2;
	my %params = @_;
	$log->tracef( 'adding axis with specs %s', \%params );
	PDL::Core::barf( 'need at least a name for every axis' ) unless $params{name};
	push @{ $self->{axes} }, \%params;
}

=head2 add_var()

Add a variable to the current object. The argument list must be a list of
key-value pairs. The name of the variable is mandatory.

	$self->add_var( name => 'flux', action => 'Avg' );

=cut

sub add_var
{
	my $self = shift;
	PDL::Core::barf( "odd number of elements for variable specification (did you use key => value?): @_" ) if @_ % 2;
	my %params = @_;
	$log->tracef( 'adding variable with specs %s', \%params );
	PDL::Core::barf( 'need at least a name for every variable' ) unless $params{name};
	push @{ $self->{vars} }, \%params;
}

=head2 new()

Constructor for a PDL::NDBin object. The argument list must be a list of
key-value pairs. No arguments are required, but you will want to add at least
one axis eventually to do meaningful work.

	my $obj = PDL::NDBin->new( axes => [ [ 'x', min => -1, max => 1, step => .1 ],
					     [ 'y', min => -1, max => 1, step => .1 ] ],
				   vars => [ [ 'F', 'Count' ] ] );

The accepted keys are the following:

=over 4

=item C<axes>

Specifies the axes along which to bin. The axes are supplied as an arrayref
containing anonymous arrays, one per axis, as follows:

	axes => [
		  [ $name1, $key11 => $value11, $key12 => $value12, ... ],
		  [ $name2, $key21 => $value21, $key22 => $value22, ... ],
		  ...
		]

Only the name is required. All other specifications are optional and will be
determined automatically as required. Note that you cannot specify all
specifications at the same time, because some may conflict.

At least one axis will eventually be required, although it needn't be specified
at constructor time, and can be added later with add_axis(), if desired.

=item C<vars>

Specifies the values to bin. The variables are supplied as an arrayref
containing anonymous arrays, one per variable, as follows:

	vars => [
		  [ $name1 => $action1 ],
		  [ $name2 => $action2 ],
		  ...
		]

Here, both the name and the action are required. In order to produce a
histogram, supply C<'Count'> as the action.

No variables are required (an I<n>-dimensional histogram is produced if no
variables are supplied), but they can be specified at constructor time, or at a
later time with add_var() if desired.

=back

=cut

sub new
{
	my $class = shift;
	my %args = @_;
	$log->debug( 'new: arguments = ' . Dumper \%args ) if $log->is_debug;
	my $self = bless { axes => [], vars => [] }, $class;
	# axes
	$args{axes} ||= [];		# be sure we can dereference
	my @axes = @{ $args{axes} };
	for my $axis ( @axes ) {
		my $name = shift @$axis;
		$self->add_axis( name => $name, @$axis );
	}
	# vars
	$args{vars} ||= [];		# be sure we can dereference
	my @vars = @{ $args{vars} };
	for my $var ( @vars ) {
		if( @$var == 2 ) {
			my( $name, $action ) = @$var;
			$self->add_var( name => $name, action => $action );
		}
		else { PDL::Core::barf( "wrong number of arguments for var: @$var" ) }
	}
	return $self;
}

=head2 axes()

Read-only accessor to retrieve the axes. It will return a list in list context,
and an array reference in scalar context.

=head2 vars()

Read-only accessor to retrieve the variables. It will return a list in list context,
and an array reference in scalar context.

=cut

sub axes { wantarray ? @{ $_[0]->{axes} } : $_[0]->{axes} }
sub vars { wantarray ? @{ $_[0]->{vars} } : $_[0]->{vars} }

# stolen from Log::Dispatch
sub _require_dynamic
{
	my $class = shift;
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

=head2 feed()

Set the piddles that will eventually be used for the axes and variables.
Arguments must be specified as key-value pairs, they keys being the name, and
the values being the piddle for every piddle to is to be set.

Note that not all piddles need be set in one call. This function can be called
repeatedly to set all piddles. This can be very useful when data must be read
from disk, as in the following example (assuming $nc is an object that reads
data from disk):

	my $binner = PDL::NDBin->new( axes => [ [ x => ... ], [ y => ... ] ] );
	for my $f ( 'x', 'y' ) { $binner->feed( $f => $nc->get( $f ) ) }
	$binner->process;

=cut

sub feed
{
	my $self = shift;
	my %pdls = @_;
	while( my( $name, $pdl ) = each %pdls ) {
		for my $v ( $self->axes, $self->vars ) {
			$v->{pdl} = $pdl if $v->{name} eq $name;
		}
	}
}

sub _check_all_pdls_present
{
	my $self = shift;
	my %warned_for;
	for my $v ( $self->axes, $self->vars ) {
		next if defined $v->{pdl};
		next if $v->{action} eq 'Count'; # those variables don't need data
		my $name = $v->{name};
		next if $warned_for{ $name };
		$log->error( "no data for $name" );
		$warned_for{ $name }++;
	}
}

sub _check_pdl_length
{
	my $self = shift;
	# checking whether the lengths of all axes and variables are equal can
	# only be done here (in a loop), and not in _auto_axis()
	my $length;
	for my $v ( $self->axes, $self->vars ) {
		$length = $v->{pdl}->nelem unless defined $length;
		# variables don't always need a pdl, or may be happy with a
		# null pdl; let the action figure it out.
		# note that the test isempty() is not a good test for null
		# pdls, but until I have a better one, this will have to do
		next if $v->{action} && ( ! defined $v->{pdl} || $v->{pdl}->isempty );
		if( $v->{pdl}->nelem != $length ) {
			PDL::Core::barf( join '', 'number of elements (',
				$v->{pdl}->nelem, ") of '$v->{name}'",
				" is different from previous ($length)" );
		}
	}
}

=head2 autoscale()

Determine missing parameters for the axes automatically. It is not usually
required to call this method, as it is called automatically by process().

=cut

sub autoscale
{
	my $self = shift;
	$self->feed( @_ );
	$self->_check_all_pdls_present;
	$self->_check_pdl_length;
	_auto_axis( $_ ) for $self->axes;
}

=head2 labels()

Return the labels for the bins as a list of lists of ranges.

=cut

sub labels
{
	my $self = shift;
	$self->autoscale( @_ );
	my @list = map {
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
	} $self->axes;
	return wantarray ? @list : \@list;
}

=head2 process()

The core method. The actual piddles to be used for the axes and variables can
be supplied to this function, although if all piddles have already been
supplied, the argument list can be empty. The argument list is the same as the
one of feed(), i.e., a list of key-value pairs specifying name and piddle.

process() returns $self for chained method calls.

=cut

sub process
{
	my $self = shift;

	# sanity check
	PDL::Core::barf( 'no axes supplied' ) unless @{ $self->axes };
	# default action, when no variables are given, is to produce a histogram
	$self->add_var( name => 'histogram', action => 'Count' ) unless @{ $self->vars };

	#
	$self->autoscale( @_ );

	# process axes
	my $idx = 0;		# flattened bin number
	my @n;			# number of bins in each direction
	# find the last axis and flatten all axes into one dimension, working
	# our way backwards from the last to the first axis
	for my $axis ( reverse $self->axes ) {
		$log->debug( 'input (' . $axis->{pdl}->info . ') = ' . $axis->{pdl} ) if $log->is_debug;
		$log->debug( "bin with parameters step=$axis->{step}, min=$axis->{min}, n=$axis->{n}" )
			if $log->is_debug;
		unshift @n, $axis->{n};			# remember that we are working backwards!
		$idx = $axis->{pdl}->_flatten_into( $idx, $axis->{step}, $axis->{min}, $axis->{n} );
	}
	$log->debug( 'idx (' . $idx->info . ') = ' . $idx ) if $log->is_debug;
	$self->{n} = \@n;

	my $N = reduce { $a * $b } @n; # total number of bins
	PDL::Core::barf( 'I need at least one bin' ) unless $N;
	my @vars = map $_->{pdl}, $self->vars;
	$self->{instances} ||= [ map { _make_instance $N, $_->{action} } $self->vars ];

	#
	{
		local $Data::Dumper::Terse = 1;
		$log->trace( 'process: $self = ' . Dumper $self );
	}

	# now visit all the bins
	my $iter = PDL::NDBin::Iterator->new( \@n, \@vars, $idx );
	$log->debug( 'iterator object created: ' . Dumper $iter );
	while( my( $bin, $i ) = $iter->next ) { $self->{instances}->[ $i ]->process( $iter ) }

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
	# reshape output
	return unless defined wantarray;
	my $n = $self->{n};
	my @output = map { $_->result } @{ $self->{instances} };
	for my $pdl ( @output ) { $pdl->reshape( @$n ) }
	if( $log->is_debug ) { $log->debug( 'output: output (' . $_->info . ') = ' . $_ ) for @output }
	my %result = pairwise { $a->{name} => $b } @{ $self->vars }, @output;
	if( $log->is_debug ) { $log->debug( 'output: result = ' . Dumper \%result ) }
	return wantarray ? %result : \%result;
}

=head2 _consume()

	_consume BLOCK LIST

Shift and return (zero or more) leading items from I<LIST> meeting the
condition in I<BLOCK>. Sets C<$_> for each item of I<LIST> in turn.

For internal use.

=cut

sub _consume (&\@)
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

sub _expand_axes
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
		elsif( @num = _consume { /^[-+]?(\d+(\.\d*)?|\.\d+)([Ee][-+]?\d+)?$/ } @_ ) {
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

sub _auto_axis
{
	my $axis = shift;
	# return early if step, min, and n have already been calculated
	if( defined $axis->{step} && defined $axis->{min} && defined $axis->{n} ) {
		$log->tracef( 'step, min, n already calculated for %s; not recalculating', $axis );
		return;
	}
	# first get & sanify the arguments
	PDL::Core::barf( 'need coordinates' ) unless defined $axis->{pdl};
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
			# later when we reimplement the flattening in XS
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

# generate a random, hopefully unique name for a pdl
sub _random_name { create_uuid( UUID_RANDOM ) }

=head1 WRAPPER FUNCTIONS

PDL::NDBin provides the two functions ndbinning() and ndbin(), which are
(almost) drop-in replacements for histogram() and hist(), except that they
handle an arbitrary number of dimensions.

ndbinning() and ndbin() are actually wrappers around the object-oriented
interface of PDL::NDBin, and may be the most convenient way to work with
PDL::NDBin for simple cases. For more advanced usage, the object-oriented
interface may be required.

=head2 ndbinning()

Calculates an I<n>-dimensional histogram from one or more piddles. The
arguments must be specified (almost) like in histogram() and histogram2d().
That is, each axis must be followed by its three specifications I<step>, I<min>
and I<n>, being the step size, the minimum value, and the number of bins,
respectively. The difference with histogram2d() is that the axis specifications
follow the piddle immediately, instead of coming at the end.

	my $hist = ndbinning( $pdl1, $step1, $min1, $n1,
	                      $pdl2, $step2, $min2, $n2,
	                      ... );

Variables may be added using the same syntax as the constructor new():

	my $hist = ndbinning( $pdl1, ...,
	                      vars => [ [ $var1, $action1 ],
	                                [ $var2, $action2 ],
	                                ... ] );

If no variables are supplied, the behaviour of histogram() and histogram2d() is
emulated, i.e., an I<n>-dimensional histogram is produced. This function,
although more flexible than the former two, is likely slower. If all you need
is a one- or two-dimensional histogram, use histogram() and histogram2d()
instead. Note that, when no variables are supplied, the returned histogram is
of type I<long>, in contrast with histogram() and histogram2d(). The
histogramming is achieved by passing an action which simply counts the number
of elements in the bin.

Unlike the output of process(), the resulting piddles are output as an array
reference, in the same order as the variables passed in. There are as many
output piddles as variables, and exactly one output piddle if no variables have
been supplied. The output piddles take the type of the variables. All values in
the output piddles are initialized to the bad value, so missing bins can be
distinguished from zero.

=cut

sub ndbinning
{
	#
	my $binner = __PACKAGE__->new;

	# leading arguments are axes and axis specifications
	#
	# PDL overloads the `eq' and `ne' operators; by checking for a PDL
	# first, we avoid (invalid) comparisons between piddles and strings in
	# the `grep'
	my @leading = _consume { eval { $_->isa('PDL') } || ! $valid_key{ $_ } } @_;

	# consume and process axes
	# axes require three numerical specifications following it
	while( @leading > 3 && eval { $leading[0]->isa('PDL') } && ! grep ref, @leading[ 1 .. 3 ] ) {
		my( $pdl, $step, $min, $n ) = splice @leading, 0, 4;
		$binner->add_axis( name => _random_name, pdl => $pdl, step => $step, min => $min, n => $n );
	}
	if( @leading ) { PDL::Core::barf( "error parsing arguments in `@leading'" ) }

	# remaining arguments are key => value pairs
	my $args = { @_ };
	my @invalid_keys = grep ! $valid_key{ $_ }, keys %$args;
	PDL::Core::barf( "invalid key(s) @invalid_keys" ) if @invalid_keys;

	# axes
	$args->{axes} ||= [];
	my @axes = @{ $args->{axes} };
	for my $axis ( @axes ) {
		my $pdl = shift @$axis;
		$binner->add_axis( name => _random_name, pdl => $pdl, @$axis );
	}

	# variables
	$args->{vars} ||= [];
	for my $var ( @{ $args->{vars} } ) {
		if( @$var == 2 ) {
			my( $pdl, $action ) = @$var;
			$binner->add_var( name => _random_name, pdl => $pdl, action => $action );
		}
		else { PDL::Core::barf( "wrong number of arguments for var: @$var" ) }
	}

	#
	$binner->process;
	my $output = $binner->output;
	my @result = map $output->{ $_->{name} }, @{ $binner->vars };
	return wantarray ? @result : $result[0];
}

=head2 ndbin()

Calculates an I<n>-dimensional histogram from one or more piddles. The
arguments must be specified like in hist(). That is, each axis may be followed
by at most three specifications I<min>, I<max>, and I<step>, being the the
minimum value, maximum value, and the step size, respectively.

	my $hist = ndbin( $pdl1, $min1, $max1, $step1,
	                  $pdl2, $min2, $max2, $step2,
	                  ... );

Note that $step, $min, and $n may be omitted, and will be calculated
automatically from the data, as in hist(). Variables may be added using the
same syntax as the constructor new():

	my $hist = ndbin( $pdl1, ...,
	                  vars => [ [ $var1, $action1 ],
	                            [ $var2, $action2 ],
	                            ... ] );

If no variables are supplied, the behaviour of hist() is emulated, i.e., an
I<n>-dimensional histogram is produced. This function, although more flexible
than the other, is likely slower. If all you need is a one-dimensional
histogram, use hist() instead. Note that, when no variables are supplied, the
returned histogram is of type I<long>, in contrast with hist(). The
histogramming is achieved by passing an action which simply counts the number
of elements in the bin.

Unlike the output of process(), the resulting piddles are output as an array
reference, in the same order as the variables passed in. There are as many
output piddles as variables, and exactly one output piddle if no variables have
been supplied. The output piddles take the type of the variables. All values in
the output piddles are initialized to the bad value, so missing bins can be
distinguished from zero.

=cut

sub ndbin
{
	#
	my $binner = __PACKAGE__->new;

	# leading arguments are axes and axis specifications
	#
	# PDL overloads the `eq' and `ne' operators; by checking for a PDL
	# first, we avoid (invalid) comparisons between piddles and strings in
	# the `grep'
	if( my @leading = _consume { eval { $_->isa('PDL') } || ! $valid_key{ $_ } } @_ ) {
		my @axes = _expand_axes( @leading );
		$binner->add_axis( name => _random_name, %$_ ) for @axes;
	}

	# remaining arguments are key => value pairs
	my $args = { @_ };
	my @invalid_keys = grep ! $valid_key{ $_ }, keys %$args;
	PDL::Core::barf( "invalid key(s) @invalid_keys" ) if @invalid_keys;

	# axes
	$args->{axes} ||= [];
	my @axes = @{ $args->{axes} };
	for my $axis ( @axes ) {
		my $pdl = shift @$axis;
		$binner->add_axis( name => _random_name, pdl => $pdl, @$axis );
	}

	# variables
	$args->{vars} ||= [];
	for my $var ( @{ $args->{vars} } ) {
		if( @$var == 2 ) {
			my( $pdl, $action ) = @$var;
			$binner->add_var( name => _random_name, pdl => $pdl, action => $action );
		}
		else { PDL::Core::barf( "wrong number of arguments for var: @$var" ) }
	}

	$binner->process;
	my $output = $binner->output;
	my @result = map $output->{ $_->{name} }, @{ $binner->vars };
	return wantarray ? @result : $result[0];
}

1;

=head1 USAGE EXAMPLES

A one-dimensional histogram of height of individuals, binned between 0 and 2
metres, with the step size determined automatically:

	my $histogram = ndbin(
		axes => [ [ $height, min => 0, max => 2 ] ]
	);

This example can be expressed concisely using the interface that is compatible
with hist():

	my $histogram = ndbin( $height, 0, 2 );

If you wanted to specify the step size manually, you can do so by adding one
key-value pair to the first example, or by just adding the step
size in second example:

	my $histogram = ndbin(
		axes => [ [ $height, min => 0, max => 2, step => 0.1 ] ]
	);
	my $histogram = ndbin( $height, 0, 2, 0.1 );

Not all parameters can be specified in the compatibility interface, however. To
have your minimum and maximum rounded before binning requires using the full
notation. For example, to get a one-dimensional histogram of particle size,
with the sizes rounded to 0.01, the step size equal to 0.01, and minimum and
maximum determined automatically, you must write:

	my $histogram = ndbin(
		axes => [ [ $particle_size, round => 0.01, step => 0.01 ] ]
	);

Two- or multidimensional histograms are specified by enumerating the axes one
by one.

	my $histogram = ndbin(
		axes => [ [ $longitude ],
			  [ $latitude  ] ]
	);

$histogram will be a two-dimensional piddle! Using the compatibility interface,
this can be written as:

	my $histogram = ndbin( $longitude, $latitude );

Extra parameters for the axes are specified as follows:

	my $histogram = ndbin( $longitude, -70, 70, 20,
			       $latitude,  -70, 70, 20 );

A rather complete example of the interface:

	ndbin( axes => [ [ $longitude, min => -70, max => 70, step => 20 ],
			 [ $latitude,  min => -70, max => 70, step => 20 ] ],
	       vars => [ [ $ceres_flux, \&do_ceres_flux ],
			 [ $gl_flux,    \&do_gl_flux    ],
			 [ $gerb_flux,  \&do_gerb_flux  ] ],
	     );

Note that there is no assignment of the return value (in fact, there is none).
The actions are supposed to have meaningful side-effects. To achieve the same
using the compatibility interface, write:

	ndbin( $longitude, -70, 70, 20,
	       $latitude,  -70, 70, 20,
	       vars => [ [ $ceres_flux, \&do_ceres_flux ],
			 [ $gl_flux,    \&do_gl_flux    ],
			 [ $gerb_flux,  \&do_gerb_flux  ] ],
	     );

More simple examples:

	my $histogram = ndbin( $x );
	my $histogram = ndbin( $x, $y );
	my $histogram = ndbin( axes => [ [ $x, min => 0, max => 10, n => 5 ] ] );

And an example where the result does not contain the count, but rather the
averages of the binned fluxes:

	my $result = ndbin(
			axes => [ [ $longitude, round => 10, step => 20 ],
				  [ $latitude,  round => 10, step => 20 ] ],
			vars => [ [ $flux => sub { shift->selection->avg } ] ],
		     );

=head1 IMPLEMENTATION DETAILS

=head2 Lowest and highest bin

All data equal to or less than the minimum (either supplied or automatically
determined) will be binned in the lowest bin. All data equal to or larger than
the maximum (either supplied or automatically determined) will be binned in the
highest bin. This is a slight asymmetry, as all other bins contain their lower
bound but not their upper bound. However, it does the right thing when binning
floating-point data.

=head2 Flattening multidimensional bin numbers

In PDL, the first dimension is the contiguous dimension, so we have to work
back from the last axis to the first when building the flattened bin number.

Here are some examples of flattening multidimensional bins into one dimension:

	(i) = i
	(i,j) = j*I + i
	(i,j,k) = (k*J + j)*I + i = k*J*I + j*I + i
	(i,j,k,l) = ((l*K + k)*J + j)*I + i = l*K*J*I + k*J*I + j*I + i

=head2 Actions

You are required supply an action with every variable. An action can be either
a code reference (i.e., a reference to a subroutine, or an anonymous
subroutine), or the name of a class that implements the methods new(),
process() and result().

It is important to note that the actions will be called in the order they are
given for each bin, before proceeding to the next bin. You can depend on this
behaviour, for instance, when you have an action that depends on the result of
a previous action within the same bin.

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
coded in XS.

=head2 Iteration strategy

By default, ndbin() will loop over all bins, and create a piddle per bin
holding only the values in that bin. This piddle is accessible to your actions
via the iterator object. This ensures that every action will only see the data
in one bin at a time. You need to do this when, e.g., you are taking the
average of the values in a bin with the standard PDL function avg(). However,
the selection and extraction of the data is time-consuming. If you have an
action that knows how to deal with indirection, you can do away with the
selection and extraction. Examples of such actions are:
PDL::NDBin::Action::Count, PDL::NDBin::Action::Sum, etc. They take the original
data and the flattened bin numbers and produce an output piddle in one step.

Note that empty bins are not skipped. If you want to use an action that cannot
handle empty piddles, you can wrap the action as follows to skip empty bins:

	sub { my $iter = shift; return unless $iter->want->nelem; ... }

Remember that return I<undef> from the action will not fill the current bin.
Note that the evaluation of C<<$iter->want>> entails a performance penalty,
even if the bin is empty and not processed further.

=head2 Automatic parameter calculation

=head3 Range

The range, when not given explicitly, is calculated from the data by calling
min() and max(). An exception will be thrown if the data range is zero.

=head3 Number of bins

The number of bins I<n>, when not given explicitly, is determined
automatically. If the step size is not defined, PDL::NDBin assumes the default
behaviour of hist(). If the number of elements of data is 100 or less, the
number of bins equals the number of elements. Otherwise, the number of bins
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
I<n> is ultimately used in the binning, it is converted to I<int> by
truncating. To have sufficient bins, I<n> must be rounded up to the next
integer. The correct formula for calculating the number of bins is therefore

	n = ceil( ( range + 1 ) / step )

In the implementation, however, it is easier to calculate I<n> as it is done
for floating-point data, and increment it by one, before it is truncated. The
following formula is how I<n> is calculated by the code:

	n = floor( range/step + 1 )

Using the following identity from
L<http://en.wikipedia.org/wiki/Floor_and_ceiling_functions>, both formulas can
be proved to be equivalent:

	ceil( x/y ) = floor( (x+y-1)/y )

	XXX the docs are out of sync here: we truncate in _auto_axis()
	because we were having trouble with PDL doing conversion to double on
	$idx = $idx * $n + $binned
	when $n is fractional (i.e., PDL doesn't truncate); but this is
	expected to go away when we reimplement the flattening in XS, since in
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
by PDL::NDBin, as described above.

=head2 Probing PDL::NDBin's parameters

=head3 Find the total number of bins

	my $binner = PDL::NDBin->new( axes => [ [ 'x', step => 10, min => ... ], [ 'y', ... ] ] );
	$binner->autoscale( x => $x, y => $y );
	my $N = List::Util::reduce { our $a * our $b } map { $_->{n} } $binner->axes;

=cut

=head1 USEFUL EXTRA'S

To hook a progress bar to ndbin():

	use Term::ProgressBar::Simple;
	my $binner = PDL::NDBin->new(
		axes => \@axes,
		vars => [ [ ... ],
			  [ 'dummy' => sub { $progress++; return } ] ]
	);
	$binner->autoscale( x => ... );
	my $N = List::Util::reduce { $a * $b } map { $_->{n} } $binner->axes;
	my $progress = Term::ProgressBar::Simple->new( $N );
	$binner->process();

Note that the progress bar updater returns I<undef>. You
probably do not want to return the result of C<$progress++>! If you were to
capture the return value of ndbin(), a piddle would be returned that holds the
return values of the progress bar updater. You probably do not want this
either. By putting the progress bar updater last, you can simply ignore that
piddle.

=head1 SEE ALSO

=over 4

=item *

The PDL::NDBin::Action:: namespace

=item *

The L<PDL> documentation

=back

There are a few histogramming modules on CPAN:

=over 4

=item *

L<PDL::Basic> offers the histogramming functions hist(), whist()

=item *

L<PDL::Primitive> offers the histogramming functions histogram(),
histogram2d(), whistogram(), whistogram2d()

=item *

L<Math::GSL::Histogram> and L<Math::GSL::Histogram2D>

=item *

L<Math::Histogram>

=item *

L<Math::SimpleHisto::XS>

=back

The following sections give a detailed overview of features, limitations, and
performance of PDL::NDBin and related distributions on CPAN.

=head1 FEATURES AND LIMITATIONS

The following table gives an overview of the features and limitations of
PDL::NDBin and related distributions on CPAN:

	+---------------------------------------------------+---------+--------+--------+-----------+----------+
	| Feature                                           | MGH     | MH     | MSHXS  | PDL       | PND      |
	+---------------------------------------------------+---------+--------+--------+-----------+----------+
	| Allows piecewise data processing                  | -       | -      | -      | -         | X        |
	| Allows resampling the histogram                   | -       | -      | X      | X         | -        |
	| Automatic parameter calculation based on the data | -       | -      | -      | X         | X        |
	| Bad value support                                 | -       | -      | -      | X         | X        |
	| Can bin multiple variables at once                | -       | -      | -      | -         | X        |
	| Core implementation                               | C       | C      | C      | C         | C/Perl   |
	| Define and use callbacks to apply to the bins     | -       | -      | -      | -         | Perl+C   |
	| Facilities for data structure serialization       | X       | X      | X      | X         | -        |
	| Has overflow and underflow bins by default        | -       | X      | X      | -         | -        |
	| Interface style                                   | Proc.   | OO     | OO     | Proc.     | OO+Proc. |
	| Maximum number of dimensions                      | 2       | N      | 1      | 2         | N        |
	| Native data type                                  | Scalars | Arrays | Arrays | Piddles   | Piddles  |
	| Performance                                       | Low     | Medium | High   | Very high | High     |
	| Support for weighted histograms                   | X       | X      | X      | X         | -        |
	| Uses PDL threading                                | -       | -      | -      | X         | -        |
	| Variable-width bins                               | X       | X      | X      | -         | -        |
	+---------------------------------------------------+---------+--------+--------+-----------+----------+

	  MGH   = Math::GSL 0.26 (Math::GSL::Histogram and Math::GSL::Histogram2D)
	  MH    = Math::Histogram 1.03
	  MSHXS = Math::SimpleHisto::XS 1.28
	  PDL   = PDL 2.4.11
	  PND   = PDL::NDBin 0.003

An explanation and discussion of each of the futures is provided below.

=over 4

=item Allows piecewise data processing

The ability to process data piecewise means that the input data (i.e., the data
points) required to produce the output (e.g., a histogram) do not have to be
fed all at once. Instead, the input data can be fed in chunks of any size. The
resulting output is of course identical, whether the input data be fed
piecewise or all at once. However, the input data do not have to fit in memory
all at once, which is very useful when dealing with very large data sets.

An example may help to understand this feature. Suppose you want to calculate
the monthly mean cloud over over an area of the globe, in boxes of 1 by 1
degree. The total amount of cloud cover data is too large to fit in memory, but
fortunately, the data are spread of several files, one by day. With PDL::NDBin,
you can do the following:

	my $binner = PDL::NDBin->new(
		axes => [[ 'latitude',    min => -60, max => 60, step => 1 ],
			 [ 'longitude',   min => -60, max => 60, step => 1 ]],
		vars => [[ 'cloud_cover', 'Avg' ]],
	);
	for my $file ( @all_files ) {
		# suppose $file contains the geolocated cloud cover data for
		# one day of the month
		my $lat = $file->read( 'latitude' );
		my $lon = $file->read( 'longitude' );
		my $cc  = $file->read( 'cloud_cover' );
		$binner->process( latitude    => $lat,
				  longitude   => $lon,
				  cloud_cover => $cc );
	}
	my $avg = $binner->output->{cloud_cover};

In this example, only the data of a single day have to be kept in memory. The
$binner object keeps a running average of the data, and retains the proper
counts until the output $avg must be generated.

Only PDL::NDBin offers this feature. It can be simulated with other libraries
for histograms, as long as histograms can be added together. PDL::NDBin extends
the feature of piecewise data processing to sums, averages, and standard
deviations.

=item Allows resampling the histogram

To resample a histogram means to put in a histogram of I<N> bins, the data that
were originally in a histogram of I<M> bins, where I<N> and I<M> are different.

Only Math::SimpleHisto::XS and PDL support this feature. In PDL, the function
is known as rebin() (to be found in L<PDL::ImageND>).

=item Automatic parameter calculation based on the data

If a minimum bin, maximum bin, or step size are not supplied, PDL and
PDL::NDBin will calculate them from the data. Other libraries require the user
to specify them manually.

=item Bad value support

Bad value support, when it is present, allows to distinguish missing or invalid
data from valid data. The missing or invalid data are excluded from the
processing. Only the PDL-based libraries PDL and PDL::NDBin support bad values.

=item Can bin multiple variables at once

When data is co-located, e.g., cloud cover, cloud phase, and cloud optical
thickness on a latitude-longitude grid, some time can be saved by binning the
cloud variables together. Once the bin number has been determined for the given
latitude and longitude, it can be reused for all cloud variables. This is
marginally faster than binning the cloud variables separately. Only PDL::NDBin
supports this feature.

=item Core implementation

Math::GSL::Histogram is a wrapper around the GSL library, which is written in
C.

Math::Histogram is a wrapper around an I<N>-dimensional histogramming library
written in C.

Math::SimpleHisto::XS, by the same author as Math::Histogram, is implemented in
C.

The core histogramming functions of PDL are implemented in C.

The core loops of PDL::NDBin are implemented partly in Perl, partly in C.

=item Define and use callbacks to apply to the bins

PDL::NDBin can handle any type of calculation on the values in the bins that
you can express in Perl or C, not only counting the number of elements in order
to produce a histogram. At the time of writing (version 0.003), PDL::NDBin
supports counting, summing, averaging, and taking the standard deviation of the
values in each bin. Additionally, Perl or C subroutines can be defined and used
to perform any operation on the values in each bin.

This feature, arguably the most important feature of PDL::NDBin, is not found
in other modules.

=item Facilities for data structure serialization

Serialization is the process of storing a histogram to disk, or retrieving it
from disk. Math::GSL::Histogram, Math::Histogram, Math::SimpleHisto::XS, and
PDL all have built-in support for serialization. PDL::NDBin doesn't, but the
serialization facilities of PDL can be used to store and retrieve data. (I
usually store computed data in netCDF files with PDL::NetCDF.)

=item Has overflow and underflow bins by default

Data lower than the lowest range of the first bin, or higher than the highest
range of the last bin, are treated differently in different modules.

Math::GSL::Histogram ignores out-of-range values.

Math::Histogram and Math::SimpleHisto::XS have overflow bins, i.e., by default
they create more bins than you define. These so-called overflow bins are
situated at either end of every dimension. Out-of-range values end up in the
overflow bins.

The histogramming functions of PDL, and PDL::NDBin, store low out-of-range
values in the first bin, and high out-of-range values in the last bin.

To ignore out-of-range values with PDL::NDBin, define two additional bins at
either end of every dimension, and disregard the values in these additional
bins.

To simulate overflow and underflow bins with PDL::NDBin, define two additional
bins at either end of every dimension.

=item Interface style

I<Proc.> means that the module has a procedural interface. I<OO> means that the
module has an object-oriented interface. PDL::NDBin has both. Which interface
you should use is largely a matter of preference, unless you want to use
advanced features such as piecewise data feeding, which require the
object-oriented interface.

Math::GSL::Histogram has a somewhat awkward interface, requiring the user to
explicitly deallocate the data structure after use.

=item Maximum number of dimensions

The maximum number of dimensions that can be processed. Math::Histogram and
PDL::NDBin can handle an arbitrary number of dimensions.

=item Native data type

Obviously, deep down, all data values are just C scalars. By 'native data type'
is meant the data type used to communicate with the library in the most
efficient way.

At the time of writing (Math::GSL version 0.27), Math::GSL::Histogram did not
have a facility to enter multiple data points at once. It accepts only Perl
scalars, and requires the user to input the data points one by one. Similarly,
to produce the final histogram, the bins must be queried one by one.

Math::Histogram and Math::SimpleHisto::XS accept Perl arrays filled with values
(although they also accept data points one by one as Perl scalars). Passing
large amounts of data as arrays is generally more efficient than passing the
data points one by one as scalars.

PDL and PDL::NDBin operate on piddles only, which are memory-efficient, packed
data arrays. This could be considered both an advantage and a disadvantage. The
advantage is that the piddles can be operated on very efficiently in C. The
disadvantage is that PDL is required!

=item Performance

In the next section (see L<PERFORMANCE>), the performance of all modules is
examined in detail.

=item Support for weighted histograms

In a weighted histogram, data points contribute by a fractional amount (or
weight) between 0 and 1. All libraries, except PDL::NDBin, support weighted
histograms. In PDL::NDBin, the weight of all data points is fixed at 1.

=item Uses PDL threading

In PDL, threading is a technique to automatically loop certain operations over
an arbitrary number of dimensions. An example is the sumover() operation, which
calculates the row sum. It is defined over the first dimension only (i.e., the
rows in PDL), but it will be looped automatically over all remaining
dimensions. If the piddle is three-dimensional, for instance, sumover() will
calculate the sum in every row of every matrix.

Threading is supported by the PDL functions histogram(), whistogram(), and
their two-dimensional counterparts, but not by hist() or whist(). At the time
of writing, PDL::NDBin does not support threading.

=item Variable-width bins

In a histogram with variable-width bins, the width of the bins needn't be
equal. This feature can be useful, for example, to construct bins on a
logarithmic scale. Math::GSL, Math::Histogram, and Math::SimpleHisto::XS
support variable-width bins; PDL and PDL::NDBin do not and are limited to
fixed-width bins.

=back

=head1 PERFORMANCE

=head2 One-dimensional histograms

This section aims to give an idea of the performance of PDL::NDBin. Some of the
most important features of PDL::NDBin aren't found in other modules on CPAN.
But there are a few histogramming modules on CPAN, and it is interesting to
examine how well PDL::NDBin does in comparison.

I've run a number of tests with PDL version 0.003 on a laptop with an Intel i3
CPU running at 2.40 GHz, and on a desktop with an Intel i7 CPU running at 2.80
GHz and fast disks. The following table, obtained with 100 bins and a data file
of 2 million data points, shows typical results on the laptop:

	Benchmark: timing 50 iterations of MGH, MH, MSHXS, PND, hist, histogram...
	       MGH: 40 wallclock secs (40.43 usr +  0.08 sys = 40.51 CPU) @  1.23/s (n=50)
		MH:  6 wallclock secs ( 5.57 usr +  0.01 sys =  5.58 CPU) @  8.96/s (n=50)
	     MSHXS:  2 wallclock secs ( 2.22 usr +  0.01 sys =  2.23 CPU) @ 22.42/s (n=50)
	       PND:  2 wallclock secs ( 1.44 usr +  0.00 sys =  1.44 CPU) @ 34.72/s (n=50)
	      hist:  1 wallclock secs ( 1.26 usr +  0.01 sys =  1.27 CPU) @ 39.37/s (n=50)
	 histogram:  1 wallclock secs ( 1.08 usr +  0.00 sys =  1.08 CPU) @ 46.30/s (n=50)

	Relative performance:
	            Rate       MGH        MH     MSHXS       PND      hist histogram
	MGH       1.23/s        --      -86%      -94%      -96%      -97%      -97%
	MH        8.96/s      626%        --      -60%      -74%      -77%      -81%
	MSHXS     22.4/s     1717%      150%        --      -35%      -43%      -52%
	PND       34.7/s     2713%      288%       55%        --      -12%      -25%
	hist      39.4/s     3090%      339%       76%       13%        --      -15%
	histogram 46.3/s     3651%      417%      106%       33%       18%        --

From this test and other tests, it can be concluded that PDL::NDBin (shown as
'PND' in the table) is, roughly speaking,

=over 4

=item 1. faster than Math::GSL::Histogram (shown as MGH in the table)

Although this module is actually a wrapper around the C library GSL, the
performance is rather low. The process of getting a large number of data points
into Math::GSL::Histogram's data structures is inefficient, as the data points
have to be input one by one.

=item 2. faster than Math::Histogram (shown as MH)

This library wraps another multidimensional histogramming library written in C.
It allows inputting multiple data points at once. It is quite a bit faster than
Math::GSL::Histogram, but does not offer the raw performance of PDL or
Math::Histogram's cousin Math::SimpleHisto::XS.

=item 3. faster than Math::SimpleHisto::XS (shown as MSHXS)

Math::SimpleHisto::XS, by the same author as Math::Histogram, is similar to the
latter library, but implemented in XS for speed, and limited to one-dimensional
histograms. It is generally somewhat slower than PDL::NDBin, but outperforms it
for small files or large bin counts (10,000 bins or more).

=item 4. slower than PDL

Although PDL::NDBin outperforms hist() by 10 to 20% in some of the tests, PDL's
built-in functions hist() and histogram() are, on average, the fastest
functions. Given that the core of these routines runs in pure C, this is not
very surprising. The PDL functions have very low overhead and are very
memory-efficient.

=back

Note that, in the tests, various data conversions between piddles and ordinary
Perl arrays were required. The timings exclude these conversions, and count
only the time required to produce a histogram from the "natural" data
structure, i.e. piddles for PDL-based modules, and ordinary Perl arrays for the
other modules.

Note also that the histograms produced by the different methods were verified
to be equal.

=head2 Two-dimensional histograms

Similar conclusions are obtained for two-dimensional histograms. The following
table shows results on the laptop for 2 million data points with 100 bins:

	Benchmark: timing 50 iterations of MGH2d, PND2d, histogram2d...
	      MGH2d: 59 wallclock secs (58.97 usr +  0.24 sys = 59.21 CPU) @  0.84/s (n=50)
	      PND2d:  6 wallclock secs ( 5.92 usr +  0.00 sys =  5.92 CPU) @  8.45/s (n=50)
	histogram2d:  2 wallclock secs ( 2.18 usr +  0.00 sys =  2.18 CPU) @ 22.94/s (n=50)

	Relative performance:
		       Rate       MGH2d       PND2d histogram2d
	MGH2d       0.844/s          --        -90%        -96%
	PND2d        8.45/s        900%          --        -63%
	histogram2d  22.9/s       2616%        172%          --

(It was not possible to run the test with Math::Histogram to completion.)

=head2 Scaling w.r.t. number of data points

Performance figures for a few tests on a particular machine don't say much. As
PDL::NDBin is intended to handle large amounts of data, it is important to
check how well PDL::NDBin's performance scales as the problem size increases.

The first and most obvious way in which a problem may be 'large', is the number
of data points. If a given method cannot process a large number of data points,
or can only do so with increased effort, it is not suitable for large problems.
How large that is, depends on the application, but in the field of satellite
data retrieval (where I work), 33 million data points is not exceptional at all
(but it is the largest size I could test). In this section, we examine how well
PDL::NDBin's performance scales with the number of data points, and compare
with alternative modules.

The following table shows timing data on the laptop for 100 bins, but with a
variable number of data points:

	+-----------+------------+----------+------+------------+------------------+
	| method    |   # points | CPU time |    n | time/iter. | time/iter./point |
	|           |            |      (s) |      |       (ms) |             (ns) |
	+-----------+------------+----------+------+------------+------------------+
	| MGH       |     66,398 |    36.63 | 1500 |     24.420 |          367.782 |
	| MGH       |  2,255,838 |    40.51 |   50 |    810.200 |          359.157 |
	+-----------+------------+----------+------+------------+------------------+
	| MH        |     66,398 |     5.17 | 1500 |      3.447 |           51.909 |
	| MH        |  2,255,838 |     5.58 |   50 |    111.600 |           49.472 |
	+-----------+------------+----------+------+------------+------------------+
	| MSHXS     |     66,398 |     1.95 | 1500 |      1.300 |           19.579 |
	| MSHXS     |  2,255,838 |     2.23 |   50 |     44.600 |           19.771 |
	+-----------+------------+----------+------+------------+------------------+
	| PND       |     66,398 |     2.85 | 1500 |      1.900 |           28.615 |
	| PND       |  2,255,838 |     1.44 |   50 |     28.800 |           12.767 |
	| PND       | 33,358,558 |     2.36 |    5 |    472.000 |           14.149 |
	+-----------+------------+----------+------+------------+------------------+
	| histogram |     66,398 |     0.96 | 1500 |      0.640 |            9.639 |
	| histogram |  2,255,838 |     1.08 |   50 |     21.600 |            9.575 |
	| histogram | 33,358,558 |     1.62 |    5 |    324.000 |            9.713 |
	+-----------+------------+----------+------+------------+------------------+

Note that the tests couldn't be run with Math::GSL::Histogram, Math::Histogram,
and Math::SimpleHisto::XS on the largest data file (33 million points), due to
insufficient memory.

The methods show a linear increase in time per iteration with the number of
data points, which translates to a fixed time per iteration per data point.
This is the desired behaviour: it guarantees that the effort required to
produce a histogram does not increase faster than the problem size. Every
method examined here displays this behaviour.

Quite notable is the high CPU time per iteration per data point of PDL::NDBin
for small data files. For large data files, the time per iteration per data
point is more or less constant. This effect is not fully understood, but may
indicate high overhead or start-up cost.

The results suggest that PDL::NDBin scales well with the number of data points,
and that it is therefore well suited for large data. PDL::NDBin and histogram()
(and hist()) are currently the only methods that allow processing very large
data files.

=head2 Scaling w.r.t. number of bins

The number of data points may not be the only way in which a problem may be
'large' or hard. The number of bins may also be high. In applications with
satellite data, for instance, a latitude/longitude grid with a resolution of
only 5 degrees already yields more than 2000 bins, and raising the resolution
to 1 degree yields approximately 64,000 bins.

Most of the methods depend in some way on the number of bins. If the execution
time depends to a significant extent on the number of bins, the method is not
suitable for large numbers of bins. In this section, we examine how well
PDL::NDBin's performance scales with the number of bins, and compare with
alternative modules.

The following table shows timing data on the laptop for 2 million data points,
with a variable number of bins:

	+-----------+---------+----------+----+------------+
	| method    |  # bins | CPU time |  n | time/iter. |
	|           |         |      (s) |    |       (ms) |
	+-----------+---------+----------+----+------------+
	| MGH       |      10 |    40.72 | 50 |    814.400 |
	| MGH       |      50 |    41.20 | 50 |    824.000 |
	| MGH       |     100 |    40.51 | 50 |    810.200 |
	+-----------+---------+----------+----+------------+
	| MH        |      10 |     5.49 | 50 |    109.800 |
	| MH        |      50 |     5.55 | 50 |    111.000 |
	| MH        |     100 |     5.58 | 50 |    111.600 |
	| MH        |   1,000 |     5.69 | 50 |    113.800 |
	+-----------+---------+----------+----+------------+
	| MSHXS     |      10 |     2.20 | 50 |     44.000 |
	| MSHXS     |      50 |     2.22 | 50 |     44.400 |
	| MSHXS     |     100 |     2.23 | 50 |     44.600 |
	| MSHXS     |   1,000 |     2.26 | 50 |     45.200 |
	| MSHXS     |  10,000 |     2.29 | 50 |     45.800 |
	| MSHXS     | 100,000 |     2.64 | 50 |     52.800 |
	+-----------+---------+----------+----+------------+
	| PND       |      10 |     1.41 | 50 |     28.200 |
	| PND       |      50 |     1.42 | 50 |     28.400 |
	| PND       |     100 |     1.44 | 50 |     28.800 |
	| PND       |   1,000 |     1.74 | 50 |     34.800 |
	| PND       |  10,000 |     4.90 | 50 |     98.000 |
	| PND       | 100,000 |    36.82 | 50 |    736.400 |
	+-----------+---------+----------+----+------------+
	| histogram |      10 |     1.09 | 50 |     21.800 |
	| histogram |      50 |     1.34 | 50 |     26.800 |
	| histogram |     100 |     1.08 | 50 |     21.600 |
	| histogram |   1,000 |     1.13 | 50 |     22.600 |
	| histogram |  10,000 |     1.12 | 50 |     22.400 |
	| histogram | 100,000 |     1.20 | 50 |     24.000 |
	+-----------+---------+----------+----+------------+

Note that some data are missing because the associated test didn't run
successfully (e.g., segmentation fault).

The methods show more or less constant execution time per iteration,
independent of the number of bins. This is the desired behaviour: the overhead
of managing the bins does not dominate the execution time.

Quite notable is the behaviour of PDL::NDBin at high bin counts: beyond 1,000
bins, execution time rises significantly. The cause of this problem is not
known.

The results suggest that PDL::NDBin scales well with the number of bins up to
1,000. Beyond 1,000 bins, the performance decreases significantly. Only
Math::SimpleHisto::XS, PDL::NDBin, and histogram() are able to work with very
high bin counts.

=head1 BUGS

None reported.

=head1 TODO

This documentation is unfortunately quite incomplete, due to lack of time.

What PDL::NDBin doesn't do (yet):

=over 4

=item Collecting the actual values in a bin

This would be very useful for plotting or output.

=back

=head1 AUTHOR

Edward Baudrez, ebaudrez@cpan.org, 2011, 2012.

=head1 COPYRIGHT and LICENSE

=cut
