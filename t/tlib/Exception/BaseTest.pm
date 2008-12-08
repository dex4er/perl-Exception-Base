package Exception::BaseTest;

use strict;
use warnings;

use utf8;

use base 'Test::Unit::TestCase';

use Exception::Base;

sub test___isa {
    my $self = shift;
    my $obj1 = Exception::Base->new;
    $self->assert_not_equals('', ref $obj1);
    $self->assert($obj1->isa("Exception::Base"), '$obj1->isa("Exception::Base")');
    my $obj2 = $obj1->new;
    $self->assert_not_equals('', ref $obj2);
    $self->assert($obj2->isa("Exception::Base"), '$obj2->isa("Exception::Base")');
}

sub test_new {
    my $self = shift;

    my $obj1 = Exception::Base->new;
    $self->assert_null($obj1->{message});

    my $obj2 = Exception::Base->new(message=>'Message');
    $self->assert_equals('Message', $obj2->{message});

    my $obj3 = Exception::Base->new(unknown=>'Unknown');
    $self->assert(! exists $obj3->{unknown}, '! exists $obj3->{unknown}');

    my $obj4 = Exception::Base->new(propagated_stack=>'Ignored');
    $self->assert_not_equals('Ignored', $obj4->{propagated_stack});
}

sub test_attribute {
    my $self = shift;
    my $obj = Exception::Base->new(message=>'Message');
    $self->assert_equals('Message', $obj->{message});
    $self->assert_equals($$, $obj->{pid});
}

sub test_accessor {
    my $self = shift;
    my $obj = Exception::Base->new(message=>'Message');
    $self->assert_equals('Message', $obj->message);
    $self->assert_equals('New Message', $obj->message('New Message'));
    $self->assert_equals('New Message', $obj->message);
    $self->assert_equals('Lvalue accessor Message', $obj->message = 'Lvalue accessor Message');
    $self->assert_equals('Lvalue accessor Message', $obj->message);
    $self->assert_equals($$, $obj->pid);
    eval { $obj->pid = 0 };
    $self->assert_matches(qr/modify non-lvalue subroutine call/, "$@");
}

sub test_accessor_message {
    my $self = shift;
    my $obj = Exception::Base->new(message=>'Message');
    $self->assert_equals('Message', $obj->message);
    $self->assert_equals('New Message', $obj->message('New Message'));
    $self->assert_equals('New Message', $obj->message);
    $self->assert_equals('Lvalue accessor Message', $obj->message = 'Lvalue accessor Message');
    $self->assert_equals('Lvalue accessor Message', $obj->message);
}

sub test_caller_stack_accessors {
    my $self = shift;
    my $obj = Exception::Base->new;
    $obj->{caller_stack} = [
        ['Package1', 'Package1.pm', 1, 'Package1::func1', 0, undef, undef, undef ],
        ['Package2', 'Package2.pm', 2, 'Package2::func2', 6, 1, undef, undef, 1, 2, 3, 4, 5, 6 ],
        ['Package3', 'Package3.pm', 3, 'Package3::func3', 2, 1, undef, undef, "123456789", "123456789" ],
        ['Package4', 'Package4.pm', 4, '(eval)', 0, undef, "123456789", undef ],
    ];

    $self->assert_equals('Package1', $obj->package);
    $self->assert_equals('Package1.pm', $obj->file);
    $self->assert_equals('1', $obj->line);
    $self->assert_equals('Package1::func1', $obj->subroutine);

    $obj->{ignore_level} = 1;

    $self->assert_equals('Package2', $obj->package);
    $self->assert_equals('Package2.pm', $obj->file);
    $self->assert_equals('2', $obj->line);
    $self->assert_equals('Package2::func2', $obj->subroutine);

    $obj->{ignore_package} = 'Package1';

    $self->assert_equals('Package3', $obj->package);
    $self->assert_equals('Package3.pm', $obj->file);
    $self->assert_equals('3', $obj->line);
    $self->assert_equals('Package3::func3', $obj->subroutine);
}

sub test_throw {
    my $self = shift;

    local $SIG{__DIE__};

    # Simple throw
    eval {
        Exception::Base->throw(message=>'Throw');
    };
    my $obj1 = $@;
    $self->assert_not_equals('', ref $obj1);
    $self->assert($obj1->isa("Exception::Base"), '$obj1->isa("Exception::Base")');
    $self->assert_equals('Throw', $obj1->{message});
    $self->assert_equals('Exception::BaseTest', $obj1->{caller_stack}->[0]->[0]);

    # Rethrow
    eval {
        $obj1->throw;
    };
    my $obj2 = $@;
    $self->assert_not_equals('', ref $obj2);
    $self->assert($obj2->isa("Exception::Base"), '$obj2->isa("Exception::Base")');
    $self->assert_equals('Throw', $obj2->{message});
    $self->assert_equals('Exception::BaseTest', $obj1->{caller_stack}->[0]->[0]);

    # Rethrow with overriden message
    eval {
        $obj1->throw(message=>'New throw', pid=>'ignored');
    };
    my $obj3 = $@;
    $self->assert_not_equals('', ref $obj3);
    $self->assert($obj3->isa("Exception::Base"), '$obj3->isa("Exception::Base")');
    $self->assert_equals('New throw', $obj3->{message});
    $self->assert_equals('Exception::BaseTest', $obj1->{caller_stack}->[0]->[0]);
    $self->assert_not_equals('ignored', $obj3->{pid});

    # Rethrow with overriden class
    {
        package Exception::Base::throw::Test1;
        our @ISA = ('Exception::Base');
    }

    eval {
        Exception::Base::throw::Test1->throw($obj1);
    };
    my $obj4 = $@;
    $self->assert_not_equals('', ref $obj4);
    $self->assert($obj4->isa("Exception::Base"), '$obj4->isa("Exception::Base")');
    $self->assert_equals('New throw', $obj4->{message});
    $self->assert_equals('Exception::BaseTest', $obj1->{caller_stack}->[0]->[0]);

    # Throw and ignore levels (does not modify caller stack)
    eval {
        Exception::Base->throw(message=>'Throw', ignore_level => 2);
    };
    my $obj7 = $@;
    $self->assert_not_equals('', ref $obj7);
    $self->assert($obj7->isa("Exception::Base"), '$obj7->isa("Exception::Base")');
    $self->assert_equals('Throw', $obj7->{message});
    $self->assert_equals('Exception::BaseTest', $obj1->{caller_stack}->[0]->[0]);

    # Message only
    eval {
        Exception::Base->throw('Throw');
    };
    my $obj8 = $@;
    $self->assert_not_equals('', ref $obj8);
    $self->assert($obj8->isa("Exception::Base"), '$obj8->isa("Exception::Base")');
    $self->assert_equals('Throw', $obj8->{message});
    $self->assert_equals('Exception::BaseTest', $obj1->{caller_stack}->[0]->[0]);

    # Message and hash only
    eval {
        Exception::Base->throw('Throw', message=>'Hash');
    };
    my $obj9 = $@;
    $self->assert_not_equals('', ref $obj9);
    $self->assert($obj9->isa("Exception::Base"), '$obj9->isa("Exception::Base")');
    $self->assert_equals('Hash', $obj9->{message});
    $self->assert_equals('Exception::BaseTest', $obj1->{caller_stack}->[0]->[0]);

    eval q{
        package Exception::BaseTest::throw::Package1;
        use base 'Exception::Base';
        use constant ATTRS => {
            %{ Exception::Base->ATTRS },
            default_attribute => { default => 'myattr' },
            myattr => { is => 'rw' },
        };
    };
    $self->assert_equals('', $@);

    # One argument only
    eval {
        Exception::BaseTest::throw::Package1->throw('Throw');
    };
    my $obj10 = $@;
    $self->assert_not_equals('', ref $obj10);
    $self->assert($obj10->isa("Exception::BaseTest::throw::Package1"), '$obj10->isa("Exception::BaseTest::throw::Package1")');
    $self->assert($obj10->isa("Exception::Base"), '$obj10->isa("Exception::Base")');
    $self->assert_equals('Throw', $obj10->{myattr});
    $self->assert_null($obj10->{message});
    $self->assert_equals('Exception::BaseTest', $obj1->{caller_stack}->[0]->[0]);
}

