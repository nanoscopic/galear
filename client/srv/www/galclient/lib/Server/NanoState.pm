#!/usr/bin/perl -w
package Server::NanoState;

require Exporter;
use strict;
use warnings;
use vars qw/@ISA @EXPORT_OK/;
use NanoMsg::Raw;
use XML::Bare;
use JSON::XS;
use Data::Dumper;
@ISA = qw/Exporter/;
@EXPORT_OK = qw/req server decode_jsxml/;

my $state = {};
my $tasks = {};
my $gid = 1;

my $coder = JSON::XS->new;

sub req {
  my ( $req, $reqtype ) = @_;
  my $socket = nn_socket( AF_SP, NN_PAIR );
  my $bindok = nn_connect( $socket, "ipc:///srv/www/galclient/nanostate.ipc" );
  if( !$bindok ) {
    my $err = nn_errno();
    die "fail to bind: ".decode_err( $err );
  }
  nn_setsockopt( $socket, NN_SOL_SOCKET, NN_RCVTIMEO, 5000 );
  
  my $reqtext = encode_jsxml( $req, $reqtype || 'xml' );
  
  #print "Sending text $reqtext\n";
  my $sent_bytes = nn_send( $socket, $reqtext, 0 );
  if( !$sent_bytes ) {
    my $err = nn_errno();
    $err = decode_err( $err );
    die "Fail to send: $err";
  }
  
  my $bytes_received = nn_recv( $socket, my $buf, 25000, 0 );
  if( !$bytes_received ) {
    my $err = nn_errno();
    if( $err == ETIMEDOUT ) {
      return "Timed out receiving result";
    }
    die "fail to recv: ".decode_err( $err );
  }
  #print "Received: $buf\n";
  
  my $data = decode_jsxml( $buf );
  
  nn_close( $socket );
  
  return $data;
}

use IO::Socket;
sub server {
  local $| = 1;
  my $socket = nn_socket( AF_SP, NN_PAIR );
  
  my $ipcFile = "/srv/www/galclient/nanostate.ipc";
  if( ! -e $ipcFile ) {
    IO::Socket::UNIX->new(
      LocalAddr => $ipcFile,
      Type => SOCK_STREAM,
      Listen => 5
    );
  }
  `chmod 777 $ipcFile`;
  
  my $bindok = nn_bind( $socket, "ipc://$ipcFile" );
  if( !$bindok ) {
    my $err = nn_errno();
    die "fail to bind: ".decode_err( $err );
  }
  nn_setsockopt( $socket, NN_SOL_SOCKET, NN_RCVTIMEO, 2000 );
  `chmod 777 $ipcFile`;
  
  while( 1 ) {
    my $bytes_received = nn_recv( $socket, my $buf, 5000, 0 );
    if( !$bytes_received ) {
      my $err = nn_errno();
      if( $err == ETIMEDOUT ) {
        print ".";
        next;
      }
      die "fail to recv: ".decode_err( $err );
    }
    
    #print "Received bytes: $buf\n";
    my $data = decode_jsxml( $buf );
    
    my %res = ( ok => 1 );
    my $op = $data->{'op'};
    if( !$op ) {
      $res{'error'} = "No op specified";
    }
    elsif( $op eq 'status' ) {
      $res{'status'} = 'okay';
    }
    elsif( $op eq 'getstate' ) {
      getState( \%res, $data );
    }
    elsif( $op eq 'setstate' ) {
      setState( \%res, $data );
    }
    elsif( $op eq 'addtask' ) {
      addTask( \%res, $data );
    }
    elsif( $op eq 'gettasks' ) {
      getTasks( \%res, $data );
    }
    elsif( $op eq 'deltask' ) {
      delTask( \%res, $data );
    }
    elsif( $op eq 'dump' ) {
      doDump( \%res, $data );
    }
    elsif( $op eq 'wipetasks' ) {
      wipeTasks( \%res, $data );
    }
    else {
      $res{'error'} = "Unknown op $op";
    }
    
    my $restype = $data->{'restype'} || 'xml';
    my $restext = encode_jsxml( \%res, $restype );
    
    my $sent_bytes = nn_send( $socket, $restext, 0 );
    if( !$sent_bytes ) {
      my $err = nn_errno();
      $err = decode_err( $err );
      die "Fail to send: $err";
    }
  }
}

sub doDump {
  my ( $res, $req ) = @_;
  $res->{'state'} = $state;
  $res->{'tasks'} = $tasks;
}

sub wipeTasks {
  my ( $res, $req ) = @_;
  $res->{'ok'} = 1;
  $tasks = {};
}

sub addTask {
  my ( $res, $req ) = @_;
  my $id = newid();
  my $task = $req->{'task'};
  $task->{'created'} = time();
  $res->{'id'} = $id;
  
  my $dest = $req->{'dest'};
  my $taskNode = $tasks->{ $dest };
  if( !$taskNode ) {
    $taskNode = $tasks->{ $dest } = { byid => {} };
  }
  
  my $byid = $taskNode->{'byid'};
  $byid->{ $id } = $task;
}

