write-host("Starting sqlcm2017 - nb. start elevated(?!)") -foregroundcolor green

$pwd = $env:dockersqlpwd

write-host("docker rm sqlcm2017") -foregroundcolor green
docker rm sqlcm2017

write-host("docker pull latest sql2017") -foregroundcolor green
docker pull mcr.microsoft.com/mssql/server:2017-latest

write-host("docker run sqlcm2017") -foregroundcolor green
docker run -e "ACCEPT_EULA=Y" -e ("SA_PASSWORD={0}" -f $pwd) `
   -p 1733:1433 --name sqlcm2017 `
   -d mcr.microsoft.com/mssql/server:2017-latest

write-host("docker start sqlcm2017") -foregroundcolor green
docker start sqlcm2017

write-host("docker ps -a show active processes") -foregroundcolor green
docker ps -a

write-host("docker log {CONTAINERID} shows logs from docker if needed") -foregroundcolor green


write-host("test-netconnection localhost -port 1733") -foregroundcolor green
tnc localhost -port 1733