sub test_to_string {
    my $self = shift;

    my $obj = Exception::Base->new;

    $self->assert_not_equals('', ref $obj);
    $self->assert($obj->isa("Exception::Base"), '$obj->isa("Exception::Base")');

    $obj->{verbosity} = 0;
    $self->assert_equals('', $obj->to_string);
    $obj->{verbosity} = 1;
    $self->assert_equals("Unknown exception\n", $obj->to_string);
    $obj->{verbosity} = 2;
    $self->assert_matches(qr/Unknown exception at .* line \d+.\n/s, $obj->to_string);

    $obj->{message} = 'Stringify';
    $obj->{value} = 123;
    $obj->{verbosity} = 0;
    $self->assert_equals('', $obj->to_string);
    $obj->{verbosity} = 1;
    $self->assert_equals("Stringify\n", $obj->to_string);
    $obj->{verbosity} = 2;
    $self->assert_matches(qr/Stringify at .* line \d+.\n/s, $obj->to_string);
    $obj->{verbosity} = 3;
    $self->assert_matches(qr/Exception::Base: Stringify at .* line \d+\n/s, $obj->to_string);

    $obj->{message} = "Ends with EOL\n";
    $obj->{value} = 123;
    $obj->{verbosity} = 0;
    $self->assert_equals('', $obj->to_string);
    $obj->{verbosity} = 1;
    $self->assert_equals("Ends with EOL\n", $obj->to_string);
    $obj->{verbosity} = 2;
    $self->assert_equals("Ends with EOL\n", $obj->to_string);
    $obj->{verbosity} = 3;
    $self->assert_matches(qr/Exception::Base: Ends with EOL\n at .* line \d+\n/s, $obj->to_string);

    $obj->{message} = "Stringify";
    $obj->{verbosity} = 2;
    $obj->{ignore_packages} = [ ];
    $obj->{ignore_class} = [ ];
    $obj->{ignore_level} = 0;
    $obj->{max_arg_len} = 64;
    $obj->{max_arg_nums} = 8;
    $obj->{max_eval_len} = 0;

    $obj->{caller_stack} = [ [ 'main', '-e', 1, 'Exception::Base::throw', 1, undef, undef, undef, 'Exception::Base' ] ];
    $obj->{file} = '-e';
    $obj->{line} = 1;

    $self->assert_equals("Stringify at -e line 1.\n", $obj->to_string);

    $obj->{caller_stack} = [
        ['Package1', 'Package1.pm', 1, 'Package1::func1', 0, undef, undef, undef ],
        ['Package1', 'Package1.pm', 1, 'Package1::func1', 0, undef, undef, undef ],
        ['Package2', 'Package2.pm', 2, 'Package2::func2', 1, 1, undef, undef, 1, [], {}, sub {1; }, $self, $obj ],
        ['Package3', 'Package3.pm', 3, '(eval)', 0, undef, 1, undef ],
        ['Package4', 'Package4.pm', 4, 'Package4::func4', 0, undef, 'Require', 1 ],
        ['Package5', 'Package5.pm', 5, 'Package5::func5', 1, undef, undef, undef, "\x{00}", "'\"\\\`\x{0d}\x{c3}", "\x{09}\x{263a}", undef, 123, -123.56, 1, 2, 3 ],
        ['Package6', '-e', 6, 'Package6::func6', 0, undef, undef, undef ],
        ['Package7', undef, undef, 'Package7::func7', 0, undef, undef, undef ],
    ];
    $obj->{propagated_stack} = [
        ['Exception::BaseTest::Propagate1', 'Propagate1.pm', 11],
        ['Exception::BaseTest::Propagate2', 'Propagate2.pm', 22],
    ];

    $self->assert_equals("Stringify at Package1.pm line 1.\n", $obj->to_string(2));

    my $s1 = << 'END';
Exception::Base: Stringify at Package1.pm line 1
\t$_ = Package1::func1 called in package Package1 at Package1.pm line 1
\t$_ = Package1::func1 called in package Package1 at Package1.pm line 1
\t@_ = Package2::func2(1, "ARRAY(0x1234567)", "HASH(0x1234567)", "CODE(0x1234567)", "Exception::BaseTest=HASH(0x1234567)", "Exception::Base=HASH(0x1234567)") called in package Package2 at Package2.pm line 2
\t$_ = eval '1' called in package Package3 at Package3.pm line 3
\t$_ = require Require called in package Package4 at Package4.pm line 4
\t$_ = Package5::func5("\x{00}", "'\"\\\`\x{0d}\x{c3}", "\x{09}\x{263a}", undef, 123, -123.56, 1, ...) called in package Package5 at Package5.pm line 5
\t$_ = Package6::func6 called in package Package6 at -e line 6
\t$_ = Package7::func7 called in package Package7 at unknown line 0
\t...propagated in package Exception::BaseTest::Propagate1 at Propagate1.pm line 11.
\t...propagated in package Exception::BaseTest::Propagate2 at Propagate2.pm line 22.
END

    $s1 =~ s/\\t/\t/g;

    $obj->{verbosity} = 4;
    my $s2 = $obj->to_string;
    $s2 =~ s/(ARRAY|HASH|CODE)\(0x\w+\)/$1(0x1234567)/g;
    $self->assert_equals($s1, $s2);

    $obj->{verbosity} = 2;
    $self->assert_equals("Stringify at Package1.pm line 1.\n", $obj->to_string);

    $obj->{caller_stack} = [
        ['Exception::BaseTest::Package1', 'Package1.pm', 1, 'Exception::BaseTest::Package1::func1', 0, undef, undef, undef ],
        ['Exception::BaseTest::Package1', 'Package1.pm', 1, 'Exception::BaseTest::Package1::func1', 6, 1, undef, undef, 1, 2, 3, 4, 5, 6 ],
        ['Exception::BaseTest::Package2', 'Package2.pm', 2, 'Exception::BaseTest::Package2::func2', 2, 1, undef, undef, "123456789", "123456789" ],
        ['Exception::BaseTest::Package3', 'Package3.pm', 3, '(eval)', 0, undef, "123456789", undef ],
    ];
    $obj->{max_arg_nums} = 2;
    $obj->{max_arg_len} = 5;
    $obj->{max_eval_len} = 5;

    my $s4 = << 'END';
Exception::Base: Stringify at Package1.pm line 1
\t$_ = Exception::BaseTest::Package1::func1 called in package Exception::BaseTest::Package1 at Package1.pm line 1
\t@_ = Exception::BaseTest::Package1::func1(1, ...) called in package Exception::BaseTest::Package1 at Package1.pm line 1
\t@_ = Exception::BaseTest::Package2::func2(12..., 12...) called in package Exception::BaseTest::Package2 at Package2.pm line 2
\t$_ = eval '12...' called in package Exception::BaseTest::Package3 at Package3.pm line 3
\t...propagated in package Exception::BaseTest::Propagate1 at Propagate1.pm line 11.
\t...propagated in package Exception::BaseTest::Propagate2 at Propagate2.pm line 22.
END
    $s4 =~ s/\\t/\t/g;

    $obj->{verbosity} = 4;
    my $s5 = $obj->to_string;
    $self->assert_equals($s4, $s5);

    $obj->{ignore_level} = 1;

    my $s6 = << 'END';
Exception::Base: Stringify at Package1.pm line 1
\t@_ = Exception::BaseTest::Package2::func2(12..., 12...) called in package Exception::BaseTest::Package2 at Package2.pm line 2
\t$_ = eval '12...' called in package Exception::BaseTest::Package3 at Package3.pm line 3
\t...propagated in package Exception::BaseTest::Propagate1 at Propagate1.pm line 11.
\t...propagated in package Exception::BaseTest::Propagate2 at Propagate2.pm line 22.
END
    $s6 =~ s/\\t/\t/g;

    $obj->{verbosity} = 3;
    my $s7 = $obj->to_string;
    $self->assert_equals($s6, $s7);

    $obj->{verbosity} = 2;
    $self->assert_equals("Stringify at Package1.pm line 1.\n", $obj->to_string);

    $obj->{ignore_package} = 'Exception::BaseTest::Package1';

    my $s8 = << 'END';
Exception::Base: Stringify at Package3.pm line 3
\t...propagated in package Exception::BaseTest::Propagate1 at Propagate1.pm line 11.
\t...propagated in package Exception::BaseTest::Propagate2 at Propagate2.pm line 22.
END

    $s8 =~ s/\\t/\t/g;

    $obj->{verbosity} = 3;
    my $s9 = $obj->to_string;
    $self->assert_equals($s8, $s9);

    { package Exception::BaseTest::Package1; }
    { package Exception::BaseTest::Package2; }
    { package Exception::BaseTest::Package3; }
    { package Exception::BaseTest::Propagate1; }
    { package Exception::BaseTest::Propagate2; }

    my $s10 = << 'END';
Exception::Base: Stringify at Package3.pm line 3
\t$_ = Exception::BaseTest::Package1::func1 called in package Exception::BaseTest::Package1 at Package1.pm line 1
\t@_ = Exception::BaseTest::Package1::func1(1, ...) called in package Exception::BaseTest::Package1 at Package1.pm line 1
\t@_ = Exception::BaseTest::Package2::func2(12..., 12...) called in package Exception::BaseTest::Package2 at Package2.pm line 2
\t$_ = eval '12...' called in package Exception::BaseTest::Package3 at Package3.pm line 3
\t...propagated in package Exception::BaseTest::Propagate1 at Propagate1.pm line 11.
\t...propagated in package Exception::BaseTest::Propagate2 at Propagate2.pm line 22.
END

    $s10 =~ s/\\t/\t/g;

    $obj->{verbosity} = 4;
    my $s11 = $obj->to_string;
    $self->assert_equals($s10, $s11);

    $obj->{verbosity} = 2;
    $self->assert_equals("Stringify at Package3.pm line 3.\n", $obj->to_string);

    $obj->{ignore_level} = 0;

    my $s12 = << 'END';
Exception::Base: Stringify at Package2.pm line 2
\t$_ = eval '12...' called in package Exception::BaseTest::Package3 at Package3.pm line 3
\t...propagated in package Exception::BaseTest::Propagate1 at Propagate1.pm line 11.
\t...propagated in package Exception::BaseTest::Propagate2 at Propagate2.pm line 22.
END

    $s12 =~ s/\\t/\t/g;

    $obj->{verbosity} = 3;
    my $s13 = $obj->to_string;
    $self->assert_equals($s12, $s13);

    $obj->{verbosity} = 2;
    $self->assert_equals("Stringify at Package2.pm line 2.\n", $obj->to_string);

    $obj->{ignore_package} = [ 'Exception::BaseTest::Package1', 'Exception::BaseTest::Package2', 'Exception::BaseTest::Propagate1' ];

    my $s14 = << 'END';
Exception::Base: Stringify at Package3.pm line 3
\t...propagated in package Exception::BaseTest::Propagate2 at Propagate2.pm line 22.
END

    $s14 =~ s/\\t/\t/g;

    $obj->{verbosity} = 3;
    my $s15 = $obj->to_string;
    $self->assert_equals($s14, $s15);

    $obj->{verbosity} = 2;
    $self->assert_equals("Stringify at Package3.pm line 3.\n", $obj->to_string);

    $obj->{ignore_package} = qr/^Exception::BaseTest::(Package|Propagate)/;

    my $s16 = << 'END';
Exception::Base: Stringify at Package1.pm line 1
END

    $s16 =~ s/\\t/\t/g;

    $obj->{verbosity} = 3;
    my $s17 = $obj->to_string;
    $self->assert_equals($s16, $s17);

    $obj->{verbosity} = 2;
    $self->assert_equals("Stringify at Package1.pm line 1.\n", $obj->to_string);

    $obj->{ignore_package} = [ qr/^Exception::BaseTest::Package1/, qr/^Exception::BaseTest::Package2/, qr/^Exception::BaseTest::Propagate2/ ];

    my $s18 = << 'END';
Exception::Base: Stringify at Package3.pm line 3
\t...propagated in package Exception::BaseTest::Propagate1 at Propagate1.pm line 11.
END

    $s18 =~ s/\\t/\t/g;

    $obj->{verbosity} = 3;
    my $s19 = $obj->to_string;
    $self->assert_equals($s18, $s19);

    $obj->{verbosity} = 2;
    $self->assert_equals("Stringify at Package3.pm line 3.\n", $obj->to_string);

    $obj->{ignore_package} = [ ];
    $obj->{ignore_class} = 'Exception::BaseTest::Package1';

    my $s20 = << 'END';
Exception::Base: Stringify at Package2.pm line 2
\t$_ = eval '12...' called in package Exception::BaseTest::Package3 at Package3.pm line 3
\t...propagated in package Exception::BaseTest::Propagate1 at Propagate1.pm line 11.
\t...propagated in package Exception::BaseTest::Propagate2 at Propagate2.pm line 22.
END

    $s20 =~ s/\\t/\t/g;

    $obj->{verbosity} = 3;
    my $s21 = $obj->to_string;
    $self->assert_equals($s20, $s21);

    $obj->{verbosity} = 2;
    $self->assert_equals("Stringify at Package2.pm line 2.\n", $obj->to_string);

    $obj->{ignore_class} = [ 'Exception::BaseTest::Package1', 'Exception::BaseTest::Package2', 'Exception::BaseTest::Propagate1' ];

    my $s22 = << 'END';
Exception::Base: Stringify at Package3.pm line 3
\t...propagated in package Exception::BaseTest::Propagate2 at Propagate2.pm line 22.
END

    $s22 =~ s/\\t/\t/g;

    $obj->{verbosity} = 3;
    my $s23 = $obj->to_string;
    $self->assert_equals($s22, $s23);

    $obj->{verbosity} = 4;
    my $s24 = $obj->to_string;
    $self->assert_equals($s10, $s24);

    $obj->{verbosity} = 2;
    $self->assert_equals("Stringify at Package3.pm line 3.\n", $obj->to_string);

    $obj->{caller_stack} = [ ];
    $obj->{propagated_stack} = [ ];

    my $s25 = << 'END';
Exception::Base: Stringify at unknown line 0
END

    $s25 =~ s/\\t/\t/g;

    $obj->{verbosity} = 3;
    my $s26 = $obj->to_string;
    $self->assert_equals($s25, $s26);

    $obj->{verbosity} = 2;
    $self->assert_equals("Stringify at unknown line 0.\n", $obj->to_string);

    $obj->{defaults}->{verbosity} = 1;
    $obj->{verbosity} = undef;
    $self->assert_equals("Stringify\n", $obj->to_string);
    $self->assert_not_null(Exception::Base->ATTRS->{verbosity}->{default});
    $self->assert_equals(2, $obj->{defaults}->{verbosity} = Exception::Base->ATTRS->{verbosity}->{default});
    $obj->{verbosity} = 1;

    $obj->{defaults}->{string_attributes} = ['verbosity', 'message', 'value'];
    $self->assert_equals("1: Stringify: 123\n", $obj->to_string);

    $obj->{value} = '';
    $self->assert_equals("1: Stringify\n", $obj->to_string);

    $obj->{value} = undef;
    $self->assert_equals("1: Stringify\n", $obj->to_string);

    $self->assert_not_null(Exception::Base->ATTRS->{string_attributes}->{default});
    $self->assert_deep_equals(['message'], $obj->{defaults}->{string_attributes} = Exception::Base->ATTRS->{string_attributes}->{default});

    $self->assert_equals("Stringify\n", $obj->to_string);
}

