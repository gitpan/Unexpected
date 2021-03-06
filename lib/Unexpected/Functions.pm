package Unexpected::Functions;

use strict;
use warnings;
use parent 'Exporter::Tiny';

use Carp         qw( croak );
use Package::Stash;
use Scalar::Util qw( blessed reftype );
use Sub::Install qw( install_sub );

our @EXPORT_OK = qw( build_attr_from catch_class exception has_exception
                     inflate_message is_class_loaded is_one_of_us throw
                     throw_on_error );

my $Exception_Class = 'Unexpected'; my $Should_Quote = 1;

# Private functions
my $_catch = sub {
   my $block = shift; return ((bless \$block, 'Try::Tiny::Catch'), @_);
};

my $_clone_one_of_us = sub {
   return $_[ 1 ] ? { %{ $_[ 0 ] }, %{ $_[ 1 ] } } : { error => $_[ 0 ] };
};

my $_dereference_code = sub {
   my ($code, @args) = @_;

   $args[ 0 ] and ref $args[ 0 ] eq 'ARRAY' and unshift @args, 'args';

   return { class => $code->(), @args };
};

my $_exception_class = sub {
   my $caller = shift; my $code = $caller->can( 'EXCEPTION_CLASS' );

   return $code ? $code->() : $Exception_Class;
};

my $_match_class = sub {
   my ($x, $ref, $blessed, $does, $key) = @_;

   return !defined $key                                       ? !defined $x
        : $key eq '*'                                         ? 1
        : $key eq ':str'                                      ? !$ref
        : $key eq $ref                                        ? 1
        : $blessed && $x->can( 'class' ) && $x->class eq $key ? 1
        : $blessed && $x->$does( $key )                       ? 1
                                                              : 0;
};

my $_quote_maybe = sub {
   return $Should_Quote ? "'".$_[ 0 ]."'" : $_[ 0 ];
};

my $_gen_checker = sub {
   my @prototable = @_;

   return sub {
      my $x       = shift;
      my $ref     = ref $x;
      my $blessed = blessed $x;
      my $does    = ($blessed && $x->can( 'DOES' )) || 'isa';
      my @table   = @prototable;

      while (my ($key, $value) = splice @table, 0, 2) {
         $_match_class->( $x, $ref, $blessed, $does, $key ) and return $value
      }

      return;
   }
};

