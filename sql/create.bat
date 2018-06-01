rem new db
rem psql -U postgres -c "CREATE DATABASE linkhub;"
psql -U postgres -c "SET CLIENT_ENCODING TO 'utf8'" -f 0_database.sql
rem roles
psql -U postgres -d linkhub -c "SET CLIENT_ENCODING TO 'utf8'" -f 1_create.sql
rem DDL: END!
Pause
