requires 'Type::Tiny', '2.000000';
requires 'kura', '0.03';
requires 'Syntax::Keyword::Assert', '0.12';

on 'test' => sub {
    requires 'DBI';
    requires 'DBD::SQLite';
    requires 'Test2::V0';
    requires 'DBIx::Tracer';
};
