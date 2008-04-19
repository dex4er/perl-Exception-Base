#!/usr/bin/perl -c

package Exception::Base;
use 5.006;
our $VERSION = 0.15;

=head1 NAME

Exception::Base - Lightweight exceptions

=head1 SYNOPSIS

  # Use module and create needed exceptions
  use Exception::Base (
    ':all',                            # import try/catch/throw
    'Exception::Runtime',              # create new module
    'Exception::System',               # load existing module
    'Exception::IO',          => {
        isa => 'Exception::System' },  # create new based on existing
    'Exception::FileNotFound' => {
        message => 'File not found',
        isa => 'Exception::IO' },      # create new based on new
  );

  # try / catch
  try eval {
    do_something() or throw 'Exception::FileNotFound' =>
                            message=>'Something wrong',
                            tag=>'something';
  };
  # Catch the Exception::Base and derived, rethrow immediately others
  if (catch my $e) {
    # $e is an exception object for sure, no need to check if is blessed
    if ($e->isa('Exception::IO')) { warn "IO problem"; }
    elsif ($e->isa('Exception::Eval')) { warn "eval died"; }
    elsif ($e->isa('Exception::Runtime')) { warn "some runtime was caught"; }
    elsif ($e->with(tag=>'something')) { warn "something happened"; }
    elsif ($e->with(qr/^Error/)) { warn "some error based on regex"; }
    else { $e->throw; } # rethrow the exception
  }

  # the exception can be thrown later
  $e = Exception::Base->new;
  # (...)
  $e->throw;

  # try with array context
  @v = try [eval { do_something_returning_array(); }];

  # catch only IO errors, rethrow immediately others
  try eval { File::Stat::Moose->stat("/etc/passwd") };
  catch my $e, ['Exception::IO'];

  # immediately rethrow all caught exceptions and eval errors
  try eval { die "Bang!\n" };
  catch my $e, [];

  # don't use syntactic sugar
  use Exception::Base;          # does not import ':all' tag
  Exception::Base->try(eval {
    Exception::IO->throw;
  });
  Exception::Base->catch(my $e);  # catch Exception::Base and derived
  # or
  Exception::IO->catch(my $e);    # catch IO errors and rethrow others

  # run Perl with changed verbosity
  sh$ perl -MException::Base=verbosity,4 script.pl

=head1 DESCRIPTION

This class implements a fully OO exception mechanism similar to
L<Exception::Class> or L<Class::Throwable>.  It does not depend on other
modules like L<Exception::Class> and it is more powerful than
L<Class::Throwable>.  Also it does not use closures as L<Error> and does not
polute namespace as L<Exception::Class::TryCatch>.  It is also much faster
than L<Exception::Class>.

The features of L<Exception::Base>:

=over 2

=item *

fast implementation of an exception object

=item *

fully OO without closures and source code filtering

=item *

does not mess with $SIG{__DIE__} and $SIG{__WARN__}

=item *

no external modules dependencies, requires core Perl modules only

=item *

implements error stack, the try/catch blocks can be nested

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

creating automatically the derived exception classes ("use" interface)

=item *

easly expendable, see L<Exception::System> class for example

=back

=cut


use strict;
use warnings;

use utf8;


# Safe operations on symbol stash
BEGIN { *Symbol::fetch_glob = sub ($) { no strict 'refs'; \*{$_[0]} } unless defined &Symbol::fetch_glob; }


# Syntactic sugar
use Exporter ();
our @EXPORT_OK = qw< try catch throw >;
our %EXPORT_TAGS = (all => [@EXPORT_OK]);


# Overload the stringify operation
use overload q|""| => "_stringify", fallback => 1;


# List of class fields (name => {is=>ro|rw, default=>value})
use constant FIELDS => {
    properties     => { },
    defaults       => { },
    message        => { is => 'rw', default => 'Unknown exception' },
    eval_error     => { is => 'ro' },
    caller_stack   => { is => 'ro' },
    egid           => { is => 'ro' },
    euid           => { is => 'ro' },
    gid            => { is => 'ro' },
    pid            => { is => 'ro' },
    tid            => { is => 'ro' },
    time           => { is => 'ro' },
    uid            => { is => 'ro' },
    verbosity      => { is => 'rw', default => 2 },
    ignore_package => { is => 'rw', default => [ ] },
    ignore_class   => { is => 'rw', default => [ ] },
    ignore_level   => { is => 'rw', default => 0 },
    max_arg_len    => { is => 'rw', default => 64 },
    max_arg_nums   => { is => 'rw', default => 8 },
    max_eval_len   => { is => 'rw', default => 0 },
};


# Cache for class' FIELDS
my %Class_Fields;


# Cache for class' defaults
my %Class_Defaults;


# Cache for $obj->isa(__PACKAGE__)
my %Isa_Package;


# Exception stack for try/catch blocks
my @Exception_Stack;


