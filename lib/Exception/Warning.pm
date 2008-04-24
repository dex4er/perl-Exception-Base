package Exception::Warning;
our $VERSION = 0;
use base 'Exception::Base';
sub __WARN__ {
    $@ = $_[0];
    Exception::Warning->throw();
}
$SIG{__WARN__} = \&__WARN__;

1;
