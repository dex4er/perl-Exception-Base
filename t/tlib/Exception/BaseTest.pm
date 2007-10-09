package Exception::BaseTest;

use base 'Test::Unit::TestCase';

use Exception::Base;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub test___isa {
    my $self = shift;
    my $obj1 = Exception::Base->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa('Exception::Base'));
    my $obj2 = $obj1->new;
    $self->assert_not_null($obj2);
    $self->assert($obj2->isa('Exception::Base'));
}

sub test_field_message {
    my $self = shift;
    my $obj = Exception::Base->new(message=>'Message');
    $self->assert_equals('Message', $obj->{message});
    $self->assert_equals('New Message', $obj->{message} = 'New Message');
    $self->assert_equals('New Message', $obj->{message});
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

sub test_field_properties {
    my $self = shift;
    my $obj = Exception::Base->new(message=>'Message', tag=>'Tag');
    $self->assert_equals('Tag', $obj->{properties}->{tag});
}

sub test_accessor_properties {
    my $self = shift;
    my $obj = Exception::Base->new(message=>'Message', tag=>'Tag');
    $self->assert_equals('Tag', $obj->properties->{tag});
}

sub test_throw {
    my $self = shift;

    # Secure with eval
    eval {
        # Simple throw
        eval {
            Exception::Base->throw(message=>'Throw');
        };
        my $obj1 = $@;
        $self->assert_not_null($obj1);
        $self->assert($obj1->isa('Exception::Base'));
        $self->assert_equals('Throw', $obj1->{message});
        $self->assert_equals(__PACKAGE__ . '::test_throw', $obj1->{caller_stack}->[3]->[3]);
        $self->assert_equals(ref $self, ref $obj1->{caller_stack}->[3]->[8]);

        # Rethrow
        eval {
            $obj1->throw;
        };
        my $obj2 = $@;
        $self->assert_not_null($obj2);
        $self->assert($obj2->isa('Exception::Base'));
        $self->assert_equals('Throw', $obj2->{message});
        $self->assert_equals(__PACKAGE__ . '::test_throw', $obj2->{caller_stack}->[3]->[3]);
        $self->assert_equals(ref $self, ref $obj2->{caller_stack}->[3]->[8]);

        # Rethrow with overriden message
        eval {
            $obj1->throw(message=>'New throw');
        };
        my $obj3 = $@;
        $self->assert_not_null($obj3);
        $self->assert($obj3->isa('Exception::Base'));
        $self->assert_equals('New throw', $obj3->{message});
        $self->assert_equals(__PACKAGE__ . '::test_throw', $obj3->{caller_stack}->[3]->[3]);
        $self->assert_equals(ref $self, ref $obj3->{caller_stack}->[3]->[8]);

	# Rethrow with overriden class
        {
            package Exception::Base::throw::Test1;
            our @ISA = ('Exception::Base');
        }

        eval {
            Exception::Base::throw::Test1->throw($obj1);
        };
        my $obj4 = $@;
        $self->assert_not_null($obj4);
        $self->assert($obj4->isa('Exception::Base'));
        $self->assert_equals('New throw', $obj4->{message});
        $self->assert_equals(__PACKAGE__ . '::test_throw', $obj4->{caller_stack}->[3]->[3]);
        $self->assert_equals(ref $self, ref $obj4->{caller_stack}->[3]->[8]);

	# Throw based on last eval error (with \n)
        eval {
	    die "Died\n";
        };
	my $e5 = $@;
        $self->assert_not_equals('', $e5);
	eval {
	    Exception::Base->throw($e5);
	};
        my $obj5 = $@;
        $self->assert_not_null($obj5);
        $self->assert($obj5->isa('Exception::Base'));
        $self->assert_equals('Died', $obj5->{message});
        $self->assert_equals(__PACKAGE__ . '::test_throw', $obj5->{caller_stack}->[3]->[3]);
        $self->assert_equals(ref $self, ref $obj5->{caller_stack}->[3]->[8]);

	# Throw based on last eval error (without \n)
        eval {
	    die "Died";
        };
	my $e6 = $@;
        $self->assert_not_equals('', $e6);
	eval {
	    Exception::Base->throw($e6);
	};
        my $obj6 = $@;
        $self->assert_not_null($obj6);
        $self->assert($obj6->isa('Exception::Base'));
        $self->assert_equals('Died', $obj6->{message});
        $self->assert_equals(__PACKAGE__ . '::test_throw', $obj6->{caller_stack}->[3]->[3]);
        $self->assert_equals(ref $self, ref $obj6->{caller_stack}->[3]->[8]);
    };
    die "$@" if $@;
}

sub test_stringify {
    my $self = shift;

    eval {
        my $obj = Exception::Base->new;

        $self->assert_not_null($obj);
        $self->assert($obj->isa('Exception::Base'));

        $self->assert_equals('', $obj->stringify(0));
        $self->assert_equals("Unknown exception\n", $obj->stringify(1));
        $self->assert_matches(qr/Unknown exception at .* line \d+.\n/s, $obj->stringify(2));

        $self->assert_equals('', $obj->stringify(0));
        $obj->{message} = 'Stringify';
        $self->assert_equals("Stringify\n", $obj->stringify(1));
        $self->assert_matches(qr/Stringify at .* line \d+.\n/s, $obj->stringify(2));
        $self->assert_matches(qr/Exception::Base: Stringify at .* line \d+\n/s, $obj->stringify(3));

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
        $obj->{file} = 'Package1.pm';
        $obj->{line} = 1;

        $self->assert_equals("Stringify at Package1.pm line 1.\n", $obj->stringify(2));

        my $s1 = << 'END';
Exception::Base: Stringify at Package1.pm line 1
\t$_ = Package1::func1 called at Package1.pm line 1
\t@_ = Package2::func2(1, "ARRAY(0x1234567)", "HASH(0x1234567)", "CODE(0x1234567)", "Exception::BaseTest=HASH(0x1234567)", "Exception::Base=HASH(0x1234567)") called at Package2.pm line 2
\t$_ = eval '1' called at Package3.pm line 3
\t$_ = require Require called at Package4.pm line 4
\t$_ = Package5::func5("\x{00}", "'\"\\\`\x{0d}\x{c3}", "\x{09}\x{263a}", undef, 123, -123.56, 1, ...) called at Package5.pm line 5
\t$_ = Package6::func6 called at -e line 6
\t$_ = Package7::func7 called at unknown line 0
END
        $s1 =~ s/\\t/\t/g;

        my $s2 = $obj->stringify(3);
        $s2 =~ s/(ARRAY|HASH|CODE)\(0x\w+\)/$1(0x1234567)/g;
        $self->assert_equals($s1, $s2);

        my $s3 = $obj->stringify;
        $s3 =~ s/(ARRAY|HASH|CODE)\(0x\w+\)/$1(0x1234567)/g;
        $self->assert_equals($s1, $s3);

        $obj->{caller_stack} = [
            ['Package1', 'Package1.pm', 1, 'Package1::func1', 0, undef, undef, undef ],
            ['Package1', 'Package1.pm', 1, 'Package1::func1', 6, 1, undef, undef, 1, 2, 3, 4, 5, 6 ],
            ['Package2', 'Package2.pm', 2, 'Package2::func2', 2, 1, undef, undef, "123456789", "123456789" ],
            ['Package3', 'Package3.pm', 3, '(eval)', 0, undef, "123456789", undef ],
        ];
        $obj->{max_arg_nums} = 2;
        $obj->{max_arg_len} = 5;
        $obj->{max_eval_len} = 5;

        my $s4 = << 'END';
Exception::Base: Stringify at Package1.pm line 1
\t@_ = Package1::func1(1, ...) called at Package1.pm line 1
\t@_ = Package2::func2(12..., 12...) called at Package2.pm line 2
\t$_ = eval '12...' called at Package3.pm line 3
END
        $s4 =~ s/\\t/\t/g;

        my $s5 = $obj->stringify;
        $self->assert_equals($s4, $s5);

        $self->assert_equals(3, $obj->{defaults}->{verbosity});
        $self->assert_equals(1, $obj->{defaults}->{verbosity} = 1);
        $self->assert_equals(1, $obj->{defaults}->{verbosity});
        $self->assert_equals("Stringify\n", $obj->stringify);
        $self->assert_not_null(Exception::Base->FIELDS->{verbosity}->{default});
        $self->assert_equals(3, $obj->{defaults}->{verbosity} = Exception::Base->FIELDS->{verbosity}->{default});
        $self->assert_equals(1, $obj->{verbosity} = 1);
        $self->assert_equals("Stringify\n", $obj->stringify);

        $self->assert_equals("Message\n", $obj->stringify(1, "Message"));
        $self->assert_equals("Unknown exception\n", $obj->stringify(1, ''));
    };
    die "$@" if $@;
}

sub test_with {
    my $self = shift;

    eval {
        my $obj1 = Exception::Base->new;
        $self->assert_null($obj1->with);
        $self->assert_equals(1, $obj1->with(undef));
        $self->assert_equals(0, $obj1->with('Unknown'));
        $self->assert_equals(0, $obj1->with('False'));
        $self->assert_equals(0, $obj1->with(sub {/Unknown/}));
        $self->assert_equals(0, $obj1->with(qr/Unknown/));
        $self->assert_equals(0, $obj1->with(sub {/False/}));
        $self->assert_equals(0, $obj1->with(qr/False/));
        $self->assert_equals(1, $obj1->with(tag=>undef));
        $self->assert_equals(0, $obj1->with(tag=>'false'));
        $self->assert_equals(0, $obj1->with(false=>'false'));
        $self->assert_equals(1, $obj1->with(false=>undef));
        $self->assert_equals(1, $obj1->with(message=>undef));
        $self->assert_equals(0, $obj1->with(message=>'false'));
        $self->assert_equals(0, $obj1->with(message=>sub{/false/}));
        $self->assert_equals(0, $obj1->with(message=>qr/false/));

        my $obj2 = Exception::Base->new(message=>'With', tag=>'tag');
        $self->assert_equals(0, $obj2->with(undef));
        $self->assert_equals(1, $obj2->with('With'));
        $self->assert_equals(0, $obj2->with('False'));
        $self->assert_equals(1, $obj2->with(sub {/With/}));
        $self->assert_equals(0, $obj2->with(sub {/False/}));
        $self->assert_equals(1, $obj2->with(qr/With/));
        $self->assert_equals(0, $obj2->with(qr/False/));
        $self->assert_equals(1, $obj2->with(tag=>'tag'));
        $self->assert_equals(0, $obj2->with(tag=>'false'));
        $self->assert_equals(1, $obj2->with(tag=>sub {/tag/}));
        $self->assert_equals(1, $obj2->with(tag=>qr/tag/));
        $self->assert_equals(0, $obj2->with(tag=>sub {/false/}));
        $self->assert_equals(0, $obj2->with(tag=>qr/false/));
        $self->assert_equals(0, $obj2->with(tag=>undef));
        $self->assert_equals(0, $obj2->with(false=>'false'));
        $self->assert_equals(1, $obj2->with(false=>undef));
        $self->assert_equals(1, $obj2->with('With', tag=>'tag'));
        $self->assert_equals(1, $obj2->with(sub {/With/}, tag=>sub {/tag/}));
        $self->assert_equals(1, $obj2->with(qr/With/, tag=>qr/tag/));
        $self->assert_equals(0, $obj2->with(message=>undef));
        $self->assert_equals(1, $obj2->with(message=>'With'));
        $self->assert_equals(0, $obj2->with(message=>'false'));
        $self->assert_equals(1, $obj2->with(message=>sub{/With/}));
        $self->assert_equals(1, $obj2->with(message=>qr/With/));
        $self->assert_equals(0, $obj2->with(message=>sub{/false/}));
        $self->assert_equals(0, $obj2->with(message=>qr/false/));

        my $obj3 = Exception::Base->new(message=>'Message');
        $obj3->{properties}->{message} = 'Tag';
        $self->assert_equals(0, $obj3->with(undef));
        $self->assert_equals(0, $obj3->with(message=>undef));
        $self->assert_equals(1, $obj3->with('Message'));
        $self->assert_equals(1, $obj3->with(message=>'Tag'));
        $self->assert_equals(1, $obj3->with(message=>sub {/Tag/}));
        $self->assert_equals(0, $obj3->with(message=>sub {/false/}));
        $self->assert_equals(1, $obj3->with(message=>qr/Tag/));
        $self->assert_equals(0, $obj3->with(message=>qr/false/));

        my $obj4 = Exception::Base->new(message=>'Message');
        $self->assert_equals(0, $obj4->with(undef));
        $self->assert_equals(0, $obj4->with(message=>undef));
        $self->assert_equals(1, $obj4->with('Message'));
        $self->assert_equals(1, $obj4->with(message=>'Message'));
        $self->assert_equals(1, $obj4->with(message=>sub {/Message/}));
        $self->assert_equals(0, $obj4->with(message=>sub {/false/}));
        $self->assert_equals(1, $obj4->with(message=>qr/Message/));
        $self->assert_equals(0, $obj4->with(message=>qr/false/));

        my $obj5 = Exception::Base->new(message=>'Message');
        $obj5->{properties}->{message} = undef;
        $self->assert_equals(0, $obj5->with(undef));
        $self->assert_equals(0, $obj5->with(message=>undef));
        $self->assert_equals(1, $obj5->with('Message'));
        $self->assert_equals(1, $obj5->with(message=>'Message'));
        $self->assert_equals(1, $obj5->with(message=>sub {/Message/}));
        $self->assert_equals(0, $obj5->with(message=>sub {/false/}));
        $self->assert_equals(1, $obj5->with(message=>qr/Message/));
        $self->assert_equals(0, $obj5->with(message=>qr/false/));

        my $obj6 = Exception::Base->new(message=>undef);
        $self->assert_equals(1, $obj6->with(undef));
        $self->assert_equals(1, $obj6->with(message=>undef));
        $self->assert_equals(0, $obj6->with('false'));
        $self->assert_equals(0, $obj6->with(message=>'false'));
        $self->assert_equals(0, $obj6->with(message=>sub {/false/}));
        $self->assert_equals(0, $obj6->with(message=>qr/false/));

        my $obj7 = Exception::Base->new;
        $obj7->{properties}->{message} = 'Tag';
        $self->assert_equals(1, $obj7->with(undef));
        $self->assert_equals(0, $obj7->with('Tag'));
        $self->assert_equals(0, $obj7->with('false'));
        $self->assert_equals(0, $obj7->with(message=>undef));
        $self->assert_equals(1, $obj7->with(message=>'Tag'));
        $self->assert_equals(0, $obj7->with(message=>'false'));
        $self->assert_equals(1, $obj7->with(message=>sub {/Tag/}));
        $self->assert_equals(0, $obj7->with(message=>sub {/false/}));
        $self->assert_equals(1, $obj7->with(message=>qr/Tag/));
        $self->assert_equals(0, $obj7->with(message=>qr/false/));
    };
    die "$@" if $@;
}

sub test_catch {
    my $self = shift;

    eval {
        # empty stack trace
        while (Exception::Base->catch(my $obj0)) { };

        eval { 1; };
        my $e1 = Exception::Base->catch(my $obj1);
        $self->assert_str_equals('', $e1);
        $self->assert_null($obj1);

        eval { die "Die 2\n"; };
        my $e2 = Exception::Base->catch(my $obj2);
        $self->assert_str_equals('1', $e2);
        $self->assert_not_null($obj2);
        $self->assert($obj2->isa('Exception::Base'));
        $self->assert_equals("Die 2", $obj2->{message});
        $self->assert($obj2->isa('Exception::Base'));
        $self->assert_equals(__PACKAGE__ . '::test_catch', $obj2->{caller_stack}->[2]->[3]);
        $self->assert_equals($self, $obj2->{caller_stack}->[2]->[8]);

        eval { die "Die 3\n"; };
        my $obj3 = Exception::Base->catch;
        $self->assert_not_null($obj3);
        $self->assert($obj3->isa('Exception::Base'));
        $self->assert_equals("Die 3", $obj3->{message});

        eval { die "Die 4\n"; };
        my $obj4 = Exception::Base->catch(['Exception::Base']);
        $self->assert_not_null($obj4);
        $self->assert($obj4->isa('Exception::Base'));
        $self->assert_equals("Die 4", $obj4->{message});

        eval { Exception::Base->throw; };
        my $e5 = Exception::Base->catch(my $obj5);
        $self->assert_str_not_equals('', $e5);
        $self->assert_not_null($obj5);
        $self->assert($obj5->isa('Exception::Base'));
        $self->assert_null($obj5->{message});

        eval { Exception::Base->throw; };
        my $e6 = Exception::Base->catch(my $obj6, ['Exception::Base']);
        $self->assert_str_not_equals('', $e6);
        $self->assert_not_null($obj6);
        $self->assert($obj6->isa('Exception::Base'));
        $self->assert_null($obj6->{message});

        eval {
            eval { Exception::Base->throw; };
            Exception::Base->catch(['false']);
        };
        my $obj7 = $@;
        $self->assert_not_null($obj7);
        $self->assert($obj7->isa('Exception::Base'));
        $self->assert_null($obj7->{message});

        my $obj8;
        eval {
            eval { Exception::Base->throw; };
            Exception::Base->catch($obj8, ['false']);
        };
        my $obj9 = $@;
        $self->assert_not_null($obj8);
        $self->assert($obj8->isa('Exception::Base'));
        $self->assert_null($obj8->{message});
        $self->assert_not_null($obj9);
        $self->assert($obj9->isa('Exception::Base'));
        $self->assert_null($obj9->{message});

        eval { 1; };
        my $e10 = Exception::Base->catch(my $obj10);
        $self->assert_str_equals('', $e10);
        $self->assert_null($obj10);

        eval { die "Die 11\n"; };
        my $e11 = Exception::Base::catch(my $obj11);
        $self->assert_str_not_equals('', $e11);
        $self->assert_not_null($obj11);
        $self->assert($obj11->isa('Exception::Base'));
        $self->assert_equals("Die 11", $obj11->{message});

        eval { die "Die 12\n"; };
        my $obj12 = Exception::Base::catch;
        $self->assert_not_null($obj12);
        $self->assert($obj12->isa('Exception::Base'));
        $self->assert_equals("Die 12", $obj12->{message});

        eval { die $self; };
        my $e13 = Exception::Base->catch(my $obj13);
        $self->assert_str_not_equals('', $e13);
        $self->assert($obj13->isa('Exception::Base'));

        eval { Exception::Base->throw; };
        my $obj14 = Exception::Base::catch;
        $self->assert($obj14->isa('Exception::Base'));

        eval { Exception::Base->throw; };
        my $obj15 = Exception::Base::catch ['Exception::Base'];
        $self->assert($obj15->isa('Exception::Base'));

        eval { 1; };
        eval 'package Exception::Base::catch::Test16; our @ISA = "Exception::Base"; 1;';
        $self->assert_equals('', "$@");
        eval {
            eval { Exception::Base::catch::Test16->throw; };
            Exception::Base->catch;
        };
        $self->assert_equals('', "$@");

        eval { 1; };
        eval 'package Exception::Base::catch::Test17; our @ISA = "Exception::Base"; 1;';
        $self->assert_equals('', "$@");
        eval {
            eval { Exception::Base::catch::Test17->throw; };
            Exception::Base::catch::Test17->catch;
        };
        $self->assert_equals('', "$@");

        eval { 1; };
        eval 'package Exception::Base::catch::Test18a; our @ISA = "Exception::Base"; 1;';
        $self->assert_equals('', "$@");
        eval 'package Exception::Base::catch::Test18b; our @ISA = "Exception::Base"; 1;';
        $self->assert_equals('', "$@");
        eval {
            eval { Exception::Base::catch::Test18a->throw; };
            Exception::Base::catch::Test18b->catch;
        };
        $self->assert_not_equals('', "$@");
    };
    die "$@" if $@;
}

sub test_catch_non_exception {
    my $self = shift;

    eval {
        # empty stack trace
        while (Exception::Base->catch(my $obj0)) { };

        my $file = __FILE__;
        my $regexp = qr/Exception::Base: Unknown message at $file line \d+( thread \d+)?\n/s;

        eval { 1; };
        $@ = "Unknown message";
        my $obj1 = Exception::Base->catch;
        $self->assert_matches($regexp, "$obj1");

        eval { 1; };
        $@ = "Unknown message\n";
        my $obj2 = Exception::Base->catch;
        $self->assert_matches($regexp, "$obj2");

        eval { 1; };
        $@ = "Unknown message at file line 123.\n";
        my $obj3 = Exception::Base->catch;
        $self->assert_matches($regexp, "$obj3");

        eval { 1; };
        $@ = "Unknown message at file line 123 thread 456789.\n";
        my $obj4 = Exception::Base->catch;
        $self->assert_matches($regexp, "$obj4");

        eval { 1; };
        $@ = "Unknown message at foo at bar at baz at file line 123.\n";
        my $obj5 = Exception::Base->catch;
        $regexp = qr/Exception::Base: Unknown message at foo at bar at baz at $file line \d+( thread \d+)?\n/s;
        $self->assert_matches($regexp, "$obj5");

        eval { 1; };
        $@ = "Unknown message\nNext line\n";
        my $obj6 = Exception::Base->catch;
        $regexp = qr/Exception::Base: Unknown message\nNext line at $file line \d+( thread \d+)?\n/s;
        $self->assert_matches($regexp, "$obj6");

    };
    die "$@" if $@;
}

sub test_try {
    my $self = shift;

    eval {
        # empty stack trace
        while (Exception::Base->catch(my $obj0)) { };

        eval { 1; };
        my $v1 = Exception::Base->try(eval { 1; });
        $self->assert_equals(1, $v1);
        my $e1 = Exception::Base->catch(my $obj1);
        $self->assert_str_equals('', $e1);
        $self->assert_null($obj1);

        eval { 1; };
        my @v2 = Exception::Base->try([eval { (1,2,3); }]);
        $self->assert_deep_equals([1,2,3],\@v2);
        my $e2 = Exception::Base->catch(my $obj2);
        $self->assert_str_equals('', $e2);
        $self->assert_null($obj2);

        eval { 1; };
        my $v3 = Exception::Base->try([eval { (1,2,3); }]);
        $self->assert_matches(qr/^ARRAY/, $v3);
        my $e3 = Exception::Base->catch(my $obj3);
        $self->assert_str_equals('', $e3);
        $self->assert_null($obj3);

        eval { 1; };
        my $v4 = Exception::Base->try(eval { die "Die 4\n"; });
        $self->assert_null($v4);
        my $e4 = Exception::Base->catch(my $obj4);
        $self->assert_str_equals(1, $e4);
        $self->assert_not_null($obj4);
        $self->assert($obj4->isa('Exception::Base'));
        $self->assert_equals("Die 4", $obj4->{message});

        eval { 1; };
        my $v5 = Exception::Base->try(eval { die "Die 5\n"; });
        $self->assert_null($v5);
        eval { 1; };
        my $e5 = Exception::Base->catch(my $obj5);
        $self->assert_str_equals(1, $e5);
        $self->assert_not_null($obj5);
        $self->assert($obj5->isa('Exception::Base'));
        $self->assert_equals("Die 5", $obj5->{message});

        eval { 1; };
        my $v6 = Exception::Base->try(eval { die "Die 6\n"; });
        $self->assert_null($v6);
        my $v7 = Exception::Base->try(eval { die "Die 7\n"; });
        $self->assert_null($v7);
        eval { 1; };
        my $e7 = Exception::Base->catch(my $obj7);
        $self->assert_str_equals(1, $e7);
        $self->assert_not_null($obj7);
        $self->assert($obj7->isa('Exception::Base'));
        $self->assert_equals("Die 7", $obj7->{message});
        eval { 1; };
        my $e6 = Exception::Base->catch(my $obj6);
        $self->assert_str_equals(1, $e6);
        $self->assert_not_null($obj6);
        $self->assert($obj6->isa('Exception::Base'));
        $self->assert_equals("Die 6", $obj6->{message});

        eval { 1; };
        my $e8 = Exception::Base->catch(my $obj8);
        $self->assert_str_equals('', $e8);
        $self->assert_str_not_equals("Die 6", $obj8) if defined $obj8;

        eval { 1; };
        my $v9 = Exception::Base::try(eval { die "Die 9\n"; });
        $self->assert_null($v9);
        my $e9 = Exception::Base::catch(my $obj9);
        $self->assert_str_equals(1, $e9);
        $self->assert_not_null($obj9);
        $self->assert($obj9->isa('Exception::Base'));
        $self->assert_equals("Die 9", $obj9->{message});

        my $obj10 = Exception::Base->new;
        eval { 1; };
        my $v11 = $obj10->try(eval { die "Die 11\n"; });
        $self->assert_null($v11);
        my $e11 = $obj10->catch(my $obj11);
        $self->assert_str_equals(1, $e11);
        $self->assert_not_null($obj11);
        $self->assert($obj11->isa('Exception::Base'));
        $self->assert_equals("Die 11", $obj11->{message});

        eval { 1; };
        my $v12 = Exception::Base::try([eval { die "Die 12\n"; }]);
        $self->assert_matches(qr/^ARRAY/, $v12);
        my $e12 = Exception::Base->catch(my $obj12);
        $self->assert_str_equals(1, $e12);
        $self->assert_not_null($obj12);
        $self->assert($obj12->isa('Exception::Base'));
        $self->assert_equals("Die 12", $obj12->{message});

        eval { 1; };
        my @v13 = Exception::Base->try({eval { (1,2,3,4); }});
        $self->assert_deep_equals([{1,2,3,4}],\@v13);
        my $e13 = Exception::Base->catch(my $obj13);
        $self->assert_str_equals('', $e13);
        $self->assert_null($obj13);
    };
    die "$@" if $@;
}

sub test_import {
    my $self = shift;

    eval {
        no warnings 'reserved';

        eval 'try eval { throw Exception::Base; }; catch my $e, ["Exception::Base"];';
        $self->assert_not_equals('', "$@");

        eval '$try = "SCALAR";';
        $self->assert_equals('SCALAR', $try);

        eval 'Exception::Base->import(qw<try catch>);';
        eval 'try eval { throw Exception::Base; }; catch my $e, ["Exception::Base"];';
        $self->assert_equals('', "$@");
        $self->assert_equals('SCALAR', $try);

        eval 'Exception::Base->unimport(qw<notsuchfunction>);';
        eval 'try eval { throw Exception::Base; }; catch my $e, ["Exception::Base"];';
        $self->assert_equals('', "$@");

        eval 'Exception::Base->unimport(qw<try>);';
        eval 'try eval { throw Exception::Base; };';
        $self->assert_matches(qr/^syntax error/, "$@");
        $self->assert_equals('SCALAR', $try);

        eval 'Exception::Base->import(qw<:all>);';
        eval 'try eval { throw Exception::Base; }; catch my $e, ["Exception::Base"];';
        $self->assert_equals('', "$@");

        eval 'Exception::Base->unimport(qw<:all>);';
        eval 'catch my $e, ["Exception"];';
        $self->assert_matches(qr/^syntax error/, "$@");
        $self->assert_equals('SCALAR', $try);

        eval 'Exception::Base->import(qw<:all>);';
        eval 'try eval { throw Exception::Base; }; catch my $e, ["Exception::Base"];';
        $self->assert_equals('', "$@");

        eval 'Exception::Base->unimport();';
        eval 'catch my $e, ["Exception"];';
        $self->assert_matches(qr/^syntax error/, "$@");
        $self->assert_equals('SCALAR', $try);

        eval 'throw Exception::Base::import::Test1;';
        $self->assert_matches(qr/^Can.t locate object method/, "$@");

        eval 'throw Exception::Base;';
        my $obj1 = $@;
        $self->assert_not_null($obj1);
        $self->assert($obj1->isa('Exception::Base'));

        eval 'Exception::Base->import(qw<Exception::Base>);';
        $self->assert_equals('', "$@");

        eval 'Exception::Base->import(qw<Exception::Base::import::Test2>);';
        $self->assert_equals('', "$@");
        eval 'throw Exception::Base::import::Test2;';
        my $obj2 = $@;
        $self->assert($obj2->isa('Exception::Base::import::Test2'));
        $self->assert($obj2->isa('Exception::Base'));
        $self->assert_equals('0.01', $obj2->VERSION);

        eval 'Exception::Base->import(Exception::Base::import::Test3 => {isa=>qw<Exception::Base::import::Test2>,
            version=>1.3});';
        $self->assert_equals('', "$@");
        eval 'throw Exception::Base::import::Test3;';
        my $obj3 = $@;
        $self->assert($obj3->isa('Exception::Base::import::Test3'));
        $self->assert($obj3->isa('Exception::Base::import::Test2'));
        $self->assert($obj3->isa('Exception::Base'));
        $self->assert_equals('1.3', $obj3->VERSION);

        eval 'Exception::Base->import(Exception::Base::import::Test4 => {version=>1.4});';
        $self->assert_equals('', "$@");
        eval 'throw Exception::Base::import::Test4;';
        my $obj4 = $@;
        $self->assert($obj4->isa('Exception::Base::import::Test4'));
        $self->assert($obj4->isa('Exception::Base'));
        $self->assert_equals('1.4', $obj4->VERSION);

        eval 'Exception::Base->import(Exception::Base::import::Test5 => {isa=>qw<Exception::Base::import::Test6>});';
        $self->assert("$@");

        eval 'Exception::Base::import::Test3->import(qw<Exception::Base::import::Test7>);';
        $self->assert_matches(qr/can only be created with/, "$@");

        eval 'Exception::Base->import(Exception::Base::import::Test8 => "__Scalar");';
        $self->assert_equals('', "$@");
        eval 'throw Exception::Base::import::Test8;';
        my $obj8 = $@;
        $self->assert($obj8->isa('Exception::Base::import::Test8'));
        $self->assert($obj8->isa('Exception::Base'));
        $self->assert_equals('0.01', $obj8->VERSION);

        eval 'package Exception::Base::import::Test9; our $VERSION = 1.9; our @ISA = ("Exception::Base"); 1;';
        eval 'Exception::Base->import(qw<Exception::Base::import::Test9>);';
        $self->assert_equals('', "$@");
        eval 'throw Exception::Base::import::Test9;';
        my $obj9 = $@;
        $self->assert($obj9->isa('Exception::Base::import::Test9'));
        $self->assert($obj9->isa('Exception::Base'));
        $self->assert_equals('1.9', $obj9->VERSION);

        eval 'package Exception::Base::import::Test10; our $VERSION = 1.10; our @ISA = ("Exception::Base"); 1;';
        eval 'Exception::Base->import("Exception::Base::import::Test10" => {version=>0.10});';
        $self->assert_equals('', "$@");
        eval 'throw Exception::Base::import::Test10;';
        my $obj10 = $@;
        $self->assert($obj10->isa('Exception::Base::import::Test10'));
        $self->assert($obj10->isa('Exception::Base'));
        $self->assert_equals('1.10', $obj10->VERSION);

        eval 'package Exception::Base::import::Test11; our $VERSION = 1.11; our @ISA = ("Exception::Base"); 1;';
        eval 'Exception::Base->import("Exception::Base::import::Test11" => {version=>2.11});';
        $self->assert_equals('', "$@");
        eval 'throw Exception::Base::import::Test11;';
        my $obj11 = $@;
        $self->assert($obj11->isa('Exception::Base::import::Test11'));
        $self->assert($obj11->isa('Exception::Base'));
        $self->assert_equals('2.11', $obj11->VERSION);

        eval 'Exception::Base->import("Exception::Base" => {version=>999.12});';
        $self->assert_matches(qr/class can not be created automatically/, "$@");

        eval 'Exception::Base->import("Exception::Base::import::Test12" => {message=>"Message", verbosity=>1});';
        $self->assert_equals('', "$@");
        eval 'throw Exception::Base::import::Test12;';
        my $obj12 = $@;
        $self->assert($obj12->isa('Exception::Base::import::Test12'));
        $self->assert($obj12->isa('Exception::Base'));
        $self->assert_equals("Message\n", "$obj12");

        eval 'Exception::Base->import("Exception::Base::import::Test13" => {time=>"readonly"});';
        $self->assert_matches(qr/class does not implement default value/, "$@");

        eval 'Exception::Base->import("Exception::Base::import::Test14" => {
            isa=>Exception::Base::import::Test14::NotExists});';
        $self->assert_matches(qr/can not be found/, "$@");
    };
    die "$@" if $@;
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

    my $obj2 = Exception::Base->new;
    Exception::BaseTest::_collect_system_data::Test3::sub3($obj2);
    $self->assert_equals('Exception::BaseTest::_collect_system_data::Test2', $obj2->{caller_stack}->[0]->[0]);
    $self->assert_equals('Exception::BaseTest::_collect_system_data::Test1::sub1', $obj2->{caller_stack}->[0]->[3]);

    my $obj3 = Exception::Base->new;
    $obj3->{ignore_package} = 'Exception::BaseTest::_collect_system_data::Test2';
    Exception::BaseTest::_collect_system_data::Test3::sub3($obj3);
    $self->assert_equals('Exception::BaseTest::_collect_system_data::Test3', $obj3->{caller_stack}->[0]->[0]);
    $self->assert_equals('Exception::BaseTest::_collect_system_data::Test2::sub1', $obj3->{caller_stack}->[0]->[3]);

    my $obj4 = Exception::Base->new;
    $obj4->{ignore_package} = ['Exception::BaseTest::_collect_system_data::Test2'];
    Exception::BaseTest::_collect_system_data::Test3::sub3($obj4);
    $self->assert_equals('Exception::BaseTest::_collect_system_data::Test3', $obj4->{caller_stack}->[0]->[0]);
    $self->assert_equals('Exception::BaseTest::_collect_system_data::Test2::sub1', $obj4->{caller_stack}->[0]->[3]);

    my $obj5 = Exception::Base->new;
    $obj5->{ignore_package} = ['Non::Existant'];
    Exception::BaseTest::_collect_system_data::Test3::sub3($obj5);
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
    $self->assert_not_null($obj->FIELDS->{max_arg_nums}->{default});
    $self->assert_equals($obj->FIELDS->{max_arg_nums}->{default}, $obj->{defaults}->{max_arg_nums} = $obj->FIELDS->{max_arg_nums}->{default});
}

