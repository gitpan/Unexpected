# @(#)Ident: TracingStacks.pm 2013-08-23 22:54 pjf ;

package Unexpected::TraitFor::TracingStacks;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.9.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Scalar::Util      qw( weaken );
use Unexpected::Types qw( HashRef LoadableClass Tracer );
use Moo::Role;

requires qw( BUILD );

# Object attributes (public)
has 'trace'       => is => 'lazy', isa => Tracer,
   handles        => [ qw( frames ) ], init_arg => undef;

has 'trace_args'  => is => 'lazy', isa => HashRef;

has 'trace_class' => is => 'ro',   isa => LoadableClass,
   default        => 'Devel::StackTrace';

# Construction
before 'BUILD' => sub {
   my $self = shift; $self->trace; return;
};

# Public methods
sub filtered_frames {
   return grep { $_->subroutine !~ m{ :: __ANON__ \z }mx } $_[ 0 ]->frames;
}

sub stacktrace {
   my ($self, $skip) = @_; my (@lines, %seen, $subr);

   for my $frame (reverse $self->frames) {
      my $package = $frame->package; my $l_no;

      unless ($l_no = $seen{ $package } and $l_no == $frame->line) {
         my $lead = $subr || $package; $lead !~ m{ :: __ANON__ \z }mx
            and push @lines, join q( ), $lead, 'line', $frame->line;
         $seen{ $package } = $frame->line;
      }

      $frame->subroutine !~ m{ :: __ANON__ \z }mx
         and $subr = $frame->subroutine;
   }

   defined $skip or $skip = 0; pop @lines while ($skip--);

   return wantarray ? reverse @lines : (join "\n", reverse @lines)."\n";
}

sub trace_frame_filter { # Lifted from StackTrace::Auto
   my $self = shift; my $found_mark = 0; weaken( $self );

   return sub {
      my ($raw)    = @_;
      my  $subr    = $raw->{caller}->[ 3 ];
     (my  $package = $subr) =~ s{ :: \w+ \z }{}mx;

      if    ($found_mark == 3) { return 1 }
      elsif ($found_mark == 2) {
         $subr =~ m{ :: new \z }mx and $self->isa( $package ) and return 0;
         $found_mark++; return 1;
      }
      elsif ($found_mark == 1) {
         $subr =~ m{ :: new \z }mx and $self->isa( $package ) and $found_mark++;
         return 0;
      }

      $subr =~ m{ :: _build_trace \z }mx and $found_mark++;
      return 0;
   }
}

# Private methods
sub _build_trace {
   return $_[ 0 ]->trace_class->new( %{ $_[ 0 ]->trace_args } );
}

sub _build_trace_args {
   return { no_refs          => 1,
            respect_overload => 0,
            max_arg_length   => 0,
            frame_filter     => $_[ 0 ]->trace_frame_filter, };
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Unexpected::TraitFor::TracingStacks - Provides a minimalist stacktrace

=head1 Synopsis

   use Moo;

   with 'Unexpected::TraitFor::TracingStacks';

=head1 Version

This documents version v0.9.$Rev: 1 $ of
L<Unexpected::TraitFor::TracingStacks>

=head1 Description

Provides a minimalist stacktrace

=head1 Configuration and Environment

Modifies C<BUILD> in the consuming class. Forces the instantiation of
the C<trace> attribute

Defines the following attributes;

=over 3

=item C<trace>

An instance of the C<trace_class>

=item C<trace_args>

A hash ref of arguments passed the C<trace_class> constructor when the
C<trace> attribute is instantiated

=item C<trace_class>

A loadable class which defaults to L<Devel::StackTrace>

=back

=head1 Subroutines/Methods

=head2 filtered_frames

   @frames = $self->filtered_frames;

Currently frames with subroutine names matching C<__ANON__> are
filtered out

=head2 stacktrace

   $lines = $self->stacktrace( $num_frames_to_skip );

Returns a minimalist stack trace. Defaults to skipping zero frames
from the stack

=head2 trace_frame_filter

Lifted from L<StackTrace::Auto> this method filters out frames from the
raw stacktrace that are not of interest. It is very clever

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<namespace::sweep>

=item L<Moo::Role>

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
