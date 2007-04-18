perl Makefile.PL
cover -delete
HARNESS_PERL_SWITCHES=-MDevel::Cover make test
cover
