use strict;
use warnings;
use PDL::Core::Dev;
use ExtUtils::MakeMaker;

my $package = [ "func.pd", 'Func', 'PDL::NDBin::Func' ];
WriteMakefile( pdlpp_stdargs( $package ) );
sub MY::postamble { pdlpp_postamble( $package ) }
