write-host("docker start sql2019") -foregroundcolor green
docker start sql2019

write-host("docker ps -a show active processes") -foregroundcolor green
docker ps -a

write-host("docker logs {CONTAINERID} shows logs from docker if needed") -foregroundcolor green

write-host("test-netconnection localhost -port 1933") -foregroundcolor green
tnc localhost -port 1933
