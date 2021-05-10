# https://gist.github.com/dpmex4527/1d702357697162384d31d033a7d505eb

docker volume create svn-root
docker run -dit --name svn-server -v svn-root:/home/svn -p 7443:80-p 3960:3960 -w /home/svn elleflorio/svn-server
docker exec -t svn-server htpasswd -b /etc/subversion/passwd svnadmin Pass1Word!

# the following statement should give errors:
# svn: E170013: Unable to connect to a repository at URL 'svn://localhost:3960'
# svn: E210002: Network connection closed unexpectedly
svn info svn://localhost:3960/

# login using http://localhost:7443/svn

docker exec -it svn-server svnadmin create Test
docker exec -it svn-server ls -al Test

# load svn repo
docker exec -it svn-server sh -c "svnrdump dump https://svn.code.sf.net/p/ultrastardx/svn | gzip > /tmp/ultrastardx.dump.gz"

docker exec -it svn-server svnadmin create sensor-svn-docker

docker cp C:\tmp\SensOor.2020-06-16_1900.svn_dump svn-server:/tmp/

docker exec -it svn-server sh -c "SensOor.2020-06-16_1900.svn_dump | svnadmin load sensor-svn-docker"

svn info svn://localhost:3960/ultrastardx

###
docker run -dit --name svn-server -v svn-root:/home/svn -p 3960:3960 -w /home/svn elleflorio/svn-server
docker exec -t svn-server htpasswd -b /etc/subversion/passwd svnadmin Pass1Word!
svn info svn://localhost:3960/

docker exec -it svn-server svnadmin create Test
docker exec -it svn-server ls -al Test

docker exec -it svn-server svnadmin create sensor-svn-foxpro
docker cp C:\temp\FoxPro.2020-06-16_1900.svn_dump.gz svn-server:/tmp/
