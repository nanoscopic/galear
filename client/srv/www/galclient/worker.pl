#!/usr/bin/perl -w
use strict;
use DBD::SQLite;
#use Linux::Inotify2;
use XML::Bare;
use lib './lib';
use Server::NanoState qw/req/;
use Data::Dumper;
use Image::ExifTool qw/:Public/;
use Date::Parse;
use Image::Magick;

my %fileHash;
my $imgFolder = "/home/dhelkowski/images";
my $thumbFolder = "$imgFolder/thumbs";
if( ! -e $thumbFolder ) {
  mkdir $thumbFolder;
}

my $dbfile = "/srv/www/galclient/db.sqlite";
my $createDb = 0;
if( ! -e $dbfile ) {
  $createDb = 1;
}
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile");
if( $createDb ) {
  $dbh->do("create table files (
    fullPath TEXT,
    processed TINYINT default 0,
    gotexif TINYINT default 0,
    size MEDIUMINT,
    changed INTEGER,
    exif TEXT,
    snaptime INTEGER,
    width INTEGER,
    height INTEGER,
    gpslat VARCHAR(255),
    gpslng VARCHAR(255) );");
  #$dbh->do("create table worker_events ( xml TEXT );");
  #$dbh->do("create table worker_event_pos ( id INT );");
  #$dbh->do("insert into worker_event_pos (rowid, id) values (1,?)",undef,0);
  
  #$dbh->do("create table client_events ( xml TEXT );");
}

#my $res = $dbh->selectrow_array("select id from worker_event_pos where rowid=1;");

#print "last event id: $res\n";

#$dbh->do("update worker_event_pos set id=? where rowid=1",undef,$res+1);
setState('waiting');

while( 1 ) {
  
  my $res = req( { op => 'gettasks', dest => 'worker', limit => 1 } );
  if( !ref( $res ) ) {
    print "Error: $res\n";
  }
  
  my $taskCount = $res->{'taskCount'} || 0;
  if( $res->{'tasks'} ) {
    print "Fetching task\n";
    my $tasks = $res->{'tasks'};
    my @ids = keys %$tasks;
    my $id = $ids[0];
    my $task = $tasks->{ $id };
    
    my $op = $task->{'op'};
    if( !$op ) {
      print "Op not specified by task\n" . Dumper( $task );
      next;
    }
    
    if( $op eq 'scanImages' ) {
      scanImages();
      delTask( $id );
    }
    elsif( $op eq 'processImages' ) {
      processImages();
      delTask( $id );
    }
    else {
      print "Unknown op $op\n";
    }
    setState('waiting');
  }
  if( $taskCount <= 1 ) {
    sleep( 1 );
  }
}

sub delTask {
  my $id = shift;
  my $res = req( { op => 'deltask', dest => 'worker', id => $id } );
}

sub setState {
  my $state = shift;
  my $res = req( { op => 'setstate', node => 'worker', data => { state => $state } } );
}

sub fetchDbFileInfo {
  my $info = $dbh->selectall_arrayref( "select fullPath, processed, size, changed, rowid, gotexif, exif, snaptime, gpslat, gpslng from files" );
  for my $row ( @$info ) {
    my $fullPath = $row->[0];
    $fileHash{ $fullPath } = {
      processed => $row->[1],
      size      => $row->[2],
      changed   => $row->[3],
      id        => $row->[4],
      gotexif   => $row->[5],
      exif      => $row->[6],
      snaptime  => $row->[7],
      gpslat    => $row->[8],
      gpslng    => $row->[9]
    };
  }
}

sub processImages {
  setState( 'processing started' );
  print "Begun processing\n";
  
  fetchDbFileInfo();
  
  my $toProcess = 0;
  for my $file ( sort { $a cmp $b } keys %fileHash ) {
    my $row = $fileHash{ $file };
    if( !$row->{'processed'} ) {
      $toProcess++;
    }
  }
  
  my $pos = 1;
  for my $file ( sort { $a cmp $b } keys %fileHash ) {
    my $row = $fileHash{ $file };
    if( !$row->{'processed'} ) {
      print "Processing $file\n";
      setState( "processing $pos/$toProcess" );
      getExif( $file, $row );
      genThumb( $file, $row );
      $pos++;
    }
  }
}

sub genThumb {
  my ( $file, $row ) = @_;
  
  my $id = $row->{'id'};
  
  my $thumbFile = "$thumbFolder/$id.jpg";
  return if( -e $thumbFile );
  
  my $maxx = 800;
  my $maxy = 600;
  
  my $curx = $row->{'width'};
  my $cury = $row->{'height'};
  
  my $curAspect = $curx / $cury;
  my $maxAspect = $maxx / $maxy;
  
  my $newx;
  my $newy;
  if( $curAspect > $maxAspect ) { # it's wider ( pad top and bottom )
    $newx = $maxx;
    $newy = int( $maxx / $curAspect );
  }
  elsif( $curAspect < $maxAspect ) { # it's taller ( pad left and right )
    $newy = $maxy;
    $newx = int( $maxy * $curAspect );
  }
  else {
    $newx = $maxx;
    $newy = $maxy;
  }
  
  
  
  
  my $image = Image::Magick->new();
  $image->Read( $file );
  $image->Resize( geometry => "${newx}x$newy", filter => "Lanczos" );
  $image->Write( filename => $thumbFile );
}

