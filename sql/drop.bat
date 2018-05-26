psql -U postgres -c "DROP DATABASE linkhub;"
psql -U postgres -c "SET CLIENT_ENCODING TO 'utf8'" -f drop/_drop.sql
Pause