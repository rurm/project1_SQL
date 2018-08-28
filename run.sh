#!/bin/sh
export POSGRES_HOST=localhost
export POSGRES_PORT=12345

# Создание docker контейра c postgres
echo '********** Создание docker контейнера **********'
sudo docker-compose --project-name postgres-db -f ./docker/docker-compose.yml up --build -d

# Загрузка данных в контейнер
echo '********** Загружаем данные в БД **********'
./scripts/load_data.sh ./data/ $POSGRES_HOST $POSGRES_PORT

# Выполнение SQL запросов
echo '********** Выполняем запросы в БД **********'
psql --host $POSGRES_HOST --port $POSGRES_PORT -U postgres -a -f ./scripts/worker1.sql

# Выполнение python запросов
export PANDAS_EXPORT_FOLDER="$PWD/output/"
jupyter-notebook ./scripts/worker2.ipynb

