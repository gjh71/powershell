write-host("Starting sqlcm2019 - nb. start elevated(?!)") -foregroundcolor green

$pwd = $env:dockersqlpwd

write-host("docker rm sqlcm2019") -foregroundcolor green
docker rm sqlcm2019

write-host("docker pull latest sql2019") -foregroundcolor green
docker pull mcr.microsoft.com/mssql/server:2019-latest

write-host("docker run sqlcm2019") -foregroundcolor green
docker run -e "ACCEPT_EULA=Y" -e ("SA_PASSWORD={0}" -f $pwd) `
   -p 1933:1433 --name sqlcm2019 `
   -d mcr.microsoft.com/mssql/server:2019-latest 
#   `
#   --mount type=bind,source="c:/wip/cm-docker",target="/var/opt/mssql"

write-host("docker start sqlcm2019") -foregroundcolor green
docker start sqlcm2019

write-host("docker ps -a show active processes") -foregroundcolor green
docker ps -a

write-host("docker log {CONTAINERID} shows logs from docker if needed") -foregroundcolor green


write-host("test-netconnection localhost -port 1933") -foregroundcolor green
tnc localhost -port 1933