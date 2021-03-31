write-host("docker start sql2017") -foregroundcolor green
docker start sql2017

write-host("docker ps -a show active processes") -foregroundcolor green
docker ps -a

write-host("docker logs {CONTAINERID} shows logs from docker if needed") -foregroundcolor green

write-host("test-netconnection localhost -port 1733") -foregroundcolor green
tnc localhost -port 1733