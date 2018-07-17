function _queryhash() {
  var q = window.location.search.substr(1), $hash = {};
  q.split('&').forEach( function( $part ) {
    var p2 = $part.split('=');
    $hash[ p2[0] ] = ( p2.length < 2 ) ? '' : decodeURIComponent( p2[1] );
  } );
  return $hash;
}
function _hash2query( $hash ) {
  var $str = '';
  Object.keys( $hash ).forEach( function( $key ) {
    var $val = $hash[$key];
    $str += '&' + $key + '=' + encodeURIComponent( $val );
  } );
  return $str.substr( 1 );
}