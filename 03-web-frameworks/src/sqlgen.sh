#!/bin/bash

DBNAME=db.sqlite3

EXTRA=$1

SRC=$(realpath $(cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd ))

DB=file:$SRC/$DBNAME

XOBIN=$(which xo)
if [ -e $SRC/../../xo ]; then
  XOBIN=$SRC/../../xo
fi

DEST=$SRC/models

set -x

mkdir -p $DEST
rm -f $DEST/*.xo.go
rm -f $SRC/$DBNAME

sqlite3 $DB << 'ENDSQL'
PRAGMA foreign_keys = 1;

CREATE TABLE authors (
  author_id integer NOT NULL PRIMARY KEY,
  name text NOT NULL DEFAULT ''
);

CREATE INDEX authors_name_idx ON authors(name);

CREATE TABLE books (
  book_id integer NOT NULL PRIMARY KEY,
  author_id integer NOT NULL REFERENCES authors(author_id),
  isbn text NOT NULL DEFAULT '' UNIQUE,
  title text NOT NULL DEFAULT '',
  year integer NOT NULL DEFAULT 2000,
  available text NOT NULL DEFAULT '',
  tags text NOT NULL DEFAULT '{}'
);

CREATE INDEX books_title_idx ON books(title, year);

ENDSQL

$XOBIN $DB -o $SRC/models $EXTRA

$XOBIN $DB -a -N -M -B -T Author -o $SRC/models $EXTRA << ENDSQL
SELECT
  a.author_id,
  a.name
FROM authors a
ENDSQL

$XOBIN $DB -N -M -B -T AuthorBookResult --query-type-comment='AuthorBookResult is the result of a search.' -o $SRC/models $EXTRA << ENDSQL
SELECT
  a.author_id,
  a.name AS author_name,
  b.book_id,
  b.isbn AS book_isbn,
  b.title AS book_title,
  b.tags AS book_tags
FROM books b
JOIN authors a ON a.author_id = b.author_id
WHERE b.tags LIKE '%' || %%tag string%% || '%'
ENDSQL

pushd $SRC &> /dev/null

go build ./models

sqlite3 $DB << ENDSQL
insert into authors (name) values ('paul simmons');
ENDSQL

sqlite3 $DB << ENDSQL
.headers on
.mode column
.width 10 20
select * from authors;
ENDSQL

popd  &> /dev/null
