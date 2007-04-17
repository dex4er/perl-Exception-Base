#!/usr/bin/perl -c

package Exception;
our $VERSION = 0.01;

=head1 NAME

Exception - Lightweight exceptions

=head1 SYNOPSIS

  # Use module and create needed exceptions
  use Exception (
    'Exception::IO',
    'Exception::FileNotFound' => { isa => 'Exception::IO' },
  );

  # try / catch
  try Exception eval {
    do_something() or throw Exception::FileNotFound 'Something wrong';
  };
  if (catch Exception my $e) {
    # $e is an exception object for sure
    if ($e->isa('Exception::IO') { warn "IO problem"; }
    elsif ($e->isa('Exception::Die') { warn "eval died"; }
    elsif ($e->isa('Exception::Warn') { warn "some warn was caught"; }
    elsif ($e->with(tag=>'something')) { warn "something happened"; }
    elsif ($e->with(qr/^Error/)) { warn "some error based on regex"; }
    else { $e->throw; } # rethrow the exception
  }

  # the exception can be thrown later
  $e = new Exception;
  $e->throw;

  # try with array context
  @v = try Exception [eval { do_something_returning_array(); }];

  # use syntactic sugar
  use Exception qw(try catch);
  try eval { throw Exception; };
  catch my $e, ['Exception::IO'];

=head1 DESCRIPTION

This class implements a fully OO exception mechanism similar to
Exception::Class or Class::Throwable.  It does not depend on other modules
like Exception::Class and it is more powerful than Class::Throwable.  Also it
does not use closures as Error and does not polute namespace as
Exception::Class::TryCatch.

The features of Exception:

=over 2

=item *

fully OO without closures and source code filtering

=item *

does not mess with $SIG{__DIE__} and $SIG{__WARN__}

=item *

no external modules dependencies, requires core Perl modules only

=item *

implements error stack, the try/catch blocks can be nested

=item *

shows full backtrace stack on die

=item *

the default behaviour of exception class can be changed globally or just for
the thrown exception

=item *

the exception can be created with defined custom properties

=item *

matching the exception by class, message or custom properties

=item *

matching with string, regex or closure function

=item *

creating automatically the derived exception classes

=item *

easly expendable, see Exception::System class

=back

=cut


use strict;
use Carp ();
use Exporter ();


# Export try/catch syntactic sugar
our @EXPORT_OK = qw(try catch);


# Overload the stringify operation
use overload q|""| => "_stringify", fallback => 1;


# List of class fields
sub FIELDS () {
    {
        message      => 'rw',
        caller_stack => 'ro',
        egid         => 'ro',
        euid         => 'ro',
        gid          => 'ro',
        pid          => 'ro',
        tid          => 'ro',
        properties   => 'ro',
        time         => 'ro',
        uid          => 'ro',
        verbosity    => 'rw',
        max_arg_len  => 'rw',
        max_arg_nums => 'rw',
        max_eval_len => 'rw',
    };
}
our %FIELDS = %{ FIELDS() };


# List of package defaults
sub DEFAULTS () {
    {
        VERBOSITY    => 3,
        MESSAGE      => 'Unknown exception',
        MAX_ARG_LEN  => 64,
        MAX_ARG_NUMS => 8,
        MAX_EVAL_LEN => 0,
    };
}
our %DEFAULTS = %{ DEFAULTS() };


# Exception stack for try/catch blocks
my @exception_stack;


# Export try/catch and create additional exception packages
sub import {
    my $pkg = shift;

    my @export;

    while (defined $_[0]) {
        my $name = shift;
        if ($name eq 'try' or $name eq 'catch') {
            push @export, $name;
        }
        else {
            if ($pkg ne __PACKAGE__) {
                Carp::croak("Exceptions can only be created with " . __PACKAGE__ . " class");
            }
            if ($name eq __PACKAGE__) {
                Carp::croak(__PACKAGE__ . " class can not be created automatically");
            }
            my $isa = __PACKAGE__;
            my $version = 0.1;
            if (defined $_[0] and ref $_[0] eq 'HASH') {
                my $param = shift;
                $isa = $param->{isa} if defined $param->{isa};
                $version = $param->{version} if defined $param->{version};
            }
            my $code = << "END";
package ${name};
use base qw(${isa});
our \$VERSION = ${version};
END
            eval $code;
            if ($@) {
                Carp::croak("An error occured while constructing " . __PACKAGE__ . " exception class ($name) : $@");
            }
        }
    }

    if (@export) {
        my $callpkg = caller;
        Exporter::export($pkg, $callpkg, @export);
    }

    return 1;
}


# Unexport try/catch
sub unimport {
    my $pkg = shift;
    my $callpkg = caller;

    my @export = @_ || qw[catch try];

    no strict 'refs';
    while (my $name = shift @export) {
        if ($name eq 'try' or $name eq 'catch') {
            if (defined &{$callpkg . '::' . $name}) {
                delete ${$callpkg . '::'}{$name};
            }
        }
    }

    return 1;
}


# Constructor
sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $self = {};

    # If the attribute is rw, initialize its value. Otherwise: properties.
    my %args = @_;
    $self->{properties} = {};
    foreach my $key (keys %args) {
        if (defined $FIELDS{$key} and $FIELDS{$key} eq 'rw') {
            $self->{$key} = $args{$key};
        }
        else {
            $self->{properties}->{$key} = $args{$key};
        }
    }

    $self->{defaults} = { %DEFAULTS };

    return bless $self => $class;
}


# Create the exception and throw it or rethrow existing
sub throw {
    my $self = shift;

    # rethrow the exception; update the system data
    if (_blessed($self) and $self->isa(__PACKAGE__)) {
        $self->_collect_system_data;
        die $self;
    }

    # new exception
    my $e = $self->new(@_);

    $e->_collect_system_data;
    die $e;
}


# Convert an exception to string
sub stringify {
    my $self = shift;
    my $verbosity = shift;
    my $message = shift;

    $verbosity = defined $self->{verbosity} ? $self->{verbosity} : $self->{defaults}->{VERBOSITY}
        if not defined $verbosity;
    $message = defined $self->{message} ? $self->{message} : $self->{defaults}->{MESSAGE}
        if not defined $message;

    my $string;

    if ($verbosity == 1) {
        $string = $message . "\n";
    }
    elsif ($verbosity == 2) {
        $string = sprintf "%s at %s line %d.\n",
            $message,
            defined $self->{caller_stack} && $self->{caller_stack}->[0]->[1]
                ? $self->{caller_stack}->[0]->[1]
                : 'unknown',
            defined $self->{caller_stack} && $self->{caller_stack}->[0]->[2]
                ? $self->{caller_stack}->[0]->[2]
                : 0;
    }
    elsif ($verbosity >= 3) {
        $string .= sprintf "%s: %s", ref $self, $message;
        $string .= $self->_caller_backtrace;
    }
    else {
        $string = "";
    }

    return $string;
}


# Stringify for overloaded operator
sub _stringify {
    my $self = shift;
    return $self->stringify();
}


# Check if an exception object has some attributes
sub with {
    my $self = shift;
    return unless @_;

    if (scalar @_ % 2 == 1) {
        my $message = shift;
        if (not defined $message) {
            return 0 if defined $self->{message};
        }
        elsif (not defined $self->{message}) {
            return 0;
        }
        elsif (ref $message eq 'CODE') {
            $_ = $self->{message};
            return 0 if not &$message;
        }
        elsif (ref $message eq 'Regexp') {
            $_ = $self->{message};
            return 0 if not /$message/;
        }
        else {
            return 0 if $self->{message} ne $message;
        }
    }

    my %a = @_;
    while (my($key,$val) = each %a) {
        return 0 if not defined $val and
            defined $self->{properties}->{$key} || exists $self->{$key} && defined $self->{$key};

        return 0 if defined $val and not
            defined $self->{properties}->{$key} || exists $self->{$key} && defined $self->{$key};

        if (defined $val and
            defined $self->{properties}->{$key} || exists $self->{$key} && defined $self->{$key})
        {
            if (ref $val eq 'CODE') {
                if (defined $self->{properties}->{$key}) {
                    $_ = $self->{properties}->{$key};
                    next if &$val;
                }
                return 0 unless exists $self->{$key} and defined $self->{$key};
                $_ = $self->{$key};
                return 0 if not &$val;
            }
            elsif (ref $val eq 'Regexp') {
                if (defined $self->{properties}->{$key}) {
                    $_ = $self->{properties}->{$key};
                    next if /$val/;
                }
                return 0 unless exists $self->{$key} and defined $self->{$key};
                $_ = $self->{$key};
                return 0 if not /$val/;
            }
            else {
                next if defined $self->{properties}->{$key} and $self->{properties}->{$key} eq $val;
                return 0 unless exists $self->{$key} and defined $self->{$key};
                return 0 if $self->{$key} ne $val;
            }
        }
    }

    return 1;
}


# Push the exception on error stack. Stolen from Exception::Class::TryCatch
sub try ($) {
    # Can be used also as function
    my $self = shift if defined $_[0] and $_[0] eq __PACKAGE__ or
                        _blessed($_[0]) and $_[0]->isa(__PACKAGE__);

    my $v = shift;
    push @exception_stack, $@;
    return ref($v) eq 'ARRAY' ? @$v : $v if wantarray;
    return $v;
}


# Pop the exception on error stack. Stolen from Exception::Class::TryCatch
sub catch {
    # Can be used also as function
    my $self = shift if defined $_[0] and $_[0] eq __PACKAGE__ or
                        _blessed($_[0]) and $_[0]->isa(__PACKAGE__);

    my $e;
    my $exception = @exception_stack ? pop @exception_stack : $@;
    if (
    #_blessed($exception) and
     $exception->isa(__PACKAGE__)) {
        $e = $exception;
    }
    elsif ($exception eq '') {
        $e = undef;
    }
    else {
        my $class = ref $self || __PACKAGE__;
        $e = $class->new(message=>"$exception");
        $e->_collect_system_data;
    }
    if (ref($_[0]) ne 'ARRAY') {
        $_[0] = $e;
        shift;
    }
    if (defined $e) {
        if (defined $_[0] and ref $_[0] eq 'ARRAY') {
            $e->throw() unless grep { $e->isa($_) } @{$_[0]};
        }
    }
    return defined $e;
}


# Collect system data and fill the attributes and caller stack.
sub _collect_system_data {
    my $self = shift;

    $self->{time}  = CORE::time();
    $self->{pid}   = $$;
    $self->{tid}   = Thread->self->tid if defined &Thread::tid;
    $self->{uid}   = $<;
    $self->{euid}  = $>;
    $self->{gid}   = $(;
    $self->{egid}  = $);

    my $verbosity = defined $self->{verbosity} ? $self->{verbosity} : $self->{defaults}->{VERBOSITY};
    if ($verbosity > 1) {
        my @caller_stack;
        my $pkg = __PACKAGE__;
        for (my $i = 1; my @c = do { package DB; caller($i) }; $i++) {
            next if $c[0] eq $pkg;
            push @caller_stack, [ @c[0 .. 7], @DB::args ];
            last if $verbosity < 3;
        }
        $self->{caller_stack} = \@caller_stack;
    }

    return $self;
}


# Stringify caller backtrace. Stolen from Carp
sub _caller_backtrace {
    my $self = shift;
    my $i = 0;
    my $mess;

    my $tid_msg = '';
    $tid_msg = ' thread ' . $self->{tid} if $self->{tid};

    my %i = ($self->_caller_info($i));
    $i{file} = 'unknown' unless $i{file};
    $i{line} = 0 unless $i{line};
    $mess = " at $i{file} line $i{line}$tid_msg\n";

    while (my %i = $self->_caller_info(++$i)) {
        $mess .= "\t$i{wantarray}$i{sub_name} called at $i{file} line $i{line}$tid_msg\n";
    }

    return $mess;
}


# Return info about caller. Stolen from Carp
sub _caller_info {
    my $self = shift;
    my $i = shift;
    my %call_info;
    my @call_info = ();

    @call_info = @{ $self->{caller_stack}->[$i] }
        if defined $self->{caller_stack} and defined $self->{caller_stack}->[$i];

    @call_info{
        qw(pack file line sub has_args wantarray evaltext is_require)
    } = @call_info[0..7];

    unless (defined $call_info{pack}) {
        return ();
    }

    my $sub_name = $self->_get_subname(\%call_info);
    if ($call_info{has_args}) {
        my @args = map {$self->_format_arg($_)} @call_info[8..$#call_info];
        my $max_arg_nums = defined $self->{max_arg_nums} ? $self->{max_arg_nums} : $self->{defaults}->{MAX_ARG_NUMS};
        if ($max_arg_nums > 0 and $#args+1 > $max_arg_nums) {
            $#args = $max_arg_nums - 2;
            push @args, '...';
        }
        # Push the args onto the subroutine
        $sub_name .= '(' . join (', ', @args) . ')';
    }
    $call_info{file} = 'unknown' unless $call_info{file};
    $call_info{line} = 0 unless $call_info{line};
    $call_info{sub_name} = $sub_name;
    $call_info{wantarray} = $call_info{wantarray} ? '@_ = ' : '$_ = ';
    return wantarray() ? %call_info : \%call_info;
}


# Figures out the name of the sub/require/eval. Stolen from Carp
sub _get_subname {
    my $self = shift;
    my $info = shift;
    if (defined($info->{evaltext})) {
        my $eval = $info->{evaltext};
        if ($info->{is_require}) {
            return "require $eval";
        }
        else {
            $eval =~ s/([\\\'])/\\$1/g;
            return
                "eval '" .
                $self->_str_len_trim($eval, defined $self->{max_eval_len} ? $self->{max_eval_len} : $self->{defaults}->{MAX_EVAL_LEN}) .
                "'";
        }
    }
    return ($info->{sub} eq '(eval)') ? 'eval {...}' : $info->{sub};
}


# Transform an argument to a function into a string. Stolen from Carp
sub _format_arg {
    my $self = shift;
    my $arg = shift;

    return 'undef' if not defined $arg;

    # Be careful! Do not recurse with our stringify!
    return '"' . overload::StrVal($arg) . '"' if ref $arg;

    $arg =~ s/\\/\\\\/g;
    $arg =~ s/"/\\"/g;
    $arg =~ s/`/\\`/g;
    $arg = $self->_str_len_trim($arg, defined $self->{max_arg_len} ? $self->{max_arg_len} : $self->{defaults}->{MAX_ARG_LEN});

    $arg = "\"$arg\"" unless $arg =~ /^-?[\d.]+\z/;

    use utf8;  #! should be here?
    if (defined $utf8::VERSION and utf8::is_utf8($arg)) {
        $arg = join('', map { $_ > 255
            ? sprintf("\\x{%04x}", $_)
            : chr($_) =~ /[[:cntrl:]]|[[:^ascii:]]/
                ? sprintf("\\x{%02x}", $_)
                : chr($_)
        } unpack("U*", $arg));
    }
    else {
        $arg =~ s/([[:cntrl:]]|[[:^ascii:]])/sprintf("\\x{%02x}",ord($1))/eg;
    }

    return $arg;
}


# If a string is too long, trims it with ... . Stolen from Carp
sub _str_len_trim {
    my $self = shift;
    my $str = shift;
    my $max = shift || 0;
    if ($max > 2 and $max < length($str)) {
        substr($str, $max - 3) = '...';
    }
    return $str;
}


# Universal method for _blessed(). Stolen from Scalar::Util
sub UNIVERSAL::Exception__a_sub_not_likely_to_be_here {
    return ref($_[0]);
}


# Check if scalar is blessed. This is function, not a method!
eval "use Scalar::Util 'blessed';";
if (defined &Scalar::Util::blessed) {
    *_blessed = \&Scalar::Util::blessed;
}
else {
    eval << 'END';

    sub _blessed ($) {
        local($@, $SIG{__DIE__}, $SIG{__WARN__});
        return length(ref($_[0]))
            ? eval { $_[0]->Exception__a_sub_not_likely_to_be_here }
            : undef;
    }
END
}

1;


=head1 IMPORTS

=head2 qw(catch try)

Exports the catch and try functions to the caller namespace.

  use Exception qw(catch try);
  try eval { throw Exception; };
  if (catch my $e) { warn "$e"; }

=head2 I<Exception>

Creates the exception class automatically at compile time.  The newly created
class will be based on Exception class.

  use Exception qw(Exception::Custom);
  throw Exception::Custom;

=head2 I<Exception> => { isa => I<BaseException>, version => I<version> }

Creates the exception class automatically at compile time.  The newly created
class will be based on given class and has the given $VERSION attribute.

  use Exception
    'try', 'catch',
    'Exception::IO',
    'Exception::FileNotFound' => { isa => 'Exception::IO' },
    'Exception::My' => { version => 0.2 };
  try eval { throw Exception::FileNotFound; };
  if (catch my $e) {
    if ($e->isa('Exception::IO')) { warn "can be also FileNotFound"; }
    if ($e->isa('Exception::My')) { print $e->VERSION; }
  }

=head1 CONSTANTS

=head2 _FIELDS, FIELDS

Declaration of class attibutes as reference to hash.  B<_FIELDS> is the list
of this package fields.  The B<FIELDS> is the list of fields for this package
and derived classes.  These constants have to be implemented by derived
classes.

  package Exception::My;
  our $VERSION = 0.1;
  use base 'Exception';

  # Define class fields
  use constant _FIELDS => {
    readonly  => 'ro',
    readwrite => 'rw',
  };
  use constant FIELDS => {
    %{Exception->_FIELDS},   # Base's fields have to be first
    %{+_FIELDS},
  };
  use fields keys %{+_FIELDS};

  # Implement accessors
  {
    no strict 'refs';
    foreach my $func (keys %{+_FIELDS}) {
      if (${+_FIELDS}{$func} eq 'ro') {
        *{__PACKAGE__.'::'.$func} = do { use strict 'refs';
            sub () { shift->{$func}; }; };
      }
      elsif (${+_FIELDS}{$func} eq 'rw') {
        *{__PACKAGE__.'::'.$func} = do { use strict 'refs';
            sub () :lvalue { my $self = shift;
                @_ ? ($self->{$func} = $_[0]) : $self->{$func}; }; };
      }
    }
  }

=head1 PACKAGE DEFAULTS

Package defaults are implemented as %Exception::defaults hash.  The
values can be read and written with accessors.

=head2 VERBOSITY (rw)

The default verbosity of the exception objects.

  Exception->VERBOSITY = 3;
  throw Exception message=>"Message";

=head2 MESSAGE (rw)

The default message of the exception objects.

  Exception->MESSAGE = 'Unknown exception';
  throw Exception;

=head2 MAX_ARG_LEN (rw)

The default maximal length of argument for functions in backtrace output.
Zero means no limit for length.

  Exception->MAX_ARG_LEN = 64;
  throw Exception;

=head2 MAX_ARG_NUMS (rw)

The default maximal number of argument for functions in backtrace output.
Zero means no limit for arguments.

  Exception->MAX_ARG_NUMS = 8;
  throw Exception;

=head2 MAX_EVAL_LEN (rw)

The default maximal length of eval strings in backtrace output.  Zero means no
limit for length.

  Exception->MAX_EVAL_LEN = 0;
  throw Exception;

=head1 ATTRIBUTES

=head2 message (rw)

Contains the message of the exception.  It is the part of the string
representing the exception object.

  eval { throw Exception message=>"Message", tag=>"TAG"; };
  print $@->message if $@;

=head2 properties (ro)

Contains the additional properies of the exception.  They can be later used
with "with" method.

  eval { throw Exception message=>"Message", tag=>"TAG"; };
  print $@->properties->{tag} if $@;

=head2 verbosity (rw)

Contains the verbosity level of the exception object.  It allows to change
the string representing the exception object.  There are following levels of
verbosity:

=over 2

=item 0

Empty string

=item 1

Message

=item 2

Message at %s line %d.

The same as the standard output of die() function.

=item 3

Class: Message
  at ...

The output contains full trace of error stack.  This is the default option.

If the verbosity is undef, then the default verbosity for exception objects
is used (see VERBOSITY variable).

=back

=head2 time (ro)

Contains the timestamp of the thrown exception.

  eval { throw Exception message=>"Message"; };
  print scalar localtime $@->time;

=head2 pid (ro)

Contains the PID of the Perl process at time of thrown exception.

  eval { throw Exception message=>"Message"; };
  kill 10, $@->pid;

=head2 tid (ro)

Constains the tid of the thread or undef if threads are not used.

=head2 uid, euid, gid, egid (ro)

Contains the real and effective uid and gid of the Perl process at time of
thrown exception.

=head2 caller_stack (ro)

Contains the error stack as array of array with informations about caller
functions.  The first 8 elements of the array's row are the same as first 8
elements of the output of caller() function.  Further elements are optional
and are the arguments of called function.

  eval { throw Exception message=>"Message"; };
  ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext,
  $is_require, @args) = $@->caller_stack->[0];

=head2 max_arg_len (rw)

Contains the maximal length of argument for functions in backtrace output.
Zero means no limit for length.

  sub a { throw Exception max_arg_len=>5 }
  a("123456789");

=head2 max_arg_nums (rw)

Contains the maximal number of arguments for functions in backtrace output.
Zero means no limit for arguments.

  sub a { throw Exception max_arg_nums=>1 }
  a(1,2,3);

=head2 max_eval_len (rw)

Contains the maximal length of eval strings in backtrace output.  Zero means
no limit for length.

  eval "throw Exception max_eval_len=>10";
  print "$@";

=head1 CONSTRUCTORS

=head2 new([%I<args>])

Creates the exception object, which can be thrown later.  The system data
attributes B<time>, B<pid>, B<uid>, B<gid>, B<euid>, B<egid> are not filled.

If the key of the argument is read-write attribute, this attribute will be
filled.  Otherwise, the properties attribute will be used.

  $e = new Exception message=>"Houston, we have a problem", tag => "BIG";
  print $e->message;
  print $e->properties->{tag};

=head2 throw([%I<args>]])

Creates the exception object and immediately throws it with die() function.

  open FILE, $file or throw Exception message=>"Can not open file: $file";

=head1 METHODS

=head2 throw([$I<exception>])

Immediately throws exception object with die() function.  It can be used as
for throwing new exception as for rethrowing existing exception object.

  eval { throw Exception message=>"Problem", tag => "TAG"; };
  # rethrow, $@ is an exception object
  $@->throw if $@->properties->{tag} eq "TAG";

=head2 stringify([$I<verbosity>[, $I<message>]])

Returns the string representation of exception object.  It is called
automatically if the exception object is used in scalar context.  The method
can be used explicity and then the verbosity level can be used.

  eval { throw Exception; };
  $@->verbosity = 1;
  print "$@";
  print $@->stringify(3) if $VERY_VERBOSE;

=head2 with(I<condition>)

Checks if the exception object matches the given condition.  If the first
argument is single value, the B<message> attribute will be matched.  If the
argument is a part of hash, the B<properties> attribute will be matched or
the attribute of the exception object if the B<properties> attribute is not
defined.

  $e->with("message");
  $e->with(tag=>"property");
  $e->with("message", tag=>"and the property");
  $e->with(tag1=>"property", tag2=>"another property");
  $e->with(uid=>0);
  $e->with(message=>'$e->properties->{message} or $e->message');

The argument (for message or properties) can be simple string or code
reference or regexp.

  $e->with("message");
  $e->with(sub {/message/});
  $e->with(qr/message/);

=head2 try(I<eval>)

The "try" method or function can be used with eval block as argument.  Then
the eval's error is pushed into error stack and can be used with "catch"
later.

  try Exception eval { throw Exception; };
  eval { die "another error messing with \$@ variable"; };
  catch Exception my $e;

The "try" returns the value of the argument in scalar context.  If the
argument is array reference, the "try" returns the value of the argument in
array context.

  $v = try Exception eval { 2 + 2; }; # $v == 4
  @v = try Exception [ eval { (1,2,3); }; ]; # @v = (1,2,3)

The "try" can be used as method or function.

  try Exception eval { throw Exception "method"; };
  Exception::try eval { throw Exception "function"; };
  Exception->import('try');
  try eval { throw Exception "exported function"; };

=head2 catch($I<exception>)

The exception is popped from error stack (or B<$@> variable is used if stack
is empty) and the exception is written into the method argument.

  eval { throw Exception; };
  catch Exception my $e;
  print $e->stringify(1);

If the B<$@> variable does not contain the exception object but string, new
exception object is created with message from B<$@> variable.

  eval { die "Died\n"; };
  catch Exception my $e;
  print $e->stringify;

=head2 catch([$I<exception>,] \@I<ExceptionClasses>)

The exception is popped from error stack (or $@ variable is used if stack is
empty).  If the exception is not based on one of the class from argument, the
exception is throwed immediately.

  eval { throw Exception::IO; }
  catch Exception my $e, ['Exception::IO'];
  print "Only IO exception was caught: " . $e->stringify(1);

=head1 INHERITANCE METHODS

=head2 _collect_system_data

Collect system data and fill the attributes of exception object.  This method
is called automatically if exception if throwed.  It can be used by derived
class.

  package Exception::Special;
  use base 'Exception';
  use fields qw(special);
  sub _collect_system_data {
    my $self = shift;
    $self->SUPER::_collect_system_data(@_);
    $self->{special} = get_special_value();
    return $self;
  }

=head1 AUTHORS

Piotr Roszatycki E<lt>dexter@debian.orgE<gt>

=head1 COPYRIGHT

Copyright 2007 by Piotr Roszatycki E<lt>dexter@debian.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
