#!/bin/sh
set -e

printf -- '-------------------------------------------------------------------\n';
printf -- 'Running metrics-web integration tests has the following effects:\n';
printf -- ' - The metrics-web/ subdirectory will be removed and recreated.\n';
printf -- ' - Any metrics-web related databases will be dropped and recreated.\n';
printf -- ' - This machine will be busy for up to one hour.\n';
printf -- '\033[31mDo *not* run this script on a production system!\033[0m\n';
printf -- '-------------------------------------------------------------------\n';

while true; do
    read -p "Are you sure you want to proceed (y/n)? " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit 1;;
        * ) echo "Please answer yes or no.";;
    esac
done

printf -- 'Cloning metrics-web Git repository into metrics-web/ subdirectory...\n\033[37m';
rm -rf metrics-web/
#git clone https://git.torproject.org/metrics-web
# In order to test another branch than master, use the following line:
#git clone --branch some-branch https://git.torproject.org/user/somebody/metrics-web
git clone --branch task-29696 https://git.torproject.org/user/karsten/metrics-web
cd metrics-web/

## Use some of the following to test an existing metrics-web clone.
#
#printf -- '\033[0mRemoving several directories not under version control...\n\033[37m';
#rm -rfv lib/ work/ generated/ shared/ expected/
#
#printf -- '\033[0mRemoving untracked files from the working tree...\n\033[37m';
#git clean -f

printf -- '\033[0mBootstrapping development environment...\n\033[37m';
src/main/resources/bootstrap-development.sh 

printf -- '\033[0mRemoving descriptor collection step...\n\033[37m';
sed -i.bak 's/.*collectdescs.*//' src/main/java/org/torproject/metrics/stats/main/Main.java

printf -- '\033[0mCopying libraries and test descriptors...\n\033[37m';
cp -a ../lib .
cp -a ../work .

printf -- '\033[0mGenerating a .jar file for execution...\n\033[37m';
ant jar

printf -- '\033[0mDropping any existing metrics-web related databases...\n\033[37m';
dropdb --if-exists userstats
dropdb --if-exists tordir
dropdb --if-exists totalcw
dropdb --if-exists webstats
dropdb --if-exists onionperf
dropdb --if-exists ipv6servers

printf -- '\033[0m(Re-)creating databases...\n\033[37m';
createdb --encoding=UTF8 --locale=C --template=template0 userstats
createdb --encoding=UTF8 --locale=C --template=template0 tordir
createdb --encoding=UTF8 --locale=C --template=template0 totalcw
createdb --encoding=UTF8 --locale=C --template=template0 webstats
createdb --encoding=UTF8 --locale=C --template=template0 onionperf
createdb --encoding=UTF8 --locale=C --template=template0 ipv6servers

printf -- '\033[0mInitializing databases...\n\033[37m';
psql -f src/main/sql/clients/init-userstats.sql userstats
psql -f src/main/sql/bwhist/tordir.sql tordir
psql -f src/main/sql/totalcw/init-totalcw.sql totalcw
psql -f src/main/sql/webstats/init-webstats.sql webstats
psql -f src/main/sql/onionperf/init-onionperf.sql onionperf
psql -f src/main/sql/servers/init-ipv6servers.sql ipv6servers

printf -- '\033[0mRunning modules...\n\033[37m';
java -DLOGBASE=work/modules/logs/ -Dmetrics.basedir=. -jar generated/dist/metrics-web-1.2.0-dev.jar
# If database user and password are not "metrics" and "password", use the following line:
#java -DLOGBASE=work/modules/logs/ -Dmetrics.basedir=. -Dmetrics.dbuser=dbuser -Dmetrics.dbpass=dbpass -jar generated/dist/metrics-web-1.2.0-dev.jar

printf -- '\033[0mComparing expected to generated .csv files...\n\033[37m';
diff -Nur ../expected shared/stats

printf -- '\033[0mTerminating...\n';

