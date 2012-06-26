use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME      => 'PDL::NDBin',
	PREREQ_PM => { "Math::Round" => 0, "PDL" => 0 },
);
