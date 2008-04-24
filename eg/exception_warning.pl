#!/usr/bin/perl -l -I../lib

use strict;
use warnings;

use Exception::Base verbosity=>3;
use Exception::Warning;

eval {
    eval {
	warn "Simple warn";
    };
    print "Inner eval: ", ref $@;
    die;
};
print "Outer eval: ", ref $@;
die;
