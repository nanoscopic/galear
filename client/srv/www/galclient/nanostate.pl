#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use lib './lib';
use Server::NanoState qw/req server decode_jsxml/;


my $cmd = $ARGV[0];

if( !$cmd ) {
  die "Specify a command. ( server or status )";
}
if( $cmd eq 'server' ) {
  server();
}
elsif( $cmd eq 'status' ) {
  my $res = req( { op => 'status', restype => 'json' } );
  print Dumper( $res );
}
elsif( $cmd eq 'getstate' ) {
  my $node = $ARGV[1];
  my $res = req( { op => 'getstate', node => $node } );
  print Dumper( $res );
}
elsif( $cmd eq 'setstate' ) {
  my $node = $ARGV[1];
  my $key = $ARGV[2];
  my $val = $ARGV[3];
  my $data = { $key => $val };
  my $res = req( { op => 'setstate', node => $node, data => $data } );
  print Dumper( $res );
}
elsif( $cmd eq 'addtask' ) {
  my $dest = $ARGV[1];
  my $task = decode_jsxml( $ARGV[2] );
  my $res = req( { op => 'addtask', dest => $dest, task => $task } );
  print Dumper( $res );
}
elsif( $cmd eq 'gettasks' ) {
  my $dest = $ARGV[1];
  my $res = req( { op => 'gettasks', dest => $dest } );
  print Dumper( $res );
}
elsif( $cmd eq 'gettask' ) {
  my $dest = $ARGV[1];
  my $res = req( { op => 'gettasks', dest => $dest, limit => 1 } );
  print Dumper( $res );
}
elsif( $cmd eq 'deltask' ) {
  my $dest = $ARGV[1];
  my $id = $ARGV[2];
  my $res = req( { op => 'deltask', dest => $dest, id => $id } );
  print Dumper( $res );
}
elsif( $cmd eq 'dump' ) {
  my $res = req( { op => 'dump' } );
  print Dumper( $res );
}
else {
  die "Unknown command";
}