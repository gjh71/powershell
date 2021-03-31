docker exec -it sql1 /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P 'Gewel3biCo!' -Q 'ALTER LOGIN SA WITH PASSWORD="R1GGUV#w68p"'

docker exec -it sql1 "bash"
# /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P 'R1GGUV#w68p'