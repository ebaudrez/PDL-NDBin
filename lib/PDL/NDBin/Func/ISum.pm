package PDL::NDBin::Func::ISum;

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
	$self->{out} = PDL->zeroes( $in->type < PDL::long() ? PDL::long : $in->type, $self->{m} ) unless defined $self->{out};
	$self->{count} = PDL->zeroes( PDL::long, $self->{m} ) unless defined $self->{count};
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
