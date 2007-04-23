#!/usr/bin/perl -I../lib

# Use module and create needed exceptions
use Exception::Base
    'Exception::IO',
    'Exception::FileNotFound' => { isa => 'Exception::IO' };

sub func1 {
    # try / catch
    try Exception::Base eval {
        my $file = '/notfound';
        open FILE, $file
            or throw Exception::FileNotFound
                     message=>'Can not open file', file=>$file;
    };

    if (catch Exception::IO my $e) {
        # $e is an exception object for sure, no need to check if is blessed
        warn "Exception caught";
        if ($e->isa('Exception::FileNotFound')) {
            warn "Exception caught for file " . $e->{properties}->{file};
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
