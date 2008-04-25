#!/usr/bin/perl -d:DProf

use lib 'lib', '../lib';	
use Exception::Base ':all';

use Exception::Died;

foreach (1..10000) {
    eval { Exception::Base->throw(message=>'Message') };
    if ($@) {
	my $e = $@;
        if ($e->isa('Exception::Base') and $e->with('Message')) { 1; }
    }
}

print "tmon.out data collected. Call dprofpp\n";
