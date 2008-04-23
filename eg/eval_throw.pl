#!/usr/bin/perl -l -I../lib

use strict;
use warnings;

use Exception::Base ':all',
    'Exception::Eval', 'Exception::Die';

$SIG{__DIE__} = sub { *__ANON__ = '__DIE__'; die $_[0]->stringify(4) if not $^S; die $_[0] }; #Exception::Die->throw(verbosity=>4); };

eval { open my $file, "<", "/badmodeexample" or Exception::Eval->throw(message=>"cannot open", verbosity=>4); };
print ref $@;
#throw if $@;
print "*** $@ ***\n";
die $@->stringify(4);
