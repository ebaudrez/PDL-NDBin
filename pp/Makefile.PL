use strict;
use warnings;
use PDL::Core::Dev;
use ExtUtils::MakeMaker;

my $package = [ "actions.pd", 'Actions_PP', 'PDL::NDBin::Actions_PP' ];
WriteMakefile( pdlpp_stdargs( $package ) );
sub MY::postamble { pdlpp_postamble( $package ) }
