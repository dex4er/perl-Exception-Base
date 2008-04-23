#!/usr/bin/perl -I../lib -al

BEGIN {
    {    
        package My::EvalDieScalarOK;
        our $n = 0;
        sub test {
            eval { $n; };
            $n++;
        }
    }    

    {    
        package My::EvalDieObjectOK;
        our $n = 0;
        sub test {
            eval { $n; };
            $n++;
        }
    }    

    {    
        package My::ExceptionEvalOK;
        use lib 'lib', '../lib';	
        use Exception::Base ':all', 'Exception::My';
        our $n = 0;
        sub test {
            eval { $n; };
            if (my $e = $@) {
                if ($e->isa('Exception::My') and $e->with('Message')) { $n++; }
            }
        }
    }    

    {    
        package My::ExceptionTryOK;
        use lib 'lib', '../lib';	
        use Exception::Base ':all', 'Exception::My';
        our $n = 0;
        sub test {
            try eval {
		$n;
	    };
            if (catch my $e) {
                if ($e->isa('Exception::My') and $e->with('Message')) { $n++; }
            }
        }
    }    

    {    
        package My::Exception1OK;
        use lib 'lib', '../lib';
        use Exception::Base ':all', 'Exception::My';
        our $n = 0;
        sub test {
            try eval {
		$n;
	    };
            if (catch my $e) {
                if ($e->isa('Exception::My') and $e->with('Message')) { $n++; }
            }
        }
    }    
    
    eval q{
        package My::ErrorOK;
        use Error qw(:try);
        our $n = 0;
        sub test {
            try {
		$n;
            }
            Error->catch(with {
                my $e = shift;
                if ($e->text eq 'Message') { $n++; }
            });
        }
    };

    eval q{    
        package My::ClassThrowableOK;
        use Class::Throwable;
        our $n = 0;
        sub test {
            eval {
                $n;
            };
            if (my $e = $@ and $e->isa('Class::Throwable')) {
                if ($e->getMessage eq 'Message') { $n++; }
            };
        }
    };

    eval q{    
        package My::ExceptionClassOK;
        use Exception::Class 'MyException';
        our $n = 0;
        sub test {
            eval {
		$n;
	    };
            my $e;
            if ($e = Exception::Class->caught('MyException') and $e->error eq 'Message') { $n++; }
        }
    };    

    eval q{    
        package My::ExceptionClassTCOK;
        use Exception::Class 'MyException';
        use Exception::Class::TryCatch;
        our $n = 0;
        sub test {
            try eval { 
		$n;
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
    '01_EvalDieScalarOK'             => sub { My::EvalDieScalarOK->test },
    '02_EvalDieObjectOK'             => sub { My::EvalDieObjectOK->test },
    '03_ExceptionEvalOK'             => sub { My::ExceptionEvalOK->test },
    '04_ExceptionTryOK'              => sub { My::ExceptionTryOK->test },
    '05_Exception1OK'                => sub { My::Exception1OK->test },
);
$tests{'06_ErrorOK'}                  = sub { My::ErrorOK->test }                if eval { Error->VERSION };
$tests{'07_ExceptionClassOK'}         = sub { My::ExceptionClassOK->test }       if eval { Exception::Class->VERSION };
$tests{'08_ExceptionClassTCOK'}       = sub { My::ExceptionClassTCOK->test }     if eval { Exception::Class::TryCatch->VERSION };
$tests{'09_ClassThrowableOK'}         = sub { My::ClassThrowableOK->test }       if eval { Class::Throwable->VERSION };

my $result = timethese(-1, { %tests });
cmpthese($result);
