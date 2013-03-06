package PDL::NDBin::Action::Count;
# ABSTRACT: Action for PDL::NDBin that counts elements

=head1 DESCRIPTION

This class implements an action for PDL::NDBin.

=cut

use strict;
use warnings;
use PDL::Lite;		# do not import any functions into this namespace
use PDL::NDBin::Actions_PP;
use Params::Validate qw( validate SCALAR );

=head1 METHODS

=head2 new()

	my $instance = PDL::NDBin::Action::Count->new( N => $N );

Construct an instance for this action. Requires the number of bins $N as input.

=cut

sub new
{
	my $class = shift;
	my $self = validate( @_, {
			N => { type => SCALAR, regex => qr/^\d+$/ },
		} );
	return bless $self, $class;
}

=head2 process()

	$instance->process( $iter );

Run the action with the given iterator $iter. This action will compute all bins
during the first call and will subsequently deactivate the variable.

=cut

sub process
{
	my $self = shift;
	my $iter = shift;
	$self->{out} = PDL->zeroes( PDL::long, $self->{N} ) unless defined $self->{out};
	PDL::NDBin::Actions_PP::_icount_loop( $iter->data, $iter->idx, $self->{out}, $self->{N} );
	# as the plugin processes all bins at once, every variable
	# needs to be visited only once
	$iter->var_active( 0 );
	return $self;
}

=head2 result()

	my $result = $instance->result;

Return the result of the computation.

=cut

sub result
{
	my $self = shift;
	return $self->{out};
}

1;
