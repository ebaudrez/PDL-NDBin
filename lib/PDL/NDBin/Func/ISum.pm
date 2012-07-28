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
	my $iter = shift;
	my $type = $iter->data->type < PDL::long() ? PDL::long : $iter->data->type;
	$self->{out} = PDL->zeroes( $type, $self->{m} ) unless defined $self->{out};
	$self->{count} = PDL->zeroes( PDL::long, $self->{m} ) unless defined $self->{count};
	PDL::NDBin::Func::PP::_isum_loop( $iter->data, $iter->hash, $self->{out}, $self->{count}, $self->{m} );
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
=head2 isum

Sum the elements in each bin.

Signature:

	isum( in(n), ind(n), m )

Usage:

	$out = isum( $in, $ind, $m ));

where $in and $ind are of dimension I<n>, and $out is of dimension I<m>.

=cut
