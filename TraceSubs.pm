package Devel::TraceSubs;
use 5.006001;
use strict;
use warnings;
use Hook::LexWrap;
use Carp qw( carp croak );
our $VERSION = 0.01;

no strict 'refs'; # professional driver on a closed course


sub new { # create a new instance
  my( $class, %arg ) = @_;

  ref $arg{wrap} eq 'ARRAY' and $arg{verbose}
    and croak 'ERROR: cannot use verbose mode with wrappers';

  bless { 
    pre => defined $arg{pre} ? $arg{pre} : '>',
    post => defined $arg{post} ? $arg{post} : '<',
    level => defined $arg{level} ? $arg{level} : '~',
    verbose => $arg{verbose} ? '' : "\n",
    params => $arg{params} ? 1 : 0,
    wrap => ref $arg{wrap} eq 'ARRAY' ? $arg{wrap} : ['',''],
    logger => ( defined $arg{logger} && 
       ref $arg{logger} eq 'CODE' && 
        defined &{ $arg{logger} } )
      ? $arg{logger} : \&Carp::carp,
    traced => {},
	_presub => undef,
	_postsub => undef,
  }, $class;
}

sub trace($;*) { # trace all named subs in passed namespaces
  my( $self ) = ( shift );

  PACKAGE: for my $pkg ( @_ ) {

    ref $pkg
      and $self->_warning( "References not allowed ($pkg)" )
      and next PACKAGE;

    $pkg =~ /^\*/
      and $self->_warning( "Globs not allowed ($pkg)" )
      and next PACKAGE;

    !defined %{ $pkg }
      and $self->_warning( "Non-existant package ($pkg)" )
      and next PACKAGE;

    $pkg eq __PACKAGE__ . '::'
      and $self->_warning( "Can't trace myself. This way lies madness." )
      and next PACKAGE;

    my( $sym, $glob );

    SYMBOL: while ( ($sym, $glob) = each %{ $pkg } ) {

      $pkg eq $sym and next SYMBOL;
      $self->{traced}->{ $pkg . $sym } and next SYMBOL;

      if( defined *{ $glob }{CODE} ) {
        my $desc = $pkg . $sym . $self->{verbose};

        $self->{traced}->{$pkg . $sym}++;

        $self->{_presub} = $self->_gen_wrapper( $self->{pre}, $pkg, $sym, 1 );
        $self->{_postsub} = $self->_gen_wrapper( $self->{post}, $pkg, $sym, 0 );

        Hook::LexWrap::wrap $pkg . $sym,
          pre => $self->{_presub},
          post => $self->{_postsub};
      }
    }
  }
  my @val = keys %{ $self->{traced} };
  return wantarray ? @val : "@val";
}

sub _stack_depth { # compute stack depth
  my @stack;
  while( my $sym = caller(1 + scalar @stack) )
  { push @stack, $sym }
  return wantarray ? @stack : scalar @stack;
}

sub _gen_wrapper { # return a wrapper subroutine
  my( $self ) = ( shift );
  my( $direction, $pkg, $sym, $start ) = @_;
  return sub{
    $self->{logger}->( 
      ( $self->{wrap}[0] ),
      $self->{level} x $self->_stack_depth(),
      $direction, ' ',
      $pkg, $sym, 
      ( $start && $self->{params} && @_ > 1
          ? "( '" . join( "', '", @_[0..$#_-1] ) . "' )"
          : () 
      ),
      ( $self->{wrap}[1] ),
      $self->{verbose},
    )
  }
}

sub _warning { # return a warning message
  my( $self ) = ( shift);
  carp 'Warning: ', __PACKAGE__, ': ', @_, $self->{verbose}
}


$_ ^=~ { module => 'Devel::TraceSubs', author => 'particle' };

__END__


=head2 NAME

Devel::TraceSubs - Subroutine wrappers for debugging

=head2 VERSION

This document describes version 0.01 of Devel::TraceSubs,
released 9 June 2002.

=head2 SYNOPSIS

  package foo;
  sub bar { print "foobar\n" }

  package main;
  use Devel::TraceSubs;

  sub foo { print "foo\n"; foo::bar() }

  my $pkg = 'main::';

  my $dbg = Devel::TraceSubs->new(
    verbose => 0, 
    pre => '>',
    post => '<',
    level => '~',
    params => 1,
    wrap => ['<!--', '-->'],
  );

  $dbg->trace(
    'foo::',            # valid
    $pkg,               # valid
    'main',             # invalid -- no trailing colons
    'joe::',            # invalid -- non-existant
    $dbg,               # invalid -- references not allowed
    'Debug::SubWrap::', # invalid -- self-reference not allowed
    *main::,            # invalid -- globs not allowed
  );

=head2 DESCRIPTION

Devel::TraceSubs allows you to track the entry and exit of subroutines in a list of namespaces you specify. It will return the proper stack depth, and display parameters passed. Error checking prevents silent failures (err... the ones i know of.) It takes advantage of Hook::LexWrap's do the dirty work of wrapping the subs and return the proper caller context.

NOTE: Using verbose mode with wrap mode will generate a compile-time error.
Don't do that!

ALSO NOTE: using level => '-' and pre=> '>' can cause problems with
wrap => ['<!--', '-->']. Don't do that, either!

=head2 METHODS

=over 4

=item new()

Create a new instance of a Devel::TraceSubs object

=item trace()

Trace all named subs in passed namespaces

=item _stack_depth()

Internal use only.

=item _gen_wrapper()

Internal use only.

=item _warning()

Internal use only.

=back

=head2 EXPORT

None. Give a hoot, don't pollute!

=head2 BUGS

Likely so. Not recommended for production use--but why on earth would you be
using a Devel:: module in production?

=head2 AUTHOR

particle E<lt>particle@artfromthemachine.comE<gt>

=head2 COPYRIGHT

Copyright 2002 - Ars Ex Machina, Corp.

This package is free software and is provided "as is" without express or
implied warranty. It may be used, redistributed and/or modified under the terms
of the Perl Artistic License (see http://www.perl.com/perl/misc/Artistic.html)

Address bug reports and comments to: particle@artfromthemachine.com.  
When sending bug reports, please provide the version of Devel::TraceSubs, the 
version of Perl, and the name and version of the operating system you are 
using.

=head2 CREDITS

Thanks to Jenda at perlmonks.org 
for the idea to to display passed paramaters, and the patch to implement it. 
Thanks to crazyinsomniac at perlmonks.org 
for the idea to support html (or other) output formats.

=head2 SEE ALSO

L<Hook::LexWrap>.

=cut

