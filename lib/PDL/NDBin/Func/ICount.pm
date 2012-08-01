package PDL::NDBin::Func::ICount;

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
	$self->{out} = PDL->zeroes( PDL::long, $self->{m} ) unless defined $self->{out};
	PDL::NDBin::Func::PP::_icount_loop( $iter->data, $iter->hash, $self->{out}, $self->{m} );
	# as the plugin processes all bins at once, every variable
	# needs to be visited only once
	$iter->var_active( 0 );
	return $self;
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
