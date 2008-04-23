#!/usr/bin/perl -I../lib -al

BEGIN {
    {    
        package My::EvalDieScalarFail;
        our $n = 0;
        sub test {
            eval { die "Message\n"; };
            if ($@ eq "Message\n") { $n++; }
        }
    }    

    {    
        package My::EvalDieObjectFail;
        our $n = 0;
        sub test {
            eval { My::EvalDieObjectFail->throw };
            if (my $e = $@) {
		if ($e->isa('My::EvalDieObjectFail')) { $n++; }
	    }
        }
        sub throw {
            my %args = @_;
            die bless {%args}, shift;
        }
    }    

    {    
        package My::ExceptionEvalFail;
        use lib 'lib', '../lib';	
        use Exception::Base ':all', 'Exception::My';
        our $n = 0;
        sub test {
            eval {
		Exception::My->throw(message=>'Message');
	    };
            if (my $e = $@) {
                if ($e->isa('Exception::My') and $e->with('Message')) { $n++; }
            }
        }
    }    

    {    
        package My::ExceptionTryFail;
        use lib 'lib', '../lib';	
        use Exception::Base ':all', 'Exception::My';
        our $n = 0;
        sub test {
            try eval {
		Exception::My->throw(message=>'Message')
	    };
            if (catch my $e) {
                if ($e->isa('Exception::My') and $e->with('Message')) { $n++; }
            }
        }
    }    

    {    
        package My::Exception1Fail;
        use lib 'lib', '../lib';
        use Exception::Base ':all', 'Exception::My';
        our $n = 0;
        sub test {
            try eval {
		Exception::My->throw(message=>'Message', verbosity=>1)
	    };
            if (catch my $e) {
                if ($e->isa('Exception::My') and $e->with('Message')) { $n++; }
            }
        }
    }    
    
    eval q{
        package My::ErrorFail;
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
        package My::ClassThrowableFail;
        use Class::Throwable;
        our $n = 0;
        sub test {
            eval {
                Class::Throwable->throw('Message');
            };
            if (my $e = $@) {
                if ($e->isa('Class::Throwable') and $e->getMessage eq 'Message') { $n++; }
            };
        }
    };

    eval q{    
        package My::ExceptionClassFail;
        use Exception::Class 'MyException';
        our $n = 0;
        sub test {
            eval {
		MyException->throw( error=>'Message' )
	    };
            my $e;
            if ($e = Exception::Class->caught('MyException') and $e->error eq 'Message') { $n++; }
        }
    };    

    eval q{    
        package My::ExceptionClassTCFail;
        use Exception::Class 'MyException';
        use Exception::Class::TryCatch;
        our $n = 0;
        sub test {
            try eval {
		MyException->throw( error=>'Message' )
	    };
            if (catch my $e) {
                if ($e->isa('MyException') and $e->error eq 'Message') { $n++; }
            }
        }
    };
}


package main;

use Benchmark ':all';

my %tests = (
    '01_EvalDieScalarFail'           => sub { My::EvalDieScalarFail->test },
    '02_EvalDieObjectFail'           => sub { My::EvalDieObjectFail->test },
    '03_ExceptionEvalFail'           => sub { My::ExceptionEvalFail->test },
    '04_ExceptionTryFail'            => sub { My::ExceptionTryFail->test },
    '05_Exception1Fail'              => sub { My::Exception1Fail->test },
);
$tests{'06_ErrorFail'}                = sub { My::ErrorFail->test }              if eval { Error->VERSION };
$tests{'07_ExceptionClassFail'}       = sub { My::ExceptionClassFail->test }     if eval { Exception::Class->VERSION };
$tests{'08_ExceptionClassTCFail'}     = sub { My::ExceptionClassTCFail->test }   if eval { Exception::Class::TryCatch->VERSION };
$tests{'09_ClassThrowableFail'}       = sub { My::ClassThrowableFail->test }     if eval { Class::Throwable->VERSION };

my $result = timethese(-1, { %tests });
cmpthese($result);
