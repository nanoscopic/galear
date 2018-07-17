var dc = new DomCascade();
dc.iconPath = '/ico';
function go() {
  //q( { cb: gotList }, 'op', 'list' );
  updateWorkerState();
}
var curstate = '';
function updateWorkerState() {
  q( { cb: gotState }, 'op', 'getState' );
}
function gotState( data, res ) {
  var state = res.state;
  if( curstate != state ) {
    curstate = state;
    var span = _getel('state');
    span.innerHTML = res.state;
  }
  setTimeout( updateWorkerState, 1000 );
}
function gotList( data, res ) {
  var c = res.c;
  var x = _getel('x');
  x.innerHTML = c;
}
function q( data ) {
  var params = Array.prototype.slice.call( arguments );
  params.shift();
  
  var url = '/index.pl';
  new Ajax( url, {
    //postBody: JSON.stringify( params ),
    postBody: _query.apply( 0, params ),
    onSuccess: success.bind( data )
  } );
}
function success( ajax ) {
  var data = this;
  var tr = ajax.transport;
  var res = JSON.parse( tr.responseText );
  if( data.cb ) {
    data.cb( data, res );
  }
}
function processImages() {
  q( { cb: processingStarted }, 'op', 'processImages' );
}
function processingStarted() {
}
function stopWorker() {
  q( { cb: stoppedWorker }, 'op', 'stopWorker' );
}
function stoppedWorker() {
}
function scanImages() {
  q( { cb: scanStarted }, 'op', 'scanImages' );
}
function scanStarted() {
}
function showFiles() {
  q( { cb: gotFiles }, 'op', 'showFiles' );
}
function gotFiles( passed, res ) {
  var entries = res.entry;
  console.log( entries );
  var info = _getel('list');
  
  var res = dc.flow( {
    name: 'table',
    attr: {
      cellPadding: 6,
      cellSpacing: 0,
      border: 1
    },
    sub: {
      name: 'tbody',
      ref: 'tbody'
    }
  } );
  _clear( info );
  _append( info, res.node );
  
  for( var i=0;i<entries.length;i++ ) {
    var e = entries[i];
    
    var tr = dc.flow( {
      name: 'tr',
      sub: [
        { name: 'td', sub: { name: 'text', text: e.id } },
        { name: 'td', sub: { name: 'text', text: e.fullpath } },
        { name: 'td', sub: { name: 'text', text: e.processed } },
        { name: 'td', sub: { name: 'text', text: e.size } },
        { name: 'td', sub: { name: 'text', text: e.created } },
        { name: 'td', sub: { name: 'text', text: e.width } },
        { name: 'td', sub: { name: 'text', text: e.height } },
        { name: 'td', sub: { name: 'text', text: e.gpslat } },
        { name: 'td', sub: { name: 'text', text: e.gpslng } },
      ]
    } );
    
    _append( res.refs.tbody, tr.node );
    
    var ob = {
      id: e.id,
      width: e.width,
      height: e.height,
      latN: e.gpslatN,
      lngN: e.gpslngN
    };
    
    var tr2 = dc.flow( {
      name: 'tr',
      sub: {
        name: 'td',
        attr: {
          colspan: 7
        },
        sub: [
          {
            name: 'a',
            click: imgClick.bind( ob ),
            style: {
              cursor: 'pointer'
            },
            sub: {
              name: 'img',
              src: '/index.pl?op=getimg&id=' + e.id
            }
          }
        ]
      }
    } );
    _append( res.refs.tbody, tr2.node );
  }
}

function imgClick() {
  var id = this.id;
  _getel('list').style.display = 'none';
  var detail = _getel('detail');
  
  var ob = {
    id: id
  };
  
  var winWidth = window.innerWidth;//document.documentElement.clientWidth;
  var winHeight = window.innerHeight;//document.documentElement.clientHeight;
  var detailTop = detail.offsetTop;
  winHeight -= detailTop;
  winHeight -= 50;
  var dims = fitInside( winWidth, winHeight, this.width, this.height );
  
  var det = dc.append ( detail, [
    {
      name: 'icon',
      icon: 'left',
      click: toPrev,
      style: { marginRight: '10px', marginBottom: '10px' }
    },
    {
      name: 'icon',
      icon: 'right',
      click: toNext,
      style: { marginRight: '10px', marginBottom: '10px' }
    },
    {
      name: 'icon',
      icon: 'nav/cross',
      click: closeImg,
      style: { marginRight: '10px', marginBottom: '10px' }
    },
    {
      name: 'icon',
      icon: 'measure_crop',
      click: doCrop,
      style: { marginRight: '10px', marginBottom: '10px' }
    },
    {
      name: 'icon',
      icon: 'google_map',
      click: showGPS.bind( this ),
      style: { marginRight: '10px', marginBottom: '10px' }
    },
    {
      name: 'div',
      style: {
        width: dims[0]+ 'px',
        height: dims[1] + 'px'
      },
      sub: {
        name: 'img',
        src: '/index.pl?op=origimg&id=' + id,
        
        ref: 'img'
      }
    }
  ] );
  
  ob.croppr = new Croppr( det.refs.img, {
      startSize: [
        0,0,'%'
      ]
  } );
}

function showGPS() {
  var latN = this.latN;
  var lngN = this.lngN;
  _getel('detail').style.display='none';
  var map = _getel('map');
  var ob = {};
  var res = dc.append( map, [
    {
      name: 'icon',
      icon: 'nav/cross',
      click: closeGPS,
      style: { marginRight: '10px', marginBottom: '10px' }
    },
    {
      name: 'div',
      id: 'osm',
      style: { width: '800px', height: '600px' }
    }
  ] );
  //latN = Math.floor( latN * 10000 ) / 10000;
  //lngN = Math.floor( lngN * 10000 ) / 10000;
  ob.map = L.map('osm').setView( [ latN , lngN ], 13 );
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png?{foo}', {foo: 'bar'}).addTo(ob.map);
  //alert( latN + '-' + lngN );
}

function closeGPS() {
  _getel('detail').style.display='block';
  _getel('map').style.display='none';
}

function toPrev() {
}

function toNext() {
}

function doCrop() {
}

function fitInside(viewX,viewY,imgX,imgY) {
  var imgRatio = imgY / imgX;
  var viewRatio = viewY / viewX;
  var outX,outY;
  if( imgRatio < viewRatio ) { // wider; pad top/bottom
    outX = viewX;
    outY = viewX * imgRatio;
  }
  else if( imgRatio > viewRatio ) {
    outY = viewY;
    outX = viewY / imgRatio;
  }
  else {
    outX = viewX;
    outY = viewY;
  }
  return [ outX, outY ];
}

function closeImg() {
  var detail = _getel('detail');
  _clear( detail );
  _getel('list').style.display = 'block';
}
