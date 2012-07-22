package PDL::NDBin::Func::IStdDev;

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
	my $in = shift;
	my $ind = shift;
	$self->{out} = PDL->zeroes( PDL::double, $self->{m} ) unless defined $self->{out};
	$self->{count} = PDL->zeroes( PDL::long, $self->{m} ) unless defined $self->{count};
	$self->{avg} = PDL->zeroes( PDL::double, $self->{m} ) unless defined $self->{avg};
	PDL::NDBin::Func::PP::_istddev_loop( $in, $ind, $self->{out}, $self->{count}, $self->{avg}, $self->{m} );
}

sub result
{
	my $self = shift;
	PDL::NDBin::Func::PP::_istddev_post( $self->{count}, $self->{out} );
	return $self->{out};
}

1;
__END__
=head2 istddev

Compute the standard deviation of the elements in each bin. Note, we compute
the sample standard deviation, I<not> an estimate of the population standard
deviation (which differs by a factor).

Signature:

	istddev( in(n), ind(n), m )

Usage:

	$out = istddev( $in, $ind, $m );

where $in and $ind are of dimension I<n>, and $out is of dimension I<m>.

Description:

Credit for the algorithm goes to
L<http://www.commandlinefu.com/commands/view/3442/display-the-standard-deviation-of-a-column-of-numbers-with-awk>;

	awk '{delta = $1 - avg; avg += delta / NR; mean2 += delta * ($1 - avg); } END { print sqrt(mean2 / NR); }'

This is a wonderful solution solving many of the problems with more naive
implementations:

=over 4

=item 1.

It's numerically well-behaved

=item 2.

The subtractions guarantee that the computations will be done in the correct
type (i.e., I<double> instead of the type of the input)

=item 3.

Requires only two temporaries (!)

=item 4.

Requires only one pass over the data

=back

I used to give the output array type I<float+>, but that creates more problems
than it solves. So now, standard deviations are always computed in type
I<double>. Besides being the default type in PDL and the `natural'
floating-point type in C, it also makes the implementation easier.

=cut
