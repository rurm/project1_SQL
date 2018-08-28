#!/bin/sh
# How to run ./load_data.sh FOLDER_WITH_SOURCE_DATASET POSGRES_HOST POSGRES_PORT
FOLDER_WITH_SOURCE_DATASET=$1
POSGRES_HOST=$2
POSGRES_PORT=$3

MOVIES_FILEPATH="$FOLDER_WITH_SOURCE_DATASET./movies.csv"
RATINGS_FILEPATH="$FOLDER_WITH_SOURCE_DATASET./ratings.csv"
LINKS_FILEPATH="$FOLDER_WITH_SOURCE_DATASET./links.csv"
KEYWORDS_FILEPATH="$FOLDER_WITH_SOURCE_DATASET./keywords.csv"

echo "Очистка памяти от таблиц (если они существуют)"
psql --host $POSGRES_HOST  --port $POSGRES_PORT -U postgres -c \
    "DROP TABLE IF EXISTS links"
psql --host $POSGRES_HOST  --port $POSGRES_PORT -U postgres -c \
    "DROP TABLE IF EXISTS ratings"
psql --host $POSGRES_HOST  --port $POSGRES_PORT -U postgres -c \
    "DROP TABLE IF EXISTS keywords"
psql --host $POSGRES_HOST  --port $POSGRES_PORT -U postgres -c \
    "DROP TABLE IF EXISTS movies"

echo "Загружаем \"$LINKS_FILEPATH\""
psql --host $POSGRES_HOST --port $POSGRES_PORT -U postgres -c '
  CREATE TABLE IF NOT EXISTS links (
    movieId bigint,
    imdbId varchar(20),
    tmdbId varchar(20)
  );'

psql --host $POSGRES_HOST --port $POSGRES_PORT -U postgres -c \
    "\\copy links FROM '$LINKS_FILEPATH' DELIMITER ',' CSV HEADER"

echo "Загружаем \"$RATINGS_FILEPATH\""
psql --host $POSGRES_HOST --port $POSGRES_PORT -U postgres -c '
  CREATE TABLE IF NOT EXISTS ratings (
    userId bigint,
    movieId bigint,
    rating float(25),
    timestamp bigint
  );'

psql --host $POSGRES_HOST --port $POSGRES_PORT -U postgres -c \
    "\\copy ratings FROM '$RATINGS_FILEPATH' DELIMITER ',' CSV HEADER"

echo "Загружаем \"$KEYWORDS_FILEPATH\""
psql --host $POSGRES_HOST --port $POSGRES_PORT -U postgres -c '
  CREATE TABLE IF NOT EXISTS keywords (
    id  bigint,
    tags text
  );'

psql --host $POSGRES_HOST --port $POSGRES_PORT -U postgres -c \
    "\\copy keywords FROM '$KEYWORDS_FILEPATH' DELIMITER ',' CSV HEADER"

echo "Загружаем \"$MOVIES_FILEPATH\""
psql --host $POSGRES_HOST --port $POSGRES_PORT -U postgres -c '
  CREATE TABLE IF NOT EXISTS movies (
    id	bigint,
    imdbId	text,
    title	text,
    release bigint,
    runtime	real,
    budget	bigint,
    revenue bigint,
    popularity real,
    vote_average real,
    vote_count bigint
  );'

psql --host $POSGRES_HOST --port $POSGRES_PORT -U postgres -c \
    "\\copy movies FROM '$MOVIES_FILEPATH' DELIMITER ',' CSV HEADER"

#psql --host $POSGRES_HOST --port $POSGRES_PORT -U postgres -a -f home/worker.sql

