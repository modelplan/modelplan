/*! SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
 * Copyright (c) 2026 ModelPlan. All rights reserved. ModelPlan and Model Plan are marks of ModelPlan. No trademark rights are granted.
 * Launch field component 1.2.0, window mode (D298), for the official cockpit's enlarged field; see README.md.
 * Bundles three.js 0.186.1 (MIT; its licence block is at the end of this file). */
const __LF_ENV__ = { BASE_URL: new URL("./", import.meta.url).href };
var ju=0,q0=1,Qu=2;var Wa=1,td=2,Ar=3,fs=0,Rn=1,Cn=2,Qn=0,ps=1,pn=2,Y0=3,Z0=4,ed=5;var As=100,nd=101,id=102,sd=103,rd=104,ad=200,od=201,ld=202,cd=203,J0=204,K0=205,hd=206,ud=207,dd=208,fd=209,pd=210,md=211,gd=212,xd=213,_d=214,tl=0,el=1,nl=2,or=3,il=4,sl=5,rl=6,al=7,j0=0,vd=1,yd=2,fi=0,Xa=1,$a=2,qa=3,Rs=4,Ya=5,Za=6,Ja=7;var Q0=300,ms=301,Cs=302,Rr=303,Fl=304,Ka=306,rs=1e3,yi=1001,ol=1002,bn=1003,Md=1004;var ja=1005;var An=1006,Ol=1007;var Ti=1008;var kn=1009,th=1010,eh=1011,Cr=1012,Bl=1013,pi=1014,ti=1015,mn=1016,zl=1017,kl=1018,Ir=1020,nh=35902,ih=35899,sh=1021,rh=1022,ei=1023,bi=1026,gs=1027,Hl=1028,Vl=1029,xs=1030,Gl=1031;var Wl=1033,Qa=33776,to=33777,eo=33778,no=33779,Xl=35840,$l=35841,ql=35842,Yl=35843,Zl=36196,Jl=37492,Kl=37496,jl=37488,Ql=37489,io=37490,tc=37491,ec=37808,nc=37809,ic=37810,sc=37811,rc=37812,ac=37813,oc=37814,lc=37815,cc=37816,hc=37817,uc=37818,dc=37819,fc=37820,pc=37821,mc=36492,gc=36494,xc=36495,_c=36283,vc=36284,so=36285,yc=36286;var ra=2300,ll=2301,Ko=2302,D0=2303,U0=2400,F0=2401,O0=2402;var bd=3200;var Mc=0,Sd=1,mi="",tn="srgb",aa="srgb-linear",oa="linear",Oe="srgb";var jo=7680;var wd=519,Ed=512,Td=513,Ad=514,bc=515,Rd=516,Cd=517,Sc=518,Id=519,ah=35044;var oh="300 es",hi=2e3,lr=2001;function pp(i){for(let t=i.length-1;t>=0;--t)if(i[t]>=65535)return!0;return!1}function mp(i){return ArrayBuffer.isView(i)&&!(i instanceof DataView)}function cr(i){return document.createElementNS("http://www.w3.org/1999/xhtml",i)}function Pd(){let i=cr("canvas");return i.style.display="block",i}var fu={},hr=null;function la(...i){let t="THREE."+i.shift();hr?hr("log",t,...i):console.log(t,...i)}function Ld(i){let t=i[0];if(typeof t=="string"&&t.startsWith("TSL:")){let e=i[1];e&&e.isStackTrace?i[0]+=" "+e.getLocation():i[1]='Stack trace not available. Enable "THREE.Node.captureStackTrace" to capture stack traces.'}return i}function pe(...i){i=Ld(i);let t="THREE."+i.shift();if(hr)hr("warn",t,...i);else{let e=i[0];e&&e.isStackTrace?console.warn(e.getError(t)):console.warn(t,...i)}}function fe(...i){i=Ld(i);let t="THREE."+i.shift();if(hr)hr("error",t,...i);else{let e=i[0];e&&e.isStackTrace?console.error(e.getError(t)):console.error(t,...i)}}function ws(...i){let t=i.join(" ");t in fu||(fu[t]=!0,pe(...i))}function Nd(i,t,e){return new Promise(function(n,s){function r(){switch(i.clientWaitSync(t,i.SYNC_FLUSH_COMMANDS_BIT,0)){case i.WAIT_FAILED:s();break;case i.TIMEOUT_EXPIRED:setTimeout(r,e);break;default:n()}}setTimeout(r,e)})}var Dd={[tl]:el,[nl]:rl,[il]:al,[or]:sl,[el]:tl,[rl]:nl,[al]:il,[sl]:or},Si=class{addEventListener(t,e){this._listeners===void 0&&(this._listeners={});let n=this._listeners;n[t]===void 0&&(n[t]=[]),n[t].indexOf(e)===-1&&n[t].push(e)}hasEventListener(t,e){let n=this._listeners;return n===void 0?!1:n[t]!==void 0&&n[t].indexOf(e)!==-1}removeEventListener(t,e){let n=this._listeners;if(n===void 0)return;let s=n[t];if(s!==void 0){let r=s.indexOf(e);r!==-1&&s.splice(r,1)}}dispatchEvent(t){let e=this._listeners;if(e===void 0)return;let n=e[t.type];if(n!==void 0){t.target=this;let s=n.slice(0);for(let r=0,a=s.length;r<a;r++)s[r].call(this,t);t.target=null}}},Nn=["00","01","02","03","04","05","06","07","08","09","0a","0b","0c","0d","0e","0f","10","11","12","13","14","15","16","17","18","19","1a","1b","1c","1d","1e","1f","20","21","22","23","24","25","26","27","28","29","2a","2b","2c","2d","2e","2f","30","31","32","33","34","35","36","37","38","39","3a","3b","3c","3d","3e","3f","40","41","42","43","44","45","46","47","48","49","4a","4b","4c","4d","4e","4f","50","51","52","53","54","55","56","57","58","59","5a","5b","5c","5d","5e","5f","60","61","62","63","64","65","66","67","68","69","6a","6b","6c","6d","6e","6f","70","71","72","73","74","75","76","77","78","79","7a","7b","7c","7d","7e","7f","80","81","82","83","84","85","86","87","88","89","8a","8b","8c","8d","8e","8f","90","91","92","93","94","95","96","97","98","99","9a","9b","9c","9d","9e","9f","a0","a1","a2","a3","a4","a5","a6","a7","a8","a9","aa","ab","ac","ad","ae","af","b0","b1","b2","b3","b4","b5","b6","b7","b8","b9","ba","bb","bc","bd","be","bf","c0","c1","c2","c3","c4","c5","c6","c7","c8","c9","ca","cb","cc","cd","ce","cf","d0","d1","d2","d3","d4","d5","d6","d7","d8","d9","da","db","dc","dd","de","df","e0","e1","e2","e3","e4","e5","e6","e7","e8","e9","ea","eb","ec","ed","ee","ef","f0","f1","f2","f3","f4","f5","f6","f7","f8","f9","fa","fb","fc","fd","fe","ff"];var a0=Math.PI/180,cl=180/Math.PI;function ki(){let i=Math.random()*4294967295|0,t=Math.random()*4294967295|0,e=Math.random()*4294967295|0,n=Math.random()*4294967295|0;return(Nn[i&255]+Nn[i>>8&255]+Nn[i>>16&255]+Nn[i>>24&255]+"-"+Nn[t&255]+Nn[t>>8&255]+"-"+Nn[t>>16&15|64]+Nn[t>>24&255]+"-"+Nn[e&63|128]+Nn[e>>8&255]+"-"+Nn[e>>16&255]+Nn[e>>24&255]+Nn[n&255]+Nn[n>>8&255]+Nn[n>>16&255]+Nn[n>>24&255]).toLowerCase()}function Ae(i,t,e){return Math.max(t,Math.min(e,i))}function gp(i,t){return(i%t+t)%t}function o0(i,t,e){return(1-e)*i+e*t}function vi(i,t){switch(t.constructor){case Float32Array:return i;case Uint32Array:return i/4294967295;case Uint16Array:return i/65535;case Uint8Array:case Uint8ClampedArray:return i/255;case Int32Array:return Math.max(i/2147483647,-1);case Int16Array:return Math.max(i/32767,-1);case Int8Array:return Math.max(i/127,-1);default:throw new Error("THREE.MathUtils: Invalid component type.")}}function Ye(i,t){switch(t.constructor){case Float32Array:return i;case Uint32Array:return Math.round(i*4294967295);case Uint16Array:return Math.round(i*65535);case Uint8Array:case Uint8ClampedArray:return Math.round(i*255);case Int32Array:return Math.round(i*2147483647);case Int16Array:return Math.round(i*32767);case Int8Array:return Math.round(i*127);default:throw new Error("THREE.MathUtils: Invalid component type.")}}var yt=class i{static{i.prototype.isVector2=!0}constructor(t=0,e=0){this.x=t,this.y=e}get width(){return this.x}set width(t){this.x=t}get height(){return this.y}set height(t){this.y=t}set(t,e){return this.x=t,this.y=e,this}setScalar(t){return this.x=t,this.y=t,this}setX(t){return this.x=t,this}setY(t){return this.y=t,this}setComponent(t,e){switch(t){case 0:this.x=e;break;case 1:this.y=e;break;default:throw new Error("THREE.Vector2: index is out of range: "+t)}return this}getComponent(t){switch(t){case 0:return this.x;case 1:return this.y;default:throw new Error("THREE.Vector2: index is out of range: "+t)}}clone(){return new this.constructor(this.x,this.y)}copy(t){return this.x=t.x,this.y=t.y,this}add(t){return this.x+=t.x,this.y+=t.y,this}addScalar(t){return this.x+=t,this.y+=t,this}addVectors(t,e){return this.x=t.x+e.x,this.y=t.y+e.y,this}addScaledVector(t,e){return this.x+=t.x*e,this.y+=t.y*e,this}sub(t){return this.x-=t.x,this.y-=t.y,this}subScalar(t){return this.x-=t,this.y-=t,this}subVectors(t,e){return this.x=t.x-e.x,this.y=t.y-e.y,this}multiply(t){return this.x*=t.x,this.y*=t.y,this}multiplyScalar(t){return this.x*=t,this.y*=t,this}divide(t){return this.x/=t.x,this.y/=t.y,this}divideScalar(t){return this.multiplyScalar(1/t)}applyMatrix3(t){let e=this.x,n=this.y,s=t.elements;return this.x=s[0]*e+s[3]*n+s[6],this.y=s[1]*e+s[4]*n+s[7],this}min(t){return this.x=Math.min(this.x,t.x),this.y=Math.min(this.y,t.y),this}max(t){return this.x=Math.max(this.x,t.x),this.y=Math.max(this.y,t.y),this}clamp(t,e){return this.x=Ae(this.x,t.x,e.x),this.y=Ae(this.y,t.y,e.y),this}clampScalar(t,e){return this.x=Ae(this.x,t,e),this.y=Ae(this.y,t,e),this}clampLength(t,e){let n=this.length();return this.divideScalar(n||1).multiplyScalar(Ae(n,t,e))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this}negate(){return this.x=-this.x,this.y=-this.y,this}dot(t){return this.x*t.x+this.y*t.y}cross(t){return this.x*t.y-this.y*t.x}lengthSq(){return this.x*this.x+this.y*this.y}length(){return Math.sqrt(this.x*this.x+this.y*this.y)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)}normalize(){return this.divideScalar(this.length()||1)}angle(){return Math.atan2(-this.y,-this.x)+Math.PI}angleTo(t){let e=Math.sqrt(this.lengthSq()*t.lengthSq());if(e===0)return Math.PI/2;let n=this.dot(t)/e;return Math.acos(Ae(n,-1,1))}distanceTo(t){return Math.sqrt(this.distanceToSquared(t))}distanceToSquared(t){let e=this.x-t.x,n=this.y-t.y;return e*e+n*n}manhattanDistanceTo(t){return Math.abs(this.x-t.x)+Math.abs(this.y-t.y)}setLength(t){return this.normalize().multiplyScalar(t)}lerp(t,e){return this.x+=(t.x-this.x)*e,this.y+=(t.y-this.y)*e,this}lerpVectors(t,e,n){return this.x=t.x+(e.x-t.x)*n,this.y=t.y+(e.y-t.y)*n,this}equals(t){return t.x===this.x&&t.y===this.y}fromArray(t,e=0){return this.x=t[e],this.y=t[e+1],this}toArray(t=[],e=0){return t[e]=this.x,t[e+1]=this.y,t}fromBufferAttribute(t,e){return this.x=t.getX(e),this.y=t.getY(e),this}rotateAround(t,e){let n=Math.cos(e),s=Math.sin(e),r=this.x-t.x,a=this.y-t.y;return this.x=r*n-a*s+t.x,this.y=r*s+a*n+t.y,this}random(){return this.x=Math.random(),this.y=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y}},wi=class{constructor(t=0,e=0,n=0,s=1){this.isQuaternion=!0,this._x=t,this._y=e,this._z=n,this._w=s}static slerpFlat(t,e,n,s,r,a,o){let c=n[s+0],l=n[s+1],h=n[s+2],f=n[s+3],u=r[a+0],d=r[a+1],m=r[a+2],x=r[a+3];if(f!==x||c!==u||l!==d||h!==m){let g=c*u+l*d+h*m+f*x;g<0&&(u=-u,d=-d,m=-m,x=-x,g=-g);let p=1-o;if(g<.9995){let b=Math.acos(g),E=Math.sin(b);p=Math.sin(p*b)/E,o=Math.sin(o*b)/E,c=c*p+u*o,l=l*p+d*o,h=h*p+m*o,f=f*p+x*o}else{c=c*p+u*o,l=l*p+d*o,h=h*p+m*o,f=f*p+x*o;let b=1/Math.sqrt(c*c+l*l+h*h+f*f);c*=b,l*=b,h*=b,f*=b}}t[e]=c,t[e+1]=l,t[e+2]=h,t[e+3]=f}static multiplyQuaternionsFlat(t,e,n,s,r,a){let o=n[s],c=n[s+1],l=n[s+2],h=n[s+3],f=r[a],u=r[a+1],d=r[a+2],m=r[a+3];return t[e]=o*m+h*f+c*d-l*u,t[e+1]=c*m+h*u+l*f-o*d,t[e+2]=l*m+h*d+o*u-c*f,t[e+3]=h*m-o*f-c*u-l*d,t}get x(){return this._x}set x(t){this._x=t,this._onChangeCallback()}get y(){return this._y}set y(t){this._y=t,this._onChangeCallback()}get z(){return this._z}set z(t){this._z=t,this._onChangeCallback()}get w(){return this._w}set w(t){this._w=t,this._onChangeCallback()}set(t,e,n,s){return this._x=t,this._y=e,this._z=n,this._w=s,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._w)}copy(t){return this._x=t.x,this._y=t.y,this._z=t.z,this._w=t.w,this._onChangeCallback(),this}setFromEuler(t,e=!0){let n=t._x,s=t._y,r=t._z,a=t._order,o=Math.cos,c=Math.sin,l=o(n/2),h=o(s/2),f=o(r/2),u=c(n/2),d=c(s/2),m=c(r/2);switch(a){case"XYZ":this._x=u*h*f+l*d*m,this._y=l*d*f-u*h*m,this._z=l*h*m+u*d*f,this._w=l*h*f-u*d*m;break;case"YXZ":this._x=u*h*f+l*d*m,this._y=l*d*f-u*h*m,this._z=l*h*m-u*d*f,this._w=l*h*f+u*d*m;break;case"ZXY":this._x=u*h*f-l*d*m,this._y=l*d*f+u*h*m,this._z=l*h*m+u*d*f,this._w=l*h*f-u*d*m;break;case"ZYX":this._x=u*h*f-l*d*m,this._y=l*d*f+u*h*m,this._z=l*h*m-u*d*f,this._w=l*h*f+u*d*m;break;case"YZX":this._x=u*h*f+l*d*m,this._y=l*d*f+u*h*m,this._z=l*h*m-u*d*f,this._w=l*h*f-u*d*m;break;case"XZY":this._x=u*h*f-l*d*m,this._y=l*d*f-u*h*m,this._z=l*h*m+u*d*f,this._w=l*h*f+u*d*m;break;default:pe("Quaternion: .setFromEuler() encountered an unknown order: "+a)}return e===!0&&this._onChangeCallback(),this}setFromAxisAngle(t,e){let n=e/2,s=Math.sin(n);return this._x=t.x*s,this._y=t.y*s,this._z=t.z*s,this._w=Math.cos(n),this._onChangeCallback(),this}setFromRotationMatrix(t){let e=t.elements,n=e[0],s=e[4],r=e[8],a=e[1],o=e[5],c=e[9],l=e[2],h=e[6],f=e[10],u=n+o+f;if(u>0){let d=.5/Math.sqrt(u+1);this._w=.25/d,this._x=(h-c)*d,this._y=(r-l)*d,this._z=(a-s)*d}else if(n>o&&n>f){let d=2*Math.sqrt(1+n-o-f);this._w=(h-c)/d,this._x=.25*d,this._y=(s+a)/d,this._z=(r+l)/d}else if(o>f){let d=2*Math.sqrt(1+o-n-f);this._w=(r-l)/d,this._x=(s+a)/d,this._y=.25*d,this._z=(c+h)/d}else{let d=2*Math.sqrt(1+f-n-o);this._w=(a-s)/d,this._x=(r+l)/d,this._y=(c+h)/d,this._z=.25*d}return this._onChangeCallback(),this}setFromUnitVectors(t,e){let n=t.dot(e)+1;return n<1e-8?(n=0,Math.abs(t.x)>Math.abs(t.z)?(this._x=-t.y,this._y=t.x,this._z=0,this._w=n):(this._x=0,this._y=-t.z,this._z=t.y,this._w=n)):(this._x=t.y*e.z-t.z*e.y,this._y=t.z*e.x-t.x*e.z,this._z=t.x*e.y-t.y*e.x,this._w=n),this.normalize()}angleTo(t){return 2*Math.acos(Math.abs(Ae(this.dot(t),-1,1)))}rotateTowards(t,e){let n=this.angleTo(t);if(n===0)return this;let s=Math.min(1,e/n);return this.slerp(t,s),this}identity(){return this.set(0,0,0,1)}invert(){return this.conjugate()}conjugate(){return this._x*=-1,this._y*=-1,this._z*=-1,this._onChangeCallback(),this}dot(t){return this._x*t._x+this._y*t._y+this._z*t._z+this._w*t._w}lengthSq(){return this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w}length(){return Math.sqrt(this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w)}normalize(){let t=this.length();return t===0?(this._x=0,this._y=0,this._z=0,this._w=1):(t=1/t,this._x=this._x*t,this._y=this._y*t,this._z=this._z*t,this._w=this._w*t),this._onChangeCallback(),this}multiply(t){return this.multiplyQuaternions(this,t)}premultiply(t){return this.multiplyQuaternions(t,this)}multiplyQuaternions(t,e){let n=t._x,s=t._y,r=t._z,a=t._w,o=e._x,c=e._y,l=e._z,h=e._w;return this._x=n*h+a*o+s*l-r*c,this._y=s*h+a*c+r*o-n*l,this._z=r*h+a*l+n*c-s*o,this._w=a*h-n*o-s*c-r*l,this._onChangeCallback(),this}slerp(t,e){let n=t._x,s=t._y,r=t._z,a=t._w,o=this.dot(t);o<0&&(n=-n,s=-s,r=-r,a=-a,o=-o);let c=1-e;if(o<.9995){let l=Math.acos(o),h=Math.sin(l);c=Math.sin(c*l)/h,e=Math.sin(e*l)/h,this._x=this._x*c+n*e,this._y=this._y*c+s*e,this._z=this._z*c+r*e,this._w=this._w*c+a*e,this._onChangeCallback()}else this._x=this._x*c+n*e,this._y=this._y*c+s*e,this._z=this._z*c+r*e,this._w=this._w*c+a*e,this.normalize();return this}slerpQuaternions(t,e,n){return this.copy(t).slerp(e,n)}random(){let t=2*Math.PI*Math.random(),e=2*Math.PI*Math.random(),n=Math.random(),s=Math.sqrt(1-n),r=Math.sqrt(n);return this.set(s*Math.sin(t),s*Math.cos(t),r*Math.sin(e),r*Math.cos(e))}equals(t){return t._x===this._x&&t._y===this._y&&t._z===this._z&&t._w===this._w}fromArray(t,e=0){return this._x=t[e],this._y=t[e+1],this._z=t[e+2],this._w=t[e+3],this._onChangeCallback(),this}toArray(t=[],e=0){return t[e]=this._x,t[e+1]=this._y,t[e+2]=this._z,t[e+3]=this._w,t}fromBufferAttribute(t,e){return this._x=t.getX(e),this._y=t.getY(e),this._z=t.getZ(e),this._w=t.getW(e),this._onChangeCallback(),this}toJSON(){return this.toArray()}_onChange(t){return this._onChangeCallback=t,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._w}},D=class i{static{i.prototype.isVector3=!0}constructor(t=0,e=0,n=0){this.x=t,this.y=e,this.z=n}set(t,e,n){return n===void 0&&(n=this.z),this.x=t,this.y=e,this.z=n,this}setScalar(t){return this.x=t,this.y=t,this.z=t,this}setX(t){return this.x=t,this}setY(t){return this.y=t,this}setZ(t){return this.z=t,this}setComponent(t,e){switch(t){case 0:this.x=e;break;case 1:this.y=e;break;case 2:this.z=e;break;default:throw new Error("THREE.Vector3: index is out of range: "+t)}return this}getComponent(t){switch(t){case 0:return this.x;case 1:return this.y;case 2:return this.z;default:throw new Error("THREE.Vector3: index is out of range: "+t)}}clone(){return new this.constructor(this.x,this.y,this.z)}copy(t){return this.x=t.x,this.y=t.y,this.z=t.z,this}add(t){return this.x+=t.x,this.y+=t.y,this.z+=t.z,this}addScalar(t){return this.x+=t,this.y+=t,this.z+=t,this}addVectors(t,e){return this.x=t.x+e.x,this.y=t.y+e.y,this.z=t.z+e.z,this}addScaledVector(t,e){return this.x+=t.x*e,this.y+=t.y*e,this.z+=t.z*e,this}sub(t){return this.x-=t.x,this.y-=t.y,this.z-=t.z,this}subScalar(t){return this.x-=t,this.y-=t,this.z-=t,this}subVectors(t,e){return this.x=t.x-e.x,this.y=t.y-e.y,this.z=t.z-e.z,this}multiply(t){return this.x*=t.x,this.y*=t.y,this.z*=t.z,this}multiplyScalar(t){return this.x*=t,this.y*=t,this.z*=t,this}multiplyVectors(t,e){return this.x=t.x*e.x,this.y=t.y*e.y,this.z=t.z*e.z,this}applyEuler(t){return this.applyQuaternion(pu.setFromEuler(t))}applyAxisAngle(t,e){return this.applyQuaternion(pu.setFromAxisAngle(t,e))}applyMatrix3(t){let e=this.x,n=this.y,s=this.z,r=t.elements;return this.x=r[0]*e+r[3]*n+r[6]*s,this.y=r[1]*e+r[4]*n+r[7]*s,this.z=r[2]*e+r[5]*n+r[8]*s,this}applyNormalMatrix(t){return this.applyMatrix3(t).normalize()}applyMatrix4(t){let e=this.x,n=this.y,s=this.z,r=t.elements,a=1/(r[3]*e+r[7]*n+r[11]*s+r[15]);return this.x=(r[0]*e+r[4]*n+r[8]*s+r[12])*a,this.y=(r[1]*e+r[5]*n+r[9]*s+r[13])*a,this.z=(r[2]*e+r[6]*n+r[10]*s+r[14])*a,this}applyQuaternion(t){let e=this.x,n=this.y,s=this.z,r=t.x,a=t.y,o=t.z,c=t.w,l=2*(a*s-o*n),h=2*(o*e-r*s),f=2*(r*n-a*e);return this.x=e+c*l+a*f-o*h,this.y=n+c*h+o*l-r*f,this.z=s+c*f+r*h-a*l,this}project(t){return this.applyMatrix4(t.matrixWorldInverse).applyMatrix4(t.projectionMatrix)}unproject(t){return this.applyMatrix4(t.projectionMatrixInverse).applyMatrix4(t.matrixWorld)}transformDirection(t){let e=this.x,n=this.y,s=this.z,r=t.elements;return this.x=r[0]*e+r[4]*n+r[8]*s,this.y=r[1]*e+r[5]*n+r[9]*s,this.z=r[2]*e+r[6]*n+r[10]*s,this.normalize()}divide(t){return this.x/=t.x,this.y/=t.y,this.z/=t.z,this}divideScalar(t){return this.multiplyScalar(1/t)}min(t){return this.x=Math.min(this.x,t.x),this.y=Math.min(this.y,t.y),this.z=Math.min(this.z,t.z),this}max(t){return this.x=Math.max(this.x,t.x),this.y=Math.max(this.y,t.y),this.z=Math.max(this.z,t.z),this}clamp(t,e){return this.x=Ae(this.x,t.x,e.x),this.y=Ae(this.y,t.y,e.y),this.z=Ae(this.z,t.z,e.z),this}clampScalar(t,e){return this.x=Ae(this.x,t,e),this.y=Ae(this.y,t,e),this.z=Ae(this.z,t,e),this}clampLength(t,e){let n=this.length();return this.divideScalar(n||1).multiplyScalar(Ae(n,t,e))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this}dot(t){return this.x*t.x+this.y*t.y+this.z*t.z}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)}normalize(){return this.divideScalar(this.length()||1)}setLength(t){return this.normalize().multiplyScalar(t)}lerp(t,e){return this.x+=(t.x-this.x)*e,this.y+=(t.y-this.y)*e,this.z+=(t.z-this.z)*e,this}lerpVectors(t,e,n){return this.x=t.x+(e.x-t.x)*n,this.y=t.y+(e.y-t.y)*n,this.z=t.z+(e.z-t.z)*n,this}cross(t){return this.crossVectors(this,t)}crossVectors(t,e){let n=t.x,s=t.y,r=t.z,a=e.x,o=e.y,c=e.z;return this.x=s*c-r*o,this.y=r*a-n*c,this.z=n*o-s*a,this}projectOnVector(t){let e=t.lengthSq();if(e===0)return this.set(0,0,0);let n=t.dot(this)/e;return this.copy(t).multiplyScalar(n)}projectOnPlane(t){return l0.copy(this).projectOnVector(t),this.sub(l0)}reflect(t){return this.sub(l0.copy(t).multiplyScalar(2*this.dot(t)))}angleTo(t){let e=Math.sqrt(this.lengthSq()*t.lengthSq());if(e===0)return Math.PI/2;let n=this.dot(t)/e;return Math.acos(Ae(n,-1,1))}distanceTo(t){return Math.sqrt(this.distanceToSquared(t))}distanceToSquared(t){let e=this.x-t.x,n=this.y-t.y,s=this.z-t.z;return e*e+n*n+s*s}manhattanDistanceTo(t){return Math.abs(this.x-t.x)+Math.abs(this.y-t.y)+Math.abs(this.z-t.z)}setFromSpherical(t){return this.setFromSphericalCoords(t.radius,t.phi,t.theta)}setFromSphericalCoords(t,e,n){let s=Math.sin(e)*t;return this.x=s*Math.sin(n),this.y=Math.cos(e)*t,this.z=s*Math.cos(n),this}setFromCylindrical(t){return this.setFromCylindricalCoords(t.radius,t.theta,t.y)}setFromCylindricalCoords(t,e,n){return this.x=t*Math.sin(e),this.y=n,this.z=t*Math.cos(e),this}setFromMatrixPosition(t){let e=t.elements;return this.x=e[12],this.y=e[13],this.z=e[14],this}setFromMatrixScale(t){let e=this.setFromMatrixColumn(t,0).length(),n=this.setFromMatrixColumn(t,1).length(),s=this.setFromMatrixColumn(t,2).length();return this.x=e,this.y=n,this.z=s,this}setFromMatrixColumn(t,e){return this.fromArray(t.elements,e*4)}setFromMatrix3Column(t,e){return this.fromArray(t.elements,e*3)}setFromEuler(t){return this.x=t._x,this.y=t._y,this.z=t._z,this}setFromColor(t){return this.x=t.r,this.y=t.g,this.z=t.b,this}equals(t){return t.x===this.x&&t.y===this.y&&t.z===this.z}fromArray(t,e=0){return this.x=t[e],this.y=t[e+1],this.z=t[e+2],this}toArray(t=[],e=0){return t[e]=this.x,t[e+1]=this.y,t[e+2]=this.z,t}fromBufferAttribute(t,e){return this.x=t.getX(e),this.y=t.getY(e),this.z=t.getZ(e),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this}randomDirection(){let t=Math.random()*Math.PI*2,e=Math.random()*2-1,n=Math.sqrt(1-e*e);return this.x=n*Math.cos(t),this.y=e,this.z=n*Math.sin(t),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z}},l0=new D,pu=new wi,ve=class i{static{i.prototype.isMatrix3=!0}constructor(t,e,n,s,r,a,o,c,l){this.elements=[1,0,0,0,1,0,0,0,1],t!==void 0&&this.set(t,e,n,s,r,a,o,c,l)}set(t,e,n,s,r,a,o,c,l){let h=this.elements;return h[0]=t,h[1]=s,h[2]=o,h[3]=e,h[4]=r,h[5]=c,h[6]=n,h[7]=a,h[8]=l,this}identity(){return this.set(1,0,0,0,1,0,0,0,1),this}copy(t){let e=this.elements,n=t.elements;return e[0]=n[0],e[1]=n[1],e[2]=n[2],e[3]=n[3],e[4]=n[4],e[5]=n[5],e[6]=n[6],e[7]=n[7],e[8]=n[8],this}extractBasis(t,e,n){return t.setFromMatrix3Column(this,0),e.setFromMatrix3Column(this,1),n.setFromMatrix3Column(this,2),this}setFromMatrix4(t){let e=t.elements;return this.set(e[0],e[4],e[8],e[1],e[5],e[9],e[2],e[6],e[10]),this}multiply(t){return this.multiplyMatrices(this,t)}premultiply(t){return this.multiplyMatrices(t,this)}multiplyMatrices(t,e){let n=t.elements,s=e.elements,r=this.elements,a=n[0],o=n[3],c=n[6],l=n[1],h=n[4],f=n[7],u=n[2],d=n[5],m=n[8],x=s[0],g=s[3],p=s[6],b=s[1],E=s[4],y=s[7],w=s[2],S=s[5],C=s[8];return r[0]=a*x+o*b+c*w,r[3]=a*g+o*E+c*S,r[6]=a*p+o*y+c*C,r[1]=l*x+h*b+f*w,r[4]=l*g+h*E+f*S,r[7]=l*p+h*y+f*C,r[2]=u*x+d*b+m*w,r[5]=u*g+d*E+m*S,r[8]=u*p+d*y+m*C,this}multiplyScalar(t){let e=this.elements;return e[0]*=t,e[3]*=t,e[6]*=t,e[1]*=t,e[4]*=t,e[7]*=t,e[2]*=t,e[5]*=t,e[8]*=t,this}determinant(){let t=this.elements,e=t[0],n=t[1],s=t[2],r=t[3],a=t[4],o=t[5],c=t[6],l=t[7],h=t[8];return e*a*h-e*o*l-n*r*h+n*o*c+s*r*l-s*a*c}invert(){let t=this.elements,e=t[0],n=t[1],s=t[2],r=t[3],a=t[4],o=t[5],c=t[6],l=t[7],h=t[8],f=h*a-o*l,u=o*c-h*r,d=l*r-a*c,m=e*f+n*u+s*d;if(m===0)return this.set(0,0,0,0,0,0,0,0,0);let x=1/m;return t[0]=f*x,t[1]=(s*l-h*n)*x,t[2]=(o*n-s*a)*x,t[3]=u*x,t[4]=(h*e-s*c)*x,t[5]=(s*r-o*e)*x,t[6]=d*x,t[7]=(n*c-l*e)*x,t[8]=(a*e-n*r)*x,this}transpose(){let t,e=this.elements;return t=e[1],e[1]=e[3],e[3]=t,t=e[2],e[2]=e[6],e[6]=t,t=e[5],e[5]=e[7],e[7]=t,this}getNormalMatrix(t){return this.setFromMatrix4(t).invert().transpose()}transposeIntoArray(t){let e=this.elements;return t[0]=e[0],t[1]=e[3],t[2]=e[6],t[3]=e[1],t[4]=e[4],t[5]=e[7],t[6]=e[2],t[7]=e[5],t[8]=e[8],this}setUvTransform(t,e,n,s,r,a,o){let c=Math.cos(r),l=Math.sin(r);return this.set(n*c,n*l,-n*(c*a+l*o)+a+t,-s*l,s*c,-s*(-l*a+c*o)+o+e,0,0,1),this}scale(t,e){return ws("Matrix3: .scale() is deprecated. Use .makeScale() instead."),this.premultiply(c0.makeScale(t,e)),this}rotate(t){return ws("Matrix3: .rotate() is deprecated. Use .makeRotation() instead."),this.premultiply(c0.makeRotation(-t)),this}translate(t,e){return ws("Matrix3: .translate() is deprecated. Use .makeTranslation() instead."),this.premultiply(c0.makeTranslation(t,e)),this}makeTranslation(t,e){return t.isVector2?this.set(1,0,t.x,0,1,t.y,0,0,1):this.set(1,0,t,0,1,e,0,0,1),this}makeRotation(t){let e=Math.cos(t),n=Math.sin(t);return this.set(e,-n,0,n,e,0,0,0,1),this}makeScale(t,e){return this.set(t,0,0,0,e,0,0,0,1),this}equals(t){let e=this.elements,n=t.elements;for(let s=0;s<9;s++)if(e[s]!==n[s])return!1;return!0}fromArray(t,e=0){for(let n=0;n<9;n++)this.elements[n]=t[n+e];return this}toArray(t=[],e=0){let n=this.elements;return t[e]=n[0],t[e+1]=n[1],t[e+2]=n[2],t[e+3]=n[3],t[e+4]=n[4],t[e+5]=n[5],t[e+6]=n[6],t[e+7]=n[7],t[e+8]=n[8],t}clone(){return new this.constructor().fromArray(this.elements)}},c0=new ve,mu=new ve().set(.4123908,.3575843,.1804808,.212639,.7151687,.0721923,.0193308,.1191948,.9505322),gu=new ve().set(3.2409699,-1.5373832,-.4986108,-.9692436,1.8759675,.0415551,.0556301,-.203977,1.0569715);function xp(){let i={enabled:!0,workingColorSpace:aa,spaces:{},convert:function(s,r,a){return this.enabled===!1||r===a||!r||!a||(this.spaces[r].transfer===Oe&&(s.r=Hi(s.r),s.g=Hi(s.g),s.b=Hi(s.b)),this.spaces[r].primaries!==this.spaces[a].primaries&&(s.applyMatrix3(this.spaces[r].toXYZ),s.applyMatrix3(this.spaces[a].fromXYZ)),this.spaces[a].transfer===Oe&&(s.r=ar(s.r),s.g=ar(s.g),s.b=ar(s.b))),s},workingToColorSpace:function(s,r){return this.convert(s,this.workingColorSpace,r)},colorSpaceToWorking:function(s,r){return this.convert(s,r,this.workingColorSpace)},getPrimaries:function(s){return this.spaces[s].primaries},getTransfer:function(s){return s===mi?oa:this.spaces[s].transfer},getToneMappingMode:function(s){return this.spaces[s].outputColorSpaceConfig.toneMappingMode||"standard"},getLuminanceCoefficients:function(s,r=this.workingColorSpace){return s.fromArray(this.spaces[r].luminanceCoefficients)},define:function(s){Object.assign(this.spaces,s)},_getMatrix:function(s,r,a){return s.copy(this.spaces[r].toXYZ).multiply(this.spaces[a].fromXYZ)},_getDrawingBufferColorSpace:function(s){return this.spaces[s].outputColorSpaceConfig.drawingBufferColorSpace},_getUnpackColorSpace:function(s=this.workingColorSpace){return this.spaces[s].workingColorSpaceConfig.unpackColorSpace},fromWorkingColorSpace:function(s,r){return ws("ColorManagement: .fromWorkingColorSpace() has been renamed to .workingToColorSpace()."),i.workingToColorSpace(s,r)},toWorkingColorSpace:function(s,r){return ws("ColorManagement: .toWorkingColorSpace() has been renamed to .colorSpaceToWorking()."),i.colorSpaceToWorking(s,r)}},t=[.64,.33,.3,.6,.15,.06],e=[.2126,.7152,.0722],n=[.3127,.329];return i.define({[aa]:{primaries:t,whitePoint:n,transfer:oa,toXYZ:mu,fromXYZ:gu,luminanceCoefficients:e,workingColorSpaceConfig:{unpackColorSpace:tn},outputColorSpaceConfig:{drawingBufferColorSpace:tn}},[tn]:{primaries:t,whitePoint:n,transfer:Oe,toXYZ:mu,fromXYZ:gu,luminanceCoefficients:e,outputColorSpaceConfig:{drawingBufferColorSpace:tn}}}),i}var Re=xp();function Hi(i){return i<.04045?i*.0773993808:Math.pow(i*.9478672986+.0521327014,2.4)}function ar(i){return i<.0031308?i*12.92:1.055*Math.pow(i,.41666)-.055}var Hs,hl=class{static getDataURL(t,e="image/png"){if(/^data:/i.test(t.src)||typeof HTMLCanvasElement>"u")return t.src;let n;if(t instanceof HTMLCanvasElement)n=t;else{Hs===void 0&&(Hs=cr("canvas")),Hs.width=t.width,Hs.height=t.height;let s=Hs.getContext("2d");t instanceof ImageData?s.putImageData(t,0,0):s.drawImage(t,0,0,t.width,t.height),n=Hs}return n.toDataURL(e)}static sRGBToLinear(t){if(typeof HTMLImageElement<"u"&&t instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&t instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&t instanceof ImageBitmap){let e=cr("canvas");e.width=t.width,e.height=t.height;let n=e.getContext("2d");n.drawImage(t,0,0,t.width,t.height);let s=n.getImageData(0,0,t.width,t.height),r=s.data;for(let a=0;a<r.length;a++)r[a]=Hi(r[a]/255)*255;return n.putImageData(s,0,0),e}else if(t.data){let e=t.data.slice(0);for(let n=0;n<e.length;n++)e instanceof Uint8Array||e instanceof Uint8ClampedArray?e[n]=Math.floor(Hi(e[n]/255)*255):e[n]=Hi(e[n]);return{data:e,width:t.width,height:t.height}}else return pe("ImageUtils.sRGBToLinear(): Unsupported image type. No color space conversion applied."),t}},_p=0,ur=class{constructor(t=null){this.isTextureSource=!0,Object.defineProperty(this,"id",{value:_p++}),this.uuid=ki(),this.data=t,this.dataReady=!0,this.version=0}getSize(t){let e=this.data;return typeof HTMLVideoElement<"u"&&e instanceof HTMLVideoElement?t.set(e.videoWidth,e.videoHeight,0):typeof VideoFrame<"u"&&e instanceof VideoFrame?t.set(e.displayWidth,e.displayHeight,0):e!==null?t.set(e.width,e.height,e.depth||0):t.set(0,0,0),t}set needsUpdate(t){t===!0&&this.version++}toJSON(t){let e=t===void 0||typeof t=="string";if(!e&&t.images[this.uuid]!==void 0)return t.images[this.uuid];let n={uuid:this.uuid,url:""},s=this.data;if(s!==null){let r;if(Array.isArray(s)){r=[];for(let a=0,o=s.length;a<o;a++)s[a].isDataTexture?r.push(h0(s[a].image)):r.push(h0(s[a]))}else r=h0(s);n.url=r}return e||(t.images[this.uuid]=n),n}};function h0(i){return typeof HTMLImageElement<"u"&&i instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&i instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&i instanceof ImageBitmap?hl.getDataURL(i):i.data?{data:Array.from(i.data),width:i.width,height:i.height,type:i.data.constructor.name}:(pe("Texture: Unable to serialize Texture."),{})}var vp=0,u0=new D,Sn=class i extends Si{constructor(t=i.DEFAULT_IMAGE,e=i.DEFAULT_MAPPING,n=yi,s=yi,r=An,a=Ti,o=ei,c=kn,l=i.DEFAULT_ANISOTROPY,h=mi){super(),this.isTexture=!0,Object.defineProperty(this,"id",{value:vp++}),this.uuid=ki(),this.name="",this.source=new ur(t),this.mipmaps=[],this.mapping=e,this.channel=0,this.wrapS=n,this.wrapT=s,this.magFilter=r,this.minFilter=a,this.anisotropy=l,this.format=o,this.internalFormat=null,this.type=c,this.offset=new yt(0,0),this.repeat=new yt(1,1),this.center=new yt(0,0),this.rotation=0,this.matrixAutoUpdate=!0,this.matrix=new ve,this.generateMipmaps=!0,this.premultiplyAlpha=!1,this.flipY=!0,this.unpackAlignment=4,this.colorSpace=h,this.userData={},this.updateRanges=[],this.version=0,this.onUpdate=null,this.renderTarget=null,this.isRenderTargetTexture=!1,this.isArrayTexture=!!(t&&t.depth&&t.depth>1),this.pmremVersion=0,this.normalized=!1}get width(){return this.source.getSize(u0).x}get height(){return this.source.getSize(u0).y}get depth(){return this.source.getSize(u0).z}get image(){return this.source.data}set image(t){this.source.data=t}updateMatrix(){this.matrix.setUvTransform(this.offset.x,this.offset.y,this.repeat.x,this.repeat.y,this.rotation,this.center.x,this.center.y)}addUpdateRange(t,e){this.updateRanges.push({start:t,count:e})}clearUpdateRanges(){this.updateRanges.length=0}clone(){return new this.constructor().copy(this)}copy(t){return this.name=t.name,this.source=t.source,this.mipmaps=t.mipmaps.slice(0),this.mapping=t.mapping,this.channel=t.channel,this.wrapS=t.wrapS,this.wrapT=t.wrapT,this.magFilter=t.magFilter,this.minFilter=t.minFilter,this.anisotropy=t.anisotropy,this.format=t.format,this.internalFormat=t.internalFormat,this.type=t.type,this.normalized=t.normalized,this.offset.copy(t.offset),this.repeat.copy(t.repeat),this.center.copy(t.center),this.rotation=t.rotation,this.matrixAutoUpdate=t.matrixAutoUpdate,this.matrix.copy(t.matrix),this.generateMipmaps=t.generateMipmaps,this.premultiplyAlpha=t.premultiplyAlpha,this.flipY=t.flipY,this.unpackAlignment=t.unpackAlignment,this.colorSpace=t.colorSpace,this.renderTarget=t.renderTarget,this.isRenderTargetTexture=t.isRenderTargetTexture,this.isArrayTexture=t.isArrayTexture,this.userData=JSON.parse(JSON.stringify(t.userData)),this.needsUpdate=!0,this}setValues(t){for(let e in t){let n=t[e];if(n===void 0){pe(`Texture.setValues(): parameter '${e}' has value of undefined.`);continue}let s=this[e];if(s===void 0){pe(`Texture.setValues(): property '${e}' does not exist.`);continue}s&&n&&s.isVector2&&n.isVector2||s&&n&&s.isVector3&&n.isVector3||s&&n&&s.isMatrix3&&n.isMatrix3?s.copy(n):this[e]=n}}toJSON(t){let e=t===void 0||typeof t=="string";if(!e&&t.textures[this.uuid]!==void 0)return t.textures[this.uuid];let n={metadata:{version:4.7,type:"Texture",generator:"Texture.toJSON"},uuid:this.uuid,name:this.name,image:this.source.toJSON(t).uuid,mapping:this.mapping,channel:this.channel,repeat:[this.repeat.x,this.repeat.y],offset:[this.offset.x,this.offset.y],center:[this.center.x,this.center.y],rotation:this.rotation,wrap:[this.wrapS,this.wrapT],format:this.format,internalFormat:this.internalFormat,type:this.type,normalized:this.normalized,colorSpace:this.colorSpace,minFilter:this.minFilter,magFilter:this.magFilter,anisotropy:this.anisotropy,flipY:this.flipY,generateMipmaps:this.generateMipmaps,premultiplyAlpha:this.premultiplyAlpha,unpackAlignment:this.unpackAlignment};return Object.keys(this.userData).length>0&&(n.userData=this.userData),e||(t.textures[this.uuid]=n),n}dispose(){this.dispatchEvent({type:"dispose"})}transformUv(t){if(this.mapping!==Q0)return t;if(t.applyMatrix3(this.matrix),t.x<0||t.x>1)switch(this.wrapS){case rs:t.x=t.x-Math.floor(t.x);break;case yi:t.x=t.x<0?0:1;break;case ol:Math.abs(Math.floor(t.x)%2)===1?t.x=Math.ceil(t.x)-t.x:t.x=t.x-Math.floor(t.x);break}if(t.y<0||t.y>1)switch(this.wrapT){case rs:t.y=t.y-Math.floor(t.y);break;case yi:t.y=t.y<0?0:1;break;case ol:Math.abs(Math.floor(t.y)%2)===1?t.y=Math.ceil(t.y)-t.y:t.y=t.y-Math.floor(t.y);break}return this.flipY&&(t.y=1-t.y),t}set needsUpdate(t){t===!0&&(this.version++,this.source.needsUpdate=!0)}set needsPMREMUpdate(t){t===!0&&this.pmremVersion++}};Sn.DEFAULT_IMAGE=null;Sn.DEFAULT_MAPPING=Q0;Sn.DEFAULT_ANISOTROPY=1;var je=class i{static{i.prototype.isVector4=!0}constructor(t=0,e=0,n=0,s=1){this.x=t,this.y=e,this.z=n,this.w=s}get width(){return this.z}set width(t){this.z=t}get height(){return this.w}set height(t){this.w=t}set(t,e,n,s){return this.x=t,this.y=e,this.z=n,this.w=s,this}setScalar(t){return this.x=t,this.y=t,this.z=t,this.w=t,this}setX(t){return this.x=t,this}setY(t){return this.y=t,this}setZ(t){return this.z=t,this}setW(t){return this.w=t,this}setComponent(t,e){switch(t){case 0:this.x=e;break;case 1:this.y=e;break;case 2:this.z=e;break;case 3:this.w=e;break;default:throw new Error("THREE.Vector4: index is out of range: "+t)}return this}getComponent(t){switch(t){case 0:return this.x;case 1:return this.y;case 2:return this.z;case 3:return this.w;default:throw new Error("THREE.Vector4: index is out of range: "+t)}}clone(){return new this.constructor(this.x,this.y,this.z,this.w)}copy(t){return this.x=t.x,this.y=t.y,this.z=t.z,this.w=t.w!==void 0?t.w:1,this}add(t){return this.x+=t.x,this.y+=t.y,this.z+=t.z,this.w+=t.w,this}addScalar(t){return this.x+=t,this.y+=t,this.z+=t,this.w+=t,this}addVectors(t,e){return this.x=t.x+e.x,this.y=t.y+e.y,this.z=t.z+e.z,this.w=t.w+e.w,this}addScaledVector(t,e){return this.x+=t.x*e,this.y+=t.y*e,this.z+=t.z*e,this.w+=t.w*e,this}sub(t){return this.x-=t.x,this.y-=t.y,this.z-=t.z,this.w-=t.w,this}subScalar(t){return this.x-=t,this.y-=t,this.z-=t,this.w-=t,this}subVectors(t,e){return this.x=t.x-e.x,this.y=t.y-e.y,this.z=t.z-e.z,this.w=t.w-e.w,this}multiply(t){return this.x*=t.x,this.y*=t.y,this.z*=t.z,this.w*=t.w,this}multiplyScalar(t){return this.x*=t,this.y*=t,this.z*=t,this.w*=t,this}applyMatrix4(t){let e=this.x,n=this.y,s=this.z,r=this.w,a=t.elements;return this.x=a[0]*e+a[4]*n+a[8]*s+a[12]*r,this.y=a[1]*e+a[5]*n+a[9]*s+a[13]*r,this.z=a[2]*e+a[6]*n+a[10]*s+a[14]*r,this.w=a[3]*e+a[7]*n+a[11]*s+a[15]*r,this}divide(t){return this.x/=t.x,this.y/=t.y,this.z/=t.z,this.w/=t.w,this}divideScalar(t){return this.multiplyScalar(1/t)}setAxisAngleFromQuaternion(t){this.w=2*Math.acos(t.w);let e=Math.sqrt(1-t.w*t.w);return e<1e-4?(this.x=1,this.y=0,this.z=0):(this.x=t.x/e,this.y=t.y/e,this.z=t.z/e),this}setAxisAngleFromRotationMatrix(t){let e,n,s,r,c=t.elements,l=c[0],h=c[4],f=c[8],u=c[1],d=c[5],m=c[9],x=c[2],g=c[6],p=c[10];if(Math.abs(h-u)<.01&&Math.abs(f-x)<.01&&Math.abs(m-g)<.01){if(Math.abs(h+u)<.1&&Math.abs(f+x)<.1&&Math.abs(m+g)<.1&&Math.abs(l+d+p-3)<.1)return this.set(1,0,0,0),this;e=Math.PI;let E=(l+1)/2,y=(d+1)/2,w=(p+1)/2,S=(h+u)/4,C=(f+x)/4,v=(m+g)/4;return E>y&&E>w?E<.01?(n=0,s=.707106781,r=.707106781):(n=Math.sqrt(E),s=S/n,r=C/n):y>w?y<.01?(n=.707106781,s=0,r=.707106781):(s=Math.sqrt(y),n=S/s,r=v/s):w<.01?(n=.707106781,s=.707106781,r=0):(r=Math.sqrt(w),n=C/r,s=v/r),this.set(n,s,r,e),this}let b=Math.sqrt((g-m)*(g-m)+(f-x)*(f-x)+(u-h)*(u-h));return Math.abs(b)<.001&&(b=1),this.x=(g-m)/b,this.y=(f-x)/b,this.z=(u-h)/b,this.w=Math.acos((l+d+p-1)/2),this}setFromMatrixPosition(t){let e=t.elements;return this.x=e[12],this.y=e[13],this.z=e[14],this.w=e[15],this}min(t){return this.x=Math.min(this.x,t.x),this.y=Math.min(this.y,t.y),this.z=Math.min(this.z,t.z),this.w=Math.min(this.w,t.w),this}max(t){return this.x=Math.max(this.x,t.x),this.y=Math.max(this.y,t.y),this.z=Math.max(this.z,t.z),this.w=Math.max(this.w,t.w),this}clamp(t,e){return this.x=Ae(this.x,t.x,e.x),this.y=Ae(this.y,t.y,e.y),this.z=Ae(this.z,t.z,e.z),this.w=Ae(this.w,t.w,e.w),this}clampScalar(t,e){return this.x=Ae(this.x,t,e),this.y=Ae(this.y,t,e),this.z=Ae(this.z,t,e),this.w=Ae(this.w,t,e),this}clampLength(t,e){let n=this.length();return this.divideScalar(n||1).multiplyScalar(Ae(n,t,e))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this.w=Math.floor(this.w),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this.w=Math.ceil(this.w),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this.w=Math.round(this.w),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this.w=Math.trunc(this.w),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this.w=-this.w,this}dot(t){return this.x*t.x+this.y*t.y+this.z*t.z+this.w*t.w}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)+Math.abs(this.w)}normalize(){return this.divideScalar(this.length()||1)}setLength(t){return this.normalize().multiplyScalar(t)}lerp(t,e){return this.x+=(t.x-this.x)*e,this.y+=(t.y-this.y)*e,this.z+=(t.z-this.z)*e,this.w+=(t.w-this.w)*e,this}lerpVectors(t,e,n){return this.x=t.x+(e.x-t.x)*n,this.y=t.y+(e.y-t.y)*n,this.z=t.z+(e.z-t.z)*n,this.w=t.w+(e.w-t.w)*n,this}equals(t){return t.x===this.x&&t.y===this.y&&t.z===this.z&&t.w===this.w}fromArray(t,e=0){return this.x=t[e],this.y=t[e+1],this.z=t[e+2],this.w=t[e+3],this}toArray(t=[],e=0){return t[e]=this.x,t[e+1]=this.y,t[e+2]=this.z,t[e+3]=this.w,t}fromBufferAttribute(t,e){return this.x=t.getX(e),this.y=t.getY(e),this.z=t.getZ(e),this.w=t.getW(e),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this.w=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z,yield this.w}},ul=class extends Si{constructor(t=1,e=1,n={}){super(),n=Object.assign({generateMipmaps:!1,internalFormat:null,minFilter:An,depthBuffer:!0,stencilBuffer:!1,resolveColorBuffer:!0,resolveDepthBuffer:!0,resolveStencilBuffer:!0,storeMultisampledColorBuffer:!0,storeMultisampledDepthBuffer:!0,storeMultisampledStencilBuffer:!0,depthTexture:null,samples:0,count:1,depth:1,multiview:!1,useArrayDepthTexture:!1},n),this.isRenderTarget=!0,this.width=t,this.height=e,this.depth=n.depth,this.scissor=new je(0,0,t,e),this.scissorTest=!1,this.viewport=new je(0,0,t,e),this.textures=[];let s={width:t,height:e,depth:n.depth},r=new Sn(s),a=n.count;for(let o=0;o<a;o++)this.textures[o]=r.clone(),this.textures[o].isRenderTargetTexture=!0,this.textures[o].renderTarget=this;this._setTextureOptions(n),this.depthBuffer=n.depthBuffer,this.stencilBuffer=n.stencilBuffer,this.resolveColorBuffer=n.resolveColorBuffer,this.resolveDepthBuffer=n.resolveDepthBuffer,this.resolveStencilBuffer=n.resolveStencilBuffer,this.storeMultisampledColorBuffer=n.storeMultisampledColorBuffer,this.storeMultisampledDepthBuffer=n.storeMultisampledDepthBuffer,this.storeMultisampledStencilBuffer=n.storeMultisampledStencilBuffer,this._depthTexture=null,this.depthTexture=n.depthTexture,this.samples=n.samples,this.multiview=n.multiview,this.useArrayDepthTexture=n.useArrayDepthTexture}_setTextureOptions(t={}){let e={minFilter:An,generateMipmaps:!1,flipY:!1,internalFormat:null};t.mapping!==void 0&&(e.mapping=t.mapping),t.wrapS!==void 0&&(e.wrapS=t.wrapS),t.wrapT!==void 0&&(e.wrapT=t.wrapT),t.wrapR!==void 0&&(e.wrapR=t.wrapR),t.magFilter!==void 0&&(e.magFilter=t.magFilter),t.minFilter!==void 0&&(e.minFilter=t.minFilter),t.format!==void 0&&(e.format=t.format),t.type!==void 0&&(e.type=t.type),t.anisotropy!==void 0&&(e.anisotropy=t.anisotropy),t.colorSpace!==void 0&&(e.colorSpace=t.colorSpace),t.flipY!==void 0&&(e.flipY=t.flipY),t.generateMipmaps!==void 0&&(e.generateMipmaps=t.generateMipmaps),t.internalFormat!==void 0&&(e.internalFormat=t.internalFormat);for(let n=0;n<this.textures.length;n++)this.textures[n].setValues(e)}get texture(){return this.textures[0]}set texture(t){this.textures[0]=t}set depthTexture(t){this._depthTexture!==null&&this._depthTexture.renderTarget===this&&(this._depthTexture.renderTarget=null),t!==null&&t.renderTarget===null&&(t.renderTarget=this),this._depthTexture=t}get depthTexture(){return this._depthTexture}setSize(t,e,n=1){if(this.width!==t||this.height!==e||this.depth!==n){this.width=t,this.height=e,this.depth=n;for(let s=0,r=this.textures.length;s<r;s++)this.textures[s].image.width=t,this.textures[s].image.height=e,this.textures[s].image.depth=n,this.textures[s].isData3DTexture!==!0&&(this.textures[s].isArrayTexture=this.textures[s].image.depth>1);this.dispose()}this.viewport.set(0,0,t,e),this.scissor.set(0,0,t,e)}clone(){return new this.constructor().copy(this)}copy(t){this.width=t.width,this.height=t.height,this.depth=t.depth,this.scissor.copy(t.scissor),this.scissorTest=t.scissorTest,this.viewport.copy(t.viewport),this.textures.length=0;for(let e=0,n=t.textures.length;e<n;e++){this.textures[e]=t.textures[e].clone(),this.textures[e].isRenderTargetTexture=!0,this.textures[e].renderTarget=this;let s=Object.assign({},t.textures[e].image);this.textures[e].source=new ur(s)}if(this.depthBuffer=t.depthBuffer,this.stencilBuffer=t.stencilBuffer,this.resolveColorBuffer=t.resolveColorBuffer,this.resolveDepthBuffer=t.resolveDepthBuffer,this.resolveStencilBuffer=t.resolveStencilBuffer,this.storeMultisampledColorBuffer=t.storeMultisampledColorBuffer,this.storeMultisampledDepthBuffer=t.storeMultisampledDepthBuffer,this.storeMultisampledStencilBuffer=t.storeMultisampledStencilBuffer,t.depthTexture!==null)if(t.depthTexture.renderTarget===t){let e=t.depthTexture.clone();e.renderTarget=null,this.depthTexture=e}else this.depthTexture=t.depthTexture;return this.samples=t.samples,this.multiview=t.multiview,this.useArrayDepthTexture=t.useArrayDepthTexture,this}dispose(){this.dispatchEvent({type:"dispose"})}},sn=class extends ul{constructor(t=1,e=1,n={}){super(t,e,n),this.isWebGLRenderTarget=!0}},ca=class extends Sn{constructor(t=null,e=1,n=1,s=1){super(null),this.isDataArrayTexture=!0,this.image={data:t,width:e,height:n,depth:s},this.magFilter=bn,this.minFilter=bn,this.wrapR=yi,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1,this.layerUpdates=new Set}copy(t){return super.copy(t),this.wrapR=t.wrapR,this}addLayerUpdate(t){this.layerUpdates.add(t)}clearLayerUpdates(){this.layerUpdates.clear()}};var dl=class extends Sn{constructor(t=null,e=1,n=1,s=1){super(null),this.isData3DTexture=!0,this.image={data:t,width:e,height:n,depth:s},this.magFilter=bn,this.minFilter=bn,this.wrapR=yi,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}copy(t){return super.copy(t),this.wrapR=t.wrapR,this}};var De=class i{static{i.prototype.isMatrix4=!0}constructor(t,e,n,s,r,a,o,c,l,h,f,u,d,m,x,g){this.elements=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1],t!==void 0&&this.set(t,e,n,s,r,a,o,c,l,h,f,u,d,m,x,g)}set(t,e,n,s,r,a,o,c,l,h,f,u,d,m,x,g){let p=this.elements;return p[0]=t,p[4]=e,p[8]=n,p[12]=s,p[1]=r,p[5]=a,p[9]=o,p[13]=c,p[2]=l,p[6]=h,p[10]=f,p[14]=u,p[3]=d,p[7]=m,p[11]=x,p[15]=g,this}identity(){return this.set(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1),this}clone(){return new i().fromArray(this.elements)}copy(t){let e=this.elements,n=t.elements;return e[0]=n[0],e[1]=n[1],e[2]=n[2],e[3]=n[3],e[4]=n[4],e[5]=n[5],e[6]=n[6],e[7]=n[7],e[8]=n[8],e[9]=n[9],e[10]=n[10],e[11]=n[11],e[12]=n[12],e[13]=n[13],e[14]=n[14],e[15]=n[15],this}copyPosition(t){let e=this.elements,n=t.elements;return e[12]=n[12],e[13]=n[13],e[14]=n[14],this}setFromMatrix3(t){let e=t.elements;return this.set(e[0],e[3],e[6],0,e[1],e[4],e[7],0,e[2],e[5],e[8],0,0,0,0,1),this}extractBasis(t,e,n){return this.determinantAffine()===0?(t.set(1,0,0),e.set(0,1,0),n.set(0,0,1),this):(t.setFromMatrixColumn(this,0),e.setFromMatrixColumn(this,1),n.setFromMatrixColumn(this,2),this)}makeBasis(t,e,n){return this.set(t.x,e.x,n.x,0,t.y,e.y,n.y,0,t.z,e.z,n.z,0,0,0,0,1),this}extractRotation(t){if(t.determinantAffine()===0)return this.identity();let e=this.elements,n=t.elements,s=1/Vs.setFromMatrixColumn(t,0).length(),r=1/Vs.setFromMatrixColumn(t,1).length(),a=1/Vs.setFromMatrixColumn(t,2).length();return e[0]=n[0]*s,e[1]=n[1]*s,e[2]=n[2]*s,e[3]=0,e[4]=n[4]*r,e[5]=n[5]*r,e[6]=n[6]*r,e[7]=0,e[8]=n[8]*a,e[9]=n[9]*a,e[10]=n[10]*a,e[11]=0,e[12]=0,e[13]=0,e[14]=0,e[15]=1,this}makeRotationFromEuler(t){let e=this.elements,n=t.x,s=t.y,r=t.z,a=Math.cos(n),o=Math.sin(n),c=Math.cos(s),l=Math.sin(s),h=Math.cos(r),f=Math.sin(r);if(t.order==="XYZ"){let u=a*h,d=a*f,m=o*h,x=o*f;e[0]=c*h,e[4]=-c*f,e[8]=l,e[1]=d+m*l,e[5]=u-x*l,e[9]=-o*c,e[2]=x-u*l,e[6]=m+d*l,e[10]=a*c}else if(t.order==="YXZ"){let u=c*h,d=c*f,m=l*h,x=l*f;e[0]=u+x*o,e[4]=m*o-d,e[8]=a*l,e[1]=a*f,e[5]=a*h,e[9]=-o,e[2]=d*o-m,e[6]=x+u*o,e[10]=a*c}else if(t.order==="ZXY"){let u=c*h,d=c*f,m=l*h,x=l*f;e[0]=u-x*o,e[4]=-a*f,e[8]=m+d*o,e[1]=d+m*o,e[5]=a*h,e[9]=x-u*o,e[2]=-a*l,e[6]=o,e[10]=a*c}else if(t.order==="ZYX"){let u=a*h,d=a*f,m=o*h,x=o*f;e[0]=c*h,e[4]=m*l-d,e[8]=u*l+x,e[1]=c*f,e[5]=x*l+u,e[9]=d*l-m,e[2]=-l,e[6]=o*c,e[10]=a*c}else if(t.order==="YZX"){let u=a*c,d=a*l,m=o*c,x=o*l;e[0]=c*h,e[4]=x-u*f,e[8]=m*f+d,e[1]=f,e[5]=a*h,e[9]=-o*h,e[2]=-l*h,e[6]=d*f+m,e[10]=u-x*f}else if(t.order==="XZY"){let u=a*c,d=a*l,m=o*c,x=o*l;e[0]=c*h,e[4]=-f,e[8]=l*h,e[1]=u*f+x,e[5]=a*h,e[9]=d*f-m,e[2]=m*f-d,e[6]=o*h,e[10]=x*f+u}return e[3]=0,e[7]=0,e[11]=0,e[12]=0,e[13]=0,e[14]=0,e[15]=1,this}makeRotationFromQuaternion(t){return this.compose(yp,t,Mp)}lookAt(t,e,n){let s=this.elements;return Gn.subVectors(t,e),Gn.lengthSq()===0&&(Gn.z=1),Gn.normalize(),ts.crossVectors(n,Gn),ts.lengthSq()===0&&(Math.abs(n.z)===1?Gn.x+=1e-4:Gn.z+=1e-4,Gn.normalize(),ts.crossVectors(n,Gn)),ts.normalize(),Mo.crossVectors(Gn,ts),s[0]=ts.x,s[4]=Mo.x,s[8]=Gn.x,s[1]=ts.y,s[5]=Mo.y,s[9]=Gn.y,s[2]=ts.z,s[6]=Mo.z,s[10]=Gn.z,this}multiply(t){return this.multiplyMatrices(this,t)}premultiply(t){return this.multiplyMatrices(t,this)}multiplyMatrices(t,e){let n=t.elements,s=e.elements,r=this.elements,a=n[0],o=n[4],c=n[8],l=n[12],h=n[1],f=n[5],u=n[9],d=n[13],m=n[2],x=n[6],g=n[10],p=n[14],b=n[3],E=n[7],y=n[11],w=n[15],S=s[0],C=s[4],v=s[8],R=s[12],I=s[1],N=s[5],L=s[9],O=s[13],P=s[2],W=s[6],it=s[10],Q=s[14],ht=s[3],K=s[7],ot=s[11],z=s[15];return r[0]=a*S+o*I+c*P+l*ht,r[4]=a*C+o*N+c*W+l*K,r[8]=a*v+o*L+c*it+l*ot,r[12]=a*R+o*O+c*Q+l*z,r[1]=h*S+f*I+u*P+d*ht,r[5]=h*C+f*N+u*W+d*K,r[9]=h*v+f*L+u*it+d*ot,r[13]=h*R+f*O+u*Q+d*z,r[2]=m*S+x*I+g*P+p*ht,r[6]=m*C+x*N+g*W+p*K,r[10]=m*v+x*L+g*it+p*ot,r[14]=m*R+x*O+g*Q+p*z,r[3]=b*S+E*I+y*P+w*ht,r[7]=b*C+E*N+y*W+w*K,r[11]=b*v+E*L+y*it+w*ot,r[15]=b*R+E*O+y*Q+w*z,this}multiplyScalar(t){let e=this.elements;return e[0]*=t,e[4]*=t,e[8]*=t,e[12]*=t,e[1]*=t,e[5]*=t,e[9]*=t,e[13]*=t,e[2]*=t,e[6]*=t,e[10]*=t,e[14]*=t,e[3]*=t,e[7]*=t,e[11]*=t,e[15]*=t,this}determinant(){let t=this.elements,e=t[0],n=t[4],s=t[8],r=t[12],a=t[1],o=t[5],c=t[9],l=t[13],h=t[2],f=t[6],u=t[10],d=t[14],m=t[3],x=t[7],g=t[11],p=t[15],b=c*d-l*u,E=o*d-l*f,y=o*u-c*f,w=a*d-l*h,S=a*u-c*h,C=a*f-o*h;return e*(x*b-g*E+p*y)-n*(m*b-g*w+p*S)+s*(m*E-x*w+p*C)-r*(m*y-x*S+g*C)}determinantAffine(){let t=this.elements,e=t[0],n=t[4],s=t[8],r=t[1],a=t[5],o=t[9],c=t[2],l=t[6],h=t[10];return e*(a*h-o*l)-n*(r*h-o*c)+s*(r*l-a*c)}transpose(){let t=this.elements,e;return e=t[1],t[1]=t[4],t[4]=e,e=t[2],t[2]=t[8],t[8]=e,e=t[6],t[6]=t[9],t[9]=e,e=t[3],t[3]=t[12],t[12]=e,e=t[7],t[7]=t[13],t[13]=e,e=t[11],t[11]=t[14],t[14]=e,this}setPosition(t,e,n){let s=this.elements;return t.isVector3?(s[12]=t.x,s[13]=t.y,s[14]=t.z):(s[12]=t,s[13]=e,s[14]=n),this}invert(){let t=this.elements,e=t[0],n=t[1],s=t[2],r=t[3],a=t[4],o=t[5],c=t[6],l=t[7],h=t[8],f=t[9],u=t[10],d=t[11],m=t[12],x=t[13],g=t[14],p=t[15],b=e*o-n*a,E=e*c-s*a,y=e*l-r*a,w=n*c-s*o,S=n*l-r*o,C=s*l-r*c,v=h*x-f*m,R=h*g-u*m,I=h*p-d*m,N=f*g-u*x,L=f*p-d*x,O=u*p-d*g,P=b*O-E*L+y*N+w*I-S*R+C*v;if(P===0)return this.set(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);let W=1/P;return t[0]=(o*O-c*L+l*N)*W,t[1]=(s*L-n*O-r*N)*W,t[2]=(x*C-g*S+p*w)*W,t[3]=(u*S-f*C-d*w)*W,t[4]=(c*I-a*O-l*R)*W,t[5]=(e*O-s*I+r*R)*W,t[6]=(g*y-m*C-p*E)*W,t[7]=(h*C-u*y+d*E)*W,t[8]=(a*L-o*I+l*v)*W,t[9]=(n*I-e*L-r*v)*W,t[10]=(m*S-x*y+p*b)*W,t[11]=(f*y-h*S-d*b)*W,t[12]=(o*R-a*N-c*v)*W,t[13]=(e*N-n*R+s*v)*W,t[14]=(x*E-m*w-g*b)*W,t[15]=(h*w-f*E+u*b)*W,this}scale(t){let e=this.elements,n=t.x,s=t.y,r=t.z;return e[0]*=n,e[4]*=s,e[8]*=r,e[1]*=n,e[5]*=s,e[9]*=r,e[2]*=n,e[6]*=s,e[10]*=r,e[3]*=n,e[7]*=s,e[11]*=r,this}getMaxScaleOnAxis(){let t=this.elements,e=t[0]*t[0]+t[1]*t[1]+t[2]*t[2],n=t[4]*t[4]+t[5]*t[5]+t[6]*t[6],s=t[8]*t[8]+t[9]*t[9]+t[10]*t[10];return Math.sqrt(Math.max(e,n,s))}makeTranslation(t,e,n){return t.isVector3?this.set(1,0,0,t.x,0,1,0,t.y,0,0,1,t.z,0,0,0,1):this.set(1,0,0,t,0,1,0,e,0,0,1,n,0,0,0,1),this}makeRotationX(t){let e=Math.cos(t),n=Math.sin(t);return this.set(1,0,0,0,0,e,-n,0,0,n,e,0,0,0,0,1),this}makeRotationY(t){let e=Math.cos(t),n=Math.sin(t);return this.set(e,0,n,0,0,1,0,0,-n,0,e,0,0,0,0,1),this}makeRotationZ(t){let e=Math.cos(t),n=Math.sin(t);return this.set(e,-n,0,0,n,e,0,0,0,0,1,0,0,0,0,1),this}makeRotationAxis(t,e){let n=Math.cos(e),s=Math.sin(e),r=1-n,a=t.x,o=t.y,c=t.z,l=r*a,h=r*o;return this.set(l*a+n,l*o-s*c,l*c+s*o,0,l*o+s*c,h*o+n,h*c-s*a,0,l*c-s*o,h*c+s*a,r*c*c+n,0,0,0,0,1),this}makeScale(t,e,n){return this.set(t,0,0,0,0,e,0,0,0,0,n,0,0,0,0,1),this}makeShear(t,e,n,s,r,a){return this.set(1,n,r,0,t,1,a,0,e,s,1,0,0,0,0,1),this}compose(t,e,n){let s=this.elements,r=e._x,a=e._y,o=e._z,c=e._w,l=r+r,h=a+a,f=o+o,u=r*l,d=r*h,m=r*f,x=a*h,g=a*f,p=o*f,b=c*l,E=c*h,y=c*f,w=n.x,S=n.y,C=n.z;return s[0]=(1-(x+p))*w,s[1]=(d+y)*w,s[2]=(m-E)*w,s[3]=0,s[4]=(d-y)*S,s[5]=(1-(u+p))*S,s[6]=(g+b)*S,s[7]=0,s[8]=(m+E)*C,s[9]=(g-b)*C,s[10]=(1-(u+x))*C,s[11]=0,s[12]=t.x,s[13]=t.y,s[14]=t.z,s[15]=1,this}decompose(t,e,n){let s=this.elements;t.x=s[12],t.y=s[13],t.z=s[14];let r=this.determinantAffine();if(r===0)return n.set(1,1,1),e.identity(),this;let a=Vs.set(s[0],s[1],s[2]).length(),o=Vs.set(s[4],s[5],s[6]).length(),c=Vs.set(s[8],s[9],s[10]).length();r<0&&(a=-a),ai.copy(this);let l=1/a,h=1/o,f=1/c;return ai.elements[0]*=l,ai.elements[1]*=l,ai.elements[2]*=l,ai.elements[4]*=h,ai.elements[5]*=h,ai.elements[6]*=h,ai.elements[8]*=f,ai.elements[9]*=f,ai.elements[10]*=f,e.setFromRotationMatrix(ai),n.x=a,n.y=o,n.z=c,this}makePerspective(t,e,n,s,r,a,o=hi,c=!1){let l=this.elements,h=2*r/(e-t),f=2*r/(n-s),u=(e+t)/(e-t),d=(n+s)/(n-s),m,x;if(c)m=r/(a-r),x=a*r/(a-r);else if(o===hi)m=-(a+r)/(a-r),x=-2*a*r/(a-r);else if(o===lr)m=-a/(a-r),x=-a*r/(a-r);else throw new Error("THREE.Matrix4.makePerspective(): Invalid coordinate system: "+o);return l[0]=h,l[4]=0,l[8]=u,l[12]=0,l[1]=0,l[5]=f,l[9]=d,l[13]=0,l[2]=0,l[6]=0,l[10]=m,l[14]=x,l[3]=0,l[7]=0,l[11]=-1,l[15]=0,this}makeOrthographic(t,e,n,s,r,a,o=hi,c=!1){let l=this.elements,h=2/(e-t),f=2/(n-s),u=-(e+t)/(e-t),d=-(n+s)/(n-s),m,x;if(c)m=1/(a-r),x=a/(a-r);else if(o===hi)m=-2/(a-r),x=-(a+r)/(a-r);else if(o===lr)m=-1/(a-r),x=-r/(a-r);else throw new Error("THREE.Matrix4.makeOrthographic(): Invalid coordinate system: "+o);return l[0]=h,l[4]=0,l[8]=0,l[12]=u,l[1]=0,l[5]=f,l[9]=0,l[13]=d,l[2]=0,l[6]=0,l[10]=m,l[14]=x,l[3]=0,l[7]=0,l[11]=0,l[15]=1,this}equals(t){let e=this.elements,n=t.elements;for(let s=0;s<16;s++)if(e[s]!==n[s])return!1;return!0}fromArray(t,e=0){for(let n=0;n<16;n++)this.elements[n]=t[n+e];return this}toArray(t=[],e=0){let n=this.elements;return t[e]=n[0],t[e+1]=n[1],t[e+2]=n[2],t[e+3]=n[3],t[e+4]=n[4],t[e+5]=n[5],t[e+6]=n[6],t[e+7]=n[7],t[e+8]=n[8],t[e+9]=n[9],t[e+10]=n[10],t[e+11]=n[11],t[e+12]=n[12],t[e+13]=n[13],t[e+14]=n[14],t[e+15]=n[15],t}},Vs=new D,ai=new De,yp=new D(0,0,0),Mp=new D(1,1,1),ts=new D,Mo=new D,Gn=new D,xu=new De,_u=new wi,Vi=class i{constructor(t=0,e=0,n=0,s=i.DEFAULT_ORDER){this.isEuler=!0,this._x=t,this._y=e,this._z=n,this._order=s}get x(){return this._x}set x(t){this._x=t,this._onChangeCallback()}get y(){return this._y}set y(t){this._y=t,this._onChangeCallback()}get z(){return this._z}set z(t){this._z=t,this._onChangeCallback()}get order(){return this._order}set order(t){this._order=t,this._onChangeCallback()}set(t,e,n,s=this._order){return this._x=t,this._y=e,this._z=n,this._order=s,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._order)}copy(t){return this._x=t._x,this._y=t._y,this._z=t._z,this._order=t._order,this._onChangeCallback(),this}setFromRotationMatrix(t,e=this._order,n=!0){let s=t.elements,r=s[0],a=s[4],o=s[8],c=s[1],l=s[5],h=s[9],f=s[2],u=s[6],d=s[10];switch(e){case"XYZ":this._y=Math.asin(Ae(o,-1,1)),Math.abs(o)<.9999999?(this._x=Math.atan2(-h,d),this._z=Math.atan2(-a,r)):(this._x=Math.atan2(u,l),this._z=0);break;case"YXZ":this._x=Math.asin(-Ae(h,-1,1)),Math.abs(h)<.9999999?(this._y=Math.atan2(o,d),this._z=Math.atan2(c,l)):(this._y=Math.atan2(-f,r),this._z=0);break;case"ZXY":this._x=Math.asin(Ae(u,-1,1)),Math.abs(u)<.9999999?(this._y=Math.atan2(-f,d),this._z=Math.atan2(-a,l)):(this._y=0,this._z=Math.atan2(c,r));break;case"ZYX":this._y=Math.asin(-Ae(f,-1,1)),Math.abs(f)<.9999999?(this._x=Math.atan2(u,d),this._z=Math.atan2(c,r)):(this._x=0,this._z=Math.atan2(-a,l));break;case"YZX":this._z=Math.asin(Ae(c,-1,1)),Math.abs(c)<.9999999?(this._x=Math.atan2(-h,l),this._y=Math.atan2(-f,r)):(this._x=0,this._y=Math.atan2(o,d));break;case"XZY":this._z=Math.asin(-Ae(a,-1,1)),Math.abs(a)<.9999999?(this._x=Math.atan2(u,l),this._y=Math.atan2(o,r)):(this._x=Math.atan2(-h,d),this._y=0);break;default:pe("Euler: .setFromRotationMatrix() encountered an unknown order: "+e)}return this._order=e,n===!0&&this._onChangeCallback(),this}setFromQuaternion(t,e,n){return xu.makeRotationFromQuaternion(t),this.setFromRotationMatrix(xu,e,n)}setFromVector3(t,e=this._order){return this.set(t.x,t.y,t.z,e)}reorder(t){return _u.setFromEuler(this),this.setFromQuaternion(_u,t)}equals(t){return t._x===this._x&&t._y===this._y&&t._z===this._z&&t._order===this._order}fromArray(t){return this._x=t[0],this._y=t[1],this._z=t[2],t[3]!==void 0&&(this._order=t[3]),this._onChangeCallback(),this}toArray(t=[],e=0){return t[e]=this._x,t[e+1]=this._y,t[e+2]=this._z,t[e+3]=this._order,t}_onChange(t){return this._onChangeCallback=t,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._order}};Vi.DEFAULT_ORDER="XYZ";var dr=class{constructor(){this.mask=1}set(t){this.mask=(1<<t|0)>>>0}enable(t){this.mask|=1<<t|0}enableAll(){this.mask=-1}toggle(t){this.mask^=1<<t|0}disable(t){this.mask&=~(1<<t|0)}disableAll(){this.mask=0}test(t){return(this.mask&t.mask)!==0}isEnabled(t){return(this.mask&(1<<t|0))!==0}},bp=0,vu=new D,Gs=new wi,Di=new De,bo=new D,$r=new D,Sp=new D,wp=new wi,yu=new D(1,0,0),Mu=new D(0,1,0),bu=new D(0,0,1),Su={type:"added"},Ep={type:"removed"},Ws={type:"childadded",child:null},d0={type:"childremoved",child:null},cn=class i extends Si{constructor(){super(),this.isObject3D=!0,Object.defineProperty(this,"id",{value:bp++}),this.uuid=ki(),this.name="",this.type="Object3D",this.parent=null,this.children=[],this.up=i.DEFAULT_UP.clone();let t=new D,e=new Vi,n=new wi,s=new D(1,1,1);function r(){n.setFromEuler(e,!1)}function a(){e.setFromQuaternion(n,void 0,!1)}e._onChange(r),n._onChange(a),Object.defineProperties(this,{position:{configurable:!0,enumerable:!0,value:t},rotation:{configurable:!0,enumerable:!0,value:e},quaternion:{configurable:!0,enumerable:!0,value:n},scale:{configurable:!0,enumerable:!0,value:s},modelViewMatrix:{value:new De},normalMatrix:{value:new ve}}),this.matrix=new De,this.matrixWorld=new De,this.matrixAutoUpdate=i.DEFAULT_MATRIX_AUTO_UPDATE,this.matrixWorldAutoUpdate=i.DEFAULT_MATRIX_WORLD_AUTO_UPDATE,this.matrixWorldNeedsUpdate=!1,this.layers=new dr,this.visible=!0,this.castShadow=!1,this.receiveShadow=!1,this.frustumCulled=!0,this.renderOrder=0,this.animations=[],this.customDepthMaterial=void 0,this.customDistanceMaterial=void 0,this.static=!1,this.userData={},this.pivot=null}onBeforeShadow(){}onAfterShadow(){}onBeforeRender(){}onAfterRender(){}applyMatrix4(t){this.matrixAutoUpdate&&this.updateMatrix(),this.matrix.premultiply(t),this.matrix.decompose(this.position,this.quaternion,this.scale)}applyQuaternion(t){return this.quaternion.premultiply(t),this}setRotationFromAxisAngle(t,e){this.quaternion.setFromAxisAngle(t,e)}setRotationFromEuler(t){this.quaternion.setFromEuler(t,!0)}setRotationFromMatrix(t){this.quaternion.setFromRotationMatrix(t)}setRotationFromQuaternion(t){this.quaternion.copy(t)}rotateOnAxis(t,e){return Gs.setFromAxisAngle(t,e),this.quaternion.multiply(Gs),this}rotateOnWorldAxis(t,e){return Gs.setFromAxisAngle(t,e),this.quaternion.premultiply(Gs),this}rotateX(t){return this.rotateOnAxis(yu,t)}rotateY(t){return this.rotateOnAxis(Mu,t)}rotateZ(t){return this.rotateOnAxis(bu,t)}translateOnAxis(t,e){return vu.copy(t).applyQuaternion(this.quaternion),this.position.add(vu.multiplyScalar(e)),this}translateX(t){return this.translateOnAxis(yu,t)}translateY(t){return this.translateOnAxis(Mu,t)}translateZ(t){return this.translateOnAxis(bu,t)}localToWorld(t){return this.updateWorldMatrix(!0,!1),t.applyMatrix4(this.matrixWorld)}worldToLocal(t){return this.updateWorldMatrix(!0,!1),t.applyMatrix4(Di.copy(this.matrixWorld).invert())}lookAt(t,e,n){t.isVector3?bo.copy(t):bo.set(t,e,n);let s=this.parent;this.updateWorldMatrix(!0,!1),$r.setFromMatrixPosition(this.matrixWorld),this.isCamera||this.isLight?Di.lookAt($r,bo,this.up):Di.lookAt(bo,$r,this.up),this.quaternion.setFromRotationMatrix(Di),s&&(Di.extractRotation(s.matrixWorld),Gs.setFromRotationMatrix(Di),this.quaternion.premultiply(Gs.invert()))}add(t){if(arguments.length>1){for(let e=0;e<arguments.length;e++)this.add(arguments[e]);return this}return t===this?(fe("Object3D.add: object can't be added as a child of itself.",t),this):(t&&t.isObject3D?(t.removeFromParent(),t.parent=this,this.children.push(t),t.dispatchEvent(Su),Ws.child=t,this.dispatchEvent(Ws),Ws.child=null):fe("Object3D.add: object not an instance of THREE.Object3D.",t),this)}remove(t){if(arguments.length>1){for(let n=0;n<arguments.length;n++)this.remove(arguments[n]);return this}let e=this.children.indexOf(t);return e!==-1&&(t.parent=null,this.children.splice(e,1),t.dispatchEvent(Ep),d0.child=t,this.dispatchEvent(d0),d0.child=null),this}removeFromParent(){let t=this.parent;return t!==null&&t.remove(this),this}clear(){return this.remove(...this.children)}attach(t){return this.updateWorldMatrix(!0,!1),Di.copy(this.matrixWorld).invert(),t.parent!==null&&(t.parent.updateWorldMatrix(!0,!1),Di.multiply(t.parent.matrixWorld)),t.applyMatrix4(Di),t.removeFromParent(),t.parent=this,this.children.push(t),t.updateWorldMatrix(!1,!0),t.dispatchEvent(Su),Ws.child=t,this.dispatchEvent(Ws),Ws.child=null,this}getObjectById(t){return this.getObjectByProperty("id",t)}getObjectByName(t){return this.getObjectByProperty("name",t)}getObjectByProperty(t,e){if(this[t]===e)return this;for(let n=0,s=this.children.length;n<s;n++){let a=this.children[n].getObjectByProperty(t,e);if(a!==void 0)return a}}getObjectsByProperty(t,e,n=[]){this[t]===e&&n.push(this);let s=this.children;for(let r=0,a=s.length;r<a;r++)s[r].getObjectsByProperty(t,e,n);return n}getWorldPosition(t){return this.updateWorldMatrix(!0,!1),t.setFromMatrixPosition(this.matrixWorld)}getWorldQuaternion(t){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose($r,t,Sp),t}getWorldScale(t){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose($r,wp,t),t}getWorldDirection(t){this.updateWorldMatrix(!0,!1);let e=this.matrixWorld.elements;return t.set(e[8],e[9],e[10]).normalize()}raycast(){}intersectsFrustum(){}traverse(t){t(this);let e=this.children;for(let n=0,s=e.length;n<s;n++)e[n].traverse(t)}traverseVisible(t){if(this.visible===!1)return;t(this);let e=this.children;for(let n=0,s=e.length;n<s;n++)e[n].traverseVisible(t)}traverseAncestors(t){let e=this.parent;e!==null&&(t(e),e.traverseAncestors(t))}updateMatrix(){this.matrix.compose(this.position,this.quaternion,this.scale);let t=this.pivot;if(t!==null){let e=t.x,n=t.y,s=t.z,r=this.matrix.elements;r[12]+=e-r[0]*e-r[4]*n-r[8]*s,r[13]+=n-r[1]*e-r[5]*n-r[9]*s,r[14]+=s-r[2]*e-r[6]*n-r[10]*s}this.matrixWorldNeedsUpdate=!0}updateMatrixWorld(t){this.matrixAutoUpdate&&this.updateMatrix(),(this.matrixWorldNeedsUpdate||t)&&(this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),this.matrixWorldNeedsUpdate=!1,t=!0);let e=this.children;for(let n=0,s=e.length;n<s;n++)e[n].updateMatrixWorld(t)}updateWorldMatrix(t,e,n=!1){let s=this.parent;if(t===!0&&s!==null&&s.updateWorldMatrix(!0,!1),this.matrixAutoUpdate&&this.updateMatrix(),(this.matrixWorldNeedsUpdate||n)&&(this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),this.matrixWorldNeedsUpdate=!1,n=!0),e===!0){let r=this.children;for(let a=0,o=r.length;a<o;a++)r[a].updateWorldMatrix(!1,!0,n)}}toJSON(t){let e=t===void 0||typeof t=="string",n={};e&&(t={geometries:{},materials:{},textures:{},images:{},shapes:{},skeletons:{},animations:{},nodes:{}},n.metadata={version:4.7,type:"Object",generator:"Object3D.toJSON"});let s={};s.uuid=this.uuid,s.type=this.type,s.name=this.name,s.castShadow=this.castShadow,s.receiveShadow=this.receiveShadow,s.visible=this.visible,s.frustumCulled=this.frustumCulled,s.renderOrder=this.renderOrder,s.static=this.static,s.matrixAutoUpdate=this.matrixAutoUpdate,Object.keys(this.userData).length>0&&(s.userData=this.userData),s.layers=this.layers.mask,s.matrix=this.matrix.toArray(),s.up=this.up.toArray(),this.pivot!==null&&(s.pivot=this.pivot.toArray()),this.morphTargetDictionary!==void 0&&(s.morphTargetDictionary=Object.assign({},this.morphTargetDictionary)),this.morphTargetInfluences!==void 0&&(s.morphTargetInfluences=this.morphTargetInfluences.slice()),this.isInstancedMesh&&(s.type="InstancedMesh",s.count=this.count,s.instanceMatrix=this.instanceMatrix.toJSON(),this.instanceColor!==null&&(s.instanceColor=this.instanceColor.toJSON())),this.isBatchedMesh&&(s.type="BatchedMesh",s.perObjectFrustumCulled=this.perObjectFrustumCulled,s.sortObjects=this.sortObjects,s.drawRanges=this._drawRanges,s.reservedRanges=this._reservedRanges,s.geometryInfo=this._geometryInfo.map(o=>({...o,boundingBox:o.boundingBox?o.boundingBox.toJSON():void 0,boundingSphere:o.boundingSphere?o.boundingSphere.toJSON():void 0})),s.instanceInfo=this._instanceInfo.map(o=>({...o})),s.availableInstanceIds=this._availableInstanceIds.slice(),s.availableGeometryIds=this._availableGeometryIds.slice(),s.nextIndexStart=this._nextIndexStart,s.nextVertexStart=this._nextVertexStart,s.geometryCount=this._geometryCount,s.maxInstanceCount=this._maxInstanceCount,s.maxVertexCount=this._maxVertexCount,s.maxIndexCount=this._maxIndexCount,s.geometryInitialized=this._geometryInitialized,s.matricesTexture=this._matricesTexture.toJSON(t),s.indirectTexture=this._indirectTexture.toJSON(t),this._colorsTexture!==null&&(s.colorsTexture=this._colorsTexture.toJSON(t)),this.boundingSphere!==null&&(s.boundingSphere=this.boundingSphere.toJSON()),this.boundingBox!==null&&(s.boundingBox=this.boundingBox.toJSON()));function r(o,c){return o[c.uuid]===void 0&&(o[c.uuid]=c.toJSON(t)),c.uuid}if(this.isScene)this.background&&(this.background.isColor?s.background=this.background.toJSON():this.background.isTexture&&(s.background=this.background.toJSON(t).uuid)),this.environment&&this.environment.isTexture&&this.environment.isRenderTargetTexture!==!0&&(s.environment=this.environment.toJSON(t).uuid);else if(this.isMesh||this.isLine||this.isPoints){s.geometry=r(t.geometries,this.geometry);let o=this.geometry.parameters;if(o!==void 0&&o.shapes!==void 0){let c=o.shapes;if(Array.isArray(c))for(let l=0,h=c.length;l<h;l++){let f=c[l];r(t.shapes,f)}else r(t.shapes,c)}}if(this.isSkinnedMesh&&(s.bindMode=this.bindMode,s.bindMatrix=this.bindMatrix.toArray(),this.skeleton!==void 0&&(r(t.skeletons,this.skeleton),s.skeleton=this.skeleton.uuid)),this.material!==void 0)if(Array.isArray(this.material)){let o=[];for(let c=0,l=this.material.length;c<l;c++)o.push(r(t.materials,this.material[c]));s.material=o}else s.material=r(t.materials,this.material);if(this.children.length>0){s.children=[];for(let o=0;o<this.children.length;o++)s.children.push(this.children[o].toJSON(t).object)}if(this.animations.length>0){s.animations=[];for(let o=0;o<this.animations.length;o++){let c=this.animations[o];s.animations.push(r(t.animations,c))}}if(e){let o=a(t.geometries),c=a(t.materials),l=a(t.textures),h=a(t.images),f=a(t.shapes),u=a(t.skeletons),d=a(t.animations),m=a(t.nodes);o.length>0&&(n.geometries=o),c.length>0&&(n.materials=c),l.length>0&&(n.textures=l),h.length>0&&(n.images=h),f.length>0&&(n.shapes=f),u.length>0&&(n.skeletons=u),d.length>0&&(n.animations=d),m.length>0&&(n.nodes=m)}return n.object=s,n;function a(o){let c=[];for(let l in o){let h=o[l];delete h.metadata,c.push(h)}return c}}clone(t){return new this.constructor().copy(this,t)}copy(t,e=!0){if(this.name=t.name,this.up.copy(t.up),this.position.copy(t.position),this.rotation.order=t.rotation.order,this.quaternion.copy(t.quaternion),this.scale.copy(t.scale),this.pivot=t.pivot!==null?t.pivot.clone():null,this.matrix.copy(t.matrix),this.matrixWorld.copy(t.matrixWorld),this.matrixAutoUpdate=t.matrixAutoUpdate,this.matrixWorldAutoUpdate=t.matrixWorldAutoUpdate,this.matrixWorldNeedsUpdate=t.matrixWorldNeedsUpdate,this.layers.mask=t.layers.mask,this.visible=t.visible,this.castShadow=t.castShadow,this.receiveShadow=t.receiveShadow,this.frustumCulled=t.frustumCulled,this.renderOrder=t.renderOrder,this.static=t.static,this.animations=t.animations.slice(),this.userData=JSON.parse(JSON.stringify(t.userData)),e===!0)for(let n=0;n<t.children.length;n++){let s=t.children[n];this.add(s.clone())}return this}dispose(){this.dispatchEvent({type:"dispose"})}};cn.DEFAULT_UP=new D(0,1,0);cn.DEFAULT_MATRIX_AUTO_UPDATE=!0;cn.DEFAULT_MATRIX_WORLD_AUTO_UPDATE=!0;var nn=class extends cn{constructor(){super(),this.isGroup=!0,this.type="Group"}},Tp={type:"move"},fr=class{constructor(){this._targetRay=null,this._grip=null,this._hand=null}getHandSpace(){return this._hand===null&&(this._hand=new nn,this._hand.matrixAutoUpdate=!1,this._hand.visible=!1,this._hand.joints={},this._hand.inputState={pinching:!1}),this._hand}getTargetRaySpace(){return this._targetRay===null&&(this._targetRay=new nn,this._targetRay.matrixAutoUpdate=!1,this._targetRay.visible=!1,this._targetRay.hasLinearVelocity=!1,this._targetRay.linearVelocity=new D,this._targetRay.hasAngularVelocity=!1,this._targetRay.angularVelocity=new D),this._targetRay}getGripSpace(){return this._grip===null&&(this._grip=new nn,this._grip.matrixAutoUpdate=!1,this._grip.visible=!1,this._grip.hasLinearVelocity=!1,this._grip.linearVelocity=new D,this._grip.hasAngularVelocity=!1,this._grip.angularVelocity=new D,this._grip.eventsEnabled=!1),this._grip}dispatchEvent(t){return this._targetRay!==null&&this._targetRay.dispatchEvent(t),this._grip!==null&&this._grip.dispatchEvent(t),this._hand!==null&&this._hand.dispatchEvent(t),this}connect(t){if(t&&t.hand){let e=this._hand;if(e)for(let n of t.hand.values())this._getHandJoint(e,n)}return this.dispatchEvent({type:"connected",data:t}),this}disconnect(t){return this.dispatchEvent({type:"disconnected",data:t}),this._targetRay!==null&&(this._targetRay.visible=!1),this._grip!==null&&(this._grip.visible=!1),this._hand!==null&&(this._hand.visible=!1),this}update(t,e,n){let s=null,r=null,a=null,o=this._targetRay,c=this._grip,l=this._hand;if(t&&e.session.visibilityState!=="visible-blurred"){if(l&&t.hand){a=!0;for(let x of t.hand.values()){let g=e.getJointPose(x,n),p=this._getHandJoint(l,x);g!==null&&(p.matrix.fromArray(g.transform.matrix),p.matrix.decompose(p.position,p.rotation,p.scale),p.matrixWorldNeedsUpdate=!0,p.jointRadius=g.radius),p.visible=g!==null}let h=l.joints["index-finger-tip"],f=l.joints["thumb-tip"],u=h.position.distanceTo(f.position),d=.02,m=.005;l.inputState.pinching&&u>d+m?(l.inputState.pinching=!1,this.dispatchEvent({type:"pinchend",handedness:t.handedness,target:this})):!l.inputState.pinching&&u<=d-m&&(l.inputState.pinching=!0,this.dispatchEvent({type:"pinchstart",handedness:t.handedness,target:this}))}else c!==null&&t.gripSpace&&(r=e.getPose(t.gripSpace,n),r!==null&&(c.matrix.fromArray(r.transform.matrix),c.matrix.decompose(c.position,c.rotation,c.scale),c.matrixWorldNeedsUpdate=!0,r.linearVelocity?(c.hasLinearVelocity=!0,c.linearVelocity.copy(r.linearVelocity)):c.hasLinearVelocity=!1,r.angularVelocity?(c.hasAngularVelocity=!0,c.angularVelocity.copy(r.angularVelocity)):c.hasAngularVelocity=!1,c.eventsEnabled&&c.dispatchEvent({type:"gripUpdated",data:t,target:this})));o!==null&&(s=e.getPose(t.targetRaySpace,n),s===null&&r!==null&&(s=r),s!==null&&(o.matrix.fromArray(s.transform.matrix),o.matrix.decompose(o.position,o.rotation,o.scale),o.matrixWorldNeedsUpdate=!0,s.linearVelocity?(o.hasLinearVelocity=!0,o.linearVelocity.copy(s.linearVelocity)):o.hasLinearVelocity=!1,s.angularVelocity?(o.hasAngularVelocity=!0,o.angularVelocity.copy(s.angularVelocity)):o.hasAngularVelocity=!1,this.dispatchEvent(Tp)))}return o!==null&&(o.visible=s!==null),c!==null&&(c.visible=r!==null),l!==null&&(l.visible=a!==null),this}_getHandJoint(t,e){if(t.joints[e.jointName]===void 0){let n=new nn;n.matrixAutoUpdate=!1,n.visible=!1,t.joints[e.jointName]=n,t.add(n)}return t.joints[e.jointName]}},Ud={aliceblue:15792383,antiquewhite:16444375,aqua:65535,aquamarine:8388564,azure:15794175,beige:16119260,bisque:16770244,black:0,blanchedalmond:16772045,blue:255,blueviolet:9055202,brown:10824234,burlywood:14596231,cadetblue:6266528,chartreuse:8388352,chocolate:13789470,coral:16744272,cornflowerblue:6591981,cornsilk:16775388,crimson:14423100,cyan:65535,darkblue:139,darkcyan:35723,darkgoldenrod:12092939,darkgray:11119017,darkgreen:25600,darkgrey:11119017,darkkhaki:12433259,darkmagenta:9109643,darkolivegreen:5597999,darkorange:16747520,darkorchid:10040012,darkred:9109504,darksalmon:15308410,darkseagreen:9419919,darkslateblue:4734347,darkslategray:3100495,darkslategrey:3100495,darkturquoise:52945,darkviolet:9699539,deeppink:16716947,deepskyblue:49151,dimgray:6908265,dimgrey:6908265,dodgerblue:2003199,firebrick:11674146,floralwhite:16775920,forestgreen:2263842,fuchsia:16711935,gainsboro:14474460,ghostwhite:16316671,gold:16766720,goldenrod:14329120,gray:8421504,green:32768,greenyellow:11403055,grey:8421504,honeydew:15794160,hotpink:16738740,indianred:13458524,indigo:4915330,ivory:16777200,khaki:15787660,lavender:15132410,lavenderblush:16773365,lawngreen:8190976,lemonchiffon:16775885,lightblue:11393254,lightcoral:15761536,lightcyan:14745599,lightgoldenrodyellow:16448210,lightgray:13882323,lightgreen:9498256,lightgrey:13882323,lightpink:16758465,lightsalmon:16752762,lightseagreen:2142890,lightskyblue:8900346,lightslategray:7833753,lightslategrey:7833753,lightsteelblue:11584734,lightyellow:16777184,lime:65280,limegreen:3329330,linen:16445670,magenta:16711935,maroon:8388608,mediumaquamarine:6737322,mediumblue:205,mediumorchid:12211667,mediumpurple:9662683,mediumseagreen:3978097,mediumslateblue:8087790,mediumspringgreen:64154,mediumturquoise:4772300,mediumvioletred:13047173,midnightblue:1644912,mintcream:16121850,mistyrose:16770273,moccasin:16770229,navajowhite:16768685,navy:128,oldlace:16643558,olive:8421376,olivedrab:7048739,orange:16753920,orangered:16729344,orchid:14315734,palegoldenrod:15657130,palegreen:10025880,paleturquoise:11529966,palevioletred:14381203,papayawhip:16773077,peachpuff:16767673,peru:13468991,pink:16761035,plum:14524637,powderblue:11591910,purple:8388736,rebeccapurple:6697881,red:16711680,rosybrown:12357519,royalblue:4286945,saddlebrown:9127187,salmon:16416882,sandybrown:16032864,seagreen:3050327,seashell:16774638,sienna:10506797,silver:12632256,skyblue:8900331,slateblue:6970061,slategray:7372944,slategrey:7372944,snow:16775930,springgreen:65407,steelblue:4620980,tan:13808780,teal:32896,thistle:14204888,tomato:16737095,turquoise:4251856,violet:15631086,wheat:16113331,white:16777215,whitesmoke:16119285,yellow:16776960,yellowgreen:10145074},es={h:0,s:0,l:0},So={h:0,s:0,l:0};function f0(i,t,e){return e<0&&(e+=1),e>1&&(e-=1),e<1/6?i+(t-i)*6*e:e<1/2?t:e<2/3?i+(t-i)*6*(2/3-e):i}var oe=class{constructor(t,e,n){return this.isColor=!0,this.r=1,this.g=1,this.b=1,this.set(t,e,n)}set(t,e,n){if(e===void 0&&n===void 0){let s=t;s&&s.isColor?this.copy(s):typeof s=="number"?this.setHex(s):typeof s=="string"&&this.setStyle(s)}else this.setRGB(t,e,n);return this}setScalar(t){return this.r=t,this.g=t,this.b=t,this}setHex(t,e=tn){return t=Math.floor(t),this.r=(t>>16&255)/255,this.g=(t>>8&255)/255,this.b=(t&255)/255,Re.colorSpaceToWorking(this,e),this}setRGB(t,e,n,s=Re.workingColorSpace){return this.r=t,this.g=e,this.b=n,Re.colorSpaceToWorking(this,s),this}setHSL(t,e,n,s=Re.workingColorSpace){if(t=gp(t,1),e=Ae(e,0,1),n=Ae(n,0,1),e===0)this.r=this.g=this.b=n;else{let r=n<=.5?n*(1+e):n+e-n*e,a=2*n-r;this.r=f0(a,r,t+1/3),this.g=f0(a,r,t),this.b=f0(a,r,t-1/3)}return Re.colorSpaceToWorking(this,s),this}setStyle(t,e=tn){function n(r){r!==void 0&&parseFloat(r)<1&&pe("Color: Alpha component of "+t+" will be ignored.")}let s;if(s=/^(\w+)\(([^\)]*)\)/.exec(t)){let r,a=s[1],o=s[2];switch(a){case"rgb":case"rgba":if(r=/^\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return n(r[4]),this.setRGB(Math.min(255,parseInt(r[1],10))/255,Math.min(255,parseInt(r[2],10))/255,Math.min(255,parseInt(r[3],10))/255,e);if(r=/^\s*(\d+)\%\s*,\s*(\d+)\%\s*,\s*(\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return n(r[4]),this.setRGB(Math.min(100,parseInt(r[1],10))/100,Math.min(100,parseInt(r[2],10))/100,Math.min(100,parseInt(r[3],10))/100,e);break;case"hsl":case"hsla":if(r=/^\s*(\d*\.?\d+)\s*,\s*(\d*\.?\d+)\%\s*,\s*(\d*\.?\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return n(r[4]),this.setHSL(parseFloat(r[1])/360,parseFloat(r[2])/100,parseFloat(r[3])/100,e);break;default:pe("Color: Unknown color model "+t)}}else if(s=/^\#([A-Fa-f\d]+)$/.exec(t)){let r=s[1],a=r.length;if(a===3)return this.setRGB(parseInt(r.charAt(0),16)/15,parseInt(r.charAt(1),16)/15,parseInt(r.charAt(2),16)/15,e);if(a===6)return this.setHex(parseInt(r,16),e);pe("Color: Invalid hex color "+t)}else if(t&&t.length>0)return this.setColorName(t,e);return this}setColorName(t,e=tn){let n=Ud[t.toLowerCase()];return n!==void 0?this.setHex(n,e):pe("Color: Unknown color "+t),this}clone(){return new this.constructor(this.r,this.g,this.b)}copy(t){return this.r=t.r,this.g=t.g,this.b=t.b,this}copySRGBToLinear(t){return this.r=Hi(t.r),this.g=Hi(t.g),this.b=Hi(t.b),this}copyLinearToSRGB(t){return this.r=ar(t.r),this.g=ar(t.g),this.b=ar(t.b),this}convertSRGBToLinear(){return this.copySRGBToLinear(this),this}convertLinearToSRGB(){return this.copyLinearToSRGB(this),this}getHex(t=tn){return Re.workingToColorSpace(Dn.copy(this),t),Math.round(Ae(Dn.r*255,0,255))*65536+Math.round(Ae(Dn.g*255,0,255))*256+Math.round(Ae(Dn.b*255,0,255))}getHexString(t=tn){return("000000"+this.getHex(t).toString(16)).slice(-6)}getHSL(t,e=Re.workingColorSpace){Re.workingToColorSpace(Dn.copy(this),e);let n=Dn.r,s=Dn.g,r=Dn.b,a=Math.max(n,s,r),o=Math.min(n,s,r),c,l,h=(o+a)/2;if(o===a)c=0,l=0;else{let f=a-o;switch(l=h<=.5?f/(a+o):f/(2-a-o),a){case n:c=(s-r)/f+(s<r?6:0);break;case s:c=(r-n)/f+2;break;case r:c=(n-s)/f+4;break}c/=6}return t.h=c,t.s=l,t.l=h,t}getRGB(t,e=Re.workingColorSpace){return Re.workingToColorSpace(Dn.copy(this),e),t.r=Dn.r,t.g=Dn.g,t.b=Dn.b,t}getStyle(t=tn){Re.workingToColorSpace(Dn.copy(this),t);let e=Dn.r,n=Dn.g,s=Dn.b;return t!==tn?`color(${t} ${e.toFixed(3)} ${n.toFixed(3)} ${s.toFixed(3)})`:`rgb(${Math.round(e*255)},${Math.round(n*255)},${Math.round(s*255)})`}offsetHSL(t,e,n){return this.getHSL(es),this.setHSL(es.h+t,es.s+e,es.l+n)}add(t){return this.r+=t.r,this.g+=t.g,this.b+=t.b,this}addColors(t,e){return this.r=t.r+e.r,this.g=t.g+e.g,this.b=t.b+e.b,this}addScalar(t){return this.r+=t,this.g+=t,this.b+=t,this}sub(t){return this.r=Math.max(0,this.r-t.r),this.g=Math.max(0,this.g-t.g),this.b=Math.max(0,this.b-t.b),this}multiply(t){return this.r*=t.r,this.g*=t.g,this.b*=t.b,this}multiplyScalar(t){return this.r*=t,this.g*=t,this.b*=t,this}lerp(t,e){return this.r+=(t.r-this.r)*e,this.g+=(t.g-this.g)*e,this.b+=(t.b-this.b)*e,this}lerpColors(t,e,n){return this.r=t.r+(e.r-t.r)*n,this.g=t.g+(e.g-t.g)*n,this.b=t.b+(e.b-t.b)*n,this}lerpHSL(t,e){this.getHSL(es),t.getHSL(So);let n=o0(es.h,So.h,e),s=o0(es.s,So.s,e),r=o0(es.l,So.l,e);return this.setHSL(n,s,r),this}setFromVector3(t){return this.r=t.x,this.g=t.y,this.b=t.z,this}applyMatrix3(t){let e=this.r,n=this.g,s=this.b,r=t.elements;return this.r=r[0]*e+r[3]*n+r[6]*s,this.g=r[1]*e+r[4]*n+r[7]*s,this.b=r[2]*e+r[5]*n+r[8]*s,this}equals(t){return t.r===this.r&&t.g===this.g&&t.b===this.b}fromArray(t,e=0){return this.r=t[e],this.g=t[e+1],this.b=t[e+2],this}toArray(t=[],e=0){return t[e]=this.r,t[e+1]=this.g,t[e+2]=this.b,t}fromBufferAttribute(t,e){return this.r=t.getX(e),this.g=t.getY(e),this.b=t.getZ(e),this}toJSON(){return this.getHex()}*[Symbol.iterator](){yield this.r,yield this.g,yield this.b}},Dn=new oe;oe.NAMES=Ud;var ha=class extends cn{constructor(){super(),this.isScene=!0,this.type="Scene",this.background=null,this.environment=null,this.fog=null,this.backgroundBlurriness=0,this.backgroundIntensity=1,this.backgroundRotation=new Vi,this.environmentIntensity=1,this.environmentRotation=new Vi,this.overrideMaterial=null,typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}copy(t,e){return super.copy(t,e),t.background!==null&&(this.background=t.background.clone()),t.environment!==null&&(this.environment=t.environment.clone()),t.fog!==null&&(this.fog=t.fog.clone()),this.backgroundBlurriness=t.backgroundBlurriness,this.backgroundIntensity=t.backgroundIntensity,this.backgroundRotation.copy(t.backgroundRotation),this.environmentIntensity=t.environmentIntensity,this.environmentRotation.copy(t.environmentRotation),t.overrideMaterial!==null&&(this.overrideMaterial=t.overrideMaterial.clone()),this.matrixAutoUpdate=t.matrixAutoUpdate,this}toJSON(t){let e=super.toJSON(t);return this.fog!==null&&(e.object.fog=this.fog.toJSON()),e.object.backgroundBlurriness=this.backgroundBlurriness,e.object.backgroundIntensity=this.backgroundIntensity,e.object.backgroundRotation=this.backgroundRotation.toArray(),e.object.environmentIntensity=this.environmentIntensity,e.object.environmentRotation=this.environmentRotation.toArray(),e}},oi=new D,Ui=new D,p0=new D,Fi=new D,Xs=new D,$s=new D,wu=new D,m0=new D,g0=new D,x0=new D,_0=new je,v0=new je,y0=new je,zi=class i{constructor(t=new D,e=new D,n=new D){this.a=t,this.b=e,this.c=n}static getNormal(t,e,n,s){s.subVectors(n,e),oi.subVectors(t,e),s.cross(oi);let r=s.lengthSq();return r>0?s.multiplyScalar(1/Math.sqrt(r)):s.set(0,0,0)}static getBarycoord(t,e,n,s,r){oi.subVectors(s,e),Ui.subVectors(n,e),p0.subVectors(t,e);let a=oi.dot(oi),o=oi.dot(Ui),c=oi.dot(p0),l=Ui.dot(Ui),h=Ui.dot(p0),f=a*l-o*o;if(f===0)return r.set(0,0,0),null;let u=1/f,d=(l*c-o*h)*u,m=(a*h-o*c)*u;return r.set(1-d-m,m,d)}static containsPoint(t,e,n,s){return this.getBarycoord(t,e,n,s,Fi)===null?!1:Fi.x>=0&&Fi.y>=0&&Fi.x+Fi.y<=1}static getInterpolation(t,e,n,s,r,a,o,c){return this.getBarycoord(t,e,n,s,Fi)===null?(c.x=0,c.y=0,"z"in c&&(c.z=0),"w"in c&&(c.w=0),null):(c.setScalar(0),c.addScaledVector(r,Fi.x),c.addScaledVector(a,Fi.y),c.addScaledVector(o,Fi.z),c)}static getInterpolatedAttribute(t,e,n,s,r,a){return _0.setScalar(0),v0.setScalar(0),y0.setScalar(0),_0.fromBufferAttribute(t,e),v0.fromBufferAttribute(t,n),y0.fromBufferAttribute(t,s),a.setScalar(0),a.addScaledVector(_0,r.x),a.addScaledVector(v0,r.y),a.addScaledVector(y0,r.z),a}static isFrontFacing(t,e,n,s){return oi.subVectors(n,e),Ui.subVectors(t,e),oi.cross(Ui).dot(s)<0}set(t,e,n){return this.a.copy(t),this.b.copy(e),this.c.copy(n),this}setFromPointsAndIndices(t,e,n,s){return this.a.copy(t[e]),this.b.copy(t[n]),this.c.copy(t[s]),this}setFromAttributeAndIndices(t,e,n,s){return this.a.fromBufferAttribute(t,e),this.b.fromBufferAttribute(t,n),this.c.fromBufferAttribute(t,s),this}clone(){return new this.constructor().copy(this)}copy(t){return this.a.copy(t.a),this.b.copy(t.b),this.c.copy(t.c),this}getArea(){return oi.subVectors(this.c,this.b),Ui.subVectors(this.a,this.b),oi.cross(Ui).length()*.5}getMidpoint(t){return t.addVectors(this.a,this.b).add(this.c).multiplyScalar(1/3)}getNormal(t){return i.getNormal(this.a,this.b,this.c,t)}getPlane(t){return t.setFromCoplanarPoints(this.a,this.b,this.c)}getBarycoord(t,e){return i.getBarycoord(t,this.a,this.b,this.c,e)}getInterpolation(t,e,n,s,r){return i.getInterpolation(t,this.a,this.b,this.c,e,n,s,r)}containsPoint(t){return i.containsPoint(t,this.a,this.b,this.c)}isFrontFacing(t){return i.isFrontFacing(this.a,this.b,this.c,t)}intersectsBox(t){return t.intersectsTriangle(this)}closestPointToPoint(t,e){let n=this.a,s=this.b,r=this.c,a,o;Xs.subVectors(s,n),$s.subVectors(r,n),m0.subVectors(t,n);let c=Xs.dot(m0),l=$s.dot(m0);if(c<=0&&l<=0)return e.copy(n);g0.subVectors(t,s);let h=Xs.dot(g0),f=$s.dot(g0);if(h>=0&&f<=h)return e.copy(s);let u=c*f-h*l;if(u<=0&&c>=0&&h<=0)return a=c/(c-h),e.copy(n).addScaledVector(Xs,a);x0.subVectors(t,r);let d=Xs.dot(x0),m=$s.dot(x0);if(m>=0&&d<=m)return e.copy(r);let x=d*l-c*m;if(x<=0&&l>=0&&m<=0)return o=l/(l-m),e.copy(n).addScaledVector($s,o);let g=h*m-d*f;if(g<=0&&f-h>=0&&d-m>=0)return wu.subVectors(r,s),o=(f-h)/(f-h+(d-m)),e.copy(s).addScaledVector(wu,o);let p=1/(g+x+u);return a=x*p,o=u*p,e.copy(n).addScaledVector(Xs,a).addScaledVector($s,o)}equals(t){return t.a.equals(this.a)&&t.b.equals(this.b)&&t.c.equals(this.c)}},Ei=class{constructor(t=new D(1/0,1/0,1/0),e=new D(-1/0,-1/0,-1/0)){this.isBox3=!0,this.min=t,this.max=e}set(t,e){return this.min.copy(t),this.max.copy(e),this}setFromArray(t){this.makeEmpty();for(let e=0,n=t.length;e<n;e+=3)this.expandByPoint(li.fromArray(t,e));return this}setFromBufferAttribute(t){this.makeEmpty();for(let e=0,n=t.count;e<n;e++)this.expandByPoint(li.fromBufferAttribute(t,e));return this}setFromPoints(t){this.makeEmpty();for(let e=0,n=t.length;e<n;e++)this.expandByPoint(t[e]);return this}setFromCenterAndSize(t,e){let n=li.copy(e).multiplyScalar(.5);return this.min.copy(t).sub(n),this.max.copy(t).add(n),this}setFromObject(t,e=!1){return this.makeEmpty(),this.expandByObject(t,e)}clone(){return new this.constructor().copy(this)}copy(t){return this.min.copy(t.min),this.max.copy(t.max),this}makeEmpty(){return this.min.x=this.min.y=this.min.z=1/0,this.max.x=this.max.y=this.max.z=-1/0,this}isEmpty(){return this.max.x<this.min.x||this.max.y<this.min.y||this.max.z<this.min.z}getCenter(t){return this.isEmpty()?t.set(0,0,0):t.addVectors(this.min,this.max).multiplyScalar(.5)}getSize(t){return this.isEmpty()?t.set(0,0,0):t.subVectors(this.max,this.min)}expandByPoint(t){return this.min.min(t),this.max.max(t),this}expandByVector(t){return this.min.sub(t),this.max.add(t),this}expandByScalar(t){return this.min.addScalar(-t),this.max.addScalar(t),this}expandByObject(t,e=!1){t.updateWorldMatrix(!1,!1);let n=t.geometry;if(n!==void 0){let r=n.getAttribute("position");if(e===!0&&r!==void 0&&t.isInstancedMesh!==!0)for(let a=0,o=r.count;a<o;a++)t.isMesh===!0?t.getVertexPosition(a,li):li.fromBufferAttribute(r,a),li.applyMatrix4(t.matrixWorld),this.expandByPoint(li);else t.boundingBox!==void 0?(t.boundingBox===null&&t.computeBoundingBox(),wo.copy(t.boundingBox)):(n.boundingBox===null&&n.computeBoundingBox(),wo.copy(n.boundingBox)),wo.applyMatrix4(t.matrixWorld),this.union(wo)}let s=t.children;for(let r=0,a=s.length;r<a;r++)this.expandByObject(s[r],e);return this}containsPoint(t){return t.x>=this.min.x&&t.x<=this.max.x&&t.y>=this.min.y&&t.y<=this.max.y&&t.z>=this.min.z&&t.z<=this.max.z}containsBox(t){return this.min.x<=t.min.x&&t.max.x<=this.max.x&&this.min.y<=t.min.y&&t.max.y<=this.max.y&&this.min.z<=t.min.z&&t.max.z<=this.max.z}getParameter(t,e){return e.set((t.x-this.min.x)/(this.max.x-this.min.x),(t.y-this.min.y)/(this.max.y-this.min.y),(t.z-this.min.z)/(this.max.z-this.min.z))}intersectsBox(t){return t.max.x>=this.min.x&&t.min.x<=this.max.x&&t.max.y>=this.min.y&&t.min.y<=this.max.y&&t.max.z>=this.min.z&&t.min.z<=this.max.z}intersectsSphere(t){return this.clampPoint(t.center,li),li.distanceToSquared(t.center)<=t.radius*t.radius}intersectsPlane(t){let e,n;return t.normal.x>0?(e=t.normal.x*this.min.x,n=t.normal.x*this.max.x):(e=t.normal.x*this.max.x,n=t.normal.x*this.min.x),t.normal.y>0?(e+=t.normal.y*this.min.y,n+=t.normal.y*this.max.y):(e+=t.normal.y*this.max.y,n+=t.normal.y*this.min.y),t.normal.z>0?(e+=t.normal.z*this.min.z,n+=t.normal.z*this.max.z):(e+=t.normal.z*this.max.z,n+=t.normal.z*this.min.z),e<=-t.constant&&n>=-t.constant}intersectsTriangle(t){if(this.isEmpty())return!1;this.getCenter(qr),Eo.subVectors(this.max,qr),qs.subVectors(t.a,qr),Ys.subVectors(t.b,qr),Zs.subVectors(t.c,qr),ns.subVectors(Ys,qs),is.subVectors(Zs,Ys),ys.subVectors(qs,Zs);let e=[0,-ns.z,ns.y,0,-is.z,is.y,0,-ys.z,ys.y,ns.z,0,-ns.x,is.z,0,-is.x,ys.z,0,-ys.x,-ns.y,ns.x,0,-is.y,is.x,0,-ys.y,ys.x,0];return!M0(e,qs,Ys,Zs,Eo)||(e=[1,0,0,0,1,0,0,0,1],!M0(e,qs,Ys,Zs,Eo))?!1:(To.crossVectors(ns,is),e=[To.x,To.y,To.z],M0(e,qs,Ys,Zs,Eo))}clampPoint(t,e){return e.copy(t).clamp(this.min,this.max)}distanceToPoint(t){return this.clampPoint(t,li).distanceTo(t)}getBoundingSphere(t){return this.isEmpty()?t.makeEmpty():(this.getCenter(t.center),t.radius=this.getSize(li).length()*.5),t}intersect(t){return this.min.max(t.min),this.max.min(t.max),this.isEmpty()&&this.makeEmpty(),this}union(t){return this.min.min(t.min),this.max.max(t.max),this}applyMatrix4(t){return this.isEmpty()?this:(Oi[0].set(this.min.x,this.min.y,this.min.z).applyMatrix4(t),Oi[1].set(this.min.x,this.min.y,this.max.z).applyMatrix4(t),Oi[2].set(this.min.x,this.max.y,this.min.z).applyMatrix4(t),Oi[3].set(this.min.x,this.max.y,this.max.z).applyMatrix4(t),Oi[4].set(this.max.x,this.min.y,this.min.z).applyMatrix4(t),Oi[5].set(this.max.x,this.min.y,this.max.z).applyMatrix4(t),Oi[6].set(this.max.x,this.max.y,this.min.z).applyMatrix4(t),Oi[7].set(this.max.x,this.max.y,this.max.z).applyMatrix4(t),this.setFromPoints(Oi),this)}translate(t){return this.min.add(t),this.max.add(t),this}equals(t){return t.min.equals(this.min)&&t.max.equals(this.max)}toJSON(){return{min:this.min.toArray(),max:this.max.toArray()}}fromJSON(t){return this.min.fromArray(t.min),this.max.fromArray(t.max),this}},Oi=[new D,new D,new D,new D,new D,new D,new D,new D],li=new D,wo=new Ei,qs=new D,Ys=new D,Zs=new D,ns=new D,is=new D,ys=new D,qr=new D,Eo=new D,To=new D,Ms=new D;function M0(i,t,e,n,s){for(let r=0,a=i.length-3;r<=a;r+=3){Ms.fromArray(i,r);let o=s.x*Math.abs(Ms.x)+s.y*Math.abs(Ms.y)+s.z*Math.abs(Ms.z),c=t.dot(Ms),l=e.dot(Ms),h=n.dot(Ms);if(Math.max(-Math.max(c,l,h),Math.min(c,l,h))>o)return!1}return!0}var on=new D,Ao=new yt,Ap=0,ln=class extends Si{constructor(t,e,n=!1){if(super(),Array.isArray(t))throw new TypeError("THREE.BufferAttribute: array should be a Typed Array.");this.isBufferAttribute=!0,Object.defineProperty(this,"id",{value:Ap++}),this.name="",this.array=t,this.itemSize=e,this.count=t!==void 0?t.length/e:0,this.normalized=n,this.usage=ah,this.updateRanges=[],this.gpuType=ti,this.version=0}onUploadCallback(){}set needsUpdate(t){t===!0&&this.version++}setUsage(t){return this.usage=t,this}addUpdateRange(t,e){this.updateRanges.push({start:t,count:e})}clearUpdateRanges(){this.updateRanges.length=0}copy(t){return this.name=t.name,this.array=new t.array.constructor(t.array),this.itemSize=t.itemSize,this.count=t.count,this.normalized=t.normalized,this.usage=t.usage,this.gpuType=t.gpuType,this}copyAt(t,e,n){t*=this.itemSize,n*=e.itemSize;for(let s=0,r=this.itemSize;s<r;s++)this.array[t+s]=e.array[n+s];return this}copyArray(t){return this.array.set(t),this}applyMatrix3(t){if(this.itemSize===2)for(let e=0,n=this.count;e<n;e++)Ao.fromBufferAttribute(this,e),Ao.applyMatrix3(t),this.setXY(e,Ao.x,Ao.y);else if(this.itemSize===3)for(let e=0,n=this.count;e<n;e++)on.fromBufferAttribute(this,e),on.applyMatrix3(t),this.setXYZ(e,on.x,on.y,on.z);return this}applyMatrix4(t){for(let e=0,n=this.count;e<n;e++)on.fromBufferAttribute(this,e),on.applyMatrix4(t),this.setXYZ(e,on.x,on.y,on.z);return this}applyNormalMatrix(t){for(let e=0,n=this.count;e<n;e++)on.fromBufferAttribute(this,e),on.applyNormalMatrix(t),this.setXYZ(e,on.x,on.y,on.z);return this}transformDirection(t){for(let e=0,n=this.count;e<n;e++)on.fromBufferAttribute(this,e),on.transformDirection(t),this.setXYZ(e,on.x,on.y,on.z);return this}set(t,e=0){return this.array.set(t,e),this}getComponent(t,e){let n=this.array[t*this.itemSize+e];return this.normalized&&(n=vi(n,this.array)),n}setComponent(t,e,n){return this.normalized&&(n=Ye(n,this.array)),this.array[t*this.itemSize+e]=n,this}getX(t){let e=this.array[t*this.itemSize];return this.normalized&&(e=vi(e,this.array)),e}setX(t,e){return this.normalized&&(e=Ye(e,this.array)),this.array[t*this.itemSize]=e,this}getY(t){let e=this.array[t*this.itemSize+1];return this.normalized&&(e=vi(e,this.array)),e}setY(t,e){return this.normalized&&(e=Ye(e,this.array)),this.array[t*this.itemSize+1]=e,this}getZ(t){let e=this.array[t*this.itemSize+2];return this.normalized&&(e=vi(e,this.array)),e}setZ(t,e){return this.normalized&&(e=Ye(e,this.array)),this.array[t*this.itemSize+2]=e,this}getW(t){let e=this.array[t*this.itemSize+3];return this.normalized&&(e=vi(e,this.array)),e}setW(t,e){return this.normalized&&(e=Ye(e,this.array)),this.array[t*this.itemSize+3]=e,this}setXY(t,e,n){return t*=this.itemSize,this.normalized&&(e=Ye(e,this.array),n=Ye(n,this.array)),this.array[t+0]=e,this.array[t+1]=n,this}setXYZ(t,e,n,s){return t*=this.itemSize,this.normalized&&(e=Ye(e,this.array),n=Ye(n,this.array),s=Ye(s,this.array)),this.array[t+0]=e,this.array[t+1]=n,this.array[t+2]=s,this}setXYZW(t,e,n,s,r){return t*=this.itemSize,this.normalized&&(e=Ye(e,this.array),n=Ye(n,this.array),s=Ye(s,this.array),r=Ye(r,this.array)),this.array[t+0]=e,this.array[t+1]=n,this.array[t+2]=s,this.array[t+3]=r,this}onUpload(t){return this.onUploadCallback=t,this}clone(){return new this.constructor(this.array,this.itemSize).copy(this)}toJSON(){let t={itemSize:this.itemSize,type:this.array.constructor.name,array:Array.from(this.array),normalized:this.normalized};return t.name=this.name,t.usage=this.usage,t.gpuType=this.gpuType,t}dispose(){this.dispatchEvent({type:"dispose"})}};var ua=class extends ln{constructor(t,e,n){super(new Uint16Array(t),e,n)}};var da=class extends ln{constructor(t,e,n){super(new Uint32Array(t),e,n)}};var ge=class extends ln{constructor(t,e,n){super(new Float32Array(t),e,n)}},Rp=new Ei,Yr=new D,b0=new D,Jn=class{constructor(t=new D,e=-1){this.isSphere=!0,this.center=t,this.radius=e}set(t,e){return this.center.copy(t),this.radius=e,this}setFromPoints(t,e){let n=this.center;e!==void 0?n.copy(e):Rp.setFromPoints(t).getCenter(n);let s=0;for(let r=0,a=t.length;r<a;r++)s=Math.max(s,n.distanceToSquared(t[r]));return this.radius=Math.sqrt(s),this}copy(t){return this.center.copy(t.center),this.radius=t.radius,this}isEmpty(){return this.radius<0}makeEmpty(){return this.center.set(0,0,0),this.radius=-1,this}containsPoint(t){return t.distanceToSquared(this.center)<=this.radius*this.radius}distanceToPoint(t){return t.distanceTo(this.center)-this.radius}intersectsSphere(t){let e=this.radius+t.radius;return t.center.distanceToSquared(this.center)<=e*e}intersectsBox(t){return t.intersectsSphere(this)}intersectsPlane(t){return Math.abs(t.distanceToPoint(this.center))<=this.radius}clampPoint(t,e){let n=this.center.distanceToSquared(t);return e.copy(t),n>this.radius*this.radius&&(e.sub(this.center).normalize(),e.multiplyScalar(this.radius).add(this.center)),e}getBoundingBox(t){return this.isEmpty()?(t.makeEmpty(),t):(t.set(this.center,this.center),t.expandByScalar(this.radius),t)}applyMatrix4(t){return this.center.applyMatrix4(t),this.radius=this.radius*t.getMaxScaleOnAxis(),this}translate(t){return this.center.add(t),this}expandByPoint(t){if(this.isEmpty())return this.center.copy(t),this.radius=0,this;Yr.subVectors(t,this.center);let e=Yr.lengthSq();if(e>this.radius*this.radius){let n=Math.sqrt(e),s=(n-this.radius)*.5;this.center.addScaledVector(Yr,s/n),this.radius+=s}return this}union(t){return t.isEmpty()?this:this.isEmpty()?(this.copy(t),this):(this.center.equals(t.center)===!0?this.radius=Math.max(this.radius,t.radius):(b0.subVectors(t.center,this.center).setLength(t.radius),this.expandByPoint(Yr.copy(t.center).add(b0)),this.expandByPoint(Yr.copy(t.center).sub(b0))),this)}equals(t){return t.center.equals(this.center)&&t.radius===this.radius}clone(){return new this.constructor().copy(this)}toJSON(){return{radius:this.radius,center:this.center.toArray()}}fromJSON(t){return this.radius=t.radius,this.center.fromArray(t.center),this}},Cp=0,Zn=new De,S0=new cn,Js=new D,Wn=new Ei,Zr=new Ei,Mn=new D,Le=class i extends Si{constructor(){super(),this.isBufferGeometry=!0,Object.defineProperty(this,"id",{value:Cp++}),this.uuid=ki(),this.name="",this.type="BufferGeometry",this.index=null,this.indirect=null,this.indirectOffset=0,this.attributes={},this.morphAttributes={},this.morphTargetsRelative=!1,this.groups=[],this.boundingBox=null,this.boundingSphere=null,this.drawRange={start:0,count:1/0},this.userData={},this._transformed=!1}getIndex(){return this.index}setIndex(t){return Array.isArray(t)?this.index=new(pp(t)?da:ua)(t,1):this.index=t,this}setIndirect(t,e=0){return this.indirect=t,this.indirectOffset=e,this}getIndirect(){return this.indirect}getAttribute(t){return this.attributes[t]}setAttribute(t,e){return this.attributes[t]=e,this}deleteAttribute(t){return delete this.attributes[t],this}hasAttribute(t){return this.attributes[t]!==void 0}addGroup(t,e,n=0){this.groups.push({start:t,count:e,materialIndex:n})}clearGroups(){this.groups=[]}setDrawRange(t,e){this.drawRange.start=t,this.drawRange.count=e}applyMatrix4(t){let e=this.attributes.position;e!==void 0&&(e.applyMatrix4(t),e.needsUpdate=!0);let n=this.attributes.normal;if(n!==void 0){let r=new ve().getNormalMatrix(t);n.applyNormalMatrix(r),n.needsUpdate=!0}let s=this.attributes.tangent;return s!==void 0&&(s.transformDirection(t),s.needsUpdate=!0),this.boundingBox!==null&&this.computeBoundingBox(),this.boundingSphere!==null&&this.computeBoundingSphere(),this._transformed=!0,this}applyQuaternion(t){return Zn.makeRotationFromQuaternion(t),this.applyMatrix4(Zn),this}rotateX(t){return Zn.makeRotationX(t),this.applyMatrix4(Zn),this}rotateY(t){return Zn.makeRotationY(t),this.applyMatrix4(Zn),this}rotateZ(t){return Zn.makeRotationZ(t),this.applyMatrix4(Zn),this}translate(t,e,n){return Zn.makeTranslation(t,e,n),this.applyMatrix4(Zn),this}scale(t,e,n){return Zn.makeScale(t,e,n),this.applyMatrix4(Zn),this}lookAt(t){return S0.lookAt(t),S0.updateMatrix(),this.applyMatrix4(S0.matrix),this}center(){return this.computeBoundingBox(),this.boundingBox.getCenter(Js).negate(),this.translate(Js.x,Js.y,Js.z),this}setFromPoints(t){let e=this.getAttribute("position");if(e===void 0){let n=[];for(let s=0,r=t.length;s<r;s++){let a=t[s];n.push(a.x,a.y,a.z||0)}this.setAttribute("position",new ge(n,3))}else{let n=Math.min(t.length,e.count);for(let s=0;s<n;s++){let r=t[s];e.setXYZ(s,r.x,r.y,r.z||0)}t.length>e.count&&pe("BufferGeometry: Buffer size too small for points data. Use .dispose() and create a new geometry."),e.needsUpdate=!0}return this}computeBoundingBox(){this.boundingBox===null&&(this.boundingBox=new Ei);let t=this.attributes.position,e=this.morphAttributes.position;if(t&&t.isGLBufferAttribute){fe("BufferGeometry.computeBoundingBox(): GLBufferAttribute requires a manual bounding box.",this),this.boundingBox.set(new D(-1/0,-1/0,-1/0),new D(1/0,1/0,1/0));return}if(t!==void 0){if(this.boundingBox.setFromBufferAttribute(t),e)for(let n=0,s=e.length;n<s;n++){let r=e[n];Wn.setFromBufferAttribute(r),this.morphTargetsRelative?(Mn.addVectors(this.boundingBox.min,Wn.min),this.boundingBox.expandByPoint(Mn),Mn.addVectors(this.boundingBox.max,Wn.max),this.boundingBox.expandByPoint(Mn)):(this.boundingBox.expandByPoint(Wn.min),this.boundingBox.expandByPoint(Wn.max))}}else this.boundingBox.makeEmpty();(isNaN(this.boundingBox.min.x)||isNaN(this.boundingBox.min.y)||isNaN(this.boundingBox.min.z))&&fe('BufferGeometry.computeBoundingBox(): Computed min/max have NaN values. The "position" attribute is likely to have NaN values.',this)}computeBoundingSphere(){this.boundingSphere===null&&(this.boundingSphere=new Jn);let t=this.attributes.position,e=this.morphAttributes.position;if(t&&t.isGLBufferAttribute){fe("BufferGeometry.computeBoundingSphere(): GLBufferAttribute requires a manual bounding sphere.",this),this.boundingSphere.set(new D,1/0);return}if(t){let n=this.boundingSphere.center;if(Wn.setFromBufferAttribute(t),e)for(let r=0,a=e.length;r<a;r++){let o=e[r];Zr.setFromBufferAttribute(o),this.morphTargetsRelative?(Mn.addVectors(Wn.min,Zr.min),Wn.expandByPoint(Mn),Mn.addVectors(Wn.max,Zr.max),Wn.expandByPoint(Mn)):(Wn.expandByPoint(Zr.min),Wn.expandByPoint(Zr.max))}Wn.getCenter(n);let s=0;for(let r=0,a=t.count;r<a;r++)Mn.fromBufferAttribute(t,r),s=Math.max(s,n.distanceToSquared(Mn));if(e)for(let r=0,a=e.length;r<a;r++){let o=e[r],c=this.morphTargetsRelative;for(let l=0,h=o.count;l<h;l++)Mn.fromBufferAttribute(o,l),c&&(Js.fromBufferAttribute(t,l),Mn.add(Js)),s=Math.max(s,n.distanceToSquared(Mn))}this.boundingSphere.radius=Math.sqrt(s),isNaN(this.boundingSphere.radius)&&fe('BufferGeometry.computeBoundingSphere(): Computed radius is NaN. The "position" attribute is likely to have NaN values.',this)}}computeTangents(){let t=this.index,e=this.attributes;if(t===null||e.position===void 0||e.normal===void 0||e.uv===void 0){fe("BufferGeometry: .computeTangents() failed. Missing required attributes (index, position, normal or uv)");return}let n=e.position,s=e.normal,r=e.uv,a=this.getAttribute("tangent");(a===void 0||a.count!==n.count)&&(a=new ln(new Float32Array(4*n.count),4),this.setAttribute("tangent",a));let o=[],c=[];for(let v=0;v<n.count;v++)o[v]=new D,c[v]=new D;let l=new D,h=new D,f=new D,u=new yt,d=new yt,m=new yt,x=new D,g=new D;function p(v,R,I){l.fromBufferAttribute(n,v),h.fromBufferAttribute(n,R),f.fromBufferAttribute(n,I),u.fromBufferAttribute(r,v),d.fromBufferAttribute(r,R),m.fromBufferAttribute(r,I),h.sub(l),f.sub(l),d.sub(u),m.sub(u);let N=1/(d.x*m.y-m.x*d.y);isFinite(N)&&(x.copy(h).multiplyScalar(m.y).addScaledVector(f,-d.y).multiplyScalar(N),g.copy(f).multiplyScalar(d.x).addScaledVector(h,-m.x).multiplyScalar(N),o[v].add(x),o[R].add(x),o[I].add(x),c[v].add(g),c[R].add(g),c[I].add(g))}let b=this.groups;b.length===0&&(b=[{start:0,count:t.count}]);for(let v=0,R=b.length;v<R;++v){let I=b[v],N=I.start,L=I.count;for(let O=N,P=N+L;O<P;O+=3)p(t.getX(O+0),t.getX(O+1),t.getX(O+2))}let E=new D,y=new D,w=new D,S=new D;function C(v){w.fromBufferAttribute(s,v),S.copy(w);let R=o[v];E.copy(R),E.sub(w.multiplyScalar(w.dot(R))).normalize(),y.crossVectors(S,R);let N=y.dot(c[v])<0?-1:1;a.setXYZW(v,E.x,E.y,E.z,N)}for(let v=0,R=b.length;v<R;++v){let I=b[v],N=I.start,L=I.count;for(let O=N,P=N+L;O<P;O+=3)C(t.getX(O+0)),C(t.getX(O+1)),C(t.getX(O+2))}this._transformed=!0}computeVertexNormals(){let t=this.index,e=this.getAttribute("position");if(e!==void 0){let n=this.getAttribute("normal");if(n===void 0||n.count!==e.count)n=new ln(new Float32Array(e.count*3),3),this.setAttribute("normal",n);else for(let u=0,d=n.count;u<d;u++)n.setXYZ(u,0,0,0);let s=new D,r=new D,a=new D,o=new D,c=new D,l=new D,h=new D,f=new D;if(t)for(let u=0,d=t.count;u<d;u+=3){let m=t.getX(u+0),x=t.getX(u+1),g=t.getX(u+2);s.fromBufferAttribute(e,m),r.fromBufferAttribute(e,x),a.fromBufferAttribute(e,g),h.subVectors(a,r),f.subVectors(s,r),h.cross(f),o.fromBufferAttribute(n,m),c.fromBufferAttribute(n,x),l.fromBufferAttribute(n,g),o.add(h),c.add(h),l.add(h),n.setXYZ(m,o.x,o.y,o.z),n.setXYZ(x,c.x,c.y,c.z),n.setXYZ(g,l.x,l.y,l.z)}else for(let u=0,d=e.count;u<d;u+=3)s.fromBufferAttribute(e,u+0),r.fromBufferAttribute(e,u+1),a.fromBufferAttribute(e,u+2),h.subVectors(a,r),f.subVectors(s,r),h.cross(f),n.setXYZ(u+0,h.x,h.y,h.z),n.setXYZ(u+1,h.x,h.y,h.z),n.setXYZ(u+2,h.x,h.y,h.z);this.normalizeNormals(),n.needsUpdate=!0}}normalizeNormals(){let t=this.attributes.normal;for(let e=0,n=t.count;e<n;e++)Mn.fromBufferAttribute(t,e),Mn.normalize(),t.setXYZ(e,Mn.x,Mn.y,Mn.z)}toNonIndexed(){function t(o,c){let l=o.array,h=o.itemSize,f=o.normalized,u=new l.constructor(c.length*h),d=0,m=0;for(let x=0,g=c.length;x<g;x++){o.isInterleavedBufferAttribute?d=c[x]*o.data.stride+o.offset:d=c[x]*h;for(let p=0;p<h;p++)u[m++]=l[d++]}return new ln(u,h,f)}if(this.index===null)return pe("BufferGeometry.toNonIndexed(): BufferGeometry is already non-indexed."),this;let e=new i,n=this.index.array,s=this.attributes;for(let o in s){let c=s[o],l=t(c,n);e.setAttribute(o,l)}let r=this.morphAttributes;for(let o in r){let c=[],l=r[o];for(let h=0,f=l.length;h<f;h++){let u=l[h],d=t(u,n);c.push(d)}e.morphAttributes[o]=c}e.morphTargetsRelative=this.morphTargetsRelative;let a=this.groups;for(let o=0,c=a.length;o<c;o++){let l=a[o];e.addGroup(l.start,l.count,l.materialIndex)}return e}toJSON(){let t={metadata:{version:4.7,type:"BufferGeometry",generator:"BufferGeometry.toJSON"}};if(t.uuid=this.uuid,t.type=this.parameters!==void 0&&this._transformed===!0?"BufferGeometry":this.type,t.name=this.name,Object.keys(this.userData).length>0&&(t.userData=this.userData),this.parameters!==void 0&&this._transformed!==!0){let c=this.parameters;for(let l in c)c[l]!==void 0&&(t[l]=c[l]);return t}t.data={attributes:{}};let e=this.index;e!==null&&(t.data.index={type:e.array.constructor.name,array:Array.prototype.slice.call(e.array)});let n=this.attributes;for(let c in n){let l=n[c];t.data.attributes[c]=l.toJSON(t.data)}let s={},r=!1;for(let c in this.morphAttributes){let l=this.morphAttributes[c],h=[];for(let f=0,u=l.length;f<u;f++){let d=l[f];h.push(d.toJSON(t.data))}h.length>0&&(s[c]=h,r=!0)}r&&(t.data.morphAttributes=s,t.data.morphTargetsRelative=this.morphTargetsRelative);let a=this.groups;a.length>0&&(t.data.groups=JSON.parse(JSON.stringify(a)));let o=this.boundingSphere;return o!==null&&(t.data.boundingSphere=o.toJSON()),t}clone(){return new this.constructor().copy(this)}copy(t){this.index=null,this.attributes={},this.morphAttributes={},this.groups=[],this.boundingBox=null,this.boundingSphere=null;let e={};this.name=t.name;let n=t.index;n!==null&&this.setIndex(n.clone());let s=t.attributes;for(let l in s){let h=s[l];this.setAttribute(l,h.clone(e))}let r=t.morphAttributes;for(let l in r){let h=[],f=r[l];for(let u=0,d=f.length;u<d;u++)h.push(f[u].clone(e));this.morphAttributes[l]=h}this.morphTargetsRelative=t.morphTargetsRelative;let a=t.groups;for(let l=0,h=a.length;l<h;l++){let f=a[l];this.addGroup(f.start,f.count,f.materialIndex)}let o=t.boundingBox;o!==null&&(this.boundingBox=o.clone());let c=t.boundingSphere;return c!==null&&(this.boundingSphere=c.clone()),this.drawRange.start=t.drawRange.start,this.drawRange.count=t.drawRange.count,this.userData=t.userData,this._transformed=t._transformed,this}dispose(){this.dispatchEvent({type:"dispose"})}},fa=class{constructor(t,e){this.isInterleavedBuffer=!0,this.array=t,this.stride=e,this.count=t!==void 0?t.length/e:0,this.usage=ah,this.updateRanges=[],this.version=0,this.uuid=ki()}onUploadCallback(){}set needsUpdate(t){t===!0&&this.version++}setUsage(t){return this.usage=t,this}addUpdateRange(t,e){this.updateRanges.push({start:t,count:e})}clearUpdateRanges(){this.updateRanges.length=0}copy(t){return this.array=new t.array.constructor(t.array),this.count=t.count,this.stride=t.stride,this.usage=t.usage,this}copyAt(t,e,n){t*=this.stride,n*=e.stride;for(let s=0,r=this.stride;s<r;s++)this.array[t+s]=e.array[n+s];return this}set(t,e=0){return this.array.set(t,e),this}clone(t){t.arrayBuffers===void 0&&(t.arrayBuffers={}),this.array.buffer._uuid===void 0&&(this.array.buffer._uuid=ki()),t.arrayBuffers[this.array.buffer._uuid]===void 0&&(t.arrayBuffers[this.array.buffer._uuid]=this.array.slice(0).buffer);let e=new this.array.constructor(t.arrayBuffers[this.array.buffer._uuid]),n=new this.constructor(e,this.stride);return n.setUsage(this.usage),n}onUpload(t){return this.onUploadCallback=t,this}toJSON(t){t.arrayBuffers===void 0&&(t.arrayBuffers={}),this.array.buffer._uuid===void 0&&(this.array.buffer._uuid=ki()),t.arrayBuffers[this.array.buffer._uuid]===void 0&&(t.arrayBuffers[this.array.buffer._uuid]=Array.from(new Uint32Array(this.array.buffer)));let e={uuid:this.uuid,buffer:this.array.buffer._uuid,type:this.array.constructor.name,stride:this.stride};return e.usage=this.usage,e}},zn=new D,pr=class i{constructor(t,e,n,s=!1){this.isInterleavedBufferAttribute=!0,this.name="",this.data=t,this.itemSize=e,this.offset=n,this.normalized=s}get count(){return this.data.count}get array(){return this.data.array}set needsUpdate(t){this.data.needsUpdate=t}applyMatrix4(t){for(let e=0,n=this.data.count;e<n;e++)zn.fromBufferAttribute(this,e),zn.applyMatrix4(t),this.setXYZ(e,zn.x,zn.y,zn.z);return this}applyNormalMatrix(t){for(let e=0,n=this.count;e<n;e++)zn.fromBufferAttribute(this,e),zn.applyNormalMatrix(t),this.setXYZ(e,zn.x,zn.y,zn.z);return this}transformDirection(t){for(let e=0,n=this.count;e<n;e++)zn.fromBufferAttribute(this,e),zn.transformDirection(t),this.setXYZ(e,zn.x,zn.y,zn.z);return this}getComponent(t,e){let n=this.array[t*this.data.stride+this.offset+e];return this.normalized&&(n=vi(n,this.array)),n}setComponent(t,e,n){return this.normalized&&(n=Ye(n,this.array)),this.data.array[t*this.data.stride+this.offset+e]=n,this}setX(t,e){return this.normalized&&(e=Ye(e,this.array)),this.data.array[t*this.data.stride+this.offset]=e,this}setY(t,e){return this.normalized&&(e=Ye(e,this.array)),this.data.array[t*this.data.stride+this.offset+1]=e,this}setZ(t,e){return this.normalized&&(e=Ye(e,this.array)),this.data.array[t*this.data.stride+this.offset+2]=e,this}setW(t,e){return this.normalized&&(e=Ye(e,this.array)),this.data.array[t*this.data.stride+this.offset+3]=e,this}getX(t){let e=this.data.array[t*this.data.stride+this.offset];return this.normalized&&(e=vi(e,this.array)),e}getY(t){let e=this.data.array[t*this.data.stride+this.offset+1];return this.normalized&&(e=vi(e,this.array)),e}getZ(t){let e=this.data.array[t*this.data.stride+this.offset+2];return this.normalized&&(e=vi(e,this.array)),e}getW(t){let e=this.data.array[t*this.data.stride+this.offset+3];return this.normalized&&(e=vi(e,this.array)),e}setXY(t,e,n){return t=t*this.data.stride+this.offset,this.normalized&&(e=Ye(e,this.array),n=Ye(n,this.array)),this.data.array[t+0]=e,this.data.array[t+1]=n,this}setXYZ(t,e,n,s){return t=t*this.data.stride+this.offset,this.normalized&&(e=Ye(e,this.array),n=Ye(n,this.array),s=Ye(s,this.array)),this.data.array[t+0]=e,this.data.array[t+1]=n,this.data.array[t+2]=s,this}setXYZW(t,e,n,s,r){return t=t*this.data.stride+this.offset,this.normalized&&(e=Ye(e,this.array),n=Ye(n,this.array),s=Ye(s,this.array),r=Ye(r,this.array)),this.data.array[t+0]=e,this.data.array[t+1]=n,this.data.array[t+2]=s,this.data.array[t+3]=r,this}clone(t){if(t===void 0){la("InterleavedBufferAttribute.clone(): Cloning an interleaved buffer attribute will de-interleave buffer data.");let e=[];for(let n=0;n<this.count;n++){let s=n*this.data.stride+this.offset;for(let r=0;r<this.itemSize;r++)e.push(this.data.array[s+r])}return new ln(new this.array.constructor(e),this.itemSize,this.normalized)}else return t.interleavedBuffers===void 0&&(t.interleavedBuffers={}),t.interleavedBuffers[this.data.uuid]===void 0&&(t.interleavedBuffers[this.data.uuid]=this.data.clone(t)),new i(t.interleavedBuffers[this.data.uuid],this.itemSize,this.offset,this.normalized)}toJSON(t){if(t===void 0){la("InterleavedBufferAttribute.toJSON(): Serializing an interleaved buffer attribute will de-interleave buffer data.");let e=[];for(let n=0;n<this.count;n++){let s=n*this.data.stride+this.offset;for(let r=0;r<this.itemSize;r++)e.push(this.data.array[s+r])}return{itemSize:this.itemSize,type:this.array.constructor.name,array:e,normalized:this.normalized}}else return t.interleavedBuffers===void 0&&(t.interleavedBuffers={}),t.interleavedBuffers[this.data.uuid]===void 0&&(t.interleavedBuffers[this.data.uuid]=this.data.toJSON(t)),{isInterleavedBufferAttribute:!0,itemSize:this.itemSize,data:this.data.uuid,offset:this.offset,normalized:this.normalized}}},w0=new D,Ip=new D,Pp=new ve,ci=class{constructor(t=new D(1,0,0),e=0){this.isPlane=!0,this.normal=t,this.constant=e}set(t,e){return this.normal.copy(t),this.constant=e,this}setComponents(t,e,n,s){return this.normal.set(t,e,n),this.constant=s,this}setFromNormalAndCoplanarPoint(t,e){return this.normal.copy(t),this.constant=-e.dot(this.normal),this}setFromCoplanarPoints(t,e,n){let s=w0.subVectors(n,e).cross(Ip.subVectors(t,e)).normalize();return this.setFromNormalAndCoplanarPoint(s,t),this}copy(t){return this.normal.copy(t.normal),this.constant=t.constant,this}normalize(){let t=1/this.normal.length();return this.normal.multiplyScalar(t),this.constant*=t,this}negate(){return this.constant*=-1,this.normal.negate(),this}distanceToPoint(t){return this.normal.dot(t)+this.constant}distanceToSphere(t){return this.distanceToPoint(t.center)-t.radius}projectPoint(t,e){return e.copy(t).addScaledVector(this.normal,-this.distanceToPoint(t))}intersectLine(t,e,n=!0){let s=t.delta(w0),r=this.normal.dot(s);if(r===0)return this.distanceToPoint(t.start)===0?e.copy(t.start):null;let a=-(t.start.dot(this.normal)+this.constant)/r;return n===!0&&(a<0||a>1)?null:e.copy(t.start).addScaledVector(s,a)}intersectsLine(t){let e=this.distanceToPoint(t.start),n=this.distanceToPoint(t.end);return e<0&&n>0||n<0&&e>0}intersectsBox(t){return t.intersectsPlane(this)}intersectsSphere(t){return t.intersectsPlane(this)}coplanarPoint(t){return t.copy(this.normal).multiplyScalar(-this.constant)}applyMatrix4(t,e){let n=e||Pp.getNormalMatrix(t),s=this.coplanarPoint(w0).applyMatrix4(t),r=this.normal.applyMatrix3(n).normalize();return this.constant=-s.dot(r),this}translate(t){return this.constant-=t.dot(this.normal),this}equals(t){return t.normal.equals(this.normal)&&t.constant===this.constant}clone(){return new this.constructor().copy(this)}toJSON(){return{normal:this.normal.toArray(),constant:this.constant}}fromJSON(t){return this.normal.fromArray(t.normal),this.constant=t.constant,this}},Lp=0,ui=class extends Si{constructor(){super(),this.isMaterial=!0,Object.defineProperty(this,"id",{value:Lp++}),this.uuid=ki(),this.name="",this.type="Material",this.blending=ps,this.side=fs,this.vertexColors=!1,this.opacity=1,this.transparent=!1,this.alphaHash=!1,this.blendSrc=J0,this.blendDst=K0,this.blendEquation=As,this.blendSrcAlpha=null,this.blendDstAlpha=null,this.blendEquationAlpha=null,this.blendColor=new oe(0,0,0),this.blendAlpha=0,this.depthFunc=or,this.depthTest=!0,this.depthWrite=!0,this.stencilWriteMask=255,this.stencilFunc=wd,this.stencilRef=0,this.stencilFuncMask=255,this.stencilFail=jo,this.stencilZFail=jo,this.stencilZPass=jo,this.stencilWrite=!1,this.clippingPlanes=null,this.clipIntersection=!1,this.clipShadows=!1,this.shadowSide=null,this.colorWrite=!0,this.precision=null,this.polygonOffset=!1,this.polygonOffsetFactor=0,this.polygonOffsetUnits=0,this.dithering=!1,this.alphaToCoverage=!1,this.premultipliedAlpha=!1,this.forceSinglePass=!1,this.allowOverride=!0,this.visible=!0,this.toneMapped=!0,this.userData={},this.version=0,this._alphaTest=0}get alphaTest(){return this._alphaTest}set alphaTest(t){this._alphaTest>0!=t>0&&this.version++,this._alphaTest=t}onBeforeRender(){}onBeforeCompile(){}customProgramCacheKey(){return this.onBeforeCompile.toString()}setValues(t){if(t!==void 0)for(let e in t){let n=t[e];if(n===void 0){pe(`Material: parameter '${e}' has value of undefined.`);continue}let s=this[e];if(s===void 0){pe(`Material: '${e}' is not a property of THREE.${this.type}.`);continue}s&&s.isColor?s.set(n):s&&s.isVector2&&n&&n.isVector2||s&&s.isEuler&&n&&n.isEuler||s&&s.isVector3&&n&&n.isVector3?s.copy(n):this[e]=n}}toJSON(t){let e=t===void 0||typeof t=="string";e&&(t={textures:{},images:{}});let n={metadata:{version:4.7,type:"Material",generator:"Material.toJSON"}};n.uuid=this.uuid,n.type=this.type,n.blending=this.blending,n.side=this.side,n.shadowSide=this.shadowSide,n.vertexColors=this.vertexColors,n.opacity=this.opacity,n.transparent=this.transparent,n.blendSrc=this.blendSrc,n.blendDst=this.blendDst,n.blendEquation=this.blendEquation,n.blendSrcAlpha=this.blendSrcAlpha,n.blendDstAlpha=this.blendDstAlpha,n.blendEquationAlpha=this.blendEquationAlpha,n.blendColor=this.blendColor.getHex(),n.blendAlpha=this.blendAlpha,n.depthFunc=this.depthFunc,n.depthTest=this.depthTest,n.depthWrite=this.depthWrite,n.colorWrite=this.colorWrite,n.clipIntersection=this.clipIntersection,n.clipShadows=this.clipShadows,n.stencilWriteMask=this.stencilWriteMask,n.stencilFunc=this.stencilFunc,n.stencilRef=this.stencilRef,n.stencilFuncMask=this.stencilFuncMask,n.stencilFail=this.stencilFail,n.stencilZFail=this.stencilZFail,n.stencilZPass=this.stencilZPass,n.stencilWrite=this.stencilWrite,n.polygonOffset=this.polygonOffset,n.polygonOffsetFactor=this.polygonOffsetFactor,n.polygonOffsetUnits=this.polygonOffsetUnits,n.dithering=this.dithering,n.alphaTest=this.alphaTest,n.alphaHash=this.alphaHash,n.alphaToCoverage=this.alphaToCoverage,n.premultipliedAlpha=this.premultipliedAlpha,n.forceSinglePass=this.forceSinglePass,n.allowOverride=this.allowOverride,n.visible=this.visible,n.toneMapped=this.toneMapped,n.name=this.name,this.color&&this.color.isColor&&(n.color=this.color.getHex()),this.roughness!==void 0&&(n.roughness=this.roughness),this.metalness!==void 0&&(n.metalness=this.metalness),this.sheen!==void 0&&(n.sheen=this.sheen),this.sheenColor&&this.sheenColor.isColor&&(n.sheenColor=this.sheenColor.getHex()),this.sheenRoughness!==void 0&&(n.sheenRoughness=this.sheenRoughness),this.emissive&&this.emissive.isColor&&(n.emissive=this.emissive.getHex()),this.emissiveIntensity!==void 0&&(n.emissiveIntensity=this.emissiveIntensity),this.specular&&this.specular.isColor&&(n.specular=this.specular.getHex()),this.specularIntensity!==void 0&&(n.specularIntensity=this.specularIntensity),this.specularColor&&this.specularColor.isColor&&(n.specularColor=this.specularColor.getHex()),this.shininess!==void 0&&(n.shininess=this.shininess),this.clearcoat!==void 0&&(n.clearcoat=this.clearcoat),this.clearcoatRoughness!==void 0&&(n.clearcoatRoughness=this.clearcoatRoughness),this.clearcoatMap&&this.clearcoatMap.isTexture&&(n.clearcoatMap=this.clearcoatMap.toJSON(t).uuid),this.clearcoatRoughnessMap&&this.clearcoatRoughnessMap.isTexture&&(n.clearcoatRoughnessMap=this.clearcoatRoughnessMap.toJSON(t).uuid),this.clearcoatNormalMap&&this.clearcoatNormalMap.isTexture&&(n.clearcoatNormalMap=this.clearcoatNormalMap.toJSON(t).uuid,n.clearcoatNormalScale=this.clearcoatNormalScale.toArray()),this.sheenColorMap&&this.sheenColorMap.isTexture&&(n.sheenColorMap=this.sheenColorMap.toJSON(t).uuid),this.sheenRoughnessMap&&this.sheenRoughnessMap.isTexture&&(n.sheenRoughnessMap=this.sheenRoughnessMap.toJSON(t).uuid),this.dispersion!==void 0&&(n.dispersion=this.dispersion),this.retroreflectivity!==void 0&&(n.retroreflectivity=this.retroreflectivity),this.iridescence!==void 0&&(n.iridescence=this.iridescence),this.iridescenceIOR!==void 0&&(n.iridescenceIOR=this.iridescenceIOR),this.iridescenceThicknessRange!==void 0&&(n.iridescenceThicknessRange=this.iridescenceThicknessRange),this.iridescenceMap&&this.iridescenceMap.isTexture&&(n.iridescenceMap=this.iridescenceMap.toJSON(t).uuid),this.iridescenceThicknessMap&&this.iridescenceThicknessMap.isTexture&&(n.iridescenceThicknessMap=this.iridescenceThicknessMap.toJSON(t).uuid),this.anisotropy!==void 0&&(n.anisotropy=this.anisotropy),this.anisotropyRotation!==void 0&&(n.anisotropyRotation=this.anisotropyRotation),this.anisotropyMap&&this.anisotropyMap.isTexture&&(n.anisotropyMap=this.anisotropyMap.toJSON(t).uuid),this.map&&this.map.isTexture&&(n.map=this.map.toJSON(t).uuid),this.matcap&&this.matcap.isTexture&&(n.matcap=this.matcap.toJSON(t).uuid),this.alphaMap&&this.alphaMap.isTexture&&(n.alphaMap=this.alphaMap.toJSON(t).uuid),this.lightMap&&this.lightMap.isTexture&&(n.lightMap=this.lightMap.toJSON(t).uuid,n.lightMapIntensity=this.lightMapIntensity),this.aoMap&&this.aoMap.isTexture&&(n.aoMap=this.aoMap.toJSON(t).uuid,n.aoMapIntensity=this.aoMapIntensity),this.bumpMap&&this.bumpMap.isTexture&&(n.bumpMap=this.bumpMap.toJSON(t).uuid,n.bumpScale=this.bumpScale),this.normalMap&&this.normalMap.isTexture&&(n.normalMap=this.normalMap.toJSON(t).uuid,n.normalMapType=this.normalMapType,n.normalScale=this.normalScale.toArray()),this.displacementMap&&this.displacementMap.isTexture&&(n.displacementMap=this.displacementMap.toJSON(t).uuid,n.displacementScale=this.displacementScale,n.displacementBias=this.displacementBias),this.roughnessMap&&this.roughnessMap.isTexture&&(n.roughnessMap=this.roughnessMap.toJSON(t).uuid),this.metalnessMap&&this.metalnessMap.isTexture&&(n.metalnessMap=this.metalnessMap.toJSON(t).uuid),this.emissiveMap&&this.emissiveMap.isTexture&&(n.emissiveMap=this.emissiveMap.toJSON(t).uuid),this.specularMap&&this.specularMap.isTexture&&(n.specularMap=this.specularMap.toJSON(t).uuid),this.specularIntensityMap&&this.specularIntensityMap.isTexture&&(n.specularIntensityMap=this.specularIntensityMap.toJSON(t).uuid),this.specularColorMap&&this.specularColorMap.isTexture&&(n.specularColorMap=this.specularColorMap.toJSON(t).uuid),this.envMap&&this.envMap.isTexture&&(n.envMap=this.envMap.toJSON(t).uuid,this.combine!==void 0&&(n.combine=this.combine)),this.envMapRotation!==void 0&&(n.envMapRotation=this.envMapRotation.toArray()),this.envMapIntensity!==void 0&&(n.envMapIntensity=this.envMapIntensity),this.reflectivity!==void 0&&(n.reflectivity=this.reflectivity),this.refractionRatio!==void 0&&(n.refractionRatio=this.refractionRatio),this.gradientMap&&this.gradientMap.isTexture&&(n.gradientMap=this.gradientMap.toJSON(t).uuid),this.transmission!==void 0&&(n.transmission=this.transmission),this.transmissionMap&&this.transmissionMap.isTexture&&(n.transmissionMap=this.transmissionMap.toJSON(t).uuid),this.thickness!==void 0&&(n.thickness=this.thickness),this.thicknessMap&&this.thicknessMap.isTexture&&(n.thicknessMap=this.thicknessMap.toJSON(t).uuid),this.attenuationDistance!==void 0&&(n.attenuationDistance=this.attenuationDistance),this.attenuationColor!==void 0&&(n.attenuationColor=this.attenuationColor.getHex()),this.size!==void 0&&(n.size=this.size),this.sizeAttenuation!==void 0&&(n.sizeAttenuation=this.sizeAttenuation),Array.isArray(this.clippingPlanes)&&this.clippingPlanes.length>0&&(n.clippingPlanes=this.clippingPlanes.map(r=>r.toJSON())),this.rotation!==void 0&&(n.rotation=this.rotation),this.depthPacking!==void 0&&(n.depthPacking=this.depthPacking),this.linewidth!==void 0&&(n.linewidth=this.linewidth),this.linecap!==void 0&&(n.linecap=this.linecap),this.linejoin!==void 0&&(n.linejoin=this.linejoin),this.dashSize!==void 0&&(n.dashSize=this.dashSize),this.gapSize!==void 0&&(n.gapSize=this.gapSize),this.scale!==void 0&&(n.scale=this.scale),this.wireframe!==void 0&&(n.wireframe=this.wireframe),this.wireframeLinewidth!==void 0&&(n.wireframeLinewidth=this.wireframeLinewidth),this.wireframeLinecap!==void 0&&(n.wireframeLinecap=this.wireframeLinecap),this.wireframeLinejoin!==void 0&&(n.wireframeLinejoin=this.wireframeLinejoin),this.flatShading!==void 0&&(n.flatShading=this.flatShading),this.fog!==void 0&&(n.fog=this.fog),Object.keys(this.userData).length>0&&(n.userData=this.userData);function s(r){let a=[];for(let o in r){let c=r[o];delete c.metadata,a.push(c)}return a}if(e){let r=s(t.textures),a=s(t.images);r.length>0&&(n.textures=r),a.length>0&&(n.images=a)}return n}fromJSON(t,e){if(t.uuid!==void 0&&(this.uuid=t.uuid),t.name!==void 0&&(this.name=t.name),t.color!==void 0&&this.color!==void 0&&this.color.setHex(t.color),t.roughness!==void 0&&(this.roughness=t.roughness),t.metalness!==void 0&&(this.metalness=t.metalness),t.sheen!==void 0&&(this.sheen=t.sheen),t.sheenColor!==void 0&&(this.sheenColor=new oe().setHex(t.sheenColor)),t.sheenRoughness!==void 0&&(this.sheenRoughness=t.sheenRoughness),t.emissive!==void 0&&this.emissive!==void 0&&this.emissive.setHex(t.emissive),t.specular!==void 0&&this.specular!==void 0&&this.specular.setHex(t.specular),t.specularIntensity!==void 0&&(this.specularIntensity=t.specularIntensity),t.specularColor!==void 0&&this.specularColor!==void 0&&this.specularColor.setHex(t.specularColor),t.shininess!==void 0&&(this.shininess=t.shininess),t.clearcoat!==void 0&&(this.clearcoat=t.clearcoat),t.clearcoatRoughness!==void 0&&(this.clearcoatRoughness=t.clearcoatRoughness),t.dispersion!==void 0&&(this.dispersion=t.dispersion),t.retroreflectivity!==void 0&&(this.retroreflectivity=t.retroreflectivity),t.iridescence!==void 0&&(this.iridescence=t.iridescence),t.iridescenceIOR!==void 0&&(this.iridescenceIOR=t.iridescenceIOR),t.iridescenceThicknessRange!==void 0&&(this.iridescenceThicknessRange=t.iridescenceThicknessRange),t.transmission!==void 0&&(this.transmission=t.transmission),t.thickness!==void 0&&(this.thickness=t.thickness),t.attenuationDistance!==void 0&&(this.attenuationDistance=t.attenuationDistance),t.attenuationColor!==void 0&&this.attenuationColor!==void 0&&this.attenuationColor.setHex(t.attenuationColor),t.anisotropy!==void 0&&(this.anisotropy=t.anisotropy),t.anisotropyRotation!==void 0&&(this.anisotropyRotation=t.anisotropyRotation),t.fog!==void 0&&(this.fog=t.fog),t.flatShading!==void 0&&(this.flatShading=t.flatShading),t.blending!==void 0&&(this.blending=t.blending),t.combine!==void 0&&(this.combine=t.combine),t.side!==void 0&&(this.side=t.side),t.shadowSide!==void 0&&(this.shadowSide=t.shadowSide),t.opacity!==void 0&&(this.opacity=t.opacity),t.transparent!==void 0&&(this.transparent=t.transparent),t.alphaTest!==void 0&&(this.alphaTest=t.alphaTest),t.alphaHash!==void 0&&(this.alphaHash=t.alphaHash),t.depthFunc!==void 0&&(this.depthFunc=t.depthFunc),t.depthTest!==void 0&&(this.depthTest=t.depthTest),t.depthWrite!==void 0&&(this.depthWrite=t.depthWrite),t.colorWrite!==void 0&&(this.colorWrite=t.colorWrite),t.clippingPlanes!==void 0&&(this.clippingPlanes=t.clippingPlanes.map(n=>new ci().fromJSON(n))),t.clipIntersection!==void 0&&(this.clipIntersection=t.clipIntersection),t.clipShadows!==void 0&&(this.clipShadows=t.clipShadows),t.depthPacking!==void 0&&(this.depthPacking=t.depthPacking),t.blendSrc!==void 0&&(this.blendSrc=t.blendSrc),t.blendDst!==void 0&&(this.blendDst=t.blendDst),t.blendEquation!==void 0&&(this.blendEquation=t.blendEquation),t.blendSrcAlpha!==void 0&&(this.blendSrcAlpha=t.blendSrcAlpha),t.blendDstAlpha!==void 0&&(this.blendDstAlpha=t.blendDstAlpha),t.blendEquationAlpha!==void 0&&(this.blendEquationAlpha=t.blendEquationAlpha),t.blendColor!==void 0&&this.blendColor!==void 0&&this.blendColor.setHex(t.blendColor),t.blendAlpha!==void 0&&(this.blendAlpha=t.blendAlpha),t.stencilWriteMask!==void 0&&(this.stencilWriteMask=t.stencilWriteMask),t.stencilFunc!==void 0&&(this.stencilFunc=t.stencilFunc),t.stencilRef!==void 0&&(this.stencilRef=t.stencilRef),t.stencilFuncMask!==void 0&&(this.stencilFuncMask=t.stencilFuncMask),t.stencilFail!==void 0&&(this.stencilFail=t.stencilFail),t.stencilZFail!==void 0&&(this.stencilZFail=t.stencilZFail),t.stencilZPass!==void 0&&(this.stencilZPass=t.stencilZPass),t.stencilWrite!==void 0&&(this.stencilWrite=t.stencilWrite),t.wireframe!==void 0&&(this.wireframe=t.wireframe),t.wireframeLinewidth!==void 0&&(this.wireframeLinewidth=t.wireframeLinewidth),t.wireframeLinecap!==void 0&&(this.wireframeLinecap=t.wireframeLinecap),t.wireframeLinejoin!==void 0&&(this.wireframeLinejoin=t.wireframeLinejoin),t.rotation!==void 0&&(this.rotation=t.rotation),t.linewidth!==void 0&&(this.linewidth=t.linewidth),t.linecap!==void 0&&(this.linecap=t.linecap),t.linejoin!==void 0&&(this.linejoin=t.linejoin),t.dashSize!==void 0&&(this.dashSize=t.dashSize),t.gapSize!==void 0&&(this.gapSize=t.gapSize),t.scale!==void 0&&(this.scale=t.scale),t.polygonOffset!==void 0&&(this.polygonOffset=t.polygonOffset),t.polygonOffsetFactor!==void 0&&(this.polygonOffsetFactor=t.polygonOffsetFactor),t.polygonOffsetUnits!==void 0&&(this.polygonOffsetUnits=t.polygonOffsetUnits),t.dithering!==void 0&&(this.dithering=t.dithering),t.alphaToCoverage!==void 0&&(this.alphaToCoverage=t.alphaToCoverage),t.premultipliedAlpha!==void 0&&(this.premultipliedAlpha=t.premultipliedAlpha),t.forceSinglePass!==void 0&&(this.forceSinglePass=t.forceSinglePass),t.allowOverride!==void 0&&(this.allowOverride=t.allowOverride),t.visible!==void 0&&(this.visible=t.visible),t.toneMapped!==void 0&&(this.toneMapped=t.toneMapped),t.userData!==void 0&&(this.userData=t.userData),t.vertexColors!==void 0&&(typeof t.vertexColors=="number"?this.vertexColors=t.vertexColors>0:this.vertexColors=t.vertexColors),t.size!==void 0&&(this.size=t.size),t.sizeAttenuation!==void 0&&(this.sizeAttenuation=t.sizeAttenuation),t.map!==void 0&&(this.map=e[t.map]||null),t.matcap!==void 0&&(this.matcap=e[t.matcap]||null),t.alphaMap!==void 0&&(this.alphaMap=e[t.alphaMap]||null),t.bumpMap!==void 0&&(this.bumpMap=e[t.bumpMap]||null),t.bumpScale!==void 0&&(this.bumpScale=t.bumpScale),t.normalMap!==void 0&&(this.normalMap=e[t.normalMap]||null),t.normalMapType!==void 0&&(this.normalMapType=t.normalMapType),t.normalScale!==void 0){let n=t.normalScale;Array.isArray(n)===!1&&(n=[n,n]),this.normalScale=new yt().fromArray(n)}return t.displacementMap!==void 0&&(this.displacementMap=e[t.displacementMap]||null),t.displacementScale!==void 0&&(this.displacementScale=t.displacementScale),t.displacementBias!==void 0&&(this.displacementBias=t.displacementBias),t.roughnessMap!==void 0&&(this.roughnessMap=e[t.roughnessMap]||null),t.metalnessMap!==void 0&&(this.metalnessMap=e[t.metalnessMap]||null),t.emissiveMap!==void 0&&(this.emissiveMap=e[t.emissiveMap]||null),t.emissiveIntensity!==void 0&&(this.emissiveIntensity=t.emissiveIntensity),t.specularMap!==void 0&&(this.specularMap=e[t.specularMap]||null),t.specularIntensityMap!==void 0&&(this.specularIntensityMap=e[t.specularIntensityMap]||null),t.specularColorMap!==void 0&&(this.specularColorMap=e[t.specularColorMap]||null),t.envMap!==void 0&&(this.envMap=e[t.envMap]||null),t.envMapRotation!==void 0&&this.envMapRotation.fromArray(t.envMapRotation),t.envMapIntensity!==void 0&&(this.envMapIntensity=t.envMapIntensity),t.reflectivity!==void 0&&(this.reflectivity=t.reflectivity),t.refractionRatio!==void 0&&(this.refractionRatio=t.refractionRatio),t.lightMap!==void 0&&(this.lightMap=e[t.lightMap]||null),t.lightMapIntensity!==void 0&&(this.lightMapIntensity=t.lightMapIntensity),t.aoMap!==void 0&&(this.aoMap=e[t.aoMap]||null),t.aoMapIntensity!==void 0&&(this.aoMapIntensity=t.aoMapIntensity),t.gradientMap!==void 0&&(this.gradientMap=e[t.gradientMap]||null),t.clearcoatMap!==void 0&&(this.clearcoatMap=e[t.clearcoatMap]||null),t.clearcoatRoughnessMap!==void 0&&(this.clearcoatRoughnessMap=e[t.clearcoatRoughnessMap]||null),t.clearcoatNormalMap!==void 0&&(this.clearcoatNormalMap=e[t.clearcoatNormalMap]||null),t.clearcoatNormalScale!==void 0&&(this.clearcoatNormalScale=new yt().fromArray(t.clearcoatNormalScale)),t.iridescenceMap!==void 0&&(this.iridescenceMap=e[t.iridescenceMap]||null),t.iridescenceThicknessMap!==void 0&&(this.iridescenceThicknessMap=e[t.iridescenceThicknessMap]||null),t.transmissionMap!==void 0&&(this.transmissionMap=e[t.transmissionMap]||null),t.thicknessMap!==void 0&&(this.thicknessMap=e[t.thicknessMap]||null),t.anisotropyMap!==void 0&&(this.anisotropyMap=e[t.anisotropyMap]||null),t.sheenColorMap!==void 0&&(this.sheenColorMap=e[t.sheenColorMap]||null),t.sheenRoughnessMap!==void 0&&(this.sheenRoughnessMap=e[t.sheenRoughnessMap]||null),this}clone(){return new this.constructor().copy(this)}copy(t){this.name=t.name,this.blending=t.blending,this.side=t.side,this.vertexColors=t.vertexColors,this.opacity=t.opacity,this.transparent=t.transparent,this.blendSrc=t.blendSrc,this.blendDst=t.blendDst,this.blendEquation=t.blendEquation,this.blendSrcAlpha=t.blendSrcAlpha,this.blendDstAlpha=t.blendDstAlpha,this.blendEquationAlpha=t.blendEquationAlpha,this.blendColor.copy(t.blendColor),this.blendAlpha=t.blendAlpha,this.depthFunc=t.depthFunc,this.depthTest=t.depthTest,this.depthWrite=t.depthWrite,this.stencilWriteMask=t.stencilWriteMask,this.stencilFunc=t.stencilFunc,this.stencilRef=t.stencilRef,this.stencilFuncMask=t.stencilFuncMask,this.stencilFail=t.stencilFail,this.stencilZFail=t.stencilZFail,this.stencilZPass=t.stencilZPass,this.stencilWrite=t.stencilWrite;let e=t.clippingPlanes,n=null;if(e!==null){let s=e.length;n=new Array(s);for(let r=0;r!==s;++r)n[r]=e[r].clone()}return this.clippingPlanes=n,this.clipIntersection=t.clipIntersection,this.clipShadows=t.clipShadows,this.shadowSide=t.shadowSide,this.colorWrite=t.colorWrite,this.precision=t.precision,this.polygonOffset=t.polygonOffset,this.polygonOffsetFactor=t.polygonOffsetFactor,this.polygonOffsetUnits=t.polygonOffsetUnits,this.dithering=t.dithering,this.alphaTest=t.alphaTest,this.alphaHash=t.alphaHash,this.alphaToCoverage=t.alphaToCoverage,this.premultipliedAlpha=t.premultipliedAlpha,this.forceSinglePass=t.forceSinglePass,this.allowOverride=t.allowOverride,this.visible=t.visible,this.toneMapped=t.toneMapped,this.userData=JSON.parse(JSON.stringify(t.userData)),this}dispose(){this.dispatchEvent({type:"dispose"})}set needsUpdate(t){t===!0&&this.version++}},Gi=class extends ui{constructor(t){super(),this.isSpriteMaterial=!0,this.type="SpriteMaterial",this.color=new oe(16777215),this.map=null,this.alphaMap=null,this.rotation=0,this.sizeAttenuation=!0,this.transparent=!0,this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.color.copy(t.color),this.map=t.map,this.alphaMap=t.alphaMap,this.rotation=t.rotation,this.sizeAttenuation=t.sizeAttenuation,this.fog=t.fog,this}},Ks,Jr=new D,js=new D,Qs=new D,tr=new yt,Kr=new yt,Fd=new De,Ro=new D,jr=new D,Co=new D,Eu=new yt,E0=new yt,Tu=new yt,as=class extends cn{constructor(t=new Gi){if(super(),this.isSprite=!0,this.type="Sprite",Ks===void 0){Ks=new Le;let e=new Float32Array([-.5,-.5,0,0,0,.5,-.5,0,1,0,.5,.5,0,1,1,-.5,.5,0,0,1]),n=new fa(e,5);Ks.setIndex([0,1,2,0,2,3]),Ks.setAttribute("position",new pr(n,3,0,!1)),Ks.setAttribute("uv",new pr(n,2,3,!1))}this.geometry=Ks,this.material=t,this.center=new yt(.5,.5),this.count=1}intersectsFrustum(t){return t.intersectsSprite(this)}raycast(t,e){t.camera===null&&fe('Sprite: "Raycaster.camera" needs to be set in order to raycast against sprites.'),js.setFromMatrixScale(this.matrixWorld),Fd.copy(t.camera.matrixWorld),this.modelViewMatrix.multiplyMatrices(t.camera.matrixWorldInverse,this.matrixWorld),Qs.setFromMatrixPosition(this.modelViewMatrix),t.camera.isPerspectiveCamera&&this.material.sizeAttenuation===!1&&js.multiplyScalar(-Qs.z);let n=this.material.rotation,s,r;n!==0&&(r=Math.cos(n),s=Math.sin(n));let a=this.center;Io(Ro.set(-.5,-.5,0),Qs,a,js,s,r),Io(jr.set(.5,-.5,0),Qs,a,js,s,r),Io(Co.set(.5,.5,0),Qs,a,js,s,r),Eu.set(0,0),E0.set(1,0),Tu.set(1,1);let o=t.ray.intersectTriangle(Ro,jr,Co,!1,Jr);if(o===null&&(Io(jr.set(-.5,.5,0),Qs,a,js,s,r),E0.set(0,1),o=t.ray.intersectTriangle(Ro,Co,jr,!1,Jr),o===null))return;let c=t.ray.origin.distanceTo(Jr);c<t.near||c>t.far||e.push({distance:c,point:Jr.clone(),uv:zi.getInterpolation(Jr,Ro,jr,Co,Eu,E0,Tu,new yt),face:null,object:this})}copy(t,e){return super.copy(t,e),t.center!==void 0&&this.center.copy(t.center),this.material=t.material,this}};function Io(i,t,e,n,s,r){tr.subVectors(i,e).addScalar(.5).multiply(n),s!==void 0?(Kr.x=r*tr.x-s*tr.y,Kr.y=s*tr.x+r*tr.y):Kr.copy(tr),i.copy(t),i.x+=Kr.x,i.y+=Kr.y,i.applyMatrix4(Fd)}var Po=new D,Au=new D,pa=class extends cn{constructor(){super(),this.isLOD=!0,this._currentLevel=0,this.type="LOD",Object.defineProperties(this,{levels:{enumerable:!0,value:[]}}),this.autoUpdate=!0}copy(t){super.copy(t,!1);let e=t.levels;for(let n=0,s=e.length;n<s;n++){let r=e[n];this.addLevel(r.object.clone(),r.distance,r.hysteresis)}return this.autoUpdate=t.autoUpdate,this}addLevel(t,e=0,n=0){e=Math.abs(e);let s=this.levels,r;for(r=0;r<s.length&&!(e<s[r].distance);r++);return s.splice(r,0,{distance:e,hysteresis:n,object:t}),this.add(t),this}removeLevel(t){let e=this.levels;for(let n=0;n<e.length;n++)if(e[n].distance===t){let s=e.splice(n,1);return this.remove(s[0].object),!0}return!1}getCurrentLevel(){return this._currentLevel}getObjectForDistance(t){let e=this.levels;if(e.length>0){let n,s;for(n=1,s=e.length;n<s;n++){let r=e[n].distance;if(e[n].object.visible&&(r-=r*e[n].hysteresis),t<r)break}return e[n-1].object}return null}raycast(t,e){if(this.levels.length>0){Po.setFromMatrixPosition(this.matrixWorld);let s=t.ray.origin.distanceTo(Po);this.getObjectForDistance(s).raycast(t,e)}}update(t){let e=this.levels;if(e.length>1){Po.setFromMatrixPosition(t.matrixWorld),Au.setFromMatrixPosition(this.matrixWorld);let n=Po.distanceTo(Au)/t.zoom;e[0].object.visible=!0;let s,r;for(s=1,r=e.length;s<r;s++){let a=e[s].distance;if(e[s].object.visible&&(a-=a*e[s].hysteresis),n>=a)e[s-1].object.visible=!1,e[s].object.visible=!0;else break}for(this._currentLevel=s-1;s<r;s++)e[s].object.visible=!1}}toJSON(t){let e=super.toJSON(t);e.object.autoUpdate=this.autoUpdate,e.object.levels=[];let n=this.levels;for(let s=0,r=n.length;s<r;s++){let a=n[s];e.object.levels.push({object:a.object.uuid,distance:a.distance,hysteresis:a.hysteresis})}return e}},Bi=new D,T0=new D,Lo=new D,No=new D,Es=class{constructor(t=new D,e=new D(0,0,-1)){this.origin=t,this.direction=e}set(t,e){return this.origin.copy(t),this.direction.copy(e),this}copy(t){return this.origin.copy(t.origin),this.direction.copy(t.direction),this}at(t,e){return e.copy(this.origin).addScaledVector(this.direction,t)}lookAt(t){return this.direction.copy(t).sub(this.origin).normalize(),this}recast(t){return this.origin.copy(this.at(t,Bi)),this}closestPointToPoint(t,e){e.subVectors(t,this.origin);let n=e.dot(this.direction);return n<0?e.copy(this.origin):e.copy(this.origin).addScaledVector(this.direction,n)}distanceToPoint(t){return Math.sqrt(this.distanceSqToPoint(t))}distanceSqToPoint(t){let e=Bi.subVectors(t,this.origin).dot(this.direction);return e<0?this.origin.distanceToSquared(t):(Bi.copy(this.origin).addScaledVector(this.direction,e),Bi.distanceToSquared(t))}distanceSqToSegment(t,e,n,s){T0.copy(t).add(e).multiplyScalar(.5),Lo.copy(e).sub(t).normalize(),No.copy(this.origin).sub(T0);let r=t.distanceTo(e)*.5,a=-this.direction.dot(Lo),o=No.dot(this.direction),c=-No.dot(Lo),l=No.lengthSq(),h=Math.abs(1-a*a),f,u,d,m;if(h>0)if(f=a*c-o,u=a*o-c,m=r*h,f>=0)if(u>=-m)if(u<=m){let x=1/h;f*=x,u*=x,d=f*(f+a*u+2*o)+u*(a*f+u+2*c)+l}else u=r,f=Math.max(0,-(a*u+o)),d=-f*f+u*(u+2*c)+l;else u=-r,f=Math.max(0,-(a*u+o)),d=-f*f+u*(u+2*c)+l;else u<=-m?(f=Math.max(0,-(-a*r+o)),u=f>0?-r:Math.min(Math.max(-r,-c),r),d=-f*f+u*(u+2*c)+l):u<=m?(f=0,u=Math.min(Math.max(-r,-c),r),d=u*(u+2*c)+l):(f=Math.max(0,-(a*r+o)),u=f>0?r:Math.min(Math.max(-r,-c),r),d=-f*f+u*(u+2*c)+l);else u=a>0?-r:r,f=Math.max(0,-(a*u+o)),d=-f*f+u*(u+2*c)+l;return n&&n.copy(this.origin).addScaledVector(this.direction,f),s&&s.copy(T0).addScaledVector(Lo,u),d}intersectSphere(t,e){if(t.radius<0)return null;Bi.subVectors(t.center,this.origin);let n=Bi.dot(this.direction),s=Bi.dot(Bi)-n*n,r=t.radius*t.radius;if(s>r)return null;let a=Math.sqrt(r-s),o=n-a,c=n+a;return c<0?null:o<0?this.at(c,e):this.at(o,e)}intersectsSphere(t){return t.radius<0?!1:this.distanceSqToPoint(t.center)<=t.radius*t.radius}distanceToPlane(t){let e=t.normal.dot(this.direction);if(e===0)return t.distanceToPoint(this.origin)===0?0:null;let n=-(this.origin.dot(t.normal)+t.constant)/e;return n>=0?n:null}intersectPlane(t,e){let n=this.distanceToPlane(t);return n===null?null:this.at(n,e)}intersectsPlane(t){let e=t.distanceToPoint(this.origin);return e===0||t.normal.dot(this.direction)*e<0}intersectBox(t,e){let n,s,r,a,o,c,l=1/this.direction.x,h=1/this.direction.y,f=1/this.direction.z,u=this.origin;return l>=0?(n=(t.min.x-u.x)*l,s=(t.max.x-u.x)*l):(n=(t.max.x-u.x)*l,s=(t.min.x-u.x)*l),h>=0?(r=(t.min.y-u.y)*h,a=(t.max.y-u.y)*h):(r=(t.max.y-u.y)*h,a=(t.min.y-u.y)*h),n>a||r>s||((r>n||isNaN(n))&&(n=r),(a<s||isNaN(s))&&(s=a),f>=0?(o=(t.min.z-u.z)*f,c=(t.max.z-u.z)*f):(o=(t.max.z-u.z)*f,c=(t.min.z-u.z)*f),n>c||o>s)||((o>n||n!==n)&&(n=o),(c<s||s!==s)&&(s=c),s<0)?null:this.at(n>=0?n:s,e)}intersectsBox(t){return this.intersectBox(t,Bi)!==null}intersectTriangle(t,e,n,s,r){let a=this.origin,o=this.direction,c=o.x,l=o.y,h=o.z,f=t.x-a.x,u=t.y-a.y,d=t.z-a.z,m=e.x-a.x,x=e.y-a.y,g=e.z-a.z,p=n.x-a.x,b=n.y-a.y,E=n.z-a.z,y=Math.abs(c),w=Math.abs(l),S=Math.abs(h),C,v,R,I,N,L,O,P,W,it,Q,ht;if(y>=w&&y>=S?(R=c,L=f,W=m,ht=p,c>=0?(C=l,v=h,I=u,N=d,O=x,P=g,it=b,Q=E):(C=h,v=l,I=d,N=u,O=g,P=x,it=E,Q=b)):w>=S?(R=l,L=u,W=x,ht=b,l>=0?(C=h,v=c,I=d,N=f,O=g,P=m,it=E,Q=p):(C=c,v=h,I=f,N=d,O=m,P=g,it=p,Q=E)):(R=h,L=d,W=g,ht=E,h>=0?(C=c,v=l,I=f,N=u,O=m,P=x,it=p,Q=b):(C=l,v=c,I=u,N=f,O=x,P=m,it=b,Q=p)),R===0)return null;let K=C/R,ot=v/R,z=1/R,Mt=I-K*L,vt=N-ot*L,Et=O-K*W,Ot=P-ot*W,Lt=it-K*ht,et=Q-ot*ht,nt=Lt*Ot-et*Et,_t=Mt*et-vt*Lt,wt=Et*vt-Ot*Mt;if(s){if(nt<0||_t<0||wt<0)return null}else if((nt<0||_t<0||wt<0)&&(nt>0||_t>0||wt>0))return null;let pt=nt+_t+wt;if(pt===0)return null;let It=z*(nt*L+_t*W+wt*ht);return(pt>0?It<0:It>0)?null:this.at(It/pt,r)}applyMatrix4(t){return this.origin.applyMatrix4(t),this.direction.transformDirection(t),this}equals(t){return t.origin.equals(this.origin)&&t.direction.equals(this.direction)}clone(){return new this.constructor().copy(this)}},hn=class extends ui{constructor(t){super(),this.isMeshBasicMaterial=!0,this.type="MeshBasicMaterial",this.color=new oe(16777215),this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.specularMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new Vi,this.combine=j0,this.reflectivity=1,this.refractionRatio=.98,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.color.copy(t.color),this.map=t.map,this.lightMap=t.lightMap,this.lightMapIntensity=t.lightMapIntensity,this.aoMap=t.aoMap,this.aoMapIntensity=t.aoMapIntensity,this.specularMap=t.specularMap,this.alphaMap=t.alphaMap,this.envMap=t.envMap,this.envMapRotation.copy(t.envMapRotation),this.combine=t.combine,this.reflectivity=t.reflectivity,this.refractionRatio=t.refractionRatio,this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this.wireframeLinecap=t.wireframeLinecap,this.wireframeLinejoin=t.wireframeLinejoin,this.fog=t.fog,this}},Ru=new De,bs=new Es,Do=new Jn,Cu=new D,Uo=new D,Fo=new D,Oo=new D,A0=new D,Bo=new D,Iu=new D,zo=new D,we=class extends cn{constructor(t=new Le,e=new hn){super(),this.isMesh=!0,this.type="Mesh",this.geometry=t,this.material=e,this.morphTargetDictionary=void 0,this.morphTargetInfluences=void 0,this.count=1,this.updateMorphTargets()}copy(t,e){return super.copy(t,e),t.morphTargetInfluences!==void 0&&(this.morphTargetInfluences=t.morphTargetInfluences.slice()),t.morphTargetDictionary!==void 0&&(this.morphTargetDictionary=Object.assign({},t.morphTargetDictionary)),this.material=Array.isArray(t.material)?t.material.slice():t.material,this.geometry=t.geometry,this}updateMorphTargets(){let e=this.geometry.morphAttributes,n=Object.keys(e);if(n.length>0){let s=e[n[0]];if(s!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let r=0,a=s.length;r<a;r++){let o=s[r].name||String(r);this.morphTargetInfluences.push(0),this.morphTargetDictionary[o]=r}}}}getVertexPosition(t,e){let n=this.geometry,s=n.attributes.position,r=n.morphAttributes.position,a=n.morphTargetsRelative;e.fromBufferAttribute(s,t);let o=this.morphTargetInfluences;if(r&&o){Bo.set(0,0,0);for(let c=0,l=r.length;c<l;c++){let h=o[c],f=r[c];h!==0&&(A0.fromBufferAttribute(f,t),a?Bo.addScaledVector(A0,h):Bo.addScaledVector(A0.sub(e),h))}e.add(Bo)}return e}intersectsFrustum(t){return t.intersectsObject(this)}raycast(t,e){let n=this.geometry,s=this.material,r=this.matrixWorld;s!==void 0&&(n.boundingSphere===null&&n.computeBoundingSphere(),Do.copy(n.boundingSphere),Do.applyMatrix4(r),bs.copy(t.ray).recast(t.near),!(Do.containsPoint(bs.origin)===!1&&(bs.intersectSphere(Do,Cu)===null||bs.origin.distanceToSquared(Cu)>(t.far-t.near)**2))&&(Ru.copy(r).invert(),bs.copy(t.ray).applyMatrix4(Ru),!(n.boundingBox!==null&&bs.intersectsBox(n.boundingBox)===!1)&&this._computeIntersections(t,e,bs)))}_computeIntersections(t,e,n){let s,r=this.geometry,a=this.material,o=r.index,c=r.attributes.position,l=r.attributes.uv,h=r.attributes.uv1,f=r.attributes.normal,u=r.groups,d=r.drawRange;if(o!==null)if(Array.isArray(a))for(let m=0,x=u.length;m<x;m++){let g=u[m],p=a[g.materialIndex],b=Math.max(g.start,d.start),E=Math.min(o.count,Math.min(g.start+g.count,d.start+d.count));for(let y=b,w=E;y<w;y+=3){let S=o.getX(y),C=o.getX(y+1),v=o.getX(y+2);s=ko(this,p,t,n,l,h,f,S,C,v),s&&(s.faceIndex=Math.floor(y/3),s.face.materialIndex=g.materialIndex,e.push(s))}}else{let m=Math.max(0,d.start),x=Math.min(o.count,d.start+d.count);for(let g=m,p=x;g<p;g+=3){let b=o.getX(g),E=o.getX(g+1),y=o.getX(g+2);s=ko(this,a,t,n,l,h,f,b,E,y),s&&(s.faceIndex=Math.floor(g/3),e.push(s))}}else if(c!==void 0)if(Array.isArray(a))for(let m=0,x=u.length;m<x;m++){let g=u[m],p=a[g.materialIndex],b=Math.max(g.start,d.start),E=Math.min(c.count,Math.min(g.start+g.count,d.start+d.count));for(let y=b,w=E;y<w;y+=3){let S=y,C=y+1,v=y+2;s=ko(this,p,t,n,l,h,f,S,C,v),s&&(s.faceIndex=Math.floor(y/3),s.face.materialIndex=g.materialIndex,e.push(s))}}else{let m=Math.max(0,d.start),x=Math.min(c.count,d.start+d.count);for(let g=m,p=x;g<p;g+=3){let b=g,E=g+1,y=g+2;s=ko(this,a,t,n,l,h,f,b,E,y),s&&(s.faceIndex=Math.floor(g/3),e.push(s))}}}};function Np(i,t,e,n,s,r,a,o){let c;if(t.side===Rn?c=n.intersectTriangle(a,r,s,!0,o):c=n.intersectTriangle(s,r,a,t.side===fs,o),c===null)return null;zo.copy(o),zo.applyMatrix4(i.matrixWorld);let l=e.ray.origin.distanceTo(zo);return l<e.near||l>e.far?null:{distance:l,point:zo.clone(),object:i}}function ko(i,t,e,n,s,r,a,o,c,l){i.getVertexPosition(o,Uo),i.getVertexPosition(c,Fo),i.getVertexPosition(l,Oo);let h=Np(i,t,e,n,Uo,Fo,Oo,Iu);if(h){let f=new D;zi.getBarycoord(Iu,Uo,Fo,Oo,f),s&&(h.uv=zi.getInterpolatedAttribute(s,o,c,l,f,new yt)),r&&(h.uv1=zi.getInterpolatedAttribute(r,o,c,l,f,new yt)),a&&(h.normal=zi.getInterpolatedAttribute(a,o,c,l,f,new D),h.normal.dot(n.direction)>0&&h.normal.multiplyScalar(-1));let u={a:o,b:c,c:l,normal:new D,materialIndex:0};zi.getNormal(Uo,Fo,Oo,u.normal),h.face=u,h.barycoord=f}return h}var ma=class extends Sn{constructor(t=null,e=1,n=1,s,r,a,o,c,l=bn,h=bn,f,u){super(null,a,o,c,l,h,s,r,f,u),this.isDataTexture=!0,this.image={data:t,width:e,height:n},this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}};var mr=class extends ln{constructor(t,e,n,s=1){super(t,e,n),this.isInstancedBufferAttribute=!0,this.meshPerAttribute=s}copy(t){return super.copy(t),this.meshPerAttribute=t.meshPerAttribute,this}toJSON(){let t=super.toJSON();return t.meshPerAttribute=this.meshPerAttribute,t.isInstancedBufferAttribute=!0,t}},er=new De,Pu=new De,Ho=[],Lu=new Ei,Dp=new De,Qr=new we,ta=new Jn,ga=class extends we{constructor(t,e,n){super(t,e),this.isInstancedMesh=!0,this.instanceMatrix=new mr(new Float32Array(n*16),16),this.instanceColor=null,this.morphTexture=null,this.count=n,this.boundingBox=null,this.boundingSphere=null;for(let s=0;s<n;s++)this.setMatrixAt(s,Dp)}computeBoundingBox(){let t=this.geometry,e=this.count;this.boundingBox===null&&(this.boundingBox=new Ei),t.boundingBox===null&&t.computeBoundingBox(),this.boundingBox.makeEmpty();for(let n=0;n<e;n++)this.getMatrixAt(n,er),Lu.copy(t.boundingBox).applyMatrix4(er),this.boundingBox.union(Lu)}computeBoundingSphere(){let t=this.geometry,e=this.count;this.boundingSphere===null&&(this.boundingSphere=new Jn),t.boundingSphere===null&&t.computeBoundingSphere(),this.boundingSphere.makeEmpty();for(let n=0;n<e;n++)this.getMatrixAt(n,er),ta.copy(t.boundingSphere).applyMatrix4(er),this.boundingSphere.union(ta)}copy(t,e){return super.copy(t,e),this.instanceMatrix.copy(t.instanceMatrix),t.morphTexture!==null&&(this.morphTexture=t.morphTexture.clone()),t.instanceColor!==null&&(this.instanceColor=t.instanceColor.clone()),this.count=t.count,t.boundingBox!==null&&(this.boundingBox=t.boundingBox.clone()),t.boundingSphere!==null&&(this.boundingSphere=t.boundingSphere.clone()),this}getColorAt(t,e){return this.instanceColor===null?e.setRGB(1,1,1):e.fromArray(this.instanceColor.array,t*3)}getMatrixAt(t,e){return e.fromArray(this.instanceMatrix.array,t*16)}getMorphAt(t,e){let n=e.morphTargetInfluences,s=this.morphTexture.source.data.data,r=n.length+1,a=t*r+1;for(let o=0;o<n.length;o++)n[o]=s[a+o]}raycast(t,e){let n=this.matrixWorld,s=this.count;if(Qr.geometry=this.geometry,Qr.material=this.material,Qr.material!==void 0&&(this.boundingSphere===null&&this.computeBoundingSphere(),ta.copy(this.boundingSphere),ta.applyMatrix4(n),t.ray.intersectsSphere(ta)!==!1))for(let r=0;r<s;r++){this.getMatrixAt(r,er),Pu.multiplyMatrices(n,er),Qr.matrixWorld=Pu,Qr.raycast(t,Ho);for(let a=0,o=Ho.length;a<o;a++){let c=Ho[a];c.instanceId=r,c.object=this,e.push(c)}Ho.length=0}}setColorAt(t,e){return this.instanceColor===null&&(this.instanceColor=new mr(new Float32Array(this.instanceMatrix.count*3).fill(1),3)),e.toArray(this.instanceColor.array,t*3),this}setMatrixAt(t,e){return e.toArray(this.instanceMatrix.array,t*16),this}setMorphAt(t,e){let n=e.morphTargetInfluences,s=n.length+1;this.morphTexture===null&&(this.morphTexture=new ma(new Float32Array(s*this.count),s,this.count,Hl,ti));let r=this.morphTexture.source.data.data,a=0;for(let l=0;l<n.length;l++)a+=n[l];let o=this.geometry.morphTargetsRelative?1:1-a,c=s*t;return r[c]=o,r.set(n,c+1),this}updateMorphTargets(){}dispose(){super.dispose(),this.morphTexture!==null&&(this.morphTexture.dispose(),this.morphTexture=null)}},Ss=new Jn,Up=new yt(.5,.5),Vo=new D,gr=class{constructor(t=new ci,e=new ci,n=new ci,s=new ci,r=new ci,a=new ci){this.planes=[t,e,n,s,r,a]}set(t,e,n,s,r,a){let o=this.planes;return o[0].copy(t),o[1].copy(e),o[2].copy(n),o[3].copy(s),o[4].copy(r),o[5].copy(a),this}copy(t){let e=this.planes;for(let n=0;n<6;n++)e[n].copy(t.planes[n]);return this}setFromProjectionMatrix(t,e=hi,n=!1){let s=this.planes,r=t.elements,a=r[0],o=r[1],c=r[2],l=r[3],h=r[4],f=r[5],u=r[6],d=r[7],m=r[8],x=r[9],g=r[10],p=r[11],b=r[12],E=r[13],y=r[14],w=r[15];if(s[0].setComponents(l-a,d-h,p-m,w-b).normalize(),s[1].setComponents(l+a,d+h,p+m,w+b).normalize(),s[2].setComponents(l+o,d+f,p+x,w+E).normalize(),s[3].setComponents(l-o,d-f,p-x,w-E).normalize(),n)s[4].setComponents(c,u,g,y).normalize(),s[5].setComponents(l-c,d-u,p-g,w-y).normalize();else if(s[4].setComponents(l-c,d-u,p-g,w-y).normalize(),e===hi)s[5].setComponents(l+c,d+u,p+g,w+y).normalize();else if(e===lr)s[5].setComponents(c,u,g,y).normalize();else throw new Error("THREE.Frustum.setFromProjectionMatrix(): Invalid coordinate system: "+e);return this}intersectsObject(t){if(t.boundingSphere!==void 0)t.boundingSphere===null&&t.computeBoundingSphere(),Ss.copy(t.boundingSphere).applyMatrix4(t.matrixWorld);else{let e=t.geometry;e.boundingSphere===null&&e.computeBoundingSphere(),Ss.copy(e.boundingSphere).applyMatrix4(t.matrixWorld)}return this.intersectsSphere(Ss)}intersectsSprite(t){Ss.center.set(0,0,0);let e=Up.distanceTo(t.center);return Ss.radius=.7071067811865476+e,Ss.applyMatrix4(t.matrixWorld),this.intersectsSphere(Ss)}intersectsSphere(t){let e=this.planes,n=t.center,s=-t.radius;for(let r=0;r<6;r++)if(e[r].distanceToPoint(n)<s)return!1;return!0}intersectsBox(t){let e=this.planes;for(let n=0;n<6;n++){let s=e[n];if(Vo.x=s.normal.x>0?t.max.x:t.min.x,Vo.y=s.normal.y>0?t.max.y:t.min.y,Vo.z=s.normal.z>0?t.max.z:t.min.z,s.distanceToPoint(Vo)<0)return!1}return!0}containsPoint(t){let e=this.planes;for(let n=0;n<6;n++)if(e[n].distanceToPoint(t)<0)return!1;return!0}clone(){return new this.constructor().copy(this)}};var di=class extends ui{constructor(t){super(),this.isLineBasicMaterial=!0,this.type="LineBasicMaterial",this.color=new oe(16777215),this.map=null,this.linewidth=1,this.linecap="round",this.linejoin="round",this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.color.copy(t.color),this.map=t.map,this.linewidth=t.linewidth,this.linecap=t.linecap,this.linejoin=t.linejoin,this.fog=t.fog,this}},fl=new D,pl=new D,Nu=new De,ea=new Es,Go=new Jn,R0=new D,Du=new D,Wi=class extends cn{constructor(t=new Le,e=new di){super(),this.isLine=!0,this.type="Line",this.geometry=t,this.material=e,this.morphTargetDictionary=void 0,this.morphTargetInfluences=void 0,this.updateMorphTargets()}copy(t,e){return super.copy(t,e),this.material=Array.isArray(t.material)?t.material.slice():t.material,this.geometry=t.geometry,this}computeLineDistances(){let t=this.geometry;if(t.index===null){let e=t.attributes.position,n=[0];for(let s=1,r=e.count;s<r;s++)fl.fromBufferAttribute(e,s-1),pl.fromBufferAttribute(e,s),n[s]=n[s-1],n[s]+=fl.distanceTo(pl);t.setAttribute("lineDistance",new ge(n,1))}else pe("Line.computeLineDistances(): Computation only possible with non-indexed BufferGeometry.");return this}intersectsFrustum(t){return t.intersectsObject(this)}raycast(t,e){let n=this.geometry,s=this.matrixWorld,r=t.params.Line.threshold,a=n.drawRange;if(n.boundingSphere===null&&n.computeBoundingSphere(),Go.copy(n.boundingSphere),Go.applyMatrix4(s),Go.radius+=r,t.ray.intersectsSphere(Go)===!1)return;Nu.copy(s).invert(),ea.copy(t.ray).applyMatrix4(Nu);let o=r/((this.scale.x+this.scale.y+this.scale.z)/3),c=o*o,l=this.isLineSegments?2:1,h=n.index,u=n.attributes.position;if(h!==null){let d=Math.max(0,a.start),m=Math.min(h.count,a.start+a.count);for(let x=d,g=m-1;x<g;x+=l){let p=h.getX(x),b=h.getX(x+1),E=Wo(this,t,ea,c,p,b,x);E&&e.push(E)}if(this.isLineLoop){let x=h.getX(m-1),g=h.getX(d),p=Wo(this,t,ea,c,x,g,m-1);p&&e.push(p)}}else{let d=Math.max(0,a.start),m=Math.min(u.count,a.start+a.count);for(let x=d,g=m-1;x<g;x+=l){let p=Wo(this,t,ea,c,x,x+1,x);p&&e.push(p)}if(this.isLineLoop){let x=Wo(this,t,ea,c,m-1,d,m-1);x&&e.push(x)}}}updateMorphTargets(){let e=this.geometry.morphAttributes,n=Object.keys(e);if(n.length>0){let s=e[n[0]];if(s!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let r=0,a=s.length;r<a;r++){let o=s[r].name||String(r);this.morphTargetInfluences.push(0),this.morphTargetDictionary[o]=r}}}}};function Wo(i,t,e,n,s,r,a){let o=i.geometry.attributes.position;if(fl.fromBufferAttribute(o,s),pl.fromBufferAttribute(o,r),e.distanceSqToSegment(fl,pl,R0,Du)>n)return;R0.applyMatrix4(i.matrixWorld);let l=t.ray.origin.distanceTo(R0);if(!(l<t.near||l>t.far))return{distance:l,point:Du.clone().applyMatrix4(i.matrixWorld),index:a,face:null,faceIndex:null,barycoord:null,object:i}}var ml=class extends ui{constructor(t){super(),this.isPointsMaterial=!0,this.type="PointsMaterial",this.color=new oe(16777215),this.map=null,this.alphaMap=null,this.size=1,this.sizeAttenuation=!0,this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.color.copy(t.color),this.map=t.map,this.alphaMap=t.alphaMap,this.size=t.size,this.sizeAttenuation=t.sizeAttenuation,this.fog=t.fog,this}},Uu=new De,B0=new Es,Xo=new Jn,$o=new D,xa=class extends cn{constructor(t=new Le,e=new ml){super(),this.isPoints=!0,this.type="Points",this.geometry=t,this.material=e,this.morphTargetDictionary=void 0,this.morphTargetInfluences=void 0,this.updateMorphTargets()}copy(t,e){return super.copy(t,e),this.material=Array.isArray(t.material)?t.material.slice():t.material,this.geometry=t.geometry,this}intersectsFrustum(t){return t.intersectsObject(this)}raycast(t,e){let n=this.geometry,s=this.matrixWorld,r=t.params.Points.threshold,a=n.drawRange;if(n.boundingSphere===null&&n.computeBoundingSphere(),Xo.copy(n.boundingSphere),Xo.applyMatrix4(s),Xo.radius+=r,t.ray.intersectsSphere(Xo)===!1)return;Uu.copy(s).invert(),B0.copy(t.ray).applyMatrix4(Uu);let o=r/((this.scale.x+this.scale.y+this.scale.z)/3),c=o*o,l=n.index,f=n.attributes.position;if(l!==null){let u=Math.max(0,a.start),d=Math.min(l.count,a.start+a.count);for(let m=u,x=d;m<x;m++){let g=l.getX(m);$o.fromBufferAttribute(f,g),Fu($o,g,c,s,t,e,this)}}else{let u=Math.max(0,a.start),d=Math.min(f.count,a.start+a.count);for(let m=u,x=d;m<x;m++)$o.fromBufferAttribute(f,m),Fu($o,m,c,s,t,e,this)}}updateMorphTargets(){let e=this.geometry.morphAttributes,n=Object.keys(e);if(n.length>0){let s=e[n[0]];if(s!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let r=0,a=s.length;r<a;r++){let o=s[r].name||String(r);this.morphTargetInfluences.push(0),this.morphTargetDictionary[o]=r}}}}};function Fu(i,t,e,n,s,r,a){let o=B0.distanceSqToPoint(i);if(o<e){let c=new D;B0.closestPointToPoint(i,c),c.applyMatrix4(n);let l=s.ray.origin.distanceTo(c);if(l<s.near||l>s.far)return;r.push({distance:l,distanceToRay:Math.sqrt(o),point:c,index:t,face:null,faceIndex:null,barycoord:null,object:a})}}var _a=class extends Sn{constructor(t=[],e=ms,n,s,r,a,o,c,l,h){super(t,e,n,s,r,a,o,c,l,h),this.isCubeTexture=!0,this.flipY=!1}get images(){return this.image}set images(t){this.image=t}},Kn=class extends Sn{constructor(t,e,n,s,r,a,o,c,l){super(t,e,n,s,r,a,o,c,l),this.isCanvasTexture=!0,this.needsUpdate=!0}};var os=class extends Sn{constructor(t,e,n=pi,s,r,a,o=bn,c=bn,l,h=bi,f=1){if(h!==bi&&h!==gs)throw new Error("THREE.DepthTexture: format must be either THREE.DepthFormat or THREE.DepthStencilFormat");let u={width:t,height:e,depth:f};super(u,s,r,a,o,c,h,n,l),this.isDepthTexture=!0,this.flipY=!1,this.generateMipmaps=!1,this.compareFunction=null}copy(t){return super.copy(t),this.source=new ur(Object.assign({},t.image)),this.compareFunction=t.compareFunction,this}toJSON(t){let e=super.toJSON(t);return e.compareFunction=this.compareFunction,e}},gl=class extends os{constructor(t,e=pi,n=ms,s,r,a=bn,o=bn,c,l=bi){let h={width:t,height:t,depth:1},f=[h,h,h,h,h,h];super(t,t,e,n,s,r,a,o,c,l),this.image=f,this.isCubeDepthTexture=!0,this.isCubeTexture=!0}get images(){return this.image}set images(t){this.image=t}},va=class extends Sn{constructor(t=null){super(),this.sourceTexture=t,this.isExternalTexture=!0}copy(t){return super.copy(t),this.sourceTexture=t.sourceTexture,this}},xr=class i extends Le{constructor(t=1,e=1,n=1,s=1,r=1,a=1){super(),this.type="BoxGeometry",this.parameters={width:t,height:e,depth:n,widthSegments:s,heightSegments:r,depthSegments:a};let o=this;s=Math.floor(s),r=Math.floor(r),a=Math.floor(a);let c=[],l=[],h=[],f=[],u=0,d=0;m("z","y","x",-1,-1,n,e,t,a,r,0),m("z","y","x",1,-1,n,e,-t,a,r,1),m("x","z","y",1,1,t,n,e,s,a,2),m("x","z","y",1,-1,t,n,-e,s,a,3),m("x","y","z",1,-1,t,e,n,s,r,4),m("x","y","z",-1,-1,t,e,-n,s,r,5),this.setIndex(c),this.setAttribute("position",new ge(l,3)),this.setAttribute("normal",new ge(h,3)),this.setAttribute("uv",new ge(f,2));function m(x,g,p,b,E,y,w,S,C,v,R){let I=y/C,N=w/v,L=y/2,O=w/2,P=S/2,W=C+1,it=v+1,Q=0,ht=0,K=new D;for(let ot=0;ot<it;ot++){let z=ot*N-O;for(let Mt=0;Mt<W;Mt++){let vt=Mt*I-L;K[x]=vt*b,K[g]=z*E,K[p]=P,l.push(K.x,K.y,K.z),K[x]=0,K[g]=0,K[p]=S>0?1:-1,h.push(K.x,K.y,K.z),f.push(Mt/C),f.push(1-ot/v),Q+=1}}for(let ot=0;ot<v;ot++)for(let z=0;z<C;z++){let Mt=u+z+W*ot,vt=u+z+W*(ot+1),Et=u+(z+1)+W*(ot+1),Ot=u+(z+1)+W*ot;c.push(Mt,vt,Ot),c.push(vt,Et,Ot),ht+=6}o.addGroup(d,ht,R),d+=ht,u+=Q}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.width,t.height,t.depth,t.widthSegments,t.heightSegments,t.depthSegments)}};var ya=class i extends Le{constructor(t=1,e=32,n=0,s=Math.PI*2){super(),this.type="CircleGeometry",this.parameters={radius:t,segments:e,thetaStart:n,thetaLength:s},e=Math.max(3,e);let r=[],a=[],o=[],c=[],l=new D,h=new yt;a.push(0,0,0),o.push(0,0,1),c.push(.5,.5);for(let f=0,u=3;f<=e;f++,u+=3){let d=n+f/e*s;l.x=t*Math.cos(d),l.y=t*Math.sin(d),a.push(l.x,l.y,l.z),o.push(0,0,1),h.x=(a[u]/t+1)/2,h.y=(a[u+1]/t+1)/2,c.push(h.x,h.y)}for(let f=1;f<=e;f++)r.push(f,f+1,0);this.setIndex(r),this.setAttribute("position",new ge(a,3)),this.setAttribute("normal",new ge(o,3)),this.setAttribute("uv",new ge(c,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.radius,t.segments,t.thetaStart,t.thetaLength)}},Xi=class i extends Le{constructor(t=1,e=1,n=1,s=32,r=1,a=!1,o=0,c=Math.PI*2){super(),this.type="CylinderGeometry",this.parameters={radiusTop:t,radiusBottom:e,height:n,radialSegments:s,heightSegments:r,openEnded:a,thetaStart:o,thetaLength:c};let l=this;s=Math.floor(s),r=Math.floor(r);let h=[],f=[],u=[],d=[],m=0,x=[],g=n/2,p=0;b(),a===!1&&(t>0&&E(!0),e>0&&E(!1)),this.setIndex(h),this.setAttribute("position",new ge(f,3)),this.setAttribute("normal",new ge(u,3)),this.setAttribute("uv",new ge(d,2));function b(){let y=new D,w=new D,S=0,C=(e-t)/n;for(let v=0;v<=r;v++){let R=[],I=v/r,N=I*(e-t)+t;for(let L=0;L<=s;L++){let O=L/s,P=O*c+o,W=Math.sin(P),it=Math.cos(P);w.x=N*W,w.y=-I*n+g,w.z=N*it,f.push(w.x,w.y,w.z),y.set(W,C,it).normalize(),u.push(y.x,y.y,y.z),d.push(O,1-I),R.push(m++)}x.push(R)}for(let v=0;v<s;v++)for(let R=0;R<r;R++){let I=x[R][v],N=x[R+1][v],L=x[R+1][v+1],O=x[R][v+1];(t>0||R!==0)&&(h.push(I,N,O),S+=3),(e>0||R!==r-1)&&(h.push(N,L,O),S+=3)}l.addGroup(p,S,0),p+=S}function E(y){let w=m,S=new yt,C=new D,v=0,R=y===!0?t:e,I=y===!0?1:-1;for(let L=1;L<=s;L++)f.push(0,g*I,0),u.push(0,I,0),d.push(.5,.5),m++;let N=m;for(let L=0;L<=s;L++){let P=L/s*c+o,W=Math.cos(P),it=Math.sin(P);C.x=R*it,C.y=g*I,C.z=R*W,f.push(C.x,C.y,C.z),u.push(0,I,0),S.x=W*.5+.5,S.y=it*.5*I+.5,d.push(S.x,S.y),m++}for(let L=0;L<s;L++){let O=w+L,P=N+L;y===!0?h.push(P,P+1,O):h.push(P+1,P,O),v+=3}l.addGroup(p,v,y===!0?1:2),p+=v}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.radiusTop,t.radiusBottom,t.height,t.radialSegments,t.heightSegments,t.openEnded,t.thetaStart,t.thetaLength)}},Ma=class i extends Xi{constructor(t=1,e=1,n=32,s=1,r=!1,a=0,o=Math.PI*2){super(0,t,e,n,s,r,a,o),this.type="ConeGeometry",this.parameters={radius:t,height:e,radialSegments:n,heightSegments:s,openEnded:r,thetaStart:a,thetaLength:o}}static fromJSON(t){return new i(t.radius,t.height,t.radialSegments,t.heightSegments,t.openEnded,t.thetaStart,t.thetaLength)}};var Xn=class{constructor(){this.type="Curve",this.arcLengthDivisions=200,this.needsUpdate=!1,this.cacheArcLengths=null}getPoint(){pe("Curve: .getPoint() not implemented.")}getPointAt(t,e){let n=this.getUtoTmapping(t);return this.getPoint(n,e)}getPoints(t=5){let e=[];for(let n=0;n<=t;n++)e.push(this.getPoint(n/t));return e}getSpacedPoints(t=5){let e=[];for(let n=0;n<=t;n++)e.push(this.getPointAt(n/t));return e}getLength(){let t=this.getLengths();return t[t.length-1]}getLengths(t=this.arcLengthDivisions){if(this.cacheArcLengths&&this.cacheArcLengths.length===t+1&&!this.needsUpdate)return this.cacheArcLengths;this.needsUpdate=!1;let e=[],n,s=this.getPoint(0),r=0;e.push(0);for(let a=1;a<=t;a++)n=this.getPoint(a/t),r+=n.distanceTo(s),e.push(r),s=n;return this.cacheArcLengths=e,e}updateArcLengths(){this.needsUpdate=!0,this.getLengths()}getUtoTmapping(t,e=null){let n=this.getLengths(),s=0,r=n.length,a;e?a=e:a=t*n[r-1];let o=0,c=r-1,l;for(;o<=c;)if(s=Math.floor(o+(c-o)/2),l=n[s]-a,l<0)o=s+1;else if(l>0)c=s-1;else{c=s;break}if(s=c,n[s]===a)return s/(r-1);let h=n[s],u=n[s+1]-h,d=(a-h)/u;return(s+d)/(r-1)}getTangent(t,e){let s=t-1e-4,r=t+1e-4;s<0&&(s=0),r>1&&(r=1);let a=this.getPoint(s),o=this.getPoint(r),c=e||(a.isVector2?new yt:new D);return c.copy(o).sub(a).normalize(),c}getTangentAt(t,e){let n=this.getUtoTmapping(t);return this.getTangent(n,e)}computeFrenetFrames(t,e=!1){let n=new D,s=[],r=[],a=[],o=new D,c=new De;for(let d=0;d<=t;d++){let m=d/t;s[d]=this.getTangentAt(m,new D)}r[0]=new D,a[0]=new D;let l=Number.MAX_VALUE,h=Math.abs(s[0].x),f=Math.abs(s[0].y),u=Math.abs(s[0].z);h<=l&&(l=h,n.set(1,0,0)),f<=l&&(l=f,n.set(0,1,0)),u<=l&&n.set(0,0,1),o.crossVectors(s[0],n).normalize(),r[0].crossVectors(s[0],o),a[0].crossVectors(s[0],r[0]);for(let d=1;d<=t;d++){if(r[d]=r[d-1].clone(),a[d]=a[d-1].clone(),o.crossVectors(s[d-1],s[d]),o.length()>Number.EPSILON){o.normalize();let m=Math.acos(Ae(s[d-1].dot(s[d]),-1,1));r[d].applyMatrix4(c.makeRotationAxis(o,m))}a[d].crossVectors(s[d],r[d])}if(e===!0){let d=Math.acos(Ae(r[0].dot(r[t]),-1,1));d/=t,s[0].dot(o.crossVectors(r[0],r[t]))>0&&(d=-d);for(let m=1;m<=t;m++)r[m].applyMatrix4(c.makeRotationAxis(s[m],d*m)),a[m].crossVectors(s[m],r[m])}return{tangents:s,normals:r,binormals:a}}clone(){return new this.constructor().copy(this)}copy(t){return this.arcLengthDivisions=t.arcLengthDivisions,this}toJSON(){let t={metadata:{version:4.7,type:"Curve",generator:"Curve.toJSON"}};return t.arcLengthDivisions=this.arcLengthDivisions,t.type=this.type,t}fromJSON(t){return this.arcLengthDivisions=t.arcLengthDivisions,this}},_r=class extends Xn{constructor(t=0,e=0,n=1,s=1,r=0,a=Math.PI*2,o=!1,c=0){super(),this.isEllipseCurve=!0,this.type="EllipseCurve",this.aX=t,this.aY=e,this.xRadius=n,this.yRadius=s,this.aStartAngle=r,this.aEndAngle=a,this.aClockwise=o,this.aRotation=c}getPoint(t,e=new yt){let n=e,s=Math.PI*2,r=this.aEndAngle-this.aStartAngle,a=Math.abs(r)<Number.EPSILON;for(;r<0;)r+=s;for(;r>s;)r-=s;r<Number.EPSILON&&(a?r=0:r=s),this.aClockwise===!0&&!a&&(r===s?r=-s:r=r-s);let o=this.aStartAngle+t*r,c=this.aX+this.xRadius*Math.cos(o),l=this.aY+this.yRadius*Math.sin(o);if(this.aRotation!==0){let h=Math.cos(this.aRotation),f=Math.sin(this.aRotation),u=c-this.aX,d=l-this.aY;c=u*h-d*f+this.aX,l=u*f+d*h+this.aY}return n.set(c,l)}copy(t){return super.copy(t),this.aX=t.aX,this.aY=t.aY,this.xRadius=t.xRadius,this.yRadius=t.yRadius,this.aStartAngle=t.aStartAngle,this.aEndAngle=t.aEndAngle,this.aClockwise=t.aClockwise,this.aRotation=t.aRotation,this}toJSON(){let t=super.toJSON();return t.aX=this.aX,t.aY=this.aY,t.xRadius=this.xRadius,t.yRadius=this.yRadius,t.aStartAngle=this.aStartAngle,t.aEndAngle=this.aEndAngle,t.aClockwise=this.aClockwise,t.aRotation=this.aRotation,t}fromJSON(t){return super.fromJSON(t),this.aX=t.aX,this.aY=t.aY,this.xRadius=t.xRadius,this.yRadius=t.yRadius,this.aStartAngle=t.aStartAngle,this.aEndAngle=t.aEndAngle,this.aClockwise=t.aClockwise,this.aRotation=t.aRotation,this}},xl=class extends _r{constructor(t,e,n,s,r,a){super(t,e,n,n,s,r,a),this.isArcCurve=!0,this.type="ArcCurve"}};function lh(){let i=0,t=0,e=0,n=0;function s(r,a,o,c){i=r,t=o,e=-3*r+3*a-2*o-c,n=2*r-2*a+o+c}return{initCatmullRom:function(r,a,o,c,l){s(a,o,l*(o-r),l*(c-a))},initNonuniformCatmullRom:function(r,a,o,c,l,h,f){let u=(a-r)/l-(o-r)/(l+h)+(o-a)/h,d=(o-a)/h-(c-a)/(h+f)+(c-o)/f;u*=h,d*=h,s(a,o,u,d)},calc:function(r){let a=r*r,o=a*r;return i+t*r+e*a+n*o}}}var Ou=new D,Bu=new D,C0=new lh,I0=new lh,P0=new lh,vr=class extends Xn{constructor(t=[],e=!1,n="centripetal",s=.5){super(),this.isCatmullRomCurve3=!0,this.type="CatmullRomCurve3",this.points=t,this.closed=e,this.curveType=n,this.tension=s}getPoint(t,e=new D){let n=e,s=this.points,r=s.length,a=(r-(this.closed?0:1))*t,o=Math.floor(a),c=a-o;this.closed?o+=o>0?0:(Math.floor(Math.abs(o)/r)+1)*r:c===0&&o===r-1&&(o=r-2,c=1);let l,h;this.closed||o>0?l=s[(o-1)%r]:(Bu.subVectors(s[0],s[1]).add(s[0]),l=Bu);let f=s[o%r],u=s[(o+1)%r];if(this.closed||o+2<r?h=s[(o+2)%r]:(Ou.subVectors(s[r-1],s[r-2]).add(s[r-1]),h=Ou),this.curveType==="centripetal"||this.curveType==="chordal"){let d=this.curveType==="chordal"?.5:.25,m=Math.pow(l.distanceToSquared(f),d),x=Math.pow(f.distanceToSquared(u),d),g=Math.pow(u.distanceToSquared(h),d);x<1e-4&&(x=1),m<1e-4&&(m=x),g<1e-4&&(g=x),C0.initNonuniformCatmullRom(l.x,f.x,u.x,h.x,m,x,g),I0.initNonuniformCatmullRom(l.y,f.y,u.y,h.y,m,x,g),P0.initNonuniformCatmullRom(l.z,f.z,u.z,h.z,m,x,g)}else this.curveType==="catmullrom"&&(C0.initCatmullRom(l.x,f.x,u.x,h.x,this.tension),I0.initCatmullRom(l.y,f.y,u.y,h.y,this.tension),P0.initCatmullRom(l.z,f.z,u.z,h.z,this.tension));return n.set(C0.calc(c),I0.calc(c),P0.calc(c)),n}copy(t){super.copy(t),this.points=[];for(let e=0,n=t.points.length;e<n;e++){let s=t.points[e];this.points.push(s.clone())}return this.closed=t.closed,this.curveType=t.curveType,this.tension=t.tension,this}toJSON(){let t=super.toJSON();t.points=[];for(let e=0,n=this.points.length;e<n;e++){let s=this.points[e];t.points.push(s.toArray())}return t.closed=this.closed,t.curveType=this.curveType,t.tension=this.tension,t}fromJSON(t){super.fromJSON(t),this.points=[];for(let e=0,n=t.points.length;e<n;e++){let s=t.points[e];this.points.push(new D().fromArray(s))}return this.closed=t.closed,this.curveType=t.curveType,this.tension=t.tension,this}};function zu(i,t,e,n,s){let r=(n-t)*.5,a=(s-e)*.5,o=i*i,c=i*o;return(2*e-2*n+r+a)*c+(-3*e+3*n-2*r-a)*o+r*i+e}function Fp(i,t){let e=1-i;return e*e*t}function Op(i,t){return 2*(1-i)*i*t}function Bp(i,t){return i*i*t}function ia(i,t,e,n){return Fp(i,t)+Op(i,e)+Bp(i,n)}function zp(i,t){let e=1-i;return e*e*e*t}function kp(i,t){let e=1-i;return 3*e*e*i*t}function Hp(i,t){return 3*(1-i)*i*i*t}function Vp(i,t){return i*i*i*t}function sa(i,t,e,n,s){return zp(i,t)+kp(i,e)+Hp(i,n)+Vp(i,s)}var ba=class extends Xn{constructor(t=new yt,e=new yt,n=new yt,s=new yt){super(),this.isCubicBezierCurve=!0,this.type="CubicBezierCurve",this.v0=t,this.v1=e,this.v2=n,this.v3=s}getPoint(t,e=new yt){let n=e,s=this.v0,r=this.v1,a=this.v2,o=this.v3;return n.set(sa(t,s.x,r.x,a.x,o.x),sa(t,s.y,r.y,a.y,o.y)),n}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this.v3.copy(t.v3),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t.v3=this.v3.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this.v3.fromArray(t.v3),this}},_l=class extends Xn{constructor(t=new D,e=new D,n=new D,s=new D){super(),this.isCubicBezierCurve3=!0,this.type="CubicBezierCurve3",this.v0=t,this.v1=e,this.v2=n,this.v3=s}getPoint(t,e=new D){let n=e,s=this.v0,r=this.v1,a=this.v2,o=this.v3;return n.set(sa(t,s.x,r.x,a.x,o.x),sa(t,s.y,r.y,a.y,o.y),sa(t,s.z,r.z,a.z,o.z)),n}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this.v3.copy(t.v3),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t.v3=this.v3.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this.v3.fromArray(t.v3),this}},Sa=class extends Xn{constructor(t=new yt,e=new yt){super(),this.isLineCurve=!0,this.type="LineCurve",this.v1=t,this.v2=e}getPoint(t,e=new yt){let n=e;return t===1?n.copy(this.v2):(n.copy(this.v2).sub(this.v1),n.multiplyScalar(t).add(this.v1)),n}getPointAt(t,e){return this.getPoint(t,e)}getTangent(t,e=new yt){return e.subVectors(this.v2,this.v1).normalize()}getTangentAt(t,e){return this.getTangent(t,e)}copy(t){return super.copy(t),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},vl=class extends Xn{constructor(t=new D,e=new D){super(),this.isLineCurve3=!0,this.type="LineCurve3",this.v1=t,this.v2=e}getPoint(t,e=new D){let n=e;return t===1?n.copy(this.v2):(n.copy(this.v2).sub(this.v1),n.multiplyScalar(t).add(this.v1)),n}getPointAt(t,e){return this.getPoint(t,e)}getTangent(t,e=new D){return e.subVectors(this.v2,this.v1).normalize()}getTangentAt(t,e){return this.getTangent(t,e)}copy(t){return super.copy(t),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},wa=class extends Xn{constructor(t=new yt,e=new yt,n=new yt){super(),this.isQuadraticBezierCurve=!0,this.type="QuadraticBezierCurve",this.v0=t,this.v1=e,this.v2=n}getPoint(t,e=new yt){let n=e,s=this.v0,r=this.v1,a=this.v2;return n.set(ia(t,s.x,r.x,a.x),ia(t,s.y,r.y,a.y)),n}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},Ea=class extends Xn{constructor(t=new D,e=new D,n=new D){super(),this.isQuadraticBezierCurve3=!0,this.type="QuadraticBezierCurve3",this.v0=t,this.v1=e,this.v2=n}getPoint(t,e=new D){let n=e,s=this.v0,r=this.v1,a=this.v2;return n.set(ia(t,s.x,r.x,a.x),ia(t,s.y,r.y,a.y),ia(t,s.z,r.z,a.z)),n}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},Ta=class extends Xn{constructor(t=[]){super(),this.isSplineCurve=!0,this.type="SplineCurve",this.points=t}getPoint(t,e=new yt){let n=e,s=this.points,r=(s.length-1)*t,a=Math.floor(r),o=r-a,c=s[a===0?a:a-1],l=s[a],h=s[a>s.length-2?s.length-1:a+1],f=s[a>s.length-3?s.length-1:a+2];return n.set(zu(o,c.x,l.x,h.x,f.x),zu(o,c.y,l.y,h.y,f.y)),n}copy(t){super.copy(t),this.points=[];for(let e=0,n=t.points.length;e<n;e++){let s=t.points[e];this.points.push(s.clone())}return this}toJSON(){let t=super.toJSON();t.points=[];for(let e=0,n=this.points.length;e<n;e++){let s=this.points[e];t.points.push(s.toArray())}return t}fromJSON(t){super.fromJSON(t),this.points=[];for(let e=0,n=t.points.length;e<n;e++){let s=t.points[e];this.points.push(new yt().fromArray(s))}return this}},yl=Object.freeze({__proto__:null,ArcCurve:xl,CatmullRomCurve3:vr,CubicBezierCurve:ba,CubicBezierCurve3:_l,EllipseCurve:_r,LineCurve:Sa,LineCurve3:vl,QuadraticBezierCurve:wa,QuadraticBezierCurve3:Ea,SplineCurve:Ta}),Ml=class extends Xn{constructor(){super(),this.type="CurvePath",this.curves=[],this.autoClose=!1}add(t){this.curves.push(t)}closePath(){let t=this.curves[0].getPoint(0),e=this.curves[this.curves.length-1].getPoint(1);if(!t.equals(e)){let n=t.isVector2===!0?"LineCurve":"LineCurve3";this.curves.push(new yl[n](e,t))}return this}getPoint(t,e){let n=t*this.getLength(),s=this.getCurveLengths(),r=0;for(;r<s.length;){if(s[r]>=n){let a=s[r]-n,o=this.curves[r],c=o.getLength(),l=c===0?0:1-a/c;return o.getPointAt(l,e)}r++}return null}getLength(){let t=this.getCurveLengths();return t[t.length-1]}updateArcLengths(){this.needsUpdate=!0,this.cacheLengths=null,this.getCurveLengths()}getCurveLengths(){if(this.cacheLengths&&this.cacheLengths.length===this.curves.length)return this.cacheLengths;let t=[],e=0;for(let n=0,s=this.curves.length;n<s;n++)e+=this.curves[n].getLength(),t.push(e);return this.cacheLengths=t,t}getSpacedPoints(t=40){let e=[];for(let n=0;n<=t;n++)e.push(this.getPoint(n/t));return this.autoClose&&e.push(e[0]),e}getPoints(t=12){let e=[],n;for(let s=0,r=this.curves;s<r.length;s++){let a=r[s],o=a.isEllipseCurve?t*2:a.isLineCurve||a.isLineCurve3?1:a.isSplineCurve?t*a.points.length:t,c=a.getPoints(o);for(let l=0;l<c.length;l++){let h=c[l];n&&n.equals(h)||(e.push(h),n=h)}}return this.autoClose&&e.length>1&&!e[e.length-1].equals(e[0])&&e.push(e[0]),e}copy(t){super.copy(t),this.curves=[];for(let e=0,n=t.curves.length;e<n;e++){let s=t.curves[e];this.curves.push(s.clone())}return this.autoClose=t.autoClose,this}toJSON(){let t=super.toJSON();t.autoClose=this.autoClose,t.curves=[];for(let e=0,n=this.curves.length;e<n;e++){let s=this.curves[e];t.curves.push(s.toJSON())}return t}fromJSON(t){super.fromJSON(t),this.autoClose=t.autoClose,this.curves=[];for(let e=0,n=t.curves.length;e<n;e++){let s=t.curves[e];this.curves.push(new yl[s.type]().fromJSON(s))}return this}},Aa=class extends Ml{constructor(t){super(),this.type="Path",this.currentPoint=new yt,t&&this.setFromPoints(t)}setFromPoints(t){this.moveTo(t[0].x,t[0].y);for(let e=1,n=t.length;e<n;e++)this.lineTo(t[e].x,t[e].y);return this}moveTo(t,e){return this.currentPoint.set(t,e),this}lineTo(t,e){let n=new Sa(this.currentPoint.clone(),new yt(t,e));return this.curves.push(n),this.currentPoint.set(t,e),this}quadraticCurveTo(t,e,n,s){let r=new wa(this.currentPoint.clone(),new yt(t,e),new yt(n,s));return this.curves.push(r),this.currentPoint.set(n,s),this}bezierCurveTo(t,e,n,s,r,a){let o=new ba(this.currentPoint.clone(),new yt(t,e),new yt(n,s),new yt(r,a));return this.curves.push(o),this.currentPoint.set(r,a),this}splineThru(t){let e=[this.currentPoint.clone()].concat(t),n=new Ta(e);return this.curves.push(n),this.currentPoint.copy(t[t.length-1]),this}arc(t,e,n,s,r,a){let o=this.currentPoint.x,c=this.currentPoint.y;return this.absarc(t+o,e+c,n,s,r,a),this}absarc(t,e,n,s,r,a){return this.absellipse(t,e,n,n,s,r,a),this}ellipse(t,e,n,s,r,a,o,c){let l=this.currentPoint.x,h=this.currentPoint.y;return this.absellipse(t+l,e+h,n,s,r,a,o,c),this}absellipse(t,e,n,s,r,a,o,c){let l=new _r(t,e,n,s,r,a,o,c);if(this.curves.length>0){let f=l.getPoint(0);f.equals(this.currentPoint)||this.lineTo(f.x,f.y)}this.curves.push(l);let h=l.getPoint(1);return this.currentPoint.copy(h),this}copy(t){return super.copy(t),this.currentPoint.copy(t.currentPoint),this}toJSON(){let t=super.toJSON();return t.currentPoint=this.currentPoint.toArray(),t}fromJSON(t){return super.fromJSON(t),this.currentPoint.fromArray(t.currentPoint),this}},$i=class extends Aa{constructor(t){super(t),this.uuid=ki(),this.type="Shape",this.holes=[]}getPointsHoles(t){let e=[];for(let n=0,s=this.holes.length;n<s;n++)e[n]=this.holes[n].getPoints(t);return e}extractPoints(t){return{shape:this.getPoints(t),holes:this.getPointsHoles(t)}}copy(t){super.copy(t),this.holes=[];for(let e=0,n=t.holes.length;e<n;e++){let s=t.holes[e];this.holes.push(s.clone())}return this}toJSON(){let t=super.toJSON();t.uuid=this.uuid,t.holes=[];for(let e=0,n=this.holes.length;e<n;e++){let s=this.holes[e];t.holes.push(s.toJSON())}return t}fromJSON(t){super.fromJSON(t),this.uuid=t.uuid,this.holes=[];for(let e=0,n=t.holes.length;e<n;e++){let s=t.holes[e];this.holes.push(new Aa().fromJSON(s))}return this}};function Gp(i,t,e=2){let n=t&&t.length,s=n?t[0]*e:i.length,r=Od(i,0,s,e,!0),a=[];if(!r||r.next===r.prev)return a;let o,c,l;if(n&&(r=Yp(i,t,r,e)),i.length>80*e){o=i[0],c=i[1];let h=o,f=c;for(let u=e;u<s;u+=e){let d=i[u],m=i[u+1];d<o&&(o=d),m<c&&(c=m),d>h&&(h=d),m>f&&(f=m)}l=Math.max(h-o,f-c),l=l!==0?32767/l:0}return Ra(r,a,e,o,c,l,0),a}function Od(i,t,e,n,s){let r;if(s===r1(i,t,e,n)>0)for(let a=t;a<e;a+=n)r=ku(a/n|0,i[a],i[a+1],r);else for(let a=e-n;a>=t;a-=n)r=ku(a/n|0,i[a],i[a+1],r);return r&&yr(r,r.next)&&(Ia(r),r=r.next),r}function Ts(i,t){if(!i)return i;t||(t=i);let e=i,n;do if(n=!1,!e.steiner&&(yr(e,e.next)||en(e.prev,e,e.next)===0)){if(Ia(e),e=t=e.prev,e===e.next)break;n=!0}else e=e.next;while(n||e!==t);return t}function Ra(i,t,e,n,s,r,a){if(!i)return;!a&&r&&Qp(i,n,s,r);let o=i;for(;i.prev!==i.next;){let c=i.prev,l=i.next;if(r?Xp(i,n,s,r):Wp(i)){t.push(c.i,i.i,l.i),Ia(i),i=l.next,o=l.next;continue}if(i=l,i===o){a?a===1?(i=$p(Ts(i),t),Ra(i,t,e,n,s,r,2)):a===2&&qp(i,t,e,n,s,r):Ra(Ts(i),t,e,n,s,r,1);break}}}function Wp(i){let t=i.prev,e=i,n=i.next;if(en(t,e,n)>=0)return!1;let s=t.x,r=e.x,a=n.x,o=t.y,c=e.y,l=n.y,h=Math.min(s,r,a),f=Math.min(o,c,l),u=Math.max(s,r,a),d=Math.max(o,c,l),m=n.next;for(;m!==t;){if(m.x>=h&&m.x<=u&&m.y>=f&&m.y<=d&&na(s,o,r,c,a,l,m.x,m.y)&&en(m.prev,m,m.next)>=0)return!1;m=m.next}return!0}function Xp(i,t,e,n){let s=i.prev,r=i,a=i.next;if(en(s,r,a)>=0)return!1;let o=s.x,c=r.x,l=a.x,h=s.y,f=r.y,u=a.y,d=Math.min(o,c,l),m=Math.min(h,f,u),x=Math.max(o,c,l),g=Math.max(h,f,u),p=z0(d,m,t,e,n),b=z0(x,g,t,e,n),E=i.prevZ,y=i.nextZ;for(;E&&E.z>=p&&y&&y.z<=b;){if(E.x>=d&&E.x<=x&&E.y>=m&&E.y<=g&&E!==s&&E!==a&&na(o,h,c,f,l,u,E.x,E.y)&&en(E.prev,E,E.next)>=0||(E=E.prevZ,y.x>=d&&y.x<=x&&y.y>=m&&y.y<=g&&y!==s&&y!==a&&na(o,h,c,f,l,u,y.x,y.y)&&en(y.prev,y,y.next)>=0))return!1;y=y.nextZ}for(;E&&E.z>=p;){if(E.x>=d&&E.x<=x&&E.y>=m&&E.y<=g&&E!==s&&E!==a&&na(o,h,c,f,l,u,E.x,E.y)&&en(E.prev,E,E.next)>=0)return!1;E=E.prevZ}for(;y&&y.z<=b;){if(y.x>=d&&y.x<=x&&y.y>=m&&y.y<=g&&y!==s&&y!==a&&na(o,h,c,f,l,u,y.x,y.y)&&en(y.prev,y,y.next)>=0)return!1;y=y.nextZ}return!0}function $p(i,t){let e=i;do{let n=e.prev,s=e.next.next;!yr(n,s)&&zd(n,e,e.next,s)&&Ca(n,s)&&Ca(s,n)&&(t.push(n.i,e.i,s.i),Ia(e),Ia(e.next),e=i=s),e=e.next}while(e!==i);return Ts(e)}function qp(i,t,e,n,s,r){let a=i;do{let o=a.next.next;for(;o!==a.prev;){if(a.i!==o.i&&n1(a,o)){let c=kd(a,o);a=Ts(a,a.next),c=Ts(c,c.next),Ra(a,t,e,n,s,r,0),Ra(c,t,e,n,s,r,0);return}o=o.next}a=a.next}while(a!==i)}function Yp(i,t,e,n){let s=[];for(let r=0,a=t.length;r<a;r++){let o=t[r]*n,c=r<a-1?t[r+1]*n:i.length,l=Od(i,o,c,n,!1);l===l.next&&(l.steiner=!0),s.push(e1(l))}s.sort(Zp);for(let r=0;r<s.length;r++)e=Jp(s[r],e);return e}function Zp(i,t){let e=i.x-t.x;if(e===0&&(e=i.y-t.y,e===0)){let n=(i.next.y-i.y)/(i.next.x-i.x),s=(t.next.y-t.y)/(t.next.x-t.x);e=n-s}return e}function Jp(i,t){let e=Kp(i,t);if(!e)return t;let n=kd(e,i);return Ts(n,n.next),Ts(e,e.next)}function Kp(i,t){let e=t,n=i.x,s=i.y,r=-1/0,a;if(yr(i,e))return e;do{if(yr(i,e.next))return e.next;if(s<=e.y&&s>=e.next.y&&e.next.y!==e.y){let f=e.x+(s-e.y)*(e.next.x-e.x)/(e.next.y-e.y);if(f<=n&&f>r&&(r=f,a=e.x<e.next.x?e:e.next,f===n))return a}e=e.next}while(e!==t);if(!a)return null;let o=a,c=a.x,l=a.y,h=1/0;e=a;do{if(n>=e.x&&e.x>=c&&n!==e.x&&Bd(s<l?n:r,s,c,l,s<l?r:n,s,e.x,e.y)){let f=Math.abs(s-e.y)/(n-e.x);Ca(e,i)&&(f<h||f===h&&(e.x>a.x||e.x===a.x&&jp(a,e)))&&(a=e,h=f)}e=e.next}while(e!==o);return a}function jp(i,t){return en(i.prev,i,t.prev)<0&&en(t.next,i,i.next)<0}function Qp(i,t,e,n){let s=i;do s.z===0&&(s.z=z0(s.x,s.y,t,e,n)),s.prevZ=s.prev,s.nextZ=s.next,s=s.next;while(s!==i);s.prevZ.nextZ=null,s.prevZ=null,t1(s)}function t1(i){let t,e=1;do{let n=i,s;i=null;let r=null;for(t=0;n;){t++;let a=n,o=0;for(let l=0;l<e&&(o++,a=a.nextZ,!!a);l++);let c=e;for(;o>0||c>0&&a;)o!==0&&(c===0||!a||n.z<=a.z)?(s=n,n=n.nextZ,o--):(s=a,a=a.nextZ,c--),r?r.nextZ=s:i=s,s.prevZ=r,r=s;n=a}r.nextZ=null,e*=2}while(t>1);return i}function z0(i,t,e,n,s){return i=(i-e)*s|0,t=(t-n)*s|0,i=(i|i<<8)&16711935,i=(i|i<<4)&252645135,i=(i|i<<2)&858993459,i=(i|i<<1)&1431655765,t=(t|t<<8)&16711935,t=(t|t<<4)&252645135,t=(t|t<<2)&858993459,t=(t|t<<1)&1431655765,i|t<<1}function e1(i){let t=i,e=i;do(t.x<e.x||t.x===e.x&&t.y<e.y)&&(e=t),t=t.next;while(t!==i);return e}function Bd(i,t,e,n,s,r,a,o){return(s-a)*(t-o)>=(i-a)*(r-o)&&(i-a)*(n-o)>=(e-a)*(t-o)&&(e-a)*(r-o)>=(s-a)*(n-o)}function na(i,t,e,n,s,r,a,o){return!(i===a&&t===o)&&Bd(i,t,e,n,s,r,a,o)}function n1(i,t){return i.next.i!==t.i&&i.prev.i!==t.i&&!i1(i,t)&&(Ca(i,t)&&Ca(t,i)&&s1(i,t)&&(en(i.prev,i,t.prev)||en(i,t.prev,t))||yr(i,t)&&en(i.prev,i,i.next)>0&&en(t.prev,t,t.next)>0)}function en(i,t,e){return(t.y-i.y)*(e.x-t.x)-(t.x-i.x)*(e.y-t.y)}function yr(i,t){return i.x===t.x&&i.y===t.y}function zd(i,t,e,n){let s=Yo(en(i,t,e)),r=Yo(en(i,t,n)),a=Yo(en(e,n,i)),o=Yo(en(e,n,t));return!!(s!==r&&a!==o||s===0&&qo(i,e,t)||r===0&&qo(i,n,t)||a===0&&qo(e,i,n)||o===0&&qo(e,t,n))}function qo(i,t,e){return t.x<=Math.max(i.x,e.x)&&t.x>=Math.min(i.x,e.x)&&t.y<=Math.max(i.y,e.y)&&t.y>=Math.min(i.y,e.y)}function Yo(i){return i>0?1:i<0?-1:0}function i1(i,t){let e=i;do{if(e.i!==i.i&&e.next.i!==i.i&&e.i!==t.i&&e.next.i!==t.i&&zd(e,e.next,i,t))return!0;e=e.next}while(e!==i);return!1}function Ca(i,t){return en(i.prev,i,i.next)<0?en(i,t,i.next)>=0&&en(i,i.prev,t)>=0:en(i,t,i.prev)<0||en(i,i.next,t)<0}function s1(i,t){let e=i,n=!1,s=(i.x+t.x)/2,r=(i.y+t.y)/2;do e.y>r!=e.next.y>r&&e.next.y!==e.y&&s<(e.next.x-e.x)*(r-e.y)/(e.next.y-e.y)+e.x&&(n=!n),e=e.next;while(e!==i);return n}function kd(i,t){let e=k0(i.i,i.x,i.y),n=k0(t.i,t.x,t.y),s=i.next,r=t.prev;return i.next=t,t.prev=i,e.next=s,s.prev=e,n.next=e,e.prev=n,r.next=n,n.prev=r,n}function ku(i,t,e,n){let s=k0(i,t,e);return n?(s.next=n.next,s.prev=n,n.next.prev=s,n.next=s):(s.prev=s,s.next=s),s}function Ia(i){i.next.prev=i.prev,i.prev.next=i.next,i.prevZ&&(i.prevZ.nextZ=i.nextZ),i.nextZ&&(i.nextZ.prevZ=i.prevZ)}function k0(i,t,e){return{i,x:t,y:e,prev:null,next:null,z:0,prevZ:null,nextZ:null,steiner:!1}}function r1(i,t,e,n){let s=0;for(let r=t,a=e-n;r<e;r+=n)s+=(i[a]-i[r])*(i[r+1]+i[a+1]),a=r;return s}var H0=class{static triangulate(t,e,n=2){return Gp(t,e,n)}},Mi=class i{static area(t){let e=t.length,n=0;for(let s=e-1,r=0;r<e;s=r++)n+=t[s].x*t[r].y-t[r].x*t[s].y;return n*.5}static isClockWise(t){return i.area(t)<0}static triangulateShape(t,e){let n=[],s=[],r=[];Hu(t),Vu(n,t);let a=t.length;e.forEach(Hu);for(let c=0;c<e.length;c++)s.push(a),a+=e[c].length,Vu(n,e[c]);let o=H0.triangulate(n,s);for(let c=0;c<o.length;c+=3)r.push(o.slice(c,c+3));return r}};function Hu(i){let t=i.length;t>2&&i[t-1].equals(i[0])&&i.pop()}function Vu(i,t){for(let e=0;e<t.length;e++)i.push(t[e].x),i.push(t[e].y)}var Pa=class i extends Le{constructor(t=new $i([new yt(.5,.5),new yt(-.5,.5),new yt(-.5,-.5),new yt(.5,-.5)]),e={}){super(),this.type="ExtrudeGeometry",this.parameters={shapes:t,options:e},t=Array.isArray(t)?t:[t];let n=this,s=[],r=[];for(let o=0,c=t.length;o<c;o++){let l=t[o];a(l)}this.setAttribute("position",new ge(s,3)),this.setAttribute("uv",new ge(r,2)),this.computeVertexNormals();function a(o){let c=[],l=e.curveSegments!==void 0?e.curveSegments:12,h=e.steps!==void 0?e.steps:1,f=e.depth!==void 0?e.depth:1,u=e.bevelEnabled!==void 0?e.bevelEnabled:!0,d=e.bevelThickness!==void 0?e.bevelThickness:.2,m=e.bevelSize!==void 0?e.bevelSize:d-.1,x=e.bevelOffset!==void 0?e.bevelOffset:0,g=e.bevelSegments!==void 0?e.bevelSegments:3,p=e.extrudePath,b=e.UVGenerator!==void 0?e.UVGenerator:a1,E,y=!1,w,S,C,v;if(p){E=p.getSpacedPoints(h),y=!0,u=!1;let V=p.isCatmullRomCurve3?p.closed:!1;w=p.computeFrenetFrames(h,V),S=new D,C=new D,v=new D}u||(g=0,d=0,m=0,x=0);let R=o.extractPoints(l),I=R.shape,N=R.holes;if(!Mi.isClockWise(I)){I=I.reverse();for(let V=0,lt=N.length;V<lt;V++){let ct=N[V];Mi.isClockWise(ct)&&(N[V]=ct.reverse())}}function O(V){let ct=10000000000000001e-36,gt=V[0];for(let bt=1;bt<=V.length;bt++){let Bt=bt%V.length,Ut=V[Bt],Kt=Ut.x-gt.x,se=Ut.y-gt.y,F=Kt*Kt+se*se,re=Math.max(Math.abs(Ut.x),Math.abs(Ut.y),Math.abs(gt.x),Math.abs(gt.y)),ae=ct*re*re;if(F<=ae){V.splice(Bt,1),bt--;continue}gt=Ut}}O(I),N.forEach(O);let P=N.length,W=I;for(let V=0;V<P;V++){let lt=N[V];I=I.concat(lt)}function it(V,lt,ct){return lt||fe("ExtrudeGeometry: vec does not exist"),V.clone().addScaledVector(lt,ct)}let Q=I.length;function ht(V,lt,ct){let gt,bt,Bt,Ut=V.x-lt.x,Kt=V.y-lt.y,se=ct.x-V.x,F=ct.y-V.y,re=Ut*Ut+Kt*Kt,ae=Ut*F-Kt*se;if(Math.abs(ae)>Number.EPSILON){let T=Math.sqrt(re),_=Math.sqrt(se*se+F*F),G=lt.x-Kt/T,q=lt.y+Ut/T,rt=ct.x-F/_,St=ct.y+se/_,Rt=((rt-G)*F-(St-q)*se)/(Ut*F-Kt*se);gt=G+Ut*Rt-V.x,bt=q+Kt*Rt-V.y;let tt=gt*gt+bt*bt;if(tt<=2)return new yt(gt,bt);Bt=Math.sqrt(tt/2)}else{let T=!1;Ut>Number.EPSILON?se>Number.EPSILON&&(T=!0):Ut<-Number.EPSILON?se<-Number.EPSILON&&(T=!0):Math.sign(Kt)===Math.sign(F)&&(T=!0),T?(gt=-Kt,bt=Ut,Bt=Math.sqrt(re)):(gt=Ut,bt=Kt,Bt=Math.sqrt(re/2))}return new yt(gt/Bt,bt/Bt)}let K=[];for(let V=0,lt=W.length,ct=lt-1,gt=V+1;V<lt;V++,ct++,gt++)ct===lt&&(ct=0),gt===lt&&(gt=0),K[V]=ht(W[V],W[ct],W[gt]);let ot=[],z,Mt=K.concat();for(let V=0,lt=P;V<lt;V++){let ct=N[V];z=[];for(let gt=0,bt=ct.length,Bt=bt-1,Ut=gt+1;gt<bt;gt++,Bt++,Ut++)Bt===bt&&(Bt=0),Ut===bt&&(Ut=0),z[gt]=ht(ct[gt],ct[Bt],ct[Ut]);ot.push(z),Mt=Mt.concat(z)}let vt;if(g===0)vt=Mi.triangulateShape(W,N);else{let V=[],lt=[];for(let ct=0;ct<g;ct++){let gt=ct/g,bt=d*Math.cos(gt*Math.PI/2),Bt=m*Math.sin(gt*Math.PI/2)+x;for(let Ut=0,Kt=W.length;Ut<Kt;Ut++){let se=it(W[Ut],K[Ut],Bt);_t(se.x,se.y,-bt),gt===0&&V.push(se)}for(let Ut=0,Kt=P;Ut<Kt;Ut++){let se=N[Ut];z=ot[Ut];let F=[];for(let re=0,ae=se.length;re<ae;re++){let T=it(se[re],z[re],Bt);_t(T.x,T.y,-bt),gt===0&&F.push(T)}gt===0&&lt.push(F)}}vt=Mi.triangulateShape(V,lt)}let Et=vt.length,Ot=m+x;for(let V=0;V<Q;V++){let lt=u?it(I[V],Mt[V],Ot):I[V];y?(C.copy(w.normals[0]).multiplyScalar(lt.x),S.copy(w.binormals[0]).multiplyScalar(lt.y),v.copy(E[0]).add(C).add(S),_t(v.x,v.y,v.z)):_t(lt.x,lt.y,0)}for(let V=1;V<=h;V++)for(let lt=0;lt<Q;lt++){let ct=u?it(I[lt],Mt[lt],Ot):I[lt];y?(C.copy(w.normals[V]).multiplyScalar(ct.x),S.copy(w.binormals[V]).multiplyScalar(ct.y),v.copy(E[V]).add(C).add(S),_t(v.x,v.y,v.z)):_t(ct.x,ct.y,f/h*V)}for(let V=g-1;V>=0;V--){let lt=V/g,ct=d*Math.cos(lt*Math.PI/2),gt=m*Math.sin(lt*Math.PI/2)+x;for(let bt=0,Bt=W.length;bt<Bt;bt++){let Ut=it(W[bt],K[bt],gt);_t(Ut.x,Ut.y,f+ct)}for(let bt=0,Bt=N.length;bt<Bt;bt++){let Ut=N[bt];z=ot[bt];for(let Kt=0,se=Ut.length;Kt<se;Kt++){let F=it(Ut[Kt],z[Kt],gt);y?_t(F.x,F.y+E[h-1].y,E[h-1].x+ct):_t(F.x,F.y,f+ct)}}}Lt(),et();function Lt(){let V=s.length/3;if(u){let lt=0,ct=Q*lt;for(let gt=0;gt<Et;gt++){let bt=vt[gt];wt(bt[2]+ct,bt[1]+ct,bt[0]+ct)}lt=h+g*2,ct=Q*lt;for(let gt=0;gt<Et;gt++){let bt=vt[gt];wt(bt[0]+ct,bt[1]+ct,bt[2]+ct)}}else{for(let lt=0;lt<Et;lt++){let ct=vt[lt];wt(ct[2],ct[1],ct[0])}for(let lt=0;lt<Et;lt++){let ct=vt[lt];wt(ct[0]+Q*h,ct[1]+Q*h,ct[2]+Q*h)}}n.addGroup(V,s.length/3-V,0)}function et(){let V=s.length/3,lt=0;nt(W,lt),lt+=W.length;for(let ct=0,gt=N.length;ct<gt;ct++){let bt=N[ct];nt(bt,lt),lt+=bt.length}n.addGroup(V,s.length/3-V,1)}function nt(V,lt){let ct=V.length;for(;--ct>=0;){let gt=ct,bt=ct-1;bt<0&&(bt=V.length-1);for(let Bt=0,Ut=h+g*2;Bt<Ut;Bt++){let Kt=Q*Bt,se=Q*(Bt+1),F=lt+gt+Kt,re=lt+bt+Kt,ae=lt+bt+se,T=lt+gt+se;pt(F,re,ae,T)}}}function _t(V,lt,ct){c.push(V),c.push(lt),c.push(ct)}function wt(V,lt,ct){It(V),It(lt),It(ct);let gt=s.length/3,bt=b.generateTopUV(n,s,gt-3,gt-2,gt-1);ee(bt[0]),ee(bt[1]),ee(bt[2])}function pt(V,lt,ct,gt){It(V),It(lt),It(gt),It(lt),It(ct),It(gt);let bt=s.length/3,Bt=b.generateSideWallUV(n,s,bt-6,bt-3,bt-2,bt-1);ee(Bt[0]),ee(Bt[1]),ee(Bt[3]),ee(Bt[1]),ee(Bt[2]),ee(Bt[3])}function It(V){s.push(c[V*3+0]),s.push(c[V*3+1]),s.push(c[V*3+2])}function ee(V){r.push(V.x),r.push(V.y)}}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}toJSON(){let t=super.toJSON(),e=this.parameters.shapes,n=this.parameters.options;return o1(e,n,t)}static fromJSON(t,e){let n=[];for(let r=0,a=t.shapes.length;r<a;r++){let o=e[t.shapes[r]];n.push(o)}let s=t.options.extrudePath;return s!==void 0&&(t.options.extrudePath=new yl[s.type]().fromJSON(s)),new i(n,t.options)}},a1={generateTopUV:function(i,t,e,n,s){let r=t[e*3],a=t[e*3+1],o=t[n*3],c=t[n*3+1],l=t[s*3],h=t[s*3+1];return[new yt(r,a),new yt(o,c),new yt(l,h)]},generateSideWallUV:function(i,t,e,n,s,r){let a=t[e*3],o=t[e*3+1],c=t[e*3+2],l=t[n*3],h=t[n*3+1],f=t[n*3+2],u=t[s*3],d=t[s*3+1],m=t[s*3+2],x=t[r*3],g=t[r*3+1],p=t[r*3+2];return Math.abs(o-h)<Math.abs(a-l)?[new yt(a,1-c),new yt(l,1-f),new yt(u,1-m),new yt(x,1-p)]:[new yt(o,1-c),new yt(h,1-f),new yt(d,1-m),new yt(g,1-p)]}};function o1(i,t,e){if(e.shapes=[],Array.isArray(i))for(let n=0,s=i.length;n<s;n++){let r=i[n];e.shapes.push(r.uuid)}else e.shapes.push(i.uuid);return e.options=Object.assign({},t),t.extrudePath!==void 0&&(e.options.extrudePath=t.extrudePath.toJSON()),e}var Mr=class i extends Le{constructor(t=[new yt(0,-.5),new yt(.5,0),new yt(0,.5)],e=12,n=0,s=Math.PI*2){super(),this.type="LatheGeometry",this.parameters={points:t,segments:e,phiStart:n,phiLength:s},e=Math.floor(e),s=Ae(s,0,Math.PI*2);let r=[],a=[],o=[],c=[],l=[],h=1/e,f=new D,u=new yt,d=new D,m=new D,x=new D,g=0,p=0;for(let b=0;b<=t.length-1;b++)switch(b){case 0:g=t[b+1].x-t[b].x,p=t[b+1].y-t[b].y,d.x=p*1,d.y=-g,d.z=p*0,x.copy(d),d.normalize(),c.push(d.x,d.y,d.z);break;case t.length-1:c.push(x.x,x.y,x.z);break;default:g=t[b+1].x-t[b].x,p=t[b+1].y-t[b].y,d.x=p*1,d.y=-g,d.z=p*0,m.copy(d),d.x+=x.x,d.y+=x.y,d.z+=x.z,d.normalize(),c.push(d.x,d.y,d.z),x.copy(m)}for(let b=0;b<=e;b++){let E=n+b*h*s,y=Math.sin(E),w=Math.cos(E);for(let S=0;S<=t.length-1;S++){f.x=t[S].x*y,f.y=t[S].y,f.z=t[S].x*w,a.push(f.x,f.y,f.z),u.x=b/e,u.y=S/(t.length-1),o.push(u.x,u.y);let C=c[3*S+0]*y,v=c[3*S+1],R=c[3*S+0]*w;l.push(C,v,R)}}for(let b=0;b<e;b++)for(let E=0;E<t.length-1;E++){let y=E+b*t.length,w=y,S=y+t.length,C=y+t.length+1,v=y+1;r.push(w,S,v),r.push(C,v,S)}this.setIndex(r),this.setAttribute("position",new ge(a,3)),this.setAttribute("uv",new ge(o,2)),this.setAttribute("normal",new ge(l,3))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.points,t.segments,t.phiStart,t.phiLength)}};var ls=class i extends Le{constructor(t=1,e=1,n=1,s=1){super(),this.type="PlaneGeometry",this.parameters={width:t,height:e,widthSegments:n,heightSegments:s};let r=t/2,a=e/2,o=Math.floor(n),c=Math.floor(s),l=o+1,h=c+1,f=t/o,u=e/c,d=[],m=[],x=[],g=[];for(let p=0;p<h;p++){let b=p*u-a;for(let E=0;E<l;E++){let y=E*f-r;m.push(y,-b,0),x.push(0,0,1),g.push(E/o),g.push(1-p/c)}}for(let p=0;p<c;p++)for(let b=0;b<o;b++){let E=b+l*p,y=b+l*(p+1),w=b+1+l*(p+1),S=b+1+l*p;d.push(E,y,S),d.push(y,w,S)}this.setIndex(d),this.setAttribute("position",new ge(m,3)),this.setAttribute("normal",new ge(x,3)),this.setAttribute("uv",new ge(g,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.width,t.height,t.widthSegments,t.heightSegments)}},br=class i extends Le{constructor(t=.5,e=1,n=32,s=1,r=0,a=Math.PI*2){super(),this.type="RingGeometry",this.parameters={innerRadius:t,outerRadius:e,thetaSegments:n,phiSegments:s,thetaStart:r,thetaLength:a},n=Math.max(3,n),s=Math.max(1,s);let o=[],c=[],l=[],h=[],f=t,u=(e-t)/s,d=new D,m=new yt;for(let x=0;x<=s;x++){for(let g=0;g<=n;g++){let p=r+g/n*a;d.x=f*Math.cos(p),d.y=f*Math.sin(p),c.push(d.x,d.y,d.z),l.push(0,0,1),m.x=(d.x/e+1)/2,m.y=(d.y/e+1)/2,h.push(m.x,m.y)}f+=u}for(let x=0;x<s;x++){let g=x*(n+1);for(let p=0;p<n;p++){let b=p+g,E=b,y=b+n+1,w=b+n+2,S=b+1;o.push(E,y,S),o.push(y,w,S)}}this.setIndex(o),this.setAttribute("position",new ge(c,3)),this.setAttribute("normal",new ge(l,3)),this.setAttribute("uv",new ge(h,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.innerRadius,t.outerRadius,t.thetaSegments,t.phiSegments,t.thetaStart,t.thetaLength)}},La=class i extends Le{constructor(t=new $i([new yt(0,.5),new yt(-.5,-.5),new yt(.5,-.5)]),e=12){super(),this.type="ShapeGeometry",this.parameters={shapes:t,curveSegments:e};let n=[],s=[],r=[],a=[],o=0,c=0;if(Array.isArray(t)===!1)l(t);else for(let h=0;h<t.length;h++)l(t[h]),this.addGroup(o,c,h),o+=c,c=0;this.setIndex(n),this.setAttribute("position",new ge(s,3)),this.setAttribute("normal",new ge(r,3)),this.setAttribute("uv",new ge(a,2));function l(h){let f=s.length/3,u=h.extractPoints(e),d=u.shape,m=u.holes;Mi.isClockWise(d)===!1&&(d=d.reverse());for(let g=0,p=m.length;g<p;g++){let b=m[g];Mi.isClockWise(b)===!0&&(m[g]=b.reverse())}let x=Mi.triangulateShape(d,m);for(let g=0,p=m.length;g<p;g++){let b=m[g];d=d.concat(b)}for(let g=0,p=d.length;g<p;g++){let b=d[g];s.push(b.x,b.y,0),r.push(0,0,1),a.push(b.x,b.y)}for(let g=0,p=x.length;g<p;g++){let b=x[g],E=b[0]+f,y=b[1]+f,w=b[2]+f;n.push(E,y,w),c+=3}}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}toJSON(){let t=super.toJSON(),e=this.parameters.shapes;return l1(e,t)}static fromJSON(t,e){let n=[];for(let s=0,r=t.shapes.length;s<r;s++){let a=e[t.shapes[s]];n.push(a)}return new i(n,t.curveSegments)}};function l1(i,t){if(t.shapes=[],Array.isArray(i))for(let e=0,n=i.length;e<n;e++){let s=i[e];t.shapes.push(s.uuid)}else t.shapes.push(i.uuid);return t}var jn=class i extends Le{constructor(t=1,e=32,n=16,s=0,r=Math.PI*2,a=0,o=Math.PI){super(),this.type="SphereGeometry",this.parameters={radius:t,widthSegments:e,heightSegments:n,phiStart:s,phiLength:r,thetaStart:a,thetaLength:o},e=Math.max(3,Math.floor(e)),n=Math.max(2,Math.floor(n));let c=Math.min(a+o,Math.PI),l=0,h=[],f=new D,u=new D,d=[],m=[],x=[],g=[];for(let p=0;p<=n;p++){let b=[],E=p/n,y=a+E*o,w=t*Math.cos(y),S=Math.sqrt(t*t-w*w),C=0;p===0&&a===0?C=.5/e:p===n&&c===Math.PI&&(C=-.5/e);for(let v=0;v<=e;v++){let R=v/e,I=s+R*r;f.x=-S*Math.cos(I),f.y=w,f.z=S*Math.sin(I),m.push(f.x,f.y,f.z),u.copy(f).normalize(),x.push(u.x,u.y,u.z),g.push(R+C,1-E),b.push(l++)}h.push(b)}for(let p=0;p<n;p++)for(let b=0;b<e;b++){let E=h[p][b+1],y=h[p][b],w=h[p+1][b],S=h[p+1][b+1];(p!==0||a>0)&&d.push(E,y,S),(p!==n-1||c<Math.PI)&&d.push(y,w,S)}this.setIndex(d),this.setAttribute("position",new ge(m,3)),this.setAttribute("normal",new ge(x,3)),this.setAttribute("uv",new ge(g,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.radius,t.widthSegments,t.heightSegments,t.phiStart,t.phiLength,t.thetaStart,t.thetaLength)}};var qi=class i extends Le{constructor(t=1,e=.4,n=12,s=48,r=Math.PI*2,a=0,o=Math.PI*2){super(),this.type="TorusGeometry",this.parameters={radius:t,tube:e,radialSegments:n,tubularSegments:s,arc:r,thetaStart:a,thetaLength:o},n=Math.floor(n),s=Math.floor(s);let c=[],l=[],h=[],f=[],u=new D,d=new D,m=new D;for(let x=0;x<=n;x++){let g=a+x/n*o;for(let p=0;p<=s;p++){let b=p/s*r;d.x=(t+e*Math.cos(g))*Math.cos(b),d.y=(t+e*Math.cos(g))*Math.sin(b),d.z=e*Math.sin(g),l.push(d.x,d.y,d.z),u.x=t*Math.cos(b),u.y=t*Math.sin(b),m.subVectors(d,u).normalize(),h.push(m.x,m.y,m.z),f.push(p/s),f.push(x/n)}}for(let x=1;x<=n;x++)for(let g=1;g<=s;g++){let p=(s+1)*x+g-1,b=(s+1)*(x-1)+g-1,E=(s+1)*(x-1)+g,y=(s+1)*x+g;c.push(p,b,y),c.push(b,E,y)}this.setIndex(c),this.setAttribute("position",new ge(l,3)),this.setAttribute("normal",new ge(h,3)),this.setAttribute("uv",new ge(f,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.radius,t.tube,t.radialSegments,t.tubularSegments,t.arc,t.thetaStart,t.thetaLength)}};var Na=class i extends Le{constructor(t=new Ea(new D(-1,-1,0),new D(-1,1,0),new D(1,1,0)),e=64,n=1,s=8,r=!1){super(),this.type="TubeGeometry",this.parameters={path:t,tubularSegments:e,radius:n,radialSegments:s,closed:r};let a=t.computeFrenetFrames(e,r);this.tangents=a.tangents,this.normals=a.normals,this.binormals=a.binormals;let o=new D,c=new D,l=new yt,h=new D,f=[],u=[],d=[],m=[];x(),this.setIndex(m),this.setAttribute("position",new ge(f,3)),this.setAttribute("normal",new ge(u,3)),this.setAttribute("uv",new ge(d,2));function x(){for(let E=0;E<e;E++)g(E);g(r===!1?e:0),b(),p()}function g(E){h=t.getPointAt(E/e,h);let y=a.normals[E],w=a.binormals[E];for(let S=0;S<=s;S++){let C=S/s*Math.PI*2,v=Math.sin(C),R=-Math.cos(C);c.x=R*y.x+v*w.x,c.y=R*y.y+v*w.y,c.z=R*y.z+v*w.z,c.normalize(),u.push(c.x,c.y,c.z),o.x=h.x+n*c.x,o.y=h.y+n*c.y,o.z=h.z+n*c.z,f.push(o.x,o.y,o.z)}}function p(){for(let E=1;E<=e;E++)for(let y=1;y<=s;y++){let w=(s+1)*(E-1)+(y-1),S=(s+1)*E+(y-1),C=(s+1)*E+y,v=(s+1)*(E-1)+y;m.push(w,S,v),m.push(S,C,v)}}function b(){for(let E=0;E<=e;E++)for(let y=0;y<=s;y++)l.x=E/e,l.y=y/s,d.push(l.x,l.y)}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}toJSON(){let t=super.toJSON();return t.path=this.parameters.path.toJSON(),t}static fromJSON(t){return new i(new yl[t.path.type]().fromJSON(t.path),t.tubularSegments,t.radius,t.radialSegments,t.closed)}};function Is(i){let t={};for(let e in i){t[e]={};for(let n in i[e]){let s=i[e][n];if(Gu(s))s.isRenderTargetTexture?(pe("UniformsUtils: Textures of render targets cannot be cloned via cloneUniforms() or mergeUniforms()."),t[e][n]=null):t[e][n]=s.clone();else if(Array.isArray(s))if(Gu(s[0])){let r=[];for(let a=0,o=s.length;a<o;a++)r[a]=s[a].clone();t[e][n]=r}else t[e][n]=s.slice();else t[e][n]=s}}return t}function Un(i){let t={};for(let e=0;e<i.length;e++){let n=Is(i[e]);for(let s in n)t[s]=n[s]}return t}function Gu(i){return i&&(i.isColor||i.isMatrix3||i.isMatrix4||i.isVector2||i.isVector3||i.isVector4||i.isTexture||i.isQuaternion)}function c1(i){let t=[];for(let e=0;e<i.length;e++)t.push(i[e].clone());return t}function ch(i){let t=i.getRenderTarget();return t===null?i.outputColorSpace:t.isXRRenderTarget===!0?t.texture.colorSpace:Re.workingColorSpace}var Yi={clone:Is,merge:Un},h1=`void main() {
	gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
}`,u1=`void main() {
	gl_FragColor = vec4( 1.0, 0.0, 0.0, 1.0 );
}`,Ge=class extends ui{constructor(t){super(),this.isShaderMaterial=!0,this.type="ShaderMaterial",this.defines={},this.uniforms={},this.uniformsGroups=[],this.vertexShader=h1,this.fragmentShader=u1,this.linewidth=1,this.wireframe=!1,this.wireframeLinewidth=1,this.fog=!1,this.lights=!1,this.clipping=!1,this.forceSinglePass=!0,this.extensions={clipCullDistance:!1,multiDraw:!1},this.defaultAttributeValues={color:[1,1,1],uv:[0,0],uv1:[0,0]},this.index0AttributeName=void 0,this.uniformsNeedUpdate=!1,this.glslVersion=null,t!==void 0&&this.setValues(t)}copy(t){return super.copy(t),this.fragmentShader=t.fragmentShader,this.vertexShader=t.vertexShader,this.uniforms=Is(t.uniforms),this.uniformsGroups=c1(t.uniformsGroups),this.defines=Object.assign({},t.defines),this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this.fog=t.fog,this.lights=t.lights,this.clipping=t.clipping,this.extensions=Object.assign({},t.extensions),this.glslVersion=t.glslVersion,this.defaultAttributeValues=Object.assign({},t.defaultAttributeValues),this.index0AttributeName=t.index0AttributeName,this.uniformsNeedUpdate=t.uniformsNeedUpdate,this}toJSON(t){let e=super.toJSON(t);e.glslVersion=this.glslVersion,e.uniforms={};for(let s in this.uniforms){let a=this.uniforms[s].value;a&&a.isTexture?e.uniforms[s]={type:"t",value:a.toJSON(t).uuid}:a&&a.isColor?e.uniforms[s]={type:"c",value:a.getHex()}:a&&a.isVector2?e.uniforms[s]={type:"v2",value:a.toArray()}:a&&a.isVector3?e.uniforms[s]={type:"v3",value:a.toArray()}:a&&a.isVector4?e.uniforms[s]={type:"v4",value:a.toArray()}:a&&a.isMatrix3?e.uniforms[s]={type:"m3",value:a.toArray()}:a&&a.isMatrix4?e.uniforms[s]={type:"m4",value:a.toArray()}:e.uniforms[s]={value:a}}Object.keys(this.defines).length>0&&(e.defines=this.defines),e.vertexShader=this.vertexShader,e.fragmentShader=this.fragmentShader,e.lights=this.lights,e.clipping=this.clipping;let n={};for(let s in this.extensions)this.extensions[s]===!0&&(n[s]=!0);return Object.keys(n).length>0&&(e.extensions=n),e}fromJSON(t,e){if(super.fromJSON(t,e),t.uniforms!==void 0)for(let n in t.uniforms){let s=t.uniforms[n];switch(this.uniforms[n]={},s.type){case"t":this.uniforms[n].value=e[s.value]||null;break;case"c":this.uniforms[n].value=new oe().setHex(s.value);break;case"v2":this.uniforms[n].value=new yt().fromArray(s.value);break;case"v3":this.uniforms[n].value=new D().fromArray(s.value);break;case"v4":this.uniforms[n].value=new je().fromArray(s.value);break;case"m3":this.uniforms[n].value=new ve().fromArray(s.value);break;case"m4":this.uniforms[n].value=new De().fromArray(s.value);break;default:this.uniforms[n].value=s.value}}if(t.defines!==void 0&&(this.defines=t.defines),t.vertexShader!==void 0&&(this.vertexShader=t.vertexShader),t.fragmentShader!==void 0&&(this.fragmentShader=t.fragmentShader),t.glslVersion!==void 0&&(this.glslVersion=t.glslVersion),t.extensions!==void 0)for(let n in t.extensions)this.extensions[n]=t.extensions[n];return t.lights!==void 0&&(this.lights=t.lights),t.clipping!==void 0&&(this.clipping=t.clipping),this}},Sr=class extends Ge{constructor(t){super(t),this.isRawShaderMaterial=!0,this.type="RawShaderMaterial"}},$n=class extends ui{constructor(t){super(),this.isMeshStandardMaterial=!0,this.type="MeshStandardMaterial",this.defines={STANDARD:""},this.color=new oe(16777215),this.roughness=1,this.metalness=0,this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.emissive=new oe(0),this.emissiveIntensity=1,this.emissiveMap=null,this.bumpMap=null,this.bumpScale=1,this.normalMap=null,this.normalMapType=Mc,this.normalScale=new yt(1,1),this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.roughnessMap=null,this.metalnessMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new Vi,this.envMapIntensity=1,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.flatShading=!1,this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.defines={STANDARD:""},this.color.copy(t.color),this.roughness=t.roughness,this.metalness=t.metalness,this.map=t.map,this.lightMap=t.lightMap,this.lightMapIntensity=t.lightMapIntensity,this.aoMap=t.aoMap,this.aoMapIntensity=t.aoMapIntensity,this.emissive.copy(t.emissive),this.emissiveMap=t.emissiveMap,this.emissiveIntensity=t.emissiveIntensity,this.bumpMap=t.bumpMap,this.bumpScale=t.bumpScale,this.normalMap=t.normalMap,this.normalMapType=t.normalMapType,this.normalScale.copy(t.normalScale),this.displacementMap=t.displacementMap,this.displacementScale=t.displacementScale,this.displacementBias=t.displacementBias,this.roughnessMap=t.roughnessMap,this.metalnessMap=t.metalnessMap,this.alphaMap=t.alphaMap,this.envMap=t.envMap,this.envMapRotation.copy(t.envMapRotation),this.envMapIntensity=t.envMapIntensity,this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this.wireframeLinecap=t.wireframeLinecap,this.wireframeLinejoin=t.wireframeLinejoin,this.flatShading=t.flatShading,this.fog=t.fog,this}},Da=class extends $n{constructor(t){super(),this.isMeshPhysicalMaterial=!0,this.defines={STANDARD:"",PHYSICAL:""},this.type="MeshPhysicalMaterial",this.anisotropyRotation=0,this.anisotropyMap=null,this.clearcoatMap=null,this.clearcoatRoughness=0,this.clearcoatRoughnessMap=null,this.clearcoatNormalScale=new yt(1,1),this.clearcoatNormalMap=null,this.ior=1.5,Object.defineProperty(this,"reflectivity",{get:function(){return Ae(2.5*(this.ior-1)/(this.ior+1),0,1)},set:function(e){this.ior=(1+.4*e)/(1-.4*e)}}),this.iridescenceMap=null,this.iridescenceIOR=1.3,this.iridescenceThicknessRange=[100,400],this.iridescenceThicknessMap=null,this.sheenColor=new oe(0),this.sheenColorMap=null,this.sheenRoughness=1,this.sheenRoughnessMap=null,this.transmissionMap=null,this.thickness=0,this.thicknessMap=null,this.attenuationDistance=1/0,this.attenuationColor=new oe(1,1,1),this.specularIntensity=1,this.specularIntensityMap=null,this.specularColor=new oe(1,1,1),this.specularColorMap=null,this._anisotropy=0,this._clearcoat=0,this._dispersion=0,this._iridescence=0,this._retroreflectivity=0,this._sheen=0,this._transmission=0,this.setValues(t)}get anisotropy(){return this._anisotropy}set anisotropy(t){this._anisotropy>0!=t>0&&this.version++,this._anisotropy=t}get clearcoat(){return this._clearcoat}set clearcoat(t){this._clearcoat>0!=t>0&&this.version++,this._clearcoat=t}get iridescence(){return this._iridescence}set iridescence(t){this._iridescence>0!=t>0&&this.version++,this._iridescence=t}get dispersion(){return this._dispersion}set dispersion(t){this._dispersion>0!=t>0&&this.version++,this._dispersion=t}get retroreflectivity(){return this._retroreflectivity}set retroreflectivity(t){this._retroreflectivity>0!=t>0&&this.version++,this._retroreflectivity=t}get sheen(){return this._sheen}set sheen(t){this._sheen>0!=t>0&&this.version++,this._sheen=t}get transmission(){return this._transmission}set transmission(t){this._transmission>0!=t>0&&this.version++,this._transmission=t}copy(t){return super.copy(t),this.defines={STANDARD:"",PHYSICAL:""},this.anisotropy=t.anisotropy,this.anisotropyRotation=t.anisotropyRotation,this.anisotropyMap=t.anisotropyMap,this.clearcoat=t.clearcoat,this.clearcoatMap=t.clearcoatMap,this.clearcoatRoughness=t.clearcoatRoughness,this.clearcoatRoughnessMap=t.clearcoatRoughnessMap,this.clearcoatNormalMap=t.clearcoatNormalMap,this.clearcoatNormalScale.copy(t.clearcoatNormalScale),this.dispersion=t.dispersion,this.ior=t.ior,this.iridescence=t.iridescence,this.iridescenceMap=t.iridescenceMap,this.iridescenceIOR=t.iridescenceIOR,this.iridescenceThicknessRange=[...t.iridescenceThicknessRange],this.iridescenceThicknessMap=t.iridescenceThicknessMap,this.retroreflectivity=t.retroreflectivity,this.sheen=t.sheen,this.sheenColor.copy(t.sheenColor),this.sheenColorMap=t.sheenColorMap,this.sheenRoughness=t.sheenRoughness,this.sheenRoughnessMap=t.sheenRoughnessMap,this.transmission=t.transmission,this.transmissionMap=t.transmissionMap,this.thickness=t.thickness,this.thicknessMap=t.thicknessMap,this.attenuationDistance=t.attenuationDistance,this.attenuationColor.copy(t.attenuationColor),this.specularIntensity=t.specularIntensity,this.specularIntensityMap=t.specularIntensityMap,this.specularColor.copy(t.specularColor),this.specularColorMap=t.specularColorMap,this}};var bl=class extends ui{constructor(t){super(),this.isMeshDepthMaterial=!0,this.type="MeshDepthMaterial",this.depthPacking=bd,this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.wireframe=!1,this.wireframeLinewidth=1,this.setValues(t)}copy(t){return super.copy(t),this.depthPacking=t.depthPacking,this.map=t.map,this.alphaMap=t.alphaMap,this.displacementMap=t.displacementMap,this.displacementScale=t.displacementScale,this.displacementBias=t.displacementBias,this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this}},Sl=class extends ui{constructor(t){super(),this.isMeshDistanceMaterial=!0,this.type="MeshDistanceMaterial",this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.setValues(t)}copy(t){return super.copy(t),this.map=t.map,this.alphaMap=t.alphaMap,this.displacementMap=t.displacementMap,this.displacementScale=t.displacementScale,this.displacementBias=t.displacementBias,this}};var Ua=class extends di{constructor(t){super(),this.isLineDashedMaterial=!0,this.type="LineDashedMaterial",this.scale=1,this.dashSize=3,this.gapSize=1,this.setValues(t)}copy(t){return super.copy(t),this.scale=t.scale,this.dashSize=t.dashSize,this.gapSize=t.gapSize,this}};function nr(i,t){return!i||i.constructor===t?i:typeof t.BYTES_PER_ELEMENT=="number"?new t(i):Array.prototype.slice.call(i)}function L0(i){return i!==void 0&&i.inTangents!==void 0&&i.outTangents!==void 0}var cs=class{constructor(t,e,n,s){this.parameterPositions=t,this._cachedIndex=0,this.resultBuffer=s!==void 0?s:new e.constructor(n),this.sampleValues=e,this.valueSize=n,this.settings=null,this.DefaultSettings_={}}evaluate(t){let e=this.parameterPositions,n=this._cachedIndex,s=e[n],r=e[n-1];n:{t:{let a;e:{i:if(!(t<s)){for(let o=n+2;;){if(s===void 0){if(t<r)break i;return n=e.length,this._cachedIndex=n,this.copySampleValue_(n-1)}if(n===o)break;if(r=s,s=e[++n],t<s)break t}a=e.length;break e}if(!(t>=r)){let o=e[1];t<o&&(n=2,r=o);for(let c=n-2;;){if(r===void 0)return this._cachedIndex=0,this.copySampleValue_(0);if(n===c)break;if(s=r,r=e[--n-1],t>=r)break t}a=n,n=0;break e}break n}for(;n<a;){let o=n+a>>>1;t<e[o]?a=o:n=o+1}if(s=e[n],r=e[n-1],r===void 0)return this._cachedIndex=0,this.copySampleValue_(0);if(s===void 0)return n=e.length,this._cachedIndex=n,this.copySampleValue_(n-1)}this._cachedIndex=n,this.intervalChanged_(n,r,s)}return this.interpolate_(n,r,t,s)}getSettings_(){return this.settings||this.DefaultSettings_}copySampleValue_(t){let e=this.resultBuffer,n=this.sampleValues,s=this.valueSize,r=t*s;for(let a=0;a!==s;++a)e[a]=n[r+a];return e}interpolate_(){throw new Error("THREE.Interpolant: Call to abstract method.")}intervalChanged_(){}},wl=class extends cs{constructor(t,e,n,s){super(t,e,n,s),this._weightPrev=-0,this._offsetPrev=-0,this._weightNext=-0,this._offsetNext=-0,this.DefaultSettings_={endingStart:U0,endingEnd:U0}}intervalChanged_(t,e,n){let s=this.parameterPositions,r=t-2,a=t+1,o=s[r],c=s[a];if(o===void 0)switch(this.getSettings_().endingStart){case F0:r=t,o=2*e-n;break;case O0:r=s.length-2,o=e+s[r]-s[r+1];break;default:r=t,o=n}if(c===void 0)switch(this.getSettings_().endingEnd){case F0:a=t,c=2*n-e;break;case O0:a=1,c=n+s[1]-s[0];break;default:a=t-1,c=e}let l=(n-e)*.5,h=this.valueSize;this._weightPrev=l/(e-o),this._weightNext=l/(c-n),this._offsetPrev=r*h,this._offsetNext=a*h}interpolate_(t,e,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,c=t*o,l=c-o,h=this._offsetPrev,f=this._offsetNext,u=this._weightPrev,d=this._weightNext,m=(n-e)/(s-e),x=m*m,g=x*m,p=-u*g+2*u*x-u*m,b=(1+u)*g+(-1.5-2*u)*x+(-.5+u)*m+1,E=(-1-d)*g+(1.5+d)*x+.5*m,y=d*g-d*x;for(let w=0;w!==o;++w)r[w]=p*a[h+w]+b*a[l+w]+E*a[c+w]+y*a[f+w];return r}},El=class extends cs{constructor(t,e,n,s){super(t,e,n,s)}interpolate_(t,e,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,c=t*o,l=c-o,h=(n-e)/(s-e),f=1-h;for(let u=0;u!==o;++u)r[u]=a[l+u]*f+a[c+u]*h;return r}},Tl=class extends cs{constructor(t,e,n,s){super(t,e,n,s)}interpolate_(t){return this.copySampleValue_(t-1)}},Al=class extends cs{interpolate_(t,e,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,c=t*o,l=c-o,h=this.inTangents,f=this.outTangents;if(!h||!f){let m=(n-e)/(s-e),x=1-m;for(let g=0;g!==o;++g)r[g]=a[l+g]*x+a[c+g]*m;return r}let u=o*2,d=t-1;for(let m=0;m!==o;++m){let x=a[l+m],g=a[c+m],p=d*u+m*2,b=f[p],E=f[p+1],y=t*u+m*2,w=h[y],S=h[y+1],C=f1(n,e,b,w,s);r[m]=Hd(C,x,E,S,g)}return r}};function Hd(i,t,e,n,s){let r=1-i;return r*r*r*t+3*r*r*i*e+3*r*i*i*n+i*i*i*s}function d1(i,t,e,n,s){let r=1-i;return 3*r*r*(e-t)+6*r*i*(n-e)+3*i*i*(s-n)}function f1(i,t,e,n,s){let r=(i-t)/(s-t);for(let a=0;a<8;a++){let o=Hd(r,t,e,n,s)-i;if(Math.abs(o)<1e-10)break;let c=d1(r,t,e,n,s);if(Math.abs(c)<1e-10)break;r=Math.max(0,Math.min(1,r-o/c))}return r}var qn=class{constructor(t,e,n,s){if(t===void 0)throw new Error("THREE.KeyframeTrack: track name is undefined");if(e===void 0||e.length===0)throw new Error("THREE.KeyframeTrack: no keyframes in track named "+t);this.name=t,this.times=nr(e,this.TimeBufferType),this.values=nr(n,this.ValueBufferType),this.setInterpolation(s||this.DefaultInterpolation)}static toJSON(t){let e=t.constructor,n;if(e.toJSON!==this.toJSON)n=e.toJSON(t);else{n={name:t.name,times:nr(t.times,Array),values:nr(t.values,Array)};let s=t.getInterpolation();s!==t.DefaultInterpolation&&(n.interpolation=s),L0(t.settings)&&(n.settings={inTangents:nr(t.settings.inTangents,Array),outTangents:nr(t.settings.outTangents,Array)})}return n.type=t.ValueTypeName,n}InterpolantFactoryMethodDiscrete(t){return new Tl(this.times,this.values,this.getValueSize(),t)}InterpolantFactoryMethodLinear(t){return new El(this.times,this.values,this.getValueSize(),t)}InterpolantFactoryMethodSmooth(t){return new wl(this.times,this.values,this.getValueSize(),t)}InterpolantFactoryMethodBezier(t){let e=new Al(this.times,this.values,this.getValueSize(),t);return this.settings&&(e.inTangents=this.settings.inTangents,e.outTangents=this.settings.outTangents),e}setInterpolation(t){let e;switch(t){case ra:e=this.InterpolantFactoryMethodDiscrete;break;case ll:e=this.InterpolantFactoryMethodLinear;break;case Ko:e=this.InterpolantFactoryMethodSmooth;break;case D0:e=this.InterpolantFactoryMethodBezier;break}if(e===void 0){let n="unsupported interpolation for "+this.ValueTypeName+" keyframe track named "+this.name;if(this.createInterpolant===void 0)if(t!==this.DefaultInterpolation)this.setInterpolation(this.DefaultInterpolation);else throw new Error(n);return pe("KeyframeTrack:",n),this}return this.createInterpolant=e,this}getInterpolation(){switch(this.createInterpolant){case this.InterpolantFactoryMethodDiscrete:return ra;case this.InterpolantFactoryMethodLinear:return ll;case this.InterpolantFactoryMethodSmooth:return Ko;case this.InterpolantFactoryMethodBezier:return D0}}getValueSize(){return this.values.length/this.times.length}shift(t){if(t!==0){let e=this.times;for(let n=0,s=e.length;n!==s;++n)e[n]+=t}return this}scale(t){if(t!==1){let e=this.times;for(let n=0,s=e.length;n!==s;++n)e[n]*=t;L0(this.settings)&&(Wu(this.settings.inTangents,t),Wu(this.settings.outTangents,t))}return this}trim(t,e){let n=this.times,s=n.length,r=0,a=s-1;for(;r!==s&&n[r]<t;)++r;for(;a!==-1&&n[a]>e;)--a;if(++a,r!==0||a!==s){r>=a&&(a=Math.max(a,1),r=a-1);let o=this.getValueSize();this.times=n.slice(r,a),this.values=this.values.slice(r*o,a*o)}return this}validate(){let t=!0,e=this.getValueSize();e-Math.floor(e)!==0&&(fe("KeyframeTrack: Invalid value size in track.",this),t=!1);let n=this.times,s=this.values,r=n.length;r===0&&(fe("KeyframeTrack: Track is empty.",this),t=!1);let a=null;for(let o=0;o!==r;o++){let c=n[o];if(typeof c=="number"&&isNaN(c)){fe("KeyframeTrack: Time is not a valid number.",this,o,c),t=!1;break}if(a!==null&&a>c){fe("KeyframeTrack: Out of order keys.",this,o,c,a),t=!1;break}a=c}if(s!==void 0&&mp(s))for(let o=0,c=s.length;o!==c;++o){let l=s[o];if(isNaN(l)){fe("KeyframeTrack: Value is not a valid number.",this,o,l),t=!1;break}}return t}optimize(){let t=this.times.slice(),e=this.values.slice(),n=this.getValueSize(),s=this.getInterpolation()===Ko,r=t.length-1,a=1;for(let o=1;o<r;++o){let c=!1,l=t[o],h=t[o+1];if(l!==h&&(o!==1||l!==t[0]))if(s)c=!0;else{let f=o*n,u=f-n,d=f+n;for(let m=0;m!==n;++m){let x=e[f+m];if(x!==e[u+m]||x!==e[d+m]){c=!0;break}}}if(c){if(o!==a){t[a]=t[o];let f=o*n,u=a*n;for(let d=0;d!==n;++d)e[u+d]=e[f+d]}++a}}if(r>0){t[a]=t[r];for(let o=r*n,c=a*n,l=0;l!==n;++l)e[c+l]=e[o+l];++a}return a!==t.length?(this.times=t.slice(0,a),this.values=e.slice(0,a*n)):(this.times=t,this.values=e),this}clone(){let t=this.times.slice(),e=this.values.slice(),n=this.constructor,s=new n(this.name,t,e);return s.createInterpolant=this.createInterpolant,L0(this.settings)&&(s.settings={inTangents:this.settings.inTangents.slice(),outTangents:this.settings.outTangents.slice()}),s}};function Wu(i,t){for(let e=0,n=i.length;e!==n;e+=2)i[e]*=t}qn.prototype.ValueTypeName="";qn.prototype.TimeBufferType=Float32Array;qn.prototype.ValueBufferType=Float32Array;qn.prototype.DefaultInterpolation=ll;var hs=class extends qn{constructor(t,e,n){super(t,e,n)}};hs.prototype.ValueTypeName="bool";hs.prototype.ValueBufferType=Array;hs.prototype.DefaultInterpolation=ra;hs.prototype.InterpolantFactoryMethodLinear=void 0;hs.prototype.InterpolantFactoryMethodSmooth=void 0;var Rl=class extends qn{constructor(t,e,n,s){super(t,e,n,s)}};Rl.prototype.ValueTypeName="color";var Cl=class extends qn{constructor(t,e,n,s){super(t,e,n,s)}};Cl.prototype.ValueTypeName="number";var Il=class extends cs{constructor(t,e,n,s){super(t,e,n,s)}interpolate_(t,e,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,c=(n-e)/(s-e),l=t*o;for(let h=l+o;l!==h;l+=4)wi.slerpFlat(r,0,a,l-o,a,l,c);return r}},Fa=class extends qn{constructor(t,e,n,s){super(t,e,n,s)}InterpolantFactoryMethodLinear(t){return new Il(this.times,this.values,this.getValueSize(),t)}};Fa.prototype.ValueTypeName="quaternion";Fa.prototype.InterpolantFactoryMethodSmooth=void 0;var us=class extends qn{constructor(t,e,n){super(t,e,n)}};us.prototype.ValueTypeName="string";us.prototype.ValueBufferType=Array;us.prototype.DefaultInterpolation=ra;us.prototype.InterpolantFactoryMethodLinear=void 0;us.prototype.InterpolantFactoryMethodSmooth=void 0;var Pl=class extends qn{constructor(t,e,n,s){super(t,e,n,s)}};Pl.prototype.ValueTypeName="vector";var Qo={enabled:!1,files:{},add:function(i,t){this.enabled!==!1&&(Xu(i)||(this.files[i]=t))},get:function(i){if(this.enabled!==!1&&!Xu(i))return this.files[i]},remove:function(i){delete this.files[i]},clear:function(){this.files={}}};function Xu(i){try{let t=i.slice(i.indexOf(":")+1);return new URL(t).protocol==="blob:"}catch{return!1}}var Ll=class{constructor(t,e,n){let s=this,r=!1,a=0,o=0,c,l=[];this.onStart=void 0,this.onLoad=t,this.onProgress=e,this.onError=n,this._abortController=null,this.itemStart=function(h){o++,r===!1&&s.onStart!==void 0&&s.onStart(h,a,o),r=!0},this.itemEnd=function(h){a++,s.onProgress!==void 0&&s.onProgress(h,a,o),a===o&&(r=!1,s.onLoad!==void 0&&s.onLoad())},this.itemError=function(h){s.onError!==void 0&&s.onError(h)},this.resolveURL=function(h){return h=h.normalize("NFC"),c?c(h):h},this.setURLModifier=function(h){return c=h,this},this.addHandler=function(h,f){return l.push(h,f),this},this.removeHandler=function(h){let f=l.indexOf(h);return f!==-1&&l.splice(f,2),this},this.getHandler=function(h){for(let f=0,u=l.length;f<u;f+=2){let d=l[f],m=l[f+1];if(d.global&&(d.lastIndex=0),d.test(h))return m}return null},this.abort=function(){return this.abortController.abort(),this._abortController=null,this}}get abortController(){return this._abortController||(this._abortController=new AbortController),this._abortController}},Vd=new Ll,wr=class{constructor(t){this.manager=t!==void 0?t:Vd,this.crossOrigin="anonymous",this.withCredentials=!1,this.path="",this.resourcePath="",this.requestHeader={},typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}load(){}loadAsync(t,e){let n=this;return new Promise(function(s,r){n.load(t,s,e,r)})}parse(){}setCrossOrigin(t){return this.crossOrigin=t,this}setWithCredentials(t){return this.withCredentials=t,this}setPath(t){return this.path=t,this}setResourcePath(t){return this.resourcePath=t,this}setRequestHeader(t){return this.requestHeader=t,this}abort(){return this}};wr.DEFAULT_MATERIAL_NAME="__DEFAULT";var ir=new WeakMap,Nl=class extends wr{constructor(t){super(t)}load(t,e,n,s){this.path!==void 0&&(t=this.path+t),t=this.manager.resolveURL(t);let r=this,a=Qo.get(`image:${t}`);if(a!==void 0){if(a.complete===!0)r.manager.itemStart(t),setTimeout(function(){e&&e(a),r.manager.itemEnd(t)},0);else{let f=ir.get(a);f===void 0&&(f=[],ir.set(a,f)),f.push({onLoad:e,onError:s})}return a}let o=cr("img");function c(){h(),e&&e(this);let f=ir.get(this)||[];for(let u=0;u<f.length;u++){let d=f[u];d.onLoad&&d.onLoad(this)}ir.delete(this),r.manager.itemEnd(t)}function l(f){h(),s&&s(f),Qo.remove(`image:${t}`);let u=ir.get(this)||[];for(let d=0;d<u.length;d++){let m=u[d];m.onError&&m.onError(f)}ir.delete(this),r.manager.itemError(t),r.manager.itemEnd(t)}function h(){o.removeEventListener("load",c,!1),o.removeEventListener("error",l,!1)}return o.addEventListener("load",c,!1),o.addEventListener("error",l,!1),t.slice(0,5)!=="data:"&&this.crossOrigin!==void 0&&(o.crossOrigin=this.crossOrigin),Qo.add(`image:${t}`,o),r.manager.itemStart(t),o.src=t,o}};var Oa=class extends wr{constructor(t){super(t)}load(t,e,n,s){let r=new Sn,a=new Nl(this.manager);return a.setCrossOrigin(this.crossOrigin),a.setPath(this.path),a.load(t,function(o){r.image=o,r.needsUpdate=!0,e!==void 0&&e(r)},n,s),r}},Er=class extends cn{constructor(t,e=1){super(),this.isLight=!0,this.type="Light",this.color=new oe(t),this.intensity=e}copy(t,e){return super.copy(t,e),this.color.copy(t.color),this.intensity=t.intensity,this}toJSON(t){let e=super.toJSON(t);return e.object.color=this.color.getHex(),e.object.intensity=this.intensity,e}},Ba=class extends Er{constructor(t,e,n){super(t,n),this.isHemisphereLight=!0,this.type="HemisphereLight",this.position.copy(cn.DEFAULT_UP),this.updateMatrix(),this.groundColor=new oe(e)}copy(t,e){return super.copy(t,e),this.groundColor.copy(t.groundColor),this}toJSON(t){let e=super.toJSON(t);return e.object.groundColor=this.groundColor.getHex(),e}},N0=new De,$u=new D,qu=new D,za=class{constructor(t){this.camera=t,this.intensity=1,this.bias=0,this.biasNode=null,this.normalBias=0,this.radius=1,this.blurSamples=8,this.mapSize=new yt(512,512),this.mapType=kn,this.map=null,this.mapPass=null,this.matrix=new De,this.autoUpdate=!0,this.needsUpdate=!1,this._frustum=new gr,this._frameExtents=new yt(1,1),this._viewportCount=1,this._viewports=[new je(0,0,1,1)]}getViewportCount(){return this._viewportCount}getCamera(){return this.camera}getFrustum(){return this._frustum}updateMatrices(t){let e=this.camera;$u.setFromMatrixPosition(t.matrixWorld),e.position.copy($u),qu.setFromMatrixPosition(t.target.matrixWorld),e.lookAt(qu),e.updateMatrixWorld(),this._updateMatrix(e,this.matrix,this._frustum)}_updateMatrix(t,e,n,s){N0.multiplyMatrices(t.projectionMatrix,t.matrixWorldInverse),n.setFromProjectionMatrix(N0,t.coordinateSystem,t.reversedDepth);let r=this._frameExtents,a=s?s.z/r.x:1,o=s?s.w/r.y:1,c=s?s.x/r.x:0,l=s?s.y/r.y:0;t.coordinateSystem===lr||t.reversedDepth?e.set(.5*a,0,0,.5*a+c,0,.5*o,0,.5*o+l,0,0,1,0,0,0,0,1):e.set(.5*a,0,0,.5*a+c,0,.5*o,0,.5*o+l,0,0,.5,.5,0,0,0,1),e.multiply(N0)}getViewport(t){return this._viewports[t]}getFrameExtents(){return this._frameExtents}dispose(){this.map&&this.map.dispose(),this.mapPass&&this.mapPass.dispose()}copy(t){return this.camera=t.camera.clone(),this.intensity=t.intensity,this.bias=t.bias,this.radius=t.radius,this.autoUpdate=t.autoUpdate,this.needsUpdate=t.needsUpdate,this.normalBias=t.normalBias,this.blurSamples=t.blurSamples,this.mapSize.copy(t.mapSize),this.biasNode=t.biasNode,this}clone(){return new this.constructor().copy(this)}toJSON(){let t={};return t.intensity=this.intensity,t.bias=this.bias,t.normalBias=this.normalBias,t.radius=this.radius,t.blurSamples=this.blurSamples,t.mapSize=this.mapSize.toArray(),t.camera=this.camera.toJSON(!1).object,delete t.camera.matrix,t}},Zo=new D,Jo=new wi,_i=new D,ka=class extends cn{constructor(){super(),this.isCamera=!0,this.type="Camera",this.matrixWorldInverse=new De,this.projectionMatrix=new De,this.projectionMatrixInverse=new De,this.coordinateSystem=hi,this._reversedDepth=!1}get reversedDepth(){return this._reversedDepth}copy(t,e){return super.copy(t,e),this.matrixWorldInverse.copy(t.matrixWorldInverse),this.projectionMatrix.copy(t.projectionMatrix),this.projectionMatrixInverse.copy(t.projectionMatrixInverse),this.coordinateSystem=t.coordinateSystem,this}getWorldDirection(t){return super.getWorldDirection(t).negate()}updateMatrixWorld(t){super.updateMatrixWorld(t),this.matrixWorld.decompose(Zo,Jo,_i),_i.x===1&&_i.y===1&&_i.z===1?this.matrixWorldInverse.copy(this.matrixWorld).invert():this.matrixWorldInverse.compose(Zo,Jo,_i.set(1,1,1)).invert()}updateWorldMatrix(t,e,n=!1){super.updateWorldMatrix(t,e,n),this.matrixWorld.decompose(Zo,Jo,_i),_i.x===1&&_i.y===1&&_i.z===1?this.matrixWorldInverse.copy(this.matrixWorld).invert():this.matrixWorldInverse.compose(Zo,Jo,_i.set(1,1,1)).invert()}clone(){return new this.constructor().copy(this)}},ss=new D,Yu=new yt,Zu=new yt,Tn=class extends ka{constructor(t=50,e=1,n=.1,s=2e3){super(),this.isPerspectiveCamera=!0,this.type="PerspectiveCamera",this.fov=t,this.zoom=1,this.near=n,this.far=s,this.focus=10,this.aspect=e,this.view=null,this.filmGauge=35,this.filmOffset=0,this.updateProjectionMatrix()}copy(t,e){return super.copy(t,e),this.fov=t.fov,this.zoom=t.zoom,this.near=t.near,this.far=t.far,this.focus=t.focus,this.aspect=t.aspect,this.view=t.view===null?null:Object.assign({},t.view),this.filmGauge=t.filmGauge,this.filmOffset=t.filmOffset,this}setFocalLength(t){let e=.5*this.getFilmHeight()/t;this.fov=cl*2*Math.atan(e),this.updateProjectionMatrix()}getFocalLength(){let t=Math.tan(a0*.5*this.fov);return .5*this.getFilmHeight()/t}getEffectiveFOV(){return cl*2*Math.atan(Math.tan(a0*.5*this.fov)/this.zoom)}getFilmWidth(){return this.filmGauge*Math.min(this.aspect,1)}getFilmHeight(){return this.filmGauge/Math.max(this.aspect,1)}getViewBounds(t,e,n){ss.set(-1,-1,.5).applyMatrix4(this.projectionMatrixInverse),e.set(ss.x,ss.y).multiplyScalar(-t/ss.z),ss.set(1,1,.5).applyMatrix4(this.projectionMatrixInverse),n.set(ss.x,ss.y).multiplyScalar(-t/ss.z)}getViewSize(t,e){return this.getViewBounds(t,Yu,Zu),e.subVectors(Zu,Yu)}setViewOffset(t,e,n,s,r,a){this.aspect=t/e,this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=t,this.view.fullHeight=e,this.view.offsetX=n,this.view.offsetY=s,this.view.width=r,this.view.height=a,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){let t=this.near,e=t*Math.tan(a0*.5*this.fov)/this.zoom,n=2*e,s=this.aspect*n,r=-.5*s,a=this.view;if(this.view!==null&&this.view.enabled){let c=a.fullWidth,l=a.fullHeight;r+=a.offsetX*s/c,e-=a.offsetY*n/l,s*=a.width/c,n*=a.height/l}let o=this.filmOffset;o!==0&&(r+=t*o/this.getFilmWidth()),this.projectionMatrix.makePerspective(r,r+s,e,e-n,t,this.far,this.coordinateSystem,this.reversedDepth),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(t){let e=super.toJSON(t);return e.object.fov=this.fov,e.object.zoom=this.zoom,e.object.near=this.near,e.object.far=this.far,e.object.focus=this.focus,e.object.aspect=this.aspect,this.view!==null&&(e.object.view=Object.assign({},this.view)),e.object.filmGauge=this.filmGauge,e.object.filmOffset=this.filmOffset,e}};var V0=class extends za{constructor(){super(new Tn(90,1,.5,500)),this.isPointLightShadow=!0}},Ha=class extends Er{constructor(t,e,n=0,s=2){super(t,e),this.isPointLight=!0,this.type="PointLight",this.distance=n,this.decay=s,this.shadow=new V0}get power(){return this.intensity*4*Math.PI}set power(t){this.intensity=t/(4*Math.PI)}dispose(){super.dispose(),this.shadow.dispose()}copy(t,e){return super.copy(t,e),this.distance=t.distance,this.decay=t.decay,this.shadow=t.shadow.clone(),this}toJSON(t){let e=super.toJSON(t);return e.object.distance=this.distance,e.object.decay=this.decay,e.object.shadow=this.shadow.toJSON(),e}},ds=class extends ka{constructor(t=-1,e=1,n=1,s=-1,r=.1,a=2e3){super(),this.isOrthographicCamera=!0,this.type="OrthographicCamera",this.zoom=1,this.view=null,this.left=t,this.right=e,this.top=n,this.bottom=s,this.near=r,this.far=a,this.updateProjectionMatrix()}copy(t,e){return super.copy(t,e),this.left=t.left,this.right=t.right,this.top=t.top,this.bottom=t.bottom,this.near=t.near,this.far=t.far,this.zoom=t.zoom,this.view=t.view===null?null:Object.assign({},t.view),this}setViewOffset(t,e,n,s,r,a){this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=t,this.view.fullHeight=e,this.view.offsetX=n,this.view.offsetY=s,this.view.width=r,this.view.height=a,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){let t=(this.right-this.left)/(2*this.zoom),e=(this.top-this.bottom)/(2*this.zoom),n=(this.right+this.left)/2,s=(this.top+this.bottom)/2,r=n-t,a=n+t,o=s+e,c=s-e;if(this.view!==null&&this.view.enabled){let l=(this.right-this.left)/this.view.fullWidth/this.zoom,h=(this.top-this.bottom)/this.view.fullHeight/this.zoom;r+=l*this.view.offsetX,a=r+l*this.view.width,o-=h*this.view.offsetY,c=o-h*this.view.height}this.projectionMatrix.makeOrthographic(r,a,o,c,this.near,this.far,this.coordinateSystem,this.reversedDepth),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(t){let e=super.toJSON(t);return e.object.zoom=this.zoom,e.object.left=this.left,e.object.right=this.right,e.object.top=this.top,e.object.bottom=this.bottom,e.object.near=this.near,e.object.far=this.far,this.view!==null&&(e.object.view=Object.assign({},this.view)),e}},G0=class extends za{constructor(){super(new ds(-5,5,5,-5,.5,500)),this.isDirectionalLightShadow=!0}},Tr=class extends Er{constructor(t,e){super(t,e),this.isDirectionalLight=!0,this.type="DirectionalLight",this.position.copy(cn.DEFAULT_UP),this.updateMatrix(),this.target=new cn,this.shadow=new G0}dispose(){super.dispose(),this.shadow.dispose()}copy(t){return super.copy(t),this.target=t.target.clone(),this.shadow=t.shadow.clone(),this}toJSON(t){let e=super.toJSON(t);return e.object.shadow=this.shadow.toJSON(),e.object.target=this.target.uuid,e}};var sr=-90,rr=1,Dl=class extends cn{constructor(t,e,n){super(),this.type="CubeCamera",this.renderTarget=n,this.coordinateSystem=null,this.activeMipmapLevel=0;let s=new Tn(sr,rr,t,e);s.layers=this.layers,this.add(s);let r=new Tn(sr,rr,t,e);r.layers=this.layers,this.add(r);let a=new Tn(sr,rr,t,e);a.layers=this.layers,this.add(a);let o=new Tn(sr,rr,t,e);o.layers=this.layers,this.add(o);let c=new Tn(sr,rr,t,e);c.layers=this.layers,this.add(c);let l=new Tn(sr,rr,t,e);l.layers=this.layers,this.add(l)}updateCoordinateSystem(){let t=this.coordinateSystem,e=this.children.concat(),[n,s,r,a,o,c]=e;for(let l of e)this.remove(l);if(t===hi)n.up.set(0,1,0),n.lookAt(1,0,0),s.up.set(0,1,0),s.lookAt(-1,0,0),r.up.set(0,0,-1),r.lookAt(0,1,0),a.up.set(0,0,1),a.lookAt(0,-1,0),o.up.set(0,1,0),o.lookAt(0,0,1),c.up.set(0,1,0),c.lookAt(0,0,-1);else if(t===lr)n.up.set(0,-1,0),n.lookAt(-1,0,0),s.up.set(0,-1,0),s.lookAt(1,0,0),r.up.set(0,0,1),r.lookAt(0,1,0),a.up.set(0,0,-1),a.lookAt(0,-1,0),o.up.set(0,-1,0),o.lookAt(0,0,1),c.up.set(0,-1,0),c.lookAt(0,0,-1);else throw new Error("THREE.CubeCamera.updateCoordinateSystem(): Invalid coordinate system: "+t);for(let l of e)this.add(l),l.updateMatrixWorld()}update(t,e){this.parent===null&&this.updateMatrixWorld();let{renderTarget:n,activeMipmapLevel:s}=this;this.coordinateSystem!==t.coordinateSystem&&(this.coordinateSystem=t.coordinateSystem,this.updateCoordinateSystem());let[r,a,o,c,l,h]=this.children,f=t.getRenderTarget(),u=t.getActiveCubeFace(),d=t.getActiveMipmapLevel(),m=t.xr.enabled;t.xr.enabled=!1;let x=n.texture.generateMipmaps;n.texture.generateMipmaps=!1;let g=!1;t.isWebGLRenderer===!0?g=t.state.buffers.depth.getReversed():g=t.reversedDepthBuffer,t.setRenderTarget(n,0,s),g&&t.autoClear===!1&&t.clearDepth(),t.render(e,r),t.setRenderTarget(n,1,s),g&&t.autoClear===!1&&t.clearDepth(),t.render(e,a),t.setRenderTarget(n,2,s),g&&t.autoClear===!1&&t.clearDepth(),t.render(e,o),t.setRenderTarget(n,3,s),g&&t.autoClear===!1&&t.clearDepth(),t.render(e,c),t.setRenderTarget(n,4,s),g&&t.autoClear===!1&&t.clearDepth(),t.render(e,l),n.texture.generateMipmaps=x,t.setRenderTarget(n,5,s),g&&t.autoClear===!1&&t.clearDepth(),t.render(e,h),t.setRenderTarget(f,u,d),t.xr.enabled=m,n.texture.needsPMREMUpdate=!0}},Ul=class extends Tn{constructor(t=[]){super(),this.isArrayCamera=!0,this.isMultiViewCamera=!1,this.cameras=t}},Va=class{constructor(){this._previousTime=0,this._currentTime=0,this._startTime=performance.now(),this._delta=0,this._elapsed=0,this._timescale=1,this._document=null,this._pageVisibilityHandler=null}connect(t){this._document=t,t.hidden!==void 0&&(this._pageVisibilityHandler=p1.bind(this),t.addEventListener("visibilitychange",this._pageVisibilityHandler,!1))}disconnect(){this._pageVisibilityHandler!==null&&(this._document.removeEventListener("visibilitychange",this._pageVisibilityHandler),this._pageVisibilityHandler=null),this._document=null}getDelta(){return this._delta/1e3}getElapsed(){return this._elapsed/1e3}getTimescale(){return this._timescale}setTimescale(t){return this._timescale=t,this}reset(){return this._currentTime=performance.now()-this._startTime,this}dispose(){this.disconnect()}update(t){return this._pageVisibilityHandler!==null&&this._document.hidden===!0?this._delta=0:(this._previousTime=this._currentTime,this._currentTime=(t!==void 0?t:performance.now())-this._startTime,this._delta=(this._currentTime-this._previousTime)*this._timescale,this._elapsed+=this._delta),this}};function p1(){this._document.hidden===!1&&this.reset()}var hh="\\[\\]\\.:\\/",m1=new RegExp("["+hh+"]","g"),uh="[^"+hh+"]",g1="[^"+hh.replace("\\.","")+"]",x1=/((?:WC+[\/:])*)/.source.replace("WC",uh),_1=/(WCOD+)?/.source.replace("WCOD",g1),v1=/(?:\.(WC+)(?:\[(.+)\])?)?/.source.replace("WC",uh),y1=/\.(WC+)(?:\[(.+)\])?/.source.replace("WC",uh),M1=new RegExp("^"+x1+_1+v1+y1+"$"),b1=["material","materials","bones","map"],W0=class{constructor(t,e,n){let s=n||Je.parseTrackName(e);this._targetGroup=t,this._bindings=t.subscribe_(e,s)}getValue(t,e){this.bind();let n=this._targetGroup.nCachedObjects_,s=this._bindings[n];s!==void 0&&s.getValue(t,e)}setValue(t,e){let n=this._bindings;for(let s=this._targetGroup.nCachedObjects_,r=n.length;s!==r;++s)n[s].setValue(t,e)}bind(){let t=this._bindings;for(let e=this._targetGroup.nCachedObjects_,n=t.length;e!==n;++e)t[e].bind()}unbind(){let t=this._bindings;for(let e=this._targetGroup.nCachedObjects_,n=t.length;e!==n;++e)t[e].unbind()}},Je=class i{constructor(t,e,n){this.path=e,this.parsedPath=n||i.parseTrackName(e),this.node=i.findNode(t,this.parsedPath.nodeName),this.rootNode=t,this.getValue=this._getValue_unbound,this.setValue=this._setValue_unbound}static create(t,e,n){return t&&t.isAnimationObjectGroup?new i.Composite(t,e,n):new i(t,e,n)}static sanitizeNodeName(t){return t.replace(/\s/g,"_").replace(m1,"")}static parseTrackName(t){let e=M1.exec(t);if(e===null)throw new Error("THREE.PropertyBinding: Cannot parse trackName: "+t);let n={nodeName:e[2],objectName:e[3],objectIndex:e[4],propertyName:e[5],propertyIndex:e[6]},s=n.nodeName&&n.nodeName.lastIndexOf(".");if(s!==void 0&&s!==-1){let r=n.nodeName.substring(s+1);b1.indexOf(r)!==-1&&(n.nodeName=n.nodeName.substring(0,s),n.objectName=r)}if(n.propertyName===null||n.propertyName.length===0)throw new Error("THREE.PropertyBinding: can not parse propertyName from trackName: "+t);return n}static findNode(t,e){if(e===void 0||e===""||e==="."||e===-1||e===t.name||e===t.uuid)return t;if(t.skeleton){let n=t.skeleton.getBoneByName(e);if(n!==void 0)return n}if(t.children){let n=function(r){for(let a=0;a<r.length;a++){let o=r[a];if(o.name===e||o.uuid===e)return o;let c=n(o.children);if(c)return c}return null},s=n(t.children);if(s)return s}return null}_getValue_unavailable(){}_setValue_unavailable(){}_getValue_direct(t,e){t[e]=this.targetObject[this.propertyName]}_getValue_array(t,e){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)t[e++]=n[s]}_getValue_arrayElement(t,e){t[e]=this.resolvedProperty[this.propertyIndex]}_getValue_toArray(t,e){this.resolvedProperty.toArray(t,e)}_setValue_direct(t,e){this.targetObject[this.propertyName]=t[e]}_setValue_direct_setNeedsUpdate(t,e){this.targetObject[this.propertyName]=t[e],this.targetObject.needsUpdate=!0}_setValue_direct_setMatrixWorldNeedsUpdate(t,e){this.targetObject[this.propertyName]=t[e],this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_array(t,e){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)n[s]=t[e++]}_setValue_array_setNeedsUpdate(t,e){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)n[s]=t[e++];this.targetObject.needsUpdate=!0}_setValue_array_setMatrixWorldNeedsUpdate(t,e){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)n[s]=t[e++];this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_arrayElement(t,e){this.resolvedProperty[this.propertyIndex]=t[e]}_setValue_arrayElement_setNeedsUpdate(t,e){this.resolvedProperty[this.propertyIndex]=t[e],this.targetObject.needsUpdate=!0}_setValue_arrayElement_setMatrixWorldNeedsUpdate(t,e){this.resolvedProperty[this.propertyIndex]=t[e],this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_fromArray(t,e){this.resolvedProperty.fromArray(t,e)}_setValue_fromArray_setNeedsUpdate(t,e){this.resolvedProperty.fromArray(t,e),this.targetObject.needsUpdate=!0}_setValue_fromArray_setMatrixWorldNeedsUpdate(t,e){this.resolvedProperty.fromArray(t,e),this.targetObject.matrixWorldNeedsUpdate=!0}_getValue_unbound(t,e){this.bind(),this.getValue(t,e)}_setValue_unbound(t,e){this.bind(),this.setValue(t,e)}bind(){let t=this.node,e=this.parsedPath,n=e.objectName,s=e.propertyName,r=e.propertyIndex;if(t||(t=i.findNode(this.rootNode,e.nodeName),this.node=t),this.getValue=this._getValue_unavailable,this.setValue=this._setValue_unavailable,!t){pe("PropertyBinding: No target node found for track: "+this.path+".");return}if(n){let l=e.objectIndex;switch(n){case"materials":if(!t.material){fe("PropertyBinding: Can not bind to material as node does not have a material.",this);return}if(!t.material.materials){fe("PropertyBinding: Can not bind to material.materials as node.material does not have a materials array.",this);return}t=t.material.materials;break;case"bones":if(!t.skeleton){fe("PropertyBinding: Can not bind to bones as node does not have a skeleton.",this);return}t=t.skeleton.bones;for(let h=0;h<t.length;h++)if(t[h].name===l){l=h;break}break;case"map":if("map"in t){t=t.map;break}if(!t.material){fe("PropertyBinding: Can not bind to material as node does not have a material.",this);return}if(!t.material.map){fe("PropertyBinding: Can not bind to material.map as node.material does not have a map.",this);return}t=t.material.map;break;default:if(t[n]===void 0){fe("PropertyBinding: Can not bind to objectName of node undefined.",this);return}t=t[n]}if(l!==void 0){if(t[l]===void 0){fe("PropertyBinding: Trying to bind to objectIndex of objectName, but is undefined.",this,t);return}t=t[l]}}let a=t[s];if(a===void 0){let l=e.nodeName;fe("PropertyBinding: Trying to update property for track: "+l+"."+s+" but it wasn't found.",t);return}let o=this.Versioning.None;this.targetObject=t,t.isMaterial===!0?o=this.Versioning.NeedsUpdate:t.isObject3D===!0&&(o=this.Versioning.MatrixWorldNeedsUpdate);let c=this.BindingType.Direct;if(r!==void 0){if(s==="morphTargetInfluences"){if(!t.geometry){fe("PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.",this);return}if(!t.geometry.morphAttributes){fe("PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.morphAttributes.",this);return}t.morphTargetDictionary[r]!==void 0&&(r=t.morphTargetDictionary[r])}c=this.BindingType.ArrayElement,this.resolvedProperty=a,this.propertyIndex=r}else a.fromArray!==void 0&&a.toArray!==void 0?(c=this.BindingType.HasFromToArray,this.resolvedProperty=a):Array.isArray(a)?(c=this.BindingType.EntireArray,this.resolvedProperty=a):this.propertyName=s;this.getValue=this.GetterByBindingType[c],this.setValue=this.SetterByBindingTypeAndVersioning[c][o]}unbind(){this.node=null,this.getValue=this._getValue_unbound,this.setValue=this._setValue_unbound}};Je.Composite=W0;Je.prototype.BindingType={Direct:0,EntireArray:1,ArrayElement:2,HasFromToArray:3};Je.prototype.Versioning={None:0,NeedsUpdate:1,MatrixWorldNeedsUpdate:2};Je.prototype.GetterByBindingType=[Je.prototype._getValue_direct,Je.prototype._getValue_array,Je.prototype._getValue_arrayElement,Je.prototype._getValue_toArray];Je.prototype.SetterByBindingTypeAndVersioning=[[Je.prototype._setValue_direct,Je.prototype._setValue_direct_setNeedsUpdate,Je.prototype._setValue_direct_setMatrixWorldNeedsUpdate],[Je.prototype._setValue_array,Je.prototype._setValue_array_setNeedsUpdate,Je.prototype._setValue_array_setMatrixWorldNeedsUpdate],[Je.prototype._setValue_arrayElement,Je.prototype._setValue_arrayElement_setNeedsUpdate,Je.prototype._setValue_arrayElement_setMatrixWorldNeedsUpdate],[Je.prototype._setValue_fromArray,Je.prototype._setValue_fromArray_setNeedsUpdate,Je.prototype._setValue_fromArray_setMatrixWorldNeedsUpdate]];var t_=new Float32Array(1);var Ju=new De,Ga=class{constructor(t,e,n=0,s=1/0){this.ray=new Es(t,e),this.near=n,this.far=s,this.camera=null,this.layers=new dr,this.params={Mesh:{},Line:{threshold:1},LOD:{},Points:{threshold:1},Sprite:{}}}set(t,e){this.ray.set(t,e)}setFromCamera(t,e){e.isPerspectiveCamera?(this.ray.origin.setFromMatrixPosition(e.matrixWorld),this.ray.direction.set(t.x,t.y,.5).unproject(e).sub(this.ray.origin).normalize(),this.camera=e):e.isOrthographicCamera?(this.ray.origin.set(t.x,t.y,e.projectionMatrix.elements[14]).unproject(e),this.ray.direction.set(0,0,-1).transformDirection(e.matrixWorld),this.camera=e):fe("Raycaster: Unsupported camera type: "+e.type)}setFromXRController(t){return Ju.identity().extractRotation(t.matrixWorld),this.ray.origin.setFromMatrixPosition(t.matrixWorld),this.ray.direction.set(0,0,-1).applyMatrix4(Ju),this}intersectObject(t,e=!0,n=[]){return X0(t,this,n,e),n.sort(Ku),n}intersectObjects(t,e=!0,n=[]){for(let s=0,r=t.length;s<r;s++)X0(t[s],this,n,e);return n.sort(Ku),n}};function Ku(i,t){return i.distance-t.distance}function X0(i,t,e,n){let s=!0;if(i.layers.test(t.layers)&&i.raycast(t,e)===!1&&(s=!1),s===!0&&n===!0){let r=i.children;for(let a=0,o=r.length;a<o;a++)X0(r[a],t,e,!0)}}var $0=class i{static{i.prototype.isMatrix2=!0}constructor(t,e,n,s){this.elements=[1,0,0,1],t!==void 0&&this.set(t,e,n,s)}identity(){return this.set(1,0,0,1),this}fromArray(t,e=0){for(let n=0;n<4;n++)this.elements[n]=t[n+e];return this}set(t,e,n,s){let r=this.elements;return r[0]=t,r[2]=e,r[1]=n,r[3]=s,this}};function dh(i,t,e,n){let s=S1(n);switch(e){case sh:return i*t;case Hl:return i*t/s.components*s.byteLength;case Vl:return i*t/s.components*s.byteLength;case xs:return i*t*2/s.components*s.byteLength;case Gl:return i*t*2/s.components*s.byteLength;case rh:return i*t*3/s.components*s.byteLength;case ei:return i*t*4/s.components*s.byteLength;case Wl:return i*t*4/s.components*s.byteLength;case Qa:case to:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*8;case eo:case no:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*16;case $l:case Yl:return Math.max(i,16)*Math.max(t,8)/4;case Xl:case ql:return Math.max(i,8)*Math.max(t,8)/2;case Zl:case Jl:case jl:case Ql:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*8;case Kl:case io:case tc:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*16;case ec:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*16;case nc:return Math.floor((i+4)/5)*Math.floor((t+3)/4)*16;case ic:return Math.floor((i+4)/5)*Math.floor((t+4)/5)*16;case sc:return Math.floor((i+5)/6)*Math.floor((t+4)/5)*16;case rc:return Math.floor((i+5)/6)*Math.floor((t+5)/6)*16;case ac:return Math.floor((i+7)/8)*Math.floor((t+4)/5)*16;case oc:return Math.floor((i+7)/8)*Math.floor((t+5)/6)*16;case lc:return Math.floor((i+7)/8)*Math.floor((t+7)/8)*16;case cc:return Math.floor((i+9)/10)*Math.floor((t+4)/5)*16;case hc:return Math.floor((i+9)/10)*Math.floor((t+5)/6)*16;case uc:return Math.floor((i+9)/10)*Math.floor((t+7)/8)*16;case dc:return Math.floor((i+9)/10)*Math.floor((t+9)/10)*16;case fc:return Math.floor((i+11)/12)*Math.floor((t+9)/10)*16;case pc:return Math.floor((i+11)/12)*Math.floor((t+11)/12)*16;case mc:case gc:case xc:return Math.ceil(i/4)*Math.ceil(t/4)*16;case _c:case vc:return Math.ceil(i/4)*Math.ceil(t/4)*8;case so:case yc:return Math.ceil(i/4)*Math.ceil(t/4)*16}throw new Error(`Unable to determine texture byte length for ${e} format.`)}function S1(i){switch(i){case kn:case th:return{byteLength:1,components:1};case Cr:case eh:case mn:return{byteLength:2,components:1};case zl:case kl:return{byteLength:2,components:4};case pi:case Bl:case ti:return{byteLength:4,components:1};case nh:case ih:return{byteLength:4,components:3}}throw new Error(`THREE.TextureUtils: Unknown texture type ${i}.`)}typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("register",{detail:{revision:"186"}}));typeof window<"u"&&(window.__THREE__?pe("WARNING: Multiple instances of Three.js being imported."):window.__THREE__="186");function uf(){let i=null,t=!1,e=null,n=null;function s(r,a){n=i.requestAnimationFrame(s),e(r,a)}return{start:function(){t!==!0&&e!==null&&i!==null&&(n=i.requestAnimationFrame(s),t=!0)},stop:function(){i!==null&&i.cancelAnimationFrame(n),t=!1},setAnimationLoop:function(r){e=r},setContext:function(r){i=r}}}function R1(i){let t=new WeakMap;function e(o,c){let l=o.array,h=o.usage,f=l.byteLength,u=i.createBuffer();i.bindBuffer(c,u),i.bufferData(c,l,h),o.onUploadCallback();let d;if(l instanceof Float32Array)d=i.FLOAT;else if(typeof Float16Array<"u"&&l instanceof Float16Array)d=i.HALF_FLOAT;else if(l instanceof Uint16Array)o.isFloat16BufferAttribute?d=i.HALF_FLOAT:d=i.UNSIGNED_SHORT;else if(l instanceof Int16Array)d=i.SHORT;else if(l instanceof Uint32Array)d=i.UNSIGNED_INT;else if(l instanceof Int32Array)d=i.INT;else if(l instanceof Int8Array)d=i.BYTE;else if(l instanceof Uint8Array)d=i.UNSIGNED_BYTE;else if(l instanceof Uint8ClampedArray)d=i.UNSIGNED_BYTE;else throw new Error("THREE.WebGLAttributes: Unsupported buffer data format: "+l);return{buffer:u,type:d,bytesPerElement:l.BYTES_PER_ELEMENT,version:o.version,size:f}}function n(o,c,l){let h=c.array,f=c.updateRanges;if(i.bindBuffer(l,o),f.length===0)i.bufferSubData(l,0,h);else{f.sort((d,m)=>d.start-m.start);let u=0;for(let d=1;d<f.length;d++){let m=f[u],x=f[d];x.start<=m.start+m.count+1?m.count=Math.max(m.count,x.start+x.count-m.start):(++u,f[u]=x)}f.length=u+1;for(let d=0,m=f.length;d<m;d++){let x=f[d];i.bufferSubData(l,x.start*h.BYTES_PER_ELEMENT,h,x.start,x.count)}c.clearUpdateRanges()}c.onUploadCallback()}function s(o){return o.isInterleavedBufferAttribute&&(o=o.data),t.get(o)}function r(o){o.isInterleavedBufferAttribute&&(o=o.data);let c=t.get(o);c&&(i.deleteBuffer(c.buffer),t.delete(o))}function a(o,c){if(o.isInterleavedBufferAttribute&&(o=o.data),o.isGLBufferAttribute){let h=t.get(o);(!h||h.version<o.version)&&t.set(o,{buffer:o.buffer,type:o.type,bytesPerElement:o.elementSize,version:o.version});return}let l=t.get(o);if(l===void 0)t.set(o,e(o,c));else if(l.version<o.version){if(l.size!==o.array.byteLength)throw new Error("THREE.WebGLAttributes: The size of the buffer attribute's array buffer does not match the original size. Resizing buffer attributes is not supported.");n(l.buffer,o,c),l.version=o.version}}return{get:s,remove:r,update:a}}var C1=`#ifdef USE_ALPHAHASH
	if ( diffuseColor.a < getAlphaHashThreshold( vPosition ) ) discard;
#endif`,I1=`#ifdef USE_ALPHAHASH
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
#endif`,P1=`#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture2D( alphaMap, vAlphaMapUv ).g;
#endif`,L1=`#ifdef USE_ALPHAMAP
	uniform sampler2D alphaMap;
#endif`,N1=`#ifdef USE_ALPHATEST
	#ifdef ALPHA_TO_COVERAGE
	diffuseColor.a = smoothstep( alphaTest, alphaTest + fwidth( diffuseColor.a ), diffuseColor.a );
	if ( diffuseColor.a == 0.0 ) discard;
	#else
	if ( diffuseColor.a < alphaTest ) discard;
	#endif
#endif`,D1=`#ifdef USE_ALPHATEST
	uniform float alphaTest;
#endif`,U1=`#ifdef USE_AOMAP
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
#endif`,F1=`#ifdef USE_AOMAP
	uniform sampler2D aoMap;
	uniform float aoMapIntensity;
#endif`,O1=`#ifdef USE_BATCHING
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
#endif`,B1=`#ifdef USE_BATCHING
	mat4 batchingMatrix = getBatchingMatrix( getIndirectIndex( gl_DrawID ) );
#endif`,z1=`vec3 transformed = vec3( position );
#ifdef USE_ALPHAHASH
	vPosition = vec3( position );
#endif`,k1=`vec3 objectNormal = vec3( normal );
#ifdef USE_TANGENT
	vec3 objectTangent = vec3( tangent.xyz );
#endif`,H1=`float G_BlinnPhong_Implicit( ) {
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
} // validated`,V1=`#ifdef USE_IRIDESCENCE
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
#endif`,G1=`#ifdef USE_BUMPMAP
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
#endif`,W1=`#if NUM_CLIPPING_PLANES > 0
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
#endif`,X1=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
	uniform vec4 clippingPlanes[ NUM_CLIPPING_PLANES ];
#endif`,$1=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
#endif`,q1=`#if NUM_CLIPPING_PLANES > 0
	vClipPosition = - mvPosition.xyz;
#endif`,Y1=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA )
	diffuseColor *= vColor;
#endif`,Z1=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA )
	varying vec4 vColor;
#endif`,J1=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
	varying vec4 vColor;
#endif`,K1=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
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
#endif`,j1=`#define PI 3.141592653589793
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
} // validated`,Q1=`#ifdef ENVMAP_TYPE_CUBE_UV
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
#endif`,tm=`vec3 transformedNormal = objectNormal;
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
#endif`,em=`#ifdef USE_DISPLACEMENTMAP
	uniform sampler2D displacementMap;
	uniform float displacementScale;
	uniform float displacementBias;
#endif`,nm=`#ifdef USE_DISPLACEMENTMAP
	transformed += normalize( objectNormal ) * ( texture2D( displacementMap, vDisplacementMapUv ).x * displacementScale + displacementBias );
#endif`,im=`#ifdef USE_EMISSIVEMAP
	vec4 emissiveColor = texture2D( emissiveMap, vEmissiveMapUv );
	#ifdef DECODE_VIDEO_TEXTURE_EMISSIVE
		emissiveColor = sRGBTransferEOTF( emissiveColor );
	#endif
	totalEmissiveRadiance *= emissiveColor.rgb;
#endif`,sm=`#ifdef USE_EMISSIVEMAP
	uniform sampler2D emissiveMap;
#endif`,rm="gl_FragColor = linearToOutputTexel( gl_FragColor );",am=`vec4 LinearTransferOETF( in vec4 value ) {
	return value;
}
vec4 sRGBTransferEOTF( in vec4 value ) {
	return vec4( mix( pow( value.rgb * 0.9478672986 + vec3( 0.0521327014 ), vec3( 2.4 ) ), value.rgb * 0.0773993808, vec3( lessThanEqual( value.rgb, vec3( 0.04045 ) ) ) ), value.a );
}
vec4 sRGBTransferOETF( in vec4 value ) {
	return vec4( mix( pow( value.rgb, vec3( 0.41666 ) ) * 1.055 - vec3( 0.055 ), value.rgb * 12.92, vec3( lessThanEqual( value.rgb, vec3( 0.0031308 ) ) ) ), value.a );
}`,om=`#ifdef USE_ENVMAP
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
#endif`,lm=`#ifdef USE_ENVMAP
	uniform float envMapIntensity;
	uniform mat3 envMapRotation;
	#ifdef ENVMAP_TYPE_CUBE
		uniform samplerCube envMap;
	#else
		uniform sampler2D envMap;
	#endif
#endif`,cm=`#ifdef USE_ENVMAP
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
#endif`,hm=`#ifdef USE_ENVMAP
	#if defined( USE_BUMPMAP ) || defined( USE_NORMALMAP ) || defined( PHONG ) || defined( LAMBERT )
		#define ENV_WORLDPOS
	#endif
	#ifdef ENV_WORLDPOS
		
		varying vec3 vWorldPosition;
	#else
		varying vec3 vReflect;
		uniform float refractionRatio;
	#endif
#endif`,um=`#ifdef USE_ENVMAP
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
#endif`,dm=`#ifdef USE_FOG
	vFogDepth = - mvPosition.z;
#endif`,fm=`#ifdef USE_FOG
	varying float vFogDepth;
#endif`,pm=`#ifdef USE_FOG
	#ifdef FOG_EXP2
		float fogFactor = 1.0 - exp( - fogDensity * fogDensity * vFogDepth * vFogDepth );
	#else
		float fogFactor = smoothstep( fogNear, fogFar, vFogDepth );
	#endif
	gl_FragColor.rgb = mix( gl_FragColor.rgb, fogColor, fogFactor );
#endif`,mm=`#ifdef USE_FOG
	uniform vec3 fogColor;
	varying float vFogDepth;
	#ifdef FOG_EXP2
		uniform float fogDensity;
	#else
		uniform float fogNear;
		uniform float fogFar;
	#endif
#endif`,gm=`#ifdef USE_GRADIENTMAP
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
}`,xm=`#ifdef USE_LIGHTMAP
	uniform sampler2D lightMap;
	uniform float lightMapIntensity;
#endif`,_m=`LambertMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularStrength = specularStrength;`,vm=`varying vec3 vViewPosition;
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
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Lambert`,ym=`uniform bool receiveShadow;
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
#include <lightprobes_pars_fragment>`,Mm=`#ifdef USE_ENVMAP
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
#endif`,bm=`ToonMaterial material;
material.diffuseColor = diffuseColor.rgb;`,Sm=`varying vec3 vViewPosition;
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
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Toon`,wm=`BlinnPhongMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularColor = specular;
material.specularShininess = shininess;
material.specularStrength = specularStrength;`,Em=`varying vec3 vViewPosition;
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
#define RE_IndirectDiffuse		RE_IndirectDiffuse_BlinnPhong`,Tm=`PhysicalMaterial material;
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
#endif`,Am=`uniform sampler2D dfgLUT;
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
}`,Rm=`
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
#endif`,Cm=`#if defined( RE_IndirectDiffuse )
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
#endif`,Im=`#if defined( RE_IndirectDiffuse )
	#if defined( LAMBERT ) || defined( PHONG )
		irradiance += iblIrradiance;
	#endif
	RE_IndirectDiffuse( irradiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif
#if defined( RE_IndirectSpecular )
	RE_IndirectSpecular( radiance, iblIrradiance, clearcoatRadiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif`,Pm=`#ifdef USE_LIGHT_PROBES_GRID
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
#endif`,Lm=`#if defined( USE_LOGARITHMIC_DEPTH_BUFFER )
	gl_FragDepth = vIsPerspective == 0.0 ? gl_FragCoord.z : log2( vFragDepth ) * logDepthBufFC * 0.5;
#endif`,Nm=`#if defined( USE_LOGARITHMIC_DEPTH_BUFFER )
	uniform float logDepthBufFC;
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,Dm=`#ifdef USE_LOGARITHMIC_DEPTH_BUFFER
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,Um=`#ifdef USE_LOGARITHMIC_DEPTH_BUFFER
	vFragDepth = 1.0 + gl_Position.w;
	vIsPerspective = float( isPerspectiveMatrix( projectionMatrix ) );
#endif`,Fm=`#ifdef USE_MAP
	vec4 sampledDiffuseColor = texture2D( map, vMapUv );
	#ifdef DECODE_VIDEO_TEXTURE
		sampledDiffuseColor = sRGBTransferEOTF( sampledDiffuseColor );
	#endif
	diffuseColor *= sampledDiffuseColor;
#endif`,Om=`#ifdef USE_MAP
	uniform sampler2D map;
#endif`,Bm=`#if defined( USE_MAP ) || defined( USE_ALPHAMAP )
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
#endif`,zm=`#if defined( USE_POINTS_UV )
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
#endif`,km=`float metalnessFactor = metalness;
#ifdef USE_METALNESSMAP
	vec4 texelMetalness = texture2D( metalnessMap, vMetalnessMapUv );
	metalnessFactor *= texelMetalness.b;
#endif`,Hm=`#ifdef USE_METALNESSMAP
	uniform sampler2D metalnessMap;
#endif`,Vm=`#ifdef USE_INSTANCING_MORPH
	float morphTargetInfluences[ MORPHTARGETS_COUNT ];
	float morphTargetBaseInfluence = texelFetch( morphTexture, ivec2( 0, gl_InstanceID ), 0 ).r;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		morphTargetInfluences[i] =  texelFetch( morphTexture, ivec2( i + 1, gl_InstanceID ), 0 ).r;
	}
#endif`,Gm=`#if defined( USE_MORPHCOLORS )
	vColor *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		#if defined( USE_COLOR_ALPHA )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ) * morphTargetInfluences[ i ];
		#elif defined( USE_COLOR )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ).rgb * morphTargetInfluences[ i ];
		#endif
	}
#endif`,Wm=`#ifdef USE_MORPHNORMALS
	objectNormal *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) objectNormal += getMorph( gl_VertexID, i, 1 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,Xm=`#ifdef USE_MORPHTARGETS
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
#endif`,$m=`#ifdef USE_MORPHTARGETS
	transformed *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) transformed += getMorph( gl_VertexID, i, 0 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,qm=`float faceDirection = gl_FrontFacing ? 1.0 : - 1.0;
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
vec3 nonPerturbedNormal = normal;`,Ym=`#ifdef USE_NORMALMAP_OBJECTSPACE
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
#endif`,Zm=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,Jm=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,Km=`#ifndef FLAT_SHADED
	vNormal = normalize( transformedNormal );
	#ifdef USE_TANGENT
		vTangent = normalize( transformedTangent );
		vBitangent = normalize( cross( vNormal, vTangent ) * tangent.w );
		#ifdef FLIP_SIDED
			vBitangent = - vBitangent;
		#endif
	#endif
#endif`,jm=`#ifdef USE_NORMALMAP
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
#endif`,Qm=`#ifdef USE_CLEARCOAT
	vec3 clearcoatNormal = nonPerturbedNormal;
#endif`,tg=`#ifdef USE_CLEARCOAT_NORMALMAP
	vec3 clearcoatMapN = texture2D( clearcoatNormalMap, vClearcoatNormalMapUv ).xyz * 2.0 - 1.0;
	clearcoatMapN.xy *= clearcoatNormalScale;
	clearcoatNormal = normalize( tbn2 * clearcoatMapN );
#endif`,eg=`#ifdef USE_CLEARCOATMAP
	uniform sampler2D clearcoatMap;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	uniform sampler2D clearcoatNormalMap;
	uniform vec2 clearcoatNormalScale;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	uniform sampler2D clearcoatRoughnessMap;
#endif`,ng=`#ifdef USE_IRIDESCENCEMAP
	uniform sampler2D iridescenceMap;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	uniform sampler2D iridescenceThicknessMap;
#endif`,ig=`#ifdef OPAQUE
diffuseColor.a = 1.0;
#endif
#ifdef USE_TRANSMISSION
diffuseColor.a *= material.transmissionAlpha;
#endif
gl_FragColor = vec4( outgoingLight, diffuseColor.a );`,sg=`vec3 packNormalToRGB( const in vec3 normal ) {
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
}`,rg=`#ifdef PREMULTIPLIED_ALPHA
	gl_FragColor.rgb *= gl_FragColor.a;
#endif`,ag=`vec4 mvPosition = vec4( transformed, 1.0 );
#ifdef USE_BATCHING
	mvPosition = batchingMatrix * mvPosition;
#endif
#ifdef USE_INSTANCING
	mvPosition = instanceMatrix * mvPosition;
#endif
mvPosition = modelViewMatrix * mvPosition;
gl_Position = projectionMatrix * mvPosition;`,og=`#ifdef DITHERING
	gl_FragColor.rgb = dithering( gl_FragColor.rgb );
#endif`,lg=`#ifdef DITHERING
	vec3 dithering( vec3 color ) {
		float grid_position = rand( gl_FragCoord.xy );
		vec3 dither_shift_RGB = vec3( 0.25 / 255.0, -0.25 / 255.0, 0.25 / 255.0 );
		dither_shift_RGB = mix( 2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position );
		return color + dither_shift_RGB;
	}
#endif`,cg=`float roughnessFactor = roughness;
#ifdef USE_ROUGHNESSMAP
	vec4 texelRoughness = texture2D( roughnessMap, vRoughnessMapUv );
	roughnessFactor *= texelRoughness.g;
#endif`,hg=`#ifdef USE_ROUGHNESSMAP
	uniform sampler2D roughnessMap;
#endif`,ug=`#if NUM_SPOT_LIGHT_COORDS > 0
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
#endif`,dg=`#if NUM_SPOT_LIGHT_COORDS > 0
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
#endif`,fg=`#if ( defined( USE_SHADOWMAP ) && ( NUM_DIR_LIGHT_SHADOWS > 0 || NUM_SUN_LIGHT_SHADOWS > 0 || NUM_POINT_LIGHT_SHADOWS > 0 ) ) || ( NUM_SPOT_LIGHT_COORDS > 0 )
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
#endif`,pg=`float getShadowMask() {
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
}`,mg=`#ifdef USE_SKINNING
	mat4 boneMatX = getBoneMatrix( skinIndex.x );
	mat4 boneMatY = getBoneMatrix( skinIndex.y );
	mat4 boneMatZ = getBoneMatrix( skinIndex.z );
	mat4 boneMatW = getBoneMatrix( skinIndex.w );
#endif`,gg=`#ifdef USE_SKINNING
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
#endif`,xg=`#ifdef USE_SKINNING
	vec4 skinVertex = bindMatrix * vec4( transformed, 1.0 );
	vec4 skinned = vec4( 0.0 );
	skinned += boneMatX * skinVertex * skinWeight.x;
	skinned += boneMatY * skinVertex * skinWeight.y;
	skinned += boneMatZ * skinVertex * skinWeight.z;
	skinned += boneMatW * skinVertex * skinWeight.w;
	transformed = ( bindMatrixInverse * skinned ).xyz;
#endif`,_g=`#ifdef USE_SKINNING
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
#endif`,vg=`float specularStrength;
#ifdef USE_SPECULARMAP
	vec4 texelSpecular = texture2D( specularMap, vSpecularMapUv );
	specularStrength = texelSpecular.r;
#else
	specularStrength = 1.0;
#endif`,yg=`#ifdef USE_SPECULARMAP
	uniform sampler2D specularMap;
#endif`,Mg=`#if defined( TONE_MAPPING )
	gl_FragColor.rgb = toneMapping( gl_FragColor.rgb );
#endif`,bg=`#ifndef saturate
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
vec3 CustomToneMapping( vec3 color ) { return color; }`,Sg=`#ifdef USE_TRANSMISSION
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
#endif`,wg=`#ifdef USE_TRANSMISSION
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
#endif`,Eg=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
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
#endif`,Tg=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
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
#endif`,Ag=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
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
#endif`,Rg=`#if defined( USE_ENVMAP ) || defined( DISTANCE ) || defined ( USE_SHADOWMAP ) || defined ( USE_TRANSMISSION ) || NUM_SPOT_LIGHT_COORDS > 0
	vec4 worldPosition = vec4( transformed, 1.0 );
	#ifdef USE_BATCHING
		worldPosition = batchingMatrix * worldPosition;
	#endif
	#ifdef USE_INSTANCING
		worldPosition = instanceMatrix * worldPosition;
	#endif
	worldPosition = modelMatrix * worldPosition;
#endif`,Cg=`varying vec2 vUv;
uniform mat3 uvTransform;
void main() {
	vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	gl_Position = vec4( position.xy, 1.0, 1.0 );
}`,Ig=`uniform sampler2D t2D;
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
}`,Pg=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,Lg=`#ifdef ENVMAP_TYPE_CUBE
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
}`,Ng=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,Dg=`uniform samplerCube tCube;
uniform float tFlip;
uniform float opacity;
varying vec3 vWorldDirection;
void main() {
	vec4 texColor = textureCube( tCube, vec3( tFlip * vWorldDirection.x, vWorldDirection.yz ) );
	gl_FragColor = texColor;
	gl_FragColor.a *= opacity;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,Ug=`#include <common>
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
}`,Fg=`#if DEPTH_PACKING == 3200
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
}`,Og=`#define DISTANCE
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
}`,Bg=`#define DISTANCE
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
}`,zg=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
}`,kg=`uniform sampler2D tEquirect;
varying vec3 vWorldDirection;
#include <common>
void main() {
	vec3 direction = normalize( vWorldDirection );
	vec2 sampleUV = equirectUv( direction );
	gl_FragColor = texture2D( tEquirect, sampleUV );
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,Hg=`uniform float scale;
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
}`,Vg=`uniform vec3 diffuse;
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
}`,Gg=`#include <common>
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
}`,Wg=`uniform vec3 diffuse;
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
}`,Xg=`#define LAMBERT
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
}`,$g=`#define LAMBERT
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
}`,qg=`#define MATCAP
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
}`,Yg=`#define MATCAP
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
}`,Zg=`#define NORMAL
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
}`,Jg=`#define NORMAL
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
}`,Kg=`#define PHONG
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
}`,jg=`#define PHONG
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
}`,Qg=`#define STANDARD
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
}`,t2=`#define STANDARD
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
}`,e2=`#define TOON
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
}`,n2=`#define TOON
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
}`,i2=`uniform float size;
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
}`,s2=`uniform vec3 diffuse;
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
}`,r2=`#include <common>
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
}`,a2=`uniform vec3 color;
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
}`,o2=`uniform float rotation;
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
}`,l2=`uniform vec3 diffuse;
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
}`,Te={alphahash_fragment:C1,alphahash_pars_fragment:I1,alphamap_fragment:P1,alphamap_pars_fragment:L1,alphatest_fragment:N1,alphatest_pars_fragment:D1,aomap_fragment:U1,aomap_pars_fragment:F1,batching_pars_vertex:O1,batching_vertex:B1,begin_vertex:z1,beginnormal_vertex:k1,bsdfs:H1,iridescence_fragment:V1,bumpmap_pars_fragment:G1,clipping_planes_fragment:W1,clipping_planes_pars_fragment:X1,clipping_planes_pars_vertex:$1,clipping_planes_vertex:q1,color_fragment:Y1,color_pars_fragment:Z1,color_pars_vertex:J1,color_vertex:K1,common:j1,cube_uv_reflection_fragment:Q1,defaultnormal_vertex:tm,displacementmap_pars_vertex:em,displacementmap_vertex:nm,emissivemap_fragment:im,emissivemap_pars_fragment:sm,colorspace_fragment:rm,colorspace_pars_fragment:am,envmap_fragment:om,envmap_common_pars_fragment:lm,envmap_pars_fragment:cm,envmap_pars_vertex:hm,envmap_physical_pars_fragment:Mm,envmap_vertex:um,fog_vertex:dm,fog_pars_vertex:fm,fog_fragment:pm,fog_pars_fragment:mm,gradientmap_pars_fragment:gm,lightmap_pars_fragment:xm,lights_lambert_fragment:_m,lights_lambert_pars_fragment:vm,lights_pars_begin:ym,lights_toon_fragment:bm,lights_toon_pars_fragment:Sm,lights_phong_fragment:wm,lights_phong_pars_fragment:Em,lights_physical_fragment:Tm,lights_physical_pars_fragment:Am,lights_fragment_begin:Rm,lights_fragment_maps:Cm,lights_fragment_end:Im,lightprobes_pars_fragment:Pm,logdepthbuf_fragment:Lm,logdepthbuf_pars_fragment:Nm,logdepthbuf_pars_vertex:Dm,logdepthbuf_vertex:Um,map_fragment:Fm,map_pars_fragment:Om,map_particle_fragment:Bm,map_particle_pars_fragment:zm,metalnessmap_fragment:km,metalnessmap_pars_fragment:Hm,morphinstance_vertex:Vm,morphcolor_vertex:Gm,morphnormal_vertex:Wm,morphtarget_pars_vertex:Xm,morphtarget_vertex:$m,normal_fragment_begin:qm,normal_fragment_maps:Ym,normal_pars_fragment:Zm,normal_pars_vertex:Jm,normal_vertex:Km,normalmap_pars_fragment:jm,clearcoat_normal_fragment_begin:Qm,clearcoat_normal_fragment_maps:tg,clearcoat_pars_fragment:eg,iridescence_pars_fragment:ng,opaque_fragment:ig,packing:sg,premultiplied_alpha_fragment:rg,project_vertex:ag,dithering_fragment:og,dithering_pars_fragment:lg,roughnessmap_fragment:cg,roughnessmap_pars_fragment:hg,shadowmap_pars_fragment:ug,shadowmap_pars_vertex:dg,shadowmap_vertex:fg,shadowmask_pars_fragment:pg,skinbase_vertex:mg,skinning_pars_vertex:gg,skinning_vertex:xg,skinnormal_vertex:_g,specularmap_fragment:vg,specularmap_pars_fragment:yg,tonemapping_fragment:Mg,tonemapping_pars_fragment:bg,transmission_fragment:Sg,transmission_pars_fragment:wg,uv_pars_fragment:Eg,uv_pars_vertex:Tg,uv_vertex:Ag,worldpos_vertex:Rg,background_vert:Cg,background_frag:Ig,backgroundCube_vert:Pg,backgroundCube_frag:Lg,cube_vert:Ng,cube_frag:Dg,depth_vert:Ug,depth_frag:Fg,distance_vert:Og,distance_frag:Bg,equirect_vert:zg,equirect_frag:kg,linedashed_vert:Hg,linedashed_frag:Vg,meshbasic_vert:Gg,meshbasic_frag:Wg,meshlambert_vert:Xg,meshlambert_frag:$g,meshmatcap_vert:qg,meshmatcap_frag:Yg,meshnormal_vert:Zg,meshnormal_frag:Jg,meshphong_vert:Kg,meshphong_frag:jg,meshphysical_vert:Qg,meshphysical_frag:t2,meshtoon_vert:e2,meshtoon_frag:n2,points_vert:i2,points_frag:s2,shadow_vert:r2,shadow_frag:a2,sprite_vert:o2,sprite_frag:l2},Wt={common:{diffuse:{value:new oe(16777215)},opacity:{value:1},map:{value:null},mapTransform:{value:new ve},alphaMap:{value:null},alphaMapTransform:{value:new ve},alphaTest:{value:0}},specularmap:{specularMap:{value:null},specularMapTransform:{value:new ve}},envmap:{envMap:{value:null},envMapRotation:{value:new ve},reflectivity:{value:1},ior:{value:1.5},refractionRatio:{value:.98},dfgLUT:{value:null}},aomap:{aoMap:{value:null},aoMapIntensity:{value:1},aoMapTransform:{value:new ve}},lightmap:{lightMap:{value:null},lightMapIntensity:{value:1},lightMapTransform:{value:new ve}},bumpmap:{bumpMap:{value:null},bumpMapTransform:{value:new ve},bumpScale:{value:1}},normalmap:{normalMap:{value:null},normalMapTransform:{value:new ve},normalScale:{value:new yt(1,1)}},displacementmap:{displacementMap:{value:null},displacementMapTransform:{value:new ve},displacementScale:{value:1},displacementBias:{value:0}},emissivemap:{emissiveMap:{value:null},emissiveMapTransform:{value:new ve}},metalnessmap:{metalnessMap:{value:null},metalnessMapTransform:{value:new ve}},roughnessmap:{roughnessMap:{value:null},roughnessMapTransform:{value:new ve}},gradientmap:{gradientMap:{value:null}},fog:{fogDensity:{value:25e-5},fogNear:{value:1},fogFar:{value:2e3},fogColor:{value:new oe(16777215)}},lights:{ambientLightColor:{value:[]},lightProbe:{value:[]},sunLights:{value:[],properties:{direction:{},color:{}}},sunLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},sunShadowMatrix:{value:[]},sunShadowCascade:{value:[]},directionalLights:{value:[],properties:{direction:{},color:{}}},directionalLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},directionalShadowMatrix:{value:[]},spotLights:{value:[],properties:{color:{},position:{},direction:{},distance:{},coneCos:{},penumbraCos:{},decay:{}}},spotLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},spotLightMap:{value:[]},spotLightMatrix:{value:[]},pointLights:{value:[],properties:{color:{},position:{},decay:{},distance:{}}},pointLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{},shadowCameraNear:{},shadowCameraFar:{}}},pointShadowMatrix:{value:[]},hemisphereLights:{value:[],properties:{direction:{},skyColor:{},groundColor:{}}},rectAreaLights:{value:[],properties:{color:{},position:{},width:{},height:{}}},ltc_1:{value:null},ltc_2:{value:null},probesSH:{value:null},probesMin:{value:new D},probesMax:{value:new D},probesResolution:{value:new D}},points:{diffuse:{value:new oe(16777215)},opacity:{value:1},size:{value:1},scale:{value:1},map:{value:null},alphaMap:{value:null},alphaMapTransform:{value:new ve},alphaTest:{value:0},uvTransform:{value:new ve}},sprite:{diffuse:{value:new oe(16777215)},opacity:{value:1},center:{value:new yt(.5,.5)},rotation:{value:0},map:{value:null},mapTransform:{value:new ve},alphaMap:{value:null},alphaMapTransform:{value:new ve},alphaTest:{value:0}}},Ri={basic:{uniforms:Un([Wt.common,Wt.specularmap,Wt.envmap,Wt.aomap,Wt.lightmap,Wt.fog]),vertexShader:Te.meshbasic_vert,fragmentShader:Te.meshbasic_frag},lambert:{uniforms:Un([Wt.common,Wt.specularmap,Wt.envmap,Wt.aomap,Wt.lightmap,Wt.emissivemap,Wt.bumpmap,Wt.normalmap,Wt.displacementmap,Wt.fog,Wt.lights,{emissive:{value:new oe(0)},envMapIntensity:{value:1}}]),vertexShader:Te.meshlambert_vert,fragmentShader:Te.meshlambert_frag},phong:{uniforms:Un([Wt.common,Wt.specularmap,Wt.envmap,Wt.aomap,Wt.lightmap,Wt.emissivemap,Wt.bumpmap,Wt.normalmap,Wt.displacementmap,Wt.fog,Wt.lights,{emissive:{value:new oe(0)},specular:{value:new oe(1118481)},shininess:{value:30},envMapIntensity:{value:1}}]),vertexShader:Te.meshphong_vert,fragmentShader:Te.meshphong_frag},standard:{uniforms:Un([Wt.common,Wt.envmap,Wt.aomap,Wt.lightmap,Wt.emissivemap,Wt.bumpmap,Wt.normalmap,Wt.displacementmap,Wt.roughnessmap,Wt.metalnessmap,Wt.fog,Wt.lights,{emissive:{value:new oe(0)},roughness:{value:1},metalness:{value:0},envMapIntensity:{value:1}}]),vertexShader:Te.meshphysical_vert,fragmentShader:Te.meshphysical_frag},toon:{uniforms:Un([Wt.common,Wt.aomap,Wt.lightmap,Wt.emissivemap,Wt.bumpmap,Wt.normalmap,Wt.displacementmap,Wt.gradientmap,Wt.fog,Wt.lights,{emissive:{value:new oe(0)}}]),vertexShader:Te.meshtoon_vert,fragmentShader:Te.meshtoon_frag},matcap:{uniforms:Un([Wt.common,Wt.bumpmap,Wt.normalmap,Wt.displacementmap,Wt.fog,{matcap:{value:null}}]),vertexShader:Te.meshmatcap_vert,fragmentShader:Te.meshmatcap_frag},points:{uniforms:Un([Wt.points,Wt.fog]),vertexShader:Te.points_vert,fragmentShader:Te.points_frag},dashed:{uniforms:Un([Wt.common,Wt.fog,{scale:{value:1},dashSize:{value:1},totalSize:{value:2}}]),vertexShader:Te.linedashed_vert,fragmentShader:Te.linedashed_frag},depth:{uniforms:Un([Wt.common,Wt.displacementmap]),vertexShader:Te.depth_vert,fragmentShader:Te.depth_frag},normal:{uniforms:Un([Wt.common,Wt.bumpmap,Wt.normalmap,Wt.displacementmap,{opacity:{value:1}}]),vertexShader:Te.meshnormal_vert,fragmentShader:Te.meshnormal_frag},sprite:{uniforms:Un([Wt.sprite,Wt.fog]),vertexShader:Te.sprite_vert,fragmentShader:Te.sprite_frag},background:{uniforms:{uvTransform:{value:new ve},t2D:{value:null},backgroundIntensity:{value:1}},vertexShader:Te.background_vert,fragmentShader:Te.background_frag},backgroundCube:{uniforms:{envMap:{value:null},backgroundBlurriness:{value:0},backgroundIntensity:{value:1},backgroundRotation:{value:new ve}},vertexShader:Te.backgroundCube_vert,fragmentShader:Te.backgroundCube_frag},cube:{uniforms:{tCube:{value:null},tFlip:{value:-1},opacity:{value:1}},vertexShader:Te.cube_vert,fragmentShader:Te.cube_frag},equirect:{uniforms:{tEquirect:{value:null}},vertexShader:Te.equirect_vert,fragmentShader:Te.equirect_frag},distance:{uniforms:Un([Wt.common,Wt.displacementmap,{referencePosition:{value:new D},nearDistance:{value:1},farDistance:{value:1e3}}]),vertexShader:Te.distance_vert,fragmentShader:Te.distance_frag},shadow:{uniforms:Un([Wt.lights,Wt.fog,{color:{value:new oe(0)},opacity:{value:1}}]),vertexShader:Te.shadow_vert,fragmentShader:Te.shadow_frag}};Ri.physical={uniforms:Un([Ri.standard.uniforms,{clearcoat:{value:0},clearcoatMap:{value:null},clearcoatMapTransform:{value:new ve},clearcoatNormalMap:{value:null},clearcoatNormalMapTransform:{value:new ve},clearcoatNormalScale:{value:new yt(1,1)},clearcoatRoughness:{value:0},clearcoatRoughnessMap:{value:null},clearcoatRoughnessMapTransform:{value:new ve},dispersion:{value:0},retroreflectivity:{value:0},iridescence:{value:0},iridescenceMap:{value:null},iridescenceMapTransform:{value:new ve},iridescenceIOR:{value:1.3},iridescenceThicknessMinimum:{value:100},iridescenceThicknessMaximum:{value:400},iridescenceThicknessMap:{value:null},iridescenceThicknessMapTransform:{value:new ve},sheen:{value:0},sheenColor:{value:new oe(0)},sheenColorMap:{value:null},sheenColorMapTransform:{value:new ve},sheenRoughness:{value:1},sheenRoughnessMap:{value:null},sheenRoughnessMapTransform:{value:new ve},transmission:{value:0},transmissionMap:{value:null},transmissionMapTransform:{value:new ve},transmissionSamplerSize:{value:new yt},transmissionSamplerMap:{value:null},thickness:{value:0},thicknessMap:{value:null},thicknessMapTransform:{value:new ve},attenuationDistance:{value:0},attenuationColor:{value:new oe(0)},specularColor:{value:new oe(1,1,1)},specularColorMap:{value:null},specularColorMapTransform:{value:new ve},specularIntensity:{value:1},specularIntensityMap:{value:null},specularIntensityMapTransform:{value:new ve},anisotropyVector:{value:new yt},anisotropyMap:{value:null},anisotropyMapTransform:{value:new ve}}]),vertexShader:Te.meshphysical_vert,fragmentShader:Te.meshphysical_frag};var wc={r:0,b:0,g:0},c2=new De,df=new ve;df.set(-1,0,0,0,1,0,0,0,1);function h2(i,t,e,n,s,r){let a=new oe(0),o=s===!0?0:1,c,l,h=null,f=0,u=null;function d(b){let E=b.isScene===!0?b.background:null;if(E&&E.isTexture){let y=b.backgroundBlurriness>0;E=t.get(E,y)}return E}function m(b){let E=!1,y=d(b);y===null?g(a,o):y&&y.isColor&&(g(y,1),E=!0);let w=i.xr.getEnvironmentBlendMode();w==="additive"?e.buffers.color.setClear(0,0,0,1,r):w==="alpha-blend"&&e.buffers.color.setClear(0,0,0,0,r),(i.autoClear||E)&&(e.buffers.depth.setTest(!0),e.buffers.depth.setMask(!0),e.buffers.color.setMask(!0),i.clear(i.autoClearColor,i.autoClearDepth,i.autoClearStencil))}function x(b,E){let y=d(E);y&&(y.isCubeTexture||y.mapping===Ka)?(l===void 0&&(l=new we(new xr(1,1,1),new Ge({name:"BackgroundCubeMaterial",uniforms:Is(Ri.backgroundCube.uniforms),vertexShader:Ri.backgroundCube.vertexShader,fragmentShader:Ri.backgroundCube.fragmentShader,side:Rn,depthTest:!1,depthWrite:!1,fog:!1,allowOverride:!1})),l.geometry.deleteAttribute("normal"),l.geometry.deleteAttribute("uv"),l.onBeforeRender=function(w,S,C){this.matrixWorld.copyPosition(C.matrixWorld)},Object.defineProperty(l.material,"envMap",{get:function(){return this.uniforms.envMap.value}}),n.update(l)),l.material.uniforms.envMap.value=y,l.material.uniforms.backgroundBlurriness.value=E.backgroundBlurriness,l.material.uniforms.backgroundIntensity.value=E.backgroundIntensity,l.material.uniforms.backgroundRotation.value.setFromMatrix4(c2.makeRotationFromEuler(E.backgroundRotation)).transpose(),y.isCubeTexture&&y.isRenderTargetTexture===!1&&l.material.uniforms.backgroundRotation.value.premultiply(df),l.material.toneMapped=Re.getTransfer(y.colorSpace)!==Oe,(h!==y||f!==y.version||u!==i.toneMapping)&&(l.material.needsUpdate=!0,h=y,f=y.version,u=i.toneMapping),l.layers.enableAll(),b.unshift(l,l.geometry,l.material,0,0,null)):y&&y.isTexture&&(c===void 0&&(c=new we(new ls(2,2),new Ge({name:"BackgroundMaterial",uniforms:Is(Ri.background.uniforms),vertexShader:Ri.background.vertexShader,fragmentShader:Ri.background.fragmentShader,side:fs,depthTest:!1,depthWrite:!1,fog:!1,allowOverride:!1})),c.geometry.deleteAttribute("normal"),Object.defineProperty(c.material,"map",{get:function(){return this.uniforms.t2D.value}}),n.update(c)),c.material.uniforms.t2D.value=y,c.material.uniforms.backgroundIntensity.value=E.backgroundIntensity,c.material.toneMapped=Re.getTransfer(y.colorSpace)!==Oe,y.matrixAutoUpdate===!0&&y.updateMatrix(),c.material.uniforms.uvTransform.value.copy(y.matrix),(h!==y||f!==y.version||u!==i.toneMapping)&&(c.material.needsUpdate=!0,h=y,f=y.version,u=i.toneMapping),c.layers.enableAll(),b.unshift(c,c.geometry,c.material,0,0,null))}function g(b,E){b.getRGB(wc,ch(i)),e.buffers.color.setClear(wc.r,wc.g,wc.b,E,r)}function p(){l!==void 0&&(l.geometry.dispose(),l.material.dispose(),l=void 0),c!==void 0&&(c.geometry.dispose(),c.material.dispose(),c=void 0)}return{getClearColor:function(){return a},setClearColor:function(b,E=1){a.set(b),o=E,g(a,o)},getClearAlpha:function(){return o},setClearAlpha:function(b){o=b,g(a,o)},render:m,addToRenderList:x,dispose:p}}function u2(i,t){let e=i.getParameter(i.MAX_VERTEX_ATTRIBS),n={},s=u(null),r=s,a=!1;function o(N,L,O,P,W){let it=!1,Q=f(N,P,O,L);r!==Q&&(r=Q,l(r.object)),it=d(N,P,O,W),it&&m(N,P,O,W),W!==null&&t.update(W,i.ELEMENT_ARRAY_BUFFER),(it||a)&&(a=!1,y(N,L,O,P),W!==null&&i.bindBuffer(i.ELEMENT_ARRAY_BUFFER,t.get(W).buffer))}function c(){return i.createVertexArray()}function l(N){return i.bindVertexArray(N)}function h(N){return i.deleteVertexArray(N)}function f(N,L,O,P){let W=P.wireframe===!0,it=n[L.id];it===void 0&&(it={},n[L.id]=it);let Q=N.isInstancedMesh===!0?N.id:0,ht=it[Q];ht===void 0&&(ht={},it[Q]=ht);let K=ht[O.id];K===void 0&&(K={},ht[O.id]=K);let ot=K[W];return ot===void 0&&(ot=u(c()),K[W]=ot),ot}function u(N){let L=[],O=[],P=[];for(let W=0;W<e;W++)L[W]=0,O[W]=0,P[W]=0;return{geometry:null,program:null,wireframe:!1,newAttributes:L,enabledAttributes:O,attributeDivisors:P,object:N,attributes:{},index:null}}function d(N,L,O,P){let W=r.attributes,it=L.attributes,Q=0,ht=O.getAttributes();for(let K in ht)if(ht[K].location>=0){let z=W[K],Mt=it[K];if(Mt===void 0&&(K==="instanceMatrix"&&N.instanceMatrix&&(Mt=N.instanceMatrix),K==="instanceColor"&&N.instanceColor&&(Mt=N.instanceColor)),z===void 0||z.attribute!==Mt||Mt&&z.data!==Mt.data)return!0;Q++}return r.attributesNum!==Q||r.index!==P}function m(N,L,O,P){let W={},it=L.attributes,Q=0,ht=O.getAttributes();for(let K in ht)if(ht[K].location>=0){let z=it[K];z===void 0&&(K==="instanceMatrix"&&N.instanceMatrix&&(z=N.instanceMatrix),K==="instanceColor"&&N.instanceColor&&(z=N.instanceColor));let Mt={};Mt.attribute=z,z&&z.data&&(Mt.data=z.data),W[K]=Mt,Q++}r.attributes=W,r.attributesNum=Q,r.index=P}function x(){let N=r.newAttributes;for(let L=0,O=N.length;L<O;L++)N[L]=0}function g(N){p(N,0)}function p(N,L){let O=r.newAttributes,P=r.enabledAttributes,W=r.attributeDivisors;O[N]=1,P[N]===0&&(i.enableVertexAttribArray(N),P[N]=1),W[N]!==L&&(i.vertexAttribDivisor(N,L),W[N]=L)}function b(){let N=r.newAttributes,L=r.enabledAttributes;for(let O=0,P=L.length;O<P;O++)L[O]!==N[O]&&(i.disableVertexAttribArray(O),L[O]=0)}function E(N,L,O,P,W,it,Q){Q===!0?i.vertexAttribIPointer(N,L,O,W,it):i.vertexAttribPointer(N,L,O,P,W,it)}function y(N,L,O,P){x();let W=P.attributes,it=O.getAttributes(),Q=L.defaultAttributeValues;for(let ht in it){let K=it[ht];if(K.location>=0){let ot=W[ht];if(ot===void 0&&(ht==="instanceMatrix"&&N.instanceMatrix&&(ot=N.instanceMatrix),ht==="instanceColor"&&N.instanceColor&&(ot=N.instanceColor)),ot!==void 0){let z=ot.normalized,Mt=ot.itemSize,vt=t.get(ot);if(vt===void 0)continue;let Et=vt.buffer,Ot=vt.type,Lt=vt.bytesPerElement,et=Ot===i.INT||Ot===i.UNSIGNED_INT||ot.gpuType===Bl;if(ot.isInterleavedBufferAttribute){let nt=ot.data,_t=nt.stride,wt=ot.offset;if(nt.isInstancedInterleavedBuffer){for(let pt=0;pt<K.locationSize;pt++)p(K.location+pt,nt.meshPerAttribute);N.isInstancedMesh!==!0&&P._maxInstanceCount===void 0&&(P._maxInstanceCount=nt.meshPerAttribute*nt.count)}else for(let pt=0;pt<K.locationSize;pt++)g(K.location+pt);i.bindBuffer(i.ARRAY_BUFFER,Et);for(let pt=0;pt<K.locationSize;pt++)E(K.location+pt,Mt/K.locationSize,Ot,z,_t*Lt,(wt+Mt/K.locationSize*pt)*Lt,et)}else{if(ot.isInstancedBufferAttribute){for(let nt=0;nt<K.locationSize;nt++)p(K.location+nt,ot.meshPerAttribute);N.isInstancedMesh!==!0&&P._maxInstanceCount===void 0&&(P._maxInstanceCount=ot.meshPerAttribute*ot.count)}else for(let nt=0;nt<K.locationSize;nt++)g(K.location+nt);i.bindBuffer(i.ARRAY_BUFFER,Et);for(let nt=0;nt<K.locationSize;nt++)E(K.location+nt,Mt/K.locationSize,Ot,z,Mt*Lt,Mt/K.locationSize*nt*Lt,et)}}else if(Q!==void 0){let z=Q[ht];if(z!==void 0)switch(z.length){case 2:i.vertexAttrib2fv(K.location,z);break;case 3:i.vertexAttrib3fv(K.location,z);break;case 4:i.vertexAttrib4fv(K.location,z);break;default:i.vertexAttrib1fv(K.location,z)}}}}b()}function w(){R();for(let N in n){let L=n[N];for(let O in L){let P=L[O];for(let W in P){let it=P[W];for(let Q in it)h(it[Q].object),delete it[Q];delete P[W]}}delete n[N]}}function S(N){if(n[N.id]===void 0)return;let L=n[N.id];for(let O in L){let P=L[O];for(let W in P){let it=P[W];for(let Q in it)h(it[Q].object),delete it[Q];delete P[W]}}delete n[N.id]}function C(N){for(let L in n){let O=n[L];for(let P in O){let W=O[P];if(W[N.id]===void 0)continue;let it=W[N.id];for(let Q in it)h(it[Q].object),delete it[Q];delete W[N.id]}}}function v(N){for(let L in n){let O=n[L],P=N.isInstancedMesh===!0?N.id:0,W=O[P];if(W!==void 0){for(let it in W){let Q=W[it];for(let ht in Q)h(Q[ht].object),delete Q[ht];delete W[it]}delete O[P],Object.keys(O).length===0&&delete n[L]}}}function R(){I(),a=!0,r!==s&&(r=s,l(r.object))}function I(){s.geometry=null,s.program=null,s.wireframe=!1}return{setup:o,reset:R,resetDefaultState:I,dispose:w,releaseStatesOfGeometry:S,releaseStatesOfObject:v,releaseStatesOfProgram:C,initAttributes:x,enableAttribute:g,disableUnusedAttributes:b}}function d2(i,t,e){let n;function s(c){n=c}function r(c,l){i.drawArrays(n,c,l),e.update(l,n,1)}function a(c,l,h){h!==0&&(i.drawArraysInstanced(n,c,l,h),e.update(l,n,h))}function o(c,l,h){if(h===0)return;t.get("WEBGL_multi_draw").multiDrawArraysWEBGL(n,c,0,l,0,h);let u=0;for(let d=0;d<h;d++)u+=l[d];e.update(u,n,1)}this.setMode=s,this.render=r,this.renderInstances=a,this.renderMultiDraw=o}function f2(i,t,e,n){let s;function r(){if(s!==void 0)return s;if(t.has("EXT_texture_filter_anisotropic")===!0){let C=t.get("EXT_texture_filter_anisotropic");s=i.getParameter(C.MAX_TEXTURE_MAX_ANISOTROPY_EXT)}else s=0;return s}function a(C){return!(C!==ei&&n.convert(C)!==i.getParameter(i.IMPLEMENTATION_COLOR_READ_FORMAT))}function o(C){let v=C===mn&&(t.has("EXT_color_buffer_half_float")||t.has("EXT_color_buffer_float"));return!(C!==kn&&C!==ti&&!v&&n.convert(C)!==i.getParameter(i.IMPLEMENTATION_COLOR_READ_TYPE))}function c(C){if(C==="highp"){if(i.getShaderPrecisionFormat(i.VERTEX_SHADER,i.HIGH_FLOAT).precision>0&&i.getShaderPrecisionFormat(i.FRAGMENT_SHADER,i.HIGH_FLOAT).precision>0)return"highp";C="mediump"}return C==="mediump"&&i.getShaderPrecisionFormat(i.VERTEX_SHADER,i.MEDIUM_FLOAT).precision>0&&i.getShaderPrecisionFormat(i.FRAGMENT_SHADER,i.MEDIUM_FLOAT).precision>0?"mediump":"lowp"}let l=e.precision!==void 0?e.precision:"highp",h=c(l);h!==l&&(pe("WebGLRenderer:",l,"not supported, using",h,"instead."),l=h);let f=e.logarithmicDepthBuffer===!0,u=e.reversedDepthBuffer===!0&&t.has("EXT_clip_control");e.reversedDepthBuffer===!0&&u===!1&&pe("WebGLRenderer: Unable to use reversed depth buffer due to missing EXT_clip_control extension. Fallback to default depth buffer.");let d=i.getParameter(i.MAX_TEXTURE_IMAGE_UNITS),m=i.getParameter(i.MAX_VERTEX_TEXTURE_IMAGE_UNITS),x=i.getParameter(i.MAX_TEXTURE_SIZE),g=i.getParameter(i.MAX_CUBE_MAP_TEXTURE_SIZE),p=i.getParameter(i.MAX_VERTEX_ATTRIBS),b=i.getParameter(i.MAX_VERTEX_UNIFORM_VECTORS),E=i.getParameter(i.MAX_VARYING_VECTORS),y=i.getParameter(i.MAX_FRAGMENT_UNIFORM_VECTORS),w=i.getParameter(i.MAX_SAMPLES),S=i.getParameter(i.SAMPLES);return{isWebGL2:!0,getMaxAnisotropy:r,getMaxPrecision:c,textureFormatReadable:a,textureTypeReadable:o,precision:l,logarithmicDepthBuffer:f,reversedDepthBuffer:u,maxTextures:d,maxVertexTextures:m,maxTextureSize:x,maxCubemapSize:g,maxAttributes:p,maxVertexUniforms:b,maxVaryings:E,maxFragmentUniforms:y,maxSamples:w,samples:S}}function p2(i){let t=this,e=null,n=0,s=!1,r=!1,a=new ci,o=new ve,c={value:null,needsUpdate:!1};this.uniform=c,this.numPlanes=0,this.numIntersection=0,this.init=function(f,u){let d=f.length!==0||u||n!==0||s;return s=u,n=f.length,d},this.beginShadows=function(){r=!0,h(null)},this.endShadows=function(){r=!1},this.setGlobalState=function(f,u){e=h(f,u,0)},this.setState=function(f,u,d){let m=f.clippingPlanes,x=f.clipIntersection,g=f.clipShadows,p=i.get(f);if(!s||m===null||m.length===0||r&&!g)r?h(null):l();else{let b=r?0:n,E=b*4,y=p.clippingState||null;c.value=y,y=h(m,u,E,d);for(let w=0;w!==E;++w)y[w]=e[w];p.clippingState=y,this.numIntersection=x?this.numPlanes:0,this.numPlanes+=b}};function l(){c.value!==e&&(c.value=e,c.needsUpdate=n>0),t.numPlanes=n,t.numIntersection=0}function h(f,u,d,m){let x=f!==null?f.length:0,g=null;if(x!==0){if(g=c.value,m!==!0||g===null){let p=d+x*4,b=u.matrixWorldInverse;o.getNormalMatrix(b),(g===null||g.length<p)&&(g=new Float32Array(p));for(let E=0,y=d;E!==x;++E,y+=4)a.copy(f[E]).applyMatrix4(b,o),a.normal.toArray(g,y),g[y+3]=a.constant}c.value=g,c.needsUpdate=!0}return t.numPlanes=x,t.numIntersection=0,g}}var Lr=4,m2=6,g2=20,x2=256,ro=new ds,Gd=new oe,fh=null,ph=0,mh=0,gh=!1,_2=new D,Ps=new D,Tc=class{constructor(t){this._renderer=t,this._pingPongRenderTarget=null,this._lodMax=0,this._cubeSize=0,this._sizeLods=[],this._lodMeshes=[],this._backgroundBox=null,this._cubemapMaterial=null,this._equirectMaterial=null,this._blurMaterial=null,this._ggxMaterial=null}fromScene(t,e=0,n=.1,s=100,r={}){let{size:a=256,position:o=_2}=r;fh=this._renderer.getRenderTarget(),ph=this._renderer.getActiveCubeFace(),mh=this._renderer.getActiveMipmapLevel(),gh=this._renderer.xr.enabled,this._renderer.xr.enabled=!1,this._setSize(a);let c=this._allocateTargets();return c.depthBuffer=!0,this._sceneToCubeUV(t,n,s,c,o),e>0&&this._blur(c,0,0,e),this._applyPMREM(c),this._cleanup(c),c}fromEquirectangular(t,e=null){return this._fromTexture(t,e)}fromCubemap(t,e=null){return this._fromTexture(t,e)}compileCubemapShader(){this._cubemapMaterial===null&&(this._cubemapMaterial=$d(),this._compileMaterial(this._cubemapMaterial))}compileEquirectangularShader(){this._equirectMaterial===null&&(this._equirectMaterial=Xd(),this._compileMaterial(this._equirectMaterial))}dispose(){this._dispose(),this._cubemapMaterial!==null&&this._cubemapMaterial.dispose(),this._equirectMaterial!==null&&this._equirectMaterial.dispose(),this._backgroundBox!==null&&(this._backgroundBox.geometry.dispose(),this._backgroundBox.material.dispose())}_setSize(t){this._lodMax=Math.floor(Math.log2(t)),this._cubeSize=Math.pow(2,this._lodMax)}_dispose(){this._blurMaterial!==null&&this._blurMaterial.dispose(),this._ggxMaterial!==null&&this._ggxMaterial.dispose(),this._pingPongRenderTarget!==null&&this._pingPongRenderTarget.dispose();for(let t=0;t<this._lodMeshes.length;t++)this._lodMeshes[t].geometry.dispose()}_cleanup(t){this._renderer.setRenderTarget(fh,ph,mh),this._renderer.xr.enabled=gh,t.scissorTest=!1,Pr(t,0,0,t.width,t.height)}_fromTexture(t,e){t.mapping===ms||t.mapping===Cs?this._setSize(t.image.length===0?16:t.image[0].width||t.image[0].image.width):this._setSize(t.image.width/4),fh=this._renderer.getRenderTarget(),ph=this._renderer.getActiveCubeFace(),mh=this._renderer.getActiveMipmapLevel(),gh=this._renderer.xr.enabled,this._renderer.xr.enabled=!1;let n=e||this._allocateTargets();return this._textureToCubeUV(t,n),this._applyPMREM(n),this._cleanup(n),n}_allocateTargets(){let t=3*Math.max(this._cubeSize,112),e=4*this._cubeSize,n={magFilter:An,minFilter:An,generateMipmaps:!1,type:mn,format:ei,colorSpace:aa,depthBuffer:!1},s=Wd(t,e,n);if(this._pingPongRenderTarget===null||this._pingPongRenderTarget.width!==t||this._pingPongRenderTarget.height!==e){this._pingPongRenderTarget!==null&&this._dispose(),this._pingPongRenderTarget=Wd(t,e,n);let{_lodMax:r}=this;({lodMeshes:this._lodMeshes,sizeLods:this._sizeLods}=v2(r)),this._blurMaterial=M2(r,t,e),this._ggxMaterial=y2(r,t,e)}return s}_compileMaterial(t){let e=new we(new Le,t);this._renderer.compile(e,ro)}_sceneToCubeUV(t,e,n,s,r){let c=new Tn(90,1,e,n),l=[1,-1,1,1,1,1],h=[1,1,1,-1,-1,-1],f=this._renderer,u=f.autoClear,d=f.toneMapping;f.getClearColor(Gd),f.toneMapping=fi,f.autoClear=!1,f.state.buffers.depth.getReversed()&&(f.setRenderTarget(s),f.clearDepth(),f.setRenderTarget(null)),this._backgroundBox===null&&(this._backgroundBox=new we(new xr,new hn({name:"PMREM.Background",side:Rn,depthWrite:!1,depthTest:!1})));let x=this._backgroundBox,g=x.material,p=!1,b=t.background;b?b.isColor&&(g.color.copy(b),t.background=null,p=!0):(g.color.copy(Gd),p=!0);for(let E=0;E<6;E++){let y=E%3;y===0?(c.up.set(0,l[E],0),c.position.set(r.x,r.y,r.z),c.lookAt(r.x+h[E],r.y,r.z)):y===1?(c.up.set(0,0,l[E]),c.position.set(r.x,r.y,r.z),c.lookAt(r.x,r.y+h[E],r.z)):(c.up.set(0,l[E],0),c.position.set(r.x,r.y,r.z),c.lookAt(r.x,r.y,r.z+h[E]));let w=this._cubeSize;Pr(s,y*w,E>2?w:0,w,w),f.setRenderTarget(s),p&&f.render(x,c),f.render(t,c)}f.toneMapping=d,f.autoClear=u,t.background=b}_textureToCubeUV(t,e){let n=this._renderer,s=t.mapping===ms||t.mapping===Cs;s?(this._cubemapMaterial===null&&(this._cubemapMaterial=$d()),this._cubemapMaterial.uniforms.flipEnvMap.value=t.isRenderTargetTexture===!1?-1:1):this._equirectMaterial===null&&(this._equirectMaterial=Xd());let r=s?this._cubemapMaterial:this._equirectMaterial,a=this._lodMeshes[0];a.material=r;let o=r.uniforms;o.envMap.value=t;let c=this._cubeSize;Pr(e,0,0,3*c,2*c),n.setRenderTarget(e),n.render(a,ro)}_applyPMREM(t){let e=this._renderer,n=e.autoClear;e.autoClear=!1;let s=this._lodMeshes.length;for(let r=1;r<s;r++)this._applyGGXFilter(t,r-1,r);e.autoClear=n}_applyGGXFilter(t,e,n){let s=this._renderer,r=this._pingPongRenderTarget,a=this._ggxMaterial,o=this._lodMeshes[n];o.material=a;let c=a.uniforms,l=n/(this._lodMeshes.length-1),h=e/(this._lodMeshes.length-1),f=Math.sqrt(l*l-h*h),u=l*1.25,d=f*u,{_lodMax:m}=this,x=this._sizeLods[n],g=3*x*(n>m-Lr?n-m+Lr:0),p=4*(this._cubeSize-x);c.envMap.value=t.texture,c.roughness.value=d,c.mipInt.value=m-e,Pr(r,g,p,3*x,2*x),s.setRenderTarget(r),s.render(o,ro),c.envMap.value=r.texture,c.roughness.value=0,c.mipInt.value=m-n,Pr(t,g,p,3*x,2*x),s.setRenderTarget(t),s.render(o,ro)}_blur(t,e,n,s){let r=this._pingPongRenderTarget,a=Math.min(s,Math.PI)/Math.SQRT2;this._blurPass(t,r,e,n,a),this._blurPass(r,t,n,n,a)}_blurPass(t,e,n,s,r){let a=this._renderer,o=this._blurMaterial,c=this._lodMeshes[s];c.material=o;let l=o.uniforms;l.envMap.value=t.texture,l.sigma.value=r,l.mipInt.value=this._lodMax-n;let h=this._sizeLods[s],f=3*h*(s>this._lodMax-Lr?s-this._lodMax+Lr:0),u=4*(this._cubeSize-h);Pr(e,f,u,3*h,2*h),a.setRenderTarget(e),a.render(c,ro)}};function v2(i){let t=[],e=[],n=i,s=i-Lr+1+m2;for(let r=0;r<s;r++){let a=Math.pow(2,n);t.push(a);let o=1/(a-2),c=-o,l=1+o,h=[c,c,l,c,l,l,c,c,l,l,c,l],f=6,u=6,d=3,m=new Float32Array(d*u*f),x=new Float32Array(d*u*f);for(let p=0;p<f;p++){let b=p%3*2/3-1,E=p>2?0:-1,y=[b,E,0,b+2/3,E,0,b+2/3,E+1,0,b,E,0,b+2/3,E+1,0,b,E+1,0];m.set(y,d*u*p);for(let w=0;w<u;w++){let S=h[w*2]*2-1,C=h[w*2+1]*2-1;p===0?Ps.set(1,C,S):p===1?Ps.set(-S,1,-C):p===2?Ps.set(-S,C,1):p===3?Ps.set(-1,C,-S):p===4?Ps.set(-S,-1,C):Ps.set(S,C,-1),Ps.toArray(x,(p*u+w)*d)}}let g=new Le;g.setAttribute("position",new ln(m,d)),g.setAttribute("outputDirection",new ln(x,d)),e.push(new we(g,null)),n>Lr&&n--}return{lodMeshes:e,sizeLods:t}}function Wd(i,t,e){let n=new sn(i,t,e);return n.texture.mapping=Ka,n.texture.name="PMREM.cubeUv",n.scissorTest=!0,n}function Pr(i,t,e,n,s){i.viewport.set(t,e,n,s),i.scissor.set(t,e,n,s)}function y2(i,t,e){return new Ge({name:"PMREMGGXConvolution",defines:{GGX_SAMPLES:x2,CUBEUV_TEXEL_WIDTH:1/t,CUBEUV_TEXEL_HEIGHT:1/e,CUBEUV_MAX_MIP:`${i}.0`},uniforms:{envMap:{value:null},roughness:{value:0},mipInt:{value:0}},vertexShader:Cc(),fragmentShader:`

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
		`,blending:Qn,depthTest:!1,depthWrite:!1})}function M2(i,t,e){return new Ge({name:"SphericalGaussianBlur",defines:{SAMPLES:g2,CUBEUV_TEXEL_WIDTH:1/t,CUBEUV_TEXEL_HEIGHT:1/e,CUBEUV_MAX_MIP:`${i}.0`},uniforms:{envMap:{value:null},sigma:{value:0},mipInt:{value:0}},vertexShader:Cc(),fragmentShader:`

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
		`,blending:Qn,depthTest:!1,depthWrite:!1})}function Xd(){return new Ge({name:"EquirectangularToCubeUV",uniforms:{envMap:{value:null}},vertexShader:Cc(),fragmentShader:`

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
		`,blending:Qn,depthTest:!1,depthWrite:!1})}function $d(){return new Ge({name:"CubemapToCubeUV",uniforms:{envMap:{value:null},flipEnvMap:{value:-1}},vertexShader:Cc(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			uniform float flipEnvMap;

			varying vec3 vOutputDirection;

			uniform samplerCube envMap;

			void main() {

				gl_FragColor = textureCube( envMap, vec3( flipEnvMap * vOutputDirection.x, vOutputDirection.yz ) );

			}
		`,blending:Qn,depthTest:!1,depthWrite:!1})}function Cc(){return`

		precision mediump float;
		precision mediump int;

		attribute vec3 outputDirection;

		varying vec3 vOutputDirection;

		void main() {

			vOutputDirection = outputDirection;
			gl_Position = vec4( position, 1.0 );

		}
	`}var Ac=class extends sn{constructor(t=1,e={}){super(t,t,e),this.isWebGLCubeRenderTarget=!0;let n={width:t,height:t,depth:1},s=[n,n,n,n,n,n];this.texture=new _a(s),this._setTextureOptions(e),this.texture.isRenderTargetTexture=!0}fromEquirectangularTexture(t,e){this.texture.type=e.type,this.texture.colorSpace=e.colorSpace,this.texture.generateMipmaps=e.generateMipmaps,this.texture.minFilter=e.minFilter,this.texture.magFilter=e.magFilter;let n={uniforms:{tEquirect:{value:null}},vertexShader:`

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
			`},s=new xr(5,5,5),r=new Ge({name:"CubemapFromEquirect",uniforms:Is(n.uniforms),vertexShader:n.vertexShader,fragmentShader:n.fragmentShader,side:Rn,blending:Qn});r.uniforms.tEquirect.value=e;let a=new we(s,r),o=e.minFilter;return e.minFilter===Ti&&(e.minFilter=An),new Dl(1,10,this).update(t,a),e.minFilter=o,a.geometry.dispose(),a.material.dispose(),this}clear(t,e=!0,n=!0,s=!0){let r=t.getRenderTarget();for(let a=0;a<6;a++)t.setRenderTarget(this,a),t.clear(e,n,s);t.setRenderTarget(r)}};function b2(i){let t=new WeakMap,e=new WeakMap,n=null;function s(u,d=!1){return u==null?null:d?a(u):r(u)}function r(u){if(u&&u.isTexture){let d=u.mapping;if(d===Rr||d===Fl)if(t.has(u)){let m=t.get(u).texture;return o(m,u.mapping)}else{let m=u.image;if(m&&m.height>0){let x=new Ac(m.height);return x.fromEquirectangularTexture(i,u),t.set(u,x),u.addEventListener("dispose",l),o(x.texture,u.mapping)}else return null}}return u}function a(u){if(u&&u.isTexture){let d=u.mapping,m=d===Rr||d===Fl,x=d===ms||d===Cs;if(m||x){let g=e.get(u),p=g!==void 0?g.texture.pmremVersion:0;if(u.isRenderTargetTexture&&u.pmremVersion!==p)return n===null&&(n=new Tc(i)),g=m?n.fromEquirectangular(u,g):n.fromCubemap(u,g),g.texture.pmremVersion=u.pmremVersion,e.set(u,g),g.texture;if(g!==void 0)return g.texture;{let b=u.image;return m&&b&&b.height>0||x&&b&&c(b)?(n===null&&(n=new Tc(i)),g=m?n.fromEquirectangular(u):n.fromCubemap(u),g.texture.pmremVersion=u.pmremVersion,e.set(u,g),u.addEventListener("dispose",h),g.texture):null}}}return u}function o(u,d){return d===Rr?u.mapping=ms:d===Fl&&(u.mapping=Cs),u}function c(u){let d=0,m=6;for(let x=0;x<m;x++)u[x]!==void 0&&d++;return d===m}function l(u){let d=u.target;d.removeEventListener("dispose",l);let m=t.get(d);m!==void 0&&(t.delete(d),m.dispose())}function h(u){let d=u.target;d.removeEventListener("dispose",h);let m=e.get(d);m!==void 0&&(e.delete(d),m.dispose())}function f(){t=new WeakMap,e=new WeakMap,n!==null&&(n.dispose(),n=null)}return{get:s,dispose:f}}function S2(i){let t={};function e(n){if(t[n]!==void 0)return t[n];let s=i.getExtension(n);return t[n]=s,s}return{has:function(n){return e(n)!==null},init:function(){e("EXT_color_buffer_float"),e("WEBGL_clip_cull_distance"),e("OES_texture_float_linear"),e("EXT_color_buffer_half_float"),e("WEBGL_multisampled_render_to_texture"),e("WEBGL_render_shared_exponent")},get:function(n){let s=e(n);return s===null&&ws("WebGLRenderer: "+n+" extension not supported."),s}}}function w2(i,t,e,n){let s={},r=new WeakMap;function a(f){let u=f.target;u.index!==null&&t.remove(u.index);for(let m in u.attributes)t.remove(u.attributes[m]);u.removeEventListener("dispose",a),delete s[u.id];let d=r.get(u);d&&(t.remove(d),r.delete(u)),n.releaseStatesOfGeometry(u),u.isInstancedBufferGeometry===!0&&delete u._maxInstanceCount,e.memory.geometries--}function o(f,u){return s[u.id]===!0||(u.addEventListener("dispose",a),s[u.id]=!0,e.memory.geometries++),u}function c(f){let u=f.attributes;for(let d in u)t.update(u[d],i.ARRAY_BUFFER)}function l(f){let u=[],d=f.index,m=f.attributes.position,x=0;if(m===void 0)return;if(d!==null){let b=d.array;x=d.version;for(let E=0,y=b.length;E<y;E+=3){let w=b[E+0],S=b[E+1],C=b[E+2];u.push(w,S,S,C,C,w)}}else{let b=m.array;x=m.version;for(let E=0,y=b.length/3-1;E<y;E+=3){let w=E+0,S=E+1,C=E+2;u.push(w,S,S,C,C,w)}}let g=new(m.count>=65535?da:ua)(u,1);g.version=x;let p=r.get(f);p&&t.remove(p),r.set(f,g)}function h(f){let u=r.get(f);if(u){let d=f.index;d!==null&&u.version<d.version&&l(f)}else l(f);return r.get(f)}return{get:o,update:c,getWireframeAttribute:h}}function E2(i,t,e){let n;function s(f){n=f}let r,a;function o(f){r=f.type,a=f.bytesPerElement}function c(f,u){i.drawElements(n,u,r,f*a),e.update(u,n,1)}function l(f,u,d){d!==0&&(i.drawElementsInstanced(n,u,r,f*a,d),e.update(u,n,d))}function h(f,u,d){if(d===0)return;t.get("WEBGL_multi_draw").multiDrawElementsWEBGL(n,u,0,r,f,0,d);let x=0;for(let g=0;g<d;g++)x+=u[g];e.update(x,n,1)}this.setMode=s,this.setIndex=o,this.render=c,this.renderInstances=l,this.renderMultiDraw=h}function T2(i){let t={geometries:0,textures:0},e={frame:0,calls:0,triangles:0,points:0,lines:0};function n(r,a,o){switch(e.calls++,a){case i.TRIANGLES:e.triangles+=o*(r/3);break;case i.LINES:e.lines+=o*(r/2);break;case i.LINE_STRIP:e.lines+=o*(r-1);break;case i.LINE_LOOP:e.lines+=o*r;break;case i.POINTS:e.points+=o*r;break;default:fe("WebGLInfo: Unknown draw mode:",a);break}}function s(){e.calls=0,e.triangles=0,e.points=0,e.lines=0}return{memory:t,render:e,programs:null,autoReset:!0,reset:s,update:n}}function A2(i,t,e){let n=new WeakMap,s=new je;function r(a,o,c){let l=a.morphTargetInfluences,h=o.morphAttributes.position||o.morphAttributes.normal||o.morphAttributes.color,f=h!==void 0?h.length:0,u=n.get(o);if(u===void 0||u.count!==f){let R=function(){C.dispose(),n.delete(o),o.removeEventListener("dispose",R)};u!==void 0&&u.texture.dispose();let d=o.morphAttributes.position!==void 0,m=o.morphAttributes.normal!==void 0,x=o.morphAttributes.color!==void 0,g=o.morphAttributes.position||[],p=o.morphAttributes.normal||[],b=o.morphAttributes.color||[],E=0;d===!0&&(E=1),m===!0&&(E=2),x===!0&&(E=3);let y=o.attributes.position.count*E,w=1;y>t.maxTextureSize&&(w=Math.ceil(y/t.maxTextureSize),y=t.maxTextureSize);let S=new Float32Array(y*w*4*f),C=new ca(S,y,w,f);C.type=ti,C.needsUpdate=!0;let v=E*4;for(let I=0;I<f;I++){let N=g[I],L=p[I],O=b[I],P=y*w*4*I;for(let W=0;W<N.count;W++){let it=W*v;d===!0&&(s.fromBufferAttribute(N,W),S[P+it+0]=s.x,S[P+it+1]=s.y,S[P+it+2]=s.z,S[P+it+3]=0),m===!0&&(s.fromBufferAttribute(L,W),S[P+it+4]=s.x,S[P+it+5]=s.y,S[P+it+6]=s.z,S[P+it+7]=0),x===!0&&(s.fromBufferAttribute(O,W),S[P+it+8]=s.x,S[P+it+9]=s.y,S[P+it+10]=s.z,S[P+it+11]=O.itemSize===4?s.w:1)}}u={count:f,texture:C,size:new yt(y,w)},n.set(o,u),o.addEventListener("dispose",R)}if(a.isInstancedMesh===!0&&a.morphTexture!==null)c.getUniforms().setValue(i,"morphTexture",a.morphTexture,e);else{let d=0;for(let x=0;x<l.length;x++)d+=l[x];let m=o.morphTargetsRelative?1:1-d;c.getUniforms().setValue(i,"morphTargetBaseInfluence",m),c.getUniforms().setValue(i,"morphTargetInfluences",l)}c.getUniforms().setValue(i,"morphTargetsTexture",u.texture,e),c.getUniforms().setValue(i,"morphTargetsTextureSize",u.size)}return{update:r}}function R2(i,t,e,n,s){let r=new WeakMap;function a(l){let h=s.render.frame,f=l.geometry,u=t.get(l,f);if(r.get(u)!==h&&(t.update(u),r.set(u,h)),l.isInstancedMesh&&(l.hasEventListener("dispose",c)===!1&&l.addEventListener("dispose",c),r.get(l)!==h&&(e.update(l.instanceMatrix,i.ARRAY_BUFFER),l.instanceColor!==null&&e.update(l.instanceColor,i.ARRAY_BUFFER),r.set(l,h))),l.isSkinnedMesh){let d=l.skeleton;r.get(d)!==h&&(d.update(),r.set(d,h))}return u}function o(){r=new WeakMap}function c(l){let h=l.target;h.removeEventListener("dispose",c),n.releaseStatesOfObject(h),e.remove(h.instanceMatrix),h.instanceColor!==null&&e.remove(h.instanceColor)}return{update:a,dispose:o}}var C2={[Xa]:"LINEAR_TONE_MAPPING",[$a]:"REINHARD_TONE_MAPPING",[qa]:"CINEON_TONE_MAPPING",[Rs]:"ACES_FILMIC_TONE_MAPPING",[Za]:"AGX_TONE_MAPPING",[Ja]:"NEUTRAL_TONE_MAPPING",[Ya]:"CUSTOM_TONE_MAPPING"};function I2(i,t,e,n,s,r){let a=new sn(t,e,{type:i,depthBuffer:s,stencilBuffer:r,samples:n?4:0,storeMultisampledDepthBuffer:!1,storeMultisampledStencilBuffer:!1,resolveDepthBuffer:!1,resolveStencilBuffer:!1}),o=null,c=null,l=new Le;l.setAttribute("position",new ge([-1,3,0,-1,-1,0,3,-1,0],3)),l.setAttribute("uv",new ge([0,2,0,0,2,0],2));let h=new Sr({uniforms:{tDiffuse:{value:null}},vertexShader:`
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
			}`,depthTest:!1,depthWrite:!1}),f=new we(l,h),u=new ds(-1,1,1,-1,0,1),d=null,m=null,x=!1,g,p=null,b=[],E=!1;this.setSize=function(y,w){a.setSize(y,w),o!==null&&o.setSize(y,w),c!==null&&c.setSize(y,w);for(let S=0;S<b.length;S++){let C=b[S];C.setSize&&C.setSize(y,w)}},this.setEffects=function(y){b=y,E=b.length>0&&b[0].isRenderPass===!0;let w=a.width,S=a.height;b.length>0&&o===null&&(o=new sn(w,S,{type:mn,depthBuffer:!1,stencilBuffer:!1}),c=new sn(w,S,{type:mn,depthBuffer:!1,stencilBuffer:!1}));for(let C=0;C<b.length;C++){let v=b[C];v.setSize&&v.setSize(w,S)}},this.begin=function(y,w){if(x||y.toneMapping===fi&&b.length===0)return!1;if(p=w,w!==null){let S=w.width,C=w.height;(a.width!==S||a.height!==C)&&this.setSize(S,C)}return E===!1&&y.setRenderTarget(a),g=y.toneMapping,y.toneMapping=fi,!0},this.hasRenderPass=function(){return E},this.end=function(y,w){y.toneMapping=g,x=!0;let S=a,C=o;for(let v=0;v<b.length;v++){let R=b[v];R.enabled!==!1&&(R.render(y,C,S,w),R.needsSwap!==!1&&(S=C,C=C===o?c:o))}if(d!==y.outputColorSpace||m!==y.toneMapping){d=y.outputColorSpace,m=y.toneMapping,h.defines={},Re.getTransfer(d)===Oe&&(h.defines.SRGB_TRANSFER="");let v=C2[m];v&&(h.defines[v]=""),h.needsUpdate=!0}h.uniforms.tDiffuse.value=S.texture,y.setRenderTarget(p),y.render(f,u),p=null,x=!1},this.isCompositing=function(){return x},this.dispose=function(){a.dispose(),o!==null&&o.dispose(),c!==null&&c.dispose(),l.dispose(),h.dispose()}}var ff=new Sn,vh=new os(1,1),pf=new ca,mf=new dl,gf=new _a,qd=[],Yd=[],Zd=new Float32Array(16),Jd=new Float32Array(9),Kd=new Float32Array(4);function Dr(i,t,e){let n=i[0];if(n<=0||n>0)return i;let s=t*e,r=qd[s];if(r===void 0&&(r=new Float32Array(s),qd[s]=r),t!==0){n.toArray(r,0);for(let a=1,o=0;a!==t;++a)o+=e,i[a].toArray(r,o)}return r}function gn(i,t){if(i.length!==t.length)return!1;for(let e=0,n=i.length;e<n;e++)if(i[e]!==t[e])return!1;return!0}function xn(i,t){for(let e=0,n=t.length;e<n;e++)i[e]=t[e]}function Ic(i,t){let e=Yd[t];e===void 0&&(e=new Int32Array(t),Yd[t]=e);for(let n=0;n!==t;++n)e[n]=i.allocateTextureUnit();return e}function P2(i,t){let e=this.cache;e[0]!==t&&(i.uniform1f(this.addr,t),e[0]=t)}function L2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y)&&(i.uniform2f(this.addr,t.x,t.y),e[0]=t.x,e[1]=t.y);else{if(gn(e,t))return;i.uniform2fv(this.addr,t),xn(e,t)}}function N2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z)&&(i.uniform3f(this.addr,t.x,t.y,t.z),e[0]=t.x,e[1]=t.y,e[2]=t.z);else if(t.r!==void 0)(e[0]!==t.r||e[1]!==t.g||e[2]!==t.b)&&(i.uniform3f(this.addr,t.r,t.g,t.b),e[0]=t.r,e[1]=t.g,e[2]=t.b);else{if(gn(e,t))return;i.uniform3fv(this.addr,t),xn(e,t)}}function D2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z||e[3]!==t.w)&&(i.uniform4f(this.addr,t.x,t.y,t.z,t.w),e[0]=t.x,e[1]=t.y,e[2]=t.z,e[3]=t.w);else{if(gn(e,t))return;i.uniform4fv(this.addr,t),xn(e,t)}}function U2(i,t){let e=this.cache,n=t.elements;if(n===void 0){if(gn(e,t))return;i.uniformMatrix2fv(this.addr,!1,t),xn(e,t)}else{if(gn(e,n))return;Kd.set(n),i.uniformMatrix2fv(this.addr,!1,Kd),xn(e,n)}}function F2(i,t){let e=this.cache,n=t.elements;if(n===void 0){if(gn(e,t))return;i.uniformMatrix3fv(this.addr,!1,t),xn(e,t)}else{if(gn(e,n))return;Jd.set(n),i.uniformMatrix3fv(this.addr,!1,Jd),xn(e,n)}}function O2(i,t){let e=this.cache,n=t.elements;if(n===void 0){if(gn(e,t))return;i.uniformMatrix4fv(this.addr,!1,t),xn(e,t)}else{if(gn(e,n))return;Zd.set(n),i.uniformMatrix4fv(this.addr,!1,Zd),xn(e,n)}}function B2(i,t){let e=this.cache;e[0]!==t&&(i.uniform1i(this.addr,t),e[0]=t)}function z2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y)&&(i.uniform2i(this.addr,t.x,t.y),e[0]=t.x,e[1]=t.y);else{if(gn(e,t))return;i.uniform2iv(this.addr,t),xn(e,t)}}function k2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z)&&(i.uniform3i(this.addr,t.x,t.y,t.z),e[0]=t.x,e[1]=t.y,e[2]=t.z);else{if(gn(e,t))return;i.uniform3iv(this.addr,t),xn(e,t)}}function H2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z||e[3]!==t.w)&&(i.uniform4i(this.addr,t.x,t.y,t.z,t.w),e[0]=t.x,e[1]=t.y,e[2]=t.z,e[3]=t.w);else{if(gn(e,t))return;i.uniform4iv(this.addr,t),xn(e,t)}}function V2(i,t){let e=this.cache;e[0]!==t&&(i.uniform1ui(this.addr,t),e[0]=t)}function G2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y)&&(i.uniform2ui(this.addr,t.x,t.y),e[0]=t.x,e[1]=t.y);else{if(gn(e,t))return;i.uniform2uiv(this.addr,t),xn(e,t)}}function W2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z)&&(i.uniform3ui(this.addr,t.x,t.y,t.z),e[0]=t.x,e[1]=t.y,e[2]=t.z);else{if(gn(e,t))return;i.uniform3uiv(this.addr,t),xn(e,t)}}function X2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z||e[3]!==t.w)&&(i.uniform4ui(this.addr,t.x,t.y,t.z,t.w),e[0]=t.x,e[1]=t.y,e[2]=t.z,e[3]=t.w);else{if(gn(e,t))return;i.uniform4uiv(this.addr,t),xn(e,t)}}function $2(i,t,e){let n=this.cache,s=e.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s);let r;this.type===i.SAMPLER_2D_SHADOW?(vh.compareFunction=e.isReversedDepthBuffer()?Sc:bc,r=vh):r=ff,e.setTexture2D(t||r,s)}function q2(i,t,e){let n=this.cache,s=e.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s),e.setTexture3D(t||mf,s)}function Y2(i,t,e){let n=this.cache,s=e.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s),e.setTextureCube(t||gf,s)}function Z2(i,t,e){let n=this.cache,s=e.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s),e.setTexture2DArray(t||pf,s)}function J2(i){switch(i){case 5126:return P2;case 35664:return L2;case 35665:return N2;case 35666:return D2;case 35674:return U2;case 35675:return F2;case 35676:return O2;case 5124:case 35670:return B2;case 35667:case 35671:return z2;case 35668:case 35672:return k2;case 35669:case 35673:return H2;case 5125:return V2;case 36294:return G2;case 36295:return W2;case 36296:return X2;case 35678:case 36198:case 36298:case 36306:case 35682:return $2;case 35679:case 36299:case 36307:return q2;case 35680:case 36300:case 36308:case 36293:return Y2;case 36289:case 36303:case 36311:case 36292:return Z2}}function K2(i,t){i.uniform1fv(this.addr,t)}function j2(i,t){let e=Dr(t,this.size,2);i.uniform2fv(this.addr,e)}function Q2(i,t){let e=Dr(t,this.size,3);i.uniform3fv(this.addr,e)}function tx(i,t){let e=Dr(t,this.size,4);i.uniform4fv(this.addr,e)}function ex(i,t){let e=Dr(t,this.size,4);i.uniformMatrix2fv(this.addr,!1,e)}function nx(i,t){let e=Dr(t,this.size,9);i.uniformMatrix3fv(this.addr,!1,e)}function ix(i,t){let e=Dr(t,this.size,16);i.uniformMatrix4fv(this.addr,!1,e)}function sx(i,t){i.uniform1iv(this.addr,t)}function rx(i,t){i.uniform2iv(this.addr,t)}function ax(i,t){i.uniform3iv(this.addr,t)}function ox(i,t){i.uniform4iv(this.addr,t)}function lx(i,t){i.uniform1uiv(this.addr,t)}function cx(i,t){i.uniform2uiv(this.addr,t)}function hx(i,t){i.uniform3uiv(this.addr,t)}function ux(i,t){i.uniform4uiv(this.addr,t)}function dx(i,t,e){let n=this.cache,s=t.length,r=Ic(e,s);gn(n,r)||(i.uniform1iv(this.addr,r),xn(n,r));let a;this.type===i.SAMPLER_2D_SHADOW?a=vh:a=ff;for(let o=0;o!==s;++o)e.setTexture2D(t[o]||a,r[o])}function fx(i,t,e){let n=this.cache,s=t.length,r=Ic(e,s);gn(n,r)||(i.uniform1iv(this.addr,r),xn(n,r));for(let a=0;a!==s;++a)e.setTexture3D(t[a]||mf,r[a])}function px(i,t,e){let n=this.cache,s=t.length,r=Ic(e,s);gn(n,r)||(i.uniform1iv(this.addr,r),xn(n,r));for(let a=0;a!==s;++a)e.setTextureCube(t[a]||gf,r[a])}function mx(i,t,e){let n=this.cache,s=t.length,r=Ic(e,s);gn(n,r)||(i.uniform1iv(this.addr,r),xn(n,r));for(let a=0;a!==s;++a)e.setTexture2DArray(t[a]||pf,r[a])}function gx(i){switch(i){case 5126:return K2;case 35664:return j2;case 35665:return Q2;case 35666:return tx;case 35674:return ex;case 35675:return nx;case 35676:return ix;case 5124:case 35670:return sx;case 35667:case 35671:return rx;case 35668:case 35672:return ax;case 35669:case 35673:return ox;case 5125:return lx;case 36294:return cx;case 36295:return hx;case 36296:return ux;case 35678:case 36198:case 36298:case 36306:case 35682:return dx;case 35679:case 36299:case 36307:return fx;case 35680:case 36300:case 36308:case 36293:return px;case 36289:case 36303:case 36311:case 36292:return mx}}var yh=class{constructor(t,e,n){this.id=t,this.addr=n,this.cache=[],this.type=e.type,this.setValue=J2(e.type)}},Mh=class{constructor(t,e,n){this.id=t,this.addr=n,this.cache=[],this.type=e.type,this.size=e.size,this.setValue=gx(e.type)}},bh=class{constructor(t){this.id=t,this.seq=[],this.map={}}setValue(t,e,n){let s=this.seq;for(let r=0,a=s.length;r!==a;++r){let o=s[r];o.setValue(t,e[o.id],n)}}},xh=/(\w+)(\])?(\[|\.)?/g;function jd(i,t){i.seq.push(t),i.map[t.id]=t}function xx(i,t,e){let n=i.name,s=n.length;for(xh.lastIndex=0;;){let r=xh.exec(n),a=xh.lastIndex,o=r[1],c=r[2]==="]",l=r[3];if(c&&(o=o|0),l===void 0||l==="["&&a+2===s){jd(e,l===void 0?new yh(o,i,t):new Mh(o,i,t));break}else{let f=e.map[o];f===void 0&&(f=new bh(o),jd(e,f)),e=f}}}var Nr=class{constructor(t,e){this.seq=[],this.map={};let n=t.getProgramParameter(e,t.ACTIVE_UNIFORMS);for(let a=0;a<n;++a){let o=t.getActiveUniform(e,a),c=t.getUniformLocation(e,o.name);xx(o,c,this)}let s=[],r=[];for(let a of this.seq)a.type===t.SAMPLER_2D_SHADOW||a.type===t.SAMPLER_CUBE_SHADOW||a.type===t.SAMPLER_2D_ARRAY_SHADOW?s.push(a):r.push(a);s.length>0&&(this.seq=s.concat(r))}setValue(t,e,n,s){let r=this.map[e];r!==void 0&&r.setValue(t,n,s)}setOptional(t,e,n){let s=e[n];s!==void 0&&this.setValue(t,n,s)}static upload(t,e,n,s){for(let r=0,a=e.length;r!==a;++r){let o=e[r],c=n[o.id];c.needsUpdate!==!1&&o.setValue(t,c.value,s)}}static seqWithValue(t,e){let n=[];for(let s=0,r=t.length;s!==r;++s){let a=t[s];a.id in e&&n.push(a)}return n}};function Qd(i,t,e){let n=i.createShader(t);return i.shaderSource(n,e),i.compileShader(n),n}var _x=37297,vx=0;function yx(i,t){let e=i.split(`
`),n=[],s=Math.max(t-6,0),r=Math.min(t+6,e.length);for(let a=s;a<r;a++){let o=a+1;n.push(`${o===t?">":" "} ${o}: ${e[a]}`)}return n.join(`
`)}var tf=new ve;function Mx(i){Re._getMatrix(tf,Re.workingColorSpace,i);let t=`mat3( ${tf.elements.map(e=>e.toFixed(4))} )`;switch(Re.getTransfer(i)){case oa:return[t,"LinearTransferOETF"];case Oe:return[t,"sRGBTransferOETF"];default:return pe("WebGLProgram: Unsupported color space: ",i),[t,"LinearTransferOETF"]}}function ef(i,t,e){let n=i.getShaderParameter(t,i.COMPILE_STATUS),r=(i.getShaderInfoLog(t)||"").trim();if(n&&r==="")return"";let a=/ERROR: 0:(\d+)/.exec(r);if(a){let o=parseInt(a[1]);return e.toUpperCase()+`

`+r+`

`+yx(i.getShaderSource(t),o)}else return r}function bx(i,t){let e=Mx(t);return[`vec4 ${i}( vec4 value ) {`,`	return ${e[1]}( vec4( value.rgb * ${e[0]}, value.a ) );`,"}"].join(`
`)}var Sx={[Xa]:"Linear",[$a]:"Reinhard",[qa]:"Cineon",[Rs]:"ACESFilmic",[Za]:"AgX",[Ja]:"Neutral",[Ya]:"Custom"};function wx(i,t){let e=Sx[t];return e===void 0?(pe("WebGLProgram: Unsupported toneMapping:",t),"vec3 "+i+"( vec3 color ) { return LinearToneMapping( color ); }"):"vec3 "+i+"( vec3 color ) { return "+e+"ToneMapping( color ); }"}var Ec=new D;function Ex(){Re.getLuminanceCoefficients(Ec);let i=Ec.x.toFixed(4),t=Ec.y.toFixed(4),e=Ec.z.toFixed(4);return["float luminance( const in vec3 rgb ) {",`	const vec3 weights = vec3( ${i}, ${t}, ${e} );`,"	return dot( weights, rgb );","}"].join(`
`)}function Tx(i){return[i.extensionClipCullDistance?"#extension GL_ANGLE_clip_cull_distance : require":"",i.extensionMultiDraw?"#extension GL_ANGLE_multi_draw : require":""].filter(oo).join(`
`)}function Ax(i){let t=[];for(let e in i){let n=i[e];n!==!1&&t.push("#define "+e+" "+n)}return t.join(`
`)}function Rx(i,t){let e={},n=i.getProgramParameter(t,i.ACTIVE_ATTRIBUTES);for(let s=0;s<n;s++){let r=i.getActiveAttrib(t,s),a=r.name,o=1;r.type===i.FLOAT_MAT2&&(o=2),r.type===i.FLOAT_MAT3&&(o=3),r.type===i.FLOAT_MAT4&&(o=4),e[a]={type:r.type,location:i.getAttribLocation(t,a),locationSize:o}}return e}function oo(i){return i!==""}function nf(i,t){let e=t.numSpotLightShadows+t.numSpotLightMaps-t.numSpotLightShadowsWithMaps;return i.replace(/NUM_SUN_LIGHTS/g,t.numSunLights).replace(/NUM_DIR_LIGHTS/g,t.numDirLights).replace(/NUM_SPOT_LIGHTS/g,t.numSpotLights).replace(/NUM_SPOT_LIGHT_MAPS/g,t.numSpotLightMaps).replace(/NUM_SPOT_LIGHT_COORDS/g,e).replace(/NUM_RECT_AREA_LIGHTS/g,t.numRectAreaLights).replace(/NUM_POINT_LIGHTS/g,t.numPointLights).replace(/NUM_HEMI_LIGHTS/g,t.numHemiLights).replace(/NUM_SUN_LIGHT_SHADOWS/g,t.numSunLightShadows).replace(/NUM_DIR_LIGHT_SHADOWS/g,t.numDirLightShadows).replace(/NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS/g,t.numSpotLightShadowsWithMaps).replace(/NUM_SPOT_LIGHT_SHADOWS/g,t.numSpotLightShadows).replace(/NUM_POINT_LIGHT_SHADOWS/g,t.numPointLightShadows)}function sf(i,t){return i.replace(/NUM_CLIPPING_PLANES/g,t.numClippingPlanes).replace(/UNION_CLIPPING_PLANES/g,t.numClippingPlanes-t.numClipIntersection)}var Cx=/^[ \t]*#include +<([\w\d./]+)>/gm;function Sh(i){return i.replace(Cx,Px)}var Ix=new Map;function Px(i,t){let e=Te[t];if(e===void 0){let n=Ix.get(t);if(n!==void 0)e=Te[n],pe('WebGLRenderer: Shader chunk "%s" has been deprecated. Use "%s" instead.',t,n);else throw new Error("THREE.WebGLProgram: Can not resolve #include <"+t+">")}return Sh(e)}var Lx=/#pragma unroll_loop_start\s+for\s*\(\s*int\s+i\s*=\s*(\d+)\s*;\s*i\s*<\s*(\d+)\s*;\s*i\s*\+\+\s*\)\s*{([\s\S]+?)}\s+#pragma unroll_loop_end/g;function rf(i){return i.replace(Lx,Nx)}function Nx(i,t,e,n){let s="";for(let r=parseInt(t);r<parseInt(e);r++)s+=n.replace(/\[\s*i\s*\]/g,"[ "+r+" ]").replace(/UNROLLED_LOOP_INDEX/g,r);return s}function af(i){let t=`precision ${i.precision} float;
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
#define LOW_PRECISION`),t}var Dx={[Wa]:"SHADOWMAP_TYPE_PCF",[Ar]:"SHADOWMAP_TYPE_VSM"};function Ux(i){return Dx[i.shadowMapType]||"SHADOWMAP_TYPE_BASIC"}var Fx={[ms]:"ENVMAP_TYPE_CUBE",[Cs]:"ENVMAP_TYPE_CUBE",[Ka]:"ENVMAP_TYPE_CUBE_UV"};function Ox(i){return i.envMap===!1?"ENVMAP_TYPE_CUBE":Fx[i.envMapMode]||"ENVMAP_TYPE_CUBE"}var Bx={[Cs]:"ENVMAP_MODE_REFRACTION"};function zx(i){return i.envMap===!1?"ENVMAP_MODE_REFLECTION":Bx[i.envMapMode]||"ENVMAP_MODE_REFLECTION"}var kx={[j0]:"ENVMAP_BLENDING_MULTIPLY",[vd]:"ENVMAP_BLENDING_MIX",[yd]:"ENVMAP_BLENDING_ADD"};function Hx(i){return i.envMap===!1?"ENVMAP_BLENDING_NONE":kx[i.combine]||"ENVMAP_BLENDING_NONE"}function Vx(i){let t=i.envMapCubeUVHeight;if(t===null)return null;let e=Math.log2(t)-2,n=1/t;return{texelWidth:1/(3*Math.max(Math.pow(2,e),112)),texelHeight:n,maxMip:e}}function Gx(i,t,e,n){let s=i.getContext(),r=e.defines,a=e.vertexShader,o=e.fragmentShader,c=Ux(e),l=Ox(e),h=zx(e),f=Hx(e),u=Vx(e),d=Tx(e),m=Ax(r),x=s.createProgram(),g,p,b=e.glslVersion?"#version "+e.glslVersion+`
`:"";e.isRawShaderMaterial?(g=["#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,m].filter(oo).join(`
`),g.length>0&&(g+=`
`),p=["#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,m].filter(oo).join(`
`),p.length>0&&(p+=`
`)):(g=[af(e),"#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,m,e.extensionClipCullDistance?"#define USE_CLIP_DISTANCE":"",e.batching?"#define USE_BATCHING":"",e.batchingColor?"#define USE_BATCHING_COLOR":"",e.instancing?"#define USE_INSTANCING":"",e.instancingColor?"#define USE_INSTANCING_COLOR":"",e.instancingMorph?"#define USE_INSTANCING_MORPH":"",e.useFog&&e.fog?"#define USE_FOG":"",e.useFog&&e.fogExp2?"#define FOG_EXP2":"",e.map?"#define USE_MAP":"",e.envMap?"#define USE_ENVMAP":"",e.envMap?"#define "+h:"",e.lightMap?"#define USE_LIGHTMAP":"",e.aoMap?"#define USE_AOMAP":"",e.bumpMap?"#define USE_BUMPMAP":"",e.normalMap?"#define USE_NORMALMAP":"",e.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",e.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",e.displacementMap?"#define USE_DISPLACEMENTMAP":"",e.emissiveMap?"#define USE_EMISSIVEMAP":"",e.anisotropy?"#define USE_ANISOTROPY":"",e.anisotropyMap?"#define USE_ANISOTROPYMAP":"",e.clearcoatMap?"#define USE_CLEARCOATMAP":"",e.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",e.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",e.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",e.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",e.specularMap?"#define USE_SPECULARMAP":"",e.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",e.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",e.roughnessMap?"#define USE_ROUGHNESSMAP":"",e.metalnessMap?"#define USE_METALNESSMAP":"",e.alphaMap?"#define USE_ALPHAMAP":"",e.alphaHash?"#define USE_ALPHAHASH":"",e.transmission?"#define USE_TRANSMISSION":"",e.transmissionMap?"#define USE_TRANSMISSIONMAP":"",e.thicknessMap?"#define USE_THICKNESSMAP":"",e.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",e.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",e.mapUv?"#define MAP_UV "+e.mapUv:"",e.alphaMapUv?"#define ALPHAMAP_UV "+e.alphaMapUv:"",e.lightMapUv?"#define LIGHTMAP_UV "+e.lightMapUv:"",e.aoMapUv?"#define AOMAP_UV "+e.aoMapUv:"",e.emissiveMapUv?"#define EMISSIVEMAP_UV "+e.emissiveMapUv:"",e.bumpMapUv?"#define BUMPMAP_UV "+e.bumpMapUv:"",e.normalMapUv?"#define NORMALMAP_UV "+e.normalMapUv:"",e.displacementMapUv?"#define DISPLACEMENTMAP_UV "+e.displacementMapUv:"",e.metalnessMapUv?"#define METALNESSMAP_UV "+e.metalnessMapUv:"",e.roughnessMapUv?"#define ROUGHNESSMAP_UV "+e.roughnessMapUv:"",e.anisotropyMapUv?"#define ANISOTROPYMAP_UV "+e.anisotropyMapUv:"",e.clearcoatMapUv?"#define CLEARCOATMAP_UV "+e.clearcoatMapUv:"",e.clearcoatNormalMapUv?"#define CLEARCOAT_NORMALMAP_UV "+e.clearcoatNormalMapUv:"",e.clearcoatRoughnessMapUv?"#define CLEARCOAT_ROUGHNESSMAP_UV "+e.clearcoatRoughnessMapUv:"",e.iridescenceMapUv?"#define IRIDESCENCEMAP_UV "+e.iridescenceMapUv:"",e.iridescenceThicknessMapUv?"#define IRIDESCENCE_THICKNESSMAP_UV "+e.iridescenceThicknessMapUv:"",e.sheenColorMapUv?"#define SHEEN_COLORMAP_UV "+e.sheenColorMapUv:"",e.sheenRoughnessMapUv?"#define SHEEN_ROUGHNESSMAP_UV "+e.sheenRoughnessMapUv:"",e.specularMapUv?"#define SPECULARMAP_UV "+e.specularMapUv:"",e.specularColorMapUv?"#define SPECULAR_COLORMAP_UV "+e.specularColorMapUv:"",e.specularIntensityMapUv?"#define SPECULAR_INTENSITYMAP_UV "+e.specularIntensityMapUv:"",e.transmissionMapUv?"#define TRANSMISSIONMAP_UV "+e.transmissionMapUv:"",e.thicknessMapUv?"#define THICKNESSMAP_UV "+e.thicknessMapUv:"",e.vertexTangents&&e.flatShading===!1?"#define USE_TANGENT":"",e.vertexNormals?"#define HAS_NORMAL":"",e.vertexColors?"#define USE_COLOR":"",e.vertexAlphas?"#define USE_COLOR_ALPHA":"",e.vertexUv1s?"#define USE_UV1":"",e.vertexUv2s?"#define USE_UV2":"",e.vertexUv3s?"#define USE_UV3":"",e.pointsUvs?"#define USE_POINTS_UV":"",e.flatShading?"#define FLAT_SHADED":"",e.skinning?"#define USE_SKINNING":"",e.morphTargets?"#define USE_MORPHTARGETS":"",e.morphNormals&&e.flatShading===!1?"#define USE_MORPHNORMALS":"",e.morphColors?"#define USE_MORPHCOLORS":"",e.morphTargetsCount>0?"#define MORPHTARGETS_TEXTURE_STRIDE "+e.morphTextureStride:"",e.morphTargetsCount>0?"#define MORPHTARGETS_COUNT "+e.morphTargetsCount:"",e.doubleSided?"#define DOUBLE_SIDED":"",e.flipSided?"#define FLIP_SIDED":"",e.shadowMapEnabled?"#define USE_SHADOWMAP":"",e.shadowMapEnabled?"#define "+c:"",e.sizeAttenuation?"#define USE_SIZEATTENUATION":"",e.numLightProbes>0?"#define USE_LIGHT_PROBES":"",e.logarithmicDepthBuffer?"#define USE_LOGARITHMIC_DEPTH_BUFFER":"",e.reversedDepthBuffer?"#define USE_REVERSED_DEPTH_BUFFER":"","uniform mat4 modelMatrix;","uniform mat4 modelViewMatrix;","uniform mat4 projectionMatrix;","uniform mat4 viewMatrix;","uniform mat3 normalMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;","#ifdef USE_INSTANCING","	attribute mat4 instanceMatrix;","#endif","#ifdef USE_INSTANCING_COLOR","	attribute vec3 instanceColor;","#endif","#ifdef USE_INSTANCING_MORPH","	uniform sampler2D morphTexture;","#endif","attribute vec3 position;","attribute vec3 normal;","attribute vec2 uv;","#ifdef USE_UV1","	attribute vec2 uv1;","#endif","#ifdef USE_UV2","	attribute vec2 uv2;","#endif","#ifdef USE_UV3","	attribute vec2 uv3;","#endif","#ifdef USE_TANGENT","	attribute vec4 tangent;","#endif","#if defined( USE_COLOR_ALPHA )","	attribute vec4 color;","#elif defined( USE_COLOR )","	attribute vec3 color;","#endif","#ifdef USE_SKINNING","	attribute vec4 skinIndex;","	attribute vec4 skinWeight;","#endif",`
`].filter(oo).join(`
`),p=[af(e),"#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,m,e.useFog&&e.fog?"#define USE_FOG":"",e.useFog&&e.fogExp2?"#define FOG_EXP2":"",e.alphaToCoverage?"#define ALPHA_TO_COVERAGE":"",e.map?"#define USE_MAP":"",e.matcap?"#define USE_MATCAP":"",e.envMap?"#define USE_ENVMAP":"",e.envMap?"#define "+l:"",e.envMap?"#define "+h:"",e.envMap?"#define "+f:"",u?"#define CUBEUV_TEXEL_WIDTH "+u.texelWidth:"",u?"#define CUBEUV_TEXEL_HEIGHT "+u.texelHeight:"",u?"#define CUBEUV_MAX_MIP "+u.maxMip+".0":"",e.lightMap?"#define USE_LIGHTMAP":"",e.aoMap?"#define USE_AOMAP":"",e.bumpMap?"#define USE_BUMPMAP":"",e.normalMap?"#define USE_NORMALMAP":"",e.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",e.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",e.packedNormalMap?"#define USE_PACKED_NORMALMAP":"",e.emissiveMap?"#define USE_EMISSIVEMAP":"",e.anisotropy?"#define USE_ANISOTROPY":"",e.anisotropyMap?"#define USE_ANISOTROPYMAP":"",e.clearcoat?"#define USE_CLEARCOAT":"",e.clearcoatMap?"#define USE_CLEARCOATMAP":"",e.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",e.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",e.dispersion?"#define USE_DISPERSION":"",e.retroreflection?"#define USE_RETROREFLECTION":"",e.iridescence?"#define USE_IRIDESCENCE":"",e.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",e.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",e.specularMap?"#define USE_SPECULARMAP":"",e.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",e.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",e.roughnessMap?"#define USE_ROUGHNESSMAP":"",e.metalnessMap?"#define USE_METALNESSMAP":"",e.alphaMap?"#define USE_ALPHAMAP":"",e.alphaTest?"#define USE_ALPHATEST":"",e.alphaHash?"#define USE_ALPHAHASH":"",e.sheen?"#define USE_SHEEN":"",e.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",e.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",e.transmission?"#define USE_TRANSMISSION":"",e.transmissionMap?"#define USE_TRANSMISSIONMAP":"",e.thicknessMap?"#define USE_THICKNESSMAP":"",e.vertexTangents&&e.flatShading===!1?"#define USE_TANGENT":"",e.vertexColors||e.instancingColor?"#define USE_COLOR":"",e.vertexAlphas||e.batchingColor?"#define USE_COLOR_ALPHA":"",e.vertexUv1s?"#define USE_UV1":"",e.vertexUv2s?"#define USE_UV2":"",e.vertexUv3s?"#define USE_UV3":"",e.pointsUvs?"#define USE_POINTS_UV":"",e.gradientMap?"#define USE_GRADIENTMAP":"",e.flatShading?"#define FLAT_SHADED":"",e.doubleSided?"#define DOUBLE_SIDED":"",e.flipSided?"#define FLIP_SIDED":"",e.shadowMapEnabled?"#define USE_SHADOWMAP":"",e.shadowMapEnabled?"#define "+c:"",e.premultipliedAlpha?"#define PREMULTIPLIED_ALPHA":"",e.numLightProbes>0?"#define USE_LIGHT_PROBES":"",e.numLightProbeGrids>0?"#define USE_LIGHT_PROBES_GRID":"",e.decodeVideoTexture?"#define DECODE_VIDEO_TEXTURE":"",e.decodeVideoTextureEmissive?"#define DECODE_VIDEO_TEXTURE_EMISSIVE":"",e.logarithmicDepthBuffer?"#define USE_LOGARITHMIC_DEPTH_BUFFER":"",e.reversedDepthBuffer?"#define USE_REVERSED_DEPTH_BUFFER":"","uniform mat4 viewMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;",e.toneMapping!==fi?"#define TONE_MAPPING":"",e.toneMapping!==fi?Te.tonemapping_pars_fragment:"",e.toneMapping!==fi?wx("toneMapping",e.toneMapping):"",e.dithering?"#define DITHERING":"",e.opaque?"#define OPAQUE":"",Te.colorspace_pars_fragment,bx("linearToOutputTexel",e.outputColorSpace),Ex(),e.useDepthPacking?"#define DEPTH_PACKING "+e.depthPacking:"",`
`].filter(oo).join(`
`)),a=Sh(a),a=nf(a,e),a=sf(a,e),o=Sh(o),o=nf(o,e),o=sf(o,e),a=rf(a),o=rf(o),e.isRawShaderMaterial!==!0&&(b=`#version 300 es
`,g=[d,"#define attribute in","#define varying out","#define texture2D texture"].join(`
`)+`
`+g,p=["#define varying in",e.glslVersion===oh?"":"layout(location = 0) out highp vec4 pc_fragColor;",e.glslVersion===oh?"":"#define gl_FragColor pc_fragColor","#define gl_FragDepthEXT gl_FragDepth","#define texture2D texture","#define textureCube texture","#define texture2DProj textureProj","#define texture2DLodEXT textureLod","#define texture2DProjLodEXT textureProjLod","#define textureCubeLodEXT textureLod","#define texture2DGradEXT textureGrad","#define texture2DProjGradEXT textureProjGrad","#define textureCubeGradEXT textureGrad"].join(`
`)+`
`+p);let E=b+g+a,y=b+p+o,w=Qd(s,s.VERTEX_SHADER,E),S=Qd(s,s.FRAGMENT_SHADER,y);s.attachShader(x,w),s.attachShader(x,S),e.index0AttributeName!==void 0?s.bindAttribLocation(x,0,e.index0AttributeName):e.hasPositionAttribute===!0&&s.bindAttribLocation(x,0,"position"),s.linkProgram(x);function C(N){if(i.debug.checkShaderErrors){let L=s.getProgramInfoLog(x)||"",O=s.getShaderInfoLog(w)||"",P=s.getShaderInfoLog(S)||"",W=L.trim(),it=O.trim(),Q=P.trim(),ht=!0,K=!0;if(s.getProgramParameter(x,s.LINK_STATUS)===!1)if(ht=!1,typeof i.debug.onShaderError=="function")i.debug.onShaderError(s,x,w,S);else{let ot=ef(s,w,"vertex"),z=ef(s,S,"fragment");fe("WebGLProgram: Shader Error "+s.getError()+" - VALIDATE_STATUS "+s.getProgramParameter(x,s.VALIDATE_STATUS)+`

Material Name: `+N.name+`
Material Type: `+N.type+`

Program Info Log: `+W+`
`+ot+`
`+z)}else W!==""?pe("WebGLProgram: Program Info Log:",W):(it===""||Q==="")&&(K=!1);K&&(N.diagnostics={runnable:ht,programLog:W,vertexShader:{log:it,prefix:g},fragmentShader:{log:Q,prefix:p}})}s.deleteShader(w),s.deleteShader(S),v=new Nr(s,x),R=Rx(s,x)}let v;this.getUniforms=function(){return v===void 0&&C(this),v};let R;this.getAttributes=function(){return R===void 0&&C(this),R};let I=e.rendererExtensionParallelShaderCompile===!1;return this.isReady=function(){return I===!1&&(I=s.getProgramParameter(x,_x)),I},this.destroy=function(){n.releaseStatesOfProgram(this),s.deleteProgram(x),this.program=void 0},this.type=e.shaderType,this.name=e.shaderName,this.id=vx++,this.cacheKey=t,this.usedTimes=1,this.program=x,this.vertexShader=w,this.fragmentShader=S,this}var Wx=0,wh=class{constructor(){this.shaderCache=new Map,this.materialCache=new Map}update(t,e,n){let s=this._getShaderCacheForMaterial(t);return s.has(e)===!1&&(s.add(e),e.usedTimes++),s.has(n)===!1&&(s.add(n),n.usedTimes++),this}remove(t){let e=this.materialCache.get(t);for(let n of e)n.usedTimes--,n.usedTimes===0&&this.shaderCache.delete(n.code);return this.materialCache.delete(t),this}getVertexShaderStage(t){return this._getShaderStage(t.vertexShader)}getFragmentShaderStage(t){return this._getShaderStage(t.fragmentShader)}dispose(){this.shaderCache.clear(),this.materialCache.clear()}_getShaderCacheForMaterial(t){let e=this.materialCache,n=e.get(t);return n===void 0&&(n=new Set,e.set(t,n)),n}_getShaderStage(t){let e=this.shaderCache,n=e.get(t);return n===void 0&&(n=new Eh(t),e.set(t,n)),n}},Eh=class{constructor(t){this.id=Wx++,this.code=t,this.usedTimes=0}};function Xx(i){return i===xs||i===io||i===so}function $x(i,t,e,n,s,r){let a=new dr,o=new wh,c=new Set,l=[],h=new Map,f=n.logarithmicDepthBuffer,u=n.precision,d={MeshDepthMaterial:"depth",MeshDistanceMaterial:"distance",MeshNormalMaterial:"normal",MeshBasicMaterial:"basic",MeshLambertMaterial:"lambert",MeshPhongMaterial:"phong",MeshToonMaterial:"toon",MeshStandardMaterial:"physical",MeshPhysicalMaterial:"physical",MeshMatcapMaterial:"matcap",LineBasicMaterial:"basic",LineDashedMaterial:"dashed",PointsMaterial:"points",ShadowMaterial:"shadow",SpriteMaterial:"sprite"};function m(v){return c.add(v),v===0?"uv":`uv${v}`}function x(v,R,I,N,L,O){let P=N.fog,W=L.geometry,it=v.isMeshStandardMaterial||v.isMeshLambertMaterial||v.isMeshPhongMaterial?N.environment:null,Q=v.isMeshStandardMaterial||v.isMeshLambertMaterial&&!v.envMap||v.isMeshPhongMaterial&&!v.envMap,ht=t.get(v.envMap||it,Q),K=ht&&ht.mapping===Ka?ht.image.height:null,ot=d[v.type];v.precision!==null&&(u=n.getMaxPrecision(v.precision),u!==v.precision&&pe("WebGLProgram.getParameters:",v.precision,"not supported, using",u,"instead."));let z=W.morphAttributes.position||W.morphAttributes.normal||W.morphAttributes.color,Mt=z!==void 0?z.length:0,vt=0;W.morphAttributes.position!==void 0&&(vt=1),W.morphAttributes.normal!==void 0&&(vt=2),W.morphAttributes.color!==void 0&&(vt=3);let Et,Ot,Lt,et;if(ot){let Be=Ri[ot];Et=Be.vertexShader,Ot=Be.fragmentShader}else{Et=v.vertexShader,Ot=v.fragmentShader;let Be=o.getVertexShaderStage(v),U=o.getFragmentShaderStage(v);o.update(v,Be,U),Lt=Be.id,et=U.id}let nt=i.getRenderTarget(),_t=i.state.buffers.depth.getReversed(),wt=L.isInstancedMesh===!0,pt=L.isBatchedMesh===!0,It=!!v.map,ee=!!v.matcap,V=!!ht,lt=!!v.aoMap,ct=!!v.lightMap,gt=!!v.bumpMap&&v.wireframe===!1,bt=!!v.normalMap,Bt=!!v.displacementMap,Ut=!!v.emissiveMap,Kt=!!v.metalnessMap,se=!!v.roughnessMap,F=v.anisotropy>0,re=v.clearcoat>0,ae=v.dispersion>0,T=v.retroreflectivity>0,_=v.iridescence>0,G=v.sheen>0,q=v.transmission>0,rt=F&&!!v.anisotropyMap,St=re&&!!v.clearcoatMap,Rt=re&&!!v.clearcoatNormalMap,tt=re&&!!v.clearcoatRoughnessMap,ft=_&&!!v.iridescenceMap,At=_&&!!v.iridescenceThicknessMap,Ht=G&&!!v.sheenColorMap,Nt=G&&!!v.sheenRoughnessMap,Tt=!!v.specularMap,Gt=!!v.specularColorMap,Jt=!!v.specularIntensityMap,he=q&&!!v.transmissionMap,B=q&&!!v.thicknessMap,Ft=!!v.gradientMap,mt=!!v.alphaMap,Dt=v.alphaTest>0,kt=!!v.alphaHash,ut=!!v.extensions,ie=fi;v.toneMapped&&(nt===null||nt.isXRRenderTarget===!0)&&(ie=i.toneMapping);let jt={shaderID:ot,shaderType:v.type,shaderName:v.name,vertexShader:Et,fragmentShader:Ot,defines:v.defines,customVertexShaderID:Lt,customFragmentShaderID:et,isRawShaderMaterial:v.isRawShaderMaterial===!0,glslVersion:v.glslVersion,precision:u,batching:pt,batchingColor:pt&&L._colorsTexture!==null,instancing:wt,instancingColor:wt&&L.instanceColor!==null,instancingMorph:wt&&L.morphTexture!==null,outputColorSpace:nt===null?i.outputColorSpace:nt.isXRRenderTarget===!0?nt.texture.colorSpace:Re.workingColorSpace,alphaToCoverage:!!v.alphaToCoverage,map:It,matcap:ee,envMap:V,envMapMode:V&&ht.mapping,envMapCubeUVHeight:K,aoMap:lt,lightMap:ct,bumpMap:gt,normalMap:bt,displacementMap:Bt,emissiveMap:Ut,normalMapObjectSpace:bt&&v.normalMapType===Sd,normalMapTangentSpace:bt&&v.normalMapType===Mc,packedNormalMap:bt&&v.normalMapType===Mc&&Xx(v.normalMap.format),metalnessMap:Kt,roughnessMap:se,anisotropy:F,anisotropyMap:rt,clearcoat:re,clearcoatMap:St,clearcoatNormalMap:Rt,clearcoatRoughnessMap:tt,dispersion:ae,retroreflection:T,iridescence:_,iridescenceMap:ft,iridescenceThicknessMap:At,sheen:G,sheenColorMap:Ht,sheenRoughnessMap:Nt,specularMap:Tt,specularColorMap:Gt,specularIntensityMap:Jt,transmission:q,transmissionMap:he,thicknessMap:B,gradientMap:Ft,opaque:v.transparent===!1&&v.blending===ps&&v.alphaToCoverage===!1,alphaMap:mt,alphaTest:Dt,alphaHash:kt,combine:v.combine,mapUv:It&&m(v.map.channel),aoMapUv:lt&&m(v.aoMap.channel),lightMapUv:ct&&m(v.lightMap.channel),bumpMapUv:gt&&m(v.bumpMap.channel),normalMapUv:bt&&m(v.normalMap.channel),displacementMapUv:Bt&&m(v.displacementMap.channel),emissiveMapUv:Ut&&m(v.emissiveMap.channel),metalnessMapUv:Kt&&m(v.metalnessMap.channel),roughnessMapUv:se&&m(v.roughnessMap.channel),anisotropyMapUv:rt&&m(v.anisotropyMap.channel),clearcoatMapUv:St&&m(v.clearcoatMap.channel),clearcoatNormalMapUv:Rt&&m(v.clearcoatNormalMap.channel),clearcoatRoughnessMapUv:tt&&m(v.clearcoatRoughnessMap.channel),iridescenceMapUv:ft&&m(v.iridescenceMap.channel),iridescenceThicknessMapUv:At&&m(v.iridescenceThicknessMap.channel),sheenColorMapUv:Ht&&m(v.sheenColorMap.channel),sheenRoughnessMapUv:Nt&&m(v.sheenRoughnessMap.channel),specularMapUv:Tt&&m(v.specularMap.channel),specularColorMapUv:Gt&&m(v.specularColorMap.channel),specularIntensityMapUv:Jt&&m(v.specularIntensityMap.channel),transmissionMapUv:he&&m(v.transmissionMap.channel),thicknessMapUv:B&&m(v.thicknessMap.channel),alphaMapUv:mt&&m(v.alphaMap.channel),vertexTangents:!!W.attributes.tangent&&(bt||F),vertexNormals:!!W.attributes.normal,vertexColors:v.vertexColors,vertexAlphas:v.vertexColors===!0&&!!W.attributes.color&&W.attributes.color.itemSize===4,pointsUvs:L.isPoints===!0&&!!W.attributes.uv&&(It||mt),fog:!!P,useFog:v.fog===!0,fogExp2:!!P&&P.isFogExp2,flatShading:v.wireframe===!1&&(v.flatShading===!0||W.attributes.normal===void 0&&bt===!1&&(v.isMeshLambertMaterial||v.isMeshPhongMaterial||v.isMeshStandardMaterial||v.isMeshPhysicalMaterial)),sizeAttenuation:v.sizeAttenuation===!0,logarithmicDepthBuffer:f,reversedDepthBuffer:_t,skinning:L.isSkinnedMesh===!0,hasPositionAttribute:W.attributes.position!==void 0,morphTargets:W.morphAttributes.position!==void 0,morphNormals:W.morphAttributes.normal!==void 0,morphColors:W.morphAttributes.color!==void 0,morphTargetsCount:Mt,morphTextureStride:vt,numSunLights:R.sun.length,numDirLights:R.directional.length,numPointLights:R.point.length,numSpotLights:R.spot.length,numSpotLightMaps:R.spotLightMap.length,numRectAreaLights:R.rectArea.length,numHemiLights:R.hemi.length,numSunLightShadows:R.sunShadowMap.length,numDirLightShadows:R.directionalShadowMap.length,numPointLightShadows:R.pointShadowMap.length,numSpotLightShadows:R.spotShadowMap.length,numSpotLightShadowsWithMaps:R.numSpotLightShadowsWithMaps,numLightProbes:R.numLightProbes,numLightProbeGrids:O.length,numClippingPlanes:r.numPlanes,numClipIntersection:r.numIntersection,dithering:v.dithering,shadowMapEnabled:i.shadowMap.enabled&&I.length>0,shadowMapType:i.shadowMap.type,toneMapping:ie,decodeVideoTexture:It&&v.map.isVideoTexture===!0&&Re.getTransfer(v.map.colorSpace)===Oe,decodeVideoTextureEmissive:Ut&&v.emissiveMap.isVideoTexture===!0&&Re.getTransfer(v.emissiveMap.colorSpace)===Oe,premultipliedAlpha:v.premultipliedAlpha,doubleSided:v.side===Cn,flipSided:v.side===Rn,useDepthPacking:v.depthPacking>=0,depthPacking:v.depthPacking||0,index0AttributeName:v.index0AttributeName,extensionClipCullDistance:ut&&v.extensions.clipCullDistance===!0&&e.has("WEBGL_clip_cull_distance"),extensionMultiDraw:(ut&&v.extensions.multiDraw===!0||pt)&&e.has("WEBGL_multi_draw"),rendererExtensionParallelShaderCompile:e.has("KHR_parallel_shader_compile"),customProgramCacheKey:v.customProgramCacheKey()};return jt.vertexUv1s=c.has(1),jt.vertexUv2s=c.has(2),jt.vertexUv3s=c.has(3),c.clear(),jt}function g(v){let R=[];if(v.shaderID?R.push(v.shaderID):(R.push(v.customVertexShaderID),R.push(v.customFragmentShaderID)),v.defines!==void 0)for(let I in v.defines)R.push(I),R.push(v.defines[I]);return v.isRawShaderMaterial===!1&&(p(R,v),b(R,v),R.push(i.outputColorSpace)),R.push(v.customProgramCacheKey),R.join()}function p(v,R){v.push(R.precision),v.push(R.outputColorSpace),v.push(R.envMapMode),v.push(R.envMapCubeUVHeight),v.push(R.mapUv),v.push(R.alphaMapUv),v.push(R.lightMapUv),v.push(R.aoMapUv),v.push(R.bumpMapUv),v.push(R.normalMapUv),v.push(R.displacementMapUv),v.push(R.emissiveMapUv),v.push(R.metalnessMapUv),v.push(R.roughnessMapUv),v.push(R.anisotropyMapUv),v.push(R.clearcoatMapUv),v.push(R.clearcoatNormalMapUv),v.push(R.clearcoatRoughnessMapUv),v.push(R.iridescenceMapUv),v.push(R.iridescenceThicknessMapUv),v.push(R.sheenColorMapUv),v.push(R.sheenRoughnessMapUv),v.push(R.specularMapUv),v.push(R.specularColorMapUv),v.push(R.specularIntensityMapUv),v.push(R.transmissionMapUv),v.push(R.thicknessMapUv),v.push(R.combine),v.push(R.fogExp2),v.push(R.sizeAttenuation),v.push(R.morphTargetsCount),v.push(R.morphAttributeCount),v.push(R.numSunLights),v.push(R.numDirLights),v.push(R.numPointLights),v.push(R.numSpotLights),v.push(R.numSpotLightMaps),v.push(R.numHemiLights),v.push(R.numRectAreaLights),v.push(R.numSunLightShadows),v.push(R.numDirLightShadows),v.push(R.numPointLightShadows),v.push(R.numSpotLightShadows),v.push(R.numSpotLightShadowsWithMaps),v.push(R.numLightProbes),v.push(R.shadowMapType),v.push(R.toneMapping),v.push(R.numClippingPlanes),v.push(R.numClipIntersection),v.push(R.depthPacking)}function b(v,R){a.disableAll(),R.instancing&&a.enable(0),R.instancingColor&&a.enable(1),R.instancingMorph&&a.enable(2),R.matcap&&a.enable(3),R.envMap&&a.enable(4),R.normalMapObjectSpace&&a.enable(5),R.normalMapTangentSpace&&a.enable(6),R.clearcoat&&a.enable(7),R.iridescence&&a.enable(8),R.alphaTest&&a.enable(9),R.vertexColors&&a.enable(10),R.vertexAlphas&&a.enable(11),R.vertexUv1s&&a.enable(12),R.vertexUv2s&&a.enable(13),R.vertexUv3s&&a.enable(14),R.vertexTangents&&a.enable(15),R.anisotropy&&a.enable(16),R.alphaHash&&a.enable(17),R.batching&&a.enable(18),R.dispersion&&a.enable(19),R.retroreflection&&a.enable(24),R.batchingColor&&a.enable(20),R.gradientMap&&a.enable(21),R.packedNormalMap&&a.enable(22),R.vertexNormals&&a.enable(23),v.push(a.mask),a.disableAll(),R.fog&&a.enable(0),R.useFog&&a.enable(1),R.flatShading&&a.enable(2),R.logarithmicDepthBuffer&&a.enable(3),R.reversedDepthBuffer&&a.enable(4),R.skinning&&a.enable(5),R.morphTargets&&a.enable(6),R.morphNormals&&a.enable(7),R.morphColors&&a.enable(8),R.premultipliedAlpha&&a.enable(9),R.shadowMapEnabled&&a.enable(10),R.doubleSided&&a.enable(11),R.flipSided&&a.enable(12),R.useDepthPacking&&a.enable(13),R.dithering&&a.enable(14),R.transmission&&a.enable(15),R.sheen&&a.enable(16),R.opaque&&a.enable(17),R.pointsUvs&&a.enable(18),R.decodeVideoTexture&&a.enable(19),R.decodeVideoTextureEmissive&&a.enable(20),R.alphaToCoverage&&a.enable(21),R.numLightProbeGrids>0&&a.enable(22),R.hasPositionAttribute&&a.enable(23),v.push(a.mask)}function E(v){let R=d[v.type],I;if(R){let N=Ri[R];I=Yi.clone(N.uniforms)}else I=v.uniforms;return I}function y(v,R){let I=h.get(R);return I!==void 0?++I.usedTimes:(I=new Gx(i,R,v,s),l.push(I),h.set(R,I)),I}function w(v){if(--v.usedTimes===0){let R=l.indexOf(v);l[R]=l[l.length-1],l.pop(),h.delete(v.cacheKey),v.destroy()}}function S(v){o.remove(v)}function C(){o.dispose()}return{getParameters:x,getProgramCacheKey:g,getUniforms:E,acquireProgram:y,releaseProgram:w,releaseShaderCache:S,programs:l,dispose:C}}function qx(){let i=new WeakMap;function t(a){return i.has(a)}function e(a){let o=i.get(a);return o===void 0&&(o={},i.set(a,o)),o}function n(a){i.delete(a)}function s(a,o,c){i.get(a)[o]=c}function r(){i=new WeakMap}return{has:t,get:e,remove:n,update:s,dispose:r}}function Yx(i,t){return i.groupOrder!==t.groupOrder?i.groupOrder-t.groupOrder:i.renderOrder!==t.renderOrder?i.renderOrder-t.renderOrder:i.material.id!==t.material.id?i.material.id-t.material.id:i.materialVariant!==t.materialVariant?i.materialVariant-t.materialVariant:i.z!==t.z?i.z-t.z:i.id-t.id}function of(i,t){return i.groupOrder!==t.groupOrder?i.groupOrder-t.groupOrder:i.renderOrder!==t.renderOrder?i.renderOrder-t.renderOrder:i.z!==t.z?t.z-i.z:i.id-t.id}function lf(){let i=[],t=0,e=[],n=[],s=[];function r(){t=0,e.length=0,n.length=0,s.length=0}function a(u){let d=0;return u.isInstancedMesh&&(d+=2),u.isSkinnedMesh&&(d+=1),d}function o(u,d,m,x,g,p){let b=i[t];return b===void 0?(b={id:u.id,object:u,geometry:d,material:m,materialVariant:a(u),groupOrder:x,renderOrder:u.renderOrder,z:g,group:p},i[t]=b):(b.id=u.id,b.object=u,b.geometry=d,b.material=m,b.materialVariant=a(u),b.groupOrder=x,b.renderOrder=u.renderOrder,b.z=g,b.group=p),t++,b}function c(u,d,m,x,g,p,b){b.reversedDepth===!0&&(g=-g);let E=o(u,d,m,x,g,p);m.transmission>0?n.push(E):m.transparent===!0?s.push(E):e.push(E)}function l(u,d,m,x,g,p){let b=o(u,d,m,x,g,p);m.transmission>0?n.unshift(b):m.transparent===!0?s.unshift(b):e.unshift(b)}function h(u,d){e.length>1&&e.sort(u||Yx),n.length>1&&n.sort(d||of),s.length>1&&s.sort(d||of)}function f(){for(let u=t,d=i.length;u<d;u++){let m=i[u];if(m.id===null)break;m.id=null,m.object=null,m.geometry=null,m.material=null,m.group=null}}return{opaque:e,transmissive:n,transparent:s,init:r,push:c,unshift:l,finish:f,sort:h}}function Zx(){let i=new WeakMap;function t(n,s){let r=i.get(n),a;return r===void 0?(a=new lf,i.set(n,[a])):s>=r.length?(a=new lf,r.push(a)):a=r[s],a}function e(){i=new WeakMap}return{get:t,dispose:e}}function Jx(){let i={};return{get:function(t){if(i[t.id]!==void 0)return i[t.id];let e;switch(t.type){case"SunLight":case"DirectionalLight":e={direction:new D,color:new oe};break;case"SpotLight":e={position:new D,direction:new D,color:new oe,distance:0,coneCos:0,penumbraCos:0,decay:0};break;case"PointLight":e={position:new D,color:new oe,distance:0,decay:0};break;case"HemisphereLight":e={direction:new D,skyColor:new oe,groundColor:new oe};break;case"RectAreaLight":e={color:new oe,position:new D,halfWidth:new D,halfHeight:new D};break}return i[t.id]=e,e}}}function Kx(){let i={};return{get:function(t){if(i[t.id]!==void 0)return i[t.id];let e;switch(t.type){case"SunLight":case"DirectionalLight":e={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new yt};break;case"SpotLight":e={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new yt};break;case"PointLight":e={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new yt,shadowCameraNear:1,shadowCameraFar:1e3};break}return i[t.id]=e,e}}}var jx=0;function Qx(i,t){return(t.castShadow?2:0)-(i.castShadow?2:0)+(t.map?1:0)-(i.map?1:0)}function t3(i){let t=new Jx,e=Kx(),n={version:0,hash:{sunLength:-1,directionalLength:-1,pointLength:-1,spotLength:-1,rectAreaLength:-1,hemiLength:-1,numSunShadows:-1,numDirectionalShadows:-1,numPointShadows:-1,numSpotShadows:-1,numSpotMaps:-1,numLightProbes:-1},ambient:[0,0,0],probe:[],sun:[],sunShadow:[],sunShadowMap:[],sunShadowMatrix:[],sunShadowCascade:[],directional:[],directionalShadow:[],directionalShadowMap:[],directionalShadowMatrix:[],spot:[],spotLightMap:[],spotShadow:[],spotShadowMap:[],spotLightMatrix:[],rectArea:[],rectAreaLTC1:null,rectAreaLTC2:null,point:[],pointShadow:[],pointShadowMap:[],pointShadowMatrix:[],hemi:[],numSpotLightShadowsWithMaps:0,numLightProbes:0};for(let l=0;l<9;l++)n.probe.push(new D);let s=new D,r=new De,a=new De;function o(l){let h=0,f=0,u=0;for(let L=0;L<9;L++)n.probe[L].set(0,0,0);let d=0,m=0,x=0,g=0,p=0,b=0,E=0,y=0,w=0,S=0,C=0,v=0,R=0,I=0;l.sort(Qx);for(let L=0,O=l.length;L<O;L++){let P=l[L],W=P.color,it=P.intensity,Q=P.distance,ht=null;if(P.shadow&&P.shadow.map&&(P.shadow.map.texture.format===xs?ht=P.shadow.map.texture:ht=P.shadow.map.depthTexture||P.shadow.map.texture),P.isAmbientLight)h+=W.r*it,f+=W.g*it,u+=W.b*it;else if(P.isLightProbe){for(let K=0;K<9;K++)n.probe[K].addScaledVector(P.sh.coefficients[K],it);I++}else if(P.isSunLight){let K=t.get(P);if(K.color.copy(P.color).multiplyScalar(P.intensity),P.castShadow){let ot=P.shadow,z=e.get(P);z.shadowIntensity=ot.intensity,z.shadowBias=ot.bias,z.shadowNormalBias=ot.normalBias,z.shadowRadius=ot.radius,z.shadowMapSize.copy(ot.mapSize).multiply(ot.getFrameExtents()),n.sunShadow[m]=z,n.sunShadowMap[m]=ht;let Mt=ot.getViewportCount();for(let vt=0;vt<Mt;vt++)n.sunShadowMatrix[x+vt]=ot.getMatrix(vt),n.sunShadowCascade[x+vt]=ot._cascadeData[vt];x+=Mt,m++}n.sun[d]=K,d++}else if(P.isDirectionalLight){let K=t.get(P);if(K.color.copy(P.color).multiplyScalar(P.intensity),P.castShadow){let ot=P.shadow,z=e.get(P);z.shadowIntensity=ot.intensity,z.shadowBias=ot.bias,z.shadowNormalBias=ot.normalBias,z.shadowRadius=ot.radius,z.shadowMapSize=ot.mapSize,n.directionalShadow[g]=z,n.directionalShadowMap[g]=ht,n.directionalShadowMatrix[g]=P.shadow.matrix,w++}n.directional[g]=K,g++}else if(P.isSpotLight){let K=t.get(P);K.position.setFromMatrixPosition(P.matrixWorld),K.color.copy(W).multiplyScalar(it),K.distance=Q,K.coneCos=Math.cos(P.angle),K.penumbraCos=Math.cos(P.angle*(1-P.penumbra)),K.decay=P.decay,n.spot[b]=K;let ot=P.shadow;if(P.map&&(n.spotLightMap[v]=P.map,v++,ot.updateMatrices(P),P.castShadow&&R++),n.spotLightMatrix[b]=ot.matrix,P.castShadow){let z=e.get(P);z.shadowIntensity=ot.intensity,z.shadowBias=ot.bias,z.shadowNormalBias=ot.normalBias,z.shadowRadius=ot.radius,z.shadowMapSize=ot.mapSize,n.spotShadow[b]=z,n.spotShadowMap[b]=ht,C++}b++}else if(P.isRectAreaLight){let K=t.get(P);K.color.copy(W).multiplyScalar(it),K.halfWidth.set(P.width*.5,0,0),K.halfHeight.set(0,P.height*.5,0),n.rectArea[E]=K,E++}else if(P.isPointLight){let K=t.get(P);if(K.color.copy(P.color).multiplyScalar(P.intensity),K.distance=P.distance,K.decay=P.decay,P.castShadow){let ot=P.shadow,z=e.get(P);z.shadowIntensity=ot.intensity,z.shadowBias=ot.bias,z.shadowNormalBias=ot.normalBias,z.shadowRadius=ot.radius,z.shadowMapSize=ot.mapSize,z.shadowCameraNear=ot.camera.near,z.shadowCameraFar=ot.camera.far,n.pointShadow[p]=z,n.pointShadowMap[p]=ht,n.pointShadowMatrix[p]=P.shadow.matrix,S++}n.point[p]=K,p++}else if(P.isHemisphereLight){let K=t.get(P);K.skyColor.copy(P.color).multiplyScalar(it),K.groundColor.copy(P.groundColor).multiplyScalar(it),n.hemi[y]=K,y++}}E>0&&(i.has("OES_texture_float_linear")===!0?(n.rectAreaLTC1=Wt.LTC_FLOAT_1,n.rectAreaLTC2=Wt.LTC_FLOAT_2):(n.rectAreaLTC1=Wt.LTC_HALF_1,n.rectAreaLTC2=Wt.LTC_HALF_2)),n.ambient[0]=h,n.ambient[1]=f,n.ambient[2]=u;let N=n.hash;(N.sunLength!==d||N.directionalLength!==g||N.pointLength!==p||N.spotLength!==b||N.rectAreaLength!==E||N.hemiLength!==y||N.numSunShadows!==m||N.numDirectionalShadows!==w||N.numPointShadows!==S||N.numSpotShadows!==C||N.numSpotMaps!==v||N.numLightProbes!==I)&&(n.sun.length=d,n.directional.length=g,n.spot.length=b,n.rectArea.length=E,n.point.length=p,n.hemi.length=y,n.sunShadow.length=m,n.sunShadowMap.length=m,n.sunShadowMatrix.length=x,n.sunShadowCascade.length=x,n.directionalShadow.length=w,n.directionalShadowMap.length=w,n.directionalShadowMatrix.length=w,n.pointShadow.length=S,n.pointShadowMap.length=S,n.pointShadowMatrix.length=S,n.spotShadow.length=C,n.spotShadowMap.length=C,n.spotLightMatrix.length=C+v-R,n.spotLightMap.length=v,n.numSpotLightShadowsWithMaps=R,n.numLightProbes=I,N.sunLength=d,N.directionalLength=g,N.pointLength=p,N.spotLength=b,N.rectAreaLength=E,N.hemiLength=y,N.numSunShadows=m,N.numDirectionalShadows=w,N.numPointShadows=S,N.numSpotShadows=C,N.numSpotMaps=v,N.numLightProbes=I,n.version=jx++)}function c(l,h){let f=0,u=0,d=0,m=0,x=0,g=0,p=h.matrixWorldInverse;for(let b=0,E=l.length;b<E;b++){let y=l[b];if(y.isSunLight){let w=n.sun[f];w.direction.setFromMatrixPosition(y.matrixWorld),w.direction.transformDirection(p),f++}else if(y.isDirectionalLight){let w=n.directional[u];w.direction.setFromMatrixPosition(y.matrixWorld),s.setFromMatrixPosition(y.target.matrixWorld),w.direction.sub(s),w.direction.transformDirection(p),u++}else if(y.isSpotLight){let w=n.spot[m];w.position.setFromMatrixPosition(y.matrixWorld),w.position.applyMatrix4(p),w.direction.setFromMatrixPosition(y.matrixWorld),s.setFromMatrixPosition(y.target.matrixWorld),w.direction.sub(s),w.direction.transformDirection(p),m++}else if(y.isRectAreaLight){let w=n.rectArea[x];w.position.setFromMatrixPosition(y.matrixWorld),w.position.applyMatrix4(p),a.identity(),r.copy(y.matrixWorld),r.premultiply(p),a.extractRotation(r),w.halfWidth.set(y.width*.5,0,0),w.halfHeight.set(0,y.height*.5,0),w.halfWidth.applyMatrix4(a),w.halfHeight.applyMatrix4(a),x++}else if(y.isPointLight){let w=n.point[d];w.position.setFromMatrixPosition(y.matrixWorld),w.position.applyMatrix4(p),d++}else if(y.isHemisphereLight){let w=n.hemi[g];w.direction.setFromMatrixPosition(y.matrixWorld),w.direction.transformDirection(p),g++}}}return{setup:o,setupView:c,state:n}}function cf(i){let t=new t3(i),e=[],n=[],s=[];function r(u){f.camera=u,e.length=0,n.length=0,s.length=0}function a(u){e.push(u)}function o(u){n.push(u)}function c(u){s.push(u)}function l(){t.setup(e)}function h(u){t.setupView(e,u)}let f={lightsArray:e,shadowsArray:n,lightProbeGridArray:s,camera:null,lights:t,transmissionRenderTarget:{},textureUnits:0};return{init:r,state:f,setupLights:l,setupLightsView:h,pushLight:a,pushShadow:o,pushLightProbeGrid:c}}function e3(i){let t=new WeakMap;function e(s,r=0){let a=t.get(s),o;return a===void 0?(o=new cf(i),t.set(s,[o])):r>=a.length?(o=new cf(i),a.push(o)):o=a[r],o}function n(){t=new WeakMap}return{get:e,dispose:n}}var n3=`void main() {
	gl_Position = vec4( position, 1.0 );
}`,i3=`uniform sampler2D shadow_pass;
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
}`,s3=[new D(1,0,0),new D(-1,0,0),new D(0,1,0),new D(0,-1,0),new D(0,0,1),new D(0,0,-1)],r3=[new D(0,-1,0),new D(0,-1,0),new D(0,0,1),new D(0,0,-1),new D(0,-1,0),new D(0,-1,0)],hf=new De,ao=new D,_h=new D;function a3(i,t,e){let n=new gr,s=new yt,r=new yt,a=new je,o=new bl,c=new Sl,l={},h=e.maxTextureSize,f={[fs]:Rn,[Rn]:fs,[Cn]:Cn},u=new Ge({defines:{VSM_SAMPLES:8},uniforms:{shadow_pass:{value:null},resolution:{value:new yt},radius:{value:4}},vertexShader:n3,fragmentShader:i3}),d=u.clone();d.defines.HORIZONTAL_PASS=1;let m=new Le;m.setAttribute("position",new ln(new Float32Array([-1,-1,.5,3,-1,.5,-1,3,.5]),3));let x=new we(m,u),g=this;this.enabled=!1,this.autoUpdate=!0,this.needsUpdate=!1,this.type=Wa;let p=this.type;this.render=function(S,C,v){if(g.enabled===!1||g.autoUpdate===!1&&g.needsUpdate===!1||S.length===0)return;this.type===td&&(pe("WebGLShadowMap: PCFSoftShadowMap has been removed. Using PCFShadowMap instead."),this.type=Wa);let R=i.getRenderTarget(),I=i.getActiveCubeFace(),N=i.getActiveMipmapLevel(),L=i.state;L.setBlending(Qn),L.buffers.depth.getReversed()===!0?L.buffers.color.setClear(0,0,0,0):L.buffers.color.setClear(1,1,1,1),L.buffers.depth.setTest(!0),L.setScissorTest(!1);let O=p!==this.type;O&&C.traverse(function(P){P.material&&(Array.isArray(P.material)?P.material.forEach(W=>W.needsUpdate=!0):P.material.needsUpdate=!0)});for(let P=0,W=S.length;P<W;P++){let it=S[P],Q=it.shadow;if(Q===void 0){pe("WebGLShadowMap:",it,"has no shadow.");continue}if(Q.autoUpdate===!1&&Q.needsUpdate===!1)continue;s.copy(Q.mapSize);let ht=Q.getFrameExtents();s.multiply(ht),r.copy(Q.mapSize),(s.x>h||s.y>h)&&(s.x>h&&(r.x=Math.floor(h/ht.x),s.x=r.x*ht.x,Q.mapSize.x=r.x),s.y>h&&(r.y=Math.floor(h/ht.y),s.y=r.y*ht.y,Q.mapSize.y=r.y));let K=i.state.buffers.depth.getReversed();if(Q.camera._reversedDepth=K,Q.map===null||O===!0){if(Q.map!==null&&(Q.map.depthTexture!==null&&(Q.map.depthTexture.dispose(),Q.map.depthTexture=null),Q.map.dispose()),this.type===Ar){if(it.isPointLight){pe("WebGLShadowMap: VSM shadow maps are not supported for PointLights. Use PCF or BasicShadowMap instead.");continue}Q.map=new sn(s.x,s.y,{format:xs,type:mn,minFilter:An,magFilter:An,generateMipmaps:!1}),Q.map.texture.name=it.name+".shadowMap",Q.map.depthTexture=new os(s.x,s.y,ti),Q.map.depthTexture.name=it.name+".shadowMapDepth",Q.map.depthTexture.format=bi,Q.map.depthTexture.compareFunction=null,Q.map.depthTexture.minFilter=bn,Q.map.depthTexture.magFilter=bn}else it.isPointLight?(Q.map=new Ac(s.x),Q.map.depthTexture=new gl(s.x,pi)):(Q.map=new sn(s.x,s.y),Q.map.depthTexture=new os(s.x,s.y,pi)),Q.map.depthTexture.name=it.name+".shadowMap",Q.map.depthTexture.format=bi,this.type===Wa?(Q.map.depthTexture.compareFunction=K?Sc:bc,Q.map.depthTexture.minFilter=An,Q.map.depthTexture.magFilter=An):(Q.map.depthTexture.compareFunction=null,Q.map.depthTexture.minFilter=bn,Q.map.depthTexture.magFilter=bn);Q.camera.updateProjectionMatrix()}Q.map.isWebGLCubeRenderTarget!==!0&&(Q.map.width!==s.x||Q.map.height!==s.y)&&Q.map.setSize(s.x,s.y);let ot=Q.map.isWebGLCubeRenderTarget?6:Q.getViewportCount();it.isPointLight!==!0&&Q.updateMatrices(it,v);for(let z=0;z<ot;z++){let Mt=Q.getCamera(z);if(it.isPointLight){let vt=Q.camera,Et=Q.matrix,Ot=it.distance||vt.far;Ot!==vt.far&&(vt.far=Ot,vt.updateProjectionMatrix()),ao.setFromMatrixPosition(it.matrixWorld),vt.position.copy(ao),_h.copy(vt.position),_h.add(s3[z]),vt.up.copy(r3[z]),vt.lookAt(_h),vt.updateMatrixWorld(),Et.makeTranslation(-ao.x,-ao.y,-ao.z),hf.multiplyMatrices(vt.projectionMatrix,vt.matrixWorldInverse),Q._frustum.setFromProjectionMatrix(hf,vt.coordinateSystem,vt.reversedDepth)}if(Q.map.isWebGLCubeRenderTarget)i.setRenderTarget(Q.map,z),i.clear();else{z===0&&(i.setRenderTarget(Q.map),i.clear());let vt=Q.getViewport(z);a.set(r.x*vt.x,r.y*vt.y,r.x*vt.z,r.y*vt.w),L.viewport(a)}n=Q.getFrustum(z),y(C,v,Mt,it,this.type)}Q.isPointLightShadow!==!0&&this.type===Ar&&b(Q,v),Q.needsUpdate=!1}p=this.type,g.needsUpdate=!1,i.setRenderTarget(R,I,N)};function b(S,C){let v=t.update(x);u.defines.VSM_SAMPLES!==S.blurSamples&&(u.defines.VSM_SAMPLES=S.blurSamples,d.defines.VSM_SAMPLES=S.blurSamples,u.needsUpdate=!0,d.needsUpdate=!0),S.mapPass===null?S.mapPass=new sn(s.x,s.y,{format:xs,type:mn}):(S.mapPass.width!==S.map.width||S.mapPass.height!==S.map.height)&&S.mapPass.setSize(S.map.width,S.map.height),u.uniforms.shadow_pass.value=S.map.depthTexture,u.uniforms.resolution.value.set(S.map.width,S.map.height),u.uniforms.radius.value=S.radius,i.setRenderTarget(S.mapPass),i.clear(),i.renderBufferDirect(C,null,v,u,x,null),d.uniforms.shadow_pass.value=S.mapPass.texture,d.uniforms.resolution.value.set(S.map.width,S.map.height),d.uniforms.radius.value=S.radius,i.setRenderTarget(S.map),i.clear(),i.renderBufferDirect(C,null,v,d,x,null)}function E(S,C,v,R){let I=null,N=v.isPointLight===!0?S.customDistanceMaterial:S.customDepthMaterial;if(N!==void 0)I=N;else if(I=v.isPointLight===!0?c:o,i.localClippingEnabled&&C.clipShadows===!0&&Array.isArray(C.clippingPlanes)&&C.clippingPlanes.length!==0||C.displacementMap&&C.displacementScale!==0||C.alphaMap&&C.alphaTest>0||C.map&&C.alphaTest>0||C.alphaToCoverage===!0){let L=I.uuid,O=C.uuid,P=l[L];P===void 0&&(P={},l[L]=P);let W=P[O];W===void 0&&(W=I.clone(),P[O]=W,C.addEventListener("dispose",w)),I=W}if(I.visible=C.visible,I.wireframe=C.wireframe,R===Ar?I.side=C.shadowSide!==null?C.shadowSide:C.side:I.side=C.shadowSide!==null?C.shadowSide:f[C.side],I.alphaMap=C.alphaMap,I.alphaTest=C.alphaToCoverage===!0?.5:C.alphaTest,I.map=C.map,I.clipShadows=C.clipShadows,I.clippingPlanes=C.clippingPlanes,I.clipIntersection=C.clipIntersection,I.displacementMap=C.displacementMap,I.displacementScale=C.displacementScale,I.displacementBias=C.displacementBias,I.wireframeLinewidth=C.wireframeLinewidth,I.linewidth=C.linewidth,v.isPointLight===!0&&I.isMeshDistanceMaterial===!0){let L=i.properties.get(I);L.light=v}return I}function y(S,C,v,R,I){if(S.visible===!1)return;if(S.layers.test(C.layers)&&(S.isMesh||S.isLine||S.isPoints)&&(S.castShadow||S.receiveShadow&&I===Ar)&&(!S.frustumCulled||S.intersectsFrustum(n))){S.modelViewMatrix.multiplyMatrices(v.matrixWorldInverse,S.matrixWorld);let O=t.update(S),P=S.material;if(Array.isArray(P)){let W=O.groups;for(let it=0,Q=W.length;it<Q;it++){let ht=W[it],K=P[ht.materialIndex];if(K&&K.visible){let ot=E(S,K,R,I);S.onBeforeShadow(i,S,C,v,O,ot,ht),i.renderBufferDirect(v,null,O,ot,S,ht),S.onAfterShadow(i,S,C,v,O,ot,ht)}}}else if(P.visible){let W=E(S,P,R,I);S.onBeforeShadow(i,S,C,v,O,W,null),i.renderBufferDirect(v,null,O,W,S,null),S.onAfterShadow(i,S,C,v,O,W,null)}}let L=S.children;for(let O=0,P=L.length;O<P;O++)y(L[O],C,v,R,I)}function w(S){S.target.removeEventListener("dispose",w);for(let v in l){let R=l[v],I=S.target.uuid;I in R&&(R[I].dispose(),delete R[I])}}}function o3(i,t){function e(){let B=!1,Ft=new je,mt=null,Dt=new je(0,0,0,0);return{setMask:function(kt){mt!==kt&&!B&&(i.colorMask(kt,kt,kt,kt),mt=kt)},setLocked:function(kt){B=kt},setClear:function(kt,ut,ie,jt,Be){Be===!0&&(kt*=jt,ut*=jt,ie*=jt),Ft.set(kt,ut,ie,jt),Dt.equals(Ft)===!1&&(i.clearColor(kt,ut,ie,jt),Dt.copy(Ft))},reset:function(){B=!1,mt=null,Dt.set(-1,0,0,0)}}}function n(){let B=!1,Ft=!1,mt=null,Dt=null,kt=null;return{setReversed:function(ut){if(Ft!==ut){let ie=t.get("EXT_clip_control");ut?ie.clipControlEXT(ie.LOWER_LEFT_EXT,ie.ZERO_TO_ONE_EXT):ie.clipControlEXT(ie.LOWER_LEFT_EXT,ie.NEGATIVE_ONE_TO_ONE_EXT),Ft=ut;let jt=kt;kt=null,this.setClear(jt)}},getReversed:function(){return Ft},setTest:function(ut){ut?nt(i.DEPTH_TEST):_t(i.DEPTH_TEST)},setMask:function(ut){mt!==ut&&!B&&(i.depthMask(ut),mt=ut)},setFunc:function(ut){if(Ft&&(ut=Dd[ut]),Dt!==ut){switch(ut){case tl:i.depthFunc(i.NEVER);break;case el:i.depthFunc(i.ALWAYS);break;case nl:i.depthFunc(i.LESS);break;case or:i.depthFunc(i.LEQUAL);break;case il:i.depthFunc(i.EQUAL);break;case sl:i.depthFunc(i.GEQUAL);break;case rl:i.depthFunc(i.GREATER);break;case al:i.depthFunc(i.NOTEQUAL);break;default:i.depthFunc(i.LEQUAL)}Dt=ut}},setLocked:function(ut){B=ut},setClear:function(ut){kt!==ut&&(kt=ut,Ft&&(ut=1-ut),i.clearDepth(ut))},reset:function(){B=!1,mt=null,Dt=null,kt=null,Ft=!1}}}function s(){let B=!1,Ft=null,mt=null,Dt=null,kt=null,ut=null,ie=null,jt=null,Be=null;return{setTest:function(U){B||(U?nt(i.STENCIL_TEST):_t(i.STENCIL_TEST))},setMask:function(U){Ft!==U&&!B&&(i.stencilMask(U),Ft=U)},setFunc:function(U,xt,zt){(mt!==U||Dt!==xt||kt!==zt)&&(i.stencilFunc(U,xt,zt),mt=U,Dt=xt,kt=zt)},setOp:function(U,xt,zt){(ut!==U||ie!==xt||jt!==zt)&&(i.stencilOp(U,xt,zt),ut=U,ie=xt,jt=zt)},setLocked:function(U){B=U},setClear:function(U){Be!==U&&(i.clearStencil(U),Be=U)},reset:function(){B=!1,Ft=null,mt=null,Dt=null,kt=null,ut=null,ie=null,jt=null,Be=null}}}let r=new e,a=new n,o=new s,c=new WeakMap,l=new WeakMap,h={},f={},u={},d=new WeakMap,m=[],x=null,g=!1,p=null,b=null,E=null,y=null,w=null,S=null,C=null,v=new oe(0,0,0),R=0,I=!1,N=null,L=null,O=null,P=null,W=null,it=i.getParameter(i.MAX_COMBINED_TEXTURE_IMAGE_UNITS),Q=!1,ht=0,K=i.getParameter(i.VERSION);K.indexOf("WebGL")!==-1?(ht=parseFloat(/^WebGL (\d)/.exec(K)[1]),Q=ht>=1):K.indexOf("OpenGL ES")!==-1&&(ht=parseFloat(/^OpenGL ES (\d)/.exec(K)[1]),Q=ht>=2);let ot=null,z={},Mt=i.getParameter(i.SCISSOR_BOX),vt=i.getParameter(i.VIEWPORT),Et=new je().fromArray(Mt),Ot=new je().fromArray(vt);function Lt(B,Ft,mt,Dt){let kt=new Uint8Array(4),ut=i.createTexture();i.bindTexture(B,ut),i.texParameteri(B,i.TEXTURE_MIN_FILTER,i.NEAREST),i.texParameteri(B,i.TEXTURE_MAG_FILTER,i.NEAREST);for(let ie=0;ie<mt;ie++)B===i.TEXTURE_3D||B===i.TEXTURE_2D_ARRAY?i.texImage3D(Ft,0,i.RGBA,1,1,Dt,0,i.RGBA,i.UNSIGNED_BYTE,kt):i.texImage2D(Ft+ie,0,i.RGBA,1,1,0,i.RGBA,i.UNSIGNED_BYTE,kt);return ut}let et={};et[i.TEXTURE_2D]=Lt(i.TEXTURE_2D,i.TEXTURE_2D,1),et[i.TEXTURE_CUBE_MAP]=Lt(i.TEXTURE_CUBE_MAP,i.TEXTURE_CUBE_MAP_POSITIVE_X,6),et[i.TEXTURE_2D_ARRAY]=Lt(i.TEXTURE_2D_ARRAY,i.TEXTURE_2D_ARRAY,1,1),et[i.TEXTURE_3D]=Lt(i.TEXTURE_3D,i.TEXTURE_3D,1,1),r.setClear(0,0,0,1),a.setClear(1),o.setClear(0),nt(i.DEPTH_TEST),a.setFunc(or),gt(!1),bt(q0),nt(i.CULL_FACE),lt(Qn);function nt(B){h[B]!==!0&&(i.enable(B),h[B]=!0)}function _t(B){h[B]!==!1&&(i.disable(B),h[B]=!1)}function wt(B,Ft){return u[B]!==Ft?(i.bindFramebuffer(B,Ft),u[B]=Ft,B===i.DRAW_FRAMEBUFFER&&(u[i.FRAMEBUFFER]=Ft),B===i.FRAMEBUFFER&&(u[i.DRAW_FRAMEBUFFER]=Ft),!0):!1}function pt(B,Ft){let mt=m,Dt=!1;if(B){mt=d.get(Ft),mt===void 0&&(mt=[],d.set(Ft,mt));let kt=B.textures;if(mt.length!==kt.length||mt[0]!==i.COLOR_ATTACHMENT0){for(let ut=0,ie=kt.length;ut<ie;ut++)mt[ut]=i.COLOR_ATTACHMENT0+ut;mt.length=kt.length,Dt=!0}}else mt[0]!==i.BACK&&(mt[0]=i.BACK,Dt=!0);Dt&&i.drawBuffers(mt)}function It(B){return x!==B?(i.useProgram(B),x=B,!0):!1}let ee={[As]:i.FUNC_ADD,[nd]:i.FUNC_SUBTRACT,[id]:i.FUNC_REVERSE_SUBTRACT};ee[sd]=i.MIN,ee[rd]=i.MAX;let V={[ad]:i.ZERO,[od]:i.ONE,[ld]:i.SRC_COLOR,[J0]:i.SRC_ALPHA,[pd]:i.SRC_ALPHA_SATURATE,[dd]:i.DST_COLOR,[hd]:i.DST_ALPHA,[cd]:i.ONE_MINUS_SRC_COLOR,[K0]:i.ONE_MINUS_SRC_ALPHA,[fd]:i.ONE_MINUS_DST_COLOR,[ud]:i.ONE_MINUS_DST_ALPHA,[md]:i.CONSTANT_COLOR,[gd]:i.ONE_MINUS_CONSTANT_COLOR,[xd]:i.CONSTANT_ALPHA,[_d]:i.ONE_MINUS_CONSTANT_ALPHA};function lt(B,Ft,mt,Dt,kt,ut,ie,jt,Be,U){if(B===Qn){g===!0&&(_t(i.BLEND),g=!1);return}if(g===!1&&(nt(i.BLEND),g=!0),B!==ed){if(B!==p||U!==I){if((b!==As||w!==As)&&(i.blendEquation(i.FUNC_ADD),b=As,w=As),U)switch(B){case ps:i.blendFuncSeparate(i.ONE,i.ONE_MINUS_SRC_ALPHA,i.ONE,i.ONE_MINUS_SRC_ALPHA);break;case pn:i.blendFunc(i.ONE,i.ONE);break;case Y0:i.blendFuncSeparate(i.ZERO,i.ONE_MINUS_SRC_COLOR,i.ZERO,i.ONE);break;case Z0:i.blendFuncSeparate(i.DST_COLOR,i.ONE_MINUS_SRC_ALPHA,i.ZERO,i.ONE);break;default:fe("WebGLState: Invalid blending: ",B);break}else switch(B){case ps:i.blendFuncSeparate(i.SRC_ALPHA,i.ONE_MINUS_SRC_ALPHA,i.ONE,i.ONE_MINUS_SRC_ALPHA);break;case pn:i.blendFuncSeparate(i.SRC_ALPHA,i.ONE,i.ONE,i.ONE);break;case Y0:fe("WebGLState: SubtractiveBlending requires material.premultipliedAlpha = true");break;case Z0:fe("WebGLState: MultiplyBlending requires material.premultipliedAlpha = true");break;default:fe("WebGLState: Invalid blending: ",B);break}E=null,y=null,S=null,C=null,v.set(0,0,0),R=0,p=B,I=U}return}kt=kt||Ft,ut=ut||mt,ie=ie||Dt,(Ft!==b||kt!==w)&&(i.blendEquationSeparate(ee[Ft],ee[kt]),b=Ft,w=kt),(mt!==E||Dt!==y||ut!==S||ie!==C)&&(i.blendFuncSeparate(V[mt],V[Dt],V[ut],V[ie]),E=mt,y=Dt,S=ut,C=ie),(jt.equals(v)===!1||Be!==R)&&(i.blendColor(jt.r,jt.g,jt.b,Be),v.copy(jt),R=Be),p=B,I=!1}function ct(B,Ft){B.side===Cn?_t(i.CULL_FACE):nt(i.CULL_FACE);let mt=B.side===Rn;Ft&&(mt=!mt),gt(mt),B.blending===ps&&B.transparent===!1?lt(Qn):lt(B.blending,B.blendEquation,B.blendSrc,B.blendDst,B.blendEquationAlpha,B.blendSrcAlpha,B.blendDstAlpha,B.blendColor,B.blendAlpha,B.premultipliedAlpha),a.setFunc(B.depthFunc),a.setTest(B.depthTest),a.setMask(B.depthWrite),r.setMask(B.colorWrite);let Dt=B.stencilWrite;o.setTest(Dt),Dt&&(o.setMask(B.stencilWriteMask),o.setFunc(B.stencilFunc,B.stencilRef,B.stencilFuncMask),o.setOp(B.stencilFail,B.stencilZFail,B.stencilZPass)),Ut(B.polygonOffset,B.polygonOffsetFactor,B.polygonOffsetUnits),B.alphaToCoverage===!0?nt(i.SAMPLE_ALPHA_TO_COVERAGE):_t(i.SAMPLE_ALPHA_TO_COVERAGE)}function gt(B){N!==B&&(B?i.frontFace(i.CW):i.frontFace(i.CCW),N=B)}function bt(B){B!==ju?(nt(i.CULL_FACE),B!==L&&(B===q0?i.cullFace(i.BACK):B===Qu?i.cullFace(i.FRONT):i.cullFace(i.FRONT_AND_BACK))):_t(i.CULL_FACE),L=B}function Bt(B){B!==O&&(Q&&i.lineWidth(B),O=B)}function Ut(B,Ft,mt){B?(nt(i.POLYGON_OFFSET_FILL),(P!==Ft||W!==mt)&&(P=Ft,W=mt,a.getReversed()&&(Ft=-Ft),i.polygonOffset(Ft,mt))):_t(i.POLYGON_OFFSET_FILL)}function Kt(B){B?nt(i.SCISSOR_TEST):_t(i.SCISSOR_TEST)}function se(B){B===void 0&&(B=i.TEXTURE0+it-1),ot!==B&&(i.activeTexture(B),ot=B)}function F(B,Ft,mt){mt===void 0&&(ot===null?mt=i.TEXTURE0+it-1:mt=ot);let Dt=z[mt];Dt===void 0&&(Dt={type:void 0,texture:void 0},z[mt]=Dt),(Dt.type!==B||Dt.texture!==Ft)&&(ot!==mt&&(i.activeTexture(mt),ot=mt),i.bindTexture(B,Ft||et[B]),Dt.type=B,Dt.texture=Ft)}function re(){let B=z[ot];B!==void 0&&B.type!==void 0&&(i.bindTexture(B.type,null),B.type=void 0,B.texture=void 0)}function ae(){try{i.compressedTexImage2D(...arguments)}catch(B){fe("WebGLState:",B)}}function T(){try{i.compressedTexImage3D(...arguments)}catch(B){fe("WebGLState:",B)}}function _(){try{i.texSubImage2D(...arguments)}catch(B){fe("WebGLState:",B)}}function G(){try{i.texSubImage3D(...arguments)}catch(B){fe("WebGLState:",B)}}function q(){try{i.compressedTexSubImage2D(...arguments)}catch(B){fe("WebGLState:",B)}}function rt(){try{i.compressedTexSubImage3D(...arguments)}catch(B){fe("WebGLState:",B)}}function St(){try{i.texStorage2D(...arguments)}catch(B){fe("WebGLState:",B)}}function Rt(){try{i.texStorage3D(...arguments)}catch(B){fe("WebGLState:",B)}}function tt(){try{i.texImage2D(...arguments)}catch(B){fe("WebGLState:",B)}}function ft(){try{i.texImage3D(...arguments)}catch(B){fe("WebGLState:",B)}}function At(B){return f[B]!==void 0?f[B]:i.getParameter(B)}function Ht(B,Ft){f[B]!==Ft&&(i.pixelStorei(B,Ft),f[B]=Ft)}function Nt(B){Et.equals(B)===!1&&(i.scissor(B.x,B.y,B.z,B.w),Et.copy(B))}function Tt(B){Ot.equals(B)===!1&&(i.viewport(B.x,B.y,B.z,B.w),Ot.copy(B))}function Gt(B,Ft){let mt=l.get(Ft);mt===void 0&&(mt=new WeakMap,l.set(Ft,mt));let Dt=mt.get(B);Dt===void 0&&(Dt=i.getUniformBlockIndex(Ft,B.name),mt.set(B,Dt))}function Jt(B,Ft){let Dt=l.get(Ft).get(B);c.get(Ft)!==Dt&&(i.uniformBlockBinding(Ft,Dt,B.__bindingPointIndex),c.set(Ft,Dt))}function he(){i.disable(i.BLEND),i.disable(i.CULL_FACE),i.disable(i.DEPTH_TEST),i.disable(i.POLYGON_OFFSET_FILL),i.disable(i.SCISSOR_TEST),i.disable(i.STENCIL_TEST),i.disable(i.SAMPLE_ALPHA_TO_COVERAGE),i.blendEquation(i.FUNC_ADD),i.blendFunc(i.ONE,i.ZERO),i.blendFuncSeparate(i.ONE,i.ZERO,i.ONE,i.ZERO),i.blendColor(0,0,0,0),i.colorMask(!0,!0,!0,!0),i.clearColor(0,0,0,0),i.depthMask(!0),i.depthFunc(i.LESS),a.setReversed(!1),i.clearDepth(1),i.stencilMask(4294967295),i.stencilFunc(i.ALWAYS,0,4294967295),i.stencilOp(i.KEEP,i.KEEP,i.KEEP),i.clearStencil(0),i.cullFace(i.BACK),i.frontFace(i.CCW),i.polygonOffset(0,0),i.activeTexture(i.TEXTURE0),i.bindFramebuffer(i.FRAMEBUFFER,null),i.bindFramebuffer(i.DRAW_FRAMEBUFFER,null),i.bindFramebuffer(i.READ_FRAMEBUFFER,null),i.useProgram(null),i.lineWidth(1),i.scissor(0,0,i.canvas.width,i.canvas.height),i.viewport(0,0,i.canvas.width,i.canvas.height),i.pixelStorei(i.PACK_ALIGNMENT,4),i.pixelStorei(i.UNPACK_ALIGNMENT,4),i.pixelStorei(i.UNPACK_FLIP_Y_WEBGL,!1),i.pixelStorei(i.UNPACK_PREMULTIPLY_ALPHA_WEBGL,!1),i.pixelStorei(i.UNPACK_COLORSPACE_CONVERSION_WEBGL,i.BROWSER_DEFAULT_WEBGL),i.pixelStorei(i.PACK_ROW_LENGTH,0),i.pixelStorei(i.PACK_SKIP_PIXELS,0),i.pixelStorei(i.PACK_SKIP_ROWS,0),i.pixelStorei(i.UNPACK_ROW_LENGTH,0),i.pixelStorei(i.UNPACK_IMAGE_HEIGHT,0),i.pixelStorei(i.UNPACK_SKIP_PIXELS,0),i.pixelStorei(i.UNPACK_SKIP_ROWS,0),i.pixelStorei(i.UNPACK_SKIP_IMAGES,0),h={},f={},ot=null,z={},u={},d=new WeakMap,m=[],x=null,g=!1,p=null,b=null,E=null,y=null,w=null,S=null,C=null,v=new oe(0,0,0),R=0,I=!1,N=null,L=null,O=null,P=null,W=null,Et.set(0,0,i.canvas.width,i.canvas.height),Ot.set(0,0,i.canvas.width,i.canvas.height),r.reset(),a.reset(),o.reset()}return{buffers:{color:r,depth:a,stencil:o},enable:nt,disable:_t,bindFramebuffer:wt,drawBuffers:pt,useProgram:It,setBlending:lt,setMaterial:ct,setFlipSided:gt,setCullFace:bt,setLineWidth:Bt,setPolygonOffset:Ut,setScissorTest:Kt,activeTexture:se,bindTexture:F,unbindTexture:re,compressedTexImage2D:ae,compressedTexImage3D:T,texImage2D:tt,texImage3D:ft,pixelStorei:Ht,getParameter:At,updateUBOMapping:Gt,uniformBlockBinding:Jt,texStorage2D:St,texStorage3D:Rt,texSubImage2D:_,texSubImage3D:G,compressedTexSubImage2D:q,compressedTexSubImage3D:rt,scissor:Nt,viewport:Tt,reset:he}}function l3(i,t,e,n,s,r,a){let o=t.has("WEBGL_multisampled_render_to_texture")?t.get("WEBGL_multisampled_render_to_texture"):null,c=typeof navigator>"u"?!1:/OculusBrowser/g.test(navigator.userAgent),l=new yt,h=new WeakMap,f=new Set,u,d=new WeakMap,m=!1;try{m=typeof OffscreenCanvas<"u"&&new OffscreenCanvas(1,1).getContext("2d")!==null}catch{}function x(T,_){return m?new OffscreenCanvas(T,_):cr("canvas")}function g(T,_,G){let q=1,rt=ae(T);if((rt.width>G||rt.height>G)&&(q=G/Math.max(rt.width,rt.height)),q<1)if(typeof HTMLImageElement<"u"&&T instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&T instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&T instanceof ImageBitmap||typeof VideoFrame<"u"&&T instanceof VideoFrame){let St=Math.floor(q*rt.width),Rt=Math.floor(q*rt.height);u===void 0&&(u=x(St,Rt));let tt=_?x(St,Rt):u;return tt.width=St,tt.height=Rt,tt.getContext("2d").drawImage(T,0,0,St,Rt),pe("WebGLRenderer: Texture has been resized from ("+rt.width+"x"+rt.height+") to ("+St+"x"+Rt+")."),tt}else return"data"in T&&pe("WebGLRenderer: Image in DataTexture is too big ("+rt.width+"x"+rt.height+")."),T;return T}function p(T){return T.generateMipmaps}function b(T){i.generateMipmap(T)}function E(T){return T.isWebGLCubeRenderTarget?i.TEXTURE_CUBE_MAP:T.isWebGL3DRenderTarget?i.TEXTURE_3D:T.isWebGLArrayRenderTarget||T.isCompressedArrayTexture?i.TEXTURE_2D_ARRAY:i.TEXTURE_2D}function y(T,_,G,q,rt,St=!1){if(T!==null){if(i[T]!==void 0)return i[T];pe("WebGLRenderer: Attempt to use non-existing WebGL internal format '"+T+"'")}let Rt;q&&(Rt=t.get("EXT_texture_norm16"),Rt||pe("WebGLRenderer: Unable to use normalized textures without EXT_texture_norm16 extension"));let tt=_;if(_===i.RED&&(G===i.FLOAT&&(tt=i.R32F),G===i.HALF_FLOAT&&(tt=i.R16F),G===i.UNSIGNED_BYTE&&(tt=i.R8),G===i.UNSIGNED_SHORT&&Rt&&(tt=Rt.R16_EXT),G===i.SHORT&&Rt&&(tt=Rt.R16_SNORM_EXT)),_===i.RED_INTEGER&&(G===i.UNSIGNED_BYTE&&(tt=i.R8UI),G===i.UNSIGNED_SHORT&&(tt=i.R16UI),G===i.UNSIGNED_INT&&(tt=i.R32UI),G===i.BYTE&&(tt=i.R8I),G===i.SHORT&&(tt=i.R16I),G===i.INT&&(tt=i.R32I)),_===i.RG&&(G===i.FLOAT&&(tt=i.RG32F),G===i.HALF_FLOAT&&(tt=i.RG16F),G===i.UNSIGNED_BYTE&&(tt=i.RG8),G===i.UNSIGNED_SHORT&&Rt&&(tt=Rt.RG16_EXT),G===i.SHORT&&Rt&&(tt=Rt.RG16_SNORM_EXT)),_===i.RG_INTEGER&&(G===i.UNSIGNED_BYTE&&(tt=i.RG8UI),G===i.UNSIGNED_SHORT&&(tt=i.RG16UI),G===i.UNSIGNED_INT&&(tt=i.RG32UI),G===i.BYTE&&(tt=i.RG8I),G===i.SHORT&&(tt=i.RG16I),G===i.INT&&(tt=i.RG32I)),_===i.RGB_INTEGER&&(G===i.UNSIGNED_BYTE&&(tt=i.RGB8UI),G===i.UNSIGNED_SHORT&&(tt=i.RGB16UI),G===i.UNSIGNED_INT&&(tt=i.RGB32UI),G===i.BYTE&&(tt=i.RGB8I),G===i.SHORT&&(tt=i.RGB16I),G===i.INT&&(tt=i.RGB32I)),_===i.RGBA_INTEGER&&(G===i.UNSIGNED_BYTE&&(tt=i.RGBA8UI),G===i.UNSIGNED_SHORT&&(tt=i.RGBA16UI),G===i.UNSIGNED_INT&&(tt=i.RGBA32UI),G===i.BYTE&&(tt=i.RGBA8I),G===i.SHORT&&(tt=i.RGBA16I),G===i.INT&&(tt=i.RGBA32I)),_===i.RGB&&(G===i.UNSIGNED_SHORT&&Rt&&(tt=Rt.RGB16_EXT),G===i.SHORT&&Rt&&(tt=Rt.RGB16_SNORM_EXT),G===i.UNSIGNED_INT_5_9_9_9_REV&&(tt=i.RGB9_E5),G===i.UNSIGNED_INT_10F_11F_11F_REV&&(tt=i.R11F_G11F_B10F)),_===i.RGBA){let ft=St?oa:Re.getTransfer(rt);G===i.FLOAT&&(tt=i.RGBA32F),G===i.HALF_FLOAT&&(tt=i.RGBA16F),G===i.UNSIGNED_BYTE&&(tt=ft===Oe?i.SRGB8_ALPHA8:i.RGBA8),G===i.UNSIGNED_SHORT&&Rt&&(tt=Rt.RGBA16_EXT),G===i.SHORT&&Rt&&(tt=Rt.RGBA16_SNORM_EXT),G===i.UNSIGNED_SHORT_4_4_4_4&&(tt=i.RGBA4),G===i.UNSIGNED_SHORT_5_5_5_1&&(tt=i.RGB5_A1)}return(tt===i.R16F||tt===i.R32F||tt===i.RG16F||tt===i.RG32F||tt===i.RGBA16F||tt===i.RGBA32F)&&t.get("EXT_color_buffer_float"),tt}function w(T,_){let G;return T?_===null||_===pi||_===Ir?G=i.DEPTH24_STENCIL8:_===ti?G=i.DEPTH32F_STENCIL8:_===Cr&&(G=i.DEPTH24_STENCIL8,pe("DepthTexture: 16 bit depth attachment is not supported with stencil. Using 24-bit attachment.")):_===null||_===pi||_===Ir?G=i.DEPTH_COMPONENT24:_===ti?G=i.DEPTH_COMPONENT32F:_===Cr&&(G=i.DEPTH_COMPONENT16),G}function S(T,_){return p(T)===!0||T.isFramebufferTexture&&T.minFilter!==bn&&T.minFilter!==An?Math.log2(Math.max(_.width,_.height))+1:T.mipmaps!==void 0&&T.mipmaps.length>0?T.mipmaps.length:T.isCompressedTexture&&Array.isArray(T.image)?_.mipmaps.length:1}function C(T){let _=T.target;_.removeEventListener("dispose",C),R(_),_.isVideoTexture&&h.delete(_),_.isHTMLTexture&&f.delete(_)}function v(T){let _=T.target;_.removeEventListener("dispose",v),N(_)}function R(T){let _=n.get(T);if(_.__webglInit===void 0)return;let G=T.source,q=d.get(G);if(q){let rt=q[_.__cacheKey];rt.usedTimes--,rt.usedTimes===0&&I(T),Object.keys(q).length===0&&d.delete(G)}n.remove(T)}function I(T){let _=n.get(T);i.deleteTexture(_.__webglTexture);let G=T.source,q=d.get(G);delete q[_.__cacheKey],a.memory.textures--}function N(T){let _=n.get(T);if(T.depthTexture&&(T.depthTexture.dispose(),n.remove(T.depthTexture)),T.isWebGLCubeRenderTarget)for(let q=0;q<6;q++){if(Array.isArray(_.__webglFramebuffer[q]))for(let rt=0;rt<_.__webglFramebuffer[q].length;rt++)i.deleteFramebuffer(_.__webglFramebuffer[q][rt]);else i.deleteFramebuffer(_.__webglFramebuffer[q]);_.__webglDepthbuffer&&i.deleteRenderbuffer(_.__webglDepthbuffer[q])}else{if(Array.isArray(_.__webglFramebuffer))for(let q=0;q<_.__webglFramebuffer.length;q++)i.deleteFramebuffer(_.__webglFramebuffer[q]);else i.deleteFramebuffer(_.__webglFramebuffer);if(_.__webglDepthbuffer&&i.deleteRenderbuffer(_.__webglDepthbuffer),_.__webglMultisampledFramebuffer&&i.deleteFramebuffer(_.__webglMultisampledFramebuffer),_.__webglColorRenderbuffer)for(let q=0;q<_.__webglColorRenderbuffer.length;q++)_.__webglColorRenderbuffer[q]&&i.deleteRenderbuffer(_.__webglColorRenderbuffer[q]);_.__webglDepthRenderbuffer&&i.deleteRenderbuffer(_.__webglDepthRenderbuffer)}let G=T.textures;for(let q=0,rt=G.length;q<rt;q++){let St=n.get(G[q]);St.__webglTexture&&(i.deleteTexture(St.__webglTexture),a.memory.textures--),n.remove(G[q])}n.remove(T)}let L=0;function O(){L=0}function P(){return L}function W(T){L=T}function it(){let T=L;return T>=s.maxTextures&&pe("WebGLTextures: Trying to use "+(T+1)+" texture units while this GPU supports only "+s.maxTextures),L+=1,T}function Q(T){let _=[];return _.push(T.wrapS),_.push(T.wrapT),_.push(T.wrapR||0),_.push(T.magFilter),_.push(T.minFilter),_.push(T.anisotropy),_.push(T.internalFormat),_.push(T.format),_.push(T.type),_.push(T.generateMipmaps),_.push(T.premultiplyAlpha),_.push(T.flipY),_.push(T.unpackAlignment),_.push(T.colorSpace),_.join()}function ht(T,_){let G=n.get(T);if(T.isVideoTexture&&F(T),T.isRenderTargetTexture===!1&&T.isExternalTexture!==!0&&T.version>0&&G.__version!==T.version){let q=T.image;if(q===null)pe("WebGLRenderer: Texture marked for update but no image data found.");else if(q.complete===!1)pe("WebGLRenderer: Texture marked for update but image is incomplete");else{_t(G,T,_);return}}else T.isExternalTexture&&(G.__webglTexture=T.sourceTexture?T.sourceTexture:null);e.bindTexture(i.TEXTURE_2D,G.__webglTexture,i.TEXTURE0+_)}function K(T,_){let G=n.get(T);if(T.isRenderTargetTexture===!1&&T.version>0&&G.__version!==T.version){_t(G,T,_);return}else T.isExternalTexture&&(G.__webglTexture=T.sourceTexture?T.sourceTexture:null);e.bindTexture(i.TEXTURE_2D_ARRAY,G.__webglTexture,i.TEXTURE0+_)}function ot(T,_){let G=n.get(T);if(T.isRenderTargetTexture===!1&&T.version>0&&G.__version!==T.version){_t(G,T,_);return}e.bindTexture(i.TEXTURE_3D,G.__webglTexture,i.TEXTURE0+_)}function z(T,_){let G=n.get(T);if(T.isCubeDepthTexture!==!0&&T.version>0&&G.__version!==T.version){wt(G,T,_);return}e.bindTexture(i.TEXTURE_CUBE_MAP,G.__webglTexture,i.TEXTURE0+_)}let Mt={[rs]:i.REPEAT,[yi]:i.CLAMP_TO_EDGE,[ol]:i.MIRRORED_REPEAT},vt={[bn]:i.NEAREST,[Md]:i.NEAREST_MIPMAP_NEAREST,[ja]:i.NEAREST_MIPMAP_LINEAR,[An]:i.LINEAR,[Ol]:i.LINEAR_MIPMAP_NEAREST,[Ti]:i.LINEAR_MIPMAP_LINEAR},Et={[Ed]:i.NEVER,[Id]:i.ALWAYS,[Td]:i.LESS,[bc]:i.LEQUAL,[Ad]:i.EQUAL,[Sc]:i.GEQUAL,[Rd]:i.GREATER,[Cd]:i.NOTEQUAL};function Ot(T,_){if(_.type===ti&&t.has("OES_texture_float_linear")===!1&&(_.magFilter===An||_.magFilter===Ol||_.magFilter===ja||_.magFilter===Ti||_.minFilter===An||_.minFilter===Ol||_.minFilter===ja||_.minFilter===Ti)&&pe("WebGLRenderer: Unable to use linear filtering with floating point textures. OES_texture_float_linear not supported on this device."),i.texParameteri(T,i.TEXTURE_WRAP_S,Mt[_.wrapS]),i.texParameteri(T,i.TEXTURE_WRAP_T,Mt[_.wrapT]),(T===i.TEXTURE_3D||T===i.TEXTURE_2D_ARRAY)&&i.texParameteri(T,i.TEXTURE_WRAP_R,Mt[_.wrapR]),i.texParameteri(T,i.TEXTURE_MAG_FILTER,vt[_.magFilter]),i.texParameteri(T,i.TEXTURE_MIN_FILTER,vt[_.minFilter]),_.compareFunction&&(i.texParameteri(T,i.TEXTURE_COMPARE_MODE,i.COMPARE_REF_TO_TEXTURE),i.texParameteri(T,i.TEXTURE_COMPARE_FUNC,Et[_.compareFunction])),t.has("EXT_texture_filter_anisotropic")===!0){if(_.magFilter===bn||_.minFilter!==ja&&_.minFilter!==Ti||_.type===ti&&t.has("OES_texture_float_linear")===!1)return;if(_.anisotropy>1||n.get(_).__currentAnisotropy){let G=t.get("EXT_texture_filter_anisotropic");i.texParameterf(T,G.TEXTURE_MAX_ANISOTROPY_EXT,Math.min(_.anisotropy,s.getMaxAnisotropy())),n.get(_).__currentAnisotropy=_.anisotropy}}}function Lt(T,_){let G=!1;T.__webglInit===void 0&&(T.__webglInit=!0,_.addEventListener("dispose",C));let q=_.source,rt=d.get(q);rt===void 0&&(rt={},d.set(q,rt));let St=Q(_);if(St!==T.__cacheKey){rt[St]===void 0&&(rt[St]={texture:i.createTexture(),usedTimes:0},a.memory.textures++,G=!0),rt[St].usedTimes++;let Rt=rt[T.__cacheKey];Rt!==void 0&&(rt[T.__cacheKey].usedTimes--,Rt.usedTimes===0&&I(_)),T.__cacheKey=St,T.__webglTexture=rt[St].texture}return G}function et(T,_,G){return Math.floor(Math.floor(T/G)/_)}function nt(T,_,G,q){let St=T.updateRanges;if(St.length===0)e.texSubImage2D(i.TEXTURE_2D,0,0,0,_.width,_.height,G,q,_.data);else{St.sort((Ht,Nt)=>Ht.start-Nt.start);let Rt=0;for(let Ht=1;Ht<St.length;Ht++){let Nt=St[Rt],Tt=St[Ht],Gt=Nt.start+Nt.count,Jt=et(Tt.start,_.width,4),he=et(Nt.start,_.width,4);Tt.start<=Gt+1&&Jt===he&&et(Tt.start+Tt.count-1,_.width,4)===Jt?Nt.count=Math.max(Nt.count,Tt.start+Tt.count-Nt.start):(++Rt,St[Rt]=Tt)}St.length=Rt+1;let tt=e.getParameter(i.UNPACK_ROW_LENGTH),ft=e.getParameter(i.UNPACK_SKIP_PIXELS),At=e.getParameter(i.UNPACK_SKIP_ROWS);e.pixelStorei(i.UNPACK_ROW_LENGTH,_.width);for(let Ht=0,Nt=St.length;Ht<Nt;Ht++){let Tt=St[Ht],Gt=Math.floor(Tt.start/4),Jt=Math.ceil(Tt.count/4),he=Gt%_.width,B=Math.floor(Gt/_.width),Ft=Jt,mt=1;e.pixelStorei(i.UNPACK_SKIP_PIXELS,he),e.pixelStorei(i.UNPACK_SKIP_ROWS,B),e.texSubImage2D(i.TEXTURE_2D,0,he,B,Ft,mt,G,q,_.data)}T.clearUpdateRanges(),e.pixelStorei(i.UNPACK_ROW_LENGTH,tt),e.pixelStorei(i.UNPACK_SKIP_PIXELS,ft),e.pixelStorei(i.UNPACK_SKIP_ROWS,At)}}function _t(T,_,G){let q=i.TEXTURE_2D;(_.isDataArrayTexture||_.isCompressedArrayTexture)&&(q=i.TEXTURE_2D_ARRAY),_.isData3DTexture&&(q=i.TEXTURE_3D);let rt=Lt(T,_),St=_.source;e.bindTexture(q,T.__webglTexture,i.TEXTURE0+G);let Rt=n.get(St);if(St.version!==Rt.__version||rt===!0){if(e.activeTexture(i.TEXTURE0+G),(typeof ImageBitmap<"u"&&_.image instanceof ImageBitmap)===!1){let mt=Re.getPrimaries(Re.workingColorSpace),Dt=_.colorSpace===mi?null:Re.getPrimaries(_.colorSpace),kt=_.colorSpace===mi||mt===Dt?i.NONE:i.BROWSER_DEFAULT_WEBGL;e.pixelStorei(i.UNPACK_FLIP_Y_WEBGL,_.flipY),e.pixelStorei(i.UNPACK_PREMULTIPLY_ALPHA_WEBGL,_.premultiplyAlpha),e.pixelStorei(i.UNPACK_COLORSPACE_CONVERSION_WEBGL,kt)}e.pixelStorei(i.UNPACK_ALIGNMENT,_.unpackAlignment);let ft=g(_.image,!1,s.maxTextureSize);ft=re(_,ft);let At=r.convert(_.format,_.colorSpace),Ht=r.convert(_.type),Nt=y(_.internalFormat,At,Ht,_.normalized,_.colorSpace,_.isVideoTexture);Ot(q,_);let Tt,Gt=_.mipmaps,Jt=_.isVideoTexture!==!0,he=Rt.__version===void 0||rt===!0,B=St.dataReady,Ft=S(_,ft);if(_.isDepthTexture)Nt=w(_.format===gs,_.type),he&&(Jt?e.texStorage2D(i.TEXTURE_2D,1,Nt,ft.width,ft.height):e.texImage2D(i.TEXTURE_2D,0,Nt,ft.width,ft.height,0,At,Ht,null));else if(_.isDataTexture)if(Gt.length>0){Jt&&he&&e.texStorage2D(i.TEXTURE_2D,Ft,Nt,Gt[0].width,Gt[0].height);for(let mt=0,Dt=Gt.length;mt<Dt;mt++)Tt=Gt[mt],Jt?B&&e.texSubImage2D(i.TEXTURE_2D,mt,0,0,Tt.width,Tt.height,At,Ht,Tt.data):e.texImage2D(i.TEXTURE_2D,mt,Nt,Tt.width,Tt.height,0,At,Ht,Tt.data);_.generateMipmaps=!1}else Jt?(he&&e.texStorage2D(i.TEXTURE_2D,Ft,Nt,ft.width,ft.height),B&&nt(_,ft,At,Ht)):e.texImage2D(i.TEXTURE_2D,0,Nt,ft.width,ft.height,0,At,Ht,ft.data);else if(_.isCompressedTexture)if(_.isCompressedArrayTexture){Jt&&he&&e.texStorage3D(i.TEXTURE_2D_ARRAY,Ft,Nt,Gt[0].width,Gt[0].height,ft.depth);for(let mt=0,Dt=Gt.length;mt<Dt;mt++)if(Tt=Gt[mt],_.format!==ei)if(At!==null)if(Jt){if(B)if(_.layerUpdates.size>0){let kt=dh(Tt.width,Tt.height,_.format,_.type);for(let ut of _.layerUpdates){let ie=Tt.data.subarray(ut*kt/Tt.data.BYTES_PER_ELEMENT,(ut+1)*kt/Tt.data.BYTES_PER_ELEMENT);e.compressedTexSubImage3D(i.TEXTURE_2D_ARRAY,mt,0,0,ut,Tt.width,Tt.height,1,At,ie)}}else e.compressedTexSubImage3D(i.TEXTURE_2D_ARRAY,mt,0,0,0,Tt.width,Tt.height,ft.depth,At,Tt.data)}else e.compressedTexImage3D(i.TEXTURE_2D_ARRAY,mt,Nt,Tt.width,Tt.height,ft.depth,0,Tt.data,0,0);else pe("WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()");else Jt?B&&e.texSubImage3D(i.TEXTURE_2D_ARRAY,mt,0,0,0,Tt.width,Tt.height,ft.depth,At,Ht,Tt.data):e.texImage3D(i.TEXTURE_2D_ARRAY,mt,Nt,Tt.width,Tt.height,ft.depth,0,At,Ht,Tt.data);_.layerUpdates.size>0&&_.clearLayerUpdates()}else{Jt&&he&&e.texStorage2D(i.TEXTURE_2D,Ft,Nt,Gt[0].width,Gt[0].height);for(let mt=0,Dt=Gt.length;mt<Dt;mt++)Tt=Gt[mt],_.format!==ei?At!==null?Jt?B&&e.compressedTexSubImage2D(i.TEXTURE_2D,mt,0,0,Tt.width,Tt.height,At,Tt.data):e.compressedTexImage2D(i.TEXTURE_2D,mt,Nt,Tt.width,Tt.height,0,Tt.data):pe("WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()"):Jt?B&&e.texSubImage2D(i.TEXTURE_2D,mt,0,0,Tt.width,Tt.height,At,Ht,Tt.data):e.texImage2D(i.TEXTURE_2D,mt,Nt,Tt.width,Tt.height,0,At,Ht,Tt.data)}else if(_.isDataArrayTexture)if(Jt){if(he&&e.texStorage3D(i.TEXTURE_2D_ARRAY,Ft,Nt,ft.width,ft.height,ft.depth),B)if(_.layerUpdates.size>0){let mt=dh(ft.width,ft.height,_.format,_.type);for(let Dt of _.layerUpdates){let kt=ft.data.subarray(Dt*mt/ft.data.BYTES_PER_ELEMENT,(Dt+1)*mt/ft.data.BYTES_PER_ELEMENT);e.texSubImage3D(i.TEXTURE_2D_ARRAY,0,0,0,Dt,ft.width,ft.height,1,At,Ht,kt)}_.clearLayerUpdates()}else e.texSubImage3D(i.TEXTURE_2D_ARRAY,0,0,0,0,ft.width,ft.height,ft.depth,At,Ht,ft.data)}else e.texImage3D(i.TEXTURE_2D_ARRAY,0,Nt,ft.width,ft.height,ft.depth,0,At,Ht,ft.data);else if(_.isData3DTexture)Jt?(he&&e.texStorage3D(i.TEXTURE_3D,Ft,Nt,ft.width,ft.height,ft.depth),B&&e.texSubImage3D(i.TEXTURE_3D,0,0,0,0,ft.width,ft.height,ft.depth,At,Ht,ft.data)):e.texImage3D(i.TEXTURE_3D,0,Nt,ft.width,ft.height,ft.depth,0,At,Ht,ft.data);else if(_.isFramebufferTexture){if(he)if(Jt)e.texStorage2D(i.TEXTURE_2D,Ft,Nt,ft.width,ft.height);else{let mt=ft.width,Dt=ft.height;for(let kt=0;kt<Ft;kt++)e.texImage2D(i.TEXTURE_2D,kt,Nt,mt,Dt,0,At,Ht,null),mt>>=1,Dt>>=1}}else if(_.isHTMLTexture){if("texElementImage2D"in i){let mt=i.canvas;if(mt.hasAttribute("layoutsubtree")||mt.setAttribute("layoutsubtree","true"),ft.parentNode!==mt){mt.appendChild(ft),f.add(_),mt.onpaint=Dt=>{let kt=Dt.changedElements;for(let ut of f)kt.includes(ut.image)&&(ut.needsUpdate=!0)},mt.requestPaint();return}if(i.texElementImage2D.length===3)i.texElementImage2D(i.TEXTURE_2D,i.RGBA8,ft);else{let kt=i.RGBA,ut=i.RGBA,ie=i.UNSIGNED_BYTE;i.texElementImage2D(i.TEXTURE_2D,0,kt,ut,ie,ft)}i.texParameteri(i.TEXTURE_2D,i.TEXTURE_MIN_FILTER,i.LINEAR),i.texParameteri(i.TEXTURE_2D,i.TEXTURE_WRAP_S,i.CLAMP_TO_EDGE),i.texParameteri(i.TEXTURE_2D,i.TEXTURE_WRAP_T,i.CLAMP_TO_EDGE)}}else if(Gt.length>0){if(Jt&&he){let mt=ae(Gt[0]);e.texStorage2D(i.TEXTURE_2D,Ft,Nt,mt.width,mt.height)}for(let mt=0,Dt=Gt.length;mt<Dt;mt++)Tt=Gt[mt],Jt?B&&e.texSubImage2D(i.TEXTURE_2D,mt,0,0,At,Ht,Tt):e.texImage2D(i.TEXTURE_2D,mt,Nt,At,Ht,Tt);_.generateMipmaps=!1}else if(Jt){if(he){let mt=ae(ft);e.texStorage2D(i.TEXTURE_2D,Ft,Nt,mt.width,mt.height)}B&&e.texSubImage2D(i.TEXTURE_2D,0,0,0,At,Ht,ft)}else e.texImage2D(i.TEXTURE_2D,0,Nt,At,Ht,ft);p(_)&&b(q),Rt.__version=St.version,_.onUpdate&&_.onUpdate(_)}T.__version=_.version}function wt(T,_,G){if(_.image.length!==6)return;let q=Lt(T,_),rt=_.source;e.bindTexture(i.TEXTURE_CUBE_MAP,T.__webglTexture,i.TEXTURE0+G);let St=n.get(rt);if(rt.version!==St.__version||q===!0){e.activeTexture(i.TEXTURE0+G);let Rt=Re.getPrimaries(Re.workingColorSpace),tt=_.colorSpace===mi?null:Re.getPrimaries(_.colorSpace),ft=_.colorSpace===mi||Rt===tt?i.NONE:i.BROWSER_DEFAULT_WEBGL;e.pixelStorei(i.UNPACK_FLIP_Y_WEBGL,_.flipY),e.pixelStorei(i.UNPACK_PREMULTIPLY_ALPHA_WEBGL,_.premultiplyAlpha),e.pixelStorei(i.UNPACK_ALIGNMENT,_.unpackAlignment),e.pixelStorei(i.UNPACK_COLORSPACE_CONVERSION_WEBGL,ft);let At=_.isCompressedTexture||_.image[0].isCompressedTexture,Ht=_.image[0]&&_.image[0].isDataTexture,Nt=[];for(let ut=0;ut<6;ut++)!At&&!Ht?Nt[ut]=g(_.image[ut],!0,s.maxCubemapSize):Nt[ut]=Ht?_.image[ut].image:_.image[ut],Nt[ut]=re(_,Nt[ut]);let Tt=Nt[0],Gt=r.convert(_.format,_.colorSpace),Jt=r.convert(_.type),he=y(_.internalFormat,Gt,Jt,_.normalized,_.colorSpace),B=_.isVideoTexture!==!0,Ft=St.__version===void 0||q===!0,mt=rt.dataReady,Dt=S(_,Tt);Ot(i.TEXTURE_CUBE_MAP,_);let kt;if(At){B&&Ft&&e.texStorage2D(i.TEXTURE_CUBE_MAP,Dt,he,Tt.width,Tt.height);for(let ut=0;ut<6;ut++){kt=Nt[ut].mipmaps;for(let ie=0;ie<kt.length;ie++){let jt=kt[ie];_.format!==ei?Gt!==null?B?mt&&e.compressedTexSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+ut,ie,0,0,jt.width,jt.height,Gt,jt.data):e.compressedTexImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+ut,ie,he,jt.width,jt.height,0,jt.data):pe("WebGLRenderer: Attempt to load unsupported compressed texture format in .setTextureCube()"):B?mt&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+ut,ie,0,0,jt.width,jt.height,Gt,Jt,jt.data):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+ut,ie,he,jt.width,jt.height,0,Gt,Jt,jt.data)}}}else{if(kt=_.mipmaps,B&&Ft){kt.length>0&&Dt++;let ut=ae(Nt[0]);e.texStorage2D(i.TEXTURE_CUBE_MAP,Dt,he,ut.width,ut.height)}for(let ut=0;ut<6;ut++)if(Ht){B?mt&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+ut,0,0,0,Nt[ut].width,Nt[ut].height,Gt,Jt,Nt[ut].data):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+ut,0,he,Nt[ut].width,Nt[ut].height,0,Gt,Jt,Nt[ut].data);for(let ie=0;ie<kt.length;ie++){let Be=kt[ie].image[ut].image;B?mt&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+ut,ie+1,0,0,Be.width,Be.height,Gt,Jt,Be.data):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+ut,ie+1,he,Be.width,Be.height,0,Gt,Jt,Be.data)}}else{B?mt&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+ut,0,0,0,Gt,Jt,Nt[ut]):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+ut,0,he,Gt,Jt,Nt[ut]);for(let ie=0;ie<kt.length;ie++){let jt=kt[ie];B?mt&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+ut,ie+1,0,0,Gt,Jt,jt.image[ut]):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+ut,ie+1,he,Gt,Jt,jt.image[ut])}}}p(_)&&b(i.TEXTURE_CUBE_MAP),St.__version=rt.version,_.onUpdate&&_.onUpdate(_)}T.__version=_.version}function pt(T,_,G,q,rt,St){let Rt=r.convert(G.format,G.colorSpace),tt=r.convert(G.type),ft=y(G.internalFormat,Rt,tt,G.normalized,G.colorSpace),At=n.get(_),Ht=n.get(G);if(Ht.__renderTarget=_,!At.__hasExternalTextures){let Nt=Math.max(1,_.width>>St),Tt=Math.max(1,_.height>>St);rt===i.TEXTURE_3D||rt===i.TEXTURE_2D_ARRAY?e.texImage3D(rt,St,ft,Nt,Tt,_.depth,0,Rt,tt,null):e.texImage2D(rt,St,ft,Nt,Tt,0,Rt,tt,null)}e.bindFramebuffer(i.FRAMEBUFFER,T),se(_)?o.framebufferTexture2DMultisampleEXT(i.FRAMEBUFFER,q,rt,Ht.__webglTexture,0,Kt(_)):(rt===i.TEXTURE_2D||rt>=i.TEXTURE_CUBE_MAP_POSITIVE_X&&rt<=i.TEXTURE_CUBE_MAP_NEGATIVE_Z)&&i.framebufferTexture2D(i.FRAMEBUFFER,q,rt,Ht.__webglTexture,St),e.bindFramebuffer(i.FRAMEBUFFER,null)}function It(T,_,G){if(i.bindRenderbuffer(i.RENDERBUFFER,T),_.depthBuffer){let q=_.depthTexture,rt=q&&q.isDepthTexture?q.type:null,St=w(_.stencilBuffer,rt),Rt=_.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT;se(_)?o.renderbufferStorageMultisampleEXT(i.RENDERBUFFER,Kt(_),St,_.width,_.height):G?i.renderbufferStorageMultisample(i.RENDERBUFFER,Kt(_),St,_.width,_.height):i.renderbufferStorage(i.RENDERBUFFER,St,_.width,_.height),i.framebufferRenderbuffer(i.FRAMEBUFFER,Rt,i.RENDERBUFFER,T)}else{let q=_.textures;for(let rt=0;rt<q.length;rt++){let St=q[rt],Rt=r.convert(St.format,St.colorSpace),tt=r.convert(St.type),ft=y(St.internalFormat,Rt,tt,St.normalized,St.colorSpace);se(_)?o.renderbufferStorageMultisampleEXT(i.RENDERBUFFER,Kt(_),ft,_.width,_.height):G?i.renderbufferStorageMultisample(i.RENDERBUFFER,Kt(_),ft,_.width,_.height):i.renderbufferStorage(i.RENDERBUFFER,ft,_.width,_.height)}}i.bindRenderbuffer(i.RENDERBUFFER,null)}function ee(T,_,G){let q=_.isWebGLCubeRenderTarget===!0;if(e.bindFramebuffer(i.FRAMEBUFFER,T),!(_.depthTexture&&_.depthTexture.isDepthTexture))throw new Error("THREE.WebGLTextures: renderTarget.depthTexture must be an instance of THREE.DepthTexture.");let rt=n.get(_.depthTexture);if(rt.__renderTarget=_,(!rt.__webglTexture||_.depthTexture.image.width!==_.width||_.depthTexture.image.height!==_.height)&&(_.depthTexture.image.width=_.width,_.depthTexture.image.height=_.height,_.depthTexture.needsUpdate=!0),q){if(rt.__webglInit===void 0&&(rt.__webglInit=!0,_.depthTexture.addEventListener("dispose",C)),rt.__webglTexture===void 0){rt.__webglTexture=i.createTexture(),e.bindTexture(i.TEXTURE_CUBE_MAP,rt.__webglTexture),Ot(i.TEXTURE_CUBE_MAP,_.depthTexture);let At=r.convert(_.depthTexture.format),Ht=r.convert(_.depthTexture.type),Nt;_.depthTexture.format===bi?Nt=i.DEPTH_COMPONENT24:_.depthTexture.format===gs&&(Nt=i.DEPTH24_STENCIL8);for(let Tt=0;Tt<6;Tt++)i.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+Tt,0,Nt,_.width,_.height,0,At,Ht,null)}}else ht(_.depthTexture,0);let St=rt.__webglTexture,Rt=Kt(_),tt=q?i.TEXTURE_CUBE_MAP_POSITIVE_X+G:i.TEXTURE_2D,ft=_.depthTexture.format===gs?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT;if(_.depthTexture.format===bi)se(_)?o.framebufferTexture2DMultisampleEXT(i.FRAMEBUFFER,ft,tt,St,0,Rt):i.framebufferTexture2D(i.FRAMEBUFFER,ft,tt,St,0);else if(_.depthTexture.format===gs)se(_)?o.framebufferTexture2DMultisampleEXT(i.FRAMEBUFFER,ft,tt,St,0,Rt):i.framebufferTexture2D(i.FRAMEBUFFER,ft,tt,St,0);else throw new Error("THREE.WebGLTextures: Unknown depthTexture format.")}function V(T){let _=n.get(T),G=T.isWebGLCubeRenderTarget===!0;if(_.__boundDepthTexture!==T.depthTexture){let q=T.depthTexture;if(_.__depthDisposeCallback&&_.__depthDisposeCallback(),q){let rt=()=>{delete _.__boundDepthTexture,delete _.__depthDisposeCallback,q.removeEventListener("dispose",rt)};q.addEventListener("dispose",rt),_.__depthDisposeCallback=rt}_.__boundDepthTexture=q}if(T.depthTexture&&!_.__autoAllocateDepthBuffer)if(G)for(let q=0;q<6;q++)ee(_.__webglFramebuffer[q],T,q);else{let q=T.texture.mipmaps;q&&q.length>0?ee(_.__webglFramebuffer[0],T,0):ee(_.__webglFramebuffer,T,0)}else if(G){_.__webglDepthbuffer=[];for(let q=0;q<6;q++)if(e.bindFramebuffer(i.FRAMEBUFFER,_.__webglFramebuffer[q]),_.__webglDepthbuffer[q]===void 0)_.__webglDepthbuffer[q]=i.createRenderbuffer(),It(_.__webglDepthbuffer[q],T,!1);else{let rt=T.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT,St=_.__webglDepthbuffer[q];i.bindRenderbuffer(i.RENDERBUFFER,St),i.framebufferRenderbuffer(i.FRAMEBUFFER,rt,i.RENDERBUFFER,St)}}else{let q=T.texture.mipmaps;if(q&&q.length>0?e.bindFramebuffer(i.FRAMEBUFFER,_.__webglFramebuffer[0]):e.bindFramebuffer(i.FRAMEBUFFER,_.__webglFramebuffer),_.__webglDepthbuffer===void 0)_.__webglDepthbuffer=i.createRenderbuffer(),It(_.__webglDepthbuffer,T,!1);else{let rt=T.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT,St=_.__webglDepthbuffer;i.bindRenderbuffer(i.RENDERBUFFER,St),i.framebufferRenderbuffer(i.FRAMEBUFFER,rt,i.RENDERBUFFER,St)}}e.bindFramebuffer(i.FRAMEBUFFER,null)}function lt(T,_,G){let q=n.get(T);_!==void 0&&pt(q.__webglFramebuffer,T,T.texture,i.COLOR_ATTACHMENT0,i.TEXTURE_2D,0),G!==void 0&&V(T)}function ct(T){let _=T.texture,G=n.get(T),q=n.get(_);T.addEventListener("dispose",v);let rt=T.textures,St=T.isWebGLCubeRenderTarget===!0,Rt=rt.length>1;if(Rt||(q.__webglTexture===void 0&&(q.__webglTexture=i.createTexture()),q.__version=_.version,a.memory.textures++),St){G.__webglFramebuffer=[];for(let tt=0;tt<6;tt++)if(_.mipmaps&&_.mipmaps.length>0){G.__webglFramebuffer[tt]=[];for(let ft=0;ft<_.mipmaps.length;ft++)G.__webglFramebuffer[tt][ft]=i.createFramebuffer()}else G.__webglFramebuffer[tt]=i.createFramebuffer()}else{if(_.mipmaps&&_.mipmaps.length>0){G.__webglFramebuffer=[];for(let tt=0;tt<_.mipmaps.length;tt++)G.__webglFramebuffer[tt]=i.createFramebuffer()}else G.__webglFramebuffer=i.createFramebuffer();if(Rt)for(let tt=0,ft=rt.length;tt<ft;tt++){let At=n.get(rt[tt]);At.__webglTexture===void 0&&(At.__webglTexture=i.createTexture(),a.memory.textures++)}if(T.samples>0&&se(T)===!1){G.__webglMultisampledFramebuffer=i.createFramebuffer(),G.__webglColorRenderbuffer=[],e.bindFramebuffer(i.FRAMEBUFFER,G.__webglMultisampledFramebuffer);for(let tt=0;tt<rt.length;tt++){let ft=rt[tt];G.__webglColorRenderbuffer[tt]=i.createRenderbuffer(),i.bindRenderbuffer(i.RENDERBUFFER,G.__webglColorRenderbuffer[tt]);let At=r.convert(ft.format,ft.colorSpace),Ht=r.convert(ft.type),Nt=y(ft.internalFormat,At,Ht,ft.normalized,ft.colorSpace,T.isXRRenderTarget===!0),Tt=Kt(T);i.renderbufferStorageMultisample(i.RENDERBUFFER,Tt,Nt,T.width,T.height),i.framebufferRenderbuffer(i.FRAMEBUFFER,i.COLOR_ATTACHMENT0+tt,i.RENDERBUFFER,G.__webglColorRenderbuffer[tt])}i.bindRenderbuffer(i.RENDERBUFFER,null),T.depthBuffer&&(G.__webglDepthRenderbuffer=i.createRenderbuffer(),It(G.__webglDepthRenderbuffer,T,!0)),e.bindFramebuffer(i.FRAMEBUFFER,null)}}if(St){e.bindTexture(i.TEXTURE_CUBE_MAP,q.__webglTexture),Ot(i.TEXTURE_CUBE_MAP,_);for(let tt=0;tt<6;tt++)if(_.mipmaps&&_.mipmaps.length>0)for(let ft=0;ft<_.mipmaps.length;ft++)pt(G.__webglFramebuffer[tt][ft],T,_,i.COLOR_ATTACHMENT0,i.TEXTURE_CUBE_MAP_POSITIVE_X+tt,ft);else pt(G.__webglFramebuffer[tt],T,_,i.COLOR_ATTACHMENT0,i.TEXTURE_CUBE_MAP_POSITIVE_X+tt,0);p(_)&&b(i.TEXTURE_CUBE_MAP),e.unbindTexture()}else if(Rt){for(let tt=0,ft=rt.length;tt<ft;tt++){let At=rt[tt],Ht=n.get(At),Nt=i.TEXTURE_2D;(T.isWebGL3DRenderTarget||T.isWebGLArrayRenderTarget)&&(Nt=T.isWebGL3DRenderTarget?i.TEXTURE_3D:i.TEXTURE_2D_ARRAY),e.bindTexture(Nt,Ht.__webglTexture),Ot(Nt,At),pt(G.__webglFramebuffer,T,At,i.COLOR_ATTACHMENT0+tt,Nt,0),p(At)&&b(Nt)}e.unbindTexture()}else{let tt=i.TEXTURE_2D;if((T.isWebGL3DRenderTarget||T.isWebGLArrayRenderTarget)&&(tt=T.isWebGL3DRenderTarget?i.TEXTURE_3D:i.TEXTURE_2D_ARRAY),e.bindTexture(tt,q.__webglTexture),Ot(tt,_),_.mipmaps&&_.mipmaps.length>0)for(let ft=0;ft<_.mipmaps.length;ft++)pt(G.__webglFramebuffer[ft],T,_,i.COLOR_ATTACHMENT0,tt,ft);else pt(G.__webglFramebuffer,T,_,i.COLOR_ATTACHMENT0,tt,0);p(_)&&b(tt),e.unbindTexture()}T.depthBuffer&&V(T)}function gt(T){let _=T.textures;for(let G=0,q=_.length;G<q;G++){let rt=_[G];if(p(rt)){let St=E(T),Rt=n.get(rt).__webglTexture;e.bindTexture(St,Rt),b(St),e.unbindTexture()}}}let bt=[],Bt=[];function Ut(T){if(T.samples>0){if(se(T)===!1){let _=T.textures,G=T.width,q=T.height,rt=i.COLOR_BUFFER_BIT,St=T.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT,Rt=n.get(T),tt=_.length>1;if(tt)for(let At=0;At<_.length;At++)e.bindFramebuffer(i.FRAMEBUFFER,Rt.__webglMultisampledFramebuffer),i.framebufferRenderbuffer(i.FRAMEBUFFER,i.COLOR_ATTACHMENT0+At,i.RENDERBUFFER,null),e.bindFramebuffer(i.FRAMEBUFFER,Rt.__webglFramebuffer),i.framebufferTexture2D(i.DRAW_FRAMEBUFFER,i.COLOR_ATTACHMENT0+At,i.TEXTURE_2D,null,0);e.bindFramebuffer(i.READ_FRAMEBUFFER,Rt.__webglMultisampledFramebuffer);let ft=T.texture.mipmaps;ft&&ft.length>0?e.bindFramebuffer(i.DRAW_FRAMEBUFFER,Rt.__webglFramebuffer[0]):e.bindFramebuffer(i.DRAW_FRAMEBUFFER,Rt.__webglFramebuffer);for(let At=0;At<_.length;At++){if(T.resolveDepthBuffer&&(T.depthBuffer&&(rt|=i.DEPTH_BUFFER_BIT),T.stencilBuffer&&T.resolveStencilBuffer&&(rt|=i.STENCIL_BUFFER_BIT)),tt){i.framebufferRenderbuffer(i.READ_FRAMEBUFFER,i.COLOR_ATTACHMENT0,i.RENDERBUFFER,Rt.__webglColorRenderbuffer[At]);let Ht=n.get(_[At]).__webglTexture;i.framebufferTexture2D(i.DRAW_FRAMEBUFFER,i.COLOR_ATTACHMENT0,i.TEXTURE_2D,Ht,0)}i.blitFramebuffer(0,0,G,q,0,0,G,q,rt,i.NEAREST),c===!0&&(bt.length=0,Bt.length=0,bt.push(i.COLOR_ATTACHMENT0+At),T.depthBuffer&&T.storeMultisampledDepthBuffer===!1&&(bt.push(St),Bt.push(St),i.invalidateFramebuffer(i.DRAW_FRAMEBUFFER,Bt)),i.invalidateFramebuffer(i.READ_FRAMEBUFFER,bt))}if(e.bindFramebuffer(i.READ_FRAMEBUFFER,null),e.bindFramebuffer(i.DRAW_FRAMEBUFFER,null),tt)for(let At=0;At<_.length;At++){e.bindFramebuffer(i.FRAMEBUFFER,Rt.__webglMultisampledFramebuffer),i.framebufferRenderbuffer(i.FRAMEBUFFER,i.COLOR_ATTACHMENT0+At,i.RENDERBUFFER,Rt.__webglColorRenderbuffer[At]);let Ht=n.get(_[At]).__webglTexture;e.bindFramebuffer(i.FRAMEBUFFER,Rt.__webglFramebuffer),i.framebufferTexture2D(i.DRAW_FRAMEBUFFER,i.COLOR_ATTACHMENT0+At,i.TEXTURE_2D,Ht,0)}e.bindFramebuffer(i.DRAW_FRAMEBUFFER,Rt.__webglMultisampledFramebuffer)}else if(T.depthBuffer&&T.storeMultisampledDepthBuffer===!1&&c){let _=T.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT;i.invalidateFramebuffer(i.DRAW_FRAMEBUFFER,[_])}}}function Kt(T){return Math.min(s.maxSamples,T.samples)}function se(T){let _=n.get(T);return T.samples>0&&t.has("WEBGL_multisampled_render_to_texture")===!0&&_.__useRenderToTexture!==!1}function F(T){let _=a.render.frame;h.get(T)!==_&&(h.set(T,_),T.update())}function re(T,_){let G=T.colorSpace,q=T.format,rt=T.type;return T.isCompressedTexture===!0||T.isVideoTexture===!0||G!==aa&&G!==mi&&(Re.getTransfer(G)===Oe?(q!==ei||rt!==kn)&&pe("WebGLTextures: sRGB encoded textures have to use RGBAFormat and UnsignedByteType."):fe("WebGLTextures: Unsupported texture color space:",G)),_}function ae(T){return typeof HTMLImageElement<"u"&&T instanceof HTMLImageElement?(l.width=T.naturalWidth||T.width,l.height=T.naturalHeight||T.height):typeof VideoFrame<"u"&&T instanceof VideoFrame?(l.width=T.displayWidth,l.height=T.displayHeight):(l.width=T.width,l.height=T.height),l}this.allocateTextureUnit=it,this.resetTextureUnits=O,this.getTextureUnits=P,this.setTextureUnits=W,this.setTexture2D=ht,this.setTexture2DArray=K,this.setTexture3D=ot,this.setTextureCube=z,this.rebindTextures=lt,this.setupRenderTarget=ct,this.updateRenderTargetMipmap=gt,this.updateMultisampleRenderTarget=Ut,this.setupDepthRenderbuffer=V,this.setupFrameBufferTexture=pt,this.useMultisampledRTT=se,this.isReversedDepthBuffer=function(){return e.buffers.depth.getReversed()}}function c3(i,t){function e(n,s=mi){let r,a=Re.getTransfer(s);if(n===kn)return i.UNSIGNED_BYTE;if(n===zl)return i.UNSIGNED_SHORT_4_4_4_4;if(n===kl)return i.UNSIGNED_SHORT_5_5_5_1;if(n===nh)return i.UNSIGNED_INT_5_9_9_9_REV;if(n===ih)return i.UNSIGNED_INT_10F_11F_11F_REV;if(n===th)return i.BYTE;if(n===eh)return i.SHORT;if(n===Cr)return i.UNSIGNED_SHORT;if(n===Bl)return i.INT;if(n===pi)return i.UNSIGNED_INT;if(n===ti)return i.FLOAT;if(n===mn)return i.HALF_FLOAT;if(n===sh)return i.ALPHA;if(n===rh)return i.RGB;if(n===ei)return i.RGBA;if(n===bi)return i.DEPTH_COMPONENT;if(n===gs)return i.DEPTH_STENCIL;if(n===Hl)return i.RED;if(n===Vl)return i.RED_INTEGER;if(n===xs)return i.RG;if(n===Gl)return i.RG_INTEGER;if(n===Wl)return i.RGBA_INTEGER;if(n===Qa||n===to||n===eo||n===no)if(a===Oe)if(r=t.get("WEBGL_compressed_texture_s3tc_srgb"),r!==null){if(n===Qa)return r.COMPRESSED_SRGB_S3TC_DXT1_EXT;if(n===to)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT;if(n===eo)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT;if(n===no)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT}else return null;else if(r=t.get("WEBGL_compressed_texture_s3tc"),r!==null){if(n===Qa)return r.COMPRESSED_RGB_S3TC_DXT1_EXT;if(n===to)return r.COMPRESSED_RGBA_S3TC_DXT1_EXT;if(n===eo)return r.COMPRESSED_RGBA_S3TC_DXT3_EXT;if(n===no)return r.COMPRESSED_RGBA_S3TC_DXT5_EXT}else return null;if(n===Xl||n===$l||n===ql||n===Yl)if(r=t.get("WEBGL_compressed_texture_pvrtc"),r!==null){if(n===Xl)return r.COMPRESSED_RGB_PVRTC_4BPPV1_IMG;if(n===$l)return r.COMPRESSED_RGB_PVRTC_2BPPV1_IMG;if(n===ql)return r.COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;if(n===Yl)return r.COMPRESSED_RGBA_PVRTC_2BPPV1_IMG}else return null;if(n===Zl||n===Jl||n===Kl||n===jl||n===Ql||n===io||n===tc)if(r=t.get("WEBGL_compressed_texture_etc"),r!==null){if(n===Zl||n===Jl)return a===Oe?r.COMPRESSED_SRGB8_ETC2:r.COMPRESSED_RGB8_ETC2;if(n===Kl)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ETC2_EAC:r.COMPRESSED_RGBA8_ETC2_EAC;if(n===jl)return r.COMPRESSED_R11_EAC;if(n===Ql)return r.COMPRESSED_SIGNED_R11_EAC;if(n===io)return r.COMPRESSED_RG11_EAC;if(n===tc)return r.COMPRESSED_SIGNED_RG11_EAC}else return null;if(n===ec||n===nc||n===ic||n===sc||n===rc||n===ac||n===oc||n===lc||n===cc||n===hc||n===uc||n===dc||n===fc||n===pc)if(r=t.get("WEBGL_compressed_texture_astc"),r!==null){if(n===ec)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR:r.COMPRESSED_RGBA_ASTC_4x4_KHR;if(n===nc)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR:r.COMPRESSED_RGBA_ASTC_5x4_KHR;if(n===ic)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR:r.COMPRESSED_RGBA_ASTC_5x5_KHR;if(n===sc)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR:r.COMPRESSED_RGBA_ASTC_6x5_KHR;if(n===rc)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR:r.COMPRESSED_RGBA_ASTC_6x6_KHR;if(n===ac)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR:r.COMPRESSED_RGBA_ASTC_8x5_KHR;if(n===oc)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR:r.COMPRESSED_RGBA_ASTC_8x6_KHR;if(n===lc)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR:r.COMPRESSED_RGBA_ASTC_8x8_KHR;if(n===cc)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR:r.COMPRESSED_RGBA_ASTC_10x5_KHR;if(n===hc)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR:r.COMPRESSED_RGBA_ASTC_10x6_KHR;if(n===uc)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR:r.COMPRESSED_RGBA_ASTC_10x8_KHR;if(n===dc)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR:r.COMPRESSED_RGBA_ASTC_10x10_KHR;if(n===fc)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR:r.COMPRESSED_RGBA_ASTC_12x10_KHR;if(n===pc)return a===Oe?r.COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR:r.COMPRESSED_RGBA_ASTC_12x12_KHR}else return null;if(n===mc||n===gc||n===xc)if(r=t.get("EXT_texture_compression_bptc"),r!==null){if(n===mc)return a===Oe?r.COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT:r.COMPRESSED_RGBA_BPTC_UNORM_EXT;if(n===gc)return r.COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT;if(n===xc)return r.COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT}else return null;if(n===_c||n===vc||n===so||n===yc)if(r=t.get("EXT_texture_compression_rgtc"),r!==null){if(n===_c)return r.COMPRESSED_RED_RGTC1_EXT;if(n===vc)return r.COMPRESSED_SIGNED_RED_RGTC1_EXT;if(n===so)return r.COMPRESSED_RED_GREEN_RGTC2_EXT;if(n===yc)return r.COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT}else return null;return n===Ir?i.UNSIGNED_INT_24_8:i[n]!==void 0?i[n]:null}return{convert:e}}var h3=`
void main() {

	gl_Position = vec4( position, 1.0 );

}`,u3=`
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

}`,Th=class{constructor(){this.texture=null,this.mesh=null,this.depthNear=0,this.depthFar=0}init(t,e){if(this.texture===null){let n=new va(t.texture);(t.depthNear!==e.depthNear||t.depthFar!==e.depthFar)&&(this.depthNear=t.depthNear,this.depthFar=t.depthFar),this.texture=n}}getMesh(t){if(this.texture!==null&&this.mesh===null){let e=t.cameras[0].viewport,n=new Ge({vertexShader:h3,fragmentShader:u3,uniforms:{depthColor:{value:this.texture},depthWidth:{value:e.z},depthHeight:{value:e.w}}});this.mesh=new we(new ls(20,20),n)}return this.mesh}reset(){this.texture=null,this.mesh=null}getDepthTexture(){return this.texture}},Ah=class extends Si{constructor(t,e){super();let n=this,s=null,r=1,a=null,o="local-floor",c=1,l=null,h=null,f=null,u=null,d=null,m=null,x=typeof XRWebGLBinding<"u",g=new Th,p={},b=e.getContextAttributes(),E=null,y=null,w=[],S=[],C=new yt,v=null,R=null,I=new Tn;I.viewport=new je;let N=new Tn;N.viewport=new je;let L=[I,N],O=new Ul,P=null,W=null;this.cameraAutoUpdate=!0,this.enabled=!1,this.isPresenting=!1,this.getController=function(et){let nt=w[et];return nt===void 0&&(nt=new fr,w[et]=nt),nt.getTargetRaySpace()},this.getControllerGrip=function(et){let nt=w[et];return nt===void 0&&(nt=new fr,w[et]=nt),nt.getGripSpace()},this.getHand=function(et){let nt=w[et];return nt===void 0&&(nt=new fr,w[et]=nt),nt.getHandSpace()};function it(et){let nt=S.indexOf(et.inputSource);if(nt===-1)return;let _t=w[nt];_t!==void 0&&(_t.update(et.inputSource,et.frame,l||a),_t.dispatchEvent({type:et.type,data:et.inputSource}))}function Q(){s.removeEventListener("select",it),s.removeEventListener("selectstart",it),s.removeEventListener("selectend",it),s.removeEventListener("squeeze",it),s.removeEventListener("squeezestart",it),s.removeEventListener("squeezeend",it),s.removeEventListener("end",Q),s.removeEventListener("inputsourceschange",ht);for(let et=0;et<w.length;et++){let nt=S[et];nt!==null&&(S[et]=null,w[et].disconnect(nt))}P=null,W=null,g.reset();for(let et in p)delete p[et];if(t.setRenderTarget(E),d=null,u=null,f=null,s=null,y=null,Lt.stop(),n.isPresenting=!1,t.setPixelRatio(v),t.setSize(C.width,C.height,!1),R!==null){let et=R.camera;et.fov=R.fov,et.zoom=R.zoom,et.updateProjectionMatrix(),R=null}n.dispatchEvent({type:"sessionend"})}this.setFramebufferScaleFactor=function(et){r=et,n.isPresenting===!0&&pe("WebXRManager: Cannot change framebuffer scale while presenting.")},this.setReferenceSpaceType=function(et){o=et,n.isPresenting===!0&&pe("WebXRManager: Cannot change reference space type while presenting.")},this.getReferenceSpace=function(){return l||a},this.setReferenceSpace=function(et){l=et},this.getBaseLayer=function(){return u!==null?u:d},this.getBinding=function(){return f===null&&x&&(f=new XRWebGLBinding(s,e)),f},this.getFrame=function(){return m},this.getSession=function(){return s},this.setSession=async function(et){if(s=et,s!==null){if(E=t.getRenderTarget(),s.addEventListener("select",it),s.addEventListener("selectstart",it),s.addEventListener("selectend",it),s.addEventListener("squeeze",it),s.addEventListener("squeezestart",it),s.addEventListener("squeezeend",it),s.addEventListener("end",Q),s.addEventListener("inputsourceschange",ht),b.xrCompatible!==!0&&await e.makeXRCompatible(),v=t.getPixelRatio(),t.getSize(C),x&&"createProjectionLayer"in XRWebGLBinding.prototype){let _t=null,wt=null,pt=null;b.depth&&(pt=b.stencil?e.DEPTH24_STENCIL8:e.DEPTH_COMPONENT24,_t=b.stencil?gs:bi,wt=b.stencil?Ir:pi);let It={colorFormat:e.RGBA8,depthFormat:pt,scaleFactor:r};f=this.getBinding(),u=f.createProjectionLayer(It),s.updateRenderState({layers:[u]}),t.setPixelRatio(1),t.setSize(u.textureWidth,u.textureHeight,!1),y=new sn(u.textureWidth,u.textureHeight,{format:ei,type:kn,depthTexture:new os(u.textureWidth,u.textureHeight,wt,void 0,void 0,void 0,void 0,void 0,void 0,_t),stencilBuffer:b.stencil,colorSpace:t.outputColorSpace,samples:b.antialias?4:0,resolveDepthBuffer:u.ignoreDepthValues===!1,resolveStencilBuffer:u.ignoreDepthValues===!1,storeMultisampledDepthBuffer:u.ignoreDepthValues===!1,storeMultisampledStencilBuffer:u.ignoreDepthValues===!1})}else{let _t={antialias:b.antialias,alpha:!0,depth:b.depth,stencil:b.stencil,framebufferScaleFactor:r};d=new XRWebGLLayer(s,e,_t),s.updateRenderState({baseLayer:d}),t.setPixelRatio(1),t.setSize(d.framebufferWidth,d.framebufferHeight,!1),y=new sn(d.framebufferWidth,d.framebufferHeight,{format:ei,type:kn,colorSpace:t.outputColorSpace,stencilBuffer:b.stencil,resolveDepthBuffer:d.ignoreDepthValues===!1,resolveStencilBuffer:d.ignoreDepthValues===!1,storeMultisampledDepthBuffer:d.ignoreDepthValues===!1,storeMultisampledStencilBuffer:d.ignoreDepthValues===!1})}y.isXRRenderTarget=!0,this.setFoveation(c),l=null,a=await s.requestReferenceSpace(o),Lt.setContext(s),Lt.start(),n.isPresenting=!0,n.dispatchEvent({type:"sessionstart"})}},this.getEnvironmentBlendMode=function(){if(s!==null)return s.environmentBlendMode},this.getDepthTexture=function(){return g.getDepthTexture()};function ht(et){for(let nt=0;nt<et.removed.length;nt++){let _t=et.removed[nt],wt=S.indexOf(_t);wt>=0&&(S[wt]=null,w[wt].disconnect(_t))}for(let nt=0;nt<et.added.length;nt++){let _t=et.added[nt],wt=S.indexOf(_t);if(wt===-1){for(let It=0;It<w.length;It++)if(It>=S.length){S.push(_t),wt=It;break}else if(S[It]===null){S[It]=_t,wt=It;break}if(wt===-1)break}let pt=w[wt];pt&&pt.connect(_t)}}let K=new D,ot=new D;function z(et,nt,_t){K.setFromMatrixPosition(nt.matrixWorld),ot.setFromMatrixPosition(_t.matrixWorld);let wt=K.distanceTo(ot),pt=nt.projectionMatrix.elements,It=_t.projectionMatrix.elements,ee=pt[14]/(pt[10]-1),V=pt[14]/(pt[10]+1),lt=(pt[9]+1)/pt[5],ct=(pt[9]-1)/pt[5],gt=(pt[8]-1)/pt[0],bt=(It[8]+1)/It[0],Bt=ee*gt,Ut=ee*bt,Kt=wt/(-gt+bt),se=Kt*-gt;if(nt.matrixWorld.decompose(et.position,et.quaternion,et.scale),et.translateX(se),et.translateZ(Kt),et.matrixWorld.compose(et.position,et.quaternion,et.scale),et.matrixWorldInverse.copy(et.matrixWorld).invert(),pt[10]===-1)et.projectionMatrix.copy(nt.projectionMatrix),et.projectionMatrixInverse.copy(nt.projectionMatrixInverse);else{let F=ee+Kt,re=V+Kt,ae=Bt-se,T=Ut+(wt-se),_=lt*V/re*F,G=ct*V/re*F;et.projectionMatrix.makePerspective(ae,T,_,G,F,re),et.projectionMatrixInverse.copy(et.projectionMatrix).invert()}}function Mt(et,nt){nt===null?et.matrixWorld.copy(et.matrix):et.matrixWorld.multiplyMatrices(nt.matrixWorld,et.matrix),et.matrixWorldInverse.copy(et.matrixWorld).invert()}this.updateCamera=function(et){if(s===null)return;let nt=et.near,_t=et.far;g.texture!==null&&(g.depthNear>0&&(nt=g.depthNear),g.depthFar>0&&(_t=g.depthFar)),O.near=N.near=I.near=nt,O.far=N.far=I.far=_t,(P!==O.near||W!==O.far)&&(s.updateRenderState({depthNear:O.near,depthFar:O.far}),P=O.near,W=O.far),O.layers.mask=et.layers.mask|6,I.layers.mask=O.layers.mask&-5,N.layers.mask=O.layers.mask&-3;let wt=et.parent,pt=O.cameras;Mt(O,wt);for(let It=0;It<pt.length;It++)Mt(pt[It],wt);pt.length===2?z(O,I,N):O.projectionMatrix.copy(I.projectionMatrix),R===null&&et.isPerspectiveCamera&&(R={camera:et,fov:et.fov,zoom:et.zoom}),vt(et,O,wt)};function vt(et,nt,_t){_t===null?et.matrix.copy(nt.matrixWorld):(et.matrix.copy(_t.matrixWorld),et.matrix.invert(),et.matrix.multiply(nt.matrixWorld)),et.matrix.decompose(et.position,et.quaternion,et.scale),et.updateMatrixWorld(!0),et.projectionMatrix.copy(nt.projectionMatrix),et.projectionMatrixInverse.copy(nt.projectionMatrixInverse),et.isPerspectiveCamera&&(et.fov=cl*2*Math.atan(1/et.projectionMatrix.elements[5]),et.zoom=1)}this.getCamera=function(){return O},this.getFoveation=function(){if(!(u===null&&d===null))return c},this.setFoveation=function(et){c=et,u!==null&&(u.fixedFoveation=et),d!==null&&d.fixedFoveation!==void 0&&(d.fixedFoveation=et)},this.hasDepthSensing=function(){return g.texture!==null},this.getDepthSensingMesh=function(){return g.getMesh(O)},this.getCameraTexture=function(et){return p[et]};let Et=null;function Ot(et,nt){if(h=nt.getViewerPose(l||a),m=nt,h!==null){let _t=h.views;d!==null&&(t.setRenderTargetFramebuffer(y,d.framebuffer),t.setRenderTarget(y));let wt=!1;_t.length!==O.cameras.length&&(O.cameras.length=0,wt=!0);for(let V=0;V<_t.length;V++){let lt=_t[V],ct=null;if(d!==null)ct=d.getViewport(lt);else{let bt=f.getViewSubImage(u,lt);ct=bt.viewport,V===0&&(t.setRenderTargetTextures(y,bt.colorTexture,bt.depthStencilTexture),t.setRenderTarget(y))}let gt=L[V];gt===void 0&&(gt=new Tn,gt.layers.enable(V),gt.viewport=new je,L[V]=gt),gt.matrix.fromArray(lt.transform.matrix),gt.matrix.decompose(gt.position,gt.quaternion,gt.scale),gt.projectionMatrix.fromArray(lt.projectionMatrix),gt.projectionMatrixInverse.copy(gt.projectionMatrix).invert(),gt.viewport.set(ct.x,ct.y,ct.width,ct.height),V===0&&(O.matrix.copy(gt.matrix),O.matrix.decompose(O.position,O.quaternion,O.scale)),wt===!0&&O.cameras.push(gt)}let pt=s.enabledFeatures;if(pt&&pt.includes("depth-sensing")&&s.depthUsage=="gpu-optimized"&&x){f=n.getBinding();let V=f.getDepthInformation(_t[0]);V&&V.isValid&&V.texture&&g.init(V,s.renderState)}if(pt&&pt.includes("camera-access")&&x){t.state.unbindTexture(),f=n.getBinding();for(let V=0;V<_t.length;V++){let lt=_t[V].camera;if(lt){let ct=p[lt];ct||(ct=new va,p[lt]=ct);let gt=f.getCameraImage(lt);ct.sourceTexture=gt}}}}for(let _t=0;_t<w.length;_t++){let wt=S[_t],pt=w[_t];wt!==null&&pt!==void 0&&pt.update(wt,nt,l||a)}Et&&Et(et,nt),nt.detectedPlanes&&n.dispatchEvent({type:"planesdetected",data:nt}),m=null}let Lt=new uf;Lt.setAnimationLoop(Ot),this.setAnimationLoop=function(et){Et=et},this.dispose=function(){}}},d3=new De,xf=new ve;xf.set(-1,0,0,0,1,0,0,0,1);function f3(i,t){function e(g,p){g.matrixAutoUpdate===!0&&g.updateMatrix(),p.value.copy(g.matrix)}function n(g,p){p.color.getRGB(g.fogColor.value,ch(i)),p.isFog?(g.fogNear.value=p.near,g.fogFar.value=p.far):p.isFogExp2&&(g.fogDensity.value=p.density)}function s(g,p,b,E,y){p.isNodeMaterial?p.uniformsNeedUpdate=!1:p.isMeshBasicMaterial?r(g,p):p.isMeshLambertMaterial?(r(g,p),p.envMap&&(g.envMapIntensity.value=p.envMapIntensity)):p.isMeshToonMaterial?(r(g,p),f(g,p)):p.isMeshPhongMaterial?(r(g,p),h(g,p),p.envMap&&(g.envMapIntensity.value=p.envMapIntensity)):p.isMeshStandardMaterial?(r(g,p),u(g,p),p.isMeshPhysicalMaterial&&d(g,p,y)):p.isMeshMatcapMaterial?(r(g,p),m(g,p)):p.isMeshDepthMaterial?r(g,p):p.isMeshDistanceMaterial?(r(g,p),x(g,p)):p.isMeshNormalMaterial?r(g,p):p.isLineBasicMaterial?(a(g,p),p.isLineDashedMaterial&&o(g,p)):p.isPointsMaterial?c(g,p,b,E):p.isSpriteMaterial?l(g,p):p.isShadowMaterial?(g.color.value.copy(p.color),g.opacity.value=p.opacity):p.isShaderMaterial&&(p.uniformsNeedUpdate=!1)}function r(g,p){g.opacity.value=p.opacity,p.color&&g.diffuse.value.copy(p.color),p.emissive&&g.emissive.value.copy(p.emissive).multiplyScalar(p.emissiveIntensity),p.map&&(g.map.value=p.map,e(p.map,g.mapTransform)),p.alphaMap&&(g.alphaMap.value=p.alphaMap,e(p.alphaMap,g.alphaMapTransform)),p.bumpMap&&(g.bumpMap.value=p.bumpMap,e(p.bumpMap,g.bumpMapTransform),g.bumpScale.value=p.bumpScale,p.side===Rn&&(g.bumpScale.value*=-1)),p.normalMap&&(g.normalMap.value=p.normalMap,e(p.normalMap,g.normalMapTransform),g.normalScale.value.copy(p.normalScale),p.side===Rn&&g.normalScale.value.negate()),p.displacementMap&&(g.displacementMap.value=p.displacementMap,e(p.displacementMap,g.displacementMapTransform),g.displacementScale.value=p.displacementScale,g.displacementBias.value=p.displacementBias),p.emissiveMap&&(g.emissiveMap.value=p.emissiveMap,e(p.emissiveMap,g.emissiveMapTransform)),p.specularMap&&(g.specularMap.value=p.specularMap,e(p.specularMap,g.specularMapTransform)),p.alphaTest>0&&(g.alphaTest.value=p.alphaTest);let b=t.get(p),E=b.envMap,y=b.envMapRotation;E&&(g.envMap.value=E,g.envMapRotation.value.setFromMatrix4(d3.makeRotationFromEuler(y)).transpose(),E.isCubeTexture&&E.isRenderTargetTexture===!1&&g.envMapRotation.value.premultiply(xf),g.reflectivity.value=p.reflectivity,g.ior.value=p.ior,g.refractionRatio.value=p.refractionRatio),p.lightMap&&(g.lightMap.value=p.lightMap,g.lightMapIntensity.value=p.lightMapIntensity,e(p.lightMap,g.lightMapTransform)),p.aoMap&&(g.aoMap.value=p.aoMap,g.aoMapIntensity.value=p.aoMapIntensity,e(p.aoMap,g.aoMapTransform))}function a(g,p){g.diffuse.value.copy(p.color),g.opacity.value=p.opacity,p.map&&(g.map.value=p.map,e(p.map,g.mapTransform))}function o(g,p){g.dashSize.value=p.dashSize,g.totalSize.value=p.dashSize+p.gapSize,g.scale.value=p.scale}function c(g,p,b,E){g.diffuse.value.copy(p.color),g.opacity.value=p.opacity,g.size.value=p.size*b,g.scale.value=E*.5,p.map&&(g.map.value=p.map,e(p.map,g.uvTransform)),p.alphaMap&&(g.alphaMap.value=p.alphaMap,e(p.alphaMap,g.alphaMapTransform)),p.alphaTest>0&&(g.alphaTest.value=p.alphaTest)}function l(g,p){g.diffuse.value.copy(p.color),g.opacity.value=p.opacity,g.rotation.value=p.rotation,p.map&&(g.map.value=p.map,e(p.map,g.mapTransform)),p.alphaMap&&(g.alphaMap.value=p.alphaMap,e(p.alphaMap,g.alphaMapTransform)),p.alphaTest>0&&(g.alphaTest.value=p.alphaTest)}function h(g,p){g.specular.value.copy(p.specular),g.shininess.value=Math.max(p.shininess,1e-4)}function f(g,p){p.gradientMap&&(g.gradientMap.value=p.gradientMap)}function u(g,p){g.metalness.value=p.metalness,p.metalnessMap&&(g.metalnessMap.value=p.metalnessMap,e(p.metalnessMap,g.metalnessMapTransform)),g.roughness.value=p.roughness,p.roughnessMap&&(g.roughnessMap.value=p.roughnessMap,e(p.roughnessMap,g.roughnessMapTransform)),p.envMap&&(g.envMapIntensity.value=p.envMapIntensity)}function d(g,p,b){g.ior.value=p.ior,p.sheen>0&&(g.sheenColor.value.copy(p.sheenColor).multiplyScalar(p.sheen),g.sheenRoughness.value=p.sheenRoughness,p.sheenColorMap&&(g.sheenColorMap.value=p.sheenColorMap,e(p.sheenColorMap,g.sheenColorMapTransform)),p.sheenRoughnessMap&&(g.sheenRoughnessMap.value=p.sheenRoughnessMap,e(p.sheenRoughnessMap,g.sheenRoughnessMapTransform))),p.clearcoat>0&&(g.clearcoat.value=p.clearcoat,g.clearcoatRoughness.value=p.clearcoatRoughness,p.clearcoatMap&&(g.clearcoatMap.value=p.clearcoatMap,e(p.clearcoatMap,g.clearcoatMapTransform)),p.clearcoatRoughnessMap&&(g.clearcoatRoughnessMap.value=p.clearcoatRoughnessMap,e(p.clearcoatRoughnessMap,g.clearcoatRoughnessMapTransform)),p.clearcoatNormalMap&&(g.clearcoatNormalMap.value=p.clearcoatNormalMap,e(p.clearcoatNormalMap,g.clearcoatNormalMapTransform),g.clearcoatNormalScale.value.copy(p.clearcoatNormalScale),p.side===Rn&&g.clearcoatNormalScale.value.negate())),p.dispersion>0&&(g.dispersion.value=p.dispersion),p.retroreflectivity>0&&(g.retroreflectivity.value=p.retroreflectivity),p.iridescence>0&&(g.iridescence.value=p.iridescence,g.iridescenceIOR.value=p.iridescenceIOR,g.iridescenceThicknessMinimum.value=p.iridescenceThicknessRange[0],g.iridescenceThicknessMaximum.value=p.iridescenceThicknessRange[1],p.iridescenceMap&&(g.iridescenceMap.value=p.iridescenceMap,e(p.iridescenceMap,g.iridescenceMapTransform)),p.iridescenceThicknessMap&&(g.iridescenceThicknessMap.value=p.iridescenceThicknessMap,e(p.iridescenceThicknessMap,g.iridescenceThicknessMapTransform))),p.transmission>0&&(g.transmission.value=p.transmission,g.transmissionSamplerMap.value=b.texture,g.transmissionSamplerSize.value.set(b.width,b.height),p.transmissionMap&&(g.transmissionMap.value=p.transmissionMap,e(p.transmissionMap,g.transmissionMapTransform)),g.thickness.value=p.thickness,p.thicknessMap&&(g.thicknessMap.value=p.thicknessMap,e(p.thicknessMap,g.thicknessMapTransform)),g.attenuationDistance.value=p.attenuationDistance,g.attenuationColor.value.copy(p.attenuationColor)),p.anisotropy>0&&(g.anisotropyVector.value.set(p.anisotropy*Math.cos(p.anisotropyRotation),p.anisotropy*Math.sin(p.anisotropyRotation)),p.anisotropyMap&&(g.anisotropyMap.value=p.anisotropyMap,e(p.anisotropyMap,g.anisotropyMapTransform))),g.specularIntensity.value=p.specularIntensity,g.specularColor.value.copy(p.specularColor),p.specularColorMap&&(g.specularColorMap.value=p.specularColorMap,e(p.specularColorMap,g.specularColorMapTransform)),p.specularIntensityMap&&(g.specularIntensityMap.value=p.specularIntensityMap,e(p.specularIntensityMap,g.specularIntensityMapTransform))}function m(g,p){p.matcap&&(g.matcap.value=p.matcap)}function x(g,p){let b=t.get(p).light;g.referencePosition.value.setFromMatrixPosition(b.matrixWorld),g.nearDistance.value=b.shadow.camera.near,g.farDistance.value=b.shadow.camera.far}return{refreshFogUniforms:n,refreshMaterialUniforms:s}}function p3(i,t,e,n){let s={},r={},a=[],o=i.getParameter(i.MAX_UNIFORM_BUFFER_BINDINGS);function c(y,w){let S=w.program;n.uniformBlockBinding(y,S)}function l(y,w){let S=s[y.id];S===void 0&&(g(y),S=h(y),s[y.id]=S,y.addEventListener("dispose",b));let C=w.program;n.updateUBOMapping(y,C);let v=t.render.frame;r[y.id]!==v&&(u(y),r[y.id]=v)}function h(y){let w=f();y.__bindingPointIndex=w;let S=i.createBuffer(),C=y.__size,v=y.usage;return i.bindBuffer(i.UNIFORM_BUFFER,S),i.bufferData(i.UNIFORM_BUFFER,C,v),i.bindBuffer(i.UNIFORM_BUFFER,null),i.bindBufferBase(i.UNIFORM_BUFFER,w,S),S}function f(){for(let y=0;y<o;y++)if(a.indexOf(y)===-1)return a.push(y),y;return fe("WebGLRenderer: Maximum number of simultaneously usable uniforms groups reached."),0}function u(y){let w=s[y.id],S=y.uniforms,C=y.__cache;i.bindBuffer(i.UNIFORM_BUFFER,w);for(let v=0,R=S.length;v<R;v++){let I=S[v];if(Array.isArray(I))for(let N=0,L=I.length;N<L;N++)d(I[N],v,N,C);else d(I,v,0,C)}i.bindBuffer(i.UNIFORM_BUFFER,null)}function d(y,w,S,C){if(x(y,w,S,C)===!0){let v=y.__offset,R=y.value;if(Array.isArray(R)){let I=0;for(let N=0;N<R.length;N++){let L=R[N],O=p(L);m(L,y.__data,I),typeof L!="number"&&typeof L!="boolean"&&!L.isMatrix3&&!ArrayBuffer.isView(L)&&(I+=O.storage/Float32Array.BYTES_PER_ELEMENT)}}else m(R,y.__data,0);i.bufferSubData(i.UNIFORM_BUFFER,v,y.__data)}}function m(y,w,S){typeof y=="number"||typeof y=="boolean"?w[0]=y:y.isMatrix3?(w[0]=y.elements[0],w[1]=y.elements[1],w[2]=y.elements[2],w[3]=0,w[4]=y.elements[3],w[5]=y.elements[4],w[6]=y.elements[5],w[7]=0,w[8]=y.elements[6],w[9]=y.elements[7],w[10]=y.elements[8],w[11]=0):ArrayBuffer.isView(y)?w.set(new y.constructor(y.buffer,y.byteOffset,w.length)):y.toArray(w,S)}function x(y,w,S,C){let v=y.value,R=w+"_"+S;if(C[R]===void 0)return typeof v=="number"||typeof v=="boolean"?C[R]=v:ArrayBuffer.isView(v)?C[R]=v.slice():C[R]=v.clone(),!0;{let I=C[R];if(typeof v=="number"||typeof v=="boolean"){if(I!==v)return C[R]=v,!0}else{if(ArrayBuffer.isView(v))return!0;if(I.equals(v)===!1)return I.copy(v),!0}}return!1}function g(y){let w=y.uniforms,S=0,C=16;for(let R=0,I=w.length;R<I;R++){let N=Array.isArray(w[R])?w[R]:[w[R]];for(let L=0,O=N.length;L<O;L++){let P=N[L],W=Array.isArray(P.value)?P.value:[P.value];for(let it=0,Q=W.length;it<Q;it++){let ht=W[it],K=p(ht),ot=S%C,z=ot%K.boundary,Mt=ot+z;S+=z,Mt!==0&&C-Mt<K.storage&&(S+=C-Mt),P.__data=new Float32Array(K.storage/Float32Array.BYTES_PER_ELEMENT),P.__offset=S,S+=K.storage}}}let v=S%C;return v>0&&(S+=C-v),y.__size=S,y.__cache={},this}function p(y){let w={boundary:0,storage:0};return typeof y=="number"||typeof y=="boolean"?(w.boundary=4,w.storage=4):y.isVector2?(w.boundary=8,w.storage=8):y.isVector3||y.isColor?(w.boundary=16,w.storage=12):y.isVector4?(w.boundary=16,w.storage=16):y.isMatrix3?(w.boundary=48,w.storage=48):y.isMatrix4?(w.boundary=64,w.storage=64):y.isTexture?pe("WebGLRenderer: Texture samplers can not be part of an uniforms group."):ArrayBuffer.isView(y)?(w.boundary=16,w.storage=y.byteLength):pe("WebGLRenderer: Unsupported uniform value type.",y),w}function b(y){let w=y.target;w.removeEventListener("dispose",b);let S=a.indexOf(w.__bindingPointIndex);a.splice(S,1),i.deleteBuffer(s[w.id]),delete s[w.id],delete r[w.id]}function E(){for(let y in s)i.deleteBuffer(s[y]);a=[],s={},r={}}return{bind:c,update:l,dispose:E}}var m3=new Uint16Array([12469,15057,12620,14925,13266,14620,13807,14376,14323,13990,14545,13625,14713,13328,14840,12882,14931,12528,14996,12233,15039,11829,15066,11525,15080,11295,15085,10976,15082,10705,15073,10495,13880,14564,13898,14542,13977,14430,14158,14124,14393,13732,14556,13410,14702,12996,14814,12596,14891,12291,14937,11834,14957,11489,14958,11194,14943,10803,14921,10506,14893,10278,14858,9960,14484,14039,14487,14025,14499,13941,14524,13740,14574,13468,14654,13106,14743,12678,14818,12344,14867,11893,14889,11509,14893,11180,14881,10751,14852,10428,14812,10128,14765,9754,14712,9466,14764,13480,14764,13475,14766,13440,14766,13347,14769,13070,14786,12713,14816,12387,14844,11957,14860,11549,14868,11215,14855,10751,14825,10403,14782,10044,14729,9651,14666,9352,14599,9029,14967,12835,14966,12831,14963,12804,14954,12723,14936,12564,14917,12347,14900,11958,14886,11569,14878,11247,14859,10765,14828,10401,14784,10011,14727,9600,14660,9289,14586,8893,14508,8533,15111,12234,15110,12234,15104,12216,15092,12156,15067,12010,15028,11776,14981,11500,14942,11205,14902,10752,14861,10393,14812,9991,14752,9570,14682,9252,14603,8808,14519,8445,14431,8145,15209,11449,15208,11451,15202,11451,15190,11438,15163,11384,15117,11274,15055,10979,14994,10648,14932,10343,14871,9936,14803,9532,14729,9218,14645,8742,14556,8381,14461,8020,14365,7603,15273,10603,15272,10607,15267,10619,15256,10631,15231,10614,15182,10535,15118,10389,15042,10167,14963,9787,14883,9447,14800,9115,14710,8665,14615,8318,14514,7911,14411,7507,14279,7198,15314,9675,15313,9683,15309,9712,15298,9759,15277,9797,15229,9773,15166,9668,15084,9487,14995,9274,14898,8910,14800,8539,14697,8234,14590,7790,14479,7409,14367,7067,14178,6621,15337,8619,15337,8631,15333,8677,15325,8769,15305,8871,15264,8940,15202,8909,15119,8775,15022,8565,14916,8328,14804,8009,14688,7614,14569,7287,14448,6888,14321,6483,14088,6171,15350,7402,15350,7419,15347,7480,15340,7613,15322,7804,15287,7973,15229,8057,15148,8012,15046,7846,14933,7611,14810,7357,14682,7069,14552,6656,14421,6316,14251,5948,14007,5528,15356,5942,15356,5977,15353,6119,15348,6294,15332,6551,15302,6824,15249,7044,15171,7122,15070,7050,14949,6861,14818,6611,14679,6349,14538,6067,14398,5651,14189,5311,13935,4958,15359,4123,15359,4153,15356,4296,15353,4646,15338,5160,15311,5508,15263,5829,15188,6042,15088,6094,14966,6001,14826,5796,14678,5543,14527,5287,14377,4985,14133,4586,13869,4257,15360,1563,15360,1642,15358,2076,15354,2636,15341,3350,15317,4019,15273,4429,15203,4732,15105,4911,14981,4932,14836,4818,14679,4621,14517,4386,14359,4156,14083,3795,13808,3437,15360,122,15360,137,15358,285,15355,636,15344,1274,15322,2177,15281,2765,15215,3223,15120,3451,14995,3569,14846,3567,14681,3466,14511,3305,14344,3121,14037,2800,13753,2467,15360,0,15360,1,15359,21,15355,89,15346,253,15325,479,15287,796,15225,1148,15133,1492,15008,1749,14856,1882,14685,1886,14506,1783,14324,1608,13996,1398,13702,1183]),Ai=null;function g3(){return Ai===null&&(Ai=new ma(m3,16,16,xs,mn),Ai.name="DFG_LUT",Ai.minFilter=An,Ai.magFilter=An,Ai.wrapS=yi,Ai.wrapT=yi,Ai.generateMipmaps=!1,Ai.needsUpdate=!0),Ai}var Rc=class{constructor(t={}){let{canvas:e=Pd(),context:n=null,depth:s=!0,stencil:r=!1,alpha:a=!1,antialias:o=!1,premultipliedAlpha:c=!0,preserveDrawingBuffer:l=!1,powerPreference:h="default",failIfMajorPerformanceCaveat:f=!1,reversedDepthBuffer:u=!1,outputBufferType:d=kn}=t;this.isWebGLRenderer=!0;let m;if(n!==null){if(typeof WebGLRenderingContext<"u"&&n instanceof WebGLRenderingContext)throw new Error("THREE.WebGLRenderer: WebGL 1 is not supported since r163.");m=n.getContextAttributes().alpha}else m=a;let x=d,g=new Set([Wl,Gl,Vl]),p=new Set([kn,pi,Cr,Ir,zl,kl]),b=new Uint32Array(4),E=new Int32Array(4),y=new D,w=null,S=null,C=[],v=[],R=null;this.domElement=e,this.debug={checkShaderErrors:!0,diagnostics:{keywords:!1},onShaderError:null},this.autoClear=!0,this.autoClearColor=!0,this.autoClearDepth=!0,this.autoClearStencil=!0,this.sortObjects=!0,this.clippingPlanes=[],this.localClippingEnabled=!1,this.toneMapping=fi,this.toneMappingExposure=1,this.transmissionResolutionScale=1;let I=this,N=!1,L=null,O=null,P=null,W=null;this._outputColorSpace=tn;let it=0,Q=0,ht=null,K=-1,ot=null,z=new je,Mt=new je,vt=null,Et=new oe(0),Ot=0,Lt=e.width,et=e.height,nt=1,_t=null,wt=null,pt=new je(0,0,Lt,et),It=new je(0,0,Lt,et),ee=!1,V=new gr,lt=!1,ct=!1,gt=new De,bt=new D,Bt=new je,Ut={background:null,fog:null,environment:null,overrideMaterial:null,isScene:!0},Kt=!1;function se(){return ht===null?nt:1}let F=n;function re(M,H){return e.getContext(M,H)}let ae,T,_,G,q,rt,St,Rt,tt,ft,At,Ht,Nt,Tt,Gt,Jt,he,B,Ft,mt,Dt,kt,ut;try{let M={alpha:!0,depth:s,stencil:r,antialias:o,premultipliedAlpha:c,preserveDrawingBuffer:l,powerPreference:h,failIfMajorPerformanceCaveat:f};if("setAttribute"in e&&e.setAttribute("data-engine",`three.js r${"186"}`),e.addEventListener("webglcontextlost",Be,!1),e.addEventListener("webglcontextrestored",U,!1),e.addEventListener("webglcontextcreationerror",xt,!1),F===null){let H="webgl2";if(F=re(H,M),F===null)throw re(H)?new Error("THREE.WebGLRenderer: Error creating WebGL context with your selected attributes."):new Error("THREE.WebGLRenderer: Error creating WebGL context.")}ie()}catch(M){throw e.removeEventListener("webglcontextlost",Be,!1),e.removeEventListener("webglcontextrestored",U,!1),e.removeEventListener("webglcontextcreationerror",xt,!1),fe("WebGLRenderer: "+M.message),M}function ie(){ae=new S2(F),ae.init(),Dt=new c3(F,ae),T=new f2(F,ae,t,Dt),_=new o3(F,ae),T.reversedDepthBuffer&&u&&_.buffers.depth.setReversed(!0),O=F.createFramebuffer(),P=F.createFramebuffer(),W=F.createFramebuffer(),G=new T2(F),q=new qx,rt=new l3(F,ae,_,q,T,Dt,G),St=new b2(I),Rt=new R1(F),kt=new u2(F,Rt),tt=new w2(F,Rt,G,kt),ft=new R2(F,tt,Rt,kt,G),B=new A2(F,T,rt),Gt=new p2(q),At=new $x(I,St,ae,T,kt,Gt),Ht=new f3(I,q),Nt=new Zx,Tt=new e3(ae),he=new h2(I,St,_,ft,m,c),Jt=new a3(I,ft,T),ut=new p3(F,G,T,_),Ft=new d2(F,ae,G),mt=new E2(F,ae,G),G.programs=At.programs,I.capabilities=T,I.extensions=ae,I.properties=q,I.renderLists=Nt,I.shadowMap=Jt,I.state=_,I.info=G}x!==kn&&(R=new I2(x,e.width,e.height,o,s,r));let jt=new Ah(I,F);this.xr=jt,this.getContext=function(){return F},this.getContextAttributes=function(){return F.getContextAttributes()},this.forceContextLoss=function(){let M=ae.get("WEBGL_lose_context");M&&M.loseContext()},this.forceContextRestore=function(){let M=ae.get("WEBGL_lose_context");M&&M.restoreContext()},this.getPixelRatio=function(){return nt},this.setPixelRatio=function(M){M!==void 0&&(nt=M,this.setSize(Lt,et,!1))},this.getSize=function(M){return M.set(Lt,et)},this.setSize=function(M,H,Y=!0){if(jt.isPresenting){pe("WebGLRenderer: Can't change size while VR device is presenting.");return}Lt=M,et=H,e.width=Math.floor(M*nt),e.height=Math.floor(H*nt),Y===!0&&(e.style.width=M+"px",e.style.height=H+"px"),R!==null&&R.setSize(e.width,e.height),this.setViewport(0,0,M,H)},this.getDrawingBufferSize=function(M){return M.set(Lt*nt,et*nt).floor()},this.setDrawingBufferSize=function(M,H,Y){Lt=M,et=H,nt=Y,e.width=Math.floor(M*Y),e.height=Math.floor(H*Y),this.setViewport(0,0,M,H)},this.setEffects=function(M){if(x===kn){fe("WebGLRenderer: setEffects() requires outputBufferType set to HalfFloatType or FloatType.");return}if(M){for(let H=0;H<M.length;H++)if(M[H].isOutputPass===!0){pe("WebGLRenderer: OutputPass is not needed in setEffects(). Tone mapping and color space conversion are applied automatically.");break}}R.setEffects(M||[])},this.getCurrentViewport=function(M){return M.copy(z)},this.getViewport=function(M){return M.copy(pt)},this.setViewport=function(M,H,Y,Z){M.isVector4?pt.set(M.x,M.y,M.z,M.w):pt.set(M,H,Y,Z),_.viewport(z.copy(pt).multiplyScalar(nt).round())},this.getScissor=function(M){return M.copy(It)},this.setScissor=function(M,H,Y,Z){M.isVector4?It.set(M.x,M.y,M.z,M.w):It.set(M,H,Y,Z),_.scissor(Mt.copy(It).multiplyScalar(nt).round())},this.getScissorTest=function(){return ee},this.setScissorTest=function(M){_.setScissorTest(ee=M)},this.setOpaqueSort=function(M){_t=M},this.setTransparentSort=function(M){wt=M},this.getClearColor=function(M){return M.copy(he.getClearColor())},this.setClearColor=function(){he.setClearColor(...arguments)},this.getClearAlpha=function(){return he.getClearAlpha()},this.setClearAlpha=function(){he.setClearAlpha(...arguments)},this.clear=function(M=!0,H=!0,Y=!0){let Z=0;if(M){let J=!1;if(ht!==null){let Vt=ht.texture.format;J=g.has(Vt)}if(J){let Vt=ht.texture.type,qt=p.has(Vt),Pt=he.getClearColor(),Qt=he.getClearAlpha(),Yt=Pt.r,_e=Pt.g,Ee=Pt.b;qt?(b[0]=Yt,b[1]=_e,b[2]=Ee,b[3]=Qt,F.clearBufferuiv(F.COLOR,0,b)):(E[0]=Yt,E[1]=_e,E[2]=Ee,E[3]=Qt,F.clearBufferiv(F.COLOR,0,E))}else Z|=F.COLOR_BUFFER_BIT}H&&(Z|=F.DEPTH_BUFFER_BIT,this.state.buffers.depth.setMask(!0)),Y&&(Z|=F.STENCIL_BUFFER_BIT,this.state.buffers.stencil.setMask(4294967295)),Z!==0&&F.clear(Z)},this.clearColor=function(){this.clear(!0,!1,!1)},this.clearDepth=function(){this.clear(!1,!0,!1)},this.clearStencil=function(){this.clear(!1,!1,!0)},this.setNodesHandler=function(M){M.setRenderer(this),L=M},this.dispose=function(){e.removeEventListener("webglcontextlost",Be,!1),e.removeEventListener("webglcontextrestored",U,!1),e.removeEventListener("webglcontextcreationerror",xt,!1),he.dispose(),Nt.dispose(),Tt.dispose(),q.dispose(),St.dispose(),ft.dispose(),kt.dispose(),ut.dispose(),At.dispose(),jt.dispose(),jt.removeEventListener("sessionstart",me),jt.removeEventListener("sessionend",an),Fn.stop()};function Be(M){M.preventDefault(),la("WebGLRenderer: Context Lost."),N=!0}function U(){la("WebGLRenderer: Context Restored."),N=!1;let M=G.autoReset,H=Jt.enabled,Y=Jt.autoUpdate,Z=Jt.needsUpdate,J=Jt.type;ie(),G.autoReset=M,Jt.enabled=H,Jt.autoUpdate=Y,Jt.needsUpdate=Z,Jt.type=J}function xt(M){fe("WebGLRenderer: A WebGL context could not be created. Reason: ",M.statusMessage)}function zt(M){let H=M.target;H.removeEventListener("dispose",zt),$t(H)}function $t(M){xe(M),q.remove(M)}function xe(M){let H=q.get(M).programs;H!==void 0&&(H.forEach(function(Y){At.releaseProgram(Y)}),M.isShaderMaterial&&At.releaseShaderCache(M))}this.renderBufferDirect=function(M,H,Y,Z,J,Vt){H===null&&(H=Ut);let qt=J.isMesh&&J.matrixWorld.determinantAffine()<0,Pt=Kc(M,H,Y,Z,J);_.setMaterial(Z,qt);let Qt=Y.index,Yt=1;if(Z.wireframe===!0){if(Qt=tt.getWireframeAttribute(Y),Qt===void 0)return;Yt=2}let _e=Y.drawRange,Ee=Y.attributes.position,te=_e.start*Yt,Me=(_e.start+_e.count)*Yt;Vt!==null&&(te=Math.max(te,Vt.start*Yt),Me=Math.min(Me,(Vt.start+Vt.count)*Yt)),Qt!==null?(te=Math.max(te,0),Me=Math.min(Me,Qt.count)):Ee!=null&&(te=Math.max(te,0),Me=Math.min(Me,Ee.count));let Ue=Me-te;if(Ue<0||Ue===1/0)return;kt.setup(J,Z,Pt,Y,Qt);let $e,ze=Ft;if(Qt!==null&&($e=Rt.get(Qt),ze=mt,ze.setIndex($e)),J.isMesh)Z.wireframe===!0?(_.setLineWidth(Z.wireframeLinewidth*se()),ze.setMode(F.LINES)):ze.setMode(F.TRIANGLES);else if(J.isLine){let un=Z.linewidth;un===void 0&&(un=1),_.setLineWidth(un*se()),J.isLineSegments?ze.setMode(F.LINES):J.isLineLoop?ze.setMode(F.LINE_LOOP):ze.setMode(F.LINE_STRIP)}else J.isPoints?ze.setMode(F.POINTS):J.isSprite&&ze.setMode(F.TRIANGLES);if(J.isBatchedMesh)if(ae.get("WEBGL_multi_draw"))ze.renderMultiDraw(J._multiDrawStarts,J._multiDrawCounts,J._multiDrawCount);else{let un=J._multiDrawStarts,Zt=J._multiDrawCounts,_n=J._multiDrawCount,Ce=Qt?Rt.get(Qt).bytesPerElement:1,On=q.get(Z).currentProgram.getUniforms();for(let Hn=0;Hn<_n;Hn++)On.setValue(F,"_gl_DrawID",Hn),ze.render(un[Hn]/Ce,Zt[Hn])}else if(J.isInstancedMesh)ze.renderInstances(te,Ue,J.count);else if(Y.isInstancedBufferGeometry){let un=Y._maxInstanceCount!==void 0?Y._maxInstanceCount:1/0,Zt=Math.min(Y.instanceCount,un);ze.renderInstances(te,Ue,Zt)}else ze.render(te,Ue)};function be(M,H,Y,Z){L!==null&&M.isNodeMaterial&&L.setObject(Z,M),lt===!0&&Gt.setState(M,Y,!1),M.transparent===!0&&M.side===Cn&&M.forceSinglePass===!1?(M.side=Rn,M.needsUpdate=!0,Ds(M,H,Z),M.side=fs,M.needsUpdate=!0,Ds(M,H,Z),M.side=Cn):Ds(M,H,Z)}this.compile=function(M,H,Y=null){Y===null&&(Y=M),L!==null&&L.renderStart(M,H,Y),S=Tt.get(Y),S.init(H),v.push(S),Y.traverseVisible(function(J){J.isLight&&J.layers.test(H.layers)&&(S.pushLight(J),J.castShadow&&S.pushShadow(J))}),M!==Y&&M.traverseVisible(function(J){J.isLight&&J.layers.test(H.layers)&&(S.pushLight(J),J.castShadow&&S.pushShadow(J))}),S.setupLights(),L!==null&&L.updateLights(S.state.lightsArray),ct=this.localClippingEnabled,lt=Gt.init(this.clippingPlanes,ct),lt===!0&&Gt.setGlobalState(this.clippingPlanes,H),L!==null&&Jt.render(S.state.shadowsArray,Y,H);let Z=new Set;return M.traverse(function(J){if(!(J.isMesh||J.isPoints||J.isLine||J.isSprite))return;let Vt=J.material;if(Vt)if(Array.isArray(Vt))for(let qt=0;qt<Vt.length;qt++){let Pt=Vt[qt];be(Pt,Y,H,J),Z.add(Pt)}else be(Vt,Y,H,J),Z.add(Vt)}),S=v.pop(),L!==null&&L.renderEnd(),Z},this.compileAsync=function(M,H,Y=null){let Z=this.compile(M,H,Y);return new Promise(J=>{function Vt(){if(Z.forEach(function(qt){let Qt=q.get(qt).currentProgram;(Qt===void 0||Qt.isReady())&&Z.delete(qt)}),Z.size===0){J(M);return}setTimeout(Vt,10)}ae.get("KHR_parallel_shader_compile")!==null?Vt():setTimeout(Vt,10)})};let Ke=null;function ye(M){Ke&&Ke(M)}function me(){Fn.stop()}function an(){Fn.start()}let Fn=new uf;Fn.setAnimationLoop(ye),typeof self<"u"&&Fn.setContext(self),this.setAnimationLoop=function(M){Ke=M,jt.setAnimationLoop(M),M===null?Fn.stop():Fn.start()},jt.addEventListener("sessionstart",me),jt.addEventListener("sessionend",an),this.render=function(M,H){if(H!==void 0&&H.isCamera!==!0){fe("WebGLRenderer.render: camera is not an instance of THREE.Camera.");return}if(N===!0)return;L!==null&&L.renderStart(M,H);let Y=jt.enabled===!0&&jt.isPresenting===!0,Z=R!==null&&(ht===null||Y)&&R.begin(I,ht);if(M.matrixWorldAutoUpdate===!0&&M.updateMatrixWorld(),H.parent===null&&H.matrixWorldAutoUpdate===!0&&H.updateMatrixWorld(),jt.enabled===!0&&jt.isPresenting===!0&&(R===null||R.isCompositing()===!1)&&(jt.cameraAutoUpdate===!0&&jt.updateCamera(H),H=jt.getCamera()),M.isScene===!0&&M.onBeforeRender(I,M,H,ht),S=Tt.get(M,v.length),S.init(H),S.state.textureUnits=rt.getTextureUnits(),v.push(S),gt.multiplyMatrices(H.projectionMatrix,H.matrixWorldInverse),V.setFromProjectionMatrix(gt,hi,H.reversedDepth),ct=this.localClippingEnabled,lt=Gt.init(this.clippingPlanes,ct),w=Nt.get(M,C.length),w.init(),C.push(w),jt.enabled===!0&&jt.isPresenting===!0){let qt=I.xr.getDepthSensingMesh();qt!==null&&ue(qt,H,-1/0,I.sortObjects)}ue(M,H,0,I.sortObjects),w.finish(),L!==null&&L.updateLights(S.state.lightsArray),I.sortObjects===!0&&w.sort(_t,wt),Kt=jt.enabled===!1||jt.isPresenting===!1||jt.hasDepthSensing()===!1,Kt&&he.addToRenderList(w,M),this.info.render.frame++,this.info.autoReset===!0&&this.info.reset(),lt===!0&&Gt.beginShadows();let J=S.state.shadowsArray;if(Jt.render(J,M,H),lt===!0&&Gt.endShadows(),(Z&&R.hasRenderPass())===!1){let qt=w.opaque,Pt=w.transmissive;if(S.setupLights(),H.isArrayCamera){let Qt=H.cameras;if(Pt.length>0)for(let Yt=0,_e=Qt.length;Yt<_e;Yt++){let Ee=Qt[Yt];Zi(qt,Pt,M,Ee)}Kt&&he.render(M);for(let Yt=0,_e=Qt.length;Yt<_e;Yt++){let Ee=Qt[Yt];Ci(w,M,Ee,Ee.viewport)}}else Pt.length>0&&Zi(qt,Pt,M,H),Kt&&he.render(M),Ci(w,M,H)}ht!==null&&Q===0&&(rt.updateMultisampleRenderTarget(ht),rt.updateRenderTargetMipmap(ht)),Z&&R.end(I),M.isScene===!0&&M.onAfterRender(I,M,H),kt.resetDefaultState(),K=-1,ot=null,v.pop(),v.length>0?(S=v[v.length-1],rt.setTextureUnits(S.state.textureUnits),lt===!0&&Gt.setGlobalState(I.clippingPlanes,S.state.camera)):S=null,C.pop(),C.length>0?w=C[C.length-1]:w=null,L!==null&&L.renderEnd()};function ue(M,H,Y,Z){if(M.visible===!1)return;if(M.layers.test(H.layers)){if(M.isGroup)Y=M.renderOrder;else if(M.isLOD)M.autoUpdate===!0&&M.update(H);else if(M.isLightProbeGrid)S.pushLightProbeGrid(M);else if(M.isLight)S.pushLight(M),M.castShadow&&S.pushShadow(M);else if(M.isSprite){if(!M.frustumCulled||M.intersectsFrustum(V)){Z&&Bt.setFromMatrixPosition(M.matrixWorld).applyMatrix4(gt);let qt=ft.update(M),Pt=M.material;Pt.visible&&w.push(M,qt,Pt,Y,Bt.z,null,H)}}else if((M.isMesh||M.isLine||M.isPoints)&&(!M.frustumCulled||M.intersectsFrustum(V))){let qt=ft.update(M),Pt=M.material;if(Z&&(M.boundingSphere!==void 0?(M.boundingSphere===null&&M.computeBoundingSphere(),Bt.copy(M.boundingSphere.center)):(qt.boundingSphere===null&&qt.computeBoundingSphere(),Bt.copy(qt.boundingSphere.center)),Bt.applyMatrix4(M.matrixWorld).applyMatrix4(gt)),Array.isArray(Pt)){let Qt=qt.groups;for(let Yt=0,_e=Qt.length;Yt<_e;Yt++){let Ee=Qt[Yt],te=Pt[Ee.materialIndex];te&&te.visible&&w.push(M,qt,te,Y,Bt.z,Ee,H)}}else Pt.visible&&w.push(M,qt,Pt,Y,Bt.z,null,H)}}let Vt=M.children;for(let qt=0,Pt=Vt.length;qt<Pt;qt++)ue(Vt[qt],H,Y,Z)}function Ci(M,H,Y,Z){let{opaque:J,transmissive:Vt,transparent:qt}=M;S.setupLightsView(Y),lt===!0&&Gt.setGlobalState(I.clippingPlanes,Y),Z&&_.viewport(z.copy(Z)),J.length>0&&wn(J,H,Y),Vt.length>0&&wn(Vt,H,Y),qt.length>0&&wn(qt,H,Y),_.buffers.depth.setTest(!0),_.buffers.depth.setMask(!0),_.buffers.color.setMask(!0),_.setPolygonOffset(!1)}function Zi(M,H,Y,Z){if((Y.isScene===!0?Y.overrideMaterial:null)!==null)return;if(S.state.transmissionRenderTarget[Z.id]===void 0){let te=ae.has("EXT_color_buffer_half_float")||ae.has("EXT_color_buffer_float");S.state.transmissionRenderTarget[Z.id]=new sn(1,1,{generateMipmaps:!0,type:te?mn:kn,minFilter:Ti,samples:Math.max(4,T.samples),stencilBuffer:r,resolveDepthBuffer:!1,resolveStencilBuffer:!1,storeMultisampledDepthBuffer:!1,storeMultisampledStencilBuffer:!1,colorSpace:Re.workingColorSpace})}let Vt=S.state.transmissionRenderTarget[Z.id],qt=Z.viewport||z;Vt.setSize(qt.z*I.transmissionResolutionScale,qt.w*I.transmissionResolutionScale);let Pt=I.getRenderTarget(),Qt=I.getActiveCubeFace(),Yt=I.getActiveMipmapLevel();I.setRenderTarget(Vt),I.getClearColor(Et),Ot=I.getClearAlpha(),Ot<1&&I.setClearColor(16777215,.5),I.clear(),Kt&&he.render(Y);let _e=I.toneMapping;I.toneMapping=fi;let Ee=Z.viewport;if(Z.viewport!==void 0&&(Z.viewport=void 0),S.setupLightsView(Z),lt===!0&&Gt.setGlobalState(I.clippingPlanes,Z),wn(M,Y,Z),rt.updateMultisampleRenderTarget(Vt),rt.updateRenderTargetMipmap(Vt),ae.has("WEBGL_multisampled_render_to_texture")===!1){let te=!1;for(let Me=0,Ue=H.length;Me<Ue;Me++){let $e=H[Me],{object:ze,geometry:un,material:Zt,group:_n}=$e;if(Zt.side===Cn&&ze.layers.test(Z.layers)){let Ce=Zt.side;Zt.side=Rn,Zt.needsUpdate=!0,vs(ze,Y,Z,un,Zt,_n),Zt.side=Ce,Zt.needsUpdate=!0,te=!0}}te===!0&&(rt.updateMultisampleRenderTarget(Vt),rt.updateRenderTargetMipmap(Vt))}I.setRenderTarget(Pt,Qt,Yt),I.setClearColor(Et,Ot),Ee!==void 0&&(Z.viewport=Ee),I.toneMapping=_e}function wn(M,H,Y){let Z=H.isScene===!0?H.overrideMaterial:null;for(let J=0,Vt=M.length;J<Vt;J++){let qt=M[J],{object:Pt,geometry:Qt,group:Yt}=qt,_e=qt.material;_e.allowOverride===!0&&Z!==null&&(_e=Z),Pt.layers.test(Y.layers)&&vs(Pt,H,Y,Qt,_e,Yt)}}function vs(M,H,Y,Z,J,Vt){L!==null&&J.isNodeMaterial&&L.setObject(M,J),M.onBeforeRender(I,H,Y,Z,J,Vt),M.modelViewMatrix.multiplyMatrices(Y.matrixWorldInverse,M.matrixWorld),M.normalMatrix.getNormalMatrix(M.modelViewMatrix),J.onBeforeRender(I,H,Y,Z,M,Vt),J.transparent===!0&&J.side===Cn&&J.forceSinglePass===!1?(J.side=Rn,J.needsUpdate=!0,I.renderBufferDirect(Y,H,Z,J,M,Vt),J.side=fs,J.needsUpdate=!0,I.renderBufferDirect(Y,H,Z,J,M,Vt),J.side=Cn):I.renderBufferDirect(Y,H,Z,J,M,Vt),M.onAfterRender(I,H,Y,Z,J,Vt)}function Ds(M,H,Y){H.isScene!==!0&&(H=Ut);let Z=q.get(M),J=S.state.lights,Vt=S.state.shadowsArray,qt=J.state.version,Pt=At.getParameters(M,J.state,Vt,H,Y,S.state.lightProbeGridArray),Qt=At.getProgramCacheKey(Pt),Yt=Z.programs;Z.environment=M.isMeshStandardMaterial||M.isMeshLambertMaterial||M.isMeshPhongMaterial?H.environment:null,Z.fog=H.fog;let _e=M.isMeshStandardMaterial||M.isMeshLambertMaterial&&!M.envMap||M.isMeshPhongMaterial&&!M.envMap;Z.envMap=St.get(M.envMap||Z.environment,_e),Z.envMapRotation=Z.environment!==null&&M.envMap===null?H.environmentRotation:M.envMapRotation,Yt===void 0&&(M.addEventListener("dispose",zt),Yt=new Map,Z.programs=Yt);let Ee=Yt.get(Qt);if(Ee!==void 0){if(Z.currentProgram===Ee&&Z.lightsStateVersion===qt)return go(M,Pt),Ee}else Pt.uniforms=At.getUniforms(M),L!==null&&M.isNodeMaterial&&L.build(M,Y,Pt),M.onBeforeCompile(Pt,I),Ee=At.acquireProgram(Pt,Qt),Yt.set(Qt,Ee),Z.uniforms=Pt.uniforms;let te=Z.uniforms;return(!M.isShaderMaterial&&!M.isRawShaderMaterial||M.clipping===!0)&&(te.clippingPlanes=Gt.uniform),go(M,Pt),Z.needsLights=jc(M),Z.lightsStateVersion=qt,Z.needsLights&&(te.ambientLightColor.value=J.state.ambient,te.lightProbe.value=J.state.probe,te.sunLights.value=J.state.sun,te.sunLightShadows.value=J.state.sunShadow,te.directionalLights.value=J.state.directional,te.directionalLightShadows.value=J.state.directionalShadow,te.spotLights.value=J.state.spot,te.spotLightShadows.value=J.state.spotShadow,te.rectAreaLights.value=J.state.rectArea,te.ltc_1.value=J.state.rectAreaLTC1,te.ltc_2.value=J.state.rectAreaLTC2,te.pointLights.value=J.state.point,te.pointLightShadows.value=J.state.pointShadow,te.hemisphereLights.value=J.state.hemi,te.sunShadowMatrix.value=J.state.sunShadowMatrix,te.sunShadowCascade.value=J.state.sunShadowCascade,te.directionalShadowMatrix.value=J.state.directionalShadowMatrix,te.spotLightMatrix.value=J.state.spotLightMatrix,te.spotLightMap.value=J.state.spotLightMap,te.pointShadowMatrix.value=J.state.pointShadowMatrix),Z.lightProbeGrid=S.state.lightProbeGridArray.length>0,Z.currentProgram=Ee,Z.uniformsList=null,Ee}function mo(M){if(M.uniformsList===null){let H=M.currentProgram.getUniforms();M.uniformsList=Nr.seqWithValue(H.seq,M.uniforms)}return M.uniformsList}function go(M,H){let Y=q.get(M);Y.outputColorSpace=H.outputColorSpace,Y.batching=H.batching,Y.batchingColor=H.batchingColor,Y.instancing=H.instancing,Y.instancingColor=H.instancingColor,Y.instancingMorph=H.instancingMorph,Y.skinning=H.skinning,Y.morphTargets=H.morphTargets,Y.morphNormals=H.morphNormals,Y.morphColors=H.morphColors,Y.morphTargetsCount=H.morphTargetsCount,Y.numClippingPlanes=H.numClippingPlanes,Y.numIntersection=H.numClipIntersection,Y.vertexAlphas=H.vertexAlphas,Y.vertexTangents=H.vertexTangents,Y.toneMapping=H.toneMapping}function Jc(M,H){if(M.length===0)return null;if(M.length===1)return M[0].texture!==null?M[0]:null;y.setFromMatrixPosition(H.matrixWorld);for(let Y=0,Z=M.length;Y<Z;Y++){let J=M[Y];if(J.texture!==null&&J.boundingBox.containsPoint(y))return J}return null}function Kc(M,H,Y,Z,J){H.isScene!==!0&&(H=Ut),rt.resetTextureUnits();let Vt=H.fog,qt=Z.isMeshStandardMaterial||Z.isMeshLambertMaterial||Z.isMeshPhongMaterial?H.environment:null,Pt=ht===null?I.outputColorSpace:ht.isXRRenderTarget===!0?ht.texture.colorSpace:Re.workingColorSpace,Qt=Z.isMeshStandardMaterial||Z.isMeshLambertMaterial&&!Z.envMap||Z.isMeshPhongMaterial&&!Z.envMap,Yt=St.get(Z.envMap||qt,Qt),_e=Z.vertexColors===!0&&!!Y.attributes.color&&Y.attributes.color.itemSize===4,Ee=!!Y.attributes.tangent&&(!!Z.normalMap||Z.anisotropy>0),te=!!Y.morphAttributes.position,Me=!!Y.morphAttributes.normal,Ue=!!Y.morphAttributes.color,$e=fi;Z.toneMapped&&(ht===null||ht.isXRRenderTarget===!0)&&($e=I.toneMapping);let ze=Y.morphAttributes.position||Y.morphAttributes.normal||Y.morphAttributes.color,un=ze!==void 0?ze.length:0,Zt=q.get(Z),_n=S.state.lights;if(lt===!0&&(ct===!0||M!==ot)){let qe=M===ot&&Z.id===K;Gt.setState(Z,M,qe)}let Ce=!1;Z.version===Zt.__version?(Zt.needsLights&&Zt.lightsStateVersion!==_n.state.version||Zt.outputColorSpace!==Pt||J.isBatchedMesh&&Zt.batching===!1||!J.isBatchedMesh&&Zt.batching===!0||J.isBatchedMesh&&Zt.batchingColor===!0&&J._colorsTexture===null||J.isBatchedMesh&&Zt.batchingColor===!1&&J._colorsTexture!==null||J.isInstancedMesh&&Zt.instancing===!1||!J.isInstancedMesh&&Zt.instancing===!0||J.isSkinnedMesh&&Zt.skinning===!1||!J.isSkinnedMesh&&Zt.skinning===!0||J.isInstancedMesh&&Zt.instancingColor===!0&&J.instanceColor===null||J.isInstancedMesh&&Zt.instancingColor===!1&&J.instanceColor!==null||J.isInstancedMesh&&Zt.instancingMorph===!0&&J.morphTexture===null||J.isInstancedMesh&&Zt.instancingMorph===!1&&J.morphTexture!==null||Zt.envMap!==Yt||Z.fog===!0&&Zt.fog!==Vt||Zt.numClippingPlanes!==void 0&&(Zt.numClippingPlanes!==Gt.numPlanes||Zt.numIntersection!==Gt.numIntersection)||Zt.vertexAlphas!==_e||Zt.vertexTangents!==Ee||Zt.morphTargets!==te||Zt.morphNormals!==Me||Zt.morphColors!==Ue||Zt.toneMapping!==$e||Zt.morphTargetsCount!==un||!!Zt.lightProbeGrid!=S.state.lightProbeGridArray.length>0)&&(Ce=!0):(Ce=!0,Zt.__version=Z.version);let On=Zt.currentProgram;Ce===!0&&(On=Ds(Z,H,J),L&&Z.isNodeMaterial&&L.onUpdateProgram(Z,On,Zt));let Hn=!1,ii=!1,Ii=!1,Fe=On.getUniforms(),Ne=Zt.uniforms;if(_.useProgram(On.program)&&(Hn=!0,ii=!0,Ii=!0),Z.id!==K&&(K=Z.id,ii=!0),Zt.needsLights){let qe=Jc(S.state.lightProbeGridArray,J);Zt.lightProbeGrid!==qe&&(Zt.lightProbeGrid=qe,ii=!0)}if(Hn||ot!==M){_.buffers.depth.getReversed()&&M.reversedDepth!==!0&&(M._reversedDepth=!0,M.updateProjectionMatrix()),Fe.setValue(F,"projectionMatrix",M.projectionMatrix),Fe.setValue(F,"viewMatrix",M.matrixWorldInverse);let xi=Fe.map.cameraPosition;xi!==void 0&&xi.setValue(F,bt.setFromMatrixPosition(M.matrixWorld)),T.logarithmicDepthBuffer&&Fe.setValue(F,"logDepthBufFC",2/(Math.log(M.far+1)/Math.LN2)),(Z.isMeshPhongMaterial||Z.isMeshToonMaterial||Z.isMeshLambertMaterial||Z.isMeshBasicMaterial||Z.isMeshStandardMaterial||Z.isShaderMaterial)&&Fe.setValue(F,"isOrthographic",M.isOrthographicCamera===!0),ot!==M&&(ot=M,ii=!0,Ii=!0)}if(Zt.needsLights&&(_n.state.sunShadowMap.length>0&&Fe.setValue(F,"sunShadowMap",_n.state.sunShadowMap,rt),_n.state.directionalShadowMap.length>0&&Fe.setValue(F,"directionalShadowMap",_n.state.directionalShadowMap,rt),_n.state.spotShadowMap.length>0&&Fe.setValue(F,"spotShadowMap",_n.state.spotShadowMap,rt),_n.state.pointShadowMap.length>0&&Fe.setValue(F,"pointShadowMap",_n.state.pointShadowMap,rt)),J.isSkinnedMesh){Fe.setOptional(F,J,"bindMatrix"),Fe.setOptional(F,J,"bindMatrixInverse");let qe=J.skeleton;qe&&(qe.boneTexture===null&&qe.computeBoneTexture(),Fe.setValue(F,"boneTexture",qe.boneTexture,rt))}J.isBatchedMesh&&(Fe.setOptional(F,J,"batchingTexture"),Fe.setValue(F,"batchingTexture",J._matricesTexture,rt),Fe.setOptional(F,J,"batchingIdTexture"),Fe.setValue(F,"batchingIdTexture",J._indirectTexture,rt),Fe.setOptional(F,J,"batchingColorTexture"),J._colorsTexture!==null&&Fe.setValue(F,"batchingColorTexture",J._colorsTexture,rt));let si=Y.morphAttributes;if((si.position!==void 0||si.normal!==void 0||si.color!==void 0)&&B.update(J,Y,On),(ii||Zt.receiveShadow!==J.receiveShadow)&&(Zt.receiveShadow=J.receiveShadow,Fe.setValue(F,"receiveShadow",J.receiveShadow)),(Z.isMeshStandardMaterial||Z.isMeshLambertMaterial||Z.isMeshPhongMaterial)&&Z.envMap===null&&H.environment!==null&&(Ne.envMapIntensity.value=H.environmentIntensity),Ne.dfgLUT!==void 0&&(Ne.dfgLUT.value=g3()),ii){if(Fe.setValue(F,"toneMappingExposure",I.toneMappingExposure),Zt.needsLights&&Us(Ne,Ii),Vt&&Z.fog===!0&&Ht.refreshFogUniforms(Ne,Vt),Ht.refreshMaterialUniforms(Ne,Z,nt,et,S.state.transmissionRenderTarget[M.id]),Zt.needsLights&&Zt.lightProbeGrid){let qe=Zt.lightProbeGrid;Ne.probesSH.value=qe.texture,Ne.probesMin.value.copy(qe.boundingBox.min),Ne.probesMax.value.copy(qe.boundingBox.max),Ne.probesResolution.value.copy(qe.resolution)}Nr.upload(F,mo(Zt),Ne,rt)}if(Z.isShaderMaterial&&Z.uniformsNeedUpdate===!0&&(Nr.upload(F,mo(Zt),Ne,rt),Z.uniformsNeedUpdate=!1),Z.isSpriteMaterial&&Fe.setValue(F,"center",J.center),Fe.setValue(F,"modelViewMatrix",J.modelViewMatrix),Fe.setValue(F,"normalMatrix",J.normalMatrix),Fe.setValue(F,"modelMatrix",J.matrixWorld),Z.uniformsGroups!==void 0){let qe=Z.uniformsGroups;for(let xi=0,Ji=qe.length;xi<Ji;xi++){let rn=qe[xi];ut.update(rn,On),ut.bind(rn,On)}}return On}function Us(M,H){M.ambientLightColor.needsUpdate=H,M.lightProbe.needsUpdate=H,M.sunLights.needsUpdate=H,M.sunLightShadows.needsUpdate=H,M.directionalLights.needsUpdate=H,M.directionalLightShadows.needsUpdate=H,M.pointLights.needsUpdate=H,M.pointLightShadows.needsUpdate=H,M.spotLights.needsUpdate=H,M.spotLightShadows.needsUpdate=H,M.rectAreaLights.needsUpdate=H,M.hemisphereLights.needsUpdate=H}function jc(M){return M.isMeshLambertMaterial||M.isMeshToonMaterial||M.isMeshPhongMaterial||M.isMeshStandardMaterial||M.isShadowMaterial||M.isShaderMaterial&&M.lights===!0}this.getActiveCubeFace=function(){return it},this.getActiveMipmapLevel=function(){return Q},this.getRenderTarget=function(){return ht},this.setRenderTargetTextures=function(M,H,Y){let Z=q.get(M);Z.__autoAllocateDepthBuffer=M.resolveDepthBuffer===!1,Z.__autoAllocateDepthBuffer===!1&&(Z.__useRenderToTexture=!1),q.get(M.texture).__webglTexture=H,q.get(M.depthTexture).__webglTexture=Z.__autoAllocateDepthBuffer?void 0:Y,Z.__hasExternalTextures=!0},this.setRenderTargetFramebuffer=function(M,H){let Y=q.get(M);Y.__webglFramebuffer=H,Y.__useDefaultFramebuffer=H===void 0},this.setRenderTarget=function(M,H=0,Y=0){ht=M,it=H,Q=Y;let Z=null,J=!1,Vt=!1;if(M){let Pt=q.get(M);if(Pt.__useDefaultFramebuffer!==void 0){_.bindFramebuffer(F.FRAMEBUFFER,Pt.__webglFramebuffer),z.copy(M.viewport),Mt.copy(M.scissor),vt=M.scissorTest,_.viewport(z),_.scissor(Mt),_.setScissorTest(vt),K=-1;return}else if(Pt.__webglFramebuffer===void 0)rt.setupRenderTarget(M);else if(Pt.__hasExternalTextures)rt.rebindTextures(M,q.get(M.texture).__webglTexture,q.get(M.depthTexture).__webglTexture);else if(M.depthBuffer){let _e=M.depthTexture;if(Pt.__boundDepthTexture!==_e){if(_e!==null&&q.has(_e)&&(M.width!==_e.image.width||M.height!==_e.image.height))throw new Error("THREE.WebGLRenderer: Attached DepthTexture is initialized to the incorrect size.");rt.setupDepthRenderbuffer(M)}}let Qt=M.texture;(Qt.isData3DTexture||Qt.isDataArrayTexture||Qt.isCompressedArrayTexture)&&(Vt=!0);let Yt=q.get(M).__webglFramebuffer;M.isWebGLCubeRenderTarget?(Array.isArray(Yt[H])?Z=Yt[H][Y]:Z=Yt[H],J=!0):M.samples>0&&rt.useMultisampledRTT(M)===!1?Z=q.get(M).__webglMultisampledFramebuffer:Array.isArray(Yt)?Z=Yt[Y]:Z=Yt,z.copy(M.viewport),Mt.copy(M.scissor),vt=M.scissorTest}else z.copy(pt).multiplyScalar(nt).floor(),Mt.copy(It).multiplyScalar(nt).floor(),vt=ee;if(Y!==0&&(Z=O),_.bindFramebuffer(F.FRAMEBUFFER,Z)&&_.drawBuffers(M,Z),_.viewport(z),_.scissor(Mt),_.setScissorTest(vt),J){let Pt=q.get(M.texture);F.framebufferTexture2D(F.FRAMEBUFFER,F.COLOR_ATTACHMENT0,F.TEXTURE_CUBE_MAP_POSITIVE_X+H,Pt.__webglTexture,Y)}else if(Vt){let Pt=H;for(let Qt=0;Qt<M.textures.length;Qt++){let Yt=q.get(M.textures[Qt]);F.framebufferTextureLayer(F.FRAMEBUFFER,F.COLOR_ATTACHMENT0+Qt,Yt.__webglTexture,Y,Pt)}}else if(M!==null&&Y!==0){let Pt=q.get(M.texture);F.framebufferTexture2D(F.FRAMEBUFFER,F.COLOR_ATTACHMENT0,F.TEXTURE_2D,Pt.__webglTexture,Y)}K=-1};function xo(M){let H=q.get(M);return(H.__readFormat!==M.format||H.__readType!==M.type)&&(H.__readFormat=M.format,H.__readType=M.type,H.__formatReadable=T.textureFormatReadable(M.format),H.__typeReadable=T.textureTypeReadable(M.type)),H}this.readRenderTargetPixels=function(M,H,Y,Z,J,Vt,qt,Pt=0){if(!(M&&M.isWebGLRenderTarget)){fe("WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");return}let Qt=q.get(M).__webglFramebuffer;if(M.isWebGLCubeRenderTarget&&qt!==void 0&&(Qt=Qt[qt]),Qt){_.bindFramebuffer(F.FRAMEBUFFER,Qt);try{let Yt=M.textures[Pt],_e=Yt.format,Ee=Yt.type;M.textures.length>1&&F.readBuffer(F.COLOR_ATTACHMENT0+Pt);let te=xo(Yt);if(te.__formatReadable===!1){fe("WebGLRenderer.readRenderTargetPixels: renderTarget is not in RGBA or implementation defined format.");return}if(te.__typeReadable===!1){fe("WebGLRenderer.readRenderTargetPixels: renderTarget is not in UnsignedByteType or implementation defined type.");return}H>=0&&H<=M.width-Z&&Y>=0&&Y<=M.height-J&&F.readPixels(H,Y,Z,J,Dt.convert(_e),Dt.convert(Ee),Vt)}finally{let Yt=ht!==null?q.get(ht).__webglFramebuffer:null;_.bindFramebuffer(F.FRAMEBUFFER,Yt)}}},this.readRenderTargetPixelsAsync=async function(M,H,Y,Z,J,Vt,qt,Pt=0){if(!(M&&M.isWebGLRenderTarget))throw new Error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");let Qt=q.get(M).__webglFramebuffer;if(M.isWebGLCubeRenderTarget&&qt!==void 0&&(Qt=Qt[qt]),Qt)if(H>=0&&H<=M.width-Z&&Y>=0&&Y<=M.height-J){_.bindFramebuffer(F.FRAMEBUFFER,Qt);let Yt=M.textures[Pt],_e=Yt.format,Ee=Yt.type;M.textures.length>1&&F.readBuffer(F.COLOR_ATTACHMENT0+Pt);let te=xo(Yt);if(te.__formatReadable===!1)throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in RGBA or implementation defined format.");if(te.__typeReadable===!1)throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in UnsignedByteType or implementation defined type.");let Me=F.createBuffer();F.bindBuffer(F.PIXEL_PACK_BUFFER,Me),F.bufferData(F.PIXEL_PACK_BUFFER,Vt.byteLength,F.STREAM_READ),F.readPixels(H,Y,Z,J,Dt.convert(_e),Dt.convert(Ee),0),F.bindBuffer(F.PIXEL_PACK_BUFFER,null);let Ue=ht!==null?q.get(ht).__webglFramebuffer:null;_.bindFramebuffer(F.FRAMEBUFFER,Ue);let $e=F.fenceSync(F.SYNC_GPU_COMMANDS_COMPLETE,0);return F.flush(),await Nd(F,$e,4),F.bindBuffer(F.PIXEL_PACK_BUFFER,Me),F.getBufferSubData(F.PIXEL_PACK_BUFFER,0,Vt),F.bindBuffer(F.PIXEL_PACK_BUFFER,null),F.deleteBuffer(Me),F.deleteSync($e),Vt}else throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: requested read bounds are out of range.")},this.copyFramebufferToTexture=function(M,H=null,Y=0){let Z=Math.pow(2,-Y),J=Math.floor(M.image.width*Z),Vt=Math.floor(M.image.height*Z),qt=H!==null?H.x:0,Pt=H!==null?H.y:0;rt.setTexture2D(M,0),F.copyTexSubImage2D(F.TEXTURE_2D,Y,0,0,qt,Pt,J,Vt),_.unbindTexture()},this.copyTextureToTexture=function(M,H,Y=null,Z=null,J=0,Vt=0){let qt,Pt,Qt,Yt,_e,Ee,te,Me,Ue,$e=M.isCompressedTexture?M.mipmaps[Vt]:M.image;if(Y!==null)qt=Y.max.x-Y.min.x,Pt=Y.max.y-Y.min.y,Qt=Y.isBox3?Y.max.z-Y.min.z:1,Yt=Y.min.x,_e=Y.min.y,Ee=Y.isBox3?Y.min.z:0;else{let Ne=Math.pow(2,-J);qt=Math.floor($e.width*Ne),Pt=Math.floor($e.height*Ne),M.isDataArrayTexture?Qt=$e.depth:M.isData3DTexture?Qt=Math.floor($e.depth*Ne):Qt=1,Yt=0,_e=0,Ee=0}Z!==null?(te=Z.x,Me=Z.y,Ue=Z.z):(te=0,Me=0,Ue=0);let ze=Dt.convert(H.format),un=Dt.convert(H.type),Zt;H.isData3DTexture?(rt.setTexture3D(H,0),Zt=F.TEXTURE_3D):H.isDataArrayTexture||H.isCompressedArrayTexture?(rt.setTexture2DArray(H,0),Zt=F.TEXTURE_2D_ARRAY):(rt.setTexture2D(H,0),Zt=F.TEXTURE_2D),_.activeTexture(F.TEXTURE0),_.pixelStorei(F.UNPACK_FLIP_Y_WEBGL,H.flipY),_.pixelStorei(F.UNPACK_PREMULTIPLY_ALPHA_WEBGL,H.premultiplyAlpha),_.pixelStorei(F.UNPACK_ALIGNMENT,H.unpackAlignment);let _n=_.getParameter(F.UNPACK_ROW_LENGTH),Ce=_.getParameter(F.UNPACK_IMAGE_HEIGHT),On=_.getParameter(F.UNPACK_SKIP_PIXELS),Hn=_.getParameter(F.UNPACK_SKIP_ROWS),ii=_.getParameter(F.UNPACK_SKIP_IMAGES);_.pixelStorei(F.UNPACK_ROW_LENGTH,$e.width),_.pixelStorei(F.UNPACK_IMAGE_HEIGHT,$e.height),_.pixelStorei(F.UNPACK_SKIP_PIXELS,Yt),_.pixelStorei(F.UNPACK_SKIP_ROWS,_e),_.pixelStorei(F.UNPACK_SKIP_IMAGES,Ee);let Ii=M.isDataArrayTexture||M.isData3DTexture,Fe=H.isDataArrayTexture||H.isData3DTexture;if(M.isDepthTexture){let Ne=q.get(M),si=q.get(H),qe=q.get(Ne.__renderTarget),xi=q.get(si.__renderTarget);_.bindFramebuffer(F.READ_FRAMEBUFFER,qe.__webglFramebuffer),_.bindFramebuffer(F.DRAW_FRAMEBUFFER,xi.__webglFramebuffer);for(let Ji=0;Ji<Qt;Ji++)Ii&&(F.framebufferTextureLayer(F.READ_FRAMEBUFFER,F.COLOR_ATTACHMENT0,q.get(M).__webglTexture,J,Ee+Ji),F.framebufferTextureLayer(F.DRAW_FRAMEBUFFER,F.COLOR_ATTACHMENT0,q.get(H).__webglTexture,Vt,Ue+Ji)),F.blitFramebuffer(Yt,_e,qt,Pt,te,Me,qt,Pt,F.DEPTH_BUFFER_BIT,F.NEAREST);_.bindFramebuffer(F.READ_FRAMEBUFFER,null),_.bindFramebuffer(F.DRAW_FRAMEBUFFER,null)}else if(J!==0||M.isRenderTargetTexture||q.has(M)){let Ne=q.get(M),si=q.get(H);_.bindFramebuffer(F.READ_FRAMEBUFFER,P),_.bindFramebuffer(F.DRAW_FRAMEBUFFER,W);for(let qe=0;qe<Qt;qe++)Ii?F.framebufferTextureLayer(F.READ_FRAMEBUFFER,F.COLOR_ATTACHMENT0,Ne.__webglTexture,J,Ee+qe):F.framebufferTexture2D(F.READ_FRAMEBUFFER,F.COLOR_ATTACHMENT0,F.TEXTURE_2D,Ne.__webglTexture,J),Fe?F.framebufferTextureLayer(F.DRAW_FRAMEBUFFER,F.COLOR_ATTACHMENT0,si.__webglTexture,Vt,Ue+qe):F.framebufferTexture2D(F.DRAW_FRAMEBUFFER,F.COLOR_ATTACHMENT0,F.TEXTURE_2D,si.__webglTexture,Vt),J!==0?F.blitFramebuffer(Yt,_e,qt,Pt,te,Me,qt,Pt,F.COLOR_BUFFER_BIT,F.NEAREST):Fe?F.copyTexSubImage3D(Zt,Vt,te,Me,Ue+qe,Yt,_e,qt,Pt):F.copyTexSubImage2D(Zt,Vt,te,Me,Yt,_e,qt,Pt);_.bindFramebuffer(F.READ_FRAMEBUFFER,null),_.bindFramebuffer(F.DRAW_FRAMEBUFFER,null)}else Fe?M.isDataTexture||M.isData3DTexture?F.texSubImage3D(Zt,Vt,te,Me,Ue,qt,Pt,Qt,ze,un,$e.data):H.isCompressedArrayTexture?F.compressedTexSubImage3D(Zt,Vt,te,Me,Ue,qt,Pt,Qt,ze,$e.data):F.texSubImage3D(Zt,Vt,te,Me,Ue,qt,Pt,Qt,ze,un,$e):M.isDataTexture?F.texSubImage2D(F.TEXTURE_2D,Vt,te,Me,qt,Pt,ze,un,$e.data):M.isCompressedTexture?F.compressedTexSubImage2D(F.TEXTURE_2D,Vt,te,Me,$e.width,$e.height,ze,$e.data):F.texSubImage2D(F.TEXTURE_2D,Vt,te,Me,qt,Pt,ze,un,$e);_.pixelStorei(F.UNPACK_ROW_LENGTH,_n),_.pixelStorei(F.UNPACK_IMAGE_HEIGHT,Ce),_.pixelStorei(F.UNPACK_SKIP_PIXELS,On),_.pixelStorei(F.UNPACK_SKIP_ROWS,Hn),_.pixelStorei(F.UNPACK_SKIP_IMAGES,ii),Vt===0&&H.generateMipmaps&&F.generateMipmap(Zt),_.unbindTexture()},this.initRenderTarget=function(M){q.get(M).__webglFramebuffer===void 0&&rt.setupRenderTarget(M)},this.initTexture=function(M){M.isCubeTexture?rt.setTextureCube(M,0):M.isData3DTexture?rt.setTexture3D(M,0):M.isDataArrayTexture||M.isCompressedArrayTexture?rt.setTexture2DArray(M,0):rt.setTexture2D(M,0),_.unbindTexture()},this.resetState=function(){it=0,Q=0,ht=null,_.reset(),kt.reset()},typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}get coordinateSystem(){return hi}get outputColorSpace(){return this._outputColorSpace}set outputColorSpace(t){this._outputColorSpace=t;let e=this.getContext();e.drawingBufferColorSpace=Re._getDrawingBufferColorSpace(t),e.unpackColorSpace=Re._getUnpackColorSpace()}};var Ur={name:"CopyShader",uniforms:{tDiffuse:{value:null},opacity:{value:1}},vertexShader:`

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


		}`};var Yn=class{constructor(){this.isPass=!0,this.enabled=!0,this.needsSwap=!0,this.clear=!1,this.renderToScreen=!1}setSize(){}render(){console.error("THREE.Pass: .render() must be implemented in derived pass.")}dispose(){}},x3=new ds(-1,1,1,-1,0,1),Rh=class extends Le{constructor(){super(),this.setAttribute("position",new ge([-1,3,0,-1,-1,0,3,-1,0],3)),this.setAttribute("uv",new ge([0,2,0,0,2,0],2))}},_3=new Rh,_s=class{constructor(t){this._mesh=new we(_3,t)}dispose(){this._mesh.geometry.dispose()}render(t){t.render(this._mesh,x3)}get material(){return this._mesh.material}set material(t){this._mesh.material=t}};var Pc=class extends Yn{constructor(t,e="tDiffuse"){super(),this.textureID=e,this.uniforms=null,this.material=null,t instanceof Ge?(this.uniforms=t.uniforms,this.material=t):t&&(this.uniforms=Yi.clone(t.uniforms),this.material=new Ge({name:t.name!==void 0?t.name:"unspecified",defines:Object.assign({},t.defines),uniforms:this.uniforms,vertexShader:t.vertexShader,fragmentShader:t.fragmentShader})),this._fsQuad=new _s(this.material)}render(t,e,n){this.uniforms[this.textureID]&&(this.uniforms[this.textureID].value=n.texture),this._fsQuad.material=this.material,this.renderToScreen?(t.setRenderTarget(null),this._fsQuad.render(t)):(t.setRenderTarget(e),this.clear&&t.clear(t.autoClearColor,t.autoClearDepth,t.autoClearStencil),this._fsQuad.render(t))}dispose(){this.material.dispose(),this._fsQuad.dispose()}};var co=class extends Yn{constructor(t,e){super(),this.scene=t,this.camera=e,this.clear=!0,this.needsSwap=!1,this.inverse=!1}render(t,e,n){let s=t.getContext(),r=t.state;r.buffers.color.setMask(!1),r.buffers.depth.setMask(!1),r.buffers.color.setLocked(!0),r.buffers.depth.setLocked(!0);let a,o;this.inverse?(a=0,o=1):(a=1,o=0),r.buffers.stencil.setTest(!0),r.buffers.stencil.setOp(s.REPLACE,s.REPLACE,s.REPLACE),r.buffers.stencil.setFunc(s.ALWAYS,a,4294967295),r.buffers.stencil.setClear(o),r.buffers.stencil.setLocked(!0),t.setRenderTarget(n),this.clear&&t.clear(),t.render(this.scene,this.camera),t.setRenderTarget(e),this.clear&&t.clear(),t.render(this.scene,this.camera),r.buffers.color.setLocked(!1),r.buffers.depth.setLocked(!1),r.buffers.color.setMask(!0),r.buffers.depth.setMask(!0),r.buffers.stencil.setLocked(!1),r.buffers.stencil.setFunc(s.EQUAL,1,4294967295),r.buffers.stencil.setOp(s.KEEP,s.KEEP,s.KEEP),r.buffers.stencil.setLocked(!0)}},Lc=class extends Yn{constructor(){super(),this.needsSwap=!1}render(t){t.state.buffers.stencil.setLocked(!1),t.state.buffers.stencil.setTest(!1)}};var Nc=class{constructor(t,e){if(this.renderer=t,this._pixelRatio=t.getPixelRatio(),e===void 0){let n=t.getSize(new yt);this._width=n.width,this._height=n.height,e=new sn(this._width*this._pixelRatio,this._height*this._pixelRatio,{type:mn}),e.texture.name="EffectComposer.rt1"}else this._width=e.width,this._height=e.height;this.renderTarget1=e,this.renderTarget2=e.clone(),this.renderTarget2.texture.name="EffectComposer.rt2",this.writeBuffer=this.renderTarget1,this.readBuffer=this.renderTarget2,this.renderToScreen=!0,this.passes=[],this.copyPass=new Pc(Ur),this.copyPass.material.blending=Qn,this.timer=new Va}swapBuffers(){let t=this.readBuffer;this.readBuffer=this.writeBuffer,this.writeBuffer=t}addPass(t){this.passes.push(t),t.setSize(this._width*this._pixelRatio,this._height*this._pixelRatio)}insertPass(t,e){this.passes.splice(e,0,t),t.setSize(this._width*this._pixelRatio,this._height*this._pixelRatio)}removePass(t){let e=this.passes.indexOf(t);e!==-1&&this.passes.splice(e,1)}isLastEnabledPass(t){for(let e=t+1;e<this.passes.length;e++)if(this.passes[e].enabled)return!1;return!0}render(t){this.timer.update(),t===void 0&&(t=this.timer.getDelta());let e=this.renderer.getRenderTarget(),n=!1;for(let s=0,r=this.passes.length;s<r;s++){let a=this.passes[s];if(a.enabled!==!1){if(a.renderToScreen=this.renderToScreen&&this.isLastEnabledPass(s),a.render(this.renderer,this.writeBuffer,this.readBuffer,t,n),a.needsSwap){if(n){let o=this.renderer.getContext(),c=this.renderer.state.buffers.stencil;c.setFunc(o.NOTEQUAL,1,4294967295),this.copyPass.render(this.renderer,this.writeBuffer,this.readBuffer,t),c.setFunc(o.EQUAL,1,4294967295)}this.swapBuffers()}co!==void 0&&(a instanceof co?n=!0:a instanceof Lc&&(n=!1))}}this.renderer.setRenderTarget(e)}reset(t){if(t===void 0){let e=this.renderer.getSize(new yt);this._pixelRatio=this.renderer.getPixelRatio(),this._width=e.width,this._height=e.height,t=this.renderTarget1.clone(),t.setSize(this._width*this._pixelRatio,this._height*this._pixelRatio)}this.renderTarget1.dispose(),this.renderTarget2.dispose(),this.renderTarget1=t,this.renderTarget2=t.clone(),this.writeBuffer=this.renderTarget1,this.readBuffer=this.renderTarget2}setSize(t,e){this._width=t,this._height=e;let n=this._width*this._pixelRatio,s=this._height*this._pixelRatio;this.renderTarget1.setSize(n,s),this.renderTarget2.setSize(n,s);for(let r=0;r<this.passes.length;r++)this.passes[r].setSize(n,s)}setPixelRatio(t){this._pixelRatio=t,this.setSize(this._width,this._height)}dispose(){this.renderTarget1.dispose(),this.renderTarget2.dispose(),this.copyPass.dispose()}};var Dc=class extends Yn{constructor(t,e,n=null,s=null,r=null){super(),this.scene=t,this.camera=e,this.overrideMaterial=n,this.clearColor=s,this.clearAlpha=r,this.clear=!0,this.clearDepth=!1,this.needsSwap=!1,this.isRenderPass=!0,this._oldClearColor=new oe}render(t,e,n){let s=t.autoClear;t.autoClear=!1;let r,a;this.overrideMaterial!==null&&(a=this.scene.overrideMaterial,this.scene.overrideMaterial=this.overrideMaterial),this.clearColor!==null&&(t.getClearColor(this._oldClearColor),t.setClearColor(this.clearColor,t.getClearAlpha())),this.clearAlpha!==null&&(r=t.getClearAlpha(),t.setClearAlpha(this.clearAlpha)),this.clearDepth==!0&&t.clearDepth(),t.setRenderTarget(this.renderToScreen?null:n),this.clear===!0&&t.clear(t.autoClearColor,t.autoClearDepth,t.autoClearStencil),t.render(this.scene,this.camera),this.clearColor!==null&&t.setClearColor(this._oldClearColor),this.clearAlpha!==null&&t.setClearAlpha(r),this.overrideMaterial!==null&&(this.scene.overrideMaterial=a),t.autoClear=s}};var _f={name:"LuminosityHighPassShader",uniforms:{tDiffuse:{value:null},luminosityThreshold:{value:1},smoothWidth:{value:1},defaultColor:{value:new oe(0)},defaultOpacity:{value:0}},vertexShader:`

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

		}`};var Fr=class i extends Yn{constructor(t,e=1,n,s){super(),this.strength=e,this.radius=n,this.threshold=s,this.resolution=t!==void 0?new yt(t.x,t.y):new yt(256,256),this.clearColor=new oe(0,0,0),this.needsSwap=!1,this.renderTargetsHorizontal=[],this.renderTargetsVertical=[],this.nMips=5;let r=Math.round(this.resolution.x/2),a=Math.round(this.resolution.y/2);this.renderTargetBright=new sn(r,a,{type:mn,depthBuffer:!1}),this.renderTargetBright.texture.name="UnrealBloomPass.bright",this.renderTargetBright.texture.generateMipmaps=!1;for(let h=0;h<this.nMips;h++){let f=new sn(r,a,{type:mn,depthBuffer:!1});f.texture.name="UnrealBloomPass.h"+h,f.texture.generateMipmaps=!1,this.renderTargetsHorizontal.push(f);let u=new sn(r,a,{type:mn,depthBuffer:!1});u.texture.name="UnrealBloomPass.v"+h,u.texture.generateMipmaps=!1,this.renderTargetsVertical.push(u),r=Math.round(r/2),a=Math.round(a/2)}let o=_f;this.highPassUniforms=Yi.clone(o.uniforms),this.highPassUniforms.luminosityThreshold.value=s,this.highPassUniforms.smoothWidth.value=.01,this.materialHighPassFilter=new Ge({uniforms:this.highPassUniforms,vertexShader:o.vertexShader,fragmentShader:o.fragmentShader}),this.separableBlurMaterials=[];let c=[6,10,14,18,22];r=Math.round(this.resolution.x/2),a=Math.round(this.resolution.y/2);for(let h=0;h<this.nMips;h++)this.separableBlurMaterials.push(this._getSeparableBlurMaterial(c[h])),this.separableBlurMaterials[h].uniforms.invSize.value=new yt(1/r,1/a),r=Math.round(r/2),a=Math.round(a/2);this.compositeMaterial=this._getCompositeMaterial(this.nMips),this.compositeMaterial.uniforms.blurTexture1.value=this.renderTargetsVertical[0].texture,this.compositeMaterial.uniforms.blurTexture2.value=this.renderTargetsVertical[1].texture,this.compositeMaterial.uniforms.blurTexture3.value=this.renderTargetsVertical[2].texture,this.compositeMaterial.uniforms.blurTexture4.value=this.renderTargetsVertical[3].texture,this.compositeMaterial.uniforms.blurTexture5.value=this.renderTargetsVertical[4].texture,this.compositeMaterial.uniforms.bloomStrength.value=e,this.compositeMaterial.uniforms.bloomRadius.value=.1;let l=[1,.8,.6,.4,.2];this.compositeMaterial.uniforms.bloomFactors.value=l,this.bloomTintColors=[new D(1,1,1),new D(1,1,1),new D(1,1,1),new D(1,1,1),new D(1,1,1)],this.compositeMaterial.uniforms.bloomTintColors.value=this.bloomTintColors,this.copyUniforms=Yi.clone(Ur.uniforms),this.blendMaterial=new Ge({uniforms:this.copyUniforms,vertexShader:Ur.vertexShader,fragmentShader:Ur.fragmentShader,premultipliedAlpha:!0,blending:pn,depthTest:!1,depthWrite:!1,transparent:!0}),this._oldClearColor=new oe,this._oldClearAlpha=1,this._basic=new hn,this._fsQuad=new _s(null)}dispose(){for(let t=0;t<this.renderTargetsHorizontal.length;t++)this.renderTargetsHorizontal[t].dispose();for(let t=0;t<this.renderTargetsVertical.length;t++)this.renderTargetsVertical[t].dispose();this.renderTargetBright.dispose();for(let t=0;t<this.separableBlurMaterials.length;t++)this.separableBlurMaterials[t].dispose();this.compositeMaterial.dispose(),this.blendMaterial.dispose(),this._basic.dispose(),this._fsQuad.dispose()}setSize(t,e){let n=Math.round(t/2),s=Math.round(e/2);this.renderTargetBright.setSize(n,s);for(let r=0;r<this.nMips;r++)this.renderTargetsHorizontal[r].setSize(n,s),this.renderTargetsVertical[r].setSize(n,s),this.separableBlurMaterials[r].uniforms.invSize.value=new yt(1/n,1/s),n=Math.round(n/2),s=Math.round(s/2)}render(t,e,n,s,r){t.getClearColor(this._oldClearColor),this._oldClearAlpha=t.getClearAlpha();let a=t.autoClear;t.autoClear=!1,t.setClearColor(this.clearColor,0),r&&t.state.buffers.stencil.setTest(!1),this.renderToScreen&&(this._fsQuad.material=this._basic,this._basic.map=n.texture,t.setRenderTarget(null),t.clear(),this._fsQuad.render(t)),this.highPassUniforms.tDiffuse.value=n.texture,this.highPassUniforms.luminosityThreshold.value=this.threshold,this._fsQuad.material=this.materialHighPassFilter,t.setRenderTarget(this.renderTargetBright),t.clear(),this._fsQuad.render(t);let o=this.renderTargetBright;for(let c=0;c<this.nMips;c++)this._fsQuad.material=this.separableBlurMaterials[c],this.separableBlurMaterials[c].uniforms.colorTexture.value=o.texture,this.separableBlurMaterials[c].uniforms.direction.value=i.BlurDirectionX,t.setRenderTarget(this.renderTargetsHorizontal[c]),t.clear(),this._fsQuad.render(t),this.separableBlurMaterials[c].uniforms.colorTexture.value=this.renderTargetsHorizontal[c].texture,this.separableBlurMaterials[c].uniforms.direction.value=i.BlurDirectionY,t.setRenderTarget(this.renderTargetsVertical[c]),t.clear(),this._fsQuad.render(t),o=this.renderTargetsVertical[c];this._fsQuad.material=this.compositeMaterial,this.compositeMaterial.uniforms.bloomStrength.value=this.strength,this.compositeMaterial.uniforms.bloomRadius.value=this.radius,this.compositeMaterial.uniforms.bloomTintColors.value=this.bloomTintColors,t.setRenderTarget(this.renderTargetsHorizontal[0]),t.clear(),this._fsQuad.render(t),this._fsQuad.material=this.blendMaterial,this.copyUniforms.tDiffuse.value=this.renderTargetsHorizontal[0].texture,r&&t.state.buffers.stencil.setTest(!0),this.renderToScreen?(t.setRenderTarget(null),this._fsQuad.render(t)):(t.setRenderTarget(n),this._fsQuad.render(t)),t.setClearColor(this._oldClearColor,this._oldClearAlpha),t.autoClear=a}_getSeparableBlurMaterial(t){let e=[],n=t/3;for(let a=0;a<t;a++)e.push(.39894*Math.exp(-.5*a*a/(n*n))/n);let s=[],r=[];for(let a=1;a<t;a+=2){let o=e[a],c=a+1<t?e[a+1]:0,l=o+c;s.push((a*o+(a+1)*c)/l),r.push(l)}return new Ge({defines:{KERNEL_PAIRS:s.length},uniforms:{colorTexture:{value:null},invSize:{value:new yt(.5,.5)},direction:{value:new yt(.5,.5)},centerWeight:{value:e[0]},gaussianOffsets:{value:s},gaussianWeights:{value:r}},vertexShader:`

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

				}`})}_getCompositeMaterial(t){return new Ge({defines:{NUM_MIPS:t},uniforms:{blurTexture1:{value:null},blurTexture2:{value:null},blurTexture3:{value:null},blurTexture4:{value:null},blurTexture5:{value:null},bloomStrength:{value:1},bloomFactors:{value:null},bloomTintColors:{value:null},bloomRadius:{value:0}},vertexShader:`

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

				}`})}};Fr.BlurDirectionX=new yt(1,0);Fr.BlurDirectionY=new yt(0,1);var ho={name:"OutputShader",uniforms:{tDiffuse:{value:null},toneMappingExposure:{value:1}},vertexShader:`
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

		}`};var Uc=class extends Yn{constructor(){super(),this.isOutputPass=!0,this.uniforms=Yi.clone(ho.uniforms),this.material=new Sr({name:ho.name,uniforms:this.uniforms,vertexShader:ho.vertexShader,fragmentShader:ho.fragmentShader}),this._fsQuad=new _s(this.material),this._outputColorSpace=null,this._toneMapping=null}render(t,e,n){this.uniforms.tDiffuse.value=n.texture,this.uniforms.toneMappingExposure.value=t.toneMappingExposure,(this._outputColorSpace!==t.outputColorSpace||this._toneMapping!==t.toneMapping)&&(this._outputColorSpace=t.outputColorSpace,this._toneMapping=t.toneMapping,this.material.defines={},Re.getTransfer(this._outputColorSpace)===Oe&&(this.material.defines.SRGB_TRANSFER=""),this._toneMapping===Xa?this.material.defines.LINEAR_TONE_MAPPING="":this._toneMapping===$a?this.material.defines.REINHARD_TONE_MAPPING="":this._toneMapping===qa?this.material.defines.CINEON_TONE_MAPPING="":this._toneMapping===Rs?this.material.defines.ACES_FILMIC_TONE_MAPPING="":this._toneMapping===Za?this.material.defines.AGX_TONE_MAPPING="":this._toneMapping===Ja?this.material.defines.NEUTRAL_TONE_MAPPING="":this._toneMapping===Ya&&(this.material.defines.CUSTOM_TONE_MAPPING=""),this.material.needsUpdate=!0),this.renderToScreen===!0?(t.setRenderTarget(null),this._fsQuad.render(t)):(t.setRenderTarget(e),this.clear&&t.clear(t.autoClearColor,t.autoClearDepth,t.autoClearStencil),this._fsQuad.render(t))}dispose(){this.material.dispose(),this._fsQuad.dispose()}};function vf(i,t,e=256){let n=i.image;if(!(n instanceof HTMLCanvasElement)||Math.max(n.width,n.height)<=e)return;let s=document.createElement("canvas"),r=e/Math.max(n.width,n.height);s.width=Math.max(1,Math.round(n.width*r)),s.height=Math.max(1,Math.round(n.height*r));let a=s.getContext("2d"),o=Object.getOwnPropertyDescriptor(Sn.prototype,"needsUpdate").set,c=()=>{a.drawImage(n,0,0,s.width,s.height),o.call(i,!0)};i.image=s,Object.defineProperty(i,"needsUpdate",{configurable:!0,set(l){l&&(c(),t())}}),c()}function yf(i){let t=new Set([i.outer,i.inner,i.hit,i.ring,...i.bOuter,...i.streaks]);for(let e of i.stdParts.concat(i.heavy)){let n=[];e.traverse(s=>{s.isGroup&&n.push(s)});for(let s of n){let r=new Map;for(let a of s.children){if(!a.isMesh||a.children.length||t.has(a))continue;let o=`${a.geometry.uuid}/${a.material.uuid}`;r.has(o)||r.set(o,[]),r.get(o).push(a)}for(let a of r.values()){if(a.length<2)continue;let o=a[0],c=new ga(o.geometry,o.material,a.length);a.forEach((l,h)=>{l.updateMatrix(),c.setMatrixAt(h,l.matrix),s.remove(l)}),c.computeBoundingSphere(),s.add(c)}}}}function Mf(i,t,e,n=40){let s=a=>a.x*Math.cos(e)-a.z*Math.sin(e),r=new Map(i.map(a=>[a,a.tgt.x]));for(let a=0;a<n;a++)for(let o=0;o<i.length;o++)for(let c=o+1;c<i.length;c++){let l=i[o],h=i[c],f=s(h.tgt)-s(l.tgt),u=(h.tgt.y-l.tgt.y)*.3,d=Math.hypot(f,u);if(d<t){let m=r.get(h)-r.get(l),x=(t-d)/2,g=m!==0?Math.sign(m):f>=0?1:-1;l.tgt.x-=x*g,h.tgt.x+=x*g,l.nudge-=x*g,h.nudge+=x*g}}}function bf(i){let e=new D(0,-55,-8),n=new D(-.93,.07,-.36).normalize(),s=`vec3 m289(vec3 x){return x-floor(x*(1./289.))*289.;} vec4 m289(vec4 x){return x-floor(x*(1./289.))*289.;} vec4 perm(vec4 x){return m289(((x*34.)+1.)*x);} vec4 tis(vec4 r){return 1.79284291400159-.85373472095314*r;}
float snoise(vec3 v){ const vec2 C=vec2(1./6.,1./3.); const vec4 D=vec4(0.,.5,1.,2.); vec3 i=floor(v+dot(v,C.yyy)); vec3 x0=v-i+dot(i,C.xxx); vec3 g=step(x0.yzx,x0.xyz); vec3 l=1.-g; vec3 i1=min(g.xyz,l.zxy); vec3 i2=max(g.xyz,l.zxy); vec3 x1=x0-i1+C.xxx; vec3 x2=x0-i2+C.yyy; vec3 x3=x0-D.yyy; i=m289(i);
 vec4 p=perm(perm(perm(i.z+vec4(0.,i1.z,i2.z,1.))+i.y+vec4(0.,i1.y,i2.y,1.))+i.x+vec4(0.,i1.x,i2.x,1.)); float n_=.142857142857; vec3 ns=n_*D.wyz-D.xzx; vec4 j=p-49.*floor(p*ns.z*ns.z); vec4 x_=floor(j*ns.z); vec4 y_=floor(j-7.*x_); vec4 x=x_*ns.x+ns.yyyy; vec4 y=y_*ns.x+ns.yyyy; vec4 h=1.-abs(x)-abs(y); vec4 b0=vec4(x.xy,y.xy); vec4 b1=vec4(x.zw,y.zw); vec4 s0=floor(b0)*2.+1.; vec4 s1=floor(b1)*2.+1.; vec4 sh=-step(h,vec4(0.));
 vec4 a0=b0.xzyw+s0.xzyw*sh.xxyy; vec4 a1=b1.xzyw+s1.xzyw*sh.zzww; vec3 p0=vec3(a0.xy,h.x); vec3 p1=vec3(a0.zw,h.y); vec3 p2=vec3(a1.xy,h.z); vec3 p3=vec3(a1.zw,h.w); vec4 nr=tis(vec4(dot(p0,p0),dot(p1,p1),dot(p2,p2),dot(p3,p3))); p0*=nr.x; p1*=nr.y; p2*=nr.z; p3*=nr.w;
 vec4 m=max(.6-vec4(dot(x0,x0),dot(x1,x1),dot(x2,x2),dot(x3,x3)),0.); m=m*m; return 42.*dot(m*m,vec4(dot(p0,x0),dot(p1,x1),dot(p2,x2),dot(p3,x3))); }
float fbm6(vec3 p){ float s=0., a=.5; for(int i=0;i<6;i++){ s+=a*snoise(p); p=p*2.03+vec3(1.7,9.2,3.1); a*=.5; } return s; }
float fbm4(vec3 p){ float s=0., a=.5; for(int i=0;i<4;i++){ s+=a*snoise(p); p=p*2.1+vec3(4.1,2.3,7.7); a*=.5; } return s; }`,r=new nn;r.position.copy(e),i.add(r);let a=new Ge({uniforms:{sun:{value:n},t:{value:0}},vertexShader:"varying vec3 vP; varying vec3 vWN; varying vec3 vWP; void main(){ vP=position; vWN=normalize(mat3(modelMatrix)*normal); vec4 w=modelMatrix*vec4(position,1.); vWP=w.xyz; gl_Position=projectionMatrix*viewMatrix*w; }",fragmentShader:`uniform vec3 sun; uniform float t; varying vec3 vP; varying vec3 vWN; varying vec3 vWP;
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
}`}),o=new we(new jn(46,128,96),a);r.add(o);let c=new we(new jn(46*1.028,96,64),new Ge({side:Rn,transparent:!0,depthWrite:!1,blending:pn,uniforms:{sun:{value:n}},vertexShader:"varying vec3 vN; varying vec3 wN; void main(){ vN=normalize(normalMatrix*normal); wN=normalize(mat3(modelMatrix)*normal); gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",fragmentShader:"uniform vec3 sun; varying vec3 vN; varying vec3 wN; void main(){ float i=pow(max(0.,.76-dot(vN,vec3(0.,0.,1.))),3.2); float s=.12+1.6*smoothstep(-.35,.55,dot(wN,sun)); vec3 c=mix(vec3(.2,.5,1.),vec3(.7,.88,1.),smoothstep(.3,.9,dot(wN,sun))); gl_FragColor=vec4(c*i*s*1.25,1.); }"}));return r.add(c),{update(l){a.uniforms.t.value=l,o.rotation.y=l*.002},dispose(){r.traverse(l=>{l.geometry?.dispose(),l.material?.dispose()}),i.remove(r)}}}var gi=i=>i,v3={openai:gi({colour:"#ececec",base:"#f3f3f1",ink:"#111214",cap:"#111214",trim:["#111214"],pattern:"lattice",glyph:"openai-white.svg"}),anthropic:gi({colour:"#d97757",base:"#f0eee6",ink:"#d97757",cap:"#d97757",trim:["#191919"],pattern:"split",glyph:"claude.svg"}),alibaba:gi({colour:"#ff6a00",base:"#ff6a00",ink:"#ffffff",cap:"#ffffff",trim:["#6950ef"],pattern:"diagonal",glyph:"alibaba.svg"}),xiaomi:gi({colour:"#ff6900",base:"#ffffff",ink:"#ff6900",cap:"#ff6900",trim:["#ff6900","#ffffff"],pattern:"rings",glyph:"xiaomi.svg"}),google:gi({colour:"#4285f4",base:"#ffffff",ink:"#4285f4",inks:["#4285f4","#ea4335","#fbbc05","#34a853"],cap:"#4285f4",trim:["#4285f4","#ea4335","#fbbc05","#34a853"],pattern:"lattice",glyph:"gemini.svg"}),kimi:gi({colour:"#007cff",base:"#007cff",ink:"#ffffff",cap:"#121212",trim:["#121212"],pattern:"rings",glyph:"kimi-white.svg"}),minimax:gi({colour:"#e73562",base:"#e73562",ink:"#ffffff",cap:"#ffffff",trim:["#ffffff"],pattern:"rings",glyph:"minimax.svg"}),zhipuai:gi({colour:"#b9c2cc",base:"#1a1d21",ink:"#ffffff",cap:"#ffffff",trim:["#ffffff","#1a1d21"],pattern:"lattice",glyph:"zai-white.svg"}),xai:gi({colour:"#8f96a0",base:"#0b0b0c",ink:"#f2f2f2",cap:"#0b0b0c",trim:["#f2f2f2"],pattern:"diagonal",glyph:"x-white.svg"}),meta:gi({colour:"#0467df",base:"#ffffff",ink:"#0467df",cap:"#0467df",trim:["#0467df"],pattern:"diagonal",glyph:"meta.svg"}),deepseek:gi({colour:"#4d6bfe",base:"#4d6bfe",ink:"#ffffff",cap:"#ffffff",trim:["#ffffff"],pattern:"diagonal",glyph:"deepseek.svg"})};function Or(i,t="#b8b0a8"){return v3[i]??{colour:t,base:t,ink:"#ffffff",cap:"#ffffff",trim:["#ffffff"],pattern:"rings",glyph:null}}function Fc(i,t=!1){let e=i[0].index!==null,n=new Set(Object.keys(i[0].attributes)),s=new Set(Object.keys(i[0].morphAttributes)),r={},a={},o=i[0].morphTargetsRelative,c=new Le,l=0;for(let h=0;h<i.length;++h){let f=i[h],u=0;if(e!==(f.index!==null))return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". All geometries must have compatible attributes; make sure index attribute exists among all geometries, or in none of them."),null;for(let d in f.attributes){if(!n.has(d))return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+'. All geometries must have compatible attributes; make sure "'+d+'" attribute exists among all geometries, or in none of them.'),null;r[d]===void 0&&(r[d]=[]),r[d].push(f.attributes[d]),u++}if(u!==n.size)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". Make sure all geometries have the same number of attributes."),null;if(o!==f.morphTargetsRelative)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". .morphTargetsRelative must be consistent throughout all geometries."),null;for(let d in f.morphAttributes){if(!s.has(d))return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+".  .morphAttributes must be consistent throughout all geometries."),null;a[d]===void 0&&(a[d]=[]),a[d].push(f.morphAttributes[d])}if(t){let d;if(e)d=f.index.count;else if(f.attributes.position!==void 0)d=f.attributes.position.count;else return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". The geometry must have either an index or a position attribute"),null;c.addGroup(l,d,h),l+=d}}if(e){let h=0,f=[];for(let u=0;u<i.length;++u){let d=i[u].index;for(let m=0;m<d.count;++m)f.push(d.getX(m)+h);h+=i[u].attributes.position.count}c.setIndex(f)}for(let h in r){let f=Sf(r[h]);if(!f)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed while trying to merge the "+h+" attribute."),null;c.setAttribute(h,f)}for(let h in a){let f=a[h][0].length;if(f!==0){c.morphAttributes=c.morphAttributes||{},c.morphAttributes[h]=[];for(let u=0;u<f;++u){let d=[];for(let x=0;x<a[h].length;++x)d.push(a[h][x][u]);let m=Sf(d);if(!m)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed while trying to merge the "+h+" morphAttribute."),null;c.morphAttributes[h].push(m)}}}return c}function Sf(i){let t,e,n,s=-1,r=0;for(let l=0;l<i.length;++l){let h=i[l];if(t===void 0&&(t=h.array.constructor),t!==h.array.constructor)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.array must be of consistent array types across matching attributes."),null;if(e===void 0&&(e=h.itemSize),e!==h.itemSize)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.itemSize must be consistent across matching attributes."),null;if(n===void 0&&(n=h.normalized),n!==h.normalized)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.normalized must be consistent across matching attributes."),null;if(s===-1&&(s=h.gpuType),s!==h.gpuType)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.gpuType must be consistent across matching attributes."),null;r+=h.count*e}let a=new t(r),o=new ln(a,e,n),c=0;for(let l=0;l<i.length;++l){let h=i[l];if(h.isInterleavedBufferAttribute){let f=c/e;for(let u=0,d=h.count;u<d;u++)for(let m=0;m<e;m++){let x=h.getComponent(u,m);o.setComponent(u+f,m,x)}}else a.set(h.array,c);c+=h.count*e}return s!==void 0&&(o.gpuType=s),o}var uo={falcon9:{id:"falcon9",shape:"falcon9",atlas:{w:852,h:1024,cap:[.993,.9941,.9977,.998]},parts:[{name:"core",uv:[0,0,.9014,1],top:1.6,end:-1.1295,profile:[[1.6,.018],[1.5886,.0552],[1.5771,.0765],[1.5657,.0934],[1.5543,.1083],[1.5429,.1218],[1.5314,.1343],[1.52,.1459],[1.5086,.1566],[1.4971,.1664],[1.4857,.1756],[1.4743,.1839],[1.4629,.1914],[1.4514,.1981],[1.44,.2041],[1.4286,.2094],[1.4171,.2139],[1.4057,.2178],[1.3943,.2211],[1.3829,.2238],[1.3714,.226],[1.36,.2275],[1.3486,.2282],[1.3371,.2287],[1.3257,.229],[1.3143,.2291],[1.3029,.2291],[1.2914,.229],[1.28,.2289],[1.2686,.2287],[1.2571,.2286],[1.2457,.2284],[1.2343,.2282],[1.2229,.2281],[1.2114,.2279],[1.2,.2278],[1.1886,.2278],[1.1771,.2281],[1.1657,.2285],[1.1543,.2284],[1.1429,.2281],[1.1314,.228],[1.12,.228],[1.1086,.228],[1.0971,.2279],[1.0857,.2277],[1.0743,.2275],[1.0629,.2274],[1.0514,.2271],[1.04,.2264],[1.0286,.2247],[1.0171,.2213],[1.0057,.216],[.9943,.2087],[.9829,.2001],[.9714,.1909],[.96,.1818],[.9486,.1735],[.9371,.1672],[.9257,.1629],[.9143,.1598],[.9029,.1574],[.8914,.1563],[.88,.1559],[.8686,.1557],[.8571,.1557],[.8457,.156],[.8343,.1564],[.8229,.1567],[.8114,.1568],[.8,.1567],[.7886,.1566],[.7771,.1567],[.7657,.157],[.7543,.1575],[.7429,.1576],[.7314,.1576],[.72,.1575],[.7086,.1574],[.6971,.1574],[.6857,.1576],[.6743,.1577],[.6629,.1575],[.6514,.157],[.64,.1568],[.6286,.1566],[.6171,.1565],[.6057,.1564],[.5943,.1564],[.5829,.1568],[.5714,.1589],[.56,.1642],[.5486,.1742],[.5371,.1896],[.5257,.2095],[.5143,.2305],[.5029,.2478],[.4914,.2566],[.48,.2521],[.4686,.232],[.4571,.2026],[.4457,.1795],[.4343,.1697],[.4229,.1675],[.4114,.1671],[.4,.1666],[.3886,.1659],[.3771,.1655],[.3657,.1652],[.3543,.1651],[.3429,.165],[.3314,.1649],[.32,.1648],[.3086,.1646],[.2971,.1645],[.2857,.1644],[.2743,.1643],[.2629,.1642],[.2514,.164],[.24,.164],[.2286,.1638],[.2171,.1637],[.2057,.1636],[.1943,.1636],[.1829,.1639],[.1714,.1645],[.16,.1653],[.1486,.1659],[.1371,.166],[.1257,.1659],[.1143,.1658],[.1029,.1657],[.0914,.1656],[.08,.1655],[.0686,.1654],[.0571,.1653],[.0457,.1651],[.0343,.165],[.0229,.1649],[.0114,.1648],[0,.1647],[-.0114,.1646],[-.0229,.1645],[-.0343,.1644],[-.0457,.1642],[-.0571,.1641],[-.0686,.164],[-.08,.164],[-.0914,.164],[-.1029,.1642],[-.1143,.1645],[-.1257,.1645],[-.1371,.1643],[-.1486,.1643],[-.16,.1646],[-.1714,.165],[-.1829,.1655],[-.1943,.1657],[-.2057,.1657],[-.2171,.1656],[-.2286,.1655],[-.24,.1654],[-.2514,.1653],[-.2629,.1652],[-.2743,.1651],[-.2857,.165],[-.2971,.1649],[-.3086,.1647],[-.32,.1646],[-.3314,.1645],[-.3429,.1644],[-.3543,.1643],[-.3657,.1644],[-.3771,.165],[-.3886,.1666],[-.4,.1684],[-.4114,.1694],[-.4229,.1696],[-.4343,.1696],[-.4457,.1695],[-.4571,.1694],[-.4686,.1692],[-.48,.1692],[-.4914,.169],[-.5029,.1689],[-.5143,.1688],[-.5257,.1687],[-.5371,.1686],[-.5486,.1685],[-.56,.1683],[-.5714,.1682],[-.5829,.1681],[-.5943,.168],[-.6057,.1679],[-.6171,.1678],[-.6286,.1677],[-.64,.1676],[-.6514,.1675],[-.6629,.1673],[-.6743,.1673],[-.6857,.1671],[-.6971,.167],[-.7086,.1669],[-.72,.1668],[-.7314,.1667],[-.7429,.1666],[-.7543,.1665],[-.7657,.1664],[-.7771,.1663],[-.7886,.1661],[-.8,.166],[-.8114,.1659],[-.8229,.1658],[-.8343,.1657],[-.8457,.1656],[-.8571,.1655],[-.8686,.1654],[-.88,.1653],[-.8914,.1652],[-.9029,.1651],[-.9143,.165],[-.9257,.1649],[-.9371,.1647],[-.9486,.1646],[-.96,.1645],[-.9714,.1644],[-.9829,.1643],[-.9943,.1642],[-1.0057,.1641],[-1.0171,.164],[-1.0286,.1639],[-1.04,.1638],[-1.0514,.1637],[-1.0629,.1636],[-1.0743,.1635],[-1.0857,.1634],[-1.0971,.1633],[-1.1086,.1631],[-1.12,.1631],[-1.1276,.163]],at:[[0,0]],fins:[{side:-1,uv:[.9014,.6426,.9894,1],x0:-.2226,x1:0,y0:-.4381,y1:-1.1352,outline:[[-.4381,.1721,.1662],[-.4438,.1751,.1662],[-.4495,.1751,.1662],[-.4552,.1751,.1662],[-.461,.1781,.1662],[-.4667,.1781,.1662],[-.4724,.1781,.1662],[-.4781,.1781,.1662],[-.4838,.181,.1662],[-.4895,.181,.1662],[-.4952,.181,.1662],[-.501,.181,.1662],[-.5067,.181,.1662],[-.5124,.184,.1662],[-.5181,.184,.1662],[-.5238,.184,.1662],[-.5295,.184,.1662],[-.5352,.184,.1662],[-.541,.187,.1662],[-.5467,.187,.1662],[-.5524,.187,.1662],[-.5581,.1899,.1662],[-.5638,.1899,.1662],[-.5695,.1899,.1662],[-.5752,.1899,.1662],[-.581,.1899,.1662],[-.5867,.187,.1662],[-.5924,.1899,.1662],[-.5981,.1899,.1662],[-.6038,.1899,.1662],[-.6095,.1899,.1662],[-.6152,.1899,.1662],[-.621,.1899,.1662],[-.6267,.1899,.1662],[-.6324,.1899,.1662],[-.6381,.1899,.1662],[-.6438,.1899,.1662],[-.6495,.1899,.1662],[-.6552,.1899,.1662],[-.661,.1929,.1662],[-.6667,.1929,.1662],[-.6724,.1929,.1662],[-.6781,.1929,.1662],[-.6838,.1929,.1662],[-.6895,.1929,.1662],[-.6952,.1929,.1662],[-.701,.1929,.1662],[-.7067,.1959,.1662],[-.7124,.1959,.1662],[-.7181,.1959,.1662],[-.7238,.1959,.1662],[-.7295,.1959,.1662],[-.7352,.1959,.1662],[-.741,.1959,.1662],[-.7467,.1959,.1662],[-.7524,.1959,.1662],[-.7581,.1988,.1662],[-.7638,.1988,.1662],[-.7695,.1988,.1662],[-.7752,.1988,.1662],[-.781,.1988,.1662],[-.7867,.1988,.1662],[-.7924,.1988,.1662],[-.7981,.1988,.1662],[-.8038,.2018,.1662],[-.8095,.2018,.1662],[-.8152,.2018,.1662],[-.821,.2018,.1662],[-.8267,.2018,.1662],[-.8324,.2018,.1662],[-.8381,.2018,.1662],[-.8438,.2018,.1662],[-.8495,.2018,.1662],[-.8552,.2018,.1662],[-.861,.2047,.1662],[-.8667,.2047,.1662],[-.8724,.2047,.1662],[-.8781,.2047,.1662],[-.8838,.2047,.1662],[-.8895,.2047,.1662],[-.8952,.2047,.1662],[-.901,.2077,.1662],[-.9067,.2077,.1662],[-.9124,.2077,.1662],[-.9181,.2077,.1662],[-.9238,.2077,.1662],[-.9295,.2077,.1662],[-.9352,.2077,.1662],[-.941,.2077,.1662],[-.9467,.2107,.1662],[-.9524,.2107,.1662],[-.9581,.2107,.1662],[-.9638,.2107,.1662],[-.9695,.2107,.1662],[-.9752,.2107,.1662],[-.981,.2107,.1662],[-.9867,.2136,.1662],[-.9924,.2136,.1662],[-.9981,.2136,.1662],[-1.0038,.2136,.1662],[-1.0095,.2136,.1662],[-1.0152,.2136,.1662],[-1.021,.2166,.1662],[-1.0267,.2196,.1662],[-1.0324,.2196,.1662],[-1.0381,.2196,.1662],[-1.0438,.2107,.1662],[-1.0495,.2047,.1662],[-1.0552,.1988,.1662],[-1.061,.1988,.1662],[-1.0667,.1988,.1662],[-1.0724,.2018,.1662],[-1.0781,.2018,.1662],[-1.0838,.2018,.1662],[-1.0895,.2018,.1662],[-1.0952,.2018,.1662],[-1.101,.2047,.1662],[-1.1067,.2047,.1662],[-1.1124,.2047,.1662],[-1.1181,.2047,.1662],[-1.1238,.1988,.1662],[-1.1295,.1899,.1662],[-1.1333,.184,.1662]]},{side:1,uv:[.9014,.2832,.9906,.6406],x0:0,x1:.2255,y0:-.4381,y1:-1.1352,outline:[[-.4381,.1721,.1662],[-.4438,.1751,.1662],[-.4495,.1751,.1662],[-.4552,.1751,.1662],[-.461,.1781,.1662],[-.4667,.1781,.1662],[-.4724,.1781,.1662],[-.4781,.1781,.1662],[-.4838,.181,.1662],[-.4895,.181,.1662],[-.4952,.181,.1662],[-.501,.181,.1662],[-.5067,.184,.1662],[-.5124,.184,.1662],[-.5181,.184,.1662],[-.5238,.184,.1662],[-.5295,.184,.1662],[-.5352,.187,.1662],[-.541,.187,.1662],[-.5467,.187,.1662],[-.5524,.1899,.1662],[-.5581,.1929,.1662],[-.5638,.1929,.1662],[-.5695,.1929,.1662],[-.5752,.1899,.1662],[-.581,.1899,.1662],[-.5867,.1899,.1662],[-.5924,.1899,.1662],[-.5981,.1899,.1662],[-.6038,.1899,.1662],[-.6095,.1929,.1662],[-.6152,.1929,.1662],[-.621,.1929,.1662],[-.6267,.1929,.1662],[-.6324,.1929,.1662],[-.6381,.1929,.1662],[-.6438,.1929,.1662],[-.6495,.1929,.1662],[-.6552,.1929,.1662],[-.661,.1929,.1662],[-.6667,.1959,.1662],[-.6724,.1959,.1662],[-.6781,.1959,.1662],[-.6838,.1959,.1662],[-.6895,.1959,.1662],[-.6952,.1959,.1662],[-.701,.1959,.1662],[-.7067,.1959,.1662],[-.7124,.1959,.1662],[-.7181,.1959,.1662],[-.7238,.1988,.1662],[-.7295,.1988,.1662],[-.7352,.1988,.1662],[-.741,.1988,.1662],[-.7467,.1988,.1662],[-.7524,.1988,.1662],[-.7581,.1988,.1662],[-.7638,.2018,.1662],[-.7695,.2018,.1662],[-.7752,.2018,.1662],[-.781,.2018,.1662],[-.7867,.2018,.1662],[-.7924,.2018,.1662],[-.7981,.2018,.1662],[-.8038,.2018,.1662],[-.8095,.2047,.1662],[-.8152,.2047,.1662],[-.821,.2047,.1662],[-.8267,.2047,.1662],[-.8324,.2047,.1662],[-.8381,.2047,.1662],[-.8438,.2047,.1662],[-.8495,.2077,.1662],[-.8552,.2077,.1662],[-.861,.2077,.1662],[-.8667,.2077,.1662],[-.8724,.2077,.1662],[-.8781,.2077,.1662],[-.8838,.2077,.1662],[-.8895,.2107,.1662],[-.8952,.2107,.1662],[-.901,.2107,.1662],[-.9067,.2107,.1662],[-.9124,.2107,.1662],[-.9181,.2107,.1662],[-.9238,.2107,.1662],[-.9295,.2136,.1662],[-.9352,.2136,.1662],[-.941,.2136,.1662],[-.9467,.2136,.1662],[-.9524,.2136,.1662],[-.9581,.2136,.1662],[-.9638,.2136,.1662],[-.9695,.2166,.1662],[-.9752,.2166,.1662],[-.981,.2166,.1662],[-.9867,.2166,.1662],[-.9924,.2166,.1662],[-.9981,.2196,.1662],[-1.0038,.2196,.1662],[-1.0095,.2196,.1662],[-1.0152,.2225,.1662],[-1.021,.2225,.1662],[-1.0267,.2225,.1662],[-1.0324,.2225,.1662],[-1.0381,.2225,.1662],[-1.0438,.2166,.1662],[-1.0495,.2107,.1662],[-1.0552,.2018,.1662],[-1.061,.2018,.1662],[-1.0667,.2018,.1662],[-1.0724,.2047,.1662],[-1.0781,.2047,.1662],[-1.0838,.2047,.1662],[-1.0895,.2047,.1662],[-1.0952,.2047,.1662],[-1.101,.2047,.1662],[-1.1067,.2047,.1662],[-1.1124,.2047,.1662],[-1.1181,.2047,.1662],[-1.1238,.2047,.1662],[-1.1295,.1959,.1662],[-1.1333,.1899,.1662]]}],finsAround:4,finsFrom:null,engines:{ring:8,centre:!0,f:.34,colour:[32,26,19],profile:[[-1.1295,.1892],[-1.1333,.1833],[-1.1371,.1803],[-1.141,.1818],[-1.1448,.1817],[-1.1486,.1846],[-1.1524,.186],[-1.1562,.1874],[-1.16,.1888],[-1.1638,.1902],[-1.1676,.1917],[-1.1714,.1931],[-1.1752,.1945],[-1.179,.1959],[-1.1829,.1973],[-1.1867,.1987],[-1.1905,.2001],[-1.1943,.2001],[-1.1981,.2015],[-1.2019,.2029],[-1.2057,.2028],[-1.2095,.1984],[-1.2133,.1854],[-1.2171,.1506],[-1.221,.1505],[-1.2248,.1476],[-1.2286,.1302],[-1.2324,.055],[-1.2362,.0521],[-1.24,.0405]]}}],badge:{y:.9137,d:.2397,r:.1598},band:[.7607,.7796],head:{top:1.6,cut:1.0666,mean:.7703,r:.2696}},falconHeavy:{id:"falcon-heavy",shape:"falconHeavy",atlas:{w:1236,h:1024,cap:[.9951,.9941,.9984,.998]},parts:[{name:"core",uv:[0,0,.6214,1],top:1.6,end:-1.1103,profile:[[1.6,.0148],[1.5884,.0342],[1.5768,.0518],[1.5652,.0675],[1.5535,.0822],[1.5419,.0952],[1.5303,.1071],[1.5187,.1182],[1.5071,.1283],[1.4955,.1375],[1.4838,.1459],[1.4722,.1535],[1.4606,.1604],[1.449,.1666],[1.4374,.1721],[1.4258,.1771],[1.4142,.1814],[1.4025,.1851],[1.3909,.1882],[1.3793,.1907],[1.3677,.1927],[1.3561,.1942],[1.3445,.1952],[1.3328,.1959],[1.3212,.1961],[1.3096,.1961],[1.298,.196],[1.2864,.1959],[1.2748,.1958],[1.2631,.1957],[1.2515,.1956],[1.2399,.1955],[1.2283,.1955],[1.2167,.1958],[1.2051,.1962],[1.1935,.1964],[1.1818,.1964],[1.1702,.1963],[1.1586,.1962],[1.147,.1961],[1.1354,.196],[1.1238,.1959],[1.1121,.1958],[1.1005,.1957],[1.0889,.1956],[1.0773,.1955],[1.0657,.1954],[1.0541,.1953],[1.0425,.1952],[1.0308,.1951],[1.0192,.195],[1.0076,.1948],[.996,.1946],[.9844,.1938],[.9728,.192],[.9611,.1887],[.9495,.1842],[.9379,.1788],[.9263,.1731],[.9147,.1673],[.9031,.1617],[.8915,.1567],[.8798,.1525],[.8682,.1495],[.8566,.1479],[.845,.1473],[.8334,.1472],[.8218,.1471],[.8101,.147],[.7985,.1469],[.7869,.1469],[.7753,.1468],[.7637,.1467],[.7521,.1467],[.7404,.1468],[.7288,.1469],[.7172,.1471],[.7056,.1473],[.694,.1476],[.6824,.1479],[.6708,.1483],[.6591,.1487],[.6475,.1491],[.6359,.1496],[.6243,.1501],[.6127,.1507],[.6011,.1513],[.5894,.1519],[.5778,.1526],[.5662,.1533],[.5546,.1539],[.543,.1546],[.5314,.1554],[.5198,.1561],[.5081,.1568],[.4965,.1575],[.4849,.1583],[.4733,.159],[.4617,.1598],[.4501,.1605],[.4384,.1613],[.4268,.162],[.4152,.1627],[.4036,.1634],[.392,.164],[.3804,.1646],[.3688,.1651],[.3571,.1655],[.3455,.1659],[.3339,.1663],[.3223,.1664],[.3107,.1663],[.2991,.1662],[.2874,.1662],[.2758,.1661],[.2642,.166],[.2526,.1659],[.241,.1658],[.2294,.1657],[.2178,.1657],[.2061,.1656],[.1945,.1655],[.1829,.1654],[.1713,.1653],[.1597,.1653],[.1481,.1652],[.1364,.1651],[.1248,.1651],[.1132,.1653],[.1016,.1657],[.09,.1657],[.0784,.1655],[.0667,.1653],[.0551,.1654],[.0435,.1657],[.0319,.1658],[.0203,.1659],[.0087,.1663],[-.0029,.1666],[-.0146,.1667],[-.0262,.1667],[-.0378,.1666],[-.0494,.1665],[-.061,.1664],[-.0726,.1664],[-.0843,.1663],[-.0959,.1662],[-.1075,.1661],[-.1191,.166],[-.1307,.1659],[-.1423,.1659],[-.1539,.1658],[-.1656,.1657],[-.1772,.1656],[-.1888,.1656],[-.2004,.1657],[-.212,.1661],[-.2236,.1664],[-.2353,.1665],[-.2469,.1665],[-.2585,.1664],[-.2701,.1663],[-.2817,.1662],[-.2933,.1662],[-.3049,.1661],[-.3166,.166],[-.3282,.1659],[-.3398,.1658],[-.3514,.1657],[-.363,.1657],[-.3746,.1656],[-.3863,.1655],[-.3979,.1654],[-.4095,.1653],[-.4211,.1653],[-.4327,.1652],[-.4443,.1651],[-.456,.1651],[-.4676,.1653],[-.4792,.1656],[-.4908,.1659],[-.5024,.166],[-.514,.166],[-.5256,.1659],[-.5373,.1658],[-.5489,.1657],[-.5605,.1656],[-.5721,.1656],[-.5837,.1655],[-.5953,.1654],[-.607,.1653],[-.6186,.1652],[-.6302,.1651],[-.6418,.1651],[-.6534,.165],[-.665,.1649],[-.6766,.1648],[-.6883,.1648],[-.6999,.1647],[-.7115,.1646],[-.7231,.1645],[-.7347,.1644],[-.7463,.1643],[-.758,.1643],[-.7696,.1642],[-.7812,.1641],[-.7928,.164],[-.8044,.1639],[-.816,.1639],[-.8276,.1638],[-.8393,.1637],[-.8509,.1636],[-.8625,.1636],[-.8741,.1635],[-.8857,.1634],[-.8973,.1633],[-.909,.1632],[-.9206,.1631],[-.9322,.1631],[-.9438,.163],[-.9554,.1629],[-.967,.1628],[-.9787,.1628],[-.9903,.1627],[-1.0019,.1626],[-1.0135,.1625],[-1.0251,.1625],[-1.0367,.1624],[-1.0483,.1623],[-1.06,.1622],[-1.0716,.1621],[-1.0832,.1621],[-1.0948,.162],[-1.1064,.1619],[-1.1103,.1619]],at:[[0,0]],fins:[],finsAround:0,finsFrom:"booster",engines:{ring:8,centre:!0,f:.34,colour:[57,54,51],profile:[[-1.1103,.1592],[-1.1142,.1579],[-1.118,.1578],[-1.1219,.1578],[-1.1258,.1591],[-1.1297,.1591],[-1.1335,.1591],[-1.1374,.159],[-1.1413,.1564],[-1.1451,.1484],[-1.149,.1404],[-1.1529,.1377],[-1.1568,.1377],[-1.1606,.1377],[-1.1645,.1403],[-1.1684,.143],[-1.1722,.1456],[-1.1761,.1456],[-1.18,.1482],[-1.1839,.1508],[-1.1877,.1508],[-1.1916,.1534],[-1.1955,.1547],[-1.1993,.156],[-1.2032,.1586],[-1.2071,.1586],[-1.211,.1612],[-1.2148,.1625],[-1.2187,.1638],[-1.2226,.1664],[-1.2264,.1637],[-1.2303,.1479],[-1.2342,.1307],[-1.2381,.1069]]}},{name:"booster",uv:[.6214,.0498,.932,1],top:.7714,end:-1.1103,profile:[[.7714,.0142],[.7598,.0316],[.7482,.0465],[.7366,.0588],[.725,.0697],[.7133,.0796],[.7017,.0886],[.6901,.0969],[.6785,.1045],[.6669,.1114],[.6553,.1178],[.6437,.1235],[.632,.1286],[.6204,.1332],[.6088,.1371],[.5972,.1406],[.5856,.1436],[.574,.146],[.5623,.1478],[.5507,.1495],[.5391,.1512],[.5275,.1533],[.5159,.1559],[.5043,.1589],[.4927,.1618],[.481,.1646],[.4694,.1669],[.4578,.1685],[.4462,.1692],[.4346,.1687],[.423,.1671],[.4113,.1646],[.3997,.1616],[.3881,.158],[.3765,.1553],[.3649,.1542],[.3533,.1539],[.3416,.1537],[.33,.1533],[.3184,.1527],[.3068,.1523],[.2952,.1522],[.2836,.1521],[.272,.152],[.2603,.1519],[.2487,.1518],[.2371,.1519],[.2255,.1521],[.2139,.1525],[.2023,.1528],[.1906,.1528],[.179,.1528],[.1674,.1527],[.1558,.1526],[.1442,.1525],[.1326,.1525],[.121,.1524],[.1093,.1523],[.0977,.1522],[.0861,.1522],[.0745,.1523],[.0629,.1527],[.0513,.153],[.0396,.1532],[.028,.1532],[.0164,.1531],[.0048,.1529],[-.0068,.1526],[-.0184,.1521],[-.03,.1516],[-.0417,.1514],[-.0533,.1513],[-.0649,.1514],[-.0765,.1517],[-.0881,.152],[-.0997,.1522],[-.1114,.1522],[-.123,.1522],[-.1346,.1521],[-.1462,.152],[-.1578,.1519],[-.1694,.1519],[-.181,.1518],[-.1927,.1517],[-.2043,.1516],[-.2159,.1517],[-.2275,.1519],[-.2391,.1523],[-.2507,.1526],[-.2624,.1526],[-.274,.1526],[-.2856,.1525],[-.2972,.1524],[-.3088,.1523],[-.3204,.1519],[-.3321,.1515],[-.3437,.151],[-.3553,.1508],[-.3669,.1509],[-.3785,.1512],[-.3901,.1516],[-.4017,.1517],[-.4134,.1516],[-.425,.1516],[-.4366,.1516],[-.4482,.1519],[-.4598,.1528],[-.4714,.1539],[-.4831,.1548],[-.4947,.1551],[-.5063,.1551],[-.5179,.1551],[-.5295,.155],[-.5411,.1549],[-.5527,.1548],[-.5644,.1547],[-.576,.1547],[-.5876,.1546],[-.5992,.1545],[-.6108,.1544],[-.6224,.1544],[-.6341,.1543],[-.6457,.1542],[-.6573,.1541],[-.6689,.1541],[-.6805,.154],[-.6921,.1539],[-.7037,.1538],[-.7154,.1538],[-.727,.1537],[-.7386,.1536],[-.7502,.1536],[-.7618,.1535],[-.7734,.1534],[-.7851,.1533],[-.7967,.1533],[-.8083,.1532],[-.8199,.1531],[-.8315,.153],[-.8431,.1529],[-.8548,.1529],[-.8664,.1528],[-.878,.1527],[-.8896,.1526],[-.9012,.1526],[-.9128,.1525],[-.9244,.1524],[-.9361,.1524],[-.9477,.1523],[-.9593,.1522],[-.9709,.1521],[-.9825,.1521],[-.9941,.152],[-1.0058,.1519],[-1.0174,.1518],[-1.029,.1518],[-1.0406,.1517],[-1.0522,.1516],[-1.0638,.1516],[-1.0754,.1515],[-1.0871,.1514],[-1.0987,.1513],[-1.1103,.1513]],at:[[-1.5708,.3464],[1.5708,.3464]],fins:[{side:-1,uv:[.932,.709,.9935,1],x0:-.2041,x1:0,y0:-.5392,y1:-1.1161,outline:[[-.5392,.1584,.1531],[-.545,.1611,.1531],[-.5508,.1638,.1531],[-.5566,.1638,.1531],[-.5624,.1638,.1531],[-.5682,.1638,.1531],[-.574,.1638,.1531],[-.5799,.1638,.1531],[-.5857,.1665,.1531],[-.5915,.1665,.1531],[-.5973,.1665,.1531],[-.6031,.1665,.1531],[-.6089,.1665,.1531],[-.6147,.1692,.1531],[-.6205,.1692,.1531],[-.6263,.1692,.1531],[-.6321,.1692,.1531],[-.6379,.1692,.1531],[-.6437,.1692,.1531],[-.6495,.1692,.1531],[-.6554,.1692,.1531],[-.6612,.1718,.1531],[-.667,.1718,.1531],[-.6728,.1718,.1531],[-.6786,.1718,.1531],[-.6844,.1718,.1531],[-.6902,.1718,.1531],[-.696,.1745,.1531],[-.7018,.1745,.1531],[-.7076,.1745,.1531],[-.7134,.1745,.1531],[-.7192,.1745,.1531],[-.725,.1745,.1531],[-.7309,.1745,.1531],[-.7367,.1772,.1531],[-.7425,.1772,.1531],[-.7483,.1772,.1531],[-.7541,.1772,.1531],[-.7599,.1772,.1531],[-.7657,.1772,.1531],[-.7715,.1772,.1531],[-.7773,.1799,.1531],[-.7831,.1799,.1531],[-.7889,.1799,.1531],[-.7947,.1799,.1531],[-.8005,.1799,.1531],[-.8064,.1799,.1531],[-.8122,.1799,.1531],[-.818,.1826,.1531],[-.8238,.1826,.1531],[-.8296,.1826,.1531],[-.8354,.1826,.1531],[-.8412,.1826,.1531],[-.847,.1826,.1531],[-.8528,.1853,.1531],[-.8586,.1853,.1531],[-.8644,.1853,.1531],[-.8702,.1853,.1531],[-.876,.1853,.1531],[-.8819,.1853,.1531],[-.8877,.1853,.1531],[-.8935,.1853,.1531],[-.8993,.1879,.1531],[-.9051,.1879,.1531],[-.9109,.1879,.1531],[-.9167,.1879,.1531],[-.9225,.1879,.1531],[-.9283,.1906,.1531],[-.9341,.1906,.1531],[-.9399,.1906,.1531],[-.9457,.1906,.1531],[-.9515,.1906,.1531],[-.9574,.1933,.1531],[-.9632,.1933,.1531],[-.969,.1933,.1531],[-.9748,.1933,.1531],[-.9806,.1933,.1531],[-.9864,.1933,.1531],[-.9922,.196,.1531],[-.998,.196,.1531],[-1.0038,.196,.1531],[-1.0096,.196,.1531],[-1.0154,.196,.1531],[-1.0212,.196,.1531],[-1.027,.196,.1531],[-1.0329,.1987,.1531],[-1.0387,.1987,.1531],[-1.0445,.1987,.1531],[-1.0503,.1987,.1531],[-1.0561,.2014,.1531],[-1.0619,.2014,.1531],[-1.0677,.2014,.1531],[-1.0735,.2014,.1531],[-1.0793,.2014,.1531],[-1.0851,.1906,.1531],[-1.0909,.1853,.1531],[-1.0967,.1772,.1531],[-1.1025,.1692,.1531],[-1.1084,.1665,.1531],[-1.1142,.1665,.1531]]}],finsAround:4,finsFrom:null,engines:{ring:8,centre:!0,f:.34,colour:[60,58,55],profile:[[-1.1103,.1645],[-1.1142,.1645],[-1.118,.1645],[-1.1219,.1644],[-1.1258,.1671],[-1.1297,.167],[-1.1335,.167],[-1.1374,.167],[-1.1413,.1643],[-1.1451,.1563],[-1.149,.151],[-1.1529,.151],[-1.1568,.1457],[-1.1606,.1456],[-1.1645,.1483],[-1.1684,.1509],[-1.1722,.1535],[-1.1761,.1535],[-1.18,.1561],[-1.1839,.1587],[-1.1877,.1587],[-1.1916,.1613],[-1.1955,.1639],[-1.1993,.1639],[-1.2032,.1665],[-1.2071,.1692],[-1.211,.1691],[-1.2148,.1717],[-1.2187,.1744],[-1.2226,.169],[-1.2264,.1585],[-1.2303,.132],[-1.2342,.0924]]}}],badge:{y:.9137,d:.251,r:.1673},band:[.7551,.774],head:{top:1.6,cut:1.0723,mean:.7752,r:.2062}},newGlenn:{id:"new-glenn",shape:"newGlenn",atlas:{w:897,h:1142,cap:[.9933,.9947,.9978,.9982]},parts:[{name:"core",uv:[0,.1033,.8562,1],top:1.6,end:-1.1485,profile:[[1.6,.0169],[1.5886,.0402],[1.5771,.0587],[1.5657,.0741],[1.5543,.0879],[1.5428,.1001],[1.5314,.1112],[1.5199,.1216],[1.5085,.1311],[1.4971,.1398],[1.4856,.1476],[1.4742,.1546],[1.4628,.1608],[1.4513,.1666],[1.4399,.1717],[1.4285,.1762],[1.417,.1798],[1.4056,.1828],[1.3941,.1851],[1.3827,.1868],[1.3713,.1879],[1.3598,.1885],[1.3484,.1888],[1.337,.1889],[1.3255,.1888],[1.3141,.1887],[1.3027,.1885],[1.2912,.1883],[1.2798,.1881],[1.2683,.1879],[1.2569,.1878],[1.2455,.1876],[1.234,.1874],[1.2226,.1873],[1.2112,.1871],[1.1997,.187],[1.1883,.1871],[1.1769,.1873],[1.1654,.1876],[1.154,.1877],[1.1426,.1876],[1.1311,.1875],[1.1197,.1873],[1.1082,.1871],[1.0968,.1871],[1.0854,.1875],[1.0739,.1881],[1.0625,.1882],[1.0511,.1874],[1.0396,.1865],[1.0282,.186],[1.0168,.1858],[1.0053,.1856],[.9939,.1854],[.9824,.1852],[.971,.1851],[.9596,.1849],[.9481,.1848],[.9367,.1846],[.9253,.1845],[.9138,.1845],[.9024,.1848],[.891,.1851],[.8795,.1852],[.8681,.1852],[.8566,.1852],[.8452,.1855],[.8338,.1858],[.8223,.1859],[.8109,.1858],[.7995,.1856],[.788,.1855],[.7766,.1853],[.7652,.1852],[.7537,.1853],[.7423,.1856],[.7308,.1859],[.7194,.1859],[.708,.1858],[.6965,.1856],[.6851,.1854],[.6737,.1852],[.6622,.1854],[.6508,.1862],[.6394,.1869],[.6279,.1869],[.6165,.1864],[.605,.1862],[.5936,.1866],[.5822,.1873],[.5707,.1879],[.5593,.1881],[.5479,.188],[.5364,.1878],[.525,.1877],[.5136,.1875],[.5021,.1873],[.4907,.1872],[.4792,.1871],[.4678,.187],[.4564,.1869],[.4449,.1869],[.4335,.1869],[.4221,.1869],[.4106,.187],[.3992,.1872],[.3878,.1873],[.3763,.1876],[.3649,.1879],[.3534,.1883],[.342,.1888],[.3306,.1894],[.3191,.19],[.3077,.1902],[.2963,.1902],[.2848,.1901],[.2734,.19],[.262,.1898],[.2505,.1896],[.2391,.1895],[.2277,.1893],[.2162,.1891],[.2048,.189],[.1933,.1888],[.1819,.1887],[.1705,.1885],[.159,.1883],[.1476,.1883],[.1362,.1883],[.1247,.1887],[.1133,.1893],[.1019,.1898],[.0904,.19],[.079,.19],[.0675,.1899],[.0561,.1898],[.0447,.1896],[.0332,.1894],[.0218,.1893],[.0104,.1891],[-.0011,.189],[-.0125,.1888],[-.0239,.1887],[-.0354,.1885],[-.0468,.1884],[-.0583,.1885],[-.0697,.1888],[-.0811,.1891],[-.0926,.1891],[-.104,.1891],[-.1154,.1893],[-.1269,.1896],[-.1383,.1898],[-.1497,.1897],[-.1612,.1896],[-.1726,.1894],[-.1841,.1893],[-.1955,.1891],[-.2069,.189],[-.2184,.1889],[-.2298,.189],[-.2412,.1898],[-.2527,.192],[-.2641,.1961],[-.2755,.2008],[-.287,.2041],[-.2984,.2054],[-.3099,.2056],[-.3213,.2055],[-.3327,.2053],[-.3442,.2051],[-.3556,.205],[-.367,.2048],[-.3785,.2046],[-.3899,.2045],[-.4013,.2043],[-.4128,.2042],[-.4242,.204],[-.4357,.2038],[-.4471,.2036],[-.4585,.2035],[-.47,.2033],[-.4814,.2032],[-.4928,.203],[-.5043,.2028],[-.5157,.2027],[-.5271,.2025],[-.5386,.2023],[-.55,.2022],[-.5614,.202],[-.5729,.2018],[-.5843,.2017],[-.5958,.2015],[-.6072,.2014],[-.6186,.2012],[-.6301,.2011],[-.6415,.2009],[-.6529,.2007],[-.6644,.2006],[-.6758,.2004],[-.6872,.2003],[-.6987,.2001],[-.7101,.1999],[-.7216,.1998],[-.733,.1996],[-.7444,.1995],[-.7559,.1993],[-.7673,.1991],[-.7787,.199],[-.7902,.1988],[-.8016,.1987],[-.813,.1985],[-.8245,.1984],[-.8359,.1982],[-.8474,.198],[-.8588,.1979],[-.8702,.1977],[-.8817,.1976],[-.8931,.1974],[-.9045,.1973],[-.916,.1971],[-.9274,.197],[-.9388,.1968],[-.9503,.1966],[-.9617,.1965],[-.9732,.1963],[-.9846,.1962],[-.996,.196],[-1.0075,.1959],[-1.0189,.1957],[-1.0303,.1956],[-1.0418,.1954],[-1.0532,.1953],[-1.0646,.1951],[-1.0761,.195],[-1.0875,.1948],[-1.099,.1947],[-1.1104,.1945],[-1.1218,.1944],[-1.1333,.1942],[-1.1447,.1941],[-1.1485,.194]],at:[[0,0]],fins:[{side:-1,uv:[.8562,.9002,.971,1],x0:-.3011,x1:.0015,y0:.5517,y1:.3344,outline:[[.5517,.1865,.1865],[.546,.2012,.1865],[.5402,.2159,.1865],[.5345,.2306,.1865],[.5288,.2423,.1865],[.5231,.2541,.1865],[.5174,.2688,.1865],[.5117,.2834,.1865],[.5059,.2952,.1865],[.5002,.2982,.1865],[.4945,.2982,.1865],[.4888,.2982,.1866],[.4831,.2982,.1866],[.4773,.2982,.1866],[.4716,.2982,.1866],[.4659,.2982,.1867],[.4602,.2952,.1867],[.4545,.2834,.1868],[.4488,.2746,.1869],[.443,.2629,.1869],[.4373,.2541,.187],[.4316,.2453,.1871],[.4259,.2335,.1872],[.4202,.2247,.1873],[.4144,.2247,.1874],[.4087,.2247,.1875],[.403,.2247,.1877],[.3973,.2247,.1879],[.3916,.2247,.188],[.3859,.2247,.1882],[.3801,.2247,.1884],[.3744,.2247,.1886],[.3687,.2218,.1889],[.363,.213,.1891],[.3573,.2042,.1894],[.3515,.1953,.1897],[.3458,.1924,.19],[.3401,.1894,.1904],[.3363,.1894,.1906]]},{side:1,uv:[.8562,.7986,.9721,.8984],x0:-.0015,x1:.304,y0:.5517,y1:.3344,outline:[[.5517,.1865,.1865],[.546,.1953,.1865],[.5402,.2042,.1865],[.5345,.213,.1865],[.5288,.2247,.1865],[.5231,.2365,.1865],[.5174,.2482,.1865],[.5117,.26,.1865],[.5059,.2717,.1865],[.5002,.2805,.1865],[.4945,.2893,.1865],[.4888,.2982,.1866],[.4831,.3011,.1866],[.4773,.3011,.1866],[.4716,.3011,.1866],[.4659,.3011,.1867],[.4602,.3011,.1867],[.4545,.3011,.1868],[.4488,.3011,.1869],[.443,.2952,.1869],[.4373,.2834,.187],[.4316,.2746,.1871],[.4259,.2658,.1872],[.4202,.257,.1873],[.4144,.2453,.1874],[.4087,.2335,.1875],[.403,.2247,.1877],[.3973,.2218,.1879],[.3916,.2218,.188],[.3859,.2218,.1882],[.3801,.2247,.1884],[.3744,.2247,.1886],[.3687,.2247,.1889],[.363,.2247,.1891],[.3573,.2218,.1894],[.3515,.2159,.1897],[.3458,.2071,.19],[.3401,.1983,.1904],[.3363,.1924,.1906]]},{side:-1,uv:[.8562,.4002,.9911,.7968],x0:-.3253,x1:.0013,y0:-.2908,y1:-1.1542,outline:[[-.2908,.2038,.1986],[-.2965,.2065,.1992],[-.3022,.2092,.1995],[-.3079,.2146,.1997],[-.3137,.2146,.1997],[-.3194,.2173,.1998],[-.3251,.22,.1998],[-.3308,.2227,.1998],[-.3365,.2254,.1998],[-.3423,.2281,.1998],[-.348,.2308,.1998],[-.3537,.2335,.1998],[-.3594,.2389,.1998],[-.3651,.2416,.1998],[-.3708,.2443,.1998],[-.3766,.247,.1998],[-.3823,.2497,.1998],[-.388,.2524,.1998],[-.3937,.2551,.1998],[-.3994,.2578,.1998],[-.4052,.2605,.1998],[-.4109,.2632,.1998],[-.4166,.2659,.1998],[-.4223,.2686,.1998],[-.428,.2713,.1998],[-.4337,.274,.1998],[-.4395,.2767,.1998],[-.4452,.2794,.1998],[-.4509,.2821,.1998],[-.4566,.2848,.1998],[-.4623,.2875,.1998],[-.4681,.2902,.1998],[-.4738,.2929,.1998],[-.4795,.2956,.1998],[-.4852,.2983,.1998],[-.4909,.301,.1998],[-.4966,.3037,.1998],[-.5024,.3037,.1998],[-.5081,.3064,.1998],[-.5138,.3091,.1998],[-.5195,.3091,.1998],[-.5252,.3118,.1998],[-.531,.3118,.1998],[-.5367,.3145,.1998],[-.5424,.3145,.1998],[-.5481,.3145,.1998],[-.5538,.3145,.1998],[-.5595,.3145,.1998],[-.5653,.3172,.1998],[-.571,.3172,.1998],[-.5767,.3172,.1998],[-.5824,.3172,.1998],[-.5881,.3172,.1998],[-.5939,.3172,.1998],[-.5996,.3172,.1998],[-.6053,.3172,.1998],[-.611,.3172,.1998],[-.6167,.3172,.1998],[-.6224,.3199,.1998],[-.6282,.3199,.1998],[-.6339,.3199,.1998],[-.6396,.3199,.1998],[-.6453,.3199,.1998],[-.651,.3199,.1998],[-.6568,.3199,.1998],[-.6625,.3199,.1998],[-.6682,.3199,.1998],[-.6739,.3199,.1998],[-.6796,.3199,.1998],[-.6853,.3226,.1998],[-.6911,.3226,.1998],[-.6968,.3226,.1998],[-.7025,.3226,.1998],[-.7082,.3226,.1998],[-.7139,.3226,.1998],[-.7197,.3226,.1998],[-.7254,.3226,.1998],[-.7311,.3199,.1998],[-.7368,.3199,.1998],[-.7425,.3199,.1998],[-.7482,.3199,.1998],[-.754,.3199,.1998],[-.7597,.3172,.1998],[-.7654,.3172,.1998],[-.7711,.3172,.1998],[-.7768,.3172,.1998],[-.7826,.3172,.1998],[-.7883,.3145,.1998],[-.794,.3145,.1998],[-.7997,.3145,.1998],[-.8054,.3145,.1998],[-.8111,.3145,.1998],[-.8169,.3118,.1998],[-.8226,.3118,.1998],[-.8283,.3118,.1998],[-.834,.3118,.1998],[-.8397,.3091,.1998],[-.8454,.3091,.1998],[-.8512,.3091,.1998],[-.8569,.3091,.1998],[-.8626,.3091,.1998],[-.8683,.3091,.1998],[-.874,.3064,.1998],[-.8798,.3064,.1998],[-.8855,.3064,.1998],[-.8912,.3064,.1998],[-.8969,.3064,.1998],[-.9026,.3064,.1998],[-.9083,.3037,.1998],[-.9141,.3037,.1998],[-.9198,.3037,.1998],[-.9255,.3037,.1998],[-.9312,.3037,.1998],[-.9369,.3037,.1998],[-.9427,.3037,.1998],[-.9484,.301,.1998],[-.9541,.301,.1998],[-.9598,.301,.1998],[-.9655,.301,.1998],[-.9712,.301,.1998],[-.977,.2983,.1998],[-.9827,.2983,.1998],[-.9884,.2983,.1998],[-.9941,.2983,.1998],[-.9998,.2983,.1998],[-1.0056,.2956,.1998],[-1.0113,.2956,.1998],[-1.017,.2929,.1998],[-1.0227,.2902,.1998],[-1.0284,.2875,.1998],[-1.0341,.2848,.1998],[-1.0399,.2848,.1998],[-1.0456,.2848,.1998],[-1.0513,.2848,.1998],[-1.057,.2848,.1998],[-1.0627,.2848,.1998],[-1.0685,.2848,.1998],[-1.0742,.2848,.1998],[-1.0799,.2848,.1998],[-1.0856,.2848,.1998],[-1.0913,.2848,.1998],[-1.097,.2848,.1998],[-1.1028,.2848,.1998],[-1.1085,.2848,.1998],[-1.1142,.2848,.1998],[-1.1199,.2848,.1998],[-1.1256,.2848,.1998],[-1.1314,.2821,.1998],[-1.1371,.2821,.1998],[-1.1428,.2794,.1998],[-1.1485,.274,.1998],[-1.1523,.2686,.1998]]},{side:1,uv:[.8562,.0018,.99,.3984],x0:-.0013,x1:.3226,y0:-.2908,y1:-1.1542,outline:[[-.2908,.2038,.1986],[-.2965,.2065,.1992],[-.3022,.2092,.1995],[-.3079,.2119,.1997],[-.3137,.2146,.1997],[-.3194,.2173,.1998],[-.3251,.22,.1998],[-.3308,.2227,.1998],[-.3365,.2281,.1998],[-.3423,.2308,.1998],[-.348,.2335,.1998],[-.3537,.2362,.1998],[-.3594,.2389,.1998],[-.3651,.2416,.1998],[-.3708,.2443,.1998],[-.3766,.247,.1998],[-.3823,.2497,.1998],[-.388,.2524,.1998],[-.3937,.2551,.1998],[-.3994,.2578,.1998],[-.4052,.2605,.1998],[-.4109,.2632,.1998],[-.4166,.2659,.1998],[-.4223,.2686,.1998],[-.428,.2713,.1998],[-.4337,.274,.1998],[-.4395,.2767,.1998],[-.4452,.2794,.1998],[-.4509,.2821,.1998],[-.4566,.2848,.1998],[-.4623,.2875,.1998],[-.4681,.2902,.1998],[-.4738,.2929,.1998],[-.4795,.2956,.1998],[-.4852,.2983,.1998],[-.4909,.301,.1998],[-.4966,.3037,.1998],[-.5024,.3037,.1998],[-.5081,.3064,.1998],[-.5138,.3091,.1998],[-.5195,.3091,.1998],[-.5252,.3118,.1998],[-.531,.3118,.1998],[-.5367,.3118,.1998],[-.5424,.3145,.1998],[-.5481,.3145,.1998],[-.5538,.3145,.1998],[-.5595,.3145,.1998],[-.5653,.3145,.1998],[-.571,.3145,.1998],[-.5767,.3145,.1998],[-.5824,.3172,.1998],[-.5881,.3172,.1998],[-.5939,.3172,.1998],[-.5996,.3172,.1998],[-.6053,.3172,.1998],[-.611,.3172,.1998],[-.6167,.3172,.1998],[-.6224,.3172,.1998],[-.6282,.3172,.1998],[-.6339,.3172,.1998],[-.6396,.3172,.1998],[-.6453,.3172,.1998],[-.651,.3172,.1998],[-.6568,.3199,.1998],[-.6625,.3199,.1998],[-.6682,.3199,.1998],[-.6739,.3199,.1998],[-.6796,.3199,.1998],[-.6853,.3199,.1998],[-.6911,.3199,.1998],[-.6968,.3199,.1998],[-.7025,.3199,.1998],[-.7082,.3199,.1998],[-.7139,.3199,.1998],[-.7197,.3199,.1998],[-.7254,.3199,.1998],[-.7311,.3199,.1998],[-.7368,.3199,.1998],[-.7425,.3199,.1998],[-.7482,.3199,.1998],[-.754,.3172,.1998],[-.7597,.3172,.1998],[-.7654,.3172,.1998],[-.7711,.3172,.1998],[-.7768,.3172,.1998],[-.7826,.3145,.1998],[-.7883,.3145,.1998],[-.794,.3145,.1998],[-.7997,.3145,.1998],[-.8054,.3118,.1998],[-.8111,.3118,.1998],[-.8169,.3118,.1998],[-.8226,.3118,.1998],[-.8283,.3118,.1998],[-.834,.3091,.1998],[-.8397,.3091,.1998],[-.8454,.3091,.1998],[-.8512,.3091,.1998],[-.8569,.3064,.1998],[-.8626,.3064,.1998],[-.8683,.3064,.1998],[-.874,.3064,.1998],[-.8798,.3064,.1998],[-.8855,.3037,.1998],[-.8912,.3037,.1998],[-.8969,.3037,.1998],[-.9026,.3037,.1998],[-.9083,.3037,.1998],[-.9141,.3037,.1998],[-.9198,.3037,.1998],[-.9255,.301,.1998],[-.9312,.301,.1998],[-.9369,.301,.1998],[-.9427,.301,.1998],[-.9484,.301,.1998],[-.9541,.301,.1998],[-.9598,.2983,.1998],[-.9655,.2983,.1998],[-.9712,.2983,.1998],[-.977,.2983,.1998],[-.9827,.2983,.1998],[-.9884,.2983,.1998],[-.9941,.2956,.1998],[-.9998,.2956,.1998],[-1.0056,.2956,.1998],[-1.0113,.2929,.1998],[-1.017,.2902,.1998],[-1.0227,.2875,.1998],[-1.0284,.2875,.1998],[-1.0341,.2848,.1998],[-1.0399,.2848,.1998],[-1.0456,.2848,.1998],[-1.0513,.2848,.1998],[-1.057,.2848,.1998],[-1.0627,.2848,.1998],[-1.0685,.2848,.1998],[-1.0742,.2848,.1998],[-1.0799,.2848,.1998],[-1.0856,.2848,.1998],[-1.0913,.2848,.1998],[-1.097,.2848,.1998],[-1.1028,.2848,.1998],[-1.1085,.2848,.1998],[-1.1142,.2848,.1998],[-1.1199,.2848,.1998],[-1.1256,.2848,.1998],[-1.1314,.2821,.1998],[-1.1371,.2821,.1998],[-1.1428,.2794,.1998],[-1.1485,.2713,.1998],[-1.1523,.2659,.1998]]}],finsAround:2,finsFrom:null,engines:{ring:6,centre:!0,f:.3,colour:[80,79,78],profile:[[-1.1485,.2648],[-1.1523,.2595],[-1.1561,.2516],[-1.1599,.2463],[-1.1638,.241],[-1.1676,.2461],[-1.1714,.2487],[-1.1752,.2512],[-1.179,.2538],[-1.1828,.255],[-1.1866,.2576],[-1.1904,.2601],[-1.1943,.2614],[-1.1981,.2639],[-1.2019,.2652],[-1.2057,.2664],[-1.2095,.2689],[-1.2133,.2702],[-1.2171,.2714],[-1.2209,.2687],[-1.2248,.2543],[-1.2286,.1734],[-1.2324,.1773],[-1.2362,.1759],[-1.24,.1576]]}}],badge:{y:.9137,d:.2768,r:.1845},band:[.7422,.7611],head:{top:1.6,cut:1.0852,mean:.6111,r:.2159}},vulcan:{id:"vulcan",shape:"vulcan",atlas:{w:1160,h:1024,cap:[.9948,.9941,.9983,.998]},parts:[{name:"core",uv:[0,0,.6621,1],top:1.6,end:-1.0752,profile:[[1.6,.0147],[1.5884,.0337],[1.5767,.0482],[1.5651,.0614],[1.5535,.0738],[1.5418,.0854],[1.5302,.0963],[1.5186,.1066],[1.5069,.1166],[1.4953,.1261],[1.4837,.1351],[1.4721,.1436],[1.4604,.1518],[1.4488,.1595],[1.4372,.1668],[1.4255,.1735],[1.4139,.1798],[1.4023,.1856],[1.3906,.1911],[1.379,.1963],[1.3674,.2012],[1.3557,.2057],[1.3441,.2099],[1.3325,.2137],[1.3208,.2171],[1.3092,.2202],[1.2976,.2228],[1.286,.2252],[1.2743,.2273],[1.2627,.229],[1.2511,.2305],[1.2394,.2316],[1.2278,.2323],[1.2162,.2327],[1.2045,.2328],[1.1929,.2326],[1.1813,.2325],[1.1696,.2326],[1.158,.2325],[1.1464,.2325],[1.1347,.2326],[1.1231,.2327],[1.1115,.2326],[1.0998,.2322],[1.0882,.2317],[1.0766,.2315],[1.065,.2314],[1.0533,.2311],[1.0417,.2307],[1.0301,.2306],[1.0184,.2308],[1.0068,.2311],[.9952,.2312],[.9835,.2311],[.9719,.2309],[.9603,.2307],[.9486,.2304],[.937,.2298],[.9254,.2292],[.9137,.2289],[.9021,.2287],[.8905,.2287],[.8789,.2288],[.8672,.229],[.8556,.2289],[.844,.2285],[.8323,.2282],[.8207,.2279],[.8091,.2279],[.7974,.228],[.7858,.2278],[.7742,.2273],[.7625,.227],[.7509,.2266],[.7393,.2254],[.7276,.2226],[.716,.2181],[.7044,.2128],[.6928,.2072],[.6811,.2015],[.6695,.196],[.6579,.1907],[.6462,.1855],[.6346,.1806],[.623,.1765],[.6113,.1743],[.5997,.1747],[.5881,.1766],[.5764,.1791],[.5648,.1818],[.5532,.1846],[.5415,.1876],[.5299,.1906],[.5183,.1938],[.5066,.1969],[.495,.2],[.4834,.2031],[.4718,.2062],[.4601,.2088],[.4485,.2104],[.4369,.2108],[.4252,.2104],[.4136,.2102],[.402,.2102],[.3903,.2101],[.3787,.21],[.3671,.2099],[.3554,.2098],[.3438,.2097],[.3322,.2095],[.3205,.2094],[.3089,.2093],[.2973,.2093],[.2857,.2094],[.274,.2094],[.2624,.2091],[.2508,.2088],[.2391,.2086],[.2275,.2084],[.2159,.2083],[.2042,.2082],[.1926,.208],[.181,.2079],[.1693,.2078],[.1577,.2077],[.1461,.2075],[.1344,.2074],[.1228,.2073],[.1112,.2072],[.0995,.2071],[.0879,.2069],[.0763,.2068],[.0647,.2067],[.053,.2066],[.0414,.2065],[.0298,.2063],[.0181,.2062],[.0065,.2061],[-.0051,.206],[-.0168,.2059],[-.0284,.2057],[-.04,.2056],[-.0517,.2055],[-.0633,.2054],[-.0749,.2052],[-.0866,.2051],[-.0982,.205],[-.1098,.2049],[-.1214,.2048],[-.1331,.2046],[-.1447,.2045],[-.1563,.2044],[-.168,.2043],[-.1796,.2042],[-.1912,.2041],[-.2029,.2039],[-.2145,.2038],[-.2261,.2037],[-.2378,.2036],[-.2494,.2035],[-.261,.2033],[-.2727,.2032],[-.2843,.2031],[-.2959,.203],[-.3075,.2029],[-.3192,.2028],[-.3308,.2026],[-.3424,.2025],[-.3541,.2024],[-.3657,.2023],[-.3773,.2022],[-.389,.202],[-.4006,.2019],[-.4122,.2018],[-.4239,.2017],[-.4355,.2016],[-.4471,.2015],[-.4588,.2013],[-.4704,.2012],[-.482,.2011],[-.4937,.201],[-.5053,.2009],[-.5169,.2008],[-.5285,.2007],[-.5402,.2005],[-.5518,.2004],[-.5634,.2003],[-.5751,.2002],[-.5867,.2001],[-.5983,.2],[-.61,.1999],[-.6216,.1997],[-.6332,.1996],[-.6449,.1995],[-.6565,.1994],[-.6681,.1993],[-.6798,.1992],[-.6914,.1991],[-.703,.199],[-.7146,.1988],[-.7263,.1987],[-.7379,.1986],[-.7495,.1985],[-.7612,.1984],[-.7728,.1983],[-.7844,.1982],[-.7961,.1981],[-.8077,.1979],[-.8193,.1978],[-.831,.1977],[-.8426,.1976],[-.8542,.1975],[-.8659,.1974],[-.8775,.1973],[-.8891,.1972],[-.9008,.1971],[-.9124,.1969],[-.924,.1968],[-.9356,.1967],[-.9473,.1966],[-.9589,.1965],[-.9705,.1964],[-.9822,.1963],[-.9938,.1962],[-1.0054,.1961],[-1.0171,.196],[-1.0287,.1958],[-1.0403,.1957],[-1.052,.1956],[-1.0636,.1955],[-1.0752,.1954]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:2,centre:!1,f:.5,colour:[62,59,55],profile:[[-1.0752,.1556],[-1.0791,.1542],[-1.083,.1516],[-1.0869,.149],[-1.0907,.1464],[-1.0946,.1464],[-1.0985,.1464],[-1.1024,.1489],[-1.1062,.1489],[-1.1101,.1514],[-1.114,.1527],[-1.1179,.154],[-1.1217,.1565],[-1.1256,.159],[-1.1295,.159],[-1.1334,.1615],[-1.1373,.1628],[-1.1411,.164],[-1.145,.1653],[-1.1489,.1665],[-1.1528,.1691],[-1.1566,.169],[-1.1605,.1716],[-1.1644,.1715],[-1.1683,.1728],[-1.1722,.174],[-1.176,.1753],[-1.1799,.1765],[-1.1838,.1778],[-1.1877,.179],[-1.1915,.1803],[-1.1954,.1802],[-1.1993,.1827],[-1.2032,.1827],[-1.207,.184],[-1.2109,.1852],[-1.2148,.1852],[-1.2187,.1864],[-1.2226,.1864],[-1.2264,.1863],[-1.2303,.1812],[-1.2342,.1684],[-1.2381,.1416]]}},{name:"booster",uv:[.6621,.3447,.9931,1],top:.2159,end:-1.083,profile:[[.2159,.0039],[.2042,.011],[.1926,.0173],[.181,.0238],[.1693,.0299],[.1577,.0355],[.1461,.041],[.1344,.0465],[.1228,.0521],[.1112,.0579],[.0995,.0635],[.0879,.069],[.0763,.0741],[.0647,.0782],[.053,.0806],[.0414,.0813],[.0298,.0814],[.0181,.0815],[.0065,.0818],[-.0051,.0826],[-.0168,.0834],[-.0284,.0838],[-.04,.0839],[-.0517,.0838],[-.0633,.0838],[-.0749,.0837],[-.0866,.0837],[-.0982,.0838],[-.1098,.0839],[-.1214,.0837],[-.1331,.0835],[-.1447,.0834],[-.1563,.0834],[-.168,.0833],[-.1796,.0833],[-.1912,.0832],[-.2029,.0832],[-.2145,.0831],[-.2261,.0831],[-.2378,.0831],[-.2494,.083],[-.261,.0829],[-.2727,.0829],[-.2843,.0829],[-.2959,.0828],[-.3075,.0828],[-.3192,.0829],[-.3308,.083],[-.3424,.0828],[-.3541,.0826],[-.3657,.0825],[-.3773,.0825],[-.389,.0824],[-.4006,.0824],[-.4122,.0823],[-.4239,.0823],[-.4355,.0822],[-.4471,.0822],[-.4588,.0821],[-.4704,.0821],[-.482,.0821],[-.4937,.0821],[-.5053,.0821],[-.5169,.0822],[-.5285,.0821],[-.5402,.0819],[-.5518,.0818],[-.5634,.0817],[-.5751,.0817],[-.5867,.0816],[-.5983,.0816],[-.61,.0815],[-.6216,.0815],[-.6332,.0814],[-.6449,.0814],[-.6565,.0813],[-.6681,.0813],[-.6798,.0813],[-.6914,.0813],[-.703,.0813],[-.7146,.0812],[-.7263,.0811],[-.7379,.081],[-.7495,.081],[-.7612,.0809],[-.7728,.0809],[-.7844,.0808],[-.7961,.0808],[-.8077,.0807],[-.8193,.0807],[-.831,.0806],[-.8426,.0806],[-.8542,.0806],[-.8659,.0806],[-.8775,.0807],[-.8891,.0808],[-.9008,.0808],[-.9124,.0805],[-.924,.0803],[-.9356,.0803],[-.9473,.0802],[-.9589,.0801],[-.9705,.0801],[-.9822,.0801],[-.9938,.08],[-1.0054,.08],[-1.0171,.0799],[-1.0287,.0798],[-1.0403,.0792],[-1.052,.0775],[-1.0636,.0749],[-1.0752,.0726],[-1.083,.0715]],at:[[-1.5708,.3099],[1.5708,.3099]],fins:[],finsAround:0,finsFrom:null,engines:{ring:0,centre:!0,f:1,colour:[88,83,79],profile:[[-1.083,.0694],[-1.0869,.0668],[-1.0907,.0668],[-1.0946,.0668],[-1.0985,.0642],[-1.1024,.0642],[-1.1062,.0616],[-1.1101,.0539],[-1.114,.0462],[-1.1179,.0462],[-1.1217,.0462],[-1.1256,.0487],[-1.1295,.0487],[-1.1334,.0513],[-1.1373,.0513],[-1.1411,.0538],[-1.145,.0538],[-1.1489,.0564],[-1.1528,.0564],[-1.1566,.0589],[-1.1605,.0589],[-1.1644,.0614],[-1.1683,.0614],[-1.1722,.064],[-1.176,.064],[-1.1799,.0665],[-1.1838,.0665],[-1.1877,.069],[-1.1915,.069],[-1.1954,.0716],[-1.1993,.0716],[-1.2032,.0741],[-1.207,.0741],[-1.2109,.0664],[-1.2148,.0281]]}}],badge:{y:.9137,d:.3434,r:.2289},band:[.7089,.7278],head:{top:1.6,cut:1.1185,mean:.8006,r:.2444}},cz2f:{id:"long-march-2f",shape:"cz2f",atlas:{w:1160,h:1024,cap:[.9948,.9941,.9983,.998]},parts:[{name:"core",uv:[0,0,.6621,1],top:1.5981,end:-1.1021,profile:[[1.5981,.0102],[1.5864,.0199],[1.5747,.0267],[1.5631,.031],[1.5514,.0329],[1.5398,.0333],[1.5281,.0336],[1.5165,.0345],[1.5048,.0363],[1.4932,.0387],[1.4815,.0404],[1.4698,.0395],[1.4582,.0379],[1.4465,.0378],[1.4349,.0389],[1.4232,.0405],[1.4116,.0435],[1.3999,.0497],[1.3883,.0568],[1.3766,.0581],[1.365,.0526],[1.3533,.047],[1.3416,.0455],[1.33,.0466],[1.3183,.0486],[1.3067,.0508],[1.295,.0533],[1.2834,.0559],[1.2717,.0587],[1.2601,.0614],[1.2484,.064],[1.2367,.0668],[1.2251,.07],[1.2134,.074],[1.2018,.0791],[1.1901,.084],[1.1785,.0891],[1.1668,.0963],[1.1552,.1056],[1.1435,.1157],[1.1318,.1259],[1.1202,.1358],[1.1085,.1455],[1.0969,.1551],[1.0852,.1644],[1.0736,.1734],[1.0619,.1818],[1.0503,.1889],[1.0386,.1945],[1.0269,.1982],[1.0153,.1999],[1.0036,.2004],[.992,.2006],[.9803,.201],[.9687,.2016],[.957,.202],[.9454,.202],[.9337,.202],[.9221,.2021],[.9104,.2028],[.8987,.2042],[.8871,.2056],[.8754,.2056],[.8638,.2041],[.8521,.2024],[.8405,.2015],[.8288,.2012],[.8172,.2011],[.8055,.2012],[.7938,.2016],[.7822,.2024],[.7705,.2026],[.7589,.2016],[.7472,.1997],[.7356,.1962],[.7239,.1908],[.7123,.1844],[.7006,.1786],[.6889,.175],[.6773,.1736],[.6656,.1731],[.654,.1728],[.6423,.1731],[.6307,.1738],[.619,.1735],[.6074,.1717],[.5957,.1696],[.584,.1682],[.5724,.1675],[.5607,.1676],[.5491,.1681],[.5374,.1686],[.5258,.1688],[.5141,.1687],[.5025,.1686],[.4908,.1686],[.4792,.1687],[.4675,.1694],[.4558,.1707],[.4442,.172],[.4325,.1724],[.4209,.1718],[.4092,.1709],[.3976,.1703],[.3859,.1701],[.3743,.1704],[.3626,.171],[.3509,.1715],[.3393,.1716],[.3276,.1716],[.316,.1715],[.3043,.1716],[.2927,.1722],[.281,.1732],[.2694,.174],[.2577,.1738],[.246,.1733],[.2344,.173],[.2227,.1731],[.2111,.1736],[.1994,.174],[.1878,.1737],[.1761,.1728],[.1645,.1719],[.1528,.1716],[.1411,.1719],[.1295,.1721],[.1178,.172],[.1062,.1715],[.0945,.1712],[.0829,.1713],[.0712,.1713],[.0596,.1713],[.0479,.1715],[.0363,.1717],[.0246,.1717],[.0129,.1716],[.0013,.1716],[-.0104,.1717],[-.022,.1719],[-.0337,.1721],[-.0453,.1718],[-.057,.1714],[-.0686,.1711],[-.0803,.1711],[-.092,.171],[-.1036,.1709],[-.1153,.1708],[-.1269,.1707],[-.1386,.1707],[-.1502,.1706],[-.1619,.1705],[-.1735,.1705],[-.1852,.1704],[-.1969,.1703],[-.2085,.1703],[-.2202,.1702],[-.2318,.1701],[-.2435,.1701],[-.2551,.17],[-.2668,.1699],[-.2784,.1698],[-.2901,.1698],[-.3018,.1697],[-.3134,.1696],[-.3251,.1696],[-.3367,.1695],[-.3484,.1694],[-.36,.1694],[-.3717,.1693],[-.3833,.1692],[-.395,.1692],[-.4066,.1691],[-.4183,.169],[-.43,.1689],[-.4416,.1689],[-.4533,.1688],[-.4649,.1687],[-.4766,.1687],[-.4882,.1686],[-.4999,.1685],[-.5115,.1684],[-.5232,.1684],[-.5349,.1683],[-.5465,.1682],[-.5582,.1682],[-.5698,.1681],[-.5815,.168],[-.5931,.168],[-.6048,.1679],[-.6164,.1678],[-.6281,.1678],[-.6398,.1677],[-.6514,.1677],[-.6631,.1676],[-.6747,.1675],[-.6864,.1674],[-.698,.1674],[-.7097,.1673],[-.7213,.1672],[-.733,.1671],[-.7447,.1671],[-.7563,.167],[-.768,.1669],[-.7796,.1669],[-.7913,.1668],[-.8029,.1667],[-.8146,.1667],[-.8262,.1666],[-.8379,.1665],[-.8495,.1665],[-.8612,.1664],[-.8729,.1663],[-.8845,.1663],[-.8962,.1662],[-.9078,.1661],[-.9195,.1661],[-.9311,.166],[-.9428,.1659],[-.9544,.1659],[-.9661,.1658],[-.9778,.1657],[-.9894,.1657],[-1.0011,.1656],[-1.0127,.1655],[-1.0244,.1655],[-1.036,.1654],[-1.0477,.1654],[-1.0593,.1653],[-1.071,.1652],[-1.0827,.1652],[-1.0943,.1651],[-1.1021,.165]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:4,centre:!1,f:.42,colour:[76,74,72],profile:[[-1.1021,.3699],[-1.106,.3661],[-1.1098,.2617],[-1.1137,.3565],[-1.1176,.2597],[-1.1215,.2616],[-1.1254,.1516],[-1.1293,.1308],[-1.1332,.1194],[-1.137,.1213],[-1.1409,.1212],[-1.1448,.1174],[-1.1487,.1098],[-1.1526,.1041],[-1.1565,.0985],[-1.1604,.0965],[-1.1642,.089],[-1.1681,.0908],[-1.172,.0927],[-1.1759,.0965],[-1.1798,.1003],[-1.1837,.1021],[-1.1876,.104],[-1.1914,.1078],[-1.1953,.1097],[-1.1992,.1134],[-1.2031,.1153],[-1.207,.2344],[-1.2109,.1191],[-1.2147,.1228],[-1.2186,.1228],[-1.2225,.1266],[-1.2264,.1303],[-1.2303,.1265],[-1.2342,.1171],[-1.2381,.0869]]}},{name:"booster",uv:[.6621,.5381,.9931,1],top:-.1852,end:-1.1021,profile:[[-.1852,.0175],[-.1969,.044],[-.2085,.0547],[-.2202,.0633],[-.2318,.0716],[-.2435,.0795],[-.2551,.0873],[-.2668,.0951],[-.2784,.1029],[-.2901,.1109],[-.3018,.1189],[-.3134,.1266],[-.3251,.1336],[-.3367,.1393],[-.3484,.1427],[-.36,.1441],[-.3717,.1444],[-.3833,.1443],[-.395,.144],[-.4066,.1438],[-.4183,.1438],[-.43,.1437],[-.4416,.1437],[-.4533,.1436],[-.4649,.1435],[-.4766,.1435],[-.4882,.1434],[-.4999,.1434],[-.5115,.1437],[-.5232,.1444],[-.5349,.1454],[-.5465,.1462],[-.5582,.1467],[-.5698,.1468],[-.5815,.1468],[-.5931,.1467],[-.6048,.1467],[-.6164,.1466],[-.6281,.1466],[-.6398,.1465],[-.6514,.1464],[-.6631,.1464],[-.6747,.1463],[-.6864,.1463],[-.698,.1462],[-.7097,.1462],[-.7213,.1461],[-.733,.146],[-.7447,.146],[-.7563,.1462],[-.768,.1466],[-.7796,.1467],[-.7913,.1466],[-.8029,.1472],[-.8146,.1483],[-.8262,.149],[-.8379,.1493],[-.8495,.1492],[-.8612,.1492],[-.8729,.1491],[-.8845,.1491],[-.8962,.149],[-.9078,.149],[-.9195,.1489],[-.9311,.1489],[-.9428,.1489],[-.9544,.1492],[-.9661,.1502],[-.9778,.1514],[-.9894,.1521],[-1.0011,.1523],[-1.0127,.1522],[-1.0244,.1521],[-1.036,.1521],[-1.0477,.152],[-1.0593,.151],[-1.071,.1467],[-1.0827,.1367],[-1.0943,.1241],[-1.1021,.117]],at:[[.7854,.401],[2.3562,.401],[3.927,.401],[5.4978,.401]],fins:[],finsAround:0,finsFrom:null,engines:{ring:0,centre:!0,f:1,colour:[76,73,70],profile:[[-1.1021,.1024],[-1.106,.0986],[-1.1098,.0948],[-1.1137,.0834],[-1.1176,.0834],[-1.1215,.0834],[-1.1254,.091],[-1.1293,.091],[-1.1332,.0834],[-1.137,.0872],[-1.1409,.0909],[-1.1448,.0909],[-1.1487,.0947],[-1.1526,.0985],[-1.1565,.1022],[-1.1604,.1022],[-1.1642,.106],[-1.1681,.1098],[-1.172,.1098],[-1.1759,.1135],[-1.1798,.1135],[-1.1837,.1173],[-1.1876,.1173],[-1.1914,.121],[-1.1953,.1248],[-1.1992,.1248],[-1.2031,.1172],[-1.207,.0869]]}}],badge:{y:.9137,d:.3036,r:.2024},band:[.7287,.7477],head:{top:1.1835,cut:1.0702,mean:.8821,r:.2161}},cz5:{id:"long-march-5",shape:"cz5",atlas:{w:1255,h:1024,cap:[.9952,.9941,.9984,.998]},parts:[{name:"core",uv:[0,0,.612,1],top:1.6,end:-1.0981,profile:[[1.6,.0202],[1.5882,.049],[1.5763,.0688],[1.5645,.0849],[1.5527,.0991],[1.5409,.1121],[1.529,.1238],[1.5172,.1345],[1.5054,.1444],[1.4936,.1537],[1.4817,.1625],[1.4699,.1705],[1.4581,.178],[1.4463,.1849],[1.4344,.1914],[1.4226,.1974],[1.4108,.2032],[1.399,.2087],[1.3871,.2138],[1.3753,.2184],[1.3635,.2226],[1.3517,.2265],[1.3398,.2299],[1.328,.233],[1.3162,.2358],[1.3044,.2382],[1.2925,.2403],[1.2807,.2419],[1.2689,.2431],[1.2571,.2438],[1.2452,.2441],[1.2334,.2438],[1.2216,.2435],[1.2098,.2432],[1.1979,.2431],[1.1861,.2429],[1.1743,.2428],[1.1625,.2427],[1.1506,.2429],[1.1388,.2432],[1.127,.2434],[1.1152,.2434],[1.1033,.2433],[1.0915,.2431],[1.0797,.243],[1.0679,.2428],[1.056,.2427],[1.0442,.2425],[1.0324,.2424],[1.0206,.2422],[1.0087,.2421],[.9969,.242],[.9851,.2419],[.9733,.2422],[.9614,.2425],[.9496,.2429],[.9378,.2433],[.926,.2436],[.9141,.2436],[.9023,.2435],[.8905,.2434],[.8787,.2433],[.8668,.2431],[.855,.243],[.8432,.2428],[.8314,.2427],[.8195,.2426],[.8077,.2425],[.7959,.2417],[.7841,.2397],[.7722,.2367],[.7604,.2331],[.7486,.2294],[.7368,.2257],[.7249,.2223],[.7131,.2192],[.7013,.2166],[.6895,.2143],[.6776,.2123],[.6658,.2109],[.654,.2104],[.6422,.2102],[.6303,.2103],[.6185,.2105],[.6067,.2102],[.5949,.2098],[.583,.2095],[.5712,.2094],[.5594,.2092],[.5476,.2091],[.5357,.209],[.5239,.2089],[.5121,.2087],[.5003,.2086],[.4884,.2085],[.4766,.2084],[.4648,.2083],[.453,.2081],[.4411,.208],[.4293,.2079],[.4175,.2078],[.4057,.2076],[.3938,.2075],[.382,.2074],[.3702,.2073],[.3584,.2072],[.3465,.207],[.3347,.2069],[.3229,.2068],[.3111,.2067],[.2992,.2065],[.2874,.2064],[.2756,.2063],[.2638,.2062],[.2519,.2061],[.2401,.2059],[.2283,.2058],[.2165,.2057],[.2046,.2056],[.1928,.2054],[.181,.2053],[.1692,.2052],[.1573,.2051],[.1455,.205],[.1337,.2048],[.1219,.2047],[.11,.2046],[.0982,.2045],[.0864,.2044],[.0746,.2042],[.0627,.2041],[.0509,.204],[.0391,.2039],[.0273,.2038],[.0154,.2037],[.0036,.2036],[-.0082,.2034],[-.02,.2033],[-.0319,.2032],[-.0437,.2031],[-.0555,.2029],[-.0673,.2028],[-.0792,.2027],[-.091,.2026],[-.1028,.2025],[-.1146,.2024],[-.1265,.2023],[-.1383,.2021],[-.1501,.202],[-.1619,.2019],[-.1738,.2018],[-.1856,.2017],[-.1974,.2015],[-.2092,.2014],[-.2211,.2013],[-.2329,.2012],[-.2447,.2011],[-.2565,.201],[-.2684,.2009],[-.2802,.2007],[-.292,.2006],[-.3038,.2005],[-.3157,.2004],[-.3275,.2003],[-.3393,.2002],[-.3511,.2001],[-.363,.1999],[-.3748,.1998],[-.3866,.1997],[-.3984,.1996],[-.4103,.1995],[-.4221,.1994],[-.4339,.1993],[-.4457,.1991],[-.4576,.199],[-.4694,.1989],[-.4812,.1988],[-.493,.1987],[-.5049,.1986],[-.5167,.1985],[-.5285,.1984],[-.5403,.1982],[-.5522,.1981],[-.564,.198],[-.5758,.1979],[-.5876,.1978],[-.5995,.1977],[-.6113,.1976],[-.6231,.1975],[-.6349,.1974],[-.6468,.1973],[-.6586,.1971],[-.6704,.197],[-.6822,.1969],[-.6941,.1968],[-.7059,.1967],[-.7177,.1966],[-.7295,.1965],[-.7414,.1964],[-.7532,.1963],[-.765,.1962],[-.7768,.196],[-.7887,.1959],[-.8005,.1958],[-.8123,.1957],[-.8241,.1956],[-.836,.1955],[-.8478,.1954],[-.8596,.1953],[-.8715,.1952],[-.8833,.1951],[-.8951,.1949],[-.9069,.1948],[-.9188,.1947],[-.9306,.1946],[-.9424,.1945],[-.9542,.1944],[-.9661,.1943],[-.9779,.1942],[-.9897,.1941],[-1.0015,.194],[-1.0134,.1939],[-1.0252,.1938],[-1.037,.1936],[-1.0488,.1935],[-1.0607,.1934],[-1.0725,.1933],[-1.0843,.1932],[-1.0961,.1931]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:2,centre:!1,f:.5,colour:[44,40,35],profile:[[-1.0981,.178],[-1.102,.1792],[-1.106,.1804],[-1.1099,.1829],[-1.1139,.1841],[-1.1178,.1854],[-1.1217,.1878],[-1.1257,.1903],[-1.1296,.1903],[-1.1336,.1928],[-1.1375,.1927],[-1.1415,.1952],[-1.1454,.1977],[-1.1493,.1977],[-1.1533,.1989],[-1.1572,.2001],[-1.1612,.2001],[-1.1651,.2026],[-1.169,.2025],[-1.173,.2037],[-1.1769,.205],[-1.1809,.2049],[-1.1848,.2061],[-1.1888,.2074],[-1.1927,.2086],[-1.1966,.2085],[-1.2006,.211],[-1.2045,.211],[-1.2085,.2109],[-1.2124,.2122],[-1.2163,.2134],[-1.2203,.2133],[-1.2242,.2133],[-1.2282,.2133],[-1.2321,.2082],[-1.2361,.1906],[-1.24,.1379]]}},{name:"booster",uv:[.612,.25,.9179,1],top:.4135,end:-1.0981,profile:[[.4135,.0016],[.4017,.009],[.3899,.0182],[.3781,.0264],[.3662,.0345],[.3544,.0426],[.3426,.0507],[.3308,.0587],[.3189,.0664],[.3071,.0742],[.2953,.0822],[.2835,.0903],[.2716,.0983],[.2598,.1064],[.248,.1142],[.2362,.1214],[.2243,.1275],[.2125,.1321],[.2007,.1346],[.1889,.1356],[.177,.1355],[.1652,.1345],[.1534,.1334],[.1416,.1328],[.1297,.1325],[.1179,.1325],[.1061,.1324],[.0943,.1323],[.0824,.1322],[.0706,.1322],[.0588,.1325],[.047,.1333],[.0351,.134],[.0233,.1344],[.0115,.1344],[-3e-4,.1344],[-.0122,.1343],[-.024,.1345],[-.0358,.1352],[-.0476,.136],[-.0595,.1364],[-.0713,.1365],[-.0831,.1366],[-.0949,.1368],[-.1068,.137],[-.1186,.1369],[-.1304,.1369],[-.1422,.1375],[-.1541,.1381],[-.1659,.1384],[-.1777,.1385],[-.1895,.1384],[-.2014,.1383],[-.2132,.1383],[-.225,.1384],[-.2368,.1389],[-.2487,.1397],[-.2605,.1402],[-.2723,.1404],[-.2841,.1403],[-.296,.1403],[-.3078,.1402],[-.3196,.1402],[-.3314,.1405],[-.3433,.1412],[-.3551,.1419],[-.3669,.1423],[-.3787,.1423],[-.3906,.1422],[-.4024,.1422],[-.4142,.1421],[-.426,.1421],[-.4379,.1425],[-.4497,.1432],[-.4615,.1439],[-.4733,.1442],[-.4852,.1442],[-.497,.1441],[-.5088,.144],[-.5206,.144],[-.5325,.144],[-.5443,.1443],[-.5561,.1449],[-.5679,.1457],[-.5798,.146],[-.5916,.146],[-.6034,.146],[-.6152,.1459],[-.6271,.1458],[-.6389,.1458],[-.6507,.1459],[-.6625,.1464],[-.6744,.1471],[-.6862,.1477],[-.698,.1479],[-.7098,.1478],[-.7217,.1478],[-.7335,.148],[-.7453,.1486],[-.7571,.1494],[-.769,.1498],[-.7808,.1499],[-.7926,.1498],[-.8044,.1497],[-.8163,.1496],[-.8281,.1496],[-.8399,.1498],[-.8517,.1504],[-.8636,.1517],[-.8754,.1537],[-.8872,.1562],[-.899,.1592],[-.9109,.1625],[-.9227,.1659],[-.9345,.1692],[-.9463,.1724],[-.9582,.1752],[-.97,.1775],[-.9818,.1791],[-.9936,.1799],[-1.0055,.1798],[-1.0173,.1785],[-1.0291,.176],[-1.0409,.172],[-1.0528,.1664],[-1.0646,.1592],[-1.0764,.1512],[-1.0882,.1438],[-1.0961,.14]],at:[[1.0297,.5171],[2.6005,.5171],[-1.0297,.5171],[-2.6005,.5171]],fins:[{side:-1,uv:[.9179,.8867,.9936,1],x0:-.24,x1:.0013,y0:-.8577,y1:-1.0863,outline:[[-.8577,.1562,.1502],[-.8636,.1587,.1509],[-.8695,.1613,.1519],[-.8754,.1638,.153],[-.8813,.1689,.1542],[-.8872,.1714,.1556],[-.8931,.1739,.1571],[-.899,.179,.1587],[-.905,.1815,.1603],[-.9109,.1841,.162],[-.9168,.1892,.1638],[-.9227,.1917,.1655],[-.9286,.1943,.1672],[-.9345,.1968,.1689],[-.9404,.2019,.1706],[-.9463,.2044,.1722],[-.9523,.2069,.1737],[-.9582,.212,.1751],[-.9641,.2146,.1763],[-.97,.2171,.1775],[-.9759,.2196,.1784],[-.9818,.2247,.1792],[-.9877,.2273,.1798],[-.9936,.2298,.1801],[-.9996,.2349,.1802],[-1.0055,.2374,.1801],[-1.0114,.2374,.1796],[-1.0173,.2374,.1789],[-1.0232,.2374,.1778],[-1.0291,.2374,.1764],[-1.035,.2374,.1747],[-1.0409,.2374,.1725],[-1.0469,.2374,.17],[-1.0528,.2374,.167],[-1.0587,.2374,.1636],[-1.0646,.2374,.1599],[-1.0705,.2374,.1559],[-1.0764,.2044,.1519],[-1.0823,.1511,.148],[-1.0843,.146,.1468]]}],finsAround:2,finsFrom:null,engines:{ring:2,centre:!1,f:.5,colour:[60,59,58],profile:[[-1.0981,.13],[-1.102,.1274],[-1.106,.1299],[-1.1099,.1324],[-1.1139,.1324],[-1.1178,.1248],[-1.1217,.1248],[-1.1257,.1273],[-1.1296,.1298],[-1.1336,.1323],[-1.1375,.1348],[-1.1415,.1373],[-1.1454,.1398],[-1.1493,.1398],[-1.1533,.1422],[-1.1572,.1447],[-1.1612,.1447],[-1.1651,.1472],[-1.169,.1497],[-1.173,.1497],[-1.1769,.1522],[-1.1809,.1521],[-1.1848,.1546],[-1.1888,.1546],[-1.1927,.1571],[-1.1966,.157],[-1.2006,.1595],[-1.2045,.1595],[-1.2085,.1595],[-1.2124,.1619],[-1.2163,.1619],[-1.2203,.1569],[-1.2242,.1343]]}}],badge:{y:.9137,d:.3654,r:.2436},band:[.6978,.7168],head:{top:1.6,cut:1.1295,mean:.7207,r:.2563}},cz3b:{id:"long-march-3b",shape:"cz3b",atlas:{w:1237,h:1024,cap:[.9951,.9941,.9984,.998]},parts:[{name:"core",uv:[0,0,.6209,1],top:1.6,end:-1.2151,profile:[[1.6,.0174],[1.5885,.0445],[1.577,.0633],[1.5656,.0779],[1.5541,.0909],[1.5426,.1025],[1.5311,.1132],[1.5196,.123],[1.5081,.132],[1.4967,.1404],[1.4852,.1483],[1.4737,.1559],[1.4622,.1632],[1.4507,.1703],[1.4392,.1771],[1.4278,.1835],[1.4163,.1897],[1.4048,.1958],[1.3933,.2018],[1.3818,.2076],[1.3704,.2131],[1.3589,.2183],[1.3474,.2234],[1.3359,.2283],[1.3244,.2329],[1.3129,.2372],[1.3015,.241],[1.29,.2443],[1.2785,.2466],[1.267,.2478],[1.2555,.2481],[1.244,.2481],[1.2326,.2481],[1.2211,.248],[1.2096,.2479],[1.1981,.2478],[1.1866,.2477],[1.1751,.2476],[1.1637,.2475],[1.1522,.2474],[1.1407,.2474],[1.1292,.2473],[1.1177,.2472],[1.1063,.2471],[1.0948,.2471],[1.0833,.2473],[1.0718,.2481],[1.0603,.2489],[1.0488,.2493],[1.0374,.2489],[1.0259,.2484],[1.0144,.248],[1.0029,.2477],[.9914,.2466],[.9799,.2438],[.9685,.2389],[.957,.2325],[.9455,.2257],[.934,.2189],[.9225,.2123],[.9111,.2059],[.8996,.1994],[.8881,.1928],[.8766,.1863],[.8651,.1804],[.8536,.1756],[.8422,.1725],[.8307,.1715],[.8192,.1724],[.8077,.1746],[.7962,.1766],[.7847,.1777],[.7733,.1776],[.7618,.1767],[.7503,.1753],[.7388,.174],[.7273,.1734],[.7158,.1731],[.7044,.1731],[.6929,.1731],[.6814,.1734],[.6699,.1738],[.6584,.174],[.647,.1742],[.6355,.1742],[.624,.1742],[.6125,.1741],[.601,.174],[.5895,.174],[.5781,.1739],[.5666,.1738],[.5551,.1738],[.5436,.1737],[.5321,.1737],[.5206,.1736],[.5092,.1735],[.4977,.1735],[.4862,.1734],[.4747,.1734],[.4632,.1733],[.4518,.1733],[.4403,.1733],[.4288,.1737],[.4173,.1746],[.4058,.1757],[.3943,.1764],[.3829,.176],[.3714,.1748],[.3599,.1736],[.3484,.1729],[.3369,.1727],[.3254,.1726],[.314,.1725],[.3025,.1725],[.291,.1724],[.2795,.1723],[.268,.1723],[.2565,.1724],[.2451,.1728],[.2336,.1732],[.2221,.1735],[.2106,.1735],[.1991,.1734],[.1877,.1734],[.1762,.1734],[.1647,.1733],[.1532,.1733],[.1417,.1734],[.1302,.1737],[.1188,.1741],[.1073,.1743],[.0958,.1743],[.0843,.1741],[.0728,.1741],[.0613,.1742],[.0499,.1742],[.0384,.1743],[.0269,.1746],[.0154,.1751],[.0039,.1751],[-.0075,.1745],[-.019,.1735],[-.0305,.1727],[-.042,.1719],[-.0535,.1712],[-.065,.1705],[-.0764,.1699],[-.0879,.1693],[-.0994,.1687],[-.1109,.1682],[-.1224,.1677],[-.1339,.1673],[-.1453,.1669],[-.1568,.1665],[-.1683,.1661],[-.1798,.1658],[-.1913,.1654],[-.2027,.1652],[-.2142,.1649],[-.2257,.1647],[-.2372,.1645],[-.2487,.1643],[-.2602,.1641],[-.2716,.164],[-.2831,.1639],[-.2946,.1638],[-.3061,.1637],[-.3176,.1637],[-.3291,.1637],[-.3405,.1637],[-.352,.1637],[-.3635,.1637],[-.375,.1637],[-.3865,.1638],[-.398,.1639],[-.4094,.164],[-.4209,.1641],[-.4324,.1642],[-.4439,.1643],[-.4554,.1645],[-.4668,.1646],[-.4783,.1648],[-.4898,.165],[-.5013,.1652],[-.5128,.1653],[-.5243,.1656],[-.5357,.1658],[-.5472,.166],[-.5587,.1662],[-.5702,.1664],[-.5817,.1666],[-.5932,.1669],[-.6046,.1671],[-.6161,.1673],[-.6276,.1676],[-.6391,.1678],[-.6506,.1681],[-.662,.1683],[-.6735,.1685],[-.685,.1688],[-.6965,.169],[-.708,.1692],[-.7195,.1694],[-.7309,.1697],[-.7424,.1699],[-.7539,.1701],[-.7654,.1703],[-.7769,.1705],[-.7884,.1707],[-.7998,.1708],[-.8113,.171],[-.8228,.1712],[-.8343,.1713],[-.8458,.1715],[-.8573,.1716],[-.8687,.1717],[-.8802,.1718],[-.8917,.1719],[-.9032,.1719],[-.9147,.172],[-.9261,.172],[-.9376,.172],[-.9491,.172],[-.9606,.172],[-.9721,.172],[-.9836,.1719],[-.995,.1718],[-1.0065,.1715],[-1.018,.171],[-1.0295,.1704],[-1.041,.1701],[-1.0525,.1709],[-1.0639,.1729],[-1.0754,.1758],[-1.0869,.1786],[-1.0984,.1792],[-1.1099,.1746],[-1.1213,.1659],[-1.1328,.1608],[-1.1443,.1637],[-1.1558,.1708],[-1.1673,.1781],[-1.1788,.1843],[-1.1902,.1893],[-1.2017,.1929],[-1.2132,.1951]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:4,centre:!1,f:.45,colour:[46,44,42],profile:[[-1.2151,.1986],[-1.2189,.2],[-1.2228,.2],[-1.2266,.2014],[-1.2304,.197],[-1.2343,.1868],[-1.2381,.1649]]}},{name:"booster",uv:[.6209,.4502,.9313,1],top:-.0363,end:-1.1118,profile:[[-.0363,.0057],[-.0477,.0241],[-.0592,.0337],[-.0707,.0416],[-.0822,.0486],[-.0937,.0552],[-.1051,.0617],[-.1166,.0681],[-.1281,.0747],[-.1396,.0814],[-.1511,.0881],[-.1626,.0944],[-.174,.0998],[-.1855,.1037],[-.197,.1058],[-.2085,.1066],[-.22,.1067],[-.2315,.1067],[-.2429,.1066],[-.2544,.1068],[-.2659,.1073],[-.2774,.1083],[-.2889,.1091],[-.3004,.1094],[-.3118,.1094],[-.3233,.1094],[-.3348,.1093],[-.3463,.1093],[-.3578,.1092],[-.3692,.1092],[-.3807,.1092],[-.3922,.1092],[-.4037,.1091],[-.4152,.1091],[-.4267,.109],[-.4381,.109],[-.4496,.109],[-.4611,.1089],[-.4726,.1089],[-.4841,.1088],[-.4956,.1088],[-.507,.1088],[-.5185,.1088],[-.53,.1087],[-.5415,.1087],[-.553,.1086],[-.5644,.1086],[-.5759,.1086],[-.5874,.1085],[-.5989,.1085],[-.6104,.1086],[-.6219,.1088],[-.6333,.1093],[-.6448,.1101],[-.6563,.1108],[-.6678,.1111],[-.6793,.1109],[-.6908,.1103],[-.7022,.11],[-.7137,.1103],[-.7252,.1107],[-.7367,.111],[-.7482,.111],[-.7596,.1109],[-.7711,.1109],[-.7826,.1109],[-.7941,.1108],[-.8056,.1108],[-.8171,.1107],[-.8285,.1107],[-.84,.1108],[-.8515,.1112],[-.863,.1122],[-.8745,.1136],[-.886,.1148],[-.8974,.1156],[-.9089,.1162],[-.9204,.1166],[-.9319,.1167],[-.9434,.1166],[-.9549,.1164],[-.9663,.116],[-.9778,.1156],[-.9893,.1151],[-1.0008,.1146],[-1.0123,.1141],[-1.0237,.1137],[-1.0352,.1133],[-1.0467,.1131],[-1.0582,.1128],[-1.0697,.1114],[-1.0812,.1064],[-1.0926,.0968],[-1.1041,.0871],[-1.1118,.0826]],at:[[.9146,.4364],[2.4853,.4364],[-.9146,.4364],[-2.4853,.4364]],fins:[{side:-1,uv:[.9313,.9131,.9935,1],x0:-.225,x1:.0015,y0:-.8802,y1:-1.0505,outline:[[-.8802,.1162,.1139],[-.886,.122,.1145],[-.8917,.1279,.115],[-.8974,.1338,.1154],[-.9032,.1397,.1158],[-.9089,.1456,.116],[-.9147,.1514,.1163],[-.9204,.1544,.1164],[-.9261,.1632,.1165],[-.9319,.1691,.1166],[-.9376,.175,.1166],[-.9434,.1809,.1166],[-.9491,.1868,.1165],[-.9549,.1926,.1163],[-.9606,.1985,.1162],[-.9663,.2044,.116],[-.9721,.2132,.1159],[-.9778,.2191,.1156],[-.9836,.222,.1154],[-.9893,.222,.1152],[-.995,.222,.115],[-1.0008,.222,.1147],[-1.0065,.222,.1145],[-1.0123,.222,.1143],[-1.018,.222,.1141],[-1.0237,.222,.1139],[-1.0295,.222,.1137],[-1.0352,.222,.1136],[-1.041,.222,.1135],[-1.0467,.1132,.1134],[-1.0486,.1132,.1133]]}],finsAround:2,finsFrom:null,engines:{ring:0,centre:!0,f:1,colour:[46,44,42],profile:[[-1.1118,.0747],[-1.1156,.0835],[-1.1194,.0893],[-1.1233,.0805],[-1.1271,.0688],[-1.1309,.0688],[-1.1347,.0717],[-1.1386,.0717],[-1.1424,.0746],[-1.1462,.0775],[-1.1501,.0775],[-1.1539,.0804],[-1.1577,.0834],[-1.1615,.0833],[-1.1654,.0863],[-1.1692,.0892],[-1.173,.0892],[-1.1768,.0921],[-1.1807,.0921],[-1.1845,.095],[-1.1883,.095],[-1.1922,.092],[-1.196,.0833],[-1.1998,.057]]}}],badge:{y:.9137,d:.312,r:.208},band:[.7245,.7435],head:{top:1.6,cut:1.1028,mean:.7484,r:.2618}},heavy:{id:"starship",shape:"heavy",atlas:{w:1029,h:1136,cap:[.9942,.9947,.9981,.9982]},parts:[{name:"core",uv:[0,.0986,.7464,1],top:1.6,end:-1.1224,profile:[[1.6,.0103],[1.5884,.0383],[1.5769,.0539],[1.5653,.0677],[1.5537,.0807],[1.5422,.0926],[1.5306,.1039],[1.519,.1146],[1.5075,.1248],[1.4959,.1347],[1.4843,.1444],[1.4727,.1536],[1.4612,.1626],[1.4496,.1712],[1.438,.1796],[1.4265,.1874],[1.4149,.1949],[1.4033,.2021],[1.3918,.2091],[1.3802,.216],[1.3686,.223],[1.3571,.2298],[1.3455,.2364],[1.3339,.2426],[1.3224,.2485],[1.3108,.254],[1.2992,.2593],[1.2877,.2642],[1.2761,.2688],[1.2645,.2731],[1.253,.2771],[1.2414,.2808],[1.2298,.2843],[1.2182,.2875],[1.2067,.2904],[1.1951,.2931],[1.1835,.2955],[1.172,.2978],[1.1604,.2998],[1.1488,.3015],[1.1373,.3031],[1.1257,.3045],[1.1141,.3057],[1.1026,.3067],[1.091,.3075],[1.0794,.3082],[1.0679,.3087],[1.0563,.3091],[1.0447,.3093],[1.0332,.3094],[1.0216,.3094],[1.01,.3092],[.9985,.309],[.9869,.3088],[.9753,.3085],[.9637,.3083],[.9522,.3081],[.9406,.308],[.929,.3082],[.9175,.3086],[.9059,.309],[.8943,.309],[.8828,.3089],[.8712,.3087],[.8596,.3085],[.8481,.3084],[.8365,.3085],[.8249,.3087],[.8134,.3088],[.8018,.309],[.7902,.3091],[.7787,.309],[.7671,.3087],[.7555,.3085],[.744,.3083],[.7324,.3081],[.7208,.308],[.7092,.3081],[.6977,.3082],[.6861,.3082],[.6745,.3082],[.663,.3083],[.6514,.3084],[.6398,.3083],[.6283,.3081],[.6167,.308],[.6051,.308],[.5936,.3081],[.582,.3082],[.5704,.308],[.5589,.3078],[.5473,.3077],[.5357,.3078],[.5242,.3079],[.5126,.308],[.501,.308],[.4895,.3081],[.4779,.3082],[.4663,.3082],[.4547,.3083],[.4432,.3084],[.4316,.3085],[.42,.3084],[.4085,.3084],[.3969,.3085],[.3853,.3086],[.3738,.3085],[.3622,.3083],[.3506,.3081],[.3391,.3078],[.3275,.3076],[.3159,.3076],[.3044,.3078],[.2928,.3083],[.2812,.3086],[.2697,.3086],[.2581,.3084],[.2465,.3082],[.2349,.3079],[.2234,.3077],[.2118,.3077],[.2002,.3079],[.1887,.3084],[.1771,.3087],[.1655,.3087],[.154,.3085],[.1424,.3083],[.1308,.308],[.1193,.3078],[.1077,.3076],[.0961,.3075],[.0846,.3075],[.073,.3077],[.0614,.3077],[.0499,.3078],[.0383,.3079],[.0267,.308],[.0152,.308],[.0036,.308],[-.008,.3082],[-.0196,.3083],[-.0311,.3083],[-.0427,.3084],[-.0543,.3084],[-.0658,.3082],[-.0774,.3081],[-.089,.308],[-.1005,.308],[-.1121,.3081],[-.1237,.3082],[-.1352,.3082],[-.1468,.3081],[-.1584,.3082],[-.1699,.3083],[-.1815,.3083],[-.1931,.3084],[-.2046,.3085],[-.2162,.3086],[-.2278,.3087],[-.2393,.3088],[-.2509,.3089],[-.2625,.3089],[-.2741,.3089],[-.2856,.3089],[-.2972,.3091],[-.3088,.3092],[-.3203,.3093],[-.3319,.3096],[-.3435,.31],[-.355,.3105],[-.3666,.3108],[-.3782,.3109],[-.3897,.3107],[-.4013,.3105],[-.4129,.3103],[-.4244,.3101],[-.436,.3098],[-.4476,.3096],[-.4591,.3094],[-.4707,.3091],[-.4823,.3089],[-.4938,.3087],[-.5054,.3085],[-.517,.3083],[-.5286,.308],[-.5401,.3078],[-.5517,.3076],[-.5633,.3074],[-.5748,.3071],[-.5864,.3069],[-.598,.3067],[-.6095,.3065],[-.6211,.3063],[-.6327,.306],[-.6442,.3058],[-.6558,.3056],[-.6674,.3054],[-.6789,.3052],[-.6905,.3049],[-.7021,.3047],[-.7136,.3045],[-.7252,.3043],[-.7368,.3041],[-.7484,.3038],[-.7599,.3036],[-.7715,.3034],[-.7831,.3032],[-.7946,.303],[-.8062,.3027],[-.8178,.3025],[-.8293,.3023],[-.8409,.3021],[-.8525,.3019],[-.864,.3017],[-.8756,.3014],[-.8872,.3012],[-.8987,.301],[-.9103,.3008],[-.9219,.3006],[-.9334,.3004],[-.945,.3002],[-.9566,.3],[-.9681,.2997],[-.9797,.2995],[-.9913,.2993],[-1.0029,.2991],[-1.0144,.2989],[-1.026,.2987],[-1.0376,.2985],[-1.0491,.2983],[-1.0607,.2981],[-1.0723,.2979],[-1.0838,.2976],[-1.0954,.2974],[-1.107,.2972],[-1.1185,.297],[-1.1224,.297]],at:[[0,0]],fins:[{side:-1,uv:[.7464,.8477,.9252,1],x0:-.4382,x1:0,y0:1.3532,y1:1.0197,outline:[[1.3532,.2286,.2293],[1.3474,.2334,.2327],[1.3416,.2405,.2359],[1.3359,.2477,.2391],[1.3301,.2548,.2421],[1.3243,.2619,.2451],[1.3185,.2691,.2481],[1.3127,.2762,.2509],[1.3069,.2834,.2537],[1.3012,.2905,.2563],[1.2954,.2976,.2589],[1.2896,.3048,.2615],[1.2838,.312,.2639],[1.278,.3191,.2663],[1.2722,.3262,.2686],[1.2664,.3334,.2709],[1.2607,.3405,.273],[1.2549,.3477,.2751],[1.2491,.3548,.2772],[1.2433,.362,.2791],[1.2375,.3691,.281],[1.2317,.3762,.2828],[1.226,.3834,.2846],[1.2202,.3905,.2863],[1.2144,.3977,.2879],[1.2086,.4024,.2895],[1.2028,.4096,.291],[1.197,.4143,.2925],[1.1913,.4191,.2939],[1.1855,.4191,.2952],[1.1797,.4191,.2965],[1.1739,.4215,.2977],[1.1681,.4215,.2989],[1.1623,.4215,.3],[1.1566,.4239,.301],[1.1508,.4239,.302],[1.145,.4239,.303],[1.1392,.4263,.3039],[1.1334,.4263,.3047],[1.1276,.4286,.3056],[1.1218,.4286,.3063],[1.1161,.431,.307],[1.1103,.431,.3077],[1.1045,.431,.3083],[1.0987,.4334,.3089],[1.0929,.4334,.3094],[1.0871,.4334,.3099],[1.0814,.4358,.3104],[1.0756,.4358,.3108],[1.0698,.4334,.3112],[1.064,.431,.3115],[1.0582,.4191,.3118],[1.0524,.4096,.3121],[1.0467,.3953,.3123],[1.0409,.3834,.3125],[1.0351,.3715,.3127],[1.0293,.3596,.3128],[1.0235,.312,.3129],[1.0216,.312,.313]]},{side:1,uv:[.7464,.6937,.9252,.846],x0:0,x1:.4382,y0:1.3532,y1:1.0197,outline:[[1.3532,.2334,.2293],[1.3474,.2405,.2327],[1.3416,.25,.2359],[1.3359,.2572,.2391],[1.3301,.2619,.2421],[1.3243,.2691,.2451],[1.3185,.2762,.2481],[1.3127,.2834,.2509],[1.3069,.2905,.2537],[1.3012,.2976,.2563],[1.2954,.3048,.2589],[1.2896,.312,.2615],[1.2838,.3191,.2639],[1.278,.3262,.2663],[1.2722,.3334,.2686],[1.2664,.3405,.2709],[1.2607,.3453,.273],[1.2549,.3524,.2751],[1.2491,.3596,.2772],[1.2433,.3691,.2791],[1.2375,.3739,.281],[1.2317,.381,.2828],[1.226,.3881,.2846],[1.2202,.3953,.2863],[1.2144,.4024,.2879],[1.2086,.4096,.2895],[1.2028,.4143,.291],[1.197,.4167,.2925],[1.1913,.4191,.2939],[1.1855,.4191,.2952],[1.1797,.4191,.2965],[1.1739,.4215,.2977],[1.1681,.4215,.2989],[1.1623,.4239,.3],[1.1566,.4239,.301],[1.1508,.4239,.302],[1.145,.4263,.303],[1.1392,.4263,.3039],[1.1334,.4263,.3047],[1.1276,.4286,.3056],[1.1218,.4286,.3063],[1.1161,.431,.307],[1.1103,.431,.3077],[1.1045,.431,.3083],[1.0987,.4334,.3089],[1.0929,.4334,.3094],[1.0871,.4334,.3099],[1.0814,.4358,.3104],[1.0756,.4358,.3108],[1.0698,.431,.3112],[1.064,.4239,.3115],[1.0582,.4143,.3118],[1.0524,.4024,.3121],[1.0467,.3905,.3123],[1.0409,.3786,.3125],[1.0351,.3667,.3127],[1.0293,.3548,.3128],[1.0235,.3143,.3129],[1.0216,.3143,.313]]},{side:-1,uv:[.7464,.3477,.9922,.6919],x0:-.5301,x1:0,y0:-.3743,y1:-1.1282,outline:[[-.3743,.3059,.3036],[-.3801,.308,.3037],[-.3859,.3101,.3038],[-.3917,.3101,.3038],[-.3974,.3122,.3038],[-.4032,.3143,.3038],[-.409,.3164,.3038],[-.4148,.3206,.3038],[-.4206,.3226,.3038],[-.4264,.3248,.3038],[-.4322,.3268,.3038],[-.4379,.3289,.3038],[-.4437,.3331,.3038],[-.4495,.3373,.3038],[-.4553,.3415,.3038],[-.4611,.3457,.3038],[-.4669,.3499,.3038],[-.4726,.3541,.3038],[-.4784,.3583,.3038],[-.4842,.3625,.3038],[-.49,.3666,.3038],[-.4958,.3708,.3038],[-.5016,.3729,.3038],[-.5073,.3771,.3038],[-.5131,.3813,.3038],[-.5189,.3855,.3038],[-.5247,.3897,.3038],[-.5305,.3939,.3038],[-.5363,.3981,.3038],[-.5421,.4023,.3038],[-.5478,.4064,.3038],[-.5536,.4106,.3038],[-.5594,.4148,.3038],[-.5652,.419,.3038],[-.571,.4232,.3038],[-.5768,.4274,.3038],[-.5825,.4316,.3038],[-.5883,.4358,.3038],[-.5941,.4379,.3038],[-.5999,.4421,.3038],[-.6057,.4463,.3038],[-.6115,.4504,.3038],[-.6172,.4546,.3038],[-.623,.4588,.3038],[-.6288,.463,.3038],[-.6346,.4672,.3038],[-.6404,.4714,.3038],[-.6462,.4756,.3038],[-.6519,.4777,.3038],[-.6577,.4819,.3038],[-.6635,.4861,.3038],[-.6693,.4903,.3038],[-.6751,.4944,.3038],[-.6809,.4986,.3038],[-.6867,.5028,.3038],[-.6924,.5049,.3038],[-.6982,.507,.3038],[-.704,.5091,.3038],[-.7098,.5091,.3038],[-.7156,.5091,.3038],[-.7214,.5091,.3038],[-.7271,.5091,.3038],[-.7329,.5091,.3038],[-.7387,.5091,.3038],[-.7445,.5112,.3038],[-.7503,.5112,.3038],[-.7561,.5112,.3038],[-.7618,.5112,.3038],[-.7676,.5112,.3038],[-.7734,.5133,.3038],[-.7792,.5133,.3038],[-.785,.5133,.3038],[-.7908,.5133,.3038],[-.7966,.5133,.3038],[-.8023,.5154,.3038],[-.8081,.5154,.3038],[-.8139,.5154,.3038],[-.8197,.5154,.3038],[-.8255,.5154,.3038],[-.8313,.5154,.3038],[-.837,.5175,.3038],[-.8428,.5175,.3038],[-.8486,.5175,.3038],[-.8544,.5175,.3038],[-.8602,.5175,.3038],[-.866,.5196,.3038],[-.8717,.5196,.3038],[-.8775,.5196,.3038],[-.8833,.5196,.3038],[-.8891,.5196,.3038],[-.8949,.5217,.3038],[-.9007,.5217,.3038],[-.9064,.5217,.3038],[-.9122,.5217,.3038],[-.918,.5217,.3038],[-.9238,.5238,.3038],[-.9296,.5238,.3038],[-.9354,.5238,.3038],[-.9412,.5238,.3038],[-.9469,.5259,.3038],[-.9527,.5259,.3038],[-.9585,.5259,.3038],[-.9643,.5259,.3038],[-.9701,.5259,.3038],[-.9759,.528,.3038],[-.9816,.528,.3038],[-.9874,.528,.3038],[-.9932,.5259,.3038],[-.999,.5217,.3038],[-1.0048,.5112,.3038],[-1.0106,.4986,.3038],[-1.0163,.484,.3038],[-1.0221,.4693,.3038],[-1.0279,.4546,.3038],[-1.0337,.4379,.3038],[-1.0395,.4253,.3038],[-1.0453,.4086,.3038],[-1.0511,.396,.3038],[-1.0568,.3813,.3038],[-1.0626,.3666,.3038],[-1.0684,.3541,.3038],[-1.0742,.3541,.3038],[-1.08,.3541,.3038],[-1.0858,.3541,.3038],[-1.0915,.3541,.3038],[-1.0973,.3541,.3038],[-1.1031,.3541,.3038],[-1.1089,.352,.3038],[-1.1147,.3436,.3038],[-1.1205,.3352,.3038],[-1.1262,.3268,.3038]]},{side:1,uv:[.7464,.0018,.9922,.346],x0:0,x1:.5301,y0:-.3743,y1:-1.1282,outline:[[-.3743,.308,.3036],[-.3801,.3101,.3037],[-.3859,.3122,.3038],[-.3917,.3143,.3038],[-.3974,.3164,.3038],[-.4032,.3185,.3038],[-.409,.3206,.3038],[-.4148,.3226,.3038],[-.4206,.3268,.3038],[-.4264,.3289,.3038],[-.4322,.331,.3038],[-.4379,.3331,.3038],[-.4437,.3373,.3038],[-.4495,.3394,.3038],[-.4553,.3436,.3038],[-.4611,.3478,.3038],[-.4669,.3499,.3038],[-.4726,.3541,.3038],[-.4784,.3583,.3038],[-.4842,.3625,.3038],[-.49,.3666,.3038],[-.4958,.3708,.3038],[-.5016,.375,.3038],[-.5073,.3792,.3038],[-.5131,.3834,.3038],[-.5189,.3876,.3038],[-.5247,.3918,.3038],[-.5305,.396,.3038],[-.5363,.4002,.3038],[-.5421,.4044,.3038],[-.5478,.4086,.3038],[-.5536,.4127,.3038],[-.5594,.4148,.3038],[-.5652,.4211,.3038],[-.571,.4253,.3038],[-.5768,.4295,.3038],[-.5825,.4316,.3038],[-.5883,.4358,.3038],[-.5941,.44,.3038],[-.5999,.4442,.3038],[-.6057,.4484,.3038],[-.6115,.4526,.3038],[-.6172,.4567,.3038],[-.623,.4609,.3038],[-.6288,.4651,.3038],[-.6346,.4693,.3038],[-.6404,.4735,.3038],[-.6462,.4756,.3038],[-.6519,.4798,.3038],[-.6577,.484,.3038],[-.6635,.4882,.3038],[-.6693,.4924,.3038],[-.6751,.4966,.3038],[-.6809,.5007,.3038],[-.6867,.5049,.3038],[-.6924,.507,.3038],[-.6982,.5091,.3038],[-.704,.5091,.3038],[-.7098,.5112,.3038],[-.7156,.5112,.3038],[-.7214,.5112,.3038],[-.7271,.5112,.3038],[-.7329,.5133,.3038],[-.7387,.5133,.3038],[-.7445,.5133,.3038],[-.7503,.5133,.3038],[-.7561,.5133,.3038],[-.7618,.5154,.3038],[-.7676,.5154,.3038],[-.7734,.5154,.3038],[-.7792,.5154,.3038],[-.785,.5154,.3038],[-.7908,.5154,.3038],[-.7966,.5175,.3038],[-.8023,.5175,.3038],[-.8081,.5175,.3038],[-.8139,.5175,.3038],[-.8197,.5175,.3038],[-.8255,.5175,.3038],[-.8313,.5175,.3038],[-.837,.5196,.3038],[-.8428,.5196,.3038],[-.8486,.5196,.3038],[-.8544,.5196,.3038],[-.8602,.5196,.3038],[-.866,.5196,.3038],[-.8717,.5217,.3038],[-.8775,.5217,.3038],[-.8833,.5217,.3038],[-.8891,.5217,.3038],[-.8949,.5217,.3038],[-.9007,.5217,.3038],[-.9064,.5238,.3038],[-.9122,.5238,.3038],[-.918,.5238,.3038],[-.9238,.5238,.3038],[-.9296,.5238,.3038],[-.9354,.5238,.3038],[-.9412,.5259,.3038],[-.9469,.5259,.3038],[-.9527,.5259,.3038],[-.9585,.5259,.3038],[-.9643,.5259,.3038],[-.9701,.528,.3038],[-.9759,.528,.3038],[-.9816,.528,.3038],[-.9874,.5259,.3038],[-.9932,.5238,.3038],[-.999,.5196,.3038],[-1.0048,.507,.3038],[-1.0106,.4924,.3038],[-1.0163,.4777,.3038],[-1.0221,.463,.3038],[-1.0279,.4484,.3038],[-1.0337,.4337,.3038],[-1.0395,.4211,.3038],[-1.0453,.4044,.3038],[-1.0511,.3897,.3038],[-1.0568,.375,.3038],[-1.0626,.3625,.3038],[-1.0684,.3562,.3038],[-1.0742,.3562,.3038],[-1.08,.3562,.3038],[-1.0858,.3562,.3038],[-1.0915,.3541,.3038],[-1.0973,.3541,.3038],[-1.1031,.3541,.3038],[-1.1089,.3499,.3038],[-1.1147,.3436,.3038],[-1.1205,.3352,.3038],[-1.1262,.3289,.3038]]}],finsAround:2,finsFrom:null,engines:{ring:3,centre:3,f:.3,colour:[75,68,59],profile:[[-1.1224,.3256],[-1.1262,.3204],[-1.1301,.3142],[-1.134,.31],[-1.1378,.3059],[-1.1417,.3017],[-1.1455,.2965],[-1.1494,.2883],[-1.1532,.2759],[-1.1571,.2636],[-1.161,.2533],[-1.1648,.2431],[-1.1687,.243],[-1.1725,.243],[-1.1764,.2439],[-1.1802,.2439],[-1.1841,.2438],[-1.1879,.2417],[-1.1918,.2396],[-1.1957,.2355],[-1.1995,.2293],[-1.2034,.2201],[-1.2072,.2058],[-1.2111,.1864],[-1.2149,.0845],[-1.2188,.0814],[-1.2226,.0784],[-1.2265,.0722],[-1.2304,.0651],[-1.2342,.0529],[-1.2381,.0325]]}}],badge:{y:.9137,d:.4632,r:.3088},band:[.6489,.6679],head:null}};var Ph={falcon9:"falcon9",falconHeavy:"falcon-heavy",newGlenn:"new-glenn",vulcan:"vulcan",cz2f:"long-march-2f",cz5:"long-march-5",cz3b:"long-march-3b",heavy:"starship"},wf=Object.keys(Ph);var M3=[64,18],Oc=(i,t,e)=>i+(t-i)*e;function Ef(i,t){if(i.length<3)return i;let e=new Uint8Array(i.length);e[0]=e[i.length-1]=1;let n=[[0,i.length-1]];for(;n.length;){let[s,r]=n.pop(),[a,o]=i[s],[c,l]=i[r],h=c-a,f=l-o,u=Math.hypot(h,f)||1,d=-1,m=-1;for(let x=s+1;x<r;x++){let g=Math.abs(f*(i[x][0]-a)-h*(i[x][1]-o))/u;g>d&&(d=g,m=x)}d>t&&(e[m]=1,n.push([s,m],[m,r]))}return i.filter((s,r)=>e[r])}var b3=[.0015,.005];function S3(i,t,e){let[n,s,r,a]=i.uv,o=Ef(i.profile,e).map(([f,u])=>new yt(Math.max(4e-4,u),f)).reverse();o.push(new yt(1e-4,i.profile[0][0]+4e-4));let c=new Mr(o,t),l=c.attributes.uv,h=c.attributes.position;for(let f=0;f<l.count;f++){let u=Math.min(1,Math.max(0,(h.getY(f)-i.end)/(i.top-i.end)));l.setXY(f,Oc(n,r,l.getX(f)),Oc(s,a,u))}return c}function w3(i,t,e){let n=i.profile[i.profile.length-1][1],s=new ya(n,e);s.rotateX(Math.PI/2),s.translate(0,i.end,0);let[r,a,o,c]=t.cap,l=s.attributes.uv;for(let h=0;h<l.count;h++)l.setXY(h,(r+o)/2,(a+c)/2);return s}function E3(i,t){let e=new $i,n=i.outline.map(([f,u,d])=>{let m=t?t(f,d):0;return[f,Math.max(d,u)+m,d+m]});n.forEach(([f,u],d)=>d?e.lineTo(u,f):e.moveTo(u,f));for(let f=n.length-1;f>=0;f--)e.lineTo(n[f][2]-.004,n[f][0]);let s=new La(e),[r,a,o,c]=i.uv,l=s.attributes.position,h=s.attributes.uv;for(let f=0;f<l.count;f++){let u=l.getY(f),d=l.getX(f);if(t){let x=i.outline[0];for(let g of i.outline)Math.abs(g[0]-u)<Math.abs(x[0]-u)&&(x=g);d-=t(u,x[2])}let m=i.side*d;h.setXY(f,Oc(r,o,(m-i.x0)/(i.x1-i.x0)),Oc(a,c,(u-i.y1)/(i.y0-i.y1)))}return s}function T3(i,t){return t===4?i.side<0?[Math.PI,Math.PI/2,-Math.PI/2]:[0]:[i.side<0?Math.PI:0]}function A3(i,t,e){if(!i||i.profile.length<3)return[];let n=Math.max(...i.profile.map(([,h])=>h)),s=i.ring?n*(1-i.f):0,r=n-s,a=i.profile.filter(([,h])=>h-s>r*.25);if(a.length<3)return[];let o=Ef(a,e).map(([h,f])=>new yt(Math.max(4e-4,f-s),h)).reverse(),c=new Mr(o,Math.max(10,t>>1)),l=[];if(i.ring)for(let h=0;h<i.ring;h++)l.push([s,h/i.ring*Math.PI*2+Math.PI/i.ring,1]);if(i.centre===!0)l.push([0,0,1]);else if(typeof i.centre=="number")for(let h=0;h<i.centre;h++)l.push([s*.38,h/i.centre*Math.PI*2,.62]);return l.map(([h,f,u])=>{let d=c.clone();return d.scale(u,1,u),d.translate(Math.sin(f)*h,(1-u)*.05,Math.cos(f)*h),d})}var R3=([i,t])=>new De().makeTranslation(Math.sin(i)*t,0,Math.cos(i)*t).multiply(new De().makeRotationY(i+Math.PI/2)),Ch=new Map;function Tf(i,t){let e=`${i}|${t?1:0}`;if(Ch.has(e))return Ch.get(e);let n=uo[i],s=M3.map(l=>t?Math.max(12,l>>1):l).map((l,h)=>{let f=b3[h]*(t?1.6:1),u=[],d=[],m=n.parts.find(x=>x.name==="booster");for(let x of n.parts){let g=[S3(x,l,f),w3(x,n.atlas,l)],p=x.fins.length?x:x.finsFrom==="booster"&&m?m:null;if(p)for(let y of p.fins){let w=p!==x?(S,C)=>{let v=x.profile[0];for(let R of x.profile)Math.abs(R[0]-S)<Math.abs(v[0]-S)&&(v=R);return v[1]-C}:null;for(let S of T3(y,p===x?x.finsAround:4)){let C=E3(y,w);C.rotateY(S),g.push(C)}}let b=A3(x.engines,l,f),E=x.name==="core"?[null]:x.at;for(let y of E){let w=y?R3(y):null;for(let S of g)u.push(w?S.clone().applyMatrix4(w):S);for(let S of b)d.push(w?S.clone().applyMatrix4(w):S)}}return{hull:Fc(u),bells:d.length?Fc(d):null}}),r=0,a=s[0].hull.attributes.position;for(let l=0;l<a.count;l++)r=Math.max(r,Math.hypot(a.getX(l),a.getZ(l)));let o=[];for(let l of n.parts)if(l.name!=="core"&&l.engines)for(let[h,f]of l.at){let u=Math.max(...l.engines.profile.map(([,d])=>d));o.push({x:Math.sin(h)*f,z:Math.cos(h)*f,r:u})}let c={levels:s,span:r,nozzles:o};return Ch.set(e,c),c}var Ih=new Map;function Af(i){if(Ih.has(i))return Ih.get(i);let t=uo[i],e=t.parts.find(o=>o.name==="core"),n=o=>{let c=e.profile[0];for(let l of e.profile)Math.abs(l[0]-o)<Math.abs(c[0]-o)&&(c=l);return c[1]},s=i==="heavy"?-.25:0,r=[];for(let o of[0,Math.PI]){let l=[],h=[],f=[],u=t.badge.d;for(let m=0;m<=10;m++)for(let x=0;x<=10;x++){let g=(x/10-.5)*u,p=(m/10-.5)*u,b=t.badge.y+p,E=n(b)+.004,y=o+s+g/E;l.push(Math.sin(y)*E,b,Math.cos(y)*E),h.push(x/10,m/10)}for(let m=0;m<10;m++)for(let x=0;x<10;x++){let g=m*11+x,p=g+1,b=g+10+1,E=b+1;f.push(g,p,E,g,E,b)}let d=new Le;d.setAttribute("position",new ge(l,3)),d.setAttribute("uv",new ge(h,2)),d.setIndex(f),d.computeVertexNormals(),r.push(d)}let a=Fc(r);return Ih.set(i,a),a}function Rf(i){let t=uo[i];if(!t?.head)return null;let e=t.parts.find(s=>s.name==="core").profile,n=s=>{for(let r=1;r<e.length;r++)if(e[r][0]<=s){let[a,o]=e[r-1],[c,l]=e[r];return a===c?l:l+(o-l)*(s-c)/(a-c)}return e[e.length-1][1]};return{cut:t.head.cut,top:t.head.top,r:n}}var C3=`
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
#endif`;function Cf(i,{near:t,envMap:e,head:n,band:s,pattern:r}){let a=uo[i],o=i==="heavy",c=a.parts.find(m=>m.name==="core"),l=Math.max(...c.profile.map(([,m])=>m))*1.06,h=t?Da:$n,f=new h({metalness:1,roughness:1,side:Cn,alphaTest:.5,envMap:e,envMapIntensity:o?2.6:.95,...t?{clearcoat:o?0:.3,clearcoatRoughness:.35,bumpScale:o?0:1.1}:{}}),u=2.84/120,d={uHeadOn:{value:n&&a.head?1:0},uHead:{value:new oe(n??"#ffffff")},uMean:{value:a.head?.mean??.7},uCut:{value:a.head?.cut??99},uTop:{value:a.head&&a.head.top<1.59?a.head.top:99},uFeather:{value:.4*u},uCoreR:{value:l},uBand:{value:new yt(a.band[0],a.band[1])},uBandC:{value:new oe(s??"#888888")},uPat:{value:r?.texture??null},uPatOn:{value:r?.texture?1:0},uSpan:{value:new yt(a.head?.cut??0,a.head?.top??1)}};return o&&f.color.setScalar(1.35),f.userData.livery=d,f.defines={MP_LIVERY:""},f.onBeforeCompile=m=>{Object.assign(m.uniforms,d),m.vertexShader=m.vertexShader.replace("#include <common>",`#include <common>
varying vec3 vObj;`).replace("#include <begin_vertex>",`#include <begin_vertex>
vObj = position;`),m.fragmentShader=m.fragmentShader.replace("#include <common>",`#include <common>
varying vec3 vObj;
uniform float uHeadOn, uMean, uCut, uTop, uFeather, uCoreR, uPatOn;
uniform vec3 uHead, uBandC;
uniform vec2 uBand, uSpan;
uniform sampler2D uPat;`).replace("#include <map_fragment>","#include <map_fragment>"+C3)},f.customProgramCacheKey=()=>`mp-hull-${t?1:0}`,f}var If=(i,t,e)=>`${i}art/rockets/${Ph[t]}-${e}.webp`,Pf=(i,t)=>`${i}art/rockets/${Ph[t]}-mat.webp`;var I3={openai:"us",anthropic:"us",xai:"us",google:"us",meta:"us",zhipuai:"cn",kimi:"cn",minimax:"cn",alibaba:"cn",deepseek:"cn",xiaomi:"cn",tencent:"cn",volcengine:"cn"},P3={us:["falcon9","newGlenn","falconHeavy","vulcan"],cn:["cz2f","cz5","cz3b"]},Lh=new Set(["xai"]);function Bc(i,t,e){let n=[...i].sort((s,r)=>t(r)-t(s));return n.slice(0,3).find(s=>Lh.has(e(s)))??n[0]}function Lf(i){let t=new Map;for(let e of i)if(Lh.has(e.developerId)&&e.ability!==null){let n=t.get(e.developerId);(!n||e.ability>n.ability)&&t.set(e.developerId,{id:e.id,ability:e.ability})}return new Map([...t.values()].map(e=>[e.id,"falconHeavy"]))}var zc=i=>{let t=2166136261;for(let e=0;e<i.length;e++)t=Math.imul(t^i.charCodeAt(e),16777619);return t>>>0},kc=(i,t)=>{if(Lh.has(i))return"falcon9";let e=P3[I3[i]==="cn"?"cn":"us"];return e[(zc(i)+t)%e.length]},Nf=(i,t)=>kc(i,zc(t));function Df(i,t={}){let e=t.studio??null,n={},s=z=>n[z]||"#b8b0a8",r={openai:"OpenAI",anthropic:"Anthropic",zhipuai:"ZHIPU",xai:"xAI",alibaba:"Qwen",deepseek:"DeepSeek",kimi:"Kimi",minimax:"MiniMax",xiaomi:"Xiaomi",tencent:"Tencent",google:"Google",meta:"Meta"},a=t.assetBase??__LF_ENV__.BASE_URL,o={logos:Object.fromEntries(Object.entries({openai:"openai-white.svg",anthropic:"claude-rounded.svg",zhipuai:"zhipu.svg",xai:"x-white.svg",alibaba:"qwen.svg",deepseek:"deepseek.svg",kimi:"kimi-white.svg",minimax:"minimax.svg",google:"gemini.svg",xiaomi:"xiaomi.svg",meta:null}).filter(([,z])=>z).map(([z,Mt])=>[z,`${a}brands/${Mt}`]))},c="varying vec2 vUv; varying float vR; void main(){ vUv=uv; vR=abs(dot(normalize(normalMatrix*normal),vec3(0.,0.,1.))); gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",l="uniform float t; uniform float k; uniform vec3 c0; uniform vec3 c1; varying vec2 vUv; varying float vR; void main(){ float a=vUv.y; float fl=.82+.18*sin(t*38.+a*22.)+.08*sin(t*61.+vUv.x*40.); float dia=.85+.15*sin(a*26.-t*20.); float alpha=pow(1.-a,1.5)*fl*dia*k*(.35+.65*pow(vR,1.2)); vec3 col=mix(c0,c1,smoothstep(0.,.55,a)); gl_FragColor=vec4(col*alpha*1.7,alpha); }",h="uniform float t; uniform float k; uniform vec3 gc; uniform vec3 sc; uniform float sm; varying vec2 vUv; varying float vR; void main(){ float y=vUv.y; float n=.75+.25*sin(t*3.+y*30.+vUv.x*20.); float glow=pow(y,3.)*.7; float smoke=pow(y,1.2)*(1.-y)*sm*n; vec3 col=gc*glow+sc*smoke; float a=(glow+smoke)*k*pow(vR,1.4); gl_FragColor=vec4(col*a,a); }",f="uniform float t; uniform float k; varying vec2 vUv; varying float vR; float h(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); } float nz(vec2 p){ vec2 i=floor(p),f=fract(p); f=f*f*(3.-2.*f); return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y); } void main(){ float y=vUv.y; vec2 p=vec2(vUv.x*6.,y*5.+t*1.6); float n=nz(p)*.6+nz(p*2.3)*.4; float a=smoothstep(.2,.75,y)*(1.-smoothstep(.92,1.,y))*smoothstep(.3,.72,n)*k*pow(vR,.6)*.85; vec3 c=mix(vec3(.30,.27,.25),vec3(.62,.36,.2),smoothstep(.55,1.,y)); gl_FragColor=vec4(c*(.75+.25*n),a); }",u={hi:{o:["#8cc8ff","#1d5cff"],i:["#e2f1ff","#4f9dff"],light:"#7fb6ff",gc:[.45,.7,1],sc:[.55,.65,.85],sm:.35,soot:!1,label:"\u9AD8\u6548 \xB7 \u84DD\u7130",tip:"\u540C\u6837\u7684\u6210\u672C\u80FD\u529B\u660E\u663E\u66F4\u9AD8\uFF0C\u6216\u6CA1\u6709\u4EFB\u4F55\u6A21\u578B\u6BD4\u5B83\u53C8\u4FBF\u5B9C\u53C8\u5F3A"},mid:{o:["#ffd9a0","#ff5a24"],i:["#ffffff","#8fd0ff"],light:"#ffa060",gc:[1,.55,.25],sc:[.6,.66,.8],sm:.5,soot:!1,label:"\u6807\u51C6",tip:"\u80FD\u529B\u4E0E\u6210\u672C\u5927\u81F4\u5728\u8D8B\u52BF\u7EBF\u4E0A"},lo:{o:["#ff9446","#9a2406"],i:["#ffcf90","#e0601c"],light:"#ff7a3a",gc:[.9,.38,.12],sc:[.28,.24,.22],sm:.75,soot:!0,label:"\u4F4E\u6548 \xB7 \u9ED1\u70DF",tip:"\u540C\u6837\u7684\u6210\u672C\uFF0C\u80FD\u529B\u660E\u663E\u4F4E\u4E8E\u8D8B\u52BF\u7EBF"}},d=new Map,m=new Map;function x(z){return d.has(z)||d.set(z,new Promise(Mt=>{let vt=new Image;vt.onload=()=>Mt(vt),vt.onerror=()=>Mt(null),vt.src=z.includes("/")?z:`${a}brands/${z}`})),d.get(z)}function g(z,Mt){let vt=`${z.src}|${Mt}`;if(!m.has(vt)){let Et=document.createElement("canvas");Et.width=Et.height=128;let Ot=Et.getContext("2d");Ot.drawImage(z,0,0,128,128),Ot.globalCompositeOperation="source-in",Ot.fillStyle=Mt,Ot.fillRect(0,0,128,128),m.set(vt,Et)}return m.get(vt)}let p=-1.24,b=1.6,E=(b-p)/120,y=typeof innerWidth=="number"&&innerWidth<600,w=y?256:512,S={openai:"#f3f3f1",xai:"#2e3238",zhipuai:"#b9c2cc"},C={alibaba:"qwen.svg",xiaomi:"xiaomi-mi.svg"},v={xiaomi:["#ff8a33","#ff6900","#e65c00"]},R={xiaomi:.8},I=i??(e?(e.mapping=Rr,e):null),N=new Oa,L=new Map,O=(z,Mt)=>(L.has(z)||L.set(z,new Promise(vt=>N.load(z,Et=>{Et.colorSpace=Mt?tn:mi,Et.anisotropy=4,Et.userData.shared=!0,vt(Et)},void 0,()=>vt(null)))),L.get(z)),P=new Map;function W(z,Mt,vt){let Et=`${vt}|${z}|${Mt}`;return P.has(Et)||P.set(Et,(async()=>{let Ot=Rf(vt);if(!Ot)return null;let Lt=Or(z,Mt),et=Lt.glyph?await x(Lt.glyph):null,nt=z==="xai"?S.xai:Lt.base,_t=Ot.top-Ot.cut,wt=_t>.2,pt=y?256:512,It=pt/2,ee=document.createElement("canvas");ee.width=pt,ee.height=It;let V=ee.getContext("2d"),lt=re=>It*(1-re),ct=re=>Ot.cut+re*_t,gt=wt?{lattice:[.17,.43,.69],diagonal:[.17,.43,.69],rings:[.25,.58],split:[.22,.62]}[Lt.pattern]:[.4],bt=Math.max(...gt.map(re=>Ot.r(ct(re)))),Bt=.46,Ut=.8,Kt=gt.length>1?(gt[1]-gt[0])*_t:_t,se=Math.min(.085,Kt*(wt?.62:.5));if(V.fillStyle=nt,V.fillRect(0,0,pt,It),wt&&Lt.pattern==="split"&&(V.fillStyle=Lt.ink,V.fillRect(0,0,pt,lt(Bt))),wt&&Lt.pattern==="rings"){let re=Math.max(1,.014/_t*It);for(let ae of gt)for(let T of[-.12,.12])V.fillStyle=Lt.ink,V.fillRect(0,lt(ae+T)-re/2,pt,re)}if(wt&&Lt.pattern==="diagonal"){V.save(),V.strokeStyle=Lt.ink,V.globalAlpha=.35,V.lineWidth=pt/170;for(let re=-pt;re<pt*2;re+=pt/6)V.beginPath(),V.moveTo(re,lt(.08)),V.lineTo(re+pt*.55,lt(Ut)),V.stroke();V.restore()}if(et&&gt.forEach((re,ae)=>{let T=Ot.r(ct(re)),_=Math.max(.25,T/bt),G=Lt.pattern==="rings",q=se*(G?.85:1),rt=Math.max(3,Math.round((G?8:5)*_)),St=pt/rt,Rt=q/(2*Math.PI*T)*pt,tt=q/_t*It,ft=Lt.pattern==="diagonal"?ae*St/2:ae%2?St/2:0;for(let At=-1;At<=rt;At++){let Ht=Lt.pattern==="split"&&re>Bt?nt:Lt.inks?Lt.inks[((At+ae)%Lt.inks.length+Lt.inks.length)%Lt.inks.length]:Lt.ink;V.save(),V.translate(At*St+ft,lt(re)),V.scale(Rt/tt,1),Lt.pattern==="diagonal"&&V.rotate(-.45),V.drawImage(g(et,Ht),-tt/2,-tt/2,tt,tt),V.restore()}}),V.fillStyle=Lt.cap,V.fillRect(0,0,pt,lt(Ut)),wt){let re=[...Lt.trim,...Lt.trim];re.forEach((ae,T)=>{V.fillStyle=ae,V.fillRect(T*pt/re.length,lt(.055),pt/re.length+1,It*.055+1)})}let F=new Kn(ee);return F.colorSpace=tn,F.wrapS=rs,F.anisotropy=4,F.userData.shared=!0,F})()),P.get(Et)}let it=new Map;function Q(z,Mt){let vt=`${z}|${Mt}`;if(!it.has(vt)){let Ot=document.createElement("canvas");Ot.width=Ot.height=256;let Lt=new Kn(Ot);Lt.colorSpace=tn,Lt.anisotropy=4,Lt.userData.shared=!0;let et=_t=>{let wt=Ot.getContext("2d"),pt=256/2,It=256/2-1;wt.clearRect(0,0,256,256);let ee=wt.createRadialGradient(pt-It*.3,pt-It*.35,It*.05,pt,pt,It),V=v[z];if(ee.addColorStop(0,V?.[0]??"#2c3443"),ee.addColorStop(.6,V?.[1]??"#11151d"),ee.addColorStop(1,V?.[2]??"#07090d"),wt.beginPath(),wt.arc(pt,pt,It,0,Math.PI*2),wt.fillStyle=ee,wt.fill(),wt.save(),wt.clip(),wt.beginPath(),wt.ellipse(pt-It*.12,pt-It*.58,It*.7,It*.3,-.25,0,7),wt.fillStyle="rgba(255,255,255,.08)",wt.fill(),wt.restore(),wt.beginPath(),wt.arc(pt,pt,256*.47,0,Math.PI*2),wt.strokeStyle=Mt,wt.lineWidth=256*.045,wt.stroke(),_t){let lt=194.56*(R[z]??1);wt.drawImage(g(_t,"#ffffff"),pt-lt/2,pt-lt/2,lt,lt)}else wt.fillStyle="#ffffff",wt.font=`800 ${Math.round(256*.5)}px 'Manrope', sans-serif`,wt.textAlign="center",wt.textBaseline="middle",wt.fillText((r[z]??z)[0]??"?",pt,pt+256*.03);Lt.needsUpdate=!0};et(null);let nt=C[z]??Or(z).glyph??o.logos[z];nt&&x(nt).then(_t=>_t&&et(_t)),it.set(vt,Lt)}return it.get(vt)}let ht=t.lodDistance??7;function K(z,Mt,vt,Et,Ot,Lt,et){let nt=Tf(z,y),_t=z==="heavy",wt=Or(Mt,vt).colour,pt=_t?null:S[Mt]??wt,It=new nn;It.rotation.y=.4*Math.PI;let ee=new pa;It.add(ee);let V=new $n({map:Q(Mt,wt),transparent:!0,alphaTest:.5,roughness:.32,metalness:.15,envMap:I,envMapIntensity:.8,polygonOffset:!0,polygonOffsetFactor:-2}),lt=new $n({color:_t?"#9a9590":"#6d6a66",metalness:.9,roughness:.38,side:Cn,transparent:!0,forceSinglePass:!0,envMap:I,envMapIntensity:1.2});Et.push(V,lt);let ct=Af(z);ct.userData.shared=!0;let gt=nt.levels.map((bt,Bt)=>{bt.hull.userData.shared=!0,bt.bells&&(bt.bells.userData.shared=!0);let Ut=Cf(z,{near:Bt===0&&!y,envMap:I,head:pt,band:wt});Object.defineProperty(Ut,"transparent",{get(){return this.opacity<.999},set(){},configurable:!0}),Ut.forceSinglePass=!0,Et.push(Ut);let Kt=new nn,se=new we(bt.hull,Ut);return se.visible=!1,Kt.add(se,new we(ct,V)),bt.bells&&Kt.add(new we(bt.bells,lt)),ee.addLevel(Kt,Bt===0?0:ht),{mat:Ut,body:se}});Promise.all([O(If(a,z,w),!0),O(Pf(a,z),!1)]).then(([bt,Bt])=>{if(bt)for(let{mat:Ut,body:Kt}of gt)Ut.map=bt,Ut.isMeshPhysicalMaterial?(Ut.metalnessMap=Ut.roughnessMap=Bt,_t||(Ut.bumpMap=bt)):(Ut.metalness=_t?.75:.04,Ut.roughness=_t?.36:.42),Ut.needsUpdate=!0,Kt.visible=!0}),pt&&t.headPattern!==!1&&W(Mt,wt,z).then(bt=>{if(bt)for(let{mat:Bt}of gt){let Ut=Bt.userData.livery;Ut.uPat.value=bt,Ut.uPatOn.value=1}});for(let bt of nt.nozzles){let Bt=Lt(bt.r*.95,.6+bt.r*2,Ot("#ffd9a0","#ff5a24"));Bt.position.x=bt.x,Bt.position.z=bt.z,It.add(Bt),et.push(Bt)}return It.userData.span=nt.span,It}function ot(z){let Mt=s(z.dev),vt=new nn,Et=[],Ot=Tt=>(Et.push(Tt),Tt),Lt=wf.includes(z.shape)&&z.shape!=="heavy"?z.shape:kc(z.dev,zc(z.id)),et=document.createElement("canvas");et.width=et.height=2;let nt=new Kn(et),_t=nt,wt=nt,pt=Ot(new $n({map:nt})),It=(Tt,Gt)=>new Ge({transparent:!0,depthWrite:!1,blending:pn,uniforms:{t:{value:0},k:{value:1},c0:{value:new oe(Tt)},c1:{value:new oe(Gt)}},vertexShader:c,fragmentShader:l}),ee=(Tt,Gt,Jt)=>{let he=new Ma(Tt,Gt,32,1,!0);he.rotateX(Math.PI),he.translate(0,-Gt/2,0);let B=new we(he,Jt);return B.position.y=p+.02,B},V=new nn;vt.add(V);let lt=[],ct=K(Lt,z.dev,Mt,Et,It,ee,lt);V.add(ct);let gt=ct.userData.span,bt=[V],Bt=ee(.26,1.7,It("#ffd9a0","#ff5a24")),Ut=ee(.12,.95,It("#ffffff","#8fd0ff"));vt.add(Bt,Ut);let Kt=new Ha("#ffa060",1.5,6,2);Kt.position.y=-1.7,vt.add(Kt);let se=new nn;se.position.y=.15,se.visible=!1;let F=new we(new qi(.6,.016,10,160),new hn({color:"#d99a2b",transparent:!0,opacity:.95}));F.rotation.x=Math.PI/2-.38,se.add(F);let re=new we(new jn(.036,16,12),new hn({color:"#ffd27a"}));re.position.set(.6,0,0),F.add(re);let ae=new nn;ae.visible=!1,vt.add(ae);let T=K("heavy",z.dev,Mt,Et,It,ee,[]);ae.add(T);let _=p,G=T.userData.span,q=se,rt=new nn;rt.visible=!1,vt.add(rt);let St=new $i;St.moveTo(0,0),St.lineTo(.34,-.5),St.lineTo(.36,-.66),St.lineTo(0,-.46),St.closePath(),new Pa(St,{depth:.022,bevelEnabled:!0,bevelThickness:.008,bevelSize:.008,bevelSegments:2}).translate(0,0,-.011);let tt=new hn({color:"#bfe6ff",transparent:!0,opacity:.6,blending:pn,depthWrite:!1});Et.push(tt);let ft=[];for(let Tt=0;Tt<7;Tt++){let Gt=Tt/7*Math.PI*2,Jt=new we(new Xi(.006,.006,.9,6),tt.clone());Jt.position.set(Math.cos(Gt)*.48,0,Math.sin(Gt)*.48),Jt.userData.o=Tt*.37%1,rt.add(Jt),ft.push(Jt)}let At=lt,Ht=new we(new qi(1.15,.03,10,96),new hn({color:"#ffd37a",transparent:!0})),Nt=new we(new jn(1,8,8),new hn({visible:!1}));return Nt.scale.set(Math.max(.9,gt*2.4),1.6,Math.max(.9,gt*2.4)),Nt.position.y=.15,vt.add(Nt),{g:vt,shape:Lt,span:gt,mats:Et,outer:Bt,inner:Ut,light:Kt,ring:Ht,hit:Nt,heavy:ae,bOuter:At,heavyNozzle:_,heavySpan:G,halo:q,stdParts:bt,racer:rt,streaks:ft,steel:pt,hullMap:nt,boltMap:_t,steelMap:wt}}return{shapeFor:kc,raw(z){n[z.dev]=z.colour;let Mt=ot({id:z.id,name:z.name,dev:z.dev,shape:z.shape});return Mt.hit.userData.modelId=z.id,Object.assign(Mt,{SOOT_F:f,FUEL:u,FLAME_V:c,TRAIL_F:h,NOZZLE_Y:p}),Mt},make(z,Mt,vt=!1){n[z.developerId]=z.colour;let Et=ot({id:z.id,name:z.name,dev:z.developerId,shape:z.shape});Et.hit.userData.modelId=z.id,Et.heavy.visible=Mt,Et.racer.visible=!Mt&&z.racer,Et.stdParts.forEach(nt=>nt.visible=!Mt),Et.halo.visible=!1,Et.steel.map=Mt?Et.steelMap:z.racer?Et.boltMap:Et.hullMap,Et.steel.metalness=Mt?.92:.35,Et.steel.roughness=Mt?.2:.34,z.fuel==="lo"&&(Et.outer.material.fragmentShader=f,Et.outer.material.blending=ps,Et.outer.material.needsUpdate=!0);let Ot=u[z.fuel];for(let[nt,_t]of[[Et.outer,Ot.o],[Et.inner,Ot.i]])nt.material.uniforms.c0.value.set(_t[0]),nt.material.uniforms.c1.value.set(_t[1]);Et.light.color.set(Ot.light);let Lt=z.cost===0?0:Math.max(.15,Math.min(1,(Math.log10(z.cost??.1)+2.2)/2.8));Et.outer.scale.set(.8+Lt*.6,.6+Lt*1.2,.8+Lt*.6),Et.inner.scale.set(1,.7+Lt*.6,1),Et.light.intensity=.6+Lt*1.4;let et=new nn;return Et.g.add(et),vt&&(Et.outer.visible=!1,Et.inner.visible=!1,Et.bOuter.forEach(nt=>nt.visible=!1),Et.light.intensity=0),{root:Et.g,flame:et,tipHeight:1.6,span:Mt?Et.heavySpan:Et.span,hit:Et.hit,animate(nt){Et.outer.material.uniforms.t.value=Et.inner.material.uniforms.t.value=nt,Et.outer.material.uniforms.k.value=Et.inner.material.uniforms.k.value=vt||z.cost===0?0:1,Et.bOuter.forEach(_t=>{_t.material.uniforms.t.value=nt,_t.material.uniforms.k.value=vt||z.cost===0?0:1}),Et.g.rotation.y=-.2-.4*Math.PI},dispose(){let nt=new Set,_t=new Set,wt=new Set;Et.g.traverse(pt=>{pt.geometry&&!pt.geometry.userData.shared&&nt.add(pt.geometry);for(let It of Array.isArray(pt.material)?pt.material:pt.material?[pt.material]:[]){_t.add(It);for(let ee of Object.values(It))ee?.isTexture&&ee!==i&&!ee.userData.shared&&wt.add(ee)}}),nt.forEach(pt=>pt.dispose()),_t.forEach(pt=>pt.dispose()),wt.forEach(pt=>pt.dispose())}}},dispose(){}}}var ni={floor:0,minSpan:30,padAbove:3,padBelow:5,round:10,emptyMax:60,tickStep:10,fineTickStep:5,fineTickSpan:40,bandBelow:4,bandAbove:3,bandMinSpan:14,bandDefault:[44,60],gaugeMin:30,gaugeMax:100,stops:[{at:40,zh:"\u8FD1\u5730\u8F68\u9053",en:"Low Earth orbit"},{at:50,zh:"\u6708\u7403",en:"Moon",body:"moon"},{at:60,zh:"\u706B\u661F",en:"Mars",body:"mars"},{at:70,zh:"\u6728\u661F",en:"Jupiter",body:"jupiter"},{at:80,zh:"\u571F\u661F",en:"Saturn",body:"saturn"},{at:90,zh:"\u65E5\u7403\u5C42\u9876",en:"Heliopause"},{at:100,zh:"\u661F\u8FB0\u5927\u6D77",en:"The stars",final:!0}]},Nh=(i=ni)=>i.stops[i.stops.length-1].at;function Dh(i,t=ni,e){let n,s;if(!i.length)n=t.floor,s=t.emptyMax;else{let r=t.round,a=Math.ceil((Math.max(...i)+t.padAbove)/r)*r,o=Math.max(t.floor,Math.floor((Math.min(...i)-t.padBelow)/r)*r);a-o<t.minSpan&&(o=Math.max(t.floor,a-t.minSpan)),n=o,s=Math.max(a,o+t.minSpan)}return e?.min!=null&&(n=e.min),e?.max!=null&&(s=e.max),{abilityMin:n,abilityMax:s}}function Uh(i,t,e=ni,n){let s=t-i,r=n&&n>0?n:s>e.fineTickSpan?e.tickStep:e.fineTickStep;return Array.from({length:Math.floor(s/r)+1},(a,o)=>i+o*r)}function Fh(i,t=ni,e){let n=t.bandDefault[0],s=t.bandDefault[1];return i.length&&(n=Math.floor(Math.min(...i))-t.bandBelow,s=Math.max(Math.ceil(Math.max(...i))+t.bandAbove,n+t.bandMinSpan)),e?.min!=null&&(n=e.min),e?.max!=null&&(s=e.max),{min:n,max:s}}function Oh(i,t=ni){let e=t.gaugeMin,n=t.gaugeMax;return(Math.max(e,Math.min(n,i))-e)/(n-e)*100}function Hc(i,t){let e=typeof i=="function"?i():i,n=s=>{let r=e?.[s];return typeof r=="number"&&Number.isFinite(r)?r:t[s]};return{top:n("top"),right:n("right"),bottom:n("bottom"),left:n("left")}}function Vc(i,t,e){return{x:i.left,r:t-i.right,y:i.top,b:e-i.bottom}}var Bh=.6,zh=3,Uf=.45,Gc=()=>({zoom:1,panX:0,panY:0});function Wc(i,t,e){let n=t*Uf,s=e*Uf;return{zoom:Math.min(zh,Math.max(Bh,i.zoom)),panX:Math.min(n,Math.max(-n,i.panX)),panY:Math.min(s,Math.max(-s,i.panY))}}function kh(i,t,e,n,s,r){let a=Math.min(zh,Math.max(Bh,i.zoom*t)),o=a/i.zoom;return Wc({zoom:a,panX:i.panX+(e.x-n.x)*(1-o),panY:i.panY+(e.y-n.y)*(1-o)},s,r)}function Ff(i,t,e){let n=e?1:.2;return i.zoom+=(t.zoom-i.zoom)*n,i.panX+=(t.panX-i.panX)*n,i.panY+=(t.panY-i.panY)*n,Math.abs(t.zoom-i.zoom)<1e-4&&(i.zoom=t.zoom),Math.abs(t.panX-i.panX)<.01&&(i.panX=t.panX),Math.abs(t.panY-i.panY)<.01&&(i.panY=t.panY),i}var Of="http://www.w3.org/2000/svg",L3="button, a, input, select, textarea, details",N3=i=>i==null?"\u2014":(i<.1?i.toFixed(3):i<1?i.toFixed(2):i.toFixed(1).replace(/\.0$/,""))+"\xD7",Br=i=>String(i).replace(/[&<>"]/g,t=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"})[t]),Bf=!1,D3={top:48,right:32,bottom:72,left:32},U3={top:48,right:16,bottom:78,left:16};function Hh(i){let t=i.container,e=i.logo??(A=>`<span>${Br(A.slice(0,1).toUpperCase())}</span>`),n=A=>{let k=document.createElement("div");return k.className=A,k},s=n("lf-scene"),r=n("lf-plates"),a=document.createElementNS(Of,"svg"),o=n("lf-voyage");s.setAttribute("role","group"),a.setAttribute("class","lf-leaders"),r.appendChild(a),t.append(s,r,o);let c=i.language??"zh",l=()=>c==="zh",h=()=>{s.setAttribute("aria-label",l()?"\u7ACB\u4F53\u53D1\u5C04\u573A\uFF1A\u6BCF\u679A\u706B\u7BAD\u662F\u4E00\u4E2A\u6A21\u578B\uFF0C\u9AD8\u5EA6\u662F\u80FD\u529B\uFF0C\u5C3E\u7130\u7C97\u7EC6\u662F\u6210\u672C\uFF0C\u7EB5\u6DF1\u662F\u822A\u65F6\uFF1B\u53EF\u62D6\u52A8\u65CB\u8F6C":"3D launch field: each rocket is a model; altitude is ability, plume is cost, depth is task time; drag to rotate"),o.setAttribute("aria-label",l()?"\u80FD\u529B\u822A\u7A0B\u5C3A":"Ability voyage gauge")};h();let f=i.scale??ni,u=f.stops,d=Nh(f),m=i.axis??null,x=()=>Hc(i.insets,P()?U3:D3),g=()=>i.focusInsets?Hc(i.focusInsets,x()):x(),p=typeof i.ignoreTargets=="function"?i.ignoreTargets:A=>!!A.closest?.(i.ignoreTargets??L3),b=i.reducedMotion??matchMedia("(prefers-reduced-motion: reduce)").matches,E=i.reducedMotion===!0,y=i.rocketScale??1,w={models:[]},S={},C=new Set,v=null,R=null,I=null,N=A=>w.models.find(k=>k.dev===A)?.colour??"#b8b0a8",L=0,O=0,P=()=>L<720,W=innerWidth<720,it=W?13:15,Q=4,ht=W?-6.5:-9,K=-ht,ot=3.2,z=W?-5.5:-8.5,Mt=2.3,vt=46,Et=new D(0,-vt-9,-8),Ot=()=>0,Lt=f.bandDefault[0],et=f.bandDefault[1],nt=A=>Math.max(1.4,(A-Lt)/(et-Lt)*it+Q),_t=-1.3,wt=.5,pt=1,It=A=>ht+.8+(Math.log10(A)-_t)/(wt-_t)*(K-ht-1.6),ee=A=>A==null?Mt:1.2-A/pt*(1.2-z-.6),V=(A,k,$)=>new D(A,k,$),lt;try{lt=new Rc({antialias:!0,powerPreference:"high-performance",preserveDrawingBuffer:!1})}catch(A){throw s.remove(),r.remove(),o.remove(),A}lt.setPixelRatio(Math.min(devicePixelRatio,2)),lt.outputColorSpace=tn,lt.toneMapping=Rs,lt.toneMappingExposure=1.05,s.appendChild(lt.domElement);let ct=new ha;ct.background=new oe("#010205");let gt=new Tn(30,1,.1,4e3),bt=[],Bt=A=>(bt.push(A),A),Ut=V(-.93,.07,-.36).normalize(),Kt=V(.5,.55,.68).normalize(),se=new Tr("#ffe4c4",2.6);se.position.copy(Ut).multiplyScalar(50),ct.add(se);let F=new Tr("#d8e6ff",1.25);F.position.copy(Kt).multiplyScalar(50),ct.add(F),ct.add(new Ba("#7d9cd6","#0d2a5c",.45));let re=(A,k,$)=>[(Math.atan2(A.z,A.x)/(2*Math.PI)+.5)*k,(1-(Math.asin(A.y)/Math.PI+.5))*$],ae=(()=>{let $=document.createElement("canvas");$.width=1024,$.height=512;let X=$.getContext("2d"),dt=X.createLinearGradient(0,0,0,512);[[0,"#06080f"],[.44,"#121a2c"],[.49,"#5d93d6"],[.5,"#bfe2ff"],[.52,"#2a64b4"],[.6,"#0d2752"],[.8,"#061330"],[1,"#02060f"]].forEach(([Xt,ne])=>dt.addColorStop(Xt,ne)),X.fillStyle=dt,X.fillRect(0,0,1024,512);let st=(Xt,ne,Se,at)=>{let[de,ce]=re(Xt,1024,512);for(let le of[-1024,0,1024]){X.save(),X.translate(de+le,ce),X.scale(ne,Se);let ke=X.createRadialGradient(0,0,0,0,0,1);at.forEach(([He,Pe])=>ke.addColorStop(He,Pe)),X.fillStyle=ke,X.beginPath(),X.arc(0,0,1,0,Math.PI*2),X.fill(),X.restore()}};st(Kt,120,70,[[0,"rgba(235,242,255,1)"],[.55,"rgba(200,220,255,.75)"],[1,"rgba(200,220,255,0)"]]),st(V(.7,.35,-.6).normalize(),40,110,[[0,"rgba(150,195,255,.9)"],[1,"rgba(150,195,255,0)"]]),st(V(-.2,.75,.6).normalize(),220,26,[[0,"rgba(255,255,255,.55)"],[1,"rgba(255,255,255,0)"]]),st(Ut,70,40,[[0,"rgba(255,250,235,1)"],[.2,"rgba(255,220,170,1)"],[1,"rgba(255,170,90,0)"]]);for(let Xt=0;Xt<260;Xt++){let ne=Math.random()*1024,Se=512*(.56+Math.random()*.4);X.fillStyle=`rgba(255,${150+Math.random()*60|0},80,${.3+Math.random()*.5})`,X.fillRect(ne,Se,1.5,1.5)}let Ct=new Kn($);return Ct.colorSpace=tn,Ct.wrapS=rs,Ct.minFilter=Ti,Bt(Ct)})(),T=Df(null,{studio:ae,assetBase:i.assetBase}),_=bf(ct),G=(A,k=128)=>{let $=document.createElement("canvas");$.width=$.height=k;let X=$.getContext("2d"),dt=X.createRadialGradient(k/2,k/2,0,k/2,k/2,k/2);A.forEach(([Ct,Xt])=>dt.addColorStop(Ct,Xt)),X.fillStyle=dt,X.fillRect(0,0,k,k);let st=new Kn($);return st.colorSpace=tn,Bt(st)},q=G([[0,"rgba(255,255,255,1)"],[.25,"rgba(255,255,255,.45)"],[1,"rgba(255,255,255,0)"]]),rt;{let k=new Float32Array(9600),$=new Float32Array(3200),X=new Float32Array(3200);for(let ce=0;ce<3200;ce++){let le=Math.random()*2-1,ke=Math.random()*Math.PI*2,He=1500,Pe=Math.sqrt(1-le*le);k.set([He*Pe*Math.cos(ke),He*le,He*Pe*Math.sin(ke)],ce*3),$[ce]=Math.random()*6.28,X[ce]=Math.random()**4*3.4+.7}let dt=new Le;dt.setAttribute("position",new ln(k,3)),dt.setAttribute("ph",new ln($,1)),dt.setAttribute("sz",new ln(X,1)),rt=new Ge({transparent:!0,depthWrite:!1,uniforms:{t:{value:0}},vertexShader:"attribute float ph; attribute float sz; uniform float t; varying float a; void main(){ a=.6+.4*sin(t*1.1+ph); gl_PointSize=sz*(.75+.25*a)*1.5; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",fragmentShader:"varying float a; void main(){ float d=length(gl_PointCoord-.5); gl_FragColor=vec4(vec3(.92,.95,1.),a*smoothstep(.5,0.,d)); }"}),ct.add(new xa(dt,rt));let st=document.createElement("canvas");st.width=1024,st.height=512;let Ct=st.getContext("2d");[[300,220,320,"rgba(70,90,170,.22)"],[640,180,280,"rgba(40,90,170,.18)"],[820,290,220,"rgba(150,80,140,.10)"]].forEach(([ce,le,ke,He])=>{let Pe=Ct.createRadialGradient(ce,le,0,ce,le,ke);Pe.addColorStop(0,He),Pe.addColorStop(1,"rgba(0,0,0,0)"),Ct.fillStyle=Pe,Ct.fillRect(0,0,1024,512)});let Xt=Bt(new Kn(st));Xt.colorSpace=tn;let ne=new we(new ls(2600,1300),new hn({map:Xt,transparent:!0,depthWrite:!1,blending:pn}));ne.position.set(200,420,-1300),ct.add(ne);let Se=Ut.clone().multiplyScalar(1100).add(Et),at=new as(new Gi({map:G([[0,"rgba(255,255,250,1)"],[.06,"rgba(255,245,225,1)"],[.16,"rgba(255,200,140,.5)"],[.45,"rgba(255,150,80,.08)"],[1,"rgba(255,120,60,0)"]],256),blending:pn,depthWrite:!1}));at.position.copy(Se),at.scale.setScalar(340),ct.add(at);let de=new as(new Gi({map:q,color:"#9cc8ff",blending:pn,depthWrite:!1,opacity:.55}));de.position.copy(Se),de.scale.set(1500,14,1),ct.add(de)}let St=[],Rt=new nn,tt=0;document.fonts?.ready.then(()=>tt++),ct.add(Rt);function ft(A,k,$,X,dt=2){let st=[];for(let Ct=0;Ct<=dt;Ct++)st.push(V($+(X-$)*(Ct/dt),A,k));return st}let At=A=>{let k=document.createElement("canvas");k.width=256,k.height=128;let $=k.getContext("2d");A($,256,128);let X=Bt(new Kn(k));return X.colorSpace=tn,X},Ht=(()=>{let A=7;return()=>(A=A*16807%2147483647)/2147483647})(),Nt={moon:At((A,k,$)=>{A.fillStyle="#b9bcc2",A.fillRect(0,0,k,$);for(let X=0;X<70;X++){let dt=2+Ht()*9;A.fillStyle=`rgba(${Ht()<.5?"70,74,82":"225,228,232"},.35)`,A.beginPath(),A.arc(Ht()*k,Ht()*$,dt,0,7),A.fill()}}),mars:At((A,k,$)=>{A.fillStyle="#b4532c",A.fillRect(0,0,k,$);for(let X=0;X<50;X++)A.fillStyle=`rgba(${Ht()<.6?"90,36,22":"214,120,72"},.35)`,A.beginPath(),A.ellipse(Ht()*k,Ht()*$,6+Ht()*26,3+Ht()*10,0,0,7),A.fill();A.fillStyle="rgba(255,250,245,.8)",A.fillRect(0,0,k,7),A.fillRect(0,$-6,k,6)}),jupiter:At((A,k,$)=>{let X=["#d8c4a4","#b98d63","#e7dcc8","#a8714b","#d9b98e","#c69c74","#efe6d6"];for(let dt=0;dt<$;dt+=6)A.fillStyle=X[(dt/6+(Ht()*2|0))%X.length],A.fillRect(0,dt,k,6);A.fillStyle="#b5523a",A.beginPath(),A.ellipse(170,82,16,8,0,0,7),A.fill()}),saturn:At((A,k,$)=>{let X=["#e6d3a6","#d4bb85","#efe2c0","#c9ad78"];for(let dt=0;dt<$;dt+=8)A.fillStyle=X[dt/8%X.length],A.fillRect(0,dt,k,8)})},Tt=A=>{A.traverse(k=>{k.geometry?.dispose(),k.isInstancedMesh&&k.dispose();for(let $ of[].concat(k.material||[]))$.dispose()}),A.clear()};function Gt(A){Tt(Rt),St.forEach(X=>X.el.remove()),St.length=0;let k=(X,dt,st="",Ct=null,Xt=0)=>{let ne=document.createElement("div");ne.className="ltag "+st,ne.innerHTML=X,r.appendChild(ne),St.push({el:ne,v:dt,far:Ct,radius:Xt,atFar:!1})};for(let X of u){let dt=X.at,st=X.body&&Nt[X.body];if(dt<Lt||dt>et)continue;let Ct=!!X.final,Xt=ft(nt(dt),z,ht+.5,K-.5),ne=new Wi(new Le().setFromPoints(Xt),Ct?new Ua({color:"#ffd37a",dashSize:.3,gapSize:.2}):new di({color:"#cfe2ff",transparent:!0,opacity:.16}));Ct&&ne.computeLineDistances(),Rt.add(ne);let Se=V(K+.2,Xt[0].y,z);if(st){let at=new we(new jn(X.body==="jupiter"?.6:.42,48,32),new $n({map:st,roughness:.9}));if(at.position.copy(Se),at.userData.spin=!0,Rt.add(at),X.body==="saturn"){let de=new we(new br(.62,.95,64),new $n({color:"#d9c6a0",transparent:!0,opacity:.75,side:Cn,roughness:.8}));de.position.copy(Se),de.rotation.x=-1.2,de.rotation.y=.3,Rt.add(de)}}k(`${l()?X.zh:X.en}<small>Index ${dt}</small>`,Se,(Ct?"kar":"")+(st?" body":""),Xt[0].clone(),st?X.body==="saturn"?.95:X.body==="jupiter"?.6:.42:0)}let $=u.find(X=>X.at>et);$&&W&&k(l()?`\u2191 \u4E0B\u4E00\u7AD9 ${$.zh} \xB7 ${$.at}<small>${A>=d?"\u5DF2\u9A76\u5165\u661F\u8FB0\u5927\u6D77":`\u7EC8\u70B9 \u661F\u8FB0\u5927\u6D77 ${d}\u3000\u9886\u5148\u8005\u8FD8\u5DEE ${(d-A).toFixed(1)}`}</small>`:`\u2191 Next stop ${$.en} \xB7 ${$.at}<small>${A>=d?"Out among the stars":`Destination: the stars at ${d} \xB7 the leader is ${(d-A).toFixed(1)} away`}</small>`,V(ht+.5,Ot()+nt(et)+1.2,z),"next")}{let A=K-ht+3,k=ot-z+2,$=new we(new ls(A,k),new Ge({transparent:!0,depthWrite:!1,blending:pn,uniforms:{size:{value:new yt(A,k)}},vertexShader:"varying vec2 vUv; void main(){ vUv=uv; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",fragmentShader:"uniform vec2 size; varying vec2 vUv; void main(){ vec2 p=vUv*size; vec2 g=abs(fract(p-.5)-.5)/fwidth(p); float line=1.-min(min(g.x,g.y),1.); vec2 e=min(vUv,1.-vUv)*size; float fade=smoothstep(0.,2.5,min(e.x,e.y)); float back=mix(.35,1.,vUv.y); gl_FragColor=vec4(vec3(.45,.68,1.)*(line*.16+.025)*fade*back,1.); }"}));$.rotation.x=-Math.PI/2,$.position.set((ht+K)/2+.5,-.01,(ot+z)/2),ct.add($)}let Jt=new nn;ct.add(Jt);let he=[];function B(A,k,$){let X=document.createElement("div");X.className="tick3 "+($??""),X.textContent=A,r.appendChild(X),he.push({el:X,v:k})}let Ft=()=>{let A=[];for(let k=Math.floor(_t)-1;k<=Math.ceil(wt)+1;k++)for(let $ of[1,3]){let X=$*10**k;Math.log10(X)>=_t&&Math.log10(X)<=wt&&A.push(X)}return A};function mt(){Tt(Jt),he.forEach($=>$.el.remove()),he.length=0;let A=[];for(let $=0;$<=60;$++){let X=ht+(K-ht)*($/60);A.push(V(X,Ot()+.03,ot))}Jt.add(new Wi(new Le().setFromPoints(A),new di({color:"#ffb27a",transparent:!0,opacity:.8})));for(let $ of Ft()){let X=It($);if(X<ht||X>K)continue;let dt=Ot();Jt.add(new Wi(new Le().setFromPoints([V(X,dt,ot),V(X,dt+.25,ot)]),new di({color:"#ffb27a"}))),B(N3($),V(X,dt-.35,ot+.2))}B(l()?"\u6CB9\u8017 \xB7 \u6210\u672C\u500D\u7387 \u2192":"Fuel \xB7 cost ratio \u2192",V(K-1.2,Ot()-1,ot+.4),"axis");let k=[];for(let $=0;$<=40;$++){let X=ot-(ot-z)*($/40);k.push(V(K+.6,Ot()+.03,X))}Jt.add(new Wi(new Le().setFromPoints(k),new di({color:"#c9b3ff",transparent:!0,opacity:.8})));for(let $ of[.25,.5,1,2,3])$<=pt&&B((l()?"\u822A\u65F6 ":"Time ")+$+"\xD7",V(K+1.2,Ot(),ee($)));B(l()?"\u822A\u65F6\u672A\u77E5 \xB7 \u524D\u6392":"Time unknown \xB7 front row",V(ht+1.2,Ot()+.1,Mt),"lane")}let Dt=new Xi(.1,.55,1,32,1,!0);Dt.translate(0,-.5,0);let kt=new Xi(.2,.7,1,32,1,!0);kt.translate(0,-.5,0);let ut=new Map;function ie(A){let k=ut.get(A.id);if(k)return k;let $=T.raw({id:A.id,name:A.name,dev:A.dev,colour:A.colour,shape:A.shape}),X=new Set([$.hullMap,$.boltMap,$.steelMap]),dt=ce=>{for(let le of Object.values(ce))le?.isTexture&&le!==ae&&X.add(le)};$.mats.forEach(dt),$.g.traverse(ce=>{for(let le of[].concat(ce.material||[]))dt(le)});for(let ce of X)bt.includes(ce)||bt.push(ce),vf(ce,()=>{},ce.image?.width===ce.image?.height?256:512);yf($);let st=new we(Dt,new Ge({transparent:!0,depthWrite:!1,blending:pn,uniforms:{t:{value:0},k:{value:1},gc:{value:new D(1,.55,.25)},sc:{value:new D(.6,.66,.8)},sm:{value:.5}},vertexShader:$.FLAME_V,fragmentShader:$.TRAIL_F})),Ct=new we(kt,new Ge({transparent:!0,depthWrite:!1,uniforms:{t:{value:0},k:{value:0}},vertexShader:$.FLAME_V,fragmentShader:$.SOOT_F})),Xt=new Wi(new Le().setFromPoints([V(0,0,0),V(0,-1,0)]),new di({color:A.colour,transparent:!0,opacity:.22})),ne=new we(new br(.2,.28,48),new hn({color:A.colour,transparent:!0,opacity:.7,side:Cn}));ne.rotation.x=-Math.PI/2;let Se=new as(new Gi({map:q,color:A.colour,blending:pn,depthWrite:!1,transparent:!0,opacity:.3})),at=new as(new Gi({map:q,color:"#b8c2d2",transparent:!0,depthWrite:!1,opacity:0})),de=new nn;return de.add($.g,$.ring),ct.add(de,st,Ct,Xt,ne,Se,at),k={m:A,...$,root:de,trail:st,soot:Ct,drop:Xt,pad:ne,padGlow:Se,smoke:at,fuelKind:null,pos:V(0,0,0),tgt:V(0,0,0),born:performance.now()+ut.size*160,flare:1,phase:Math.random()*6.28,screen:{x:0,y:0,z:0},base:{x:0,y:0,z:0}},ut.set(A.id,k),k}let jt=null;function Be(A){let k=A.m.fuel??"mid";if(A.fuelKind===k)return;A.fuelKind=k;let $=A.FUEL[k];for(let X of[A.outer,...A.bOuter])X.material.uniforms.c0.value.set($.o[0]),X.material.uniforms.c1.value.set($.o[1]);A.inner.material.uniforms.c0.value.set($.i[0]),A.inner.material.uniforms.c1.value.set($.i[1]),A.light.color.set($.light),A.trail.material.uniforms.gc.value.set(...$.gc),A.trail.material.uniforms.sc.value.set(...$.sc),A.trail.material.uniforms.sm.value=$.sm}let U={yaw:-.26,pitch:.12},xt={yaw:-.2,pitch:.16},zt=null,$t=null,xe;function be(){let A=w.models.filter(X=>C.has(X.id)&&S[X.id]);if(jt=Bc(A,X=>S[X.id][1],X=>X.dev)?.id??null,!A.length)return;let k=A.map(X=>S[X.id][2]);if(_t=Math.log10(Math.min(...k))-.22,wt=Math.log10(Math.max(...k))+.22,wt-_t<1){let X=(_t+wt)/2;_t=X-.5,wt=X+.5}pt=Math.max(.6,...A.map(X=>S[X.id][3]??0))*1.15;let $=A.map(X=>S[X.id][1]);({min:Lt,max:et}=Fh($,f,m??void 0));for(let X of A){let dt=ie(X),st=S[X.id];dt.m=X,dt.focusPoints?.length!==X.e.length+2&&(dt.focusPoints=Array.from({length:X.e.length+2},()=>V(0,0,0))),dt.tgt.set(It(st[2]),nt(st[1]),ee(st[3])),dt.nudge=0}Mf(A.map(X=>ut.get(X.id)),W?1:1.3,(W?xt:U).yaw);for(let X of ut.values())X.started||(X.pos.copy(X.tgt),X.started=!0);iu(),mt(),Gt(Math.max(...$)),zt=null,xe=void 0}let Ke=new nn;ct.add(Ke);let ye=[];function me(A){if(Tt(Ke),ye.forEach(st=>st.el.remove()),ye.length=0,xe=A,!A)return;let k=w.models.find(st=>st.id===A);if(!k||!ut.has(A))return;let $=k.colour,X=ut.get(A)?.nudge??0,dt=k.e.map(st=>{let Ct=It(st[2])+X,Xt=ee(st[3]);return V(Ct,Ot()+nt(st[1]),Xt)});dt.length>1&&Ke.add(new we(new Na(new vr(dt,!1,"centripetal"),120,.022,8,!1),new hn({color:$,transparent:!0,opacity:.5,blending:pn,depthWrite:!1}))),k.e.forEach((st,Ct)=>{let Xt=new we(new jn(.1,16,12),new hn({color:st[3]==null||st[4]?"#0b1020":$}));if(Xt.position.copy(dt[Ct]),Ke.add(Xt),st[3]==null||st[4]){let Se=new we(new qi(.1,.025,8,24),new hn({color:$}));Se.position.copy(dt[Ct]),Se.userData.bill=!0,Ke.add(Se)}let ne=document.createElement("div");ne.className="bl3"+(st[0]===k.rec?" rec":"")+(st===S[k.id]?" cur":""),ne.textContent=`${st[0]} ${st[1].toFixed(1)}${st[4]?l()?" \xB7 \u4F30\u65F6":" \xB7 est. time":st[3]==null?l()?" \xB7 \u672A\u6D4B\u65F6":" \xB7 time unknown":""}`,ne.style.setProperty("--c",$),r.appendChild(ne),ye.push({el:ne,v:dt[Ct]})})}let an=new Nc(lt,new sn(1,1,{type:mn}));an.addPass(new Dc(ct,gt));let Fn=new Fr(new yt(256,256),.75,.28,.86);an.addPass(Fn),an.addPass(new Uc);let ue={yaw:U.yaw,pitch:U.pitch,vy:0,vp:0,drag:null},Ci=V(0,10,-2.4),Zi=Ci.clone(),wn=0,vs=()=>Vc(x(),L,O),Ds=(A,k=A.tgt)=>V(k.x,Ot()+k.y,k.z),mo=gt.clone(),go=V(0,0,0),Jc=V(0,0,0),Kc=V(0,0,0),Us={look:V(0,0,0),d:0,fy:0};function jc(A){let k=A.nudge??0,$=A.focusPoints;$[0].set(A.tgt.x,Ot()+A.tgt.y+2.2,A.tgt.z),$[1].set(A.tgt.x,Ot()+A.tgt.y-2.4,A.tgt.z);for(let ce=0;ce<A.m.e.length;ce++){let le=A.m.e[ce];$[ce+2].set(It(le[2])+k,Ot()+nt(le[1]),ee(le[3]))}let X=go.copy($[0]),dt=Jc.copy($[0]);for(let ce of $)X.min(ce),dt.max(ce);let st=Us.look.copy(X).add(dt).multiplyScalar(.5),Ct=Vc(g(),L,O),Xt=Ct.y,ne=Ct.b,Se=xt,at=mo;at.aspect=L/O,at.clearViewOffset(),at.updateProjectionMatrix();let de=24;for(let ce=0;ce<6;ce++){at.position.set(st.x+de*Math.sin(Se.yaw)*Math.cos(Se.pitch),st.y+de*Math.sin(Se.pitch),st.z+de*Math.cos(Se.yaw)*Math.cos(Se.pitch)),at.lookAt(st),at.updateMatrixWorld();let le=1/0,ke=-1/0,He=1/0,Pe=-1/0;for(let j of $){let Qe=Kc.copy(j).project(at),En=(Qe.x*.5+.5)*L,vn=(-Qe.y*.5+.5)*O;le=Math.min(le,En),ke=Math.max(ke,En),He=Math.min(He,vn),Pe=Math.max(Pe,vn)}de*=Math.max((ke-le)/(L-120),(Pe-He)/Math.max(120,ne-Xt))*1.12}return Us.d=Math.max(8,de),Us.fy=(Xt+ne)/2,Us}function xo(){let A=[V(ht,Ot(),ot),V(K,Ot(),ot)];for(let Ct of ut.values())if(C.has(Ct.m.id)){let Xt=Ds(Ct);A.push(Xt.clone().add(V(0,2.2,0)),Xt.clone().add(V(0,-2.4,0)))}let k=vs(),$=P()?xt:U,X=gt.clone();X.aspect=L/O,X.clearViewOffset(),X.updateProjectionMatrix();let dt=40,st;for(let Ct=0;Ct<6;Ct++){X.position.set(Ci.x+dt*Math.sin($.yaw)*Math.cos($.pitch),Ci.y+dt*Math.sin($.pitch),Ci.z+dt*Math.cos($.yaw)*Math.cos($.pitch)),X.lookAt(Ci),X.updateMatrixWorld();let Xt=A.map(ne=>{let Se=ne.clone().project(X);return[(Se.x*.5+.5)*L,(-Se.y*.5+.5)*O]});st={x0:Math.min(...Xt.map(ne=>ne[0])),x1:Math.max(...Xt.map(ne=>ne[0])),y0:Math.min(...Xt.map(ne=>ne[1])),y1:Math.max(...Xt.map(ne=>ne[1]))},dt*=Math.max((st.x1-st.x0)/(k.r-k.x),(st.y1-st.y0)/(k.b-k.y))*1.02}zt={d:dt,ox:(st.x0+st.x1)/2-(k.x+k.r)/2,oy:(st.y0+st.y1)/2-(k.y+k.b)/2-(P()?24:0)}}function M(){L=t.clientWidth,O=t.clientHeight,!(!L||!O)&&(lt.setSize(L,O),gt.aspect=L/O,gt.updateProjectionMatrix(),an.setSize(L,O),Fn.resolution.set(L,O),zt=null,tt++,w.models.length&&iu())}let H=new ResizeObserver(M);H.observe(t),M();let Y=lt.domElement,Z=new Ga,J=new yt,Vt=A=>{let k=Y.getBoundingClientRect();J.set((A.clientX-k.left)/k.width*2-1,-((A.clientY-k.top)/k.height)*2+1),Z.setFromCamera(J,gt);let $=[...ut.values()].filter(dt=>C.has(dt.m.id)).map(dt=>dt.hit),X=Z.intersectObjects($)[0];return X?[...ut.values()].find(dt=>dt.hit===X.object).m.id:null},qt=A=>i.onSelect?.(A===I?null:A),Pt={zoom:!!i.controls?.zoom,pan:!!i.controls?.pan},Qt=Gc(),Yt=Gc(),_e={x:0,y:0},Ee=null,te=()=>Object.assign(Yt,Gc());(Pt.zoom||Pt.pan)&&(s.style.touchAction="none");let Me=new Map,Ue=null,$e=()=>{let[A,k]=[...Me.values()];return{dist:Math.max(1,Math.hypot(A.x-k.x,A.y-k.y)),mid:{x:(A.x+k.x)/2,y:(A.y+k.y)/2}}},ze=A=>{let k=Y.getBoundingClientRect();return{x:A.clientX-k.left,y:A.clientY-k.top}},un=A=>{if(A.pointerType==="touch"&&(Pt.zoom||Pt.pan)){if(Me.set(A.pointerId,ze(A)),Me.size===2){ue.drag=null,s.classList.remove("dragging"),Ue={...$e(),view:{...Yt}};return}if(Me.size>2)return}ue.drag={x:A.clientX,y:A.clientY,yaw:ue.yaw,pitch:ue.pitch,still:!0,pan:Pt.pan&&!A.shiftKey,panX:Yt.panX,panY:Yt.panY},Y.setPointerCapture(A.pointerId),s.classList.add("dragging")},Zt=A=>{if(Me.has(A.pointerId)&&Me.set(A.pointerId,ze(A)),Ue&&Me.size>=2){let k=$e(),$=Pt.zoom?kh(Ue.view,k.dist/Ue.dist,Ue.mid,_e,L,O):{...Ue.view};Pt.pan&&($.panX+=k.mid.x-Ue.mid.x,$.panY+=k.mid.y-Ue.mid.y),Object.assign(Yt,Wc($,L,O));return}if(ue.drag){if(Math.hypot(A.clientX-ue.drag.x,A.clientY-ue.drag.y)>4&&(ue.drag.still=!1),!ue.drag.still){if(ue.drag.pan){Object.assign(Yt,Wc({zoom:Yt.zoom,panX:ue.drag.panX+(A.clientX-ue.drag.x),panY:ue.drag.panY+(A.clientY-ue.drag.y)},L,O));return}ue.yaw=ue.drag.yaw-(A.clientX-ue.drag.x)*.005,ue.pitch=Math.min(.9,Math.max(-.05,ue.drag.pitch+(A.clientY-ue.drag.y)*.0035)),ue.vy=ue.vp=0}return}A.pointerType!=="touch"&&(v=Vt(A),s.classList.toggle("over",!!v))},_n=A=>{if(Me.delete(A.pointerId)&&Ue){Me.size<2&&(Ue=null);return}let k=ue.drag;if(ue.drag=null,s.classList.remove("dragging"),k?.still){let $=Vt(A);$?qt($):I&&!P()&&i.onSelect?.(null)}},Ce=A=>{Me.delete(A.pointerId),Me.size<2&&(Ue=null),ue.drag=null,s.classList.remove("dragging")},On=()=>{ue.drag||(v=null)},Hn=A=>{A.preventDefault();let k=A.deltaY*(A.deltaMode===1?16:A.deltaMode===2?O:1);Object.assign(Yt,kh(Yt,Math.exp(-k*.0015),ze(A),_e,L,O))},ii=A=>{A.preventDefault(),te()};Y.addEventListener("pointerdown",un),Y.addEventListener("pointermove",Zt),Y.addEventListener("pointerup",_n),(Pt.zoom||Pt.pan)&&Y.addEventListener("pointercancel",Ce),Y.addEventListener("pointerleave",On),Pt.zoom&&Y.addEventListener("wheel",Hn,{passive:!1}),(Pt.zoom||Pt.pan)&&Y.addEventListener("dblclick",ii);let Ii=A=>{A.preventDefault(),i.onFail?.()};Y.addEventListener("webglcontextlost",Ii);let Fe="",Ne=new D,si=new D(0,1,0),qe=new D,xi=new D,Ji={x:0,y:0,z:0},rn=(A,k=Ji)=>(Ne.copy(A).project(gt),k.x=(Ne.x*.5+.5)*L,k.y=(-Ne.y*.5+.5)*O,k.z=Ne.z,k),Fs=null,tu=A=>{if(Fs||!t.contains(A.target)||o.contains(A.target)||p(A.target))return;let k=null,$=12;for(let X of r.querySelectorAll(".plate")){let dt=X.getBoundingClientRect(),st=Math.max(dt.left-A.clientX,0,A.clientX-dt.right),Ct=Math.max(dt.top-A.clientY,0,A.clientY-dt.bottom),Xt=Math.hypot(st,Ct);Xt<=$&&($=Xt,k=X)}k&&(Fs={id:k.dataset.id,x:A.clientX,y:A.clientY})},eu=A=>{let k=Fs;Fs=null,k&&Math.hypot(A.clientX-k.x,A.clientY-k.y)<14&&qt(k.id)},nu=()=>Fs=null;addEventListener("pointerdown",tu,!0),addEventListener("pointerup",eu),addEventListener("pointercancel",nu);let Qc=new D,_o={x:0,y:0,z:0},t0={x:0,y:0,z:0};function lp(){Qc.setFromMatrixColumn(gt.matrixWorld,0);let A=[];for(let k of ut.values()){if(!C.has(k.m.id)||!k.screen)continue;let $=k.root.scale.y,X=k.root.position.x,dt=k.root.position.y,st=k.root.position.z,Ct=rn(Ne.set(X,dt+1.6*$,st),_o);if(Ct.z>=1)continue;let Xt=Ct.x,ne=Ct.y,Se=rn(Ne.set(X,dt-1.24*$,st),_o),at=Se.x,de=Se.y,ce=rn(Ne.set(X,dt,st),_o).x,le=Math.abs(rn(Ne.set(X,dt,st).addScaledVector(Qc,(k.span||.3)*$),t0).x-ce);A.push({id:k.m.id,x:Math.min(Xt,at)-le,y:ne,w:Math.abs(Xt-at)+le*2,h:de-ne,nx:Xt,ny:ne})}return A}function cp(A,k,$){let X=[];for(let dt of St){let st=dt.el,Ct=rn(dt.v,_o);if(st.classList.contains("next")){P()?(Ct.x=18,Ct.y=$.y-26):Ct.y=Math.max(Ct.y,128),st.style.transform=`translate(${Ct.x}px, ${Ct.y}px)`,st.style.opacity=Ct.z<1?A*(1-wn):0;continue}let Xt=Ct.x,ne=Ct.y,Se=Ct.z<1&&A*(1-wn)>.3;if(st.style.opacity=Ct.z<1?A*(1-wn):0,dt.radius&&Se){let Ze=Math.abs(rn(Ne.copy(dt.v).addScaledVector(Qc,dt.radius),t0).x-Xt);X.push({x:Xt-Ze,y:ne-Ze,w:Ze*2,h:Ze*2})}dt.epoch!==tt&&(dt.w=dt.h=0),dt.epoch=tt;let at=dt.w||(dt.w=st.offsetWidth),de=dt.h||(dt.h=st.offsetHeight);if(!at){st.style.transform=`translate(${Xt}px, ${ne}px)`;continue}let ce=dt.radius?{x:Xt+20,y:ne-de/2}:{x:Xt+2,y:ne-de-4},le=rn(dt.far,t0),ke=Math.max(le.x+4,$.x+8),He=Math.abs(Xt-le.x)>1?(ke-le.x)/(Xt-le.x):0,Pe={x:ke,y:le.y+He*(ne-le.y)-de-3},j=Ze=>k.reduce((Pi,In)=>Pi+(Ze.x<In.x+In.w+4&&In.x<Ze.x+at+4&&Ze.y<In.y+In.h*1.4&&In.y<Ze.y+de+2?2:0)+(Math.abs(In.ny-(Ze.y+de/2))<de/2+18&&Ze.x<In.nx+212&&In.nx-212<Ze.x+at?1:0),0)+(Ze.x<$.x-10||Ze.x+at>$.r+10?2:0),Qe=j(ce),En=j(Pe);!dt.atFar&&Qe>0&&En<Qe&&le.z<1?dt.atFar=!0:dt.atFar&&(Qe===0||En>Qe)&&(dt.atFar=!1),st.classList.toggle("far",dt.atFar);let vn=dt.atFar?Pe:ce;st.style.transform=dt.atFar?`translate(${Pe.x}px, ${Pe.y}px)`:`translate(${Xt}px, ${ne}px)`,Se&&X.push({x:vn.x,y:vn.y,w:at,h:de})}return X}function hp(A,k){let $=w.models.filter(at=>C.has(at.id)&&S[at.id]).sort((at,de)=>S[de.id][1]-S[at.id][1]),X=$.map(at=>at.id+S[at.id][0]+c).join("|");X!==Fe&&(r.querySelectorAll(".plate").forEach(at=>at.remove()),a.replaceChildren(),$.forEach((at,de)=>{let ce=S[at.id],le=document.createElement("div");le.className="plate",le.dataset.id=at.id,le.style.setProperty("--c",at.colour);let ke=/^(Claude|DeepSeek|Kimi)\s/.exec(at.name)?.[0]??"";le.innerHTML=`<span class="rank">${de+1}</span><span class="lg">${e(at.dev)}</span><b><span class="nf">${Br(ke)}</span>${Br(at.name.slice(ke.length))}${at.racer?`<i class="rz" title="${l()?"\u7ADE\u901F\uFF1A\u5B8C\u5DE5\u5FEB\u4E14\u51FA\u5B57\u5FEB":"Racer: fast tasks and fast output"}">\u26A1</i>`:""}</b><span class="lcdc"><span class="v">${ce[1].toFixed(1)}</span><span class="ef">${Br(ce[0])}${ce[0]===at.rec?"<i>\u2605</i>":""}</span></span>`,le.title=`${at.name} \xB7 ${ce[0]} \xB7 ${ce[1].toFixed(1)}`,le.onmouseenter=()=>v=at.id,le.onmouseleave=()=>v=null,le.onpointerdown=Pe=>{Fs={id:at.id,x:Pe.clientX,y:Pe.clientY}},r.appendChild(le);let He=document.createElementNS(Of,"line");He.setAttribute("stroke",at.colour),a.appendChild(He),le.leader=He}),Fe=X);let dt=vs(),st=[],Ct=lp(),Xt=cp(k,Ct,dt);globalThis.__mpLabelProbe&&(globalThis.__mpLabelProbe.fixed=Xt);let ne=[...r.querySelectorAll(".plate")].map(at=>({p:at,r:ut.get(at.dataset.id)})).filter(at=>at.r?.screen),Se=P()?6:9;ne.forEach(({p:at,r:de},ce)=>{let le=at.dataset.id,ke=A===le;at.classList.toggle("hot",ke);let He=at.classList.contains("dot"),Pe=at.classList.contains("tight"),j=at.offsetHeight,Qe=de.screen.x,En=de.screen.y;!He&&!Pe&&(at._full=at.offsetWidth,at._lead=at.querySelector(".nf")?.offsetWidth??0);let vn=at._full??at.offsetWidth,Ze=(Xe,dn,fn)=>st.find(Ve=>Xe<Ve.x+Ve.w+4&&Ve.x<Xe+fn+4&&dn<Ve.y+Ve.h+3&&Ve.y<dn+j+3)??Xt.find(Ve=>Xe<Ve.x+Ve.w+2&&Ve.x<Xe+fn+2&&dn<Ve.y+Ve.h+2&&Ve.y<dn+j+2),Pi=(Xe,dn)=>{let fn=Math.max(En-j/2,...st.filter(Ve=>Xe<Ve.x+Ve.w+30&&Ve.x<Xe+dn+30).map(Ve=>Ve.y+2));for(let Ve=0;Ve<60;Ve++){let Pn=Ze(Xe,fn,dn);if(!Pn)return fn;fn=Pn.y+Pn.h+(Pn.chip?3:2)+.01}return fn},In=(Xe,dn,fn)=>{let Ve=Xe+fn/2<Qe?Xe+fn:Xe,Pn=Math.max(dn+4,Math.min(dn+j-4,En)),Xr=Math.hypot(Ve-Qe,Pn-En),yo=Xr*.6+Math.max(0,Xr-120)*2.5;for(let Ln of Ct){let ks=Math.min(Xe+fn,Ln.x+Ln.w)-Math.max(Xe,Ln.x),uu=Math.min(dn+j,Ln.y+Ln.h)-Math.max(dn,Ln.y);if(ks<=0||uu<=0)continue;let du=ks*uu;yo+=Ln.id===le?400:Math.min(1,du/260)*60+du/j*2.2+(Ln.nx>Xe&&Ln.nx<Xe+fn&&Ln.ny>dn-4&&Ln.ny<dn+j?90:0)}return yo},Ki=(Xe,dn,fn,Ve)=>{for(let Pn of[1,-1])fn.forEach((Xr,yo)=>{let Ln=Pn>0?Math.min(dt.r+10-Xe,Qe+Xr):Math.max(dt.x-10,Qe-Xr-Xe),ks=Pi(Ln,Xe);Ve.push({x:Ln,y:ks,w:Xe,tight:dn,slot:Pn*(yo+1),cost:In(Ln,ks,Xe)+(Pn<0?4:0)+(dn?10:0)+(Ze(Ln,ks,Xe)?1e3:0)})});return Ve},Li=(Xe,dn)=>{let fn=Xe[0];for(let Pn of Xe)Pn.cost<fn.cost&&(fn=Pn);let Ve=Xe.find(Pn=>Pn.slot===at._slot&&Pn.tight===dn);return Ve&&Ve.cost<=fn.cost+30?Ve:fn},Hr=[12,34,60,92,130],Vr=Ki(vn,!1,Hr,[]);at._lead>0&&!ke&&Ki(vn-at._lead,!0,Hr,Vr);let We=Li(Vr,Pe&&!He),Ni=!ke&&ce>=Se&&We.cost>(He?125:180);Ni&&(We=Li(Ki(at._dot??j,!1,[8,22],[]),!1)),Ni!==He&&at.classList.toggle("dot",Ni),Ni&&He&&(at._dot=at.offsetWidth);let Bn=!Ni&&We.tight;Bn!==Pe&&at.classList.toggle("tight",Bn),at._slot=We.slot;let Vn=We.w;st.push({x:We.x,y:We.y,w:Vn,h:j,chip:!0}),globalThis.__mpLabelProbe&&(at._pick=We),at._x=at._x==null||Math.abs(at._x-We.x)>80?We.x:at._x+(We.x-at._x)*.25,at._y=at._y==null||Math.abs(at._y-We.y)>80?We.y:at._y+(We.y-at._y)*.25,at.style.transform=`translate(${at._x}px, ${at._y}px)`;let ri=A&&A!==at.dataset.id&&Ct.find(Xe=>Xe.id===A),Gr=ri&&at._x<ri.x+ri.w+6&&ri.x-6<at._x+Vn&&at._y<ri.y+ri.h&&ri.y<at._y+j,Bs=Gr?.04:A&&!ke?I?.42:.22:Math.min(1,Math.max(0,(performance.now()-de.born-1200)/600));at.style.opacity=Bs,at.style.pointerEvents=Gr&&!I?"none":"";let ji=at._x+Vn/2<Qe,zs=ji?at._x+Vn:at._x,yn=at._y+j/2,Qi=Math.hypot(zs-Qe,yn-En)>16,Wr=at.leader;Wr.setAttribute("x1",Qe+(ji?-4:4)),Wr.setAttribute("y1",En),Wr.setAttribute("x2",zs),Wr.setAttribute("y2",yn),Wr.style.opacity=Qi?Bs*.6:0});for(let at of he){let de=rn(at.v);at.el.style.transform=`translate(${de.x}px, ${de.y}px)`,at.el.style.opacity=de.z<1?k*(1-wn):0}for(let at of ye){let de=rn(at.v);at.el.style.transform=`translate(${de.x}px, ${de.y}px)`}}let vo=[];function iu(){if(W)return;let A=st=>Oh(st,f),k=w.models.filter(st=>C.has(st.id)&&S[st.id]).sort((st,Ct)=>S[Ct.id][1]-S[st.id][1]),$=k.length?S[k[0].id][1]:0;o.style.left=(i.gaugeLeft?i.gaugeLeft():x().left-92)+"px";let X=`<div class="vbar"></div><div class="lead">${l()?`\u9886\u5148 ${$.toFixed(1)} \xB7 \u8DDD\u661F\u8FB0\u5927\u6D77 ${(d-$).toFixed(1)}`:`Leader ${$.toFixed(1)} \xB7 ${(d-$).toFixed(1)} to the stars`}</div><div class="vwin" style="bottom:${A(Lt)}%;height:${A(et)-A(Lt)}%" title="${l()?"3D \u89C6\u91CE\u91CC\u7684\u5206\u6570\u6BB5":"Score band shown in 3D"}"></div>`;X+=u.map(st=>`<div class="vt ${st.final?"agi":""}" style="bottom:${A(st.at)}%"><b>${st.final?l()?`\u2605 ${st.zh}`:`\u2605 ${st.en}`:l()?st.zh:st.en}</b>${st.at}</div>`).join("");let dt=[];X+=k.map(st=>{let Ct=S[st.id][1],Xt=dt.filter(ne=>Math.abs(ne-Ct)<.9).length;return dt.push(Ct),`<span class="vdot" data-id="${Br(st.id)}" style="--c:${st.colour};bottom:${A(Ct)}%;left:${11-Xt*9}px" title="${Br(st.name)} \xB7 ${Ct.toFixed(1)}"></span>`}).join(""),o.innerHTML=X,vo=[...o.querySelectorAll(".vdot")],vo.forEach(st=>{st.onmouseenter=()=>v=st.dataset.id,st.onmouseleave=()=>v=null,st.onclick=()=>qt(st.dataset.id)})}let zr=[];function up(A){for(let k of w.models){if(!C.has(k.id)||!S[k.id])continue;let $=A[k.id],X=S[k.id][1],dt=ut.get(k.id);if($==null||X<=$||!dt)continue;let st=u.filter(Ct=>Ct.at>$&&Ct.at<=X).pop();st&&(dt.cross=st)}}let su=new qi(1,.035,8,96);function dp(A,k){let $=new we(su,new hn({color:k.final?"#ffd37a":"#9fd8ff",transparent:!0,blending:pn,depthWrite:!1}));$.position.copy(A.root.position),$.rotation.x=Math.PI/2,ct.add($);let X=document.createElement("div");X.className="burst",X.textContent=k.final?l()?"\u2605 \u9A76\u51FA\u592A\u9633\u7CFB \xB7 \u5954\u5411\u661F\u8FB0\u5927\u6D77":"\u2605 Leaving the solar system \xB7 out to the stars":l()?`\u2726 \u8D8A\u8FC7${k.zh}`:`\u2726 Past ${k.en}`,r.appendChild(X),zr.push({ring:$,el:X,r:A,t0:performance.now()})}function fp(A){for(let k=zr.length-1;k>=0;k--){let $=zr[k],X=(A-$.t0)/1400;if(X>=1){ct.remove($.ring),$.ring.material.dispose(),$.el.remove(),zr.splice(k,1);continue}let dt=1-Math.pow(1-X,3);$.ring.scale.setScalar(.4+dt*3.2),$.ring.material.opacity=(1-X)*.9;let st=rn(Ne.copy($.r.root.position).addScaledVector(si,1.9));$.el.style.transform=`translate(${st.x}px, ${st.y-dt*26}px)`,$.el.style.opacity=X<.15?X/.15:1-Math.max(0,(X-.6)/.4)}}let Os=0,e0=performance.now(),n0=e0,i0=!1,s0=0,ru=!0,au=!1,kr=0,r0=0,ou=0,lu=!i.onSlow,cu=new IntersectionObserver(([A])=>ru=A?.isIntersecting??!0);cu.observe(t);function hu(A){if(s0=requestAnimationFrame(hu),document.hidden||!ru||!L||!w.models.length){kr=0;return}!lu&&i0&&A-e0>1500&&(kr&&A-kr<1e3&&(r0+=A-kr,ou++),kr=A,r0>=3e3&&(lu=!0,ou*1e3/r0<20&&i.onSlow()));let k=A/1e3,$=b?1:Math.min(1,(A-n0)/1800),X=I??v??R;if(!ue.drag||ue.drag.still){let j=P()?xt:U,Qe=b||X?0:Math.sin(k/3.6)*.03;ue.vy=ue.vy*.85+(j.yaw+Qe-ue.yaw)*.03,ue.yaw+=ue.vy,ue.vp=ue.vp*.85+(j.pitch-ue.pitch)*.03,ue.pitch+=ue.vp}if(zt||xo(),!$t)$t={...zt};else if(b)Object.assign($t,zt);else for(let j of["d","ox","oy"])$t[j]+=(zt[j]-$t[j])*.06;let dt=I&&C.has(I)&&ut.get(I),st=vs();wn+=((dt?1:0)-wn)*(b?1:.06);let Ct=P()&&dt?jc(dt):null;Zi.lerp(Ct?Ct.look:dt?qe.copy(dt.root.position).addScaledVector(si,.3):Ci,b?1:.08);let Xt=b?1:Math.min(1,(A-n0)/5200),ne=1-Math.pow(1-Xt,3),Se=ue.pitch-.07*(1-ne);Os*=.93;let at=Ct?Ct.fy:(st.y+st.b)/2;I!==Ee&&(Ee=I,te()),Ff(Qt,Yt,b);let de=Ct?Ct.d:Math.min(26,$t.d*.55),ce=($t.d+(de-$t.d)*wn)*(1-.2*(1-ne))/Qt.zoom,le=$t.ox+(L/2-(st.x+st.r)/2-$t.ox)*wn-Qt.panX,ke=$t.oy+(O/2-at-$t.oy)*wn-Qt.panY;_e.x=L/2-le,_e.y=O/2-ke,gt.position.set(Zi.x+ce*Math.sin(ue.yaw)*Math.cos(Se),Zi.y+ce*Math.sin(Se),Zi.z+ce*Math.cos(ue.yaw)*Math.cos(Se)),gt.lookAt(Zi),Os>.01&&gt.position.add(xi.set(Math.sin(k*61),Math.sin(k*47+1),Math.sin(k*53+2)).multiplyScalar(.007*ce*Os)),gt.setViewOffset(L,O,le,ke,L,O),Fn.strength=.8-.38*wn+.55*Os,lt.toneMappingExposure=1.05-.15*wn,_.update(b?0:k),rt.uniforms.t.value=k,Rt.children.forEach(j=>{j.userData.spin&&(j.rotation.y=k*.15)}),X!==xe&&me(X);let He=(P()?.68:.88)*y,Pe=E?0:k;for(let j of ut.values()){let Qe=C.has(j.m.id)&&!!S[j.m.id];if(Qe||(j.soot.visible=!1),j.root.visible=j.trail.visible=j.drop.visible=j.pad.visible=j.padGlow.visible=j.smoke.visible=Qe,!Qe)continue;j.pos.lerp(j.tgt,b?1:.08),j.flare+=(1-j.flare)*.035;let En=A-j.born,vn=b?1:Math.max(0,Math.min(1,En/650)),Ze=b?1:Math.max(0,Math.min(1,(En-550)/2400)),Pi=Ze<.5?4*Ze**3:1-Math.pow(-2*Ze+2,3)/2,In=vn*(1-Ze),Ki=vn*(1-Pi),Li=Ot(),Hr=Li+1.5+(j.pos.y-1.5)*Pi,Vr=S[j.m.id],We=Math.max(.15,Math.min(1,(Math.log10(Vr[2])+2.2)/2.8))*j.flare+In*.9,Ni=X===j.m.id||v===j.m.id,Bn=X&&!Ni?.2:1;j.root.position.set(j.pos.x,Hr+(b?0:Math.sin(k*1.1+j.phase)*.06),j.pos.z),Be(j);let Vn=j.m.id===jt;j.heavy.visible=Vn;let ri=!Vn&&j.m.racer;j.racer.visible=ri,j.stdParts.forEach(yn=>yn.visible=!Vn);let Gr=Vn?j.steelMap:ri?j.boltMap:j.hullMap;j.steel.metalness=Vn?.92:.35,j.steel.roughness=Vn?.2:.34,j.steel.map!==Gr&&(j.steel.map=Gr,j.steel.needsUpdate=!0),ri&&j.streaks.forEach(yn=>{let Qi=b?yn.userData.o:(k*1.6+yn.userData.o)%1;yn.position.y=1.2-Qi*2.8,yn.material.opacity=.65*Math.sin(Qi*Math.PI)*Bn});let Bs=Vn?j.heavyNozzle:j.NOZZLE_Y;j.outer.position.y=j.inner.position.y=Bs+.02,j.light.position.y=Bs-.45,j.halo&&(j.halo.rotation.y=b?0:k*.7),j.root.scale.setScalar(He*(Ni?1.12:1)*(Vn?1.18:1));{let yn=I===j.m.id||j.m.id===jt?ue.yaw-.4*Math.PI:k*.12+j.phase,Qi=j.g.rotation.y;j.g.rotation.y=Qi+Math.atan2(Math.sin(yn-Qi),Math.cos(yn-Qi))*(b?1:.08)}j.g.rotation.z=b?0:Math.sin(k*.7+j.phase)*.02,j.mats.forEach(yn=>yn.opacity=Bn),j.outer.material.uniforms.t.value=j.inner.material.uniforms.t.value=j.trail.material.uniforms.t.value=j.soot.material.uniforms.t.value=Pe;for(let yn of j.bOuter)yn.material.uniforms.t.value=Pe,yn.material.uniforms.k.value=Bn*(.15+.85*vn),yn.scale.set(.8+We*.6,.6+We*1.2,.8+We*.6);j.outer.material.uniforms.k.value=j.inner.material.uniforms.k.value=Bn*(.15+.85*vn),j.trail.material.uniforms.k.value=Bn*.8*vn,j.outer.scale.set((.8+We*.6)*(j.racer.visible?.75:1),(.6+We*1.2)*(j.racer.visible?1.45:1),(.8+We*.6)*(j.racer.visible?.75:1)),j.inner.scale.set(1,.7+We*.6,1),j.light.intensity=(.6+We*1.4)*Bn,j.ring.visible=Ni&&I!==j.m.id&&Vr[0]===j.m.rec,j.ring.quaternion.copy(gt.quaternion),j.ring.material.opacity=Bn;let ji=j.root.position.y+Bs*j.root.scale.y,zs=Math.max(.05,ji-Li);j.trail.position.set(j.pos.x,ji-.3,j.pos.z),j.trail.scale.set(.5+We*.8,Math.max(.05,Math.min(zs-.3,2.6+We*1.2)),.5+We*.8),j.soot.visible=j.fuelKind==="lo",j.soot.position.set(j.pos.x,ji-.5,j.pos.z),j.soot.scale.set(.55+We*.5,Math.max(.05,Math.min(zs-.5,1.6+We*.9)),.55+We*.5),j.soot.material.uniforms.k.value=Bn*vn,j.drop.position.set(j.pos.x,ji,j.pos.z),j.drop.scale.y=zs,j.drop.material.opacity=.22*Bn,j.pad.position.set(j.pos.x,Li+.02,j.pos.z),j.pad.material.opacity=.7*Bn,j.padGlow.position.set(j.pos.x,Li+.1,j.pos.z),j.padGlow.scale.setScalar(1.4+3.2*Ki),j.padGlow.material.opacity=Bn*Math.max(.3*Pi,.7*Ki),j.smoke.position.set(j.pos.x,Li+.5+Ze*.8,j.pos.z),j.smoke.scale.setScalar(1.2+2.5*vn+4.5*Ze),j.smoke.material.opacity=.3*Ki*Bn,j.smoke.visible=Ki>0,j.cross&&Ze>=1&&Hr-Li>=nt(j.cross.at)-.05&&(j.cross.at>=Lt-.01&&dp(j,j.cross),j.cross=null),j.screen=rn(Ne.set(j.pos.x,j.root.position.y+1.2*j.root.scale.y,j.pos.z),j.screen),rn(Ne.set(j.pos.x,ji-.8,j.pos.z),j.base)}Ke.children.forEach(j=>{j.userData.bill&&j.quaternion.copy(gt.quaternion)}),fp(A),an.render(),hp(X,$),vo.forEach(j=>j.classList.toggle("hot",j.dataset.id===X)),i.onFrame?.()}if(s0=requestAnimationFrame(hu),globalThis.__mpLabelProbe){let A=new D,k=new Jn,$=new D,X=st=>({x:+st.x.toFixed(1),y:+st.y.toFixed(1),w:+st.w.toFixed(1),h:+st.h.toFixed(1)}),dt=(st,Ct)=>{let Xt=st.getBoundingClientRect();return X({x:Xt.left-Ct.left,y:Xt.top-Ct.top,w:Xt.width,h:Xt.height})};Object.assign(globalThis.__mpLabelProbe,{view:()=>({yaw:ue.yaw,pitch:ue.pitch,W:L,H:O,narrow:P(),region:vs(),zoom:wn}),boxes(){let st=t.getBoundingClientRect(),Ct=[...r.querySelectorAll(".plate")].map(at=>({id:at.dataset.id,opacity:+at.style.opacity||0,collapsed:at.classList.contains("dot"),tight:at.classList.contains("tight"),target:at._pick&&{x:Math.round(at._pick.x),y:Math.round(at._pick.y),w:Math.round(at._pick.w),cost:Math.round(at._pick.cost),slot:at._pick.slot},...dt(at,st)})),Xt=[...r.querySelectorAll(".ltag, .tick3")].map(at=>({kind:at.classList.contains("tick3")?"tick":at.classList.contains("next")?"next":"orbit",text:at.textContent,opacity:+getComputedStyle(at).opacity||0,...dt(at,st)})),ne=[];Rt.children.forEach(at=>{if(!at.userData.spin)return;at.geometry.computeBoundingSphere(),k.copy(at.geometry.boundingSphere).applyMatrix4(at.matrixWorld);let de=rn(k.center),ce=de.x,le=de.y,ke=de.z;$.setFromMatrixColumn(gt.matrixWorld,0);let He=rn(A.copy(k.center).addScaledVector($,k.radius)),Pe=Math.hypot(He.x-ce,He.y-le);ke<1&&ne.push(X({x:ce-Pe,y:le-Pe,w:Pe*2,h:Pe*2}))});let Se=[];for(let at of ut.values()){if(!C.has(at.m.id))continue;at.root.updateWorldMatrix(!0,!1);let de=(at.span||.3)*at.root.scale.x,ce=rn(A.set(0,1.6,0).applyMatrix4(at.root.matrixWorld)),le=ce.x,ke=ce.y,He=ce.z,Pe=rn(A.set(0,-1.24,0).applyMatrix4(at.root.matrixWorld)),j=Pe.x,Qe=Pe.y;$.setFromMatrixColumn(gt.matrixWorld,0);let En=A.set(0,.18,0).applyMatrix4(at.root.matrixWorld).clone(),vn=rn(En),Ze=vn.x,Pi=rn(En.addScaledVector($,de)),In=Math.abs(Pi.x-Ze);He<1&&Se.push({id:at.m.id,nose:{x:+le.toFixed(1),y:+ke.toFixed(1)},depth:+He.toFixed(4),...X({x:Math.min(le,j)-In,y:ke,w:Math.abs(le-j)+In*2,h:Qe-ke})})}return{chips:Ct,tags:Xt,planets:ne,hulls:Se}}})}return{update(A){let k=Object.fromEntries(Object.entries(S).map(([st,Ct])=>[st,Ct[1]])),$=C,X=A.language!=null&&A.language!==c;X&&(c=A.language,h()),A.axis!==void 0&&(m=A.axis),w={models:A.models};for(let st of Object.keys(S))delete S[st];for(let st of A.models)st.sel&&(S[st.id]=st.sel);C=new Set(A.shown.filter(st=>S[st])),A.focus!==void 0?I=A.focus&&C.has(A.focus)?A.focus:null:I&&!C.has(I)&&(I=null),R=A.hint&&C.has(A.hint)?A.hint:null;let dt=performance.now();if(i0){let st=[...C].filter(Ct=>!$.has(Ct));be(),st.forEach((Ct,Xt)=>{let ne=ut.get(Ct);ne&&(ne.born=dt+Xt*120)}),up(k)}else{e0=dt;let st=Bf;n0=st?dt-6e3:dt,be(),w.models.filter(Ct=>C.has(Ct.id)).sort((Ct,Xt)=>S[Xt.id][1]-S[Ct.id][1]).forEach((Ct,Xt)=>ie(Ct).born=st?dt-4e3:dt+700+Xt*300),i0=Bf=!0}X&&(Fe="")},thrust(){E||(Os=1)},setOptions(A){A.reducedMotion!==void 0&&(b=A.reducedMotion??matchMedia("(prefers-reduced-motion: reduce)").matches,E=A.reducedMotion===!0,E&&(Os=0)),A.rocketScale!==void 0&&(y=A.rocketScale??1)},setSelection(A){I=A&&C.has(A)?A:null},resetView(){te()},dispose(){if(!au){au=!0,cancelAnimationFrame(s0),H.disconnect(),cu.disconnect(),removeEventListener("pointerdown",tu,!0),removeEventListener("pointerup",eu),removeEventListener("pointercancel",nu);for(let A of ut.values()){A.mats.forEach(k=>k.dispose()),A.halo?.traverse(k=>{k.geometry?.dispose(),k.material?.dispose()}),A.root.traverse(k=>{k.isInstancedMesh&&k.dispose(),k.geometry?.dispose();for(let $ of Array.isArray(k.material)?k.material:k.material?[k.material]:[]){for(let X of Object.values($))X?.isTexture&&X!==ae&&X.dispose();$.dispose()}});for(let k of[A.trail,A.soot,A.drop,A.pad,A.padGlow,A.smoke])k.material.dispose(),k.geometry!==Dt&&k.geometry!==kt&&k.geometry?.dispose()}Dt.dispose(),kt.dispose(),su.dispose(),Tt(Rt),Tt(Jt),Tt(Ke),_.dispose(),T.dispose(),bt.forEach(A=>A.dispose()),ct.traverse(A=>{A.geometry?.dispose(),A.material?.dispose?.()}),an.passes.forEach(A=>A.dispose()),Fn.materialHighPassFilter.dispose(),an.dispose(),Y.removeEventListener("pointerdown",un),Y.removeEventListener("pointermove",Zt),Y.removeEventListener("pointerup",_n),Y.removeEventListener("pointerleave",On),Y.removeEventListener("pointercancel",Ce),Y.removeEventListener("wheel",Hn),Y.removeEventListener("dblclick",ii),Y.removeEventListener("webglcontextlost",Ii),Me.clear(),lt.forceContextLoss(),lt.dispose(),ct.clear(),ut.clear(),bt.length=0,St.length=he.length=ye.length=zr.length=0,vo.length=0,s.remove(),r.remove(),o.remove(),s.replaceChildren(),r.replaceChildren(),o.replaceChildren()}}}}var zf={height:47,scales:[2,3],sprites:{"cz2f-alibaba":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-alibaba":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-alibaba":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-alibaba":{w:20,h:48,ax:10,tip:1,nz:48},"falcon9-anthropic":{w:12,h:49,ax:6,tip:1,nz:48},"newGlenn-anthropic":{w:14,h:49,ax:7,tip:1,nz:48},"falconHeavy-anthropic":{w:22,h:49,ax:11,tip:1,nz:48},"vulcan-anthropic":{w:16,h:50,ax:8,tip:1,nz:48},"heavy-anthropic":{w:20,h:48,ax:10,tip:1,nz:48},"cz2f-deepseek":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-deepseek":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-deepseek":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-deepseek":{w:20,h:48,ax:10,tip:1,nz:48},"falcon9-google":{w:12,h:49,ax:6,tip:1,nz:48},"newGlenn-google":{w:14,h:49,ax:7,tip:1,nz:48},"falconHeavy-google":{w:22,h:49,ax:11,tip:1,nz:48},"vulcan-google":{w:16,h:50,ax:8,tip:1,nz:48},"heavy-google":{w:20,h:48,ax:10,tip:1,nz:48},"cz2f-kimi":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-kimi":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-kimi":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-kimi":{w:20,h:48,ax:10,tip:1,nz:48},"falcon9-meta":{w:12,h:49,ax:6,tip:1,nz:48},"newGlenn-meta":{w:14,h:49,ax:7,tip:1,nz:48},"falconHeavy-meta":{w:22,h:49,ax:11,tip:1,nz:48},"vulcan-meta":{w:16,h:50,ax:8,tip:1,nz:48},"heavy-meta":{w:20,h:48,ax:10,tip:1,nz:48},"cz2f-minimax":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-minimax":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-minimax":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-minimax":{w:20,h:48,ax:10,tip:1,nz:48},"falcon9-openai":{w:12,h:49,ax:6,tip:1,nz:48},"newGlenn-openai":{w:14,h:49,ax:7,tip:1,nz:48},"falconHeavy-openai":{w:22,h:49,ax:11,tip:1,nz:48},"vulcan-openai":{w:16,h:50,ax:8,tip:1,nz:48},"heavy-openai":{w:20,h:48,ax:10,tip:1,nz:48},"cz2f-tencent":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-tencent":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-tencent":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-tencent":{w:20,h:48,ax:10,tip:1,nz:48},"cz2f-volcengine":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-volcengine":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-volcengine":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-volcengine":{w:20,h:48,ax:10,tip:1,nz:48},"falcon9-xai":{w:12,h:49,ax:6,tip:1,nz:48},"newGlenn-xai":{w:14,h:49,ax:7,tip:1,nz:48},"falconHeavy-xai":{w:22,h:49,ax:11,tip:1,nz:48},"vulcan-xai":{w:16,h:50,ax:8,tip:1,nz:48},"heavy-xai":{w:20,h:48,ax:10,tip:1,nz:48},"cz2f-xiaomi":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-xiaomi":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-xiaomi":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-xiaomi":{w:20,h:48,ax:10,tip:1,nz:48},"cz2f-zhipuai":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-zhipuai":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-zhipuai":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-zhipuai":{w:20,h:48,ax:10,tip:1,nz:48}}};function kf(i,t,e){let n=[],s=new Map,r=8,a=(o,c,l,h)=>!n.some(f=>o<f.x+f.width+4&&o+l+4>f.x&&c<f.y+f.height+4&&c+h+4>f.y);for(let o of[...i].sort((c,l)=>(c.order??c.y)-(l.order??l.y)||c.id.localeCompare(l.id))){let c=o.order!==void 0&&n.length?n.at(-1).y:r,l=(u,d)=>({x:Math.max(r,Math.min(t-o.width-r,u)),y:Math.max(c,Math.min(e-o.height-r,d))}),h=l(o.x+12,o.y-20),f=!1;for(let u=0;u<18&&!f;u++){let d=u===0?-20:u%2?-20-Math.ceil(u/2)*(o.height+5):-20+Math.ceil(u/2)*(o.height+5);for(let m of[12,-o.width-12]){let x=l(o.x+m,o.y+d);if(a(x.x,x.y,o.width,o.height)){h=x,f=!0;break}}}if(!f){for(let u=c;u<e-o.height-r&&!f;u+=o.height+5)for(let d=r;d<t-o.width-r;d+=o.width+6)if(a(d,u,o.width,o.height)){h={x:d,y:u},f=!0;break}}n.push({...h,width:o.width,height:o.height}),s.set(o.id,h)}return s}var Xc=(i,t,e=0)=>i.left<t.right+e&&t.left<i.right+e&&i.top<t.bottom+e&&t.top<i.bottom+e;function O3(i,t){if(i==="axis")return 0;if(i==="lane")return 4;let e=t.trim(),n=/^(\d+(?:\.\d+)?)×$/.exec(e);if(n){let s=Math.log10(Number(n[1]));return Math.abs(s-Math.round(s))<1e-9?1:3}return/\b1×$/.test(e)?2:3}function Hf(i,t){let e=u=>u.right-u.left<=0,n=u=>Math.min(t.opacityAt(u.left,u.top),t.opacityAt(u.right,u.top),t.opacityAt(u.left,u.bottom),t.opacityAt(u.right,u.bottom))<t.minOpacity,s=[...t.menu?[t.menu]:[],...t.blocks,...i.chips.filter(u=>u.visible).map(u=>u.rect)],r=new Array(i.ticks.length).fill(!1),a=[];i.ticks.map((u,d)=>({i:d,t:u,p:O3(u.cls,u.text)})).sort((u,d)=>u.p-d.p||u.i-d.i).forEach(({i:u,t:d})=>{let m=e(d.rect)||n(d.rect)||s.some(x=>Xc(d.rect,x,6))||a.some(x=>Xc(d.rect,x,8));r[u]=m,m||a.push(d.rect)});let o=u=>!!t.menu&&Xc(u,t.menu,2),c=i.chips.map(u=>o(u.rect)),l=i.orbits.map(o),h=new Array(i.paths.length).fill(!1),f=i.chips.filter(u=>u.hot).map(u=>u.rect);return i.paths.map((u,d)=>({i:d,t:u})).sort((u,d)=>Number(d.t.rec)-Number(u.t.rec)||u.i-d.i).forEach(({i:u,t:d})=>{let m=e(d.rect)||o(d.rect)||f.some(x=>Xc(d.rect,x,3));h[u]=m,m||f.push(d.rect)}),{ticks:r,paths:h,chips:c,orbits:l}}function $c(i,t,e){return i.ability===null||i.cost===null||i.cost<0||!t.costBasisId||i.costBasisId!==t.costBasisId?null:{x:i.cost===0?-9.2:-8+16*(Math.log2(i.cost)-Math.log2(e)-t.costMin)/(t.costMax-t.costMin),y:3+18*(i.ability-t.abilityMin)/(t.abilityMax-t.abilityMin),z:i.time===null?5.7:4-10*i.time/t.timeMax,unknownTime:i.time===null}}function Vh(i,t=ni){let e=new Set(i.shown),n=i.models.filter(a=>e.has(a.id)&&a.sel).map(a=>{let o=a.sel;return{id:a.id,name:a.name,developerId:a.dev,colour:a.colour,ability:o[1],provisional:!1,cost:o[2],costBasisId:"ratio",time:o[3],estimated:o[4],effort:o[0],fuel:a.fuel,shape:a.shape}}),s=n.flatMap(a=>a.cost!==null&&a.cost>0?[Math.log2(a.cost)]:[]),r=i.models.flatMap(a=>a.e.flatMap(o=>o[3]!==null?[o[3]]:[]));return{engines:n,bounds:{costBasisId:"ratio",costMin:Math.min(-1,Math.min(...s)-.5),costMax:Math.max(1,Math.max(...s)+.5),...Dh(n.flatMap(a=>a.ability!==null?[a.ability]:[]),t,i.axis??void 0),timeMax:Math.max(1,...r)},baseline:1,focus:i.focus??null,language:i.language,step:i.axis?.step}}var fo={hi:["#e9f6ff","#6fb8ff"],mid:["#fff1d6","#ff9a4a"],lo:["#d9b49a","#5a3a2c"]},Vf=i=>i.name.replace(/^Claude /,""),Gf=zf.sprites,qc=i=>String(i).replace(/[&<>"]/g,t=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"})[t]),B3=(i,t)=>{let e=`${t?"heavy":i.shape??Nf(i.developerId,i.id)}-${i.developerId}`;return Gf[e]?{key:e,...Gf[e]}:void 0},z3=()=>__LF_ENV__?.BASE_URL??"./";function k3(i,t,e,n,s,r,a){let o=B3(i,s),c=(typeof devicePixelRatio=="number"?devicePixelRatio:1)*r>2?3:2,l=Or(i.developerId,i.colour),h=s?"#c9ced4":l.base,f=s?"#8b929b":l.trim[0]??l.ink,u=s?"#7d848d":l.colour,d=fo[i.fuel],m=Math.min(7,3+Math.sqrt(n)*.8),x=Math.min(46,14+Math.sqrt(n)*5),g=`<g class="rk"><ellipse cx="${t}" cy="${e+47+x*.35}" rx="${m*2.2}" ry="${x*.55}" fill="${d[1]}" opacity=".22" filter="url(#flatBlur)"></ellipse><path d="M${t-m} ${e+44} Q${t-m*.7} ${e+44+x*.6} ${t} ${e+44+x} Q${t+m*.7} ${e+44+x*.6} ${t+m} ${e+44} Z" fill="url(#flame-${i.fuel})"></path>`;return o?g+=`<image href="${qc(`${a}art/rockets/flat/${o.key}@${c}x.webp`)}" x="${t-o.ax}" y="${e+44-o.nz}" width="${o.w}" height="${o.h}"></image>`:g+=`<path d="M${t-4} ${e+37} L${t+4} ${e+37} L${t+5.5} ${e+44} L${t-5.5} ${e+44} Z" fill="url(#flatBell)"></path><path d="M${t-5} ${e+27} L${t-11} ${e+37} L${t-11} ${e+40} L${t-5} ${e+36} Z" fill="${u}"></path><path d="M${t+5} ${e+27} L${t+11} ${e+37} L${t+11} ${e+40} L${t+5} ${e+36} Z" fill="${u}"></path><rect x="${t-5}" y="${e+9}" width="10" height="29" rx="1.5" fill="${s?"url(#flatSteel)":"url(#flatHull)"}"></rect><rect x="${t-5}" y="${e+14}" width="10" height="2.2" fill="${f}"></rect><circle cx="${t}" cy="${e+21}" r="1.7" fill="#0b0e15" stroke="${f}" stroke-width=".7"></circle><path d="M${t-5} ${e+9.5} Q${t-5} ${e+1.5} ${t} ${e-3} Q${t+5} ${e+1.5} ${t+5} ${e+9.5} Z" fill="${h}"></path><path d="M${t-5} ${e+9.5} Q${t-5} ${e+1.5} ${t} ${e-3} L${t} ${e+9.5} Z" fill="#ffffff" opacity=".18"></path><path d="M${t-1.6} ${e-1.4} Q${t} ${e-3.6} ${t+1.6} ${e-1.4} Z" fill="${s?"#f6d38a":l.cap}"></path>`,g+"</g>"}var H3=(()=>{let i=(t,e)=>`<linearGradient id="${t}" x1="0" y1="0" x2="1" y2="0">${e.map(([n,s])=>`<stop offset="${n}" stop-color="${s}"></stop>`).join("")}</linearGradient>`;return'<defs><linearGradient id="flatGlow" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9fd8ff" stop-opacity=".5"></stop><stop offset="1" stop-color="#9fd8ff" stop-opacity="0"></stop></linearGradient>'+i("flatHull",[["0","#8f949b"],[".35","#f4f1ec"],[".7","#d8d4ce"],["1","#6d7178"]])+i("flatSteel",[["0","#5d636b"],[".35","#dfe3e8"],[".65","#a9b0b8"],["1","#4b5057"]])+i("flatBell",[["0","#24272c"],[".45","#6b707a"],["1","#1c1e22"]])+Object.keys(fo).map(t=>`<linearGradient id="flame-${t}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${fo[t][0]}"></stop><stop offset=".35" stop-color="${fo[t][1]}" stop-opacity=".9"></stop><stop offset="1" stop-color="${fo[t][1]}" stop-opacity="0"></stop></linearGradient>`).join("")+'<filter id="flatBlur" x="-1" y="-1" width="3" height="3"><feGaussianBlur stdDeviation="4"></feGaussianBlur></filter></defs>'})(),Wf=i=>i==="zh"?"\u4E8C\u7EF4\u53D1\u5C04\u573A\uFF0C\u80FD\u529B\u4E0E\u53C2\u8003\u6210\u672C":"2D launch field, ability and reference cost";function Xf(i,t,e,n={}){let{engines:s,bounds:r,baseline:a,focus:o}=i,c=n.assetBase??z3(),l=n.scale??ni,h=t,f=e,u=64,d=66,m=75,x=f-80,g=h>640&&f>560,p=i.language==="zh",b=s.filter(N=>$c(N,r,a)),E=N=>u+($c(N,r,a).x+9.2)/18.4*(h-u-d),y=N=>x-(N.ability-r.abilityMin)/(r.abilityMax-r.abilityMin)*(x-m),w=N=>Math.round(62+Vf(N).length*6.1+(N.ability??0).toFixed(1).length*6),S=kf(b.map(N=>({id:N.id,order:-(N.ability??0),x:E(N),y:y(N),width:w(N),height:24})),h,x+30),C=b.filter(N=>!N.provisional),v=Bc(C,N=>N.ability,N=>N.developerId)?.id,R=new Map([...C].sort((N,L)=>(L.ability??0)-(N.ability??0)).map((N,L)=>[N.id,L+1])),I=H3;Uh(r.abilityMin,r.abilityMax,l,i.step).forEach((N,L)=>{let O=x-(x-m)*(N-r.abilityMin)/(r.abilityMax-r.abilityMin);I+=`<g><line x1="${u}" x2="${h-d+12}" y1="${O}" y2="${O}" stroke="#5a748733"></line><text x="${u-15}" y="${O+4}" text-anchor="end" fill="#acb5bf" font-size="11">${L===0&&N>0?p?`${N} \u8D77`:`from ${N}`:N.toFixed(0)}</text></g>`}),I+=`<text x="${u+1}" y="${m-28}" fill="#f0c28f" font-size="12">${p?"\u9AD8\u5EA6 \xB7 \u80FD\u529B Index":"Height \xB7 ability Index"}</text>`;for(let N=0;N<7;N++){let L=r.costMin+(r.costMax-r.costMin)*N/6,O=u+48+N*(h-u-d-50)/6;I+=`<g><line x1="${O}" x2="${O}" y1="${m}" y2="${x}" stroke="#5a748722"></line><text x="${O}" y="${x+26}" text-anchor="middle" fill="#b5a693" font-size="10">${Math.pow(2,L).toFixed(Math.pow(2,L)<1?2:0)}\xD7</text></g>`}for(let N of[0,1])for(let L of b){let O=E(L),P=y(L),W=(L.cost??0)/a,it=L.time===null?0:Math.min(92,12+70*L.time/r.timeMax),Q=S.get(L.id),ht=w(L),K=(L.ability??0).toFixed(1).length*6+10;I+=`<g tabindex="0" role="button" data-id="${qc(L.id)}" aria-label="${qc(`${L.name} ${L.effort}`)}" class="${o===L.id?"focus":""}${o&&o!==L.id?" dim":""}">`,N===0?(I+=`<line x1="${O}" x2="${O}" y1="${P+44}" y2="${x}" stroke="${L.colour}" opacity=".14"></line>`,it>0&&(I+=`<path d="M${O-2.5} ${P+70}L${O} ${P+70+it}L${O+2.5} ${P+70}" fill="url(#flatGlow)" stroke="${L.estimated?"#adbef655":"none"}"${L.estimated?' stroke-dasharray="3 3"':""}></path>`),I+=`<g${g?` transform="translate(${O} ${P}) scale(1.3) translate(${-O} ${-P})"`:""}>${k3(L,O,P,W,L.id===v,g?1.3:1,c)}</g>`):I+=`<line x1="${O+(Q.x>O?7:-7)}" y1="${P+4}" x2="${Q.x>O?Q.x:Q.x+ht}" y2="${Q.y+12}" stroke="${L.colour}" opacity=".4" stroke-width=".8"></line><g class="plate2d" transform="translate(${Q.x} ${Q.y})"><rect width="${ht}" height="24" rx="12" fill="#191a1c" fill-opacity=".82" stroke="${L.colour}" stroke-opacity=".5"></rect><circle cx="12" cy="12" r="8" fill="${L.colour}"></circle><text x="12" y="15.5" text-anchor="middle" class="rk-n">${R.get(L.id)??"~"}</text><text x="25" y="16" class="rk-name">${qc(Vf(L))}</text><rect x="${ht-K-4}" y="4" width="${K}" height="16" rx="5" style="fill: var(--lf-lcd-ink, #070c16); stroke: var(--lf-lcd-edge, #2a3a55);"></rect><text x="${ht-4-K/2}" y="16" text-anchor="middle" class="rk-v">${L.ability?.toFixed(1)??""}</text></g>`,I+="</g>"}return I+=`<text x="${h-d+8}" y="${x+54}" text-anchor="end" fill="#efb37a" font-size="11">${p?"\u53C2\u8003\u6210\u672C \xD7 \xB7 \u6DE1\u62D6\u5C3E\u4E3A\u822A\u65F6\uFF0C\u865A\u7EBF\u4E3A\u4F30\u7B97":"Reference cost \xD7 \xB7 faint trail is task time; dashed is estimated"}</text>`,I}function Gh(i){let t="http://www.w3.org/2000/svg",e=document.createElementNS(t,"svg");e.setAttribute("class","lf-flat"+(i.className?" "+i.className:"")),e.setAttribute("role","img"),i.container.appendChild(e);let n={w:820,h:580},s=null,r=!1,a=()=>{if(r||!s)return;let f=document.activeElement,u=f&&e.contains(f)?f.getAttribute("data-id"):null;e.setAttribute("viewBox",`0 0 ${n.w} ${n.h}`),e.setAttribute("aria-label",Wf(s.language)),e.innerHTML=Xf(s,n.w,n.h,{assetBase:i.assetBase,scale:i.scale}),u&&e.querySelector(`g[role="button"][data-id="${CSS.escape(u)}"]`)?.focus()},o=new ResizeObserver(([f])=>{let u={w:Math.max(320,Math.round(f.contentRect.width)),h:Math.max(360,Math.round(f.contentRect.height))};u.w===n.w&&u.h===n.h||(n=u,a())});o.observe(e);let c=f=>f.target?.closest?.('g[role="button"][data-id]'),l=f=>{let u=c(f);u&&i.onSelect?.(u.getAttribute("data-id"))},h=f=>{let u=c(f);u&&(f.key==="Enter"||f.key===" ")&&(f.preventDefault(),i.onSelect?.(u.getAttribute("data-id")))};return e.addEventListener("click",l),e.addEventListener("keydown",h),{update(f){s="models"in f?Vh(f,i.scale):{...f,language:f.language??i.language??"zh"},a()},setSelection(f){s&&(s={...s,focus:f},a())},dispose(){r||(r=!0,o.disconnect(),e.removeEventListener("click",l),e.removeEventListener("keydown",h),e.remove())}}}var V3="lineup-v1";var $f=i=>typeof i=="number"&&Number.isFinite(i);function Yc(i){if(new Set(i.map(d=>d.id)).size!==i.length)throw Error("duplicate_lineup_model");let t=i.filter(d=>$f(d.ability)&&$f(d.cost)&&d.cost>0),e=new Set(t.map(d=>d.id)),n=i.filter(d=>!e.has(d.id)).map(d=>({id:d.id,status:"incomplete",tags:[],dominatedBy:null}));if(t.length<2)return null;let s=(d,m)=>d.cost-m.cost||m.ability-d.ability||(d.id<m.id?-1:d.id>m.id?1:0),r=[...t].sort(s)[0],a=r.cost,o=t.map(d=>{let m=t.filter(x=>x!==d&&(x.cost<d.cost&&x.ability>=d.ability-1||x.cost===d.cost&&x.ability>d.ability)).sort(s)[0];return{id:d.id,ability:d.ability,cost:d.cost,costRelative:d.cost/a,tags:[],dominatedBy:m?{id:m.id,kind:Math.abs(m.ability-d.ability)<=1?"equivalent":"weaker"}:null}}),c=o.filter(d=>!d.dominatedBy).sort(s),l=Math.max(...o.map(d=>d.ability)),h=o.filter(d=>d.ability>=l-1).sort(s)[0],f=o.find(d=>d.id===r.id),u=null;for(let d of c){if(d===f||d.cost===f.cost)continue;let m=(d.ability-f.ability)/Math.log2(d.cost/f.cost);(!u||m>u.gain)&&(u={row:d,gain:m})}f.tags.push("cheapest"),h.tags.push("strongest"),u&&u.row.tags.push("best_value");for(let d of o)d.dominatedBy&&d.tags.push(d.dominatedBy.kind==="equivalent"?"equivalent_costlier":"dominated");return{method:V3,tie:1,baseline:f.id,frontier:c.map(d=>d.id),steps:c.slice(1).map((d,m)=>({from:c[m].id,to:d.id,abilityDelta:d.ability-c[m].ability,costRatio:d.cost/c[m].cost})),members:[...o,...n]}}function Wh(i){let t=new Map(i.map(h=>[h.id,"mid"])),e=i.filter(h=>h.ability!==null&&!h.provisional&&h.cost!==null&&h.cost>0&&h.costBasisId);if(e.length<3||new Set(e.map(h=>h.costBasisId)).size!==1)return t;let n=e.reduce((h,f)=>h+Math.log2(f.cost),0)/e.length,s=e.reduce((h,f)=>h+f.ability,0)/e.length,r=e.reduce((h,f)=>h+(Math.log2(f.cost)-n)**2,0);if(r<1e-10)return t;let a=e.reduce((h,f)=>h+(Math.log2(f.cost)-n)*(f.ability-s),0)/r,o=new Map(e.map(h=>[h.id,h.ability-(s+a*(Math.log2(h.cost)-n))])),c=Math.sqrt([...o.values()].reduce((h,f)=>h+f*f,0)/e.length),l=new Set(Yc(e.map(h=>({id:h.id,ability:h.ability,cost:h.cost})))?.frontier??[]);if(c<1e-10)return t;for(let[h,f]of o)t.set(h,f>=.75*c||l.has(h)&&f>=0?"hi":f<=-.75*c?"lo":"mid");return t}var Yf={openai:{file:"openai-black.svg",dark:"openai-white.svg"},anthropic:{file:"claude-rounded.svg",tile:!0},claude:{file:"claude-rounded.svg",tile:!0},zhipu:{file:"zhipu.svg",tile:!0},zai:{file:"zhipu.svg",tile:!0},xiaomi:{file:"xiaomi.svg",tile:!0},kimi:{file:"kimi-black.svg",dark:"kimi-white.svg"},minimax:{file:"minimax.svg"},alibaba:{file:"alibaba.svg"},qwen:{file:"qwen.svg"},volcengine:{file:"bytedance.svg"},google:{file:"gemini.svg"},deepseek:{file:"deepseek.svg"},mistral:{file:"mistral.svg"},grok:{file:"x-black.svg",dark:"x-white.svg"},opencode:{file:"opencode-black.svg",dark:"opencode-white.svg"},meta:{file:"meta.svg"},cursor:{file:"cursor-black.svg",dark:"cursor-white.svg"},githubcopilot:{file:"githubcopilot-black.svg",dark:"githubcopilot-white.svg"}};function Zf(i){let t=i.toLowerCase();return/openai|chatgpt/.test(t)?"openai":/anthropic|claude/.test(t)?"anthropic":/zhipu|智谱|z\.ai|\bzai\b|bigmodel/.test(t)?"zhipu":/kimi|moonshot/.test(t)?"kimi":/minimax/.test(t)?"minimax":/qwen|通义/.test(t)?"qwen":/alibaba|aliyun|百炼|阿里/.test(t)?"alibaba":/volc|bytedance|doubao|豆包|火山/.test(t)?"volcengine":/xiaomi|mimo|小米/.test(t)?"xiaomi":/google|gemini/.test(t)?"google":/deepseek/.test(t)?"deepseek":/mistral/.test(t)?"mistral":/grok|xai|spacex|x-subscription/.test(t)?"grok":/opencode/.test(t)?"opencode":/\bmeta\b|muse/.test(t)?"meta":/cursor/.test(t)?"cursor":/copilot|github/.test(t)?"githubcopilot":t}var qf=i=>i.replace(/&/g,"&amp;").replace(/"/g,"&quot;").replace(/</g,"&lt;");function Xh(i,t){let e=Yf[Zf(i)];return e?`<img${e.tile?' class="full"':""} src="${qf(`${t}brands/${e.dark??e.file}`)}" alt="">`:`<span>${qf(i.slice(0,1).toUpperCase())}</span>`}var Jf=i=>i.normalize("NFKD").toLowerCase().replace(/[^a-z0-9]+/g,"-").replace(/^-+|-+$/g,"");var G3={n:4.6,sagTop:.035,sagBot:.015},W3=1440,X3=.09,$3=.5,Kf=560,Ls=.97,jf=.95;function Qf(i,t=G3){let e=Math.cos(i),n=Math.sin(i),s=2/t.n,r=Math.sign(e)*Math.abs(e)**s,a=Math.sign(n)*Math.abs(n)**s;return a<0?a+=2*t.sagTop*r*r*-a:a-=2*t.sagBot*r*r*a,{x:r,y:a}}function $h(i,t,{steps:e=W3,sx:n=1,sy:s=1}={}){let r=[];for(let a=0;a<e;a++){let{x:o,y:c}=Qf(a/e*Math.PI*2);r.push({x:i/2*(1+o*n),y:t/2*(1+c*s)})}return r}function tp(i,t,e=X3){let n=Math.min(i,t),s=e*n,r=Math.max(40,(n-470)/2);return{px:Math.round(Math.min(s,r)),capped:s>r+.5}}var q3=i=>{let t=Math.max(0,Math.min(1,i));return t*t*t*(t*(t*6-15)+10)};function qh(i,t){let e=$3,n=Math.max(1,Math.round(i*e)),s=Math.max(1,Math.round(t*e)),r=n*s,a=$h(n,s),o=new Float32Array(r),c=n+s,l=Math.SQRT2,h=[];for(let p=0;p<s;p++){let b=p+.5;h.length=0;for(let E=0,y=a.length-1;E<a.length;y=E++){let w=a[E],S=a[y];w.y>b!=S.y>b&&h.push(w.x+(b-w.y)/(S.y-w.y)*(S.x-w.x))}h.sort((E,y)=>E-y);for(let E=0;E+1<h.length;E+=2){let y=Math.max(0,Math.ceil(h[E]-.5)),w=Math.min(n-1,Math.floor(h[E+1]-.5));for(let S=y;S<=w;S++)o[p*n+S]=c}}let f=0;for(let p=0;p<r;p++)o[p]&&f++;for(let p=0;p<s;p++)for(let b=0;b<n;b++){let E=p*n+b;o[E]&&(o[E]=Math.min(o[E],b?o[E-1]+1:1,p?o[E-n]+1:1,b&&p?o[E-n-1]+l:l,b<n-1&&p?o[E-n+1]+l:l))}for(let p=s-1;p>=0;p--)for(let b=n-1;b>=0;b--){let E=p*n+b;o[E]&&(o[E]=Math.min(o[E],b<n-1?o[E+1]+1:1,p<s-1?o[E+n]+1:1,b<n-1&&p<s-1?o[E+n+1]+l:l,b&&p<s-1?o[E+n-1]+l:l))}let{px:u,capped:d}=tp(i,t),m=Math.max(1,u*e),x=new Uint8Array(r),g=0;for(let p=0;p<r;p++){let b=Math.round(255*q3(o[p]/m));x[p]=b,b>=Math.round(255*Ls)&&g++}return{W:i,H:t,w:n,h:s,alpha:x,featherPx:u,capped:d,area:f/r,clear:g/r,at(p,b){let E=Math.round(p*e),y=Math.round(b*e);return E<0||y<0||E>=n||y>=s?0:x[y*n+E]/255}}}function ep(i){let{W:t,H:e}=i;return{topOp:(c,l)=>{for(let h=0;h<e;h+=2)if(i.at(c,h)>=l)return h;return e},botOp:(c,l)=>{for(let h=e-1;h>=0;h-=2)if(i.at(c,h)>=l)return h;return 0},leftOp:(c,l)=>{for(let h=0;h<t;h+=2)if(i.at(h,c)>=l)return h;return t},rightOp:(c,l)=>{for(let h=t-1;h>=0;h-=2)if(i.at(h,c)>=l)return h;return 0},span:(c,l,h,f)=>{let u=h(c);for(let d=c;d<=l;d+=6)u=f(u,h(d));return f(u,h(l))}}}function Y3(i){let{W:t,H:e}=i,{topOp:n,botOp:s,leftOp:r,span:a}=ep(i),o=Math.max(248,Math.min(300,Math.round(.2*t))),c=.8,l=r(e*.55,c)+4,h={x:l,y:0,h:-1/0};for(let f=l;f<l+86;f+=4){let u=a(f,f+o,m=>n(m,c),Math.max)+4,d=a(f,f+o,m=>s(m,c),Math.min)-4;d-u>h.h+6&&(h={x:f,y:u,h:d-u})}return Z3(h,o,e)}function Z3(i,t,e){let n=i.h>=Kf,s=n?{x:i.x,y:i.y,w:t,h:i.h}:{x:10,y:10,w:t,h:e-20};return{...s,inside:n,dense:s.h<660,legend:s.h<600?"hidden":s.h>=720?"open":"closed"}}function Yh(i){let{W:t,H:e}=i,{topOp:n,botOp:s,rightOp:r,span:a}=ep(i),o=Y3(i),c=o.x+o.w,l=t>=1e3,h=c+(l?112:28),f=t-a(Math.round(e*.25),Math.round(e*.85),g=>r(g,Ls),Math.min)+34,u=t-f,d=a(h,u,g=>n(g,Ls),Math.max)+8,m=e-a(h,u,g=>s(g,Ls),Math.min)+50,x=Math.round((h+u)/2);return{W:t,H:e,menu:o,insets:{left:h,right:f,top:d,bottom:m},gauge:{show:l,left:c+20,top:a(c+20,c+120,g=>n(g,Ls),Math.max)+40,bottom:e-a(c+20,c+120,g=>s(g,Ls),Math.min)+8},focus:{x,bottom:e-a(x-230,x+230,g=>s(g,Ls),Math.min)+6}}}function Zh(i){return i.search?"clear-search":i.focus?"leave-focus":"close"}var np=["fleet","effort","methodology"],J3=/^[a-z0-9][a-z0-9._-]{0,119}$/i;function Jh(i,t={}){if(!np.includes(i)||t==null||typeof t!="object"||Array.isArray(t))return null;let e=Object.keys(t);if(!e.length)return{target:i,params:{}};let n=t.m;return i==="effort"&&e.length===1&&e[0]==="m"&&typeof n=="string"&&J3.test(n)?{target:"effort",params:{m:n}}:null}var Kh={strongest:["Strongest","\u6700\u5F3A"],best_value:["Best value","\u6700\u503C"],cheapest:["Cheapest","\u6700\u7701"],dominated:["Outclassed","\u6709\u66F4\u4F18"],equivalent_costlier:["Pricier twin","\u6709\u66F4\u7701"]},ip={None:"\u5173",Off:"\u5173",Min:"\u6781\u4F4E",Low:"\u4F4E",Med:"\u4E2D",Medium:"\u4E2D",High:"\u9AD8",XHigh:"\u8D85\u9AD8",Max:"\u6700\u9AD8",Ultra:"Ultra",Default:"\u9ED8\u8BA4"},Ns=i=>i.e.find(t=>t[0]===i.rec)??i.e.at(-1);function Zc(i){let t=Yc(i.map(n=>{let s=Ns(n);return{id:n.id,ability:s?.[1]??null,cost:s?.[2]??null}})),e=new Map;for(let n of i){let s=t?.members.find(a=>a.id===n.id),r=["strongest","best_value","cheapest","dominated","equivalent_costlier"].find(a=>s?.tags.includes(a))??null;e.set(n.id,{tag:r,costRelative:s?.costRelative??null,dominatedBy:s?.dominatedBy?.id??null})}return e}var sp=i=>i==="dominated"||i==="equivalent_costlier",rp=i=>i==null?"\u2013":"\xD7"+(i>=10?i.toFixed(0):i>=1.995?i.toFixed(1):i.toFixed(2));function ap(i,t=34,e=13){let n=i.filter(d=>d!=null&&Number.isFinite(d));if(n.length<3)return null;let s=Math.min(...n),r=Math.max(...n),a=Math.max(r-s,3),o="",c=!1,l=NaN,h={x:0,y:0},f=NaN;for(let d=0;d<i.length;d++){let m=i[d];if(m==null||!Number.isFinite(m)){c=!1;continue}let x=d/Math.max(1,i.length-1)*(t-4)+2,g=2+(m-s)/a*(e-4);o+=`${c?"L":"M"}${x.toFixed(1)} ${g.toFixed(1)}`,c=!0,h={x,y:g},f=m,Number.isNaN(l)&&(l=m)}let u=f<l?"up":f>l?"down":"flat";return{d:o,end:h,first:l,last:f,trend:u}}var jh=10;function Qh(i,t,e=jh){return i.includes(t)?i.length>1?{ids:i.filter(n=>n!==t)}:{refused:"last"}:i.length>=e?{refused:"full"}:{ids:[...i,t]}}var Ie=i=>String(i).replace(/[&<>"]/g,t=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"})[t]),op='<svg viewBox="0 0 12 12" aria-hidden="true"><path d="M2.5 2.5l7 7M9.5 2.5l-7 7"/></svg>',K3={h:'<path d="M8 13V3M4 7l4-4 4 4"/>',f:'<path d="M8 14c-2.6 0-4.3-1.8-4.3-4.1 0-2.6 2.3-3.9 2.6-6.9 1.9 1 3 2.6 2.9 4.3.7-.5 1.1-1.2 1.2-2 1.2 1.1 1.9 2.7 1.9 4.4C12.3 12.2 10.6 14 8 14z"/>',d:'<circle cx="8" cy="8.5" r="5.3"/><path d="M8 5.6v3l2 1.4"/>',s:'<path d="M8 2.6l1.6 3.5 3.8.4-2.8 2.6.8 3.8L8 11l-3.4 1.9.8-3.8-2.8-2.6 3.8-.4z"/>',r:'<path d="M8 1.8c2 1.6 2.9 4 2.6 7.2l-1.2 2.2H6.6L5.4 9C5.1 5.8 6 3.4 8 1.8zM6.4 11.4L5 14l2-.9M9.6 11.4L11 14l-2-.9"/>'},po=i=>`<svg viewBox="0 0 16 16" aria-hidden="true">${K3[i]}</svg>`;function j3(i){let t=i.container,e=t.ownerDocument,n=e.defaultView??window,s=i.limit??jh,r=i.menu!==!1,a=i.language,o=i.contrast??"normal",c=()=>a==="zh",l=(U,xt)=>c()?xt:U,h=i.assetBase??__LF_ENV__?.BASE_URL??"./",f=i.logo??(U=>Xh(U,h)),u=(U,xt)=>{let zt=e.createElement(U);return zt.className=xt,zt};t.classList.add("lfw");let d=u("div","lfw-dim"),m=u("div","lfw-view"),x=u("div","lfw-sky"),g=u("canvas","lfw-outline"),p=u("aside","lfw-menu"),b=u("div","lfw-keys"),E=u("div","lfw-focus"),y=u("div","lfw-toast");d.hidden=i.dim===!1;for(let U of[d,x,g])U.setAttribute("aria-hidden","true");E.hidden=!0,p.hidden=!r,y.setAttribute("role","status"),y.setAttribute("aria-live","polite"),t.append(d,m,g,p,b,E,y);let w=[],S=new Set,C=new Map,v=[],R=new Set,I={},N=new Set,L=null,O="",P=null,W=null,it=null,Q="fleet",ht="mine",K="",ot=!1,z=new Map,Mt=null,vt=null,Et=()=>{let U=t.clientWidth,xt=t.clientHeight;return!U||!xt?!1:(Mt&&Mt.W===U&&Mt.H===xt||(Mt=qh(U,xt),vt=Yh(Mt),nt()),!0)},Ot=(U,xt)=>{let zt=e.createElement("canvas");zt.width=U.w,zt.height=U.h;let $t=zt.getContext("2d"),xe=$t.createImageData(U.w,U.h);for(let be=0;be<U.alpha.length;be++)xe.data[be*4]=xe.data[be*4+1]=xe.data[be*4+2]=255,xe.data[be*4+3]=xt?255-U.alpha[be]:U.alpha[be];return $t.putImageData(xe,0,0),`url(${zt.toDataURL("image/png")})`},Lt=(U,xt)=>{U.style.maskImage=xt,U.style.setProperty("-webkit-mask-image",xt)};function et(){if(!Mt)return;let U=n.devicePixelRatio||1,{W:xt,H:zt}=Mt;g.width=Math.round(xt*U),g.height=Math.round(zt*U);let $t=g.getContext("2d");if(!$t||($t.setTransform(U,0,0,U,0,0),$t.clearRect(0,0,xt,zt),o!=="more"))return;let xe=$h(xt,zt,{sx:.996,sy:.994});$t.beginPath(),xe.forEach((be,Ke)=>Ke?$t.lineTo(be.x,be.y):$t.moveTo(be.x,be.y)),$t.closePath(),$t.lineWidth=1,$t.strokeStyle="rgba(186,204,232,.55)",$t.stroke()}function nt(){if(!Mt||!vt)return;Lt(m,Ot(Mt,!1)),d.hidden||Lt(d,Ot(Mt,!0)),et();let U=vt.menu;t.classList.toggle("lfw-rim",!U.inside),t.classList.toggle("lfw-dense",U.dense),t.classList.toggle("lfw-window-mini",U.legend==="hidden"),t.classList.toggle("lfw-tiny",!vt.gauge.show),t.style.setProperty("--lfw-mw",U.w+"px"),Object.assign(p.style,{left:U.x+"px",top:U.y+"px",width:U.w+"px",height:U.h+"px"}),E.style.left=vt.focus.x+"px",E.style.bottom=vt.focus.bottom+"px",E.style.maxWidth=Math.max(320,vt.W-(U.x+U.w)-60)+"px",t.style.setProperty("--lf-gauge-top",vt.gauge.top+"px"),t.style.setProperty("--lf-gauge-bottom",vt.gauge.bottom+"px"),gt(),r&&tt()}let _t=U=>{let xt=z.get(U.id);return xt&&U.e.find(zt=>zt[0]===xt)||U.sel||Ns(U)||null},wt=()=>{let U=w.map(xe=>({...xe,sel:_t(xe)})),xt=U.filter(xe=>v.includes(xe.id)),zt=Wh(xt.map(xe=>({id:xe.id,ability:xe.sel?.[1]??null,cost:xe.sel?.[2]??null,provisional:N.has(xe.id),costBasisId:"fleet"}))),$t=Lf(xt.map(xe=>({id:xe.id,developerId:xe.dev,ability:xe.sel?.[1]??null})));return U.map(xe=>({...xe,fuel:S.has(xe.id)?xe.fuel:zt.get(xe.id)??"mid",shape:xe.shape??$t.get(xe.id)}))},pt=()=>w.filter(U=>v.includes(U.id)&&_t(U)).sort((U,xt)=>_t(xt)[1]-_t(U)[1]),It=null,ee=null,V=null,lt=()=>!Et()||!vt?{}:r?vt.insets:{...vt.insets,left:vt.menu.x+28},ct=()=>{It?It.update({models:wt(),shown:v,focus:P,hint:it??W,language:a}):ee?.update({models:wt(),shown:v,focus:P,language:a})};function gt(){if(!V)return;let U=lt();Object.assign(V.style,{left:(U.left??0)+"px",right:(U.right??0)+"px",top:(U.top??0)+"px",bottom:(U.bottom??0)+"px"})}function bt(){ee||ot||(It?.dispose(),It=null,V=u("div","lfw-flat"),m.appendChild(V),gt(),ee=Gh({container:V,language:a,assetBase:i.assetBase,scale:i.scale,onSelect:U=>Gt(U,!0)}),V.addEventListener("click",U=>{P&&!U.target.closest?.('g[role="button"]')&&Gt(null,!0)}),Kt(),ct())}let Bt=(U,xt)=>{let zt=U.getBoundingClientRect();return{left:zt.left-xt.left,top:zt.top-xt.top,right:zt.right-xt.left,bottom:zt.bottom-xt.top}};function Ut(){if(!Mt)return;let U=t.getBoundingClientRect(),xt=Mt,zt=[...m.querySelectorAll(".tick3")],$t=[...m.querySelectorAll(".bl3")],xe=[...m.querySelectorAll(".plate")],be=[...m.querySelectorAll(".ltag")],Ke=Hf({ticks:zt.map(ye=>({cls:ye.classList.contains("axis")?"axis":ye.classList.contains("lane")?"lane":"",text:ye.textContent??"",rect:Bt(ye,U)})),paths:$t.map(ye=>({rec:ye.classList.contains("rec"),rect:Bt(ye,U)})),chips:xe.map(ye=>({rect:Bt(ye,U),visible:+(ye.style.opacity||1)>.3,hot:ye.classList.contains("hot")})),orbits:be.map(ye=>Bt(ye,U))},{opacityAt:(ye,me)=>xt.at(ye,me),minOpacity:jf,menu:r&&!p.hidden?Bt(p,U):null,blocks:[b,...E.hidden?[]:[E]].map(ye=>Bt(ye,U))});zt.forEach((ye,me)=>ye.classList.toggle("lf-hid",Ke.ticks[me])),$t.forEach((ye,me)=>ye.classList.toggle("lf-hid",Ke.paths[me])),xe.forEach((ye,me)=>ye.classList.toggle("lf-hid",Ke.chips[me])),be.forEach((ye,me)=>ye.classList.toggle("lf-hid",Ke.orbits[me]))}function Kt(){b.innerHTML=`<p class="lfw-hint">${P?`${l("Click empty space or","\u70B9\u7A7A\u767D\u5904\u6216\u6309")} <kbd>Esc</kbd> ${l("to go back","\u8FD4\u56DE\u5168\u666F")}`:`${ee?"":`${l("Drag to rotate","\u62D6\u52A8\u65CB\u8F6C")} \xB7 `}${l("click a rocket to fly in","\u70B9\u706B\u7BAD\u98DE\u8FD1")} \xB7 <kbd>Esc</kbd> ${l("closes","\u5173\u95ED")}`}</p><button type="button" class="lfw-site" data-site="fleet">${l("Full fleet on the website","\u5728\u7F51\u7AD9\u4E0A\u770B\u5B8C\u6574\u8230\u961F")} <span aria-hidden="true">\u2197</span></button><button type="button" class="lfw-x" data-close aria-label="${Ie(l("Close (Esc)","\u5173\u95ED\uFF08Esc\uFF09"))}" title="${Ie(l("Close \xB7 Esc","\u5173\u95ED \xB7 Esc"))}">${op}</button>`}let se=U=>U==="Default"?l("Default","\u9ED8\u8BA4"):c()?(ip[U]??U)+"\u6863":U,F=(U,xt)=>`${xt===U.rec?"\u2605 ":""}${se(xt)}`,re=U=>`<span class="lfw-mini">${f(U)}</span>`,ae=U=>N.has(U.id)?`<em class="lfw-prov" title="${Ie(l("Provisional score: too few benchmark results yet; it can still move","\u6682\u5B9A\u5206\uFF1A\u57FA\u51C6\u7ED3\u679C\u8FD8\u4E0D\u591F\u591A\uFF0C\u4E4B\u540E\u53EF\u80FD\u53D8\u52A8"))}">${l("provisional","\u6682\u5B9A")}</em>`:"",T=U=>{let xt=ap(I[U]??[]);return xt?`<svg class="lfw-spk ${xt.trend}" width="34" height="13" viewBox="0 0 34 13" role="img" aria-label="${Ie(l(`OpenRouter usage rank, 30 days: #${xt.first} \u2192 #${xt.last}`,`OpenRouter \u7528\u91CF\u6392\u540D 30 \u5929\uFF1A#${xt.first} \u2192 #${xt.last}`))}"><path d="${xt.d}"/><circle cx="${xt.end.x.toFixed(1)}" cy="${xt.end.y.toFixed(1)}" r="1.8"/></svg>`:`<span class="lfw-spk-na" title="${Ie(l("Not ranked on OpenRouter in the last 30 days","\u8FD1 30 \u5929\u672A\u8FDB\u5165 OpenRouter \u6392\u540D"))}">\u2013</span>`},_=U=>U.name.replace(/^Claude /,"");function G(){let U=pt(),xt=Zc(U),zt=[...U].sort((be,Ke)=>(Ns(be)?.[2]??1/0)-(Ns(Ke)?.[2]??1/0))[0],$t=U.map((be,Ke)=>{let ye=xt.get(be.id),me=_t(be),an=ye.dominatedBy&&C.get(ye.dominatedBy);return`<li class="lfw-row ${sp(ye.tag)?"out":""} ${P===be.id?"on":""}" data-id="${Ie(be.id)}" style="--c:${Ie(be.colour)}">
        <button type="button" class="lfw-go" data-go="${Ie(be.id)}" title="${Ie(an?l(`${_(an)} costs less with at least the same ability`,`${_(an)} \u66F4\u4FBF\u5B9C\uFF0C\u80FD\u529B\u4E0D\u4F4E\u4E8E\u5B83`):l("Fly to this rocket","\u98DE\u8FD1\u8FD9\u53F0\u706B\u7BAD"))}">
          <span class="lfw-lamp">${Ke+1}</span>
          <span class="nm">${re(be.dev)}<b>${Ie(_(be))}</b>${ae(be)}</span>
          <span class="sub">${ye.tag?`<i class="lfw-tag tag-${ye.tag}">${l(...Kh[ye.tag])}</i>`:""}<span class="cx" title="${Ie(l("Cost per task as a multiple of the cheapest model on the field","\u6BCF\u4EFB\u52A1\u8D39\u7528\uFF0C\u76F8\u5BF9\u573A\u4E0A\u6700\u7701\u7684\u4E00\u53F0"))}">${rp(ye.costRelative)}</span><span class="tr">${T(be.id)}</span></span>
          <span class="vl"><b>${me[1].toFixed(1)}</b><small class="${me[0]===be.rec?"rec":""}">${Ie(F(be,me[0]))}</small></span>
        </button>
        <button type="button" class="lfw-rm" data-rm="${Ie(be.id)}" ${v.length<=1?"disabled":""} aria-label="${Ie(l(`Remove ${be.name} from the field`,`\u628A ${be.name} \u64A4\u4E0B\u53D1\u5C04\u573A`))}" title="${Ie(l("Remove from the field","\u64A4\u4E0B\u53D1\u5C04\u573A"))}">${op}</button>
      </li>`}).join(""),xe=vt?.menu.legend==="open";return`<div class="lfw-colh"><span><i class="lbl">${l("On the field","\u573A\u4E0A")} </i><b>${U.length}</b>/${s}</span><span class="ix" title="${Ie(l("ModelPlan ability index at the effort shown under each number (\u2605 = recommended effort)","ModelPlan \u80FD\u529B\u6307\u6570\uFF0C\u6309\u6BCF\u4E2A\u6570\u5B57\u4E0B\u9762\u6807\u7684\u6863\u4F4D\uFF08\u2605 = \u63A8\u8350\u6863\uFF09"))}">${l("ModelPlan ability index","ModelPlan \u80FD\u529B\u6307\u6570")}</span></div>
      <ol class="lfw-list">${$t}</ol>
      <p class="lfw-key"><span><svg width="16" height="8" aria-hidden="true"><path d="M1 6 L5 3 L9 5 L15 1" fill="none" stroke="#a2a4a8" stroke-width="1.2"/></svg>${l("30-day usage trend (OpenRouter rank)","30 \u5929\u7528\u91CF\u8D70\u52BF\uFF08OpenRouter \u6392\u540D\uFF09")}</span>${zt?`<span><b class="cxk">\xD7</b>${l("cost vs the cheapest here","\u8D39\u7528\uFF0C\u76F8\u5BF9\u573A\u4E0A\u6700\u7701\u7684")} (${Ie(_(zt))} \u2605)</span>`:""}</p>
      <details class="lfw-legend" ${xe?"open":""}><summary>${l("How to read this chart","\u600E\u4E48\u770B\u8FD9\u5F20\u56FE")}</summary><dl>
        <dt>${po("h")}</dt><dd><b>${l("Height","\u9AD8\u5EA6")}</b>${l("ModelPlan ability index","ModelPlan \u80FD\u529B\u6307\u6570")}</dd>
        <dt>${po("f")}</dt><dd><b>${l("Flame","\u5C3E\u7130")}</b>${l("cost ","\u6210\u672C ")}<em class="fz hi">${l("cheap","\u84DD\u7701")}</em> \xB7 <em class="fz mid">${l("mid","\u6A59\u4E2D")}</em> \xB7 <em class="fz lo">${l("dear","\u9ED1\u8D35")}</em></dd>
        <dt>${po("d")}</dt><dd><b>${l("Depth","\u7EB5\u6DF1")}</b>${l("task time (est.)","\u8017\u65F6\uFF08\u4F30\u7B97\uFF09")}</dd>
        <dt>${po("s")}</dt><dd><b>${l("Star","\u63A8\u8350\u6863")}</b>${l("best-value effort","\u6700\u503C\u7684\u6863\u4F4D")}</dd>
        <dt>${po("r")}</dt><dd><b>${l("Starship","\u661F\u8230")}</b>${l("top, or xAI in top 3","\u6700\u5F3A\uFF08xAI \u524D\u4E09\u4F18\u5148\uFF09")}</dd></dl>
        <button type="button" class="lfw-link" data-site="methodology">${l("How we work it out","\u600E\u4E48\u7B97\u7684")} <span aria-hidden="true">\u2197</span></button></details>
      <div class="lfw-act"><button type="button" class="pri" data-tab="pick"><span aria-hidden="true">+</span> ${l("Pick models","\u9009\u6A21\u578B")}</button><button type="button" data-site="effort">${l("Compare on site","\u53BB\u7F51\u7AD9\u5BF9\u6BD4")} <span aria-hidden="true">\u2197</span></button></div>`}let q=U=>R.has(U.id)||v.includes(U.id),rt=()=>[...w].sort((U,xt)=>(Ns(xt)?.[1]??-1)-(Ns(U)?.[1]??-1));function St(){let U=K.trim().toLowerCase(),xt=me=>!U||`${me.name} ${me.dev}`.toLowerCase().includes(U),zt=rt(),$t=zt.filter(me=>(ht==="all"||q(me))&&xt(me)),xe=ht==="mine"&&U?zt.filter(me=>!q(me)&&xt(me)):[],be=v.length>=s,Ke=pt().map(me=>me.id),ye=me=>{let an=v.includes(me.id),Fn=!an&&be,ue=_t(me);return`<li class="${an?"is-on":""} ${Fn?"is-full":""} ${P===me.id?"focused":""}" data-id="${Ie(me.id)}" style="--c:${Ie(me.colour)}">
        <button type="button" class="lfw-lamp lfw-tg" data-tg="${Ie(me.id)}" aria-pressed="${an}" ${Fn?`aria-disabled="true" title="${Ie(l(`The field holds ${s}; remove one first`,`\u573A\u4E0A\u6700\u591A ${s} \u53F0\uFF0C\u5148\u64A4\u4E0B\u4E00\u53F0`))}"`:""} aria-label="${Ie(an?l(`Retract ${me.name}`,`\u64A4\u56DE ${me.name}`):l(`Launch ${me.name}`,`\u53D1\u5C04 ${me.name}`))}">${an?Ke.indexOf(me.id)+1:""}</button>
        <button type="button" class="lfw-pn" data-pk="${Ie(me.id)}"><span class="l1">${re(me.dev)}<b>${Ie(me.name)}</b></span><span class="l2">${ue?`<small class="${ue[0]===me.rec?"rec":""}">${Ie(F(me,ue[0]))}</small>`:""}${ae(me)}</span></button>
        <span class="lfw-ps">${ue?ue[1].toFixed(1):"\u2013"}</span></li>`};return!$t.length&&!xe.length?`<li class="lfw-empty">${l("No matching models","\u6CA1\u6709\u5339\u914D\u7684\u6A21\u578B")}</li>`:($t.length?$t.map(ye).join(""):`<li class="lfw-empty sm">${l("None of your tools runs a match.","\u4F60\u7684\u5DE5\u5177\u91CC\u6CA1\u6709\u5339\u914D\u7684\u6A21\u578B\u3002")}</li>`)+(xe.length?`<li class="lfw-div" aria-hidden="true">${l("Other models","\u5176\u4ED6\u6A21\u578B")}</li>`+xe.map(ye).join(""):"")}function Rt(){let U=w.filter(q).length,xt=v.length>=s,zt=!!L&&L.length===v.length&&L.every($t=>v.includes($t));return`<label class="lfw-search"><svg viewBox="0 0 16 16" aria-hidden="true"><circle cx="7" cy="7" r="4.6"/><path d="M10.4 10.4L14 14"/></svg><input type="search" autocomplete="off" spellcheck="false" value="${Ie(K)}" placeholder="${Ie(l("Search models","\u641C\u7D22\u6A21\u578B"))}" aria-label="${Ie(l("Search models","\u641C\u7D22\u6A21\u578B"))}"></label>
      <div class="lfw-scope"><div class="lfw-seg" role="group" aria-label="${Ie(l("Scope","\u8303\u56F4"))}"><button type="button" data-scope="mine" aria-pressed="${ht==="mine"}">${l("Mine","\u6211\u7684")} <small>${U}</small></button><button type="button" data-scope="all" aria-pressed="${ht==="all"}">${l("All","\u5168\u90E8")} <small>${w.length}</small></button></div>
        <span class="lfw-cnt ${xt?"full":""}"><b>${v.length}</b>/${s} ${l("on the field","\u4E0A\u573A")}</span></div>
      <p class="lfw-note">${xt?`<span class="warn">${l(`The field is full (${s}). Tap a lit lamp to retract one first.`,`\u573A\u4E0A\u5DF2\u6EE1 ${s} \u53F0\uFF1A\u5148\u70B9\u4EAE\u7740\u7684\u5706\u706F\u64A4\u4E0B\u4E00\u53F0\u3002`)}</span>`:ht==="mine"?l("Mine: models your connected tools can run, plus anything on the field.","\u6211\u7684\uFF1A\u4F60\u8FDE\u63A5\u7684\u5DE5\u5177\u80FD\u8DD1\u7684\u6A21\u578B\uFF0C\u4EE5\u53CA\u5DF2\u5728\u573A\u4E0A\u7684\u3002"):l("Every model ModelPlan tracks, strongest first. Tap a lamp to launch or retract.","ModelPlan \u8DDF\u8E2A\u7684\u5168\u90E8\u6A21\u578B\uFF0C\u6309\u80FD\u529B\u6392\u5E8F\u3002\u70B9\u5706\u706F\u53D1\u5C04\u6216\u64A4\u56DE\u3002")}</p>
      <ul class="lfw-pick">${St()}</ul>
      <div class="lfw-act">${L?`<button type="button" data-reset ${zt?"disabled":""}>${l("Default fleet","\u6062\u590D\u9ED8\u8BA4")}</button>`:""}<button type="button" class="pri" data-tab="fleet">${l("Done","\u5B8C\u6210")}</button></div>`}function tt(){if(!r||ot)return;let U=e.activeElement,xt=U instanceof HTMLInputElement&&p.contains(U),zt=xt?U.selectionStart:null;if(p.setAttribute("aria-label",l("Models on the field","\u573A\u4E0A\u6A21\u578B")),p.innerHTML=`<header class="lfw-h"><p class="lfw-kick">${l("Launch field","\u53D1\u5C04\u573A")}</p>${O?`<span class="lfw-asof" title="${Ie(l("Data snapshot","\u6570\u636E\u5FEB\u7167"))}">${l("data","\u6570\u636E")} ${Ie(O.slice(5,10))}</span>`:""}</header>
      <div class="lfw-tabs" role="tablist"><button type="button" role="tab" data-tab="fleet" aria-selected="${Q==="fleet"}">${l("Worth it?","\u54EA\u4E2A\u6700\u503C")}</button><button type="button" role="tab" data-tab="pick" aria-selected="${Q==="pick"}">${l("Pick models","\u9009\u6A21\u578B")} <small>${v.length}/${s}</small></button></div>
      <div class="lfw-body ${Q}">${Q==="fleet"?G():Rt()}</div>`,xt){let $t=p.querySelector(".lfw-search input");$t?.focus({preventScroll:!0}),$t&&zt!=null&&$t.setSelectionRange(zt,zt)}}let ft=()=>{let U=p.querySelector(".lfw-pick");U&&(U.innerHTML=St())};function At(){let U=P?C.get(P):void 0;if(E.hidden=!U,t.classList.toggle("lfw-zoomed",!!U),Kt(),!U)return;let xt=Zc(pt()).get(U.id),zt=_t(U);E.innerHTML=`<div class="fh"><button type="button" class="lfw-back" data-back>${l("Back to fleet","\u8FD4\u56DE\u5168\u666F")} <kbd>Esc</kbd></button>
        ${re(U.dev)}<b>${Ie(U.name)}</b>${ae(U)}${xt?.tag?`<i class="lfw-tag tag-${xt.tag}">${l(...Kh[xt.tag])}</i>`:""}
        <button type="button" class="lfw-link" data-site="effort" data-m="${Ie(U.slug??U.id)}">${l("Effort details","\u6863\u4F4D\u8BE6\u60C5")} <span aria-hidden="true">\u2197</span></button></div>
      ${U.e.length>1?`<div class="lfw-ladder" role="group" aria-label="${Ie(l("Change effort","\u5207\u6362\u6863\u4F4D"))}">${U.e.map($t=>`<button type="button" data-eff="${Ie($t[0])}" aria-pressed="${zt?.[0]===$t[0]}" class="${$t[0]===U.rec?"rec":""}"><span>${$t[0]===U.rec?"<i>\u2605</i>":""}${Ie(se($t[0]))}</span><small>${$t[1].toFixed(1)}</small></button>`).join("")}</div>`:""}
      <p class="lfw-ix">${l("ModelPlan ability index","ModelPlan \u80FD\u529B\u6307\u6570")} \xB7 ${l("height = the effort lit above","\u9AD8\u5EA6 = \u4E0A\u9762\u4EAE\u7740\u7684\u6863\u4F4D")}</p>`}let Ht=0,Nt=U=>{y.textContent=U,y.classList.add("on"),n.clearTimeout(Ht),Ht=n.setTimeout(()=>y.classList.remove("on"),2600)},Tt=(U,xt={})=>{let zt=Jh(U,xt);zt&&i.onOpenSite?.(zt.target,zt.params)};function Gt(U,xt){if(U&&!C.has(U)&&(U=null),U&&!v.includes(U)){let zt=Qh(v,U,s);if("refused"in zt){Nt(l(`The field holds ${s}. Retract one first.`,`\u573A\u4E0A\u6700\u591A ${s} \u53F0\uFF0C\u5148\u64A4\u4E0B\u4E00\u53F0\u3002`));return}Jt(zt.ids,!0)}U!==P&&(P=U,At(),tt(),ct(),xt&&i.onSelect?.(P))}function Jt(U,xt){v=U.slice(0,s),P&&!v.includes(P)&&(P=null,At()),tt(),ct(),xt&&i.onShownChange?.([...v])}let he=U=>{let xt=Qh(v,U,s);"refused"in xt?Nt(xt.refused==="last"?l("Keep at least one rocket on the field","\u573A\u4E0A\u81F3\u5C11\u7559\u4E00\u53F0\u706B\u7BAD"):l(`The field holds ${s}. Retract one first.`,`\u573A\u4E0A\u6700\u591A ${s} \u53F0\uFF0C\u5148\u64A4\u4E0B\u4E00\u53F0\u3002`)):Jt(xt.ids,!0)},B=U=>{z.clear(),K="",P=null,At(),tt(),ct(),i.onClose?.(U)},Ft=U=>{let xt=U.target;if(!xt?.closest||xt.closest(".lfw-view"))return;let zt=xe=>xt.closest(xe),$t;($t=zt("[data-site]"))?(U.preventDefault(),Tt($t.dataset.site,$t.dataset.m?{m:$t.dataset.m}:{})):zt("[data-close]")?B("key"):zt("[data-back]")?Gt(null,!0):($t=zt("[data-eff]"))&&P?(z.set(P,$t.dataset.eff),At(),tt(),ct()):($t=zt("[data-tab]"))?(Q=$t.dataset.tab==="pick"?"pick":"fleet",tt(),Q==="pick"&&p.querySelector(".lfw-search input")?.focus({preventScroll:!0})):($t=zt("[data-scope]"))?(ht=$t.dataset.scope==="all"?"all":"mine",tt()):($t=zt("[data-rm]"))?he($t.dataset.rm):($t=zt("[data-go]"))?Gt($t.dataset.go,!0):($t=zt("[data-tg]"))?he($t.dataset.tg):($t=zt("[data-pk]"))?Gt($t.dataset.pk,!0):zt("[data-reset]")&&L&&Jt(L.slice(0,s),!0)},mt=U=>{let xt=U.target;xt.closest?.(".lfw-search")&&(K=xt.value,ft())},Dt=U=>{let xt=U.target.closest?.(".lfw-row, .lfw-pick li"),zt=xt?.dataset.id&&v.includes(xt.dataset.id)?xt.dataset.id:null;zt!==it&&(it=zt,ct())},kt=()=>{it&&(it=null,ct())},ut=U=>{if(U.key!=="Escape"||ot)return;U.preventDefault();let xt=Zh({search:K,focus:P});if(xt==="clear-search"){K="";let zt=p.querySelector(".lfw-search input");zt&&(zt.value=""),ft()}else xt==="leave-focus"?Gt(null,!0):B("esc")};t.addEventListener("click",Ft),t.addEventListener("input",mt),p.addEventListener("pointerover",Dt),p.addEventListener("pointerleave",kt),n.addEventListener("keydown",ut);let ie=new ResizeObserver(()=>Et());ie.observe(t),Kt();let jt=()=>{bt(),i.onFail?.()};try{let U=Hh({container:m,language:a,assetBase:i.assetBase,logo:f,scale:i.scale,axis:i.axis,insets:lt,gaugeLeft:()=>Et()&&vt?r?vt.gauge.left:vt.menu.x:0,rocketScale:i.rocketScale??1.24,reducedMotion:i.reducedMotion,onSelect:xt=>Gt(xt,!0),onFail:jt,onSlow:i.onSlow,onFrame:Ut});ee?U.dispose():It=U}catch{jt()}let Be=m.querySelector(".lf-scene");return m.insertBefore(x,Be?Be.nextSibling:m.firstChild),Et(),{update(U){if(!ot){S=new Set(U.models.filter(xt=>xt.fuel).map(xt=>xt.id)),w=U.models.map(xt=>({...xt,slug:xt.slug??Jf(xt.name),fuel:xt.fuel??"mid",racer:xt.racer??!1})),C=new Map(w.map(xt=>[xt.id,xt])),v=U.shown.filter(xt=>C.has(xt)).slice(0,s),U.language&&(a=U.language),U.mine&&(R=new Set(U.mine)),U.trend&&(I=U.trend),U.provisional&&(N=new Set(U.provisional)),U.defaults!==void 0&&(L=U.defaults),U.asOf!==void 0&&(O=U.asOf),U.hint!==void 0&&(W=U.hint);for(let xt of[...z.keys()])C.has(xt)||z.delete(xt);U.focus!==void 0?P=U.focus&&v.includes(U.focus)?U.focus:null:P&&!v.includes(P)&&(P=null),Et(),At(),tt(),ct()}},setOptions(U){ot||(U.contrast&&(o=U.contrast,et()),U.reducedMotion!==void 0&&It?.setOptions({reducedMotion:U.reducedMotion}),U.language&&U.language!==a&&(a=U.language,At(),tt(),ct()))},setSelection(U){ot||(P=U&&v.includes(U)?U:null,At(),tt(),ct())},layout:()=>vt,dispose(){if(!ot){ot=!0,z.clear(),n.clearTimeout(Ht),ie.disconnect(),n.removeEventListener("keydown",ut),t.removeEventListener("click",Ft),t.removeEventListener("input",mt),p.removeEventListener("pointerover",Dt),p.removeEventListener("pointerleave",kt),It?.dispose(),It=null,ee?.dispose(),ee=null,V?.remove(),V=null;for(let U of[d,m,g,p,b,E,y])U.remove();t.classList.remove("lfw","lfw-rim","lfw-dense","lfw-window-mini","lfw-tiny","lfw-zoomed");for(let U of["--lfw-mw","--lf-gauge-top","--lf-gauge-bottom"])t.style.removeProperty(U)}}}}var Q3="1.2.0";export{ni as ABILITY_SCALE,Q3 as LAUNCH_FIELD_VERSION,Yf as MAKER_LOGOS,Kf as MENU_INSIDE_MIN_H,np as SITE_TARGETS,zh as USER_ZOOM_MAX,Bh as USER_ZOOM_MIN,Dh as abilityRange,Uh as abilityTicks,Zf as brandKey,Qf as canopyPoint,Gh as createFlatLaunch,Hh as createLaunchField,j3 as createLaunchWindow,Nh as destination,Zh as escAction,tp as featherWidth,Fh as fieldBand,$c as fieldCoordinates,Wf as flatAriaLabel,Vh as flatInputFromField,Zc as fleetVerdicts,Wh as fuelGrades,Oh as gaugePercent,Yh as layoutWindow,Xh as makerLogoHtml,qh as rasterWindow,Vc as regionFromInsets,Xf as renderFlatSvg,Hc as resolveInsets,Jh as siteRequest};
/*! Bundled license information:

three/build/three.core.js:
three/build/three.module.js:
  (**
   * @license
   * Copyright 2010-2026 Three.js Authors
   * SPDX-License-Identifier: MIT
   *)
*/