sub newid {
  my $id = $gid++;
  return $id;
}

sub getTasks {
  my ( $res, $req ) = @_;
  my $dest = $req->{'dest'};
  my $taskNode = $tasks->{ $dest };
  if( !$taskNode ) {
    $taskNode = $tasks->{ $dest } = { byid => {} };
  }
  my $byid = $taskNode->{'byid'};
  if( !%$byid ) {
    $res->{'tasks'} = {};
    $res->{'taskCount'} = 0;
    return;
  }
  if( $req->{'limit'} ) {
    my @ids = sort { $byid->{$a}{'created'} <=> $byid->{$b}{'created'} } keys %$byid;
    $res->{'taskCount'} = scalar @ids;
    my $byid_filtered = {};
    $res->{'tasks'} = $byid_filtered;
    
    my $limit = $req->{'limit'};
    while( $limit > 0 ) {
      $limit--;
      my $id = shift @ids;
      $byid_filtered->{ $id } = $byid->{ $id };
    }
  }
  else {
    $res->{'tasks'} = $byid;
  }
}

sub delTask {
  my ( $res, $req ) = @_;
  my $id = $req->{'id'};
  
  my $dest = $req->{'dest'};
  my $taskNode = $tasks->{ $dest };
  if( !$taskNode ) {
    $taskNode = $tasks->{ $dest } = { byid => {} };
  }
  
  my $byid = $taskNode->{'byid'};
  if( $byid->{ $id } ) {
    $res->{'result'} = 'deleted';
    delete $byid->{ $id };
  }
  else {
    $res->{'error'} = "Could not find task id $id under dest $dest";
  }
}

sub getState {
  my ( $res, $req ) = @_;
  my $node = $req->{'node'};
  my $nodeState = $state->{ $node } || {};
  $res->{'state'} = $nodeState;
}

sub setState {
  my ( $res, $req ) = @_;
  my $node = $req->{'node'};
  my $nodeState = $state->{ $node };
  if( !$nodeState ) {
    $nodeState = $state->{ $node } = {};
  }
  my $newData = $req->{'data'};
  print "Muxing " . Dumper( $newData ) . "\nINTO\n" . Dumper( $nodeState ) . "\n";
  mux( $nodeState, $newData );
  print "Reslt ". Dumper( $nodeState ) . "\n";
}

sub mux {
  my ( $a, $b ) = @_;
  return if( !$a || !defined( $b ) );
  my $ra = ref( $a );
  my $rb = ref( $b );
  if( $ra eq 'HASH' && $rb eq 'HASH' ) {
    for my $key ( keys %$b ) {
      my $val = $b->{ $key };
      if( defined( $val ) ) {
        my $rv = ref( $val );
        if( $rv eq 'HASH' ) {
          my $curval = $a->{ $key };
          if( ! defined( $curval ) || ref( $curval ) ne 'HASH' ) { $a->{ $key } = {}; }
          mux( $a->{ $key }, $val );
        }
        else {
          $a->{ $key } = $val;
        }
      }
      else {
        delete $a->{ $key };
      }
    }
  }
}

sub decode_jsxml {
  my $buf = shift;
  my $data;
  my $b1 = substr( $buf, 0, 1 );
  if( $b1 eq '<' ) {
    my ( $ob, $xml ) = XML::Bare->simple( text => $buf );
    $data = $xml;
  }
  elsif( $b1 eq '{' ) {
    $data = $coder->decode( $buf );
  }
  else {
    die "Unknown first character of request data: $b1";
  }
  return $data;
}

sub encode_jsxml {
  my ( $req, $reqtype ) = @_;
  my $reqtext = '';
  if( $reqtype eq 'xml' ) {
    $reqtext = XML::Bare::Object::xml( 0, $req );
  }
  elsif( $reqtype eq 'json' ) {
    $reqtext = $coder->encode( $req );
  }
  else {
    die "Invalid reqtype $reqtype";
  }
  return $reqtext;
}

sub decode_err {
  my $n = shift;
  return "EBADF" if( $n == EBADF );
  return "EMFILE" if( $n == EMFILE );
  return "EINVAL" if( $n == EINVAL );
  return "ENAMETOOLONG" if( $n == ENAMETOOLONG );
  return "EPROTONOSUPPORT" if( $n == EPROTONOSUPPORT );
  return "EADDRNOTAVAIL" if( $n == EADDRNOTAVAIL );
  return "ENODEV" if( $n == ENODEV );
  return "EADDRINUSE" if( $n == EADDRINUSE );
  return "ETERM" if( $n == ETERM );
  return "ETIMEDOUT" if( $n == ETIMEDOUT );
  return "unknown error - $n";
}

1;
