package Exception::BaseImportDefaultsTest;

use strict;
use warnings;

use Test::Unit::Lite;
use base 'Test::Unit::TestCase';

use Exception::Base;

sub set_up {
    my $self = shift;

    $self->{fields} = Exception::Base->ATTRS;
    $self->{defaults_orig} = {
        map { $_ => $self->{fields}->{$_}->{default} }
        grep { exists $self->{fields}->{$_}->{default} }
        keys %{ $self->{fields} }
    };
};

sub tear_down {
    my $self = shift;

    foreach (keys %{ $self->{defaults_orig} } ) {
        if (not defined $self->{defaults_orig}->{$_}) {
            $self->{fields}->{$_}->{default} = undef;
        }
        elsif (ref $self->{defaults_orig}->{$_} eq 'ARRAY') {
            $self->{fields}->{$_}->{default} = [ @{ $self->{defaults_orig}->{$_} } ];
        }
        else {
            $self->{fields}->{$_}->{default} = $self->{defaults_orig}->{$_};
        };
    };

    $self->assert_equals('Unknown exception', $self->{fields}->{message}->{default});
    $self->assert_deep_equals([ ], $self->{fields}->{ignore_package}->{default});
    $self->assert_equals(0, $self->{fields}->{ignore_level}->{default});
};

sub test_import_defaults_message {
    my $self = shift;

    eval {
        Exception::Base->import(
            'message' => "New message",
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_equals('New message', $self->{fields}->{message}->{default});
};

sub test_import_defaults_plus_message {
    my $self = shift;

    eval {
        Exception::Base->import(
            '+message' => " with suffix",
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_equals('Unknown exception with suffix', $self->{fields}->{message}->{default});
};

sub test_import_defaults_minus_message {
    my $self = shift;

    eval {
        Exception::Base->import(
            '-message' => "Another new message",
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_equals('Another new message', $self->{fields}->{message}->{default});
};

sub test_import_defaults_ignore_package {
    my $self = shift;

    eval {
        Exception::Base->import("ignore_package" => [ "1" ]);
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([qw<1>], $self->{fields}->{ignore_package}->{default});

    eval {
        Exception::Base->import("+ignore_package" => "2");
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([qw<1 2>], [sort @{ $self->{fields}->{ignore_package}->{default} }]);

    eval {
        Exception::Base->import("+ignore_package" => [ "3" ]);
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([qw<1 2 3>], [sort @{ $self->{fields}->{ignore_package}->{default} }]);

    eval {
        Exception::Base->import("+ignore_package" => [ "3", "4", "5" ]);
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([qw<1 2 3 4 5>], [sort @{ $self->{fields}->{ignore_package}->{default} }]);

    eval {
        Exception::Base->import("+ignore_package" => [ "1", "2", "3" ]);
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([qw<1 2 3 4 5>], [sort @{ $self->{fields}->{ignore_package}->{default} }]);

    eval {
        Exception::Base->import("-ignore_package" => [ "1" ]);
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([qw<2 3 4 5>], [sort @{ $self->{fields}->{ignore_package}->{default} }]);

    eval {
        Exception::Base->import("-ignore_package" => "2");
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([qw<3 4 5>], [sort @{ $self->{fields}->{ignore_package}->{default} }]);

    eval {
        Exception::Base->import("-ignore_package" => [ "2", "3", "4" ]);
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([qw<5>], [sort @{ $self->{fields}->{ignore_package}->{default} }]);

    eval {
        Exception::Base->import("+ignore_package" => qr/6/);
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([qw<(?-xism:6) 5>], [sort @{ $self->{fields}->{ignore_package}->{default} }]);
    $self->assert_equals('Regexp', ref $self->{fields}->{ignore_package}->{default}->[1]);

    eval {
        Exception::Base->import("-ignore_package" => [ "5", qr/6/ ]);
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([ ], [sort @{ $self->{fields}->{ignore_package}->{default} }]);
};

sub test_import_defaults_ignore_level {
    my $self = shift;

    eval {
        Exception::Base->import("ignore_level" => 5);
    };
    $self->assert_equals('', "$@");
    $self->assert_equals(5, $self->{fields}->{ignore_level}->{default});

    eval {
        Exception::Base->import("+ignore_level" => 1);
    };
    $self->assert_equals('', "$@");
    $self->assert_equals(6, $self->{fields}->{ignore_level}->{default});

    eval {
        Exception::Base->import("-ignore_level" => 2);
    };
    $self->assert_equals('', "$@");
    $self->assert_equals(4, $self->{fields}->{ignore_level}->{default});
};

sub test_import_defaults_ignore_class {
    my $self = shift;

    eval {
        Exception::Base->import(
            'ignore_class' => undef,
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_null($self->{fields}->{ignore_class}->{default});
};

sub test_import_defaults_no_such_field {
    my $self = shift;

    eval {
        Exception::Base->import(
            'exception_basetest_no_such_field' => undef,
        );
    };
    $self->assert_matches(qr/class does not implement default value/, "$@");
};

sub test_import_defaults_verbosity {
    my $self = shift;

    {
        eval {
            Exception::Base->import(
                'Exception::BaseTest::import_defaults::Test' => {
                    verbosity => 0,
                 },
            );
        };
        $self->assert_equals('', "$@");

        eval {
            Exception::BaseTest::import_defaults::Test->throw(
                message => 'Message',
            )
        };
        my $obj = $@;
        $self->assert($obj->isa("Exception::BaseTest::import_defaults::Test"), '$obj->isa("Exception::BaseTest::import_defaults::Test")');
        $self->assert($obj->isa("Exception::Base"), '$obj->isa("Exception::Base")');
        $self->assert_equals("", "$obj");
    };

    {
        eval {
            Exception::BaseTest::import_defaults::Test->import(
                verbosity => 1,
            );
        };
        $self->assert_equals('', "$@");

        eval {
            Exception::BaseTest::import_defaults::Test->throw(
                message => 'Message',
            );
        };
        my $obj = $@;
        $self->assert($obj->isa("Exception::BaseTest::import_defaults::Test"), '$obj->isa("Exception::BaseTest::import_defaults::Test")');
        $self->assert($obj->isa("Exception::Base"), '$obj->isa("Exception::Base")');
        $self->assert_equals("Message\n", "$obj");
    };
};

1;
