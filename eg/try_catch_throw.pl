#!/usr/bin/perl -I../lib

use Exception::Base ':all',
    'Exception::Eval';

try eval { open $file, "z", "/badmodeexample" };
if (catch my $e) {
    throw Exception::Eval $e, message=>"cannot open";
}
