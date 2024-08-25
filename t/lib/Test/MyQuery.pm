package Test::MyQuery;
use strict;
use warnings;

use parent qw(Test::Class);
use Test2::V0;
use DBI;
use MyQuery;

sub create_schema : Test(setup) {
    my $dbh = connect_db();
    open my $fh, '<', 'schema.sql';
    my $schema = do { local $/; <$fh> };
    $dbh->do($schema);
}

sub drop_schema : Test(teardown) {
    unlink 'test.db';
}

sub test_queries : Tests {
    my $data = { name => 'John Doe', bio => 'A mysterious' };

    my $dbh = connect_db();
    my $q = MyQuery->new($dbh);

    $q->CreateAuthor($data);

    my $authors = $q->ListAuthors();
    is $authors, [ { id => 1, %$data } ], 'ListAuthors';

    my $author = $q->GetAuthor(1);
    is $author, { id => 1, %$data }, 'GetAuthor';

    $q->DeleteAuthor(1);
    $author = $q->GetAuthor(1);
    is $author, undef, 'DeleteAuthor';
}

sub test_sql : Tests {
    my $SQL;
    require DBIx::Tracer;
    my $tracer = DBIx::Tracer->new(sub {
        my (%args) = @_;
        $SQL = $args{sql};
    });

    my $dbh = connect_db();
    my $q = MyQuery->new($dbh);
    $q->ListAuthors();

    like $SQL, qr[-- name: ListAuthors], 'SQL includes method name';
    like $SQL, qr[-- called at t/lib/Test/MyQuery.pm line 50], 'SQL includes caller info';
}

sub test_models : Tests {
    use MyQuery qw( Author CreateAuthorParams );

    isa_ok Author, 'Type::Tiny';
    my $author = { id => 1, name => 'John Doe', bio => 'A mysterious' };
    ok Author->check($author);
    ok !Author->check({ id => 'a', name => 'John Doe', bio => 'A mysterious' });
}

sub test_strict_mode : Tests {
    use Devel::StrictMode;

    my $dbh = connect_db();
    my $q = MyQuery->new($dbh);

    my $illegal_params = { naaame => 'John' };

    if (STRICT) {
        # Not query invalid data
        like dies {
            $q->CreateAuthor($illegal_params);
        }, qr[Assertion failed at t/lib/Test/MyQuery.pm];
    }
    else {
        # Query invalid data
        ok warning {
            like dies {
                $q->CreateAuthor($illegal_params);
            }, qr[NOT NULL constraint failed: authors.name];
        };
    }
}

# Tests helper
sub connect_db {
    DBI->connect('dbi:SQLite:dbname=test.db', '', '');
}

1;
