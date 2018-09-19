# CoProD
A Configuration-Aware Performance Modeling Framework

# Script Usage
1. Each project should have a separate copy of the data processing script
2. There are three major scripts, for example, in the Apache project, you will use
**oneTouch.sh** which calls the following scripts
* apacheGo.sh to get the single option ranking
* apachePairWiseDriver.sh to get the configuration interaction ranking
* buildPerfModel.sh to get the final performance prediction model

# Deployment Procedure
1. Get the latestes scripts
2. Build test subject with debug symbols
3. Compile the latest pintool
4. Compile the latest java code
5. ACST, for coverage array
5. Test run

# Trouble Shooting
1. Make sure to check globalVar.sh
2. Compile the test subject on the deployment machine, make sure to build with debug symbols (-g)
3. Check the filter options on the instrumentation level and on the post processing script level
4. If you don't see output from pin, make sure the subject program has debug symbols in it.
Also, check the source code fileter (G_S_FILTER) in global.var

# Building
1. How to build Apache dynamic shared object (DSO)
http://httpd.apache.org/docs/current/programs/apxs.html
http://httpd.apache.org/docs/2.2/dso.html
http://httpd.apache.org/docs/current/dso.html

Current options pass to ./configure
--enable-debug --with-mpm=prefork  --with-ldap 
--enable-mods-shared="all ssl ldap cache proxy authn_alias mem_cache file_cache authnz_ldap charset_lite dav_lock disk_cache"

*Extra libraries needed for building: ldap, ssl 
* This configuration seems to enable the minimum modules and you have to LoadModule each one from httpd.config

Notice that for the "-c" option, you should provide the full path to the module source code. 
For instance, "-c mod_deflate.c" would not work in most cases except maybe inside the root directory of mod_deflatte.c.
But "-c apacheRoot/modules/filters/mod_deflate.c" would work.
Notice also, the modules are under the "modules" folder under where you put the apache root folder. 
IMPORTANT!!
* make sure in srclib/apr/apr-1-config file, LDFLAGS is set to:  LDFLAGS="-lz" before building 
Verify this by check the apr-1-config file in the bin folder. Look for LDFLAGS. And it should be LDFLAGS="-lz";
* How to check if deflate is enabled?
curl -I -H 'Accept-Encoding: gzip,deflate' 192.168.56.101
The returned header should contain: Content-Encoding: gzip

2. Static build of mod_deflate
./configure --prefix=/home/x/PlayGround/httpd-2.2.2/INSTALL --enable-module=prefork --enable-deflate
* if configure complains about can not locate zlib, intall zlib by: sudo "apt-get install libghc-zlib-dev" and "zlib1g-dev"
* list files installed from package name (also can be used to tell if a package is installed at all)
dpkg -L zlib1g-dev

To enable most modules compiled statically, use "--enable-modules=most"

-----------Build Postgresql----------
1. Install readline
sudo apt-get update
sudo apt-get install libreadline6 libreadline6-dev

Reference: https://linuxprograms.wordpress.com/2010/10/19/install-readline-linux/

To build without readline library (not recommended)
./configure --prefix=$(pwd)/SETUP --enable-debug --without-readline

2. Run configure
2.1. Create a installation folder (e.g. SETUP) to use with --prefix
Otherwise, the default installation folder is /usr/local/pgsql
2.2. ./configure --prefix=/home/x/PlayGround/pin-2.14-71313-gcc.4.4.7-linux/source/tools/ManualExamples/TestSubjects/postgresql-9.6.2/SETUP --enable-debug
3. make
4. make install
5. cd SETUP
6. mkdir data
Check INSTALL on the "Getting Started" section
7. bin/initdb -D "$(pwd)/data"
8. Run the command printed on the screen to start the db server
e.g.: bin/pg_ctl -D /home/x/PlayGround/pin-2.14-71313-gcc.4.4.7-linux/source/tools/ManualExamples/TestSubjects/postgresql-9.6.2/SETUP/data -l logfile start
9. Create DB: bin/createdb testDB
10. Test DB: bin/psql testDB
11. Regression test perl scripts
./src/bin/pg_ctl/t
src/test/regress/
12. Restore DB from an SQL dump
create the data base first if it does not exist, then
psql dbName < sqlDumpFile
13. Query a table (don't forget the tailing semi-colon)
select * from tableName;
To stop a server running in the background you can type:
  kill `cat $(pwd)/data/postmaster.pid`

Also, ./bin/psql --help will show the available commands
For example, to list databases: psql -l
to connect to a database: psql yourDbName

Once inside a DB, you could try the following commands
The query command is case sensitive
SELECT version();

To issue a command line query against a databse
./bin/psql -c 'SELECT version();' -d testDB

Configuration file location
$yourInstallDir/data/postgresql.conf

To find the location of your configuration file
./bin/psql -c 'SHOW CONFIG_FILE' -d yourDbName

To get sample database
http://pgfoundry.org/projects/dbsamples/

Reload configuration settings
-D: location of the database storage area
./bin/pg_ctl reload -D data/

NOTE
Because postgresql cannot be started as root, you need to run pin without sudo.
Also start the database in the background.

TO UPDATE
update city set population = 10 where name = 'Shanghai'
To list talbes
\dt

To create multiple instances
1. initdb -D pathToDataDb2
2. Modify postgres.config to change the port number
3. postgres -D pathToDataDb2 -p portNum

------------BUILD LIGHTTPD------------
1. export CFLAGS=-g

Build without pbzip2 and pcre
2. ./configure --prefix=$(pwd)/SETUP --without-pcre --without-bzip2
3. make
4. make install
5. Create/Download configuration file (https://redmine.lighttpd.net/projects/1/wiki/TutorialConfiguration)
6. Create htdocs, conf, and logs folder
7. Modify configuration file for htdocs, logs, and port, accesslog.filename
8. Test configuration syntax
lighttpd -t -f lighttpd.conf
8. Start server (-D prevents the server to run in the background)
./sbin/lighttpd -D -f conf/lighttpd.conf
9. Request a page

------------WEKA-------------
1. Put Weka.jar in $PATH (I think it does not matter, a classpath for java should be set instead)
2. Run java -cp weka.jar weka.classifiers.trees.J48 -t data/weather.numeric.arff -i
3. Convert CSV (with header) to arff using the converter class
java -cp weka.jar weka.core.converters.CSVLoader yourCsvDataFile > yourConverted.arff
To start Weka UI: java -cp weka.jar weka.gui.GUIChooser
4. How to load and evaluate data on a saved model?
Right click load model in the "Result list", load test data from "Supplied test set", then, right click
on the model and select "Re-evaluate model on current test"


------------WEKA machine learning code-------------

1. javac -cp ./weka.jar *.java edu/uky/cs/testing/perfmodel/*.java


# HPC Scripts
1. To queue a job:
sbatch scriptName
p.s. make sure inside your script you have #SBATCH to specify time, #ofCPC etc
2. To check queued jobs:
squeue -u yourUserName
3. To logon a queue
Once you check the running jobs with squeue, find out the node name.
It might be something like: cnode238
Then, use "ssh cnode238" to logon
4. To cancel a job
scancel job_id
5. To check the queue info
queue_wcl
6. Review a pending job's status
checkjob -v job_id
7. load java
module load java/1.8.0_66

