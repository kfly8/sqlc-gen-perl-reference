requires 'Type::Tiny', '2.000000';
requires 'kura', '0.03';
requires 'Devel::StrictMode', '0.003';

on 'test' => sub {
    requires 'DBI';
    requires 'DBD::SQLite';
    requires 'DBIx::Tracer';

    requires 'Test2::V0';
    requires 'Test::Class';
};