my $_inflate_placeholders = sub { # Sub visible strings for null and undef
   return map { $_quote_maybe->( (length) ? $_ : '[]' ) }
          map { $_ // '[?]' } @_,
          map {       '[?]' } 0 .. 9;
};

# Package methods
sub import {
   my $class       = shift;
   my $global_opts = { $_[ 0 ] && ref $_[ 0 ] eq 'HASH' ? %{+ shift } : () };
   my $ex_class    = delete $global_opts->{exception_class};
   # uncoverable condition false
   my $target      = $global_opts->{into} ||= caller;
   my $ex_subr     = $target->can( 'EXCEPTION_CLASS' );
   my @want        = @_;
   my @args        = ();

   $ex_subr and $ex_class = $ex_subr->();

   for my $sym (@want) {
      if ($ex_class and $ex_class->can( 'is_exception' )
                    and $ex_class->is_exception( $sym )) {
         my $code = sub { sub { $sym } };

         install_sub { as => $sym, code => $code, into => $target, };
      }
      else { push @args, $sym }
   }

   $class->SUPER::import( $global_opts, @args );
   return;
}

sub quote_bind_values {
   defined $_[ 1 ] and $Should_Quote = !!$_[ 1 ]; return $Should_Quote;
}

# Public functions
sub build_attr_from (;@) { # Coerce a hash ref from whatever was passed
   my $n = 0; $n++ while (defined $_[ $n ]);

   return (                $n == 0) ? {}
        : (is_one_of_us( $_[ 0 ] )) ? $_clone_one_of_us->( @_ )
        : ( ref $_[ 0 ] eq  'CODE') ? $_dereference_code->( @_ )
        : ( ref $_[ 0 ] eq  'HASH') ? { %{ $_[ 0 ] } }
        : (                $n == 1) ? { error => $_[ 0 ] }
        : ( ref $_[ 1 ] eq 'ARRAY') ? { error => (shift), args => @_ }
        : ( ref $_[ 1 ] eq  'HASH') ? { error => $_[ 0 ], %{ $_[ 1 ] } }
        : (            $n % 2 == 1) ? { error => @_ }
                                    : { @_ };
}

sub catch_class ($@) {
   my $check = $_gen_checker->( @{+ shift }, '*' => sub { die $_[ 0 ] } );

   wantarray or croak 'Useless bare catch_class()';

   return $_catch->( sub { ($check->( $_[ 0 ] ) || return)->( $_[ 0 ] ) }, @_ );
}

sub exception (;@) {
   return $_exception_class->( caller )->caught( @_ );
}

sub has_exception ($;@) {
   my ($name, %args) = @_; my $exception_class = caller;

   return $exception_class->add_exception( $name, \%args );
}

sub inflate_message ($;@) { # Expand positional parameters of the form [_<n>]
   my $msg = shift; my @args = $_inflate_placeholders->( @_ );

   $msg =~ s{ \[ _ (\d+) \] }{$args[ $1 - 1 ]}gmx; return $msg;
}

sub is_class_loaded ($) { # Lifted from Class::Load
   my $class = shift; my $stash = Package::Stash->new( $class );

   if ($stash->has_symbol( '$VERSION' )) {
      my $version = ${ $stash->get_symbol( '$VERSION' ) };

      if (defined $version) {
         not ref $version and return 1;
         # Sometimes $VERSION ends up as a reference to undef (weird)
         ref $version and reftype $version eq 'SCALAR'
            and defined ${ $version } and return 1;
         blessed $version and return 1; # A version object
      }
   }

   $stash->has_symbol( '@ISA' ) and @{ $stash->get_symbol( '@ISA' ) }
      and return 1;
   # Check for any method
   return $stash->list_all_symbols( 'CODE' ) ? 1 : 0;
}

sub is_one_of_us ($) {
   return $_[ 0 ] && (blessed $_[ 0 ]) && $_[ 0 ]->isa( $Exception_Class );
}

sub throw (;@) {
   $_exception_class->( caller )->throw( @_ );
}

sub throw_on_error (;@) {
   return $_exception_class->( caller )->throw_on_error( @_ );
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Unexpected::Functions - A collection of functions used in this distribution

=head1 Synopsis

   package YourApp::Exception;

   use Moo;

   extends 'Unexpected';
   with    'Unexpected::TraitFor::ExceptionClasses';

   package YourApp;

   use Unexpected::Functions 'Unspecified';

   sub EXCEPTION_CLASS { 'YourApp::Exception' }

   sub throw { EXCEPTION_CLASS->throw( @_ ) }

   throw Unspecified, args => [ 'parameter name' ];

=head1 Description

A collection of functions used in this distribution

Also exports any exceptions defined by the caller's C<EXCEPTION_CLASS> as
subroutines that return a subroutine that returns the subroutines name as a
string. The calling package can then throw exceptions with a class attribute
that takes these subroutines return values

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

=head2 build_attr_from

   $hash_ref = build_attr_from( <whatever> );

Coerces a hash ref from whatever args are passed. This function is
responsible for parsing the arguments passed to the constructor. Supports
the following signatures

   # no defined arguments - returns and empty hash reference
   Unexpected->new();

   # first argument is one if our own objects - clone it
   Unexpected->new( $unexpected_object_ref );

   # first argument is one if our own objects, second is a hash reference
   # - clone the object but mutate it using the hash reference
   Unexpected->new( $unexpected_object_ref, { key => 'value', ... } );

   # first argument is a code reference - the code reference returns the
   # exception class and the remaining arguents are treated as a list of
   # keys and values
   Unexpected->new( Unspecified, args => [ 'parameter name' ] );
   Unexpected->new( Unspecified, [ 'parameter name' ] ); # Shortcut

   # first argmentt is a hash reference - clone it
   Unexpected->new( { key => 'value', ... } );

   # only one scalar argement - the error string
   Unexpected->new( $error_string );

   # second argement is a hash reference, first argument is the error
   Unexpected->new( $error_string, { key => 'value', ... } );

   # odd numbered list of arguments is the error followed by keys and values
   Unexpected->new( $error_string, key => 'value', ... );
   Unexecpted->new( 'File [_1] not found', args => [ $filename ] );
   Unexecpted->new( 'File [_1] not found', [ $filename ] ); # Shortcut

   arguments are a list of keys and values
   Unexpected->new( key => 'value', ... );

=head2 catch_class

   use Try::Tiny;

   try         { die $exception_object }
   catch_class [ 'exception_class' => sub { # handle exception }, ... ],
   finally     { # always do this };

See L<Try::Tiny::ByClass>. Checks the exception object's C<class> attribute
against the list of exception class names passed to C<catch_class>. If there
is a match, call the subroutine provided to handle that exception. Re-throws
the exception if there is no match or if the exception object has no C<class>
attribute

=head2 exception;

   $exception_object_ref = exception $optional_error;

A function which calls the L<caught|Unexpected::TraitFor::Throwing/caught>
class method

=head2 has_exception

   has_exception 'exception_name' => parents => [ 'parent_exception' ],
      error => 'Error message for the exception with placeholders';

A function which calls L<Unexpected::TraitFor::ExceptionClasses/add_exception>
via the calling class which is assumed to inherit from a class that consumes
the L<Unexpected::TraitFor::ExceptionClasses> role

=head2 inflate_message

   $message = inflate_message( $template, $arg1, $arg2, ... );

Substitute the placeholders in the C<$template> string (e.g. [_1])
with the corresponding argument

=head2 is_class_loaded

   $bool = is_class_loaded $classname;

Returns true is the classname as already loaded and compiled

=head2 is_one_of_us

   $bool = is_one_of_us $string_or_exception_object_ref;

Function which detects instances of this exception class

=head2 quote_bind_values

   $bool = Unexpected::Functions->quote_bind_values( $bool );

Accessor / mutator class method that toggles the state on quoting
the placeholder substitution values in C<inflate_message>. Defaults
to true

=head2 throw

   throw 'Path [_1] not found', args => [ 'pathname' ];

A function which calls the L<throw|Unexpected::TraitFor::Throwing/throw> class
method

=head2 throw_on_error

   throw_on_error @optional_args;

A function which calls the
L<throw_on_error|Unexpected::TraitFor::Throwing/throw_on_error> class method

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Exporter::Tiny>

=item L<Package::Stash>

=item L<Sub::Install>

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

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
