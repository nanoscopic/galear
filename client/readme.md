Client Setup

The client has currently been setup and tested on OpenSUSE Tumbleweed.
It should work properly on many other operating systems and platforms, as nothing being used is specific to Linux.
Intentionally the libraries chosen are available on Windows and OSX as well.

Packages to install:

   * apache2
   * perl-PerkMagick ( ImageMagick module for Perl )
   * perl-DBD-SQLite ( SQLite for perl )
   * perl-image-ExifTool ( exif library for perl )
   * perl-XML-Bare ( XML library for perl )
   * nanomsg-devel ( nanomsg development libraries )

Packages to install via CPAN:

   * NanoMsg::Raw ( depedns on the nanomsg-devel library installed above )

How to get the system up and running:

   1. Configure Apache to serve .pl files as CGI perl scripts ( ensure lines below in /etc/apache2/httpd.conf )
       1. DirectoryIndex index.html index.pl
       1. AddHandler cgi-script .pl
   1. Add 'galclient' to /etc/hosts to point to localhost ( 127.0.0.1 )
       1. Eg: Add this line: "127.0.0.1    galclient"
   1. Copy etc/apache2/vhosts.d/galclient.conf to /etc/apache2/vhosts.d
   1. Restart Apache
       1. systemctl restart apache2
   1. Run the state engine ( in a shell, tmux, or setp as a service )
       1. cd client/srv/www/galclient
       1. ./nanostate.pl server
   1. Run the worker ( in a shell, tmux, or setp as a service )
       1. cd client/srv/www/galclient
       1. ./worker.pl
   1. Configure $imgFolder in worker.pl and index.pl to point to where your images to ingest are
   1. Visit \url{http://galclient}

How to use the client interface:

   1. Click 'Scan'
       1. Each time you click scan 20 images will be imported
       1. This pulls in images from the $imgFolder location to be tracked
   1. Click 'Process'
       1. This reads the exif data from the images and creates "thumbnails"
   1. Click 'List' to view all the loaded images
   1. Click an image to get to the 'crop' screen
   1. Click the GPS icon to view a GPS map for that image



