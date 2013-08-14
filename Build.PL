# @(#)$Ident: Build.PL 2013-08-14 19:20 pjf ;

use strict;
use warnings;

use Module::Build;

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

my $code = do { local $/; <DATA> }; my $perl_ver = 5.010001;

$] >= $perl_ver or $ENV{PERL5_CPANPLUS_IS_VERSION}
   or whimper "Minimum required Perl version is ${perl_ver}";

Module::Build->subclass( code => $code )->new(
  'module_name' => 'Unexpected',
  'notes'       => { min_perl_version => $perl_ver },
  'build_requires' => {
    'Module::Build' => '0.4004',
    'Moo' => '1.002',
    'Test::Requires' => '0.06',
    'version' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.4004',
    'version' => '0.88'
  },
  'requires' => {
    'Class::Load' => '0.18',
    'Devel::StackTrace' => '1.26',
    'Moo' => '1.002',
    'Type::Tiny' => '0.012',
    'namespace::clean' => '0.23',
    'namespace::sweep' => '0.006'
  },

)->create_build_script;

exit 0;

__DATA__

sub _normalize_prereqs { # Dynamic config
   my $self = shift; my $p = $self->SUPER::_normalize_prereqs; return $p;
}
