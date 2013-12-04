package PDL::NDBin::Action::StdDev;
# ABSTRACT: Action for PDL::NDBin that computes standard deviation

=head1 DESCRIPTION

This class implements an action for PDL::NDBin.

=cut

use strict;
use warnings;
use PDL::Lite;		# do not import any functions into this namespace
use PDL::NDBin::Actions_PP;
use Params::Validate qw( validate OBJECT SCALAR );

=head1 METHODS

=head2 new()

	my $instance = PDL::NDBin::Action::StdDev->new(
		N    => $N,
		type => double,   # default
	);

Construct an instance for this action. Requires the number of bins $N as input.
Optionally allows the type of the output piddle to be set (defaults to
I<double>).

=cut

sub new
{
	my $class = shift;
	my $self = validate( @_, {
			N    => { type => SCALAR, regex => qr/^\d+$/ },
			type => { type => OBJECT, isa => 'PDL::Type', default => PDL::double }
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
	$self->{out} = PDL->zeroes( $self->{type}, $self->{N} ) unless defined $self->{out};
	$self->{count} = PDL->zeroes( PDL::indx, $self->{N} ) unless defined $self->{count};
	# as the internal computations happen in double, the type of 'avg' sticks to double
	$self->{avg} = PDL->zeroes( PDL::double, $self->{N} ) unless defined $self->{avg};
	PDL::NDBin::Actions_PP::_istddev_loop( $iter->data, $iter->idx, $self->{out}, $self->{count}, $self->{avg}, $self->{N} );
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
	$self->{out}->inplace->_istddev_post( $self->{count} );
	return $self->{out};
}

1;
