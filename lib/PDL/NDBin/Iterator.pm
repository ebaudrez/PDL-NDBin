package PDL::NDBin::Iterator;
# ABSTRACT: Iterator object for PDL::NDBin

use strict;
use warnings;
use Carp;
use List::Util qw( reduce );

=head1 DESCRIPTION

This class provides an iterator object for PDL::NDBin. The iterator object is
used to systematically step through all bins and variables using a simple
interface. Actions will receive a PDL::NDBin::Iterator object as the first and
only argument. This object can then be used to retrieve the current bin and
variable, and other information.

=head1 METHODS

=cut

=head2 new()

	my $iter = PDL::NDBin::Iterator->new( \@bins, \@array, $idx );

Construct a PDL::NDBin::Iterator object. Requires three arguments:

=over 4

=item \@bins

A reference to an array containing the number of bins per dimension. E.g.,
C<[ 4, 7 ]> to indicate 4 bins in the first (contiguous) dimension, and 7 bins
in the second dimension. There must be at least one bin in every dimension.

=item \@array

A reference to an array of piddles to operate on. The data values inside the
piddles don't really matter, as far as the iterator object is concerned. The
data inside the piddles will be made available to the actions in the order they
appear, one by one. There must be at least one element in this array.

=item $idx

A piddle containing the flattened bin numbers corresponding to the data values
in the piddles in \@array. The length of this piddle must match the length of
the piddles in \@array.

=back

=cut

sub new
{
	my $class = shift;
	my( $bins, $array, $idx ) = @_;
	grep { ! ($_ > 0) } @$bins and croak 'new: need at least one bin along every dimension';
	@$array or croak 'new: need at least one element in the array';
	defined $idx or croak 'new: need a list of flattened bin numbers';
	my $self = {
		bins   => $bins,
		array  => $array,
		idx    => $idx,
		active => [ (1) x @$array ],
		bin    => 0,
		var    => -1,
		nbins  => (reduce { $a * $b } @$bins),
		nvars  => (scalar @$array),
	};
	return bless $self, $class;
}

=head2 advance()

	while( $iter->advance ) { ... }

Advance the iterator to the next bin and/or I<active> variable. If no bins or
active variables remain, return C<undef> to signal that the iteration is done.
Otherwise, return 1.

=cut

sub advance
{
	my $self = shift;
	return if $self->{bin} >= $self->{nbins};			# return if $self->done;
	for( ;; ) {
		undef $self->{selection};				# we're switching to a new var!
		if( ++$self->{var} >= $self->{nvars} ) {
			$self->{var} = 0;
			return if ++$self->{bin} >= $self->{nbins};	# return if $self->done;
			undef $self->{want};				# we're switching to a new bin!
			undef $self->{unflattened};
		}
		last if $self->{active}->[ $self->{var} ];		# last if $self->var_active;
	}
	return 1;
}

=head2 bin()

Return the current bin number.

=head2 var()

Return the current variable index, i.e., the index into $self->{array} that
points to the current variable.

=head2 done()

Return a boolean value indicating whether there remain bins or variables to
visit.

=head2 bins()

Return a reference to the @bins array passed to the constructor.

=head2 nbins()

Return the total number of bins.

=head2 nvars()

Return the number of variables.

=head2 data()

Return the piddle corresponding to the current variable.

=head2 idx()

Return the piddle $idx passed to the constructor.

=cut

sub bin   { $_[0]->{bin} }
sub var   { $_[0]->{var} }
sub done  { $_[0]->{bin} >= $_[0]->{nbins} }
sub bins  { @{ $_[0]->{bins} } }
sub nbins { $_[0]->{nbins} }
sub nvars { $_[0]->{nvars} }
sub data  { $_[0]->{array}->[ $_[0]->{var} ] }
sub idx   { $_[0]->{idx} }

=head2 var_active()

This method is either a getter or a setter, depending on whether an argument is
supplied.

If no arguments are supplied: return whether the current variable is still
active, i.e., whether any bins remain to be computed. If all bins have been
computed for this variable, the variable is inactive.

If a boolean is supplied: mark the current variable active or inactive. An
inactive variable will be skipped by next(). An action may mark a variable
inactive if it knows that all bins have been computed already, and that
visiting the same variable again may either be redundant or wrong. For example,
the action L<PDL::NDBin::Action::Count> can deal with the indirection in $idx,
and counts the elements of all bins the first time it is called. Visiting the
same variable again would double-count the elements. Therefore, the variable
must be marked inactive after the first time it has been visited.

	# if all bins have been set for this variable, mark inactive
	$iter->var_active( 0 );

=cut

sub var_active
{
	my $self = shift;
	my $i = $self->{var};
	if( @_ ) { $self->{active}->[ $i ] = shift }
	else { $self->{active}->[ $i ] }
}

=head2 want()

Return the indices of the elements that fall in the current bin. Not very
useful in regular actions, except for the common case where only the number of
elements is of importance (see L<PDL::NDBin::Action::Count>):

	my $nelem = $iter->want->nelem;

Another use is when empty bins needs to be skipped:

	sub compute_maximum {
		my $iter = shift;
		# max() won't work with empty piddles
		return unless $iter->want->nelem;
		my $values = $iter->selection;
		return $values->max;
	}

Please note that the indexing is time-consuming. However, once computed, the
indices are cached for the remainder of the current bin and variable.

=cut

sub want
{
	my $self = shift;
	unless( defined $self->{want} ) {
		$self->{want} = PDL::which $self->idx == $self->{bin};
	}
	return $self->{want};
}

=head2 selection()

Return the data values that actually fall in the current bin for the current
variable. This is usually the only method that you need to call in an action.

	sub compute_median {
		my $iter = shift;
		my $values = $iter->selection;
		return $values->median;
	}

Please note that the extraction is time-consuming (and requires the indexing).
However, once computed, the values are cached for the remainder of the current
bin and variable.

=cut

sub selection
{
	my $self = shift;
	unless( defined $self->{selection} ) {
		$self->{selection} = $self->data->index( $self->want );
	}
	return $self->{selection};
}

=head2 unflatten()

Return the unflattened bin number, i.e., the bin number along each axis
(cached). For example, if there 4 bins along the first dimension, and 7 along
the second, and the current bin number is 9, calling

	my @pos = $iter->unflatten;

will set @pos to C<( 1, 2 )>.

=cut

sub unflatten
{
	my $self = shift;
	unless( defined $self->{unflattened} ) {
		my $q = $self->{bin}; # quotient
		$self->{unflattened} =
			[ map {
				( $q, my $r ) = do { use integer; ( $q / $_, $q % $_ ) };
				$r
			      } $self->bins
			];
	}
	return @{ $self->{unflattened} };
}

1;