sub test_to_number {
    my $self = shift;

    my $obj = Exception::Base->new;

    $self->assert_not_equals('', ref $obj);
    $self->assert($obj->isa("Exception::Base"), '$obj->isa("Exception::Base")');

    $self->assert_num_equals(0, $obj->to_number);
    $self->assert_num_equals(0, 0+ $obj);

    $obj->{defaults}->{value} = 123;
    $obj->{value} = undef;

    $self->assert_num_equals(123, $obj->to_number);
    $self->assert_num_equals(123, 0+ $obj);

    $obj->{value} = 456;

    $self->assert_num_equals(456, $obj->to_number);
    $self->assert_num_equals(456, 0+ $obj);

    $obj->{defaults}->{value} = undef;
    $obj->{value} = undef;

    $self->assert_num_equals(0, $obj->to_number);
    $self->assert_num_equals(0, 0+ $obj);

    $self->assert_num_equals(0, $obj->{defaults}->{value} = Exception::Base->ATTRS->{value}->{default});
}

sub test_overload {
    my $self = shift;

    local $SIG{__DIE__};

    my $obj = Exception::Base->new(message=>'String', value=>123);
    $self->assert_not_equals('', ref $obj);
    $self->assert($obj->isa("Exception::Base"), '$obj->isa("Exception::Base")');

    # boolify
    $self->assert($obj && 1, '$obj && 1');

    # numerify
    $self->assert_num_equals(123, $obj);

    # stringify without $SIG{__DIE__}
    $self->assert_matches(qr/String at /, $obj);

    # smart matching for Perl 5.10
    if ($] >= 5.010) {
        eval q{
            $self->assert_num_equals(1, $obj ~~ 'String');
            $self->assert_num_equals(1, $obj ~~ 123);
            $self->assert_num_equals(1, $obj ~~ ['Exception::Base']);
        };
        die "$@" if $@;
    }
}

