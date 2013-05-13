
#### how to compile SQLite3 to be used with tagnotes:

go to:
http://www.sqlite.org/download.html

download:
sqlite-autoconf-3071601.tar.gz (1.77 MiB) 	

compile:
CFLAGS="-Os -DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS3_PARENTHESIS=1 -DSQLITE_ENABLE_FTS4=1" ./configure && sudo make install


#### how to compile ruby to be used with tagnotes:

go to:
www.rubyenterpriseedition.com

compile:
sudo ./installer --no-tcmalloc --no-dev-docs -c --enable-pthread


#### how to get started:

first create a database:
$ ruby dbdrive.rb createdb my.db

now start the program:
$ ruby tcl.rb

warning: always start the program from the same directory where it's in.