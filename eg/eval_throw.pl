#!/usr/bin/perl -I../lib

use strict;
use warnings;

use Exception::Base ':all',
    'Exception::Eval';

eval { open my $file, "x", "/badmodeexample" };
throw 'Exception::Eval' => message=>"cannot open", verbosity=>4 if $@;
