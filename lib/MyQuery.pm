package MyQuery;
use strict;
use warnings FATAL => 'all';
use utf8;
use feature qw(state);

use Carp ();
use Syntax::Keyword::Assert;
use Types::Standard ();
use Devel::StrictMode;

sub new {
    my ($class, $dbh) = @_;
    assert { (Types::Standard::InstanceOf['DBI::db'])->check($dbh) };
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

sub __error_message {
    my ($self, %args) = @_;

    my $subname   = $args{subname};
    my $type      = $args{type};
    my $typename  = $args{typename};
    my $params    = $args{params};
    my $usage     = $args{usage};

    my $subject = 'error: invalid parameters';

    # Dictの場合
    # - 期待のキーが存在しない
    # - キーの型が違う
    # - キーが余分
    # - [x] そもそもハッシュでない

    my $code_template = "\$q->$subname(%s)";

    state $detect_reason;
    $detect_reason //= sub {
        my %args = @_;
        my $typename = $args{typename};
        my $type     = $args{type};
        my $params   = $args{params};

        if ($type->is_a_type_of('Dict')) {
            if ((ref $params||'') eq 'HASH') {
                ...
            }
            else {
                my $plen = length $params;
                my $code = sprintf($code_template, $params);
                my $indent = " " x ( (length $code) - ($plen) - 1 );
                my $seek = '^' x $plen;
                return "$code\n$indent$seek expected `$typename`, but got `@{[ $params ]}`";
            }
        }
        else {
            ...
        }
    };

    my $reason = $detect_reason->(
        typename => $typename,
        type     => $type,
        params   => $params,
    );

    #$reason .= "\n\n$reason";

    my $indent = " " x 2;
    $reason =~ s/\n/\n$indent/g;
    $usage =~ s/\n/\n$indent/g;

    return "$subject

  $reason

  Usage:
    $usage
"
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
    my $self = shift;
    my $params = @_ == 1 ? $_[0] : { @_ };
    STRICT && do {
        unless (CreateAuthorParams->check($params)) {
            my $usage = <<USAGE;
\$q->CreateAuthor(
    name => Str,
    bio => Str,
)
USAGE
            Carp::croak $self->__error_message(
                subname      => 'CreateAuthor',
                typename     => 'CreateAuthorParams',
                type         => CreateAuthorParams,
                params       => $params,
                usage        => $usage,
            )
        }
    };

    my $sth = $self->dbh->prepare($self->__set_comment($CreateAuthor));
    my @bind = ($params->{name}, $params->{bio});
    my $ret = $sth->execute(@bind) or Carp::croak $sth->errstr;
    return $ret;
}

my $DeleteAuthor = q{-- name: DeleteAuthor :exec
DELETE FROM authors
WHERE id = ?
};

sub DeleteAuthor {
    my ($self, $id) = @_;
    assert { Types::Standard::Int->check($id) };

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
    assert { Types::Standard::Int->check($id) };

    my $sth = $self->dbh->prepare($self->__set_comment($GetAuthor));
    my @bind = ($id);
    my $ret = $sth->execute(@bind) or Carp::croak $sth->errstr;

    my $row = $ret && $sth->fetchrow_hashref;
    return unless $row;

    assert { Author->check($row) };
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

    assert { (Types::Standard::ArrayRef[Author])->check($rows) };
    return $rows;
}

my $CountAuthors = q{-- name: CountAuthors :one
SELECT count(*) FROM authors
};

sub CountAuthors {
    my ($self) = @_;

    my $sth = $self->dbh->prepare($self->__set_comment($CountAuthors));
    my $ret = $sth->execute() or Carp::croak $sth->errstr;

    my $row = $ret && $sth->fetchrow_arrayref;
    return unless $row;

    assert { Types::Standard::Int->check($row->[0]) };
    return $row->[0];
}

my $CountAuthorsByName = q{-- name: CountAuthorsByName :many
SELECT name , count(*) AS count FROM authors
GROUP BY name
ORDER BY count
};

use kura CountAuthorsByNameRow => Types::Standard::Dict[
    name => Types::Standard::Str,
    count => Types::Standard::Int,
];

sub CountAuthorsByName {
    my ($self) = @_;

    my $sth = $self->dbh->prepare($self->__set_comment($CountAuthorsByName));
    my $ret = $sth->execute() or Carp::croak $sth->errstr;

    my $rows = $ret && $sth->fetchall_arrayref({});

    assert { (Types::Standard::ArrayRef[CountAuthorsByNameRow])->check($rows) };
    return $rows;
}

1;
