package TestMyQuery;
use strict;
use warnings;

use parent qw(Test::Class);

use Test2::V0;
use DBI;
use MyQuery;
use Devel::StrictMode;

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
    like $SQL, qr[-- called at t/lib/TestMyQuery.pm line 52], 'SQL includes caller info';
}

sub test_models : Tests {
    use MyQuery qw( Author CreateAuthorParams );

    isa_ok Author, 'Type::Tiny';
    my $author = { id => 1, name => 'John Doe', bio => 'A mysterious' };
    ok Author->check($author);
    ok !Author->check({ id => 'a', name => 'John Doe', bio => 'A mysterious' });
}

sub test_error_message : Tests {
    my $dbh = connect_db();
    my $q = MyQuery->new($dbh);

    if (!STRICT) {
        like dies { $q->CreateAuthor(123) }, qr{Can't use string \("123"\) as a HASH};
        return;
    }

    subtest "Given 123" => sub {
        my $err = dies { $q->CreateAuthor(123) };
        like $err, qr{
  .q\Q->CreateAuthor(123)\E
                   \Q^^^ expected `CreateAuthorParams`, but got `123`\E};
        note $err;
    };

    subtest "Given 'hello'" => sub {
        my $err = dies { $q->CreateAuthor('hello') };
        like $err, qr{
  .q\Q->CreateAuthor('hello')\E
                   \Q^^^^^^^ expected `CreateAuthorParams`, but got `'hello'`\E};
        note $err;

    };

    subtest "Given undef" => sub {
        my $err = dies { $q->CreateAuthor(undef) };
        like $err, qr{
  .q\Q->CreateAuthor(undef)\E
                   \Q^^^^^ expected `CreateAuthorParams`, but got `undef`\E};
        note $err;
    };

    subtest "Given ArrayRef" => sub {
        subtest 'single arrayref' => sub {
            my $err = dies { $q->CreateAuthor([123]) };
            like $err, qr{
  .q\Q->CreateAuthor([123])\E
                   \Q^^^^^ expected `CreateAuthorParams`, but got `ARRAY` reference\E};
            note $err;
        };

        subtest 'multi arrayref' => sub {
            my $err = dies { $q->CreateAuthor([123,456,789]) };
            like $err, qr{
  .q\Q->CreateAuthor([123,...])\E
                   \Q^^^^^^^^^ expected `CreateAuthorParams`, but got `ARRAY` reference\E};
            note $err;
        };
    };
}

# Tests helper
sub connect_db {
    DBI->connect('dbi:SQLite:dbname=test.db', '', '');
}

1;
