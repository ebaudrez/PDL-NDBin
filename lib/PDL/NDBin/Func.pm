package PDL::NDBin::Func;

=head1 NAME

PDL::NDBin::Func - useful functions for multidimensional binning & histogramming

=cut

use strict;
use warnings;
use Exporter;
our @ISA = qw( Exporter );
use Carp;
use Module::Pluggable require     => 1,
		      search_path => [ 'PDL::NDBin::Func' ],
		      except      => [ 'PDL::NDBin::Func::PP' ];

# create exportable wrapper functions around the classes
my @plugins = __PACKAGE__->plugins;
my @functions;
for my $plugin ( @plugins )
{
	my $function = do { $plugin =~ /::(\w+)$/; lc $1 };
	no strict 'refs';
	*$function = sub {
		my $iter = shift;
		confess 'too many arguments' if @_;
		my $obj = $plugin->new( $iter->nbins );
		$obj->process( $iter->data, $iter->hash );
		# as the plugin processes all bins at once, every variable
		# needs to be visited only once
		$iter->var_active( 0 );
		return $obj->result;
	};
	push @functions, $function;
}

our @EXPORT = @functions;
our @EXPORT_OK = @functions;
our %EXPORT_TAGS = ( all => \@functions );

1;
__END__
=head1 BUGS

None reported.

=head1 TODO

This documentation is unfortunately quite incomplete, due to lack of time.

=head1 AUTHOR

Edward Baudrez, ebaudrez@cpan.org, 2011, 2012.

=head1 SEE ALSO

L<PDL::NDBin>, L<PDL>

=head1 COPYRIGHT and LICENSE

=cut
