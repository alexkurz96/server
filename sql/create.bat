rem new db
rem psql -U postgres -c "CREATE DATABASE linkhub;"
"c:\Program Files\PostgresPro\10\bin\psql" -U postgres -c "SET CLIENT_ENCODING TO 'utf8'" -f create/database.sql
rem roles
"c:\Program Files\PostgresPro\10\bin\psql" -U postgres -d linkhub -c "SET CLIENT_ENCODING TO 'utf8'" -f temp/create.sql
rem DDL: END!
Pause
