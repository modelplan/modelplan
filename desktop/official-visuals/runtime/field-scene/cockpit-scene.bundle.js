/*! SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
 * Copyright (c) 2026 ModelPlan. All rights reserved. ModelPlan and Model Plan are marks of ModelPlan. No trademark rights are granted.
 * Minified 3D launch-field scene for the official cockpit's enlarged porthole (owner D39/D-A); see README.md.
 * Bundles three.js 0.186.1 (MIT; its notice is at the end of this file). */
var ch="c01-joined-fit-v1";function hh(i,e){let t=e/i<.13,n=i/636;return{x:(t?300:272)*n,r:580*n,y:(t?8:18)*n,b:e-(t?10:34)*n}}function Rc(i,e,t){if(t===ch)return hh(i,e);let n=e/i<.13,s=i/636;return{x:i*(n?.52:.44),r:i-32*s,y:(n?8:12)*s,b:e-(n?10:20)*s}}function uh({renderer:i,composer:e,camera:t,fit:n,target:s,home:r,width:a,height:o,liveWidth:l,liveHeight:c,profile:h}){let f=t.clone();try{let u=n(a,o,Rc(a,o,h));t.aspect=a/o,t.position.set(s.x+u.d*Math.sin(r.yaw)*Math.cos(r.pitch),s.y+u.d*Math.sin(r.pitch),s.z+u.d*Math.cos(r.yaw)*Math.cos(r.pitch)),t.lookAt(s),t.setViewOffset(a,o,u.ox,u.oy,a,o),i.setSize(a,o,!1),e.setSize(a,o),e.render();let d=document.createElement("canvas");return d.width=a,d.height=o,d.getContext("2d").drawImage(i.domElement,0,0,a,o),d}finally{t.copy(f),i.setSize(l,c,!1),e.setSize(l,c),e.render()}}var Kh=0,g0=1,jh=2;var Ia=1,Qh=2,_r=3,ts=0,_n=1,xn=2,Hn=0,ns=1,nn=2,_0=3,x0=4,eu=5;var ys=100,tu=101,nu=102,iu=103,su=104,ru=200,au=201,ou=202,lu=203,v0=204,y0=205,cu=206,hu=207,uu=208,fu=209,du=210,pu=211,mu=212,gu=213,_u=214,zo=0,Ho=1,ko=2,Js=3,Vo=4,Go=5,Wo=6,Xo=7,M0=0,xu=1,vu=2,Qn=0,La=1,Da=2,Na=3,Ms=4,Ua=5,Fa=6,Oa=7;var S0=300,is=301,Ss=302,xr=303,yl=304,Ba=306,Yi=1e3,ui=1001,qo=1002,un=1003,yu=1004;var za=1005;var gn=1006,Ml=1007;var xi=1008;var Rn=1009,b0=1010,E0=1011,vr=1012,Sl=1013,ei=1014,kn=1015,sn=1016,bl=1017,El=1018,yr=1020,T0=35902,w0=35899,A0=1021,R0=1022,Vn=1023,di=1026,ss=1027,Tl=1028,wl=1029,rs=1030,Al=1031;var Rl=1033,Ha=33776,ka=33777,Va=33778,Ga=33779,Cl=35840,Pl=35841,Il=35842,Ll=35843,Dl=36196,Nl=37492,Ul=37496,Fl=37488,Ol=37489,Wa=37490,Bl=37491,zl=37808,Hl=37809,kl=37810,Vl=37811,Gl=37812,Wl=37813,Xl=37814,ql=37815,Yl=37816,$l=37817,Zl=37818,Jl=37819,Kl=37820,jl=37821,Ql=36492,ec=36494,tc=36495,nc=36283,ic=36284,Xa=36285,sc=36286;var qr=2300,Yo=2301,Fo=2302,i0=2303,s0=2400,r0=2401,a0=2402;var Mu=3200;var rc=0,Su=1,ti="",Wt="srgb",Yr="srgb-linear",$r="linear",Pt="srgb";var Oo=7680;var bu=519,Eu=512,Tu=513,wu=514,ac=515,Au=516,Ru=517,oc=518,Cu=519,C0=35044;var P0="300 es",Jn=2e3,Ks=2001;function zf(i){for(let e=i.length-1;e>=0;--e)if(i[e]>=65535)return!0;return!1}function Hf(i){return ArrayBuffer.isView(i)&&!(i instanceof DataView)}function js(i){return document.createElementNS("http://www.w3.org/1999/xhtml",i)}function Pu(){let i=js("canvas");return i.style.display="block",i}var fh={},Qs=null;function Zr(...i){let e="THREE."+i.shift();Qs?Qs("log",e,...i):console.log(e,...i)}function Iu(i){let e=i[0];if(typeof e=="string"&&e.startsWith("TSL:")){let t=i[1];t&&t.isStackTrace?i[0]+=" "+t.getLocation():i[1]='Stack trace not available. Enable "THREE.Node.captureStackTrace" to capture stack traces.'}return i}function ct(...i){i=Iu(i);let e="THREE."+i.shift();if(Qs)Qs("warn",e,...i);else{let t=i[0];t&&t.isStackTrace?console.warn(t.getError(e)):console.warn(e,...i)}}function lt(...i){i=Iu(i);let e="THREE."+i.shift();if(Qs)Qs("error",e,...i);else{let t=i[0];t&&t.isStackTrace?console.error(t.getError(e)):console.error(e,...i)}}function _s(...i){let e=i.join(" ");e in fh||(fh[e]=!0,ct(...i))}function Lu(i,e,t){return new Promise(function(n,s){function r(){switch(i.clientWaitSync(e,i.SYNC_FLUSH_COMMANDS_BIT,0)){case i.WAIT_FAILED:s();break;case i.TIMEOUT_EXPIRED:setTimeout(r,t);break;default:n()}}setTimeout(r,t)})}var Du={[zo]:Ho,[ko]:Wo,[Vo]:Xo,[Js]:Go,[Ho]:zo,[Wo]:ko,[Xo]:Vo,[Go]:Js},pi=class{addEventListener(e,t){this._listeners===void 0&&(this._listeners={});let n=this._listeners;n[e]===void 0&&(n[e]=[]),n[e].indexOf(t)===-1&&n[e].push(t)}hasEventListener(e,t){let n=this._listeners;return n===void 0?!1:n[e]!==void 0&&n[e].indexOf(t)!==-1}removeEventListener(e,t){let n=this._listeners;if(n===void 0)return;let s=n[e];if(s!==void 0){let r=s.indexOf(t);r!==-1&&s.splice(r,1)}}dispatchEvent(e){let t=this._listeners;if(t===void 0)return;let n=t[e.type];if(n!==void 0){e.target=this;let s=n.slice(0);for(let r=0,a=s.length;r<a;r++)s[r].call(this,e);e.target=null}}},vn=["00","01","02","03","04","05","06","07","08","09","0a","0b","0c","0d","0e","0f","10","11","12","13","14","15","16","17","18","19","1a","1b","1c","1d","1e","1f","20","21","22","23","24","25","26","27","28","29","2a","2b","2c","2d","2e","2f","30","31","32","33","34","35","36","37","38","39","3a","3b","3c","3d","3e","3f","40","41","42","43","44","45","46","47","48","49","4a","4b","4c","4d","4e","4f","50","51","52","53","54","55","56","57","58","59","5a","5b","5c","5d","5e","5f","60","61","62","63","64","65","66","67","68","69","6a","6b","6c","6d","6e","6f","70","71","72","73","74","75","76","77","78","79","7a","7b","7c","7d","7e","7f","80","81","82","83","84","85","86","87","88","89","8a","8b","8c","8d","8e","8f","90","91","92","93","94","95","96","97","98","99","9a","9b","9c","9d","9e","9f","a0","a1","a2","a3","a4","a5","a6","a7","a8","a9","aa","ab","ac","ad","ae","af","b0","b1","b2","b3","b4","b5","b6","b7","b8","b9","ba","bb","bc","bd","be","bf","c0","c1","c2","c3","c4","c5","c6","c7","c8","c9","ca","cb","cc","cd","ce","cf","d0","d1","d2","d3","d4","d5","d6","d7","d8","d9","da","db","dc","dd","de","df","e0","e1","e2","e3","e4","e5","e6","e7","e8","e9","ea","eb","ec","ed","ee","ef","f0","f1","f2","f3","f4","f5","f6","f7","f8","f9","fa","fb","fc","fd","fe","ff"];var Cc=Math.PI/180,$o=180/Math.PI;function Li(){let i=Math.random()*4294967295|0,e=Math.random()*4294967295|0,t=Math.random()*4294967295|0,n=Math.random()*4294967295|0;return(vn[i&255]+vn[i>>8&255]+vn[i>>16&255]+vn[i>>24&255]+"-"+vn[e&255]+vn[e>>8&255]+"-"+vn[e>>16&15|64]+vn[e>>24&255]+"-"+vn[t&63|128]+vn[t>>8&255]+"-"+vn[t>>16&255]+vn[t>>24&255]+vn[n&255]+vn[n>>8&255]+vn[n>>16&255]+vn[n>>24&255]).toLowerCase()}function Mt(i,e,t){return Math.max(e,Math.min(t,i))}function kf(i,e){return(i%e+e)%e}function Pc(i,e,t){return(1-t)*i+t*e}function hi(i,e){switch(e.constructor){case Float32Array:return i;case Uint32Array:return i/4294967295;case Uint16Array:return i/65535;case Uint8Array:case Uint8ClampedArray:return i/255;case Int32Array:return Math.max(i/2147483647,-1);case Int16Array:return Math.max(i/32767,-1);case Int8Array:return Math.max(i/127,-1);default:throw new Error("THREE.MathUtils: Invalid component type.")}}function zt(i,e){switch(e.constructor){case Float32Array:return i;case Uint32Array:return Math.round(i*4294967295);case Uint16Array:return Math.round(i*65535);case Uint8Array:case Uint8ClampedArray:return Math.round(i*255);case Int32Array:return Math.round(i*2147483647);case Int16Array:return Math.round(i*32767);case Int8Array:return Math.round(i*127);default:throw new Error("THREE.MathUtils: Invalid component type.")}}var ue=class i{static{i.prototype.isVector2=!0}constructor(e=0,t=0){this.x=e,this.y=t}get width(){return this.x}set width(e){this.x=e}get height(){return this.y}set height(e){this.y=e}set(e,t){return this.x=e,this.y=t,this}setScalar(e){return this.x=e,this.y=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;default:throw new Error("THREE.Vector2: index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;default:throw new Error("THREE.Vector2: index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y)}copy(e){return this.x=e.x,this.y=e.y,this}add(e){return this.x+=e.x,this.y+=e.y,this}addScalar(e){return this.x+=e,this.y+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this}subScalar(e){return this.x-=e,this.y-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this}multiply(e){return this.x*=e.x,this.y*=e.y,this}multiplyScalar(e){return this.x*=e,this.y*=e,this}divide(e){return this.x/=e.x,this.y/=e.y,this}divideScalar(e){return this.multiplyScalar(1/e)}applyMatrix3(e){let t=this.x,n=this.y,s=e.elements;return this.x=s[0]*t+s[3]*n+s[6],this.y=s[1]*t+s[4]*n+s[7],this}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this}clamp(e,t){return this.x=Mt(this.x,e.x,t.x),this.y=Mt(this.y,e.y,t.y),this}clampScalar(e,t){return this.x=Mt(this.x,e,t),this.y=Mt(this.y,e,t),this}clampLength(e,t){let n=this.length();return this.divideScalar(n||1).multiplyScalar(Mt(n,e,t))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this}negate(){return this.x=-this.x,this.y=-this.y,this}dot(e){return this.x*e.x+this.y*e.y}cross(e){return this.x*e.y-this.y*e.x}lengthSq(){return this.x*this.x+this.y*this.y}length(){return Math.sqrt(this.x*this.x+this.y*this.y)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)}normalize(){return this.divideScalar(this.length()||1)}angle(){return Math.atan2(-this.y,-this.x)+Math.PI}angleTo(e){let t=Math.sqrt(this.lengthSq()*e.lengthSq());if(t===0)return Math.PI/2;let n=this.dot(e)/t;return Math.acos(Mt(n,-1,1))}distanceTo(e){return Math.sqrt(this.distanceToSquared(e))}distanceToSquared(e){let t=this.x-e.x,n=this.y-e.y;return t*t+n*n}manhattanDistanceTo(e){return Math.abs(this.x-e.x)+Math.abs(this.y-e.y)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this}lerpVectors(e,t,n){return this.x=e.x+(t.x-e.x)*n,this.y=e.y+(t.y-e.y)*n,this}equals(e){return e.x===this.x&&e.y===this.y}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this}rotateAround(e,t){let n=Math.cos(t),s=Math.sin(t),r=this.x-e.x,a=this.y-e.y;return this.x=r*n-a*s+e.x,this.y=r*s+a*n+e.y,this}random(){return this.x=Math.random(),this.y=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y}},mi=class{constructor(e=0,t=0,n=0,s=1){this.isQuaternion=!0,this._x=e,this._y=t,this._z=n,this._w=s}static slerpFlat(e,t,n,s,r,a,o){let l=n[s+0],c=n[s+1],h=n[s+2],f=n[s+3],u=r[a+0],d=r[a+1],g=r[a+2],x=r[a+3];if(f!==x||l!==u||c!==d||h!==g){let m=l*u+c*d+h*g+f*x;m<0&&(u=-u,d=-d,g=-g,x=-x,m=-m);let p=1-o;if(m<.9995){let S=Math.acos(m),A=Math.sin(S);p=Math.sin(p*S)/A,o=Math.sin(o*S)/A,l=l*p+u*o,c=c*p+d*o,h=h*p+g*o,f=f*p+x*o}else{l=l*p+u*o,c=c*p+d*o,h=h*p+g*o,f=f*p+x*o;let S=1/Math.sqrt(l*l+c*c+h*h+f*f);l*=S,c*=S,h*=S,f*=S}}e[t]=l,e[t+1]=c,e[t+2]=h,e[t+3]=f}static multiplyQuaternionsFlat(e,t,n,s,r,a){let o=n[s],l=n[s+1],c=n[s+2],h=n[s+3],f=r[a],u=r[a+1],d=r[a+2],g=r[a+3];return e[t]=o*g+h*f+l*d-c*u,e[t+1]=l*g+h*u+c*f-o*d,e[t+2]=c*g+h*d+o*u-l*f,e[t+3]=h*g-o*f-l*u-c*d,e}get x(){return this._x}set x(e){this._x=e,this._onChangeCallback()}get y(){return this._y}set y(e){this._y=e,this._onChangeCallback()}get z(){return this._z}set z(e){this._z=e,this._onChangeCallback()}get w(){return this._w}set w(e){this._w=e,this._onChangeCallback()}set(e,t,n,s){return this._x=e,this._y=t,this._z=n,this._w=s,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._w)}copy(e){return this._x=e.x,this._y=e.y,this._z=e.z,this._w=e.w,this._onChangeCallback(),this}setFromEuler(e,t=!0){let n=e._x,s=e._y,r=e._z,a=e._order,o=Math.cos,l=Math.sin,c=o(n/2),h=o(s/2),f=o(r/2),u=l(n/2),d=l(s/2),g=l(r/2);switch(a){case"XYZ":this._x=u*h*f+c*d*g,this._y=c*d*f-u*h*g,this._z=c*h*g+u*d*f,this._w=c*h*f-u*d*g;break;case"YXZ":this._x=u*h*f+c*d*g,this._y=c*d*f-u*h*g,this._z=c*h*g-u*d*f,this._w=c*h*f+u*d*g;break;case"ZXY":this._x=u*h*f-c*d*g,this._y=c*d*f+u*h*g,this._z=c*h*g+u*d*f,this._w=c*h*f-u*d*g;break;case"ZYX":this._x=u*h*f-c*d*g,this._y=c*d*f+u*h*g,this._z=c*h*g-u*d*f,this._w=c*h*f+u*d*g;break;case"YZX":this._x=u*h*f+c*d*g,this._y=c*d*f+u*h*g,this._z=c*h*g-u*d*f,this._w=c*h*f-u*d*g;break;case"XZY":this._x=u*h*f-c*d*g,this._y=c*d*f-u*h*g,this._z=c*h*g+u*d*f,this._w=c*h*f+u*d*g;break;default:ct("Quaternion: .setFromEuler() encountered an unknown order: "+a)}return t===!0&&this._onChangeCallback(),this}setFromAxisAngle(e,t){let n=t/2,s=Math.sin(n);return this._x=e.x*s,this._y=e.y*s,this._z=e.z*s,this._w=Math.cos(n),this._onChangeCallback(),this}setFromRotationMatrix(e){let t=e.elements,n=t[0],s=t[4],r=t[8],a=t[1],o=t[5],l=t[9],c=t[2],h=t[6],f=t[10],u=n+o+f;if(u>0){let d=.5/Math.sqrt(u+1);this._w=.25/d,this._x=(h-l)*d,this._y=(r-c)*d,this._z=(a-s)*d}else if(n>o&&n>f){let d=2*Math.sqrt(1+n-o-f);this._w=(h-l)/d,this._x=.25*d,this._y=(s+a)/d,this._z=(r+c)/d}else if(o>f){let d=2*Math.sqrt(1+o-n-f);this._w=(r-c)/d,this._x=(s+a)/d,this._y=.25*d,this._z=(l+h)/d}else{let d=2*Math.sqrt(1+f-n-o);this._w=(a-s)/d,this._x=(r+c)/d,this._y=(l+h)/d,this._z=.25*d}return this._onChangeCallback(),this}setFromUnitVectors(e,t){let n=e.dot(t)+1;return n<1e-8?(n=0,Math.abs(e.x)>Math.abs(e.z)?(this._x=-e.y,this._y=e.x,this._z=0,this._w=n):(this._x=0,this._y=-e.z,this._z=e.y,this._w=n)):(this._x=e.y*t.z-e.z*t.y,this._y=e.z*t.x-e.x*t.z,this._z=e.x*t.y-e.y*t.x,this._w=n),this.normalize()}angleTo(e){return 2*Math.acos(Math.abs(Mt(this.dot(e),-1,1)))}rotateTowards(e,t){let n=this.angleTo(e);if(n===0)return this;let s=Math.min(1,t/n);return this.slerp(e,s),this}identity(){return this.set(0,0,0,1)}invert(){return this.conjugate()}conjugate(){return this._x*=-1,this._y*=-1,this._z*=-1,this._onChangeCallback(),this}dot(e){return this._x*e._x+this._y*e._y+this._z*e._z+this._w*e._w}lengthSq(){return this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w}length(){return Math.sqrt(this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w)}normalize(){let e=this.length();return e===0?(this._x=0,this._y=0,this._z=0,this._w=1):(e=1/e,this._x=this._x*e,this._y=this._y*e,this._z=this._z*e,this._w=this._w*e),this._onChangeCallback(),this}multiply(e){return this.multiplyQuaternions(this,e)}premultiply(e){return this.multiplyQuaternions(e,this)}multiplyQuaternions(e,t){let n=e._x,s=e._y,r=e._z,a=e._w,o=t._x,l=t._y,c=t._z,h=t._w;return this._x=n*h+a*o+s*c-r*l,this._y=s*h+a*l+r*o-n*c,this._z=r*h+a*c+n*l-s*o,this._w=a*h-n*o-s*l-r*c,this._onChangeCallback(),this}slerp(e,t){let n=e._x,s=e._y,r=e._z,a=e._w,o=this.dot(e);o<0&&(n=-n,s=-s,r=-r,a=-a,o=-o);let l=1-t;if(o<.9995){let c=Math.acos(o),h=Math.sin(c);l=Math.sin(l*c)/h,t=Math.sin(t*c)/h,this._x=this._x*l+n*t,this._y=this._y*l+s*t,this._z=this._z*l+r*t,this._w=this._w*l+a*t,this._onChangeCallback()}else this._x=this._x*l+n*t,this._y=this._y*l+s*t,this._z=this._z*l+r*t,this._w=this._w*l+a*t,this.normalize();return this}slerpQuaternions(e,t,n){return this.copy(e).slerp(t,n)}random(){let e=2*Math.PI*Math.random(),t=2*Math.PI*Math.random(),n=Math.random(),s=Math.sqrt(1-n),r=Math.sqrt(n);return this.set(s*Math.sin(e),s*Math.cos(e),r*Math.sin(t),r*Math.cos(t))}equals(e){return e._x===this._x&&e._y===this._y&&e._z===this._z&&e._w===this._w}fromArray(e,t=0){return this._x=e[t],this._y=e[t+1],this._z=e[t+2],this._w=e[t+3],this._onChangeCallback(),this}toArray(e=[],t=0){return e[t]=this._x,e[t+1]=this._y,e[t+2]=this._z,e[t+3]=this._w,e}fromBufferAttribute(e,t){return this._x=e.getX(t),this._y=e.getY(t),this._z=e.getZ(t),this._w=e.getW(t),this._onChangeCallback(),this}toJSON(){return this.toArray()}_onChange(e){return this._onChangeCallback=e,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._w}},I=class i{static{i.prototype.isVector3=!0}constructor(e=0,t=0,n=0){this.x=e,this.y=t,this.z=n}set(e,t,n){return n===void 0&&(n=this.z),this.x=e,this.y=t,this.z=n,this}setScalar(e){return this.x=e,this.y=e,this.z=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setZ(e){return this.z=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;case 2:this.z=t;break;default:throw new Error("THREE.Vector3: index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;case 2:return this.z;default:throw new Error("THREE.Vector3: index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y,this.z)}copy(e){return this.x=e.x,this.y=e.y,this.z=e.z,this}add(e){return this.x+=e.x,this.y+=e.y,this.z+=e.z,this}addScalar(e){return this.x+=e,this.y+=e,this.z+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this.z=e.z+t.z,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this.z+=e.z*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this.z-=e.z,this}subScalar(e){return this.x-=e,this.y-=e,this.z-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this.z=e.z-t.z,this}multiply(e){return this.x*=e.x,this.y*=e.y,this.z*=e.z,this}multiplyScalar(e){return this.x*=e,this.y*=e,this.z*=e,this}multiplyVectors(e,t){return this.x=e.x*t.x,this.y=e.y*t.y,this.z=e.z*t.z,this}applyEuler(e){return this.applyQuaternion(dh.setFromEuler(e))}applyAxisAngle(e,t){return this.applyQuaternion(dh.setFromAxisAngle(e,t))}applyMatrix3(e){let t=this.x,n=this.y,s=this.z,r=e.elements;return this.x=r[0]*t+r[3]*n+r[6]*s,this.y=r[1]*t+r[4]*n+r[7]*s,this.z=r[2]*t+r[5]*n+r[8]*s,this}applyNormalMatrix(e){return this.applyMatrix3(e).normalize()}applyMatrix4(e){let t=this.x,n=this.y,s=this.z,r=e.elements,a=1/(r[3]*t+r[7]*n+r[11]*s+r[15]);return this.x=(r[0]*t+r[4]*n+r[8]*s+r[12])*a,this.y=(r[1]*t+r[5]*n+r[9]*s+r[13])*a,this.z=(r[2]*t+r[6]*n+r[10]*s+r[14])*a,this}applyQuaternion(e){let t=this.x,n=this.y,s=this.z,r=e.x,a=e.y,o=e.z,l=e.w,c=2*(a*s-o*n),h=2*(o*t-r*s),f=2*(r*n-a*t);return this.x=t+l*c+a*f-o*h,this.y=n+l*h+o*c-r*f,this.z=s+l*f+r*h-a*c,this}project(e){return this.applyMatrix4(e.matrixWorldInverse).applyMatrix4(e.projectionMatrix)}unproject(e){return this.applyMatrix4(e.projectionMatrixInverse).applyMatrix4(e.matrixWorld)}transformDirection(e){let t=this.x,n=this.y,s=this.z,r=e.elements;return this.x=r[0]*t+r[4]*n+r[8]*s,this.y=r[1]*t+r[5]*n+r[9]*s,this.z=r[2]*t+r[6]*n+r[10]*s,this.normalize()}divide(e){return this.x/=e.x,this.y/=e.y,this.z/=e.z,this}divideScalar(e){return this.multiplyScalar(1/e)}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this.z=Math.min(this.z,e.z),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this.z=Math.max(this.z,e.z),this}clamp(e,t){return this.x=Mt(this.x,e.x,t.x),this.y=Mt(this.y,e.y,t.y),this.z=Mt(this.z,e.z,t.z),this}clampScalar(e,t){return this.x=Mt(this.x,e,t),this.y=Mt(this.y,e,t),this.z=Mt(this.z,e,t),this}clampLength(e,t){let n=this.length();return this.divideScalar(n||1).multiplyScalar(Mt(n,e,t))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this}dot(e){return this.x*e.x+this.y*e.y+this.z*e.z}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)}normalize(){return this.divideScalar(this.length()||1)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this.z+=(e.z-this.z)*t,this}lerpVectors(e,t,n){return this.x=e.x+(t.x-e.x)*n,this.y=e.y+(t.y-e.y)*n,this.z=e.z+(t.z-e.z)*n,this}cross(e){return this.crossVectors(this,e)}crossVectors(e,t){let n=e.x,s=e.y,r=e.z,a=t.x,o=t.y,l=t.z;return this.x=s*l-r*o,this.y=r*a-n*l,this.z=n*o-s*a,this}projectOnVector(e){let t=e.lengthSq();if(t===0)return this.set(0,0,0);let n=e.dot(this)/t;return this.copy(e).multiplyScalar(n)}projectOnPlane(e){return Ic.copy(this).projectOnVector(e),this.sub(Ic)}reflect(e){return this.sub(Ic.copy(e).multiplyScalar(2*this.dot(e)))}angleTo(e){let t=Math.sqrt(this.lengthSq()*e.lengthSq());if(t===0)return Math.PI/2;let n=this.dot(e)/t;return Math.acos(Mt(n,-1,1))}distanceTo(e){return Math.sqrt(this.distanceToSquared(e))}distanceToSquared(e){let t=this.x-e.x,n=this.y-e.y,s=this.z-e.z;return t*t+n*n+s*s}manhattanDistanceTo(e){return Math.abs(this.x-e.x)+Math.abs(this.y-e.y)+Math.abs(this.z-e.z)}setFromSpherical(e){return this.setFromSphericalCoords(e.radius,e.phi,e.theta)}setFromSphericalCoords(e,t,n){let s=Math.sin(t)*e;return this.x=s*Math.sin(n),this.y=Math.cos(t)*e,this.z=s*Math.cos(n),this}setFromCylindrical(e){return this.setFromCylindricalCoords(e.radius,e.theta,e.y)}setFromCylindricalCoords(e,t,n){return this.x=e*Math.sin(t),this.y=n,this.z=e*Math.cos(t),this}setFromMatrixPosition(e){let t=e.elements;return this.x=t[12],this.y=t[13],this.z=t[14],this}setFromMatrixScale(e){let t=this.setFromMatrixColumn(e,0).length(),n=this.setFromMatrixColumn(e,1).length(),s=this.setFromMatrixColumn(e,2).length();return this.x=t,this.y=n,this.z=s,this}setFromMatrixColumn(e,t){return this.fromArray(e.elements,t*4)}setFromMatrix3Column(e,t){return this.fromArray(e.elements,t*3)}setFromEuler(e){return this.x=e._x,this.y=e._y,this.z=e._z,this}setFromColor(e){return this.x=e.r,this.y=e.g,this.z=e.b,this}equals(e){return e.x===this.x&&e.y===this.y&&e.z===this.z}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this.z=e[t+2],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e[t+2]=this.z,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this.z=e.getZ(t),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this}randomDirection(){let e=Math.random()*Math.PI*2,t=Math.random()*2-1,n=Math.sqrt(1-t*t);return this.x=n*Math.cos(e),this.y=t,this.z=n*Math.sin(e),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z}},Ic=new I,dh=new mi,dt=class i{static{i.prototype.isMatrix3=!0}constructor(e,t,n,s,r,a,o,l,c){this.elements=[1,0,0,0,1,0,0,0,1],e!==void 0&&this.set(e,t,n,s,r,a,o,l,c)}set(e,t,n,s,r,a,o,l,c){let h=this.elements;return h[0]=e,h[1]=s,h[2]=o,h[3]=t,h[4]=r,h[5]=l,h[6]=n,h[7]=a,h[8]=c,this}identity(){return this.set(1,0,0,0,1,0,0,0,1),this}copy(e){let t=this.elements,n=e.elements;return t[0]=n[0],t[1]=n[1],t[2]=n[2],t[3]=n[3],t[4]=n[4],t[5]=n[5],t[6]=n[6],t[7]=n[7],t[8]=n[8],this}extractBasis(e,t,n){return e.setFromMatrix3Column(this,0),t.setFromMatrix3Column(this,1),n.setFromMatrix3Column(this,2),this}setFromMatrix4(e){let t=e.elements;return this.set(t[0],t[4],t[8],t[1],t[5],t[9],t[2],t[6],t[10]),this}multiply(e){return this.multiplyMatrices(this,e)}premultiply(e){return this.multiplyMatrices(e,this)}multiplyMatrices(e,t){let n=e.elements,s=t.elements,r=this.elements,a=n[0],o=n[3],l=n[6],c=n[1],h=n[4],f=n[7],u=n[2],d=n[5],g=n[8],x=s[0],m=s[3],p=s[6],S=s[1],A=s[4],v=s[7],b=s[2],E=s[5],C=s[8];return r[0]=a*x+o*S+l*b,r[3]=a*m+o*A+l*E,r[6]=a*p+o*v+l*C,r[1]=c*x+h*S+f*b,r[4]=c*m+h*A+f*E,r[7]=c*p+h*v+f*C,r[2]=u*x+d*S+g*b,r[5]=u*m+d*A+g*E,r[8]=u*p+d*v+g*C,this}multiplyScalar(e){let t=this.elements;return t[0]*=e,t[3]*=e,t[6]*=e,t[1]*=e,t[4]*=e,t[7]*=e,t[2]*=e,t[5]*=e,t[8]*=e,this}determinant(){let e=this.elements,t=e[0],n=e[1],s=e[2],r=e[3],a=e[4],o=e[5],l=e[6],c=e[7],h=e[8];return t*a*h-t*o*c-n*r*h+n*o*l+s*r*c-s*a*l}invert(){let e=this.elements,t=e[0],n=e[1],s=e[2],r=e[3],a=e[4],o=e[5],l=e[6],c=e[7],h=e[8],f=h*a-o*c,u=o*l-h*r,d=c*r-a*l,g=t*f+n*u+s*d;if(g===0)return this.set(0,0,0,0,0,0,0,0,0);let x=1/g;return e[0]=f*x,e[1]=(s*c-h*n)*x,e[2]=(o*n-s*a)*x,e[3]=u*x,e[4]=(h*t-s*l)*x,e[5]=(s*r-o*t)*x,e[6]=d*x,e[7]=(n*l-c*t)*x,e[8]=(a*t-n*r)*x,this}transpose(){let e,t=this.elements;return e=t[1],t[1]=t[3],t[3]=e,e=t[2],t[2]=t[6],t[6]=e,e=t[5],t[5]=t[7],t[7]=e,this}getNormalMatrix(e){return this.setFromMatrix4(e).invert().transpose()}transposeIntoArray(e){let t=this.elements;return e[0]=t[0],e[1]=t[3],e[2]=t[6],e[3]=t[1],e[4]=t[4],e[5]=t[7],e[6]=t[2],e[7]=t[5],e[8]=t[8],this}setUvTransform(e,t,n,s,r,a,o){let l=Math.cos(r),c=Math.sin(r);return this.set(n*l,n*c,-n*(l*a+c*o)+a+e,-s*c,s*l,-s*(-c*a+l*o)+o+t,0,0,1),this}scale(e,t){return _s("Matrix3: .scale() is deprecated. Use .makeScale() instead."),this.premultiply(Lc.makeScale(e,t)),this}rotate(e){return _s("Matrix3: .rotate() is deprecated. Use .makeRotation() instead."),this.premultiply(Lc.makeRotation(-e)),this}translate(e,t){return _s("Matrix3: .translate() is deprecated. Use .makeTranslation() instead."),this.premultiply(Lc.makeTranslation(e,t)),this}makeTranslation(e,t){return e.isVector2?this.set(1,0,e.x,0,1,e.y,0,0,1):this.set(1,0,e,0,1,t,0,0,1),this}makeRotation(e){let t=Math.cos(e),n=Math.sin(e);return this.set(t,-n,0,n,t,0,0,0,1),this}makeScale(e,t){return this.set(e,0,0,0,t,0,0,0,1),this}equals(e){let t=this.elements,n=e.elements;for(let s=0;s<9;s++)if(t[s]!==n[s])return!1;return!0}fromArray(e,t=0){for(let n=0;n<9;n++)this.elements[n]=e[n+t];return this}toArray(e=[],t=0){let n=this.elements;return e[t]=n[0],e[t+1]=n[1],e[t+2]=n[2],e[t+3]=n[3],e[t+4]=n[4],e[t+5]=n[5],e[t+6]=n[6],e[t+7]=n[7],e[t+8]=n[8],e}clone(){return new this.constructor().fromArray(this.elements)}},Lc=new dt,ph=new dt().set(.4123908,.3575843,.1804808,.212639,.7151687,.0721923,.0193308,.1191948,.9505322),mh=new dt().set(3.2409699,-1.5373832,-.4986108,-.9692436,1.8759675,.0415551,.0556301,-.203977,1.0569715);function Vf(){let i={enabled:!0,workingColorSpace:Yr,spaces:{},convert:function(s,r,a){return this.enabled===!1||r===a||!r||!a||(this.spaces[r].transfer===Pt&&(s.r=Di(s.r),s.g=Di(s.g),s.b=Di(s.b)),this.spaces[r].primaries!==this.spaces[a].primaries&&(s.applyMatrix3(this.spaces[r].toXYZ),s.applyMatrix3(this.spaces[a].fromXYZ)),this.spaces[a].transfer===Pt&&(s.r=Zs(s.r),s.g=Zs(s.g),s.b=Zs(s.b))),s},workingToColorSpace:function(s,r){return this.convert(s,this.workingColorSpace,r)},colorSpaceToWorking:function(s,r){return this.convert(s,r,this.workingColorSpace)},getPrimaries:function(s){return this.spaces[s].primaries},getTransfer:function(s){return s===ti?$r:this.spaces[s].transfer},getToneMappingMode:function(s){return this.spaces[s].outputColorSpaceConfig.toneMappingMode||"standard"},getLuminanceCoefficients:function(s,r=this.workingColorSpace){return s.fromArray(this.spaces[r].luminanceCoefficients)},define:function(s){Object.assign(this.spaces,s)},_getMatrix:function(s,r,a){return s.copy(this.spaces[r].toXYZ).multiply(this.spaces[a].fromXYZ)},_getDrawingBufferColorSpace:function(s){return this.spaces[s].outputColorSpaceConfig.drawingBufferColorSpace},_getUnpackColorSpace:function(s=this.workingColorSpace){return this.spaces[s].workingColorSpaceConfig.unpackColorSpace},fromWorkingColorSpace:function(s,r){return _s("ColorManagement: .fromWorkingColorSpace() has been renamed to .workingToColorSpace()."),i.workingToColorSpace(s,r)},toWorkingColorSpace:function(s,r){return _s("ColorManagement: .toWorkingColorSpace() has been renamed to .colorSpaceToWorking()."),i.colorSpaceToWorking(s,r)}},e=[.64,.33,.3,.6,.15,.06],t=[.2126,.7152,.0722],n=[.3127,.329];return i.define({[Yr]:{primaries:e,whitePoint:n,transfer:$r,toXYZ:ph,fromXYZ:mh,luminanceCoefficients:t,workingColorSpaceConfig:{unpackColorSpace:Wt},outputColorSpaceConfig:{drawingBufferColorSpace:Wt}},[Wt]:{primaries:e,whitePoint:n,transfer:Pt,toXYZ:ph,fromXYZ:mh,luminanceCoefficients:t,outputColorSpaceConfig:{drawingBufferColorSpace:Wt}}}),i}var St=Vf();function Di(i){return i<.04045?i*.0773993808:Math.pow(i*.9478672986+.0521327014,2.4)}function Zs(i){return i<.0031308?i*12.92:1.055*Math.pow(i,.41666)-.055}var Ps,Zo=class{static getDataURL(e,t="image/png"){if(/^data:/i.test(e.src)||typeof HTMLCanvasElement>"u")return e.src;let n;if(e instanceof HTMLCanvasElement)n=e;else{Ps===void 0&&(Ps=js("canvas")),Ps.width=e.width,Ps.height=e.height;let s=Ps.getContext("2d");e instanceof ImageData?s.putImageData(e,0,0):s.drawImage(e,0,0,e.width,e.height),n=Ps}return n.toDataURL(t)}static sRGBToLinear(e){if(typeof HTMLImageElement<"u"&&e instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&e instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&e instanceof ImageBitmap){let t=js("canvas");t.width=e.width,t.height=e.height;let n=t.getContext("2d");n.drawImage(e,0,0,e.width,e.height);let s=n.getImageData(0,0,e.width,e.height),r=s.data;for(let a=0;a<r.length;a++)r[a]=Di(r[a]/255)*255;return n.putImageData(s,0,0),t}else if(e.data){let t=e.data.slice(0);for(let n=0;n<t.length;n++)t instanceof Uint8Array||t instanceof Uint8ClampedArray?t[n]=Math.floor(Di(t[n]/255)*255):t[n]=Di(t[n]);return{data:t,width:e.width,height:e.height}}else return ct("ImageUtils.sRGBToLinear(): Unsupported image type. No color space conversion applied."),e}},Gf=0,er=class{constructor(e=null){this.isTextureSource=!0,Object.defineProperty(this,"id",{value:Gf++}),this.uuid=Li(),this.data=e,this.dataReady=!0,this.version=0}getSize(e){let t=this.data;return typeof HTMLVideoElement<"u"&&t instanceof HTMLVideoElement?e.set(t.videoWidth,t.videoHeight,0):typeof VideoFrame<"u"&&t instanceof VideoFrame?e.set(t.displayWidth,t.displayHeight,0):t!==null?e.set(t.width,t.height,t.depth||0):e.set(0,0,0),e}set needsUpdate(e){e===!0&&this.version++}toJSON(e){let t=e===void 0||typeof e=="string";if(!t&&e.images[this.uuid]!==void 0)return e.images[this.uuid];let n={uuid:this.uuid,url:""},s=this.data;if(s!==null){let r;if(Array.isArray(s)){r=[];for(let a=0,o=s.length;a<o;a++)s[a].isDataTexture?r.push(Dc(s[a].image)):r.push(Dc(s[a]))}else r=Dc(s);n.url=r}return t||(e.images[this.uuid]=n),n}};function Dc(i){return typeof HTMLImageElement<"u"&&i instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&i instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&i instanceof ImageBitmap?Zo.getDataURL(i):i.data?{data:Array.from(i.data),width:i.width,height:i.height,type:i.data.constructor.name}:(ct("Texture: Unable to serialize Texture."),{})}var Wf=0,Nc=new I,fn=class i extends pi{constructor(e=i.DEFAULT_IMAGE,t=i.DEFAULT_MAPPING,n=ui,s=ui,r=gn,a=xi,o=Vn,l=Rn,c=i.DEFAULT_ANISOTROPY,h=ti){super(),this.isTexture=!0,Object.defineProperty(this,"id",{value:Wf++}),this.uuid=Li(),this.name="",this.source=new er(e),this.mipmaps=[],this.mapping=t,this.channel=0,this.wrapS=n,this.wrapT=s,this.magFilter=r,this.minFilter=a,this.anisotropy=c,this.format=o,this.internalFormat=null,this.type=l,this.offset=new ue(0,0),this.repeat=new ue(1,1),this.center=new ue(0,0),this.rotation=0,this.matrixAutoUpdate=!0,this.matrix=new dt,this.generateMipmaps=!0,this.premultiplyAlpha=!1,this.flipY=!0,this.unpackAlignment=4,this.colorSpace=h,this.userData={},this.updateRanges=[],this.version=0,this.onUpdate=null,this.renderTarget=null,this.isRenderTargetTexture=!1,this.isArrayTexture=!!(e&&e.depth&&e.depth>1),this.pmremVersion=0,this.normalized=!1}get width(){return this.source.getSize(Nc).x}get height(){return this.source.getSize(Nc).y}get depth(){return this.source.getSize(Nc).z}get image(){return this.source.data}set image(e){this.source.data=e}updateMatrix(){this.matrix.setUvTransform(this.offset.x,this.offset.y,this.repeat.x,this.repeat.y,this.rotation,this.center.x,this.center.y)}addUpdateRange(e,t){this.updateRanges.push({start:e,count:t})}clearUpdateRanges(){this.updateRanges.length=0}clone(){return new this.constructor().copy(this)}copy(e){return this.name=e.name,this.source=e.source,this.mipmaps=e.mipmaps.slice(0),this.mapping=e.mapping,this.channel=e.channel,this.wrapS=e.wrapS,this.wrapT=e.wrapT,this.magFilter=e.magFilter,this.minFilter=e.minFilter,this.anisotropy=e.anisotropy,this.format=e.format,this.internalFormat=e.internalFormat,this.type=e.type,this.normalized=e.normalized,this.offset.copy(e.offset),this.repeat.copy(e.repeat),this.center.copy(e.center),this.rotation=e.rotation,this.matrixAutoUpdate=e.matrixAutoUpdate,this.matrix.copy(e.matrix),this.generateMipmaps=e.generateMipmaps,this.premultiplyAlpha=e.premultiplyAlpha,this.flipY=e.flipY,this.unpackAlignment=e.unpackAlignment,this.colorSpace=e.colorSpace,this.renderTarget=e.renderTarget,this.isRenderTargetTexture=e.isRenderTargetTexture,this.isArrayTexture=e.isArrayTexture,this.userData=JSON.parse(JSON.stringify(e.userData)),this.needsUpdate=!0,this}setValues(e){for(let t in e){let n=e[t];if(n===void 0){ct(`Texture.setValues(): parameter '${t}' has value of undefined.`);continue}let s=this[t];if(s===void 0){ct(`Texture.setValues(): property '${t}' does not exist.`);continue}s&&n&&s.isVector2&&n.isVector2||s&&n&&s.isVector3&&n.isVector3||s&&n&&s.isMatrix3&&n.isMatrix3?s.copy(n):this[t]=n}}toJSON(e){let t=e===void 0||typeof e=="string";if(!t&&e.textures[this.uuid]!==void 0)return e.textures[this.uuid];let n={metadata:{version:4.7,type:"Texture",generator:"Texture.toJSON"},uuid:this.uuid,name:this.name,image:this.source.toJSON(e).uuid,mapping:this.mapping,channel:this.channel,repeat:[this.repeat.x,this.repeat.y],offset:[this.offset.x,this.offset.y],center:[this.center.x,this.center.y],rotation:this.rotation,wrap:[this.wrapS,this.wrapT],format:this.format,internalFormat:this.internalFormat,type:this.type,normalized:this.normalized,colorSpace:this.colorSpace,minFilter:this.minFilter,magFilter:this.magFilter,anisotropy:this.anisotropy,flipY:this.flipY,generateMipmaps:this.generateMipmaps,premultiplyAlpha:this.premultiplyAlpha,unpackAlignment:this.unpackAlignment};return Object.keys(this.userData).length>0&&(n.userData=this.userData),t||(e.textures[this.uuid]=n),n}dispose(){this.dispatchEvent({type:"dispose"})}transformUv(e){if(this.mapping!==S0)return e;if(e.applyMatrix3(this.matrix),e.x<0||e.x>1)switch(this.wrapS){case Yi:e.x=e.x-Math.floor(e.x);break;case ui:e.x=e.x<0?0:1;break;case qo:Math.abs(Math.floor(e.x)%2)===1?e.x=Math.ceil(e.x)-e.x:e.x=e.x-Math.floor(e.x);break}if(e.y<0||e.y>1)switch(this.wrapT){case Yi:e.y=e.y-Math.floor(e.y);break;case ui:e.y=e.y<0?0:1;break;case qo:Math.abs(Math.floor(e.y)%2)===1?e.y=Math.ceil(e.y)-e.y:e.y=e.y-Math.floor(e.y);break}return this.flipY&&(e.y=1-e.y),e}set needsUpdate(e){e===!0&&(this.version++,this.source.needsUpdate=!0)}set needsPMREMUpdate(e){e===!0&&this.pmremVersion++}};fn.DEFAULT_IMAGE=null;fn.DEFAULT_MAPPING=S0;fn.DEFAULT_ANISOTROPY=1;var Gt=class i{static{i.prototype.isVector4=!0}constructor(e=0,t=0,n=0,s=1){this.x=e,this.y=t,this.z=n,this.w=s}get width(){return this.z}set width(e){this.z=e}get height(){return this.w}set height(e){this.w=e}set(e,t,n,s){return this.x=e,this.y=t,this.z=n,this.w=s,this}setScalar(e){return this.x=e,this.y=e,this.z=e,this.w=e,this}setX(e){return this.x=e,this}setY(e){return this.y=e,this}setZ(e){return this.z=e,this}setW(e){return this.w=e,this}setComponent(e,t){switch(e){case 0:this.x=t;break;case 1:this.y=t;break;case 2:this.z=t;break;case 3:this.w=t;break;default:throw new Error("THREE.Vector4: index is out of range: "+e)}return this}getComponent(e){switch(e){case 0:return this.x;case 1:return this.y;case 2:return this.z;case 3:return this.w;default:throw new Error("THREE.Vector4: index is out of range: "+e)}}clone(){return new this.constructor(this.x,this.y,this.z,this.w)}copy(e){return this.x=e.x,this.y=e.y,this.z=e.z,this.w=e.w!==void 0?e.w:1,this}add(e){return this.x+=e.x,this.y+=e.y,this.z+=e.z,this.w+=e.w,this}addScalar(e){return this.x+=e,this.y+=e,this.z+=e,this.w+=e,this}addVectors(e,t){return this.x=e.x+t.x,this.y=e.y+t.y,this.z=e.z+t.z,this.w=e.w+t.w,this}addScaledVector(e,t){return this.x+=e.x*t,this.y+=e.y*t,this.z+=e.z*t,this.w+=e.w*t,this}sub(e){return this.x-=e.x,this.y-=e.y,this.z-=e.z,this.w-=e.w,this}subScalar(e){return this.x-=e,this.y-=e,this.z-=e,this.w-=e,this}subVectors(e,t){return this.x=e.x-t.x,this.y=e.y-t.y,this.z=e.z-t.z,this.w=e.w-t.w,this}multiply(e){return this.x*=e.x,this.y*=e.y,this.z*=e.z,this.w*=e.w,this}multiplyScalar(e){return this.x*=e,this.y*=e,this.z*=e,this.w*=e,this}applyMatrix4(e){let t=this.x,n=this.y,s=this.z,r=this.w,a=e.elements;return this.x=a[0]*t+a[4]*n+a[8]*s+a[12]*r,this.y=a[1]*t+a[5]*n+a[9]*s+a[13]*r,this.z=a[2]*t+a[6]*n+a[10]*s+a[14]*r,this.w=a[3]*t+a[7]*n+a[11]*s+a[15]*r,this}divide(e){return this.x/=e.x,this.y/=e.y,this.z/=e.z,this.w/=e.w,this}divideScalar(e){return this.multiplyScalar(1/e)}setAxisAngleFromQuaternion(e){this.w=2*Math.acos(e.w);let t=Math.sqrt(1-e.w*e.w);return t<1e-4?(this.x=1,this.y=0,this.z=0):(this.x=e.x/t,this.y=e.y/t,this.z=e.z/t),this}setAxisAngleFromRotationMatrix(e){let t,n,s,r,l=e.elements,c=l[0],h=l[4],f=l[8],u=l[1],d=l[5],g=l[9],x=l[2],m=l[6],p=l[10];if(Math.abs(h-u)<.01&&Math.abs(f-x)<.01&&Math.abs(g-m)<.01){if(Math.abs(h+u)<.1&&Math.abs(f+x)<.1&&Math.abs(g+m)<.1&&Math.abs(c+d+p-3)<.1)return this.set(1,0,0,0),this;t=Math.PI;let A=(c+1)/2,v=(d+1)/2,b=(p+1)/2,E=(h+u)/4,C=(f+x)/4,y=(g+m)/4;return A>v&&A>b?A<.01?(n=0,s=.707106781,r=.707106781):(n=Math.sqrt(A),s=E/n,r=C/n):v>b?v<.01?(n=.707106781,s=0,r=.707106781):(s=Math.sqrt(v),n=E/s,r=y/s):b<.01?(n=.707106781,s=.707106781,r=0):(r=Math.sqrt(b),n=C/r,s=y/r),this.set(n,s,r,t),this}let S=Math.sqrt((m-g)*(m-g)+(f-x)*(f-x)+(u-h)*(u-h));return Math.abs(S)<.001&&(S=1),this.x=(m-g)/S,this.y=(f-x)/S,this.z=(u-h)/S,this.w=Math.acos((c+d+p-1)/2),this}setFromMatrixPosition(e){let t=e.elements;return this.x=t[12],this.y=t[13],this.z=t[14],this.w=t[15],this}min(e){return this.x=Math.min(this.x,e.x),this.y=Math.min(this.y,e.y),this.z=Math.min(this.z,e.z),this.w=Math.min(this.w,e.w),this}max(e){return this.x=Math.max(this.x,e.x),this.y=Math.max(this.y,e.y),this.z=Math.max(this.z,e.z),this.w=Math.max(this.w,e.w),this}clamp(e,t){return this.x=Mt(this.x,e.x,t.x),this.y=Mt(this.y,e.y,t.y),this.z=Mt(this.z,e.z,t.z),this.w=Mt(this.w,e.w,t.w),this}clampScalar(e,t){return this.x=Mt(this.x,e,t),this.y=Mt(this.y,e,t),this.z=Mt(this.z,e,t),this.w=Mt(this.w,e,t),this}clampLength(e,t){let n=this.length();return this.divideScalar(n||1).multiplyScalar(Mt(n,e,t))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this.w=Math.floor(this.w),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this.w=Math.ceil(this.w),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this.w=Math.round(this.w),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this.w=Math.trunc(this.w),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this.w=-this.w,this}dot(e){return this.x*e.x+this.y*e.y+this.z*e.z+this.w*e.w}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)+Math.abs(this.w)}normalize(){return this.divideScalar(this.length()||1)}setLength(e){return this.normalize().multiplyScalar(e)}lerp(e,t){return this.x+=(e.x-this.x)*t,this.y+=(e.y-this.y)*t,this.z+=(e.z-this.z)*t,this.w+=(e.w-this.w)*t,this}lerpVectors(e,t,n){return this.x=e.x+(t.x-e.x)*n,this.y=e.y+(t.y-e.y)*n,this.z=e.z+(t.z-e.z)*n,this.w=e.w+(t.w-e.w)*n,this}equals(e){return e.x===this.x&&e.y===this.y&&e.z===this.z&&e.w===this.w}fromArray(e,t=0){return this.x=e[t],this.y=e[t+1],this.z=e[t+2],this.w=e[t+3],this}toArray(e=[],t=0){return e[t]=this.x,e[t+1]=this.y,e[t+2]=this.z,e[t+3]=this.w,e}fromBufferAttribute(e,t){return this.x=e.getX(t),this.y=e.getY(t),this.z=e.getZ(t),this.w=e.getW(t),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this.w=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z,yield this.w}},Jo=class extends pi{constructor(e=1,t=1,n={}){super(),n=Object.assign({generateMipmaps:!1,internalFormat:null,minFilter:gn,depthBuffer:!0,stencilBuffer:!1,resolveColorBuffer:!0,resolveDepthBuffer:!0,resolveStencilBuffer:!0,storeMultisampledColorBuffer:!0,storeMultisampledDepthBuffer:!0,storeMultisampledStencilBuffer:!0,depthTexture:null,samples:0,count:1,depth:1,multiview:!1,useArrayDepthTexture:!1},n),this.isRenderTarget=!0,this.width=e,this.height=t,this.depth=n.depth,this.scissor=new Gt(0,0,e,t),this.scissorTest=!1,this.viewport=new Gt(0,0,e,t),this.textures=[];let s={width:e,height:t,depth:n.depth},r=new fn(s),a=n.count;for(let o=0;o<a;o++)this.textures[o]=r.clone(),this.textures[o].isRenderTargetTexture=!0,this.textures[o].renderTarget=this;this._setTextureOptions(n),this.depthBuffer=n.depthBuffer,this.stencilBuffer=n.stencilBuffer,this.resolveColorBuffer=n.resolveColorBuffer,this.resolveDepthBuffer=n.resolveDepthBuffer,this.resolveStencilBuffer=n.resolveStencilBuffer,this.storeMultisampledColorBuffer=n.storeMultisampledColorBuffer,this.storeMultisampledDepthBuffer=n.storeMultisampledDepthBuffer,this.storeMultisampledStencilBuffer=n.storeMultisampledStencilBuffer,this._depthTexture=null,this.depthTexture=n.depthTexture,this.samples=n.samples,this.multiview=n.multiview,this.useArrayDepthTexture=n.useArrayDepthTexture}_setTextureOptions(e={}){let t={minFilter:gn,generateMipmaps:!1,flipY:!1,internalFormat:null};e.mapping!==void 0&&(t.mapping=e.mapping),e.wrapS!==void 0&&(t.wrapS=e.wrapS),e.wrapT!==void 0&&(t.wrapT=e.wrapT),e.wrapR!==void 0&&(t.wrapR=e.wrapR),e.magFilter!==void 0&&(t.magFilter=e.magFilter),e.minFilter!==void 0&&(t.minFilter=e.minFilter),e.format!==void 0&&(t.format=e.format),e.type!==void 0&&(t.type=e.type),e.anisotropy!==void 0&&(t.anisotropy=e.anisotropy),e.colorSpace!==void 0&&(t.colorSpace=e.colorSpace),e.flipY!==void 0&&(t.flipY=e.flipY),e.generateMipmaps!==void 0&&(t.generateMipmaps=e.generateMipmaps),e.internalFormat!==void 0&&(t.internalFormat=e.internalFormat);for(let n=0;n<this.textures.length;n++)this.textures[n].setValues(t)}get texture(){return this.textures[0]}set texture(e){this.textures[0]=e}set depthTexture(e){this._depthTexture!==null&&this._depthTexture.renderTarget===this&&(this._depthTexture.renderTarget=null),e!==null&&e.renderTarget===null&&(e.renderTarget=this),this._depthTexture=e}get depthTexture(){return this._depthTexture}setSize(e,t,n=1){if(this.width!==e||this.height!==t||this.depth!==n){this.width=e,this.height=t,this.depth=n;for(let s=0,r=this.textures.length;s<r;s++)this.textures[s].image.width=e,this.textures[s].image.height=t,this.textures[s].image.depth=n,this.textures[s].isData3DTexture!==!0&&(this.textures[s].isArrayTexture=this.textures[s].image.depth>1);this.dispose()}this.viewport.set(0,0,e,t),this.scissor.set(0,0,e,t)}clone(){return new this.constructor().copy(this)}copy(e){this.width=e.width,this.height=e.height,this.depth=e.depth,this.scissor.copy(e.scissor),this.scissorTest=e.scissorTest,this.viewport.copy(e.viewport),this.textures.length=0;for(let t=0,n=e.textures.length;t<n;t++){this.textures[t]=e.textures[t].clone(),this.textures[t].isRenderTargetTexture=!0,this.textures[t].renderTarget=this;let s=Object.assign({},e.textures[t].image);this.textures[t].source=new er(s)}if(this.depthBuffer=e.depthBuffer,this.stencilBuffer=e.stencilBuffer,this.resolveColorBuffer=e.resolveColorBuffer,this.resolveDepthBuffer=e.resolveDepthBuffer,this.resolveStencilBuffer=e.resolveStencilBuffer,this.storeMultisampledColorBuffer=e.storeMultisampledColorBuffer,this.storeMultisampledDepthBuffer=e.storeMultisampledDepthBuffer,this.storeMultisampledStencilBuffer=e.storeMultisampledStencilBuffer,e.depthTexture!==null)if(e.depthTexture.renderTarget===e){let t=e.depthTexture.clone();t.renderTarget=null,this.depthTexture=t}else this.depthTexture=e.depthTexture;return this.samples=e.samples,this.multiview=e.multiview,this.useArrayDepthTexture=e.useArrayDepthTexture,this}dispose(){this.dispatchEvent({type:"dispose"})}},$t=class extends Jo{constructor(e=1,t=1,n={}){super(e,t,n),this.isWebGLRenderTarget=!0}},Jr=class extends fn{constructor(e=null,t=1,n=1,s=1){super(null),this.isDataArrayTexture=!0,this.image={data:e,width:t,height:n,depth:s},this.magFilter=un,this.minFilter=un,this.wrapR=ui,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1,this.layerUpdates=new Set}copy(e){return super.copy(e),this.wrapR=e.wrapR,this}addLayerUpdate(e){this.layerUpdates.add(e)}clearLayerUpdates(){this.layerUpdates.clear()}};var Ko=class extends fn{constructor(e=null,t=1,n=1,s=1){super(null),this.isData3DTexture=!0,this.image={data:e,width:t,height:n,depth:s},this.magFilter=un,this.minFilter=un,this.wrapR=ui,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}copy(e){return super.copy(e),this.wrapR=e.wrapR,this}};var Rt=class i{static{i.prototype.isMatrix4=!0}constructor(e,t,n,s,r,a,o,l,c,h,f,u,d,g,x,m){this.elements=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1],e!==void 0&&this.set(e,t,n,s,r,a,o,l,c,h,f,u,d,g,x,m)}set(e,t,n,s,r,a,o,l,c,h,f,u,d,g,x,m){let p=this.elements;return p[0]=e,p[4]=t,p[8]=n,p[12]=s,p[1]=r,p[5]=a,p[9]=o,p[13]=l,p[2]=c,p[6]=h,p[10]=f,p[14]=u,p[3]=d,p[7]=g,p[11]=x,p[15]=m,this}identity(){return this.set(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1),this}clone(){return new i().fromArray(this.elements)}copy(e){let t=this.elements,n=e.elements;return t[0]=n[0],t[1]=n[1],t[2]=n[2],t[3]=n[3],t[4]=n[4],t[5]=n[5],t[6]=n[6],t[7]=n[7],t[8]=n[8],t[9]=n[9],t[10]=n[10],t[11]=n[11],t[12]=n[12],t[13]=n[13],t[14]=n[14],t[15]=n[15],this}copyPosition(e){let t=this.elements,n=e.elements;return t[12]=n[12],t[13]=n[13],t[14]=n[14],this}setFromMatrix3(e){let t=e.elements;return this.set(t[0],t[3],t[6],0,t[1],t[4],t[7],0,t[2],t[5],t[8],0,0,0,0,1),this}extractBasis(e,t,n){return this.determinantAffine()===0?(e.set(1,0,0),t.set(0,1,0),n.set(0,0,1),this):(e.setFromMatrixColumn(this,0),t.setFromMatrixColumn(this,1),n.setFromMatrixColumn(this,2),this)}makeBasis(e,t,n){return this.set(e.x,t.x,n.x,0,e.y,t.y,n.y,0,e.z,t.z,n.z,0,0,0,0,1),this}extractRotation(e){if(e.determinantAffine()===0)return this.identity();let t=this.elements,n=e.elements,s=1/Is.setFromMatrixColumn(e,0).length(),r=1/Is.setFromMatrixColumn(e,1).length(),a=1/Is.setFromMatrixColumn(e,2).length();return t[0]=n[0]*s,t[1]=n[1]*s,t[2]=n[2]*s,t[3]=0,t[4]=n[4]*r,t[5]=n[5]*r,t[6]=n[6]*r,t[7]=0,t[8]=n[8]*a,t[9]=n[9]*a,t[10]=n[10]*a,t[11]=0,t[12]=0,t[13]=0,t[14]=0,t[15]=1,this}makeRotationFromEuler(e){let t=this.elements,n=e.x,s=e.y,r=e.z,a=Math.cos(n),o=Math.sin(n),l=Math.cos(s),c=Math.sin(s),h=Math.cos(r),f=Math.sin(r);if(e.order==="XYZ"){let u=a*h,d=a*f,g=o*h,x=o*f;t[0]=l*h,t[4]=-l*f,t[8]=c,t[1]=d+g*c,t[5]=u-x*c,t[9]=-o*l,t[2]=x-u*c,t[6]=g+d*c,t[10]=a*l}else if(e.order==="YXZ"){let u=l*h,d=l*f,g=c*h,x=c*f;t[0]=u+x*o,t[4]=g*o-d,t[8]=a*c,t[1]=a*f,t[5]=a*h,t[9]=-o,t[2]=d*o-g,t[6]=x+u*o,t[10]=a*l}else if(e.order==="ZXY"){let u=l*h,d=l*f,g=c*h,x=c*f;t[0]=u-x*o,t[4]=-a*f,t[8]=g+d*o,t[1]=d+g*o,t[5]=a*h,t[9]=x-u*o,t[2]=-a*c,t[6]=o,t[10]=a*l}else if(e.order==="ZYX"){let u=a*h,d=a*f,g=o*h,x=o*f;t[0]=l*h,t[4]=g*c-d,t[8]=u*c+x,t[1]=l*f,t[5]=x*c+u,t[9]=d*c-g,t[2]=-c,t[6]=o*l,t[10]=a*l}else if(e.order==="YZX"){let u=a*l,d=a*c,g=o*l,x=o*c;t[0]=l*h,t[4]=x-u*f,t[8]=g*f+d,t[1]=f,t[5]=a*h,t[9]=-o*h,t[2]=-c*h,t[6]=d*f+g,t[10]=u-x*f}else if(e.order==="XZY"){let u=a*l,d=a*c,g=o*l,x=o*c;t[0]=l*h,t[4]=-f,t[8]=c*h,t[1]=u*f+x,t[5]=a*h,t[9]=d*f-g,t[2]=g*f-d,t[6]=o*h,t[10]=x*f+u}return t[3]=0,t[7]=0,t[11]=0,t[12]=0,t[13]=0,t[14]=0,t[15]=1,this}makeRotationFromQuaternion(e){return this.compose(Xf,e,qf)}lookAt(e,t,n){let s=this.elements;return Cn.subVectors(e,t),Cn.lengthSq()===0&&(Cn.z=1),Cn.normalize(),Vi.crossVectors(n,Cn),Vi.lengthSq()===0&&(Math.abs(n.z)===1?Cn.x+=1e-4:Cn.z+=1e-4,Cn.normalize(),Vi.crossVectors(n,Cn)),Vi.normalize(),ro.crossVectors(Cn,Vi),s[0]=Vi.x,s[4]=ro.x,s[8]=Cn.x,s[1]=Vi.y,s[5]=ro.y,s[9]=Cn.y,s[2]=Vi.z,s[6]=ro.z,s[10]=Cn.z,this}multiply(e){return this.multiplyMatrices(this,e)}premultiply(e){return this.multiplyMatrices(e,this)}multiplyMatrices(e,t){let n=e.elements,s=t.elements,r=this.elements,a=n[0],o=n[4],l=n[8],c=n[12],h=n[1],f=n[5],u=n[9],d=n[13],g=n[2],x=n[6],m=n[10],p=n[14],S=n[3],A=n[7],v=n[11],b=n[15],E=s[0],C=s[4],y=s[8],w=s[12],P=s[1],U=s[5],B=s[9],W=s[13],F=s[2],V=s[6],se=s[10],K=s[14],de=s[3],te=s[7],ae=s[11],O=s[15];return r[0]=a*E+o*P+l*F+c*de,r[4]=a*C+o*U+l*V+c*te,r[8]=a*y+o*B+l*se+c*ae,r[12]=a*w+o*W+l*K+c*O,r[1]=h*E+f*P+u*F+d*de,r[5]=h*C+f*U+u*V+d*te,r[9]=h*y+f*B+u*se+d*ae,r[13]=h*w+f*W+u*K+d*O,r[2]=g*E+x*P+m*F+p*de,r[6]=g*C+x*U+m*V+p*te,r[10]=g*y+x*B+m*se+p*ae,r[14]=g*w+x*W+m*K+p*O,r[3]=S*E+A*P+v*F+b*de,r[7]=S*C+A*U+v*V+b*te,r[11]=S*y+A*B+v*se+b*ae,r[15]=S*w+A*W+v*K+b*O,this}multiplyScalar(e){let t=this.elements;return t[0]*=e,t[4]*=e,t[8]*=e,t[12]*=e,t[1]*=e,t[5]*=e,t[9]*=e,t[13]*=e,t[2]*=e,t[6]*=e,t[10]*=e,t[14]*=e,t[3]*=e,t[7]*=e,t[11]*=e,t[15]*=e,this}determinant(){let e=this.elements,t=e[0],n=e[4],s=e[8],r=e[12],a=e[1],o=e[5],l=e[9],c=e[13],h=e[2],f=e[6],u=e[10],d=e[14],g=e[3],x=e[7],m=e[11],p=e[15],S=l*d-c*u,A=o*d-c*f,v=o*u-l*f,b=a*d-c*h,E=a*u-l*h,C=a*f-o*h;return t*(x*S-m*A+p*v)-n*(g*S-m*b+p*E)+s*(g*A-x*b+p*C)-r*(g*v-x*E+m*C)}determinantAffine(){let e=this.elements,t=e[0],n=e[4],s=e[8],r=e[1],a=e[5],o=e[9],l=e[2],c=e[6],h=e[10];return t*(a*h-o*c)-n*(r*h-o*l)+s*(r*c-a*l)}transpose(){let e=this.elements,t;return t=e[1],e[1]=e[4],e[4]=t,t=e[2],e[2]=e[8],e[8]=t,t=e[6],e[6]=e[9],e[9]=t,t=e[3],e[3]=e[12],e[12]=t,t=e[7],e[7]=e[13],e[13]=t,t=e[11],e[11]=e[14],e[14]=t,this}setPosition(e,t,n){let s=this.elements;return e.isVector3?(s[12]=e.x,s[13]=e.y,s[14]=e.z):(s[12]=e,s[13]=t,s[14]=n),this}invert(){let e=this.elements,t=e[0],n=e[1],s=e[2],r=e[3],a=e[4],o=e[5],l=e[6],c=e[7],h=e[8],f=e[9],u=e[10],d=e[11],g=e[12],x=e[13],m=e[14],p=e[15],S=t*o-n*a,A=t*l-s*a,v=t*c-r*a,b=n*l-s*o,E=n*c-r*o,C=s*c-r*l,y=h*x-f*g,w=h*m-u*g,P=h*p-d*g,U=f*m-u*x,B=f*p-d*x,W=u*p-d*m,F=S*W-A*B+v*U+b*P-E*w+C*y;if(F===0)return this.set(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);let V=1/F;return e[0]=(o*W-l*B+c*U)*V,e[1]=(s*B-n*W-r*U)*V,e[2]=(x*C-m*E+p*b)*V,e[3]=(u*E-f*C-d*b)*V,e[4]=(l*P-a*W-c*w)*V,e[5]=(t*W-s*P+r*w)*V,e[6]=(m*v-g*C-p*A)*V,e[7]=(h*C-u*v+d*A)*V,e[8]=(a*B-o*P+c*y)*V,e[9]=(n*P-t*B-r*y)*V,e[10]=(g*E-x*v+p*S)*V,e[11]=(f*v-h*E-d*S)*V,e[12]=(o*w-a*U-l*y)*V,e[13]=(t*U-n*w+s*y)*V,e[14]=(x*A-g*b-m*S)*V,e[15]=(h*b-f*A+u*S)*V,this}scale(e){let t=this.elements,n=e.x,s=e.y,r=e.z;return t[0]*=n,t[4]*=s,t[8]*=r,t[1]*=n,t[5]*=s,t[9]*=r,t[2]*=n,t[6]*=s,t[10]*=r,t[3]*=n,t[7]*=s,t[11]*=r,this}getMaxScaleOnAxis(){let e=this.elements,t=e[0]*e[0]+e[1]*e[1]+e[2]*e[2],n=e[4]*e[4]+e[5]*e[5]+e[6]*e[6],s=e[8]*e[8]+e[9]*e[9]+e[10]*e[10];return Math.sqrt(Math.max(t,n,s))}makeTranslation(e,t,n){return e.isVector3?this.set(1,0,0,e.x,0,1,0,e.y,0,0,1,e.z,0,0,0,1):this.set(1,0,0,e,0,1,0,t,0,0,1,n,0,0,0,1),this}makeRotationX(e){let t=Math.cos(e),n=Math.sin(e);return this.set(1,0,0,0,0,t,-n,0,0,n,t,0,0,0,0,1),this}makeRotationY(e){let t=Math.cos(e),n=Math.sin(e);return this.set(t,0,n,0,0,1,0,0,-n,0,t,0,0,0,0,1),this}makeRotationZ(e){let t=Math.cos(e),n=Math.sin(e);return this.set(t,-n,0,0,n,t,0,0,0,0,1,0,0,0,0,1),this}makeRotationAxis(e,t){let n=Math.cos(t),s=Math.sin(t),r=1-n,a=e.x,o=e.y,l=e.z,c=r*a,h=r*o;return this.set(c*a+n,c*o-s*l,c*l+s*o,0,c*o+s*l,h*o+n,h*l-s*a,0,c*l-s*o,h*l+s*a,r*l*l+n,0,0,0,0,1),this}makeScale(e,t,n){return this.set(e,0,0,0,0,t,0,0,0,0,n,0,0,0,0,1),this}makeShear(e,t,n,s,r,a){return this.set(1,n,r,0,e,1,a,0,t,s,1,0,0,0,0,1),this}compose(e,t,n){let s=this.elements,r=t._x,a=t._y,o=t._z,l=t._w,c=r+r,h=a+a,f=o+o,u=r*c,d=r*h,g=r*f,x=a*h,m=a*f,p=o*f,S=l*c,A=l*h,v=l*f,b=n.x,E=n.y,C=n.z;return s[0]=(1-(x+p))*b,s[1]=(d+v)*b,s[2]=(g-A)*b,s[3]=0,s[4]=(d-v)*E,s[5]=(1-(u+p))*E,s[6]=(m+S)*E,s[7]=0,s[8]=(g+A)*C,s[9]=(m-S)*C,s[10]=(1-(u+x))*C,s[11]=0,s[12]=e.x,s[13]=e.y,s[14]=e.z,s[15]=1,this}decompose(e,t,n){let s=this.elements;e.x=s[12],e.y=s[13],e.z=s[14];let r=this.determinantAffine();if(r===0)return n.set(1,1,1),t.identity(),this;let a=Is.set(s[0],s[1],s[2]).length(),o=Is.set(s[4],s[5],s[6]).length(),l=Is.set(s[8],s[9],s[10]).length();r<0&&(a=-a),qn.copy(this);let c=1/a,h=1/o,f=1/l;return qn.elements[0]*=c,qn.elements[1]*=c,qn.elements[2]*=c,qn.elements[4]*=h,qn.elements[5]*=h,qn.elements[6]*=h,qn.elements[8]*=f,qn.elements[9]*=f,qn.elements[10]*=f,t.setFromRotationMatrix(qn),n.x=a,n.y=o,n.z=l,this}makePerspective(e,t,n,s,r,a,o=Jn,l=!1){let c=this.elements,h=2*r/(t-e),f=2*r/(n-s),u=(t+e)/(t-e),d=(n+s)/(n-s),g,x;if(l)g=r/(a-r),x=a*r/(a-r);else if(o===Jn)g=-(a+r)/(a-r),x=-2*a*r/(a-r);else if(o===Ks)g=-a/(a-r),x=-a*r/(a-r);else throw new Error("THREE.Matrix4.makePerspective(): Invalid coordinate system: "+o);return c[0]=h,c[4]=0,c[8]=u,c[12]=0,c[1]=0,c[5]=f,c[9]=d,c[13]=0,c[2]=0,c[6]=0,c[10]=g,c[14]=x,c[3]=0,c[7]=0,c[11]=-1,c[15]=0,this}makeOrthographic(e,t,n,s,r,a,o=Jn,l=!1){let c=this.elements,h=2/(t-e),f=2/(n-s),u=-(t+e)/(t-e),d=-(n+s)/(n-s),g,x;if(l)g=1/(a-r),x=a/(a-r);else if(o===Jn)g=-2/(a-r),x=-(a+r)/(a-r);else if(o===Ks)g=-1/(a-r),x=-r/(a-r);else throw new Error("THREE.Matrix4.makeOrthographic(): Invalid coordinate system: "+o);return c[0]=h,c[4]=0,c[8]=0,c[12]=u,c[1]=0,c[5]=f,c[9]=0,c[13]=d,c[2]=0,c[6]=0,c[10]=g,c[14]=x,c[3]=0,c[7]=0,c[11]=0,c[15]=1,this}equals(e){let t=this.elements,n=e.elements;for(let s=0;s<16;s++)if(t[s]!==n[s])return!1;return!0}fromArray(e,t=0){for(let n=0;n<16;n++)this.elements[n]=e[n+t];return this}toArray(e=[],t=0){let n=this.elements;return e[t]=n[0],e[t+1]=n[1],e[t+2]=n[2],e[t+3]=n[3],e[t+4]=n[4],e[t+5]=n[5],e[t+6]=n[6],e[t+7]=n[7],e[t+8]=n[8],e[t+9]=n[9],e[t+10]=n[10],e[t+11]=n[11],e[t+12]=n[12],e[t+13]=n[13],e[t+14]=n[14],e[t+15]=n[15],e}},Is=new I,qn=new Rt,Xf=new I(0,0,0),qf=new I(1,1,1),Vi=new I,ro=new I,Cn=new I,gh=new Rt,_h=new mi,Ni=class i{constructor(e=0,t=0,n=0,s=i.DEFAULT_ORDER){this.isEuler=!0,this._x=e,this._y=t,this._z=n,this._order=s}get x(){return this._x}set x(e){this._x=e,this._onChangeCallback()}get y(){return this._y}set y(e){this._y=e,this._onChangeCallback()}get z(){return this._z}set z(e){this._z=e,this._onChangeCallback()}get order(){return this._order}set order(e){this._order=e,this._onChangeCallback()}set(e,t,n,s=this._order){return this._x=e,this._y=t,this._z=n,this._order=s,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._order)}copy(e){return this._x=e._x,this._y=e._y,this._z=e._z,this._order=e._order,this._onChangeCallback(),this}setFromRotationMatrix(e,t=this._order,n=!0){let s=e.elements,r=s[0],a=s[4],o=s[8],l=s[1],c=s[5],h=s[9],f=s[2],u=s[6],d=s[10];switch(t){case"XYZ":this._y=Math.asin(Mt(o,-1,1)),Math.abs(o)<.9999999?(this._x=Math.atan2(-h,d),this._z=Math.atan2(-a,r)):(this._x=Math.atan2(u,c),this._z=0);break;case"YXZ":this._x=Math.asin(-Mt(h,-1,1)),Math.abs(h)<.9999999?(this._y=Math.atan2(o,d),this._z=Math.atan2(l,c)):(this._y=Math.atan2(-f,r),this._z=0);break;case"ZXY":this._x=Math.asin(Mt(u,-1,1)),Math.abs(u)<.9999999?(this._y=Math.atan2(-f,d),this._z=Math.atan2(-a,c)):(this._y=0,this._z=Math.atan2(l,r));break;case"ZYX":this._y=Math.asin(-Mt(f,-1,1)),Math.abs(f)<.9999999?(this._x=Math.atan2(u,d),this._z=Math.atan2(l,r)):(this._x=0,this._z=Math.atan2(-a,c));break;case"YZX":this._z=Math.asin(Mt(l,-1,1)),Math.abs(l)<.9999999?(this._x=Math.atan2(-h,c),this._y=Math.atan2(-f,r)):(this._x=0,this._y=Math.atan2(o,d));break;case"XZY":this._z=Math.asin(-Mt(a,-1,1)),Math.abs(a)<.9999999?(this._x=Math.atan2(u,c),this._y=Math.atan2(o,r)):(this._x=Math.atan2(-h,d),this._y=0);break;default:ct("Euler: .setFromRotationMatrix() encountered an unknown order: "+t)}return this._order=t,n===!0&&this._onChangeCallback(),this}setFromQuaternion(e,t,n){return gh.makeRotationFromQuaternion(e),this.setFromRotationMatrix(gh,t,n)}setFromVector3(e,t=this._order){return this.set(e.x,e.y,e.z,t)}reorder(e){return _h.setFromEuler(this),this.setFromQuaternion(_h,e)}equals(e){return e._x===this._x&&e._y===this._y&&e._z===this._z&&e._order===this._order}fromArray(e){return this._x=e[0],this._y=e[1],this._z=e[2],e[3]!==void 0&&(this._order=e[3]),this._onChangeCallback(),this}toArray(e=[],t=0){return e[t]=this._x,e[t+1]=this._y,e[t+2]=this._z,e[t+3]=this._order,e}_onChange(e){return this._onChangeCallback=e,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._order}};Ni.DEFAULT_ORDER="XYZ";var tr=class{constructor(){this.mask=1}set(e){this.mask=(1<<e|0)>>>0}enable(e){this.mask|=1<<e|0}enableAll(){this.mask=-1}toggle(e){this.mask^=1<<e|0}disable(e){this.mask&=~(1<<e|0)}disableAll(){this.mask=0}test(e){return(this.mask&e.mask)!==0}isEnabled(e){return(this.mask&(1<<e|0))!==0}},Yf=0,xh=new I,Ls=new mi,wi=new Rt,ao=new I,Dr=new I,$f=new I,Zf=new mi,vh=new I(1,0,0),yh=new I(0,1,0),Mh=new I(0,0,1),Sh={type:"added"},Jf={type:"removed"},Ds={type:"childadded",child:null},Uc={type:"childremoved",child:null},Qt=class i extends pi{constructor(){super(),this.isObject3D=!0,Object.defineProperty(this,"id",{value:Yf++}),this.uuid=Li(),this.name="",this.type="Object3D",this.parent=null,this.children=[],this.up=i.DEFAULT_UP.clone();let e=new I,t=new Ni,n=new mi,s=new I(1,1,1);function r(){n.setFromEuler(t,!1)}function a(){t.setFromQuaternion(n,void 0,!1)}t._onChange(r),n._onChange(a),Object.defineProperties(this,{position:{configurable:!0,enumerable:!0,value:e},rotation:{configurable:!0,enumerable:!0,value:t},quaternion:{configurable:!0,enumerable:!0,value:n},scale:{configurable:!0,enumerable:!0,value:s},modelViewMatrix:{value:new Rt},normalMatrix:{value:new dt}}),this.matrix=new Rt,this.matrixWorld=new Rt,this.matrixAutoUpdate=i.DEFAULT_MATRIX_AUTO_UPDATE,this.matrixWorldAutoUpdate=i.DEFAULT_MATRIX_WORLD_AUTO_UPDATE,this.matrixWorldNeedsUpdate=!1,this.layers=new tr,this.visible=!0,this.castShadow=!1,this.receiveShadow=!1,this.frustumCulled=!0,this.renderOrder=0,this.animations=[],this.customDepthMaterial=void 0,this.customDistanceMaterial=void 0,this.static=!1,this.userData={},this.pivot=null}onBeforeShadow(){}onAfterShadow(){}onBeforeRender(){}onAfterRender(){}applyMatrix4(e){this.matrixAutoUpdate&&this.updateMatrix(),this.matrix.premultiply(e),this.matrix.decompose(this.position,this.quaternion,this.scale)}applyQuaternion(e){return this.quaternion.premultiply(e),this}setRotationFromAxisAngle(e,t){this.quaternion.setFromAxisAngle(e,t)}setRotationFromEuler(e){this.quaternion.setFromEuler(e,!0)}setRotationFromMatrix(e){this.quaternion.setFromRotationMatrix(e)}setRotationFromQuaternion(e){this.quaternion.copy(e)}rotateOnAxis(e,t){return Ls.setFromAxisAngle(e,t),this.quaternion.multiply(Ls),this}rotateOnWorldAxis(e,t){return Ls.setFromAxisAngle(e,t),this.quaternion.premultiply(Ls),this}rotateX(e){return this.rotateOnAxis(vh,e)}rotateY(e){return this.rotateOnAxis(yh,e)}rotateZ(e){return this.rotateOnAxis(Mh,e)}translateOnAxis(e,t){return xh.copy(e).applyQuaternion(this.quaternion),this.position.add(xh.multiplyScalar(t)),this}translateX(e){return this.translateOnAxis(vh,e)}translateY(e){return this.translateOnAxis(yh,e)}translateZ(e){return this.translateOnAxis(Mh,e)}localToWorld(e){return this.updateWorldMatrix(!0,!1),e.applyMatrix4(this.matrixWorld)}worldToLocal(e){return this.updateWorldMatrix(!0,!1),e.applyMatrix4(wi.copy(this.matrixWorld).invert())}lookAt(e,t,n){e.isVector3?ao.copy(e):ao.set(e,t,n);let s=this.parent;this.updateWorldMatrix(!0,!1),Dr.setFromMatrixPosition(this.matrixWorld),this.isCamera||this.isLight?wi.lookAt(Dr,ao,this.up):wi.lookAt(ao,Dr,this.up),this.quaternion.setFromRotationMatrix(wi),s&&(wi.extractRotation(s.matrixWorld),Ls.setFromRotationMatrix(wi),this.quaternion.premultiply(Ls.invert()))}add(e){if(arguments.length>1){for(let t=0;t<arguments.length;t++)this.add(arguments[t]);return this}return e===this?(lt("Object3D.add: object can't be added as a child of itself.",e),this):(e&&e.isObject3D?(e.removeFromParent(),e.parent=this,this.children.push(e),e.dispatchEvent(Sh),Ds.child=e,this.dispatchEvent(Ds),Ds.child=null):lt("Object3D.add: object not an instance of THREE.Object3D.",e),this)}remove(e){if(arguments.length>1){for(let n=0;n<arguments.length;n++)this.remove(arguments[n]);return this}let t=this.children.indexOf(e);return t!==-1&&(e.parent=null,this.children.splice(t,1),e.dispatchEvent(Jf),Uc.child=e,this.dispatchEvent(Uc),Uc.child=null),this}removeFromParent(){let e=this.parent;return e!==null&&e.remove(this),this}clear(){return this.remove(...this.children)}attach(e){return this.updateWorldMatrix(!0,!1),wi.copy(this.matrixWorld).invert(),e.parent!==null&&(e.parent.updateWorldMatrix(!0,!1),wi.multiply(e.parent.matrixWorld)),e.applyMatrix4(wi),e.removeFromParent(),e.parent=this,this.children.push(e),e.updateWorldMatrix(!1,!0),e.dispatchEvent(Sh),Ds.child=e,this.dispatchEvent(Ds),Ds.child=null,this}getObjectById(e){return this.getObjectByProperty("id",e)}getObjectByName(e){return this.getObjectByProperty("name",e)}getObjectByProperty(e,t){if(this[e]===t)return this;for(let n=0,s=this.children.length;n<s;n++){let a=this.children[n].getObjectByProperty(e,t);if(a!==void 0)return a}}getObjectsByProperty(e,t,n=[]){this[e]===t&&n.push(this);let s=this.children;for(let r=0,a=s.length;r<a;r++)s[r].getObjectsByProperty(e,t,n);return n}getWorldPosition(e){return this.updateWorldMatrix(!0,!1),e.setFromMatrixPosition(this.matrixWorld)}getWorldQuaternion(e){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose(Dr,e,$f),e}getWorldScale(e){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose(Dr,Zf,e),e}getWorldDirection(e){this.updateWorldMatrix(!0,!1);let t=this.matrixWorld.elements;return e.set(t[8],t[9],t[10]).normalize()}raycast(){}intersectsFrustum(){}traverse(e){e(this);let t=this.children;for(let n=0,s=t.length;n<s;n++)t[n].traverse(e)}traverseVisible(e){if(this.visible===!1)return;e(this);let t=this.children;for(let n=0,s=t.length;n<s;n++)t[n].traverseVisible(e)}traverseAncestors(e){let t=this.parent;t!==null&&(e(t),t.traverseAncestors(e))}updateMatrix(){this.matrix.compose(this.position,this.quaternion,this.scale);let e=this.pivot;if(e!==null){let t=e.x,n=e.y,s=e.z,r=this.matrix.elements;r[12]+=t-r[0]*t-r[4]*n-r[8]*s,r[13]+=n-r[1]*t-r[5]*n-r[9]*s,r[14]+=s-r[2]*t-r[6]*n-r[10]*s}this.matrixWorldNeedsUpdate=!0}updateMatrixWorld(e){this.matrixAutoUpdate&&this.updateMatrix(),(this.matrixWorldNeedsUpdate||e)&&(this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),this.matrixWorldNeedsUpdate=!1,e=!0);let t=this.children;for(let n=0,s=t.length;n<s;n++)t[n].updateMatrixWorld(e)}updateWorldMatrix(e,t,n=!1){let s=this.parent;if(e===!0&&s!==null&&s.updateWorldMatrix(!0,!1),this.matrixAutoUpdate&&this.updateMatrix(),(this.matrixWorldNeedsUpdate||n)&&(this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),this.matrixWorldNeedsUpdate=!1,n=!0),t===!0){let r=this.children;for(let a=0,o=r.length;a<o;a++)r[a].updateWorldMatrix(!1,!0,n)}}toJSON(e){let t=e===void 0||typeof e=="string",n={};t&&(e={geometries:{},materials:{},textures:{},images:{},shapes:{},skeletons:{},animations:{},nodes:{}},n.metadata={version:4.7,type:"Object",generator:"Object3D.toJSON"});let s={};s.uuid=this.uuid,s.type=this.type,s.name=this.name,s.castShadow=this.castShadow,s.receiveShadow=this.receiveShadow,s.visible=this.visible,s.frustumCulled=this.frustumCulled,s.renderOrder=this.renderOrder,s.static=this.static,s.matrixAutoUpdate=this.matrixAutoUpdate,Object.keys(this.userData).length>0&&(s.userData=this.userData),s.layers=this.layers.mask,s.matrix=this.matrix.toArray(),s.up=this.up.toArray(),this.pivot!==null&&(s.pivot=this.pivot.toArray()),this.morphTargetDictionary!==void 0&&(s.morphTargetDictionary=Object.assign({},this.morphTargetDictionary)),this.morphTargetInfluences!==void 0&&(s.morphTargetInfluences=this.morphTargetInfluences.slice()),this.isInstancedMesh&&(s.type="InstancedMesh",s.count=this.count,s.instanceMatrix=this.instanceMatrix.toJSON(),this.instanceColor!==null&&(s.instanceColor=this.instanceColor.toJSON())),this.isBatchedMesh&&(s.type="BatchedMesh",s.perObjectFrustumCulled=this.perObjectFrustumCulled,s.sortObjects=this.sortObjects,s.drawRanges=this._drawRanges,s.reservedRanges=this._reservedRanges,s.geometryInfo=this._geometryInfo.map(o=>({...o,boundingBox:o.boundingBox?o.boundingBox.toJSON():void 0,boundingSphere:o.boundingSphere?o.boundingSphere.toJSON():void 0})),s.instanceInfo=this._instanceInfo.map(o=>({...o})),s.availableInstanceIds=this._availableInstanceIds.slice(),s.availableGeometryIds=this._availableGeometryIds.slice(),s.nextIndexStart=this._nextIndexStart,s.nextVertexStart=this._nextVertexStart,s.geometryCount=this._geometryCount,s.maxInstanceCount=this._maxInstanceCount,s.maxVertexCount=this._maxVertexCount,s.maxIndexCount=this._maxIndexCount,s.geometryInitialized=this._geometryInitialized,s.matricesTexture=this._matricesTexture.toJSON(e),s.indirectTexture=this._indirectTexture.toJSON(e),this._colorsTexture!==null&&(s.colorsTexture=this._colorsTexture.toJSON(e)),this.boundingSphere!==null&&(s.boundingSphere=this.boundingSphere.toJSON()),this.boundingBox!==null&&(s.boundingBox=this.boundingBox.toJSON()));function r(o,l){return o[l.uuid]===void 0&&(o[l.uuid]=l.toJSON(e)),l.uuid}if(this.isScene)this.background&&(this.background.isColor?s.background=this.background.toJSON():this.background.isTexture&&(s.background=this.background.toJSON(e).uuid)),this.environment&&this.environment.isTexture&&this.environment.isRenderTargetTexture!==!0&&(s.environment=this.environment.toJSON(e).uuid);else if(this.isMesh||this.isLine||this.isPoints){s.geometry=r(e.geometries,this.geometry);let o=this.geometry.parameters;if(o!==void 0&&o.shapes!==void 0){let l=o.shapes;if(Array.isArray(l))for(let c=0,h=l.length;c<h;c++){let f=l[c];r(e.shapes,f)}else r(e.shapes,l)}}if(this.isSkinnedMesh&&(s.bindMode=this.bindMode,s.bindMatrix=this.bindMatrix.toArray(),this.skeleton!==void 0&&(r(e.skeletons,this.skeleton),s.skeleton=this.skeleton.uuid)),this.material!==void 0)if(Array.isArray(this.material)){let o=[];for(let l=0,c=this.material.length;l<c;l++)o.push(r(e.materials,this.material[l]));s.material=o}else s.material=r(e.materials,this.material);if(this.children.length>0){s.children=[];for(let o=0;o<this.children.length;o++)s.children.push(this.children[o].toJSON(e).object)}if(this.animations.length>0){s.animations=[];for(let o=0;o<this.animations.length;o++){let l=this.animations[o];s.animations.push(r(e.animations,l))}}if(t){let o=a(e.geometries),l=a(e.materials),c=a(e.textures),h=a(e.images),f=a(e.shapes),u=a(e.skeletons),d=a(e.animations),g=a(e.nodes);o.length>0&&(n.geometries=o),l.length>0&&(n.materials=l),c.length>0&&(n.textures=c),h.length>0&&(n.images=h),f.length>0&&(n.shapes=f),u.length>0&&(n.skeletons=u),d.length>0&&(n.animations=d),g.length>0&&(n.nodes=g)}return n.object=s,n;function a(o){let l=[];for(let c in o){let h=o[c];delete h.metadata,l.push(h)}return l}}clone(e){return new this.constructor().copy(this,e)}copy(e,t=!0){if(this.name=e.name,this.up.copy(e.up),this.position.copy(e.position),this.rotation.order=e.rotation.order,this.quaternion.copy(e.quaternion),this.scale.copy(e.scale),this.pivot=e.pivot!==null?e.pivot.clone():null,this.matrix.copy(e.matrix),this.matrixWorld.copy(e.matrixWorld),this.matrixAutoUpdate=e.matrixAutoUpdate,this.matrixWorldAutoUpdate=e.matrixWorldAutoUpdate,this.matrixWorldNeedsUpdate=e.matrixWorldNeedsUpdate,this.layers.mask=e.layers.mask,this.visible=e.visible,this.castShadow=e.castShadow,this.receiveShadow=e.receiveShadow,this.frustumCulled=e.frustumCulled,this.renderOrder=e.renderOrder,this.static=e.static,this.animations=e.animations.slice(),this.userData=JSON.parse(JSON.stringify(e.userData)),t===!0)for(let n=0;n<e.children.length;n++){let s=e.children[n];this.add(s.clone())}return this}dispose(){this.dispatchEvent({type:"dispose"})}};Qt.DEFAULT_UP=new I(0,1,0);Qt.DEFAULT_MATRIX_AUTO_UPDATE=!0;Qt.DEFAULT_MATRIX_WORLD_AUTO_UPDATE=!0;var qt=class extends Qt{constructor(){super(),this.isGroup=!0,this.type="Group"}},Kf={type:"move"},nr=class{constructor(){this._targetRay=null,this._grip=null,this._hand=null}getHandSpace(){return this._hand===null&&(this._hand=new qt,this._hand.matrixAutoUpdate=!1,this._hand.visible=!1,this._hand.joints={},this._hand.inputState={pinching:!1}),this._hand}getTargetRaySpace(){return this._targetRay===null&&(this._targetRay=new qt,this._targetRay.matrixAutoUpdate=!1,this._targetRay.visible=!1,this._targetRay.hasLinearVelocity=!1,this._targetRay.linearVelocity=new I,this._targetRay.hasAngularVelocity=!1,this._targetRay.angularVelocity=new I),this._targetRay}getGripSpace(){return this._grip===null&&(this._grip=new qt,this._grip.matrixAutoUpdate=!1,this._grip.visible=!1,this._grip.hasLinearVelocity=!1,this._grip.linearVelocity=new I,this._grip.hasAngularVelocity=!1,this._grip.angularVelocity=new I,this._grip.eventsEnabled=!1),this._grip}dispatchEvent(e){return this._targetRay!==null&&this._targetRay.dispatchEvent(e),this._grip!==null&&this._grip.dispatchEvent(e),this._hand!==null&&this._hand.dispatchEvent(e),this}connect(e){if(e&&e.hand){let t=this._hand;if(t)for(let n of e.hand.values())this._getHandJoint(t,n)}return this.dispatchEvent({type:"connected",data:e}),this}disconnect(e){return this.dispatchEvent({type:"disconnected",data:e}),this._targetRay!==null&&(this._targetRay.visible=!1),this._grip!==null&&(this._grip.visible=!1),this._hand!==null&&(this._hand.visible=!1),this}update(e,t,n){let s=null,r=null,a=null,o=this._targetRay,l=this._grip,c=this._hand;if(e&&t.session.visibilityState!=="visible-blurred"){if(c&&e.hand){a=!0;for(let x of e.hand.values()){let m=t.getJointPose(x,n),p=this._getHandJoint(c,x);m!==null&&(p.matrix.fromArray(m.transform.matrix),p.matrix.decompose(p.position,p.rotation,p.scale),p.matrixWorldNeedsUpdate=!0,p.jointRadius=m.radius),p.visible=m!==null}let h=c.joints["index-finger-tip"],f=c.joints["thumb-tip"],u=h.position.distanceTo(f.position),d=.02,g=.005;c.inputState.pinching&&u>d+g?(c.inputState.pinching=!1,this.dispatchEvent({type:"pinchend",handedness:e.handedness,target:this})):!c.inputState.pinching&&u<=d-g&&(c.inputState.pinching=!0,this.dispatchEvent({type:"pinchstart",handedness:e.handedness,target:this}))}else l!==null&&e.gripSpace&&(r=t.getPose(e.gripSpace,n),r!==null&&(l.matrix.fromArray(r.transform.matrix),l.matrix.decompose(l.position,l.rotation,l.scale),l.matrixWorldNeedsUpdate=!0,r.linearVelocity?(l.hasLinearVelocity=!0,l.linearVelocity.copy(r.linearVelocity)):l.hasLinearVelocity=!1,r.angularVelocity?(l.hasAngularVelocity=!0,l.angularVelocity.copy(r.angularVelocity)):l.hasAngularVelocity=!1,l.eventsEnabled&&l.dispatchEvent({type:"gripUpdated",data:e,target:this})));o!==null&&(s=t.getPose(e.targetRaySpace,n),s===null&&r!==null&&(s=r),s!==null&&(o.matrix.fromArray(s.transform.matrix),o.matrix.decompose(o.position,o.rotation,o.scale),o.matrixWorldNeedsUpdate=!0,s.linearVelocity?(o.hasLinearVelocity=!0,o.linearVelocity.copy(s.linearVelocity)):o.hasLinearVelocity=!1,s.angularVelocity?(o.hasAngularVelocity=!0,o.angularVelocity.copy(s.angularVelocity)):o.hasAngularVelocity=!1,this.dispatchEvent(Kf)))}return o!==null&&(o.visible=s!==null),l!==null&&(l.visible=r!==null),c!==null&&(c.visible=a!==null),this}_getHandJoint(e,t){if(e.joints[t.jointName]===void 0){let n=new qt;n.matrixAutoUpdate=!1,n.visible=!1,e.joints[t.jointName]=n,e.add(n)}return e.joints[t.jointName]}},Nu={aliceblue:15792383,antiquewhite:16444375,aqua:65535,aquamarine:8388564,azure:15794175,beige:16119260,bisque:16770244,black:0,blanchedalmond:16772045,blue:255,blueviolet:9055202,brown:10824234,burlywood:14596231,cadetblue:6266528,chartreuse:8388352,chocolate:13789470,coral:16744272,cornflowerblue:6591981,cornsilk:16775388,crimson:14423100,cyan:65535,darkblue:139,darkcyan:35723,darkgoldenrod:12092939,darkgray:11119017,darkgreen:25600,darkgrey:11119017,darkkhaki:12433259,darkmagenta:9109643,darkolivegreen:5597999,darkorange:16747520,darkorchid:10040012,darkred:9109504,darksalmon:15308410,darkseagreen:9419919,darkslateblue:4734347,darkslategray:3100495,darkslategrey:3100495,darkturquoise:52945,darkviolet:9699539,deeppink:16716947,deepskyblue:49151,dimgray:6908265,dimgrey:6908265,dodgerblue:2003199,firebrick:11674146,floralwhite:16775920,forestgreen:2263842,fuchsia:16711935,gainsboro:14474460,ghostwhite:16316671,gold:16766720,goldenrod:14329120,gray:8421504,green:32768,greenyellow:11403055,grey:8421504,honeydew:15794160,hotpink:16738740,indianred:13458524,indigo:4915330,ivory:16777200,khaki:15787660,lavender:15132410,lavenderblush:16773365,lawngreen:8190976,lemonchiffon:16775885,lightblue:11393254,lightcoral:15761536,lightcyan:14745599,lightgoldenrodyellow:16448210,lightgray:13882323,lightgreen:9498256,lightgrey:13882323,lightpink:16758465,lightsalmon:16752762,lightseagreen:2142890,lightskyblue:8900346,lightslategray:7833753,lightslategrey:7833753,lightsteelblue:11584734,lightyellow:16777184,lime:65280,limegreen:3329330,linen:16445670,magenta:16711935,maroon:8388608,mediumaquamarine:6737322,mediumblue:205,mediumorchid:12211667,mediumpurple:9662683,mediumseagreen:3978097,mediumslateblue:8087790,mediumspringgreen:64154,mediumturquoise:4772300,mediumvioletred:13047173,midnightblue:1644912,mintcream:16121850,mistyrose:16770273,moccasin:16770229,navajowhite:16768685,navy:128,oldlace:16643558,olive:8421376,olivedrab:7048739,orange:16753920,orangered:16729344,orchid:14315734,palegoldenrod:15657130,palegreen:10025880,paleturquoise:11529966,palevioletred:14381203,papayawhip:16773077,peachpuff:16767673,peru:13468991,pink:16761035,plum:14524637,powderblue:11591910,purple:8388736,rebeccapurple:6697881,red:16711680,rosybrown:12357519,royalblue:4286945,saddlebrown:9127187,salmon:16416882,sandybrown:16032864,seagreen:3050327,seashell:16774638,sienna:10506797,silver:12632256,skyblue:8900331,slateblue:6970061,slategray:7372944,slategrey:7372944,snow:16775930,springgreen:65407,steelblue:4620980,tan:13808780,teal:32896,thistle:14204888,tomato:16737095,turquoise:4251856,violet:15631086,wheat:16113331,white:16777215,whitesmoke:16119285,yellow:16776960,yellowgreen:10145074},Gi={h:0,s:0,l:0},oo={h:0,s:0,l:0};function Fc(i,e,t){return t<0&&(t+=1),t>1&&(t-=1),t<1/6?i+(e-i)*6*t:t<1/2?e:t<2/3?i+(e-i)*6*(2/3-t):i}var it=class{constructor(e,t,n){return this.isColor=!0,this.r=1,this.g=1,this.b=1,this.set(e,t,n)}set(e,t,n){if(t===void 0&&n===void 0){let s=e;s&&s.isColor?this.copy(s):typeof s=="number"?this.setHex(s):typeof s=="string"&&this.setStyle(s)}else this.setRGB(e,t,n);return this}setScalar(e){return this.r=e,this.g=e,this.b=e,this}setHex(e,t=Wt){return e=Math.floor(e),this.r=(e>>16&255)/255,this.g=(e>>8&255)/255,this.b=(e&255)/255,St.colorSpaceToWorking(this,t),this}setRGB(e,t,n,s=St.workingColorSpace){return this.r=e,this.g=t,this.b=n,St.colorSpaceToWorking(this,s),this}setHSL(e,t,n,s=St.workingColorSpace){if(e=kf(e,1),t=Mt(t,0,1),n=Mt(n,0,1),t===0)this.r=this.g=this.b=n;else{let r=n<=.5?n*(1+t):n+t-n*t,a=2*n-r;this.r=Fc(a,r,e+1/3),this.g=Fc(a,r,e),this.b=Fc(a,r,e-1/3)}return St.colorSpaceToWorking(this,s),this}setStyle(e,t=Wt){function n(r){r!==void 0&&parseFloat(r)<1&&ct("Color: Alpha component of "+e+" will be ignored.")}let s;if(s=/^(\w+)\(([^\)]*)\)/.exec(e)){let r,a=s[1],o=s[2];switch(a){case"rgb":case"rgba":if(r=/^\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return n(r[4]),this.setRGB(Math.min(255,parseInt(r[1],10))/255,Math.min(255,parseInt(r[2],10))/255,Math.min(255,parseInt(r[3],10))/255,t);if(r=/^\s*(\d+)\%\s*,\s*(\d+)\%\s*,\s*(\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return n(r[4]),this.setRGB(Math.min(100,parseInt(r[1],10))/100,Math.min(100,parseInt(r[2],10))/100,Math.min(100,parseInt(r[3],10))/100,t);break;case"hsl":case"hsla":if(r=/^\s*(\d*\.?\d+)\s*,\s*(\d*\.?\d+)\%\s*,\s*(\d*\.?\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return n(r[4]),this.setHSL(parseFloat(r[1])/360,parseFloat(r[2])/100,parseFloat(r[3])/100,t);break;default:ct("Color: Unknown color model "+e)}}else if(s=/^\#([A-Fa-f\d]+)$/.exec(e)){let r=s[1],a=r.length;if(a===3)return this.setRGB(parseInt(r.charAt(0),16)/15,parseInt(r.charAt(1),16)/15,parseInt(r.charAt(2),16)/15,t);if(a===6)return this.setHex(parseInt(r,16),t);ct("Color: Invalid hex color "+e)}else if(e&&e.length>0)return this.setColorName(e,t);return this}setColorName(e,t=Wt){let n=Nu[e.toLowerCase()];return n!==void 0?this.setHex(n,t):ct("Color: Unknown color "+e),this}clone(){return new this.constructor(this.r,this.g,this.b)}copy(e){return this.r=e.r,this.g=e.g,this.b=e.b,this}copySRGBToLinear(e){return this.r=Di(e.r),this.g=Di(e.g),this.b=Di(e.b),this}copyLinearToSRGB(e){return this.r=Zs(e.r),this.g=Zs(e.g),this.b=Zs(e.b),this}convertSRGBToLinear(){return this.copySRGBToLinear(this),this}convertLinearToSRGB(){return this.copyLinearToSRGB(this),this}getHex(e=Wt){return St.workingToColorSpace(yn.copy(this),e),Math.round(Mt(yn.r*255,0,255))*65536+Math.round(Mt(yn.g*255,0,255))*256+Math.round(Mt(yn.b*255,0,255))}getHexString(e=Wt){return("000000"+this.getHex(e).toString(16)).slice(-6)}getHSL(e,t=St.workingColorSpace){St.workingToColorSpace(yn.copy(this),t);let n=yn.r,s=yn.g,r=yn.b,a=Math.max(n,s,r),o=Math.min(n,s,r),l,c,h=(o+a)/2;if(o===a)l=0,c=0;else{let f=a-o;switch(c=h<=.5?f/(a+o):f/(2-a-o),a){case n:l=(s-r)/f+(s<r?6:0);break;case s:l=(r-n)/f+2;break;case r:l=(n-s)/f+4;break}l/=6}return e.h=l,e.s=c,e.l=h,e}getRGB(e,t=St.workingColorSpace){return St.workingToColorSpace(yn.copy(this),t),e.r=yn.r,e.g=yn.g,e.b=yn.b,e}getStyle(e=Wt){St.workingToColorSpace(yn.copy(this),e);let t=yn.r,n=yn.g,s=yn.b;return e!==Wt?`color(${e} ${t.toFixed(3)} ${n.toFixed(3)} ${s.toFixed(3)})`:`rgb(${Math.round(t*255)},${Math.round(n*255)},${Math.round(s*255)})`}offsetHSL(e,t,n){return this.getHSL(Gi),this.setHSL(Gi.h+e,Gi.s+t,Gi.l+n)}add(e){return this.r+=e.r,this.g+=e.g,this.b+=e.b,this}addColors(e,t){return this.r=e.r+t.r,this.g=e.g+t.g,this.b=e.b+t.b,this}addScalar(e){return this.r+=e,this.g+=e,this.b+=e,this}sub(e){return this.r=Math.max(0,this.r-e.r),this.g=Math.max(0,this.g-e.g),this.b=Math.max(0,this.b-e.b),this}multiply(e){return this.r*=e.r,this.g*=e.g,this.b*=e.b,this}multiplyScalar(e){return this.r*=e,this.g*=e,this.b*=e,this}lerp(e,t){return this.r+=(e.r-this.r)*t,this.g+=(e.g-this.g)*t,this.b+=(e.b-this.b)*t,this}lerpColors(e,t,n){return this.r=e.r+(t.r-e.r)*n,this.g=e.g+(t.g-e.g)*n,this.b=e.b+(t.b-e.b)*n,this}lerpHSL(e,t){this.getHSL(Gi),e.getHSL(oo);let n=Pc(Gi.h,oo.h,t),s=Pc(Gi.s,oo.s,t),r=Pc(Gi.l,oo.l,t);return this.setHSL(n,s,r),this}setFromVector3(e){return this.r=e.x,this.g=e.y,this.b=e.z,this}applyMatrix3(e){let t=this.r,n=this.g,s=this.b,r=e.elements;return this.r=r[0]*t+r[3]*n+r[6]*s,this.g=r[1]*t+r[4]*n+r[7]*s,this.b=r[2]*t+r[5]*n+r[8]*s,this}equals(e){return e.r===this.r&&e.g===this.g&&e.b===this.b}fromArray(e,t=0){return this.r=e[t],this.g=e[t+1],this.b=e[t+2],this}toArray(e=[],t=0){return e[t]=this.r,e[t+1]=this.g,e[t+2]=this.b,e}fromBufferAttribute(e,t){return this.r=e.getX(t),this.g=e.getY(t),this.b=e.getZ(t),this}toJSON(){return this.getHex()}*[Symbol.iterator](){yield this.r,yield this.g,yield this.b}},yn=new it;it.NAMES=Nu;var Kr=class extends Qt{constructor(){super(),this.isScene=!0,this.type="Scene",this.background=null,this.environment=null,this.fog=null,this.backgroundBlurriness=0,this.backgroundIntensity=1,this.backgroundRotation=new Ni,this.environmentIntensity=1,this.environmentRotation=new Ni,this.overrideMaterial=null,typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}copy(e,t){return super.copy(e,t),e.background!==null&&(this.background=e.background.clone()),e.environment!==null&&(this.environment=e.environment.clone()),e.fog!==null&&(this.fog=e.fog.clone()),this.backgroundBlurriness=e.backgroundBlurriness,this.backgroundIntensity=e.backgroundIntensity,this.backgroundRotation.copy(e.backgroundRotation),this.environmentIntensity=e.environmentIntensity,this.environmentRotation.copy(e.environmentRotation),e.overrideMaterial!==null&&(this.overrideMaterial=e.overrideMaterial.clone()),this.matrixAutoUpdate=e.matrixAutoUpdate,this}toJSON(e){let t=super.toJSON(e);return this.fog!==null&&(t.object.fog=this.fog.toJSON()),t.object.backgroundBlurriness=this.backgroundBlurriness,t.object.backgroundIntensity=this.backgroundIntensity,t.object.backgroundRotation=this.backgroundRotation.toArray(),t.object.environmentIntensity=this.environmentIntensity,t.object.environmentRotation=this.environmentRotation.toArray(),t}},Yn=new I,Ai=new I,Oc=new I,Ri=new I,Ns=new I,Us=new I,bh=new I,Bc=new I,zc=new I,Hc=new I,kc=new Gt,Vc=new Gt,Gc=new Gt,Ii=class i{constructor(e=new I,t=new I,n=new I){this.a=e,this.b=t,this.c=n}static getNormal(e,t,n,s){s.subVectors(n,t),Yn.subVectors(e,t),s.cross(Yn);let r=s.lengthSq();return r>0?s.multiplyScalar(1/Math.sqrt(r)):s.set(0,0,0)}static getBarycoord(e,t,n,s,r){Yn.subVectors(s,t),Ai.subVectors(n,t),Oc.subVectors(e,t);let a=Yn.dot(Yn),o=Yn.dot(Ai),l=Yn.dot(Oc),c=Ai.dot(Ai),h=Ai.dot(Oc),f=a*c-o*o;if(f===0)return r.set(0,0,0),null;let u=1/f,d=(c*l-o*h)*u,g=(a*h-o*l)*u;return r.set(1-d-g,g,d)}static containsPoint(e,t,n,s){return this.getBarycoord(e,t,n,s,Ri)===null?!1:Ri.x>=0&&Ri.y>=0&&Ri.x+Ri.y<=1}static getInterpolation(e,t,n,s,r,a,o,l){return this.getBarycoord(e,t,n,s,Ri)===null?(l.x=0,l.y=0,"z"in l&&(l.z=0),"w"in l&&(l.w=0),null):(l.setScalar(0),l.addScaledVector(r,Ri.x),l.addScaledVector(a,Ri.y),l.addScaledVector(o,Ri.z),l)}static getInterpolatedAttribute(e,t,n,s,r,a){return kc.setScalar(0),Vc.setScalar(0),Gc.setScalar(0),kc.fromBufferAttribute(e,t),Vc.fromBufferAttribute(e,n),Gc.fromBufferAttribute(e,s),a.setScalar(0),a.addScaledVector(kc,r.x),a.addScaledVector(Vc,r.y),a.addScaledVector(Gc,r.z),a}static isFrontFacing(e,t,n,s){return Yn.subVectors(n,t),Ai.subVectors(e,t),Yn.cross(Ai).dot(s)<0}set(e,t,n){return this.a.copy(e),this.b.copy(t),this.c.copy(n),this}setFromPointsAndIndices(e,t,n,s){return this.a.copy(e[t]),this.b.copy(e[n]),this.c.copy(e[s]),this}setFromAttributeAndIndices(e,t,n,s){return this.a.fromBufferAttribute(e,t),this.b.fromBufferAttribute(e,n),this.c.fromBufferAttribute(e,s),this}clone(){return new this.constructor().copy(this)}copy(e){return this.a.copy(e.a),this.b.copy(e.b),this.c.copy(e.c),this}getArea(){return Yn.subVectors(this.c,this.b),Ai.subVectors(this.a,this.b),Yn.cross(Ai).length()*.5}getMidpoint(e){return e.addVectors(this.a,this.b).add(this.c).multiplyScalar(1/3)}getNormal(e){return i.getNormal(this.a,this.b,this.c,e)}getPlane(e){return e.setFromCoplanarPoints(this.a,this.b,this.c)}getBarycoord(e,t){return i.getBarycoord(e,this.a,this.b,this.c,t)}getInterpolation(e,t,n,s,r){return i.getInterpolation(e,this.a,this.b,this.c,t,n,s,r)}containsPoint(e){return i.containsPoint(e,this.a,this.b,this.c)}isFrontFacing(e){return i.isFrontFacing(this.a,this.b,this.c,e)}intersectsBox(e){return e.intersectsTriangle(this)}closestPointToPoint(e,t){let n=this.a,s=this.b,r=this.c,a,o;Ns.subVectors(s,n),Us.subVectors(r,n),Bc.subVectors(e,n);let l=Ns.dot(Bc),c=Us.dot(Bc);if(l<=0&&c<=0)return t.copy(n);zc.subVectors(e,s);let h=Ns.dot(zc),f=Us.dot(zc);if(h>=0&&f<=h)return t.copy(s);let u=l*f-h*c;if(u<=0&&l>=0&&h<=0)return a=l/(l-h),t.copy(n).addScaledVector(Ns,a);Hc.subVectors(e,r);let d=Ns.dot(Hc),g=Us.dot(Hc);if(g>=0&&d<=g)return t.copy(r);let x=d*c-l*g;if(x<=0&&c>=0&&g<=0)return o=c/(c-g),t.copy(n).addScaledVector(Us,o);let m=h*g-d*f;if(m<=0&&f-h>=0&&d-g>=0)return bh.subVectors(r,s),o=(f-h)/(f-h+(d-g)),t.copy(s).addScaledVector(bh,o);let p=1/(m+x+u);return a=x*p,o=u*p,t.copy(n).addScaledVector(Ns,a).addScaledVector(Us,o)}equals(e){return e.a.equals(this.a)&&e.b.equals(this.b)&&e.c.equals(this.c)}},gi=class{constructor(e=new I(1/0,1/0,1/0),t=new I(-1/0,-1/0,-1/0)){this.isBox3=!0,this.min=e,this.max=t}set(e,t){return this.min.copy(e),this.max.copy(t),this}setFromArray(e){this.makeEmpty();for(let t=0,n=e.length;t<n;t+=3)this.expandByPoint($n.fromArray(e,t));return this}setFromBufferAttribute(e){this.makeEmpty();for(let t=0,n=e.count;t<n;t++)this.expandByPoint($n.fromBufferAttribute(e,t));return this}setFromPoints(e){this.makeEmpty();for(let t=0,n=e.length;t<n;t++)this.expandByPoint(e[t]);return this}setFromCenterAndSize(e,t){let n=$n.copy(t).multiplyScalar(.5);return this.min.copy(e).sub(n),this.max.copy(e).add(n),this}setFromObject(e,t=!1){return this.makeEmpty(),this.expandByObject(e,t)}clone(){return new this.constructor().copy(this)}copy(e){return this.min.copy(e.min),this.max.copy(e.max),this}makeEmpty(){return this.min.x=this.min.y=this.min.z=1/0,this.max.x=this.max.y=this.max.z=-1/0,this}isEmpty(){return this.max.x<this.min.x||this.max.y<this.min.y||this.max.z<this.min.z}getCenter(e){return this.isEmpty()?e.set(0,0,0):e.addVectors(this.min,this.max).multiplyScalar(.5)}getSize(e){return this.isEmpty()?e.set(0,0,0):e.subVectors(this.max,this.min)}expandByPoint(e){return this.min.min(e),this.max.max(e),this}expandByVector(e){return this.min.sub(e),this.max.add(e),this}expandByScalar(e){return this.min.addScalar(-e),this.max.addScalar(e),this}expandByObject(e,t=!1){e.updateWorldMatrix(!1,!1);let n=e.geometry;if(n!==void 0){let r=n.getAttribute("position");if(t===!0&&r!==void 0&&e.isInstancedMesh!==!0)for(let a=0,o=r.count;a<o;a++)e.isMesh===!0?e.getVertexPosition(a,$n):$n.fromBufferAttribute(r,a),$n.applyMatrix4(e.matrixWorld),this.expandByPoint($n);else e.boundingBox!==void 0?(e.boundingBox===null&&e.computeBoundingBox(),lo.copy(e.boundingBox)):(n.boundingBox===null&&n.computeBoundingBox(),lo.copy(n.boundingBox)),lo.applyMatrix4(e.matrixWorld),this.union(lo)}let s=e.children;for(let r=0,a=s.length;r<a;r++)this.expandByObject(s[r],t);return this}containsPoint(e){return e.x>=this.min.x&&e.x<=this.max.x&&e.y>=this.min.y&&e.y<=this.max.y&&e.z>=this.min.z&&e.z<=this.max.z}containsBox(e){return this.min.x<=e.min.x&&e.max.x<=this.max.x&&this.min.y<=e.min.y&&e.max.y<=this.max.y&&this.min.z<=e.min.z&&e.max.z<=this.max.z}getParameter(e,t){return t.set((e.x-this.min.x)/(this.max.x-this.min.x),(e.y-this.min.y)/(this.max.y-this.min.y),(e.z-this.min.z)/(this.max.z-this.min.z))}intersectsBox(e){return e.max.x>=this.min.x&&e.min.x<=this.max.x&&e.max.y>=this.min.y&&e.min.y<=this.max.y&&e.max.z>=this.min.z&&e.min.z<=this.max.z}intersectsSphere(e){return this.clampPoint(e.center,$n),$n.distanceToSquared(e.center)<=e.radius*e.radius}intersectsPlane(e){let t,n;return e.normal.x>0?(t=e.normal.x*this.min.x,n=e.normal.x*this.max.x):(t=e.normal.x*this.max.x,n=e.normal.x*this.min.x),e.normal.y>0?(t+=e.normal.y*this.min.y,n+=e.normal.y*this.max.y):(t+=e.normal.y*this.max.y,n+=e.normal.y*this.min.y),e.normal.z>0?(t+=e.normal.z*this.min.z,n+=e.normal.z*this.max.z):(t+=e.normal.z*this.max.z,n+=e.normal.z*this.min.z),t<=-e.constant&&n>=-e.constant}intersectsTriangle(e){if(this.isEmpty())return!1;this.getCenter(Nr),co.subVectors(this.max,Nr),Fs.subVectors(e.a,Nr),Os.subVectors(e.b,Nr),Bs.subVectors(e.c,Nr),Wi.subVectors(Os,Fs),Xi.subVectors(Bs,Os),ds.subVectors(Fs,Bs);let t=[0,-Wi.z,Wi.y,0,-Xi.z,Xi.y,0,-ds.z,ds.y,Wi.z,0,-Wi.x,Xi.z,0,-Xi.x,ds.z,0,-ds.x,-Wi.y,Wi.x,0,-Xi.y,Xi.x,0,-ds.y,ds.x,0];return!Wc(t,Fs,Os,Bs,co)||(t=[1,0,0,0,1,0,0,0,1],!Wc(t,Fs,Os,Bs,co))?!1:(ho.crossVectors(Wi,Xi),t=[ho.x,ho.y,ho.z],Wc(t,Fs,Os,Bs,co))}clampPoint(e,t){return t.copy(e).clamp(this.min,this.max)}distanceToPoint(e){return this.clampPoint(e,$n).distanceTo(e)}getBoundingSphere(e){return this.isEmpty()?e.makeEmpty():(this.getCenter(e.center),e.radius=this.getSize($n).length()*.5),e}intersect(e){return this.min.max(e.min),this.max.min(e.max),this.isEmpty()&&this.makeEmpty(),this}union(e){return this.min.min(e.min),this.max.max(e.max),this}applyMatrix4(e){return this.isEmpty()?this:(Ci[0].set(this.min.x,this.min.y,this.min.z).applyMatrix4(e),Ci[1].set(this.min.x,this.min.y,this.max.z).applyMatrix4(e),Ci[2].set(this.min.x,this.max.y,this.min.z).applyMatrix4(e),Ci[3].set(this.min.x,this.max.y,this.max.z).applyMatrix4(e),Ci[4].set(this.max.x,this.min.y,this.min.z).applyMatrix4(e),Ci[5].set(this.max.x,this.min.y,this.max.z).applyMatrix4(e),Ci[6].set(this.max.x,this.max.y,this.min.z).applyMatrix4(e),Ci[7].set(this.max.x,this.max.y,this.max.z).applyMatrix4(e),this.setFromPoints(Ci),this)}translate(e){return this.min.add(e),this.max.add(e),this}equals(e){return e.min.equals(this.min)&&e.max.equals(this.max)}toJSON(){return{min:this.min.toArray(),max:this.max.toArray()}}fromJSON(e){return this.min.fromArray(e.min),this.max.fromArray(e.max),this}},Ci=[new I,new I,new I,new I,new I,new I,new I,new I],$n=new I,lo=new gi,Fs=new I,Os=new I,Bs=new I,Wi=new I,Xi=new I,ds=new I,Nr=new I,co=new I,ho=new I,ps=new I;function Wc(i,e,t,n,s){for(let r=0,a=i.length-3;r<=a;r+=3){ps.fromArray(i,r);let o=s.x*Math.abs(ps.x)+s.y*Math.abs(ps.y)+s.z*Math.abs(ps.z),l=e.dot(ps),c=t.dot(ps),h=n.dot(ps);if(Math.max(-Math.max(l,c,h),Math.min(l,c,h))>o)return!1}return!0}var Kt=new I,uo=new ue,jf=0,jt=class extends pi{constructor(e,t,n=!1){if(super(),Array.isArray(e))throw new TypeError("THREE.BufferAttribute: array should be a Typed Array.");this.isBufferAttribute=!0,Object.defineProperty(this,"id",{value:jf++}),this.name="",this.array=e,this.itemSize=t,this.count=e!==void 0?e.length/t:0,this.normalized=n,this.usage=C0,this.updateRanges=[],this.gpuType=kn,this.version=0}onUploadCallback(){}set needsUpdate(e){e===!0&&this.version++}setUsage(e){return this.usage=e,this}addUpdateRange(e,t){this.updateRanges.push({start:e,count:t})}clearUpdateRanges(){this.updateRanges.length=0}copy(e){return this.name=e.name,this.array=new e.array.constructor(e.array),this.itemSize=e.itemSize,this.count=e.count,this.normalized=e.normalized,this.usage=e.usage,this.gpuType=e.gpuType,this}copyAt(e,t,n){e*=this.itemSize,n*=t.itemSize;for(let s=0,r=this.itemSize;s<r;s++)this.array[e+s]=t.array[n+s];return this}copyArray(e){return this.array.set(e),this}applyMatrix3(e){if(this.itemSize===2)for(let t=0,n=this.count;t<n;t++)uo.fromBufferAttribute(this,t),uo.applyMatrix3(e),this.setXY(t,uo.x,uo.y);else if(this.itemSize===3)for(let t=0,n=this.count;t<n;t++)Kt.fromBufferAttribute(this,t),Kt.applyMatrix3(e),this.setXYZ(t,Kt.x,Kt.y,Kt.z);return this}applyMatrix4(e){for(let t=0,n=this.count;t<n;t++)Kt.fromBufferAttribute(this,t),Kt.applyMatrix4(e),this.setXYZ(t,Kt.x,Kt.y,Kt.z);return this}applyNormalMatrix(e){for(let t=0,n=this.count;t<n;t++)Kt.fromBufferAttribute(this,t),Kt.applyNormalMatrix(e),this.setXYZ(t,Kt.x,Kt.y,Kt.z);return this}transformDirection(e){for(let t=0,n=this.count;t<n;t++)Kt.fromBufferAttribute(this,t),Kt.transformDirection(e),this.setXYZ(t,Kt.x,Kt.y,Kt.z);return this}set(e,t=0){return this.array.set(e,t),this}getComponent(e,t){let n=this.array[e*this.itemSize+t];return this.normalized&&(n=hi(n,this.array)),n}setComponent(e,t,n){return this.normalized&&(n=zt(n,this.array)),this.array[e*this.itemSize+t]=n,this}getX(e){let t=this.array[e*this.itemSize];return this.normalized&&(t=hi(t,this.array)),t}setX(e,t){return this.normalized&&(t=zt(t,this.array)),this.array[e*this.itemSize]=t,this}getY(e){let t=this.array[e*this.itemSize+1];return this.normalized&&(t=hi(t,this.array)),t}setY(e,t){return this.normalized&&(t=zt(t,this.array)),this.array[e*this.itemSize+1]=t,this}getZ(e){let t=this.array[e*this.itemSize+2];return this.normalized&&(t=hi(t,this.array)),t}setZ(e,t){return this.normalized&&(t=zt(t,this.array)),this.array[e*this.itemSize+2]=t,this}getW(e){let t=this.array[e*this.itemSize+3];return this.normalized&&(t=hi(t,this.array)),t}setW(e,t){return this.normalized&&(t=zt(t,this.array)),this.array[e*this.itemSize+3]=t,this}setXY(e,t,n){return e*=this.itemSize,this.normalized&&(t=zt(t,this.array),n=zt(n,this.array)),this.array[e+0]=t,this.array[e+1]=n,this}setXYZ(e,t,n,s){return e*=this.itemSize,this.normalized&&(t=zt(t,this.array),n=zt(n,this.array),s=zt(s,this.array)),this.array[e+0]=t,this.array[e+1]=n,this.array[e+2]=s,this}setXYZW(e,t,n,s,r){return e*=this.itemSize,this.normalized&&(t=zt(t,this.array),n=zt(n,this.array),s=zt(s,this.array),r=zt(r,this.array)),this.array[e+0]=t,this.array[e+1]=n,this.array[e+2]=s,this.array[e+3]=r,this}onUpload(e){return this.onUploadCallback=e,this}clone(){return new this.constructor(this.array,this.itemSize).copy(this)}toJSON(){let e={itemSize:this.itemSize,type:this.array.constructor.name,array:Array.from(this.array),normalized:this.normalized};return e.name=this.name,e.usage=this.usage,e.gpuType=this.gpuType,e}dispose(){this.dispatchEvent({type:"dispose"})}};var jr=class extends jt{constructor(e,t,n){super(new Uint16Array(e),t,n)}};var Qr=class extends jt{constructor(e,t,n){super(new Uint32Array(e),t,n)}};var ft=class extends jt{constructor(e,t,n){super(new Float32Array(e),t,n)}},Qf=new gi,Ur=new I,Xc=new I,_i=class{constructor(e=new I,t=-1){this.isSphere=!0,this.center=e,this.radius=t}set(e,t){return this.center.copy(e),this.radius=t,this}setFromPoints(e,t){let n=this.center;t!==void 0?n.copy(t):Qf.setFromPoints(e).getCenter(n);let s=0;for(let r=0,a=e.length;r<a;r++)s=Math.max(s,n.distanceToSquared(e[r]));return this.radius=Math.sqrt(s),this}copy(e){return this.center.copy(e.center),this.radius=e.radius,this}isEmpty(){return this.radius<0}makeEmpty(){return this.center.set(0,0,0),this.radius=-1,this}containsPoint(e){return e.distanceToSquared(this.center)<=this.radius*this.radius}distanceToPoint(e){return e.distanceTo(this.center)-this.radius}intersectsSphere(e){let t=this.radius+e.radius;return e.center.distanceToSquared(this.center)<=t*t}intersectsBox(e){return e.intersectsSphere(this)}intersectsPlane(e){return Math.abs(e.distanceToPoint(this.center))<=this.radius}clampPoint(e,t){let n=this.center.distanceToSquared(e);return t.copy(e),n>this.radius*this.radius&&(t.sub(this.center).normalize(),t.multiplyScalar(this.radius).add(this.center)),t}getBoundingBox(e){return this.isEmpty()?(e.makeEmpty(),e):(e.set(this.center,this.center),e.expandByScalar(this.radius),e)}applyMatrix4(e){return this.center.applyMatrix4(e),this.radius=this.radius*e.getMaxScaleOnAxis(),this}translate(e){return this.center.add(e),this}expandByPoint(e){if(this.isEmpty())return this.center.copy(e),this.radius=0,this;Ur.subVectors(e,this.center);let t=Ur.lengthSq();if(t>this.radius*this.radius){let n=Math.sqrt(t),s=(n-this.radius)*.5;this.center.addScaledVector(Ur,s/n),this.radius+=s}return this}union(e){return e.isEmpty()?this:this.isEmpty()?(this.copy(e),this):(this.center.equals(e.center)===!0?this.radius=Math.max(this.radius,e.radius):(Xc.subVectors(e.center,this.center).setLength(e.radius),this.expandByPoint(Ur.copy(e.center).add(Xc)),this.expandByPoint(Ur.copy(e.center).sub(Xc))),this)}equals(e){return e.center.equals(this.center)&&e.radius===this.radius}clone(){return new this.constructor().copy(this)}toJSON(){return{radius:this.radius,center:this.center.toArray()}}fromJSON(e){return this.radius=e.radius,this.center.fromArray(e.center),this}},ed=0,On=new Rt,qc=new Qt,zs=new I,Pn=new gi,Fr=new gi,hn=new I,wt=class i extends pi{constructor(){super(),this.isBufferGeometry=!0,Object.defineProperty(this,"id",{value:ed++}),this.uuid=Li(),this.name="",this.type="BufferGeometry",this.index=null,this.indirect=null,this.indirectOffset=0,this.attributes={},this.morphAttributes={},this.morphTargetsRelative=!1,this.groups=[],this.boundingBox=null,this.boundingSphere=null,this.drawRange={start:0,count:1/0},this.userData={},this._transformed=!1}getIndex(){return this.index}setIndex(e){return Array.isArray(e)?this.index=new(zf(e)?Qr:jr)(e,1):this.index=e,this}setIndirect(e,t=0){return this.indirect=e,this.indirectOffset=t,this}getIndirect(){return this.indirect}getAttribute(e){return this.attributes[e]}setAttribute(e,t){return this.attributes[e]=t,this}deleteAttribute(e){return delete this.attributes[e],this}hasAttribute(e){return this.attributes[e]!==void 0}addGroup(e,t,n=0){this.groups.push({start:e,count:t,materialIndex:n})}clearGroups(){this.groups=[]}setDrawRange(e,t){this.drawRange.start=e,this.drawRange.count=t}applyMatrix4(e){let t=this.attributes.position;t!==void 0&&(t.applyMatrix4(e),t.needsUpdate=!0);let n=this.attributes.normal;if(n!==void 0){let r=new dt().getNormalMatrix(e);n.applyNormalMatrix(r),n.needsUpdate=!0}let s=this.attributes.tangent;return s!==void 0&&(s.transformDirection(e),s.needsUpdate=!0),this.boundingBox!==null&&this.computeBoundingBox(),this.boundingSphere!==null&&this.computeBoundingSphere(),this._transformed=!0,this}applyQuaternion(e){return On.makeRotationFromQuaternion(e),this.applyMatrix4(On),this}rotateX(e){return On.makeRotationX(e),this.applyMatrix4(On),this}rotateY(e){return On.makeRotationY(e),this.applyMatrix4(On),this}rotateZ(e){return On.makeRotationZ(e),this.applyMatrix4(On),this}translate(e,t,n){return On.makeTranslation(e,t,n),this.applyMatrix4(On),this}scale(e,t,n){return On.makeScale(e,t,n),this.applyMatrix4(On),this}lookAt(e){return qc.lookAt(e),qc.updateMatrix(),this.applyMatrix4(qc.matrix),this}center(){return this.computeBoundingBox(),this.boundingBox.getCenter(zs).negate(),this.translate(zs.x,zs.y,zs.z),this}setFromPoints(e){let t=this.getAttribute("position");if(t===void 0){let n=[];for(let s=0,r=e.length;s<r;s++){let a=e[s];n.push(a.x,a.y,a.z||0)}this.setAttribute("position",new ft(n,3))}else{let n=Math.min(e.length,t.count);for(let s=0;s<n;s++){let r=e[s];t.setXYZ(s,r.x,r.y,r.z||0)}e.length>t.count&&ct("BufferGeometry: Buffer size too small for points data. Use .dispose() and create a new geometry."),t.needsUpdate=!0}return this}computeBoundingBox(){this.boundingBox===null&&(this.boundingBox=new gi);let e=this.attributes.position,t=this.morphAttributes.position;if(e&&e.isGLBufferAttribute){lt("BufferGeometry.computeBoundingBox(): GLBufferAttribute requires a manual bounding box.",this),this.boundingBox.set(new I(-1/0,-1/0,-1/0),new I(1/0,1/0,1/0));return}if(e!==void 0){if(this.boundingBox.setFromBufferAttribute(e),t)for(let n=0,s=t.length;n<s;n++){let r=t[n];Pn.setFromBufferAttribute(r),this.morphTargetsRelative?(hn.addVectors(this.boundingBox.min,Pn.min),this.boundingBox.expandByPoint(hn),hn.addVectors(this.boundingBox.max,Pn.max),this.boundingBox.expandByPoint(hn)):(this.boundingBox.expandByPoint(Pn.min),this.boundingBox.expandByPoint(Pn.max))}}else this.boundingBox.makeEmpty();(isNaN(this.boundingBox.min.x)||isNaN(this.boundingBox.min.y)||isNaN(this.boundingBox.min.z))&&lt('BufferGeometry.computeBoundingBox(): Computed min/max have NaN values. The "position" attribute is likely to have NaN values.',this)}computeBoundingSphere(){this.boundingSphere===null&&(this.boundingSphere=new _i);let e=this.attributes.position,t=this.morphAttributes.position;if(e&&e.isGLBufferAttribute){lt("BufferGeometry.computeBoundingSphere(): GLBufferAttribute requires a manual bounding sphere.",this),this.boundingSphere.set(new I,1/0);return}if(e){let n=this.boundingSphere.center;if(Pn.setFromBufferAttribute(e),t)for(let r=0,a=t.length;r<a;r++){let o=t[r];Fr.setFromBufferAttribute(o),this.morphTargetsRelative?(hn.addVectors(Pn.min,Fr.min),Pn.expandByPoint(hn),hn.addVectors(Pn.max,Fr.max),Pn.expandByPoint(hn)):(Pn.expandByPoint(Fr.min),Pn.expandByPoint(Fr.max))}Pn.getCenter(n);let s=0;for(let r=0,a=e.count;r<a;r++)hn.fromBufferAttribute(e,r),s=Math.max(s,n.distanceToSquared(hn));if(t)for(let r=0,a=t.length;r<a;r++){let o=t[r],l=this.morphTargetsRelative;for(let c=0,h=o.count;c<h;c++)hn.fromBufferAttribute(o,c),l&&(zs.fromBufferAttribute(e,c),hn.add(zs)),s=Math.max(s,n.distanceToSquared(hn))}this.boundingSphere.radius=Math.sqrt(s),isNaN(this.boundingSphere.radius)&&lt('BufferGeometry.computeBoundingSphere(): Computed radius is NaN. The "position" attribute is likely to have NaN values.',this)}}computeTangents(){let e=this.index,t=this.attributes;if(e===null||t.position===void 0||t.normal===void 0||t.uv===void 0){lt("BufferGeometry: .computeTangents() failed. Missing required attributes (index, position, normal or uv)");return}let n=t.position,s=t.normal,r=t.uv,a=this.getAttribute("tangent");(a===void 0||a.count!==n.count)&&(a=new jt(new Float32Array(4*n.count),4),this.setAttribute("tangent",a));let o=[],l=[];for(let y=0;y<n.count;y++)o[y]=new I,l[y]=new I;let c=new I,h=new I,f=new I,u=new ue,d=new ue,g=new ue,x=new I,m=new I;function p(y,w,P){c.fromBufferAttribute(n,y),h.fromBufferAttribute(n,w),f.fromBufferAttribute(n,P),u.fromBufferAttribute(r,y),d.fromBufferAttribute(r,w),g.fromBufferAttribute(r,P),h.sub(c),f.sub(c),d.sub(u),g.sub(u);let U=1/(d.x*g.y-g.x*d.y);isFinite(U)&&(x.copy(h).multiplyScalar(g.y).addScaledVector(f,-d.y).multiplyScalar(U),m.copy(f).multiplyScalar(d.x).addScaledVector(h,-g.x).multiplyScalar(U),o[y].add(x),o[w].add(x),o[P].add(x),l[y].add(m),l[w].add(m),l[P].add(m))}let S=this.groups;S.length===0&&(S=[{start:0,count:e.count}]);for(let y=0,w=S.length;y<w;++y){let P=S[y],U=P.start,B=P.count;for(let W=U,F=U+B;W<F;W+=3)p(e.getX(W+0),e.getX(W+1),e.getX(W+2))}let A=new I,v=new I,b=new I,E=new I;function C(y){b.fromBufferAttribute(s,y),E.copy(b);let w=o[y];A.copy(w),A.sub(b.multiplyScalar(b.dot(w))).normalize(),v.crossVectors(E,w);let U=v.dot(l[y])<0?-1:1;a.setXYZW(y,A.x,A.y,A.z,U)}for(let y=0,w=S.length;y<w;++y){let P=S[y],U=P.start,B=P.count;for(let W=U,F=U+B;W<F;W+=3)C(e.getX(W+0)),C(e.getX(W+1)),C(e.getX(W+2))}this._transformed=!0}computeVertexNormals(){let e=this.index,t=this.getAttribute("position");if(t!==void 0){let n=this.getAttribute("normal");if(n===void 0||n.count!==t.count)n=new jt(new Float32Array(t.count*3),3),this.setAttribute("normal",n);else for(let u=0,d=n.count;u<d;u++)n.setXYZ(u,0,0,0);let s=new I,r=new I,a=new I,o=new I,l=new I,c=new I,h=new I,f=new I;if(e)for(let u=0,d=e.count;u<d;u+=3){let g=e.getX(u+0),x=e.getX(u+1),m=e.getX(u+2);s.fromBufferAttribute(t,g),r.fromBufferAttribute(t,x),a.fromBufferAttribute(t,m),h.subVectors(a,r),f.subVectors(s,r),h.cross(f),o.fromBufferAttribute(n,g),l.fromBufferAttribute(n,x),c.fromBufferAttribute(n,m),o.add(h),l.add(h),c.add(h),n.setXYZ(g,o.x,o.y,o.z),n.setXYZ(x,l.x,l.y,l.z),n.setXYZ(m,c.x,c.y,c.z)}else for(let u=0,d=t.count;u<d;u+=3)s.fromBufferAttribute(t,u+0),r.fromBufferAttribute(t,u+1),a.fromBufferAttribute(t,u+2),h.subVectors(a,r),f.subVectors(s,r),h.cross(f),n.setXYZ(u+0,h.x,h.y,h.z),n.setXYZ(u+1,h.x,h.y,h.z),n.setXYZ(u+2,h.x,h.y,h.z);this.normalizeNormals(),n.needsUpdate=!0}}normalizeNormals(){let e=this.attributes.normal;for(let t=0,n=e.count;t<n;t++)hn.fromBufferAttribute(e,t),hn.normalize(),e.setXYZ(t,hn.x,hn.y,hn.z)}toNonIndexed(){function e(o,l){let c=o.array,h=o.itemSize,f=o.normalized,u=new c.constructor(l.length*h),d=0,g=0;for(let x=0,m=l.length;x<m;x++){o.isInterleavedBufferAttribute?d=l[x]*o.data.stride+o.offset:d=l[x]*h;for(let p=0;p<h;p++)u[g++]=c[d++]}return new jt(u,h,f)}if(this.index===null)return ct("BufferGeometry.toNonIndexed(): BufferGeometry is already non-indexed."),this;let t=new i,n=this.index.array,s=this.attributes;for(let o in s){let l=s[o],c=e(l,n);t.setAttribute(o,c)}let r=this.morphAttributes;for(let o in r){let l=[],c=r[o];for(let h=0,f=c.length;h<f;h++){let u=c[h],d=e(u,n);l.push(d)}t.morphAttributes[o]=l}t.morphTargetsRelative=this.morphTargetsRelative;let a=this.groups;for(let o=0,l=a.length;o<l;o++){let c=a[o];t.addGroup(c.start,c.count,c.materialIndex)}return t}toJSON(){let e={metadata:{version:4.7,type:"BufferGeometry",generator:"BufferGeometry.toJSON"}};if(e.uuid=this.uuid,e.type=this.parameters!==void 0&&this._transformed===!0?"BufferGeometry":this.type,e.name=this.name,Object.keys(this.userData).length>0&&(e.userData=this.userData),this.parameters!==void 0&&this._transformed!==!0){let l=this.parameters;for(let c in l)l[c]!==void 0&&(e[c]=l[c]);return e}e.data={attributes:{}};let t=this.index;t!==null&&(e.data.index={type:t.array.constructor.name,array:Array.prototype.slice.call(t.array)});let n=this.attributes;for(let l in n){let c=n[l];e.data.attributes[l]=c.toJSON(e.data)}let s={},r=!1;for(let l in this.morphAttributes){let c=this.morphAttributes[l],h=[];for(let f=0,u=c.length;f<u;f++){let d=c[f];h.push(d.toJSON(e.data))}h.length>0&&(s[l]=h,r=!0)}r&&(e.data.morphAttributes=s,e.data.morphTargetsRelative=this.morphTargetsRelative);let a=this.groups;a.length>0&&(e.data.groups=JSON.parse(JSON.stringify(a)));let o=this.boundingSphere;return o!==null&&(e.data.boundingSphere=o.toJSON()),e}clone(){return new this.constructor().copy(this)}copy(e){this.index=null,this.attributes={},this.morphAttributes={},this.groups=[],this.boundingBox=null,this.boundingSphere=null;let t={};this.name=e.name;let n=e.index;n!==null&&this.setIndex(n.clone());let s=e.attributes;for(let c in s){let h=s[c];this.setAttribute(c,h.clone(t))}let r=e.morphAttributes;for(let c in r){let h=[],f=r[c];for(let u=0,d=f.length;u<d;u++)h.push(f[u].clone(t));this.morphAttributes[c]=h}this.morphTargetsRelative=e.morphTargetsRelative;let a=e.groups;for(let c=0,h=a.length;c<h;c++){let f=a[c];this.addGroup(f.start,f.count,f.materialIndex)}let o=e.boundingBox;o!==null&&(this.boundingBox=o.clone());let l=e.boundingSphere;return l!==null&&(this.boundingSphere=l.clone()),this.drawRange.start=e.drawRange.start,this.drawRange.count=e.drawRange.count,this.userData=e.userData,this._transformed=e._transformed,this}dispose(){this.dispatchEvent({type:"dispose"})}},ea=class{constructor(e,t){this.isInterleavedBuffer=!0,this.array=e,this.stride=t,this.count=e!==void 0?e.length/t:0,this.usage=C0,this.updateRanges=[],this.version=0,this.uuid=Li()}onUploadCallback(){}set needsUpdate(e){e===!0&&this.version++}setUsage(e){return this.usage=e,this}addUpdateRange(e,t){this.updateRanges.push({start:e,count:t})}clearUpdateRanges(){this.updateRanges.length=0}copy(e){return this.array=new e.array.constructor(e.array),this.count=e.count,this.stride=e.stride,this.usage=e.usage,this}copyAt(e,t,n){e*=this.stride,n*=t.stride;for(let s=0,r=this.stride;s<r;s++)this.array[e+s]=t.array[n+s];return this}set(e,t=0){return this.array.set(e,t),this}clone(e){e.arrayBuffers===void 0&&(e.arrayBuffers={}),this.array.buffer._uuid===void 0&&(this.array.buffer._uuid=Li()),e.arrayBuffers[this.array.buffer._uuid]===void 0&&(e.arrayBuffers[this.array.buffer._uuid]=this.array.slice(0).buffer);let t=new this.array.constructor(e.arrayBuffers[this.array.buffer._uuid]),n=new this.constructor(t,this.stride);return n.setUsage(this.usage),n}onUpload(e){return this.onUploadCallback=e,this}toJSON(e){e.arrayBuffers===void 0&&(e.arrayBuffers={}),this.array.buffer._uuid===void 0&&(this.array.buffer._uuid=Li()),e.arrayBuffers[this.array.buffer._uuid]===void 0&&(e.arrayBuffers[this.array.buffer._uuid]=Array.from(new Uint32Array(this.array.buffer)));let t={uuid:this.uuid,buffer:this.array.buffer._uuid,type:this.array.constructor.name,stride:this.stride};return t.usage=this.usage,t}},Tn=new I,ir=class i{constructor(e,t,n,s=!1){this.isInterleavedBufferAttribute=!0,this.name="",this.data=e,this.itemSize=t,this.offset=n,this.normalized=s}get count(){return this.data.count}get array(){return this.data.array}set needsUpdate(e){this.data.needsUpdate=e}applyMatrix4(e){for(let t=0,n=this.data.count;t<n;t++)Tn.fromBufferAttribute(this,t),Tn.applyMatrix4(e),this.setXYZ(t,Tn.x,Tn.y,Tn.z);return this}applyNormalMatrix(e){for(let t=0,n=this.count;t<n;t++)Tn.fromBufferAttribute(this,t),Tn.applyNormalMatrix(e),this.setXYZ(t,Tn.x,Tn.y,Tn.z);return this}transformDirection(e){for(let t=0,n=this.count;t<n;t++)Tn.fromBufferAttribute(this,t),Tn.transformDirection(e),this.setXYZ(t,Tn.x,Tn.y,Tn.z);return this}getComponent(e,t){let n=this.array[e*this.data.stride+this.offset+t];return this.normalized&&(n=hi(n,this.array)),n}setComponent(e,t,n){return this.normalized&&(n=zt(n,this.array)),this.data.array[e*this.data.stride+this.offset+t]=n,this}setX(e,t){return this.normalized&&(t=zt(t,this.array)),this.data.array[e*this.data.stride+this.offset]=t,this}setY(e,t){return this.normalized&&(t=zt(t,this.array)),this.data.array[e*this.data.stride+this.offset+1]=t,this}setZ(e,t){return this.normalized&&(t=zt(t,this.array)),this.data.array[e*this.data.stride+this.offset+2]=t,this}setW(e,t){return this.normalized&&(t=zt(t,this.array)),this.data.array[e*this.data.stride+this.offset+3]=t,this}getX(e){let t=this.data.array[e*this.data.stride+this.offset];return this.normalized&&(t=hi(t,this.array)),t}getY(e){let t=this.data.array[e*this.data.stride+this.offset+1];return this.normalized&&(t=hi(t,this.array)),t}getZ(e){let t=this.data.array[e*this.data.stride+this.offset+2];return this.normalized&&(t=hi(t,this.array)),t}getW(e){let t=this.data.array[e*this.data.stride+this.offset+3];return this.normalized&&(t=hi(t,this.array)),t}setXY(e,t,n){return e=e*this.data.stride+this.offset,this.normalized&&(t=zt(t,this.array),n=zt(n,this.array)),this.data.array[e+0]=t,this.data.array[e+1]=n,this}setXYZ(e,t,n,s){return e=e*this.data.stride+this.offset,this.normalized&&(t=zt(t,this.array),n=zt(n,this.array),s=zt(s,this.array)),this.data.array[e+0]=t,this.data.array[e+1]=n,this.data.array[e+2]=s,this}setXYZW(e,t,n,s,r){return e=e*this.data.stride+this.offset,this.normalized&&(t=zt(t,this.array),n=zt(n,this.array),s=zt(s,this.array),r=zt(r,this.array)),this.data.array[e+0]=t,this.data.array[e+1]=n,this.data.array[e+2]=s,this.data.array[e+3]=r,this}clone(e){if(e===void 0){Zr("InterleavedBufferAttribute.clone(): Cloning an interleaved buffer attribute will de-interleave buffer data.");let t=[];for(let n=0;n<this.count;n++){let s=n*this.data.stride+this.offset;for(let r=0;r<this.itemSize;r++)t.push(this.data.array[s+r])}return new jt(new this.array.constructor(t),this.itemSize,this.normalized)}else return e.interleavedBuffers===void 0&&(e.interleavedBuffers={}),e.interleavedBuffers[this.data.uuid]===void 0&&(e.interleavedBuffers[this.data.uuid]=this.data.clone(e)),new i(e.interleavedBuffers[this.data.uuid],this.itemSize,this.offset,this.normalized)}toJSON(e){if(e===void 0){Zr("InterleavedBufferAttribute.toJSON(): Serializing an interleaved buffer attribute will de-interleave buffer data.");let t=[];for(let n=0;n<this.count;n++){let s=n*this.data.stride+this.offset;for(let r=0;r<this.itemSize;r++)t.push(this.data.array[s+r])}return{itemSize:this.itemSize,type:this.array.constructor.name,array:t,normalized:this.normalized}}else return e.interleavedBuffers===void 0&&(e.interleavedBuffers={}),e.interleavedBuffers[this.data.uuid]===void 0&&(e.interleavedBuffers[this.data.uuid]=this.data.toJSON(e)),{isInterleavedBufferAttribute:!0,itemSize:this.itemSize,data:this.data.uuid,offset:this.offset,normalized:this.normalized}}},Yc=new I,td=new I,nd=new dt,Zn=class{constructor(e=new I(1,0,0),t=0){this.isPlane=!0,this.normal=e,this.constant=t}set(e,t){return this.normal.copy(e),this.constant=t,this}setComponents(e,t,n,s){return this.normal.set(e,t,n),this.constant=s,this}setFromNormalAndCoplanarPoint(e,t){return this.normal.copy(e),this.constant=-t.dot(this.normal),this}setFromCoplanarPoints(e,t,n){let s=Yc.subVectors(n,t).cross(td.subVectors(e,t)).normalize();return this.setFromNormalAndCoplanarPoint(s,e),this}copy(e){return this.normal.copy(e.normal),this.constant=e.constant,this}normalize(){let e=1/this.normal.length();return this.normal.multiplyScalar(e),this.constant*=e,this}negate(){return this.constant*=-1,this.normal.negate(),this}distanceToPoint(e){return this.normal.dot(e)+this.constant}distanceToSphere(e){return this.distanceToPoint(e.center)-e.radius}projectPoint(e,t){return t.copy(e).addScaledVector(this.normal,-this.distanceToPoint(e))}intersectLine(e,t,n=!0){let s=e.delta(Yc),r=this.normal.dot(s);if(r===0)return this.distanceToPoint(e.start)===0?t.copy(e.start):null;let a=-(e.start.dot(this.normal)+this.constant)/r;return n===!0&&(a<0||a>1)?null:t.copy(e.start).addScaledVector(s,a)}intersectsLine(e){let t=this.distanceToPoint(e.start),n=this.distanceToPoint(e.end);return t<0&&n>0||n<0&&t>0}intersectsBox(e){return e.intersectsPlane(this)}intersectsSphere(e){return e.intersectsPlane(this)}coplanarPoint(e){return e.copy(this.normal).multiplyScalar(-this.constant)}applyMatrix4(e,t){let n=t||nd.getNormalMatrix(e),s=this.coplanarPoint(Yc).applyMatrix4(e),r=this.normal.applyMatrix3(n).normalize();return this.constant=-s.dot(r),this}translate(e){return this.constant-=e.dot(this.normal),this}equals(e){return e.normal.equals(this.normal)&&e.constant===this.constant}clone(){return new this.constructor().copy(this)}toJSON(){return{normal:this.normal.toArray(),constant:this.constant}}fromJSON(e){return this.normal.fromArray(e.normal),this.constant=e.constant,this}},id=0,Kn=class extends pi{constructor(){super(),this.isMaterial=!0,Object.defineProperty(this,"id",{value:id++}),this.uuid=Li(),this.name="",this.type="Material",this.blending=ns,this.side=ts,this.vertexColors=!1,this.opacity=1,this.transparent=!1,this.alphaHash=!1,this.blendSrc=v0,this.blendDst=y0,this.blendEquation=ys,this.blendSrcAlpha=null,this.blendDstAlpha=null,this.blendEquationAlpha=null,this.blendColor=new it(0,0,0),this.blendAlpha=0,this.depthFunc=Js,this.depthTest=!0,this.depthWrite=!0,this.stencilWriteMask=255,this.stencilFunc=bu,this.stencilRef=0,this.stencilFuncMask=255,this.stencilFail=Oo,this.stencilZFail=Oo,this.stencilZPass=Oo,this.stencilWrite=!1,this.clippingPlanes=null,this.clipIntersection=!1,this.clipShadows=!1,this.shadowSide=null,this.colorWrite=!0,this.precision=null,this.polygonOffset=!1,this.polygonOffsetFactor=0,this.polygonOffsetUnits=0,this.dithering=!1,this.alphaToCoverage=!1,this.premultipliedAlpha=!1,this.forceSinglePass=!1,this.allowOverride=!0,this.visible=!0,this.toneMapped=!0,this.userData={},this.version=0,this._alphaTest=0}get alphaTest(){return this._alphaTest}set alphaTest(e){this._alphaTest>0!=e>0&&this.version++,this._alphaTest=e}onBeforeRender(){}onBeforeCompile(){}customProgramCacheKey(){return this.onBeforeCompile.toString()}setValues(e){if(e!==void 0)for(let t in e){let n=e[t];if(n===void 0){ct(`Material: parameter '${t}' has value of undefined.`);continue}let s=this[t];if(s===void 0){ct(`Material: '${t}' is not a property of THREE.${this.type}.`);continue}s&&s.isColor?s.set(n):s&&s.isVector2&&n&&n.isVector2||s&&s.isEuler&&n&&n.isEuler||s&&s.isVector3&&n&&n.isVector3?s.copy(n):this[t]=n}}toJSON(e){let t=e===void 0||typeof e=="string";t&&(e={textures:{},images:{}});let n={metadata:{version:4.7,type:"Material",generator:"Material.toJSON"}};n.uuid=this.uuid,n.type=this.type,n.blending=this.blending,n.side=this.side,n.shadowSide=this.shadowSide,n.vertexColors=this.vertexColors,n.opacity=this.opacity,n.transparent=this.transparent,n.blendSrc=this.blendSrc,n.blendDst=this.blendDst,n.blendEquation=this.blendEquation,n.blendSrcAlpha=this.blendSrcAlpha,n.blendDstAlpha=this.blendDstAlpha,n.blendEquationAlpha=this.blendEquationAlpha,n.blendColor=this.blendColor.getHex(),n.blendAlpha=this.blendAlpha,n.depthFunc=this.depthFunc,n.depthTest=this.depthTest,n.depthWrite=this.depthWrite,n.colorWrite=this.colorWrite,n.clipIntersection=this.clipIntersection,n.clipShadows=this.clipShadows,n.stencilWriteMask=this.stencilWriteMask,n.stencilFunc=this.stencilFunc,n.stencilRef=this.stencilRef,n.stencilFuncMask=this.stencilFuncMask,n.stencilFail=this.stencilFail,n.stencilZFail=this.stencilZFail,n.stencilZPass=this.stencilZPass,n.stencilWrite=this.stencilWrite,n.polygonOffset=this.polygonOffset,n.polygonOffsetFactor=this.polygonOffsetFactor,n.polygonOffsetUnits=this.polygonOffsetUnits,n.dithering=this.dithering,n.alphaTest=this.alphaTest,n.alphaHash=this.alphaHash,n.alphaToCoverage=this.alphaToCoverage,n.premultipliedAlpha=this.premultipliedAlpha,n.forceSinglePass=this.forceSinglePass,n.allowOverride=this.allowOverride,n.visible=this.visible,n.toneMapped=this.toneMapped,n.name=this.name,this.color&&this.color.isColor&&(n.color=this.color.getHex()),this.roughness!==void 0&&(n.roughness=this.roughness),this.metalness!==void 0&&(n.metalness=this.metalness),this.sheen!==void 0&&(n.sheen=this.sheen),this.sheenColor&&this.sheenColor.isColor&&(n.sheenColor=this.sheenColor.getHex()),this.sheenRoughness!==void 0&&(n.sheenRoughness=this.sheenRoughness),this.emissive&&this.emissive.isColor&&(n.emissive=this.emissive.getHex()),this.emissiveIntensity!==void 0&&(n.emissiveIntensity=this.emissiveIntensity),this.specular&&this.specular.isColor&&(n.specular=this.specular.getHex()),this.specularIntensity!==void 0&&(n.specularIntensity=this.specularIntensity),this.specularColor&&this.specularColor.isColor&&(n.specularColor=this.specularColor.getHex()),this.shininess!==void 0&&(n.shininess=this.shininess),this.clearcoat!==void 0&&(n.clearcoat=this.clearcoat),this.clearcoatRoughness!==void 0&&(n.clearcoatRoughness=this.clearcoatRoughness),this.clearcoatMap&&this.clearcoatMap.isTexture&&(n.clearcoatMap=this.clearcoatMap.toJSON(e).uuid),this.clearcoatRoughnessMap&&this.clearcoatRoughnessMap.isTexture&&(n.clearcoatRoughnessMap=this.clearcoatRoughnessMap.toJSON(e).uuid),this.clearcoatNormalMap&&this.clearcoatNormalMap.isTexture&&(n.clearcoatNormalMap=this.clearcoatNormalMap.toJSON(e).uuid,n.clearcoatNormalScale=this.clearcoatNormalScale.toArray()),this.sheenColorMap&&this.sheenColorMap.isTexture&&(n.sheenColorMap=this.sheenColorMap.toJSON(e).uuid),this.sheenRoughnessMap&&this.sheenRoughnessMap.isTexture&&(n.sheenRoughnessMap=this.sheenRoughnessMap.toJSON(e).uuid),this.dispersion!==void 0&&(n.dispersion=this.dispersion),this.retroreflectivity!==void 0&&(n.retroreflectivity=this.retroreflectivity),this.iridescence!==void 0&&(n.iridescence=this.iridescence),this.iridescenceIOR!==void 0&&(n.iridescenceIOR=this.iridescenceIOR),this.iridescenceThicknessRange!==void 0&&(n.iridescenceThicknessRange=this.iridescenceThicknessRange),this.iridescenceMap&&this.iridescenceMap.isTexture&&(n.iridescenceMap=this.iridescenceMap.toJSON(e).uuid),this.iridescenceThicknessMap&&this.iridescenceThicknessMap.isTexture&&(n.iridescenceThicknessMap=this.iridescenceThicknessMap.toJSON(e).uuid),this.anisotropy!==void 0&&(n.anisotropy=this.anisotropy),this.anisotropyRotation!==void 0&&(n.anisotropyRotation=this.anisotropyRotation),this.anisotropyMap&&this.anisotropyMap.isTexture&&(n.anisotropyMap=this.anisotropyMap.toJSON(e).uuid),this.map&&this.map.isTexture&&(n.map=this.map.toJSON(e).uuid),this.matcap&&this.matcap.isTexture&&(n.matcap=this.matcap.toJSON(e).uuid),this.alphaMap&&this.alphaMap.isTexture&&(n.alphaMap=this.alphaMap.toJSON(e).uuid),this.lightMap&&this.lightMap.isTexture&&(n.lightMap=this.lightMap.toJSON(e).uuid,n.lightMapIntensity=this.lightMapIntensity),this.aoMap&&this.aoMap.isTexture&&(n.aoMap=this.aoMap.toJSON(e).uuid,n.aoMapIntensity=this.aoMapIntensity),this.bumpMap&&this.bumpMap.isTexture&&(n.bumpMap=this.bumpMap.toJSON(e).uuid,n.bumpScale=this.bumpScale),this.normalMap&&this.normalMap.isTexture&&(n.normalMap=this.normalMap.toJSON(e).uuid,n.normalMapType=this.normalMapType,n.normalScale=this.normalScale.toArray()),this.displacementMap&&this.displacementMap.isTexture&&(n.displacementMap=this.displacementMap.toJSON(e).uuid,n.displacementScale=this.displacementScale,n.displacementBias=this.displacementBias),this.roughnessMap&&this.roughnessMap.isTexture&&(n.roughnessMap=this.roughnessMap.toJSON(e).uuid),this.metalnessMap&&this.metalnessMap.isTexture&&(n.metalnessMap=this.metalnessMap.toJSON(e).uuid),this.emissiveMap&&this.emissiveMap.isTexture&&(n.emissiveMap=this.emissiveMap.toJSON(e).uuid),this.specularMap&&this.specularMap.isTexture&&(n.specularMap=this.specularMap.toJSON(e).uuid),this.specularIntensityMap&&this.specularIntensityMap.isTexture&&(n.specularIntensityMap=this.specularIntensityMap.toJSON(e).uuid),this.specularColorMap&&this.specularColorMap.isTexture&&(n.specularColorMap=this.specularColorMap.toJSON(e).uuid),this.envMap&&this.envMap.isTexture&&(n.envMap=this.envMap.toJSON(e).uuid,this.combine!==void 0&&(n.combine=this.combine)),this.envMapRotation!==void 0&&(n.envMapRotation=this.envMapRotation.toArray()),this.envMapIntensity!==void 0&&(n.envMapIntensity=this.envMapIntensity),this.reflectivity!==void 0&&(n.reflectivity=this.reflectivity),this.refractionRatio!==void 0&&(n.refractionRatio=this.refractionRatio),this.gradientMap&&this.gradientMap.isTexture&&(n.gradientMap=this.gradientMap.toJSON(e).uuid),this.transmission!==void 0&&(n.transmission=this.transmission),this.transmissionMap&&this.transmissionMap.isTexture&&(n.transmissionMap=this.transmissionMap.toJSON(e).uuid),this.thickness!==void 0&&(n.thickness=this.thickness),this.thicknessMap&&this.thicknessMap.isTexture&&(n.thicknessMap=this.thicknessMap.toJSON(e).uuid),this.attenuationDistance!==void 0&&(n.attenuationDistance=this.attenuationDistance),this.attenuationColor!==void 0&&(n.attenuationColor=this.attenuationColor.getHex()),this.size!==void 0&&(n.size=this.size),this.sizeAttenuation!==void 0&&(n.sizeAttenuation=this.sizeAttenuation),Array.isArray(this.clippingPlanes)&&this.clippingPlanes.length>0&&(n.clippingPlanes=this.clippingPlanes.map(r=>r.toJSON())),this.rotation!==void 0&&(n.rotation=this.rotation),this.depthPacking!==void 0&&(n.depthPacking=this.depthPacking),this.linewidth!==void 0&&(n.linewidth=this.linewidth),this.linecap!==void 0&&(n.linecap=this.linecap),this.linejoin!==void 0&&(n.linejoin=this.linejoin),this.dashSize!==void 0&&(n.dashSize=this.dashSize),this.gapSize!==void 0&&(n.gapSize=this.gapSize),this.scale!==void 0&&(n.scale=this.scale),this.wireframe!==void 0&&(n.wireframe=this.wireframe),this.wireframeLinewidth!==void 0&&(n.wireframeLinewidth=this.wireframeLinewidth),this.wireframeLinecap!==void 0&&(n.wireframeLinecap=this.wireframeLinecap),this.wireframeLinejoin!==void 0&&(n.wireframeLinejoin=this.wireframeLinejoin),this.flatShading!==void 0&&(n.flatShading=this.flatShading),this.fog!==void 0&&(n.fog=this.fog),Object.keys(this.userData).length>0&&(n.userData=this.userData);function s(r){let a=[];for(let o in r){let l=r[o];delete l.metadata,a.push(l)}return a}if(t){let r=s(e.textures),a=s(e.images);r.length>0&&(n.textures=r),a.length>0&&(n.images=a)}return n}fromJSON(e,t){if(e.uuid!==void 0&&(this.uuid=e.uuid),e.name!==void 0&&(this.name=e.name),e.color!==void 0&&this.color!==void 0&&this.color.setHex(e.color),e.roughness!==void 0&&(this.roughness=e.roughness),e.metalness!==void 0&&(this.metalness=e.metalness),e.sheen!==void 0&&(this.sheen=e.sheen),e.sheenColor!==void 0&&(this.sheenColor=new it().setHex(e.sheenColor)),e.sheenRoughness!==void 0&&(this.sheenRoughness=e.sheenRoughness),e.emissive!==void 0&&this.emissive!==void 0&&this.emissive.setHex(e.emissive),e.specular!==void 0&&this.specular!==void 0&&this.specular.setHex(e.specular),e.specularIntensity!==void 0&&(this.specularIntensity=e.specularIntensity),e.specularColor!==void 0&&this.specularColor!==void 0&&this.specularColor.setHex(e.specularColor),e.shininess!==void 0&&(this.shininess=e.shininess),e.clearcoat!==void 0&&(this.clearcoat=e.clearcoat),e.clearcoatRoughness!==void 0&&(this.clearcoatRoughness=e.clearcoatRoughness),e.dispersion!==void 0&&(this.dispersion=e.dispersion),e.retroreflectivity!==void 0&&(this.retroreflectivity=e.retroreflectivity),e.iridescence!==void 0&&(this.iridescence=e.iridescence),e.iridescenceIOR!==void 0&&(this.iridescenceIOR=e.iridescenceIOR),e.iridescenceThicknessRange!==void 0&&(this.iridescenceThicknessRange=e.iridescenceThicknessRange),e.transmission!==void 0&&(this.transmission=e.transmission),e.thickness!==void 0&&(this.thickness=e.thickness),e.attenuationDistance!==void 0&&(this.attenuationDistance=e.attenuationDistance),e.attenuationColor!==void 0&&this.attenuationColor!==void 0&&this.attenuationColor.setHex(e.attenuationColor),e.anisotropy!==void 0&&(this.anisotropy=e.anisotropy),e.anisotropyRotation!==void 0&&(this.anisotropyRotation=e.anisotropyRotation),e.fog!==void 0&&(this.fog=e.fog),e.flatShading!==void 0&&(this.flatShading=e.flatShading),e.blending!==void 0&&(this.blending=e.blending),e.combine!==void 0&&(this.combine=e.combine),e.side!==void 0&&(this.side=e.side),e.shadowSide!==void 0&&(this.shadowSide=e.shadowSide),e.opacity!==void 0&&(this.opacity=e.opacity),e.transparent!==void 0&&(this.transparent=e.transparent),e.alphaTest!==void 0&&(this.alphaTest=e.alphaTest),e.alphaHash!==void 0&&(this.alphaHash=e.alphaHash),e.depthFunc!==void 0&&(this.depthFunc=e.depthFunc),e.depthTest!==void 0&&(this.depthTest=e.depthTest),e.depthWrite!==void 0&&(this.depthWrite=e.depthWrite),e.colorWrite!==void 0&&(this.colorWrite=e.colorWrite),e.clippingPlanes!==void 0&&(this.clippingPlanes=e.clippingPlanes.map(n=>new Zn().fromJSON(n))),e.clipIntersection!==void 0&&(this.clipIntersection=e.clipIntersection),e.clipShadows!==void 0&&(this.clipShadows=e.clipShadows),e.depthPacking!==void 0&&(this.depthPacking=e.depthPacking),e.blendSrc!==void 0&&(this.blendSrc=e.blendSrc),e.blendDst!==void 0&&(this.blendDst=e.blendDst),e.blendEquation!==void 0&&(this.blendEquation=e.blendEquation),e.blendSrcAlpha!==void 0&&(this.blendSrcAlpha=e.blendSrcAlpha),e.blendDstAlpha!==void 0&&(this.blendDstAlpha=e.blendDstAlpha),e.blendEquationAlpha!==void 0&&(this.blendEquationAlpha=e.blendEquationAlpha),e.blendColor!==void 0&&this.blendColor!==void 0&&this.blendColor.setHex(e.blendColor),e.blendAlpha!==void 0&&(this.blendAlpha=e.blendAlpha),e.stencilWriteMask!==void 0&&(this.stencilWriteMask=e.stencilWriteMask),e.stencilFunc!==void 0&&(this.stencilFunc=e.stencilFunc),e.stencilRef!==void 0&&(this.stencilRef=e.stencilRef),e.stencilFuncMask!==void 0&&(this.stencilFuncMask=e.stencilFuncMask),e.stencilFail!==void 0&&(this.stencilFail=e.stencilFail),e.stencilZFail!==void 0&&(this.stencilZFail=e.stencilZFail),e.stencilZPass!==void 0&&(this.stencilZPass=e.stencilZPass),e.stencilWrite!==void 0&&(this.stencilWrite=e.stencilWrite),e.wireframe!==void 0&&(this.wireframe=e.wireframe),e.wireframeLinewidth!==void 0&&(this.wireframeLinewidth=e.wireframeLinewidth),e.wireframeLinecap!==void 0&&(this.wireframeLinecap=e.wireframeLinecap),e.wireframeLinejoin!==void 0&&(this.wireframeLinejoin=e.wireframeLinejoin),e.rotation!==void 0&&(this.rotation=e.rotation),e.linewidth!==void 0&&(this.linewidth=e.linewidth),e.linecap!==void 0&&(this.linecap=e.linecap),e.linejoin!==void 0&&(this.linejoin=e.linejoin),e.dashSize!==void 0&&(this.dashSize=e.dashSize),e.gapSize!==void 0&&(this.gapSize=e.gapSize),e.scale!==void 0&&(this.scale=e.scale),e.polygonOffset!==void 0&&(this.polygonOffset=e.polygonOffset),e.polygonOffsetFactor!==void 0&&(this.polygonOffsetFactor=e.polygonOffsetFactor),e.polygonOffsetUnits!==void 0&&(this.polygonOffsetUnits=e.polygonOffsetUnits),e.dithering!==void 0&&(this.dithering=e.dithering),e.alphaToCoverage!==void 0&&(this.alphaToCoverage=e.alphaToCoverage),e.premultipliedAlpha!==void 0&&(this.premultipliedAlpha=e.premultipliedAlpha),e.forceSinglePass!==void 0&&(this.forceSinglePass=e.forceSinglePass),e.allowOverride!==void 0&&(this.allowOverride=e.allowOverride),e.visible!==void 0&&(this.visible=e.visible),e.toneMapped!==void 0&&(this.toneMapped=e.toneMapped),e.userData!==void 0&&(this.userData=e.userData),e.vertexColors!==void 0&&(typeof e.vertexColors=="number"?this.vertexColors=e.vertexColors>0:this.vertexColors=e.vertexColors),e.size!==void 0&&(this.size=e.size),e.sizeAttenuation!==void 0&&(this.sizeAttenuation=e.sizeAttenuation),e.map!==void 0&&(this.map=t[e.map]||null),e.matcap!==void 0&&(this.matcap=t[e.matcap]||null),e.alphaMap!==void 0&&(this.alphaMap=t[e.alphaMap]||null),e.bumpMap!==void 0&&(this.bumpMap=t[e.bumpMap]||null),e.bumpScale!==void 0&&(this.bumpScale=e.bumpScale),e.normalMap!==void 0&&(this.normalMap=t[e.normalMap]||null),e.normalMapType!==void 0&&(this.normalMapType=e.normalMapType),e.normalScale!==void 0){let n=e.normalScale;Array.isArray(n)===!1&&(n=[n,n]),this.normalScale=new ue().fromArray(n)}return e.displacementMap!==void 0&&(this.displacementMap=t[e.displacementMap]||null),e.displacementScale!==void 0&&(this.displacementScale=e.displacementScale),e.displacementBias!==void 0&&(this.displacementBias=e.displacementBias),e.roughnessMap!==void 0&&(this.roughnessMap=t[e.roughnessMap]||null),e.metalnessMap!==void 0&&(this.metalnessMap=t[e.metalnessMap]||null),e.emissiveMap!==void 0&&(this.emissiveMap=t[e.emissiveMap]||null),e.emissiveIntensity!==void 0&&(this.emissiveIntensity=e.emissiveIntensity),e.specularMap!==void 0&&(this.specularMap=t[e.specularMap]||null),e.specularIntensityMap!==void 0&&(this.specularIntensityMap=t[e.specularIntensityMap]||null),e.specularColorMap!==void 0&&(this.specularColorMap=t[e.specularColorMap]||null),e.envMap!==void 0&&(this.envMap=t[e.envMap]||null),e.envMapRotation!==void 0&&this.envMapRotation.fromArray(e.envMapRotation),e.envMapIntensity!==void 0&&(this.envMapIntensity=e.envMapIntensity),e.reflectivity!==void 0&&(this.reflectivity=e.reflectivity),e.refractionRatio!==void 0&&(this.refractionRatio=e.refractionRatio),e.lightMap!==void 0&&(this.lightMap=t[e.lightMap]||null),e.lightMapIntensity!==void 0&&(this.lightMapIntensity=e.lightMapIntensity),e.aoMap!==void 0&&(this.aoMap=t[e.aoMap]||null),e.aoMapIntensity!==void 0&&(this.aoMapIntensity=e.aoMapIntensity),e.gradientMap!==void 0&&(this.gradientMap=t[e.gradientMap]||null),e.clearcoatMap!==void 0&&(this.clearcoatMap=t[e.clearcoatMap]||null),e.clearcoatRoughnessMap!==void 0&&(this.clearcoatRoughnessMap=t[e.clearcoatRoughnessMap]||null),e.clearcoatNormalMap!==void 0&&(this.clearcoatNormalMap=t[e.clearcoatNormalMap]||null),e.clearcoatNormalScale!==void 0&&(this.clearcoatNormalScale=new ue().fromArray(e.clearcoatNormalScale)),e.iridescenceMap!==void 0&&(this.iridescenceMap=t[e.iridescenceMap]||null),e.iridescenceThicknessMap!==void 0&&(this.iridescenceThicknessMap=t[e.iridescenceThicknessMap]||null),e.transmissionMap!==void 0&&(this.transmissionMap=t[e.transmissionMap]||null),e.thicknessMap!==void 0&&(this.thicknessMap=t[e.thicknessMap]||null),e.anisotropyMap!==void 0&&(this.anisotropyMap=t[e.anisotropyMap]||null),e.sheenColorMap!==void 0&&(this.sheenColorMap=t[e.sheenColorMap]||null),e.sheenRoughnessMap!==void 0&&(this.sheenRoughnessMap=t[e.sheenRoughnessMap]||null),this}clone(){return new this.constructor().copy(this)}copy(e){this.name=e.name,this.blending=e.blending,this.side=e.side,this.vertexColors=e.vertexColors,this.opacity=e.opacity,this.transparent=e.transparent,this.blendSrc=e.blendSrc,this.blendDst=e.blendDst,this.blendEquation=e.blendEquation,this.blendSrcAlpha=e.blendSrcAlpha,this.blendDstAlpha=e.blendDstAlpha,this.blendEquationAlpha=e.blendEquationAlpha,this.blendColor.copy(e.blendColor),this.blendAlpha=e.blendAlpha,this.depthFunc=e.depthFunc,this.depthTest=e.depthTest,this.depthWrite=e.depthWrite,this.stencilWriteMask=e.stencilWriteMask,this.stencilFunc=e.stencilFunc,this.stencilRef=e.stencilRef,this.stencilFuncMask=e.stencilFuncMask,this.stencilFail=e.stencilFail,this.stencilZFail=e.stencilZFail,this.stencilZPass=e.stencilZPass,this.stencilWrite=e.stencilWrite;let t=e.clippingPlanes,n=null;if(t!==null){let s=t.length;n=new Array(s);for(let r=0;r!==s;++r)n[r]=t[r].clone()}return this.clippingPlanes=n,this.clipIntersection=e.clipIntersection,this.clipShadows=e.clipShadows,this.shadowSide=e.shadowSide,this.colorWrite=e.colorWrite,this.precision=e.precision,this.polygonOffset=e.polygonOffset,this.polygonOffsetFactor=e.polygonOffsetFactor,this.polygonOffsetUnits=e.polygonOffsetUnits,this.dithering=e.dithering,this.alphaTest=e.alphaTest,this.alphaHash=e.alphaHash,this.alphaToCoverage=e.alphaToCoverage,this.premultipliedAlpha=e.premultipliedAlpha,this.forceSinglePass=e.forceSinglePass,this.allowOverride=e.allowOverride,this.visible=e.visible,this.toneMapped=e.toneMapped,this.userData=JSON.parse(JSON.stringify(e.userData)),this}dispose(){this.dispatchEvent({type:"dispose"})}set needsUpdate(e){e===!0&&this.version++}},Ui=class extends Kn{constructor(e){super(),this.isSpriteMaterial=!0,this.type="SpriteMaterial",this.color=new it(16777215),this.map=null,this.alphaMap=null,this.rotation=0,this.sizeAttenuation=!0,this.transparent=!0,this.fog=!0,this.setValues(e)}copy(e){return super.copy(e),this.color.copy(e.color),this.map=e.map,this.alphaMap=e.alphaMap,this.rotation=e.rotation,this.sizeAttenuation=e.sizeAttenuation,this.fog=e.fog,this}},Hs,Or=new I,ks=new I,Vs=new I,Gs=new ue,Br=new ue,Uu=new Rt,fo=new I,zr=new I,po=new I,Eh=new ue,$c=new ue,Th=new ue,$i=class extends Qt{constructor(e=new Ui){if(super(),this.isSprite=!0,this.type="Sprite",Hs===void 0){Hs=new wt;let t=new Float32Array([-.5,-.5,0,0,0,.5,-.5,0,1,0,.5,.5,0,1,1,-.5,.5,0,0,1]),n=new ea(t,5);Hs.setIndex([0,1,2,0,2,3]),Hs.setAttribute("position",new ir(n,3,0,!1)),Hs.setAttribute("uv",new ir(n,2,3,!1))}this.geometry=Hs,this.material=e,this.center=new ue(.5,.5),this.count=1}intersectsFrustum(e){return e.intersectsSprite(this)}raycast(e,t){e.camera===null&&lt('Sprite: "Raycaster.camera" needs to be set in order to raycast against sprites.'),ks.setFromMatrixScale(this.matrixWorld),Uu.copy(e.camera.matrixWorld),this.modelViewMatrix.multiplyMatrices(e.camera.matrixWorldInverse,this.matrixWorld),Vs.setFromMatrixPosition(this.modelViewMatrix),e.camera.isPerspectiveCamera&&this.material.sizeAttenuation===!1&&ks.multiplyScalar(-Vs.z);let n=this.material.rotation,s,r;n!==0&&(r=Math.cos(n),s=Math.sin(n));let a=this.center;mo(fo.set(-.5,-.5,0),Vs,a,ks,s,r),mo(zr.set(.5,-.5,0),Vs,a,ks,s,r),mo(po.set(.5,.5,0),Vs,a,ks,s,r),Eh.set(0,0),$c.set(1,0),Th.set(1,1);let o=e.ray.intersectTriangle(fo,zr,po,!1,Or);if(o===null&&(mo(zr.set(-.5,.5,0),Vs,a,ks,s,r),$c.set(0,1),o=e.ray.intersectTriangle(fo,po,zr,!1,Or),o===null))return;let l=e.ray.origin.distanceTo(Or);l<e.near||l>e.far||t.push({distance:l,point:Or.clone(),uv:Ii.getInterpolation(Or,fo,zr,po,Eh,$c,Th,new ue),face:null,object:this})}copy(e,t){return super.copy(e,t),e.center!==void 0&&this.center.copy(e.center),this.material=e.material,this}};function mo(i,e,t,n,s,r){Gs.subVectors(i,t).addScalar(.5).multiply(n),s!==void 0?(Br.x=r*Gs.x-s*Gs.y,Br.y=s*Gs.x+r*Gs.y):Br.copy(Gs),i.copy(e),i.x+=Br.x,i.y+=Br.y,i.applyMatrix4(Uu)}var go=new I,wh=new I,ta=class extends Qt{constructor(){super(),this.isLOD=!0,this._currentLevel=0,this.type="LOD",Object.defineProperties(this,{levels:{enumerable:!0,value:[]}}),this.autoUpdate=!0}copy(e){super.copy(e,!1);let t=e.levels;for(let n=0,s=t.length;n<s;n++){let r=t[n];this.addLevel(r.object.clone(),r.distance,r.hysteresis)}return this.autoUpdate=e.autoUpdate,this}addLevel(e,t=0,n=0){t=Math.abs(t);let s=this.levels,r;for(r=0;r<s.length&&!(t<s[r].distance);r++);return s.splice(r,0,{distance:t,hysteresis:n,object:e}),this.add(e),this}removeLevel(e){let t=this.levels;for(let n=0;n<t.length;n++)if(t[n].distance===e){let s=t.splice(n,1);return this.remove(s[0].object),!0}return!1}getCurrentLevel(){return this._currentLevel}getObjectForDistance(e){let t=this.levels;if(t.length>0){let n,s;for(n=1,s=t.length;n<s;n++){let r=t[n].distance;if(t[n].object.visible&&(r-=r*t[n].hysteresis),e<r)break}return t[n-1].object}return null}raycast(e,t){if(this.levels.length>0){go.setFromMatrixPosition(this.matrixWorld);let s=e.ray.origin.distanceTo(go);this.getObjectForDistance(s).raycast(e,t)}}update(e){let t=this.levels;if(t.length>1){go.setFromMatrixPosition(e.matrixWorld),wh.setFromMatrixPosition(this.matrixWorld);let n=go.distanceTo(wh)/e.zoom;t[0].object.visible=!0;let s,r;for(s=1,r=t.length;s<r;s++){let a=t[s].distance;if(t[s].object.visible&&(a-=a*t[s].hysteresis),n>=a)t[s-1].object.visible=!1,t[s].object.visible=!0;else break}for(this._currentLevel=s-1;s<r;s++)t[s].object.visible=!1}}toJSON(e){let t=super.toJSON(e);t.object.autoUpdate=this.autoUpdate,t.object.levels=[];let n=this.levels;for(let s=0,r=n.length;s<r;s++){let a=n[s];t.object.levels.push({object:a.object.uuid,distance:a.distance,hysteresis:a.hysteresis})}return t}},Pi=new I,Zc=new I,_o=new I,xo=new I,xs=class{constructor(e=new I,t=new I(0,0,-1)){this.origin=e,this.direction=t}set(e,t){return this.origin.copy(e),this.direction.copy(t),this}copy(e){return this.origin.copy(e.origin),this.direction.copy(e.direction),this}at(e,t){return t.copy(this.origin).addScaledVector(this.direction,e)}lookAt(e){return this.direction.copy(e).sub(this.origin).normalize(),this}recast(e){return this.origin.copy(this.at(e,Pi)),this}closestPointToPoint(e,t){t.subVectors(e,this.origin);let n=t.dot(this.direction);return n<0?t.copy(this.origin):t.copy(this.origin).addScaledVector(this.direction,n)}distanceToPoint(e){return Math.sqrt(this.distanceSqToPoint(e))}distanceSqToPoint(e){let t=Pi.subVectors(e,this.origin).dot(this.direction);return t<0?this.origin.distanceToSquared(e):(Pi.copy(this.origin).addScaledVector(this.direction,t),Pi.distanceToSquared(e))}distanceSqToSegment(e,t,n,s){Zc.copy(e).add(t).multiplyScalar(.5),_o.copy(t).sub(e).normalize(),xo.copy(this.origin).sub(Zc);let r=e.distanceTo(t)*.5,a=-this.direction.dot(_o),o=xo.dot(this.direction),l=-xo.dot(_o),c=xo.lengthSq(),h=Math.abs(1-a*a),f,u,d,g;if(h>0)if(f=a*l-o,u=a*o-l,g=r*h,f>=0)if(u>=-g)if(u<=g){let x=1/h;f*=x,u*=x,d=f*(f+a*u+2*o)+u*(a*f+u+2*l)+c}else u=r,f=Math.max(0,-(a*u+o)),d=-f*f+u*(u+2*l)+c;else u=-r,f=Math.max(0,-(a*u+o)),d=-f*f+u*(u+2*l)+c;else u<=-g?(f=Math.max(0,-(-a*r+o)),u=f>0?-r:Math.min(Math.max(-r,-l),r),d=-f*f+u*(u+2*l)+c):u<=g?(f=0,u=Math.min(Math.max(-r,-l),r),d=u*(u+2*l)+c):(f=Math.max(0,-(a*r+o)),u=f>0?r:Math.min(Math.max(-r,-l),r),d=-f*f+u*(u+2*l)+c);else u=a>0?-r:r,f=Math.max(0,-(a*u+o)),d=-f*f+u*(u+2*l)+c;return n&&n.copy(this.origin).addScaledVector(this.direction,f),s&&s.copy(Zc).addScaledVector(_o,u),d}intersectSphere(e,t){if(e.radius<0)return null;Pi.subVectors(e.center,this.origin);let n=Pi.dot(this.direction),s=Pi.dot(Pi)-n*n,r=e.radius*e.radius;if(s>r)return null;let a=Math.sqrt(r-s),o=n-a,l=n+a;return l<0?null:o<0?this.at(l,t):this.at(o,t)}intersectsSphere(e){return e.radius<0?!1:this.distanceSqToPoint(e.center)<=e.radius*e.radius}distanceToPlane(e){let t=e.normal.dot(this.direction);if(t===0)return e.distanceToPoint(this.origin)===0?0:null;let n=-(this.origin.dot(e.normal)+e.constant)/t;return n>=0?n:null}intersectPlane(e,t){let n=this.distanceToPlane(e);return n===null?null:this.at(n,t)}intersectsPlane(e){let t=e.distanceToPoint(this.origin);return t===0||e.normal.dot(this.direction)*t<0}intersectBox(e,t){let n,s,r,a,o,l,c=1/this.direction.x,h=1/this.direction.y,f=1/this.direction.z,u=this.origin;return c>=0?(n=(e.min.x-u.x)*c,s=(e.max.x-u.x)*c):(n=(e.max.x-u.x)*c,s=(e.min.x-u.x)*c),h>=0?(r=(e.min.y-u.y)*h,a=(e.max.y-u.y)*h):(r=(e.max.y-u.y)*h,a=(e.min.y-u.y)*h),n>a||r>s||((r>n||isNaN(n))&&(n=r),(a<s||isNaN(s))&&(s=a),f>=0?(o=(e.min.z-u.z)*f,l=(e.max.z-u.z)*f):(o=(e.max.z-u.z)*f,l=(e.min.z-u.z)*f),n>l||o>s)||((o>n||n!==n)&&(n=o),(l<s||s!==s)&&(s=l),s<0)?null:this.at(n>=0?n:s,t)}intersectsBox(e){return this.intersectBox(e,Pi)!==null}intersectTriangle(e,t,n,s,r){let a=this.origin,o=this.direction,l=o.x,c=o.y,h=o.z,f=e.x-a.x,u=e.y-a.y,d=e.z-a.z,g=t.x-a.x,x=t.y-a.y,m=t.z-a.z,p=n.x-a.x,S=n.y-a.y,A=n.z-a.z,v=Math.abs(l),b=Math.abs(c),E=Math.abs(h),C,y,w,P,U,B,W,F,V,se,K,de;if(v>=b&&v>=E?(w=l,B=f,V=g,de=p,l>=0?(C=c,y=h,P=u,U=d,W=x,F=m,se=S,K=A):(C=h,y=c,P=d,U=u,W=m,F=x,se=A,K=S)):b>=E?(w=c,B=u,V=x,de=S,c>=0?(C=h,y=l,P=d,U=f,W=m,F=g,se=A,K=p):(C=l,y=h,P=f,U=d,W=g,F=m,se=p,K=A)):(w=h,B=d,V=m,de=A,h>=0?(C=l,y=c,P=f,U=u,W=g,F=x,se=p,K=S):(C=c,y=l,P=u,U=f,W=x,F=g,se=S,K=p)),w===0)return null;let te=C/w,ae=y/w,O=1/w,ye=P-te*B,Se=U-ae*B,be=W-te*V,Ve=F-ae*V,me=se-te*de,$=K-ae*de,X=me*Ve-$*be,he=ye*$-Se*me,Te=be*Se-Ve*ye;if(s){if(X<0||he<0||Te<0)return null}else if((X<0||he<0||Te<0)&&(X>0||he>0||Te>0))return null;let le=X+he+Te;if(le===0)return null;let Ie=O*(X*B+he*V+Te*de);return(le>0?Ie<0:Ie>0)?null:this.at(Ie/le,r)}applyMatrix4(e){return this.origin.applyMatrix4(e),this.direction.transformDirection(e),this}equals(e){return e.origin.equals(this.origin)&&e.direction.equals(this.direction)}clone(){return new this.constructor().copy(this)}},en=class extends Kn{constructor(e){super(),this.isMeshBasicMaterial=!0,this.type="MeshBasicMaterial",this.color=new it(16777215),this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.specularMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new Ni,this.combine=M0,this.reflectivity=1,this.refractionRatio=.98,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.fog=!0,this.setValues(e)}copy(e){return super.copy(e),this.color.copy(e.color),this.map=e.map,this.lightMap=e.lightMap,this.lightMapIntensity=e.lightMapIntensity,this.aoMap=e.aoMap,this.aoMapIntensity=e.aoMapIntensity,this.specularMap=e.specularMap,this.alphaMap=e.alphaMap,this.envMap=e.envMap,this.envMapRotation.copy(e.envMapRotation),this.combine=e.combine,this.reflectivity=e.reflectivity,this.refractionRatio=e.refractionRatio,this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this.wireframeLinecap=e.wireframeLinecap,this.wireframeLinejoin=e.wireframeLinejoin,this.fog=e.fog,this}},Ah=new Rt,ms=new xs,vo=new _i,Rh=new I,yo=new I,Mo=new I,So=new I,Jc=new I,bo=new I,Ch=new I,Eo=new I,gt=class extends Qt{constructor(e=new wt,t=new en){super(),this.isMesh=!0,this.type="Mesh",this.geometry=e,this.material=t,this.morphTargetDictionary=void 0,this.morphTargetInfluences=void 0,this.count=1,this.updateMorphTargets()}copy(e,t){return super.copy(e,t),e.morphTargetInfluences!==void 0&&(this.morphTargetInfluences=e.morphTargetInfluences.slice()),e.morphTargetDictionary!==void 0&&(this.morphTargetDictionary=Object.assign({},e.morphTargetDictionary)),this.material=Array.isArray(e.material)?e.material.slice():e.material,this.geometry=e.geometry,this}updateMorphTargets(){let t=this.geometry.morphAttributes,n=Object.keys(t);if(n.length>0){let s=t[n[0]];if(s!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let r=0,a=s.length;r<a;r++){let o=s[r].name||String(r);this.morphTargetInfluences.push(0),this.morphTargetDictionary[o]=r}}}}getVertexPosition(e,t){let n=this.geometry,s=n.attributes.position,r=n.morphAttributes.position,a=n.morphTargetsRelative;t.fromBufferAttribute(s,e);let o=this.morphTargetInfluences;if(r&&o){bo.set(0,0,0);for(let l=0,c=r.length;l<c;l++){let h=o[l],f=r[l];h!==0&&(Jc.fromBufferAttribute(f,e),a?bo.addScaledVector(Jc,h):bo.addScaledVector(Jc.sub(t),h))}t.add(bo)}return t}intersectsFrustum(e){return e.intersectsObject(this)}raycast(e,t){let n=this.geometry,s=this.material,r=this.matrixWorld;s!==void 0&&(n.boundingSphere===null&&n.computeBoundingSphere(),vo.copy(n.boundingSphere),vo.applyMatrix4(r),ms.copy(e.ray).recast(e.near),!(vo.containsPoint(ms.origin)===!1&&(ms.intersectSphere(vo,Rh)===null||ms.origin.distanceToSquared(Rh)>(e.far-e.near)**2))&&(Ah.copy(r).invert(),ms.copy(e.ray).applyMatrix4(Ah),!(n.boundingBox!==null&&ms.intersectsBox(n.boundingBox)===!1)&&this._computeIntersections(e,t,ms)))}_computeIntersections(e,t,n){let s,r=this.geometry,a=this.material,o=r.index,l=r.attributes.position,c=r.attributes.uv,h=r.attributes.uv1,f=r.attributes.normal,u=r.groups,d=r.drawRange;if(o!==null)if(Array.isArray(a))for(let g=0,x=u.length;g<x;g++){let m=u[g],p=a[m.materialIndex],S=Math.max(m.start,d.start),A=Math.min(o.count,Math.min(m.start+m.count,d.start+d.count));for(let v=S,b=A;v<b;v+=3){let E=o.getX(v),C=o.getX(v+1),y=o.getX(v+2);s=To(this,p,e,n,c,h,f,E,C,y),s&&(s.faceIndex=Math.floor(v/3),s.face.materialIndex=m.materialIndex,t.push(s))}}else{let g=Math.max(0,d.start),x=Math.min(o.count,d.start+d.count);for(let m=g,p=x;m<p;m+=3){let S=o.getX(m),A=o.getX(m+1),v=o.getX(m+2);s=To(this,a,e,n,c,h,f,S,A,v),s&&(s.faceIndex=Math.floor(m/3),t.push(s))}}else if(l!==void 0)if(Array.isArray(a))for(let g=0,x=u.length;g<x;g++){let m=u[g],p=a[m.materialIndex],S=Math.max(m.start,d.start),A=Math.min(l.count,Math.min(m.start+m.count,d.start+d.count));for(let v=S,b=A;v<b;v+=3){let E=v,C=v+1,y=v+2;s=To(this,p,e,n,c,h,f,E,C,y),s&&(s.faceIndex=Math.floor(v/3),s.face.materialIndex=m.materialIndex,t.push(s))}}else{let g=Math.max(0,d.start),x=Math.min(l.count,d.start+d.count);for(let m=g,p=x;m<p;m+=3){let S=m,A=m+1,v=m+2;s=To(this,a,e,n,c,h,f,S,A,v),s&&(s.faceIndex=Math.floor(m/3),t.push(s))}}}};function sd(i,e,t,n,s,r,a,o){let l;if(e.side===_n?l=n.intersectTriangle(a,r,s,!0,o):l=n.intersectTriangle(s,r,a,e.side===ts,o),l===null)return null;Eo.copy(o),Eo.applyMatrix4(i.matrixWorld);let c=t.ray.origin.distanceTo(Eo);return c<t.near||c>t.far?null:{distance:c,point:Eo.clone(),object:i}}function To(i,e,t,n,s,r,a,o,l,c){i.getVertexPosition(o,yo),i.getVertexPosition(l,Mo),i.getVertexPosition(c,So);let h=sd(i,e,t,n,yo,Mo,So,Ch);if(h){let f=new I;Ii.getBarycoord(Ch,yo,Mo,So,f),s&&(h.uv=Ii.getInterpolatedAttribute(s,o,l,c,f,new ue)),r&&(h.uv1=Ii.getInterpolatedAttribute(r,o,l,c,f,new ue)),a&&(h.normal=Ii.getInterpolatedAttribute(a,o,l,c,f,new I),h.normal.dot(n.direction)>0&&h.normal.multiplyScalar(-1));let u={a:o,b:l,c,normal:new I,materialIndex:0};Ii.getNormal(yo,Mo,So,u.normal),h.face=u,h.barycoord=f}return h}var na=class extends fn{constructor(e=null,t=1,n=1,s,r,a,o,l,c=un,h=un,f,u){super(null,a,o,l,c,h,s,r,f,u),this.isDataTexture=!0,this.image={data:e,width:t,height:n},this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}};var sr=class extends jt{constructor(e,t,n,s=1){super(e,t,n),this.isInstancedBufferAttribute=!0,this.meshPerAttribute=s}copy(e){return super.copy(e),this.meshPerAttribute=e.meshPerAttribute,this}toJSON(){let e=super.toJSON();return e.meshPerAttribute=this.meshPerAttribute,e.isInstancedBufferAttribute=!0,e}},Ws=new Rt,Ph=new Rt,wo=[],Ih=new gi,rd=new Rt,Hr=new gt,kr=new _i,ia=class extends gt{constructor(e,t,n){super(e,t),this.isInstancedMesh=!0,this.instanceMatrix=new sr(new Float32Array(n*16),16),this.instanceColor=null,this.morphTexture=null,this.count=n,this.boundingBox=null,this.boundingSphere=null;for(let s=0;s<n;s++)this.setMatrixAt(s,rd)}computeBoundingBox(){let e=this.geometry,t=this.count;this.boundingBox===null&&(this.boundingBox=new gi),e.boundingBox===null&&e.computeBoundingBox(),this.boundingBox.makeEmpty();for(let n=0;n<t;n++)this.getMatrixAt(n,Ws),Ih.copy(e.boundingBox).applyMatrix4(Ws),this.boundingBox.union(Ih)}computeBoundingSphere(){let e=this.geometry,t=this.count;this.boundingSphere===null&&(this.boundingSphere=new _i),e.boundingSphere===null&&e.computeBoundingSphere(),this.boundingSphere.makeEmpty();for(let n=0;n<t;n++)this.getMatrixAt(n,Ws),kr.copy(e.boundingSphere).applyMatrix4(Ws),this.boundingSphere.union(kr)}copy(e,t){return super.copy(e,t),this.instanceMatrix.copy(e.instanceMatrix),e.morphTexture!==null&&(this.morphTexture=e.morphTexture.clone()),e.instanceColor!==null&&(this.instanceColor=e.instanceColor.clone()),this.count=e.count,e.boundingBox!==null&&(this.boundingBox=e.boundingBox.clone()),e.boundingSphere!==null&&(this.boundingSphere=e.boundingSphere.clone()),this}getColorAt(e,t){return this.instanceColor===null?t.setRGB(1,1,1):t.fromArray(this.instanceColor.array,e*3)}getMatrixAt(e,t){return t.fromArray(this.instanceMatrix.array,e*16)}getMorphAt(e,t){let n=t.morphTargetInfluences,s=this.morphTexture.source.data.data,r=n.length+1,a=e*r+1;for(let o=0;o<n.length;o++)n[o]=s[a+o]}raycast(e,t){let n=this.matrixWorld,s=this.count;if(Hr.geometry=this.geometry,Hr.material=this.material,Hr.material!==void 0&&(this.boundingSphere===null&&this.computeBoundingSphere(),kr.copy(this.boundingSphere),kr.applyMatrix4(n),e.ray.intersectsSphere(kr)!==!1))for(let r=0;r<s;r++){this.getMatrixAt(r,Ws),Ph.multiplyMatrices(n,Ws),Hr.matrixWorld=Ph,Hr.raycast(e,wo);for(let a=0,o=wo.length;a<o;a++){let l=wo[a];l.instanceId=r,l.object=this,t.push(l)}wo.length=0}}setColorAt(e,t){return this.instanceColor===null&&(this.instanceColor=new sr(new Float32Array(this.instanceMatrix.count*3).fill(1),3)),t.toArray(this.instanceColor.array,e*3),this}setMatrixAt(e,t){return t.toArray(this.instanceMatrix.array,e*16),this}setMorphAt(e,t){let n=t.morphTargetInfluences,s=n.length+1;this.morphTexture===null&&(this.morphTexture=new na(new Float32Array(s*this.count),s,this.count,Tl,kn));let r=this.morphTexture.source.data.data,a=0;for(let c=0;c<n.length;c++)a+=n[c];let o=this.geometry.morphTargetsRelative?1:1-a,l=s*e;return r[l]=o,r.set(n,l+1),this}updateMorphTargets(){}dispose(){super.dispose(),this.morphTexture!==null&&(this.morphTexture.dispose(),this.morphTexture=null)}},gs=new _i,ad=new ue(.5,.5),Ao=new I,rr=class{constructor(e=new Zn,t=new Zn,n=new Zn,s=new Zn,r=new Zn,a=new Zn){this.planes=[e,t,n,s,r,a]}set(e,t,n,s,r,a){let o=this.planes;return o[0].copy(e),o[1].copy(t),o[2].copy(n),o[3].copy(s),o[4].copy(r),o[5].copy(a),this}copy(e){let t=this.planes;for(let n=0;n<6;n++)t[n].copy(e.planes[n]);return this}setFromProjectionMatrix(e,t=Jn,n=!1){let s=this.planes,r=e.elements,a=r[0],o=r[1],l=r[2],c=r[3],h=r[4],f=r[5],u=r[6],d=r[7],g=r[8],x=r[9],m=r[10],p=r[11],S=r[12],A=r[13],v=r[14],b=r[15];if(s[0].setComponents(c-a,d-h,p-g,b-S).normalize(),s[1].setComponents(c+a,d+h,p+g,b+S).normalize(),s[2].setComponents(c+o,d+f,p+x,b+A).normalize(),s[3].setComponents(c-o,d-f,p-x,b-A).normalize(),n)s[4].setComponents(l,u,m,v).normalize(),s[5].setComponents(c-l,d-u,p-m,b-v).normalize();else if(s[4].setComponents(c-l,d-u,p-m,b-v).normalize(),t===Jn)s[5].setComponents(c+l,d+u,p+m,b+v).normalize();else if(t===Ks)s[5].setComponents(l,u,m,v).normalize();else throw new Error("THREE.Frustum.setFromProjectionMatrix(): Invalid coordinate system: "+t);return this}intersectsObject(e){if(e.boundingSphere!==void 0)e.boundingSphere===null&&e.computeBoundingSphere(),gs.copy(e.boundingSphere).applyMatrix4(e.matrixWorld);else{let t=e.geometry;t.boundingSphere===null&&t.computeBoundingSphere(),gs.copy(t.boundingSphere).applyMatrix4(e.matrixWorld)}return this.intersectsSphere(gs)}intersectsSprite(e){gs.center.set(0,0,0);let t=ad.distanceTo(e.center);return gs.radius=.7071067811865476+t,gs.applyMatrix4(e.matrixWorld),this.intersectsSphere(gs)}intersectsSphere(e){let t=this.planes,n=e.center,s=-e.radius;for(let r=0;r<6;r++)if(t[r].distanceToPoint(n)<s)return!1;return!0}intersectsBox(e){let t=this.planes;for(let n=0;n<6;n++){let s=t[n];if(Ao.x=s.normal.x>0?e.max.x:e.min.x,Ao.y=s.normal.y>0?e.max.y:e.min.y,Ao.z=s.normal.z>0?e.max.z:e.min.z,s.distanceToPoint(Ao)<0)return!1}return!0}containsPoint(e){let t=this.planes;for(let n=0;n<6;n++)if(t[n].distanceToPoint(e)<0)return!1;return!0}clone(){return new this.constructor().copy(this)}};var jn=class extends Kn{constructor(e){super(),this.isLineBasicMaterial=!0,this.type="LineBasicMaterial",this.color=new it(16777215),this.map=null,this.linewidth=1,this.linecap="round",this.linejoin="round",this.fog=!0,this.setValues(e)}copy(e){return super.copy(e),this.color.copy(e.color),this.map=e.map,this.linewidth=e.linewidth,this.linecap=e.linecap,this.linejoin=e.linejoin,this.fog=e.fog,this}},jo=new I,Qo=new I,Lh=new Rt,Vr=new xs,Ro=new _i,Kc=new I,Dh=new I,Fi=class extends Qt{constructor(e=new wt,t=new jn){super(),this.isLine=!0,this.type="Line",this.geometry=e,this.material=t,this.morphTargetDictionary=void 0,this.morphTargetInfluences=void 0,this.updateMorphTargets()}copy(e,t){return super.copy(e,t),this.material=Array.isArray(e.material)?e.material.slice():e.material,this.geometry=e.geometry,this}computeLineDistances(){let e=this.geometry;if(e.index===null){let t=e.attributes.position,n=[0];for(let s=1,r=t.count;s<r;s++)jo.fromBufferAttribute(t,s-1),Qo.fromBufferAttribute(t,s),n[s]=n[s-1],n[s]+=jo.distanceTo(Qo);e.setAttribute("lineDistance",new ft(n,1))}else ct("Line.computeLineDistances(): Computation only possible with non-indexed BufferGeometry.");return this}intersectsFrustum(e){return e.intersectsObject(this)}raycast(e,t){let n=this.geometry,s=this.matrixWorld,r=e.params.Line.threshold,a=n.drawRange;if(n.boundingSphere===null&&n.computeBoundingSphere(),Ro.copy(n.boundingSphere),Ro.applyMatrix4(s),Ro.radius+=r,e.ray.intersectsSphere(Ro)===!1)return;Lh.copy(s).invert(),Vr.copy(e.ray).applyMatrix4(Lh);let o=r/((this.scale.x+this.scale.y+this.scale.z)/3),l=o*o,c=this.isLineSegments?2:1,h=n.index,u=n.attributes.position;if(h!==null){let d=Math.max(0,a.start),g=Math.min(h.count,a.start+a.count);for(let x=d,m=g-1;x<m;x+=c){let p=h.getX(x),S=h.getX(x+1),A=Co(this,e,Vr,l,p,S,x);A&&t.push(A)}if(this.isLineLoop){let x=h.getX(g-1),m=h.getX(d),p=Co(this,e,Vr,l,x,m,g-1);p&&t.push(p)}}else{let d=Math.max(0,a.start),g=Math.min(u.count,a.start+a.count);for(let x=d,m=g-1;x<m;x+=c){let p=Co(this,e,Vr,l,x,x+1,x);p&&t.push(p)}if(this.isLineLoop){let x=Co(this,e,Vr,l,g-1,d,g-1);x&&t.push(x)}}}updateMorphTargets(){let t=this.geometry.morphAttributes,n=Object.keys(t);if(n.length>0){let s=t[n[0]];if(s!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let r=0,a=s.length;r<a;r++){let o=s[r].name||String(r);this.morphTargetInfluences.push(0),this.morphTargetDictionary[o]=r}}}}};function Co(i,e,t,n,s,r,a){let o=i.geometry.attributes.position;if(jo.fromBufferAttribute(o,s),Qo.fromBufferAttribute(o,r),t.distanceSqToSegment(jo,Qo,Kc,Dh)>n)return;Kc.applyMatrix4(i.matrixWorld);let c=e.ray.origin.distanceTo(Kc);if(!(c<e.near||c>e.far))return{distance:c,point:Dh.clone().applyMatrix4(i.matrixWorld),index:a,face:null,faceIndex:null,barycoord:null,object:i}}var el=class extends Kn{constructor(e){super(),this.isPointsMaterial=!0,this.type="PointsMaterial",this.color=new it(16777215),this.map=null,this.alphaMap=null,this.size=1,this.sizeAttenuation=!0,this.fog=!0,this.setValues(e)}copy(e){return super.copy(e),this.color.copy(e.color),this.map=e.map,this.alphaMap=e.alphaMap,this.size=e.size,this.sizeAttenuation=e.sizeAttenuation,this.fog=e.fog,this}},Nh=new Rt,o0=new xs,Po=new _i,Io=new I,sa=class extends Qt{constructor(e=new wt,t=new el){super(),this.isPoints=!0,this.type="Points",this.geometry=e,this.material=t,this.morphTargetDictionary=void 0,this.morphTargetInfluences=void 0,this.updateMorphTargets()}copy(e,t){return super.copy(e,t),this.material=Array.isArray(e.material)?e.material.slice():e.material,this.geometry=e.geometry,this}intersectsFrustum(e){return e.intersectsObject(this)}raycast(e,t){let n=this.geometry,s=this.matrixWorld,r=e.params.Points.threshold,a=n.drawRange;if(n.boundingSphere===null&&n.computeBoundingSphere(),Po.copy(n.boundingSphere),Po.applyMatrix4(s),Po.radius+=r,e.ray.intersectsSphere(Po)===!1)return;Nh.copy(s).invert(),o0.copy(e.ray).applyMatrix4(Nh);let o=r/((this.scale.x+this.scale.y+this.scale.z)/3),l=o*o,c=n.index,f=n.attributes.position;if(c!==null){let u=Math.max(0,a.start),d=Math.min(c.count,a.start+a.count);for(let g=u,x=d;g<x;g++){let m=c.getX(g);Io.fromBufferAttribute(f,m),Uh(Io,m,l,s,e,t,this)}}else{let u=Math.max(0,a.start),d=Math.min(f.count,a.start+a.count);for(let g=u,x=d;g<x;g++)Io.fromBufferAttribute(f,g),Uh(Io,g,l,s,e,t,this)}}updateMorphTargets(){let t=this.geometry.morphAttributes,n=Object.keys(t);if(n.length>0){let s=t[n[0]];if(s!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let r=0,a=s.length;r<a;r++){let o=s[r].name||String(r);this.morphTargetInfluences.push(0),this.morphTargetDictionary[o]=r}}}}};function Uh(i,e,t,n,s,r,a){let o=o0.distanceSqToPoint(i);if(o<t){let l=new I;o0.closestPointToPoint(i,l),l.applyMatrix4(n);let c=s.ray.origin.distanceTo(l);if(c<s.near||c>s.far)return;r.push({distance:c,distanceToRay:Math.sqrt(o),point:l,index:e,face:null,faceIndex:null,barycoord:null,object:a})}}var ra=class extends fn{constructor(e=[],t=is,n,s,r,a,o,l,c,h){super(e,t,n,s,r,a,o,l,c,h),this.isCubeTexture=!0,this.flipY=!1}get images(){return this.image}set images(e){this.image=e}},Bn=class extends fn{constructor(e,t,n,s,r,a,o,l,c){super(e,t,n,s,r,a,o,l,c),this.isCanvasTexture=!0,this.needsUpdate=!0}};var Zi=class extends fn{constructor(e,t,n=ei,s,r,a,o=un,l=un,c,h=di,f=1){if(h!==di&&h!==ss)throw new Error("THREE.DepthTexture: format must be either THREE.DepthFormat or THREE.DepthStencilFormat");let u={width:e,height:t,depth:f};super(u,s,r,a,o,l,h,n,c),this.isDepthTexture=!0,this.flipY=!1,this.generateMipmaps=!1,this.compareFunction=null}copy(e){return super.copy(e),this.source=new er(Object.assign({},e.image)),this.compareFunction=e.compareFunction,this}toJSON(e){let t=super.toJSON(e);return t.compareFunction=this.compareFunction,t}},tl=class extends Zi{constructor(e,t=ei,n=is,s,r,a=un,o=un,l,c=di){let h={width:e,height:e,depth:1},f=[h,h,h,h,h,h];super(e,e,t,n,s,r,a,o,l,c),this.image=f,this.isCubeDepthTexture=!0,this.isCubeTexture=!0}get images(){return this.image}set images(e){this.image=e}},aa=class extends fn{constructor(e=null){super(),this.sourceTexture=e,this.isExternalTexture=!0}copy(e){return super.copy(e),this.sourceTexture=e.sourceTexture,this}},ar=class i extends wt{constructor(e=1,t=1,n=1,s=1,r=1,a=1){super(),this.type="BoxGeometry",this.parameters={width:e,height:t,depth:n,widthSegments:s,heightSegments:r,depthSegments:a};let o=this;s=Math.floor(s),r=Math.floor(r),a=Math.floor(a);let l=[],c=[],h=[],f=[],u=0,d=0;g("z","y","x",-1,-1,n,t,e,a,r,0),g("z","y","x",1,-1,n,t,-e,a,r,1),g("x","z","y",1,1,e,n,t,s,a,2),g("x","z","y",1,-1,e,n,-t,s,a,3),g("x","y","z",1,-1,e,t,n,s,r,4),g("x","y","z",-1,-1,e,t,-n,s,r,5),this.setIndex(l),this.setAttribute("position",new ft(c,3)),this.setAttribute("normal",new ft(h,3)),this.setAttribute("uv",new ft(f,2));function g(x,m,p,S,A,v,b,E,C,y,w){let P=v/C,U=b/y,B=v/2,W=b/2,F=E/2,V=C+1,se=y+1,K=0,de=0,te=new I;for(let ae=0;ae<se;ae++){let O=ae*U-W;for(let ye=0;ye<V;ye++){let Se=ye*P-B;te[x]=Se*S,te[m]=O*A,te[p]=F,c.push(te.x,te.y,te.z),te[x]=0,te[m]=0,te[p]=E>0?1:-1,h.push(te.x,te.y,te.z),f.push(ye/C),f.push(1-ae/y),K+=1}}for(let ae=0;ae<y;ae++)for(let O=0;O<C;O++){let ye=u+O+V*ae,Se=u+O+V*(ae+1),be=u+(O+1)+V*(ae+1),Ve=u+(O+1)+V*ae;l.push(ye,Se,Ve),l.push(Se,be,Ve),de+=6}o.addGroup(d,de,w),d+=de,u+=K}}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new i(e.width,e.height,e.depth,e.widthSegments,e.heightSegments,e.depthSegments)}};var oa=class i extends wt{constructor(e=1,t=32,n=0,s=Math.PI*2){super(),this.type="CircleGeometry",this.parameters={radius:e,segments:t,thetaStart:n,thetaLength:s},t=Math.max(3,t);let r=[],a=[],o=[],l=[],c=new I,h=new ue;a.push(0,0,0),o.push(0,0,1),l.push(.5,.5);for(let f=0,u=3;f<=t;f++,u+=3){let d=n+f/t*s;c.x=e*Math.cos(d),c.y=e*Math.sin(d),a.push(c.x,c.y,c.z),o.push(0,0,1),h.x=(a[u]/e+1)/2,h.y=(a[u+1]/e+1)/2,l.push(h.x,h.y)}for(let f=1;f<=t;f++)r.push(f,f+1,0);this.setIndex(r),this.setAttribute("position",new ft(a,3)),this.setAttribute("normal",new ft(o,3)),this.setAttribute("uv",new ft(l,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new i(e.radius,e.segments,e.thetaStart,e.thetaLength)}},Oi=class i extends wt{constructor(e=1,t=1,n=1,s=32,r=1,a=!1,o=0,l=Math.PI*2){super(),this.type="CylinderGeometry",this.parameters={radiusTop:e,radiusBottom:t,height:n,radialSegments:s,heightSegments:r,openEnded:a,thetaStart:o,thetaLength:l};let c=this;s=Math.floor(s),r=Math.floor(r);let h=[],f=[],u=[],d=[],g=0,x=[],m=n/2,p=0;S(),a===!1&&(e>0&&A(!0),t>0&&A(!1)),this.setIndex(h),this.setAttribute("position",new ft(f,3)),this.setAttribute("normal",new ft(u,3)),this.setAttribute("uv",new ft(d,2));function S(){let v=new I,b=new I,E=0,C=(t-e)/n;for(let y=0;y<=r;y++){let w=[],P=y/r,U=P*(t-e)+e;for(let B=0;B<=s;B++){let W=B/s,F=W*l+o,V=Math.sin(F),se=Math.cos(F);b.x=U*V,b.y=-P*n+m,b.z=U*se,f.push(b.x,b.y,b.z),v.set(V,C,se).normalize(),u.push(v.x,v.y,v.z),d.push(W,1-P),w.push(g++)}x.push(w)}for(let y=0;y<s;y++)for(let w=0;w<r;w++){let P=x[w][y],U=x[w+1][y],B=x[w+1][y+1],W=x[w][y+1];(e>0||w!==0)&&(h.push(P,U,W),E+=3),(t>0||w!==r-1)&&(h.push(U,B,W),E+=3)}c.addGroup(p,E,0),p+=E}function A(v){let b=g,E=new ue,C=new I,y=0,w=v===!0?e:t,P=v===!0?1:-1;for(let B=1;B<=s;B++)f.push(0,m*P,0),u.push(0,P,0),d.push(.5,.5),g++;let U=g;for(let B=0;B<=s;B++){let F=B/s*l+o,V=Math.cos(F),se=Math.sin(F);C.x=w*se,C.y=m*P,C.z=w*V,f.push(C.x,C.y,C.z),u.push(0,P,0),E.x=V*.5+.5,E.y=se*.5*P+.5,d.push(E.x,E.y),g++}for(let B=0;B<s;B++){let W=b+B,F=U+B;v===!0?h.push(F,F+1,W):h.push(F+1,F,W),y+=3}c.addGroup(p,y,v===!0?1:2),p+=y}}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new i(e.radiusTop,e.radiusBottom,e.height,e.radialSegments,e.heightSegments,e.openEnded,e.thetaStart,e.thetaLength)}},la=class i extends Oi{constructor(e=1,t=1,n=32,s=1,r=!1,a=0,o=Math.PI*2){super(0,e,t,n,s,r,a,o),this.type="ConeGeometry",this.parameters={radius:e,height:t,radialSegments:n,heightSegments:s,openEnded:r,thetaStart:a,thetaLength:o}}static fromJSON(e){return new i(e.radius,e.height,e.radialSegments,e.heightSegments,e.openEnded,e.thetaStart,e.thetaLength)}};var In=class{constructor(){this.type="Curve",this.arcLengthDivisions=200,this.needsUpdate=!1,this.cacheArcLengths=null}getPoint(){ct("Curve: .getPoint() not implemented.")}getPointAt(e,t){let n=this.getUtoTmapping(e);return this.getPoint(n,t)}getPoints(e=5){let t=[];for(let n=0;n<=e;n++)t.push(this.getPoint(n/e));return t}getSpacedPoints(e=5){let t=[];for(let n=0;n<=e;n++)t.push(this.getPointAt(n/e));return t}getLength(){let e=this.getLengths();return e[e.length-1]}getLengths(e=this.arcLengthDivisions){if(this.cacheArcLengths&&this.cacheArcLengths.length===e+1&&!this.needsUpdate)return this.cacheArcLengths;this.needsUpdate=!1;let t=[],n,s=this.getPoint(0),r=0;t.push(0);for(let a=1;a<=e;a++)n=this.getPoint(a/e),r+=n.distanceTo(s),t.push(r),s=n;return this.cacheArcLengths=t,t}updateArcLengths(){this.needsUpdate=!0,this.getLengths()}getUtoTmapping(e,t=null){let n=this.getLengths(),s=0,r=n.length,a;t?a=t:a=e*n[r-1];let o=0,l=r-1,c;for(;o<=l;)if(s=Math.floor(o+(l-o)/2),c=n[s]-a,c<0)o=s+1;else if(c>0)l=s-1;else{l=s;break}if(s=l,n[s]===a)return s/(r-1);let h=n[s],u=n[s+1]-h,d=(a-h)/u;return(s+d)/(r-1)}getTangent(e,t){let s=e-1e-4,r=e+1e-4;s<0&&(s=0),r>1&&(r=1);let a=this.getPoint(s),o=this.getPoint(r),l=t||(a.isVector2?new ue:new I);return l.copy(o).sub(a).normalize(),l}getTangentAt(e,t){let n=this.getUtoTmapping(e);return this.getTangent(n,t)}computeFrenetFrames(e,t=!1){let n=new I,s=[],r=[],a=[],o=new I,l=new Rt;for(let d=0;d<=e;d++){let g=d/e;s[d]=this.getTangentAt(g,new I)}r[0]=new I,a[0]=new I;let c=Number.MAX_VALUE,h=Math.abs(s[0].x),f=Math.abs(s[0].y),u=Math.abs(s[0].z);h<=c&&(c=h,n.set(1,0,0)),f<=c&&(c=f,n.set(0,1,0)),u<=c&&n.set(0,0,1),o.crossVectors(s[0],n).normalize(),r[0].crossVectors(s[0],o),a[0].crossVectors(s[0],r[0]);for(let d=1;d<=e;d++){if(r[d]=r[d-1].clone(),a[d]=a[d-1].clone(),o.crossVectors(s[d-1],s[d]),o.length()>Number.EPSILON){o.normalize();let g=Math.acos(Mt(s[d-1].dot(s[d]),-1,1));r[d].applyMatrix4(l.makeRotationAxis(o,g))}a[d].crossVectors(s[d],r[d])}if(t===!0){let d=Math.acos(Mt(r[0].dot(r[e]),-1,1));d/=e,s[0].dot(o.crossVectors(r[0],r[e]))>0&&(d=-d);for(let g=1;g<=e;g++)r[g].applyMatrix4(l.makeRotationAxis(s[g],d*g)),a[g].crossVectors(s[g],r[g])}return{tangents:s,normals:r,binormals:a}}clone(){return new this.constructor().copy(this)}copy(e){return this.arcLengthDivisions=e.arcLengthDivisions,this}toJSON(){let e={metadata:{version:4.7,type:"Curve",generator:"Curve.toJSON"}};return e.arcLengthDivisions=this.arcLengthDivisions,e.type=this.type,e}fromJSON(e){return this.arcLengthDivisions=e.arcLengthDivisions,this}},or=class extends In{constructor(e=0,t=0,n=1,s=1,r=0,a=Math.PI*2,o=!1,l=0){super(),this.isEllipseCurve=!0,this.type="EllipseCurve",this.aX=e,this.aY=t,this.xRadius=n,this.yRadius=s,this.aStartAngle=r,this.aEndAngle=a,this.aClockwise=o,this.aRotation=l}getPoint(e,t=new ue){let n=t,s=Math.PI*2,r=this.aEndAngle-this.aStartAngle,a=Math.abs(r)<Number.EPSILON;for(;r<0;)r+=s;for(;r>s;)r-=s;r<Number.EPSILON&&(a?r=0:r=s),this.aClockwise===!0&&!a&&(r===s?r=-s:r=r-s);let o=this.aStartAngle+e*r,l=this.aX+this.xRadius*Math.cos(o),c=this.aY+this.yRadius*Math.sin(o);if(this.aRotation!==0){let h=Math.cos(this.aRotation),f=Math.sin(this.aRotation),u=l-this.aX,d=c-this.aY;l=u*h-d*f+this.aX,c=u*f+d*h+this.aY}return n.set(l,c)}copy(e){return super.copy(e),this.aX=e.aX,this.aY=e.aY,this.xRadius=e.xRadius,this.yRadius=e.yRadius,this.aStartAngle=e.aStartAngle,this.aEndAngle=e.aEndAngle,this.aClockwise=e.aClockwise,this.aRotation=e.aRotation,this}toJSON(){let e=super.toJSON();return e.aX=this.aX,e.aY=this.aY,e.xRadius=this.xRadius,e.yRadius=this.yRadius,e.aStartAngle=this.aStartAngle,e.aEndAngle=this.aEndAngle,e.aClockwise=this.aClockwise,e.aRotation=this.aRotation,e}fromJSON(e){return super.fromJSON(e),this.aX=e.aX,this.aY=e.aY,this.xRadius=e.xRadius,this.yRadius=e.yRadius,this.aStartAngle=e.aStartAngle,this.aEndAngle=e.aEndAngle,this.aClockwise=e.aClockwise,this.aRotation=e.aRotation,this}},nl=class extends or{constructor(e,t,n,s,r,a){super(e,t,n,n,s,r,a),this.isArcCurve=!0,this.type="ArcCurve"}};function I0(){let i=0,e=0,t=0,n=0;function s(r,a,o,l){i=r,e=o,t=-3*r+3*a-2*o-l,n=2*r-2*a+o+l}return{initCatmullRom:function(r,a,o,l,c){s(a,o,c*(o-r),c*(l-a))},initNonuniformCatmullRom:function(r,a,o,l,c,h,f){let u=(a-r)/c-(o-r)/(c+h)+(o-a)/h,d=(o-a)/h-(l-a)/(h+f)+(l-o)/f;u*=h,d*=h,s(a,o,u,d)},calc:function(r){let a=r*r,o=a*r;return i+e*r+t*a+n*o}}}var Fh=new I,Oh=new I,jc=new I0,Qc=new I0,e0=new I0,il=class extends In{constructor(e=[],t=!1,n="centripetal",s=.5){super(),this.isCatmullRomCurve3=!0,this.type="CatmullRomCurve3",this.points=e,this.closed=t,this.curveType=n,this.tension=s}getPoint(e,t=new I){let n=t,s=this.points,r=s.length,a=(r-(this.closed?0:1))*e,o=Math.floor(a),l=a-o;this.closed?o+=o>0?0:(Math.floor(Math.abs(o)/r)+1)*r:l===0&&o===r-1&&(o=r-2,l=1);let c,h;this.closed||o>0?c=s[(o-1)%r]:(Oh.subVectors(s[0],s[1]).add(s[0]),c=Oh);let f=s[o%r],u=s[(o+1)%r];if(this.closed||o+2<r?h=s[(o+2)%r]:(Fh.subVectors(s[r-1],s[r-2]).add(s[r-1]),h=Fh),this.curveType==="centripetal"||this.curveType==="chordal"){let d=this.curveType==="chordal"?.5:.25,g=Math.pow(c.distanceToSquared(f),d),x=Math.pow(f.distanceToSquared(u),d),m=Math.pow(u.distanceToSquared(h),d);x<1e-4&&(x=1),g<1e-4&&(g=x),m<1e-4&&(m=x),jc.initNonuniformCatmullRom(c.x,f.x,u.x,h.x,g,x,m),Qc.initNonuniformCatmullRom(c.y,f.y,u.y,h.y,g,x,m),e0.initNonuniformCatmullRom(c.z,f.z,u.z,h.z,g,x,m)}else this.curveType==="catmullrom"&&(jc.initCatmullRom(c.x,f.x,u.x,h.x,this.tension),Qc.initCatmullRom(c.y,f.y,u.y,h.y,this.tension),e0.initCatmullRom(c.z,f.z,u.z,h.z,this.tension));return n.set(jc.calc(l),Qc.calc(l),e0.calc(l)),n}copy(e){super.copy(e),this.points=[];for(let t=0,n=e.points.length;t<n;t++){let s=e.points[t];this.points.push(s.clone())}return this.closed=e.closed,this.curveType=e.curveType,this.tension=e.tension,this}toJSON(){let e=super.toJSON();e.points=[];for(let t=0,n=this.points.length;t<n;t++){let s=this.points[t];e.points.push(s.toArray())}return e.closed=this.closed,e.curveType=this.curveType,e.tension=this.tension,e}fromJSON(e){super.fromJSON(e),this.points=[];for(let t=0,n=e.points.length;t<n;t++){let s=e.points[t];this.points.push(new I().fromArray(s))}return this.closed=e.closed,this.curveType=e.curveType,this.tension=e.tension,this}};function Bh(i,e,t,n,s){let r=(n-e)*.5,a=(s-t)*.5,o=i*i,l=i*o;return(2*t-2*n+r+a)*l+(-3*t+3*n-2*r-a)*o+r*i+t}function od(i,e){let t=1-i;return t*t*e}function ld(i,e){return 2*(1-i)*i*e}function cd(i,e){return i*i*e}function Wr(i,e,t,n){return od(i,e)+ld(i,t)+cd(i,n)}function hd(i,e){let t=1-i;return t*t*t*e}function ud(i,e){let t=1-i;return 3*t*t*i*e}function fd(i,e){return 3*(1-i)*i*i*e}function dd(i,e){return i*i*i*e}function Xr(i,e,t,n,s){return hd(i,e)+ud(i,t)+fd(i,n)+dd(i,s)}var ca=class extends In{constructor(e=new ue,t=new ue,n=new ue,s=new ue){super(),this.isCubicBezierCurve=!0,this.type="CubicBezierCurve",this.v0=e,this.v1=t,this.v2=n,this.v3=s}getPoint(e,t=new ue){let n=t,s=this.v0,r=this.v1,a=this.v2,o=this.v3;return n.set(Xr(e,s.x,r.x,a.x,o.x),Xr(e,s.y,r.y,a.y,o.y)),n}copy(e){return super.copy(e),this.v0.copy(e.v0),this.v1.copy(e.v1),this.v2.copy(e.v2),this.v3.copy(e.v3),this}toJSON(){let e=super.toJSON();return e.v0=this.v0.toArray(),e.v1=this.v1.toArray(),e.v2=this.v2.toArray(),e.v3=this.v3.toArray(),e}fromJSON(e){return super.fromJSON(e),this.v0.fromArray(e.v0),this.v1.fromArray(e.v1),this.v2.fromArray(e.v2),this.v3.fromArray(e.v3),this}},sl=class extends In{constructor(e=new I,t=new I,n=new I,s=new I){super(),this.isCubicBezierCurve3=!0,this.type="CubicBezierCurve3",this.v0=e,this.v1=t,this.v2=n,this.v3=s}getPoint(e,t=new I){let n=t,s=this.v0,r=this.v1,a=this.v2,o=this.v3;return n.set(Xr(e,s.x,r.x,a.x,o.x),Xr(e,s.y,r.y,a.y,o.y),Xr(e,s.z,r.z,a.z,o.z)),n}copy(e){return super.copy(e),this.v0.copy(e.v0),this.v1.copy(e.v1),this.v2.copy(e.v2),this.v3.copy(e.v3),this}toJSON(){let e=super.toJSON();return e.v0=this.v0.toArray(),e.v1=this.v1.toArray(),e.v2=this.v2.toArray(),e.v3=this.v3.toArray(),e}fromJSON(e){return super.fromJSON(e),this.v0.fromArray(e.v0),this.v1.fromArray(e.v1),this.v2.fromArray(e.v2),this.v3.fromArray(e.v3),this}},ha=class extends In{constructor(e=new ue,t=new ue){super(),this.isLineCurve=!0,this.type="LineCurve",this.v1=e,this.v2=t}getPoint(e,t=new ue){let n=t;return e===1?n.copy(this.v2):(n.copy(this.v2).sub(this.v1),n.multiplyScalar(e).add(this.v1)),n}getPointAt(e,t){return this.getPoint(e,t)}getTangent(e,t=new ue){return t.subVectors(this.v2,this.v1).normalize()}getTangentAt(e,t){return this.getTangent(e,t)}copy(e){return super.copy(e),this.v1.copy(e.v1),this.v2.copy(e.v2),this}toJSON(){let e=super.toJSON();return e.v1=this.v1.toArray(),e.v2=this.v2.toArray(),e}fromJSON(e){return super.fromJSON(e),this.v1.fromArray(e.v1),this.v2.fromArray(e.v2),this}},lr=class extends In{constructor(e=new I,t=new I){super(),this.isLineCurve3=!0,this.type="LineCurve3",this.v1=e,this.v2=t}getPoint(e,t=new I){let n=t;return e===1?n.copy(this.v2):(n.copy(this.v2).sub(this.v1),n.multiplyScalar(e).add(this.v1)),n}getPointAt(e,t){return this.getPoint(e,t)}getTangent(e,t=new I){return t.subVectors(this.v2,this.v1).normalize()}getTangentAt(e,t){return this.getTangent(e,t)}copy(e){return super.copy(e),this.v1.copy(e.v1),this.v2.copy(e.v2),this}toJSON(){let e=super.toJSON();return e.v1=this.v1.toArray(),e.v2=this.v2.toArray(),e}fromJSON(e){return super.fromJSON(e),this.v1.fromArray(e.v1),this.v2.fromArray(e.v2),this}},ua=class extends In{constructor(e=new ue,t=new ue,n=new ue){super(),this.isQuadraticBezierCurve=!0,this.type="QuadraticBezierCurve",this.v0=e,this.v1=t,this.v2=n}getPoint(e,t=new ue){let n=t,s=this.v0,r=this.v1,a=this.v2;return n.set(Wr(e,s.x,r.x,a.x),Wr(e,s.y,r.y,a.y)),n}copy(e){return super.copy(e),this.v0.copy(e.v0),this.v1.copy(e.v1),this.v2.copy(e.v2),this}toJSON(){let e=super.toJSON();return e.v0=this.v0.toArray(),e.v1=this.v1.toArray(),e.v2=this.v2.toArray(),e}fromJSON(e){return super.fromJSON(e),this.v0.fromArray(e.v0),this.v1.fromArray(e.v1),this.v2.fromArray(e.v2),this}},fa=class extends In{constructor(e=new I,t=new I,n=new I){super(),this.isQuadraticBezierCurve3=!0,this.type="QuadraticBezierCurve3",this.v0=e,this.v1=t,this.v2=n}getPoint(e,t=new I){let n=t,s=this.v0,r=this.v1,a=this.v2;return n.set(Wr(e,s.x,r.x,a.x),Wr(e,s.y,r.y,a.y),Wr(e,s.z,r.z,a.z)),n}copy(e){return super.copy(e),this.v0.copy(e.v0),this.v1.copy(e.v1),this.v2.copy(e.v2),this}toJSON(){let e=super.toJSON();return e.v0=this.v0.toArray(),e.v1=this.v1.toArray(),e.v2=this.v2.toArray(),e}fromJSON(e){return super.fromJSON(e),this.v0.fromArray(e.v0),this.v1.fromArray(e.v1),this.v2.fromArray(e.v2),this}},da=class extends In{constructor(e=[]){super(),this.isSplineCurve=!0,this.type="SplineCurve",this.points=e}getPoint(e,t=new ue){let n=t,s=this.points,r=(s.length-1)*e,a=Math.floor(r),o=r-a,l=s[a===0?a:a-1],c=s[a],h=s[a>s.length-2?s.length-1:a+1],f=s[a>s.length-3?s.length-1:a+2];return n.set(Bh(o,l.x,c.x,h.x,f.x),Bh(o,l.y,c.y,h.y,f.y)),n}copy(e){super.copy(e),this.points=[];for(let t=0,n=e.points.length;t<n;t++){let s=e.points[t];this.points.push(s.clone())}return this}toJSON(){let e=super.toJSON();e.points=[];for(let t=0,n=this.points.length;t<n;t++){let s=this.points[t];e.points.push(s.toArray())}return e}fromJSON(e){super.fromJSON(e),this.points=[];for(let t=0,n=e.points.length;t<n;t++){let s=e.points[t];this.points.push(new ue().fromArray(s))}return this}},rl=Object.freeze({__proto__:null,ArcCurve:nl,CatmullRomCurve3:il,CubicBezierCurve:ca,CubicBezierCurve3:sl,EllipseCurve:or,LineCurve:ha,LineCurve3:lr,QuadraticBezierCurve:ua,QuadraticBezierCurve3:fa,SplineCurve:da}),cr=class extends In{constructor(){super(),this.type="CurvePath",this.curves=[],this.autoClose=!1}add(e){this.curves.push(e)}closePath(){let e=this.curves[0].getPoint(0),t=this.curves[this.curves.length-1].getPoint(1);if(!e.equals(t)){let n=e.isVector2===!0?"LineCurve":"LineCurve3";this.curves.push(new rl[n](t,e))}return this}getPoint(e,t){let n=e*this.getLength(),s=this.getCurveLengths(),r=0;for(;r<s.length;){if(s[r]>=n){let a=s[r]-n,o=this.curves[r],l=o.getLength(),c=l===0?0:1-a/l;return o.getPointAt(c,t)}r++}return null}getLength(){let e=this.getCurveLengths();return e[e.length-1]}updateArcLengths(){this.needsUpdate=!0,this.cacheLengths=null,this.getCurveLengths()}getCurveLengths(){if(this.cacheLengths&&this.cacheLengths.length===this.curves.length)return this.cacheLengths;let e=[],t=0;for(let n=0,s=this.curves.length;n<s;n++)t+=this.curves[n].getLength(),e.push(t);return this.cacheLengths=e,e}getSpacedPoints(e=40){let t=[];for(let n=0;n<=e;n++)t.push(this.getPoint(n/e));return this.autoClose&&t.push(t[0]),t}getPoints(e=12){let t=[],n;for(let s=0,r=this.curves;s<r.length;s++){let a=r[s],o=a.isEllipseCurve?e*2:a.isLineCurve||a.isLineCurve3?1:a.isSplineCurve?e*a.points.length:e,l=a.getPoints(o);for(let c=0;c<l.length;c++){let h=l[c];n&&n.equals(h)||(t.push(h),n=h)}}return this.autoClose&&t.length>1&&!t[t.length-1].equals(t[0])&&t.push(t[0]),t}copy(e){super.copy(e),this.curves=[];for(let t=0,n=e.curves.length;t<n;t++){let s=e.curves[t];this.curves.push(s.clone())}return this.autoClose=e.autoClose,this}toJSON(){let e=super.toJSON();e.autoClose=this.autoClose,e.curves=[];for(let t=0,n=this.curves.length;t<n;t++){let s=this.curves[t];e.curves.push(s.toJSON())}return e}fromJSON(e){super.fromJSON(e),this.autoClose=e.autoClose,this.curves=[];for(let t=0,n=e.curves.length;t<n;t++){let s=e.curves[t];this.curves.push(new rl[s.type]().fromJSON(s))}return this}},pa=class extends cr{constructor(e){super(),this.type="Path",this.currentPoint=new ue,e&&this.setFromPoints(e)}setFromPoints(e){this.moveTo(e[0].x,e[0].y);for(let t=1,n=e.length;t<n;t++)this.lineTo(e[t].x,e[t].y);return this}moveTo(e,t){return this.currentPoint.set(e,t),this}lineTo(e,t){let n=new ha(this.currentPoint.clone(),new ue(e,t));return this.curves.push(n),this.currentPoint.set(e,t),this}quadraticCurveTo(e,t,n,s){let r=new ua(this.currentPoint.clone(),new ue(e,t),new ue(n,s));return this.curves.push(r),this.currentPoint.set(n,s),this}bezierCurveTo(e,t,n,s,r,a){let o=new ca(this.currentPoint.clone(),new ue(e,t),new ue(n,s),new ue(r,a));return this.curves.push(o),this.currentPoint.set(r,a),this}splineThru(e){let t=[this.currentPoint.clone()].concat(e),n=new da(t);return this.curves.push(n),this.currentPoint.copy(e[e.length-1]),this}arc(e,t,n,s,r,a){let o=this.currentPoint.x,l=this.currentPoint.y;return this.absarc(e+o,t+l,n,s,r,a),this}absarc(e,t,n,s,r,a){return this.absellipse(e,t,n,n,s,r,a),this}ellipse(e,t,n,s,r,a,o,l){let c=this.currentPoint.x,h=this.currentPoint.y;return this.absellipse(e+c,t+h,n,s,r,a,o,l),this}absellipse(e,t,n,s,r,a,o,l){let c=new or(e,t,n,s,r,a,o,l);if(this.curves.length>0){let f=c.getPoint(0);f.equals(this.currentPoint)||this.lineTo(f.x,f.y)}this.curves.push(c);let h=c.getPoint(1);return this.currentPoint.copy(h),this}copy(e){return super.copy(e),this.currentPoint.copy(e.currentPoint),this}toJSON(){let e=super.toJSON();return e.currentPoint=this.currentPoint.toArray(),e}fromJSON(e){return super.fromJSON(e),this.currentPoint.fromArray(e.currentPoint),this}},Bi=class extends pa{constructor(e){super(e),this.uuid=Li(),this.type="Shape",this.holes=[]}getPointsHoles(e){let t=[];for(let n=0,s=this.holes.length;n<s;n++)t[n]=this.holes[n].getPoints(e);return t}extractPoints(e){return{shape:this.getPoints(e),holes:this.getPointsHoles(e)}}copy(e){super.copy(e),this.holes=[];for(let t=0,n=e.holes.length;t<n;t++){let s=e.holes[t];this.holes.push(s.clone())}return this}toJSON(){let e=super.toJSON();e.uuid=this.uuid,e.holes=[];for(let t=0,n=this.holes.length;t<n;t++){let s=this.holes[t];e.holes.push(s.toJSON())}return e}fromJSON(e){super.fromJSON(e),this.uuid=e.uuid,this.holes=[];for(let t=0,n=e.holes.length;t<n;t++){let s=e.holes[t];this.holes.push(new pa().fromJSON(s))}return this}};function pd(i,e,t=2){let n=e&&e.length,s=n?e[0]*t:i.length,r=Fu(i,0,s,t,!0),a=[];if(!r||r.next===r.prev)return a;let o,l,c;if(n&&(r=vd(i,e,r,t)),i.length>80*t){o=i[0],l=i[1];let h=o,f=l;for(let u=t;u<s;u+=t){let d=i[u],g=i[u+1];d<o&&(o=d),g<l&&(l=g),d>h&&(h=d),g>f&&(f=g)}c=Math.max(h-o,f-l),c=c!==0?32767/c:0}return ma(r,a,t,o,l,c,0),a}function Fu(i,e,t,n,s){let r;if(s===Pd(i,e,t,n)>0)for(let a=e;a<t;a+=n)r=zh(a/n|0,i[a],i[a+1],r);else for(let a=t-n;a>=e;a-=n)r=zh(a/n|0,i[a],i[a+1],r);return r&&hr(r,r.next)&&(_a(r),r=r.next),r}function vs(i,e){if(!i)return i;e||(e=i);let t=i,n;do if(n=!1,!t.steiner&&(hr(t,t.next)||Xt(t.prev,t,t.next)===0)){if(_a(t),t=e=t.prev,t===t.next)break;n=!0}else t=t.next;while(n||t!==e);return e}function ma(i,e,t,n,s,r,a){if(!i)return;!a&&r&&Ed(i,n,s,r);let o=i;for(;i.prev!==i.next;){let l=i.prev,c=i.next;if(r?gd(i,n,s,r):md(i)){e.push(l.i,i.i,c.i),_a(i),i=c.next,o=c.next;continue}if(i=c,i===o){a?a===1?(i=_d(vs(i),e),ma(i,e,t,n,s,r,2)):a===2&&xd(i,e,t,n,s,r):ma(vs(i),e,t,n,s,r,1);break}}}function md(i){let e=i.prev,t=i,n=i.next;if(Xt(e,t,n)>=0)return!1;let s=e.x,r=t.x,a=n.x,o=e.y,l=t.y,c=n.y,h=Math.min(s,r,a),f=Math.min(o,l,c),u=Math.max(s,r,a),d=Math.max(o,l,c),g=n.next;for(;g!==e;){if(g.x>=h&&g.x<=u&&g.y>=f&&g.y<=d&&Gr(s,o,r,l,a,c,g.x,g.y)&&Xt(g.prev,g,g.next)>=0)return!1;g=g.next}return!0}function gd(i,e,t,n){let s=i.prev,r=i,a=i.next;if(Xt(s,r,a)>=0)return!1;let o=s.x,l=r.x,c=a.x,h=s.y,f=r.y,u=a.y,d=Math.min(o,l,c),g=Math.min(h,f,u),x=Math.max(o,l,c),m=Math.max(h,f,u),p=l0(d,g,e,t,n),S=l0(x,m,e,t,n),A=i.prevZ,v=i.nextZ;for(;A&&A.z>=p&&v&&v.z<=S;){if(A.x>=d&&A.x<=x&&A.y>=g&&A.y<=m&&A!==s&&A!==a&&Gr(o,h,l,f,c,u,A.x,A.y)&&Xt(A.prev,A,A.next)>=0||(A=A.prevZ,v.x>=d&&v.x<=x&&v.y>=g&&v.y<=m&&v!==s&&v!==a&&Gr(o,h,l,f,c,u,v.x,v.y)&&Xt(v.prev,v,v.next)>=0))return!1;v=v.nextZ}for(;A&&A.z>=p;){if(A.x>=d&&A.x<=x&&A.y>=g&&A.y<=m&&A!==s&&A!==a&&Gr(o,h,l,f,c,u,A.x,A.y)&&Xt(A.prev,A,A.next)>=0)return!1;A=A.prevZ}for(;v&&v.z<=S;){if(v.x>=d&&v.x<=x&&v.y>=g&&v.y<=m&&v!==s&&v!==a&&Gr(o,h,l,f,c,u,v.x,v.y)&&Xt(v.prev,v,v.next)>=0)return!1;v=v.nextZ}return!0}function _d(i,e){let t=i;do{let n=t.prev,s=t.next.next;!hr(n,s)&&Bu(n,t,t.next,s)&&ga(n,s)&&ga(s,n)&&(e.push(n.i,t.i,s.i),_a(t),_a(t.next),t=i=s),t=t.next}while(t!==i);return vs(t)}function xd(i,e,t,n,s,r){let a=i;do{let o=a.next.next;for(;o!==a.prev;){if(a.i!==o.i&&Ad(a,o)){let l=zu(a,o);a=vs(a,a.next),l=vs(l,l.next),ma(a,e,t,n,s,r,0),ma(l,e,t,n,s,r,0);return}o=o.next}a=a.next}while(a!==i)}function vd(i,e,t,n){let s=[];for(let r=0,a=e.length;r<a;r++){let o=e[r]*n,l=r<a-1?e[r+1]*n:i.length,c=Fu(i,o,l,n,!1);c===c.next&&(c.steiner=!0),s.push(wd(c))}s.sort(yd);for(let r=0;r<s.length;r++)t=Md(s[r],t);return t}function yd(i,e){let t=i.x-e.x;if(t===0&&(t=i.y-e.y,t===0)){let n=(i.next.y-i.y)/(i.next.x-i.x),s=(e.next.y-e.y)/(e.next.x-e.x);t=n-s}return t}function Md(i,e){let t=Sd(i,e);if(!t)return e;let n=zu(t,i);return vs(n,n.next),vs(t,t.next)}function Sd(i,e){let t=e,n=i.x,s=i.y,r=-1/0,a;if(hr(i,t))return t;do{if(hr(i,t.next))return t.next;if(s<=t.y&&s>=t.next.y&&t.next.y!==t.y){let f=t.x+(s-t.y)*(t.next.x-t.x)/(t.next.y-t.y);if(f<=n&&f>r&&(r=f,a=t.x<t.next.x?t:t.next,f===n))return a}t=t.next}while(t!==e);if(!a)return null;let o=a,l=a.x,c=a.y,h=1/0;t=a;do{if(n>=t.x&&t.x>=l&&n!==t.x&&Ou(s<c?n:r,s,l,c,s<c?r:n,s,t.x,t.y)){let f=Math.abs(s-t.y)/(n-t.x);ga(t,i)&&(f<h||f===h&&(t.x>a.x||t.x===a.x&&bd(a,t)))&&(a=t,h=f)}t=t.next}while(t!==o);return a}function bd(i,e){return Xt(i.prev,i,e.prev)<0&&Xt(e.next,i,i.next)<0}function Ed(i,e,t,n){let s=i;do s.z===0&&(s.z=l0(s.x,s.y,e,t,n)),s.prevZ=s.prev,s.nextZ=s.next,s=s.next;while(s!==i);s.prevZ.nextZ=null,s.prevZ=null,Td(s)}function Td(i){let e,t=1;do{let n=i,s;i=null;let r=null;for(e=0;n;){e++;let a=n,o=0;for(let c=0;c<t&&(o++,a=a.nextZ,!!a);c++);let l=t;for(;o>0||l>0&&a;)o!==0&&(l===0||!a||n.z<=a.z)?(s=n,n=n.nextZ,o--):(s=a,a=a.nextZ,l--),r?r.nextZ=s:i=s,s.prevZ=r,r=s;n=a}r.nextZ=null,t*=2}while(e>1);return i}function l0(i,e,t,n,s){return i=(i-t)*s|0,e=(e-n)*s|0,i=(i|i<<8)&16711935,i=(i|i<<4)&252645135,i=(i|i<<2)&858993459,i=(i|i<<1)&1431655765,e=(e|e<<8)&16711935,e=(e|e<<4)&252645135,e=(e|e<<2)&858993459,e=(e|e<<1)&1431655765,i|e<<1}function wd(i){let e=i,t=i;do(e.x<t.x||e.x===t.x&&e.y<t.y)&&(t=e),e=e.next;while(e!==i);return t}function Ou(i,e,t,n,s,r,a,o){return(s-a)*(e-o)>=(i-a)*(r-o)&&(i-a)*(n-o)>=(t-a)*(e-o)&&(t-a)*(r-o)>=(s-a)*(n-o)}function Gr(i,e,t,n,s,r,a,o){return!(i===a&&e===o)&&Ou(i,e,t,n,s,r,a,o)}function Ad(i,e){return i.next.i!==e.i&&i.prev.i!==e.i&&!Rd(i,e)&&(ga(i,e)&&ga(e,i)&&Cd(i,e)&&(Xt(i.prev,i,e.prev)||Xt(i,e.prev,e))||hr(i,e)&&Xt(i.prev,i,i.next)>0&&Xt(e.prev,e,e.next)>0)}function Xt(i,e,t){return(e.y-i.y)*(t.x-e.x)-(e.x-i.x)*(t.y-e.y)}function hr(i,e){return i.x===e.x&&i.y===e.y}function Bu(i,e,t,n){let s=Do(Xt(i,e,t)),r=Do(Xt(i,e,n)),a=Do(Xt(t,n,i)),o=Do(Xt(t,n,e));return!!(s!==r&&a!==o||s===0&&Lo(i,t,e)||r===0&&Lo(i,n,e)||a===0&&Lo(t,i,n)||o===0&&Lo(t,e,n))}function Lo(i,e,t){return e.x<=Math.max(i.x,t.x)&&e.x>=Math.min(i.x,t.x)&&e.y<=Math.max(i.y,t.y)&&e.y>=Math.min(i.y,t.y)}function Do(i){return i>0?1:i<0?-1:0}function Rd(i,e){let t=i;do{if(t.i!==i.i&&t.next.i!==i.i&&t.i!==e.i&&t.next.i!==e.i&&Bu(t,t.next,i,e))return!0;t=t.next}while(t!==i);return!1}function ga(i,e){return Xt(i.prev,i,i.next)<0?Xt(i,e,i.next)>=0&&Xt(i,i.prev,e)>=0:Xt(i,e,i.prev)<0||Xt(i,i.next,e)<0}function Cd(i,e){let t=i,n=!1,s=(i.x+e.x)/2,r=(i.y+e.y)/2;do t.y>r!=t.next.y>r&&t.next.y!==t.y&&s<(t.next.x-t.x)*(r-t.y)/(t.next.y-t.y)+t.x&&(n=!n),t=t.next;while(t!==i);return n}function zu(i,e){let t=c0(i.i,i.x,i.y),n=c0(e.i,e.x,e.y),s=i.next,r=e.prev;return i.next=e,e.prev=i,t.next=s,s.prev=t,n.next=t,t.prev=n,r.next=n,n.prev=r,n}function zh(i,e,t,n){let s=c0(i,e,t);return n?(s.next=n.next,s.prev=n,n.next.prev=s,n.next=s):(s.prev=s,s.next=s),s}function _a(i){i.next.prev=i.prev,i.prev.next=i.next,i.prevZ&&(i.prevZ.nextZ=i.nextZ),i.nextZ&&(i.nextZ.prevZ=i.prevZ)}function c0(i,e,t){return{i,x:e,y:t,prev:null,next:null,z:0,prevZ:null,nextZ:null,steiner:!1}}function Pd(i,e,t,n){let s=0;for(let r=e,a=t-n;r<t;r+=n)s+=(i[a]-i[r])*(i[r+1]+i[a+1]),a=r;return s}var h0=class{static triangulate(e,t,n=2){return pd(e,t,n)}},fi=class i{static area(e){let t=e.length,n=0;for(let s=t-1,r=0;r<t;s=r++)n+=e[s].x*e[r].y-e[r].x*e[s].y;return n*.5}static isClockWise(e){return i.area(e)<0}static triangulateShape(e,t){let n=[],s=[],r=[];Hh(e),kh(n,e);let a=e.length;t.forEach(Hh);for(let l=0;l<t.length;l++)s.push(a),a+=t[l].length,kh(n,t[l]);let o=h0.triangulate(n,s);for(let l=0;l<o.length;l+=3)r.push(o.slice(l,l+3));return r}};function Hh(i){let e=i.length;e>2&&i[e-1].equals(i[0])&&i.pop()}function kh(i,e){for(let t=0;t<e.length;t++)i.push(e[t].x),i.push(e[t].y)}var xa=class i extends wt{constructor(e=new Bi([new ue(.5,.5),new ue(-.5,.5),new ue(-.5,-.5),new ue(.5,-.5)]),t={}){super(),this.type="ExtrudeGeometry",this.parameters={shapes:e,options:t},e=Array.isArray(e)?e:[e];let n=this,s=[],r=[];for(let o=0,l=e.length;o<l;o++){let c=e[o];a(c)}this.setAttribute("position",new ft(s,3)),this.setAttribute("uv",new ft(r,2)),this.computeVertexNormals();function a(o){let l=[],c=t.curveSegments!==void 0?t.curveSegments:12,h=t.steps!==void 0?t.steps:1,f=t.depth!==void 0?t.depth:1,u=t.bevelEnabled!==void 0?t.bevelEnabled:!0,d=t.bevelThickness!==void 0?t.bevelThickness:.2,g=t.bevelSize!==void 0?t.bevelSize:d-.1,x=t.bevelOffset!==void 0?t.bevelOffset:0,m=t.bevelSegments!==void 0?t.bevelSegments:3,p=t.extrudePath,S=t.UVGenerator!==void 0?t.UVGenerator:Id,A,v=!1,b,E,C,y;if(p){A=p.getSpacedPoints(h),v=!0,u=!1;let Z=p.isCatmullRomCurve3?p.closed:!1;b=p.computeFrenetFrames(h,Z),E=new I,C=new I,y=new I}u||(m=0,d=0,g=0,x=0);let w=o.extractPoints(c),P=w.shape,U=w.holes;if(!fi.isClockWise(P)){P=P.reverse();for(let Z=0,ce=U.length;Z<ce;Z++){let Me=U[Z];fi.isClockWise(Me)&&(U[Z]=Me.reverse())}}function W(Z){let Me=10000000000000001e-36,ge=Z[0];for(let xe=1;xe<=Z.length;xe++){let ke=xe%Z.length,Le=Z[ke],Je=Le.x-ge.x,tt=Le.y-ge.y,L=Je*Je+tt*tt,Qe=Math.max(Math.abs(Le.x),Math.abs(Le.y),Math.abs(ge.x),Math.abs(ge.y)),at=Me*Qe*Qe;if(L<=at){Z.splice(ke,1),xe--;continue}ge=Le}}W(P),U.forEach(W);let F=U.length,V=P;for(let Z=0;Z<F;Z++){let ce=U[Z];P=P.concat(ce)}function se(Z,ce,Me){return ce||lt("ExtrudeGeometry: vec does not exist"),Z.clone().addScaledVector(ce,Me)}let K=P.length;function de(Z,ce,Me){let ge,xe,ke,Le=Z.x-ce.x,Je=Z.y-ce.y,tt=Me.x-Z.x,L=Me.y-Z.y,Qe=Le*Le+Je*Je,at=Le*L-Je*tt;if(Math.abs(at)>Number.EPSILON){let T=Math.sqrt(Qe),_=Math.sqrt(tt*tt+L*L),H=ce.x-Je/T,G=ce.y+Le/T,ne=Me.x-L/_,ve=Me.y+tt/_,Ae=((ne-H)*L-(ve-G)*tt)/(Le*L-Je*tt);ge=H+Le*Ae-Z.x,xe=G+Je*Ae-Z.y;let ee=ge*ge+xe*xe;if(ee<=2)return new ue(ge,xe);ke=Math.sqrt(ee/2)}else{let T=!1;Le>Number.EPSILON?tt>Number.EPSILON&&(T=!0):Le<-Number.EPSILON?tt<-Number.EPSILON&&(T=!0):Math.sign(Je)===Math.sign(L)&&(T=!0),T?(ge=-Je,xe=Le,ke=Math.sqrt(Qe)):(ge=Le,xe=Je,ke=Math.sqrt(Qe/2))}return new ue(ge/ke,xe/ke)}let te=[];for(let Z=0,ce=V.length,Me=ce-1,ge=Z+1;Z<ce;Z++,Me++,ge++)Me===ce&&(Me=0),ge===ce&&(ge=0),te[Z]=de(V[Z],V[Me],V[ge]);let ae=[],O,ye=te.concat();for(let Z=0,ce=F;Z<ce;Z++){let Me=U[Z];O=[];for(let ge=0,xe=Me.length,ke=xe-1,Le=ge+1;ge<xe;ge++,ke++,Le++)ke===xe&&(ke=0),Le===xe&&(Le=0),O[ge]=de(Me[ge],Me[ke],Me[Le]);ae.push(O),ye=ye.concat(O)}let Se;if(m===0)Se=fi.triangulateShape(V,U);else{let Z=[],ce=[];for(let Me=0;Me<m;Me++){let ge=Me/m,xe=d*Math.cos(ge*Math.PI/2),ke=g*Math.sin(ge*Math.PI/2)+x;for(let Le=0,Je=V.length;Le<Je;Le++){let tt=se(V[Le],te[Le],ke);he(tt.x,tt.y,-xe),ge===0&&Z.push(tt)}for(let Le=0,Je=F;Le<Je;Le++){let tt=U[Le];O=ae[Le];let L=[];for(let Qe=0,at=tt.length;Qe<at;Qe++){let T=se(tt[Qe],O[Qe],ke);he(T.x,T.y,-xe),ge===0&&L.push(T)}ge===0&&ce.push(L)}}Se=fi.triangulateShape(Z,ce)}let be=Se.length,Ve=g+x;for(let Z=0;Z<K;Z++){let ce=u?se(P[Z],ye[Z],Ve):P[Z];v?(C.copy(b.normals[0]).multiplyScalar(ce.x),E.copy(b.binormals[0]).multiplyScalar(ce.y),y.copy(A[0]).add(C).add(E),he(y.x,y.y,y.z)):he(ce.x,ce.y,0)}for(let Z=1;Z<=h;Z++)for(let ce=0;ce<K;ce++){let Me=u?se(P[ce],ye[ce],Ve):P[ce];v?(C.copy(b.normals[Z]).multiplyScalar(Me.x),E.copy(b.binormals[Z]).multiplyScalar(Me.y),y.copy(A[Z]).add(C).add(E),he(y.x,y.y,y.z)):he(Me.x,Me.y,f/h*Z)}for(let Z=m-1;Z>=0;Z--){let ce=Z/m,Me=d*Math.cos(ce*Math.PI/2),ge=g*Math.sin(ce*Math.PI/2)+x;for(let xe=0,ke=V.length;xe<ke;xe++){let Le=se(V[xe],te[xe],ge);he(Le.x,Le.y,f+Me)}for(let xe=0,ke=U.length;xe<ke;xe++){let Le=U[xe];O=ae[xe];for(let Je=0,tt=Le.length;Je<tt;Je++){let L=se(Le[Je],O[Je],ge);v?he(L.x,L.y+A[h-1].y,A[h-1].x+Me):he(L.x,L.y,f+Me)}}}me(),$();function me(){let Z=s.length/3;if(u){let ce=0,Me=K*ce;for(let ge=0;ge<be;ge++){let xe=Se[ge];Te(xe[2]+Me,xe[1]+Me,xe[0]+Me)}ce=h+m*2,Me=K*ce;for(let ge=0;ge<be;ge++){let xe=Se[ge];Te(xe[0]+Me,xe[1]+Me,xe[2]+Me)}}else{for(let ce=0;ce<be;ce++){let Me=Se[ce];Te(Me[2],Me[1],Me[0])}for(let ce=0;ce<be;ce++){let Me=Se[ce];Te(Me[0]+K*h,Me[1]+K*h,Me[2]+K*h)}}n.addGroup(Z,s.length/3-Z,0)}function $(){let Z=s.length/3,ce=0;X(V,ce),ce+=V.length;for(let Me=0,ge=U.length;Me<ge;Me++){let xe=U[Me];X(xe,ce),ce+=xe.length}n.addGroup(Z,s.length/3-Z,1)}function X(Z,ce){let Me=Z.length;for(;--Me>=0;){let ge=Me,xe=Me-1;xe<0&&(xe=Z.length-1);for(let ke=0,Le=h+m*2;ke<Le;ke++){let Je=K*ke,tt=K*(ke+1),L=ce+ge+Je,Qe=ce+xe+Je,at=ce+xe+tt,T=ce+ge+tt;le(L,Qe,at,T)}}}function he(Z,ce,Me){l.push(Z),l.push(ce),l.push(Me)}function Te(Z,ce,Me){Ie(Z),Ie(ce),Ie(Me);let ge=s.length/3,xe=S.generateTopUV(n,s,ge-3,ge-2,ge-1);st(xe[0]),st(xe[1]),st(xe[2])}function le(Z,ce,Me,ge){Ie(Z),Ie(ce),Ie(ge),Ie(ce),Ie(Me),Ie(ge);let xe=s.length/3,ke=S.generateSideWallUV(n,s,xe-6,xe-3,xe-2,xe-1);st(ke[0]),st(ke[1]),st(ke[3]),st(ke[1]),st(ke[2]),st(ke[3])}function Ie(Z){s.push(l[Z*3+0]),s.push(l[Z*3+1]),s.push(l[Z*3+2])}function st(Z){r.push(Z.x),r.push(Z.y)}}}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}toJSON(){let e=super.toJSON(),t=this.parameters.shapes,n=this.parameters.options;return Ld(t,n,e)}static fromJSON(e,t){let n=[];for(let r=0,a=e.shapes.length;r<a;r++){let o=t[e.shapes[r]];n.push(o)}let s=e.options.extrudePath;return s!==void 0&&(e.options.extrudePath=new rl[s.type]().fromJSON(s)),new i(n,e.options)}},Id={generateTopUV:function(i,e,t,n,s){let r=e[t*3],a=e[t*3+1],o=e[n*3],l=e[n*3+1],c=e[s*3],h=e[s*3+1];return[new ue(r,a),new ue(o,l),new ue(c,h)]},generateSideWallUV:function(i,e,t,n,s,r){let a=e[t*3],o=e[t*3+1],l=e[t*3+2],c=e[n*3],h=e[n*3+1],f=e[n*3+2],u=e[s*3],d=e[s*3+1],g=e[s*3+2],x=e[r*3],m=e[r*3+1],p=e[r*3+2];return Math.abs(o-h)<Math.abs(a-c)?[new ue(a,1-l),new ue(c,1-f),new ue(u,1-g),new ue(x,1-p)]:[new ue(o,1-l),new ue(h,1-f),new ue(d,1-g),new ue(m,1-p)]}};function Ld(i,e,t){if(t.shapes=[],Array.isArray(i))for(let n=0,s=i.length;n<s;n++){let r=i[n];t.shapes.push(r.uuid)}else t.shapes.push(i.uuid);return t.options=Object.assign({},e),e.extrudePath!==void 0&&(t.options.extrudePath=e.extrudePath.toJSON()),t}var ur=class i extends wt{constructor(e=[new ue(0,-.5),new ue(.5,0),new ue(0,.5)],t=12,n=0,s=Math.PI*2){super(),this.type="LatheGeometry",this.parameters={points:e,segments:t,phiStart:n,phiLength:s},t=Math.floor(t),s=Mt(s,0,Math.PI*2);let r=[],a=[],o=[],l=[],c=[],h=1/t,f=new I,u=new ue,d=new I,g=new I,x=new I,m=0,p=0;for(let S=0;S<=e.length-1;S++)switch(S){case 0:m=e[S+1].x-e[S].x,p=e[S+1].y-e[S].y,d.x=p*1,d.y=-m,d.z=p*0,x.copy(d),d.normalize(),l.push(d.x,d.y,d.z);break;case e.length-1:l.push(x.x,x.y,x.z);break;default:m=e[S+1].x-e[S].x,p=e[S+1].y-e[S].y,d.x=p*1,d.y=-m,d.z=p*0,g.copy(d),d.x+=x.x,d.y+=x.y,d.z+=x.z,d.normalize(),l.push(d.x,d.y,d.z),x.copy(g)}for(let S=0;S<=t;S++){let A=n+S*h*s,v=Math.sin(A),b=Math.cos(A);for(let E=0;E<=e.length-1;E++){f.x=e[E].x*v,f.y=e[E].y,f.z=e[E].x*b,a.push(f.x,f.y,f.z),u.x=S/t,u.y=E/(e.length-1),o.push(u.x,u.y);let C=l[3*E+0]*v,y=l[3*E+1],w=l[3*E+0]*b;c.push(C,y,w)}}for(let S=0;S<t;S++)for(let A=0;A<e.length-1;A++){let v=A+S*e.length,b=v,E=v+e.length,C=v+e.length+1,y=v+1;r.push(b,E,y),r.push(C,y,E)}this.setIndex(r),this.setAttribute("position",new ft(a,3)),this.setAttribute("uv",new ft(o,2)),this.setAttribute("normal",new ft(c,3))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new i(e.points,e.segments,e.phiStart,e.phiLength)}};var Ji=class i extends wt{constructor(e=1,t=1,n=1,s=1){super(),this.type="PlaneGeometry",this.parameters={width:e,height:t,widthSegments:n,heightSegments:s};let r=e/2,a=t/2,o=Math.floor(n),l=Math.floor(s),c=o+1,h=l+1,f=e/o,u=t/l,d=[],g=[],x=[],m=[];for(let p=0;p<h;p++){let S=p*u-a;for(let A=0;A<c;A++){let v=A*f-r;g.push(v,-S,0),x.push(0,0,1),m.push(A/o),m.push(1-p/l)}}for(let p=0;p<l;p++)for(let S=0;S<o;S++){let A=S+c*p,v=S+c*(p+1),b=S+1+c*(p+1),E=S+1+c*p;d.push(A,v,E),d.push(v,b,E)}this.setIndex(d),this.setAttribute("position",new ft(g,3)),this.setAttribute("normal",new ft(x,3)),this.setAttribute("uv",new ft(m,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new i(e.width,e.height,e.widthSegments,e.heightSegments)}},fr=class i extends wt{constructor(e=.5,t=1,n=32,s=1,r=0,a=Math.PI*2){super(),this.type="RingGeometry",this.parameters={innerRadius:e,outerRadius:t,thetaSegments:n,phiSegments:s,thetaStart:r,thetaLength:a},n=Math.max(3,n),s=Math.max(1,s);let o=[],l=[],c=[],h=[],f=e,u=(t-e)/s,d=new I,g=new ue;for(let x=0;x<=s;x++){for(let m=0;m<=n;m++){let p=r+m/n*a;d.x=f*Math.cos(p),d.y=f*Math.sin(p),l.push(d.x,d.y,d.z),c.push(0,0,1),g.x=(d.x/t+1)/2,g.y=(d.y/t+1)/2,h.push(g.x,g.y)}f+=u}for(let x=0;x<s;x++){let m=x*(n+1);for(let p=0;p<n;p++){let S=p+m,A=S,v=S+n+1,b=S+n+2,E=S+1;o.push(A,v,E),o.push(v,b,E)}}this.setIndex(o),this.setAttribute("position",new ft(l,3)),this.setAttribute("normal",new ft(c,3)),this.setAttribute("uv",new ft(h,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new i(e.innerRadius,e.outerRadius,e.thetaSegments,e.phiSegments,e.thetaStart,e.thetaLength)}},va=class i extends wt{constructor(e=new Bi([new ue(0,.5),new ue(-.5,-.5),new ue(.5,-.5)]),t=12){super(),this.type="ShapeGeometry",this.parameters={shapes:e,curveSegments:t};let n=[],s=[],r=[],a=[],o=0,l=0;if(Array.isArray(e)===!1)c(e);else for(let h=0;h<e.length;h++)c(e[h]),this.addGroup(o,l,h),o+=l,l=0;this.setIndex(n),this.setAttribute("position",new ft(s,3)),this.setAttribute("normal",new ft(r,3)),this.setAttribute("uv",new ft(a,2));function c(h){let f=s.length/3,u=h.extractPoints(t),d=u.shape,g=u.holes;fi.isClockWise(d)===!1&&(d=d.reverse());for(let m=0,p=g.length;m<p;m++){let S=g[m];fi.isClockWise(S)===!0&&(g[m]=S.reverse())}let x=fi.triangulateShape(d,g);for(let m=0,p=g.length;m<p;m++){let S=g[m];d=d.concat(S)}for(let m=0,p=d.length;m<p;m++){let S=d[m];s.push(S.x,S.y,0),r.push(0,0,1),a.push(S.x,S.y)}for(let m=0,p=x.length;m<p;m++){let S=x[m],A=S[0]+f,v=S[1]+f,b=S[2]+f;n.push(A,v,b),l+=3}}}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}toJSON(){let e=super.toJSON(),t=this.parameters.shapes;return Dd(t,e)}static fromJSON(e,t){let n=[];for(let s=0,r=e.shapes.length;s<r;s++){let a=t[e.shapes[s]];n.push(a)}return new i(n,e.curveSegments)}};function Dd(i,e){if(e.shapes=[],Array.isArray(i))for(let t=0,n=i.length;t<n;t++){let s=i[t];e.shapes.push(s.uuid)}else e.shapes.push(i.uuid);return e}var zn=class i extends wt{constructor(e=1,t=32,n=16,s=0,r=Math.PI*2,a=0,o=Math.PI){super(),this.type="SphereGeometry",this.parameters={radius:e,widthSegments:t,heightSegments:n,phiStart:s,phiLength:r,thetaStart:a,thetaLength:o},t=Math.max(3,Math.floor(t)),n=Math.max(2,Math.floor(n));let l=Math.min(a+o,Math.PI),c=0,h=[],f=new I,u=new I,d=[],g=[],x=[],m=[];for(let p=0;p<=n;p++){let S=[],A=p/n,v=a+A*o,b=e*Math.cos(v),E=Math.sqrt(e*e-b*b),C=0;p===0&&a===0?C=.5/t:p===n&&l===Math.PI&&(C=-.5/t);for(let y=0;y<=t;y++){let w=y/t,P=s+w*r;f.x=-E*Math.cos(P),f.y=b,f.z=E*Math.sin(P),g.push(f.x,f.y,f.z),u.copy(f).normalize(),x.push(u.x,u.y,u.z),m.push(w+C,1-A),S.push(c++)}h.push(S)}for(let p=0;p<n;p++)for(let S=0;S<t;S++){let A=h[p][S+1],v=h[p][S],b=h[p+1][S],E=h[p+1][S+1];(p!==0||a>0)&&d.push(A,v,E),(p!==n-1||l<Math.PI)&&d.push(v,b,E)}this.setIndex(d),this.setAttribute("position",new ft(g,3)),this.setAttribute("normal",new ft(x,3)),this.setAttribute("uv",new ft(m,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new i(e.radius,e.widthSegments,e.heightSegments,e.phiStart,e.phiLength,e.thetaStart,e.thetaLength)}};var zi=class i extends wt{constructor(e=1,t=.4,n=12,s=48,r=Math.PI*2,a=0,o=Math.PI*2){super(),this.type="TorusGeometry",this.parameters={radius:e,tube:t,radialSegments:n,tubularSegments:s,arc:r,thetaStart:a,thetaLength:o},n=Math.floor(n),s=Math.floor(s);let l=[],c=[],h=[],f=[],u=new I,d=new I,g=new I;for(let x=0;x<=n;x++){let m=a+x/n*o;for(let p=0;p<=s;p++){let S=p/s*r;d.x=(e+t*Math.cos(m))*Math.cos(S),d.y=(e+t*Math.cos(m))*Math.sin(S),d.z=t*Math.sin(m),c.push(d.x,d.y,d.z),u.x=e*Math.cos(S),u.y=e*Math.sin(S),g.subVectors(d,u).normalize(),h.push(g.x,g.y,g.z),f.push(p/s),f.push(x/n)}}for(let x=1;x<=n;x++)for(let m=1;m<=s;m++){let p=(s+1)*x+m-1,S=(s+1)*(x-1)+m-1,A=(s+1)*(x-1)+m,v=(s+1)*x+m;l.push(p,S,v),l.push(S,A,v)}this.setIndex(l),this.setAttribute("position",new ft(c,3)),this.setAttribute("normal",new ft(h,3)),this.setAttribute("uv",new ft(f,2))}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}static fromJSON(e){return new i(e.radius,e.tube,e.radialSegments,e.tubularSegments,e.arc,e.thetaStart,e.thetaLength)}};var ya=class i extends wt{constructor(e=new fa(new I(-1,-1,0),new I(-1,1,0),new I(1,1,0)),t=64,n=1,s=8,r=!1){super(),this.type="TubeGeometry",this.parameters={path:e,tubularSegments:t,radius:n,radialSegments:s,closed:r};let a=e.computeFrenetFrames(t,r);this.tangents=a.tangents,this.normals=a.normals,this.binormals=a.binormals;let o=new I,l=new I,c=new ue,h=new I,f=[],u=[],d=[],g=[];x(),this.setIndex(g),this.setAttribute("position",new ft(f,3)),this.setAttribute("normal",new ft(u,3)),this.setAttribute("uv",new ft(d,2));function x(){for(let A=0;A<t;A++)m(A);m(r===!1?t:0),S(),p()}function m(A){h=e.getPointAt(A/t,h);let v=a.normals[A],b=a.binormals[A];for(let E=0;E<=s;E++){let C=E/s*Math.PI*2,y=Math.sin(C),w=-Math.cos(C);l.x=w*v.x+y*b.x,l.y=w*v.y+y*b.y,l.z=w*v.z+y*b.z,l.normalize(),u.push(l.x,l.y,l.z),o.x=h.x+n*l.x,o.y=h.y+n*l.y,o.z=h.z+n*l.z,f.push(o.x,o.y,o.z)}}function p(){for(let A=1;A<=t;A++)for(let v=1;v<=s;v++){let b=(s+1)*(A-1)+(v-1),E=(s+1)*A+(v-1),C=(s+1)*A+v,y=(s+1)*(A-1)+v;g.push(b,E,y),g.push(E,C,y)}}function S(){for(let A=0;A<=t;A++)for(let v=0;v<=s;v++)c.x=A/t,c.y=v/s,d.push(c.x,c.y)}}copy(e){return super.copy(e),this.parameters=Object.assign({},e.parameters),this}toJSON(){let e=super.toJSON();return e.path=this.parameters.path.toJSON(),e}static fromJSON(e){return new i(new rl[e.path.type]().fromJSON(e.path),e.tubularSegments,e.radius,e.radialSegments,e.closed)}};function bs(i){let e={};for(let t in i){e[t]={};for(let n in i[t]){let s=i[t][n];if(Vh(s))s.isRenderTargetTexture?(ct("UniformsUtils: Textures of render targets cannot be cloned via cloneUniforms() or mergeUniforms()."),e[t][n]=null):e[t][n]=s.clone();else if(Array.isArray(s))if(Vh(s[0])){let r=[];for(let a=0,o=s.length;a<o;a++)r[a]=s[a].clone();e[t][n]=r}else e[t][n]=s.slice();else e[t][n]=s}}return e}function Mn(i){let e={};for(let t=0;t<i.length;t++){let n=bs(i[t]);for(let s in n)e[s]=n[s]}return e}function Vh(i){return i&&(i.isColor||i.isMatrix3||i.isMatrix4||i.isVector2||i.isVector3||i.isVector4||i.isTexture||i.isQuaternion)}function Nd(i){let e=[];for(let t=0;t<i.length;t++)e.push(i[t].clone());return e}function L0(i){let e=i.getRenderTarget();return e===null?i.outputColorSpace:e.isXRRenderTarget===!0?e.texture.colorSpace:St.workingColorSpace}var Hi={clone:bs,merge:Mn},Ud=`void main() {
	gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
}`,Fd=`void main() {
	gl_FragColor = vec4( 1.0, 0.0, 0.0, 1.0 );
}`,Ft=class extends Kn{constructor(e){super(),this.isShaderMaterial=!0,this.type="ShaderMaterial",this.defines={},this.uniforms={},this.uniformsGroups=[],this.vertexShader=Ud,this.fragmentShader=Fd,this.linewidth=1,this.wireframe=!1,this.wireframeLinewidth=1,this.fog=!1,this.lights=!1,this.clipping=!1,this.forceSinglePass=!0,this.extensions={clipCullDistance:!1,multiDraw:!1},this.defaultAttributeValues={color:[1,1,1],uv:[0,0],uv1:[0,0]},this.index0AttributeName=void 0,this.uniformsNeedUpdate=!1,this.glslVersion=null,e!==void 0&&this.setValues(e)}copy(e){return super.copy(e),this.fragmentShader=e.fragmentShader,this.vertexShader=e.vertexShader,this.uniforms=bs(e.uniforms),this.uniformsGroups=Nd(e.uniformsGroups),this.defines=Object.assign({},e.defines),this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this.fog=e.fog,this.lights=e.lights,this.clipping=e.clipping,this.extensions=Object.assign({},e.extensions),this.glslVersion=e.glslVersion,this.defaultAttributeValues=Object.assign({},e.defaultAttributeValues),this.index0AttributeName=e.index0AttributeName,this.uniformsNeedUpdate=e.uniformsNeedUpdate,this}toJSON(e){let t=super.toJSON(e);t.glslVersion=this.glslVersion,t.uniforms={};for(let s in this.uniforms){let a=this.uniforms[s].value;a&&a.isTexture?t.uniforms[s]={type:"t",value:a.toJSON(e).uuid}:a&&a.isColor?t.uniforms[s]={type:"c",value:a.getHex()}:a&&a.isVector2?t.uniforms[s]={type:"v2",value:a.toArray()}:a&&a.isVector3?t.uniforms[s]={type:"v3",value:a.toArray()}:a&&a.isVector4?t.uniforms[s]={type:"v4",value:a.toArray()}:a&&a.isMatrix3?t.uniforms[s]={type:"m3",value:a.toArray()}:a&&a.isMatrix4?t.uniforms[s]={type:"m4",value:a.toArray()}:t.uniforms[s]={value:a}}Object.keys(this.defines).length>0&&(t.defines=this.defines),t.vertexShader=this.vertexShader,t.fragmentShader=this.fragmentShader,t.lights=this.lights,t.clipping=this.clipping;let n={};for(let s in this.extensions)this.extensions[s]===!0&&(n[s]=!0);return Object.keys(n).length>0&&(t.extensions=n),t}fromJSON(e,t){if(super.fromJSON(e,t),e.uniforms!==void 0)for(let n in e.uniforms){let s=e.uniforms[n];switch(this.uniforms[n]={},s.type){case"t":this.uniforms[n].value=t[s.value]||null;break;case"c":this.uniforms[n].value=new it().setHex(s.value);break;case"v2":this.uniforms[n].value=new ue().fromArray(s.value);break;case"v3":this.uniforms[n].value=new I().fromArray(s.value);break;case"v4":this.uniforms[n].value=new Gt().fromArray(s.value);break;case"m3":this.uniforms[n].value=new dt().fromArray(s.value);break;case"m4":this.uniforms[n].value=new Rt().fromArray(s.value);break;default:this.uniforms[n].value=s.value}}if(e.defines!==void 0&&(this.defines=e.defines),e.vertexShader!==void 0&&(this.vertexShader=e.vertexShader),e.fragmentShader!==void 0&&(this.fragmentShader=e.fragmentShader),e.glslVersion!==void 0&&(this.glslVersion=e.glslVersion),e.extensions!==void 0)for(let n in e.extensions)this.extensions[n]=e.extensions[n];return e.lights!==void 0&&(this.lights=e.lights),e.clipping!==void 0&&(this.clipping=e.clipping),this}},dr=class extends Ft{constructor(e){super(e),this.isRawShaderMaterial=!0,this.type="RawShaderMaterial"}},Ln=class extends Kn{constructor(e){super(),this.isMeshStandardMaterial=!0,this.type="MeshStandardMaterial",this.defines={STANDARD:""},this.color=new it(16777215),this.roughness=1,this.metalness=0,this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.emissive=new it(0),this.emissiveIntensity=1,this.emissiveMap=null,this.bumpMap=null,this.bumpScale=1,this.normalMap=null,this.normalMapType=rc,this.normalScale=new ue(1,1),this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.roughnessMap=null,this.metalnessMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new Ni,this.envMapIntensity=1,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.flatShading=!1,this.fog=!0,this.setValues(e)}copy(e){return super.copy(e),this.defines={STANDARD:""},this.color.copy(e.color),this.roughness=e.roughness,this.metalness=e.metalness,this.map=e.map,this.lightMap=e.lightMap,this.lightMapIntensity=e.lightMapIntensity,this.aoMap=e.aoMap,this.aoMapIntensity=e.aoMapIntensity,this.emissive.copy(e.emissive),this.emissiveMap=e.emissiveMap,this.emissiveIntensity=e.emissiveIntensity,this.bumpMap=e.bumpMap,this.bumpScale=e.bumpScale,this.normalMap=e.normalMap,this.normalMapType=e.normalMapType,this.normalScale.copy(e.normalScale),this.displacementMap=e.displacementMap,this.displacementScale=e.displacementScale,this.displacementBias=e.displacementBias,this.roughnessMap=e.roughnessMap,this.metalnessMap=e.metalnessMap,this.alphaMap=e.alphaMap,this.envMap=e.envMap,this.envMapRotation.copy(e.envMapRotation),this.envMapIntensity=e.envMapIntensity,this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this.wireframeLinecap=e.wireframeLinecap,this.wireframeLinejoin=e.wireframeLinejoin,this.flatShading=e.flatShading,this.fog=e.fog,this}},Ma=class extends Ln{constructor(e){super(),this.isMeshPhysicalMaterial=!0,this.defines={STANDARD:"",PHYSICAL:""},this.type="MeshPhysicalMaterial",this.anisotropyRotation=0,this.anisotropyMap=null,this.clearcoatMap=null,this.clearcoatRoughness=0,this.clearcoatRoughnessMap=null,this.clearcoatNormalScale=new ue(1,1),this.clearcoatNormalMap=null,this.ior=1.5,Object.defineProperty(this,"reflectivity",{get:function(){return Mt(2.5*(this.ior-1)/(this.ior+1),0,1)},set:function(t){this.ior=(1+.4*t)/(1-.4*t)}}),this.iridescenceMap=null,this.iridescenceIOR=1.3,this.iridescenceThicknessRange=[100,400],this.iridescenceThicknessMap=null,this.sheenColor=new it(0),this.sheenColorMap=null,this.sheenRoughness=1,this.sheenRoughnessMap=null,this.transmissionMap=null,this.thickness=0,this.thicknessMap=null,this.attenuationDistance=1/0,this.attenuationColor=new it(1,1,1),this.specularIntensity=1,this.specularIntensityMap=null,this.specularColor=new it(1,1,1),this.specularColorMap=null,this._anisotropy=0,this._clearcoat=0,this._dispersion=0,this._iridescence=0,this._retroreflectivity=0,this._sheen=0,this._transmission=0,this.setValues(e)}get anisotropy(){return this._anisotropy}set anisotropy(e){this._anisotropy>0!=e>0&&this.version++,this._anisotropy=e}get clearcoat(){return this._clearcoat}set clearcoat(e){this._clearcoat>0!=e>0&&this.version++,this._clearcoat=e}get iridescence(){return this._iridescence}set iridescence(e){this._iridescence>0!=e>0&&this.version++,this._iridescence=e}get dispersion(){return this._dispersion}set dispersion(e){this._dispersion>0!=e>0&&this.version++,this._dispersion=e}get retroreflectivity(){return this._retroreflectivity}set retroreflectivity(e){this._retroreflectivity>0!=e>0&&this.version++,this._retroreflectivity=e}get sheen(){return this._sheen}set sheen(e){this._sheen>0!=e>0&&this.version++,this._sheen=e}get transmission(){return this._transmission}set transmission(e){this._transmission>0!=e>0&&this.version++,this._transmission=e}copy(e){return super.copy(e),this.defines={STANDARD:"",PHYSICAL:""},this.anisotropy=e.anisotropy,this.anisotropyRotation=e.anisotropyRotation,this.anisotropyMap=e.anisotropyMap,this.clearcoat=e.clearcoat,this.clearcoatMap=e.clearcoatMap,this.clearcoatRoughness=e.clearcoatRoughness,this.clearcoatRoughnessMap=e.clearcoatRoughnessMap,this.clearcoatNormalMap=e.clearcoatNormalMap,this.clearcoatNormalScale.copy(e.clearcoatNormalScale),this.dispersion=e.dispersion,this.ior=e.ior,this.iridescence=e.iridescence,this.iridescenceMap=e.iridescenceMap,this.iridescenceIOR=e.iridescenceIOR,this.iridescenceThicknessRange=[...e.iridescenceThicknessRange],this.iridescenceThicknessMap=e.iridescenceThicknessMap,this.retroreflectivity=e.retroreflectivity,this.sheen=e.sheen,this.sheenColor.copy(e.sheenColor),this.sheenColorMap=e.sheenColorMap,this.sheenRoughness=e.sheenRoughness,this.sheenRoughnessMap=e.sheenRoughnessMap,this.transmission=e.transmission,this.transmissionMap=e.transmissionMap,this.thickness=e.thickness,this.thicknessMap=e.thicknessMap,this.attenuationDistance=e.attenuationDistance,this.attenuationColor.copy(e.attenuationColor),this.specularIntensity=e.specularIntensity,this.specularIntensityMap=e.specularIntensityMap,this.specularColor.copy(e.specularColor),this.specularColorMap=e.specularColorMap,this}};var al=class extends Kn{constructor(e){super(),this.isMeshDepthMaterial=!0,this.type="MeshDepthMaterial",this.depthPacking=Mu,this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.wireframe=!1,this.wireframeLinewidth=1,this.setValues(e)}copy(e){return super.copy(e),this.depthPacking=e.depthPacking,this.map=e.map,this.alphaMap=e.alphaMap,this.displacementMap=e.displacementMap,this.displacementScale=e.displacementScale,this.displacementBias=e.displacementBias,this.wireframe=e.wireframe,this.wireframeLinewidth=e.wireframeLinewidth,this}},ol=class extends Kn{constructor(e){super(),this.isMeshDistanceMaterial=!0,this.type="MeshDistanceMaterial",this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.setValues(e)}copy(e){return super.copy(e),this.map=e.map,this.alphaMap=e.alphaMap,this.displacementMap=e.displacementMap,this.displacementScale=e.displacementScale,this.displacementBias=e.displacementBias,this}};var Sa=class extends jn{constructor(e){super(),this.isLineDashedMaterial=!0,this.type="LineDashedMaterial",this.scale=1,this.dashSize=3,this.gapSize=1,this.setValues(e)}copy(e){return super.copy(e),this.scale=e.scale,this.dashSize=e.dashSize,this.gapSize=e.gapSize,this}};function Xs(i,e){return!i||i.constructor===e?i:typeof e.BYTES_PER_ELEMENT=="number"?new e(i):Array.prototype.slice.call(i)}function t0(i){return i!==void 0&&i.inTangents!==void 0&&i.outTangents!==void 0}var Ki=class{constructor(e,t,n,s){this.parameterPositions=e,this._cachedIndex=0,this.resultBuffer=s!==void 0?s:new t.constructor(n),this.sampleValues=t,this.valueSize=n,this.settings=null,this.DefaultSettings_={}}evaluate(e){let t=this.parameterPositions,n=this._cachedIndex,s=t[n],r=t[n-1];n:{e:{let a;t:{i:if(!(e<s)){for(let o=n+2;;){if(s===void 0){if(e<r)break i;return n=t.length,this._cachedIndex=n,this.copySampleValue_(n-1)}if(n===o)break;if(r=s,s=t[++n],e<s)break e}a=t.length;break t}if(!(e>=r)){let o=t[1];e<o&&(n=2,r=o);for(let l=n-2;;){if(r===void 0)return this._cachedIndex=0,this.copySampleValue_(0);if(n===l)break;if(s=r,r=t[--n-1],e>=r)break e}a=n,n=0;break t}break n}for(;n<a;){let o=n+a>>>1;e<t[o]?a=o:n=o+1}if(s=t[n],r=t[n-1],r===void 0)return this._cachedIndex=0,this.copySampleValue_(0);if(s===void 0)return n=t.length,this._cachedIndex=n,this.copySampleValue_(n-1)}this._cachedIndex=n,this.intervalChanged_(n,r,s)}return this.interpolate_(n,r,e,s)}getSettings_(){return this.settings||this.DefaultSettings_}copySampleValue_(e){let t=this.resultBuffer,n=this.sampleValues,s=this.valueSize,r=e*s;for(let a=0;a!==s;++a)t[a]=n[r+a];return t}interpolate_(){throw new Error("THREE.Interpolant: Call to abstract method.")}intervalChanged_(){}},ll=class extends Ki{constructor(e,t,n,s){super(e,t,n,s),this._weightPrev=-0,this._offsetPrev=-0,this._weightNext=-0,this._offsetNext=-0,this.DefaultSettings_={endingStart:s0,endingEnd:s0}}intervalChanged_(e,t,n){let s=this.parameterPositions,r=e-2,a=e+1,o=s[r],l=s[a];if(o===void 0)switch(this.getSettings_().endingStart){case r0:r=e,o=2*t-n;break;case a0:r=s.length-2,o=t+s[r]-s[r+1];break;default:r=e,o=n}if(l===void 0)switch(this.getSettings_().endingEnd){case r0:a=e,l=2*n-t;break;case a0:a=1,l=n+s[1]-s[0];break;default:a=e-1,l=t}let c=(n-t)*.5,h=this.valueSize;this._weightPrev=c/(t-o),this._weightNext=c/(l-n),this._offsetPrev=r*h,this._offsetNext=a*h}interpolate_(e,t,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,l=e*o,c=l-o,h=this._offsetPrev,f=this._offsetNext,u=this._weightPrev,d=this._weightNext,g=(n-t)/(s-t),x=g*g,m=x*g,p=-u*m+2*u*x-u*g,S=(1+u)*m+(-1.5-2*u)*x+(-.5+u)*g+1,A=(-1-d)*m+(1.5+d)*x+.5*g,v=d*m-d*x;for(let b=0;b!==o;++b)r[b]=p*a[h+b]+S*a[c+b]+A*a[l+b]+v*a[f+b];return r}},cl=class extends Ki{constructor(e,t,n,s){super(e,t,n,s)}interpolate_(e,t,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,l=e*o,c=l-o,h=(n-t)/(s-t),f=1-h;for(let u=0;u!==o;++u)r[u]=a[c+u]*f+a[l+u]*h;return r}},hl=class extends Ki{constructor(e,t,n,s){super(e,t,n,s)}interpolate_(e){return this.copySampleValue_(e-1)}},ul=class extends Ki{interpolate_(e,t,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,l=e*o,c=l-o,h=this.inTangents,f=this.outTangents;if(!h||!f){let g=(n-t)/(s-t),x=1-g;for(let m=0;m!==o;++m)r[m]=a[c+m]*x+a[l+m]*g;return r}let u=o*2,d=e-1;for(let g=0;g!==o;++g){let x=a[c+g],m=a[l+g],p=d*u+g*2,S=f[p],A=f[p+1],v=e*u+g*2,b=h[v],E=h[v+1],C=Bd(n,t,S,b,s);r[g]=Hu(C,x,A,E,m)}return r}};function Hu(i,e,t,n,s){let r=1-i;return r*r*r*e+3*r*r*i*t+3*r*i*i*n+i*i*i*s}function Od(i,e,t,n,s){let r=1-i;return 3*r*r*(t-e)+6*r*i*(n-t)+3*i*i*(s-n)}function Bd(i,e,t,n,s){let r=(i-e)/(s-e);for(let a=0;a<8;a++){let o=Hu(r,e,t,n,s)-i;if(Math.abs(o)<1e-10)break;let l=Od(r,e,t,n,s);if(Math.abs(l)<1e-10)break;r=Math.max(0,Math.min(1,r-o/l))}return r}var Dn=class{constructor(e,t,n,s){if(e===void 0)throw new Error("THREE.KeyframeTrack: track name is undefined");if(t===void 0||t.length===0)throw new Error("THREE.KeyframeTrack: no keyframes in track named "+e);this.name=e,this.times=Xs(t,this.TimeBufferType),this.values=Xs(n,this.ValueBufferType),this.setInterpolation(s||this.DefaultInterpolation)}static toJSON(e){let t=e.constructor,n;if(t.toJSON!==this.toJSON)n=t.toJSON(e);else{n={name:e.name,times:Xs(e.times,Array),values:Xs(e.values,Array)};let s=e.getInterpolation();s!==e.DefaultInterpolation&&(n.interpolation=s),t0(e.settings)&&(n.settings={inTangents:Xs(e.settings.inTangents,Array),outTangents:Xs(e.settings.outTangents,Array)})}return n.type=e.ValueTypeName,n}InterpolantFactoryMethodDiscrete(e){return new hl(this.times,this.values,this.getValueSize(),e)}InterpolantFactoryMethodLinear(e){return new cl(this.times,this.values,this.getValueSize(),e)}InterpolantFactoryMethodSmooth(e){return new ll(this.times,this.values,this.getValueSize(),e)}InterpolantFactoryMethodBezier(e){let t=new ul(this.times,this.values,this.getValueSize(),e);return this.settings&&(t.inTangents=this.settings.inTangents,t.outTangents=this.settings.outTangents),t}setInterpolation(e){let t;switch(e){case qr:t=this.InterpolantFactoryMethodDiscrete;break;case Yo:t=this.InterpolantFactoryMethodLinear;break;case Fo:t=this.InterpolantFactoryMethodSmooth;break;case i0:t=this.InterpolantFactoryMethodBezier;break}if(t===void 0){let n="unsupported interpolation for "+this.ValueTypeName+" keyframe track named "+this.name;if(this.createInterpolant===void 0)if(e!==this.DefaultInterpolation)this.setInterpolation(this.DefaultInterpolation);else throw new Error(n);return ct("KeyframeTrack:",n),this}return this.createInterpolant=t,this}getInterpolation(){switch(this.createInterpolant){case this.InterpolantFactoryMethodDiscrete:return qr;case this.InterpolantFactoryMethodLinear:return Yo;case this.InterpolantFactoryMethodSmooth:return Fo;case this.InterpolantFactoryMethodBezier:return i0}}getValueSize(){return this.values.length/this.times.length}shift(e){if(e!==0){let t=this.times;for(let n=0,s=t.length;n!==s;++n)t[n]+=e}return this}scale(e){if(e!==1){let t=this.times;for(let n=0,s=t.length;n!==s;++n)t[n]*=e;t0(this.settings)&&(Gh(this.settings.inTangents,e),Gh(this.settings.outTangents,e))}return this}trim(e,t){let n=this.times,s=n.length,r=0,a=s-1;for(;r!==s&&n[r]<e;)++r;for(;a!==-1&&n[a]>t;)--a;if(++a,r!==0||a!==s){r>=a&&(a=Math.max(a,1),r=a-1);let o=this.getValueSize();this.times=n.slice(r,a),this.values=this.values.slice(r*o,a*o)}return this}validate(){let e=!0,t=this.getValueSize();t-Math.floor(t)!==0&&(lt("KeyframeTrack: Invalid value size in track.",this),e=!1);let n=this.times,s=this.values,r=n.length;r===0&&(lt("KeyframeTrack: Track is empty.",this),e=!1);let a=null;for(let o=0;o!==r;o++){let l=n[o];if(typeof l=="number"&&isNaN(l)){lt("KeyframeTrack: Time is not a valid number.",this,o,l),e=!1;break}if(a!==null&&a>l){lt("KeyframeTrack: Out of order keys.",this,o,l,a),e=!1;break}a=l}if(s!==void 0&&Hf(s))for(let o=0,l=s.length;o!==l;++o){let c=s[o];if(isNaN(c)){lt("KeyframeTrack: Value is not a valid number.",this,o,c),e=!1;break}}return e}optimize(){let e=this.times.slice(),t=this.values.slice(),n=this.getValueSize(),s=this.getInterpolation()===Fo,r=e.length-1,a=1;for(let o=1;o<r;++o){let l=!1,c=e[o],h=e[o+1];if(c!==h&&(o!==1||c!==e[0]))if(s)l=!0;else{let f=o*n,u=f-n,d=f+n;for(let g=0;g!==n;++g){let x=t[f+g];if(x!==t[u+g]||x!==t[d+g]){l=!0;break}}}if(l){if(o!==a){e[a]=e[o];let f=o*n,u=a*n;for(let d=0;d!==n;++d)t[u+d]=t[f+d]}++a}}if(r>0){e[a]=e[r];for(let o=r*n,l=a*n,c=0;c!==n;++c)t[l+c]=t[o+c];++a}return a!==e.length?(this.times=e.slice(0,a),this.values=t.slice(0,a*n)):(this.times=e,this.values=t),this}clone(){let e=this.times.slice(),t=this.values.slice(),n=this.constructor,s=new n(this.name,e,t);return s.createInterpolant=this.createInterpolant,t0(this.settings)&&(s.settings={inTangents:this.settings.inTangents.slice(),outTangents:this.settings.outTangents.slice()}),s}};function Gh(i,e){for(let t=0,n=i.length;t!==n;t+=2)i[t]*=e}Dn.prototype.ValueTypeName="";Dn.prototype.TimeBufferType=Float32Array;Dn.prototype.ValueBufferType=Float32Array;Dn.prototype.DefaultInterpolation=Yo;var ji=class extends Dn{constructor(e,t,n){super(e,t,n)}};ji.prototype.ValueTypeName="bool";ji.prototype.ValueBufferType=Array;ji.prototype.DefaultInterpolation=qr;ji.prototype.InterpolantFactoryMethodLinear=void 0;ji.prototype.InterpolantFactoryMethodSmooth=void 0;var fl=class extends Dn{constructor(e,t,n,s){super(e,t,n,s)}};fl.prototype.ValueTypeName="color";var dl=class extends Dn{constructor(e,t,n,s){super(e,t,n,s)}};dl.prototype.ValueTypeName="number";var pl=class extends Ki{constructor(e,t,n,s){super(e,t,n,s)}interpolate_(e,t,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,l=(n-t)/(s-t),c=e*o;for(let h=c+o;c!==h;c+=4)mi.slerpFlat(r,0,a,c-o,a,c,l);return r}},ba=class extends Dn{constructor(e,t,n,s){super(e,t,n,s)}InterpolantFactoryMethodLinear(e){return new pl(this.times,this.values,this.getValueSize(),e)}};ba.prototype.ValueTypeName="quaternion";ba.prototype.InterpolantFactoryMethodSmooth=void 0;var Qi=class extends Dn{constructor(e,t,n){super(e,t,n)}};Qi.prototype.ValueTypeName="string";Qi.prototype.ValueBufferType=Array;Qi.prototype.DefaultInterpolation=qr;Qi.prototype.InterpolantFactoryMethodLinear=void 0;Qi.prototype.InterpolantFactoryMethodSmooth=void 0;var ml=class extends Dn{constructor(e,t,n,s){super(e,t,n,s)}};ml.prototype.ValueTypeName="vector";var Bo={enabled:!1,files:{},add:function(i,e){this.enabled!==!1&&(Wh(i)||(this.files[i]=e))},get:function(i){if(this.enabled!==!1&&!Wh(i))return this.files[i]},remove:function(i){delete this.files[i]},clear:function(){this.files={}}};function Wh(i){try{let e=i.slice(i.indexOf(":")+1);return new URL(e).protocol==="blob:"}catch{return!1}}var gl=class{constructor(e,t,n){let s=this,r=!1,a=0,o=0,l,c=[];this.onStart=void 0,this.onLoad=e,this.onProgress=t,this.onError=n,this._abortController=null,this.itemStart=function(h){o++,r===!1&&s.onStart!==void 0&&s.onStart(h,a,o),r=!0},this.itemEnd=function(h){a++,s.onProgress!==void 0&&s.onProgress(h,a,o),a===o&&(r=!1,s.onLoad!==void 0&&s.onLoad())},this.itemError=function(h){s.onError!==void 0&&s.onError(h)},this.resolveURL=function(h){return h=h.normalize("NFC"),l?l(h):h},this.setURLModifier=function(h){return l=h,this},this.addHandler=function(h,f){return c.push(h,f),this},this.removeHandler=function(h){let f=c.indexOf(h);return f!==-1&&c.splice(f,2),this},this.getHandler=function(h){for(let f=0,u=c.length;f<u;f+=2){let d=c[f],g=c[f+1];if(d.global&&(d.lastIndex=0),d.test(h))return g}return null},this.abort=function(){return this.abortController.abort(),this._abortController=null,this}}get abortController(){return this._abortController||(this._abortController=new AbortController),this._abortController}},ku=new gl,pr=class{constructor(e){this.manager=e!==void 0?e:ku,this.crossOrigin="anonymous",this.withCredentials=!1,this.path="",this.resourcePath="",this.requestHeader={},typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}load(){}loadAsync(e,t){let n=this;return new Promise(function(s,r){n.load(e,s,t,r)})}parse(){}setCrossOrigin(e){return this.crossOrigin=e,this}setWithCredentials(e){return this.withCredentials=e,this}setPath(e){return this.path=e,this}setResourcePath(e){return this.resourcePath=e,this}setRequestHeader(e){return this.requestHeader=e,this}abort(){return this}};pr.DEFAULT_MATERIAL_NAME="__DEFAULT";var qs=new WeakMap,_l=class extends pr{constructor(e){super(e)}load(e,t,n,s){this.path!==void 0&&(e=this.path+e),e=this.manager.resolveURL(e);let r=this,a=Bo.get(`image:${e}`);if(a!==void 0){if(a.complete===!0)r.manager.itemStart(e),setTimeout(function(){t&&t(a),r.manager.itemEnd(e)},0);else{let f=qs.get(a);f===void 0&&(f=[],qs.set(a,f)),f.push({onLoad:t,onError:s})}return a}let o=js("img");function l(){h(),t&&t(this);let f=qs.get(this)||[];for(let u=0;u<f.length;u++){let d=f[u];d.onLoad&&d.onLoad(this)}qs.delete(this),r.manager.itemEnd(e)}function c(f){h(),s&&s(f),Bo.remove(`image:${e}`);let u=qs.get(this)||[];for(let d=0;d<u.length;d++){let g=u[d];g.onError&&g.onError(f)}qs.delete(this),r.manager.itemError(e),r.manager.itemEnd(e)}function h(){o.removeEventListener("load",l,!1),o.removeEventListener("error",c,!1)}return o.addEventListener("load",l,!1),o.addEventListener("error",c,!1),e.slice(0,5)!=="data:"&&this.crossOrigin!==void 0&&(o.crossOrigin=this.crossOrigin),Bo.add(`image:${e}`,o),r.manager.itemStart(e),o.src=e,o}};var Ea=class extends pr{constructor(e){super(e)}load(e,t,n,s){let r=new fn,a=new _l(this.manager);return a.setCrossOrigin(this.crossOrigin),a.setPath(this.path),a.load(e,function(o){r.image=o,r.needsUpdate=!0,t!==void 0&&t(r)},n,s),r}},mr=class extends Qt{constructor(e,t=1){super(),this.isLight=!0,this.type="Light",this.color=new it(e),this.intensity=t}copy(e,t){return super.copy(e,t),this.color.copy(e.color),this.intensity=e.intensity,this}toJSON(e){let t=super.toJSON(e);return t.object.color=this.color.getHex(),t.object.intensity=this.intensity,t}},Ta=class extends mr{constructor(e,t,n){super(e,n),this.isHemisphereLight=!0,this.type="HemisphereLight",this.position.copy(Qt.DEFAULT_UP),this.updateMatrix(),this.groundColor=new it(t)}copy(e,t){return super.copy(e,t),this.groundColor.copy(e.groundColor),this}toJSON(e){let t=super.toJSON(e);return t.object.groundColor=this.groundColor.getHex(),t}},n0=new Rt,Xh=new I,qh=new I,wa=class{constructor(e){this.camera=e,this.intensity=1,this.bias=0,this.biasNode=null,this.normalBias=0,this.radius=1,this.blurSamples=8,this.mapSize=new ue(512,512),this.mapType=Rn,this.map=null,this.mapPass=null,this.matrix=new Rt,this.autoUpdate=!0,this.needsUpdate=!1,this._frustum=new rr,this._frameExtents=new ue(1,1),this._viewportCount=1,this._viewports=[new Gt(0,0,1,1)]}getViewportCount(){return this._viewportCount}getCamera(){return this.camera}getFrustum(){return this._frustum}updateMatrices(e){let t=this.camera;Xh.setFromMatrixPosition(e.matrixWorld),t.position.copy(Xh),qh.setFromMatrixPosition(e.target.matrixWorld),t.lookAt(qh),t.updateMatrixWorld(),this._updateMatrix(t,this.matrix,this._frustum)}_updateMatrix(e,t,n,s){n0.multiplyMatrices(e.projectionMatrix,e.matrixWorldInverse),n.setFromProjectionMatrix(n0,e.coordinateSystem,e.reversedDepth);let r=this._frameExtents,a=s?s.z/r.x:1,o=s?s.w/r.y:1,l=s?s.x/r.x:0,c=s?s.y/r.y:0;e.coordinateSystem===Ks||e.reversedDepth?t.set(.5*a,0,0,.5*a+l,0,.5*o,0,.5*o+c,0,0,1,0,0,0,0,1):t.set(.5*a,0,0,.5*a+l,0,.5*o,0,.5*o+c,0,0,.5,.5,0,0,0,1),t.multiply(n0)}getViewport(e){return this._viewports[e]}getFrameExtents(){return this._frameExtents}dispose(){this.map&&this.map.dispose(),this.mapPass&&this.mapPass.dispose()}copy(e){return this.camera=e.camera.clone(),this.intensity=e.intensity,this.bias=e.bias,this.radius=e.radius,this.autoUpdate=e.autoUpdate,this.needsUpdate=e.needsUpdate,this.normalBias=e.normalBias,this.blurSamples=e.blurSamples,this.mapSize.copy(e.mapSize),this.biasNode=e.biasNode,this}clone(){return new this.constructor().copy(this)}toJSON(){let e={};return e.intensity=this.intensity,e.bias=this.bias,e.normalBias=this.normalBias,e.radius=this.radius,e.blurSamples=this.blurSamples,e.mapSize=this.mapSize.toArray(),e.camera=this.camera.toJSON(!1).object,delete e.camera.matrix,e}},No=new I,Uo=new mi,ci=new I,Aa=class extends Qt{constructor(){super(),this.isCamera=!0,this.type="Camera",this.matrixWorldInverse=new Rt,this.projectionMatrix=new Rt,this.projectionMatrixInverse=new Rt,this.coordinateSystem=Jn,this._reversedDepth=!1}get reversedDepth(){return this._reversedDepth}copy(e,t){return super.copy(e,t),this.matrixWorldInverse.copy(e.matrixWorldInverse),this.projectionMatrix.copy(e.projectionMatrix),this.projectionMatrixInverse.copy(e.projectionMatrixInverse),this.coordinateSystem=e.coordinateSystem,this}getWorldDirection(e){return super.getWorldDirection(e).negate()}updateMatrixWorld(e){super.updateMatrixWorld(e),this.matrixWorld.decompose(No,Uo,ci),ci.x===1&&ci.y===1&&ci.z===1?this.matrixWorldInverse.copy(this.matrixWorld).invert():this.matrixWorldInverse.compose(No,Uo,ci.set(1,1,1)).invert()}updateWorldMatrix(e,t,n=!1){super.updateWorldMatrix(e,t,n),this.matrixWorld.decompose(No,Uo,ci),ci.x===1&&ci.y===1&&ci.z===1?this.matrixWorldInverse.copy(this.matrixWorld).invert():this.matrixWorldInverse.compose(No,Uo,ci.set(1,1,1)).invert()}clone(){return new this.constructor().copy(this)}},qi=new I,Yh=new ue,$h=new ue,mn=class extends Aa{constructor(e=50,t=1,n=.1,s=2e3){super(),this.isPerspectiveCamera=!0,this.type="PerspectiveCamera",this.fov=e,this.zoom=1,this.near=n,this.far=s,this.focus=10,this.aspect=t,this.view=null,this.filmGauge=35,this.filmOffset=0,this.updateProjectionMatrix()}copy(e,t){return super.copy(e,t),this.fov=e.fov,this.zoom=e.zoom,this.near=e.near,this.far=e.far,this.focus=e.focus,this.aspect=e.aspect,this.view=e.view===null?null:Object.assign({},e.view),this.filmGauge=e.filmGauge,this.filmOffset=e.filmOffset,this}setFocalLength(e){let t=.5*this.getFilmHeight()/e;this.fov=$o*2*Math.atan(t),this.updateProjectionMatrix()}getFocalLength(){let e=Math.tan(Cc*.5*this.fov);return .5*this.getFilmHeight()/e}getEffectiveFOV(){return $o*2*Math.atan(Math.tan(Cc*.5*this.fov)/this.zoom)}getFilmWidth(){return this.filmGauge*Math.min(this.aspect,1)}getFilmHeight(){return this.filmGauge/Math.max(this.aspect,1)}getViewBounds(e,t,n){qi.set(-1,-1,.5).applyMatrix4(this.projectionMatrixInverse),t.set(qi.x,qi.y).multiplyScalar(-e/qi.z),qi.set(1,1,.5).applyMatrix4(this.projectionMatrixInverse),n.set(qi.x,qi.y).multiplyScalar(-e/qi.z)}getViewSize(e,t){return this.getViewBounds(e,Yh,$h),t.subVectors($h,Yh)}setViewOffset(e,t,n,s,r,a){this.aspect=e/t,this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=e,this.view.fullHeight=t,this.view.offsetX=n,this.view.offsetY=s,this.view.width=r,this.view.height=a,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){let e=this.near,t=e*Math.tan(Cc*.5*this.fov)/this.zoom,n=2*t,s=this.aspect*n,r=-.5*s,a=this.view;if(this.view!==null&&this.view.enabled){let l=a.fullWidth,c=a.fullHeight;r+=a.offsetX*s/l,t-=a.offsetY*n/c,s*=a.width/l,n*=a.height/c}let o=this.filmOffset;o!==0&&(r+=e*o/this.getFilmWidth()),this.projectionMatrix.makePerspective(r,r+s,t,t-n,e,this.far,this.coordinateSystem,this.reversedDepth),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(e){let t=super.toJSON(e);return t.object.fov=this.fov,t.object.zoom=this.zoom,t.object.near=this.near,t.object.far=this.far,t.object.focus=this.focus,t.object.aspect=this.aspect,this.view!==null&&(t.object.view=Object.assign({},this.view)),t.object.filmGauge=this.filmGauge,t.object.filmOffset=this.filmOffset,t}};var u0=class extends wa{constructor(){super(new mn(90,1,.5,500)),this.isPointLightShadow=!0}},Ra=class extends mr{constructor(e,t,n=0,s=2){super(e,t),this.isPointLight=!0,this.type="PointLight",this.distance=n,this.decay=s,this.shadow=new u0}get power(){return this.intensity*4*Math.PI}set power(e){this.intensity=e/(4*Math.PI)}dispose(){super.dispose(),this.shadow.dispose()}copy(e,t){return super.copy(e,t),this.distance=e.distance,this.decay=e.decay,this.shadow=e.shadow.clone(),this}toJSON(e){let t=super.toJSON(e);return t.object.distance=this.distance,t.object.decay=this.decay,t.object.shadow=this.shadow.toJSON(),t}},es=class extends Aa{constructor(e=-1,t=1,n=1,s=-1,r=.1,a=2e3){super(),this.isOrthographicCamera=!0,this.type="OrthographicCamera",this.zoom=1,this.view=null,this.left=e,this.right=t,this.top=n,this.bottom=s,this.near=r,this.far=a,this.updateProjectionMatrix()}copy(e,t){return super.copy(e,t),this.left=e.left,this.right=e.right,this.top=e.top,this.bottom=e.bottom,this.near=e.near,this.far=e.far,this.zoom=e.zoom,this.view=e.view===null?null:Object.assign({},e.view),this}setViewOffset(e,t,n,s,r,a){this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=e,this.view.fullHeight=t,this.view.offsetX=n,this.view.offsetY=s,this.view.width=r,this.view.height=a,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){let e=(this.right-this.left)/(2*this.zoom),t=(this.top-this.bottom)/(2*this.zoom),n=(this.right+this.left)/2,s=(this.top+this.bottom)/2,r=n-e,a=n+e,o=s+t,l=s-t;if(this.view!==null&&this.view.enabled){let c=(this.right-this.left)/this.view.fullWidth/this.zoom,h=(this.top-this.bottom)/this.view.fullHeight/this.zoom;r+=c*this.view.offsetX,a=r+c*this.view.width,o-=h*this.view.offsetY,l=o-h*this.view.height}this.projectionMatrix.makeOrthographic(r,a,o,l,this.near,this.far,this.coordinateSystem,this.reversedDepth),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(e){let t=super.toJSON(e);return t.object.zoom=this.zoom,t.object.left=this.left,t.object.right=this.right,t.object.top=this.top,t.object.bottom=this.bottom,t.object.near=this.near,t.object.far=this.far,this.view!==null&&(t.object.view=Object.assign({},this.view)),t}},f0=class extends wa{constructor(){super(new es(-5,5,5,-5,.5,500)),this.isDirectionalLightShadow=!0}},gr=class extends mr{constructor(e,t){super(e,t),this.isDirectionalLight=!0,this.type="DirectionalLight",this.position.copy(Qt.DEFAULT_UP),this.updateMatrix(),this.target=new Qt,this.shadow=new f0}dispose(){super.dispose(),this.shadow.dispose()}copy(e){return super.copy(e),this.target=e.target.clone(),this.shadow=e.shadow.clone(),this}toJSON(e){let t=super.toJSON(e);return t.object.shadow=this.shadow.toJSON(),t.object.target=this.target.uuid,t}};var Ys=-90,$s=1,xl=class extends Qt{constructor(e,t,n){super(),this.type="CubeCamera",this.renderTarget=n,this.coordinateSystem=null,this.activeMipmapLevel=0;let s=new mn(Ys,$s,e,t);s.layers=this.layers,this.add(s);let r=new mn(Ys,$s,e,t);r.layers=this.layers,this.add(r);let a=new mn(Ys,$s,e,t);a.layers=this.layers,this.add(a);let o=new mn(Ys,$s,e,t);o.layers=this.layers,this.add(o);let l=new mn(Ys,$s,e,t);l.layers=this.layers,this.add(l);let c=new mn(Ys,$s,e,t);c.layers=this.layers,this.add(c)}updateCoordinateSystem(){let e=this.coordinateSystem,t=this.children.concat(),[n,s,r,a,o,l]=t;for(let c of t)this.remove(c);if(e===Jn)n.up.set(0,1,0),n.lookAt(1,0,0),s.up.set(0,1,0),s.lookAt(-1,0,0),r.up.set(0,0,-1),r.lookAt(0,1,0),a.up.set(0,0,1),a.lookAt(0,-1,0),o.up.set(0,1,0),o.lookAt(0,0,1),l.up.set(0,1,0),l.lookAt(0,0,-1);else if(e===Ks)n.up.set(0,-1,0),n.lookAt(-1,0,0),s.up.set(0,-1,0),s.lookAt(1,0,0),r.up.set(0,0,1),r.lookAt(0,1,0),a.up.set(0,0,-1),a.lookAt(0,-1,0),o.up.set(0,-1,0),o.lookAt(0,0,1),l.up.set(0,-1,0),l.lookAt(0,0,-1);else throw new Error("THREE.CubeCamera.updateCoordinateSystem(): Invalid coordinate system: "+e);for(let c of t)this.add(c),c.updateMatrixWorld()}update(e,t){this.parent===null&&this.updateMatrixWorld();let{renderTarget:n,activeMipmapLevel:s}=this;this.coordinateSystem!==e.coordinateSystem&&(this.coordinateSystem=e.coordinateSystem,this.updateCoordinateSystem());let[r,a,o,l,c,h]=this.children,f=e.getRenderTarget(),u=e.getActiveCubeFace(),d=e.getActiveMipmapLevel(),g=e.xr.enabled;e.xr.enabled=!1;let x=n.texture.generateMipmaps;n.texture.generateMipmaps=!1;let m=!1;e.isWebGLRenderer===!0?m=e.state.buffers.depth.getReversed():m=e.reversedDepthBuffer,e.setRenderTarget(n,0,s),m&&e.autoClear===!1&&e.clearDepth(),e.render(t,r),e.setRenderTarget(n,1,s),m&&e.autoClear===!1&&e.clearDepth(),e.render(t,a),e.setRenderTarget(n,2,s),m&&e.autoClear===!1&&e.clearDepth(),e.render(t,o),e.setRenderTarget(n,3,s),m&&e.autoClear===!1&&e.clearDepth(),e.render(t,l),e.setRenderTarget(n,4,s),m&&e.autoClear===!1&&e.clearDepth(),e.render(t,c),n.texture.generateMipmaps=x,e.setRenderTarget(n,5,s),m&&e.autoClear===!1&&e.clearDepth(),e.render(t,h),e.setRenderTarget(f,u,d),e.xr.enabled=g,n.texture.needsPMREMUpdate=!0}},vl=class extends mn{constructor(e=[]){super(),this.isArrayCamera=!0,this.isMultiViewCamera=!1,this.cameras=e}},Ca=class{constructor(){this._previousTime=0,this._currentTime=0,this._startTime=performance.now(),this._delta=0,this._elapsed=0,this._timescale=1,this._document=null,this._pageVisibilityHandler=null}connect(e){this._document=e,e.hidden!==void 0&&(this._pageVisibilityHandler=zd.bind(this),e.addEventListener("visibilitychange",this._pageVisibilityHandler,!1))}disconnect(){this._pageVisibilityHandler!==null&&(this._document.removeEventListener("visibilitychange",this._pageVisibilityHandler),this._pageVisibilityHandler=null),this._document=null}getDelta(){return this._delta/1e3}getElapsed(){return this._elapsed/1e3}getTimescale(){return this._timescale}setTimescale(e){return this._timescale=e,this}reset(){return this._currentTime=performance.now()-this._startTime,this}dispose(){this.disconnect()}update(e){return this._pageVisibilityHandler!==null&&this._document.hidden===!0?this._delta=0:(this._previousTime=this._currentTime,this._currentTime=(e!==void 0?e:performance.now())-this._startTime,this._delta=(this._currentTime-this._previousTime)*this._timescale,this._elapsed+=this._delta),this}};function zd(){this._document.hidden===!1&&this.reset()}var D0="\\[\\]\\.:\\/",Hd=new RegExp("["+D0+"]","g"),N0="[^"+D0+"]",kd="[^"+D0.replace("\\.","")+"]",Vd=/((?:WC+[\/:])*)/.source.replace("WC",N0),Gd=/(WCOD+)?/.source.replace("WCOD",kd),Wd=/(?:\.(WC+)(?:\[(.+)\])?)?/.source.replace("WC",N0),Xd=/\.(WC+)(?:\[(.+)\])?/.source.replace("WC",N0),qd=new RegExp("^"+Vd+Gd+Wd+Xd+"$"),Yd=["material","materials","bones","map"],d0=class{constructor(e,t,n){let s=n||Vt.parseTrackName(t);this._targetGroup=e,this._bindings=e.subscribe_(t,s)}getValue(e,t){this.bind();let n=this._targetGroup.nCachedObjects_,s=this._bindings[n];s!==void 0&&s.getValue(e,t)}setValue(e,t){let n=this._bindings;for(let s=this._targetGroup.nCachedObjects_,r=n.length;s!==r;++s)n[s].setValue(e,t)}bind(){let e=this._bindings;for(let t=this._targetGroup.nCachedObjects_,n=e.length;t!==n;++t)e[t].bind()}unbind(){let e=this._bindings;for(let t=this._targetGroup.nCachedObjects_,n=e.length;t!==n;++t)e[t].unbind()}},Vt=class i{constructor(e,t,n){this.path=t,this.parsedPath=n||i.parseTrackName(t),this.node=i.findNode(e,this.parsedPath.nodeName),this.rootNode=e,this.getValue=this._getValue_unbound,this.setValue=this._setValue_unbound}static create(e,t,n){return e&&e.isAnimationObjectGroup?new i.Composite(e,t,n):new i(e,t,n)}static sanitizeNodeName(e){return e.replace(/\s/g,"_").replace(Hd,"")}static parseTrackName(e){let t=qd.exec(e);if(t===null)throw new Error("THREE.PropertyBinding: Cannot parse trackName: "+e);let n={nodeName:t[2],objectName:t[3],objectIndex:t[4],propertyName:t[5],propertyIndex:t[6]},s=n.nodeName&&n.nodeName.lastIndexOf(".");if(s!==void 0&&s!==-1){let r=n.nodeName.substring(s+1);Yd.indexOf(r)!==-1&&(n.nodeName=n.nodeName.substring(0,s),n.objectName=r)}if(n.propertyName===null||n.propertyName.length===0)throw new Error("THREE.PropertyBinding: can not parse propertyName from trackName: "+e);return n}static findNode(e,t){if(t===void 0||t===""||t==="."||t===-1||t===e.name||t===e.uuid)return e;if(e.skeleton){let n=e.skeleton.getBoneByName(t);if(n!==void 0)return n}if(e.children){let n=function(r){for(let a=0;a<r.length;a++){let o=r[a];if(o.name===t||o.uuid===t)return o;let l=n(o.children);if(l)return l}return null},s=n(e.children);if(s)return s}return null}_getValue_unavailable(){}_setValue_unavailable(){}_getValue_direct(e,t){e[t]=this.targetObject[this.propertyName]}_getValue_array(e,t){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)e[t++]=n[s]}_getValue_arrayElement(e,t){e[t]=this.resolvedProperty[this.propertyIndex]}_getValue_toArray(e,t){this.resolvedProperty.toArray(e,t)}_setValue_direct(e,t){this.targetObject[this.propertyName]=e[t]}_setValue_direct_setNeedsUpdate(e,t){this.targetObject[this.propertyName]=e[t],this.targetObject.needsUpdate=!0}_setValue_direct_setMatrixWorldNeedsUpdate(e,t){this.targetObject[this.propertyName]=e[t],this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_array(e,t){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)n[s]=e[t++]}_setValue_array_setNeedsUpdate(e,t){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)n[s]=e[t++];this.targetObject.needsUpdate=!0}_setValue_array_setMatrixWorldNeedsUpdate(e,t){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)n[s]=e[t++];this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_arrayElement(e,t){this.resolvedProperty[this.propertyIndex]=e[t]}_setValue_arrayElement_setNeedsUpdate(e,t){this.resolvedProperty[this.propertyIndex]=e[t],this.targetObject.needsUpdate=!0}_setValue_arrayElement_setMatrixWorldNeedsUpdate(e,t){this.resolvedProperty[this.propertyIndex]=e[t],this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_fromArray(e,t){this.resolvedProperty.fromArray(e,t)}_setValue_fromArray_setNeedsUpdate(e,t){this.resolvedProperty.fromArray(e,t),this.targetObject.needsUpdate=!0}_setValue_fromArray_setMatrixWorldNeedsUpdate(e,t){this.resolvedProperty.fromArray(e,t),this.targetObject.matrixWorldNeedsUpdate=!0}_getValue_unbound(e,t){this.bind(),this.getValue(e,t)}_setValue_unbound(e,t){this.bind(),this.setValue(e,t)}bind(){let e=this.node,t=this.parsedPath,n=t.objectName,s=t.propertyName,r=t.propertyIndex;if(e||(e=i.findNode(this.rootNode,t.nodeName),this.node=e),this.getValue=this._getValue_unavailable,this.setValue=this._setValue_unavailable,!e){ct("PropertyBinding: No target node found for track: "+this.path+".");return}if(n){let c=t.objectIndex;switch(n){case"materials":if(!e.material){lt("PropertyBinding: Can not bind to material as node does not have a material.",this);return}if(!e.material.materials){lt("PropertyBinding: Can not bind to material.materials as node.material does not have a materials array.",this);return}e=e.material.materials;break;case"bones":if(!e.skeleton){lt("PropertyBinding: Can not bind to bones as node does not have a skeleton.",this);return}e=e.skeleton.bones;for(let h=0;h<e.length;h++)if(e[h].name===c){c=h;break}break;case"map":if("map"in e){e=e.map;break}if(!e.material){lt("PropertyBinding: Can not bind to material as node does not have a material.",this);return}if(!e.material.map){lt("PropertyBinding: Can not bind to material.map as node.material does not have a map.",this);return}e=e.material.map;break;default:if(e[n]===void 0){lt("PropertyBinding: Can not bind to objectName of node undefined.",this);return}e=e[n]}if(c!==void 0){if(e[c]===void 0){lt("PropertyBinding: Trying to bind to objectIndex of objectName, but is undefined.",this,e);return}e=e[c]}}let a=e[s];if(a===void 0){let c=t.nodeName;lt("PropertyBinding: Trying to update property for track: "+c+"."+s+" but it wasn't found.",e);return}let o=this.Versioning.None;this.targetObject=e,e.isMaterial===!0?o=this.Versioning.NeedsUpdate:e.isObject3D===!0&&(o=this.Versioning.MatrixWorldNeedsUpdate);let l=this.BindingType.Direct;if(r!==void 0){if(s==="morphTargetInfluences"){if(!e.geometry){lt("PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.",this);return}if(!e.geometry.morphAttributes){lt("PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.morphAttributes.",this);return}e.morphTargetDictionary[r]!==void 0&&(r=e.morphTargetDictionary[r])}l=this.BindingType.ArrayElement,this.resolvedProperty=a,this.propertyIndex=r}else a.fromArray!==void 0&&a.toArray!==void 0?(l=this.BindingType.HasFromToArray,this.resolvedProperty=a):Array.isArray(a)?(l=this.BindingType.EntireArray,this.resolvedProperty=a):this.propertyName=s;this.getValue=this.GetterByBindingType[l],this.setValue=this.SetterByBindingTypeAndVersioning[l][o]}unbind(){this.node=null,this.getValue=this._getValue_unbound,this.setValue=this._setValue_unbound}};Vt.Composite=d0;Vt.prototype.BindingType={Direct:0,EntireArray:1,ArrayElement:2,HasFromToArray:3};Vt.prototype.Versioning={None:0,NeedsUpdate:1,MatrixWorldNeedsUpdate:2};Vt.prototype.GetterByBindingType=[Vt.prototype._getValue_direct,Vt.prototype._getValue_array,Vt.prototype._getValue_arrayElement,Vt.prototype._getValue_toArray];Vt.prototype.SetterByBindingTypeAndVersioning=[[Vt.prototype._setValue_direct,Vt.prototype._setValue_direct_setNeedsUpdate,Vt.prototype._setValue_direct_setMatrixWorldNeedsUpdate],[Vt.prototype._setValue_array,Vt.prototype._setValue_array_setNeedsUpdate,Vt.prototype._setValue_array_setMatrixWorldNeedsUpdate],[Vt.prototype._setValue_arrayElement,Vt.prototype._setValue_arrayElement_setNeedsUpdate,Vt.prototype._setValue_arrayElement_setMatrixWorldNeedsUpdate],[Vt.prototype._setValue_fromArray,Vt.prototype._setValue_fromArray_setNeedsUpdate,Vt.prototype._setValue_fromArray_setMatrixWorldNeedsUpdate]];var o3=new Float32Array(1);var Zh=new Rt,Pa=class{constructor(e,t,n=0,s=1/0){this.ray=new xs(e,t),this.near=n,this.far=s,this.camera=null,this.layers=new tr,this.params={Mesh:{},Line:{threshold:1},LOD:{},Points:{threshold:1},Sprite:{}}}set(e,t){this.ray.set(e,t)}setFromCamera(e,t){t.isPerspectiveCamera?(this.ray.origin.setFromMatrixPosition(t.matrixWorld),this.ray.direction.set(e.x,e.y,.5).unproject(t).sub(this.ray.origin).normalize(),this.camera=t):t.isOrthographicCamera?(this.ray.origin.set(e.x,e.y,t.projectionMatrix.elements[14]).unproject(t),this.ray.direction.set(0,0,-1).transformDirection(t.matrixWorld),this.camera=t):lt("Raycaster: Unsupported camera type: "+t.type)}setFromXRController(e){return Zh.identity().extractRotation(e.matrixWorld),this.ray.origin.setFromMatrixPosition(e.matrixWorld),this.ray.direction.set(0,0,-1).applyMatrix4(Zh),this}intersectObject(e,t=!0,n=[]){return p0(e,this,n,t),n.sort(Jh),n}intersectObjects(e,t=!0,n=[]){for(let s=0,r=e.length;s<r;s++)p0(e[s],this,n,t);return n.sort(Jh),n}};function Jh(i,e){return i.distance-e.distance}function p0(i,e,t,n){let s=!0;if(i.layers.test(e.layers)&&i.raycast(e,t)===!1&&(s=!1),s===!0&&n===!0){let r=i.children;for(let a=0,o=r.length;a<o;a++)p0(r[a],e,t,!0)}}var m0=class i{static{i.prototype.isMatrix2=!0}constructor(e,t,n,s){this.elements=[1,0,0,1],e!==void 0&&this.set(e,t,n,s)}identity(){return this.set(1,0,0,1),this}fromArray(e,t=0){for(let n=0;n<4;n++)this.elements[n]=e[n+t];return this}set(e,t,n,s){let r=this.elements;return r[0]=e,r[2]=t,r[1]=n,r[3]=s,this}};function U0(i,e,t,n){let s=$d(n);switch(t){case A0:return i*e;case Tl:return i*e/s.components*s.byteLength;case wl:return i*e/s.components*s.byteLength;case rs:return i*e*2/s.components*s.byteLength;case Al:return i*e*2/s.components*s.byteLength;case R0:return i*e*3/s.components*s.byteLength;case Vn:return i*e*4/s.components*s.byteLength;case Rl:return i*e*4/s.components*s.byteLength;case Ha:case ka:return Math.floor((i+3)/4)*Math.floor((e+3)/4)*8;case Va:case Ga:return Math.floor((i+3)/4)*Math.floor((e+3)/4)*16;case Pl:case Ll:return Math.max(i,16)*Math.max(e,8)/4;case Cl:case Il:return Math.max(i,8)*Math.max(e,8)/2;case Dl:case Nl:case Fl:case Ol:return Math.floor((i+3)/4)*Math.floor((e+3)/4)*8;case Ul:case Wa:case Bl:return Math.floor((i+3)/4)*Math.floor((e+3)/4)*16;case zl:return Math.floor((i+3)/4)*Math.floor((e+3)/4)*16;case Hl:return Math.floor((i+4)/5)*Math.floor((e+3)/4)*16;case kl:return Math.floor((i+4)/5)*Math.floor((e+4)/5)*16;case Vl:return Math.floor((i+5)/6)*Math.floor((e+4)/5)*16;case Gl:return Math.floor((i+5)/6)*Math.floor((e+5)/6)*16;case Wl:return Math.floor((i+7)/8)*Math.floor((e+4)/5)*16;case Xl:return Math.floor((i+7)/8)*Math.floor((e+5)/6)*16;case ql:return Math.floor((i+7)/8)*Math.floor((e+7)/8)*16;case Yl:return Math.floor((i+9)/10)*Math.floor((e+4)/5)*16;case $l:return Math.floor((i+9)/10)*Math.floor((e+5)/6)*16;case Zl:return Math.floor((i+9)/10)*Math.floor((e+7)/8)*16;case Jl:return Math.floor((i+9)/10)*Math.floor((e+9)/10)*16;case Kl:return Math.floor((i+11)/12)*Math.floor((e+9)/10)*16;case jl:return Math.floor((i+11)/12)*Math.floor((e+11)/12)*16;case Ql:case ec:case tc:return Math.ceil(i/4)*Math.ceil(e/4)*16;case nc:case ic:return Math.ceil(i/4)*Math.ceil(e/4)*8;case Xa:case sc:return Math.ceil(i/4)*Math.ceil(e/4)*16}throw new Error(`Unable to determine texture byte length for ${t} format.`)}function $d(i){switch(i){case Rn:case b0:return{byteLength:1,components:1};case vr:case E0:case sn:return{byteLength:2,components:1};case bl:case El:return{byteLength:2,components:4};case ei:case Sl:case kn:return{byteLength:4,components:1};case T0:case w0:return{byteLength:4,components:3}}throw new Error(`THREE.TextureUtils: Unknown texture type ${i}.`)}typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("register",{detail:{revision:"186"}}));typeof window<"u"&&(window.__THREE__?ct("WARNING: Multiple instances of Three.js being imported."):window.__THREE__="186");function hf(){let i=null,e=!1,t=null,n=null;function s(r,a){n=i.requestAnimationFrame(s),t(r,a)}return{start:function(){e!==!0&&t!==null&&i!==null&&(n=i.requestAnimationFrame(s),e=!0)},stop:function(){i!==null&&i.cancelAnimationFrame(n),e=!1},setAnimationLoop:function(r){t=r},setContext:function(r){i=r}}}function Qd(i){let e=new WeakMap;function t(o,l){let c=o.array,h=o.usage,f=c.byteLength,u=i.createBuffer();i.bindBuffer(l,u),i.bufferData(l,c,h),o.onUploadCallback();let d;if(c instanceof Float32Array)d=i.FLOAT;else if(typeof Float16Array<"u"&&c instanceof Float16Array)d=i.HALF_FLOAT;else if(c instanceof Uint16Array)o.isFloat16BufferAttribute?d=i.HALF_FLOAT:d=i.UNSIGNED_SHORT;else if(c instanceof Int16Array)d=i.SHORT;else if(c instanceof Uint32Array)d=i.UNSIGNED_INT;else if(c instanceof Int32Array)d=i.INT;else if(c instanceof Int8Array)d=i.BYTE;else if(c instanceof Uint8Array)d=i.UNSIGNED_BYTE;else if(c instanceof Uint8ClampedArray)d=i.UNSIGNED_BYTE;else throw new Error("THREE.WebGLAttributes: Unsupported buffer data format: "+c);return{buffer:u,type:d,bytesPerElement:c.BYTES_PER_ELEMENT,version:o.version,size:f}}function n(o,l,c){let h=l.array,f=l.updateRanges;if(i.bindBuffer(c,o),f.length===0)i.bufferSubData(c,0,h);else{f.sort((d,g)=>d.start-g.start);let u=0;for(let d=1;d<f.length;d++){let g=f[u],x=f[d];x.start<=g.start+g.count+1?g.count=Math.max(g.count,x.start+x.count-g.start):(++u,f[u]=x)}f.length=u+1;for(let d=0,g=f.length;d<g;d++){let x=f[d];i.bufferSubData(c,x.start*h.BYTES_PER_ELEMENT,h,x.start,x.count)}l.clearUpdateRanges()}l.onUploadCallback()}function s(o){return o.isInterleavedBufferAttribute&&(o=o.data),e.get(o)}function r(o){o.isInterleavedBufferAttribute&&(o=o.data);let l=e.get(o);l&&(i.deleteBuffer(l.buffer),e.delete(o))}function a(o,l){if(o.isInterleavedBufferAttribute&&(o=o.data),o.isGLBufferAttribute){let h=e.get(o);(!h||h.version<o.version)&&e.set(o,{buffer:o.buffer,type:o.type,bytesPerElement:o.elementSize,version:o.version});return}let c=e.get(o);if(c===void 0)e.set(o,t(o,l));else if(c.version<o.version){if(c.size!==o.array.byteLength)throw new Error("THREE.WebGLAttributes: The size of the buffer attribute's array buffer does not match the original size. Resizing buffer attributes is not supported.");n(c.buffer,o,l),c.version=o.version}}return{get:s,remove:r,update:a}}var ep=`#ifdef USE_ALPHAHASH
	if ( diffuseColor.a < getAlphaHashThreshold( vPosition ) ) discard;
#endif`,tp=`#ifdef USE_ALPHAHASH
	const float ALPHA_HASH_SCALE = 0.05;
	float hash2D( vec2 value ) {
		return fract( 1.0e4 * sin( 17.0 * value.x + 0.1 * value.y ) * ( 0.1 + abs( sin( 13.0 * value.y + value.x ) ) ) );
	}
	float hash3D( vec3 value ) {
		return hash2D( vec2( hash2D( value.xy ), value.z ) );
	}
	float getAlphaHashThreshold( vec3 position ) {
		float maxDeriv = max(
			length( dFdx( position.xyz ) ),
			length( dFdy( position.xyz ) )
		);
		float pixScale = 1.0 / ( ALPHA_HASH_SCALE * maxDeriv );
		vec2 pixScales = vec2(
			exp2( floor( log2( pixScale ) ) ),
			exp2( ceil( log2( pixScale ) ) )
		);
		vec2 alpha = vec2(
			hash3D( floor( pixScales.x * position.xyz ) ),
			hash3D( floor( pixScales.y * position.xyz ) )
		);
		float lerpFactor = fract( log2( pixScale ) );
		float x = ( 1.0 - lerpFactor ) * alpha.x + lerpFactor * alpha.y;
		float a = min( lerpFactor, 1.0 - lerpFactor );
		vec3 cases = vec3(
			x * x / ( 2.0 * a * ( 1.0 - a ) ),
			( x - 0.5 * a ) / ( 1.0 - a ),
			1.0 - ( ( 1.0 - x ) * ( 1.0 - x ) / ( 2.0 * a * ( 1.0 - a ) ) )
		);
		float threshold = ( x < ( 1.0 - a ) )
			? ( ( x < a ) ? cases.x : cases.y )
			: cases.z;
		return clamp( threshold , 1.0e-6, 1.0 );
	}
#endif`,np=`#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture2D( alphaMap, vAlphaMapUv ).g;
#endif`,ip=`#ifdef USE_ALPHAMAP
	uniform sampler2D alphaMap;
#endif`,sp=`#ifdef USE_ALPHATEST
	#ifdef ALPHA_TO_COVERAGE
	diffuseColor.a = smoothstep( alphaTest, alphaTest + fwidth( diffuseColor.a ), diffuseColor.a );
	if ( diffuseColor.a == 0.0 ) discard;
	#else
	if ( diffuseColor.a < alphaTest ) discard;
	#endif
#endif`,rp=`#ifdef USE_ALPHATEST
	uniform float alphaTest;
#endif`,ap=`#ifdef USE_AOMAP
	float ambientOcclusion = ( texture2D( aoMap, vAoMapUv ).r - 1.0 ) * aoMapIntensity + 1.0;
	reflectedLight.indirectDiffuse *= ambientOcclusion;
	#if defined( USE_CLEARCOAT ) 
		clearcoatSpecularIndirect *= ambientOcclusion;
	#endif
	#if defined( USE_SHEEN ) 
		sheenSpecularIndirect *= ambientOcclusion;
	#endif
	#if defined( USE_ENVMAP ) && defined( STANDARD )
		float dotNV = saturate( dot( geometryNormal, geometryViewDir ) );
		reflectedLight.indirectSpecular *= computeSpecularOcclusion( dotNV, ambientOcclusion, material.roughness );
	#endif
#endif`,op=`#ifdef USE_AOMAP
	uniform sampler2D aoMap;
	uniform float aoMapIntensity;
#endif`,lp=`#ifdef USE_BATCHING
	#if ! defined( GL_ANGLE_multi_draw )
	#define gl_DrawID _gl_DrawID
	uniform int _gl_DrawID;
	#endif
	uniform highp sampler2D batchingTexture;
	uniform highp usampler2D batchingIdTexture;
	mat4 getBatchingMatrix( const in float i ) {
		int size = textureSize( batchingTexture, 0 ).x;
		int j = int( i ) * 4;
		int x = j % size;
		int y = j / size;
		vec4 v1 = texelFetch( batchingTexture, ivec2( x, y ), 0 );
		vec4 v2 = texelFetch( batchingTexture, ivec2( x + 1, y ), 0 );
		vec4 v3 = texelFetch( batchingTexture, ivec2( x + 2, y ), 0 );
		vec4 v4 = texelFetch( batchingTexture, ivec2( x + 3, y ), 0 );
		return mat4( v1, v2, v3, v4 );
	}
	float getIndirectIndex( const in int i ) {
		int size = textureSize( batchingIdTexture, 0 ).x;
		int x = i % size;
		int y = i / size;
		return float( texelFetch( batchingIdTexture, ivec2( x, y ), 0 ).r );
	}
#endif
#ifdef USE_BATCHING_COLOR
	uniform sampler2D batchingColorTexture;
	vec4 getBatchingColor( const in float i ) {
		int size = textureSize( batchingColorTexture, 0 ).x;
		int j = int( i );
		int x = j % size;
		int y = j / size;
		return texelFetch( batchingColorTexture, ivec2( x, y ), 0 );
	}
#endif`,cp=`#ifdef USE_BATCHING
	mat4 batchingMatrix = getBatchingMatrix( getIndirectIndex( gl_DrawID ) );
#endif`,hp=`vec3 transformed = vec3( position );
#ifdef USE_ALPHAHASH
	vPosition = vec3( position );
#endif`,up=`vec3 objectNormal = vec3( normal );
#ifdef USE_TANGENT
	vec3 objectTangent = vec3( tangent.xyz );
#endif`,fp=`float G_BlinnPhong_Implicit( ) {
	return 0.25;
}
float D_BlinnPhong( const in float shininess, const in float dotNH ) {
	return RECIPROCAL_PI * ( shininess * 0.5 + 1.0 ) * pow( dotNH, shininess );
}
vec3 BRDF_BlinnPhong( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in vec3 specularColor, const in float shininess ) {
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNH = saturate( dot( normal, halfDir ) );
	float dotVH = saturate( dot( viewDir, halfDir ) );
	vec3 F = F_Schlick( specularColor, 1.0, dotVH );
	float G = G_BlinnPhong_Implicit( );
	float D = D_BlinnPhong( shininess, dotNH );
	return F * ( G * D );
} // validated`,dp=`#ifdef USE_IRIDESCENCE
	const mat3 XYZ_TO_REC709 = mat3(
		 3.2404542, -0.9692660,  0.0556434,
		-1.5371385,  1.8760108, -0.2040259,
		-0.4985314,  0.0415560,  1.0572252
	);
	vec3 Fresnel0ToIor( vec3 fresnel0 ) {
		vec3 sqrtF0 = sqrt( fresnel0 );
		return ( vec3( 1.0 ) + sqrtF0 ) / ( vec3( 1.0 ) - sqrtF0 );
	}
	vec3 IorToFresnel0( vec3 transmittedIor, float incidentIor ) {
		return pow2( ( transmittedIor - vec3( incidentIor ) ) / ( transmittedIor + vec3( incidentIor ) ) );
	}
	float IorToFresnel0( float transmittedIor, float incidentIor ) {
		return pow2( ( transmittedIor - incidentIor ) / ( transmittedIor + incidentIor ));
	}
	vec3 evalSensitivity( float OPD, vec3 shift ) {
		float phase = 2.0 * PI * OPD * 1.0e-9;
		vec3 val = vec3( 5.4856e-13, 4.4201e-13, 5.2481e-13 );
		vec3 pos = vec3( 1.6810e+06, 1.7953e+06, 2.2084e+06 );
		vec3 var = vec3( 4.3278e+09, 9.3046e+09, 6.6121e+09 );
		vec3 xyz = val * sqrt( 2.0 * PI * var ) * cos( pos * phase + shift ) * exp( - pow2( phase ) * var );
		xyz.x += 9.7470e-14 * sqrt( 2.0 * PI * 4.5282e+09 ) * cos( 2.2399e+06 * phase + shift[ 0 ] ) * exp( - 4.5282e+09 * pow2( phase ) );
		xyz /= 1.0685e-7;
		vec3 rgb = XYZ_TO_REC709 * xyz;
		return rgb;
	}
	vec3 evalIridescence( float outsideIOR, float eta2, float cosTheta1, float thinFilmThickness, vec3 baseF0 ) {
		vec3 I;
		float iridescenceIOR = mix( outsideIOR, eta2, smoothstep( 0.0, 0.03, thinFilmThickness ) );
		float sinTheta2Sq = pow2( outsideIOR / iridescenceIOR ) * ( 1.0 - pow2( cosTheta1 ) );
		float cosTheta2Sq = 1.0 - sinTheta2Sq;
		if ( cosTheta2Sq < 0.0 ) {
			return vec3( 1.0 );
		}
		float cosTheta2 = sqrt( cosTheta2Sq );
		float R0 = IorToFresnel0( iridescenceIOR, outsideIOR );
		float R12 = F_Schlick( R0, 1.0, cosTheta1 );
		float T121 = 1.0 - R12;
		float phi12 = 0.0;
		if ( iridescenceIOR < outsideIOR ) phi12 = PI;
		float phi21 = PI - phi12;
		vec3 baseIOR = Fresnel0ToIor( clamp( baseF0, 0.0, 0.9999 ) );		vec3 R1 = IorToFresnel0( baseIOR, iridescenceIOR );
		vec3 R23 = F_Schlick( R1, 1.0, cosTheta2 );
		vec3 phi23 = vec3( 0.0 );
		if ( baseIOR[ 0 ] < iridescenceIOR ) phi23[ 0 ] = PI;
		if ( baseIOR[ 1 ] < iridescenceIOR ) phi23[ 1 ] = PI;
		if ( baseIOR[ 2 ] < iridescenceIOR ) phi23[ 2 ] = PI;
		float OPD = 2.0 * iridescenceIOR * thinFilmThickness * cosTheta2;
		vec3 phi = vec3( phi21 ) + phi23;
		vec3 R123 = clamp( R12 * R23, 1e-5, 0.9999 );
		vec3 r123 = sqrt( R123 );
		vec3 Rs = pow2( T121 ) * R23 / ( vec3( 1.0 ) - R123 );
		vec3 C0 = R12 + Rs;
		I = C0;
		vec3 Cm = Rs - T121;
		for ( int m = 1; m <= 2; ++ m ) {
			Cm *= r123;
			vec3 Sm = 2.0 * evalSensitivity( float( m ) * OPD, float( m ) * phi );
			I += Cm * Sm;
		}
		return max( I, vec3( 0.0 ) );
	}
#endif`,pp=`#ifdef USE_BUMPMAP
	uniform sampler2D bumpMap;
	uniform float bumpScale;
	vec2 dHdxy_fwd() {
		vec2 dSTdx = dFdx( vBumpMapUv );
		vec2 dSTdy = dFdy( vBumpMapUv );
		float Hll = bumpScale * texture2D( bumpMap, vBumpMapUv ).x;
		float dBx = bumpScale * texture2D( bumpMap, vBumpMapUv + dSTdx ).x - Hll;
		float dBy = bumpScale * texture2D( bumpMap, vBumpMapUv + dSTdy ).x - Hll;
		return vec2( dBx, dBy );
	}
	vec3 perturbNormalArb( vec3 surf_pos, vec3 surf_norm, vec2 dHdxy, float faceDirection ) {
		vec3 vSigmaX = normalize( dFdx( surf_pos.xyz ) );
		vec3 vSigmaY = normalize( dFdy( surf_pos.xyz ) );
		vec3 vN = surf_norm;
		vec3 R1 = cross( vSigmaY, vN );
		vec3 R2 = cross( vN, vSigmaX );
		float fDet = dot( vSigmaX, R1 ) * faceDirection;
		vec3 vGrad = sign( fDet ) * ( dHdxy.x * R1 + dHdxy.y * R2 );
		return normalize( abs( fDet ) * surf_norm - vGrad );
	}
#endif`,mp=`#if NUM_CLIPPING_PLANES > 0
	vec4 plane;
	#ifdef ALPHA_TO_COVERAGE
		float distanceToPlane, distanceGradient;
		float clipOpacity = 1.0;
		#pragma unroll_loop_start
		for ( int i = 0; i < UNION_CLIPPING_PLANES; i ++ ) {
			plane = clippingPlanes[ i ];
			distanceToPlane = - dot( vClipPosition, plane.xyz ) + plane.w;
			distanceGradient = fwidth( distanceToPlane ) / 2.0;
			clipOpacity *= smoothstep( - distanceGradient, distanceGradient, distanceToPlane );
			if ( clipOpacity == 0.0 ) discard;
		}
		#pragma unroll_loop_end
		#if UNION_CLIPPING_PLANES < NUM_CLIPPING_PLANES
			float unionClipOpacity = 1.0;
			#pragma unroll_loop_start
			for ( int i = UNION_CLIPPING_PLANES; i < NUM_CLIPPING_PLANES; i ++ ) {
				plane = clippingPlanes[ i ];
				distanceToPlane = - dot( vClipPosition, plane.xyz ) + plane.w;
				distanceGradient = fwidth( distanceToPlane ) / 2.0;
				unionClipOpacity *= 1.0 - smoothstep( - distanceGradient, distanceGradient, distanceToPlane );
			}
			#pragma unroll_loop_end
			clipOpacity *= 1.0 - unionClipOpacity;
		#endif
		diffuseColor.a *= clipOpacity;
		if ( diffuseColor.a == 0.0 ) discard;
	#else
		#pragma unroll_loop_start
		for ( int i = 0; i < UNION_CLIPPING_PLANES; i ++ ) {
			plane = clippingPlanes[ i ];
			if ( dot( vClipPosition, plane.xyz ) > plane.w ) discard;
		}
		#pragma unroll_loop_end
		#if UNION_CLIPPING_PLANES < NUM_CLIPPING_PLANES
			bool clipped = true;
			#pragma unroll_loop_start
			for ( int i = UNION_CLIPPING_PLANES; i < NUM_CLIPPING_PLANES; i ++ ) {
				plane = clippingPlanes[ i ];
				clipped = ( dot( vClipPosition, plane.xyz ) > plane.w ) && clipped;
			}
			#pragma unroll_loop_end
			if ( clipped ) discard;
		#endif
	#endif
#endif`,gp=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
	uniform vec4 clippingPlanes[ NUM_CLIPPING_PLANES ];
#endif`,_p=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
#endif`,xp=`#if NUM_CLIPPING_PLANES > 0
	vClipPosition = - mvPosition.xyz;
#endif`,vp=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA )
	diffuseColor *= vColor;
#endif`,yp=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA )
	varying vec4 vColor;
#endif`,Mp=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
	varying vec4 vColor;
#endif`,Sp=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
	vColor = vec4( 1.0 );
#endif
#ifdef USE_COLOR_ALPHA
	vColor *= color;
#elif defined( USE_COLOR )
	vColor.rgb *= color;
#endif
#ifdef USE_INSTANCING_COLOR
	vColor.rgb *= instanceColor.rgb;
#endif
#ifdef USE_BATCHING_COLOR
	vColor *= getBatchingColor( getIndirectIndex( gl_DrawID ) );
#endif`,bp=`#define PI 3.141592653589793
#define PI2 6.283185307179586
#define PI_HALF 1.5707963267948966
#define RECIPROCAL_PI 0.3183098861837907
#define RECIPROCAL_PI2 0.15915494309189535
#define EPSILON 1e-6
#ifndef saturate
#define saturate( a ) clamp( a, 0.0, 1.0 )
#endif
#define whiteComplement( a ) ( 1.0 - saturate( a ) )
float pow2( const in float x ) { return x*x; }
vec3 pow2( const in vec3 x ) { return x*x; }
float pow3( const in float x ) { return x*x*x; }
float pow4( const in float x ) { float x2 = x*x; return x2*x2; }
float max3( const in vec3 v ) { return max( max( v.x, v.y ), v.z ); }
float average( const in vec3 v ) { return dot( v, vec3( 0.3333333 ) ); }
highp float rand( const in vec2 uv ) {
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract( sin( sn ) * c );
}
#ifdef HIGH_PRECISION
	float precisionSafeLength( vec3 v ) { return length( v ); }
#else
	float precisionSafeLength( vec3 v ) {
		float maxComponent = max3( abs( v ) );
		return length( v / maxComponent ) * maxComponent;
	}
#endif
struct IncidentLight {
	vec3 color;
	vec3 direction;
	bool visible;
};
struct ReflectedLight {
	vec3 directDiffuse;
	vec3 directSpecular;
	vec3 indirectDiffuse;
	vec3 indirectSpecular;
};
#ifdef USE_ALPHAHASH
	varying vec3 vPosition;
#endif
vec3 transformDirection( in vec3 dir, in mat4 matrix ) {
	return normalize( ( matrix * vec4( dir, 0.0 ) ).xyz );
}
#define inverseTransformDirection transformDirectionByInverseViewMatrix
vec3 transformNormalByInverseViewMatrix( in vec3 normal, in mat4 viewMatrix ) {
	return normalize( ( vec4( normal, 0.0 ) * viewMatrix ).xyz );
}
vec3 transformDirectionByInverseViewMatrix( in vec3 dir, in mat4 viewMatrix ) {
	return normalize( ( vec4( dir, 0.0 ) * viewMatrix ).xyz );
}
bool isPerspectiveMatrix( mat4 m ) {
	return m[ 2 ][ 3 ] == - 1.0;
}
vec2 equirectUv( in vec3 dir ) {
	float u = atan( dir.z, dir.x ) * RECIPROCAL_PI2 + 0.5;
	float v = asin( clamp( dir.y, - 1.0, 1.0 ) ) * RECIPROCAL_PI + 0.5;
	return vec2( u, v );
}
vec3 BRDF_Lambert( const in vec3 diffuseColor ) {
	return RECIPROCAL_PI * diffuseColor;
}
vec3 F_Schlick( const in vec3 f0, const in float f90, const in float dotVH ) {
	float fresnel = exp2( ( - 5.55473 * dotVH - 6.98316 ) * dotVH );
	return f0 * ( 1.0 - fresnel ) + ( f90 * fresnel );
}
float F_Schlick( const in float f0, const in float f90, const in float dotVH ) {
	float fresnel = exp2( ( - 5.55473 * dotVH - 6.98316 ) * dotVH );
	return f0 * ( 1.0 - fresnel ) + ( f90 * fresnel );
} // validated`,Ep=`#ifdef ENVMAP_TYPE_CUBE_UV
	#define cubeUV_minMipLevel 4.0
	#define cubeUV_minTileSize 16.0
	float getFace( vec3 direction ) {
		vec3 absDirection = abs( direction );
		float face = - 1.0;
		if ( absDirection.x > absDirection.z ) {
			if ( absDirection.x > absDirection.y )
				face = direction.x > 0.0 ? 0.0 : 3.0;
			else
				face = direction.y > 0.0 ? 1.0 : 4.0;
		} else {
			if ( absDirection.z > absDirection.y )
				face = direction.z > 0.0 ? 2.0 : 5.0;
			else
				face = direction.y > 0.0 ? 1.0 : 4.0;
		}
		return face;
	}
	vec2 getUV( vec3 direction, float face ) {
		vec2 uv;
		if ( face == 0.0 ) {
			uv = vec2( direction.z, direction.y ) / abs( direction.x );
		} else if ( face == 1.0 ) {
			uv = vec2( - direction.x, - direction.z ) / abs( direction.y );
		} else if ( face == 2.0 ) {
			uv = vec2( - direction.x, direction.y ) / abs( direction.z );
		} else if ( face == 3.0 ) {
			uv = vec2( - direction.z, direction.y ) / abs( direction.x );
		} else if ( face == 4.0 ) {
			uv = vec2( - direction.x, direction.z ) / abs( direction.y );
		} else {
			uv = vec2( direction.x, direction.y ) / abs( direction.z );
		}
		return 0.5 * ( uv + 1.0 );
	}
	vec3 bilinearCubeUV( sampler2D envMap, vec3 direction, float mipInt ) {
		float face = getFace( direction );
		float filterInt = max( cubeUV_minMipLevel - mipInt, 0.0 );
		mipInt = max( mipInt, cubeUV_minMipLevel );
		float faceSize = exp2( mipInt );
		highp vec2 uv = getUV( direction, face ) * ( faceSize - 2.0 ) + 1.0;
		if ( face > 2.0 ) {
			uv.y += faceSize;
			face -= 3.0;
		}
		uv.x += face * faceSize;
		uv.x += filterInt * 3.0 * cubeUV_minTileSize;
		uv.y += 4.0 * ( exp2( CUBEUV_MAX_MIP ) - faceSize );
		uv.x *= CUBEUV_TEXEL_WIDTH;
		uv.y *= CUBEUV_TEXEL_HEIGHT;
		#ifdef texture2DGradEXT
			return texture2DGradEXT( envMap, uv, vec2( 0.0 ), vec2( 0.0 ) ).rgb;
		#else
			return texture2D( envMap, uv ).rgb;
		#endif
	}
	#define cubeUV_r0 1.0
	#define cubeUV_m0 - 2.0
	#define cubeUV_r1 0.8
	#define cubeUV_m1 - 1.0
	#define cubeUV_r4 0.4
	#define cubeUV_m4 2.0
	#define cubeUV_r5 0.305
	#define cubeUV_m5 3.0
	#define cubeUV_r6 0.21
	#define cubeUV_m6 4.0
	float roughnessToMip( float roughness ) {
		float mip = 0.0;
		if ( roughness >= cubeUV_r1 ) {
			mip = ( cubeUV_r0 - roughness ) * ( cubeUV_m1 - cubeUV_m0 ) / ( cubeUV_r0 - cubeUV_r1 ) + cubeUV_m0;
		} else if ( roughness >= cubeUV_r4 ) {
			mip = ( cubeUV_r1 - roughness ) * ( cubeUV_m4 - cubeUV_m1 ) / ( cubeUV_r1 - cubeUV_r4 ) + cubeUV_m1;
		} else if ( roughness >= cubeUV_r5 ) {
			mip = ( cubeUV_r4 - roughness ) * ( cubeUV_m5 - cubeUV_m4 ) / ( cubeUV_r4 - cubeUV_r5 ) + cubeUV_m4;
		} else if ( roughness >= cubeUV_r6 ) {
			mip = ( cubeUV_r5 - roughness ) * ( cubeUV_m6 - cubeUV_m5 ) / ( cubeUV_r5 - cubeUV_r6 ) + cubeUV_m5;
		} else {
			mip = - 2.0 * log2( 1.16 * roughness );		}
		return mip;
	}
	vec4 textureCubeUV( sampler2D envMap, vec3 sampleDir, float roughness ) {
		float mip = clamp( roughnessToMip( roughness ), cubeUV_m0, CUBEUV_MAX_MIP );
		float mipF = fract( mip );
		float mipInt = floor( mip );
		vec3 color0 = bilinearCubeUV( envMap, sampleDir, mipInt );
		if ( mipF == 0.0 ) {
			return vec4( color0, 1.0 );
		} else {
			vec3 color1 = bilinearCubeUV( envMap, sampleDir, mipInt + 1.0 );
			return vec4( mix( color0, color1, mipF ), 1.0 );
		}
	}
#endif`,Tp=`vec3 transformedNormal = objectNormal;
#ifdef USE_TANGENT
	vec3 transformedTangent = objectTangent;
#endif
#ifdef USE_BATCHING
	mat3 bm = mat3( batchingMatrix );
	transformedNormal /= vec3( dot( bm[ 0 ], bm[ 0 ] ), dot( bm[ 1 ], bm[ 1 ] ), dot( bm[ 2 ], bm[ 2 ] ) );
	transformedNormal = bm * transformedNormal;
	#ifdef USE_TANGENT
		transformedTangent = bm * transformedTangent;
	#endif
#endif
#ifdef USE_INSTANCING
	mat3 im = mat3( instanceMatrix );
	transformedNormal /= vec3( dot( im[ 0 ], im[ 0 ] ), dot( im[ 1 ], im[ 1 ] ), dot( im[ 2 ], im[ 2 ] ) );
	transformedNormal = im * transformedNormal;
	#ifdef USE_TANGENT
		transformedTangent = im * transformedTangent;
	#endif
#endif
transformedNormal = normalMatrix * transformedNormal;
#ifdef FLIP_SIDED
	transformedNormal = - transformedNormal;
#endif
#ifdef USE_TANGENT
	transformedTangent = ( modelViewMatrix * vec4( transformedTangent, 0.0 ) ).xyz;
#endif`,wp=`#ifdef USE_DISPLACEMENTMAP
	uniform sampler2D displacementMap;
	uniform float displacementScale;
	uniform float displacementBias;
#endif`,Ap=`#ifdef USE_DISPLACEMENTMAP
	transformed += normalize( objectNormal ) * ( texture2D( displacementMap, vDisplacementMapUv ).x * displacementScale + displacementBias );
#endif`,Rp=`#ifdef USE_EMISSIVEMAP
	vec4 emissiveColor = texture2D( emissiveMap, vEmissiveMapUv );
	#ifdef DECODE_VIDEO_TEXTURE_EMISSIVE
		emissiveColor = sRGBTransferEOTF( emissiveColor );
	#endif
	totalEmissiveRadiance *= emissiveColor.rgb;
#endif`,Cp=`#ifdef USE_EMISSIVEMAP
	uniform sampler2D emissiveMap;
#endif`,Pp="gl_FragColor = linearToOutputTexel( gl_FragColor );",Ip=`vec4 LinearTransferOETF( in vec4 value ) {
	return value;
}
vec4 sRGBTransferEOTF( in vec4 value ) {
	return vec4( mix( pow( value.rgb * 0.9478672986 + vec3( 0.0521327014 ), vec3( 2.4 ) ), value.rgb * 0.0773993808, vec3( lessThanEqual( value.rgb, vec3( 0.04045 ) ) ) ), value.a );
}
vec4 sRGBTransferOETF( in vec4 value ) {
	return vec4( mix( pow( value.rgb, vec3( 0.41666 ) ) * 1.055 - vec3( 0.055 ), value.rgb * 12.92, vec3( lessThanEqual( value.rgb, vec3( 0.0031308 ) ) ) ), value.a );
}`,Lp=`#ifdef USE_ENVMAP
	#ifdef ENV_WORLDPOS
		vec3 cameraToFrag;
		if ( isOrthographic ) {
			cameraToFrag = normalize( vec3( - viewMatrix[ 0 ][ 2 ], - viewMatrix[ 1 ][ 2 ], - viewMatrix[ 2 ][ 2 ] ) );
		} else {
			cameraToFrag = normalize( vWorldPosition - cameraPosition );
		}
		vec3 worldNormal = transformNormalByInverseViewMatrix( normal, viewMatrix );
		#ifdef ENVMAP_MODE_REFLECTION
			vec3 reflectVec = reflect( cameraToFrag, worldNormal );
		#else
			vec3 reflectVec = refract( cameraToFrag, worldNormal, refractionRatio );
		#endif
	#else
		vec3 reflectVec = vReflect;
	#endif
	#ifdef ENVMAP_TYPE_CUBE
		vec4 envColor = textureCube( envMap, envMapRotation * reflectVec );
		#ifdef ENVMAP_BLENDING_MULTIPLY
			outgoingLight = mix( outgoingLight, outgoingLight * envColor.xyz, specularStrength * reflectivity );
		#elif defined( ENVMAP_BLENDING_MIX )
			outgoingLight = mix( outgoingLight, envColor.xyz, specularStrength * reflectivity );
		#elif defined( ENVMAP_BLENDING_ADD )
			outgoingLight += envColor.xyz * specularStrength * reflectivity;
		#endif
	#endif
#endif`,Dp=`#ifdef USE_ENVMAP
	uniform float envMapIntensity;
	uniform mat3 envMapRotation;
	#ifdef ENVMAP_TYPE_CUBE
		uniform samplerCube envMap;
	#else
		uniform sampler2D envMap;
	#endif
#endif`,Np=`#ifdef USE_ENVMAP
	uniform float reflectivity;
	#if defined( USE_BUMPMAP ) || defined( USE_NORMALMAP ) || defined( PHONG ) || defined( LAMBERT )
		#define ENV_WORLDPOS
	#endif
	#ifdef ENV_WORLDPOS
		varying vec3 vWorldPosition;
		uniform float refractionRatio;
	#else
		varying vec3 vReflect;
	#endif
#endif`,Up=`#ifdef USE_ENVMAP
	#if defined( USE_BUMPMAP ) || defined( USE_NORMALMAP ) || defined( PHONG ) || defined( LAMBERT )
		#define ENV_WORLDPOS
	#endif
	#ifdef ENV_WORLDPOS
		
		varying vec3 vWorldPosition;
	#else
		varying vec3 vReflect;
		uniform float refractionRatio;
	#endif
#endif`,Fp=`#ifdef USE_ENVMAP
	#ifdef ENV_WORLDPOS
		vWorldPosition = worldPosition.xyz;
	#else
		vec3 cameraToVertex;
		if ( isOrthographic ) {
			cameraToVertex = normalize( vec3( - viewMatrix[ 0 ][ 2 ], - viewMatrix[ 1 ][ 2 ], - viewMatrix[ 2 ][ 2 ] ) );
		} else {
			cameraToVertex = normalize( worldPosition.xyz - cameraPosition );
		}
		vec3 worldNormal = transformNormalByInverseViewMatrix( transformedNormal, viewMatrix );
		#ifdef ENVMAP_MODE_REFLECTION
			vReflect = reflect( cameraToVertex, worldNormal );
		#else
			vReflect = refract( cameraToVertex, worldNormal, refractionRatio );
		#endif
	#endif
#endif`,Op=`#ifdef USE_FOG
	vFogDepth = - mvPosition.z;
#endif`,Bp=`#ifdef USE_FOG
	varying float vFogDepth;
#endif`,zp=`#ifdef USE_FOG
	#ifdef FOG_EXP2
		float fogFactor = 1.0 - exp( - fogDensity * fogDensity * vFogDepth * vFogDepth );
	#else
		float fogFactor = smoothstep( fogNear, fogFar, vFogDepth );
	#endif
	gl_FragColor.rgb = mix( gl_FragColor.rgb, fogColor, fogFactor );
#endif`,Hp=`#ifdef USE_FOG
	uniform vec3 fogColor;
	varying float vFogDepth;
	#ifdef FOG_EXP2
		uniform float fogDensity;
	#else
		uniform float fogNear;
		uniform float fogFar;
	#endif
#endif`,kp=`#ifdef USE_GRADIENTMAP
	uniform sampler2D gradientMap;
#endif
vec3 getGradientIrradiance( vec3 normal, vec3 lightDirection ) {
	float dotNL = dot( normal, lightDirection );
	vec2 coord = vec2( dotNL * 0.5 + 0.5, 0.0 );
	#ifdef USE_GRADIENTMAP
		return vec3( texture2D( gradientMap, coord ).r );
	#else
		vec2 fw = fwidth( coord ) * 0.5;
		return mix( vec3( 0.7 ), vec3( 1.0 ), smoothstep( 0.7 - fw.x, 0.7 + fw.x, coord.x ) );
	#endif
}`,Vp=`#ifdef USE_LIGHTMAP
	uniform sampler2D lightMap;
	uniform float lightMapIntensity;
#endif`,Gp=`LambertMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularStrength = specularStrength;`,Wp=`varying vec3 vViewPosition;
struct LambertMaterial {
	vec3 diffuseColor;
	float specularStrength;
};
void RE_Direct_Lambert( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in LambertMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectDiffuse_Lambert( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in LambertMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_Lambert
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Lambert`,Xp=`uniform bool receiveShadow;
uniform vec3 ambientLightColor;
#if defined( USE_LIGHT_PROBES )
	uniform vec3 lightProbe[ 9 ];
#endif
vec3 shGetIrradianceAt( in vec3 normal, in vec3 shCoefficients[ 9 ] ) {
	float x = normal.x, y = normal.y, z = normal.z;
	vec3 result = shCoefficients[ 0 ] * 0.886227;
	result += shCoefficients[ 1 ] * 2.0 * 0.511664 * y;
	result += shCoefficients[ 2 ] * 2.0 * 0.511664 * z;
	result += shCoefficients[ 3 ] * 2.0 * 0.511664 * x;
	result += shCoefficients[ 4 ] * 2.0 * 0.429043 * x * y;
	result += shCoefficients[ 5 ] * 2.0 * 0.429043 * y * z;
	result += shCoefficients[ 6 ] * ( 0.743125 * z * z - 0.247708 );
	result += shCoefficients[ 7 ] * 2.0 * 0.429043 * x * z;
	result += shCoefficients[ 8 ] * 0.429043 * ( x * x - y * y );
	return result;
}
vec3 getLightProbeIrradiance( const in vec3 lightProbe[ 9 ], const in vec3 normal ) {
	vec3 worldNormal = transformNormalByInverseViewMatrix( normal, viewMatrix );
	vec3 irradiance = shGetIrradianceAt( worldNormal, lightProbe );
	return irradiance;
}
vec3 getAmbientLightIrradiance( const in vec3 ambientLightColor ) {
	vec3 irradiance = ambientLightColor;
	return irradiance;
}
float getDistanceAttenuation( const in float lightDistance, const in float cutoffDistance, const in float decayExponent ) {
	float distanceFalloff = 1.0 / max( pow( lightDistance, decayExponent ), 0.01 );
	if ( cutoffDistance > 0.0 ) {
		distanceFalloff *= pow2( saturate( 1.0 - pow4( lightDistance / cutoffDistance ) ) );
	}
	return distanceFalloff;
}
float getSpotAttenuation( const in float coneCosine, const in float penumbraCosine, const in float angleCosine ) {
	return smoothstep( coneCosine, penumbraCosine, angleCosine );
}
#if NUM_SUN_LIGHTS > 0
	struct SunLight {
		vec3 direction;
		vec3 color;
	};
	uniform SunLight sunLights[ NUM_SUN_LIGHTS ];
	void getSunLightInfo( const in SunLight sunLight, out IncidentLight light ) {
		light.color = sunLight.color;
		light.direction = sunLight.direction;
		light.visible = true;
	}
#endif
#if NUM_DIR_LIGHTS > 0
	struct DirectionalLight {
		vec3 direction;
		vec3 color;
	};
	uniform DirectionalLight directionalLights[ NUM_DIR_LIGHTS ];
	void getDirectionalLightInfo( const in DirectionalLight directionalLight, out IncidentLight light ) {
		light.color = directionalLight.color;
		light.direction = directionalLight.direction;
		light.visible = true;
	}
#endif
#if NUM_POINT_LIGHTS > 0
	struct PointLight {
		vec3 position;
		vec3 color;
		float distance;
		float decay;
	};
	uniform PointLight pointLights[ NUM_POINT_LIGHTS ];
	void getPointLightInfo( const in PointLight pointLight, const in vec3 geometryPosition, out IncidentLight light ) {
		vec3 lVector = pointLight.position - geometryPosition;
		light.direction = normalize( lVector );
		float lightDistance = length( lVector );
		light.color = pointLight.color;
		light.color *= getDistanceAttenuation( lightDistance, pointLight.distance, pointLight.decay );
		light.visible = ( light.color != vec3( 0.0 ) );
	}
#endif
#if NUM_SPOT_LIGHTS > 0
	struct SpotLight {
		vec3 position;
		vec3 direction;
		vec3 color;
		float distance;
		float decay;
		float coneCos;
		float penumbraCos;
	};
	uniform SpotLight spotLights[ NUM_SPOT_LIGHTS ];
	void getSpotLightInfo( const in SpotLight spotLight, const in vec3 geometryPosition, out IncidentLight light ) {
		vec3 lVector = spotLight.position - geometryPosition;
		light.direction = normalize( lVector );
		float angleCos = dot( light.direction, spotLight.direction );
		float spotAttenuation = getSpotAttenuation( spotLight.coneCos, spotLight.penumbraCos, angleCos );
		if ( spotAttenuation > 0.0 ) {
			float lightDistance = length( lVector );
			light.color = spotLight.color * spotAttenuation;
			light.color *= getDistanceAttenuation( lightDistance, spotLight.distance, spotLight.decay );
			light.visible = ( light.color != vec3( 0.0 ) );
		} else {
			light.color = vec3( 0.0 );
			light.visible = false;
		}
	}
#endif
#if NUM_RECT_AREA_LIGHTS > 0
	struct RectAreaLight {
		vec3 color;
		vec3 position;
		vec3 halfWidth;
		vec3 halfHeight;
	};
	uniform sampler2D ltc_1;	uniform sampler2D ltc_2;
	uniform RectAreaLight rectAreaLights[ NUM_RECT_AREA_LIGHTS ];
#endif
#if NUM_HEMI_LIGHTS > 0
	struct HemisphereLight {
		vec3 direction;
		vec3 skyColor;
		vec3 groundColor;
	};
	uniform HemisphereLight hemisphereLights[ NUM_HEMI_LIGHTS ];
	vec3 getHemisphereLightIrradiance( const in HemisphereLight hemiLight, const in vec3 normal ) {
		float dotNL = dot( normal, hemiLight.direction );
		float hemiDiffuseWeight = 0.5 * dotNL + 0.5;
		vec3 irradiance = mix( hemiLight.groundColor, hemiLight.skyColor, hemiDiffuseWeight );
		return irradiance;
	}
#endif
#include <lightprobes_pars_fragment>`,qp=`#ifdef USE_ENVMAP
	vec3 getIBLIrradiance( const in vec3 normal ) {
		#ifdef ENVMAP_TYPE_CUBE_UV
			vec3 worldNormal = transformNormalByInverseViewMatrix( normal, viewMatrix );
			vec4 envMapColor = textureCubeUV( envMap, envMapRotation * worldNormal, 1.0 );
			return PI * envMapColor.rgb * envMapIntensity;
		#else
			return vec3( 0.0 );
		#endif
	}
	vec3 getIBLRadiance( const in vec3 viewDir, const in vec3 normal, const in float roughness ) {
		#ifdef ENVMAP_TYPE_CUBE_UV
			vec3 reflectVec = reflect( - viewDir, normal );
			reflectVec = normalize( mix( reflectVec, normal, pow4( roughness ) ) );
			reflectVec = transformDirectionByInverseViewMatrix( reflectVec, viewMatrix );
			vec4 envMapColor = textureCubeUV( envMap, envMapRotation * reflectVec, roughness );
			return envMapColor.rgb * envMapIntensity;
		#else
			return vec3( 0.0 );
		#endif
	}
	#ifdef USE_RETROREFLECTION
		vec3 getIBLRetroRadiance( const in vec3 viewDir, const in vec3 normal, const in float roughness ) {
			#ifdef ENVMAP_TYPE_CUBE_UV
				vec3 retroVec = normalize( mix( viewDir, normal, pow4( roughness ) ) );
				retroVec = transformDirectionByInverseViewMatrix( retroVec, viewMatrix );
				vec4 envMapColor = textureCubeUV( envMap, envMapRotation * retroVec, roughness );
				return envMapColor.rgb * envMapIntensity;
			#else
				return vec3( 0.0 );
			#endif
		}
	#endif
	#ifdef USE_ANISOTROPY
		vec3 getIBLAnisotropyRadiance( const in vec3 viewDir, const in vec3 normal, const in float roughness, const in vec3 bitangent, const in float anisotropy ) {
			#ifdef ENVMAP_TYPE_CUBE_UV
				vec3 bentNormal = cross( bitangent, viewDir );
				bentNormal = normalize( cross( bentNormal, bitangent ) );
				bentNormal = normalize( mix( bentNormal, normal, pow2( pow2( 1.0 - anisotropy * ( 1.0 - roughness ) ) ) ) );
				return getIBLRadiance( viewDir, bentNormal, roughness );
			#else
				return vec3( 0.0 );
			#endif
		}
		#ifdef USE_RETROREFLECTION
			vec3 getIBLAnisotropyRetroRadiance( const in vec3 viewDir, const in vec3 normal, const in float roughness, const in vec3 bitangent, const in float anisotropy ) {
				#ifdef ENVMAP_TYPE_CUBE_UV
					vec3 bentNormal = cross( bitangent, viewDir );
					bentNormal = normalize( cross( bentNormal, bitangent ) );
					bentNormal = normalize( mix( bentNormal, normal, pow2( pow2( 1.0 - anisotropy * ( 1.0 - roughness ) ) ) ) );
					return getIBLRetroRadiance( viewDir, bentNormal, roughness );
				#else
					return vec3( 0.0 );
				#endif
			}
		#endif
	#endif
#endif`,Yp=`ToonMaterial material;
material.diffuseColor = diffuseColor.rgb;`,$p=`varying vec3 vViewPosition;
struct ToonMaterial {
	vec3 diffuseColor;
};
void RE_Direct_Toon( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in ToonMaterial material, inout ReflectedLight reflectedLight ) {
	vec3 irradiance = getGradientIrradiance( geometryNormal, directLight.direction ) * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
void RE_IndirectDiffuse_Toon( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in ToonMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_Toon
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Toon`,Zp=`BlinnPhongMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularColor = specular;
material.specularShininess = shininess;
material.specularStrength = specularStrength;`,Jp=`varying vec3 vViewPosition;
struct BlinnPhongMaterial {
	vec3 diffuseColor;
	vec3 specularColor;
	float specularShininess;
	float specularStrength;
};
void RE_Direct_BlinnPhong( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in BlinnPhongMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
	reflectedLight.directSpecular += irradiance * BRDF_BlinnPhong( directLight.direction, geometryViewDir, geometryNormal, material.specularColor, material.specularShininess ) * material.specularStrength;
}
void RE_IndirectDiffuse_BlinnPhong( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in BlinnPhongMaterial material, inout ReflectedLight reflectedLight ) {
	reflectedLight.indirectDiffuse += irradiance * BRDF_Lambert( material.diffuseColor );
}
#define RE_Direct				RE_Direct_BlinnPhong
#define RE_IndirectDiffuse		RE_IndirectDiffuse_BlinnPhong`,Kp=`PhysicalMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.diffuseContribution = diffuseColor.rgb * ( 1.0 - metalnessFactor );
material.metalness = metalnessFactor;
vec3 dxy = max( abs( dFdx( nonPerturbedNormal ) ), abs( dFdy( nonPerturbedNormal ) ) );
float geometryRoughness = max( max( dxy.x, dxy.y ), dxy.z );
material.roughness = max( roughnessFactor, 0.0525 );material.roughness += geometryRoughness;
material.roughness = min( material.roughness, 1.0 );
#ifdef IOR
	material.ior = ior;
	#ifdef USE_SPECULAR
		float specularIntensityFactor = specularIntensity;
		vec3 specularColorFactor = specularColor;
		#ifdef USE_SPECULAR_COLORMAP
			specularColorFactor *= texture2D( specularColorMap, vSpecularColorMapUv ).rgb;
		#endif
		#ifdef USE_SPECULAR_INTENSITYMAP
			specularIntensityFactor *= texture2D( specularIntensityMap, vSpecularIntensityMapUv ).a;
		#endif
		material.specularF90 = mix( specularIntensityFactor, 1.0, metalnessFactor );
	#else
		float specularIntensityFactor = 1.0;
		vec3 specularColorFactor = vec3( 1.0 );
		material.specularF90 = 1.0;
	#endif
	material.specularColor = min( pow2( ( material.ior - 1.0 ) / ( material.ior + 1.0 ) ) * specularColorFactor, vec3( 1.0 ) ) * specularIntensityFactor;
	material.specularColorBlended = mix( material.specularColor, diffuseColor.rgb, metalnessFactor );
#else
	material.specularColor = vec3( 0.04 );
	material.specularColorBlended = mix( material.specularColor, diffuseColor.rgb, metalnessFactor );
	material.specularF90 = 1.0;
#endif
#ifdef USE_CLEARCOAT
	material.clearcoat = clearcoat;
	material.clearcoatRoughness = clearcoatRoughness;
	material.clearcoatF0 = vec3( 0.04 );
	material.clearcoatF90 = 1.0;
	#ifdef USE_CLEARCOATMAP
		material.clearcoat *= texture2D( clearcoatMap, vClearcoatMapUv ).x;
	#endif
	#ifdef USE_CLEARCOAT_ROUGHNESSMAP
		material.clearcoatRoughness *= texture2D( clearcoatRoughnessMap, vClearcoatRoughnessMapUv ).y;
	#endif
	material.clearcoat = saturate( material.clearcoat );	material.clearcoatRoughness = max( material.clearcoatRoughness, 0.0525 );
	material.clearcoatRoughness += geometryRoughness;
	material.clearcoatRoughness = min( material.clearcoatRoughness, 1.0 );
#endif
#ifdef USE_DISPERSION
	material.dispersion = dispersion;
#endif
#ifdef USE_RETROREFLECTION
	material.retroreflectivity = retroreflectivity;
#endif
#ifdef USE_IRIDESCENCE
	material.iridescence = iridescence;
	material.iridescenceIOR = iridescenceIOR;
	#ifdef USE_IRIDESCENCEMAP
		material.iridescence *= texture2D( iridescenceMap, vIridescenceMapUv ).r;
	#endif
	#ifdef USE_IRIDESCENCE_THICKNESSMAP
		material.iridescenceThickness = (iridescenceThicknessMaximum - iridescenceThicknessMinimum) * texture2D( iridescenceThicknessMap, vIridescenceThicknessMapUv ).g + iridescenceThicknessMinimum;
	#else
		material.iridescenceThickness = iridescenceThicknessMaximum;
	#endif
#endif
#ifdef USE_SHEEN
	material.sheenColor = sheenColor;
	#ifdef USE_SHEEN_COLORMAP
		material.sheenColor *= texture2D( sheenColorMap, vSheenColorMapUv ).rgb;
	#endif
	material.sheenRoughness = clamp( sheenRoughness, 0.0001, 1.0 );
	#ifdef USE_SHEEN_ROUGHNESSMAP
		material.sheenRoughness *= texture2D( sheenRoughnessMap, vSheenRoughnessMapUv ).a;
	#endif
#endif
#ifdef USE_ANISOTROPY
	#ifdef USE_ANISOTROPYMAP
		mat2 anisotropyMat = mat2( anisotropyVector.x, anisotropyVector.y, - anisotropyVector.y, anisotropyVector.x );
		vec3 anisotropyPolar = texture2D( anisotropyMap, vAnisotropyMapUv ).rgb;
		vec2 anisotropyV = anisotropyMat * normalize( 2.0 * anisotropyPolar.rg - vec2( 1.0 ) ) * anisotropyPolar.b;
	#else
		vec2 anisotropyV = anisotropyVector;
	#endif
	material.anisotropy = length( anisotropyV );
	if( material.anisotropy == 0.0 ) {
		anisotropyV = vec2( 1.0, 0.0 );
	} else {
		anisotropyV /= material.anisotropy;
		material.anisotropy = saturate( material.anisotropy );
	}
	material.alphaT = mix( pow2( material.roughness ), 1.0, pow2( material.anisotropy ) );
	material.anisotropyT = tbn[ 0 ] * anisotropyV.x + tbn[ 1 ] * anisotropyV.y;
	material.anisotropyB = tbn[ 1 ] * anisotropyV.x - tbn[ 0 ] * anisotropyV.y;
#endif`,jp=`uniform sampler2D dfgLUT;
struct PhysicalMaterial {
	vec3 diffuseColor;
	vec3 diffuseContribution;
	vec3 specularColor;
	vec3 specularColorBlended;
	float roughness;
	float metalness;
	float specularF90;
	float dispersion;
	vec2 dfg;
	vec3 multiScatteringCompensation;
	#ifdef USE_RETROREFLECTION
		float retroreflectivity;
	#endif
	#ifdef USE_CLEARCOAT
		float clearcoat;
		float clearcoatRoughness;
		vec3 clearcoatF0;
		float clearcoatF90;
	#endif
	#ifdef USE_IRIDESCENCE
		float iridescence;
		float iridescenceIOR;
		float iridescenceThickness;
		vec3 iridescenceFresnel;
		vec3 iridescenceF0Dielectric;
		vec3 iridescenceF0Metallic;
	#endif
	#ifdef USE_SHEEN
		vec3 sheenColor;
		float sheenRoughness;
	#endif
	#ifdef IOR
		float ior;
	#endif
	#ifdef USE_TRANSMISSION
		float transmission;
		float transmissionAlpha;
		float thickness;
		float attenuationDistance;
		vec3 attenuationColor;
	#endif
	#ifdef USE_ANISOTROPY
		float anisotropy;
		float alphaT;
		vec3 anisotropyT;
		vec3 anisotropyB;
	#endif
};
vec3 clearcoatSpecularDirect = vec3( 0.0 );
vec3 clearcoatSpecularIndirect = vec3( 0.0 );
vec3 sheenSpecularDirect = vec3( 0.0 );
vec3 sheenSpecularIndirect = vec3(0.0 );
vec3 Schlick_to_F0( const in vec3 f, const in float f90, const in float dotVH ) {
    float x = clamp( 1.0 - dotVH, 0.0, 1.0 );
    float x2 = x * x;
    float x5 = clamp( x * x2 * x2, 0.0, 0.9999 );
    return ( f - vec3( f90 ) * x5 ) / ( 1.0 - x5 );
}
float V_GGX_SmithCorrelated( const in float alpha, const in float dotNL, const in float dotNV ) {
	float a2 = pow2( alpha );
	float gv = dotNL * sqrt( a2 + ( 1.0 - a2 ) * pow2( dotNV ) );
	float gl = dotNV * sqrt( a2 + ( 1.0 - a2 ) * pow2( dotNL ) );
	return 0.5 / max( gv + gl, EPSILON );
}
float D_GGX( const in float alpha, const in float dotNH ) {
	float a2 = pow2( alpha );
	float denom = pow2( dotNH ) * ( a2 - 1.0 ) + 1.0;
	return RECIPROCAL_PI * a2 / pow2( denom );
}
#ifdef USE_ANISOTROPY
	float V_GGX_SmithCorrelated_Anisotropic( const in float alphaT, const in float alphaB, const in float dotTV, const in float dotBV, const in float dotTL, const in float dotBL, const in float dotNV, const in float dotNL ) {
		float gv = dotNL * length( vec3( alphaT * dotTV, alphaB * dotBV, dotNV ) );
		float gl = dotNV * length( vec3( alphaT * dotTL, alphaB * dotBL, dotNL ) );
		return 0.5 / max( gv + gl, EPSILON );
	}
	float D_GGX_Anisotropic( const in float alphaT, const in float alphaB, const in float dotNH, const in float dotTH, const in float dotBH ) {
		float a2 = alphaT * alphaB;
		highp vec3 v = vec3( alphaB * dotTH, alphaT * dotBH, a2 * dotNH );
		highp float v2 = dot( v, v );
		float w2 = a2 / v2;
		return RECIPROCAL_PI * a2 * pow2 ( w2 );
	}
#endif
#ifdef USE_CLEARCOAT
	vec3 BRDF_GGX_Clearcoat( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in PhysicalMaterial material) {
		vec3 f0 = material.clearcoatF0;
		float f90 = material.clearcoatF90;
		float roughness = material.clearcoatRoughness;
		float alpha = pow2( roughness );
		vec3 halfDir = normalize( lightDir + viewDir );
		float dotNL = saturate( dot( normal, lightDir ) );
		float dotNV = saturate( dot( normal, viewDir ) );
		float dotNH = saturate( dot( normal, halfDir ) );
		float dotVH = saturate( dot( viewDir, halfDir ) );
		vec3 F = F_Schlick( f0, f90, dotVH );
		float V = V_GGX_SmithCorrelated( alpha, dotNL, dotNV );
		float D = D_GGX( alpha, dotNH );
		return F * ( V * D );
	}
#endif
vec3 BRDF_GGX( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, const in PhysicalMaterial material ) {
	vec3 f0 = material.specularColorBlended;
	float f90 = material.specularF90;
	float roughness = material.roughness;
	float alpha = pow2( roughness );
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNL = saturate( dot( normal, lightDir ) );
	float dotNV = saturate( dot( normal, viewDir ) );
	float dotNH = saturate( dot( normal, halfDir ) );
	float dotVH = saturate( dot( viewDir, halfDir ) );
	vec3 F = F_Schlick( f0, f90, dotVH );
	#ifdef USE_IRIDESCENCE
		F = mix( F, material.iridescenceFresnel, material.iridescence );
	#endif
	#ifdef USE_ANISOTROPY
		float dotTL = dot( material.anisotropyT, lightDir );
		float dotTV = dot( material.anisotropyT, viewDir );
		float dotTH = dot( material.anisotropyT, halfDir );
		float dotBL = dot( material.anisotropyB, lightDir );
		float dotBV = dot( material.anisotropyB, viewDir );
		float dotBH = dot( material.anisotropyB, halfDir );
		float V = V_GGX_SmithCorrelated_Anisotropic( material.alphaT, alpha, dotTV, dotBV, dotTL, dotBL, dotNV, dotNL );
		float D = D_GGX_Anisotropic( material.alphaT, alpha, dotNH, dotTH, dotBH );
	#else
		float V = V_GGX_SmithCorrelated( alpha, dotNL, dotNV );
		float D = D_GGX( alpha, dotNH );
	#endif
	return F * ( V * D );
}
vec2 LTC_Uv( const in vec3 N, const in vec3 V, const in float roughness ) {
	const float LUT_SIZE = 64.0;
	const float LUT_SCALE = ( LUT_SIZE - 1.0 ) / LUT_SIZE;
	const float LUT_BIAS = 0.5 / LUT_SIZE;
	float dotNV = saturate( dot( N, V ) );
	vec2 uv = vec2( roughness, sqrt( 1.0 - dotNV ) );
	uv = uv * LUT_SCALE + LUT_BIAS;
	return uv;
}
float LTC_ClippedSphereFormFactor( const in vec3 f ) {
	float l = length( f );
	return max( ( l * l + f.z ) / ( l + 1.0 ), 0.0 );
}
vec3 LTC_EdgeVectorFormFactor( const in vec3 v1, const in vec3 v2 ) {
	float x = dot( v1, v2 );
	float y = abs( x );
	float a = 0.8543985 + ( 0.4965155 + 0.0145206 * y ) * y;
	float b = 3.4175940 + ( 4.1616724 + y ) * y;
	float v = a / b;
	float theta_sintheta = ( x > 0.0 ) ? v : 0.5 * inversesqrt( max( 1.0 - x * x, 1e-7 ) ) - v;
	return cross( v1, v2 ) * theta_sintheta;
}
vec3 LTC_Evaluate( const in vec3 N, const in vec3 V, const in vec3 P, const in mat3 mInv, const in vec3 rectCoords[ 4 ] ) {
	vec3 v1 = rectCoords[ 1 ] - rectCoords[ 0 ];
	vec3 v2 = rectCoords[ 3 ] - rectCoords[ 0 ];
	vec3 lightNormal = cross( v1, v2 );
	if( dot( lightNormal, P - rectCoords[ 0 ] ) < 0.0 ) return vec3( 0.0 );
	vec3 T1, T2;
	T1 = normalize( V - N * dot( V, N ) );
	T2 = - cross( N, T1 );
	mat3 mat = mInv * transpose( mat3( T1, T2, N ) );
	vec3 coords[ 4 ];
	coords[ 0 ] = mat * ( rectCoords[ 0 ] - P );
	coords[ 1 ] = mat * ( rectCoords[ 1 ] - P );
	coords[ 2 ] = mat * ( rectCoords[ 2 ] - P );
	coords[ 3 ] = mat * ( rectCoords[ 3 ] - P );
	coords[ 0 ] = normalize( coords[ 0 ] );
	coords[ 1 ] = normalize( coords[ 1 ] );
	coords[ 2 ] = normalize( coords[ 2 ] );
	coords[ 3 ] = normalize( coords[ 3 ] );
	vec3 vectorFormFactor = vec3( 0.0 );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 0 ], coords[ 1 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 1 ], coords[ 2 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 2 ], coords[ 3 ] );
	vectorFormFactor += LTC_EdgeVectorFormFactor( coords[ 3 ], coords[ 0 ] );
	float result = LTC_ClippedSphereFormFactor( vectorFormFactor );
	return vec3( result );
}
#if defined( USE_SHEEN )
float D_Charlie( float roughness, float dotNH ) {
	float alpha = pow2( roughness );
	float invAlpha = 1.0 / alpha;
	float cos2h = dotNH * dotNH;
	float sin2h = max( 1.0 - cos2h, 0.0078125 );
	return ( 2.0 + invAlpha ) * pow( sin2h, invAlpha * 0.5 ) / ( 2.0 * PI );
}
float V_Neubelt( float dotNV, float dotNL ) {
	return saturate( 1.0 / ( 4.0 * ( dotNL + dotNV - dotNL * dotNV ) ) );
}
vec3 BRDF_Sheen( const in vec3 lightDir, const in vec3 viewDir, const in vec3 normal, vec3 sheenColor, const in float sheenRoughness ) {
	vec3 halfDir = normalize( lightDir + viewDir );
	float dotNL = saturate( dot( normal, lightDir ) );
	float dotNV = saturate( dot( normal, viewDir ) );
	float dotNH = saturate( dot( normal, halfDir ) );
	float D = D_Charlie( sheenRoughness, dotNH );
	float V = V_Neubelt( dotNV, dotNL );
	return sheenColor * ( D * V );
}
#endif
float IBLSheenBRDF( const in vec3 normal, const in vec3 viewDir, const in float roughness ) {
	float dotNV = saturate( dot( normal, viewDir ) );
	float r2 = roughness * roughness;
	float rInv = 1.0 / ( roughness + 0.1 );
	float a = -1.9362 + 1.0678 * roughness + 0.4573 * r2 - 0.8469 * rInv;
	float b = -0.6014 + 0.5538 * roughness - 0.4670 * r2 - 0.1255 * rInv;
	float DG = exp( a * dotNV + b );
	return saturate( DG );
}
vec3 EnvironmentBRDF( const in vec3 normal, const in vec3 viewDir, const in vec3 specularColor, const in float specularF90, const in float roughness ) {
	float dotNV = saturate( dot( normal, viewDir ) );
	vec2 fab = texture2D( dfgLUT, vec2( roughness, dotNV ) ).rg;
	return specularColor * fab.x + specularF90 * fab.y;
}
#ifdef USE_IRIDESCENCE
void computeMultiscatteringIridescence( const in vec2 fab, const in vec3 specularColor, const in float specularF90, const in float iridescence, const in vec3 iridescenceF0, inout vec3 singleScatter, inout vec3 multiScatter ) {
#else
void computeMultiscattering( const in vec2 fab, const in vec3 specularColor, const in float specularF90, inout vec3 singleScatter, inout vec3 multiScatter ) {
#endif
	#ifdef USE_IRIDESCENCE
		vec3 Fr = mix( specularColor, iridescenceF0, iridescence );
	#else
		vec3 Fr = specularColor;
	#endif
	vec3 FssEss = Fr * fab.x + specularF90 * fab.y;
	float Ess = fab.x + fab.y;
	float Ems = 1.0 - Ess;
	vec3 Favg = Fr + ( 1.0 - Fr ) * 0.047619;	vec3 Fms = FssEss * Favg / ( 1.0 - Ems * Favg );
	singleScatter += FssEss;
	multiScatter += Fms * Ems;
}
#if NUM_RECT_AREA_LIGHTS > 0
	void RE_Direct_RectArea_Physical( const in RectAreaLight rectAreaLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
		vec3 normal = geometryNormal;
		vec3 viewDir = geometryViewDir;
		vec3 position = geometryPosition;
		vec3 lightPos = rectAreaLight.position;
		vec3 halfWidth = rectAreaLight.halfWidth;
		vec3 halfHeight = rectAreaLight.halfHeight;
		vec3 lightColor = rectAreaLight.color;
		float roughness = material.roughness;
		vec3 rectCoords[ 4 ];
		rectCoords[ 0 ] = lightPos + halfWidth - halfHeight;		rectCoords[ 1 ] = lightPos - halfWidth - halfHeight;
		rectCoords[ 2 ] = lightPos - halfWidth + halfHeight;
		rectCoords[ 3 ] = lightPos + halfWidth + halfHeight;
		vec2 uv = LTC_Uv( normal, viewDir, roughness );
		vec4 t1 = texture2D( ltc_1, uv );
		vec4 t2 = texture2D( ltc_2, uv );
		mat3 mInv = mat3(
			vec3( t1.x, 0, t1.y ),
			vec3(    0, 1,    0 ),
			vec3( t1.z, 0, t1.w )
		);
		vec3 fresnel = ( material.specularColorBlended * t2.x + ( material.specularF90 - material.specularColorBlended ) * t2.y );
		reflectedLight.directSpecular += lightColor * fresnel * LTC_Evaluate( normal, viewDir, position, mInv, rectCoords );
		reflectedLight.directDiffuse += lightColor * material.diffuseContribution * LTC_Evaluate( normal, viewDir, position, mat3( 1.0 ), rectCoords );
		#ifdef USE_CLEARCOAT
			vec3 Ncc = geometryClearcoatNormal;
			vec2 uvClearcoat = LTC_Uv( Ncc, viewDir, material.clearcoatRoughness );
			vec4 t1Clearcoat = texture2D( ltc_1, uvClearcoat );
			vec4 t2Clearcoat = texture2D( ltc_2, uvClearcoat );
			mat3 mInvClearcoat = mat3(
				vec3( t1Clearcoat.x, 0, t1Clearcoat.y ),
				vec3(             0, 1,             0 ),
				vec3( t1Clearcoat.z, 0, t1Clearcoat.w )
			);
			vec3 fresnelClearcoat = material.clearcoatF0 * t2Clearcoat.x + ( material.clearcoatF90 - material.clearcoatF0 ) * t2Clearcoat.y;
			clearcoatSpecularDirect += lightColor * fresnelClearcoat * LTC_Evaluate( Ncc, viewDir, position, mInvClearcoat, rectCoords );
		#endif
	}
#endif
void RE_Direct_Physical( const in IncidentLight directLight, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
	float dotNL = saturate( dot( geometryNormal, directLight.direction ) );
	vec3 irradiance = dotNL * directLight.color;
	#ifdef USE_CLEARCOAT
		float dotNLcc = saturate( dot( geometryClearcoatNormal, directLight.direction ) );
		vec3 ccIrradiance = dotNLcc * directLight.color;
		clearcoatSpecularDirect += ccIrradiance * BRDF_GGX_Clearcoat( directLight.direction, geometryViewDir, geometryClearcoatNormal, material );
	#endif
	#ifdef USE_SHEEN
 
 		sheenSpecularDirect += irradiance * BRDF_Sheen( directLight.direction, geometryViewDir, geometryNormal, material.sheenColor, material.sheenRoughness );
 
 		float sheenAlbedoV = IBLSheenBRDF( geometryNormal, geometryViewDir, material.sheenRoughness );
 		float sheenAlbedoL = IBLSheenBRDF( geometryNormal, directLight.direction, material.sheenRoughness );
 
 		float sheenEnergyComp = 1.0 - max3( material.sheenColor ) * max( sheenAlbedoV, sheenAlbedoL );
 
 		irradiance *= sheenEnergyComp;
 
 	#endif
	vec3 specularBRDF = BRDF_GGX( directLight.direction, geometryViewDir, geometryNormal, material );
	#ifdef USE_RETROREFLECTION
		vec3 retroViewDir = reflect( - geometryViewDir, geometryNormal );
		vec3 retroSpecularBRDF = BRDF_GGX( directLight.direction, retroViewDir, geometryNormal, material );
		specularBRDF = mix( specularBRDF, retroSpecularBRDF, saturate( material.retroreflectivity ) );
	#endif
	reflectedLight.directSpecular += irradiance * specularBRDF * material.multiScatteringCompensation;
	vec3 halfDir = normalize( directLight.direction + geometryViewDir );
	float dotVH = saturate( dot( geometryViewDir, halfDir ) );
	vec3 F = F_Schlick( material.specularColor, material.specularF90, dotVH );
	#ifdef USE_RETROREFLECTION
		vec3 retroHalfDir = normalize( directLight.direction + retroViewDir );
		float dotRetroVH = saturate( dot( retroViewDir, retroHalfDir ) );
		vec3 retroF = F_Schlick( material.specularColor, material.specularF90, dotRetroVH );
		F = mix( F, retroF, saturate( material.retroreflectivity ) );
	#endif
	reflectedLight.directDiffuse += irradiance * BRDF_Lambert( material.diffuseContribution ) * ( 1.0 - F );
}
void RE_IndirectDiffuse_Physical( const in vec3 irradiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight ) {
	vec3 singleScattering = vec3( 0.0 );
	vec3 multiScattering = vec3( 0.0 );
	#ifdef USE_IRIDESCENCE
		computeMultiscatteringIridescence( material.dfg, material.specularColor, material.specularF90, material.iridescence, material.iridescenceF0Dielectric, singleScattering, multiScattering );
	#else
		computeMultiscattering( material.dfg, material.specularColor, material.specularF90, singleScattering, multiScattering );
	#endif
	vec3 diffuse = irradiance * BRDF_Lambert( material.diffuseContribution ) * ( 1.0 - singleScattering - multiScattering );
	#ifdef USE_SHEEN
		float sheenAlbedo = IBLSheenBRDF( geometryNormal, geometryViewDir, material.sheenRoughness );
		sheenSpecularIndirect += irradiance * material.sheenColor * sheenAlbedo * RECIPROCAL_PI;
		float sheenEnergyComp = 1.0 - max3( material.sheenColor ) * sheenAlbedo;
		diffuse *= sheenEnergyComp;
	#endif
	reflectedLight.indirectDiffuse += diffuse;
}
void RE_IndirectSpecular_Physical( const in vec3 radiance, const in vec3 irradiance, const in vec3 clearcoatRadiance, const in vec3 geometryPosition, const in vec3 geometryNormal, const in vec3 geometryViewDir, const in vec3 geometryClearcoatNormal, const in PhysicalMaterial material, inout ReflectedLight reflectedLight) {
	#ifdef USE_CLEARCOAT
		clearcoatSpecularIndirect += clearcoatRadiance * EnvironmentBRDF( geometryClearcoatNormal, geometryViewDir, material.clearcoatF0, material.clearcoatF90, material.clearcoatRoughness );
	#endif
	#ifdef USE_SHEEN
		sheenSpecularIndirect += irradiance * material.sheenColor * IBLSheenBRDF( geometryNormal, geometryViewDir, material.sheenRoughness ) * RECIPROCAL_PI;
 	#endif
	vec3 singleScatteringDielectric = vec3( 0.0 );
	vec3 multiScatteringDielectric = vec3( 0.0 );
	vec3 singleScatteringMetallic = vec3( 0.0 );
	vec3 multiScatteringMetallic = vec3( 0.0 );
	#ifdef USE_IRIDESCENCE
		computeMultiscatteringIridescence( material.dfg, material.specularColor, material.specularF90, material.iridescence, material.iridescenceF0Dielectric, singleScatteringDielectric, multiScatteringDielectric );
		computeMultiscatteringIridescence( material.dfg, material.diffuseColor, material.specularF90, material.iridescence, material.iridescenceF0Metallic, singleScatteringMetallic, multiScatteringMetallic );
	#else
		computeMultiscattering( material.dfg, material.specularColor, material.specularF90, singleScatteringDielectric, multiScatteringDielectric );
		computeMultiscattering( material.dfg, material.diffuseColor, material.specularF90, singleScatteringMetallic, multiScatteringMetallic );
	#endif
	vec3 singleScattering = mix( singleScatteringDielectric, singleScatteringMetallic, material.metalness );
	vec3 multiScattering = mix( multiScatteringDielectric, multiScatteringMetallic, material.metalness );
	vec3 totalScatteringDielectric = singleScatteringDielectric + multiScatteringDielectric;
	vec3 diffuse = material.diffuseContribution * ( 1.0 - totalScatteringDielectric );
	vec3 cosineWeightedIrradiance = irradiance * RECIPROCAL_PI;
	vec3 indirectSpecular = radiance * singleScattering;
	indirectSpecular += multiScattering * cosineWeightedIrradiance;
	vec3 indirectDiffuse = diffuse * cosineWeightedIrradiance;
	#ifdef USE_SHEEN
		float sheenAlbedo = IBLSheenBRDF( geometryNormal, geometryViewDir, material.sheenRoughness );
		float sheenEnergyComp = 1.0 - max3( material.sheenColor ) * sheenAlbedo;
		indirectSpecular *= sheenEnergyComp;
		indirectDiffuse *= sheenEnergyComp;
	#endif
	reflectedLight.indirectSpecular += indirectSpecular;
	reflectedLight.indirectDiffuse += indirectDiffuse;
}
#define RE_Direct				RE_Direct_Physical
#define RE_Direct_RectArea		RE_Direct_RectArea_Physical
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Physical
#define RE_IndirectSpecular		RE_IndirectSpecular_Physical
float computeSpecularOcclusion( const in float dotNV, const in float ambientOcclusion, const in float roughness ) {
	return saturate( pow( dotNV + ambientOcclusion, exp2( - 16.0 * roughness - 1.0 ) ) - 1.0 + ambientOcclusion );
}`,Qp=`
vec3 geometryPosition = - vViewPosition;
vec3 geometryNormal = normal;
vec3 geometryViewDir = ( isOrthographic ) ? vec3( 0, 0, 1 ) : normalize( vViewPosition );
vec3 geometryClearcoatNormal = vec3( 0.0 );
#ifdef USE_CLEARCOAT
	geometryClearcoatNormal = clearcoatNormal;
#endif
#ifdef USE_IRIDESCENCE
	float dotNVi = saturate( dot( normal, geometryViewDir ) );
	if ( material.iridescenceThickness == 0.0 ) {
		material.iridescence = 0.0;
	} else {
		material.iridescence = saturate( material.iridescence );
	}
	if ( material.iridescence > 0.0 ) {
		vec3 iridescenceFresnelDielectric = evalIridescence( 1.0, material.iridescenceIOR, dotNVi, material.iridescenceThickness, material.specularColor );
		vec3 iridescenceFresnelMetallic = evalIridescence( 1.0, material.iridescenceIOR, dotNVi, material.iridescenceThickness, material.diffuseColor );
		material.iridescenceFresnel = mix( iridescenceFresnelDielectric, iridescenceFresnelMetallic, material.metalness );
		material.iridescenceF0Dielectric = Schlick_to_F0( iridescenceFresnelDielectric, 1.0, dotNVi );
		material.iridescenceF0Metallic = Schlick_to_F0( iridescenceFresnelMetallic, 1.0, dotNVi );
	}
#endif
#ifdef STANDARD
	float dotNVms = saturate( dot( geometryNormal, geometryViewDir ) );
	material.dfg = texture2D( dfgLUT, vec2( material.roughness, dotNVms ) ).rg;
	#if ( NUM_SUN_LIGHTS > 0 || NUM_DIR_LIGHTS > 0 || NUM_POINT_LIGHTS > 0 || NUM_SPOT_LIGHTS > 0 )
		float EssMs = material.dfg.x + material.dfg.y;
		material.multiScatteringCompensation = 1.0 + material.specularColorBlended * ( 1.0 / EssMs - 1.0 );
	#endif
#endif
IncidentLight directLight;
#if ( NUM_POINT_LIGHTS > 0 ) && defined( RE_Direct )
	PointLight pointLight;
	#if defined( USE_SHADOWMAP ) && NUM_POINT_LIGHT_SHADOWS > 0
	PointLightShadow pointLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_POINT_LIGHTS; i ++ ) {
		pointLight = pointLights[ i ];
		getPointLightInfo( pointLight, geometryPosition, directLight );
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_POINT_LIGHT_SHADOWS ) && ( defined( SHADOWMAP_TYPE_PCF ) || defined( SHADOWMAP_TYPE_BASIC ) )
		pointLightShadow = pointLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getPointShadow( pointShadowMap[ i ], pointLightShadow.shadowMapSize, pointLightShadow.shadowIntensity, pointLightShadow.shadowBias, pointLightShadow.shadowRadius, vPointShadowCoord[ i ], pointLightShadow.shadowCameraNear, pointLightShadow.shadowCameraFar ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_SPOT_LIGHTS > 0 ) && defined( RE_Direct )
	SpotLight spotLight;
	vec4 spotColor;
	vec3 spotLightCoord;
	bool inSpotLightMap;
	#if defined( USE_SHADOWMAP ) && NUM_SPOT_LIGHT_SHADOWS > 0
	SpotLightShadow spotLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHTS; i ++ ) {
		spotLight = spotLights[ i ];
		getSpotLightInfo( spotLight, geometryPosition, directLight );
		#if ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS )
		#define SPOT_LIGHT_MAP_INDEX UNROLLED_LOOP_INDEX
		#elif ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
		#define SPOT_LIGHT_MAP_INDEX NUM_SPOT_LIGHT_MAPS
		#else
		#define SPOT_LIGHT_MAP_INDEX ( UNROLLED_LOOP_INDEX - NUM_SPOT_LIGHT_SHADOWS + NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS )
		#endif
		#if ( SPOT_LIGHT_MAP_INDEX < NUM_SPOT_LIGHT_MAPS )
			spotLightCoord = vSpotLightCoord[ i ].xyz / vSpotLightCoord[ i ].w;
			inSpotLightMap = all( lessThan( abs( spotLightCoord * 2. - 1. ), vec3( 1.0 ) ) );
			spotColor = texture2D( spotLightMap[ SPOT_LIGHT_MAP_INDEX ], spotLightCoord.xy );
			directLight.color = inSpotLightMap ? directLight.color * spotColor.rgb : directLight.color;
		#endif
		#undef SPOT_LIGHT_MAP_INDEX
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
		spotLightShadow = spotLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getShadow( spotShadowMap[ i ], spotLightShadow.shadowMapSize, spotLightShadow.shadowIntensity, spotLightShadow.shadowBias, spotLightShadow.shadowRadius, vSpotLightCoord[ i ] ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_SUN_LIGHTS > 0 ) && defined( RE_Direct )
	SunLight sunLight;
	#if defined( USE_SHADOWMAP ) && NUM_SUN_LIGHT_SHADOWS > 0
	SunLightShadow sunLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SUN_LIGHTS; i ++ ) {
		sunLight = sunLights[ i ];
		getSunLightInfo( sunLight, directLight );
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_SUN_LIGHT_SHADOWS )
		sunLightShadow = sunLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getSunShadow( sunShadowMap[ i ], sunLightShadow, UNROLLED_LOOP_INDEX ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_DIR_LIGHTS > 0 ) && defined( RE_Direct )
	DirectionalLight directionalLight;
	#if defined( USE_SHADOWMAP ) && NUM_DIR_LIGHT_SHADOWS > 0
	DirectionalLightShadow directionalLightShadow;
	#endif
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_DIR_LIGHTS; i ++ ) {
		directionalLight = directionalLights[ i ];
		getDirectionalLightInfo( directionalLight, directLight );
		#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_DIR_LIGHT_SHADOWS )
		directionalLightShadow = directionalLightShadows[ i ];
		directLight.color *= ( directLight.visible && receiveShadow ) ? getShadow( directionalShadowMap[ i ], directionalLightShadow.shadowMapSize, directionalLightShadow.shadowIntensity, directionalLightShadow.shadowBias, directionalLightShadow.shadowRadius, vDirectionalShadowCoord[ i ] ) : 1.0;
		#endif
		RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if ( NUM_RECT_AREA_LIGHTS > 0 ) && defined( RE_Direct_RectArea )
	RectAreaLight rectAreaLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_RECT_AREA_LIGHTS; i ++ ) {
		rectAreaLight = rectAreaLights[ i ];
		RE_Direct_RectArea( rectAreaLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
	}
	#pragma unroll_loop_end
#endif
#if defined( RE_IndirectDiffuse )
	vec3 iblIrradiance = vec3( 0.0 );
	vec3 irradiance = getAmbientLightIrradiance( ambientLightColor );
	#if defined( USE_LIGHT_PROBES )
		irradiance += getLightProbeIrradiance( lightProbe, geometryNormal );
	#endif
	#if ( NUM_HEMI_LIGHTS > 0 )
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_HEMI_LIGHTS; i ++ ) {
			irradiance += getHemisphereLightIrradiance( hemisphereLights[ i ], geometryNormal );
		}
		#pragma unroll_loop_end
	#endif
	#ifdef USE_LIGHT_PROBES_GRID
		vec3 probeWorldPos = ( ( vec4( geometryPosition, 1.0 ) - viewMatrix[ 3 ] ) * viewMatrix ).xyz;
		vec3 probeWorldNormal = transformNormalByInverseViewMatrix( geometryNormal, viewMatrix );
		irradiance += getLightProbeGridIrradiance( probeWorldPos, probeWorldNormal );
	#endif
#endif
#if defined( RE_IndirectSpecular )
	vec3 radiance = vec3( 0.0 );
	vec3 clearcoatRadiance = vec3( 0.0 );
#endif`,e1=`#if defined( RE_IndirectDiffuse )
	#ifdef USE_LIGHTMAP
		vec4 lightMapTexel = texture2D( lightMap, vLightMapUv );
		vec3 lightMapIrradiance = lightMapTexel.rgb * lightMapIntensity;
		irradiance += lightMapIrradiance;
	#endif
	#if defined( USE_ENVMAP ) && defined( ENVMAP_TYPE_CUBE_UV )
		#if defined( STANDARD ) || defined( LAMBERT ) || defined( PHONG )
			iblIrradiance += getIBLIrradiance( geometryNormal );
		#endif
	#endif
#endif
#if defined( USE_ENVMAP ) && defined( RE_IndirectSpecular )
	#ifdef USE_ANISOTROPY
		vec3 iblRadiance = getIBLAnisotropyRadiance( geometryViewDir, geometryNormal, material.roughness, material.anisotropyB, material.anisotropy );
	#else
		vec3 iblRadiance = getIBLRadiance( geometryViewDir, geometryNormal, material.roughness );
	#endif
	#ifdef USE_RETROREFLECTION
		#ifdef USE_ANISOTROPY
			vec3 retroIBLRadiance = getIBLAnisotropyRetroRadiance( geometryViewDir, geometryNormal, material.roughness, material.anisotropyB, material.anisotropy );
		#else
			vec3 retroIBLRadiance = getIBLRetroRadiance( geometryViewDir, geometryNormal, material.roughness );
		#endif
		iblRadiance = mix( iblRadiance, retroIBLRadiance, saturate( material.retroreflectivity ) );
	#endif
	radiance += iblRadiance;
	#ifdef USE_CLEARCOAT
		clearcoatRadiance += getIBLRadiance( geometryViewDir, geometryClearcoatNormal, material.clearcoatRoughness );
	#endif
#endif`,t1=`#if defined( RE_IndirectDiffuse )
	#if defined( LAMBERT ) || defined( PHONG )
		irradiance += iblIrradiance;
	#endif
	RE_IndirectDiffuse( irradiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif
#if defined( RE_IndirectSpecular )
	RE_IndirectSpecular( radiance, iblIrradiance, clearcoatRadiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif`,n1=`#ifdef USE_LIGHT_PROBES_GRID
uniform highp sampler3D probesSH;
uniform vec3 probesMin;
uniform vec3 probesMax;
uniform vec3 probesResolution;
vec3 getLightProbeGridIrradiance( vec3 worldPos, vec3 worldNormal ) {
	vec3 res = probesResolution;
	vec3 gridRange = probesMax - probesMin;
	vec3 resMinusOne = res - 1.0;
	vec3 probeSpacing = gridRange / resMinusOne;
	vec3 samplePos = worldPos + worldNormal * probeSpacing * 0.5;
	vec3 uvw = clamp( ( samplePos - probesMin ) / gridRange, 0.0, 1.0 );
	uvw = uvw * resMinusOne / res + 0.5 / res;
	float nz          = res.z;
	float paddedSlices = nz + 2.0;
	float atlasDepth  = 7.0 * paddedSlices;
	float uvZBase     = uvw.z * nz + 1.0;
	vec4 s0 = texture( probesSH, vec3( uvw.xy, ( uvZBase                       ) / atlasDepth ) );
	vec4 s1 = texture( probesSH, vec3( uvw.xy, ( uvZBase +       paddedSlices   ) / atlasDepth ) );
	vec4 s2 = texture( probesSH, vec3( uvw.xy, ( uvZBase + 2.0 * paddedSlices   ) / atlasDepth ) );
	vec4 s3 = texture( probesSH, vec3( uvw.xy, ( uvZBase + 3.0 * paddedSlices   ) / atlasDepth ) );
	vec4 s4 = texture( probesSH, vec3( uvw.xy, ( uvZBase + 4.0 * paddedSlices   ) / atlasDepth ) );
	vec4 s5 = texture( probesSH, vec3( uvw.xy, ( uvZBase + 5.0 * paddedSlices   ) / atlasDepth ) );
	vec4 s6 = texture( probesSH, vec3( uvw.xy, ( uvZBase + 6.0 * paddedSlices   ) / atlasDepth ) );
	vec3 c0 = s0.xyz;
	vec3 c1 = vec3( s0.w, s1.xy );
	vec3 c2 = vec3( s1.zw, s2.x );
	vec3 c3 = s2.yzw;
	vec3 c4 = s3.xyz;
	vec3 c5 = vec3( s3.w, s4.xy );
	vec3 c6 = vec3( s4.zw, s5.x );
	vec3 c7 = s5.yzw;
	vec3 c8 = s6.xyz;
	float x = worldNormal.x, y = worldNormal.y, z = worldNormal.z;
	vec3 result = c0 * 0.886227;
	result += c1 * 2.0 * 0.511664 * y;
	result += c2 * 2.0 * 0.511664 * z;
	result += c3 * 2.0 * 0.511664 * x;
	result += c4 * 2.0 * 0.429043 * x * y;
	result += c5 * 2.0 * 0.429043 * y * z;
	result += c6 * ( 0.743125 * z * z - 0.247708 );
	result += c7 * 2.0 * 0.429043 * x * z;
	result += c8 * 0.429043 * ( x * x - y * y );
	return max( result, vec3( 0.0 ) );
}
#endif`,i1=`#if defined( USE_LOGARITHMIC_DEPTH_BUFFER )
	gl_FragDepth = vIsPerspective == 0.0 ? gl_FragCoord.z : log2( vFragDepth ) * logDepthBufFC * 0.5;
#endif`,s1=`#if defined( USE_LOGARITHMIC_DEPTH_BUFFER )
	uniform float logDepthBufFC;
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,r1=`#ifdef USE_LOGARITHMIC_DEPTH_BUFFER
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,a1=`#ifdef USE_LOGARITHMIC_DEPTH_BUFFER
	vFragDepth = 1.0 + gl_Position.w;
	vIsPerspective = float( isPerspectiveMatrix( projectionMatrix ) );
#endif`,o1=`#ifdef USE_MAP
	vec4 sampledDiffuseColor = texture2D( map, vMapUv );
	#ifdef DECODE_VIDEO_TEXTURE
		sampledDiffuseColor = sRGBTransferEOTF( sampledDiffuseColor );
	#endif
	diffuseColor *= sampledDiffuseColor;
#endif`,l1=`#ifdef USE_MAP
	uniform sampler2D map;
#endif`,c1=`#if defined( USE_MAP ) || defined( USE_ALPHAMAP )
	#if defined( USE_POINTS_UV )
		vec2 uv = vUv;
	#else
		vec2 uv = ( uvTransform * vec3( gl_PointCoord.x, 1.0 - gl_PointCoord.y, 1 ) ).xy;
	#endif
#endif
#ifdef USE_MAP
	diffuseColor *= texture2D( map, uv );
#endif
#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture2D( alphaMap, uv ).g;
#endif`,h1=`#if defined( USE_POINTS_UV )
	varying vec2 vUv;
#else
	#if defined( USE_MAP ) || defined( USE_ALPHAMAP )
		uniform mat3 uvTransform;
	#endif
#endif
#ifdef USE_MAP
	uniform sampler2D map;
#endif
#ifdef USE_ALPHAMAP
	uniform sampler2D alphaMap;
#endif`,u1=`float metalnessFactor = metalness;
#ifdef USE_METALNESSMAP
	vec4 texelMetalness = texture2D( metalnessMap, vMetalnessMapUv );
	metalnessFactor *= texelMetalness.b;
#endif`,f1=`#ifdef USE_METALNESSMAP
	uniform sampler2D metalnessMap;
#endif`,d1=`#ifdef USE_INSTANCING_MORPH
	float morphTargetInfluences[ MORPHTARGETS_COUNT ];
	float morphTargetBaseInfluence = texelFetch( morphTexture, ivec2( 0, gl_InstanceID ), 0 ).r;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		morphTargetInfluences[i] =  texelFetch( morphTexture, ivec2( i + 1, gl_InstanceID ), 0 ).r;
	}
#endif`,p1=`#if defined( USE_MORPHCOLORS )
	vColor *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		#if defined( USE_COLOR_ALPHA )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ) * morphTargetInfluences[ i ];
		#elif defined( USE_COLOR )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ).rgb * morphTargetInfluences[ i ];
		#endif
	}
#endif`,m1=`#ifdef USE_MORPHNORMALS
	objectNormal *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) objectNormal += getMorph( gl_VertexID, i, 1 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,g1=`#ifdef USE_MORPHTARGETS
	#ifndef USE_INSTANCING_MORPH
		uniform float morphTargetBaseInfluence;
		uniform float morphTargetInfluences[ MORPHTARGETS_COUNT ];
	#endif
	uniform sampler2DArray morphTargetsTexture;
	uniform ivec2 morphTargetsTextureSize;
	vec4 getMorph( const in int vertexIndex, const in int morphTargetIndex, const in int offset ) {
		int texelIndex = vertexIndex * MORPHTARGETS_TEXTURE_STRIDE + offset;
		int y = texelIndex / morphTargetsTextureSize.x;
		int x = texelIndex - y * morphTargetsTextureSize.x;
		ivec3 morphUV = ivec3( x, y, morphTargetIndex );
		return texelFetch( morphTargetsTexture, morphUV, 0 );
	}
#endif`,_1=`#ifdef USE_MORPHTARGETS
	transformed *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) transformed += getMorph( gl_VertexID, i, 0 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,x1=`float faceDirection = gl_FrontFacing ? 1.0 : - 1.0;
#ifdef FLAT_SHADED
	vec3 fdx = dFdx( vViewPosition );
	vec3 fdy = dFdy( vViewPosition );
	vec3 normal = normalize( cross( fdx, fdy ) );
#else
	vec3 normal = normalize( vNormal );
	#ifdef DOUBLE_SIDED
		normal *= faceDirection;
	#endif
#endif
#if defined( USE_NORMALMAP_TANGENTSPACE ) || defined( USE_CLEARCOAT_NORMALMAP ) || defined( USE_ANISOTROPY )
	#ifdef USE_TANGENT
		mat3 tbn = mat3( normalize( vTangent ), normalize( vBitangent ), normal );
	#else
		mat3 tbn = getTangentFrame( - vViewPosition, normal,
		#if defined( USE_NORMALMAP )
			vNormalMapUv
		#elif defined( USE_CLEARCOAT_NORMALMAP )
			vClearcoatNormalMapUv
		#else
			vUv
		#endif
		);
	#endif
	#ifdef DOUBLE_SIDED
		tbn[0] *= faceDirection;
		tbn[1] *= faceDirection;
	#endif
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	#ifdef USE_TANGENT
		mat3 tbn2 = mat3( normalize( vTangent ), normalize( vBitangent ), normal );
	#else
		mat3 tbn2 = getTangentFrame( - vViewPosition, normal, vClearcoatNormalMapUv );
	#endif
	#ifdef DOUBLE_SIDED
		tbn2[0] *= faceDirection;
		tbn2[1] *= faceDirection;
	#endif
#endif
vec3 nonPerturbedNormal = normal;`,v1=`#ifdef USE_NORMALMAP_OBJECTSPACE
	normal = texture2D( normalMap, vNormalMapUv ).xyz * 2.0 - 1.0;
	#ifdef FLIP_SIDED
		normal = - normal;
	#endif
	#ifdef DOUBLE_SIDED
		normal = normal * faceDirection;
	#endif
	normal = normalize( normalMatrix * normal );
#elif defined( USE_NORMALMAP_TANGENTSPACE )
	vec3 mapN = texture2D( normalMap, vNormalMapUv ).xyz * 2.0 - 1.0;
	#if defined( USE_PACKED_NORMALMAP )
		mapN = vec3( mapN.xy, sqrt( saturate( 1.0 - dot( mapN.xy, mapN.xy ) ) ) );
	#endif
	mapN.xy *= normalScale;
	normal = normalize( tbn * mapN );
#elif defined( USE_BUMPMAP )
	normal = perturbNormalArb( - vViewPosition, normal, dHdxy_fwd(), faceDirection );
#endif`,y1=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,M1=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,S1=`#ifndef FLAT_SHADED
	vNormal = normalize( transformedNormal );
	#ifdef USE_TANGENT
		vTangent = normalize( transformedTangent );
		vBitangent = normalize( cross( vNormal, vTangent ) * tangent.w );
		#ifdef FLIP_SIDED
			vBitangent = - vBitangent;
		#endif
	#endif
#endif`,b1=`#ifdef USE_NORMALMAP
	uniform sampler2D normalMap;
	uniform vec2 normalScale;
#endif
#ifdef USE_NORMALMAP_OBJECTSPACE
	uniform mat3 normalMatrix;
#endif
#if ! defined ( USE_TANGENT ) && ( defined ( USE_NORMALMAP_TANGENTSPACE ) || defined ( USE_CLEARCOAT_NORMALMAP ) || defined( USE_ANISOTROPY ) )
	mat3 getTangentFrame( vec3 eye_pos, vec3 surf_norm, vec2 uv ) {
		vec3 q0 = dFdx( eye_pos.xyz );
		vec3 q1 = dFdy( eye_pos.xyz );
		vec2 st0 = dFdx( uv.st );
		vec2 st1 = dFdy( uv.st );
		vec3 N = surf_norm;
		vec3 q1perp = cross( q1, N );
		vec3 q0perp = cross( N, q0 );
		vec3 T = q1perp * st0.x + q0perp * st1.x;
		vec3 B = q1perp * st0.y + q0perp * st1.y;
		float det = max( dot( T, T ), dot( B, B ) );
		float scale = ( det == 0.0 ) ? 0.0 : inversesqrt( det );
		return mat3( T * scale, B * scale, N );
	}
#endif`,E1=`#ifdef USE_CLEARCOAT
	vec3 clearcoatNormal = nonPerturbedNormal;
#endif`,T1=`#ifdef USE_CLEARCOAT_NORMALMAP
	vec3 clearcoatMapN = texture2D( clearcoatNormalMap, vClearcoatNormalMapUv ).xyz * 2.0 - 1.0;
	clearcoatMapN.xy *= clearcoatNormalScale;
	clearcoatNormal = normalize( tbn2 * clearcoatMapN );
#endif`,w1=`#ifdef USE_CLEARCOATMAP
	uniform sampler2D clearcoatMap;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	uniform sampler2D clearcoatNormalMap;
	uniform vec2 clearcoatNormalScale;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	uniform sampler2D clearcoatRoughnessMap;
#endif`,A1=`#ifdef USE_IRIDESCENCEMAP
	uniform sampler2D iridescenceMap;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	uniform sampler2D iridescenceThicknessMap;
#endif`,R1=`#ifdef OPAQUE
diffuseColor.a = 1.0;
#endif
#ifdef USE_TRANSMISSION
diffuseColor.a *= material.transmissionAlpha;
#endif
gl_FragColor = vec4( outgoingLight, diffuseColor.a );`,C1=`vec3 packNormalToRGB( const in vec3 normal ) {
	return normalize( normal ) * 0.5 + 0.5;
}
vec3 unpackRGBToNormal( const in vec3 rgb ) {
	return 2.0 * rgb.xyz - 1.0;
}
const float PackUpscale = 256. / 255.;const float UnpackDownscale = 255. / 256.;const float ShiftRight8 = 1. / 256.;
const float Inv255 = 1. / 255.;
const vec4 PackFactors = vec4( 1.0, 256.0, 256.0 * 256.0, 256.0 * 256.0 * 256.0 );
const vec2 UnpackFactors2 = vec2( UnpackDownscale, 1.0 / PackFactors.g );
const vec3 UnpackFactors3 = vec3( UnpackDownscale / PackFactors.rg, 1.0 / PackFactors.b );
const vec4 UnpackFactors4 = vec4( UnpackDownscale / PackFactors.rgb, 1.0 / PackFactors.a );
vec4 packDepthToRGBA( const in float v ) {
	if( v <= 0.0 )
		return vec4( 0., 0., 0., 0. );
	if( v >= 1.0 )
		return vec4( 1., 1., 1., 1. );
	float vuf;
	float af = modf( v * PackFactors.a, vuf );
	float bf = modf( vuf * ShiftRight8, vuf );
	float gf = modf( vuf * ShiftRight8, vuf );
	return vec4( vuf * Inv255, gf * PackUpscale, bf * PackUpscale, af );
}
vec3 packDepthToRGB( const in float v ) {
	if( v <= 0.0 )
		return vec3( 0., 0., 0. );
	if( v >= 1.0 )
		return vec3( 1., 1., 1. );
	float vuf;
	float bf = modf( v * PackFactors.b, vuf );
	float gf = modf( vuf * ShiftRight8, vuf );
	return vec3( vuf * Inv255, gf * PackUpscale, bf );
}
vec2 packDepthToRG( const in float v ) {
	if( v <= 0.0 )
		return vec2( 0., 0. );
	if( v >= 1.0 )
		return vec2( 1., 1. );
	float vuf;
	float gf = modf( v * 256., vuf );
	return vec2( vuf * Inv255, gf );
}
float unpackRGBAToDepth( const in vec4 v ) {
	return dot( v, UnpackFactors4 );
}
float unpackRGBToDepth( const in vec3 v ) {
	return dot( v, UnpackFactors3 );
}
float unpackRGToDepth( const in vec2 v ) {
	return v.r * UnpackFactors2.r + v.g * UnpackFactors2.g;
}
vec4 pack2HalfToRGBA( const in vec2 v ) {
	vec4 r = vec4( v.x, fract( v.x * 255.0 ), v.y, fract( v.y * 255.0 ) );
	return vec4( r.x - r.y / 255.0, r.y, r.z - r.w / 255.0, r.w );
}
vec2 unpackRGBATo2Half( const in vec4 v ) {
	return vec2( v.x + ( v.y / 255.0 ), v.z + ( v.w / 255.0 ) );
}
float viewZToOrthographicDepth( const in float viewZ, const in float near, const in float far ) {
	return ( viewZ + near ) / ( near - far );
}
float orthographicDepthToViewZ( const in float depth, const in float near, const in float far ) {
	#ifdef USE_REVERSED_DEPTH_BUFFER
	
		return depth * ( far - near ) - far;
	#else
		return depth * ( near - far ) - near;
	#endif
}
float viewZToPerspectiveDepth( const in float viewZ, const in float near, const in float far ) {
	return ( ( near + viewZ ) * far ) / ( ( far - near ) * viewZ );
}
float perspectiveDepthToViewZ( const in float depth, const in float near, const in float far ) {
	
	#ifdef USE_REVERSED_DEPTH_BUFFER
		return ( near * far ) / ( ( near - far ) * depth - near );
	#else
		return ( near * far ) / ( ( far - near ) * depth - far );
	#endif
}`,P1=`#ifdef PREMULTIPLIED_ALPHA
	gl_FragColor.rgb *= gl_FragColor.a;
#endif`,I1=`vec4 mvPosition = vec4( transformed, 1.0 );
#ifdef USE_BATCHING
	mvPosition = batchingMatrix * mvPosition;
#endif
#ifdef USE_INSTANCING
	mvPosition = instanceMatrix * mvPosition;
#endif
mvPosition = modelViewMatrix * mvPosition;
gl_Position = projectionMatrix * mvPosition;`,L1=`#ifdef DITHERING
	gl_FragColor.rgb = dithering( gl_FragColor.rgb );
#endif`,D1=`#ifdef DITHERING
	vec3 dithering( vec3 color ) {
		float grid_position = rand( gl_FragCoord.xy );
		vec3 dither_shift_RGB = vec3( 0.25 / 255.0, -0.25 / 255.0, 0.25 / 255.0 );
		dither_shift_RGB = mix( 2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position );
		return color + dither_shift_RGB;
	}
#endif`,N1=`float roughnessFactor = roughness;
#ifdef USE_ROUGHNESSMAP
	vec4 texelRoughness = texture2D( roughnessMap, vRoughnessMapUv );
	roughnessFactor *= texelRoughness.g;
#endif`,U1=`#ifdef USE_ROUGHNESSMAP
	uniform sampler2D roughnessMap;
#endif`,F1=`#if NUM_SPOT_LIGHT_COORDS > 0
	varying vec4 vSpotLightCoord[ NUM_SPOT_LIGHT_COORDS ];
#endif
#if NUM_SPOT_LIGHT_MAPS > 0
	uniform sampler2D spotLightMap[ NUM_SPOT_LIGHT_MAPS ];
#endif
#ifdef USE_SHADOWMAP
	#if NUM_SUN_LIGHT_SHADOWS > 0
		#define SUN_LIGHT_CASCADES 2
		#if defined( SHADOWMAP_TYPE_PCF )
			uniform sampler2DShadow sunShadowMap[ NUM_SUN_LIGHT_SHADOWS ];
		#else
			uniform sampler2D sunShadowMap[ NUM_SUN_LIGHT_SHADOWS ];
		#endif
		uniform mat4 sunShadowMatrix[ NUM_SUN_LIGHT_SHADOWS * SUN_LIGHT_CASCADES ];
		uniform vec4 sunShadowCascade[ NUM_SUN_LIGHT_SHADOWS * SUN_LIGHT_CASCADES ];
		varying vec4 vSunShadowWorldPosition;
		varying vec3 vSunShadowWorldNormal;
		struct SunLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform SunLightShadow sunLightShadows[ NUM_SUN_LIGHT_SHADOWS ];
	#endif
	#if NUM_DIR_LIGHT_SHADOWS > 0
		#if defined( SHADOWMAP_TYPE_PCF )
			uniform sampler2DShadow directionalShadowMap[ NUM_DIR_LIGHT_SHADOWS ];
		#else
			uniform sampler2D directionalShadowMap[ NUM_DIR_LIGHT_SHADOWS ];
		#endif
		varying vec4 vDirectionalShadowCoord[ NUM_DIR_LIGHT_SHADOWS ];
		struct DirectionalLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform DirectionalLightShadow directionalLightShadows[ NUM_DIR_LIGHT_SHADOWS ];
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
		#if defined( SHADOWMAP_TYPE_PCF )
			uniform sampler2DShadow spotShadowMap[ NUM_SPOT_LIGHT_SHADOWS ];
		#else
			uniform sampler2D spotShadowMap[ NUM_SPOT_LIGHT_SHADOWS ];
		#endif
		struct SpotLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform SpotLightShadow spotLightShadows[ NUM_SPOT_LIGHT_SHADOWS ];
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		#if defined( SHADOWMAP_TYPE_PCF )
			uniform samplerCubeShadow pointShadowMap[ NUM_POINT_LIGHT_SHADOWS ];
		#elif defined( SHADOWMAP_TYPE_BASIC )
			uniform samplerCube pointShadowMap[ NUM_POINT_LIGHT_SHADOWS ];
		#endif
		varying vec4 vPointShadowCoord[ NUM_POINT_LIGHT_SHADOWS ];
		struct PointLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
			float shadowCameraNear;
			float shadowCameraFar;
		};
		uniform PointLightShadow pointLightShadows[ NUM_POINT_LIGHT_SHADOWS ];
	#endif
	#if defined( SHADOWMAP_TYPE_PCF )
		float interleavedGradientNoise( vec2 position ) {
			return fract( 52.9829189 * fract( dot( position, vec2( 0.06711056, 0.00583715 ) ) ) );
		}
		vec2 vogelDiskSample( int sampleIndex, int samplesCount, float phi ) {
			const float goldenAngle = 2.399963229728653;
			float r = sqrt( ( float( sampleIndex ) + 0.5 ) / float( samplesCount ) );
			float theta = float( sampleIndex ) * goldenAngle + phi;
			return vec2( cos( theta ), sin( theta ) ) * r;
		}
	#endif
	#if defined( SHADOWMAP_TYPE_PCF )
		float getShadow( sampler2DShadow shadowMap, vec2 shadowMapSize, float shadowIntensity, float shadowBias, float shadowRadius, vec4 shadowCoord ) {
			float shadow = 1.0;
			shadowCoord.xyz /= shadowCoord.w;
			shadowCoord.z += shadowBias;
			bool inFrustum = shadowCoord.x >= 0.0 && shadowCoord.x <= 1.0 && shadowCoord.y >= 0.0 && shadowCoord.y <= 1.0;
			bool frustumTest = inFrustum && shadowCoord.z <= 1.0;
			if ( frustumTest ) {
				vec2 texelSize = vec2( 1.0 ) / shadowMapSize;
				float radius = shadowRadius * texelSize.x;
				float phi = interleavedGradientNoise( gl_FragCoord.xy ) * PI2;
				shadow = (
					texture( shadowMap, vec3( shadowCoord.xy + vogelDiskSample( 0, 5, phi ) * radius, shadowCoord.z ) ) +
					texture( shadowMap, vec3( shadowCoord.xy + vogelDiskSample( 1, 5, phi ) * radius, shadowCoord.z ) ) +
					texture( shadowMap, vec3( shadowCoord.xy + vogelDiskSample( 2, 5, phi ) * radius, shadowCoord.z ) ) +
					texture( shadowMap, vec3( shadowCoord.xy + vogelDiskSample( 3, 5, phi ) * radius, shadowCoord.z ) ) +
					texture( shadowMap, vec3( shadowCoord.xy + vogelDiskSample( 4, 5, phi ) * radius, shadowCoord.z ) )
				) * 0.2;
			}
			return mix( 1.0, shadow, shadowIntensity );
		}
	#elif defined( SHADOWMAP_TYPE_VSM )
		float getShadow( sampler2D shadowMap, vec2 shadowMapSize, float shadowIntensity, float shadowBias, float shadowRadius, vec4 shadowCoord ) {
			float shadow = 1.0;
			shadowCoord.xyz /= shadowCoord.w;
			#ifdef USE_REVERSED_DEPTH_BUFFER
				shadowCoord.z -= shadowBias;
			#else
				shadowCoord.z += shadowBias;
			#endif
			bool inFrustum = shadowCoord.x >= 0.0 && shadowCoord.x <= 1.0 && shadowCoord.y >= 0.0 && shadowCoord.y <= 1.0;
			bool frustumTest = inFrustum && shadowCoord.z <= 1.0;
			if ( frustumTest ) {
				vec2 distribution = texture2D( shadowMap, shadowCoord.xy ).rg;
				float mean = distribution.x;
				float variance = distribution.y * distribution.y;
				#ifdef USE_REVERSED_DEPTH_BUFFER
					float hard_shadow = step( mean, shadowCoord.z );
				#else
					float hard_shadow = step( shadowCoord.z, mean );
				#endif
				
				if ( hard_shadow == 1.0 ) {
					shadow = 1.0;
				} else {
					variance = max( variance, 0.0000001 );
					float d = shadowCoord.z - mean;
					float p_max = variance / ( variance + d * d );
					p_max = clamp( ( p_max - 0.3 ) / 0.65, 0.0, 1.0 );
					shadow = max( hard_shadow, p_max );
				}
			}
			return mix( 1.0, shadow, shadowIntensity );
		}
	#else
		float getShadow( sampler2D shadowMap, vec2 shadowMapSize, float shadowIntensity, float shadowBias, float shadowRadius, vec4 shadowCoord ) {
			float shadow = 1.0;
			shadowCoord.xyz /= shadowCoord.w;
			#ifdef USE_REVERSED_DEPTH_BUFFER
				shadowCoord.z -= shadowBias;
			#else
				shadowCoord.z += shadowBias;
			#endif
			bool inFrustum = shadowCoord.x >= 0.0 && shadowCoord.x <= 1.0 && shadowCoord.y >= 0.0 && shadowCoord.y <= 1.0;
			bool frustumTest = inFrustum && shadowCoord.z <= 1.0;
			if ( frustumTest ) {
				float depth = texture2D( shadowMap, shadowCoord.xy ).r;
				#ifdef USE_REVERSED_DEPTH_BUFFER
					shadow = step( depth, shadowCoord.z );
				#else
					shadow = step( shadowCoord.z, depth );
				#endif
			}
			return mix( 1.0, shadow, shadowIntensity );
		}
	#endif
	#if NUM_SUN_LIGHT_SHADOWS > 0
		float getSunShadow(
			#if defined( SHADOWMAP_TYPE_PCF )
				sampler2DShadow shadowMap,
			#else
				sampler2D shadowMap,
			#endif
			SunLightShadow sunLightShadow,
			int shadowIndex
		) {
			vec4 shadowWorldPosition = vec4( vSunShadowWorldPosition.xyz + vSunShadowWorldNormal * sunLightShadow.shadowNormalBias, 1.0 );
			float viewDepth = vSunShadowWorldPosition.w;
			int cascadeOffset = shadowIndex * SUN_LIGHT_CASCADES;
			float shadow = 1.0;
			for ( int i = SUN_LIGHT_CASCADES - 1; i >= 0; i -- ) {
				vec4 cascade = sunShadowCascade[ cascadeOffset + i ];
				if ( viewDepth >= cascade.x && viewDepth < cascade.y ) {
					float cascadeShadow = getShadow(
						shadowMap,
						sunLightShadow.shadowMapSize,
						sunLightShadow.shadowIntensity,
						sunLightShadow.shadowBias,
						sunLightShadow.shadowRadius,
						sunShadowMatrix[ cascadeOffset + i ] * shadowWorldPosition
					);
					shadow = mix( cascadeShadow, shadow, smoothstep( cascade.z, cascade.y, viewDepth ) );
				}
			}
			return shadow;
		}
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
	#if defined( SHADOWMAP_TYPE_PCF )
	float getPointShadow( samplerCubeShadow shadowMap, vec2 shadowMapSize, float shadowIntensity, float shadowBias, float shadowRadius, vec4 shadowCoord, float shadowCameraNear, float shadowCameraFar ) {
		float shadow = 1.0;
		vec3 lightToPosition = shadowCoord.xyz;
		vec3 bd3D = normalize( lightToPosition );
		vec3 absVec = abs( lightToPosition );
		float viewSpaceZ = max( max( absVec.x, absVec.y ), absVec.z );
		if ( viewSpaceZ - shadowCameraFar <= 0.0 && viewSpaceZ - shadowCameraNear >= 0.0 ) {
			#ifdef USE_REVERSED_DEPTH_BUFFER
				float dp = ( shadowCameraNear * ( shadowCameraFar - viewSpaceZ ) ) / ( viewSpaceZ * ( shadowCameraFar - shadowCameraNear ) );
				dp -= shadowBias;
			#else
				float dp = ( shadowCameraFar * ( viewSpaceZ - shadowCameraNear ) ) / ( viewSpaceZ * ( shadowCameraFar - shadowCameraNear ) );
				dp += shadowBias;
			#endif
			float texelSize = shadowRadius / shadowMapSize.x;
			vec3 absDir = abs( bd3D );
			vec3 tangent = absDir.x > absDir.z ? vec3( 0.0, 1.0, 0.0 ) : vec3( 1.0, 0.0, 0.0 );
			tangent = normalize( cross( bd3D, tangent ) );
			vec3 bitangent = cross( bd3D, tangent );
			float phi = interleavedGradientNoise( gl_FragCoord.xy ) * PI2;
			vec2 sample0 = vogelDiskSample( 0, 5, phi );
			vec2 sample1 = vogelDiskSample( 1, 5, phi );
			vec2 sample2 = vogelDiskSample( 2, 5, phi );
			vec2 sample3 = vogelDiskSample( 3, 5, phi );
			vec2 sample4 = vogelDiskSample( 4, 5, phi );
			shadow = (
				texture( shadowMap, vec4( bd3D + ( tangent * sample0.x + bitangent * sample0.y ) * texelSize, dp ) ) +
				texture( shadowMap, vec4( bd3D + ( tangent * sample1.x + bitangent * sample1.y ) * texelSize, dp ) ) +
				texture( shadowMap, vec4( bd3D + ( tangent * sample2.x + bitangent * sample2.y ) * texelSize, dp ) ) +
				texture( shadowMap, vec4( bd3D + ( tangent * sample3.x + bitangent * sample3.y ) * texelSize, dp ) ) +
				texture( shadowMap, vec4( bd3D + ( tangent * sample4.x + bitangent * sample4.y ) * texelSize, dp ) )
			) * 0.2;
		}
		return mix( 1.0, shadow, shadowIntensity );
	}
	#elif defined( SHADOWMAP_TYPE_BASIC )
	float getPointShadow( samplerCube shadowMap, vec2 shadowMapSize, float shadowIntensity, float shadowBias, float shadowRadius, vec4 shadowCoord, float shadowCameraNear, float shadowCameraFar ) {
		float shadow = 1.0;
		vec3 lightToPosition = shadowCoord.xyz;
		vec3 absVec = abs( lightToPosition );
		float viewSpaceZ = max( max( absVec.x, absVec.y ), absVec.z );
		if ( viewSpaceZ - shadowCameraFar <= 0.0 && viewSpaceZ - shadowCameraNear >= 0.0 ) {
			float dp = ( shadowCameraFar * ( viewSpaceZ - shadowCameraNear ) ) / ( viewSpaceZ * ( shadowCameraFar - shadowCameraNear ) );
			dp += shadowBias;
			vec3 bd3D = normalize( lightToPosition );
			float depth = textureCube( shadowMap, bd3D ).r;
			#ifdef USE_REVERSED_DEPTH_BUFFER
				depth = 1.0 - depth;
			#endif
			shadow = step( dp, depth );
		}
		return mix( 1.0, shadow, shadowIntensity );
	}
	#endif
	#endif
#endif`,O1=`#if NUM_SPOT_LIGHT_COORDS > 0
	uniform mat4 spotLightMatrix[ NUM_SPOT_LIGHT_COORDS ];
	varying vec4 vSpotLightCoord[ NUM_SPOT_LIGHT_COORDS ];
#endif
#ifdef USE_SHADOWMAP
	#if NUM_SUN_LIGHT_SHADOWS > 0
		varying vec4 vSunShadowWorldPosition;
		varying vec3 vSunShadowWorldNormal;
	#endif
	#if NUM_DIR_LIGHT_SHADOWS > 0
		uniform mat4 directionalShadowMatrix[ NUM_DIR_LIGHT_SHADOWS ];
		varying vec4 vDirectionalShadowCoord[ NUM_DIR_LIGHT_SHADOWS ];
		struct DirectionalLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform DirectionalLightShadow directionalLightShadows[ NUM_DIR_LIGHT_SHADOWS ];
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
		struct SpotLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
		uniform SpotLightShadow spotLightShadows[ NUM_SPOT_LIGHT_SHADOWS ];
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		uniform mat4 pointShadowMatrix[ NUM_POINT_LIGHT_SHADOWS ];
		varying vec4 vPointShadowCoord[ NUM_POINT_LIGHT_SHADOWS ];
		struct PointLightShadow {
			float shadowIntensity;
			float shadowBias;
			float shadowNormalBias;
			float shadowRadius;
			vec2 shadowMapSize;
			float shadowCameraNear;
			float shadowCameraFar;
		};
		uniform PointLightShadow pointLightShadows[ NUM_POINT_LIGHT_SHADOWS ];
	#endif
#endif`,B1=`#if ( defined( USE_SHADOWMAP ) && ( NUM_DIR_LIGHT_SHADOWS > 0 || NUM_SUN_LIGHT_SHADOWS > 0 || NUM_POINT_LIGHT_SHADOWS > 0 ) ) || ( NUM_SPOT_LIGHT_COORDS > 0 )
	#ifdef HAS_NORMAL
		vec3 shadowWorldNormal = transformNormalByInverseViewMatrix( transformedNormal, viewMatrix );
	#else
		vec3 shadowWorldNormal = vec3( 0.0 );
	#endif
	vec4 shadowWorldPosition;
#endif
#if defined( USE_SHADOWMAP )
	#if NUM_SUN_LIGHT_SHADOWS > 0
		vSunShadowWorldPosition = vec4( worldPosition.xyz, - mvPosition.z );
		vSunShadowWorldNormal = shadowWorldNormal;
	#endif
	#if NUM_DIR_LIGHT_SHADOWS > 0
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_DIR_LIGHT_SHADOWS; i ++ ) {
			shadowWorldPosition = worldPosition + vec4( shadowWorldNormal * directionalLightShadows[ i ].shadowNormalBias, 0 );
			vDirectionalShadowCoord[ i ] = directionalShadowMatrix[ i ] * shadowWorldPosition;
		}
		#pragma unroll_loop_end
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0
		#pragma unroll_loop_start
		for ( int i = 0; i < NUM_POINT_LIGHT_SHADOWS; i ++ ) {
			shadowWorldPosition = worldPosition + vec4( shadowWorldNormal * pointLightShadows[ i ].shadowNormalBias, 0 );
			vPointShadowCoord[ i ] = pointShadowMatrix[ i ] * shadowWorldPosition;
		}
		#pragma unroll_loop_end
	#endif
#endif
#if NUM_SPOT_LIGHT_COORDS > 0
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHT_COORDS; i ++ ) {
		shadowWorldPosition = worldPosition;
		#if ( defined( USE_SHADOWMAP ) && UNROLLED_LOOP_INDEX < NUM_SPOT_LIGHT_SHADOWS )
			shadowWorldPosition.xyz += shadowWorldNormal * spotLightShadows[ i ].shadowNormalBias;
		#endif
		vSpotLightCoord[ i ] = spotLightMatrix[ i ] * shadowWorldPosition;
	}
	#pragma unroll_loop_end
#endif`,z1=`float getShadowMask() {
	float shadow = 1.0;
	#ifdef USE_SHADOWMAP
	#if NUM_SUN_LIGHT_SHADOWS > 0
	SunLightShadow sunLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SUN_LIGHT_SHADOWS; i ++ ) {
		sunLight = sunLightShadows[ i ];
		shadow *= receiveShadow ? getSunShadow( sunShadowMap[ i ], sunLight, UNROLLED_LOOP_INDEX ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#if NUM_DIR_LIGHT_SHADOWS > 0
	DirectionalLightShadow directionalLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_DIR_LIGHT_SHADOWS; i ++ ) {
		directionalLight = directionalLightShadows[ i ];
		shadow *= receiveShadow ? getShadow( directionalShadowMap[ i ], directionalLight.shadowMapSize, directionalLight.shadowIntensity, directionalLight.shadowBias, directionalLight.shadowRadius, vDirectionalShadowCoord[ i ] ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
	SpotLightShadow spotLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_SPOT_LIGHT_SHADOWS; i ++ ) {
		spotLight = spotLightShadows[ i ];
		shadow *= receiveShadow ? getShadow( spotShadowMap[ i ], spotLight.shadowMapSize, spotLight.shadowIntensity, spotLight.shadowBias, spotLight.shadowRadius, vSpotLightCoord[ i ] ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#if NUM_POINT_LIGHT_SHADOWS > 0 && ( defined( SHADOWMAP_TYPE_PCF ) || defined( SHADOWMAP_TYPE_BASIC ) )
	PointLightShadow pointLight;
	#pragma unroll_loop_start
	for ( int i = 0; i < NUM_POINT_LIGHT_SHADOWS; i ++ ) {
		pointLight = pointLightShadows[ i ];
		shadow *= receiveShadow ? getPointShadow( pointShadowMap[ i ], pointLight.shadowMapSize, pointLight.shadowIntensity, pointLight.shadowBias, pointLight.shadowRadius, vPointShadowCoord[ i ], pointLight.shadowCameraNear, pointLight.shadowCameraFar ) : 1.0;
	}
	#pragma unroll_loop_end
	#endif
	#endif
	return shadow;
}`,H1=`#ifdef USE_SKINNING
	mat4 boneMatX = getBoneMatrix( skinIndex.x );
	mat4 boneMatY = getBoneMatrix( skinIndex.y );
	mat4 boneMatZ = getBoneMatrix( skinIndex.z );
	mat4 boneMatW = getBoneMatrix( skinIndex.w );
#endif`,k1=`#ifdef USE_SKINNING
	uniform mat4 bindMatrix;
	uniform mat4 bindMatrixInverse;
	uniform highp sampler2D boneTexture;
	mat4 getBoneMatrix( const in float i ) {
		int size = textureSize( boneTexture, 0 ).x;
		int j = int( i ) * 4;
		int x = j % size;
		int y = j / size;
		vec4 v1 = texelFetch( boneTexture, ivec2( x, y ), 0 );
		vec4 v2 = texelFetch( boneTexture, ivec2( x + 1, y ), 0 );
		vec4 v3 = texelFetch( boneTexture, ivec2( x + 2, y ), 0 );
		vec4 v4 = texelFetch( boneTexture, ivec2( x + 3, y ), 0 );
		return mat4( v1, v2, v3, v4 );
	}
#endif`,V1=`#ifdef USE_SKINNING
	vec4 skinVertex = bindMatrix * vec4( transformed, 1.0 );
	vec4 skinned = vec4( 0.0 );
	skinned += boneMatX * skinVertex * skinWeight.x;
	skinned += boneMatY * skinVertex * skinWeight.y;
	skinned += boneMatZ * skinVertex * skinWeight.z;
	skinned += boneMatW * skinVertex * skinWeight.w;
	transformed = ( bindMatrixInverse * skinned ).xyz;
#endif`,G1=`#ifdef USE_SKINNING
	mat4 skinMatrix = mat4( 0.0 );
	skinMatrix += skinWeight.x * boneMatX;
	skinMatrix += skinWeight.y * boneMatY;
	skinMatrix += skinWeight.z * boneMatZ;
	skinMatrix += skinWeight.w * boneMatW;
	skinMatrix = bindMatrixInverse * skinMatrix * bindMatrix;
	objectNormal = vec4( skinMatrix * vec4( objectNormal, 0.0 ) ).xyz;
	#ifdef USE_TANGENT
		objectTangent = vec4( skinMatrix * vec4( objectTangent, 0.0 ) ).xyz;
	#endif
#endif`,W1=`float specularStrength;
#ifdef USE_SPECULARMAP
	vec4 texelSpecular = texture2D( specularMap, vSpecularMapUv );
	specularStrength = texelSpecular.r;
#else
	specularStrength = 1.0;
#endif`,X1=`#ifdef USE_SPECULARMAP
	uniform sampler2D specularMap;
#endif`,q1=`#if defined( TONE_MAPPING )
	gl_FragColor.rgb = toneMapping( gl_FragColor.rgb );
#endif`,Y1=`#ifndef saturate
#define saturate( a ) clamp( a, 0.0, 1.0 )
#endif
uniform float toneMappingExposure;
vec3 LinearToneMapping( vec3 color ) {
	return saturate( toneMappingExposure * color );
}
vec3 ReinhardToneMapping( vec3 color ) {
	color *= toneMappingExposure;
	return saturate( color / ( vec3( 1.0 ) + color ) );
}
vec3 CineonToneMapping( vec3 color ) {
	color *= toneMappingExposure;
	color = max( vec3( 0.0 ), color - 0.004 );
	return pow( ( color * ( 6.2 * color + 0.5 ) ) / ( color * ( 6.2 * color + 1.7 ) + 0.06 ), vec3( 2.2 ) );
}
vec3 RRTAndODTFit( vec3 v ) {
	vec3 a = v * ( v + 0.0245786 ) - 0.000090537;
	vec3 b = v * ( 0.983729 * v + 0.4329510 ) + 0.238081;
	return a / b;
}
vec3 ACESFilmicToneMapping( vec3 color ) {
	const mat3 ACESInputMat = mat3(
		vec3( 0.59719, 0.07600, 0.02840 ),		vec3( 0.35458, 0.90834, 0.13383 ),
		vec3( 0.04823, 0.01566, 0.83777 )
	);
	const mat3 ACESOutputMat = mat3(
		vec3(  1.60475, -0.10208, -0.00327 ),		vec3( -0.53108,  1.10813, -0.07276 ),
		vec3( -0.07367, -0.00605,  1.07602 )
	);
	color *= toneMappingExposure / 0.6;
	color = ACESInputMat * color;
	color = RRTAndODTFit( color );
	color = ACESOutputMat * color;
	return saturate( color );
}
const mat3 LINEAR_REC2020_TO_LINEAR_SRGB = mat3(
	vec3( 1.6605, - 0.1246, - 0.0182 ),
	vec3( - 0.5876, 1.1329, - 0.1006 ),
	vec3( - 0.0728, - 0.0083, 1.1187 )
);
const mat3 LINEAR_SRGB_TO_LINEAR_REC2020 = mat3(
	vec3( 0.6274, 0.0691, 0.0164 ),
	vec3( 0.3293, 0.9195, 0.0880 ),
	vec3( 0.0433, 0.0113, 0.8956 )
);
vec3 agxDefaultContrastApprox( vec3 x ) {
	vec3 x2 = x * x;
	vec3 x4 = x2 * x2;
	return + 15.5 * x4 * x2
		- 40.14 * x4 * x
		+ 31.96 * x4
		- 6.868 * x2 * x
		+ 0.4298 * x2
		+ 0.1191 * x
		- 0.00232;
}
vec3 AgXToneMapping( vec3 color ) {
	const mat3 AgXInsetMatrix = mat3(
		vec3( 0.856627153315983, 0.137318972929847, 0.11189821299995 ),
		vec3( 0.0951212405381588, 0.761241990602591, 0.0767994186031903 ),
		vec3( 0.0482516061458583, 0.101439036467562, 0.811302368396859 )
	);
	const mat3 AgXOutsetMatrix = mat3(
		vec3( 1.1271005818144368, - 0.1413297634984383, - 0.14132976349843826 ),
		vec3( - 0.11060664309660323, 1.157823702216272, - 0.11060664309660294 ),
		vec3( - 0.016493938717834573, - 0.016493938717834257, 1.2519364065950405 )
	);
	const float AgxMinEv = - 12.47393;	const float AgxMaxEv = 4.026069;
	color *= toneMappingExposure;
	color = LINEAR_SRGB_TO_LINEAR_REC2020 * color;
	color = AgXInsetMatrix * color;
	color = max( color, 1e-10 );	color = log2( color );
	color = ( color - AgxMinEv ) / ( AgxMaxEv - AgxMinEv );
	color = clamp( color, 0.0, 1.0 );
	color = agxDefaultContrastApprox( color );
	color = AgXOutsetMatrix * color;
	color = pow( max( vec3( 0.0 ), color ), vec3( 2.2 ) );
	color = LINEAR_REC2020_TO_LINEAR_SRGB * color;
	color = clamp( color, 0.0, 1.0 );
	return color;
}
vec3 NeutralToneMapping( vec3 color ) {
	const float StartCompression = 0.8 - 0.04;
	const float Desaturation = 0.15;
	color *= toneMappingExposure;
	float x = min( color.r, min( color.g, color.b ) );
	float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
	color -= offset;
	float peak = max( color.r, max( color.g, color.b ) );
	if ( peak < StartCompression ) return color;
	float d = 1. - StartCompression;
	float newPeak = 1. - d * d / ( peak + d - StartCompression );
	color *= newPeak / peak;
	float g = 1. - 1. / ( Desaturation * ( peak - newPeak ) + 1. );
	return mix( color, vec3( newPeak ), g );
}
vec3 CustomToneMapping( vec3 color ) { return color; }`,$1=`#ifdef USE_TRANSMISSION
	material.transmission = transmission;
	material.transmissionAlpha = 1.0;
	material.thickness = thickness;
	material.attenuationDistance = attenuationDistance;
	material.attenuationColor = attenuationColor;
	#ifdef USE_TRANSMISSIONMAP
		material.transmission *= texture2D( transmissionMap, vTransmissionMapUv ).r;
	#endif
	#ifdef USE_THICKNESSMAP
		material.thickness *= texture2D( thicknessMap, vThicknessMapUv ).g;
	#endif
	vec3 pos = vWorldPosition;
	vec3 v = normalize( cameraPosition - pos );
	vec3 n = transformNormalByInverseViewMatrix( normal, viewMatrix );
	vec4 transmitted = getIBLVolumeRefraction(
		n, v, material.roughness, material.diffuseContribution, material.specularColorBlended, material.specularF90,
		pos, modelMatrix, viewMatrix, projectionMatrix, material.dispersion, material.ior, material.thickness,
		material.attenuationColor, material.attenuationDistance );
	material.transmissionAlpha = mix( material.transmissionAlpha, transmitted.a, material.transmission );
	totalDiffuse = mix( totalDiffuse, transmitted.rgb, material.transmission );
#endif`,Z1=`#ifdef USE_TRANSMISSION
	uniform float transmission;
	uniform float thickness;
	uniform float attenuationDistance;
	uniform vec3 attenuationColor;
	#ifdef USE_TRANSMISSIONMAP
		uniform sampler2D transmissionMap;
	#endif
	#ifdef USE_THICKNESSMAP
		uniform sampler2D thicknessMap;
	#endif
	uniform vec2 transmissionSamplerSize;
	uniform sampler2D transmissionSamplerMap;
	uniform mat4 modelMatrix;
	uniform mat4 projectionMatrix;
	varying vec3 vWorldPosition;
	float w0( float a ) {
		return ( 1.0 / 6.0 ) * ( a * ( a * ( - a + 3.0 ) - 3.0 ) + 1.0 );
	}
	float w1( float a ) {
		return ( 1.0 / 6.0 ) * ( a *  a * ( 3.0 * a - 6.0 ) + 4.0 );
	}
	float w2( float a ){
		return ( 1.0 / 6.0 ) * ( a * ( a * ( - 3.0 * a + 3.0 ) + 3.0 ) + 1.0 );
	}
	float w3( float a ) {
		return ( 1.0 / 6.0 ) * ( a * a * a );
	}
	float g0( float a ) {
		return w0( a ) + w1( a );
	}
	float g1( float a ) {
		return w2( a ) + w3( a );
	}
	float h0( float a ) {
		return - 1.0 + w1( a ) / ( w0( a ) + w1( a ) );
	}
	float h1( float a ) {
		return 1.0 + w3( a ) / ( w2( a ) + w3( a ) );
	}
	vec4 bicubic( sampler2D tex, vec2 uv, vec4 texelSize, float lod ) {
		uv = uv * texelSize.zw + 0.5;
		vec2 iuv = floor( uv );
		vec2 fuv = fract( uv );
		float g0x = g0( fuv.x );
		float g1x = g1( fuv.x );
		float h0x = h0( fuv.x );
		float h1x = h1( fuv.x );
		float h0y = h0( fuv.y );
		float h1y = h1( fuv.y );
		vec2 p0 = ( vec2( iuv.x + h0x, iuv.y + h0y ) - 0.5 ) * texelSize.xy;
		vec2 p1 = ( vec2( iuv.x + h1x, iuv.y + h0y ) - 0.5 ) * texelSize.xy;
		vec2 p2 = ( vec2( iuv.x + h0x, iuv.y + h1y ) - 0.5 ) * texelSize.xy;
		vec2 p3 = ( vec2( iuv.x + h1x, iuv.y + h1y ) - 0.5 ) * texelSize.xy;
		return g0( fuv.y ) * ( g0x * textureLod( tex, p0, lod ) + g1x * textureLod( tex, p1, lod ) ) +
			g1( fuv.y ) * ( g0x * textureLod( tex, p2, lod ) + g1x * textureLod( tex, p3, lod ) );
	}
	vec4 textureBicubic( sampler2D sampler, vec2 uv, float lod ) {
		vec2 fLodSize = vec2( textureSize( sampler, int( lod ) ) );
		vec2 cLodSize = vec2( textureSize( sampler, int( lod + 1.0 ) ) );
		vec2 fLodSizeInv = 1.0 / fLodSize;
		vec2 cLodSizeInv = 1.0 / cLodSize;
		vec4 fSample = bicubic( sampler, uv, vec4( fLodSizeInv, fLodSize ), floor( lod ) );
		vec4 cSample = bicubic( sampler, uv, vec4( cLodSizeInv, cLodSize ), ceil( lod ) );
		return mix( fSample, cSample, fract( lod ) );
	}
	vec3 getVolumeTransmissionRay( const in vec3 n, const in vec3 v, const in float thickness, const in float ior, const in mat4 modelMatrix ) {
		vec3 refractionVector = refract( - v, normalize( n ), 1.0 / ior );
		vec3 modelScale;
		modelScale.x = length( vec3( modelMatrix[ 0 ].xyz ) );
		modelScale.y = length( vec3( modelMatrix[ 1 ].xyz ) );
		modelScale.z = length( vec3( modelMatrix[ 2 ].xyz ) );
		return normalize( refractionVector ) * thickness * modelScale;
	}
	float applyIorToRoughness( const in float roughness, const in float ior ) {
		return roughness * clamp( ior * 2.0 - 2.0, 0.0, 1.0 );
	}
	vec4 getTransmissionSample( const in vec2 fragCoord, const in float roughness, const in float ior ) {
		float lod = log2( transmissionSamplerSize.x ) * applyIorToRoughness( roughness, ior );
		return textureBicubic( transmissionSamplerMap, fragCoord.xy, lod );
	}
	vec3 volumeAttenuation( const in float transmissionDistance, const in vec3 attenuationColor, const in float attenuationDistance ) {
		if ( isinf( attenuationDistance ) ) {
			return vec3( 1.0 );
		} else {
			vec3 attenuationCoefficient = -log( attenuationColor ) / attenuationDistance;
			vec3 transmittance = exp( - attenuationCoefficient * transmissionDistance );			return transmittance;
		}
	}
	vec4 getIBLVolumeRefraction( const in vec3 n, const in vec3 v, const in float roughness, const in vec3 diffuseColor,
		const in vec3 specularColor, const in float specularF90, const in vec3 position, const in mat4 modelMatrix,
		const in mat4 viewMatrix, const in mat4 projMatrix, const in float dispersion, const in float ior, const in float thickness,
		const in vec3 attenuationColor, const in float attenuationDistance ) {
		vec4 transmittedLight;
		vec3 transmittance;
		#ifdef USE_DISPERSION
			float halfSpread = ( ior - 1.0 ) * 0.025 * dispersion;
			vec3 iors = vec3( ior - halfSpread, ior, ior + halfSpread );
			for ( int i = 0; i < 3; i ++ ) {
				vec3 transmissionRay = getVolumeTransmissionRay( n, v, thickness, iors[ i ], modelMatrix );
				vec3 refractedRayExit = position + transmissionRay;
				vec4 ndcPos = projMatrix * viewMatrix * vec4( refractedRayExit, 1.0 );
				vec2 refractionCoords = ndcPos.xy / ndcPos.w;
				refractionCoords += 1.0;
				refractionCoords /= 2.0;
				vec4 transmissionSample = getTransmissionSample( refractionCoords, roughness, iors[ i ] );
				transmittedLight[ i ] = transmissionSample[ i ];
				transmittedLight.a += transmissionSample.a;
				transmittance[ i ] = diffuseColor[ i ] * volumeAttenuation( length( transmissionRay ), attenuationColor, attenuationDistance )[ i ];
			}
			transmittedLight.a /= 3.0;
		#else
			vec3 transmissionRay = getVolumeTransmissionRay( n, v, thickness, ior, modelMatrix );
			vec3 refractedRayExit = position + transmissionRay;
			vec4 ndcPos = projMatrix * viewMatrix * vec4( refractedRayExit, 1.0 );
			vec2 refractionCoords = ndcPos.xy / ndcPos.w;
			refractionCoords += 1.0;
			refractionCoords /= 2.0;
			transmittedLight = getTransmissionSample( refractionCoords, roughness, ior );
			transmittance = diffuseColor * volumeAttenuation( length( transmissionRay ), attenuationColor, attenuationDistance );
		#endif
		vec3 attenuatedColor = transmittance * transmittedLight.rgb;
		vec3 F = EnvironmentBRDF( n, v, specularColor, specularF90, roughness );
		float transmittanceFactor = ( transmittance.r + transmittance.g + transmittance.b ) / 3.0;
		return vec4( ( 1.0 - F ) * attenuatedColor, 1.0 - ( 1.0 - transmittedLight.a ) * transmittanceFactor );
	}
#endif`,J1=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	varying vec2 vUv;
#endif
#ifdef USE_MAP
	varying vec2 vMapUv;
#endif
#ifdef USE_ALPHAMAP
	varying vec2 vAlphaMapUv;
#endif
#ifdef USE_LIGHTMAP
	varying vec2 vLightMapUv;
#endif
#ifdef USE_AOMAP
	varying vec2 vAoMapUv;
#endif
#ifdef USE_BUMPMAP
	varying vec2 vBumpMapUv;
#endif
#ifdef USE_NORMALMAP
	varying vec2 vNormalMapUv;
#endif
#ifdef USE_EMISSIVEMAP
	varying vec2 vEmissiveMapUv;
#endif
#ifdef USE_METALNESSMAP
	varying vec2 vMetalnessMapUv;
#endif
#ifdef USE_ROUGHNESSMAP
	varying vec2 vRoughnessMapUv;
#endif
#ifdef USE_ANISOTROPYMAP
	varying vec2 vAnisotropyMapUv;
#endif
#ifdef USE_CLEARCOATMAP
	varying vec2 vClearcoatMapUv;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	varying vec2 vClearcoatNormalMapUv;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	varying vec2 vClearcoatRoughnessMapUv;
#endif
#ifdef USE_IRIDESCENCEMAP
	varying vec2 vIridescenceMapUv;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	varying vec2 vIridescenceThicknessMapUv;
#endif
#ifdef USE_SHEEN_COLORMAP
	varying vec2 vSheenColorMapUv;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	varying vec2 vSheenRoughnessMapUv;
#endif
#ifdef USE_SPECULARMAP
	varying vec2 vSpecularMapUv;
#endif
#ifdef USE_SPECULAR_COLORMAP
	varying vec2 vSpecularColorMapUv;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	varying vec2 vSpecularIntensityMapUv;
#endif
#ifdef USE_TRANSMISSIONMAP
	uniform mat3 transmissionMapTransform;
	varying vec2 vTransmissionMapUv;
#endif
#ifdef USE_THICKNESSMAP
	uniform mat3 thicknessMapTransform;
	varying vec2 vThicknessMapUv;
#endif`,K1=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	varying vec2 vUv;
#endif
#ifdef USE_MAP
	uniform mat3 mapTransform;
	varying vec2 vMapUv;
#endif
#ifdef USE_ALPHAMAP
	uniform mat3 alphaMapTransform;
	varying vec2 vAlphaMapUv;
#endif
#ifdef USE_LIGHTMAP
	uniform mat3 lightMapTransform;
	varying vec2 vLightMapUv;
#endif
#ifdef USE_AOMAP
	uniform mat3 aoMapTransform;
	varying vec2 vAoMapUv;
#endif
#ifdef USE_BUMPMAP
	uniform mat3 bumpMapTransform;
	varying vec2 vBumpMapUv;
#endif
#ifdef USE_NORMALMAP
	uniform mat3 normalMapTransform;
	varying vec2 vNormalMapUv;
#endif
#ifdef USE_DISPLACEMENTMAP
	uniform mat3 displacementMapTransform;
	varying vec2 vDisplacementMapUv;
#endif
#ifdef USE_EMISSIVEMAP
	uniform mat3 emissiveMapTransform;
	varying vec2 vEmissiveMapUv;
#endif
#ifdef USE_METALNESSMAP
	uniform mat3 metalnessMapTransform;
	varying vec2 vMetalnessMapUv;
#endif
#ifdef USE_ROUGHNESSMAP
	uniform mat3 roughnessMapTransform;
	varying vec2 vRoughnessMapUv;
#endif
#ifdef USE_ANISOTROPYMAP
	uniform mat3 anisotropyMapTransform;
	varying vec2 vAnisotropyMapUv;
#endif
#ifdef USE_CLEARCOATMAP
	uniform mat3 clearcoatMapTransform;
	varying vec2 vClearcoatMapUv;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	uniform mat3 clearcoatNormalMapTransform;
	varying vec2 vClearcoatNormalMapUv;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	uniform mat3 clearcoatRoughnessMapTransform;
	varying vec2 vClearcoatRoughnessMapUv;
#endif
#ifdef USE_SHEEN_COLORMAP
	uniform mat3 sheenColorMapTransform;
	varying vec2 vSheenColorMapUv;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	uniform mat3 sheenRoughnessMapTransform;
	varying vec2 vSheenRoughnessMapUv;
#endif
#ifdef USE_IRIDESCENCEMAP
	uniform mat3 iridescenceMapTransform;
	varying vec2 vIridescenceMapUv;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	uniform mat3 iridescenceThicknessMapTransform;
	varying vec2 vIridescenceThicknessMapUv;
#endif
#ifdef USE_SPECULARMAP
	uniform mat3 specularMapTransform;
	varying vec2 vSpecularMapUv;
#endif
#ifdef USE_SPECULAR_COLORMAP
	uniform mat3 specularColorMapTransform;
	varying vec2 vSpecularColorMapUv;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	uniform mat3 specularIntensityMapTransform;
	varying vec2 vSpecularIntensityMapUv;
#endif
#ifdef USE_TRANSMISSIONMAP
	uniform mat3 transmissionMapTransform;
	varying vec2 vTransmissionMapUv;
#endif
#ifdef USE_THICKNESSMAP
	uniform mat3 thicknessMapTransform;
	varying vec2 vThicknessMapUv;
#endif`,j1=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
	vUv = vec3( uv, 1 ).xy;
#endif
#ifdef USE_MAP
	vMapUv = ( mapTransform * vec3( MAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ALPHAMAP
	vAlphaMapUv = ( alphaMapTransform * vec3( ALPHAMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_LIGHTMAP
	vLightMapUv = ( lightMapTransform * vec3( LIGHTMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_AOMAP
	vAoMapUv = ( aoMapTransform * vec3( AOMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_BUMPMAP
	vBumpMapUv = ( bumpMapTransform * vec3( BUMPMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_NORMALMAP
	vNormalMapUv = ( normalMapTransform * vec3( NORMALMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_DISPLACEMENTMAP
	vDisplacementMapUv = ( displacementMapTransform * vec3( DISPLACEMENTMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_EMISSIVEMAP
	vEmissiveMapUv = ( emissiveMapTransform * vec3( EMISSIVEMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_METALNESSMAP
	vMetalnessMapUv = ( metalnessMapTransform * vec3( METALNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ROUGHNESSMAP
	vRoughnessMapUv = ( roughnessMapTransform * vec3( ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_ANISOTROPYMAP
	vAnisotropyMapUv = ( anisotropyMapTransform * vec3( ANISOTROPYMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOATMAP
	vClearcoatMapUv = ( clearcoatMapTransform * vec3( CLEARCOATMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	vClearcoatNormalMapUv = ( clearcoatNormalMapTransform * vec3( CLEARCOAT_NORMALMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	vClearcoatRoughnessMapUv = ( clearcoatRoughnessMapTransform * vec3( CLEARCOAT_ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_IRIDESCENCEMAP
	vIridescenceMapUv = ( iridescenceMapTransform * vec3( IRIDESCENCEMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	vIridescenceThicknessMapUv = ( iridescenceThicknessMapTransform * vec3( IRIDESCENCE_THICKNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SHEEN_COLORMAP
	vSheenColorMapUv = ( sheenColorMapTransform * vec3( SHEEN_COLORMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SHEEN_ROUGHNESSMAP
	vSheenRoughnessMapUv = ( sheenRoughnessMapTransform * vec3( SHEEN_ROUGHNESSMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULARMAP
	vSpecularMapUv = ( specularMapTransform * vec3( SPECULARMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULAR_COLORMAP
	vSpecularColorMapUv = ( specularColorMapTransform * vec3( SPECULAR_COLORMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_SPECULAR_INTENSITYMAP
	vSpecularIntensityMapUv = ( specularIntensityMapTransform * vec3( SPECULAR_INTENSITYMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_TRANSMISSIONMAP
	vTransmissionMapUv = ( transmissionMapTransform * vec3( TRANSMISSIONMAP_UV, 1 ) ).xy;
#endif
#ifdef USE_THICKNESSMAP
	vThicknessMapUv = ( thicknessMapTransform * vec3( THICKNESSMAP_UV, 1 ) ).xy;
#endif`,Q1=`#if defined( USE_ENVMAP ) || defined( DISTANCE ) || defined ( USE_SHADOWMAP ) || defined ( USE_TRANSMISSION ) || NUM_SPOT_LIGHT_COORDS > 0
	vec4 worldPosition = vec4( transformed, 1.0 );
	#ifdef USE_BATCHING
		worldPosition = batchingMatrix * worldPosition;
	#endif
	#ifdef USE_INSTANCING
		worldPosition = instanceMatrix * worldPosition;
	#endif
	worldPosition = modelMatrix * worldPosition;
#endif`,em=`varying vec2 vUv;
uniform mat3 uvTransform;
void main() {
	vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	gl_Position = vec4( position.xy, 1.0, 1.0 );
}`,tm=`uniform sampler2D t2D;
uniform float backgroundIntensity;
varying vec2 vUv;
void main() {
	vec4 texColor = texture2D( t2D, vUv );
	#ifdef DECODE_VIDEO_TEXTURE
		texColor = vec4( mix( pow( texColor.rgb * 0.9478672986 + vec3( 0.0521327014 ), vec3( 2.4 ) ), texColor.rgb * 0.0773993808, vec3( lessThanEqual( texColor.rgb, vec3( 0.04045 ) ) ) ), texColor.w );
	#endif
	texColor.rgb *= backgroundIntensity;
	gl_FragColor = texColor;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,nm=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,im=`#ifdef ENVMAP_TYPE_CUBE
	uniform samplerCube envMap;
#elif defined( ENVMAP_TYPE_CUBE_UV )
	uniform sampler2D envMap;
#endif
uniform float backgroundBlurriness;
uniform float backgroundIntensity;
uniform mat3 backgroundRotation;
varying vec3 vWorldDirection;
#include <cube_uv_reflection_fragment>
void main() {
	#ifdef ENVMAP_TYPE_CUBE
		vec4 texColor = textureCube( envMap, backgroundRotation * vWorldDirection );
	#elif defined( ENVMAP_TYPE_CUBE_UV )
		vec4 texColor = textureCubeUV( envMap, backgroundRotation * vWorldDirection, backgroundBlurriness );
	#else
		vec4 texColor = vec4( 0.0, 0.0, 0.0, 1.0 );
	#endif
	texColor.rgb *= backgroundIntensity;
	gl_FragColor = texColor;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,sm=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,rm=`uniform samplerCube tCube;
uniform float tFlip;
uniform float opacity;
varying vec3 vWorldDirection;
void main() {
	vec4 texColor = textureCube( tCube, vec3( tFlip * vWorldDirection.x, vWorldDirection.yz ) );
	gl_FragColor = texColor;
	gl_FragColor.a *= opacity;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,am=`#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
varying vec2 vHighPrecisionZW;
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <skinbase_vertex>
	#include <morphinstance_vertex>
	#ifdef USE_DISPLACEMENTMAP
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vHighPrecisionZW = gl_Position.zw;
}`,om=`#if DEPTH_PACKING == 3200
	uniform float opacity;
#endif
#include <common>
#include <packing>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
varying vec2 vHighPrecisionZW;
void main() {
	vec4 diffuseColor = vec4( 1.0 );
	#include <clipping_planes_fragment>
	#if DEPTH_PACKING == 3200
		diffuseColor.a = opacity;
	#endif
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <logdepthbuf_fragment>
	#ifdef USE_REVERSED_DEPTH_BUFFER
		float fragCoordZ = vHighPrecisionZW[ 0 ] / vHighPrecisionZW[ 1 ];
	#else
		float fragCoordZ = 0.5 * vHighPrecisionZW[ 0 ] / vHighPrecisionZW[ 1 ] + 0.5;
	#endif
	#if DEPTH_PACKING == 3200
		gl_FragColor = vec4( vec3( 1.0 - fragCoordZ ), opacity );
	#elif DEPTH_PACKING == 3201
		gl_FragColor = packDepthToRGBA( fragCoordZ );
	#elif DEPTH_PACKING == 3202
		gl_FragColor = vec4( packDepthToRGB( fragCoordZ ), 1.0 );
	#elif DEPTH_PACKING == 3203
		gl_FragColor = vec4( packDepthToRG( fragCoordZ ), 0.0, 1.0 );
	#endif
}`,lm=`#define DISTANCE
varying vec3 vWorldPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <skinbase_vertex>
	#include <morphinstance_vertex>
	#ifdef USE_DISPLACEMENTMAP
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <worldpos_vertex>
	#include <clipping_planes_vertex>
	vWorldPosition = worldPosition.xyz;
}`,cm=`#define DISTANCE
uniform vec3 referencePosition;
uniform float nearDistance;
uniform float farDistance;
varying vec3 vWorldPosition;
#include <common>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( 1.0 );
	#include <clipping_planes_fragment>
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	float dist = length( vWorldPosition - referencePosition );
	dist = ( dist - nearDistance ) / ( farDistance - nearDistance );
	dist = saturate( dist );
	gl_FragColor = vec4( dist, 0.0, 0.0, 1.0 );
}`,hm=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
}`,um=`uniform sampler2D tEquirect;
varying vec3 vWorldDirection;
#include <common>
void main() {
	vec3 direction = normalize( vWorldDirection );
	vec2 sampleUV = equirectUv( direction );
	gl_FragColor = texture2D( tEquirect, sampleUV );
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,fm=`uniform float scale;
attribute float lineDistance;
varying float vLineDistance;
#include <common>
#include <uv_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	vLineDistance = scale * lineDistance;
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
}`,dm=`uniform vec3 diffuse;
uniform float opacity;
uniform float dashSize;
uniform float totalSize;
varying float vLineDistance;
#include <common>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	if ( mod( vLineDistance, totalSize ) > dashSize ) {
		discard;
	}
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
}`,pm=`#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#if defined ( USE_ENVMAP ) || defined ( USE_SKINNING )
		#include <beginnormal_vertex>
		#include <morphnormal_vertex>
		#include <skinbase_vertex>
		#include <skinnormal_vertex>
		#include <defaultnormal_vertex>
	#endif
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <fog_vertex>
}`,mm=`uniform vec3 diffuse;
uniform float opacity;
#ifndef FLAT_SHADED
	varying vec3 vNormal;
#endif
#include <common>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <fog_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	#ifdef USE_LIGHTMAP
		vec4 lightMapTexel = texture2D( lightMap, vLightMapUv );
		reflectedLight.indirectDiffuse += lightMapTexel.rgb * lightMapIntensity * RECIPROCAL_PI;
	#else
		reflectedLight.indirectDiffuse += vec3( 1.0 );
	#endif
	#include <aomap_fragment>
	reflectedLight.indirectDiffuse *= diffuseColor.rgb;
	vec3 outgoingLight = reflectedLight.indirectDiffuse;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,gm=`#define LAMBERT
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,_m=`#define LAMBERT
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float opacity;
#include <common>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <cube_uv_reflection_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <envmap_physical_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_lambert_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_lambert_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + totalEmissiveRadiance;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,xm=`#define MATCAP
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <color_pars_vertex>
#include <displacementmap_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
	vViewPosition = - mvPosition.xyz;
}`,vm=`#define MATCAP
uniform vec3 diffuse;
uniform float opacity;
uniform sampler2D matcap;
varying vec3 vViewPosition;
#include <common>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <normal_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	vec3 viewDir = normalize( vViewPosition );
	vec3 x = normalize( vec3( viewDir.z, 0.0, - viewDir.x ) );
	vec3 y = cross( viewDir, x );
	vec2 uv = vec2( dot( x, normal ), dot( y, normal ) ) * 0.495 + 0.5;
	#ifdef USE_MATCAP
		vec4 matcapColor = texture2D( matcap, uv );
	#else
		vec4 matcapColor = vec4( vec3( mix( 0.2, 0.8, uv.y ) ), 1.0 );
	#endif
	vec3 outgoingLight = diffuseColor.rgb * matcapColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,ym=`#define NORMAL
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	varying vec3 vViewPosition;
#endif
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	vViewPosition = - mvPosition.xyz;
#endif
}`,Mm=`#define NORMAL
uniform float opacity;
#if defined( FLAT_SHADED ) || defined( USE_BUMPMAP ) || defined( USE_NORMALMAP_TANGENTSPACE )
	varying vec3 vViewPosition;
#endif
#include <uv_pars_fragment>
#include <normal_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( 0.0, 0.0, 0.0, opacity );
	#include <clipping_planes_fragment>
	#include <logdepthbuf_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	gl_FragColor = vec4( normalize( normal ) * 0.5 + 0.5, diffuseColor.a );
	#ifdef OPAQUE
		gl_FragColor.a = 1.0;
	#endif
}`,Sm=`#define PHONG
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <envmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <envmap_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,bm=`#define PHONG
uniform vec3 diffuse;
uniform vec3 emissive;
uniform vec3 specular;
uniform float shininess;
uniform float opacity;
#include <common>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <cube_uv_reflection_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_pars_fragment>
#include <envmap_physical_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_phong_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <specularmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <specularmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_phong_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + reflectedLight.directSpecular + reflectedLight.indirectSpecular + totalEmissiveRadiance;
	#include <envmap_fragment>
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,Em=`#define STANDARD
varying vec3 vViewPosition;
#ifdef USE_TRANSMISSION
	varying vec3 vWorldPosition;
#endif
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
#ifdef USE_TRANSMISSION
	vWorldPosition = worldPosition.xyz;
#endif
}`,Tm=`#define STANDARD
#ifdef PHYSICAL
	#define IOR
	#define USE_SPECULAR
#endif
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float roughness;
uniform float metalness;
uniform float opacity;
#ifdef IOR
	uniform float ior;
#endif
#ifdef USE_SPECULAR
	uniform float specularIntensity;
	uniform vec3 specularColor;
	#ifdef USE_SPECULAR_COLORMAP
		uniform sampler2D specularColorMap;
	#endif
	#ifdef USE_SPECULAR_INTENSITYMAP
		uniform sampler2D specularIntensityMap;
	#endif
#endif
#ifdef USE_CLEARCOAT
	uniform float clearcoat;
	uniform float clearcoatRoughness;
#endif
#ifdef USE_DISPERSION
	uniform float dispersion;
#endif
#ifdef USE_RETROREFLECTION
	uniform float retroreflectivity;
#endif
#ifdef USE_IRIDESCENCE
	uniform float iridescence;
	uniform float iridescenceIOR;
	uniform float iridescenceThicknessMinimum;
	uniform float iridescenceThicknessMaximum;
#endif
#ifdef USE_SHEEN
	uniform vec3 sheenColor;
	uniform float sheenRoughness;
	#ifdef USE_SHEEN_COLORMAP
		uniform sampler2D sheenColorMap;
	#endif
	#ifdef USE_SHEEN_ROUGHNESSMAP
		uniform sampler2D sheenRoughnessMap;
	#endif
#endif
#ifdef USE_ANISOTROPY
	uniform vec2 anisotropyVector;
	#ifdef USE_ANISOTROPYMAP
		uniform sampler2D anisotropyMap;
	#endif
#endif
varying vec3 vViewPosition;
#include <common>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <iridescence_fragment>
#include <cube_uv_reflection_fragment>
#include <envmap_common_pars_fragment>
#include <envmap_physical_pars_fragment>
#include <fog_pars_fragment>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_physical_pars_fragment>
#include <transmission_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <clearcoat_pars_fragment>
#include <iridescence_pars_fragment>
#include <roughnessmap_pars_fragment>
#include <metalnessmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <roughnessmap_fragment>
	#include <metalnessmap_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <clearcoat_normal_fragment_begin>
	#include <clearcoat_normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_physical_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 totalDiffuse = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse;
	vec3 totalSpecular = reflectedLight.directSpecular + reflectedLight.indirectSpecular;
	#include <transmission_fragment>
	vec3 outgoingLight = totalDiffuse + totalSpecular + totalEmissiveRadiance;
	#ifdef USE_SHEEN
 
		outgoingLight = outgoingLight + sheenSpecularDirect + sheenSpecularIndirect;
 
 	#endif
	#ifdef USE_CLEARCOAT
		float dotNVcc = saturate( dot( geometryClearcoatNormal, geometryViewDir ) );
		vec3 Fcc = F_Schlick( material.clearcoatF0, material.clearcoatF90, dotNVcc );
		outgoingLight = outgoingLight * ( 1.0 - material.clearcoat * Fcc ) + ( clearcoatSpecularDirect + clearcoatSpecularIndirect ) * material.clearcoat;
	#endif
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,wm=`#define TOON
varying vec3 vViewPosition;
#include <common>
#include <batching_pars_vertex>
#include <uv_pars_vertex>
#include <displacementmap_pars_vertex>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <normal_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <shadowmap_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <normal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <displacementmap_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	vViewPosition = - mvPosition.xyz;
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,Am=`#define TOON
uniform vec3 diffuse;
uniform vec3 emissive;
uniform float opacity;
#include <common>
#include <dithering_pars_fragment>
#include <color_pars_fragment>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <aomap_pars_fragment>
#include <lightmap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <gradientmap_pars_fragment>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <normal_pars_fragment>
#include <lights_toon_pars_fragment>
#include <shadowmap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <normalmap_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	ReflectedLight reflectedLight = ReflectedLight( vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ), vec3( 0.0 ) );
	vec3 totalEmissiveRadiance = emissive;
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <color_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	#include <normal_fragment_begin>
	#include <normal_fragment_maps>
	#include <emissivemap_fragment>
	#include <lights_toon_fragment>
	#include <lights_fragment_begin>
	#include <lights_fragment_maps>
	#include <lights_fragment_end>
	#include <aomap_fragment>
	vec3 outgoingLight = reflectedLight.directDiffuse + reflectedLight.indirectDiffuse + totalEmissiveRadiance;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
	#include <dithering_fragment>
}`,Rm=`uniform float size;
uniform float scale;
#include <common>
#include <color_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
#ifdef USE_POINTS_UV
	varying vec2 vUv;
	uniform mat3 uvTransform;
#endif
void main() {
	#ifdef USE_POINTS_UV
		vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	#endif
	#include <color_vertex>
	#include <morphinstance_vertex>
	#include <morphcolor_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <project_vertex>
	gl_PointSize = size;
	#ifdef USE_SIZEATTENUATION
		bool isPerspective = isPerspectiveMatrix( projectionMatrix );
		if ( isPerspective ) gl_PointSize *= ( scale / - mvPosition.z );
	#endif
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <worldpos_vertex>
	#include <fog_vertex>
}`,Cm=`uniform vec3 diffuse;
uniform float opacity;
#include <common>
#include <color_pars_fragment>
#include <map_particle_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_particle_fragment>
	#include <color_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
}`,Pm=`#include <common>
#include <batching_pars_vertex>
#include <fog_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <shadowmap_pars_vertex>
void main() {
	#include <batching_vertex>
	#include <beginnormal_vertex>
	#include <morphinstance_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>
	#include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <project_vertex>
	#include <logdepthbuf_vertex>
	#include <worldpos_vertex>
	#include <shadowmap_vertex>
	#include <fog_vertex>
}`,Im=`uniform vec3 color;
uniform float opacity;
#include <common>
#include <fog_pars_fragment>
#include <bsdfs>
#include <lights_pars_begin>
#include <logdepthbuf_pars_fragment>
#include <shadowmap_pars_fragment>
#include <shadowmask_pars_fragment>
void main() {
	#include <logdepthbuf_fragment>
	gl_FragColor = vec4( color, opacity * ( 1.0 - getShadowMask() ) );
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
	#include <premultiplied_alpha_fragment>
}`,Lm=`uniform float rotation;
uniform vec2 center;
#include <common>
#include <uv_pars_vertex>
#include <fog_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <clipping_planes_pars_vertex>
void main() {
	#include <uv_vertex>
	vec4 mvPosition = modelViewMatrix[ 3 ];
	vec2 scale = vec2( length( modelMatrix[ 0 ].xyz ), length( modelMatrix[ 1 ].xyz ) );
	#ifndef USE_SIZEATTENUATION
		bool isPerspective = isPerspectiveMatrix( projectionMatrix );
		if ( isPerspective ) scale *= - mvPosition.z;
	#endif
	vec2 alignedPosition = ( position.xy - ( center - vec2( 0.5 ) ) ) * scale;
	vec2 rotatedPosition;
	rotatedPosition.x = cos( rotation ) * alignedPosition.x - sin( rotation ) * alignedPosition.y;
	rotatedPosition.y = sin( rotation ) * alignedPosition.x + cos( rotation ) * alignedPosition.y;
	mvPosition.xy += rotatedPosition;
	gl_Position = projectionMatrix * mvPosition;
	#include <logdepthbuf_vertex>
	#include <clipping_planes_vertex>
	#include <fog_vertex>
}`,Dm=`uniform vec3 diffuse;
uniform float opacity;
#include <common>
#include <uv_pars_fragment>
#include <map_pars_fragment>
#include <alphamap_pars_fragment>
#include <alphatest_pars_fragment>
#include <alphahash_pars_fragment>
#include <fog_pars_fragment>
#include <logdepthbuf_pars_fragment>
#include <clipping_planes_pars_fragment>
void main() {
	vec4 diffuseColor = vec4( diffuse, opacity );
	#include <clipping_planes_fragment>
	vec3 outgoingLight = vec3( 0.0 );
	#include <logdepthbuf_fragment>
	#include <map_fragment>
	#include <alphamap_fragment>
	#include <alphatest_fragment>
	#include <alphahash_fragment>
	outgoingLight = diffuseColor.rgb;
	#include <opaque_fragment>
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
	#include <fog_fragment>
}`,xt={alphahash_fragment:ep,alphahash_pars_fragment:tp,alphamap_fragment:np,alphamap_pars_fragment:ip,alphatest_fragment:sp,alphatest_pars_fragment:rp,aomap_fragment:ap,aomap_pars_fragment:op,batching_pars_vertex:lp,batching_vertex:cp,begin_vertex:hp,beginnormal_vertex:up,bsdfs:fp,iridescence_fragment:dp,bumpmap_pars_fragment:pp,clipping_planes_fragment:mp,clipping_planes_pars_fragment:gp,clipping_planes_pars_vertex:_p,clipping_planes_vertex:xp,color_fragment:vp,color_pars_fragment:yp,color_pars_vertex:Mp,color_vertex:Sp,common:bp,cube_uv_reflection_fragment:Ep,defaultnormal_vertex:Tp,displacementmap_pars_vertex:wp,displacementmap_vertex:Ap,emissivemap_fragment:Rp,emissivemap_pars_fragment:Cp,colorspace_fragment:Pp,colorspace_pars_fragment:Ip,envmap_fragment:Lp,envmap_common_pars_fragment:Dp,envmap_pars_fragment:Np,envmap_pars_vertex:Up,envmap_physical_pars_fragment:qp,envmap_vertex:Fp,fog_vertex:Op,fog_pars_vertex:Bp,fog_fragment:zp,fog_pars_fragment:Hp,gradientmap_pars_fragment:kp,lightmap_pars_fragment:Vp,lights_lambert_fragment:Gp,lights_lambert_pars_fragment:Wp,lights_pars_begin:Xp,lights_toon_fragment:Yp,lights_toon_pars_fragment:$p,lights_phong_fragment:Zp,lights_phong_pars_fragment:Jp,lights_physical_fragment:Kp,lights_physical_pars_fragment:jp,lights_fragment_begin:Qp,lights_fragment_maps:e1,lights_fragment_end:t1,lightprobes_pars_fragment:n1,logdepthbuf_fragment:i1,logdepthbuf_pars_fragment:s1,logdepthbuf_pars_vertex:r1,logdepthbuf_vertex:a1,map_fragment:o1,map_pars_fragment:l1,map_particle_fragment:c1,map_particle_pars_fragment:h1,metalnessmap_fragment:u1,metalnessmap_pars_fragment:f1,morphinstance_vertex:d1,morphcolor_vertex:p1,morphnormal_vertex:m1,morphtarget_pars_vertex:g1,morphtarget_vertex:_1,normal_fragment_begin:x1,normal_fragment_maps:v1,normal_pars_fragment:y1,normal_pars_vertex:M1,normal_vertex:S1,normalmap_pars_fragment:b1,clearcoat_normal_fragment_begin:E1,clearcoat_normal_fragment_maps:T1,clearcoat_pars_fragment:w1,iridescence_pars_fragment:A1,opaque_fragment:R1,packing:C1,premultiplied_alpha_fragment:P1,project_vertex:I1,dithering_fragment:L1,dithering_pars_fragment:D1,roughnessmap_fragment:N1,roughnessmap_pars_fragment:U1,shadowmap_pars_fragment:F1,shadowmap_pars_vertex:O1,shadowmap_vertex:B1,shadowmask_pars_fragment:z1,skinbase_vertex:H1,skinning_pars_vertex:k1,skinning_vertex:V1,skinnormal_vertex:G1,specularmap_fragment:W1,specularmap_pars_fragment:X1,tonemapping_fragment:q1,tonemapping_pars_fragment:Y1,transmission_fragment:$1,transmission_pars_fragment:Z1,uv_pars_fragment:J1,uv_pars_vertex:K1,uv_vertex:j1,worldpos_vertex:Q1,background_vert:em,background_frag:tm,backgroundCube_vert:nm,backgroundCube_frag:im,cube_vert:sm,cube_frag:rm,depth_vert:am,depth_frag:om,distance_vert:lm,distance_frag:cm,equirect_vert:hm,equirect_frag:um,linedashed_vert:fm,linedashed_frag:dm,meshbasic_vert:pm,meshbasic_frag:mm,meshlambert_vert:gm,meshlambert_frag:_m,meshmatcap_vert:xm,meshmatcap_frag:vm,meshnormal_vert:ym,meshnormal_frag:Mm,meshphong_vert:Sm,meshphong_frag:bm,meshphysical_vert:Em,meshphysical_frag:Tm,meshtoon_vert:wm,meshtoon_frag:Am,points_vert:Rm,points_frag:Cm,shadow_vert:Pm,shadow_frag:Im,sprite_vert:Lm,sprite_frag:Dm},Be={common:{diffuse:{value:new it(16777215)},opacity:{value:1},map:{value:null},mapTransform:{value:new dt},alphaMap:{value:null},alphaMapTransform:{value:new dt},alphaTest:{value:0}},specularmap:{specularMap:{value:null},specularMapTransform:{value:new dt}},envmap:{envMap:{value:null},envMapRotation:{value:new dt},reflectivity:{value:1},ior:{value:1.5},refractionRatio:{value:.98},dfgLUT:{value:null}},aomap:{aoMap:{value:null},aoMapIntensity:{value:1},aoMapTransform:{value:new dt}},lightmap:{lightMap:{value:null},lightMapIntensity:{value:1},lightMapTransform:{value:new dt}},bumpmap:{bumpMap:{value:null},bumpMapTransform:{value:new dt},bumpScale:{value:1}},normalmap:{normalMap:{value:null},normalMapTransform:{value:new dt},normalScale:{value:new ue(1,1)}},displacementmap:{displacementMap:{value:null},displacementMapTransform:{value:new dt},displacementScale:{value:1},displacementBias:{value:0}},emissivemap:{emissiveMap:{value:null},emissiveMapTransform:{value:new dt}},metalnessmap:{metalnessMap:{value:null},metalnessMapTransform:{value:new dt}},roughnessmap:{roughnessMap:{value:null},roughnessMapTransform:{value:new dt}},gradientmap:{gradientMap:{value:null}},fog:{fogDensity:{value:25e-5},fogNear:{value:1},fogFar:{value:2e3},fogColor:{value:new it(16777215)}},lights:{ambientLightColor:{value:[]},lightProbe:{value:[]},sunLights:{value:[],properties:{direction:{},color:{}}},sunLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},sunShadowMatrix:{value:[]},sunShadowCascade:{value:[]},directionalLights:{value:[],properties:{direction:{},color:{}}},directionalLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},directionalShadowMatrix:{value:[]},spotLights:{value:[],properties:{color:{},position:{},direction:{},distance:{},coneCos:{},penumbraCos:{},decay:{}}},spotLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},spotLightMap:{value:[]},spotLightMatrix:{value:[]},pointLights:{value:[],properties:{color:{},position:{},decay:{},distance:{}}},pointLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{},shadowCameraNear:{},shadowCameraFar:{}}},pointShadowMatrix:{value:[]},hemisphereLights:{value:[],properties:{direction:{},skyColor:{},groundColor:{}}},rectAreaLights:{value:[],properties:{color:{},position:{},width:{},height:{}}},ltc_1:{value:null},ltc_2:{value:null},probesSH:{value:null},probesMin:{value:new I},probesMax:{value:new I},probesResolution:{value:new I}},points:{diffuse:{value:new it(16777215)},opacity:{value:1},size:{value:1},scale:{value:1},map:{value:null},alphaMap:{value:null},alphaMapTransform:{value:new dt},alphaTest:{value:0},uvTransform:{value:new dt}},sprite:{diffuse:{value:new it(16777215)},opacity:{value:1},center:{value:new ue(.5,.5)},rotation:{value:0},map:{value:null},mapTransform:{value:new dt},alphaMap:{value:null},alphaMapTransform:{value:new dt},alphaTest:{value:0}}},yi={basic:{uniforms:Mn([Be.common,Be.specularmap,Be.envmap,Be.aomap,Be.lightmap,Be.fog]),vertexShader:xt.meshbasic_vert,fragmentShader:xt.meshbasic_frag},lambert:{uniforms:Mn([Be.common,Be.specularmap,Be.envmap,Be.aomap,Be.lightmap,Be.emissivemap,Be.bumpmap,Be.normalmap,Be.displacementmap,Be.fog,Be.lights,{emissive:{value:new it(0)},envMapIntensity:{value:1}}]),vertexShader:xt.meshlambert_vert,fragmentShader:xt.meshlambert_frag},phong:{uniforms:Mn([Be.common,Be.specularmap,Be.envmap,Be.aomap,Be.lightmap,Be.emissivemap,Be.bumpmap,Be.normalmap,Be.displacementmap,Be.fog,Be.lights,{emissive:{value:new it(0)},specular:{value:new it(1118481)},shininess:{value:30},envMapIntensity:{value:1}}]),vertexShader:xt.meshphong_vert,fragmentShader:xt.meshphong_frag},standard:{uniforms:Mn([Be.common,Be.envmap,Be.aomap,Be.lightmap,Be.emissivemap,Be.bumpmap,Be.normalmap,Be.displacementmap,Be.roughnessmap,Be.metalnessmap,Be.fog,Be.lights,{emissive:{value:new it(0)},roughness:{value:1},metalness:{value:0},envMapIntensity:{value:1}}]),vertexShader:xt.meshphysical_vert,fragmentShader:xt.meshphysical_frag},toon:{uniforms:Mn([Be.common,Be.aomap,Be.lightmap,Be.emissivemap,Be.bumpmap,Be.normalmap,Be.displacementmap,Be.gradientmap,Be.fog,Be.lights,{emissive:{value:new it(0)}}]),vertexShader:xt.meshtoon_vert,fragmentShader:xt.meshtoon_frag},matcap:{uniforms:Mn([Be.common,Be.bumpmap,Be.normalmap,Be.displacementmap,Be.fog,{matcap:{value:null}}]),vertexShader:xt.meshmatcap_vert,fragmentShader:xt.meshmatcap_frag},points:{uniforms:Mn([Be.points,Be.fog]),vertexShader:xt.points_vert,fragmentShader:xt.points_frag},dashed:{uniforms:Mn([Be.common,Be.fog,{scale:{value:1},dashSize:{value:1},totalSize:{value:2}}]),vertexShader:xt.linedashed_vert,fragmentShader:xt.linedashed_frag},depth:{uniforms:Mn([Be.common,Be.displacementmap]),vertexShader:xt.depth_vert,fragmentShader:xt.depth_frag},normal:{uniforms:Mn([Be.common,Be.bumpmap,Be.normalmap,Be.displacementmap,{opacity:{value:1}}]),vertexShader:xt.meshnormal_vert,fragmentShader:xt.meshnormal_frag},sprite:{uniforms:Mn([Be.sprite,Be.fog]),vertexShader:xt.sprite_vert,fragmentShader:xt.sprite_frag},background:{uniforms:{uvTransform:{value:new dt},t2D:{value:null},backgroundIntensity:{value:1}},vertexShader:xt.background_vert,fragmentShader:xt.background_frag},backgroundCube:{uniforms:{envMap:{value:null},backgroundBlurriness:{value:0},backgroundIntensity:{value:1},backgroundRotation:{value:new dt}},vertexShader:xt.backgroundCube_vert,fragmentShader:xt.backgroundCube_frag},cube:{uniforms:{tCube:{value:null},tFlip:{value:-1},opacity:{value:1}},vertexShader:xt.cube_vert,fragmentShader:xt.cube_frag},equirect:{uniforms:{tEquirect:{value:null}},vertexShader:xt.equirect_vert,fragmentShader:xt.equirect_frag},distance:{uniforms:Mn([Be.common,Be.displacementmap,{referencePosition:{value:new I},nearDistance:{value:1},farDistance:{value:1e3}}]),vertexShader:xt.distance_vert,fragmentShader:xt.distance_frag},shadow:{uniforms:Mn([Be.lights,Be.fog,{color:{value:new it(0)},opacity:{value:1}}]),vertexShader:xt.shadow_vert,fragmentShader:xt.shadow_frag}};yi.physical={uniforms:Mn([yi.standard.uniforms,{clearcoat:{value:0},clearcoatMap:{value:null},clearcoatMapTransform:{value:new dt},clearcoatNormalMap:{value:null},clearcoatNormalMapTransform:{value:new dt},clearcoatNormalScale:{value:new ue(1,1)},clearcoatRoughness:{value:0},clearcoatRoughnessMap:{value:null},clearcoatRoughnessMapTransform:{value:new dt},dispersion:{value:0},retroreflectivity:{value:0},iridescence:{value:0},iridescenceMap:{value:null},iridescenceMapTransform:{value:new dt},iridescenceIOR:{value:1.3},iridescenceThicknessMinimum:{value:100},iridescenceThicknessMaximum:{value:400},iridescenceThicknessMap:{value:null},iridescenceThicknessMapTransform:{value:new dt},sheen:{value:0},sheenColor:{value:new it(0)},sheenColorMap:{value:null},sheenColorMapTransform:{value:new dt},sheenRoughness:{value:1},sheenRoughnessMap:{value:null},sheenRoughnessMapTransform:{value:new dt},transmission:{value:0},transmissionMap:{value:null},transmissionMapTransform:{value:new dt},transmissionSamplerSize:{value:new ue},transmissionSamplerMap:{value:null},thickness:{value:0},thicknessMap:{value:null},thicknessMapTransform:{value:new dt},attenuationDistance:{value:0},attenuationColor:{value:new it(0)},specularColor:{value:new it(1,1,1)},specularColorMap:{value:null},specularColorMapTransform:{value:new dt},specularIntensity:{value:1},specularIntensityMap:{value:null},specularIntensityMapTransform:{value:new dt},anisotropyVector:{value:new ue},anisotropyMap:{value:null},anisotropyMapTransform:{value:new dt}}]),vertexShader:xt.meshphysical_vert,fragmentShader:xt.meshphysical_frag};var lc={r:0,b:0,g:0},Nm=new Rt,uf=new dt;uf.set(-1,0,0,0,1,0,0,0,1);function Um(i,e,t,n,s,r){let a=new it(0),o=s===!0?0:1,l,c,h=null,f=0,u=null;function d(S){let A=S.isScene===!0?S.background:null;if(A&&A.isTexture){let v=S.backgroundBlurriness>0;A=e.get(A,v)}return A}function g(S){let A=!1,v=d(S);v===null?m(a,o):v&&v.isColor&&(m(v,1),A=!0);let b=i.xr.getEnvironmentBlendMode();b==="additive"?t.buffers.color.setClear(0,0,0,1,r):b==="alpha-blend"&&t.buffers.color.setClear(0,0,0,0,r),(i.autoClear||A)&&(t.buffers.depth.setTest(!0),t.buffers.depth.setMask(!0),t.buffers.color.setMask(!0),i.clear(i.autoClearColor,i.autoClearDepth,i.autoClearStencil))}function x(S,A){let v=d(A);v&&(v.isCubeTexture||v.mapping===Ba)?(c===void 0&&(c=new gt(new ar(1,1,1),new Ft({name:"BackgroundCubeMaterial",uniforms:bs(yi.backgroundCube.uniforms),vertexShader:yi.backgroundCube.vertexShader,fragmentShader:yi.backgroundCube.fragmentShader,side:_n,depthTest:!1,depthWrite:!1,fog:!1,allowOverride:!1})),c.geometry.deleteAttribute("normal"),c.geometry.deleteAttribute("uv"),c.onBeforeRender=function(b,E,C){this.matrixWorld.copyPosition(C.matrixWorld)},Object.defineProperty(c.material,"envMap",{get:function(){return this.uniforms.envMap.value}}),n.update(c)),c.material.uniforms.envMap.value=v,c.material.uniforms.backgroundBlurriness.value=A.backgroundBlurriness,c.material.uniforms.backgroundIntensity.value=A.backgroundIntensity,c.material.uniforms.backgroundRotation.value.setFromMatrix4(Nm.makeRotationFromEuler(A.backgroundRotation)).transpose(),v.isCubeTexture&&v.isRenderTargetTexture===!1&&c.material.uniforms.backgroundRotation.value.premultiply(uf),c.material.toneMapped=St.getTransfer(v.colorSpace)!==Pt,(h!==v||f!==v.version||u!==i.toneMapping)&&(c.material.needsUpdate=!0,h=v,f=v.version,u=i.toneMapping),c.layers.enableAll(),S.unshift(c,c.geometry,c.material,0,0,null)):v&&v.isTexture&&(l===void 0&&(l=new gt(new Ji(2,2),new Ft({name:"BackgroundMaterial",uniforms:bs(yi.background.uniforms),vertexShader:yi.background.vertexShader,fragmentShader:yi.background.fragmentShader,side:ts,depthTest:!1,depthWrite:!1,fog:!1,allowOverride:!1})),l.geometry.deleteAttribute("normal"),Object.defineProperty(l.material,"map",{get:function(){return this.uniforms.t2D.value}}),n.update(l)),l.material.uniforms.t2D.value=v,l.material.uniforms.backgroundIntensity.value=A.backgroundIntensity,l.material.toneMapped=St.getTransfer(v.colorSpace)!==Pt,v.matrixAutoUpdate===!0&&v.updateMatrix(),l.material.uniforms.uvTransform.value.copy(v.matrix),(h!==v||f!==v.version||u!==i.toneMapping)&&(l.material.needsUpdate=!0,h=v,f=v.version,u=i.toneMapping),l.layers.enableAll(),S.unshift(l,l.geometry,l.material,0,0,null))}function m(S,A){S.getRGB(lc,L0(i)),t.buffers.color.setClear(lc.r,lc.g,lc.b,A,r)}function p(){c!==void 0&&(c.geometry.dispose(),c.material.dispose(),c=void 0),l!==void 0&&(l.geometry.dispose(),l.material.dispose(),l=void 0)}return{getClearColor:function(){return a},setClearColor:function(S,A=1){a.set(S),o=A,m(a,o)},getClearAlpha:function(){return o},setClearAlpha:function(S){o=S,m(a,o)},render:g,addToRenderList:x,dispose:p}}function Fm(i,e){let t=i.getParameter(i.MAX_VERTEX_ATTRIBS),n={},s=u(null),r=s,a=!1;function o(U,B,W,F,V){let se=!1,K=f(U,F,W,B);r!==K&&(r=K,c(r.object)),se=d(U,F,W,V),se&&g(U,F,W,V),V!==null&&e.update(V,i.ELEMENT_ARRAY_BUFFER),(se||a)&&(a=!1,v(U,B,W,F),V!==null&&i.bindBuffer(i.ELEMENT_ARRAY_BUFFER,e.get(V).buffer))}function l(){return i.createVertexArray()}function c(U){return i.bindVertexArray(U)}function h(U){return i.deleteVertexArray(U)}function f(U,B,W,F){let V=F.wireframe===!0,se=n[B.id];se===void 0&&(se={},n[B.id]=se);let K=U.isInstancedMesh===!0?U.id:0,de=se[K];de===void 0&&(de={},se[K]=de);let te=de[W.id];te===void 0&&(te={},de[W.id]=te);let ae=te[V];return ae===void 0&&(ae=u(l()),te[V]=ae),ae}function u(U){let B=[],W=[],F=[];for(let V=0;V<t;V++)B[V]=0,W[V]=0,F[V]=0;return{geometry:null,program:null,wireframe:!1,newAttributes:B,enabledAttributes:W,attributeDivisors:F,object:U,attributes:{},index:null}}function d(U,B,W,F){let V=r.attributes,se=B.attributes,K=0,de=W.getAttributes();for(let te in de)if(de[te].location>=0){let O=V[te],ye=se[te];if(ye===void 0&&(te==="instanceMatrix"&&U.instanceMatrix&&(ye=U.instanceMatrix),te==="instanceColor"&&U.instanceColor&&(ye=U.instanceColor)),O===void 0||O.attribute!==ye||ye&&O.data!==ye.data)return!0;K++}return r.attributesNum!==K||r.index!==F}function g(U,B,W,F){let V={},se=B.attributes,K=0,de=W.getAttributes();for(let te in de)if(de[te].location>=0){let O=se[te];O===void 0&&(te==="instanceMatrix"&&U.instanceMatrix&&(O=U.instanceMatrix),te==="instanceColor"&&U.instanceColor&&(O=U.instanceColor));let ye={};ye.attribute=O,O&&O.data&&(ye.data=O.data),V[te]=ye,K++}r.attributes=V,r.attributesNum=K,r.index=F}function x(){let U=r.newAttributes;for(let B=0,W=U.length;B<W;B++)U[B]=0}function m(U){p(U,0)}function p(U,B){let W=r.newAttributes,F=r.enabledAttributes,V=r.attributeDivisors;W[U]=1,F[U]===0&&(i.enableVertexAttribArray(U),F[U]=1),V[U]!==B&&(i.vertexAttribDivisor(U,B),V[U]=B)}function S(){let U=r.newAttributes,B=r.enabledAttributes;for(let W=0,F=B.length;W<F;W++)B[W]!==U[W]&&(i.disableVertexAttribArray(W),B[W]=0)}function A(U,B,W,F,V,se,K){K===!0?i.vertexAttribIPointer(U,B,W,V,se):i.vertexAttribPointer(U,B,W,F,V,se)}function v(U,B,W,F){x();let V=F.attributes,se=W.getAttributes(),K=B.defaultAttributeValues;for(let de in se){let te=se[de];if(te.location>=0){let ae=V[de];if(ae===void 0&&(de==="instanceMatrix"&&U.instanceMatrix&&(ae=U.instanceMatrix),de==="instanceColor"&&U.instanceColor&&(ae=U.instanceColor)),ae!==void 0){let O=ae.normalized,ye=ae.itemSize,Se=e.get(ae);if(Se===void 0)continue;let be=Se.buffer,Ve=Se.type,me=Se.bytesPerElement,$=Ve===i.INT||Ve===i.UNSIGNED_INT||ae.gpuType===Sl;if(ae.isInterleavedBufferAttribute){let X=ae.data,he=X.stride,Te=ae.offset;if(X.isInstancedInterleavedBuffer){for(let le=0;le<te.locationSize;le++)p(te.location+le,X.meshPerAttribute);U.isInstancedMesh!==!0&&F._maxInstanceCount===void 0&&(F._maxInstanceCount=X.meshPerAttribute*X.count)}else for(let le=0;le<te.locationSize;le++)m(te.location+le);i.bindBuffer(i.ARRAY_BUFFER,be);for(let le=0;le<te.locationSize;le++)A(te.location+le,ye/te.locationSize,Ve,O,he*me,(Te+ye/te.locationSize*le)*me,$)}else{if(ae.isInstancedBufferAttribute){for(let X=0;X<te.locationSize;X++)p(te.location+X,ae.meshPerAttribute);U.isInstancedMesh!==!0&&F._maxInstanceCount===void 0&&(F._maxInstanceCount=ae.meshPerAttribute*ae.count)}else for(let X=0;X<te.locationSize;X++)m(te.location+X);i.bindBuffer(i.ARRAY_BUFFER,be);for(let X=0;X<te.locationSize;X++)A(te.location+X,ye/te.locationSize,Ve,O,ye*me,ye/te.locationSize*X*me,$)}}else if(K!==void 0){let O=K[de];if(O!==void 0)switch(O.length){case 2:i.vertexAttrib2fv(te.location,O);break;case 3:i.vertexAttrib3fv(te.location,O);break;case 4:i.vertexAttrib4fv(te.location,O);break;default:i.vertexAttrib1fv(te.location,O)}}}}S()}function b(){w();for(let U in n){let B=n[U];for(let W in B){let F=B[W];for(let V in F){let se=F[V];for(let K in se)h(se[K].object),delete se[K];delete F[V]}}delete n[U]}}function E(U){if(n[U.id]===void 0)return;let B=n[U.id];for(let W in B){let F=B[W];for(let V in F){let se=F[V];for(let K in se)h(se[K].object),delete se[K];delete F[V]}}delete n[U.id]}function C(U){for(let B in n){let W=n[B];for(let F in W){let V=W[F];if(V[U.id]===void 0)continue;let se=V[U.id];for(let K in se)h(se[K].object),delete se[K];delete V[U.id]}}}function y(U){for(let B in n){let W=n[B],F=U.isInstancedMesh===!0?U.id:0,V=W[F];if(V!==void 0){for(let se in V){let K=V[se];for(let de in K)h(K[de].object),delete K[de];delete V[se]}delete W[F],Object.keys(W).length===0&&delete n[B]}}}function w(){P(),a=!0,r!==s&&(r=s,c(r.object))}function P(){s.geometry=null,s.program=null,s.wireframe=!1}return{setup:o,reset:w,resetDefaultState:P,dispose:b,releaseStatesOfGeometry:E,releaseStatesOfObject:y,releaseStatesOfProgram:C,initAttributes:x,enableAttribute:m,disableUnusedAttributes:S}}function Om(i,e,t){let n;function s(l){n=l}function r(l,c){i.drawArrays(n,l,c),t.update(c,n,1)}function a(l,c,h){h!==0&&(i.drawArraysInstanced(n,l,c,h),t.update(c,n,h))}function o(l,c,h){if(h===0)return;e.get("WEBGL_multi_draw").multiDrawArraysWEBGL(n,l,0,c,0,h);let u=0;for(let d=0;d<h;d++)u+=c[d];t.update(u,n,1)}this.setMode=s,this.render=r,this.renderInstances=a,this.renderMultiDraw=o}function Bm(i,e,t,n){let s;function r(){if(s!==void 0)return s;if(e.has("EXT_texture_filter_anisotropic")===!0){let C=e.get("EXT_texture_filter_anisotropic");s=i.getParameter(C.MAX_TEXTURE_MAX_ANISOTROPY_EXT)}else s=0;return s}function a(C){return!(C!==Vn&&n.convert(C)!==i.getParameter(i.IMPLEMENTATION_COLOR_READ_FORMAT))}function o(C){let y=C===sn&&(e.has("EXT_color_buffer_half_float")||e.has("EXT_color_buffer_float"));return!(C!==Rn&&C!==kn&&!y&&n.convert(C)!==i.getParameter(i.IMPLEMENTATION_COLOR_READ_TYPE))}function l(C){if(C==="highp"){if(i.getShaderPrecisionFormat(i.VERTEX_SHADER,i.HIGH_FLOAT).precision>0&&i.getShaderPrecisionFormat(i.FRAGMENT_SHADER,i.HIGH_FLOAT).precision>0)return"highp";C="mediump"}return C==="mediump"&&i.getShaderPrecisionFormat(i.VERTEX_SHADER,i.MEDIUM_FLOAT).precision>0&&i.getShaderPrecisionFormat(i.FRAGMENT_SHADER,i.MEDIUM_FLOAT).precision>0?"mediump":"lowp"}let c=t.precision!==void 0?t.precision:"highp",h=l(c);h!==c&&(ct("WebGLRenderer:",c,"not supported, using",h,"instead."),c=h);let f=t.logarithmicDepthBuffer===!0,u=t.reversedDepthBuffer===!0&&e.has("EXT_clip_control");t.reversedDepthBuffer===!0&&u===!1&&ct("WebGLRenderer: Unable to use reversed depth buffer due to missing EXT_clip_control extension. Fallback to default depth buffer.");let d=i.getParameter(i.MAX_TEXTURE_IMAGE_UNITS),g=i.getParameter(i.MAX_VERTEX_TEXTURE_IMAGE_UNITS),x=i.getParameter(i.MAX_TEXTURE_SIZE),m=i.getParameter(i.MAX_CUBE_MAP_TEXTURE_SIZE),p=i.getParameter(i.MAX_VERTEX_ATTRIBS),S=i.getParameter(i.MAX_VERTEX_UNIFORM_VECTORS),A=i.getParameter(i.MAX_VARYING_VECTORS),v=i.getParameter(i.MAX_FRAGMENT_UNIFORM_VECTORS),b=i.getParameter(i.MAX_SAMPLES),E=i.getParameter(i.SAMPLES);return{isWebGL2:!0,getMaxAnisotropy:r,getMaxPrecision:l,textureFormatReadable:a,textureTypeReadable:o,precision:c,logarithmicDepthBuffer:f,reversedDepthBuffer:u,maxTextures:d,maxVertexTextures:g,maxTextureSize:x,maxCubemapSize:m,maxAttributes:p,maxVertexUniforms:S,maxVaryings:A,maxFragmentUniforms:v,maxSamples:b,samples:E}}function zm(i){let e=this,t=null,n=0,s=!1,r=!1,a=new Zn,o=new dt,l={value:null,needsUpdate:!1};this.uniform=l,this.numPlanes=0,this.numIntersection=0,this.init=function(f,u){let d=f.length!==0||u||n!==0||s;return s=u,n=f.length,d},this.beginShadows=function(){r=!0,h(null)},this.endShadows=function(){r=!1},this.setGlobalState=function(f,u){t=h(f,u,0)},this.setState=function(f,u,d){let g=f.clippingPlanes,x=f.clipIntersection,m=f.clipShadows,p=i.get(f);if(!s||g===null||g.length===0||r&&!m)r?h(null):c();else{let S=r?0:n,A=S*4,v=p.clippingState||null;l.value=v,v=h(g,u,A,d);for(let b=0;b!==A;++b)v[b]=t[b];p.clippingState=v,this.numIntersection=x?this.numPlanes:0,this.numPlanes+=S}};function c(){l.value!==t&&(l.value=t,l.needsUpdate=n>0),e.numPlanes=n,e.numIntersection=0}function h(f,u,d,g){let x=f!==null?f.length:0,m=null;if(x!==0){if(m=l.value,g!==!0||m===null){let p=d+x*4,S=u.matrixWorldInverse;o.getNormalMatrix(S),(m===null||m.length<p)&&(m=new Float32Array(p));for(let A=0,v=d;A!==x;++A,v+=4)a.copy(f[A]).applyMatrix4(S,o),a.normal.toArray(m,v),m[v+3]=a.constant}l.value=m,l.needsUpdate=!0}return e.numPlanes=x,e.numIntersection=0,m}}var Sr=4,Hm=6,km=20,Vm=256,qa=new es,Vu=new it,F0=null,O0=0,B0=0,z0=!1,Gm=new I,Es=new I,hc=class{constructor(e){this._renderer=e,this._pingPongRenderTarget=null,this._lodMax=0,this._cubeSize=0,this._sizeLods=[],this._lodMeshes=[],this._backgroundBox=null,this._cubemapMaterial=null,this._equirectMaterial=null,this._blurMaterial=null,this._ggxMaterial=null}fromScene(e,t=0,n=.1,s=100,r={}){let{size:a=256,position:o=Gm}=r;F0=this._renderer.getRenderTarget(),O0=this._renderer.getActiveCubeFace(),B0=this._renderer.getActiveMipmapLevel(),z0=this._renderer.xr.enabled,this._renderer.xr.enabled=!1,this._setSize(a);let l=this._allocateTargets();return l.depthBuffer=!0,this._sceneToCubeUV(e,n,s,l,o),t>0&&this._blur(l,0,0,t),this._applyPMREM(l),this._cleanup(l),l}fromEquirectangular(e,t=null){return this._fromTexture(e,t)}fromCubemap(e,t=null){return this._fromTexture(e,t)}compileCubemapShader(){this._cubemapMaterial===null&&(this._cubemapMaterial=Xu(),this._compileMaterial(this._cubemapMaterial))}compileEquirectangularShader(){this._equirectMaterial===null&&(this._equirectMaterial=Wu(),this._compileMaterial(this._equirectMaterial))}dispose(){this._dispose(),this._cubemapMaterial!==null&&this._cubemapMaterial.dispose(),this._equirectMaterial!==null&&this._equirectMaterial.dispose(),this._backgroundBox!==null&&(this._backgroundBox.geometry.dispose(),this._backgroundBox.material.dispose())}_setSize(e){this._lodMax=Math.floor(Math.log2(e)),this._cubeSize=Math.pow(2,this._lodMax)}_dispose(){this._blurMaterial!==null&&this._blurMaterial.dispose(),this._ggxMaterial!==null&&this._ggxMaterial.dispose(),this._pingPongRenderTarget!==null&&this._pingPongRenderTarget.dispose();for(let e=0;e<this._lodMeshes.length;e++)this._lodMeshes[e].geometry.dispose()}_cleanup(e){this._renderer.setRenderTarget(F0,O0,B0),this._renderer.xr.enabled=z0,e.scissorTest=!1,Mr(e,0,0,e.width,e.height)}_fromTexture(e,t){e.mapping===is||e.mapping===Ss?this._setSize(e.image.length===0?16:e.image[0].width||e.image[0].image.width):this._setSize(e.image.width/4),F0=this._renderer.getRenderTarget(),O0=this._renderer.getActiveCubeFace(),B0=this._renderer.getActiveMipmapLevel(),z0=this._renderer.xr.enabled,this._renderer.xr.enabled=!1;let n=t||this._allocateTargets();return this._textureToCubeUV(e,n),this._applyPMREM(n),this._cleanup(n),n}_allocateTargets(){let e=3*Math.max(this._cubeSize,112),t=4*this._cubeSize,n={magFilter:gn,minFilter:gn,generateMipmaps:!1,type:sn,format:Vn,colorSpace:Yr,depthBuffer:!1},s=Gu(e,t,n);if(this._pingPongRenderTarget===null||this._pingPongRenderTarget.width!==e||this._pingPongRenderTarget.height!==t){this._pingPongRenderTarget!==null&&this._dispose(),this._pingPongRenderTarget=Gu(e,t,n);let{_lodMax:r}=this;({lodMeshes:this._lodMeshes,sizeLods:this._sizeLods}=Wm(r)),this._blurMaterial=qm(r,e,t),this._ggxMaterial=Xm(r,e,t)}return s}_compileMaterial(e){let t=new gt(new wt,e);this._renderer.compile(t,qa)}_sceneToCubeUV(e,t,n,s,r){let l=new mn(90,1,t,n),c=[1,-1,1,1,1,1],h=[1,1,1,-1,-1,-1],f=this._renderer,u=f.autoClear,d=f.toneMapping;f.getClearColor(Vu),f.toneMapping=Qn,f.autoClear=!1,f.state.buffers.depth.getReversed()&&(f.setRenderTarget(s),f.clearDepth(),f.setRenderTarget(null)),this._backgroundBox===null&&(this._backgroundBox=new gt(new ar,new en({name:"PMREM.Background",side:_n,depthWrite:!1,depthTest:!1})));let x=this._backgroundBox,m=x.material,p=!1,S=e.background;S?S.isColor&&(m.color.copy(S),e.background=null,p=!0):(m.color.copy(Vu),p=!0);for(let A=0;A<6;A++){let v=A%3;v===0?(l.up.set(0,c[A],0),l.position.set(r.x,r.y,r.z),l.lookAt(r.x+h[A],r.y,r.z)):v===1?(l.up.set(0,0,c[A]),l.position.set(r.x,r.y,r.z),l.lookAt(r.x,r.y+h[A],r.z)):(l.up.set(0,c[A],0),l.position.set(r.x,r.y,r.z),l.lookAt(r.x,r.y,r.z+h[A]));let b=this._cubeSize;Mr(s,v*b,A>2?b:0,b,b),f.setRenderTarget(s),p&&f.render(x,l),f.render(e,l)}f.toneMapping=d,f.autoClear=u,e.background=S}_textureToCubeUV(e,t){let n=this._renderer,s=e.mapping===is||e.mapping===Ss;s?(this._cubemapMaterial===null&&(this._cubemapMaterial=Xu()),this._cubemapMaterial.uniforms.flipEnvMap.value=e.isRenderTargetTexture===!1?-1:1):this._equirectMaterial===null&&(this._equirectMaterial=Wu());let r=s?this._cubemapMaterial:this._equirectMaterial,a=this._lodMeshes[0];a.material=r;let o=r.uniforms;o.envMap.value=e;let l=this._cubeSize;Mr(t,0,0,3*l,2*l),n.setRenderTarget(t),n.render(a,qa)}_applyPMREM(e){let t=this._renderer,n=t.autoClear;t.autoClear=!1;let s=this._lodMeshes.length;for(let r=1;r<s;r++)this._applyGGXFilter(e,r-1,r);t.autoClear=n}_applyGGXFilter(e,t,n){let s=this._renderer,r=this._pingPongRenderTarget,a=this._ggxMaterial,o=this._lodMeshes[n];o.material=a;let l=a.uniforms,c=n/(this._lodMeshes.length-1),h=t/(this._lodMeshes.length-1),f=Math.sqrt(c*c-h*h),u=c*1.25,d=f*u,{_lodMax:g}=this,x=this._sizeLods[n],m=3*x*(n>g-Sr?n-g+Sr:0),p=4*(this._cubeSize-x);l.envMap.value=e.texture,l.roughness.value=d,l.mipInt.value=g-t,Mr(r,m,p,3*x,2*x),s.setRenderTarget(r),s.render(o,qa),l.envMap.value=r.texture,l.roughness.value=0,l.mipInt.value=g-n,Mr(e,m,p,3*x,2*x),s.setRenderTarget(e),s.render(o,qa)}_blur(e,t,n,s){let r=this._pingPongRenderTarget,a=Math.min(s,Math.PI)/Math.SQRT2;this._blurPass(e,r,t,n,a),this._blurPass(r,e,n,n,a)}_blurPass(e,t,n,s,r){let a=this._renderer,o=this._blurMaterial,l=this._lodMeshes[s];l.material=o;let c=o.uniforms;c.envMap.value=e.texture,c.sigma.value=r,c.mipInt.value=this._lodMax-n;let h=this._sizeLods[s],f=3*h*(s>this._lodMax-Sr?s-this._lodMax+Sr:0),u=4*(this._cubeSize-h);Mr(t,f,u,3*h,2*h),a.setRenderTarget(t),a.render(l,qa)}};function Wm(i){let e=[],t=[],n=i,s=i-Sr+1+Hm;for(let r=0;r<s;r++){let a=Math.pow(2,n);e.push(a);let o=1/(a-2),l=-o,c=1+o,h=[l,l,c,l,c,c,l,l,c,c,l,c],f=6,u=6,d=3,g=new Float32Array(d*u*f),x=new Float32Array(d*u*f);for(let p=0;p<f;p++){let S=p%3*2/3-1,A=p>2?0:-1,v=[S,A,0,S+2/3,A,0,S+2/3,A+1,0,S,A,0,S+2/3,A+1,0,S,A+1,0];g.set(v,d*u*p);for(let b=0;b<u;b++){let E=h[b*2]*2-1,C=h[b*2+1]*2-1;p===0?Es.set(1,C,E):p===1?Es.set(-E,1,-C):p===2?Es.set(-E,C,1):p===3?Es.set(-1,C,-E):p===4?Es.set(-E,-1,C):Es.set(E,C,-1),Es.toArray(x,(p*u+b)*d)}}let m=new wt;m.setAttribute("position",new jt(g,d)),m.setAttribute("outputDirection",new jt(x,d)),t.push(new gt(m,null)),n>Sr&&n--}return{lodMeshes:t,sizeLods:e}}function Gu(i,e,t){let n=new $t(i,e,t);return n.texture.mapping=Ba,n.texture.name="PMREM.cubeUv",n.scissorTest=!0,n}function Mr(i,e,t,n,s){i.viewport.set(e,t,n,s),i.scissor.set(e,t,n,s)}function Xm(i,e,t){return new Ft({name:"PMREMGGXConvolution",defines:{GGX_SAMPLES:Vm,CUBEUV_TEXEL_WIDTH:1/e,CUBEUV_TEXEL_HEIGHT:1/t,CUBEUV_MAX_MIP:`${i}.0`},uniforms:{envMap:{value:null},roughness:{value:0},mipInt:{value:0}},vertexShader:dc(),fragmentShader:`

			precision highp float;
			precision highp int;

			varying vec3 vOutputDirection;

			uniform sampler2D envMap;
			uniform float roughness;
			uniform float mipInt;

			#define ENVMAP_TYPE_CUBE_UV
			#include <cube_uv_reflection_fragment>

			#define PI 3.14159265359

			// Van der Corput radical inverse
			float radicalInverse_VdC(uint bits) {
				bits = (bits << 16u) | (bits >> 16u);
				bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
				bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
				bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
				bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
				return float(bits) * 2.3283064365386963e-10; // / 0x100000000
			}

			// Hammersley sequence
			vec2 hammersley(uint i, uint N) {
				return vec2(float(i) / float(N), radicalInverse_VdC(i));
			}

			// GGX VNDF importance sampling (Eric Heitz 2018)
			// "Sampling the GGX Distribution of Visible Normals"
			// https://jcgt.org/published/0007/04/01/
			vec3 importanceSampleGGX_VNDF(vec2 Xi, vec3 V, float roughness) {
				float alpha = roughness * roughness;

				// Section 4.1: Orthonormal basis
				vec3 T1 = vec3(1.0, 0.0, 0.0);
				vec3 T2 = cross(V, T1);

				// Section 4.2: Parameterization of projected area
				float r = sqrt(Xi.x);
				float phi = 2.0 * PI * Xi.y;
				float t1 = r * cos(phi);
				float t2 = r * sin(phi);
				float s = 0.5 * (1.0 + V.z);
				t2 = (1.0 - s) * sqrt(1.0 - t1 * t1) + s * t2;

				// Section 4.3: Reprojection onto hemisphere
				vec3 Nh = t1 * T1 + t2 * T2 + sqrt(max(0.0, 1.0 - t1 * t1 - t2 * t2)) * V;

				// Section 3.4: Transform back to ellipsoid configuration
				return normalize(vec3(alpha * Nh.x, alpha * Nh.y, max(0.0, Nh.z)));
			}

			void main() {
				vec3 N = normalize(vOutputDirection);
				vec3 V = N; // Assume view direction equals normal for pre-filtering

				vec3 prefilteredColor = vec3(0.0);
				float totalWeight = 0.0;

				// For very low roughness, just sample the environment directly
				if (roughness < 0.001) {
					gl_FragColor = vec4(bilinearCubeUV(envMap, N, mipInt), 1.0);
					return;
				}

				// Tangent space basis for VNDF sampling
				vec3 up = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
				vec3 tangent = normalize(cross(up, N));
				vec3 bitangent = cross(N, tangent);

				for(uint i = 0u; i < uint(GGX_SAMPLES); i++) {
					vec2 Xi = hammersley(i, uint(GGX_SAMPLES));

					// For PMREM, V = N, so in tangent space V is always (0, 0, 1)
					vec3 H_tangent = importanceSampleGGX_VNDF(Xi, vec3(0.0, 0.0, 1.0), roughness);

					// Transform H back to world space
					vec3 H = normalize(tangent * H_tangent.x + bitangent * H_tangent.y + N * H_tangent.z);
					vec3 L = normalize(2.0 * dot(V, H) * H - V);

					float NdotL = max(dot(N, L), 0.0);

					if(NdotL > 0.0) {
						// Sample environment at fixed mip level
						// VNDF importance sampling handles the distribution filtering
						vec3 sampleColor = bilinearCubeUV(envMap, L, mipInt);

						// Weight by NdotL for the split-sum approximation
						// VNDF PDF naturally accounts for the visible microfacet distribution
						prefilteredColor += sampleColor * NdotL;
						totalWeight += NdotL;
					}
				}

				if (totalWeight > 0.0) {
					prefilteredColor = prefilteredColor / totalWeight;
				}

				gl_FragColor = vec4(prefilteredColor, 1.0);
			}
		`,blending:Hn,depthTest:!1,depthWrite:!1})}function qm(i,e,t){return new Ft({name:"SphericalGaussianBlur",defines:{SAMPLES:km,CUBEUV_TEXEL_WIDTH:1/e,CUBEUV_TEXEL_HEIGHT:1/t,CUBEUV_MAX_MIP:`${i}.0`},uniforms:{envMap:{value:null},sigma:{value:0},mipInt:{value:0}},vertexShader:dc(),fragmentShader:`

			precision highp float;
			precision highp int;

			varying vec3 vOutputDirection;

			uniform sampler2D envMap;
			uniform float sigma;
			uniform float mipInt;

			#define ENVMAP_TYPE_CUBE_UV
			#include <cube_uv_reflection_fragment>

			#define PI 3.14159265359
			#define GOLDEN_ANGLE 2.39996322973

			void main() {

				if ( sigma == 0.0 ) {

					gl_FragColor = vec4( bilinearCubeUV( envMap, vOutputDirection, mipInt ), 1.0 );
					return;

				}

				vec3 outputDirection = normalize( vOutputDirection );

				vec3 up = abs( outputDirection.z ) < 0.999 ? vec3( 0.0, 0.0, 1.0 ) : vec3( 1.0, 0.0, 0.0 );
				vec3 tangent = normalize( cross( up, outputDirection ) );
				vec3 bitangent = cross( outputDirection, tangent );

				// Truncate the kernel at three standard deviations or at the antipode.
				float thetaMax = min( 3.0 * sigma, PI );
				float truncation = 1.0 - exp( - 0.5 * thetaMax * thetaMax / ( sigma * sigma ) );

				vec3 accumColor = vec3( 0.0 );
				float accumWeight = 0.0;

				for ( int i = 0; i < SAMPLES; i ++ ) {

					// Stratified inverse-CDF sampling of the Gaussian, placed on a golden-angle spiral.
					float stratum = ( float( i ) + 0.5 ) / float( SAMPLES );
					float theta = sigma * sqrt( - 2.0 * log( 1.0 - stratum * truncation ) );
					float phi = float( i ) * GOLDEN_ANGLE;

					vec3 offset = cos( phi ) * tangent + sin( phi ) * bitangent;
					vec3 sampleDirection = cos( theta ) * outputDirection + sin( theta ) * offset;

					// Correct the planar sample density to solid angle.
					float weight = sin( theta ) / theta;

					accumColor += weight * bilinearCubeUV( envMap, sampleDirection, mipInt );
					accumWeight += weight;

				}

				gl_FragColor = vec4( accumColor / accumWeight, 1.0 );

			}
		`,blending:Hn,depthTest:!1,depthWrite:!1})}function Wu(){return new Ft({name:"EquirectangularToCubeUV",uniforms:{envMap:{value:null}},vertexShader:dc(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			varying vec3 vOutputDirection;

			uniform sampler2D envMap;

			#include <common>

			void main() {

				vec3 outputDirection = normalize( vOutputDirection );
				vec2 uv = equirectUv( outputDirection );

				gl_FragColor = vec4( texture2D ( envMap, uv ).rgb, 1.0 );

			}
		`,blending:Hn,depthTest:!1,depthWrite:!1})}function Xu(){return new Ft({name:"CubemapToCubeUV",uniforms:{envMap:{value:null},flipEnvMap:{value:-1}},vertexShader:dc(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			uniform float flipEnvMap;

			varying vec3 vOutputDirection;

			uniform samplerCube envMap;

			void main() {

				gl_FragColor = textureCube( envMap, vec3( flipEnvMap * vOutputDirection.x, vOutputDirection.yz ) );

			}
		`,blending:Hn,depthTest:!1,depthWrite:!1})}function dc(){return`

		precision mediump float;
		precision mediump int;

		attribute vec3 outputDirection;

		varying vec3 vOutputDirection;

		void main() {

			vOutputDirection = outputDirection;
			gl_Position = vec4( position, 1.0 );

		}
	`}var uc=class extends $t{constructor(e=1,t={}){super(e,e,t),this.isWebGLCubeRenderTarget=!0;let n={width:e,height:e,depth:1},s=[n,n,n,n,n,n];this.texture=new ra(s),this._setTextureOptions(t),this.texture.isRenderTargetTexture=!0}fromEquirectangularTexture(e,t){this.texture.type=t.type,this.texture.colorSpace=t.colorSpace,this.texture.generateMipmaps=t.generateMipmaps,this.texture.minFilter=t.minFilter,this.texture.magFilter=t.magFilter;let n={uniforms:{tEquirect:{value:null}},vertexShader:`

				varying vec3 vWorldDirection;

				vec3 transformDirection( in vec3 dir, in mat4 matrix ) {

					return normalize( ( matrix * vec4( dir, 0.0 ) ).xyz );

				}

				void main() {

					vWorldDirection = transformDirection( position, modelMatrix );

					#include <begin_vertex>
					#include <project_vertex>

				}
			`,fragmentShader:`

				uniform sampler2D tEquirect;

				varying vec3 vWorldDirection;

				#include <common>

				void main() {

					vec3 direction = normalize( vWorldDirection );

					vec2 sampleUV = equirectUv( direction );

					gl_FragColor = texture2D( tEquirect, sampleUV );

				}
			`},s=new ar(5,5,5),r=new Ft({name:"CubemapFromEquirect",uniforms:bs(n.uniforms),vertexShader:n.vertexShader,fragmentShader:n.fragmentShader,side:_n,blending:Hn});r.uniforms.tEquirect.value=t;let a=new gt(s,r),o=t.minFilter;return t.minFilter===xi&&(t.minFilter=gn),new xl(1,10,this).update(e,a),t.minFilter=o,a.geometry.dispose(),a.material.dispose(),this}clear(e,t=!0,n=!0,s=!0){let r=e.getRenderTarget();for(let a=0;a<6;a++)e.setRenderTarget(this,a),e.clear(t,n,s);e.setRenderTarget(r)}};function Ym(i){let e=new WeakMap,t=new WeakMap,n=null;function s(u,d=!1){return u==null?null:d?a(u):r(u)}function r(u){if(u&&u.isTexture){let d=u.mapping;if(d===xr||d===yl)if(e.has(u)){let g=e.get(u).texture;return o(g,u.mapping)}else{let g=u.image;if(g&&g.height>0){let x=new uc(g.height);return x.fromEquirectangularTexture(i,u),e.set(u,x),u.addEventListener("dispose",c),o(x.texture,u.mapping)}else return null}}return u}function a(u){if(u&&u.isTexture){let d=u.mapping,g=d===xr||d===yl,x=d===is||d===Ss;if(g||x){let m=t.get(u),p=m!==void 0?m.texture.pmremVersion:0;if(u.isRenderTargetTexture&&u.pmremVersion!==p)return n===null&&(n=new hc(i)),m=g?n.fromEquirectangular(u,m):n.fromCubemap(u,m),m.texture.pmremVersion=u.pmremVersion,t.set(u,m),m.texture;if(m!==void 0)return m.texture;{let S=u.image;return g&&S&&S.height>0||x&&S&&l(S)?(n===null&&(n=new hc(i)),m=g?n.fromEquirectangular(u):n.fromCubemap(u),m.texture.pmremVersion=u.pmremVersion,t.set(u,m),u.addEventListener("dispose",h),m.texture):null}}}return u}function o(u,d){return d===xr?u.mapping=is:d===yl&&(u.mapping=Ss),u}function l(u){let d=0,g=6;for(let x=0;x<g;x++)u[x]!==void 0&&d++;return d===g}function c(u){let d=u.target;d.removeEventListener("dispose",c);let g=e.get(d);g!==void 0&&(e.delete(d),g.dispose())}function h(u){let d=u.target;d.removeEventListener("dispose",h);let g=t.get(d);g!==void 0&&(t.delete(d),g.dispose())}function f(){e=new WeakMap,t=new WeakMap,n!==null&&(n.dispose(),n=null)}return{get:s,dispose:f}}function $m(i){let e={};function t(n){if(e[n]!==void 0)return e[n];let s=i.getExtension(n);return e[n]=s,s}return{has:function(n){return t(n)!==null},init:function(){t("EXT_color_buffer_float"),t("WEBGL_clip_cull_distance"),t("OES_texture_float_linear"),t("EXT_color_buffer_half_float"),t("WEBGL_multisampled_render_to_texture"),t("WEBGL_render_shared_exponent")},get:function(n){let s=t(n);return s===null&&_s("WebGLRenderer: "+n+" extension not supported."),s}}}function Zm(i,e,t,n){let s={},r=new WeakMap;function a(f){let u=f.target;u.index!==null&&e.remove(u.index);for(let g in u.attributes)e.remove(u.attributes[g]);u.removeEventListener("dispose",a),delete s[u.id];let d=r.get(u);d&&(e.remove(d),r.delete(u)),n.releaseStatesOfGeometry(u),u.isInstancedBufferGeometry===!0&&delete u._maxInstanceCount,t.memory.geometries--}function o(f,u){return s[u.id]===!0||(u.addEventListener("dispose",a),s[u.id]=!0,t.memory.geometries++),u}function l(f){let u=f.attributes;for(let d in u)e.update(u[d],i.ARRAY_BUFFER)}function c(f){let u=[],d=f.index,g=f.attributes.position,x=0;if(g===void 0)return;if(d!==null){let S=d.array;x=d.version;for(let A=0,v=S.length;A<v;A+=3){let b=S[A+0],E=S[A+1],C=S[A+2];u.push(b,E,E,C,C,b)}}else{let S=g.array;x=g.version;for(let A=0,v=S.length/3-1;A<v;A+=3){let b=A+0,E=A+1,C=A+2;u.push(b,E,E,C,C,b)}}let m=new(g.count>=65535?Qr:jr)(u,1);m.version=x;let p=r.get(f);p&&e.remove(p),r.set(f,m)}function h(f){let u=r.get(f);if(u){let d=f.index;d!==null&&u.version<d.version&&c(f)}else c(f);return r.get(f)}return{get:o,update:l,getWireframeAttribute:h}}function Jm(i,e,t){let n;function s(f){n=f}let r,a;function o(f){r=f.type,a=f.bytesPerElement}function l(f,u){i.drawElements(n,u,r,f*a),t.update(u,n,1)}function c(f,u,d){d!==0&&(i.drawElementsInstanced(n,u,r,f*a,d),t.update(u,n,d))}function h(f,u,d){if(d===0)return;e.get("WEBGL_multi_draw").multiDrawElementsWEBGL(n,u,0,r,f,0,d);let x=0;for(let m=0;m<d;m++)x+=u[m];t.update(x,n,1)}this.setMode=s,this.setIndex=o,this.render=l,this.renderInstances=c,this.renderMultiDraw=h}function Km(i){let e={geometries:0,textures:0},t={frame:0,calls:0,triangles:0,points:0,lines:0};function n(r,a,o){switch(t.calls++,a){case i.TRIANGLES:t.triangles+=o*(r/3);break;case i.LINES:t.lines+=o*(r/2);break;case i.LINE_STRIP:t.lines+=o*(r-1);break;case i.LINE_LOOP:t.lines+=o*r;break;case i.POINTS:t.points+=o*r;break;default:lt("WebGLInfo: Unknown draw mode:",a);break}}function s(){t.calls=0,t.triangles=0,t.points=0,t.lines=0}return{memory:e,render:t,programs:null,autoReset:!0,reset:s,update:n}}function jm(i,e,t){let n=new WeakMap,s=new Gt;function r(a,o,l){let c=a.morphTargetInfluences,h=o.morphAttributes.position||o.morphAttributes.normal||o.morphAttributes.color,f=h!==void 0?h.length:0,u=n.get(o);if(u===void 0||u.count!==f){let w=function(){C.dispose(),n.delete(o),o.removeEventListener("dispose",w)};u!==void 0&&u.texture.dispose();let d=o.morphAttributes.position!==void 0,g=o.morphAttributes.normal!==void 0,x=o.morphAttributes.color!==void 0,m=o.morphAttributes.position||[],p=o.morphAttributes.normal||[],S=o.morphAttributes.color||[],A=0;d===!0&&(A=1),g===!0&&(A=2),x===!0&&(A=3);let v=o.attributes.position.count*A,b=1;v>e.maxTextureSize&&(b=Math.ceil(v/e.maxTextureSize),v=e.maxTextureSize);let E=new Float32Array(v*b*4*f),C=new Jr(E,v,b,f);C.type=kn,C.needsUpdate=!0;let y=A*4;for(let P=0;P<f;P++){let U=m[P],B=p[P],W=S[P],F=v*b*4*P;for(let V=0;V<U.count;V++){let se=V*y;d===!0&&(s.fromBufferAttribute(U,V),E[F+se+0]=s.x,E[F+se+1]=s.y,E[F+se+2]=s.z,E[F+se+3]=0),g===!0&&(s.fromBufferAttribute(B,V),E[F+se+4]=s.x,E[F+se+5]=s.y,E[F+se+6]=s.z,E[F+se+7]=0),x===!0&&(s.fromBufferAttribute(W,V),E[F+se+8]=s.x,E[F+se+9]=s.y,E[F+se+10]=s.z,E[F+se+11]=W.itemSize===4?s.w:1)}}u={count:f,texture:C,size:new ue(v,b)},n.set(o,u),o.addEventListener("dispose",w)}if(a.isInstancedMesh===!0&&a.morphTexture!==null)l.getUniforms().setValue(i,"morphTexture",a.morphTexture,t);else{let d=0;for(let x=0;x<c.length;x++)d+=c[x];let g=o.morphTargetsRelative?1:1-d;l.getUniforms().setValue(i,"morphTargetBaseInfluence",g),l.getUniforms().setValue(i,"morphTargetInfluences",c)}l.getUniforms().setValue(i,"morphTargetsTexture",u.texture,t),l.getUniforms().setValue(i,"morphTargetsTextureSize",u.size)}return{update:r}}function Qm(i,e,t,n,s){let r=new WeakMap;function a(c){let h=s.render.frame,f=c.geometry,u=e.get(c,f);if(r.get(u)!==h&&(e.update(u),r.set(u,h)),c.isInstancedMesh&&(c.hasEventListener("dispose",l)===!1&&c.addEventListener("dispose",l),r.get(c)!==h&&(t.update(c.instanceMatrix,i.ARRAY_BUFFER),c.instanceColor!==null&&t.update(c.instanceColor,i.ARRAY_BUFFER),r.set(c,h))),c.isSkinnedMesh){let d=c.skeleton;r.get(d)!==h&&(d.update(),r.set(d,h))}return u}function o(){r=new WeakMap}function l(c){let h=c.target;h.removeEventListener("dispose",l),n.releaseStatesOfObject(h),t.remove(h.instanceMatrix),h.instanceColor!==null&&t.remove(h.instanceColor)}return{update:a,dispose:o}}var eg={[La]:"LINEAR_TONE_MAPPING",[Da]:"REINHARD_TONE_MAPPING",[Na]:"CINEON_TONE_MAPPING",[Ms]:"ACES_FILMIC_TONE_MAPPING",[Fa]:"AGX_TONE_MAPPING",[Oa]:"NEUTRAL_TONE_MAPPING",[Ua]:"CUSTOM_TONE_MAPPING"};function tg(i,e,t,n,s,r){let a=new $t(e,t,{type:i,depthBuffer:s,stencilBuffer:r,samples:n?4:0,storeMultisampledDepthBuffer:!1,storeMultisampledStencilBuffer:!1,resolveDepthBuffer:!1,resolveStencilBuffer:!1}),o=null,l=null,c=new wt;c.setAttribute("position",new ft([-1,3,0,-1,-1,0,3,-1,0],3)),c.setAttribute("uv",new ft([0,2,0,0,2,0],2));let h=new dr({uniforms:{tDiffuse:{value:null}},vertexShader:`
			precision highp float;

			uniform mat4 modelViewMatrix;
			uniform mat4 projectionMatrix;

			attribute vec3 position;
			attribute vec2 uv;

			varying vec2 vUv;

			void main() {
				vUv = uv;
				gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
			}`,fragmentShader:`
			precision highp float;

			uniform sampler2D tDiffuse;

			varying vec2 vUv;

			#include <tonemapping_pars_fragment>
			#include <colorspace_pars_fragment>

			void main() {
				gl_FragColor = texture2D( tDiffuse, vUv );

				#ifdef LINEAR_TONE_MAPPING
					gl_FragColor.rgb = LinearToneMapping( gl_FragColor.rgb );
				#elif defined( REINHARD_TONE_MAPPING )
					gl_FragColor.rgb = ReinhardToneMapping( gl_FragColor.rgb );
				#elif defined( CINEON_TONE_MAPPING )
					gl_FragColor.rgb = CineonToneMapping( gl_FragColor.rgb );
				#elif defined( ACES_FILMIC_TONE_MAPPING )
					gl_FragColor.rgb = ACESFilmicToneMapping( gl_FragColor.rgb );
				#elif defined( AGX_TONE_MAPPING )
					gl_FragColor.rgb = AgXToneMapping( gl_FragColor.rgb );
				#elif defined( NEUTRAL_TONE_MAPPING )
					gl_FragColor.rgb = NeutralToneMapping( gl_FragColor.rgb );
				#elif defined( CUSTOM_TONE_MAPPING )
					gl_FragColor.rgb = CustomToneMapping( gl_FragColor.rgb );
				#endif

				#ifdef SRGB_TRANSFER
					gl_FragColor = sRGBTransferOETF( gl_FragColor );
				#endif
			}`,depthTest:!1,depthWrite:!1}),f=new gt(c,h),u=new es(-1,1,1,-1,0,1),d=null,g=null,x=!1,m,p=null,S=[],A=!1;this.setSize=function(v,b){a.setSize(v,b),o!==null&&o.setSize(v,b),l!==null&&l.setSize(v,b);for(let E=0;E<S.length;E++){let C=S[E];C.setSize&&C.setSize(v,b)}},this.setEffects=function(v){S=v,A=S.length>0&&S[0].isRenderPass===!0;let b=a.width,E=a.height;S.length>0&&o===null&&(o=new $t(b,E,{type:sn,depthBuffer:!1,stencilBuffer:!1}),l=new $t(b,E,{type:sn,depthBuffer:!1,stencilBuffer:!1}));for(let C=0;C<S.length;C++){let y=S[C];y.setSize&&y.setSize(b,E)}},this.begin=function(v,b){if(x||v.toneMapping===Qn&&S.length===0)return!1;if(p=b,b!==null){let E=b.width,C=b.height;(a.width!==E||a.height!==C)&&this.setSize(E,C)}return A===!1&&v.setRenderTarget(a),m=v.toneMapping,v.toneMapping=Qn,!0},this.hasRenderPass=function(){return A},this.end=function(v,b){v.toneMapping=m,x=!0;let E=a,C=o;for(let y=0;y<S.length;y++){let w=S[y];w.enabled!==!1&&(w.render(v,C,E,b),w.needsSwap!==!1&&(E=C,C=C===o?l:o))}if(d!==v.outputColorSpace||g!==v.toneMapping){d=v.outputColorSpace,g=v.toneMapping,h.defines={},St.getTransfer(d)===Pt&&(h.defines.SRGB_TRANSFER="");let y=eg[g];y&&(h.defines[y]=""),h.needsUpdate=!0}h.uniforms.tDiffuse.value=E.texture,v.setRenderTarget(p),v.render(f,u),p=null,x=!1},this.isCompositing=function(){return x},this.dispose=function(){a.dispose(),o!==null&&o.dispose(),l!==null&&l.dispose(),c.dispose(),h.dispose()}}var ff=new fn,V0=new Zi(1,1),df=new Jr,pf=new Ko,mf=new ra,qu=[],Yu=[],$u=new Float32Array(16),Zu=new Float32Array(9),Ju=new Float32Array(4);function Er(i,e,t){let n=i[0];if(n<=0||n>0)return i;let s=e*t,r=qu[s];if(r===void 0&&(r=new Float32Array(s),qu[s]=r),e!==0){n.toArray(r,0);for(let a=1,o=0;a!==e;++a)o+=t,i[a].toArray(r,o)}return r}function rn(i,e){if(i.length!==e.length)return!1;for(let t=0,n=i.length;t<n;t++)if(i[t]!==e[t])return!1;return!0}function an(i,e){for(let t=0,n=e.length;t<n;t++)i[t]=e[t]}function pc(i,e){let t=Yu[e];t===void 0&&(t=new Int32Array(e),Yu[e]=t);for(let n=0;n!==e;++n)t[n]=i.allocateTextureUnit();return t}function ng(i,e){let t=this.cache;t[0]!==e&&(i.uniform1f(this.addr,e),t[0]=e)}function ig(i,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(i.uniform2f(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(rn(t,e))return;i.uniform2fv(this.addr,e),an(t,e)}}function sg(i,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(i.uniform3f(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else if(e.r!==void 0)(t[0]!==e.r||t[1]!==e.g||t[2]!==e.b)&&(i.uniform3f(this.addr,e.r,e.g,e.b),t[0]=e.r,t[1]=e.g,t[2]=e.b);else{if(rn(t,e))return;i.uniform3fv(this.addr,e),an(t,e)}}function rg(i,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(i.uniform4f(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(rn(t,e))return;i.uniform4fv(this.addr,e),an(t,e)}}function ag(i,e){let t=this.cache,n=e.elements;if(n===void 0){if(rn(t,e))return;i.uniformMatrix2fv(this.addr,!1,e),an(t,e)}else{if(rn(t,n))return;Ju.set(n),i.uniformMatrix2fv(this.addr,!1,Ju),an(t,n)}}function og(i,e){let t=this.cache,n=e.elements;if(n===void 0){if(rn(t,e))return;i.uniformMatrix3fv(this.addr,!1,e),an(t,e)}else{if(rn(t,n))return;Zu.set(n),i.uniformMatrix3fv(this.addr,!1,Zu),an(t,n)}}function lg(i,e){let t=this.cache,n=e.elements;if(n===void 0){if(rn(t,e))return;i.uniformMatrix4fv(this.addr,!1,e),an(t,e)}else{if(rn(t,n))return;$u.set(n),i.uniformMatrix4fv(this.addr,!1,$u),an(t,n)}}function cg(i,e){let t=this.cache;t[0]!==e&&(i.uniform1i(this.addr,e),t[0]=e)}function hg(i,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(i.uniform2i(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(rn(t,e))return;i.uniform2iv(this.addr,e),an(t,e)}}function ug(i,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(i.uniform3i(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else{if(rn(t,e))return;i.uniform3iv(this.addr,e),an(t,e)}}function fg(i,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(i.uniform4i(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(rn(t,e))return;i.uniform4iv(this.addr,e),an(t,e)}}function dg(i,e){let t=this.cache;t[0]!==e&&(i.uniform1ui(this.addr,e),t[0]=e)}function pg(i,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y)&&(i.uniform2ui(this.addr,e.x,e.y),t[0]=e.x,t[1]=e.y);else{if(rn(t,e))return;i.uniform2uiv(this.addr,e),an(t,e)}}function mg(i,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z)&&(i.uniform3ui(this.addr,e.x,e.y,e.z),t[0]=e.x,t[1]=e.y,t[2]=e.z);else{if(rn(t,e))return;i.uniform3uiv(this.addr,e),an(t,e)}}function gg(i,e){let t=this.cache;if(e.x!==void 0)(t[0]!==e.x||t[1]!==e.y||t[2]!==e.z||t[3]!==e.w)&&(i.uniform4ui(this.addr,e.x,e.y,e.z,e.w),t[0]=e.x,t[1]=e.y,t[2]=e.z,t[3]=e.w);else{if(rn(t,e))return;i.uniform4uiv(this.addr,e),an(t,e)}}function _g(i,e,t){let n=this.cache,s=t.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s);let r;this.type===i.SAMPLER_2D_SHADOW?(V0.compareFunction=t.isReversedDepthBuffer()?oc:ac,r=V0):r=ff,t.setTexture2D(e||r,s)}function xg(i,e,t){let n=this.cache,s=t.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s),t.setTexture3D(e||pf,s)}function vg(i,e,t){let n=this.cache,s=t.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s),t.setTextureCube(e||mf,s)}function yg(i,e,t){let n=this.cache,s=t.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s),t.setTexture2DArray(e||df,s)}function Mg(i){switch(i){case 5126:return ng;case 35664:return ig;case 35665:return sg;case 35666:return rg;case 35674:return ag;case 35675:return og;case 35676:return lg;case 5124:case 35670:return cg;case 35667:case 35671:return hg;case 35668:case 35672:return ug;case 35669:case 35673:return fg;case 5125:return dg;case 36294:return pg;case 36295:return mg;case 36296:return gg;case 35678:case 36198:case 36298:case 36306:case 35682:return _g;case 35679:case 36299:case 36307:return xg;case 35680:case 36300:case 36308:case 36293:return vg;case 36289:case 36303:case 36311:case 36292:return yg}}function Sg(i,e){i.uniform1fv(this.addr,e)}function bg(i,e){let t=Er(e,this.size,2);i.uniform2fv(this.addr,t)}function Eg(i,e){let t=Er(e,this.size,3);i.uniform3fv(this.addr,t)}function Tg(i,e){let t=Er(e,this.size,4);i.uniform4fv(this.addr,t)}function wg(i,e){let t=Er(e,this.size,4);i.uniformMatrix2fv(this.addr,!1,t)}function Ag(i,e){let t=Er(e,this.size,9);i.uniformMatrix3fv(this.addr,!1,t)}function Rg(i,e){let t=Er(e,this.size,16);i.uniformMatrix4fv(this.addr,!1,t)}function Cg(i,e){i.uniform1iv(this.addr,e)}function Pg(i,e){i.uniform2iv(this.addr,e)}function Ig(i,e){i.uniform3iv(this.addr,e)}function Lg(i,e){i.uniform4iv(this.addr,e)}function Dg(i,e){i.uniform1uiv(this.addr,e)}function Ng(i,e){i.uniform2uiv(this.addr,e)}function Ug(i,e){i.uniform3uiv(this.addr,e)}function Fg(i,e){i.uniform4uiv(this.addr,e)}function Og(i,e,t){let n=this.cache,s=e.length,r=pc(t,s);rn(n,r)||(i.uniform1iv(this.addr,r),an(n,r));let a;this.type===i.SAMPLER_2D_SHADOW?a=V0:a=ff;for(let o=0;o!==s;++o)t.setTexture2D(e[o]||a,r[o])}function Bg(i,e,t){let n=this.cache,s=e.length,r=pc(t,s);rn(n,r)||(i.uniform1iv(this.addr,r),an(n,r));for(let a=0;a!==s;++a)t.setTexture3D(e[a]||pf,r[a])}function zg(i,e,t){let n=this.cache,s=e.length,r=pc(t,s);rn(n,r)||(i.uniform1iv(this.addr,r),an(n,r));for(let a=0;a!==s;++a)t.setTextureCube(e[a]||mf,r[a])}function Hg(i,e,t){let n=this.cache,s=e.length,r=pc(t,s);rn(n,r)||(i.uniform1iv(this.addr,r),an(n,r));for(let a=0;a!==s;++a)t.setTexture2DArray(e[a]||df,r[a])}function kg(i){switch(i){case 5126:return Sg;case 35664:return bg;case 35665:return Eg;case 35666:return Tg;case 35674:return wg;case 35675:return Ag;case 35676:return Rg;case 5124:case 35670:return Cg;case 35667:case 35671:return Pg;case 35668:case 35672:return Ig;case 35669:case 35673:return Lg;case 5125:return Dg;case 36294:return Ng;case 36295:return Ug;case 36296:return Fg;case 35678:case 36198:case 36298:case 36306:case 35682:return Og;case 35679:case 36299:case 36307:return Bg;case 35680:case 36300:case 36308:case 36293:return zg;case 36289:case 36303:case 36311:case 36292:return Hg}}var G0=class{constructor(e,t,n){this.id=e,this.addr=n,this.cache=[],this.type=t.type,this.setValue=Mg(t.type)}},W0=class{constructor(e,t,n){this.id=e,this.addr=n,this.cache=[],this.type=t.type,this.size=t.size,this.setValue=kg(t.type)}},X0=class{constructor(e){this.id=e,this.seq=[],this.map={}}setValue(e,t,n){let s=this.seq;for(let r=0,a=s.length;r!==a;++r){let o=s[r];o.setValue(e,t[o.id],n)}}},H0=/(\w+)(\])?(\[|\.)?/g;function Ku(i,e){i.seq.push(e),i.map[e.id]=e}function Vg(i,e,t){let n=i.name,s=n.length;for(H0.lastIndex=0;;){let r=H0.exec(n),a=H0.lastIndex,o=r[1],l=r[2]==="]",c=r[3];if(l&&(o=o|0),c===void 0||c==="["&&a+2===s){Ku(t,c===void 0?new G0(o,i,e):new W0(o,i,e));break}else{let f=t.map[o];f===void 0&&(f=new X0(o),Ku(t,f)),t=f}}}var br=class{constructor(e,t){this.seq=[],this.map={};let n=e.getProgramParameter(t,e.ACTIVE_UNIFORMS);for(let a=0;a<n;++a){let o=e.getActiveUniform(t,a),l=e.getUniformLocation(t,o.name);Vg(o,l,this)}let s=[],r=[];for(let a of this.seq)a.type===e.SAMPLER_2D_SHADOW||a.type===e.SAMPLER_CUBE_SHADOW||a.type===e.SAMPLER_2D_ARRAY_SHADOW?s.push(a):r.push(a);s.length>0&&(this.seq=s.concat(r))}setValue(e,t,n,s){let r=this.map[t];r!==void 0&&r.setValue(e,n,s)}setOptional(e,t,n){let s=t[n];s!==void 0&&this.setValue(e,n,s)}static upload(e,t,n,s){for(let r=0,a=t.length;r!==a;++r){let o=t[r],l=n[o.id];l.needsUpdate!==!1&&o.setValue(e,l.value,s)}}static seqWithValue(e,t){let n=[];for(let s=0,r=e.length;s!==r;++s){let a=e[s];a.id in t&&n.push(a)}return n}};function ju(i,e,t){let n=i.createShader(e);return i.shaderSource(n,t),i.compileShader(n),n}var Gg=37297,Wg=0;function Xg(i,e){let t=i.split(`
`),n=[],s=Math.max(e-6,0),r=Math.min(e+6,t.length);for(let a=s;a<r;a++){let o=a+1;n.push(`${o===e?">":" "} ${o}: ${t[a]}`)}return n.join(`
`)}var Qu=new dt;function qg(i){St._getMatrix(Qu,St.workingColorSpace,i);let e=`mat3( ${Qu.elements.map(t=>t.toFixed(4))} )`;switch(St.getTransfer(i)){case $r:return[e,"LinearTransferOETF"];case Pt:return[e,"sRGBTransferOETF"];default:return ct("WebGLProgram: Unsupported color space: ",i),[e,"LinearTransferOETF"]}}function ef(i,e,t){let n=i.getShaderParameter(e,i.COMPILE_STATUS),r=(i.getShaderInfoLog(e)||"").trim();if(n&&r==="")return"";let a=/ERROR: 0:(\d+)/.exec(r);if(a){let o=parseInt(a[1]);return t.toUpperCase()+`

`+r+`

`+Xg(i.getShaderSource(e),o)}else return r}function Yg(i,e){let t=qg(e);return[`vec4 ${i}( vec4 value ) {`,`	return ${t[1]}( vec4( value.rgb * ${t[0]}, value.a ) );`,"}"].join(`
`)}var $g={[La]:"Linear",[Da]:"Reinhard",[Na]:"Cineon",[Ms]:"ACESFilmic",[Fa]:"AgX",[Oa]:"Neutral",[Ua]:"Custom"};function Zg(i,e){let t=$g[e];return t===void 0?(ct("WebGLProgram: Unsupported toneMapping:",e),"vec3 "+i+"( vec3 color ) { return LinearToneMapping( color ); }"):"vec3 "+i+"( vec3 color ) { return "+t+"ToneMapping( color ); }"}var cc=new I;function Jg(){St.getLuminanceCoefficients(cc);let i=cc.x.toFixed(4),e=cc.y.toFixed(4),t=cc.z.toFixed(4);return["float luminance( const in vec3 rgb ) {",`	const vec3 weights = vec3( ${i}, ${e}, ${t} );`,"	return dot( weights, rgb );","}"].join(`
`)}function Kg(i){return[i.extensionClipCullDistance?"#extension GL_ANGLE_clip_cull_distance : require":"",i.extensionMultiDraw?"#extension GL_ANGLE_multi_draw : require":""].filter($a).join(`
`)}function jg(i){let e=[];for(let t in i){let n=i[t];n!==!1&&e.push("#define "+t+" "+n)}return e.join(`
`)}function Qg(i,e){let t={},n=i.getProgramParameter(e,i.ACTIVE_ATTRIBUTES);for(let s=0;s<n;s++){let r=i.getActiveAttrib(e,s),a=r.name,o=1;r.type===i.FLOAT_MAT2&&(o=2),r.type===i.FLOAT_MAT3&&(o=3),r.type===i.FLOAT_MAT4&&(o=4),t[a]={type:r.type,location:i.getAttribLocation(e,a),locationSize:o}}return t}function $a(i){return i!==""}function tf(i,e){let t=e.numSpotLightShadows+e.numSpotLightMaps-e.numSpotLightShadowsWithMaps;return i.replace(/NUM_SUN_LIGHTS/g,e.numSunLights).replace(/NUM_DIR_LIGHTS/g,e.numDirLights).replace(/NUM_SPOT_LIGHTS/g,e.numSpotLights).replace(/NUM_SPOT_LIGHT_MAPS/g,e.numSpotLightMaps).replace(/NUM_SPOT_LIGHT_COORDS/g,t).replace(/NUM_RECT_AREA_LIGHTS/g,e.numRectAreaLights).replace(/NUM_POINT_LIGHTS/g,e.numPointLights).replace(/NUM_HEMI_LIGHTS/g,e.numHemiLights).replace(/NUM_SUN_LIGHT_SHADOWS/g,e.numSunLightShadows).replace(/NUM_DIR_LIGHT_SHADOWS/g,e.numDirLightShadows).replace(/NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS/g,e.numSpotLightShadowsWithMaps).replace(/NUM_SPOT_LIGHT_SHADOWS/g,e.numSpotLightShadows).replace(/NUM_POINT_LIGHT_SHADOWS/g,e.numPointLightShadows)}function nf(i,e){return i.replace(/NUM_CLIPPING_PLANES/g,e.numClippingPlanes).replace(/UNION_CLIPPING_PLANES/g,e.numClippingPlanes-e.numClipIntersection)}var e2=/^[ \t]*#include +<([\w\d./]+)>/gm;function q0(i){return i.replace(e2,n2)}var t2=new Map;function n2(i,e){let t=xt[e];if(t===void 0){let n=t2.get(e);if(n!==void 0)t=xt[n],ct('WebGLRenderer: Shader chunk "%s" has been deprecated. Use "%s" instead.',e,n);else throw new Error("THREE.WebGLProgram: Can not resolve #include <"+e+">")}return q0(t)}var i2=/#pragma unroll_loop_start\s+for\s*\(\s*int\s+i\s*=\s*(\d+)\s*;\s*i\s*<\s*(\d+)\s*;\s*i\s*\+\+\s*\)\s*{([\s\S]+?)}\s+#pragma unroll_loop_end/g;function sf(i){return i.replace(i2,s2)}function s2(i,e,t,n){let s="";for(let r=parseInt(e);r<parseInt(t);r++)s+=n.replace(/\[\s*i\s*\]/g,"[ "+r+" ]").replace(/UNROLLED_LOOP_INDEX/g,r);return s}function rf(i){let e=`precision ${i.precision} float;
	precision ${i.precision} int;
	precision ${i.precision} sampler2D;
	precision ${i.precision} samplerCube;
	precision ${i.precision} sampler3D;
	precision ${i.precision} sampler2DArray;
	precision ${i.precision} sampler2DShadow;
	precision ${i.precision} samplerCubeShadow;
	precision ${i.precision} sampler2DArrayShadow;
	precision ${i.precision} isampler2D;
	precision ${i.precision} isampler3D;
	precision ${i.precision} isamplerCube;
	precision ${i.precision} isampler2DArray;
	precision ${i.precision} usampler2D;
	precision ${i.precision} usampler3D;
	precision ${i.precision} usamplerCube;
	precision ${i.precision} usampler2DArray;
	`;return i.precision==="highp"?e+=`
#define HIGH_PRECISION`:i.precision==="mediump"?e+=`
#define MEDIUM_PRECISION`:i.precision==="lowp"&&(e+=`
#define LOW_PRECISION`),e}var r2={[Ia]:"SHADOWMAP_TYPE_PCF",[_r]:"SHADOWMAP_TYPE_VSM"};function a2(i){return r2[i.shadowMapType]||"SHADOWMAP_TYPE_BASIC"}var o2={[is]:"ENVMAP_TYPE_CUBE",[Ss]:"ENVMAP_TYPE_CUBE",[Ba]:"ENVMAP_TYPE_CUBE_UV"};function l2(i){return i.envMap===!1?"ENVMAP_TYPE_CUBE":o2[i.envMapMode]||"ENVMAP_TYPE_CUBE"}var c2={[Ss]:"ENVMAP_MODE_REFRACTION"};function h2(i){return i.envMap===!1?"ENVMAP_MODE_REFLECTION":c2[i.envMapMode]||"ENVMAP_MODE_REFLECTION"}var u2={[M0]:"ENVMAP_BLENDING_MULTIPLY",[xu]:"ENVMAP_BLENDING_MIX",[vu]:"ENVMAP_BLENDING_ADD"};function f2(i){return i.envMap===!1?"ENVMAP_BLENDING_NONE":u2[i.combine]||"ENVMAP_BLENDING_NONE"}function d2(i){let e=i.envMapCubeUVHeight;if(e===null)return null;let t=Math.log2(e)-2,n=1/e;return{texelWidth:1/(3*Math.max(Math.pow(2,t),112)),texelHeight:n,maxMip:t}}function p2(i,e,t,n){let s=i.getContext(),r=t.defines,a=t.vertexShader,o=t.fragmentShader,l=a2(t),c=l2(t),h=h2(t),f=f2(t),u=d2(t),d=Kg(t),g=jg(r),x=s.createProgram(),m,p,S=t.glslVersion?"#version "+t.glslVersion+`
`:"";t.isRawShaderMaterial?(m=["#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,g].filter($a).join(`
`),m.length>0&&(m+=`
`),p=["#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,g].filter($a).join(`
`),p.length>0&&(p+=`
`)):(m=[rf(t),"#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,g,t.extensionClipCullDistance?"#define USE_CLIP_DISTANCE":"",t.batching?"#define USE_BATCHING":"",t.batchingColor?"#define USE_BATCHING_COLOR":"",t.instancing?"#define USE_INSTANCING":"",t.instancingColor?"#define USE_INSTANCING_COLOR":"",t.instancingMorph?"#define USE_INSTANCING_MORPH":"",t.useFog&&t.fog?"#define USE_FOG":"",t.useFog&&t.fogExp2?"#define FOG_EXP2":"",t.map?"#define USE_MAP":"",t.envMap?"#define USE_ENVMAP":"",t.envMap?"#define "+h:"",t.lightMap?"#define USE_LIGHTMAP":"",t.aoMap?"#define USE_AOMAP":"",t.bumpMap?"#define USE_BUMPMAP":"",t.normalMap?"#define USE_NORMALMAP":"",t.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",t.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",t.displacementMap?"#define USE_DISPLACEMENTMAP":"",t.emissiveMap?"#define USE_EMISSIVEMAP":"",t.anisotropy?"#define USE_ANISOTROPY":"",t.anisotropyMap?"#define USE_ANISOTROPYMAP":"",t.clearcoatMap?"#define USE_CLEARCOATMAP":"",t.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",t.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",t.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",t.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",t.specularMap?"#define USE_SPECULARMAP":"",t.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",t.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",t.roughnessMap?"#define USE_ROUGHNESSMAP":"",t.metalnessMap?"#define USE_METALNESSMAP":"",t.alphaMap?"#define USE_ALPHAMAP":"",t.alphaHash?"#define USE_ALPHAHASH":"",t.transmission?"#define USE_TRANSMISSION":"",t.transmissionMap?"#define USE_TRANSMISSIONMAP":"",t.thicknessMap?"#define USE_THICKNESSMAP":"",t.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",t.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",t.mapUv?"#define MAP_UV "+t.mapUv:"",t.alphaMapUv?"#define ALPHAMAP_UV "+t.alphaMapUv:"",t.lightMapUv?"#define LIGHTMAP_UV "+t.lightMapUv:"",t.aoMapUv?"#define AOMAP_UV "+t.aoMapUv:"",t.emissiveMapUv?"#define EMISSIVEMAP_UV "+t.emissiveMapUv:"",t.bumpMapUv?"#define BUMPMAP_UV "+t.bumpMapUv:"",t.normalMapUv?"#define NORMALMAP_UV "+t.normalMapUv:"",t.displacementMapUv?"#define DISPLACEMENTMAP_UV "+t.displacementMapUv:"",t.metalnessMapUv?"#define METALNESSMAP_UV "+t.metalnessMapUv:"",t.roughnessMapUv?"#define ROUGHNESSMAP_UV "+t.roughnessMapUv:"",t.anisotropyMapUv?"#define ANISOTROPYMAP_UV "+t.anisotropyMapUv:"",t.clearcoatMapUv?"#define CLEARCOATMAP_UV "+t.clearcoatMapUv:"",t.clearcoatNormalMapUv?"#define CLEARCOAT_NORMALMAP_UV "+t.clearcoatNormalMapUv:"",t.clearcoatRoughnessMapUv?"#define CLEARCOAT_ROUGHNESSMAP_UV "+t.clearcoatRoughnessMapUv:"",t.iridescenceMapUv?"#define IRIDESCENCEMAP_UV "+t.iridescenceMapUv:"",t.iridescenceThicknessMapUv?"#define IRIDESCENCE_THICKNESSMAP_UV "+t.iridescenceThicknessMapUv:"",t.sheenColorMapUv?"#define SHEEN_COLORMAP_UV "+t.sheenColorMapUv:"",t.sheenRoughnessMapUv?"#define SHEEN_ROUGHNESSMAP_UV "+t.sheenRoughnessMapUv:"",t.specularMapUv?"#define SPECULARMAP_UV "+t.specularMapUv:"",t.specularColorMapUv?"#define SPECULAR_COLORMAP_UV "+t.specularColorMapUv:"",t.specularIntensityMapUv?"#define SPECULAR_INTENSITYMAP_UV "+t.specularIntensityMapUv:"",t.transmissionMapUv?"#define TRANSMISSIONMAP_UV "+t.transmissionMapUv:"",t.thicknessMapUv?"#define THICKNESSMAP_UV "+t.thicknessMapUv:"",t.vertexTangents&&t.flatShading===!1?"#define USE_TANGENT":"",t.vertexNormals?"#define HAS_NORMAL":"",t.vertexColors?"#define USE_COLOR":"",t.vertexAlphas?"#define USE_COLOR_ALPHA":"",t.vertexUv1s?"#define USE_UV1":"",t.vertexUv2s?"#define USE_UV2":"",t.vertexUv3s?"#define USE_UV3":"",t.pointsUvs?"#define USE_POINTS_UV":"",t.flatShading?"#define FLAT_SHADED":"",t.skinning?"#define USE_SKINNING":"",t.morphTargets?"#define USE_MORPHTARGETS":"",t.morphNormals&&t.flatShading===!1?"#define USE_MORPHNORMALS":"",t.morphColors?"#define USE_MORPHCOLORS":"",t.morphTargetsCount>0?"#define MORPHTARGETS_TEXTURE_STRIDE "+t.morphTextureStride:"",t.morphTargetsCount>0?"#define MORPHTARGETS_COUNT "+t.morphTargetsCount:"",t.doubleSided?"#define DOUBLE_SIDED":"",t.flipSided?"#define FLIP_SIDED":"",t.shadowMapEnabled?"#define USE_SHADOWMAP":"",t.shadowMapEnabled?"#define "+l:"",t.sizeAttenuation?"#define USE_SIZEATTENUATION":"",t.numLightProbes>0?"#define USE_LIGHT_PROBES":"",t.logarithmicDepthBuffer?"#define USE_LOGARITHMIC_DEPTH_BUFFER":"",t.reversedDepthBuffer?"#define USE_REVERSED_DEPTH_BUFFER":"","uniform mat4 modelMatrix;","uniform mat4 modelViewMatrix;","uniform mat4 projectionMatrix;","uniform mat4 viewMatrix;","uniform mat3 normalMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;","#ifdef USE_INSTANCING","	attribute mat4 instanceMatrix;","#endif","#ifdef USE_INSTANCING_COLOR","	attribute vec3 instanceColor;","#endif","#ifdef USE_INSTANCING_MORPH","	uniform sampler2D morphTexture;","#endif","attribute vec3 position;","attribute vec3 normal;","attribute vec2 uv;","#ifdef USE_UV1","	attribute vec2 uv1;","#endif","#ifdef USE_UV2","	attribute vec2 uv2;","#endif","#ifdef USE_UV3","	attribute vec2 uv3;","#endif","#ifdef USE_TANGENT","	attribute vec4 tangent;","#endif","#if defined( USE_COLOR_ALPHA )","	attribute vec4 color;","#elif defined( USE_COLOR )","	attribute vec3 color;","#endif","#ifdef USE_SKINNING","	attribute vec4 skinIndex;","	attribute vec4 skinWeight;","#endif",`
`].filter($a).join(`
`),p=[rf(t),"#define SHADER_TYPE "+t.shaderType,"#define SHADER_NAME "+t.shaderName,g,t.useFog&&t.fog?"#define USE_FOG":"",t.useFog&&t.fogExp2?"#define FOG_EXP2":"",t.alphaToCoverage?"#define ALPHA_TO_COVERAGE":"",t.map?"#define USE_MAP":"",t.matcap?"#define USE_MATCAP":"",t.envMap?"#define USE_ENVMAP":"",t.envMap?"#define "+c:"",t.envMap?"#define "+h:"",t.envMap?"#define "+f:"",u?"#define CUBEUV_TEXEL_WIDTH "+u.texelWidth:"",u?"#define CUBEUV_TEXEL_HEIGHT "+u.texelHeight:"",u?"#define CUBEUV_MAX_MIP "+u.maxMip+".0":"",t.lightMap?"#define USE_LIGHTMAP":"",t.aoMap?"#define USE_AOMAP":"",t.bumpMap?"#define USE_BUMPMAP":"",t.normalMap?"#define USE_NORMALMAP":"",t.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",t.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",t.packedNormalMap?"#define USE_PACKED_NORMALMAP":"",t.emissiveMap?"#define USE_EMISSIVEMAP":"",t.anisotropy?"#define USE_ANISOTROPY":"",t.anisotropyMap?"#define USE_ANISOTROPYMAP":"",t.clearcoat?"#define USE_CLEARCOAT":"",t.clearcoatMap?"#define USE_CLEARCOATMAP":"",t.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",t.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",t.dispersion?"#define USE_DISPERSION":"",t.retroreflection?"#define USE_RETROREFLECTION":"",t.iridescence?"#define USE_IRIDESCENCE":"",t.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",t.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",t.specularMap?"#define USE_SPECULARMAP":"",t.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",t.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",t.roughnessMap?"#define USE_ROUGHNESSMAP":"",t.metalnessMap?"#define USE_METALNESSMAP":"",t.alphaMap?"#define USE_ALPHAMAP":"",t.alphaTest?"#define USE_ALPHATEST":"",t.alphaHash?"#define USE_ALPHAHASH":"",t.sheen?"#define USE_SHEEN":"",t.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",t.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",t.transmission?"#define USE_TRANSMISSION":"",t.transmissionMap?"#define USE_TRANSMISSIONMAP":"",t.thicknessMap?"#define USE_THICKNESSMAP":"",t.vertexTangents&&t.flatShading===!1?"#define USE_TANGENT":"",t.vertexColors||t.instancingColor?"#define USE_COLOR":"",t.vertexAlphas||t.batchingColor?"#define USE_COLOR_ALPHA":"",t.vertexUv1s?"#define USE_UV1":"",t.vertexUv2s?"#define USE_UV2":"",t.vertexUv3s?"#define USE_UV3":"",t.pointsUvs?"#define USE_POINTS_UV":"",t.gradientMap?"#define USE_GRADIENTMAP":"",t.flatShading?"#define FLAT_SHADED":"",t.doubleSided?"#define DOUBLE_SIDED":"",t.flipSided?"#define FLIP_SIDED":"",t.shadowMapEnabled?"#define USE_SHADOWMAP":"",t.shadowMapEnabled?"#define "+l:"",t.premultipliedAlpha?"#define PREMULTIPLIED_ALPHA":"",t.numLightProbes>0?"#define USE_LIGHT_PROBES":"",t.numLightProbeGrids>0?"#define USE_LIGHT_PROBES_GRID":"",t.decodeVideoTexture?"#define DECODE_VIDEO_TEXTURE":"",t.decodeVideoTextureEmissive?"#define DECODE_VIDEO_TEXTURE_EMISSIVE":"",t.logarithmicDepthBuffer?"#define USE_LOGARITHMIC_DEPTH_BUFFER":"",t.reversedDepthBuffer?"#define USE_REVERSED_DEPTH_BUFFER":"","uniform mat4 viewMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;",t.toneMapping!==Qn?"#define TONE_MAPPING":"",t.toneMapping!==Qn?xt.tonemapping_pars_fragment:"",t.toneMapping!==Qn?Zg("toneMapping",t.toneMapping):"",t.dithering?"#define DITHERING":"",t.opaque?"#define OPAQUE":"",xt.colorspace_pars_fragment,Yg("linearToOutputTexel",t.outputColorSpace),Jg(),t.useDepthPacking?"#define DEPTH_PACKING "+t.depthPacking:"",`
`].filter($a).join(`
`)),a=q0(a),a=tf(a,t),a=nf(a,t),o=q0(o),o=tf(o,t),o=nf(o,t),a=sf(a),o=sf(o),t.isRawShaderMaterial!==!0&&(S=`#version 300 es
`,m=[d,"#define attribute in","#define varying out","#define texture2D texture"].join(`
`)+`
`+m,p=["#define varying in",t.glslVersion===P0?"":"layout(location = 0) out highp vec4 pc_fragColor;",t.glslVersion===P0?"":"#define gl_FragColor pc_fragColor","#define gl_FragDepthEXT gl_FragDepth","#define texture2D texture","#define textureCube texture","#define texture2DProj textureProj","#define texture2DLodEXT textureLod","#define texture2DProjLodEXT textureProjLod","#define textureCubeLodEXT textureLod","#define texture2DGradEXT textureGrad","#define texture2DProjGradEXT textureProjGrad","#define textureCubeGradEXT textureGrad"].join(`
`)+`
`+p);let A=S+m+a,v=S+p+o,b=ju(s,s.VERTEX_SHADER,A),E=ju(s,s.FRAGMENT_SHADER,v);s.attachShader(x,b),s.attachShader(x,E),t.index0AttributeName!==void 0?s.bindAttribLocation(x,0,t.index0AttributeName):t.hasPositionAttribute===!0&&s.bindAttribLocation(x,0,"position"),s.linkProgram(x);function C(U){if(i.debug.checkShaderErrors){let B=s.getProgramInfoLog(x)||"",W=s.getShaderInfoLog(b)||"",F=s.getShaderInfoLog(E)||"",V=B.trim(),se=W.trim(),K=F.trim(),de=!0,te=!0;if(s.getProgramParameter(x,s.LINK_STATUS)===!1)if(de=!1,typeof i.debug.onShaderError=="function")i.debug.onShaderError(s,x,b,E);else{let ae=ef(s,b,"vertex"),O=ef(s,E,"fragment");lt("WebGLProgram: Shader Error "+s.getError()+" - VALIDATE_STATUS "+s.getProgramParameter(x,s.VALIDATE_STATUS)+`

Material Name: `+U.name+`
Material Type: `+U.type+`

Program Info Log: `+V+`
`+ae+`
`+O)}else V!==""?ct("WebGLProgram: Program Info Log:",V):(se===""||K==="")&&(te=!1);te&&(U.diagnostics={runnable:de,programLog:V,vertexShader:{log:se,prefix:m},fragmentShader:{log:K,prefix:p}})}s.deleteShader(b),s.deleteShader(E),y=new br(s,x),w=Qg(s,x)}let y;this.getUniforms=function(){return y===void 0&&C(this),y};let w;this.getAttributes=function(){return w===void 0&&C(this),w};let P=t.rendererExtensionParallelShaderCompile===!1;return this.isReady=function(){return P===!1&&(P=s.getProgramParameter(x,Gg)),P},this.destroy=function(){n.releaseStatesOfProgram(this),s.deleteProgram(x),this.program=void 0},this.type=t.shaderType,this.name=t.shaderName,this.id=Wg++,this.cacheKey=e,this.usedTimes=1,this.program=x,this.vertexShader=b,this.fragmentShader=E,this}var m2=0,Y0=class{constructor(){this.shaderCache=new Map,this.materialCache=new Map}update(e,t,n){let s=this._getShaderCacheForMaterial(e);return s.has(t)===!1&&(s.add(t),t.usedTimes++),s.has(n)===!1&&(s.add(n),n.usedTimes++),this}remove(e){let t=this.materialCache.get(e);for(let n of t)n.usedTimes--,n.usedTimes===0&&this.shaderCache.delete(n.code);return this.materialCache.delete(e),this}getVertexShaderStage(e){return this._getShaderStage(e.vertexShader)}getFragmentShaderStage(e){return this._getShaderStage(e.fragmentShader)}dispose(){this.shaderCache.clear(),this.materialCache.clear()}_getShaderCacheForMaterial(e){let t=this.materialCache,n=t.get(e);return n===void 0&&(n=new Set,t.set(e,n)),n}_getShaderStage(e){let t=this.shaderCache,n=t.get(e);return n===void 0&&(n=new $0(e),t.set(e,n)),n}},$0=class{constructor(e){this.id=m2++,this.code=e,this.usedTimes=0}};function g2(i){return i===rs||i===Wa||i===Xa}function _2(i,e,t,n,s,r){let a=new tr,o=new Y0,l=new Set,c=[],h=new Map,f=n.logarithmicDepthBuffer,u=n.precision,d={MeshDepthMaterial:"depth",MeshDistanceMaterial:"distance",MeshNormalMaterial:"normal",MeshBasicMaterial:"basic",MeshLambertMaterial:"lambert",MeshPhongMaterial:"phong",MeshToonMaterial:"toon",MeshStandardMaterial:"physical",MeshPhysicalMaterial:"physical",MeshMatcapMaterial:"matcap",LineBasicMaterial:"basic",LineDashedMaterial:"dashed",PointsMaterial:"points",ShadowMaterial:"shadow",SpriteMaterial:"sprite"};function g(y){return l.add(y),y===0?"uv":`uv${y}`}function x(y,w,P,U,B,W){let F=U.fog,V=B.geometry,se=y.isMeshStandardMaterial||y.isMeshLambertMaterial||y.isMeshPhongMaterial?U.environment:null,K=y.isMeshStandardMaterial||y.isMeshLambertMaterial&&!y.envMap||y.isMeshPhongMaterial&&!y.envMap,de=e.get(y.envMap||se,K),te=de&&de.mapping===Ba?de.image.height:null,ae=d[y.type];y.precision!==null&&(u=n.getMaxPrecision(y.precision),u!==y.precision&&ct("WebGLProgram.getParameters:",y.precision,"not supported, using",u,"instead."));let O=V.morphAttributes.position||V.morphAttributes.normal||V.morphAttributes.color,ye=O!==void 0?O.length:0,Se=0;V.morphAttributes.position!==void 0&&(Se=1),V.morphAttributes.normal!==void 0&&(Se=2),V.morphAttributes.color!==void 0&&(Se=3);let be,Ve,me,$;if(ae){let Bt=yi[ae];be=Bt.vertexShader,Ve=Bt.fragmentShader}else{be=y.vertexShader,Ve=y.fragmentShader;let Bt=o.getVertexShaderStage(y),vt=o.getFragmentShaderStage(y);o.update(y,Bt,vt),me=Bt.id,$=vt.id}let X=i.getRenderTarget(),he=i.state.buffers.depth.getReversed(),Te=B.isInstancedMesh===!0,le=B.isBatchedMesh===!0,Ie=!!y.map,st=!!y.matcap,Z=!!de,ce=!!y.aoMap,Me=!!y.lightMap,ge=!!y.bumpMap&&y.wireframe===!1,xe=!!y.normalMap,ke=!!y.displacementMap,Le=!!y.emissiveMap,Je=!!y.metalnessMap,tt=!!y.roughnessMap,L=y.anisotropy>0,Qe=y.clearcoat>0,at=y.dispersion>0,T=y.retroreflectivity>0,_=y.iridescence>0,H=y.sheen>0,G=y.transmission>0,ne=L&&!!y.anisotropyMap,ve=Qe&&!!y.clearcoatMap,Ae=Qe&&!!y.clearcoatNormalMap,ee=Qe&&!!y.clearcoatRoughnessMap,oe=_&&!!y.iridescenceMap,Re=_&&!!y.iridescenceThicknessMap,qe=H&&!!y.sheenColorMap,Pe=H&&!!y.sheenRoughnessMap,pe=!!y.specularMap,Ge=!!y.specularColorMap,et=!!y.specularIntensityMap,ht=G&&!!y.transmissionMap,D=G&&!!y.thicknessMap,Ce=!!y.gradientMap,re=!!y.alphaMap,we=y.alphaTest>0,Fe=!!y.alphaHash,_e=!!y.extensions,Ke=Qn;y.toneMapped&&(X===null||X.isXRRenderTarget===!0)&&(Ke=i.toneMapping);let Ye={shaderID:ae,shaderType:y.type,shaderName:y.name,vertexShader:be,fragmentShader:Ve,defines:y.defines,customVertexShaderID:me,customFragmentShaderID:$,isRawShaderMaterial:y.isRawShaderMaterial===!0,glslVersion:y.glslVersion,precision:u,batching:le,batchingColor:le&&B._colorsTexture!==null,instancing:Te,instancingColor:Te&&B.instanceColor!==null,instancingMorph:Te&&B.morphTexture!==null,outputColorSpace:X===null?i.outputColorSpace:X.isXRRenderTarget===!0?X.texture.colorSpace:St.workingColorSpace,alphaToCoverage:!!y.alphaToCoverage,map:Ie,matcap:st,envMap:Z,envMapMode:Z&&de.mapping,envMapCubeUVHeight:te,aoMap:ce,lightMap:Me,bumpMap:ge,normalMap:xe,displacementMap:ke,emissiveMap:Le,normalMapObjectSpace:xe&&y.normalMapType===Su,normalMapTangentSpace:xe&&y.normalMapType===rc,packedNormalMap:xe&&y.normalMapType===rc&&g2(y.normalMap.format),metalnessMap:Je,roughnessMap:tt,anisotropy:L,anisotropyMap:ne,clearcoat:Qe,clearcoatMap:ve,clearcoatNormalMap:Ae,clearcoatRoughnessMap:ee,dispersion:at,retroreflection:T,iridescence:_,iridescenceMap:oe,iridescenceThicknessMap:Re,sheen:H,sheenColorMap:qe,sheenRoughnessMap:Pe,specularMap:pe,specularColorMap:Ge,specularIntensityMap:et,transmission:G,transmissionMap:ht,thicknessMap:D,gradientMap:Ce,opaque:y.transparent===!1&&y.blending===ns&&y.alphaToCoverage===!1,alphaMap:re,alphaTest:we,alphaHash:Fe,combine:y.combine,mapUv:Ie&&g(y.map.channel),aoMapUv:ce&&g(y.aoMap.channel),lightMapUv:Me&&g(y.lightMap.channel),bumpMapUv:ge&&g(y.bumpMap.channel),normalMapUv:xe&&g(y.normalMap.channel),displacementMapUv:ke&&g(y.displacementMap.channel),emissiveMapUv:Le&&g(y.emissiveMap.channel),metalnessMapUv:Je&&g(y.metalnessMap.channel),roughnessMapUv:tt&&g(y.roughnessMap.channel),anisotropyMapUv:ne&&g(y.anisotropyMap.channel),clearcoatMapUv:ve&&g(y.clearcoatMap.channel),clearcoatNormalMapUv:Ae&&g(y.clearcoatNormalMap.channel),clearcoatRoughnessMapUv:ee&&g(y.clearcoatRoughnessMap.channel),iridescenceMapUv:oe&&g(y.iridescenceMap.channel),iridescenceThicknessMapUv:Re&&g(y.iridescenceThicknessMap.channel),sheenColorMapUv:qe&&g(y.sheenColorMap.channel),sheenRoughnessMapUv:Pe&&g(y.sheenRoughnessMap.channel),specularMapUv:pe&&g(y.specularMap.channel),specularColorMapUv:Ge&&g(y.specularColorMap.channel),specularIntensityMapUv:et&&g(y.specularIntensityMap.channel),transmissionMapUv:ht&&g(y.transmissionMap.channel),thicknessMapUv:D&&g(y.thicknessMap.channel),alphaMapUv:re&&g(y.alphaMap.channel),vertexTangents:!!V.attributes.tangent&&(xe||L),vertexNormals:!!V.attributes.normal,vertexColors:y.vertexColors,vertexAlphas:y.vertexColors===!0&&!!V.attributes.color&&V.attributes.color.itemSize===4,pointsUvs:B.isPoints===!0&&!!V.attributes.uv&&(Ie||re),fog:!!F,useFog:y.fog===!0,fogExp2:!!F&&F.isFogExp2,flatShading:y.wireframe===!1&&(y.flatShading===!0||V.attributes.normal===void 0&&xe===!1&&(y.isMeshLambertMaterial||y.isMeshPhongMaterial||y.isMeshStandardMaterial||y.isMeshPhysicalMaterial)),sizeAttenuation:y.sizeAttenuation===!0,logarithmicDepthBuffer:f,reversedDepthBuffer:he,skinning:B.isSkinnedMesh===!0,hasPositionAttribute:V.attributes.position!==void 0,morphTargets:V.morphAttributes.position!==void 0,morphNormals:V.morphAttributes.normal!==void 0,morphColors:V.morphAttributes.color!==void 0,morphTargetsCount:ye,morphTextureStride:Se,numSunLights:w.sun.length,numDirLights:w.directional.length,numPointLights:w.point.length,numSpotLights:w.spot.length,numSpotLightMaps:w.spotLightMap.length,numRectAreaLights:w.rectArea.length,numHemiLights:w.hemi.length,numSunLightShadows:w.sunShadowMap.length,numDirLightShadows:w.directionalShadowMap.length,numPointLightShadows:w.pointShadowMap.length,numSpotLightShadows:w.spotShadowMap.length,numSpotLightShadowsWithMaps:w.numSpotLightShadowsWithMaps,numLightProbes:w.numLightProbes,numLightProbeGrids:W.length,numClippingPlanes:r.numPlanes,numClipIntersection:r.numIntersection,dithering:y.dithering,shadowMapEnabled:i.shadowMap.enabled&&P.length>0,shadowMapType:i.shadowMap.type,toneMapping:Ke,decodeVideoTexture:Ie&&y.map.isVideoTexture===!0&&St.getTransfer(y.map.colorSpace)===Pt,decodeVideoTextureEmissive:Le&&y.emissiveMap.isVideoTexture===!0&&St.getTransfer(y.emissiveMap.colorSpace)===Pt,premultipliedAlpha:y.premultipliedAlpha,doubleSided:y.side===xn,flipSided:y.side===_n,useDepthPacking:y.depthPacking>=0,depthPacking:y.depthPacking||0,index0AttributeName:y.index0AttributeName,extensionClipCullDistance:_e&&y.extensions.clipCullDistance===!0&&t.has("WEBGL_clip_cull_distance"),extensionMultiDraw:(_e&&y.extensions.multiDraw===!0||le)&&t.has("WEBGL_multi_draw"),rendererExtensionParallelShaderCompile:t.has("KHR_parallel_shader_compile"),customProgramCacheKey:y.customProgramCacheKey()};return Ye.vertexUv1s=l.has(1),Ye.vertexUv2s=l.has(2),Ye.vertexUv3s=l.has(3),l.clear(),Ye}function m(y){let w=[];if(y.shaderID?w.push(y.shaderID):(w.push(y.customVertexShaderID),w.push(y.customFragmentShaderID)),y.defines!==void 0)for(let P in y.defines)w.push(P),w.push(y.defines[P]);return y.isRawShaderMaterial===!1&&(p(w,y),S(w,y),w.push(i.outputColorSpace)),w.push(y.customProgramCacheKey),w.join()}function p(y,w){y.push(w.precision),y.push(w.outputColorSpace),y.push(w.envMapMode),y.push(w.envMapCubeUVHeight),y.push(w.mapUv),y.push(w.alphaMapUv),y.push(w.lightMapUv),y.push(w.aoMapUv),y.push(w.bumpMapUv),y.push(w.normalMapUv),y.push(w.displacementMapUv),y.push(w.emissiveMapUv),y.push(w.metalnessMapUv),y.push(w.roughnessMapUv),y.push(w.anisotropyMapUv),y.push(w.clearcoatMapUv),y.push(w.clearcoatNormalMapUv),y.push(w.clearcoatRoughnessMapUv),y.push(w.iridescenceMapUv),y.push(w.iridescenceThicknessMapUv),y.push(w.sheenColorMapUv),y.push(w.sheenRoughnessMapUv),y.push(w.specularMapUv),y.push(w.specularColorMapUv),y.push(w.specularIntensityMapUv),y.push(w.transmissionMapUv),y.push(w.thicknessMapUv),y.push(w.combine),y.push(w.fogExp2),y.push(w.sizeAttenuation),y.push(w.morphTargetsCount),y.push(w.morphAttributeCount),y.push(w.numSunLights),y.push(w.numDirLights),y.push(w.numPointLights),y.push(w.numSpotLights),y.push(w.numSpotLightMaps),y.push(w.numHemiLights),y.push(w.numRectAreaLights),y.push(w.numSunLightShadows),y.push(w.numDirLightShadows),y.push(w.numPointLightShadows),y.push(w.numSpotLightShadows),y.push(w.numSpotLightShadowsWithMaps),y.push(w.numLightProbes),y.push(w.shadowMapType),y.push(w.toneMapping),y.push(w.numClippingPlanes),y.push(w.numClipIntersection),y.push(w.depthPacking)}function S(y,w){a.disableAll(),w.instancing&&a.enable(0),w.instancingColor&&a.enable(1),w.instancingMorph&&a.enable(2),w.matcap&&a.enable(3),w.envMap&&a.enable(4),w.normalMapObjectSpace&&a.enable(5),w.normalMapTangentSpace&&a.enable(6),w.clearcoat&&a.enable(7),w.iridescence&&a.enable(8),w.alphaTest&&a.enable(9),w.vertexColors&&a.enable(10),w.vertexAlphas&&a.enable(11),w.vertexUv1s&&a.enable(12),w.vertexUv2s&&a.enable(13),w.vertexUv3s&&a.enable(14),w.vertexTangents&&a.enable(15),w.anisotropy&&a.enable(16),w.alphaHash&&a.enable(17),w.batching&&a.enable(18),w.dispersion&&a.enable(19),w.retroreflection&&a.enable(24),w.batchingColor&&a.enable(20),w.gradientMap&&a.enable(21),w.packedNormalMap&&a.enable(22),w.vertexNormals&&a.enable(23),y.push(a.mask),a.disableAll(),w.fog&&a.enable(0),w.useFog&&a.enable(1),w.flatShading&&a.enable(2),w.logarithmicDepthBuffer&&a.enable(3),w.reversedDepthBuffer&&a.enable(4),w.skinning&&a.enable(5),w.morphTargets&&a.enable(6),w.morphNormals&&a.enable(7),w.morphColors&&a.enable(8),w.premultipliedAlpha&&a.enable(9),w.shadowMapEnabled&&a.enable(10),w.doubleSided&&a.enable(11),w.flipSided&&a.enable(12),w.useDepthPacking&&a.enable(13),w.dithering&&a.enable(14),w.transmission&&a.enable(15),w.sheen&&a.enable(16),w.opaque&&a.enable(17),w.pointsUvs&&a.enable(18),w.decodeVideoTexture&&a.enable(19),w.decodeVideoTextureEmissive&&a.enable(20),w.alphaToCoverage&&a.enable(21),w.numLightProbeGrids>0&&a.enable(22),w.hasPositionAttribute&&a.enable(23),y.push(a.mask)}function A(y){let w=d[y.type],P;if(w){let U=yi[w];P=Hi.clone(U.uniforms)}else P=y.uniforms;return P}function v(y,w){let P=h.get(w);return P!==void 0?++P.usedTimes:(P=new p2(i,w,y,s),c.push(P),h.set(w,P)),P}function b(y){if(--y.usedTimes===0){let w=c.indexOf(y);c[w]=c[c.length-1],c.pop(),h.delete(y.cacheKey),y.destroy()}}function E(y){o.remove(y)}function C(){o.dispose()}return{getParameters:x,getProgramCacheKey:m,getUniforms:A,acquireProgram:v,releaseProgram:b,releaseShaderCache:E,programs:c,dispose:C}}function x2(){let i=new WeakMap;function e(a){return i.has(a)}function t(a){let o=i.get(a);return o===void 0&&(o={},i.set(a,o)),o}function n(a){i.delete(a)}function s(a,o,l){i.get(a)[o]=l}function r(){i=new WeakMap}return{has:e,get:t,remove:n,update:s,dispose:r}}function v2(i,e){return i.groupOrder!==e.groupOrder?i.groupOrder-e.groupOrder:i.renderOrder!==e.renderOrder?i.renderOrder-e.renderOrder:i.material.id!==e.material.id?i.material.id-e.material.id:i.materialVariant!==e.materialVariant?i.materialVariant-e.materialVariant:i.z!==e.z?i.z-e.z:i.id-e.id}function af(i,e){return i.groupOrder!==e.groupOrder?i.groupOrder-e.groupOrder:i.renderOrder!==e.renderOrder?i.renderOrder-e.renderOrder:i.z!==e.z?e.z-i.z:i.id-e.id}function of(){let i=[],e=0,t=[],n=[],s=[];function r(){e=0,t.length=0,n.length=0,s.length=0}function a(u){let d=0;return u.isInstancedMesh&&(d+=2),u.isSkinnedMesh&&(d+=1),d}function o(u,d,g,x,m,p){let S=i[e];return S===void 0?(S={id:u.id,object:u,geometry:d,material:g,materialVariant:a(u),groupOrder:x,renderOrder:u.renderOrder,z:m,group:p},i[e]=S):(S.id=u.id,S.object=u,S.geometry=d,S.material=g,S.materialVariant=a(u),S.groupOrder=x,S.renderOrder=u.renderOrder,S.z=m,S.group=p),e++,S}function l(u,d,g,x,m,p,S){S.reversedDepth===!0&&(m=-m);let A=o(u,d,g,x,m,p);g.transmission>0?n.push(A):g.transparent===!0?s.push(A):t.push(A)}function c(u,d,g,x,m,p){let S=o(u,d,g,x,m,p);g.transmission>0?n.unshift(S):g.transparent===!0?s.unshift(S):t.unshift(S)}function h(u,d){t.length>1&&t.sort(u||v2),n.length>1&&n.sort(d||af),s.length>1&&s.sort(d||af)}function f(){for(let u=e,d=i.length;u<d;u++){let g=i[u];if(g.id===null)break;g.id=null,g.object=null,g.geometry=null,g.material=null,g.group=null}}return{opaque:t,transmissive:n,transparent:s,init:r,push:l,unshift:c,finish:f,sort:h}}function y2(){let i=new WeakMap;function e(n,s){let r=i.get(n),a;return r===void 0?(a=new of,i.set(n,[a])):s>=r.length?(a=new of,r.push(a)):a=r[s],a}function t(){i=new WeakMap}return{get:e,dispose:t}}function M2(){let i={};return{get:function(e){if(i[e.id]!==void 0)return i[e.id];let t;switch(e.type){case"SunLight":case"DirectionalLight":t={direction:new I,color:new it};break;case"SpotLight":t={position:new I,direction:new I,color:new it,distance:0,coneCos:0,penumbraCos:0,decay:0};break;case"PointLight":t={position:new I,color:new it,distance:0,decay:0};break;case"HemisphereLight":t={direction:new I,skyColor:new it,groundColor:new it};break;case"RectAreaLight":t={color:new it,position:new I,halfWidth:new I,halfHeight:new I};break}return i[e.id]=t,t}}}function S2(){let i={};return{get:function(e){if(i[e.id]!==void 0)return i[e.id];let t;switch(e.type){case"SunLight":case"DirectionalLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new ue};break;case"SpotLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new ue};break;case"PointLight":t={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new ue,shadowCameraNear:1,shadowCameraFar:1e3};break}return i[e.id]=t,t}}}var b2=0;function E2(i,e){return(e.castShadow?2:0)-(i.castShadow?2:0)+(e.map?1:0)-(i.map?1:0)}function T2(i){let e=new M2,t=S2(),n={version:0,hash:{sunLength:-1,directionalLength:-1,pointLength:-1,spotLength:-1,rectAreaLength:-1,hemiLength:-1,numSunShadows:-1,numDirectionalShadows:-1,numPointShadows:-1,numSpotShadows:-1,numSpotMaps:-1,numLightProbes:-1},ambient:[0,0,0],probe:[],sun:[],sunShadow:[],sunShadowMap:[],sunShadowMatrix:[],sunShadowCascade:[],directional:[],directionalShadow:[],directionalShadowMap:[],directionalShadowMatrix:[],spot:[],spotLightMap:[],spotShadow:[],spotShadowMap:[],spotLightMatrix:[],rectArea:[],rectAreaLTC1:null,rectAreaLTC2:null,point:[],pointShadow:[],pointShadowMap:[],pointShadowMatrix:[],hemi:[],numSpotLightShadowsWithMaps:0,numLightProbes:0};for(let c=0;c<9;c++)n.probe.push(new I);let s=new I,r=new Rt,a=new Rt;function o(c){let h=0,f=0,u=0;for(let B=0;B<9;B++)n.probe[B].set(0,0,0);let d=0,g=0,x=0,m=0,p=0,S=0,A=0,v=0,b=0,E=0,C=0,y=0,w=0,P=0;c.sort(E2);for(let B=0,W=c.length;B<W;B++){let F=c[B],V=F.color,se=F.intensity,K=F.distance,de=null;if(F.shadow&&F.shadow.map&&(F.shadow.map.texture.format===rs?de=F.shadow.map.texture:de=F.shadow.map.depthTexture||F.shadow.map.texture),F.isAmbientLight)h+=V.r*se,f+=V.g*se,u+=V.b*se;else if(F.isLightProbe){for(let te=0;te<9;te++)n.probe[te].addScaledVector(F.sh.coefficients[te],se);P++}else if(F.isSunLight){let te=e.get(F);if(te.color.copy(F.color).multiplyScalar(F.intensity),F.castShadow){let ae=F.shadow,O=t.get(F);O.shadowIntensity=ae.intensity,O.shadowBias=ae.bias,O.shadowNormalBias=ae.normalBias,O.shadowRadius=ae.radius,O.shadowMapSize.copy(ae.mapSize).multiply(ae.getFrameExtents()),n.sunShadow[g]=O,n.sunShadowMap[g]=de;let ye=ae.getViewportCount();for(let Se=0;Se<ye;Se++)n.sunShadowMatrix[x+Se]=ae.getMatrix(Se),n.sunShadowCascade[x+Se]=ae._cascadeData[Se];x+=ye,g++}n.sun[d]=te,d++}else if(F.isDirectionalLight){let te=e.get(F);if(te.color.copy(F.color).multiplyScalar(F.intensity),F.castShadow){let ae=F.shadow,O=t.get(F);O.shadowIntensity=ae.intensity,O.shadowBias=ae.bias,O.shadowNormalBias=ae.normalBias,O.shadowRadius=ae.radius,O.shadowMapSize=ae.mapSize,n.directionalShadow[m]=O,n.directionalShadowMap[m]=de,n.directionalShadowMatrix[m]=F.shadow.matrix,b++}n.directional[m]=te,m++}else if(F.isSpotLight){let te=e.get(F);te.position.setFromMatrixPosition(F.matrixWorld),te.color.copy(V).multiplyScalar(se),te.distance=K,te.coneCos=Math.cos(F.angle),te.penumbraCos=Math.cos(F.angle*(1-F.penumbra)),te.decay=F.decay,n.spot[S]=te;let ae=F.shadow;if(F.map&&(n.spotLightMap[y]=F.map,y++,ae.updateMatrices(F),F.castShadow&&w++),n.spotLightMatrix[S]=ae.matrix,F.castShadow){let O=t.get(F);O.shadowIntensity=ae.intensity,O.shadowBias=ae.bias,O.shadowNormalBias=ae.normalBias,O.shadowRadius=ae.radius,O.shadowMapSize=ae.mapSize,n.spotShadow[S]=O,n.spotShadowMap[S]=de,C++}S++}else if(F.isRectAreaLight){let te=e.get(F);te.color.copy(V).multiplyScalar(se),te.halfWidth.set(F.width*.5,0,0),te.halfHeight.set(0,F.height*.5,0),n.rectArea[A]=te,A++}else if(F.isPointLight){let te=e.get(F);if(te.color.copy(F.color).multiplyScalar(F.intensity),te.distance=F.distance,te.decay=F.decay,F.castShadow){let ae=F.shadow,O=t.get(F);O.shadowIntensity=ae.intensity,O.shadowBias=ae.bias,O.shadowNormalBias=ae.normalBias,O.shadowRadius=ae.radius,O.shadowMapSize=ae.mapSize,O.shadowCameraNear=ae.camera.near,O.shadowCameraFar=ae.camera.far,n.pointShadow[p]=O,n.pointShadowMap[p]=de,n.pointShadowMatrix[p]=F.shadow.matrix,E++}n.point[p]=te,p++}else if(F.isHemisphereLight){let te=e.get(F);te.skyColor.copy(F.color).multiplyScalar(se),te.groundColor.copy(F.groundColor).multiplyScalar(se),n.hemi[v]=te,v++}}A>0&&(i.has("OES_texture_float_linear")===!0?(n.rectAreaLTC1=Be.LTC_FLOAT_1,n.rectAreaLTC2=Be.LTC_FLOAT_2):(n.rectAreaLTC1=Be.LTC_HALF_1,n.rectAreaLTC2=Be.LTC_HALF_2)),n.ambient[0]=h,n.ambient[1]=f,n.ambient[2]=u;let U=n.hash;(U.sunLength!==d||U.directionalLength!==m||U.pointLength!==p||U.spotLength!==S||U.rectAreaLength!==A||U.hemiLength!==v||U.numSunShadows!==g||U.numDirectionalShadows!==b||U.numPointShadows!==E||U.numSpotShadows!==C||U.numSpotMaps!==y||U.numLightProbes!==P)&&(n.sun.length=d,n.directional.length=m,n.spot.length=S,n.rectArea.length=A,n.point.length=p,n.hemi.length=v,n.sunShadow.length=g,n.sunShadowMap.length=g,n.sunShadowMatrix.length=x,n.sunShadowCascade.length=x,n.directionalShadow.length=b,n.directionalShadowMap.length=b,n.directionalShadowMatrix.length=b,n.pointShadow.length=E,n.pointShadowMap.length=E,n.pointShadowMatrix.length=E,n.spotShadow.length=C,n.spotShadowMap.length=C,n.spotLightMatrix.length=C+y-w,n.spotLightMap.length=y,n.numSpotLightShadowsWithMaps=w,n.numLightProbes=P,U.sunLength=d,U.directionalLength=m,U.pointLength=p,U.spotLength=S,U.rectAreaLength=A,U.hemiLength=v,U.numSunShadows=g,U.numDirectionalShadows=b,U.numPointShadows=E,U.numSpotShadows=C,U.numSpotMaps=y,U.numLightProbes=P,n.version=b2++)}function l(c,h){let f=0,u=0,d=0,g=0,x=0,m=0,p=h.matrixWorldInverse;for(let S=0,A=c.length;S<A;S++){let v=c[S];if(v.isSunLight){let b=n.sun[f];b.direction.setFromMatrixPosition(v.matrixWorld),b.direction.transformDirection(p),f++}else if(v.isDirectionalLight){let b=n.directional[u];b.direction.setFromMatrixPosition(v.matrixWorld),s.setFromMatrixPosition(v.target.matrixWorld),b.direction.sub(s),b.direction.transformDirection(p),u++}else if(v.isSpotLight){let b=n.spot[g];b.position.setFromMatrixPosition(v.matrixWorld),b.position.applyMatrix4(p),b.direction.setFromMatrixPosition(v.matrixWorld),s.setFromMatrixPosition(v.target.matrixWorld),b.direction.sub(s),b.direction.transformDirection(p),g++}else if(v.isRectAreaLight){let b=n.rectArea[x];b.position.setFromMatrixPosition(v.matrixWorld),b.position.applyMatrix4(p),a.identity(),r.copy(v.matrixWorld),r.premultiply(p),a.extractRotation(r),b.halfWidth.set(v.width*.5,0,0),b.halfHeight.set(0,v.height*.5,0),b.halfWidth.applyMatrix4(a),b.halfHeight.applyMatrix4(a),x++}else if(v.isPointLight){let b=n.point[d];b.position.setFromMatrixPosition(v.matrixWorld),b.position.applyMatrix4(p),d++}else if(v.isHemisphereLight){let b=n.hemi[m];b.direction.setFromMatrixPosition(v.matrixWorld),b.direction.transformDirection(p),m++}}}return{setup:o,setupView:l,state:n}}function lf(i){let e=new T2(i),t=[],n=[],s=[];function r(u){f.camera=u,t.length=0,n.length=0,s.length=0}function a(u){t.push(u)}function o(u){n.push(u)}function l(u){s.push(u)}function c(){e.setup(t)}function h(u){e.setupView(t,u)}let f={lightsArray:t,shadowsArray:n,lightProbeGridArray:s,camera:null,lights:e,transmissionRenderTarget:{},textureUnits:0};return{init:r,state:f,setupLights:c,setupLightsView:h,pushLight:a,pushShadow:o,pushLightProbeGrid:l}}function w2(i){let e=new WeakMap;function t(s,r=0){let a=e.get(s),o;return a===void 0?(o=new lf(i),e.set(s,[o])):r>=a.length?(o=new lf(i),a.push(o)):o=a[r],o}function n(){e=new WeakMap}return{get:t,dispose:n}}var A2=`void main() {
	gl_Position = vec4( position, 1.0 );
}`,R2=`uniform sampler2D shadow_pass;
uniform vec2 resolution;
uniform float radius;
void main() {
	const float samples = float( VSM_SAMPLES );
	float mean = 0.0;
	float squared_mean = 0.0;
	float uvStride = samples <= 1.0 ? 0.0 : 2.0 / ( samples - 1.0 );
	float uvStart = samples <= 1.0 ? 0.0 : - 1.0;
	for ( float i = 0.0; i < samples; i ++ ) {
		float uvOffset = uvStart + i * uvStride;
		#ifdef HORIZONTAL_PASS
			vec2 distribution = texture2D( shadow_pass, ( gl_FragCoord.xy + vec2( uvOffset, 0.0 ) * radius ) / resolution ).rg;
			mean += distribution.x;
			squared_mean += distribution.y * distribution.y + distribution.x * distribution.x;
		#else
			float depth = texture2D( shadow_pass, ( gl_FragCoord.xy + vec2( 0.0, uvOffset ) * radius ) / resolution ).r;
			mean += depth;
			squared_mean += depth * depth;
		#endif
	}
	mean = mean / samples;
	squared_mean = squared_mean / samples;
	float std_dev = sqrt( max( 0.0, squared_mean - mean * mean ) );
	gl_FragColor = vec4( mean, std_dev, 0.0, 1.0 );
}`,C2=[new I(1,0,0),new I(-1,0,0),new I(0,1,0),new I(0,-1,0),new I(0,0,1),new I(0,0,-1)],P2=[new I(0,-1,0),new I(0,-1,0),new I(0,0,1),new I(0,0,-1),new I(0,-1,0),new I(0,-1,0)],cf=new Rt,Ya=new I,k0=new I;function I2(i,e,t){let n=new rr,s=new ue,r=new ue,a=new Gt,o=new al,l=new ol,c={},h=t.maxTextureSize,f={[ts]:_n,[_n]:ts,[xn]:xn},u=new Ft({defines:{VSM_SAMPLES:8},uniforms:{shadow_pass:{value:null},resolution:{value:new ue},radius:{value:4}},vertexShader:A2,fragmentShader:R2}),d=u.clone();d.defines.HORIZONTAL_PASS=1;let g=new wt;g.setAttribute("position",new jt(new Float32Array([-1,-1,.5,3,-1,.5,-1,3,.5]),3));let x=new gt(g,u),m=this;this.enabled=!1,this.autoUpdate=!0,this.needsUpdate=!1,this.type=Ia;let p=this.type;this.render=function(E,C,y){if(m.enabled===!1||m.autoUpdate===!1&&m.needsUpdate===!1||E.length===0)return;this.type===Qh&&(ct("WebGLShadowMap: PCFSoftShadowMap has been removed. Using PCFShadowMap instead."),this.type=Ia);let w=i.getRenderTarget(),P=i.getActiveCubeFace(),U=i.getActiveMipmapLevel(),B=i.state;B.setBlending(Hn),B.buffers.depth.getReversed()===!0?B.buffers.color.setClear(0,0,0,0):B.buffers.color.setClear(1,1,1,1),B.buffers.depth.setTest(!0),B.setScissorTest(!1);let W=p!==this.type;W&&C.traverse(function(F){F.material&&(Array.isArray(F.material)?F.material.forEach(V=>V.needsUpdate=!0):F.material.needsUpdate=!0)});for(let F=0,V=E.length;F<V;F++){let se=E[F],K=se.shadow;if(K===void 0){ct("WebGLShadowMap:",se,"has no shadow.");continue}if(K.autoUpdate===!1&&K.needsUpdate===!1)continue;s.copy(K.mapSize);let de=K.getFrameExtents();s.multiply(de),r.copy(K.mapSize),(s.x>h||s.y>h)&&(s.x>h&&(r.x=Math.floor(h/de.x),s.x=r.x*de.x,K.mapSize.x=r.x),s.y>h&&(r.y=Math.floor(h/de.y),s.y=r.y*de.y,K.mapSize.y=r.y));let te=i.state.buffers.depth.getReversed();if(K.camera._reversedDepth=te,K.map===null||W===!0){if(K.map!==null&&(K.map.depthTexture!==null&&(K.map.depthTexture.dispose(),K.map.depthTexture=null),K.map.dispose()),this.type===_r){if(se.isPointLight){ct("WebGLShadowMap: VSM shadow maps are not supported for PointLights. Use PCF or BasicShadowMap instead.");continue}K.map=new $t(s.x,s.y,{format:rs,type:sn,minFilter:gn,magFilter:gn,generateMipmaps:!1}),K.map.texture.name=se.name+".shadowMap",K.map.depthTexture=new Zi(s.x,s.y,kn),K.map.depthTexture.name=se.name+".shadowMapDepth",K.map.depthTexture.format=di,K.map.depthTexture.compareFunction=null,K.map.depthTexture.minFilter=un,K.map.depthTexture.magFilter=un}else se.isPointLight?(K.map=new uc(s.x),K.map.depthTexture=new tl(s.x,ei)):(K.map=new $t(s.x,s.y),K.map.depthTexture=new Zi(s.x,s.y,ei)),K.map.depthTexture.name=se.name+".shadowMap",K.map.depthTexture.format=di,this.type===Ia?(K.map.depthTexture.compareFunction=te?oc:ac,K.map.depthTexture.minFilter=gn,K.map.depthTexture.magFilter=gn):(K.map.depthTexture.compareFunction=null,K.map.depthTexture.minFilter=un,K.map.depthTexture.magFilter=un);K.camera.updateProjectionMatrix()}K.map.isWebGLCubeRenderTarget!==!0&&(K.map.width!==s.x||K.map.height!==s.y)&&K.map.setSize(s.x,s.y);let ae=K.map.isWebGLCubeRenderTarget?6:K.getViewportCount();se.isPointLight!==!0&&K.updateMatrices(se,y);for(let O=0;O<ae;O++){let ye=K.getCamera(O);if(se.isPointLight){let Se=K.camera,be=K.matrix,Ve=se.distance||Se.far;Ve!==Se.far&&(Se.far=Ve,Se.updateProjectionMatrix()),Ya.setFromMatrixPosition(se.matrixWorld),Se.position.copy(Ya),k0.copy(Se.position),k0.add(C2[O]),Se.up.copy(P2[O]),Se.lookAt(k0),Se.updateMatrixWorld(),be.makeTranslation(-Ya.x,-Ya.y,-Ya.z),cf.multiplyMatrices(Se.projectionMatrix,Se.matrixWorldInverse),K._frustum.setFromProjectionMatrix(cf,Se.coordinateSystem,Se.reversedDepth)}if(K.map.isWebGLCubeRenderTarget)i.setRenderTarget(K.map,O),i.clear();else{O===0&&(i.setRenderTarget(K.map),i.clear());let Se=K.getViewport(O);a.set(r.x*Se.x,r.y*Se.y,r.x*Se.z,r.y*Se.w),B.viewport(a)}n=K.getFrustum(O),v(C,y,ye,se,this.type)}K.isPointLightShadow!==!0&&this.type===_r&&S(K,y),K.needsUpdate=!1}p=this.type,m.needsUpdate=!1,i.setRenderTarget(w,P,U)};function S(E,C){let y=e.update(x);u.defines.VSM_SAMPLES!==E.blurSamples&&(u.defines.VSM_SAMPLES=E.blurSamples,d.defines.VSM_SAMPLES=E.blurSamples,u.needsUpdate=!0,d.needsUpdate=!0),E.mapPass===null?E.mapPass=new $t(s.x,s.y,{format:rs,type:sn}):(E.mapPass.width!==E.map.width||E.mapPass.height!==E.map.height)&&E.mapPass.setSize(E.map.width,E.map.height),u.uniforms.shadow_pass.value=E.map.depthTexture,u.uniforms.resolution.value.set(E.map.width,E.map.height),u.uniforms.radius.value=E.radius,i.setRenderTarget(E.mapPass),i.clear(),i.renderBufferDirect(C,null,y,u,x,null),d.uniforms.shadow_pass.value=E.mapPass.texture,d.uniforms.resolution.value.set(E.map.width,E.map.height),d.uniforms.radius.value=E.radius,i.setRenderTarget(E.map),i.clear(),i.renderBufferDirect(C,null,y,d,x,null)}function A(E,C,y,w){let P=null,U=y.isPointLight===!0?E.customDistanceMaterial:E.customDepthMaterial;if(U!==void 0)P=U;else if(P=y.isPointLight===!0?l:o,i.localClippingEnabled&&C.clipShadows===!0&&Array.isArray(C.clippingPlanes)&&C.clippingPlanes.length!==0||C.displacementMap&&C.displacementScale!==0||C.alphaMap&&C.alphaTest>0||C.map&&C.alphaTest>0||C.alphaToCoverage===!0){let B=P.uuid,W=C.uuid,F=c[B];F===void 0&&(F={},c[B]=F);let V=F[W];V===void 0&&(V=P.clone(),F[W]=V,C.addEventListener("dispose",b)),P=V}if(P.visible=C.visible,P.wireframe=C.wireframe,w===_r?P.side=C.shadowSide!==null?C.shadowSide:C.side:P.side=C.shadowSide!==null?C.shadowSide:f[C.side],P.alphaMap=C.alphaMap,P.alphaTest=C.alphaToCoverage===!0?.5:C.alphaTest,P.map=C.map,P.clipShadows=C.clipShadows,P.clippingPlanes=C.clippingPlanes,P.clipIntersection=C.clipIntersection,P.displacementMap=C.displacementMap,P.displacementScale=C.displacementScale,P.displacementBias=C.displacementBias,P.wireframeLinewidth=C.wireframeLinewidth,P.linewidth=C.linewidth,y.isPointLight===!0&&P.isMeshDistanceMaterial===!0){let B=i.properties.get(P);B.light=y}return P}function v(E,C,y,w,P){if(E.visible===!1)return;if(E.layers.test(C.layers)&&(E.isMesh||E.isLine||E.isPoints)&&(E.castShadow||E.receiveShadow&&P===_r)&&(!E.frustumCulled||E.intersectsFrustum(n))){E.modelViewMatrix.multiplyMatrices(y.matrixWorldInverse,E.matrixWorld);let W=e.update(E),F=E.material;if(Array.isArray(F)){let V=W.groups;for(let se=0,K=V.length;se<K;se++){let de=V[se],te=F[de.materialIndex];if(te&&te.visible){let ae=A(E,te,w,P);E.onBeforeShadow(i,E,C,y,W,ae,de),i.renderBufferDirect(y,null,W,ae,E,de),E.onAfterShadow(i,E,C,y,W,ae,de)}}}else if(F.visible){let V=A(E,F,w,P);E.onBeforeShadow(i,E,C,y,W,V,null),i.renderBufferDirect(y,null,W,V,E,null),E.onAfterShadow(i,E,C,y,W,V,null)}}let B=E.children;for(let W=0,F=B.length;W<F;W++)v(B[W],C,y,w,P)}function b(E){E.target.removeEventListener("dispose",b);for(let y in c){let w=c[y],P=E.target.uuid;P in w&&(w[P].dispose(),delete w[P])}}}function L2(i,e){function t(){let D=!1,Ce=new Gt,re=null,we=new Gt(0,0,0,0);return{setMask:function(Fe){re!==Fe&&!D&&(i.colorMask(Fe,Fe,Fe,Fe),re=Fe)},setLocked:function(Fe){D=Fe},setClear:function(Fe,_e,Ke,Ye,Bt){Bt===!0&&(Fe*=Ye,_e*=Ye,Ke*=Ye),Ce.set(Fe,_e,Ke,Ye),we.equals(Ce)===!1&&(i.clearColor(Fe,_e,Ke,Ye),we.copy(Ce))},reset:function(){D=!1,re=null,we.set(-1,0,0,0)}}}function n(){let D=!1,Ce=!1,re=null,we=null,Fe=null;return{setReversed:function(_e){if(Ce!==_e){let Ke=e.get("EXT_clip_control");_e?Ke.clipControlEXT(Ke.LOWER_LEFT_EXT,Ke.ZERO_TO_ONE_EXT):Ke.clipControlEXT(Ke.LOWER_LEFT_EXT,Ke.NEGATIVE_ONE_TO_ONE_EXT),Ce=_e;let Ye=Fe;Fe=null,this.setClear(Ye)}},getReversed:function(){return Ce},setTest:function(_e){_e?X(i.DEPTH_TEST):he(i.DEPTH_TEST)},setMask:function(_e){re!==_e&&!D&&(i.depthMask(_e),re=_e)},setFunc:function(_e){if(Ce&&(_e=Du[_e]),we!==_e){switch(_e){case zo:i.depthFunc(i.NEVER);break;case Ho:i.depthFunc(i.ALWAYS);break;case ko:i.depthFunc(i.LESS);break;case Js:i.depthFunc(i.LEQUAL);break;case Vo:i.depthFunc(i.EQUAL);break;case Go:i.depthFunc(i.GEQUAL);break;case Wo:i.depthFunc(i.GREATER);break;case Xo:i.depthFunc(i.NOTEQUAL);break;default:i.depthFunc(i.LEQUAL)}we=_e}},setLocked:function(_e){D=_e},setClear:function(_e){Fe!==_e&&(Fe=_e,Ce&&(_e=1-_e),i.clearDepth(_e))},reset:function(){D=!1,re=null,we=null,Fe=null,Ce=!1}}}function s(){let D=!1,Ce=null,re=null,we=null,Fe=null,_e=null,Ke=null,Ye=null,Bt=null;return{setTest:function(vt){D||(vt?X(i.STENCIL_TEST):he(i.STENCIL_TEST))},setMask:function(vt){Ce!==vt&&!D&&(i.stencilMask(vt),Ce=vt)},setFunc:function(vt,Sn,ot){(re!==vt||we!==Sn||Fe!==ot)&&(i.stencilFunc(vt,Sn,ot),re=vt,we=Sn,Fe=ot)},setOp:function(vt,Sn,ot){(_e!==vt||Ke!==Sn||Ye!==ot)&&(i.stencilOp(vt,Sn,ot),_e=vt,Ke=Sn,Ye=ot)},setLocked:function(vt){D=vt},setClear:function(vt){Bt!==vt&&(i.clearStencil(vt),Bt=vt)},reset:function(){D=!1,Ce=null,re=null,we=null,Fe=null,_e=null,Ke=null,Ye=null,Bt=null}}}let r=new t,a=new n,o=new s,l=new WeakMap,c=new WeakMap,h={},f={},u={},d=new WeakMap,g=[],x=null,m=!1,p=null,S=null,A=null,v=null,b=null,E=null,C=null,y=new it(0,0,0),w=0,P=!1,U=null,B=null,W=null,F=null,V=null,se=i.getParameter(i.MAX_COMBINED_TEXTURE_IMAGE_UNITS),K=!1,de=0,te=i.getParameter(i.VERSION);te.indexOf("WebGL")!==-1?(de=parseFloat(/^WebGL (\d)/.exec(te)[1]),K=de>=1):te.indexOf("OpenGL ES")!==-1&&(de=parseFloat(/^OpenGL ES (\d)/.exec(te)[1]),K=de>=2);let ae=null,O={},ye=i.getParameter(i.SCISSOR_BOX),Se=i.getParameter(i.VIEWPORT),be=new Gt().fromArray(ye),Ve=new Gt().fromArray(Se);function me(D,Ce,re,we){let Fe=new Uint8Array(4),_e=i.createTexture();i.bindTexture(D,_e),i.texParameteri(D,i.TEXTURE_MIN_FILTER,i.NEAREST),i.texParameteri(D,i.TEXTURE_MAG_FILTER,i.NEAREST);for(let Ke=0;Ke<re;Ke++)D===i.TEXTURE_3D||D===i.TEXTURE_2D_ARRAY?i.texImage3D(Ce,0,i.RGBA,1,1,we,0,i.RGBA,i.UNSIGNED_BYTE,Fe):i.texImage2D(Ce+Ke,0,i.RGBA,1,1,0,i.RGBA,i.UNSIGNED_BYTE,Fe);return _e}let $={};$[i.TEXTURE_2D]=me(i.TEXTURE_2D,i.TEXTURE_2D,1),$[i.TEXTURE_CUBE_MAP]=me(i.TEXTURE_CUBE_MAP,i.TEXTURE_CUBE_MAP_POSITIVE_X,6),$[i.TEXTURE_2D_ARRAY]=me(i.TEXTURE_2D_ARRAY,i.TEXTURE_2D_ARRAY,1,1),$[i.TEXTURE_3D]=me(i.TEXTURE_3D,i.TEXTURE_3D,1,1),r.setClear(0,0,0,1),a.setClear(1),o.setClear(0),X(i.DEPTH_TEST),a.setFunc(Js),ge(!1),xe(g0),X(i.CULL_FACE),ce(Hn);function X(D){h[D]!==!0&&(i.enable(D),h[D]=!0)}function he(D){h[D]!==!1&&(i.disable(D),h[D]=!1)}function Te(D,Ce){return u[D]!==Ce?(i.bindFramebuffer(D,Ce),u[D]=Ce,D===i.DRAW_FRAMEBUFFER&&(u[i.FRAMEBUFFER]=Ce),D===i.FRAMEBUFFER&&(u[i.DRAW_FRAMEBUFFER]=Ce),!0):!1}function le(D,Ce){let re=g,we=!1;if(D){re=d.get(Ce),re===void 0&&(re=[],d.set(Ce,re));let Fe=D.textures;if(re.length!==Fe.length||re[0]!==i.COLOR_ATTACHMENT0){for(let _e=0,Ke=Fe.length;_e<Ke;_e++)re[_e]=i.COLOR_ATTACHMENT0+_e;re.length=Fe.length,we=!0}}else re[0]!==i.BACK&&(re[0]=i.BACK,we=!0);we&&i.drawBuffers(re)}function Ie(D){return x!==D?(i.useProgram(D),x=D,!0):!1}let st={[ys]:i.FUNC_ADD,[tu]:i.FUNC_SUBTRACT,[nu]:i.FUNC_REVERSE_SUBTRACT};st[iu]=i.MIN,st[su]=i.MAX;let Z={[ru]:i.ZERO,[au]:i.ONE,[ou]:i.SRC_COLOR,[v0]:i.SRC_ALPHA,[du]:i.SRC_ALPHA_SATURATE,[uu]:i.DST_COLOR,[cu]:i.DST_ALPHA,[lu]:i.ONE_MINUS_SRC_COLOR,[y0]:i.ONE_MINUS_SRC_ALPHA,[fu]:i.ONE_MINUS_DST_COLOR,[hu]:i.ONE_MINUS_DST_ALPHA,[pu]:i.CONSTANT_COLOR,[mu]:i.ONE_MINUS_CONSTANT_COLOR,[gu]:i.CONSTANT_ALPHA,[_u]:i.ONE_MINUS_CONSTANT_ALPHA};function ce(D,Ce,re,we,Fe,_e,Ke,Ye,Bt,vt){if(D===Hn){m===!0&&(he(i.BLEND),m=!1);return}if(m===!1&&(X(i.BLEND),m=!0),D!==eu){if(D!==p||vt!==P){if((S!==ys||b!==ys)&&(i.blendEquation(i.FUNC_ADD),S=ys,b=ys),vt)switch(D){case ns:i.blendFuncSeparate(i.ONE,i.ONE_MINUS_SRC_ALPHA,i.ONE,i.ONE_MINUS_SRC_ALPHA);break;case nn:i.blendFunc(i.ONE,i.ONE);break;case _0:i.blendFuncSeparate(i.ZERO,i.ONE_MINUS_SRC_COLOR,i.ZERO,i.ONE);break;case x0:i.blendFuncSeparate(i.DST_COLOR,i.ONE_MINUS_SRC_ALPHA,i.ZERO,i.ONE);break;default:lt("WebGLState: Invalid blending: ",D);break}else switch(D){case ns:i.blendFuncSeparate(i.SRC_ALPHA,i.ONE_MINUS_SRC_ALPHA,i.ONE,i.ONE_MINUS_SRC_ALPHA);break;case nn:i.blendFuncSeparate(i.SRC_ALPHA,i.ONE,i.ONE,i.ONE);break;case _0:lt("WebGLState: SubtractiveBlending requires material.premultipliedAlpha = true");break;case x0:lt("WebGLState: MultiplyBlending requires material.premultipliedAlpha = true");break;default:lt("WebGLState: Invalid blending: ",D);break}A=null,v=null,E=null,C=null,y.set(0,0,0),w=0,p=D,P=vt}return}Fe=Fe||Ce,_e=_e||re,Ke=Ke||we,(Ce!==S||Fe!==b)&&(i.blendEquationSeparate(st[Ce],st[Fe]),S=Ce,b=Fe),(re!==A||we!==v||_e!==E||Ke!==C)&&(i.blendFuncSeparate(Z[re],Z[we],Z[_e],Z[Ke]),A=re,v=we,E=_e,C=Ke),(Ye.equals(y)===!1||Bt!==w)&&(i.blendColor(Ye.r,Ye.g,Ye.b,Bt),y.copy(Ye),w=Bt),p=D,P=!1}function Me(D,Ce){D.side===xn?he(i.CULL_FACE):X(i.CULL_FACE);let re=D.side===_n;Ce&&(re=!re),ge(re),D.blending===ns&&D.transparent===!1?ce(Hn):ce(D.blending,D.blendEquation,D.blendSrc,D.blendDst,D.blendEquationAlpha,D.blendSrcAlpha,D.blendDstAlpha,D.blendColor,D.blendAlpha,D.premultipliedAlpha),a.setFunc(D.depthFunc),a.setTest(D.depthTest),a.setMask(D.depthWrite),r.setMask(D.colorWrite);let we=D.stencilWrite;o.setTest(we),we&&(o.setMask(D.stencilWriteMask),o.setFunc(D.stencilFunc,D.stencilRef,D.stencilFuncMask),o.setOp(D.stencilFail,D.stencilZFail,D.stencilZPass)),Le(D.polygonOffset,D.polygonOffsetFactor,D.polygonOffsetUnits),D.alphaToCoverage===!0?X(i.SAMPLE_ALPHA_TO_COVERAGE):he(i.SAMPLE_ALPHA_TO_COVERAGE)}function ge(D){U!==D&&(D?i.frontFace(i.CW):i.frontFace(i.CCW),U=D)}function xe(D){D!==Kh?(X(i.CULL_FACE),D!==B&&(D===g0?i.cullFace(i.BACK):D===jh?i.cullFace(i.FRONT):i.cullFace(i.FRONT_AND_BACK))):he(i.CULL_FACE),B=D}function ke(D){D!==W&&(K&&i.lineWidth(D),W=D)}function Le(D,Ce,re){D?(X(i.POLYGON_OFFSET_FILL),(F!==Ce||V!==re)&&(F=Ce,V=re,a.getReversed()&&(Ce=-Ce),i.polygonOffset(Ce,re))):he(i.POLYGON_OFFSET_FILL)}function Je(D){D?X(i.SCISSOR_TEST):he(i.SCISSOR_TEST)}function tt(D){D===void 0&&(D=i.TEXTURE0+se-1),ae!==D&&(i.activeTexture(D),ae=D)}function L(D,Ce,re){re===void 0&&(ae===null?re=i.TEXTURE0+se-1:re=ae);let we=O[re];we===void 0&&(we={type:void 0,texture:void 0},O[re]=we),(we.type!==D||we.texture!==Ce)&&(ae!==re&&(i.activeTexture(re),ae=re),i.bindTexture(D,Ce||$[D]),we.type=D,we.texture=Ce)}function Qe(){let D=O[ae];D!==void 0&&D.type!==void 0&&(i.bindTexture(D.type,null),D.type=void 0,D.texture=void 0)}function at(){try{i.compressedTexImage2D(...arguments)}catch(D){lt("WebGLState:",D)}}function T(){try{i.compressedTexImage3D(...arguments)}catch(D){lt("WebGLState:",D)}}function _(){try{i.texSubImage2D(...arguments)}catch(D){lt("WebGLState:",D)}}function H(){try{i.texSubImage3D(...arguments)}catch(D){lt("WebGLState:",D)}}function G(){try{i.compressedTexSubImage2D(...arguments)}catch(D){lt("WebGLState:",D)}}function ne(){try{i.compressedTexSubImage3D(...arguments)}catch(D){lt("WebGLState:",D)}}function ve(){try{i.texStorage2D(...arguments)}catch(D){lt("WebGLState:",D)}}function Ae(){try{i.texStorage3D(...arguments)}catch(D){lt("WebGLState:",D)}}function ee(){try{i.texImage2D(...arguments)}catch(D){lt("WebGLState:",D)}}function oe(){try{i.texImage3D(...arguments)}catch(D){lt("WebGLState:",D)}}function Re(D){return f[D]!==void 0?f[D]:i.getParameter(D)}function qe(D,Ce){f[D]!==Ce&&(i.pixelStorei(D,Ce),f[D]=Ce)}function Pe(D){be.equals(D)===!1&&(i.scissor(D.x,D.y,D.z,D.w),be.copy(D))}function pe(D){Ve.equals(D)===!1&&(i.viewport(D.x,D.y,D.z,D.w),Ve.copy(D))}function Ge(D,Ce){let re=c.get(Ce);re===void 0&&(re=new WeakMap,c.set(Ce,re));let we=re.get(D);we===void 0&&(we=i.getUniformBlockIndex(Ce,D.name),re.set(D,we))}function et(D,Ce){let we=c.get(Ce).get(D);l.get(Ce)!==we&&(i.uniformBlockBinding(Ce,we,D.__bindingPointIndex),l.set(Ce,we))}function ht(){i.disable(i.BLEND),i.disable(i.CULL_FACE),i.disable(i.DEPTH_TEST),i.disable(i.POLYGON_OFFSET_FILL),i.disable(i.SCISSOR_TEST),i.disable(i.STENCIL_TEST),i.disable(i.SAMPLE_ALPHA_TO_COVERAGE),i.blendEquation(i.FUNC_ADD),i.blendFunc(i.ONE,i.ZERO),i.blendFuncSeparate(i.ONE,i.ZERO,i.ONE,i.ZERO),i.blendColor(0,0,0,0),i.colorMask(!0,!0,!0,!0),i.clearColor(0,0,0,0),i.depthMask(!0),i.depthFunc(i.LESS),a.setReversed(!1),i.clearDepth(1),i.stencilMask(4294967295),i.stencilFunc(i.ALWAYS,0,4294967295),i.stencilOp(i.KEEP,i.KEEP,i.KEEP),i.clearStencil(0),i.cullFace(i.BACK),i.frontFace(i.CCW),i.polygonOffset(0,0),i.activeTexture(i.TEXTURE0),i.bindFramebuffer(i.FRAMEBUFFER,null),i.bindFramebuffer(i.DRAW_FRAMEBUFFER,null),i.bindFramebuffer(i.READ_FRAMEBUFFER,null),i.useProgram(null),i.lineWidth(1),i.scissor(0,0,i.canvas.width,i.canvas.height),i.viewport(0,0,i.canvas.width,i.canvas.height),i.pixelStorei(i.PACK_ALIGNMENT,4),i.pixelStorei(i.UNPACK_ALIGNMENT,4),i.pixelStorei(i.UNPACK_FLIP_Y_WEBGL,!1),i.pixelStorei(i.UNPACK_PREMULTIPLY_ALPHA_WEBGL,!1),i.pixelStorei(i.UNPACK_COLORSPACE_CONVERSION_WEBGL,i.BROWSER_DEFAULT_WEBGL),i.pixelStorei(i.PACK_ROW_LENGTH,0),i.pixelStorei(i.PACK_SKIP_PIXELS,0),i.pixelStorei(i.PACK_SKIP_ROWS,0),i.pixelStorei(i.UNPACK_ROW_LENGTH,0),i.pixelStorei(i.UNPACK_IMAGE_HEIGHT,0),i.pixelStorei(i.UNPACK_SKIP_PIXELS,0),i.pixelStorei(i.UNPACK_SKIP_ROWS,0),i.pixelStorei(i.UNPACK_SKIP_IMAGES,0),h={},f={},ae=null,O={},u={},d=new WeakMap,g=[],x=null,m=!1,p=null,S=null,A=null,v=null,b=null,E=null,C=null,y=new it(0,0,0),w=0,P=!1,U=null,B=null,W=null,F=null,V=null,be.set(0,0,i.canvas.width,i.canvas.height),Ve.set(0,0,i.canvas.width,i.canvas.height),r.reset(),a.reset(),o.reset()}return{buffers:{color:r,depth:a,stencil:o},enable:X,disable:he,bindFramebuffer:Te,drawBuffers:le,useProgram:Ie,setBlending:ce,setMaterial:Me,setFlipSided:ge,setCullFace:xe,setLineWidth:ke,setPolygonOffset:Le,setScissorTest:Je,activeTexture:tt,bindTexture:L,unbindTexture:Qe,compressedTexImage2D:at,compressedTexImage3D:T,texImage2D:ee,texImage3D:oe,pixelStorei:qe,getParameter:Re,updateUBOMapping:Ge,uniformBlockBinding:et,texStorage2D:ve,texStorage3D:Ae,texSubImage2D:_,texSubImage3D:H,compressedTexSubImage2D:G,compressedTexSubImage3D:ne,scissor:Pe,viewport:pe,reset:ht}}function D2(i,e,t,n,s,r,a){let o=e.has("WEBGL_multisampled_render_to_texture")?e.get("WEBGL_multisampled_render_to_texture"):null,l=typeof navigator>"u"?!1:/OculusBrowser/g.test(navigator.userAgent),c=new ue,h=new WeakMap,f=new Set,u,d=new WeakMap,g=!1;try{g=typeof OffscreenCanvas<"u"&&new OffscreenCanvas(1,1).getContext("2d")!==null}catch{}function x(T,_){return g?new OffscreenCanvas(T,_):js("canvas")}function m(T,_,H){let G=1,ne=at(T);if((ne.width>H||ne.height>H)&&(G=H/Math.max(ne.width,ne.height)),G<1)if(typeof HTMLImageElement<"u"&&T instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&T instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&T instanceof ImageBitmap||typeof VideoFrame<"u"&&T instanceof VideoFrame){let ve=Math.floor(G*ne.width),Ae=Math.floor(G*ne.height);u===void 0&&(u=x(ve,Ae));let ee=_?x(ve,Ae):u;return ee.width=ve,ee.height=Ae,ee.getContext("2d").drawImage(T,0,0,ve,Ae),ct("WebGLRenderer: Texture has been resized from ("+ne.width+"x"+ne.height+") to ("+ve+"x"+Ae+")."),ee}else return"data"in T&&ct("WebGLRenderer: Image in DataTexture is too big ("+ne.width+"x"+ne.height+")."),T;return T}function p(T){return T.generateMipmaps}function S(T){i.generateMipmap(T)}function A(T){return T.isWebGLCubeRenderTarget?i.TEXTURE_CUBE_MAP:T.isWebGL3DRenderTarget?i.TEXTURE_3D:T.isWebGLArrayRenderTarget||T.isCompressedArrayTexture?i.TEXTURE_2D_ARRAY:i.TEXTURE_2D}function v(T,_,H,G,ne,ve=!1){if(T!==null){if(i[T]!==void 0)return i[T];ct("WebGLRenderer: Attempt to use non-existing WebGL internal format '"+T+"'")}let Ae;G&&(Ae=e.get("EXT_texture_norm16"),Ae||ct("WebGLRenderer: Unable to use normalized textures without EXT_texture_norm16 extension"));let ee=_;if(_===i.RED&&(H===i.FLOAT&&(ee=i.R32F),H===i.HALF_FLOAT&&(ee=i.R16F),H===i.UNSIGNED_BYTE&&(ee=i.R8),H===i.UNSIGNED_SHORT&&Ae&&(ee=Ae.R16_EXT),H===i.SHORT&&Ae&&(ee=Ae.R16_SNORM_EXT)),_===i.RED_INTEGER&&(H===i.UNSIGNED_BYTE&&(ee=i.R8UI),H===i.UNSIGNED_SHORT&&(ee=i.R16UI),H===i.UNSIGNED_INT&&(ee=i.R32UI),H===i.BYTE&&(ee=i.R8I),H===i.SHORT&&(ee=i.R16I),H===i.INT&&(ee=i.R32I)),_===i.RG&&(H===i.FLOAT&&(ee=i.RG32F),H===i.HALF_FLOAT&&(ee=i.RG16F),H===i.UNSIGNED_BYTE&&(ee=i.RG8),H===i.UNSIGNED_SHORT&&Ae&&(ee=Ae.RG16_EXT),H===i.SHORT&&Ae&&(ee=Ae.RG16_SNORM_EXT)),_===i.RG_INTEGER&&(H===i.UNSIGNED_BYTE&&(ee=i.RG8UI),H===i.UNSIGNED_SHORT&&(ee=i.RG16UI),H===i.UNSIGNED_INT&&(ee=i.RG32UI),H===i.BYTE&&(ee=i.RG8I),H===i.SHORT&&(ee=i.RG16I),H===i.INT&&(ee=i.RG32I)),_===i.RGB_INTEGER&&(H===i.UNSIGNED_BYTE&&(ee=i.RGB8UI),H===i.UNSIGNED_SHORT&&(ee=i.RGB16UI),H===i.UNSIGNED_INT&&(ee=i.RGB32UI),H===i.BYTE&&(ee=i.RGB8I),H===i.SHORT&&(ee=i.RGB16I),H===i.INT&&(ee=i.RGB32I)),_===i.RGBA_INTEGER&&(H===i.UNSIGNED_BYTE&&(ee=i.RGBA8UI),H===i.UNSIGNED_SHORT&&(ee=i.RGBA16UI),H===i.UNSIGNED_INT&&(ee=i.RGBA32UI),H===i.BYTE&&(ee=i.RGBA8I),H===i.SHORT&&(ee=i.RGBA16I),H===i.INT&&(ee=i.RGBA32I)),_===i.RGB&&(H===i.UNSIGNED_SHORT&&Ae&&(ee=Ae.RGB16_EXT),H===i.SHORT&&Ae&&(ee=Ae.RGB16_SNORM_EXT),H===i.UNSIGNED_INT_5_9_9_9_REV&&(ee=i.RGB9_E5),H===i.UNSIGNED_INT_10F_11F_11F_REV&&(ee=i.R11F_G11F_B10F)),_===i.RGBA){let oe=ve?$r:St.getTransfer(ne);H===i.FLOAT&&(ee=i.RGBA32F),H===i.HALF_FLOAT&&(ee=i.RGBA16F),H===i.UNSIGNED_BYTE&&(ee=oe===Pt?i.SRGB8_ALPHA8:i.RGBA8),H===i.UNSIGNED_SHORT&&Ae&&(ee=Ae.RGBA16_EXT),H===i.SHORT&&Ae&&(ee=Ae.RGBA16_SNORM_EXT),H===i.UNSIGNED_SHORT_4_4_4_4&&(ee=i.RGBA4),H===i.UNSIGNED_SHORT_5_5_5_1&&(ee=i.RGB5_A1)}return(ee===i.R16F||ee===i.R32F||ee===i.RG16F||ee===i.RG32F||ee===i.RGBA16F||ee===i.RGBA32F)&&e.get("EXT_color_buffer_float"),ee}function b(T,_){let H;return T?_===null||_===ei||_===yr?H=i.DEPTH24_STENCIL8:_===kn?H=i.DEPTH32F_STENCIL8:_===vr&&(H=i.DEPTH24_STENCIL8,ct("DepthTexture: 16 bit depth attachment is not supported with stencil. Using 24-bit attachment.")):_===null||_===ei||_===yr?H=i.DEPTH_COMPONENT24:_===kn?H=i.DEPTH_COMPONENT32F:_===vr&&(H=i.DEPTH_COMPONENT16),H}function E(T,_){return p(T)===!0||T.isFramebufferTexture&&T.minFilter!==un&&T.minFilter!==gn?Math.log2(Math.max(_.width,_.height))+1:T.mipmaps!==void 0&&T.mipmaps.length>0?T.mipmaps.length:T.isCompressedTexture&&Array.isArray(T.image)?_.mipmaps.length:1}function C(T){let _=T.target;_.removeEventListener("dispose",C),w(_),_.isVideoTexture&&h.delete(_),_.isHTMLTexture&&f.delete(_)}function y(T){let _=T.target;_.removeEventListener("dispose",y),U(_)}function w(T){let _=n.get(T);if(_.__webglInit===void 0)return;let H=T.source,G=d.get(H);if(G){let ne=G[_.__cacheKey];ne.usedTimes--,ne.usedTimes===0&&P(T),Object.keys(G).length===0&&d.delete(H)}n.remove(T)}function P(T){let _=n.get(T);i.deleteTexture(_.__webglTexture);let H=T.source,G=d.get(H);delete G[_.__cacheKey],a.memory.textures--}function U(T){let _=n.get(T);if(T.depthTexture&&(T.depthTexture.dispose(),n.remove(T.depthTexture)),T.isWebGLCubeRenderTarget)for(let G=0;G<6;G++){if(Array.isArray(_.__webglFramebuffer[G]))for(let ne=0;ne<_.__webglFramebuffer[G].length;ne++)i.deleteFramebuffer(_.__webglFramebuffer[G][ne]);else i.deleteFramebuffer(_.__webglFramebuffer[G]);_.__webglDepthbuffer&&i.deleteRenderbuffer(_.__webglDepthbuffer[G])}else{if(Array.isArray(_.__webglFramebuffer))for(let G=0;G<_.__webglFramebuffer.length;G++)i.deleteFramebuffer(_.__webglFramebuffer[G]);else i.deleteFramebuffer(_.__webglFramebuffer);if(_.__webglDepthbuffer&&i.deleteRenderbuffer(_.__webglDepthbuffer),_.__webglMultisampledFramebuffer&&i.deleteFramebuffer(_.__webglMultisampledFramebuffer),_.__webglColorRenderbuffer)for(let G=0;G<_.__webglColorRenderbuffer.length;G++)_.__webglColorRenderbuffer[G]&&i.deleteRenderbuffer(_.__webglColorRenderbuffer[G]);_.__webglDepthRenderbuffer&&i.deleteRenderbuffer(_.__webglDepthRenderbuffer)}let H=T.textures;for(let G=0,ne=H.length;G<ne;G++){let ve=n.get(H[G]);ve.__webglTexture&&(i.deleteTexture(ve.__webglTexture),a.memory.textures--),n.remove(H[G])}n.remove(T)}let B=0;function W(){B=0}function F(){return B}function V(T){B=T}function se(){let T=B;return T>=s.maxTextures&&ct("WebGLTextures: Trying to use "+(T+1)+" texture units while this GPU supports only "+s.maxTextures),B+=1,T}function K(T){let _=[];return _.push(T.wrapS),_.push(T.wrapT),_.push(T.wrapR||0),_.push(T.magFilter),_.push(T.minFilter),_.push(T.anisotropy),_.push(T.internalFormat),_.push(T.format),_.push(T.type),_.push(T.generateMipmaps),_.push(T.premultiplyAlpha),_.push(T.flipY),_.push(T.unpackAlignment),_.push(T.colorSpace),_.join()}function de(T,_){let H=n.get(T);if(T.isVideoTexture&&L(T),T.isRenderTargetTexture===!1&&T.isExternalTexture!==!0&&T.version>0&&H.__version!==T.version){let G=T.image;if(G===null)ct("WebGLRenderer: Texture marked for update but no image data found.");else if(G.complete===!1)ct("WebGLRenderer: Texture marked for update but image is incomplete");else{he(H,T,_);return}}else T.isExternalTexture&&(H.__webglTexture=T.sourceTexture?T.sourceTexture:null);t.bindTexture(i.TEXTURE_2D,H.__webglTexture,i.TEXTURE0+_)}function te(T,_){let H=n.get(T);if(T.isRenderTargetTexture===!1&&T.version>0&&H.__version!==T.version){he(H,T,_);return}else T.isExternalTexture&&(H.__webglTexture=T.sourceTexture?T.sourceTexture:null);t.bindTexture(i.TEXTURE_2D_ARRAY,H.__webglTexture,i.TEXTURE0+_)}function ae(T,_){let H=n.get(T);if(T.isRenderTargetTexture===!1&&T.version>0&&H.__version!==T.version){he(H,T,_);return}t.bindTexture(i.TEXTURE_3D,H.__webglTexture,i.TEXTURE0+_)}function O(T,_){let H=n.get(T);if(T.isCubeDepthTexture!==!0&&T.version>0&&H.__version!==T.version){Te(H,T,_);return}t.bindTexture(i.TEXTURE_CUBE_MAP,H.__webglTexture,i.TEXTURE0+_)}let ye={[Yi]:i.REPEAT,[ui]:i.CLAMP_TO_EDGE,[qo]:i.MIRRORED_REPEAT},Se={[un]:i.NEAREST,[yu]:i.NEAREST_MIPMAP_NEAREST,[za]:i.NEAREST_MIPMAP_LINEAR,[gn]:i.LINEAR,[Ml]:i.LINEAR_MIPMAP_NEAREST,[xi]:i.LINEAR_MIPMAP_LINEAR},be={[Eu]:i.NEVER,[Cu]:i.ALWAYS,[Tu]:i.LESS,[ac]:i.LEQUAL,[wu]:i.EQUAL,[oc]:i.GEQUAL,[Au]:i.GREATER,[Ru]:i.NOTEQUAL};function Ve(T,_){if(_.type===kn&&e.has("OES_texture_float_linear")===!1&&(_.magFilter===gn||_.magFilter===Ml||_.magFilter===za||_.magFilter===xi||_.minFilter===gn||_.minFilter===Ml||_.minFilter===za||_.minFilter===xi)&&ct("WebGLRenderer: Unable to use linear filtering with floating point textures. OES_texture_float_linear not supported on this device."),i.texParameteri(T,i.TEXTURE_WRAP_S,ye[_.wrapS]),i.texParameteri(T,i.TEXTURE_WRAP_T,ye[_.wrapT]),(T===i.TEXTURE_3D||T===i.TEXTURE_2D_ARRAY)&&i.texParameteri(T,i.TEXTURE_WRAP_R,ye[_.wrapR]),i.texParameteri(T,i.TEXTURE_MAG_FILTER,Se[_.magFilter]),i.texParameteri(T,i.TEXTURE_MIN_FILTER,Se[_.minFilter]),_.compareFunction&&(i.texParameteri(T,i.TEXTURE_COMPARE_MODE,i.COMPARE_REF_TO_TEXTURE),i.texParameteri(T,i.TEXTURE_COMPARE_FUNC,be[_.compareFunction])),e.has("EXT_texture_filter_anisotropic")===!0){if(_.magFilter===un||_.minFilter!==za&&_.minFilter!==xi||_.type===kn&&e.has("OES_texture_float_linear")===!1)return;if(_.anisotropy>1||n.get(_).__currentAnisotropy){let H=e.get("EXT_texture_filter_anisotropic");i.texParameterf(T,H.TEXTURE_MAX_ANISOTROPY_EXT,Math.min(_.anisotropy,s.getMaxAnisotropy())),n.get(_).__currentAnisotropy=_.anisotropy}}}function me(T,_){let H=!1;T.__webglInit===void 0&&(T.__webglInit=!0,_.addEventListener("dispose",C));let G=_.source,ne=d.get(G);ne===void 0&&(ne={},d.set(G,ne));let ve=K(_);if(ve!==T.__cacheKey){ne[ve]===void 0&&(ne[ve]={texture:i.createTexture(),usedTimes:0},a.memory.textures++,H=!0),ne[ve].usedTimes++;let Ae=ne[T.__cacheKey];Ae!==void 0&&(ne[T.__cacheKey].usedTimes--,Ae.usedTimes===0&&P(_)),T.__cacheKey=ve,T.__webglTexture=ne[ve].texture}return H}function $(T,_,H){return Math.floor(Math.floor(T/H)/_)}function X(T,_,H,G){let ve=T.updateRanges;if(ve.length===0)t.texSubImage2D(i.TEXTURE_2D,0,0,0,_.width,_.height,H,G,_.data);else{ve.sort((qe,Pe)=>qe.start-Pe.start);let Ae=0;for(let qe=1;qe<ve.length;qe++){let Pe=ve[Ae],pe=ve[qe],Ge=Pe.start+Pe.count,et=$(pe.start,_.width,4),ht=$(Pe.start,_.width,4);pe.start<=Ge+1&&et===ht&&$(pe.start+pe.count-1,_.width,4)===et?Pe.count=Math.max(Pe.count,pe.start+pe.count-Pe.start):(++Ae,ve[Ae]=pe)}ve.length=Ae+1;let ee=t.getParameter(i.UNPACK_ROW_LENGTH),oe=t.getParameter(i.UNPACK_SKIP_PIXELS),Re=t.getParameter(i.UNPACK_SKIP_ROWS);t.pixelStorei(i.UNPACK_ROW_LENGTH,_.width);for(let qe=0,Pe=ve.length;qe<Pe;qe++){let pe=ve[qe],Ge=Math.floor(pe.start/4),et=Math.ceil(pe.count/4),ht=Ge%_.width,D=Math.floor(Ge/_.width),Ce=et,re=1;t.pixelStorei(i.UNPACK_SKIP_PIXELS,ht),t.pixelStorei(i.UNPACK_SKIP_ROWS,D),t.texSubImage2D(i.TEXTURE_2D,0,ht,D,Ce,re,H,G,_.data)}T.clearUpdateRanges(),t.pixelStorei(i.UNPACK_ROW_LENGTH,ee),t.pixelStorei(i.UNPACK_SKIP_PIXELS,oe),t.pixelStorei(i.UNPACK_SKIP_ROWS,Re)}}function he(T,_,H){let G=i.TEXTURE_2D;(_.isDataArrayTexture||_.isCompressedArrayTexture)&&(G=i.TEXTURE_2D_ARRAY),_.isData3DTexture&&(G=i.TEXTURE_3D);let ne=me(T,_),ve=_.source;t.bindTexture(G,T.__webglTexture,i.TEXTURE0+H);let Ae=n.get(ve);if(ve.version!==Ae.__version||ne===!0){if(t.activeTexture(i.TEXTURE0+H),(typeof ImageBitmap<"u"&&_.image instanceof ImageBitmap)===!1){let re=St.getPrimaries(St.workingColorSpace),we=_.colorSpace===ti?null:St.getPrimaries(_.colorSpace),Fe=_.colorSpace===ti||re===we?i.NONE:i.BROWSER_DEFAULT_WEBGL;t.pixelStorei(i.UNPACK_FLIP_Y_WEBGL,_.flipY),t.pixelStorei(i.UNPACK_PREMULTIPLY_ALPHA_WEBGL,_.premultiplyAlpha),t.pixelStorei(i.UNPACK_COLORSPACE_CONVERSION_WEBGL,Fe)}t.pixelStorei(i.UNPACK_ALIGNMENT,_.unpackAlignment);let oe=m(_.image,!1,s.maxTextureSize);oe=Qe(_,oe);let Re=r.convert(_.format,_.colorSpace),qe=r.convert(_.type),Pe=v(_.internalFormat,Re,qe,_.normalized,_.colorSpace,_.isVideoTexture);Ve(G,_);let pe,Ge=_.mipmaps,et=_.isVideoTexture!==!0,ht=Ae.__version===void 0||ne===!0,D=ve.dataReady,Ce=E(_,oe);if(_.isDepthTexture)Pe=b(_.format===ss,_.type),ht&&(et?t.texStorage2D(i.TEXTURE_2D,1,Pe,oe.width,oe.height):t.texImage2D(i.TEXTURE_2D,0,Pe,oe.width,oe.height,0,Re,qe,null));else if(_.isDataTexture)if(Ge.length>0){et&&ht&&t.texStorage2D(i.TEXTURE_2D,Ce,Pe,Ge[0].width,Ge[0].height);for(let re=0,we=Ge.length;re<we;re++)pe=Ge[re],et?D&&t.texSubImage2D(i.TEXTURE_2D,re,0,0,pe.width,pe.height,Re,qe,pe.data):t.texImage2D(i.TEXTURE_2D,re,Pe,pe.width,pe.height,0,Re,qe,pe.data);_.generateMipmaps=!1}else et?(ht&&t.texStorage2D(i.TEXTURE_2D,Ce,Pe,oe.width,oe.height),D&&X(_,oe,Re,qe)):t.texImage2D(i.TEXTURE_2D,0,Pe,oe.width,oe.height,0,Re,qe,oe.data);else if(_.isCompressedTexture)if(_.isCompressedArrayTexture){et&&ht&&t.texStorage3D(i.TEXTURE_2D_ARRAY,Ce,Pe,Ge[0].width,Ge[0].height,oe.depth);for(let re=0,we=Ge.length;re<we;re++)if(pe=Ge[re],_.format!==Vn)if(Re!==null)if(et){if(D)if(_.layerUpdates.size>0){let Fe=U0(pe.width,pe.height,_.format,_.type);for(let _e of _.layerUpdates){let Ke=pe.data.subarray(_e*Fe/pe.data.BYTES_PER_ELEMENT,(_e+1)*Fe/pe.data.BYTES_PER_ELEMENT);t.compressedTexSubImage3D(i.TEXTURE_2D_ARRAY,re,0,0,_e,pe.width,pe.height,1,Re,Ke)}}else t.compressedTexSubImage3D(i.TEXTURE_2D_ARRAY,re,0,0,0,pe.width,pe.height,oe.depth,Re,pe.data)}else t.compressedTexImage3D(i.TEXTURE_2D_ARRAY,re,Pe,pe.width,pe.height,oe.depth,0,pe.data,0,0);else ct("WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()");else et?D&&t.texSubImage3D(i.TEXTURE_2D_ARRAY,re,0,0,0,pe.width,pe.height,oe.depth,Re,qe,pe.data):t.texImage3D(i.TEXTURE_2D_ARRAY,re,Pe,pe.width,pe.height,oe.depth,0,Re,qe,pe.data);_.layerUpdates.size>0&&_.clearLayerUpdates()}else{et&&ht&&t.texStorage2D(i.TEXTURE_2D,Ce,Pe,Ge[0].width,Ge[0].height);for(let re=0,we=Ge.length;re<we;re++)pe=Ge[re],_.format!==Vn?Re!==null?et?D&&t.compressedTexSubImage2D(i.TEXTURE_2D,re,0,0,pe.width,pe.height,Re,pe.data):t.compressedTexImage2D(i.TEXTURE_2D,re,Pe,pe.width,pe.height,0,pe.data):ct("WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()"):et?D&&t.texSubImage2D(i.TEXTURE_2D,re,0,0,pe.width,pe.height,Re,qe,pe.data):t.texImage2D(i.TEXTURE_2D,re,Pe,pe.width,pe.height,0,Re,qe,pe.data)}else if(_.isDataArrayTexture)if(et){if(ht&&t.texStorage3D(i.TEXTURE_2D_ARRAY,Ce,Pe,oe.width,oe.height,oe.depth),D)if(_.layerUpdates.size>0){let re=U0(oe.width,oe.height,_.format,_.type);for(let we of _.layerUpdates){let Fe=oe.data.subarray(we*re/oe.data.BYTES_PER_ELEMENT,(we+1)*re/oe.data.BYTES_PER_ELEMENT);t.texSubImage3D(i.TEXTURE_2D_ARRAY,0,0,0,we,oe.width,oe.height,1,Re,qe,Fe)}_.clearLayerUpdates()}else t.texSubImage3D(i.TEXTURE_2D_ARRAY,0,0,0,0,oe.width,oe.height,oe.depth,Re,qe,oe.data)}else t.texImage3D(i.TEXTURE_2D_ARRAY,0,Pe,oe.width,oe.height,oe.depth,0,Re,qe,oe.data);else if(_.isData3DTexture)et?(ht&&t.texStorage3D(i.TEXTURE_3D,Ce,Pe,oe.width,oe.height,oe.depth),D&&t.texSubImage3D(i.TEXTURE_3D,0,0,0,0,oe.width,oe.height,oe.depth,Re,qe,oe.data)):t.texImage3D(i.TEXTURE_3D,0,Pe,oe.width,oe.height,oe.depth,0,Re,qe,oe.data);else if(_.isFramebufferTexture){if(ht)if(et)t.texStorage2D(i.TEXTURE_2D,Ce,Pe,oe.width,oe.height);else{let re=oe.width,we=oe.height;for(let Fe=0;Fe<Ce;Fe++)t.texImage2D(i.TEXTURE_2D,Fe,Pe,re,we,0,Re,qe,null),re>>=1,we>>=1}}else if(_.isHTMLTexture){if("texElementImage2D"in i){let re=i.canvas;if(re.hasAttribute("layoutsubtree")||re.setAttribute("layoutsubtree","true"),oe.parentNode!==re){re.appendChild(oe),f.add(_),re.onpaint=we=>{let Fe=we.changedElements;for(let _e of f)Fe.includes(_e.image)&&(_e.needsUpdate=!0)},re.requestPaint();return}if(i.texElementImage2D.length===3)i.texElementImage2D(i.TEXTURE_2D,i.RGBA8,oe);else{let Fe=i.RGBA,_e=i.RGBA,Ke=i.UNSIGNED_BYTE;i.texElementImage2D(i.TEXTURE_2D,0,Fe,_e,Ke,oe)}i.texParameteri(i.TEXTURE_2D,i.TEXTURE_MIN_FILTER,i.LINEAR),i.texParameteri(i.TEXTURE_2D,i.TEXTURE_WRAP_S,i.CLAMP_TO_EDGE),i.texParameteri(i.TEXTURE_2D,i.TEXTURE_WRAP_T,i.CLAMP_TO_EDGE)}}else if(Ge.length>0){if(et&&ht){let re=at(Ge[0]);t.texStorage2D(i.TEXTURE_2D,Ce,Pe,re.width,re.height)}for(let re=0,we=Ge.length;re<we;re++)pe=Ge[re],et?D&&t.texSubImage2D(i.TEXTURE_2D,re,0,0,Re,qe,pe):t.texImage2D(i.TEXTURE_2D,re,Pe,Re,qe,pe);_.generateMipmaps=!1}else if(et){if(ht){let re=at(oe);t.texStorage2D(i.TEXTURE_2D,Ce,Pe,re.width,re.height)}D&&t.texSubImage2D(i.TEXTURE_2D,0,0,0,Re,qe,oe)}else t.texImage2D(i.TEXTURE_2D,0,Pe,Re,qe,oe);p(_)&&S(G),Ae.__version=ve.version,_.onUpdate&&_.onUpdate(_)}T.__version=_.version}function Te(T,_,H){if(_.image.length!==6)return;let G=me(T,_),ne=_.source;t.bindTexture(i.TEXTURE_CUBE_MAP,T.__webglTexture,i.TEXTURE0+H);let ve=n.get(ne);if(ne.version!==ve.__version||G===!0){t.activeTexture(i.TEXTURE0+H);let Ae=St.getPrimaries(St.workingColorSpace),ee=_.colorSpace===ti?null:St.getPrimaries(_.colorSpace),oe=_.colorSpace===ti||Ae===ee?i.NONE:i.BROWSER_DEFAULT_WEBGL;t.pixelStorei(i.UNPACK_FLIP_Y_WEBGL,_.flipY),t.pixelStorei(i.UNPACK_PREMULTIPLY_ALPHA_WEBGL,_.premultiplyAlpha),t.pixelStorei(i.UNPACK_ALIGNMENT,_.unpackAlignment),t.pixelStorei(i.UNPACK_COLORSPACE_CONVERSION_WEBGL,oe);let Re=_.isCompressedTexture||_.image[0].isCompressedTexture,qe=_.image[0]&&_.image[0].isDataTexture,Pe=[];for(let _e=0;_e<6;_e++)!Re&&!qe?Pe[_e]=m(_.image[_e],!0,s.maxCubemapSize):Pe[_e]=qe?_.image[_e].image:_.image[_e],Pe[_e]=Qe(_,Pe[_e]);let pe=Pe[0],Ge=r.convert(_.format,_.colorSpace),et=r.convert(_.type),ht=v(_.internalFormat,Ge,et,_.normalized,_.colorSpace),D=_.isVideoTexture!==!0,Ce=ve.__version===void 0||G===!0,re=ne.dataReady,we=E(_,pe);Ve(i.TEXTURE_CUBE_MAP,_);let Fe;if(Re){D&&Ce&&t.texStorage2D(i.TEXTURE_CUBE_MAP,we,ht,pe.width,pe.height);for(let _e=0;_e<6;_e++){Fe=Pe[_e].mipmaps;for(let Ke=0;Ke<Fe.length;Ke++){let Ye=Fe[Ke];_.format!==Vn?Ge!==null?D?re&&t.compressedTexSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Ke,0,0,Ye.width,Ye.height,Ge,Ye.data):t.compressedTexImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Ke,ht,Ye.width,Ye.height,0,Ye.data):ct("WebGLRenderer: Attempt to load unsupported compressed texture format in .setTextureCube()"):D?re&&t.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Ke,0,0,Ye.width,Ye.height,Ge,et,Ye.data):t.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Ke,ht,Ye.width,Ye.height,0,Ge,et,Ye.data)}}}else{if(Fe=_.mipmaps,D&&Ce){Fe.length>0&&we++;let _e=at(Pe[0]);t.texStorage2D(i.TEXTURE_CUBE_MAP,we,ht,_e.width,_e.height)}for(let _e=0;_e<6;_e++)if(qe){D?re&&t.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+_e,0,0,0,Pe[_e].width,Pe[_e].height,Ge,et,Pe[_e].data):t.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+_e,0,ht,Pe[_e].width,Pe[_e].height,0,Ge,et,Pe[_e].data);for(let Ke=0;Ke<Fe.length;Ke++){let Bt=Fe[Ke].image[_e].image;D?re&&t.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Ke+1,0,0,Bt.width,Bt.height,Ge,et,Bt.data):t.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Ke+1,ht,Bt.width,Bt.height,0,Ge,et,Bt.data)}}else{D?re&&t.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+_e,0,0,0,Ge,et,Pe[_e]):t.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+_e,0,ht,Ge,et,Pe[_e]);for(let Ke=0;Ke<Fe.length;Ke++){let Ye=Fe[Ke];D?re&&t.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Ke+1,0,0,Ge,et,Ye.image[_e]):t.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+_e,Ke+1,ht,Ge,et,Ye.image[_e])}}}p(_)&&S(i.TEXTURE_CUBE_MAP),ve.__version=ne.version,_.onUpdate&&_.onUpdate(_)}T.__version=_.version}function le(T,_,H,G,ne,ve){let Ae=r.convert(H.format,H.colorSpace),ee=r.convert(H.type),oe=v(H.internalFormat,Ae,ee,H.normalized,H.colorSpace),Re=n.get(_),qe=n.get(H);if(qe.__renderTarget=_,!Re.__hasExternalTextures){let Pe=Math.max(1,_.width>>ve),pe=Math.max(1,_.height>>ve);ne===i.TEXTURE_3D||ne===i.TEXTURE_2D_ARRAY?t.texImage3D(ne,ve,oe,Pe,pe,_.depth,0,Ae,ee,null):t.texImage2D(ne,ve,oe,Pe,pe,0,Ae,ee,null)}t.bindFramebuffer(i.FRAMEBUFFER,T),tt(_)?o.framebufferTexture2DMultisampleEXT(i.FRAMEBUFFER,G,ne,qe.__webglTexture,0,Je(_)):(ne===i.TEXTURE_2D||ne>=i.TEXTURE_CUBE_MAP_POSITIVE_X&&ne<=i.TEXTURE_CUBE_MAP_NEGATIVE_Z)&&i.framebufferTexture2D(i.FRAMEBUFFER,G,ne,qe.__webglTexture,ve),t.bindFramebuffer(i.FRAMEBUFFER,null)}function Ie(T,_,H){if(i.bindRenderbuffer(i.RENDERBUFFER,T),_.depthBuffer){let G=_.depthTexture,ne=G&&G.isDepthTexture?G.type:null,ve=b(_.stencilBuffer,ne),Ae=_.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT;tt(_)?o.renderbufferStorageMultisampleEXT(i.RENDERBUFFER,Je(_),ve,_.width,_.height):H?i.renderbufferStorageMultisample(i.RENDERBUFFER,Je(_),ve,_.width,_.height):i.renderbufferStorage(i.RENDERBUFFER,ve,_.width,_.height),i.framebufferRenderbuffer(i.FRAMEBUFFER,Ae,i.RENDERBUFFER,T)}else{let G=_.textures;for(let ne=0;ne<G.length;ne++){let ve=G[ne],Ae=r.convert(ve.format,ve.colorSpace),ee=r.convert(ve.type),oe=v(ve.internalFormat,Ae,ee,ve.normalized,ve.colorSpace);tt(_)?o.renderbufferStorageMultisampleEXT(i.RENDERBUFFER,Je(_),oe,_.width,_.height):H?i.renderbufferStorageMultisample(i.RENDERBUFFER,Je(_),oe,_.width,_.height):i.renderbufferStorage(i.RENDERBUFFER,oe,_.width,_.height)}}i.bindRenderbuffer(i.RENDERBUFFER,null)}function st(T,_,H){let G=_.isWebGLCubeRenderTarget===!0;if(t.bindFramebuffer(i.FRAMEBUFFER,T),!(_.depthTexture&&_.depthTexture.isDepthTexture))throw new Error("THREE.WebGLTextures: renderTarget.depthTexture must be an instance of THREE.DepthTexture.");let ne=n.get(_.depthTexture);if(ne.__renderTarget=_,(!ne.__webglTexture||_.depthTexture.image.width!==_.width||_.depthTexture.image.height!==_.height)&&(_.depthTexture.image.width=_.width,_.depthTexture.image.height=_.height,_.depthTexture.needsUpdate=!0),G){if(ne.__webglInit===void 0&&(ne.__webglInit=!0,_.depthTexture.addEventListener("dispose",C)),ne.__webglTexture===void 0){ne.__webglTexture=i.createTexture(),t.bindTexture(i.TEXTURE_CUBE_MAP,ne.__webglTexture),Ve(i.TEXTURE_CUBE_MAP,_.depthTexture);let Re=r.convert(_.depthTexture.format),qe=r.convert(_.depthTexture.type),Pe;_.depthTexture.format===di?Pe=i.DEPTH_COMPONENT24:_.depthTexture.format===ss&&(Pe=i.DEPTH24_STENCIL8);for(let pe=0;pe<6;pe++)i.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+pe,0,Pe,_.width,_.height,0,Re,qe,null)}}else de(_.depthTexture,0);let ve=ne.__webglTexture,Ae=Je(_),ee=G?i.TEXTURE_CUBE_MAP_POSITIVE_X+H:i.TEXTURE_2D,oe=_.depthTexture.format===ss?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT;if(_.depthTexture.format===di)tt(_)?o.framebufferTexture2DMultisampleEXT(i.FRAMEBUFFER,oe,ee,ve,0,Ae):i.framebufferTexture2D(i.FRAMEBUFFER,oe,ee,ve,0);else if(_.depthTexture.format===ss)tt(_)?o.framebufferTexture2DMultisampleEXT(i.FRAMEBUFFER,oe,ee,ve,0,Ae):i.framebufferTexture2D(i.FRAMEBUFFER,oe,ee,ve,0);else throw new Error("THREE.WebGLTextures: Unknown depthTexture format.")}function Z(T){let _=n.get(T),H=T.isWebGLCubeRenderTarget===!0;if(_.__boundDepthTexture!==T.depthTexture){let G=T.depthTexture;if(_.__depthDisposeCallback&&_.__depthDisposeCallback(),G){let ne=()=>{delete _.__boundDepthTexture,delete _.__depthDisposeCallback,G.removeEventListener("dispose",ne)};G.addEventListener("dispose",ne),_.__depthDisposeCallback=ne}_.__boundDepthTexture=G}if(T.depthTexture&&!_.__autoAllocateDepthBuffer)if(H)for(let G=0;G<6;G++)st(_.__webglFramebuffer[G],T,G);else{let G=T.texture.mipmaps;G&&G.length>0?st(_.__webglFramebuffer[0],T,0):st(_.__webglFramebuffer,T,0)}else if(H){_.__webglDepthbuffer=[];for(let G=0;G<6;G++)if(t.bindFramebuffer(i.FRAMEBUFFER,_.__webglFramebuffer[G]),_.__webglDepthbuffer[G]===void 0)_.__webglDepthbuffer[G]=i.createRenderbuffer(),Ie(_.__webglDepthbuffer[G],T,!1);else{let ne=T.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT,ve=_.__webglDepthbuffer[G];i.bindRenderbuffer(i.RENDERBUFFER,ve),i.framebufferRenderbuffer(i.FRAMEBUFFER,ne,i.RENDERBUFFER,ve)}}else{let G=T.texture.mipmaps;if(G&&G.length>0?t.bindFramebuffer(i.FRAMEBUFFER,_.__webglFramebuffer[0]):t.bindFramebuffer(i.FRAMEBUFFER,_.__webglFramebuffer),_.__webglDepthbuffer===void 0)_.__webglDepthbuffer=i.createRenderbuffer(),Ie(_.__webglDepthbuffer,T,!1);else{let ne=T.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT,ve=_.__webglDepthbuffer;i.bindRenderbuffer(i.RENDERBUFFER,ve),i.framebufferRenderbuffer(i.FRAMEBUFFER,ne,i.RENDERBUFFER,ve)}}t.bindFramebuffer(i.FRAMEBUFFER,null)}function ce(T,_,H){let G=n.get(T);_!==void 0&&le(G.__webglFramebuffer,T,T.texture,i.COLOR_ATTACHMENT0,i.TEXTURE_2D,0),H!==void 0&&Z(T)}function Me(T){let _=T.texture,H=n.get(T),G=n.get(_);T.addEventListener("dispose",y);let ne=T.textures,ve=T.isWebGLCubeRenderTarget===!0,Ae=ne.length>1;if(Ae||(G.__webglTexture===void 0&&(G.__webglTexture=i.createTexture()),G.__version=_.version,a.memory.textures++),ve){H.__webglFramebuffer=[];for(let ee=0;ee<6;ee++)if(_.mipmaps&&_.mipmaps.length>0){H.__webglFramebuffer[ee]=[];for(let oe=0;oe<_.mipmaps.length;oe++)H.__webglFramebuffer[ee][oe]=i.createFramebuffer()}else H.__webglFramebuffer[ee]=i.createFramebuffer()}else{if(_.mipmaps&&_.mipmaps.length>0){H.__webglFramebuffer=[];for(let ee=0;ee<_.mipmaps.length;ee++)H.__webglFramebuffer[ee]=i.createFramebuffer()}else H.__webglFramebuffer=i.createFramebuffer();if(Ae)for(let ee=0,oe=ne.length;ee<oe;ee++){let Re=n.get(ne[ee]);Re.__webglTexture===void 0&&(Re.__webglTexture=i.createTexture(),a.memory.textures++)}if(T.samples>0&&tt(T)===!1){H.__webglMultisampledFramebuffer=i.createFramebuffer(),H.__webglColorRenderbuffer=[],t.bindFramebuffer(i.FRAMEBUFFER,H.__webglMultisampledFramebuffer);for(let ee=0;ee<ne.length;ee++){let oe=ne[ee];H.__webglColorRenderbuffer[ee]=i.createRenderbuffer(),i.bindRenderbuffer(i.RENDERBUFFER,H.__webglColorRenderbuffer[ee]);let Re=r.convert(oe.format,oe.colorSpace),qe=r.convert(oe.type),Pe=v(oe.internalFormat,Re,qe,oe.normalized,oe.colorSpace,T.isXRRenderTarget===!0),pe=Je(T);i.renderbufferStorageMultisample(i.RENDERBUFFER,pe,Pe,T.width,T.height),i.framebufferRenderbuffer(i.FRAMEBUFFER,i.COLOR_ATTACHMENT0+ee,i.RENDERBUFFER,H.__webglColorRenderbuffer[ee])}i.bindRenderbuffer(i.RENDERBUFFER,null),T.depthBuffer&&(H.__webglDepthRenderbuffer=i.createRenderbuffer(),Ie(H.__webglDepthRenderbuffer,T,!0)),t.bindFramebuffer(i.FRAMEBUFFER,null)}}if(ve){t.bindTexture(i.TEXTURE_CUBE_MAP,G.__webglTexture),Ve(i.TEXTURE_CUBE_MAP,_);for(let ee=0;ee<6;ee++)if(_.mipmaps&&_.mipmaps.length>0)for(let oe=0;oe<_.mipmaps.length;oe++)le(H.__webglFramebuffer[ee][oe],T,_,i.COLOR_ATTACHMENT0,i.TEXTURE_CUBE_MAP_POSITIVE_X+ee,oe);else le(H.__webglFramebuffer[ee],T,_,i.COLOR_ATTACHMENT0,i.TEXTURE_CUBE_MAP_POSITIVE_X+ee,0);p(_)&&S(i.TEXTURE_CUBE_MAP),t.unbindTexture()}else if(Ae){for(let ee=0,oe=ne.length;ee<oe;ee++){let Re=ne[ee],qe=n.get(Re),Pe=i.TEXTURE_2D;(T.isWebGL3DRenderTarget||T.isWebGLArrayRenderTarget)&&(Pe=T.isWebGL3DRenderTarget?i.TEXTURE_3D:i.TEXTURE_2D_ARRAY),t.bindTexture(Pe,qe.__webglTexture),Ve(Pe,Re),le(H.__webglFramebuffer,T,Re,i.COLOR_ATTACHMENT0+ee,Pe,0),p(Re)&&S(Pe)}t.unbindTexture()}else{let ee=i.TEXTURE_2D;if((T.isWebGL3DRenderTarget||T.isWebGLArrayRenderTarget)&&(ee=T.isWebGL3DRenderTarget?i.TEXTURE_3D:i.TEXTURE_2D_ARRAY),t.bindTexture(ee,G.__webglTexture),Ve(ee,_),_.mipmaps&&_.mipmaps.length>0)for(let oe=0;oe<_.mipmaps.length;oe++)le(H.__webglFramebuffer[oe],T,_,i.COLOR_ATTACHMENT0,ee,oe);else le(H.__webglFramebuffer,T,_,i.COLOR_ATTACHMENT0,ee,0);p(_)&&S(ee),t.unbindTexture()}T.depthBuffer&&Z(T)}function ge(T){let _=T.textures;for(let H=0,G=_.length;H<G;H++){let ne=_[H];if(p(ne)){let ve=A(T),Ae=n.get(ne).__webglTexture;t.bindTexture(ve,Ae),S(ve),t.unbindTexture()}}}let xe=[],ke=[];function Le(T){if(T.samples>0){if(tt(T)===!1){let _=T.textures,H=T.width,G=T.height,ne=i.COLOR_BUFFER_BIT,ve=T.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT,Ae=n.get(T),ee=_.length>1;if(ee)for(let Re=0;Re<_.length;Re++)t.bindFramebuffer(i.FRAMEBUFFER,Ae.__webglMultisampledFramebuffer),i.framebufferRenderbuffer(i.FRAMEBUFFER,i.COLOR_ATTACHMENT0+Re,i.RENDERBUFFER,null),t.bindFramebuffer(i.FRAMEBUFFER,Ae.__webglFramebuffer),i.framebufferTexture2D(i.DRAW_FRAMEBUFFER,i.COLOR_ATTACHMENT0+Re,i.TEXTURE_2D,null,0);t.bindFramebuffer(i.READ_FRAMEBUFFER,Ae.__webglMultisampledFramebuffer);let oe=T.texture.mipmaps;oe&&oe.length>0?t.bindFramebuffer(i.DRAW_FRAMEBUFFER,Ae.__webglFramebuffer[0]):t.bindFramebuffer(i.DRAW_FRAMEBUFFER,Ae.__webglFramebuffer);for(let Re=0;Re<_.length;Re++){if(T.resolveDepthBuffer&&(T.depthBuffer&&(ne|=i.DEPTH_BUFFER_BIT),T.stencilBuffer&&T.resolveStencilBuffer&&(ne|=i.STENCIL_BUFFER_BIT)),ee){i.framebufferRenderbuffer(i.READ_FRAMEBUFFER,i.COLOR_ATTACHMENT0,i.RENDERBUFFER,Ae.__webglColorRenderbuffer[Re]);let qe=n.get(_[Re]).__webglTexture;i.framebufferTexture2D(i.DRAW_FRAMEBUFFER,i.COLOR_ATTACHMENT0,i.TEXTURE_2D,qe,0)}i.blitFramebuffer(0,0,H,G,0,0,H,G,ne,i.NEAREST),l===!0&&(xe.length=0,ke.length=0,xe.push(i.COLOR_ATTACHMENT0+Re),T.depthBuffer&&T.storeMultisampledDepthBuffer===!1&&(xe.push(ve),ke.push(ve),i.invalidateFramebuffer(i.DRAW_FRAMEBUFFER,ke)),i.invalidateFramebuffer(i.READ_FRAMEBUFFER,xe))}if(t.bindFramebuffer(i.READ_FRAMEBUFFER,null),t.bindFramebuffer(i.DRAW_FRAMEBUFFER,null),ee)for(let Re=0;Re<_.length;Re++){t.bindFramebuffer(i.FRAMEBUFFER,Ae.__webglMultisampledFramebuffer),i.framebufferRenderbuffer(i.FRAMEBUFFER,i.COLOR_ATTACHMENT0+Re,i.RENDERBUFFER,Ae.__webglColorRenderbuffer[Re]);let qe=n.get(_[Re]).__webglTexture;t.bindFramebuffer(i.FRAMEBUFFER,Ae.__webglFramebuffer),i.framebufferTexture2D(i.DRAW_FRAMEBUFFER,i.COLOR_ATTACHMENT0+Re,i.TEXTURE_2D,qe,0)}t.bindFramebuffer(i.DRAW_FRAMEBUFFER,Ae.__webglMultisampledFramebuffer)}else if(T.depthBuffer&&T.storeMultisampledDepthBuffer===!1&&l){let _=T.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT;i.invalidateFramebuffer(i.DRAW_FRAMEBUFFER,[_])}}}function Je(T){return Math.min(s.maxSamples,T.samples)}function tt(T){let _=n.get(T);return T.samples>0&&e.has("WEBGL_multisampled_render_to_texture")===!0&&_.__useRenderToTexture!==!1}function L(T){let _=a.render.frame;h.get(T)!==_&&(h.set(T,_),T.update())}function Qe(T,_){let H=T.colorSpace,G=T.format,ne=T.type;return T.isCompressedTexture===!0||T.isVideoTexture===!0||H!==Yr&&H!==ti&&(St.getTransfer(H)===Pt?(G!==Vn||ne!==Rn)&&ct("WebGLTextures: sRGB encoded textures have to use RGBAFormat and UnsignedByteType."):lt("WebGLTextures: Unsupported texture color space:",H)),_}function at(T){return typeof HTMLImageElement<"u"&&T instanceof HTMLImageElement?(c.width=T.naturalWidth||T.width,c.height=T.naturalHeight||T.height):typeof VideoFrame<"u"&&T instanceof VideoFrame?(c.width=T.displayWidth,c.height=T.displayHeight):(c.width=T.width,c.height=T.height),c}this.allocateTextureUnit=se,this.resetTextureUnits=W,this.getTextureUnits=F,this.setTextureUnits=V,this.setTexture2D=de,this.setTexture2DArray=te,this.setTexture3D=ae,this.setTextureCube=O,this.rebindTextures=ce,this.setupRenderTarget=Me,this.updateRenderTargetMipmap=ge,this.updateMultisampleRenderTarget=Le,this.setupDepthRenderbuffer=Z,this.setupFrameBufferTexture=le,this.useMultisampledRTT=tt,this.isReversedDepthBuffer=function(){return t.buffers.depth.getReversed()}}function N2(i,e){function t(n,s=ti){let r,a=St.getTransfer(s);if(n===Rn)return i.UNSIGNED_BYTE;if(n===bl)return i.UNSIGNED_SHORT_4_4_4_4;if(n===El)return i.UNSIGNED_SHORT_5_5_5_1;if(n===T0)return i.UNSIGNED_INT_5_9_9_9_REV;if(n===w0)return i.UNSIGNED_INT_10F_11F_11F_REV;if(n===b0)return i.BYTE;if(n===E0)return i.SHORT;if(n===vr)return i.UNSIGNED_SHORT;if(n===Sl)return i.INT;if(n===ei)return i.UNSIGNED_INT;if(n===kn)return i.FLOAT;if(n===sn)return i.HALF_FLOAT;if(n===A0)return i.ALPHA;if(n===R0)return i.RGB;if(n===Vn)return i.RGBA;if(n===di)return i.DEPTH_COMPONENT;if(n===ss)return i.DEPTH_STENCIL;if(n===Tl)return i.RED;if(n===wl)return i.RED_INTEGER;if(n===rs)return i.RG;if(n===Al)return i.RG_INTEGER;if(n===Rl)return i.RGBA_INTEGER;if(n===Ha||n===ka||n===Va||n===Ga)if(a===Pt)if(r=e.get("WEBGL_compressed_texture_s3tc_srgb"),r!==null){if(n===Ha)return r.COMPRESSED_SRGB_S3TC_DXT1_EXT;if(n===ka)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT;if(n===Va)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT;if(n===Ga)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT}else return null;else if(r=e.get("WEBGL_compressed_texture_s3tc"),r!==null){if(n===Ha)return r.COMPRESSED_RGB_S3TC_DXT1_EXT;if(n===ka)return r.COMPRESSED_RGBA_S3TC_DXT1_EXT;if(n===Va)return r.COMPRESSED_RGBA_S3TC_DXT3_EXT;if(n===Ga)return r.COMPRESSED_RGBA_S3TC_DXT5_EXT}else return null;if(n===Cl||n===Pl||n===Il||n===Ll)if(r=e.get("WEBGL_compressed_texture_pvrtc"),r!==null){if(n===Cl)return r.COMPRESSED_RGB_PVRTC_4BPPV1_IMG;if(n===Pl)return r.COMPRESSED_RGB_PVRTC_2BPPV1_IMG;if(n===Il)return r.COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;if(n===Ll)return r.COMPRESSED_RGBA_PVRTC_2BPPV1_IMG}else return null;if(n===Dl||n===Nl||n===Ul||n===Fl||n===Ol||n===Wa||n===Bl)if(r=e.get("WEBGL_compressed_texture_etc"),r!==null){if(n===Dl||n===Nl)return a===Pt?r.COMPRESSED_SRGB8_ETC2:r.COMPRESSED_RGB8_ETC2;if(n===Ul)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ETC2_EAC:r.COMPRESSED_RGBA8_ETC2_EAC;if(n===Fl)return r.COMPRESSED_R11_EAC;if(n===Ol)return r.COMPRESSED_SIGNED_R11_EAC;if(n===Wa)return r.COMPRESSED_RG11_EAC;if(n===Bl)return r.COMPRESSED_SIGNED_RG11_EAC}else return null;if(n===zl||n===Hl||n===kl||n===Vl||n===Gl||n===Wl||n===Xl||n===ql||n===Yl||n===$l||n===Zl||n===Jl||n===Kl||n===jl)if(r=e.get("WEBGL_compressed_texture_astc"),r!==null){if(n===zl)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR:r.COMPRESSED_RGBA_ASTC_4x4_KHR;if(n===Hl)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR:r.COMPRESSED_RGBA_ASTC_5x4_KHR;if(n===kl)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR:r.COMPRESSED_RGBA_ASTC_5x5_KHR;if(n===Vl)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR:r.COMPRESSED_RGBA_ASTC_6x5_KHR;if(n===Gl)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR:r.COMPRESSED_RGBA_ASTC_6x6_KHR;if(n===Wl)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR:r.COMPRESSED_RGBA_ASTC_8x5_KHR;if(n===Xl)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR:r.COMPRESSED_RGBA_ASTC_8x6_KHR;if(n===ql)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR:r.COMPRESSED_RGBA_ASTC_8x8_KHR;if(n===Yl)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR:r.COMPRESSED_RGBA_ASTC_10x5_KHR;if(n===$l)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR:r.COMPRESSED_RGBA_ASTC_10x6_KHR;if(n===Zl)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR:r.COMPRESSED_RGBA_ASTC_10x8_KHR;if(n===Jl)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR:r.COMPRESSED_RGBA_ASTC_10x10_KHR;if(n===Kl)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR:r.COMPRESSED_RGBA_ASTC_12x10_KHR;if(n===jl)return a===Pt?r.COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR:r.COMPRESSED_RGBA_ASTC_12x12_KHR}else return null;if(n===Ql||n===ec||n===tc)if(r=e.get("EXT_texture_compression_bptc"),r!==null){if(n===Ql)return a===Pt?r.COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT:r.COMPRESSED_RGBA_BPTC_UNORM_EXT;if(n===ec)return r.COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT;if(n===tc)return r.COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT}else return null;if(n===nc||n===ic||n===Xa||n===sc)if(r=e.get("EXT_texture_compression_rgtc"),r!==null){if(n===nc)return r.COMPRESSED_RED_RGTC1_EXT;if(n===ic)return r.COMPRESSED_SIGNED_RED_RGTC1_EXT;if(n===Xa)return r.COMPRESSED_RED_GREEN_RGTC2_EXT;if(n===sc)return r.COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT}else return null;return n===yr?i.UNSIGNED_INT_24_8:i[n]!==void 0?i[n]:null}return{convert:t}}var U2=`
void main() {

	gl_Position = vec4( position, 1.0 );

}`,F2=`
uniform sampler2DArray depthColor;
uniform float depthWidth;
uniform float depthHeight;

void main() {

	vec2 coord = vec2( gl_FragCoord.x / depthWidth, gl_FragCoord.y / depthHeight );

	if ( coord.x >= 1.0 ) {

		gl_FragDepth = texture( depthColor, vec3( coord.x - 1.0, coord.y, 1 ) ).r;

	} else {

		gl_FragDepth = texture( depthColor, vec3( coord.x, coord.y, 0 ) ).r;

	}

}`,Z0=class{constructor(){this.texture=null,this.mesh=null,this.depthNear=0,this.depthFar=0}init(e,t){if(this.texture===null){let n=new aa(e.texture);(e.depthNear!==t.depthNear||e.depthFar!==t.depthFar)&&(this.depthNear=e.depthNear,this.depthFar=e.depthFar),this.texture=n}}getMesh(e){if(this.texture!==null&&this.mesh===null){let t=e.cameras[0].viewport,n=new Ft({vertexShader:U2,fragmentShader:F2,uniforms:{depthColor:{value:this.texture},depthWidth:{value:t.z},depthHeight:{value:t.w}}});this.mesh=new gt(new Ji(20,20),n)}return this.mesh}reset(){this.texture=null,this.mesh=null}getDepthTexture(){return this.texture}},J0=class extends pi{constructor(e,t){super();let n=this,s=null,r=1,a=null,o="local-floor",l=1,c=null,h=null,f=null,u=null,d=null,g=null,x=typeof XRWebGLBinding<"u",m=new Z0,p={},S=t.getContextAttributes(),A=null,v=null,b=[],E=[],C=new ue,y=null,w=null,P=new mn;P.viewport=new Gt;let U=new mn;U.viewport=new Gt;let B=[P,U],W=new vl,F=null,V=null;this.cameraAutoUpdate=!0,this.enabled=!1,this.isPresenting=!1,this.getController=function($){let X=b[$];return X===void 0&&(X=new nr,b[$]=X),X.getTargetRaySpace()},this.getControllerGrip=function($){let X=b[$];return X===void 0&&(X=new nr,b[$]=X),X.getGripSpace()},this.getHand=function($){let X=b[$];return X===void 0&&(X=new nr,b[$]=X),X.getHandSpace()};function se($){let X=E.indexOf($.inputSource);if(X===-1)return;let he=b[X];he!==void 0&&(he.update($.inputSource,$.frame,c||a),he.dispatchEvent({type:$.type,data:$.inputSource}))}function K(){s.removeEventListener("select",se),s.removeEventListener("selectstart",se),s.removeEventListener("selectend",se),s.removeEventListener("squeeze",se),s.removeEventListener("squeezestart",se),s.removeEventListener("squeezeend",se),s.removeEventListener("end",K),s.removeEventListener("inputsourceschange",de);for(let $=0;$<b.length;$++){let X=E[$];X!==null&&(E[$]=null,b[$].disconnect(X))}F=null,V=null,m.reset();for(let $ in p)delete p[$];if(e.setRenderTarget(A),d=null,u=null,f=null,s=null,v=null,me.stop(),n.isPresenting=!1,e.setPixelRatio(y),e.setSize(C.width,C.height,!1),w!==null){let $=w.camera;$.fov=w.fov,$.zoom=w.zoom,$.updateProjectionMatrix(),w=null}n.dispatchEvent({type:"sessionend"})}this.setFramebufferScaleFactor=function($){r=$,n.isPresenting===!0&&ct("WebXRManager: Cannot change framebuffer scale while presenting.")},this.setReferenceSpaceType=function($){o=$,n.isPresenting===!0&&ct("WebXRManager: Cannot change reference space type while presenting.")},this.getReferenceSpace=function(){return c||a},this.setReferenceSpace=function($){c=$},this.getBaseLayer=function(){return u!==null?u:d},this.getBinding=function(){return f===null&&x&&(f=new XRWebGLBinding(s,t)),f},this.getFrame=function(){return g},this.getSession=function(){return s},this.setSession=async function($){if(s=$,s!==null){if(A=e.getRenderTarget(),s.addEventListener("select",se),s.addEventListener("selectstart",se),s.addEventListener("selectend",se),s.addEventListener("squeeze",se),s.addEventListener("squeezestart",se),s.addEventListener("squeezeend",se),s.addEventListener("end",K),s.addEventListener("inputsourceschange",de),S.xrCompatible!==!0&&await t.makeXRCompatible(),y=e.getPixelRatio(),e.getSize(C),x&&"createProjectionLayer"in XRWebGLBinding.prototype){let he=null,Te=null,le=null;S.depth&&(le=S.stencil?t.DEPTH24_STENCIL8:t.DEPTH_COMPONENT24,he=S.stencil?ss:di,Te=S.stencil?yr:ei);let Ie={colorFormat:t.RGBA8,depthFormat:le,scaleFactor:r};f=this.getBinding(),u=f.createProjectionLayer(Ie),s.updateRenderState({layers:[u]}),e.setPixelRatio(1),e.setSize(u.textureWidth,u.textureHeight,!1),v=new $t(u.textureWidth,u.textureHeight,{format:Vn,type:Rn,depthTexture:new Zi(u.textureWidth,u.textureHeight,Te,void 0,void 0,void 0,void 0,void 0,void 0,he),stencilBuffer:S.stencil,colorSpace:e.outputColorSpace,samples:S.antialias?4:0,resolveDepthBuffer:u.ignoreDepthValues===!1,resolveStencilBuffer:u.ignoreDepthValues===!1,storeMultisampledDepthBuffer:u.ignoreDepthValues===!1,storeMultisampledStencilBuffer:u.ignoreDepthValues===!1})}else{let he={antialias:S.antialias,alpha:!0,depth:S.depth,stencil:S.stencil,framebufferScaleFactor:r};d=new XRWebGLLayer(s,t,he),s.updateRenderState({baseLayer:d}),e.setPixelRatio(1),e.setSize(d.framebufferWidth,d.framebufferHeight,!1),v=new $t(d.framebufferWidth,d.framebufferHeight,{format:Vn,type:Rn,colorSpace:e.outputColorSpace,stencilBuffer:S.stencil,resolveDepthBuffer:d.ignoreDepthValues===!1,resolveStencilBuffer:d.ignoreDepthValues===!1,storeMultisampledDepthBuffer:d.ignoreDepthValues===!1,storeMultisampledStencilBuffer:d.ignoreDepthValues===!1})}v.isXRRenderTarget=!0,this.setFoveation(l),c=null,a=await s.requestReferenceSpace(o),me.setContext(s),me.start(),n.isPresenting=!0,n.dispatchEvent({type:"sessionstart"})}},this.getEnvironmentBlendMode=function(){if(s!==null)return s.environmentBlendMode},this.getDepthTexture=function(){return m.getDepthTexture()};function de($){for(let X=0;X<$.removed.length;X++){let he=$.removed[X],Te=E.indexOf(he);Te>=0&&(E[Te]=null,b[Te].disconnect(he))}for(let X=0;X<$.added.length;X++){let he=$.added[X],Te=E.indexOf(he);if(Te===-1){for(let Ie=0;Ie<b.length;Ie++)if(Ie>=E.length){E.push(he),Te=Ie;break}else if(E[Ie]===null){E[Ie]=he,Te=Ie;break}if(Te===-1)break}let le=b[Te];le&&le.connect(he)}}let te=new I,ae=new I;function O($,X,he){te.setFromMatrixPosition(X.matrixWorld),ae.setFromMatrixPosition(he.matrixWorld);let Te=te.distanceTo(ae),le=X.projectionMatrix.elements,Ie=he.projectionMatrix.elements,st=le[14]/(le[10]-1),Z=le[14]/(le[10]+1),ce=(le[9]+1)/le[5],Me=(le[9]-1)/le[5],ge=(le[8]-1)/le[0],xe=(Ie[8]+1)/Ie[0],ke=st*ge,Le=st*xe,Je=Te/(-ge+xe),tt=Je*-ge;if(X.matrixWorld.decompose($.position,$.quaternion,$.scale),$.translateX(tt),$.translateZ(Je),$.matrixWorld.compose($.position,$.quaternion,$.scale),$.matrixWorldInverse.copy($.matrixWorld).invert(),le[10]===-1)$.projectionMatrix.copy(X.projectionMatrix),$.projectionMatrixInverse.copy(X.projectionMatrixInverse);else{let L=st+Je,Qe=Z+Je,at=ke-tt,T=Le+(Te-tt),_=ce*Z/Qe*L,H=Me*Z/Qe*L;$.projectionMatrix.makePerspective(at,T,_,H,L,Qe),$.projectionMatrixInverse.copy($.projectionMatrix).invert()}}function ye($,X){X===null?$.matrixWorld.copy($.matrix):$.matrixWorld.multiplyMatrices(X.matrixWorld,$.matrix),$.matrixWorldInverse.copy($.matrixWorld).invert()}this.updateCamera=function($){if(s===null)return;let X=$.near,he=$.far;m.texture!==null&&(m.depthNear>0&&(X=m.depthNear),m.depthFar>0&&(he=m.depthFar)),W.near=U.near=P.near=X,W.far=U.far=P.far=he,(F!==W.near||V!==W.far)&&(s.updateRenderState({depthNear:W.near,depthFar:W.far}),F=W.near,V=W.far),W.layers.mask=$.layers.mask|6,P.layers.mask=W.layers.mask&-5,U.layers.mask=W.layers.mask&-3;let Te=$.parent,le=W.cameras;ye(W,Te);for(let Ie=0;Ie<le.length;Ie++)ye(le[Ie],Te);le.length===2?O(W,P,U):W.projectionMatrix.copy(P.projectionMatrix),w===null&&$.isPerspectiveCamera&&(w={camera:$,fov:$.fov,zoom:$.zoom}),Se($,W,Te)};function Se($,X,he){he===null?$.matrix.copy(X.matrixWorld):($.matrix.copy(he.matrixWorld),$.matrix.invert(),$.matrix.multiply(X.matrixWorld)),$.matrix.decompose($.position,$.quaternion,$.scale),$.updateMatrixWorld(!0),$.projectionMatrix.copy(X.projectionMatrix),$.projectionMatrixInverse.copy(X.projectionMatrixInverse),$.isPerspectiveCamera&&($.fov=$o*2*Math.atan(1/$.projectionMatrix.elements[5]),$.zoom=1)}this.getCamera=function(){return W},this.getFoveation=function(){if(!(u===null&&d===null))return l},this.setFoveation=function($){l=$,u!==null&&(u.fixedFoveation=$),d!==null&&d.fixedFoveation!==void 0&&(d.fixedFoveation=$)},this.hasDepthSensing=function(){return m.texture!==null},this.getDepthSensingMesh=function(){return m.getMesh(W)},this.getCameraTexture=function($){return p[$]};let be=null;function Ve($,X){if(h=X.getViewerPose(c||a),g=X,h!==null){let he=h.views;d!==null&&(e.setRenderTargetFramebuffer(v,d.framebuffer),e.setRenderTarget(v));let Te=!1;he.length!==W.cameras.length&&(W.cameras.length=0,Te=!0);for(let Z=0;Z<he.length;Z++){let ce=he[Z],Me=null;if(d!==null)Me=d.getViewport(ce);else{let xe=f.getViewSubImage(u,ce);Me=xe.viewport,Z===0&&(e.setRenderTargetTextures(v,xe.colorTexture,xe.depthStencilTexture),e.setRenderTarget(v))}let ge=B[Z];ge===void 0&&(ge=new mn,ge.layers.enable(Z),ge.viewport=new Gt,B[Z]=ge),ge.matrix.fromArray(ce.transform.matrix),ge.matrix.decompose(ge.position,ge.quaternion,ge.scale),ge.projectionMatrix.fromArray(ce.projectionMatrix),ge.projectionMatrixInverse.copy(ge.projectionMatrix).invert(),ge.viewport.set(Me.x,Me.y,Me.width,Me.height),Z===0&&(W.matrix.copy(ge.matrix),W.matrix.decompose(W.position,W.quaternion,W.scale)),Te===!0&&W.cameras.push(ge)}let le=s.enabledFeatures;if(le&&le.includes("depth-sensing")&&s.depthUsage=="gpu-optimized"&&x){f=n.getBinding();let Z=f.getDepthInformation(he[0]);Z&&Z.isValid&&Z.texture&&m.init(Z,s.renderState)}if(le&&le.includes("camera-access")&&x){e.state.unbindTexture(),f=n.getBinding();for(let Z=0;Z<he.length;Z++){let ce=he[Z].camera;if(ce){let Me=p[ce];Me||(Me=new aa,p[ce]=Me);let ge=f.getCameraImage(ce);Me.sourceTexture=ge}}}}for(let he=0;he<b.length;he++){let Te=E[he],le=b[he];Te!==null&&le!==void 0&&le.update(Te,X,c||a)}be&&be($,X),X.detectedPlanes&&n.dispatchEvent({type:"planesdetected",data:X}),g=null}let me=new hf;me.setAnimationLoop(Ve),this.setAnimationLoop=function($){be=$},this.dispose=function(){}}},O2=new Rt,gf=new dt;gf.set(-1,0,0,0,1,0,0,0,1);function B2(i,e){function t(m,p){m.matrixAutoUpdate===!0&&m.updateMatrix(),p.value.copy(m.matrix)}function n(m,p){p.color.getRGB(m.fogColor.value,L0(i)),p.isFog?(m.fogNear.value=p.near,m.fogFar.value=p.far):p.isFogExp2&&(m.fogDensity.value=p.density)}function s(m,p,S,A,v){p.isNodeMaterial?p.uniformsNeedUpdate=!1:p.isMeshBasicMaterial?r(m,p):p.isMeshLambertMaterial?(r(m,p),p.envMap&&(m.envMapIntensity.value=p.envMapIntensity)):p.isMeshToonMaterial?(r(m,p),f(m,p)):p.isMeshPhongMaterial?(r(m,p),h(m,p),p.envMap&&(m.envMapIntensity.value=p.envMapIntensity)):p.isMeshStandardMaterial?(r(m,p),u(m,p),p.isMeshPhysicalMaterial&&d(m,p,v)):p.isMeshMatcapMaterial?(r(m,p),g(m,p)):p.isMeshDepthMaterial?r(m,p):p.isMeshDistanceMaterial?(r(m,p),x(m,p)):p.isMeshNormalMaterial?r(m,p):p.isLineBasicMaterial?(a(m,p),p.isLineDashedMaterial&&o(m,p)):p.isPointsMaterial?l(m,p,S,A):p.isSpriteMaterial?c(m,p):p.isShadowMaterial?(m.color.value.copy(p.color),m.opacity.value=p.opacity):p.isShaderMaterial&&(p.uniformsNeedUpdate=!1)}function r(m,p){m.opacity.value=p.opacity,p.color&&m.diffuse.value.copy(p.color),p.emissive&&m.emissive.value.copy(p.emissive).multiplyScalar(p.emissiveIntensity),p.map&&(m.map.value=p.map,t(p.map,m.mapTransform)),p.alphaMap&&(m.alphaMap.value=p.alphaMap,t(p.alphaMap,m.alphaMapTransform)),p.bumpMap&&(m.bumpMap.value=p.bumpMap,t(p.bumpMap,m.bumpMapTransform),m.bumpScale.value=p.bumpScale,p.side===_n&&(m.bumpScale.value*=-1)),p.normalMap&&(m.normalMap.value=p.normalMap,t(p.normalMap,m.normalMapTransform),m.normalScale.value.copy(p.normalScale),p.side===_n&&m.normalScale.value.negate()),p.displacementMap&&(m.displacementMap.value=p.displacementMap,t(p.displacementMap,m.displacementMapTransform),m.displacementScale.value=p.displacementScale,m.displacementBias.value=p.displacementBias),p.emissiveMap&&(m.emissiveMap.value=p.emissiveMap,t(p.emissiveMap,m.emissiveMapTransform)),p.specularMap&&(m.specularMap.value=p.specularMap,t(p.specularMap,m.specularMapTransform)),p.alphaTest>0&&(m.alphaTest.value=p.alphaTest);let S=e.get(p),A=S.envMap,v=S.envMapRotation;A&&(m.envMap.value=A,m.envMapRotation.value.setFromMatrix4(O2.makeRotationFromEuler(v)).transpose(),A.isCubeTexture&&A.isRenderTargetTexture===!1&&m.envMapRotation.value.premultiply(gf),m.reflectivity.value=p.reflectivity,m.ior.value=p.ior,m.refractionRatio.value=p.refractionRatio),p.lightMap&&(m.lightMap.value=p.lightMap,m.lightMapIntensity.value=p.lightMapIntensity,t(p.lightMap,m.lightMapTransform)),p.aoMap&&(m.aoMap.value=p.aoMap,m.aoMapIntensity.value=p.aoMapIntensity,t(p.aoMap,m.aoMapTransform))}function a(m,p){m.diffuse.value.copy(p.color),m.opacity.value=p.opacity,p.map&&(m.map.value=p.map,t(p.map,m.mapTransform))}function o(m,p){m.dashSize.value=p.dashSize,m.totalSize.value=p.dashSize+p.gapSize,m.scale.value=p.scale}function l(m,p,S,A){m.diffuse.value.copy(p.color),m.opacity.value=p.opacity,m.size.value=p.size*S,m.scale.value=A*.5,p.map&&(m.map.value=p.map,t(p.map,m.uvTransform)),p.alphaMap&&(m.alphaMap.value=p.alphaMap,t(p.alphaMap,m.alphaMapTransform)),p.alphaTest>0&&(m.alphaTest.value=p.alphaTest)}function c(m,p){m.diffuse.value.copy(p.color),m.opacity.value=p.opacity,m.rotation.value=p.rotation,p.map&&(m.map.value=p.map,t(p.map,m.mapTransform)),p.alphaMap&&(m.alphaMap.value=p.alphaMap,t(p.alphaMap,m.alphaMapTransform)),p.alphaTest>0&&(m.alphaTest.value=p.alphaTest)}function h(m,p){m.specular.value.copy(p.specular),m.shininess.value=Math.max(p.shininess,1e-4)}function f(m,p){p.gradientMap&&(m.gradientMap.value=p.gradientMap)}function u(m,p){m.metalness.value=p.metalness,p.metalnessMap&&(m.metalnessMap.value=p.metalnessMap,t(p.metalnessMap,m.metalnessMapTransform)),m.roughness.value=p.roughness,p.roughnessMap&&(m.roughnessMap.value=p.roughnessMap,t(p.roughnessMap,m.roughnessMapTransform)),p.envMap&&(m.envMapIntensity.value=p.envMapIntensity)}function d(m,p,S){m.ior.value=p.ior,p.sheen>0&&(m.sheenColor.value.copy(p.sheenColor).multiplyScalar(p.sheen),m.sheenRoughness.value=p.sheenRoughness,p.sheenColorMap&&(m.sheenColorMap.value=p.sheenColorMap,t(p.sheenColorMap,m.sheenColorMapTransform)),p.sheenRoughnessMap&&(m.sheenRoughnessMap.value=p.sheenRoughnessMap,t(p.sheenRoughnessMap,m.sheenRoughnessMapTransform))),p.clearcoat>0&&(m.clearcoat.value=p.clearcoat,m.clearcoatRoughness.value=p.clearcoatRoughness,p.clearcoatMap&&(m.clearcoatMap.value=p.clearcoatMap,t(p.clearcoatMap,m.clearcoatMapTransform)),p.clearcoatRoughnessMap&&(m.clearcoatRoughnessMap.value=p.clearcoatRoughnessMap,t(p.clearcoatRoughnessMap,m.clearcoatRoughnessMapTransform)),p.clearcoatNormalMap&&(m.clearcoatNormalMap.value=p.clearcoatNormalMap,t(p.clearcoatNormalMap,m.clearcoatNormalMapTransform),m.clearcoatNormalScale.value.copy(p.clearcoatNormalScale),p.side===_n&&m.clearcoatNormalScale.value.negate())),p.dispersion>0&&(m.dispersion.value=p.dispersion),p.retroreflectivity>0&&(m.retroreflectivity.value=p.retroreflectivity),p.iridescence>0&&(m.iridescence.value=p.iridescence,m.iridescenceIOR.value=p.iridescenceIOR,m.iridescenceThicknessMinimum.value=p.iridescenceThicknessRange[0],m.iridescenceThicknessMaximum.value=p.iridescenceThicknessRange[1],p.iridescenceMap&&(m.iridescenceMap.value=p.iridescenceMap,t(p.iridescenceMap,m.iridescenceMapTransform)),p.iridescenceThicknessMap&&(m.iridescenceThicknessMap.value=p.iridescenceThicknessMap,t(p.iridescenceThicknessMap,m.iridescenceThicknessMapTransform))),p.transmission>0&&(m.transmission.value=p.transmission,m.transmissionSamplerMap.value=S.texture,m.transmissionSamplerSize.value.set(S.width,S.height),p.transmissionMap&&(m.transmissionMap.value=p.transmissionMap,t(p.transmissionMap,m.transmissionMapTransform)),m.thickness.value=p.thickness,p.thicknessMap&&(m.thicknessMap.value=p.thicknessMap,t(p.thicknessMap,m.thicknessMapTransform)),m.attenuationDistance.value=p.attenuationDistance,m.attenuationColor.value.copy(p.attenuationColor)),p.anisotropy>0&&(m.anisotropyVector.value.set(p.anisotropy*Math.cos(p.anisotropyRotation),p.anisotropy*Math.sin(p.anisotropyRotation)),p.anisotropyMap&&(m.anisotropyMap.value=p.anisotropyMap,t(p.anisotropyMap,m.anisotropyMapTransform))),m.specularIntensity.value=p.specularIntensity,m.specularColor.value.copy(p.specularColor),p.specularColorMap&&(m.specularColorMap.value=p.specularColorMap,t(p.specularColorMap,m.specularColorMapTransform)),p.specularIntensityMap&&(m.specularIntensityMap.value=p.specularIntensityMap,t(p.specularIntensityMap,m.specularIntensityMapTransform))}function g(m,p){p.matcap&&(m.matcap.value=p.matcap)}function x(m,p){let S=e.get(p).light;m.referencePosition.value.setFromMatrixPosition(S.matrixWorld),m.nearDistance.value=S.shadow.camera.near,m.farDistance.value=S.shadow.camera.far}return{refreshFogUniforms:n,refreshMaterialUniforms:s}}function z2(i,e,t,n){let s={},r={},a=[],o=i.getParameter(i.MAX_UNIFORM_BUFFER_BINDINGS);function l(v,b){let E=b.program;n.uniformBlockBinding(v,E)}function c(v,b){let E=s[v.id];E===void 0&&(m(v),E=h(v),s[v.id]=E,v.addEventListener("dispose",S));let C=b.program;n.updateUBOMapping(v,C);let y=e.render.frame;r[v.id]!==y&&(u(v),r[v.id]=y)}function h(v){let b=f();v.__bindingPointIndex=b;let E=i.createBuffer(),C=v.__size,y=v.usage;return i.bindBuffer(i.UNIFORM_BUFFER,E),i.bufferData(i.UNIFORM_BUFFER,C,y),i.bindBuffer(i.UNIFORM_BUFFER,null),i.bindBufferBase(i.UNIFORM_BUFFER,b,E),E}function f(){for(let v=0;v<o;v++)if(a.indexOf(v)===-1)return a.push(v),v;return lt("WebGLRenderer: Maximum number of simultaneously usable uniforms groups reached."),0}function u(v){let b=s[v.id],E=v.uniforms,C=v.__cache;i.bindBuffer(i.UNIFORM_BUFFER,b);for(let y=0,w=E.length;y<w;y++){let P=E[y];if(Array.isArray(P))for(let U=0,B=P.length;U<B;U++)d(P[U],y,U,C);else d(P,y,0,C)}i.bindBuffer(i.UNIFORM_BUFFER,null)}function d(v,b,E,C){if(x(v,b,E,C)===!0){let y=v.__offset,w=v.value;if(Array.isArray(w)){let P=0;for(let U=0;U<w.length;U++){let B=w[U],W=p(B);g(B,v.__data,P),typeof B!="number"&&typeof B!="boolean"&&!B.isMatrix3&&!ArrayBuffer.isView(B)&&(P+=W.storage/Float32Array.BYTES_PER_ELEMENT)}}else g(w,v.__data,0);i.bufferSubData(i.UNIFORM_BUFFER,y,v.__data)}}function g(v,b,E){typeof v=="number"||typeof v=="boolean"?b[0]=v:v.isMatrix3?(b[0]=v.elements[0],b[1]=v.elements[1],b[2]=v.elements[2],b[3]=0,b[4]=v.elements[3],b[5]=v.elements[4],b[6]=v.elements[5],b[7]=0,b[8]=v.elements[6],b[9]=v.elements[7],b[10]=v.elements[8],b[11]=0):ArrayBuffer.isView(v)?b.set(new v.constructor(v.buffer,v.byteOffset,b.length)):v.toArray(b,E)}function x(v,b,E,C){let y=v.value,w=b+"_"+E;if(C[w]===void 0)return typeof y=="number"||typeof y=="boolean"?C[w]=y:ArrayBuffer.isView(y)?C[w]=y.slice():C[w]=y.clone(),!0;{let P=C[w];if(typeof y=="number"||typeof y=="boolean"){if(P!==y)return C[w]=y,!0}else{if(ArrayBuffer.isView(y))return!0;if(P.equals(y)===!1)return P.copy(y),!0}}return!1}function m(v){let b=v.uniforms,E=0,C=16;for(let w=0,P=b.length;w<P;w++){let U=Array.isArray(b[w])?b[w]:[b[w]];for(let B=0,W=U.length;B<W;B++){let F=U[B],V=Array.isArray(F.value)?F.value:[F.value];for(let se=0,K=V.length;se<K;se++){let de=V[se],te=p(de),ae=E%C,O=ae%te.boundary,ye=ae+O;E+=O,ye!==0&&C-ye<te.storage&&(E+=C-ye),F.__data=new Float32Array(te.storage/Float32Array.BYTES_PER_ELEMENT),F.__offset=E,E+=te.storage}}}let y=E%C;return y>0&&(E+=C-y),v.__size=E,v.__cache={},this}function p(v){let b={boundary:0,storage:0};return typeof v=="number"||typeof v=="boolean"?(b.boundary=4,b.storage=4):v.isVector2?(b.boundary=8,b.storage=8):v.isVector3||v.isColor?(b.boundary=16,b.storage=12):v.isVector4?(b.boundary=16,b.storage=16):v.isMatrix3?(b.boundary=48,b.storage=48):v.isMatrix4?(b.boundary=64,b.storage=64):v.isTexture?ct("WebGLRenderer: Texture samplers can not be part of an uniforms group."):ArrayBuffer.isView(v)?(b.boundary=16,b.storage=v.byteLength):ct("WebGLRenderer: Unsupported uniform value type.",v),b}function S(v){let b=v.target;b.removeEventListener("dispose",S);let E=a.indexOf(b.__bindingPointIndex);a.splice(E,1),i.deleteBuffer(s[b.id]),delete s[b.id],delete r[b.id]}function A(){for(let v in s)i.deleteBuffer(s[v]);a=[],s={},r={}}return{bind:l,update:c,dispose:A}}var H2=new Uint16Array([12469,15057,12620,14925,13266,14620,13807,14376,14323,13990,14545,13625,14713,13328,14840,12882,14931,12528,14996,12233,15039,11829,15066,11525,15080,11295,15085,10976,15082,10705,15073,10495,13880,14564,13898,14542,13977,14430,14158,14124,14393,13732,14556,13410,14702,12996,14814,12596,14891,12291,14937,11834,14957,11489,14958,11194,14943,10803,14921,10506,14893,10278,14858,9960,14484,14039,14487,14025,14499,13941,14524,13740,14574,13468,14654,13106,14743,12678,14818,12344,14867,11893,14889,11509,14893,11180,14881,10751,14852,10428,14812,10128,14765,9754,14712,9466,14764,13480,14764,13475,14766,13440,14766,13347,14769,13070,14786,12713,14816,12387,14844,11957,14860,11549,14868,11215,14855,10751,14825,10403,14782,10044,14729,9651,14666,9352,14599,9029,14967,12835,14966,12831,14963,12804,14954,12723,14936,12564,14917,12347,14900,11958,14886,11569,14878,11247,14859,10765,14828,10401,14784,10011,14727,9600,14660,9289,14586,8893,14508,8533,15111,12234,15110,12234,15104,12216,15092,12156,15067,12010,15028,11776,14981,11500,14942,11205,14902,10752,14861,10393,14812,9991,14752,9570,14682,9252,14603,8808,14519,8445,14431,8145,15209,11449,15208,11451,15202,11451,15190,11438,15163,11384,15117,11274,15055,10979,14994,10648,14932,10343,14871,9936,14803,9532,14729,9218,14645,8742,14556,8381,14461,8020,14365,7603,15273,10603,15272,10607,15267,10619,15256,10631,15231,10614,15182,10535,15118,10389,15042,10167,14963,9787,14883,9447,14800,9115,14710,8665,14615,8318,14514,7911,14411,7507,14279,7198,15314,9675,15313,9683,15309,9712,15298,9759,15277,9797,15229,9773,15166,9668,15084,9487,14995,9274,14898,8910,14800,8539,14697,8234,14590,7790,14479,7409,14367,7067,14178,6621,15337,8619,15337,8631,15333,8677,15325,8769,15305,8871,15264,8940,15202,8909,15119,8775,15022,8565,14916,8328,14804,8009,14688,7614,14569,7287,14448,6888,14321,6483,14088,6171,15350,7402,15350,7419,15347,7480,15340,7613,15322,7804,15287,7973,15229,8057,15148,8012,15046,7846,14933,7611,14810,7357,14682,7069,14552,6656,14421,6316,14251,5948,14007,5528,15356,5942,15356,5977,15353,6119,15348,6294,15332,6551,15302,6824,15249,7044,15171,7122,15070,7050,14949,6861,14818,6611,14679,6349,14538,6067,14398,5651,14189,5311,13935,4958,15359,4123,15359,4153,15356,4296,15353,4646,15338,5160,15311,5508,15263,5829,15188,6042,15088,6094,14966,6001,14826,5796,14678,5543,14527,5287,14377,4985,14133,4586,13869,4257,15360,1563,15360,1642,15358,2076,15354,2636,15341,3350,15317,4019,15273,4429,15203,4732,15105,4911,14981,4932,14836,4818,14679,4621,14517,4386,14359,4156,14083,3795,13808,3437,15360,122,15360,137,15358,285,15355,636,15344,1274,15322,2177,15281,2765,15215,3223,15120,3451,14995,3569,14846,3567,14681,3466,14511,3305,14344,3121,14037,2800,13753,2467,15360,0,15360,1,15359,21,15355,89,15346,253,15325,479,15287,796,15225,1148,15133,1492,15008,1749,14856,1882,14685,1886,14506,1783,14324,1608,13996,1398,13702,1183]),vi=null;function k2(){return vi===null&&(vi=new na(H2,16,16,rs,sn),vi.name="DFG_LUT",vi.minFilter=gn,vi.magFilter=gn,vi.wrapS=ui,vi.wrapT=ui,vi.generateMipmaps=!1,vi.needsUpdate=!0),vi}var fc=class{constructor(e={}){let{canvas:t=Pu(),context:n=null,depth:s=!0,stencil:r=!1,alpha:a=!1,antialias:o=!1,premultipliedAlpha:l=!0,preserveDrawingBuffer:c=!1,powerPreference:h="default",failIfMajorPerformanceCaveat:f=!1,reversedDepthBuffer:u=!1,outputBufferType:d=Rn}=e;this.isWebGLRenderer=!0;let g;if(n!==null){if(typeof WebGLRenderingContext<"u"&&n instanceof WebGLRenderingContext)throw new Error("THREE.WebGLRenderer: WebGL 1 is not supported since r163.");g=n.getContextAttributes().alpha}else g=a;let x=d,m=new Set([Rl,Al,wl]),p=new Set([Rn,ei,vr,yr,bl,El]),S=new Uint32Array(4),A=new Int32Array(4),v=new I,b=null,E=null,C=[],y=[],w=null;this.domElement=t,this.debug={checkShaderErrors:!0,diagnostics:{keywords:!1},onShaderError:null},this.autoClear=!0,this.autoClearColor=!0,this.autoClearDepth=!0,this.autoClearStencil=!0,this.sortObjects=!0,this.clippingPlanes=[],this.localClippingEnabled=!1,this.toneMapping=Qn,this.toneMappingExposure=1,this.transmissionResolutionScale=1;let P=this,U=!1,B=null,W=null,F=null,V=null;this._outputColorSpace=Wt;let se=0,K=0,de=null,te=-1,ae=null,O=new Gt,ye=new Gt,Se=null,be=new it(0),Ve=0,me=t.width,$=t.height,X=1,he=null,Te=null,le=new Gt(0,0,me,$),Ie=new Gt(0,0,me,$),st=!1,Z=new rr,ce=!1,Me=!1,ge=new Rt,xe=new I,ke=new Gt,Le={background:null,fog:null,environment:null,overrideMaterial:null,isScene:!0},Je=!1;function tt(){return de===null?X:1}let L=n;function Qe(M,N){return t.getContext(M,N)}let at,T,_,H,G,ne,ve,Ae,ee,oe,Re,qe,Pe,pe,Ge,et,ht,D,Ce,re,we,Fe,_e;try{let M={alpha:!0,depth:s,stencil:r,antialias:o,premultipliedAlpha:l,preserveDrawingBuffer:c,powerPreference:h,failIfMajorPerformanceCaveat:f};if("setAttribute"in t&&t.setAttribute("data-engine",`three.js r${"186"}`),t.addEventListener("webglcontextlost",Bt,!1),t.addEventListener("webglcontextrestored",vt,!1),t.addEventListener("webglcontextcreationerror",Sn,!1),L===null){let N="webgl2";if(L=Qe(N,M),L===null)throw Qe(N)?new Error("THREE.WebGLRenderer: Error creating WebGL context with your selected attributes."):new Error("THREE.WebGLRenderer: Error creating WebGL context.")}Ke()}catch(M){throw t.removeEventListener("webglcontextlost",Bt,!1),t.removeEventListener("webglcontextrestored",vt,!1),t.removeEventListener("webglcontextcreationerror",Sn,!1),lt("WebGLRenderer: "+M.message),M}function Ke(){at=new $m(L),at.init(),we=new N2(L,at),T=new Bm(L,at,e,we),_=new L2(L,at),T.reversedDepthBuffer&&u&&_.buffers.depth.setReversed(!0),W=L.createFramebuffer(),F=L.createFramebuffer(),V=L.createFramebuffer(),H=new Km(L),G=new x2,ne=new D2(L,at,_,G,T,we,H),ve=new Ym(P),Ae=new Qd(L),Fe=new Fm(L,Ae),ee=new Zm(L,Ae,H,Fe),oe=new Qm(L,ee,Ae,Fe,H),D=new jm(L,T,ne),Ge=new zm(G),Re=new _2(P,ve,at,T,Fe,Ge),qe=new B2(P,G),Pe=new y2,pe=new w2(at),ht=new Um(P,ve,_,oe,g,l),et=new I2(P,oe,T),_e=new z2(L,H,T,_),Ce=new Om(L,at,H),re=new Jm(L,at,H),H.programs=Re.programs,P.capabilities=T,P.extensions=at,P.properties=G,P.renderLists=Pe,P.shadowMap=et,P.state=_,P.info=H}x!==Rn&&(w=new tg(x,t.width,t.height,o,s,r));let Ye=new J0(P,L);this.xr=Ye,this.getContext=function(){return L},this.getContextAttributes=function(){return L.getContextAttributes()},this.forceContextLoss=function(){let M=at.get("WEBGL_lose_context");M&&M.loseContext()},this.forceContextRestore=function(){let M=at.get("WEBGL_lose_context");M&&M.restoreContext()},this.getPixelRatio=function(){return X},this.setPixelRatio=function(M){M!==void 0&&(X=M,this.setSize(me,$,!1))},this.getSize=function(M){return M.set(me,$)},this.setSize=function(M,N,j=!0){if(Ye.isPresenting){ct("WebGLRenderer: Can't change size while VR device is presenting.");return}me=M,$=N,t.width=Math.floor(M*X),t.height=Math.floor(N*X),j===!0&&(t.style.width=M+"px",t.style.height=N+"px"),w!==null&&w.setSize(t.width,t.height),this.setViewport(0,0,M,N)},this.getDrawingBufferSize=function(M){return M.set(me*X,$*X).floor()},this.setDrawingBufferSize=function(M,N,j){me=M,$=N,X=j,t.width=Math.floor(M*j),t.height=Math.floor(N*j),this.setViewport(0,0,M,N)},this.setEffects=function(M){if(x===Rn){lt("WebGLRenderer: setEffects() requires outputBufferType set to HalfFloatType or FloatType.");return}if(M){for(let N=0;N<M.length;N++)if(M[N].isOutputPass===!0){ct("WebGLRenderer: OutputPass is not needed in setEffects(). Tone mapping and color space conversion are applied automatically.");break}}w.setEffects(M||[])},this.getCurrentViewport=function(M){return M.copy(O)},this.getViewport=function(M){return M.copy(le)},this.setViewport=function(M,N,j,q){M.isVector4?le.set(M.x,M.y,M.z,M.w):le.set(M,N,j,q),_.viewport(O.copy(le).multiplyScalar(X).round())},this.getScissor=function(M){return M.copy(Ie)},this.setScissor=function(M,N,j,q){M.isVector4?Ie.set(M.x,M.y,M.z,M.w):Ie.set(M,N,j,q),_.scissor(ye.copy(Ie).multiplyScalar(X).round())},this.getScissorTest=function(){return st},this.setScissorTest=function(M){_.setScissorTest(st=M)},this.setOpaqueSort=function(M){he=M},this.setTransparentSort=function(M){Te=M},this.getClearColor=function(M){return M.copy(ht.getClearColor())},this.setClearColor=function(){ht.setClearColor(...arguments)},this.getClearAlpha=function(){return ht.getClearAlpha()},this.setClearAlpha=function(){ht.setClearAlpha(...arguments)},this.clear=function(M=!0,N=!0,j=!0){let q=0;if(M){let Y=!1;if(de!==null){let Oe=de.texture.format;Y=m.has(Oe)}if(Y){let Oe=de.texture.type,We=p.has(Oe),Ne=ht.getClearColor(),$e=ht.getClearAlpha(),Ze=Ne.r,mt=Ne.g,_t=Ne.b;We?(S[0]=Ze,S[1]=mt,S[2]=_t,S[3]=$e,L.clearBufferuiv(L.COLOR,0,S)):(A[0]=Ze,A[1]=mt,A[2]=_t,A[3]=$e,L.clearBufferiv(L.COLOR,0,A))}else q|=L.COLOR_BUFFER_BIT}N&&(q|=L.DEPTH_BUFFER_BIT,this.state.buffers.depth.setMask(!0)),j&&(q|=L.STENCIL_BUFFER_BIT,this.state.buffers.stencil.setMask(4294967295)),q!==0&&L.clear(q)},this.clearColor=function(){this.clear(!0,!1,!1)},this.clearDepth=function(){this.clear(!1,!0,!1)},this.clearStencil=function(){this.clear(!1,!1,!0)},this.setNodesHandler=function(M){M.setRenderer(this),B=M},this.dispose=function(){t.removeEventListener("webglcontextlost",Bt,!1),t.removeEventListener("webglcontextrestored",vt,!1),t.removeEventListener("webglcontextcreationerror",Sn,!1),ht.dispose(),Pe.dispose(),pe.dispose(),G.dispose(),ve.dispose(),oe.dispose(),Fe.dispose(),_e.dispose(),Re.dispose(),Ye.dispose(),Ye.removeEventListener("sessionstart",eo),Ye.removeEventListener("sessionend",to),si.stop()};function Bt(M){M.preventDefault(),Zr("WebGLRenderer: Context Lost."),U=!0}function vt(){Zr("WebGLRenderer: Context Restored."),U=!1;let M=H.autoReset,N=et.enabled,j=et.autoUpdate,q=et.needsUpdate,Y=et.type;Ke(),H.autoReset=M,et.enabled=N,et.autoUpdate=j,et.needsUpdate=q,et.type=Y}function Sn(M){lt("WebGLRenderer: A WebGL context could not be created. Reason: ",M.statusMessage)}function ot(M){let N=M.target;N.removeEventListener("dispose",ot),ii(N)}function ii(M){ki(M),G.remove(M)}function ki(M){let N=G.get(M).programs;N!==void 0&&(N.forEach(function(j){Re.releaseProgram(j)}),M.isShaderMaterial&&Re.releaseShaderCache(M))}this.renderBufferDirect=function(M,N,j,q,Y,Oe){N===null&&(N=Le);let We=Y.isMesh&&Y.matrixWorld.determinantAffine()<0,Ne=Ec(M,N,j,q,Y);_.setMaterial(q,We);let $e=j.index,Ze=1;if(q.wireframe===!0){if($e=ee.getWireframeAttribute(j),$e===void 0)return;Ze=2}let mt=j.drawRange,_t=j.attributes.position,je=mt.start*Ze,Ct=(mt.start+mt.count)*Ze;Oe!==null&&(je=Math.max(je,Oe.start*Ze),Ct=Math.min(Ct,(Oe.start+Oe.count)*Ze)),$e!==null?(je=Math.max(je,0),Ct=Math.min(Ct,$e.count)):_t!=null&&(je=Math.max(je,0),Ct=Math.min(Ct,_t.count));let kt=Ct-je;if(kt<0||kt===1/0)return;Fe.setup(Y,q,Ne,j,$e);let Ot,It=Ce;if($e!==null&&(Ot=Ae.get($e),It=re,It.setIndex(Ot)),Y.isMesh)q.wireframe===!0?(_.setLineWidth(q.wireframeLinewidth*tt()),It.setMode(L.LINES)):It.setMode(L.TRIANGLES);else if(Y.isLine){let Jt=q.linewidth;Jt===void 0&&(Jt=1),_.setLineWidth(Jt*tt()),Y.isLineSegments?It.setMode(L.LINES):Y.isLineLoop?It.setMode(L.LINE_LOOP):It.setMode(L.LINE_STRIP)}else Y.isPoints?It.setMode(L.POINTS):Y.isSprite&&It.setMode(L.TRIANGLES);if(Y.isBatchedMesh)if(at.get("WEBGL_multi_draw"))It.renderMultiDraw(Y._multiDrawStarts,Y._multiDrawCounts,Y._multiDrawCount);else{let Jt=Y._multiDrawStarts,ze=Y._multiDrawCounts,Yt=Y._multiDrawCount,bt=$e?Ae.get($e).bytesPerElement:1,dn=G.get(q).currentProgram.getUniforms();for(let tn=0;tn<Yt;tn++)dn.setValue(L,"_gl_DrawID",tn),It.render(Jt[tn]/bt,ze[tn])}else if(Y.isInstancedMesh)It.renderInstances(je,kt,Y.count);else if(j.isInstancedBufferGeometry){let Jt=j._maxInstanceCount!==void 0?j._maxInstanceCount:1/0,ze=Math.min(j.instanceCount,Jt);It.renderInstances(je,kt,ze)}else It.render(je,kt)};function Un(M,N,j,q){B!==null&&M.isNodeMaterial&&B.setObject(q,M),ce===!0&&Ge.setState(M,j,!1),M.transparent===!0&&M.side===xn&&M.forceSinglePass===!1?(M.side=_n,M.needsUpdate=!0,cs(M,N,q),M.side=ts,M.needsUpdate=!0,cs(M,N,q),M.side=xn):cs(M,N,q)}this.compile=function(M,N,j=null){j===null&&(j=M),B!==null&&B.renderStart(M,N,j),E=pe.get(j),E.init(N),y.push(E),j.traverseVisible(function(Y){Y.isLight&&Y.layers.test(N.layers)&&(E.pushLight(Y),Y.castShadow&&E.pushShadow(Y))}),M!==j&&M.traverseVisible(function(Y){Y.isLight&&Y.layers.test(N.layers)&&(E.pushLight(Y),Y.castShadow&&E.pushShadow(Y))}),E.setupLights(),B!==null&&B.updateLights(E.state.lightsArray),Me=this.localClippingEnabled,ce=Ge.init(this.clippingPlanes,Me),ce===!0&&Ge.setGlobalState(this.clippingPlanes,N),B!==null&&et.render(E.state.shadowsArray,j,N);let q=new Set;return M.traverse(function(Y){if(!(Y.isMesh||Y.isPoints||Y.isLine||Y.isSprite))return;let Oe=Y.material;if(Oe)if(Array.isArray(Oe))for(let We=0;We<Oe.length;We++){let Ne=Oe[We];Un(Ne,j,N,Y),q.add(Ne)}else Un(Oe,j,N,Y),q.add(Oe)}),E=y.pop(),B!==null&&B.renderEnd(),q},this.compileAsync=function(M,N,j=null){let q=this.compile(M,N,j);return new Promise(Y=>{function Oe(){if(q.forEach(function(We){let $e=G.get(We).currentProgram;($e===void 0||$e.isReady())&&q.delete(We)}),q.size===0){Y(M);return}setTimeout(Oe,10)}at.get("KHR_parallel_shader_compile")!==null?Oe():setTimeout(Oe,10)})};let os=null;function Qa(M){os&&os(M)}function eo(){si.stop()}function to(){si.start()}let si=new hf;si.setAnimationLoop(Qa),typeof self<"u"&&si.setContext(self),this.setAnimationLoop=function(M){os=M,Ye.setAnimationLoop(M),M===null?si.stop():si.start()},Ye.addEventListener("sessionstart",eo),Ye.addEventListener("sessionend",to),this.render=function(M,N){if(N!==void 0&&N.isCamera!==!0){lt("WebGLRenderer.render: camera is not an instance of THREE.Camera.");return}if(U===!0)return;B!==null&&B.renderStart(M,N);let j=Ye.enabled===!0&&Ye.isPresenting===!0,q=w!==null&&(de===null||j)&&w.begin(P,de);if(M.matrixWorldAutoUpdate===!0&&M.updateMatrixWorld(),N.parent===null&&N.matrixWorldAutoUpdate===!0&&N.updateMatrixWorld(),Ye.enabled===!0&&Ye.isPresenting===!0&&(w===null||w.isCompositing()===!1)&&(Ye.cameraAutoUpdate===!0&&Ye.updateCamera(N),N=Ye.getCamera()),M.isScene===!0&&M.onBeforeRender(P,M,N,de),E=pe.get(M,y.length),E.init(N),E.state.textureUnits=ne.getTextureUnits(),y.push(E),ge.multiplyMatrices(N.projectionMatrix,N.matrixWorldInverse),Z.setFromProjectionMatrix(ge,Jn,N.reversedDepth),Me=this.localClippingEnabled,ce=Ge.init(this.clippingPlanes,Me),b=Pe.get(M,C.length),b.init(),C.push(b),Ye.enabled===!0&&Ye.isPresenting===!0){let We=P.xr.getDepthSensingMesh();We!==null&&Ts(We,N,-1/0,P.sortObjects)}Ts(M,N,0,P.sortObjects),b.finish(),B!==null&&B.updateLights(E.state.lightsArray),P.sortObjects===!0&&b.sort(he,Te),Je=Ye.enabled===!1||Ye.isPresenting===!1||Ye.hasDepthSensing()===!1,Je&&ht.addToRenderList(b,M),this.info.render.frame++,this.info.autoReset===!0&&this.info.reset(),ce===!0&&Ge.beginShadows();let Y=E.state.shadowsArray;if(et.render(Y,M,N),ce===!0&&Ge.endShadows(),(q&&w.hasRenderPass())===!1){let We=b.opaque,Ne=b.transmissive;if(E.setupLights(),N.isArrayCamera){let $e=N.cameras;if(Ne.length>0)for(let Ze=0,mt=$e.length;Ze<mt;Ze++){let _t=$e[Ze];ri(We,Ne,M,_t)}Je&&ht.render(M);for(let Ze=0,mt=$e.length;Ze<mt;Ze++){let _t=$e[Ze];Cr(b,M,_t,_t.viewport)}}else Ne.length>0&&ri(We,Ne,M,N),Je&&ht.render(M),Cr(b,M,N)}de!==null&&K===0&&(ne.updateMultisampleRenderTarget(de),ne.updateRenderTargetMipmap(de)),q&&w.end(P),M.isScene===!0&&M.onAfterRender(P,M,N),Fe.resetDefaultState(),te=-1,ae=null,y.pop(),y.length>0?(E=y[y.length-1],ne.setTextureUnits(E.state.textureUnits),ce===!0&&Ge.setGlobalState(P.clippingPlanes,E.state.camera)):E=null,C.pop(),C.length>0?b=C[C.length-1]:b=null,B!==null&&B.renderEnd()};function Ts(M,N,j,q){if(M.visible===!1)return;if(M.layers.test(N.layers)){if(M.isGroup)j=M.renderOrder;else if(M.isLOD)M.autoUpdate===!0&&M.update(N);else if(M.isLightProbeGrid)E.pushLightProbeGrid(M);else if(M.isLight)E.pushLight(M),M.castShadow&&E.pushShadow(M);else if(M.isSprite){if(!M.frustumCulled||M.intersectsFrustum(Z)){q&&ke.setFromMatrixPosition(M.matrixWorld).applyMatrix4(ge);let We=oe.update(M),Ne=M.material;Ne.visible&&b.push(M,We,Ne,j,ke.z,null,N)}}else if((M.isMesh||M.isLine||M.isPoints)&&(!M.frustumCulled||M.intersectsFrustum(Z))){let We=oe.update(M),Ne=M.material;if(q&&(M.boundingSphere!==void 0?(M.boundingSphere===null&&M.computeBoundingSphere(),ke.copy(M.boundingSphere.center)):(We.boundingSphere===null&&We.computeBoundingSphere(),ke.copy(We.boundingSphere.center)),ke.applyMatrix4(M.matrixWorld).applyMatrix4(ge)),Array.isArray(Ne)){let $e=We.groups;for(let Ze=0,mt=$e.length;Ze<mt;Ze++){let _t=$e[Ze],je=Ne[_t.materialIndex];je&&je.visible&&b.push(M,We,je,j,ke.z,_t,N)}}else Ne.visible&&b.push(M,We,Ne,j,ke.z,null,N)}}let Oe=M.children;for(let We=0,Ne=Oe.length;We<Ne;We++)Ts(Oe[We],N,j,q)}function Cr(M,N,j,q){let{opaque:Y,transmissive:Oe,transparent:We}=M;E.setupLightsView(j),ce===!0&&Ge.setGlobalState(P.clippingPlanes,j),q&&_.viewport(O.copy(q)),Y.length>0&&ls(Y,N,j),Oe.length>0&&ls(Oe,N,j),We.length>0&&ls(We,N,j),_.buffers.depth.setTest(!0),_.buffers.depth.setMask(!0),_.buffers.color.setMask(!0),_.setPolygonOffset(!1)}function ri(M,N,j,q){if((j.isScene===!0?j.overrideMaterial:null)!==null)return;if(E.state.transmissionRenderTarget[q.id]===void 0){let je=at.has("EXT_color_buffer_half_float")||at.has("EXT_color_buffer_float");E.state.transmissionRenderTarget[q.id]=new $t(1,1,{generateMipmaps:!0,type:je?sn:Rn,minFilter:xi,samples:Math.max(4,T.samples),stencilBuffer:r,resolveDepthBuffer:!1,resolveStencilBuffer:!1,storeMultisampledDepthBuffer:!1,storeMultisampledStencilBuffer:!1,colorSpace:St.workingColorSpace})}let Oe=E.state.transmissionRenderTarget[q.id],We=q.viewport||O;Oe.setSize(We.z*P.transmissionResolutionScale,We.w*P.transmissionResolutionScale);let Ne=P.getRenderTarget(),$e=P.getActiveCubeFace(),Ze=P.getActiveMipmapLevel();P.setRenderTarget(Oe),P.getClearColor(be),Ve=P.getClearAlpha(),Ve<1&&P.setClearColor(16777215,.5),P.clear(),Je&&ht.render(j);let mt=P.toneMapping;P.toneMapping=Qn;let _t=q.viewport;if(q.viewport!==void 0&&(q.viewport=void 0),E.setupLightsView(q),ce===!0&&Ge.setGlobalState(P.clippingPlanes,q),ls(M,j,q),ne.updateMultisampleRenderTarget(Oe),ne.updateRenderTargetMipmap(Oe),at.has("WEBGL_multisampled_render_to_texture")===!1){let je=!1;for(let Ct=0,kt=N.length;Ct<kt;Ct++){let Ot=N[Ct],{object:It,geometry:Jt,material:ze,group:Yt}=Ot;if(ze.side===xn&&It.layers.test(q.layers)){let bt=ze.side;ze.side=_n,ze.needsUpdate=!0,Pr(It,j,q,Jt,ze,Yt),ze.side=bt,ze.needsUpdate=!0,je=!0}}je===!0&&(ne.updateMultisampleRenderTarget(Oe),ne.updateRenderTargetMipmap(Oe))}P.setRenderTarget(Ne,$e,Ze),P.setClearColor(be,Ve),_t!==void 0&&(q.viewport=_t),P.toneMapping=mt}function ls(M,N,j){let q=N.isScene===!0?N.overrideMaterial:null;for(let Y=0,Oe=M.length;Y<Oe;Y++){let We=M[Y],{object:Ne,geometry:$e,group:Ze}=We,mt=We.material;mt.allowOverride===!0&&q!==null&&(mt=q),Ne.layers.test(j.layers)&&Pr(Ne,N,j,$e,mt,Ze)}}function Pr(M,N,j,q,Y,Oe){B!==null&&Y.isNodeMaterial&&B.setObject(M,Y),M.onBeforeRender(P,N,j,q,Y,Oe),M.modelViewMatrix.multiplyMatrices(j.matrixWorldInverse,M.matrixWorld),M.normalMatrix.getNormalMatrix(M.modelViewMatrix),Y.onBeforeRender(P,N,j,q,M,Oe),Y.transparent===!0&&Y.side===xn&&Y.forceSinglePass===!1?(Y.side=_n,Y.needsUpdate=!0,P.renderBufferDirect(j,N,q,Y,M,Oe),Y.side=ts,Y.needsUpdate=!0,P.renderBufferDirect(j,N,q,Y,M,Oe),Y.side=xn):P.renderBufferDirect(j,N,q,Y,M,Oe),M.onAfterRender(P,N,j,q,Y,Oe)}function cs(M,N,j){N.isScene!==!0&&(N=Le);let q=G.get(M),Y=E.state.lights,Oe=E.state.shadowsArray,We=Y.state.version,Ne=Re.getParameters(M,Y.state,Oe,N,j,E.state.lightProbeGridArray),$e=Re.getProgramCacheKey(Ne),Ze=q.programs;q.environment=M.isMeshStandardMaterial||M.isMeshLambertMaterial||M.isMeshPhongMaterial?N.environment:null,q.fog=N.fog;let mt=M.isMeshStandardMaterial||M.isMeshLambertMaterial&&!M.envMap||M.isMeshPhongMaterial&&!M.envMap;q.envMap=ve.get(M.envMap||q.environment,mt),q.envMapRotation=q.environment!==null&&M.envMap===null?N.environmentRotation:M.envMapRotation,Ze===void 0&&(M.addEventListener("dispose",ot),Ze=new Map,q.programs=Ze);let _t=Ze.get($e);if(_t!==void 0){if(q.currentProgram===_t&&q.lightsStateVersion===We)return no(M,Ne),_t}else Ne.uniforms=Re.getUniforms(M),B!==null&&M.isNodeMaterial&&B.build(M,j,Ne),M.onBeforeCompile(Ne,P),_t=Re.acquireProgram(Ne,$e),Ze.set($e,_t),q.uniforms=Ne.uniforms;let je=q.uniforms;return(!M.isShaderMaterial&&!M.isRawShaderMaterial||M.clipping===!0)&&(je.clippingPlanes=Ge.uniform),no(M,Ne),q.needsLights=Ir(M),q.lightsStateVersion=We,q.needsLights&&(je.ambientLightColor.value=Y.state.ambient,je.lightProbe.value=Y.state.probe,je.sunLights.value=Y.state.sun,je.sunLightShadows.value=Y.state.sunShadow,je.directionalLights.value=Y.state.directional,je.directionalLightShadows.value=Y.state.directionalShadow,je.spotLights.value=Y.state.spot,je.spotLightShadows.value=Y.state.spotShadow,je.rectAreaLights.value=Y.state.rectArea,je.ltc_1.value=Y.state.rectAreaLTC1,je.ltc_2.value=Y.state.rectAreaLTC2,je.pointLights.value=Y.state.point,je.pointLightShadows.value=Y.state.pointShadow,je.hemisphereLights.value=Y.state.hemi,je.sunShadowMatrix.value=Y.state.sunShadowMatrix,je.sunShadowCascade.value=Y.state.sunShadowCascade,je.directionalShadowMatrix.value=Y.state.directionalShadowMatrix,je.spotLightMatrix.value=Y.state.spotLightMatrix,je.spotLightMap.value=Y.state.spotLightMap,je.pointShadowMatrix.value=Y.state.pointShadowMatrix),q.lightProbeGrid=E.state.lightProbeGridArray.length>0,q.currentProgram=_t,q.uniformsList=null,_t}function hs(M){if(M.uniformsList===null){let N=M.currentProgram.getUniforms();M.uniformsList=br.seqWithValue(N.seq,M.uniforms)}return M.uniformsList}function no(M,N){let j=G.get(M);j.outputColorSpace=N.outputColorSpace,j.batching=N.batching,j.batchingColor=N.batchingColor,j.instancing=N.instancing,j.instancingColor=N.instancingColor,j.instancingMorph=N.instancingMorph,j.skinning=N.skinning,j.morphTargets=N.morphTargets,j.morphNormals=N.morphNormals,j.morphColors=N.morphColors,j.morphTargetsCount=N.morphTargetsCount,j.numClippingPlanes=N.numClippingPlanes,j.numIntersection=N.numClipIntersection,j.vertexAlphas=N.vertexAlphas,j.vertexTangents=N.vertexTangents,j.toneMapping=N.toneMapping}function bc(M,N){if(M.length===0)return null;if(M.length===1)return M[0].texture!==null?M[0]:null;v.setFromMatrixPosition(N.matrixWorld);for(let j=0,q=M.length;j<q;j++){let Y=M[j];if(Y.texture!==null&&Y.boundingBox.containsPoint(v))return Y}return null}function Ec(M,N,j,q,Y){N.isScene!==!0&&(N=Le),ne.resetTextureUnits();let Oe=N.fog,We=q.isMeshStandardMaterial||q.isMeshLambertMaterial||q.isMeshPhongMaterial?N.environment:null,Ne=de===null?P.outputColorSpace:de.isXRRenderTarget===!0?de.texture.colorSpace:St.workingColorSpace,$e=q.isMeshStandardMaterial||q.isMeshLambertMaterial&&!q.envMap||q.isMeshPhongMaterial&&!q.envMap,Ze=ve.get(q.envMap||We,$e),mt=q.vertexColors===!0&&!!j.attributes.color&&j.attributes.color.itemSize===4,_t=!!j.attributes.tangent&&(!!q.normalMap||q.anisotropy>0),je=!!j.morphAttributes.position,Ct=!!j.morphAttributes.normal,kt=!!j.morphAttributes.color,Ot=Qn;q.toneMapped&&(de===null||de.isXRRenderTarget===!0)&&(Ot=P.toneMapping);let It=j.morphAttributes.position||j.morphAttributes.normal||j.morphAttributes.color,Jt=It!==void 0?It.length:0,ze=G.get(q),Yt=E.state.lights;if(ce===!0&&(Me===!0||M!==ae)){let Dt=M===ae&&q.id===te;Ge.setState(q,M,Dt)}let bt=!1;q.version===ze.__version?(ze.needsLights&&ze.lightsStateVersion!==Yt.state.version||ze.outputColorSpace!==Ne||Y.isBatchedMesh&&ze.batching===!1||!Y.isBatchedMesh&&ze.batching===!0||Y.isBatchedMesh&&ze.batchingColor===!0&&Y._colorsTexture===null||Y.isBatchedMesh&&ze.batchingColor===!1&&Y._colorsTexture!==null||Y.isInstancedMesh&&ze.instancing===!1||!Y.isInstancedMesh&&ze.instancing===!0||Y.isSkinnedMesh&&ze.skinning===!1||!Y.isSkinnedMesh&&ze.skinning===!0||Y.isInstancedMesh&&ze.instancingColor===!0&&Y.instanceColor===null||Y.isInstancedMesh&&ze.instancingColor===!1&&Y.instanceColor!==null||Y.isInstancedMesh&&ze.instancingMorph===!0&&Y.morphTexture===null||Y.isInstancedMesh&&ze.instancingMorph===!1&&Y.morphTexture!==null||ze.envMap!==Ze||q.fog===!0&&ze.fog!==Oe||ze.numClippingPlanes!==void 0&&(ze.numClippingPlanes!==Ge.numPlanes||ze.numIntersection!==Ge.numIntersection)||ze.vertexAlphas!==mt||ze.vertexTangents!==_t||ze.morphTargets!==je||ze.morphNormals!==Ct||ze.morphColors!==kt||ze.toneMapping!==Ot||ze.morphTargetsCount!==Jt||!!ze.lightProbeGrid!=E.state.lightProbeGridArray.length>0)&&(bt=!0):(bt=!0,ze.__version=q.version);let dn=ze.currentProgram;bt===!0&&(dn=cs(q,N,Y),B&&q.isNodeMaterial&&B.onUpdateProgram(q,dn,ze));let tn=!1,on=!1,Si=!1,Lt=dn.getUniforms(),At=ze.uniforms;if(_.useProgram(dn.program)&&(tn=!0,on=!0,Si=!0),q.id!==te&&(te=q.id,on=!0),ze.needsLights){let Dt=bc(E.state.lightProbeGridArray,Y);ze.lightProbeGrid!==Dt&&(ze.lightProbeGrid=Dt,on=!0)}if(tn||ae!==M){_.buffers.depth.getReversed()&&M.reversedDepth!==!0&&(M._reversedDepth=!0,M.updateProjectionMatrix()),Lt.setValue(L,"projectionMatrix",M.projectionMatrix),Lt.setValue(L,"viewMatrix",M.matrixWorldInverse);let wn=Lt.map.cameraPosition;wn!==void 0&&wn.setValue(L,xe.setFromMatrixPosition(M.matrixWorld)),T.logarithmicDepthBuffer&&Lt.setValue(L,"logDepthBufFC",2/(Math.log(M.far+1)/Math.LN2)),(q.isMeshPhongMaterial||q.isMeshToonMaterial||q.isMeshLambertMaterial||q.isMeshBasicMaterial||q.isMeshStandardMaterial||q.isShaderMaterial)&&Lt.setValue(L,"isOrthographic",M.isOrthographicCamera===!0),ae!==M&&(ae=M,on=!0,Si=!0)}if(ze.needsLights&&(Yt.state.sunShadowMap.length>0&&Lt.setValue(L,"sunShadowMap",Yt.state.sunShadowMap,ne),Yt.state.directionalShadowMap.length>0&&Lt.setValue(L,"directionalShadowMap",Yt.state.directionalShadowMap,ne),Yt.state.spotShadowMap.length>0&&Lt.setValue(L,"spotShadowMap",Yt.state.spotShadowMap,ne),Yt.state.pointShadowMap.length>0&&Lt.setValue(L,"pointShadowMap",Yt.state.pointShadowMap,ne)),Y.isSkinnedMesh){Lt.setOptional(L,Y,"bindMatrix"),Lt.setOptional(L,Y,"bindMatrixInverse");let Dt=Y.skeleton;Dt&&(Dt.boneTexture===null&&Dt.computeBoneTexture(),Lt.setValue(L,"boneTexture",Dt.boneTexture,ne))}Y.isBatchedMesh&&(Lt.setOptional(L,Y,"batchingTexture"),Lt.setValue(L,"batchingTexture",Y._matricesTexture,ne),Lt.setOptional(L,Y,"batchingIdTexture"),Lt.setValue(L,"batchingIdTexture",Y._indirectTexture,ne),Lt.setOptional(L,Y,"batchingColorTexture"),Y._colorsTexture!==null&&Lt.setValue(L,"batchingColorTexture",Y._colorsTexture,ne));let bn=j.morphAttributes;if((bn.position!==void 0||bn.normal!==void 0||bn.color!==void 0)&&D.update(Y,j,dn),(on||ze.receiveShadow!==Y.receiveShadow)&&(ze.receiveShadow=Y.receiveShadow,Lt.setValue(L,"receiveShadow",Y.receiveShadow)),(q.isMeshStandardMaterial||q.isMeshLambertMaterial||q.isMeshPhongMaterial)&&q.envMap===null&&N.environment!==null&&(At.envMapIntensity.value=N.environmentIntensity),At.dfgLUT!==void 0&&(At.dfgLUT.value=k2()),on){if(Lt.setValue(L,"toneMappingExposure",P.toneMappingExposure),ze.needsLights&&Tc(At,Si),Oe&&q.fog===!0&&qe.refreshFogUniforms(At,Oe),qe.refreshMaterialUniforms(At,q,X,$,E.state.transmissionRenderTarget[M.id]),ze.needsLights&&ze.lightProbeGrid){let Dt=ze.lightProbeGrid;At.probesSH.value=Dt.texture,At.probesMin.value.copy(Dt.boundingBox.min),At.probesMax.value.copy(Dt.boundingBox.max),At.probesResolution.value.copy(Dt.resolution)}br.upload(L,hs(ze),At,ne)}if(q.isShaderMaterial&&q.uniformsNeedUpdate===!0&&(br.upload(L,hs(ze),At,ne),q.uniformsNeedUpdate=!1),q.isSpriteMaterial&&Lt.setValue(L,"center",Y.center),Lt.setValue(L,"modelViewMatrix",Y.modelViewMatrix),Lt.setValue(L,"normalMatrix",Y.normalMatrix),Lt.setValue(L,"modelMatrix",Y.matrixWorld),q.uniformsGroups!==void 0){let Dt=q.uniformsGroups;for(let wn=0,ai=Dt.length;wn<ai;wn++){let bi=Dt[wn];_e.update(bi,dn),_e.bind(bi,dn)}}return dn}function Tc(M,N){M.ambientLightColor.needsUpdate=N,M.lightProbe.needsUpdate=N,M.sunLights.needsUpdate=N,M.sunLightShadows.needsUpdate=N,M.directionalLights.needsUpdate=N,M.directionalLightShadows.needsUpdate=N,M.pointLights.needsUpdate=N,M.pointLightShadows.needsUpdate=N,M.spotLights.needsUpdate=N,M.spotLightShadows.needsUpdate=N,M.rectAreaLights.needsUpdate=N,M.hemisphereLights.needsUpdate=N}function Ir(M){return M.isMeshLambertMaterial||M.isMeshToonMaterial||M.isMeshPhongMaterial||M.isMeshStandardMaterial||M.isShadowMaterial||M.isShaderMaterial&&M.lights===!0}this.getActiveCubeFace=function(){return se},this.getActiveMipmapLevel=function(){return K},this.getRenderTarget=function(){return de},this.setRenderTargetTextures=function(M,N,j){let q=G.get(M);q.__autoAllocateDepthBuffer=M.resolveDepthBuffer===!1,q.__autoAllocateDepthBuffer===!1&&(q.__useRenderToTexture=!1),G.get(M.texture).__webglTexture=N,G.get(M.depthTexture).__webglTexture=q.__autoAllocateDepthBuffer?void 0:j,q.__hasExternalTextures=!0},this.setRenderTargetFramebuffer=function(M,N){let j=G.get(M);j.__webglFramebuffer=N,j.__useDefaultFramebuffer=N===void 0},this.setRenderTarget=function(M,N=0,j=0){de=M,se=N,K=j;let q=null,Y=!1,Oe=!1;if(M){let Ne=G.get(M);if(Ne.__useDefaultFramebuffer!==void 0){_.bindFramebuffer(L.FRAMEBUFFER,Ne.__webglFramebuffer),O.copy(M.viewport),ye.copy(M.scissor),Se=M.scissorTest,_.viewport(O),_.scissor(ye),_.setScissorTest(Se),te=-1;return}else if(Ne.__webglFramebuffer===void 0)ne.setupRenderTarget(M);else if(Ne.__hasExternalTextures)ne.rebindTextures(M,G.get(M.texture).__webglTexture,G.get(M.depthTexture).__webglTexture);else if(M.depthBuffer){let mt=M.depthTexture;if(Ne.__boundDepthTexture!==mt){if(mt!==null&&G.has(mt)&&(M.width!==mt.image.width||M.height!==mt.image.height))throw new Error("THREE.WebGLRenderer: Attached DepthTexture is initialized to the incorrect size.");ne.setupDepthRenderbuffer(M)}}let $e=M.texture;($e.isData3DTexture||$e.isDataArrayTexture||$e.isCompressedArrayTexture)&&(Oe=!0);let Ze=G.get(M).__webglFramebuffer;M.isWebGLCubeRenderTarget?(Array.isArray(Ze[N])?q=Ze[N][j]:q=Ze[N],Y=!0):M.samples>0&&ne.useMultisampledRTT(M)===!1?q=G.get(M).__webglMultisampledFramebuffer:Array.isArray(Ze)?q=Ze[j]:q=Ze,O.copy(M.viewport),ye.copy(M.scissor),Se=M.scissorTest}else O.copy(le).multiplyScalar(X).floor(),ye.copy(Ie).multiplyScalar(X).floor(),Se=st;if(j!==0&&(q=W),_.bindFramebuffer(L.FRAMEBUFFER,q)&&_.drawBuffers(M,q),_.viewport(O),_.scissor(ye),_.setScissorTest(Se),Y){let Ne=G.get(M.texture);L.framebufferTexture2D(L.FRAMEBUFFER,L.COLOR_ATTACHMENT0,L.TEXTURE_CUBE_MAP_POSITIVE_X+N,Ne.__webglTexture,j)}else if(Oe){let Ne=N;for(let $e=0;$e<M.textures.length;$e++){let Ze=G.get(M.textures[$e]);L.framebufferTextureLayer(L.FRAMEBUFFER,L.COLOR_ATTACHMENT0+$e,Ze.__webglTexture,j,Ne)}}else if(M!==null&&j!==0){let Ne=G.get(M.texture);L.framebufferTexture2D(L.FRAMEBUFFER,L.COLOR_ATTACHMENT0,L.TEXTURE_2D,Ne.__webglTexture,j)}te=-1};function Mi(M){let N=G.get(M);return(N.__readFormat!==M.format||N.__readType!==M.type)&&(N.__readFormat=M.format,N.__readType=M.type,N.__formatReadable=T.textureFormatReadable(M.format),N.__typeReadable=T.textureTypeReadable(M.type)),N}this.readRenderTargetPixels=function(M,N,j,q,Y,Oe,We,Ne=0){if(!(M&&M.isWebGLRenderTarget)){lt("WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");return}let $e=G.get(M).__webglFramebuffer;if(M.isWebGLCubeRenderTarget&&We!==void 0&&($e=$e[We]),$e){_.bindFramebuffer(L.FRAMEBUFFER,$e);try{let Ze=M.textures[Ne],mt=Ze.format,_t=Ze.type;M.textures.length>1&&L.readBuffer(L.COLOR_ATTACHMENT0+Ne);let je=Mi(Ze);if(je.__formatReadable===!1){lt("WebGLRenderer.readRenderTargetPixels: renderTarget is not in RGBA or implementation defined format.");return}if(je.__typeReadable===!1){lt("WebGLRenderer.readRenderTargetPixels: renderTarget is not in UnsignedByteType or implementation defined type.");return}N>=0&&N<=M.width-q&&j>=0&&j<=M.height-Y&&L.readPixels(N,j,q,Y,we.convert(mt),we.convert(_t),Oe)}finally{let Ze=de!==null?G.get(de).__webglFramebuffer:null;_.bindFramebuffer(L.FRAMEBUFFER,Ze)}}},this.readRenderTargetPixelsAsync=async function(M,N,j,q,Y,Oe,We,Ne=0){if(!(M&&M.isWebGLRenderTarget))throw new Error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");let $e=G.get(M).__webglFramebuffer;if(M.isWebGLCubeRenderTarget&&We!==void 0&&($e=$e[We]),$e)if(N>=0&&N<=M.width-q&&j>=0&&j<=M.height-Y){_.bindFramebuffer(L.FRAMEBUFFER,$e);let Ze=M.textures[Ne],mt=Ze.format,_t=Ze.type;M.textures.length>1&&L.readBuffer(L.COLOR_ATTACHMENT0+Ne);let je=Mi(Ze);if(je.__formatReadable===!1)throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in RGBA or implementation defined format.");if(je.__typeReadable===!1)throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in UnsignedByteType or implementation defined type.");let Ct=L.createBuffer();L.bindBuffer(L.PIXEL_PACK_BUFFER,Ct),L.bufferData(L.PIXEL_PACK_BUFFER,Oe.byteLength,L.STREAM_READ),L.readPixels(N,j,q,Y,we.convert(mt),we.convert(_t),0),L.bindBuffer(L.PIXEL_PACK_BUFFER,null);let kt=de!==null?G.get(de).__webglFramebuffer:null;_.bindFramebuffer(L.FRAMEBUFFER,kt);let Ot=L.fenceSync(L.SYNC_GPU_COMMANDS_COMPLETE,0);return L.flush(),await Lu(L,Ot,4),L.bindBuffer(L.PIXEL_PACK_BUFFER,Ct),L.getBufferSubData(L.PIXEL_PACK_BUFFER,0,Oe),L.bindBuffer(L.PIXEL_PACK_BUFFER,null),L.deleteBuffer(Ct),L.deleteSync(Ot),Oe}else throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: requested read bounds are out of range.")},this.copyFramebufferToTexture=function(M,N=null,j=0){let q=Math.pow(2,-j),Y=Math.floor(M.image.width*q),Oe=Math.floor(M.image.height*q),We=N!==null?N.x:0,Ne=N!==null?N.y:0;ne.setTexture2D(M,0),L.copyTexSubImage2D(L.TEXTURE_2D,j,0,0,We,Ne,Y,Oe),_.unbindTexture()},this.copyTextureToTexture=function(M,N,j=null,q=null,Y=0,Oe=0){let We,Ne,$e,Ze,mt,_t,je,Ct,kt,Ot=M.isCompressedTexture?M.mipmaps[Oe]:M.image;if(j!==null)We=j.max.x-j.min.x,Ne=j.max.y-j.min.y,$e=j.isBox3?j.max.z-j.min.z:1,Ze=j.min.x,mt=j.min.y,_t=j.isBox3?j.min.z:0;else{let At=Math.pow(2,-Y);We=Math.floor(Ot.width*At),Ne=Math.floor(Ot.height*At),M.isDataArrayTexture?$e=Ot.depth:M.isData3DTexture?$e=Math.floor(Ot.depth*At):$e=1,Ze=0,mt=0,_t=0}q!==null?(je=q.x,Ct=q.y,kt=q.z):(je=0,Ct=0,kt=0);let It=we.convert(N.format),Jt=we.convert(N.type),ze;N.isData3DTexture?(ne.setTexture3D(N,0),ze=L.TEXTURE_3D):N.isDataArrayTexture||N.isCompressedArrayTexture?(ne.setTexture2DArray(N,0),ze=L.TEXTURE_2D_ARRAY):(ne.setTexture2D(N,0),ze=L.TEXTURE_2D),_.activeTexture(L.TEXTURE0),_.pixelStorei(L.UNPACK_FLIP_Y_WEBGL,N.flipY),_.pixelStorei(L.UNPACK_PREMULTIPLY_ALPHA_WEBGL,N.premultiplyAlpha),_.pixelStorei(L.UNPACK_ALIGNMENT,N.unpackAlignment);let Yt=_.getParameter(L.UNPACK_ROW_LENGTH),bt=_.getParameter(L.UNPACK_IMAGE_HEIGHT),dn=_.getParameter(L.UNPACK_SKIP_PIXELS),tn=_.getParameter(L.UNPACK_SKIP_ROWS),on=_.getParameter(L.UNPACK_SKIP_IMAGES);_.pixelStorei(L.UNPACK_ROW_LENGTH,Ot.width),_.pixelStorei(L.UNPACK_IMAGE_HEIGHT,Ot.height),_.pixelStorei(L.UNPACK_SKIP_PIXELS,Ze),_.pixelStorei(L.UNPACK_SKIP_ROWS,mt),_.pixelStorei(L.UNPACK_SKIP_IMAGES,_t);let Si=M.isDataArrayTexture||M.isData3DTexture,Lt=N.isDataArrayTexture||N.isData3DTexture;if(M.isDepthTexture){let At=G.get(M),bn=G.get(N),Dt=G.get(At.__renderTarget),wn=G.get(bn.__renderTarget);_.bindFramebuffer(L.READ_FRAMEBUFFER,Dt.__webglFramebuffer),_.bindFramebuffer(L.DRAW_FRAMEBUFFER,wn.__webglFramebuffer);for(let ai=0;ai<$e;ai++)Si&&(L.framebufferTextureLayer(L.READ_FRAMEBUFFER,L.COLOR_ATTACHMENT0,G.get(M).__webglTexture,Y,_t+ai),L.framebufferTextureLayer(L.DRAW_FRAMEBUFFER,L.COLOR_ATTACHMENT0,G.get(N).__webglTexture,Oe,kt+ai)),L.blitFramebuffer(Ze,mt,We,Ne,je,Ct,We,Ne,L.DEPTH_BUFFER_BIT,L.NEAREST);_.bindFramebuffer(L.READ_FRAMEBUFFER,null),_.bindFramebuffer(L.DRAW_FRAMEBUFFER,null)}else if(Y!==0||M.isRenderTargetTexture||G.has(M)){let At=G.get(M),bn=G.get(N);_.bindFramebuffer(L.READ_FRAMEBUFFER,F),_.bindFramebuffer(L.DRAW_FRAMEBUFFER,V);for(let Dt=0;Dt<$e;Dt++)Si?L.framebufferTextureLayer(L.READ_FRAMEBUFFER,L.COLOR_ATTACHMENT0,At.__webglTexture,Y,_t+Dt):L.framebufferTexture2D(L.READ_FRAMEBUFFER,L.COLOR_ATTACHMENT0,L.TEXTURE_2D,At.__webglTexture,Y),Lt?L.framebufferTextureLayer(L.DRAW_FRAMEBUFFER,L.COLOR_ATTACHMENT0,bn.__webglTexture,Oe,kt+Dt):L.framebufferTexture2D(L.DRAW_FRAMEBUFFER,L.COLOR_ATTACHMENT0,L.TEXTURE_2D,bn.__webglTexture,Oe),Y!==0?L.blitFramebuffer(Ze,mt,We,Ne,je,Ct,We,Ne,L.COLOR_BUFFER_BIT,L.NEAREST):Lt?L.copyTexSubImage3D(ze,Oe,je,Ct,kt+Dt,Ze,mt,We,Ne):L.copyTexSubImage2D(ze,Oe,je,Ct,Ze,mt,We,Ne);_.bindFramebuffer(L.READ_FRAMEBUFFER,null),_.bindFramebuffer(L.DRAW_FRAMEBUFFER,null)}else Lt?M.isDataTexture||M.isData3DTexture?L.texSubImage3D(ze,Oe,je,Ct,kt,We,Ne,$e,It,Jt,Ot.data):N.isCompressedArrayTexture?L.compressedTexSubImage3D(ze,Oe,je,Ct,kt,We,Ne,$e,It,Ot.data):L.texSubImage3D(ze,Oe,je,Ct,kt,We,Ne,$e,It,Jt,Ot):M.isDataTexture?L.texSubImage2D(L.TEXTURE_2D,Oe,je,Ct,We,Ne,It,Jt,Ot.data):M.isCompressedTexture?L.compressedTexSubImage2D(L.TEXTURE_2D,Oe,je,Ct,Ot.width,Ot.height,It,Ot.data):L.texSubImage2D(L.TEXTURE_2D,Oe,je,Ct,We,Ne,It,Jt,Ot);_.pixelStorei(L.UNPACK_ROW_LENGTH,Yt),_.pixelStorei(L.UNPACK_IMAGE_HEIGHT,bt),_.pixelStorei(L.UNPACK_SKIP_PIXELS,dn),_.pixelStorei(L.UNPACK_SKIP_ROWS,tn),_.pixelStorei(L.UNPACK_SKIP_IMAGES,on),Oe===0&&N.generateMipmaps&&L.generateMipmap(ze),_.unbindTexture()},this.initRenderTarget=function(M){G.get(M).__webglFramebuffer===void 0&&ne.setupRenderTarget(M)},this.initTexture=function(M){M.isCubeTexture?ne.setTextureCube(M,0):M.isData3DTexture?ne.setTexture3D(M,0):M.isDataArrayTexture||M.isCompressedArrayTexture?ne.setTexture2DArray(M,0):ne.setTexture2D(M,0),_.unbindTexture()},this.resetState=function(){se=0,K=0,de=null,_.reset(),Fe.reset()},typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}get coordinateSystem(){return Jn}get outputColorSpace(){return this._outputColorSpace}set outputColorSpace(e){this._outputColorSpace=e;let t=this.getContext();t.drawingBufferColorSpace=St._getDrawingBufferColorSpace(e),t.unpackColorSpace=St._getUnpackColorSpace()}};var ni=i=>i,V2={openai:ni({colour:"#ececec",base:"#f3f3f1",ink:"#111214",cap:"#111214",trim:["#111214"],pattern:"lattice",glyph:"openai-white.svg"}),anthropic:ni({colour:"#d97757",base:"#f0eee6",ink:"#d97757",cap:"#d97757",trim:["#191919"],pattern:"split",glyph:"claude.svg"}),alibaba:ni({colour:"#ff6a00",base:"#ff6a00",ink:"#ffffff",cap:"#ffffff",trim:["#6950ef"],pattern:"diagonal",glyph:"alibaba.svg"}),xiaomi:ni({colour:"#ff6900",base:"#ffffff",ink:"#ff6900",cap:"#ff6900",trim:["#ff6900","#ffffff"],pattern:"rings",glyph:"xiaomi.svg"}),google:ni({colour:"#4285f4",base:"#ffffff",ink:"#4285f4",inks:["#4285f4","#ea4335","#fbbc05","#34a853"],cap:"#4285f4",trim:["#4285f4","#ea4335","#fbbc05","#34a853"],pattern:"lattice",glyph:"gemini.svg"}),kimi:ni({colour:"#007cff",base:"#007cff",ink:"#ffffff",cap:"#121212",trim:["#121212"],pattern:"rings",glyph:"kimi-white.svg"}),minimax:ni({colour:"#e73562",base:"#e73562",ink:"#ffffff",cap:"#ffffff",trim:["#ffffff"],pattern:"rings",glyph:"minimax.svg"}),zhipuai:ni({colour:"#b9c2cc",base:"#1a1d21",ink:"#ffffff",cap:"#ffffff",trim:["#ffffff","#1a1d21"],pattern:"lattice",glyph:"zai-white.svg"}),xai:ni({colour:"#8f96a0",base:"#0b0b0c",ink:"#f2f2f2",cap:"#0b0b0c",trim:["#f2f2f2"],pattern:"diagonal",glyph:"x-white.svg"}),meta:ni({colour:"#0467df",base:"#ffffff",ink:"#0467df",cap:"#0467df",trim:["#0467df"],pattern:"diagonal",glyph:"meta.svg"}),deepseek:ni({colour:"#4d6bfe",base:"#4d6bfe",ink:"#ffffff",cap:"#ffffff",trim:["#ffffff"],pattern:"diagonal",glyph:"deepseek.svg"})};function Tr(i,e="#b8b0a8"){return V2[i]??{colour:e,base:e,ink:"#ffffff",cap:"#ffffff",trim:["#ffffff"],pattern:"rings",glyph:null}}var G2={openai:"us",anthropic:"us",xai:"us",google:"us",meta:"us",zhipuai:"cn",kimi:"cn",minimax:"cn",alibaba:"cn",deepseek:"cn",xiaomi:"cn",tencent:"cn",volcengine:"cn"},W2={us:["falcon9","newGlenn","falconHeavy","vulcan"],cn:["cz2f","cz5","cz3b"]},_f=new Set(["xai"]);function xf(i,e,t){let n=[...i].sort((s,r)=>e(r)-e(s));return n.slice(0,3).find(s=>_f.has(t(s)))??n[0]}var K0=i=>{let e=2166136261;for(let t=0;t<i.length;t++)e=Math.imul(e^i.charCodeAt(t),16777619);return e>>>0},j0=(i,e)=>{if(_f.has(i))return"falcon9";let t=W2[G2[i]==="cn"?"cn":"us"];return t[(K0(i)+e)%t.length]};function vf(i,e,t=256){let n=i.image;if(!(n instanceof HTMLCanvasElement)||Math.max(n.width,n.height)<=t)return;let s=document.createElement("canvas"),r=t/Math.max(n.width,n.height);s.width=Math.max(1,Math.round(n.width*r)),s.height=Math.max(1,Math.round(n.height*r));let a=s.getContext("2d"),o=Object.getOwnPropertyDescriptor(fn.prototype,"needsUpdate").set,l=()=>{a.drawImage(n,0,0,s.width,s.height),o.call(i,!0)};i.image=s,Object.defineProperty(i,"needsUpdate",{configurable:!0,set(c){c&&(l(),e())}}),l()}function yf(i){let e=new Set([i.outer,i.inner,i.hit,i.ring,...i.bOuter,...i.streaks]);for(let t of i.stdParts.concat(i.heavy)){let n=[];t.traverse(s=>{s.isGroup&&n.push(s)});for(let s of n){let r=new Map;for(let a of s.children){if(!a.isMesh||a.children.length||e.has(a))continue;let o=`${a.geometry.uuid}/${a.material.uuid}`;r.has(o)||r.set(o,[]),r.get(o).push(a)}for(let a of r.values()){if(a.length<2)continue;let o=a[0],l=new ia(o.geometry,o.material,a.length);a.forEach((c,h)=>{c.updateMatrix(),l.setMatrixAt(h,c.matrix),s.remove(c)}),l.computeBoundingSphere(),s.add(l)}}}}function Q0(i,e=2e5){for(let t of["image/webp","image/jpeg"])for(let n of[.8,.65,.5,.35,.2,.1]){let s=i.toDataURL(t,n);if(!s.startsWith(`data:${t};`))break;if(s.length*2<=e)return s}return""}var wr={name:"CopyShader",uniforms:{tDiffuse:{value:null},opacity:{value:1}},vertexShader:`

		varying vec2 vUv;

		void main() {

			vUv = uv;
			gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );

		}`,fragmentShader:`

		uniform float opacity;

		uniform sampler2D tDiffuse;

		varying vec2 vUv;

		void main() {

			vec4 texel = texture2D( tDiffuse, vUv );
			gl_FragColor = opacity * texel;


		}`};var Nn=class{constructor(){this.isPass=!0,this.enabled=!0,this.needsSwap=!0,this.clear=!1,this.renderToScreen=!1}setSize(){}render(){console.error("THREE.Pass: .render() must be implemented in derived pass.")}dispose(){}},X2=new es(-1,1,1,-1,0,1),eh=class extends wt{constructor(){super(),this.setAttribute("position",new ft([-1,3,0,-1,-1,0,3,-1,0],3)),this.setAttribute("uv",new ft([0,2,0,0,2,0],2))}},q2=new eh,as=class{constructor(e){this._mesh=new gt(q2,e)}dispose(){this._mesh.geometry.dispose()}render(e){e.render(this._mesh,X2)}get material(){return this._mesh.material}set material(e){this._mesh.material=e}};var mc=class extends Nn{constructor(e,t="tDiffuse"){super(),this.textureID=t,this.uniforms=null,this.material=null,e instanceof Ft?(this.uniforms=e.uniforms,this.material=e):e&&(this.uniforms=Hi.clone(e.uniforms),this.material=new Ft({name:e.name!==void 0?e.name:"unspecified",defines:Object.assign({},e.defines),uniforms:this.uniforms,vertexShader:e.vertexShader,fragmentShader:e.fragmentShader})),this._fsQuad=new as(this.material)}render(e,t,n){this.uniforms[this.textureID]&&(this.uniforms[this.textureID].value=n.texture),this._fsQuad.material=this.material,this.renderToScreen?(e.setRenderTarget(null),this._fsQuad.render(e)):(e.setRenderTarget(t),this.clear&&e.clear(e.autoClearColor,e.autoClearDepth,e.autoClearStencil),this._fsQuad.render(e))}dispose(){this.material.dispose(),this._fsQuad.dispose()}};var Ja=class extends Nn{constructor(e,t){super(),this.scene=e,this.camera=t,this.clear=!0,this.needsSwap=!1,this.inverse=!1}render(e,t,n){let s=e.getContext(),r=e.state;r.buffers.color.setMask(!1),r.buffers.depth.setMask(!1),r.buffers.color.setLocked(!0),r.buffers.depth.setLocked(!0);let a,o;this.inverse?(a=0,o=1):(a=1,o=0),r.buffers.stencil.setTest(!0),r.buffers.stencil.setOp(s.REPLACE,s.REPLACE,s.REPLACE),r.buffers.stencil.setFunc(s.ALWAYS,a,4294967295),r.buffers.stencil.setClear(o),r.buffers.stencil.setLocked(!0),e.setRenderTarget(n),this.clear&&e.clear(),e.render(this.scene,this.camera),e.setRenderTarget(t),this.clear&&e.clear(),e.render(this.scene,this.camera),r.buffers.color.setLocked(!1),r.buffers.depth.setLocked(!1),r.buffers.color.setMask(!0),r.buffers.depth.setMask(!0),r.buffers.stencil.setLocked(!1),r.buffers.stencil.setFunc(s.EQUAL,1,4294967295),r.buffers.stencil.setOp(s.KEEP,s.KEEP,s.KEEP),r.buffers.stencil.setLocked(!0)}},gc=class extends Nn{constructor(){super(),this.needsSwap=!1}render(e){e.state.buffers.stencil.setLocked(!1),e.state.buffers.stencil.setTest(!1)}};var _c=class{constructor(e,t){if(this.renderer=e,this._pixelRatio=e.getPixelRatio(),t===void 0){let n=e.getSize(new ue);this._width=n.width,this._height=n.height,t=new $t(this._width*this._pixelRatio,this._height*this._pixelRatio,{type:sn}),t.texture.name="EffectComposer.rt1"}else this._width=t.width,this._height=t.height;this.renderTarget1=t,this.renderTarget2=t.clone(),this.renderTarget2.texture.name="EffectComposer.rt2",this.writeBuffer=this.renderTarget1,this.readBuffer=this.renderTarget2,this.renderToScreen=!0,this.passes=[],this.copyPass=new mc(wr),this.copyPass.material.blending=Hn,this.timer=new Ca}swapBuffers(){let e=this.readBuffer;this.readBuffer=this.writeBuffer,this.writeBuffer=e}addPass(e){this.passes.push(e),e.setSize(this._width*this._pixelRatio,this._height*this._pixelRatio)}insertPass(e,t){this.passes.splice(t,0,e),e.setSize(this._width*this._pixelRatio,this._height*this._pixelRatio)}removePass(e){let t=this.passes.indexOf(e);t!==-1&&this.passes.splice(t,1)}isLastEnabledPass(e){for(let t=e+1;t<this.passes.length;t++)if(this.passes[t].enabled)return!1;return!0}render(e){this.timer.update(),e===void 0&&(e=this.timer.getDelta());let t=this.renderer.getRenderTarget(),n=!1;for(let s=0,r=this.passes.length;s<r;s++){let a=this.passes[s];if(a.enabled!==!1){if(a.renderToScreen=this.renderToScreen&&this.isLastEnabledPass(s),a.render(this.renderer,this.writeBuffer,this.readBuffer,e,n),a.needsSwap){if(n){let o=this.renderer.getContext(),l=this.renderer.state.buffers.stencil;l.setFunc(o.NOTEQUAL,1,4294967295),this.copyPass.render(this.renderer,this.writeBuffer,this.readBuffer,e),l.setFunc(o.EQUAL,1,4294967295)}this.swapBuffers()}Ja!==void 0&&(a instanceof Ja?n=!0:a instanceof gc&&(n=!1))}}this.renderer.setRenderTarget(t)}reset(e){if(e===void 0){let t=this.renderer.getSize(new ue);this._pixelRatio=this.renderer.getPixelRatio(),this._width=t.width,this._height=t.height,e=this.renderTarget1.clone(),e.setSize(this._width*this._pixelRatio,this._height*this._pixelRatio)}this.renderTarget1.dispose(),this.renderTarget2.dispose(),this.renderTarget1=e,this.renderTarget2=e.clone(),this.writeBuffer=this.renderTarget1,this.readBuffer=this.renderTarget2}setSize(e,t){this._width=e,this._height=t;let n=this._width*this._pixelRatio,s=this._height*this._pixelRatio;this.renderTarget1.setSize(n,s),this.renderTarget2.setSize(n,s);for(let r=0;r<this.passes.length;r++)this.passes[r].setSize(n,s)}setPixelRatio(e){this._pixelRatio=e,this.setSize(this._width,this._height)}dispose(){this.renderTarget1.dispose(),this.renderTarget2.dispose(),this.copyPass.dispose()}};var xc=class extends Nn{constructor(e,t,n=null,s=null,r=null){super(),this.scene=e,this.camera=t,this.overrideMaterial=n,this.clearColor=s,this.clearAlpha=r,this.clear=!0,this.clearDepth=!1,this.needsSwap=!1,this.isRenderPass=!0,this._oldClearColor=new it}render(e,t,n){let s=e.autoClear;e.autoClear=!1;let r,a;this.overrideMaterial!==null&&(a=this.scene.overrideMaterial,this.scene.overrideMaterial=this.overrideMaterial),this.clearColor!==null&&(e.getClearColor(this._oldClearColor),e.setClearColor(this.clearColor,e.getClearAlpha())),this.clearAlpha!==null&&(r=e.getClearAlpha(),e.setClearAlpha(this.clearAlpha)),this.clearDepth==!0&&e.clearDepth(),e.setRenderTarget(this.renderToScreen?null:n),this.clear===!0&&e.clear(e.autoClearColor,e.autoClearDepth,e.autoClearStencil),e.render(this.scene,this.camera),this.clearColor!==null&&e.setClearColor(this._oldClearColor),this.clearAlpha!==null&&e.setClearAlpha(r),this.overrideMaterial!==null&&(this.scene.overrideMaterial=a),e.autoClear=s}};var Mf={name:"LuminosityHighPassShader",uniforms:{tDiffuse:{value:null},luminosityThreshold:{value:1},smoothWidth:{value:1},defaultColor:{value:new it(0)},defaultOpacity:{value:0}},vertexShader:`

		varying vec2 vUv;

		void main() {

			vUv = uv;

			gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );

		}`,fragmentShader:`

		uniform sampler2D tDiffuse;
		uniform vec3 defaultColor;
		uniform float defaultOpacity;
		uniform float luminosityThreshold;
		uniform float smoothWidth;

		varying vec2 vUv;

		void main() {

			vec4 texel = texture2D( tDiffuse, vUv );

			float v = luminance( texel.xyz );

			vec4 outputColor = vec4( defaultColor.rgb, defaultOpacity );

			float alpha = smoothstep( luminosityThreshold, luminosityThreshold + smoothWidth, v );

			gl_FragColor = mix( outputColor, texel, alpha );

		}`};var Ar=class i extends Nn{constructor(e,t=1,n,s){super(),this.strength=t,this.radius=n,this.threshold=s,this.resolution=e!==void 0?new ue(e.x,e.y):new ue(256,256),this.clearColor=new it(0,0,0),this.needsSwap=!1,this.renderTargetsHorizontal=[],this.renderTargetsVertical=[],this.nMips=5;let r=Math.round(this.resolution.x/2),a=Math.round(this.resolution.y/2);this.renderTargetBright=new $t(r,a,{type:sn,depthBuffer:!1}),this.renderTargetBright.texture.name="UnrealBloomPass.bright",this.renderTargetBright.texture.generateMipmaps=!1;for(let h=0;h<this.nMips;h++){let f=new $t(r,a,{type:sn,depthBuffer:!1});f.texture.name="UnrealBloomPass.h"+h,f.texture.generateMipmaps=!1,this.renderTargetsHorizontal.push(f);let u=new $t(r,a,{type:sn,depthBuffer:!1});u.texture.name="UnrealBloomPass.v"+h,u.texture.generateMipmaps=!1,this.renderTargetsVertical.push(u),r=Math.round(r/2),a=Math.round(a/2)}let o=Mf;this.highPassUniforms=Hi.clone(o.uniforms),this.highPassUniforms.luminosityThreshold.value=s,this.highPassUniforms.smoothWidth.value=.01,this.materialHighPassFilter=new Ft({uniforms:this.highPassUniforms,vertexShader:o.vertexShader,fragmentShader:o.fragmentShader}),this.separableBlurMaterials=[];let l=[6,10,14,18,22];r=Math.round(this.resolution.x/2),a=Math.round(this.resolution.y/2);for(let h=0;h<this.nMips;h++)this.separableBlurMaterials.push(this._getSeparableBlurMaterial(l[h])),this.separableBlurMaterials[h].uniforms.invSize.value=new ue(1/r,1/a),r=Math.round(r/2),a=Math.round(a/2);this.compositeMaterial=this._getCompositeMaterial(this.nMips),this.compositeMaterial.uniforms.blurTexture1.value=this.renderTargetsVertical[0].texture,this.compositeMaterial.uniforms.blurTexture2.value=this.renderTargetsVertical[1].texture,this.compositeMaterial.uniforms.blurTexture3.value=this.renderTargetsVertical[2].texture,this.compositeMaterial.uniforms.blurTexture4.value=this.renderTargetsVertical[3].texture,this.compositeMaterial.uniforms.blurTexture5.value=this.renderTargetsVertical[4].texture,this.compositeMaterial.uniforms.bloomStrength.value=t,this.compositeMaterial.uniforms.bloomRadius.value=.1;let c=[1,.8,.6,.4,.2];this.compositeMaterial.uniforms.bloomFactors.value=c,this.bloomTintColors=[new I(1,1,1),new I(1,1,1),new I(1,1,1),new I(1,1,1),new I(1,1,1)],this.compositeMaterial.uniforms.bloomTintColors.value=this.bloomTintColors,this.copyUniforms=Hi.clone(wr.uniforms),this.blendMaterial=new Ft({uniforms:this.copyUniforms,vertexShader:wr.vertexShader,fragmentShader:wr.fragmentShader,premultipliedAlpha:!0,blending:nn,depthTest:!1,depthWrite:!1,transparent:!0}),this._oldClearColor=new it,this._oldClearAlpha=1,this._basic=new en,this._fsQuad=new as(null)}dispose(){for(let e=0;e<this.renderTargetsHorizontal.length;e++)this.renderTargetsHorizontal[e].dispose();for(let e=0;e<this.renderTargetsVertical.length;e++)this.renderTargetsVertical[e].dispose();this.renderTargetBright.dispose();for(let e=0;e<this.separableBlurMaterials.length;e++)this.separableBlurMaterials[e].dispose();this.compositeMaterial.dispose(),this.blendMaterial.dispose(),this._basic.dispose(),this._fsQuad.dispose()}setSize(e,t){let n=Math.round(e/2),s=Math.round(t/2);this.renderTargetBright.setSize(n,s);for(let r=0;r<this.nMips;r++)this.renderTargetsHorizontal[r].setSize(n,s),this.renderTargetsVertical[r].setSize(n,s),this.separableBlurMaterials[r].uniforms.invSize.value=new ue(1/n,1/s),n=Math.round(n/2),s=Math.round(s/2)}render(e,t,n,s,r){e.getClearColor(this._oldClearColor),this._oldClearAlpha=e.getClearAlpha();let a=e.autoClear;e.autoClear=!1,e.setClearColor(this.clearColor,0),r&&e.state.buffers.stencil.setTest(!1),this.renderToScreen&&(this._fsQuad.material=this._basic,this._basic.map=n.texture,e.setRenderTarget(null),e.clear(),this._fsQuad.render(e)),this.highPassUniforms.tDiffuse.value=n.texture,this.highPassUniforms.luminosityThreshold.value=this.threshold,this._fsQuad.material=this.materialHighPassFilter,e.setRenderTarget(this.renderTargetBright),e.clear(),this._fsQuad.render(e);let o=this.renderTargetBright;for(let l=0;l<this.nMips;l++)this._fsQuad.material=this.separableBlurMaterials[l],this.separableBlurMaterials[l].uniforms.colorTexture.value=o.texture,this.separableBlurMaterials[l].uniforms.direction.value=i.BlurDirectionX,e.setRenderTarget(this.renderTargetsHorizontal[l]),e.clear(),this._fsQuad.render(e),this.separableBlurMaterials[l].uniforms.colorTexture.value=this.renderTargetsHorizontal[l].texture,this.separableBlurMaterials[l].uniforms.direction.value=i.BlurDirectionY,e.setRenderTarget(this.renderTargetsVertical[l]),e.clear(),this._fsQuad.render(e),o=this.renderTargetsVertical[l];this._fsQuad.material=this.compositeMaterial,this.compositeMaterial.uniforms.bloomStrength.value=this.strength,this.compositeMaterial.uniforms.bloomRadius.value=this.radius,this.compositeMaterial.uniforms.bloomTintColors.value=this.bloomTintColors,e.setRenderTarget(this.renderTargetsHorizontal[0]),e.clear(),this._fsQuad.render(e),this._fsQuad.material=this.blendMaterial,this.copyUniforms.tDiffuse.value=this.renderTargetsHorizontal[0].texture,r&&e.state.buffers.stencil.setTest(!0),this.renderToScreen?(e.setRenderTarget(null),this._fsQuad.render(e)):(e.setRenderTarget(n),this._fsQuad.render(e)),e.setClearColor(this._oldClearColor,this._oldClearAlpha),e.autoClear=a}_getSeparableBlurMaterial(e){let t=[],n=e/3;for(let a=0;a<e;a++)t.push(.39894*Math.exp(-.5*a*a/(n*n))/n);let s=[],r=[];for(let a=1;a<e;a+=2){let o=t[a],l=a+1<e?t[a+1]:0,c=o+l;s.push((a*o+(a+1)*l)/c),r.push(c)}return new Ft({defines:{KERNEL_PAIRS:s.length},uniforms:{colorTexture:{value:null},invSize:{value:new ue(.5,.5)},direction:{value:new ue(.5,.5)},centerWeight:{value:t[0]},gaussianOffsets:{value:s},gaussianWeights:{value:r}},vertexShader:`

				varying vec2 vUv;

				void main() {

					vUv = uv;
					gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );

				}`,fragmentShader:`

				#include <common>

				varying vec2 vUv;

				uniform sampler2D colorTexture;
				uniform vec2 invSize;
				uniform vec2 direction;
				uniform float centerWeight;
				uniform float gaussianOffsets[KERNEL_PAIRS];
				uniform float gaussianWeights[KERNEL_PAIRS];

				void main() {

					vec3 diffuseSum = texture2D( colorTexture, vUv ).rgb * centerWeight;

					for ( int i = 0; i < KERNEL_PAIRS; i ++ ) {

						vec2 uvOffset = direction * invSize * gaussianOffsets[ i ];
						vec3 sample1 = texture2D( colorTexture, vUv + uvOffset ).rgb;
						vec3 sample2 = texture2D( colorTexture, vUv - uvOffset ).rgb;
						diffuseSum += ( sample1 + sample2 ) * gaussianWeights[ i ];

					}

					gl_FragColor = vec4( diffuseSum, 1.0 );

				}`})}_getCompositeMaterial(e){return new Ft({defines:{NUM_MIPS:e},uniforms:{blurTexture1:{value:null},blurTexture2:{value:null},blurTexture3:{value:null},blurTexture4:{value:null},blurTexture5:{value:null},bloomStrength:{value:1},bloomFactors:{value:null},bloomTintColors:{value:null},bloomRadius:{value:0}},vertexShader:`

				varying vec2 vUv;

				void main() {

					vUv = uv;
					gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );

				}`,fragmentShader:`

				varying vec2 vUv;

				uniform sampler2D blurTexture1;
				uniform sampler2D blurTexture2;
				uniform sampler2D blurTexture3;
				uniform sampler2D blurTexture4;
				uniform sampler2D blurTexture5;
				uniform float bloomStrength;
				uniform float bloomRadius;
				uniform float bloomFactors[NUM_MIPS];
				uniform vec3 bloomTintColors[NUM_MIPS];

				float lerpBloomFactor( const in float factor ) {

					float mirrorFactor = 1.2 - factor;
					return mix( factor, mirrorFactor, bloomRadius );

				}

				void main() {

					// 3.0 for backwards compatibility with previous alpha-based intensity
					vec3 bloom = 3.0 * bloomStrength * (
						lerpBloomFactor( bloomFactors[ 0 ] ) * bloomTintColors[ 0 ] * texture2D( blurTexture1, vUv ).rgb +
						lerpBloomFactor( bloomFactors[ 1 ] ) * bloomTintColors[ 1 ] * texture2D( blurTexture2, vUv ).rgb +
						lerpBloomFactor( bloomFactors[ 2 ] ) * bloomTintColors[ 2 ] * texture2D( blurTexture3, vUv ).rgb +
						lerpBloomFactor( bloomFactors[ 3 ] ) * bloomTintColors[ 3 ] * texture2D( blurTexture4, vUv ).rgb +
						lerpBloomFactor( bloomFactors[ 4 ] ) * bloomTintColors[ 4 ] * texture2D( blurTexture5, vUv ).rgb
					);

					float bloomAlpha = max( bloom.r, max( bloom.g, bloom.b ) );
					gl_FragColor = vec4( bloom, bloomAlpha );

				}`})}};Ar.BlurDirectionX=new ue(1,0);Ar.BlurDirectionY=new ue(0,1);var Ka={name:"OutputShader",uniforms:{tDiffuse:{value:null},toneMappingExposure:{value:1}},vertexShader:`
		precision highp float;

		uniform mat4 modelViewMatrix;
		uniform mat4 projectionMatrix;

		attribute vec3 position;
		attribute vec2 uv;

		varying vec2 vUv;

		void main() {

			vUv = uv;
			gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );

		}`,fragmentShader:`

		precision highp float;

		uniform sampler2D tDiffuse;

		#include <tonemapping_pars_fragment>
		#include <colorspace_pars_fragment>

		varying vec2 vUv;

		void main() {

			gl_FragColor = texture2D( tDiffuse, vUv );

			// tone mapping

			#ifdef LINEAR_TONE_MAPPING

				gl_FragColor.rgb = LinearToneMapping( gl_FragColor.rgb );

			#elif defined( REINHARD_TONE_MAPPING )

				gl_FragColor.rgb = ReinhardToneMapping( gl_FragColor.rgb );

			#elif defined( CINEON_TONE_MAPPING )

				gl_FragColor.rgb = CineonToneMapping( gl_FragColor.rgb );

			#elif defined( ACES_FILMIC_TONE_MAPPING )

				gl_FragColor.rgb = ACESFilmicToneMapping( gl_FragColor.rgb );

			#elif defined( AGX_TONE_MAPPING )

				gl_FragColor.rgb = AgXToneMapping( gl_FragColor.rgb );

			#elif defined( NEUTRAL_TONE_MAPPING )

				gl_FragColor.rgb = NeutralToneMapping( gl_FragColor.rgb );

			#elif defined( CUSTOM_TONE_MAPPING )

				gl_FragColor.rgb = CustomToneMapping( gl_FragColor.rgb );

			#endif

			// color space

			#ifdef SRGB_TRANSFER

				gl_FragColor = sRGBTransferOETF( gl_FragColor );

			#endif

		}`};var vc=class extends Nn{constructor(){super(),this.isOutputPass=!0,this.uniforms=Hi.clone(Ka.uniforms),this.material=new dr({name:Ka.name,uniforms:this.uniforms,vertexShader:Ka.vertexShader,fragmentShader:Ka.fragmentShader}),this._fsQuad=new as(this.material),this._outputColorSpace=null,this._toneMapping=null}render(e,t,n){this.uniforms.tDiffuse.value=n.texture,this.uniforms.toneMappingExposure.value=e.toneMappingExposure,(this._outputColorSpace!==e.outputColorSpace||this._toneMapping!==e.toneMapping)&&(this._outputColorSpace=e.outputColorSpace,this._toneMapping=e.toneMapping,this.material.defines={},St.getTransfer(this._outputColorSpace)===Pt&&(this.material.defines.SRGB_TRANSFER=""),this._toneMapping===La?this.material.defines.LINEAR_TONE_MAPPING="":this._toneMapping===Da?this.material.defines.REINHARD_TONE_MAPPING="":this._toneMapping===Na?this.material.defines.CINEON_TONE_MAPPING="":this._toneMapping===Ms?this.material.defines.ACES_FILMIC_TONE_MAPPING="":this._toneMapping===Fa?this.material.defines.AGX_TONE_MAPPING="":this._toneMapping===Oa?this.material.defines.NEUTRAL_TONE_MAPPING="":this._toneMapping===Ua&&(this.material.defines.CUSTOM_TONE_MAPPING=""),this.material.needsUpdate=!0),this.renderToScreen===!0?(e.setRenderTarget(null),this._fsQuad.render(e)):(e.setRenderTarget(t),this.clear&&e.clear(e.autoClearColor,e.autoClearDepth,e.autoClearStencil),this._fsQuad.render(e))}dispose(){this.material.dispose(),this._fsQuad.dispose()}};function Sf(i){let t=new I(0,-55,-8),n=new I(-.93,.07,-.36).normalize(),s=`vec3 m289(vec3 x){return x-floor(x*(1./289.))*289.;} vec4 m289(vec4 x){return x-floor(x*(1./289.))*289.;} vec4 perm(vec4 x){return m289(((x*34.)+1.)*x);} vec4 tis(vec4 r){return 1.79284291400159-.85373472095314*r;}
float snoise(vec3 v){ const vec2 C=vec2(1./6.,1./3.); const vec4 D=vec4(0.,.5,1.,2.); vec3 i=floor(v+dot(v,C.yyy)); vec3 x0=v-i+dot(i,C.xxx); vec3 g=step(x0.yzx,x0.xyz); vec3 l=1.-g; vec3 i1=min(g.xyz,l.zxy); vec3 i2=max(g.xyz,l.zxy); vec3 x1=x0-i1+C.xxx; vec3 x2=x0-i2+C.yyy; vec3 x3=x0-D.yyy; i=m289(i);
 vec4 p=perm(perm(perm(i.z+vec4(0.,i1.z,i2.z,1.))+i.y+vec4(0.,i1.y,i2.y,1.))+i.x+vec4(0.,i1.x,i2.x,1.)); float n_=.142857142857; vec3 ns=n_*D.wyz-D.xzx; vec4 j=p-49.*floor(p*ns.z*ns.z); vec4 x_=floor(j*ns.z); vec4 y_=floor(j-7.*x_); vec4 x=x_*ns.x+ns.yyyy; vec4 y=y_*ns.x+ns.yyyy; vec4 h=1.-abs(x)-abs(y); vec4 b0=vec4(x.xy,y.xy); vec4 b1=vec4(x.zw,y.zw); vec4 s0=floor(b0)*2.+1.; vec4 s1=floor(b1)*2.+1.; vec4 sh=-step(h,vec4(0.));
 vec4 a0=b0.xzyw+s0.xzyw*sh.xxyy; vec4 a1=b1.xzyw+s1.xzyw*sh.zzww; vec3 p0=vec3(a0.xy,h.x); vec3 p1=vec3(a0.zw,h.y); vec3 p2=vec3(a1.xy,h.z); vec3 p3=vec3(a1.zw,h.w); vec4 nr=tis(vec4(dot(p0,p0),dot(p1,p1),dot(p2,p2),dot(p3,p3))); p0*=nr.x; p1*=nr.y; p2*=nr.z; p3*=nr.w;
 vec4 m=max(.6-vec4(dot(x0,x0),dot(x1,x1),dot(x2,x2),dot(x3,x3)),0.); m=m*m; return 42.*dot(m*m,vec4(dot(p0,x0),dot(p1,x1),dot(p2,x2),dot(p3,x3))); }
float fbm6(vec3 p){ float s=0., a=.5; for(int i=0;i<6;i++){ s+=a*snoise(p); p=p*2.03+vec3(1.7,9.2,3.1); a*=.5; } return s; }
float fbm4(vec3 p){ float s=0., a=.5; for(int i=0;i<4;i++){ s+=a*snoise(p); p=p*2.1+vec3(4.1,2.3,7.7); a*=.5; } return s; }`,r=new qt;r.position.copy(t),i.add(r);let a=new Ft({uniforms:{sun:{value:n},t:{value:0}},vertexShader:"varying vec3 vP; varying vec3 vWN; varying vec3 vWP; void main(){ vP=position; vWN=normalize(mat3(modelMatrix)*normal); vec4 w=modelMatrix*vec4(position,1.); vWP=w.xyz; gl_Position=projectionMatrix*viewMatrix*w; }",fragmentShader:`uniform vec3 sun; uniform float t; varying vec3 vP; varying vec3 vWN; varying vec3 vWP;
${s}
void main(){
  vec3 p=normalize(vP), N=normalize(vWN), V=normalize(cameraPosition-vWP);
  float e=fbm6(p*5.5), land=smoothstep(.1,.13,e), hg=clamp((e-.11)/.4,0.,1.);
  vec3 ocean=mix(vec3(.003,.014,.045),vec3(.012,.07,.16),smoothstep(-.35,.05,e));
  vec3 ground=mix(vec3(.035,.07,.03),vec3(.15,.12,.075),smoothstep(.1,.5,hg+.22*snoise(p*34.)));
  ground=mix(ground,vec3(.42,.42,.44),smoothstep(.72,.95,hg));
  vec3 alb=mix(ocean,ground,land);
  float cl=smoothstep(.12,.55,fbm4(p*4.6+vec3(t*.003,0.,t*.002)))*.85;
  float ndl=dot(N,sun), lit=smoothstep(-.06,.22,ndl);
  vec3 col=mix(alb,vec3(.8,.83,.88),cl)*(max(ndl,0.)*1.9+.012);
  vec3 H=normalize(sun+V); col+=(1.-land)*(1.-cl)*pow(max(dot(N,H),0.),90.)*vec3(1.,.78,.5)*2.2*lit;
  float city=smoothstep(.5,.9,snoise(p*150.))*smoothstep(-.1,.45,snoise(p*16.))*land*(1.-smoothstep(.6,.8,hg));
  col+=vec3(1.,.6,.26)*city*(1.-lit)*(1.-cl*.9)*1.6;
  col+=vec3(1.,.36,.12)*exp(-pow((ndl+.04)*16.,2.))*.012;
  float f=pow(1.-max(dot(N,V),0.),4.);
  col+=mix(vec3(.03,.14,.5),vec3(.32,.66,1.),f)*f*(.08+1.5*smoothstep(-.3,.45,ndl));
  gl_FragColor=vec4(col,1.);
  #include <tonemapping_fragment>
  #include <colorspace_fragment>
}`}),o=new gt(new zn(46,128,96),a);r.add(o);let l=new gt(new zn(46*1.028,96,64),new Ft({side:_n,transparent:!0,depthWrite:!1,blending:nn,uniforms:{sun:{value:n}},vertexShader:"varying vec3 vN; varying vec3 wN; void main(){ vN=normalize(normalMatrix*normal); wN=normalize(mat3(modelMatrix)*normal); gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",fragmentShader:"uniform vec3 sun; varying vec3 vN; varying vec3 wN; void main(){ float i=pow(max(0.,.76-dot(vN,vec3(0.,0.,1.))),3.2); float s=.12+1.6*smoothstep(-.35,.55,dot(wN,sun)); vec3 c=mix(vec3(.2,.5,1.),vec3(.7,.88,1.),smoothstep(.3,.9,dot(wN,sun))); gl_FragColor=vec4(c*i*s*1.25,1.); }"}));return r.add(l),{update(c){a.uniforms.t.value=c,o.rotation.y=c*.002},dispose(){r.traverse(c=>{c.geometry?.dispose(),c.material?.dispose()}),i.remove(r)}}}function yc(i,e=!1){let t=i[0].index!==null,n=new Set(Object.keys(i[0].attributes)),s=new Set(Object.keys(i[0].morphAttributes)),r={},a={},o=i[0].morphTargetsRelative,l=new wt,c=0;for(let h=0;h<i.length;++h){let f=i[h],u=0;if(t!==(f.index!==null))return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". All geometries must have compatible attributes; make sure index attribute exists among all geometries, or in none of them."),null;for(let d in f.attributes){if(!n.has(d))return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+'. All geometries must have compatible attributes; make sure "'+d+'" attribute exists among all geometries, or in none of them.'),null;r[d]===void 0&&(r[d]=[]),r[d].push(f.attributes[d]),u++}if(u!==n.size)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". Make sure all geometries have the same number of attributes."),null;if(o!==f.morphTargetsRelative)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". .morphTargetsRelative must be consistent throughout all geometries."),null;for(let d in f.morphAttributes){if(!s.has(d))return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+".  .morphAttributes must be consistent throughout all geometries."),null;a[d]===void 0&&(a[d]=[]),a[d].push(f.morphAttributes[d])}if(e){let d;if(t)d=f.index.count;else if(f.attributes.position!==void 0)d=f.attributes.position.count;else return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". The geometry must have either an index or a position attribute"),null;l.addGroup(c,d,h),c+=d}}if(t){let h=0,f=[];for(let u=0;u<i.length;++u){let d=i[u].index;for(let g=0;g<d.count;++g)f.push(d.getX(g)+h);h+=i[u].attributes.position.count}l.setIndex(f)}for(let h in r){let f=bf(r[h]);if(!f)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed while trying to merge the "+h+" attribute."),null;l.setAttribute(h,f)}for(let h in a){let f=a[h][0].length;if(f!==0){l.morphAttributes=l.morphAttributes||{},l.morphAttributes[h]=[];for(let u=0;u<f;++u){let d=[];for(let x=0;x<a[h].length;++x)d.push(a[h][x][u]);let g=bf(d);if(!g)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed while trying to merge the "+h+" morphAttribute."),null;l.morphAttributes[h].push(g)}}}return l}function bf(i){let e,t,n,s=-1,r=0;for(let c=0;c<i.length;++c){let h=i[c];if(e===void 0&&(e=h.array.constructor),e!==h.array.constructor)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.array must be of consistent array types across matching attributes."),null;if(t===void 0&&(t=h.itemSize),t!==h.itemSize)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.itemSize must be consistent across matching attributes."),null;if(n===void 0&&(n=h.normalized),n!==h.normalized)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.normalized must be consistent across matching attributes."),null;if(s===-1&&(s=h.gpuType),s!==h.gpuType)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.gpuType must be consistent across matching attributes."),null;r+=h.count*t}let a=new e(r),o=new jt(a,t,n),l=0;for(let c=0;c<i.length;++c){let h=i[c];if(h.isInterleavedBufferAttribute){let f=l/t;for(let u=0,d=h.count;u<d;u++)for(let g=0;g<t;g++){let x=h.getComponent(u,g);o.setComponent(u+f,g,x)}}else a.set(h.array,l);l+=h.count*t}return s!==void 0&&(o.gpuType=s),o}var ja={falcon9:{id:"falcon9",shape:"falcon9",atlas:{w:852,h:1024,cap:[.993,.9941,.9977,.998]},parts:[{name:"core",uv:[0,0,.9014,1],top:1.6,end:-1.1295,profile:[[1.6,.018],[1.5886,.0552],[1.5771,.0765],[1.5657,.0934],[1.5543,.1083],[1.5429,.1218],[1.5314,.1343],[1.52,.1459],[1.5086,.1566],[1.4971,.1664],[1.4857,.1756],[1.4743,.1839],[1.4629,.1914],[1.4514,.1981],[1.44,.2041],[1.4286,.2094],[1.4171,.2139],[1.4057,.2178],[1.3943,.2211],[1.3829,.2238],[1.3714,.226],[1.36,.2275],[1.3486,.2282],[1.3371,.2287],[1.3257,.229],[1.3143,.2291],[1.3029,.2291],[1.2914,.229],[1.28,.2289],[1.2686,.2287],[1.2571,.2286],[1.2457,.2284],[1.2343,.2282],[1.2229,.2281],[1.2114,.2279],[1.2,.2278],[1.1886,.2278],[1.1771,.2281],[1.1657,.2285],[1.1543,.2284],[1.1429,.2281],[1.1314,.228],[1.12,.228],[1.1086,.228],[1.0971,.2279],[1.0857,.2277],[1.0743,.2275],[1.0629,.2274],[1.0514,.2271],[1.04,.2264],[1.0286,.2247],[1.0171,.2213],[1.0057,.216],[.9943,.2087],[.9829,.2001],[.9714,.1909],[.96,.1818],[.9486,.1735],[.9371,.1672],[.9257,.1629],[.9143,.1598],[.9029,.1574],[.8914,.1563],[.88,.1559],[.8686,.1557],[.8571,.1557],[.8457,.156],[.8343,.1564],[.8229,.1567],[.8114,.1568],[.8,.1567],[.7886,.1566],[.7771,.1567],[.7657,.157],[.7543,.1575],[.7429,.1576],[.7314,.1576],[.72,.1575],[.7086,.1574],[.6971,.1574],[.6857,.1576],[.6743,.1577],[.6629,.1575],[.6514,.157],[.64,.1568],[.6286,.1566],[.6171,.1565],[.6057,.1564],[.5943,.1564],[.5829,.1568],[.5714,.1589],[.56,.1642],[.5486,.1742],[.5371,.1896],[.5257,.2095],[.5143,.2305],[.5029,.2478],[.4914,.2566],[.48,.2521],[.4686,.232],[.4571,.2026],[.4457,.1795],[.4343,.1697],[.4229,.1675],[.4114,.1671],[.4,.1666],[.3886,.1659],[.3771,.1655],[.3657,.1652],[.3543,.1651],[.3429,.165],[.3314,.1649],[.32,.1648],[.3086,.1646],[.2971,.1645],[.2857,.1644],[.2743,.1643],[.2629,.1642],[.2514,.164],[.24,.164],[.2286,.1638],[.2171,.1637],[.2057,.1636],[.1943,.1636],[.1829,.1639],[.1714,.1645],[.16,.1653],[.1486,.1659],[.1371,.166],[.1257,.1659],[.1143,.1658],[.1029,.1657],[.0914,.1656],[.08,.1655],[.0686,.1654],[.0571,.1653],[.0457,.1651],[.0343,.165],[.0229,.1649],[.0114,.1648],[0,.1647],[-.0114,.1646],[-.0229,.1645],[-.0343,.1644],[-.0457,.1642],[-.0571,.1641],[-.0686,.164],[-.08,.164],[-.0914,.164],[-.1029,.1642],[-.1143,.1645],[-.1257,.1645],[-.1371,.1643],[-.1486,.1643],[-.16,.1646],[-.1714,.165],[-.1829,.1655],[-.1943,.1657],[-.2057,.1657],[-.2171,.1656],[-.2286,.1655],[-.24,.1654],[-.2514,.1653],[-.2629,.1652],[-.2743,.1651],[-.2857,.165],[-.2971,.1649],[-.3086,.1647],[-.32,.1646],[-.3314,.1645],[-.3429,.1644],[-.3543,.1643],[-.3657,.1644],[-.3771,.165],[-.3886,.1666],[-.4,.1684],[-.4114,.1694],[-.4229,.1696],[-.4343,.1696],[-.4457,.1695],[-.4571,.1694],[-.4686,.1692],[-.48,.1692],[-.4914,.169],[-.5029,.1689],[-.5143,.1688],[-.5257,.1687],[-.5371,.1686],[-.5486,.1685],[-.56,.1683],[-.5714,.1682],[-.5829,.1681],[-.5943,.168],[-.6057,.1679],[-.6171,.1678],[-.6286,.1677],[-.64,.1676],[-.6514,.1675],[-.6629,.1673],[-.6743,.1673],[-.6857,.1671],[-.6971,.167],[-.7086,.1669],[-.72,.1668],[-.7314,.1667],[-.7429,.1666],[-.7543,.1665],[-.7657,.1664],[-.7771,.1663],[-.7886,.1661],[-.8,.166],[-.8114,.1659],[-.8229,.1658],[-.8343,.1657],[-.8457,.1656],[-.8571,.1655],[-.8686,.1654],[-.88,.1653],[-.8914,.1652],[-.9029,.1651],[-.9143,.165],[-.9257,.1649],[-.9371,.1647],[-.9486,.1646],[-.96,.1645],[-.9714,.1644],[-.9829,.1643],[-.9943,.1642],[-1.0057,.1641],[-1.0171,.164],[-1.0286,.1639],[-1.04,.1638],[-1.0514,.1637],[-1.0629,.1636],[-1.0743,.1635],[-1.0857,.1634],[-1.0971,.1633],[-1.1086,.1631],[-1.12,.1631],[-1.1276,.163]],at:[[0,0]],fins:[{side:-1,uv:[.9014,.6426,.9894,1],x0:-.2226,x1:0,y0:-.4381,y1:-1.1352,outline:[[-.4381,.1721,.1662],[-.4438,.1751,.1662],[-.4495,.1751,.1662],[-.4552,.1751,.1662],[-.461,.1781,.1662],[-.4667,.1781,.1662],[-.4724,.1781,.1662],[-.4781,.1781,.1662],[-.4838,.181,.1662],[-.4895,.181,.1662],[-.4952,.181,.1662],[-.501,.181,.1662],[-.5067,.181,.1662],[-.5124,.184,.1662],[-.5181,.184,.1662],[-.5238,.184,.1662],[-.5295,.184,.1662],[-.5352,.184,.1662],[-.541,.187,.1662],[-.5467,.187,.1662],[-.5524,.187,.1662],[-.5581,.1899,.1662],[-.5638,.1899,.1662],[-.5695,.1899,.1662],[-.5752,.1899,.1662],[-.581,.1899,.1662],[-.5867,.187,.1662],[-.5924,.1899,.1662],[-.5981,.1899,.1662],[-.6038,.1899,.1662],[-.6095,.1899,.1662],[-.6152,.1899,.1662],[-.621,.1899,.1662],[-.6267,.1899,.1662],[-.6324,.1899,.1662],[-.6381,.1899,.1662],[-.6438,.1899,.1662],[-.6495,.1899,.1662],[-.6552,.1899,.1662],[-.661,.1929,.1662],[-.6667,.1929,.1662],[-.6724,.1929,.1662],[-.6781,.1929,.1662],[-.6838,.1929,.1662],[-.6895,.1929,.1662],[-.6952,.1929,.1662],[-.701,.1929,.1662],[-.7067,.1959,.1662],[-.7124,.1959,.1662],[-.7181,.1959,.1662],[-.7238,.1959,.1662],[-.7295,.1959,.1662],[-.7352,.1959,.1662],[-.741,.1959,.1662],[-.7467,.1959,.1662],[-.7524,.1959,.1662],[-.7581,.1988,.1662],[-.7638,.1988,.1662],[-.7695,.1988,.1662],[-.7752,.1988,.1662],[-.781,.1988,.1662],[-.7867,.1988,.1662],[-.7924,.1988,.1662],[-.7981,.1988,.1662],[-.8038,.2018,.1662],[-.8095,.2018,.1662],[-.8152,.2018,.1662],[-.821,.2018,.1662],[-.8267,.2018,.1662],[-.8324,.2018,.1662],[-.8381,.2018,.1662],[-.8438,.2018,.1662],[-.8495,.2018,.1662],[-.8552,.2018,.1662],[-.861,.2047,.1662],[-.8667,.2047,.1662],[-.8724,.2047,.1662],[-.8781,.2047,.1662],[-.8838,.2047,.1662],[-.8895,.2047,.1662],[-.8952,.2047,.1662],[-.901,.2077,.1662],[-.9067,.2077,.1662],[-.9124,.2077,.1662],[-.9181,.2077,.1662],[-.9238,.2077,.1662],[-.9295,.2077,.1662],[-.9352,.2077,.1662],[-.941,.2077,.1662],[-.9467,.2107,.1662],[-.9524,.2107,.1662],[-.9581,.2107,.1662],[-.9638,.2107,.1662],[-.9695,.2107,.1662],[-.9752,.2107,.1662],[-.981,.2107,.1662],[-.9867,.2136,.1662],[-.9924,.2136,.1662],[-.9981,.2136,.1662],[-1.0038,.2136,.1662],[-1.0095,.2136,.1662],[-1.0152,.2136,.1662],[-1.021,.2166,.1662],[-1.0267,.2196,.1662],[-1.0324,.2196,.1662],[-1.0381,.2196,.1662],[-1.0438,.2107,.1662],[-1.0495,.2047,.1662],[-1.0552,.1988,.1662],[-1.061,.1988,.1662],[-1.0667,.1988,.1662],[-1.0724,.2018,.1662],[-1.0781,.2018,.1662],[-1.0838,.2018,.1662],[-1.0895,.2018,.1662],[-1.0952,.2018,.1662],[-1.101,.2047,.1662],[-1.1067,.2047,.1662],[-1.1124,.2047,.1662],[-1.1181,.2047,.1662],[-1.1238,.1988,.1662],[-1.1295,.1899,.1662],[-1.1333,.184,.1662]]},{side:1,uv:[.9014,.2832,.9906,.6406],x0:0,x1:.2255,y0:-.4381,y1:-1.1352,outline:[[-.4381,.1721,.1662],[-.4438,.1751,.1662],[-.4495,.1751,.1662],[-.4552,.1751,.1662],[-.461,.1781,.1662],[-.4667,.1781,.1662],[-.4724,.1781,.1662],[-.4781,.1781,.1662],[-.4838,.181,.1662],[-.4895,.181,.1662],[-.4952,.181,.1662],[-.501,.181,.1662],[-.5067,.184,.1662],[-.5124,.184,.1662],[-.5181,.184,.1662],[-.5238,.184,.1662],[-.5295,.184,.1662],[-.5352,.187,.1662],[-.541,.187,.1662],[-.5467,.187,.1662],[-.5524,.1899,.1662],[-.5581,.1929,.1662],[-.5638,.1929,.1662],[-.5695,.1929,.1662],[-.5752,.1899,.1662],[-.581,.1899,.1662],[-.5867,.1899,.1662],[-.5924,.1899,.1662],[-.5981,.1899,.1662],[-.6038,.1899,.1662],[-.6095,.1929,.1662],[-.6152,.1929,.1662],[-.621,.1929,.1662],[-.6267,.1929,.1662],[-.6324,.1929,.1662],[-.6381,.1929,.1662],[-.6438,.1929,.1662],[-.6495,.1929,.1662],[-.6552,.1929,.1662],[-.661,.1929,.1662],[-.6667,.1959,.1662],[-.6724,.1959,.1662],[-.6781,.1959,.1662],[-.6838,.1959,.1662],[-.6895,.1959,.1662],[-.6952,.1959,.1662],[-.701,.1959,.1662],[-.7067,.1959,.1662],[-.7124,.1959,.1662],[-.7181,.1959,.1662],[-.7238,.1988,.1662],[-.7295,.1988,.1662],[-.7352,.1988,.1662],[-.741,.1988,.1662],[-.7467,.1988,.1662],[-.7524,.1988,.1662],[-.7581,.1988,.1662],[-.7638,.2018,.1662],[-.7695,.2018,.1662],[-.7752,.2018,.1662],[-.781,.2018,.1662],[-.7867,.2018,.1662],[-.7924,.2018,.1662],[-.7981,.2018,.1662],[-.8038,.2018,.1662],[-.8095,.2047,.1662],[-.8152,.2047,.1662],[-.821,.2047,.1662],[-.8267,.2047,.1662],[-.8324,.2047,.1662],[-.8381,.2047,.1662],[-.8438,.2047,.1662],[-.8495,.2077,.1662],[-.8552,.2077,.1662],[-.861,.2077,.1662],[-.8667,.2077,.1662],[-.8724,.2077,.1662],[-.8781,.2077,.1662],[-.8838,.2077,.1662],[-.8895,.2107,.1662],[-.8952,.2107,.1662],[-.901,.2107,.1662],[-.9067,.2107,.1662],[-.9124,.2107,.1662],[-.9181,.2107,.1662],[-.9238,.2107,.1662],[-.9295,.2136,.1662],[-.9352,.2136,.1662],[-.941,.2136,.1662],[-.9467,.2136,.1662],[-.9524,.2136,.1662],[-.9581,.2136,.1662],[-.9638,.2136,.1662],[-.9695,.2166,.1662],[-.9752,.2166,.1662],[-.981,.2166,.1662],[-.9867,.2166,.1662],[-.9924,.2166,.1662],[-.9981,.2196,.1662],[-1.0038,.2196,.1662],[-1.0095,.2196,.1662],[-1.0152,.2225,.1662],[-1.021,.2225,.1662],[-1.0267,.2225,.1662],[-1.0324,.2225,.1662],[-1.0381,.2225,.1662],[-1.0438,.2166,.1662],[-1.0495,.2107,.1662],[-1.0552,.2018,.1662],[-1.061,.2018,.1662],[-1.0667,.2018,.1662],[-1.0724,.2047,.1662],[-1.0781,.2047,.1662],[-1.0838,.2047,.1662],[-1.0895,.2047,.1662],[-1.0952,.2047,.1662],[-1.101,.2047,.1662],[-1.1067,.2047,.1662],[-1.1124,.2047,.1662],[-1.1181,.2047,.1662],[-1.1238,.2047,.1662],[-1.1295,.1959,.1662],[-1.1333,.1899,.1662]]}],finsAround:4,finsFrom:null,engines:{ring:8,centre:!0,f:.34,colour:[32,26,19],profile:[[-1.1295,.1892],[-1.1333,.1833],[-1.1371,.1803],[-1.141,.1818],[-1.1448,.1817],[-1.1486,.1846],[-1.1524,.186],[-1.1562,.1874],[-1.16,.1888],[-1.1638,.1902],[-1.1676,.1917],[-1.1714,.1931],[-1.1752,.1945],[-1.179,.1959],[-1.1829,.1973],[-1.1867,.1987],[-1.1905,.2001],[-1.1943,.2001],[-1.1981,.2015],[-1.2019,.2029],[-1.2057,.2028],[-1.2095,.1984],[-1.2133,.1854],[-1.2171,.1506],[-1.221,.1505],[-1.2248,.1476],[-1.2286,.1302],[-1.2324,.055],[-1.2362,.0521],[-1.24,.0405]]}}],badge:{y:.9137,d:.2397,r:.1598},band:[.7607,.7796],head:{top:1.6,cut:1.0666,mean:.7703,r:.2696}},falconHeavy:{id:"falcon-heavy",shape:"falconHeavy",atlas:{w:1236,h:1024,cap:[.9951,.9941,.9984,.998]},parts:[{name:"core",uv:[0,0,.6214,1],top:1.6,end:-1.1103,profile:[[1.6,.0148],[1.5884,.0342],[1.5768,.0518],[1.5652,.0675],[1.5535,.0822],[1.5419,.0952],[1.5303,.1071],[1.5187,.1182],[1.5071,.1283],[1.4955,.1375],[1.4838,.1459],[1.4722,.1535],[1.4606,.1604],[1.449,.1666],[1.4374,.1721],[1.4258,.1771],[1.4142,.1814],[1.4025,.1851],[1.3909,.1882],[1.3793,.1907],[1.3677,.1927],[1.3561,.1942],[1.3445,.1952],[1.3328,.1959],[1.3212,.1961],[1.3096,.1961],[1.298,.196],[1.2864,.1959],[1.2748,.1958],[1.2631,.1957],[1.2515,.1956],[1.2399,.1955],[1.2283,.1955],[1.2167,.1958],[1.2051,.1962],[1.1935,.1964],[1.1818,.1964],[1.1702,.1963],[1.1586,.1962],[1.147,.1961],[1.1354,.196],[1.1238,.1959],[1.1121,.1958],[1.1005,.1957],[1.0889,.1956],[1.0773,.1955],[1.0657,.1954],[1.0541,.1953],[1.0425,.1952],[1.0308,.1951],[1.0192,.195],[1.0076,.1948],[.996,.1946],[.9844,.1938],[.9728,.192],[.9611,.1887],[.9495,.1842],[.9379,.1788],[.9263,.1731],[.9147,.1673],[.9031,.1617],[.8915,.1567],[.8798,.1525],[.8682,.1495],[.8566,.1479],[.845,.1473],[.8334,.1472],[.8218,.1471],[.8101,.147],[.7985,.1469],[.7869,.1469],[.7753,.1468],[.7637,.1467],[.7521,.1467],[.7404,.1468],[.7288,.1469],[.7172,.1471],[.7056,.1473],[.694,.1476],[.6824,.1479],[.6708,.1483],[.6591,.1487],[.6475,.1491],[.6359,.1496],[.6243,.1501],[.6127,.1507],[.6011,.1513],[.5894,.1519],[.5778,.1526],[.5662,.1533],[.5546,.1539],[.543,.1546],[.5314,.1554],[.5198,.1561],[.5081,.1568],[.4965,.1575],[.4849,.1583],[.4733,.159],[.4617,.1598],[.4501,.1605],[.4384,.1613],[.4268,.162],[.4152,.1627],[.4036,.1634],[.392,.164],[.3804,.1646],[.3688,.1651],[.3571,.1655],[.3455,.1659],[.3339,.1663],[.3223,.1664],[.3107,.1663],[.2991,.1662],[.2874,.1662],[.2758,.1661],[.2642,.166],[.2526,.1659],[.241,.1658],[.2294,.1657],[.2178,.1657],[.2061,.1656],[.1945,.1655],[.1829,.1654],[.1713,.1653],[.1597,.1653],[.1481,.1652],[.1364,.1651],[.1248,.1651],[.1132,.1653],[.1016,.1657],[.09,.1657],[.0784,.1655],[.0667,.1653],[.0551,.1654],[.0435,.1657],[.0319,.1658],[.0203,.1659],[.0087,.1663],[-.0029,.1666],[-.0146,.1667],[-.0262,.1667],[-.0378,.1666],[-.0494,.1665],[-.061,.1664],[-.0726,.1664],[-.0843,.1663],[-.0959,.1662],[-.1075,.1661],[-.1191,.166],[-.1307,.1659],[-.1423,.1659],[-.1539,.1658],[-.1656,.1657],[-.1772,.1656],[-.1888,.1656],[-.2004,.1657],[-.212,.1661],[-.2236,.1664],[-.2353,.1665],[-.2469,.1665],[-.2585,.1664],[-.2701,.1663],[-.2817,.1662],[-.2933,.1662],[-.3049,.1661],[-.3166,.166],[-.3282,.1659],[-.3398,.1658],[-.3514,.1657],[-.363,.1657],[-.3746,.1656],[-.3863,.1655],[-.3979,.1654],[-.4095,.1653],[-.4211,.1653],[-.4327,.1652],[-.4443,.1651],[-.456,.1651],[-.4676,.1653],[-.4792,.1656],[-.4908,.1659],[-.5024,.166],[-.514,.166],[-.5256,.1659],[-.5373,.1658],[-.5489,.1657],[-.5605,.1656],[-.5721,.1656],[-.5837,.1655],[-.5953,.1654],[-.607,.1653],[-.6186,.1652],[-.6302,.1651],[-.6418,.1651],[-.6534,.165],[-.665,.1649],[-.6766,.1648],[-.6883,.1648],[-.6999,.1647],[-.7115,.1646],[-.7231,.1645],[-.7347,.1644],[-.7463,.1643],[-.758,.1643],[-.7696,.1642],[-.7812,.1641],[-.7928,.164],[-.8044,.1639],[-.816,.1639],[-.8276,.1638],[-.8393,.1637],[-.8509,.1636],[-.8625,.1636],[-.8741,.1635],[-.8857,.1634],[-.8973,.1633],[-.909,.1632],[-.9206,.1631],[-.9322,.1631],[-.9438,.163],[-.9554,.1629],[-.967,.1628],[-.9787,.1628],[-.9903,.1627],[-1.0019,.1626],[-1.0135,.1625],[-1.0251,.1625],[-1.0367,.1624],[-1.0483,.1623],[-1.06,.1622],[-1.0716,.1621],[-1.0832,.1621],[-1.0948,.162],[-1.1064,.1619],[-1.1103,.1619]],at:[[0,0]],fins:[],finsAround:0,finsFrom:"booster",engines:{ring:8,centre:!0,f:.34,colour:[57,54,51],profile:[[-1.1103,.1592],[-1.1142,.1579],[-1.118,.1578],[-1.1219,.1578],[-1.1258,.1591],[-1.1297,.1591],[-1.1335,.1591],[-1.1374,.159],[-1.1413,.1564],[-1.1451,.1484],[-1.149,.1404],[-1.1529,.1377],[-1.1568,.1377],[-1.1606,.1377],[-1.1645,.1403],[-1.1684,.143],[-1.1722,.1456],[-1.1761,.1456],[-1.18,.1482],[-1.1839,.1508],[-1.1877,.1508],[-1.1916,.1534],[-1.1955,.1547],[-1.1993,.156],[-1.2032,.1586],[-1.2071,.1586],[-1.211,.1612],[-1.2148,.1625],[-1.2187,.1638],[-1.2226,.1664],[-1.2264,.1637],[-1.2303,.1479],[-1.2342,.1307],[-1.2381,.1069]]}},{name:"booster",uv:[.6214,.0498,.932,1],top:.7714,end:-1.1103,profile:[[.7714,.0142],[.7598,.0316],[.7482,.0465],[.7366,.0588],[.725,.0697],[.7133,.0796],[.7017,.0886],[.6901,.0969],[.6785,.1045],[.6669,.1114],[.6553,.1178],[.6437,.1235],[.632,.1286],[.6204,.1332],[.6088,.1371],[.5972,.1406],[.5856,.1436],[.574,.146],[.5623,.1478],[.5507,.1495],[.5391,.1512],[.5275,.1533],[.5159,.1559],[.5043,.1589],[.4927,.1618],[.481,.1646],[.4694,.1669],[.4578,.1685],[.4462,.1692],[.4346,.1687],[.423,.1671],[.4113,.1646],[.3997,.1616],[.3881,.158],[.3765,.1553],[.3649,.1542],[.3533,.1539],[.3416,.1537],[.33,.1533],[.3184,.1527],[.3068,.1523],[.2952,.1522],[.2836,.1521],[.272,.152],[.2603,.1519],[.2487,.1518],[.2371,.1519],[.2255,.1521],[.2139,.1525],[.2023,.1528],[.1906,.1528],[.179,.1528],[.1674,.1527],[.1558,.1526],[.1442,.1525],[.1326,.1525],[.121,.1524],[.1093,.1523],[.0977,.1522],[.0861,.1522],[.0745,.1523],[.0629,.1527],[.0513,.153],[.0396,.1532],[.028,.1532],[.0164,.1531],[.0048,.1529],[-.0068,.1526],[-.0184,.1521],[-.03,.1516],[-.0417,.1514],[-.0533,.1513],[-.0649,.1514],[-.0765,.1517],[-.0881,.152],[-.0997,.1522],[-.1114,.1522],[-.123,.1522],[-.1346,.1521],[-.1462,.152],[-.1578,.1519],[-.1694,.1519],[-.181,.1518],[-.1927,.1517],[-.2043,.1516],[-.2159,.1517],[-.2275,.1519],[-.2391,.1523],[-.2507,.1526],[-.2624,.1526],[-.274,.1526],[-.2856,.1525],[-.2972,.1524],[-.3088,.1523],[-.3204,.1519],[-.3321,.1515],[-.3437,.151],[-.3553,.1508],[-.3669,.1509],[-.3785,.1512],[-.3901,.1516],[-.4017,.1517],[-.4134,.1516],[-.425,.1516],[-.4366,.1516],[-.4482,.1519],[-.4598,.1528],[-.4714,.1539],[-.4831,.1548],[-.4947,.1551],[-.5063,.1551],[-.5179,.1551],[-.5295,.155],[-.5411,.1549],[-.5527,.1548],[-.5644,.1547],[-.576,.1547],[-.5876,.1546],[-.5992,.1545],[-.6108,.1544],[-.6224,.1544],[-.6341,.1543],[-.6457,.1542],[-.6573,.1541],[-.6689,.1541],[-.6805,.154],[-.6921,.1539],[-.7037,.1538],[-.7154,.1538],[-.727,.1537],[-.7386,.1536],[-.7502,.1536],[-.7618,.1535],[-.7734,.1534],[-.7851,.1533],[-.7967,.1533],[-.8083,.1532],[-.8199,.1531],[-.8315,.153],[-.8431,.1529],[-.8548,.1529],[-.8664,.1528],[-.878,.1527],[-.8896,.1526],[-.9012,.1526],[-.9128,.1525],[-.9244,.1524],[-.9361,.1524],[-.9477,.1523],[-.9593,.1522],[-.9709,.1521],[-.9825,.1521],[-.9941,.152],[-1.0058,.1519],[-1.0174,.1518],[-1.029,.1518],[-1.0406,.1517],[-1.0522,.1516],[-1.0638,.1516],[-1.0754,.1515],[-1.0871,.1514],[-1.0987,.1513],[-1.1103,.1513]],at:[[-1.5708,.3464],[1.5708,.3464]],fins:[{side:-1,uv:[.932,.709,.9935,1],x0:-.2041,x1:0,y0:-.5392,y1:-1.1161,outline:[[-.5392,.1584,.1531],[-.545,.1611,.1531],[-.5508,.1638,.1531],[-.5566,.1638,.1531],[-.5624,.1638,.1531],[-.5682,.1638,.1531],[-.574,.1638,.1531],[-.5799,.1638,.1531],[-.5857,.1665,.1531],[-.5915,.1665,.1531],[-.5973,.1665,.1531],[-.6031,.1665,.1531],[-.6089,.1665,.1531],[-.6147,.1692,.1531],[-.6205,.1692,.1531],[-.6263,.1692,.1531],[-.6321,.1692,.1531],[-.6379,.1692,.1531],[-.6437,.1692,.1531],[-.6495,.1692,.1531],[-.6554,.1692,.1531],[-.6612,.1718,.1531],[-.667,.1718,.1531],[-.6728,.1718,.1531],[-.6786,.1718,.1531],[-.6844,.1718,.1531],[-.6902,.1718,.1531],[-.696,.1745,.1531],[-.7018,.1745,.1531],[-.7076,.1745,.1531],[-.7134,.1745,.1531],[-.7192,.1745,.1531],[-.725,.1745,.1531],[-.7309,.1745,.1531],[-.7367,.1772,.1531],[-.7425,.1772,.1531],[-.7483,.1772,.1531],[-.7541,.1772,.1531],[-.7599,.1772,.1531],[-.7657,.1772,.1531],[-.7715,.1772,.1531],[-.7773,.1799,.1531],[-.7831,.1799,.1531],[-.7889,.1799,.1531],[-.7947,.1799,.1531],[-.8005,.1799,.1531],[-.8064,.1799,.1531],[-.8122,.1799,.1531],[-.818,.1826,.1531],[-.8238,.1826,.1531],[-.8296,.1826,.1531],[-.8354,.1826,.1531],[-.8412,.1826,.1531],[-.847,.1826,.1531],[-.8528,.1853,.1531],[-.8586,.1853,.1531],[-.8644,.1853,.1531],[-.8702,.1853,.1531],[-.876,.1853,.1531],[-.8819,.1853,.1531],[-.8877,.1853,.1531],[-.8935,.1853,.1531],[-.8993,.1879,.1531],[-.9051,.1879,.1531],[-.9109,.1879,.1531],[-.9167,.1879,.1531],[-.9225,.1879,.1531],[-.9283,.1906,.1531],[-.9341,.1906,.1531],[-.9399,.1906,.1531],[-.9457,.1906,.1531],[-.9515,.1906,.1531],[-.9574,.1933,.1531],[-.9632,.1933,.1531],[-.969,.1933,.1531],[-.9748,.1933,.1531],[-.9806,.1933,.1531],[-.9864,.1933,.1531],[-.9922,.196,.1531],[-.998,.196,.1531],[-1.0038,.196,.1531],[-1.0096,.196,.1531],[-1.0154,.196,.1531],[-1.0212,.196,.1531],[-1.027,.196,.1531],[-1.0329,.1987,.1531],[-1.0387,.1987,.1531],[-1.0445,.1987,.1531],[-1.0503,.1987,.1531],[-1.0561,.2014,.1531],[-1.0619,.2014,.1531],[-1.0677,.2014,.1531],[-1.0735,.2014,.1531],[-1.0793,.2014,.1531],[-1.0851,.1906,.1531],[-1.0909,.1853,.1531],[-1.0967,.1772,.1531],[-1.1025,.1692,.1531],[-1.1084,.1665,.1531],[-1.1142,.1665,.1531]]}],finsAround:4,finsFrom:null,engines:{ring:8,centre:!0,f:.34,colour:[60,58,55],profile:[[-1.1103,.1645],[-1.1142,.1645],[-1.118,.1645],[-1.1219,.1644],[-1.1258,.1671],[-1.1297,.167],[-1.1335,.167],[-1.1374,.167],[-1.1413,.1643],[-1.1451,.1563],[-1.149,.151],[-1.1529,.151],[-1.1568,.1457],[-1.1606,.1456],[-1.1645,.1483],[-1.1684,.1509],[-1.1722,.1535],[-1.1761,.1535],[-1.18,.1561],[-1.1839,.1587],[-1.1877,.1587],[-1.1916,.1613],[-1.1955,.1639],[-1.1993,.1639],[-1.2032,.1665],[-1.2071,.1692],[-1.211,.1691],[-1.2148,.1717],[-1.2187,.1744],[-1.2226,.169],[-1.2264,.1585],[-1.2303,.132],[-1.2342,.0924]]}}],badge:{y:.9137,d:.251,r:.1673},band:[.7551,.774],head:{top:1.6,cut:1.0723,mean:.7752,r:.2062}},newGlenn:{id:"new-glenn",shape:"newGlenn",atlas:{w:897,h:1142,cap:[.9933,.9947,.9978,.9982]},parts:[{name:"core",uv:[0,.1033,.8562,1],top:1.6,end:-1.1485,profile:[[1.6,.0169],[1.5886,.0402],[1.5771,.0587],[1.5657,.0741],[1.5543,.0879],[1.5428,.1001],[1.5314,.1112],[1.5199,.1216],[1.5085,.1311],[1.4971,.1398],[1.4856,.1476],[1.4742,.1546],[1.4628,.1608],[1.4513,.1666],[1.4399,.1717],[1.4285,.1762],[1.417,.1798],[1.4056,.1828],[1.3941,.1851],[1.3827,.1868],[1.3713,.1879],[1.3598,.1885],[1.3484,.1888],[1.337,.1889],[1.3255,.1888],[1.3141,.1887],[1.3027,.1885],[1.2912,.1883],[1.2798,.1881],[1.2683,.1879],[1.2569,.1878],[1.2455,.1876],[1.234,.1874],[1.2226,.1873],[1.2112,.1871],[1.1997,.187],[1.1883,.1871],[1.1769,.1873],[1.1654,.1876],[1.154,.1877],[1.1426,.1876],[1.1311,.1875],[1.1197,.1873],[1.1082,.1871],[1.0968,.1871],[1.0854,.1875],[1.0739,.1881],[1.0625,.1882],[1.0511,.1874],[1.0396,.1865],[1.0282,.186],[1.0168,.1858],[1.0053,.1856],[.9939,.1854],[.9824,.1852],[.971,.1851],[.9596,.1849],[.9481,.1848],[.9367,.1846],[.9253,.1845],[.9138,.1845],[.9024,.1848],[.891,.1851],[.8795,.1852],[.8681,.1852],[.8566,.1852],[.8452,.1855],[.8338,.1858],[.8223,.1859],[.8109,.1858],[.7995,.1856],[.788,.1855],[.7766,.1853],[.7652,.1852],[.7537,.1853],[.7423,.1856],[.7308,.1859],[.7194,.1859],[.708,.1858],[.6965,.1856],[.6851,.1854],[.6737,.1852],[.6622,.1854],[.6508,.1862],[.6394,.1869],[.6279,.1869],[.6165,.1864],[.605,.1862],[.5936,.1866],[.5822,.1873],[.5707,.1879],[.5593,.1881],[.5479,.188],[.5364,.1878],[.525,.1877],[.5136,.1875],[.5021,.1873],[.4907,.1872],[.4792,.1871],[.4678,.187],[.4564,.1869],[.4449,.1869],[.4335,.1869],[.4221,.1869],[.4106,.187],[.3992,.1872],[.3878,.1873],[.3763,.1876],[.3649,.1879],[.3534,.1883],[.342,.1888],[.3306,.1894],[.3191,.19],[.3077,.1902],[.2963,.1902],[.2848,.1901],[.2734,.19],[.262,.1898],[.2505,.1896],[.2391,.1895],[.2277,.1893],[.2162,.1891],[.2048,.189],[.1933,.1888],[.1819,.1887],[.1705,.1885],[.159,.1883],[.1476,.1883],[.1362,.1883],[.1247,.1887],[.1133,.1893],[.1019,.1898],[.0904,.19],[.079,.19],[.0675,.1899],[.0561,.1898],[.0447,.1896],[.0332,.1894],[.0218,.1893],[.0104,.1891],[-.0011,.189],[-.0125,.1888],[-.0239,.1887],[-.0354,.1885],[-.0468,.1884],[-.0583,.1885],[-.0697,.1888],[-.0811,.1891],[-.0926,.1891],[-.104,.1891],[-.1154,.1893],[-.1269,.1896],[-.1383,.1898],[-.1497,.1897],[-.1612,.1896],[-.1726,.1894],[-.1841,.1893],[-.1955,.1891],[-.2069,.189],[-.2184,.1889],[-.2298,.189],[-.2412,.1898],[-.2527,.192],[-.2641,.1961],[-.2755,.2008],[-.287,.2041],[-.2984,.2054],[-.3099,.2056],[-.3213,.2055],[-.3327,.2053],[-.3442,.2051],[-.3556,.205],[-.367,.2048],[-.3785,.2046],[-.3899,.2045],[-.4013,.2043],[-.4128,.2042],[-.4242,.204],[-.4357,.2038],[-.4471,.2036],[-.4585,.2035],[-.47,.2033],[-.4814,.2032],[-.4928,.203],[-.5043,.2028],[-.5157,.2027],[-.5271,.2025],[-.5386,.2023],[-.55,.2022],[-.5614,.202],[-.5729,.2018],[-.5843,.2017],[-.5958,.2015],[-.6072,.2014],[-.6186,.2012],[-.6301,.2011],[-.6415,.2009],[-.6529,.2007],[-.6644,.2006],[-.6758,.2004],[-.6872,.2003],[-.6987,.2001],[-.7101,.1999],[-.7216,.1998],[-.733,.1996],[-.7444,.1995],[-.7559,.1993],[-.7673,.1991],[-.7787,.199],[-.7902,.1988],[-.8016,.1987],[-.813,.1985],[-.8245,.1984],[-.8359,.1982],[-.8474,.198],[-.8588,.1979],[-.8702,.1977],[-.8817,.1976],[-.8931,.1974],[-.9045,.1973],[-.916,.1971],[-.9274,.197],[-.9388,.1968],[-.9503,.1966],[-.9617,.1965],[-.9732,.1963],[-.9846,.1962],[-.996,.196],[-1.0075,.1959],[-1.0189,.1957],[-1.0303,.1956],[-1.0418,.1954],[-1.0532,.1953],[-1.0646,.1951],[-1.0761,.195],[-1.0875,.1948],[-1.099,.1947],[-1.1104,.1945],[-1.1218,.1944],[-1.1333,.1942],[-1.1447,.1941],[-1.1485,.194]],at:[[0,0]],fins:[{side:-1,uv:[.8562,.9002,.971,1],x0:-.3011,x1:.0015,y0:.5517,y1:.3344,outline:[[.5517,.1865,.1865],[.546,.2012,.1865],[.5402,.2159,.1865],[.5345,.2306,.1865],[.5288,.2423,.1865],[.5231,.2541,.1865],[.5174,.2688,.1865],[.5117,.2834,.1865],[.5059,.2952,.1865],[.5002,.2982,.1865],[.4945,.2982,.1865],[.4888,.2982,.1866],[.4831,.2982,.1866],[.4773,.2982,.1866],[.4716,.2982,.1866],[.4659,.2982,.1867],[.4602,.2952,.1867],[.4545,.2834,.1868],[.4488,.2746,.1869],[.443,.2629,.1869],[.4373,.2541,.187],[.4316,.2453,.1871],[.4259,.2335,.1872],[.4202,.2247,.1873],[.4144,.2247,.1874],[.4087,.2247,.1875],[.403,.2247,.1877],[.3973,.2247,.1879],[.3916,.2247,.188],[.3859,.2247,.1882],[.3801,.2247,.1884],[.3744,.2247,.1886],[.3687,.2218,.1889],[.363,.213,.1891],[.3573,.2042,.1894],[.3515,.1953,.1897],[.3458,.1924,.19],[.3401,.1894,.1904],[.3363,.1894,.1906]]},{side:1,uv:[.8562,.7986,.9721,.8984],x0:-.0015,x1:.304,y0:.5517,y1:.3344,outline:[[.5517,.1865,.1865],[.546,.1953,.1865],[.5402,.2042,.1865],[.5345,.213,.1865],[.5288,.2247,.1865],[.5231,.2365,.1865],[.5174,.2482,.1865],[.5117,.26,.1865],[.5059,.2717,.1865],[.5002,.2805,.1865],[.4945,.2893,.1865],[.4888,.2982,.1866],[.4831,.3011,.1866],[.4773,.3011,.1866],[.4716,.3011,.1866],[.4659,.3011,.1867],[.4602,.3011,.1867],[.4545,.3011,.1868],[.4488,.3011,.1869],[.443,.2952,.1869],[.4373,.2834,.187],[.4316,.2746,.1871],[.4259,.2658,.1872],[.4202,.257,.1873],[.4144,.2453,.1874],[.4087,.2335,.1875],[.403,.2247,.1877],[.3973,.2218,.1879],[.3916,.2218,.188],[.3859,.2218,.1882],[.3801,.2247,.1884],[.3744,.2247,.1886],[.3687,.2247,.1889],[.363,.2247,.1891],[.3573,.2218,.1894],[.3515,.2159,.1897],[.3458,.2071,.19],[.3401,.1983,.1904],[.3363,.1924,.1906]]},{side:-1,uv:[.8562,.4002,.9911,.7968],x0:-.3253,x1:.0013,y0:-.2908,y1:-1.1542,outline:[[-.2908,.2038,.1986],[-.2965,.2065,.1992],[-.3022,.2092,.1995],[-.3079,.2146,.1997],[-.3137,.2146,.1997],[-.3194,.2173,.1998],[-.3251,.22,.1998],[-.3308,.2227,.1998],[-.3365,.2254,.1998],[-.3423,.2281,.1998],[-.348,.2308,.1998],[-.3537,.2335,.1998],[-.3594,.2389,.1998],[-.3651,.2416,.1998],[-.3708,.2443,.1998],[-.3766,.247,.1998],[-.3823,.2497,.1998],[-.388,.2524,.1998],[-.3937,.2551,.1998],[-.3994,.2578,.1998],[-.4052,.2605,.1998],[-.4109,.2632,.1998],[-.4166,.2659,.1998],[-.4223,.2686,.1998],[-.428,.2713,.1998],[-.4337,.274,.1998],[-.4395,.2767,.1998],[-.4452,.2794,.1998],[-.4509,.2821,.1998],[-.4566,.2848,.1998],[-.4623,.2875,.1998],[-.4681,.2902,.1998],[-.4738,.2929,.1998],[-.4795,.2956,.1998],[-.4852,.2983,.1998],[-.4909,.301,.1998],[-.4966,.3037,.1998],[-.5024,.3037,.1998],[-.5081,.3064,.1998],[-.5138,.3091,.1998],[-.5195,.3091,.1998],[-.5252,.3118,.1998],[-.531,.3118,.1998],[-.5367,.3145,.1998],[-.5424,.3145,.1998],[-.5481,.3145,.1998],[-.5538,.3145,.1998],[-.5595,.3145,.1998],[-.5653,.3172,.1998],[-.571,.3172,.1998],[-.5767,.3172,.1998],[-.5824,.3172,.1998],[-.5881,.3172,.1998],[-.5939,.3172,.1998],[-.5996,.3172,.1998],[-.6053,.3172,.1998],[-.611,.3172,.1998],[-.6167,.3172,.1998],[-.6224,.3199,.1998],[-.6282,.3199,.1998],[-.6339,.3199,.1998],[-.6396,.3199,.1998],[-.6453,.3199,.1998],[-.651,.3199,.1998],[-.6568,.3199,.1998],[-.6625,.3199,.1998],[-.6682,.3199,.1998],[-.6739,.3199,.1998],[-.6796,.3199,.1998],[-.6853,.3226,.1998],[-.6911,.3226,.1998],[-.6968,.3226,.1998],[-.7025,.3226,.1998],[-.7082,.3226,.1998],[-.7139,.3226,.1998],[-.7197,.3226,.1998],[-.7254,.3226,.1998],[-.7311,.3199,.1998],[-.7368,.3199,.1998],[-.7425,.3199,.1998],[-.7482,.3199,.1998],[-.754,.3199,.1998],[-.7597,.3172,.1998],[-.7654,.3172,.1998],[-.7711,.3172,.1998],[-.7768,.3172,.1998],[-.7826,.3172,.1998],[-.7883,.3145,.1998],[-.794,.3145,.1998],[-.7997,.3145,.1998],[-.8054,.3145,.1998],[-.8111,.3145,.1998],[-.8169,.3118,.1998],[-.8226,.3118,.1998],[-.8283,.3118,.1998],[-.834,.3118,.1998],[-.8397,.3091,.1998],[-.8454,.3091,.1998],[-.8512,.3091,.1998],[-.8569,.3091,.1998],[-.8626,.3091,.1998],[-.8683,.3091,.1998],[-.874,.3064,.1998],[-.8798,.3064,.1998],[-.8855,.3064,.1998],[-.8912,.3064,.1998],[-.8969,.3064,.1998],[-.9026,.3064,.1998],[-.9083,.3037,.1998],[-.9141,.3037,.1998],[-.9198,.3037,.1998],[-.9255,.3037,.1998],[-.9312,.3037,.1998],[-.9369,.3037,.1998],[-.9427,.3037,.1998],[-.9484,.301,.1998],[-.9541,.301,.1998],[-.9598,.301,.1998],[-.9655,.301,.1998],[-.9712,.301,.1998],[-.977,.2983,.1998],[-.9827,.2983,.1998],[-.9884,.2983,.1998],[-.9941,.2983,.1998],[-.9998,.2983,.1998],[-1.0056,.2956,.1998],[-1.0113,.2956,.1998],[-1.017,.2929,.1998],[-1.0227,.2902,.1998],[-1.0284,.2875,.1998],[-1.0341,.2848,.1998],[-1.0399,.2848,.1998],[-1.0456,.2848,.1998],[-1.0513,.2848,.1998],[-1.057,.2848,.1998],[-1.0627,.2848,.1998],[-1.0685,.2848,.1998],[-1.0742,.2848,.1998],[-1.0799,.2848,.1998],[-1.0856,.2848,.1998],[-1.0913,.2848,.1998],[-1.097,.2848,.1998],[-1.1028,.2848,.1998],[-1.1085,.2848,.1998],[-1.1142,.2848,.1998],[-1.1199,.2848,.1998],[-1.1256,.2848,.1998],[-1.1314,.2821,.1998],[-1.1371,.2821,.1998],[-1.1428,.2794,.1998],[-1.1485,.274,.1998],[-1.1523,.2686,.1998]]},{side:1,uv:[.8562,.0018,.99,.3984],x0:-.0013,x1:.3226,y0:-.2908,y1:-1.1542,outline:[[-.2908,.2038,.1986],[-.2965,.2065,.1992],[-.3022,.2092,.1995],[-.3079,.2119,.1997],[-.3137,.2146,.1997],[-.3194,.2173,.1998],[-.3251,.22,.1998],[-.3308,.2227,.1998],[-.3365,.2281,.1998],[-.3423,.2308,.1998],[-.348,.2335,.1998],[-.3537,.2362,.1998],[-.3594,.2389,.1998],[-.3651,.2416,.1998],[-.3708,.2443,.1998],[-.3766,.247,.1998],[-.3823,.2497,.1998],[-.388,.2524,.1998],[-.3937,.2551,.1998],[-.3994,.2578,.1998],[-.4052,.2605,.1998],[-.4109,.2632,.1998],[-.4166,.2659,.1998],[-.4223,.2686,.1998],[-.428,.2713,.1998],[-.4337,.274,.1998],[-.4395,.2767,.1998],[-.4452,.2794,.1998],[-.4509,.2821,.1998],[-.4566,.2848,.1998],[-.4623,.2875,.1998],[-.4681,.2902,.1998],[-.4738,.2929,.1998],[-.4795,.2956,.1998],[-.4852,.2983,.1998],[-.4909,.301,.1998],[-.4966,.3037,.1998],[-.5024,.3037,.1998],[-.5081,.3064,.1998],[-.5138,.3091,.1998],[-.5195,.3091,.1998],[-.5252,.3118,.1998],[-.531,.3118,.1998],[-.5367,.3118,.1998],[-.5424,.3145,.1998],[-.5481,.3145,.1998],[-.5538,.3145,.1998],[-.5595,.3145,.1998],[-.5653,.3145,.1998],[-.571,.3145,.1998],[-.5767,.3145,.1998],[-.5824,.3172,.1998],[-.5881,.3172,.1998],[-.5939,.3172,.1998],[-.5996,.3172,.1998],[-.6053,.3172,.1998],[-.611,.3172,.1998],[-.6167,.3172,.1998],[-.6224,.3172,.1998],[-.6282,.3172,.1998],[-.6339,.3172,.1998],[-.6396,.3172,.1998],[-.6453,.3172,.1998],[-.651,.3172,.1998],[-.6568,.3199,.1998],[-.6625,.3199,.1998],[-.6682,.3199,.1998],[-.6739,.3199,.1998],[-.6796,.3199,.1998],[-.6853,.3199,.1998],[-.6911,.3199,.1998],[-.6968,.3199,.1998],[-.7025,.3199,.1998],[-.7082,.3199,.1998],[-.7139,.3199,.1998],[-.7197,.3199,.1998],[-.7254,.3199,.1998],[-.7311,.3199,.1998],[-.7368,.3199,.1998],[-.7425,.3199,.1998],[-.7482,.3199,.1998],[-.754,.3172,.1998],[-.7597,.3172,.1998],[-.7654,.3172,.1998],[-.7711,.3172,.1998],[-.7768,.3172,.1998],[-.7826,.3145,.1998],[-.7883,.3145,.1998],[-.794,.3145,.1998],[-.7997,.3145,.1998],[-.8054,.3118,.1998],[-.8111,.3118,.1998],[-.8169,.3118,.1998],[-.8226,.3118,.1998],[-.8283,.3118,.1998],[-.834,.3091,.1998],[-.8397,.3091,.1998],[-.8454,.3091,.1998],[-.8512,.3091,.1998],[-.8569,.3064,.1998],[-.8626,.3064,.1998],[-.8683,.3064,.1998],[-.874,.3064,.1998],[-.8798,.3064,.1998],[-.8855,.3037,.1998],[-.8912,.3037,.1998],[-.8969,.3037,.1998],[-.9026,.3037,.1998],[-.9083,.3037,.1998],[-.9141,.3037,.1998],[-.9198,.3037,.1998],[-.9255,.301,.1998],[-.9312,.301,.1998],[-.9369,.301,.1998],[-.9427,.301,.1998],[-.9484,.301,.1998],[-.9541,.301,.1998],[-.9598,.2983,.1998],[-.9655,.2983,.1998],[-.9712,.2983,.1998],[-.977,.2983,.1998],[-.9827,.2983,.1998],[-.9884,.2983,.1998],[-.9941,.2956,.1998],[-.9998,.2956,.1998],[-1.0056,.2956,.1998],[-1.0113,.2929,.1998],[-1.017,.2902,.1998],[-1.0227,.2875,.1998],[-1.0284,.2875,.1998],[-1.0341,.2848,.1998],[-1.0399,.2848,.1998],[-1.0456,.2848,.1998],[-1.0513,.2848,.1998],[-1.057,.2848,.1998],[-1.0627,.2848,.1998],[-1.0685,.2848,.1998],[-1.0742,.2848,.1998],[-1.0799,.2848,.1998],[-1.0856,.2848,.1998],[-1.0913,.2848,.1998],[-1.097,.2848,.1998],[-1.1028,.2848,.1998],[-1.1085,.2848,.1998],[-1.1142,.2848,.1998],[-1.1199,.2848,.1998],[-1.1256,.2848,.1998],[-1.1314,.2821,.1998],[-1.1371,.2821,.1998],[-1.1428,.2794,.1998],[-1.1485,.2713,.1998],[-1.1523,.2659,.1998]]}],finsAround:2,finsFrom:null,engines:{ring:6,centre:!0,f:.3,colour:[80,79,78],profile:[[-1.1485,.2648],[-1.1523,.2595],[-1.1561,.2516],[-1.1599,.2463],[-1.1638,.241],[-1.1676,.2461],[-1.1714,.2487],[-1.1752,.2512],[-1.179,.2538],[-1.1828,.255],[-1.1866,.2576],[-1.1904,.2601],[-1.1943,.2614],[-1.1981,.2639],[-1.2019,.2652],[-1.2057,.2664],[-1.2095,.2689],[-1.2133,.2702],[-1.2171,.2714],[-1.2209,.2687],[-1.2248,.2543],[-1.2286,.1734],[-1.2324,.1773],[-1.2362,.1759],[-1.24,.1576]]}}],badge:{y:.9137,d:.2768,r:.1845},band:[.7422,.7611],head:{top:1.6,cut:1.0852,mean:.6111,r:.2159}},vulcan:{id:"vulcan",shape:"vulcan",atlas:{w:1160,h:1024,cap:[.9948,.9941,.9983,.998]},parts:[{name:"core",uv:[0,0,.6621,1],top:1.6,end:-1.0752,profile:[[1.6,.0147],[1.5884,.0337],[1.5767,.0482],[1.5651,.0614],[1.5535,.0738],[1.5418,.0854],[1.5302,.0963],[1.5186,.1066],[1.5069,.1166],[1.4953,.1261],[1.4837,.1351],[1.4721,.1436],[1.4604,.1518],[1.4488,.1595],[1.4372,.1668],[1.4255,.1735],[1.4139,.1798],[1.4023,.1856],[1.3906,.1911],[1.379,.1963],[1.3674,.2012],[1.3557,.2057],[1.3441,.2099],[1.3325,.2137],[1.3208,.2171],[1.3092,.2202],[1.2976,.2228],[1.286,.2252],[1.2743,.2273],[1.2627,.229],[1.2511,.2305],[1.2394,.2316],[1.2278,.2323],[1.2162,.2327],[1.2045,.2328],[1.1929,.2326],[1.1813,.2325],[1.1696,.2326],[1.158,.2325],[1.1464,.2325],[1.1347,.2326],[1.1231,.2327],[1.1115,.2326],[1.0998,.2322],[1.0882,.2317],[1.0766,.2315],[1.065,.2314],[1.0533,.2311],[1.0417,.2307],[1.0301,.2306],[1.0184,.2308],[1.0068,.2311],[.9952,.2312],[.9835,.2311],[.9719,.2309],[.9603,.2307],[.9486,.2304],[.937,.2298],[.9254,.2292],[.9137,.2289],[.9021,.2287],[.8905,.2287],[.8789,.2288],[.8672,.229],[.8556,.2289],[.844,.2285],[.8323,.2282],[.8207,.2279],[.8091,.2279],[.7974,.228],[.7858,.2278],[.7742,.2273],[.7625,.227],[.7509,.2266],[.7393,.2254],[.7276,.2226],[.716,.2181],[.7044,.2128],[.6928,.2072],[.6811,.2015],[.6695,.196],[.6579,.1907],[.6462,.1855],[.6346,.1806],[.623,.1765],[.6113,.1743],[.5997,.1747],[.5881,.1766],[.5764,.1791],[.5648,.1818],[.5532,.1846],[.5415,.1876],[.5299,.1906],[.5183,.1938],[.5066,.1969],[.495,.2],[.4834,.2031],[.4718,.2062],[.4601,.2088],[.4485,.2104],[.4369,.2108],[.4252,.2104],[.4136,.2102],[.402,.2102],[.3903,.2101],[.3787,.21],[.3671,.2099],[.3554,.2098],[.3438,.2097],[.3322,.2095],[.3205,.2094],[.3089,.2093],[.2973,.2093],[.2857,.2094],[.274,.2094],[.2624,.2091],[.2508,.2088],[.2391,.2086],[.2275,.2084],[.2159,.2083],[.2042,.2082],[.1926,.208],[.181,.2079],[.1693,.2078],[.1577,.2077],[.1461,.2075],[.1344,.2074],[.1228,.2073],[.1112,.2072],[.0995,.2071],[.0879,.2069],[.0763,.2068],[.0647,.2067],[.053,.2066],[.0414,.2065],[.0298,.2063],[.0181,.2062],[.0065,.2061],[-.0051,.206],[-.0168,.2059],[-.0284,.2057],[-.04,.2056],[-.0517,.2055],[-.0633,.2054],[-.0749,.2052],[-.0866,.2051],[-.0982,.205],[-.1098,.2049],[-.1214,.2048],[-.1331,.2046],[-.1447,.2045],[-.1563,.2044],[-.168,.2043],[-.1796,.2042],[-.1912,.2041],[-.2029,.2039],[-.2145,.2038],[-.2261,.2037],[-.2378,.2036],[-.2494,.2035],[-.261,.2033],[-.2727,.2032],[-.2843,.2031],[-.2959,.203],[-.3075,.2029],[-.3192,.2028],[-.3308,.2026],[-.3424,.2025],[-.3541,.2024],[-.3657,.2023],[-.3773,.2022],[-.389,.202],[-.4006,.2019],[-.4122,.2018],[-.4239,.2017],[-.4355,.2016],[-.4471,.2015],[-.4588,.2013],[-.4704,.2012],[-.482,.2011],[-.4937,.201],[-.5053,.2009],[-.5169,.2008],[-.5285,.2007],[-.5402,.2005],[-.5518,.2004],[-.5634,.2003],[-.5751,.2002],[-.5867,.2001],[-.5983,.2],[-.61,.1999],[-.6216,.1997],[-.6332,.1996],[-.6449,.1995],[-.6565,.1994],[-.6681,.1993],[-.6798,.1992],[-.6914,.1991],[-.703,.199],[-.7146,.1988],[-.7263,.1987],[-.7379,.1986],[-.7495,.1985],[-.7612,.1984],[-.7728,.1983],[-.7844,.1982],[-.7961,.1981],[-.8077,.1979],[-.8193,.1978],[-.831,.1977],[-.8426,.1976],[-.8542,.1975],[-.8659,.1974],[-.8775,.1973],[-.8891,.1972],[-.9008,.1971],[-.9124,.1969],[-.924,.1968],[-.9356,.1967],[-.9473,.1966],[-.9589,.1965],[-.9705,.1964],[-.9822,.1963],[-.9938,.1962],[-1.0054,.1961],[-1.0171,.196],[-1.0287,.1958],[-1.0403,.1957],[-1.052,.1956],[-1.0636,.1955],[-1.0752,.1954]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:2,centre:!1,f:.5,colour:[62,59,55],profile:[[-1.0752,.1556],[-1.0791,.1542],[-1.083,.1516],[-1.0869,.149],[-1.0907,.1464],[-1.0946,.1464],[-1.0985,.1464],[-1.1024,.1489],[-1.1062,.1489],[-1.1101,.1514],[-1.114,.1527],[-1.1179,.154],[-1.1217,.1565],[-1.1256,.159],[-1.1295,.159],[-1.1334,.1615],[-1.1373,.1628],[-1.1411,.164],[-1.145,.1653],[-1.1489,.1665],[-1.1528,.1691],[-1.1566,.169],[-1.1605,.1716],[-1.1644,.1715],[-1.1683,.1728],[-1.1722,.174],[-1.176,.1753],[-1.1799,.1765],[-1.1838,.1778],[-1.1877,.179],[-1.1915,.1803],[-1.1954,.1802],[-1.1993,.1827],[-1.2032,.1827],[-1.207,.184],[-1.2109,.1852],[-1.2148,.1852],[-1.2187,.1864],[-1.2226,.1864],[-1.2264,.1863],[-1.2303,.1812],[-1.2342,.1684],[-1.2381,.1416]]}},{name:"booster",uv:[.6621,.3447,.9931,1],top:.2159,end:-1.083,profile:[[.2159,.0039],[.2042,.011],[.1926,.0173],[.181,.0238],[.1693,.0299],[.1577,.0355],[.1461,.041],[.1344,.0465],[.1228,.0521],[.1112,.0579],[.0995,.0635],[.0879,.069],[.0763,.0741],[.0647,.0782],[.053,.0806],[.0414,.0813],[.0298,.0814],[.0181,.0815],[.0065,.0818],[-.0051,.0826],[-.0168,.0834],[-.0284,.0838],[-.04,.0839],[-.0517,.0838],[-.0633,.0838],[-.0749,.0837],[-.0866,.0837],[-.0982,.0838],[-.1098,.0839],[-.1214,.0837],[-.1331,.0835],[-.1447,.0834],[-.1563,.0834],[-.168,.0833],[-.1796,.0833],[-.1912,.0832],[-.2029,.0832],[-.2145,.0831],[-.2261,.0831],[-.2378,.0831],[-.2494,.083],[-.261,.0829],[-.2727,.0829],[-.2843,.0829],[-.2959,.0828],[-.3075,.0828],[-.3192,.0829],[-.3308,.083],[-.3424,.0828],[-.3541,.0826],[-.3657,.0825],[-.3773,.0825],[-.389,.0824],[-.4006,.0824],[-.4122,.0823],[-.4239,.0823],[-.4355,.0822],[-.4471,.0822],[-.4588,.0821],[-.4704,.0821],[-.482,.0821],[-.4937,.0821],[-.5053,.0821],[-.5169,.0822],[-.5285,.0821],[-.5402,.0819],[-.5518,.0818],[-.5634,.0817],[-.5751,.0817],[-.5867,.0816],[-.5983,.0816],[-.61,.0815],[-.6216,.0815],[-.6332,.0814],[-.6449,.0814],[-.6565,.0813],[-.6681,.0813],[-.6798,.0813],[-.6914,.0813],[-.703,.0813],[-.7146,.0812],[-.7263,.0811],[-.7379,.081],[-.7495,.081],[-.7612,.0809],[-.7728,.0809],[-.7844,.0808],[-.7961,.0808],[-.8077,.0807],[-.8193,.0807],[-.831,.0806],[-.8426,.0806],[-.8542,.0806],[-.8659,.0806],[-.8775,.0807],[-.8891,.0808],[-.9008,.0808],[-.9124,.0805],[-.924,.0803],[-.9356,.0803],[-.9473,.0802],[-.9589,.0801],[-.9705,.0801],[-.9822,.0801],[-.9938,.08],[-1.0054,.08],[-1.0171,.0799],[-1.0287,.0798],[-1.0403,.0792],[-1.052,.0775],[-1.0636,.0749],[-1.0752,.0726],[-1.083,.0715]],at:[[-1.5708,.3099],[1.5708,.3099]],fins:[],finsAround:0,finsFrom:null,engines:{ring:0,centre:!0,f:1,colour:[88,83,79],profile:[[-1.083,.0694],[-1.0869,.0668],[-1.0907,.0668],[-1.0946,.0668],[-1.0985,.0642],[-1.1024,.0642],[-1.1062,.0616],[-1.1101,.0539],[-1.114,.0462],[-1.1179,.0462],[-1.1217,.0462],[-1.1256,.0487],[-1.1295,.0487],[-1.1334,.0513],[-1.1373,.0513],[-1.1411,.0538],[-1.145,.0538],[-1.1489,.0564],[-1.1528,.0564],[-1.1566,.0589],[-1.1605,.0589],[-1.1644,.0614],[-1.1683,.0614],[-1.1722,.064],[-1.176,.064],[-1.1799,.0665],[-1.1838,.0665],[-1.1877,.069],[-1.1915,.069],[-1.1954,.0716],[-1.1993,.0716],[-1.2032,.0741],[-1.207,.0741],[-1.2109,.0664],[-1.2148,.0281]]}}],badge:{y:.9137,d:.3434,r:.2289},band:[.7089,.7278],head:{top:1.6,cut:1.1185,mean:.8006,r:.2444}},cz2f:{id:"long-march-2f",shape:"cz2f",atlas:{w:1160,h:1024,cap:[.9948,.9941,.9983,.998]},parts:[{name:"core",uv:[0,0,.6621,1],top:1.5981,end:-1.1021,profile:[[1.5981,.0102],[1.5864,.0199],[1.5747,.0267],[1.5631,.031],[1.5514,.0329],[1.5398,.0333],[1.5281,.0336],[1.5165,.0345],[1.5048,.0363],[1.4932,.0387],[1.4815,.0404],[1.4698,.0395],[1.4582,.0379],[1.4465,.0378],[1.4349,.0389],[1.4232,.0405],[1.4116,.0435],[1.3999,.0497],[1.3883,.0568],[1.3766,.0581],[1.365,.0526],[1.3533,.047],[1.3416,.0455],[1.33,.0466],[1.3183,.0486],[1.3067,.0508],[1.295,.0533],[1.2834,.0559],[1.2717,.0587],[1.2601,.0614],[1.2484,.064],[1.2367,.0668],[1.2251,.07],[1.2134,.074],[1.2018,.0791],[1.1901,.084],[1.1785,.0891],[1.1668,.0963],[1.1552,.1056],[1.1435,.1157],[1.1318,.1259],[1.1202,.1358],[1.1085,.1455],[1.0969,.1551],[1.0852,.1644],[1.0736,.1734],[1.0619,.1818],[1.0503,.1889],[1.0386,.1945],[1.0269,.1982],[1.0153,.1999],[1.0036,.2004],[.992,.2006],[.9803,.201],[.9687,.2016],[.957,.202],[.9454,.202],[.9337,.202],[.9221,.2021],[.9104,.2028],[.8987,.2042],[.8871,.2056],[.8754,.2056],[.8638,.2041],[.8521,.2024],[.8405,.2015],[.8288,.2012],[.8172,.2011],[.8055,.2012],[.7938,.2016],[.7822,.2024],[.7705,.2026],[.7589,.2016],[.7472,.1997],[.7356,.1962],[.7239,.1908],[.7123,.1844],[.7006,.1786],[.6889,.175],[.6773,.1736],[.6656,.1731],[.654,.1728],[.6423,.1731],[.6307,.1738],[.619,.1735],[.6074,.1717],[.5957,.1696],[.584,.1682],[.5724,.1675],[.5607,.1676],[.5491,.1681],[.5374,.1686],[.5258,.1688],[.5141,.1687],[.5025,.1686],[.4908,.1686],[.4792,.1687],[.4675,.1694],[.4558,.1707],[.4442,.172],[.4325,.1724],[.4209,.1718],[.4092,.1709],[.3976,.1703],[.3859,.1701],[.3743,.1704],[.3626,.171],[.3509,.1715],[.3393,.1716],[.3276,.1716],[.316,.1715],[.3043,.1716],[.2927,.1722],[.281,.1732],[.2694,.174],[.2577,.1738],[.246,.1733],[.2344,.173],[.2227,.1731],[.2111,.1736],[.1994,.174],[.1878,.1737],[.1761,.1728],[.1645,.1719],[.1528,.1716],[.1411,.1719],[.1295,.1721],[.1178,.172],[.1062,.1715],[.0945,.1712],[.0829,.1713],[.0712,.1713],[.0596,.1713],[.0479,.1715],[.0363,.1717],[.0246,.1717],[.0129,.1716],[.0013,.1716],[-.0104,.1717],[-.022,.1719],[-.0337,.1721],[-.0453,.1718],[-.057,.1714],[-.0686,.1711],[-.0803,.1711],[-.092,.171],[-.1036,.1709],[-.1153,.1708],[-.1269,.1707],[-.1386,.1707],[-.1502,.1706],[-.1619,.1705],[-.1735,.1705],[-.1852,.1704],[-.1969,.1703],[-.2085,.1703],[-.2202,.1702],[-.2318,.1701],[-.2435,.1701],[-.2551,.17],[-.2668,.1699],[-.2784,.1698],[-.2901,.1698],[-.3018,.1697],[-.3134,.1696],[-.3251,.1696],[-.3367,.1695],[-.3484,.1694],[-.36,.1694],[-.3717,.1693],[-.3833,.1692],[-.395,.1692],[-.4066,.1691],[-.4183,.169],[-.43,.1689],[-.4416,.1689],[-.4533,.1688],[-.4649,.1687],[-.4766,.1687],[-.4882,.1686],[-.4999,.1685],[-.5115,.1684],[-.5232,.1684],[-.5349,.1683],[-.5465,.1682],[-.5582,.1682],[-.5698,.1681],[-.5815,.168],[-.5931,.168],[-.6048,.1679],[-.6164,.1678],[-.6281,.1678],[-.6398,.1677],[-.6514,.1677],[-.6631,.1676],[-.6747,.1675],[-.6864,.1674],[-.698,.1674],[-.7097,.1673],[-.7213,.1672],[-.733,.1671],[-.7447,.1671],[-.7563,.167],[-.768,.1669],[-.7796,.1669],[-.7913,.1668],[-.8029,.1667],[-.8146,.1667],[-.8262,.1666],[-.8379,.1665],[-.8495,.1665],[-.8612,.1664],[-.8729,.1663],[-.8845,.1663],[-.8962,.1662],[-.9078,.1661],[-.9195,.1661],[-.9311,.166],[-.9428,.1659],[-.9544,.1659],[-.9661,.1658],[-.9778,.1657],[-.9894,.1657],[-1.0011,.1656],[-1.0127,.1655],[-1.0244,.1655],[-1.036,.1654],[-1.0477,.1654],[-1.0593,.1653],[-1.071,.1652],[-1.0827,.1652],[-1.0943,.1651],[-1.1021,.165]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:4,centre:!1,f:.42,colour:[76,74,72],profile:[[-1.1021,.3699],[-1.106,.3661],[-1.1098,.2617],[-1.1137,.3565],[-1.1176,.2597],[-1.1215,.2616],[-1.1254,.1516],[-1.1293,.1308],[-1.1332,.1194],[-1.137,.1213],[-1.1409,.1212],[-1.1448,.1174],[-1.1487,.1098],[-1.1526,.1041],[-1.1565,.0985],[-1.1604,.0965],[-1.1642,.089],[-1.1681,.0908],[-1.172,.0927],[-1.1759,.0965],[-1.1798,.1003],[-1.1837,.1021],[-1.1876,.104],[-1.1914,.1078],[-1.1953,.1097],[-1.1992,.1134],[-1.2031,.1153],[-1.207,.2344],[-1.2109,.1191],[-1.2147,.1228],[-1.2186,.1228],[-1.2225,.1266],[-1.2264,.1303],[-1.2303,.1265],[-1.2342,.1171],[-1.2381,.0869]]}},{name:"booster",uv:[.6621,.5381,.9931,1],top:-.1852,end:-1.1021,profile:[[-.1852,.0175],[-.1969,.044],[-.2085,.0547],[-.2202,.0633],[-.2318,.0716],[-.2435,.0795],[-.2551,.0873],[-.2668,.0951],[-.2784,.1029],[-.2901,.1109],[-.3018,.1189],[-.3134,.1266],[-.3251,.1336],[-.3367,.1393],[-.3484,.1427],[-.36,.1441],[-.3717,.1444],[-.3833,.1443],[-.395,.144],[-.4066,.1438],[-.4183,.1438],[-.43,.1437],[-.4416,.1437],[-.4533,.1436],[-.4649,.1435],[-.4766,.1435],[-.4882,.1434],[-.4999,.1434],[-.5115,.1437],[-.5232,.1444],[-.5349,.1454],[-.5465,.1462],[-.5582,.1467],[-.5698,.1468],[-.5815,.1468],[-.5931,.1467],[-.6048,.1467],[-.6164,.1466],[-.6281,.1466],[-.6398,.1465],[-.6514,.1464],[-.6631,.1464],[-.6747,.1463],[-.6864,.1463],[-.698,.1462],[-.7097,.1462],[-.7213,.1461],[-.733,.146],[-.7447,.146],[-.7563,.1462],[-.768,.1466],[-.7796,.1467],[-.7913,.1466],[-.8029,.1472],[-.8146,.1483],[-.8262,.149],[-.8379,.1493],[-.8495,.1492],[-.8612,.1492],[-.8729,.1491],[-.8845,.1491],[-.8962,.149],[-.9078,.149],[-.9195,.1489],[-.9311,.1489],[-.9428,.1489],[-.9544,.1492],[-.9661,.1502],[-.9778,.1514],[-.9894,.1521],[-1.0011,.1523],[-1.0127,.1522],[-1.0244,.1521],[-1.036,.1521],[-1.0477,.152],[-1.0593,.151],[-1.071,.1467],[-1.0827,.1367],[-1.0943,.1241],[-1.1021,.117]],at:[[.7854,.401],[2.3562,.401],[3.927,.401],[5.4978,.401]],fins:[],finsAround:0,finsFrom:null,engines:{ring:0,centre:!0,f:1,colour:[76,73,70],profile:[[-1.1021,.1024],[-1.106,.0986],[-1.1098,.0948],[-1.1137,.0834],[-1.1176,.0834],[-1.1215,.0834],[-1.1254,.091],[-1.1293,.091],[-1.1332,.0834],[-1.137,.0872],[-1.1409,.0909],[-1.1448,.0909],[-1.1487,.0947],[-1.1526,.0985],[-1.1565,.1022],[-1.1604,.1022],[-1.1642,.106],[-1.1681,.1098],[-1.172,.1098],[-1.1759,.1135],[-1.1798,.1135],[-1.1837,.1173],[-1.1876,.1173],[-1.1914,.121],[-1.1953,.1248],[-1.1992,.1248],[-1.2031,.1172],[-1.207,.0869]]}}],badge:{y:.9137,d:.3036,r:.2024},band:[.7287,.7477],head:{top:1.1835,cut:1.0702,mean:.8821,r:.2161}},cz5:{id:"long-march-5",shape:"cz5",atlas:{w:1255,h:1024,cap:[.9952,.9941,.9984,.998]},parts:[{name:"core",uv:[0,0,.612,1],top:1.6,end:-1.0981,profile:[[1.6,.0202],[1.5882,.049],[1.5763,.0688],[1.5645,.0849],[1.5527,.0991],[1.5409,.1121],[1.529,.1238],[1.5172,.1345],[1.5054,.1444],[1.4936,.1537],[1.4817,.1625],[1.4699,.1705],[1.4581,.178],[1.4463,.1849],[1.4344,.1914],[1.4226,.1974],[1.4108,.2032],[1.399,.2087],[1.3871,.2138],[1.3753,.2184],[1.3635,.2226],[1.3517,.2265],[1.3398,.2299],[1.328,.233],[1.3162,.2358],[1.3044,.2382],[1.2925,.2403],[1.2807,.2419],[1.2689,.2431],[1.2571,.2438],[1.2452,.2441],[1.2334,.2438],[1.2216,.2435],[1.2098,.2432],[1.1979,.2431],[1.1861,.2429],[1.1743,.2428],[1.1625,.2427],[1.1506,.2429],[1.1388,.2432],[1.127,.2434],[1.1152,.2434],[1.1033,.2433],[1.0915,.2431],[1.0797,.243],[1.0679,.2428],[1.056,.2427],[1.0442,.2425],[1.0324,.2424],[1.0206,.2422],[1.0087,.2421],[.9969,.242],[.9851,.2419],[.9733,.2422],[.9614,.2425],[.9496,.2429],[.9378,.2433],[.926,.2436],[.9141,.2436],[.9023,.2435],[.8905,.2434],[.8787,.2433],[.8668,.2431],[.855,.243],[.8432,.2428],[.8314,.2427],[.8195,.2426],[.8077,.2425],[.7959,.2417],[.7841,.2397],[.7722,.2367],[.7604,.2331],[.7486,.2294],[.7368,.2257],[.7249,.2223],[.7131,.2192],[.7013,.2166],[.6895,.2143],[.6776,.2123],[.6658,.2109],[.654,.2104],[.6422,.2102],[.6303,.2103],[.6185,.2105],[.6067,.2102],[.5949,.2098],[.583,.2095],[.5712,.2094],[.5594,.2092],[.5476,.2091],[.5357,.209],[.5239,.2089],[.5121,.2087],[.5003,.2086],[.4884,.2085],[.4766,.2084],[.4648,.2083],[.453,.2081],[.4411,.208],[.4293,.2079],[.4175,.2078],[.4057,.2076],[.3938,.2075],[.382,.2074],[.3702,.2073],[.3584,.2072],[.3465,.207],[.3347,.2069],[.3229,.2068],[.3111,.2067],[.2992,.2065],[.2874,.2064],[.2756,.2063],[.2638,.2062],[.2519,.2061],[.2401,.2059],[.2283,.2058],[.2165,.2057],[.2046,.2056],[.1928,.2054],[.181,.2053],[.1692,.2052],[.1573,.2051],[.1455,.205],[.1337,.2048],[.1219,.2047],[.11,.2046],[.0982,.2045],[.0864,.2044],[.0746,.2042],[.0627,.2041],[.0509,.204],[.0391,.2039],[.0273,.2038],[.0154,.2037],[.0036,.2036],[-.0082,.2034],[-.02,.2033],[-.0319,.2032],[-.0437,.2031],[-.0555,.2029],[-.0673,.2028],[-.0792,.2027],[-.091,.2026],[-.1028,.2025],[-.1146,.2024],[-.1265,.2023],[-.1383,.2021],[-.1501,.202],[-.1619,.2019],[-.1738,.2018],[-.1856,.2017],[-.1974,.2015],[-.2092,.2014],[-.2211,.2013],[-.2329,.2012],[-.2447,.2011],[-.2565,.201],[-.2684,.2009],[-.2802,.2007],[-.292,.2006],[-.3038,.2005],[-.3157,.2004],[-.3275,.2003],[-.3393,.2002],[-.3511,.2001],[-.363,.1999],[-.3748,.1998],[-.3866,.1997],[-.3984,.1996],[-.4103,.1995],[-.4221,.1994],[-.4339,.1993],[-.4457,.1991],[-.4576,.199],[-.4694,.1989],[-.4812,.1988],[-.493,.1987],[-.5049,.1986],[-.5167,.1985],[-.5285,.1984],[-.5403,.1982],[-.5522,.1981],[-.564,.198],[-.5758,.1979],[-.5876,.1978],[-.5995,.1977],[-.6113,.1976],[-.6231,.1975],[-.6349,.1974],[-.6468,.1973],[-.6586,.1971],[-.6704,.197],[-.6822,.1969],[-.6941,.1968],[-.7059,.1967],[-.7177,.1966],[-.7295,.1965],[-.7414,.1964],[-.7532,.1963],[-.765,.1962],[-.7768,.196],[-.7887,.1959],[-.8005,.1958],[-.8123,.1957],[-.8241,.1956],[-.836,.1955],[-.8478,.1954],[-.8596,.1953],[-.8715,.1952],[-.8833,.1951],[-.8951,.1949],[-.9069,.1948],[-.9188,.1947],[-.9306,.1946],[-.9424,.1945],[-.9542,.1944],[-.9661,.1943],[-.9779,.1942],[-.9897,.1941],[-1.0015,.194],[-1.0134,.1939],[-1.0252,.1938],[-1.037,.1936],[-1.0488,.1935],[-1.0607,.1934],[-1.0725,.1933],[-1.0843,.1932],[-1.0961,.1931]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:2,centre:!1,f:.5,colour:[44,40,35],profile:[[-1.0981,.178],[-1.102,.1792],[-1.106,.1804],[-1.1099,.1829],[-1.1139,.1841],[-1.1178,.1854],[-1.1217,.1878],[-1.1257,.1903],[-1.1296,.1903],[-1.1336,.1928],[-1.1375,.1927],[-1.1415,.1952],[-1.1454,.1977],[-1.1493,.1977],[-1.1533,.1989],[-1.1572,.2001],[-1.1612,.2001],[-1.1651,.2026],[-1.169,.2025],[-1.173,.2037],[-1.1769,.205],[-1.1809,.2049],[-1.1848,.2061],[-1.1888,.2074],[-1.1927,.2086],[-1.1966,.2085],[-1.2006,.211],[-1.2045,.211],[-1.2085,.2109],[-1.2124,.2122],[-1.2163,.2134],[-1.2203,.2133],[-1.2242,.2133],[-1.2282,.2133],[-1.2321,.2082],[-1.2361,.1906],[-1.24,.1379]]}},{name:"booster",uv:[.612,.25,.9179,1],top:.4135,end:-1.0981,profile:[[.4135,.0016],[.4017,.009],[.3899,.0182],[.3781,.0264],[.3662,.0345],[.3544,.0426],[.3426,.0507],[.3308,.0587],[.3189,.0664],[.3071,.0742],[.2953,.0822],[.2835,.0903],[.2716,.0983],[.2598,.1064],[.248,.1142],[.2362,.1214],[.2243,.1275],[.2125,.1321],[.2007,.1346],[.1889,.1356],[.177,.1355],[.1652,.1345],[.1534,.1334],[.1416,.1328],[.1297,.1325],[.1179,.1325],[.1061,.1324],[.0943,.1323],[.0824,.1322],[.0706,.1322],[.0588,.1325],[.047,.1333],[.0351,.134],[.0233,.1344],[.0115,.1344],[-3e-4,.1344],[-.0122,.1343],[-.024,.1345],[-.0358,.1352],[-.0476,.136],[-.0595,.1364],[-.0713,.1365],[-.0831,.1366],[-.0949,.1368],[-.1068,.137],[-.1186,.1369],[-.1304,.1369],[-.1422,.1375],[-.1541,.1381],[-.1659,.1384],[-.1777,.1385],[-.1895,.1384],[-.2014,.1383],[-.2132,.1383],[-.225,.1384],[-.2368,.1389],[-.2487,.1397],[-.2605,.1402],[-.2723,.1404],[-.2841,.1403],[-.296,.1403],[-.3078,.1402],[-.3196,.1402],[-.3314,.1405],[-.3433,.1412],[-.3551,.1419],[-.3669,.1423],[-.3787,.1423],[-.3906,.1422],[-.4024,.1422],[-.4142,.1421],[-.426,.1421],[-.4379,.1425],[-.4497,.1432],[-.4615,.1439],[-.4733,.1442],[-.4852,.1442],[-.497,.1441],[-.5088,.144],[-.5206,.144],[-.5325,.144],[-.5443,.1443],[-.5561,.1449],[-.5679,.1457],[-.5798,.146],[-.5916,.146],[-.6034,.146],[-.6152,.1459],[-.6271,.1458],[-.6389,.1458],[-.6507,.1459],[-.6625,.1464],[-.6744,.1471],[-.6862,.1477],[-.698,.1479],[-.7098,.1478],[-.7217,.1478],[-.7335,.148],[-.7453,.1486],[-.7571,.1494],[-.769,.1498],[-.7808,.1499],[-.7926,.1498],[-.8044,.1497],[-.8163,.1496],[-.8281,.1496],[-.8399,.1498],[-.8517,.1504],[-.8636,.1517],[-.8754,.1537],[-.8872,.1562],[-.899,.1592],[-.9109,.1625],[-.9227,.1659],[-.9345,.1692],[-.9463,.1724],[-.9582,.1752],[-.97,.1775],[-.9818,.1791],[-.9936,.1799],[-1.0055,.1798],[-1.0173,.1785],[-1.0291,.176],[-1.0409,.172],[-1.0528,.1664],[-1.0646,.1592],[-1.0764,.1512],[-1.0882,.1438],[-1.0961,.14]],at:[[1.0297,.5171],[2.6005,.5171],[-1.0297,.5171],[-2.6005,.5171]],fins:[{side:-1,uv:[.9179,.8867,.9936,1],x0:-.24,x1:.0013,y0:-.8577,y1:-1.0863,outline:[[-.8577,.1562,.1502],[-.8636,.1587,.1509],[-.8695,.1613,.1519],[-.8754,.1638,.153],[-.8813,.1689,.1542],[-.8872,.1714,.1556],[-.8931,.1739,.1571],[-.899,.179,.1587],[-.905,.1815,.1603],[-.9109,.1841,.162],[-.9168,.1892,.1638],[-.9227,.1917,.1655],[-.9286,.1943,.1672],[-.9345,.1968,.1689],[-.9404,.2019,.1706],[-.9463,.2044,.1722],[-.9523,.2069,.1737],[-.9582,.212,.1751],[-.9641,.2146,.1763],[-.97,.2171,.1775],[-.9759,.2196,.1784],[-.9818,.2247,.1792],[-.9877,.2273,.1798],[-.9936,.2298,.1801],[-.9996,.2349,.1802],[-1.0055,.2374,.1801],[-1.0114,.2374,.1796],[-1.0173,.2374,.1789],[-1.0232,.2374,.1778],[-1.0291,.2374,.1764],[-1.035,.2374,.1747],[-1.0409,.2374,.1725],[-1.0469,.2374,.17],[-1.0528,.2374,.167],[-1.0587,.2374,.1636],[-1.0646,.2374,.1599],[-1.0705,.2374,.1559],[-1.0764,.2044,.1519],[-1.0823,.1511,.148],[-1.0843,.146,.1468]]}],finsAround:2,finsFrom:null,engines:{ring:2,centre:!1,f:.5,colour:[60,59,58],profile:[[-1.0981,.13],[-1.102,.1274],[-1.106,.1299],[-1.1099,.1324],[-1.1139,.1324],[-1.1178,.1248],[-1.1217,.1248],[-1.1257,.1273],[-1.1296,.1298],[-1.1336,.1323],[-1.1375,.1348],[-1.1415,.1373],[-1.1454,.1398],[-1.1493,.1398],[-1.1533,.1422],[-1.1572,.1447],[-1.1612,.1447],[-1.1651,.1472],[-1.169,.1497],[-1.173,.1497],[-1.1769,.1522],[-1.1809,.1521],[-1.1848,.1546],[-1.1888,.1546],[-1.1927,.1571],[-1.1966,.157],[-1.2006,.1595],[-1.2045,.1595],[-1.2085,.1595],[-1.2124,.1619],[-1.2163,.1619],[-1.2203,.1569],[-1.2242,.1343]]}}],badge:{y:.9137,d:.3654,r:.2436},band:[.6978,.7168],head:{top:1.6,cut:1.1295,mean:.7207,r:.2563}},cz3b:{id:"long-march-3b",shape:"cz3b",atlas:{w:1237,h:1024,cap:[.9951,.9941,.9984,.998]},parts:[{name:"core",uv:[0,0,.6209,1],top:1.6,end:-1.2151,profile:[[1.6,.0174],[1.5885,.0445],[1.577,.0633],[1.5656,.0779],[1.5541,.0909],[1.5426,.1025],[1.5311,.1132],[1.5196,.123],[1.5081,.132],[1.4967,.1404],[1.4852,.1483],[1.4737,.1559],[1.4622,.1632],[1.4507,.1703],[1.4392,.1771],[1.4278,.1835],[1.4163,.1897],[1.4048,.1958],[1.3933,.2018],[1.3818,.2076],[1.3704,.2131],[1.3589,.2183],[1.3474,.2234],[1.3359,.2283],[1.3244,.2329],[1.3129,.2372],[1.3015,.241],[1.29,.2443],[1.2785,.2466],[1.267,.2478],[1.2555,.2481],[1.244,.2481],[1.2326,.2481],[1.2211,.248],[1.2096,.2479],[1.1981,.2478],[1.1866,.2477],[1.1751,.2476],[1.1637,.2475],[1.1522,.2474],[1.1407,.2474],[1.1292,.2473],[1.1177,.2472],[1.1063,.2471],[1.0948,.2471],[1.0833,.2473],[1.0718,.2481],[1.0603,.2489],[1.0488,.2493],[1.0374,.2489],[1.0259,.2484],[1.0144,.248],[1.0029,.2477],[.9914,.2466],[.9799,.2438],[.9685,.2389],[.957,.2325],[.9455,.2257],[.934,.2189],[.9225,.2123],[.9111,.2059],[.8996,.1994],[.8881,.1928],[.8766,.1863],[.8651,.1804],[.8536,.1756],[.8422,.1725],[.8307,.1715],[.8192,.1724],[.8077,.1746],[.7962,.1766],[.7847,.1777],[.7733,.1776],[.7618,.1767],[.7503,.1753],[.7388,.174],[.7273,.1734],[.7158,.1731],[.7044,.1731],[.6929,.1731],[.6814,.1734],[.6699,.1738],[.6584,.174],[.647,.1742],[.6355,.1742],[.624,.1742],[.6125,.1741],[.601,.174],[.5895,.174],[.5781,.1739],[.5666,.1738],[.5551,.1738],[.5436,.1737],[.5321,.1737],[.5206,.1736],[.5092,.1735],[.4977,.1735],[.4862,.1734],[.4747,.1734],[.4632,.1733],[.4518,.1733],[.4403,.1733],[.4288,.1737],[.4173,.1746],[.4058,.1757],[.3943,.1764],[.3829,.176],[.3714,.1748],[.3599,.1736],[.3484,.1729],[.3369,.1727],[.3254,.1726],[.314,.1725],[.3025,.1725],[.291,.1724],[.2795,.1723],[.268,.1723],[.2565,.1724],[.2451,.1728],[.2336,.1732],[.2221,.1735],[.2106,.1735],[.1991,.1734],[.1877,.1734],[.1762,.1734],[.1647,.1733],[.1532,.1733],[.1417,.1734],[.1302,.1737],[.1188,.1741],[.1073,.1743],[.0958,.1743],[.0843,.1741],[.0728,.1741],[.0613,.1742],[.0499,.1742],[.0384,.1743],[.0269,.1746],[.0154,.1751],[.0039,.1751],[-.0075,.1745],[-.019,.1735],[-.0305,.1727],[-.042,.1719],[-.0535,.1712],[-.065,.1705],[-.0764,.1699],[-.0879,.1693],[-.0994,.1687],[-.1109,.1682],[-.1224,.1677],[-.1339,.1673],[-.1453,.1669],[-.1568,.1665],[-.1683,.1661],[-.1798,.1658],[-.1913,.1654],[-.2027,.1652],[-.2142,.1649],[-.2257,.1647],[-.2372,.1645],[-.2487,.1643],[-.2602,.1641],[-.2716,.164],[-.2831,.1639],[-.2946,.1638],[-.3061,.1637],[-.3176,.1637],[-.3291,.1637],[-.3405,.1637],[-.352,.1637],[-.3635,.1637],[-.375,.1637],[-.3865,.1638],[-.398,.1639],[-.4094,.164],[-.4209,.1641],[-.4324,.1642],[-.4439,.1643],[-.4554,.1645],[-.4668,.1646],[-.4783,.1648],[-.4898,.165],[-.5013,.1652],[-.5128,.1653],[-.5243,.1656],[-.5357,.1658],[-.5472,.166],[-.5587,.1662],[-.5702,.1664],[-.5817,.1666],[-.5932,.1669],[-.6046,.1671],[-.6161,.1673],[-.6276,.1676],[-.6391,.1678],[-.6506,.1681],[-.662,.1683],[-.6735,.1685],[-.685,.1688],[-.6965,.169],[-.708,.1692],[-.7195,.1694],[-.7309,.1697],[-.7424,.1699],[-.7539,.1701],[-.7654,.1703],[-.7769,.1705],[-.7884,.1707],[-.7998,.1708],[-.8113,.171],[-.8228,.1712],[-.8343,.1713],[-.8458,.1715],[-.8573,.1716],[-.8687,.1717],[-.8802,.1718],[-.8917,.1719],[-.9032,.1719],[-.9147,.172],[-.9261,.172],[-.9376,.172],[-.9491,.172],[-.9606,.172],[-.9721,.172],[-.9836,.1719],[-.995,.1718],[-1.0065,.1715],[-1.018,.171],[-1.0295,.1704],[-1.041,.1701],[-1.0525,.1709],[-1.0639,.1729],[-1.0754,.1758],[-1.0869,.1786],[-1.0984,.1792],[-1.1099,.1746],[-1.1213,.1659],[-1.1328,.1608],[-1.1443,.1637],[-1.1558,.1708],[-1.1673,.1781],[-1.1788,.1843],[-1.1902,.1893],[-1.2017,.1929],[-1.2132,.1951]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:4,centre:!1,f:.45,colour:[46,44,42],profile:[[-1.2151,.1986],[-1.2189,.2],[-1.2228,.2],[-1.2266,.2014],[-1.2304,.197],[-1.2343,.1868],[-1.2381,.1649]]}},{name:"booster",uv:[.6209,.4502,.9313,1],top:-.0363,end:-1.1118,profile:[[-.0363,.0057],[-.0477,.0241],[-.0592,.0337],[-.0707,.0416],[-.0822,.0486],[-.0937,.0552],[-.1051,.0617],[-.1166,.0681],[-.1281,.0747],[-.1396,.0814],[-.1511,.0881],[-.1626,.0944],[-.174,.0998],[-.1855,.1037],[-.197,.1058],[-.2085,.1066],[-.22,.1067],[-.2315,.1067],[-.2429,.1066],[-.2544,.1068],[-.2659,.1073],[-.2774,.1083],[-.2889,.1091],[-.3004,.1094],[-.3118,.1094],[-.3233,.1094],[-.3348,.1093],[-.3463,.1093],[-.3578,.1092],[-.3692,.1092],[-.3807,.1092],[-.3922,.1092],[-.4037,.1091],[-.4152,.1091],[-.4267,.109],[-.4381,.109],[-.4496,.109],[-.4611,.1089],[-.4726,.1089],[-.4841,.1088],[-.4956,.1088],[-.507,.1088],[-.5185,.1088],[-.53,.1087],[-.5415,.1087],[-.553,.1086],[-.5644,.1086],[-.5759,.1086],[-.5874,.1085],[-.5989,.1085],[-.6104,.1086],[-.6219,.1088],[-.6333,.1093],[-.6448,.1101],[-.6563,.1108],[-.6678,.1111],[-.6793,.1109],[-.6908,.1103],[-.7022,.11],[-.7137,.1103],[-.7252,.1107],[-.7367,.111],[-.7482,.111],[-.7596,.1109],[-.7711,.1109],[-.7826,.1109],[-.7941,.1108],[-.8056,.1108],[-.8171,.1107],[-.8285,.1107],[-.84,.1108],[-.8515,.1112],[-.863,.1122],[-.8745,.1136],[-.886,.1148],[-.8974,.1156],[-.9089,.1162],[-.9204,.1166],[-.9319,.1167],[-.9434,.1166],[-.9549,.1164],[-.9663,.116],[-.9778,.1156],[-.9893,.1151],[-1.0008,.1146],[-1.0123,.1141],[-1.0237,.1137],[-1.0352,.1133],[-1.0467,.1131],[-1.0582,.1128],[-1.0697,.1114],[-1.0812,.1064],[-1.0926,.0968],[-1.1041,.0871],[-1.1118,.0826]],at:[[.9146,.4364],[2.4853,.4364],[-.9146,.4364],[-2.4853,.4364]],fins:[{side:-1,uv:[.9313,.9131,.9935,1],x0:-.225,x1:.0015,y0:-.8802,y1:-1.0505,outline:[[-.8802,.1162,.1139],[-.886,.122,.1145],[-.8917,.1279,.115],[-.8974,.1338,.1154],[-.9032,.1397,.1158],[-.9089,.1456,.116],[-.9147,.1514,.1163],[-.9204,.1544,.1164],[-.9261,.1632,.1165],[-.9319,.1691,.1166],[-.9376,.175,.1166],[-.9434,.1809,.1166],[-.9491,.1868,.1165],[-.9549,.1926,.1163],[-.9606,.1985,.1162],[-.9663,.2044,.116],[-.9721,.2132,.1159],[-.9778,.2191,.1156],[-.9836,.222,.1154],[-.9893,.222,.1152],[-.995,.222,.115],[-1.0008,.222,.1147],[-1.0065,.222,.1145],[-1.0123,.222,.1143],[-1.018,.222,.1141],[-1.0237,.222,.1139],[-1.0295,.222,.1137],[-1.0352,.222,.1136],[-1.041,.222,.1135],[-1.0467,.1132,.1134],[-1.0486,.1132,.1133]]}],finsAround:2,finsFrom:null,engines:{ring:0,centre:!0,f:1,colour:[46,44,42],profile:[[-1.1118,.0747],[-1.1156,.0835],[-1.1194,.0893],[-1.1233,.0805],[-1.1271,.0688],[-1.1309,.0688],[-1.1347,.0717],[-1.1386,.0717],[-1.1424,.0746],[-1.1462,.0775],[-1.1501,.0775],[-1.1539,.0804],[-1.1577,.0834],[-1.1615,.0833],[-1.1654,.0863],[-1.1692,.0892],[-1.173,.0892],[-1.1768,.0921],[-1.1807,.0921],[-1.1845,.095],[-1.1883,.095],[-1.1922,.092],[-1.196,.0833],[-1.1998,.057]]}}],badge:{y:.9137,d:.312,r:.208},band:[.7245,.7435],head:{top:1.6,cut:1.1028,mean:.7484,r:.2618}},heavy:{id:"starship",shape:"heavy",atlas:{w:1029,h:1136,cap:[.9942,.9947,.9981,.9982]},parts:[{name:"core",uv:[0,.0986,.7464,1],top:1.6,end:-1.1224,profile:[[1.6,.0103],[1.5884,.0383],[1.5769,.0539],[1.5653,.0677],[1.5537,.0807],[1.5422,.0926],[1.5306,.1039],[1.519,.1146],[1.5075,.1248],[1.4959,.1347],[1.4843,.1444],[1.4727,.1536],[1.4612,.1626],[1.4496,.1712],[1.438,.1796],[1.4265,.1874],[1.4149,.1949],[1.4033,.2021],[1.3918,.2091],[1.3802,.216],[1.3686,.223],[1.3571,.2298],[1.3455,.2364],[1.3339,.2426],[1.3224,.2485],[1.3108,.254],[1.2992,.2593],[1.2877,.2642],[1.2761,.2688],[1.2645,.2731],[1.253,.2771],[1.2414,.2808],[1.2298,.2843],[1.2182,.2875],[1.2067,.2904],[1.1951,.2931],[1.1835,.2955],[1.172,.2978],[1.1604,.2998],[1.1488,.3015],[1.1373,.3031],[1.1257,.3045],[1.1141,.3057],[1.1026,.3067],[1.091,.3075],[1.0794,.3082],[1.0679,.3087],[1.0563,.3091],[1.0447,.3093],[1.0332,.3094],[1.0216,.3094],[1.01,.3092],[.9985,.309],[.9869,.3088],[.9753,.3085],[.9637,.3083],[.9522,.3081],[.9406,.308],[.929,.3082],[.9175,.3086],[.9059,.309],[.8943,.309],[.8828,.3089],[.8712,.3087],[.8596,.3085],[.8481,.3084],[.8365,.3085],[.8249,.3087],[.8134,.3088],[.8018,.309],[.7902,.3091],[.7787,.309],[.7671,.3087],[.7555,.3085],[.744,.3083],[.7324,.3081],[.7208,.308],[.7092,.3081],[.6977,.3082],[.6861,.3082],[.6745,.3082],[.663,.3083],[.6514,.3084],[.6398,.3083],[.6283,.3081],[.6167,.308],[.6051,.308],[.5936,.3081],[.582,.3082],[.5704,.308],[.5589,.3078],[.5473,.3077],[.5357,.3078],[.5242,.3079],[.5126,.308],[.501,.308],[.4895,.3081],[.4779,.3082],[.4663,.3082],[.4547,.3083],[.4432,.3084],[.4316,.3085],[.42,.3084],[.4085,.3084],[.3969,.3085],[.3853,.3086],[.3738,.3085],[.3622,.3083],[.3506,.3081],[.3391,.3078],[.3275,.3076],[.3159,.3076],[.3044,.3078],[.2928,.3083],[.2812,.3086],[.2697,.3086],[.2581,.3084],[.2465,.3082],[.2349,.3079],[.2234,.3077],[.2118,.3077],[.2002,.3079],[.1887,.3084],[.1771,.3087],[.1655,.3087],[.154,.3085],[.1424,.3083],[.1308,.308],[.1193,.3078],[.1077,.3076],[.0961,.3075],[.0846,.3075],[.073,.3077],[.0614,.3077],[.0499,.3078],[.0383,.3079],[.0267,.308],[.0152,.308],[.0036,.308],[-.008,.3082],[-.0196,.3083],[-.0311,.3083],[-.0427,.3084],[-.0543,.3084],[-.0658,.3082],[-.0774,.3081],[-.089,.308],[-.1005,.308],[-.1121,.3081],[-.1237,.3082],[-.1352,.3082],[-.1468,.3081],[-.1584,.3082],[-.1699,.3083],[-.1815,.3083],[-.1931,.3084],[-.2046,.3085],[-.2162,.3086],[-.2278,.3087],[-.2393,.3088],[-.2509,.3089],[-.2625,.3089],[-.2741,.3089],[-.2856,.3089],[-.2972,.3091],[-.3088,.3092],[-.3203,.3093],[-.3319,.3096],[-.3435,.31],[-.355,.3105],[-.3666,.3108],[-.3782,.3109],[-.3897,.3107],[-.4013,.3105],[-.4129,.3103],[-.4244,.3101],[-.436,.3098],[-.4476,.3096],[-.4591,.3094],[-.4707,.3091],[-.4823,.3089],[-.4938,.3087],[-.5054,.3085],[-.517,.3083],[-.5286,.308],[-.5401,.3078],[-.5517,.3076],[-.5633,.3074],[-.5748,.3071],[-.5864,.3069],[-.598,.3067],[-.6095,.3065],[-.6211,.3063],[-.6327,.306],[-.6442,.3058],[-.6558,.3056],[-.6674,.3054],[-.6789,.3052],[-.6905,.3049],[-.7021,.3047],[-.7136,.3045],[-.7252,.3043],[-.7368,.3041],[-.7484,.3038],[-.7599,.3036],[-.7715,.3034],[-.7831,.3032],[-.7946,.303],[-.8062,.3027],[-.8178,.3025],[-.8293,.3023],[-.8409,.3021],[-.8525,.3019],[-.864,.3017],[-.8756,.3014],[-.8872,.3012],[-.8987,.301],[-.9103,.3008],[-.9219,.3006],[-.9334,.3004],[-.945,.3002],[-.9566,.3],[-.9681,.2997],[-.9797,.2995],[-.9913,.2993],[-1.0029,.2991],[-1.0144,.2989],[-1.026,.2987],[-1.0376,.2985],[-1.0491,.2983],[-1.0607,.2981],[-1.0723,.2979],[-1.0838,.2976],[-1.0954,.2974],[-1.107,.2972],[-1.1185,.297],[-1.1224,.297]],at:[[0,0]],fins:[{side:-1,uv:[.7464,.8477,.9252,1],x0:-.4382,x1:0,y0:1.3532,y1:1.0197,outline:[[1.3532,.2286,.2293],[1.3474,.2334,.2327],[1.3416,.2405,.2359],[1.3359,.2477,.2391],[1.3301,.2548,.2421],[1.3243,.2619,.2451],[1.3185,.2691,.2481],[1.3127,.2762,.2509],[1.3069,.2834,.2537],[1.3012,.2905,.2563],[1.2954,.2976,.2589],[1.2896,.3048,.2615],[1.2838,.312,.2639],[1.278,.3191,.2663],[1.2722,.3262,.2686],[1.2664,.3334,.2709],[1.2607,.3405,.273],[1.2549,.3477,.2751],[1.2491,.3548,.2772],[1.2433,.362,.2791],[1.2375,.3691,.281],[1.2317,.3762,.2828],[1.226,.3834,.2846],[1.2202,.3905,.2863],[1.2144,.3977,.2879],[1.2086,.4024,.2895],[1.2028,.4096,.291],[1.197,.4143,.2925],[1.1913,.4191,.2939],[1.1855,.4191,.2952],[1.1797,.4191,.2965],[1.1739,.4215,.2977],[1.1681,.4215,.2989],[1.1623,.4215,.3],[1.1566,.4239,.301],[1.1508,.4239,.302],[1.145,.4239,.303],[1.1392,.4263,.3039],[1.1334,.4263,.3047],[1.1276,.4286,.3056],[1.1218,.4286,.3063],[1.1161,.431,.307],[1.1103,.431,.3077],[1.1045,.431,.3083],[1.0987,.4334,.3089],[1.0929,.4334,.3094],[1.0871,.4334,.3099],[1.0814,.4358,.3104],[1.0756,.4358,.3108],[1.0698,.4334,.3112],[1.064,.431,.3115],[1.0582,.4191,.3118],[1.0524,.4096,.3121],[1.0467,.3953,.3123],[1.0409,.3834,.3125],[1.0351,.3715,.3127],[1.0293,.3596,.3128],[1.0235,.312,.3129],[1.0216,.312,.313]]},{side:1,uv:[.7464,.6937,.9252,.846],x0:0,x1:.4382,y0:1.3532,y1:1.0197,outline:[[1.3532,.2334,.2293],[1.3474,.2405,.2327],[1.3416,.25,.2359],[1.3359,.2572,.2391],[1.3301,.2619,.2421],[1.3243,.2691,.2451],[1.3185,.2762,.2481],[1.3127,.2834,.2509],[1.3069,.2905,.2537],[1.3012,.2976,.2563],[1.2954,.3048,.2589],[1.2896,.312,.2615],[1.2838,.3191,.2639],[1.278,.3262,.2663],[1.2722,.3334,.2686],[1.2664,.3405,.2709],[1.2607,.3453,.273],[1.2549,.3524,.2751],[1.2491,.3596,.2772],[1.2433,.3691,.2791],[1.2375,.3739,.281],[1.2317,.381,.2828],[1.226,.3881,.2846],[1.2202,.3953,.2863],[1.2144,.4024,.2879],[1.2086,.4096,.2895],[1.2028,.4143,.291],[1.197,.4167,.2925],[1.1913,.4191,.2939],[1.1855,.4191,.2952],[1.1797,.4191,.2965],[1.1739,.4215,.2977],[1.1681,.4215,.2989],[1.1623,.4239,.3],[1.1566,.4239,.301],[1.1508,.4239,.302],[1.145,.4263,.303],[1.1392,.4263,.3039],[1.1334,.4263,.3047],[1.1276,.4286,.3056],[1.1218,.4286,.3063],[1.1161,.431,.307],[1.1103,.431,.3077],[1.1045,.431,.3083],[1.0987,.4334,.3089],[1.0929,.4334,.3094],[1.0871,.4334,.3099],[1.0814,.4358,.3104],[1.0756,.4358,.3108],[1.0698,.431,.3112],[1.064,.4239,.3115],[1.0582,.4143,.3118],[1.0524,.4024,.3121],[1.0467,.3905,.3123],[1.0409,.3786,.3125],[1.0351,.3667,.3127],[1.0293,.3548,.3128],[1.0235,.3143,.3129],[1.0216,.3143,.313]]},{side:-1,uv:[.7464,.3477,.9922,.6919],x0:-.5301,x1:0,y0:-.3743,y1:-1.1282,outline:[[-.3743,.3059,.3036],[-.3801,.308,.3037],[-.3859,.3101,.3038],[-.3917,.3101,.3038],[-.3974,.3122,.3038],[-.4032,.3143,.3038],[-.409,.3164,.3038],[-.4148,.3206,.3038],[-.4206,.3226,.3038],[-.4264,.3248,.3038],[-.4322,.3268,.3038],[-.4379,.3289,.3038],[-.4437,.3331,.3038],[-.4495,.3373,.3038],[-.4553,.3415,.3038],[-.4611,.3457,.3038],[-.4669,.3499,.3038],[-.4726,.3541,.3038],[-.4784,.3583,.3038],[-.4842,.3625,.3038],[-.49,.3666,.3038],[-.4958,.3708,.3038],[-.5016,.3729,.3038],[-.5073,.3771,.3038],[-.5131,.3813,.3038],[-.5189,.3855,.3038],[-.5247,.3897,.3038],[-.5305,.3939,.3038],[-.5363,.3981,.3038],[-.5421,.4023,.3038],[-.5478,.4064,.3038],[-.5536,.4106,.3038],[-.5594,.4148,.3038],[-.5652,.419,.3038],[-.571,.4232,.3038],[-.5768,.4274,.3038],[-.5825,.4316,.3038],[-.5883,.4358,.3038],[-.5941,.4379,.3038],[-.5999,.4421,.3038],[-.6057,.4463,.3038],[-.6115,.4504,.3038],[-.6172,.4546,.3038],[-.623,.4588,.3038],[-.6288,.463,.3038],[-.6346,.4672,.3038],[-.6404,.4714,.3038],[-.6462,.4756,.3038],[-.6519,.4777,.3038],[-.6577,.4819,.3038],[-.6635,.4861,.3038],[-.6693,.4903,.3038],[-.6751,.4944,.3038],[-.6809,.4986,.3038],[-.6867,.5028,.3038],[-.6924,.5049,.3038],[-.6982,.507,.3038],[-.704,.5091,.3038],[-.7098,.5091,.3038],[-.7156,.5091,.3038],[-.7214,.5091,.3038],[-.7271,.5091,.3038],[-.7329,.5091,.3038],[-.7387,.5091,.3038],[-.7445,.5112,.3038],[-.7503,.5112,.3038],[-.7561,.5112,.3038],[-.7618,.5112,.3038],[-.7676,.5112,.3038],[-.7734,.5133,.3038],[-.7792,.5133,.3038],[-.785,.5133,.3038],[-.7908,.5133,.3038],[-.7966,.5133,.3038],[-.8023,.5154,.3038],[-.8081,.5154,.3038],[-.8139,.5154,.3038],[-.8197,.5154,.3038],[-.8255,.5154,.3038],[-.8313,.5154,.3038],[-.837,.5175,.3038],[-.8428,.5175,.3038],[-.8486,.5175,.3038],[-.8544,.5175,.3038],[-.8602,.5175,.3038],[-.866,.5196,.3038],[-.8717,.5196,.3038],[-.8775,.5196,.3038],[-.8833,.5196,.3038],[-.8891,.5196,.3038],[-.8949,.5217,.3038],[-.9007,.5217,.3038],[-.9064,.5217,.3038],[-.9122,.5217,.3038],[-.918,.5217,.3038],[-.9238,.5238,.3038],[-.9296,.5238,.3038],[-.9354,.5238,.3038],[-.9412,.5238,.3038],[-.9469,.5259,.3038],[-.9527,.5259,.3038],[-.9585,.5259,.3038],[-.9643,.5259,.3038],[-.9701,.5259,.3038],[-.9759,.528,.3038],[-.9816,.528,.3038],[-.9874,.528,.3038],[-.9932,.5259,.3038],[-.999,.5217,.3038],[-1.0048,.5112,.3038],[-1.0106,.4986,.3038],[-1.0163,.484,.3038],[-1.0221,.4693,.3038],[-1.0279,.4546,.3038],[-1.0337,.4379,.3038],[-1.0395,.4253,.3038],[-1.0453,.4086,.3038],[-1.0511,.396,.3038],[-1.0568,.3813,.3038],[-1.0626,.3666,.3038],[-1.0684,.3541,.3038],[-1.0742,.3541,.3038],[-1.08,.3541,.3038],[-1.0858,.3541,.3038],[-1.0915,.3541,.3038],[-1.0973,.3541,.3038],[-1.1031,.3541,.3038],[-1.1089,.352,.3038],[-1.1147,.3436,.3038],[-1.1205,.3352,.3038],[-1.1262,.3268,.3038]]},{side:1,uv:[.7464,.0018,.9922,.346],x0:0,x1:.5301,y0:-.3743,y1:-1.1282,outline:[[-.3743,.308,.3036],[-.3801,.3101,.3037],[-.3859,.3122,.3038],[-.3917,.3143,.3038],[-.3974,.3164,.3038],[-.4032,.3185,.3038],[-.409,.3206,.3038],[-.4148,.3226,.3038],[-.4206,.3268,.3038],[-.4264,.3289,.3038],[-.4322,.331,.3038],[-.4379,.3331,.3038],[-.4437,.3373,.3038],[-.4495,.3394,.3038],[-.4553,.3436,.3038],[-.4611,.3478,.3038],[-.4669,.3499,.3038],[-.4726,.3541,.3038],[-.4784,.3583,.3038],[-.4842,.3625,.3038],[-.49,.3666,.3038],[-.4958,.3708,.3038],[-.5016,.375,.3038],[-.5073,.3792,.3038],[-.5131,.3834,.3038],[-.5189,.3876,.3038],[-.5247,.3918,.3038],[-.5305,.396,.3038],[-.5363,.4002,.3038],[-.5421,.4044,.3038],[-.5478,.4086,.3038],[-.5536,.4127,.3038],[-.5594,.4148,.3038],[-.5652,.4211,.3038],[-.571,.4253,.3038],[-.5768,.4295,.3038],[-.5825,.4316,.3038],[-.5883,.4358,.3038],[-.5941,.44,.3038],[-.5999,.4442,.3038],[-.6057,.4484,.3038],[-.6115,.4526,.3038],[-.6172,.4567,.3038],[-.623,.4609,.3038],[-.6288,.4651,.3038],[-.6346,.4693,.3038],[-.6404,.4735,.3038],[-.6462,.4756,.3038],[-.6519,.4798,.3038],[-.6577,.484,.3038],[-.6635,.4882,.3038],[-.6693,.4924,.3038],[-.6751,.4966,.3038],[-.6809,.5007,.3038],[-.6867,.5049,.3038],[-.6924,.507,.3038],[-.6982,.5091,.3038],[-.704,.5091,.3038],[-.7098,.5112,.3038],[-.7156,.5112,.3038],[-.7214,.5112,.3038],[-.7271,.5112,.3038],[-.7329,.5133,.3038],[-.7387,.5133,.3038],[-.7445,.5133,.3038],[-.7503,.5133,.3038],[-.7561,.5133,.3038],[-.7618,.5154,.3038],[-.7676,.5154,.3038],[-.7734,.5154,.3038],[-.7792,.5154,.3038],[-.785,.5154,.3038],[-.7908,.5154,.3038],[-.7966,.5175,.3038],[-.8023,.5175,.3038],[-.8081,.5175,.3038],[-.8139,.5175,.3038],[-.8197,.5175,.3038],[-.8255,.5175,.3038],[-.8313,.5175,.3038],[-.837,.5196,.3038],[-.8428,.5196,.3038],[-.8486,.5196,.3038],[-.8544,.5196,.3038],[-.8602,.5196,.3038],[-.866,.5196,.3038],[-.8717,.5217,.3038],[-.8775,.5217,.3038],[-.8833,.5217,.3038],[-.8891,.5217,.3038],[-.8949,.5217,.3038],[-.9007,.5217,.3038],[-.9064,.5238,.3038],[-.9122,.5238,.3038],[-.918,.5238,.3038],[-.9238,.5238,.3038],[-.9296,.5238,.3038],[-.9354,.5238,.3038],[-.9412,.5259,.3038],[-.9469,.5259,.3038],[-.9527,.5259,.3038],[-.9585,.5259,.3038],[-.9643,.5259,.3038],[-.9701,.528,.3038],[-.9759,.528,.3038],[-.9816,.528,.3038],[-.9874,.5259,.3038],[-.9932,.5238,.3038],[-.999,.5196,.3038],[-1.0048,.507,.3038],[-1.0106,.4924,.3038],[-1.0163,.4777,.3038],[-1.0221,.463,.3038],[-1.0279,.4484,.3038],[-1.0337,.4337,.3038],[-1.0395,.4211,.3038],[-1.0453,.4044,.3038],[-1.0511,.3897,.3038],[-1.0568,.375,.3038],[-1.0626,.3625,.3038],[-1.0684,.3562,.3038],[-1.0742,.3562,.3038],[-1.08,.3562,.3038],[-1.0858,.3562,.3038],[-1.0915,.3541,.3038],[-1.0973,.3541,.3038],[-1.1031,.3541,.3038],[-1.1089,.3499,.3038],[-1.1147,.3436,.3038],[-1.1205,.3352,.3038],[-1.1262,.3289,.3038]]}],finsAround:2,finsFrom:null,engines:{ring:3,centre:3,f:.3,colour:[75,68,59],profile:[[-1.1224,.3256],[-1.1262,.3204],[-1.1301,.3142],[-1.134,.31],[-1.1378,.3059],[-1.1417,.3017],[-1.1455,.2965],[-1.1494,.2883],[-1.1532,.2759],[-1.1571,.2636],[-1.161,.2533],[-1.1648,.2431],[-1.1687,.243],[-1.1725,.243],[-1.1764,.2439],[-1.1802,.2439],[-1.1841,.2438],[-1.1879,.2417],[-1.1918,.2396],[-1.1957,.2355],[-1.1995,.2293],[-1.2034,.2201],[-1.2072,.2058],[-1.2111,.1864],[-1.2149,.0845],[-1.2188,.0814],[-1.2226,.0784],[-1.2265,.0722],[-1.2304,.0651],[-1.2342,.0529],[-1.2381,.0325]]}}],badge:{y:.9137,d:.4632,r:.3088},band:[.6489,.6679],head:null}};var ih={falcon9:"falcon9",falconHeavy:"falcon-heavy",newGlenn:"new-glenn",vulcan:"vulcan",cz2f:"long-march-2f",cz5:"long-march-5",cz3b:"long-march-3b",heavy:"starship"},Ef=Object.keys(ih);var $2=[64,18],Mc=(i,e,t)=>i+(e-i)*t;function Tf(i,e){if(i.length<3)return i;let t=new Uint8Array(i.length);t[0]=t[i.length-1]=1;let n=[[0,i.length-1]];for(;n.length;){let[s,r]=n.pop(),[a,o]=i[s],[l,c]=i[r],h=l-a,f=c-o,u=Math.hypot(h,f)||1,d=-1,g=-1;for(let x=s+1;x<r;x++){let m=Math.abs(f*(i[x][0]-a)-h*(i[x][1]-o))/u;m>d&&(d=m,g=x)}d>e&&(t[g]=1,n.push([s,g],[g,r]))}return i.filter((s,r)=>t[r])}var Z2=[.0015,.005];function J2(i,e,t){let[n,s,r,a]=i.uv,o=Tf(i.profile,t).map(([f,u])=>new ue(Math.max(4e-4,u),f)).reverse();o.push(new ue(1e-4,i.profile[0][0]+4e-4));let l=new ur(o,e),c=l.attributes.uv,h=l.attributes.position;for(let f=0;f<c.count;f++){let u=Math.min(1,Math.max(0,(h.getY(f)-i.end)/(i.top-i.end)));c.setXY(f,Mc(n,r,c.getX(f)),Mc(s,a,u))}return l}function K2(i,e,t){let n=i.profile[i.profile.length-1][1],s=new oa(n,t);s.rotateX(Math.PI/2),s.translate(0,i.end,0);let[r,a,o,l]=e.cap,c=s.attributes.uv;for(let h=0;h<c.count;h++)c.setXY(h,(r+o)/2,(a+l)/2);return s}function j2(i,e){let t=new Bi,n=i.outline.map(([f,u,d])=>{let g=e?e(f,d):0;return[f,Math.max(d,u)+g,d+g]});n.forEach(([f,u],d)=>d?t.lineTo(u,f):t.moveTo(u,f));for(let f=n.length-1;f>=0;f--)t.lineTo(n[f][2]-.004,n[f][0]);let s=new va(t),[r,a,o,l]=i.uv,c=s.attributes.position,h=s.attributes.uv;for(let f=0;f<c.count;f++){let u=c.getY(f),d=c.getX(f);if(e){let x=i.outline[0];for(let m of i.outline)Math.abs(m[0]-u)<Math.abs(x[0]-u)&&(x=m);d-=e(u,x[2])}let g=i.side*d;h.setXY(f,Mc(r,o,(g-i.x0)/(i.x1-i.x0)),Mc(a,l,(u-i.y1)/(i.y0-i.y1)))}return s}function Q2(i,e){return e===4?i.side<0?[Math.PI,Math.PI/2,-Math.PI/2]:[0]:[i.side<0?Math.PI:0]}function e3(i,e,t){if(!i||i.profile.length<3)return[];let n=Math.max(...i.profile.map(([,h])=>h)),s=i.ring?n*(1-i.f):0,r=n-s,a=i.profile.filter(([,h])=>h-s>r*.25);if(a.length<3)return[];let o=Tf(a,t).map(([h,f])=>new ue(Math.max(4e-4,f-s),h)).reverse(),l=new ur(o,Math.max(10,e>>1)),c=[];if(i.ring)for(let h=0;h<i.ring;h++)c.push([s,h/i.ring*Math.PI*2+Math.PI/i.ring,1]);if(i.centre===!0)c.push([0,0,1]);else if(typeof i.centre=="number")for(let h=0;h<i.centre;h++)c.push([s*.38,h/i.centre*Math.PI*2,.62]);return c.map(([h,f,u])=>{let d=l.clone();return d.scale(u,1,u),d.translate(Math.sin(f)*h,(1-u)*.05,Math.cos(f)*h),d})}var t3=([i,e])=>new Rt().makeTranslation(Math.sin(i)*e,0,Math.cos(i)*e).multiply(new Rt().makeRotationY(i+Math.PI/2)),th=new Map;function wf(i,e){let t=`${i}|${e?1:0}`;if(th.has(t))return th.get(t);let n=ja[i],s=$2.map(c=>e?Math.max(12,c>>1):c).map((c,h)=>{let f=Z2[h]*(e?1.6:1),u=[],d=[],g=n.parts.find(x=>x.name==="booster");for(let x of n.parts){let m=[J2(x,c,f),K2(x,n.atlas,c)],p=x.fins.length?x:x.finsFrom==="booster"&&g?g:null;if(p)for(let v of p.fins){let b=p!==x?(E,C)=>{let y=x.profile[0];for(let w of x.profile)Math.abs(w[0]-E)<Math.abs(y[0]-E)&&(y=w);return y[1]-C}:null;for(let E of Q2(v,p===x?x.finsAround:4)){let C=j2(v,b);C.rotateY(E),m.push(C)}}let S=e3(x.engines,c,f),A=x.name==="core"?[null]:x.at;for(let v of A){let b=v?t3(v):null;for(let E of m)u.push(b?E.clone().applyMatrix4(b):E);for(let E of S)d.push(b?E.clone().applyMatrix4(b):E)}}return{hull:yc(u),bells:d.length?yc(d):null}}),r=0,a=s[0].hull.attributes.position;for(let c=0;c<a.count;c++)r=Math.max(r,Math.hypot(a.getX(c),a.getZ(c)));let o=[];for(let c of n.parts)if(c.name!=="core"&&c.engines)for(let[h,f]of c.at){let u=Math.max(...c.engines.profile.map(([,d])=>d));o.push({x:Math.sin(h)*f,z:Math.cos(h)*f,r:u})}let l={levels:s,span:r,nozzles:o};return th.set(t,l),l}var nh=new Map;function Af(i){if(nh.has(i))return nh.get(i);let e=ja[i],t=e.parts.find(o=>o.name==="core"),n=o=>{let l=t.profile[0];for(let c of t.profile)Math.abs(c[0]-o)<Math.abs(l[0]-o)&&(l=c);return l[1]},s=i==="heavy"?-.25:0,r=[];for(let o of[0,Math.PI]){let c=[],h=[],f=[],u=e.badge.d;for(let g=0;g<=10;g++)for(let x=0;x<=10;x++){let m=(x/10-.5)*u,p=(g/10-.5)*u,S=e.badge.y+p,A=n(S)+.004,v=o+s+m/A;c.push(Math.sin(v)*A,S,Math.cos(v)*A),h.push(x/10,g/10)}for(let g=0;g<10;g++)for(let x=0;x<10;x++){let m=g*11+x,p=m+1,S=m+10+1,A=S+1;f.push(m,p,A,m,A,S)}let d=new wt;d.setAttribute("position",new ft(c,3)),d.setAttribute("uv",new ft(h,2)),d.setIndex(f),d.computeVertexNormals(),r.push(d)}let a=yc(r);return nh.set(i,a),a}function Rf(i){let e=ja[i];if(!e?.head)return null;let t=e.parts.find(s=>s.name==="core").profile,n=s=>{for(let r=1;r<t.length;r++)if(t[r][0]<=s){let[a,o]=t[r-1],[l,c]=t[r];return a===l?c:c+(o-c)*(s-l)/(a-l)}return t[t.length-1][1]};return{cut:e.head.cut,top:e.head.top,r:n}}var n3=`
#ifdef MP_LIVERY
{
  float L = dot(diffuseColor.rgb, vec3(.2126, .7152, .0722));
  float rr = length(vObj.xz);
  float onCore = 1. - step(uCoreR, rr);
  float m = onCore * uHeadOn * smoothstep(uCut, uCut + uFeather, vObj.y) * (1. - smoothstep(uTop - uFeather, uTop, vObj.y));
  vec3 paint = uHead;
  if (uPatOn > .5) {
    float a = atan(vObj.x, vObj.z) / 6.2831853;
    float u1 = fract(a), u2 = fract(a + .5) - .5;
    float uu = fwidth(u1) <= fwidth(u2) + 1e-6 ? u1 : u2;
    paint = texture2D(uPat, vec2(uu, clamp((vObj.y - uSpan.x) / (uSpan.y - uSpan.x), 0., 1.))).rgb;
  }
  diffuseColor.rgb = mix(diffuseColor.rgb, paint * clamp(L / uMean, 0., 1.35), m);
  float b = onCore * step(uBand.x, vObj.y) * step(vObj.y, uBand.y);
  diffuseColor.rgb = mix(diffuseColor.rgb, uBandC * clamp(L / .7, .55, 1.3), b);
}
#endif`;function Cf(i,{near:e,envMap:t,head:n,band:s,pattern:r}){let a=ja[i],o=i==="heavy",l=a.parts.find(g=>g.name==="core"),c=Math.max(...l.profile.map(([,g])=>g))*1.06,h=e?Ma:Ln,f=new h({metalness:1,roughness:1,side:xn,alphaTest:.5,envMap:t,envMapIntensity:o?2.6:.95,...e?{clearcoat:o?0:.3,clearcoatRoughness:.35,bumpScale:o?0:1.1}:{}}),u=2.84/120,d={uHeadOn:{value:n&&a.head?1:0},uHead:{value:new it(n??"#ffffff")},uMean:{value:a.head?.mean??.7},uCut:{value:a.head?.cut??99},uTop:{value:a.head&&a.head.top<1.59?a.head.top:99},uFeather:{value:.4*u},uCoreR:{value:c},uBand:{value:new ue(a.band[0],a.band[1])},uBandC:{value:new it(s??"#888888")},uPat:{value:r?.texture??null},uPatOn:{value:r?.texture?1:0},uSpan:{value:new ue(a.head?.cut??0,a.head?.top??1)}};return o&&f.color.setScalar(1.35),f.userData.livery=d,f.defines={MP_LIVERY:""},f.onBeforeCompile=g=>{Object.assign(g.uniforms,d),g.vertexShader=g.vertexShader.replace("#include <common>",`#include <common>
varying vec3 vObj;`).replace("#include <begin_vertex>",`#include <begin_vertex>
vObj = position;`),g.fragmentShader=g.fragmentShader.replace("#include <common>",`#include <common>
varying vec3 vObj;
uniform float uHeadOn, uMean, uCut, uTop, uFeather, uCoreR, uPatOn;
uniform vec3 uHead, uBandC;
uniform vec2 uBand, uSpan;
uniform sampler2D uPat;`).replace("#include <map_fragment>","#include <map_fragment>"+n3)},f.customProgramCacheKey=()=>`mp-hull-${e?1:0}`,f}var Pf=(i,e,t)=>`${i}art/rockets/${ih[e]}-${t}.webp`,If=(i,e)=>`${i}art/rockets/${ih[e]}-mat.webp`;function Lf(i,e={}){let t=e.studio??null,n={},s=O=>n[O]||"#b8b0a8",r={openai:"OpenAI",anthropic:"Anthropic",zhipuai:"ZHIPU",xai:"xAI",alibaba:"Qwen",deepseek:"DeepSeek",kimi:"Kimi",minimax:"MiniMax",xiaomi:"Xiaomi",tencent:"Tencent",google:"Google",meta:"Meta"},a="./assets/",o={logos:Object.fromEntries(Object.entries({openai:"openai-white.svg",anthropic:"claude-rounded.svg",zhipuai:"zhipu.svg",xai:"x-white.svg",alibaba:"qwen.svg",deepseek:"deepseek.svg",kimi:"kimi-white.svg",minimax:"minimax.svg",google:"gemini.svg",xiaomi:"xiaomi.svg",meta:null}).filter(([,O])=>O).map(([O,ye])=>[O,`${a}brands/${ye}`]))},l="varying vec2 vUv; varying float vR; void main(){ vUv=uv; vR=abs(dot(normalize(normalMatrix*normal),vec3(0.,0.,1.))); gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",c="uniform float t; uniform float k; uniform vec3 c0; uniform vec3 c1; varying vec2 vUv; varying float vR; void main(){ float a=vUv.y; float fl=.82+.18*sin(t*38.+a*22.)+.08*sin(t*61.+vUv.x*40.); float dia=.85+.15*sin(a*26.-t*20.); float alpha=pow(1.-a,1.5)*fl*dia*k*(.35+.65*pow(vR,1.2)); vec3 col=mix(c0,c1,smoothstep(0.,.55,a)); gl_FragColor=vec4(col*alpha*1.7,alpha); }",h="uniform float t; uniform float k; uniform vec3 gc; uniform vec3 sc; uniform float sm; varying vec2 vUv; varying float vR; void main(){ float y=vUv.y; float n=.75+.25*sin(t*3.+y*30.+vUv.x*20.); float glow=pow(y,3.)*.7; float smoke=pow(y,1.2)*(1.-y)*sm*n; vec3 col=gc*glow+sc*smoke; float a=(glow+smoke)*k*pow(vR,1.4); gl_FragColor=vec4(col*a,a); }",f="uniform float t; uniform float k; varying vec2 vUv; varying float vR; float h(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); } float nz(vec2 p){ vec2 i=floor(p),f=fract(p); f=f*f*(3.-2.*f); return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y); } void main(){ float y=vUv.y; vec2 p=vec2(vUv.x*6.,y*5.+t*1.6); float n=nz(p)*.6+nz(p*2.3)*.4; float a=smoothstep(.2,.75,y)*(1.-smoothstep(.92,1.,y))*smoothstep(.3,.72,n)*k*pow(vR,.6)*.85; vec3 c=mix(vec3(.30,.27,.25),vec3(.62,.36,.2),smoothstep(.55,1.,y)); gl_FragColor=vec4(c*(.75+.25*n),a); }",u={hi:{o:["#8cc8ff","#1d5cff"],i:["#e2f1ff","#4f9dff"],light:"#7fb6ff",gc:[.45,.7,1],sc:[.55,.65,.85],sm:.35,soot:!1,label:"\u9AD8\u6548 \xB7 \u84DD\u7130",tip:"\u540C\u6837\u7684\u6210\u672C\u80FD\u529B\u660E\u663E\u66F4\u9AD8\uFF0C\u6216\u6CA1\u6709\u4EFB\u4F55\u6A21\u578B\u6BD4\u5B83\u53C8\u4FBF\u5B9C\u53C8\u5F3A"},mid:{o:["#ffd9a0","#ff5a24"],i:["#ffffff","#8fd0ff"],light:"#ffa060",gc:[1,.55,.25],sc:[.6,.66,.8],sm:.5,soot:!1,label:"\u6807\u51C6",tip:"\u80FD\u529B\u4E0E\u6210\u672C\u5927\u81F4\u5728\u8D8B\u52BF\u7EBF\u4E0A"},lo:{o:["#ff9446","#9a2406"],i:["#ffcf90","#e0601c"],light:"#ff7a3a",gc:[.9,.38,.12],sc:[.28,.24,.22],sm:.75,soot:!0,label:"\u4F4E\u6548 \xB7 \u9ED1\u70DF",tip:"\u540C\u6837\u7684\u6210\u672C\uFF0C\u80FD\u529B\u660E\u663E\u4F4E\u4E8E\u8D8B\u52BF\u7EBF"}},d=new Map,g=new Map;function x(O){return d.has(O)||d.set(O,new Promise(ye=>{let Se=new Image;Se.onload=()=>ye(Se),Se.onerror=()=>ye(null),Se.src=O.includes("/")?O:`${a}brands/${O}`})),d.get(O)}function m(O,ye){let Se=`${O.src}|${ye}`;if(!g.has(Se)){let be=document.createElement("canvas");be.width=be.height=128;let Ve=be.getContext("2d");Ve.drawImage(O,0,0,128,128),Ve.globalCompositeOperation="source-in",Ve.fillStyle=ye,Ve.fillRect(0,0,128,128),g.set(Se,be)}return g.get(Se)}let p=-1.24,S=1.6,A=(S-p)/120,v=typeof innerWidth=="number"&&innerWidth<600,b=v?256:512,E={openai:"#f3f3f1",xai:"#2e3238",zhipuai:"#b9c2cc"},C={alibaba:"qwen.svg",xiaomi:"xiaomi-mi.svg"},y={xiaomi:["#ff8a33","#ff6900","#e65c00"]},w={xiaomi:.8},P=i??(t?(t.mapping=xr,t):null),U=new Ea,B=new Map,W=(O,ye)=>(B.has(O)||B.set(O,new Promise(Se=>U.load(O,be=>{be.colorSpace=ye?Wt:ti,be.anisotropy=4,be.userData.shared=!0,Se(be)},void 0,()=>Se(null)))),B.get(O)),F=new Map;function V(O,ye,Se){let be=`${Se}|${O}|${ye}`;return F.has(be)||F.set(be,(async()=>{let Ve=Rf(Se);if(!Ve)return null;let me=Tr(O,ye),$=me.glyph?await x(me.glyph):null,X=O==="xai"?E.xai:me.base,he=Ve.top-Ve.cut,Te=he>.2,le=v?256:512,Ie=le/2,st=document.createElement("canvas");st.width=le,st.height=Ie;let Z=st.getContext("2d"),ce=Qe=>Ie*(1-Qe),Me=Qe=>Ve.cut+Qe*he,ge=Te?{lattice:[.17,.43,.69],diagonal:[.17,.43,.69],rings:[.25,.58],split:[.22,.62]}[me.pattern]:[.4],xe=Math.max(...ge.map(Qe=>Ve.r(Me(Qe)))),ke=.46,Le=.8,Je=ge.length>1?(ge[1]-ge[0])*he:he,tt=Math.min(.085,Je*(Te?.62:.5));if(Z.fillStyle=X,Z.fillRect(0,0,le,Ie),Te&&me.pattern==="split"&&(Z.fillStyle=me.ink,Z.fillRect(0,0,le,ce(ke))),Te&&me.pattern==="rings"){let Qe=Math.max(1,.014/he*Ie);for(let at of ge)for(let T of[-.12,.12])Z.fillStyle=me.ink,Z.fillRect(0,ce(at+T)-Qe/2,le,Qe)}if(Te&&me.pattern==="diagonal"){Z.save(),Z.strokeStyle=me.ink,Z.globalAlpha=.35,Z.lineWidth=le/170;for(let Qe=-le;Qe<le*2;Qe+=le/6)Z.beginPath(),Z.moveTo(Qe,ce(.08)),Z.lineTo(Qe+le*.55,ce(Le)),Z.stroke();Z.restore()}if($&&ge.forEach((Qe,at)=>{let T=Ve.r(Me(Qe)),_=Math.max(.25,T/xe),H=me.pattern==="rings",G=tt*(H?.85:1),ne=Math.max(3,Math.round((H?8:5)*_)),ve=le/ne,Ae=G/(2*Math.PI*T)*le,ee=G/he*Ie,oe=me.pattern==="diagonal"?at*ve/2:at%2?ve/2:0;for(let Re=-1;Re<=ne;Re++){let qe=me.pattern==="split"&&Qe>ke?X:me.inks?me.inks[((Re+at)%me.inks.length+me.inks.length)%me.inks.length]:me.ink;Z.save(),Z.translate(Re*ve+oe,ce(Qe)),Z.scale(Ae/ee,1),me.pattern==="diagonal"&&Z.rotate(-.45),Z.drawImage(m($,qe),-ee/2,-ee/2,ee,ee),Z.restore()}}),Z.fillStyle=me.cap,Z.fillRect(0,0,le,ce(Le)),Te){let Qe=[...me.trim,...me.trim];Qe.forEach((at,T)=>{Z.fillStyle=at,Z.fillRect(T*le/Qe.length,ce(.055),le/Qe.length+1,Ie*.055+1)})}let L=new Bn(st);return L.colorSpace=Wt,L.wrapS=Yi,L.anisotropy=4,L.userData.shared=!0,L})()),F.get(be)}let se=new Map;function K(O,ye){let Se=`${O}|${ye}`;if(!se.has(Se)){let Ve=document.createElement("canvas");Ve.width=Ve.height=256;let me=new Bn(Ve);me.colorSpace=Wt,me.anisotropy=4,me.userData.shared=!0;let $=he=>{let Te=Ve.getContext("2d"),le=256/2,Ie=256/2-1;Te.clearRect(0,0,256,256);let st=Te.createRadialGradient(le-Ie*.3,le-Ie*.35,Ie*.05,le,le,Ie),Z=y[O];if(st.addColorStop(0,Z?.[0]??"#2c3443"),st.addColorStop(.6,Z?.[1]??"#11151d"),st.addColorStop(1,Z?.[2]??"#07090d"),Te.beginPath(),Te.arc(le,le,Ie,0,Math.PI*2),Te.fillStyle=st,Te.fill(),Te.save(),Te.clip(),Te.beginPath(),Te.ellipse(le-Ie*.12,le-Ie*.58,Ie*.7,Ie*.3,-.25,0,7),Te.fillStyle="rgba(255,255,255,.08)",Te.fill(),Te.restore(),Te.beginPath(),Te.arc(le,le,256*.47,0,Math.PI*2),Te.strokeStyle=ye,Te.lineWidth=256*.045,Te.stroke(),he){let ce=194.56*(w[O]??1);Te.drawImage(m(he,"#ffffff"),le-ce/2,le-ce/2,ce,ce)}else Te.fillStyle="#ffffff",Te.font=`800 ${Math.round(256*.5)}px 'Manrope', sans-serif`,Te.textAlign="center",Te.textBaseline="middle",Te.fillText((r[O]??O)[0]??"?",le,le+256*.03);me.needsUpdate=!0};$(null);let X=C[O]??Tr(O).glyph??o.logos[O];X&&x(X).then(he=>he&&$(he)),se.set(Se,me)}return se.get(Se)}let de=e.lodDistance??7;function te(O,ye,Se,be,Ve,me,$){let X=wf(O,v),he=O==="heavy",Te=Tr(ye,Se).colour,le=he?null:E[ye]??Te,Ie=new qt;Ie.rotation.y=.4*Math.PI;let st=new ta;Ie.add(st);let Z=new Ln({map:K(ye,Te),transparent:!0,alphaTest:.5,roughness:.32,metalness:.15,envMap:P,envMapIntensity:.8,polygonOffset:!0,polygonOffsetFactor:-2}),ce=new Ln({color:he?"#9a9590":"#6d6a66",metalness:.9,roughness:.38,side:xn,transparent:!0,forceSinglePass:!0,envMap:P,envMapIntensity:1.2});be.push(Z,ce);let Me=Af(O);Me.userData.shared=!0;let ge=X.levels.map((xe,ke)=>{xe.hull.userData.shared=!0,xe.bells&&(xe.bells.userData.shared=!0);let Le=Cf(O,{near:ke===0&&!v,envMap:P,head:le,band:Te});Object.defineProperty(Le,"transparent",{get(){return this.opacity<.999},set(){},configurable:!0}),Le.forceSinglePass=!0,be.push(Le);let Je=new qt,tt=new gt(xe.hull,Le);return tt.visible=!1,Je.add(tt,new gt(Me,Z)),xe.bells&&Je.add(new gt(xe.bells,ce)),st.addLevel(Je,ke===0?0:de),{mat:Le,body:tt}});Promise.all([W(Pf(a,O,b),!0),W(If(a,O),!1)]).then(([xe,ke])=>{if(xe)for(let{mat:Le,body:Je}of ge)Le.map=xe,Le.isMeshPhysicalMaterial?(Le.metalnessMap=Le.roughnessMap=ke,he||(Le.bumpMap=xe)):(Le.metalness=he?.75:.04,Le.roughness=he?.36:.42),Le.needsUpdate=!0,Je.visible=!0}),le&&e.headPattern!==!1&&V(ye,Te,O).then(xe=>{if(xe)for(let{mat:ke}of ge){let Le=ke.userData.livery;Le.uPat.value=xe,Le.uPatOn.value=1}});for(let xe of X.nozzles){let ke=me(xe.r*.95,.6+xe.r*2,Ve("#ffd9a0","#ff5a24"));ke.position.x=xe.x,ke.position.z=xe.z,Ie.add(ke),$.push(ke)}return Ie.userData.span=X.span,Ie}function ae(O){let ye=s(O.dev),Se=new qt,be=[],Ve=pe=>(be.push(pe),pe),me=Ef.includes(O.shape)&&O.shape!=="heavy"?O.shape:j0(O.dev,K0(O.id)),$=document.createElement("canvas");$.width=$.height=2;let X=new Bn($),he=X,Te=X,le=Ve(new Ln({map:X})),Ie=(pe,Ge)=>new Ft({transparent:!0,depthWrite:!1,blending:nn,uniforms:{t:{value:0},k:{value:1},c0:{value:new it(pe)},c1:{value:new it(Ge)}},vertexShader:l,fragmentShader:c}),st=(pe,Ge,et)=>{let ht=new la(pe,Ge,32,1,!0);ht.rotateX(Math.PI),ht.translate(0,-Ge/2,0);let D=new gt(ht,et);return D.position.y=p+.02,D},Z=new qt;Se.add(Z);let ce=[],Me=te(me,O.dev,ye,be,Ie,st,ce);Z.add(Me);let ge=Me.userData.span,xe=[Z],ke=st(.26,1.7,Ie("#ffd9a0","#ff5a24")),Le=st(.12,.95,Ie("#ffffff","#8fd0ff"));Se.add(ke,Le);let Je=new Ra("#ffa060",1.5,6,2);Je.position.y=-1.7,Se.add(Je);let tt=new qt;tt.position.y=.15,tt.visible=!1;let L=new gt(new zi(.6,.016,10,160),new en({color:"#d99a2b",transparent:!0,opacity:.95}));L.rotation.x=Math.PI/2-.38,tt.add(L);let Qe=new gt(new zn(.036,16,12),new en({color:"#ffd27a"}));Qe.position.set(.6,0,0),L.add(Qe);let at=new qt;at.visible=!1,Se.add(at);let T=te("heavy",O.dev,ye,be,Ie,st,[]);at.add(T);let _=p,H=T.userData.span,G=tt,ne=new qt;ne.visible=!1,Se.add(ne);let ve=new Bi;ve.moveTo(0,0),ve.lineTo(.34,-.5),ve.lineTo(.36,-.66),ve.lineTo(0,-.46),ve.closePath(),new xa(ve,{depth:.022,bevelEnabled:!0,bevelThickness:.008,bevelSize:.008,bevelSegments:2}).translate(0,0,-.011);let ee=new en({color:"#bfe6ff",transparent:!0,opacity:.6,blending:nn,depthWrite:!1});be.push(ee);let oe=[];for(let pe=0;pe<7;pe++){let Ge=pe/7*Math.PI*2,et=new gt(new Oi(.006,.006,.9,6),ee.clone());et.position.set(Math.cos(Ge)*.48,0,Math.sin(Ge)*.48),et.userData.o=pe*.37%1,ne.add(et),oe.push(et)}let Re=ce,qe=new gt(new zi(1.15,.03,10,96),new en({color:"#ffd37a",transparent:!0})),Pe=new gt(new zn(1,8,8),new en({visible:!1}));return Pe.scale.set(Math.max(.9,ge*2.4),1.6,Math.max(.9,ge*2.4)),Pe.position.y=.15,Se.add(Pe),{g:Se,shape:me,span:ge,mats:be,outer:ke,inner:Le,light:Je,ring:qe,hit:Pe,heavy:at,bOuter:Re,heavyNozzle:_,heavySpan:H,halo:G,stdParts:xe,racer:ne,streaks:oe,steel:le,hullMap:X,boltMap:he,steelMap:Te}}return{shapeFor:j0,raw(O){n[O.dev]=O.colour;let ye=ae({id:O.id,name:O.name,dev:O.dev,shape:O.shape});return ye.hit.userData.modelId=O.id,Object.assign(ye,{SOOT_F:f,FUEL:u,FLAME_V:l,TRAIL_F:h,NOZZLE_Y:p}),ye},make(O,ye,Se=!1){n[O.developerId]=O.colour;let be=ae({id:O.id,name:O.name,dev:O.developerId,shape:O.shape});be.hit.userData.modelId=O.id,be.heavy.visible=ye,be.racer.visible=!ye&&O.racer,be.stdParts.forEach(X=>X.visible=!ye),be.halo.visible=!1,be.steel.map=ye?be.steelMap:O.racer?be.boltMap:be.hullMap,be.steel.metalness=ye?.92:.35,be.steel.roughness=ye?.2:.34,O.fuel==="lo"&&(be.outer.material.fragmentShader=f,be.outer.material.blending=ns,be.outer.material.needsUpdate=!0);let Ve=u[O.fuel];for(let[X,he]of[[be.outer,Ve.o],[be.inner,Ve.i]])X.material.uniforms.c0.value.set(he[0]),X.material.uniforms.c1.value.set(he[1]);be.light.color.set(Ve.light);let me=O.cost===0?0:Math.max(.15,Math.min(1,(Math.log10(O.cost??.1)+2.2)/2.8));be.outer.scale.set(.8+me*.6,.6+me*1.2,.8+me*.6),be.inner.scale.set(1,.7+me*.6,1),be.light.intensity=.6+me*1.4;let $=new qt;return be.g.add($),Se&&(be.outer.visible=!1,be.inner.visible=!1,be.bOuter.forEach(X=>X.visible=!1),be.light.intensity=0),{root:be.g,flame:$,tipHeight:1.6,span:ye?be.heavySpan:be.span,hit:be.hit,animate(X){be.outer.material.uniforms.t.value=be.inner.material.uniforms.t.value=X,be.outer.material.uniforms.k.value=be.inner.material.uniforms.k.value=Se||O.cost===0?0:1,be.bOuter.forEach(he=>{he.material.uniforms.t.value=X,he.material.uniforms.k.value=Se||O.cost===0?0:1}),be.g.rotation.y=-.2-.4*Math.PI},dispose(){let X=new Set,he=new Set,Te=new Set;be.g.traverse(le=>{le.geometry&&!le.geometry.userData.shared&&X.add(le.geometry);for(let Ie of Array.isArray(le.material)?le.material:le.material?[le.material]:[]){he.add(Ie);for(let st of Object.values(Ie))st?.isTexture&&st!==i&&!st.userData.shared&&Te.add(st)}}),X.forEach(le=>le.dispose()),he.forEach(le=>le.dispose()),Te.forEach(le=>le.dispose())}}},dispose(){}}}var Sc=[[40,"\u8FD1\u5730\u8F68\u9053","Low Earth orbit"],[50,"\u6708\u7403","Moon"],[60,"\u706B\u661F","Mars"],[70,"\u6728\u661F","Jupiter"],[80,"\u571F\u661F","Saturn"],[90,"\u65E5\u7403\u5C42\u9876","Heliopause"],[100,"\u661F\u8FB0\u5927\u6D77","The stars"]],i3=i=>i==null?"\u2014":"$"+(i<.1?i.toFixed(3):i<1?i.toFixed(2):i.toFixed(1).replace(/\.0$/,"")),Rr=i=>String(i).replace(/[&<>"]/g,e=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"})[e]),Df=!1;function Nf(i){let{launch:e,host:t,plates:n,leaders:s,voyage:r,logo:a}=i,o=i.language??"zh",l=()=>o==="zh",c=()=>e.querySelector(i.copySelector),h=()=>e.querySelector(i.panelSelector),f=!!i.quiet||matchMedia("(prefers-reduced-motion: reduce)").matches,u={models:[]},d=!!i.showEffortPath,g={},x=new Set,m=null,p=null,S=null,A=R=>u.models.find(k=>k.dev===R)?.colour??"#b8b0a8",v=0,b=0,E=()=>i.embedded?!1:v<720,C=innerWidth<720,y=C?13:15,w=4,P=C?-6.5:-9,U=-P,B=3.2,W=C?-5.5:-8.5,F=2.3,V=46,se=new I(0,-V-9,-8),K=()=>0,de=44,te=60,ae=R=>Math.max(1.4,(R-de)/(te-de)*y+w),O=-1.3,ye=.5,Se=1,be=R=>P+.8+(Math.log10(R)-O)/(ye-O)*(U-P-1.6),Ve=R=>R==null?F:1.2-R/Se*(1.2-W-.6),me=(R,k,J)=>new I(R,k,J),$=new fc({antialias:!0,powerPreference:"high-performance",preserveDrawingBuffer:!1});$.setPixelRatio(i.stillCapture?devicePixelRatio:Math.min(devicePixelRatio,i.embedded?1.35:2)),$.outputColorSpace=Wt,$.toneMapping=Ms,$.toneMappingExposure=1.05,t.appendChild($.domElement);let X=new Kr;X.background=new it("#010205");let he=new mn(30,1,.1,4e3),Te=[],le=R=>(Te.push(R),R),Ie=me(-.93,.07,-.36).normalize(),st=me(.5,.55,.68).normalize(),Z=new gr("#ffe4c4",2.6);Z.position.copy(Ie).multiplyScalar(50),X.add(Z);let ce=new gr("#d8e6ff",1.25);ce.position.copy(st).multiplyScalar(50),X.add(ce),X.add(new Ta("#7d9cd6","#0d2a5c",.45));let Me=(R,k,J)=>[(Math.atan2(R.z,R.x)/(2*Math.PI)+.5)*k,(1-(Math.asin(R.y)/Math.PI+.5))*J],ge=(()=>{let J=document.createElement("canvas");J.width=1024,J.height=512;let ie=J.getContext("2d"),fe=ie.createLinearGradient(0,0,0,512);[[0,"#06080f"],[.44,"#121a2c"],[.49,"#5d93d6"],[.5,"#bfe2ff"],[.52,"#2a64b4"],[.6,"#0d2752"],[.8,"#061330"],[1,"#02060f"]].forEach(([nt,De])=>fe.addColorStop(nt,De)),ie.fillStyle=fe,ie.fillRect(0,0,1024,512);let Ue=(nt,De,Xe,rt)=>{let[Et,yt]=Me(nt,1024,512);for(let Nt of[-1024,0,1024]){ie.save(),ie.translate(Et+Nt,yt),ie.scale(De,Xe);let Ht=ie.createRadialGradient(0,0,0,0,0,1);rt.forEach(([Q,He])=>Ht.addColorStop(Q,He)),ie.fillStyle=Ht,ie.beginPath(),ie.arc(0,0,1,0,Math.PI*2),ie.fill(),ie.restore()}};Ue(st,120,70,[[0,"rgba(235,242,255,1)"],[.55,"rgba(200,220,255,.75)"],[1,"rgba(200,220,255,0)"]]),Ue(me(.7,.35,-.6).normalize(),40,110,[[0,"rgba(150,195,255,.9)"],[1,"rgba(150,195,255,0)"]]),Ue(me(-.2,.75,.6).normalize(),220,26,[[0,"rgba(255,255,255,.55)"],[1,"rgba(255,255,255,0)"]]),Ue(Ie,70,40,[[0,"rgba(255,250,235,1)"],[.2,"rgba(255,220,170,1)"],[1,"rgba(255,170,90,0)"]]);for(let nt=0;nt<260;nt++){let De=Math.random()*1024,Xe=512*(.56+Math.random()*.4);ie.fillStyle=`rgba(255,${150+Math.random()*60|0},80,${.3+Math.random()*.5})`,ie.fillRect(De,Xe,1.5,1.5)}let Ee=new Bn(J);return Ee.colorSpace=Wt,Ee.wrapS=Yi,Ee.minFilter=xi,le(Ee)})(),xe=Lf(null,{studio:ge}),ke=Sf(X),Le=(R,k=128)=>{let J=document.createElement("canvas");J.width=J.height=k;let ie=J.getContext("2d"),fe=ie.createRadialGradient(k/2,k/2,0,k/2,k/2,k/2);R.forEach(([Ee,nt])=>fe.addColorStop(Ee,nt)),ie.fillStyle=fe,ie.fillRect(0,0,k,k);let Ue=new Bn(J);return Ue.colorSpace=Wt,le(Ue)},Je=Le([[0,"rgba(255,255,255,1)"],[.25,"rgba(255,255,255,.45)"],[1,"rgba(255,255,255,0)"]]),tt;{let k=new Float32Array(9600),J=new Float32Array(3200),ie=new Float32Array(3200);for(let yt=0;yt<3200;yt++){let Nt=Math.random()*2-1,Ht=Math.random()*Math.PI*2,Q=1500,He=Math.sqrt(1-Nt*Nt);k.set([Q*He*Math.cos(Ht),Q*Nt,Q*He*Math.sin(Ht)],yt*3),J[yt]=Math.random()*6.28,ie[yt]=Math.random()**4*3.4+.7}let fe=new wt;fe.setAttribute("position",new jt(k,3)),fe.setAttribute("ph",new jt(J,1)),fe.setAttribute("sz",new jt(ie,1)),tt=new Ft({transparent:!0,depthWrite:!1,uniforms:{t:{value:0}},vertexShader:"attribute float ph; attribute float sz; uniform float t; varying float a; void main(){ a=.6+.4*sin(t*1.1+ph); gl_PointSize=sz*(.75+.25*a)*1.5; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",fragmentShader:"varying float a; void main(){ float d=length(gl_PointCoord-.5); gl_FragColor=vec4(vec3(.92,.95,1.),a*smoothstep(.5,0.,d)); }"}),X.add(new sa(fe,tt));let Ue=document.createElement("canvas");Ue.width=1024,Ue.height=512;let Ee=Ue.getContext("2d");[[300,220,320,"rgba(70,90,170,.22)"],[640,180,280,"rgba(40,90,170,.18)"],[820,290,220,"rgba(150,80,140,.10)"]].forEach(([yt,Nt,Ht,Q])=>{let He=Ee.createRadialGradient(yt,Nt,0,yt,Nt,Ht);He.addColorStop(0,Q),He.addColorStop(1,"rgba(0,0,0,0)"),Ee.fillStyle=He,Ee.fillRect(0,0,1024,512)});let nt=le(new Bn(Ue));nt.colorSpace=Wt;let De=new gt(new Ji(2600,1300),new en({map:nt,transparent:!0,depthWrite:!1,blending:nn}));De.position.set(200,420,-1300),X.add(De);let Xe=Ie.clone().multiplyScalar(1100).add(se),rt=new $i(new Ui({map:Le([[0,"rgba(255,255,250,1)"],[.06,"rgba(255,245,225,1)"],[.16,"rgba(255,200,140,.5)"],[.45,"rgba(255,150,80,.08)"],[1,"rgba(255,120,60,0)"]],256),blending:nn,depthWrite:!1}));rt.position.copy(Xe),rt.scale.setScalar(340),X.add(rt);let Et=new $i(new Ui({map:Je,color:"#9cc8ff",blending:nn,depthWrite:!1,opacity:.55}));Et.position.copy(Xe),Et.scale.set(1500,14,1),X.add(Et)}let L=[],Qe=new qt;X.add(Qe);function at(R,k,J,ie,fe=2){let Ue=[];for(let Ee=0;Ee<=fe;Ee++)Ue.push(me(J+(ie-J)*(Ee/fe),R,k));return Ue}let T=R=>{let k=document.createElement("canvas");k.width=256,k.height=128;let J=k.getContext("2d");R(J,256,128);let ie=le(new Bn(k));return ie.colorSpace=Wt,ie},_=(()=>{let R=7;return()=>(R=R*16807%2147483647)/2147483647})(),H={50:T((R,k,J)=>{R.fillStyle="#b9bcc2",R.fillRect(0,0,k,J);for(let ie=0;ie<70;ie++){let fe=2+_()*9;R.fillStyle=`rgba(${_()<.5?"70,74,82":"225,228,232"},.35)`,R.beginPath(),R.arc(_()*k,_()*J,fe,0,7),R.fill()}}),60:T((R,k,J)=>{R.fillStyle="#b4532c",R.fillRect(0,0,k,J);for(let ie=0;ie<50;ie++)R.fillStyle=`rgba(${_()<.6?"90,36,22":"214,120,72"},.35)`,R.beginPath(),R.ellipse(_()*k,_()*J,6+_()*26,3+_()*10,0,0,7),R.fill();R.fillStyle="rgba(255,250,245,.8)",R.fillRect(0,0,k,7),R.fillRect(0,J-6,k,6)}),70:T((R,k,J)=>{let ie=["#d8c4a4","#b98d63","#e7dcc8","#a8714b","#d9b98e","#c69c74","#efe6d6"];for(let fe=0;fe<J;fe+=6)R.fillStyle=ie[(fe/6+(_()*2|0))%ie.length],R.fillRect(0,fe,k,6);R.fillStyle="#b5523a",R.beginPath(),R.ellipse(170,82,16,8,0,0,7),R.fill()}),80:T((R,k,J)=>{let ie=["#e6d3a6","#d4bb85","#efe2c0","#c9ad78"];for(let fe=0;fe<J;fe+=8)R.fillStyle=ie[fe/8%ie.length],R.fillRect(0,fe,k,8)})},G=R=>{R.traverse(k=>{k.geometry?.dispose();for(let J of[].concat(k.material||[]))J.dispose()}),R.clear()};function ne(R){G(Qe),L.forEach(ie=>ie.el.remove()),L.length=0;let k=(ie,fe,Ue="")=>{let Ee=document.createElement("div");Ee.className="ltag "+Ue,Ee.innerHTML=ie,n.appendChild(Ee),L.push({el:Ee,v:fe})};for(let[ie,fe,Ue]of Sc){if(ie<de||ie>te)continue;let Ee=ie===100,nt=at(ae(ie),W,P+.5,U-.5),De=new Fi(new wt().setFromPoints(nt),Ee?new Sa({color:"#ffd37a",dashSize:.3,gapSize:.2}):new jn({color:"#cfe2ff",transparent:!0,opacity:.16}));Ee&&De.computeLineDistances(),Qe.add(De);let Xe=me(U+.2,nt[0].y,W);if(H[ie]){let rt=new gt(new zn(ie===70?.6:.42,48,32),new Ln({map:H[ie],roughness:.9}));if(rt.position.copy(Xe),rt.userData.spin=!0,Qe.add(rt),ie===80){let Et=new gt(new fr(.62,.95,64),new Ln({color:"#d9c6a0",transparent:!0,opacity:.75,side:xn,roughness:.8}));Et.position.copy(Xe),Et.rotation.x=-1.2,Et.rotation.y=.3,Qe.add(Et)}}k(`${l()?fe:Ue} <small>Index ${ie}</small>`,nt[0],"orbit"+(Ee?" kar":""))}let J=Sc.find(ie=>ie[0]>te);J&&C&&k(l()?`\u2191 \u4E0B\u4E00\u7AD9 ${J[1]} \xB7 ${J[0]}<small>${R>=100?"\u5DF2\u9A76\u5165\u661F\u8FB0\u5927\u6D77":`\u7EC8\u70B9 \u661F\u8FB0\u5927\u6D77 100\u3000\u9886\u5148\u8005\u8FD8\u5DEE ${(100-R).toFixed(1)}`}</small>`:`\u2191 Next stop ${J[2]} \xB7 ${J[0]}<small>${R>=100?"Out among the stars":`Destination: the stars at 100 \xB7 the leader is ${(100-R).toFixed(1)} away`}</small>`,me(P+.5,K()+ae(te)+1.2,W),"next")}{let R=U-P+3,k=B-W+2,J=new gt(new Ji(R,k),new Ft({transparent:!0,depthWrite:!1,blending:nn,uniforms:{size:{value:new ue(R,k)}},vertexShader:"varying vec2 vUv; void main(){ vUv=uv; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",fragmentShader:"uniform vec2 size; varying vec2 vUv; void main(){ vec2 p=vUv*size; vec2 g=abs(fract(p-.5)-.5)/fwidth(p); float line=1.-min(min(g.x,g.y),1.); vec2 e=min(vUv,1.-vUv)*size; float fade=smoothstep(0.,2.5,min(e.x,e.y)); float back=mix(.35,1.,vUv.y); gl_FragColor=vec4(vec3(.45,.68,1.)*(line*.16+.025)*fade*back,1.); }"}));J.rotation.x=-Math.PI/2,J.position.set((P+U)/2+.5,-.01,(B+W)/2),X.add(J)}let ve=new qt;X.add(ve);let Ae=[];function ee(R,k,J){let ie=document.createElement("div");ie.className="tick3 "+(J??""),ie.textContent=R,n.appendChild(ie),Ae.push({el:ie,v:k,kind:J})}let oe=()=>{let R=[];for(let k=Math.floor(O)-1;k<=Math.ceil(ye)+1;k++)for(let J of[1,3]){let ie=J*10**k;Math.log10(ie)>=O&&Math.log10(ie)<=ye&&R.push(ie)}return R};function Re(){G(ve),Ae.forEach(J=>J.el.remove()),Ae.length=0;let R=[];for(let J=0;J<=60;J++){let ie=P+(U-P)*(J/60);R.push(me(ie,K()+.03,B))}ve.add(new Fi(new wt().setFromPoints(R),new jn({color:"#ffb27a",transparent:!0,opacity:.8})));for(let J of oe()){let ie=be(J);if(ie<P||ie>U)continue;let fe=K();ve.add(new Fi(new wt().setFromPoints([me(ie,fe,B),me(ie,fe+.25,B)]),new jn({color:"#ffb27a"}))),ee(i3(J),me(ie,fe-.35,B+.2),"cost")}ee(l()?"API \u53C2\u8003\u6210\u672C \u2192":"API reference cost \u2192",me(U-1.2,K()-1,B+.4),"axis");let k=[];for(let J=0;J<=40;J++){let ie=B-(B-W)*(J/40);k.push(me(U+.6,K()+.03,ie))}ve.add(new Fi(new wt().setFromPoints(k),new jn({color:"#c9b3ff",transparent:!0,opacity:.8})));for(let J of[.25,.5,1,2,4,8,16])J<=Se&&ee((l()?"\u4F30\u65F6 ":"Estimated time ")+J+(l()?"\u5206":" min"),me(U+1.2,K(),Ve(J)),"time");ee(l()?"\u822A\u65F6\u672A\u77E5 \xB7 \u524D\u6392":"Time unknown \xB7 front row",me(P+1.2,K()+.1,F),"lane")}let qe=new Oi(.1,.55,1,32,1,!0);qe.translate(0,-.5,0);let Pe=new Oi(.2,.7,1,32,1,!0);Pe.translate(0,-.5,0);let pe=new Map;function Ge(R){let k=pe.get(R.id);if(k)return k;let J=R.dev==="zhipu"?"zhipuai":R.dev,ie=Tr(J,R.colour).colour,fe=xe.raw({id:R.id,name:R.name,dev:J,colour:ie,shape:R.shape}),Ue=new Set([fe.hullMap,fe.boltMap,fe.steelMap]);fe.g.traverse(Nt=>{for(let Ht of[].concat(Nt.material||[]))for(let Q of Object.values(Ht))Q?.isTexture&&Q!==ge&&Ue.add(Q)});for(let Nt of Ue)Te.includes(Nt)||Te.push(Nt),vf(Nt,()=>Fn(0),Nt.image?.width===Nt.image?.height?256:512);yf(fe);let Ee=new gt(qe,new Ft({transparent:!0,depthWrite:!1,blending:nn,uniforms:{t:{value:0},k:{value:1},gc:{value:new I(1,.55,.25)},sc:{value:new I(.6,.66,.8)},sm:{value:.5}},vertexShader:fe.FLAME_V,fragmentShader:fe.TRAIL_F})),nt=new gt(Pe,new Ft({transparent:!0,depthWrite:!1,uniforms:{t:{value:0},k:{value:0}},vertexShader:fe.FLAME_V,fragmentShader:fe.SOOT_F})),De=new Fi(new wt().setFromPoints([me(0,0,0),me(0,-1,0)]),new jn({color:R.colour,transparent:!0,opacity:.22})),Xe=new gt(new fr(.2,.28,48),new en({color:R.colour,transparent:!0,opacity:.7,side:xn})),rt=new $i(new Ui({map:Je,color:R.colour,blending:nn,depthWrite:!1,transparent:!0,opacity:.3})),Et=new $i(new Ui({map:Je,color:"#b8c2d2",transparent:!0,depthWrite:!1,opacity:0})),yt=new qt;return yt.add(fe.g,fe.ring),X.add(yt,Ee,nt,De,Xe,rt,Et),k={m:R,factoryDeveloper:J,factoryColour:ie,...fe,root:yt,trail:Ee,soot:nt,drop:De,pad:Xe,padGlow:rt,smoke:Et,fuelKind:null,pos:me(0,0,0),tgt:me(0,0,0),born:performance.now()+pe.size*160,flare:1,phase:Math.random()*6.28,screen:null},pe.set(R.id,k),k}let et=null;function ht(R){let k=R.m.fuel??"mid";if(R.fuelKind===k)return;R.fuelKind=k;let J=R.FUEL[k];for(let ie of[R.outer,...R.bOuter])ie.material.uniforms.c0.value.set(J.o[0]),ie.material.uniforms.c1.value.set(J.o[1]);R.inner.material.uniforms.c0.value.set(J.i[0]),R.inner.material.uniforms.c1.value.set(J.i[1]),R.light.color.set(J.light),R.trail.material.uniforms.gc.value.set(...J.gc),R.trail.material.uniforms.sc.value.set(...J.sc),R.trail.material.uniforms.sm.value=J.sm}let D={yaw:-.26,pitch:.12},Ce={yaw:-.2,pitch:.16},re=null,we=null,Fe;function _e(){let R=u.models.filter(De=>x.has(De.id)&&g[De.id]);if(et=xf(R,De=>g[De.id][1],De=>De.dev==="zhipu"?"zhipuai":De.dev)?.id??null,!R.length)return;let k=i.embedded?R.flatMap(De=>De.e):R.map(De=>g[De.id]),J=k.map(De=>De[2]);if(O=Math.log10(Math.min(...J))-.22,ye=Math.log10(Math.max(...J))+.22,ye-O<1){let De=(O+ye)/2;O=De-.5,ye=De+.5}Se=Math.max(.6,...k.map(De=>De[3]??0))*1.15;let ie=k.map(De=>De[1]);de=Math.floor(Math.min(...ie))-4,te=Math.max(Math.ceil(Math.max(...ie))+3,de+14);for(let De of R){let Xe=Ge(De),rt=g[De.id];Xe.m=De,Xe.tgt.set(be(rt[2]),ae(rt[1]),Ve(rt[3])),Xe.nudge=0}let fe=i.embedded?[]:R.map(De=>pe.get(De.id)),Ue=C?1:1.3,Ee=(C?Ce:D).yaw,nt=De=>De.x*Math.cos(Ee)-De.z*Math.sin(Ee);for(let De=0;De<40;De++)for(let Xe=0;Xe<fe.length;Xe++)for(let rt=Xe+1;rt<fe.length;rt++){let Et=fe[Xe],yt=fe[rt],Nt=nt(yt.tgt)-nt(Et.tgt),Ht=(yt.tgt.y-Et.tgt.y)*.3,Q=Math.hypot(Nt,Ht);if(Q<Ue){let He=(Ue-Q)/2,pt=Nt>=0?1:-1;Et.tgt.x-=He*pt,yt.tgt.x+=He*pt,Et.nudge-=He*pt,yt.nudge+=He*pt}}for(let De of pe.values())De.started||(De.pos.copy(De.tgt),De.started=!0);$e(),Re(),ne(Math.max(...ie)),re=null,Fe=void 0}let Ke=new qt;X.add(Ke);let Ye=[];function Bt(R){if(G(Ke),Ye.forEach(Ee=>Ee.el.remove()),Ye.length=0,Fe=R,!R)return;let k=u.models.find(Ee=>Ee.id===R);if(!k||!pe.has(R))return;let J=k.colour,ie=pe.get(R)?.nudge??0,fe=k.e.map(Ee=>{let nt=be(Ee[2])+ie,De=Ve(Ee[3]);return me(nt,K()+ae(Ee[1]),De)}),Ue=new cr;for(let Ee=1;Ee<fe.length;Ee++)Ue.add(new lr(fe[Ee-1],fe[Ee]));fe.length>1&&Ke.add(new gt(new ya(Ue,120,.022,8,!1),new en({color:J,transparent:!0,opacity:.5,blending:nn,depthWrite:!1}))),k.e.forEach((Ee,nt)=>{let De=new gt(new zn(.1,16,12),new en({color:Ee[0]===k.reportedEffort?"#e5eceb":Ee[0]===k.rec?"#dfbf7a":"#0b1020"}));if(De.position.copy(fe[nt]),Ke.add(De),Ee[0]===k.previewEffort||Ee[3]==null||Ee[4]){let rt=new gt(new zi(Ee[0]===k.previewEffort?.2:.1,.025,8,24),new en({color:J}));rt.position.copy(fe[nt]),rt.userData.bill=!0,Ke.add(rt)}if(Ee[0]!==k.reportedEffort&&Ee[0]!==k.previewEffort)return;let Xe=document.createElement("div");Xe.className="bl3"+(Ee[0]===k.rec?" rec":"")+(Ee[0]===g[k.id]?.[0]?" cur":""),Xe.textContent=`${Ee[0]===k.previewEffort?"\u25C7 "+(i.labels?.preview??(l()?"\u9884\u89C8":"Preview"))+" ":"\u25CF "+(i.labels?.current??(l()?"\u5F53\u524D":"Current"))+" "}${Ee[0]}`,Xe.style.setProperty("--c",J),n.appendChild(Xe),Ye.push({el:Xe,v:fe[nt]})})}let vt=new _c($,new $t(1,1,{type:sn}));vt.addPass(new xc(X,he));let Sn=new Ar(new ue(256,256),.75,.28,.86);vt.addPass(Sn),vt.addPass(new vc);let ot={yaw:D.yaw,pitch:D.pitch,vy:0,vp:0,drag:null},ii=me(0,10,-2.4),ki=ii.clone(),Un=0;function os(){if(i.embedded)return i.compactFrame?i.canopyFrame?Rc(v,b,i.canopyProfile):{x:35,r:v-16,y:14,b:b-28}:{x:70,r:v-26,y:58,b:b-70};let R=e.getBoundingClientRect(),k=c()?.getBoundingClientRect(),J=h()?.getBoundingClientRect();return E()?{x:16,r:v-16,y:(k?k.bottom-R.top:200)+70,b:Math.min(b,innerHeight-R.top)-78}:{x:(k?k.right-R.left:420)+30+88,r:(J?J.left-R.left:v-360)-30,y:110,b:b-120}}let Qa=(R,k=R.tgt)=>me(k.x,K()+k.y,k.z);function eo(R){let k=R.nudge??0,J=Qa(R),ie=[J.clone().add(me(0,2.2,0)),J.clone().add(me(0,-2.4,0)),...R.m.e.map(Ht=>me(be(Ht[2])+k,K()+ae(Ht[1]),Ve(Ht[3])))],fe=ie.reduce((Ht,Q)=>Ht.min(Q),ie[0].clone()),Ue=ie.reduce((Ht,Q)=>Ht.max(Q),ie[0].clone()),Ee=fe.clone().add(Ue).multiplyScalar(.5),nt=e.getBoundingClientRect().top,De=Math.max(0,-nt)+64,Xe=e.querySelector(".sp-focus-bar")?.getBoundingClientRect(),rt=Math.min(b,innerHeight-nt,Xe?Xe.top-nt:b-150)-14,Et=Ce,yt=he.clone();yt.aspect=v/b,yt.clearViewOffset(),yt.updateProjectionMatrix();let Nt=24;for(let Ht=0;Ht<6;Ht++){yt.position.set(Ee.x+Nt*Math.sin(Et.yaw)*Math.cos(Et.pitch),Ee.y+Nt*Math.sin(Et.pitch),Ee.z+Nt*Math.cos(Et.yaw)*Math.cos(Et.pitch)),yt.lookAt(Ee),yt.updateMatrixWorld();let Q=ie.map(ut=>{let z=ut.clone().project(yt);return[(z.x*.5+.5)*v,(-z.y*.5+.5)*b]}),He=Q.map(ut=>ut[0]),pt=Q.map(ut=>ut[1]);Nt*=Math.max((Math.max(...He)-Math.min(...He))/(v-120),(Math.max(...pt)-Math.min(...pt))/Math.max(120,rt-De))*1.12}return{look:Ee,d:Math.max(8,Nt),fy:(De+rt)/2}}function to(){re=si(v,b,os())}function si(R,k,J){let ie=[me(P,K(),B),me(U,K(),B)];for(let De of pe.values())if(x.has(De.m.id)){let Xe=Qa(De);if(i.embedded)for(let rt of De.m.e)ie.push(me(be(rt[2]),ae(rt[1])+2.2,Ve(rt[3])));ie.push(Xe.clone().add(me(0,2.2,0)),Xe.clone().add(me(0,-2.4,0)))}let fe=E()?Ce:D,Ue=he.clone();Ue.aspect=R/k,Ue.clearViewOffset(),Ue.updateProjectionMatrix();let Ee=40,nt;for(let De=0;De<6;De++){Ue.position.set(ii.x+Ee*Math.sin(fe.yaw)*Math.cos(fe.pitch),ii.y+Ee*Math.sin(fe.pitch),ii.z+Ee*Math.cos(fe.yaw)*Math.cos(fe.pitch)),Ue.lookAt(ii),Ue.updateMatrixWorld();let Xe=ie.map(rt=>{let Et=rt.clone().project(Ue);return[(Et.x*.5+.5)*R,(-Et.y*.5+.5)*k]});nt={x0:Math.min(...Xe.map(rt=>rt[0])),x1:Math.max(...Xe.map(rt=>rt[0])),y0:Math.min(...Xe.map(rt=>rt[1])),y1:Math.max(...Xe.map(rt=>rt[1]))},Ee*=Math.max((nt.x1-nt.x0)/(J.r-J.x),(nt.y1-nt.y0)/(J.b-J.y))*1.02}return{d:Ee,ox:(nt.x0+nt.x1)/2-(J.x+J.r)/2,oy:(nt.y0+nt.y1)/2-(J.y+J.b)/2-(E()?24:0)}}function Ts(){v=e.clientWidth,b=e.clientHeight,!(!v||!b)&&($.setSize(v,b),he.aspect=v/b,he.updateProjectionMatrix(),vt.setSize(v,b),Sn.resolution.set(v,b),re=null,we=null,u.models.length&&($e(),Fn(1400)))}let Cr=new ResizeObserver(Ts);Cr.observe(e),Ts();let ri=$.domElement,ls=new Pa,Pr=new ue,cs=R=>{let k=ri.getBoundingClientRect();Pr.set((R.clientX-k.left)/k.width*2-1,-((R.clientY-k.top)/k.height)*2+1),ls.setFromCamera(Pr,he);let J=[...pe.values()].filter(fe=>x.has(fe.m.id)).map(fe=>fe.hit),ie=ls.intersectObjects(J)[0];return ie?[...pe.values()].find(fe=>fe.hit===ie.object).m.id:null},hs=R=>i.onSelect?.(R===S?null:R),no=R=>{ot.drag={x:R.clientX,y:R.clientY,yaw:ot.yaw,pitch:ot.pitch,still:!0},ri.setPointerCapture(R.pointerId),t.classList.add("dragging"),At=null,Fn(700)},bc=R=>{if(ot.drag){Math.hypot(R.clientX-ot.drag.x,R.clientY-ot.drag.y)>4&&(ot.drag.still=!1),ot.drag.still||(ot.yaw=ot.drag.yaw-(R.clientX-ot.drag.x)*.005,ot.pitch=Math.min(.9,Math.max(-.05,ot.drag.pitch+(R.clientY-ot.drag.y)*.0035)),ot.vy=ot.vp=0,Fn(700));return}if(R.pointerType==="touch")return;let k=cs(R);k!==m&&Fn(700),m=k,t.classList.toggle("over",!!m)},Ec=R=>{let k=ot.drag;if(ot.drag=null,t.classList.remove("dragging"),k&&!k.still){let J=E()?Ce:D;At={start:performance.now(),yaw:ot.yaw,pitch:ot.pitch,endYaw:J.yaw,endPitch:J.pitch},Fn(650);return}if(k?.still){let J=cs(R);J?hs(J):S&&!E()&&i.onSelect?.(null)}},Tc=()=>{!ot.drag&&m&&(m=null,Fn(700))};ri.addEventListener("pointerdown",no),ri.addEventListener("pointermove",bc),ri.addEventListener("pointerup",Ec),ri.addEventListener("pointerleave",Tc),ri.addEventListener("webglcontextlost",R=>{R.preventDefault(),i.onFail?.()});let Ir="",Mi=new I,M=R=>(Mi.copy(R).project(he),{x:(Mi.x*.5+.5)*v,y:(-Mi.y*.5+.5)*b,z:Mi.z}),N=null,j=R=>{if(N||!e.contains(R.target)||R.target.closest(`${i.panelSelector}, nav, header, button, a, .voyage, details`))return;let k=null,J=12;for(let ie of n.querySelectorAll(".plate")){let fe=ie.getBoundingClientRect(),Ue=Math.max(fe.left-R.clientX,0,R.clientX-fe.right),Ee=Math.max(fe.top-R.clientY,0,R.clientY-fe.bottom),nt=Math.hypot(Ue,Ee);nt<=J&&(J=nt,k=ie)}k&&(N={id:k.dataset.id,x:R.clientX,y:R.clientY})},q=R=>{let k=N;N=null,k&&Math.hypot(R.clientX-k.x,R.clientY-k.y)<14&&hs(k.id)},Y=()=>N=null;addEventListener("pointerdown",j,!0),addEventListener("pointerup",q),addEventListener("pointercancel",Y);let Oe="http://www.w3.org/2000/svg";function We(R,k,J=!1){for(let Q of[...n.children,...s.children])Q.style.transition=f||J?"none":"";let ie=u.models.filter(Q=>x.has(Q.id)&&g[Q.id]).sort((Q,He)=>g[He.id][1]-g[Q.id][1]),fe=(i.compactFrame?u.models.filter(Q=>x.has(Q.id)&&g[Q.id]).map(Q=>Q.id+o):ie.map(Q=>Q.id+g[Q.id][0]+o)).join("|");if(fe!==Ir&&(n.querySelectorAll(".plate").forEach(Q=>Q.remove()),s.replaceChildren(),ie.forEach((Q,He)=>{let pt=g[Q.id],ut=document.createElement("div");ut.className="plate",ut.dataset.id=Q.id,i.embedded&&(ut.setAttribute("role","button"),ut.setAttribute("aria-label",Q.name+" \xB7 "+pt[1].toFixed(1)+" \xB7 "+(pt[0]===Q.rec?"\u2605":"")+pt[0]+" \xB7 "+(l()?"\u9009\u62E9\u6A21\u578B":"Select model")),ut.tabIndex=0,ut.onkeydown=Tt=>{(Tt.key==="Enter"||Tt.key===" ")&&(Tt.preventDefault(),hs(Q.id))}),ut.style.setProperty("--c",Q.colour),ut.innerHTML=`<span class="rank">${He+1}</span><span class="lg">${a(Q.dev)}</span><b><span class="nf">${Rr(Q.name.match(/^Claude\s/)?"Claude ":"")}</span>${Rr(Q.name.replace(/^Claude\s/,""))}${Q.racer?`<i class="rz" title="${l()?"\u7ADE\u901F\uFF1A\u5B8C\u5DE5\u5FEB\u4E14\u51FA\u5B57\u5FEB":"Racer: fast tasks and fast output"}">\u26A1</i>`:""}</b><span class="lcdc"><span class="sep">\xB7</span><span class="v">${pt[1].toFixed(1)}</span><span class="sep">\xB7</span><span class="ef">${pt[0]===Q.rec?"<i>\u2605</i>":""}${Rr(pt[0])}</span></span>`,ut.title=`${Q.name} \xB7 ${pt[0]} \xB7 ${pt[1].toFixed(1)}`,ut.onmouseenter=()=>m=Q.id,ut.onmouseleave=()=>m=null,ut.onpointerdown=Tt=>{N={id:Q.id,x:Tt.clientX,y:Tt.clientY}},n.appendChild(ut);let z=document.createElementNS(Oe,"line");z.setAttribute("stroke",Q.colour),s.appendChild(z),ut.leader=z}),Ir=fe),i.compactFrame)for(let Q of n.querySelectorAll(".plate")){let He=u.models.find(z=>z.id===Q.dataset.id),pt=He&&g[He.id];if(!pt)continue;let ut=pt[0]+"|"+pt[1]+"|"+ie.findIndex(z=>z.id===He.id);Q.dataset.configuration!==ut&&(Q.querySelector(".v").textContent=pt[1].toFixed(1),Q.querySelector(".ef").innerHTML=(pt[0]===He.rec?"<i>\u2605</i>":"")+Rr(pt[0]),Q.querySelector(".rank").textContent=ie.findIndex(z=>z.id===He.id)+1,Q.title=He.name+" \xB7 "+pt[0]+" \xB7 "+pt[1].toFixed(1),Q.setAttribute("aria-label",He.name+" \xB7 "+pt[1].toFixed(1)+" \xB7 "+(pt[0]===He.rec?"\u2605":"")+pt[0]+" \xB7 "+(l()?"\u9009\u62E9\u6A21\u578B":"Select model")),Q.dataset.configuration=ut)}let Ue=os(),Ee=[],nt=[];for(let Q of pe.values())x.has(Q.m.id)&&Q.screen&&Q.base&&nt.push({x:Q.screen.x-7,y:Q.screen.y-6,w:14,h:Q.base.y-Q.screen.y+6,id:Q.m.id});let De=[...n.querySelectorAll(".plate")].map(Q=>({p:Q,r:pe.get(Q.dataset.id)})).filter(Q=>Q.r?.screen);i.compactFrame&&De.sort((Q,He)=>+(Q.p.dataset.id===R)-+(He.p.dataset.id===R)),De.forEach(({p:Q,r:He})=>{let pt=R===Q.dataset.id;Q.classList.toggle("hot",pt);let ut=Q.offsetWidth,z=Q.offsetHeight,Tt=He.screen.x,Zt=He.screen.y,ln=(An,li)=>Ee.some(Ut=>An<Ut.x+Ut.w+4&&Ut.x<An+ut+4&&li<Ut.y+Ut.h+3&&Ut.y<li+z+3),cn=An=>{let li=Math.max(Zt-z/2,...Ee.filter(Ut=>An<Ut.x+Ut.w+30&&Ut.x<An+ut+30).map(Ut=>Ut.y+2));for(let Ut=0;Ut<80&&ln(An,li);Ut++)li+=4;return li},Gn=Math.min(Ue.r+10-ut,Tt+12),ws=Math.max(Ue.x-10,Tt-12-ut),fs={x:Gn,y:cn(Gn)},Ei={x:ws,y:cn(ws)},Wn=Tt+12+ut>Ue.r+10||Ei.y+6<fs.y?Ei:fs;Ee.push({x:Wn.x,y:Wn.y,w:ut,h:z}),Q._x=J||Q._x==null||Math.abs(Q._x-Wn.x)>80?Wn.x:Q._x+(Wn.x-Q._x)*.25,Q._y=J||Q._y==null||Math.abs(Q._y-Wn.y)>80?Wn.y:Q._y+(Wn.y-Q._y)*.25,Q.style.transform=`translate(${Q._x}px, ${Q._y}px)`;let oi=R&&R!==Q.dataset.id&&nt.find(An=>An.id===R),pn=oi&&Q._x<oi.x+oi.w+6&&oi.x-6<Q._x+ut&&Q._y<oi.y+oi.h&&oi.y<Q._y+z,As=pn?.04:R&&!pt?S?i.embedded?.82:.42:i.embedded?.7:.22:f||J?1:Math.min(1,Math.max(0,(performance.now()-He.born-1200)/600));Q.style.opacity=As,Q.style.pointerEvents=pn&&!S?"none":"";let En=Q._x+ut/2<Tt,Xn=En?Q._x+ut:Q._x,Rs=Q._y+z/2,so=Math.hypot(Xn-Tt,Rs-Zt)>16,Ti=Q.leader;Ti.setAttribute("x1",Tt+(En?-4:4)),Ti.setAttribute("y1",Zt),Ti.setAttribute("x2",Xn),Ti.setAttribute("y2",Rs),Ti.style.opacity=so?As*.6:0});let Xe=n.getBoundingClientRect(),rt=[...n.querySelectorAll(".plate, .bl3")].filter(Q=>Q.style.opacity===""||Number(Q.style.opacity)>.08).map(Q=>{let He=Q.getBoundingClientRect();return{x:He.left-Xe.left,y:He.top-Xe.top,w:He.width,h:He.height}}),Et=(Q,He,pt,ut)=>rt.some(z=>Q<z.x+z.w+3&&z.x<Q+pt+3&&He<z.y+z.h+3&&z.y<He+ut+3),yt=[];for(let Q of[...L,...Ae]){let He=M(Q.v);if(Q.kind==="time"){yt.push({t:Q,s:He});continue}if(Q.el.classList.contains("next"))if(E()){let Zt=e.getBoundingClientRect();He.x=18,He.y=(c()?.getBoundingClientRect().bottom??200)-Zt.top+44}else He.y=Math.max(He.y,128);Q.el.style.transform=`translate(${He.x}px, ${He.y}px)`;let pt=Q.el.offsetWidth,ut=Q.el.offsetHeight,z=Q.kind==="cost"?He.x-pt/2:He.x,Tt=Q.el.classList.contains("orbit")?He.y-ut-4:He.y;Q.el.style.opacity=He.z<1&&z>=12&&z+pt<=v-12&&Tt>=12&&Tt+ut<=b-12&&!Et(z,Tt,pt,ut)?k*(1-Un):0}yt.sort((Q,He)=>Q.s.y-He.s.y);let Nt=40;for(let Q of yt){let He=Q.t.el.offsetHeight;Q.y=Math.max(Q.s.y,Nt+He/2+4),Nt=Q.y+He/2}let Ht=Math.max(0,Nt-(b-125));for(let{t:Q,s:He,y:pt}of yt){let ut=Q.el.offsetWidth,z=Q.el.offsetHeight,Tt=Math.min(He.x-8,v-72),Zt=pt-Ht-z/2;Q.el.style.transform=`translate(${Tt}px, ${pt-Ht}px)`,Q.el.style.opacity=He.z<1&&Tt-ut>=16&&Zt>=36&&!Et(Tt-ut,Zt,ut,z)?k*(1-Un):0}for(let Q of Ye){let He=M(Q.v);Q.el.style.transform=`translate(${He.x-105}px, ${He.y-10}px)`}if(J)for(let Q of[...n.children,...s.children])for(let He of Q.getAnimations())"transitionProperty"in He&&He.effect.getTiming().iterations!==1/0&&He.finish()}let Ne=[];function $e(){if(C||!r)return;let R=30,k=100,J=Xe=>(Math.max(R,Math.min(k,Xe))-R)/(k-R)*100,ie=u.models.filter(Xe=>x.has(Xe.id)&&g[Xe.id]).sort((Xe,rt)=>g[rt.id][1]-g[Xe.id][1]),fe=ie.length?g[ie[0].id][1]:0,Ue=e.getBoundingClientRect(),Ee=c()?.getBoundingClientRect();r.style.left=(Ee?Ee.right-Ue.left:400)+26+"px";let nt=`<div class="vbar"></div><div class="lead">${l()?`\u9886\u5148 ${fe.toFixed(1)} \xB7 \u8DDD\u661F\u8FB0\u5927\u6D77 ${(100-fe).toFixed(1)}`:`Leader ${fe.toFixed(1)} \xB7 ${(100-fe).toFixed(1)} to the stars`}</div><div class="vwin" style="bottom:${J(de)}%;height:${J(te)-J(de)}%" title="${l()?"3D \u89C6\u91CE\u91CC\u7684\u5206\u6570\u6BB5":"Score band shown in 3D"}"></div>`;nt+=Sc.map(([Xe,rt,Et])=>`<div class="vt ${Xe===100?"agi":""}" style="bottom:${J(Xe)}%"><b>${Xe===100?l()?"\u2605 \u661F\u8FB0\u5927\u6D77":"\u2605 The stars":l()?rt:Et}</b>${Xe}</div>`).join("");let De=[];nt+=ie.map(Xe=>{let rt=g[Xe.id][1],Et=De.filter(yt=>Math.abs(yt-rt)<.9).length;return De.push(rt),`<span class="vdot" data-id="${Rr(Xe.id)}" style="--c:${Xe.colour};bottom:${J(rt)}%;left:${11-Et*9}px" title="${Rr(Xe.name)} \xB7 ${rt.toFixed(1)}"></span>`}).join(""),r.innerHTML=nt,Ne=[...r.querySelectorAll(".vdot")],Ne.forEach(Xe=>{Xe.onmouseenter=()=>m=Xe.dataset.id,Xe.onmouseleave=()=>m=null,Xe.onclick=()=>hs(Xe.dataset.id)})}let Ze=[];function mt(R){for(let k of u.models){if(!x.has(k.id)||!g[k.id])continue;let J=R[k.id],ie=g[k.id][1],fe=pe.get(k.id);if(J==null||ie<=J||!fe)continue;let Ue=Sc.filter(([Ee])=>Ee>J&&Ee<=ie).pop();Ue&&(fe.cross=Ue)}}let _t=new zi(1,.035,8,96);function je(R,[k,J,ie]){let fe=new gt(_t,new en({color:k===100?"#ffd37a":"#9fd8ff",transparent:!0,blending:nn,depthWrite:!1}));fe.position.copy(R.root.position),fe.rotation.x=Math.PI/2,X.add(fe);let Ue=document.createElement("div");Ue.className="burst",Ue.textContent=k===100?l()?"\u2605 \u9A76\u51FA\u592A\u9633\u7CFB \xB7 \u5954\u5411\u661F\u8FB0\u5927\u6D77":"\u2605 Leaving the solar system \xB7 out to the stars":l()?`\u2726 \u8D8A\u8FC7${J}`:`\u2726 Past ${ie}`,n.appendChild(Ue),Ze.push({ring:fe,el:Ue,r:R,t0:performance.now()})}function Ct(R){for(let k=Ze.length-1;k>=0;k--){let J=Ze[k],ie=(R-J.t0)/1400;if(ie>=1){X.remove(J.ring),J.ring.material.dispose(),J.el.remove(),Ze.splice(k,1);continue}let fe=1-Math.pow(1-ie,3);J.ring.scale.setScalar(.4+fe*3.2),J.ring.material.opacity=(1-ie)*.9;let Ue=M(J.r.root.position.clone().add(me(0,1.9,0)));J.el.style.transform=`translate(${Ue.x}px, ${Ue.y-fe*26}px)`,J.el.style.opacity=ie<.15?ie/.15:1-Math.max(0,(ie-.6)/.4)}}let kt=0,Ot=performance.now(),It=Ot,Jt=!1,ze=0,Yt=0,bt=-1/0,dn=!0,tn=!i.onDemand,on=0,Si=0,Lt=0,At=null,bn=!1,Dt=[],wn=!1,ai=!1,bi="",io="",sh=0;function Uf(){if(!document.fonts)return!0;let R=new Map;for(let J of n.querySelectorAll("*")){if(!J.textContent?.trim())continue;let ie=getComputedStyle(J),fe=`${ie.fontStyle} ${ie.fontWeight} ${ie.fontSize} ${ie.fontFamily}`;R.set(fe,(R.get(fe)||"")+J.textContent)}let k=[...R.keys()].sort().join("|");if(k===bi)return!0;if(k!==io){io=k;let J=++sh;Promise.all([...R].map(([ie,fe])=>document.fonts.load(ie,fe).catch(()=>[]))).then(()=>document.fonts.ready).then(()=>{wn||J!==sh||(bi=k,Fn(0))})}return!1}function us(){if(wn||document.hidden||!dn||ze||Yt||!(tn||bn||on>0))return;let R=i.onDemand?Math.max(0,1e3/30-(performance.now()-bt)):0;R>0?Yt=setTimeout(()=>{Yt=0,us()},Math.ceil(R)):ze=requestAnimationFrame(Bf)}function Ff(R){tn=!!R,tn||(on=0),us()}function Fn(R){ai=!1,Lt++,bn=!0,on=Math.max(on,performance.now()+Math.max(0,R)),us()}function Of(R){return wn?Promise.reject(new Error("field disposed")):new Promise((k,J)=>{Dt.push({resolve:k,reject:J,options:R}),Fn(0)})}let Lr=0,wc=0,rh=0,ah=!i.onSlow;function oh(){cancelAnimationFrame(ze),clearTimeout(Yt),ze=Yt=0}function Ac(){document.hidden||!dn?oh():(bn=!0,us())}document.addEventListener("visibilitychange",Ac);let lh=new IntersectionObserver(([R])=>{dn=R?.isIntersecting??!0,Ac()});lh.observe(e);function Bf(R){if(ze=0,!tn&&!on&&!bn)return;if(R>=on&&(on=0),document.hidden||!dn||!v||!b||!u.models.length){Lr=0,tn&&us();return}bn=!1,bt=R,Si++,!ah&&Jt&&R-Ot>1500&&(Lr&&R-Lr<1e3&&(wc+=R-Lr,rh++),Lr=R,wc>=3e3&&(ah=!0,rh*1e3/wc<20&&i.onSlow()));let k=f?0:R/1e3,J=f?1:Math.min(1,(R-It)/1800),ie=S??m??p;if(At){let z=Math.min(1,(R-At.start)/600),Tt=1-(1-z)**3;ot.yaw=At.yaw+(At.endYaw-At.yaw)*Tt,ot.pitch=At.pitch+(At.endPitch-At.pitch)*Tt,z>=1&&(At=null)}else if(!ot.drag||ot.drag.still){let z=E()?Ce:D,Tt=f||ie?0:Math.sin(k/3.6)*.03;ot.vy=ot.vy*.85+(z.yaw+Tt-ot.yaw)*.03,ot.yaw+=ot.vy,ot.vp=ot.vp*.85+(z.pitch-ot.pitch)*.03,ot.pitch+=ot.vp}if(re||to(),!we||f)we={...re};else for(let z of["d","ox","oy"])we[z]+=(re[z]-we[z])*.06;let fe=!i.embedded&&S&&x.has(S)&&pe.get(S),Ue=os();Un+=((fe?1:0)-Un)*(f?1:.06);let Ee=E()&&fe?eo(fe):null;ki.lerp(Ee?Ee.look:fe?fe.root.position.clone().add(me(0,.3,0)):ii,f?1:.08);let nt=f?1:Math.min(1,(R-It)/5200),De=1-Math.pow(1-nt,3),Xe=ot.pitch-.07*(1-De);kt*=.93;let rt=Ee?Ee.fy:(Ue.y+Ue.b)/2,Et=Ee?Ee.d:Math.min(26,we.d*.55),yt=(we.d+(Et-we.d)*Un)*(1-.2*(1-De)),Nt=we.ox+(v/2-(Ue.x+Ue.r)/2-we.ox)*Un,Ht=we.oy+(b/2-rt-we.oy)*Un;he.position.set(ki.x+yt*Math.sin(ot.yaw)*Math.cos(Xe),ki.y+yt*Math.sin(Xe),ki.z+yt*Math.cos(ot.yaw)*Math.cos(Xe)),he.lookAt(ki),kt>.01&&he.position.add(me(Math.sin(k*61),Math.sin(k*47+1),Math.sin(k*53+2)).multiplyScalar(.007*yt*kt)),he.setViewOffset(v,b,Nt,Ht,v,b),Sn.strength=.8-.38*Un+.55*kt,$.toneMappingExposure=1.05-.15*Un,ke.update(f?0:k),tt.uniforms.t.value=k,Qe.children.forEach(z=>{z.userData.spin&&(z.rotation.y=k*.15)});let Q=i.embedded&&!d?null:ie;Q!==Fe&&Bt(Q);let He=E()?.68:.88;for(let z of pe.values()){let Tt=x.has(z.m.id)&&!!g[z.m.id];if(Tt||(z.soot.visible=!1),z.root.visible=z.trail.visible=z.drop.visible=z.pad.visible=z.padGlow.visible=z.smoke.visible=Tt,!Tt)continue;z.pos.lerp(z.tgt,f?1:.08),z.flare+=(1-z.flare)*.035;let Zt=R-z.born,ln=f?1:Math.max(0,Math.min(1,Zt/650)),cn=f?1:Math.max(0,Math.min(1,(Zt-550)/2400)),Gn=cn<.5?4*cn**3:1-Math.pow(-2*cn+2,3)/2,ws=ln*(1-cn),fs=ln*(1-Gn),Ei=K(),Wn=Ei+1.5+(z.pos.y-1.5)*Gn,oi=g[z.m.id],pn=Math.max(.15,Math.min(1,(Math.log10(oi[2])+2.2)/2.8))*z.flare+ws*.9,As=ie===z.m.id||m===z.m.id,En=ie&&!As?i.embedded?.72:.2:1;z.root.position.set(z.pos.x,Wn+(f?0:Math.sin(k*1.1+z.phase)*.06),z.pos.z),ht(z);let Xn=z.m.id===et;z.heavy.visible=Xn;let Rs=!Xn&&z.m.racer;z.racer.visible=Rs,z.stdParts.forEach(Ut=>Ut.visible=!Xn);let so=Xn?z.steelMap:Rs?z.boltMap:z.hullMap;z.steel.metalness=Xn?.92:.35,z.steel.roughness=Xn?.2:.34,z.steel.map!==so&&(z.steel.map=so,z.steel.needsUpdate=!0),Rs&&z.streaks.forEach(Ut=>{let Cs=f?Ut.userData.o:(k*1.6+Ut.userData.o)%1;Ut.position.y=1.2-Cs*2.8,Ut.material.opacity=.65*Math.sin(Cs*Math.PI)*En});let Ti=Xn?z.heavyNozzle:z.NOZZLE_Y;z.outer.position.y=z.inner.position.y=Ti+.02,z.light.position.y=Ti-.45,z.halo&&(z.halo.rotation.y=f?0:k*.7),z.root.scale.setScalar(He*(i.embedded?1.15:1)*(As?1.12:1)*(Xn?1.18:1));{let Ut=S===z.m.id||z.m.id===et?ot.yaw-.4*Math.PI:k*.12+z.phase,Cs=z.g.rotation.y;z.g.rotation.y=Cs+Math.atan2(Math.sin(Ut-Cs),Math.cos(Ut-Cs))*(f?1:.08)}z.g.rotation.z=f?0:Math.sin(k*.7+z.phase)*.02,z.mats.forEach(Ut=>Ut.opacity=En),z.outer.material.uniforms.t.value=z.inner.material.uniforms.t.value=z.trail.material.uniforms.t.value=z.soot.material.uniforms.t.value=k;for(let Ut of z.bOuter)Ut.material.uniforms.t.value=k,Ut.material.uniforms.k.value=En*(.15+.85*ln),Ut.scale.set(.8+pn*.6,.6+pn*1.2,.8+pn*.6);z.outer.material.uniforms.k.value=z.inner.material.uniforms.k.value=En*(.15+.85*ln),z.trail.material.uniforms.k.value=En*.8*ln,z.outer.scale.set((.8+pn*.6)*(z.racer.visible?.75:1),(.6+pn*1.2)*(z.racer.visible?1.45:1),(.8+pn*.6)*(z.racer.visible?.75:1)),z.inner.scale.set(1,.7+pn*.6,1),z.light.intensity=(.6+pn*1.4)*En,z.ring.visible=As&&S!==z.m.id&&oi[0]===z.m.rec,z.ring.quaternion.copy(he.quaternion),z.ring.material.opacity=En;let An=z.root.position.y+Ti*z.root.scale.y,li=Math.max(.05,An-Ei);z.trail.position.set(z.pos.x,An-.3,z.pos.z),z.trail.scale.set(.5+pn*.8,Math.max(.05,Math.min(li-.3,2.6+pn*1.2)),.5+pn*.8),z.soot.visible=z.fuelKind==="lo",z.soot.position.set(z.pos.x,An-.5,z.pos.z),z.soot.scale.set(.55+pn*.5,Math.max(.05,Math.min(li-.5,1.6+pn*.9)),.55+pn*.5),z.soot.material.uniforms.k.value=En*ln,z.drop.position.set(z.pos.x,An,z.pos.z),z.drop.scale.y=li,z.drop.material.opacity=.22*En,z.pad.position.set(z.pos.x,Ei+.02,z.pos.z),z.pad.rotation.x=-Math.PI/2,z.pad.material.opacity=.7*En,z.padGlow.position.set(z.pos.x,Ei+.1,z.pos.z),z.padGlow.scale.setScalar(1.4+3.2*fs),z.padGlow.material.opacity=En*Math.max(.3*Gn,.7*fs),z.smoke.position.set(z.pos.x,Ei+.5+cn*.8,z.pos.z),z.smoke.scale.setScalar(1.2+2.5*ln+4.5*cn),z.smoke.material.opacity=.3*fs*En,z.smoke.visible=fs>0,z.cross&&cn>=1&&Wn-Ei>=ae(z.cross[0])-.05&&(z.cross[0]>=de-.01&&je(z,z.cross),z.cross=null),z.screen=M(Mi.set(z.pos.x,z.root.position.y+1.2*z.root.scale.y,z.pos.z)),z.base=M(Mi.set(z.pos.x,An-.8,z.pos.z))}Ke.children.forEach(z=>{z.userData.bill&&z.quaternion.copy(he.quaternion)}),Ct(R);let pt=!!(At||Ze.length||[...pe.values()].some(z=>x.has(z.m.id)&&(!f&&R<z.born+2950||z.pos.distanceToSquared(z.tgt)>25e-6))||we&&re&&["d","ox","oy"].some(z=>Math.abs(we[z]-re[z])>.02)||ki.distanceToSquared(ii)>25e-6),ut=i.onDemand&&!tn&&!on&&!pt;if(vt.render(),We(ie,J,ut&&bi===io&&!!bi),ai=ut&&Uf(),Ne.forEach(z=>z.classList.toggle("hot",z.dataset.id===ie)),Dt.length){let z=Dt.splice(0);try{for(let{resolve:Tt,options:Zt}of z){if(!Zt){Tt($.domElement.toDataURL("image/png"));continue}if(Zt.canopyFrame){let ws=uh({renderer:$,composer:vt,camera:he,fit:si,target:ii,home:E()?Ce:D,width:Zt.width,height:Zt.height,liveWidth:v,liveHeight:b,profile:Zt.canopyProfile});Tt(Q0(ws));continue}let ln=document.createElement("canvas"),cn=$.domElement;ln.width=Zt.width,ln.height=Zt.height;let Gn=Math.max(ln.width/cn.width,ln.height/cn.height);ln.getContext("2d").drawImage(cn,(ln.width-cn.width*Gn)/2,(ln.height-cn.height*Gn)/2,cn.width*Gn,cn.height*Gn),Tt(Q0(ln))}}catch(Tt){z.forEach(({reject:Zt})=>Zt(Tt))}}i.onDemand&&pt&&(bn=!0),us()}return us(),{setActive:Ff,renderFor:Fn,captureStill:Of,stats:()=>({frames:Si,requests:Lt,active:tn,labelsSettled:ai,fontsSettled:!!bi&&bi===io,scheduled:!!ze||!!Yt,yaw:ot.yaw,pitch:ot.pitch,defaultYaw:(E()?Ce:D).yaw,defaultPitch:(E()?Ce:D).pitch}),update(R){R.effortPath!==void 0&&d!==R.effortPath&&(d=R.effortPath,Fe=void 0);let k=Object.fromEntries(Object.entries(g).map(([Ue,Ee])=>[Ue,Ee[1]])),J=x,ie=R.language!==o;o=R.language,u={models:R.models};for(let Ue of Object.keys(g))delete g[Ue];for(let Ue of R.models)Ue.sel&&(g[Ue.id]=Ue.sel);x=new Set(R.shown.filter(Ue=>g[Ue])),S=R.focus&&x.has(R.focus)?R.focus:null,p=R.hint&&x.has(R.hint)?R.hint:null;let fe=performance.now();if(Jt){let Ue=[...x].filter(Ee=>!J.has(Ee));_e(),Ue.forEach((Ee,nt)=>{let De=pe.get(Ee);De&&(De.born=fe+nt*120)}),mt(k)}else{Ot=fe;let Ue=Df;It=Ue||i.noIntro?fe-6e3:fe,_e(),u.models.filter(Ee=>x.has(Ee.id)).sort((Ee,nt)=>g[nt.id][1]-g[Ee.id][1]).forEach((Ee,nt)=>Ge(Ee).born=Ue||i.noIntro?fe-4e3:fe+700+nt*300),Jt=Df=!0}ie&&(Ir=""),Fn(i.noIntro?1400:5400)},thrust(){kt=1,Fn(1800)},dispose(){if(!wn){wn=!0,Dt.splice(0).forEach(({reject:R})=>R(new Error("field disposed"))),oh(),document.removeEventListener("visibilitychange",Ac),tn=!1,on=0,Cr.disconnect(),lh.disconnect(),removeEventListener("pointerdown",j,!0),removeEventListener("pointerup",q),removeEventListener("pointercancel",Y);for(let R of pe.values()){R.mats.forEach(k=>k.dispose()),R.halo?.traverse(k=>{k.geometry?.dispose(),k.material?.dispose()}),R.root.traverse(k=>{k.geometry?.dispose();for(let J of Array.isArray(k.material)?k.material:k.material?[k.material]:[]){for(let ie of Object.values(J))ie?.isTexture&&ie!==ge&&ie.dispose();J.dispose()}});for(let k of[R.trail,R.soot,R.drop,R.pad,R.padGlow,R.smoke])k.material.dispose(),k.geometry!==qe&&k.geometry!==Pe&&k.geometry?.dispose()}qe.dispose(),Pe.dispose(),_t.dispose(),G(Qe),G(ve),G(Ke),ke.dispose(),xe.dispose(),Te.forEach(R=>R.dispose()),X.traverse(R=>{R.isInstancedMesh&&R.dispose(),R.geometry?.dispose(),R.material?.dispose?.()}),vt.passes.forEach(R=>R.dispose()),vt.dispose(),$.forceContextLoss(),$.dispose(),X.clear(),pe.clear(),Te.length=0,t.replaceChildren(),n.querySelectorAll(".plate, .ltag, .tick3, .bl3, .burst").forEach(R=>R.remove()),s.replaceChildren(),r&&r.replaceChildren()}}}}function ty(i,{models:e,focus:t,onSelect:n,onFail:s,quiet:r=!1,showPath:a=!1,compactFrame:o=!1,canopyFrame:l=!1,canopyProfile:c,language:h="zh",onDemand:f=!1,noIntro:u=!1,stillCapture:d=!1,labels:g=null}){let x=S=>`<img src="assets/brands/${S==="anthropic"?"claude.svg":S==="zhipu"?"zhipu.svg":"openai-white.svg"}" alt="">`,m;try{m=Nf({launch:i,host:i.querySelector(".wb-canvas"),plates:i.querySelector(".wb-plates"),leaders:i.querySelector(".wb-leaders"),voyage:i.querySelector(".wb-voyage"),copySelector:".not-mounted-copy",panelSelector:".not-mounted-panel",embedded:!0,compactFrame:o,canopyFrame:l,canopyProfile:c,quiet:r,onDemand:f,noIntro:u,stillCapture:d,labels:g,showEffortPath:a,language:h,logo:x,onSelect:n,onFail:s})}catch(S){return s?.(S),{update(){},setActive(){},renderFor(){},captureStill:()=>Promise.reject(S),stats:()=>({frames:0,active:!1,scheduled:!1}),dispose(){}}}let p=(S,A,v=a)=>m.update({effortPath:v,language:h,models:S,shown:S.map(b=>b.id),focus:A,hint:null});return p(e,t),{update:p,setActive:S=>m.setActive(S),renderFor:S=>m.renderFor(S),captureStill:S=>m.captureStill(S),stats:()=>m.stats(),dispose:()=>m.dispose(),thrust:()=>m.thrust()}}export{ty as mountWorkbenchField};
/*! Bundled license information:

three/build/three.core.js:
three/build/three.module.js:
  (**
   * @license
   * Copyright 2010-2026 Three.js Authors
   * SPDX-License-Identifier: MIT
   *)
*/
