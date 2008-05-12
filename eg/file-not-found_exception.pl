#!/usr/bin/perl -I../lib

use strict;
use warnings;

# Use module and create needed exceptions
use Exception::Base
    'verbosity' => 3,
    'Exception::IO',
    'Exception::FileNotFound' => { isa => 'Exception::IO', has => 'filename' };

sub func1 {
    # try / catch
    eval {
        my $file = '/notfound';
        open my $fh, $file
            or Exception::FileNotFound->throw(
                   message=>'Can not open file', filename=>$file
               );
	close $fh;
    };

    if ($@) {
        my $e = Exception::Base->catch;
        # $e is an exception object for sure, no need to check if is blessed
        warn "Exception caught";
        if ($e->isa('Exception::FileNotFound')) {
            warn "Exception caught for file " . $e->file;
        }
        # rethrow the exception
        warn "Rethrow exception";
        $e->throw;
    }
}

sub func2 {
    func1(1);
}

sub func3 {
    func2(2,2);
}

func3(3,3,3);
