package PDL::NDBin::Func;

=head1 NAME

PDL::NDBin::Func - useful functions for multidimensional binning & histogramming

=cut

use strict;
use warnings;
use Exporter;
our @ISA = qw( Exporter );
our @EXPORT = qw( icount isum iavg istddev );
our @EXPORT_OK = qw( icount isum iavg istddev );
our %EXPORT_TAGS = ( all => [ qw( icount isum iavg istddev ) ] );
use PDL;
use PDL::NDBin::Func::PP;

=head2 icount

Count the number of elements in each bin.

Signature:

	icount( in(n), ind(n), [o]out(m), m )

Synopsis:

	$out = icount( $in, $ind, $out, $m ));

where $in and $ind are of dimension I<n>, and $out is of dimension I<m>.
$out is optional.

=cut

sub icount
{
	my $in = shift;
	my $ind = shift;
	my $out = eval { $_[0]->isa( q(PDL) ) } ? shift : PDL->nullcreate;
	my $m = shift;
	PDL::NDBin::Func::PP::icount_pre( $out, $m );
	PDL::NDBin::Func::PP::icount_loop( $in, $ind, $out, $m );
	return $out;
}

=head2 isum

Sum the elements in each bin.

Signature:

	isum( in(n), ind(n), [o]out(m), [t]count(m), m )

Usage:

	$out = isum( $in, $ind, $out, $count, $m ));

where $in and $ind are of dimension I<n>, and $out and $count are of dimension
I<m>. $out and $count are optional.

=cut

sub isum
{
	my $in = shift;
	my $ind = shift;
	my $out = eval { $_[0]->isa( q(PDL) ) } ? shift : PDL->nullcreate;
	my $count = eval { $_[0]->isa( q(PDL) ) } ? shift : PDL->nullcreate;
	# DIRTY HACK :-(
	$out->badflag( 1 );
	my $m = shift;
	PDL::NDBin::Func::PP::isum_pre( $in, $ind, $out, $count, $m );
	PDL::NDBin::Func::PP::isum_loop( $in, $ind, $out, $count, $m );
	PDL::NDBin::Func::PP::isum_post( $count, $out );
	return $out;
}

=head2 iavg

Compute the average of the elements in each bin.

Signature:

	iavg( in(n), ind(n), [o]out(m), [t]count(m), m )

Usage:

	$out = iavg( $in, $ind, $out, $count, $m );

where $in and $ind are of dimension I<n>, and $out and $count are of dimension
I<m>. $out and $count are optional. You can leave out $count, or both $out and
$count.

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
	my $out = eval { $_[0]->isa( q(PDL) ) } ? shift : PDL->nullcreate;
	my $count = eval { $_[0]->isa( q(PDL) ) } ? shift : PDL->nullcreate;
	# DIRTY HACK :-(
	$out->badflag( 1 );
	my $m = shift;
	PDL::NDBin::Func::PP::iavg_pre( $out, $count, $m );
	PDL::NDBin::Func::PP::iavg_loop( $in, $ind, $out, $count, $m );
	PDL::NDBin::Func::PP::iavg_post( $count, $out );
	return $out;
}

=head2 istddev

Compute the standard deviation of the elements in each bin. Note, we compute
the sample standard deviation, I<not> an estimate of the population standard
deviation (which differs by a factor).

Signature:

	istddev( in(n), ind(n), [o]out(m), [t]count(m), [t]avg(m), m )

Usage:

	$out = istddev( $in, $ind, $out, $count, $avg, $m );

where $in and $ind are of dimension I<n>, and $out, $count, and $avg are of
dimension I<m>. $out, $count, and $avg are optional. You can leave out $avg,
$count and $avg, or $out, $count and $avg.

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
	my $out = eval { $_[0]->isa( q(PDL) ) } ? shift : PDL->nullcreate;
	my $count = eval { $_[0]->isa( q(PDL) ) } ? shift : PDL->nullcreate;
	my $avg = eval { $_[0]->isa( q(PDL) ) } ? shift : PDL->nullcreate;
	# DIRTY HACK :-(
	$out->badflag( 1 );
	my $m = shift;
	PDL::NDBin::Func::PP::istddev_pre( $out, $count, $avg, $m );
	PDL::NDBin::Func::PP::istddev_loop( $in, $ind, $out, $count, $avg, $m );
	PDL::NDBin::Func::PP::istddev_post( $count, $out );
	return $out;
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