sub getExif {
  my ( $file, $row ) = @_;
  
  my $info = ImageInfo( $file );
  
  my %wl = (
      # File info
      FileIndex => 1,
      DirectoryIndex => 1,
      FileNumber => 1,
      FileName => 1,
      
      # Dates / Times
      CreateDate => 1,
      FileModifyDate => 1,
      SubSecModifyDate => 1,
      SubSecDateTimeOriginal => 1,
      DateTimeOriginal => 1,
      ModifyDate => 1,
      TimeZoneCity => 1,
      TimeZone => 1,
      
      # GPS Info
      GPSDateTime => 1,
      "GPSAltitude (1)" => 1,
      GPSSatellites => 1,
      GPSLatitude => 1,
      GPSDateStamp => 1,
      GPSTimeStamp => 1,
      GPSPosition => 1,
      "GPSLongitude (1)" => 1,
      "GPSLatitude (1)" => 1,
      GPSAltitude => 1,
      GPSMapDatum => 1,
      GPSLongitude => 1,
      
      # Image dimensions
      ImageWidth => 1,
      ImageHeight => 1,
      ExifImageWidth => 1,
      ImageSize => 1,
      
      # Exposure / Focus / etc
      RedBalance => 1,
      "ExposureTime (2)" => 1,
      "ColorTemperature (1)" => 1,
      LightValue => 1,
      ShutterSpeed => 1,
      ISO => 1,
      ShutterSpeedValue => 1,
      "FocalLength (2)" => 1,
      FOV => 1,
      Aperature => 1,
      AperatureValue => 1,
      Megapixels => 1,
      BitsPerSample => 1,
      FNumber => 1,
      
      # Lens info
      Lens => 1,
      "LensModel (1)" => 1,
      LensModel => 1,
      Lenstype => 1,
      "LensType (1)" => 1,
      LensID => 1,
      
      # Camera info
      CanonImageType => 1,
      Model => 1,
      Make => 1,
      CanonModelID => 1,
      InternalSerialNumber => 1,
      SerialNumber => 1,
      
      # Other
      RecordMode => 1,
      ExifVersion => 1
    );
  
  my $okinfo = {};
  for my $key ( keys %$info ) {
    if( $wl{$key} ) {
      $okinfo->{ $key } = $info->{ $key };
    }
  }
  delete $info->{'Thumbnailimage'};
  my $exifdata = XML::Bare::Object::xml( 0, $okinfo );
  #print "Exif data for $file\n";
  #print Dumper($okinfo);
  #print "---------------------------\n";
  my $dtorig = $info->{ "SubSecDateTimeOriginal" };
  my $tzoff = $info->{ 'TimeZone' };
  my $snaptime = str2time( "$dtorig $tzoff" );
  
  # Example 2018:02:18 17:12:55.00
  my $width = $info->{'ImageWidth'};
  my $height = $info->{'ImageHeight'};
  
  my $latitude = $info->{'GPSLatitude'} || 0;
  my $longitude = $info->{'GPSLongitude'} || 0;
  
  $row->{'gotexif'} = 1;
  $row->{'snaptime'} = $snaptime;
  $row->{'width'} = $width;
  $row->{'height'} = $height;
  $row->{'exif'} = $exifdata;
  $row->{'gpslat'} = $latitude;
  $row->{'gpslng'} = $longitude;
  
  $dbh->do( "update files set gotexif=?,snaptime=?,width=?,height=?,exif=?,gpslat=?,gpslng=? where rowid=?", undef,
    1, # to mark that we got the exif
    $snaptime,
    $width,
    $height,
    $exifdata,
    $latitude,
    $longitude,
    $row->{'id'} );
}

sub scanImages {
  setState( 'scanning' );
  print "Starting image scan\n";
  
  fetchDbFileInfo();
  opendir( my $dh, $imgFolder );
  my @files = readdir( $dh );
  closedir( $dh );
  
  my $count = 0;
  for my $file ( @files ) {
    next if( $file =~ m/^\.+$/ );
    next if( $file !~ m/\.jpg$/i );
    $count++;
  }
  
  my $maxNum = 20;
  my $pos = 0;
  my $added = 0;
  for my $file ( sort { $a cmp $b } @files ) {
    next if( $file =~ m/^\.+$/ );
    next if( $file !~ m/\.jpg$/i );
    $pos++;
    setState( "scanning $pos/$count" );
    
    #print "Checking file $file\n";
    my $fullPath = "$imgFolder/$file";
    
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($fullPath);
    
    my $curData = $fileHash{ $fullPath };
    if( !$curData ) {
      $fileHash{ $fullPath } = {
        processed => 0,
        size => $size,
        changed => $mtime
      };
      print "Tracking file $fullPath\n  size = $size, mtime = $mtime\n";
      $dbh->do("insert into files ( fullPath, processed, size, changed ) values ( ?,?,?,? )", undef,
        $fullPath,
        0,
        $size,
        $mtime );
      $added++;
    }
    last if( $added >= $maxNum );
  }
  
  #sleep( 4 );
}
