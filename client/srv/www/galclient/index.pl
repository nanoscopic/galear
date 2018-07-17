#!/usr/bin/perl -w
use strict;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
use JSON::XS;
use lib './lib';
use Server::NanoState qw/req/;
use DBD::SQLite;

my $q = CGI->new();

my $dbfile = "/srv/www/galclient/db.sqlite";
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile");

if( $q->request_method() eq 'GET' ) {
  my %vars = $q->Vars();
  
  my $op = $vars{'op'} || '';
  if( $op eq 'getimg' ) {
    my $id = $vars{'id'};
    
    my $imgFolder = "/home/dhelkowski/images";
    my $thumbFolder = "$imgFolder/thumbs";
    my $thumbFile = "$thumbFolder/$id.jpg";
    serve_file( $thumbFile );
    exit;
  }
  if( $op eq 'origimg' ) {
    my $id = $vars{'id'};
    my $path = $dbh->selectrow_array( 'select fullpath from files where rowid=?', undef, $id );
    serve_file( $path );
  }
}

sub serve_file {
  my $path = shift;
  print $q->header( -type => 'image/jpeg' );
  open( my $fh, "<$path" );
    binmode( $fh );
    {
      local $/ = undef;
      my $data = <$fh>;
      print STDOUT $data;
    }
    close( $fh );
  
}

if( $q->request_method() eq 'POST' ) {
  open( my $lfh, ">>/srv/www/galclient/log" );
  
  my %vars = $q->Vars();
  
  my $op = $vars{'op'};
  print $lfh "Op: $op\n";
  
  print $q->header( -type => 'application/json' );
  my %out;
  if( $op eq 'list' ) {
    $out{'c'} = 34;
  }
  elsif( $op eq 'scanImages' ) {
    my $task = { op => 'scanImages' };
    my $res = req( { op => 'addtask', dest => 'worker', task => $task } );
    $out{'started'} = 1;
  }
  elsif( $op eq 'processImages' ) {
    my $task = { op => 'processImages' };
    my $res = req( { op => 'addtask', dest => 'worker', task => $task } );
    $out{'started'} = 1;
  }
  elsif( $op eq 'getState' ) {
    my $res = req( { op => 'getstate', node => 'worker' } );
    my $workerState = $res->{'state'} || {};
    my $state_of_worker = $workerState->{'state'};
    $out{'state'} = $state_of_worker;
  }
  elsif( $op eq 'stopWorker' ) {
    my $res = req( { op => 'wipetasks' } );
    $out{'ok'} = 1;
  }
  elsif( $op eq 'showFiles' ) {
    my $info = $dbh->selectall_arrayref( "select fullPath, processed, size, changed, rowid, snaptime, width, height, gpslat, gpslng from files" );
    my $entries = [];
    for my $row ( @$info ) {
      my $createdunix = $row->[5];
      
      my $gpslat = $row->[8];
      my $gpslng = $row->[9];
      #var dd = degrees + minutes/60 + seconds/(60*60);

      #if (direction == "S" || direction == "W") {
      #  dd = dd * -1;
      #} // Don't do anything for N or E
      
      #47 deg 35' 44.78" N
      my $latN = 0;
      my $lngN = 0;
      if( $gpslat =~ m/([0-9.]+) deg ([0-9.]+)' ([0-9.]+)"/ ) {
        $latN = $1 + ( $2 / 60 ) + ( $3 / 3600 );
      }
      if( $gpslat =~ m/([0-9.]+) deg ([0-9.]+)' ([0-9.]+)"/ ) {
        $lngN = $1 + ( $2 / 60 ) + ( $3 / 3600 );
      }
      
      my $entry = {
        fullpath => $row->[0],
        processed => $row->[1],
        size => clean_size( $row->[2] ),
        createdunix => $createdunix,
        created => clean_date( $createdunix ),
        changed => clean_date( $row->[3] ),
        id => $row->[4],
        width => $row->[6],
        height => $row->[7],
        gpslat => $row->[8],
        gpslng => $row->[9],
        gpslatN => $latN,
        gpslngN => $lngN
      };
      push( @$entries, $entry );
    }
    @$entries = sort {
      if( $a->{'createdunix'} && $b->{'createdunix'} ) { return $a->{'createdunix'} <=> $b->{'createdunix'}; }
      $a->{'fullpath'} cmp $b->{'fullpath'};
    } @$entries;
    
    $out{'entry'} = $entries;
  }
  my $coder = JSON::XS->new->ascii->pretty;
  print $coder->encode( \%out );
  
  close( $lfh );
  exit;
}

sub clean_date {
  my $unix = shift;
  return '' if( !$unix );
  my $str = localtime( $unix );
  return $str;
}

sub clean_size {
  my $size = shift;
  if( $size > 1024 * 1024 ) {
    $size /= 1024 * 1024;
    $size *= 100;
    $size = int( $size );
    $size /= 100;
    return "$size MB";
  }
  if( $size > 1024 ) {
    $size /= 1024;
    $size *= 100;
    $size = int( $size );
    $size /= 100;
    return "$size KB";
  }
  return "$size B";
}

print $q->header;

print <<DONE;
<html>
  <head>
    <script src='js/protocut/base.js'></script>
    <script src='js/protocut/dom.js'></script>
    <script src='js/protocut/ajax.js'></script>
    <script src='js/DomCascade/protocut/dom-cascade.js'></script>
    <script src='js/index.js'></script>
    
     <link rel="stylesheet" href="/js/map/leaflet.css" crossorigin=""/>

     <script src="/js/map/leaflet.js" crossorigin=""></script>
    
    <link href="/js/crop/croppr.min.css" rel="stylesheet"/>
    <script src="/js/crop/croppr.min.js"></script>
  </head>
  <body onload='go()'>
  
  <input type='button' value='Scan' onclick='scanImages()'>
  <input type='button' value='Process' onclick='processImages()'>
  <input type='button' value='List' onclick='showFiles()'>
  <input type='button' value='Stop worker' onclick='stopWorker()'>
  
  Worker State:
  <span id='state'></span>
  <br><br>
  
  <!--Generic Info:-->
  <span id='detail'></span>
  <span id='map'></span>
  <span id='list'></span>
    
  </body>
</html>
DONE
