package PDL::NDBin::Action::CodeRef;
# ABSTRACT: Action for PDL::NDBin that calls user sub

=head1 DESCRIPTION

This class implements a special action for PDL::NDBin that is actually a
wrapper around a user-defined function. This class exists just to fit
user-defined subroutines in the same framework as the other actions, which are
defined by classes (so that the user doesn't have to define a full-blown class
just to implement an action).

=cut

use strict;
use warnings;
use PDL::Lite;		# do not import any functions into this namespace
use Params::Validate qw( validate CODEREF SCALAR );

=head1 METHODS

=head2 new()

	my $instance = PDL::NDBin::Action::CodeRef->new( N => $N, coderef => $coderef );

Construct an instance for this action. Requires two parameters:

=over 4

=item I<N>

The number of bins.

=item I<coderef>

A reference to an anonymous or named subroutine that implements the real action.

=back

=cut

sub new
{
	my $class = shift;
	my $self = validate( @_, {
			N       => { type => SCALAR, regex => qr/^\d+$/ },
			coderef => { type => CODEREF },
		} );
	return bless $self, $class;
}

=head2 process()

	$instance->process( $iter );

Run the action with the given iterator $iter. This action cannot assume that
all bins can be computed at once, and will not deactivate the variable. This
means that process() will need to be called for every bin.

Note that process() does not trap exceptions. The user-supplied subroutine
should be wrapped in an I<eval> block if the rest of the code should be
protected from exceptions raised inside the subroutine.

=cut

sub process
{
	my $self = shift;
	my $iter = shift;
	$self->{out} = PDL->zeroes( $iter->data->type, $self->{N} )->setbadif( 1 ) unless defined $self->{out};
	my $value = $self->{coderef}->( $iter );
	if( defined $value ) { $self->{out}->set( $iter->bin, $value ) }
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
