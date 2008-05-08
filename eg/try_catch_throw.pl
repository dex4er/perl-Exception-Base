#!/usr/bin/perl -I../lib

use Exception::Base
    ':all',
    'verbosity' => 3,
    'Exception::My';

try eval {
    try eval { open $file, "z", "/badmodeexample" };
    if (catch my $e) {
        throw 'Exception::My' => $e, message=>"cannot open";
    }
};
if (catch my $e) {
    throw $e;
}
