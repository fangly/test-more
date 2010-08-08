package Test::Builder2;

use 5.008001;
use Test::Builder2::Mouse;
use Test::Builder2::Types;

use Test::Builder2::Result;
use Test::Builder2::AssertRecord;

use Carp qw(confess);
sub sanity ($) { confess "Assert failed" unless $_[0] };


=head1 NAME

Test::Builder2 - 2nd Generation test library builder

=head1 SYNOPSIS

=head1 DESCRIPTION

Just a stub at this point to get things off the ground.

=head2 METHODS

=head3 history

Contains the Test::Builder2::History object.

=cut

has history_class => (
  is            => 'ro',
  isa           => 'Test::Builder2::LoadableClass',
  coerce        => 1,
  default       => 'Test::Builder2::History',
);

has history => (
  reader        => 'history',
  writer        => 'set_history',
  isa           => 'Test::Builder2::History',
  builder       => '_build_history',
  lazy          => 1,
);

sub _build_history {
    my $self = shift;
    $self->history_class->singleton;
}


=head3 planned_tests

Number of tests planned.

=cut

has planned_tests =>
  is            => 'rw',
  isa           => 'Int',
  default       => 0;

=head3 formatter

A Test::Builder2::Formatter object used to formatter results.

Defaults to Test::Builder2::Formatter::TAP.

=cut

has formatter_class => (
  is            => 'ro',
  isa           => 'Test::Builder2::LoadableClass',
  coerce        => 1,
  default       => 'Test::Builder2::Formatter::TAP',
);

has formatter => (
  reader        => 'formatter',
  writer        => 'set_formatter',
  isa           => 'Test::Builder2::Formatter',
  builder       => '_build_formatter',
  lazy          => 1,
);

sub _build_formatter {
    my $self = shift;
    $self->formatter_class->new;
}


=head3 top

=head3 top_stack

  my $top_stack = $tb->top_stack;

Stores the current stack of asserts as a Test::Builder2::AssertStack.

=cut

has top_stack =>
  is            => 'ro',
  isa           => 'Test::Builder2::AssertStack',
  default       => sub {
      require Test::Builder2::AssertStack;
      Test::Builder2::AssertStack->new;
  };


=head3 stream_start

  $tb->stream_start(%options);

Inform the builder that testing is about to begin.  This will allow
the builder to output any necessary headers.

Extension authors are encouraged to put method modifiers on
stream_start().

=cut

sub stream_start {
    my $self = shift;
    my %options = @_;

    %options = $self->set_plan( %options );

    $self->formatter->begin(%options);

    return;
}

=head3 stream_end

  $tb->stream_end(%options);

Inform the Builder that testing is complete.  This will allow the builder to
perform any end of testing checks and actions, such as outputting a plan, and
inform any other objects, such as the formatter.

Extension authors are encouraged to put method modifiers on
stream_end().

=cut

sub stream_end {
    my $self    = shift;
    my %options = @_;

    $self->set_plan( %options );

    $self->formatter->end(%options);
}


=head3 assert_start

  $tb->assert_start;

Called just before a user written test function begins, an assertion.

By default it records the caller at this point in C<< $self->top_stack >>
for the purposes of reporting test file and line numbers properly.

Extension authors are encouraged to put method modifiers on
assert_start()

=cut

sub assert_start {
    my $self = shift;

    my $record = Test::Builder2::AssertRecord->new_from_caller(1);
    sanity $record;

    $self->top_stack->push($record);

    return;
}

=head3 assert_end

  $tb->assert_end($result);

Like C<assert_start> but for just after a user written assert function
finishes.

By default it pops C<< $self->top_stack >> and if this is the last
assert in the stack it formats the result.

Extension authors are encouraged to put method modifiers on
assert_end().

=cut

sub assert_end {
    my $self   = shift;
    my $result = shift;

    $self->formatter->result($result) if
      $self->top_stack->at_top and defined $result;

    sanity $self->top_stack->pop;

    return;
}


=head3 set_plan

  $tb->set_plan(%plan);

Inform the builder what your test plan is, if any.

For example, Perl tests would say:

    $tb->set_plan( tests => $number_of_tests );

Extension authors are encouraged to put method modifiers on
set_plan().

=cut

sub set_plan {
    my $self = shift;
    my %plan = @_;

    $self->planned_tests($plan{tests}) if $plan{tests};

    return %plan;
}


=head3 ok

  my $result = $tb->ok( $test );
  my $result = $tb->ok( $test, $name );

Records the result of a $test.  $test is simple true for success,
false for failure.

$name is a description of the test.

Returns a Test::Builder2::Result object representing the test.

=cut

has result_class => (
  is            => 'ro',
  isa           => 'Test::Builder2::LoadableClass',
  coerce        => 1,
  default       => 'Test::Builder2::Result',
);


sub ok {
    my $self = shift;
    my $test = shift;
    my $name = shift;

    $self->assert_start();

    my $num = $self->history->counter->get + 1;

    my $result = $self->result_class->new_result(
        test_number     => $num,
        description     => $name,
        pass            => $test,
    );

    $self->accept_result($result);

    $self->assert_end($result);

    return $result;
}


=head3 accept_result

  $tb->accept_result( $result );

Records a test $result (a Test::Builder2::Result object) to C<< $tb->history >>.

This is a bare bones version of C<< ok() >>.

=cut

sub accept_result {
    my $self = shift;
    my $result = shift;

    $self->history->add_test_history( $result );

    return;
}


no Test::Builder2::Mouse;

1;
