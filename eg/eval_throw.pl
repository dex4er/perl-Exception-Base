#!/usr/bin/perl -I../lib

use Exception::Base ':all',
    'Exception::Eval';

eval { open $file, "x", "/badmodeexample" };
throw Exception::Eval message=>"cannot open" if $@;
