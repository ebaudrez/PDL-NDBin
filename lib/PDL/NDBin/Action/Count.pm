package PDL::NDBin::Action::Count;
# ABSTRACT: Action for PDL::NDBin that counts elements

use strict;
use warnings;
use PDL::Lite;		# do not import any functions into this namespace
use PDL::NDBin::Actions_PP;

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
	PDL::NDBin::Actions_PP::_icount_loop( $iter->data, $iter->idx, $self->{out}, $self->{m} );
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
