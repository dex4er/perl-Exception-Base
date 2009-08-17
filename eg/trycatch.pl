#!/usr/bin/perl

use 5.010;

use lib 'lib', '../lib';

use strict;
use warnings;

use Exception::Base;
use TryCatch;

use Moose::Util::TypeConstraints;
BEGIN { class_type 'Exception::Base'; };

try {
    Exception::Base->throw( message=>"something happened", value=>123, verbosity=>4 );
}
catch ( Exception::Base $e where { $_->value == 123 } ) {
    say $e->message;
};
