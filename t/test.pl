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

local $SIG{__WARN__} = sub { $@ = $_[0]; Exception::Warning->throw(message => 'Warning', ignore_level => 1) };

all_tests;
