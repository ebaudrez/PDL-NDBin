
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Multidimensional binning & histogramming",
  "AUTHOR" => "Edward Baudrez <ebaudrez\@cpan.org>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "PDL-NDBin",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "PDL::NDBin",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Class::Load" => 0,
    "Data::Dumper" => 0,
    "Exporter" => 0,
    "List::MoreUtils" => 0,
    "List::Util" => 0,
    "Log::Any" => 0,
    "Math::Round" => 0,
    "PDL::Lite" => 0,
    "POSIX" => 0,
    "Params::Validate" => 0,
    "UUID::Tiny" => 0,
    "XSLoader" => 0,
    "integer" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Module::Pluggable" => "3.1",
    "PDL" => "2.004",
    "PDL::Types" => 0,
    "Test::Deep" => 0,
    "Test::Exception" => 0,
    "Test::More" => "0.88",
    "Test::NoWarnings" => 0,
    "Test::PDL" => "0.10"
  },
  "VERSION" => "0.013",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Class::Load" => 0,
  "Data::Dumper" => 0,
  "Exporter" => 0,
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "List::MoreUtils" => 0,
  "List::Util" => 0,
  "Log::Any" => 0,
  "Math::Round" => 0,
  "Module::Pluggable" => "3.1",
  "PDL" => "2.004",
  "PDL::Lite" => 0,
  "PDL::Types" => 0,
  "POSIX" => 0,
  "Params::Validate" => 0,
  "Test::Deep" => 0,
  "Test::Exception" => 0,
  "Test::More" => "0.88",
  "Test::NoWarnings" => 0,
  "Test::PDL" => "0.10",
  "UUID::Tiny" => 0,
  "XSLoader" => 0,
  "integer" => 0,
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