sub test__get_subname {
    my $self = shift;
    my $obj = Exception::Base->new;
    $self->assert_equals('sub', $obj->_get_subname({sub=>'sub'}));
    $self->assert_equals('eval {...}', $obj->_get_subname({sub=>'(eval)'}));
    $self->assert_equals("eval 'evaltext'", $obj->_get_subname({sub=>'sub', evaltext=>'evaltext'}));
    $self->assert_equals("require evaltext", $obj->_get_subname({sub=>'sub', evaltext=>'evaltext', is_require=>1}));
    $self->assert_equals("eval 'eval\\\\\\\'text'", $obj->_get_subname({sub=>'sub', evaltext=>'eval\\\'text'}));
    $obj->{defaults}->{max_eval_len} = 5;
    $self->assert_equals("eval 'ev...'", $obj->_get_subname({sub=>'sub', evaltext=>'evaltext'}));
    $obj->{max_eval_len} = 10;
    $self->assert_equals("eval 'evaltext'", $obj->_get_subname({sub=>'sub', evaltext=>'evaltext'}));
    $obj->{max_eval_len} = 0;
    $self->assert_equals("eval 'evaltext'", $obj->_get_subname({sub=>'sub', evaltext=>'evaltext'}));
    $self->assert_not_null($obj->FIELDS->{max_eval_len}->{default});
    $self->assert_equals($obj->FIELDS->{max_eval_len}->{default}, $obj->{defaults}->{max_eval_len} = $obj->FIELDS->{max_eval_len}->{default});
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
    $self->assert_not_null($obj->FIELDS->{max_arg_len}->{default});
    $self->assert_equals($obj->FIELDS->{max_arg_len}->{default}, $obj->{defaults}->{max_arg_len} = $obj->FIELDS->{max_arg_len}->{default});
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
