#!/usr/bin/perl -al

BEGIN {
    {    
        package My::Eval;
        our $n = 0;
        sub test {
            eval { 1; };
            $n++;
        }
    }    

    {    
        package My::DieScalar;
        our $n = 0;
        sub test {
            eval { die "Message\n"; };
            if ($@ eq "Message\n") { $n++; }
        }
    }    

    {    
        package My::DieObject;
        our $n = 0;
        sub test {
            eval { My::DieObject->throw };
            if ($@ and $@->isa('My::DieObject')) { $n++; }
        }
        sub throw {
            my %args = @_;
            die bless {%args}, shift;
        }
    }    

    {    
        package My::Exception;
        use lib 'lib', '../lib';	
        use Exception::Base ':all', 'Exception::My';
        our $n = 0;
        sub test {
            try eval { Exception::My->throw(message=>'Message') };
            if (catch my $e) {
                if ($e->isa('Exception::My') and $e->with('Message')) { $n++; }
            }
        }
    }    

    {    
        package My::Exception1;
        use lib 'lib', '../lib';
        use Exception::Base ':all', 'Exception::My';
        our $n = 0;
        sub test {
            try eval { Exception::My->throw(message=>'Message', verbosity=>1) };
            if (catch my $e) {
                if ($e->isa('Exception::My') and $e->with('Message')) { $n++; }
            }
        }
    }    
    
    eval q{
        package My::Error;
        use Error qw(:try);
        our $n = 0;
        sub test {
            try {
                Error::Simple->throw('Message');
            }
            Error->catch(with {
                my $e = shift;
                if ($e->text eq 'Message') { $n++; }
            });
        }
    };

    eval q{    
        package My::ClassThrowable;
        use Class::Throwable;
        our $n = 0;
        sub test {
            eval {
                Class::Throwable->throw('Message');
            };
            if ($@ and $@->isa('Class::Throwable')) {
                if ($@->getMessage eq 'Message') { $n++; }
            };
        }
    };

    eval q{    
        package My::ExceptionClass;
        use Exception::Class 'MyException';
        our $n = 0;
        sub test {
            eval { MyException->throw( error=>'Message' ) };
            my $e;
            if ($e = Exception::Class->caught('MyException') and $e->error eq 'Message') { $n++; }
        }
    };    

    eval q{    
        package My::ExceptionClassTryCatch;
        use Exception::Class 'MyException';
        use Exception::Class::TryCatch;
        our $n = 0;
        sub test {
            try eval { MyException->throw( error=>'Message' ) };
            if (catch my $e) {
                if ($e->isa('MyException') and $e->error eq 'Message') { $n++; }
            }
        }
    };
}


package main;

use Benchmark ':all';

my %tests = (
    '1_DieScalar'                 => sub { My::DieScalar->test },
    '2_DieObject'                 => sub { My::DieObject->test },
    '3_Exception'                 => sub { My::Exception->test },
    '4_Exception1'                => sub { My::Exception1->test },
);
$tests{'5_Error'}                  = sub { My::Error->test }                  if eval { Error->VERSION };
$tests{'6_ExceptionClass'}         = sub { My::ExceptionClass->test }         if eval { Exception::Class->VERSION };
$tests{'7_ExceptionClassTryCatch'} = sub { My::ExceptionClassTryCatch->test } if eval { Exception::Class::TryCatch->VERSION };
$tests{'8_ClassThrowable'}         = sub { My::ClassThrowable->test }         if eval { Class::Throwable->VERSION };

my $result = timethese(-1, { %tests });
cmpthese($result);
