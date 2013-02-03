package PDL::NDBin::Action::CodeRef;
# ABSTRACT: Action for PDL::NDBin that calls user sub

use strict;
use warnings;
use PDL::Lite;		# do not import any functions into this namespace

sub new
{
	my $class = shift;
	my $m = shift;
	my $coderef = shift;
	return bless { m => $m, coderef => $coderef }, $class;
}

=head2 process()

Note that process() does not catch exceptions. The user-supplied subroutine
should be wrapped in an I<eval> block if the rest of the code should be
protected from exceptions raised inside the subroutine.

=cut

sub process
{
	my $self = shift;
	my $iter = shift;
	$self->{out} = PDL->zeroes( $iter->data->type, $self->{m} )->setbadif( 1 ) unless defined $self->{out};
	my $value = $self->{coderef}->( $iter );
	if( defined $value ) { $self->{out}->set( $iter->bin, $value ) }
	return $self;
}

sub result
{
	my $self = shift;
	return $self->{out};
}

1;
