#!/usr/bin/perl

use strict;
use warnings;

use lib 'inc', 'lib';

use Test::Unit::Lite;

use Exception::Base 'Exception::Warning';

local $SIG{__WARN__} = sub { $@ = $_[0]; Exception::Warning->throw(message => 'Warning', ignore_level => 1) };

Test::Unit::HarnessUnit->new->start('Test::Unit::Lite::AllTests');
