#!/usr/bin/perl -l -I../lib

use strict;
use warnings;

use Exception::Base ':all',
    'Exception::Eval';#, verbosity=>3;

#$SIG{__DIE__} = sub { *__ANON__ = '__DIE__'; die $_[0]->stringify(3) if not $^S; die $_[0] }; #Exception::Die->throw(verbosity=>4); };
use Exception::Died;

eval {
    eval { open my $file, "<", "/badmodeexample" or Exception::Eval->throw(message=>"cannot open", verbosity=>4); };
    print ref $@;
    #throw if $@;
    print "*** $@ ***\n";
    #die $@;
    die;
};
print ">>> ", ref $@, " <<<\n";
die "akuku";
#die;
