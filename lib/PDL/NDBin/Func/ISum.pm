package PDL::NDBin::Func::ISum;

use strict;
use warnings;
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

1;
__END__
=head2 isum

Sum the elements in each bin.

Signature:

	isum( in(n), ind(n), m )

Usage:

	$out = isum( $in, $ind, $m ));

where $in and $ind are of dimension I<n>, and $out is of dimension I<m>.

=cut