# Export try/catch and create additional exception packages
sub import {
    my $pkg = shift;

    my @export;

    while (defined $_[0]) {
        my $name = shift @_;
        if ($name =~ /^(try|catch|throw|:all)$/) {
            push @export, $name;
        }
        elsif ($name =~ /^([+-]?)([a-z0-9_]+)$/) {
            # Lower case: change default
            my ($modifier, $key) = ($1, $2);
            my $value = shift;
            $pkg->_modify_default_value($key, $value, $modifier);
        }
        else {
            # Try to use external module
            my $param = shift @_ if defined $_[0] and ref $_[0] eq 'HASH';
            my $version = defined $param->{version} ? $param->{version} : 0;
            my $mod_version = eval { $name->VERSION } || 0;
            if (not $mod_version or $version > $mod_version) {
                # Package is needed
                eval "use $name $version;";
                if ($@) {
                    # Die unless can't load module
                    if ($@ !~ /Can\'t locate/) {
                        Exception::Base->throw(
                              message => "Can not load available $name class: $@",
                              verbosity => 1
                        );
                    }

                    # Package not found so it have to be created
                    if ($pkg ne __PACKAGE__) {
                        Exception::Base->throw(
                              message => "Exceptions can only be created with " . __PACKAGE__ . " class",
                              verbosity => 1
                        );
                    }
                    # Paranoid check
                    if ($name eq __PACKAGE__) {
                        Exception::Base->throw(
                              message => "$name class can not be created automatically",
                              verbosity => 1
                        );
                    }
                    my $isa = defined $param->{isa} ? $param->{isa} : __PACKAGE__;
                    $version = 0.01 if not $version;

                    # Base class is needed
                    {
                        if (not defined eval { $isa->VERSION }) {
                            eval "use $isa;";
                            if ($@) {
                                Exception::Base->throw(
                                      message => "Base class $isa for class $name can not be found",
                                      verbosity => 1
                                );
                            }
                        }
                    }

                    # Handle defaults for fields
                    my $fields;
                    eval { $fields = $isa->FIELDS };
                    if ($@) {
                        Exception::Base->throw(
                              message => "$name class is based on $isa class which does not implement FIELDS",
                              verbosity => 1
                        );
                    }

                    # Create the hash with overriden fields
                    my %overriden_fields;
                    foreach my $field (keys %{ $param }) {
                        next if $field =~ /^(isa|version)$/;
                        if (not exists $fields->{$field}->{default}) {
                            Exception::Base->throw(
                                  message => "$isa class does not implement default value for $field field",
                                  verbosity => 1
                            );
                        }
                        $overriden_fields{$field} = {};
                        $overriden_fields{$field}->{default} = $param->{$field};
                        foreach my $property (keys %{ $fields->{$field} }) {
                            next if $property eq 'default';
                            $overriden_fields{$field}->{$property} = $fields->{$field}->{$property};
                        }
                    }

                    # Create the new package
                    ${ *{Symbol::fetch_glob($name . '::VERSION')} } = $version;
                    @{ *{Symbol::fetch_glob($name . '::ISA')} } = ($isa);
                    *{Symbol::fetch_glob($name . '::FIELDS')} = sub {
                        return { %{ $isa->FIELDS }, %overriden_fields };
                    };
                }
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

    # Unexport all by default
    my @export = scalar @_ ? @_ : ':all';

    while (my $name = shift @export) {
        if ($name eq ':all') {
            unshift @export, @EXPORT_OK;
        }
        elsif ($name eq 'try' or $name eq 'catch' or $name eq 'throw') {
            if (defined *{Symbol::fetch_glob($callpkg . '::' . $name)}{CODE}) {
                # Store and restore other typeglobs than CODE
                my %glob;
                foreach my $type (qw< SCALAR ARRAY HASH IO FORMAT >) {
                    $glob{$type} = *{Symbol::fetch_glob($callpkg . '::' . $name)}{$type}
                        if defined *{Symbol::fetch_glob($callpkg . '::' . $name)}{$type};
                }
                undef *{Symbol::fetch_glob($callpkg . '::' . $name)};
                foreach my $type (qw< SCALAR ARRAY HASH IO FORMAT >) {
                    *{Symbol::fetch_glob($callpkg . '::' . $name)} = $glob{$type}
                        if defined $glob{$type};
                }
            }
        }
    }

    return 1;
}


# Constructor
sub new {
    my $class = shift;
    $class = ref $class if ref $class;

    my $fields;
    my $defaults;

    # Use cached value if available
    if (not defined $Class_Fields{$class}) {
        $fields = $Class_Fields{$class} = $class->FIELDS;
        $defaults = $Class_Defaults{$class} = {
            map { $_ => $fields->{$_}->{default} }
                grep { defined $fields->{$_}->{default} }
                    (keys %$fields)
        };
    }
    else {
        $fields = $Class_Fields{$class};
        $defaults = $Class_Defaults{$class};
    }

    my $self = {};

    # If the attribute is rw, initialize its value. Otherwise: properties.
    no warnings 'uninitialized';
    my %args = @_;
    $self->{properties} = {};
    foreach my $key (keys %args) {
        if ($fields->{$key}->{is} eq 'rw') {
            $self->{$key} = $args{$key};
        }
        else {
            $self->{properties}->{$key} = $args{$key};
        }
    }

    # Defaults for this object
    $self->{defaults} = { %$defaults };

    bless $self => $class;
    $self->_collect_system_data;

    return $self;
}


# Create the exception and throw it or rethrow existing
sub throw (;$@) {
    my $self = shift;

    my $old;
    my $class = ref $self;
    if (not ref $self) {
        # throw new exception
        if (scalar @_ % 2 == 0) {
            # throw new exception if there was no error
            die $self->new(@_) if not $@;
            # otherwise collect pure eval error message
            $class = $self;
            $old = $@;
        }
        else {
            # rethrow old exception
            $class = $self;
            $old = shift @_;
        }
    }
    else {
        # rethrow old exception
        $class = ref $self;
        $old = $self;
    }

    # check if $old is an exception
    if (ref $old and do { local $@; local $SIG{__DIE__}; eval { $old->isa(__PACKAGE__) } }) {
        no warnings 'uninitialized';
        my %args = @_;
        my $fields = $self->FIELDS;
        foreach my $key (keys %args) {
            if ($fields->{$key}->{is} eq 'rw') {
                $old->{$key} = $args{$key};
            }
            else {
                $old->{properties}->{$key} = $args{$key};
            }
        }
        if (ref $old ne $class) {
            # rebless if this is new class
            bless $old => $class;
        }
        die $old;
    }

    # rethrow pure eval error
    $old =~ s/( at (?!.*\bat\b.*).* line \d+( thread \d+)?\.)?\n$//s;
    my $e = $class->new(@_);
    $e->{eval_error} = $old;
    die $e;
}


# Convert an exception to string
sub stringify {
    my ($self, $verbosity, $message) = @_;

    $verbosity = defined $self->{verbosity}
               ? $self->{verbosity}
               : $self->{defaults}->{verbosity}
        if not defined $verbosity;

    my $string;

    $message = $self->{message} if not defined $message;

    my $is_message = defined $message && $message ne '';
    my $is_eval_error = $self->{eval_error};

    if ($is_message or $is_eval_error) {
        $message = ($is_message ? $message : '')
                . ($is_message && $is_eval_error ? ': ' : '')
                . ($is_eval_error ? $self->{eval_error} : '');
    }
    else {
        $message = $self->{defaults}->{message};
    }

    if ($verbosity == 1) {
        $string = $message . "\n";
    }
    elsif ($verbosity == 2) {
        my $file = $self->file;
        $string = sprintf "%s at %s line %d.\n",
            $message,
            defined $file && $file ne '' ? $file : 'unknown',
            $self->line || 0;
    }
    elsif ($verbosity >= 3) {
        $string .= sprintf "%s: %s", ref $self, $message;
        $string .= $self->_caller_backtrace($verbosity);
    }
    else {
        $string = q{};
    }

    return $string;
}


# Stringify for overloaded operator
sub _stringify {
    return $_[0]->stringify;
}


# Check if an exception object has some attributes
sub with {
    my $self = shift;
    return unless @_;

    # Odd number of arguments - first is message
    if (scalar @_ % 2 == 1) {
        my $message = shift @_;
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
        return 1 unless @_;
    }


    my %args = @_;
    while (my($key,$val) = each %args) {
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
sub try ($;$) {
    # Can be used also as function
    my $self = shift if defined $_[0] and do { local $@; local $SIG{__DIE__}; eval { $_[0]->isa(__PACKAGE__) } };

    my ($v) = @_;

    push @Exception_Stack, $@;
    return wantarray && ref $v eq 'ARRAY' ? @$v : $v;
}


# Pop the exception on error stack. Stolen from Exception::Class::TryCatch
sub catch (;$$) {
    # Can be used also as function
    my $self = shift if defined $_[0] and do { local $@; local $SIG{__DIE__}; eval { $_[0]->isa(__PACKAGE__) } };

    # Recover class from object or set the default
    my $class = defined $self ? (ref $self || $self) : __PACKAGE__;

    # Will return exception object if no argument
    my $want_object = 1;

    my $e;
    my $e_from_stack = @Exception_Stack ? pop @Exception_Stack : '';
    if (ref $e_from_stack and do { local $@; local $SIG{__DIE__}; eval { $e_from_stack->isa(__PACKAGE__) } }) {
        # Caught exception
        $e = $e_from_stack;
    }
    elsif ($e_from_stack eq '') {
        # No error in $@
        $e = undef;
    }
    else {
        # New exception based on error from $@. Clean up the message.
        $e_from_stack =~ s/( at (?!.*\bat\b.*).* line \d+( thread \d+)?\.)?\n$//s;
        $e = $class->new;
        $e->{eval_error} = $e_from_stack;
    }

    if (scalar @_ > 0 and ref($_[0]) ne 'ARRAY') {
        # Save object in argument, return only status
        $_[0] = $e;
        shift @_;
        $want_object = 0;
    }
    if (defined $e) {
        # For real exceptions...
        if (defined $self and not do { local $@; local $SIG{__DIE__}; eval { $e->isa($class) } }) {
            # ... throw if the exception is not our class
            $e->throw;
        }
        if (defined $_[0] and ref $_[0] eq 'ARRAY') {
            # ... throw if the exception class is not listed
            $e->throw unless grep { do { local $@; local $SIG{__DIE__}; eval { $e->isa($_) } } } @{$_[0]};
        }
    }
    # Return status or object
    return $want_object ? $e : defined $e;
}


# Collect system data and fill the attributes and caller stack.
sub _collect_system_data {
    my ($self) = @_;

    # Collect system data only if verbosity is meaning
    my $verbosity = defined $self->{verbosity} ? $self->{verbosity} : $self->{defaults}->{verbosity};
    if ($verbosity > 1) {
        $self->{time}  = CORE::time();
        $self->{tid}   = Thread->self->tid if defined &Thread::tid;
        @{$self}{qw < pid uid euid gid egid >}
              = (     $$, $<, $>,  $(, $)    );

        # Collect stack info
        my @caller_stack;
        my $level = 1;
        while (my @c = do { package DB; caller($level++) }) {
            # Skip own package
            next if ! defined $Isa_Package{$c[0]} ? $Isa_Package{$c[0]} = do { local $@; local $SIG{__DIE__}; eval { $c[0]->isa(__PACKAGE__) } } : $Isa_Package{$c[0]};
            # Collect the caller stack
            push @caller_stack, [ @c[0 .. 7], @DB::args ];
            # Collect only one entry if verbosity is lower than 3
            last if $verbosity < 3;
        }
        $self->{caller_stack} = \@caller_stack;
    }

    return $self;
}


# Stringify caller backtrace. Stolen from Carp
sub _caller_backtrace {
    my ($self, $verbosity) = @_;
    my $message;

    my $tid_msg = '';
    $tid_msg = ' thread ' . $self->{tid} if $self->{tid};

    $verbosity = defined $self->{verbosity}
                  ? $self->{verbosity}
                  : $self->{defaults}->{verbosity}
        if not defined $verbosity;

    my $ignore_level = defined $self->{ignore_level}
                     ? $self->{ignore_level}
                     : defined $self->{defaults}->{ignore_level}
                       ? $self->{defaults}->{ignore_level}
                       : 0;

    my $ignore_package = defined $self->{ignore_package}
                     ? $self->{ignore_package}
                     : $self->{defaults}->{ignore_package};

    my $ignore_class = defined $self->{ignore_class}
                     ? $self->{ignore_class}
                     : $self->{defaults}->{ignore_class};

    # Skip some packages for first line
    my $level = 0;
    while (my %c = $self->_caller_info($level++)) {
        if (defined $ignore_package) {
            if (ref $ignore_package eq 'ARRAY') {
                if (@{ $ignore_package }) {
                    next if grep { ref $_ eq 'Regexp' ? $c{package} =~ $_ : $c{package} eq $_ } @{ $ignore_package };
                }
            }
            else {
                next if ref $ignore_package eq 'Regexp' ? $c{package} =~ $ignore_package : $c{package} eq $ignore_package;
            }
        }
        if (defined $ignore_class) {
            if (ref $ignore_class eq 'ARRAY') {
                if (@{ $ignore_class }) {
                    next if grep { do { local $@; local $SIG{__DIE__}; eval { $c{package}->isa($_) } } } @{ $ignore_class };
                }
            }
            else {
                next if do { local $@; local $SIG{__DIE__}; eval { $c{package}->isa($ignore_class) } };
            }
        }
        # Skip ignored levels
        if ($ignore_level > 0) {
            $ignore_level --;
            next;
        }
        if (not defined $message) {
            $message = sprintf " at %s line %s$tid_msg\n",
                       defined $c{file} && $c{file} ne '' ? $c{file} : 'unknown',
                       $c{line} || 0;
        }
        last;
    }
    # Reset the stack trace level only if needed
    if ($verbosity > 3) {
        $level = 0;
    }
    # Dump the stack
    while (my %c = $self->_caller_info($level++)) {
        $message .= "\t$c{wantarray}$c{sub_name} called in package $c{package} at $c{file} line $c{line}$tid_msg\n";
    }

    return $message || " at unknown line 0$tid_msg\n";
}


# Return info about caller. Stolen from Carp
sub _caller_info {
    my ($self, $i) = @_;
    my %call_info;
    my @call_info = ();

    @call_info = @{ $self->{caller_stack}->[$i] }
        if defined $self->{caller_stack} and defined $self->{caller_stack}->[$i];

    @call_info{
        qw< package file line subroutine has_args wantarray evaltext is_require >
    } = @call_info[0..7];

    unless (defined $call_info{package}) {
        return ();
    }

    my $sub_name = $self->_get_subname(\%call_info);
    if ($call_info{has_args}) {
        my @args = map {$self->_format_arg($_)} @call_info[8..$#call_info];
        my $max_arg_nums = defined $self->{max_arg_nums} ? $self->{max_arg_nums} : $self->{defaults}->{max_arg_nums};
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
    my ($self, $info) = @_;
    if (defined($info->{evaltext})) {
        my $eval = $info->{evaltext};
        if ($info->{is_require}) {
            return "require $eval";
        }
        else {
            $eval =~ s/([\\\'])/\\$1/g;
            return
                "eval '" .
                $self->_str_len_trim($eval, defined $self->{max_eval_len} ? $self->{max_eval_len} : $self->{defaults}->{max_eval_len}) .
                "'";
        }
    }
    return ($info->{subroutine} eq '(eval)') ? 'eval {...}' : $info->{subroutine};
}


# Transform an argument to a function into a string. Stolen from Carp
sub _format_arg {
    my ($self, $arg) = @_;

    return 'undef' if not defined $arg;

    if (do { local $@; local $SIG{__DIE__}; eval { $arg->isa(__PACKAGE__) } } or ref $arg) {
        return q{"} . overload::StrVal($arg) . q{"};
    }

    $arg =~ s/\\/\\\\/g;
    $arg =~ s/"/\\"/g;
    $arg =~ s/`/\\`/g;
    $arg = $self->_str_len_trim($arg, defined $self->{max_arg_len} ? $self->{max_arg_len} : $self->{defaults}->{max_arg_len});

    $arg = "\"$arg\"" unless $arg =~ /^-?[\d.]+\z/;

    no warnings 'utf8';
    if (not defined *utf8::is_utf{CODE} or utf8::is_utf8($arg)) {
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
    my ($self, $str, $max) = @_;
    $max = 0 unless defined $max;
    if ($max > 2 and $max < length($str)) {
        substr($str, $max - 3) = '...';
    }
    return $str;
}


# Modify default values for FIELDS
sub _modify_default_value {
    my ($self, $key, $value, $modifier) = @_;
    my $class = ref $self ? ref $self : $self;

    # Modify entry in FIELDS constant. Its elements are not constant.
    my $fields = $class->FIELDS;

    if (not exists $fields->{$key}->{default}) {
        Exception::Base->throw(
              message => "$class class does not implement default value for $key field",
              verbosity => 1
        );
    }

    if ($modifier eq '+') {
        my $old = $fields->{$key}->{default};
        if (ref $old eq 'ARRAY') {
            my %new = map { $_ => 1 } @{ $old }, ref $value eq 'ARRAY' ? @{ $value } : $value;
            $fields->{$key}->{default} = [ keys %new ];
        }
        elsif ($old =~ /^\d+$/) {
            $fields->{$key}->{default} += $value;
        }
        else {
            $fields->{$key}->{default} .= $value;
        }
    }
    elsif ($modifier eq '-') {
        my $old = $fields->{$key}->{default};
        if (ref $old eq 'ARRAY') {
            if (ref $value eq 'ARRAY') {
                my %new = map { $_ => 1 } @{ $old };
                foreach (@{ $value }) { delete $new{$_} };
                $fields->{$key}->{default} = [ keys %new ];
            }
            else {
                $fields->{$key}->{default} = [ grep { $_ ne $value } @{ $old } ];
            }
        }
        elsif ($old =~ /^\d+$/) {
            $fields->{$key}->{default} -= $value;
        }
        else {
            $fields->{$key}->{default} = $value;
        }
    }
    else {
        $fields->{$key}->{default} = $value;
    }

    if (exists $Class_Defaults{$class}) {
        $Class_Fields{$class}->{$key}->{default}
        = $Class_Defaults{$class}->{$key}
        = $fields->{$key}->{default};
    }
}


# Create accessors for this class
sub _make_accessors {
    my ($class) = @_;
    $class = ref $class if ref $class;

    no warnings 'uninitialized';
    my $fields = $class->FIELDS;
    foreach my $key (keys %{ $fields }) {
        if (not $class->can($key)) {
            if ($fields->{$key}->{is} eq 'rw') {
                *{Symbol::fetch_glob($class . '::' . $key)} = sub :lvalue {
                    @_ > 1 ? $_[0]->{$key} = $_[1]
                           : $_[0]->{$key};
                };
            }
            else {
                *{Symbol::fetch_glob($class . '::' . $key)} = sub {
                    $_[0]->{$key};
                };
            }
        }
    }
}


# Create caller_info() accessors for this class
sub _make_caller_info_accessors {
    my ($class) = @_;
    $class = ref $class if ref $class;

    foreach my $key (qw< package file line subroutine >) {
        if (not $class->can($key)) {
            *{Symbol::fetch_glob($class . '::' . $key)} = sub {
                my $self = shift;
                my $ignore_level = defined $self->{ignore_level}
                                 ? $self->{ignore_level}
                                 : defined $self->{defaults}->{ignore_level}
                                   ? $self->{defaults}->{ignore_level}
                                   : 0;
                my $ignore_package = defined $self->{ignore_package}
                                 ? $self->{ignore_package}
                                 : $self->{defaults}->{ignore_package};
                my $level = 0;
                while (my %c = $self->_caller_info($level++)) {
                    if (defined $ignore_package) {
                        if (ref $ignore_package eq 'ARRAY') {
                            next if grep { $_ eq $c{package} } @{ $ignore_package };
                        }
                        else {
                            next if $c{package} eq $ignore_package;
                        }
                    }
                    # Skip ignored levels
                    if ($ignore_level > 0) {
                        $ignore_level --;
                        next;
                    }
                    return $c{$key};
                }
            };
        }
    }
}


INIT: {
    __PACKAGE__->_make_accessors;
    __PACKAGE__->_make_caller_info_accessors;
}


1;


__END__

=for readme stop

=head1 IMPORTS

=over

=item use Exception::Base qw< catch try throw >;

Exports the B<catch>, B<try> and B<throw> functions to the caller namespace.

  use Exception::Base qw< catch try throw >;
  try eval { throw 'Exception::Base'; };
  if (catch my $e) { warn "$e"; }

=item use Exception::Base ':all';

Exports all available symbols to the caller namespace.

=item use Exception::Base 'I<field>' => I<value>;

Changes the default value for I<field>.  If the I<field> name has no
special prefix, its default value is replaced with a new I<value>.

  use Exception::Base verbosity => 4;

If the I<field> name starts with "B<+>" or "B<->" then the new I<value>
is based on previous value:

=over

=item *

If the original I<value> was a reference to array, the new I<value> can
be included or removed from original array.  Use array reference if you
need to add or remove more than one element.

  use Exception::Base "+ignore_packages" => [ __PACKAGE__, qr/^Moose::/ ];
  use Exception::Base "-ignore_class" => "My::Good::Class";

=item *

If the original I<value> was a number, it will be incremeted or
decremented by the new I<value>.

  use Exception::Base "+ignore_level" => 1;

=item *

If the original I<value> was a string, the new I<value> will be
included.

  use Exception::Base "+message" => ": The incuded message";

=back

=item use Exception::Base 'I<Exception>', ...;

Loads additional exception class module.  If the module is not available,
creates the exception class automatically at compile time.  The newly created
class will be based on L<Exception::Base> class.

  use Exception::Base qw< Exception::Custom Exception::SomethingWrong >;
  Exception::Custom->throw;

=item use Exception::Base 'I<Exception>' => { isa => I<BaseException>, version => I<version>, ... };

Loads additional exception class module.  If the module's version is lower
than given parameter or the module can't be loaded, creates the exception
class automatically at compile time.  The newly created class will be based
on given class and has the given $VERSION variable.

=over

=item isa

The newly created class will be based on given class.

=item version

The class will be created only if the module's version is lower than given
parameter and will have the version given in the argument.

=item message

=item verbosity

=item max_arg_len

=item max_arg_nums

=item max_eval_len

=item I<other field having default property>

The class will have the default property for the given field.

=back

  use Exception::Base
    'try', 'catch',
    'Exception::IO',
    'Exception::FileNotFound' => { isa => 'Exception::IO' },
    'Exception::My' => { version => 0.2 },
    'Exception::WithDefault' => { message => 'Default message' };
  try eval { Exception::FileNotFound->throw; };
  if (catch my $e) {
    if ($e->isa('Exception::IO')) { warn "can be also FileNotFound"; }
    if ($e->isa('Exception::My')) { print $e->VERSION; }
  }

=item no Exception::Base qw< catch try throw >;

=item no Exception::Base ':all';

=item no Exception::Base;

Unexports the B<catch> and B<try> functions from the caller namespace.

  use Exception::Base ':all', 'Exception::FileNotFound';
  try eval { Exception::FileNotFound->throw; };  # ok
  no Exception::Base;
  try eval { Exception::FileNotFound->throw; };  # syntax error

=back

=head1 CONSTANTS

=over

=item FIELDS

Declaration of class fields as reference to hash.

The fields are listed as I<name> => {I<properties>}, where I<properties> is a
list of field properties:

=over

=item is

Can be 'rw' for read-write fields or 'ro' for read-only fields.  The field is
read-only and does not have an accessor created if 'is' property is missed.

=item default

Optional property with the default value if the field value is not defined.

=back

The read-write fields can be set with B<new> constructor.  Read-only fields
are modified by L<Exception::Base> class itself and arguments for B<new>
constructor will be stored in B<properties> field.

The constant have to be defined in derivered class if it brings additional
fields.

  package Exception::My;
  our $VERSION = 0.01;
  use base 'Exception::Base';

  # Define new class fields
  use constant FIELDS => {
    %{Exception::Base->FIELDS},       # base's fields have to be first
    readonly  => { is=>'ro', default=>'value' },  # new ro field
    readwrite => { is=>'rw' },                    # new rw field
  };

  package main;
  use Exception::Base ':all';
  try eval {
    throw 'Exception::My' => readonly=>1, readwrite=>2;
  };
  if (catch my $e) {
    print $e->{readwrite};                # = 2
    print $e->{properties}->{readonly};   # = 1
    print $e->{defaults}->{readwrite};    # = "value"
  }

=back

=head1 FIELDS

Class fields are implemented as values of blessed hash.  The fields are also
available as accessors methods.

=over

=item message (rw, default: 'Unknown exception')

Contains the message of the exception.  It is the part of the string
representing the exception object.

  eval { Exception::Base->throw(message=>"Message", tag=>"TAG"); };
  print $@->{message} if $@;

=item properties (ro)

Contains the additional properies of the exception.  They can be later used
with "with" method.

  eval { Exception::Base->throw(message=>"Message", tag=>"TAG"); };
  print $@->{properties}->{tag} if $@;

=item verbosity (rw, default: 2)

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

The same as the standard output of die() function.  This is the default option.

=item 3

 Class: Message at %s line %d
         %c_ = %s::%s() called in package %s at %s line %d
 ...

The output contains full trace of error stack without first
B<ignore_level> lines and those packages which are listed in
B<ignore_package> and B<ignore_class> settings.

=item 3

The output contains full trace of error stack. In this case the
B<ignore_level>, B<ignore_package> and B<ignore_class> settings are
meaning only for first line of exception's message.  The 

=back

If the verbosity is undef, then the default verbosity for exception objects
is used.

If the verbosity set with constructor (B<new> or B<throw>) is lower than 3,
the full stack trace won't be collected.

If the verbosity is lower than 2, the full system data (time, pid, tid, uid,
euid, gid, egid) won't be collected.

This setting can be changed with import interface.

  use Exception::Base verbosity => 4;

It can be also changed for Perl interpreter instance, i.e. for debugging
purposes.

  sh$ perl -MException::Base=verbosity,4 script.pl

=item ignore_package (rw)

Contains the name (scalar or regexp) or names (as references array) of
packages which are ignored in error stack trace.  It is useful if some
package throws an exception but this module shouldn't be listed in stack
trace.

  package My::Package;
  use Exception::Base;
  sub my_function {
    do_something() or throw Exception::Base ignore_package=>__PACKAGE__;
    throw Exception::Base ignore_package => [ "My", qr/^My::Modules::/ ];
  }

This setting can be changed with import interface.

  use Exception::Base ignore_package => __PACKAGE__;

=item ignore_class (rw)

Contains the name (scalar) or names (as references array) of packages
which are base classes for ignored packages in error stack trace.  It
means that some packages will be ignored even the derived class was
called.

  package My::Package;
  use Exception::Base;
  Exception::Base->throw(ignore_class => "My::Base");

This setting can be changed with import interface.

  use Exception::Base ignore_class => "My::Base";

=item ignore_level (rw)

Contains the number of level on stack trace to ignore.  It is useful if some
package throws an exception but this module shouldn't be listed in stack
trace.  It can be used with or without I<ignore_package> field.

  # Convert warning into exception. The signal handler ignores itself.
  use Exception::Base 'Exception::Warning';
  $SIG{__WARN__} = sub {
    Exception::Warning->throw(message => $_[0], ignore_level => 1)
  };

=item eval_error (ro)

Contains the original eval error message if the exception was rethrown from
B<$@> variable.  This message will be displayed as a part of
L<Exception::Base> message.  The I<eval_error> has line number, file name and
line-feed (\n) removed from its message.

  try eval {
    eval { $a = $b = 0; $c = $a / $b };
    Exception::Base->throw;
  };
  catch my $e;
  print $e->eval_error;

=item time (ro)

Contains the timestamp of the thrown exception.  Collected if the verbosity
on throwing exception was greater than 1.

  eval { Exception::Base->throw(message=>"Message"); };
  print scalar localtime $@->{time};

=item pid (ro)

Contains the PID of the Perl process at time of thrown exception.  Collected
if the verbosity on throwing exception was greater than 1.

  eval { Exception::Base->throw(message=>"Message"); };
  kill 10, $@->{pid};

=item tid (ro)

Constains the tid of the thread or undef if threads are not used.  Collected
if the verbosity on throwing exception was greater than 1.

=item uid (ro)

=item euid (ro)

=item gid (ro)

=item egid (ro)

Contains the real and effective uid and gid of the Perl process at time of
thrown exception.  Collected if the verbosity on throwing exception was
greater than 1.

=item caller_stack (ro)

Contains the error stack as array of array with informations about caller
functions.  The first 8 elements of the array's row are the same as first 8
elements of the output of caller() function.  Further elements are optional
and are the arguments of called function.  Collected if the verbosity on
throwing exception was greater than 1.  Contains only the first element of
caller stack if the verbosity was lower than 3.

  eval { Exception::Base->throw(message=>"Message"); };
  ($package, $filename, $line, $subroutine, $hasargs, $wantarray,
  $evaltext, $is_require, @args) = $@->{caller_stack}->[0];

=item max_arg_len (rw, default: 64)

Contains the maximal length of argument for functions in backtrace output.
Zero means no limit for length.

  sub a { Exception::Base->throw(max_arg_len=>5) }
  a("123456789");

=item max_arg_nums (rw, default: 8)

Contains the maximal number of arguments for functions in backtrace output.
Zero means no limit for arguments.

  sub a { Exception::Base->throw(max_arg_nums=>1) }
  a(1,2,3);

=item max_eval_len (rw, default: 0)

Contains the maximal length of eval strings in backtrace output.  Zero means
no limit for length.

  eval "Exception->throw(max_eval_len=>10)";
  print "$@";

=item defaults (rw)

Meta-field contains the list of default values.

  my $e = Exception::Base->new;
  print defined $e->{verbosity}
    ? $e->{verbosity}
    : $e->{defaults}->{verbosity};

=back

=head1 CONSTRUCTORS

=over

=item new([%I<args>])

Creates the exception object, which can be thrown later.  The system data
fields like B<time>, B<pid>, B<uid>, B<gid>, B<euid>, B<egid> are not filled.

If the key of the argument is read-write field, this field will be filled.
Otherwise, the properties field will be used.

  $e = Exception::Base->new(
           message=>"Houston, we have a problem",
           tag => "BIG"
       );
  print $e->{message};
  print $e->{properties}->{tag};

The constructor reads the list of class fields from FIELDS constant function
and stores it in the internal cache for performance reason.  The defaults
values for the class are also stored in internal cache.

=item throw([%I<args>]])

Creates the exception object and immediately throws it with die() function.

  open FILE, $file
    or Exception::Base->throw(message=>"Can not open file: $file");

This method is also exported as a function.

  open FILE, $file
    or throw 'Exception::Base' => message=>"Can not open file: $file";

=back

=head1 METHODS

=over

=item throw([%I<args>])

Immediately throws exception object.  It can be used for rethrowing existing
exception object.  Additional arguments will override the fields in existing
exception object.

  $e = Exception::Base->new;
  # (...)
  $e->throw(message=>"thrown exception with overriden message");

  eval { Exception::Base->throw(message=>"Problem", fatal=>1) };
  $@->throw if $@->properties->{fatal};

=item throw($I<exception>, [%I<args>])

Immediately rethrows an existing exception object as an other exception
class.

  eval { open $f, "w", "/etc/passwd" or Exception::System->throw };
  # convert Exception::System into Exception::Base
  Exception::Base->throw($@);

=item stringify([$I<verbosity>[, $I<message>]])

Returns the string representation of exception object.  It is called
automatically if the exception object is used in scalar context.  The method
can be used explicity and then the verbosity level can be used.

  eval { Exception::Base->throw; };
  $@->{verbosity} = 1;
  print "$@";
  print $@->stringify(4) if $VERY_VERBOSE;

It also replaces any message stored in object with the I<message> argument if
it exists.  This feature can be used by derived class overwriting
B<stringify> method.

=item with(I<condition>)

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
  $e->with(message=>'$e->{properties}->{message} or $e->{message}');

The argument (for message or properties) can be simple string or code
reference or regexp.

  $e->with("message");
  $e->with(sub {/message/});
  $e->with(qr/message/);

=item try(I<eval>)

The B<try> method or function can be used with eval block as argument.  Then
the eval's error is pushed into error stack and can be used with B<catch>
later.

  Exception::Base->try(eval { Exception::Base->throw; });
  eval { die "another error messing with \$@ variable"; };
  Exception::Base->catch(my $e);

The B<try> returns the value of the argument in scalar context.  If the
argument is array reference, the B<try> returns the value of the argument in
array context.

  $v = Exception::Base->try( eval { 2 + 2; } ); # $v == 4
  @v = Exception::Base->try( [ eval { (1,2,3); }; ] ); # @v = (1,2,3)

The B<try> can be used as method or function.

  try 'Exception::Base' => eval {
    Exception::Base->throw(message=>"method"); 
  };
  Exception::Base::try eval {
    Exception::Base->throw(message=>"function");
  };
  Exception::Base->import('try');
  try eval {
    Exception::Base->throw(message=>"exported function");
  };

=item I<CLASS>->catch([$I<variable>])

The exception is popped from error stack written into the method argument.  If
the exception is not based on the I<CLASS>, the exception is thrown
immediately.

  try eval { Exception::Base->throw; };
  catch Exception::Base my $e;
  print $e->stringify(1);

If the error stack is empty, the B<catch> method returns undefined value.  It
can be used in loop to clean up all unhandled exceptions.

  try eval { -f 'file1' or Exception::FileNotFound->throw };
  try eval { -f 'file2' or Exception::FileNotFound->throw };
  try eval { -f 'file3' or Exception::FileNotFound->throw };
  while (catch my $e) {
      warn "$e" if not $e->isa('Exception::FileNotFound');
  }

If the B<$@> variable does not contain the exception object but string, new
exception object is created with message from B<$@> variable with removed
C<" at file line 123."> string and the last end of line (LF).

  try eval { die "Died\n"; };
  catch 'Exception::Base', my $e;
  print $e->stringify;

The method returns B<1>, if the exception object is caught, and returns B<0>
otherwise.

  try eval { throw 'Exception::Base'; };
  if (Exception::Base->catch(my $e)) {
    warn "Exception caught: " . ref $e;

If the method argument is missing, the method returns the exception object.

  try eval { Exception::Base->throw; };
  my $e = Exception::Base->catch;

The B<catch> can be used as method or function.  If it is used as function,
then the I<CLASS> is Exception::Base by default.

  try eval { throw 'Exception::Base' => message=>"method"; };
  Exception::Base->import('catch');
  catch my $e;  # the same as Exception::Base->catch(my $e);
  print $e->stringify;

=item I<CLASS>->catch([$I<variable>,] \@I<ExceptionClasses>)

The exception is popped from error stack or returns undefined value if error
stack is empty.  If the exception is not based on the I<CLASS> and is not
based on one of the class from argument, the exception is thrown immediately.

  try eval { throw Exception::IO; }
  catch 'Exception::Base', my $e, ['Exception::IO'];
  print "Only IO exception was caught: " . $e->stringify(1);

=item package

Returns the package name of the subroutine which thrown an exception.

=item file

Returns the file name of the subroutine which thrown an exception.

=item line

Returns the line number for file of the subroutine which thrown an exception.

=item subroutine

Returns the subroutine name which thrown an exception.

=back

=head1 PRIVATE METHODS

=over

=item _collect_system_data

Collect system data and fill the attributes of exception object.  This method
is called automatically if exception if thrown.  It can be used by derived
class.

  package Exception::Special;
  use base 'Exception::Base';
  use constant FIELDS => {
    %{Exception::Base->FIELDS},
    'special' => { is => 'ro' },
  };
  sub _collect_system_data {
    my $self = shift;
    $self->SUPER::_collect_system_data(@_);
    $self->{special} = get_special_value();
    return $self;
  }
  __PACKAGE__->_make_accessors;
  1;

Method returns the reference to the self object.

=item _make_accessors

Create accessors for each field.  This static method should be called in each
derived class which defines new fields.

  package Exception::My;
  # (...)
  __PACKAGE__->_make_accessors;

=back

=head1 SEE ALSO

There are more implementation of exception objects available on CPAN:

=over

=item L<Error>

Complete implementation of try/catch/finally/otherwise mechanism.  Uses
nested closures with a lot of syntactic sugar.  It is slightly faster than
L<Exception::Base> module.  It doesn't provide a simple way to create user
defined exceptions.  It doesn't collect system data and stack trace on error.

=item L<Exception::Class>

More perl-ish way to do OO exceptions.  It is too heavy and too slow.  It
requires non-core perl modules to work.  It missing try/catch mechanism.

=item L<Exception::Class::TryCatch>

Additional try/catch mechanism for L<Exception::Class>.  It is also slow as
L<Exception::Class>.

=item L<Class::Throwable>

Elegant OO exceptions without try/catch mechanism.  It might be missing some
features found in L<Exception::Base> and L<Exception::Class>.

=item L<Exceptions>

Not recommended.  Abadoned.  Modifies %SIG handlers.

=back

See also L<Exception::System> class as an example for implementation of
echanced exception class based on this L<Exception::Base> class.

=head1 PERFORMANCE

The L<Exception::Base> module was benchmarked with other implementations for
simple try/catch scenario.  The results (Perl 5.8.8
i486-linux-gnu-thread-multi) are following:

=over

=item pure eval/die with string

381868/s

=item pure eval/die with object

137700/s

=item L<Exception::Base> module with default options

5070/s

=item L<Exception::Base> module with verbosity = 1

18979/s

=item L<Error> module

17300/s

=item L<Exception::Class> module

1540/s

=item L<Exception::Class::TryCatch> module

1491/s

=item L<Class::Throwable> module

7383/s

=back

The L<Exception::Base> module is 80 times slower than pure eval/die.  This
module was written to be as fast as it is possible.  It does not use i.e.
accessor functions which are slower about 6 times than standard variables.
It is slower than pure die/eval because it is uses OO mechanism which are
slow in Perl.  It can be a litte faster if some features are disables, i.e.
the stack trace and higher verbosity.

You can find the benchmark script in this package distribution.

=head1 TESTS

The module was tested with L<Devel::Cover> and L<Devel::Dprof>.

=head1 BUGS

If you find the bug, please report it.

=for readme continue

=head1 AUTHOR

Piotr Roszatycki E<lt>dexter@debian.orgE<gt>

=head1 LICENSE

Copyright (C) 2007, 2008 by Piotr Roszatycki E<lt>dexter@debian.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
