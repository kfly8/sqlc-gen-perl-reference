BEGIN {
    # enable Strict mode for Syntax::Keyword::Assert
    $ENV{PERL_STRICT} = 1;
}

use lib 't/lib';
use Test::MyQuery;
Test::MyQuery->runtests;
