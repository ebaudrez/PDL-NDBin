use strict;
use warnings;
use PDL::Core::Dev;
use ExtUtils::MakeMaker;

my $package = [ "func.pd", 'PP', 'PDL::NDBin::Func::PP' ];
WriteMakefile( pdlpp_stdargs( $package ) );
sub MY::postamble { pdlpp_postamble( $package ) }
