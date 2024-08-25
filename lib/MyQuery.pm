package MyQuery;
use strict;
use warnings;
use utf8;

use Carp ();
use Types::Standard ();
use Devel::StrictMode;

sub new {
    my ($class, $dbh) = @_;
    STRICT && do {
        Carp::croak "Usage: MyQuery->new(\$dbh)" unless (Types::Standard::InstanceOf['DBI::db'])->check($dbh)
    };
    bless [$dbh], $class;
}

sub dbh { $_[0][0] }

# copy from DBIx::Sunny. thanks!
our $SKIP_CALLER_REGEX = qr/^(:?DBIx?|DBD|Try::Tiny|Context::Preserve)\b/;
sub __set_comment {
    my $self = shift;
    my $query = shift;

    my $trace;
    my $i = 0;
    while ( my @caller = caller($i) ) {
        my $file = $caller[1];
        $file =~ s!\*/!*\//!g;
        $trace = "-- called at $file line $caller[2]";
        last if $caller[0] ne ref($self) && $caller[0] !~ $SKIP_CALLER_REGEX;
        $i++;
    }
    $query =~ s!\n!\n$trace\n!;
    $query;
}

# Define Models
use kura Author => Types::Standard::Dict[
  id => Types::Standard::Int,
  name => Types::Standard::Str,
  bio => Types::Standard::Str,
];

# Define Queries
my $CreateAuthor = q{-- name: CreateAuthor :exec
INSERT INTO authors (
  name, bio
) VALUES (
  ?, ?
)
};

use kura CreateAuthorParams => Types::Standard::Dict[
    name => Types::Standard::Str,
    bio => Types::Standard::Str,
];

sub CreateAuthor {
    my ($self, $arg) = @_;
    STRICT && do {
        Carp::croak "Usage: CreateAuthor(\$arg)" unless CreateAuthorParams->check($arg);
    };

    my $sth = $self->dbh->prepare($self->__set_comment($CreateAuthor));
    my @bind = ($arg->{name}, $arg->{bio});
    my $ret = $sth->execute(@bind) or Carp::croak $sth->errstr;
    return $ret;
}

my $DeleteAuthor = q{-- name: DeleteAuthor :exec
DELETE FROM authors
WHERE id = ?
};

sub DeleteAuthor {
    my ($self, $id) = @_;
    STRICT && do {
        Carp::croak "Usage: DeleteAuthor(\$id)" unless Types::Standard::Int->check($id);
    };

    my $sth = $self->dbh->prepare($self->__set_comment($DeleteAuthor));
    my @bind = ($id);
    my $ret = $sth->execute(@bind) or Carp::croak $sth->errstr;
    return $ret;
}

my $GetAuthor = q{-- name: GetAuthor :one
SELECT id, name, bio FROM authors
WHERE id = ? LIMIT 1
};

sub GetAuthor {
    my ($self, $id) = @_;
    STRICT && do {
        Carp::croak "Usage: GetAuthor(\$id)" unless Types::Standard::Int->check($id);
    };

    my $sth = $self->dbh->prepare($self->__set_comment($GetAuthor));
    my @bind = ($id);
    my $ret = $sth->execute(@bind) or Carp::croak $sth->errstr;

    my $row = $ret && $sth->fetchrow_hashref;
    return unless $row;

    STRICT && do {
        Carp::croak "Invalid row" unless Author->check($row);
    };
    return $row;
}

my $ListAuthors = q{-- name: ListAuthors :many
SELECT id, name, bio FROM authors
ORDER BY name
};

sub ListAuthors {
    my ($self) = @_;

    my $sth = $self->dbh->prepare($self->__set_comment($ListAuthors));
    my $ret = $sth->execute() or Carp::croak $sth->errstr;

    my $rows = $ret && $sth->fetchall_arrayref({});

    STRICT && do {
        Carp::croak "Invalid rows" unless (Types::Standard::ArrayRef[Author])->check($rows);
    };
    return $rows;
}

1;
