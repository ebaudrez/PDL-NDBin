use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME      => 'PDL::NDBin',
	PREREQ_PM => {
		'Data::Dumper'      => 0,
		'Log::Any'          => 0,
		'Math::Round'       => 0,
		'Module::Pluggable' => 0,
		'PDL'               => 0,
	},
);
