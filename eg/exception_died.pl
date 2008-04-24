#!/usr/bin/perl -l -I../lib

use strict;
use warnings;

use Exception::Base verbosity=>3;
use Exception::Died;

eval {
    eval {
	die "Simple die";
    };
    print "Inner eval: ", ref $@;
    die;
};
print "Outer eval: ", ref $@;
die;
