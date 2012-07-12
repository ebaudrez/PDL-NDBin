=head1 NAME

PDL::NDBin::Func - useful functions for multidimensional binning & histogramming

=cut

use strict;
use warnings;

##########
# ICOUNT #
##########
package PDL::NDBin::Func::ICount;
use PDL::Lite;		# do not import any functions into this namespace
use PDL::NDBin::Func::PP;

sub new
{
	my $class = shift;
	my $m = shift;
	my $self = {
		m   => $m,
		out => PDL->zeroes( PDL::long, $m ),
	};
	return bless $self, $class;
}

sub process
{
	my $self = shift;
	my $in = shift;
	my $ind = shift;
	PDL::NDBin::Func::PP::_icount_loop( $in, $ind, $self->{out}, $self->{m} );
}

sub result
{
	my $self = shift;
	return $self->{out};
}

########
# ISUM #
########
package PDL::NDBin::Func::ISum;
use PDL::Lite;		# do not import any functions into this namespace
use PDL::NDBin::Func::PP;

sub new
{
	my $class = shift;
	my $m = shift;
	my $self = {
		count => PDL->zeroes( PDL::long, $m ),
		m     => $m,
	};
	return bless $self, $class;
}

sub process
{
	my $self = shift;
	my $in = shift;
	my $ind = shift;
	# allocate $self->{out} first time round; since the type of
	# $self->{out} depends on the input data, the allocation is deferred
	# until we receive the input data
	unless( defined $self->{out} ) {
		my $type = $in->type;
		$type = PDL::long unless $type > PDL::long;
		$self->{out} = PDL->zeroes( $type, $self->{m} );
	}
	PDL::NDBin::Func::PP::_isum_loop( $in, $ind, $self->{out}, $self->{count}, $self->{m} );
}

sub result
{
	my $self = shift;
	PDL::NDBin::Func::PP::_setnulltobad( $self->{count}, $self->{out} );
	return $self->{out};
}

########
# IAVG #
########
package PDL::NDBin::Func::IAvg;
use PDL::Lite;		# do not import any functions into this namespace
use PDL::NDBin::Func::PP;

sub new
{
	my $class = shift;
	my $m = shift;
	my $self = {
		count => PDL->zeroes( PDL::long, $m ),
		m     => $m,
		out   => PDL->zeroes( PDL::double, $m ),
	};
	return bless $self, $class;
}

sub process
{
	my $self = shift;
	my $in = shift;
	my $ind = shift;
	PDL::NDBin::Func::PP::_iavg_loop( $in, $ind, $self->{out}, $self->{count}, $self->{m} );
}

sub result
{
	my $self = shift;
	PDL::NDBin::Func::PP::_setnulltobad( $self->{count}, $self->{out} );
	return $self->{out};
}

###########
# ISTDDEV #
###########
package PDL::NDBin::Func::IStdDev;
use PDL::Lite;		# do not import any functions into this namespace
use PDL::NDBin::Func::PP;

sub new
{
	my $class = shift;
	my $m = shift;
	my $self = {
		avg   => PDL->zeroes( PDL::double, $m ),
		count => PDL->zeroes( PDL::long, $m ),
		m     => $m,
		out   => PDL->zeroes( PDL::double, $m ),
	};
	return bless $self, $class;
}

sub process
{
	my $self = shift;
	my $in = shift;
	my $ind = shift;
	PDL::NDBin::Func::PP::_istddev_loop( $in, $ind, $self->{out}, $self->{count}, $self->{avg}, $self->{m} );
}

sub result
{
	my $self = shift;
	PDL::NDBin::Func::PP::_istddev_post( $self->{count}, $self->{out} );
	return $self->{out};
}

package PDL::NDBin::Func;

use Exporter;
our @ISA = qw( Exporter );
our @EXPORT = qw( icount isum iavg istddev );
our @EXPORT_OK = qw( icount isum iavg istddev );
our %EXPORT_TAGS = ( all => [ qw( icount isum iavg istddev ) ] );
use PDL;
use PDL::NDBin::Func::PP;
use Carp;

=head2 icount

Count the number of elements in each bin.

Signature:

	icount( in(n), ind(n), m )

Synopsis:

	$out = icount( $in, $ind, $m ));

where $in and $ind are of dimension I<n>, and $out is of dimension I<m>.

=cut

sub icount
{
	my $in = shift;
	my $ind = shift;
	my $m = shift;
	confess 'too many arguments' if @_;
	my $obj = PDL::NDBin::Func::ICount->new( $m );
	$obj->process( $in, $ind );
	return $obj->result;
}

=head2 isum

Sum the elements in each bin.

Signature:

	isum( in(n), ind(n), m )

Usage:

	$out = isum( $in, $ind, $m ));

where $in and $ind are of dimension I<n>, and $out is of dimension I<m>.

=cut

sub isum
{
	my $in = shift;
	my $ind = shift;
	my $m = shift;
	confess 'too many arguments' if @_;
	my $obj = PDL::NDBin::Func::ISum->new( $m );
	$obj->process( $in, $ind );
	return $obj->result;
}

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

sub iavg
{
	my $in = shift;
	my $ind = shift;
	my $m = shift;
	confess 'too many arguments' if @_;
	my $obj = PDL::NDBin::Func::IAvg->new( $m );
	$obj->process( $in, $ind );
	return $obj->result;
}

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

sub istddev
{
	my $in = shift;
	my $ind = shift;
	my $m = shift;
	confess 'too many arguments' if @_;
	my $obj = PDL::NDBin::Func::IStdDev->new( $m );
	$obj->process( $in, $ind );
	return $obj->result;
}

1;
__END__
=head1 BUGS

None reported.

=head1 TODO

This documentation is unfortunately quite incomplete, due to lack of time.

=head1 AUTHOR

Edward Baudrez, ebaudrez@cpan.org, 2011, 2012.

=head1 SEE ALSO

L<PDL::NDBin>, L<PDL>

=head1 COPYRIGHT and LICENSE

=cut