sub test_matches {
    my $self = shift;

    my $obj1 = Exception::Base->new;
    $self->assert_num_equals(1, $obj1->matches);
    $self->assert_num_equals(1, $obj1->matches(undef));
    $self->assert_num_equals(0, $obj1->matches(sub {/Unknown/}));
    $self->assert_num_equals(0, $obj1->matches(qr/Unknown/));
    $self->assert_num_equals(0, $obj1->matches(sub {/False/}));
    $self->assert_num_equals(0, $obj1->matches(qr/False/));
    $self->assert_num_equals(1, $obj1->matches({tag=>undef}));
    $self->assert_num_equals(0, $obj1->matches({tag=>'false'}));
    $self->assert_num_equals(1, $obj1->matches({tag=>['False', qr//, sub {}, undef]}));
    $self->assert_num_equals(0, $obj1->matches({tag=>['False', qr//, sub {}]}));
    $self->assert_num_equals(0, $obj1->matches({tag=>[]}));
    $self->assert_num_equals(1, $obj1->matches({tag=>[undef]}));
    $self->assert_num_equals(1, $obj1->matches({message=>undef}));
    $self->assert_num_equals(0, $obj1->matches({message=>'false'}));
    $self->assert_num_equals(0, $obj1->matches({message=>sub{/false/}}));
    $self->assert_num_equals(0, $obj1->matches({message=>qr/false/}));
    $self->assert_num_equals(0, $obj1->matches({message=>[]}));
    $self->assert_num_equals(1, $obj1->matches({message=>[undef]}));
    $self->assert_num_equals(1, $obj1->matches({message=>['False', qr//, sub {}, undef]}));
    $self->assert_num_equals(0, $obj1->matches({message=>['False', qr//, sub {}]}));
    $self->assert_num_equals(0, $obj1->matches({-isa=>'False'}));
    $self->assert_num_equals(1, $obj1->matches({-isa=>'Exception::Base'}));
    $self->assert_num_equals(0, $obj1->matches({-isa=>['False', 'False', 'False']}));
    $self->assert_num_equals(1, $obj1->matches({-isa=>['False', 'Exception::Base', 'False']}));
    $self->assert_num_equals(0, $obj1->matches({-has=>'False'}));
    $self->assert_num_equals(1, $obj1->matches({-has=>'message'}));
    $self->assert_num_equals(0, $obj1->matches({-has=>['False', 'False', 'False']}));
    $self->assert_num_equals(1, $obj1->matches({-has=>['False', 'message', 'False']}));
    $self->assert_num_equals(1, $obj1->matches({-default=>undef}));
    $self->assert_num_equals(0, $obj1->matches({-default=>'false'}));
    $self->assert_num_equals(0, $obj1->matches('False'));
    $self->assert_num_equals(0, $obj1->matches('Exception::Base'));
    $self->assert_num_equals(1, $obj1->matches(0));
    $self->assert_num_equals(0, $obj1->matches(1));
    $self->assert_num_equals(0, $obj1->matches(123));
    $self->assert_num_equals(0, $obj1->matches(['False', 'False', 'False']));
    $self->assert_num_equals(1, $obj1->matches(['False', 'Exception::Base', 'False']));
    $self->assert_num_equals(0, $obj1->matches(\1));

    my $obj2 = Exception::Base->new(message=>'Message', value=>123);
    $self->assert_num_equals(0, $obj2->matches(undef));
    $self->assert_num_equals(1, $obj2->matches(sub {/Message/}));
    $self->assert_num_equals(0, $obj2->matches(sub {/False/}));
    $self->assert_num_equals(1, $obj2->matches(qr/Message/));
    $self->assert_num_equals(0, $obj2->matches(qr/False/));
    $self->assert_num_equals(1, $obj2->matches({value=>123}));
    $self->assert_num_equals(0, $obj2->matches({value=>'false'}));
    $self->assert_num_equals(1, $obj2->matches({value=>sub {/123/}}));
    $self->assert_num_equals(1, $obj2->matches({value=>qr/123/}));
    $self->assert_num_equals(0, $obj2->matches({value=>sub {/false/}}));
    $self->assert_num_equals(0, $obj2->matches({value=>qr/false/}));
    $self->assert_num_equals(0, $obj2->matches({value=>undef}));
    $self->assert_num_equals(0, $obj2->matches({value=>[]}));
    $self->assert_num_equals(0, $obj2->matches({value=>[undef]}));
    $self->assert_num_equals(0, $obj2->matches({value=>['False', qr/False/, sub {/False/}, undef]}));
    $self->assert_num_equals(1, $obj2->matches({value=>['123', qr/False/, sub {/False/}, undef]}));
    $self->assert_num_equals(1, $obj2->matches({value=>['False', qr/123/, sub {/False/}, undef]}));
    $self->assert_num_equals(1, $obj2->matches({value=>['False', qr/False/, sub {/123/}, undef]}));
    $self->assert_num_equals(0, $obj2->matches({false=>'false'}));
    $self->assert_num_equals(1, $obj2->matches({false=>undef}));
    $self->assert_num_equals(1, $obj2->matches({message=>'Message', value=>123}));
    $self->assert_num_equals(1, $obj2->matches({message=>sub {/Message/}, value=>sub {/123/}}));
    $self->assert_num_equals(1, $obj2->matches({message=>qr/Message/, value=>qr/123/}));
    $self->assert_num_equals(0, $obj2->matches({message=>undef}));
    $self->assert_num_equals(1, $obj2->matches({message=>'Message'}));
    $self->assert_num_equals(0, $obj2->matches({message=>'false'}));
    $self->assert_num_equals(1, $obj2->matches({message=>sub{/Message/}}));
    $self->assert_num_equals(1, $obj2->matches({message=>qr/Message/}));
    $self->assert_num_equals(0, $obj2->matches({message=>sub{/false/}}));
    $self->assert_num_equals(0, $obj2->matches({message=>qr/false/}));
    $self->assert_num_equals(0, $obj2->matches({message=>[]}));
    $self->assert_num_equals(0, $obj2->matches({message=>[undef]}));
    $self->assert_num_equals(0, $obj2->matches({message=>['False', qr/False/, sub {/False/}, undef]}));
    $self->assert_num_equals(1, $obj2->matches({message=>['Message', qr/False/, sub {/False/}, undef]}));
    $self->assert_num_equals(1, $obj2->matches({message=>['False', qr/Message/, sub {/False/}, undef]}));
    $self->assert_num_equals(1, $obj2->matches({message=>['False', qr/False/, sub {/Message/}, undef]}));
    $self->assert_num_equals(0, $obj2->matches({-default=>undef}));
    $self->assert_num_equals(1, $obj2->matches({-default=>'Message'}));
    $self->assert_num_equals(0, $obj2->matches('False'));
    $self->assert_num_equals(0, $obj2->matches('Exception::Base'));
    $self->assert_num_equals(1, $obj2->matches('Message'));
    $self->assert_num_equals(0, $obj2->matches(0));
    $self->assert_num_equals(0, $obj2->matches(1));
    $self->assert_num_equals(1, $obj2->matches(123));
    $self->assert_num_equals(0, $obj2->matches(['False', 'False', 'False']));
    $self->assert_num_equals(1, $obj2->matches(['False', 'Exception::Base', 'False']));
    $self->assert_num_equals(0, $obj2->matches(\1));

    my $obj3 = Exception::Base->new(message=>undef);
    $self->assert_num_equals(1, $obj3->matches(undef));
    $self->assert_num_equals(1, $obj3->matches({message=>undef}));
    $self->assert_num_equals(0, $obj3->matches('false'));
    $self->assert_num_equals(0, $obj3->matches({message=>'false'}));
    $self->assert_num_equals(0, $obj3->matches({message=>sub {/false/}}));
    $self->assert_num_equals(0, $obj3->matches({message=>qr/false/}));
    $self->assert_num_equals(0, $obj3->matches({message=>[]}));
    $self->assert_num_equals(1, $obj3->matches({message=>[undef]}));
    $self->assert_num_equals(1, $obj3->matches({message=>['False', qr/False/, sub {/False/}, undef]}));
    $self->assert_num_equals(1, $obj3->matches({message=>['Message', qr/False/, sub {/False/}, undef]}));
    $self->assert_num_equals(1, $obj3->matches({message=>['False', qr/Message/, sub {/False/}, undef]}));
    $self->assert_num_equals(1, $obj3->matches({message=>['False', qr/False/, sub {/Message/}, undef]}));

    eval q{
        package Exception::BaseTest::matches::Package1;
        use base 'Exception::Base';
        use constant ATTRS => {
            %{ Exception::Base->ATTRS },
            string_attributes => { default => [ 'message', 'strattr' ] },
            numeric_attribute    => { default => 'numattr' },
            strattr => { is => 'rw' },
            numattr => { is => 'rw' },
        };
    };
    $self->assert_equals('', $@);

    my $obj4 = Exception::BaseTest::matches::Package1->new;
    $self->assert_num_equals(1, $obj4->matches(undef));
    $self->assert_num_equals(1, $obj4->matches(0));

    my $obj5 = Exception::BaseTest::matches::Package1->new(message=>'Message', value=>123);
    $self->assert_num_equals(0, $obj5->matches(undef));
    $self->assert_num_equals(1, $obj5->matches('Message'));
    $self->assert_num_equals(1, $obj5->matches(qr/Message/));
    $self->assert_num_equals(1, $obj5->matches(sub{qr/Message/}));
    $self->assert_num_equals(1, $obj5->matches(0));

    my $obj6 = Exception::BaseTest::matches::Package1->new(message=>'Message', strattr=>'String', value=>123, numattr=>456);
    $self->assert_num_equals(0, $obj6->matches(undef));
    $self->assert_num_equals(1, $obj6->matches('Message: String'));
    $self->assert_num_equals(1, $obj6->matches(qr/Message: String/));
    $self->assert_num_equals(1, $obj6->matches(sub{qr/Message: String/}));
    $self->assert_num_equals(1, $obj6->matches(456));
}

sub test_catch {
    my $self = shift;

    local $SIG{__DIE__};

    eval { 1; };
    my $e1 = Exception::Base->catch;
    $self->assert_null($e1);

    eval { die "Die 2\n"; };
    my $e2 = Exception::Base->catch;
    $self->assert_not_equals('', ref $e2);
    $self->assert($e2->isa("Exception::Base"), '$e2->isa("Exception::Base")');
    $self->assert_equals("Die 2", $e2->{message});
    $self->assert($e2->isa("Exception::Base"), '$e2->isa("Exception::Base")');
    $self->assert_equals('Exception::BaseTest', $e2->{caller_stack}->[0]->[0]);

    eval { die "Die 3\n"; };
    my $e3 = Exception::Base->catch;
    $self->assert_not_equals('', ref $e3);
    $self->assert($e3->isa("Exception::Base"), '$e3->isa("Exception::Base")');
    $self->assert_equals("Die 3", $e3->{message});

    eval { Exception::Base->throw; };
    my $e5 = Exception::Base->catch;
    $self->assert_not_equals('', ref $e5);
    $self->assert($e5->isa("Exception::Base"), '$e5->isa("Exception::Base")');
    $self->assert_null($e5->{message});

    eval { 1; };
    my $e10 = Exception::Base->catch;
    $self->assert_null($e10);

    eval { die $self; };
    my $e13 = Exception::Base->catch;
    $self->assert_str_not_equals('', $e13);
    $self->assert($e13->isa("Exception::Base"), '$e13->isa("Exception::Base")');

    eval { Exception::Base->throw; };
    my $e14 = Exception::Base::catch;
    $self->assert($e14->isa("Exception::Base"), '$e14->isa("Exception::Base")');

    eval { 1; };
    eval 'package Exception::Base::catch::Package16; our @ISA = "Exception::Base"; 1;';
    $self->assert_equals('', "$@");
    eval {
        die "Die 16";
    };
    my $e16 = Exception::Base->catch;
    $self->assert_equals('Exception::Base', ref $e16);

    eval { 1; };
    eval 'package Exception::Base::catch::Package17; our @ISA = "Exception::Base"; 1;';
    $self->assert_equals('', "$@");
    eval {
        die "Die 17";
    };
    my $e17 = Exception::Base::catch::Package17->catch;
    $self->assert_equals('Exception::Base::catch::Package17', ref $e17);

    eval q{
        package Exception::BaseTest::catch::Package19;
        use base 'Exception::Base';
        use constant ATTRS => {
            %{ Exception::Base->ATTRS },
            eval_attribute => { default => 'myattr' },
        myattr => { is => 'rw' },
        };
    };
    $self->assert_equals('', $@);

    # Recover $@ to myattr
    eval {
        die 'Throw 19';
    };
    my $e19 = Exception::BaseTest::catch::Package19->catch;
    $self->assert_not_equals('', ref $e19);
    $self->assert_equals('Exception::BaseTest::catch::Package19', ref $e19);
    $self->assert($e19->isa("Exception::Base"), '$e19->isa("Exception::Base")');
    $self->assert_equals('Throw 19', $e19->{myattr});
    $self->assert_null($e19->{message});
}

sub test_catch_non_exception {
    my $self = shift;

    local $SIG{__DIE__};

    # empty stack trace
    while (Exception::Base->catch(my $obj0)) { };

    $@ = "Unknown message";
    my $obj1 = Exception::Base->catch;
    $self->assert_equals("Unknown message", $obj1->{message});

    do { $@ = "Unknown message\n" };
    my $obj2 = Exception::Base->catch;
    $self->assert_equals("Unknown message", $obj2->{message});

    do { $@ = "Unknown message at file line 123.\n" };
    my $obj3 = Exception::Base->catch;
    $self->assert_equals("Unknown message", $obj3->{message});

    do { $@ = "Unknown message at file line 123 thread 456789.\n" };
    my $obj4 = Exception::Base->catch;
    $self->assert_equals("Unknown message", $obj4->{message});

    do { $@ = "Unknown message at foo at bar at baz at file line 123.\n" };
    my $obj5 = Exception::Base->catch;
    $self->assert_equals("Unknown message at foo at bar at baz", $obj5->{message});

    do { $@ = "Unknown message\nNext line\n" };
    my $obj6 = Exception::Base->catch;
    $self->assert_equals("Unknown message\nNext line", $obj6->{message});

    do { $@ = "Unknown message\n\t...propagated at -e line 1.\n" };
    my $obj7 = Exception::Base->catch;
    $self->assert_equals("Unknown message", $obj7->{message});

    do { $@ = "Unknown message\n\t...propagated at -e line 1.\n\t...propagated at file line 123 thread 456789.\n" };
    my $obj8 = Exception::Base->catch;
    $self->assert_equals("Unknown message", $obj8->{message});
}

sub test_import_all {
    my $self = shift;

    local $SIG{__DIE__};

    eval 'Exception::Base->import(":all");';
    $self->assert_equals('', "$@");
}

sub test_import_class {
    my $self = shift;

    local $SIG{__DIE__};

    no warnings 'reserved';

    eval 'Exception::Base->throw;';
    my $obj1 = $@;
    $self->assert_not_equals('', ref $obj1);
    $self->assert($obj1->isa("Exception::Base"), '$obj1->isa("Exception::Base")');

    eval 'Exception::Base->import(qw<Exception::Base>);';
    $self->assert_equals('', "$@");

    eval 'Exception::Base->import(qw<Exception::Base::import::Test2>);';
    $self->assert_equals('', "$@");
    eval 'Exception::Base::import::Test2->throw;';
    my $obj2 = $@;
    $self->assert($obj2->isa("Exception::Base::import::Test2"), '$obj->isa("Exception::Base::import::Test2")');
    $self->assert($obj2->isa("Exception::Base"), '$obj2->isa("Exception::Base")');
    $self->assert_equals('0.01', $obj2->VERSION);

    eval 'Exception::Base->import("Exception::Base::import::Test3" => {isa=>"Exception::Base::import::Test2",
        version=>1.3});';
    $self->assert_equals('', "$@");
    eval 'Exception::Base::import::Test3->throw;';
    my $obj3 = $@;
    $self->assert($obj3->isa("Exception::Base::import::Test3"), '$obj3->isa("Exception::Base::import::Test3")');
    $self->assert($obj3->isa("Exception::Base::import::Test2"), '$obj3->isa("Exception::Base::import::Test2")');
    $self->assert($obj3->isa("Exception::Base"), '$obj3->isa("Exception::Base")');
    $self->assert_equals('1.3', $obj3->VERSION);

    eval 'Exception::Base->import("Exception::Base::import::Test4" => {version=>1.4});';
    $self->assert_equals('', "$@");
    eval 'Exception::Base::import::Test4->throw;';
    my $obj4 = $@;
    $self->assert($obj4->isa("Exception::Base::import::Test4"), '$obj4->isa("Exception::Base::import::Test4")');
    $self->assert($obj4->isa("Exception::Base"), '$obj4->isa("Exception::Base")');
    $self->assert_equals('1.4', $obj4->VERSION);

    eval 'Exception::Base->import("Exception::Base::import::Test5" => {isa=>qw<Exception::Base::import::Test6>});';
    $self->assert("$@");

    eval 'Exception::Base::import::Test3->import(qw<Exception::Base::import::Test7>);';
    $self->assert_matches(qr/can only be created with/, "$@");

    eval 'Exception::Base->import("Exception::Base::import::Test8" => "__Scalar");';
    $self->assert_equals('', "$@");
    eval 'Exception::Base::import::Test8->throw;';
    my $obj8 = $@;
    $self->assert($obj8->isa("Exception::Base::import::Test8"), '$obj8->isa("Exception::Base::import::Test8")');
    $self->assert($obj8->isa("Exception::Base"), '$obj8->isa("Exception::Base")');
    $self->assert_equals('0.01', $obj8->VERSION);

    eval 'package Exception::Base::import::Test9; our $VERSION = 1.9; our @ISA = ("Exception::Base"); 1;';
    eval 'Exception::Base->import(qw<Exception::Base::import::Test9>);';
    $self->assert_equals('', "$@");
    eval 'Exception::Base::import::Test9->throw;';
    my $obj9 = $@;
    $self->assert($obj9->isa("Exception::Base::import::Test9"), '$obj9->isa("Exception::Base::import::Test9")');
    $self->assert($obj9->isa("Exception::Base"), '$obj9->isa("Exception::Base")');
    $self->assert_equals('1.9', $obj9->VERSION);

    eval 'package Exception::Base::import::Test10; our $VERSION = 1.10; our @ISA = ("Exception::Base"); 1;';
    eval 'Exception::Base->import("Exception::Base::import::Test10" => {version=>0.10});';
    $self->assert_equals('', "$@");
    eval 'Exception::Base::import::Test10->throw;';
    my $obj10 = $@;
    $self->assert($obj10->isa("Exception::Base::import::Test10"), '$obj10->isa("Exception::Base::import::Test10")');
    $self->assert($obj10->isa("Exception::Base"), '$obj10->isa("Exception::Base")');
    $self->assert_equals('1.10', $obj10->VERSION);

    eval 'package Exception::Base::import::Test11; our $VERSION = 1.11; our @ISA = ("Exception::Base"); 1;';
    eval 'Exception::Base->import("Exception::Base::import::Test11" => {version=>2.11});';
    $self->assert_equals('', "$@");
    eval 'Exception::Base::import::Test11->throw;';
    my $obj11 = $@;
    $self->assert($obj11->isa("Exception::Base::import::Test11"), '$obj11->isa("Exception::Base::import::Test10")');
    $self->assert($obj11->isa("Exception::Base"), '$obj11->isa("Exception::Base")');
    $self->assert_equals('2.11', $obj11->VERSION);

    eval 'Exception::Base->import("Exception::Base" => {version=>999.12});';
    $self->assert_matches(qr/version 999.12 required/, "$@");

    eval 'Exception::Base->import("Exception::Base::import::Test12" => {message=>"Message", verbosity=>1});';
    $self->assert_equals('', "$@");
    eval 'Exception::Base::import::Test12->throw;';
    my $obj12 = $@;
    $self->assert($obj12->isa("Exception::Base::import::Test12"), '$obj12->isa("Exception::Base::import::Test12")');
    $self->assert($obj12->isa("Exception::Base"), '$obj10->isa("Exception::Base")');
    $self->assert_equals("Message\n", "$obj12");

    eval 'Exception::Base->import("Exception::Base::import::Test13" => {time=>"readonly"});';
    $self->assert_matches(qr/class does not implement default value/, "$@");

    eval 'Exception::Base->import("Exception::Base::import::Test14" => {
        isa=>"Exception::Base::import::Test14::NotExists"});';
    $self->assert_matches(qr/can not be found/, "$@");

    eval 'Exception::Base->import("Exception::Base::import::Test15" => {has => "attr1"});';
    $self->assert_equals('', "$@");
    eval 'Exception::Base::import::Test15->throw(attr1=>"attr1");';
    my $obj15 = $@;
    $self->assert($obj15->isa("Exception::Base::import::Test15"), '$obj15->isa("Exception::Base::import::Test15")');
    $self->assert($obj15->isa("Exception::Base"), '$obj15->isa("Exception::Base")');
    $self->assert_equals("attr1", $obj15->{attr1});
    $self->assert_equals("attr1", $obj15->attr1);

    eval 'Exception::Base->import("Exception::Base::import::Test16" => {isa => "Exception::Base::import::Test15", has => [ "attr2", "attr3" ]});';
    $self->assert_equals('', "$@");
    eval 'Exception::Base::import::Test16->throw(attr1=>"attr1", attr2=>"attr2", attr3=>"attr3");';
    my $obj16 = $@;
    $self->assert($obj16->isa("Exception::Base::import::Test16"), '$obj16->isa("Exception::Base::import::Test16")');
    $self->assert($obj16->isa("Exception::Base"), '$obj16->isa("Exception::Base")');
    $self->assert_equals("attr1", $obj16->{attr1});
    $self->assert_equals("attr1", $obj16->attr1);
    $self->assert_equals("attr2", $obj16->{attr2});
    $self->assert_equals("attr2", $obj16->attr2);
    $self->assert_equals("attr3", $obj16->{attr3});
    $self->assert_equals("attr3", $obj16->attr3);

    eval 'Exception::Base->import("Exception::Base::import::Test17" => {has => { rw => "attr4", ro => [ "attr5" ] } });';
    $self->assert_equals('', "$@");
    eval 'Exception::Base::import::Test17->throw(attr4=>"attr4", attr5=>"attr5");';
    my $obj17 = $@;
    $self->assert($obj17->isa("Exception::Base::import::Test17"), '$obj17->isa("Exception::Base::import::Test17")');
    $self->assert($obj17->isa("Exception::Base"), '$obj17->isa("Exception::Base")');
    $self->assert_equals("attr4", $obj17->{attr4});
    $self->assert_equals("attr4", $obj17->attr4);
    $self->assert_null($obj17->{attr5});
    $self->assert_null($obj17->attr5);

    eval 'Exception::Base->import("Exception::Base::import::Test18" => {has => "has"});';
    $self->assert_matches(qr/can not be defined/, "$@");

    eval 'Exception::Base->import("Exception::Base::import::Test18" => {has => [ "message" ]});';
    $self->assert_matches(qr/can not be defined/, "$@");

    eval 'Exception::Base->import("Exception::Base::import::Test18" => {has => { ro => "VERSION" } });';
    $self->assert_matches(qr/can not be defined/, "$@");

    eval 'package Exception::Base::import::Test19; Exception::Base->import("Exception::Base::import::Test19" => {version=>2.19});';
    $self->assert_equals('', "$@");
    eval 'Exception::Base::import::Test19->throw;';
    my $obj19 = $@;
    $self->assert($obj19->isa("Exception::Base::import::Test19"), '$obj19->isa("Exception::Base::import::Test19")');
    $self->assert($obj19->isa("Exception::Base"), '$obj19->isa("Exception::Base")');
    $self->assert_equals('2.19', $obj19->VERSION);

    eval 'Exception::Base->import("Exception::BaseTest::SyntaxError");';
    $self->assert_matches(qr/Can not load/, "$@");

    eval 'Exception::Base->import("Exception::BaseTest::MissingVersion");';
    $self->assert_matches(qr/Can not load/, "$@");

    eval 'Exception::Base->import("Exception::BaseTest::LoadedException");';
    $self->assert_equals('', "$@");
}

sub test_import_defaults {
    my $self = shift;

    # set up
    my $fields = Exception::Base->ATTRS;
    my %defaults_orig = map { $_ => $fields->{$_}->{default} }
                            grep { exists $fields->{$_}->{default} }
                            keys %{ $fields };

    eval {
        no warnings 'reserved';

        eval 'Exception::Base->import("message" => "New message");';
        $self->assert_equals('', "$@");
        $self->assert_equals('New message', $fields->{message}->{default});

        eval 'Exception::Base->import("+message" => " with suffix");';
        $self->assert_equals('', "$@");
        $self->assert_equals('New message with suffix', $fields->{message}->{default});

        eval 'Exception::Base->import("-message" => "Another new message");';
        $self->assert_equals('', "$@");
        $self->assert_equals('Another new message', $fields->{message}->{default});

        eval 'Exception::Base->import("ignore_package" => [ "1" ]);';
        $self->assert_equals('', "$@");
        $self->assert_deep_equals([qw<1>], $fields->{ignore_package}->{default});

        eval 'Exception::Base->import("+ignore_package" => "2");';
        $self->assert_equals('', "$@");
        $self->assert_deep_equals([qw<1 2>], [sort @{ $fields->{ignore_package}->{default} }]);

        eval 'Exception::Base->import("+ignore_package" => [ "3" ]);';
        $self->assert_equals('', "$@");
        $self->assert_deep_equals([qw<1 2 3>], [sort @{ $fields->{ignore_package}->{default} }]);

        eval 'Exception::Base->import("+ignore_package" => [ "3", "4", "5" ]);';
        $self->assert_equals('', "$@");
        $self->assert_deep_equals([qw<1 2 3 4 5>], [sort @{ $fields->{ignore_package}->{default} }]);

        eval 'Exception::Base->import("+ignore_package" => [ "1", "2", "3" ]);';
        $self->assert_equals('', "$@");
        $self->assert_deep_equals([qw<1 2 3 4 5>], [sort @{ $fields->{ignore_package}->{default} }]);

        eval 'Exception::Base->import("-ignore_package" => [ "1" ]);';
        $self->assert_equals('', "$@");
        $self->assert_deep_equals([qw<2 3 4 5>], [sort @{ $fields->{ignore_package}->{default} }]);

        eval 'Exception::Base->import("-ignore_package" => "2");';
        $self->assert_equals('', "$@");
        $self->assert_deep_equals([qw<3 4 5>], [sort @{ $fields->{ignore_package}->{default} }]);

        eval 'Exception::Base->import("-ignore_package" => [ "2", "3", "4" ]);';
        $self->assert_equals('', "$@");
        $self->assert_deep_equals([qw<5>], [sort @{ $fields->{ignore_package}->{default} }]);

        eval 'Exception::Base->import("+ignore_package" => qr/6/);';
        $self->assert_equals('', "$@");
        $self->assert_deep_equals([qw<(?-xism:6) 5>], [sort @{ $fields->{ignore_package}->{default} }]);
        $self->assert_equals('Regexp', ref $fields->{ignore_package}->{default}->[1]);

        eval 'Exception::Base->import("-ignore_package" => [ "5", qr/6/ ]);';
        $self->assert_equals('', "$@");
        $self->assert_deep_equals([ ], [sort @{ $fields->{ignore_package}->{default} }]);

        eval 'Exception::Base->import("ignore_level" => 5);';
        $self->assert_equals('', "$@");
        $self->assert_equals(5, $fields->{ignore_level}->{default});

        eval 'Exception::Base->import("+ignore_level" => 1);';
        $self->assert_equals('', "$@");
        $self->assert_equals(6, $fields->{ignore_level}->{default});

        eval 'Exception::Base->import("-ignore_level" => 2);';
        $self->assert_equals('', "$@");
        $self->assert_equals(4, $fields->{ignore_level}->{default});

        eval 'Exception::Base->import("ignore_class" => undef);';
        $self->assert_equals('', "$@");
        $self->assert_null($fields->{ignore_class}->{default});

        eval 'Exception::Base->import("exception_basetest_no_such_field" => undef);';
        $self->assert_matches(qr/class does not implement/, "$@");

        # Change default verbosity
        eval 'Exception::Base->import("Exception::Base::import_defaults::Test1" => { verbosity => 0 });';
        $self->assert_equals('', "$@");
        
        eval { Exception::Base::import_defaults::Test1->throw(message=>'Message') };
        $self->assert_equals('Exception::Base::import_defaults::Test1', ref $@);
        $self->assert_equals('', "$@");

        eval { Exception::Base::import_defaults::Test1->import(verbosity=>1) };        
        $self->assert_equals('', "$@");

        eval { Exception::Base::import_defaults::Test1->throw(message=>'Message') };
        $self->assert_equals('Exception::Base::import_defaults::Test1', ref $@);
        $self->assert_equals("Message\n", "$@");
        
    };
    my $e = $@;

    # tear down
    foreach (keys %defaults_orig) {
        if (not defined $defaults_orig{$_}) {
            eval sprintf 'Exception::Base->import("%s" => undef);', $_;
        }
        elsif (ref $defaults_orig{$_} eq 'ARRAY') {
            eval sprintf 'Exception::Base->import("%s" => [%s]);', $_, join(',', map { "'$_'" } @{ $defaults_orig{$_} });
        }
        elsif ($defaults_orig{$_} =~ /^\d+$/) {
            eval sprintf 'Exception::Base->import("%s" => %s);', $_, $defaults_orig{$_};
        }
        else {
            eval sprintf 'Exception::Base->import("%s" => "%s");', $_, $defaults_orig{$_};
        }
    }

    $self->assert_equals('Unknown exception', $fields->{message}->{default});
    $self->assert_deep_equals([ ], $fields->{ignore_package}->{default});
    $self->assert_equals(0, $fields->{ignore_level}->{default});

    die "$e" if $e;
}

sub test__collect_system_data {
    my $self = shift;

    {
        package Exception::BaseTest::_collect_system_data::Test1;
        sub sub1 {
        my $obj = shift;
            $obj->_collect_system_data;
            return $obj;
        }
        sub sub2 {
            return sub1 shift();
        }
        sub sub3 {
            return sub2 shift();
        }

        package Exception::BaseTest::_collect_system_data::Test2;
        sub sub1 {
            return Exception::BaseTest::_collect_system_data::Test1::sub1 shift();
        }
        sub sub2 {
            return sub1 shift();
        }
        sub sub3 {
            return sub2 shift();
        }

        package Exception::BaseTest::_collect_system_data::Test3;
        sub sub1 {
            return Exception::BaseTest::_collect_system_data::Test2::sub1 shift();
        }
        sub sub2 {
            return sub1 shift();
        }
        sub sub3 {
            return sub2 shift();
        }
    }

    my $obj1 = Exception::Base->new;
    Exception::BaseTest::_collect_system_data::Test3::sub3($obj1);
    $self->assert_equals('Exception::BaseTest::_collect_system_data::Test2', $obj1->{caller_stack}->[0]->[0]);
    $self->assert_equals('Exception::BaseTest::_collect_system_data::Test1::sub1', $obj1->{caller_stack}->[0]->[3]);
}

sub test__caller_info {
    my $self = shift;

    my $obj = Exception::Base->new;

    $obj->{caller_stack} = [
        ['Package0', 'Package0.pm', 1, 'Package0::func0', 0, undef, undef, undef ],
        ['Package1', 'Package1.pm', 1, 'Package1::func1', 1, undef, undef, undef ],
        ['Package2', 'Package2.pm', 1, 'Package2::func2', 1, undef, undef, undef, 1 ],
        ['Package3', 'Package3.pm', 1, 'Package3::func3', 1, undef, undef, undef, 1, 2, 3, 4, 5, 6, 7, 8],
    ];
    $self->assert_equals('Package0::func0', ${$obj->_caller_info(0)}{sub_name});
    $self->assert_equals('Package1::func1()', ${$obj->_caller_info(1)}{sub_name});
    $self->assert_equals('Package2::func2(1)', ${$obj->_caller_info(2)}{sub_name});
    $self->assert_equals('Package3::func3(1, 2, 3, 4, 5, 6, 7, 8)', ${$obj->_caller_info(3)}{sub_name});
    $obj->{defaults}->{max_arg_nums} = 5;
    $self->assert_equals('Package3::func3(1, 2, 3, 4, ...)', ${$obj->_caller_info(3)}{sub_name});
    $obj->{max_arg_nums} = 10;
    $self->assert_equals('Package3::func3(1, 2, 3, 4, 5, 6, 7, 8)', ${$obj->_caller_info(3)}{sub_name});
    $obj->{max_arg_nums} = 0;
    $self->assert_equals('Package3::func3(1, 2, 3, 4, 5, 6, 7, 8)', ${$obj->_caller_info(3)}{sub_name});
    $obj->{max_arg_nums} = 1;
    $self->assert_equals('Package3::func3(...)', ${$obj->_caller_info(3)}{sub_name});
    $obj->{max_arg_nums} = 2;
    $self->assert_equals('Package3::func3(1, ...)', ${$obj->_caller_info(3)}{sub_name});
    $self->assert_not_null($obj->ATTRS->{max_arg_nums}->{default});
    $self->assert_equals($obj->ATTRS->{max_arg_nums}->{default}, $obj->{defaults}->{max_arg_nums} = $obj->ATTRS->{max_arg_nums}->{default});
}

sub test__get_subname {
    my $self = shift;
    my $obj = Exception::Base->new;
    $self->assert_equals('sub', $obj->_get_subname({subroutine=>'sub'}));
    $self->assert_equals('eval {...}', $obj->_get_subname({subroutine=>'(eval)'}));
    $self->assert_equals("eval 'evaltext'", $obj->_get_subname({subroutine=>'sub', evaltext=>'evaltext'}));
    $self->assert_equals("require evaltext", $obj->_get_subname({subroutine=>'sub', evaltext=>'evaltext', is_require=>1}));
    $self->assert_equals("eval 'eval\\\\\\\'text'", $obj->_get_subname({subroutine=>'sub', evaltext=>'eval\\\'text'}));
    $obj->{defaults}->{max_eval_len} = 5;
    $self->assert_equals("eval 'ev...'", $obj->_get_subname({subroutine=>'sub', evaltext=>'evaltext'}));
    $obj->{max_eval_len} = 10;
    $self->assert_equals("eval 'evaltext'", $obj->_get_subname({subroutine=>'sub', evaltext=>'evaltext'}));
    $obj->{max_eval_len} = 0;
    $self->assert_equals("eval 'evaltext'", $obj->_get_subname({subroutine=>'sub', evaltext=>'evaltext'}));
    $self->assert_not_null($obj->ATTRS->{max_eval_len}->{default});
    $self->assert_equals($obj->ATTRS->{max_eval_len}->{default}, $obj->{defaults}->{max_eval_len} = $obj->ATTRS->{max_eval_len}->{default});
}

sub test__format_arg {
    my $self = shift;
    my $obj = Exception::Base->new;
    $self->assert_equals('undef', $obj->_format_arg());
    $self->assert_equals('""', $obj->_format_arg(''));
    $self->assert_equals('0', $obj->_format_arg('0'));
    $self->assert_equals('1', $obj->_format_arg('1'));
    $self->assert_equals('12.34', $obj->_format_arg('12.34'));
    $self->assert_equals('"A"', $obj->_format_arg('A'));
    $self->assert_equals('"\""', $obj->_format_arg("\""));
    $self->assert_equals('"\`"', $obj->_format_arg("\`"));
    $self->assert_equals('"\\\\"', $obj->_format_arg("\\"));
    $self->assert_equals('"\x{0d}"', $obj->_format_arg("\x{0d}"));
    $self->assert_equals('"\x{c3}"', $obj->_format_arg("\x{c3}"));
    $self->assert_equals('"\x{263a}"', $obj->_format_arg("\x{263a}"));
    $self->assert_equals('"\x{c3}\x{263a}"', $obj->_format_arg("\x{c3}\x{263a}"));
    $self->assert(qr/^.ARRAY/, $obj->_format_arg([]));
    $self->assert(qr/^.HASH/, $obj->_format_arg({}));
    $self->assert(qr/^.Exception::BaseTest=/, $obj->_format_arg($self));
    $self->assert(qr/^.Exception::Base=/, $obj->_format_arg($obj));
    $obj->{defaults}->{max_arg_len} = 5;
    $self->assert_equals('12...', $obj->_format_arg('123456789'));
    $obj->{max_arg_len} = 10;
    $self->assert_equals('123456789', $obj->_format_arg('123456789'));
    $obj->{max_arg_len} = 0;
    $self->assert_equals('123456789', $obj->_format_arg('123456789'));
    $self->assert_not_null($obj->ATTRS->{max_arg_len}->{default});
    $self->assert_equals($obj->ATTRS->{max_arg_len}->{default}, $obj->{defaults}->{max_arg_len} = $obj->ATTRS->{max_arg_len}->{default});
}

sub test__str_len_trim {
    my $self = shift;
    my $obj = Exception::Base->new;
    $self->assert_equals('', $obj->_str_len_trim(''));
    $self->assert_equals('1', $obj->_str_len_trim('1'));
    $self->assert_equals('12', $obj->_str_len_trim('12'));
    $self->assert_equals('123', $obj->_str_len_trim('123'));
    $self->assert_equals('1234', $obj->_str_len_trim('1234'));
    $self->assert_equals('12345', $obj->_str_len_trim('12345'));
    $self->assert_equals('123456789', $obj->_str_len_trim('123456789'));
    $self->assert_equals('', $obj->_str_len_trim('', 10));
    $self->assert_equals('1', $obj->_str_len_trim('1', 10));
    $self->assert_equals('12', $obj->_str_len_trim('12', 10));
    $self->assert_equals('123', $obj->_str_len_trim('123', 10));
    $self->assert_equals('1234', $obj->_str_len_trim('1234', 10));
    $self->assert_equals('12345', $obj->_str_len_trim('12345', 10));
    $self->assert_equals('123456789', $obj->_str_len_trim('123456789', 10));
    $self->assert_equals('', $obj->_str_len_trim('', 2));
    $self->assert_equals('1', $obj->_str_len_trim('1', 2));
    $self->assert_equals('12', $obj->_str_len_trim('12', 2));
    $self->assert_equals('123', $obj->_str_len_trim('123', 2));
    $self->assert_equals('1234', $obj->_str_len_trim('1234', 2));
    $self->assert_equals('12345', $obj->_str_len_trim('12345', 2));
    $self->assert_equals('123456789', $obj->_str_len_trim('123456789', 2));
    $self->assert_equals('', $obj->_str_len_trim('', 3));
    $self->assert_equals('1', $obj->_str_len_trim('1', 3));
    $self->assert_equals('12', $obj->_str_len_trim('12', 3));
    $self->assert_equals('123', $obj->_str_len_trim('123', 3));
    $self->assert_equals('...', $obj->_str_len_trim('1234', 3));
    $self->assert_equals('...', $obj->_str_len_trim('12345', 3));
    $self->assert_equals('...', $obj->_str_len_trim('123456789', 3));
    $self->assert_equals('', $obj->_str_len_trim('', 4));
    $self->assert_equals('1', $obj->_str_len_trim('1', 4));
    $self->assert_equals('12', $obj->_str_len_trim('12', 4));
    $self->assert_equals('123', $obj->_str_len_trim('123', 4));
    $self->assert_equals('1234', $obj->_str_len_trim('1234', 4));
    $self->assert_equals('1...', $obj->_str_len_trim('12345', 4));
    $self->assert_equals('1...', $obj->_str_len_trim('123456789', 4));
    $self->assert_equals('', $obj->_str_len_trim('', 5));
    $self->assert_equals('1', $obj->_str_len_trim('1', 5));
    $self->assert_equals('12', $obj->_str_len_trim('12', 5));
    $self->assert_equals('123', $obj->_str_len_trim('123', 5));
    $self->assert_equals('1234', $obj->_str_len_trim('1234', 5));
    $self->assert_equals('12345', $obj->_str_len_trim('12345', 5));
    $self->assert_equals('12...', $obj->_str_len_trim('123456789', 5));
}

1;
