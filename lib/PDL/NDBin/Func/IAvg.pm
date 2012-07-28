package PDL::NDBin::Func::IAvg;

use strict;
use warnings;
use PDL::Lite;		# do not import any functions into this namespace
use PDL::NDBin::Func::PP;

sub new
{
	my $class = shift;
	my $m = shift;
	return bless { m => $m }, $class;
}

sub process
{
	my $self = shift;
	my $iter = shift;
	$self->{out} = PDL->zeroes( PDL::double, $self->{m} ) unless defined $self->{out};
	$self->{count} = PDL->zeroes( PDL::long, $self->{m} ) unless defined $self->{count};
	PDL::NDBin::Func::PP::_iavg_loop( $iter->data, $iter->hash, $self->{out}, $self->{count}, $self->{m} );
	# as the plugin processes all bins at once, every variable
	# needs to be visited only once
	$iter->var_active( 0 );
}

sub result
{
	my $self = shift;
	PDL::NDBin::Func::PP::_setnulltobad( $self->{count}, $self->{out} );
	return $self->{out};
}

1;
__END__
=head2 iavg

Compute the average of the elements in each bin.

Signature:

	iavg( in(n), ind(n), m )

Usage:

	$out = iavg( $in, $ind, $m );

where $in and $ind are of dimension I<n>, and $out is of dimension I<m>.

Description:

Credit for the algorithm goes to
L<http://www.commandlinefu.com/commands/view/3437/compute-running-average-for-a-column-of-numbers>:

	awk '{avg += ($1 - avg) / NR;} END { print avg; }'

This is a wonderful solution solving many of the problems with more naive
implementations:

=over 4

=item 1.

It's numerically well-behaved: out() is always of the order of magnitude of the
values themselves, unlike the sum of the values, which grows very large as the
number of elements grows large

=item 2.

The subtraction in() - out() guarantees that the computation will be done in
the correct type (i.e., I<double> instead of the type of the input)

=item 3.

Requires only one temporary

=item 4.

Requires only one pass over the data

=back

I used to give the output array type I<float+>, but that creates more problems
than it solves. So now, averages are always computed in type I<double>. Besides
being the default type in PDL and the `natural' floating-point type in C, it
also makes the implementation easier.

=cut
