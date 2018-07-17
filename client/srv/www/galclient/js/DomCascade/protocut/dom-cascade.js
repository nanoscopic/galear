/*
    DOM Cascade
    Copyright (C) 2014 David Helkowski
    License: CC0 1.0 Universal - http://creativecommons.org/publicdomain/zero/1.0/
    Compatibility: IE9+, Chrome 7+, Firefox 4+, Safari 5.1.4+ ( bind and isArray )
      es5-shim could be used...
*/
var DomCascade = Class.create();
DomCascade.prototype = {
    num: 10,
    initialize: function() {
    },
    types: {
        html: function( ob ) {
            var dummy = _newel('div');
            dummy.innerHTML = ob.html;
            if( dummy.childNodes.length == 1 ) return { node: dummy.removeChild( dummy.firstChild ) };
            var child, frag = document.createDocumentFragment();
            while( child = dummy.firstChild() ) frag.appendChild( child );
            return { node: frag };
        },
        text: function( ob ) {
            var text = ob.text;
            return { node: _newtext( text ) };
        },
        nbsp: function( ob ) {
            return { node: _newtext('\u00a0') };
        },
        img: function( ob ) {
            var node = _newel( 'img' );
            node.src = ob.src;
            return { node: node };
        },
        icon: function( ob ) {
            var node = _newel( 'img' );
            node.src = this.iconPath + '/' + ob.icon + '.png';
            node.style.cursor = 'pointer';
            return { node: node };
        },
        svg: function( ob ) {
            var node = document.createElementNS("http://www.w3.org/2000/svg", ob.svg);
            return { node: node };
        },
        select: function( ob ) {
            var node  = _newel( 'select' );
            node.size = ob.size;
            return { node: node };
        },
        option: function( ob ) {
            var node       = _newel( 'option' );
            node.value     = ob.value;
            node.innerHTML = ob.html || ob.value;
            return { node: node };
        },
        widget: function( ob ) {
            var cls = ob.widget;
            var widget;
            if( ob.args ) widget = new cls( ob.args );
            else widget = new cls();
            return { node: widget.domNode, widget: widget };
        },
        hidden: function( ob ) {
            var node   = _newel( 'input' );
            node.type  = 'hidden';
            node.value = ob.value;
            node.name  = ob.name2;
            return { node: node };
        },
        input: function( ob ) {
            var node   = _newel( 'input' );
            node.type  = ob.type;
            node.value = ob.value;
            node.name  = ob.name2;
            return { node: node };
        }
    },
    options: {
        ref: function( ob, res ) {
            res.refs[ ob.ref ] = res.node;
        },
        widget: function( ob, res ) {
            if( !res.widgets ) res.widgets = [];
            res.widgets.push( ob.widget );
        },
        sub: function( ob, res ) {
            var subs = ob.sub;
            if( !Array.isArray( subs ) ) subs = [ subs ];
  
            for( var i=0;i<subs.length;i++ ) {
                var sub = subs[ i ];
                var subres = this.flow( sub );
                if( subres.refs ) this.mux( res.refs, subres.refs );
                _append( res.node, subres.node );
            }
        },
        click:     function( ob, res ) { var node = res.node; node.addEventListener( 'click'    , ob.click.bind( ob ) ); },
        mouseover: function( ob, res ) { var node = res.node; node.addEventListener( 'mouseover', ob.mouseover.bind( ob ) ); },
        mouseout:  function( ob, res ) { var node = res.node; node.addEventListener( 'mouseout' , ob.mouseout.bind( ob ) ); },
        js: function( ob, res ) {
            var node = res.node;
            var func = ob.js;
            func( ob, res );
        },
        attr: function( ob, res ) {
            var node = res.node;
            var base = {};
            var attrs = ob.attr;
            var n;
            for( n in attrs ) {
                if( n in base ) continue;
                node.setAttribute( n, attrs[ n ] );
            }
        },
        style: function( ob, res ) {
            var node = res.node;
            var base = {};
            var styles = ob.style;
            var n;
            for( n in styles ){
                if( n in base ) continue;
                node.style[ n ] = styles[ n ];
            }
        },
        "class": function( ob, res ) {
            var node = res.node;
            node.className = ob['class'];
        },
        id: function( ob, res ) {
            res.node.id = ob.id;
        }
    },
    append: function( node, ob ) {
        if( ob.length ) {
            return this.flowArr( ob, function( ires ) {
                node.appendChild( ires.node );
            } );
        }
        res = this.flow( ob );
        node.appendChild( res.node );
        if( res.widget && res.widget.length ) this.startupWidgets( res );
        return res;
    },
    replaceInner: function( node, ob ) {
        domC.empty( node );
        node.appendChild( this.flow( ob ).node );
    },
    flowArr: function( ob, func ) {
        var res = { node: [], refs: {}, dojo: [] };
        for( var i=0;i<ob.length;i++ ) {
            var ires = this.flow( ob[ i ] );
            this.mux( res.refs, ires.refs );
            if( ires.dojo ) this.mux( res.dojo, ires.dojo );
            res.node.push( ires.node );
            if( func ) func( ires );
        }
        return res;
    },
    startupWidgets: function( res ) {
        var widgets = res.widgets;
        for( var i in widgets ) {
            var widget = widgets[i];
            widget.startup();
        }
    },
    flow: function( ob ) {
        if( Array.isArray( ob ) ) return this.flowArr( ob );
        var name = ob.name;
        var typeF = this.types[ name ];
        var res = {};
        
        if( typeF ) res = typeF.apply(this, [ ob ] );
        else        res = { node: _newel( name ) };
  
        if( ! res.refs ) res.refs = {};
        
        var base = { name: 1 };
        var op;
        for( op in ob ) {
            if( op in base ) continue; // skip name and basic JS stuffs
            var opF = this.options[ op ];
            if( opF ) opF.apply( this, [ ob, res ] );
        }
        
        return res;
    },
    mux: function( a, b ) {
        var name, base = {};
        for( name in b ) {
            if( !( name in base ) ) {
                if( a[ name ] ) {
                    // potentially create arrays here
                }
                else a[ name ] = b[ name ];
            }
        }
    }
};