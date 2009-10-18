#!/usr/bin/perl

my %tests = (
    '01_EvalDieScalar'    => { desc => 'eval/die string' },
    '02_EvalDieObject'    => { desc => 'eval/die object' },
    '03_ExceptionEval'    => { desc => 'Exception::Base eval/if' },
    '04_Exception1Eval'   => { desc => 'Exception::Base eval/if verbosity=1' },
    '05_Error'            => { desc => 'Error' },
    '06_ClassThrowable'   => { desc => 'Class::Throwable' },
    '07_ExceptionClass'   => { desc => 'Exception::Class' },
    '08_ExceptionClassTC' => { desc => 'Exception::Class::TryCatch' },
    '09_TryCatch'         => { desc => 'TryCatch' },
    '10_TryTiny'          => { desc => 'Try::Tiny' },
);
