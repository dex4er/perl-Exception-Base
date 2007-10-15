#!/usr/bin/perl

use strict;
use warnings;

use File::Basename ();

BEGIN {
    chdir File::Basename::dirname(__FILE__) or die "$!";
    chdir '..' or die "$!";
}

use lib 'inc', 'lib';

use Test::Unit::Lite;

use Exception::Base 'Exception::Warning';

local $SIG{__WARN__} = sub { Exception::Warning->throw(message => $_[0], ignore_level => 1) };

all_tests;
