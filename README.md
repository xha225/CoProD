# CoProD
Performance modeling
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
