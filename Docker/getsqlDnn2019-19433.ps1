write-host("Starting sqldnn2019 - nb. start elevated(?!)") -foregroundcolor green

$pwd = $env:cmbackuptst

write-host("docker rm sqldnn2019") -foregroundcolor green
docker rm sqldnn2019

write-host("docker pull latest sql2019") -foregroundcolor green
docker pull mcr.microsoft.com/mssql/server:2019-latest

write-host("docker run sqldnn2019") -foregroundcolor green
docker run -e "ACCEPT_EULA=Y" -e ("SA_PASSWORD={0}" -f $pwd) `
   -p 19433:1433 --name sqldnn2019 `
   -d mcr.microsoft.com/mssql/server:2019-latest

write-host("docker start sqldnn2019") -foregroundcolor green
docker start sqldnn2019

write-host("docker ps -a show active processes") -foregroundcolor green
docker ps -a

write-host("docker log {CONTAINERID} shows logs from docker if needed") -foregroundcolor green


write-host("test-netconnection localhost -port 19433") -foregroundcolor green
tnc localhost -port 19433