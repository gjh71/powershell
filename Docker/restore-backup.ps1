docker exec -it sqlcm2019 mkdir /var/opt/mssql/backup
# curl -OutFile "wwi.bak" "https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Full.bak"

docker cp C:\wip\cm-docker\cm-db01-test_CowManager_FULL_20200209_013007.bak sqlcms2019:/var/opt/mssql/backup