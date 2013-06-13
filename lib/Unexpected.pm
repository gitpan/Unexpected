# @(#)Ident: Unexpected.pm 2013-06-13 16:33 pjf ;

package Unexpected;

use namespace::sweep;
use overload '""' => 'as_string', fallback => 1;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 7 $ =~ /\d+/gmx );

use 5.01;
use Moo;
use Scalar::Util      qw(blessed);
use Unexpected::Types qw(NonEmptySimpleStr);

with q(Unexpected::TraitFor::StringifyingError);
with q(Unexpected::TraitFor::Throwing);
with q(Unexpected::TraitFor::TracingStacks);

has 'class' => is => 'ro', isa => NonEmptySimpleStr, default => __PACKAGE__;

sub BUILD {} # Can be modified by the applied traits

sub is_one_of_us {
   return $_[ 1 ] && blessed $_[ 1 ] && $_[ 1 ]->isa( __PACKAGE__ );
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Unexpected - Exception class composed from traits

=head1 Synopsis

   package YourApp::Exception;

   use Moo;

   extends 'Unexpected';
   with    'Unexpected::TraitFor::ErrorLeader';

   __PACKAGE__->ignore_class( 'YourApp::IgnoreMe' );

   has '+class' => default => __PACKAGE__;

   package YourApp;

   use YourApp::Exception;
   use Try::Tiny;

   sub some_method {
      my $self = shift;

      try   { this_will_fail }
      catch { YourApp::Exception->throw $_ };
   }

   # OR

   sub some_method {
      my $self = shift;

      eval { this_will_fail };
      YourApp::Exception->throw_on_error;
   }

   # THEN
   try   { $self->some_method() }
   catch { warn $_->message };

=head1 Version

This documents version v0.3.$Rev: 7 $ of L<Unexpected>

=head1 Description

An exception class that supports error messages with placeholders, a
L<Unexpected::TraitFor::Throwing/throw> method with
automatic re-throw upon detection of self, conditional throw if an
exception was caught and a simplified stacktrace

=head1 Configuration and Environment

Applies exception roles to the exception base class L<Unexpected>. See
L</Dependencies> for the list of roles that are applied

Error objects are overloaded to stringify to the full error message
plus a leader if the optional C<ErrorLeader> role has been applied

Defines these attributes;

=over 3

=item C<class>

Defaults to C<__PACKAGE__>. Can be used to differentiate different
classes of error

=back

=head1 Subroutines/Methods

=head2 BUILDARGS

Placeholder to shut L<Pod::Coverage> up

=head2 BUILD

Does nothing placeholder that allows the applied roles to modify it

=head2 is_one_of_us

   $bool = $class->is_one_of_us( $string_or_exception_object_ref );

Class method which detects instances of this exception class

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<namespace::sweep>

=item L<overload>

=item L<Moo>

=item L<Unexpected::TraitFor::StringifyingError>

=item L<Unexpected::TraitFor::Throwing>

=item L<Unexpected::TraitFor::TracingStacks>

=item L<Unexpected::Types>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

L<Throwable::Error> - Lifted the stack frame filter from here

John Sargent - Came up with the package name

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
