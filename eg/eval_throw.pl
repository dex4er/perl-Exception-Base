#!/usr/bin/perl -l -I../lib

use strict;
use warnings;

use Exception::Base ':all';

eval {
    eval { open my $file, "<", "/badmodeexample"
        or Exception::Base->throw( message=>"cannot open", verbosity=>4 ); };
    die;
};
die;
