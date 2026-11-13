/*! SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
 * Copyright (c) 2026 ModelPlan. All rights reserved. ModelPlan and Model Plan are marks of ModelPlan. No trademark rights are granted.
 * Minified 3D launch-field scene for the official cockpit's enlarged porthole (owner D39/D-A); see README.md.
 * Bundles three.js 0.186.1 (MIT; its notice is at the end of this file). */
var Lh="c01-joined-fit-v1";function Dh(i,t){let e=t/i<.13,n=i/636;return{x:(e?300:272)*n,r:580*n,y:(e?8:18)*n,b:t-(e?10:34)*n}}function Xc(i,t,e){if(e===Lh)return Dh(i,t);let n=t/i<.13,s=i/636;return{x:i*(n?.52:.44),r:i-32*s,y:(n?8:12)*s,b:t-(n?10:20)*s}}function Nh({renderer:i,composer:t,camera:e,fit:n,target:s,home:r,width:a,height:o,liveWidth:l,liveHeight:c,profile:h}){let f=e.clone();try{let u=n(a,o,Xc(a,o,h));e.aspect=a/o,e.position.set(s.x+u.d*Math.sin(r.yaw)*Math.cos(r.pitch),s.y+u.d*Math.sin(r.pitch),s.z+u.d*Math.cos(r.yaw)*Math.cos(r.pitch)),e.lookAt(s),e.setViewOffset(a,o,u.ox,u.oy,a,o),i.setSize(a,o,!1),t.setSize(a,o),t.render();let d=document.createElement("canvas");return d.width=a,d.height=o,d.getContext("2d").drawImage(i.domElement,0,0,a,o),d}finally{e.copy(f),i.setSize(l,c,!1),t.setSize(l,c),t.render()}}var yu=0,D0=1,Mu=2;var qa=1,Su=2,wr=3,hs=0,bn=1,En=2,Qn=0,us=1,hn=2,N0=3,U0=4,bu=5;var As=100,Eu=101,Tu=102,wu=103,Au=104,Ru=200,Cu=201,Pu=202,Iu=203,F0=204,O0=205,Lu=206,Du=207,Nu=208,Uu=209,Fu=210,Ou=211,Bu=212,zu=213,ku=214,Qo=0,tl=1,el=2,rr=3,nl=4,il=5,sl=6,rl=7,B0=0,Hu=1,Vu=2,ui=0,Ya=1,$a=2,Za=3,Rs=4,Ja=5,Ka=6,ja=7;var z0=300,fs=301,Cs=302,Ar=303,Nl=304,Qa=306,ns=1e3,vi=1001,al=1002,gn=1003,Gu=1004;var to=1005;var Sn=1006,Ul=1007;var Ti=1008;var Fn=1009,k0=1010,H0=1011,Rr=1012,Fl=1013,fi=1014,ti=1015,un=1016,Ol=1017,Bl=1018,Cr=1020,V0=35902,G0=35899,W0=1021,X0=1022,ei=1023,Mi=1026,ds=1027,zl=1028,kl=1029,ps=1030,Hl=1031;var Vl=1033,eo=33776,no=33777,io=33778,so=33779,Gl=35840,Wl=35841,Xl=35842,ql=35843,Yl=36196,$l=37492,Zl=37496,Jl=37488,Kl=37489,ro=37490,jl=37491,Ql=37808,tc=37809,ec=37810,nc=37811,ic=37812,sc=37813,rc=37814,ac=37815,oc=37816,lc=37817,cc=37818,hc=37819,uc=37820,fc=37821,dc=36492,pc=36494,mc=36495,gc=36283,xc=36284,ao=36285,_c=36286;var oa=2300,ol=2301,Jo=2302,y0=2303,M0=2400,S0=2401,b0=2402;var Wu=3200;var vc=0,Xu=1,di="",Ke="srgb",la="srgb-linear",ca="linear",Fe="srgb";var Ko=7680;var qu=519,Yu=512,$u=513,Zu=514,yc=515,Ju=516,Ku=517,Mc=518,ju=519,q0=35044;var Y0="300 es",li=2e3,ar=2001;function hd(i){for(let t=i.length-1;t>=0;--t)if(i[t]>=65535)return!0;return!1}function ud(i){return ArrayBuffer.isView(i)&&!(i instanceof DataView)}function or(i){return document.createElementNS("http://www.w3.org/1999/xhtml",i)}function Qu(){let i=or("canvas");return i.style.display="block",i}var Uh={},lr=null;function ha(...i){let t="THREE."+i.shift();lr?lr("log",t,...i):console.log(t,...i)}function tf(i){let t=i[0];if(typeof t=="string"&&t.startsWith("TSL:")){let e=i[1];e&&e.isStackTrace?i[0]+=" "+e.getLocation():i[1]='Stack trace not available. Enable "THREE.Node.captureStackTrace" to capture stack traces.'}return i}function ue(...i){i=tf(i);let t="THREE."+i.shift();if(lr)lr("warn",t,...i);else{let e=i[0];e&&e.isStackTrace?console.warn(e.getError(t)):console.warn(t,...i)}}function he(...i){i=tf(i);let t="THREE."+i.shift();if(lr)lr("error",t,...i);else{let e=i[0];e&&e.isStackTrace?console.error(e.getError(t)):console.error(t,...i)}}function Es(...i){let t=i.join(" ");t in Uh||(Uh[t]=!0,ue(...i))}function ef(i,t,e){return new Promise(function(n,s){function r(){switch(i.clientWaitSync(t,i.SYNC_FLUSH_COMMANDS_BIT,0)){case i.WAIT_FAILED:s();break;case i.TIMEOUT_EXPIRED:setTimeout(r,e);break;default:n()}}setTimeout(r,e)})}var nf={[Qo]:tl,[el]:sl,[nl]:rl,[rr]:il,[tl]:Qo,[sl]:el,[rl]:nl,[il]:rr},Si=class{addEventListener(t,e){this._listeners===void 0&&(this._listeners={});let n=this._listeners;n[t]===void 0&&(n[t]=[]),n[t].indexOf(e)===-1&&n[t].push(e)}hasEventListener(t,e){let n=this._listeners;return n===void 0?!1:n[t]!==void 0&&n[t].indexOf(e)!==-1}removeEventListener(t,e){let n=this._listeners;if(n===void 0)return;let s=n[t];if(s!==void 0){let r=s.indexOf(e);r!==-1&&s.splice(r,1)}}dispatchEvent(t){let e=this._listeners;if(e===void 0)return;let n=e[t.type];if(n!==void 0){t.target=this;let s=n.slice(0);for(let r=0,a=s.length;r<a;r++)s[r].call(this,t);t.target=null}}},Cn=["00","01","02","03","04","05","06","07","08","09","0a","0b","0c","0d","0e","0f","10","11","12","13","14","15","16","17","18","19","1a","1b","1c","1d","1e","1f","20","21","22","23","24","25","26","27","28","29","2a","2b","2c","2d","2e","2f","30","31","32","33","34","35","36","37","38","39","3a","3b","3c","3d","3e","3f","40","41","42","43","44","45","46","47","48","49","4a","4b","4c","4d","4e","4f","50","51","52","53","54","55","56","57","58","59","5a","5b","5c","5d","5e","5f","60","61","62","63","64","65","66","67","68","69","6a","6b","6c","6d","6e","6f","70","71","72","73","74","75","76","77","78","79","7a","7b","7c","7d","7e","7f","80","81","82","83","84","85","86","87","88","89","8a","8b","8c","8d","8e","8f","90","91","92","93","94","95","96","97","98","99","9a","9b","9c","9d","9e","9f","a0","a1","a2","a3","a4","a5","a6","a7","a8","a9","aa","ab","ac","ad","ae","af","b0","b1","b2","b3","b4","b5","b6","b7","b8","b9","ba","bb","bc","bd","be","bf","c0","c1","c2","c3","c4","c5","c6","c7","c8","c9","ca","cb","cc","cd","ce","cf","d0","d1","d2","d3","d4","d5","d6","d7","d8","d9","da","db","dc","dd","de","df","e0","e1","e2","e3","e4","e5","e6","e7","e8","e9","ea","eb","ec","ed","ee","ef","f0","f1","f2","f3","f4","f5","f6","f7","f8","f9","fa","fb","fc","fd","fe","ff"];var qc=Math.PI/180,ll=180/Math.PI;function ki(){let i=Math.random()*4294967295|0,t=Math.random()*4294967295|0,e=Math.random()*4294967295|0,n=Math.random()*4294967295|0;return(Cn[i&255]+Cn[i>>8&255]+Cn[i>>16&255]+Cn[i>>24&255]+"-"+Cn[t&255]+Cn[t>>8&255]+"-"+Cn[t>>16&15|64]+Cn[t>>24&255]+"-"+Cn[e&63|128]+Cn[e>>8&255]+"-"+Cn[e>>16&255]+Cn[e>>24&255]+Cn[n&255]+Cn[n>>8&255]+Cn[n>>16&255]+Cn[n>>24&255]).toLowerCase()}function we(i,t,e){return Math.max(t,Math.min(e,i))}function fd(i,t){return(i%t+t)%t}function Yc(i,t,e){return(1-e)*i+e*t}function _i(i,t){switch(t.constructor){case Float32Array:return i;case Uint32Array:return i/4294967295;case Uint16Array:return i/65535;case Uint8Array:case Uint8ClampedArray:return i/255;case Int32Array:return Math.max(i/2147483647,-1);case Int16Array:return Math.max(i/32767,-1);case Int8Array:return Math.max(i/127,-1);default:throw new Error("THREE.MathUtils: Invalid component type.")}}function We(i,t){switch(t.constructor){case Float32Array:return i;case Uint32Array:return Math.round(i*4294967295);case Uint16Array:return Math.round(i*65535);case Uint8Array:case Uint8ClampedArray:return Math.round(i*255);case Int32Array:return Math.round(i*2147483647);case Int16Array:return Math.round(i*32767);case Int8Array:return Math.round(i*127);default:throw new Error("THREE.MathUtils: Invalid component type.")}}var ft=class i{static{i.prototype.isVector2=!0}constructor(t=0,e=0){this.x=t,this.y=e}get width(){return this.x}set width(t){this.x=t}get height(){return this.y}set height(t){this.y=t}set(t,e){return this.x=t,this.y=e,this}setScalar(t){return this.x=t,this.y=t,this}setX(t){return this.x=t,this}setY(t){return this.y=t,this}setComponent(t,e){switch(t){case 0:this.x=e;break;case 1:this.y=e;break;default:throw new Error("THREE.Vector2: index is out of range: "+t)}return this}getComponent(t){switch(t){case 0:return this.x;case 1:return this.y;default:throw new Error("THREE.Vector2: index is out of range: "+t)}}clone(){return new this.constructor(this.x,this.y)}copy(t){return this.x=t.x,this.y=t.y,this}add(t){return this.x+=t.x,this.y+=t.y,this}addScalar(t){return this.x+=t,this.y+=t,this}addVectors(t,e){return this.x=t.x+e.x,this.y=t.y+e.y,this}addScaledVector(t,e){return this.x+=t.x*e,this.y+=t.y*e,this}sub(t){return this.x-=t.x,this.y-=t.y,this}subScalar(t){return this.x-=t,this.y-=t,this}subVectors(t,e){return this.x=t.x-e.x,this.y=t.y-e.y,this}multiply(t){return this.x*=t.x,this.y*=t.y,this}multiplyScalar(t){return this.x*=t,this.y*=t,this}divide(t){return this.x/=t.x,this.y/=t.y,this}divideScalar(t){return this.multiplyScalar(1/t)}applyMatrix3(t){let e=this.x,n=this.y,s=t.elements;return this.x=s[0]*e+s[3]*n+s[6],this.y=s[1]*e+s[4]*n+s[7],this}min(t){return this.x=Math.min(this.x,t.x),this.y=Math.min(this.y,t.y),this}max(t){return this.x=Math.max(this.x,t.x),this.y=Math.max(this.y,t.y),this}clamp(t,e){return this.x=we(this.x,t.x,e.x),this.y=we(this.y,t.y,e.y),this}clampScalar(t,e){return this.x=we(this.x,t,e),this.y=we(this.y,t,e),this}clampLength(t,e){let n=this.length();return this.divideScalar(n||1).multiplyScalar(we(n,t,e))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this}negate(){return this.x=-this.x,this.y=-this.y,this}dot(t){return this.x*t.x+this.y*t.y}cross(t){return this.x*t.y-this.y*t.x}lengthSq(){return this.x*this.x+this.y*this.y}length(){return Math.sqrt(this.x*this.x+this.y*this.y)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)}normalize(){return this.divideScalar(this.length()||1)}angle(){return Math.atan2(-this.y,-this.x)+Math.PI}angleTo(t){let e=Math.sqrt(this.lengthSq()*t.lengthSq());if(e===0)return Math.PI/2;let n=this.dot(t)/e;return Math.acos(we(n,-1,1))}distanceTo(t){return Math.sqrt(this.distanceToSquared(t))}distanceToSquared(t){let e=this.x-t.x,n=this.y-t.y;return e*e+n*n}manhattanDistanceTo(t){return Math.abs(this.x-t.x)+Math.abs(this.y-t.y)}setLength(t){return this.normalize().multiplyScalar(t)}lerp(t,e){return this.x+=(t.x-this.x)*e,this.y+=(t.y-this.y)*e,this}lerpVectors(t,e,n){return this.x=t.x+(e.x-t.x)*n,this.y=t.y+(e.y-t.y)*n,this}equals(t){return t.x===this.x&&t.y===this.y}fromArray(t,e=0){return this.x=t[e],this.y=t[e+1],this}toArray(t=[],e=0){return t[e]=this.x,t[e+1]=this.y,t}fromBufferAttribute(t,e){return this.x=t.getX(e),this.y=t.getY(e),this}rotateAround(t,e){let n=Math.cos(e),s=Math.sin(e),r=this.x-t.x,a=this.y-t.y;return this.x=r*n-a*s+t.x,this.y=r*s+a*n+t.y,this}random(){return this.x=Math.random(),this.y=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y}},bi=class{constructor(t=0,e=0,n=0,s=1){this.isQuaternion=!0,this._x=t,this._y=e,this._z=n,this._w=s}static slerpFlat(t,e,n,s,r,a,o){let l=n[s+0],c=n[s+1],h=n[s+2],f=n[s+3],u=r[a+0],d=r[a+1],g=r[a+2],_=r[a+3];if(f!==_||l!==u||c!==d||h!==g){let m=l*u+c*d+h*g+f*_;m<0&&(u=-u,d=-d,g=-g,_=-_,m=-m);let p=1-o;if(m<.9995){let S=Math.acos(m),A=Math.sin(S);p=Math.sin(p*S)/A,o=Math.sin(o*S)/A,l=l*p+u*o,c=c*p+d*o,h=h*p+g*o,f=f*p+_*o}else{l=l*p+u*o,c=c*p+d*o,h=h*p+g*o,f=f*p+_*o;let S=1/Math.sqrt(l*l+c*c+h*h+f*f);l*=S,c*=S,h*=S,f*=S}}t[e]=l,t[e+1]=c,t[e+2]=h,t[e+3]=f}static multiplyQuaternionsFlat(t,e,n,s,r,a){let o=n[s],l=n[s+1],c=n[s+2],h=n[s+3],f=r[a],u=r[a+1],d=r[a+2],g=r[a+3];return t[e]=o*g+h*f+l*d-c*u,t[e+1]=l*g+h*u+c*f-o*d,t[e+2]=c*g+h*d+o*u-l*f,t[e+3]=h*g-o*f-l*u-c*d,t}get x(){return this._x}set x(t){this._x=t,this._onChangeCallback()}get y(){return this._y}set y(t){this._y=t,this._onChangeCallback()}get z(){return this._z}set z(t){this._z=t,this._onChangeCallback()}get w(){return this._w}set w(t){this._w=t,this._onChangeCallback()}set(t,e,n,s){return this._x=t,this._y=e,this._z=n,this._w=s,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._w)}copy(t){return this._x=t.x,this._y=t.y,this._z=t.z,this._w=t.w,this._onChangeCallback(),this}setFromEuler(t,e=!0){let n=t._x,s=t._y,r=t._z,a=t._order,o=Math.cos,l=Math.sin,c=o(n/2),h=o(s/2),f=o(r/2),u=l(n/2),d=l(s/2),g=l(r/2);switch(a){case"XYZ":this._x=u*h*f+c*d*g,this._y=c*d*f-u*h*g,this._z=c*h*g+u*d*f,this._w=c*h*f-u*d*g;break;case"YXZ":this._x=u*h*f+c*d*g,this._y=c*d*f-u*h*g,this._z=c*h*g-u*d*f,this._w=c*h*f+u*d*g;break;case"ZXY":this._x=u*h*f-c*d*g,this._y=c*d*f+u*h*g,this._z=c*h*g+u*d*f,this._w=c*h*f-u*d*g;break;case"ZYX":this._x=u*h*f-c*d*g,this._y=c*d*f+u*h*g,this._z=c*h*g-u*d*f,this._w=c*h*f+u*d*g;break;case"YZX":this._x=u*h*f+c*d*g,this._y=c*d*f+u*h*g,this._z=c*h*g-u*d*f,this._w=c*h*f-u*d*g;break;case"XZY":this._x=u*h*f-c*d*g,this._y=c*d*f-u*h*g,this._z=c*h*g+u*d*f,this._w=c*h*f+u*d*g;break;default:ue("Quaternion: .setFromEuler() encountered an unknown order: "+a)}return e===!0&&this._onChangeCallback(),this}setFromAxisAngle(t,e){let n=e/2,s=Math.sin(n);return this._x=t.x*s,this._y=t.y*s,this._z=t.z*s,this._w=Math.cos(n),this._onChangeCallback(),this}setFromRotationMatrix(t){let e=t.elements,n=e[0],s=e[4],r=e[8],a=e[1],o=e[5],l=e[9],c=e[2],h=e[6],f=e[10],u=n+o+f;if(u>0){let d=.5/Math.sqrt(u+1);this._w=.25/d,this._x=(h-l)*d,this._y=(r-c)*d,this._z=(a-s)*d}else if(n>o&&n>f){let d=2*Math.sqrt(1+n-o-f);this._w=(h-l)/d,this._x=.25*d,this._y=(s+a)/d,this._z=(r+c)/d}else if(o>f){let d=2*Math.sqrt(1+o-n-f);this._w=(r-c)/d,this._x=(s+a)/d,this._y=.25*d,this._z=(l+h)/d}else{let d=2*Math.sqrt(1+f-n-o);this._w=(a-s)/d,this._x=(r+c)/d,this._y=(l+h)/d,this._z=.25*d}return this._onChangeCallback(),this}setFromUnitVectors(t,e){let n=t.dot(e)+1;return n<1e-8?(n=0,Math.abs(t.x)>Math.abs(t.z)?(this._x=-t.y,this._y=t.x,this._z=0,this._w=n):(this._x=0,this._y=-t.z,this._z=t.y,this._w=n)):(this._x=t.y*e.z-t.z*e.y,this._y=t.z*e.x-t.x*e.z,this._z=t.x*e.y-t.y*e.x,this._w=n),this.normalize()}angleTo(t){return 2*Math.acos(Math.abs(we(this.dot(t),-1,1)))}rotateTowards(t,e){let n=this.angleTo(t);if(n===0)return this;let s=Math.min(1,e/n);return this.slerp(t,s),this}identity(){return this.set(0,0,0,1)}invert(){return this.conjugate()}conjugate(){return this._x*=-1,this._y*=-1,this._z*=-1,this._onChangeCallback(),this}dot(t){return this._x*t._x+this._y*t._y+this._z*t._z+this._w*t._w}lengthSq(){return this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w}length(){return Math.sqrt(this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w)}normalize(){let t=this.length();return t===0?(this._x=0,this._y=0,this._z=0,this._w=1):(t=1/t,this._x=this._x*t,this._y=this._y*t,this._z=this._z*t,this._w=this._w*t),this._onChangeCallback(),this}multiply(t){return this.multiplyQuaternions(this,t)}premultiply(t){return this.multiplyQuaternions(t,this)}multiplyQuaternions(t,e){let n=t._x,s=t._y,r=t._z,a=t._w,o=e._x,l=e._y,c=e._z,h=e._w;return this._x=n*h+a*o+s*c-r*l,this._y=s*h+a*l+r*o-n*c,this._z=r*h+a*c+n*l-s*o,this._w=a*h-n*o-s*l-r*c,this._onChangeCallback(),this}slerp(t,e){let n=t._x,s=t._y,r=t._z,a=t._w,o=this.dot(t);o<0&&(n=-n,s=-s,r=-r,a=-a,o=-o);let l=1-e;if(o<.9995){let c=Math.acos(o),h=Math.sin(c);l=Math.sin(l*c)/h,e=Math.sin(e*c)/h,this._x=this._x*l+n*e,this._y=this._y*l+s*e,this._z=this._z*l+r*e,this._w=this._w*l+a*e,this._onChangeCallback()}else this._x=this._x*l+n*e,this._y=this._y*l+s*e,this._z=this._z*l+r*e,this._w=this._w*l+a*e,this.normalize();return this}slerpQuaternions(t,e,n){return this.copy(t).slerp(e,n)}random(){let t=2*Math.PI*Math.random(),e=2*Math.PI*Math.random(),n=Math.random(),s=Math.sqrt(1-n),r=Math.sqrt(n);return this.set(s*Math.sin(t),s*Math.cos(t),r*Math.sin(e),r*Math.cos(e))}equals(t){return t._x===this._x&&t._y===this._y&&t._z===this._z&&t._w===this._w}fromArray(t,e=0){return this._x=t[e],this._y=t[e+1],this._z=t[e+2],this._w=t[e+3],this._onChangeCallback(),this}toArray(t=[],e=0){return t[e]=this._x,t[e+1]=this._y,t[e+2]=this._z,t[e+3]=this._w,t}fromBufferAttribute(t,e){return this._x=t.getX(e),this._y=t.getY(e),this._z=t.getZ(e),this._w=t.getW(e),this._onChangeCallback(),this}toJSON(){return this.toArray()}_onChange(t){return this._onChangeCallback=t,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._w}},P=class i{static{i.prototype.isVector3=!0}constructor(t=0,e=0,n=0){this.x=t,this.y=e,this.z=n}set(t,e,n){return n===void 0&&(n=this.z),this.x=t,this.y=e,this.z=n,this}setScalar(t){return this.x=t,this.y=t,this.z=t,this}setX(t){return this.x=t,this}setY(t){return this.y=t,this}setZ(t){return this.z=t,this}setComponent(t,e){switch(t){case 0:this.x=e;break;case 1:this.y=e;break;case 2:this.z=e;break;default:throw new Error("THREE.Vector3: index is out of range: "+t)}return this}getComponent(t){switch(t){case 0:return this.x;case 1:return this.y;case 2:return this.z;default:throw new Error("THREE.Vector3: index is out of range: "+t)}}clone(){return new this.constructor(this.x,this.y,this.z)}copy(t){return this.x=t.x,this.y=t.y,this.z=t.z,this}add(t){return this.x+=t.x,this.y+=t.y,this.z+=t.z,this}addScalar(t){return this.x+=t,this.y+=t,this.z+=t,this}addVectors(t,e){return this.x=t.x+e.x,this.y=t.y+e.y,this.z=t.z+e.z,this}addScaledVector(t,e){return this.x+=t.x*e,this.y+=t.y*e,this.z+=t.z*e,this}sub(t){return this.x-=t.x,this.y-=t.y,this.z-=t.z,this}subScalar(t){return this.x-=t,this.y-=t,this.z-=t,this}subVectors(t,e){return this.x=t.x-e.x,this.y=t.y-e.y,this.z=t.z-e.z,this}multiply(t){return this.x*=t.x,this.y*=t.y,this.z*=t.z,this}multiplyScalar(t){return this.x*=t,this.y*=t,this.z*=t,this}multiplyVectors(t,e){return this.x=t.x*e.x,this.y=t.y*e.y,this.z=t.z*e.z,this}applyEuler(t){return this.applyQuaternion(Fh.setFromEuler(t))}applyAxisAngle(t,e){return this.applyQuaternion(Fh.setFromAxisAngle(t,e))}applyMatrix3(t){let e=this.x,n=this.y,s=this.z,r=t.elements;return this.x=r[0]*e+r[3]*n+r[6]*s,this.y=r[1]*e+r[4]*n+r[7]*s,this.z=r[2]*e+r[5]*n+r[8]*s,this}applyNormalMatrix(t){return this.applyMatrix3(t).normalize()}applyMatrix4(t){let e=this.x,n=this.y,s=this.z,r=t.elements,a=1/(r[3]*e+r[7]*n+r[11]*s+r[15]);return this.x=(r[0]*e+r[4]*n+r[8]*s+r[12])*a,this.y=(r[1]*e+r[5]*n+r[9]*s+r[13])*a,this.z=(r[2]*e+r[6]*n+r[10]*s+r[14])*a,this}applyQuaternion(t){let e=this.x,n=this.y,s=this.z,r=t.x,a=t.y,o=t.z,l=t.w,c=2*(a*s-o*n),h=2*(o*e-r*s),f=2*(r*n-a*e);return this.x=e+l*c+a*f-o*h,this.y=n+l*h+o*c-r*f,this.z=s+l*f+r*h-a*c,this}project(t){return this.applyMatrix4(t.matrixWorldInverse).applyMatrix4(t.projectionMatrix)}unproject(t){return this.applyMatrix4(t.projectionMatrixInverse).applyMatrix4(t.matrixWorld)}transformDirection(t){let e=this.x,n=this.y,s=this.z,r=t.elements;return this.x=r[0]*e+r[4]*n+r[8]*s,this.y=r[1]*e+r[5]*n+r[9]*s,this.z=r[2]*e+r[6]*n+r[10]*s,this.normalize()}divide(t){return this.x/=t.x,this.y/=t.y,this.z/=t.z,this}divideScalar(t){return this.multiplyScalar(1/t)}min(t){return this.x=Math.min(this.x,t.x),this.y=Math.min(this.y,t.y),this.z=Math.min(this.z,t.z),this}max(t){return this.x=Math.max(this.x,t.x),this.y=Math.max(this.y,t.y),this.z=Math.max(this.z,t.z),this}clamp(t,e){return this.x=we(this.x,t.x,e.x),this.y=we(this.y,t.y,e.y),this.z=we(this.z,t.z,e.z),this}clampScalar(t,e){return this.x=we(this.x,t,e),this.y=we(this.y,t,e),this.z=we(this.z,t,e),this}clampLength(t,e){let n=this.length();return this.divideScalar(n||1).multiplyScalar(we(n,t,e))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this}dot(t){return this.x*t.x+this.y*t.y+this.z*t.z}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)}normalize(){return this.divideScalar(this.length()||1)}setLength(t){return this.normalize().multiplyScalar(t)}lerp(t,e){return this.x+=(t.x-this.x)*e,this.y+=(t.y-this.y)*e,this.z+=(t.z-this.z)*e,this}lerpVectors(t,e,n){return this.x=t.x+(e.x-t.x)*n,this.y=t.y+(e.y-t.y)*n,this.z=t.z+(e.z-t.z)*n,this}cross(t){return this.crossVectors(this,t)}crossVectors(t,e){let n=t.x,s=t.y,r=t.z,a=e.x,o=e.y,l=e.z;return this.x=s*l-r*o,this.y=r*a-n*l,this.z=n*o-s*a,this}projectOnVector(t){let e=t.lengthSq();if(e===0)return this.set(0,0,0);let n=t.dot(this)/e;return this.copy(t).multiplyScalar(n)}projectOnPlane(t){return $c.copy(this).projectOnVector(t),this.sub($c)}reflect(t){return this.sub($c.copy(t).multiplyScalar(2*this.dot(t)))}angleTo(t){let e=Math.sqrt(this.lengthSq()*t.lengthSq());if(e===0)return Math.PI/2;let n=this.dot(t)/e;return Math.acos(we(n,-1,1))}distanceTo(t){return Math.sqrt(this.distanceToSquared(t))}distanceToSquared(t){let e=this.x-t.x,n=this.y-t.y,s=this.z-t.z;return e*e+n*n+s*s}manhattanDistanceTo(t){return Math.abs(this.x-t.x)+Math.abs(this.y-t.y)+Math.abs(this.z-t.z)}setFromSpherical(t){return this.setFromSphericalCoords(t.radius,t.phi,t.theta)}setFromSphericalCoords(t,e,n){let s=Math.sin(e)*t;return this.x=s*Math.sin(n),this.y=Math.cos(e)*t,this.z=s*Math.cos(n),this}setFromCylindrical(t){return this.setFromCylindricalCoords(t.radius,t.theta,t.y)}setFromCylindricalCoords(t,e,n){return this.x=t*Math.sin(e),this.y=n,this.z=t*Math.cos(e),this}setFromMatrixPosition(t){let e=t.elements;return this.x=e[12],this.y=e[13],this.z=e[14],this}setFromMatrixScale(t){let e=this.setFromMatrixColumn(t,0).length(),n=this.setFromMatrixColumn(t,1).length(),s=this.setFromMatrixColumn(t,2).length();return this.x=e,this.y=n,this.z=s,this}setFromMatrixColumn(t,e){return this.fromArray(t.elements,e*4)}setFromMatrix3Column(t,e){return this.fromArray(t.elements,e*3)}setFromEuler(t){return this.x=t._x,this.y=t._y,this.z=t._z,this}setFromColor(t){return this.x=t.r,this.y=t.g,this.z=t.b,this}equals(t){return t.x===this.x&&t.y===this.y&&t.z===this.z}fromArray(t,e=0){return this.x=t[e],this.y=t[e+1],this.z=t[e+2],this}toArray(t=[],e=0){return t[e]=this.x,t[e+1]=this.y,t[e+2]=this.z,t}fromBufferAttribute(t,e){return this.x=t.getX(e),this.y=t.getY(e),this.z=t.getZ(e),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this}randomDirection(){let t=Math.random()*Math.PI*2,e=Math.random()*2-1,n=Math.sqrt(1-e*e);return this.x=n*Math.cos(t),this.y=e,this.z=n*Math.sin(t),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z}},$c=new P,Fh=new bi,xe=class i{static{i.prototype.isMatrix3=!0}constructor(t,e,n,s,r,a,o,l,c){this.elements=[1,0,0,0,1,0,0,0,1],t!==void 0&&this.set(t,e,n,s,r,a,o,l,c)}set(t,e,n,s,r,a,o,l,c){let h=this.elements;return h[0]=t,h[1]=s,h[2]=o,h[3]=e,h[4]=r,h[5]=l,h[6]=n,h[7]=a,h[8]=c,this}identity(){return this.set(1,0,0,0,1,0,0,0,1),this}copy(t){let e=this.elements,n=t.elements;return e[0]=n[0],e[1]=n[1],e[2]=n[2],e[3]=n[3],e[4]=n[4],e[5]=n[5],e[6]=n[6],e[7]=n[7],e[8]=n[8],this}extractBasis(t,e,n){return t.setFromMatrix3Column(this,0),e.setFromMatrix3Column(this,1),n.setFromMatrix3Column(this,2),this}setFromMatrix4(t){let e=t.elements;return this.set(e[0],e[4],e[8],e[1],e[5],e[9],e[2],e[6],e[10]),this}multiply(t){return this.multiplyMatrices(this,t)}premultiply(t){return this.multiplyMatrices(t,this)}multiplyMatrices(t,e){let n=t.elements,s=e.elements,r=this.elements,a=n[0],o=n[3],l=n[6],c=n[1],h=n[4],f=n[7],u=n[2],d=n[5],g=n[8],_=s[0],m=s[3],p=s[6],S=s[1],A=s[4],v=s[7],b=s[2],E=s[5],C=s[8];return r[0]=a*_+o*S+l*b,r[3]=a*m+o*A+l*E,r[6]=a*p+o*v+l*C,r[1]=c*_+h*S+f*b,r[4]=c*m+h*A+f*E,r[7]=c*p+h*v+f*C,r[2]=u*_+d*S+g*b,r[5]=u*m+d*A+g*E,r[8]=u*p+d*v+g*C,this}multiplyScalar(t){let e=this.elements;return e[0]*=t,e[3]*=t,e[6]*=t,e[1]*=t,e[4]*=t,e[7]*=t,e[2]*=t,e[5]*=t,e[8]*=t,this}determinant(){let t=this.elements,e=t[0],n=t[1],s=t[2],r=t[3],a=t[4],o=t[5],l=t[6],c=t[7],h=t[8];return e*a*h-e*o*c-n*r*h+n*o*l+s*r*c-s*a*l}invert(){let t=this.elements,e=t[0],n=t[1],s=t[2],r=t[3],a=t[4],o=t[5],l=t[6],c=t[7],h=t[8],f=h*a-o*c,u=o*l-h*r,d=c*r-a*l,g=e*f+n*u+s*d;if(g===0)return this.set(0,0,0,0,0,0,0,0,0);let _=1/g;return t[0]=f*_,t[1]=(s*c-h*n)*_,t[2]=(o*n-s*a)*_,t[3]=u*_,t[4]=(h*e-s*l)*_,t[5]=(s*r-o*e)*_,t[6]=d*_,t[7]=(n*l-c*e)*_,t[8]=(a*e-n*r)*_,this}transpose(){let t,e=this.elements;return t=e[1],e[1]=e[3],e[3]=t,t=e[2],e[2]=e[6],e[6]=t,t=e[5],e[5]=e[7],e[7]=t,this}getNormalMatrix(t){return this.setFromMatrix4(t).invert().transpose()}transposeIntoArray(t){let e=this.elements;return t[0]=e[0],t[1]=e[3],t[2]=e[6],t[3]=e[1],t[4]=e[4],t[5]=e[7],t[6]=e[2],t[7]=e[5],t[8]=e[8],this}setUvTransform(t,e,n,s,r,a,o){let l=Math.cos(r),c=Math.sin(r);return this.set(n*l,n*c,-n*(l*a+c*o)+a+t,-s*c,s*l,-s*(-c*a+l*o)+o+e,0,0,1),this}scale(t,e){return Es("Matrix3: .scale() is deprecated. Use .makeScale() instead."),this.premultiply(Zc.makeScale(t,e)),this}rotate(t){return Es("Matrix3: .rotate() is deprecated. Use .makeRotation() instead."),this.premultiply(Zc.makeRotation(-t)),this}translate(t,e){return Es("Matrix3: .translate() is deprecated. Use .makeTranslation() instead."),this.premultiply(Zc.makeTranslation(t,e)),this}makeTranslation(t,e){return t.isVector2?this.set(1,0,t.x,0,1,t.y,0,0,1):this.set(1,0,t,0,1,e,0,0,1),this}makeRotation(t){let e=Math.cos(t),n=Math.sin(t);return this.set(e,-n,0,n,e,0,0,0,1),this}makeScale(t,e){return this.set(t,0,0,0,e,0,0,0,1),this}equals(t){let e=this.elements,n=t.elements;for(let s=0;s<9;s++)if(e[s]!==n[s])return!1;return!0}fromArray(t,e=0){for(let n=0;n<9;n++)this.elements[n]=t[n+e];return this}toArray(t=[],e=0){let n=this.elements;return t[e]=n[0],t[e+1]=n[1],t[e+2]=n[2],t[e+3]=n[3],t[e+4]=n[4],t[e+5]=n[5],t[e+6]=n[6],t[e+7]=n[7],t[e+8]=n[8],t}clone(){return new this.constructor().fromArray(this.elements)}},Zc=new xe,Oh=new xe().set(.4123908,.3575843,.1804808,.212639,.7151687,.0721923,.0193308,.1191948,.9505322),Bh=new xe().set(3.2409699,-1.5373832,-.4986108,-.9692436,1.8759675,.0415551,.0556301,-.203977,1.0569715);function dd(){let i={enabled:!0,workingColorSpace:la,spaces:{},convert:function(s,r,a){return this.enabled===!1||r===a||!r||!a||(this.spaces[r].transfer===Fe&&(s.r=Hi(s.r),s.g=Hi(s.g),s.b=Hi(s.b)),this.spaces[r].primaries!==this.spaces[a].primaries&&(s.applyMatrix3(this.spaces[r].toXYZ),s.applyMatrix3(this.spaces[a].fromXYZ)),this.spaces[a].transfer===Fe&&(s.r=sr(s.r),s.g=sr(s.g),s.b=sr(s.b))),s},workingToColorSpace:function(s,r){return this.convert(s,this.workingColorSpace,r)},colorSpaceToWorking:function(s,r){return this.convert(s,r,this.workingColorSpace)},getPrimaries:function(s){return this.spaces[s].primaries},getTransfer:function(s){return s===di?ca:this.spaces[s].transfer},getToneMappingMode:function(s){return this.spaces[s].outputColorSpaceConfig.toneMappingMode||"standard"},getLuminanceCoefficients:function(s,r=this.workingColorSpace){return s.fromArray(this.spaces[r].luminanceCoefficients)},define:function(s){Object.assign(this.spaces,s)},_getMatrix:function(s,r,a){return s.copy(this.spaces[r].toXYZ).multiply(this.spaces[a].fromXYZ)},_getDrawingBufferColorSpace:function(s){return this.spaces[s].outputColorSpaceConfig.drawingBufferColorSpace},_getUnpackColorSpace:function(s=this.workingColorSpace){return this.spaces[s].workingColorSpaceConfig.unpackColorSpace},fromWorkingColorSpace:function(s,r){return Es("ColorManagement: .fromWorkingColorSpace() has been renamed to .workingToColorSpace()."),i.workingToColorSpace(s,r)},toWorkingColorSpace:function(s,r){return Es("ColorManagement: .toWorkingColorSpace() has been renamed to .colorSpaceToWorking()."),i.colorSpaceToWorking(s,r)}},t=[.64,.33,.3,.6,.15,.06],e=[.2126,.7152,.0722],n=[.3127,.329];return i.define({[la]:{primaries:t,whitePoint:n,transfer:ca,toXYZ:Oh,fromXYZ:Bh,luminanceCoefficients:e,workingColorSpaceConfig:{unpackColorSpace:Ke},outputColorSpaceConfig:{drawingBufferColorSpace:Ke}},[Ke]:{primaries:t,whitePoint:n,transfer:Fe,toXYZ:Oh,fromXYZ:Bh,luminanceCoefficients:e,outputColorSpaceConfig:{drawingBufferColorSpace:Ke}}}),i}var Ae=dd();function Hi(i){return i<.04045?i*.0773993808:Math.pow(i*.9478672986+.0521327014,2.4)}function sr(i){return i<.0031308?i*12.92:1.055*Math.pow(i,.41666)-.055}var zs,cl=class{static getDataURL(t,e="image/png"){if(/^data:/i.test(t.src)||typeof HTMLCanvasElement>"u")return t.src;let n;if(t instanceof HTMLCanvasElement)n=t;else{zs===void 0&&(zs=or("canvas")),zs.width=t.width,zs.height=t.height;let s=zs.getContext("2d");t instanceof ImageData?s.putImageData(t,0,0):s.drawImage(t,0,0,t.width,t.height),n=zs}return n.toDataURL(e)}static sRGBToLinear(t){if(typeof HTMLImageElement<"u"&&t instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&t instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&t instanceof ImageBitmap){let e=or("canvas");e.width=t.width,e.height=t.height;let n=e.getContext("2d");n.drawImage(t,0,0,t.width,t.height);let s=n.getImageData(0,0,t.width,t.height),r=s.data;for(let a=0;a<r.length;a++)r[a]=Hi(r[a]/255)*255;return n.putImageData(s,0,0),e}else if(t.data){let e=t.data.slice(0);for(let n=0;n<e.length;n++)e instanceof Uint8Array||e instanceof Uint8ClampedArray?e[n]=Math.floor(Hi(e[n]/255)*255):e[n]=Hi(e[n]);return{data:e,width:t.width,height:t.height}}else return ue("ImageUtils.sRGBToLinear(): Unsupported image type. No color space conversion applied."),t}},pd=0,cr=class{constructor(t=null){this.isTextureSource=!0,Object.defineProperty(this,"id",{value:pd++}),this.uuid=ki(),this.data=t,this.dataReady=!0,this.version=0}getSize(t){let e=this.data;return typeof HTMLVideoElement<"u"&&e instanceof HTMLVideoElement?t.set(e.videoWidth,e.videoHeight,0):typeof VideoFrame<"u"&&e instanceof VideoFrame?t.set(e.displayWidth,e.displayHeight,0):e!==null?t.set(e.width,e.height,e.depth||0):t.set(0,0,0),t}set needsUpdate(t){t===!0&&this.version++}toJSON(t){let e=t===void 0||typeof t=="string";if(!e&&t.images[this.uuid]!==void 0)return t.images[this.uuid];let n={uuid:this.uuid,url:""},s=this.data;if(s!==null){let r;if(Array.isArray(s)){r=[];for(let a=0,o=s.length;a<o;a++)s[a].isDataTexture?r.push(Jc(s[a].image)):r.push(Jc(s[a]))}else r=Jc(s);n.url=r}return e||(t.images[this.uuid]=n),n}};function Jc(i){return typeof HTMLImageElement<"u"&&i instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&i instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&i instanceof ImageBitmap?cl.getDataURL(i):i.data?{data:Array.from(i.data),width:i.width,height:i.height,type:i.data.constructor.name}:(ue("Texture: Unable to serialize Texture."),{})}var md=0,Kc=new P,xn=class i extends Si{constructor(t=i.DEFAULT_IMAGE,e=i.DEFAULT_MAPPING,n=vi,s=vi,r=Sn,a=Ti,o=ei,l=Fn,c=i.DEFAULT_ANISOTROPY,h=di){super(),this.isTexture=!0,Object.defineProperty(this,"id",{value:md++}),this.uuid=ki(),this.name="",this.source=new cr(t),this.mipmaps=[],this.mapping=e,this.channel=0,this.wrapS=n,this.wrapT=s,this.magFilter=r,this.minFilter=a,this.anisotropy=c,this.format=o,this.internalFormat=null,this.type=l,this.offset=new ft(0,0),this.repeat=new ft(1,1),this.center=new ft(0,0),this.rotation=0,this.matrixAutoUpdate=!0,this.matrix=new xe,this.generateMipmaps=!0,this.premultiplyAlpha=!1,this.flipY=!0,this.unpackAlignment=4,this.colorSpace=h,this.userData={},this.updateRanges=[],this.version=0,this.onUpdate=null,this.renderTarget=null,this.isRenderTargetTexture=!1,this.isArrayTexture=!!(t&&t.depth&&t.depth>1),this.pmremVersion=0,this.normalized=!1}get width(){return this.source.getSize(Kc).x}get height(){return this.source.getSize(Kc).y}get depth(){return this.source.getSize(Kc).z}get image(){return this.source.data}set image(t){this.source.data=t}updateMatrix(){this.matrix.setUvTransform(this.offset.x,this.offset.y,this.repeat.x,this.repeat.y,this.rotation,this.center.x,this.center.y)}addUpdateRange(t,e){this.updateRanges.push({start:t,count:e})}clearUpdateRanges(){this.updateRanges.length=0}clone(){return new this.constructor().copy(this)}copy(t){return this.name=t.name,this.source=t.source,this.mipmaps=t.mipmaps.slice(0),this.mapping=t.mapping,this.channel=t.channel,this.wrapS=t.wrapS,this.wrapT=t.wrapT,this.magFilter=t.magFilter,this.minFilter=t.minFilter,this.anisotropy=t.anisotropy,this.format=t.format,this.internalFormat=t.internalFormat,this.type=t.type,this.normalized=t.normalized,this.offset.copy(t.offset),this.repeat.copy(t.repeat),this.center.copy(t.center),this.rotation=t.rotation,this.matrixAutoUpdate=t.matrixAutoUpdate,this.matrix.copy(t.matrix),this.generateMipmaps=t.generateMipmaps,this.premultiplyAlpha=t.premultiplyAlpha,this.flipY=t.flipY,this.unpackAlignment=t.unpackAlignment,this.colorSpace=t.colorSpace,this.renderTarget=t.renderTarget,this.isRenderTargetTexture=t.isRenderTargetTexture,this.isArrayTexture=t.isArrayTexture,this.userData=JSON.parse(JSON.stringify(t.userData)),this.needsUpdate=!0,this}setValues(t){for(let e in t){let n=t[e];if(n===void 0){ue(`Texture.setValues(): parameter '${e}' has value of undefined.`);continue}let s=this[e];if(s===void 0){ue(`Texture.setValues(): property '${e}' does not exist.`);continue}s&&n&&s.isVector2&&n.isVector2||s&&n&&s.isVector3&&n.isVector3||s&&n&&s.isMatrix3&&n.isMatrix3?s.copy(n):this[e]=n}}toJSON(t){let e=t===void 0||typeof t=="string";if(!e&&t.textures[this.uuid]!==void 0)return t.textures[this.uuid];let n={metadata:{version:4.7,type:"Texture",generator:"Texture.toJSON"},uuid:this.uuid,name:this.name,image:this.source.toJSON(t).uuid,mapping:this.mapping,channel:this.channel,repeat:[this.repeat.x,this.repeat.y],offset:[this.offset.x,this.offset.y],center:[this.center.x,this.center.y],rotation:this.rotation,wrap:[this.wrapS,this.wrapT],format:this.format,internalFormat:this.internalFormat,type:this.type,normalized:this.normalized,colorSpace:this.colorSpace,minFilter:this.minFilter,magFilter:this.magFilter,anisotropy:this.anisotropy,flipY:this.flipY,generateMipmaps:this.generateMipmaps,premultiplyAlpha:this.premultiplyAlpha,unpackAlignment:this.unpackAlignment};return Object.keys(this.userData).length>0&&(n.userData=this.userData),e||(t.textures[this.uuid]=n),n}dispose(){this.dispatchEvent({type:"dispose"})}transformUv(t){if(this.mapping!==z0)return t;if(t.applyMatrix3(this.matrix),t.x<0||t.x>1)switch(this.wrapS){case ns:t.x=t.x-Math.floor(t.x);break;case vi:t.x=t.x<0?0:1;break;case al:Math.abs(Math.floor(t.x)%2)===1?t.x=Math.ceil(t.x)-t.x:t.x=t.x-Math.floor(t.x);break}if(t.y<0||t.y>1)switch(this.wrapT){case ns:t.y=t.y-Math.floor(t.y);break;case vi:t.y=t.y<0?0:1;break;case al:Math.abs(Math.floor(t.y)%2)===1?t.y=Math.ceil(t.y)-t.y:t.y=t.y-Math.floor(t.y);break}return this.flipY&&(t.y=1-t.y),t}set needsUpdate(t){t===!0&&(this.version++,this.source.needsUpdate=!0)}set needsPMREMUpdate(t){t===!0&&this.pmremVersion++}};xn.DEFAULT_IMAGE=null;xn.DEFAULT_MAPPING=z0;xn.DEFAULT_ANISOTROPY=1;var $e=class i{static{i.prototype.isVector4=!0}constructor(t=0,e=0,n=0,s=1){this.x=t,this.y=e,this.z=n,this.w=s}get width(){return this.z}set width(t){this.z=t}get height(){return this.w}set height(t){this.w=t}set(t,e,n,s){return this.x=t,this.y=e,this.z=n,this.w=s,this}setScalar(t){return this.x=t,this.y=t,this.z=t,this.w=t,this}setX(t){return this.x=t,this}setY(t){return this.y=t,this}setZ(t){return this.z=t,this}setW(t){return this.w=t,this}setComponent(t,e){switch(t){case 0:this.x=e;break;case 1:this.y=e;break;case 2:this.z=e;break;case 3:this.w=e;break;default:throw new Error("THREE.Vector4: index is out of range: "+t)}return this}getComponent(t){switch(t){case 0:return this.x;case 1:return this.y;case 2:return this.z;case 3:return this.w;default:throw new Error("THREE.Vector4: index is out of range: "+t)}}clone(){return new this.constructor(this.x,this.y,this.z,this.w)}copy(t){return this.x=t.x,this.y=t.y,this.z=t.z,this.w=t.w!==void 0?t.w:1,this}add(t){return this.x+=t.x,this.y+=t.y,this.z+=t.z,this.w+=t.w,this}addScalar(t){return this.x+=t,this.y+=t,this.z+=t,this.w+=t,this}addVectors(t,e){return this.x=t.x+e.x,this.y=t.y+e.y,this.z=t.z+e.z,this.w=t.w+e.w,this}addScaledVector(t,e){return this.x+=t.x*e,this.y+=t.y*e,this.z+=t.z*e,this.w+=t.w*e,this}sub(t){return this.x-=t.x,this.y-=t.y,this.z-=t.z,this.w-=t.w,this}subScalar(t){return this.x-=t,this.y-=t,this.z-=t,this.w-=t,this}subVectors(t,e){return this.x=t.x-e.x,this.y=t.y-e.y,this.z=t.z-e.z,this.w=t.w-e.w,this}multiply(t){return this.x*=t.x,this.y*=t.y,this.z*=t.z,this.w*=t.w,this}multiplyScalar(t){return this.x*=t,this.y*=t,this.z*=t,this.w*=t,this}applyMatrix4(t){let e=this.x,n=this.y,s=this.z,r=this.w,a=t.elements;return this.x=a[0]*e+a[4]*n+a[8]*s+a[12]*r,this.y=a[1]*e+a[5]*n+a[9]*s+a[13]*r,this.z=a[2]*e+a[6]*n+a[10]*s+a[14]*r,this.w=a[3]*e+a[7]*n+a[11]*s+a[15]*r,this}divide(t){return this.x/=t.x,this.y/=t.y,this.z/=t.z,this.w/=t.w,this}divideScalar(t){return this.multiplyScalar(1/t)}setAxisAngleFromQuaternion(t){this.w=2*Math.acos(t.w);let e=Math.sqrt(1-t.w*t.w);return e<1e-4?(this.x=1,this.y=0,this.z=0):(this.x=t.x/e,this.y=t.y/e,this.z=t.z/e),this}setAxisAngleFromRotationMatrix(t){let e,n,s,r,l=t.elements,c=l[0],h=l[4],f=l[8],u=l[1],d=l[5],g=l[9],_=l[2],m=l[6],p=l[10];if(Math.abs(h-u)<.01&&Math.abs(f-_)<.01&&Math.abs(g-m)<.01){if(Math.abs(h+u)<.1&&Math.abs(f+_)<.1&&Math.abs(g+m)<.1&&Math.abs(c+d+p-3)<.1)return this.set(1,0,0,0),this;e=Math.PI;let A=(c+1)/2,v=(d+1)/2,b=(p+1)/2,E=(h+u)/4,C=(f+_)/4,y=(g+m)/4;return A>v&&A>b?A<.01?(n=0,s=.707106781,r=.707106781):(n=Math.sqrt(A),s=E/n,r=C/n):v>b?v<.01?(n=.707106781,s=0,r=.707106781):(s=Math.sqrt(v),n=E/s,r=y/s):b<.01?(n=.707106781,s=.707106781,r=0):(r=Math.sqrt(b),n=C/r,s=y/r),this.set(n,s,r,e),this}let S=Math.sqrt((m-g)*(m-g)+(f-_)*(f-_)+(u-h)*(u-h));return Math.abs(S)<.001&&(S=1),this.x=(m-g)/S,this.y=(f-_)/S,this.z=(u-h)/S,this.w=Math.acos((c+d+p-1)/2),this}setFromMatrixPosition(t){let e=t.elements;return this.x=e[12],this.y=e[13],this.z=e[14],this.w=e[15],this}min(t){return this.x=Math.min(this.x,t.x),this.y=Math.min(this.y,t.y),this.z=Math.min(this.z,t.z),this.w=Math.min(this.w,t.w),this}max(t){return this.x=Math.max(this.x,t.x),this.y=Math.max(this.y,t.y),this.z=Math.max(this.z,t.z),this.w=Math.max(this.w,t.w),this}clamp(t,e){return this.x=we(this.x,t.x,e.x),this.y=we(this.y,t.y,e.y),this.z=we(this.z,t.z,e.z),this.w=we(this.w,t.w,e.w),this}clampScalar(t,e){return this.x=we(this.x,t,e),this.y=we(this.y,t,e),this.z=we(this.z,t,e),this.w=we(this.w,t,e),this}clampLength(t,e){let n=this.length();return this.divideScalar(n||1).multiplyScalar(we(n,t,e))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this.w=Math.floor(this.w),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this.w=Math.ceil(this.w),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this.w=Math.round(this.w),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this.w=Math.trunc(this.w),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this.w=-this.w,this}dot(t){return this.x*t.x+this.y*t.y+this.z*t.z+this.w*t.w}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)+Math.abs(this.w)}normalize(){return this.divideScalar(this.length()||1)}setLength(t){return this.normalize().multiplyScalar(t)}lerp(t,e){return this.x+=(t.x-this.x)*e,this.y+=(t.y-this.y)*e,this.z+=(t.z-this.z)*e,this.w+=(t.w-this.w)*e,this}lerpVectors(t,e,n){return this.x=t.x+(e.x-t.x)*n,this.y=t.y+(e.y-t.y)*n,this.z=t.z+(e.z-t.z)*n,this.w=t.w+(e.w-t.w)*n,this}equals(t){return t.x===this.x&&t.y===this.y&&t.z===this.z&&t.w===this.w}fromArray(t,e=0){return this.x=t[e],this.y=t[e+1],this.z=t[e+2],this.w=t[e+3],this}toArray(t=[],e=0){return t[e]=this.x,t[e+1]=this.y,t[e+2]=this.z,t[e+3]=this.w,t}fromBufferAttribute(t,e){return this.x=t.getX(e),this.y=t.getY(e),this.z=t.getZ(e),this.w=t.getW(e),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this.w=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z,yield this.w}},hl=class extends Si{constructor(t=1,e=1,n={}){super(),n=Object.assign({generateMipmaps:!1,internalFormat:null,minFilter:Sn,depthBuffer:!0,stencilBuffer:!1,resolveColorBuffer:!0,resolveDepthBuffer:!0,resolveStencilBuffer:!0,storeMultisampledColorBuffer:!0,storeMultisampledDepthBuffer:!0,storeMultisampledStencilBuffer:!0,depthTexture:null,samples:0,count:1,depth:1,multiview:!1,useArrayDepthTexture:!1},n),this.isRenderTarget=!0,this.width=t,this.height=e,this.depth=n.depth,this.scissor=new $e(0,0,t,e),this.scissorTest=!1,this.viewport=new $e(0,0,t,e),this.textures=[];let s={width:t,height:e,depth:n.depth},r=new xn(s),a=n.count;for(let o=0;o<a;o++)this.textures[o]=r.clone(),this.textures[o].isRenderTargetTexture=!0,this.textures[o].renderTarget=this;this._setTextureOptions(n),this.depthBuffer=n.depthBuffer,this.stencilBuffer=n.stencilBuffer,this.resolveColorBuffer=n.resolveColorBuffer,this.resolveDepthBuffer=n.resolveDepthBuffer,this.resolveStencilBuffer=n.resolveStencilBuffer,this.storeMultisampledColorBuffer=n.storeMultisampledColorBuffer,this.storeMultisampledDepthBuffer=n.storeMultisampledDepthBuffer,this.storeMultisampledStencilBuffer=n.storeMultisampledStencilBuffer,this._depthTexture=null,this.depthTexture=n.depthTexture,this.samples=n.samples,this.multiview=n.multiview,this.useArrayDepthTexture=n.useArrayDepthTexture}_setTextureOptions(t={}){let e={minFilter:Sn,generateMipmaps:!1,flipY:!1,internalFormat:null};t.mapping!==void 0&&(e.mapping=t.mapping),t.wrapS!==void 0&&(e.wrapS=t.wrapS),t.wrapT!==void 0&&(e.wrapT=t.wrapT),t.wrapR!==void 0&&(e.wrapR=t.wrapR),t.magFilter!==void 0&&(e.magFilter=t.magFilter),t.minFilter!==void 0&&(e.minFilter=t.minFilter),t.format!==void 0&&(e.format=t.format),t.type!==void 0&&(e.type=t.type),t.anisotropy!==void 0&&(e.anisotropy=t.anisotropy),t.colorSpace!==void 0&&(e.colorSpace=t.colorSpace),t.flipY!==void 0&&(e.flipY=t.flipY),t.generateMipmaps!==void 0&&(e.generateMipmaps=t.generateMipmaps),t.internalFormat!==void 0&&(e.internalFormat=t.internalFormat);for(let n=0;n<this.textures.length;n++)this.textures[n].setValues(e)}get texture(){return this.textures[0]}set texture(t){this.textures[0]=t}set depthTexture(t){this._depthTexture!==null&&this._depthTexture.renderTarget===this&&(this._depthTexture.renderTarget=null),t!==null&&t.renderTarget===null&&(t.renderTarget=this),this._depthTexture=t}get depthTexture(){return this._depthTexture}setSize(t,e,n=1){if(this.width!==t||this.height!==e||this.depth!==n){this.width=t,this.height=e,this.depth=n;for(let s=0,r=this.textures.length;s<r;s++)this.textures[s].image.width=t,this.textures[s].image.height=e,this.textures[s].image.depth=n,this.textures[s].isData3DTexture!==!0&&(this.textures[s].isArrayTexture=this.textures[s].image.depth>1);this.dispose()}this.viewport.set(0,0,t,e),this.scissor.set(0,0,t,e)}clone(){return new this.constructor().copy(this)}copy(t){this.width=t.width,this.height=t.height,this.depth=t.depth,this.scissor.copy(t.scissor),this.scissorTest=t.scissorTest,this.viewport.copy(t.viewport),this.textures.length=0;for(let e=0,n=t.textures.length;e<n;e++){this.textures[e]=t.textures[e].clone(),this.textures[e].isRenderTargetTexture=!0,this.textures[e].renderTarget=this;let s=Object.assign({},t.textures[e].image);this.textures[e].source=new cr(s)}if(this.depthBuffer=t.depthBuffer,this.stencilBuffer=t.stencilBuffer,this.resolveColorBuffer=t.resolveColorBuffer,this.resolveDepthBuffer=t.resolveDepthBuffer,this.resolveStencilBuffer=t.resolveStencilBuffer,this.storeMultisampledColorBuffer=t.storeMultisampledColorBuffer,this.storeMultisampledDepthBuffer=t.storeMultisampledDepthBuffer,this.storeMultisampledStencilBuffer=t.storeMultisampledStencilBuffer,t.depthTexture!==null)if(t.depthTexture.renderTarget===t){let e=t.depthTexture.clone();e.renderTarget=null,this.depthTexture=e}else this.depthTexture=t.depthTexture;return this.samples=t.samples,this.multiview=t.multiview,this.useArrayDepthTexture=t.useArrayDepthTexture,this}dispose(){this.dispatchEvent({type:"dispose"})}},tn=class extends hl{constructor(t=1,e=1,n={}){super(t,e,n),this.isWebGLRenderTarget=!0}},ua=class extends xn{constructor(t=null,e=1,n=1,s=1){super(null),this.isDataArrayTexture=!0,this.image={data:t,width:e,height:n,depth:s},this.magFilter=gn,this.minFilter=gn,this.wrapR=vi,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1,this.layerUpdates=new Set}copy(t){return super.copy(t),this.wrapR=t.wrapR,this}addLayerUpdate(t){this.layerUpdates.add(t)}clearLayerUpdates(){this.layerUpdates.clear()}};var ul=class extends xn{constructor(t=null,e=1,n=1,s=1){super(null),this.isData3DTexture=!0,this.image={data:t,width:e,height:n,depth:s},this.magFilter=gn,this.minFilter=gn,this.wrapR=vi,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}copy(t){return super.copy(t),this.wrapR=t.wrapR,this}};var De=class i{static{i.prototype.isMatrix4=!0}constructor(t,e,n,s,r,a,o,l,c,h,f,u,d,g,_,m){this.elements=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1],t!==void 0&&this.set(t,e,n,s,r,a,o,l,c,h,f,u,d,g,_,m)}set(t,e,n,s,r,a,o,l,c,h,f,u,d,g,_,m){let p=this.elements;return p[0]=t,p[4]=e,p[8]=n,p[12]=s,p[1]=r,p[5]=a,p[9]=o,p[13]=l,p[2]=c,p[6]=h,p[10]=f,p[14]=u,p[3]=d,p[7]=g,p[11]=_,p[15]=m,this}identity(){return this.set(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1),this}clone(){return new i().fromArray(this.elements)}copy(t){let e=this.elements,n=t.elements;return e[0]=n[0],e[1]=n[1],e[2]=n[2],e[3]=n[3],e[4]=n[4],e[5]=n[5],e[6]=n[6],e[7]=n[7],e[8]=n[8],e[9]=n[9],e[10]=n[10],e[11]=n[11],e[12]=n[12],e[13]=n[13],e[14]=n[14],e[15]=n[15],this}copyPosition(t){let e=this.elements,n=t.elements;return e[12]=n[12],e[13]=n[13],e[14]=n[14],this}setFromMatrix3(t){let e=t.elements;return this.set(e[0],e[3],e[6],0,e[1],e[4],e[7],0,e[2],e[5],e[8],0,0,0,0,1),this}extractBasis(t,e,n){return this.determinantAffine()===0?(t.set(1,0,0),e.set(0,1,0),n.set(0,0,1),this):(t.setFromMatrixColumn(this,0),e.setFromMatrixColumn(this,1),n.setFromMatrixColumn(this,2),this)}makeBasis(t,e,n){return this.set(t.x,e.x,n.x,0,t.y,e.y,n.y,0,t.z,e.z,n.z,0,0,0,0,1),this}extractRotation(t){if(t.determinantAffine()===0)return this.identity();let e=this.elements,n=t.elements,s=1/ks.setFromMatrixColumn(t,0).length(),r=1/ks.setFromMatrixColumn(t,1).length(),a=1/ks.setFromMatrixColumn(t,2).length();return e[0]=n[0]*s,e[1]=n[1]*s,e[2]=n[2]*s,e[3]=0,e[4]=n[4]*r,e[5]=n[5]*r,e[6]=n[6]*r,e[7]=0,e[8]=n[8]*a,e[9]=n[9]*a,e[10]=n[10]*a,e[11]=0,e[12]=0,e[13]=0,e[14]=0,e[15]=1,this}makeRotationFromEuler(t){let e=this.elements,n=t.x,s=t.y,r=t.z,a=Math.cos(n),o=Math.sin(n),l=Math.cos(s),c=Math.sin(s),h=Math.cos(r),f=Math.sin(r);if(t.order==="XYZ"){let u=a*h,d=a*f,g=o*h,_=o*f;e[0]=l*h,e[4]=-l*f,e[8]=c,e[1]=d+g*c,e[5]=u-_*c,e[9]=-o*l,e[2]=_-u*c,e[6]=g+d*c,e[10]=a*l}else if(t.order==="YXZ"){let u=l*h,d=l*f,g=c*h,_=c*f;e[0]=u+_*o,e[4]=g*o-d,e[8]=a*c,e[1]=a*f,e[5]=a*h,e[9]=-o,e[2]=d*o-g,e[6]=_+u*o,e[10]=a*l}else if(t.order==="ZXY"){let u=l*h,d=l*f,g=c*h,_=c*f;e[0]=u-_*o,e[4]=-a*f,e[8]=g+d*o,e[1]=d+g*o,e[5]=a*h,e[9]=_-u*o,e[2]=-a*c,e[6]=o,e[10]=a*l}else if(t.order==="ZYX"){let u=a*h,d=a*f,g=o*h,_=o*f;e[0]=l*h,e[4]=g*c-d,e[8]=u*c+_,e[1]=l*f,e[5]=_*c+u,e[9]=d*c-g,e[2]=-c,e[6]=o*l,e[10]=a*l}else if(t.order==="YZX"){let u=a*l,d=a*c,g=o*l,_=o*c;e[0]=l*h,e[4]=_-u*f,e[8]=g*f+d,e[1]=f,e[5]=a*h,e[9]=-o*h,e[2]=-c*h,e[6]=d*f+g,e[10]=u-_*f}else if(t.order==="XZY"){let u=a*l,d=a*c,g=o*l,_=o*c;e[0]=l*h,e[4]=-f,e[8]=c*h,e[1]=u*f+_,e[5]=a*h,e[9]=d*f-g,e[2]=g*f-d,e[6]=o*h,e[10]=_*f+u}return e[3]=0,e[7]=0,e[11]=0,e[12]=0,e[13]=0,e[14]=0,e[15]=1,this}makeRotationFromQuaternion(t){return this.compose(gd,t,xd)}lookAt(t,e,n){let s=this.elements;return zn.subVectors(t,e),zn.lengthSq()===0&&(zn.z=1),zn.normalize(),Ki.crossVectors(n,zn),Ki.lengthSq()===0&&(Math.abs(n.z)===1?zn.x+=1e-4:zn.z+=1e-4,zn.normalize(),Ki.crossVectors(n,zn)),Ki.normalize(),yo.crossVectors(zn,Ki),s[0]=Ki.x,s[4]=yo.x,s[8]=zn.x,s[1]=Ki.y,s[5]=yo.y,s[9]=zn.y,s[2]=Ki.z,s[6]=yo.z,s[10]=zn.z,this}multiply(t){return this.multiplyMatrices(this,t)}premultiply(t){return this.multiplyMatrices(t,this)}multiplyMatrices(t,e){let n=t.elements,s=e.elements,r=this.elements,a=n[0],o=n[4],l=n[8],c=n[12],h=n[1],f=n[5],u=n[9],d=n[13],g=n[2],_=n[6],m=n[10],p=n[14],S=n[3],A=n[7],v=n[11],b=n[15],E=s[0],C=s[4],y=s[8],w=s[12],I=s[1],N=s[5],H=s[9],W=s[13],U=s[2],G=s[6],rt=s[10],j=s[14],pt=s[3],st=s[7],lt=s[11],O=s[15];return r[0]=a*E+o*I+l*U+c*pt,r[4]=a*C+o*N+l*G+c*st,r[8]=a*y+o*H+l*rt+c*lt,r[12]=a*w+o*W+l*j+c*O,r[1]=h*E+f*I+u*U+d*pt,r[5]=h*C+f*N+u*G+d*st,r[9]=h*y+f*H+u*rt+d*lt,r[13]=h*w+f*W+u*j+d*O,r[2]=g*E+_*I+m*U+p*pt,r[6]=g*C+_*N+m*G+p*st,r[10]=g*y+_*H+m*rt+p*lt,r[14]=g*w+_*W+m*j+p*O,r[3]=S*E+A*I+v*U+b*pt,r[7]=S*C+A*N+v*G+b*st,r[11]=S*y+A*H+v*rt+b*lt,r[15]=S*w+A*W+v*j+b*O,this}multiplyScalar(t){let e=this.elements;return e[0]*=t,e[4]*=t,e[8]*=t,e[12]*=t,e[1]*=t,e[5]*=t,e[9]*=t,e[13]*=t,e[2]*=t,e[6]*=t,e[10]*=t,e[14]*=t,e[3]*=t,e[7]*=t,e[11]*=t,e[15]*=t,this}determinant(){let t=this.elements,e=t[0],n=t[4],s=t[8],r=t[12],a=t[1],o=t[5],l=t[9],c=t[13],h=t[2],f=t[6],u=t[10],d=t[14],g=t[3],_=t[7],m=t[11],p=t[15],S=l*d-c*u,A=o*d-c*f,v=o*u-l*f,b=a*d-c*h,E=a*u-l*h,C=a*f-o*h;return e*(_*S-m*A+p*v)-n*(g*S-m*b+p*E)+s*(g*A-_*b+p*C)-r*(g*v-_*E+m*C)}determinantAffine(){let t=this.elements,e=t[0],n=t[4],s=t[8],r=t[1],a=t[5],o=t[9],l=t[2],c=t[6],h=t[10];return e*(a*h-o*c)-n*(r*h-o*l)+s*(r*c-a*l)}transpose(){let t=this.elements,e;return e=t[1],t[1]=t[4],t[4]=e,e=t[2],t[2]=t[8],t[8]=e,e=t[6],t[6]=t[9],t[9]=e,e=t[3],t[3]=t[12],t[12]=e,e=t[7],t[7]=t[13],t[13]=e,e=t[11],t[11]=t[14],t[14]=e,this}setPosition(t,e,n){let s=this.elements;return t.isVector3?(s[12]=t.x,s[13]=t.y,s[14]=t.z):(s[12]=t,s[13]=e,s[14]=n),this}invert(){let t=this.elements,e=t[0],n=t[1],s=t[2],r=t[3],a=t[4],o=t[5],l=t[6],c=t[7],h=t[8],f=t[9],u=t[10],d=t[11],g=t[12],_=t[13],m=t[14],p=t[15],S=e*o-n*a,A=e*l-s*a,v=e*c-r*a,b=n*l-s*o,E=n*c-r*o,C=s*c-r*l,y=h*_-f*g,w=h*m-u*g,I=h*p-d*g,N=f*m-u*_,H=f*p-d*_,W=u*p-d*m,U=S*W-A*H+v*N+b*I-E*w+C*y;if(U===0)return this.set(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);let G=1/U;return t[0]=(o*W-l*H+c*N)*G,t[1]=(s*H-n*W-r*N)*G,t[2]=(_*C-m*E+p*b)*G,t[3]=(u*E-f*C-d*b)*G,t[4]=(l*I-a*W-c*w)*G,t[5]=(e*W-s*I+r*w)*G,t[6]=(m*v-g*C-p*A)*G,t[7]=(h*C-u*v+d*A)*G,t[8]=(a*H-o*I+c*y)*G,t[9]=(n*I-e*H-r*y)*G,t[10]=(g*E-_*v+p*S)*G,t[11]=(f*v-h*E-d*S)*G,t[12]=(o*w-a*N-l*y)*G,t[13]=(e*N-n*w+s*y)*G,t[14]=(_*A-g*b-m*S)*G,t[15]=(h*b-f*A+u*S)*G,this}scale(t){let e=this.elements,n=t.x,s=t.y,r=t.z;return e[0]*=n,e[4]*=s,e[8]*=r,e[1]*=n,e[5]*=s,e[9]*=r,e[2]*=n,e[6]*=s,e[10]*=r,e[3]*=n,e[7]*=s,e[11]*=r,this}getMaxScaleOnAxis(){let t=this.elements,e=t[0]*t[0]+t[1]*t[1]+t[2]*t[2],n=t[4]*t[4]+t[5]*t[5]+t[6]*t[6],s=t[8]*t[8]+t[9]*t[9]+t[10]*t[10];return Math.sqrt(Math.max(e,n,s))}makeTranslation(t,e,n){return t.isVector3?this.set(1,0,0,t.x,0,1,0,t.y,0,0,1,t.z,0,0,0,1):this.set(1,0,0,t,0,1,0,e,0,0,1,n,0,0,0,1),this}makeRotationX(t){let e=Math.cos(t),n=Math.sin(t);return this.set(1,0,0,0,0,e,-n,0,0,n,e,0,0,0,0,1),this}makeRotationY(t){let e=Math.cos(t),n=Math.sin(t);return this.set(e,0,n,0,0,1,0,0,-n,0,e,0,0,0,0,1),this}makeRotationZ(t){let e=Math.cos(t),n=Math.sin(t);return this.set(e,-n,0,0,n,e,0,0,0,0,1,0,0,0,0,1),this}makeRotationAxis(t,e){let n=Math.cos(e),s=Math.sin(e),r=1-n,a=t.x,o=t.y,l=t.z,c=r*a,h=r*o;return this.set(c*a+n,c*o-s*l,c*l+s*o,0,c*o+s*l,h*o+n,h*l-s*a,0,c*l-s*o,h*l+s*a,r*l*l+n,0,0,0,0,1),this}makeScale(t,e,n){return this.set(t,0,0,0,0,e,0,0,0,0,n,0,0,0,0,1),this}makeShear(t,e,n,s,r,a){return this.set(1,n,r,0,t,1,a,0,e,s,1,0,0,0,0,1),this}compose(t,e,n){let s=this.elements,r=e._x,a=e._y,o=e._z,l=e._w,c=r+r,h=a+a,f=o+o,u=r*c,d=r*h,g=r*f,_=a*h,m=a*f,p=o*f,S=l*c,A=l*h,v=l*f,b=n.x,E=n.y,C=n.z;return s[0]=(1-(_+p))*b,s[1]=(d+v)*b,s[2]=(g-A)*b,s[3]=0,s[4]=(d-v)*E,s[5]=(1-(u+p))*E,s[6]=(m+S)*E,s[7]=0,s[8]=(g+A)*C,s[9]=(m-S)*C,s[10]=(1-(u+_))*C,s[11]=0,s[12]=t.x,s[13]=t.y,s[14]=t.z,s[15]=1,this}decompose(t,e,n){let s=this.elements;t.x=s[12],t.y=s[13],t.z=s[14];let r=this.determinantAffine();if(r===0)return n.set(1,1,1),e.identity(),this;let a=ks.set(s[0],s[1],s[2]).length(),o=ks.set(s[4],s[5],s[6]).length(),l=ks.set(s[8],s[9],s[10]).length();r<0&&(a=-a),si.copy(this);let c=1/a,h=1/o,f=1/l;return si.elements[0]*=c,si.elements[1]*=c,si.elements[2]*=c,si.elements[4]*=h,si.elements[5]*=h,si.elements[6]*=h,si.elements[8]*=f,si.elements[9]*=f,si.elements[10]*=f,e.setFromRotationMatrix(si),n.x=a,n.y=o,n.z=l,this}makePerspective(t,e,n,s,r,a,o=li,l=!1){let c=this.elements,h=2*r/(e-t),f=2*r/(n-s),u=(e+t)/(e-t),d=(n+s)/(n-s),g,_;if(l)g=r/(a-r),_=a*r/(a-r);else if(o===li)g=-(a+r)/(a-r),_=-2*a*r/(a-r);else if(o===ar)g=-a/(a-r),_=-a*r/(a-r);else throw new Error("THREE.Matrix4.makePerspective(): Invalid coordinate system: "+o);return c[0]=h,c[4]=0,c[8]=u,c[12]=0,c[1]=0,c[5]=f,c[9]=d,c[13]=0,c[2]=0,c[6]=0,c[10]=g,c[14]=_,c[3]=0,c[7]=0,c[11]=-1,c[15]=0,this}makeOrthographic(t,e,n,s,r,a,o=li,l=!1){let c=this.elements,h=2/(e-t),f=2/(n-s),u=-(e+t)/(e-t),d=-(n+s)/(n-s),g,_;if(l)g=1/(a-r),_=a/(a-r);else if(o===li)g=-2/(a-r),_=-(a+r)/(a-r);else if(o===ar)g=-1/(a-r),_=-r/(a-r);else throw new Error("THREE.Matrix4.makeOrthographic(): Invalid coordinate system: "+o);return c[0]=h,c[4]=0,c[8]=0,c[12]=u,c[1]=0,c[5]=f,c[9]=0,c[13]=d,c[2]=0,c[6]=0,c[10]=g,c[14]=_,c[3]=0,c[7]=0,c[11]=0,c[15]=1,this}equals(t){let e=this.elements,n=t.elements;for(let s=0;s<16;s++)if(e[s]!==n[s])return!1;return!0}fromArray(t,e=0){for(let n=0;n<16;n++)this.elements[n]=t[n+e];return this}toArray(t=[],e=0){let n=this.elements;return t[e]=n[0],t[e+1]=n[1],t[e+2]=n[2],t[e+3]=n[3],t[e+4]=n[4],t[e+5]=n[5],t[e+6]=n[6],t[e+7]=n[7],t[e+8]=n[8],t[e+9]=n[9],t[e+10]=n[10],t[e+11]=n[11],t[e+12]=n[12],t[e+13]=n[13],t[e+14]=n[14],t[e+15]=n[15],t}},ks=new P,si=new De,gd=new P(0,0,0),xd=new P(1,1,1),Ki=new P,yo=new P,zn=new P,zh=new De,kh=new bi,Vi=class i{constructor(t=0,e=0,n=0,s=i.DEFAULT_ORDER){this.isEuler=!0,this._x=t,this._y=e,this._z=n,this._order=s}get x(){return this._x}set x(t){this._x=t,this._onChangeCallback()}get y(){return this._y}set y(t){this._y=t,this._onChangeCallback()}get z(){return this._z}set z(t){this._z=t,this._onChangeCallback()}get order(){return this._order}set order(t){this._order=t,this._onChangeCallback()}set(t,e,n,s=this._order){return this._x=t,this._y=e,this._z=n,this._order=s,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._order)}copy(t){return this._x=t._x,this._y=t._y,this._z=t._z,this._order=t._order,this._onChangeCallback(),this}setFromRotationMatrix(t,e=this._order,n=!0){let s=t.elements,r=s[0],a=s[4],o=s[8],l=s[1],c=s[5],h=s[9],f=s[2],u=s[6],d=s[10];switch(e){case"XYZ":this._y=Math.asin(we(o,-1,1)),Math.abs(o)<.9999999?(this._x=Math.atan2(-h,d),this._z=Math.atan2(-a,r)):(this._x=Math.atan2(u,c),this._z=0);break;case"YXZ":this._x=Math.asin(-we(h,-1,1)),Math.abs(h)<.9999999?(this._y=Math.atan2(o,d),this._z=Math.atan2(l,c)):(this._y=Math.atan2(-f,r),this._z=0);break;case"ZXY":this._x=Math.asin(we(u,-1,1)),Math.abs(u)<.9999999?(this._y=Math.atan2(-f,d),this._z=Math.atan2(-a,c)):(this._y=0,this._z=Math.atan2(l,r));break;case"ZYX":this._y=Math.asin(-we(f,-1,1)),Math.abs(f)<.9999999?(this._x=Math.atan2(u,d),this._z=Math.atan2(l,r)):(this._x=0,this._z=Math.atan2(-a,c));break;case"YZX":this._z=Math.asin(we(l,-1,1)),Math.abs(l)<.9999999?(this._x=Math.atan2(-h,c),this._y=Math.atan2(-f,r)):(this._x=0,this._y=Math.atan2(o,d));break;case"XZY":this._z=Math.asin(-we(a,-1,1)),Math.abs(a)<.9999999?(this._x=Math.atan2(u,c),this._y=Math.atan2(o,r)):(this._x=Math.atan2(-h,d),this._y=0);break;default:ue("Euler: .setFromRotationMatrix() encountered an unknown order: "+e)}return this._order=e,n===!0&&this._onChangeCallback(),this}setFromQuaternion(t,e,n){return zh.makeRotationFromQuaternion(t),this.setFromRotationMatrix(zh,e,n)}setFromVector3(t,e=this._order){return this.set(t.x,t.y,t.z,e)}reorder(t){return kh.setFromEuler(this),this.setFromQuaternion(kh,t)}equals(t){return t._x===this._x&&t._y===this._y&&t._z===this._z&&t._order===this._order}fromArray(t){return this._x=t[0],this._y=t[1],this._z=t[2],t[3]!==void 0&&(this._order=t[3]),this._onChangeCallback(),this}toArray(t=[],e=0){return t[e]=this._x,t[e+1]=this._y,t[e+2]=this._z,t[e+3]=this._order,t}_onChange(t){return this._onChangeCallback=t,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._order}};Vi.DEFAULT_ORDER="XYZ";var hr=class{constructor(){this.mask=1}set(t){this.mask=(1<<t|0)>>>0}enable(t){this.mask|=1<<t|0}enableAll(){this.mask=-1}toggle(t){this.mask^=1<<t|0}disable(t){this.mask&=~(1<<t|0)}disableAll(){this.mask=0}test(t){return(this.mask&t.mask)!==0}isEnabled(t){return(this.mask&(1<<t|0))!==0}},_d=0,Hh=new P,Hs=new bi,Ni=new De,Mo=new P,$r=new P,vd=new P,yd=new bi,Vh=new P(1,0,0),Gh=new P(0,1,0),Wh=new P(0,0,1),Xh={type:"added"},Md={type:"removed"},Vs={type:"childadded",child:null},jc={type:"childremoved",child:null},rn=class i extends Si{constructor(){super(),this.isObject3D=!0,Object.defineProperty(this,"id",{value:_d++}),this.uuid=ki(),this.name="",this.type="Object3D",this.parent=null,this.children=[],this.up=i.DEFAULT_UP.clone();let t=new P,e=new Vi,n=new bi,s=new P(1,1,1);function r(){n.setFromEuler(e,!1)}function a(){e.setFromQuaternion(n,void 0,!1)}e._onChange(r),n._onChange(a),Object.defineProperties(this,{position:{configurable:!0,enumerable:!0,value:t},rotation:{configurable:!0,enumerable:!0,value:e},quaternion:{configurable:!0,enumerable:!0,value:n},scale:{configurable:!0,enumerable:!0,value:s},modelViewMatrix:{value:new De},normalMatrix:{value:new xe}}),this.matrix=new De,this.matrixWorld=new De,this.matrixAutoUpdate=i.DEFAULT_MATRIX_AUTO_UPDATE,this.matrixWorldAutoUpdate=i.DEFAULT_MATRIX_WORLD_AUTO_UPDATE,this.matrixWorldNeedsUpdate=!1,this.layers=new hr,this.visible=!0,this.castShadow=!1,this.receiveShadow=!1,this.frustumCulled=!0,this.renderOrder=0,this.animations=[],this.customDepthMaterial=void 0,this.customDistanceMaterial=void 0,this.static=!1,this.userData={},this.pivot=null}onBeforeShadow(){}onAfterShadow(){}onBeforeRender(){}onAfterRender(){}applyMatrix4(t){this.matrixAutoUpdate&&this.updateMatrix(),this.matrix.premultiply(t),this.matrix.decompose(this.position,this.quaternion,this.scale)}applyQuaternion(t){return this.quaternion.premultiply(t),this}setRotationFromAxisAngle(t,e){this.quaternion.setFromAxisAngle(t,e)}setRotationFromEuler(t){this.quaternion.setFromEuler(t,!0)}setRotationFromMatrix(t){this.quaternion.setFromRotationMatrix(t)}setRotationFromQuaternion(t){this.quaternion.copy(t)}rotateOnAxis(t,e){return Hs.setFromAxisAngle(t,e),this.quaternion.multiply(Hs),this}rotateOnWorldAxis(t,e){return Hs.setFromAxisAngle(t,e),this.quaternion.premultiply(Hs),this}rotateX(t){return this.rotateOnAxis(Vh,t)}rotateY(t){return this.rotateOnAxis(Gh,t)}rotateZ(t){return this.rotateOnAxis(Wh,t)}translateOnAxis(t,e){return Hh.copy(t).applyQuaternion(this.quaternion),this.position.add(Hh.multiplyScalar(e)),this}translateX(t){return this.translateOnAxis(Vh,t)}translateY(t){return this.translateOnAxis(Gh,t)}translateZ(t){return this.translateOnAxis(Wh,t)}localToWorld(t){return this.updateWorldMatrix(!0,!1),t.applyMatrix4(this.matrixWorld)}worldToLocal(t){return this.updateWorldMatrix(!0,!1),t.applyMatrix4(Ni.copy(this.matrixWorld).invert())}lookAt(t,e,n){t.isVector3?Mo.copy(t):Mo.set(t,e,n);let s=this.parent;this.updateWorldMatrix(!0,!1),$r.setFromMatrixPosition(this.matrixWorld),this.isCamera||this.isLight?Ni.lookAt($r,Mo,this.up):Ni.lookAt(Mo,$r,this.up),this.quaternion.setFromRotationMatrix(Ni),s&&(Ni.extractRotation(s.matrixWorld),Hs.setFromRotationMatrix(Ni),this.quaternion.premultiply(Hs.invert()))}add(t){if(arguments.length>1){for(let e=0;e<arguments.length;e++)this.add(arguments[e]);return this}return t===this?(he("Object3D.add: object can't be added as a child of itself.",t),this):(t&&t.isObject3D?(t.removeFromParent(),t.parent=this,this.children.push(t),t.dispatchEvent(Xh),Vs.child=t,this.dispatchEvent(Vs),Vs.child=null):he("Object3D.add: object not an instance of THREE.Object3D.",t),this)}remove(t){if(arguments.length>1){for(let n=0;n<arguments.length;n++)this.remove(arguments[n]);return this}let e=this.children.indexOf(t);return e!==-1&&(t.parent=null,this.children.splice(e,1),t.dispatchEvent(Md),jc.child=t,this.dispatchEvent(jc),jc.child=null),this}removeFromParent(){let t=this.parent;return t!==null&&t.remove(this),this}clear(){return this.remove(...this.children)}attach(t){return this.updateWorldMatrix(!0,!1),Ni.copy(this.matrixWorld).invert(),t.parent!==null&&(t.parent.updateWorldMatrix(!0,!1),Ni.multiply(t.parent.matrixWorld)),t.applyMatrix4(Ni),t.removeFromParent(),t.parent=this,this.children.push(t),t.updateWorldMatrix(!1,!0),t.dispatchEvent(Xh),Vs.child=t,this.dispatchEvent(Vs),Vs.child=null,this}getObjectById(t){return this.getObjectByProperty("id",t)}getObjectByName(t){return this.getObjectByProperty("name",t)}getObjectByProperty(t,e){if(this[t]===e)return this;for(let n=0,s=this.children.length;n<s;n++){let a=this.children[n].getObjectByProperty(t,e);if(a!==void 0)return a}}getObjectsByProperty(t,e,n=[]){this[t]===e&&n.push(this);let s=this.children;for(let r=0,a=s.length;r<a;r++)s[r].getObjectsByProperty(t,e,n);return n}getWorldPosition(t){return this.updateWorldMatrix(!0,!1),t.setFromMatrixPosition(this.matrixWorld)}getWorldQuaternion(t){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose($r,t,vd),t}getWorldScale(t){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose($r,yd,t),t}getWorldDirection(t){this.updateWorldMatrix(!0,!1);let e=this.matrixWorld.elements;return t.set(e[8],e[9],e[10]).normalize()}raycast(){}intersectsFrustum(){}traverse(t){t(this);let e=this.children;for(let n=0,s=e.length;n<s;n++)e[n].traverse(t)}traverseVisible(t){if(this.visible===!1)return;t(this);let e=this.children;for(let n=0,s=e.length;n<s;n++)e[n].traverseVisible(t)}traverseAncestors(t){let e=this.parent;e!==null&&(t(e),e.traverseAncestors(t))}updateMatrix(){this.matrix.compose(this.position,this.quaternion,this.scale);let t=this.pivot;if(t!==null){let e=t.x,n=t.y,s=t.z,r=this.matrix.elements;r[12]+=e-r[0]*e-r[4]*n-r[8]*s,r[13]+=n-r[1]*e-r[5]*n-r[9]*s,r[14]+=s-r[2]*e-r[6]*n-r[10]*s}this.matrixWorldNeedsUpdate=!0}updateMatrixWorld(t){this.matrixAutoUpdate&&this.updateMatrix(),(this.matrixWorldNeedsUpdate||t)&&(this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),this.matrixWorldNeedsUpdate=!1,t=!0);let e=this.children;for(let n=0,s=e.length;n<s;n++)e[n].updateMatrixWorld(t)}updateWorldMatrix(t,e,n=!1){let s=this.parent;if(t===!0&&s!==null&&s.updateWorldMatrix(!0,!1),this.matrixAutoUpdate&&this.updateMatrix(),(this.matrixWorldNeedsUpdate||n)&&(this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),this.matrixWorldNeedsUpdate=!1,n=!0),e===!0){let r=this.children;for(let a=0,o=r.length;a<o;a++)r[a].updateWorldMatrix(!1,!0,n)}}toJSON(t){let e=t===void 0||typeof t=="string",n={};e&&(t={geometries:{},materials:{},textures:{},images:{},shapes:{},skeletons:{},animations:{},nodes:{}},n.metadata={version:4.7,type:"Object",generator:"Object3D.toJSON"});let s={};s.uuid=this.uuid,s.type=this.type,s.name=this.name,s.castShadow=this.castShadow,s.receiveShadow=this.receiveShadow,s.visible=this.visible,s.frustumCulled=this.frustumCulled,s.renderOrder=this.renderOrder,s.static=this.static,s.matrixAutoUpdate=this.matrixAutoUpdate,Object.keys(this.userData).length>0&&(s.userData=this.userData),s.layers=this.layers.mask,s.matrix=this.matrix.toArray(),s.up=this.up.toArray(),this.pivot!==null&&(s.pivot=this.pivot.toArray()),this.morphTargetDictionary!==void 0&&(s.morphTargetDictionary=Object.assign({},this.morphTargetDictionary)),this.morphTargetInfluences!==void 0&&(s.morphTargetInfluences=this.morphTargetInfluences.slice()),this.isInstancedMesh&&(s.type="InstancedMesh",s.count=this.count,s.instanceMatrix=this.instanceMatrix.toJSON(),this.instanceColor!==null&&(s.instanceColor=this.instanceColor.toJSON())),this.isBatchedMesh&&(s.type="BatchedMesh",s.perObjectFrustumCulled=this.perObjectFrustumCulled,s.sortObjects=this.sortObjects,s.drawRanges=this._drawRanges,s.reservedRanges=this._reservedRanges,s.geometryInfo=this._geometryInfo.map(o=>({...o,boundingBox:o.boundingBox?o.boundingBox.toJSON():void 0,boundingSphere:o.boundingSphere?o.boundingSphere.toJSON():void 0})),s.instanceInfo=this._instanceInfo.map(o=>({...o})),s.availableInstanceIds=this._availableInstanceIds.slice(),s.availableGeometryIds=this._availableGeometryIds.slice(),s.nextIndexStart=this._nextIndexStart,s.nextVertexStart=this._nextVertexStart,s.geometryCount=this._geometryCount,s.maxInstanceCount=this._maxInstanceCount,s.maxVertexCount=this._maxVertexCount,s.maxIndexCount=this._maxIndexCount,s.geometryInitialized=this._geometryInitialized,s.matricesTexture=this._matricesTexture.toJSON(t),s.indirectTexture=this._indirectTexture.toJSON(t),this._colorsTexture!==null&&(s.colorsTexture=this._colorsTexture.toJSON(t)),this.boundingSphere!==null&&(s.boundingSphere=this.boundingSphere.toJSON()),this.boundingBox!==null&&(s.boundingBox=this.boundingBox.toJSON()));function r(o,l){return o[l.uuid]===void 0&&(o[l.uuid]=l.toJSON(t)),l.uuid}if(this.isScene)this.background&&(this.background.isColor?s.background=this.background.toJSON():this.background.isTexture&&(s.background=this.background.toJSON(t).uuid)),this.environment&&this.environment.isTexture&&this.environment.isRenderTargetTexture!==!0&&(s.environment=this.environment.toJSON(t).uuid);else if(this.isMesh||this.isLine||this.isPoints){s.geometry=r(t.geometries,this.geometry);let o=this.geometry.parameters;if(o!==void 0&&o.shapes!==void 0){let l=o.shapes;if(Array.isArray(l))for(let c=0,h=l.length;c<h;c++){let f=l[c];r(t.shapes,f)}else r(t.shapes,l)}}if(this.isSkinnedMesh&&(s.bindMode=this.bindMode,s.bindMatrix=this.bindMatrix.toArray(),this.skeleton!==void 0&&(r(t.skeletons,this.skeleton),s.skeleton=this.skeleton.uuid)),this.material!==void 0)if(Array.isArray(this.material)){let o=[];for(let l=0,c=this.material.length;l<c;l++)o.push(r(t.materials,this.material[l]));s.material=o}else s.material=r(t.materials,this.material);if(this.children.length>0){s.children=[];for(let o=0;o<this.children.length;o++)s.children.push(this.children[o].toJSON(t).object)}if(this.animations.length>0){s.animations=[];for(let o=0;o<this.animations.length;o++){let l=this.animations[o];s.animations.push(r(t.animations,l))}}if(e){let o=a(t.geometries),l=a(t.materials),c=a(t.textures),h=a(t.images),f=a(t.shapes),u=a(t.skeletons),d=a(t.animations),g=a(t.nodes);o.length>0&&(n.geometries=o),l.length>0&&(n.materials=l),c.length>0&&(n.textures=c),h.length>0&&(n.images=h),f.length>0&&(n.shapes=f),u.length>0&&(n.skeletons=u),d.length>0&&(n.animations=d),g.length>0&&(n.nodes=g)}return n.object=s,n;function a(o){let l=[];for(let c in o){let h=o[c];delete h.metadata,l.push(h)}return l}}clone(t){return new this.constructor().copy(this,t)}copy(t,e=!0){if(this.name=t.name,this.up.copy(t.up),this.position.copy(t.position),this.rotation.order=t.rotation.order,this.quaternion.copy(t.quaternion),this.scale.copy(t.scale),this.pivot=t.pivot!==null?t.pivot.clone():null,this.matrix.copy(t.matrix),this.matrixWorld.copy(t.matrixWorld),this.matrixAutoUpdate=t.matrixAutoUpdate,this.matrixWorldAutoUpdate=t.matrixWorldAutoUpdate,this.matrixWorldNeedsUpdate=t.matrixWorldNeedsUpdate,this.layers.mask=t.layers.mask,this.visible=t.visible,this.castShadow=t.castShadow,this.receiveShadow=t.receiveShadow,this.frustumCulled=t.frustumCulled,this.renderOrder=t.renderOrder,this.static=t.static,this.animations=t.animations.slice(),this.userData=JSON.parse(JSON.stringify(t.userData)),e===!0)for(let n=0;n<t.children.length;n++){let s=t.children[n];this.add(s.clone())}return this}dispose(){this.dispatchEvent({type:"dispose"})}};rn.DEFAULT_UP=new P(0,1,0);rn.DEFAULT_MATRIX_AUTO_UPDATE=!0;rn.DEFAULT_MATRIX_WORLD_AUTO_UPDATE=!0;var Qe=class extends rn{constructor(){super(),this.isGroup=!0,this.type="Group"}},Sd={type:"move"},ur=class{constructor(){this._targetRay=null,this._grip=null,this._hand=null}getHandSpace(){return this._hand===null&&(this._hand=new Qe,this._hand.matrixAutoUpdate=!1,this._hand.visible=!1,this._hand.joints={},this._hand.inputState={pinching:!1}),this._hand}getTargetRaySpace(){return this._targetRay===null&&(this._targetRay=new Qe,this._targetRay.matrixAutoUpdate=!1,this._targetRay.visible=!1,this._targetRay.hasLinearVelocity=!1,this._targetRay.linearVelocity=new P,this._targetRay.hasAngularVelocity=!1,this._targetRay.angularVelocity=new P),this._targetRay}getGripSpace(){return this._grip===null&&(this._grip=new Qe,this._grip.matrixAutoUpdate=!1,this._grip.visible=!1,this._grip.hasLinearVelocity=!1,this._grip.linearVelocity=new P,this._grip.hasAngularVelocity=!1,this._grip.angularVelocity=new P,this._grip.eventsEnabled=!1),this._grip}dispatchEvent(t){return this._targetRay!==null&&this._targetRay.dispatchEvent(t),this._grip!==null&&this._grip.dispatchEvent(t),this._hand!==null&&this._hand.dispatchEvent(t),this}connect(t){if(t&&t.hand){let e=this._hand;if(e)for(let n of t.hand.values())this._getHandJoint(e,n)}return this.dispatchEvent({type:"connected",data:t}),this}disconnect(t){return this.dispatchEvent({type:"disconnected",data:t}),this._targetRay!==null&&(this._targetRay.visible=!1),this._grip!==null&&(this._grip.visible=!1),this._hand!==null&&(this._hand.visible=!1),this}update(t,e,n){let s=null,r=null,a=null,o=this._targetRay,l=this._grip,c=this._hand;if(t&&e.session.visibilityState!=="visible-blurred"){if(c&&t.hand){a=!0;for(let _ of t.hand.values()){let m=e.getJointPose(_,n),p=this._getHandJoint(c,_);m!==null&&(p.matrix.fromArray(m.transform.matrix),p.matrix.decompose(p.position,p.rotation,p.scale),p.matrixWorldNeedsUpdate=!0,p.jointRadius=m.radius),p.visible=m!==null}let h=c.joints["index-finger-tip"],f=c.joints["thumb-tip"],u=h.position.distanceTo(f.position),d=.02,g=.005;c.inputState.pinching&&u>d+g?(c.inputState.pinching=!1,this.dispatchEvent({type:"pinchend",handedness:t.handedness,target:this})):!c.inputState.pinching&&u<=d-g&&(c.inputState.pinching=!0,this.dispatchEvent({type:"pinchstart",handedness:t.handedness,target:this}))}else l!==null&&t.gripSpace&&(r=e.getPose(t.gripSpace,n),r!==null&&(l.matrix.fromArray(r.transform.matrix),l.matrix.decompose(l.position,l.rotation,l.scale),l.matrixWorldNeedsUpdate=!0,r.linearVelocity?(l.hasLinearVelocity=!0,l.linearVelocity.copy(r.linearVelocity)):l.hasLinearVelocity=!1,r.angularVelocity?(l.hasAngularVelocity=!0,l.angularVelocity.copy(r.angularVelocity)):l.hasAngularVelocity=!1,l.eventsEnabled&&l.dispatchEvent({type:"gripUpdated",data:t,target:this})));o!==null&&(s=e.getPose(t.targetRaySpace,n),s===null&&r!==null&&(s=r),s!==null&&(o.matrix.fromArray(s.transform.matrix),o.matrix.decompose(o.position,o.rotation,o.scale),o.matrixWorldNeedsUpdate=!0,s.linearVelocity?(o.hasLinearVelocity=!0,o.linearVelocity.copy(s.linearVelocity)):o.hasLinearVelocity=!1,s.angularVelocity?(o.hasAngularVelocity=!0,o.angularVelocity.copy(s.angularVelocity)):o.hasAngularVelocity=!1,this.dispatchEvent(Sd)))}return o!==null&&(o.visible=s!==null),l!==null&&(l.visible=r!==null),c!==null&&(c.visible=a!==null),this}_getHandJoint(t,e){if(t.joints[e.jointName]===void 0){let n=new Qe;n.matrixAutoUpdate=!1,n.visible=!1,t.joints[e.jointName]=n,t.add(n)}return t.joints[e.jointName]}},sf={aliceblue:15792383,antiquewhite:16444375,aqua:65535,aquamarine:8388564,azure:15794175,beige:16119260,bisque:16770244,black:0,blanchedalmond:16772045,blue:255,blueviolet:9055202,brown:10824234,burlywood:14596231,cadetblue:6266528,chartreuse:8388352,chocolate:13789470,coral:16744272,cornflowerblue:6591981,cornsilk:16775388,crimson:14423100,cyan:65535,darkblue:139,darkcyan:35723,darkgoldenrod:12092939,darkgray:11119017,darkgreen:25600,darkgrey:11119017,darkkhaki:12433259,darkmagenta:9109643,darkolivegreen:5597999,darkorange:16747520,darkorchid:10040012,darkred:9109504,darksalmon:15308410,darkseagreen:9419919,darkslateblue:4734347,darkslategray:3100495,darkslategrey:3100495,darkturquoise:52945,darkviolet:9699539,deeppink:16716947,deepskyblue:49151,dimgray:6908265,dimgrey:6908265,dodgerblue:2003199,firebrick:11674146,floralwhite:16775920,forestgreen:2263842,fuchsia:16711935,gainsboro:14474460,ghostwhite:16316671,gold:16766720,goldenrod:14329120,gray:8421504,green:32768,greenyellow:11403055,grey:8421504,honeydew:15794160,hotpink:16738740,indianred:13458524,indigo:4915330,ivory:16777200,khaki:15787660,lavender:15132410,lavenderblush:16773365,lawngreen:8190976,lemonchiffon:16775885,lightblue:11393254,lightcoral:15761536,lightcyan:14745599,lightgoldenrodyellow:16448210,lightgray:13882323,lightgreen:9498256,lightgrey:13882323,lightpink:16758465,lightsalmon:16752762,lightseagreen:2142890,lightskyblue:8900346,lightslategray:7833753,lightslategrey:7833753,lightsteelblue:11584734,lightyellow:16777184,lime:65280,limegreen:3329330,linen:16445670,magenta:16711935,maroon:8388608,mediumaquamarine:6737322,mediumblue:205,mediumorchid:12211667,mediumpurple:9662683,mediumseagreen:3978097,mediumslateblue:8087790,mediumspringgreen:64154,mediumturquoise:4772300,mediumvioletred:13047173,midnightblue:1644912,mintcream:16121850,mistyrose:16770273,moccasin:16770229,navajowhite:16768685,navy:128,oldlace:16643558,olive:8421376,olivedrab:7048739,orange:16753920,orangered:16729344,orchid:14315734,palegoldenrod:15657130,palegreen:10025880,paleturquoise:11529966,palevioletred:14381203,papayawhip:16773077,peachpuff:16767673,peru:13468991,pink:16761035,plum:14524637,powderblue:11591910,purple:8388736,rebeccapurple:6697881,red:16711680,rosybrown:12357519,royalblue:4286945,saddlebrown:9127187,salmon:16416882,sandybrown:16032864,seagreen:3050327,seashell:16774638,sienna:10506797,silver:12632256,skyblue:8900331,slateblue:6970061,slategray:7372944,slategrey:7372944,snow:16775930,springgreen:65407,steelblue:4620980,tan:13808780,teal:32896,thistle:14204888,tomato:16737095,turquoise:4251856,violet:15631086,wheat:16113331,white:16777215,whitesmoke:16119285,yellow:16776960,yellowgreen:10145074},ji={h:0,s:0,l:0},So={h:0,s:0,l:0};function Qc(i,t,e){return e<0&&(e+=1),e>1&&(e-=1),e<1/6?i+(t-i)*6*e:e<1/2?t:e<2/3?i+(t-i)*6*(2/3-e):i}var se=class{constructor(t,e,n){return this.isColor=!0,this.r=1,this.g=1,this.b=1,this.set(t,e,n)}set(t,e,n){if(e===void 0&&n===void 0){let s=t;s&&s.isColor?this.copy(s):typeof s=="number"?this.setHex(s):typeof s=="string"&&this.setStyle(s)}else this.setRGB(t,e,n);return this}setScalar(t){return this.r=t,this.g=t,this.b=t,this}setHex(t,e=Ke){return t=Math.floor(t),this.r=(t>>16&255)/255,this.g=(t>>8&255)/255,this.b=(t&255)/255,Ae.colorSpaceToWorking(this,e),this}setRGB(t,e,n,s=Ae.workingColorSpace){return this.r=t,this.g=e,this.b=n,Ae.colorSpaceToWorking(this,s),this}setHSL(t,e,n,s=Ae.workingColorSpace){if(t=fd(t,1),e=we(e,0,1),n=we(n,0,1),e===0)this.r=this.g=this.b=n;else{let r=n<=.5?n*(1+e):n+e-n*e,a=2*n-r;this.r=Qc(a,r,t+1/3),this.g=Qc(a,r,t),this.b=Qc(a,r,t-1/3)}return Ae.colorSpaceToWorking(this,s),this}setStyle(t,e=Ke){function n(r){r!==void 0&&parseFloat(r)<1&&ue("Color: Alpha component of "+t+" will be ignored.")}let s;if(s=/^(\w+)\(([^\)]*)\)/.exec(t)){let r,a=s[1],o=s[2];switch(a){case"rgb":case"rgba":if(r=/^\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return n(r[4]),this.setRGB(Math.min(255,parseInt(r[1],10))/255,Math.min(255,parseInt(r[2],10))/255,Math.min(255,parseInt(r[3],10))/255,e);if(r=/^\s*(\d+)\%\s*,\s*(\d+)\%\s*,\s*(\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return n(r[4]),this.setRGB(Math.min(100,parseInt(r[1],10))/100,Math.min(100,parseInt(r[2],10))/100,Math.min(100,parseInt(r[3],10))/100,e);break;case"hsl":case"hsla":if(r=/^\s*(\d*\.?\d+)\s*,\s*(\d*\.?\d+)\%\s*,\s*(\d*\.?\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return n(r[4]),this.setHSL(parseFloat(r[1])/360,parseFloat(r[2])/100,parseFloat(r[3])/100,e);break;default:ue("Color: Unknown color model "+t)}}else if(s=/^\#([A-Fa-f\d]+)$/.exec(t)){let r=s[1],a=r.length;if(a===3)return this.setRGB(parseInt(r.charAt(0),16)/15,parseInt(r.charAt(1),16)/15,parseInt(r.charAt(2),16)/15,e);if(a===6)return this.setHex(parseInt(r,16),e);ue("Color: Invalid hex color "+t)}else if(t&&t.length>0)return this.setColorName(t,e);return this}setColorName(t,e=Ke){let n=sf[t.toLowerCase()];return n!==void 0?this.setHex(n,e):ue("Color: Unknown color "+t),this}clone(){return new this.constructor(this.r,this.g,this.b)}copy(t){return this.r=t.r,this.g=t.g,this.b=t.b,this}copySRGBToLinear(t){return this.r=Hi(t.r),this.g=Hi(t.g),this.b=Hi(t.b),this}copyLinearToSRGB(t){return this.r=sr(t.r),this.g=sr(t.g),this.b=sr(t.b),this}convertSRGBToLinear(){return this.copySRGBToLinear(this),this}convertLinearToSRGB(){return this.copyLinearToSRGB(this),this}getHex(t=Ke){return Ae.workingToColorSpace(Pn.copy(this),t),Math.round(we(Pn.r*255,0,255))*65536+Math.round(we(Pn.g*255,0,255))*256+Math.round(we(Pn.b*255,0,255))}getHexString(t=Ke){return("000000"+this.getHex(t).toString(16)).slice(-6)}getHSL(t,e=Ae.workingColorSpace){Ae.workingToColorSpace(Pn.copy(this),e);let n=Pn.r,s=Pn.g,r=Pn.b,a=Math.max(n,s,r),o=Math.min(n,s,r),l,c,h=(o+a)/2;if(o===a)l=0,c=0;else{let f=a-o;switch(c=h<=.5?f/(a+o):f/(2-a-o),a){case n:l=(s-r)/f+(s<r?6:0);break;case s:l=(r-n)/f+2;break;case r:l=(n-s)/f+4;break}l/=6}return t.h=l,t.s=c,t.l=h,t}getRGB(t,e=Ae.workingColorSpace){return Ae.workingToColorSpace(Pn.copy(this),e),t.r=Pn.r,t.g=Pn.g,t.b=Pn.b,t}getStyle(t=Ke){Ae.workingToColorSpace(Pn.copy(this),t);let e=Pn.r,n=Pn.g,s=Pn.b;return t!==Ke?`color(${t} ${e.toFixed(3)} ${n.toFixed(3)} ${s.toFixed(3)})`:`rgb(${Math.round(e*255)},${Math.round(n*255)},${Math.round(s*255)})`}offsetHSL(t,e,n){return this.getHSL(ji),this.setHSL(ji.h+t,ji.s+e,ji.l+n)}add(t){return this.r+=t.r,this.g+=t.g,this.b+=t.b,this}addColors(t,e){return this.r=t.r+e.r,this.g=t.g+e.g,this.b=t.b+e.b,this}addScalar(t){return this.r+=t,this.g+=t,this.b+=t,this}sub(t){return this.r=Math.max(0,this.r-t.r),this.g=Math.max(0,this.g-t.g),this.b=Math.max(0,this.b-t.b),this}multiply(t){return this.r*=t.r,this.g*=t.g,this.b*=t.b,this}multiplyScalar(t){return this.r*=t,this.g*=t,this.b*=t,this}lerp(t,e){return this.r+=(t.r-this.r)*e,this.g+=(t.g-this.g)*e,this.b+=(t.b-this.b)*e,this}lerpColors(t,e,n){return this.r=t.r+(e.r-t.r)*n,this.g=t.g+(e.g-t.g)*n,this.b=t.b+(e.b-t.b)*n,this}lerpHSL(t,e){this.getHSL(ji),t.getHSL(So);let n=Yc(ji.h,So.h,e),s=Yc(ji.s,So.s,e),r=Yc(ji.l,So.l,e);return this.setHSL(n,s,r),this}setFromVector3(t){return this.r=t.x,this.g=t.y,this.b=t.z,this}applyMatrix3(t){let e=this.r,n=this.g,s=this.b,r=t.elements;return this.r=r[0]*e+r[3]*n+r[6]*s,this.g=r[1]*e+r[4]*n+r[7]*s,this.b=r[2]*e+r[5]*n+r[8]*s,this}equals(t){return t.r===this.r&&t.g===this.g&&t.b===this.b}fromArray(t,e=0){return this.r=t[e],this.g=t[e+1],this.b=t[e+2],this}toArray(t=[],e=0){return t[e]=this.r,t[e+1]=this.g,t[e+2]=this.b,t}fromBufferAttribute(t,e){return this.r=t.getX(e),this.g=t.getY(e),this.b=t.getZ(e),this}toJSON(){return this.getHex()}*[Symbol.iterator](){yield this.r,yield this.g,yield this.b}},Pn=new se;se.NAMES=sf;var fa=class extends rn{constructor(){super(),this.isScene=!0,this.type="Scene",this.background=null,this.environment=null,this.fog=null,this.backgroundBlurriness=0,this.backgroundIntensity=1,this.backgroundRotation=new Vi,this.environmentIntensity=1,this.environmentRotation=new Vi,this.overrideMaterial=null,typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}copy(t,e){return super.copy(t,e),t.background!==null&&(this.background=t.background.clone()),t.environment!==null&&(this.environment=t.environment.clone()),t.fog!==null&&(this.fog=t.fog.clone()),this.backgroundBlurriness=t.backgroundBlurriness,this.backgroundIntensity=t.backgroundIntensity,this.backgroundRotation.copy(t.backgroundRotation),this.environmentIntensity=t.environmentIntensity,this.environmentRotation.copy(t.environmentRotation),t.overrideMaterial!==null&&(this.overrideMaterial=t.overrideMaterial.clone()),this.matrixAutoUpdate=t.matrixAutoUpdate,this}toJSON(t){let e=super.toJSON(t);return this.fog!==null&&(e.object.fog=this.fog.toJSON()),e.object.backgroundBlurriness=this.backgroundBlurriness,e.object.backgroundIntensity=this.backgroundIntensity,e.object.backgroundRotation=this.backgroundRotation.toArray(),e.object.environmentIntensity=this.environmentIntensity,e.object.environmentRotation=this.environmentRotation.toArray(),e}},ri=new P,Ui=new P,t0=new P,Fi=new P,Gs=new P,Ws=new P,qh=new P,e0=new P,n0=new P,i0=new P,s0=new $e,r0=new $e,a0=new $e,zi=class i{constructor(t=new P,e=new P,n=new P){this.a=t,this.b=e,this.c=n}static getNormal(t,e,n,s){s.subVectors(n,e),ri.subVectors(t,e),s.cross(ri);let r=s.lengthSq();return r>0?s.multiplyScalar(1/Math.sqrt(r)):s.set(0,0,0)}static getBarycoord(t,e,n,s,r){ri.subVectors(s,e),Ui.subVectors(n,e),t0.subVectors(t,e);let a=ri.dot(ri),o=ri.dot(Ui),l=ri.dot(t0),c=Ui.dot(Ui),h=Ui.dot(t0),f=a*c-o*o;if(f===0)return r.set(0,0,0),null;let u=1/f,d=(c*l-o*h)*u,g=(a*h-o*l)*u;return r.set(1-d-g,g,d)}static containsPoint(t,e,n,s){return this.getBarycoord(t,e,n,s,Fi)===null?!1:Fi.x>=0&&Fi.y>=0&&Fi.x+Fi.y<=1}static getInterpolation(t,e,n,s,r,a,o,l){return this.getBarycoord(t,e,n,s,Fi)===null?(l.x=0,l.y=0,"z"in l&&(l.z=0),"w"in l&&(l.w=0),null):(l.setScalar(0),l.addScaledVector(r,Fi.x),l.addScaledVector(a,Fi.y),l.addScaledVector(o,Fi.z),l)}static getInterpolatedAttribute(t,e,n,s,r,a){return s0.setScalar(0),r0.setScalar(0),a0.setScalar(0),s0.fromBufferAttribute(t,e),r0.fromBufferAttribute(t,n),a0.fromBufferAttribute(t,s),a.setScalar(0),a.addScaledVector(s0,r.x),a.addScaledVector(r0,r.y),a.addScaledVector(a0,r.z),a}static isFrontFacing(t,e,n,s){return ri.subVectors(n,e),Ui.subVectors(t,e),ri.cross(Ui).dot(s)<0}set(t,e,n){return this.a.copy(t),this.b.copy(e),this.c.copy(n),this}setFromPointsAndIndices(t,e,n,s){return this.a.copy(t[e]),this.b.copy(t[n]),this.c.copy(t[s]),this}setFromAttributeAndIndices(t,e,n,s){return this.a.fromBufferAttribute(t,e),this.b.fromBufferAttribute(t,n),this.c.fromBufferAttribute(t,s),this}clone(){return new this.constructor().copy(this)}copy(t){return this.a.copy(t.a),this.b.copy(t.b),this.c.copy(t.c),this}getArea(){return ri.subVectors(this.c,this.b),Ui.subVectors(this.a,this.b),ri.cross(Ui).length()*.5}getMidpoint(t){return t.addVectors(this.a,this.b).add(this.c).multiplyScalar(1/3)}getNormal(t){return i.getNormal(this.a,this.b,this.c,t)}getPlane(t){return t.setFromCoplanarPoints(this.a,this.b,this.c)}getBarycoord(t,e){return i.getBarycoord(t,this.a,this.b,this.c,e)}getInterpolation(t,e,n,s,r){return i.getInterpolation(t,this.a,this.b,this.c,e,n,s,r)}containsPoint(t){return i.containsPoint(t,this.a,this.b,this.c)}isFrontFacing(t){return i.isFrontFacing(this.a,this.b,this.c,t)}intersectsBox(t){return t.intersectsTriangle(this)}closestPointToPoint(t,e){let n=this.a,s=this.b,r=this.c,a,o;Gs.subVectors(s,n),Ws.subVectors(r,n),e0.subVectors(t,n);let l=Gs.dot(e0),c=Ws.dot(e0);if(l<=0&&c<=0)return e.copy(n);n0.subVectors(t,s);let h=Gs.dot(n0),f=Ws.dot(n0);if(h>=0&&f<=h)return e.copy(s);let u=l*f-h*c;if(u<=0&&l>=0&&h<=0)return a=l/(l-h),e.copy(n).addScaledVector(Gs,a);i0.subVectors(t,r);let d=Gs.dot(i0),g=Ws.dot(i0);if(g>=0&&d<=g)return e.copy(r);let _=d*c-l*g;if(_<=0&&c>=0&&g<=0)return o=c/(c-g),e.copy(n).addScaledVector(Ws,o);let m=h*g-d*f;if(m<=0&&f-h>=0&&d-g>=0)return qh.subVectors(r,s),o=(f-h)/(f-h+(d-g)),e.copy(s).addScaledVector(qh,o);let p=1/(m+_+u);return a=_*p,o=u*p,e.copy(n).addScaledVector(Gs,a).addScaledVector(Ws,o)}equals(t){return t.a.equals(this.a)&&t.b.equals(this.b)&&t.c.equals(this.c)}},Ei=class{constructor(t=new P(1/0,1/0,1/0),e=new P(-1/0,-1/0,-1/0)){this.isBox3=!0,this.min=t,this.max=e}set(t,e){return this.min.copy(t),this.max.copy(e),this}setFromArray(t){this.makeEmpty();for(let e=0,n=t.length;e<n;e+=3)this.expandByPoint(ai.fromArray(t,e));return this}setFromBufferAttribute(t){this.makeEmpty();for(let e=0,n=t.count;e<n;e++)this.expandByPoint(ai.fromBufferAttribute(t,e));return this}setFromPoints(t){this.makeEmpty();for(let e=0,n=t.length;e<n;e++)this.expandByPoint(t[e]);return this}setFromCenterAndSize(t,e){let n=ai.copy(e).multiplyScalar(.5);return this.min.copy(t).sub(n),this.max.copy(t).add(n),this}setFromObject(t,e=!1){return this.makeEmpty(),this.expandByObject(t,e)}clone(){return new this.constructor().copy(this)}copy(t){return this.min.copy(t.min),this.max.copy(t.max),this}makeEmpty(){return this.min.x=this.min.y=this.min.z=1/0,this.max.x=this.max.y=this.max.z=-1/0,this}isEmpty(){return this.max.x<this.min.x||this.max.y<this.min.y||this.max.z<this.min.z}getCenter(t){return this.isEmpty()?t.set(0,0,0):t.addVectors(this.min,this.max).multiplyScalar(.5)}getSize(t){return this.isEmpty()?t.set(0,0,0):t.subVectors(this.max,this.min)}expandByPoint(t){return this.min.min(t),this.max.max(t),this}expandByVector(t){return this.min.sub(t),this.max.add(t),this}expandByScalar(t){return this.min.addScalar(-t),this.max.addScalar(t),this}expandByObject(t,e=!1){t.updateWorldMatrix(!1,!1);let n=t.geometry;if(n!==void 0){let r=n.getAttribute("position");if(e===!0&&r!==void 0&&t.isInstancedMesh!==!0)for(let a=0,o=r.count;a<o;a++)t.isMesh===!0?t.getVertexPosition(a,ai):ai.fromBufferAttribute(r,a),ai.applyMatrix4(t.matrixWorld),this.expandByPoint(ai);else t.boundingBox!==void 0?(t.boundingBox===null&&t.computeBoundingBox(),bo.copy(t.boundingBox)):(n.boundingBox===null&&n.computeBoundingBox(),bo.copy(n.boundingBox)),bo.applyMatrix4(t.matrixWorld),this.union(bo)}let s=t.children;for(let r=0,a=s.length;r<a;r++)this.expandByObject(s[r],e);return this}containsPoint(t){return t.x>=this.min.x&&t.x<=this.max.x&&t.y>=this.min.y&&t.y<=this.max.y&&t.z>=this.min.z&&t.z<=this.max.z}containsBox(t){return this.min.x<=t.min.x&&t.max.x<=this.max.x&&this.min.y<=t.min.y&&t.max.y<=this.max.y&&this.min.z<=t.min.z&&t.max.z<=this.max.z}getParameter(t,e){return e.set((t.x-this.min.x)/(this.max.x-this.min.x),(t.y-this.min.y)/(this.max.y-this.min.y),(t.z-this.min.z)/(this.max.z-this.min.z))}intersectsBox(t){return t.max.x>=this.min.x&&t.min.x<=this.max.x&&t.max.y>=this.min.y&&t.min.y<=this.max.y&&t.max.z>=this.min.z&&t.min.z<=this.max.z}intersectsSphere(t){return this.clampPoint(t.center,ai),ai.distanceToSquared(t.center)<=t.radius*t.radius}intersectsPlane(t){let e,n;return t.normal.x>0?(e=t.normal.x*this.min.x,n=t.normal.x*this.max.x):(e=t.normal.x*this.max.x,n=t.normal.x*this.min.x),t.normal.y>0?(e+=t.normal.y*this.min.y,n+=t.normal.y*this.max.y):(e+=t.normal.y*this.max.y,n+=t.normal.y*this.min.y),t.normal.z>0?(e+=t.normal.z*this.min.z,n+=t.normal.z*this.max.z):(e+=t.normal.z*this.max.z,n+=t.normal.z*this.min.z),e<=-t.constant&&n>=-t.constant}intersectsTriangle(t){if(this.isEmpty())return!1;this.getCenter(Zr),Eo.subVectors(this.max,Zr),Xs.subVectors(t.a,Zr),qs.subVectors(t.b,Zr),Ys.subVectors(t.c,Zr),Qi.subVectors(qs,Xs),ts.subVectors(Ys,qs),ys.subVectors(Xs,Ys);let e=[0,-Qi.z,Qi.y,0,-ts.z,ts.y,0,-ys.z,ys.y,Qi.z,0,-Qi.x,ts.z,0,-ts.x,ys.z,0,-ys.x,-Qi.y,Qi.x,0,-ts.y,ts.x,0,-ys.y,ys.x,0];return!o0(e,Xs,qs,Ys,Eo)||(e=[1,0,0,0,1,0,0,0,1],!o0(e,Xs,qs,Ys,Eo))?!1:(To.crossVectors(Qi,ts),e=[To.x,To.y,To.z],o0(e,Xs,qs,Ys,Eo))}clampPoint(t,e){return e.copy(t).clamp(this.min,this.max)}distanceToPoint(t){return this.clampPoint(t,ai).distanceTo(t)}getBoundingSphere(t){return this.isEmpty()?t.makeEmpty():(this.getCenter(t.center),t.radius=this.getSize(ai).length()*.5),t}intersect(t){return this.min.max(t.min),this.max.min(t.max),this.isEmpty()&&this.makeEmpty(),this}union(t){return this.min.min(t.min),this.max.max(t.max),this}applyMatrix4(t){return this.isEmpty()?this:(Oi[0].set(this.min.x,this.min.y,this.min.z).applyMatrix4(t),Oi[1].set(this.min.x,this.min.y,this.max.z).applyMatrix4(t),Oi[2].set(this.min.x,this.max.y,this.min.z).applyMatrix4(t),Oi[3].set(this.min.x,this.max.y,this.max.z).applyMatrix4(t),Oi[4].set(this.max.x,this.min.y,this.min.z).applyMatrix4(t),Oi[5].set(this.max.x,this.min.y,this.max.z).applyMatrix4(t),Oi[6].set(this.max.x,this.max.y,this.min.z).applyMatrix4(t),Oi[7].set(this.max.x,this.max.y,this.max.z).applyMatrix4(t),this.setFromPoints(Oi),this)}translate(t){return this.min.add(t),this.max.add(t),this}equals(t){return t.min.equals(this.min)&&t.max.equals(this.max)}toJSON(){return{min:this.min.toArray(),max:this.max.toArray()}}fromJSON(t){return this.min.fromArray(t.min),this.max.fromArray(t.max),this}},Oi=[new P,new P,new P,new P,new P,new P,new P,new P],ai=new P,bo=new Ei,Xs=new P,qs=new P,Ys=new P,Qi=new P,ts=new P,ys=new P,Zr=new P,Eo=new P,To=new P,Ms=new P;function o0(i,t,e,n,s){for(let r=0,a=i.length-3;r<=a;r+=3){Ms.fromArray(i,r);let o=s.x*Math.abs(Ms.x)+s.y*Math.abs(Ms.y)+s.z*Math.abs(Ms.z),l=t.dot(Ms),c=e.dot(Ms),h=n.dot(Ms);if(Math.max(-Math.max(l,c,h),Math.min(l,c,h))>o)return!1}return!0}var nn=new P,wo=new ft,bd=0,sn=class extends Si{constructor(t,e,n=!1){if(super(),Array.isArray(t))throw new TypeError("THREE.BufferAttribute: array should be a Typed Array.");this.isBufferAttribute=!0,Object.defineProperty(this,"id",{value:bd++}),this.name="",this.array=t,this.itemSize=e,this.count=t!==void 0?t.length/e:0,this.normalized=n,this.usage=q0,this.updateRanges=[],this.gpuType=ti,this.version=0}onUploadCallback(){}set needsUpdate(t){t===!0&&this.version++}setUsage(t){return this.usage=t,this}addUpdateRange(t,e){this.updateRanges.push({start:t,count:e})}clearUpdateRanges(){this.updateRanges.length=0}copy(t){return this.name=t.name,this.array=new t.array.constructor(t.array),this.itemSize=t.itemSize,this.count=t.count,this.normalized=t.normalized,this.usage=t.usage,this.gpuType=t.gpuType,this}copyAt(t,e,n){t*=this.itemSize,n*=e.itemSize;for(let s=0,r=this.itemSize;s<r;s++)this.array[t+s]=e.array[n+s];return this}copyArray(t){return this.array.set(t),this}applyMatrix3(t){if(this.itemSize===2)for(let e=0,n=this.count;e<n;e++)wo.fromBufferAttribute(this,e),wo.applyMatrix3(t),this.setXY(e,wo.x,wo.y);else if(this.itemSize===3)for(let e=0,n=this.count;e<n;e++)nn.fromBufferAttribute(this,e),nn.applyMatrix3(t),this.setXYZ(e,nn.x,nn.y,nn.z);return this}applyMatrix4(t){for(let e=0,n=this.count;e<n;e++)nn.fromBufferAttribute(this,e),nn.applyMatrix4(t),this.setXYZ(e,nn.x,nn.y,nn.z);return this}applyNormalMatrix(t){for(let e=0,n=this.count;e<n;e++)nn.fromBufferAttribute(this,e),nn.applyNormalMatrix(t),this.setXYZ(e,nn.x,nn.y,nn.z);return this}transformDirection(t){for(let e=0,n=this.count;e<n;e++)nn.fromBufferAttribute(this,e),nn.transformDirection(t),this.setXYZ(e,nn.x,nn.y,nn.z);return this}set(t,e=0){return this.array.set(t,e),this}getComponent(t,e){let n=this.array[t*this.itemSize+e];return this.normalized&&(n=_i(n,this.array)),n}setComponent(t,e,n){return this.normalized&&(n=We(n,this.array)),this.array[t*this.itemSize+e]=n,this}getX(t){let e=this.array[t*this.itemSize];return this.normalized&&(e=_i(e,this.array)),e}setX(t,e){return this.normalized&&(e=We(e,this.array)),this.array[t*this.itemSize]=e,this}getY(t){let e=this.array[t*this.itemSize+1];return this.normalized&&(e=_i(e,this.array)),e}setY(t,e){return this.normalized&&(e=We(e,this.array)),this.array[t*this.itemSize+1]=e,this}getZ(t){let e=this.array[t*this.itemSize+2];return this.normalized&&(e=_i(e,this.array)),e}setZ(t,e){return this.normalized&&(e=We(e,this.array)),this.array[t*this.itemSize+2]=e,this}getW(t){let e=this.array[t*this.itemSize+3];return this.normalized&&(e=_i(e,this.array)),e}setW(t,e){return this.normalized&&(e=We(e,this.array)),this.array[t*this.itemSize+3]=e,this}setXY(t,e,n){return t*=this.itemSize,this.normalized&&(e=We(e,this.array),n=We(n,this.array)),this.array[t+0]=e,this.array[t+1]=n,this}setXYZ(t,e,n,s){return t*=this.itemSize,this.normalized&&(e=We(e,this.array),n=We(n,this.array),s=We(s,this.array)),this.array[t+0]=e,this.array[t+1]=n,this.array[t+2]=s,this}setXYZW(t,e,n,s,r){return t*=this.itemSize,this.normalized&&(e=We(e,this.array),n=We(n,this.array),s=We(s,this.array),r=We(r,this.array)),this.array[t+0]=e,this.array[t+1]=n,this.array[t+2]=s,this.array[t+3]=r,this}onUpload(t){return this.onUploadCallback=t,this}clone(){return new this.constructor(this.array,this.itemSize).copy(this)}toJSON(){let t={itemSize:this.itemSize,type:this.array.constructor.name,array:Array.from(this.array),normalized:this.normalized};return t.name=this.name,t.usage=this.usage,t.gpuType=this.gpuType,t}dispose(){this.dispatchEvent({type:"dispose"})}};var da=class extends sn{constructor(t,e,n){super(new Uint16Array(t),e,n)}};var pa=class extends sn{constructor(t,e,n){super(new Uint32Array(t),e,n)}};var pe=class extends sn{constructor(t,e,n){super(new Float32Array(t),e,n)}},Ed=new Ei,Jr=new P,l0=new P,Jn=class{constructor(t=new P,e=-1){this.isSphere=!0,this.center=t,this.radius=e}set(t,e){return this.center.copy(t),this.radius=e,this}setFromPoints(t,e){let n=this.center;e!==void 0?n.copy(e):Ed.setFromPoints(t).getCenter(n);let s=0;for(let r=0,a=t.length;r<a;r++)s=Math.max(s,n.distanceToSquared(t[r]));return this.radius=Math.sqrt(s),this}copy(t){return this.center.copy(t.center),this.radius=t.radius,this}isEmpty(){return this.radius<0}makeEmpty(){return this.center.set(0,0,0),this.radius=-1,this}containsPoint(t){return t.distanceToSquared(this.center)<=this.radius*this.radius}distanceToPoint(t){return t.distanceTo(this.center)-this.radius}intersectsSphere(t){let e=this.radius+t.radius;return t.center.distanceToSquared(this.center)<=e*e}intersectsBox(t){return t.intersectsSphere(this)}intersectsPlane(t){return Math.abs(t.distanceToPoint(this.center))<=this.radius}clampPoint(t,e){let n=this.center.distanceToSquared(t);return e.copy(t),n>this.radius*this.radius&&(e.sub(this.center).normalize(),e.multiplyScalar(this.radius).add(this.center)),e}getBoundingBox(t){return this.isEmpty()?(t.makeEmpty(),t):(t.set(this.center,this.center),t.expandByScalar(this.radius),t)}applyMatrix4(t){return this.center.applyMatrix4(t),this.radius=this.radius*t.getMaxScaleOnAxis(),this}translate(t){return this.center.add(t),this}expandByPoint(t){if(this.isEmpty())return this.center.copy(t),this.radius=0,this;Jr.subVectors(t,this.center);let e=Jr.lengthSq();if(e>this.radius*this.radius){let n=Math.sqrt(e),s=(n-this.radius)*.5;this.center.addScaledVector(Jr,s/n),this.radius+=s}return this}union(t){return t.isEmpty()?this:this.isEmpty()?(this.copy(t),this):(this.center.equals(t.center)===!0?this.radius=Math.max(this.radius,t.radius):(l0.subVectors(t.center,this.center).setLength(t.radius),this.expandByPoint(Jr.copy(t.center).add(l0)),this.expandByPoint(Jr.copy(t.center).sub(l0))),this)}equals(t){return t.center.equals(this.center)&&t.radius===this.radius}clone(){return new this.constructor().copy(this)}toJSON(){return{radius:this.radius,center:this.center.toArray()}}fromJSON(t){return this.radius=t.radius,this.center.fromArray(t.center),this}},Td=0,Zn=new De,c0=new rn,$s=new P,kn=new Ei,Kr=new Ei,mn=new P,Ie=class i extends Si{constructor(){super(),this.isBufferGeometry=!0,Object.defineProperty(this,"id",{value:Td++}),this.uuid=ki(),this.name="",this.type="BufferGeometry",this.index=null,this.indirect=null,this.indirectOffset=0,this.attributes={},this.morphAttributes={},this.morphTargetsRelative=!1,this.groups=[],this.boundingBox=null,this.boundingSphere=null,this.drawRange={start:0,count:1/0},this.userData={},this._transformed=!1}getIndex(){return this.index}setIndex(t){return Array.isArray(t)?this.index=new(hd(t)?pa:da)(t,1):this.index=t,this}setIndirect(t,e=0){return this.indirect=t,this.indirectOffset=e,this}getIndirect(){return this.indirect}getAttribute(t){return this.attributes[t]}setAttribute(t,e){return this.attributes[t]=e,this}deleteAttribute(t){return delete this.attributes[t],this}hasAttribute(t){return this.attributes[t]!==void 0}addGroup(t,e,n=0){this.groups.push({start:t,count:e,materialIndex:n})}clearGroups(){this.groups=[]}setDrawRange(t,e){this.drawRange.start=t,this.drawRange.count=e}applyMatrix4(t){let e=this.attributes.position;e!==void 0&&(e.applyMatrix4(t),e.needsUpdate=!0);let n=this.attributes.normal;if(n!==void 0){let r=new xe().getNormalMatrix(t);n.applyNormalMatrix(r),n.needsUpdate=!0}let s=this.attributes.tangent;return s!==void 0&&(s.transformDirection(t),s.needsUpdate=!0),this.boundingBox!==null&&this.computeBoundingBox(),this.boundingSphere!==null&&this.computeBoundingSphere(),this._transformed=!0,this}applyQuaternion(t){return Zn.makeRotationFromQuaternion(t),this.applyMatrix4(Zn),this}rotateX(t){return Zn.makeRotationX(t),this.applyMatrix4(Zn),this}rotateY(t){return Zn.makeRotationY(t),this.applyMatrix4(Zn),this}rotateZ(t){return Zn.makeRotationZ(t),this.applyMatrix4(Zn),this}translate(t,e,n){return Zn.makeTranslation(t,e,n),this.applyMatrix4(Zn),this}scale(t,e,n){return Zn.makeScale(t,e,n),this.applyMatrix4(Zn),this}lookAt(t){return c0.lookAt(t),c0.updateMatrix(),this.applyMatrix4(c0.matrix),this}center(){return this.computeBoundingBox(),this.boundingBox.getCenter($s).negate(),this.translate($s.x,$s.y,$s.z),this}setFromPoints(t){let e=this.getAttribute("position");if(e===void 0){let n=[];for(let s=0,r=t.length;s<r;s++){let a=t[s];n.push(a.x,a.y,a.z||0)}this.setAttribute("position",new pe(n,3))}else{let n=Math.min(t.length,e.count);for(let s=0;s<n;s++){let r=t[s];e.setXYZ(s,r.x,r.y,r.z||0)}t.length>e.count&&ue("BufferGeometry: Buffer size too small for points data. Use .dispose() and create a new geometry."),e.needsUpdate=!0}return this}computeBoundingBox(){this.boundingBox===null&&(this.boundingBox=new Ei);let t=this.attributes.position,e=this.morphAttributes.position;if(t&&t.isGLBufferAttribute){he("BufferGeometry.computeBoundingBox(): GLBufferAttribute requires a manual bounding box.",this),this.boundingBox.set(new P(-1/0,-1/0,-1/0),new P(1/0,1/0,1/0));return}if(t!==void 0){if(this.boundingBox.setFromBufferAttribute(t),e)for(let n=0,s=e.length;n<s;n++){let r=e[n];kn.setFromBufferAttribute(r),this.morphTargetsRelative?(mn.addVectors(this.boundingBox.min,kn.min),this.boundingBox.expandByPoint(mn),mn.addVectors(this.boundingBox.max,kn.max),this.boundingBox.expandByPoint(mn)):(this.boundingBox.expandByPoint(kn.min),this.boundingBox.expandByPoint(kn.max))}}else this.boundingBox.makeEmpty();(isNaN(this.boundingBox.min.x)||isNaN(this.boundingBox.min.y)||isNaN(this.boundingBox.min.z))&&he('BufferGeometry.computeBoundingBox(): Computed min/max have NaN values. The "position" attribute is likely to have NaN values.',this)}computeBoundingSphere(){this.boundingSphere===null&&(this.boundingSphere=new Jn);let t=this.attributes.position,e=this.morphAttributes.position;if(t&&t.isGLBufferAttribute){he("BufferGeometry.computeBoundingSphere(): GLBufferAttribute requires a manual bounding sphere.",this),this.boundingSphere.set(new P,1/0);return}if(t){let n=this.boundingSphere.center;if(kn.setFromBufferAttribute(t),e)for(let r=0,a=e.length;r<a;r++){let o=e[r];Kr.setFromBufferAttribute(o),this.morphTargetsRelative?(mn.addVectors(kn.min,Kr.min),kn.expandByPoint(mn),mn.addVectors(kn.max,Kr.max),kn.expandByPoint(mn)):(kn.expandByPoint(Kr.min),kn.expandByPoint(Kr.max))}kn.getCenter(n);let s=0;for(let r=0,a=t.count;r<a;r++)mn.fromBufferAttribute(t,r),s=Math.max(s,n.distanceToSquared(mn));if(e)for(let r=0,a=e.length;r<a;r++){let o=e[r],l=this.morphTargetsRelative;for(let c=0,h=o.count;c<h;c++)mn.fromBufferAttribute(o,c),l&&($s.fromBufferAttribute(t,c),mn.add($s)),s=Math.max(s,n.distanceToSquared(mn))}this.boundingSphere.radius=Math.sqrt(s),isNaN(this.boundingSphere.radius)&&he('BufferGeometry.computeBoundingSphere(): Computed radius is NaN. The "position" attribute is likely to have NaN values.',this)}}computeTangents(){let t=this.index,e=this.attributes;if(t===null||e.position===void 0||e.normal===void 0||e.uv===void 0){he("BufferGeometry: .computeTangents() failed. Missing required attributes (index, position, normal or uv)");return}let n=e.position,s=e.normal,r=e.uv,a=this.getAttribute("tangent");(a===void 0||a.count!==n.count)&&(a=new sn(new Float32Array(4*n.count),4),this.setAttribute("tangent",a));let o=[],l=[];for(let y=0;y<n.count;y++)o[y]=new P,l[y]=new P;let c=new P,h=new P,f=new P,u=new ft,d=new ft,g=new ft,_=new P,m=new P;function p(y,w,I){c.fromBufferAttribute(n,y),h.fromBufferAttribute(n,w),f.fromBufferAttribute(n,I),u.fromBufferAttribute(r,y),d.fromBufferAttribute(r,w),g.fromBufferAttribute(r,I),h.sub(c),f.sub(c),d.sub(u),g.sub(u);let N=1/(d.x*g.y-g.x*d.y);isFinite(N)&&(_.copy(h).multiplyScalar(g.y).addScaledVector(f,-d.y).multiplyScalar(N),m.copy(f).multiplyScalar(d.x).addScaledVector(h,-g.x).multiplyScalar(N),o[y].add(_),o[w].add(_),o[I].add(_),l[y].add(m),l[w].add(m),l[I].add(m))}let S=this.groups;S.length===0&&(S=[{start:0,count:t.count}]);for(let y=0,w=S.length;y<w;++y){let I=S[y],N=I.start,H=I.count;for(let W=N,U=N+H;W<U;W+=3)p(t.getX(W+0),t.getX(W+1),t.getX(W+2))}let A=new P,v=new P,b=new P,E=new P;function C(y){b.fromBufferAttribute(s,y),E.copy(b);let w=o[y];A.copy(w),A.sub(b.multiplyScalar(b.dot(w))).normalize(),v.crossVectors(E,w);let N=v.dot(l[y])<0?-1:1;a.setXYZW(y,A.x,A.y,A.z,N)}for(let y=0,w=S.length;y<w;++y){let I=S[y],N=I.start,H=I.count;for(let W=N,U=N+H;W<U;W+=3)C(t.getX(W+0)),C(t.getX(W+1)),C(t.getX(W+2))}this._transformed=!0}computeVertexNormals(){let t=this.index,e=this.getAttribute("position");if(e!==void 0){let n=this.getAttribute("normal");if(n===void 0||n.count!==e.count)n=new sn(new Float32Array(e.count*3),3),this.setAttribute("normal",n);else for(let u=0,d=n.count;u<d;u++)n.setXYZ(u,0,0,0);let s=new P,r=new P,a=new P,o=new P,l=new P,c=new P,h=new P,f=new P;if(t)for(let u=0,d=t.count;u<d;u+=3){let g=t.getX(u+0),_=t.getX(u+1),m=t.getX(u+2);s.fromBufferAttribute(e,g),r.fromBufferAttribute(e,_),a.fromBufferAttribute(e,m),h.subVectors(a,r),f.subVectors(s,r),h.cross(f),o.fromBufferAttribute(n,g),l.fromBufferAttribute(n,_),c.fromBufferAttribute(n,m),o.add(h),l.add(h),c.add(h),n.setXYZ(g,o.x,o.y,o.z),n.setXYZ(_,l.x,l.y,l.z),n.setXYZ(m,c.x,c.y,c.z)}else for(let u=0,d=e.count;u<d;u+=3)s.fromBufferAttribute(e,u+0),r.fromBufferAttribute(e,u+1),a.fromBufferAttribute(e,u+2),h.subVectors(a,r),f.subVectors(s,r),h.cross(f),n.setXYZ(u+0,h.x,h.y,h.z),n.setXYZ(u+1,h.x,h.y,h.z),n.setXYZ(u+2,h.x,h.y,h.z);this.normalizeNormals(),n.needsUpdate=!0}}normalizeNormals(){let t=this.attributes.normal;for(let e=0,n=t.count;e<n;e++)mn.fromBufferAttribute(t,e),mn.normalize(),t.setXYZ(e,mn.x,mn.y,mn.z)}toNonIndexed(){function t(o,l){let c=o.array,h=o.itemSize,f=o.normalized,u=new c.constructor(l.length*h),d=0,g=0;for(let _=0,m=l.length;_<m;_++){o.isInterleavedBufferAttribute?d=l[_]*o.data.stride+o.offset:d=l[_]*h;for(let p=0;p<h;p++)u[g++]=c[d++]}return new sn(u,h,f)}if(this.index===null)return ue("BufferGeometry.toNonIndexed(): BufferGeometry is already non-indexed."),this;let e=new i,n=this.index.array,s=this.attributes;for(let o in s){let l=s[o],c=t(l,n);e.setAttribute(o,c)}let r=this.morphAttributes;for(let o in r){let l=[],c=r[o];for(let h=0,f=c.length;h<f;h++){let u=c[h],d=t(u,n);l.push(d)}e.morphAttributes[o]=l}e.morphTargetsRelative=this.morphTargetsRelative;let a=this.groups;for(let o=0,l=a.length;o<l;o++){let c=a[o];e.addGroup(c.start,c.count,c.materialIndex)}return e}toJSON(){let t={metadata:{version:4.7,type:"BufferGeometry",generator:"BufferGeometry.toJSON"}};if(t.uuid=this.uuid,t.type=this.parameters!==void 0&&this._transformed===!0?"BufferGeometry":this.type,t.name=this.name,Object.keys(this.userData).length>0&&(t.userData=this.userData),this.parameters!==void 0&&this._transformed!==!0){let l=this.parameters;for(let c in l)l[c]!==void 0&&(t[c]=l[c]);return t}t.data={attributes:{}};let e=this.index;e!==null&&(t.data.index={type:e.array.constructor.name,array:Array.prototype.slice.call(e.array)});let n=this.attributes;for(let l in n){let c=n[l];t.data.attributes[l]=c.toJSON(t.data)}let s={},r=!1;for(let l in this.morphAttributes){let c=this.morphAttributes[l],h=[];for(let f=0,u=c.length;f<u;f++){let d=c[f];h.push(d.toJSON(t.data))}h.length>0&&(s[l]=h,r=!0)}r&&(t.data.morphAttributes=s,t.data.morphTargetsRelative=this.morphTargetsRelative);let a=this.groups;a.length>0&&(t.data.groups=JSON.parse(JSON.stringify(a)));let o=this.boundingSphere;return o!==null&&(t.data.boundingSphere=o.toJSON()),t}clone(){return new this.constructor().copy(this)}copy(t){this.index=null,this.attributes={},this.morphAttributes={},this.groups=[],this.boundingBox=null,this.boundingSphere=null;let e={};this.name=t.name;let n=t.index;n!==null&&this.setIndex(n.clone());let s=t.attributes;for(let c in s){let h=s[c];this.setAttribute(c,h.clone(e))}let r=t.morphAttributes;for(let c in r){let h=[],f=r[c];for(let u=0,d=f.length;u<d;u++)h.push(f[u].clone(e));this.morphAttributes[c]=h}this.morphTargetsRelative=t.morphTargetsRelative;let a=t.groups;for(let c=0,h=a.length;c<h;c++){let f=a[c];this.addGroup(f.start,f.count,f.materialIndex)}let o=t.boundingBox;o!==null&&(this.boundingBox=o.clone());let l=t.boundingSphere;return l!==null&&(this.boundingSphere=l.clone()),this.drawRange.start=t.drawRange.start,this.drawRange.count=t.drawRange.count,this.userData=t.userData,this._transformed=t._transformed,this}dispose(){this.dispatchEvent({type:"dispose"})}},ma=class{constructor(t,e){this.isInterleavedBuffer=!0,this.array=t,this.stride=e,this.count=t!==void 0?t.length/e:0,this.usage=q0,this.updateRanges=[],this.version=0,this.uuid=ki()}onUploadCallback(){}set needsUpdate(t){t===!0&&this.version++}setUsage(t){return this.usage=t,this}addUpdateRange(t,e){this.updateRanges.push({start:t,count:e})}clearUpdateRanges(){this.updateRanges.length=0}copy(t){return this.array=new t.array.constructor(t.array),this.count=t.count,this.stride=t.stride,this.usage=t.usage,this}copyAt(t,e,n){t*=this.stride,n*=e.stride;for(let s=0,r=this.stride;s<r;s++)this.array[t+s]=e.array[n+s];return this}set(t,e=0){return this.array.set(t,e),this}clone(t){t.arrayBuffers===void 0&&(t.arrayBuffers={}),this.array.buffer._uuid===void 0&&(this.array.buffer._uuid=ki()),t.arrayBuffers[this.array.buffer._uuid]===void 0&&(t.arrayBuffers[this.array.buffer._uuid]=this.array.slice(0).buffer);let e=new this.array.constructor(t.arrayBuffers[this.array.buffer._uuid]),n=new this.constructor(e,this.stride);return n.setUsage(this.usage),n}onUpload(t){return this.onUploadCallback=t,this}toJSON(t){t.arrayBuffers===void 0&&(t.arrayBuffers={}),this.array.buffer._uuid===void 0&&(this.array.buffer._uuid=ki()),t.arrayBuffers[this.array.buffer._uuid]===void 0&&(t.arrayBuffers[this.array.buffer._uuid]=Array.from(new Uint32Array(this.array.buffer)));let e={uuid:this.uuid,buffer:this.array.buffer._uuid,type:this.array.constructor.name,stride:this.stride};return e.usage=this.usage,e}},Dn=new P,fr=class i{constructor(t,e,n,s=!1){this.isInterleavedBufferAttribute=!0,this.name="",this.data=t,this.itemSize=e,this.offset=n,this.normalized=s}get count(){return this.data.count}get array(){return this.data.array}set needsUpdate(t){this.data.needsUpdate=t}applyMatrix4(t){for(let e=0,n=this.data.count;e<n;e++)Dn.fromBufferAttribute(this,e),Dn.applyMatrix4(t),this.setXYZ(e,Dn.x,Dn.y,Dn.z);return this}applyNormalMatrix(t){for(let e=0,n=this.count;e<n;e++)Dn.fromBufferAttribute(this,e),Dn.applyNormalMatrix(t),this.setXYZ(e,Dn.x,Dn.y,Dn.z);return this}transformDirection(t){for(let e=0,n=this.count;e<n;e++)Dn.fromBufferAttribute(this,e),Dn.transformDirection(t),this.setXYZ(e,Dn.x,Dn.y,Dn.z);return this}getComponent(t,e){let n=this.array[t*this.data.stride+this.offset+e];return this.normalized&&(n=_i(n,this.array)),n}setComponent(t,e,n){return this.normalized&&(n=We(n,this.array)),this.data.array[t*this.data.stride+this.offset+e]=n,this}setX(t,e){return this.normalized&&(e=We(e,this.array)),this.data.array[t*this.data.stride+this.offset]=e,this}setY(t,e){return this.normalized&&(e=We(e,this.array)),this.data.array[t*this.data.stride+this.offset+1]=e,this}setZ(t,e){return this.normalized&&(e=We(e,this.array)),this.data.array[t*this.data.stride+this.offset+2]=e,this}setW(t,e){return this.normalized&&(e=We(e,this.array)),this.data.array[t*this.data.stride+this.offset+3]=e,this}getX(t){let e=this.data.array[t*this.data.stride+this.offset];return this.normalized&&(e=_i(e,this.array)),e}getY(t){let e=this.data.array[t*this.data.stride+this.offset+1];return this.normalized&&(e=_i(e,this.array)),e}getZ(t){let e=this.data.array[t*this.data.stride+this.offset+2];return this.normalized&&(e=_i(e,this.array)),e}getW(t){let e=this.data.array[t*this.data.stride+this.offset+3];return this.normalized&&(e=_i(e,this.array)),e}setXY(t,e,n){return t=t*this.data.stride+this.offset,this.normalized&&(e=We(e,this.array),n=We(n,this.array)),this.data.array[t+0]=e,this.data.array[t+1]=n,this}setXYZ(t,e,n,s){return t=t*this.data.stride+this.offset,this.normalized&&(e=We(e,this.array),n=We(n,this.array),s=We(s,this.array)),this.data.array[t+0]=e,this.data.array[t+1]=n,this.data.array[t+2]=s,this}setXYZW(t,e,n,s,r){return t=t*this.data.stride+this.offset,this.normalized&&(e=We(e,this.array),n=We(n,this.array),s=We(s,this.array),r=We(r,this.array)),this.data.array[t+0]=e,this.data.array[t+1]=n,this.data.array[t+2]=s,this.data.array[t+3]=r,this}clone(t){if(t===void 0){ha("InterleavedBufferAttribute.clone(): Cloning an interleaved buffer attribute will de-interleave buffer data.");let e=[];for(let n=0;n<this.count;n++){let s=n*this.data.stride+this.offset;for(let r=0;r<this.itemSize;r++)e.push(this.data.array[s+r])}return new sn(new this.array.constructor(e),this.itemSize,this.normalized)}else return t.interleavedBuffers===void 0&&(t.interleavedBuffers={}),t.interleavedBuffers[this.data.uuid]===void 0&&(t.interleavedBuffers[this.data.uuid]=this.data.clone(t)),new i(t.interleavedBuffers[this.data.uuid],this.itemSize,this.offset,this.normalized)}toJSON(t){if(t===void 0){ha("InterleavedBufferAttribute.toJSON(): Serializing an interleaved buffer attribute will de-interleave buffer data.");let e=[];for(let n=0;n<this.count;n++){let s=n*this.data.stride+this.offset;for(let r=0;r<this.itemSize;r++)e.push(this.data.array[s+r])}return{itemSize:this.itemSize,type:this.array.constructor.name,array:e,normalized:this.normalized}}else return t.interleavedBuffers===void 0&&(t.interleavedBuffers={}),t.interleavedBuffers[this.data.uuid]===void 0&&(t.interleavedBuffers[this.data.uuid]=this.data.toJSON(t)),{isInterleavedBufferAttribute:!0,itemSize:this.itemSize,data:this.data.uuid,offset:this.offset,normalized:this.normalized}}},h0=new P,wd=new P,Ad=new xe,oi=class{constructor(t=new P(1,0,0),e=0){this.isPlane=!0,this.normal=t,this.constant=e}set(t,e){return this.normal.copy(t),this.constant=e,this}setComponents(t,e,n,s){return this.normal.set(t,e,n),this.constant=s,this}setFromNormalAndCoplanarPoint(t,e){return this.normal.copy(t),this.constant=-e.dot(this.normal),this}setFromCoplanarPoints(t,e,n){let s=h0.subVectors(n,e).cross(wd.subVectors(t,e)).normalize();return this.setFromNormalAndCoplanarPoint(s,t),this}copy(t){return this.normal.copy(t.normal),this.constant=t.constant,this}normalize(){let t=1/this.normal.length();return this.normal.multiplyScalar(t),this.constant*=t,this}negate(){return this.constant*=-1,this.normal.negate(),this}distanceToPoint(t){return this.normal.dot(t)+this.constant}distanceToSphere(t){return this.distanceToPoint(t.center)-t.radius}projectPoint(t,e){return e.copy(t).addScaledVector(this.normal,-this.distanceToPoint(t))}intersectLine(t,e,n=!0){let s=t.delta(h0),r=this.normal.dot(s);if(r===0)return this.distanceToPoint(t.start)===0?e.copy(t.start):null;let a=-(t.start.dot(this.normal)+this.constant)/r;return n===!0&&(a<0||a>1)?null:e.copy(t.start).addScaledVector(s,a)}intersectsLine(t){let e=this.distanceToPoint(t.start),n=this.distanceToPoint(t.end);return e<0&&n>0||n<0&&e>0}intersectsBox(t){return t.intersectsPlane(this)}intersectsSphere(t){return t.intersectsPlane(this)}coplanarPoint(t){return t.copy(this.normal).multiplyScalar(-this.constant)}applyMatrix4(t,e){let n=e||Ad.getNormalMatrix(t),s=this.coplanarPoint(h0).applyMatrix4(t),r=this.normal.applyMatrix3(n).normalize();return this.constant=-s.dot(r),this}translate(t){return this.constant-=t.dot(this.normal),this}equals(t){return t.normal.equals(this.normal)&&t.constant===this.constant}clone(){return new this.constructor().copy(this)}toJSON(){return{normal:this.normal.toArray(),constant:this.constant}}fromJSON(t){return this.normal.fromArray(t.normal),this.constant=t.constant,this}},Rd=0,ci=class extends Si{constructor(){super(),this.isMaterial=!0,Object.defineProperty(this,"id",{value:Rd++}),this.uuid=ki(),this.name="",this.type="Material",this.blending=us,this.side=hs,this.vertexColors=!1,this.opacity=1,this.transparent=!1,this.alphaHash=!1,this.blendSrc=F0,this.blendDst=O0,this.blendEquation=As,this.blendSrcAlpha=null,this.blendDstAlpha=null,this.blendEquationAlpha=null,this.blendColor=new se(0,0,0),this.blendAlpha=0,this.depthFunc=rr,this.depthTest=!0,this.depthWrite=!0,this.stencilWriteMask=255,this.stencilFunc=qu,this.stencilRef=0,this.stencilFuncMask=255,this.stencilFail=Ko,this.stencilZFail=Ko,this.stencilZPass=Ko,this.stencilWrite=!1,this.clippingPlanes=null,this.clipIntersection=!1,this.clipShadows=!1,this.shadowSide=null,this.colorWrite=!0,this.precision=null,this.polygonOffset=!1,this.polygonOffsetFactor=0,this.polygonOffsetUnits=0,this.dithering=!1,this.alphaToCoverage=!1,this.premultipliedAlpha=!1,this.forceSinglePass=!1,this.allowOverride=!0,this.visible=!0,this.toneMapped=!0,this.userData={},this.version=0,this._alphaTest=0}get alphaTest(){return this._alphaTest}set alphaTest(t){this._alphaTest>0!=t>0&&this.version++,this._alphaTest=t}onBeforeRender(){}onBeforeCompile(){}customProgramCacheKey(){return this.onBeforeCompile.toString()}setValues(t){if(t!==void 0)for(let e in t){let n=t[e];if(n===void 0){ue(`Material: parameter '${e}' has value of undefined.`);continue}let s=this[e];if(s===void 0){ue(`Material: '${e}' is not a property of THREE.${this.type}.`);continue}s&&s.isColor?s.set(n):s&&s.isVector2&&n&&n.isVector2||s&&s.isEuler&&n&&n.isEuler||s&&s.isVector3&&n&&n.isVector3?s.copy(n):this[e]=n}}toJSON(t){let e=t===void 0||typeof t=="string";e&&(t={textures:{},images:{}});let n={metadata:{version:4.7,type:"Material",generator:"Material.toJSON"}};n.uuid=this.uuid,n.type=this.type,n.blending=this.blending,n.side=this.side,n.shadowSide=this.shadowSide,n.vertexColors=this.vertexColors,n.opacity=this.opacity,n.transparent=this.transparent,n.blendSrc=this.blendSrc,n.blendDst=this.blendDst,n.blendEquation=this.blendEquation,n.blendSrcAlpha=this.blendSrcAlpha,n.blendDstAlpha=this.blendDstAlpha,n.blendEquationAlpha=this.blendEquationAlpha,n.blendColor=this.blendColor.getHex(),n.blendAlpha=this.blendAlpha,n.depthFunc=this.depthFunc,n.depthTest=this.depthTest,n.depthWrite=this.depthWrite,n.colorWrite=this.colorWrite,n.clipIntersection=this.clipIntersection,n.clipShadows=this.clipShadows,n.stencilWriteMask=this.stencilWriteMask,n.stencilFunc=this.stencilFunc,n.stencilRef=this.stencilRef,n.stencilFuncMask=this.stencilFuncMask,n.stencilFail=this.stencilFail,n.stencilZFail=this.stencilZFail,n.stencilZPass=this.stencilZPass,n.stencilWrite=this.stencilWrite,n.polygonOffset=this.polygonOffset,n.polygonOffsetFactor=this.polygonOffsetFactor,n.polygonOffsetUnits=this.polygonOffsetUnits,n.dithering=this.dithering,n.alphaTest=this.alphaTest,n.alphaHash=this.alphaHash,n.alphaToCoverage=this.alphaToCoverage,n.premultipliedAlpha=this.premultipliedAlpha,n.forceSinglePass=this.forceSinglePass,n.allowOverride=this.allowOverride,n.visible=this.visible,n.toneMapped=this.toneMapped,n.name=this.name,this.color&&this.color.isColor&&(n.color=this.color.getHex()),this.roughness!==void 0&&(n.roughness=this.roughness),this.metalness!==void 0&&(n.metalness=this.metalness),this.sheen!==void 0&&(n.sheen=this.sheen),this.sheenColor&&this.sheenColor.isColor&&(n.sheenColor=this.sheenColor.getHex()),this.sheenRoughness!==void 0&&(n.sheenRoughness=this.sheenRoughness),this.emissive&&this.emissive.isColor&&(n.emissive=this.emissive.getHex()),this.emissiveIntensity!==void 0&&(n.emissiveIntensity=this.emissiveIntensity),this.specular&&this.specular.isColor&&(n.specular=this.specular.getHex()),this.specularIntensity!==void 0&&(n.specularIntensity=this.specularIntensity),this.specularColor&&this.specularColor.isColor&&(n.specularColor=this.specularColor.getHex()),this.shininess!==void 0&&(n.shininess=this.shininess),this.clearcoat!==void 0&&(n.clearcoat=this.clearcoat),this.clearcoatRoughness!==void 0&&(n.clearcoatRoughness=this.clearcoatRoughness),this.clearcoatMap&&this.clearcoatMap.isTexture&&(n.clearcoatMap=this.clearcoatMap.toJSON(t).uuid),this.clearcoatRoughnessMap&&this.clearcoatRoughnessMap.isTexture&&(n.clearcoatRoughnessMap=this.clearcoatRoughnessMap.toJSON(t).uuid),this.clearcoatNormalMap&&this.clearcoatNormalMap.isTexture&&(n.clearcoatNormalMap=this.clearcoatNormalMap.toJSON(t).uuid,n.clearcoatNormalScale=this.clearcoatNormalScale.toArray()),this.sheenColorMap&&this.sheenColorMap.isTexture&&(n.sheenColorMap=this.sheenColorMap.toJSON(t).uuid),this.sheenRoughnessMap&&this.sheenRoughnessMap.isTexture&&(n.sheenRoughnessMap=this.sheenRoughnessMap.toJSON(t).uuid),this.dispersion!==void 0&&(n.dispersion=this.dispersion),this.retroreflectivity!==void 0&&(n.retroreflectivity=this.retroreflectivity),this.iridescence!==void 0&&(n.iridescence=this.iridescence),this.iridescenceIOR!==void 0&&(n.iridescenceIOR=this.iridescenceIOR),this.iridescenceThicknessRange!==void 0&&(n.iridescenceThicknessRange=this.iridescenceThicknessRange),this.iridescenceMap&&this.iridescenceMap.isTexture&&(n.iridescenceMap=this.iridescenceMap.toJSON(t).uuid),this.iridescenceThicknessMap&&this.iridescenceThicknessMap.isTexture&&(n.iridescenceThicknessMap=this.iridescenceThicknessMap.toJSON(t).uuid),this.anisotropy!==void 0&&(n.anisotropy=this.anisotropy),this.anisotropyRotation!==void 0&&(n.anisotropyRotation=this.anisotropyRotation),this.anisotropyMap&&this.anisotropyMap.isTexture&&(n.anisotropyMap=this.anisotropyMap.toJSON(t).uuid),this.map&&this.map.isTexture&&(n.map=this.map.toJSON(t).uuid),this.matcap&&this.matcap.isTexture&&(n.matcap=this.matcap.toJSON(t).uuid),this.alphaMap&&this.alphaMap.isTexture&&(n.alphaMap=this.alphaMap.toJSON(t).uuid),this.lightMap&&this.lightMap.isTexture&&(n.lightMap=this.lightMap.toJSON(t).uuid,n.lightMapIntensity=this.lightMapIntensity),this.aoMap&&this.aoMap.isTexture&&(n.aoMap=this.aoMap.toJSON(t).uuid,n.aoMapIntensity=this.aoMapIntensity),this.bumpMap&&this.bumpMap.isTexture&&(n.bumpMap=this.bumpMap.toJSON(t).uuid,n.bumpScale=this.bumpScale),this.normalMap&&this.normalMap.isTexture&&(n.normalMap=this.normalMap.toJSON(t).uuid,n.normalMapType=this.normalMapType,n.normalScale=this.normalScale.toArray()),this.displacementMap&&this.displacementMap.isTexture&&(n.displacementMap=this.displacementMap.toJSON(t).uuid,n.displacementScale=this.displacementScale,n.displacementBias=this.displacementBias),this.roughnessMap&&this.roughnessMap.isTexture&&(n.roughnessMap=this.roughnessMap.toJSON(t).uuid),this.metalnessMap&&this.metalnessMap.isTexture&&(n.metalnessMap=this.metalnessMap.toJSON(t).uuid),this.emissiveMap&&this.emissiveMap.isTexture&&(n.emissiveMap=this.emissiveMap.toJSON(t).uuid),this.specularMap&&this.specularMap.isTexture&&(n.specularMap=this.specularMap.toJSON(t).uuid),this.specularIntensityMap&&this.specularIntensityMap.isTexture&&(n.specularIntensityMap=this.specularIntensityMap.toJSON(t).uuid),this.specularColorMap&&this.specularColorMap.isTexture&&(n.specularColorMap=this.specularColorMap.toJSON(t).uuid),this.envMap&&this.envMap.isTexture&&(n.envMap=this.envMap.toJSON(t).uuid,this.combine!==void 0&&(n.combine=this.combine)),this.envMapRotation!==void 0&&(n.envMapRotation=this.envMapRotation.toArray()),this.envMapIntensity!==void 0&&(n.envMapIntensity=this.envMapIntensity),this.reflectivity!==void 0&&(n.reflectivity=this.reflectivity),this.refractionRatio!==void 0&&(n.refractionRatio=this.refractionRatio),this.gradientMap&&this.gradientMap.isTexture&&(n.gradientMap=this.gradientMap.toJSON(t).uuid),this.transmission!==void 0&&(n.transmission=this.transmission),this.transmissionMap&&this.transmissionMap.isTexture&&(n.transmissionMap=this.transmissionMap.toJSON(t).uuid),this.thickness!==void 0&&(n.thickness=this.thickness),this.thicknessMap&&this.thicknessMap.isTexture&&(n.thicknessMap=this.thicknessMap.toJSON(t).uuid),this.attenuationDistance!==void 0&&(n.attenuationDistance=this.attenuationDistance),this.attenuationColor!==void 0&&(n.attenuationColor=this.attenuationColor.getHex()),this.size!==void 0&&(n.size=this.size),this.sizeAttenuation!==void 0&&(n.sizeAttenuation=this.sizeAttenuation),Array.isArray(this.clippingPlanes)&&this.clippingPlanes.length>0&&(n.clippingPlanes=this.clippingPlanes.map(r=>r.toJSON())),this.rotation!==void 0&&(n.rotation=this.rotation),this.depthPacking!==void 0&&(n.depthPacking=this.depthPacking),this.linewidth!==void 0&&(n.linewidth=this.linewidth),this.linecap!==void 0&&(n.linecap=this.linecap),this.linejoin!==void 0&&(n.linejoin=this.linejoin),this.dashSize!==void 0&&(n.dashSize=this.dashSize),this.gapSize!==void 0&&(n.gapSize=this.gapSize),this.scale!==void 0&&(n.scale=this.scale),this.wireframe!==void 0&&(n.wireframe=this.wireframe),this.wireframeLinewidth!==void 0&&(n.wireframeLinewidth=this.wireframeLinewidth),this.wireframeLinecap!==void 0&&(n.wireframeLinecap=this.wireframeLinecap),this.wireframeLinejoin!==void 0&&(n.wireframeLinejoin=this.wireframeLinejoin),this.flatShading!==void 0&&(n.flatShading=this.flatShading),this.fog!==void 0&&(n.fog=this.fog),Object.keys(this.userData).length>0&&(n.userData=this.userData);function s(r){let a=[];for(let o in r){let l=r[o];delete l.metadata,a.push(l)}return a}if(e){let r=s(t.textures),a=s(t.images);r.length>0&&(n.textures=r),a.length>0&&(n.images=a)}return n}fromJSON(t,e){if(t.uuid!==void 0&&(this.uuid=t.uuid),t.name!==void 0&&(this.name=t.name),t.color!==void 0&&this.color!==void 0&&this.color.setHex(t.color),t.roughness!==void 0&&(this.roughness=t.roughness),t.metalness!==void 0&&(this.metalness=t.metalness),t.sheen!==void 0&&(this.sheen=t.sheen),t.sheenColor!==void 0&&(this.sheenColor=new se().setHex(t.sheenColor)),t.sheenRoughness!==void 0&&(this.sheenRoughness=t.sheenRoughness),t.emissive!==void 0&&this.emissive!==void 0&&this.emissive.setHex(t.emissive),t.specular!==void 0&&this.specular!==void 0&&this.specular.setHex(t.specular),t.specularIntensity!==void 0&&(this.specularIntensity=t.specularIntensity),t.specularColor!==void 0&&this.specularColor!==void 0&&this.specularColor.setHex(t.specularColor),t.shininess!==void 0&&(this.shininess=t.shininess),t.clearcoat!==void 0&&(this.clearcoat=t.clearcoat),t.clearcoatRoughness!==void 0&&(this.clearcoatRoughness=t.clearcoatRoughness),t.dispersion!==void 0&&(this.dispersion=t.dispersion),t.retroreflectivity!==void 0&&(this.retroreflectivity=t.retroreflectivity),t.iridescence!==void 0&&(this.iridescence=t.iridescence),t.iridescenceIOR!==void 0&&(this.iridescenceIOR=t.iridescenceIOR),t.iridescenceThicknessRange!==void 0&&(this.iridescenceThicknessRange=t.iridescenceThicknessRange),t.transmission!==void 0&&(this.transmission=t.transmission),t.thickness!==void 0&&(this.thickness=t.thickness),t.attenuationDistance!==void 0&&(this.attenuationDistance=t.attenuationDistance),t.attenuationColor!==void 0&&this.attenuationColor!==void 0&&this.attenuationColor.setHex(t.attenuationColor),t.anisotropy!==void 0&&(this.anisotropy=t.anisotropy),t.anisotropyRotation!==void 0&&(this.anisotropyRotation=t.anisotropyRotation),t.fog!==void 0&&(this.fog=t.fog),t.flatShading!==void 0&&(this.flatShading=t.flatShading),t.blending!==void 0&&(this.blending=t.blending),t.combine!==void 0&&(this.combine=t.combine),t.side!==void 0&&(this.side=t.side),t.shadowSide!==void 0&&(this.shadowSide=t.shadowSide),t.opacity!==void 0&&(this.opacity=t.opacity),t.transparent!==void 0&&(this.transparent=t.transparent),t.alphaTest!==void 0&&(this.alphaTest=t.alphaTest),t.alphaHash!==void 0&&(this.alphaHash=t.alphaHash),t.depthFunc!==void 0&&(this.depthFunc=t.depthFunc),t.depthTest!==void 0&&(this.depthTest=t.depthTest),t.depthWrite!==void 0&&(this.depthWrite=t.depthWrite),t.colorWrite!==void 0&&(this.colorWrite=t.colorWrite),t.clippingPlanes!==void 0&&(this.clippingPlanes=t.clippingPlanes.map(n=>new oi().fromJSON(n))),t.clipIntersection!==void 0&&(this.clipIntersection=t.clipIntersection),t.clipShadows!==void 0&&(this.clipShadows=t.clipShadows),t.depthPacking!==void 0&&(this.depthPacking=t.depthPacking),t.blendSrc!==void 0&&(this.blendSrc=t.blendSrc),t.blendDst!==void 0&&(this.blendDst=t.blendDst),t.blendEquation!==void 0&&(this.blendEquation=t.blendEquation),t.blendSrcAlpha!==void 0&&(this.blendSrcAlpha=t.blendSrcAlpha),t.blendDstAlpha!==void 0&&(this.blendDstAlpha=t.blendDstAlpha),t.blendEquationAlpha!==void 0&&(this.blendEquationAlpha=t.blendEquationAlpha),t.blendColor!==void 0&&this.blendColor!==void 0&&this.blendColor.setHex(t.blendColor),t.blendAlpha!==void 0&&(this.blendAlpha=t.blendAlpha),t.stencilWriteMask!==void 0&&(this.stencilWriteMask=t.stencilWriteMask),t.stencilFunc!==void 0&&(this.stencilFunc=t.stencilFunc),t.stencilRef!==void 0&&(this.stencilRef=t.stencilRef),t.stencilFuncMask!==void 0&&(this.stencilFuncMask=t.stencilFuncMask),t.stencilFail!==void 0&&(this.stencilFail=t.stencilFail),t.stencilZFail!==void 0&&(this.stencilZFail=t.stencilZFail),t.stencilZPass!==void 0&&(this.stencilZPass=t.stencilZPass),t.stencilWrite!==void 0&&(this.stencilWrite=t.stencilWrite),t.wireframe!==void 0&&(this.wireframe=t.wireframe),t.wireframeLinewidth!==void 0&&(this.wireframeLinewidth=t.wireframeLinewidth),t.wireframeLinecap!==void 0&&(this.wireframeLinecap=t.wireframeLinecap),t.wireframeLinejoin!==void 0&&(this.wireframeLinejoin=t.wireframeLinejoin),t.rotation!==void 0&&(this.rotation=t.rotation),t.linewidth!==void 0&&(this.linewidth=t.linewidth),t.linecap!==void 0&&(this.linecap=t.linecap),t.linejoin!==void 0&&(this.linejoin=t.linejoin),t.dashSize!==void 0&&(this.dashSize=t.dashSize),t.gapSize!==void 0&&(this.gapSize=t.gapSize),t.scale!==void 0&&(this.scale=t.scale),t.polygonOffset!==void 0&&(this.polygonOffset=t.polygonOffset),t.polygonOffsetFactor!==void 0&&(this.polygonOffsetFactor=t.polygonOffsetFactor),t.polygonOffsetUnits!==void 0&&(this.polygonOffsetUnits=t.polygonOffsetUnits),t.dithering!==void 0&&(this.dithering=t.dithering),t.alphaToCoverage!==void 0&&(this.alphaToCoverage=t.alphaToCoverage),t.premultipliedAlpha!==void 0&&(this.premultipliedAlpha=t.premultipliedAlpha),t.forceSinglePass!==void 0&&(this.forceSinglePass=t.forceSinglePass),t.allowOverride!==void 0&&(this.allowOverride=t.allowOverride),t.visible!==void 0&&(this.visible=t.visible),t.toneMapped!==void 0&&(this.toneMapped=t.toneMapped),t.userData!==void 0&&(this.userData=t.userData),t.vertexColors!==void 0&&(typeof t.vertexColors=="number"?this.vertexColors=t.vertexColors>0:this.vertexColors=t.vertexColors),t.size!==void 0&&(this.size=t.size),t.sizeAttenuation!==void 0&&(this.sizeAttenuation=t.sizeAttenuation),t.map!==void 0&&(this.map=e[t.map]||null),t.matcap!==void 0&&(this.matcap=e[t.matcap]||null),t.alphaMap!==void 0&&(this.alphaMap=e[t.alphaMap]||null),t.bumpMap!==void 0&&(this.bumpMap=e[t.bumpMap]||null),t.bumpScale!==void 0&&(this.bumpScale=t.bumpScale),t.normalMap!==void 0&&(this.normalMap=e[t.normalMap]||null),t.normalMapType!==void 0&&(this.normalMapType=t.normalMapType),t.normalScale!==void 0){let n=t.normalScale;Array.isArray(n)===!1&&(n=[n,n]),this.normalScale=new ft().fromArray(n)}return t.displacementMap!==void 0&&(this.displacementMap=e[t.displacementMap]||null),t.displacementScale!==void 0&&(this.displacementScale=t.displacementScale),t.displacementBias!==void 0&&(this.displacementBias=t.displacementBias),t.roughnessMap!==void 0&&(this.roughnessMap=e[t.roughnessMap]||null),t.metalnessMap!==void 0&&(this.metalnessMap=e[t.metalnessMap]||null),t.emissiveMap!==void 0&&(this.emissiveMap=e[t.emissiveMap]||null),t.emissiveIntensity!==void 0&&(this.emissiveIntensity=t.emissiveIntensity),t.specularMap!==void 0&&(this.specularMap=e[t.specularMap]||null),t.specularIntensityMap!==void 0&&(this.specularIntensityMap=e[t.specularIntensityMap]||null),t.specularColorMap!==void 0&&(this.specularColorMap=e[t.specularColorMap]||null),t.envMap!==void 0&&(this.envMap=e[t.envMap]||null),t.envMapRotation!==void 0&&this.envMapRotation.fromArray(t.envMapRotation),t.envMapIntensity!==void 0&&(this.envMapIntensity=t.envMapIntensity),t.reflectivity!==void 0&&(this.reflectivity=t.reflectivity),t.refractionRatio!==void 0&&(this.refractionRatio=t.refractionRatio),t.lightMap!==void 0&&(this.lightMap=e[t.lightMap]||null),t.lightMapIntensity!==void 0&&(this.lightMapIntensity=t.lightMapIntensity),t.aoMap!==void 0&&(this.aoMap=e[t.aoMap]||null),t.aoMapIntensity!==void 0&&(this.aoMapIntensity=t.aoMapIntensity),t.gradientMap!==void 0&&(this.gradientMap=e[t.gradientMap]||null),t.clearcoatMap!==void 0&&(this.clearcoatMap=e[t.clearcoatMap]||null),t.clearcoatRoughnessMap!==void 0&&(this.clearcoatRoughnessMap=e[t.clearcoatRoughnessMap]||null),t.clearcoatNormalMap!==void 0&&(this.clearcoatNormalMap=e[t.clearcoatNormalMap]||null),t.clearcoatNormalScale!==void 0&&(this.clearcoatNormalScale=new ft().fromArray(t.clearcoatNormalScale)),t.iridescenceMap!==void 0&&(this.iridescenceMap=e[t.iridescenceMap]||null),t.iridescenceThicknessMap!==void 0&&(this.iridescenceThicknessMap=e[t.iridescenceThicknessMap]||null),t.transmissionMap!==void 0&&(this.transmissionMap=e[t.transmissionMap]||null),t.thicknessMap!==void 0&&(this.thicknessMap=e[t.thicknessMap]||null),t.anisotropyMap!==void 0&&(this.anisotropyMap=e[t.anisotropyMap]||null),t.sheenColorMap!==void 0&&(this.sheenColorMap=e[t.sheenColorMap]||null),t.sheenRoughnessMap!==void 0&&(this.sheenRoughnessMap=e[t.sheenRoughnessMap]||null),this}clone(){return new this.constructor().copy(this)}copy(t){this.name=t.name,this.blending=t.blending,this.side=t.side,this.vertexColors=t.vertexColors,this.opacity=t.opacity,this.transparent=t.transparent,this.blendSrc=t.blendSrc,this.blendDst=t.blendDst,this.blendEquation=t.blendEquation,this.blendSrcAlpha=t.blendSrcAlpha,this.blendDstAlpha=t.blendDstAlpha,this.blendEquationAlpha=t.blendEquationAlpha,this.blendColor.copy(t.blendColor),this.blendAlpha=t.blendAlpha,this.depthFunc=t.depthFunc,this.depthTest=t.depthTest,this.depthWrite=t.depthWrite,this.stencilWriteMask=t.stencilWriteMask,this.stencilFunc=t.stencilFunc,this.stencilRef=t.stencilRef,this.stencilFuncMask=t.stencilFuncMask,this.stencilFail=t.stencilFail,this.stencilZFail=t.stencilZFail,this.stencilZPass=t.stencilZPass,this.stencilWrite=t.stencilWrite;let e=t.clippingPlanes,n=null;if(e!==null){let s=e.length;n=new Array(s);for(let r=0;r!==s;++r)n[r]=e[r].clone()}return this.clippingPlanes=n,this.clipIntersection=t.clipIntersection,this.clipShadows=t.clipShadows,this.shadowSide=t.shadowSide,this.colorWrite=t.colorWrite,this.precision=t.precision,this.polygonOffset=t.polygonOffset,this.polygonOffsetFactor=t.polygonOffsetFactor,this.polygonOffsetUnits=t.polygonOffsetUnits,this.dithering=t.dithering,this.alphaTest=t.alphaTest,this.alphaHash=t.alphaHash,this.alphaToCoverage=t.alphaToCoverage,this.premultipliedAlpha=t.premultipliedAlpha,this.forceSinglePass=t.forceSinglePass,this.allowOverride=t.allowOverride,this.visible=t.visible,this.toneMapped=t.toneMapped,this.userData=JSON.parse(JSON.stringify(t.userData)),this}dispose(){this.dispatchEvent({type:"dispose"})}set needsUpdate(t){t===!0&&this.version++}},Gi=class extends ci{constructor(t){super(),this.isSpriteMaterial=!0,this.type="SpriteMaterial",this.color=new se(16777215),this.map=null,this.alphaMap=null,this.rotation=0,this.sizeAttenuation=!0,this.transparent=!0,this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.color.copy(t.color),this.map=t.map,this.alphaMap=t.alphaMap,this.rotation=t.rotation,this.sizeAttenuation=t.sizeAttenuation,this.fog=t.fog,this}},Zs,jr=new P,Js=new P,Ks=new P,js=new ft,Qr=new ft,rf=new De,Ao=new P,ta=new P,Ro=new P,Yh=new ft,u0=new ft,$h=new ft,is=class extends rn{constructor(t=new Gi){if(super(),this.isSprite=!0,this.type="Sprite",Zs===void 0){Zs=new Ie;let e=new Float32Array([-.5,-.5,0,0,0,.5,-.5,0,1,0,.5,.5,0,1,1,-.5,.5,0,0,1]),n=new ma(e,5);Zs.setIndex([0,1,2,0,2,3]),Zs.setAttribute("position",new fr(n,3,0,!1)),Zs.setAttribute("uv",new fr(n,2,3,!1))}this.geometry=Zs,this.material=t,this.center=new ft(.5,.5),this.count=1}intersectsFrustum(t){return t.intersectsSprite(this)}raycast(t,e){t.camera===null&&he('Sprite: "Raycaster.camera" needs to be set in order to raycast against sprites.'),Js.setFromMatrixScale(this.matrixWorld),rf.copy(t.camera.matrixWorld),this.modelViewMatrix.multiplyMatrices(t.camera.matrixWorldInverse,this.matrixWorld),Ks.setFromMatrixPosition(this.modelViewMatrix),t.camera.isPerspectiveCamera&&this.material.sizeAttenuation===!1&&Js.multiplyScalar(-Ks.z);let n=this.material.rotation,s,r;n!==0&&(r=Math.cos(n),s=Math.sin(n));let a=this.center;Co(Ao.set(-.5,-.5,0),Ks,a,Js,s,r),Co(ta.set(.5,-.5,0),Ks,a,Js,s,r),Co(Ro.set(.5,.5,0),Ks,a,Js,s,r),Yh.set(0,0),u0.set(1,0),$h.set(1,1);let o=t.ray.intersectTriangle(Ao,ta,Ro,!1,jr);if(o===null&&(Co(ta.set(-.5,.5,0),Ks,a,Js,s,r),u0.set(0,1),o=t.ray.intersectTriangle(Ao,Ro,ta,!1,jr),o===null))return;let l=t.ray.origin.distanceTo(jr);l<t.near||l>t.far||e.push({distance:l,point:jr.clone(),uv:zi.getInterpolation(jr,Ao,ta,Ro,Yh,u0,$h,new ft),face:null,object:this})}copy(t,e){return super.copy(t,e),t.center!==void 0&&this.center.copy(t.center),this.material=t.material,this}};function Co(i,t,e,n,s,r){js.subVectors(i,e).addScalar(.5).multiply(n),s!==void 0?(Qr.x=r*js.x-s*js.y,Qr.y=s*js.x+r*js.y):Qr.copy(js),i.copy(t),i.x+=Qr.x,i.y+=Qr.y,i.applyMatrix4(rf)}var Po=new P,Zh=new P,ga=class extends rn{constructor(){super(),this.isLOD=!0,this._currentLevel=0,this.type="LOD",Object.defineProperties(this,{levels:{enumerable:!0,value:[]}}),this.autoUpdate=!0}copy(t){super.copy(t,!1);let e=t.levels;for(let n=0,s=e.length;n<s;n++){let r=e[n];this.addLevel(r.object.clone(),r.distance,r.hysteresis)}return this.autoUpdate=t.autoUpdate,this}addLevel(t,e=0,n=0){e=Math.abs(e);let s=this.levels,r;for(r=0;r<s.length&&!(e<s[r].distance);r++);return s.splice(r,0,{distance:e,hysteresis:n,object:t}),this.add(t),this}removeLevel(t){let e=this.levels;for(let n=0;n<e.length;n++)if(e[n].distance===t){let s=e.splice(n,1);return this.remove(s[0].object),!0}return!1}getCurrentLevel(){return this._currentLevel}getObjectForDistance(t){let e=this.levels;if(e.length>0){let n,s;for(n=1,s=e.length;n<s;n++){let r=e[n].distance;if(e[n].object.visible&&(r-=r*e[n].hysteresis),t<r)break}return e[n-1].object}return null}raycast(t,e){if(this.levels.length>0){Po.setFromMatrixPosition(this.matrixWorld);let s=t.ray.origin.distanceTo(Po);this.getObjectForDistance(s).raycast(t,e)}}update(t){let e=this.levels;if(e.length>1){Po.setFromMatrixPosition(t.matrixWorld),Zh.setFromMatrixPosition(this.matrixWorld);let n=Po.distanceTo(Zh)/t.zoom;e[0].object.visible=!0;let s,r;for(s=1,r=e.length;s<r;s++){let a=e[s].distance;if(e[s].object.visible&&(a-=a*e[s].hysteresis),n>=a)e[s-1].object.visible=!1,e[s].object.visible=!0;else break}for(this._currentLevel=s-1;s<r;s++)e[s].object.visible=!1}}toJSON(t){let e=super.toJSON(t);e.object.autoUpdate=this.autoUpdate,e.object.levels=[];let n=this.levels;for(let s=0,r=n.length;s<r;s++){let a=n[s];e.object.levels.push({object:a.object.uuid,distance:a.distance,hysteresis:a.hysteresis})}return e}},Bi=new P,f0=new P,Io=new P,Lo=new P,Ts=class{constructor(t=new P,e=new P(0,0,-1)){this.origin=t,this.direction=e}set(t,e){return this.origin.copy(t),this.direction.copy(e),this}copy(t){return this.origin.copy(t.origin),this.direction.copy(t.direction),this}at(t,e){return e.copy(this.origin).addScaledVector(this.direction,t)}lookAt(t){return this.direction.copy(t).sub(this.origin).normalize(),this}recast(t){return this.origin.copy(this.at(t,Bi)),this}closestPointToPoint(t,e){e.subVectors(t,this.origin);let n=e.dot(this.direction);return n<0?e.copy(this.origin):e.copy(this.origin).addScaledVector(this.direction,n)}distanceToPoint(t){return Math.sqrt(this.distanceSqToPoint(t))}distanceSqToPoint(t){let e=Bi.subVectors(t,this.origin).dot(this.direction);return e<0?this.origin.distanceToSquared(t):(Bi.copy(this.origin).addScaledVector(this.direction,e),Bi.distanceToSquared(t))}distanceSqToSegment(t,e,n,s){f0.copy(t).add(e).multiplyScalar(.5),Io.copy(e).sub(t).normalize(),Lo.copy(this.origin).sub(f0);let r=t.distanceTo(e)*.5,a=-this.direction.dot(Io),o=Lo.dot(this.direction),l=-Lo.dot(Io),c=Lo.lengthSq(),h=Math.abs(1-a*a),f,u,d,g;if(h>0)if(f=a*l-o,u=a*o-l,g=r*h,f>=0)if(u>=-g)if(u<=g){let _=1/h;f*=_,u*=_,d=f*(f+a*u+2*o)+u*(a*f+u+2*l)+c}else u=r,f=Math.max(0,-(a*u+o)),d=-f*f+u*(u+2*l)+c;else u=-r,f=Math.max(0,-(a*u+o)),d=-f*f+u*(u+2*l)+c;else u<=-g?(f=Math.max(0,-(-a*r+o)),u=f>0?-r:Math.min(Math.max(-r,-l),r),d=-f*f+u*(u+2*l)+c):u<=g?(f=0,u=Math.min(Math.max(-r,-l),r),d=u*(u+2*l)+c):(f=Math.max(0,-(a*r+o)),u=f>0?r:Math.min(Math.max(-r,-l),r),d=-f*f+u*(u+2*l)+c);else u=a>0?-r:r,f=Math.max(0,-(a*u+o)),d=-f*f+u*(u+2*l)+c;return n&&n.copy(this.origin).addScaledVector(this.direction,f),s&&s.copy(f0).addScaledVector(Io,u),d}intersectSphere(t,e){if(t.radius<0)return null;Bi.subVectors(t.center,this.origin);let n=Bi.dot(this.direction),s=Bi.dot(Bi)-n*n,r=t.radius*t.radius;if(s>r)return null;let a=Math.sqrt(r-s),o=n-a,l=n+a;return l<0?null:o<0?this.at(l,e):this.at(o,e)}intersectsSphere(t){return t.radius<0?!1:this.distanceSqToPoint(t.center)<=t.radius*t.radius}distanceToPlane(t){let e=t.normal.dot(this.direction);if(e===0)return t.distanceToPoint(this.origin)===0?0:null;let n=-(this.origin.dot(t.normal)+t.constant)/e;return n>=0?n:null}intersectPlane(t,e){let n=this.distanceToPlane(t);return n===null?null:this.at(n,e)}intersectsPlane(t){let e=t.distanceToPoint(this.origin);return e===0||t.normal.dot(this.direction)*e<0}intersectBox(t,e){let n,s,r,a,o,l,c=1/this.direction.x,h=1/this.direction.y,f=1/this.direction.z,u=this.origin;return c>=0?(n=(t.min.x-u.x)*c,s=(t.max.x-u.x)*c):(n=(t.max.x-u.x)*c,s=(t.min.x-u.x)*c),h>=0?(r=(t.min.y-u.y)*h,a=(t.max.y-u.y)*h):(r=(t.max.y-u.y)*h,a=(t.min.y-u.y)*h),n>a||r>s||((r>n||isNaN(n))&&(n=r),(a<s||isNaN(s))&&(s=a),f>=0?(o=(t.min.z-u.z)*f,l=(t.max.z-u.z)*f):(o=(t.max.z-u.z)*f,l=(t.min.z-u.z)*f),n>l||o>s)||((o>n||n!==n)&&(n=o),(l<s||s!==s)&&(s=l),s<0)?null:this.at(n>=0?n:s,e)}intersectsBox(t){return this.intersectBox(t,Bi)!==null}intersectTriangle(t,e,n,s,r){let a=this.origin,o=this.direction,l=o.x,c=o.y,h=o.z,f=t.x-a.x,u=t.y-a.y,d=t.z-a.z,g=e.x-a.x,_=e.y-a.y,m=e.z-a.z,p=n.x-a.x,S=n.y-a.y,A=n.z-a.z,v=Math.abs(l),b=Math.abs(c),E=Math.abs(h),C,y,w,I,N,H,W,U,G,rt,j,pt;if(v>=b&&v>=E?(w=l,H=f,G=g,pt=p,l>=0?(C=c,y=h,I=u,N=d,W=_,U=m,rt=S,j=A):(C=h,y=c,I=d,N=u,W=m,U=_,rt=A,j=S)):b>=E?(w=c,H=u,G=_,pt=S,c>=0?(C=h,y=l,I=d,N=f,W=m,U=g,rt=A,j=p):(C=l,y=h,I=f,N=d,W=g,U=m,rt=p,j=A)):(w=h,H=d,G=m,pt=A,h>=0?(C=l,y=c,I=f,N=u,W=g,U=_,rt=p,j=S):(C=c,y=l,I=u,N=f,W=_,U=g,rt=S,j=p)),w===0)return null;let st=C/w,lt=y/w,O=1/w,vt=I-st*H,St=N-lt*H,Et=W-st*G,Xt=U-lt*G,gt=rt-st*pt,J=j-lt*pt,q=gt*Xt-J*Et,ht=vt*J-St*gt,wt=Et*St-Xt*vt;if(s){if(q<0||ht<0||wt<0)return null}else if((q<0||ht<0||wt<0)&&(q>0||ht>0||wt>0))return null;let ct=q+ht+wt;if(ct===0)return null;let Ft=O*(q*H+ht*G+wt*pt);return(ct>0?Ft<0:Ft>0)?null:this.at(Ft/ct,r)}applyMatrix4(t){return this.origin.applyMatrix4(t),this.direction.transformDirection(t),this}equals(t){return t.origin.equals(this.origin)&&t.direction.equals(this.direction)}clone(){return new this.constructor().copy(this)}},an=class extends ci{constructor(t){super(),this.isMeshBasicMaterial=!0,this.type="MeshBasicMaterial",this.color=new se(16777215),this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.specularMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new Vi,this.combine=B0,this.reflectivity=1,this.refractionRatio=.98,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.color.copy(t.color),this.map=t.map,this.lightMap=t.lightMap,this.lightMapIntensity=t.lightMapIntensity,this.aoMap=t.aoMap,this.aoMapIntensity=t.aoMapIntensity,this.specularMap=t.specularMap,this.alphaMap=t.alphaMap,this.envMap=t.envMap,this.envMapRotation.copy(t.envMapRotation),this.combine=t.combine,this.reflectivity=t.reflectivity,this.refractionRatio=t.refractionRatio,this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this.wireframeLinecap=t.wireframeLinecap,this.wireframeLinejoin=t.wireframeLinejoin,this.fog=t.fog,this}},Jh=new De,Ss=new Ts,Do=new Jn,Kh=new P,No=new P,Uo=new P,Fo=new P,d0=new P,Oo=new P,jh=new P,Bo=new P,Se=class extends rn{constructor(t=new Ie,e=new an){super(),this.isMesh=!0,this.type="Mesh",this.geometry=t,this.material=e,this.morphTargetDictionary=void 0,this.morphTargetInfluences=void 0,this.count=1,this.updateMorphTargets()}copy(t,e){return super.copy(t,e),t.morphTargetInfluences!==void 0&&(this.morphTargetInfluences=t.morphTargetInfluences.slice()),t.morphTargetDictionary!==void 0&&(this.morphTargetDictionary=Object.assign({},t.morphTargetDictionary)),this.material=Array.isArray(t.material)?t.material.slice():t.material,this.geometry=t.geometry,this}updateMorphTargets(){let e=this.geometry.morphAttributes,n=Object.keys(e);if(n.length>0){let s=e[n[0]];if(s!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let r=0,a=s.length;r<a;r++){let o=s[r].name||String(r);this.morphTargetInfluences.push(0),this.morphTargetDictionary[o]=r}}}}getVertexPosition(t,e){let n=this.geometry,s=n.attributes.position,r=n.morphAttributes.position,a=n.morphTargetsRelative;e.fromBufferAttribute(s,t);let o=this.morphTargetInfluences;if(r&&o){Oo.set(0,0,0);for(let l=0,c=r.length;l<c;l++){let h=o[l],f=r[l];h!==0&&(d0.fromBufferAttribute(f,t),a?Oo.addScaledVector(d0,h):Oo.addScaledVector(d0.sub(e),h))}e.add(Oo)}return e}intersectsFrustum(t){return t.intersectsObject(this)}raycast(t,e){let n=this.geometry,s=this.material,r=this.matrixWorld;s!==void 0&&(n.boundingSphere===null&&n.computeBoundingSphere(),Do.copy(n.boundingSphere),Do.applyMatrix4(r),Ss.copy(t.ray).recast(t.near),!(Do.containsPoint(Ss.origin)===!1&&(Ss.intersectSphere(Do,Kh)===null||Ss.origin.distanceToSquared(Kh)>(t.far-t.near)**2))&&(Jh.copy(r).invert(),Ss.copy(t.ray).applyMatrix4(Jh),!(n.boundingBox!==null&&Ss.intersectsBox(n.boundingBox)===!1)&&this._computeIntersections(t,e,Ss)))}_computeIntersections(t,e,n){let s,r=this.geometry,a=this.material,o=r.index,l=r.attributes.position,c=r.attributes.uv,h=r.attributes.uv1,f=r.attributes.normal,u=r.groups,d=r.drawRange;if(o!==null)if(Array.isArray(a))for(let g=0,_=u.length;g<_;g++){let m=u[g],p=a[m.materialIndex],S=Math.max(m.start,d.start),A=Math.min(o.count,Math.min(m.start+m.count,d.start+d.count));for(let v=S,b=A;v<b;v+=3){let E=o.getX(v),C=o.getX(v+1),y=o.getX(v+2);s=zo(this,p,t,n,c,h,f,E,C,y),s&&(s.faceIndex=Math.floor(v/3),s.face.materialIndex=m.materialIndex,e.push(s))}}else{let g=Math.max(0,d.start),_=Math.min(o.count,d.start+d.count);for(let m=g,p=_;m<p;m+=3){let S=o.getX(m),A=o.getX(m+1),v=o.getX(m+2);s=zo(this,a,t,n,c,h,f,S,A,v),s&&(s.faceIndex=Math.floor(m/3),e.push(s))}}else if(l!==void 0)if(Array.isArray(a))for(let g=0,_=u.length;g<_;g++){let m=u[g],p=a[m.materialIndex],S=Math.max(m.start,d.start),A=Math.min(l.count,Math.min(m.start+m.count,d.start+d.count));for(let v=S,b=A;v<b;v+=3){let E=v,C=v+1,y=v+2;s=zo(this,p,t,n,c,h,f,E,C,y),s&&(s.faceIndex=Math.floor(v/3),s.face.materialIndex=m.materialIndex,e.push(s))}}else{let g=Math.max(0,d.start),_=Math.min(l.count,d.start+d.count);for(let m=g,p=_;m<p;m+=3){let S=m,A=m+1,v=m+2;s=zo(this,a,t,n,c,h,f,S,A,v),s&&(s.faceIndex=Math.floor(m/3),e.push(s))}}}};function Cd(i,t,e,n,s,r,a,o){let l;if(t.side===bn?l=n.intersectTriangle(a,r,s,!0,o):l=n.intersectTriangle(s,r,a,t.side===hs,o),l===null)return null;Bo.copy(o),Bo.applyMatrix4(i.matrixWorld);let c=e.ray.origin.distanceTo(Bo);return c<e.near||c>e.far?null:{distance:c,point:Bo.clone(),object:i}}function zo(i,t,e,n,s,r,a,o,l,c){i.getVertexPosition(o,No),i.getVertexPosition(l,Uo),i.getVertexPosition(c,Fo);let h=Cd(i,t,e,n,No,Uo,Fo,jh);if(h){let f=new P;zi.getBarycoord(jh,No,Uo,Fo,f),s&&(h.uv=zi.getInterpolatedAttribute(s,o,l,c,f,new ft)),r&&(h.uv1=zi.getInterpolatedAttribute(r,o,l,c,f,new ft)),a&&(h.normal=zi.getInterpolatedAttribute(a,o,l,c,f,new P),h.normal.dot(n.direction)>0&&h.normal.multiplyScalar(-1));let u={a:o,b:l,c,normal:new P,materialIndex:0};zi.getNormal(No,Uo,Fo,u.normal),h.face=u,h.barycoord=f}return h}var xa=class extends xn{constructor(t=null,e=1,n=1,s,r,a,o,l,c=gn,h=gn,f,u){super(null,a,o,l,c,h,s,r,f,u),this.isDataTexture=!0,this.image={data:t,width:e,height:n},this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}};var dr=class extends sn{constructor(t,e,n,s=1){super(t,e,n),this.isInstancedBufferAttribute=!0,this.meshPerAttribute=s}copy(t){return super.copy(t),this.meshPerAttribute=t.meshPerAttribute,this}toJSON(){let t=super.toJSON();return t.meshPerAttribute=this.meshPerAttribute,t.isInstancedBufferAttribute=!0,t}},Qs=new De,Qh=new De,ko=[],tu=new Ei,Pd=new De,ea=new Se,na=new Jn,_a=class extends Se{constructor(t,e,n){super(t,e),this.isInstancedMesh=!0,this.instanceMatrix=new dr(new Float32Array(n*16),16),this.instanceColor=null,this.morphTexture=null,this.count=n,this.boundingBox=null,this.boundingSphere=null;for(let s=0;s<n;s++)this.setMatrixAt(s,Pd)}computeBoundingBox(){let t=this.geometry,e=this.count;this.boundingBox===null&&(this.boundingBox=new Ei),t.boundingBox===null&&t.computeBoundingBox(),this.boundingBox.makeEmpty();for(let n=0;n<e;n++)this.getMatrixAt(n,Qs),tu.copy(t.boundingBox).applyMatrix4(Qs),this.boundingBox.union(tu)}computeBoundingSphere(){let t=this.geometry,e=this.count;this.boundingSphere===null&&(this.boundingSphere=new Jn),t.boundingSphere===null&&t.computeBoundingSphere(),this.boundingSphere.makeEmpty();for(let n=0;n<e;n++)this.getMatrixAt(n,Qs),na.copy(t.boundingSphere).applyMatrix4(Qs),this.boundingSphere.union(na)}copy(t,e){return super.copy(t,e),this.instanceMatrix.copy(t.instanceMatrix),t.morphTexture!==null&&(this.morphTexture=t.morphTexture.clone()),t.instanceColor!==null&&(this.instanceColor=t.instanceColor.clone()),this.count=t.count,t.boundingBox!==null&&(this.boundingBox=t.boundingBox.clone()),t.boundingSphere!==null&&(this.boundingSphere=t.boundingSphere.clone()),this}getColorAt(t,e){return this.instanceColor===null?e.setRGB(1,1,1):e.fromArray(this.instanceColor.array,t*3)}getMatrixAt(t,e){return e.fromArray(this.instanceMatrix.array,t*16)}getMorphAt(t,e){let n=e.morphTargetInfluences,s=this.morphTexture.source.data.data,r=n.length+1,a=t*r+1;for(let o=0;o<n.length;o++)n[o]=s[a+o]}raycast(t,e){let n=this.matrixWorld,s=this.count;if(ea.geometry=this.geometry,ea.material=this.material,ea.material!==void 0&&(this.boundingSphere===null&&this.computeBoundingSphere(),na.copy(this.boundingSphere),na.applyMatrix4(n),t.ray.intersectsSphere(na)!==!1))for(let r=0;r<s;r++){this.getMatrixAt(r,Qs),Qh.multiplyMatrices(n,Qs),ea.matrixWorld=Qh,ea.raycast(t,ko);for(let a=0,o=ko.length;a<o;a++){let l=ko[a];l.instanceId=r,l.object=this,e.push(l)}ko.length=0}}setColorAt(t,e){return this.instanceColor===null&&(this.instanceColor=new dr(new Float32Array(this.instanceMatrix.count*3).fill(1),3)),e.toArray(this.instanceColor.array,t*3),this}setMatrixAt(t,e){return e.toArray(this.instanceMatrix.array,t*16),this}setMorphAt(t,e){let n=e.morphTargetInfluences,s=n.length+1;this.morphTexture===null&&(this.morphTexture=new xa(new Float32Array(s*this.count),s,this.count,zl,ti));let r=this.morphTexture.source.data.data,a=0;for(let c=0;c<n.length;c++)a+=n[c];let o=this.geometry.morphTargetsRelative?1:1-a,l=s*t;return r[l]=o,r.set(n,l+1),this}updateMorphTargets(){}dispose(){super.dispose(),this.morphTexture!==null&&(this.morphTexture.dispose(),this.morphTexture=null)}},bs=new Jn,Id=new ft(.5,.5),Ho=new P,pr=class{constructor(t=new oi,e=new oi,n=new oi,s=new oi,r=new oi,a=new oi){this.planes=[t,e,n,s,r,a]}set(t,e,n,s,r,a){let o=this.planes;return o[0].copy(t),o[1].copy(e),o[2].copy(n),o[3].copy(s),o[4].copy(r),o[5].copy(a),this}copy(t){let e=this.planes;for(let n=0;n<6;n++)e[n].copy(t.planes[n]);return this}setFromProjectionMatrix(t,e=li,n=!1){let s=this.planes,r=t.elements,a=r[0],o=r[1],l=r[2],c=r[3],h=r[4],f=r[5],u=r[6],d=r[7],g=r[8],_=r[9],m=r[10],p=r[11],S=r[12],A=r[13],v=r[14],b=r[15];if(s[0].setComponents(c-a,d-h,p-g,b-S).normalize(),s[1].setComponents(c+a,d+h,p+g,b+S).normalize(),s[2].setComponents(c+o,d+f,p+_,b+A).normalize(),s[3].setComponents(c-o,d-f,p-_,b-A).normalize(),n)s[4].setComponents(l,u,m,v).normalize(),s[5].setComponents(c-l,d-u,p-m,b-v).normalize();else if(s[4].setComponents(c-l,d-u,p-m,b-v).normalize(),e===li)s[5].setComponents(c+l,d+u,p+m,b+v).normalize();else if(e===ar)s[5].setComponents(l,u,m,v).normalize();else throw new Error("THREE.Frustum.setFromProjectionMatrix(): Invalid coordinate system: "+e);return this}intersectsObject(t){if(t.boundingSphere!==void 0)t.boundingSphere===null&&t.computeBoundingSphere(),bs.copy(t.boundingSphere).applyMatrix4(t.matrixWorld);else{let e=t.geometry;e.boundingSphere===null&&e.computeBoundingSphere(),bs.copy(e.boundingSphere).applyMatrix4(t.matrixWorld)}return this.intersectsSphere(bs)}intersectsSprite(t){bs.center.set(0,0,0);let e=Id.distanceTo(t.center);return bs.radius=.7071067811865476+e,bs.applyMatrix4(t.matrixWorld),this.intersectsSphere(bs)}intersectsSphere(t){let e=this.planes,n=t.center,s=-t.radius;for(let r=0;r<6;r++)if(e[r].distanceToPoint(n)<s)return!1;return!0}intersectsBox(t){let e=this.planes;for(let n=0;n<6;n++){let s=e[n];if(Ho.x=s.normal.x>0?t.max.x:t.min.x,Ho.y=s.normal.y>0?t.max.y:t.min.y,Ho.z=s.normal.z>0?t.max.z:t.min.z,s.distanceToPoint(Ho)<0)return!1}return!0}containsPoint(t){let e=this.planes;for(let n=0;n<6;n++)if(e[n].distanceToPoint(t)<0)return!1;return!0}clone(){return new this.constructor().copy(this)}};var hi=class extends ci{constructor(t){super(),this.isLineBasicMaterial=!0,this.type="LineBasicMaterial",this.color=new se(16777215),this.map=null,this.linewidth=1,this.linecap="round",this.linejoin="round",this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.color.copy(t.color),this.map=t.map,this.linewidth=t.linewidth,this.linecap=t.linecap,this.linejoin=t.linejoin,this.fog=t.fog,this}},fl=new P,dl=new P,eu=new De,ia=new Ts,Vo=new Jn,p0=new P,nu=new P,Wi=class extends rn{constructor(t=new Ie,e=new hi){super(),this.isLine=!0,this.type="Line",this.geometry=t,this.material=e,this.morphTargetDictionary=void 0,this.morphTargetInfluences=void 0,this.updateMorphTargets()}copy(t,e){return super.copy(t,e),this.material=Array.isArray(t.material)?t.material.slice():t.material,this.geometry=t.geometry,this}computeLineDistances(){let t=this.geometry;if(t.index===null){let e=t.attributes.position,n=[0];for(let s=1,r=e.count;s<r;s++)fl.fromBufferAttribute(e,s-1),dl.fromBufferAttribute(e,s),n[s]=n[s-1],n[s]+=fl.distanceTo(dl);t.setAttribute("lineDistance",new pe(n,1))}else ue("Line.computeLineDistances(): Computation only possible with non-indexed BufferGeometry.");return this}intersectsFrustum(t){return t.intersectsObject(this)}raycast(t,e){let n=this.geometry,s=this.matrixWorld,r=t.params.Line.threshold,a=n.drawRange;if(n.boundingSphere===null&&n.computeBoundingSphere(),Vo.copy(n.boundingSphere),Vo.applyMatrix4(s),Vo.radius+=r,t.ray.intersectsSphere(Vo)===!1)return;eu.copy(s).invert(),ia.copy(t.ray).applyMatrix4(eu);let o=r/((this.scale.x+this.scale.y+this.scale.z)/3),l=o*o,c=this.isLineSegments?2:1,h=n.index,u=n.attributes.position;if(h!==null){let d=Math.max(0,a.start),g=Math.min(h.count,a.start+a.count);for(let _=d,m=g-1;_<m;_+=c){let p=h.getX(_),S=h.getX(_+1),A=Go(this,t,ia,l,p,S,_);A&&e.push(A)}if(this.isLineLoop){let _=h.getX(g-1),m=h.getX(d),p=Go(this,t,ia,l,_,m,g-1);p&&e.push(p)}}else{let d=Math.max(0,a.start),g=Math.min(u.count,a.start+a.count);for(let _=d,m=g-1;_<m;_+=c){let p=Go(this,t,ia,l,_,_+1,_);p&&e.push(p)}if(this.isLineLoop){let _=Go(this,t,ia,l,g-1,d,g-1);_&&e.push(_)}}}updateMorphTargets(){let e=this.geometry.morphAttributes,n=Object.keys(e);if(n.length>0){let s=e[n[0]];if(s!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let r=0,a=s.length;r<a;r++){let o=s[r].name||String(r);this.morphTargetInfluences.push(0),this.morphTargetDictionary[o]=r}}}}};function Go(i,t,e,n,s,r,a){let o=i.geometry.attributes.position;if(fl.fromBufferAttribute(o,s),dl.fromBufferAttribute(o,r),e.distanceSqToSegment(fl,dl,p0,nu)>n)return;p0.applyMatrix4(i.matrixWorld);let c=t.ray.origin.distanceTo(p0);if(!(c<t.near||c>t.far))return{distance:c,point:nu.clone().applyMatrix4(i.matrixWorld),index:a,face:null,faceIndex:null,barycoord:null,object:i}}var pl=class extends ci{constructor(t){super(),this.isPointsMaterial=!0,this.type="PointsMaterial",this.color=new se(16777215),this.map=null,this.alphaMap=null,this.size=1,this.sizeAttenuation=!0,this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.color.copy(t.color),this.map=t.map,this.alphaMap=t.alphaMap,this.size=t.size,this.sizeAttenuation=t.sizeAttenuation,this.fog=t.fog,this}},iu=new De,E0=new Ts,Wo=new Jn,Xo=new P,va=class extends rn{constructor(t=new Ie,e=new pl){super(),this.isPoints=!0,this.type="Points",this.geometry=t,this.material=e,this.morphTargetDictionary=void 0,this.morphTargetInfluences=void 0,this.updateMorphTargets()}copy(t,e){return super.copy(t,e),this.material=Array.isArray(t.material)?t.material.slice():t.material,this.geometry=t.geometry,this}intersectsFrustum(t){return t.intersectsObject(this)}raycast(t,e){let n=this.geometry,s=this.matrixWorld,r=t.params.Points.threshold,a=n.drawRange;if(n.boundingSphere===null&&n.computeBoundingSphere(),Wo.copy(n.boundingSphere),Wo.applyMatrix4(s),Wo.radius+=r,t.ray.intersectsSphere(Wo)===!1)return;iu.copy(s).invert(),E0.copy(t.ray).applyMatrix4(iu);let o=r/((this.scale.x+this.scale.y+this.scale.z)/3),l=o*o,c=n.index,f=n.attributes.position;if(c!==null){let u=Math.max(0,a.start),d=Math.min(c.count,a.start+a.count);for(let g=u,_=d;g<_;g++){let m=c.getX(g);Xo.fromBufferAttribute(f,m),su(Xo,m,l,s,t,e,this)}}else{let u=Math.max(0,a.start),d=Math.min(f.count,a.start+a.count);for(let g=u,_=d;g<_;g++)Xo.fromBufferAttribute(f,g),su(Xo,g,l,s,t,e,this)}}updateMorphTargets(){let e=this.geometry.morphAttributes,n=Object.keys(e);if(n.length>0){let s=e[n[0]];if(s!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let r=0,a=s.length;r<a;r++){let o=s[r].name||String(r);this.morphTargetInfluences.push(0),this.morphTargetDictionary[o]=r}}}}};function su(i,t,e,n,s,r,a){let o=E0.distanceSqToPoint(i);if(o<e){let l=new P;E0.closestPointToPoint(i,l),l.applyMatrix4(n);let c=s.ray.origin.distanceTo(l);if(c<s.near||c>s.far)return;r.push({distance:c,distanceToRay:Math.sqrt(o),point:l,index:t,face:null,faceIndex:null,barycoord:null,object:a})}}var ya=class extends xn{constructor(t=[],e=fs,n,s,r,a,o,l,c,h){super(t,e,n,s,r,a,o,l,c,h),this.isCubeTexture=!0,this.flipY=!1}get images(){return this.image}set images(t){this.image=t}},Kn=class extends xn{constructor(t,e,n,s,r,a,o,l,c){super(t,e,n,s,r,a,o,l,c),this.isCanvasTexture=!0,this.needsUpdate=!0}};var ss=class extends xn{constructor(t,e,n=fi,s,r,a,o=gn,l=gn,c,h=Mi,f=1){if(h!==Mi&&h!==ds)throw new Error("THREE.DepthTexture: format must be either THREE.DepthFormat or THREE.DepthStencilFormat");let u={width:t,height:e,depth:f};super(u,s,r,a,o,l,h,n,c),this.isDepthTexture=!0,this.flipY=!1,this.generateMipmaps=!1,this.compareFunction=null}copy(t){return super.copy(t),this.source=new cr(Object.assign({},t.image)),this.compareFunction=t.compareFunction,this}toJSON(t){let e=super.toJSON(t);return e.compareFunction=this.compareFunction,e}},ml=class extends ss{constructor(t,e=fi,n=fs,s,r,a=gn,o=gn,l,c=Mi){let h={width:t,height:t,depth:1},f=[h,h,h,h,h,h];super(t,t,e,n,s,r,a,o,l,c),this.image=f,this.isCubeDepthTexture=!0,this.isCubeTexture=!0}get images(){return this.image}set images(t){this.image=t}},Ma=class extends xn{constructor(t=null){super(),this.sourceTexture=t,this.isExternalTexture=!0}copy(t){return super.copy(t),this.sourceTexture=t.sourceTexture,this}},mr=class i extends Ie{constructor(t=1,e=1,n=1,s=1,r=1,a=1){super(),this.type="BoxGeometry",this.parameters={width:t,height:e,depth:n,widthSegments:s,heightSegments:r,depthSegments:a};let o=this;s=Math.floor(s),r=Math.floor(r),a=Math.floor(a);let l=[],c=[],h=[],f=[],u=0,d=0;g("z","y","x",-1,-1,n,e,t,a,r,0),g("z","y","x",1,-1,n,e,-t,a,r,1),g("x","z","y",1,1,t,n,e,s,a,2),g("x","z","y",1,-1,t,n,-e,s,a,3),g("x","y","z",1,-1,t,e,n,s,r,4),g("x","y","z",-1,-1,t,e,-n,s,r,5),this.setIndex(l),this.setAttribute("position",new pe(c,3)),this.setAttribute("normal",new pe(h,3)),this.setAttribute("uv",new pe(f,2));function g(_,m,p,S,A,v,b,E,C,y,w){let I=v/C,N=b/y,H=v/2,W=b/2,U=E/2,G=C+1,rt=y+1,j=0,pt=0,st=new P;for(let lt=0;lt<rt;lt++){let O=lt*N-W;for(let vt=0;vt<G;vt++){let St=vt*I-H;st[_]=St*S,st[m]=O*A,st[p]=U,c.push(st.x,st.y,st.z),st[_]=0,st[m]=0,st[p]=E>0?1:-1,h.push(st.x,st.y,st.z),f.push(vt/C),f.push(1-lt/y),j+=1}}for(let lt=0;lt<y;lt++)for(let O=0;O<C;O++){let vt=u+O+G*lt,St=u+O+G*(lt+1),Et=u+(O+1)+G*(lt+1),Xt=u+(O+1)+G*lt;l.push(vt,St,Xt),l.push(St,Et,Xt),pt+=6}o.addGroup(d,pt,w),d+=pt,u+=j}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.width,t.height,t.depth,t.widthSegments,t.heightSegments,t.depthSegments)}};var Sa=class i extends Ie{constructor(t=1,e=32,n=0,s=Math.PI*2){super(),this.type="CircleGeometry",this.parameters={radius:t,segments:e,thetaStart:n,thetaLength:s},e=Math.max(3,e);let r=[],a=[],o=[],l=[],c=new P,h=new ft;a.push(0,0,0),o.push(0,0,1),l.push(.5,.5);for(let f=0,u=3;f<=e;f++,u+=3){let d=n+f/e*s;c.x=t*Math.cos(d),c.y=t*Math.sin(d),a.push(c.x,c.y,c.z),o.push(0,0,1),h.x=(a[u]/t+1)/2,h.y=(a[u+1]/t+1)/2,l.push(h.x,h.y)}for(let f=1;f<=e;f++)r.push(f,f+1,0);this.setIndex(r),this.setAttribute("position",new pe(a,3)),this.setAttribute("normal",new pe(o,3)),this.setAttribute("uv",new pe(l,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.radius,t.segments,t.thetaStart,t.thetaLength)}},Xi=class i extends Ie{constructor(t=1,e=1,n=1,s=32,r=1,a=!1,o=0,l=Math.PI*2){super(),this.type="CylinderGeometry",this.parameters={radiusTop:t,radiusBottom:e,height:n,radialSegments:s,heightSegments:r,openEnded:a,thetaStart:o,thetaLength:l};let c=this;s=Math.floor(s),r=Math.floor(r);let h=[],f=[],u=[],d=[],g=0,_=[],m=n/2,p=0;S(),a===!1&&(t>0&&A(!0),e>0&&A(!1)),this.setIndex(h),this.setAttribute("position",new pe(f,3)),this.setAttribute("normal",new pe(u,3)),this.setAttribute("uv",new pe(d,2));function S(){let v=new P,b=new P,E=0,C=(e-t)/n;for(let y=0;y<=r;y++){let w=[],I=y/r,N=I*(e-t)+t;for(let H=0;H<=s;H++){let W=H/s,U=W*l+o,G=Math.sin(U),rt=Math.cos(U);b.x=N*G,b.y=-I*n+m,b.z=N*rt,f.push(b.x,b.y,b.z),v.set(G,C,rt).normalize(),u.push(v.x,v.y,v.z),d.push(W,1-I),w.push(g++)}_.push(w)}for(let y=0;y<s;y++)for(let w=0;w<r;w++){let I=_[w][y],N=_[w+1][y],H=_[w+1][y+1],W=_[w][y+1];(t>0||w!==0)&&(h.push(I,N,W),E+=3),(e>0||w!==r-1)&&(h.push(N,H,W),E+=3)}c.addGroup(p,E,0),p+=E}function A(v){let b=g,E=new ft,C=new P,y=0,w=v===!0?t:e,I=v===!0?1:-1;for(let H=1;H<=s;H++)f.push(0,m*I,0),u.push(0,I,0),d.push(.5,.5),g++;let N=g;for(let H=0;H<=s;H++){let U=H/s*l+o,G=Math.cos(U),rt=Math.sin(U);C.x=w*rt,C.y=m*I,C.z=w*G,f.push(C.x,C.y,C.z),u.push(0,I,0),E.x=G*.5+.5,E.y=rt*.5*I+.5,d.push(E.x,E.y),g++}for(let H=0;H<s;H++){let W=b+H,U=N+H;v===!0?h.push(U,U+1,W):h.push(U+1,U,W),y+=3}c.addGroup(p,y,v===!0?1:2),p+=y}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.radiusTop,t.radiusBottom,t.height,t.radialSegments,t.heightSegments,t.openEnded,t.thetaStart,t.thetaLength)}},ba=class i extends Xi{constructor(t=1,e=1,n=32,s=1,r=!1,a=0,o=Math.PI*2){super(0,t,e,n,s,r,a,o),this.type="ConeGeometry",this.parameters={radius:t,height:e,radialSegments:n,heightSegments:s,openEnded:r,thetaStart:a,thetaLength:o}}static fromJSON(t){return new i(t.radius,t.height,t.radialSegments,t.heightSegments,t.openEnded,t.thetaStart,t.thetaLength)}};var Hn=class{constructor(){this.type="Curve",this.arcLengthDivisions=200,this.needsUpdate=!1,this.cacheArcLengths=null}getPoint(){ue("Curve: .getPoint() not implemented.")}getPointAt(t,e){let n=this.getUtoTmapping(t);return this.getPoint(n,e)}getPoints(t=5){let e=[];for(let n=0;n<=t;n++)e.push(this.getPoint(n/t));return e}getSpacedPoints(t=5){let e=[];for(let n=0;n<=t;n++)e.push(this.getPointAt(n/t));return e}getLength(){let t=this.getLengths();return t[t.length-1]}getLengths(t=this.arcLengthDivisions){if(this.cacheArcLengths&&this.cacheArcLengths.length===t+1&&!this.needsUpdate)return this.cacheArcLengths;this.needsUpdate=!1;let e=[],n,s=this.getPoint(0),r=0;e.push(0);for(let a=1;a<=t;a++)n=this.getPoint(a/t),r+=n.distanceTo(s),e.push(r),s=n;return this.cacheArcLengths=e,e}updateArcLengths(){this.needsUpdate=!0,this.getLengths()}getUtoTmapping(t,e=null){let n=this.getLengths(),s=0,r=n.length,a;e?a=e:a=t*n[r-1];let o=0,l=r-1,c;for(;o<=l;)if(s=Math.floor(o+(l-o)/2),c=n[s]-a,c<0)o=s+1;else if(c>0)l=s-1;else{l=s;break}if(s=l,n[s]===a)return s/(r-1);let h=n[s],u=n[s+1]-h,d=(a-h)/u;return(s+d)/(r-1)}getTangent(t,e){let s=t-1e-4,r=t+1e-4;s<0&&(s=0),r>1&&(r=1);let a=this.getPoint(s),o=this.getPoint(r),l=e||(a.isVector2?new ft:new P);return l.copy(o).sub(a).normalize(),l}getTangentAt(t,e){let n=this.getUtoTmapping(t);return this.getTangent(n,e)}computeFrenetFrames(t,e=!1){let n=new P,s=[],r=[],a=[],o=new P,l=new De;for(let d=0;d<=t;d++){let g=d/t;s[d]=this.getTangentAt(g,new P)}r[0]=new P,a[0]=new P;let c=Number.MAX_VALUE,h=Math.abs(s[0].x),f=Math.abs(s[0].y),u=Math.abs(s[0].z);h<=c&&(c=h,n.set(1,0,0)),f<=c&&(c=f,n.set(0,1,0)),u<=c&&n.set(0,0,1),o.crossVectors(s[0],n).normalize(),r[0].crossVectors(s[0],o),a[0].crossVectors(s[0],r[0]);for(let d=1;d<=t;d++){if(r[d]=r[d-1].clone(),a[d]=a[d-1].clone(),o.crossVectors(s[d-1],s[d]),o.length()>Number.EPSILON){o.normalize();let g=Math.acos(we(s[d-1].dot(s[d]),-1,1));r[d].applyMatrix4(l.makeRotationAxis(o,g))}a[d].crossVectors(s[d],r[d])}if(e===!0){let d=Math.acos(we(r[0].dot(r[t]),-1,1));d/=t,s[0].dot(o.crossVectors(r[0],r[t]))>0&&(d=-d);for(let g=1;g<=t;g++)r[g].applyMatrix4(l.makeRotationAxis(s[g],d*g)),a[g].crossVectors(s[g],r[g])}return{tangents:s,normals:r,binormals:a}}clone(){return new this.constructor().copy(this)}copy(t){return this.arcLengthDivisions=t.arcLengthDivisions,this}toJSON(){let t={metadata:{version:4.7,type:"Curve",generator:"Curve.toJSON"}};return t.arcLengthDivisions=this.arcLengthDivisions,t.type=this.type,t}fromJSON(t){return this.arcLengthDivisions=t.arcLengthDivisions,this}},gr=class extends Hn{constructor(t=0,e=0,n=1,s=1,r=0,a=Math.PI*2,o=!1,l=0){super(),this.isEllipseCurve=!0,this.type="EllipseCurve",this.aX=t,this.aY=e,this.xRadius=n,this.yRadius=s,this.aStartAngle=r,this.aEndAngle=a,this.aClockwise=o,this.aRotation=l}getPoint(t,e=new ft){let n=e,s=Math.PI*2,r=this.aEndAngle-this.aStartAngle,a=Math.abs(r)<Number.EPSILON;for(;r<0;)r+=s;for(;r>s;)r-=s;r<Number.EPSILON&&(a?r=0:r=s),this.aClockwise===!0&&!a&&(r===s?r=-s:r=r-s);let o=this.aStartAngle+t*r,l=this.aX+this.xRadius*Math.cos(o),c=this.aY+this.yRadius*Math.sin(o);if(this.aRotation!==0){let h=Math.cos(this.aRotation),f=Math.sin(this.aRotation),u=l-this.aX,d=c-this.aY;l=u*h-d*f+this.aX,c=u*f+d*h+this.aY}return n.set(l,c)}copy(t){return super.copy(t),this.aX=t.aX,this.aY=t.aY,this.xRadius=t.xRadius,this.yRadius=t.yRadius,this.aStartAngle=t.aStartAngle,this.aEndAngle=t.aEndAngle,this.aClockwise=t.aClockwise,this.aRotation=t.aRotation,this}toJSON(){let t=super.toJSON();return t.aX=this.aX,t.aY=this.aY,t.xRadius=this.xRadius,t.yRadius=this.yRadius,t.aStartAngle=this.aStartAngle,t.aEndAngle=this.aEndAngle,t.aClockwise=this.aClockwise,t.aRotation=this.aRotation,t}fromJSON(t){return super.fromJSON(t),this.aX=t.aX,this.aY=t.aY,this.xRadius=t.xRadius,this.yRadius=t.yRadius,this.aStartAngle=t.aStartAngle,this.aEndAngle=t.aEndAngle,this.aClockwise=t.aClockwise,this.aRotation=t.aRotation,this}},gl=class extends gr{constructor(t,e,n,s,r,a){super(t,e,n,n,s,r,a),this.isArcCurve=!0,this.type="ArcCurve"}};function $0(){let i=0,t=0,e=0,n=0;function s(r,a,o,l){i=r,t=o,e=-3*r+3*a-2*o-l,n=2*r-2*a+o+l}return{initCatmullRom:function(r,a,o,l,c){s(a,o,c*(o-r),c*(l-a))},initNonuniformCatmullRom:function(r,a,o,l,c,h,f){let u=(a-r)/c-(o-r)/(c+h)+(o-a)/h,d=(o-a)/h-(l-a)/(h+f)+(l-o)/f;u*=h,d*=h,s(a,o,u,d)},calc:function(r){let a=r*r,o=a*r;return i+t*r+e*a+n*o}}}var ru=new P,au=new P,m0=new $0,g0=new $0,x0=new $0,xl=class extends Hn{constructor(t=[],e=!1,n="centripetal",s=.5){super(),this.isCatmullRomCurve3=!0,this.type="CatmullRomCurve3",this.points=t,this.closed=e,this.curveType=n,this.tension=s}getPoint(t,e=new P){let n=e,s=this.points,r=s.length,a=(r-(this.closed?0:1))*t,o=Math.floor(a),l=a-o;this.closed?o+=o>0?0:(Math.floor(Math.abs(o)/r)+1)*r:l===0&&o===r-1&&(o=r-2,l=1);let c,h;this.closed||o>0?c=s[(o-1)%r]:(au.subVectors(s[0],s[1]).add(s[0]),c=au);let f=s[o%r],u=s[(o+1)%r];if(this.closed||o+2<r?h=s[(o+2)%r]:(ru.subVectors(s[r-1],s[r-2]).add(s[r-1]),h=ru),this.curveType==="centripetal"||this.curveType==="chordal"){let d=this.curveType==="chordal"?.5:.25,g=Math.pow(c.distanceToSquared(f),d),_=Math.pow(f.distanceToSquared(u),d),m=Math.pow(u.distanceToSquared(h),d);_<1e-4&&(_=1),g<1e-4&&(g=_),m<1e-4&&(m=_),m0.initNonuniformCatmullRom(c.x,f.x,u.x,h.x,g,_,m),g0.initNonuniformCatmullRom(c.y,f.y,u.y,h.y,g,_,m),x0.initNonuniformCatmullRom(c.z,f.z,u.z,h.z,g,_,m)}else this.curveType==="catmullrom"&&(m0.initCatmullRom(c.x,f.x,u.x,h.x,this.tension),g0.initCatmullRom(c.y,f.y,u.y,h.y,this.tension),x0.initCatmullRom(c.z,f.z,u.z,h.z,this.tension));return n.set(m0.calc(l),g0.calc(l),x0.calc(l)),n}copy(t){super.copy(t),this.points=[];for(let e=0,n=t.points.length;e<n;e++){let s=t.points[e];this.points.push(s.clone())}return this.closed=t.closed,this.curveType=t.curveType,this.tension=t.tension,this}toJSON(){let t=super.toJSON();t.points=[];for(let e=0,n=this.points.length;e<n;e++){let s=this.points[e];t.points.push(s.toArray())}return t.closed=this.closed,t.curveType=this.curveType,t.tension=this.tension,t}fromJSON(t){super.fromJSON(t),this.points=[];for(let e=0,n=t.points.length;e<n;e++){let s=t.points[e];this.points.push(new P().fromArray(s))}return this.closed=t.closed,this.curveType=t.curveType,this.tension=t.tension,this}};function ou(i,t,e,n,s){let r=(n-t)*.5,a=(s-e)*.5,o=i*i,l=i*o;return(2*e-2*n+r+a)*l+(-3*e+3*n-2*r-a)*o+r*i+e}function Ld(i,t){let e=1-i;return e*e*t}function Dd(i,t){return 2*(1-i)*i*t}function Nd(i,t){return i*i*t}function ra(i,t,e,n){return Ld(i,t)+Dd(i,e)+Nd(i,n)}function Ud(i,t){let e=1-i;return e*e*e*t}function Fd(i,t){let e=1-i;return 3*e*e*i*t}function Od(i,t){return 3*(1-i)*i*i*t}function Bd(i,t){return i*i*i*t}function aa(i,t,e,n,s){return Ud(i,t)+Fd(i,e)+Od(i,n)+Bd(i,s)}var Ea=class extends Hn{constructor(t=new ft,e=new ft,n=new ft,s=new ft){super(),this.isCubicBezierCurve=!0,this.type="CubicBezierCurve",this.v0=t,this.v1=e,this.v2=n,this.v3=s}getPoint(t,e=new ft){let n=e,s=this.v0,r=this.v1,a=this.v2,o=this.v3;return n.set(aa(t,s.x,r.x,a.x,o.x),aa(t,s.y,r.y,a.y,o.y)),n}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this.v3.copy(t.v3),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t.v3=this.v3.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this.v3.fromArray(t.v3),this}},_l=class extends Hn{constructor(t=new P,e=new P,n=new P,s=new P){super(),this.isCubicBezierCurve3=!0,this.type="CubicBezierCurve3",this.v0=t,this.v1=e,this.v2=n,this.v3=s}getPoint(t,e=new P){let n=e,s=this.v0,r=this.v1,a=this.v2,o=this.v3;return n.set(aa(t,s.x,r.x,a.x,o.x),aa(t,s.y,r.y,a.y,o.y),aa(t,s.z,r.z,a.z,o.z)),n}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this.v3.copy(t.v3),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t.v3=this.v3.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this.v3.fromArray(t.v3),this}},Ta=class extends Hn{constructor(t=new ft,e=new ft){super(),this.isLineCurve=!0,this.type="LineCurve",this.v1=t,this.v2=e}getPoint(t,e=new ft){let n=e;return t===1?n.copy(this.v2):(n.copy(this.v2).sub(this.v1),n.multiplyScalar(t).add(this.v1)),n}getPointAt(t,e){return this.getPoint(t,e)}getTangent(t,e=new ft){return e.subVectors(this.v2,this.v1).normalize()}getTangentAt(t,e){return this.getTangent(t,e)}copy(t){return super.copy(t),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},xr=class extends Hn{constructor(t=new P,e=new P){super(),this.isLineCurve3=!0,this.type="LineCurve3",this.v1=t,this.v2=e}getPoint(t,e=new P){let n=e;return t===1?n.copy(this.v2):(n.copy(this.v2).sub(this.v1),n.multiplyScalar(t).add(this.v1)),n}getPointAt(t,e){return this.getPoint(t,e)}getTangent(t,e=new P){return e.subVectors(this.v2,this.v1).normalize()}getTangentAt(t,e){return this.getTangent(t,e)}copy(t){return super.copy(t),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},wa=class extends Hn{constructor(t=new ft,e=new ft,n=new ft){super(),this.isQuadraticBezierCurve=!0,this.type="QuadraticBezierCurve",this.v0=t,this.v1=e,this.v2=n}getPoint(t,e=new ft){let n=e,s=this.v0,r=this.v1,a=this.v2;return n.set(ra(t,s.x,r.x,a.x),ra(t,s.y,r.y,a.y)),n}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},Aa=class extends Hn{constructor(t=new P,e=new P,n=new P){super(),this.isQuadraticBezierCurve3=!0,this.type="QuadraticBezierCurve3",this.v0=t,this.v1=e,this.v2=n}getPoint(t,e=new P){let n=e,s=this.v0,r=this.v1,a=this.v2;return n.set(ra(t,s.x,r.x,a.x),ra(t,s.y,r.y,a.y),ra(t,s.z,r.z,a.z)),n}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},Ra=class extends Hn{constructor(t=[]){super(),this.isSplineCurve=!0,this.type="SplineCurve",this.points=t}getPoint(t,e=new ft){let n=e,s=this.points,r=(s.length-1)*t,a=Math.floor(r),o=r-a,l=s[a===0?a:a-1],c=s[a],h=s[a>s.length-2?s.length-1:a+1],f=s[a>s.length-3?s.length-1:a+2];return n.set(ou(o,l.x,c.x,h.x,f.x),ou(o,l.y,c.y,h.y,f.y)),n}copy(t){super.copy(t),this.points=[];for(let e=0,n=t.points.length;e<n;e++){let s=t.points[e];this.points.push(s.clone())}return this}toJSON(){let t=super.toJSON();t.points=[];for(let e=0,n=this.points.length;e<n;e++){let s=this.points[e];t.points.push(s.toArray())}return t}fromJSON(t){super.fromJSON(t),this.points=[];for(let e=0,n=t.points.length;e<n;e++){let s=t.points[e];this.points.push(new ft().fromArray(s))}return this}},vl=Object.freeze({__proto__:null,ArcCurve:gl,CatmullRomCurve3:xl,CubicBezierCurve:Ea,CubicBezierCurve3:_l,EllipseCurve:gr,LineCurve:Ta,LineCurve3:xr,QuadraticBezierCurve:wa,QuadraticBezierCurve3:Aa,SplineCurve:Ra}),_r=class extends Hn{constructor(){super(),this.type="CurvePath",this.curves=[],this.autoClose=!1}add(t){this.curves.push(t)}closePath(){let t=this.curves[0].getPoint(0),e=this.curves[this.curves.length-1].getPoint(1);if(!t.equals(e)){let n=t.isVector2===!0?"LineCurve":"LineCurve3";this.curves.push(new vl[n](e,t))}return this}getPoint(t,e){let n=t*this.getLength(),s=this.getCurveLengths(),r=0;for(;r<s.length;){if(s[r]>=n){let a=s[r]-n,o=this.curves[r],l=o.getLength(),c=l===0?0:1-a/l;return o.getPointAt(c,e)}r++}return null}getLength(){let t=this.getCurveLengths();return t[t.length-1]}updateArcLengths(){this.needsUpdate=!0,this.cacheLengths=null,this.getCurveLengths()}getCurveLengths(){if(this.cacheLengths&&this.cacheLengths.length===this.curves.length)return this.cacheLengths;let t=[],e=0;for(let n=0,s=this.curves.length;n<s;n++)e+=this.curves[n].getLength(),t.push(e);return this.cacheLengths=t,t}getSpacedPoints(t=40){let e=[];for(let n=0;n<=t;n++)e.push(this.getPoint(n/t));return this.autoClose&&e.push(e[0]),e}getPoints(t=12){let e=[],n;for(let s=0,r=this.curves;s<r.length;s++){let a=r[s],o=a.isEllipseCurve?t*2:a.isLineCurve||a.isLineCurve3?1:a.isSplineCurve?t*a.points.length:t,l=a.getPoints(o);for(let c=0;c<l.length;c++){let h=l[c];n&&n.equals(h)||(e.push(h),n=h)}}return this.autoClose&&e.length>1&&!e[e.length-1].equals(e[0])&&e.push(e[0]),e}copy(t){super.copy(t),this.curves=[];for(let e=0,n=t.curves.length;e<n;e++){let s=t.curves[e];this.curves.push(s.clone())}return this.autoClose=t.autoClose,this}toJSON(){let t=super.toJSON();t.autoClose=this.autoClose,t.curves=[];for(let e=0,n=this.curves.length;e<n;e++){let s=this.curves[e];t.curves.push(s.toJSON())}return t}fromJSON(t){super.fromJSON(t),this.autoClose=t.autoClose,this.curves=[];for(let e=0,n=t.curves.length;e<n;e++){let s=t.curves[e];this.curves.push(new vl[s.type]().fromJSON(s))}return this}},Ca=class extends _r{constructor(t){super(),this.type="Path",this.currentPoint=new ft,t&&this.setFromPoints(t)}setFromPoints(t){this.moveTo(t[0].x,t[0].y);for(let e=1,n=t.length;e<n;e++)this.lineTo(t[e].x,t[e].y);return this}moveTo(t,e){return this.currentPoint.set(t,e),this}lineTo(t,e){let n=new Ta(this.currentPoint.clone(),new ft(t,e));return this.curves.push(n),this.currentPoint.set(t,e),this}quadraticCurveTo(t,e,n,s){let r=new wa(this.currentPoint.clone(),new ft(t,e),new ft(n,s));return this.curves.push(r),this.currentPoint.set(n,s),this}bezierCurveTo(t,e,n,s,r,a){let o=new Ea(this.currentPoint.clone(),new ft(t,e),new ft(n,s),new ft(r,a));return this.curves.push(o),this.currentPoint.set(r,a),this}splineThru(t){let e=[this.currentPoint.clone()].concat(t),n=new Ra(e);return this.curves.push(n),this.currentPoint.copy(t[t.length-1]),this}arc(t,e,n,s,r,a){let o=this.currentPoint.x,l=this.currentPoint.y;return this.absarc(t+o,e+l,n,s,r,a),this}absarc(t,e,n,s,r,a){return this.absellipse(t,e,n,n,s,r,a),this}ellipse(t,e,n,s,r,a,o,l){let c=this.currentPoint.x,h=this.currentPoint.y;return this.absellipse(t+c,e+h,n,s,r,a,o,l),this}absellipse(t,e,n,s,r,a,o,l){let c=new gr(t,e,n,s,r,a,o,l);if(this.curves.length>0){let f=c.getPoint(0);f.equals(this.currentPoint)||this.lineTo(f.x,f.y)}this.curves.push(c);let h=c.getPoint(1);return this.currentPoint.copy(h),this}copy(t){return super.copy(t),this.currentPoint.copy(t.currentPoint),this}toJSON(){let t=super.toJSON();return t.currentPoint=this.currentPoint.toArray(),t}fromJSON(t){return super.fromJSON(t),this.currentPoint.fromArray(t.currentPoint),this}},qi=class extends Ca{constructor(t){super(t),this.uuid=ki(),this.type="Shape",this.holes=[]}getPointsHoles(t){let e=[];for(let n=0,s=this.holes.length;n<s;n++)e[n]=this.holes[n].getPoints(t);return e}extractPoints(t){return{shape:this.getPoints(t),holes:this.getPointsHoles(t)}}copy(t){super.copy(t),this.holes=[];for(let e=0,n=t.holes.length;e<n;e++){let s=t.holes[e];this.holes.push(s.clone())}return this}toJSON(){let t=super.toJSON();t.uuid=this.uuid,t.holes=[];for(let e=0,n=this.holes.length;e<n;e++){let s=this.holes[e];t.holes.push(s.toJSON())}return t}fromJSON(t){super.fromJSON(t),this.uuid=t.uuid,this.holes=[];for(let e=0,n=t.holes.length;e<n;e++){let s=t.holes[e];this.holes.push(new Ca().fromJSON(s))}return this}};function zd(i,t,e=2){let n=t&&t.length,s=n?t[0]*e:i.length,r=af(i,0,s,e,!0),a=[];if(!r||r.next===r.prev)return a;let o,l,c;if(n&&(r=Wd(i,t,r,e)),i.length>80*e){o=i[0],l=i[1];let h=o,f=l;for(let u=e;u<s;u+=e){let d=i[u],g=i[u+1];d<o&&(o=d),g<l&&(l=g),d>h&&(h=d),g>f&&(f=g)}c=Math.max(h-o,f-l),c=c!==0?32767/c:0}return Pa(r,a,e,o,l,c,0),a}function af(i,t,e,n,s){let r;if(s===ep(i,t,e,n)>0)for(let a=t;a<e;a+=n)r=lu(a/n|0,i[a],i[a+1],r);else for(let a=e-n;a>=t;a-=n)r=lu(a/n|0,i[a],i[a+1],r);return r&&vr(r,r.next)&&(La(r),r=r.next),r}function ws(i,t){if(!i)return i;t||(t=i);let e=i,n;do if(n=!1,!e.steiner&&(vr(e,e.next)||je(e.prev,e,e.next)===0)){if(La(e),e=t=e.prev,e===e.next)break;n=!0}else e=e.next;while(n||e!==t);return t}function Pa(i,t,e,n,s,r,a){if(!i)return;!a&&r&&Zd(i,n,s,r);let o=i;for(;i.prev!==i.next;){let l=i.prev,c=i.next;if(r?Hd(i,n,s,r):kd(i)){t.push(l.i,i.i,c.i),La(i),i=c.next,o=c.next;continue}if(i=c,i===o){a?a===1?(i=Vd(ws(i),t),Pa(i,t,e,n,s,r,2)):a===2&&Gd(i,t,e,n,s,r):Pa(ws(i),t,e,n,s,r,1);break}}}function kd(i){let t=i.prev,e=i,n=i.next;if(je(t,e,n)>=0)return!1;let s=t.x,r=e.x,a=n.x,o=t.y,l=e.y,c=n.y,h=Math.min(s,r,a),f=Math.min(o,l,c),u=Math.max(s,r,a),d=Math.max(o,l,c),g=n.next;for(;g!==t;){if(g.x>=h&&g.x<=u&&g.y>=f&&g.y<=d&&sa(s,o,r,l,a,c,g.x,g.y)&&je(g.prev,g,g.next)>=0)return!1;g=g.next}return!0}function Hd(i,t,e,n){let s=i.prev,r=i,a=i.next;if(je(s,r,a)>=0)return!1;let o=s.x,l=r.x,c=a.x,h=s.y,f=r.y,u=a.y,d=Math.min(o,l,c),g=Math.min(h,f,u),_=Math.max(o,l,c),m=Math.max(h,f,u),p=T0(d,g,t,e,n),S=T0(_,m,t,e,n),A=i.prevZ,v=i.nextZ;for(;A&&A.z>=p&&v&&v.z<=S;){if(A.x>=d&&A.x<=_&&A.y>=g&&A.y<=m&&A!==s&&A!==a&&sa(o,h,l,f,c,u,A.x,A.y)&&je(A.prev,A,A.next)>=0||(A=A.prevZ,v.x>=d&&v.x<=_&&v.y>=g&&v.y<=m&&v!==s&&v!==a&&sa(o,h,l,f,c,u,v.x,v.y)&&je(v.prev,v,v.next)>=0))return!1;v=v.nextZ}for(;A&&A.z>=p;){if(A.x>=d&&A.x<=_&&A.y>=g&&A.y<=m&&A!==s&&A!==a&&sa(o,h,l,f,c,u,A.x,A.y)&&je(A.prev,A,A.next)>=0)return!1;A=A.prevZ}for(;v&&v.z<=S;){if(v.x>=d&&v.x<=_&&v.y>=g&&v.y<=m&&v!==s&&v!==a&&sa(o,h,l,f,c,u,v.x,v.y)&&je(v.prev,v,v.next)>=0)return!1;v=v.nextZ}return!0}function Vd(i,t){let e=i;do{let n=e.prev,s=e.next.next;!vr(n,s)&&lf(n,e,e.next,s)&&Ia(n,s)&&Ia(s,n)&&(t.push(n.i,e.i,s.i),La(e),La(e.next),e=i=s),e=e.next}while(e!==i);return ws(e)}function Gd(i,t,e,n,s,r){let a=i;do{let o=a.next.next;for(;o!==a.prev;){if(a.i!==o.i&&jd(a,o)){let l=cf(a,o);a=ws(a,a.next),l=ws(l,l.next),Pa(a,t,e,n,s,r,0),Pa(l,t,e,n,s,r,0);return}o=o.next}a=a.next}while(a!==i)}function Wd(i,t,e,n){let s=[];for(let r=0,a=t.length;r<a;r++){let o=t[r]*n,l=r<a-1?t[r+1]*n:i.length,c=af(i,o,l,n,!1);c===c.next&&(c.steiner=!0),s.push(Kd(c))}s.sort(Xd);for(let r=0;r<s.length;r++)e=qd(s[r],e);return e}function Xd(i,t){let e=i.x-t.x;if(e===0&&(e=i.y-t.y,e===0)){let n=(i.next.y-i.y)/(i.next.x-i.x),s=(t.next.y-t.y)/(t.next.x-t.x);e=n-s}return e}function qd(i,t){let e=Yd(i,t);if(!e)return t;let n=cf(e,i);return ws(n,n.next),ws(e,e.next)}function Yd(i,t){let e=t,n=i.x,s=i.y,r=-1/0,a;if(vr(i,e))return e;do{if(vr(i,e.next))return e.next;if(s<=e.y&&s>=e.next.y&&e.next.y!==e.y){let f=e.x+(s-e.y)*(e.next.x-e.x)/(e.next.y-e.y);if(f<=n&&f>r&&(r=f,a=e.x<e.next.x?e:e.next,f===n))return a}e=e.next}while(e!==t);if(!a)return null;let o=a,l=a.x,c=a.y,h=1/0;e=a;do{if(n>=e.x&&e.x>=l&&n!==e.x&&of(s<c?n:r,s,l,c,s<c?r:n,s,e.x,e.y)){let f=Math.abs(s-e.y)/(n-e.x);Ia(e,i)&&(f<h||f===h&&(e.x>a.x||e.x===a.x&&$d(a,e)))&&(a=e,h=f)}e=e.next}while(e!==o);return a}function $d(i,t){return je(i.prev,i,t.prev)<0&&je(t.next,i,i.next)<0}function Zd(i,t,e,n){let s=i;do s.z===0&&(s.z=T0(s.x,s.y,t,e,n)),s.prevZ=s.prev,s.nextZ=s.next,s=s.next;while(s!==i);s.prevZ.nextZ=null,s.prevZ=null,Jd(s)}function Jd(i){let t,e=1;do{let n=i,s;i=null;let r=null;for(t=0;n;){t++;let a=n,o=0;for(let c=0;c<e&&(o++,a=a.nextZ,!!a);c++);let l=e;for(;o>0||l>0&&a;)o!==0&&(l===0||!a||n.z<=a.z)?(s=n,n=n.nextZ,o--):(s=a,a=a.nextZ,l--),r?r.nextZ=s:i=s,s.prevZ=r,r=s;n=a}r.nextZ=null,e*=2}while(t>1);return i}function T0(i,t,e,n,s){return i=(i-e)*s|0,t=(t-n)*s|0,i=(i|i<<8)&16711935,i=(i|i<<4)&252645135,i=(i|i<<2)&858993459,i=(i|i<<1)&1431655765,t=(t|t<<8)&16711935,t=(t|t<<4)&252645135,t=(t|t<<2)&858993459,t=(t|t<<1)&1431655765,i|t<<1}function Kd(i){let t=i,e=i;do(t.x<e.x||t.x===e.x&&t.y<e.y)&&(e=t),t=t.next;while(t!==i);return e}function of(i,t,e,n,s,r,a,o){return(s-a)*(t-o)>=(i-a)*(r-o)&&(i-a)*(n-o)>=(e-a)*(t-o)&&(e-a)*(r-o)>=(s-a)*(n-o)}function sa(i,t,e,n,s,r,a,o){return!(i===a&&t===o)&&of(i,t,e,n,s,r,a,o)}function jd(i,t){return i.next.i!==t.i&&i.prev.i!==t.i&&!Qd(i,t)&&(Ia(i,t)&&Ia(t,i)&&tp(i,t)&&(je(i.prev,i,t.prev)||je(i,t.prev,t))||vr(i,t)&&je(i.prev,i,i.next)>0&&je(t.prev,t,t.next)>0)}function je(i,t,e){return(t.y-i.y)*(e.x-t.x)-(t.x-i.x)*(e.y-t.y)}function vr(i,t){return i.x===t.x&&i.y===t.y}function lf(i,t,e,n){let s=Yo(je(i,t,e)),r=Yo(je(i,t,n)),a=Yo(je(e,n,i)),o=Yo(je(e,n,t));return!!(s!==r&&a!==o||s===0&&qo(i,e,t)||r===0&&qo(i,n,t)||a===0&&qo(e,i,n)||o===0&&qo(e,t,n))}function qo(i,t,e){return t.x<=Math.max(i.x,e.x)&&t.x>=Math.min(i.x,e.x)&&t.y<=Math.max(i.y,e.y)&&t.y>=Math.min(i.y,e.y)}function Yo(i){return i>0?1:i<0?-1:0}function Qd(i,t){let e=i;do{if(e.i!==i.i&&e.next.i!==i.i&&e.i!==t.i&&e.next.i!==t.i&&lf(e,e.next,i,t))return!0;e=e.next}while(e!==i);return!1}function Ia(i,t){return je(i.prev,i,i.next)<0?je(i,t,i.next)>=0&&je(i,i.prev,t)>=0:je(i,t,i.prev)<0||je(i,i.next,t)<0}function tp(i,t){let e=i,n=!1,s=(i.x+t.x)/2,r=(i.y+t.y)/2;do e.y>r!=e.next.y>r&&e.next.y!==e.y&&s<(e.next.x-e.x)*(r-e.y)/(e.next.y-e.y)+e.x&&(n=!n),e=e.next;while(e!==i);return n}function cf(i,t){let e=w0(i.i,i.x,i.y),n=w0(t.i,t.x,t.y),s=i.next,r=t.prev;return i.next=t,t.prev=i,e.next=s,s.prev=e,n.next=e,e.prev=n,r.next=n,n.prev=r,n}function lu(i,t,e,n){let s=w0(i,t,e);return n?(s.next=n.next,s.prev=n,n.next.prev=s,n.next=s):(s.prev=s,s.next=s),s}function La(i){i.next.prev=i.prev,i.prev.next=i.next,i.prevZ&&(i.prevZ.nextZ=i.nextZ),i.nextZ&&(i.nextZ.prevZ=i.prevZ)}function w0(i,t,e){return{i,x:t,y:e,prev:null,next:null,z:0,prevZ:null,nextZ:null,steiner:!1}}function ep(i,t,e,n){let s=0;for(let r=t,a=e-n;r<e;r+=n)s+=(i[a]-i[r])*(i[r+1]+i[a+1]),a=r;return s}var A0=class{static triangulate(t,e,n=2){return zd(t,e,n)}},yi=class i{static area(t){let e=t.length,n=0;for(let s=e-1,r=0;r<e;s=r++)n+=t[s].x*t[r].y-t[r].x*t[s].y;return n*.5}static isClockWise(t){return i.area(t)<0}static triangulateShape(t,e){let n=[],s=[],r=[];cu(t),hu(n,t);let a=t.length;e.forEach(cu);for(let l=0;l<e.length;l++)s.push(a),a+=e[l].length,hu(n,e[l]);let o=A0.triangulate(n,s);for(let l=0;l<o.length;l+=3)r.push(o.slice(l,l+3));return r}};function cu(i){let t=i.length;t>2&&i[t-1].equals(i[0])&&i.pop()}function hu(i,t){for(let e=0;e<t.length;e++)i.push(t[e].x),i.push(t[e].y)}var Da=class i extends Ie{constructor(t=new qi([new ft(.5,.5),new ft(-.5,.5),new ft(-.5,-.5),new ft(.5,-.5)]),e={}){super(),this.type="ExtrudeGeometry",this.parameters={shapes:t,options:e},t=Array.isArray(t)?t:[t];let n=this,s=[],r=[];for(let o=0,l=t.length;o<l;o++){let c=t[o];a(c)}this.setAttribute("position",new pe(s,3)),this.setAttribute("uv",new pe(r,2)),this.computeVertexNormals();function a(o){let l=[],c=e.curveSegments!==void 0?e.curveSegments:12,h=e.steps!==void 0?e.steps:1,f=e.depth!==void 0?e.depth:1,u=e.bevelEnabled!==void 0?e.bevelEnabled:!0,d=e.bevelThickness!==void 0?e.bevelThickness:.2,g=e.bevelSize!==void 0?e.bevelSize:d-.1,_=e.bevelOffset!==void 0?e.bevelOffset:0,m=e.bevelSegments!==void 0?e.bevelSegments:3,p=e.extrudePath,S=e.UVGenerator!==void 0?e.UVGenerator:np,A,v=!1,b,E,C,y;if(p){A=p.getSpacedPoints(h),v=!0,u=!1;let K=p.isCatmullRomCurve3?p.closed:!1;b=p.computeFrenetFrames(h,K),E=new P,C=new P,y=new P}u||(m=0,d=0,g=0,_=0);let w=o.extractPoints(c),I=w.shape,N=w.holes;if(!yi.isClockWise(I)){I=I.reverse();for(let K=0,ut=N.length;K<ut;K++){let yt=N[K];yi.isClockWise(yt)&&(N[K]=yt.reverse())}}function W(K){let yt=10000000000000001e-36,xt=K[0];for(let _t=1;_t<=K.length;_t++){let Gt=_t%K.length,Bt=K[Gt],Zt=Bt.x-xt.x,ne=Bt.y-xt.y,L=Zt*Zt+ne*ne,Jt=Math.max(Math.abs(Bt.x),Math.abs(Bt.y),Math.abs(xt.x),Math.abs(xt.y)),oe=yt*Jt*Jt;if(L<=oe){K.splice(Gt,1),_t--;continue}xt=Bt}}W(I),N.forEach(W);let U=N.length,G=I;for(let K=0;K<U;K++){let ut=N[K];I=I.concat(ut)}function rt(K,ut,yt){return ut||he("ExtrudeGeometry: vec does not exist"),K.clone().addScaledVector(ut,yt)}let j=I.length;function pt(K,ut,yt){let xt,_t,Gt,Bt=K.x-ut.x,Zt=K.y-ut.y,ne=yt.x-K.x,L=yt.y-K.y,Jt=Bt*Bt+Zt*Zt,oe=Bt*L-Zt*ne;if(Math.abs(oe)>Number.EPSILON){let T=Math.sqrt(Jt),x=Math.sqrt(ne*ne+L*L),k=ut.x-Zt/T,X=ut.y+Bt/T,et=yt.x-L/x,bt=yt.y+ne/x,Rt=((et-k)*L-(bt-X)*ne)/(Bt*L-Zt*ne);xt=k+Bt*Rt-K.x,_t=X+Zt*Rt-K.y;let it=xt*xt+_t*_t;if(it<=2)return new ft(xt,_t);Gt=Math.sqrt(it/2)}else{let T=!1;Bt>Number.EPSILON?ne>Number.EPSILON&&(T=!0):Bt<-Number.EPSILON?ne<-Number.EPSILON&&(T=!0):Math.sign(Zt)===Math.sign(L)&&(T=!0),T?(xt=-Zt,_t=Bt,Gt=Math.sqrt(Jt)):(xt=Bt,_t=Zt,Gt=Math.sqrt(Jt/2))}return new ft(xt/Gt,_t/Gt)}let st=[];for(let K=0,ut=G.length,yt=ut-1,xt=K+1;K<ut;K++,yt++,xt++)yt===ut&&(yt=0),xt===ut&&(xt=0),st[K]=pt(G[K],G[yt],G[xt]);let lt=[],O,vt=st.concat();for(let K=0,ut=U;K<ut;K++){let yt=N[K];O=[];for(let xt=0,_t=yt.length,Gt=_t-1,Bt=xt+1;xt<_t;xt++,Gt++,Bt++)Gt===_t&&(Gt=0),Bt===_t&&(Bt=0),O[xt]=pt(yt[xt],yt[Gt],yt[Bt]);lt.push(O),vt=vt.concat(O)}let St;if(m===0)St=yi.triangulateShape(G,N);else{let K=[],ut=[];for(let yt=0;yt<m;yt++){let xt=yt/m,_t=d*Math.cos(xt*Math.PI/2),Gt=g*Math.sin(xt*Math.PI/2)+_;for(let Bt=0,Zt=G.length;Bt<Zt;Bt++){let ne=rt(G[Bt],st[Bt],Gt);ht(ne.x,ne.y,-_t),xt===0&&K.push(ne)}for(let Bt=0,Zt=U;Bt<Zt;Bt++){let ne=N[Bt];O=lt[Bt];let L=[];for(let Jt=0,oe=ne.length;Jt<oe;Jt++){let T=rt(ne[Jt],O[Jt],Gt);ht(T.x,T.y,-_t),xt===0&&L.push(T)}xt===0&&ut.push(L)}}St=yi.triangulateShape(K,ut)}let Et=St.length,Xt=g+_;for(let K=0;K<j;K++){let ut=u?rt(I[K],vt[K],Xt):I[K];v?(C.copy(b.normals[0]).multiplyScalar(ut.x),E.copy(b.binormals[0]).multiplyScalar(ut.y),y.copy(A[0]).add(C).add(E),ht(y.x,y.y,y.z)):ht(ut.x,ut.y,0)}for(let K=1;K<=h;K++)for(let ut=0;ut<j;ut++){let yt=u?rt(I[ut],vt[ut],Xt):I[ut];v?(C.copy(b.normals[K]).multiplyScalar(yt.x),E.copy(b.binormals[K]).multiplyScalar(yt.y),y.copy(A[K]).add(C).add(E),ht(y.x,y.y,y.z)):ht(yt.x,yt.y,f/h*K)}for(let K=m-1;K>=0;K--){let ut=K/m,yt=d*Math.cos(ut*Math.PI/2),xt=g*Math.sin(ut*Math.PI/2)+_;for(let _t=0,Gt=G.length;_t<Gt;_t++){let Bt=rt(G[_t],st[_t],xt);ht(Bt.x,Bt.y,f+yt)}for(let _t=0,Gt=N.length;_t<Gt;_t++){let Bt=N[_t];O=lt[_t];for(let Zt=0,ne=Bt.length;Zt<ne;Zt++){let L=rt(Bt[Zt],O[Zt],xt);v?ht(L.x,L.y+A[h-1].y,A[h-1].x+yt):ht(L.x,L.y,f+yt)}}}gt(),J();function gt(){let K=s.length/3;if(u){let ut=0,yt=j*ut;for(let xt=0;xt<Et;xt++){let _t=St[xt];wt(_t[2]+yt,_t[1]+yt,_t[0]+yt)}ut=h+m*2,yt=j*ut;for(let xt=0;xt<Et;xt++){let _t=St[xt];wt(_t[0]+yt,_t[1]+yt,_t[2]+yt)}}else{for(let ut=0;ut<Et;ut++){let yt=St[ut];wt(yt[2],yt[1],yt[0])}for(let ut=0;ut<Et;ut++){let yt=St[ut];wt(yt[0]+j*h,yt[1]+j*h,yt[2]+j*h)}}n.addGroup(K,s.length/3-K,0)}function J(){let K=s.length/3,ut=0;q(G,ut),ut+=G.length;for(let yt=0,xt=N.length;yt<xt;yt++){let _t=N[yt];q(_t,ut),ut+=_t.length}n.addGroup(K,s.length/3-K,1)}function q(K,ut){let yt=K.length;for(;--yt>=0;){let xt=yt,_t=yt-1;_t<0&&(_t=K.length-1);for(let Gt=0,Bt=h+m*2;Gt<Bt;Gt++){let Zt=j*Gt,ne=j*(Gt+1),L=ut+xt+Zt,Jt=ut+_t+Zt,oe=ut+_t+ne,T=ut+xt+ne;ct(L,Jt,oe,T)}}}function ht(K,ut,yt){l.push(K),l.push(ut),l.push(yt)}function wt(K,ut,yt){Ft(K),Ft(ut),Ft(yt);let xt=s.length/3,_t=S.generateTopUV(n,s,xt-3,xt-2,xt-1);ae(_t[0]),ae(_t[1]),ae(_t[2])}function ct(K,ut,yt,xt){Ft(K),Ft(ut),Ft(xt),Ft(ut),Ft(yt),Ft(xt);let _t=s.length/3,Gt=S.generateSideWallUV(n,s,_t-6,_t-3,_t-2,_t-1);ae(Gt[0]),ae(Gt[1]),ae(Gt[3]),ae(Gt[1]),ae(Gt[2]),ae(Gt[3])}function Ft(K){s.push(l[K*3+0]),s.push(l[K*3+1]),s.push(l[K*3+2])}function ae(K){r.push(K.x),r.push(K.y)}}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}toJSON(){let t=super.toJSON(),e=this.parameters.shapes,n=this.parameters.options;return ip(e,n,t)}static fromJSON(t,e){let n=[];for(let r=0,a=t.shapes.length;r<a;r++){let o=e[t.shapes[r]];n.push(o)}let s=t.options.extrudePath;return s!==void 0&&(t.options.extrudePath=new vl[s.type]().fromJSON(s)),new i(n,t.options)}},np={generateTopUV:function(i,t,e,n,s){let r=t[e*3],a=t[e*3+1],o=t[n*3],l=t[n*3+1],c=t[s*3],h=t[s*3+1];return[new ft(r,a),new ft(o,l),new ft(c,h)]},generateSideWallUV:function(i,t,e,n,s,r){let a=t[e*3],o=t[e*3+1],l=t[e*3+2],c=t[n*3],h=t[n*3+1],f=t[n*3+2],u=t[s*3],d=t[s*3+1],g=t[s*3+2],_=t[r*3],m=t[r*3+1],p=t[r*3+2];return Math.abs(o-h)<Math.abs(a-c)?[new ft(a,1-l),new ft(c,1-f),new ft(u,1-g),new ft(_,1-p)]:[new ft(o,1-l),new ft(h,1-f),new ft(d,1-g),new ft(m,1-p)]}};function ip(i,t,e){if(e.shapes=[],Array.isArray(i))for(let n=0,s=i.length;n<s;n++){let r=i[n];e.shapes.push(r.uuid)}else e.shapes.push(i.uuid);return e.options=Object.assign({},t),t.extrudePath!==void 0&&(e.options.extrudePath=t.extrudePath.toJSON()),e}var yr=class i extends Ie{constructor(t=[new ft(0,-.5),new ft(.5,0),new ft(0,.5)],e=12,n=0,s=Math.PI*2){super(),this.type="LatheGeometry",this.parameters={points:t,segments:e,phiStart:n,phiLength:s},e=Math.floor(e),s=we(s,0,Math.PI*2);let r=[],a=[],o=[],l=[],c=[],h=1/e,f=new P,u=new ft,d=new P,g=new P,_=new P,m=0,p=0;for(let S=0;S<=t.length-1;S++)switch(S){case 0:m=t[S+1].x-t[S].x,p=t[S+1].y-t[S].y,d.x=p*1,d.y=-m,d.z=p*0,_.copy(d),d.normalize(),l.push(d.x,d.y,d.z);break;case t.length-1:l.push(_.x,_.y,_.z);break;default:m=t[S+1].x-t[S].x,p=t[S+1].y-t[S].y,d.x=p*1,d.y=-m,d.z=p*0,g.copy(d),d.x+=_.x,d.y+=_.y,d.z+=_.z,d.normalize(),l.push(d.x,d.y,d.z),_.copy(g)}for(let S=0;S<=e;S++){let A=n+S*h*s,v=Math.sin(A),b=Math.cos(A);for(let E=0;E<=t.length-1;E++){f.x=t[E].x*v,f.y=t[E].y,f.z=t[E].x*b,a.push(f.x,f.y,f.z),u.x=S/e,u.y=E/(t.length-1),o.push(u.x,u.y);let C=l[3*E+0]*v,y=l[3*E+1],w=l[3*E+0]*b;c.push(C,y,w)}}for(let S=0;S<e;S++)for(let A=0;A<t.length-1;A++){let v=A+S*t.length,b=v,E=v+t.length,C=v+t.length+1,y=v+1;r.push(b,E,y),r.push(C,y,E)}this.setIndex(r),this.setAttribute("position",new pe(a,3)),this.setAttribute("uv",new pe(o,2)),this.setAttribute("normal",new pe(c,3))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.points,t.segments,t.phiStart,t.phiLength)}};var rs=class i extends Ie{constructor(t=1,e=1,n=1,s=1){super(),this.type="PlaneGeometry",this.parameters={width:t,height:e,widthSegments:n,heightSegments:s};let r=t/2,a=e/2,o=Math.floor(n),l=Math.floor(s),c=o+1,h=l+1,f=t/o,u=e/l,d=[],g=[],_=[],m=[];for(let p=0;p<h;p++){let S=p*u-a;for(let A=0;A<c;A++){let v=A*f-r;g.push(v,-S,0),_.push(0,0,1),m.push(A/o),m.push(1-p/l)}}for(let p=0;p<l;p++)for(let S=0;S<o;S++){let A=S+c*p,v=S+c*(p+1),b=S+1+c*(p+1),E=S+1+c*p;d.push(A,v,E),d.push(v,b,E)}this.setIndex(d),this.setAttribute("position",new pe(g,3)),this.setAttribute("normal",new pe(_,3)),this.setAttribute("uv",new pe(m,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.width,t.height,t.widthSegments,t.heightSegments)}},Mr=class i extends Ie{constructor(t=.5,e=1,n=32,s=1,r=0,a=Math.PI*2){super(),this.type="RingGeometry",this.parameters={innerRadius:t,outerRadius:e,thetaSegments:n,phiSegments:s,thetaStart:r,thetaLength:a},n=Math.max(3,n),s=Math.max(1,s);let o=[],l=[],c=[],h=[],f=t,u=(e-t)/s,d=new P,g=new ft;for(let _=0;_<=s;_++){for(let m=0;m<=n;m++){let p=r+m/n*a;d.x=f*Math.cos(p),d.y=f*Math.sin(p),l.push(d.x,d.y,d.z),c.push(0,0,1),g.x=(d.x/e+1)/2,g.y=(d.y/e+1)/2,h.push(g.x,g.y)}f+=u}for(let _=0;_<s;_++){let m=_*(n+1);for(let p=0;p<n;p++){let S=p+m,A=S,v=S+n+1,b=S+n+2,E=S+1;o.push(A,v,E),o.push(v,b,E)}}this.setIndex(o),this.setAttribute("position",new pe(l,3)),this.setAttribute("normal",new pe(c,3)),this.setAttribute("uv",new pe(h,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.innerRadius,t.outerRadius,t.thetaSegments,t.phiSegments,t.thetaStart,t.thetaLength)}},Na=class i extends Ie{constructor(t=new qi([new ft(0,.5),new ft(-.5,-.5),new ft(.5,-.5)]),e=12){super(),this.type="ShapeGeometry",this.parameters={shapes:t,curveSegments:e};let n=[],s=[],r=[],a=[],o=0,l=0;if(Array.isArray(t)===!1)c(t);else for(let h=0;h<t.length;h++)c(t[h]),this.addGroup(o,l,h),o+=l,l=0;this.setIndex(n),this.setAttribute("position",new pe(s,3)),this.setAttribute("normal",new pe(r,3)),this.setAttribute("uv",new pe(a,2));function c(h){let f=s.length/3,u=h.extractPoints(e),d=u.shape,g=u.holes;yi.isClockWise(d)===!1&&(d=d.reverse());for(let m=0,p=g.length;m<p;m++){let S=g[m];yi.isClockWise(S)===!0&&(g[m]=S.reverse())}let _=yi.triangulateShape(d,g);for(let m=0,p=g.length;m<p;m++){let S=g[m];d=d.concat(S)}for(let m=0,p=d.length;m<p;m++){let S=d[m];s.push(S.x,S.y,0),r.push(0,0,1),a.push(S.x,S.y)}for(let m=0,p=_.length;m<p;m++){let S=_[m],A=S[0]+f,v=S[1]+f,b=S[2]+f;n.push(A,v,b),l+=3}}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}toJSON(){let t=super.toJSON(),e=this.parameters.shapes;return sp(e,t)}static fromJSON(t,e){let n=[];for(let s=0,r=t.shapes.length;s<r;s++){let a=e[t.shapes[s]];n.push(a)}return new i(n,t.curveSegments)}};function sp(i,t){if(t.shapes=[],Array.isArray(i))for(let e=0,n=i.length;e<n;e++){let s=i[e];t.shapes.push(s.uuid)}else t.shapes.push(i.uuid);return t}var jn=class i extends Ie{constructor(t=1,e=32,n=16,s=0,r=Math.PI*2,a=0,o=Math.PI){super(),this.type="SphereGeometry",this.parameters={radius:t,widthSegments:e,heightSegments:n,phiStart:s,phiLength:r,thetaStart:a,thetaLength:o},e=Math.max(3,Math.floor(e)),n=Math.max(2,Math.floor(n));let l=Math.min(a+o,Math.PI),c=0,h=[],f=new P,u=new P,d=[],g=[],_=[],m=[];for(let p=0;p<=n;p++){let S=[],A=p/n,v=a+A*o,b=t*Math.cos(v),E=Math.sqrt(t*t-b*b),C=0;p===0&&a===0?C=.5/e:p===n&&l===Math.PI&&(C=-.5/e);for(let y=0;y<=e;y++){let w=y/e,I=s+w*r;f.x=-E*Math.cos(I),f.y=b,f.z=E*Math.sin(I),g.push(f.x,f.y,f.z),u.copy(f).normalize(),_.push(u.x,u.y,u.z),m.push(w+C,1-A),S.push(c++)}h.push(S)}for(let p=0;p<n;p++)for(let S=0;S<e;S++){let A=h[p][S+1],v=h[p][S],b=h[p+1][S],E=h[p+1][S+1];(p!==0||a>0)&&d.push(A,v,E),(p!==n-1||l<Math.PI)&&d.push(v,b,E)}this.setIndex(d),this.setAttribute("position",new pe(g,3)),this.setAttribute("normal",new pe(_,3)),this.setAttribute("uv",new pe(m,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.radius,t.widthSegments,t.heightSegments,t.phiStart,t.phiLength,t.thetaStart,t.thetaLength)}};var Yi=class i extends Ie{constructor(t=1,e=.4,n=12,s=48,r=Math.PI*2,a=0,o=Math.PI*2){super(),this.type="TorusGeometry",this.parameters={radius:t,tube:e,radialSegments:n,tubularSegments:s,arc:r,thetaStart:a,thetaLength:o},n=Math.floor(n),s=Math.floor(s);let l=[],c=[],h=[],f=[],u=new P,d=new P,g=new P;for(let _=0;_<=n;_++){let m=a+_/n*o;for(let p=0;p<=s;p++){let S=p/s*r;d.x=(t+e*Math.cos(m))*Math.cos(S),d.y=(t+e*Math.cos(m))*Math.sin(S),d.z=e*Math.sin(m),c.push(d.x,d.y,d.z),u.x=t*Math.cos(S),u.y=t*Math.sin(S),g.subVectors(d,u).normalize(),h.push(g.x,g.y,g.z),f.push(p/s),f.push(_/n)}}for(let _=1;_<=n;_++)for(let m=1;m<=s;m++){let p=(s+1)*_+m-1,S=(s+1)*(_-1)+m-1,A=(s+1)*(_-1)+m,v=(s+1)*_+m;l.push(p,S,v),l.push(S,A,v)}this.setIndex(l),this.setAttribute("position",new pe(c,3)),this.setAttribute("normal",new pe(h,3)),this.setAttribute("uv",new pe(f,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.radius,t.tube,t.radialSegments,t.tubularSegments,t.arc,t.thetaStart,t.thetaLength)}};var Ua=class i extends Ie{constructor(t=new Aa(new P(-1,-1,0),new P(-1,1,0),new P(1,1,0)),e=64,n=1,s=8,r=!1){super(),this.type="TubeGeometry",this.parameters={path:t,tubularSegments:e,radius:n,radialSegments:s,closed:r};let a=t.computeFrenetFrames(e,r);this.tangents=a.tangents,this.normals=a.normals,this.binormals=a.binormals;let o=new P,l=new P,c=new ft,h=new P,f=[],u=[],d=[],g=[];_(),this.setIndex(g),this.setAttribute("position",new pe(f,3)),this.setAttribute("normal",new pe(u,3)),this.setAttribute("uv",new pe(d,2));function _(){for(let A=0;A<e;A++)m(A);m(r===!1?e:0),S(),p()}function m(A){h=t.getPointAt(A/e,h);let v=a.normals[A],b=a.binormals[A];for(let E=0;E<=s;E++){let C=E/s*Math.PI*2,y=Math.sin(C),w=-Math.cos(C);l.x=w*v.x+y*b.x,l.y=w*v.y+y*b.y,l.z=w*v.z+y*b.z,l.normalize(),u.push(l.x,l.y,l.z),o.x=h.x+n*l.x,o.y=h.y+n*l.y,o.z=h.z+n*l.z,f.push(o.x,o.y,o.z)}}function p(){for(let A=1;A<=e;A++)for(let v=1;v<=s;v++){let b=(s+1)*(A-1)+(v-1),E=(s+1)*A+(v-1),C=(s+1)*A+v,y=(s+1)*(A-1)+v;g.push(b,E,y),g.push(E,C,y)}}function S(){for(let A=0;A<=e;A++)for(let v=0;v<=s;v++)c.x=A/e,c.y=v/s,d.push(c.x,c.y)}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}toJSON(){let t=super.toJSON();return t.path=this.parameters.path.toJSON(),t}static fromJSON(t){return new i(new vl[t.path.type]().fromJSON(t.path),t.tubularSegments,t.radius,t.radialSegments,t.closed)}};function Ps(i){let t={};for(let e in i){t[e]={};for(let n in i[e]){let s=i[e][n];if(uu(s))s.isRenderTargetTexture?(ue("UniformsUtils: Textures of render targets cannot be cloned via cloneUniforms() or mergeUniforms()."),t[e][n]=null):t[e][n]=s.clone();else if(Array.isArray(s))if(uu(s[0])){let r=[];for(let a=0,o=s.length;a<o;a++)r[a]=s[a].clone();t[e][n]=r}else t[e][n]=s.slice();else t[e][n]=s}}return t}function In(i){let t={};for(let e=0;e<i.length;e++){let n=Ps(i[e]);for(let s in n)t[s]=n[s]}return t}function uu(i){return i&&(i.isColor||i.isMatrix3||i.isMatrix4||i.isVector2||i.isVector3||i.isVector4||i.isTexture||i.isQuaternion)}function rp(i){let t=[];for(let e=0;e<i.length;e++)t.push(i[e].clone());return t}function Z0(i){let t=i.getRenderTarget();return t===null?i.outputColorSpace:t.isXRRenderTarget===!0?t.texture.colorSpace:Ae.workingColorSpace}var $i={clone:Ps,merge:In},ap=`void main() {
	gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
}`,op=`void main() {
	gl_FragColor = vec4( 1.0, 0.0, 0.0, 1.0 );
}`,He=class extends ci{constructor(t){super(),this.isShaderMaterial=!0,this.type="ShaderMaterial",this.defines={},this.uniforms={},this.uniformsGroups=[],this.vertexShader=ap,this.fragmentShader=op,this.linewidth=1,this.wireframe=!1,this.wireframeLinewidth=1,this.fog=!1,this.lights=!1,this.clipping=!1,this.forceSinglePass=!0,this.extensions={clipCullDistance:!1,multiDraw:!1},this.defaultAttributeValues={color:[1,1,1],uv:[0,0],uv1:[0,0]},this.index0AttributeName=void 0,this.uniformsNeedUpdate=!1,this.glslVersion=null,t!==void 0&&this.setValues(t)}copy(t){return super.copy(t),this.fragmentShader=t.fragmentShader,this.vertexShader=t.vertexShader,this.uniforms=Ps(t.uniforms),this.uniformsGroups=rp(t.uniformsGroups),this.defines=Object.assign({},t.defines),this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this.fog=t.fog,this.lights=t.lights,this.clipping=t.clipping,this.extensions=Object.assign({},t.extensions),this.glslVersion=t.glslVersion,this.defaultAttributeValues=Object.assign({},t.defaultAttributeValues),this.index0AttributeName=t.index0AttributeName,this.uniformsNeedUpdate=t.uniformsNeedUpdate,this}toJSON(t){let e=super.toJSON(t);e.glslVersion=this.glslVersion,e.uniforms={};for(let s in this.uniforms){let a=this.uniforms[s].value;a&&a.isTexture?e.uniforms[s]={type:"t",value:a.toJSON(t).uuid}:a&&a.isColor?e.uniforms[s]={type:"c",value:a.getHex()}:a&&a.isVector2?e.uniforms[s]={type:"v2",value:a.toArray()}:a&&a.isVector3?e.uniforms[s]={type:"v3",value:a.toArray()}:a&&a.isVector4?e.uniforms[s]={type:"v4",value:a.toArray()}:a&&a.isMatrix3?e.uniforms[s]={type:"m3",value:a.toArray()}:a&&a.isMatrix4?e.uniforms[s]={type:"m4",value:a.toArray()}:e.uniforms[s]={value:a}}Object.keys(this.defines).length>0&&(e.defines=this.defines),e.vertexShader=this.vertexShader,e.fragmentShader=this.fragmentShader,e.lights=this.lights,e.clipping=this.clipping;let n={};for(let s in this.extensions)this.extensions[s]===!0&&(n[s]=!0);return Object.keys(n).length>0&&(e.extensions=n),e}fromJSON(t,e){if(super.fromJSON(t,e),t.uniforms!==void 0)for(let n in t.uniforms){let s=t.uniforms[n];switch(this.uniforms[n]={},s.type){case"t":this.uniforms[n].value=e[s.value]||null;break;case"c":this.uniforms[n].value=new se().setHex(s.value);break;case"v2":this.uniforms[n].value=new ft().fromArray(s.value);break;case"v3":this.uniforms[n].value=new P().fromArray(s.value);break;case"v4":this.uniforms[n].value=new $e().fromArray(s.value);break;case"m3":this.uniforms[n].value=new xe().fromArray(s.value);break;case"m4":this.uniforms[n].value=new De().fromArray(s.value);break;default:this.uniforms[n].value=s.value}}if(t.defines!==void 0&&(this.defines=t.defines),t.vertexShader!==void 0&&(this.vertexShader=t.vertexShader),t.fragmentShader!==void 0&&(this.fragmentShader=t.fragmentShader),t.glslVersion!==void 0&&(this.glslVersion=t.glslVersion),t.extensions!==void 0)for(let n in t.extensions)this.extensions[n]=t.extensions[n];return t.lights!==void 0&&(this.lights=t.lights),t.clipping!==void 0&&(this.clipping=t.clipping),this}},Sr=class extends He{constructor(t){super(t),this.isRawShaderMaterial=!0,this.type="RawShaderMaterial"}},Vn=class extends ci{constructor(t){super(),this.isMeshStandardMaterial=!0,this.type="MeshStandardMaterial",this.defines={STANDARD:""},this.color=new se(16777215),this.roughness=1,this.metalness=0,this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.emissive=new se(0),this.emissiveIntensity=1,this.emissiveMap=null,this.bumpMap=null,this.bumpScale=1,this.normalMap=null,this.normalMapType=vc,this.normalScale=new ft(1,1),this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.roughnessMap=null,this.metalnessMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new Vi,this.envMapIntensity=1,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.flatShading=!1,this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.defines={STANDARD:""},this.color.copy(t.color),this.roughness=t.roughness,this.metalness=t.metalness,this.map=t.map,this.lightMap=t.lightMap,this.lightMapIntensity=t.lightMapIntensity,this.aoMap=t.aoMap,this.aoMapIntensity=t.aoMapIntensity,this.emissive.copy(t.emissive),this.emissiveMap=t.emissiveMap,this.emissiveIntensity=t.emissiveIntensity,this.bumpMap=t.bumpMap,this.bumpScale=t.bumpScale,this.normalMap=t.normalMap,this.normalMapType=t.normalMapType,this.normalScale.copy(t.normalScale),this.displacementMap=t.displacementMap,this.displacementScale=t.displacementScale,this.displacementBias=t.displacementBias,this.roughnessMap=t.roughnessMap,this.metalnessMap=t.metalnessMap,this.alphaMap=t.alphaMap,this.envMap=t.envMap,this.envMapRotation.copy(t.envMapRotation),this.envMapIntensity=t.envMapIntensity,this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this.wireframeLinecap=t.wireframeLinecap,this.wireframeLinejoin=t.wireframeLinejoin,this.flatShading=t.flatShading,this.fog=t.fog,this}},Fa=class extends Vn{constructor(t){super(),this.isMeshPhysicalMaterial=!0,this.defines={STANDARD:"",PHYSICAL:""},this.type="MeshPhysicalMaterial",this.anisotropyRotation=0,this.anisotropyMap=null,this.clearcoatMap=null,this.clearcoatRoughness=0,this.clearcoatRoughnessMap=null,this.clearcoatNormalScale=new ft(1,1),this.clearcoatNormalMap=null,this.ior=1.5,Object.defineProperty(this,"reflectivity",{get:function(){return we(2.5*(this.ior-1)/(this.ior+1),0,1)},set:function(e){this.ior=(1+.4*e)/(1-.4*e)}}),this.iridescenceMap=null,this.iridescenceIOR=1.3,this.iridescenceThicknessRange=[100,400],this.iridescenceThicknessMap=null,this.sheenColor=new se(0),this.sheenColorMap=null,this.sheenRoughness=1,this.sheenRoughnessMap=null,this.transmissionMap=null,this.thickness=0,this.thicknessMap=null,this.attenuationDistance=1/0,this.attenuationColor=new se(1,1,1),this.specularIntensity=1,this.specularIntensityMap=null,this.specularColor=new se(1,1,1),this.specularColorMap=null,this._anisotropy=0,this._clearcoat=0,this._dispersion=0,this._iridescence=0,this._retroreflectivity=0,this._sheen=0,this._transmission=0,this.setValues(t)}get anisotropy(){return this._anisotropy}set anisotropy(t){this._anisotropy>0!=t>0&&this.version++,this._anisotropy=t}get clearcoat(){return this._clearcoat}set clearcoat(t){this._clearcoat>0!=t>0&&this.version++,this._clearcoat=t}get iridescence(){return this._iridescence}set iridescence(t){this._iridescence>0!=t>0&&this.version++,this._iridescence=t}get dispersion(){return this._dispersion}set dispersion(t){this._dispersion>0!=t>0&&this.version++,this._dispersion=t}get retroreflectivity(){return this._retroreflectivity}set retroreflectivity(t){this._retroreflectivity>0!=t>0&&this.version++,this._retroreflectivity=t}get sheen(){return this._sheen}set sheen(t){this._sheen>0!=t>0&&this.version++,this._sheen=t}get transmission(){return this._transmission}set transmission(t){this._transmission>0!=t>0&&this.version++,this._transmission=t}copy(t){return super.copy(t),this.defines={STANDARD:"",PHYSICAL:""},this.anisotropy=t.anisotropy,this.anisotropyRotation=t.anisotropyRotation,this.anisotropyMap=t.anisotropyMap,this.clearcoat=t.clearcoat,this.clearcoatMap=t.clearcoatMap,this.clearcoatRoughness=t.clearcoatRoughness,this.clearcoatRoughnessMap=t.clearcoatRoughnessMap,this.clearcoatNormalMap=t.clearcoatNormalMap,this.clearcoatNormalScale.copy(t.clearcoatNormalScale),this.dispersion=t.dispersion,this.ior=t.ior,this.iridescence=t.iridescence,this.iridescenceMap=t.iridescenceMap,this.iridescenceIOR=t.iridescenceIOR,this.iridescenceThicknessRange=[...t.iridescenceThicknessRange],this.iridescenceThicknessMap=t.iridescenceThicknessMap,this.retroreflectivity=t.retroreflectivity,this.sheen=t.sheen,this.sheenColor.copy(t.sheenColor),this.sheenColorMap=t.sheenColorMap,this.sheenRoughness=t.sheenRoughness,this.sheenRoughnessMap=t.sheenRoughnessMap,this.transmission=t.transmission,this.transmissionMap=t.transmissionMap,this.thickness=t.thickness,this.thicknessMap=t.thicknessMap,this.attenuationDistance=t.attenuationDistance,this.attenuationColor.copy(t.attenuationColor),this.specularIntensity=t.specularIntensity,this.specularIntensityMap=t.specularIntensityMap,this.specularColor.copy(t.specularColor),this.specularColorMap=t.specularColorMap,this}};var yl=class extends ci{constructor(t){super(),this.isMeshDepthMaterial=!0,this.type="MeshDepthMaterial",this.depthPacking=Wu,this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.wireframe=!1,this.wireframeLinewidth=1,this.setValues(t)}copy(t){return super.copy(t),this.depthPacking=t.depthPacking,this.map=t.map,this.alphaMap=t.alphaMap,this.displacementMap=t.displacementMap,this.displacementScale=t.displacementScale,this.displacementBias=t.displacementBias,this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this}},Ml=class extends ci{constructor(t){super(),this.isMeshDistanceMaterial=!0,this.type="MeshDistanceMaterial",this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.setValues(t)}copy(t){return super.copy(t),this.map=t.map,this.alphaMap=t.alphaMap,this.displacementMap=t.displacementMap,this.displacementScale=t.displacementScale,this.displacementBias=t.displacementBias,this}};var Oa=class extends hi{constructor(t){super(),this.isLineDashedMaterial=!0,this.type="LineDashedMaterial",this.scale=1,this.dashSize=3,this.gapSize=1,this.setValues(t)}copy(t){return super.copy(t),this.scale=t.scale,this.dashSize=t.dashSize,this.gapSize=t.gapSize,this}};function tr(i,t){return!i||i.constructor===t?i:typeof t.BYTES_PER_ELEMENT=="number"?new t(i):Array.prototype.slice.call(i)}function _0(i){return i!==void 0&&i.inTangents!==void 0&&i.outTangents!==void 0}var as=class{constructor(t,e,n,s){this.parameterPositions=t,this._cachedIndex=0,this.resultBuffer=s!==void 0?s:new e.constructor(n),this.sampleValues=e,this.valueSize=n,this.settings=null,this.DefaultSettings_={}}evaluate(t){let e=this.parameterPositions,n=this._cachedIndex,s=e[n],r=e[n-1];n:{t:{let a;e:{i:if(!(t<s)){for(let o=n+2;;){if(s===void 0){if(t<r)break i;return n=e.length,this._cachedIndex=n,this.copySampleValue_(n-1)}if(n===o)break;if(r=s,s=e[++n],t<s)break t}a=e.length;break e}if(!(t>=r)){let o=e[1];t<o&&(n=2,r=o);for(let l=n-2;;){if(r===void 0)return this._cachedIndex=0,this.copySampleValue_(0);if(n===l)break;if(s=r,r=e[--n-1],t>=r)break t}a=n,n=0;break e}break n}for(;n<a;){let o=n+a>>>1;t<e[o]?a=o:n=o+1}if(s=e[n],r=e[n-1],r===void 0)return this._cachedIndex=0,this.copySampleValue_(0);if(s===void 0)return n=e.length,this._cachedIndex=n,this.copySampleValue_(n-1)}this._cachedIndex=n,this.intervalChanged_(n,r,s)}return this.interpolate_(n,r,t,s)}getSettings_(){return this.settings||this.DefaultSettings_}copySampleValue_(t){let e=this.resultBuffer,n=this.sampleValues,s=this.valueSize,r=t*s;for(let a=0;a!==s;++a)e[a]=n[r+a];return e}interpolate_(){throw new Error("THREE.Interpolant: Call to abstract method.")}intervalChanged_(){}},Sl=class extends as{constructor(t,e,n,s){super(t,e,n,s),this._weightPrev=-0,this._offsetPrev=-0,this._weightNext=-0,this._offsetNext=-0,this.DefaultSettings_={endingStart:M0,endingEnd:M0}}intervalChanged_(t,e,n){let s=this.parameterPositions,r=t-2,a=t+1,o=s[r],l=s[a];if(o===void 0)switch(this.getSettings_().endingStart){case S0:r=t,o=2*e-n;break;case b0:r=s.length-2,o=e+s[r]-s[r+1];break;default:r=t,o=n}if(l===void 0)switch(this.getSettings_().endingEnd){case S0:a=t,l=2*n-e;break;case b0:a=1,l=n+s[1]-s[0];break;default:a=t-1,l=e}let c=(n-e)*.5,h=this.valueSize;this._weightPrev=c/(e-o),this._weightNext=c/(l-n),this._offsetPrev=r*h,this._offsetNext=a*h}interpolate_(t,e,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,l=t*o,c=l-o,h=this._offsetPrev,f=this._offsetNext,u=this._weightPrev,d=this._weightNext,g=(n-e)/(s-e),_=g*g,m=_*g,p=-u*m+2*u*_-u*g,S=(1+u)*m+(-1.5-2*u)*_+(-.5+u)*g+1,A=(-1-d)*m+(1.5+d)*_+.5*g,v=d*m-d*_;for(let b=0;b!==o;++b)r[b]=p*a[h+b]+S*a[c+b]+A*a[l+b]+v*a[f+b];return r}},bl=class extends as{constructor(t,e,n,s){super(t,e,n,s)}interpolate_(t,e,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,l=t*o,c=l-o,h=(n-e)/(s-e),f=1-h;for(let u=0;u!==o;++u)r[u]=a[c+u]*f+a[l+u]*h;return r}},El=class extends as{constructor(t,e,n,s){super(t,e,n,s)}interpolate_(t){return this.copySampleValue_(t-1)}},Tl=class extends as{interpolate_(t,e,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,l=t*o,c=l-o,h=this.inTangents,f=this.outTangents;if(!h||!f){let g=(n-e)/(s-e),_=1-g;for(let m=0;m!==o;++m)r[m]=a[c+m]*_+a[l+m]*g;return r}let u=o*2,d=t-1;for(let g=0;g!==o;++g){let _=a[c+g],m=a[l+g],p=d*u+g*2,S=f[p],A=f[p+1],v=t*u+g*2,b=h[v],E=h[v+1],C=cp(n,e,S,b,s);r[g]=hf(C,_,A,E,m)}return r}};function hf(i,t,e,n,s){let r=1-i;return r*r*r*t+3*r*r*i*e+3*r*i*i*n+i*i*i*s}function lp(i,t,e,n,s){let r=1-i;return 3*r*r*(e-t)+6*r*i*(n-e)+3*i*i*(s-n)}function cp(i,t,e,n,s){let r=(i-t)/(s-t);for(let a=0;a<8;a++){let o=hf(r,t,e,n,s)-i;if(Math.abs(o)<1e-10)break;let l=lp(r,t,e,n,s);if(Math.abs(l)<1e-10)break;r=Math.max(0,Math.min(1,r-o/l))}return r}var Gn=class{constructor(t,e,n,s){if(t===void 0)throw new Error("THREE.KeyframeTrack: track name is undefined");if(e===void 0||e.length===0)throw new Error("THREE.KeyframeTrack: no keyframes in track named "+t);this.name=t,this.times=tr(e,this.TimeBufferType),this.values=tr(n,this.ValueBufferType),this.setInterpolation(s||this.DefaultInterpolation)}static toJSON(t){let e=t.constructor,n;if(e.toJSON!==this.toJSON)n=e.toJSON(t);else{n={name:t.name,times:tr(t.times,Array),values:tr(t.values,Array)};let s=t.getInterpolation();s!==t.DefaultInterpolation&&(n.interpolation=s),_0(t.settings)&&(n.settings={inTangents:tr(t.settings.inTangents,Array),outTangents:tr(t.settings.outTangents,Array)})}return n.type=t.ValueTypeName,n}InterpolantFactoryMethodDiscrete(t){return new El(this.times,this.values,this.getValueSize(),t)}InterpolantFactoryMethodLinear(t){return new bl(this.times,this.values,this.getValueSize(),t)}InterpolantFactoryMethodSmooth(t){return new Sl(this.times,this.values,this.getValueSize(),t)}InterpolantFactoryMethodBezier(t){let e=new Tl(this.times,this.values,this.getValueSize(),t);return this.settings&&(e.inTangents=this.settings.inTangents,e.outTangents=this.settings.outTangents),e}setInterpolation(t){let e;switch(t){case oa:e=this.InterpolantFactoryMethodDiscrete;break;case ol:e=this.InterpolantFactoryMethodLinear;break;case Jo:e=this.InterpolantFactoryMethodSmooth;break;case y0:e=this.InterpolantFactoryMethodBezier;break}if(e===void 0){let n="unsupported interpolation for "+this.ValueTypeName+" keyframe track named "+this.name;if(this.createInterpolant===void 0)if(t!==this.DefaultInterpolation)this.setInterpolation(this.DefaultInterpolation);else throw new Error(n);return ue("KeyframeTrack:",n),this}return this.createInterpolant=e,this}getInterpolation(){switch(this.createInterpolant){case this.InterpolantFactoryMethodDiscrete:return oa;case this.InterpolantFactoryMethodLinear:return ol;case this.InterpolantFactoryMethodSmooth:return Jo;case this.InterpolantFactoryMethodBezier:return y0}}getValueSize(){return this.values.length/this.times.length}shift(t){if(t!==0){let e=this.times;for(let n=0,s=e.length;n!==s;++n)e[n]+=t}return this}scale(t){if(t!==1){let e=this.times;for(let n=0,s=e.length;n!==s;++n)e[n]*=t;_0(this.settings)&&(fu(this.settings.inTangents,t),fu(this.settings.outTangents,t))}return this}trim(t,e){let n=this.times,s=n.length,r=0,a=s-1;for(;r!==s&&n[r]<t;)++r;for(;a!==-1&&n[a]>e;)--a;if(++a,r!==0||a!==s){r>=a&&(a=Math.max(a,1),r=a-1);let o=this.getValueSize();this.times=n.slice(r,a),this.values=this.values.slice(r*o,a*o)}return this}validate(){let t=!0,e=this.getValueSize();e-Math.floor(e)!==0&&(he("KeyframeTrack: Invalid value size in track.",this),t=!1);let n=this.times,s=this.values,r=n.length;r===0&&(he("KeyframeTrack: Track is empty.",this),t=!1);let a=null;for(let o=0;o!==r;o++){let l=n[o];if(typeof l=="number"&&isNaN(l)){he("KeyframeTrack: Time is not a valid number.",this,o,l),t=!1;break}if(a!==null&&a>l){he("KeyframeTrack: Out of order keys.",this,o,l,a),t=!1;break}a=l}if(s!==void 0&&ud(s))for(let o=0,l=s.length;o!==l;++o){let c=s[o];if(isNaN(c)){he("KeyframeTrack: Value is not a valid number.",this,o,c),t=!1;break}}return t}optimize(){let t=this.times.slice(),e=this.values.slice(),n=this.getValueSize(),s=this.getInterpolation()===Jo,r=t.length-1,a=1;for(let o=1;o<r;++o){let l=!1,c=t[o],h=t[o+1];if(c!==h&&(o!==1||c!==t[0]))if(s)l=!0;else{let f=o*n,u=f-n,d=f+n;for(let g=0;g!==n;++g){let _=e[f+g];if(_!==e[u+g]||_!==e[d+g]){l=!0;break}}}if(l){if(o!==a){t[a]=t[o];let f=o*n,u=a*n;for(let d=0;d!==n;++d)e[u+d]=e[f+d]}++a}}if(r>0){t[a]=t[r];for(let o=r*n,l=a*n,c=0;c!==n;++c)e[l+c]=e[o+c];++a}return a!==t.length?(this.times=t.slice(0,a),this.values=e.slice(0,a*n)):(this.times=t,this.values=e),this}clone(){let t=this.times.slice(),e=this.values.slice(),n=this.constructor,s=new n(this.name,t,e);return s.createInterpolant=this.createInterpolant,_0(this.settings)&&(s.settings={inTangents:this.settings.inTangents.slice(),outTangents:this.settings.outTangents.slice()}),s}};function fu(i,t){for(let e=0,n=i.length;e!==n;e+=2)i[e]*=t}Gn.prototype.ValueTypeName="";Gn.prototype.TimeBufferType=Float32Array;Gn.prototype.ValueBufferType=Float32Array;Gn.prototype.DefaultInterpolation=ol;var os=class extends Gn{constructor(t,e,n){super(t,e,n)}};os.prototype.ValueTypeName="bool";os.prototype.ValueBufferType=Array;os.prototype.DefaultInterpolation=oa;os.prototype.InterpolantFactoryMethodLinear=void 0;os.prototype.InterpolantFactoryMethodSmooth=void 0;var wl=class extends Gn{constructor(t,e,n,s){super(t,e,n,s)}};wl.prototype.ValueTypeName="color";var Al=class extends Gn{constructor(t,e,n,s){super(t,e,n,s)}};Al.prototype.ValueTypeName="number";var Rl=class extends as{constructor(t,e,n,s){super(t,e,n,s)}interpolate_(t,e,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,l=(n-e)/(s-e),c=t*o;for(let h=c+o;c!==h;c+=4)bi.slerpFlat(r,0,a,c-o,a,c,l);return r}},Ba=class extends Gn{constructor(t,e,n,s){super(t,e,n,s)}InterpolantFactoryMethodLinear(t){return new Rl(this.times,this.values,this.getValueSize(),t)}};Ba.prototype.ValueTypeName="quaternion";Ba.prototype.InterpolantFactoryMethodSmooth=void 0;var ls=class extends Gn{constructor(t,e,n){super(t,e,n)}};ls.prototype.ValueTypeName="string";ls.prototype.ValueBufferType=Array;ls.prototype.DefaultInterpolation=oa;ls.prototype.InterpolantFactoryMethodLinear=void 0;ls.prototype.InterpolantFactoryMethodSmooth=void 0;var Cl=class extends Gn{constructor(t,e,n,s){super(t,e,n,s)}};Cl.prototype.ValueTypeName="vector";var jo={enabled:!1,files:{},add:function(i,t){this.enabled!==!1&&(du(i)||(this.files[i]=t))},get:function(i){if(this.enabled!==!1&&!du(i))return this.files[i]},remove:function(i){delete this.files[i]},clear:function(){this.files={}}};function du(i){try{let t=i.slice(i.indexOf(":")+1);return new URL(t).protocol==="blob:"}catch{return!1}}var Pl=class{constructor(t,e,n){let s=this,r=!1,a=0,o=0,l,c=[];this.onStart=void 0,this.onLoad=t,this.onProgress=e,this.onError=n,this._abortController=null,this.itemStart=function(h){o++,r===!1&&s.onStart!==void 0&&s.onStart(h,a,o),r=!0},this.itemEnd=function(h){a++,s.onProgress!==void 0&&s.onProgress(h,a,o),a===o&&(r=!1,s.onLoad!==void 0&&s.onLoad())},this.itemError=function(h){s.onError!==void 0&&s.onError(h)},this.resolveURL=function(h){return h=h.normalize("NFC"),l?l(h):h},this.setURLModifier=function(h){return l=h,this},this.addHandler=function(h,f){return c.push(h,f),this},this.removeHandler=function(h){let f=c.indexOf(h);return f!==-1&&c.splice(f,2),this},this.getHandler=function(h){for(let f=0,u=c.length;f<u;f+=2){let d=c[f],g=c[f+1];if(d.global&&(d.lastIndex=0),d.test(h))return g}return null},this.abort=function(){return this.abortController.abort(),this._abortController=null,this}}get abortController(){return this._abortController||(this._abortController=new AbortController),this._abortController}},uf=new Pl,br=class{constructor(t){this.manager=t!==void 0?t:uf,this.crossOrigin="anonymous",this.withCredentials=!1,this.path="",this.resourcePath="",this.requestHeader={},typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}load(){}loadAsync(t,e){let n=this;return new Promise(function(s,r){n.load(t,s,e,r)})}parse(){}setCrossOrigin(t){return this.crossOrigin=t,this}setWithCredentials(t){return this.withCredentials=t,this}setPath(t){return this.path=t,this}setResourcePath(t){return this.resourcePath=t,this}setRequestHeader(t){return this.requestHeader=t,this}abort(){return this}};br.DEFAULT_MATERIAL_NAME="__DEFAULT";var er=new WeakMap,Il=class extends br{constructor(t){super(t)}load(t,e,n,s){this.path!==void 0&&(t=this.path+t),t=this.manager.resolveURL(t);let r=this,a=jo.get(`image:${t}`);if(a!==void 0){if(a.complete===!0)r.manager.itemStart(t),setTimeout(function(){e&&e(a),r.manager.itemEnd(t)},0);else{let f=er.get(a);f===void 0&&(f=[],er.set(a,f)),f.push({onLoad:e,onError:s})}return a}let o=or("img");function l(){h(),e&&e(this);let f=er.get(this)||[];for(let u=0;u<f.length;u++){let d=f[u];d.onLoad&&d.onLoad(this)}er.delete(this),r.manager.itemEnd(t)}function c(f){h(),s&&s(f),jo.remove(`image:${t}`);let u=er.get(this)||[];for(let d=0;d<u.length;d++){let g=u[d];g.onError&&g.onError(f)}er.delete(this),r.manager.itemError(t),r.manager.itemEnd(t)}function h(){o.removeEventListener("load",l,!1),o.removeEventListener("error",c,!1)}return o.addEventListener("load",l,!1),o.addEventListener("error",c,!1),t.slice(0,5)!=="data:"&&this.crossOrigin!==void 0&&(o.crossOrigin=this.crossOrigin),jo.add(`image:${t}`,o),r.manager.itemStart(t),o.src=t,o}};var za=class extends br{constructor(t){super(t)}load(t,e,n,s){let r=new xn,a=new Il(this.manager);return a.setCrossOrigin(this.crossOrigin),a.setPath(this.path),a.load(t,function(o){r.image=o,r.needsUpdate=!0,e!==void 0&&e(r)},n,s),r}},Er=class extends rn{constructor(t,e=1){super(),this.isLight=!0,this.type="Light",this.color=new se(t),this.intensity=e}copy(t,e){return super.copy(t,e),this.color.copy(t.color),this.intensity=t.intensity,this}toJSON(t){let e=super.toJSON(t);return e.object.color=this.color.getHex(),e.object.intensity=this.intensity,e}},ka=class extends Er{constructor(t,e,n){super(t,n),this.isHemisphereLight=!0,this.type="HemisphereLight",this.position.copy(rn.DEFAULT_UP),this.updateMatrix(),this.groundColor=new se(e)}copy(t,e){return super.copy(t,e),this.groundColor.copy(t.groundColor),this}toJSON(t){let e=super.toJSON(t);return e.object.groundColor=this.groundColor.getHex(),e}},v0=new De,pu=new P,mu=new P,Ha=class{constructor(t){this.camera=t,this.intensity=1,this.bias=0,this.biasNode=null,this.normalBias=0,this.radius=1,this.blurSamples=8,this.mapSize=new ft(512,512),this.mapType=Fn,this.map=null,this.mapPass=null,this.matrix=new De,this.autoUpdate=!0,this.needsUpdate=!1,this._frustum=new pr,this._frameExtents=new ft(1,1),this._viewportCount=1,this._viewports=[new $e(0,0,1,1)]}getViewportCount(){return this._viewportCount}getCamera(){return this.camera}getFrustum(){return this._frustum}updateMatrices(t){let e=this.camera;pu.setFromMatrixPosition(t.matrixWorld),e.position.copy(pu),mu.setFromMatrixPosition(t.target.matrixWorld),e.lookAt(mu),e.updateMatrixWorld(),this._updateMatrix(e,this.matrix,this._frustum)}_updateMatrix(t,e,n,s){v0.multiplyMatrices(t.projectionMatrix,t.matrixWorldInverse),n.setFromProjectionMatrix(v0,t.coordinateSystem,t.reversedDepth);let r=this._frameExtents,a=s?s.z/r.x:1,o=s?s.w/r.y:1,l=s?s.x/r.x:0,c=s?s.y/r.y:0;t.coordinateSystem===ar||t.reversedDepth?e.set(.5*a,0,0,.5*a+l,0,.5*o,0,.5*o+c,0,0,1,0,0,0,0,1):e.set(.5*a,0,0,.5*a+l,0,.5*o,0,.5*o+c,0,0,.5,.5,0,0,0,1),e.multiply(v0)}getViewport(t){return this._viewports[t]}getFrameExtents(){return this._frameExtents}dispose(){this.map&&this.map.dispose(),this.mapPass&&this.mapPass.dispose()}copy(t){return this.camera=t.camera.clone(),this.intensity=t.intensity,this.bias=t.bias,this.radius=t.radius,this.autoUpdate=t.autoUpdate,this.needsUpdate=t.needsUpdate,this.normalBias=t.normalBias,this.blurSamples=t.blurSamples,this.mapSize.copy(t.mapSize),this.biasNode=t.biasNode,this}clone(){return new this.constructor().copy(this)}toJSON(){let t={};return t.intensity=this.intensity,t.bias=this.bias,t.normalBias=this.normalBias,t.radius=this.radius,t.blurSamples=this.blurSamples,t.mapSize=this.mapSize.toArray(),t.camera=this.camera.toJSON(!1).object,delete t.camera.matrix,t}},$o=new P,Zo=new bi,xi=new P,Va=class extends rn{constructor(){super(),this.isCamera=!0,this.type="Camera",this.matrixWorldInverse=new De,this.projectionMatrix=new De,this.projectionMatrixInverse=new De,this.coordinateSystem=li,this._reversedDepth=!1}get reversedDepth(){return this._reversedDepth}copy(t,e){return super.copy(t,e),this.matrixWorldInverse.copy(t.matrixWorldInverse),this.projectionMatrix.copy(t.projectionMatrix),this.projectionMatrixInverse.copy(t.projectionMatrixInverse),this.coordinateSystem=t.coordinateSystem,this}getWorldDirection(t){return super.getWorldDirection(t).negate()}updateMatrixWorld(t){super.updateMatrixWorld(t),this.matrixWorld.decompose($o,Zo,xi),xi.x===1&&xi.y===1&&xi.z===1?this.matrixWorldInverse.copy(this.matrixWorld).invert():this.matrixWorldInverse.compose($o,Zo,xi.set(1,1,1)).invert()}updateWorldMatrix(t,e,n=!1){super.updateWorldMatrix(t,e,n),this.matrixWorld.decompose($o,Zo,xi),xi.x===1&&xi.y===1&&xi.z===1?this.matrixWorldInverse.copy(this.matrixWorld).invert():this.matrixWorldInverse.compose($o,Zo,xi.set(1,1,1)).invert()}clone(){return new this.constructor().copy(this)}},es=new P,gu=new ft,xu=new ft,Mn=class extends Va{constructor(t=50,e=1,n=.1,s=2e3){super(),this.isPerspectiveCamera=!0,this.type="PerspectiveCamera",this.fov=t,this.zoom=1,this.near=n,this.far=s,this.focus=10,this.aspect=e,this.view=null,this.filmGauge=35,this.filmOffset=0,this.updateProjectionMatrix()}copy(t,e){return super.copy(t,e),this.fov=t.fov,this.zoom=t.zoom,this.near=t.near,this.far=t.far,this.focus=t.focus,this.aspect=t.aspect,this.view=t.view===null?null:Object.assign({},t.view),this.filmGauge=t.filmGauge,this.filmOffset=t.filmOffset,this}setFocalLength(t){let e=.5*this.getFilmHeight()/t;this.fov=ll*2*Math.atan(e),this.updateProjectionMatrix()}getFocalLength(){let t=Math.tan(qc*.5*this.fov);return .5*this.getFilmHeight()/t}getEffectiveFOV(){return ll*2*Math.atan(Math.tan(qc*.5*this.fov)/this.zoom)}getFilmWidth(){return this.filmGauge*Math.min(this.aspect,1)}getFilmHeight(){return this.filmGauge/Math.max(this.aspect,1)}getViewBounds(t,e,n){es.set(-1,-1,.5).applyMatrix4(this.projectionMatrixInverse),e.set(es.x,es.y).multiplyScalar(-t/es.z),es.set(1,1,.5).applyMatrix4(this.projectionMatrixInverse),n.set(es.x,es.y).multiplyScalar(-t/es.z)}getViewSize(t,e){return this.getViewBounds(t,gu,xu),e.subVectors(xu,gu)}setViewOffset(t,e,n,s,r,a){this.aspect=t/e,this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=t,this.view.fullHeight=e,this.view.offsetX=n,this.view.offsetY=s,this.view.width=r,this.view.height=a,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){let t=this.near,e=t*Math.tan(qc*.5*this.fov)/this.zoom,n=2*e,s=this.aspect*n,r=-.5*s,a=this.view;if(this.view!==null&&this.view.enabled){let l=a.fullWidth,c=a.fullHeight;r+=a.offsetX*s/l,e-=a.offsetY*n/c,s*=a.width/l,n*=a.height/c}let o=this.filmOffset;o!==0&&(r+=t*o/this.getFilmWidth()),this.projectionMatrix.makePerspective(r,r+s,e,e-n,t,this.far,this.coordinateSystem,this.reversedDepth),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(t){let e=super.toJSON(t);return e.object.fov=this.fov,e.object.zoom=this.zoom,e.object.near=this.near,e.object.far=this.far,e.object.focus=this.focus,e.object.aspect=this.aspect,this.view!==null&&(e.object.view=Object.assign({},this.view)),e.object.filmGauge=this.filmGauge,e.object.filmOffset=this.filmOffset,e}};var R0=class extends Ha{constructor(){super(new Mn(90,1,.5,500)),this.isPointLightShadow=!0}},Ga=class extends Er{constructor(t,e,n=0,s=2){super(t,e),this.isPointLight=!0,this.type="PointLight",this.distance=n,this.decay=s,this.shadow=new R0}get power(){return this.intensity*4*Math.PI}set power(t){this.intensity=t/(4*Math.PI)}dispose(){super.dispose(),this.shadow.dispose()}copy(t,e){return super.copy(t,e),this.distance=t.distance,this.decay=t.decay,this.shadow=t.shadow.clone(),this}toJSON(t){let e=super.toJSON(t);return e.object.distance=this.distance,e.object.decay=this.decay,e.object.shadow=this.shadow.toJSON(),e}},cs=class extends Va{constructor(t=-1,e=1,n=1,s=-1,r=.1,a=2e3){super(),this.isOrthographicCamera=!0,this.type="OrthographicCamera",this.zoom=1,this.view=null,this.left=t,this.right=e,this.top=n,this.bottom=s,this.near=r,this.far=a,this.updateProjectionMatrix()}copy(t,e){return super.copy(t,e),this.left=t.left,this.right=t.right,this.top=t.top,this.bottom=t.bottom,this.near=t.near,this.far=t.far,this.zoom=t.zoom,this.view=t.view===null?null:Object.assign({},t.view),this}setViewOffset(t,e,n,s,r,a){this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=t,this.view.fullHeight=e,this.view.offsetX=n,this.view.offsetY=s,this.view.width=r,this.view.height=a,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){let t=(this.right-this.left)/(2*this.zoom),e=(this.top-this.bottom)/(2*this.zoom),n=(this.right+this.left)/2,s=(this.top+this.bottom)/2,r=n-t,a=n+t,o=s+e,l=s-e;if(this.view!==null&&this.view.enabled){let c=(this.right-this.left)/this.view.fullWidth/this.zoom,h=(this.top-this.bottom)/this.view.fullHeight/this.zoom;r+=c*this.view.offsetX,a=r+c*this.view.width,o-=h*this.view.offsetY,l=o-h*this.view.height}this.projectionMatrix.makeOrthographic(r,a,o,l,this.near,this.far,this.coordinateSystem,this.reversedDepth),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(t){let e=super.toJSON(t);return e.object.zoom=this.zoom,e.object.left=this.left,e.object.right=this.right,e.object.top=this.top,e.object.bottom=this.bottom,e.object.near=this.near,e.object.far=this.far,this.view!==null&&(e.object.view=Object.assign({},this.view)),e}},C0=class extends Ha{constructor(){super(new cs(-5,5,5,-5,.5,500)),this.isDirectionalLightShadow=!0}},Tr=class extends Er{constructor(t,e){super(t,e),this.isDirectionalLight=!0,this.type="DirectionalLight",this.position.copy(rn.DEFAULT_UP),this.updateMatrix(),this.target=new rn,this.shadow=new C0}dispose(){super.dispose(),this.shadow.dispose()}copy(t){return super.copy(t),this.target=t.target.clone(),this.shadow=t.shadow.clone(),this}toJSON(t){let e=super.toJSON(t);return e.object.shadow=this.shadow.toJSON(),e.object.target=this.target.uuid,e}};var nr=-90,ir=1,Ll=class extends rn{constructor(t,e,n){super(),this.type="CubeCamera",this.renderTarget=n,this.coordinateSystem=null,this.activeMipmapLevel=0;let s=new Mn(nr,ir,t,e);s.layers=this.layers,this.add(s);let r=new Mn(nr,ir,t,e);r.layers=this.layers,this.add(r);let a=new Mn(nr,ir,t,e);a.layers=this.layers,this.add(a);let o=new Mn(nr,ir,t,e);o.layers=this.layers,this.add(o);let l=new Mn(nr,ir,t,e);l.layers=this.layers,this.add(l);let c=new Mn(nr,ir,t,e);c.layers=this.layers,this.add(c)}updateCoordinateSystem(){let t=this.coordinateSystem,e=this.children.concat(),[n,s,r,a,o,l]=e;for(let c of e)this.remove(c);if(t===li)n.up.set(0,1,0),n.lookAt(1,0,0),s.up.set(0,1,0),s.lookAt(-1,0,0),r.up.set(0,0,-1),r.lookAt(0,1,0),a.up.set(0,0,1),a.lookAt(0,-1,0),o.up.set(0,1,0),o.lookAt(0,0,1),l.up.set(0,1,0),l.lookAt(0,0,-1);else if(t===ar)n.up.set(0,-1,0),n.lookAt(-1,0,0),s.up.set(0,-1,0),s.lookAt(1,0,0),r.up.set(0,0,1),r.lookAt(0,1,0),a.up.set(0,0,-1),a.lookAt(0,-1,0),o.up.set(0,-1,0),o.lookAt(0,0,1),l.up.set(0,-1,0),l.lookAt(0,0,-1);else throw new Error("THREE.CubeCamera.updateCoordinateSystem(): Invalid coordinate system: "+t);for(let c of e)this.add(c),c.updateMatrixWorld()}update(t,e){this.parent===null&&this.updateMatrixWorld();let{renderTarget:n,activeMipmapLevel:s}=this;this.coordinateSystem!==t.coordinateSystem&&(this.coordinateSystem=t.coordinateSystem,this.updateCoordinateSystem());let[r,a,o,l,c,h]=this.children,f=t.getRenderTarget(),u=t.getActiveCubeFace(),d=t.getActiveMipmapLevel(),g=t.xr.enabled;t.xr.enabled=!1;let _=n.texture.generateMipmaps;n.texture.generateMipmaps=!1;let m=!1;t.isWebGLRenderer===!0?m=t.state.buffers.depth.getReversed():m=t.reversedDepthBuffer,t.setRenderTarget(n,0,s),m&&t.autoClear===!1&&t.clearDepth(),t.render(e,r),t.setRenderTarget(n,1,s),m&&t.autoClear===!1&&t.clearDepth(),t.render(e,a),t.setRenderTarget(n,2,s),m&&t.autoClear===!1&&t.clearDepth(),t.render(e,o),t.setRenderTarget(n,3,s),m&&t.autoClear===!1&&t.clearDepth(),t.render(e,l),t.setRenderTarget(n,4,s),m&&t.autoClear===!1&&t.clearDepth(),t.render(e,c),n.texture.generateMipmaps=_,t.setRenderTarget(n,5,s),m&&t.autoClear===!1&&t.clearDepth(),t.render(e,h),t.setRenderTarget(f,u,d),t.xr.enabled=g,n.texture.needsPMREMUpdate=!0}},Dl=class extends Mn{constructor(t=[]){super(),this.isArrayCamera=!0,this.isMultiViewCamera=!1,this.cameras=t}},Wa=class{constructor(){this._previousTime=0,this._currentTime=0,this._startTime=performance.now(),this._delta=0,this._elapsed=0,this._timescale=1,this._document=null,this._pageVisibilityHandler=null}connect(t){this._document=t,t.hidden!==void 0&&(this._pageVisibilityHandler=hp.bind(this),t.addEventListener("visibilitychange",this._pageVisibilityHandler,!1))}disconnect(){this._pageVisibilityHandler!==null&&(this._document.removeEventListener("visibilitychange",this._pageVisibilityHandler),this._pageVisibilityHandler=null),this._document=null}getDelta(){return this._delta/1e3}getElapsed(){return this._elapsed/1e3}getTimescale(){return this._timescale}setTimescale(t){return this._timescale=t,this}reset(){return this._currentTime=performance.now()-this._startTime,this}dispose(){this.disconnect()}update(t){return this._pageVisibilityHandler!==null&&this._document.hidden===!0?this._delta=0:(this._previousTime=this._currentTime,this._currentTime=(t!==void 0?t:performance.now())-this._startTime,this._delta=(this._currentTime-this._previousTime)*this._timescale,this._elapsed+=this._delta),this}};function hp(){this._document.hidden===!1&&this.reset()}var J0="\\[\\]\\.:\\/",up=new RegExp("["+J0+"]","g"),K0="[^"+J0+"]",fp="[^"+J0.replace("\\.","")+"]",dp=/((?:WC+[\/:])*)/.source.replace("WC",K0),pp=/(WCOD+)?/.source.replace("WCOD",fp),mp=/(?:\.(WC+)(?:\[(.+)\])?)?/.source.replace("WC",K0),gp=/\.(WC+)(?:\[(.+)\])?/.source.replace("WC",K0),xp=new RegExp("^"+dp+pp+mp+gp+"$"),_p=["material","materials","bones","map"],P0=class{constructor(t,e,n){let s=n||qe.parseTrackName(e);this._targetGroup=t,this._bindings=t.subscribe_(e,s)}getValue(t,e){this.bind();let n=this._targetGroup.nCachedObjects_,s=this._bindings[n];s!==void 0&&s.getValue(t,e)}setValue(t,e){let n=this._bindings;for(let s=this._targetGroup.nCachedObjects_,r=n.length;s!==r;++s)n[s].setValue(t,e)}bind(){let t=this._bindings;for(let e=this._targetGroup.nCachedObjects_,n=t.length;e!==n;++e)t[e].bind()}unbind(){let t=this._bindings;for(let e=this._targetGroup.nCachedObjects_,n=t.length;e!==n;++e)t[e].unbind()}},qe=class i{constructor(t,e,n){this.path=e,this.parsedPath=n||i.parseTrackName(e),this.node=i.findNode(t,this.parsedPath.nodeName),this.rootNode=t,this.getValue=this._getValue_unbound,this.setValue=this._setValue_unbound}static create(t,e,n){return t&&t.isAnimationObjectGroup?new i.Composite(t,e,n):new i(t,e,n)}static sanitizeNodeName(t){return t.replace(/\s/g,"_").replace(up,"")}static parseTrackName(t){let e=xp.exec(t);if(e===null)throw new Error("THREE.PropertyBinding: Cannot parse trackName: "+t);let n={nodeName:e[2],objectName:e[3],objectIndex:e[4],propertyName:e[5],propertyIndex:e[6]},s=n.nodeName&&n.nodeName.lastIndexOf(".");if(s!==void 0&&s!==-1){let r=n.nodeName.substring(s+1);_p.indexOf(r)!==-1&&(n.nodeName=n.nodeName.substring(0,s),n.objectName=r)}if(n.propertyName===null||n.propertyName.length===0)throw new Error("THREE.PropertyBinding: can not parse propertyName from trackName: "+t);return n}static findNode(t,e){if(e===void 0||e===""||e==="."||e===-1||e===t.name||e===t.uuid)return t;if(t.skeleton){let n=t.skeleton.getBoneByName(e);if(n!==void 0)return n}if(t.children){let n=function(r){for(let a=0;a<r.length;a++){let o=r[a];if(o.name===e||o.uuid===e)return o;let l=n(o.children);if(l)return l}return null},s=n(t.children);if(s)return s}return null}_getValue_unavailable(){}_setValue_unavailable(){}_getValue_direct(t,e){t[e]=this.targetObject[this.propertyName]}_getValue_array(t,e){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)t[e++]=n[s]}_getValue_arrayElement(t,e){t[e]=this.resolvedProperty[this.propertyIndex]}_getValue_toArray(t,e){this.resolvedProperty.toArray(t,e)}_setValue_direct(t,e){this.targetObject[this.propertyName]=t[e]}_setValue_direct_setNeedsUpdate(t,e){this.targetObject[this.propertyName]=t[e],this.targetObject.needsUpdate=!0}_setValue_direct_setMatrixWorldNeedsUpdate(t,e){this.targetObject[this.propertyName]=t[e],this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_array(t,e){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)n[s]=t[e++]}_setValue_array_setNeedsUpdate(t,e){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)n[s]=t[e++];this.targetObject.needsUpdate=!0}_setValue_array_setMatrixWorldNeedsUpdate(t,e){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)n[s]=t[e++];this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_arrayElement(t,e){this.resolvedProperty[this.propertyIndex]=t[e]}_setValue_arrayElement_setNeedsUpdate(t,e){this.resolvedProperty[this.propertyIndex]=t[e],this.targetObject.needsUpdate=!0}_setValue_arrayElement_setMatrixWorldNeedsUpdate(t,e){this.resolvedProperty[this.propertyIndex]=t[e],this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_fromArray(t,e){this.resolvedProperty.fromArray(t,e)}_setValue_fromArray_setNeedsUpdate(t,e){this.resolvedProperty.fromArray(t,e),this.targetObject.needsUpdate=!0}_setValue_fromArray_setMatrixWorldNeedsUpdate(t,e){this.resolvedProperty.fromArray(t,e),this.targetObject.matrixWorldNeedsUpdate=!0}_getValue_unbound(t,e){this.bind(),this.getValue(t,e)}_setValue_unbound(t,e){this.bind(),this.setValue(t,e)}bind(){let t=this.node,e=this.parsedPath,n=e.objectName,s=e.propertyName,r=e.propertyIndex;if(t||(t=i.findNode(this.rootNode,e.nodeName),this.node=t),this.getValue=this._getValue_unavailable,this.setValue=this._setValue_unavailable,!t){ue("PropertyBinding: No target node found for track: "+this.path+".");return}if(n){let c=e.objectIndex;switch(n){case"materials":if(!t.material){he("PropertyBinding: Can not bind to material as node does not have a material.",this);return}if(!t.material.materials){he("PropertyBinding: Can not bind to material.materials as node.material does not have a materials array.",this);return}t=t.material.materials;break;case"bones":if(!t.skeleton){he("PropertyBinding: Can not bind to bones as node does not have a skeleton.",this);return}t=t.skeleton.bones;for(let h=0;h<t.length;h++)if(t[h].name===c){c=h;break}break;case"map":if("map"in t){t=t.map;break}if(!t.material){he("PropertyBinding: Can not bind to material as node does not have a material.",this);return}if(!t.material.map){he("PropertyBinding: Can not bind to material.map as node.material does not have a map.",this);return}t=t.material.map;break;default:if(t[n]===void 0){he("PropertyBinding: Can not bind to objectName of node undefined.",this);return}t=t[n]}if(c!==void 0){if(t[c]===void 0){he("PropertyBinding: Trying to bind to objectIndex of objectName, but is undefined.",this,t);return}t=t[c]}}let a=t[s];if(a===void 0){let c=e.nodeName;he("PropertyBinding: Trying to update property for track: "+c+"."+s+" but it wasn't found.",t);return}let o=this.Versioning.None;this.targetObject=t,t.isMaterial===!0?o=this.Versioning.NeedsUpdate:t.isObject3D===!0&&(o=this.Versioning.MatrixWorldNeedsUpdate);let l=this.BindingType.Direct;if(r!==void 0){if(s==="morphTargetInfluences"){if(!t.geometry){he("PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.",this);return}if(!t.geometry.morphAttributes){he("PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.morphAttributes.",this);return}t.morphTargetDictionary[r]!==void 0&&(r=t.morphTargetDictionary[r])}l=this.BindingType.ArrayElement,this.resolvedProperty=a,this.propertyIndex=r}else a.fromArray!==void 0&&a.toArray!==void 0?(l=this.BindingType.HasFromToArray,this.resolvedProperty=a):Array.isArray(a)?(l=this.BindingType.EntireArray,this.resolvedProperty=a):this.propertyName=s;this.getValue=this.GetterByBindingType[l],this.setValue=this.SetterByBindingTypeAndVersioning[l][o]}unbind(){this.node=null,this.getValue=this._getValue_unbound,this.setValue=this._setValue_unbound}};qe.Composite=P0;qe.prototype.BindingType={Direct:0,EntireArray:1,ArrayElement:2,HasFromToArray:3};qe.prototype.Versioning={None:0,NeedsUpdate:1,MatrixWorldNeedsUpdate:2};qe.prototype.GetterByBindingType=[qe.prototype._getValue_direct,qe.prototype._getValue_array,qe.prototype._getValue_arrayElement,qe.prototype._getValue_toArray];qe.prototype.SetterByBindingTypeAndVersioning=[[qe.prototype._setValue_direct,qe.prototype._setValue_direct_setNeedsUpdate,qe.prototype._setValue_direct_setMatrixWorldNeedsUpdate],[qe.prototype._setValue_array,qe.prototype._setValue_array_setNeedsUpdate,qe.prototype._setValue_array_setMatrixWorldNeedsUpdate],[qe.prototype._setValue_arrayElement,qe.prototype._setValue_arrayElement_setNeedsUpdate,qe.prototype._setValue_arrayElement_setMatrixWorldNeedsUpdate],[qe.prototype._setValue_fromArray,qe.prototype._setValue_fromArray_setNeedsUpdate,qe.prototype._setValue_fromArray_setMatrixWorldNeedsUpdate]];var Dx=new Float32Array(1);var _u=new De,Xa=class{constructor(t,e,n=0,s=1/0){this.ray=new Ts(t,e),this.near=n,this.far=s,this.camera=null,this.layers=new hr,this.params={Mesh:{},Line:{threshold:1},LOD:{},Points:{threshold:1},Sprite:{}}}set(t,e){this.ray.set(t,e)}setFromCamera(t,e){e.isPerspectiveCamera?(this.ray.origin.setFromMatrixPosition(e.matrixWorld),this.ray.direction.set(t.x,t.y,.5).unproject(e).sub(this.ray.origin).normalize(),this.camera=e):e.isOrthographicCamera?(this.ray.origin.set(t.x,t.y,e.projectionMatrix.elements[14]).unproject(e),this.ray.direction.set(0,0,-1).transformDirection(e.matrixWorld),this.camera=e):he("Raycaster: Unsupported camera type: "+e.type)}setFromXRController(t){return _u.identity().extractRotation(t.matrixWorld),this.ray.origin.setFromMatrixPosition(t.matrixWorld),this.ray.direction.set(0,0,-1).applyMatrix4(_u),this}intersectObject(t,e=!0,n=[]){return I0(t,this,n,e),n.sort(vu),n}intersectObjects(t,e=!0,n=[]){for(let s=0,r=t.length;s<r;s++)I0(t[s],this,n,e);return n.sort(vu),n}};function vu(i,t){return i.distance-t.distance}function I0(i,t,e,n){let s=!0;if(i.layers.test(t.layers)&&i.raycast(t,e)===!1&&(s=!1),s===!0&&n===!0){let r=i.children;for(let a=0,o=r.length;a<o;a++)I0(r[a],t,e,!0)}}var L0=class i{static{i.prototype.isMatrix2=!0}constructor(t,e,n,s){this.elements=[1,0,0,1],t!==void 0&&this.set(t,e,n,s)}identity(){return this.set(1,0,0,1),this}fromArray(t,e=0){for(let n=0;n<4;n++)this.elements[n]=t[n+e];return this}set(t,e,n,s){let r=this.elements;return r[0]=t,r[2]=e,r[1]=n,r[3]=s,this}};function j0(i,t,e,n){let s=vp(n);switch(e){case W0:return i*t;case zl:return i*t/s.components*s.byteLength;case kl:return i*t/s.components*s.byteLength;case ps:return i*t*2/s.components*s.byteLength;case Hl:return i*t*2/s.components*s.byteLength;case X0:return i*t*3/s.components*s.byteLength;case ei:return i*t*4/s.components*s.byteLength;case Vl:return i*t*4/s.components*s.byteLength;case eo:case no:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*8;case io:case so:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*16;case Wl:case ql:return Math.max(i,16)*Math.max(t,8)/4;case Gl:case Xl:return Math.max(i,8)*Math.max(t,8)/2;case Yl:case $l:case Jl:case Kl:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*8;case Zl:case ro:case jl:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*16;case Ql:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*16;case tc:return Math.floor((i+4)/5)*Math.floor((t+3)/4)*16;case ec:return Math.floor((i+4)/5)*Math.floor((t+4)/5)*16;case nc:return Math.floor((i+5)/6)*Math.floor((t+4)/5)*16;case ic:return Math.floor((i+5)/6)*Math.floor((t+5)/6)*16;case sc:return Math.floor((i+7)/8)*Math.floor((t+4)/5)*16;case rc:return Math.floor((i+7)/8)*Math.floor((t+5)/6)*16;case ac:return Math.floor((i+7)/8)*Math.floor((t+7)/8)*16;case oc:return Math.floor((i+9)/10)*Math.floor((t+4)/5)*16;case lc:return Math.floor((i+9)/10)*Math.floor((t+5)/6)*16;case cc:return Math.floor((i+9)/10)*Math.floor((t+7)/8)*16;case hc:return Math.floor((i+9)/10)*Math.floor((t+9)/10)*16;case uc:return Math.floor((i+11)/12)*Math.floor((t+9)/10)*16;case fc:return Math.floor((i+11)/12)*Math.floor((t+11)/12)*16;case dc:case pc:case mc:return Math.ceil(i/4)*Math.ceil(t/4)*16;case gc:case xc:return Math.ceil(i/4)*Math.ceil(t/4)*8;case ao:case _c:return Math.ceil(i/4)*Math.ceil(t/4)*16}throw new Error(`Unable to determine texture byte length for ${e} format.`)}function vp(i){switch(i){case Fn:case k0:return{byteLength:1,components:1};case Rr:case H0:case un:return{byteLength:2,components:1};case Ol:case Bl:return{byteLength:2,components:4};case fi:case Fl:case ti:return{byteLength:4,components:1};case V0:case G0:return{byteLength:4,components:3}}throw new Error(`THREE.TextureUtils: Unknown texture type ${i}.`)}typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("register",{detail:{revision:"186"}}));typeof window<"u"&&(window.__THREE__?ue("WARNING: Multiple instances of Three.js being imported."):window.__THREE__="186");function Df(){let i=null,t=!1,e=null,n=null;function s(r,a){n=i.requestAnimationFrame(s),e(r,a)}return{start:function(){t!==!0&&e!==null&&i!==null&&(n=i.requestAnimationFrame(s),t=!0)},stop:function(){i!==null&&i.cancelAnimationFrame(n),t=!1},setAnimationLoop:function(r){e=r},setContext:function(r){i=r}}}function Ep(i){let t=new WeakMap;function e(o,l){let c=o.array,h=o.usage,f=c.byteLength,u=i.createBuffer();i.bindBuffer(l,u),i.bufferData(l,c,h),o.onUploadCallback();let d;if(c instanceof Float32Array)d=i.FLOAT;else if(typeof Float16Array<"u"&&c instanceof Float16Array)d=i.HALF_FLOAT;else if(c instanceof Uint16Array)o.isFloat16BufferAttribute?d=i.HALF_FLOAT:d=i.UNSIGNED_SHORT;else if(c instanceof Int16Array)d=i.SHORT;else if(c instanceof Uint32Array)d=i.UNSIGNED_INT;else if(c instanceof Int32Array)d=i.INT;else if(c instanceof Int8Array)d=i.BYTE;else if(c instanceof Uint8Array)d=i.UNSIGNED_BYTE;else if(c instanceof Uint8ClampedArray)d=i.UNSIGNED_BYTE;else throw new Error("THREE.WebGLAttributes: Unsupported buffer data format: "+c);return{buffer:u,type:d,bytesPerElement:c.BYTES_PER_ELEMENT,version:o.version,size:f}}function n(o,l,c){let h=l.array,f=l.updateRanges;if(i.bindBuffer(c,o),f.length===0)i.bufferSubData(c,0,h);else{f.sort((d,g)=>d.start-g.start);let u=0;for(let d=1;d<f.length;d++){let g=f[u],_=f[d];_.start<=g.start+g.count+1?g.count=Math.max(g.count,_.start+_.count-g.start):(++u,f[u]=_)}f.length=u+1;for(let d=0,g=f.length;d<g;d++){let _=f[d];i.bufferSubData(c,_.start*h.BYTES_PER_ELEMENT,h,_.start,_.count)}l.clearUpdateRanges()}l.onUploadCallback()}function s(o){return o.isInterleavedBufferAttribute&&(o=o.data),t.get(o)}function r(o){o.isInterleavedBufferAttribute&&(o=o.data);let l=t.get(o);l&&(i.deleteBuffer(l.buffer),t.delete(o))}function a(o,l){if(o.isInterleavedBufferAttribute&&(o=o.data),o.isGLBufferAttribute){let h=t.get(o);(!h||h.version<o.version)&&t.set(o,{buffer:o.buffer,type:o.type,bytesPerElement:o.elementSize,version:o.version});return}let c=t.get(o);if(c===void 0)t.set(o,e(o,l));else if(c.version<o.version){if(c.size!==o.array.byteLength)throw new Error("THREE.WebGLAttributes: The size of the buffer attribute's array buffer does not match the original size. Resizing buffer attributes is not supported.");n(c.buffer,o,l),c.version=o.version}}return{get:s,remove:r,update:a}}var Tp=`#ifdef USE_ALPHAHASH
	if ( diffuseColor.a < getAlphaHashThreshold( vPosition ) ) discard;
#endif`,wp=`#ifdef USE_ALPHAHASH
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
#endif`,Ap=`#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture2D( alphaMap, vAlphaMapUv ).g;
#endif`,Rp=`#ifdef USE_ALPHAMAP
	uniform sampler2D alphaMap;
#endif`,Cp=`#ifdef USE_ALPHATEST
	#ifdef ALPHA_TO_COVERAGE
	diffuseColor.a = smoothstep( alphaTest, alphaTest + fwidth( diffuseColor.a ), diffuseColor.a );
	if ( diffuseColor.a == 0.0 ) discard;
	#else
	if ( diffuseColor.a < alphaTest ) discard;
	#endif
#endif`,Pp=`#ifdef USE_ALPHATEST
	uniform float alphaTest;
#endif`,Ip=`#ifdef USE_AOMAP
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
#endif`,Lp=`#ifdef USE_AOMAP
	uniform sampler2D aoMap;
	uniform float aoMapIntensity;
#endif`,Dp=`#ifdef USE_BATCHING
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
#endif`,Np=`#ifdef USE_BATCHING
	mat4 batchingMatrix = getBatchingMatrix( getIndirectIndex( gl_DrawID ) );
#endif`,Up=`vec3 transformed = vec3( position );
#ifdef USE_ALPHAHASH
	vPosition = vec3( position );
#endif`,Fp=`vec3 objectNormal = vec3( normal );
#ifdef USE_TANGENT
	vec3 objectTangent = vec3( tangent.xyz );
#endif`,Op=`float G_BlinnPhong_Implicit( ) {
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
} // validated`,Bp=`#ifdef USE_IRIDESCENCE
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
#endif`,zp=`#ifdef USE_BUMPMAP
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
#endif`,kp=`#if NUM_CLIPPING_PLANES > 0
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
#endif`,Hp=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
	uniform vec4 clippingPlanes[ NUM_CLIPPING_PLANES ];
#endif`,Vp=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
#endif`,Gp=`#if NUM_CLIPPING_PLANES > 0
	vClipPosition = - mvPosition.xyz;
#endif`,Wp=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA )
	diffuseColor *= vColor;
#endif`,Xp=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA )
	varying vec4 vColor;
#endif`,qp=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
	varying vec4 vColor;
#endif`,Yp=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
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
#endif`,$p=`#define PI 3.141592653589793
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
} // validated`,Zp=`#ifdef ENVMAP_TYPE_CUBE_UV
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
#endif`,Jp=`vec3 transformedNormal = objectNormal;
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
#endif`,Kp=`#ifdef USE_DISPLACEMENTMAP
	uniform sampler2D displacementMap;
	uniform float displacementScale;
	uniform float displacementBias;
#endif`,jp=`#ifdef USE_DISPLACEMENTMAP
	transformed += normalize( objectNormal ) * ( texture2D( displacementMap, vDisplacementMapUv ).x * displacementScale + displacementBias );
#endif`,Qp=`#ifdef USE_EMISSIVEMAP
	vec4 emissiveColor = texture2D( emissiveMap, vEmissiveMapUv );
	#ifdef DECODE_VIDEO_TEXTURE_EMISSIVE
		emissiveColor = sRGBTransferEOTF( emissiveColor );
	#endif
	totalEmissiveRadiance *= emissiveColor.rgb;
#endif`,t1=`#ifdef USE_EMISSIVEMAP
	uniform sampler2D emissiveMap;
#endif`,e1="gl_FragColor = linearToOutputTexel( gl_FragColor );",n1=`vec4 LinearTransferOETF( in vec4 value ) {
	return value;
}
vec4 sRGBTransferEOTF( in vec4 value ) {
	return vec4( mix( pow( value.rgb * 0.9478672986 + vec3( 0.0521327014 ), vec3( 2.4 ) ), value.rgb * 0.0773993808, vec3( lessThanEqual( value.rgb, vec3( 0.04045 ) ) ) ), value.a );
}
vec4 sRGBTransferOETF( in vec4 value ) {
	return vec4( mix( pow( value.rgb, vec3( 0.41666 ) ) * 1.055 - vec3( 0.055 ), value.rgb * 12.92, vec3( lessThanEqual( value.rgb, vec3( 0.0031308 ) ) ) ), value.a );
}`,i1=`#ifdef USE_ENVMAP
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
#endif`,s1=`#ifdef USE_ENVMAP
	uniform float envMapIntensity;
	uniform mat3 envMapRotation;
	#ifdef ENVMAP_TYPE_CUBE
		uniform samplerCube envMap;
	#else
		uniform sampler2D envMap;
	#endif
#endif`,r1=`#ifdef USE_ENVMAP
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
#endif`,a1=`#ifdef USE_ENVMAP
	#if defined( USE_BUMPMAP ) || defined( USE_NORMALMAP ) || defined( PHONG ) || defined( LAMBERT )
		#define ENV_WORLDPOS
	#endif
	#ifdef ENV_WORLDPOS
		
		varying vec3 vWorldPosition;
	#else
		varying vec3 vReflect;
		uniform float refractionRatio;
	#endif
#endif`,o1=`#ifdef USE_ENVMAP
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
#endif`,l1=`#ifdef USE_FOG
	vFogDepth = - mvPosition.z;
#endif`,c1=`#ifdef USE_FOG
	varying float vFogDepth;
#endif`,h1=`#ifdef USE_FOG
	#ifdef FOG_EXP2
		float fogFactor = 1.0 - exp( - fogDensity * fogDensity * vFogDepth * vFogDepth );
	#else
		float fogFactor = smoothstep( fogNear, fogFar, vFogDepth );
	#endif
	gl_FragColor.rgb = mix( gl_FragColor.rgb, fogColor, fogFactor );
#endif`,u1=`#ifdef USE_FOG
	uniform vec3 fogColor;
	varying float vFogDepth;
	#ifdef FOG_EXP2
		uniform float fogDensity;
	#else
		uniform float fogNear;
		uniform float fogFar;
	#endif
#endif`,f1=`#ifdef USE_GRADIENTMAP
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
}`,d1=`#ifdef USE_LIGHTMAP
	uniform sampler2D lightMap;
	uniform float lightMapIntensity;
#endif`,p1=`LambertMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularStrength = specularStrength;`,m1=`varying vec3 vViewPosition;
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
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Lambert`,g1=`uniform bool receiveShadow;
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
#include <lightprobes_pars_fragment>`,x1=`#ifdef USE_ENVMAP
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
#endif`,_1=`ToonMaterial material;
material.diffuseColor = diffuseColor.rgb;`,v1=`varying vec3 vViewPosition;
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
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Toon`,y1=`BlinnPhongMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularColor = specular;
material.specularShininess = shininess;
material.specularStrength = specularStrength;`,M1=`varying vec3 vViewPosition;
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
#define RE_IndirectDiffuse		RE_IndirectDiffuse_BlinnPhong`,S1=`PhysicalMaterial material;
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
#endif`,b1=`uniform sampler2D dfgLUT;
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
}`,E1=`
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
#endif`,T1=`#if defined( RE_IndirectDiffuse )
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
#endif`,w1=`#if defined( RE_IndirectDiffuse )
	#if defined( LAMBERT ) || defined( PHONG )
		irradiance += iblIrradiance;
	#endif
	RE_IndirectDiffuse( irradiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif
#if defined( RE_IndirectSpecular )
	RE_IndirectSpecular( radiance, iblIrradiance, clearcoatRadiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif`,A1=`#ifdef USE_LIGHT_PROBES_GRID
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
#endif`,R1=`#if defined( USE_LOGARITHMIC_DEPTH_BUFFER )
	gl_FragDepth = vIsPerspective == 0.0 ? gl_FragCoord.z : log2( vFragDepth ) * logDepthBufFC * 0.5;
#endif`,C1=`#if defined( USE_LOGARITHMIC_DEPTH_BUFFER )
	uniform float logDepthBufFC;
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,P1=`#ifdef USE_LOGARITHMIC_DEPTH_BUFFER
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,I1=`#ifdef USE_LOGARITHMIC_DEPTH_BUFFER
	vFragDepth = 1.0 + gl_Position.w;
	vIsPerspective = float( isPerspectiveMatrix( projectionMatrix ) );
#endif`,L1=`#ifdef USE_MAP
	vec4 sampledDiffuseColor = texture2D( map, vMapUv );
	#ifdef DECODE_VIDEO_TEXTURE
		sampledDiffuseColor = sRGBTransferEOTF( sampledDiffuseColor );
	#endif
	diffuseColor *= sampledDiffuseColor;
#endif`,D1=`#ifdef USE_MAP
	uniform sampler2D map;
#endif`,N1=`#if defined( USE_MAP ) || defined( USE_ALPHAMAP )
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
#endif`,U1=`#if defined( USE_POINTS_UV )
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
#endif`,F1=`float metalnessFactor = metalness;
#ifdef USE_METALNESSMAP
	vec4 texelMetalness = texture2D( metalnessMap, vMetalnessMapUv );
	metalnessFactor *= texelMetalness.b;
#endif`,O1=`#ifdef USE_METALNESSMAP
	uniform sampler2D metalnessMap;
#endif`,B1=`#ifdef USE_INSTANCING_MORPH
	float morphTargetInfluences[ MORPHTARGETS_COUNT ];
	float morphTargetBaseInfluence = texelFetch( morphTexture, ivec2( 0, gl_InstanceID ), 0 ).r;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		morphTargetInfluences[i] =  texelFetch( morphTexture, ivec2( i + 1, gl_InstanceID ), 0 ).r;
	}
#endif`,z1=`#if defined( USE_MORPHCOLORS )
	vColor *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		#if defined( USE_COLOR_ALPHA )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ) * morphTargetInfluences[ i ];
		#elif defined( USE_COLOR )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ).rgb * morphTargetInfluences[ i ];
		#endif
	}
#endif`,k1=`#ifdef USE_MORPHNORMALS
	objectNormal *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) objectNormal += getMorph( gl_VertexID, i, 1 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,H1=`#ifdef USE_MORPHTARGETS
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
#endif`,V1=`#ifdef USE_MORPHTARGETS
	transformed *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) transformed += getMorph( gl_VertexID, i, 0 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,G1=`float faceDirection = gl_FrontFacing ? 1.0 : - 1.0;
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
vec3 nonPerturbedNormal = normal;`,W1=`#ifdef USE_NORMALMAP_OBJECTSPACE
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
#endif`,X1=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,q1=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,Y1=`#ifndef FLAT_SHADED
	vNormal = normalize( transformedNormal );
	#ifdef USE_TANGENT
		vTangent = normalize( transformedTangent );
		vBitangent = normalize( cross( vNormal, vTangent ) * tangent.w );
		#ifdef FLIP_SIDED
			vBitangent = - vBitangent;
		#endif
	#endif
#endif`,$1=`#ifdef USE_NORMALMAP
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
#endif`,Z1=`#ifdef USE_CLEARCOAT
	vec3 clearcoatNormal = nonPerturbedNormal;
#endif`,J1=`#ifdef USE_CLEARCOAT_NORMALMAP
	vec3 clearcoatMapN = texture2D( clearcoatNormalMap, vClearcoatNormalMapUv ).xyz * 2.0 - 1.0;
	clearcoatMapN.xy *= clearcoatNormalScale;
	clearcoatNormal = normalize( tbn2 * clearcoatMapN );
#endif`,K1=`#ifdef USE_CLEARCOATMAP
	uniform sampler2D clearcoatMap;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	uniform sampler2D clearcoatNormalMap;
	uniform vec2 clearcoatNormalScale;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	uniform sampler2D clearcoatRoughnessMap;
#endif`,j1=`#ifdef USE_IRIDESCENCEMAP
	uniform sampler2D iridescenceMap;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	uniform sampler2D iridescenceThicknessMap;
#endif`,Q1=`#ifdef OPAQUE
diffuseColor.a = 1.0;
#endif
#ifdef USE_TRANSMISSION
diffuseColor.a *= material.transmissionAlpha;
#endif
gl_FragColor = vec4( outgoingLight, diffuseColor.a );`,tm=`vec3 packNormalToRGB( const in vec3 normal ) {
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
}`,em=`#ifdef PREMULTIPLIED_ALPHA
	gl_FragColor.rgb *= gl_FragColor.a;
#endif`,nm=`vec4 mvPosition = vec4( transformed, 1.0 );
#ifdef USE_BATCHING
	mvPosition = batchingMatrix * mvPosition;
#endif
#ifdef USE_INSTANCING
	mvPosition = instanceMatrix * mvPosition;
#endif
mvPosition = modelViewMatrix * mvPosition;
gl_Position = projectionMatrix * mvPosition;`,im=`#ifdef DITHERING
	gl_FragColor.rgb = dithering( gl_FragColor.rgb );
#endif`,sm=`#ifdef DITHERING
	vec3 dithering( vec3 color ) {
		float grid_position = rand( gl_FragCoord.xy );
		vec3 dither_shift_RGB = vec3( 0.25 / 255.0, -0.25 / 255.0, 0.25 / 255.0 );
		dither_shift_RGB = mix( 2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position );
		return color + dither_shift_RGB;
	}
#endif`,rm=`float roughnessFactor = roughness;
#ifdef USE_ROUGHNESSMAP
	vec4 texelRoughness = texture2D( roughnessMap, vRoughnessMapUv );
	roughnessFactor *= texelRoughness.g;
#endif`,am=`#ifdef USE_ROUGHNESSMAP
	uniform sampler2D roughnessMap;
#endif`,om=`#if NUM_SPOT_LIGHT_COORDS > 0
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
#endif`,lm=`#if NUM_SPOT_LIGHT_COORDS > 0
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
#endif`,cm=`#if ( defined( USE_SHADOWMAP ) && ( NUM_DIR_LIGHT_SHADOWS > 0 || NUM_SUN_LIGHT_SHADOWS > 0 || NUM_POINT_LIGHT_SHADOWS > 0 ) ) || ( NUM_SPOT_LIGHT_COORDS > 0 )
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
#endif`,hm=`float getShadowMask() {
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
}`,um=`#ifdef USE_SKINNING
	mat4 boneMatX = getBoneMatrix( skinIndex.x );
	mat4 boneMatY = getBoneMatrix( skinIndex.y );
	mat4 boneMatZ = getBoneMatrix( skinIndex.z );
	mat4 boneMatW = getBoneMatrix( skinIndex.w );
#endif`,fm=`#ifdef USE_SKINNING
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
#endif`,dm=`#ifdef USE_SKINNING
	vec4 skinVertex = bindMatrix * vec4( transformed, 1.0 );
	vec4 skinned = vec4( 0.0 );
	skinned += boneMatX * skinVertex * skinWeight.x;
	skinned += boneMatY * skinVertex * skinWeight.y;
	skinned += boneMatZ * skinVertex * skinWeight.z;
	skinned += boneMatW * skinVertex * skinWeight.w;
	transformed = ( bindMatrixInverse * skinned ).xyz;
#endif`,pm=`#ifdef USE_SKINNING
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
#endif`,mm=`float specularStrength;
#ifdef USE_SPECULARMAP
	vec4 texelSpecular = texture2D( specularMap, vSpecularMapUv );
	specularStrength = texelSpecular.r;
#else
	specularStrength = 1.0;
#endif`,gm=`#ifdef USE_SPECULARMAP
	uniform sampler2D specularMap;
#endif`,xm=`#if defined( TONE_MAPPING )
	gl_FragColor.rgb = toneMapping( gl_FragColor.rgb );
#endif`,_m=`#ifndef saturate
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
vec3 CustomToneMapping( vec3 color ) { return color; }`,vm=`#ifdef USE_TRANSMISSION
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
#endif`,ym=`#ifdef USE_TRANSMISSION
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
#endif`,Mm=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
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
#endif`,Sm=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
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
#endif`,bm=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
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
#endif`,Em=`#if defined( USE_ENVMAP ) || defined( DISTANCE ) || defined ( USE_SHADOWMAP ) || defined ( USE_TRANSMISSION ) || NUM_SPOT_LIGHT_COORDS > 0
	vec4 worldPosition = vec4( transformed, 1.0 );
	#ifdef USE_BATCHING
		worldPosition = batchingMatrix * worldPosition;
	#endif
	#ifdef USE_INSTANCING
		worldPosition = instanceMatrix * worldPosition;
	#endif
	worldPosition = modelMatrix * worldPosition;
#endif`,Tm=`varying vec2 vUv;
uniform mat3 uvTransform;
void main() {
	vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	gl_Position = vec4( position.xy, 1.0, 1.0 );
}`,wm=`uniform sampler2D t2D;
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
}`,Am=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,Rm=`#ifdef ENVMAP_TYPE_CUBE
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
}`,Cm=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,Pm=`uniform samplerCube tCube;
uniform float tFlip;
uniform float opacity;
varying vec3 vWorldDirection;
void main() {
	vec4 texColor = textureCube( tCube, vec3( tFlip * vWorldDirection.x, vWorldDirection.yz ) );
	gl_FragColor = texColor;
	gl_FragColor.a *= opacity;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,Im=`#include <common>
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
}`,Lm=`#if DEPTH_PACKING == 3200
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
}`,Dm=`#define DISTANCE
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
}`,Nm=`#define DISTANCE
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
}`,Um=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
}`,Fm=`uniform sampler2D tEquirect;
varying vec3 vWorldDirection;
#include <common>
void main() {
	vec3 direction = normalize( vWorldDirection );
	vec2 sampleUV = equirectUv( direction );
	gl_FragColor = texture2D( tEquirect, sampleUV );
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,Om=`uniform float scale;
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
}`,Bm=`uniform vec3 diffuse;
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
}`,zm=`#include <common>
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
}`,km=`uniform vec3 diffuse;
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
}`,Hm=`#define LAMBERT
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
}`,Vm=`#define LAMBERT
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
}`,Gm=`#define MATCAP
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
}`,Wm=`#define MATCAP
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
}`,Xm=`#define NORMAL
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
}`,qm=`#define NORMAL
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
}`,Ym=`#define PHONG
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
}`,$m=`#define PHONG
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
}`,Zm=`#define STANDARD
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
}`,Jm=`#define STANDARD
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
}`,Km=`#define TOON
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
}`,jm=`#define TOON
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
}`,Qm=`uniform float size;
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
}`,tg=`uniform vec3 diffuse;
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
}`,eg=`#include <common>
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
}`,ng=`uniform vec3 color;
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
}`,ig=`uniform float rotation;
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
}`,sg=`uniform vec3 diffuse;
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
}`,be={alphahash_fragment:Tp,alphahash_pars_fragment:wp,alphamap_fragment:Ap,alphamap_pars_fragment:Rp,alphatest_fragment:Cp,alphatest_pars_fragment:Pp,aomap_fragment:Ip,aomap_pars_fragment:Lp,batching_pars_vertex:Dp,batching_vertex:Np,begin_vertex:Up,beginnormal_vertex:Fp,bsdfs:Op,iridescence_fragment:Bp,bumpmap_pars_fragment:zp,clipping_planes_fragment:kp,clipping_planes_pars_fragment:Hp,clipping_planes_pars_vertex:Vp,clipping_planes_vertex:Gp,color_fragment:Wp,color_pars_fragment:Xp,color_pars_vertex:qp,color_vertex:Yp,common:$p,cube_uv_reflection_fragment:Zp,defaultnormal_vertex:Jp,displacementmap_pars_vertex:Kp,displacementmap_vertex:jp,emissivemap_fragment:Qp,emissivemap_pars_fragment:t1,colorspace_fragment:e1,colorspace_pars_fragment:n1,envmap_fragment:i1,envmap_common_pars_fragment:s1,envmap_pars_fragment:r1,envmap_pars_vertex:a1,envmap_physical_pars_fragment:x1,envmap_vertex:o1,fog_vertex:l1,fog_pars_vertex:c1,fog_fragment:h1,fog_pars_fragment:u1,gradientmap_pars_fragment:f1,lightmap_pars_fragment:d1,lights_lambert_fragment:p1,lights_lambert_pars_fragment:m1,lights_pars_begin:g1,lights_toon_fragment:_1,lights_toon_pars_fragment:v1,lights_phong_fragment:y1,lights_phong_pars_fragment:M1,lights_physical_fragment:S1,lights_physical_pars_fragment:b1,lights_fragment_begin:E1,lights_fragment_maps:T1,lights_fragment_end:w1,lightprobes_pars_fragment:A1,logdepthbuf_fragment:R1,logdepthbuf_pars_fragment:C1,logdepthbuf_pars_vertex:P1,logdepthbuf_vertex:I1,map_fragment:L1,map_pars_fragment:D1,map_particle_fragment:N1,map_particle_pars_fragment:U1,metalnessmap_fragment:F1,metalnessmap_pars_fragment:O1,morphinstance_vertex:B1,morphcolor_vertex:z1,morphnormal_vertex:k1,morphtarget_pars_vertex:H1,morphtarget_vertex:V1,normal_fragment_begin:G1,normal_fragment_maps:W1,normal_pars_fragment:X1,normal_pars_vertex:q1,normal_vertex:Y1,normalmap_pars_fragment:$1,clearcoat_normal_fragment_begin:Z1,clearcoat_normal_fragment_maps:J1,clearcoat_pars_fragment:K1,iridescence_pars_fragment:j1,opaque_fragment:Q1,packing:tm,premultiplied_alpha_fragment:em,project_vertex:nm,dithering_fragment:im,dithering_pars_fragment:sm,roughnessmap_fragment:rm,roughnessmap_pars_fragment:am,shadowmap_pars_fragment:om,shadowmap_pars_vertex:lm,shadowmap_vertex:cm,shadowmask_pars_fragment:hm,skinbase_vertex:um,skinning_pars_vertex:fm,skinning_vertex:dm,skinnormal_vertex:pm,specularmap_fragment:mm,specularmap_pars_fragment:gm,tonemapping_fragment:xm,tonemapping_pars_fragment:_m,transmission_fragment:vm,transmission_pars_fragment:ym,uv_pars_fragment:Mm,uv_pars_vertex:Sm,uv_vertex:bm,worldpos_vertex:Em,background_vert:Tm,background_frag:wm,backgroundCube_vert:Am,backgroundCube_frag:Rm,cube_vert:Cm,cube_frag:Pm,depth_vert:Im,depth_frag:Lm,distance_vert:Dm,distance_frag:Nm,equirect_vert:Um,equirect_frag:Fm,linedashed_vert:Om,linedashed_frag:Bm,meshbasic_vert:zm,meshbasic_frag:km,meshlambert_vert:Hm,meshlambert_frag:Vm,meshmatcap_vert:Gm,meshmatcap_frag:Wm,meshnormal_vert:Xm,meshnormal_frag:qm,meshphong_vert:Ym,meshphong_frag:$m,meshphysical_vert:Zm,meshphysical_frag:Jm,meshtoon_vert:Km,meshtoon_frag:jm,points_vert:Qm,points_frag:tg,shadow_vert:eg,shadow_frag:ng,sprite_vert:ig,sprite_frag:sg},Vt={common:{diffuse:{value:new se(16777215)},opacity:{value:1},map:{value:null},mapTransform:{value:new xe},alphaMap:{value:null},alphaMapTransform:{value:new xe},alphaTest:{value:0}},specularmap:{specularMap:{value:null},specularMapTransform:{value:new xe}},envmap:{envMap:{value:null},envMapRotation:{value:new xe},reflectivity:{value:1},ior:{value:1.5},refractionRatio:{value:.98},dfgLUT:{value:null}},aomap:{aoMap:{value:null},aoMapIntensity:{value:1},aoMapTransform:{value:new xe}},lightmap:{lightMap:{value:null},lightMapIntensity:{value:1},lightMapTransform:{value:new xe}},bumpmap:{bumpMap:{value:null},bumpMapTransform:{value:new xe},bumpScale:{value:1}},normalmap:{normalMap:{value:null},normalMapTransform:{value:new xe},normalScale:{value:new ft(1,1)}},displacementmap:{displacementMap:{value:null},displacementMapTransform:{value:new xe},displacementScale:{value:1},displacementBias:{value:0}},emissivemap:{emissiveMap:{value:null},emissiveMapTransform:{value:new xe}},metalnessmap:{metalnessMap:{value:null},metalnessMapTransform:{value:new xe}},roughnessmap:{roughnessMap:{value:null},roughnessMapTransform:{value:new xe}},gradientmap:{gradientMap:{value:null}},fog:{fogDensity:{value:25e-5},fogNear:{value:1},fogFar:{value:2e3},fogColor:{value:new se(16777215)}},lights:{ambientLightColor:{value:[]},lightProbe:{value:[]},sunLights:{value:[],properties:{direction:{},color:{}}},sunLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},sunShadowMatrix:{value:[]},sunShadowCascade:{value:[]},directionalLights:{value:[],properties:{direction:{},color:{}}},directionalLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},directionalShadowMatrix:{value:[]},spotLights:{value:[],properties:{color:{},position:{},direction:{},distance:{},coneCos:{},penumbraCos:{},decay:{}}},spotLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},spotLightMap:{value:[]},spotLightMatrix:{value:[]},pointLights:{value:[],properties:{color:{},position:{},decay:{},distance:{}}},pointLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{},shadowCameraNear:{},shadowCameraFar:{}}},pointShadowMatrix:{value:[]},hemisphereLights:{value:[],properties:{direction:{},skyColor:{},groundColor:{}}},rectAreaLights:{value:[],properties:{color:{},position:{},width:{},height:{}}},ltc_1:{value:null},ltc_2:{value:null},probesSH:{value:null},probesMin:{value:new P},probesMax:{value:new P},probesResolution:{value:new P}},points:{diffuse:{value:new se(16777215)},opacity:{value:1},size:{value:1},scale:{value:1},map:{value:null},alphaMap:{value:null},alphaMapTransform:{value:new xe},alphaTest:{value:0},uvTransform:{value:new xe}},sprite:{diffuse:{value:new se(16777215)},opacity:{value:1},center:{value:new ft(.5,.5)},rotation:{value:0},map:{value:null},mapTransform:{value:new xe},alphaMap:{value:null},alphaMapTransform:{value:new xe},alphaTest:{value:0}}},Ai={basic:{uniforms:In([Vt.common,Vt.specularmap,Vt.envmap,Vt.aomap,Vt.lightmap,Vt.fog]),vertexShader:be.meshbasic_vert,fragmentShader:be.meshbasic_frag},lambert:{uniforms:In([Vt.common,Vt.specularmap,Vt.envmap,Vt.aomap,Vt.lightmap,Vt.emissivemap,Vt.bumpmap,Vt.normalmap,Vt.displacementmap,Vt.fog,Vt.lights,{emissive:{value:new se(0)},envMapIntensity:{value:1}}]),vertexShader:be.meshlambert_vert,fragmentShader:be.meshlambert_frag},phong:{uniforms:In([Vt.common,Vt.specularmap,Vt.envmap,Vt.aomap,Vt.lightmap,Vt.emissivemap,Vt.bumpmap,Vt.normalmap,Vt.displacementmap,Vt.fog,Vt.lights,{emissive:{value:new se(0)},specular:{value:new se(1118481)},shininess:{value:30},envMapIntensity:{value:1}}]),vertexShader:be.meshphong_vert,fragmentShader:be.meshphong_frag},standard:{uniforms:In([Vt.common,Vt.envmap,Vt.aomap,Vt.lightmap,Vt.emissivemap,Vt.bumpmap,Vt.normalmap,Vt.displacementmap,Vt.roughnessmap,Vt.metalnessmap,Vt.fog,Vt.lights,{emissive:{value:new se(0)},roughness:{value:1},metalness:{value:0},envMapIntensity:{value:1}}]),vertexShader:be.meshphysical_vert,fragmentShader:be.meshphysical_frag},toon:{uniforms:In([Vt.common,Vt.aomap,Vt.lightmap,Vt.emissivemap,Vt.bumpmap,Vt.normalmap,Vt.displacementmap,Vt.gradientmap,Vt.fog,Vt.lights,{emissive:{value:new se(0)}}]),vertexShader:be.meshtoon_vert,fragmentShader:be.meshtoon_frag},matcap:{uniforms:In([Vt.common,Vt.bumpmap,Vt.normalmap,Vt.displacementmap,Vt.fog,{matcap:{value:null}}]),vertexShader:be.meshmatcap_vert,fragmentShader:be.meshmatcap_frag},points:{uniforms:In([Vt.points,Vt.fog]),vertexShader:be.points_vert,fragmentShader:be.points_frag},dashed:{uniforms:In([Vt.common,Vt.fog,{scale:{value:1},dashSize:{value:1},totalSize:{value:2}}]),vertexShader:be.linedashed_vert,fragmentShader:be.linedashed_frag},depth:{uniforms:In([Vt.common,Vt.displacementmap]),vertexShader:be.depth_vert,fragmentShader:be.depth_frag},normal:{uniforms:In([Vt.common,Vt.bumpmap,Vt.normalmap,Vt.displacementmap,{opacity:{value:1}}]),vertexShader:be.meshnormal_vert,fragmentShader:be.meshnormal_frag},sprite:{uniforms:In([Vt.sprite,Vt.fog]),vertexShader:be.sprite_vert,fragmentShader:be.sprite_frag},background:{uniforms:{uvTransform:{value:new xe},t2D:{value:null},backgroundIntensity:{value:1}},vertexShader:be.background_vert,fragmentShader:be.background_frag},backgroundCube:{uniforms:{envMap:{value:null},backgroundBlurriness:{value:0},backgroundIntensity:{value:1},backgroundRotation:{value:new xe}},vertexShader:be.backgroundCube_vert,fragmentShader:be.backgroundCube_frag},cube:{uniforms:{tCube:{value:null},tFlip:{value:-1},opacity:{value:1}},vertexShader:be.cube_vert,fragmentShader:be.cube_frag},equirect:{uniforms:{tEquirect:{value:null}},vertexShader:be.equirect_vert,fragmentShader:be.equirect_frag},distance:{uniforms:In([Vt.common,Vt.displacementmap,{referencePosition:{value:new P},nearDistance:{value:1},farDistance:{value:1e3}}]),vertexShader:be.distance_vert,fragmentShader:be.distance_frag},shadow:{uniforms:In([Vt.lights,Vt.fog,{color:{value:new se(0)},opacity:{value:1}}]),vertexShader:be.shadow_vert,fragmentShader:be.shadow_frag}};Ai.physical={uniforms:In([Ai.standard.uniforms,{clearcoat:{value:0},clearcoatMap:{value:null},clearcoatMapTransform:{value:new xe},clearcoatNormalMap:{value:null},clearcoatNormalMapTransform:{value:new xe},clearcoatNormalScale:{value:new ft(1,1)},clearcoatRoughness:{value:0},clearcoatRoughnessMap:{value:null},clearcoatRoughnessMapTransform:{value:new xe},dispersion:{value:0},retroreflectivity:{value:0},iridescence:{value:0},iridescenceMap:{value:null},iridescenceMapTransform:{value:new xe},iridescenceIOR:{value:1.3},iridescenceThicknessMinimum:{value:100},iridescenceThicknessMaximum:{value:400},iridescenceThicknessMap:{value:null},iridescenceThicknessMapTransform:{value:new xe},sheen:{value:0},sheenColor:{value:new se(0)},sheenColorMap:{value:null},sheenColorMapTransform:{value:new xe},sheenRoughness:{value:1},sheenRoughnessMap:{value:null},sheenRoughnessMapTransform:{value:new xe},transmission:{value:0},transmissionMap:{value:null},transmissionMapTransform:{value:new xe},transmissionSamplerSize:{value:new ft},transmissionSamplerMap:{value:null},thickness:{value:0},thicknessMap:{value:null},thicknessMapTransform:{value:new xe},attenuationDistance:{value:0},attenuationColor:{value:new se(0)},specularColor:{value:new se(1,1,1)},specularColorMap:{value:null},specularColorMapTransform:{value:new xe},specularIntensity:{value:1},specularIntensityMap:{value:null},specularIntensityMapTransform:{value:new xe},anisotropyVector:{value:new ft},anisotropyMap:{value:null},anisotropyMapTransform:{value:new xe}}]),vertexShader:be.meshphysical_vert,fragmentShader:be.meshphysical_frag};var Sc={r:0,b:0,g:0},rg=new De,Nf=new xe;Nf.set(-1,0,0,0,1,0,0,0,1);function ag(i,t,e,n,s,r){let a=new se(0),o=s===!0?0:1,l,c,h=null,f=0,u=null;function d(S){let A=S.isScene===!0?S.background:null;if(A&&A.isTexture){let v=S.backgroundBlurriness>0;A=t.get(A,v)}return A}function g(S){let A=!1,v=d(S);v===null?m(a,o):v&&v.isColor&&(m(v,1),A=!0);let b=i.xr.getEnvironmentBlendMode();b==="additive"?e.buffers.color.setClear(0,0,0,1,r):b==="alpha-blend"&&e.buffers.color.setClear(0,0,0,0,r),(i.autoClear||A)&&(e.buffers.depth.setTest(!0),e.buffers.depth.setMask(!0),e.buffers.color.setMask(!0),i.clear(i.autoClearColor,i.autoClearDepth,i.autoClearStencil))}function _(S,A){let v=d(A);v&&(v.isCubeTexture||v.mapping===Qa)?(c===void 0&&(c=new Se(new mr(1,1,1),new He({name:"BackgroundCubeMaterial",uniforms:Ps(Ai.backgroundCube.uniforms),vertexShader:Ai.backgroundCube.vertexShader,fragmentShader:Ai.backgroundCube.fragmentShader,side:bn,depthTest:!1,depthWrite:!1,fog:!1,allowOverride:!1})),c.geometry.deleteAttribute("normal"),c.geometry.deleteAttribute("uv"),c.onBeforeRender=function(b,E,C){this.matrixWorld.copyPosition(C.matrixWorld)},Object.defineProperty(c.material,"envMap",{get:function(){return this.uniforms.envMap.value}}),n.update(c)),c.material.uniforms.envMap.value=v,c.material.uniforms.backgroundBlurriness.value=A.backgroundBlurriness,c.material.uniforms.backgroundIntensity.value=A.backgroundIntensity,c.material.uniforms.backgroundRotation.value.setFromMatrix4(rg.makeRotationFromEuler(A.backgroundRotation)).transpose(),v.isCubeTexture&&v.isRenderTargetTexture===!1&&c.material.uniforms.backgroundRotation.value.premultiply(Nf),c.material.toneMapped=Ae.getTransfer(v.colorSpace)!==Fe,(h!==v||f!==v.version||u!==i.toneMapping)&&(c.material.needsUpdate=!0,h=v,f=v.version,u=i.toneMapping),c.layers.enableAll(),S.unshift(c,c.geometry,c.material,0,0,null)):v&&v.isTexture&&(l===void 0&&(l=new Se(new rs(2,2),new He({name:"BackgroundMaterial",uniforms:Ps(Ai.background.uniforms),vertexShader:Ai.background.vertexShader,fragmentShader:Ai.background.fragmentShader,side:hs,depthTest:!1,depthWrite:!1,fog:!1,allowOverride:!1})),l.geometry.deleteAttribute("normal"),Object.defineProperty(l.material,"map",{get:function(){return this.uniforms.t2D.value}}),n.update(l)),l.material.uniforms.t2D.value=v,l.material.uniforms.backgroundIntensity.value=A.backgroundIntensity,l.material.toneMapped=Ae.getTransfer(v.colorSpace)!==Fe,v.matrixAutoUpdate===!0&&v.updateMatrix(),l.material.uniforms.uvTransform.value.copy(v.matrix),(h!==v||f!==v.version||u!==i.toneMapping)&&(l.material.needsUpdate=!0,h=v,f=v.version,u=i.toneMapping),l.layers.enableAll(),S.unshift(l,l.geometry,l.material,0,0,null))}function m(S,A){S.getRGB(Sc,Z0(i)),e.buffers.color.setClear(Sc.r,Sc.g,Sc.b,A,r)}function p(){c!==void 0&&(c.geometry.dispose(),c.material.dispose(),c=void 0),l!==void 0&&(l.geometry.dispose(),l.material.dispose(),l=void 0)}return{getClearColor:function(){return a},setClearColor:function(S,A=1){a.set(S),o=A,m(a,o)},getClearAlpha:function(){return o},setClearAlpha:function(S){o=S,m(a,o)},render:g,addToRenderList:_,dispose:p}}function og(i,t){let e=i.getParameter(i.MAX_VERTEX_ATTRIBS),n={},s=u(null),r=s,a=!1;function o(N,H,W,U,G){let rt=!1,j=f(N,U,W,H);r!==j&&(r=j,c(r.object)),rt=d(N,U,W,G),rt&&g(N,U,W,G),G!==null&&t.update(G,i.ELEMENT_ARRAY_BUFFER),(rt||a)&&(a=!1,v(N,H,W,U),G!==null&&i.bindBuffer(i.ELEMENT_ARRAY_BUFFER,t.get(G).buffer))}function l(){return i.createVertexArray()}function c(N){return i.bindVertexArray(N)}function h(N){return i.deleteVertexArray(N)}function f(N,H,W,U){let G=U.wireframe===!0,rt=n[H.id];rt===void 0&&(rt={},n[H.id]=rt);let j=N.isInstancedMesh===!0?N.id:0,pt=rt[j];pt===void 0&&(pt={},rt[j]=pt);let st=pt[W.id];st===void 0&&(st={},pt[W.id]=st);let lt=st[G];return lt===void 0&&(lt=u(l()),st[G]=lt),lt}function u(N){let H=[],W=[],U=[];for(let G=0;G<e;G++)H[G]=0,W[G]=0,U[G]=0;return{geometry:null,program:null,wireframe:!1,newAttributes:H,enabledAttributes:W,attributeDivisors:U,object:N,attributes:{},index:null}}function d(N,H,W,U){let G=r.attributes,rt=H.attributes,j=0,pt=W.getAttributes();for(let st in pt)if(pt[st].location>=0){let O=G[st],vt=rt[st];if(vt===void 0&&(st==="instanceMatrix"&&N.instanceMatrix&&(vt=N.instanceMatrix),st==="instanceColor"&&N.instanceColor&&(vt=N.instanceColor)),O===void 0||O.attribute!==vt||vt&&O.data!==vt.data)return!0;j++}return r.attributesNum!==j||r.index!==U}function g(N,H,W,U){let G={},rt=H.attributes,j=0,pt=W.getAttributes();for(let st in pt)if(pt[st].location>=0){let O=rt[st];O===void 0&&(st==="instanceMatrix"&&N.instanceMatrix&&(O=N.instanceMatrix),st==="instanceColor"&&N.instanceColor&&(O=N.instanceColor));let vt={};vt.attribute=O,O&&O.data&&(vt.data=O.data),G[st]=vt,j++}r.attributes=G,r.attributesNum=j,r.index=U}function _(){let N=r.newAttributes;for(let H=0,W=N.length;H<W;H++)N[H]=0}function m(N){p(N,0)}function p(N,H){let W=r.newAttributes,U=r.enabledAttributes,G=r.attributeDivisors;W[N]=1,U[N]===0&&(i.enableVertexAttribArray(N),U[N]=1),G[N]!==H&&(i.vertexAttribDivisor(N,H),G[N]=H)}function S(){let N=r.newAttributes,H=r.enabledAttributes;for(let W=0,U=H.length;W<U;W++)H[W]!==N[W]&&(i.disableVertexAttribArray(W),H[W]=0)}function A(N,H,W,U,G,rt,j){j===!0?i.vertexAttribIPointer(N,H,W,G,rt):i.vertexAttribPointer(N,H,W,U,G,rt)}function v(N,H,W,U){_();let G=U.attributes,rt=W.getAttributes(),j=H.defaultAttributeValues;for(let pt in rt){let st=rt[pt];if(st.location>=0){let lt=G[pt];if(lt===void 0&&(pt==="instanceMatrix"&&N.instanceMatrix&&(lt=N.instanceMatrix),pt==="instanceColor"&&N.instanceColor&&(lt=N.instanceColor)),lt!==void 0){let O=lt.normalized,vt=lt.itemSize,St=t.get(lt);if(St===void 0)continue;let Et=St.buffer,Xt=St.type,gt=St.bytesPerElement,J=Xt===i.INT||Xt===i.UNSIGNED_INT||lt.gpuType===Fl;if(lt.isInterleavedBufferAttribute){let q=lt.data,ht=q.stride,wt=lt.offset;if(q.isInstancedInterleavedBuffer){for(let ct=0;ct<st.locationSize;ct++)p(st.location+ct,q.meshPerAttribute);N.isInstancedMesh!==!0&&U._maxInstanceCount===void 0&&(U._maxInstanceCount=q.meshPerAttribute*q.count)}else for(let ct=0;ct<st.locationSize;ct++)m(st.location+ct);i.bindBuffer(i.ARRAY_BUFFER,Et);for(let ct=0;ct<st.locationSize;ct++)A(st.location+ct,vt/st.locationSize,Xt,O,ht*gt,(wt+vt/st.locationSize*ct)*gt,J)}else{if(lt.isInstancedBufferAttribute){for(let q=0;q<st.locationSize;q++)p(st.location+q,lt.meshPerAttribute);N.isInstancedMesh!==!0&&U._maxInstanceCount===void 0&&(U._maxInstanceCount=lt.meshPerAttribute*lt.count)}else for(let q=0;q<st.locationSize;q++)m(st.location+q);i.bindBuffer(i.ARRAY_BUFFER,Et);for(let q=0;q<st.locationSize;q++)A(st.location+q,vt/st.locationSize,Xt,O,vt*gt,vt/st.locationSize*q*gt,J)}}else if(j!==void 0){let O=j[pt];if(O!==void 0)switch(O.length){case 2:i.vertexAttrib2fv(st.location,O);break;case 3:i.vertexAttrib3fv(st.location,O);break;case 4:i.vertexAttrib4fv(st.location,O);break;default:i.vertexAttrib1fv(st.location,O)}}}}S()}function b(){w();for(let N in n){let H=n[N];for(let W in H){let U=H[W];for(let G in U){let rt=U[G];for(let j in rt)h(rt[j].object),delete rt[j];delete U[G]}}delete n[N]}}function E(N){if(n[N.id]===void 0)return;let H=n[N.id];for(let W in H){let U=H[W];for(let G in U){let rt=U[G];for(let j in rt)h(rt[j].object),delete rt[j];delete U[G]}}delete n[N.id]}function C(N){for(let H in n){let W=n[H];for(let U in W){let G=W[U];if(G[N.id]===void 0)continue;let rt=G[N.id];for(let j in rt)h(rt[j].object),delete rt[j];delete G[N.id]}}}function y(N){for(let H in n){let W=n[H],U=N.isInstancedMesh===!0?N.id:0,G=W[U];if(G!==void 0){for(let rt in G){let j=G[rt];for(let pt in j)h(j[pt].object),delete j[pt];delete G[rt]}delete W[U],Object.keys(W).length===0&&delete n[H]}}}function w(){I(),a=!0,r!==s&&(r=s,c(r.object))}function I(){s.geometry=null,s.program=null,s.wireframe=!1}return{setup:o,reset:w,resetDefaultState:I,dispose:b,releaseStatesOfGeometry:E,releaseStatesOfObject:y,releaseStatesOfProgram:C,initAttributes:_,enableAttribute:m,disableUnusedAttributes:S}}function lg(i,t,e){let n;function s(l){n=l}function r(l,c){i.drawArrays(n,l,c),e.update(c,n,1)}function a(l,c,h){h!==0&&(i.drawArraysInstanced(n,l,c,h),e.update(c,n,h))}function o(l,c,h){if(h===0)return;t.get("WEBGL_multi_draw").multiDrawArraysWEBGL(n,l,0,c,0,h);let u=0;for(let d=0;d<h;d++)u+=c[d];e.update(u,n,1)}this.setMode=s,this.render=r,this.renderInstances=a,this.renderMultiDraw=o}function cg(i,t,e,n){let s;function r(){if(s!==void 0)return s;if(t.has("EXT_texture_filter_anisotropic")===!0){let C=t.get("EXT_texture_filter_anisotropic");s=i.getParameter(C.MAX_TEXTURE_MAX_ANISOTROPY_EXT)}else s=0;return s}function a(C){return!(C!==ei&&n.convert(C)!==i.getParameter(i.IMPLEMENTATION_COLOR_READ_FORMAT))}function o(C){let y=C===un&&(t.has("EXT_color_buffer_half_float")||t.has("EXT_color_buffer_float"));return!(C!==Fn&&C!==ti&&!y&&n.convert(C)!==i.getParameter(i.IMPLEMENTATION_COLOR_READ_TYPE))}function l(C){if(C==="highp"){if(i.getShaderPrecisionFormat(i.VERTEX_SHADER,i.HIGH_FLOAT).precision>0&&i.getShaderPrecisionFormat(i.FRAGMENT_SHADER,i.HIGH_FLOAT).precision>0)return"highp";C="mediump"}return C==="mediump"&&i.getShaderPrecisionFormat(i.VERTEX_SHADER,i.MEDIUM_FLOAT).precision>0&&i.getShaderPrecisionFormat(i.FRAGMENT_SHADER,i.MEDIUM_FLOAT).precision>0?"mediump":"lowp"}let c=e.precision!==void 0?e.precision:"highp",h=l(c);h!==c&&(ue("WebGLRenderer:",c,"not supported, using",h,"instead."),c=h);let f=e.logarithmicDepthBuffer===!0,u=e.reversedDepthBuffer===!0&&t.has("EXT_clip_control");e.reversedDepthBuffer===!0&&u===!1&&ue("WebGLRenderer: Unable to use reversed depth buffer due to missing EXT_clip_control extension. Fallback to default depth buffer.");let d=i.getParameter(i.MAX_TEXTURE_IMAGE_UNITS),g=i.getParameter(i.MAX_VERTEX_TEXTURE_IMAGE_UNITS),_=i.getParameter(i.MAX_TEXTURE_SIZE),m=i.getParameter(i.MAX_CUBE_MAP_TEXTURE_SIZE),p=i.getParameter(i.MAX_VERTEX_ATTRIBS),S=i.getParameter(i.MAX_VERTEX_UNIFORM_VECTORS),A=i.getParameter(i.MAX_VARYING_VECTORS),v=i.getParameter(i.MAX_FRAGMENT_UNIFORM_VECTORS),b=i.getParameter(i.MAX_SAMPLES),E=i.getParameter(i.SAMPLES);return{isWebGL2:!0,getMaxAnisotropy:r,getMaxPrecision:l,textureFormatReadable:a,textureTypeReadable:o,precision:c,logarithmicDepthBuffer:f,reversedDepthBuffer:u,maxTextures:d,maxVertexTextures:g,maxTextureSize:_,maxCubemapSize:m,maxAttributes:p,maxVertexUniforms:S,maxVaryings:A,maxFragmentUniforms:v,maxSamples:b,samples:E}}function hg(i){let t=this,e=null,n=0,s=!1,r=!1,a=new oi,o=new xe,l={value:null,needsUpdate:!1};this.uniform=l,this.numPlanes=0,this.numIntersection=0,this.init=function(f,u){let d=f.length!==0||u||n!==0||s;return s=u,n=f.length,d},this.beginShadows=function(){r=!0,h(null)},this.endShadows=function(){r=!1},this.setGlobalState=function(f,u){e=h(f,u,0)},this.setState=function(f,u,d){let g=f.clippingPlanes,_=f.clipIntersection,m=f.clipShadows,p=i.get(f);if(!s||g===null||g.length===0||r&&!m)r?h(null):c();else{let S=r?0:n,A=S*4,v=p.clippingState||null;l.value=v,v=h(g,u,A,d);for(let b=0;b!==A;++b)v[b]=e[b];p.clippingState=v,this.numIntersection=_?this.numPlanes:0,this.numPlanes+=S}};function c(){l.value!==e&&(l.value=e,l.needsUpdate=n>0),t.numPlanes=n,t.numIntersection=0}function h(f,u,d,g){let _=f!==null?f.length:0,m=null;if(_!==0){if(m=l.value,g!==!0||m===null){let p=d+_*4,S=u.matrixWorldInverse;o.getNormalMatrix(S),(m===null||m.length<p)&&(m=new Float32Array(p));for(let A=0,v=d;A!==_;++A,v+=4)a.copy(f[A]).applyMatrix4(S,o),a.normal.toArray(m,v),m[v+3]=a.constant}l.value=m,l.needsUpdate=!0}return t.numPlanes=_,t.numIntersection=0,m}}var Ir=4,ug=6,fg=20,dg=256,oo=new cs,ff=new se,Q0=null,th=0,eh=0,nh=!1,pg=new P,Is=new P,Ec=class{constructor(t){this._renderer=t,this._pingPongRenderTarget=null,this._lodMax=0,this._cubeSize=0,this._sizeLods=[],this._lodMeshes=[],this._backgroundBox=null,this._cubemapMaterial=null,this._equirectMaterial=null,this._blurMaterial=null,this._ggxMaterial=null}fromScene(t,e=0,n=.1,s=100,r={}){let{size:a=256,position:o=pg}=r;Q0=this._renderer.getRenderTarget(),th=this._renderer.getActiveCubeFace(),eh=this._renderer.getActiveMipmapLevel(),nh=this._renderer.xr.enabled,this._renderer.xr.enabled=!1,this._setSize(a);let l=this._allocateTargets();return l.depthBuffer=!0,this._sceneToCubeUV(t,n,s,l,o),e>0&&this._blur(l,0,0,e),this._applyPMREM(l),this._cleanup(l),l}fromEquirectangular(t,e=null){return this._fromTexture(t,e)}fromCubemap(t,e=null){return this._fromTexture(t,e)}compileCubemapShader(){this._cubemapMaterial===null&&(this._cubemapMaterial=mf(),this._compileMaterial(this._cubemapMaterial))}compileEquirectangularShader(){this._equirectMaterial===null&&(this._equirectMaterial=pf(),this._compileMaterial(this._equirectMaterial))}dispose(){this._dispose(),this._cubemapMaterial!==null&&this._cubemapMaterial.dispose(),this._equirectMaterial!==null&&this._equirectMaterial.dispose(),this._backgroundBox!==null&&(this._backgroundBox.geometry.dispose(),this._backgroundBox.material.dispose())}_setSize(t){this._lodMax=Math.floor(Math.log2(t)),this._cubeSize=Math.pow(2,this._lodMax)}_dispose(){this._blurMaterial!==null&&this._blurMaterial.dispose(),this._ggxMaterial!==null&&this._ggxMaterial.dispose(),this._pingPongRenderTarget!==null&&this._pingPongRenderTarget.dispose();for(let t=0;t<this._lodMeshes.length;t++)this._lodMeshes[t].geometry.dispose()}_cleanup(t){this._renderer.setRenderTarget(Q0,th,eh),this._renderer.xr.enabled=nh,t.scissorTest=!1,Pr(t,0,0,t.width,t.height)}_fromTexture(t,e){t.mapping===fs||t.mapping===Cs?this._setSize(t.image.length===0?16:t.image[0].width||t.image[0].image.width):this._setSize(t.image.width/4),Q0=this._renderer.getRenderTarget(),th=this._renderer.getActiveCubeFace(),eh=this._renderer.getActiveMipmapLevel(),nh=this._renderer.xr.enabled,this._renderer.xr.enabled=!1;let n=e||this._allocateTargets();return this._textureToCubeUV(t,n),this._applyPMREM(n),this._cleanup(n),n}_allocateTargets(){let t=3*Math.max(this._cubeSize,112),e=4*this._cubeSize,n={magFilter:Sn,minFilter:Sn,generateMipmaps:!1,type:un,format:ei,colorSpace:la,depthBuffer:!1},s=df(t,e,n);if(this._pingPongRenderTarget===null||this._pingPongRenderTarget.width!==t||this._pingPongRenderTarget.height!==e){this._pingPongRenderTarget!==null&&this._dispose(),this._pingPongRenderTarget=df(t,e,n);let{_lodMax:r}=this;({lodMeshes:this._lodMeshes,sizeLods:this._sizeLods}=mg(r)),this._blurMaterial=xg(r,t,e),this._ggxMaterial=gg(r,t,e)}return s}_compileMaterial(t){let e=new Se(new Ie,t);this._renderer.compile(e,oo)}_sceneToCubeUV(t,e,n,s,r){let l=new Mn(90,1,e,n),c=[1,-1,1,1,1,1],h=[1,1,1,-1,-1,-1],f=this._renderer,u=f.autoClear,d=f.toneMapping;f.getClearColor(ff),f.toneMapping=ui,f.autoClear=!1,f.state.buffers.depth.getReversed()&&(f.setRenderTarget(s),f.clearDepth(),f.setRenderTarget(null)),this._backgroundBox===null&&(this._backgroundBox=new Se(new mr,new an({name:"PMREM.Background",side:bn,depthWrite:!1,depthTest:!1})));let _=this._backgroundBox,m=_.material,p=!1,S=t.background;S?S.isColor&&(m.color.copy(S),t.background=null,p=!0):(m.color.copy(ff),p=!0);for(let A=0;A<6;A++){let v=A%3;v===0?(l.up.set(0,c[A],0),l.position.set(r.x,r.y,r.z),l.lookAt(r.x+h[A],r.y,r.z)):v===1?(l.up.set(0,0,c[A]),l.position.set(r.x,r.y,r.z),l.lookAt(r.x,r.y+h[A],r.z)):(l.up.set(0,c[A],0),l.position.set(r.x,r.y,r.z),l.lookAt(r.x,r.y,r.z+h[A]));let b=this._cubeSize;Pr(s,v*b,A>2?b:0,b,b),f.setRenderTarget(s),p&&f.render(_,l),f.render(t,l)}f.toneMapping=d,f.autoClear=u,t.background=S}_textureToCubeUV(t,e){let n=this._renderer,s=t.mapping===fs||t.mapping===Cs;s?(this._cubemapMaterial===null&&(this._cubemapMaterial=mf()),this._cubemapMaterial.uniforms.flipEnvMap.value=t.isRenderTargetTexture===!1?-1:1):this._equirectMaterial===null&&(this._equirectMaterial=pf());let r=s?this._cubemapMaterial:this._equirectMaterial,a=this._lodMeshes[0];a.material=r;let o=r.uniforms;o.envMap.value=t;let l=this._cubeSize;Pr(e,0,0,3*l,2*l),n.setRenderTarget(e),n.render(a,oo)}_applyPMREM(t){let e=this._renderer,n=e.autoClear;e.autoClear=!1;let s=this._lodMeshes.length;for(let r=1;r<s;r++)this._applyGGXFilter(t,r-1,r);e.autoClear=n}_applyGGXFilter(t,e,n){let s=this._renderer,r=this._pingPongRenderTarget,a=this._ggxMaterial,o=this._lodMeshes[n];o.material=a;let l=a.uniforms,c=n/(this._lodMeshes.length-1),h=e/(this._lodMeshes.length-1),f=Math.sqrt(c*c-h*h),u=c*1.25,d=f*u,{_lodMax:g}=this,_=this._sizeLods[n],m=3*_*(n>g-Ir?n-g+Ir:0),p=4*(this._cubeSize-_);l.envMap.value=t.texture,l.roughness.value=d,l.mipInt.value=g-e,Pr(r,m,p,3*_,2*_),s.setRenderTarget(r),s.render(o,oo),l.envMap.value=r.texture,l.roughness.value=0,l.mipInt.value=g-n,Pr(t,m,p,3*_,2*_),s.setRenderTarget(t),s.render(o,oo)}_blur(t,e,n,s){let r=this._pingPongRenderTarget,a=Math.min(s,Math.PI)/Math.SQRT2;this._blurPass(t,r,e,n,a),this._blurPass(r,t,n,n,a)}_blurPass(t,e,n,s,r){let a=this._renderer,o=this._blurMaterial,l=this._lodMeshes[s];l.material=o;let c=o.uniforms;c.envMap.value=t.texture,c.sigma.value=r,c.mipInt.value=this._lodMax-n;let h=this._sizeLods[s],f=3*h*(s>this._lodMax-Ir?s-this._lodMax+Ir:0),u=4*(this._cubeSize-h);Pr(e,f,u,3*h,2*h),a.setRenderTarget(e),a.render(l,oo)}};function mg(i){let t=[],e=[],n=i,s=i-Ir+1+ug;for(let r=0;r<s;r++){let a=Math.pow(2,n);t.push(a);let o=1/(a-2),l=-o,c=1+o,h=[l,l,c,l,c,c,l,l,c,c,l,c],f=6,u=6,d=3,g=new Float32Array(d*u*f),_=new Float32Array(d*u*f);for(let p=0;p<f;p++){let S=p%3*2/3-1,A=p>2?0:-1,v=[S,A,0,S+2/3,A,0,S+2/3,A+1,0,S,A,0,S+2/3,A+1,0,S,A+1,0];g.set(v,d*u*p);for(let b=0;b<u;b++){let E=h[b*2]*2-1,C=h[b*2+1]*2-1;p===0?Is.set(1,C,E):p===1?Is.set(-E,1,-C):p===2?Is.set(-E,C,1):p===3?Is.set(-1,C,-E):p===4?Is.set(-E,-1,C):Is.set(E,C,-1),Is.toArray(_,(p*u+b)*d)}}let m=new Ie;m.setAttribute("position",new sn(g,d)),m.setAttribute("outputDirection",new sn(_,d)),e.push(new Se(m,null)),n>Ir&&n--}return{lodMeshes:e,sizeLods:t}}function df(i,t,e){let n=new tn(i,t,e);return n.texture.mapping=Qa,n.texture.name="PMREM.cubeUv",n.scissorTest=!0,n}function Pr(i,t,e,n,s){i.viewport.set(t,e,n,s),i.scissor.set(t,e,n,s)}function gg(i,t,e){return new He({name:"PMREMGGXConvolution",defines:{GGX_SAMPLES:dg,CUBEUV_TEXEL_WIDTH:1/t,CUBEUV_TEXEL_HEIGHT:1/e,CUBEUV_MAX_MIP:`${i}.0`},uniforms:{envMap:{value:null},roughness:{value:0},mipInt:{value:0}},vertexShader:Ac(),fragmentShader:`

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
		`,blending:Qn,depthTest:!1,depthWrite:!1})}function xg(i,t,e){return new He({name:"SphericalGaussianBlur",defines:{SAMPLES:fg,CUBEUV_TEXEL_WIDTH:1/t,CUBEUV_TEXEL_HEIGHT:1/e,CUBEUV_MAX_MIP:`${i}.0`},uniforms:{envMap:{value:null},sigma:{value:0},mipInt:{value:0}},vertexShader:Ac(),fragmentShader:`

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
		`,blending:Qn,depthTest:!1,depthWrite:!1})}function pf(){return new He({name:"EquirectangularToCubeUV",uniforms:{envMap:{value:null}},vertexShader:Ac(),fragmentShader:`

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
		`,blending:Qn,depthTest:!1,depthWrite:!1})}function mf(){return new He({name:"CubemapToCubeUV",uniforms:{envMap:{value:null},flipEnvMap:{value:-1}},vertexShader:Ac(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			uniform float flipEnvMap;

			varying vec3 vOutputDirection;

			uniform samplerCube envMap;

			void main() {

				gl_FragColor = textureCube( envMap, vec3( flipEnvMap * vOutputDirection.x, vOutputDirection.yz ) );

			}
		`,blending:Qn,depthTest:!1,depthWrite:!1})}function Ac(){return`

		precision mediump float;
		precision mediump int;

		attribute vec3 outputDirection;

		varying vec3 vOutputDirection;

		void main() {

			vOutputDirection = outputDirection;
			gl_Position = vec4( position, 1.0 );

		}
	`}var Tc=class extends tn{constructor(t=1,e={}){super(t,t,e),this.isWebGLCubeRenderTarget=!0;let n={width:t,height:t,depth:1},s=[n,n,n,n,n,n];this.texture=new ya(s),this._setTextureOptions(e),this.texture.isRenderTargetTexture=!0}fromEquirectangularTexture(t,e){this.texture.type=e.type,this.texture.colorSpace=e.colorSpace,this.texture.generateMipmaps=e.generateMipmaps,this.texture.minFilter=e.minFilter,this.texture.magFilter=e.magFilter;let n={uniforms:{tEquirect:{value:null}},vertexShader:`

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
			`},s=new mr(5,5,5),r=new He({name:"CubemapFromEquirect",uniforms:Ps(n.uniforms),vertexShader:n.vertexShader,fragmentShader:n.fragmentShader,side:bn,blending:Qn});r.uniforms.tEquirect.value=e;let a=new Se(s,r),o=e.minFilter;return e.minFilter===Ti&&(e.minFilter=Sn),new Ll(1,10,this).update(t,a),e.minFilter=o,a.geometry.dispose(),a.material.dispose(),this}clear(t,e=!0,n=!0,s=!0){let r=t.getRenderTarget();for(let a=0;a<6;a++)t.setRenderTarget(this,a),t.clear(e,n,s);t.setRenderTarget(r)}};function _g(i){let t=new WeakMap,e=new WeakMap,n=null;function s(u,d=!1){return u==null?null:d?a(u):r(u)}function r(u){if(u&&u.isTexture){let d=u.mapping;if(d===Ar||d===Nl)if(t.has(u)){let g=t.get(u).texture;return o(g,u.mapping)}else{let g=u.image;if(g&&g.height>0){let _=new Tc(g.height);return _.fromEquirectangularTexture(i,u),t.set(u,_),u.addEventListener("dispose",c),o(_.texture,u.mapping)}else return null}}return u}function a(u){if(u&&u.isTexture){let d=u.mapping,g=d===Ar||d===Nl,_=d===fs||d===Cs;if(g||_){let m=e.get(u),p=m!==void 0?m.texture.pmremVersion:0;if(u.isRenderTargetTexture&&u.pmremVersion!==p)return n===null&&(n=new Ec(i)),m=g?n.fromEquirectangular(u,m):n.fromCubemap(u,m),m.texture.pmremVersion=u.pmremVersion,e.set(u,m),m.texture;if(m!==void 0)return m.texture;{let S=u.image;return g&&S&&S.height>0||_&&S&&l(S)?(n===null&&(n=new Ec(i)),m=g?n.fromEquirectangular(u):n.fromCubemap(u),m.texture.pmremVersion=u.pmremVersion,e.set(u,m),u.addEventListener("dispose",h),m.texture):null}}}return u}function o(u,d){return d===Ar?u.mapping=fs:d===Nl&&(u.mapping=Cs),u}function l(u){let d=0,g=6;for(let _=0;_<g;_++)u[_]!==void 0&&d++;return d===g}function c(u){let d=u.target;d.removeEventListener("dispose",c);let g=t.get(d);g!==void 0&&(t.delete(d),g.dispose())}function h(u){let d=u.target;d.removeEventListener("dispose",h);let g=e.get(d);g!==void 0&&(e.delete(d),g.dispose())}function f(){t=new WeakMap,e=new WeakMap,n!==null&&(n.dispose(),n=null)}return{get:s,dispose:f}}function vg(i){let t={};function e(n){if(t[n]!==void 0)return t[n];let s=i.getExtension(n);return t[n]=s,s}return{has:function(n){return e(n)!==null},init:function(){e("EXT_color_buffer_float"),e("WEBGL_clip_cull_distance"),e("OES_texture_float_linear"),e("EXT_color_buffer_half_float"),e("WEBGL_multisampled_render_to_texture"),e("WEBGL_render_shared_exponent")},get:function(n){let s=e(n);return s===null&&Es("WebGLRenderer: "+n+" extension not supported."),s}}}function yg(i,t,e,n){let s={},r=new WeakMap;function a(f){let u=f.target;u.index!==null&&t.remove(u.index);for(let g in u.attributes)t.remove(u.attributes[g]);u.removeEventListener("dispose",a),delete s[u.id];let d=r.get(u);d&&(t.remove(d),r.delete(u)),n.releaseStatesOfGeometry(u),u.isInstancedBufferGeometry===!0&&delete u._maxInstanceCount,e.memory.geometries--}function o(f,u){return s[u.id]===!0||(u.addEventListener("dispose",a),s[u.id]=!0,e.memory.geometries++),u}function l(f){let u=f.attributes;for(let d in u)t.update(u[d],i.ARRAY_BUFFER)}function c(f){let u=[],d=f.index,g=f.attributes.position,_=0;if(g===void 0)return;if(d!==null){let S=d.array;_=d.version;for(let A=0,v=S.length;A<v;A+=3){let b=S[A+0],E=S[A+1],C=S[A+2];u.push(b,E,E,C,C,b)}}else{let S=g.array;_=g.version;for(let A=0,v=S.length/3-1;A<v;A+=3){let b=A+0,E=A+1,C=A+2;u.push(b,E,E,C,C,b)}}let m=new(g.count>=65535?pa:da)(u,1);m.version=_;let p=r.get(f);p&&t.remove(p),r.set(f,m)}function h(f){let u=r.get(f);if(u){let d=f.index;d!==null&&u.version<d.version&&c(f)}else c(f);return r.get(f)}return{get:o,update:l,getWireframeAttribute:h}}function Mg(i,t,e){let n;function s(f){n=f}let r,a;function o(f){r=f.type,a=f.bytesPerElement}function l(f,u){i.drawElements(n,u,r,f*a),e.update(u,n,1)}function c(f,u,d){d!==0&&(i.drawElementsInstanced(n,u,r,f*a,d),e.update(u,n,d))}function h(f,u,d){if(d===0)return;t.get("WEBGL_multi_draw").multiDrawElementsWEBGL(n,u,0,r,f,0,d);let _=0;for(let m=0;m<d;m++)_+=u[m];e.update(_,n,1)}this.setMode=s,this.setIndex=o,this.render=l,this.renderInstances=c,this.renderMultiDraw=h}function Sg(i){let t={geometries:0,textures:0},e={frame:0,calls:0,triangles:0,points:0,lines:0};function n(r,a,o){switch(e.calls++,a){case i.TRIANGLES:e.triangles+=o*(r/3);break;case i.LINES:e.lines+=o*(r/2);break;case i.LINE_STRIP:e.lines+=o*(r-1);break;case i.LINE_LOOP:e.lines+=o*r;break;case i.POINTS:e.points+=o*r;break;default:he("WebGLInfo: Unknown draw mode:",a);break}}function s(){e.calls=0,e.triangles=0,e.points=0,e.lines=0}return{memory:t,render:e,programs:null,autoReset:!0,reset:s,update:n}}function bg(i,t,e){let n=new WeakMap,s=new $e;function r(a,o,l){let c=a.morphTargetInfluences,h=o.morphAttributes.position||o.morphAttributes.normal||o.morphAttributes.color,f=h!==void 0?h.length:0,u=n.get(o);if(u===void 0||u.count!==f){let w=function(){C.dispose(),n.delete(o),o.removeEventListener("dispose",w)};u!==void 0&&u.texture.dispose();let d=o.morphAttributes.position!==void 0,g=o.morphAttributes.normal!==void 0,_=o.morphAttributes.color!==void 0,m=o.morphAttributes.position||[],p=o.morphAttributes.normal||[],S=o.morphAttributes.color||[],A=0;d===!0&&(A=1),g===!0&&(A=2),_===!0&&(A=3);let v=o.attributes.position.count*A,b=1;v>t.maxTextureSize&&(b=Math.ceil(v/t.maxTextureSize),v=t.maxTextureSize);let E=new Float32Array(v*b*4*f),C=new ua(E,v,b,f);C.type=ti,C.needsUpdate=!0;let y=A*4;for(let I=0;I<f;I++){let N=m[I],H=p[I],W=S[I],U=v*b*4*I;for(let G=0;G<N.count;G++){let rt=G*y;d===!0&&(s.fromBufferAttribute(N,G),E[U+rt+0]=s.x,E[U+rt+1]=s.y,E[U+rt+2]=s.z,E[U+rt+3]=0),g===!0&&(s.fromBufferAttribute(H,G),E[U+rt+4]=s.x,E[U+rt+5]=s.y,E[U+rt+6]=s.z,E[U+rt+7]=0),_===!0&&(s.fromBufferAttribute(W,G),E[U+rt+8]=s.x,E[U+rt+9]=s.y,E[U+rt+10]=s.z,E[U+rt+11]=W.itemSize===4?s.w:1)}}u={count:f,texture:C,size:new ft(v,b)},n.set(o,u),o.addEventListener("dispose",w)}if(a.isInstancedMesh===!0&&a.morphTexture!==null)l.getUniforms().setValue(i,"morphTexture",a.morphTexture,e);else{let d=0;for(let _=0;_<c.length;_++)d+=c[_];let g=o.morphTargetsRelative?1:1-d;l.getUniforms().setValue(i,"morphTargetBaseInfluence",g),l.getUniforms().setValue(i,"morphTargetInfluences",c)}l.getUniforms().setValue(i,"morphTargetsTexture",u.texture,e),l.getUniforms().setValue(i,"morphTargetsTextureSize",u.size)}return{update:r}}function Eg(i,t,e,n,s){let r=new WeakMap;function a(c){let h=s.render.frame,f=c.geometry,u=t.get(c,f);if(r.get(u)!==h&&(t.update(u),r.set(u,h)),c.isInstancedMesh&&(c.hasEventListener("dispose",l)===!1&&c.addEventListener("dispose",l),r.get(c)!==h&&(e.update(c.instanceMatrix,i.ARRAY_BUFFER),c.instanceColor!==null&&e.update(c.instanceColor,i.ARRAY_BUFFER),r.set(c,h))),c.isSkinnedMesh){let d=c.skeleton;r.get(d)!==h&&(d.update(),r.set(d,h))}return u}function o(){r=new WeakMap}function l(c){let h=c.target;h.removeEventListener("dispose",l),n.releaseStatesOfObject(h),e.remove(h.instanceMatrix),h.instanceColor!==null&&e.remove(h.instanceColor)}return{update:a,dispose:o}}var Tg={[Ya]:"LINEAR_TONE_MAPPING",[$a]:"REINHARD_TONE_MAPPING",[Za]:"CINEON_TONE_MAPPING",[Rs]:"ACES_FILMIC_TONE_MAPPING",[Ka]:"AGX_TONE_MAPPING",[ja]:"NEUTRAL_TONE_MAPPING",[Ja]:"CUSTOM_TONE_MAPPING"};function wg(i,t,e,n,s,r){let a=new tn(t,e,{type:i,depthBuffer:s,stencilBuffer:r,samples:n?4:0,storeMultisampledDepthBuffer:!1,storeMultisampledStencilBuffer:!1,resolveDepthBuffer:!1,resolveStencilBuffer:!1}),o=null,l=null,c=new Ie;c.setAttribute("position",new pe([-1,3,0,-1,-1,0,3,-1,0],3)),c.setAttribute("uv",new pe([0,2,0,0,2,0],2));let h=new Sr({uniforms:{tDiffuse:{value:null}},vertexShader:`
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
			}`,depthTest:!1,depthWrite:!1}),f=new Se(c,h),u=new cs(-1,1,1,-1,0,1),d=null,g=null,_=!1,m,p=null,S=[],A=!1;this.setSize=function(v,b){a.setSize(v,b),o!==null&&o.setSize(v,b),l!==null&&l.setSize(v,b);for(let E=0;E<S.length;E++){let C=S[E];C.setSize&&C.setSize(v,b)}},this.setEffects=function(v){S=v,A=S.length>0&&S[0].isRenderPass===!0;let b=a.width,E=a.height;S.length>0&&o===null&&(o=new tn(b,E,{type:un,depthBuffer:!1,stencilBuffer:!1}),l=new tn(b,E,{type:un,depthBuffer:!1,stencilBuffer:!1}));for(let C=0;C<S.length;C++){let y=S[C];y.setSize&&y.setSize(b,E)}},this.begin=function(v,b){if(_||v.toneMapping===ui&&S.length===0)return!1;if(p=b,b!==null){let E=b.width,C=b.height;(a.width!==E||a.height!==C)&&this.setSize(E,C)}return A===!1&&v.setRenderTarget(a),m=v.toneMapping,v.toneMapping=ui,!0},this.hasRenderPass=function(){return A},this.end=function(v,b){v.toneMapping=m,_=!0;let E=a,C=o;for(let y=0;y<S.length;y++){let w=S[y];w.enabled!==!1&&(w.render(v,C,E,b),w.needsSwap!==!1&&(E=C,C=C===o?l:o))}if(d!==v.outputColorSpace||g!==v.toneMapping){d=v.outputColorSpace,g=v.toneMapping,h.defines={},Ae.getTransfer(d)===Fe&&(h.defines.SRGB_TRANSFER="");let y=Tg[g];y&&(h.defines[y]=""),h.needsUpdate=!0}h.uniforms.tDiffuse.value=E.texture,v.setRenderTarget(p),v.render(f,u),p=null,_=!1},this.isCompositing=function(){return _},this.dispose=function(){a.dispose(),o!==null&&o.dispose(),l!==null&&l.dispose(),c.dispose(),h.dispose()}}var Uf=new xn,rh=new ss(1,1),Ff=new ua,Of=new ul,Bf=new ya,gf=[],xf=[],_f=new Float32Array(16),vf=new Float32Array(9),yf=new Float32Array(4);function Dr(i,t,e){let n=i[0];if(n<=0||n>0)return i;let s=t*e,r=gf[s];if(r===void 0&&(r=new Float32Array(s),gf[s]=r),t!==0){n.toArray(r,0);for(let a=1,o=0;a!==t;++a)o+=e,i[a].toArray(r,o)}return r}function fn(i,t){if(i.length!==t.length)return!1;for(let e=0,n=i.length;e<n;e++)if(i[e]!==t[e])return!1;return!0}function dn(i,t){for(let e=0,n=t.length;e<n;e++)i[e]=t[e]}function Rc(i,t){let e=xf[t];e===void 0&&(e=new Int32Array(t),xf[t]=e);for(let n=0;n!==t;++n)e[n]=i.allocateTextureUnit();return e}function Ag(i,t){let e=this.cache;e[0]!==t&&(i.uniform1f(this.addr,t),e[0]=t)}function Rg(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y)&&(i.uniform2f(this.addr,t.x,t.y),e[0]=t.x,e[1]=t.y);else{if(fn(e,t))return;i.uniform2fv(this.addr,t),dn(e,t)}}function Cg(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z)&&(i.uniform3f(this.addr,t.x,t.y,t.z),e[0]=t.x,e[1]=t.y,e[2]=t.z);else if(t.r!==void 0)(e[0]!==t.r||e[1]!==t.g||e[2]!==t.b)&&(i.uniform3f(this.addr,t.r,t.g,t.b),e[0]=t.r,e[1]=t.g,e[2]=t.b);else{if(fn(e,t))return;i.uniform3fv(this.addr,t),dn(e,t)}}function Pg(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z||e[3]!==t.w)&&(i.uniform4f(this.addr,t.x,t.y,t.z,t.w),e[0]=t.x,e[1]=t.y,e[2]=t.z,e[3]=t.w);else{if(fn(e,t))return;i.uniform4fv(this.addr,t),dn(e,t)}}function Ig(i,t){let e=this.cache,n=t.elements;if(n===void 0){if(fn(e,t))return;i.uniformMatrix2fv(this.addr,!1,t),dn(e,t)}else{if(fn(e,n))return;yf.set(n),i.uniformMatrix2fv(this.addr,!1,yf),dn(e,n)}}function Lg(i,t){let e=this.cache,n=t.elements;if(n===void 0){if(fn(e,t))return;i.uniformMatrix3fv(this.addr,!1,t),dn(e,t)}else{if(fn(e,n))return;vf.set(n),i.uniformMatrix3fv(this.addr,!1,vf),dn(e,n)}}function Dg(i,t){let e=this.cache,n=t.elements;if(n===void 0){if(fn(e,t))return;i.uniformMatrix4fv(this.addr,!1,t),dn(e,t)}else{if(fn(e,n))return;_f.set(n),i.uniformMatrix4fv(this.addr,!1,_f),dn(e,n)}}function Ng(i,t){let e=this.cache;e[0]!==t&&(i.uniform1i(this.addr,t),e[0]=t)}function Ug(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y)&&(i.uniform2i(this.addr,t.x,t.y),e[0]=t.x,e[1]=t.y);else{if(fn(e,t))return;i.uniform2iv(this.addr,t),dn(e,t)}}function Fg(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z)&&(i.uniform3i(this.addr,t.x,t.y,t.z),e[0]=t.x,e[1]=t.y,e[2]=t.z);else{if(fn(e,t))return;i.uniform3iv(this.addr,t),dn(e,t)}}function Og(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z||e[3]!==t.w)&&(i.uniform4i(this.addr,t.x,t.y,t.z,t.w),e[0]=t.x,e[1]=t.y,e[2]=t.z,e[3]=t.w);else{if(fn(e,t))return;i.uniform4iv(this.addr,t),dn(e,t)}}function Bg(i,t){let e=this.cache;e[0]!==t&&(i.uniform1ui(this.addr,t),e[0]=t)}function zg(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y)&&(i.uniform2ui(this.addr,t.x,t.y),e[0]=t.x,e[1]=t.y);else{if(fn(e,t))return;i.uniform2uiv(this.addr,t),dn(e,t)}}function kg(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z)&&(i.uniform3ui(this.addr,t.x,t.y,t.z),e[0]=t.x,e[1]=t.y,e[2]=t.z);else{if(fn(e,t))return;i.uniform3uiv(this.addr,t),dn(e,t)}}function Hg(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z||e[3]!==t.w)&&(i.uniform4ui(this.addr,t.x,t.y,t.z,t.w),e[0]=t.x,e[1]=t.y,e[2]=t.z,e[3]=t.w);else{if(fn(e,t))return;i.uniform4uiv(this.addr,t),dn(e,t)}}function Vg(i,t,e){let n=this.cache,s=e.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s);let r;this.type===i.SAMPLER_2D_SHADOW?(rh.compareFunction=e.isReversedDepthBuffer()?Mc:yc,r=rh):r=Uf,e.setTexture2D(t||r,s)}function Gg(i,t,e){let n=this.cache,s=e.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s),e.setTexture3D(t||Of,s)}function Wg(i,t,e){let n=this.cache,s=e.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s),e.setTextureCube(t||Bf,s)}function Xg(i,t,e){let n=this.cache,s=e.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s),e.setTexture2DArray(t||Ff,s)}function qg(i){switch(i){case 5126:return Ag;case 35664:return Rg;case 35665:return Cg;case 35666:return Pg;case 35674:return Ig;case 35675:return Lg;case 35676:return Dg;case 5124:case 35670:return Ng;case 35667:case 35671:return Ug;case 35668:case 35672:return Fg;case 35669:case 35673:return Og;case 5125:return Bg;case 36294:return zg;case 36295:return kg;case 36296:return Hg;case 35678:case 36198:case 36298:case 36306:case 35682:return Vg;case 35679:case 36299:case 36307:return Gg;case 35680:case 36300:case 36308:case 36293:return Wg;case 36289:case 36303:case 36311:case 36292:return Xg}}function Yg(i,t){i.uniform1fv(this.addr,t)}function $g(i,t){let e=Dr(t,this.size,2);i.uniform2fv(this.addr,e)}function Zg(i,t){let e=Dr(t,this.size,3);i.uniform3fv(this.addr,e)}function Jg(i,t){let e=Dr(t,this.size,4);i.uniform4fv(this.addr,e)}function Kg(i,t){let e=Dr(t,this.size,4);i.uniformMatrix2fv(this.addr,!1,e)}function jg(i,t){let e=Dr(t,this.size,9);i.uniformMatrix3fv(this.addr,!1,e)}function Qg(i,t){let e=Dr(t,this.size,16);i.uniformMatrix4fv(this.addr,!1,e)}function t2(i,t){i.uniform1iv(this.addr,t)}function e2(i,t){i.uniform2iv(this.addr,t)}function n2(i,t){i.uniform3iv(this.addr,t)}function i2(i,t){i.uniform4iv(this.addr,t)}function s2(i,t){i.uniform1uiv(this.addr,t)}function r2(i,t){i.uniform2uiv(this.addr,t)}function a2(i,t){i.uniform3uiv(this.addr,t)}function o2(i,t){i.uniform4uiv(this.addr,t)}function l2(i,t,e){let n=this.cache,s=t.length,r=Rc(e,s);fn(n,r)||(i.uniform1iv(this.addr,r),dn(n,r));let a;this.type===i.SAMPLER_2D_SHADOW?a=rh:a=Uf;for(let o=0;o!==s;++o)e.setTexture2D(t[o]||a,r[o])}function c2(i,t,e){let n=this.cache,s=t.length,r=Rc(e,s);fn(n,r)||(i.uniform1iv(this.addr,r),dn(n,r));for(let a=0;a!==s;++a)e.setTexture3D(t[a]||Of,r[a])}function h2(i,t,e){let n=this.cache,s=t.length,r=Rc(e,s);fn(n,r)||(i.uniform1iv(this.addr,r),dn(n,r));for(let a=0;a!==s;++a)e.setTextureCube(t[a]||Bf,r[a])}function u2(i,t,e){let n=this.cache,s=t.length,r=Rc(e,s);fn(n,r)||(i.uniform1iv(this.addr,r),dn(n,r));for(let a=0;a!==s;++a)e.setTexture2DArray(t[a]||Ff,r[a])}function f2(i){switch(i){case 5126:return Yg;case 35664:return $g;case 35665:return Zg;case 35666:return Jg;case 35674:return Kg;case 35675:return jg;case 35676:return Qg;case 5124:case 35670:return t2;case 35667:case 35671:return e2;case 35668:case 35672:return n2;case 35669:case 35673:return i2;case 5125:return s2;case 36294:return r2;case 36295:return a2;case 36296:return o2;case 35678:case 36198:case 36298:case 36306:case 35682:return l2;case 35679:case 36299:case 36307:return c2;case 35680:case 36300:case 36308:case 36293:return h2;case 36289:case 36303:case 36311:case 36292:return u2}}var ah=class{constructor(t,e,n){this.id=t,this.addr=n,this.cache=[],this.type=e.type,this.setValue=qg(e.type)}},oh=class{constructor(t,e,n){this.id=t,this.addr=n,this.cache=[],this.type=e.type,this.size=e.size,this.setValue=f2(e.type)}},lh=class{constructor(t){this.id=t,this.seq=[],this.map={}}setValue(t,e,n){let s=this.seq;for(let r=0,a=s.length;r!==a;++r){let o=s[r];o.setValue(t,e[o.id],n)}}},ih=/(\w+)(\])?(\[|\.)?/g;function Mf(i,t){i.seq.push(t),i.map[t.id]=t}function d2(i,t,e){let n=i.name,s=n.length;for(ih.lastIndex=0;;){let r=ih.exec(n),a=ih.lastIndex,o=r[1],l=r[2]==="]",c=r[3];if(l&&(o=o|0),c===void 0||c==="["&&a+2===s){Mf(e,c===void 0?new ah(o,i,t):new oh(o,i,t));break}else{let f=e.map[o];f===void 0&&(f=new lh(o),Mf(e,f)),e=f}}}var Lr=class{constructor(t,e){this.seq=[],this.map={};let n=t.getProgramParameter(e,t.ACTIVE_UNIFORMS);for(let a=0;a<n;++a){let o=t.getActiveUniform(e,a),l=t.getUniformLocation(e,o.name);d2(o,l,this)}let s=[],r=[];for(let a of this.seq)a.type===t.SAMPLER_2D_SHADOW||a.type===t.SAMPLER_CUBE_SHADOW||a.type===t.SAMPLER_2D_ARRAY_SHADOW?s.push(a):r.push(a);s.length>0&&(this.seq=s.concat(r))}setValue(t,e,n,s){let r=this.map[e];r!==void 0&&r.setValue(t,n,s)}setOptional(t,e,n){let s=e[n];s!==void 0&&this.setValue(t,n,s)}static upload(t,e,n,s){for(let r=0,a=e.length;r!==a;++r){let o=e[r],l=n[o.id];l.needsUpdate!==!1&&o.setValue(t,l.value,s)}}static seqWithValue(t,e){let n=[];for(let s=0,r=t.length;s!==r;++s){let a=t[s];a.id in e&&n.push(a)}return n}};function Sf(i,t,e){let n=i.createShader(t);return i.shaderSource(n,e),i.compileShader(n),n}var p2=37297,m2=0;function g2(i,t){let e=i.split(`
`),n=[],s=Math.max(t-6,0),r=Math.min(t+6,e.length);for(let a=s;a<r;a++){let o=a+1;n.push(`${o===t?">":" "} ${o}: ${e[a]}`)}return n.join(`
`)}var bf=new xe;function x2(i){Ae._getMatrix(bf,Ae.workingColorSpace,i);let t=`mat3( ${bf.elements.map(e=>e.toFixed(4))} )`;switch(Ae.getTransfer(i)){case ca:return[t,"LinearTransferOETF"];case Fe:return[t,"sRGBTransferOETF"];default:return ue("WebGLProgram: Unsupported color space: ",i),[t,"LinearTransferOETF"]}}function Ef(i,t,e){let n=i.getShaderParameter(t,i.COMPILE_STATUS),r=(i.getShaderInfoLog(t)||"").trim();if(n&&r==="")return"";let a=/ERROR: 0:(\d+)/.exec(r);if(a){let o=parseInt(a[1]);return e.toUpperCase()+`

`+r+`

`+g2(i.getShaderSource(t),o)}else return r}function _2(i,t){let e=x2(t);return[`vec4 ${i}( vec4 value ) {`,`	return ${e[1]}( vec4( value.rgb * ${e[0]}, value.a ) );`,"}"].join(`
`)}var v2={[Ya]:"Linear",[$a]:"Reinhard",[Za]:"Cineon",[Rs]:"ACESFilmic",[Ka]:"AgX",[ja]:"Neutral",[Ja]:"Custom"};function y2(i,t){let e=v2[t];return e===void 0?(ue("WebGLProgram: Unsupported toneMapping:",t),"vec3 "+i+"( vec3 color ) { return LinearToneMapping( color ); }"):"vec3 "+i+"( vec3 color ) { return "+e+"ToneMapping( color ); }"}var bc=new P;function M2(){Ae.getLuminanceCoefficients(bc);let i=bc.x.toFixed(4),t=bc.y.toFixed(4),e=bc.z.toFixed(4);return["float luminance( const in vec3 rgb ) {",`	const vec3 weights = vec3( ${i}, ${t}, ${e} );`,"	return dot( weights, rgb );","}"].join(`
`)}function S2(i){return[i.extensionClipCullDistance?"#extension GL_ANGLE_clip_cull_distance : require":"",i.extensionMultiDraw?"#extension GL_ANGLE_multi_draw : require":""].filter(co).join(`
`)}function b2(i){let t=[];for(let e in i){let n=i[e];n!==!1&&t.push("#define "+e+" "+n)}return t.join(`
`)}function E2(i,t){let e={},n=i.getProgramParameter(t,i.ACTIVE_ATTRIBUTES);for(let s=0;s<n;s++){let r=i.getActiveAttrib(t,s),a=r.name,o=1;r.type===i.FLOAT_MAT2&&(o=2),r.type===i.FLOAT_MAT3&&(o=3),r.type===i.FLOAT_MAT4&&(o=4),e[a]={type:r.type,location:i.getAttribLocation(t,a),locationSize:o}}return e}function co(i){return i!==""}function Tf(i,t){let e=t.numSpotLightShadows+t.numSpotLightMaps-t.numSpotLightShadowsWithMaps;return i.replace(/NUM_SUN_LIGHTS/g,t.numSunLights).replace(/NUM_DIR_LIGHTS/g,t.numDirLights).replace(/NUM_SPOT_LIGHTS/g,t.numSpotLights).replace(/NUM_SPOT_LIGHT_MAPS/g,t.numSpotLightMaps).replace(/NUM_SPOT_LIGHT_COORDS/g,e).replace(/NUM_RECT_AREA_LIGHTS/g,t.numRectAreaLights).replace(/NUM_POINT_LIGHTS/g,t.numPointLights).replace(/NUM_HEMI_LIGHTS/g,t.numHemiLights).replace(/NUM_SUN_LIGHT_SHADOWS/g,t.numSunLightShadows).replace(/NUM_DIR_LIGHT_SHADOWS/g,t.numDirLightShadows).replace(/NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS/g,t.numSpotLightShadowsWithMaps).replace(/NUM_SPOT_LIGHT_SHADOWS/g,t.numSpotLightShadows).replace(/NUM_POINT_LIGHT_SHADOWS/g,t.numPointLightShadows)}function wf(i,t){return i.replace(/NUM_CLIPPING_PLANES/g,t.numClippingPlanes).replace(/UNION_CLIPPING_PLANES/g,t.numClippingPlanes-t.numClipIntersection)}var T2=/^[ \t]*#include +<([\w\d./]+)>/gm;function ch(i){return i.replace(T2,A2)}var w2=new Map;function A2(i,t){let e=be[t];if(e===void 0){let n=w2.get(t);if(n!==void 0)e=be[n],ue('WebGLRenderer: Shader chunk "%s" has been deprecated. Use "%s" instead.',t,n);else throw new Error("THREE.WebGLProgram: Can not resolve #include <"+t+">")}return ch(e)}var R2=/#pragma unroll_loop_start\s+for\s*\(\s*int\s+i\s*=\s*(\d+)\s*;\s*i\s*<\s*(\d+)\s*;\s*i\s*\+\+\s*\)\s*{([\s\S]+?)}\s+#pragma unroll_loop_end/g;function Af(i){return i.replace(R2,C2)}function C2(i,t,e,n){let s="";for(let r=parseInt(t);r<parseInt(e);r++)s+=n.replace(/\[\s*i\s*\]/g,"[ "+r+" ]").replace(/UNROLLED_LOOP_INDEX/g,r);return s}function Rf(i){let t=`precision ${i.precision} float;
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
	`;return i.precision==="highp"?t+=`
#define HIGH_PRECISION`:i.precision==="mediump"?t+=`
#define MEDIUM_PRECISION`:i.precision==="lowp"&&(t+=`
#define LOW_PRECISION`),t}var P2={[qa]:"SHADOWMAP_TYPE_PCF",[wr]:"SHADOWMAP_TYPE_VSM"};function I2(i){return P2[i.shadowMapType]||"SHADOWMAP_TYPE_BASIC"}var L2={[fs]:"ENVMAP_TYPE_CUBE",[Cs]:"ENVMAP_TYPE_CUBE",[Qa]:"ENVMAP_TYPE_CUBE_UV"};function D2(i){return i.envMap===!1?"ENVMAP_TYPE_CUBE":L2[i.envMapMode]||"ENVMAP_TYPE_CUBE"}var N2={[Cs]:"ENVMAP_MODE_REFRACTION"};function U2(i){return i.envMap===!1?"ENVMAP_MODE_REFLECTION":N2[i.envMapMode]||"ENVMAP_MODE_REFLECTION"}var F2={[B0]:"ENVMAP_BLENDING_MULTIPLY",[Hu]:"ENVMAP_BLENDING_MIX",[Vu]:"ENVMAP_BLENDING_ADD"};function O2(i){return i.envMap===!1?"ENVMAP_BLENDING_NONE":F2[i.combine]||"ENVMAP_BLENDING_NONE"}function B2(i){let t=i.envMapCubeUVHeight;if(t===null)return null;let e=Math.log2(t)-2,n=1/t;return{texelWidth:1/(3*Math.max(Math.pow(2,e),112)),texelHeight:n,maxMip:e}}function z2(i,t,e,n){let s=i.getContext(),r=e.defines,a=e.vertexShader,o=e.fragmentShader,l=I2(e),c=D2(e),h=U2(e),f=O2(e),u=B2(e),d=S2(e),g=b2(r),_=s.createProgram(),m,p,S=e.glslVersion?"#version "+e.glslVersion+`
`:"";e.isRawShaderMaterial?(m=["#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,g].filter(co).join(`
`),m.length>0&&(m+=`
`),p=["#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,g].filter(co).join(`
`),p.length>0&&(p+=`
`)):(m=[Rf(e),"#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,g,e.extensionClipCullDistance?"#define USE_CLIP_DISTANCE":"",e.batching?"#define USE_BATCHING":"",e.batchingColor?"#define USE_BATCHING_COLOR":"",e.instancing?"#define USE_INSTANCING":"",e.instancingColor?"#define USE_INSTANCING_COLOR":"",e.instancingMorph?"#define USE_INSTANCING_MORPH":"",e.useFog&&e.fog?"#define USE_FOG":"",e.useFog&&e.fogExp2?"#define FOG_EXP2":"",e.map?"#define USE_MAP":"",e.envMap?"#define USE_ENVMAP":"",e.envMap?"#define "+h:"",e.lightMap?"#define USE_LIGHTMAP":"",e.aoMap?"#define USE_AOMAP":"",e.bumpMap?"#define USE_BUMPMAP":"",e.normalMap?"#define USE_NORMALMAP":"",e.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",e.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",e.displacementMap?"#define USE_DISPLACEMENTMAP":"",e.emissiveMap?"#define USE_EMISSIVEMAP":"",e.anisotropy?"#define USE_ANISOTROPY":"",e.anisotropyMap?"#define USE_ANISOTROPYMAP":"",e.clearcoatMap?"#define USE_CLEARCOATMAP":"",e.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",e.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",e.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",e.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",e.specularMap?"#define USE_SPECULARMAP":"",e.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",e.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",e.roughnessMap?"#define USE_ROUGHNESSMAP":"",e.metalnessMap?"#define USE_METALNESSMAP":"",e.alphaMap?"#define USE_ALPHAMAP":"",e.alphaHash?"#define USE_ALPHAHASH":"",e.transmission?"#define USE_TRANSMISSION":"",e.transmissionMap?"#define USE_TRANSMISSIONMAP":"",e.thicknessMap?"#define USE_THICKNESSMAP":"",e.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",e.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",e.mapUv?"#define MAP_UV "+e.mapUv:"",e.alphaMapUv?"#define ALPHAMAP_UV "+e.alphaMapUv:"",e.lightMapUv?"#define LIGHTMAP_UV "+e.lightMapUv:"",e.aoMapUv?"#define AOMAP_UV "+e.aoMapUv:"",e.emissiveMapUv?"#define EMISSIVEMAP_UV "+e.emissiveMapUv:"",e.bumpMapUv?"#define BUMPMAP_UV "+e.bumpMapUv:"",e.normalMapUv?"#define NORMALMAP_UV "+e.normalMapUv:"",e.displacementMapUv?"#define DISPLACEMENTMAP_UV "+e.displacementMapUv:"",e.metalnessMapUv?"#define METALNESSMAP_UV "+e.metalnessMapUv:"",e.roughnessMapUv?"#define ROUGHNESSMAP_UV "+e.roughnessMapUv:"",e.anisotropyMapUv?"#define ANISOTROPYMAP_UV "+e.anisotropyMapUv:"",e.clearcoatMapUv?"#define CLEARCOATMAP_UV "+e.clearcoatMapUv:"",e.clearcoatNormalMapUv?"#define CLEARCOAT_NORMALMAP_UV "+e.clearcoatNormalMapUv:"",e.clearcoatRoughnessMapUv?"#define CLEARCOAT_ROUGHNESSMAP_UV "+e.clearcoatRoughnessMapUv:"",e.iridescenceMapUv?"#define IRIDESCENCEMAP_UV "+e.iridescenceMapUv:"",e.iridescenceThicknessMapUv?"#define IRIDESCENCE_THICKNESSMAP_UV "+e.iridescenceThicknessMapUv:"",e.sheenColorMapUv?"#define SHEEN_COLORMAP_UV "+e.sheenColorMapUv:"",e.sheenRoughnessMapUv?"#define SHEEN_ROUGHNESSMAP_UV "+e.sheenRoughnessMapUv:"",e.specularMapUv?"#define SPECULARMAP_UV "+e.specularMapUv:"",e.specularColorMapUv?"#define SPECULAR_COLORMAP_UV "+e.specularColorMapUv:"",e.specularIntensityMapUv?"#define SPECULAR_INTENSITYMAP_UV "+e.specularIntensityMapUv:"",e.transmissionMapUv?"#define TRANSMISSIONMAP_UV "+e.transmissionMapUv:"",e.thicknessMapUv?"#define THICKNESSMAP_UV "+e.thicknessMapUv:"",e.vertexTangents&&e.flatShading===!1?"#define USE_TANGENT":"",e.vertexNormals?"#define HAS_NORMAL":"",e.vertexColors?"#define USE_COLOR":"",e.vertexAlphas?"#define USE_COLOR_ALPHA":"",e.vertexUv1s?"#define USE_UV1":"",e.vertexUv2s?"#define USE_UV2":"",e.vertexUv3s?"#define USE_UV3":"",e.pointsUvs?"#define USE_POINTS_UV":"",e.flatShading?"#define FLAT_SHADED":"",e.skinning?"#define USE_SKINNING":"",e.morphTargets?"#define USE_MORPHTARGETS":"",e.morphNormals&&e.flatShading===!1?"#define USE_MORPHNORMALS":"",e.morphColors?"#define USE_MORPHCOLORS":"",e.morphTargetsCount>0?"#define MORPHTARGETS_TEXTURE_STRIDE "+e.morphTextureStride:"",e.morphTargetsCount>0?"#define MORPHTARGETS_COUNT "+e.morphTargetsCount:"",e.doubleSided?"#define DOUBLE_SIDED":"",e.flipSided?"#define FLIP_SIDED":"",e.shadowMapEnabled?"#define USE_SHADOWMAP":"",e.shadowMapEnabled?"#define "+l:"",e.sizeAttenuation?"#define USE_SIZEATTENUATION":"",e.numLightProbes>0?"#define USE_LIGHT_PROBES":"",e.logarithmicDepthBuffer?"#define USE_LOGARITHMIC_DEPTH_BUFFER":"",e.reversedDepthBuffer?"#define USE_REVERSED_DEPTH_BUFFER":"","uniform mat4 modelMatrix;","uniform mat4 modelViewMatrix;","uniform mat4 projectionMatrix;","uniform mat4 viewMatrix;","uniform mat3 normalMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;","#ifdef USE_INSTANCING","	attribute mat4 instanceMatrix;","#endif","#ifdef USE_INSTANCING_COLOR","	attribute vec3 instanceColor;","#endif","#ifdef USE_INSTANCING_MORPH","	uniform sampler2D morphTexture;","#endif","attribute vec3 position;","attribute vec3 normal;","attribute vec2 uv;","#ifdef USE_UV1","	attribute vec2 uv1;","#endif","#ifdef USE_UV2","	attribute vec2 uv2;","#endif","#ifdef USE_UV3","	attribute vec2 uv3;","#endif","#ifdef USE_TANGENT","	attribute vec4 tangent;","#endif","#if defined( USE_COLOR_ALPHA )","	attribute vec4 color;","#elif defined( USE_COLOR )","	attribute vec3 color;","#endif","#ifdef USE_SKINNING","	attribute vec4 skinIndex;","	attribute vec4 skinWeight;","#endif",`
`].filter(co).join(`
`),p=[Rf(e),"#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,g,e.useFog&&e.fog?"#define USE_FOG":"",e.useFog&&e.fogExp2?"#define FOG_EXP2":"",e.alphaToCoverage?"#define ALPHA_TO_COVERAGE":"",e.map?"#define USE_MAP":"",e.matcap?"#define USE_MATCAP":"",e.envMap?"#define USE_ENVMAP":"",e.envMap?"#define "+c:"",e.envMap?"#define "+h:"",e.envMap?"#define "+f:"",u?"#define CUBEUV_TEXEL_WIDTH "+u.texelWidth:"",u?"#define CUBEUV_TEXEL_HEIGHT "+u.texelHeight:"",u?"#define CUBEUV_MAX_MIP "+u.maxMip+".0":"",e.lightMap?"#define USE_LIGHTMAP":"",e.aoMap?"#define USE_AOMAP":"",e.bumpMap?"#define USE_BUMPMAP":"",e.normalMap?"#define USE_NORMALMAP":"",e.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",e.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",e.packedNormalMap?"#define USE_PACKED_NORMALMAP":"",e.emissiveMap?"#define USE_EMISSIVEMAP":"",e.anisotropy?"#define USE_ANISOTROPY":"",e.anisotropyMap?"#define USE_ANISOTROPYMAP":"",e.clearcoat?"#define USE_CLEARCOAT":"",e.clearcoatMap?"#define USE_CLEARCOATMAP":"",e.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",e.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",e.dispersion?"#define USE_DISPERSION":"",e.retroreflection?"#define USE_RETROREFLECTION":"",e.iridescence?"#define USE_IRIDESCENCE":"",e.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",e.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",e.specularMap?"#define USE_SPECULARMAP":"",e.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",e.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",e.roughnessMap?"#define USE_ROUGHNESSMAP":"",e.metalnessMap?"#define USE_METALNESSMAP":"",e.alphaMap?"#define USE_ALPHAMAP":"",e.alphaTest?"#define USE_ALPHATEST":"",e.alphaHash?"#define USE_ALPHAHASH":"",e.sheen?"#define USE_SHEEN":"",e.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",e.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",e.transmission?"#define USE_TRANSMISSION":"",e.transmissionMap?"#define USE_TRANSMISSIONMAP":"",e.thicknessMap?"#define USE_THICKNESSMAP":"",e.vertexTangents&&e.flatShading===!1?"#define USE_TANGENT":"",e.vertexColors||e.instancingColor?"#define USE_COLOR":"",e.vertexAlphas||e.batchingColor?"#define USE_COLOR_ALPHA":"",e.vertexUv1s?"#define USE_UV1":"",e.vertexUv2s?"#define USE_UV2":"",e.vertexUv3s?"#define USE_UV3":"",e.pointsUvs?"#define USE_POINTS_UV":"",e.gradientMap?"#define USE_GRADIENTMAP":"",e.flatShading?"#define FLAT_SHADED":"",e.doubleSided?"#define DOUBLE_SIDED":"",e.flipSided?"#define FLIP_SIDED":"",e.shadowMapEnabled?"#define USE_SHADOWMAP":"",e.shadowMapEnabled?"#define "+l:"",e.premultipliedAlpha?"#define PREMULTIPLIED_ALPHA":"",e.numLightProbes>0?"#define USE_LIGHT_PROBES":"",e.numLightProbeGrids>0?"#define USE_LIGHT_PROBES_GRID":"",e.decodeVideoTexture?"#define DECODE_VIDEO_TEXTURE":"",e.decodeVideoTextureEmissive?"#define DECODE_VIDEO_TEXTURE_EMISSIVE":"",e.logarithmicDepthBuffer?"#define USE_LOGARITHMIC_DEPTH_BUFFER":"",e.reversedDepthBuffer?"#define USE_REVERSED_DEPTH_BUFFER":"","uniform mat4 viewMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;",e.toneMapping!==ui?"#define TONE_MAPPING":"",e.toneMapping!==ui?be.tonemapping_pars_fragment:"",e.toneMapping!==ui?y2("toneMapping",e.toneMapping):"",e.dithering?"#define DITHERING":"",e.opaque?"#define OPAQUE":"",be.colorspace_pars_fragment,_2("linearToOutputTexel",e.outputColorSpace),M2(),e.useDepthPacking?"#define DEPTH_PACKING "+e.depthPacking:"",`
`].filter(co).join(`
`)),a=ch(a),a=Tf(a,e),a=wf(a,e),o=ch(o),o=Tf(o,e),o=wf(o,e),a=Af(a),o=Af(o),e.isRawShaderMaterial!==!0&&(S=`#version 300 es
`,m=[d,"#define attribute in","#define varying out","#define texture2D texture"].join(`
`)+`
`+m,p=["#define varying in",e.glslVersion===Y0?"":"layout(location = 0) out highp vec4 pc_fragColor;",e.glslVersion===Y0?"":"#define gl_FragColor pc_fragColor","#define gl_FragDepthEXT gl_FragDepth","#define texture2D texture","#define textureCube texture","#define texture2DProj textureProj","#define texture2DLodEXT textureLod","#define texture2DProjLodEXT textureProjLod","#define textureCubeLodEXT textureLod","#define texture2DGradEXT textureGrad","#define texture2DProjGradEXT textureProjGrad","#define textureCubeGradEXT textureGrad"].join(`
`)+`
`+p);let A=S+m+a,v=S+p+o,b=Sf(s,s.VERTEX_SHADER,A),E=Sf(s,s.FRAGMENT_SHADER,v);s.attachShader(_,b),s.attachShader(_,E),e.index0AttributeName!==void 0?s.bindAttribLocation(_,0,e.index0AttributeName):e.hasPositionAttribute===!0&&s.bindAttribLocation(_,0,"position"),s.linkProgram(_);function C(N){if(i.debug.checkShaderErrors){let H=s.getProgramInfoLog(_)||"",W=s.getShaderInfoLog(b)||"",U=s.getShaderInfoLog(E)||"",G=H.trim(),rt=W.trim(),j=U.trim(),pt=!0,st=!0;if(s.getProgramParameter(_,s.LINK_STATUS)===!1)if(pt=!1,typeof i.debug.onShaderError=="function")i.debug.onShaderError(s,_,b,E);else{let lt=Ef(s,b,"vertex"),O=Ef(s,E,"fragment");he("WebGLProgram: Shader Error "+s.getError()+" - VALIDATE_STATUS "+s.getProgramParameter(_,s.VALIDATE_STATUS)+`

Material Name: `+N.name+`
Material Type: `+N.type+`

Program Info Log: `+G+`
`+lt+`
`+O)}else G!==""?ue("WebGLProgram: Program Info Log:",G):(rt===""||j==="")&&(st=!1);st&&(N.diagnostics={runnable:pt,programLog:G,vertexShader:{log:rt,prefix:m},fragmentShader:{log:j,prefix:p}})}s.deleteShader(b),s.deleteShader(E),y=new Lr(s,_),w=E2(s,_)}let y;this.getUniforms=function(){return y===void 0&&C(this),y};let w;this.getAttributes=function(){return w===void 0&&C(this),w};let I=e.rendererExtensionParallelShaderCompile===!1;return this.isReady=function(){return I===!1&&(I=s.getProgramParameter(_,p2)),I},this.destroy=function(){n.releaseStatesOfProgram(this),s.deleteProgram(_),this.program=void 0},this.type=e.shaderType,this.name=e.shaderName,this.id=m2++,this.cacheKey=t,this.usedTimes=1,this.program=_,this.vertexShader=b,this.fragmentShader=E,this}var k2=0,hh=class{constructor(){this.shaderCache=new Map,this.materialCache=new Map}update(t,e,n){let s=this._getShaderCacheForMaterial(t);return s.has(e)===!1&&(s.add(e),e.usedTimes++),s.has(n)===!1&&(s.add(n),n.usedTimes++),this}remove(t){let e=this.materialCache.get(t);for(let n of e)n.usedTimes--,n.usedTimes===0&&this.shaderCache.delete(n.code);return this.materialCache.delete(t),this}getVertexShaderStage(t){return this._getShaderStage(t.vertexShader)}getFragmentShaderStage(t){return this._getShaderStage(t.fragmentShader)}dispose(){this.shaderCache.clear(),this.materialCache.clear()}_getShaderCacheForMaterial(t){let e=this.materialCache,n=e.get(t);return n===void 0&&(n=new Set,e.set(t,n)),n}_getShaderStage(t){let e=this.shaderCache,n=e.get(t);return n===void 0&&(n=new uh(t),e.set(t,n)),n}},uh=class{constructor(t){this.id=k2++,this.code=t,this.usedTimes=0}};function H2(i){return i===ps||i===ro||i===ao}function V2(i,t,e,n,s,r){let a=new hr,o=new hh,l=new Set,c=[],h=new Map,f=n.logarithmicDepthBuffer,u=n.precision,d={MeshDepthMaterial:"depth",MeshDistanceMaterial:"distance",MeshNormalMaterial:"normal",MeshBasicMaterial:"basic",MeshLambertMaterial:"lambert",MeshPhongMaterial:"phong",MeshToonMaterial:"toon",MeshStandardMaterial:"physical",MeshPhysicalMaterial:"physical",MeshMatcapMaterial:"matcap",LineBasicMaterial:"basic",LineDashedMaterial:"dashed",PointsMaterial:"points",ShadowMaterial:"shadow",SpriteMaterial:"sprite"};function g(y){return l.add(y),y===0?"uv":`uv${y}`}function _(y,w,I,N,H,W){let U=N.fog,G=H.geometry,rt=y.isMeshStandardMaterial||y.isMeshLambertMaterial||y.isMeshPhongMaterial?N.environment:null,j=y.isMeshStandardMaterial||y.isMeshLambertMaterial&&!y.envMap||y.isMeshPhongMaterial&&!y.envMap,pt=t.get(y.envMap||rt,j),st=pt&&pt.mapping===Qa?pt.image.height:null,lt=d[y.type];y.precision!==null&&(u=n.getMaxPrecision(y.precision),u!==y.precision&&ue("WebGLProgram.getParameters:",y.precision,"not supported, using",u,"instead."));let O=G.morphAttributes.position||G.morphAttributes.normal||G.morphAttributes.color,vt=O!==void 0?O.length:0,St=0;G.morphAttributes.position!==void 0&&(St=1),G.morphAttributes.normal!==void 0&&(St=2),G.morphAttributes.color!==void 0&&(St=3);let Et,Xt,gt,J;if(lt){let Oe=Ai[lt];Et=Oe.vertexShader,Xt=Oe.fragmentShader}else{Et=y.vertexShader,Xt=y.fragmentShader;let Oe=o.getVertexShaderStage(y),Ue=o.getFragmentShaderStage(y);o.update(y,Oe,Ue),gt=Oe.id,J=Ue.id}let q=i.getRenderTarget(),ht=i.state.buffers.depth.getReversed(),wt=H.isInstancedMesh===!0,ct=H.isBatchedMesh===!0,Ft=!!y.map,ae=!!y.matcap,K=!!pt,ut=!!y.aoMap,yt=!!y.lightMap,xt=!!y.bumpMap&&y.wireframe===!1,_t=!!y.normalMap,Gt=!!y.displacementMap,Bt=!!y.emissiveMap,Zt=!!y.metalnessMap,ne=!!y.roughnessMap,L=y.anisotropy>0,Jt=y.clearcoat>0,oe=y.dispersion>0,T=y.retroreflectivity>0,x=y.iridescence>0,k=y.sheen>0,X=y.transmission>0,et=L&&!!y.anisotropyMap,bt=Jt&&!!y.clearcoatMap,Rt=Jt&&!!y.clearcoatNormalMap,it=Jt&&!!y.clearcoatRoughnessMap,ot=x&&!!y.iridescenceMap,It=x&&!!y.iridescenceThicknessMap,Qt=k&&!!y.sheenColorMap,Ut=k&&!!y.sheenRoughnessMap,At=!!y.specularMap,Lt=!!y.specularColorMap,ee=!!y.specularIntensityMap,fe=X&&!!y.transmissionMap,F=X&&!!y.thicknessMap,Pt=!!y.gradientMap,at=!!y.alphaMap,Dt=y.alphaTest>0,Nt=!!y.alphaHash,mt=!!y.extensions,ie=ui;y.toneMapped&&(q===null||q.isXRRenderTarget===!0)&&(ie=i.toneMapping);let qt={shaderID:lt,shaderType:y.type,shaderName:y.name,vertexShader:Et,fragmentShader:Xt,defines:y.defines,customVertexShaderID:gt,customFragmentShaderID:J,isRawShaderMaterial:y.isRawShaderMaterial===!0,glslVersion:y.glslVersion,precision:u,batching:ct,batchingColor:ct&&H._colorsTexture!==null,instancing:wt,instancingColor:wt&&H.instanceColor!==null,instancingMorph:wt&&H.morphTexture!==null,outputColorSpace:q===null?i.outputColorSpace:q.isXRRenderTarget===!0?q.texture.colorSpace:Ae.workingColorSpace,alphaToCoverage:!!y.alphaToCoverage,map:Ft,matcap:ae,envMap:K,envMapMode:K&&pt.mapping,envMapCubeUVHeight:st,aoMap:ut,lightMap:yt,bumpMap:xt,normalMap:_t,displacementMap:Gt,emissiveMap:Bt,normalMapObjectSpace:_t&&y.normalMapType===Xu,normalMapTangentSpace:_t&&y.normalMapType===vc,packedNormalMap:_t&&y.normalMapType===vc&&H2(y.normalMap.format),metalnessMap:Zt,roughnessMap:ne,anisotropy:L,anisotropyMap:et,clearcoat:Jt,clearcoatMap:bt,clearcoatNormalMap:Rt,clearcoatRoughnessMap:it,dispersion:oe,retroreflection:T,iridescence:x,iridescenceMap:ot,iridescenceThicknessMap:It,sheen:k,sheenColorMap:Qt,sheenRoughnessMap:Ut,specularMap:At,specularColorMap:Lt,specularIntensityMap:ee,transmission:X,transmissionMap:fe,thicknessMap:F,gradientMap:Pt,opaque:y.transparent===!1&&y.blending===us&&y.alphaToCoverage===!1,alphaMap:at,alphaTest:Dt,alphaHash:Nt,combine:y.combine,mapUv:Ft&&g(y.map.channel),aoMapUv:ut&&g(y.aoMap.channel),lightMapUv:yt&&g(y.lightMap.channel),bumpMapUv:xt&&g(y.bumpMap.channel),normalMapUv:_t&&g(y.normalMap.channel),displacementMapUv:Gt&&g(y.displacementMap.channel),emissiveMapUv:Bt&&g(y.emissiveMap.channel),metalnessMapUv:Zt&&g(y.metalnessMap.channel),roughnessMapUv:ne&&g(y.roughnessMap.channel),anisotropyMapUv:et&&g(y.anisotropyMap.channel),clearcoatMapUv:bt&&g(y.clearcoatMap.channel),clearcoatNormalMapUv:Rt&&g(y.clearcoatNormalMap.channel),clearcoatRoughnessMapUv:it&&g(y.clearcoatRoughnessMap.channel),iridescenceMapUv:ot&&g(y.iridescenceMap.channel),iridescenceThicknessMapUv:It&&g(y.iridescenceThicknessMap.channel),sheenColorMapUv:Qt&&g(y.sheenColorMap.channel),sheenRoughnessMapUv:Ut&&g(y.sheenRoughnessMap.channel),specularMapUv:At&&g(y.specularMap.channel),specularColorMapUv:Lt&&g(y.specularColorMap.channel),specularIntensityMapUv:ee&&g(y.specularIntensityMap.channel),transmissionMapUv:fe&&g(y.transmissionMap.channel),thicknessMapUv:F&&g(y.thicknessMap.channel),alphaMapUv:at&&g(y.alphaMap.channel),vertexTangents:!!G.attributes.tangent&&(_t||L),vertexNormals:!!G.attributes.normal,vertexColors:y.vertexColors,vertexAlphas:y.vertexColors===!0&&!!G.attributes.color&&G.attributes.color.itemSize===4,pointsUvs:H.isPoints===!0&&!!G.attributes.uv&&(Ft||at),fog:!!U,useFog:y.fog===!0,fogExp2:!!U&&U.isFogExp2,flatShading:y.wireframe===!1&&(y.flatShading===!0||G.attributes.normal===void 0&&_t===!1&&(y.isMeshLambertMaterial||y.isMeshPhongMaterial||y.isMeshStandardMaterial||y.isMeshPhysicalMaterial)),sizeAttenuation:y.sizeAttenuation===!0,logarithmicDepthBuffer:f,reversedDepthBuffer:ht,skinning:H.isSkinnedMesh===!0,hasPositionAttribute:G.attributes.position!==void 0,morphTargets:G.morphAttributes.position!==void 0,morphNormals:G.morphAttributes.normal!==void 0,morphColors:G.morphAttributes.color!==void 0,morphTargetsCount:vt,morphTextureStride:St,numSunLights:w.sun.length,numDirLights:w.directional.length,numPointLights:w.point.length,numSpotLights:w.spot.length,numSpotLightMaps:w.spotLightMap.length,numRectAreaLights:w.rectArea.length,numHemiLights:w.hemi.length,numSunLightShadows:w.sunShadowMap.length,numDirLightShadows:w.directionalShadowMap.length,numPointLightShadows:w.pointShadowMap.length,numSpotLightShadows:w.spotShadowMap.length,numSpotLightShadowsWithMaps:w.numSpotLightShadowsWithMaps,numLightProbes:w.numLightProbes,numLightProbeGrids:W.length,numClippingPlanes:r.numPlanes,numClipIntersection:r.numIntersection,dithering:y.dithering,shadowMapEnabled:i.shadowMap.enabled&&I.length>0,shadowMapType:i.shadowMap.type,toneMapping:ie,decodeVideoTexture:Ft&&y.map.isVideoTexture===!0&&Ae.getTransfer(y.map.colorSpace)===Fe,decodeVideoTextureEmissive:Bt&&y.emissiveMap.isVideoTexture===!0&&Ae.getTransfer(y.emissiveMap.colorSpace)===Fe,premultipliedAlpha:y.premultipliedAlpha,doubleSided:y.side===En,flipSided:y.side===bn,useDepthPacking:y.depthPacking>=0,depthPacking:y.depthPacking||0,index0AttributeName:y.index0AttributeName,extensionClipCullDistance:mt&&y.extensions.clipCullDistance===!0&&e.has("WEBGL_clip_cull_distance"),extensionMultiDraw:(mt&&y.extensions.multiDraw===!0||ct)&&e.has("WEBGL_multi_draw"),rendererExtensionParallelShaderCompile:e.has("KHR_parallel_shader_compile"),customProgramCacheKey:y.customProgramCacheKey()};return qt.vertexUv1s=l.has(1),qt.vertexUv2s=l.has(2),qt.vertexUv3s=l.has(3),l.clear(),qt}function m(y){let w=[];if(y.shaderID?w.push(y.shaderID):(w.push(y.customVertexShaderID),w.push(y.customFragmentShaderID)),y.defines!==void 0)for(let I in y.defines)w.push(I),w.push(y.defines[I]);return y.isRawShaderMaterial===!1&&(p(w,y),S(w,y),w.push(i.outputColorSpace)),w.push(y.customProgramCacheKey),w.join()}function p(y,w){y.push(w.precision),y.push(w.outputColorSpace),y.push(w.envMapMode),y.push(w.envMapCubeUVHeight),y.push(w.mapUv),y.push(w.alphaMapUv),y.push(w.lightMapUv),y.push(w.aoMapUv),y.push(w.bumpMapUv),y.push(w.normalMapUv),y.push(w.displacementMapUv),y.push(w.emissiveMapUv),y.push(w.metalnessMapUv),y.push(w.roughnessMapUv),y.push(w.anisotropyMapUv),y.push(w.clearcoatMapUv),y.push(w.clearcoatNormalMapUv),y.push(w.clearcoatRoughnessMapUv),y.push(w.iridescenceMapUv),y.push(w.iridescenceThicknessMapUv),y.push(w.sheenColorMapUv),y.push(w.sheenRoughnessMapUv),y.push(w.specularMapUv),y.push(w.specularColorMapUv),y.push(w.specularIntensityMapUv),y.push(w.transmissionMapUv),y.push(w.thicknessMapUv),y.push(w.combine),y.push(w.fogExp2),y.push(w.sizeAttenuation),y.push(w.morphTargetsCount),y.push(w.morphAttributeCount),y.push(w.numSunLights),y.push(w.numDirLights),y.push(w.numPointLights),y.push(w.numSpotLights),y.push(w.numSpotLightMaps),y.push(w.numHemiLights),y.push(w.numRectAreaLights),y.push(w.numSunLightShadows),y.push(w.numDirLightShadows),y.push(w.numPointLightShadows),y.push(w.numSpotLightShadows),y.push(w.numSpotLightShadowsWithMaps),y.push(w.numLightProbes),y.push(w.shadowMapType),y.push(w.toneMapping),y.push(w.numClippingPlanes),y.push(w.numClipIntersection),y.push(w.depthPacking)}function S(y,w){a.disableAll(),w.instancing&&a.enable(0),w.instancingColor&&a.enable(1),w.instancingMorph&&a.enable(2),w.matcap&&a.enable(3),w.envMap&&a.enable(4),w.normalMapObjectSpace&&a.enable(5),w.normalMapTangentSpace&&a.enable(6),w.clearcoat&&a.enable(7),w.iridescence&&a.enable(8),w.alphaTest&&a.enable(9),w.vertexColors&&a.enable(10),w.vertexAlphas&&a.enable(11),w.vertexUv1s&&a.enable(12),w.vertexUv2s&&a.enable(13),w.vertexUv3s&&a.enable(14),w.vertexTangents&&a.enable(15),w.anisotropy&&a.enable(16),w.alphaHash&&a.enable(17),w.batching&&a.enable(18),w.dispersion&&a.enable(19),w.retroreflection&&a.enable(24),w.batchingColor&&a.enable(20),w.gradientMap&&a.enable(21),w.packedNormalMap&&a.enable(22),w.vertexNormals&&a.enable(23),y.push(a.mask),a.disableAll(),w.fog&&a.enable(0),w.useFog&&a.enable(1),w.flatShading&&a.enable(2),w.logarithmicDepthBuffer&&a.enable(3),w.reversedDepthBuffer&&a.enable(4),w.skinning&&a.enable(5),w.morphTargets&&a.enable(6),w.morphNormals&&a.enable(7),w.morphColors&&a.enable(8),w.premultipliedAlpha&&a.enable(9),w.shadowMapEnabled&&a.enable(10),w.doubleSided&&a.enable(11),w.flipSided&&a.enable(12),w.useDepthPacking&&a.enable(13),w.dithering&&a.enable(14),w.transmission&&a.enable(15),w.sheen&&a.enable(16),w.opaque&&a.enable(17),w.pointsUvs&&a.enable(18),w.decodeVideoTexture&&a.enable(19),w.decodeVideoTextureEmissive&&a.enable(20),w.alphaToCoverage&&a.enable(21),w.numLightProbeGrids>0&&a.enable(22),w.hasPositionAttribute&&a.enable(23),y.push(a.mask)}function A(y){let w=d[y.type],I;if(w){let N=Ai[w];I=$i.clone(N.uniforms)}else I=y.uniforms;return I}function v(y,w){let I=h.get(w);return I!==void 0?++I.usedTimes:(I=new z2(i,w,y,s),c.push(I),h.set(w,I)),I}function b(y){if(--y.usedTimes===0){let w=c.indexOf(y);c[w]=c[c.length-1],c.pop(),h.delete(y.cacheKey),y.destroy()}}function E(y){o.remove(y)}function C(){o.dispose()}return{getParameters:_,getProgramCacheKey:m,getUniforms:A,acquireProgram:v,releaseProgram:b,releaseShaderCache:E,programs:c,dispose:C}}function G2(){let i=new WeakMap;function t(a){return i.has(a)}function e(a){let o=i.get(a);return o===void 0&&(o={},i.set(a,o)),o}function n(a){i.delete(a)}function s(a,o,l){i.get(a)[o]=l}function r(){i=new WeakMap}return{has:t,get:e,remove:n,update:s,dispose:r}}function W2(i,t){return i.groupOrder!==t.groupOrder?i.groupOrder-t.groupOrder:i.renderOrder!==t.renderOrder?i.renderOrder-t.renderOrder:i.material.id!==t.material.id?i.material.id-t.material.id:i.materialVariant!==t.materialVariant?i.materialVariant-t.materialVariant:i.z!==t.z?i.z-t.z:i.id-t.id}function Cf(i,t){return i.groupOrder!==t.groupOrder?i.groupOrder-t.groupOrder:i.renderOrder!==t.renderOrder?i.renderOrder-t.renderOrder:i.z!==t.z?t.z-i.z:i.id-t.id}function Pf(){let i=[],t=0,e=[],n=[],s=[];function r(){t=0,e.length=0,n.length=0,s.length=0}function a(u){let d=0;return u.isInstancedMesh&&(d+=2),u.isSkinnedMesh&&(d+=1),d}function o(u,d,g,_,m,p){let S=i[t];return S===void 0?(S={id:u.id,object:u,geometry:d,material:g,materialVariant:a(u),groupOrder:_,renderOrder:u.renderOrder,z:m,group:p},i[t]=S):(S.id=u.id,S.object=u,S.geometry=d,S.material=g,S.materialVariant=a(u),S.groupOrder=_,S.renderOrder=u.renderOrder,S.z=m,S.group=p),t++,S}function l(u,d,g,_,m,p,S){S.reversedDepth===!0&&(m=-m);let A=o(u,d,g,_,m,p);g.transmission>0?n.push(A):g.transparent===!0?s.push(A):e.push(A)}function c(u,d,g,_,m,p){let S=o(u,d,g,_,m,p);g.transmission>0?n.unshift(S):g.transparent===!0?s.unshift(S):e.unshift(S)}function h(u,d){e.length>1&&e.sort(u||W2),n.length>1&&n.sort(d||Cf),s.length>1&&s.sort(d||Cf)}function f(){for(let u=t,d=i.length;u<d;u++){let g=i[u];if(g.id===null)break;g.id=null,g.object=null,g.geometry=null,g.material=null,g.group=null}}return{opaque:e,transmissive:n,transparent:s,init:r,push:l,unshift:c,finish:f,sort:h}}function X2(){let i=new WeakMap;function t(n,s){let r=i.get(n),a;return r===void 0?(a=new Pf,i.set(n,[a])):s>=r.length?(a=new Pf,r.push(a)):a=r[s],a}function e(){i=new WeakMap}return{get:t,dispose:e}}function q2(){let i={};return{get:function(t){if(i[t.id]!==void 0)return i[t.id];let e;switch(t.type){case"SunLight":case"DirectionalLight":e={direction:new P,color:new se};break;case"SpotLight":e={position:new P,direction:new P,color:new se,distance:0,coneCos:0,penumbraCos:0,decay:0};break;case"PointLight":e={position:new P,color:new se,distance:0,decay:0};break;case"HemisphereLight":e={direction:new P,skyColor:new se,groundColor:new se};break;case"RectAreaLight":e={color:new se,position:new P,halfWidth:new P,halfHeight:new P};break}return i[t.id]=e,e}}}function Y2(){let i={};return{get:function(t){if(i[t.id]!==void 0)return i[t.id];let e;switch(t.type){case"SunLight":case"DirectionalLight":e={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new ft};break;case"SpotLight":e={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new ft};break;case"PointLight":e={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new ft,shadowCameraNear:1,shadowCameraFar:1e3};break}return i[t.id]=e,e}}}var $2=0;function Z2(i,t){return(t.castShadow?2:0)-(i.castShadow?2:0)+(t.map?1:0)-(i.map?1:0)}function J2(i){let t=new q2,e=Y2(),n={version:0,hash:{sunLength:-1,directionalLength:-1,pointLength:-1,spotLength:-1,rectAreaLength:-1,hemiLength:-1,numSunShadows:-1,numDirectionalShadows:-1,numPointShadows:-1,numSpotShadows:-1,numSpotMaps:-1,numLightProbes:-1},ambient:[0,0,0],probe:[],sun:[],sunShadow:[],sunShadowMap:[],sunShadowMatrix:[],sunShadowCascade:[],directional:[],directionalShadow:[],directionalShadowMap:[],directionalShadowMatrix:[],spot:[],spotLightMap:[],spotShadow:[],spotShadowMap:[],spotLightMatrix:[],rectArea:[],rectAreaLTC1:null,rectAreaLTC2:null,point:[],pointShadow:[],pointShadowMap:[],pointShadowMatrix:[],hemi:[],numSpotLightShadowsWithMaps:0,numLightProbes:0};for(let c=0;c<9;c++)n.probe.push(new P);let s=new P,r=new De,a=new De;function o(c){let h=0,f=0,u=0;for(let H=0;H<9;H++)n.probe[H].set(0,0,0);let d=0,g=0,_=0,m=0,p=0,S=0,A=0,v=0,b=0,E=0,C=0,y=0,w=0,I=0;c.sort(Z2);for(let H=0,W=c.length;H<W;H++){let U=c[H],G=U.color,rt=U.intensity,j=U.distance,pt=null;if(U.shadow&&U.shadow.map&&(U.shadow.map.texture.format===ps?pt=U.shadow.map.texture:pt=U.shadow.map.depthTexture||U.shadow.map.texture),U.isAmbientLight)h+=G.r*rt,f+=G.g*rt,u+=G.b*rt;else if(U.isLightProbe){for(let st=0;st<9;st++)n.probe[st].addScaledVector(U.sh.coefficients[st],rt);I++}else if(U.isSunLight){let st=t.get(U);if(st.color.copy(U.color).multiplyScalar(U.intensity),U.castShadow){let lt=U.shadow,O=e.get(U);O.shadowIntensity=lt.intensity,O.shadowBias=lt.bias,O.shadowNormalBias=lt.normalBias,O.shadowRadius=lt.radius,O.shadowMapSize.copy(lt.mapSize).multiply(lt.getFrameExtents()),n.sunShadow[g]=O,n.sunShadowMap[g]=pt;let vt=lt.getViewportCount();for(let St=0;St<vt;St++)n.sunShadowMatrix[_+St]=lt.getMatrix(St),n.sunShadowCascade[_+St]=lt._cascadeData[St];_+=vt,g++}n.sun[d]=st,d++}else if(U.isDirectionalLight){let st=t.get(U);if(st.color.copy(U.color).multiplyScalar(U.intensity),U.castShadow){let lt=U.shadow,O=e.get(U);O.shadowIntensity=lt.intensity,O.shadowBias=lt.bias,O.shadowNormalBias=lt.normalBias,O.shadowRadius=lt.radius,O.shadowMapSize=lt.mapSize,n.directionalShadow[m]=O,n.directionalShadowMap[m]=pt,n.directionalShadowMatrix[m]=U.shadow.matrix,b++}n.directional[m]=st,m++}else if(U.isSpotLight){let st=t.get(U);st.position.setFromMatrixPosition(U.matrixWorld),st.color.copy(G).multiplyScalar(rt),st.distance=j,st.coneCos=Math.cos(U.angle),st.penumbraCos=Math.cos(U.angle*(1-U.penumbra)),st.decay=U.decay,n.spot[S]=st;let lt=U.shadow;if(U.map&&(n.spotLightMap[y]=U.map,y++,lt.updateMatrices(U),U.castShadow&&w++),n.spotLightMatrix[S]=lt.matrix,U.castShadow){let O=e.get(U);O.shadowIntensity=lt.intensity,O.shadowBias=lt.bias,O.shadowNormalBias=lt.normalBias,O.shadowRadius=lt.radius,O.shadowMapSize=lt.mapSize,n.spotShadow[S]=O,n.spotShadowMap[S]=pt,C++}S++}else if(U.isRectAreaLight){let st=t.get(U);st.color.copy(G).multiplyScalar(rt),st.halfWidth.set(U.width*.5,0,0),st.halfHeight.set(0,U.height*.5,0),n.rectArea[A]=st,A++}else if(U.isPointLight){let st=t.get(U);if(st.color.copy(U.color).multiplyScalar(U.intensity),st.distance=U.distance,st.decay=U.decay,U.castShadow){let lt=U.shadow,O=e.get(U);O.shadowIntensity=lt.intensity,O.shadowBias=lt.bias,O.shadowNormalBias=lt.normalBias,O.shadowRadius=lt.radius,O.shadowMapSize=lt.mapSize,O.shadowCameraNear=lt.camera.near,O.shadowCameraFar=lt.camera.far,n.pointShadow[p]=O,n.pointShadowMap[p]=pt,n.pointShadowMatrix[p]=U.shadow.matrix,E++}n.point[p]=st,p++}else if(U.isHemisphereLight){let st=t.get(U);st.skyColor.copy(U.color).multiplyScalar(rt),st.groundColor.copy(U.groundColor).multiplyScalar(rt),n.hemi[v]=st,v++}}A>0&&(i.has("OES_texture_float_linear")===!0?(n.rectAreaLTC1=Vt.LTC_FLOAT_1,n.rectAreaLTC2=Vt.LTC_FLOAT_2):(n.rectAreaLTC1=Vt.LTC_HALF_1,n.rectAreaLTC2=Vt.LTC_HALF_2)),n.ambient[0]=h,n.ambient[1]=f,n.ambient[2]=u;let N=n.hash;(N.sunLength!==d||N.directionalLength!==m||N.pointLength!==p||N.spotLength!==S||N.rectAreaLength!==A||N.hemiLength!==v||N.numSunShadows!==g||N.numDirectionalShadows!==b||N.numPointShadows!==E||N.numSpotShadows!==C||N.numSpotMaps!==y||N.numLightProbes!==I)&&(n.sun.length=d,n.directional.length=m,n.spot.length=S,n.rectArea.length=A,n.point.length=p,n.hemi.length=v,n.sunShadow.length=g,n.sunShadowMap.length=g,n.sunShadowMatrix.length=_,n.sunShadowCascade.length=_,n.directionalShadow.length=b,n.directionalShadowMap.length=b,n.directionalShadowMatrix.length=b,n.pointShadow.length=E,n.pointShadowMap.length=E,n.pointShadowMatrix.length=E,n.spotShadow.length=C,n.spotShadowMap.length=C,n.spotLightMatrix.length=C+y-w,n.spotLightMap.length=y,n.numSpotLightShadowsWithMaps=w,n.numLightProbes=I,N.sunLength=d,N.directionalLength=m,N.pointLength=p,N.spotLength=S,N.rectAreaLength=A,N.hemiLength=v,N.numSunShadows=g,N.numDirectionalShadows=b,N.numPointShadows=E,N.numSpotShadows=C,N.numSpotMaps=y,N.numLightProbes=I,n.version=$2++)}function l(c,h){let f=0,u=0,d=0,g=0,_=0,m=0,p=h.matrixWorldInverse;for(let S=0,A=c.length;S<A;S++){let v=c[S];if(v.isSunLight){let b=n.sun[f];b.direction.setFromMatrixPosition(v.matrixWorld),b.direction.transformDirection(p),f++}else if(v.isDirectionalLight){let b=n.directional[u];b.direction.setFromMatrixPosition(v.matrixWorld),s.setFromMatrixPosition(v.target.matrixWorld),b.direction.sub(s),b.direction.transformDirection(p),u++}else if(v.isSpotLight){let b=n.spot[g];b.position.setFromMatrixPosition(v.matrixWorld),b.position.applyMatrix4(p),b.direction.setFromMatrixPosition(v.matrixWorld),s.setFromMatrixPosition(v.target.matrixWorld),b.direction.sub(s),b.direction.transformDirection(p),g++}else if(v.isRectAreaLight){let b=n.rectArea[_];b.position.setFromMatrixPosition(v.matrixWorld),b.position.applyMatrix4(p),a.identity(),r.copy(v.matrixWorld),r.premultiply(p),a.extractRotation(r),b.halfWidth.set(v.width*.5,0,0),b.halfHeight.set(0,v.height*.5,0),b.halfWidth.applyMatrix4(a),b.halfHeight.applyMatrix4(a),_++}else if(v.isPointLight){let b=n.point[d];b.position.setFromMatrixPosition(v.matrixWorld),b.position.applyMatrix4(p),d++}else if(v.isHemisphereLight){let b=n.hemi[m];b.direction.setFromMatrixPosition(v.matrixWorld),b.direction.transformDirection(p),m++}}}return{setup:o,setupView:l,state:n}}function If(i){let t=new J2(i),e=[],n=[],s=[];function r(u){f.camera=u,e.length=0,n.length=0,s.length=0}function a(u){e.push(u)}function o(u){n.push(u)}function l(u){s.push(u)}function c(){t.setup(e)}function h(u){t.setupView(e,u)}let f={lightsArray:e,shadowsArray:n,lightProbeGridArray:s,camera:null,lights:t,transmissionRenderTarget:{},textureUnits:0};return{init:r,state:f,setupLights:c,setupLightsView:h,pushLight:a,pushShadow:o,pushLightProbeGrid:l}}function K2(i){let t=new WeakMap;function e(s,r=0){let a=t.get(s),o;return a===void 0?(o=new If(i),t.set(s,[o])):r>=a.length?(o=new If(i),a.push(o)):o=a[r],o}function n(){t=new WeakMap}return{get:e,dispose:n}}var j2=`void main() {
	gl_Position = vec4( position, 1.0 );
}`,Q2=`uniform sampler2D shadow_pass;
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
}`,tx=[new P(1,0,0),new P(-1,0,0),new P(0,1,0),new P(0,-1,0),new P(0,0,1),new P(0,0,-1)],ex=[new P(0,-1,0),new P(0,-1,0),new P(0,0,1),new P(0,0,-1),new P(0,-1,0),new P(0,-1,0)],Lf=new De,lo=new P,sh=new P;function nx(i,t,e){let n=new pr,s=new ft,r=new ft,a=new $e,o=new yl,l=new Ml,c={},h=e.maxTextureSize,f={[hs]:bn,[bn]:hs,[En]:En},u=new He({defines:{VSM_SAMPLES:8},uniforms:{shadow_pass:{value:null},resolution:{value:new ft},radius:{value:4}},vertexShader:j2,fragmentShader:Q2}),d=u.clone();d.defines.HORIZONTAL_PASS=1;let g=new Ie;g.setAttribute("position",new sn(new Float32Array([-1,-1,.5,3,-1,.5,-1,3,.5]),3));let _=new Se(g,u),m=this;this.enabled=!1,this.autoUpdate=!0,this.needsUpdate=!1,this.type=qa;let p=this.type;this.render=function(E,C,y){if(m.enabled===!1||m.autoUpdate===!1&&m.needsUpdate===!1||E.length===0)return;this.type===Su&&(ue("WebGLShadowMap: PCFSoftShadowMap has been removed. Using PCFShadowMap instead."),this.type=qa);let w=i.getRenderTarget(),I=i.getActiveCubeFace(),N=i.getActiveMipmapLevel(),H=i.state;H.setBlending(Qn),H.buffers.depth.getReversed()===!0?H.buffers.color.setClear(0,0,0,0):H.buffers.color.setClear(1,1,1,1),H.buffers.depth.setTest(!0),H.setScissorTest(!1);let W=p!==this.type;W&&C.traverse(function(U){U.material&&(Array.isArray(U.material)?U.material.forEach(G=>G.needsUpdate=!0):U.material.needsUpdate=!0)});for(let U=0,G=E.length;U<G;U++){let rt=E[U],j=rt.shadow;if(j===void 0){ue("WebGLShadowMap:",rt,"has no shadow.");continue}if(j.autoUpdate===!1&&j.needsUpdate===!1)continue;s.copy(j.mapSize);let pt=j.getFrameExtents();s.multiply(pt),r.copy(j.mapSize),(s.x>h||s.y>h)&&(s.x>h&&(r.x=Math.floor(h/pt.x),s.x=r.x*pt.x,j.mapSize.x=r.x),s.y>h&&(r.y=Math.floor(h/pt.y),s.y=r.y*pt.y,j.mapSize.y=r.y));let st=i.state.buffers.depth.getReversed();if(j.camera._reversedDepth=st,j.map===null||W===!0){if(j.map!==null&&(j.map.depthTexture!==null&&(j.map.depthTexture.dispose(),j.map.depthTexture=null),j.map.dispose()),this.type===wr){if(rt.isPointLight){ue("WebGLShadowMap: VSM shadow maps are not supported for PointLights. Use PCF or BasicShadowMap instead.");continue}j.map=new tn(s.x,s.y,{format:ps,type:un,minFilter:Sn,magFilter:Sn,generateMipmaps:!1}),j.map.texture.name=rt.name+".shadowMap",j.map.depthTexture=new ss(s.x,s.y,ti),j.map.depthTexture.name=rt.name+".shadowMapDepth",j.map.depthTexture.format=Mi,j.map.depthTexture.compareFunction=null,j.map.depthTexture.minFilter=gn,j.map.depthTexture.magFilter=gn}else rt.isPointLight?(j.map=new Tc(s.x),j.map.depthTexture=new ml(s.x,fi)):(j.map=new tn(s.x,s.y),j.map.depthTexture=new ss(s.x,s.y,fi)),j.map.depthTexture.name=rt.name+".shadowMap",j.map.depthTexture.format=Mi,this.type===qa?(j.map.depthTexture.compareFunction=st?Mc:yc,j.map.depthTexture.minFilter=Sn,j.map.depthTexture.magFilter=Sn):(j.map.depthTexture.compareFunction=null,j.map.depthTexture.minFilter=gn,j.map.depthTexture.magFilter=gn);j.camera.updateProjectionMatrix()}j.map.isWebGLCubeRenderTarget!==!0&&(j.map.width!==s.x||j.map.height!==s.y)&&j.map.setSize(s.x,s.y);let lt=j.map.isWebGLCubeRenderTarget?6:j.getViewportCount();rt.isPointLight!==!0&&j.updateMatrices(rt,y);for(let O=0;O<lt;O++){let vt=j.getCamera(O);if(rt.isPointLight){let St=j.camera,Et=j.matrix,Xt=rt.distance||St.far;Xt!==St.far&&(St.far=Xt,St.updateProjectionMatrix()),lo.setFromMatrixPosition(rt.matrixWorld),St.position.copy(lo),sh.copy(St.position),sh.add(tx[O]),St.up.copy(ex[O]),St.lookAt(sh),St.updateMatrixWorld(),Et.makeTranslation(-lo.x,-lo.y,-lo.z),Lf.multiplyMatrices(St.projectionMatrix,St.matrixWorldInverse),j._frustum.setFromProjectionMatrix(Lf,St.coordinateSystem,St.reversedDepth)}if(j.map.isWebGLCubeRenderTarget)i.setRenderTarget(j.map,O),i.clear();else{O===0&&(i.setRenderTarget(j.map),i.clear());let St=j.getViewport(O);a.set(r.x*St.x,r.y*St.y,r.x*St.z,r.y*St.w),H.viewport(a)}n=j.getFrustum(O),v(C,y,vt,rt,this.type)}j.isPointLightShadow!==!0&&this.type===wr&&S(j,y),j.needsUpdate=!1}p=this.type,m.needsUpdate=!1,i.setRenderTarget(w,I,N)};function S(E,C){let y=t.update(_);u.defines.VSM_SAMPLES!==E.blurSamples&&(u.defines.VSM_SAMPLES=E.blurSamples,d.defines.VSM_SAMPLES=E.blurSamples,u.needsUpdate=!0,d.needsUpdate=!0),E.mapPass===null?E.mapPass=new tn(s.x,s.y,{format:ps,type:un}):(E.mapPass.width!==E.map.width||E.mapPass.height!==E.map.height)&&E.mapPass.setSize(E.map.width,E.map.height),u.uniforms.shadow_pass.value=E.map.depthTexture,u.uniforms.resolution.value.set(E.map.width,E.map.height),u.uniforms.radius.value=E.radius,i.setRenderTarget(E.mapPass),i.clear(),i.renderBufferDirect(C,null,y,u,_,null),d.uniforms.shadow_pass.value=E.mapPass.texture,d.uniforms.resolution.value.set(E.map.width,E.map.height),d.uniforms.radius.value=E.radius,i.setRenderTarget(E.map),i.clear(),i.renderBufferDirect(C,null,y,d,_,null)}function A(E,C,y,w){let I=null,N=y.isPointLight===!0?E.customDistanceMaterial:E.customDepthMaterial;if(N!==void 0)I=N;else if(I=y.isPointLight===!0?l:o,i.localClippingEnabled&&C.clipShadows===!0&&Array.isArray(C.clippingPlanes)&&C.clippingPlanes.length!==0||C.displacementMap&&C.displacementScale!==0||C.alphaMap&&C.alphaTest>0||C.map&&C.alphaTest>0||C.alphaToCoverage===!0){let H=I.uuid,W=C.uuid,U=c[H];U===void 0&&(U={},c[H]=U);let G=U[W];G===void 0&&(G=I.clone(),U[W]=G,C.addEventListener("dispose",b)),I=G}if(I.visible=C.visible,I.wireframe=C.wireframe,w===wr?I.side=C.shadowSide!==null?C.shadowSide:C.side:I.side=C.shadowSide!==null?C.shadowSide:f[C.side],I.alphaMap=C.alphaMap,I.alphaTest=C.alphaToCoverage===!0?.5:C.alphaTest,I.map=C.map,I.clipShadows=C.clipShadows,I.clippingPlanes=C.clippingPlanes,I.clipIntersection=C.clipIntersection,I.displacementMap=C.displacementMap,I.displacementScale=C.displacementScale,I.displacementBias=C.displacementBias,I.wireframeLinewidth=C.wireframeLinewidth,I.linewidth=C.linewidth,y.isPointLight===!0&&I.isMeshDistanceMaterial===!0){let H=i.properties.get(I);H.light=y}return I}function v(E,C,y,w,I){if(E.visible===!1)return;if(E.layers.test(C.layers)&&(E.isMesh||E.isLine||E.isPoints)&&(E.castShadow||E.receiveShadow&&I===wr)&&(!E.frustumCulled||E.intersectsFrustum(n))){E.modelViewMatrix.multiplyMatrices(y.matrixWorldInverse,E.matrixWorld);let W=t.update(E),U=E.material;if(Array.isArray(U)){let G=W.groups;for(let rt=0,j=G.length;rt<j;rt++){let pt=G[rt],st=U[pt.materialIndex];if(st&&st.visible){let lt=A(E,st,w,I);E.onBeforeShadow(i,E,C,y,W,lt,pt),i.renderBufferDirect(y,null,W,lt,E,pt),E.onAfterShadow(i,E,C,y,W,lt,pt)}}}else if(U.visible){let G=A(E,U,w,I);E.onBeforeShadow(i,E,C,y,W,G,null),i.renderBufferDirect(y,null,W,G,E,null),E.onAfterShadow(i,E,C,y,W,G,null)}}let H=E.children;for(let W=0,U=H.length;W<U;W++)v(H[W],C,y,w,I)}function b(E){E.target.removeEventListener("dispose",b);for(let y in c){let w=c[y],I=E.target.uuid;I in w&&(w[I].dispose(),delete w[I])}}}function ix(i,t){function e(){let F=!1,Pt=new $e,at=null,Dt=new $e(0,0,0,0);return{setMask:function(Nt){at!==Nt&&!F&&(i.colorMask(Nt,Nt,Nt,Nt),at=Nt)},setLocked:function(Nt){F=Nt},setClear:function(Nt,mt,ie,qt,Oe){Oe===!0&&(Nt*=qt,mt*=qt,ie*=qt),Pt.set(Nt,mt,ie,qt),Dt.equals(Pt)===!1&&(i.clearColor(Nt,mt,ie,qt),Dt.copy(Pt))},reset:function(){F=!1,at=null,Dt.set(-1,0,0,0)}}}function n(){let F=!1,Pt=!1,at=null,Dt=null,Nt=null;return{setReversed:function(mt){if(Pt!==mt){let ie=t.get("EXT_clip_control");mt?ie.clipControlEXT(ie.LOWER_LEFT_EXT,ie.ZERO_TO_ONE_EXT):ie.clipControlEXT(ie.LOWER_LEFT_EXT,ie.NEGATIVE_ONE_TO_ONE_EXT),Pt=mt;let qt=Nt;Nt=null,this.setClear(qt)}},getReversed:function(){return Pt},setTest:function(mt){mt?q(i.DEPTH_TEST):ht(i.DEPTH_TEST)},setMask:function(mt){at!==mt&&!F&&(i.depthMask(mt),at=mt)},setFunc:function(mt){if(Pt&&(mt=nf[mt]),Dt!==mt){switch(mt){case Qo:i.depthFunc(i.NEVER);break;case tl:i.depthFunc(i.ALWAYS);break;case el:i.depthFunc(i.LESS);break;case rr:i.depthFunc(i.LEQUAL);break;case nl:i.depthFunc(i.EQUAL);break;case il:i.depthFunc(i.GEQUAL);break;case sl:i.depthFunc(i.GREATER);break;case rl:i.depthFunc(i.NOTEQUAL);break;default:i.depthFunc(i.LEQUAL)}Dt=mt}},setLocked:function(mt){F=mt},setClear:function(mt){Nt!==mt&&(Nt=mt,Pt&&(mt=1-mt),i.clearDepth(mt))},reset:function(){F=!1,at=null,Dt=null,Nt=null,Pt=!1}}}function s(){let F=!1,Pt=null,at=null,Dt=null,Nt=null,mt=null,ie=null,qt=null,Oe=null;return{setTest:function(Ue){F||(Ue?q(i.STENCIL_TEST):ht(i.STENCIL_TEST))},setMask:function(Ue){Pt!==Ue&&!F&&(i.stencilMask(Ue),Pt=Ue)},setFunc:function(Ue,en,Nn){(at!==Ue||Dt!==en||Nt!==Nn)&&(i.stencilFunc(Ue,en,Nn),at=Ue,Dt=en,Nt=Nn)},setOp:function(Ue,en,Nn){(mt!==Ue||ie!==en||qt!==Nn)&&(i.stencilOp(Ue,en,Nn),mt=Ue,ie=en,qt=Nn)},setLocked:function(Ue){F=Ue},setClear:function(Ue){Oe!==Ue&&(i.clearStencil(Ue),Oe=Ue)},reset:function(){F=!1,Pt=null,at=null,Dt=null,Nt=null,mt=null,ie=null,qt=null,Oe=null}}}let r=new e,a=new n,o=new s,l=new WeakMap,c=new WeakMap,h={},f={},u={},d=new WeakMap,g=[],_=null,m=!1,p=null,S=null,A=null,v=null,b=null,E=null,C=null,y=new se(0,0,0),w=0,I=!1,N=null,H=null,W=null,U=null,G=null,rt=i.getParameter(i.MAX_COMBINED_TEXTURE_IMAGE_UNITS),j=!1,pt=0,st=i.getParameter(i.VERSION);st.indexOf("WebGL")!==-1?(pt=parseFloat(/^WebGL (\d)/.exec(st)[1]),j=pt>=1):st.indexOf("OpenGL ES")!==-1&&(pt=parseFloat(/^OpenGL ES (\d)/.exec(st)[1]),j=pt>=2);let lt=null,O={},vt=i.getParameter(i.SCISSOR_BOX),St=i.getParameter(i.VIEWPORT),Et=new $e().fromArray(vt),Xt=new $e().fromArray(St);function gt(F,Pt,at,Dt){let Nt=new Uint8Array(4),mt=i.createTexture();i.bindTexture(F,mt),i.texParameteri(F,i.TEXTURE_MIN_FILTER,i.NEAREST),i.texParameteri(F,i.TEXTURE_MAG_FILTER,i.NEAREST);for(let ie=0;ie<at;ie++)F===i.TEXTURE_3D||F===i.TEXTURE_2D_ARRAY?i.texImage3D(Pt,0,i.RGBA,1,1,Dt,0,i.RGBA,i.UNSIGNED_BYTE,Nt):i.texImage2D(Pt+ie,0,i.RGBA,1,1,0,i.RGBA,i.UNSIGNED_BYTE,Nt);return mt}let J={};J[i.TEXTURE_2D]=gt(i.TEXTURE_2D,i.TEXTURE_2D,1),J[i.TEXTURE_CUBE_MAP]=gt(i.TEXTURE_CUBE_MAP,i.TEXTURE_CUBE_MAP_POSITIVE_X,6),J[i.TEXTURE_2D_ARRAY]=gt(i.TEXTURE_2D_ARRAY,i.TEXTURE_2D_ARRAY,1,1),J[i.TEXTURE_3D]=gt(i.TEXTURE_3D,i.TEXTURE_3D,1,1),r.setClear(0,0,0,1),a.setClear(1),o.setClear(0),q(i.DEPTH_TEST),a.setFunc(rr),xt(!1),_t(D0),q(i.CULL_FACE),ut(Qn);function q(F){h[F]!==!0&&(i.enable(F),h[F]=!0)}function ht(F){h[F]!==!1&&(i.disable(F),h[F]=!1)}function wt(F,Pt){return u[F]!==Pt?(i.bindFramebuffer(F,Pt),u[F]=Pt,F===i.DRAW_FRAMEBUFFER&&(u[i.FRAMEBUFFER]=Pt),F===i.FRAMEBUFFER&&(u[i.DRAW_FRAMEBUFFER]=Pt),!0):!1}function ct(F,Pt){let at=g,Dt=!1;if(F){at=d.get(Pt),at===void 0&&(at=[],d.set(Pt,at));let Nt=F.textures;if(at.length!==Nt.length||at[0]!==i.COLOR_ATTACHMENT0){for(let mt=0,ie=Nt.length;mt<ie;mt++)at[mt]=i.COLOR_ATTACHMENT0+mt;at.length=Nt.length,Dt=!0}}else at[0]!==i.BACK&&(at[0]=i.BACK,Dt=!0);Dt&&i.drawBuffers(at)}function Ft(F){return _!==F?(i.useProgram(F),_=F,!0):!1}let ae={[As]:i.FUNC_ADD,[Eu]:i.FUNC_SUBTRACT,[Tu]:i.FUNC_REVERSE_SUBTRACT};ae[wu]=i.MIN,ae[Au]=i.MAX;let K={[Ru]:i.ZERO,[Cu]:i.ONE,[Pu]:i.SRC_COLOR,[F0]:i.SRC_ALPHA,[Fu]:i.SRC_ALPHA_SATURATE,[Nu]:i.DST_COLOR,[Lu]:i.DST_ALPHA,[Iu]:i.ONE_MINUS_SRC_COLOR,[O0]:i.ONE_MINUS_SRC_ALPHA,[Uu]:i.ONE_MINUS_DST_COLOR,[Du]:i.ONE_MINUS_DST_ALPHA,[Ou]:i.CONSTANT_COLOR,[Bu]:i.ONE_MINUS_CONSTANT_COLOR,[zu]:i.CONSTANT_ALPHA,[ku]:i.ONE_MINUS_CONSTANT_ALPHA};function ut(F,Pt,at,Dt,Nt,mt,ie,qt,Oe,Ue){if(F===Qn){m===!0&&(ht(i.BLEND),m=!1);return}if(m===!1&&(q(i.BLEND),m=!0),F!==bu){if(F!==p||Ue!==I){if((S!==As||b!==As)&&(i.blendEquation(i.FUNC_ADD),S=As,b=As),Ue)switch(F){case us:i.blendFuncSeparate(i.ONE,i.ONE_MINUS_SRC_ALPHA,i.ONE,i.ONE_MINUS_SRC_ALPHA);break;case hn:i.blendFunc(i.ONE,i.ONE);break;case N0:i.blendFuncSeparate(i.ZERO,i.ONE_MINUS_SRC_COLOR,i.ZERO,i.ONE);break;case U0:i.blendFuncSeparate(i.DST_COLOR,i.ONE_MINUS_SRC_ALPHA,i.ZERO,i.ONE);break;default:he("WebGLState: Invalid blending: ",F);break}else switch(F){case us:i.blendFuncSeparate(i.SRC_ALPHA,i.ONE_MINUS_SRC_ALPHA,i.ONE,i.ONE_MINUS_SRC_ALPHA);break;case hn:i.blendFuncSeparate(i.SRC_ALPHA,i.ONE,i.ONE,i.ONE);break;case N0:he("WebGLState: SubtractiveBlending requires material.premultipliedAlpha = true");break;case U0:he("WebGLState: MultiplyBlending requires material.premultipliedAlpha = true");break;default:he("WebGLState: Invalid blending: ",F);break}A=null,v=null,E=null,C=null,y.set(0,0,0),w=0,p=F,I=Ue}return}Nt=Nt||Pt,mt=mt||at,ie=ie||Dt,(Pt!==S||Nt!==b)&&(i.blendEquationSeparate(ae[Pt],ae[Nt]),S=Pt,b=Nt),(at!==A||Dt!==v||mt!==E||ie!==C)&&(i.blendFuncSeparate(K[at],K[Dt],K[mt],K[ie]),A=at,v=Dt,E=mt,C=ie),(qt.equals(y)===!1||Oe!==w)&&(i.blendColor(qt.r,qt.g,qt.b,Oe),y.copy(qt),w=Oe),p=F,I=!1}function yt(F,Pt){F.side===En?ht(i.CULL_FACE):q(i.CULL_FACE);let at=F.side===bn;Pt&&(at=!at),xt(at),F.blending===us&&F.transparent===!1?ut(Qn):ut(F.blending,F.blendEquation,F.blendSrc,F.blendDst,F.blendEquationAlpha,F.blendSrcAlpha,F.blendDstAlpha,F.blendColor,F.blendAlpha,F.premultipliedAlpha),a.setFunc(F.depthFunc),a.setTest(F.depthTest),a.setMask(F.depthWrite),r.setMask(F.colorWrite);let Dt=F.stencilWrite;o.setTest(Dt),Dt&&(o.setMask(F.stencilWriteMask),o.setFunc(F.stencilFunc,F.stencilRef,F.stencilFuncMask),o.setOp(F.stencilFail,F.stencilZFail,F.stencilZPass)),Bt(F.polygonOffset,F.polygonOffsetFactor,F.polygonOffsetUnits),F.alphaToCoverage===!0?q(i.SAMPLE_ALPHA_TO_COVERAGE):ht(i.SAMPLE_ALPHA_TO_COVERAGE)}function xt(F){N!==F&&(F?i.frontFace(i.CW):i.frontFace(i.CCW),N=F)}function _t(F){F!==yu?(q(i.CULL_FACE),F!==H&&(F===D0?i.cullFace(i.BACK):F===Mu?i.cullFace(i.FRONT):i.cullFace(i.FRONT_AND_BACK))):ht(i.CULL_FACE),H=F}function Gt(F){F!==W&&(j&&i.lineWidth(F),W=F)}function Bt(F,Pt,at){F?(q(i.POLYGON_OFFSET_FILL),(U!==Pt||G!==at)&&(U=Pt,G=at,a.getReversed()&&(Pt=-Pt),i.polygonOffset(Pt,at))):ht(i.POLYGON_OFFSET_FILL)}function Zt(F){F?q(i.SCISSOR_TEST):ht(i.SCISSOR_TEST)}function ne(F){F===void 0&&(F=i.TEXTURE0+rt-1),lt!==F&&(i.activeTexture(F),lt=F)}function L(F,Pt,at){at===void 0&&(lt===null?at=i.TEXTURE0+rt-1:at=lt);let Dt=O[at];Dt===void 0&&(Dt={type:void 0,texture:void 0},O[at]=Dt),(Dt.type!==F||Dt.texture!==Pt)&&(lt!==at&&(i.activeTexture(at),lt=at),i.bindTexture(F,Pt||J[F]),Dt.type=F,Dt.texture=Pt)}function Jt(){let F=O[lt];F!==void 0&&F.type!==void 0&&(i.bindTexture(F.type,null),F.type=void 0,F.texture=void 0)}function oe(){try{i.compressedTexImage2D(...arguments)}catch(F){he("WebGLState:",F)}}function T(){try{i.compressedTexImage3D(...arguments)}catch(F){he("WebGLState:",F)}}function x(){try{i.texSubImage2D(...arguments)}catch(F){he("WebGLState:",F)}}function k(){try{i.texSubImage3D(...arguments)}catch(F){he("WebGLState:",F)}}function X(){try{i.compressedTexSubImage2D(...arguments)}catch(F){he("WebGLState:",F)}}function et(){try{i.compressedTexSubImage3D(...arguments)}catch(F){he("WebGLState:",F)}}function bt(){try{i.texStorage2D(...arguments)}catch(F){he("WebGLState:",F)}}function Rt(){try{i.texStorage3D(...arguments)}catch(F){he("WebGLState:",F)}}function it(){try{i.texImage2D(...arguments)}catch(F){he("WebGLState:",F)}}function ot(){try{i.texImage3D(...arguments)}catch(F){he("WebGLState:",F)}}function It(F){return f[F]!==void 0?f[F]:i.getParameter(F)}function Qt(F,Pt){f[F]!==Pt&&(i.pixelStorei(F,Pt),f[F]=Pt)}function Ut(F){Et.equals(F)===!1&&(i.scissor(F.x,F.y,F.z,F.w),Et.copy(F))}function At(F){Xt.equals(F)===!1&&(i.viewport(F.x,F.y,F.z,F.w),Xt.copy(F))}function Lt(F,Pt){let at=c.get(Pt);at===void 0&&(at=new WeakMap,c.set(Pt,at));let Dt=at.get(F);Dt===void 0&&(Dt=i.getUniformBlockIndex(Pt,F.name),at.set(F,Dt))}function ee(F,Pt){let Dt=c.get(Pt).get(F);l.get(Pt)!==Dt&&(i.uniformBlockBinding(Pt,Dt,F.__bindingPointIndex),l.set(Pt,Dt))}function fe(){i.disable(i.BLEND),i.disable(i.CULL_FACE),i.disable(i.DEPTH_TEST),i.disable(i.POLYGON_OFFSET_FILL),i.disable(i.SCISSOR_TEST),i.disable(i.STENCIL_TEST),i.disable(i.SAMPLE_ALPHA_TO_COVERAGE),i.blendEquation(i.FUNC_ADD),i.blendFunc(i.ONE,i.ZERO),i.blendFuncSeparate(i.ONE,i.ZERO,i.ONE,i.ZERO),i.blendColor(0,0,0,0),i.colorMask(!0,!0,!0,!0),i.clearColor(0,0,0,0),i.depthMask(!0),i.depthFunc(i.LESS),a.setReversed(!1),i.clearDepth(1),i.stencilMask(4294967295),i.stencilFunc(i.ALWAYS,0,4294967295),i.stencilOp(i.KEEP,i.KEEP,i.KEEP),i.clearStencil(0),i.cullFace(i.BACK),i.frontFace(i.CCW),i.polygonOffset(0,0),i.activeTexture(i.TEXTURE0),i.bindFramebuffer(i.FRAMEBUFFER,null),i.bindFramebuffer(i.DRAW_FRAMEBUFFER,null),i.bindFramebuffer(i.READ_FRAMEBUFFER,null),i.useProgram(null),i.lineWidth(1),i.scissor(0,0,i.canvas.width,i.canvas.height),i.viewport(0,0,i.canvas.width,i.canvas.height),i.pixelStorei(i.PACK_ALIGNMENT,4),i.pixelStorei(i.UNPACK_ALIGNMENT,4),i.pixelStorei(i.UNPACK_FLIP_Y_WEBGL,!1),i.pixelStorei(i.UNPACK_PREMULTIPLY_ALPHA_WEBGL,!1),i.pixelStorei(i.UNPACK_COLORSPACE_CONVERSION_WEBGL,i.BROWSER_DEFAULT_WEBGL),i.pixelStorei(i.PACK_ROW_LENGTH,0),i.pixelStorei(i.PACK_SKIP_PIXELS,0),i.pixelStorei(i.PACK_SKIP_ROWS,0),i.pixelStorei(i.UNPACK_ROW_LENGTH,0),i.pixelStorei(i.UNPACK_IMAGE_HEIGHT,0),i.pixelStorei(i.UNPACK_SKIP_PIXELS,0),i.pixelStorei(i.UNPACK_SKIP_ROWS,0),i.pixelStorei(i.UNPACK_SKIP_IMAGES,0),h={},f={},lt=null,O={},u={},d=new WeakMap,g=[],_=null,m=!1,p=null,S=null,A=null,v=null,b=null,E=null,C=null,y=new se(0,0,0),w=0,I=!1,N=null,H=null,W=null,U=null,G=null,Et.set(0,0,i.canvas.width,i.canvas.height),Xt.set(0,0,i.canvas.width,i.canvas.height),r.reset(),a.reset(),o.reset()}return{buffers:{color:r,depth:a,stencil:o},enable:q,disable:ht,bindFramebuffer:wt,drawBuffers:ct,useProgram:Ft,setBlending:ut,setMaterial:yt,setFlipSided:xt,setCullFace:_t,setLineWidth:Gt,setPolygonOffset:Bt,setScissorTest:Zt,activeTexture:ne,bindTexture:L,unbindTexture:Jt,compressedTexImage2D:oe,compressedTexImage3D:T,texImage2D:it,texImage3D:ot,pixelStorei:Qt,getParameter:It,updateUBOMapping:Lt,uniformBlockBinding:ee,texStorage2D:bt,texStorage3D:Rt,texSubImage2D:x,texSubImage3D:k,compressedTexSubImage2D:X,compressedTexSubImage3D:et,scissor:Ut,viewport:At,reset:fe}}function sx(i,t,e,n,s,r,a){let o=t.has("WEBGL_multisampled_render_to_texture")?t.get("WEBGL_multisampled_render_to_texture"):null,l=typeof navigator>"u"?!1:/OculusBrowser/g.test(navigator.userAgent),c=new ft,h=new WeakMap,f=new Set,u,d=new WeakMap,g=!1;try{g=typeof OffscreenCanvas<"u"&&new OffscreenCanvas(1,1).getContext("2d")!==null}catch{}function _(T,x){return g?new OffscreenCanvas(T,x):or("canvas")}function m(T,x,k){let X=1,et=oe(T);if((et.width>k||et.height>k)&&(X=k/Math.max(et.width,et.height)),X<1)if(typeof HTMLImageElement<"u"&&T instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&T instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&T instanceof ImageBitmap||typeof VideoFrame<"u"&&T instanceof VideoFrame){let bt=Math.floor(X*et.width),Rt=Math.floor(X*et.height);u===void 0&&(u=_(bt,Rt));let it=x?_(bt,Rt):u;return it.width=bt,it.height=Rt,it.getContext("2d").drawImage(T,0,0,bt,Rt),ue("WebGLRenderer: Texture has been resized from ("+et.width+"x"+et.height+") to ("+bt+"x"+Rt+")."),it}else return"data"in T&&ue("WebGLRenderer: Image in DataTexture is too big ("+et.width+"x"+et.height+")."),T;return T}function p(T){return T.generateMipmaps}function S(T){i.generateMipmap(T)}function A(T){return T.isWebGLCubeRenderTarget?i.TEXTURE_CUBE_MAP:T.isWebGL3DRenderTarget?i.TEXTURE_3D:T.isWebGLArrayRenderTarget||T.isCompressedArrayTexture?i.TEXTURE_2D_ARRAY:i.TEXTURE_2D}function v(T,x,k,X,et,bt=!1){if(T!==null){if(i[T]!==void 0)return i[T];ue("WebGLRenderer: Attempt to use non-existing WebGL internal format '"+T+"'")}let Rt;X&&(Rt=t.get("EXT_texture_norm16"),Rt||ue("WebGLRenderer: Unable to use normalized textures without EXT_texture_norm16 extension"));let it=x;if(x===i.RED&&(k===i.FLOAT&&(it=i.R32F),k===i.HALF_FLOAT&&(it=i.R16F),k===i.UNSIGNED_BYTE&&(it=i.R8),k===i.UNSIGNED_SHORT&&Rt&&(it=Rt.R16_EXT),k===i.SHORT&&Rt&&(it=Rt.R16_SNORM_EXT)),x===i.RED_INTEGER&&(k===i.UNSIGNED_BYTE&&(it=i.R8UI),k===i.UNSIGNED_SHORT&&(it=i.R16UI),k===i.UNSIGNED_INT&&(it=i.R32UI),k===i.BYTE&&(it=i.R8I),k===i.SHORT&&(it=i.R16I),k===i.INT&&(it=i.R32I)),x===i.RG&&(k===i.FLOAT&&(it=i.RG32F),k===i.HALF_FLOAT&&(it=i.RG16F),k===i.UNSIGNED_BYTE&&(it=i.RG8),k===i.UNSIGNED_SHORT&&Rt&&(it=Rt.RG16_EXT),k===i.SHORT&&Rt&&(it=Rt.RG16_SNORM_EXT)),x===i.RG_INTEGER&&(k===i.UNSIGNED_BYTE&&(it=i.RG8UI),k===i.UNSIGNED_SHORT&&(it=i.RG16UI),k===i.UNSIGNED_INT&&(it=i.RG32UI),k===i.BYTE&&(it=i.RG8I),k===i.SHORT&&(it=i.RG16I),k===i.INT&&(it=i.RG32I)),x===i.RGB_INTEGER&&(k===i.UNSIGNED_BYTE&&(it=i.RGB8UI),k===i.UNSIGNED_SHORT&&(it=i.RGB16UI),k===i.UNSIGNED_INT&&(it=i.RGB32UI),k===i.BYTE&&(it=i.RGB8I),k===i.SHORT&&(it=i.RGB16I),k===i.INT&&(it=i.RGB32I)),x===i.RGBA_INTEGER&&(k===i.UNSIGNED_BYTE&&(it=i.RGBA8UI),k===i.UNSIGNED_SHORT&&(it=i.RGBA16UI),k===i.UNSIGNED_INT&&(it=i.RGBA32UI),k===i.BYTE&&(it=i.RGBA8I),k===i.SHORT&&(it=i.RGBA16I),k===i.INT&&(it=i.RGBA32I)),x===i.RGB&&(k===i.UNSIGNED_SHORT&&Rt&&(it=Rt.RGB16_EXT),k===i.SHORT&&Rt&&(it=Rt.RGB16_SNORM_EXT),k===i.UNSIGNED_INT_5_9_9_9_REV&&(it=i.RGB9_E5),k===i.UNSIGNED_INT_10F_11F_11F_REV&&(it=i.R11F_G11F_B10F)),x===i.RGBA){let ot=bt?ca:Ae.getTransfer(et);k===i.FLOAT&&(it=i.RGBA32F),k===i.HALF_FLOAT&&(it=i.RGBA16F),k===i.UNSIGNED_BYTE&&(it=ot===Fe?i.SRGB8_ALPHA8:i.RGBA8),k===i.UNSIGNED_SHORT&&Rt&&(it=Rt.RGBA16_EXT),k===i.SHORT&&Rt&&(it=Rt.RGBA16_SNORM_EXT),k===i.UNSIGNED_SHORT_4_4_4_4&&(it=i.RGBA4),k===i.UNSIGNED_SHORT_5_5_5_1&&(it=i.RGB5_A1)}return(it===i.R16F||it===i.R32F||it===i.RG16F||it===i.RG32F||it===i.RGBA16F||it===i.RGBA32F)&&t.get("EXT_color_buffer_float"),it}function b(T,x){let k;return T?x===null||x===fi||x===Cr?k=i.DEPTH24_STENCIL8:x===ti?k=i.DEPTH32F_STENCIL8:x===Rr&&(k=i.DEPTH24_STENCIL8,ue("DepthTexture: 16 bit depth attachment is not supported with stencil. Using 24-bit attachment.")):x===null||x===fi||x===Cr?k=i.DEPTH_COMPONENT24:x===ti?k=i.DEPTH_COMPONENT32F:x===Rr&&(k=i.DEPTH_COMPONENT16),k}function E(T,x){return p(T)===!0||T.isFramebufferTexture&&T.minFilter!==gn&&T.minFilter!==Sn?Math.log2(Math.max(x.width,x.height))+1:T.mipmaps!==void 0&&T.mipmaps.length>0?T.mipmaps.length:T.isCompressedTexture&&Array.isArray(T.image)?x.mipmaps.length:1}function C(T){let x=T.target;x.removeEventListener("dispose",C),w(x),x.isVideoTexture&&h.delete(x),x.isHTMLTexture&&f.delete(x)}function y(T){let x=T.target;x.removeEventListener("dispose",y),N(x)}function w(T){let x=n.get(T);if(x.__webglInit===void 0)return;let k=T.source,X=d.get(k);if(X){let et=X[x.__cacheKey];et.usedTimes--,et.usedTimes===0&&I(T),Object.keys(X).length===0&&d.delete(k)}n.remove(T)}function I(T){let x=n.get(T);i.deleteTexture(x.__webglTexture);let k=T.source,X=d.get(k);delete X[x.__cacheKey],a.memory.textures--}function N(T){let x=n.get(T);if(T.depthTexture&&(T.depthTexture.dispose(),n.remove(T.depthTexture)),T.isWebGLCubeRenderTarget)for(let X=0;X<6;X++){if(Array.isArray(x.__webglFramebuffer[X]))for(let et=0;et<x.__webglFramebuffer[X].length;et++)i.deleteFramebuffer(x.__webglFramebuffer[X][et]);else i.deleteFramebuffer(x.__webglFramebuffer[X]);x.__webglDepthbuffer&&i.deleteRenderbuffer(x.__webglDepthbuffer[X])}else{if(Array.isArray(x.__webglFramebuffer))for(let X=0;X<x.__webglFramebuffer.length;X++)i.deleteFramebuffer(x.__webglFramebuffer[X]);else i.deleteFramebuffer(x.__webglFramebuffer);if(x.__webglDepthbuffer&&i.deleteRenderbuffer(x.__webglDepthbuffer),x.__webglMultisampledFramebuffer&&i.deleteFramebuffer(x.__webglMultisampledFramebuffer),x.__webglColorRenderbuffer)for(let X=0;X<x.__webglColorRenderbuffer.length;X++)x.__webglColorRenderbuffer[X]&&i.deleteRenderbuffer(x.__webglColorRenderbuffer[X]);x.__webglDepthRenderbuffer&&i.deleteRenderbuffer(x.__webglDepthRenderbuffer)}let k=T.textures;for(let X=0,et=k.length;X<et;X++){let bt=n.get(k[X]);bt.__webglTexture&&(i.deleteTexture(bt.__webglTexture),a.memory.textures--),n.remove(k[X])}n.remove(T)}let H=0;function W(){H=0}function U(){return H}function G(T){H=T}function rt(){let T=H;return T>=s.maxTextures&&ue("WebGLTextures: Trying to use "+(T+1)+" texture units while this GPU supports only "+s.maxTextures),H+=1,T}function j(T){let x=[];return x.push(T.wrapS),x.push(T.wrapT),x.push(T.wrapR||0),x.push(T.magFilter),x.push(T.minFilter),x.push(T.anisotropy),x.push(T.internalFormat),x.push(T.format),x.push(T.type),x.push(T.generateMipmaps),x.push(T.premultiplyAlpha),x.push(T.flipY),x.push(T.unpackAlignment),x.push(T.colorSpace),x.join()}function pt(T,x){let k=n.get(T);if(T.isVideoTexture&&L(T),T.isRenderTargetTexture===!1&&T.isExternalTexture!==!0&&T.version>0&&k.__version!==T.version){let X=T.image;if(X===null)ue("WebGLRenderer: Texture marked for update but no image data found.");else if(X.complete===!1)ue("WebGLRenderer: Texture marked for update but image is incomplete");else{ht(k,T,x);return}}else T.isExternalTexture&&(k.__webglTexture=T.sourceTexture?T.sourceTexture:null);e.bindTexture(i.TEXTURE_2D,k.__webglTexture,i.TEXTURE0+x)}function st(T,x){let k=n.get(T);if(T.isRenderTargetTexture===!1&&T.version>0&&k.__version!==T.version){ht(k,T,x);return}else T.isExternalTexture&&(k.__webglTexture=T.sourceTexture?T.sourceTexture:null);e.bindTexture(i.TEXTURE_2D_ARRAY,k.__webglTexture,i.TEXTURE0+x)}function lt(T,x){let k=n.get(T);if(T.isRenderTargetTexture===!1&&T.version>0&&k.__version!==T.version){ht(k,T,x);return}e.bindTexture(i.TEXTURE_3D,k.__webglTexture,i.TEXTURE0+x)}function O(T,x){let k=n.get(T);if(T.isCubeDepthTexture!==!0&&T.version>0&&k.__version!==T.version){wt(k,T,x);return}e.bindTexture(i.TEXTURE_CUBE_MAP,k.__webglTexture,i.TEXTURE0+x)}let vt={[ns]:i.REPEAT,[vi]:i.CLAMP_TO_EDGE,[al]:i.MIRRORED_REPEAT},St={[gn]:i.NEAREST,[Gu]:i.NEAREST_MIPMAP_NEAREST,[to]:i.NEAREST_MIPMAP_LINEAR,[Sn]:i.LINEAR,[Ul]:i.LINEAR_MIPMAP_NEAREST,[Ti]:i.LINEAR_MIPMAP_LINEAR},Et={[Yu]:i.NEVER,[ju]:i.ALWAYS,[$u]:i.LESS,[yc]:i.LEQUAL,[Zu]:i.EQUAL,[Mc]:i.GEQUAL,[Ju]:i.GREATER,[Ku]:i.NOTEQUAL};function Xt(T,x){if(x.type===ti&&t.has("OES_texture_float_linear")===!1&&(x.magFilter===Sn||x.magFilter===Ul||x.magFilter===to||x.magFilter===Ti||x.minFilter===Sn||x.minFilter===Ul||x.minFilter===to||x.minFilter===Ti)&&ue("WebGLRenderer: Unable to use linear filtering with floating point textures. OES_texture_float_linear not supported on this device."),i.texParameteri(T,i.TEXTURE_WRAP_S,vt[x.wrapS]),i.texParameteri(T,i.TEXTURE_WRAP_T,vt[x.wrapT]),(T===i.TEXTURE_3D||T===i.TEXTURE_2D_ARRAY)&&i.texParameteri(T,i.TEXTURE_WRAP_R,vt[x.wrapR]),i.texParameteri(T,i.TEXTURE_MAG_FILTER,St[x.magFilter]),i.texParameteri(T,i.TEXTURE_MIN_FILTER,St[x.minFilter]),x.compareFunction&&(i.texParameteri(T,i.TEXTURE_COMPARE_MODE,i.COMPARE_REF_TO_TEXTURE),i.texParameteri(T,i.TEXTURE_COMPARE_FUNC,Et[x.compareFunction])),t.has("EXT_texture_filter_anisotropic")===!0){if(x.magFilter===gn||x.minFilter!==to&&x.minFilter!==Ti||x.type===ti&&t.has("OES_texture_float_linear")===!1)return;if(x.anisotropy>1||n.get(x).__currentAnisotropy){let k=t.get("EXT_texture_filter_anisotropic");i.texParameterf(T,k.TEXTURE_MAX_ANISOTROPY_EXT,Math.min(x.anisotropy,s.getMaxAnisotropy())),n.get(x).__currentAnisotropy=x.anisotropy}}}function gt(T,x){let k=!1;T.__webglInit===void 0&&(T.__webglInit=!0,x.addEventListener("dispose",C));let X=x.source,et=d.get(X);et===void 0&&(et={},d.set(X,et));let bt=j(x);if(bt!==T.__cacheKey){et[bt]===void 0&&(et[bt]={texture:i.createTexture(),usedTimes:0},a.memory.textures++,k=!0),et[bt].usedTimes++;let Rt=et[T.__cacheKey];Rt!==void 0&&(et[T.__cacheKey].usedTimes--,Rt.usedTimes===0&&I(x)),T.__cacheKey=bt,T.__webglTexture=et[bt].texture}return k}function J(T,x,k){return Math.floor(Math.floor(T/k)/x)}function q(T,x,k,X){let bt=T.updateRanges;if(bt.length===0)e.texSubImage2D(i.TEXTURE_2D,0,0,0,x.width,x.height,k,X,x.data);else{bt.sort((Qt,Ut)=>Qt.start-Ut.start);let Rt=0;for(let Qt=1;Qt<bt.length;Qt++){let Ut=bt[Rt],At=bt[Qt],Lt=Ut.start+Ut.count,ee=J(At.start,x.width,4),fe=J(Ut.start,x.width,4);At.start<=Lt+1&&ee===fe&&J(At.start+At.count-1,x.width,4)===ee?Ut.count=Math.max(Ut.count,At.start+At.count-Ut.start):(++Rt,bt[Rt]=At)}bt.length=Rt+1;let it=e.getParameter(i.UNPACK_ROW_LENGTH),ot=e.getParameter(i.UNPACK_SKIP_PIXELS),It=e.getParameter(i.UNPACK_SKIP_ROWS);e.pixelStorei(i.UNPACK_ROW_LENGTH,x.width);for(let Qt=0,Ut=bt.length;Qt<Ut;Qt++){let At=bt[Qt],Lt=Math.floor(At.start/4),ee=Math.ceil(At.count/4),fe=Lt%x.width,F=Math.floor(Lt/x.width),Pt=ee,at=1;e.pixelStorei(i.UNPACK_SKIP_PIXELS,fe),e.pixelStorei(i.UNPACK_SKIP_ROWS,F),e.texSubImage2D(i.TEXTURE_2D,0,fe,F,Pt,at,k,X,x.data)}T.clearUpdateRanges(),e.pixelStorei(i.UNPACK_ROW_LENGTH,it),e.pixelStorei(i.UNPACK_SKIP_PIXELS,ot),e.pixelStorei(i.UNPACK_SKIP_ROWS,It)}}function ht(T,x,k){let X=i.TEXTURE_2D;(x.isDataArrayTexture||x.isCompressedArrayTexture)&&(X=i.TEXTURE_2D_ARRAY),x.isData3DTexture&&(X=i.TEXTURE_3D);let et=gt(T,x),bt=x.source;e.bindTexture(X,T.__webglTexture,i.TEXTURE0+k);let Rt=n.get(bt);if(bt.version!==Rt.__version||et===!0){if(e.activeTexture(i.TEXTURE0+k),(typeof ImageBitmap<"u"&&x.image instanceof ImageBitmap)===!1){let at=Ae.getPrimaries(Ae.workingColorSpace),Dt=x.colorSpace===di?null:Ae.getPrimaries(x.colorSpace),Nt=x.colorSpace===di||at===Dt?i.NONE:i.BROWSER_DEFAULT_WEBGL;e.pixelStorei(i.UNPACK_FLIP_Y_WEBGL,x.flipY),e.pixelStorei(i.UNPACK_PREMULTIPLY_ALPHA_WEBGL,x.premultiplyAlpha),e.pixelStorei(i.UNPACK_COLORSPACE_CONVERSION_WEBGL,Nt)}e.pixelStorei(i.UNPACK_ALIGNMENT,x.unpackAlignment);let ot=m(x.image,!1,s.maxTextureSize);ot=Jt(x,ot);let It=r.convert(x.format,x.colorSpace),Qt=r.convert(x.type),Ut=v(x.internalFormat,It,Qt,x.normalized,x.colorSpace,x.isVideoTexture);Xt(X,x);let At,Lt=x.mipmaps,ee=x.isVideoTexture!==!0,fe=Rt.__version===void 0||et===!0,F=bt.dataReady,Pt=E(x,ot);if(x.isDepthTexture)Ut=b(x.format===ds,x.type),fe&&(ee?e.texStorage2D(i.TEXTURE_2D,1,Ut,ot.width,ot.height):e.texImage2D(i.TEXTURE_2D,0,Ut,ot.width,ot.height,0,It,Qt,null));else if(x.isDataTexture)if(Lt.length>0){ee&&fe&&e.texStorage2D(i.TEXTURE_2D,Pt,Ut,Lt[0].width,Lt[0].height);for(let at=0,Dt=Lt.length;at<Dt;at++)At=Lt[at],ee?F&&e.texSubImage2D(i.TEXTURE_2D,at,0,0,At.width,At.height,It,Qt,At.data):e.texImage2D(i.TEXTURE_2D,at,Ut,At.width,At.height,0,It,Qt,At.data);x.generateMipmaps=!1}else ee?(fe&&e.texStorage2D(i.TEXTURE_2D,Pt,Ut,ot.width,ot.height),F&&q(x,ot,It,Qt)):e.texImage2D(i.TEXTURE_2D,0,Ut,ot.width,ot.height,0,It,Qt,ot.data);else if(x.isCompressedTexture)if(x.isCompressedArrayTexture){ee&&fe&&e.texStorage3D(i.TEXTURE_2D_ARRAY,Pt,Ut,Lt[0].width,Lt[0].height,ot.depth);for(let at=0,Dt=Lt.length;at<Dt;at++)if(At=Lt[at],x.format!==ei)if(It!==null)if(ee){if(F)if(x.layerUpdates.size>0){let Nt=j0(At.width,At.height,x.format,x.type);for(let mt of x.layerUpdates){let ie=At.data.subarray(mt*Nt/At.data.BYTES_PER_ELEMENT,(mt+1)*Nt/At.data.BYTES_PER_ELEMENT);e.compressedTexSubImage3D(i.TEXTURE_2D_ARRAY,at,0,0,mt,At.width,At.height,1,It,ie)}}else e.compressedTexSubImage3D(i.TEXTURE_2D_ARRAY,at,0,0,0,At.width,At.height,ot.depth,It,At.data)}else e.compressedTexImage3D(i.TEXTURE_2D_ARRAY,at,Ut,At.width,At.height,ot.depth,0,At.data,0,0);else ue("WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()");else ee?F&&e.texSubImage3D(i.TEXTURE_2D_ARRAY,at,0,0,0,At.width,At.height,ot.depth,It,Qt,At.data):e.texImage3D(i.TEXTURE_2D_ARRAY,at,Ut,At.width,At.height,ot.depth,0,It,Qt,At.data);x.layerUpdates.size>0&&x.clearLayerUpdates()}else{ee&&fe&&e.texStorage2D(i.TEXTURE_2D,Pt,Ut,Lt[0].width,Lt[0].height);for(let at=0,Dt=Lt.length;at<Dt;at++)At=Lt[at],x.format!==ei?It!==null?ee?F&&e.compressedTexSubImage2D(i.TEXTURE_2D,at,0,0,At.width,At.height,It,At.data):e.compressedTexImage2D(i.TEXTURE_2D,at,Ut,At.width,At.height,0,At.data):ue("WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()"):ee?F&&e.texSubImage2D(i.TEXTURE_2D,at,0,0,At.width,At.height,It,Qt,At.data):e.texImage2D(i.TEXTURE_2D,at,Ut,At.width,At.height,0,It,Qt,At.data)}else if(x.isDataArrayTexture)if(ee){if(fe&&e.texStorage3D(i.TEXTURE_2D_ARRAY,Pt,Ut,ot.width,ot.height,ot.depth),F)if(x.layerUpdates.size>0){let at=j0(ot.width,ot.height,x.format,x.type);for(let Dt of x.layerUpdates){let Nt=ot.data.subarray(Dt*at/ot.data.BYTES_PER_ELEMENT,(Dt+1)*at/ot.data.BYTES_PER_ELEMENT);e.texSubImage3D(i.TEXTURE_2D_ARRAY,0,0,0,Dt,ot.width,ot.height,1,It,Qt,Nt)}x.clearLayerUpdates()}else e.texSubImage3D(i.TEXTURE_2D_ARRAY,0,0,0,0,ot.width,ot.height,ot.depth,It,Qt,ot.data)}else e.texImage3D(i.TEXTURE_2D_ARRAY,0,Ut,ot.width,ot.height,ot.depth,0,It,Qt,ot.data);else if(x.isData3DTexture)ee?(fe&&e.texStorage3D(i.TEXTURE_3D,Pt,Ut,ot.width,ot.height,ot.depth),F&&e.texSubImage3D(i.TEXTURE_3D,0,0,0,0,ot.width,ot.height,ot.depth,It,Qt,ot.data)):e.texImage3D(i.TEXTURE_3D,0,Ut,ot.width,ot.height,ot.depth,0,It,Qt,ot.data);else if(x.isFramebufferTexture){if(fe)if(ee)e.texStorage2D(i.TEXTURE_2D,Pt,Ut,ot.width,ot.height);else{let at=ot.width,Dt=ot.height;for(let Nt=0;Nt<Pt;Nt++)e.texImage2D(i.TEXTURE_2D,Nt,Ut,at,Dt,0,It,Qt,null),at>>=1,Dt>>=1}}else if(x.isHTMLTexture){if("texElementImage2D"in i){let at=i.canvas;if(at.hasAttribute("layoutsubtree")||at.setAttribute("layoutsubtree","true"),ot.parentNode!==at){at.appendChild(ot),f.add(x),at.onpaint=Dt=>{let Nt=Dt.changedElements;for(let mt of f)Nt.includes(mt.image)&&(mt.needsUpdate=!0)},at.requestPaint();return}if(i.texElementImage2D.length===3)i.texElementImage2D(i.TEXTURE_2D,i.RGBA8,ot);else{let Nt=i.RGBA,mt=i.RGBA,ie=i.UNSIGNED_BYTE;i.texElementImage2D(i.TEXTURE_2D,0,Nt,mt,ie,ot)}i.texParameteri(i.TEXTURE_2D,i.TEXTURE_MIN_FILTER,i.LINEAR),i.texParameteri(i.TEXTURE_2D,i.TEXTURE_WRAP_S,i.CLAMP_TO_EDGE),i.texParameteri(i.TEXTURE_2D,i.TEXTURE_WRAP_T,i.CLAMP_TO_EDGE)}}else if(Lt.length>0){if(ee&&fe){let at=oe(Lt[0]);e.texStorage2D(i.TEXTURE_2D,Pt,Ut,at.width,at.height)}for(let at=0,Dt=Lt.length;at<Dt;at++)At=Lt[at],ee?F&&e.texSubImage2D(i.TEXTURE_2D,at,0,0,It,Qt,At):e.texImage2D(i.TEXTURE_2D,at,Ut,It,Qt,At);x.generateMipmaps=!1}else if(ee){if(fe){let at=oe(ot);e.texStorage2D(i.TEXTURE_2D,Pt,Ut,at.width,at.height)}F&&e.texSubImage2D(i.TEXTURE_2D,0,0,0,It,Qt,ot)}else e.texImage2D(i.TEXTURE_2D,0,Ut,It,Qt,ot);p(x)&&S(X),Rt.__version=bt.version,x.onUpdate&&x.onUpdate(x)}T.__version=x.version}function wt(T,x,k){if(x.image.length!==6)return;let X=gt(T,x),et=x.source;e.bindTexture(i.TEXTURE_CUBE_MAP,T.__webglTexture,i.TEXTURE0+k);let bt=n.get(et);if(et.version!==bt.__version||X===!0){e.activeTexture(i.TEXTURE0+k);let Rt=Ae.getPrimaries(Ae.workingColorSpace),it=x.colorSpace===di?null:Ae.getPrimaries(x.colorSpace),ot=x.colorSpace===di||Rt===it?i.NONE:i.BROWSER_DEFAULT_WEBGL;e.pixelStorei(i.UNPACK_FLIP_Y_WEBGL,x.flipY),e.pixelStorei(i.UNPACK_PREMULTIPLY_ALPHA_WEBGL,x.premultiplyAlpha),e.pixelStorei(i.UNPACK_ALIGNMENT,x.unpackAlignment),e.pixelStorei(i.UNPACK_COLORSPACE_CONVERSION_WEBGL,ot);let It=x.isCompressedTexture||x.image[0].isCompressedTexture,Qt=x.image[0]&&x.image[0].isDataTexture,Ut=[];for(let mt=0;mt<6;mt++)!It&&!Qt?Ut[mt]=m(x.image[mt],!0,s.maxCubemapSize):Ut[mt]=Qt?x.image[mt].image:x.image[mt],Ut[mt]=Jt(x,Ut[mt]);let At=Ut[0],Lt=r.convert(x.format,x.colorSpace),ee=r.convert(x.type),fe=v(x.internalFormat,Lt,ee,x.normalized,x.colorSpace),F=x.isVideoTexture!==!0,Pt=bt.__version===void 0||X===!0,at=et.dataReady,Dt=E(x,At);Xt(i.TEXTURE_CUBE_MAP,x);let Nt;if(It){F&&Pt&&e.texStorage2D(i.TEXTURE_CUBE_MAP,Dt,fe,At.width,At.height);for(let mt=0;mt<6;mt++){Nt=Ut[mt].mipmaps;for(let ie=0;ie<Nt.length;ie++){let qt=Nt[ie];x.format!==ei?Lt!==null?F?at&&e.compressedTexSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+mt,ie,0,0,qt.width,qt.height,Lt,qt.data):e.compressedTexImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+mt,ie,fe,qt.width,qt.height,0,qt.data):ue("WebGLRenderer: Attempt to load unsupported compressed texture format in .setTextureCube()"):F?at&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+mt,ie,0,0,qt.width,qt.height,Lt,ee,qt.data):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+mt,ie,fe,qt.width,qt.height,0,Lt,ee,qt.data)}}}else{if(Nt=x.mipmaps,F&&Pt){Nt.length>0&&Dt++;let mt=oe(Ut[0]);e.texStorage2D(i.TEXTURE_CUBE_MAP,Dt,fe,mt.width,mt.height)}for(let mt=0;mt<6;mt++)if(Qt){F?at&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+mt,0,0,0,Ut[mt].width,Ut[mt].height,Lt,ee,Ut[mt].data):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+mt,0,fe,Ut[mt].width,Ut[mt].height,0,Lt,ee,Ut[mt].data);for(let ie=0;ie<Nt.length;ie++){let Oe=Nt[ie].image[mt].image;F?at&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+mt,ie+1,0,0,Oe.width,Oe.height,Lt,ee,Oe.data):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+mt,ie+1,fe,Oe.width,Oe.height,0,Lt,ee,Oe.data)}}else{F?at&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+mt,0,0,0,Lt,ee,Ut[mt]):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+mt,0,fe,Lt,ee,Ut[mt]);for(let ie=0;ie<Nt.length;ie++){let qt=Nt[ie];F?at&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+mt,ie+1,0,0,Lt,ee,qt.image[mt]):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+mt,ie+1,fe,Lt,ee,qt.image[mt])}}}p(x)&&S(i.TEXTURE_CUBE_MAP),bt.__version=et.version,x.onUpdate&&x.onUpdate(x)}T.__version=x.version}function ct(T,x,k,X,et,bt){let Rt=r.convert(k.format,k.colorSpace),it=r.convert(k.type),ot=v(k.internalFormat,Rt,it,k.normalized,k.colorSpace),It=n.get(x),Qt=n.get(k);if(Qt.__renderTarget=x,!It.__hasExternalTextures){let Ut=Math.max(1,x.width>>bt),At=Math.max(1,x.height>>bt);et===i.TEXTURE_3D||et===i.TEXTURE_2D_ARRAY?e.texImage3D(et,bt,ot,Ut,At,x.depth,0,Rt,it,null):e.texImage2D(et,bt,ot,Ut,At,0,Rt,it,null)}e.bindFramebuffer(i.FRAMEBUFFER,T),ne(x)?o.framebufferTexture2DMultisampleEXT(i.FRAMEBUFFER,X,et,Qt.__webglTexture,0,Zt(x)):(et===i.TEXTURE_2D||et>=i.TEXTURE_CUBE_MAP_POSITIVE_X&&et<=i.TEXTURE_CUBE_MAP_NEGATIVE_Z)&&i.framebufferTexture2D(i.FRAMEBUFFER,X,et,Qt.__webglTexture,bt),e.bindFramebuffer(i.FRAMEBUFFER,null)}function Ft(T,x,k){if(i.bindRenderbuffer(i.RENDERBUFFER,T),x.depthBuffer){let X=x.depthTexture,et=X&&X.isDepthTexture?X.type:null,bt=b(x.stencilBuffer,et),Rt=x.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT;ne(x)?o.renderbufferStorageMultisampleEXT(i.RENDERBUFFER,Zt(x),bt,x.width,x.height):k?i.renderbufferStorageMultisample(i.RENDERBUFFER,Zt(x),bt,x.width,x.height):i.renderbufferStorage(i.RENDERBUFFER,bt,x.width,x.height),i.framebufferRenderbuffer(i.FRAMEBUFFER,Rt,i.RENDERBUFFER,T)}else{let X=x.textures;for(let et=0;et<X.length;et++){let bt=X[et],Rt=r.convert(bt.format,bt.colorSpace),it=r.convert(bt.type),ot=v(bt.internalFormat,Rt,it,bt.normalized,bt.colorSpace);ne(x)?o.renderbufferStorageMultisampleEXT(i.RENDERBUFFER,Zt(x),ot,x.width,x.height):k?i.renderbufferStorageMultisample(i.RENDERBUFFER,Zt(x),ot,x.width,x.height):i.renderbufferStorage(i.RENDERBUFFER,ot,x.width,x.height)}}i.bindRenderbuffer(i.RENDERBUFFER,null)}function ae(T,x,k){let X=x.isWebGLCubeRenderTarget===!0;if(e.bindFramebuffer(i.FRAMEBUFFER,T),!(x.depthTexture&&x.depthTexture.isDepthTexture))throw new Error("THREE.WebGLTextures: renderTarget.depthTexture must be an instance of THREE.DepthTexture.");let et=n.get(x.depthTexture);if(et.__renderTarget=x,(!et.__webglTexture||x.depthTexture.image.width!==x.width||x.depthTexture.image.height!==x.height)&&(x.depthTexture.image.width=x.width,x.depthTexture.image.height=x.height,x.depthTexture.needsUpdate=!0),X){if(et.__webglInit===void 0&&(et.__webglInit=!0,x.depthTexture.addEventListener("dispose",C)),et.__webglTexture===void 0){et.__webglTexture=i.createTexture(),e.bindTexture(i.TEXTURE_CUBE_MAP,et.__webglTexture),Xt(i.TEXTURE_CUBE_MAP,x.depthTexture);let It=r.convert(x.depthTexture.format),Qt=r.convert(x.depthTexture.type),Ut;x.depthTexture.format===Mi?Ut=i.DEPTH_COMPONENT24:x.depthTexture.format===ds&&(Ut=i.DEPTH24_STENCIL8);for(let At=0;At<6;At++)i.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+At,0,Ut,x.width,x.height,0,It,Qt,null)}}else pt(x.depthTexture,0);let bt=et.__webglTexture,Rt=Zt(x),it=X?i.TEXTURE_CUBE_MAP_POSITIVE_X+k:i.TEXTURE_2D,ot=x.depthTexture.format===ds?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT;if(x.depthTexture.format===Mi)ne(x)?o.framebufferTexture2DMultisampleEXT(i.FRAMEBUFFER,ot,it,bt,0,Rt):i.framebufferTexture2D(i.FRAMEBUFFER,ot,it,bt,0);else if(x.depthTexture.format===ds)ne(x)?o.framebufferTexture2DMultisampleEXT(i.FRAMEBUFFER,ot,it,bt,0,Rt):i.framebufferTexture2D(i.FRAMEBUFFER,ot,it,bt,0);else throw new Error("THREE.WebGLTextures: Unknown depthTexture format.")}function K(T){let x=n.get(T),k=T.isWebGLCubeRenderTarget===!0;if(x.__boundDepthTexture!==T.depthTexture){let X=T.depthTexture;if(x.__depthDisposeCallback&&x.__depthDisposeCallback(),X){let et=()=>{delete x.__boundDepthTexture,delete x.__depthDisposeCallback,X.removeEventListener("dispose",et)};X.addEventListener("dispose",et),x.__depthDisposeCallback=et}x.__boundDepthTexture=X}if(T.depthTexture&&!x.__autoAllocateDepthBuffer)if(k)for(let X=0;X<6;X++)ae(x.__webglFramebuffer[X],T,X);else{let X=T.texture.mipmaps;X&&X.length>0?ae(x.__webglFramebuffer[0],T,0):ae(x.__webglFramebuffer,T,0)}else if(k){x.__webglDepthbuffer=[];for(let X=0;X<6;X++)if(e.bindFramebuffer(i.FRAMEBUFFER,x.__webglFramebuffer[X]),x.__webglDepthbuffer[X]===void 0)x.__webglDepthbuffer[X]=i.createRenderbuffer(),Ft(x.__webglDepthbuffer[X],T,!1);else{let et=T.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT,bt=x.__webglDepthbuffer[X];i.bindRenderbuffer(i.RENDERBUFFER,bt),i.framebufferRenderbuffer(i.FRAMEBUFFER,et,i.RENDERBUFFER,bt)}}else{let X=T.texture.mipmaps;if(X&&X.length>0?e.bindFramebuffer(i.FRAMEBUFFER,x.__webglFramebuffer[0]):e.bindFramebuffer(i.FRAMEBUFFER,x.__webglFramebuffer),x.__webglDepthbuffer===void 0)x.__webglDepthbuffer=i.createRenderbuffer(),Ft(x.__webglDepthbuffer,T,!1);else{let et=T.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT,bt=x.__webglDepthbuffer;i.bindRenderbuffer(i.RENDERBUFFER,bt),i.framebufferRenderbuffer(i.FRAMEBUFFER,et,i.RENDERBUFFER,bt)}}e.bindFramebuffer(i.FRAMEBUFFER,null)}function ut(T,x,k){let X=n.get(T);x!==void 0&&ct(X.__webglFramebuffer,T,T.texture,i.COLOR_ATTACHMENT0,i.TEXTURE_2D,0),k!==void 0&&K(T)}function yt(T){let x=T.texture,k=n.get(T),X=n.get(x);T.addEventListener("dispose",y);let et=T.textures,bt=T.isWebGLCubeRenderTarget===!0,Rt=et.length>1;if(Rt||(X.__webglTexture===void 0&&(X.__webglTexture=i.createTexture()),X.__version=x.version,a.memory.textures++),bt){k.__webglFramebuffer=[];for(let it=0;it<6;it++)if(x.mipmaps&&x.mipmaps.length>0){k.__webglFramebuffer[it]=[];for(let ot=0;ot<x.mipmaps.length;ot++)k.__webglFramebuffer[it][ot]=i.createFramebuffer()}else k.__webglFramebuffer[it]=i.createFramebuffer()}else{if(x.mipmaps&&x.mipmaps.length>0){k.__webglFramebuffer=[];for(let it=0;it<x.mipmaps.length;it++)k.__webglFramebuffer[it]=i.createFramebuffer()}else k.__webglFramebuffer=i.createFramebuffer();if(Rt)for(let it=0,ot=et.length;it<ot;it++){let It=n.get(et[it]);It.__webglTexture===void 0&&(It.__webglTexture=i.createTexture(),a.memory.textures++)}if(T.samples>0&&ne(T)===!1){k.__webglMultisampledFramebuffer=i.createFramebuffer(),k.__webglColorRenderbuffer=[],e.bindFramebuffer(i.FRAMEBUFFER,k.__webglMultisampledFramebuffer);for(let it=0;it<et.length;it++){let ot=et[it];k.__webglColorRenderbuffer[it]=i.createRenderbuffer(),i.bindRenderbuffer(i.RENDERBUFFER,k.__webglColorRenderbuffer[it]);let It=r.convert(ot.format,ot.colorSpace),Qt=r.convert(ot.type),Ut=v(ot.internalFormat,It,Qt,ot.normalized,ot.colorSpace,T.isXRRenderTarget===!0),At=Zt(T);i.renderbufferStorageMultisample(i.RENDERBUFFER,At,Ut,T.width,T.height),i.framebufferRenderbuffer(i.FRAMEBUFFER,i.COLOR_ATTACHMENT0+it,i.RENDERBUFFER,k.__webglColorRenderbuffer[it])}i.bindRenderbuffer(i.RENDERBUFFER,null),T.depthBuffer&&(k.__webglDepthRenderbuffer=i.createRenderbuffer(),Ft(k.__webglDepthRenderbuffer,T,!0)),e.bindFramebuffer(i.FRAMEBUFFER,null)}}if(bt){e.bindTexture(i.TEXTURE_CUBE_MAP,X.__webglTexture),Xt(i.TEXTURE_CUBE_MAP,x);for(let it=0;it<6;it++)if(x.mipmaps&&x.mipmaps.length>0)for(let ot=0;ot<x.mipmaps.length;ot++)ct(k.__webglFramebuffer[it][ot],T,x,i.COLOR_ATTACHMENT0,i.TEXTURE_CUBE_MAP_POSITIVE_X+it,ot);else ct(k.__webglFramebuffer[it],T,x,i.COLOR_ATTACHMENT0,i.TEXTURE_CUBE_MAP_POSITIVE_X+it,0);p(x)&&S(i.TEXTURE_CUBE_MAP),e.unbindTexture()}else if(Rt){for(let it=0,ot=et.length;it<ot;it++){let It=et[it],Qt=n.get(It),Ut=i.TEXTURE_2D;(T.isWebGL3DRenderTarget||T.isWebGLArrayRenderTarget)&&(Ut=T.isWebGL3DRenderTarget?i.TEXTURE_3D:i.TEXTURE_2D_ARRAY),e.bindTexture(Ut,Qt.__webglTexture),Xt(Ut,It),ct(k.__webglFramebuffer,T,It,i.COLOR_ATTACHMENT0+it,Ut,0),p(It)&&S(Ut)}e.unbindTexture()}else{let it=i.TEXTURE_2D;if((T.isWebGL3DRenderTarget||T.isWebGLArrayRenderTarget)&&(it=T.isWebGL3DRenderTarget?i.TEXTURE_3D:i.TEXTURE_2D_ARRAY),e.bindTexture(it,X.__webglTexture),Xt(it,x),x.mipmaps&&x.mipmaps.length>0)for(let ot=0;ot<x.mipmaps.length;ot++)ct(k.__webglFramebuffer[ot],T,x,i.COLOR_ATTACHMENT0,it,ot);else ct(k.__webglFramebuffer,T,x,i.COLOR_ATTACHMENT0,it,0);p(x)&&S(it),e.unbindTexture()}T.depthBuffer&&K(T)}function xt(T){let x=T.textures;for(let k=0,X=x.length;k<X;k++){let et=x[k];if(p(et)){let bt=A(T),Rt=n.get(et).__webglTexture;e.bindTexture(bt,Rt),S(bt),e.unbindTexture()}}}let _t=[],Gt=[];function Bt(T){if(T.samples>0){if(ne(T)===!1){let x=T.textures,k=T.width,X=T.height,et=i.COLOR_BUFFER_BIT,bt=T.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT,Rt=n.get(T),it=x.length>1;if(it)for(let It=0;It<x.length;It++)e.bindFramebuffer(i.FRAMEBUFFER,Rt.__webglMultisampledFramebuffer),i.framebufferRenderbuffer(i.FRAMEBUFFER,i.COLOR_ATTACHMENT0+It,i.RENDERBUFFER,null),e.bindFramebuffer(i.FRAMEBUFFER,Rt.__webglFramebuffer),i.framebufferTexture2D(i.DRAW_FRAMEBUFFER,i.COLOR_ATTACHMENT0+It,i.TEXTURE_2D,null,0);e.bindFramebuffer(i.READ_FRAMEBUFFER,Rt.__webglMultisampledFramebuffer);let ot=T.texture.mipmaps;ot&&ot.length>0?e.bindFramebuffer(i.DRAW_FRAMEBUFFER,Rt.__webglFramebuffer[0]):e.bindFramebuffer(i.DRAW_FRAMEBUFFER,Rt.__webglFramebuffer);for(let It=0;It<x.length;It++){if(T.resolveDepthBuffer&&(T.depthBuffer&&(et|=i.DEPTH_BUFFER_BIT),T.stencilBuffer&&T.resolveStencilBuffer&&(et|=i.STENCIL_BUFFER_BIT)),it){i.framebufferRenderbuffer(i.READ_FRAMEBUFFER,i.COLOR_ATTACHMENT0,i.RENDERBUFFER,Rt.__webglColorRenderbuffer[It]);let Qt=n.get(x[It]).__webglTexture;i.framebufferTexture2D(i.DRAW_FRAMEBUFFER,i.COLOR_ATTACHMENT0,i.TEXTURE_2D,Qt,0)}i.blitFramebuffer(0,0,k,X,0,0,k,X,et,i.NEAREST),l===!0&&(_t.length=0,Gt.length=0,_t.push(i.COLOR_ATTACHMENT0+It),T.depthBuffer&&T.storeMultisampledDepthBuffer===!1&&(_t.push(bt),Gt.push(bt),i.invalidateFramebuffer(i.DRAW_FRAMEBUFFER,Gt)),i.invalidateFramebuffer(i.READ_FRAMEBUFFER,_t))}if(e.bindFramebuffer(i.READ_FRAMEBUFFER,null),e.bindFramebuffer(i.DRAW_FRAMEBUFFER,null),it)for(let It=0;It<x.length;It++){e.bindFramebuffer(i.FRAMEBUFFER,Rt.__webglMultisampledFramebuffer),i.framebufferRenderbuffer(i.FRAMEBUFFER,i.COLOR_ATTACHMENT0+It,i.RENDERBUFFER,Rt.__webglColorRenderbuffer[It]);let Qt=n.get(x[It]).__webglTexture;e.bindFramebuffer(i.FRAMEBUFFER,Rt.__webglFramebuffer),i.framebufferTexture2D(i.DRAW_FRAMEBUFFER,i.COLOR_ATTACHMENT0+It,i.TEXTURE_2D,Qt,0)}e.bindFramebuffer(i.DRAW_FRAMEBUFFER,Rt.__webglMultisampledFramebuffer)}else if(T.depthBuffer&&T.storeMultisampledDepthBuffer===!1&&l){let x=T.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT;i.invalidateFramebuffer(i.DRAW_FRAMEBUFFER,[x])}}}function Zt(T){return Math.min(s.maxSamples,T.samples)}function ne(T){let x=n.get(T);return T.samples>0&&t.has("WEBGL_multisampled_render_to_texture")===!0&&x.__useRenderToTexture!==!1}function L(T){let x=a.render.frame;h.get(T)!==x&&(h.set(T,x),T.update())}function Jt(T,x){let k=T.colorSpace,X=T.format,et=T.type;return T.isCompressedTexture===!0||T.isVideoTexture===!0||k!==la&&k!==di&&(Ae.getTransfer(k)===Fe?(X!==ei||et!==Fn)&&ue("WebGLTextures: sRGB encoded textures have to use RGBAFormat and UnsignedByteType."):he("WebGLTextures: Unsupported texture color space:",k)),x}function oe(T){return typeof HTMLImageElement<"u"&&T instanceof HTMLImageElement?(c.width=T.naturalWidth||T.width,c.height=T.naturalHeight||T.height):typeof VideoFrame<"u"&&T instanceof VideoFrame?(c.width=T.displayWidth,c.height=T.displayHeight):(c.width=T.width,c.height=T.height),c}this.allocateTextureUnit=rt,this.resetTextureUnits=W,this.getTextureUnits=U,this.setTextureUnits=G,this.setTexture2D=pt,this.setTexture2DArray=st,this.setTexture3D=lt,this.setTextureCube=O,this.rebindTextures=ut,this.setupRenderTarget=yt,this.updateRenderTargetMipmap=xt,this.updateMultisampleRenderTarget=Bt,this.setupDepthRenderbuffer=K,this.setupFrameBufferTexture=ct,this.useMultisampledRTT=ne,this.isReversedDepthBuffer=function(){return e.buffers.depth.getReversed()}}function rx(i,t){function e(n,s=di){let r,a=Ae.getTransfer(s);if(n===Fn)return i.UNSIGNED_BYTE;if(n===Ol)return i.UNSIGNED_SHORT_4_4_4_4;if(n===Bl)return i.UNSIGNED_SHORT_5_5_5_1;if(n===V0)return i.UNSIGNED_INT_5_9_9_9_REV;if(n===G0)return i.UNSIGNED_INT_10F_11F_11F_REV;if(n===k0)return i.BYTE;if(n===H0)return i.SHORT;if(n===Rr)return i.UNSIGNED_SHORT;if(n===Fl)return i.INT;if(n===fi)return i.UNSIGNED_INT;if(n===ti)return i.FLOAT;if(n===un)return i.HALF_FLOAT;if(n===W0)return i.ALPHA;if(n===X0)return i.RGB;if(n===ei)return i.RGBA;if(n===Mi)return i.DEPTH_COMPONENT;if(n===ds)return i.DEPTH_STENCIL;if(n===zl)return i.RED;if(n===kl)return i.RED_INTEGER;if(n===ps)return i.RG;if(n===Hl)return i.RG_INTEGER;if(n===Vl)return i.RGBA_INTEGER;if(n===eo||n===no||n===io||n===so)if(a===Fe)if(r=t.get("WEBGL_compressed_texture_s3tc_srgb"),r!==null){if(n===eo)return r.COMPRESSED_SRGB_S3TC_DXT1_EXT;if(n===no)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT;if(n===io)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT;if(n===so)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT}else return null;else if(r=t.get("WEBGL_compressed_texture_s3tc"),r!==null){if(n===eo)return r.COMPRESSED_RGB_S3TC_DXT1_EXT;if(n===no)return r.COMPRESSED_RGBA_S3TC_DXT1_EXT;if(n===io)return r.COMPRESSED_RGBA_S3TC_DXT3_EXT;if(n===so)return r.COMPRESSED_RGBA_S3TC_DXT5_EXT}else return null;if(n===Gl||n===Wl||n===Xl||n===ql)if(r=t.get("WEBGL_compressed_texture_pvrtc"),r!==null){if(n===Gl)return r.COMPRESSED_RGB_PVRTC_4BPPV1_IMG;if(n===Wl)return r.COMPRESSED_RGB_PVRTC_2BPPV1_IMG;if(n===Xl)return r.COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;if(n===ql)return r.COMPRESSED_RGBA_PVRTC_2BPPV1_IMG}else return null;if(n===Yl||n===$l||n===Zl||n===Jl||n===Kl||n===ro||n===jl)if(r=t.get("WEBGL_compressed_texture_etc"),r!==null){if(n===Yl||n===$l)return a===Fe?r.COMPRESSED_SRGB8_ETC2:r.COMPRESSED_RGB8_ETC2;if(n===Zl)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ETC2_EAC:r.COMPRESSED_RGBA8_ETC2_EAC;if(n===Jl)return r.COMPRESSED_R11_EAC;if(n===Kl)return r.COMPRESSED_SIGNED_R11_EAC;if(n===ro)return r.COMPRESSED_RG11_EAC;if(n===jl)return r.COMPRESSED_SIGNED_RG11_EAC}else return null;if(n===Ql||n===tc||n===ec||n===nc||n===ic||n===sc||n===rc||n===ac||n===oc||n===lc||n===cc||n===hc||n===uc||n===fc)if(r=t.get("WEBGL_compressed_texture_astc"),r!==null){if(n===Ql)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR:r.COMPRESSED_RGBA_ASTC_4x4_KHR;if(n===tc)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR:r.COMPRESSED_RGBA_ASTC_5x4_KHR;if(n===ec)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR:r.COMPRESSED_RGBA_ASTC_5x5_KHR;if(n===nc)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR:r.COMPRESSED_RGBA_ASTC_6x5_KHR;if(n===ic)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR:r.COMPRESSED_RGBA_ASTC_6x6_KHR;if(n===sc)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR:r.COMPRESSED_RGBA_ASTC_8x5_KHR;if(n===rc)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR:r.COMPRESSED_RGBA_ASTC_8x6_KHR;if(n===ac)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR:r.COMPRESSED_RGBA_ASTC_8x8_KHR;if(n===oc)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR:r.COMPRESSED_RGBA_ASTC_10x5_KHR;if(n===lc)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR:r.COMPRESSED_RGBA_ASTC_10x6_KHR;if(n===cc)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR:r.COMPRESSED_RGBA_ASTC_10x8_KHR;if(n===hc)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR:r.COMPRESSED_RGBA_ASTC_10x10_KHR;if(n===uc)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR:r.COMPRESSED_RGBA_ASTC_12x10_KHR;if(n===fc)return a===Fe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR:r.COMPRESSED_RGBA_ASTC_12x12_KHR}else return null;if(n===dc||n===pc||n===mc)if(r=t.get("EXT_texture_compression_bptc"),r!==null){if(n===dc)return a===Fe?r.COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT:r.COMPRESSED_RGBA_BPTC_UNORM_EXT;if(n===pc)return r.COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT;if(n===mc)return r.COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT}else return null;if(n===gc||n===xc||n===ao||n===_c)if(r=t.get("EXT_texture_compression_rgtc"),r!==null){if(n===gc)return r.COMPRESSED_RED_RGTC1_EXT;if(n===xc)return r.COMPRESSED_SIGNED_RED_RGTC1_EXT;if(n===ao)return r.COMPRESSED_RED_GREEN_RGTC2_EXT;if(n===_c)return r.COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT}else return null;return n===Cr?i.UNSIGNED_INT_24_8:i[n]!==void 0?i[n]:null}return{convert:e}}var ax=`
void main() {

	gl_Position = vec4( position, 1.0 );

}`,ox=`
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

}`,fh=class{constructor(){this.texture=null,this.mesh=null,this.depthNear=0,this.depthFar=0}init(t,e){if(this.texture===null){let n=new Ma(t.texture);(t.depthNear!==e.depthNear||t.depthFar!==e.depthFar)&&(this.depthNear=t.depthNear,this.depthFar=t.depthFar),this.texture=n}}getMesh(t){if(this.texture!==null&&this.mesh===null){let e=t.cameras[0].viewport,n=new He({vertexShader:ax,fragmentShader:ox,uniforms:{depthColor:{value:this.texture},depthWidth:{value:e.z},depthHeight:{value:e.w}}});this.mesh=new Se(new rs(20,20),n)}return this.mesh}reset(){this.texture=null,this.mesh=null}getDepthTexture(){return this.texture}},dh=class extends Si{constructor(t,e){super();let n=this,s=null,r=1,a=null,o="local-floor",l=1,c=null,h=null,f=null,u=null,d=null,g=null,_=typeof XRWebGLBinding<"u",m=new fh,p={},S=e.getContextAttributes(),A=null,v=null,b=[],E=[],C=new ft,y=null,w=null,I=new Mn;I.viewport=new $e;let N=new Mn;N.viewport=new $e;let H=[I,N],W=new Dl,U=null,G=null;this.cameraAutoUpdate=!0,this.enabled=!1,this.isPresenting=!1,this.getController=function(J){let q=b[J];return q===void 0&&(q=new ur,b[J]=q),q.getTargetRaySpace()},this.getControllerGrip=function(J){let q=b[J];return q===void 0&&(q=new ur,b[J]=q),q.getGripSpace()},this.getHand=function(J){let q=b[J];return q===void 0&&(q=new ur,b[J]=q),q.getHandSpace()};function rt(J){let q=E.indexOf(J.inputSource);if(q===-1)return;let ht=b[q];ht!==void 0&&(ht.update(J.inputSource,J.frame,c||a),ht.dispatchEvent({type:J.type,data:J.inputSource}))}function j(){s.removeEventListener("select",rt),s.removeEventListener("selectstart",rt),s.removeEventListener("selectend",rt),s.removeEventListener("squeeze",rt),s.removeEventListener("squeezestart",rt),s.removeEventListener("squeezeend",rt),s.removeEventListener("end",j),s.removeEventListener("inputsourceschange",pt);for(let J=0;J<b.length;J++){let q=E[J];q!==null&&(E[J]=null,b[J].disconnect(q))}U=null,G=null,m.reset();for(let J in p)delete p[J];if(t.setRenderTarget(A),d=null,u=null,f=null,s=null,v=null,gt.stop(),n.isPresenting=!1,t.setPixelRatio(y),t.setSize(C.width,C.height,!1),w!==null){let J=w.camera;J.fov=w.fov,J.zoom=w.zoom,J.updateProjectionMatrix(),w=null}n.dispatchEvent({type:"sessionend"})}this.setFramebufferScaleFactor=function(J){r=J,n.isPresenting===!0&&ue("WebXRManager: Cannot change framebuffer scale while presenting.")},this.setReferenceSpaceType=function(J){o=J,n.isPresenting===!0&&ue("WebXRManager: Cannot change reference space type while presenting.")},this.getReferenceSpace=function(){return c||a},this.setReferenceSpace=function(J){c=J},this.getBaseLayer=function(){return u!==null?u:d},this.getBinding=function(){return f===null&&_&&(f=new XRWebGLBinding(s,e)),f},this.getFrame=function(){return g},this.getSession=function(){return s},this.setSession=async function(J){if(s=J,s!==null){if(A=t.getRenderTarget(),s.addEventListener("select",rt),s.addEventListener("selectstart",rt),s.addEventListener("selectend",rt),s.addEventListener("squeeze",rt),s.addEventListener("squeezestart",rt),s.addEventListener("squeezeend",rt),s.addEventListener("end",j),s.addEventListener("inputsourceschange",pt),S.xrCompatible!==!0&&await e.makeXRCompatible(),y=t.getPixelRatio(),t.getSize(C),_&&"createProjectionLayer"in XRWebGLBinding.prototype){let ht=null,wt=null,ct=null;S.depth&&(ct=S.stencil?e.DEPTH24_STENCIL8:e.DEPTH_COMPONENT24,ht=S.stencil?ds:Mi,wt=S.stencil?Cr:fi);let Ft={colorFormat:e.RGBA8,depthFormat:ct,scaleFactor:r};f=this.getBinding(),u=f.createProjectionLayer(Ft),s.updateRenderState({layers:[u]}),t.setPixelRatio(1),t.setSize(u.textureWidth,u.textureHeight,!1),v=new tn(u.textureWidth,u.textureHeight,{format:ei,type:Fn,depthTexture:new ss(u.textureWidth,u.textureHeight,wt,void 0,void 0,void 0,void 0,void 0,void 0,ht),stencilBuffer:S.stencil,colorSpace:t.outputColorSpace,samples:S.antialias?4:0,resolveDepthBuffer:u.ignoreDepthValues===!1,resolveStencilBuffer:u.ignoreDepthValues===!1,storeMultisampledDepthBuffer:u.ignoreDepthValues===!1,storeMultisampledStencilBuffer:u.ignoreDepthValues===!1})}else{let ht={antialias:S.antialias,alpha:!0,depth:S.depth,stencil:S.stencil,framebufferScaleFactor:r};d=new XRWebGLLayer(s,e,ht),s.updateRenderState({baseLayer:d}),t.setPixelRatio(1),t.setSize(d.framebufferWidth,d.framebufferHeight,!1),v=new tn(d.framebufferWidth,d.framebufferHeight,{format:ei,type:Fn,colorSpace:t.outputColorSpace,stencilBuffer:S.stencil,resolveDepthBuffer:d.ignoreDepthValues===!1,resolveStencilBuffer:d.ignoreDepthValues===!1,storeMultisampledDepthBuffer:d.ignoreDepthValues===!1,storeMultisampledStencilBuffer:d.ignoreDepthValues===!1})}v.isXRRenderTarget=!0,this.setFoveation(l),c=null,a=await s.requestReferenceSpace(o),gt.setContext(s),gt.start(),n.isPresenting=!0,n.dispatchEvent({type:"sessionstart"})}},this.getEnvironmentBlendMode=function(){if(s!==null)return s.environmentBlendMode},this.getDepthTexture=function(){return m.getDepthTexture()};function pt(J){for(let q=0;q<J.removed.length;q++){let ht=J.removed[q],wt=E.indexOf(ht);wt>=0&&(E[wt]=null,b[wt].disconnect(ht))}for(let q=0;q<J.added.length;q++){let ht=J.added[q],wt=E.indexOf(ht);if(wt===-1){for(let Ft=0;Ft<b.length;Ft++)if(Ft>=E.length){E.push(ht),wt=Ft;break}else if(E[Ft]===null){E[Ft]=ht,wt=Ft;break}if(wt===-1)break}let ct=b[wt];ct&&ct.connect(ht)}}let st=new P,lt=new P;function O(J,q,ht){st.setFromMatrixPosition(q.matrixWorld),lt.setFromMatrixPosition(ht.matrixWorld);let wt=st.distanceTo(lt),ct=q.projectionMatrix.elements,Ft=ht.projectionMatrix.elements,ae=ct[14]/(ct[10]-1),K=ct[14]/(ct[10]+1),ut=(ct[9]+1)/ct[5],yt=(ct[9]-1)/ct[5],xt=(ct[8]-1)/ct[0],_t=(Ft[8]+1)/Ft[0],Gt=ae*xt,Bt=ae*_t,Zt=wt/(-xt+_t),ne=Zt*-xt;if(q.matrixWorld.decompose(J.position,J.quaternion,J.scale),J.translateX(ne),J.translateZ(Zt),J.matrixWorld.compose(J.position,J.quaternion,J.scale),J.matrixWorldInverse.copy(J.matrixWorld).invert(),ct[10]===-1)J.projectionMatrix.copy(q.projectionMatrix),J.projectionMatrixInverse.copy(q.projectionMatrixInverse);else{let L=ae+Zt,Jt=K+Zt,oe=Gt-ne,T=Bt+(wt-ne),x=ut*K/Jt*L,k=yt*K/Jt*L;J.projectionMatrix.makePerspective(oe,T,x,k,L,Jt),J.projectionMatrixInverse.copy(J.projectionMatrix).invert()}}function vt(J,q){q===null?J.matrixWorld.copy(J.matrix):J.matrixWorld.multiplyMatrices(q.matrixWorld,J.matrix),J.matrixWorldInverse.copy(J.matrixWorld).invert()}this.updateCamera=function(J){if(s===null)return;let q=J.near,ht=J.far;m.texture!==null&&(m.depthNear>0&&(q=m.depthNear),m.depthFar>0&&(ht=m.depthFar)),W.near=N.near=I.near=q,W.far=N.far=I.far=ht,(U!==W.near||G!==W.far)&&(s.updateRenderState({depthNear:W.near,depthFar:W.far}),U=W.near,G=W.far),W.layers.mask=J.layers.mask|6,I.layers.mask=W.layers.mask&-5,N.layers.mask=W.layers.mask&-3;let wt=J.parent,ct=W.cameras;vt(W,wt);for(let Ft=0;Ft<ct.length;Ft++)vt(ct[Ft],wt);ct.length===2?O(W,I,N):W.projectionMatrix.copy(I.projectionMatrix),w===null&&J.isPerspectiveCamera&&(w={camera:J,fov:J.fov,zoom:J.zoom}),St(J,W,wt)};function St(J,q,ht){ht===null?J.matrix.copy(q.matrixWorld):(J.matrix.copy(ht.matrixWorld),J.matrix.invert(),J.matrix.multiply(q.matrixWorld)),J.matrix.decompose(J.position,J.quaternion,J.scale),J.updateMatrixWorld(!0),J.projectionMatrix.copy(q.projectionMatrix),J.projectionMatrixInverse.copy(q.projectionMatrixInverse),J.isPerspectiveCamera&&(J.fov=ll*2*Math.atan(1/J.projectionMatrix.elements[5]),J.zoom=1)}this.getCamera=function(){return W},this.getFoveation=function(){if(!(u===null&&d===null))return l},this.setFoveation=function(J){l=J,u!==null&&(u.fixedFoveation=J),d!==null&&d.fixedFoveation!==void 0&&(d.fixedFoveation=J)},this.hasDepthSensing=function(){return m.texture!==null},this.getDepthSensingMesh=function(){return m.getMesh(W)},this.getCameraTexture=function(J){return p[J]};let Et=null;function Xt(J,q){if(h=q.getViewerPose(c||a),g=q,h!==null){let ht=h.views;d!==null&&(t.setRenderTargetFramebuffer(v,d.framebuffer),t.setRenderTarget(v));let wt=!1;ht.length!==W.cameras.length&&(W.cameras.length=0,wt=!0);for(let K=0;K<ht.length;K++){let ut=ht[K],yt=null;if(d!==null)yt=d.getViewport(ut);else{let _t=f.getViewSubImage(u,ut);yt=_t.viewport,K===0&&(t.setRenderTargetTextures(v,_t.colorTexture,_t.depthStencilTexture),t.setRenderTarget(v))}let xt=H[K];xt===void 0&&(xt=new Mn,xt.layers.enable(K),xt.viewport=new $e,H[K]=xt),xt.matrix.fromArray(ut.transform.matrix),xt.matrix.decompose(xt.position,xt.quaternion,xt.scale),xt.projectionMatrix.fromArray(ut.projectionMatrix),xt.projectionMatrixInverse.copy(xt.projectionMatrix).invert(),xt.viewport.set(yt.x,yt.y,yt.width,yt.height),K===0&&(W.matrix.copy(xt.matrix),W.matrix.decompose(W.position,W.quaternion,W.scale)),wt===!0&&W.cameras.push(xt)}let ct=s.enabledFeatures;if(ct&&ct.includes("depth-sensing")&&s.depthUsage=="gpu-optimized"&&_){f=n.getBinding();let K=f.getDepthInformation(ht[0]);K&&K.isValid&&K.texture&&m.init(K,s.renderState)}if(ct&&ct.includes("camera-access")&&_){t.state.unbindTexture(),f=n.getBinding();for(let K=0;K<ht.length;K++){let ut=ht[K].camera;if(ut){let yt=p[ut];yt||(yt=new Ma,p[ut]=yt);let xt=f.getCameraImage(ut);yt.sourceTexture=xt}}}}for(let ht=0;ht<b.length;ht++){let wt=E[ht],ct=b[ht];wt!==null&&ct!==void 0&&ct.update(wt,q,c||a)}Et&&Et(J,q),q.detectedPlanes&&n.dispatchEvent({type:"planesdetected",data:q}),g=null}let gt=new Df;gt.setAnimationLoop(Xt),this.setAnimationLoop=function(J){Et=J},this.dispose=function(){}}},lx=new De,zf=new xe;zf.set(-1,0,0,0,1,0,0,0,1);function cx(i,t){function e(m,p){m.matrixAutoUpdate===!0&&m.updateMatrix(),p.value.copy(m.matrix)}function n(m,p){p.color.getRGB(m.fogColor.value,Z0(i)),p.isFog?(m.fogNear.value=p.near,m.fogFar.value=p.far):p.isFogExp2&&(m.fogDensity.value=p.density)}function s(m,p,S,A,v){p.isNodeMaterial?p.uniformsNeedUpdate=!1:p.isMeshBasicMaterial?r(m,p):p.isMeshLambertMaterial?(r(m,p),p.envMap&&(m.envMapIntensity.value=p.envMapIntensity)):p.isMeshToonMaterial?(r(m,p),f(m,p)):p.isMeshPhongMaterial?(r(m,p),h(m,p),p.envMap&&(m.envMapIntensity.value=p.envMapIntensity)):p.isMeshStandardMaterial?(r(m,p),u(m,p),p.isMeshPhysicalMaterial&&d(m,p,v)):p.isMeshMatcapMaterial?(r(m,p),g(m,p)):p.isMeshDepthMaterial?r(m,p):p.isMeshDistanceMaterial?(r(m,p),_(m,p)):p.isMeshNormalMaterial?r(m,p):p.isLineBasicMaterial?(a(m,p),p.isLineDashedMaterial&&o(m,p)):p.isPointsMaterial?l(m,p,S,A):p.isSpriteMaterial?c(m,p):p.isShadowMaterial?(m.color.value.copy(p.color),m.opacity.value=p.opacity):p.isShaderMaterial&&(p.uniformsNeedUpdate=!1)}function r(m,p){m.opacity.value=p.opacity,p.color&&m.diffuse.value.copy(p.color),p.emissive&&m.emissive.value.copy(p.emissive).multiplyScalar(p.emissiveIntensity),p.map&&(m.map.value=p.map,e(p.map,m.mapTransform)),p.alphaMap&&(m.alphaMap.value=p.alphaMap,e(p.alphaMap,m.alphaMapTransform)),p.bumpMap&&(m.bumpMap.value=p.bumpMap,e(p.bumpMap,m.bumpMapTransform),m.bumpScale.value=p.bumpScale,p.side===bn&&(m.bumpScale.value*=-1)),p.normalMap&&(m.normalMap.value=p.normalMap,e(p.normalMap,m.normalMapTransform),m.normalScale.value.copy(p.normalScale),p.side===bn&&m.normalScale.value.negate()),p.displacementMap&&(m.displacementMap.value=p.displacementMap,e(p.displacementMap,m.displacementMapTransform),m.displacementScale.value=p.displacementScale,m.displacementBias.value=p.displacementBias),p.emissiveMap&&(m.emissiveMap.value=p.emissiveMap,e(p.emissiveMap,m.emissiveMapTransform)),p.specularMap&&(m.specularMap.value=p.specularMap,e(p.specularMap,m.specularMapTransform)),p.alphaTest>0&&(m.alphaTest.value=p.alphaTest);let S=t.get(p),A=S.envMap,v=S.envMapRotation;A&&(m.envMap.value=A,m.envMapRotation.value.setFromMatrix4(lx.makeRotationFromEuler(v)).transpose(),A.isCubeTexture&&A.isRenderTargetTexture===!1&&m.envMapRotation.value.premultiply(zf),m.reflectivity.value=p.reflectivity,m.ior.value=p.ior,m.refractionRatio.value=p.refractionRatio),p.lightMap&&(m.lightMap.value=p.lightMap,m.lightMapIntensity.value=p.lightMapIntensity,e(p.lightMap,m.lightMapTransform)),p.aoMap&&(m.aoMap.value=p.aoMap,m.aoMapIntensity.value=p.aoMapIntensity,e(p.aoMap,m.aoMapTransform))}function a(m,p){m.diffuse.value.copy(p.color),m.opacity.value=p.opacity,p.map&&(m.map.value=p.map,e(p.map,m.mapTransform))}function o(m,p){m.dashSize.value=p.dashSize,m.totalSize.value=p.dashSize+p.gapSize,m.scale.value=p.scale}function l(m,p,S,A){m.diffuse.value.copy(p.color),m.opacity.value=p.opacity,m.size.value=p.size*S,m.scale.value=A*.5,p.map&&(m.map.value=p.map,e(p.map,m.uvTransform)),p.alphaMap&&(m.alphaMap.value=p.alphaMap,e(p.alphaMap,m.alphaMapTransform)),p.alphaTest>0&&(m.alphaTest.value=p.alphaTest)}function c(m,p){m.diffuse.value.copy(p.color),m.opacity.value=p.opacity,m.rotation.value=p.rotation,p.map&&(m.map.value=p.map,e(p.map,m.mapTransform)),p.alphaMap&&(m.alphaMap.value=p.alphaMap,e(p.alphaMap,m.alphaMapTransform)),p.alphaTest>0&&(m.alphaTest.value=p.alphaTest)}function h(m,p){m.specular.value.copy(p.specular),m.shininess.value=Math.max(p.shininess,1e-4)}function f(m,p){p.gradientMap&&(m.gradientMap.value=p.gradientMap)}function u(m,p){m.metalness.value=p.metalness,p.metalnessMap&&(m.metalnessMap.value=p.metalnessMap,e(p.metalnessMap,m.metalnessMapTransform)),m.roughness.value=p.roughness,p.roughnessMap&&(m.roughnessMap.value=p.roughnessMap,e(p.roughnessMap,m.roughnessMapTransform)),p.envMap&&(m.envMapIntensity.value=p.envMapIntensity)}function d(m,p,S){m.ior.value=p.ior,p.sheen>0&&(m.sheenColor.value.copy(p.sheenColor).multiplyScalar(p.sheen),m.sheenRoughness.value=p.sheenRoughness,p.sheenColorMap&&(m.sheenColorMap.value=p.sheenColorMap,e(p.sheenColorMap,m.sheenColorMapTransform)),p.sheenRoughnessMap&&(m.sheenRoughnessMap.value=p.sheenRoughnessMap,e(p.sheenRoughnessMap,m.sheenRoughnessMapTransform))),p.clearcoat>0&&(m.clearcoat.value=p.clearcoat,m.clearcoatRoughness.value=p.clearcoatRoughness,p.clearcoatMap&&(m.clearcoatMap.value=p.clearcoatMap,e(p.clearcoatMap,m.clearcoatMapTransform)),p.clearcoatRoughnessMap&&(m.clearcoatRoughnessMap.value=p.clearcoatRoughnessMap,e(p.clearcoatRoughnessMap,m.clearcoatRoughnessMapTransform)),p.clearcoatNormalMap&&(m.clearcoatNormalMap.value=p.clearcoatNormalMap,e(p.clearcoatNormalMap,m.clearcoatNormalMapTransform),m.clearcoatNormalScale.value.copy(p.clearcoatNormalScale),p.side===bn&&m.clearcoatNormalScale.value.negate())),p.dispersion>0&&(m.dispersion.value=p.dispersion),p.retroreflectivity>0&&(m.retroreflectivity.value=p.retroreflectivity),p.iridescence>0&&(m.iridescence.value=p.iridescence,m.iridescenceIOR.value=p.iridescenceIOR,m.iridescenceThicknessMinimum.value=p.iridescenceThicknessRange[0],m.iridescenceThicknessMaximum.value=p.iridescenceThicknessRange[1],p.iridescenceMap&&(m.iridescenceMap.value=p.iridescenceMap,e(p.iridescenceMap,m.iridescenceMapTransform)),p.iridescenceThicknessMap&&(m.iridescenceThicknessMap.value=p.iridescenceThicknessMap,e(p.iridescenceThicknessMap,m.iridescenceThicknessMapTransform))),p.transmission>0&&(m.transmission.value=p.transmission,m.transmissionSamplerMap.value=S.texture,m.transmissionSamplerSize.value.set(S.width,S.height),p.transmissionMap&&(m.transmissionMap.value=p.transmissionMap,e(p.transmissionMap,m.transmissionMapTransform)),m.thickness.value=p.thickness,p.thicknessMap&&(m.thicknessMap.value=p.thicknessMap,e(p.thicknessMap,m.thicknessMapTransform)),m.attenuationDistance.value=p.attenuationDistance,m.attenuationColor.value.copy(p.attenuationColor)),p.anisotropy>0&&(m.anisotropyVector.value.set(p.anisotropy*Math.cos(p.anisotropyRotation),p.anisotropy*Math.sin(p.anisotropyRotation)),p.anisotropyMap&&(m.anisotropyMap.value=p.anisotropyMap,e(p.anisotropyMap,m.anisotropyMapTransform))),m.specularIntensity.value=p.specularIntensity,m.specularColor.value.copy(p.specularColor),p.specularColorMap&&(m.specularColorMap.value=p.specularColorMap,e(p.specularColorMap,m.specularColorMapTransform)),p.specularIntensityMap&&(m.specularIntensityMap.value=p.specularIntensityMap,e(p.specularIntensityMap,m.specularIntensityMapTransform))}function g(m,p){p.matcap&&(m.matcap.value=p.matcap)}function _(m,p){let S=t.get(p).light;m.referencePosition.value.setFromMatrixPosition(S.matrixWorld),m.nearDistance.value=S.shadow.camera.near,m.farDistance.value=S.shadow.camera.far}return{refreshFogUniforms:n,refreshMaterialUniforms:s}}function hx(i,t,e,n){let s={},r={},a=[],o=i.getParameter(i.MAX_UNIFORM_BUFFER_BINDINGS);function l(v,b){let E=b.program;n.uniformBlockBinding(v,E)}function c(v,b){let E=s[v.id];E===void 0&&(m(v),E=h(v),s[v.id]=E,v.addEventListener("dispose",S));let C=b.program;n.updateUBOMapping(v,C);let y=t.render.frame;r[v.id]!==y&&(u(v),r[v.id]=y)}function h(v){let b=f();v.__bindingPointIndex=b;let E=i.createBuffer(),C=v.__size,y=v.usage;return i.bindBuffer(i.UNIFORM_BUFFER,E),i.bufferData(i.UNIFORM_BUFFER,C,y),i.bindBuffer(i.UNIFORM_BUFFER,null),i.bindBufferBase(i.UNIFORM_BUFFER,b,E),E}function f(){for(let v=0;v<o;v++)if(a.indexOf(v)===-1)return a.push(v),v;return he("WebGLRenderer: Maximum number of simultaneously usable uniforms groups reached."),0}function u(v){let b=s[v.id],E=v.uniforms,C=v.__cache;i.bindBuffer(i.UNIFORM_BUFFER,b);for(let y=0,w=E.length;y<w;y++){let I=E[y];if(Array.isArray(I))for(let N=0,H=I.length;N<H;N++)d(I[N],y,N,C);else d(I,y,0,C)}i.bindBuffer(i.UNIFORM_BUFFER,null)}function d(v,b,E,C){if(_(v,b,E,C)===!0){let y=v.__offset,w=v.value;if(Array.isArray(w)){let I=0;for(let N=0;N<w.length;N++){let H=w[N],W=p(H);g(H,v.__data,I),typeof H!="number"&&typeof H!="boolean"&&!H.isMatrix3&&!ArrayBuffer.isView(H)&&(I+=W.storage/Float32Array.BYTES_PER_ELEMENT)}}else g(w,v.__data,0);i.bufferSubData(i.UNIFORM_BUFFER,y,v.__data)}}function g(v,b,E){typeof v=="number"||typeof v=="boolean"?b[0]=v:v.isMatrix3?(b[0]=v.elements[0],b[1]=v.elements[1],b[2]=v.elements[2],b[3]=0,b[4]=v.elements[3],b[5]=v.elements[4],b[6]=v.elements[5],b[7]=0,b[8]=v.elements[6],b[9]=v.elements[7],b[10]=v.elements[8],b[11]=0):ArrayBuffer.isView(v)?b.set(new v.constructor(v.buffer,v.byteOffset,b.length)):v.toArray(b,E)}function _(v,b,E,C){let y=v.value,w=b+"_"+E;if(C[w]===void 0)return typeof y=="number"||typeof y=="boolean"?C[w]=y:ArrayBuffer.isView(y)?C[w]=y.slice():C[w]=y.clone(),!0;{let I=C[w];if(typeof y=="number"||typeof y=="boolean"){if(I!==y)return C[w]=y,!0}else{if(ArrayBuffer.isView(y))return!0;if(I.equals(y)===!1)return I.copy(y),!0}}return!1}function m(v){let b=v.uniforms,E=0,C=16;for(let w=0,I=b.length;w<I;w++){let N=Array.isArray(b[w])?b[w]:[b[w]];for(let H=0,W=N.length;H<W;H++){let U=N[H],G=Array.isArray(U.value)?U.value:[U.value];for(let rt=0,j=G.length;rt<j;rt++){let pt=G[rt],st=p(pt),lt=E%C,O=lt%st.boundary,vt=lt+O;E+=O,vt!==0&&C-vt<st.storage&&(E+=C-vt),U.__data=new Float32Array(st.storage/Float32Array.BYTES_PER_ELEMENT),U.__offset=E,E+=st.storage}}}let y=E%C;return y>0&&(E+=C-y),v.__size=E,v.__cache={},this}function p(v){let b={boundary:0,storage:0};return typeof v=="number"||typeof v=="boolean"?(b.boundary=4,b.storage=4):v.isVector2?(b.boundary=8,b.storage=8):v.isVector3||v.isColor?(b.boundary=16,b.storage=12):v.isVector4?(b.boundary=16,b.storage=16):v.isMatrix3?(b.boundary=48,b.storage=48):v.isMatrix4?(b.boundary=64,b.storage=64):v.isTexture?ue("WebGLRenderer: Texture samplers can not be part of an uniforms group."):ArrayBuffer.isView(v)?(b.boundary=16,b.storage=v.byteLength):ue("WebGLRenderer: Unsupported uniform value type.",v),b}function S(v){let b=v.target;b.removeEventListener("dispose",S);let E=a.indexOf(b.__bindingPointIndex);a.splice(E,1),i.deleteBuffer(s[b.id]),delete s[b.id],delete r[b.id]}function A(){for(let v in s)i.deleteBuffer(s[v]);a=[],s={},r={}}return{bind:l,update:c,dispose:A}}var ux=new Uint16Array([12469,15057,12620,14925,13266,14620,13807,14376,14323,13990,14545,13625,14713,13328,14840,12882,14931,12528,14996,12233,15039,11829,15066,11525,15080,11295,15085,10976,15082,10705,15073,10495,13880,14564,13898,14542,13977,14430,14158,14124,14393,13732,14556,13410,14702,12996,14814,12596,14891,12291,14937,11834,14957,11489,14958,11194,14943,10803,14921,10506,14893,10278,14858,9960,14484,14039,14487,14025,14499,13941,14524,13740,14574,13468,14654,13106,14743,12678,14818,12344,14867,11893,14889,11509,14893,11180,14881,10751,14852,10428,14812,10128,14765,9754,14712,9466,14764,13480,14764,13475,14766,13440,14766,13347,14769,13070,14786,12713,14816,12387,14844,11957,14860,11549,14868,11215,14855,10751,14825,10403,14782,10044,14729,9651,14666,9352,14599,9029,14967,12835,14966,12831,14963,12804,14954,12723,14936,12564,14917,12347,14900,11958,14886,11569,14878,11247,14859,10765,14828,10401,14784,10011,14727,9600,14660,9289,14586,8893,14508,8533,15111,12234,15110,12234,15104,12216,15092,12156,15067,12010,15028,11776,14981,11500,14942,11205,14902,10752,14861,10393,14812,9991,14752,9570,14682,9252,14603,8808,14519,8445,14431,8145,15209,11449,15208,11451,15202,11451,15190,11438,15163,11384,15117,11274,15055,10979,14994,10648,14932,10343,14871,9936,14803,9532,14729,9218,14645,8742,14556,8381,14461,8020,14365,7603,15273,10603,15272,10607,15267,10619,15256,10631,15231,10614,15182,10535,15118,10389,15042,10167,14963,9787,14883,9447,14800,9115,14710,8665,14615,8318,14514,7911,14411,7507,14279,7198,15314,9675,15313,9683,15309,9712,15298,9759,15277,9797,15229,9773,15166,9668,15084,9487,14995,9274,14898,8910,14800,8539,14697,8234,14590,7790,14479,7409,14367,7067,14178,6621,15337,8619,15337,8631,15333,8677,15325,8769,15305,8871,15264,8940,15202,8909,15119,8775,15022,8565,14916,8328,14804,8009,14688,7614,14569,7287,14448,6888,14321,6483,14088,6171,15350,7402,15350,7419,15347,7480,15340,7613,15322,7804,15287,7973,15229,8057,15148,8012,15046,7846,14933,7611,14810,7357,14682,7069,14552,6656,14421,6316,14251,5948,14007,5528,15356,5942,15356,5977,15353,6119,15348,6294,15332,6551,15302,6824,15249,7044,15171,7122,15070,7050,14949,6861,14818,6611,14679,6349,14538,6067,14398,5651,14189,5311,13935,4958,15359,4123,15359,4153,15356,4296,15353,4646,15338,5160,15311,5508,15263,5829,15188,6042,15088,6094,14966,6001,14826,5796,14678,5543,14527,5287,14377,4985,14133,4586,13869,4257,15360,1563,15360,1642,15358,2076,15354,2636,15341,3350,15317,4019,15273,4429,15203,4732,15105,4911,14981,4932,14836,4818,14679,4621,14517,4386,14359,4156,14083,3795,13808,3437,15360,122,15360,137,15358,285,15355,636,15344,1274,15322,2177,15281,2765,15215,3223,15120,3451,14995,3569,14846,3567,14681,3466,14511,3305,14344,3121,14037,2800,13753,2467,15360,0,15360,1,15359,21,15355,89,15346,253,15325,479,15287,796,15225,1148,15133,1492,15008,1749,14856,1882,14685,1886,14506,1783,14324,1608,13996,1398,13702,1183]),wi=null;function fx(){return wi===null&&(wi=new xa(ux,16,16,ps,un),wi.name="DFG_LUT",wi.minFilter=Sn,wi.magFilter=Sn,wi.wrapS=vi,wi.wrapT=vi,wi.generateMipmaps=!1,wi.needsUpdate=!0),wi}var wc=class{constructor(t={}){let{canvas:e=Qu(),context:n=null,depth:s=!0,stencil:r=!1,alpha:a=!1,antialias:o=!1,premultipliedAlpha:l=!0,preserveDrawingBuffer:c=!1,powerPreference:h="default",failIfMajorPerformanceCaveat:f=!1,reversedDepthBuffer:u=!1,outputBufferType:d=Fn}=t;this.isWebGLRenderer=!0;let g;if(n!==null){if(typeof WebGLRenderingContext<"u"&&n instanceof WebGLRenderingContext)throw new Error("THREE.WebGLRenderer: WebGL 1 is not supported since r163.");g=n.getContextAttributes().alpha}else g=a;let _=d,m=new Set([Vl,Hl,kl]),p=new Set([Fn,fi,Rr,Cr,Ol,Bl]),S=new Uint32Array(4),A=new Int32Array(4),v=new P,b=null,E=null,C=[],y=[],w=null;this.domElement=e,this.debug={checkShaderErrors:!0,diagnostics:{keywords:!1},onShaderError:null},this.autoClear=!0,this.autoClearColor=!0,this.autoClearDepth=!0,this.autoClearStencil=!0,this.sortObjects=!0,this.clippingPlanes=[],this.localClippingEnabled=!1,this.toneMapping=ui,this.toneMappingExposure=1,this.transmissionResolutionScale=1;let I=this,N=!1,H=null,W=null,U=null,G=null;this._outputColorSpace=Ke;let rt=0,j=0,pt=null,st=-1,lt=null,O=new $e,vt=new $e,St=null,Et=new se(0),Xt=0,gt=e.width,J=e.height,q=1,ht=null,wt=null,ct=new $e(0,0,gt,J),Ft=new $e(0,0,gt,J),ae=!1,K=new pr,ut=!1,yt=!1,xt=new De,_t=new P,Gt=new $e,Bt={background:null,fog:null,environment:null,overrideMaterial:null,isScene:!0},Zt=!1;function ne(){return pt===null?q:1}let L=n;function Jt(M,D){return e.getContext(M,D)}let oe,T,x,k,X,et,bt,Rt,it,ot,It,Qt,Ut,At,Lt,ee,fe,F,Pt,at,Dt,Nt,mt;try{let M={alpha:!0,depth:s,stencil:r,antialias:o,premultipliedAlpha:l,preserveDrawingBuffer:c,powerPreference:h,failIfMajorPerformanceCaveat:f};if("setAttribute"in e&&e.setAttribute("data-engine",`three.js r${"186"}`),e.addEventListener("webglcontextlost",Oe,!1),e.addEventListener("webglcontextrestored",Ue,!1),e.addEventListener("webglcontextcreationerror",en,!1),L===null){let D="webgl2";if(L=Jt(D,M),L===null)throw Jt(D)?new Error("THREE.WebGLRenderer: Error creating WebGL context with your selected attributes."):new Error("THREE.WebGLRenderer: Error creating WebGL context.")}ie()}catch(M){throw e.removeEventListener("webglcontextlost",Oe,!1),e.removeEventListener("webglcontextrestored",Ue,!1),e.removeEventListener("webglcontextcreationerror",en,!1),he("WebGLRenderer: "+M.message),M}function ie(){oe=new vg(L),oe.init(),Dt=new rx(L,oe),T=new cg(L,oe,t,Dt),x=new ix(L,oe),T.reversedDepthBuffer&&u&&x.buffers.depth.setReversed(!0),W=L.createFramebuffer(),U=L.createFramebuffer(),G=L.createFramebuffer(),k=new Sg(L),X=new G2,et=new sx(L,oe,x,X,T,Dt,k),bt=new _g(I),Rt=new Ep(L),Nt=new og(L,Rt),it=new yg(L,Rt,k,Nt),ot=new Eg(L,it,Rt,Nt,k),F=new bg(L,T,et),Lt=new hg(X),It=new V2(I,bt,oe,T,Nt,Lt),Qt=new cx(I,X),Ut=new X2,At=new K2(oe),fe=new ag(I,bt,x,ot,g,l),ee=new nx(I,ot,T),mt=new hx(L,k,T,x),Pt=new lg(L,oe,k),at=new Mg(L,oe,k),k.programs=It.programs,I.capabilities=T,I.extensions=oe,I.properties=X,I.renderLists=Ut,I.shadowMap=ee,I.state=x,I.info=k}_!==Fn&&(w=new wg(_,e.width,e.height,o,s,r));let qt=new dh(I,L);this.xr=qt,this.getContext=function(){return L},this.getContextAttributes=function(){return L.getContextAttributes()},this.forceContextLoss=function(){let M=oe.get("WEBGL_lose_context");M&&M.loseContext()},this.forceContextRestore=function(){let M=oe.get("WEBGL_lose_context");M&&M.restoreContext()},this.getPixelRatio=function(){return q},this.setPixelRatio=function(M){M!==void 0&&(q=M,this.setSize(gt,J,!1))},this.getSize=function(M){return M.set(gt,J)},this.setSize=function(M,D,Q=!0){if(qt.isPresenting){ue("WebGLRenderer: Can't change size while VR device is presenting.");return}gt=M,J=D,e.width=Math.floor(M*q),e.height=Math.floor(D*q),Q===!0&&(e.style.width=M+"px",e.style.height=D+"px"),w!==null&&w.setSize(e.width,e.height),this.setViewport(0,0,M,D)},this.getDrawingBufferSize=function(M){return M.set(gt*q,J*q).floor()},this.setDrawingBufferSize=function(M,D,Q){gt=M,J=D,q=Q,e.width=Math.floor(M*Q),e.height=Math.floor(D*Q),this.setViewport(0,0,M,D)},this.setEffects=function(M){if(_===Fn){he("WebGLRenderer: setEffects() requires outputBufferType set to HalfFloatType or FloatType.");return}if(M){for(let D=0;D<M.length;D++)if(M[D].isOutputPass===!0){ue("WebGLRenderer: OutputPass is not needed in setEffects(). Tone mapping and color space conversion are applied automatically.");break}}w.setEffects(M||[])},this.getCurrentViewport=function(M){return M.copy(O)},this.getViewport=function(M){return M.copy(ct)},this.setViewport=function(M,D,Q,Y){M.isVector4?ct.set(M.x,M.y,M.z,M.w):ct.set(M,D,Q,Y),x.viewport(O.copy(ct).multiplyScalar(q).round())},this.getScissor=function(M){return M.copy(Ft)},this.setScissor=function(M,D,Q,Y){M.isVector4?Ft.set(M.x,M.y,M.z,M.w):Ft.set(M,D,Q,Y),x.scissor(vt.copy(Ft).multiplyScalar(q).round())},this.getScissorTest=function(){return ae},this.setScissorTest=function(M){x.setScissorTest(ae=M)},this.setOpaqueSort=function(M){ht=M},this.setTransparentSort=function(M){wt=M},this.getClearColor=function(M){return M.copy(fe.getClearColor())},this.setClearColor=function(){fe.setClearColor(...arguments)},this.getClearAlpha=function(){return fe.getClearAlpha()},this.setClearAlpha=function(){fe.setClearAlpha(...arguments)},this.clear=function(M=!0,D=!0,Q=!0){let Y=0;if(M){let $=!1;if(pt!==null){let Ht=pt.texture.format;$=m.has(Ht)}if($){let Ht=pt.texture.type,Yt=p.has(Ht),zt=fe.getClearColor(),$t=fe.getClearAlpha(),te=zt.r,Me=zt.g,Ee=zt.b;Yt?(S[0]=te,S[1]=Me,S[2]=Ee,S[3]=$t,L.clearBufferuiv(L.COLOR,0,S)):(A[0]=te,A[1]=Me,A[2]=Ee,A[3]=$t,L.clearBufferiv(L.COLOR,0,A))}else Y|=L.COLOR_BUFFER_BIT}D&&(Y|=L.DEPTH_BUFFER_BIT,this.state.buffers.depth.setMask(!0)),Q&&(Y|=L.STENCIL_BUFFER_BIT,this.state.buffers.stencil.setMask(4294967295)),Y!==0&&L.clear(Y)},this.clearColor=function(){this.clear(!0,!1,!1)},this.clearDepth=function(){this.clear(!1,!0,!1)},this.clearStencil=function(){this.clear(!1,!1,!0)},this.setNodesHandler=function(M){M.setRenderer(this),H=M},this.dispose=function(){e.removeEventListener("webglcontextlost",Oe,!1),e.removeEventListener("webglcontextrestored",Ue,!1),e.removeEventListener("webglcontextcreationerror",en,!1),fe.dispose(),Ut.dispose(),At.dispose(),X.dispose(),bt.dispose(),ot.dispose(),Nt.dispose(),mt.dispose(),It.dispose(),qt.dispose(),qt.removeEventListener("sessionstart",Or),qt.removeEventListener("sessionend",mo),Ci.stop()};function Oe(M){M.preventDefault(),ha("WebGLRenderer: Context Lost."),N=!0}function Ue(){ha("WebGLRenderer: Context Restored."),N=!1;let M=k.autoReset,D=ee.enabled,Q=ee.autoUpdate,Y=ee.needsUpdate,$=ee.type;ie(),k.autoReset=M,ee.enabled=D,ee.autoUpdate=Q,ee.needsUpdate=Y,ee.type=$}function en(M){he("WebGLRenderer: A WebGL context could not be created. Reason: ",M.statusMessage)}function Nn(M){let D=M.target;D.removeEventListener("dispose",Nn),me(D)}function me(M){mi(M),X.remove(M)}function mi(M){let D=X.get(M).programs;D!==void 0&&(D.forEach(function(Q){It.releaseProgram(Q)}),M.isShaderMaterial&&It.releaseShaderCache(M))}this.renderBufferDirect=function(M,D,Q,Y,$,Ht){D===null&&(D=Bt);let Yt=$.isMesh&&$.matrixWorld.determinantAffine()<0,zt=zc(M,D,Q,Y,$);x.setMaterial(Y,Yt);let $t=Q.index,te=1;if(Y.wireframe===!0){if($t=it.getWireframeAttribute(Q),$t===void 0)return;te=2}let Me=Q.drawRange,Ee=Q.attributes.position,Kt=Me.start*te,Le=(Me.start+Me.count)*te;Ht!==null&&(Kt=Math.max(Kt,Ht.start*te),Le=Math.min(Le,(Ht.start+Ht.count)*te)),$t!==null?(Kt=Math.max(Kt,0),Le=Math.min(Le,$t.count)):Ee!=null&&(Kt=Math.max(Kt,0),Le=Math.min(Le,Ee.count));let Ze=Le-Kt;if(Ze<0||Ze===1/0)return;Nt.setup($,Y,zt,Q,$t);let Be,Ve=Pt;if($t!==null&&(Be=Rt.get($t),Ve=at,Ve.setIndex(Be)),$.isMesh)Y.wireframe===!0?(x.setLineWidth(Y.wireframeLinewidth*ne()),Ve.setMode(L.LINES)):Ve.setMode(L.TRIANGLES);else if($.isLine){let on=Y.linewidth;on===void 0&&(on=1),x.setLineWidth(on*ne()),$.isLineSegments?Ve.setMode(L.LINES):$.isLineLoop?Ve.setMode(L.LINE_LOOP):Ve.setMode(L.LINE_STRIP)}else $.isPoints?Ve.setMode(L.POINTS):$.isSprite&&Ve.setMode(L.TRIANGLES);if($.isBatchedMesh)if(oe.get("WEBGL_multi_draw"))Ve.renderMultiDraw($._multiDrawStarts,$._multiDrawCounts,$._multiDrawCount);else{let on=$._multiDrawStarts,Wt=$._multiDrawCounts,vn=$._multiDrawCount,Te=$t?Rt.get($t).bytesPerElement:1,Tn=X.get(Y).currentProgram.getUniforms();for(let Un=0;Un<vn;Un++)Tn.setValue(L,"_gl_DrawID",Un),Ve.render(on[Un]/Te,Wt[Un])}else if($.isInstancedMesh)Ve.renderInstances(Kt,Ze,$.count);else if(Q.isInstancedBufferGeometry){let on=Q._maxInstanceCount!==void 0?Q._maxInstanceCount:1/0,Wt=Math.min(Q.instanceCount,on);Ve.renderInstances(Kt,Ze,Wt)}else Ve.render(Kt,Ze)};function Ri(M,D,Q,Y){H!==null&&M.isNodeMaterial&&H.setObject(Y,M),ut===!0&&Lt.setState(M,Q,!1),M.transparent===!0&&M.side===En&&M.forceSinglePass===!1?(M.side=bn,M.needsUpdate=!0,gs(M,D,Y),M.side=hs,M.needsUpdate=!0,gs(M,D,Y),M.side=En):gs(M,D,Y)}this.compile=function(M,D,Q=null){Q===null&&(Q=M),H!==null&&H.renderStart(M,D,Q),E=At.get(Q),E.init(D),y.push(E),Q.traverseVisible(function($){$.isLight&&$.layers.test(D.layers)&&(E.pushLight($),$.castShadow&&E.pushShadow($))}),M!==Q&&M.traverseVisible(function($){$.isLight&&$.layers.test(D.layers)&&(E.pushLight($),$.castShadow&&E.pushShadow($))}),E.setupLights(),H!==null&&H.updateLights(E.state.lightsArray),yt=this.localClippingEnabled,ut=Lt.init(this.clippingPlanes,yt),ut===!0&&Lt.setGlobalState(this.clippingPlanes,D),H!==null&&ee.render(E.state.shadowsArray,Q,D);let Y=new Set;return M.traverse(function($){if(!($.isMesh||$.isPoints||$.isLine||$.isSprite))return;let Ht=$.material;if(Ht)if(Array.isArray(Ht))for(let Yt=0;Yt<Ht.length;Yt++){let zt=Ht[Yt];Ri(zt,Q,D,$),Y.add(zt)}else Ri(Ht,Q,D,$),Y.add(Ht)}),E=y.pop(),H!==null&&H.renderEnd(),Y},this.compileAsync=function(M,D,Q=null){let Y=this.compile(M,D,Q);return new Promise($=>{function Ht(){if(Y.forEach(function(Yt){let $t=X.get(Yt).currentProgram;($t===void 0||$t.isReady())&&Y.delete(Yt)}),Y.size===0){$(M);return}setTimeout(Ht,10)}oe.get("KHR_parallel_shader_compile")!==null?Ht():setTimeout(Ht,10)})};let _n=null;function Ls(M){_n&&_n(M)}function Or(){Ci.stop()}function mo(){Ci.start()}let Ci=new Df;Ci.setAnimationLoop(Ls),typeof self<"u"&&Ci.setContext(self),this.setAnimationLoop=function(M){_n=M,qt.setAnimationLoop(M),M===null?Ci.stop():Ci.start()},qt.addEventListener("sessionstart",Or),qt.addEventListener("sessionend",mo),this.render=function(M,D){if(D!==void 0&&D.isCamera!==!0){he("WebGLRenderer.render: camera is not an instance of THREE.Camera.");return}if(N===!0)return;H!==null&&H.renderStart(M,D);let Q=qt.enabled===!0&&qt.isPresenting===!0,Y=w!==null&&(pt===null||Q)&&w.begin(I,pt);if(M.matrixWorldAutoUpdate===!0&&M.updateMatrixWorld(),D.parent===null&&D.matrixWorldAutoUpdate===!0&&D.updateMatrixWorld(),qt.enabled===!0&&qt.isPresenting===!0&&(w===null||w.isCompositing()===!1)&&(qt.cameraAutoUpdate===!0&&qt.updateCamera(D),D=qt.getCamera()),M.isScene===!0&&M.onBeforeRender(I,M,D,pt),E=At.get(M,y.length),E.init(D),E.state.textureUnits=et.getTextureUnits(),y.push(E),xt.multiplyMatrices(D.projectionMatrix,D.matrixWorldInverse),K.setFromProjectionMatrix(xt,li,D.reversedDepth),yt=this.localClippingEnabled,ut=Lt.init(this.clippingPlanes,yt),b=Ut.get(M,C.length),b.init(),C.push(b),qt.enabled===!0&&qt.isPresenting===!0){let Yt=I.xr.getDepthSensingMesh();Yt!==null&&Ds(Yt,D,-1/0,I.sortObjects)}Ds(M,D,0,I.sortObjects),b.finish(),H!==null&&H.updateLights(E.state.lightsArray),I.sortObjects===!0&&b.sort(ht,wt),Zt=qt.enabled===!1||qt.isPresenting===!1||qt.hasDepthSensing()===!1,Zt&&fe.addToRenderList(b,M),this.info.render.frame++,this.info.autoReset===!0&&this.info.reset(),ut===!0&&Lt.beginShadows();let $=E.state.shadowsArray;if(ee.render($,M,D),ut===!0&&Lt.endShadows(),(Y&&w.hasRenderPass())===!1){let Yt=b.opaque,zt=b.transmissive;if(E.setupLights(),D.isArrayCamera){let $t=D.cameras;if(zt.length>0)for(let te=0,Me=$t.length;te<Me;te++){let Ee=$t[te];zr(Yt,zt,M,Ee)}Zt&&fe.render(M);for(let te=0,Me=$t.length;te<Me;te++){let Ee=$t[te];Br(b,M,Ee,Ee.viewport)}}else zt.length>0&&zr(Yt,zt,M,D),Zt&&fe.render(M),Br(b,M,D)}pt!==null&&j===0&&(et.updateMultisampleRenderTarget(pt),et.updateRenderTargetMipmap(pt)),Y&&w.end(I),M.isScene===!0&&M.onAfterRender(I,M,D),Nt.resetDefaultState(),st=-1,lt=null,y.pop(),y.length>0?(E=y[y.length-1],et.setTextureUnits(E.state.textureUnits),ut===!0&&Lt.setGlobalState(I.clippingPlanes,E.state.camera)):E=null,C.pop(),C.length>0?b=C[C.length-1]:b=null,H!==null&&H.renderEnd()};function Ds(M,D,Q,Y){if(M.visible===!1)return;if(M.layers.test(D.layers)){if(M.isGroup)Q=M.renderOrder;else if(M.isLOD)M.autoUpdate===!0&&M.update(D);else if(M.isLightProbeGrid)E.pushLightProbeGrid(M);else if(M.isLight)E.pushLight(M),M.castShadow&&E.pushShadow(M);else if(M.isSprite){if(!M.frustumCulled||M.intersectsFrustum(K)){Y&&Gt.setFromMatrixPosition(M.matrixWorld).applyMatrix4(xt);let Yt=ot.update(M),zt=M.material;zt.visible&&b.push(M,Yt,zt,Q,Gt.z,null,D)}}else if((M.isMesh||M.isLine||M.isPoints)&&(!M.frustumCulled||M.intersectsFrustum(K))){let Yt=ot.update(M),zt=M.material;if(Y&&(M.boundingSphere!==void 0?(M.boundingSphere===null&&M.computeBoundingSphere(),Gt.copy(M.boundingSphere.center)):(Yt.boundingSphere===null&&Yt.computeBoundingSphere(),Gt.copy(Yt.boundingSphere.center)),Gt.applyMatrix4(M.matrixWorld).applyMatrix4(xt)),Array.isArray(zt)){let $t=Yt.groups;for(let te=0,Me=$t.length;te<Me;te++){let Ee=$t[te],Kt=zt[Ee.materialIndex];Kt&&Kt.visible&&b.push(M,Yt,Kt,Q,Gt.z,Ee,D)}}else zt.visible&&b.push(M,Yt,zt,Q,Gt.z,null,D)}}let Ht=M.children;for(let Yt=0,zt=Ht.length;Yt<zt;Yt++)Ds(Ht[Yt],D,Q,Y)}function Br(M,D,Q,Y){let{opaque:$,transmissive:Ht,transparent:Yt}=M;E.setupLightsView(Q),ut===!0&&Lt.setGlobalState(I.clippingPlanes,Q),Y&&x.viewport(O.copy(Y)),$.length>0&&Xn($,D,Q),Ht.length>0&&Xn(Ht,D,Q),Yt.length>0&&Xn(Yt,D,Q),x.buffers.depth.setTest(!0),x.buffers.depth.setMask(!0),x.buffers.color.setMask(!0),x.setPolygonOffset(!1)}function zr(M,D,Q,Y){if((Q.isScene===!0?Q.overrideMaterial:null)!==null)return;if(E.state.transmissionRenderTarget[Y.id]===void 0){let Kt=oe.has("EXT_color_buffer_half_float")||oe.has("EXT_color_buffer_float");E.state.transmissionRenderTarget[Y.id]=new tn(1,1,{generateMipmaps:!0,type:Kt?un:Fn,minFilter:Ti,samples:Math.max(4,T.samples),stencilBuffer:r,resolveDepthBuffer:!1,resolveStencilBuffer:!1,storeMultisampledDepthBuffer:!1,storeMultisampledStencilBuffer:!1,colorSpace:Ae.workingColorSpace})}let Ht=E.state.transmissionRenderTarget[Y.id],Yt=Y.viewport||O;Ht.setSize(Yt.z*I.transmissionResolutionScale,Yt.w*I.transmissionResolutionScale);let zt=I.getRenderTarget(),$t=I.getActiveCubeFace(),te=I.getActiveMipmapLevel();I.setRenderTarget(Ht),I.getClearColor(Et),Xt=I.getClearAlpha(),Xt<1&&I.setClearColor(16777215,.5),I.clear(),Zt&&fe.render(Q);let Me=I.toneMapping;I.toneMapping=ui;let Ee=Y.viewport;if(Y.viewport!==void 0&&(Y.viewport=void 0),E.setupLightsView(Y),ut===!0&&Lt.setGlobalState(I.clippingPlanes,Y),Xn(M,Q,Y),et.updateMultisampleRenderTarget(Ht),et.updateRenderTargetMipmap(Ht),oe.has("WEBGL_multisampled_render_to_texture")===!1){let Kt=!1;for(let Le=0,Ze=D.length;Le<Ze;Le++){let Be=D[Le],{object:Ve,geometry:on,material:Wt,group:vn}=Be;if(Wt.side===En&&Ve.layers.test(Y.layers)){let Te=Wt.side;Wt.side=bn,Wt.needsUpdate=!0,kr(Ve,Q,Y,on,Wt,vn),Wt.side=Te,Wt.needsUpdate=!0,Kt=!0}}Kt===!0&&(et.updateMultisampleRenderTarget(Ht),et.updateRenderTargetMipmap(Ht))}I.setRenderTarget(zt,$t,te),I.setClearColor(Et,Xt),Ee!==void 0&&(Y.viewport=Ee),I.toneMapping=Me}function Xn(M,D,Q){let Y=D.isScene===!0?D.overrideMaterial:null;for(let $=0,Ht=M.length;$<Ht;$++){let Yt=M[$],{object:zt,geometry:$t,group:te}=Yt,Me=Yt.material;Me.allowOverride===!0&&Y!==null&&(Me=Y),zt.layers.test(Q.layers)&&kr(zt,D,Q,$t,Me,te)}}function kr(M,D,Q,Y,$,Ht){H!==null&&$.isNodeMaterial&&H.setObject(M,$),M.onBeforeRender(I,D,Q,Y,$,Ht),M.modelViewMatrix.multiplyMatrices(Q.matrixWorldInverse,M.matrixWorld),M.normalMatrix.getNormalMatrix(M.modelViewMatrix),$.onBeforeRender(I,D,Q,Y,M,Ht),$.transparent===!0&&$.side===En&&$.forceSinglePass===!1?($.side=bn,$.needsUpdate=!0,I.renderBufferDirect(Q,D,Y,$,M,Ht),$.side=hs,$.needsUpdate=!0,I.renderBufferDirect(Q,D,Y,$,M,Ht),$.side=En):I.renderBufferDirect(Q,D,Y,$,M,Ht),M.onAfterRender(I,D,Q,Y,$,Ht)}function gs(M,D,Q){D.isScene!==!0&&(D=Bt);let Y=X.get(M),$=E.state.lights,Ht=E.state.shadowsArray,Yt=$.state.version,zt=It.getParameters(M,$.state,Ht,D,Q,E.state.lightProbeGridArray),$t=It.getProgramCacheKey(zt),te=Y.programs;Y.environment=M.isMeshStandardMaterial||M.isMeshLambertMaterial||M.isMeshPhongMaterial?D.environment:null,Y.fog=D.fog;let Me=M.isMeshStandardMaterial||M.isMeshLambertMaterial&&!M.envMap||M.isMeshPhongMaterial&&!M.envMap;Y.envMap=bt.get(M.envMap||Y.environment,Me),Y.envMapRotation=Y.environment!==null&&M.envMap===null?D.environmentRotation:M.envMapRotation,te===void 0&&(M.addEventListener("dispose",Nn),te=new Map,Y.programs=te);let Ee=te.get($t);if(Ee!==void 0){if(Y.currentProgram===Ee&&Y.lightsStateVersion===Yt)return xs(M,zt),Ee}else zt.uniforms=It.getUniforms(M),H!==null&&M.isNodeMaterial&&H.build(M,Q,zt),M.onBeforeCompile(zt,I),Ee=It.acquireProgram(zt,$t),te.set($t,Ee),Y.uniforms=zt.uniforms;let Kt=Y.uniforms;return(!M.isShaderMaterial&&!M.isRawShaderMaterial||M.clipping===!0)&&(Kt.clippingPlanes=Lt.uniform),xs(M,zt),Y.needsLights=Hc(M),Y.lightsStateVersion=Yt,Y.needsLights&&(Kt.ambientLightColor.value=$.state.ambient,Kt.lightProbe.value=$.state.probe,Kt.sunLights.value=$.state.sun,Kt.sunLightShadows.value=$.state.sunShadow,Kt.directionalLights.value=$.state.directional,Kt.directionalLightShadows.value=$.state.directionalShadow,Kt.spotLights.value=$.state.spot,Kt.spotLightShadows.value=$.state.spotShadow,Kt.rectAreaLights.value=$.state.rectArea,Kt.ltc_1.value=$.state.rectAreaLTC1,Kt.ltc_2.value=$.state.rectAreaLTC2,Kt.pointLights.value=$.state.point,Kt.pointLightShadows.value=$.state.pointShadow,Kt.hemisphereLights.value=$.state.hemi,Kt.sunShadowMatrix.value=$.state.sunShadowMatrix,Kt.sunShadowCascade.value=$.state.sunShadowCascade,Kt.directionalShadowMatrix.value=$.state.directionalShadowMatrix,Kt.spotLightMatrix.value=$.state.spotLightMatrix,Kt.spotLightMap.value=$.state.spotLightMap,Kt.pointShadowMatrix.value=$.state.pointShadowMatrix),Y.lightProbeGrid=E.state.lightProbeGridArray.length>0,Y.currentProgram=Ee,Y.uniformsList=null,Ee}function Hr(M){if(M.uniformsList===null){let D=M.currentProgram.getUniforms();M.uniformsList=Lr.seqWithValue(D.seq,M.uniforms)}return M.uniformsList}function xs(M,D){let Q=X.get(M);Q.outputColorSpace=D.outputColorSpace,Q.batching=D.batching,Q.batchingColor=D.batchingColor,Q.instancing=D.instancing,Q.instancingColor=D.instancingColor,Q.instancingMorph=D.instancingMorph,Q.skinning=D.skinning,Q.morphTargets=D.morphTargets,Q.morphNormals=D.morphNormals,Q.morphColors=D.morphColors,Q.morphTargetsCount=D.morphTargetsCount,Q.numClippingPlanes=D.numClippingPlanes,Q.numIntersection=D.numClipIntersection,Q.vertexAlphas=D.vertexAlphas,Q.vertexTangents=D.vertexTangents,Q.toneMapping=D.toneMapping}function Bc(M,D){if(M.length===0)return null;if(M.length===1)return M[0].texture!==null?M[0]:null;v.setFromMatrixPosition(D.matrixWorld);for(let Q=0,Y=M.length;Q<Y;Q++){let $=M[Q];if($.texture!==null&&$.boundingBox.containsPoint(v))return $}return null}function zc(M,D,Q,Y,$){D.isScene!==!0&&(D=Bt),et.resetTextureUnits();let Ht=D.fog,Yt=Y.isMeshStandardMaterial||Y.isMeshLambertMaterial||Y.isMeshPhongMaterial?D.environment:null,zt=pt===null?I.outputColorSpace:pt.isXRRenderTarget===!0?pt.texture.colorSpace:Ae.workingColorSpace,$t=Y.isMeshStandardMaterial||Y.isMeshLambertMaterial&&!Y.envMap||Y.isMeshPhongMaterial&&!Y.envMap,te=bt.get(Y.envMap||Yt,$t),Me=Y.vertexColors===!0&&!!Q.attributes.color&&Q.attributes.color.itemSize===4,Ee=!!Q.attributes.tangent&&(!!Y.normalMap||Y.anisotropy>0),Kt=!!Q.morphAttributes.position,Le=!!Q.morphAttributes.normal,Ze=!!Q.morphAttributes.color,Be=ui;Y.toneMapped&&(pt===null||pt.isXRRenderTarget===!0)&&(Be=I.toneMapping);let Ve=Q.morphAttributes.position||Q.morphAttributes.normal||Q.morphAttributes.color,on=Ve!==void 0?Ve.length:0,Wt=X.get(Y),vn=E.state.lights;if(ut===!0&&(yt===!0||M!==lt)){let Pe=M===lt&&Y.id===st;Lt.setState(Y,M,Pe)}let Te=!1;Y.version===Wt.__version?(Wt.needsLights&&Wt.lightsStateVersion!==vn.state.version||Wt.outputColorSpace!==zt||$.isBatchedMesh&&Wt.batching===!1||!$.isBatchedMesh&&Wt.batching===!0||$.isBatchedMesh&&Wt.batchingColor===!0&&$._colorsTexture===null||$.isBatchedMesh&&Wt.batchingColor===!1&&$._colorsTexture!==null||$.isInstancedMesh&&Wt.instancing===!1||!$.isInstancedMesh&&Wt.instancing===!0||$.isSkinnedMesh&&Wt.skinning===!1||!$.isSkinnedMesh&&Wt.skinning===!0||$.isInstancedMesh&&Wt.instancingColor===!0&&$.instanceColor===null||$.isInstancedMesh&&Wt.instancingColor===!1&&$.instanceColor!==null||$.isInstancedMesh&&Wt.instancingMorph===!0&&$.morphTexture===null||$.isInstancedMesh&&Wt.instancingMorph===!1&&$.morphTexture!==null||Wt.envMap!==te||Y.fog===!0&&Wt.fog!==Ht||Wt.numClippingPlanes!==void 0&&(Wt.numClippingPlanes!==Lt.numPlanes||Wt.numIntersection!==Lt.numIntersection)||Wt.vertexAlphas!==Me||Wt.vertexTangents!==Ee||Wt.morphTargets!==Kt||Wt.morphNormals!==Le||Wt.morphColors!==Ze||Wt.toneMapping!==Be||Wt.morphTargetsCount!==on||!!Wt.lightProbeGrid!=E.state.lightProbeGridArray.length>0)&&(Te=!0):(Te=!0,Wt.__version=Y.version);let Tn=Wt.currentProgram;Te===!0&&(Tn=gs(Y,D,$),H&&Y.isNodeMaterial&&H.onUpdateProgram(Y,Tn,Wt));let Un=!1,qn=!1,On=!1,Ce=Tn.getUniforms(),Ye=Wt.uniforms;if(x.useProgram(Tn.program)&&(Un=!0,qn=!0,On=!0),Y.id!==st&&(st=Y.id,qn=!0),Wt.needsLights){let Pe=Bc(E.state.lightProbeGridArray,$);Wt.lightProbeGrid!==Pe&&(Wt.lightProbeGrid=Pe,qn=!0)}if(Un||lt!==M){x.buffers.depth.getReversed()&&M.reversedDepth!==!0&&(M._reversedDepth=!0,M.updateProjectionMatrix()),Ce.setValue(L,"projectionMatrix",M.projectionMatrix),Ce.setValue(L,"viewMatrix",M.matrixWorldInverse);let pn=Ce.map.cameraPosition;pn!==void 0&&pn.setValue(L,_t.setFromMatrixPosition(M.matrixWorld)),T.logarithmicDepthBuffer&&Ce.setValue(L,"logDepthBufFC",2/(Math.log(M.far+1)/Math.LN2)),(Y.isMeshPhongMaterial||Y.isMeshToonMaterial||Y.isMeshLambertMaterial||Y.isMeshBasicMaterial||Y.isMeshStandardMaterial||Y.isShaderMaterial)&&Ce.setValue(L,"isOrthographic",M.isOrthographicCamera===!0),lt!==M&&(lt=M,qn=!0,On=!0)}if(Wt.needsLights&&(vn.state.sunShadowMap.length>0&&Ce.setValue(L,"sunShadowMap",vn.state.sunShadowMap,et),vn.state.directionalShadowMap.length>0&&Ce.setValue(L,"directionalShadowMap",vn.state.directionalShadowMap,et),vn.state.spotShadowMap.length>0&&Ce.setValue(L,"spotShadowMap",vn.state.spotShadowMap,et),vn.state.pointShadowMap.length>0&&Ce.setValue(L,"pointShadowMap",vn.state.pointShadowMap,et)),$.isSkinnedMesh){Ce.setOptional(L,$,"bindMatrix"),Ce.setOptional(L,$,"bindMatrixInverse");let Pe=$.skeleton;Pe&&(Pe.boneTexture===null&&Pe.computeBoneTexture(),Ce.setValue(L,"boneTexture",Pe.boneTexture,et))}$.isBatchedMesh&&(Ce.setOptional(L,$,"batchingTexture"),Ce.setValue(L,"batchingTexture",$._matricesTexture,et),Ce.setOptional(L,$,"batchingIdTexture"),Ce.setValue(L,"batchingIdTexture",$._indirectTexture,et),Ce.setOptional(L,$,"batchingColorTexture"),$._colorsTexture!==null&&Ce.setValue(L,"batchingColorTexture",$._colorsTexture,et));let Bn=Q.morphAttributes;if((Bn.position!==void 0||Bn.normal!==void 0||Bn.color!==void 0)&&F.update($,Q,Tn),(qn||Wt.receiveShadow!==$.receiveShadow)&&(Wt.receiveShadow=$.receiveShadow,Ce.setValue(L,"receiveShadow",$.receiveShadow)),(Y.isMeshStandardMaterial||Y.isMeshLambertMaterial||Y.isMeshPhongMaterial)&&Y.envMap===null&&D.environment!==null&&(Ye.envMapIntensity.value=D.environmentIntensity),Ye.dfgLUT!==void 0&&(Ye.dfgLUT.value=fx()),qn){if(Ce.setValue(L,"toneMappingExposure",I.toneMappingExposure),Wt.needsLights&&kc(Ye,On),Ht&&Y.fog===!0&&Qt.refreshFogUniforms(Ye,Ht),Qt.refreshMaterialUniforms(Ye,Y,q,J,E.state.transmissionRenderTarget[M.id]),Wt.needsLights&&Wt.lightProbeGrid){let Pe=Wt.lightProbeGrid;Ye.probesSH.value=Pe.texture,Ye.probesMin.value.copy(Pe.boundingBox.min),Ye.probesMax.value.copy(Pe.boundingBox.max),Ye.probesResolution.value.copy(Pe.resolution)}Lr.upload(L,Hr(Wt),Ye,et)}if(Y.isShaderMaterial&&Y.uniformsNeedUpdate===!0&&(Lr.upload(L,Hr(Wt),Ye,et),Y.uniformsNeedUpdate=!1),Y.isSpriteMaterial&&Ce.setValue(L,"center",$.center),Ce.setValue(L,"modelViewMatrix",$.modelViewMatrix),Ce.setValue(L,"normalMatrix",$.normalMatrix),Ce.setValue(L,"modelMatrix",$.matrixWorld),Y.uniformsGroups!==void 0){let Pe=Y.uniformsGroups;for(let pn=0,Pi=Pe.length;pn<Pi;pn++){let Vr=Pe[pn];mt.update(Vr,Tn),mt.bind(Vr,Tn)}}return Tn}function kc(M,D){M.ambientLightColor.needsUpdate=D,M.lightProbe.needsUpdate=D,M.sunLights.needsUpdate=D,M.sunLightShadows.needsUpdate=D,M.directionalLights.needsUpdate=D,M.directionalLightShadows.needsUpdate=D,M.pointLights.needsUpdate=D,M.pointLightShadows.needsUpdate=D,M.spotLights.needsUpdate=D,M.spotLightShadows.needsUpdate=D,M.rectAreaLights.needsUpdate=D,M.hemisphereLights.needsUpdate=D}function Hc(M){return M.isMeshLambertMaterial||M.isMeshToonMaterial||M.isMeshPhongMaterial||M.isMeshStandardMaterial||M.isShadowMaterial||M.isShaderMaterial&&M.lights===!0}this.getActiveCubeFace=function(){return rt},this.getActiveMipmapLevel=function(){return j},this.getRenderTarget=function(){return pt},this.setRenderTargetTextures=function(M,D,Q){let Y=X.get(M);Y.__autoAllocateDepthBuffer=M.resolveDepthBuffer===!1,Y.__autoAllocateDepthBuffer===!1&&(Y.__useRenderToTexture=!1),X.get(M.texture).__webglTexture=D,X.get(M.depthTexture).__webglTexture=Y.__autoAllocateDepthBuffer?void 0:Q,Y.__hasExternalTextures=!0},this.setRenderTargetFramebuffer=function(M,D){let Q=X.get(M);Q.__webglFramebuffer=D,Q.__useDefaultFramebuffer=D===void 0},this.setRenderTarget=function(M,D=0,Q=0){pt=M,rt=D,j=Q;let Y=null,$=!1,Ht=!1;if(M){let zt=X.get(M);if(zt.__useDefaultFramebuffer!==void 0){x.bindFramebuffer(L.FRAMEBUFFER,zt.__webglFramebuffer),O.copy(M.viewport),vt.copy(M.scissor),St=M.scissorTest,x.viewport(O),x.scissor(vt),x.setScissorTest(St),st=-1;return}else if(zt.__webglFramebuffer===void 0)et.setupRenderTarget(M);else if(zt.__hasExternalTextures)et.rebindTextures(M,X.get(M.texture).__webglTexture,X.get(M.depthTexture).__webglTexture);else if(M.depthBuffer){let Me=M.depthTexture;if(zt.__boundDepthTexture!==Me){if(Me!==null&&X.has(Me)&&(M.width!==Me.image.width||M.height!==Me.image.height))throw new Error("THREE.WebGLRenderer: Attached DepthTexture is initialized to the incorrect size.");et.setupDepthRenderbuffer(M)}}let $t=M.texture;($t.isData3DTexture||$t.isDataArrayTexture||$t.isCompressedArrayTexture)&&(Ht=!0);let te=X.get(M).__webglFramebuffer;M.isWebGLCubeRenderTarget?(Array.isArray(te[D])?Y=te[D][Q]:Y=te[D],$=!0):M.samples>0&&et.useMultisampledRTT(M)===!1?Y=X.get(M).__webglMultisampledFramebuffer:Array.isArray(te)?Y=te[Q]:Y=te,O.copy(M.viewport),vt.copy(M.scissor),St=M.scissorTest}else O.copy(ct).multiplyScalar(q).floor(),vt.copy(Ft).multiplyScalar(q).floor(),St=ae;if(Q!==0&&(Y=W),x.bindFramebuffer(L.FRAMEBUFFER,Y)&&x.drawBuffers(M,Y),x.viewport(O),x.scissor(vt),x.setScissorTest(St),$){let zt=X.get(M.texture);L.framebufferTexture2D(L.FRAMEBUFFER,L.COLOR_ATTACHMENT0,L.TEXTURE_CUBE_MAP_POSITIVE_X+D,zt.__webglTexture,Q)}else if(Ht){let zt=D;for(let $t=0;$t<M.textures.length;$t++){let te=X.get(M.textures[$t]);L.framebufferTextureLayer(L.FRAMEBUFFER,L.COLOR_ATTACHMENT0+$t,te.__webglTexture,Q,zt)}}else if(M!==null&&Q!==0){let zt=X.get(M.texture);L.framebufferTexture2D(L.FRAMEBUFFER,L.COLOR_ATTACHMENT0,L.TEXTURE_2D,zt.__webglTexture,Q)}st=-1};function Ns(M){let D=X.get(M);return(D.__readFormat!==M.format||D.__readType!==M.type)&&(D.__readFormat=M.format,D.__readType=M.type,D.__formatReadable=T.textureFormatReadable(M.format),D.__typeReadable=T.textureTypeReadable(M.type)),D}this.readRenderTargetPixels=function(M,D,Q,Y,$,Ht,Yt,zt=0){if(!(M&&M.isWebGLRenderTarget)){he("WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");return}let $t=X.get(M).__webglFramebuffer;if(M.isWebGLCubeRenderTarget&&Yt!==void 0&&($t=$t[Yt]),$t){x.bindFramebuffer(L.FRAMEBUFFER,$t);try{let te=M.textures[zt],Me=te.format,Ee=te.type;M.textures.length>1&&L.readBuffer(L.COLOR_ATTACHMENT0+zt);let Kt=Ns(te);if(Kt.__formatReadable===!1){he("WebGLRenderer.readRenderTargetPixels: renderTarget is not in RGBA or implementation defined format.");return}if(Kt.__typeReadable===!1){he("WebGLRenderer.readRenderTargetPixels: renderTarget is not in UnsignedByteType or implementation defined type.");return}D>=0&&D<=M.width-Y&&Q>=0&&Q<=M.height-$&&L.readPixels(D,Q,Y,$,Dt.convert(Me),Dt.convert(Ee),Ht)}finally{let te=pt!==null?X.get(pt).__webglFramebuffer:null;x.bindFramebuffer(L.FRAMEBUFFER,te)}}},this.readRenderTargetPixelsAsync=async function(M,D,Q,Y,$,Ht,Yt,zt=0){if(!(M&&M.isWebGLRenderTarget))throw new Error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");let $t=X.get(M).__webglFramebuffer;if(M.isWebGLCubeRenderTarget&&Yt!==void 0&&($t=$t[Yt]),$t)if(D>=0&&D<=M.width-Y&&Q>=0&&Q<=M.height-$){x.bindFramebuffer(L.FRAMEBUFFER,$t);let te=M.textures[zt],Me=te.format,Ee=te.type;M.textures.length>1&&L.readBuffer(L.COLOR_ATTACHMENT0+zt);let Kt=Ns(te);if(Kt.__formatReadable===!1)throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in RGBA or implementation defined format.");if(Kt.__typeReadable===!1)throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in UnsignedByteType or implementation defined type.");let Le=L.createBuffer();L.bindBuffer(L.PIXEL_PACK_BUFFER,Le),L.bufferData(L.PIXEL_PACK_BUFFER,Ht.byteLength,L.STREAM_READ),L.readPixels(D,Q,Y,$,Dt.convert(Me),Dt.convert(Ee),0),L.bindBuffer(L.PIXEL_PACK_BUFFER,null);let Ze=pt!==null?X.get(pt).__webglFramebuffer:null;x.bindFramebuffer(L.FRAMEBUFFER,Ze);let Be=L.fenceSync(L.SYNC_GPU_COMMANDS_COMPLETE,0);return L.flush(),await ef(L,Be,4),L.bindBuffer(L.PIXEL_PACK_BUFFER,Le),L.getBufferSubData(L.PIXEL_PACK_BUFFER,0,Ht),L.bindBuffer(L.PIXEL_PACK_BUFFER,null),L.deleteBuffer(Le),L.deleteSync(Be),Ht}else throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: requested read bounds are out of range.")},this.copyFramebufferToTexture=function(M,D=null,Q=0){let Y=Math.pow(2,-Q),$=Math.floor(M.image.width*Y),Ht=Math.floor(M.image.height*Y),Yt=D!==null?D.x:0,zt=D!==null?D.y:0;et.setTexture2D(M,0),L.copyTexSubImage2D(L.TEXTURE_2D,Q,0,0,Yt,zt,$,Ht),x.unbindTexture()},this.copyTextureToTexture=function(M,D,Q=null,Y=null,$=0,Ht=0){let Yt,zt,$t,te,Me,Ee,Kt,Le,Ze,Be=M.isCompressedTexture?M.mipmaps[Ht]:M.image;if(Q!==null)Yt=Q.max.x-Q.min.x,zt=Q.max.y-Q.min.y,$t=Q.isBox3?Q.max.z-Q.min.z:1,te=Q.min.x,Me=Q.min.y,Ee=Q.isBox3?Q.min.z:0;else{let Ye=Math.pow(2,-$);Yt=Math.floor(Be.width*Ye),zt=Math.floor(Be.height*Ye),M.isDataArrayTexture?$t=Be.depth:M.isData3DTexture?$t=Math.floor(Be.depth*Ye):$t=1,te=0,Me=0,Ee=0}Y!==null?(Kt=Y.x,Le=Y.y,Ze=Y.z):(Kt=0,Le=0,Ze=0);let Ve=Dt.convert(D.format),on=Dt.convert(D.type),Wt;D.isData3DTexture?(et.setTexture3D(D,0),Wt=L.TEXTURE_3D):D.isDataArrayTexture||D.isCompressedArrayTexture?(et.setTexture2DArray(D,0),Wt=L.TEXTURE_2D_ARRAY):(et.setTexture2D(D,0),Wt=L.TEXTURE_2D),x.activeTexture(L.TEXTURE0),x.pixelStorei(L.UNPACK_FLIP_Y_WEBGL,D.flipY),x.pixelStorei(L.UNPACK_PREMULTIPLY_ALPHA_WEBGL,D.premultiplyAlpha),x.pixelStorei(L.UNPACK_ALIGNMENT,D.unpackAlignment);let vn=x.getParameter(L.UNPACK_ROW_LENGTH),Te=x.getParameter(L.UNPACK_IMAGE_HEIGHT),Tn=x.getParameter(L.UNPACK_SKIP_PIXELS),Un=x.getParameter(L.UNPACK_SKIP_ROWS),qn=x.getParameter(L.UNPACK_SKIP_IMAGES);x.pixelStorei(L.UNPACK_ROW_LENGTH,Be.width),x.pixelStorei(L.UNPACK_IMAGE_HEIGHT,Be.height),x.pixelStorei(L.UNPACK_SKIP_PIXELS,te),x.pixelStorei(L.UNPACK_SKIP_ROWS,Me),x.pixelStorei(L.UNPACK_SKIP_IMAGES,Ee);let On=M.isDataArrayTexture||M.isData3DTexture,Ce=D.isDataArrayTexture||D.isData3DTexture;if(M.isDepthTexture){let Ye=X.get(M),Bn=X.get(D),Pe=X.get(Ye.__renderTarget),pn=X.get(Bn.__renderTarget);x.bindFramebuffer(L.READ_FRAMEBUFFER,Pe.__webglFramebuffer),x.bindFramebuffer(L.DRAW_FRAMEBUFFER,pn.__webglFramebuffer);for(let Pi=0;Pi<$t;Pi++)On&&(L.framebufferTextureLayer(L.READ_FRAMEBUFFER,L.COLOR_ATTACHMENT0,X.get(M).__webglTexture,$,Ee+Pi),L.framebufferTextureLayer(L.DRAW_FRAMEBUFFER,L.COLOR_ATTACHMENT0,X.get(D).__webglTexture,Ht,Ze+Pi)),L.blitFramebuffer(te,Me,Yt,zt,Kt,Le,Yt,zt,L.DEPTH_BUFFER_BIT,L.NEAREST);x.bindFramebuffer(L.READ_FRAMEBUFFER,null),x.bindFramebuffer(L.DRAW_FRAMEBUFFER,null)}else if($!==0||M.isRenderTargetTexture||X.has(M)){let Ye=X.get(M),Bn=X.get(D);x.bindFramebuffer(L.READ_FRAMEBUFFER,U),x.bindFramebuffer(L.DRAW_FRAMEBUFFER,G);for(let Pe=0;Pe<$t;Pe++)On?L.framebufferTextureLayer(L.READ_FRAMEBUFFER,L.COLOR_ATTACHMENT0,Ye.__webglTexture,$,Ee+Pe):L.framebufferTexture2D(L.READ_FRAMEBUFFER,L.COLOR_ATTACHMENT0,L.TEXTURE_2D,Ye.__webglTexture,$),Ce?L.framebufferTextureLayer(L.DRAW_FRAMEBUFFER,L.COLOR_ATTACHMENT0,Bn.__webglTexture,Ht,Ze+Pe):L.framebufferTexture2D(L.DRAW_FRAMEBUFFER,L.COLOR_ATTACHMENT0,L.TEXTURE_2D,Bn.__webglTexture,Ht),$!==0?L.blitFramebuffer(te,Me,Yt,zt,Kt,Le,Yt,zt,L.COLOR_BUFFER_BIT,L.NEAREST):Ce?L.copyTexSubImage3D(Wt,Ht,Kt,Le,Ze+Pe,te,Me,Yt,zt):L.copyTexSubImage2D(Wt,Ht,Kt,Le,te,Me,Yt,zt);x.bindFramebuffer(L.READ_FRAMEBUFFER,null),x.bindFramebuffer(L.DRAW_FRAMEBUFFER,null)}else Ce?M.isDataTexture||M.isData3DTexture?L.texSubImage3D(Wt,Ht,Kt,Le,Ze,Yt,zt,$t,Ve,on,Be.data):D.isCompressedArrayTexture?L.compressedTexSubImage3D(Wt,Ht,Kt,Le,Ze,Yt,zt,$t,Ve,Be.data):L.texSubImage3D(Wt,Ht,Kt,Le,Ze,Yt,zt,$t,Ve,on,Be):M.isDataTexture?L.texSubImage2D(L.TEXTURE_2D,Ht,Kt,Le,Yt,zt,Ve,on,Be.data):M.isCompressedTexture?L.compressedTexSubImage2D(L.TEXTURE_2D,Ht,Kt,Le,Be.width,Be.height,Ve,Be.data):L.texSubImage2D(L.TEXTURE_2D,Ht,Kt,Le,Yt,zt,Ve,on,Be);x.pixelStorei(L.UNPACK_ROW_LENGTH,vn),x.pixelStorei(L.UNPACK_IMAGE_HEIGHT,Te),x.pixelStorei(L.UNPACK_SKIP_PIXELS,Tn),x.pixelStorei(L.UNPACK_SKIP_ROWS,Un),x.pixelStorei(L.UNPACK_SKIP_IMAGES,qn),Ht===0&&D.generateMipmaps&&L.generateMipmap(Wt),x.unbindTexture()},this.initRenderTarget=function(M){X.get(M).__webglFramebuffer===void 0&&et.setupRenderTarget(M)},this.initTexture=function(M){M.isCubeTexture?et.setTextureCube(M,0):M.isData3DTexture?et.setTexture3D(M,0):M.isDataArrayTexture||M.isCompressedArrayTexture?et.setTexture2DArray(M,0):et.setTexture2D(M,0),x.unbindTexture()},this.resetState=function(){rt=0,j=0,pt=null,x.reset(),Nt.reset()},typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}get coordinateSystem(){return li}get outputColorSpace(){return this._outputColorSpace}set outputColorSpace(t){this._outputColorSpace=t;let e=this.getContext();e.drawingBufferColorSpace=Ae._getDrawingBufferColorSpace(t),e.unpackColorSpace=Ae._getUnpackColorSpace()}};var kf={openai:"#6aa8ff",anthropic:"#ff9a6a",zhipuai:"#63d69c",xai:"#b9a7ff",kimi:"#ff8fcf",google:"#ffd166",meta:"#7fd3ff",alibaba:"#ffab5c",deepseek:"#7d93ff",xiaomi:"#ff9a4a",minimax:"#ff6f99",tencent:"#6fe0d2"};var dx={openai:"us",anthropic:"us",xai:"us",google:"us",meta:"us",zhipuai:"cn",kimi:"cn",minimax:"cn",alibaba:"cn",deepseek:"cn",xiaomi:"cn",tencent:"cn",volcengine:"cn"},px={us:["falcon9","newGlenn","falconHeavy","vulcan"],cn:["cz2f","cz5","cz3b"]},Hf=new Set(["xai"]);function Vf(i,t,e){let n=[...i].sort((s,r)=>t(r)-t(s));return n.slice(0,3).find(s=>Hf.has(e(s)))??n[0]}var ph=i=>{let t=2166136261;for(let e=0;e<i.length;e++)t=Math.imul(t^i.charCodeAt(e),16777619);return t>>>0},mh=(i,t)=>{if(Hf.has(i))return"falcon9";let e=px[dx[i]==="cn"?"cn":"us"];return e[(ph(i)+t)%e.length]};function Gf(i,t,e=256){let n=i.image;if(!(n instanceof HTMLCanvasElement)||Math.max(n.width,n.height)<=e)return;let s=document.createElement("canvas"),r=e/Math.max(n.width,n.height);s.width=Math.max(1,Math.round(n.width*r)),s.height=Math.max(1,Math.round(n.height*r));let a=s.getContext("2d"),o=Object.getOwnPropertyDescriptor(xn.prototype,"needsUpdate").set,l=()=>{a.drawImage(n,0,0,s.width,s.height),o.call(i,!0)};i.image=s,Object.defineProperty(i,"needsUpdate",{configurable:!0,set(c){c&&(l(),t())}}),l()}function Wf(i){let t=new Set([i.outer,i.inner,i.hit,i.ring,...i.bOuter,...i.streaks]);for(let e of i.stdParts.concat(i.heavy)){let n=[];e.traverse(s=>{s.isGroup&&n.push(s)});for(let s of n){let r=new Map;for(let a of s.children){if(!a.isMesh||a.children.length||t.has(a))continue;let o=`${a.geometry.uuid}/${a.material.uuid}`;r.has(o)||r.set(o,[]),r.get(o).push(a)}for(let a of r.values()){if(a.length<2)continue;let o=a[0],l=new _a(o.geometry,o.material,a.length);a.forEach((c,h)=>{c.updateMatrix(),l.setMatrixAt(h,c.matrix),s.remove(c)}),l.computeBoundingSphere(),s.add(l)}}}}function gh(i,t=2e5){for(let e of["image/webp","image/jpeg"])for(let n of[.8,.65,.5,.35,.2,.1]){let s=i.toDataURL(e,n);if(!s.startsWith(`data:${e};`))break;if(s.length*2<=t)return s}return""}var Nr={name:"CopyShader",uniforms:{tDiffuse:{value:null},opacity:{value:1}},vertexShader:`

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


		}`};var Wn=class{constructor(){this.isPass=!0,this.enabled=!0,this.needsSwap=!0,this.clear=!1,this.renderToScreen=!1}setSize(){}render(){console.error("THREE.Pass: .render() must be implemented in derived pass.")}dispose(){}},mx=new cs(-1,1,1,-1,0,1),xh=class extends Ie{constructor(){super(),this.setAttribute("position",new pe([-1,3,0,-1,-1,0,3,-1,0],3)),this.setAttribute("uv",new pe([0,2,0,0,2,0],2))}},gx=new xh,ms=class{constructor(t){this._mesh=new Se(gx,t)}dispose(){this._mesh.geometry.dispose()}render(t){t.render(this._mesh,mx)}get material(){return this._mesh.material}set material(t){this._mesh.material=t}};var Cc=class extends Wn{constructor(t,e="tDiffuse"){super(),this.textureID=e,this.uniforms=null,this.material=null,t instanceof He?(this.uniforms=t.uniforms,this.material=t):t&&(this.uniforms=$i.clone(t.uniforms),this.material=new He({name:t.name!==void 0?t.name:"unspecified",defines:Object.assign({},t.defines),uniforms:this.uniforms,vertexShader:t.vertexShader,fragmentShader:t.fragmentShader})),this._fsQuad=new ms(this.material)}render(t,e,n){this.uniforms[this.textureID]&&(this.uniforms[this.textureID].value=n.texture),this._fsQuad.material=this.material,this.renderToScreen?(t.setRenderTarget(null),this._fsQuad.render(t)):(t.setRenderTarget(e),this.clear&&t.clear(t.autoClearColor,t.autoClearDepth,t.autoClearStencil),this._fsQuad.render(t))}dispose(){this.material.dispose(),this._fsQuad.dispose()}};var uo=class extends Wn{constructor(t,e){super(),this.scene=t,this.camera=e,this.clear=!0,this.needsSwap=!1,this.inverse=!1}render(t,e,n){let s=t.getContext(),r=t.state;r.buffers.color.setMask(!1),r.buffers.depth.setMask(!1),r.buffers.color.setLocked(!0),r.buffers.depth.setLocked(!0);let a,o;this.inverse?(a=0,o=1):(a=1,o=0),r.buffers.stencil.setTest(!0),r.buffers.stencil.setOp(s.REPLACE,s.REPLACE,s.REPLACE),r.buffers.stencil.setFunc(s.ALWAYS,a,4294967295),r.buffers.stencil.setClear(o),r.buffers.stencil.setLocked(!0),t.setRenderTarget(n),this.clear&&t.clear(),t.render(this.scene,this.camera),t.setRenderTarget(e),this.clear&&t.clear(),t.render(this.scene,this.camera),r.buffers.color.setLocked(!1),r.buffers.depth.setLocked(!1),r.buffers.color.setMask(!0),r.buffers.depth.setMask(!0),r.buffers.stencil.setLocked(!1),r.buffers.stencil.setFunc(s.EQUAL,1,4294967295),r.buffers.stencil.setOp(s.KEEP,s.KEEP,s.KEEP),r.buffers.stencil.setLocked(!0)}},Pc=class extends Wn{constructor(){super(),this.needsSwap=!1}render(t){t.state.buffers.stencil.setLocked(!1),t.state.buffers.stencil.setTest(!1)}};var Ic=class{constructor(t,e){if(this.renderer=t,this._pixelRatio=t.getPixelRatio(),e===void 0){let n=t.getSize(new ft);this._width=n.width,this._height=n.height,e=new tn(this._width*this._pixelRatio,this._height*this._pixelRatio,{type:un}),e.texture.name="EffectComposer.rt1"}else this._width=e.width,this._height=e.height;this.renderTarget1=e,this.renderTarget2=e.clone(),this.renderTarget2.texture.name="EffectComposer.rt2",this.writeBuffer=this.renderTarget1,this.readBuffer=this.renderTarget2,this.renderToScreen=!0,this.passes=[],this.copyPass=new Cc(Nr),this.copyPass.material.blending=Qn,this.timer=new Wa}swapBuffers(){let t=this.readBuffer;this.readBuffer=this.writeBuffer,this.writeBuffer=t}addPass(t){this.passes.push(t),t.setSize(this._width*this._pixelRatio,this._height*this._pixelRatio)}insertPass(t,e){this.passes.splice(e,0,t),t.setSize(this._width*this._pixelRatio,this._height*this._pixelRatio)}removePass(t){let e=this.passes.indexOf(t);e!==-1&&this.passes.splice(e,1)}isLastEnabledPass(t){for(let e=t+1;e<this.passes.length;e++)if(this.passes[e].enabled)return!1;return!0}render(t){this.timer.update(),t===void 0&&(t=this.timer.getDelta());let e=this.renderer.getRenderTarget(),n=!1;for(let s=0,r=this.passes.length;s<r;s++){let a=this.passes[s];if(a.enabled!==!1){if(a.renderToScreen=this.renderToScreen&&this.isLastEnabledPass(s),a.render(this.renderer,this.writeBuffer,this.readBuffer,t,n),a.needsSwap){if(n){let o=this.renderer.getContext(),l=this.renderer.state.buffers.stencil;l.setFunc(o.NOTEQUAL,1,4294967295),this.copyPass.render(this.renderer,this.writeBuffer,this.readBuffer,t),l.setFunc(o.EQUAL,1,4294967295)}this.swapBuffers()}uo!==void 0&&(a instanceof uo?n=!0:a instanceof Pc&&(n=!1))}}this.renderer.setRenderTarget(e)}reset(t){if(t===void 0){let e=this.renderer.getSize(new ft);this._pixelRatio=this.renderer.getPixelRatio(),this._width=e.width,this._height=e.height,t=this.renderTarget1.clone(),t.setSize(this._width*this._pixelRatio,this._height*this._pixelRatio)}this.renderTarget1.dispose(),this.renderTarget2.dispose(),this.renderTarget1=t,this.renderTarget2=t.clone(),this.writeBuffer=this.renderTarget1,this.readBuffer=this.renderTarget2}setSize(t,e){this._width=t,this._height=e;let n=this._width*this._pixelRatio,s=this._height*this._pixelRatio;this.renderTarget1.setSize(n,s),this.renderTarget2.setSize(n,s);for(let r=0;r<this.passes.length;r++)this.passes[r].setSize(n,s)}setPixelRatio(t){this._pixelRatio=t,this.setSize(this._width,this._height)}dispose(){this.renderTarget1.dispose(),this.renderTarget2.dispose(),this.copyPass.dispose()}};var Lc=class extends Wn{constructor(t,e,n=null,s=null,r=null){super(),this.scene=t,this.camera=e,this.overrideMaterial=n,this.clearColor=s,this.clearAlpha=r,this.clear=!0,this.clearDepth=!1,this.needsSwap=!1,this.isRenderPass=!0,this._oldClearColor=new se}render(t,e,n){let s=t.autoClear;t.autoClear=!1;let r,a;this.overrideMaterial!==null&&(a=this.scene.overrideMaterial,this.scene.overrideMaterial=this.overrideMaterial),this.clearColor!==null&&(t.getClearColor(this._oldClearColor),t.setClearColor(this.clearColor,t.getClearAlpha())),this.clearAlpha!==null&&(r=t.getClearAlpha(),t.setClearAlpha(this.clearAlpha)),this.clearDepth==!0&&t.clearDepth(),t.setRenderTarget(this.renderToScreen?null:n),this.clear===!0&&t.clear(t.autoClearColor,t.autoClearDepth,t.autoClearStencil),t.render(this.scene,this.camera),this.clearColor!==null&&t.setClearColor(this._oldClearColor),this.clearAlpha!==null&&t.setClearAlpha(r),this.overrideMaterial!==null&&(this.scene.overrideMaterial=a),t.autoClear=s}};var Xf={name:"LuminosityHighPassShader",uniforms:{tDiffuse:{value:null},luminosityThreshold:{value:1},smoothWidth:{value:1},defaultColor:{value:new se(0)},defaultOpacity:{value:0}},vertexShader:`

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

		}`};var Ur=class i extends Wn{constructor(t,e=1,n,s){super(),this.strength=e,this.radius=n,this.threshold=s,this.resolution=t!==void 0?new ft(t.x,t.y):new ft(256,256),this.clearColor=new se(0,0,0),this.needsSwap=!1,this.renderTargetsHorizontal=[],this.renderTargetsVertical=[],this.nMips=5;let r=Math.round(this.resolution.x/2),a=Math.round(this.resolution.y/2);this.renderTargetBright=new tn(r,a,{type:un,depthBuffer:!1}),this.renderTargetBright.texture.name="UnrealBloomPass.bright",this.renderTargetBright.texture.generateMipmaps=!1;for(let h=0;h<this.nMips;h++){let f=new tn(r,a,{type:un,depthBuffer:!1});f.texture.name="UnrealBloomPass.h"+h,f.texture.generateMipmaps=!1,this.renderTargetsHorizontal.push(f);let u=new tn(r,a,{type:un,depthBuffer:!1});u.texture.name="UnrealBloomPass.v"+h,u.texture.generateMipmaps=!1,this.renderTargetsVertical.push(u),r=Math.round(r/2),a=Math.round(a/2)}let o=Xf;this.highPassUniforms=$i.clone(o.uniforms),this.highPassUniforms.luminosityThreshold.value=s,this.highPassUniforms.smoothWidth.value=.01,this.materialHighPassFilter=new He({uniforms:this.highPassUniforms,vertexShader:o.vertexShader,fragmentShader:o.fragmentShader}),this.separableBlurMaterials=[];let l=[6,10,14,18,22];r=Math.round(this.resolution.x/2),a=Math.round(this.resolution.y/2);for(let h=0;h<this.nMips;h++)this.separableBlurMaterials.push(this._getSeparableBlurMaterial(l[h])),this.separableBlurMaterials[h].uniforms.invSize.value=new ft(1/r,1/a),r=Math.round(r/2),a=Math.round(a/2);this.compositeMaterial=this._getCompositeMaterial(this.nMips),this.compositeMaterial.uniforms.blurTexture1.value=this.renderTargetsVertical[0].texture,this.compositeMaterial.uniforms.blurTexture2.value=this.renderTargetsVertical[1].texture,this.compositeMaterial.uniforms.blurTexture3.value=this.renderTargetsVertical[2].texture,this.compositeMaterial.uniforms.blurTexture4.value=this.renderTargetsVertical[3].texture,this.compositeMaterial.uniforms.blurTexture5.value=this.renderTargetsVertical[4].texture,this.compositeMaterial.uniforms.bloomStrength.value=e,this.compositeMaterial.uniforms.bloomRadius.value=.1;let c=[1,.8,.6,.4,.2];this.compositeMaterial.uniforms.bloomFactors.value=c,this.bloomTintColors=[new P(1,1,1),new P(1,1,1),new P(1,1,1),new P(1,1,1),new P(1,1,1)],this.compositeMaterial.uniforms.bloomTintColors.value=this.bloomTintColors,this.copyUniforms=$i.clone(Nr.uniforms),this.blendMaterial=new He({uniforms:this.copyUniforms,vertexShader:Nr.vertexShader,fragmentShader:Nr.fragmentShader,premultipliedAlpha:!0,blending:hn,depthTest:!1,depthWrite:!1,transparent:!0}),this._oldClearColor=new se,this._oldClearAlpha=1,this._basic=new an,this._fsQuad=new ms(null)}dispose(){for(let t=0;t<this.renderTargetsHorizontal.length;t++)this.renderTargetsHorizontal[t].dispose();for(let t=0;t<this.renderTargetsVertical.length;t++)this.renderTargetsVertical[t].dispose();this.renderTargetBright.dispose();for(let t=0;t<this.separableBlurMaterials.length;t++)this.separableBlurMaterials[t].dispose();this.compositeMaterial.dispose(),this.blendMaterial.dispose(),this._basic.dispose(),this._fsQuad.dispose()}setSize(t,e){let n=Math.round(t/2),s=Math.round(e/2);this.renderTargetBright.setSize(n,s);for(let r=0;r<this.nMips;r++)this.renderTargetsHorizontal[r].setSize(n,s),this.renderTargetsVertical[r].setSize(n,s),this.separableBlurMaterials[r].uniforms.invSize.value=new ft(1/n,1/s),n=Math.round(n/2),s=Math.round(s/2)}render(t,e,n,s,r){t.getClearColor(this._oldClearColor),this._oldClearAlpha=t.getClearAlpha();let a=t.autoClear;t.autoClear=!1,t.setClearColor(this.clearColor,0),r&&t.state.buffers.stencil.setTest(!1),this.renderToScreen&&(this._fsQuad.material=this._basic,this._basic.map=n.texture,t.setRenderTarget(null),t.clear(),this._fsQuad.render(t)),this.highPassUniforms.tDiffuse.value=n.texture,this.highPassUniforms.luminosityThreshold.value=this.threshold,this._fsQuad.material=this.materialHighPassFilter,t.setRenderTarget(this.renderTargetBright),t.clear(),this._fsQuad.render(t);let o=this.renderTargetBright;for(let l=0;l<this.nMips;l++)this._fsQuad.material=this.separableBlurMaterials[l],this.separableBlurMaterials[l].uniforms.colorTexture.value=o.texture,this.separableBlurMaterials[l].uniforms.direction.value=i.BlurDirectionX,t.setRenderTarget(this.renderTargetsHorizontal[l]),t.clear(),this._fsQuad.render(t),this.separableBlurMaterials[l].uniforms.colorTexture.value=this.renderTargetsHorizontal[l].texture,this.separableBlurMaterials[l].uniforms.direction.value=i.BlurDirectionY,t.setRenderTarget(this.renderTargetsVertical[l]),t.clear(),this._fsQuad.render(t),o=this.renderTargetsVertical[l];this._fsQuad.material=this.compositeMaterial,this.compositeMaterial.uniforms.bloomStrength.value=this.strength,this.compositeMaterial.uniforms.bloomRadius.value=this.radius,this.compositeMaterial.uniforms.bloomTintColors.value=this.bloomTintColors,t.setRenderTarget(this.renderTargetsHorizontal[0]),t.clear(),this._fsQuad.render(t),this._fsQuad.material=this.blendMaterial,this.copyUniforms.tDiffuse.value=this.renderTargetsHorizontal[0].texture,r&&t.state.buffers.stencil.setTest(!0),this.renderToScreen?(t.setRenderTarget(null),this._fsQuad.render(t)):(t.setRenderTarget(n),this._fsQuad.render(t)),t.setClearColor(this._oldClearColor,this._oldClearAlpha),t.autoClear=a}_getSeparableBlurMaterial(t){let e=[],n=t/3;for(let a=0;a<t;a++)e.push(.39894*Math.exp(-.5*a*a/(n*n))/n);let s=[],r=[];for(let a=1;a<t;a+=2){let o=e[a],l=a+1<t?e[a+1]:0,c=o+l;s.push((a*o+(a+1)*l)/c),r.push(c)}return new He({defines:{KERNEL_PAIRS:s.length},uniforms:{colorTexture:{value:null},invSize:{value:new ft(.5,.5)},direction:{value:new ft(.5,.5)},centerWeight:{value:e[0]},gaussianOffsets:{value:s},gaussianWeights:{value:r}},vertexShader:`

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

				}`})}_getCompositeMaterial(t){return new He({defines:{NUM_MIPS:t},uniforms:{blurTexture1:{value:null},blurTexture2:{value:null},blurTexture3:{value:null},blurTexture4:{value:null},blurTexture5:{value:null},bloomStrength:{value:1},bloomFactors:{value:null},bloomTintColors:{value:null},bloomRadius:{value:0}},vertexShader:`

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

				}`})}};Ur.BlurDirectionX=new ft(1,0);Ur.BlurDirectionY=new ft(0,1);var fo={name:"OutputShader",uniforms:{tDiffuse:{value:null},toneMappingExposure:{value:1}},vertexShader:`
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

		}`};var Dc=class extends Wn{constructor(){super(),this.isOutputPass=!0,this.uniforms=$i.clone(fo.uniforms),this.material=new Sr({name:fo.name,uniforms:this.uniforms,vertexShader:fo.vertexShader,fragmentShader:fo.fragmentShader}),this._fsQuad=new ms(this.material),this._outputColorSpace=null,this._toneMapping=null}render(t,e,n){this.uniforms.tDiffuse.value=n.texture,this.uniforms.toneMappingExposure.value=t.toneMappingExposure,(this._outputColorSpace!==t.outputColorSpace||this._toneMapping!==t.toneMapping)&&(this._outputColorSpace=t.outputColorSpace,this._toneMapping=t.toneMapping,this.material.defines={},Ae.getTransfer(this._outputColorSpace)===Fe&&(this.material.defines.SRGB_TRANSFER=""),this._toneMapping===Ya?this.material.defines.LINEAR_TONE_MAPPING="":this._toneMapping===$a?this.material.defines.REINHARD_TONE_MAPPING="":this._toneMapping===Za?this.material.defines.CINEON_TONE_MAPPING="":this._toneMapping===Rs?this.material.defines.ACES_FILMIC_TONE_MAPPING="":this._toneMapping===Ka?this.material.defines.AGX_TONE_MAPPING="":this._toneMapping===ja?this.material.defines.NEUTRAL_TONE_MAPPING="":this._toneMapping===Ja&&(this.material.defines.CUSTOM_TONE_MAPPING=""),this.material.needsUpdate=!0),this.renderToScreen===!0?(t.setRenderTarget(null),this._fsQuad.render(t)):(t.setRenderTarget(e),this.clear&&t.clear(t.autoClearColor,t.autoClearDepth,t.autoClearStencil),this._fsQuad.render(t))}dispose(){this.material.dispose(),this._fsQuad.dispose()}};function qf(i){let e=new P(0,-55,-8),n=new P(-.93,.07,-.36).normalize(),s=`vec3 m289(vec3 x){return x-floor(x*(1./289.))*289.;} vec4 m289(vec4 x){return x-floor(x*(1./289.))*289.;} vec4 perm(vec4 x){return m289(((x*34.)+1.)*x);} vec4 tis(vec4 r){return 1.79284291400159-.85373472095314*r;}
float snoise(vec3 v){ const vec2 C=vec2(1./6.,1./3.); const vec4 D=vec4(0.,.5,1.,2.); vec3 i=floor(v+dot(v,C.yyy)); vec3 x0=v-i+dot(i,C.xxx); vec3 g=step(x0.yzx,x0.xyz); vec3 l=1.-g; vec3 i1=min(g.xyz,l.zxy); vec3 i2=max(g.xyz,l.zxy); vec3 x1=x0-i1+C.xxx; vec3 x2=x0-i2+C.yyy; vec3 x3=x0-D.yyy; i=m289(i);
 vec4 p=perm(perm(perm(i.z+vec4(0.,i1.z,i2.z,1.))+i.y+vec4(0.,i1.y,i2.y,1.))+i.x+vec4(0.,i1.x,i2.x,1.)); float n_=.142857142857; vec3 ns=n_*D.wyz-D.xzx; vec4 j=p-49.*floor(p*ns.z*ns.z); vec4 x_=floor(j*ns.z); vec4 y_=floor(j-7.*x_); vec4 x=x_*ns.x+ns.yyyy; vec4 y=y_*ns.x+ns.yyyy; vec4 h=1.-abs(x)-abs(y); vec4 b0=vec4(x.xy,y.xy); vec4 b1=vec4(x.zw,y.zw); vec4 s0=floor(b0)*2.+1.; vec4 s1=floor(b1)*2.+1.; vec4 sh=-step(h,vec4(0.));
 vec4 a0=b0.xzyw+s0.xzyw*sh.xxyy; vec4 a1=b1.xzyw+s1.xzyw*sh.zzww; vec3 p0=vec3(a0.xy,h.x); vec3 p1=vec3(a0.zw,h.y); vec3 p2=vec3(a1.xy,h.z); vec3 p3=vec3(a1.zw,h.w); vec4 nr=tis(vec4(dot(p0,p0),dot(p1,p1),dot(p2,p2),dot(p3,p3))); p0*=nr.x; p1*=nr.y; p2*=nr.z; p3*=nr.w;
 vec4 m=max(.6-vec4(dot(x0,x0),dot(x1,x1),dot(x2,x2),dot(x3,x3)),0.); m=m*m; return 42.*dot(m*m,vec4(dot(p0,x0),dot(p1,x1),dot(p2,x2),dot(p3,x3))); }
float fbm6(vec3 p){ float s=0., a=.5; for(int i=0;i<6;i++){ s+=a*snoise(p); p=p*2.03+vec3(1.7,9.2,3.1); a*=.5; } return s; }
float fbm4(vec3 p){ float s=0., a=.5; for(int i=0;i<4;i++){ s+=a*snoise(p); p=p*2.1+vec3(4.1,2.3,7.7); a*=.5; } return s; }`,r=new Qe;r.position.copy(e),i.add(r);let a=new He({uniforms:{sun:{value:n},t:{value:0}},vertexShader:"varying vec3 vP; varying vec3 vWN; varying vec3 vWP; void main(){ vP=position; vWN=normalize(mat3(modelMatrix)*normal); vec4 w=modelMatrix*vec4(position,1.); vWP=w.xyz; gl_Position=projectionMatrix*viewMatrix*w; }",fragmentShader:`uniform vec3 sun; uniform float t; varying vec3 vP; varying vec3 vWN; varying vec3 vWP;
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
}`}),o=new Se(new jn(46,128,96),a);r.add(o);let l=new Se(new jn(46*1.028,96,64),new He({side:bn,transparent:!0,depthWrite:!1,blending:hn,uniforms:{sun:{value:n}},vertexShader:"varying vec3 vN; varying vec3 wN; void main(){ vN=normalize(normalMatrix*normal); wN=normalize(mat3(modelMatrix)*normal); gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",fragmentShader:"uniform vec3 sun; varying vec3 vN; varying vec3 wN; void main(){ float i=pow(max(0.,.76-dot(vN,vec3(0.,0.,1.))),3.2); float s=.12+1.6*smoothstep(-.35,.55,dot(wN,sun)); vec3 c=mix(vec3(.2,.5,1.),vec3(.7,.88,1.),smoothstep(.3,.9,dot(wN,sun))); gl_FragColor=vec4(c*i*s*1.25,1.); }"}));return r.add(l),{update(c){a.uniforms.t.value=c,o.rotation.y=c*.002},dispose(){r.traverse(c=>{c.geometry?.dispose(),c.material?.dispose()}),i.remove(r)}}}var pi=i=>i,xx={openai:pi({colour:"#ececec",base:"#f3f3f1",ink:"#111214",cap:"#111214",trim:["#111214"],pattern:"lattice",glyph:"openai-white.svg"}),anthropic:pi({colour:"#d97757",base:"#f0eee6",ink:"#d97757",cap:"#d97757",trim:["#191919"],pattern:"split",glyph:"claude.svg"}),alibaba:pi({colour:"#ff6a00",base:"#ff6a00",ink:"#ffffff",cap:"#ffffff",trim:["#6950ef"],pattern:"diagonal",glyph:"alibaba.svg"}),xiaomi:pi({colour:"#ff6900",base:"#ffffff",ink:"#ff6900",cap:"#ff6900",trim:["#ff6900","#ffffff"],pattern:"rings",glyph:"xiaomi.svg"}),google:pi({colour:"#4285f4",base:"#ffffff",ink:"#4285f4",inks:["#4285f4","#ea4335","#fbbc05","#34a853"],cap:"#4285f4",trim:["#4285f4","#ea4335","#fbbc05","#34a853"],pattern:"lattice",glyph:"gemini.svg"}),kimi:pi({colour:"#007cff",base:"#007cff",ink:"#ffffff",cap:"#121212",trim:["#121212"],pattern:"rings",glyph:"kimi-white.svg"}),minimax:pi({colour:"#e73562",base:"#e73562",ink:"#ffffff",cap:"#ffffff",trim:["#ffffff"],pattern:"rings",glyph:"minimax.svg"}),zhipuai:pi({colour:"#b9c2cc",base:"#1a1d21",ink:"#ffffff",cap:"#ffffff",trim:["#ffffff","#1a1d21"],pattern:"lattice",glyph:"zai-white.svg"}),xai:pi({colour:"#8f96a0",base:"#0b0b0c",ink:"#f2f2f2",cap:"#0b0b0c",trim:["#f2f2f2"],pattern:"diagonal",glyph:"x-white.svg"}),meta:pi({colour:"#0467df",base:"#ffffff",ink:"#0467df",cap:"#0467df",trim:["#0467df"],pattern:"diagonal",glyph:"meta.svg"}),deepseek:pi({colour:"#4d6bfe",base:"#4d6bfe",ink:"#ffffff",cap:"#ffffff",trim:["#ffffff"],pattern:"diagonal",glyph:"deepseek.svg"})};function Nc(i,t="#b8b0a8"){return xx[i]??{colour:t,base:t,ink:"#ffffff",cap:"#ffffff",trim:["#ffffff"],pattern:"rings",glyph:null}}function Uc(i,t=!1){let e=i[0].index!==null,n=new Set(Object.keys(i[0].attributes)),s=new Set(Object.keys(i[0].morphAttributes)),r={},a={},o=i[0].morphTargetsRelative,l=new Ie,c=0;for(let h=0;h<i.length;++h){let f=i[h],u=0;if(e!==(f.index!==null))return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". All geometries must have compatible attributes; make sure index attribute exists among all geometries, or in none of them."),null;for(let d in f.attributes){if(!n.has(d))return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+'. All geometries must have compatible attributes; make sure "'+d+'" attribute exists among all geometries, or in none of them.'),null;r[d]===void 0&&(r[d]=[]),r[d].push(f.attributes[d]),u++}if(u!==n.size)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". Make sure all geometries have the same number of attributes."),null;if(o!==f.morphTargetsRelative)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". .morphTargetsRelative must be consistent throughout all geometries."),null;for(let d in f.morphAttributes){if(!s.has(d))return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+".  .morphAttributes must be consistent throughout all geometries."),null;a[d]===void 0&&(a[d]=[]),a[d].push(f.morphAttributes[d])}if(t){let d;if(e)d=f.index.count;else if(f.attributes.position!==void 0)d=f.attributes.position.count;else return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". The geometry must have either an index or a position attribute"),null;l.addGroup(c,d,h),c+=d}}if(e){let h=0,f=[];for(let u=0;u<i.length;++u){let d=i[u].index;for(let g=0;g<d.count;++g)f.push(d.getX(g)+h);h+=i[u].attributes.position.count}l.setIndex(f)}for(let h in r){let f=Yf(r[h]);if(!f)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed while trying to merge the "+h+" attribute."),null;l.setAttribute(h,f)}for(let h in a){let f=a[h][0].length;if(f!==0){l.morphAttributes=l.morphAttributes||{},l.morphAttributes[h]=[];for(let u=0;u<f;++u){let d=[];for(let _=0;_<a[h].length;++_)d.push(a[h][_][u]);let g=Yf(d);if(!g)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed while trying to merge the "+h+" morphAttribute."),null;l.morphAttributes[h].push(g)}}}return l}function Yf(i){let t,e,n,s=-1,r=0;for(let c=0;c<i.length;++c){let h=i[c];if(t===void 0&&(t=h.array.constructor),t!==h.array.constructor)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.array must be of consistent array types across matching attributes."),null;if(e===void 0&&(e=h.itemSize),e!==h.itemSize)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.itemSize must be consistent across matching attributes."),null;if(n===void 0&&(n=h.normalized),n!==h.normalized)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.normalized must be consistent across matching attributes."),null;if(s===-1&&(s=h.gpuType),s!==h.gpuType)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.gpuType must be consistent across matching attributes."),null;r+=h.count*e}let a=new t(r),o=new sn(a,e,n),l=0;for(let c=0;c<i.length;++c){let h=i[c];if(h.isInterleavedBufferAttribute){let f=l/e;for(let u=0,d=h.count;u<d;u++)for(let g=0;g<e;g++){let _=h.getComponent(u,g);o.setComponent(u+f,g,_)}}else a.set(h.array,l);l+=h.count*e}return s!==void 0&&(o.gpuType=s),o}var po={falcon9:{id:"falcon9",shape:"falcon9",atlas:{w:852,h:1024,cap:[.993,.9941,.9977,.998]},parts:[{name:"core",uv:[0,0,.9014,1],top:1.6,end:-1.1295,profile:[[1.6,.018],[1.5886,.0552],[1.5771,.0765],[1.5657,.0934],[1.5543,.1083],[1.5429,.1218],[1.5314,.1343],[1.52,.1459],[1.5086,.1566],[1.4971,.1664],[1.4857,.1756],[1.4743,.1839],[1.4629,.1914],[1.4514,.1981],[1.44,.2041],[1.4286,.2094],[1.4171,.2139],[1.4057,.2178],[1.3943,.2211],[1.3829,.2238],[1.3714,.226],[1.36,.2275],[1.3486,.2282],[1.3371,.2287],[1.3257,.229],[1.3143,.2291],[1.3029,.2291],[1.2914,.229],[1.28,.2289],[1.2686,.2287],[1.2571,.2286],[1.2457,.2284],[1.2343,.2282],[1.2229,.2281],[1.2114,.2279],[1.2,.2278],[1.1886,.2278],[1.1771,.2281],[1.1657,.2285],[1.1543,.2284],[1.1429,.2281],[1.1314,.228],[1.12,.228],[1.1086,.228],[1.0971,.2279],[1.0857,.2277],[1.0743,.2275],[1.0629,.2274],[1.0514,.2271],[1.04,.2264],[1.0286,.2247],[1.0171,.2213],[1.0057,.216],[.9943,.2087],[.9829,.2001],[.9714,.1909],[.96,.1818],[.9486,.1735],[.9371,.1672],[.9257,.1629],[.9143,.1598],[.9029,.1574],[.8914,.1563],[.88,.1559],[.8686,.1557],[.8571,.1557],[.8457,.156],[.8343,.1564],[.8229,.1567],[.8114,.1568],[.8,.1567],[.7886,.1566],[.7771,.1567],[.7657,.157],[.7543,.1575],[.7429,.1576],[.7314,.1576],[.72,.1575],[.7086,.1574],[.6971,.1574],[.6857,.1576],[.6743,.1577],[.6629,.1575],[.6514,.157],[.64,.1568],[.6286,.1566],[.6171,.1565],[.6057,.1564],[.5943,.1564],[.5829,.1568],[.5714,.1589],[.56,.1642],[.5486,.1742],[.5371,.1896],[.5257,.2095],[.5143,.2305],[.5029,.2478],[.4914,.2566],[.48,.2521],[.4686,.232],[.4571,.2026],[.4457,.1795],[.4343,.1697],[.4229,.1675],[.4114,.1671],[.4,.1666],[.3886,.1659],[.3771,.1655],[.3657,.1652],[.3543,.1651],[.3429,.165],[.3314,.1649],[.32,.1648],[.3086,.1646],[.2971,.1645],[.2857,.1644],[.2743,.1643],[.2629,.1642],[.2514,.164],[.24,.164],[.2286,.1638],[.2171,.1637],[.2057,.1636],[.1943,.1636],[.1829,.1639],[.1714,.1645],[.16,.1653],[.1486,.1659],[.1371,.166],[.1257,.1659],[.1143,.1658],[.1029,.1657],[.0914,.1656],[.08,.1655],[.0686,.1654],[.0571,.1653],[.0457,.1651],[.0343,.165],[.0229,.1649],[.0114,.1648],[0,.1647],[-.0114,.1646],[-.0229,.1645],[-.0343,.1644],[-.0457,.1642],[-.0571,.1641],[-.0686,.164],[-.08,.164],[-.0914,.164],[-.1029,.1642],[-.1143,.1645],[-.1257,.1645],[-.1371,.1643],[-.1486,.1643],[-.16,.1646],[-.1714,.165],[-.1829,.1655],[-.1943,.1657],[-.2057,.1657],[-.2171,.1656],[-.2286,.1655],[-.24,.1654],[-.2514,.1653],[-.2629,.1652],[-.2743,.1651],[-.2857,.165],[-.2971,.1649],[-.3086,.1647],[-.32,.1646],[-.3314,.1645],[-.3429,.1644],[-.3543,.1643],[-.3657,.1644],[-.3771,.165],[-.3886,.1666],[-.4,.1684],[-.4114,.1694],[-.4229,.1696],[-.4343,.1696],[-.4457,.1695],[-.4571,.1694],[-.4686,.1692],[-.48,.1692],[-.4914,.169],[-.5029,.1689],[-.5143,.1688],[-.5257,.1687],[-.5371,.1686],[-.5486,.1685],[-.56,.1683],[-.5714,.1682],[-.5829,.1681],[-.5943,.168],[-.6057,.1679],[-.6171,.1678],[-.6286,.1677],[-.64,.1676],[-.6514,.1675],[-.6629,.1673],[-.6743,.1673],[-.6857,.1671],[-.6971,.167],[-.7086,.1669],[-.72,.1668],[-.7314,.1667],[-.7429,.1666],[-.7543,.1665],[-.7657,.1664],[-.7771,.1663],[-.7886,.1661],[-.8,.166],[-.8114,.1659],[-.8229,.1658],[-.8343,.1657],[-.8457,.1656],[-.8571,.1655],[-.8686,.1654],[-.88,.1653],[-.8914,.1652],[-.9029,.1651],[-.9143,.165],[-.9257,.1649],[-.9371,.1647],[-.9486,.1646],[-.96,.1645],[-.9714,.1644],[-.9829,.1643],[-.9943,.1642],[-1.0057,.1641],[-1.0171,.164],[-1.0286,.1639],[-1.04,.1638],[-1.0514,.1637],[-1.0629,.1636],[-1.0743,.1635],[-1.0857,.1634],[-1.0971,.1633],[-1.1086,.1631],[-1.12,.1631],[-1.1276,.163]],at:[[0,0]],fins:[{side:-1,uv:[.9014,.6426,.9894,1],x0:-.2226,x1:0,y0:-.4381,y1:-1.1352,outline:[[-.4381,.1721,.1662],[-.4438,.1751,.1662],[-.4495,.1751,.1662],[-.4552,.1751,.1662],[-.461,.1781,.1662],[-.4667,.1781,.1662],[-.4724,.1781,.1662],[-.4781,.1781,.1662],[-.4838,.181,.1662],[-.4895,.181,.1662],[-.4952,.181,.1662],[-.501,.181,.1662],[-.5067,.181,.1662],[-.5124,.184,.1662],[-.5181,.184,.1662],[-.5238,.184,.1662],[-.5295,.184,.1662],[-.5352,.184,.1662],[-.541,.187,.1662],[-.5467,.187,.1662],[-.5524,.187,.1662],[-.5581,.1899,.1662],[-.5638,.1899,.1662],[-.5695,.1899,.1662],[-.5752,.1899,.1662],[-.581,.1899,.1662],[-.5867,.187,.1662],[-.5924,.1899,.1662],[-.5981,.1899,.1662],[-.6038,.1899,.1662],[-.6095,.1899,.1662],[-.6152,.1899,.1662],[-.621,.1899,.1662],[-.6267,.1899,.1662],[-.6324,.1899,.1662],[-.6381,.1899,.1662],[-.6438,.1899,.1662],[-.6495,.1899,.1662],[-.6552,.1899,.1662],[-.661,.1929,.1662],[-.6667,.1929,.1662],[-.6724,.1929,.1662],[-.6781,.1929,.1662],[-.6838,.1929,.1662],[-.6895,.1929,.1662],[-.6952,.1929,.1662],[-.701,.1929,.1662],[-.7067,.1959,.1662],[-.7124,.1959,.1662],[-.7181,.1959,.1662],[-.7238,.1959,.1662],[-.7295,.1959,.1662],[-.7352,.1959,.1662],[-.741,.1959,.1662],[-.7467,.1959,.1662],[-.7524,.1959,.1662],[-.7581,.1988,.1662],[-.7638,.1988,.1662],[-.7695,.1988,.1662],[-.7752,.1988,.1662],[-.781,.1988,.1662],[-.7867,.1988,.1662],[-.7924,.1988,.1662],[-.7981,.1988,.1662],[-.8038,.2018,.1662],[-.8095,.2018,.1662],[-.8152,.2018,.1662],[-.821,.2018,.1662],[-.8267,.2018,.1662],[-.8324,.2018,.1662],[-.8381,.2018,.1662],[-.8438,.2018,.1662],[-.8495,.2018,.1662],[-.8552,.2018,.1662],[-.861,.2047,.1662],[-.8667,.2047,.1662],[-.8724,.2047,.1662],[-.8781,.2047,.1662],[-.8838,.2047,.1662],[-.8895,.2047,.1662],[-.8952,.2047,.1662],[-.901,.2077,.1662],[-.9067,.2077,.1662],[-.9124,.2077,.1662],[-.9181,.2077,.1662],[-.9238,.2077,.1662],[-.9295,.2077,.1662],[-.9352,.2077,.1662],[-.941,.2077,.1662],[-.9467,.2107,.1662],[-.9524,.2107,.1662],[-.9581,.2107,.1662],[-.9638,.2107,.1662],[-.9695,.2107,.1662],[-.9752,.2107,.1662],[-.981,.2107,.1662],[-.9867,.2136,.1662],[-.9924,.2136,.1662],[-.9981,.2136,.1662],[-1.0038,.2136,.1662],[-1.0095,.2136,.1662],[-1.0152,.2136,.1662],[-1.021,.2166,.1662],[-1.0267,.2196,.1662],[-1.0324,.2196,.1662],[-1.0381,.2196,.1662],[-1.0438,.2107,.1662],[-1.0495,.2047,.1662],[-1.0552,.1988,.1662],[-1.061,.1988,.1662],[-1.0667,.1988,.1662],[-1.0724,.2018,.1662],[-1.0781,.2018,.1662],[-1.0838,.2018,.1662],[-1.0895,.2018,.1662],[-1.0952,.2018,.1662],[-1.101,.2047,.1662],[-1.1067,.2047,.1662],[-1.1124,.2047,.1662],[-1.1181,.2047,.1662],[-1.1238,.1988,.1662],[-1.1295,.1899,.1662],[-1.1333,.184,.1662]]},{side:1,uv:[.9014,.2832,.9906,.6406],x0:0,x1:.2255,y0:-.4381,y1:-1.1352,outline:[[-.4381,.1721,.1662],[-.4438,.1751,.1662],[-.4495,.1751,.1662],[-.4552,.1751,.1662],[-.461,.1781,.1662],[-.4667,.1781,.1662],[-.4724,.1781,.1662],[-.4781,.1781,.1662],[-.4838,.181,.1662],[-.4895,.181,.1662],[-.4952,.181,.1662],[-.501,.181,.1662],[-.5067,.184,.1662],[-.5124,.184,.1662],[-.5181,.184,.1662],[-.5238,.184,.1662],[-.5295,.184,.1662],[-.5352,.187,.1662],[-.541,.187,.1662],[-.5467,.187,.1662],[-.5524,.1899,.1662],[-.5581,.1929,.1662],[-.5638,.1929,.1662],[-.5695,.1929,.1662],[-.5752,.1899,.1662],[-.581,.1899,.1662],[-.5867,.1899,.1662],[-.5924,.1899,.1662],[-.5981,.1899,.1662],[-.6038,.1899,.1662],[-.6095,.1929,.1662],[-.6152,.1929,.1662],[-.621,.1929,.1662],[-.6267,.1929,.1662],[-.6324,.1929,.1662],[-.6381,.1929,.1662],[-.6438,.1929,.1662],[-.6495,.1929,.1662],[-.6552,.1929,.1662],[-.661,.1929,.1662],[-.6667,.1959,.1662],[-.6724,.1959,.1662],[-.6781,.1959,.1662],[-.6838,.1959,.1662],[-.6895,.1959,.1662],[-.6952,.1959,.1662],[-.701,.1959,.1662],[-.7067,.1959,.1662],[-.7124,.1959,.1662],[-.7181,.1959,.1662],[-.7238,.1988,.1662],[-.7295,.1988,.1662],[-.7352,.1988,.1662],[-.741,.1988,.1662],[-.7467,.1988,.1662],[-.7524,.1988,.1662],[-.7581,.1988,.1662],[-.7638,.2018,.1662],[-.7695,.2018,.1662],[-.7752,.2018,.1662],[-.781,.2018,.1662],[-.7867,.2018,.1662],[-.7924,.2018,.1662],[-.7981,.2018,.1662],[-.8038,.2018,.1662],[-.8095,.2047,.1662],[-.8152,.2047,.1662],[-.821,.2047,.1662],[-.8267,.2047,.1662],[-.8324,.2047,.1662],[-.8381,.2047,.1662],[-.8438,.2047,.1662],[-.8495,.2077,.1662],[-.8552,.2077,.1662],[-.861,.2077,.1662],[-.8667,.2077,.1662],[-.8724,.2077,.1662],[-.8781,.2077,.1662],[-.8838,.2077,.1662],[-.8895,.2107,.1662],[-.8952,.2107,.1662],[-.901,.2107,.1662],[-.9067,.2107,.1662],[-.9124,.2107,.1662],[-.9181,.2107,.1662],[-.9238,.2107,.1662],[-.9295,.2136,.1662],[-.9352,.2136,.1662],[-.941,.2136,.1662],[-.9467,.2136,.1662],[-.9524,.2136,.1662],[-.9581,.2136,.1662],[-.9638,.2136,.1662],[-.9695,.2166,.1662],[-.9752,.2166,.1662],[-.981,.2166,.1662],[-.9867,.2166,.1662],[-.9924,.2166,.1662],[-.9981,.2196,.1662],[-1.0038,.2196,.1662],[-1.0095,.2196,.1662],[-1.0152,.2225,.1662],[-1.021,.2225,.1662],[-1.0267,.2225,.1662],[-1.0324,.2225,.1662],[-1.0381,.2225,.1662],[-1.0438,.2166,.1662],[-1.0495,.2107,.1662],[-1.0552,.2018,.1662],[-1.061,.2018,.1662],[-1.0667,.2018,.1662],[-1.0724,.2047,.1662],[-1.0781,.2047,.1662],[-1.0838,.2047,.1662],[-1.0895,.2047,.1662],[-1.0952,.2047,.1662],[-1.101,.2047,.1662],[-1.1067,.2047,.1662],[-1.1124,.2047,.1662],[-1.1181,.2047,.1662],[-1.1238,.2047,.1662],[-1.1295,.1959,.1662],[-1.1333,.1899,.1662]]}],finsAround:4,finsFrom:null,engines:{ring:8,centre:!0,f:.34,colour:[32,26,19],profile:[[-1.1295,.1892],[-1.1333,.1833],[-1.1371,.1803],[-1.141,.1818],[-1.1448,.1817],[-1.1486,.1846],[-1.1524,.186],[-1.1562,.1874],[-1.16,.1888],[-1.1638,.1902],[-1.1676,.1917],[-1.1714,.1931],[-1.1752,.1945],[-1.179,.1959],[-1.1829,.1973],[-1.1867,.1987],[-1.1905,.2001],[-1.1943,.2001],[-1.1981,.2015],[-1.2019,.2029],[-1.2057,.2028],[-1.2095,.1984],[-1.2133,.1854],[-1.2171,.1506],[-1.221,.1505],[-1.2248,.1476],[-1.2286,.1302],[-1.2324,.055],[-1.2362,.0521],[-1.24,.0405]]}}],badge:{y:.9137,d:.2397,r:.1598},band:[.7607,.7796],head:{top:1.6,cut:1.0666,mean:.7703,r:.2696}},falconHeavy:{id:"falcon-heavy",shape:"falconHeavy",atlas:{w:1236,h:1024,cap:[.9951,.9941,.9984,.998]},parts:[{name:"core",uv:[0,0,.6214,1],top:1.6,end:-1.1103,profile:[[1.6,.0148],[1.5884,.0342],[1.5768,.0518],[1.5652,.0675],[1.5535,.0822],[1.5419,.0952],[1.5303,.1071],[1.5187,.1182],[1.5071,.1283],[1.4955,.1375],[1.4838,.1459],[1.4722,.1535],[1.4606,.1604],[1.449,.1666],[1.4374,.1721],[1.4258,.1771],[1.4142,.1814],[1.4025,.1851],[1.3909,.1882],[1.3793,.1907],[1.3677,.1927],[1.3561,.1942],[1.3445,.1952],[1.3328,.1959],[1.3212,.1961],[1.3096,.1961],[1.298,.196],[1.2864,.1959],[1.2748,.1958],[1.2631,.1957],[1.2515,.1956],[1.2399,.1955],[1.2283,.1955],[1.2167,.1958],[1.2051,.1962],[1.1935,.1964],[1.1818,.1964],[1.1702,.1963],[1.1586,.1962],[1.147,.1961],[1.1354,.196],[1.1238,.1959],[1.1121,.1958],[1.1005,.1957],[1.0889,.1956],[1.0773,.1955],[1.0657,.1954],[1.0541,.1953],[1.0425,.1952],[1.0308,.1951],[1.0192,.195],[1.0076,.1948],[.996,.1946],[.9844,.1938],[.9728,.192],[.9611,.1887],[.9495,.1842],[.9379,.1788],[.9263,.1731],[.9147,.1673],[.9031,.1617],[.8915,.1567],[.8798,.1525],[.8682,.1495],[.8566,.1479],[.845,.1473],[.8334,.1472],[.8218,.1471],[.8101,.147],[.7985,.1469],[.7869,.1469],[.7753,.1468],[.7637,.1467],[.7521,.1467],[.7404,.1468],[.7288,.1469],[.7172,.1471],[.7056,.1473],[.694,.1476],[.6824,.1479],[.6708,.1483],[.6591,.1487],[.6475,.1491],[.6359,.1496],[.6243,.1501],[.6127,.1507],[.6011,.1513],[.5894,.1519],[.5778,.1526],[.5662,.1533],[.5546,.1539],[.543,.1546],[.5314,.1554],[.5198,.1561],[.5081,.1568],[.4965,.1575],[.4849,.1583],[.4733,.159],[.4617,.1598],[.4501,.1605],[.4384,.1613],[.4268,.162],[.4152,.1627],[.4036,.1634],[.392,.164],[.3804,.1646],[.3688,.1651],[.3571,.1655],[.3455,.1659],[.3339,.1663],[.3223,.1664],[.3107,.1663],[.2991,.1662],[.2874,.1662],[.2758,.1661],[.2642,.166],[.2526,.1659],[.241,.1658],[.2294,.1657],[.2178,.1657],[.2061,.1656],[.1945,.1655],[.1829,.1654],[.1713,.1653],[.1597,.1653],[.1481,.1652],[.1364,.1651],[.1248,.1651],[.1132,.1653],[.1016,.1657],[.09,.1657],[.0784,.1655],[.0667,.1653],[.0551,.1654],[.0435,.1657],[.0319,.1658],[.0203,.1659],[.0087,.1663],[-.0029,.1666],[-.0146,.1667],[-.0262,.1667],[-.0378,.1666],[-.0494,.1665],[-.061,.1664],[-.0726,.1664],[-.0843,.1663],[-.0959,.1662],[-.1075,.1661],[-.1191,.166],[-.1307,.1659],[-.1423,.1659],[-.1539,.1658],[-.1656,.1657],[-.1772,.1656],[-.1888,.1656],[-.2004,.1657],[-.212,.1661],[-.2236,.1664],[-.2353,.1665],[-.2469,.1665],[-.2585,.1664],[-.2701,.1663],[-.2817,.1662],[-.2933,.1662],[-.3049,.1661],[-.3166,.166],[-.3282,.1659],[-.3398,.1658],[-.3514,.1657],[-.363,.1657],[-.3746,.1656],[-.3863,.1655],[-.3979,.1654],[-.4095,.1653],[-.4211,.1653],[-.4327,.1652],[-.4443,.1651],[-.456,.1651],[-.4676,.1653],[-.4792,.1656],[-.4908,.1659],[-.5024,.166],[-.514,.166],[-.5256,.1659],[-.5373,.1658],[-.5489,.1657],[-.5605,.1656],[-.5721,.1656],[-.5837,.1655],[-.5953,.1654],[-.607,.1653],[-.6186,.1652],[-.6302,.1651],[-.6418,.1651],[-.6534,.165],[-.665,.1649],[-.6766,.1648],[-.6883,.1648],[-.6999,.1647],[-.7115,.1646],[-.7231,.1645],[-.7347,.1644],[-.7463,.1643],[-.758,.1643],[-.7696,.1642],[-.7812,.1641],[-.7928,.164],[-.8044,.1639],[-.816,.1639],[-.8276,.1638],[-.8393,.1637],[-.8509,.1636],[-.8625,.1636],[-.8741,.1635],[-.8857,.1634],[-.8973,.1633],[-.909,.1632],[-.9206,.1631],[-.9322,.1631],[-.9438,.163],[-.9554,.1629],[-.967,.1628],[-.9787,.1628],[-.9903,.1627],[-1.0019,.1626],[-1.0135,.1625],[-1.0251,.1625],[-1.0367,.1624],[-1.0483,.1623],[-1.06,.1622],[-1.0716,.1621],[-1.0832,.1621],[-1.0948,.162],[-1.1064,.1619],[-1.1103,.1619]],at:[[0,0]],fins:[],finsAround:0,finsFrom:"booster",engines:{ring:8,centre:!0,f:.34,colour:[57,54,51],profile:[[-1.1103,.1592],[-1.1142,.1579],[-1.118,.1578],[-1.1219,.1578],[-1.1258,.1591],[-1.1297,.1591],[-1.1335,.1591],[-1.1374,.159],[-1.1413,.1564],[-1.1451,.1484],[-1.149,.1404],[-1.1529,.1377],[-1.1568,.1377],[-1.1606,.1377],[-1.1645,.1403],[-1.1684,.143],[-1.1722,.1456],[-1.1761,.1456],[-1.18,.1482],[-1.1839,.1508],[-1.1877,.1508],[-1.1916,.1534],[-1.1955,.1547],[-1.1993,.156],[-1.2032,.1586],[-1.2071,.1586],[-1.211,.1612],[-1.2148,.1625],[-1.2187,.1638],[-1.2226,.1664],[-1.2264,.1637],[-1.2303,.1479],[-1.2342,.1307],[-1.2381,.1069]]}},{name:"booster",uv:[.6214,.0498,.932,1],top:.7714,end:-1.1103,profile:[[.7714,.0142],[.7598,.0316],[.7482,.0465],[.7366,.0588],[.725,.0697],[.7133,.0796],[.7017,.0886],[.6901,.0969],[.6785,.1045],[.6669,.1114],[.6553,.1178],[.6437,.1235],[.632,.1286],[.6204,.1332],[.6088,.1371],[.5972,.1406],[.5856,.1436],[.574,.146],[.5623,.1478],[.5507,.1495],[.5391,.1512],[.5275,.1533],[.5159,.1559],[.5043,.1589],[.4927,.1618],[.481,.1646],[.4694,.1669],[.4578,.1685],[.4462,.1692],[.4346,.1687],[.423,.1671],[.4113,.1646],[.3997,.1616],[.3881,.158],[.3765,.1553],[.3649,.1542],[.3533,.1539],[.3416,.1537],[.33,.1533],[.3184,.1527],[.3068,.1523],[.2952,.1522],[.2836,.1521],[.272,.152],[.2603,.1519],[.2487,.1518],[.2371,.1519],[.2255,.1521],[.2139,.1525],[.2023,.1528],[.1906,.1528],[.179,.1528],[.1674,.1527],[.1558,.1526],[.1442,.1525],[.1326,.1525],[.121,.1524],[.1093,.1523],[.0977,.1522],[.0861,.1522],[.0745,.1523],[.0629,.1527],[.0513,.153],[.0396,.1532],[.028,.1532],[.0164,.1531],[.0048,.1529],[-.0068,.1526],[-.0184,.1521],[-.03,.1516],[-.0417,.1514],[-.0533,.1513],[-.0649,.1514],[-.0765,.1517],[-.0881,.152],[-.0997,.1522],[-.1114,.1522],[-.123,.1522],[-.1346,.1521],[-.1462,.152],[-.1578,.1519],[-.1694,.1519],[-.181,.1518],[-.1927,.1517],[-.2043,.1516],[-.2159,.1517],[-.2275,.1519],[-.2391,.1523],[-.2507,.1526],[-.2624,.1526],[-.274,.1526],[-.2856,.1525],[-.2972,.1524],[-.3088,.1523],[-.3204,.1519],[-.3321,.1515],[-.3437,.151],[-.3553,.1508],[-.3669,.1509],[-.3785,.1512],[-.3901,.1516],[-.4017,.1517],[-.4134,.1516],[-.425,.1516],[-.4366,.1516],[-.4482,.1519],[-.4598,.1528],[-.4714,.1539],[-.4831,.1548],[-.4947,.1551],[-.5063,.1551],[-.5179,.1551],[-.5295,.155],[-.5411,.1549],[-.5527,.1548],[-.5644,.1547],[-.576,.1547],[-.5876,.1546],[-.5992,.1545],[-.6108,.1544],[-.6224,.1544],[-.6341,.1543],[-.6457,.1542],[-.6573,.1541],[-.6689,.1541],[-.6805,.154],[-.6921,.1539],[-.7037,.1538],[-.7154,.1538],[-.727,.1537],[-.7386,.1536],[-.7502,.1536],[-.7618,.1535],[-.7734,.1534],[-.7851,.1533],[-.7967,.1533],[-.8083,.1532],[-.8199,.1531],[-.8315,.153],[-.8431,.1529],[-.8548,.1529],[-.8664,.1528],[-.878,.1527],[-.8896,.1526],[-.9012,.1526],[-.9128,.1525],[-.9244,.1524],[-.9361,.1524],[-.9477,.1523],[-.9593,.1522],[-.9709,.1521],[-.9825,.1521],[-.9941,.152],[-1.0058,.1519],[-1.0174,.1518],[-1.029,.1518],[-1.0406,.1517],[-1.0522,.1516],[-1.0638,.1516],[-1.0754,.1515],[-1.0871,.1514],[-1.0987,.1513],[-1.1103,.1513]],at:[[-1.5708,.3464],[1.5708,.3464]],fins:[{side:-1,uv:[.932,.709,.9935,1],x0:-.2041,x1:0,y0:-.5392,y1:-1.1161,outline:[[-.5392,.1584,.1531],[-.545,.1611,.1531],[-.5508,.1638,.1531],[-.5566,.1638,.1531],[-.5624,.1638,.1531],[-.5682,.1638,.1531],[-.574,.1638,.1531],[-.5799,.1638,.1531],[-.5857,.1665,.1531],[-.5915,.1665,.1531],[-.5973,.1665,.1531],[-.6031,.1665,.1531],[-.6089,.1665,.1531],[-.6147,.1692,.1531],[-.6205,.1692,.1531],[-.6263,.1692,.1531],[-.6321,.1692,.1531],[-.6379,.1692,.1531],[-.6437,.1692,.1531],[-.6495,.1692,.1531],[-.6554,.1692,.1531],[-.6612,.1718,.1531],[-.667,.1718,.1531],[-.6728,.1718,.1531],[-.6786,.1718,.1531],[-.6844,.1718,.1531],[-.6902,.1718,.1531],[-.696,.1745,.1531],[-.7018,.1745,.1531],[-.7076,.1745,.1531],[-.7134,.1745,.1531],[-.7192,.1745,.1531],[-.725,.1745,.1531],[-.7309,.1745,.1531],[-.7367,.1772,.1531],[-.7425,.1772,.1531],[-.7483,.1772,.1531],[-.7541,.1772,.1531],[-.7599,.1772,.1531],[-.7657,.1772,.1531],[-.7715,.1772,.1531],[-.7773,.1799,.1531],[-.7831,.1799,.1531],[-.7889,.1799,.1531],[-.7947,.1799,.1531],[-.8005,.1799,.1531],[-.8064,.1799,.1531],[-.8122,.1799,.1531],[-.818,.1826,.1531],[-.8238,.1826,.1531],[-.8296,.1826,.1531],[-.8354,.1826,.1531],[-.8412,.1826,.1531],[-.847,.1826,.1531],[-.8528,.1853,.1531],[-.8586,.1853,.1531],[-.8644,.1853,.1531],[-.8702,.1853,.1531],[-.876,.1853,.1531],[-.8819,.1853,.1531],[-.8877,.1853,.1531],[-.8935,.1853,.1531],[-.8993,.1879,.1531],[-.9051,.1879,.1531],[-.9109,.1879,.1531],[-.9167,.1879,.1531],[-.9225,.1879,.1531],[-.9283,.1906,.1531],[-.9341,.1906,.1531],[-.9399,.1906,.1531],[-.9457,.1906,.1531],[-.9515,.1906,.1531],[-.9574,.1933,.1531],[-.9632,.1933,.1531],[-.969,.1933,.1531],[-.9748,.1933,.1531],[-.9806,.1933,.1531],[-.9864,.1933,.1531],[-.9922,.196,.1531],[-.998,.196,.1531],[-1.0038,.196,.1531],[-1.0096,.196,.1531],[-1.0154,.196,.1531],[-1.0212,.196,.1531],[-1.027,.196,.1531],[-1.0329,.1987,.1531],[-1.0387,.1987,.1531],[-1.0445,.1987,.1531],[-1.0503,.1987,.1531],[-1.0561,.2014,.1531],[-1.0619,.2014,.1531],[-1.0677,.2014,.1531],[-1.0735,.2014,.1531],[-1.0793,.2014,.1531],[-1.0851,.1906,.1531],[-1.0909,.1853,.1531],[-1.0967,.1772,.1531],[-1.1025,.1692,.1531],[-1.1084,.1665,.1531],[-1.1142,.1665,.1531]]}],finsAround:4,finsFrom:null,engines:{ring:8,centre:!0,f:.34,colour:[60,58,55],profile:[[-1.1103,.1645],[-1.1142,.1645],[-1.118,.1645],[-1.1219,.1644],[-1.1258,.1671],[-1.1297,.167],[-1.1335,.167],[-1.1374,.167],[-1.1413,.1643],[-1.1451,.1563],[-1.149,.151],[-1.1529,.151],[-1.1568,.1457],[-1.1606,.1456],[-1.1645,.1483],[-1.1684,.1509],[-1.1722,.1535],[-1.1761,.1535],[-1.18,.1561],[-1.1839,.1587],[-1.1877,.1587],[-1.1916,.1613],[-1.1955,.1639],[-1.1993,.1639],[-1.2032,.1665],[-1.2071,.1692],[-1.211,.1691],[-1.2148,.1717],[-1.2187,.1744],[-1.2226,.169],[-1.2264,.1585],[-1.2303,.132],[-1.2342,.0924]]}}],badge:{y:.9137,d:.251,r:.1673},band:[.7551,.774],head:{top:1.6,cut:1.0723,mean:.7752,r:.2062}},newGlenn:{id:"new-glenn",shape:"newGlenn",atlas:{w:897,h:1142,cap:[.9933,.9947,.9978,.9982]},parts:[{name:"core",uv:[0,.1033,.8562,1],top:1.6,end:-1.1485,profile:[[1.6,.0169],[1.5886,.0402],[1.5771,.0587],[1.5657,.0741],[1.5543,.0879],[1.5428,.1001],[1.5314,.1112],[1.5199,.1216],[1.5085,.1311],[1.4971,.1398],[1.4856,.1476],[1.4742,.1546],[1.4628,.1608],[1.4513,.1666],[1.4399,.1717],[1.4285,.1762],[1.417,.1798],[1.4056,.1828],[1.3941,.1851],[1.3827,.1868],[1.3713,.1879],[1.3598,.1885],[1.3484,.1888],[1.337,.1889],[1.3255,.1888],[1.3141,.1887],[1.3027,.1885],[1.2912,.1883],[1.2798,.1881],[1.2683,.1879],[1.2569,.1878],[1.2455,.1876],[1.234,.1874],[1.2226,.1873],[1.2112,.1871],[1.1997,.187],[1.1883,.1871],[1.1769,.1873],[1.1654,.1876],[1.154,.1877],[1.1426,.1876],[1.1311,.1875],[1.1197,.1873],[1.1082,.1871],[1.0968,.1871],[1.0854,.1875],[1.0739,.1881],[1.0625,.1882],[1.0511,.1874],[1.0396,.1865],[1.0282,.186],[1.0168,.1858],[1.0053,.1856],[.9939,.1854],[.9824,.1852],[.971,.1851],[.9596,.1849],[.9481,.1848],[.9367,.1846],[.9253,.1845],[.9138,.1845],[.9024,.1848],[.891,.1851],[.8795,.1852],[.8681,.1852],[.8566,.1852],[.8452,.1855],[.8338,.1858],[.8223,.1859],[.8109,.1858],[.7995,.1856],[.788,.1855],[.7766,.1853],[.7652,.1852],[.7537,.1853],[.7423,.1856],[.7308,.1859],[.7194,.1859],[.708,.1858],[.6965,.1856],[.6851,.1854],[.6737,.1852],[.6622,.1854],[.6508,.1862],[.6394,.1869],[.6279,.1869],[.6165,.1864],[.605,.1862],[.5936,.1866],[.5822,.1873],[.5707,.1879],[.5593,.1881],[.5479,.188],[.5364,.1878],[.525,.1877],[.5136,.1875],[.5021,.1873],[.4907,.1872],[.4792,.1871],[.4678,.187],[.4564,.1869],[.4449,.1869],[.4335,.1869],[.4221,.1869],[.4106,.187],[.3992,.1872],[.3878,.1873],[.3763,.1876],[.3649,.1879],[.3534,.1883],[.342,.1888],[.3306,.1894],[.3191,.19],[.3077,.1902],[.2963,.1902],[.2848,.1901],[.2734,.19],[.262,.1898],[.2505,.1896],[.2391,.1895],[.2277,.1893],[.2162,.1891],[.2048,.189],[.1933,.1888],[.1819,.1887],[.1705,.1885],[.159,.1883],[.1476,.1883],[.1362,.1883],[.1247,.1887],[.1133,.1893],[.1019,.1898],[.0904,.19],[.079,.19],[.0675,.1899],[.0561,.1898],[.0447,.1896],[.0332,.1894],[.0218,.1893],[.0104,.1891],[-.0011,.189],[-.0125,.1888],[-.0239,.1887],[-.0354,.1885],[-.0468,.1884],[-.0583,.1885],[-.0697,.1888],[-.0811,.1891],[-.0926,.1891],[-.104,.1891],[-.1154,.1893],[-.1269,.1896],[-.1383,.1898],[-.1497,.1897],[-.1612,.1896],[-.1726,.1894],[-.1841,.1893],[-.1955,.1891],[-.2069,.189],[-.2184,.1889],[-.2298,.189],[-.2412,.1898],[-.2527,.192],[-.2641,.1961],[-.2755,.2008],[-.287,.2041],[-.2984,.2054],[-.3099,.2056],[-.3213,.2055],[-.3327,.2053],[-.3442,.2051],[-.3556,.205],[-.367,.2048],[-.3785,.2046],[-.3899,.2045],[-.4013,.2043],[-.4128,.2042],[-.4242,.204],[-.4357,.2038],[-.4471,.2036],[-.4585,.2035],[-.47,.2033],[-.4814,.2032],[-.4928,.203],[-.5043,.2028],[-.5157,.2027],[-.5271,.2025],[-.5386,.2023],[-.55,.2022],[-.5614,.202],[-.5729,.2018],[-.5843,.2017],[-.5958,.2015],[-.6072,.2014],[-.6186,.2012],[-.6301,.2011],[-.6415,.2009],[-.6529,.2007],[-.6644,.2006],[-.6758,.2004],[-.6872,.2003],[-.6987,.2001],[-.7101,.1999],[-.7216,.1998],[-.733,.1996],[-.7444,.1995],[-.7559,.1993],[-.7673,.1991],[-.7787,.199],[-.7902,.1988],[-.8016,.1987],[-.813,.1985],[-.8245,.1984],[-.8359,.1982],[-.8474,.198],[-.8588,.1979],[-.8702,.1977],[-.8817,.1976],[-.8931,.1974],[-.9045,.1973],[-.916,.1971],[-.9274,.197],[-.9388,.1968],[-.9503,.1966],[-.9617,.1965],[-.9732,.1963],[-.9846,.1962],[-.996,.196],[-1.0075,.1959],[-1.0189,.1957],[-1.0303,.1956],[-1.0418,.1954],[-1.0532,.1953],[-1.0646,.1951],[-1.0761,.195],[-1.0875,.1948],[-1.099,.1947],[-1.1104,.1945],[-1.1218,.1944],[-1.1333,.1942],[-1.1447,.1941],[-1.1485,.194]],at:[[0,0]],fins:[{side:-1,uv:[.8562,.9002,.971,1],x0:-.3011,x1:.0015,y0:.5517,y1:.3344,outline:[[.5517,.1865,.1865],[.546,.2012,.1865],[.5402,.2159,.1865],[.5345,.2306,.1865],[.5288,.2423,.1865],[.5231,.2541,.1865],[.5174,.2688,.1865],[.5117,.2834,.1865],[.5059,.2952,.1865],[.5002,.2982,.1865],[.4945,.2982,.1865],[.4888,.2982,.1866],[.4831,.2982,.1866],[.4773,.2982,.1866],[.4716,.2982,.1866],[.4659,.2982,.1867],[.4602,.2952,.1867],[.4545,.2834,.1868],[.4488,.2746,.1869],[.443,.2629,.1869],[.4373,.2541,.187],[.4316,.2453,.1871],[.4259,.2335,.1872],[.4202,.2247,.1873],[.4144,.2247,.1874],[.4087,.2247,.1875],[.403,.2247,.1877],[.3973,.2247,.1879],[.3916,.2247,.188],[.3859,.2247,.1882],[.3801,.2247,.1884],[.3744,.2247,.1886],[.3687,.2218,.1889],[.363,.213,.1891],[.3573,.2042,.1894],[.3515,.1953,.1897],[.3458,.1924,.19],[.3401,.1894,.1904],[.3363,.1894,.1906]]},{side:1,uv:[.8562,.7986,.9721,.8984],x0:-.0015,x1:.304,y0:.5517,y1:.3344,outline:[[.5517,.1865,.1865],[.546,.1953,.1865],[.5402,.2042,.1865],[.5345,.213,.1865],[.5288,.2247,.1865],[.5231,.2365,.1865],[.5174,.2482,.1865],[.5117,.26,.1865],[.5059,.2717,.1865],[.5002,.2805,.1865],[.4945,.2893,.1865],[.4888,.2982,.1866],[.4831,.3011,.1866],[.4773,.3011,.1866],[.4716,.3011,.1866],[.4659,.3011,.1867],[.4602,.3011,.1867],[.4545,.3011,.1868],[.4488,.3011,.1869],[.443,.2952,.1869],[.4373,.2834,.187],[.4316,.2746,.1871],[.4259,.2658,.1872],[.4202,.257,.1873],[.4144,.2453,.1874],[.4087,.2335,.1875],[.403,.2247,.1877],[.3973,.2218,.1879],[.3916,.2218,.188],[.3859,.2218,.1882],[.3801,.2247,.1884],[.3744,.2247,.1886],[.3687,.2247,.1889],[.363,.2247,.1891],[.3573,.2218,.1894],[.3515,.2159,.1897],[.3458,.2071,.19],[.3401,.1983,.1904],[.3363,.1924,.1906]]},{side:-1,uv:[.8562,.4002,.9911,.7968],x0:-.3253,x1:.0013,y0:-.2908,y1:-1.1542,outline:[[-.2908,.2038,.1986],[-.2965,.2065,.1992],[-.3022,.2092,.1995],[-.3079,.2146,.1997],[-.3137,.2146,.1997],[-.3194,.2173,.1998],[-.3251,.22,.1998],[-.3308,.2227,.1998],[-.3365,.2254,.1998],[-.3423,.2281,.1998],[-.348,.2308,.1998],[-.3537,.2335,.1998],[-.3594,.2389,.1998],[-.3651,.2416,.1998],[-.3708,.2443,.1998],[-.3766,.247,.1998],[-.3823,.2497,.1998],[-.388,.2524,.1998],[-.3937,.2551,.1998],[-.3994,.2578,.1998],[-.4052,.2605,.1998],[-.4109,.2632,.1998],[-.4166,.2659,.1998],[-.4223,.2686,.1998],[-.428,.2713,.1998],[-.4337,.274,.1998],[-.4395,.2767,.1998],[-.4452,.2794,.1998],[-.4509,.2821,.1998],[-.4566,.2848,.1998],[-.4623,.2875,.1998],[-.4681,.2902,.1998],[-.4738,.2929,.1998],[-.4795,.2956,.1998],[-.4852,.2983,.1998],[-.4909,.301,.1998],[-.4966,.3037,.1998],[-.5024,.3037,.1998],[-.5081,.3064,.1998],[-.5138,.3091,.1998],[-.5195,.3091,.1998],[-.5252,.3118,.1998],[-.531,.3118,.1998],[-.5367,.3145,.1998],[-.5424,.3145,.1998],[-.5481,.3145,.1998],[-.5538,.3145,.1998],[-.5595,.3145,.1998],[-.5653,.3172,.1998],[-.571,.3172,.1998],[-.5767,.3172,.1998],[-.5824,.3172,.1998],[-.5881,.3172,.1998],[-.5939,.3172,.1998],[-.5996,.3172,.1998],[-.6053,.3172,.1998],[-.611,.3172,.1998],[-.6167,.3172,.1998],[-.6224,.3199,.1998],[-.6282,.3199,.1998],[-.6339,.3199,.1998],[-.6396,.3199,.1998],[-.6453,.3199,.1998],[-.651,.3199,.1998],[-.6568,.3199,.1998],[-.6625,.3199,.1998],[-.6682,.3199,.1998],[-.6739,.3199,.1998],[-.6796,.3199,.1998],[-.6853,.3226,.1998],[-.6911,.3226,.1998],[-.6968,.3226,.1998],[-.7025,.3226,.1998],[-.7082,.3226,.1998],[-.7139,.3226,.1998],[-.7197,.3226,.1998],[-.7254,.3226,.1998],[-.7311,.3199,.1998],[-.7368,.3199,.1998],[-.7425,.3199,.1998],[-.7482,.3199,.1998],[-.754,.3199,.1998],[-.7597,.3172,.1998],[-.7654,.3172,.1998],[-.7711,.3172,.1998],[-.7768,.3172,.1998],[-.7826,.3172,.1998],[-.7883,.3145,.1998],[-.794,.3145,.1998],[-.7997,.3145,.1998],[-.8054,.3145,.1998],[-.8111,.3145,.1998],[-.8169,.3118,.1998],[-.8226,.3118,.1998],[-.8283,.3118,.1998],[-.834,.3118,.1998],[-.8397,.3091,.1998],[-.8454,.3091,.1998],[-.8512,.3091,.1998],[-.8569,.3091,.1998],[-.8626,.3091,.1998],[-.8683,.3091,.1998],[-.874,.3064,.1998],[-.8798,.3064,.1998],[-.8855,.3064,.1998],[-.8912,.3064,.1998],[-.8969,.3064,.1998],[-.9026,.3064,.1998],[-.9083,.3037,.1998],[-.9141,.3037,.1998],[-.9198,.3037,.1998],[-.9255,.3037,.1998],[-.9312,.3037,.1998],[-.9369,.3037,.1998],[-.9427,.3037,.1998],[-.9484,.301,.1998],[-.9541,.301,.1998],[-.9598,.301,.1998],[-.9655,.301,.1998],[-.9712,.301,.1998],[-.977,.2983,.1998],[-.9827,.2983,.1998],[-.9884,.2983,.1998],[-.9941,.2983,.1998],[-.9998,.2983,.1998],[-1.0056,.2956,.1998],[-1.0113,.2956,.1998],[-1.017,.2929,.1998],[-1.0227,.2902,.1998],[-1.0284,.2875,.1998],[-1.0341,.2848,.1998],[-1.0399,.2848,.1998],[-1.0456,.2848,.1998],[-1.0513,.2848,.1998],[-1.057,.2848,.1998],[-1.0627,.2848,.1998],[-1.0685,.2848,.1998],[-1.0742,.2848,.1998],[-1.0799,.2848,.1998],[-1.0856,.2848,.1998],[-1.0913,.2848,.1998],[-1.097,.2848,.1998],[-1.1028,.2848,.1998],[-1.1085,.2848,.1998],[-1.1142,.2848,.1998],[-1.1199,.2848,.1998],[-1.1256,.2848,.1998],[-1.1314,.2821,.1998],[-1.1371,.2821,.1998],[-1.1428,.2794,.1998],[-1.1485,.274,.1998],[-1.1523,.2686,.1998]]},{side:1,uv:[.8562,.0018,.99,.3984],x0:-.0013,x1:.3226,y0:-.2908,y1:-1.1542,outline:[[-.2908,.2038,.1986],[-.2965,.2065,.1992],[-.3022,.2092,.1995],[-.3079,.2119,.1997],[-.3137,.2146,.1997],[-.3194,.2173,.1998],[-.3251,.22,.1998],[-.3308,.2227,.1998],[-.3365,.2281,.1998],[-.3423,.2308,.1998],[-.348,.2335,.1998],[-.3537,.2362,.1998],[-.3594,.2389,.1998],[-.3651,.2416,.1998],[-.3708,.2443,.1998],[-.3766,.247,.1998],[-.3823,.2497,.1998],[-.388,.2524,.1998],[-.3937,.2551,.1998],[-.3994,.2578,.1998],[-.4052,.2605,.1998],[-.4109,.2632,.1998],[-.4166,.2659,.1998],[-.4223,.2686,.1998],[-.428,.2713,.1998],[-.4337,.274,.1998],[-.4395,.2767,.1998],[-.4452,.2794,.1998],[-.4509,.2821,.1998],[-.4566,.2848,.1998],[-.4623,.2875,.1998],[-.4681,.2902,.1998],[-.4738,.2929,.1998],[-.4795,.2956,.1998],[-.4852,.2983,.1998],[-.4909,.301,.1998],[-.4966,.3037,.1998],[-.5024,.3037,.1998],[-.5081,.3064,.1998],[-.5138,.3091,.1998],[-.5195,.3091,.1998],[-.5252,.3118,.1998],[-.531,.3118,.1998],[-.5367,.3118,.1998],[-.5424,.3145,.1998],[-.5481,.3145,.1998],[-.5538,.3145,.1998],[-.5595,.3145,.1998],[-.5653,.3145,.1998],[-.571,.3145,.1998],[-.5767,.3145,.1998],[-.5824,.3172,.1998],[-.5881,.3172,.1998],[-.5939,.3172,.1998],[-.5996,.3172,.1998],[-.6053,.3172,.1998],[-.611,.3172,.1998],[-.6167,.3172,.1998],[-.6224,.3172,.1998],[-.6282,.3172,.1998],[-.6339,.3172,.1998],[-.6396,.3172,.1998],[-.6453,.3172,.1998],[-.651,.3172,.1998],[-.6568,.3199,.1998],[-.6625,.3199,.1998],[-.6682,.3199,.1998],[-.6739,.3199,.1998],[-.6796,.3199,.1998],[-.6853,.3199,.1998],[-.6911,.3199,.1998],[-.6968,.3199,.1998],[-.7025,.3199,.1998],[-.7082,.3199,.1998],[-.7139,.3199,.1998],[-.7197,.3199,.1998],[-.7254,.3199,.1998],[-.7311,.3199,.1998],[-.7368,.3199,.1998],[-.7425,.3199,.1998],[-.7482,.3199,.1998],[-.754,.3172,.1998],[-.7597,.3172,.1998],[-.7654,.3172,.1998],[-.7711,.3172,.1998],[-.7768,.3172,.1998],[-.7826,.3145,.1998],[-.7883,.3145,.1998],[-.794,.3145,.1998],[-.7997,.3145,.1998],[-.8054,.3118,.1998],[-.8111,.3118,.1998],[-.8169,.3118,.1998],[-.8226,.3118,.1998],[-.8283,.3118,.1998],[-.834,.3091,.1998],[-.8397,.3091,.1998],[-.8454,.3091,.1998],[-.8512,.3091,.1998],[-.8569,.3064,.1998],[-.8626,.3064,.1998],[-.8683,.3064,.1998],[-.874,.3064,.1998],[-.8798,.3064,.1998],[-.8855,.3037,.1998],[-.8912,.3037,.1998],[-.8969,.3037,.1998],[-.9026,.3037,.1998],[-.9083,.3037,.1998],[-.9141,.3037,.1998],[-.9198,.3037,.1998],[-.9255,.301,.1998],[-.9312,.301,.1998],[-.9369,.301,.1998],[-.9427,.301,.1998],[-.9484,.301,.1998],[-.9541,.301,.1998],[-.9598,.2983,.1998],[-.9655,.2983,.1998],[-.9712,.2983,.1998],[-.977,.2983,.1998],[-.9827,.2983,.1998],[-.9884,.2983,.1998],[-.9941,.2956,.1998],[-.9998,.2956,.1998],[-1.0056,.2956,.1998],[-1.0113,.2929,.1998],[-1.017,.2902,.1998],[-1.0227,.2875,.1998],[-1.0284,.2875,.1998],[-1.0341,.2848,.1998],[-1.0399,.2848,.1998],[-1.0456,.2848,.1998],[-1.0513,.2848,.1998],[-1.057,.2848,.1998],[-1.0627,.2848,.1998],[-1.0685,.2848,.1998],[-1.0742,.2848,.1998],[-1.0799,.2848,.1998],[-1.0856,.2848,.1998],[-1.0913,.2848,.1998],[-1.097,.2848,.1998],[-1.1028,.2848,.1998],[-1.1085,.2848,.1998],[-1.1142,.2848,.1998],[-1.1199,.2848,.1998],[-1.1256,.2848,.1998],[-1.1314,.2821,.1998],[-1.1371,.2821,.1998],[-1.1428,.2794,.1998],[-1.1485,.2713,.1998],[-1.1523,.2659,.1998]]}],finsAround:2,finsFrom:null,engines:{ring:6,centre:!0,f:.3,colour:[80,79,78],profile:[[-1.1485,.2648],[-1.1523,.2595],[-1.1561,.2516],[-1.1599,.2463],[-1.1638,.241],[-1.1676,.2461],[-1.1714,.2487],[-1.1752,.2512],[-1.179,.2538],[-1.1828,.255],[-1.1866,.2576],[-1.1904,.2601],[-1.1943,.2614],[-1.1981,.2639],[-1.2019,.2652],[-1.2057,.2664],[-1.2095,.2689],[-1.2133,.2702],[-1.2171,.2714],[-1.2209,.2687],[-1.2248,.2543],[-1.2286,.1734],[-1.2324,.1773],[-1.2362,.1759],[-1.24,.1576]]}}],badge:{y:.9137,d:.2768,r:.1845},band:[.7422,.7611],head:{top:1.6,cut:1.0852,mean:.6111,r:.2159}},vulcan:{id:"vulcan",shape:"vulcan",atlas:{w:1160,h:1024,cap:[.9948,.9941,.9983,.998]},parts:[{name:"core",uv:[0,0,.6621,1],top:1.6,end:-1.0752,profile:[[1.6,.0147],[1.5884,.0337],[1.5767,.0482],[1.5651,.0614],[1.5535,.0738],[1.5418,.0854],[1.5302,.0963],[1.5186,.1066],[1.5069,.1166],[1.4953,.1261],[1.4837,.1351],[1.4721,.1436],[1.4604,.1518],[1.4488,.1595],[1.4372,.1668],[1.4255,.1735],[1.4139,.1798],[1.4023,.1856],[1.3906,.1911],[1.379,.1963],[1.3674,.2012],[1.3557,.2057],[1.3441,.2099],[1.3325,.2137],[1.3208,.2171],[1.3092,.2202],[1.2976,.2228],[1.286,.2252],[1.2743,.2273],[1.2627,.229],[1.2511,.2305],[1.2394,.2316],[1.2278,.2323],[1.2162,.2327],[1.2045,.2328],[1.1929,.2326],[1.1813,.2325],[1.1696,.2326],[1.158,.2325],[1.1464,.2325],[1.1347,.2326],[1.1231,.2327],[1.1115,.2326],[1.0998,.2322],[1.0882,.2317],[1.0766,.2315],[1.065,.2314],[1.0533,.2311],[1.0417,.2307],[1.0301,.2306],[1.0184,.2308],[1.0068,.2311],[.9952,.2312],[.9835,.2311],[.9719,.2309],[.9603,.2307],[.9486,.2304],[.937,.2298],[.9254,.2292],[.9137,.2289],[.9021,.2287],[.8905,.2287],[.8789,.2288],[.8672,.229],[.8556,.2289],[.844,.2285],[.8323,.2282],[.8207,.2279],[.8091,.2279],[.7974,.228],[.7858,.2278],[.7742,.2273],[.7625,.227],[.7509,.2266],[.7393,.2254],[.7276,.2226],[.716,.2181],[.7044,.2128],[.6928,.2072],[.6811,.2015],[.6695,.196],[.6579,.1907],[.6462,.1855],[.6346,.1806],[.623,.1765],[.6113,.1743],[.5997,.1747],[.5881,.1766],[.5764,.1791],[.5648,.1818],[.5532,.1846],[.5415,.1876],[.5299,.1906],[.5183,.1938],[.5066,.1969],[.495,.2],[.4834,.2031],[.4718,.2062],[.4601,.2088],[.4485,.2104],[.4369,.2108],[.4252,.2104],[.4136,.2102],[.402,.2102],[.3903,.2101],[.3787,.21],[.3671,.2099],[.3554,.2098],[.3438,.2097],[.3322,.2095],[.3205,.2094],[.3089,.2093],[.2973,.2093],[.2857,.2094],[.274,.2094],[.2624,.2091],[.2508,.2088],[.2391,.2086],[.2275,.2084],[.2159,.2083],[.2042,.2082],[.1926,.208],[.181,.2079],[.1693,.2078],[.1577,.2077],[.1461,.2075],[.1344,.2074],[.1228,.2073],[.1112,.2072],[.0995,.2071],[.0879,.2069],[.0763,.2068],[.0647,.2067],[.053,.2066],[.0414,.2065],[.0298,.2063],[.0181,.2062],[.0065,.2061],[-.0051,.206],[-.0168,.2059],[-.0284,.2057],[-.04,.2056],[-.0517,.2055],[-.0633,.2054],[-.0749,.2052],[-.0866,.2051],[-.0982,.205],[-.1098,.2049],[-.1214,.2048],[-.1331,.2046],[-.1447,.2045],[-.1563,.2044],[-.168,.2043],[-.1796,.2042],[-.1912,.2041],[-.2029,.2039],[-.2145,.2038],[-.2261,.2037],[-.2378,.2036],[-.2494,.2035],[-.261,.2033],[-.2727,.2032],[-.2843,.2031],[-.2959,.203],[-.3075,.2029],[-.3192,.2028],[-.3308,.2026],[-.3424,.2025],[-.3541,.2024],[-.3657,.2023],[-.3773,.2022],[-.389,.202],[-.4006,.2019],[-.4122,.2018],[-.4239,.2017],[-.4355,.2016],[-.4471,.2015],[-.4588,.2013],[-.4704,.2012],[-.482,.2011],[-.4937,.201],[-.5053,.2009],[-.5169,.2008],[-.5285,.2007],[-.5402,.2005],[-.5518,.2004],[-.5634,.2003],[-.5751,.2002],[-.5867,.2001],[-.5983,.2],[-.61,.1999],[-.6216,.1997],[-.6332,.1996],[-.6449,.1995],[-.6565,.1994],[-.6681,.1993],[-.6798,.1992],[-.6914,.1991],[-.703,.199],[-.7146,.1988],[-.7263,.1987],[-.7379,.1986],[-.7495,.1985],[-.7612,.1984],[-.7728,.1983],[-.7844,.1982],[-.7961,.1981],[-.8077,.1979],[-.8193,.1978],[-.831,.1977],[-.8426,.1976],[-.8542,.1975],[-.8659,.1974],[-.8775,.1973],[-.8891,.1972],[-.9008,.1971],[-.9124,.1969],[-.924,.1968],[-.9356,.1967],[-.9473,.1966],[-.9589,.1965],[-.9705,.1964],[-.9822,.1963],[-.9938,.1962],[-1.0054,.1961],[-1.0171,.196],[-1.0287,.1958],[-1.0403,.1957],[-1.052,.1956],[-1.0636,.1955],[-1.0752,.1954]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:2,centre:!1,f:.5,colour:[62,59,55],profile:[[-1.0752,.1556],[-1.0791,.1542],[-1.083,.1516],[-1.0869,.149],[-1.0907,.1464],[-1.0946,.1464],[-1.0985,.1464],[-1.1024,.1489],[-1.1062,.1489],[-1.1101,.1514],[-1.114,.1527],[-1.1179,.154],[-1.1217,.1565],[-1.1256,.159],[-1.1295,.159],[-1.1334,.1615],[-1.1373,.1628],[-1.1411,.164],[-1.145,.1653],[-1.1489,.1665],[-1.1528,.1691],[-1.1566,.169],[-1.1605,.1716],[-1.1644,.1715],[-1.1683,.1728],[-1.1722,.174],[-1.176,.1753],[-1.1799,.1765],[-1.1838,.1778],[-1.1877,.179],[-1.1915,.1803],[-1.1954,.1802],[-1.1993,.1827],[-1.2032,.1827],[-1.207,.184],[-1.2109,.1852],[-1.2148,.1852],[-1.2187,.1864],[-1.2226,.1864],[-1.2264,.1863],[-1.2303,.1812],[-1.2342,.1684],[-1.2381,.1416]]}},{name:"booster",uv:[.6621,.3447,.9931,1],top:.2159,end:-1.083,profile:[[.2159,.0039],[.2042,.011],[.1926,.0173],[.181,.0238],[.1693,.0299],[.1577,.0355],[.1461,.041],[.1344,.0465],[.1228,.0521],[.1112,.0579],[.0995,.0635],[.0879,.069],[.0763,.0741],[.0647,.0782],[.053,.0806],[.0414,.0813],[.0298,.0814],[.0181,.0815],[.0065,.0818],[-.0051,.0826],[-.0168,.0834],[-.0284,.0838],[-.04,.0839],[-.0517,.0838],[-.0633,.0838],[-.0749,.0837],[-.0866,.0837],[-.0982,.0838],[-.1098,.0839],[-.1214,.0837],[-.1331,.0835],[-.1447,.0834],[-.1563,.0834],[-.168,.0833],[-.1796,.0833],[-.1912,.0832],[-.2029,.0832],[-.2145,.0831],[-.2261,.0831],[-.2378,.0831],[-.2494,.083],[-.261,.0829],[-.2727,.0829],[-.2843,.0829],[-.2959,.0828],[-.3075,.0828],[-.3192,.0829],[-.3308,.083],[-.3424,.0828],[-.3541,.0826],[-.3657,.0825],[-.3773,.0825],[-.389,.0824],[-.4006,.0824],[-.4122,.0823],[-.4239,.0823],[-.4355,.0822],[-.4471,.0822],[-.4588,.0821],[-.4704,.0821],[-.482,.0821],[-.4937,.0821],[-.5053,.0821],[-.5169,.0822],[-.5285,.0821],[-.5402,.0819],[-.5518,.0818],[-.5634,.0817],[-.5751,.0817],[-.5867,.0816],[-.5983,.0816],[-.61,.0815],[-.6216,.0815],[-.6332,.0814],[-.6449,.0814],[-.6565,.0813],[-.6681,.0813],[-.6798,.0813],[-.6914,.0813],[-.703,.0813],[-.7146,.0812],[-.7263,.0811],[-.7379,.081],[-.7495,.081],[-.7612,.0809],[-.7728,.0809],[-.7844,.0808],[-.7961,.0808],[-.8077,.0807],[-.8193,.0807],[-.831,.0806],[-.8426,.0806],[-.8542,.0806],[-.8659,.0806],[-.8775,.0807],[-.8891,.0808],[-.9008,.0808],[-.9124,.0805],[-.924,.0803],[-.9356,.0803],[-.9473,.0802],[-.9589,.0801],[-.9705,.0801],[-.9822,.0801],[-.9938,.08],[-1.0054,.08],[-1.0171,.0799],[-1.0287,.0798],[-1.0403,.0792],[-1.052,.0775],[-1.0636,.0749],[-1.0752,.0726],[-1.083,.0715]],at:[[-1.5708,.3099],[1.5708,.3099]],fins:[],finsAround:0,finsFrom:null,engines:{ring:0,centre:!0,f:1,colour:[88,83,79],profile:[[-1.083,.0694],[-1.0869,.0668],[-1.0907,.0668],[-1.0946,.0668],[-1.0985,.0642],[-1.1024,.0642],[-1.1062,.0616],[-1.1101,.0539],[-1.114,.0462],[-1.1179,.0462],[-1.1217,.0462],[-1.1256,.0487],[-1.1295,.0487],[-1.1334,.0513],[-1.1373,.0513],[-1.1411,.0538],[-1.145,.0538],[-1.1489,.0564],[-1.1528,.0564],[-1.1566,.0589],[-1.1605,.0589],[-1.1644,.0614],[-1.1683,.0614],[-1.1722,.064],[-1.176,.064],[-1.1799,.0665],[-1.1838,.0665],[-1.1877,.069],[-1.1915,.069],[-1.1954,.0716],[-1.1993,.0716],[-1.2032,.0741],[-1.207,.0741],[-1.2109,.0664],[-1.2148,.0281]]}}],badge:{y:.9137,d:.3434,r:.2289},band:[.7089,.7278],head:{top:1.6,cut:1.1185,mean:.8006,r:.2444}},cz2f:{id:"long-march-2f",shape:"cz2f",atlas:{w:1160,h:1024,cap:[.9948,.9941,.9983,.998]},parts:[{name:"core",uv:[0,0,.6621,1],top:1.5981,end:-1.1021,profile:[[1.5981,.0102],[1.5864,.0199],[1.5747,.0267],[1.5631,.031],[1.5514,.0329],[1.5398,.0333],[1.5281,.0336],[1.5165,.0345],[1.5048,.0363],[1.4932,.0387],[1.4815,.0404],[1.4698,.0395],[1.4582,.0379],[1.4465,.0378],[1.4349,.0389],[1.4232,.0405],[1.4116,.0435],[1.3999,.0497],[1.3883,.0568],[1.3766,.0581],[1.365,.0526],[1.3533,.047],[1.3416,.0455],[1.33,.0466],[1.3183,.0486],[1.3067,.0508],[1.295,.0533],[1.2834,.0559],[1.2717,.0587],[1.2601,.0614],[1.2484,.064],[1.2367,.0668],[1.2251,.07],[1.2134,.074],[1.2018,.0791],[1.1901,.084],[1.1785,.0891],[1.1668,.0963],[1.1552,.1056],[1.1435,.1157],[1.1318,.1259],[1.1202,.1358],[1.1085,.1455],[1.0969,.1551],[1.0852,.1644],[1.0736,.1734],[1.0619,.1818],[1.0503,.1889],[1.0386,.1945],[1.0269,.1982],[1.0153,.1999],[1.0036,.2004],[.992,.2006],[.9803,.201],[.9687,.2016],[.957,.202],[.9454,.202],[.9337,.202],[.9221,.2021],[.9104,.2028],[.8987,.2042],[.8871,.2056],[.8754,.2056],[.8638,.2041],[.8521,.2024],[.8405,.2015],[.8288,.2012],[.8172,.2011],[.8055,.2012],[.7938,.2016],[.7822,.2024],[.7705,.2026],[.7589,.2016],[.7472,.1997],[.7356,.1962],[.7239,.1908],[.7123,.1844],[.7006,.1786],[.6889,.175],[.6773,.1736],[.6656,.1731],[.654,.1728],[.6423,.1731],[.6307,.1738],[.619,.1735],[.6074,.1717],[.5957,.1696],[.584,.1682],[.5724,.1675],[.5607,.1676],[.5491,.1681],[.5374,.1686],[.5258,.1688],[.5141,.1687],[.5025,.1686],[.4908,.1686],[.4792,.1687],[.4675,.1694],[.4558,.1707],[.4442,.172],[.4325,.1724],[.4209,.1718],[.4092,.1709],[.3976,.1703],[.3859,.1701],[.3743,.1704],[.3626,.171],[.3509,.1715],[.3393,.1716],[.3276,.1716],[.316,.1715],[.3043,.1716],[.2927,.1722],[.281,.1732],[.2694,.174],[.2577,.1738],[.246,.1733],[.2344,.173],[.2227,.1731],[.2111,.1736],[.1994,.174],[.1878,.1737],[.1761,.1728],[.1645,.1719],[.1528,.1716],[.1411,.1719],[.1295,.1721],[.1178,.172],[.1062,.1715],[.0945,.1712],[.0829,.1713],[.0712,.1713],[.0596,.1713],[.0479,.1715],[.0363,.1717],[.0246,.1717],[.0129,.1716],[.0013,.1716],[-.0104,.1717],[-.022,.1719],[-.0337,.1721],[-.0453,.1718],[-.057,.1714],[-.0686,.1711],[-.0803,.1711],[-.092,.171],[-.1036,.1709],[-.1153,.1708],[-.1269,.1707],[-.1386,.1707],[-.1502,.1706],[-.1619,.1705],[-.1735,.1705],[-.1852,.1704],[-.1969,.1703],[-.2085,.1703],[-.2202,.1702],[-.2318,.1701],[-.2435,.1701],[-.2551,.17],[-.2668,.1699],[-.2784,.1698],[-.2901,.1698],[-.3018,.1697],[-.3134,.1696],[-.3251,.1696],[-.3367,.1695],[-.3484,.1694],[-.36,.1694],[-.3717,.1693],[-.3833,.1692],[-.395,.1692],[-.4066,.1691],[-.4183,.169],[-.43,.1689],[-.4416,.1689],[-.4533,.1688],[-.4649,.1687],[-.4766,.1687],[-.4882,.1686],[-.4999,.1685],[-.5115,.1684],[-.5232,.1684],[-.5349,.1683],[-.5465,.1682],[-.5582,.1682],[-.5698,.1681],[-.5815,.168],[-.5931,.168],[-.6048,.1679],[-.6164,.1678],[-.6281,.1678],[-.6398,.1677],[-.6514,.1677],[-.6631,.1676],[-.6747,.1675],[-.6864,.1674],[-.698,.1674],[-.7097,.1673],[-.7213,.1672],[-.733,.1671],[-.7447,.1671],[-.7563,.167],[-.768,.1669],[-.7796,.1669],[-.7913,.1668],[-.8029,.1667],[-.8146,.1667],[-.8262,.1666],[-.8379,.1665],[-.8495,.1665],[-.8612,.1664],[-.8729,.1663],[-.8845,.1663],[-.8962,.1662],[-.9078,.1661],[-.9195,.1661],[-.9311,.166],[-.9428,.1659],[-.9544,.1659],[-.9661,.1658],[-.9778,.1657],[-.9894,.1657],[-1.0011,.1656],[-1.0127,.1655],[-1.0244,.1655],[-1.036,.1654],[-1.0477,.1654],[-1.0593,.1653],[-1.071,.1652],[-1.0827,.1652],[-1.0943,.1651],[-1.1021,.165]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:4,centre:!1,f:.42,colour:[76,74,72],profile:[[-1.1021,.3699],[-1.106,.3661],[-1.1098,.2617],[-1.1137,.3565],[-1.1176,.2597],[-1.1215,.2616],[-1.1254,.1516],[-1.1293,.1308],[-1.1332,.1194],[-1.137,.1213],[-1.1409,.1212],[-1.1448,.1174],[-1.1487,.1098],[-1.1526,.1041],[-1.1565,.0985],[-1.1604,.0965],[-1.1642,.089],[-1.1681,.0908],[-1.172,.0927],[-1.1759,.0965],[-1.1798,.1003],[-1.1837,.1021],[-1.1876,.104],[-1.1914,.1078],[-1.1953,.1097],[-1.1992,.1134],[-1.2031,.1153],[-1.207,.2344],[-1.2109,.1191],[-1.2147,.1228],[-1.2186,.1228],[-1.2225,.1266],[-1.2264,.1303],[-1.2303,.1265],[-1.2342,.1171],[-1.2381,.0869]]}},{name:"booster",uv:[.6621,.5381,.9931,1],top:-.1852,end:-1.1021,profile:[[-.1852,.0175],[-.1969,.044],[-.2085,.0547],[-.2202,.0633],[-.2318,.0716],[-.2435,.0795],[-.2551,.0873],[-.2668,.0951],[-.2784,.1029],[-.2901,.1109],[-.3018,.1189],[-.3134,.1266],[-.3251,.1336],[-.3367,.1393],[-.3484,.1427],[-.36,.1441],[-.3717,.1444],[-.3833,.1443],[-.395,.144],[-.4066,.1438],[-.4183,.1438],[-.43,.1437],[-.4416,.1437],[-.4533,.1436],[-.4649,.1435],[-.4766,.1435],[-.4882,.1434],[-.4999,.1434],[-.5115,.1437],[-.5232,.1444],[-.5349,.1454],[-.5465,.1462],[-.5582,.1467],[-.5698,.1468],[-.5815,.1468],[-.5931,.1467],[-.6048,.1467],[-.6164,.1466],[-.6281,.1466],[-.6398,.1465],[-.6514,.1464],[-.6631,.1464],[-.6747,.1463],[-.6864,.1463],[-.698,.1462],[-.7097,.1462],[-.7213,.1461],[-.733,.146],[-.7447,.146],[-.7563,.1462],[-.768,.1466],[-.7796,.1467],[-.7913,.1466],[-.8029,.1472],[-.8146,.1483],[-.8262,.149],[-.8379,.1493],[-.8495,.1492],[-.8612,.1492],[-.8729,.1491],[-.8845,.1491],[-.8962,.149],[-.9078,.149],[-.9195,.1489],[-.9311,.1489],[-.9428,.1489],[-.9544,.1492],[-.9661,.1502],[-.9778,.1514],[-.9894,.1521],[-1.0011,.1523],[-1.0127,.1522],[-1.0244,.1521],[-1.036,.1521],[-1.0477,.152],[-1.0593,.151],[-1.071,.1467],[-1.0827,.1367],[-1.0943,.1241],[-1.1021,.117]],at:[[.7854,.401],[2.3562,.401],[3.927,.401],[5.4978,.401]],fins:[],finsAround:0,finsFrom:null,engines:{ring:0,centre:!0,f:1,colour:[76,73,70],profile:[[-1.1021,.1024],[-1.106,.0986],[-1.1098,.0948],[-1.1137,.0834],[-1.1176,.0834],[-1.1215,.0834],[-1.1254,.091],[-1.1293,.091],[-1.1332,.0834],[-1.137,.0872],[-1.1409,.0909],[-1.1448,.0909],[-1.1487,.0947],[-1.1526,.0985],[-1.1565,.1022],[-1.1604,.1022],[-1.1642,.106],[-1.1681,.1098],[-1.172,.1098],[-1.1759,.1135],[-1.1798,.1135],[-1.1837,.1173],[-1.1876,.1173],[-1.1914,.121],[-1.1953,.1248],[-1.1992,.1248],[-1.2031,.1172],[-1.207,.0869]]}}],badge:{y:.9137,d:.3036,r:.2024},band:[.7287,.7477],head:{top:1.1835,cut:1.0702,mean:.8821,r:.2161}},cz5:{id:"long-march-5",shape:"cz5",atlas:{w:1255,h:1024,cap:[.9952,.9941,.9984,.998]},parts:[{name:"core",uv:[0,0,.612,1],top:1.6,end:-1.0981,profile:[[1.6,.0202],[1.5882,.049],[1.5763,.0688],[1.5645,.0849],[1.5527,.0991],[1.5409,.1121],[1.529,.1238],[1.5172,.1345],[1.5054,.1444],[1.4936,.1537],[1.4817,.1625],[1.4699,.1705],[1.4581,.178],[1.4463,.1849],[1.4344,.1914],[1.4226,.1974],[1.4108,.2032],[1.399,.2087],[1.3871,.2138],[1.3753,.2184],[1.3635,.2226],[1.3517,.2265],[1.3398,.2299],[1.328,.233],[1.3162,.2358],[1.3044,.2382],[1.2925,.2403],[1.2807,.2419],[1.2689,.2431],[1.2571,.2438],[1.2452,.2441],[1.2334,.2438],[1.2216,.2435],[1.2098,.2432],[1.1979,.2431],[1.1861,.2429],[1.1743,.2428],[1.1625,.2427],[1.1506,.2429],[1.1388,.2432],[1.127,.2434],[1.1152,.2434],[1.1033,.2433],[1.0915,.2431],[1.0797,.243],[1.0679,.2428],[1.056,.2427],[1.0442,.2425],[1.0324,.2424],[1.0206,.2422],[1.0087,.2421],[.9969,.242],[.9851,.2419],[.9733,.2422],[.9614,.2425],[.9496,.2429],[.9378,.2433],[.926,.2436],[.9141,.2436],[.9023,.2435],[.8905,.2434],[.8787,.2433],[.8668,.2431],[.855,.243],[.8432,.2428],[.8314,.2427],[.8195,.2426],[.8077,.2425],[.7959,.2417],[.7841,.2397],[.7722,.2367],[.7604,.2331],[.7486,.2294],[.7368,.2257],[.7249,.2223],[.7131,.2192],[.7013,.2166],[.6895,.2143],[.6776,.2123],[.6658,.2109],[.654,.2104],[.6422,.2102],[.6303,.2103],[.6185,.2105],[.6067,.2102],[.5949,.2098],[.583,.2095],[.5712,.2094],[.5594,.2092],[.5476,.2091],[.5357,.209],[.5239,.2089],[.5121,.2087],[.5003,.2086],[.4884,.2085],[.4766,.2084],[.4648,.2083],[.453,.2081],[.4411,.208],[.4293,.2079],[.4175,.2078],[.4057,.2076],[.3938,.2075],[.382,.2074],[.3702,.2073],[.3584,.2072],[.3465,.207],[.3347,.2069],[.3229,.2068],[.3111,.2067],[.2992,.2065],[.2874,.2064],[.2756,.2063],[.2638,.2062],[.2519,.2061],[.2401,.2059],[.2283,.2058],[.2165,.2057],[.2046,.2056],[.1928,.2054],[.181,.2053],[.1692,.2052],[.1573,.2051],[.1455,.205],[.1337,.2048],[.1219,.2047],[.11,.2046],[.0982,.2045],[.0864,.2044],[.0746,.2042],[.0627,.2041],[.0509,.204],[.0391,.2039],[.0273,.2038],[.0154,.2037],[.0036,.2036],[-.0082,.2034],[-.02,.2033],[-.0319,.2032],[-.0437,.2031],[-.0555,.2029],[-.0673,.2028],[-.0792,.2027],[-.091,.2026],[-.1028,.2025],[-.1146,.2024],[-.1265,.2023],[-.1383,.2021],[-.1501,.202],[-.1619,.2019],[-.1738,.2018],[-.1856,.2017],[-.1974,.2015],[-.2092,.2014],[-.2211,.2013],[-.2329,.2012],[-.2447,.2011],[-.2565,.201],[-.2684,.2009],[-.2802,.2007],[-.292,.2006],[-.3038,.2005],[-.3157,.2004],[-.3275,.2003],[-.3393,.2002],[-.3511,.2001],[-.363,.1999],[-.3748,.1998],[-.3866,.1997],[-.3984,.1996],[-.4103,.1995],[-.4221,.1994],[-.4339,.1993],[-.4457,.1991],[-.4576,.199],[-.4694,.1989],[-.4812,.1988],[-.493,.1987],[-.5049,.1986],[-.5167,.1985],[-.5285,.1984],[-.5403,.1982],[-.5522,.1981],[-.564,.198],[-.5758,.1979],[-.5876,.1978],[-.5995,.1977],[-.6113,.1976],[-.6231,.1975],[-.6349,.1974],[-.6468,.1973],[-.6586,.1971],[-.6704,.197],[-.6822,.1969],[-.6941,.1968],[-.7059,.1967],[-.7177,.1966],[-.7295,.1965],[-.7414,.1964],[-.7532,.1963],[-.765,.1962],[-.7768,.196],[-.7887,.1959],[-.8005,.1958],[-.8123,.1957],[-.8241,.1956],[-.836,.1955],[-.8478,.1954],[-.8596,.1953],[-.8715,.1952],[-.8833,.1951],[-.8951,.1949],[-.9069,.1948],[-.9188,.1947],[-.9306,.1946],[-.9424,.1945],[-.9542,.1944],[-.9661,.1943],[-.9779,.1942],[-.9897,.1941],[-1.0015,.194],[-1.0134,.1939],[-1.0252,.1938],[-1.037,.1936],[-1.0488,.1935],[-1.0607,.1934],[-1.0725,.1933],[-1.0843,.1932],[-1.0961,.1931]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:2,centre:!1,f:.5,colour:[44,40,35],profile:[[-1.0981,.178],[-1.102,.1792],[-1.106,.1804],[-1.1099,.1829],[-1.1139,.1841],[-1.1178,.1854],[-1.1217,.1878],[-1.1257,.1903],[-1.1296,.1903],[-1.1336,.1928],[-1.1375,.1927],[-1.1415,.1952],[-1.1454,.1977],[-1.1493,.1977],[-1.1533,.1989],[-1.1572,.2001],[-1.1612,.2001],[-1.1651,.2026],[-1.169,.2025],[-1.173,.2037],[-1.1769,.205],[-1.1809,.2049],[-1.1848,.2061],[-1.1888,.2074],[-1.1927,.2086],[-1.1966,.2085],[-1.2006,.211],[-1.2045,.211],[-1.2085,.2109],[-1.2124,.2122],[-1.2163,.2134],[-1.2203,.2133],[-1.2242,.2133],[-1.2282,.2133],[-1.2321,.2082],[-1.2361,.1906],[-1.24,.1379]]}},{name:"booster",uv:[.612,.25,.9179,1],top:.4135,end:-1.0981,profile:[[.4135,.0016],[.4017,.009],[.3899,.0182],[.3781,.0264],[.3662,.0345],[.3544,.0426],[.3426,.0507],[.3308,.0587],[.3189,.0664],[.3071,.0742],[.2953,.0822],[.2835,.0903],[.2716,.0983],[.2598,.1064],[.248,.1142],[.2362,.1214],[.2243,.1275],[.2125,.1321],[.2007,.1346],[.1889,.1356],[.177,.1355],[.1652,.1345],[.1534,.1334],[.1416,.1328],[.1297,.1325],[.1179,.1325],[.1061,.1324],[.0943,.1323],[.0824,.1322],[.0706,.1322],[.0588,.1325],[.047,.1333],[.0351,.134],[.0233,.1344],[.0115,.1344],[-3e-4,.1344],[-.0122,.1343],[-.024,.1345],[-.0358,.1352],[-.0476,.136],[-.0595,.1364],[-.0713,.1365],[-.0831,.1366],[-.0949,.1368],[-.1068,.137],[-.1186,.1369],[-.1304,.1369],[-.1422,.1375],[-.1541,.1381],[-.1659,.1384],[-.1777,.1385],[-.1895,.1384],[-.2014,.1383],[-.2132,.1383],[-.225,.1384],[-.2368,.1389],[-.2487,.1397],[-.2605,.1402],[-.2723,.1404],[-.2841,.1403],[-.296,.1403],[-.3078,.1402],[-.3196,.1402],[-.3314,.1405],[-.3433,.1412],[-.3551,.1419],[-.3669,.1423],[-.3787,.1423],[-.3906,.1422],[-.4024,.1422],[-.4142,.1421],[-.426,.1421],[-.4379,.1425],[-.4497,.1432],[-.4615,.1439],[-.4733,.1442],[-.4852,.1442],[-.497,.1441],[-.5088,.144],[-.5206,.144],[-.5325,.144],[-.5443,.1443],[-.5561,.1449],[-.5679,.1457],[-.5798,.146],[-.5916,.146],[-.6034,.146],[-.6152,.1459],[-.6271,.1458],[-.6389,.1458],[-.6507,.1459],[-.6625,.1464],[-.6744,.1471],[-.6862,.1477],[-.698,.1479],[-.7098,.1478],[-.7217,.1478],[-.7335,.148],[-.7453,.1486],[-.7571,.1494],[-.769,.1498],[-.7808,.1499],[-.7926,.1498],[-.8044,.1497],[-.8163,.1496],[-.8281,.1496],[-.8399,.1498],[-.8517,.1504],[-.8636,.1517],[-.8754,.1537],[-.8872,.1562],[-.899,.1592],[-.9109,.1625],[-.9227,.1659],[-.9345,.1692],[-.9463,.1724],[-.9582,.1752],[-.97,.1775],[-.9818,.1791],[-.9936,.1799],[-1.0055,.1798],[-1.0173,.1785],[-1.0291,.176],[-1.0409,.172],[-1.0528,.1664],[-1.0646,.1592],[-1.0764,.1512],[-1.0882,.1438],[-1.0961,.14]],at:[[1.0297,.5171],[2.6005,.5171],[-1.0297,.5171],[-2.6005,.5171]],fins:[{side:-1,uv:[.9179,.8867,.9936,1],x0:-.24,x1:.0013,y0:-.8577,y1:-1.0863,outline:[[-.8577,.1562,.1502],[-.8636,.1587,.1509],[-.8695,.1613,.1519],[-.8754,.1638,.153],[-.8813,.1689,.1542],[-.8872,.1714,.1556],[-.8931,.1739,.1571],[-.899,.179,.1587],[-.905,.1815,.1603],[-.9109,.1841,.162],[-.9168,.1892,.1638],[-.9227,.1917,.1655],[-.9286,.1943,.1672],[-.9345,.1968,.1689],[-.9404,.2019,.1706],[-.9463,.2044,.1722],[-.9523,.2069,.1737],[-.9582,.212,.1751],[-.9641,.2146,.1763],[-.97,.2171,.1775],[-.9759,.2196,.1784],[-.9818,.2247,.1792],[-.9877,.2273,.1798],[-.9936,.2298,.1801],[-.9996,.2349,.1802],[-1.0055,.2374,.1801],[-1.0114,.2374,.1796],[-1.0173,.2374,.1789],[-1.0232,.2374,.1778],[-1.0291,.2374,.1764],[-1.035,.2374,.1747],[-1.0409,.2374,.1725],[-1.0469,.2374,.17],[-1.0528,.2374,.167],[-1.0587,.2374,.1636],[-1.0646,.2374,.1599],[-1.0705,.2374,.1559],[-1.0764,.2044,.1519],[-1.0823,.1511,.148],[-1.0843,.146,.1468]]}],finsAround:2,finsFrom:null,engines:{ring:2,centre:!1,f:.5,colour:[60,59,58],profile:[[-1.0981,.13],[-1.102,.1274],[-1.106,.1299],[-1.1099,.1324],[-1.1139,.1324],[-1.1178,.1248],[-1.1217,.1248],[-1.1257,.1273],[-1.1296,.1298],[-1.1336,.1323],[-1.1375,.1348],[-1.1415,.1373],[-1.1454,.1398],[-1.1493,.1398],[-1.1533,.1422],[-1.1572,.1447],[-1.1612,.1447],[-1.1651,.1472],[-1.169,.1497],[-1.173,.1497],[-1.1769,.1522],[-1.1809,.1521],[-1.1848,.1546],[-1.1888,.1546],[-1.1927,.1571],[-1.1966,.157],[-1.2006,.1595],[-1.2045,.1595],[-1.2085,.1595],[-1.2124,.1619],[-1.2163,.1619],[-1.2203,.1569],[-1.2242,.1343]]}}],badge:{y:.9137,d:.3654,r:.2436},band:[.6978,.7168],head:{top:1.6,cut:1.1295,mean:.7207,r:.2563}},cz3b:{id:"long-march-3b",shape:"cz3b",atlas:{w:1237,h:1024,cap:[.9951,.9941,.9984,.998]},parts:[{name:"core",uv:[0,0,.6209,1],top:1.6,end:-1.2151,profile:[[1.6,.0174],[1.5885,.0445],[1.577,.0633],[1.5656,.0779],[1.5541,.0909],[1.5426,.1025],[1.5311,.1132],[1.5196,.123],[1.5081,.132],[1.4967,.1404],[1.4852,.1483],[1.4737,.1559],[1.4622,.1632],[1.4507,.1703],[1.4392,.1771],[1.4278,.1835],[1.4163,.1897],[1.4048,.1958],[1.3933,.2018],[1.3818,.2076],[1.3704,.2131],[1.3589,.2183],[1.3474,.2234],[1.3359,.2283],[1.3244,.2329],[1.3129,.2372],[1.3015,.241],[1.29,.2443],[1.2785,.2466],[1.267,.2478],[1.2555,.2481],[1.244,.2481],[1.2326,.2481],[1.2211,.248],[1.2096,.2479],[1.1981,.2478],[1.1866,.2477],[1.1751,.2476],[1.1637,.2475],[1.1522,.2474],[1.1407,.2474],[1.1292,.2473],[1.1177,.2472],[1.1063,.2471],[1.0948,.2471],[1.0833,.2473],[1.0718,.2481],[1.0603,.2489],[1.0488,.2493],[1.0374,.2489],[1.0259,.2484],[1.0144,.248],[1.0029,.2477],[.9914,.2466],[.9799,.2438],[.9685,.2389],[.957,.2325],[.9455,.2257],[.934,.2189],[.9225,.2123],[.9111,.2059],[.8996,.1994],[.8881,.1928],[.8766,.1863],[.8651,.1804],[.8536,.1756],[.8422,.1725],[.8307,.1715],[.8192,.1724],[.8077,.1746],[.7962,.1766],[.7847,.1777],[.7733,.1776],[.7618,.1767],[.7503,.1753],[.7388,.174],[.7273,.1734],[.7158,.1731],[.7044,.1731],[.6929,.1731],[.6814,.1734],[.6699,.1738],[.6584,.174],[.647,.1742],[.6355,.1742],[.624,.1742],[.6125,.1741],[.601,.174],[.5895,.174],[.5781,.1739],[.5666,.1738],[.5551,.1738],[.5436,.1737],[.5321,.1737],[.5206,.1736],[.5092,.1735],[.4977,.1735],[.4862,.1734],[.4747,.1734],[.4632,.1733],[.4518,.1733],[.4403,.1733],[.4288,.1737],[.4173,.1746],[.4058,.1757],[.3943,.1764],[.3829,.176],[.3714,.1748],[.3599,.1736],[.3484,.1729],[.3369,.1727],[.3254,.1726],[.314,.1725],[.3025,.1725],[.291,.1724],[.2795,.1723],[.268,.1723],[.2565,.1724],[.2451,.1728],[.2336,.1732],[.2221,.1735],[.2106,.1735],[.1991,.1734],[.1877,.1734],[.1762,.1734],[.1647,.1733],[.1532,.1733],[.1417,.1734],[.1302,.1737],[.1188,.1741],[.1073,.1743],[.0958,.1743],[.0843,.1741],[.0728,.1741],[.0613,.1742],[.0499,.1742],[.0384,.1743],[.0269,.1746],[.0154,.1751],[.0039,.1751],[-.0075,.1745],[-.019,.1735],[-.0305,.1727],[-.042,.1719],[-.0535,.1712],[-.065,.1705],[-.0764,.1699],[-.0879,.1693],[-.0994,.1687],[-.1109,.1682],[-.1224,.1677],[-.1339,.1673],[-.1453,.1669],[-.1568,.1665],[-.1683,.1661],[-.1798,.1658],[-.1913,.1654],[-.2027,.1652],[-.2142,.1649],[-.2257,.1647],[-.2372,.1645],[-.2487,.1643],[-.2602,.1641],[-.2716,.164],[-.2831,.1639],[-.2946,.1638],[-.3061,.1637],[-.3176,.1637],[-.3291,.1637],[-.3405,.1637],[-.352,.1637],[-.3635,.1637],[-.375,.1637],[-.3865,.1638],[-.398,.1639],[-.4094,.164],[-.4209,.1641],[-.4324,.1642],[-.4439,.1643],[-.4554,.1645],[-.4668,.1646],[-.4783,.1648],[-.4898,.165],[-.5013,.1652],[-.5128,.1653],[-.5243,.1656],[-.5357,.1658],[-.5472,.166],[-.5587,.1662],[-.5702,.1664],[-.5817,.1666],[-.5932,.1669],[-.6046,.1671],[-.6161,.1673],[-.6276,.1676],[-.6391,.1678],[-.6506,.1681],[-.662,.1683],[-.6735,.1685],[-.685,.1688],[-.6965,.169],[-.708,.1692],[-.7195,.1694],[-.7309,.1697],[-.7424,.1699],[-.7539,.1701],[-.7654,.1703],[-.7769,.1705],[-.7884,.1707],[-.7998,.1708],[-.8113,.171],[-.8228,.1712],[-.8343,.1713],[-.8458,.1715],[-.8573,.1716],[-.8687,.1717],[-.8802,.1718],[-.8917,.1719],[-.9032,.1719],[-.9147,.172],[-.9261,.172],[-.9376,.172],[-.9491,.172],[-.9606,.172],[-.9721,.172],[-.9836,.1719],[-.995,.1718],[-1.0065,.1715],[-1.018,.171],[-1.0295,.1704],[-1.041,.1701],[-1.0525,.1709],[-1.0639,.1729],[-1.0754,.1758],[-1.0869,.1786],[-1.0984,.1792],[-1.1099,.1746],[-1.1213,.1659],[-1.1328,.1608],[-1.1443,.1637],[-1.1558,.1708],[-1.1673,.1781],[-1.1788,.1843],[-1.1902,.1893],[-1.2017,.1929],[-1.2132,.1951]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:4,centre:!1,f:.45,colour:[46,44,42],profile:[[-1.2151,.1986],[-1.2189,.2],[-1.2228,.2],[-1.2266,.2014],[-1.2304,.197],[-1.2343,.1868],[-1.2381,.1649]]}},{name:"booster",uv:[.6209,.4502,.9313,1],top:-.0363,end:-1.1118,profile:[[-.0363,.0057],[-.0477,.0241],[-.0592,.0337],[-.0707,.0416],[-.0822,.0486],[-.0937,.0552],[-.1051,.0617],[-.1166,.0681],[-.1281,.0747],[-.1396,.0814],[-.1511,.0881],[-.1626,.0944],[-.174,.0998],[-.1855,.1037],[-.197,.1058],[-.2085,.1066],[-.22,.1067],[-.2315,.1067],[-.2429,.1066],[-.2544,.1068],[-.2659,.1073],[-.2774,.1083],[-.2889,.1091],[-.3004,.1094],[-.3118,.1094],[-.3233,.1094],[-.3348,.1093],[-.3463,.1093],[-.3578,.1092],[-.3692,.1092],[-.3807,.1092],[-.3922,.1092],[-.4037,.1091],[-.4152,.1091],[-.4267,.109],[-.4381,.109],[-.4496,.109],[-.4611,.1089],[-.4726,.1089],[-.4841,.1088],[-.4956,.1088],[-.507,.1088],[-.5185,.1088],[-.53,.1087],[-.5415,.1087],[-.553,.1086],[-.5644,.1086],[-.5759,.1086],[-.5874,.1085],[-.5989,.1085],[-.6104,.1086],[-.6219,.1088],[-.6333,.1093],[-.6448,.1101],[-.6563,.1108],[-.6678,.1111],[-.6793,.1109],[-.6908,.1103],[-.7022,.11],[-.7137,.1103],[-.7252,.1107],[-.7367,.111],[-.7482,.111],[-.7596,.1109],[-.7711,.1109],[-.7826,.1109],[-.7941,.1108],[-.8056,.1108],[-.8171,.1107],[-.8285,.1107],[-.84,.1108],[-.8515,.1112],[-.863,.1122],[-.8745,.1136],[-.886,.1148],[-.8974,.1156],[-.9089,.1162],[-.9204,.1166],[-.9319,.1167],[-.9434,.1166],[-.9549,.1164],[-.9663,.116],[-.9778,.1156],[-.9893,.1151],[-1.0008,.1146],[-1.0123,.1141],[-1.0237,.1137],[-1.0352,.1133],[-1.0467,.1131],[-1.0582,.1128],[-1.0697,.1114],[-1.0812,.1064],[-1.0926,.0968],[-1.1041,.0871],[-1.1118,.0826]],at:[[.9146,.4364],[2.4853,.4364],[-.9146,.4364],[-2.4853,.4364]],fins:[{side:-1,uv:[.9313,.9131,.9935,1],x0:-.225,x1:.0015,y0:-.8802,y1:-1.0505,outline:[[-.8802,.1162,.1139],[-.886,.122,.1145],[-.8917,.1279,.115],[-.8974,.1338,.1154],[-.9032,.1397,.1158],[-.9089,.1456,.116],[-.9147,.1514,.1163],[-.9204,.1544,.1164],[-.9261,.1632,.1165],[-.9319,.1691,.1166],[-.9376,.175,.1166],[-.9434,.1809,.1166],[-.9491,.1868,.1165],[-.9549,.1926,.1163],[-.9606,.1985,.1162],[-.9663,.2044,.116],[-.9721,.2132,.1159],[-.9778,.2191,.1156],[-.9836,.222,.1154],[-.9893,.222,.1152],[-.995,.222,.115],[-1.0008,.222,.1147],[-1.0065,.222,.1145],[-1.0123,.222,.1143],[-1.018,.222,.1141],[-1.0237,.222,.1139],[-1.0295,.222,.1137],[-1.0352,.222,.1136],[-1.041,.222,.1135],[-1.0467,.1132,.1134],[-1.0486,.1132,.1133]]}],finsAround:2,finsFrom:null,engines:{ring:0,centre:!0,f:1,colour:[46,44,42],profile:[[-1.1118,.0747],[-1.1156,.0835],[-1.1194,.0893],[-1.1233,.0805],[-1.1271,.0688],[-1.1309,.0688],[-1.1347,.0717],[-1.1386,.0717],[-1.1424,.0746],[-1.1462,.0775],[-1.1501,.0775],[-1.1539,.0804],[-1.1577,.0834],[-1.1615,.0833],[-1.1654,.0863],[-1.1692,.0892],[-1.173,.0892],[-1.1768,.0921],[-1.1807,.0921],[-1.1845,.095],[-1.1883,.095],[-1.1922,.092],[-1.196,.0833],[-1.1998,.057]]}}],badge:{y:.9137,d:.312,r:.208},band:[.7245,.7435],head:{top:1.6,cut:1.1028,mean:.7484,r:.2618}},heavy:{id:"starship",shape:"heavy",atlas:{w:1029,h:1136,cap:[.9942,.9947,.9981,.9982]},parts:[{name:"core",uv:[0,.0986,.7464,1],top:1.6,end:-1.1224,profile:[[1.6,.0103],[1.5884,.0383],[1.5769,.0539],[1.5653,.0677],[1.5537,.0807],[1.5422,.0926],[1.5306,.1039],[1.519,.1146],[1.5075,.1248],[1.4959,.1347],[1.4843,.1444],[1.4727,.1536],[1.4612,.1626],[1.4496,.1712],[1.438,.1796],[1.4265,.1874],[1.4149,.1949],[1.4033,.2021],[1.3918,.2091],[1.3802,.216],[1.3686,.223],[1.3571,.2298],[1.3455,.2364],[1.3339,.2426],[1.3224,.2485],[1.3108,.254],[1.2992,.2593],[1.2877,.2642],[1.2761,.2688],[1.2645,.2731],[1.253,.2771],[1.2414,.2808],[1.2298,.2843],[1.2182,.2875],[1.2067,.2904],[1.1951,.2931],[1.1835,.2955],[1.172,.2978],[1.1604,.2998],[1.1488,.3015],[1.1373,.3031],[1.1257,.3045],[1.1141,.3057],[1.1026,.3067],[1.091,.3075],[1.0794,.3082],[1.0679,.3087],[1.0563,.3091],[1.0447,.3093],[1.0332,.3094],[1.0216,.3094],[1.01,.3092],[.9985,.309],[.9869,.3088],[.9753,.3085],[.9637,.3083],[.9522,.3081],[.9406,.308],[.929,.3082],[.9175,.3086],[.9059,.309],[.8943,.309],[.8828,.3089],[.8712,.3087],[.8596,.3085],[.8481,.3084],[.8365,.3085],[.8249,.3087],[.8134,.3088],[.8018,.309],[.7902,.3091],[.7787,.309],[.7671,.3087],[.7555,.3085],[.744,.3083],[.7324,.3081],[.7208,.308],[.7092,.3081],[.6977,.3082],[.6861,.3082],[.6745,.3082],[.663,.3083],[.6514,.3084],[.6398,.3083],[.6283,.3081],[.6167,.308],[.6051,.308],[.5936,.3081],[.582,.3082],[.5704,.308],[.5589,.3078],[.5473,.3077],[.5357,.3078],[.5242,.3079],[.5126,.308],[.501,.308],[.4895,.3081],[.4779,.3082],[.4663,.3082],[.4547,.3083],[.4432,.3084],[.4316,.3085],[.42,.3084],[.4085,.3084],[.3969,.3085],[.3853,.3086],[.3738,.3085],[.3622,.3083],[.3506,.3081],[.3391,.3078],[.3275,.3076],[.3159,.3076],[.3044,.3078],[.2928,.3083],[.2812,.3086],[.2697,.3086],[.2581,.3084],[.2465,.3082],[.2349,.3079],[.2234,.3077],[.2118,.3077],[.2002,.3079],[.1887,.3084],[.1771,.3087],[.1655,.3087],[.154,.3085],[.1424,.3083],[.1308,.308],[.1193,.3078],[.1077,.3076],[.0961,.3075],[.0846,.3075],[.073,.3077],[.0614,.3077],[.0499,.3078],[.0383,.3079],[.0267,.308],[.0152,.308],[.0036,.308],[-.008,.3082],[-.0196,.3083],[-.0311,.3083],[-.0427,.3084],[-.0543,.3084],[-.0658,.3082],[-.0774,.3081],[-.089,.308],[-.1005,.308],[-.1121,.3081],[-.1237,.3082],[-.1352,.3082],[-.1468,.3081],[-.1584,.3082],[-.1699,.3083],[-.1815,.3083],[-.1931,.3084],[-.2046,.3085],[-.2162,.3086],[-.2278,.3087],[-.2393,.3088],[-.2509,.3089],[-.2625,.3089],[-.2741,.3089],[-.2856,.3089],[-.2972,.3091],[-.3088,.3092],[-.3203,.3093],[-.3319,.3096],[-.3435,.31],[-.355,.3105],[-.3666,.3108],[-.3782,.3109],[-.3897,.3107],[-.4013,.3105],[-.4129,.3103],[-.4244,.3101],[-.436,.3098],[-.4476,.3096],[-.4591,.3094],[-.4707,.3091],[-.4823,.3089],[-.4938,.3087],[-.5054,.3085],[-.517,.3083],[-.5286,.308],[-.5401,.3078],[-.5517,.3076],[-.5633,.3074],[-.5748,.3071],[-.5864,.3069],[-.598,.3067],[-.6095,.3065],[-.6211,.3063],[-.6327,.306],[-.6442,.3058],[-.6558,.3056],[-.6674,.3054],[-.6789,.3052],[-.6905,.3049],[-.7021,.3047],[-.7136,.3045],[-.7252,.3043],[-.7368,.3041],[-.7484,.3038],[-.7599,.3036],[-.7715,.3034],[-.7831,.3032],[-.7946,.303],[-.8062,.3027],[-.8178,.3025],[-.8293,.3023],[-.8409,.3021],[-.8525,.3019],[-.864,.3017],[-.8756,.3014],[-.8872,.3012],[-.8987,.301],[-.9103,.3008],[-.9219,.3006],[-.9334,.3004],[-.945,.3002],[-.9566,.3],[-.9681,.2997],[-.9797,.2995],[-.9913,.2993],[-1.0029,.2991],[-1.0144,.2989],[-1.026,.2987],[-1.0376,.2985],[-1.0491,.2983],[-1.0607,.2981],[-1.0723,.2979],[-1.0838,.2976],[-1.0954,.2974],[-1.107,.2972],[-1.1185,.297],[-1.1224,.297]],at:[[0,0]],fins:[{side:-1,uv:[.7464,.8477,.9252,1],x0:-.4382,x1:0,y0:1.3532,y1:1.0197,outline:[[1.3532,.2286,.2293],[1.3474,.2334,.2327],[1.3416,.2405,.2359],[1.3359,.2477,.2391],[1.3301,.2548,.2421],[1.3243,.2619,.2451],[1.3185,.2691,.2481],[1.3127,.2762,.2509],[1.3069,.2834,.2537],[1.3012,.2905,.2563],[1.2954,.2976,.2589],[1.2896,.3048,.2615],[1.2838,.312,.2639],[1.278,.3191,.2663],[1.2722,.3262,.2686],[1.2664,.3334,.2709],[1.2607,.3405,.273],[1.2549,.3477,.2751],[1.2491,.3548,.2772],[1.2433,.362,.2791],[1.2375,.3691,.281],[1.2317,.3762,.2828],[1.226,.3834,.2846],[1.2202,.3905,.2863],[1.2144,.3977,.2879],[1.2086,.4024,.2895],[1.2028,.4096,.291],[1.197,.4143,.2925],[1.1913,.4191,.2939],[1.1855,.4191,.2952],[1.1797,.4191,.2965],[1.1739,.4215,.2977],[1.1681,.4215,.2989],[1.1623,.4215,.3],[1.1566,.4239,.301],[1.1508,.4239,.302],[1.145,.4239,.303],[1.1392,.4263,.3039],[1.1334,.4263,.3047],[1.1276,.4286,.3056],[1.1218,.4286,.3063],[1.1161,.431,.307],[1.1103,.431,.3077],[1.1045,.431,.3083],[1.0987,.4334,.3089],[1.0929,.4334,.3094],[1.0871,.4334,.3099],[1.0814,.4358,.3104],[1.0756,.4358,.3108],[1.0698,.4334,.3112],[1.064,.431,.3115],[1.0582,.4191,.3118],[1.0524,.4096,.3121],[1.0467,.3953,.3123],[1.0409,.3834,.3125],[1.0351,.3715,.3127],[1.0293,.3596,.3128],[1.0235,.312,.3129],[1.0216,.312,.313]]},{side:1,uv:[.7464,.6937,.9252,.846],x0:0,x1:.4382,y0:1.3532,y1:1.0197,outline:[[1.3532,.2334,.2293],[1.3474,.2405,.2327],[1.3416,.25,.2359],[1.3359,.2572,.2391],[1.3301,.2619,.2421],[1.3243,.2691,.2451],[1.3185,.2762,.2481],[1.3127,.2834,.2509],[1.3069,.2905,.2537],[1.3012,.2976,.2563],[1.2954,.3048,.2589],[1.2896,.312,.2615],[1.2838,.3191,.2639],[1.278,.3262,.2663],[1.2722,.3334,.2686],[1.2664,.3405,.2709],[1.2607,.3453,.273],[1.2549,.3524,.2751],[1.2491,.3596,.2772],[1.2433,.3691,.2791],[1.2375,.3739,.281],[1.2317,.381,.2828],[1.226,.3881,.2846],[1.2202,.3953,.2863],[1.2144,.4024,.2879],[1.2086,.4096,.2895],[1.2028,.4143,.291],[1.197,.4167,.2925],[1.1913,.4191,.2939],[1.1855,.4191,.2952],[1.1797,.4191,.2965],[1.1739,.4215,.2977],[1.1681,.4215,.2989],[1.1623,.4239,.3],[1.1566,.4239,.301],[1.1508,.4239,.302],[1.145,.4263,.303],[1.1392,.4263,.3039],[1.1334,.4263,.3047],[1.1276,.4286,.3056],[1.1218,.4286,.3063],[1.1161,.431,.307],[1.1103,.431,.3077],[1.1045,.431,.3083],[1.0987,.4334,.3089],[1.0929,.4334,.3094],[1.0871,.4334,.3099],[1.0814,.4358,.3104],[1.0756,.4358,.3108],[1.0698,.431,.3112],[1.064,.4239,.3115],[1.0582,.4143,.3118],[1.0524,.4024,.3121],[1.0467,.3905,.3123],[1.0409,.3786,.3125],[1.0351,.3667,.3127],[1.0293,.3548,.3128],[1.0235,.3143,.3129],[1.0216,.3143,.313]]},{side:-1,uv:[.7464,.3477,.9922,.6919],x0:-.5301,x1:0,y0:-.3743,y1:-1.1282,outline:[[-.3743,.3059,.3036],[-.3801,.308,.3037],[-.3859,.3101,.3038],[-.3917,.3101,.3038],[-.3974,.3122,.3038],[-.4032,.3143,.3038],[-.409,.3164,.3038],[-.4148,.3206,.3038],[-.4206,.3226,.3038],[-.4264,.3248,.3038],[-.4322,.3268,.3038],[-.4379,.3289,.3038],[-.4437,.3331,.3038],[-.4495,.3373,.3038],[-.4553,.3415,.3038],[-.4611,.3457,.3038],[-.4669,.3499,.3038],[-.4726,.3541,.3038],[-.4784,.3583,.3038],[-.4842,.3625,.3038],[-.49,.3666,.3038],[-.4958,.3708,.3038],[-.5016,.3729,.3038],[-.5073,.3771,.3038],[-.5131,.3813,.3038],[-.5189,.3855,.3038],[-.5247,.3897,.3038],[-.5305,.3939,.3038],[-.5363,.3981,.3038],[-.5421,.4023,.3038],[-.5478,.4064,.3038],[-.5536,.4106,.3038],[-.5594,.4148,.3038],[-.5652,.419,.3038],[-.571,.4232,.3038],[-.5768,.4274,.3038],[-.5825,.4316,.3038],[-.5883,.4358,.3038],[-.5941,.4379,.3038],[-.5999,.4421,.3038],[-.6057,.4463,.3038],[-.6115,.4504,.3038],[-.6172,.4546,.3038],[-.623,.4588,.3038],[-.6288,.463,.3038],[-.6346,.4672,.3038],[-.6404,.4714,.3038],[-.6462,.4756,.3038],[-.6519,.4777,.3038],[-.6577,.4819,.3038],[-.6635,.4861,.3038],[-.6693,.4903,.3038],[-.6751,.4944,.3038],[-.6809,.4986,.3038],[-.6867,.5028,.3038],[-.6924,.5049,.3038],[-.6982,.507,.3038],[-.704,.5091,.3038],[-.7098,.5091,.3038],[-.7156,.5091,.3038],[-.7214,.5091,.3038],[-.7271,.5091,.3038],[-.7329,.5091,.3038],[-.7387,.5091,.3038],[-.7445,.5112,.3038],[-.7503,.5112,.3038],[-.7561,.5112,.3038],[-.7618,.5112,.3038],[-.7676,.5112,.3038],[-.7734,.5133,.3038],[-.7792,.5133,.3038],[-.785,.5133,.3038],[-.7908,.5133,.3038],[-.7966,.5133,.3038],[-.8023,.5154,.3038],[-.8081,.5154,.3038],[-.8139,.5154,.3038],[-.8197,.5154,.3038],[-.8255,.5154,.3038],[-.8313,.5154,.3038],[-.837,.5175,.3038],[-.8428,.5175,.3038],[-.8486,.5175,.3038],[-.8544,.5175,.3038],[-.8602,.5175,.3038],[-.866,.5196,.3038],[-.8717,.5196,.3038],[-.8775,.5196,.3038],[-.8833,.5196,.3038],[-.8891,.5196,.3038],[-.8949,.5217,.3038],[-.9007,.5217,.3038],[-.9064,.5217,.3038],[-.9122,.5217,.3038],[-.918,.5217,.3038],[-.9238,.5238,.3038],[-.9296,.5238,.3038],[-.9354,.5238,.3038],[-.9412,.5238,.3038],[-.9469,.5259,.3038],[-.9527,.5259,.3038],[-.9585,.5259,.3038],[-.9643,.5259,.3038],[-.9701,.5259,.3038],[-.9759,.528,.3038],[-.9816,.528,.3038],[-.9874,.528,.3038],[-.9932,.5259,.3038],[-.999,.5217,.3038],[-1.0048,.5112,.3038],[-1.0106,.4986,.3038],[-1.0163,.484,.3038],[-1.0221,.4693,.3038],[-1.0279,.4546,.3038],[-1.0337,.4379,.3038],[-1.0395,.4253,.3038],[-1.0453,.4086,.3038],[-1.0511,.396,.3038],[-1.0568,.3813,.3038],[-1.0626,.3666,.3038],[-1.0684,.3541,.3038],[-1.0742,.3541,.3038],[-1.08,.3541,.3038],[-1.0858,.3541,.3038],[-1.0915,.3541,.3038],[-1.0973,.3541,.3038],[-1.1031,.3541,.3038],[-1.1089,.352,.3038],[-1.1147,.3436,.3038],[-1.1205,.3352,.3038],[-1.1262,.3268,.3038]]},{side:1,uv:[.7464,.0018,.9922,.346],x0:0,x1:.5301,y0:-.3743,y1:-1.1282,outline:[[-.3743,.308,.3036],[-.3801,.3101,.3037],[-.3859,.3122,.3038],[-.3917,.3143,.3038],[-.3974,.3164,.3038],[-.4032,.3185,.3038],[-.409,.3206,.3038],[-.4148,.3226,.3038],[-.4206,.3268,.3038],[-.4264,.3289,.3038],[-.4322,.331,.3038],[-.4379,.3331,.3038],[-.4437,.3373,.3038],[-.4495,.3394,.3038],[-.4553,.3436,.3038],[-.4611,.3478,.3038],[-.4669,.3499,.3038],[-.4726,.3541,.3038],[-.4784,.3583,.3038],[-.4842,.3625,.3038],[-.49,.3666,.3038],[-.4958,.3708,.3038],[-.5016,.375,.3038],[-.5073,.3792,.3038],[-.5131,.3834,.3038],[-.5189,.3876,.3038],[-.5247,.3918,.3038],[-.5305,.396,.3038],[-.5363,.4002,.3038],[-.5421,.4044,.3038],[-.5478,.4086,.3038],[-.5536,.4127,.3038],[-.5594,.4148,.3038],[-.5652,.4211,.3038],[-.571,.4253,.3038],[-.5768,.4295,.3038],[-.5825,.4316,.3038],[-.5883,.4358,.3038],[-.5941,.44,.3038],[-.5999,.4442,.3038],[-.6057,.4484,.3038],[-.6115,.4526,.3038],[-.6172,.4567,.3038],[-.623,.4609,.3038],[-.6288,.4651,.3038],[-.6346,.4693,.3038],[-.6404,.4735,.3038],[-.6462,.4756,.3038],[-.6519,.4798,.3038],[-.6577,.484,.3038],[-.6635,.4882,.3038],[-.6693,.4924,.3038],[-.6751,.4966,.3038],[-.6809,.5007,.3038],[-.6867,.5049,.3038],[-.6924,.507,.3038],[-.6982,.5091,.3038],[-.704,.5091,.3038],[-.7098,.5112,.3038],[-.7156,.5112,.3038],[-.7214,.5112,.3038],[-.7271,.5112,.3038],[-.7329,.5133,.3038],[-.7387,.5133,.3038],[-.7445,.5133,.3038],[-.7503,.5133,.3038],[-.7561,.5133,.3038],[-.7618,.5154,.3038],[-.7676,.5154,.3038],[-.7734,.5154,.3038],[-.7792,.5154,.3038],[-.785,.5154,.3038],[-.7908,.5154,.3038],[-.7966,.5175,.3038],[-.8023,.5175,.3038],[-.8081,.5175,.3038],[-.8139,.5175,.3038],[-.8197,.5175,.3038],[-.8255,.5175,.3038],[-.8313,.5175,.3038],[-.837,.5196,.3038],[-.8428,.5196,.3038],[-.8486,.5196,.3038],[-.8544,.5196,.3038],[-.8602,.5196,.3038],[-.866,.5196,.3038],[-.8717,.5217,.3038],[-.8775,.5217,.3038],[-.8833,.5217,.3038],[-.8891,.5217,.3038],[-.8949,.5217,.3038],[-.9007,.5217,.3038],[-.9064,.5238,.3038],[-.9122,.5238,.3038],[-.918,.5238,.3038],[-.9238,.5238,.3038],[-.9296,.5238,.3038],[-.9354,.5238,.3038],[-.9412,.5259,.3038],[-.9469,.5259,.3038],[-.9527,.5259,.3038],[-.9585,.5259,.3038],[-.9643,.5259,.3038],[-.9701,.528,.3038],[-.9759,.528,.3038],[-.9816,.528,.3038],[-.9874,.5259,.3038],[-.9932,.5238,.3038],[-.999,.5196,.3038],[-1.0048,.507,.3038],[-1.0106,.4924,.3038],[-1.0163,.4777,.3038],[-1.0221,.463,.3038],[-1.0279,.4484,.3038],[-1.0337,.4337,.3038],[-1.0395,.4211,.3038],[-1.0453,.4044,.3038],[-1.0511,.3897,.3038],[-1.0568,.375,.3038],[-1.0626,.3625,.3038],[-1.0684,.3562,.3038],[-1.0742,.3562,.3038],[-1.08,.3562,.3038],[-1.0858,.3562,.3038],[-1.0915,.3541,.3038],[-1.0973,.3541,.3038],[-1.1031,.3541,.3038],[-1.1089,.3499,.3038],[-1.1147,.3436,.3038],[-1.1205,.3352,.3038],[-1.1262,.3289,.3038]]}],finsAround:2,finsFrom:null,engines:{ring:3,centre:3,f:.3,colour:[75,68,59],profile:[[-1.1224,.3256],[-1.1262,.3204],[-1.1301,.3142],[-1.134,.31],[-1.1378,.3059],[-1.1417,.3017],[-1.1455,.2965],[-1.1494,.2883],[-1.1532,.2759],[-1.1571,.2636],[-1.161,.2533],[-1.1648,.2431],[-1.1687,.243],[-1.1725,.243],[-1.1764,.2439],[-1.1802,.2439],[-1.1841,.2438],[-1.1879,.2417],[-1.1918,.2396],[-1.1957,.2355],[-1.1995,.2293],[-1.2034,.2201],[-1.2072,.2058],[-1.2111,.1864],[-1.2149,.0845],[-1.2188,.0814],[-1.2226,.0784],[-1.2265,.0722],[-1.2304,.0651],[-1.2342,.0529],[-1.2381,.0325]]}}],badge:{y:.9137,d:.4632,r:.3088},band:[.6489,.6679],head:null}};var yh={falcon9:"falcon9",falconHeavy:"falcon-heavy",newGlenn:"new-glenn",vulcan:"vulcan",cz2f:"long-march-2f",cz5:"long-march-5",cz3b:"long-march-3b",heavy:"starship"},$f=Object.keys(yh);var vx=[64,18],Fc=(i,t,e)=>i+(t-i)*e;function Zf(i,t){if(i.length<3)return i;let e=new Uint8Array(i.length);e[0]=e[i.length-1]=1;let n=[[0,i.length-1]];for(;n.length;){let[s,r]=n.pop(),[a,o]=i[s],[l,c]=i[r],h=l-a,f=c-o,u=Math.hypot(h,f)||1,d=-1,g=-1;for(let _=s+1;_<r;_++){let m=Math.abs(f*(i[_][0]-a)-h*(i[_][1]-o))/u;m>d&&(d=m,g=_)}d>t&&(e[g]=1,n.push([s,g],[g,r]))}return i.filter((s,r)=>e[r])}var yx=[.0015,.005];function Mx(i,t,e){let[n,s,r,a]=i.uv,o=Zf(i.profile,e).map(([f,u])=>new ft(Math.max(4e-4,u),f)).reverse();o.push(new ft(1e-4,i.profile[0][0]+4e-4));let l=new yr(o,t),c=l.attributes.uv,h=l.attributes.position;for(let f=0;f<c.count;f++){let u=Math.min(1,Math.max(0,(h.getY(f)-i.end)/(i.top-i.end)));c.setXY(f,Fc(n,r,c.getX(f)),Fc(s,a,u))}return l}function Sx(i,t,e){let n=i.profile[i.profile.length-1][1],s=new Sa(n,e);s.rotateX(Math.PI/2),s.translate(0,i.end,0);let[r,a,o,l]=t.cap,c=s.attributes.uv;for(let h=0;h<c.count;h++)c.setXY(h,(r+o)/2,(a+l)/2);return s}function bx(i,t){let e=new qi,n=i.outline.map(([f,u,d])=>{let g=t?t(f,d):0;return[f,Math.max(d,u)+g,d+g]});n.forEach(([f,u],d)=>d?e.lineTo(u,f):e.moveTo(u,f));for(let f=n.length-1;f>=0;f--)e.lineTo(n[f][2]-.004,n[f][0]);let s=new Na(e),[r,a,o,l]=i.uv,c=s.attributes.position,h=s.attributes.uv;for(let f=0;f<c.count;f++){let u=c.getY(f),d=c.getX(f);if(t){let _=i.outline[0];for(let m of i.outline)Math.abs(m[0]-u)<Math.abs(_[0]-u)&&(_=m);d-=t(u,_[2])}let g=i.side*d;h.setXY(f,Fc(r,o,(g-i.x0)/(i.x1-i.x0)),Fc(a,l,(u-i.y1)/(i.y0-i.y1)))}return s}function Ex(i,t){return t===4?i.side<0?[Math.PI,Math.PI/2,-Math.PI/2]:[0]:[i.side<0?Math.PI:0]}function Tx(i,t,e){if(!i||i.profile.length<3)return[];let n=Math.max(...i.profile.map(([,h])=>h)),s=i.ring?n*(1-i.f):0,r=n-s,a=i.profile.filter(([,h])=>h-s>r*.25);if(a.length<3)return[];let o=Zf(a,e).map(([h,f])=>new ft(Math.max(4e-4,f-s),h)).reverse(),l=new yr(o,Math.max(10,t>>1)),c=[];if(i.ring)for(let h=0;h<i.ring;h++)c.push([s,h/i.ring*Math.PI*2+Math.PI/i.ring,1]);if(i.centre===!0)c.push([0,0,1]);else if(typeof i.centre=="number")for(let h=0;h<i.centre;h++)c.push([s*.38,h/i.centre*Math.PI*2,.62]);return c.map(([h,f,u])=>{let d=l.clone();return d.scale(u,1,u),d.translate(Math.sin(f)*h,(1-u)*.05,Math.cos(f)*h),d})}var wx=([i,t])=>new De().makeTranslation(Math.sin(i)*t,0,Math.cos(i)*t).multiply(new De().makeRotationY(i+Math.PI/2)),_h=new Map;function Jf(i,t){let e=`${i}|${t?1:0}`;if(_h.has(e))return _h.get(e);let n=po[i],s=vx.map(c=>t?Math.max(12,c>>1):c).map((c,h)=>{let f=yx[h]*(t?1.6:1),u=[],d=[],g=n.parts.find(_=>_.name==="booster");for(let _ of n.parts){let m=[Mx(_,c,f),Sx(_,n.atlas,c)],p=_.fins.length?_:_.finsFrom==="booster"&&g?g:null;if(p)for(let v of p.fins){let b=p!==_?(E,C)=>{let y=_.profile[0];for(let w of _.profile)Math.abs(w[0]-E)<Math.abs(y[0]-E)&&(y=w);return y[1]-C}:null;for(let E of Ex(v,p===_?_.finsAround:4)){let C=bx(v,b);C.rotateY(E),m.push(C)}}let S=Tx(_.engines,c,f),A=_.name==="core"?[null]:_.at;for(let v of A){let b=v?wx(v):null;for(let E of m)u.push(b?E.clone().applyMatrix4(b):E);for(let E of S)d.push(b?E.clone().applyMatrix4(b):E)}}return{hull:Uc(u),bells:d.length?Uc(d):null}}),r=0,a=s[0].hull.attributes.position;for(let c=0;c<a.count;c++)r=Math.max(r,Math.hypot(a.getX(c),a.getZ(c)));let o=[];for(let c of n.parts)if(c.name!=="core"&&c.engines)for(let[h,f]of c.at){let u=Math.max(...c.engines.profile.map(([,d])=>d));o.push({x:Math.sin(h)*f,z:Math.cos(h)*f,r:u})}let l={levels:s,span:r,nozzles:o};return _h.set(e,l),l}var vh=new Map;function Kf(i){if(vh.has(i))return vh.get(i);let t=po[i],e=t.parts.find(o=>o.name==="core"),n=o=>{let l=e.profile[0];for(let c of e.profile)Math.abs(c[0]-o)<Math.abs(l[0]-o)&&(l=c);return l[1]},s=i==="heavy"?-.25:0,r=[];for(let o of[0,Math.PI]){let c=[],h=[],f=[],u=t.badge.d;for(let g=0;g<=10;g++)for(let _=0;_<=10;_++){let m=(_/10-.5)*u,p=(g/10-.5)*u,S=t.badge.y+p,A=n(S)+.004,v=o+s+m/A;c.push(Math.sin(v)*A,S,Math.cos(v)*A),h.push(_/10,g/10)}for(let g=0;g<10;g++)for(let _=0;_<10;_++){let m=g*11+_,p=m+1,S=m+10+1,A=S+1;f.push(m,p,A,m,A,S)}let d=new Ie;d.setAttribute("position",new pe(c,3)),d.setAttribute("uv",new pe(h,2)),d.setIndex(f),d.computeVertexNormals(),r.push(d)}let a=Uc(r);return vh.set(i,a),a}function jf(i){let t=po[i];if(!t?.head)return null;let e=t.parts.find(s=>s.name==="core").profile,n=s=>{for(let r=1;r<e.length;r++)if(e[r][0]<=s){let[a,o]=e[r-1],[l,c]=e[r];return a===l?c:c+(o-c)*(s-l)/(a-l)}return e[e.length-1][1]};return{cut:t.head.cut,top:t.head.top,r:n}}var Ax=`
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
#endif`;function Qf(i,{near:t,envMap:e,head:n,band:s,pattern:r}){let a=po[i],o=i==="heavy",l=a.parts.find(g=>g.name==="core"),c=Math.max(...l.profile.map(([,g])=>g))*1.06,h=t?Fa:Vn,f=new h({metalness:1,roughness:1,side:En,alphaTest:.5,envMap:e,envMapIntensity:o?2.6:.95,...t?{clearcoat:o?0:.3,clearcoatRoughness:.35,bumpScale:o?0:1.1}:{}}),u=2.84/120,d={uHeadOn:{value:n&&a.head?1:0},uHead:{value:new se(n??"#ffffff")},uMean:{value:a.head?.mean??.7},uCut:{value:a.head?.cut??99},uTop:{value:a.head&&a.head.top<1.59?a.head.top:99},uFeather:{value:.4*u},uCoreR:{value:c},uBand:{value:new ft(a.band[0],a.band[1])},uBandC:{value:new se(s??"#888888")},uPat:{value:r?.texture??null},uPatOn:{value:r?.texture?1:0},uSpan:{value:new ft(a.head?.cut??0,a.head?.top??1)}};return o&&f.color.setScalar(1.35),f.userData.livery=d,f.defines={MP_LIVERY:""},f.onBeforeCompile=g=>{Object.assign(g.uniforms,d),g.vertexShader=g.vertexShader.replace("#include <common>",`#include <common>
varying vec3 vObj;`).replace("#include <begin_vertex>",`#include <begin_vertex>
vObj = position;`),g.fragmentShader=g.fragmentShader.replace("#include <common>",`#include <common>
varying vec3 vObj;
uniform float uHeadOn, uMean, uCut, uTop, uFeather, uCoreR, uPatOn;
uniform vec3 uHead, uBandC;
uniform vec2 uBand, uSpan;
uniform sampler2D uPat;`).replace("#include <map_fragment>","#include <map_fragment>"+Ax)},f.customProgramCacheKey=()=>`mp-hull-${t?1:0}`,f}var td=(i,t,e)=>`${i}art/rockets/${yh[t]}-${e}.webp`,ed=(i,t)=>`${i}art/rockets/${yh[t]}-mat.webp`;function nd(i,t={}){let e=t.studio??null,n={},s=O=>n[O]||"#b8b0a8",r={openai:"OpenAI",anthropic:"Anthropic",zhipuai:"ZHIPU",xai:"xAI",alibaba:"Qwen",deepseek:"DeepSeek",kimi:"Kimi",minimax:"MiniMax",xiaomi:"Xiaomi",tencent:"Tencent",google:"Google",meta:"Meta"},a="./assets/",o={logos:Object.fromEntries(Object.entries({openai:"openai-white.svg",anthropic:"claude-rounded.svg",zhipuai:"zhipu.svg",xai:"x-white.svg",alibaba:"qwen.svg",deepseek:"deepseek.svg",kimi:"kimi-white.svg",minimax:"minimax.svg",google:"gemini.svg",xiaomi:"xiaomi.svg",meta:null}).filter(([,O])=>O).map(([O,vt])=>[O,`${a}brands/${vt}`]))},l="varying vec2 vUv; varying float vR; void main(){ vUv=uv; vR=abs(dot(normalize(normalMatrix*normal),vec3(0.,0.,1.))); gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",c="uniform float t; uniform float k; uniform vec3 c0; uniform vec3 c1; varying vec2 vUv; varying float vR; void main(){ float a=vUv.y; float fl=.82+.18*sin(t*38.+a*22.)+.08*sin(t*61.+vUv.x*40.); float dia=.85+.15*sin(a*26.-t*20.); float alpha=pow(1.-a,1.5)*fl*dia*k*(.35+.65*pow(vR,1.2)); vec3 col=mix(c0,c1,smoothstep(0.,.55,a)); gl_FragColor=vec4(col*alpha*1.7,alpha); }",h="uniform float t; uniform float k; uniform vec3 gc; uniform vec3 sc; uniform float sm; varying vec2 vUv; varying float vR; void main(){ float y=vUv.y; float n=.75+.25*sin(t*3.+y*30.+vUv.x*20.); float glow=pow(y,3.)*.7; float smoke=pow(y,1.2)*(1.-y)*sm*n; vec3 col=gc*glow+sc*smoke; float a=(glow+smoke)*k*pow(vR,1.4); gl_FragColor=vec4(col*a,a); }",f="uniform float t; uniform float k; varying vec2 vUv; varying float vR; float h(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); } float nz(vec2 p){ vec2 i=floor(p),f=fract(p); f=f*f*(3.-2.*f); return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y); } void main(){ float y=vUv.y; vec2 p=vec2(vUv.x*6.,y*5.+t*1.6); float n=nz(p)*.6+nz(p*2.3)*.4; float a=smoothstep(.2,.75,y)*(1.-smoothstep(.92,1.,y))*smoothstep(.3,.72,n)*k*pow(vR,.6)*.85; vec3 c=mix(vec3(.30,.27,.25),vec3(.62,.36,.2),smoothstep(.55,1.,y)); gl_FragColor=vec4(c*(.75+.25*n),a); }",u={hi:{o:["#8cc8ff","#1d5cff"],i:["#e2f1ff","#4f9dff"],light:"#7fb6ff",gc:[.45,.7,1],sc:[.55,.65,.85],sm:.35,soot:!1,label:"\u9AD8\u6548 \xB7 \u84DD\u7130",tip:"\u540C\u6837\u7684\u6210\u672C\u80FD\u529B\u660E\u663E\u66F4\u9AD8\uFF0C\u6216\u6CA1\u6709\u4EFB\u4F55\u6A21\u578B\u6BD4\u5B83\u53C8\u4FBF\u5B9C\u53C8\u5F3A"},mid:{o:["#ffd9a0","#ff5a24"],i:["#ffffff","#8fd0ff"],light:"#ffa060",gc:[1,.55,.25],sc:[.6,.66,.8],sm:.5,soot:!1,label:"\u6807\u51C6",tip:"\u80FD\u529B\u4E0E\u6210\u672C\u5927\u81F4\u5728\u8D8B\u52BF\u7EBF\u4E0A"},lo:{o:["#ff9446","#9a2406"],i:["#ffcf90","#e0601c"],light:"#ff7a3a",gc:[.9,.38,.12],sc:[.28,.24,.22],sm:.75,soot:!0,label:"\u4F4E\u6548 \xB7 \u9ED1\u70DF",tip:"\u540C\u6837\u7684\u6210\u672C\uFF0C\u80FD\u529B\u660E\u663E\u4F4E\u4E8E\u8D8B\u52BF\u7EBF"}},d=new Map,g=new Map;function _(O){return d.has(O)||d.set(O,new Promise(vt=>{let St=new Image;St.onload=()=>vt(St),St.onerror=()=>vt(null),St.src=O.includes("/")?O:`${a}brands/${O}`})),d.get(O)}function m(O,vt){let St=`${O.src}|${vt}`;if(!g.has(St)){let Et=document.createElement("canvas");Et.width=Et.height=128;let Xt=Et.getContext("2d");Xt.drawImage(O,0,0,128,128),Xt.globalCompositeOperation="source-in",Xt.fillStyle=vt,Xt.fillRect(0,0,128,128),g.set(St,Et)}return g.get(St)}let p=-1.24,S=1.6,A=(S-p)/120,v=typeof innerWidth=="number"&&innerWidth<600,b=v?256:512,E={openai:"#f3f3f1",xai:"#2e3238",zhipuai:"#b9c2cc"},C={alibaba:"qwen.svg",xiaomi:"xiaomi-mi.svg"},y={xiaomi:["#ff8a33","#ff6900","#e65c00"]},w={xiaomi:.8},I=i??(e?(e.mapping=Ar,e):null),N=new za,H=new Map,W=(O,vt)=>(H.has(O)||H.set(O,new Promise(St=>N.load(O,Et=>{Et.colorSpace=vt?Ke:di,Et.anisotropy=4,Et.userData.shared=!0,St(Et)},void 0,()=>St(null)))),H.get(O)),U=new Map;function G(O,vt,St){let Et=`${St}|${O}|${vt}`;return U.has(Et)||U.set(Et,(async()=>{let Xt=jf(St);if(!Xt)return null;let gt=Nc(O,vt),J=gt.glyph?await _(gt.glyph):null,q=O==="xai"?E.xai:gt.base,ht=Xt.top-Xt.cut,wt=ht>.2,ct=v?256:512,Ft=ct/2,ae=document.createElement("canvas");ae.width=ct,ae.height=Ft;let K=ae.getContext("2d"),ut=Jt=>Ft*(1-Jt),yt=Jt=>Xt.cut+Jt*ht,xt=wt?{lattice:[.17,.43,.69],diagonal:[.17,.43,.69],rings:[.25,.58],split:[.22,.62]}[gt.pattern]:[.4],_t=Math.max(...xt.map(Jt=>Xt.r(yt(Jt)))),Gt=.46,Bt=.8,Zt=xt.length>1?(xt[1]-xt[0])*ht:ht,ne=Math.min(.085,Zt*(wt?.62:.5));if(K.fillStyle=q,K.fillRect(0,0,ct,Ft),wt&&gt.pattern==="split"&&(K.fillStyle=gt.ink,K.fillRect(0,0,ct,ut(Gt))),wt&&gt.pattern==="rings"){let Jt=Math.max(1,.014/ht*Ft);for(let oe of xt)for(let T of[-.12,.12])K.fillStyle=gt.ink,K.fillRect(0,ut(oe+T)-Jt/2,ct,Jt)}if(wt&&gt.pattern==="diagonal"){K.save(),K.strokeStyle=gt.ink,K.globalAlpha=.35,K.lineWidth=ct/170;for(let Jt=-ct;Jt<ct*2;Jt+=ct/6)K.beginPath(),K.moveTo(Jt,ut(.08)),K.lineTo(Jt+ct*.55,ut(Bt)),K.stroke();K.restore()}if(J&&xt.forEach((Jt,oe)=>{let T=Xt.r(yt(Jt)),x=Math.max(.25,T/_t),k=gt.pattern==="rings",X=ne*(k?.85:1),et=Math.max(3,Math.round((k?8:5)*x)),bt=ct/et,Rt=X/(2*Math.PI*T)*ct,it=X/ht*Ft,ot=gt.pattern==="diagonal"?oe*bt/2:oe%2?bt/2:0;for(let It=-1;It<=et;It++){let Qt=gt.pattern==="split"&&Jt>Gt?q:gt.inks?gt.inks[((It+oe)%gt.inks.length+gt.inks.length)%gt.inks.length]:gt.ink;K.save(),K.translate(It*bt+ot,ut(Jt)),K.scale(Rt/it,1),gt.pattern==="diagonal"&&K.rotate(-.45),K.drawImage(m(J,Qt),-it/2,-it/2,it,it),K.restore()}}),K.fillStyle=gt.cap,K.fillRect(0,0,ct,ut(Bt)),wt){let Jt=[...gt.trim,...gt.trim];Jt.forEach((oe,T)=>{K.fillStyle=oe,K.fillRect(T*ct/Jt.length,ut(.055),ct/Jt.length+1,Ft*.055+1)})}let L=new Kn(ae);return L.colorSpace=Ke,L.wrapS=ns,L.anisotropy=4,L.userData.shared=!0,L})()),U.get(Et)}let rt=new Map;function j(O,vt){let St=`${O}|${vt}`;if(!rt.has(St)){let Xt=document.createElement("canvas");Xt.width=Xt.height=256;let gt=new Kn(Xt);gt.colorSpace=Ke,gt.anisotropy=4,gt.userData.shared=!0;let J=ht=>{let wt=Xt.getContext("2d"),ct=256/2,Ft=256/2-1;wt.clearRect(0,0,256,256);let ae=wt.createRadialGradient(ct-Ft*.3,ct-Ft*.35,Ft*.05,ct,ct,Ft),K=y[O];if(ae.addColorStop(0,K?.[0]??"#2c3443"),ae.addColorStop(.6,K?.[1]??"#11151d"),ae.addColorStop(1,K?.[2]??"#07090d"),wt.beginPath(),wt.arc(ct,ct,Ft,0,Math.PI*2),wt.fillStyle=ae,wt.fill(),wt.save(),wt.clip(),wt.beginPath(),wt.ellipse(ct-Ft*.12,ct-Ft*.58,Ft*.7,Ft*.3,-.25,0,7),wt.fillStyle="rgba(255,255,255,.08)",wt.fill(),wt.restore(),wt.beginPath(),wt.arc(ct,ct,256*.47,0,Math.PI*2),wt.strokeStyle=vt,wt.lineWidth=256*.045,wt.stroke(),ht){let ut=194.56*(w[O]??1);wt.drawImage(m(ht,"#ffffff"),ct-ut/2,ct-ut/2,ut,ut)}else wt.fillStyle="#ffffff",wt.font=`800 ${Math.round(256*.5)}px 'Manrope', sans-serif`,wt.textAlign="center",wt.textBaseline="middle",wt.fillText((r[O]??O)[0]??"?",ct,ct+256*.03);gt.needsUpdate=!0};J(null);let q=C[O]??Nc(O).glyph??o.logos[O];q&&_(q).then(ht=>ht&&J(ht)),rt.set(St,gt)}return rt.get(St)}let pt=t.lodDistance??7;function st(O,vt,St,Et,Xt,gt,J){let q=Jf(O,v),ht=O==="heavy",wt=Nc(vt,St).colour,ct=ht?null:E[vt]??wt,Ft=new Qe;Ft.rotation.y=.4*Math.PI;let ae=new ga;Ft.add(ae);let K=new Vn({map:j(vt,wt),transparent:!0,alphaTest:.5,roughness:.32,metalness:.15,envMap:I,envMapIntensity:.8,polygonOffset:!0,polygonOffsetFactor:-2}),ut=new Vn({color:ht?"#9a9590":"#6d6a66",metalness:.9,roughness:.38,side:En,transparent:!0,forceSinglePass:!0,envMap:I,envMapIntensity:1.2});Et.push(K,ut);let yt=Kf(O);yt.userData.shared=!0;let xt=q.levels.map((_t,Gt)=>{_t.hull.userData.shared=!0,_t.bells&&(_t.bells.userData.shared=!0);let Bt=Qf(O,{near:Gt===0&&!v,envMap:I,head:ct,band:wt});Object.defineProperty(Bt,"transparent",{get(){return this.opacity<.999},set(){},configurable:!0}),Bt.forceSinglePass=!0,Et.push(Bt);let Zt=new Qe,ne=new Se(_t.hull,Bt);return ne.visible=!1,Zt.add(ne,new Se(yt,K)),_t.bells&&Zt.add(new Se(_t.bells,ut)),ae.addLevel(Zt,Gt===0?0:pt),{mat:Bt,body:ne}});Promise.all([W(td(a,O,b),!0),W(ed(a,O),!1)]).then(([_t,Gt])=>{if(_t)for(let{mat:Bt,body:Zt}of xt)Bt.map=_t,Bt.isMeshPhysicalMaterial?(Bt.metalnessMap=Bt.roughnessMap=Gt,ht||(Bt.bumpMap=_t)):(Bt.metalness=ht?.75:.04,Bt.roughness=ht?.36:.42),Bt.needsUpdate=!0,Zt.visible=!0}),ct&&t.headPattern!==!1&&G(vt,wt,O).then(_t=>{if(_t)for(let{mat:Gt}of xt){let Bt=Gt.userData.livery;Bt.uPat.value=_t,Bt.uPatOn.value=1}});for(let _t of q.nozzles){let Gt=gt(_t.r*.95,.6+_t.r*2,Xt("#ffd9a0","#ff5a24"));Gt.position.x=_t.x,Gt.position.z=_t.z,Ft.add(Gt),J.push(Gt)}return Ft.userData.span=q.span,Ft}function lt(O){let vt=s(O.dev),St=new Qe,Et=[],Xt=At=>(Et.push(At),At),gt=$f.includes(O.shape)&&O.shape!=="heavy"?O.shape:mh(O.dev,ph(O.id)),J=document.createElement("canvas");J.width=J.height=2;let q=new Kn(J),ht=q,wt=q,ct=Xt(new Vn({map:q})),Ft=(At,Lt)=>new He({transparent:!0,depthWrite:!1,blending:hn,uniforms:{t:{value:0},k:{value:1},c0:{value:new se(At)},c1:{value:new se(Lt)}},vertexShader:l,fragmentShader:c}),ae=(At,Lt,ee)=>{let fe=new ba(At,Lt,32,1,!0);fe.rotateX(Math.PI),fe.translate(0,-Lt/2,0);let F=new Se(fe,ee);return F.position.y=p+.02,F},K=new Qe;St.add(K);let ut=[],yt=st(gt,O.dev,vt,Et,Ft,ae,ut);K.add(yt);let xt=yt.userData.span,_t=[K],Gt=ae(.26,1.7,Ft("#ffd9a0","#ff5a24")),Bt=ae(.12,.95,Ft("#ffffff","#8fd0ff"));St.add(Gt,Bt);let Zt=new Ga("#ffa060",1.5,6,2);Zt.position.y=-1.7,St.add(Zt);let ne=new Qe;ne.position.y=.15,ne.visible=!1;let L=new Se(new Yi(.6,.016,10,160),new an({color:"#d99a2b",transparent:!0,opacity:.95}));L.rotation.x=Math.PI/2-.38,ne.add(L);let Jt=new Se(new jn(.036,16,12),new an({color:"#ffd27a"}));Jt.position.set(.6,0,0),L.add(Jt);let oe=new Qe;oe.visible=!1,St.add(oe);let T=st("heavy",O.dev,vt,Et,Ft,ae,[]);oe.add(T);let x=p,k=T.userData.span,X=ne,et=new Qe;et.visible=!1,St.add(et);let bt=new qi;bt.moveTo(0,0),bt.lineTo(.34,-.5),bt.lineTo(.36,-.66),bt.lineTo(0,-.46),bt.closePath(),new Da(bt,{depth:.022,bevelEnabled:!0,bevelThickness:.008,bevelSize:.008,bevelSegments:2}).translate(0,0,-.011);let it=new an({color:"#bfe6ff",transparent:!0,opacity:.6,blending:hn,depthWrite:!1});Et.push(it);let ot=[];for(let At=0;At<7;At++){let Lt=At/7*Math.PI*2,ee=new Se(new Xi(.006,.006,.9,6),it.clone());ee.position.set(Math.cos(Lt)*.48,0,Math.sin(Lt)*.48),ee.userData.o=At*.37%1,et.add(ee),ot.push(ee)}let It=ut,Qt=new Se(new Yi(1.15,.03,10,96),new an({color:"#ffd37a",transparent:!0})),Ut=new Se(new jn(1,8,8),new an({visible:!1}));return Ut.scale.set(Math.max(.9,xt*2.4),1.6,Math.max(.9,xt*2.4)),Ut.position.y=.15,St.add(Ut),{g:St,shape:gt,span:xt,mats:Et,outer:Gt,inner:Bt,light:Zt,ring:Qt,hit:Ut,heavy:oe,bOuter:It,heavyNozzle:x,heavySpan:k,halo:X,stdParts:_t,racer:et,streaks:ot,steel:ct,hullMap:q,boltMap:ht,steelMap:wt}}return{shapeFor:mh,raw(O){n[O.dev]=O.colour;let vt=lt({id:O.id,name:O.name,dev:O.dev,shape:O.shape});return vt.hit.userData.modelId=O.id,Object.assign(vt,{SOOT_F:f,FUEL:u,FLAME_V:l,TRAIL_F:h,NOZZLE_Y:p}),vt},make(O,vt,St=!1){n[O.developerId]=O.colour;let Et=lt({id:O.id,name:O.name,dev:O.developerId,shape:O.shape});Et.hit.userData.modelId=O.id,Et.heavy.visible=vt,Et.racer.visible=!vt&&O.racer,Et.stdParts.forEach(q=>q.visible=!vt),Et.halo.visible=!1,Et.steel.map=vt?Et.steelMap:O.racer?Et.boltMap:Et.hullMap,Et.steel.metalness=vt?.92:.35,Et.steel.roughness=vt?.2:.34,O.fuel==="lo"&&(Et.outer.material.fragmentShader=f,Et.outer.material.blending=us,Et.outer.material.needsUpdate=!0);let Xt=u[O.fuel];for(let[q,ht]of[[Et.outer,Xt.o],[Et.inner,Xt.i]])q.material.uniforms.c0.value.set(ht[0]),q.material.uniforms.c1.value.set(ht[1]);Et.light.color.set(Xt.light);let gt=O.cost===0?0:Math.max(.15,Math.min(1,(Math.log10(O.cost??.1)+2.2)/2.8));Et.outer.scale.set(.8+gt*.6,.6+gt*1.2,.8+gt*.6),Et.inner.scale.set(1,.7+gt*.6,1),Et.light.intensity=.6+gt*1.4;let J=new Qe;return Et.g.add(J),St&&(Et.outer.visible=!1,Et.inner.visible=!1,Et.bOuter.forEach(q=>q.visible=!1),Et.light.intensity=0),{root:Et.g,flame:J,tipHeight:1.6,span:vt?Et.heavySpan:Et.span,hit:Et.hit,animate(q){Et.outer.material.uniforms.t.value=Et.inner.material.uniforms.t.value=q,Et.outer.material.uniforms.k.value=Et.inner.material.uniforms.k.value=St||O.cost===0?0:1,Et.bOuter.forEach(ht=>{ht.material.uniforms.t.value=q,ht.material.uniforms.k.value=St||O.cost===0?0:1}),Et.g.rotation.y=-.2-.4*Math.PI},dispose(){let q=new Set,ht=new Set,wt=new Set;Et.g.traverse(ct=>{ct.geometry&&!ct.geometry.userData.shared&&q.add(ct.geometry);for(let Ft of Array.isArray(ct.material)?ct.material:ct.material?[ct.material]:[]){ht.add(Ft);for(let ae of Object.values(Ft))ae?.isTexture&&ae!==i&&!ae.userData.shared&&wt.add(ae)}}),q.forEach(ct=>ct.dispose()),ht.forEach(ct=>ct.dispose()),wt.forEach(ct=>ct.dispose())}}},dispose(){}}}var Oc=[[40,"\u8FD1\u5730\u8F68\u9053","Low Earth orbit"],[50,"\u6708\u7403","Moon"],[60,"\u706B\u661F","Mars"],[70,"\u6728\u661F","Jupiter"],[80,"\u571F\u661F","Saturn"],[90,"\u65E5\u7403\u5C42\u9876","Heliopause"],[100,"\u661F\u8FB0\u5927\u6D77","The stars"]],Rx=i=>i==null?"\u2014":"$"+(i<.1?i.toFixed(3):i<1?i.toFixed(2):i.toFixed(1).replace(/\.0$/,"")),Fr=i=>String(i).replace(/[&<>"]/g,t=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"})[t]),id=!1,Xe=".p2-field.r4chips",Cx=`
${Xe} .wb-plates .plate{position:absolute;left:0;top:0;pointer-events:auto;cursor:pointer;white-space:nowrap;padding:3px 9px 3px 3px;border-radius:99px;display:flex;align-items:center;gap:6px;transition:opacity .25s;background:rgba(25,26,28,.34);border:1px solid color-mix(in srgb,var(--c) 30%,transparent);text-shadow:0 1px 3px #000,0 0 8px #000a;text-transform:none;letter-spacing:normal;font:500 12px/1.25 var(--f-lcd,ui-monospace,monospace);color:#e8edf5}
${Xe} .wb-plates .plate.hot{z-index:3;background:rgba(25,26,28,.78);border-color:var(--c)}
${Xe} .wb-plates .plate b{font:600 12px/1.25 Manrope,"DM Sans","PingFang SC","Noto Sans SC",system-ui,sans-serif;letter-spacing:-.01em;white-space:nowrap}
${Xe} .wb-plates .plate b .rz{font-style:normal;margin-left:4px;color:#bfe6ff;text-shadow:0 0 6px #7fc8ff}
${Xe} .wb-plates .plate .nf:not(:empty){margin-right:0}
${Xe} .wb-plates .plate .lcdc{display:inline-flex;align-items:baseline;gap:5px;padding:2px 6px;border-radius:6px;opacity:.92;font-family:"Share Tech Mono",var(--f-lcd,ui-monospace),monospace;color:#ffc98a;text-shadow:0 0 5px rgba(255,160,80,.45);background:radial-gradient(130% 120% at 25% 0%,#18263d,#070c16 72%);box-shadow:inset 0 0 0 1px #2a3a55}
${Xe} .wb-plates .plate .lcdc .v{font-size:12.5px}
${Xe} .wb-plates .plate .lcdc .ef{font-size:10px;color:rgba(255,201,138,.7)}
${Xe} .wb-plates .plate:not(.hot) .lcdc .ef{display:none}
${Xe} .wb-plates .plate .lcdc i{font-style:normal;color:#ffe19a;text-shadow:0 0 5px rgba(255,211,122,.6)}
${Xe} .wb-plates .plate .rank{align-self:center;display:grid;place-items:center;min-width:17px;height:17px;padding:0 3px;border-radius:9px;background:var(--c);color:#0a0e18;font:700 10px/1 var(--f-lcd,ui-monospace),monospace;box-shadow:0 0 10px color-mix(in srgb,var(--c) 45%,transparent)}
${Xe} .wb-plates .plate .lg{align-self:center;flex:none;width:16px;height:16px;border-radius:5px;overflow:hidden;display:grid;place-items:center;background:rgba(255,255,255,.07)}
${Xe} .wb-plates .plate .lg img{display:block;width:72%;height:72%}
${Xe} .wb-plates .plate .lg span{font:800 10px system-ui,sans-serif;color:var(--c)}
${Xe} .wb-plates .plate.dot{padding:3px;gap:0}
${Xe} .wb-plates .plate.dot>b,${Xe} .wb-plates .plate.dot .lg,${Xe} .wb-plates .plate.dot .lcdc{display:none}
${Xe} .wb-plates .plate.tight .nf{display:none}
${Xe} .ltag{font:500 10.5px var(--f-lcd,ui-monospace),monospace;color:rgba(154,164,184,.8);transform-origin:0 0;margin:-4px 0 0 2px;translate:0 -100%;text-align:left;text-shadow:0 1px 8px #000}
${Xe} .ltag small{display:inline;margin-left:.5em;color:rgba(95,107,130,.9);font:inherit}
${Xe} .ltag.kar,${Xe} .ltag.kar small{color:#ffd37a}
${Xe} .ltag.body{margin:0 0 0 20px;translate:0 -50%}
${Xe} .ltag.far,${Xe} .ltag.body.far{margin:0;translate:none}
${Xe} .ltag.next{font:600 11px system-ui,sans-serif;color:#ffd37a;letter-spacing:.02em}
${Xe} .ltag.next small{font:500 10px var(--f-lcd,ui-monospace),monospace;color:rgba(255,211,122,.6);margin-top:2px}
`;function sd(i){let{launch:t,host:e,plates:n,leaders:s,voyage:r,logo:a}=i,o=i.language??"zh",l=()=>o==="zh",c=()=>t.querySelector(i.copySelector),h=()=>t.querySelector(i.panelSelector),f=!!i.quiet||matchMedia("(prefers-reduced-motion: reduce)").matches,u={models:[]},d=!!i.showEffortPath,g={},_=new Set,m=null,p=null,S=null,A=R=>u.models.find(B=>B.dev===R)?.colour??"#b8b0a8",v=0,b=0,E=()=>i.embedded?!1:v<720,C=innerWidth<720,y=C?13:15,w=4,I=C?-6.5:-9,N=-I,H=3.2,W=C?-5.5:-8.5,U=2.3,G=46,rt=new P(0,-G-9,-8),j=()=>0,pt=44,st=60,lt=R=>Math.max(1.4,(R-pt)/(st-pt)*y+w),O=-1.3,vt=.5,St=1,Et=R=>I+.8+(Math.log10(R)-O)/(vt-O)*(N-I-1.6),Xt=R=>R==null?U:1.2-R/St*(1.2-W-.6),gt=(R,B,V)=>new P(R,B,V),J=new wc({antialias:!0,powerPreference:"high-performance",preserveDrawingBuffer:!1});J.setPixelRatio(i.stillCapture?devicePixelRatio:Math.min(devicePixelRatio,i.embedded?1.35:2)),J.outputColorSpace=Ke,J.toneMapping=Rs,J.toneMappingExposure=1.05,e.appendChild(J.domElement);let q=new fa;q.background=new se("#010205");let ht=new Mn(30,1,.1,4e3),wt=[],ct=R=>(wt.push(R),R),Ft=gt(-.93,.07,-.36).normalize(),ae=gt(.5,.55,.68).normalize(),K=new Tr("#ffe4c4",2.6);K.position.copy(Ft).multiplyScalar(50),q.add(K);let ut=new Tr("#d8e6ff",1.25);ut.position.copy(ae).multiplyScalar(50),q.add(ut),q.add(new ka("#7d9cd6","#0d2a5c",.45));let yt=(R,B,V)=>[(Math.atan2(R.z,R.x)/(2*Math.PI)+.5)*B,(1-(Math.asin(R.y)/Math.PI+.5))*V],xt=(()=>{let V=document.createElement("canvas");V.width=1024,V.height=512;let Z=V.getContext("2d"),nt=Z.createLinearGradient(0,0,0,512);[[0,"#06080f"],[.44,"#121a2c"],[.49,"#5d93d6"],[.5,"#bfe2ff"],[.52,"#2a64b4"],[.6,"#0d2752"],[.8,"#061330"],[1,"#02060f"]].forEach(([Ot,Tt])=>nt.addColorStop(Ot,Tt)),Z.fillStyle=nt,Z.fillRect(0,0,1024,512);let Mt=(Ot,Tt,kt,Ct)=>{let[ce,le]=yt(Ot,1024,512);for(let ve of[-1024,0,1024]){Z.save(),Z.translate(ce+ve,le),Z.scale(Tt,kt);let ye=Z.createRadialGradient(0,0,0,0,0,1);Ct.forEach(([Re,ze])=>ye.addColorStop(Re,ze)),Z.fillStyle=ye,Z.beginPath(),Z.arc(0,0,1,0,Math.PI*2),Z.fill(),Z.restore()}};Mt(ae,120,70,[[0,"rgba(235,242,255,1)"],[.55,"rgba(200,220,255,.75)"],[1,"rgba(200,220,255,0)"]]),Mt(gt(.7,.35,-.6).normalize(),40,110,[[0,"rgba(150,195,255,.9)"],[1,"rgba(150,195,255,0)"]]),Mt(gt(-.2,.75,.6).normalize(),220,26,[[0,"rgba(255,255,255,.55)"],[1,"rgba(255,255,255,0)"]]),Mt(Ft,70,40,[[0,"rgba(255,250,235,1)"],[.2,"rgba(255,220,170,1)"],[1,"rgba(255,170,90,0)"]]);for(let Ot=0;Ot<260;Ot++){let Tt=Math.random()*1024,kt=512*(.56+Math.random()*.4);Z.fillStyle=`rgba(255,${150+Math.random()*60|0},80,${.3+Math.random()*.5})`,Z.fillRect(Tt,kt,1.5,1.5)}let dt=new Kn(V);return dt.colorSpace=Ke,dt.wrapS=ns,dt.minFilter=Ti,ct(dt)})(),_t=nd(null,{studio:xt}),Gt=qf(q),Bt=(R,B=128)=>{let V=document.createElement("canvas");V.width=V.height=B;let Z=V.getContext("2d"),nt=Z.createRadialGradient(B/2,B/2,0,B/2,B/2,B/2);R.forEach(([dt,Ot])=>nt.addColorStop(dt,Ot)),Z.fillStyle=nt,Z.fillRect(0,0,B,B);let Mt=new Kn(V);return Mt.colorSpace=Ke,ct(Mt)},Zt=Bt([[0,"rgba(255,255,255,1)"],[.25,"rgba(255,255,255,.45)"],[1,"rgba(255,255,255,0)"]]),ne;{let B=new Float32Array(9600),V=new Float32Array(3200),Z=new Float32Array(3200);for(let le=0;le<3200;le++){let ve=Math.random()*2-1,ye=Math.random()*Math.PI*2,Re=1500,ze=Math.sqrt(1-ve*ve);B.set([Re*ze*Math.cos(ye),Re*ve,Re*ze*Math.sin(ye)],le*3),V[le]=Math.random()*6.28,Z[le]=Math.random()**4*3.4+.7}let nt=new Ie;nt.setAttribute("position",new sn(B,3)),nt.setAttribute("ph",new sn(V,1)),nt.setAttribute("sz",new sn(Z,1)),ne=new He({transparent:!0,depthWrite:!1,uniforms:{t:{value:0}},vertexShader:"attribute float ph; attribute float sz; uniform float t; varying float a; void main(){ a=.6+.4*sin(t*1.1+ph); gl_PointSize=sz*(.75+.25*a)*1.5; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",fragmentShader:"varying float a; void main(){ float d=length(gl_PointCoord-.5); gl_FragColor=vec4(vec3(.92,.95,1.),a*smoothstep(.5,0.,d)); }"}),q.add(new va(nt,ne));let Mt=document.createElement("canvas");Mt.width=1024,Mt.height=512;let dt=Mt.getContext("2d");[[300,220,320,"rgba(70,90,170,.22)"],[640,180,280,"rgba(40,90,170,.18)"],[820,290,220,"rgba(150,80,140,.10)"]].forEach(([le,ve,ye,Re])=>{let ze=dt.createRadialGradient(le,ve,0,le,ve,ye);ze.addColorStop(0,Re),ze.addColorStop(1,"rgba(0,0,0,0)"),dt.fillStyle=ze,dt.fillRect(0,0,1024,512)});let Ot=ct(new Kn(Mt));Ot.colorSpace=Ke;let Tt=new Se(new rs(2600,1300),new an({map:Ot,transparent:!0,depthWrite:!1,blending:hn}));Tt.position.set(200,420,-1300),q.add(Tt);let kt=Ft.clone().multiplyScalar(1100).add(rt),Ct=new is(new Gi({map:Bt([[0,"rgba(255,255,250,1)"],[.06,"rgba(255,245,225,1)"],[.16,"rgba(255,200,140,.5)"],[.45,"rgba(255,150,80,.08)"],[1,"rgba(255,120,60,0)"]],256),blending:hn,depthWrite:!1}));Ct.position.copy(kt),Ct.scale.setScalar(340),q.add(Ct);let ce=new is(new Gi({map:Zt,color:"#9cc8ff",blending:hn,depthWrite:!1,opacity:.55}));ce.position.copy(kt),ce.scale.set(1500,14,1),q.add(ce)}let L=[],Jt=new Qe,oe=0;document.fonts?.ready.then(()=>oe++),q.add(Jt);function T(R,B,V,Z,nt=2){let Mt=[];for(let dt=0;dt<=nt;dt++)Mt.push(gt(V+(Z-V)*(dt/nt),R,B));return Mt}let x=R=>{let B=document.createElement("canvas");B.width=256,B.height=128;let V=B.getContext("2d");R(V,256,128);let Z=ct(new Kn(B));return Z.colorSpace=Ke,Z},k=(()=>{let R=7;return()=>(R=R*16807%2147483647)/2147483647})(),X={50:x((R,B,V)=>{R.fillStyle="#b9bcc2",R.fillRect(0,0,B,V);for(let Z=0;Z<70;Z++){let nt=2+k()*9;R.fillStyle=`rgba(${k()<.5?"70,74,82":"225,228,232"},.35)`,R.beginPath(),R.arc(k()*B,k()*V,nt,0,7),R.fill()}}),60:x((R,B,V)=>{R.fillStyle="#b4532c",R.fillRect(0,0,B,V);for(let Z=0;Z<50;Z++)R.fillStyle=`rgba(${k()<.6?"90,36,22":"214,120,72"},.35)`,R.beginPath(),R.ellipse(k()*B,k()*V,6+k()*26,3+k()*10,0,0,7),R.fill();R.fillStyle="rgba(255,250,245,.8)",R.fillRect(0,0,B,7),R.fillRect(0,V-6,B,6)}),70:x((R,B,V)=>{let Z=["#d8c4a4","#b98d63","#e7dcc8","#a8714b","#d9b98e","#c69c74","#efe6d6"];for(let nt=0;nt<V;nt+=6)R.fillStyle=Z[(nt/6+(k()*2|0))%Z.length],R.fillRect(0,nt,B,6);R.fillStyle="#b5523a",R.beginPath(),R.ellipse(170,82,16,8,0,0,7),R.fill()}),80:x((R,B,V)=>{let Z=["#e6d3a6","#d4bb85","#efe2c0","#c9ad78"];for(let nt=0;nt<V;nt+=8)R.fillStyle=Z[nt/8%Z.length],R.fillRect(0,nt,B,8)})},et=R=>{R.traverse(B=>{B.geometry?.dispose();for(let V of[].concat(B.material||[]))V.dispose()}),R.clear()};function bt(R){et(Jt),L.forEach(Z=>Z.el.remove()),L.length=0;let B=(Z,nt,Mt="",dt=null,Ot=0)=>{let Tt=document.createElement("div");Tt.className="ltag "+Mt,Tt.innerHTML=Z,n.appendChild(Tt),L.push({el:Tt,v:nt,far:dt,radius:Ot,atFar:!1})};for(let[Z,nt,Mt]of Oc){if(Z<pt||Z>st)continue;let dt=Z===100,Ot=T(lt(Z),W,I+.5,N-.5),Tt=new Wi(new Ie().setFromPoints(Ot),dt?new Oa({color:"#ffd37a",dashSize:.3,gapSize:.2}):new hi({color:"#cfe2ff",transparent:!0,opacity:.16}));dt&&Tt.computeLineDistances(),Jt.add(Tt);let kt=gt(N+.2,Ot[0].y,W);if(X[Z]){let Ct=new Se(new jn(Z===70?.6:.42,48,32),new Vn({map:X[Z],roughness:.9}));if(Ct.position.copy(kt),Ct.userData.spin=!0,Jt.add(Ct),Z===80){let ce=new Se(new Mr(.62,.95,64),new Vn({color:"#d9c6a0",transparent:!0,opacity:.75,side:En,roughness:.8}));ce.position.copy(kt),ce.rotation.x=-1.2,ce.rotation.y=.3,Jt.add(ce)}}B(`${l()?nt:Mt}<small>Index ${Z}</small>`,kt,(dt?"kar":"")+(X[Z]?" body":""),Ot[0].clone(),X[Z]?Z===80?.95:Z===70?.6:.42:0)}let V=Oc.find(Z=>Z[0]>st);V&&C&&B(l()?`\u2191 \u4E0B\u4E00\u7AD9 ${V[1]} \xB7 ${V[0]}<small>${R>=100?"\u5DF2\u9A76\u5165\u661F\u8FB0\u5927\u6D77":`\u7EC8\u70B9 \u661F\u8FB0\u5927\u6D77 100\u3000\u9886\u5148\u8005\u8FD8\u5DEE ${(100-R).toFixed(1)}`}</small>`:`\u2191 Next stop ${V[2]} \xB7 ${V[0]}<small>${R>=100?"Out among the stars":`Destination: the stars at 100 \xB7 the leader is ${(100-R).toFixed(1)} away`}</small>`,gt(I+.5,j()+lt(st)+1.2,W),"next")}{let R=N-I+3,B=H-W+2,V=new Se(new rs(R,B),new He({transparent:!0,depthWrite:!1,blending:hn,uniforms:{size:{value:new ft(R,B)}},vertexShader:"varying vec2 vUv; void main(){ vUv=uv; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",fragmentShader:"uniform vec2 size; varying vec2 vUv; void main(){ vec2 p=vUv*size; vec2 g=abs(fract(p-.5)-.5)/fwidth(p); float line=1.-min(min(g.x,g.y),1.); vec2 e=min(vUv,1.-vUv)*size; float fade=smoothstep(0.,2.5,min(e.x,e.y)); float back=mix(.35,1.,vUv.y); gl_FragColor=vec4(vec3(.45,.68,1.)*(line*.16+.025)*fade*back,1.); }"}));V.rotation.x=-Math.PI/2,V.position.set((I+N)/2+.5,-.01,(H+W)/2),q.add(V)}let Rt=new Qe;q.add(Rt);let it=[];function ot(R,B,V){let Z=document.createElement("div");Z.className="tick3 "+(V??""),Z.textContent=R,n.appendChild(Z),it.push({el:Z,v:B,kind:V})}let It=()=>{let R=[];for(let B=Math.floor(O)-1;B<=Math.ceil(vt)+1;B++)for(let V of[1,3]){let Z=V*10**B;Math.log10(Z)>=O&&Math.log10(Z)<=vt&&R.push(Z)}return R};function Qt(){et(Rt),it.forEach(V=>V.el.remove()),it.length=0;let R=[];for(let V=0;V<=60;V++){let Z=I+(N-I)*(V/60);R.push(gt(Z,j()+.03,H))}Rt.add(new Wi(new Ie().setFromPoints(R),new hi({color:"#ffb27a",transparent:!0,opacity:.8})));for(let V of It()){let Z=Et(V);if(Z<I||Z>N)continue;let nt=j();Rt.add(new Wi(new Ie().setFromPoints([gt(Z,nt,H),gt(Z,nt+.25,H)]),new hi({color:"#ffb27a"}))),ot(Rx(V),gt(Z,nt-.35,H+.2),"cost")}ot(l()?"API \u53C2\u8003\u6210\u672C \u2192":"API reference cost \u2192",gt(N-1.2,j()-1,H+.4),"axis");let B=[];for(let V=0;V<=40;V++){let Z=H-(H-W)*(V/40);B.push(gt(N+.6,j()+.03,Z))}Rt.add(new Wi(new Ie().setFromPoints(B),new hi({color:"#c9b3ff",transparent:!0,opacity:.8})));for(let V of[.25,.5,1,2,4,8,16])V<=St&&ot((l()?"\u4F30\u65F6 ":"Estimated time ")+V+(l()?"\u5206":" min"),gt(N+1.2,j(),Xt(V)),"time");ot(l()?"\u822A\u65F6\u672A\u77E5 \xB7 \u524D\u6392":"Time unknown \xB7 front row",gt(I+1.2,j()+.1,U),"lane")}let Ut=new Xi(.1,.55,1,32,1,!0);Ut.translate(0,-.5,0);let At=new Xi(.2,.7,1,32,1,!0);At.translate(0,-.5,0);let Lt=new Map;function ee(R){let B=Lt.get(R.id);if(B)return B;let V=R.dev==="zhipu"?"zhipuai":R.dev,Z=kf[V]??"#b8b0a8",nt=_t.raw({id:R.id,name:R.name,dev:V,colour:Z,shape:R.shape}),Mt=new Set([nt.hullMap,nt.boltMap,nt.steelMap]);nt.g.traverse(ve=>{for(let ye of[].concat(ve.material||[]))for(let Re of Object.values(ye))Re?.isTexture&&Re!==xt&&Mt.add(Re)});for(let ve of Mt)wt.includes(ve)||wt.push(ve),Gf(ve,()=>$n(0),ve.image?.width===ve.image?.height?256:512);Wf(nt);let dt=new Se(Ut,new He({transparent:!0,depthWrite:!1,blending:hn,uniforms:{t:{value:0},k:{value:1},gc:{value:new P(1,.55,.25)},sc:{value:new P(.6,.66,.8)},sm:{value:.5}},vertexShader:nt.FLAME_V,fragmentShader:nt.TRAIL_F})),Ot=new Se(At,new He({transparent:!0,depthWrite:!1,uniforms:{t:{value:0},k:{value:0}},vertexShader:nt.FLAME_V,fragmentShader:nt.SOOT_F})),Tt=new Wi(new Ie().setFromPoints([gt(0,0,0),gt(0,-1,0)]),new hi({color:R.colour,transparent:!0,opacity:.22})),kt=new Se(new Mr(.2,.28,48),new an({color:R.colour,transparent:!0,opacity:.7,side:En})),Ct=new is(new Gi({map:Zt,color:R.colour,blending:hn,depthWrite:!1,transparent:!0,opacity:.3})),ce=new is(new Gi({map:Zt,color:"#b8c2d2",transparent:!0,depthWrite:!1,opacity:0})),le=new Qe;return le.add(nt.g,nt.ring),q.add(le,dt,Ot,Tt,kt,Ct,ce),B={m:R,factoryDeveloper:V,factoryColour:Z,...nt,root:le,trail:dt,soot:Ot,drop:Tt,pad:kt,padGlow:Ct,smoke:ce,fuelKind:null,pos:gt(0,0,0),tgt:gt(0,0,0),born:performance.now()+Lt.size*160,flare:1,phase:Math.random()*6.28,screen:null},Lt.set(R.id,B),B}let fe=null;function F(R){let B=R.m.fuel??"mid";if(R.fuelKind===B)return;R.fuelKind=B;let V=R.FUEL[B];for(let Z of[R.outer,...R.bOuter])Z.material.uniforms.c0.value.set(V.o[0]),Z.material.uniforms.c1.value.set(V.o[1]);R.inner.material.uniforms.c0.value.set(V.i[0]),R.inner.material.uniforms.c1.value.set(V.i[1]),R.light.color.set(V.light),R.trail.material.uniforms.gc.value.set(...V.gc),R.trail.material.uniforms.sc.value.set(...V.sc),R.trail.material.uniforms.sm.value=V.sm}let Pt={yaw:-.26,pitch:.12},at={yaw:-.2,pitch:.16},Dt=null,Nt=null,mt;function ie(){let R=u.models.filter(Tt=>_.has(Tt.id)&&g[Tt.id]);if(fe=Vf(R,Tt=>g[Tt.id][1],Tt=>Tt.dev==="zhipu"?"zhipuai":Tt.dev)?.id??null,!R.length)return;let B=i.embedded?R.flatMap(Tt=>Tt.e):R.map(Tt=>g[Tt.id]),V=B.map(Tt=>Tt[2]);if(O=Math.log10(Math.min(...V))-.22,vt=Math.log10(Math.max(...V))+.22,vt-O<1){let Tt=(O+vt)/2;O=Tt-.5,vt=Tt+.5}St=Math.max(.6,...B.map(Tt=>Tt[3]??0))*1.15;let Z=B.map(Tt=>Tt[1]);pt=Math.floor(Math.min(...Z))-4,st=Math.max(Math.ceil(Math.max(...Z))+3,pt+14);for(let Tt of R){let kt=ee(Tt),Ct=g[Tt.id];kt.m=Tt,kt.tgt.set(Et(Ct[2]),lt(Ct[1]),Xt(Ct[3])),kt.nudge=0}let nt=i.embedded?[]:R.map(Tt=>Lt.get(Tt.id)),Mt=C?1:1.3,dt=(C?at:Pt).yaw,Ot=Tt=>Tt.x*Math.cos(dt)-Tt.z*Math.sin(dt);for(let Tt=0;Tt<40;Tt++)for(let kt=0;kt<nt.length;kt++)for(let Ct=kt+1;Ct<nt.length;Ct++){let ce=nt[kt],le=nt[Ct],ve=Ot(le.tgt)-Ot(ce.tgt),ye=(le.tgt.y-ce.tgt.y)*.3,Re=Math.hypot(ve,ye);if(Re<Mt){let ze=(Mt-Re)/2,tt=ve>=0?1:-1;ce.tgt.x-=ze*tt,le.tgt.x+=ze*tt,ce.nudge-=ze*tt,le.nudge+=ze*tt}}for(let Tt of Lt.values())Tt.started||(Tt.pos.copy(Tt.tgt),Tt.started=!0);Ze(),Qt(),bt(Math.max(...Z)),Dt=null,mt=void 0}let qt=new Qe;q.add(qt);let Oe=[];function Ue(R){if(et(qt),Oe.forEach(dt=>dt.el.remove()),Oe.length=0,mt=R,!R)return;let B=u.models.find(dt=>dt.id===R);if(!B||!Lt.has(R))return;let V=B.colour,Z=Lt.get(R)?.nudge??0,nt=B.e.map(dt=>{let Ot=Et(dt[2])+Z,Tt=Xt(dt[3]);return gt(Ot,j()+lt(dt[1]),Tt)}),Mt=new _r;for(let dt=1;dt<nt.length;dt++)Mt.add(new xr(nt[dt-1],nt[dt]));nt.length>1&&qt.add(new Se(new Ua(Mt,120,.022,8,!1),new an({color:V,transparent:!0,opacity:.5,blending:hn,depthWrite:!1}))),B.e.forEach((dt,Ot)=>{let Tt=new Se(new jn(.1,16,12),new an({color:dt[0]===B.reportedEffort?"#e5eceb":dt[0]===B.rec?"#dfbf7a":"#0b1020"}));if(Tt.position.copy(nt[Ot]),qt.add(Tt),dt[0]===B.previewEffort||dt[3]==null||dt[4]){let Ct=new Se(new Yi(dt[0]===B.previewEffort?.2:.1,.025,8,24),new an({color:V}));Ct.position.copy(nt[Ot]),Ct.userData.bill=!0,qt.add(Ct)}if(dt[0]!==B.reportedEffort&&dt[0]!==B.previewEffort)return;let kt=document.createElement("div");kt.className="bl3"+(dt[0]===B.rec?" rec":"")+(dt[0]===g[B.id]?.[0]?" cur":""),kt.textContent=`${dt[0]===B.previewEffort?"\u25C7 "+(i.labels?.preview??(l()?"\u9884\u89C8":"Preview"))+" ":"\u25CF "+(i.labels?.current??(l()?"\u5F53\u524D":"Current"))+" "}${dt[0]}`,kt.style.setProperty("--c",V),n.appendChild(kt),Oe.push({el:kt,v:nt[Ot]})})}let en=new Ic(J,new tn(1,1,{type:un}));en.addPass(new Lc(q,ht));let Nn=new Ur(new ft(256,256),.75,.28,.86);en.addPass(Nn),en.addPass(new Dc);let me={yaw:Pt.yaw,pitch:Pt.pitch,vy:0,vp:0,drag:null},mi=gt(0,10,-2.4),Ri=mi.clone(),_n=0;function Ls(){if(i.embedded)return i.compactFrame?i.canopyFrame?Xc(v,b,i.canopyProfile):{x:35,r:v-16,y:14,b:b-28}:{x:70,r:v-26,y:58,b:b-70};let R=t.getBoundingClientRect(),B=c()?.getBoundingClientRect(),V=h()?.getBoundingClientRect();return E()?{x:16,r:v-16,y:(B?B.bottom-R.top:200)+70,b:Math.min(b,innerHeight-R.top)-78}:{x:(B?B.right-R.left:420)+30+88,r:(V?V.left-R.left:v-360)-30,y:110,b:b-120}}let Or=(R,B=R.tgt)=>gt(B.x,j()+B.y,B.z);function mo(R){let B=R.nudge??0,V=Or(R),Z=[V.clone().add(gt(0,2.2,0)),V.clone().add(gt(0,-2.4,0)),...R.m.e.map(ye=>gt(Et(ye[2])+B,j()+lt(ye[1]),Xt(ye[3])))],nt=Z.reduce((ye,Re)=>ye.min(Re),Z[0].clone()),Mt=Z.reduce((ye,Re)=>ye.max(Re),Z[0].clone()),dt=nt.clone().add(Mt).multiplyScalar(.5),Ot=t.getBoundingClientRect().top,Tt=Math.max(0,-Ot)+64,kt=t.querySelector(".sp-focus-bar")?.getBoundingClientRect(),Ct=Math.min(b,innerHeight-Ot,kt?kt.top-Ot:b-150)-14,ce=at,le=ht.clone();le.aspect=v/b,le.clearViewOffset(),le.updateProjectionMatrix();let ve=24;for(let ye=0;ye<6;ye++){le.position.set(dt.x+ve*Math.sin(ce.yaw)*Math.cos(ce.pitch),dt.y+ve*Math.sin(ce.pitch),dt.z+ve*Math.cos(ce.yaw)*Math.cos(ce.pitch)),le.lookAt(dt),le.updateMatrixWorld();let Re=Z.map(jt=>{let z=jt.clone().project(le);return[(z.x*.5+.5)*v,(-z.y*.5+.5)*b]}),ze=Re.map(jt=>jt[0]),tt=Re.map(jt=>jt[1]);ve*=Math.max((Math.max(...ze)-Math.min(...ze))/(v-120),(Math.max(...tt)-Math.min(...tt))/Math.max(120,Ct-Tt))*1.12}return{look:dt,d:Math.max(8,ve),fy:(Tt+Ct)/2}}function Ci(){Dt=Ds(v,b,Ls())}function Ds(R,B,V){let Z=[gt(I,j(),H),gt(N,j(),H)];for(let Tt of Lt.values())if(_.has(Tt.m.id)){let kt=Or(Tt);if(i.embedded)for(let Ct of Tt.m.e)Z.push(gt(Et(Ct[2]),lt(Ct[1])+2.2,Xt(Ct[3])));Z.push(kt.clone().add(gt(0,2.2,0)),kt.clone().add(gt(0,-2.4,0)))}let nt=E()?at:Pt,Mt=ht.clone();Mt.aspect=R/B,Mt.clearViewOffset(),Mt.updateProjectionMatrix();let dt=40,Ot;for(let Tt=0;Tt<6;Tt++){Mt.position.set(mi.x+dt*Math.sin(nt.yaw)*Math.cos(nt.pitch),mi.y+dt*Math.sin(nt.pitch),mi.z+dt*Math.cos(nt.yaw)*Math.cos(nt.pitch)),Mt.lookAt(mi),Mt.updateMatrixWorld();let kt=Z.map(Ct=>{let ce=Ct.clone().project(Mt);return[(ce.x*.5+.5)*R,(-ce.y*.5+.5)*B]});Ot={x0:Math.min(...kt.map(Ct=>Ct[0])),x1:Math.max(...kt.map(Ct=>Ct[0])),y0:Math.min(...kt.map(Ct=>Ct[1])),y1:Math.max(...kt.map(Ct=>Ct[1]))},dt*=Math.max((Ot.x1-Ot.x0)/(V.r-V.x),(Ot.y1-Ot.y0)/(V.b-V.y))*1.02}return{d:dt,ox:(Ot.x0+Ot.x1)/2-(V.x+V.r)/2,oy:(Ot.y0+Ot.y1)/2-(V.y+V.b)/2-(E()?24:0)}}function Br(){v=t.clientWidth,b=t.clientHeight,!(!v||!b)&&(J.setSize(v,b),ht.aspect=v/b,ht.updateProjectionMatrix(),en.setSize(v,b),Nn.resolution.set(v,b),Dt=null,Nt=null,oe++,u.models.length&&(Ze(),$n(1400)))}let zr=new ResizeObserver(Br);zr.observe(t),Br();let Xn=J.domElement,kr=new Xa,gs=new ft,Hr=R=>{let B=Xn.getBoundingClientRect();gs.set((R.clientX-B.left)/B.width*2-1,-((R.clientY-B.top)/B.height)*2+1),kr.setFromCamera(gs,ht);let V=[...Lt.values()].filter(nt=>_.has(nt.m.id)).map(nt=>nt.hit),Z=kr.intersectObjects(V)[0];return Z?[...Lt.values()].find(nt=>nt.hit===Z.object).m.id:null},xs=R=>i.onSelect?.(R===S?null:R),Bc=R=>{me.drag={x:R.clientX,y:R.clientY,yaw:me.yaw,pitch:me.pitch,still:!0},Xn.setPointerCapture(R.pointerId),e.classList.add("dragging"),Yn=null,$n(700)},zc=R=>{if(me.drag){Math.hypot(R.clientX-me.drag.x,R.clientY-me.drag.y)>4&&(me.drag.still=!1),me.drag.still||(me.yaw=me.drag.yaw-(R.clientX-me.drag.x)*.005,me.pitch=Math.min(.9,Math.max(-.05,me.drag.pitch+(R.clientY-me.drag.y)*.0035)),me.vy=me.vp=0,$n(700));return}if(R.pointerType==="touch")return;let B=Hr(R);B!==m&&$n(700),m=B,e.classList.toggle("over",!!m)},kc=R=>{let B=me.drag;if(me.drag=null,e.classList.remove("dragging"),B&&!B.still){let V=E()?at:Pt;Yn={start:performance.now(),yaw:me.yaw,pitch:me.pitch,endYaw:V.yaw,endPitch:V.pitch},$n(650);return}if(B?.still){let V=Hr(R);V?xs(V):S&&!E()&&i.onSelect?.(null)}},Hc=()=>{!me.drag&&m&&(m=null,$n(700))};Xn.addEventListener("pointerdown",Bc),Xn.addEventListener("pointermove",zc),Xn.addEventListener("pointerup",kc),Xn.addEventListener("pointerleave",Hc),Xn.addEventListener("webglcontextlost",R=>{R.preventDefault(),i.onFail?.()});let Ns="",M=new P,D=R=>(M.copy(R).project(ht),{x:(M.x*.5+.5)*v,y:(-M.y*.5+.5)*b,z:M.z}),Q=null,Y=R=>{if(Q||!t.contains(R.target)||R.target.closest(`${i.panelSelector}, nav, header, button, a, .voyage, details`))return;let B=null,V=12;for(let Z of n.querySelectorAll(".plate")){let nt=Z.getBoundingClientRect(),Mt=Math.max(nt.left-R.clientX,0,R.clientX-nt.right),dt=Math.max(nt.top-R.clientY,0,R.clientY-nt.bottom),Ot=Math.hypot(Mt,dt);Ot<=V&&(V=Ot,B=Z)}B&&(Q={id:B.dataset.id,x:R.clientX,y:R.clientY})},$=R=>{let B=Q;Q=null,B&&Math.hypot(R.clientX-B.x,R.clientY-B.y)<14&&xs(B.id)},Ht=()=>Q=null;addEventListener("pointerdown",Y,!0),addEventListener("pointerup",$),addEventListener("pointercancel",Ht);let Yt="http://www.w3.org/2000/svg";if(i.embedded&&!document.getElementById("mp-field-chips")){let R=document.createElement("style");R.id="mp-field-chips",R.textContent=Cx,document.head.appendChild(R)}t.classList.add("r4chips");let zt=new P,$t={x:0,y:0,z:0},te={x:0,y:0,z:0};function Me(){zt.setFromMatrixColumn(ht.matrixWorld,0);let R=[];for(let B of Lt.values()){if(!_.has(B.m.id)||!B.screen)continue;let V=B.root.scale.y,Z=B.root.position.x,nt=B.root.position.y,Mt=B.root.position.z,dt=D(M.set(Z,nt+1.6*V,Mt),$t);if(dt.z>=1)continue;let Ot=dt.x,Tt=dt.y,kt=D(M.set(Z,nt-1.24*V,Mt),$t),Ct=kt.x,ce=kt.y,le=D(M.set(Z,nt,Mt),$t).x,ve=Math.abs(D(M.set(Z,nt,Mt).addScaledVector(zt,(B.span||.3)*V),te).x-le);R.push({id:B.m.id,x:Math.min(Ot,Ct)-ve,y:Tt,w:Math.abs(Ot-Ct)+ve*2,h:ce-Tt,nx:Ot,ny:Tt})}return R}function Ee(R,B,V){let Z=[];for(let nt of L){let Mt=nt.el,dt=D(nt.v,$t);if(Mt.classList.contains("next")){if(E()){let re=t.getBoundingClientRect();dt.x=18,dt.y=(c()?.getBoundingClientRect().bottom??200)-re.top+44}else dt.y=Math.max(dt.y,128);Mt.style.transform=`translate(${dt.x}px, ${dt.y}px)`,Mt.style.opacity=dt.z<1?R*(1-_n):0;continue}let Ot=dt.x,Tt=dt.y,kt=dt.z<1&&R*(1-_n)>.3;Mt.style.opacity=dt.z<1?R*(1-_n):0;let Ct=Z.slice();if(nt.radius&&kt){let re=Math.abs(D(M.copy(nt.v).addScaledVector(zt,nt.radius),te).x-Ot);Z.push({x:Ot-re,y:Tt-re,w:re*2,h:re*2})}nt.epoch!==oe&&(nt.w=nt.h=0),nt.epoch=oe;let ce=nt.w||(nt.w=Mt.offsetWidth),le=nt.h||(nt.h=Mt.offsetHeight);if(!ce){Mt.style.transform=`translate(${Ot}px, ${Tt}px)`;continue}let ve=nt.radius?{x:Ot+20,y:Tt-le/2}:{x:Ot+2,y:Tt-le-4},ye=D(nt.far,te),Re=Math.max(ye.x+4,V.x+8),ze=Math.abs(Ot-ye.x)>1?(Re-ye.x)/(Ot-ye.x):0,tt={x:Re,y:ye.y+ze*(Tt-ye.y)-le-3},jt=re=>B.reduce((Ne,_e)=>Ne+(re.x<_e.x+_e.w+4&&_e.x<re.x+ce+4&&re.y<_e.y+_e.h*1.4&&_e.y<re.y+le+2?2:0)+(Math.abs(_e.ny-(re.y+le/2))<le/2+18&&re.x<_e.nx+212&&_e.nx-212<re.x+ce?1:0),0)+(re.x<V.x-10||re.x+ce>V.r+10?2:0)+Ct.reduce((Ne,_e)=>Ne+(re.x<_e.x+_e.w+2&&_e.x<re.x+ce+2&&re.y<_e.y+_e.h+2&&_e.y<re.y+le+2?2:0),0),z=jt(ve),de=jt(tt);!nt.atFar&&z>0&&de<z&&ye.z<1?nt.atFar=!0:nt.atFar&&(z===0||de>z)&&(nt.atFar=!1),Mt.classList.toggle("far",nt.atFar);let ge=nt.atFar?tt:ve;Mt.style.transform=nt.atFar?`translate(${tt.x}px, ${tt.y}px)`:`translate(${Ot}px, ${Tt}px)`,kt&&Z.push({x:ge.x,y:ge.y,w:ce,h:le})}return Z}function Kt(R,B,V=!1){for(let tt of[...n.children,...s.children])tt.style.transition=f||V?"none":"";let Z=u.models.filter(tt=>_.has(tt.id)&&g[tt.id]).sort((tt,jt)=>g[jt.id][1]-g[tt.id][1]),nt=(i.compactFrame?u.models.filter(tt=>_.has(tt.id)&&g[tt.id]).map(tt=>tt.id+o):Z.map(tt=>tt.id+g[tt.id][0]+o)).join("|");if(nt!==Ns&&(n.querySelectorAll(".plate").forEach(tt=>tt.remove()),s.replaceChildren(),Z.forEach((tt,jt)=>{let z=g[tt.id],de=document.createElement("div");de.className="plate",de.dataset.id=tt.id,i.embedded&&(de.setAttribute("role","button"),de.setAttribute("aria-label",tt.name+" \xB7 "+z[1].toFixed(1)+" \xB7 "+(z[0]===tt.rec?"\u2605":"")+z[0]+" \xB7 "+(l()?"\u9009\u62E9\u6A21\u578B":"Select model")),de.tabIndex=0,de.onkeydown=_e=>{(_e.key==="Enter"||_e.key===" ")&&(_e.preventDefault(),xs(tt.id))});let ge=tt.colour;de.style.setProperty("--c",ge);let re=/^(Claude|DeepSeek|Kimi)\s/.exec(tt.name)?.[0]??"";de.innerHTML=`<span class="rank">${jt+1}</span><span class="lg">${a(tt.dev)}</span><b><span class="nf">${Fr(re)}</span>${Fr(tt.name.slice(re.length))}${tt.racer?`<i class="rz" title="${l()?"\u7ADE\u901F\uFF1A\u5B8C\u5DE5\u5FEB\u4E14\u51FA\u5B57\u5FEB":"Racer: fast tasks and fast output"}">\u26A1</i>`:""}</b><span class="lcdc"><span class="v">${z[1].toFixed(1)}</span><span class="ef">${Fr(z[0])}${z[0]===tt.rec?"<i>\u2605</i>":""}</span></span>`,de.title=`${tt.name} \xB7 ${z[0]} \xB7 ${z[1].toFixed(1)}`,de.onmouseenter=()=>m=tt.id,de.onmouseleave=()=>m=null,de.onpointerdown=_e=>{Q={id:tt.id,x:_e.clientX,y:_e.clientY}},n.appendChild(de);let Ne=document.createElementNS(Yt,"line");Ne.setAttribute("stroke",ge),s.appendChild(Ne),de.leader=Ne}),Ns=nt),i.compactFrame)for(let tt of n.querySelectorAll(".plate")){let jt=u.models.find(ge=>ge.id===tt.dataset.id),z=jt&&g[jt.id];if(!z)continue;let de=z[0]+"|"+z[1]+"|"+Z.findIndex(ge=>ge.id===jt.id);tt.dataset.configuration!==de&&(tt.querySelector(".v").textContent=z[1].toFixed(1),tt.querySelector(".ef").innerHTML=Fr(z[0])+(z[0]===jt.rec?"<i>\u2605</i>":""),tt.querySelector(".rank").textContent=Z.findIndex(ge=>ge.id===jt.id)+1,tt.title=jt.name+" \xB7 "+z[0]+" \xB7 "+z[1].toFixed(1),tt.setAttribute("aria-label",jt.name+" \xB7 "+z[1].toFixed(1)+" \xB7 "+(z[0]===jt.rec?"\u2605":"")+z[0]+" \xB7 "+(l()?"\u9009\u62E9\u6A21\u578B":"Select model")),tt.dataset.configuration=de)}let Mt=Ls(),dt=[],Ot=Me(),Tt=Ee(B,Ot,Mt);globalThis.__mpLabelProbe&&(globalThis.__mpLabelProbe.fixed=Tt);let kt=[...n.querySelectorAll(".plate")].map(tt=>({p:tt,r:Lt.get(tt.dataset.id)})).filter(tt=>tt.r?.screen);i.compactFrame&&kt.sort((tt,jt)=>+(tt.p.dataset.id===R)-+(jt.p.dataset.id===R));let Ct=E()?6:9;kt.forEach(({p:tt,r:jt},z)=>{let de=tt.dataset.id,ge=R===de;tt.classList.toggle("hot",ge);let re=tt.classList.contains("dot"),Ne=tt.classList.contains("tight"),_e=tt.offsetHeight,ni=jt.screen.x,gi=jt.screen.y;!re&&!Ne&&(tt._full=tt.offsetWidth,tt._lead=tt.querySelector(".nf")?.offsetWidth??0);let Ii=tt._full??tt.offsetWidth,Xr=(Ge,ln,cn)=>dt.find(ke=>Ge<ke.x+ke.w+4&&ke.x<Ge+cn+4&&ln<ke.y+ke.h+3&&ke.y<ln+_e+3)??Tt.find(ke=>Ge<ke.x+ke.w+2&&ke.x<Ge+cn+2&&ln<ke.y+ke.h+2&&ke.y<ln+_e+2),_o=(Ge,ln)=>{let cn=Math.max(gi-_e/2,...dt.filter(ke=>Ge<ke.x+ke.w+30&&ke.x<Ge+ln+30).map(ke=>ke.y+2));for(let ke=0;ke<60;ke++){let An=Xr(Ge,cn,ln);if(!An)return cn;cn=An.y+An.h+(An.chip?3:2)+.01}return cn},wn=(Ge,ln,cn)=>{let ke=Ge+cn/2<ni?Ge+cn:Ge,An=Math.max(ln+4,Math.min(ln+_e-4,gi)),Yr=Math.hypot(ke-ni,An-gi),vo=Yr*.6+Math.max(0,Yr-120)*2.5;for(let Rn of Ot){let Bs=Math.min(Ge+cn,Rn.x+Rn.w)-Math.max(Ge,Rn.x),Ph=Math.min(ln+_e,Rn.y+Rn.h)-Math.max(ln,Rn.y);if(Bs<=0||Ph<=0)continue;let Ih=Bs*Ph;vo+=Rn.id===de?400:Math.min(1,Ih/260)*60+Ih/_e*2.2+(Rn.nx>Ge&&Rn.nx<Ge+cn&&Rn.ny>ln-4&&Rn.ny<ln+_e?90:0)}return vo},vs=(Ge,ln,cn,ke)=>{for(let An of[1,-1])cn.forEach((Yr,vo)=>{let Rn=An>0?Math.min(Mt.r+10-Ge,ni+Yr):Math.max(Mt.x-10,ni-Yr-Ge),Bs=_o(Rn,Ge);ke.push({x:Rn,y:Bs,w:Ge,tight:ln,slot:An*(vo+1),cost:wn(Rn,Bs,Ge)+(An<0?4:0)+(ln?10:0)+(Xr(Rn,Bs,Ge)?1e3:0)})});return ke},Ln=(Ge,ln)=>{let cn=Ge[0];for(let An of Ge)An.cost<cn.cost&&(cn=An);let ke=Ge.find(An=>An.slot===tt._slot&&An.tight===ln);return ke&&ke.cost<=cn.cost+30?ke:cn},ii=[12,34,60,92,130],Os=vs(Ii,!1,ii,[]);tt._lead>0&&!ge&&vs(Ii-tt._lead,!0,ii,Os);let yn=Ln(Os,Ne&&!re),Li=!ge&&z>=Ct&&yn.cost>(re?125:180);Li&&(yn=Ln(vs(tt._dot??_e,!1,[8,22],[]),!1)),Li!==re&&tt.classList.toggle("dot",Li),Li&&re&&(tt._dot=tt.offsetWidth);let Zi=!Li&&yn.tight;Zi!==Ne&&tt.classList.toggle("tight",Zi),tt._slot=yn.slot;let Ji=yn.w;dt.push({x:yn.x,y:yn.y,w:Ji,h:_e,chip:!0}),globalThis.__mpLabelProbe&&(tt._pick=yn),tt._x=V||tt._x==null||Math.abs(tt._x-yn.x)>80?yn.x:tt._x+(yn.x-tt._x)*.25,tt._y=V||tt._y==null||Math.abs(tt._y-yn.y)>80?yn.y:tt._y+(yn.y-tt._y)*.25,tt.style.transform=`translate(${tt._x}px, ${tt._y}px)`;let Je=R&&R!==tt.dataset.id&&Ot.find(Ge=>Ge.id===R),Di=Je&&tt._x<Je.x+Je.w+6&&Je.x-6<tt._x+Ji&&tt._y<Je.y+Je.h&&Je.y<tt._y+_e,wh=Di?.04:R&&!ge?S?i.embedded?.82:.42:i.embedded?.7:.22:f||V?1:Math.min(1,Math.max(0,(performance.now()-jt.born-1200)/600));tt.style.opacity=wh,tt.style.pointerEvents=Di&&!S?"none":"";let Ah=tt._x+Ji/2<ni,Rh=Ah?tt._x+Ji:tt._x,Ch=tt._y+_e/2,cd=Math.hypot(Rh-ni,Ch-gi)>16,qr=tt.leader;qr.setAttribute("x1",ni+(Ah?-4:4)),qr.setAttribute("y1",gi),qr.setAttribute("x2",Rh),qr.setAttribute("y2",Ch),qr.style.opacity=cd?wh*.6:0});let ce=n.getBoundingClientRect(),le=[...n.querySelectorAll(".plate, .bl3")].filter(tt=>tt.style.opacity===""||Number(tt.style.opacity)>.08).map(tt=>{let jt=tt.getBoundingClientRect();return{x:jt.left-ce.left,y:jt.top-ce.top,w:jt.width,h:jt.height}}),ve=(tt,jt,z,de)=>le.some(ge=>tt<ge.x+ge.w+3&&ge.x<tt+z+3&&jt<ge.y+ge.h+3&&ge.y<jt+de+3),ye=[];for(let tt of it){let jt=D(tt.v);if(tt.kind==="time"){ye.push({t:tt,s:jt});continue}tt.el.style.transform=`translate(${jt.x}px, ${jt.y}px)`;let z=tt.el.offsetWidth,de=tt.el.offsetHeight,ge=tt.kind==="cost"?jt.x-z/2:jt.x,re=tt.el.classList.contains("orbit")?jt.y-de-4:jt.y;tt.el.style.opacity=jt.z<1&&ge>=12&&ge+z<=v-12&&re>=12&&re+de<=b-12&&!ve(ge,re,z,de)?B*(1-_n):0}ye.sort((tt,jt)=>tt.s.y-jt.s.y);let Re=40;for(let tt of ye){let jt=tt.t.el.offsetHeight;tt.y=Math.max(tt.s.y,Re+jt/2+4),Re=tt.y+jt/2}let ze=Math.max(0,Re-(b-125));for(let{t:tt,s:jt,y:z}of ye){let de=tt.el.offsetWidth,ge=tt.el.offsetHeight,re=Math.min(jt.x-8,v-72),Ne=z-ze-ge/2;tt.el.style.transform=`translate(${re}px, ${z-ze}px)`,tt.el.style.opacity=jt.z<1&&re-de>=16&&Ne>=36&&!ve(re-de,Ne,de,ge)?B*(1-_n):0}for(let tt of Oe){let jt=D(tt.v);tt.el.style.transform=`translate(${jt.x-105}px, ${jt.y-10}px)`}if(V)for(let tt of[...n.children,...s.children])for(let jt of tt.getAnimations())"transitionProperty"in jt&&jt.effect.getTiming().iterations!==1/0&&jt.finish()}let Le=[];function Ze(){if(C||!r)return;let R=30,B=100,V=kt=>(Math.max(R,Math.min(B,kt))-R)/(B-R)*100,Z=u.models.filter(kt=>_.has(kt.id)&&g[kt.id]).sort((kt,Ct)=>g[Ct.id][1]-g[kt.id][1]),nt=Z.length?g[Z[0].id][1]:0,Mt=t.getBoundingClientRect(),dt=c()?.getBoundingClientRect();r.style.left=(dt?dt.right-Mt.left:400)+26+"px";let Ot=`<div class="vbar"></div><div class="lead">${l()?`\u9886\u5148 ${nt.toFixed(1)} \xB7 \u8DDD\u661F\u8FB0\u5927\u6D77 ${(100-nt).toFixed(1)}`:`Leader ${nt.toFixed(1)} \xB7 ${(100-nt).toFixed(1)} to the stars`}</div><div class="vwin" style="bottom:${V(pt)}%;height:${V(st)-V(pt)}%" title="${l()?"3D \u89C6\u91CE\u91CC\u7684\u5206\u6570\u6BB5":"Score band shown in 3D"}"></div>`;Ot+=Oc.map(([kt,Ct,ce])=>`<div class="vt ${kt===100?"agi":""}" style="bottom:${V(kt)}%"><b>${kt===100?l()?"\u2605 \u661F\u8FB0\u5927\u6D77":"\u2605 The stars":l()?Ct:ce}</b>${kt}</div>`).join("");let Tt=[];Ot+=Z.map(kt=>{let Ct=g[kt.id][1],ce=Tt.filter(le=>Math.abs(le-Ct)<.9).length;return Tt.push(Ct),`<span class="vdot" data-id="${Fr(kt.id)}" style="--c:${kt.colour};bottom:${V(Ct)}%;left:${11-ce*9}px" title="${Fr(kt.name)} \xB7 ${Ct.toFixed(1)}"></span>`}).join(""),r.innerHTML=Ot,Le=[...r.querySelectorAll(".vdot")],Le.forEach(kt=>{kt.onmouseenter=()=>m=kt.dataset.id,kt.onmouseleave=()=>m=null,kt.onclick=()=>xs(kt.dataset.id)})}let Be=[];function Ve(R){for(let B of u.models){if(!_.has(B.id)||!g[B.id])continue;let V=R[B.id],Z=g[B.id][1],nt=Lt.get(B.id);if(V==null||Z<=V||!nt)continue;let Mt=Oc.filter(([dt])=>dt>V&&dt<=Z).pop();Mt&&(nt.cross=Mt)}}let on=new Yi(1,.035,8,96);function Wt(R,[B,V,Z]){let nt=new Se(on,new an({color:B===100?"#ffd37a":"#9fd8ff",transparent:!0,blending:hn,depthWrite:!1}));nt.position.copy(R.root.position),nt.rotation.x=Math.PI/2,q.add(nt);let Mt=document.createElement("div");Mt.className="burst",Mt.textContent=B===100?l()?"\u2605 \u9A76\u51FA\u592A\u9633\u7CFB \xB7 \u5954\u5411\u661F\u8FB0\u5927\u6D77":"\u2605 Leaving the solar system \xB7 out to the stars":l()?`\u2726 \u8D8A\u8FC7${V}`:`\u2726 Past ${Z}`,n.appendChild(Mt),Be.push({ring:nt,el:Mt,r:R,t0:performance.now()})}function vn(R){for(let B=Be.length-1;B>=0;B--){let V=Be[B],Z=(R-V.t0)/1400;if(Z>=1){q.remove(V.ring),V.ring.material.dispose(),V.el.remove(),Be.splice(B,1);continue}let nt=1-Math.pow(1-Z,3);V.ring.scale.setScalar(.4+nt*3.2),V.ring.material.opacity=(1-Z)*.9;let Mt=D(V.r.root.position.clone().add(gt(0,1.9,0)));V.el.style.transform=`translate(${Mt.x}px, ${Mt.y-nt*26}px)`,V.el.style.opacity=Z<.15?Z/.15:1-Math.max(0,(Z-.6)/.4)}}let Te=0,Tn=performance.now(),Un=Tn,qn=!1,On=0,Ce=0,Ye=-1/0,Bn=!0,Pe=!i.onDemand,pn=0,Pi=0,Vr=0,Yn=null,Us=!1,go=[],Gr=!1,Vc=!1,Fs="",xo="",Mh=0;function rd(){if(!document.fonts)return!0;let R=new Map;for(let V of n.querySelectorAll("*")){if(!V.textContent?.trim())continue;let Z=getComputedStyle(V),nt=`${Z.fontStyle} ${Z.fontWeight} ${Z.fontSize} ${Z.fontFamily}`;R.set(nt,(R.get(nt)||"")+V.textContent)}let B=[...R.keys()].sort().join("|");if(B===Fs)return!0;if(B!==xo){xo=B;let V=++Mh;Promise.all([...R].map(([Z,nt])=>document.fonts.load(Z,nt).catch(()=>[]))).then(()=>document.fonts.ready).then(()=>{Gr||V!==Mh||(Fs=B,$n(0))})}return!1}function _s(){if(Gr||document.hidden||!Bn||On||Ce||!(Pe||Us||pn>0))return;let R=i.onDemand?Math.max(0,1e3/30-(performance.now()-Ye)):0;R>0?Ce=setTimeout(()=>{Ce=0,_s()},Math.ceil(R)):On=requestAnimationFrame(ld)}function ad(R){Pe=!!R,Pe||(pn=0),_s()}function $n(R){Vc=!1,Vr++,Us=!0,pn=Math.max(pn,performance.now()+Math.max(0,R)),_s()}function od(R){return Gr?Promise.reject(new Error("field disposed")):new Promise((B,V)=>{go.push({resolve:B,reject:V,options:R}),$n(0)})}let Wr=0,Gc=0,Sh=0,bh=!i.onSlow;function Eh(){cancelAnimationFrame(On),clearTimeout(Ce),On=Ce=0}function Wc(){document.hidden||!Bn?Eh():(Us=!0,_s())}document.addEventListener("visibilitychange",Wc);let Th=new IntersectionObserver(([R])=>{Bn=R?.isIntersecting??!0,Wc()});Th.observe(t);function ld(R){if(On=0,!Pe&&!pn&&!Us)return;if(R>=pn&&(pn=0),document.hidden||!Bn||!v||!b||!u.models.length){Wr=0,Pe&&_s();return}Us=!1,Ye=R,Pi++,!bh&&qn&&R-Tn>1500&&(Wr&&R-Wr<1e3&&(Gc+=R-Wr,Sh++),Wr=R,Gc>=3e3&&(bh=!0,Sh*1e3/Gc<20&&i.onSlow()));let B=f?0:R/1e3,V=f?1:Math.min(1,(R-Un)/1800),Z=S??m??p;if(Yn){let z=Math.min(1,(R-Yn.start)/600),de=1-(1-z)**3;me.yaw=Yn.yaw+(Yn.endYaw-Yn.yaw)*de,me.pitch=Yn.pitch+(Yn.endPitch-Yn.pitch)*de,z>=1&&(Yn=null)}else if(!me.drag||me.drag.still){let z=E()?at:Pt,de=f||Z?0:Math.sin(B/3.6)*.03;me.vy=me.vy*.85+(z.yaw+de-me.yaw)*.03,me.yaw+=me.vy,me.vp=me.vp*.85+(z.pitch-me.pitch)*.03,me.pitch+=me.vp}if(Dt||Ci(),!Nt||f)Nt={...Dt};else for(let z of["d","ox","oy"])Nt[z]+=(Dt[z]-Nt[z])*.06;let nt=!i.embedded&&S&&_.has(S)&&Lt.get(S),Mt=Ls();_n+=((nt?1:0)-_n)*(f?1:.06);let dt=E()&&nt?mo(nt):null;Ri.lerp(dt?dt.look:nt?nt.root.position.clone().add(gt(0,.3,0)):mi,f?1:.08);let Ot=f?1:Math.min(1,(R-Un)/5200),Tt=1-Math.pow(1-Ot,3),kt=me.pitch-.07*(1-Tt);Te*=.93;let Ct=dt?dt.fy:(Mt.y+Mt.b)/2,ce=dt?dt.d:Math.min(26,Nt.d*.55),le=(Nt.d+(ce-Nt.d)*_n)*(1-.2*(1-Tt)),ve=Nt.ox+(v/2-(Mt.x+Mt.r)/2-Nt.ox)*_n,ye=Nt.oy+(b/2-Ct-Nt.oy)*_n;ht.position.set(Ri.x+le*Math.sin(me.yaw)*Math.cos(kt),Ri.y+le*Math.sin(kt),Ri.z+le*Math.cos(me.yaw)*Math.cos(kt)),ht.lookAt(Ri),Te>.01&&ht.position.add(gt(Math.sin(B*61),Math.sin(B*47+1),Math.sin(B*53+2)).multiplyScalar(.007*le*Te)),ht.setViewOffset(v,b,ve,ye,v,b),Nn.strength=.8-.38*_n+.55*Te,J.toneMappingExposure=1.05-.15*_n,Gt.update(f?0:B),ne.uniforms.t.value=B,Jt.children.forEach(z=>{z.userData.spin&&(z.rotation.y=B*.15)});let Re=i.embedded&&!d?null:Z;Re!==mt&&Ue(Re);let ze=E()?.68:.88;for(let z of Lt.values()){let de=_.has(z.m.id)&&!!g[z.m.id];if(de||(z.soot.visible=!1),z.root.visible=z.trail.visible=z.drop.visible=z.pad.visible=z.padGlow.visible=z.smoke.visible=de,!de)continue;z.pos.lerp(z.tgt,f?1:.08),z.flare+=(1-z.flare)*.035;let ge=R-z.born,re=f?1:Math.max(0,Math.min(1,ge/650)),Ne=f?1:Math.max(0,Math.min(1,(ge-550)/2400)),_e=Ne<.5?4*Ne**3:1-Math.pow(-2*Ne+2,3)/2,ni=re*(1-Ne),gi=re*(1-_e),Ii=j(),Xr=Ii+1.5+(z.pos.y-1.5)*_e,_o=g[z.m.id],wn=Math.max(.15,Math.min(1,(Math.log10(_o[2])+2.2)/2.8))*z.flare+ni*.9,vs=Z===z.m.id||m===z.m.id,Ln=Z&&!vs?i.embedded?.72:.2:1;z.root.position.set(z.pos.x,Xr+(f?0:Math.sin(B*1.1+z.phase)*.06),z.pos.z),F(z);let ii=z.m.id===fe;z.heavy.visible=ii;let Os=!ii&&z.m.racer;z.racer.visible=Os,z.stdParts.forEach(Je=>Je.visible=!ii);let yn=ii?z.steelMap:Os?z.boltMap:z.hullMap;z.steel.metalness=ii?.92:.35,z.steel.roughness=ii?.2:.34,z.steel.map!==yn&&(z.steel.map=yn,z.steel.needsUpdate=!0),Os&&z.streaks.forEach(Je=>{let Di=f?Je.userData.o:(B*1.6+Je.userData.o)%1;Je.position.y=1.2-Di*2.8,Je.material.opacity=.65*Math.sin(Di*Math.PI)*Ln});let Li=ii?z.heavyNozzle:z.NOZZLE_Y;z.outer.position.y=z.inner.position.y=Li+.02,z.light.position.y=Li-.45,z.halo&&(z.halo.rotation.y=f?0:B*.7),z.root.scale.setScalar(ze*(i.embedded?1.15:1)*(vs?1.12:1)*(ii?1.18:1));{let Je=S===z.m.id||z.m.id===fe?me.yaw-.4*Math.PI:B*.12+z.phase,Di=z.g.rotation.y;z.g.rotation.y=Di+Math.atan2(Math.sin(Je-Di),Math.cos(Je-Di))*(f?1:.08)}z.g.rotation.z=f?0:Math.sin(B*.7+z.phase)*.02,z.mats.forEach(Je=>Je.opacity=Ln),z.outer.material.uniforms.t.value=z.inner.material.uniforms.t.value=z.trail.material.uniforms.t.value=z.soot.material.uniforms.t.value=B;for(let Je of z.bOuter)Je.material.uniforms.t.value=B,Je.material.uniforms.k.value=Ln*(.15+.85*re),Je.scale.set(.8+wn*.6,.6+wn*1.2,.8+wn*.6);z.outer.material.uniforms.k.value=z.inner.material.uniforms.k.value=Ln*(.15+.85*re),z.trail.material.uniforms.k.value=Ln*.8*re,z.outer.scale.set((.8+wn*.6)*(z.racer.visible?.75:1),(.6+wn*1.2)*(z.racer.visible?1.45:1),(.8+wn*.6)*(z.racer.visible?.75:1)),z.inner.scale.set(1,.7+wn*.6,1),z.light.intensity=(.6+wn*1.4)*Ln,z.ring.visible=vs&&S!==z.m.id&&_o[0]===z.m.rec,z.ring.quaternion.copy(ht.quaternion),z.ring.material.opacity=Ln;let Zi=z.root.position.y+Li*z.root.scale.y,Ji=Math.max(.05,Zi-Ii);z.trail.position.set(z.pos.x,Zi-.3,z.pos.z),z.trail.scale.set(.5+wn*.8,Math.max(.05,Math.min(Ji-.3,2.6+wn*1.2)),.5+wn*.8),z.soot.visible=z.fuelKind==="lo",z.soot.position.set(z.pos.x,Zi-.5,z.pos.z),z.soot.scale.set(.55+wn*.5,Math.max(.05,Math.min(Ji-.5,1.6+wn*.9)),.55+wn*.5),z.soot.material.uniforms.k.value=Ln*re,z.drop.position.set(z.pos.x,Zi,z.pos.z),z.drop.scale.y=Ji,z.drop.material.opacity=.22*Ln,z.pad.position.set(z.pos.x,Ii+.02,z.pos.z),z.pad.rotation.x=-Math.PI/2,z.pad.material.opacity=.7*Ln,z.padGlow.position.set(z.pos.x,Ii+.1,z.pos.z),z.padGlow.scale.setScalar(1.4+3.2*gi),z.padGlow.material.opacity=Ln*Math.max(.3*_e,.7*gi),z.smoke.position.set(z.pos.x,Ii+.5+Ne*.8,z.pos.z),z.smoke.scale.setScalar(1.2+2.5*re+4.5*Ne),z.smoke.material.opacity=.3*gi*Ln,z.smoke.visible=gi>0,z.cross&&Ne>=1&&Xr-Ii>=lt(z.cross[0])-.05&&(z.cross[0]>=pt-.01&&Wt(z,z.cross),z.cross=null),z.screen=D(M.set(z.pos.x,z.root.position.y+1.2*z.root.scale.y,z.pos.z)),z.base=D(M.set(z.pos.x,Zi-.8,z.pos.z))}qt.children.forEach(z=>{z.userData.bill&&z.quaternion.copy(ht.quaternion)}),vn(R);let tt=!!(Yn||Be.length||[...Lt.values()].some(z=>_.has(z.m.id)&&(!f&&R<z.born+2950||z.pos.distanceToSquared(z.tgt)>25e-6))||Nt&&Dt&&["d","ox","oy"].some(z=>Math.abs(Nt[z]-Dt[z])>.02)||Ri.distanceToSquared(mi)>25e-6),jt=i.onDemand&&!Pe&&!pn&&!tt;if(en.render(),Kt(Z,V,jt&&Fs===xo&&!!Fs),Vc=jt&&rd(),Le.forEach(z=>z.classList.toggle("hot",z.dataset.id===Z)),go.length){let z=go.splice(0);try{for(let{resolve:de,options:ge}of z){if(!ge){de(J.domElement.toDataURL("image/png"));continue}if(ge.canopyFrame){let ni=Nh({renderer:J,composer:en,camera:ht,fit:Ds,target:mi,home:E()?at:Pt,width:ge.width,height:ge.height,liveWidth:v,liveHeight:b,profile:ge.canopyProfile});de(gh(ni));continue}let re=document.createElement("canvas"),Ne=J.domElement;re.width=ge.width,re.height=ge.height;let _e=Math.max(re.width/Ne.width,re.height/Ne.height);re.getContext("2d").drawImage(Ne,(re.width-Ne.width*_e)/2,(re.height-Ne.height*_e)/2,Ne.width*_e,Ne.height*_e),de(gh(re))}}catch(de){z.forEach(({reject:ge})=>ge(de))}}i.onDemand&&tt&&(Us=!0),_s()}if(_s(),globalThis.__mpLabelProbe){let R=new P,B=new Jn,V=new P,Z=Mt=>({x:+Mt.x.toFixed(1),y:+Mt.y.toFixed(1),w:+Mt.w.toFixed(1),h:+Mt.h.toFixed(1)}),nt=(Mt,dt)=>{let Ot=Mt.getBoundingClientRect();return Z({x:Ot.left-dt.left,y:Ot.top-dt.top,w:Ot.width,h:Ot.height})};Object.assign(globalThis.__mpLabelProbe,{view:()=>({yaw:me.yaw,pitch:me.pitch,W:v,H:b,narrow:E(),region:Ls(),zoom:_n}),boxes(){let Mt=t.getBoundingClientRect(),dt=[...n.querySelectorAll(".plate")].map(Ct=>({id:Ct.dataset.id,opacity:+Ct.style.opacity||0,collapsed:Ct.classList.contains("dot"),tight:Ct.classList.contains("tight"),target:Ct._pick&&{x:Math.round(Ct._pick.x),y:Math.round(Ct._pick.y),w:Math.round(Ct._pick.w),cost:Math.round(Ct._pick.cost),slot:Ct._pick.slot},...nt(Ct,Mt)})),Ot=[...n.querySelectorAll(".ltag, .tick3")].map(Ct=>({kind:Ct.classList.contains("tick3")?"tick":Ct.classList.contains("next")?"next":"orbit",text:Ct.textContent,opacity:+getComputedStyle(Ct).opacity||0,...nt(Ct,Mt)})),Tt=[];Jt.children.forEach(Ct=>{if(!Ct.userData.spin)return;Ct.geometry.computeBoundingSphere(),B.copy(Ct.geometry.boundingSphere).applyMatrix4(Ct.matrixWorld);let ce=D(B.center),le=ce.x,ve=ce.y,ye=ce.z;V.setFromMatrixColumn(ht.matrixWorld,0);let Re=D(R.copy(B.center).addScaledVector(V,B.radius)),ze=Math.hypot(Re.x-le,Re.y-ve);ye<1&&Tt.push(Z({x:le-ze,y:ve-ze,w:ze*2,h:ze*2}))});let kt=[];for(let Ct of Lt.values()){if(!_.has(Ct.m.id))continue;Ct.root.updateWorldMatrix(!0,!1);let ce=(Ct.span||.3)*Ct.root.scale.x,le=D(R.set(0,1.6,0).applyMatrix4(Ct.root.matrixWorld)),ve=le.x,ye=le.y,Re=le.z,ze=D(R.set(0,-1.24,0).applyMatrix4(Ct.root.matrixWorld)),tt=ze.x,jt=ze.y;V.setFromMatrixColumn(ht.matrixWorld,0);let z=R.set(0,.18,0).applyMatrix4(Ct.root.matrixWorld).clone(),de=D(z),ge=de.x,re=D(z.addScaledVector(V,ce)),Ne=Math.abs(re.x-ge);Re<1&&kt.push({id:Ct.m.id,nose:{x:+ve.toFixed(1),y:+ye.toFixed(1)},depth:+Re.toFixed(4),...Z({x:Math.min(ve,tt)-Ne,y:ye,w:Math.abs(ve-tt)+Ne*2,h:jt-ye})})}return{chips:dt,tags:Ot,planets:Tt,hulls:kt}}})}return{setActive:ad,renderFor:$n,captureStill:od,stats:()=>({frames:Pi,requests:Vr,active:Pe,labelsSettled:Vc,fontsSettled:!!Fs&&Fs===xo,scheduled:!!On||!!Ce,yaw:me.yaw,pitch:me.pitch,defaultYaw:(E()?at:Pt).yaw,defaultPitch:(E()?at:Pt).pitch}),update(R){R.effortPath!==void 0&&d!==R.effortPath&&(d=R.effortPath,mt=void 0);let B=Object.fromEntries(Object.entries(g).map(([Mt,dt])=>[Mt,dt[1]])),V=_,Z=R.language!==o;o=R.language,u={models:R.models};for(let Mt of Object.keys(g))delete g[Mt];for(let Mt of R.models)Mt.sel&&(g[Mt.id]=Mt.sel);_=new Set(R.shown.filter(Mt=>g[Mt])),S=R.focus&&_.has(R.focus)?R.focus:null,p=R.hint&&_.has(R.hint)?R.hint:null;let nt=performance.now();if(qn){let Mt=[..._].filter(dt=>!V.has(dt));ie(),Mt.forEach((dt,Ot)=>{let Tt=Lt.get(dt);Tt&&(Tt.born=nt+Ot*120)}),Ve(B)}else{Tn=nt;let Mt=id;Un=Mt||i.noIntro?nt-6e3:nt,ie(),u.models.filter(dt=>_.has(dt.id)).sort((dt,Ot)=>g[Ot.id][1]-g[dt.id][1]).forEach((dt,Ot)=>ee(dt).born=Mt||i.noIntro?nt-4e3:nt+700+Ot*300),qn=id=!0}Z&&(Ns=""),$n(i.noIntro?1400:5400)},thrust(){Te=1,$n(1800)},dispose(){if(!Gr){Gr=!0,go.splice(0).forEach(({reject:R})=>R(new Error("field disposed"))),Eh(),document.removeEventListener("visibilitychange",Wc),Pe=!1,pn=0,zr.disconnect(),Th.disconnect(),removeEventListener("pointerdown",Y,!0),removeEventListener("pointerup",$),removeEventListener("pointercancel",Ht);for(let R of Lt.values()){R.mats.forEach(B=>B.dispose()),R.halo?.traverse(B=>{B.geometry?.dispose(),B.material?.dispose()}),R.root.traverse(B=>{B.geometry?.dispose();for(let V of Array.isArray(B.material)?B.material:B.material?[B.material]:[]){for(let Z of Object.values(V))Z?.isTexture&&Z!==xt&&Z.dispose();V.dispose()}});for(let B of[R.trail,R.soot,R.drop,R.pad,R.padGlow,R.smoke])B.material.dispose(),B.geometry!==Ut&&B.geometry!==At&&B.geometry?.dispose()}Ut.dispose(),At.dispose(),on.dispose(),et(Jt),et(Rt),et(qt),Gt.dispose(),_t.dispose(),wt.forEach(R=>R.dispose()),q.traverse(R=>{R.isInstancedMesh&&R.dispose(),R.geometry?.dispose(),R.material?.dispose?.()}),en.passes.forEach(R=>R.dispose()),en.dispose(),J.forceContextLoss(),J.dispose(),q.clear(),Lt.clear(),wt.length=0,e.replaceChildren(),n.querySelectorAll(".plate, .ltag, .tick3, .bl3, .burst").forEach(R=>R.remove()),s.replaceChildren(),r&&r.replaceChildren()}}}}function Ry(i,{models:t,focus:e,onSelect:n,onFail:s,quiet:r=!1,showPath:a=!1,compactFrame:o=!1,canopyFrame:l=!1,canopyProfile:c,language:h="zh",onDemand:f=!1,noIntro:u=!1,stillCapture:d=!1,labels:g=null}){let _=S=>`<img src="assets/brands/${S==="anthropic"?"claude.svg":S==="zhipu"?"zhipu.svg":"openai-white.svg"}" alt="">`,m;try{m=sd({launch:i,host:i.querySelector(".wb-canvas"),plates:i.querySelector(".wb-plates"),leaders:i.querySelector(".wb-leaders"),voyage:i.querySelector(".wb-voyage"),copySelector:".not-mounted-copy",panelSelector:".not-mounted-panel",embedded:!0,compactFrame:o,canopyFrame:l,canopyProfile:c,quiet:r,onDemand:f,noIntro:u,stillCapture:d,labels:g,showEffortPath:a,language:h,logo:_,onSelect:n,onFail:s})}catch(S){return s?.(S),{update(){},setActive(){},renderFor(){},captureStill:()=>Promise.reject(S),stats:()=>({frames:0,active:!1,scheduled:!1}),dispose(){}}}let p=(S,A,v=a)=>m.update({effortPath:v,language:h,models:S,shown:S.map(b=>b.id),focus:A,hint:null});return p(t,e),{update:p,setActive:S=>m.setActive(S),renderFor:S=>m.renderFor(S),captureStill:S=>m.captureStill(S),stats:()=>m.stats(),dispose:()=>m.dispose(),thrust:()=>m.thrust()}}export{Ry as mountWorkbenchField};
/*! Bundled license information:

three/build/three.core.js:
three/build/three.module.js:
  (**
   * @license
   * Copyright 2010-2026 Three.js Authors
   * SPDX-License-Identifier: MIT
   *)
*/
