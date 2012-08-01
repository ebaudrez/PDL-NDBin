package PDL::NDBin::Func::CodeRef;

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

sub process
{
	my $self = shift;
	my $iter = shift;
	$self->{out} = PDL->zeroes( $iter->data->type, $self->{m} )->setbadif( 1 ) unless defined $self->{out};
	# catch exceptions; one particularly difficult sort of exception is
	# indexing on empty piddles: this may throw an exception, but only when
	# the selection is evaluated (which is inside the action)
	my $value = eval { $self->{coderef}->( $iter ) };
	if( defined $value ) { $self->{out}->set( $iter->bin, $value ) }
	return $self;
}

sub result
{
	my $self = shift;
	return $self->{out};
}

1;
