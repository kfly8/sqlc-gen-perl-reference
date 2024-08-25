use Test2::V0;

use MyDB;

subtest 'Test Queries' => sub {
    setup();

    my $data = { name => 'John Doe', bio => 'A mysterious' };

    my $dbh = connect_db();
    my $q = MyDB->new($dbh);

    $q->CreateAuthor($data);

    my $authors = $q->ListAuthors();
    is $authors, [ { id => 1, %$data } ], 'ListAuthors';

    my $author = $q->GetAuthor(1);
    is $author, { id => 1, %$data }, 'GetAuthor';

    $q->DeleteAuthor(1);
    $author = $q->GetAuthor(1);
    is $author, undef, 'DeleteAuthor';

    teardown();
};

subtest 'Test SQL' => sub {
    setup();

    my $SQL;
    require DBIx::Tracer;
    my $tracer = DBIx::Tracer->new(sub {
        my (%args) = @_;
        $SQL = $args{sql};
    });

    my $dbh = connect_db();
    my $q = MyDB->new($dbh);
    $q->ListAuthors();

    like $SQL, qr[-- name: ListAuthors], 'SQL includes method name';
    like $SQL, qr[-- called at t/basic.t line 40], 'SQL includes caller info';

    teardown();
};

subtest 'Test Models' => sub {
    use MyDB qw( Author CreateAuthorParams );

    isa_ok Author, 'Type::Tiny';
    my $author = { id => 1, name => 'John Doe', bio => 'A mysterious' };
    ok Author->check($author);
    ok !Author->check({ id => 'a', name => 'John Doe', bio => 'A mysterious' });

    isa_ok CreateAuthorParams, 'Type::Tiny';
    my $params = { name => 'John Doe', bio => 'A mysterious' };
    ok CreateAuthorParams->check($params);
    ok !CreateAuthorParams->check({ bio => 'A mysterious' });
};

# Test Helpers
sub setup {
    my $dbh = connect_db();
    open my $fh, '<', 'schema.sql';
    my $schema = do { local $/; <$fh> };
    $dbh->do($schema);
}

sub connect_db {
    require DBI;
    DBI->connect('dbi:SQLite:dbname=test.db', '', '');
}

sub teardown {
    unlink 'test.db';
}

done_testing;
