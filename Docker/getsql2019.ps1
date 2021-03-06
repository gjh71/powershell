write-host("Starting sql2019 - nb. start elevated(?!)") -foregroundcolor green

$pwd = $env:cmbackuptst

write-host("docker rm sql2019") -foregroundcolor green
docker rm sql2019

write-host("docker pull latest sql2019") -foregroundcolor green
docker pull mcr.microsoft.com/mssql/server:2019-latest

write-host("docker run sql2019") -foregroundcolor green
docker run -e "ACCEPT_EULA=Y" -e ("SA_PASSWORD={0}" -f $pwd) `
   -p 1433:1433 --name sql2019 `
   -d mcr.microsoft.com/mssql/server:2019-latest

write-host("docker start sql2019") -foregroundcolor green
docker start sql2019

write-host("docker ps -a show active processes") -foregroundcolor green
docker ps -a

write-host("docker logs {CONTAINERID} shows logs from docker if needed") -foregroundcolor green


write-host("test-netconnection localhost -port 1433") -foregroundcolor green
tnc localhost -port 1433