Goal:
    Create a functional replacement for Picasa to show a gallery of photos
    
Planned Process:

   1. Setup an initial environment in which to create and deploy the created application
       1. Fedora 28 *done*
       1. MariaDB *done*
       1. MyWebSQL ( to administrate DB ) *done*
       1. Apache *done*
       1. Perl CGI ( for rapid initial development ) *done*
   1. Write user stories for what the system will be able to do
       1. MVP *done*
       1. Additional later planned features
   1. Design database for storing data needed for such a system
   1. Create loose mockups of the functionality of how the system will look
   1. Write code to implement the system
       1. Backend
       1. Frontend
   1. Test the system with a set of photos
   1. Setup a SUSE environment using containers that replicates the application setup
       1. Container for Apache with configuration
           1. Configuration for the domain/path it is at
           1. Configuration to use the mod\_nano module to pass requests out of the apache cotnainer
       1. Container for database
       1. Container for MyWebSQL
       1. Container for the application, receiving messages in mod\_nano format from the Apache container
MVP User Stories:

   1. Able to upload images in bulk into the system
       1. Using a perl script
   1. Able to select which images to make "public"
   1. Able to tag images into "galleries"
   1. Able to display galleries
   1. Able to accept images in a variety of formats
Extended User Stories:

   1. Permissions to view specific image or tags
   1. Group owned galleries
       1. With approval process to post to it
   1. Image request ( such as for image contests )
   1. User ratings of images
   1. Email verification on account registration
   1. Password reset process
   1. Two factor authentication
   1. User comments on images
   1. Template system for gallery rendering / themes
   1. Plugin system for processing incoming raw images
   1. Natively installable uploader
       1. Installs web server / app with root permissions onto users system
       1. For Windows
       1. For Linux
           1. As SUSE package
           1. As RHEL package
Database

   1. Users
       1. Username
       1. Email
       1. Password ( hashed )
       1. Approved ( boolean )
       1. User type ( 0=regular, 1=admin )
   1. Image file
       1. Owning user id
       1. Filename
       1. Full path
       1. Remote / Local ( indicates whether we have the file locally or are just tracking a remote file )
       1. Complete File size ( the size of the file when "complete" )
       1. Current file size ( the size of the file currently - will not match when it is being transferred )
       1. Boolean 'in\_transfer' ( indicates that the file is currently being/about to be transferred )
       1. Boolean 'original\_file' ( indicates that this is an original untouched file)
       1. Boolean 'to\_generate' ( indicates it has not yet been generated from the original fle )
       1. image file id derived from
       1. crop region applied from source ( the image crop region id )
       1. image width
       1. image height
   1. Image hash
       1. Hash type (md5, sha1, etc )
       1. Hash value
       1. Imge file id
   1. Image crop region
       1. left, top, right, bottom
       1. crop tagname
   1. Active transfers
       1. Local destination image file id
       1. Original image file id
       1. Size transferred so far
   1. Gallery tag
       1. Name of the tag
   1. Applications of tags
       1. Id of image tag is applied to
       1. Id of the gallery tag itself
   1. Gallery
       1. ( tags to display; done as a subtable )
       1. type ( latest or all )
       1. latest N number ( if latest type )
   1. Image permissions ( for a specific image )
   1. Tag permissions ( for permission to a tag )
   1. User group
       1. Group name
   1. Group member
       1. Group id
       1. User id
   1. Session
       1. User id
       1. Session start time
       1. Session end time
       1. Session key ( uuid )
API

   1. /users/register Register user
   1. /session/login Login user
   1. /session/logout
   1. /users/approve Approve registered user
   1. /users/deny Deby registerered user
   1. /users/list Get users of system
   1. /users/resetpw Reset user password
   1. /img/getkey Fetch key for sftp'ing in
   1. /img/upload/request Request to upload files
   1. /img/upload/update Update status of upload
   1. /img/query Fetch filename info of a stored file via known information
   1. /img/download Download an image directly
   1. /img/list List stored files
     
Potential benefits:

   1. Have a functional way to manage posting thousands fo images easily
   1. Create a useful application which could then be scaled using k8s / CaaSP.
   1. Learn how some various tooling works
       1. Etherpad ( this Etherpad deployed to share progress of HackWeek work )
   1. Learn differences in applications deployment on Fedora vs SUSE ( initially made and deployed on Fedora; will port to SUSE )
   1. Gain more experience using OBS ( open build server ), contributing created application to SUSE repos
   1. Learn how to make letsencrypt auto renew ssl via apache plugin ( instead fo using certbot manually periodically )

   
   Subproject: nanostate

Purpose:
    Have a centralized system that stores the state of various "nodes". The state being a XML tree of information.
    Besides state per "unit", there should also be a queue of messags that can be stored and tracked.
    Events should be able to have a name, so that events can be listened to.
