
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
    "File::Find" => 0,
    "File::Temp" => 0,
    "Module::Pluggable" => "3.1",
    "PDL" => "2.004",
    "PDL::Types" => 0,
    "Test::Deep" => 0,
    "Test::Exception" => 0,
    "Test::More" => "0.88",
    "Test::NoWarnings" => 0,
    "Test::PDL" => "0.04"
  },
  "VERSION" => "0.012",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  my $tr = delete $WriteMakefileArgs{TEST_REQUIRES};
  my $br = $WriteMakefileArgs{BUILD_REQUIRES};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



