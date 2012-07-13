package PDL::NDBin::Func::ICount;

use strict;
use warnings;
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

1;
__END__
=head2 icount

Count the number of elements in each bin.

Signature:

	icount( in(n), ind(n), m )

Synopsis:

	$out = icount( $in, $ind, $m ));

where $in and $ind are of dimension I<n>, and $out is of dimension I<m>.

=cut
