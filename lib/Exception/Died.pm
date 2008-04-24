package Exception::Died;
our $VERSION = 0;
use base 'Exception::Base';
sub __DIE__ {
    if (not $^S) {
	if (ref $_[0]) {
	    die $_[0]->stringify;
	}
	else {
	    my $old = $_[0];
	    $old =~ s/( at (?!.*\bat\b.*).* line \d+( thread \d+)?\.)?\n$//s;
	    my $e = Exception::Died->new();
	    $e->{eval_error} = $old;
	    die $e->stringify;
	}
    }
    if (not ref $_[0]) {
	$@ = $_[0];
	Exception::Died->throw;
    }
    die $_[0];
}
$SIG{__DIE__} = \&__DIE__;

1;
