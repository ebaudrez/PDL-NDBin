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
use Params::Validate qw( validate CODEREF OBJECT SCALAR UNDEF );

=head1 METHODS

=head2 new()

	my $instance = PDL::NDBin::Action::CodeRef->new(
		N       => $N,
		coderef => $coderef,
		type    => double,   # optional
	);

Construct an instance for this action. Accepts three parameters:

=over 4

=item I<N>

The number of bins. Required.

=item I<coderef>

A reference to an anonymous or named subroutine that implements the real
action. Required.

=item I<type>

The type of the output variable. Optional. Defaults to the type of the variable
this instance is associated with.

=back

=cut

sub new
{
	my $class = shift;
	my $self = validate( @_, {
			N       => { type => SCALAR, regex => qr/^\d+$/ },
			coderef => { type => CODEREF },
			type    => { type => OBJECT | UNDEF, isa => 'PDL::Type', optional => 1 }
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
	if( ! defined $self->{out} ) {
		my $type = defined $self->{type} ? $self->{type} : $iter->data->type;
		$self->{out} = PDL->zeroes( $type, $self->{N} )->setbadif( 1 );
	}
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
