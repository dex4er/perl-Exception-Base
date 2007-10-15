#!/usr/bin/perl

use strict;
use warnings;

use lib 'inc', 'lib';

use Test::Unit::Lite;

use Exception::Base 'Exception::Warning';

local $SIG{__WARN__} = sub { Exception::Warning->throw(message => $_[0], ignore_level => 1) };

Test::Unit::HarnessUnit->new->start('Test::Unit::Lite::AllTests');
