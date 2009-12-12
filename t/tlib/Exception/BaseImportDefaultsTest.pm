package Exception::BaseImportDefaultsTest;

use strict;
use warnings;

use Test::Unit::Lite;
use base 'Test::Unit::TestCase';

use Exception::Base;

sub test_import_defaults_message {
    my $self = shift;

    eval {
        Exception::Base->import(
            'Exception::BaseTest::import_defaults::WithMessage',
        );
        Exception::BaseTest::import_defaults::WithMessage->import(
            'message' => "New message",
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_equals('New message', Exception::BaseTest::import_defaults::WithMessage->ATTRS->{message}->{default});
};

sub test_import_defaults_plus_message {
    my $self = shift;

    eval {
        Exception::Base->import(
            'Exception::BaseTest::import_defaults::WithPlusMessage',
        );
        Exception::BaseTest::import_defaults::WithPlusMessage->import(
            '+message' => " with suffix",
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_equals('Unknown exception with suffix', Exception::BaseTest::import_defaults::WithPlusMessage->ATTRS->{message}->{default});
};

sub test_import_defaults_minus_message {
    my $self = shift;

    eval {
        Exception::Base->import(
            'Exception::BaseTest::import_defaults::WithMinusMessage',
        );
        Exception::BaseTest::import_defaults::WithMinusMessage->import(
            'message' => "New message",
        );
        Exception::BaseTest::import_defaults::WithMinusMessage->import(
            '-message' => "Another new message",
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_equals('Another new message', Exception::BaseTest::import_defaults::WithMinusMessage->ATTRS->{message}->{default});
};

sub test_import_defaults_ignore_package {
    my $self = shift;

    eval {
        Exception::Base->import(
            'Exception::BaseTest::import_defaults::WithIgnorePackage',
        );
        Exception::BaseTest::import_defaults::WithIgnorePackage->import(
            "ignore_package" => [ "1" ]
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([ 1 ], Exception::BaseTest::import_defaults::WithIgnorePackage->ATTRS->{ignore_package}->{default});

    eval {
        Exception::BaseTest::import_defaults::WithIgnorePackage->import(
            "+ignore_package" => "2"
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([ 1, 2 ], [sort @{ Exception::BaseTest::import_defaults::WithIgnorePackage->ATTRS->{ignore_package}->{default} }]);

    eval {
        Exception::BaseTest::import_defaults::WithIgnorePackage->import(
            "+ignore_package" => [ "3" ]
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([ 1, 2, 3 ], [sort @{ Exception::BaseTest::import_defaults::WithIgnorePackage->ATTRS->{ignore_package}->{default} }]);

    eval {
        Exception::BaseTest::import_defaults::WithIgnorePackage->import(
            "+ignore_package" => [ "3", "4", "5" ]
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([ 1, 2, 3, 4, 5 ], [sort @{ Exception::BaseTest::import_defaults::WithIgnorePackage->ATTRS->{ignore_package}->{default} }]);

    eval {
        Exception::BaseTest::import_defaults::WithIgnorePackage->import(
            "+ignore_package" => [ "1", "2", "3" ]
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([ 1, 2, 3, 4, 5 ], [sort @{ Exception::BaseTest::import_defaults::WithIgnorePackage->ATTRS->{ignore_package}->{default} }]);

    eval {
        Exception::BaseTest::import_defaults::WithIgnorePackage->import(
            "-ignore_package" => [ "1" ]
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([ 2, 3, 4, 5 ], [sort @{ Exception::BaseTest::import_defaults::WithIgnorePackage->ATTRS->{ignore_package}->{default} }]);

    eval {
        Exception::BaseTest::import_defaults::WithIgnorePackage->import(
            "-ignore_package" => "2"
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([ 3, 4 ,5 ], [sort @{ Exception::BaseTest::import_defaults::WithIgnorePackage->ATTRS->{ignore_package}->{default} }]);

    eval {
        Exception::BaseTest::import_defaults::WithIgnorePackage->import(
            "-ignore_package" => [ "2", "3", "4" ]
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([ 5 ], [sort @{ Exception::BaseTest::import_defaults::WithIgnorePackage->ATTRS->{ignore_package}->{default} }]);

    eval {
        Exception::BaseTest::import_defaults::WithIgnorePackage->import(
            "+ignore_package" => qr/6/
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([ '(?-xism:6)', 5 ], [sort @{ Exception::BaseTest::import_defaults::WithIgnorePackage->ATTRS->{ignore_package}->{default} }]);
    $self->assert_equals('Regexp', ref Exception::BaseTest::import_defaults::WithIgnorePackage->ATTRS->{ignore_package}->{default}->[1]);

    eval {
        Exception::BaseTest::import_defaults::WithIgnorePackage->import(
            "-ignore_package" => [ "5", qr/6/ ]
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_deep_equals([], [sort @{ Exception::BaseTest::import_defaults::WithIgnorePackage->ATTRS->{ignore_package}->{default} }]);
};

sub test_import_defaults_ignore_level {
    my $self = shift;

    eval {
        Exception::Base->import(
            'Exception::BaseTest::import_defaults::WithIgnoreLevel',
        );
        Exception::BaseTest::import_defaults::WithIgnoreLevel->import(
            "ignore_level" => 5
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_equals(5, Exception::BaseTest::import_defaults::WithIgnoreLevel->ATTRS->{ignore_level}->{default});

    eval {
        Exception::BaseTest::import_defaults::WithIgnoreLevel->import(
            "+ignore_level" => 1
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_equals(6, Exception::BaseTest::import_defaults::WithIgnoreLevel->ATTRS->{ignore_level}->{default});

    eval {
        Exception::BaseTest::import_defaults::WithIgnoreLevel->import(
            "-ignore_level" => 2
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_equals(4, Exception::BaseTest::import_defaults::WithIgnoreLevel->ATTRS->{ignore_level}->{default});
};

sub test_import_defaults_ignore_class {
    my $self = shift;

    eval {
        Exception::Base->import(
            'Exception::BaseTest::import_defaults::WithIgnoreClass',
        );
        Exception::BaseTest::import_defaults::WithIgnoreClass->import(
            'ignore_class' => undef,
        );
    };
    $self->assert_equals('', "$@");
    $self->assert_null(Exception::BaseTest::import_defaults::WithIgnoreClass->ATTRS->{ignore_class}->{default});
};

sub test_import_defaults_no_such_field {
    my $self = shift;

    eval {
        Exception::Base->import(
            'Exception::BaseTest::import_defaults::WithNoSuchField',
        );
        Exception::BaseTest::import_defaults::WithNoSuchField->import(
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
                'Exception::BaseTest::import_defaults::WithVerbosity' => {
                    verbosity => 0,
                 },
            );
        };
        $self->assert_equals('', "$@");

        eval {
            Exception::BaseTest::import_defaults::WithVerbosity->throw(
                message => 'Message',
            )
        };
        my $obj = $@;
        $self->assert($obj->isa("Exception::BaseTest::import_defaults::WithVerbosity"), '$obj->isa("Exception::BaseTest::import_defaults::WithVerbosity")');
        $self->assert($obj->isa("Exception::Base"), '$obj->isa("Exception::Base")');
        $self->assert_equals("", "$obj");
    };

    {
        eval {
            Exception::BaseTest::import_defaults::WithVerbosity->import(
                verbosity => 1,
            );
        };
        $self->assert_equals('', "$@");

        eval {
            Exception::BaseTest::import_defaults::WithVerbosity->throw(
                message => 'Message',
            );
        };
        my $obj = $@;
        $self->assert($obj->isa("Exception::BaseTest::import_defaults::WithVerbosity"), '$obj->isa("Exception::BaseTest::import_defaults::WithVerbosity")');
        $self->assert($obj->isa("Exception::Base"), '$obj->isa("Exception::Base")');
        $self->assert_equals("Message\n", "$obj");
    };
};

sub test_import_defaults_via_loaded_exception {
    my $self = shift;

    local $SIG{__DIE__} = '';

    {
        eval {
            require Exception::BaseTest::LoadedException;
            Exception::BaseTest::LoadedException->import(
                verbosity => 1,
            );
        };
        $self->assert_equals('', "$@");
        eval {
            Exception::BaseTest::LoadedException->throw(
                message => "Message",
            );
        };
        my $obj = $@;
        $self->assert($obj->isa("Exception::BaseTest::LoadedException"), '$obj->isa("Exception::BaseTest::LoadedException")');
        $self->assert($obj->isa("Exception::Base"), '$obj->isa("Exception::Base")');
        $self->assert_equals("Message\n", "$obj");
    };

    {
        eval {
            Exception::Base->throw(
                message => "Message",
            );
        };
        my $obj = $@;
        $self->assert($obj->isa("Exception::Base"), '$obj->isa("Exception::Base")');
        $self->assert_matches(qr/Message at.* line/, "$obj");
    };
};

1;
