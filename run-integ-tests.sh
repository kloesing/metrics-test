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
git clone https://git.torproject.org/metrics-web
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

printf -- '\033[0mReplacing absolute paths in build.xml with relative paths...\n\033[37m';
sed -i.bak 's/.srv.metrics.torproject.org.metrics/./' build.xml

printf -- '\033[0mExtracting libraries, test descriptors, and expected .csv files...\n\033[37m';
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
createdb userstats
createdb tordir
createdb totalcw
createdb webstats
createdb onionperf
createdb ipv6servers

printf -- '\033[0mInitializing databases...\n\033[37m';
psql -f src/main/sql/clients/init-userstats.sql userstats
psql -f src/main/sql/bwhist/tordir.sql tordir
psql -f src/main/sql/totalcw/init-totalcw.sql totalcw
psql -f src/main/sql/webstats/init-webstats.sql webstats
psql -f src/main/sql/onionperf/init-onionperf.sql onionperf
psql -f src/main/sql/servers/init-ipv6servers.sql ipv6servers

printf -- '\033[0mRunning the connbidirect module...\n\033[37m';
ant connbidirect

printf -- '\033[0mRunning the onionperf module...\n\033[37m';
ant onionperf

printf -- '\033[0mRunning the bwhist module...\n\033[37m';
ant bwhist

printf -- '\033[0mRunning the advbwdist module...\n\033[37m';
ant advbwdist

printf -- '\033[0mRunning the hidserv module...\n\033[37m';
ant hidserv

printf -- '\033[0mRunning the clients module...\n\033[37m';
ant clients

printf -- '\033[0mRunning the servers module...\n\033[37m';
ant servers

printf -- '\033[0mRunning the webstats module...\n\033[37m';
ant webstats

printf -- '\033[0mRunning the totalcw module...\n\033[37m';
ant totalcw

printf -- '\033[0mGathering all generated .csv files...\n\033[37m';
ant make-data-available

printf -- '\033[0mComparing expected to generated .csv files...\n\033[37m';
diff -Nur ../expected shared/stats

printf -- '\033[0mTerminating...\n';

