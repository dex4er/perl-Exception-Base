package Exception::BaseTest::LoadedException;

our $VERSION = 0.01;

use Exception::Base
    'Exception::BaseTest::LoadedException' => {
        has => ['myattr'],
    };

1;
