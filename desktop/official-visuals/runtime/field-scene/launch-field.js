/*! SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
 * Copyright (c) 2026 ModelPlan. All rights reserved. ModelPlan and Model Plan are marks of ModelPlan. No trademark rights are granted.
 * Launch field component 1.1.0, window mode (D298), for the official cockpit's enlarged field; see README.md.
 * Bundles three.js 0.186.1 (MIT; its notice is at the end of this file). */
const __LF_ENV__ = { BASE_URL: new URL("./", import.meta.url).href };
var qu=0,$0=1,Yu=2;var Ga=1,Zu=2,wr=3,hs=0,bn=1,Sn=2,qn=0,us=1,on=2,q0=3,Y0=4,Ju=5;var ws=100,Ku=101,ju=102,Qu=103,td=104,ed=200,nd=201,id=202,sd=203,Z0=204,J0=205,rd=206,ad=207,od=208,ld=209,cd=210,hd=211,ud=212,dd=213,fd=214,tl=0,el=1,nl=2,rr=3,il=4,sl=5,rl=6,al=7,K0=0,pd=1,md=2,ci=0,Wa=1,Xa=2,$a=3,Ts=4,qa=5,Ya=6,Za=7;var j0=300,ds=301,As=302,Tr=303,Fl=304,Ja=306,ns=1e3,xi=1001,ol=1002,mn=1003,gd=1004;var Ka=1005;var Mn=1006,Ol=1007;var Si=1008;var Nn=1009,Q0=1010,th=1011,Ar=1012,Bl=1013,hi=1014,Yn=1015,ln=1016,zl=1017,kl=1018,Rr=1020,eh=35902,nh=35899,ih=1021,sh=1022,Zn=1023,vi=1026,fs=1027,Hl=1028,Vl=1029,ps=1030,Gl=1031;var Wl=1033,ja=33776,Qa=33777,to=33778,eo=33779,Xl=35840,$l=35841,ql=35842,Yl=35843,Zl=36196,Jl=37492,Kl=37496,jl=37488,Ql=37489,no=37490,tc=37491,ec=37808,nc=37809,ic=37810,sc=37811,rc=37812,ac=37813,oc=37814,lc=37815,cc=37816,hc=37817,uc=37818,dc=37819,fc=37820,pc=37821,mc=36492,gc=36494,xc=36495,_c=36283,vc=36284,io=36285,yc=36286;var sa=2300,ll=2301,Ko=2302,N0=2303,D0=2400,U0=2401,F0=2402;var xd=3200;var Mc=0,_d=1,ui="",Ye="srgb",ra="srgb-linear",aa="linear",Le="srgb";var jo=7680;var vd=519,yd=512,Md=513,bd=514,bc=515,Sd=516,Ed=517,Sc=518,wd=519,rh=35044;var ah="300 es",ai=2e3,ar=2001;function ap(i){for(let t=i.length-1;t>=0;--t)if(i[t]>=65535)return!0;return!1}function op(i){return ArrayBuffer.isView(i)&&!(i instanceof DataView)}function or(i){return document.createElementNS("http://www.w3.org/1999/xhtml",i)}function Td(){let i=or("canvas");return i.style.display="block",i}var lu={},lr=null;function oa(...i){let t="THREE."+i.shift();lr?lr("log",t,...i):console.log(t,...i)}function Ad(i){let t=i[0];if(typeof t=="string"&&t.startsWith("TSL:")){let e=i[1];e&&e.isStackTrace?i[0]+=" "+e.getLocation():i[1]='Stack trace not available. Enable "THREE.Node.captureStackTrace" to capture stack traces.'}return i}function ue(...i){i=Ad(i);let t="THREE."+i.shift();if(lr)lr("warn",t,...i);else{let e=i[0];e&&e.isStackTrace?console.warn(e.getError(t)):console.warn(t,...i)}}function he(...i){i=Ad(i);let t="THREE."+i.shift();if(lr)lr("error",t,...i);else{let e=i[0];e&&e.isStackTrace?console.error(e.getError(t)):console.error(t,...i)}}function bs(...i){let t=i.join(" ");t in lu||(lu[t]=!0,ue(...i))}function Rd(i,t,e){return new Promise(function(n,s){function r(){switch(i.clientWaitSync(t,i.SYNC_FLUSH_COMMANDS_BIT,0)){case i.WAIT_FAILED:s();break;case i.TIMEOUT_EXPIRED:setTimeout(r,e);break;default:n()}}setTimeout(r,e)})}var Cd={[tl]:el,[nl]:rl,[il]:al,[rr]:sl,[el]:tl,[rl]:nl,[al]:il,[sl]:rr},yi=class{addEventListener(t,e){this._listeners===void 0&&(this._listeners={});let n=this._listeners;n[t]===void 0&&(n[t]=[]),n[t].indexOf(e)===-1&&n[t].push(e)}hasEventListener(t,e){let n=this._listeners;return n===void 0?!1:n[t]!==void 0&&n[t].indexOf(e)!==-1}removeEventListener(t,e){let n=this._listeners;if(n===void 0)return;let s=n[t];if(s!==void 0){let r=s.indexOf(e);r!==-1&&s.splice(r,1)}}dispatchEvent(t){let e=this._listeners;if(e===void 0)return;let n=e[t.type];if(n!==void 0){t.target=this;let s=n.slice(0);for(let r=0,a=s.length;r<a;r++)s[r].call(this,t);t.target=null}}},An=["00","01","02","03","04","05","06","07","08","09","0a","0b","0c","0d","0e","0f","10","11","12","13","14","15","16","17","18","19","1a","1b","1c","1d","1e","1f","20","21","22","23","24","25","26","27","28","29","2a","2b","2c","2d","2e","2f","30","31","32","33","34","35","36","37","38","39","3a","3b","3c","3d","3e","3f","40","41","42","43","44","45","46","47","48","49","4a","4b","4c","4d","4e","4f","50","51","52","53","54","55","56","57","58","59","5a","5b","5c","5d","5e","5f","60","61","62","63","64","65","66","67","68","69","6a","6b","6c","6d","6e","6f","70","71","72","73","74","75","76","77","78","79","7a","7b","7c","7d","7e","7f","80","81","82","83","84","85","86","87","88","89","8a","8b","8c","8d","8e","8f","90","91","92","93","94","95","96","97","98","99","9a","9b","9c","9d","9e","9f","a0","a1","a2","a3","a4","a5","a6","a7","a8","a9","aa","ab","ac","ad","ae","af","b0","b1","b2","b3","b4","b5","b6","b7","b8","b9","ba","bb","bc","bd","be","bf","c0","c1","c2","c3","c4","c5","c6","c7","c8","c9","ca","cb","cc","cd","ce","cf","d0","d1","d2","d3","d4","d5","d6","d7","d8","d9","da","db","dc","dd","de","df","e0","e1","e2","e3","e4","e5","e6","e7","e8","e9","ea","eb","ec","ed","ee","ef","f0","f1","f2","f3","f4","f5","f6","f7","f8","f9","fa","fb","fc","fd","fe","ff"];var r0=Math.PI/180,cl=180/Math.PI;function Oi(){let i=Math.random()*4294967295|0,t=Math.random()*4294967295|0,e=Math.random()*4294967295|0,n=Math.random()*4294967295|0;return(An[i&255]+An[i>>8&255]+An[i>>16&255]+An[i>>24&255]+"-"+An[t&255]+An[t>>8&255]+"-"+An[t>>16&15|64]+An[t>>24&255]+"-"+An[e&63|128]+An[e>>8&255]+"-"+An[e>>16&255]+An[e>>24&255]+An[n&255]+An[n>>8&255]+An[n>>16&255]+An[n>>24&255]).toLowerCase()}function be(i,t,e){return Math.max(t,Math.min(e,i))}function lp(i,t){return(i%t+t)%t}function a0(i,t,e){return(1-e)*i+e*t}function gi(i,t){switch(t.constructor){case Float32Array:return i;case Uint32Array:return i/4294967295;case Uint16Array:return i/65535;case Uint8Array:case Uint8ClampedArray:return i/255;case Int32Array:return Math.max(i/2147483647,-1);case Int16Array:return Math.max(i/32767,-1);case Int8Array:return Math.max(i/127,-1);default:throw new Error("THREE.MathUtils: Invalid component type.")}}function Ge(i,t){switch(t.constructor){case Float32Array:return i;case Uint32Array:return Math.round(i*4294967295);case Uint16Array:return Math.round(i*65535);case Uint8Array:case Uint8ClampedArray:return Math.round(i*255);case Int32Array:return Math.round(i*2147483647);case Int16Array:return Math.round(i*32767);case Int8Array:return Math.round(i*127);default:throw new Error("THREE.MathUtils: Invalid component type.")}}var vt=class i{static{i.prototype.isVector2=!0}constructor(t=0,e=0){this.x=t,this.y=e}get width(){return this.x}set width(t){this.x=t}get height(){return this.y}set height(t){this.y=t}set(t,e){return this.x=t,this.y=e,this}setScalar(t){return this.x=t,this.y=t,this}setX(t){return this.x=t,this}setY(t){return this.y=t,this}setComponent(t,e){switch(t){case 0:this.x=e;break;case 1:this.y=e;break;default:throw new Error("THREE.Vector2: index is out of range: "+t)}return this}getComponent(t){switch(t){case 0:return this.x;case 1:return this.y;default:throw new Error("THREE.Vector2: index is out of range: "+t)}}clone(){return new this.constructor(this.x,this.y)}copy(t){return this.x=t.x,this.y=t.y,this}add(t){return this.x+=t.x,this.y+=t.y,this}addScalar(t){return this.x+=t,this.y+=t,this}addVectors(t,e){return this.x=t.x+e.x,this.y=t.y+e.y,this}addScaledVector(t,e){return this.x+=t.x*e,this.y+=t.y*e,this}sub(t){return this.x-=t.x,this.y-=t.y,this}subScalar(t){return this.x-=t,this.y-=t,this}subVectors(t,e){return this.x=t.x-e.x,this.y=t.y-e.y,this}multiply(t){return this.x*=t.x,this.y*=t.y,this}multiplyScalar(t){return this.x*=t,this.y*=t,this}divide(t){return this.x/=t.x,this.y/=t.y,this}divideScalar(t){return this.multiplyScalar(1/t)}applyMatrix3(t){let e=this.x,n=this.y,s=t.elements;return this.x=s[0]*e+s[3]*n+s[6],this.y=s[1]*e+s[4]*n+s[7],this}min(t){return this.x=Math.min(this.x,t.x),this.y=Math.min(this.y,t.y),this}max(t){return this.x=Math.max(this.x,t.x),this.y=Math.max(this.y,t.y),this}clamp(t,e){return this.x=be(this.x,t.x,e.x),this.y=be(this.y,t.y,e.y),this}clampScalar(t,e){return this.x=be(this.x,t,e),this.y=be(this.y,t,e),this}clampLength(t,e){let n=this.length();return this.divideScalar(n||1).multiplyScalar(be(n,t,e))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this}negate(){return this.x=-this.x,this.y=-this.y,this}dot(t){return this.x*t.x+this.y*t.y}cross(t){return this.x*t.y-this.y*t.x}lengthSq(){return this.x*this.x+this.y*this.y}length(){return Math.sqrt(this.x*this.x+this.y*this.y)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)}normalize(){return this.divideScalar(this.length()||1)}angle(){return Math.atan2(-this.y,-this.x)+Math.PI}angleTo(t){let e=Math.sqrt(this.lengthSq()*t.lengthSq());if(e===0)return Math.PI/2;let n=this.dot(t)/e;return Math.acos(be(n,-1,1))}distanceTo(t){return Math.sqrt(this.distanceToSquared(t))}distanceToSquared(t){let e=this.x-t.x,n=this.y-t.y;return e*e+n*n}manhattanDistanceTo(t){return Math.abs(this.x-t.x)+Math.abs(this.y-t.y)}setLength(t){return this.normalize().multiplyScalar(t)}lerp(t,e){return this.x+=(t.x-this.x)*e,this.y+=(t.y-this.y)*e,this}lerpVectors(t,e,n){return this.x=t.x+(e.x-t.x)*n,this.y=t.y+(e.y-t.y)*n,this}equals(t){return t.x===this.x&&t.y===this.y}fromArray(t,e=0){return this.x=t[e],this.y=t[e+1],this}toArray(t=[],e=0){return t[e]=this.x,t[e+1]=this.y,t}fromBufferAttribute(t,e){return this.x=t.getX(e),this.y=t.getY(e),this}rotateAround(t,e){let n=Math.cos(e),s=Math.sin(e),r=this.x-t.x,a=this.y-t.y;return this.x=r*n-a*s+t.x,this.y=r*s+a*n+t.y,this}random(){return this.x=Math.random(),this.y=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y}},Mi=class{constructor(t=0,e=0,n=0,s=1){this.isQuaternion=!0,this._x=t,this._y=e,this._z=n,this._w=s}static slerpFlat(t,e,n,s,r,a,o){let c=n[s+0],l=n[s+1],h=n[s+2],f=n[s+3],u=r[a+0],d=r[a+1],g=r[a+2],_=r[a+3];if(f!==_||c!==u||l!==d||h!==g){let m=c*u+l*d+h*g+f*_;m<0&&(u=-u,d=-d,g=-g,_=-_,m=-m);let p=1-o;if(m<.9995){let S=Math.acos(m),w=Math.sin(S);p=Math.sin(p*S)/w,o=Math.sin(o*S)/w,c=c*p+u*o,l=l*p+d*o,h=h*p+g*o,f=f*p+_*o}else{c=c*p+u*o,l=l*p+d*o,h=h*p+g*o,f=f*p+_*o;let S=1/Math.sqrt(c*c+l*l+h*h+f*f);c*=S,l*=S,h*=S,f*=S}}t[e]=c,t[e+1]=l,t[e+2]=h,t[e+3]=f}static multiplyQuaternionsFlat(t,e,n,s,r,a){let o=n[s],c=n[s+1],l=n[s+2],h=n[s+3],f=r[a],u=r[a+1],d=r[a+2],g=r[a+3];return t[e]=o*g+h*f+c*d-l*u,t[e+1]=c*g+h*u+l*f-o*d,t[e+2]=l*g+h*d+o*u-c*f,t[e+3]=h*g-o*f-c*u-l*d,t}get x(){return this._x}set x(t){this._x=t,this._onChangeCallback()}get y(){return this._y}set y(t){this._y=t,this._onChangeCallback()}get z(){return this._z}set z(t){this._z=t,this._onChangeCallback()}get w(){return this._w}set w(t){this._w=t,this._onChangeCallback()}set(t,e,n,s){return this._x=t,this._y=e,this._z=n,this._w=s,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._w)}copy(t){return this._x=t.x,this._y=t.y,this._z=t.z,this._w=t.w,this._onChangeCallback(),this}setFromEuler(t,e=!0){let n=t._x,s=t._y,r=t._z,a=t._order,o=Math.cos,c=Math.sin,l=o(n/2),h=o(s/2),f=o(r/2),u=c(n/2),d=c(s/2),g=c(r/2);switch(a){case"XYZ":this._x=u*h*f+l*d*g,this._y=l*d*f-u*h*g,this._z=l*h*g+u*d*f,this._w=l*h*f-u*d*g;break;case"YXZ":this._x=u*h*f+l*d*g,this._y=l*d*f-u*h*g,this._z=l*h*g-u*d*f,this._w=l*h*f+u*d*g;break;case"ZXY":this._x=u*h*f-l*d*g,this._y=l*d*f+u*h*g,this._z=l*h*g+u*d*f,this._w=l*h*f-u*d*g;break;case"ZYX":this._x=u*h*f-l*d*g,this._y=l*d*f+u*h*g,this._z=l*h*g-u*d*f,this._w=l*h*f+u*d*g;break;case"YZX":this._x=u*h*f+l*d*g,this._y=l*d*f+u*h*g,this._z=l*h*g-u*d*f,this._w=l*h*f-u*d*g;break;case"XZY":this._x=u*h*f-l*d*g,this._y=l*d*f-u*h*g,this._z=l*h*g+u*d*f,this._w=l*h*f+u*d*g;break;default:ue("Quaternion: .setFromEuler() encountered an unknown order: "+a)}return e===!0&&this._onChangeCallback(),this}setFromAxisAngle(t,e){let n=e/2,s=Math.sin(n);return this._x=t.x*s,this._y=t.y*s,this._z=t.z*s,this._w=Math.cos(n),this._onChangeCallback(),this}setFromRotationMatrix(t){let e=t.elements,n=e[0],s=e[4],r=e[8],a=e[1],o=e[5],c=e[9],l=e[2],h=e[6],f=e[10],u=n+o+f;if(u>0){let d=.5/Math.sqrt(u+1);this._w=.25/d,this._x=(h-c)*d,this._y=(r-l)*d,this._z=(a-s)*d}else if(n>o&&n>f){let d=2*Math.sqrt(1+n-o-f);this._w=(h-c)/d,this._x=.25*d,this._y=(s+a)/d,this._z=(r+l)/d}else if(o>f){let d=2*Math.sqrt(1+o-n-f);this._w=(r-l)/d,this._x=(s+a)/d,this._y=.25*d,this._z=(c+h)/d}else{let d=2*Math.sqrt(1+f-n-o);this._w=(a-s)/d,this._x=(r+l)/d,this._y=(c+h)/d,this._z=.25*d}return this._onChangeCallback(),this}setFromUnitVectors(t,e){let n=t.dot(e)+1;return n<1e-8?(n=0,Math.abs(t.x)>Math.abs(t.z)?(this._x=-t.y,this._y=t.x,this._z=0,this._w=n):(this._x=0,this._y=-t.z,this._z=t.y,this._w=n)):(this._x=t.y*e.z-t.z*e.y,this._y=t.z*e.x-t.x*e.z,this._z=t.x*e.y-t.y*e.x,this._w=n),this.normalize()}angleTo(t){return 2*Math.acos(Math.abs(be(this.dot(t),-1,1)))}rotateTowards(t,e){let n=this.angleTo(t);if(n===0)return this;let s=Math.min(1,e/n);return this.slerp(t,s),this}identity(){return this.set(0,0,0,1)}invert(){return this.conjugate()}conjugate(){return this._x*=-1,this._y*=-1,this._z*=-1,this._onChangeCallback(),this}dot(t){return this._x*t._x+this._y*t._y+this._z*t._z+this._w*t._w}lengthSq(){return this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w}length(){return Math.sqrt(this._x*this._x+this._y*this._y+this._z*this._z+this._w*this._w)}normalize(){let t=this.length();return t===0?(this._x=0,this._y=0,this._z=0,this._w=1):(t=1/t,this._x=this._x*t,this._y=this._y*t,this._z=this._z*t,this._w=this._w*t),this._onChangeCallback(),this}multiply(t){return this.multiplyQuaternions(this,t)}premultiply(t){return this.multiplyQuaternions(t,this)}multiplyQuaternions(t,e){let n=t._x,s=t._y,r=t._z,a=t._w,o=e._x,c=e._y,l=e._z,h=e._w;return this._x=n*h+a*o+s*l-r*c,this._y=s*h+a*c+r*o-n*l,this._z=r*h+a*l+n*c-s*o,this._w=a*h-n*o-s*c-r*l,this._onChangeCallback(),this}slerp(t,e){let n=t._x,s=t._y,r=t._z,a=t._w,o=this.dot(t);o<0&&(n=-n,s=-s,r=-r,a=-a,o=-o);let c=1-e;if(o<.9995){let l=Math.acos(o),h=Math.sin(l);c=Math.sin(c*l)/h,e=Math.sin(e*l)/h,this._x=this._x*c+n*e,this._y=this._y*c+s*e,this._z=this._z*c+r*e,this._w=this._w*c+a*e,this._onChangeCallback()}else this._x=this._x*c+n*e,this._y=this._y*c+s*e,this._z=this._z*c+r*e,this._w=this._w*c+a*e,this.normalize();return this}slerpQuaternions(t,e,n){return this.copy(t).slerp(e,n)}random(){let t=2*Math.PI*Math.random(),e=2*Math.PI*Math.random(),n=Math.random(),s=Math.sqrt(1-n),r=Math.sqrt(n);return this.set(s*Math.sin(t),s*Math.cos(t),r*Math.sin(e),r*Math.cos(e))}equals(t){return t._x===this._x&&t._y===this._y&&t._z===this._z&&t._w===this._w}fromArray(t,e=0){return this._x=t[e],this._y=t[e+1],this._z=t[e+2],this._w=t[e+3],this._onChangeCallback(),this}toArray(t=[],e=0){return t[e]=this._x,t[e+1]=this._y,t[e+2]=this._z,t[e+3]=this._w,t}fromBufferAttribute(t,e){return this._x=t.getX(e),this._y=t.getY(e),this._z=t.getZ(e),this._w=t.getW(e),this._onChangeCallback(),this}toJSON(){return this.toArray()}_onChange(t){return this._onChangeCallback=t,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._w}},D=class i{static{i.prototype.isVector3=!0}constructor(t=0,e=0,n=0){this.x=t,this.y=e,this.z=n}set(t,e,n){return n===void 0&&(n=this.z),this.x=t,this.y=e,this.z=n,this}setScalar(t){return this.x=t,this.y=t,this.z=t,this}setX(t){return this.x=t,this}setY(t){return this.y=t,this}setZ(t){return this.z=t,this}setComponent(t,e){switch(t){case 0:this.x=e;break;case 1:this.y=e;break;case 2:this.z=e;break;default:throw new Error("THREE.Vector3: index is out of range: "+t)}return this}getComponent(t){switch(t){case 0:return this.x;case 1:return this.y;case 2:return this.z;default:throw new Error("THREE.Vector3: index is out of range: "+t)}}clone(){return new this.constructor(this.x,this.y,this.z)}copy(t){return this.x=t.x,this.y=t.y,this.z=t.z,this}add(t){return this.x+=t.x,this.y+=t.y,this.z+=t.z,this}addScalar(t){return this.x+=t,this.y+=t,this.z+=t,this}addVectors(t,e){return this.x=t.x+e.x,this.y=t.y+e.y,this.z=t.z+e.z,this}addScaledVector(t,e){return this.x+=t.x*e,this.y+=t.y*e,this.z+=t.z*e,this}sub(t){return this.x-=t.x,this.y-=t.y,this.z-=t.z,this}subScalar(t){return this.x-=t,this.y-=t,this.z-=t,this}subVectors(t,e){return this.x=t.x-e.x,this.y=t.y-e.y,this.z=t.z-e.z,this}multiply(t){return this.x*=t.x,this.y*=t.y,this.z*=t.z,this}multiplyScalar(t){return this.x*=t,this.y*=t,this.z*=t,this}multiplyVectors(t,e){return this.x=t.x*e.x,this.y=t.y*e.y,this.z=t.z*e.z,this}applyEuler(t){return this.applyQuaternion(cu.setFromEuler(t))}applyAxisAngle(t,e){return this.applyQuaternion(cu.setFromAxisAngle(t,e))}applyMatrix3(t){let e=this.x,n=this.y,s=this.z,r=t.elements;return this.x=r[0]*e+r[3]*n+r[6]*s,this.y=r[1]*e+r[4]*n+r[7]*s,this.z=r[2]*e+r[5]*n+r[8]*s,this}applyNormalMatrix(t){return this.applyMatrix3(t).normalize()}applyMatrix4(t){let e=this.x,n=this.y,s=this.z,r=t.elements,a=1/(r[3]*e+r[7]*n+r[11]*s+r[15]);return this.x=(r[0]*e+r[4]*n+r[8]*s+r[12])*a,this.y=(r[1]*e+r[5]*n+r[9]*s+r[13])*a,this.z=(r[2]*e+r[6]*n+r[10]*s+r[14])*a,this}applyQuaternion(t){let e=this.x,n=this.y,s=this.z,r=t.x,a=t.y,o=t.z,c=t.w,l=2*(a*s-o*n),h=2*(o*e-r*s),f=2*(r*n-a*e);return this.x=e+c*l+a*f-o*h,this.y=n+c*h+o*l-r*f,this.z=s+c*f+r*h-a*l,this}project(t){return this.applyMatrix4(t.matrixWorldInverse).applyMatrix4(t.projectionMatrix)}unproject(t){return this.applyMatrix4(t.projectionMatrixInverse).applyMatrix4(t.matrixWorld)}transformDirection(t){let e=this.x,n=this.y,s=this.z,r=t.elements;return this.x=r[0]*e+r[4]*n+r[8]*s,this.y=r[1]*e+r[5]*n+r[9]*s,this.z=r[2]*e+r[6]*n+r[10]*s,this.normalize()}divide(t){return this.x/=t.x,this.y/=t.y,this.z/=t.z,this}divideScalar(t){return this.multiplyScalar(1/t)}min(t){return this.x=Math.min(this.x,t.x),this.y=Math.min(this.y,t.y),this.z=Math.min(this.z,t.z),this}max(t){return this.x=Math.max(this.x,t.x),this.y=Math.max(this.y,t.y),this.z=Math.max(this.z,t.z),this}clamp(t,e){return this.x=be(this.x,t.x,e.x),this.y=be(this.y,t.y,e.y),this.z=be(this.z,t.z,e.z),this}clampScalar(t,e){return this.x=be(this.x,t,e),this.y=be(this.y,t,e),this.z=be(this.z,t,e),this}clampLength(t,e){let n=this.length();return this.divideScalar(n||1).multiplyScalar(be(n,t,e))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this}dot(t){return this.x*t.x+this.y*t.y+this.z*t.z}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)}normalize(){return this.divideScalar(this.length()||1)}setLength(t){return this.normalize().multiplyScalar(t)}lerp(t,e){return this.x+=(t.x-this.x)*e,this.y+=(t.y-this.y)*e,this.z+=(t.z-this.z)*e,this}lerpVectors(t,e,n){return this.x=t.x+(e.x-t.x)*n,this.y=t.y+(e.y-t.y)*n,this.z=t.z+(e.z-t.z)*n,this}cross(t){return this.crossVectors(this,t)}crossVectors(t,e){let n=t.x,s=t.y,r=t.z,a=e.x,o=e.y,c=e.z;return this.x=s*c-r*o,this.y=r*a-n*c,this.z=n*o-s*a,this}projectOnVector(t){let e=t.lengthSq();if(e===0)return this.set(0,0,0);let n=t.dot(this)/e;return this.copy(t).multiplyScalar(n)}projectOnPlane(t){return o0.copy(this).projectOnVector(t),this.sub(o0)}reflect(t){return this.sub(o0.copy(t).multiplyScalar(2*this.dot(t)))}angleTo(t){let e=Math.sqrt(this.lengthSq()*t.lengthSq());if(e===0)return Math.PI/2;let n=this.dot(t)/e;return Math.acos(be(n,-1,1))}distanceTo(t){return Math.sqrt(this.distanceToSquared(t))}distanceToSquared(t){let e=this.x-t.x,n=this.y-t.y,s=this.z-t.z;return e*e+n*n+s*s}manhattanDistanceTo(t){return Math.abs(this.x-t.x)+Math.abs(this.y-t.y)+Math.abs(this.z-t.z)}setFromSpherical(t){return this.setFromSphericalCoords(t.radius,t.phi,t.theta)}setFromSphericalCoords(t,e,n){let s=Math.sin(e)*t;return this.x=s*Math.sin(n),this.y=Math.cos(e)*t,this.z=s*Math.cos(n),this}setFromCylindrical(t){return this.setFromCylindricalCoords(t.radius,t.theta,t.y)}setFromCylindricalCoords(t,e,n){return this.x=t*Math.sin(e),this.y=n,this.z=t*Math.cos(e),this}setFromMatrixPosition(t){let e=t.elements;return this.x=e[12],this.y=e[13],this.z=e[14],this}setFromMatrixScale(t){let e=this.setFromMatrixColumn(t,0).length(),n=this.setFromMatrixColumn(t,1).length(),s=this.setFromMatrixColumn(t,2).length();return this.x=e,this.y=n,this.z=s,this}setFromMatrixColumn(t,e){return this.fromArray(t.elements,e*4)}setFromMatrix3Column(t,e){return this.fromArray(t.elements,e*3)}setFromEuler(t){return this.x=t._x,this.y=t._y,this.z=t._z,this}setFromColor(t){return this.x=t.r,this.y=t.g,this.z=t.b,this}equals(t){return t.x===this.x&&t.y===this.y&&t.z===this.z}fromArray(t,e=0){return this.x=t[e],this.y=t[e+1],this.z=t[e+2],this}toArray(t=[],e=0){return t[e]=this.x,t[e+1]=this.y,t[e+2]=this.z,t}fromBufferAttribute(t,e){return this.x=t.getX(e),this.y=t.getY(e),this.z=t.getZ(e),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this}randomDirection(){let t=Math.random()*Math.PI*2,e=Math.random()*2-1,n=Math.sqrt(1-e*e);return this.x=n*Math.cos(t),this.y=e,this.z=n*Math.sin(t),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z}},o0=new D,cu=new Mi,me=class i{static{i.prototype.isMatrix3=!0}constructor(t,e,n,s,r,a,o,c,l){this.elements=[1,0,0,0,1,0,0,0,1],t!==void 0&&this.set(t,e,n,s,r,a,o,c,l)}set(t,e,n,s,r,a,o,c,l){let h=this.elements;return h[0]=t,h[1]=s,h[2]=o,h[3]=e,h[4]=r,h[5]=c,h[6]=n,h[7]=a,h[8]=l,this}identity(){return this.set(1,0,0,0,1,0,0,0,1),this}copy(t){let e=this.elements,n=t.elements;return e[0]=n[0],e[1]=n[1],e[2]=n[2],e[3]=n[3],e[4]=n[4],e[5]=n[5],e[6]=n[6],e[7]=n[7],e[8]=n[8],this}extractBasis(t,e,n){return t.setFromMatrix3Column(this,0),e.setFromMatrix3Column(this,1),n.setFromMatrix3Column(this,2),this}setFromMatrix4(t){let e=t.elements;return this.set(e[0],e[4],e[8],e[1],e[5],e[9],e[2],e[6],e[10]),this}multiply(t){return this.multiplyMatrices(this,t)}premultiply(t){return this.multiplyMatrices(t,this)}multiplyMatrices(t,e){let n=t.elements,s=e.elements,r=this.elements,a=n[0],o=n[3],c=n[6],l=n[1],h=n[4],f=n[7],u=n[2],d=n[5],g=n[8],_=s[0],m=s[3],p=s[6],S=s[1],w=s[4],y=s[7],E=s[2],M=s[5],I=s[8];return r[0]=a*_+o*S+c*E,r[3]=a*m+o*w+c*M,r[6]=a*p+o*y+c*I,r[1]=l*_+h*S+f*E,r[4]=l*m+h*w+f*M,r[7]=l*p+h*y+f*I,r[2]=u*_+d*S+g*E,r[5]=u*m+d*w+g*M,r[8]=u*p+d*y+g*I,this}multiplyScalar(t){let e=this.elements;return e[0]*=t,e[3]*=t,e[6]*=t,e[1]*=t,e[4]*=t,e[7]*=t,e[2]*=t,e[5]*=t,e[8]*=t,this}determinant(){let t=this.elements,e=t[0],n=t[1],s=t[2],r=t[3],a=t[4],o=t[5],c=t[6],l=t[7],h=t[8];return e*a*h-e*o*l-n*r*h+n*o*c+s*r*l-s*a*c}invert(){let t=this.elements,e=t[0],n=t[1],s=t[2],r=t[3],a=t[4],o=t[5],c=t[6],l=t[7],h=t[8],f=h*a-o*l,u=o*c-h*r,d=l*r-a*c,g=e*f+n*u+s*d;if(g===0)return this.set(0,0,0,0,0,0,0,0,0);let _=1/g;return t[0]=f*_,t[1]=(s*l-h*n)*_,t[2]=(o*n-s*a)*_,t[3]=u*_,t[4]=(h*e-s*c)*_,t[5]=(s*r-o*e)*_,t[6]=d*_,t[7]=(n*c-l*e)*_,t[8]=(a*e-n*r)*_,this}transpose(){let t,e=this.elements;return t=e[1],e[1]=e[3],e[3]=t,t=e[2],e[2]=e[6],e[6]=t,t=e[5],e[5]=e[7],e[7]=t,this}getNormalMatrix(t){return this.setFromMatrix4(t).invert().transpose()}transposeIntoArray(t){let e=this.elements;return t[0]=e[0],t[1]=e[3],t[2]=e[6],t[3]=e[1],t[4]=e[4],t[5]=e[7],t[6]=e[2],t[7]=e[5],t[8]=e[8],this}setUvTransform(t,e,n,s,r,a,o){let c=Math.cos(r),l=Math.sin(r);return this.set(n*c,n*l,-n*(c*a+l*o)+a+t,-s*l,s*c,-s*(-l*a+c*o)+o+e,0,0,1),this}scale(t,e){return bs("Matrix3: .scale() is deprecated. Use .makeScale() instead."),this.premultiply(l0.makeScale(t,e)),this}rotate(t){return bs("Matrix3: .rotate() is deprecated. Use .makeRotation() instead."),this.premultiply(l0.makeRotation(-t)),this}translate(t,e){return bs("Matrix3: .translate() is deprecated. Use .makeTranslation() instead."),this.premultiply(l0.makeTranslation(t,e)),this}makeTranslation(t,e){return t.isVector2?this.set(1,0,t.x,0,1,t.y,0,0,1):this.set(1,0,t,0,1,e,0,0,1),this}makeRotation(t){let e=Math.cos(t),n=Math.sin(t);return this.set(e,-n,0,n,e,0,0,0,1),this}makeScale(t,e){return this.set(t,0,0,0,e,0,0,0,1),this}equals(t){let e=this.elements,n=t.elements;for(let s=0;s<9;s++)if(e[s]!==n[s])return!1;return!0}fromArray(t,e=0){for(let n=0;n<9;n++)this.elements[n]=t[n+e];return this}toArray(t=[],e=0){let n=this.elements;return t[e]=n[0],t[e+1]=n[1],t[e+2]=n[2],t[e+3]=n[3],t[e+4]=n[4],t[e+5]=n[5],t[e+6]=n[6],t[e+7]=n[7],t[e+8]=n[8],t}clone(){return new this.constructor().fromArray(this.elements)}},l0=new me,hu=new me().set(.4123908,.3575843,.1804808,.212639,.7151687,.0721923,.0193308,.1191948,.9505322),uu=new me().set(3.2409699,-1.5373832,-.4986108,-.9692436,1.8759675,.0415551,.0556301,-.203977,1.0569715);function cp(){let i={enabled:!0,workingColorSpace:ra,spaces:{},convert:function(s,r,a){return this.enabled===!1||r===a||!r||!a||(this.spaces[r].transfer===Le&&(s.r=Bi(s.r),s.g=Bi(s.g),s.b=Bi(s.b)),this.spaces[r].primaries!==this.spaces[a].primaries&&(s.applyMatrix3(this.spaces[r].toXYZ),s.applyMatrix3(this.spaces[a].fromXYZ)),this.spaces[a].transfer===Le&&(s.r=sr(s.r),s.g=sr(s.g),s.b=sr(s.b))),s},workingToColorSpace:function(s,r){return this.convert(s,this.workingColorSpace,r)},colorSpaceToWorking:function(s,r){return this.convert(s,r,this.workingColorSpace)},getPrimaries:function(s){return this.spaces[s].primaries},getTransfer:function(s){return s===ui?aa:this.spaces[s].transfer},getToneMappingMode:function(s){return this.spaces[s].outputColorSpaceConfig.toneMappingMode||"standard"},getLuminanceCoefficients:function(s,r=this.workingColorSpace){return s.fromArray(this.spaces[r].luminanceCoefficients)},define:function(s){Object.assign(this.spaces,s)},_getMatrix:function(s,r,a){return s.copy(this.spaces[r].toXYZ).multiply(this.spaces[a].fromXYZ)},_getDrawingBufferColorSpace:function(s){return this.spaces[s].outputColorSpaceConfig.drawingBufferColorSpace},_getUnpackColorSpace:function(s=this.workingColorSpace){return this.spaces[s].workingColorSpaceConfig.unpackColorSpace},fromWorkingColorSpace:function(s,r){return bs("ColorManagement: .fromWorkingColorSpace() has been renamed to .workingToColorSpace()."),i.workingToColorSpace(s,r)},toWorkingColorSpace:function(s,r){return bs("ColorManagement: .toWorkingColorSpace() has been renamed to .colorSpaceToWorking()."),i.colorSpaceToWorking(s,r)}},t=[.64,.33,.3,.6,.15,.06],e=[.2126,.7152,.0722],n=[.3127,.329];return i.define({[ra]:{primaries:t,whitePoint:n,transfer:aa,toXYZ:hu,fromXYZ:uu,luminanceCoefficients:e,workingColorSpaceConfig:{unpackColorSpace:Ye},outputColorSpaceConfig:{drawingBufferColorSpace:Ye}},[Ye]:{primaries:t,whitePoint:n,transfer:Le,toXYZ:hu,fromXYZ:uu,luminanceCoefficients:e,outputColorSpaceConfig:{drawingBufferColorSpace:Ye}}}),i}var Se=cp();function Bi(i){return i<.04045?i*.0773993808:Math.pow(i*.9478672986+.0521327014,2.4)}function sr(i){return i<.0031308?i*12.92:1.055*Math.pow(i,.41666)-.055}var zs,hl=class{static getDataURL(t,e="image/png"){if(/^data:/i.test(t.src)||typeof HTMLCanvasElement>"u")return t.src;let n;if(t instanceof HTMLCanvasElement)n=t;else{zs===void 0&&(zs=or("canvas")),zs.width=t.width,zs.height=t.height;let s=zs.getContext("2d");t instanceof ImageData?s.putImageData(t,0,0):s.drawImage(t,0,0,t.width,t.height),n=zs}return n.toDataURL(e)}static sRGBToLinear(t){if(typeof HTMLImageElement<"u"&&t instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&t instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&t instanceof ImageBitmap){let e=or("canvas");e.width=t.width,e.height=t.height;let n=e.getContext("2d");n.drawImage(t,0,0,t.width,t.height);let s=n.getImageData(0,0,t.width,t.height),r=s.data;for(let a=0;a<r.length;a++)r[a]=Bi(r[a]/255)*255;return n.putImageData(s,0,0),e}else if(t.data){let e=t.data.slice(0);for(let n=0;n<e.length;n++)e instanceof Uint8Array||e instanceof Uint8ClampedArray?e[n]=Math.floor(Bi(e[n]/255)*255):e[n]=Bi(e[n]);return{data:e,width:t.width,height:t.height}}else return ue("ImageUtils.sRGBToLinear(): Unsupported image type. No color space conversion applied."),t}},hp=0,cr=class{constructor(t=null){this.isTextureSource=!0,Object.defineProperty(this,"id",{value:hp++}),this.uuid=Oi(),this.data=t,this.dataReady=!0,this.version=0}getSize(t){let e=this.data;return typeof HTMLVideoElement<"u"&&e instanceof HTMLVideoElement?t.set(e.videoWidth,e.videoHeight,0):typeof VideoFrame<"u"&&e instanceof VideoFrame?t.set(e.displayWidth,e.displayHeight,0):e!==null?t.set(e.width,e.height,e.depth||0):t.set(0,0,0),t}set needsUpdate(t){t===!0&&this.version++}toJSON(t){let e=t===void 0||typeof t=="string";if(!e&&t.images[this.uuid]!==void 0)return t.images[this.uuid];let n={uuid:this.uuid,url:""},s=this.data;if(s!==null){let r;if(Array.isArray(s)){r=[];for(let a=0,o=s.length;a<o;a++)s[a].isDataTexture?r.push(c0(s[a].image)):r.push(c0(s[a]))}else r=c0(s);n.url=r}return e||(t.images[this.uuid]=n),n}};function c0(i){return typeof HTMLImageElement<"u"&&i instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&i instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&i instanceof ImageBitmap?hl.getDataURL(i):i.data?{data:Array.from(i.data),width:i.width,height:i.height,type:i.data.constructor.name}:(ue("Texture: Unable to serialize Texture."),{})}var up=0,h0=new D,gn=class i extends yi{constructor(t=i.DEFAULT_IMAGE,e=i.DEFAULT_MAPPING,n=xi,s=xi,r=Mn,a=Si,o=Zn,c=Nn,l=i.DEFAULT_ANISOTROPY,h=ui){super(),this.isTexture=!0,Object.defineProperty(this,"id",{value:up++}),this.uuid=Oi(),this.name="",this.source=new cr(t),this.mipmaps=[],this.mapping=e,this.channel=0,this.wrapS=n,this.wrapT=s,this.magFilter=r,this.minFilter=a,this.anisotropy=l,this.format=o,this.internalFormat=null,this.type=c,this.offset=new vt(0,0),this.repeat=new vt(1,1),this.center=new vt(0,0),this.rotation=0,this.matrixAutoUpdate=!0,this.matrix=new me,this.generateMipmaps=!0,this.premultiplyAlpha=!1,this.flipY=!0,this.unpackAlignment=4,this.colorSpace=h,this.userData={},this.updateRanges=[],this.version=0,this.onUpdate=null,this.renderTarget=null,this.isRenderTargetTexture=!1,this.isArrayTexture=!!(t&&t.depth&&t.depth>1),this.pmremVersion=0,this.normalized=!1}get width(){return this.source.getSize(h0).x}get height(){return this.source.getSize(h0).y}get depth(){return this.source.getSize(h0).z}get image(){return this.source.data}set image(t){this.source.data=t}updateMatrix(){this.matrix.setUvTransform(this.offset.x,this.offset.y,this.repeat.x,this.repeat.y,this.rotation,this.center.x,this.center.y)}addUpdateRange(t,e){this.updateRanges.push({start:t,count:e})}clearUpdateRanges(){this.updateRanges.length=0}clone(){return new this.constructor().copy(this)}copy(t){return this.name=t.name,this.source=t.source,this.mipmaps=t.mipmaps.slice(0),this.mapping=t.mapping,this.channel=t.channel,this.wrapS=t.wrapS,this.wrapT=t.wrapT,this.magFilter=t.magFilter,this.minFilter=t.minFilter,this.anisotropy=t.anisotropy,this.format=t.format,this.internalFormat=t.internalFormat,this.type=t.type,this.normalized=t.normalized,this.offset.copy(t.offset),this.repeat.copy(t.repeat),this.center.copy(t.center),this.rotation=t.rotation,this.matrixAutoUpdate=t.matrixAutoUpdate,this.matrix.copy(t.matrix),this.generateMipmaps=t.generateMipmaps,this.premultiplyAlpha=t.premultiplyAlpha,this.flipY=t.flipY,this.unpackAlignment=t.unpackAlignment,this.colorSpace=t.colorSpace,this.renderTarget=t.renderTarget,this.isRenderTargetTexture=t.isRenderTargetTexture,this.isArrayTexture=t.isArrayTexture,this.userData=JSON.parse(JSON.stringify(t.userData)),this.needsUpdate=!0,this}setValues(t){for(let e in t){let n=t[e];if(n===void 0){ue(`Texture.setValues(): parameter '${e}' has value of undefined.`);continue}let s=this[e];if(s===void 0){ue(`Texture.setValues(): property '${e}' does not exist.`);continue}s&&n&&s.isVector2&&n.isVector2||s&&n&&s.isVector3&&n.isVector3||s&&n&&s.isMatrix3&&n.isMatrix3?s.copy(n):this[e]=n}}toJSON(t){let e=t===void 0||typeof t=="string";if(!e&&t.textures[this.uuid]!==void 0)return t.textures[this.uuid];let n={metadata:{version:4.7,type:"Texture",generator:"Texture.toJSON"},uuid:this.uuid,name:this.name,image:this.source.toJSON(t).uuid,mapping:this.mapping,channel:this.channel,repeat:[this.repeat.x,this.repeat.y],offset:[this.offset.x,this.offset.y],center:[this.center.x,this.center.y],rotation:this.rotation,wrap:[this.wrapS,this.wrapT],format:this.format,internalFormat:this.internalFormat,type:this.type,normalized:this.normalized,colorSpace:this.colorSpace,minFilter:this.minFilter,magFilter:this.magFilter,anisotropy:this.anisotropy,flipY:this.flipY,generateMipmaps:this.generateMipmaps,premultiplyAlpha:this.premultiplyAlpha,unpackAlignment:this.unpackAlignment};return Object.keys(this.userData).length>0&&(n.userData=this.userData),e||(t.textures[this.uuid]=n),n}dispose(){this.dispatchEvent({type:"dispose"})}transformUv(t){if(this.mapping!==j0)return t;if(t.applyMatrix3(this.matrix),t.x<0||t.x>1)switch(this.wrapS){case ns:t.x=t.x-Math.floor(t.x);break;case xi:t.x=t.x<0?0:1;break;case ol:Math.abs(Math.floor(t.x)%2)===1?t.x=Math.ceil(t.x)-t.x:t.x=t.x-Math.floor(t.x);break}if(t.y<0||t.y>1)switch(this.wrapT){case ns:t.y=t.y-Math.floor(t.y);break;case xi:t.y=t.y<0?0:1;break;case ol:Math.abs(Math.floor(t.y)%2)===1?t.y=Math.ceil(t.y)-t.y:t.y=t.y-Math.floor(t.y);break}return this.flipY&&(t.y=1-t.y),t}set needsUpdate(t){t===!0&&(this.version++,this.source.needsUpdate=!0)}set needsPMREMUpdate(t){t===!0&&this.pmremVersion++}};gn.DEFAULT_IMAGE=null;gn.DEFAULT_MAPPING=j0;gn.DEFAULT_ANISOTROPY=1;var $e=class i{static{i.prototype.isVector4=!0}constructor(t=0,e=0,n=0,s=1){this.x=t,this.y=e,this.z=n,this.w=s}get width(){return this.z}set width(t){this.z=t}get height(){return this.w}set height(t){this.w=t}set(t,e,n,s){return this.x=t,this.y=e,this.z=n,this.w=s,this}setScalar(t){return this.x=t,this.y=t,this.z=t,this.w=t,this}setX(t){return this.x=t,this}setY(t){return this.y=t,this}setZ(t){return this.z=t,this}setW(t){return this.w=t,this}setComponent(t,e){switch(t){case 0:this.x=e;break;case 1:this.y=e;break;case 2:this.z=e;break;case 3:this.w=e;break;default:throw new Error("THREE.Vector4: index is out of range: "+t)}return this}getComponent(t){switch(t){case 0:return this.x;case 1:return this.y;case 2:return this.z;case 3:return this.w;default:throw new Error("THREE.Vector4: index is out of range: "+t)}}clone(){return new this.constructor(this.x,this.y,this.z,this.w)}copy(t){return this.x=t.x,this.y=t.y,this.z=t.z,this.w=t.w!==void 0?t.w:1,this}add(t){return this.x+=t.x,this.y+=t.y,this.z+=t.z,this.w+=t.w,this}addScalar(t){return this.x+=t,this.y+=t,this.z+=t,this.w+=t,this}addVectors(t,e){return this.x=t.x+e.x,this.y=t.y+e.y,this.z=t.z+e.z,this.w=t.w+e.w,this}addScaledVector(t,e){return this.x+=t.x*e,this.y+=t.y*e,this.z+=t.z*e,this.w+=t.w*e,this}sub(t){return this.x-=t.x,this.y-=t.y,this.z-=t.z,this.w-=t.w,this}subScalar(t){return this.x-=t,this.y-=t,this.z-=t,this.w-=t,this}subVectors(t,e){return this.x=t.x-e.x,this.y=t.y-e.y,this.z=t.z-e.z,this.w=t.w-e.w,this}multiply(t){return this.x*=t.x,this.y*=t.y,this.z*=t.z,this.w*=t.w,this}multiplyScalar(t){return this.x*=t,this.y*=t,this.z*=t,this.w*=t,this}applyMatrix4(t){let e=this.x,n=this.y,s=this.z,r=this.w,a=t.elements;return this.x=a[0]*e+a[4]*n+a[8]*s+a[12]*r,this.y=a[1]*e+a[5]*n+a[9]*s+a[13]*r,this.z=a[2]*e+a[6]*n+a[10]*s+a[14]*r,this.w=a[3]*e+a[7]*n+a[11]*s+a[15]*r,this}divide(t){return this.x/=t.x,this.y/=t.y,this.z/=t.z,this.w/=t.w,this}divideScalar(t){return this.multiplyScalar(1/t)}setAxisAngleFromQuaternion(t){this.w=2*Math.acos(t.w);let e=Math.sqrt(1-t.w*t.w);return e<1e-4?(this.x=1,this.y=0,this.z=0):(this.x=t.x/e,this.y=t.y/e,this.z=t.z/e),this}setAxisAngleFromRotationMatrix(t){let e,n,s,r,c=t.elements,l=c[0],h=c[4],f=c[8],u=c[1],d=c[5],g=c[9],_=c[2],m=c[6],p=c[10];if(Math.abs(h-u)<.01&&Math.abs(f-_)<.01&&Math.abs(g-m)<.01){if(Math.abs(h+u)<.1&&Math.abs(f+_)<.1&&Math.abs(g+m)<.1&&Math.abs(l+d+p-3)<.1)return this.set(1,0,0,0),this;e=Math.PI;let w=(l+1)/2,y=(d+1)/2,E=(p+1)/2,M=(h+u)/4,I=(f+_)/4,v=(g+m)/4;return w>y&&w>E?w<.01?(n=0,s=.707106781,r=.707106781):(n=Math.sqrt(w),s=M/n,r=I/n):y>E?y<.01?(n=.707106781,s=0,r=.707106781):(s=Math.sqrt(y),n=M/s,r=v/s):E<.01?(n=.707106781,s=.707106781,r=0):(r=Math.sqrt(E),n=I/r,s=v/r),this.set(n,s,r,e),this}let S=Math.sqrt((m-g)*(m-g)+(f-_)*(f-_)+(u-h)*(u-h));return Math.abs(S)<.001&&(S=1),this.x=(m-g)/S,this.y=(f-_)/S,this.z=(u-h)/S,this.w=Math.acos((l+d+p-1)/2),this}setFromMatrixPosition(t){let e=t.elements;return this.x=e[12],this.y=e[13],this.z=e[14],this.w=e[15],this}min(t){return this.x=Math.min(this.x,t.x),this.y=Math.min(this.y,t.y),this.z=Math.min(this.z,t.z),this.w=Math.min(this.w,t.w),this}max(t){return this.x=Math.max(this.x,t.x),this.y=Math.max(this.y,t.y),this.z=Math.max(this.z,t.z),this.w=Math.max(this.w,t.w),this}clamp(t,e){return this.x=be(this.x,t.x,e.x),this.y=be(this.y,t.y,e.y),this.z=be(this.z,t.z,e.z),this.w=be(this.w,t.w,e.w),this}clampScalar(t,e){return this.x=be(this.x,t,e),this.y=be(this.y,t,e),this.z=be(this.z,t,e),this.w=be(this.w,t,e),this}clampLength(t,e){let n=this.length();return this.divideScalar(n||1).multiplyScalar(be(n,t,e))}floor(){return this.x=Math.floor(this.x),this.y=Math.floor(this.y),this.z=Math.floor(this.z),this.w=Math.floor(this.w),this}ceil(){return this.x=Math.ceil(this.x),this.y=Math.ceil(this.y),this.z=Math.ceil(this.z),this.w=Math.ceil(this.w),this}round(){return this.x=Math.round(this.x),this.y=Math.round(this.y),this.z=Math.round(this.z),this.w=Math.round(this.w),this}roundToZero(){return this.x=Math.trunc(this.x),this.y=Math.trunc(this.y),this.z=Math.trunc(this.z),this.w=Math.trunc(this.w),this}negate(){return this.x=-this.x,this.y=-this.y,this.z=-this.z,this.w=-this.w,this}dot(t){return this.x*t.x+this.y*t.y+this.z*t.z+this.w*t.w}lengthSq(){return this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w}length(){return Math.sqrt(this.x*this.x+this.y*this.y+this.z*this.z+this.w*this.w)}manhattanLength(){return Math.abs(this.x)+Math.abs(this.y)+Math.abs(this.z)+Math.abs(this.w)}normalize(){return this.divideScalar(this.length()||1)}setLength(t){return this.normalize().multiplyScalar(t)}lerp(t,e){return this.x+=(t.x-this.x)*e,this.y+=(t.y-this.y)*e,this.z+=(t.z-this.z)*e,this.w+=(t.w-this.w)*e,this}lerpVectors(t,e,n){return this.x=t.x+(e.x-t.x)*n,this.y=t.y+(e.y-t.y)*n,this.z=t.z+(e.z-t.z)*n,this.w=t.w+(e.w-t.w)*n,this}equals(t){return t.x===this.x&&t.y===this.y&&t.z===this.z&&t.w===this.w}fromArray(t,e=0){return this.x=t[e],this.y=t[e+1],this.z=t[e+2],this.w=t[e+3],this}toArray(t=[],e=0){return t[e]=this.x,t[e+1]=this.y,t[e+2]=this.z,t[e+3]=this.w,t}fromBufferAttribute(t,e){return this.x=t.getX(e),this.y=t.getY(e),this.z=t.getZ(e),this.w=t.getW(e),this}random(){return this.x=Math.random(),this.y=Math.random(),this.z=Math.random(),this.w=Math.random(),this}*[Symbol.iterator](){yield this.x,yield this.y,yield this.z,yield this.w}},ul=class extends yi{constructor(t=1,e=1,n={}){super(),n=Object.assign({generateMipmaps:!1,internalFormat:null,minFilter:Mn,depthBuffer:!0,stencilBuffer:!1,resolveColorBuffer:!0,resolveDepthBuffer:!0,resolveStencilBuffer:!0,storeMultisampledColorBuffer:!0,storeMultisampledDepthBuffer:!0,storeMultisampledStencilBuffer:!0,depthTexture:null,samples:0,count:1,depth:1,multiview:!1,useArrayDepthTexture:!1},n),this.isRenderTarget=!0,this.width=t,this.height=e,this.depth=n.depth,this.scissor=new $e(0,0,t,e),this.scissorTest=!1,this.viewport=new $e(0,0,t,e),this.textures=[];let s={width:t,height:e,depth:n.depth},r=new gn(s),a=n.count;for(let o=0;o<a;o++)this.textures[o]=r.clone(),this.textures[o].isRenderTargetTexture=!0,this.textures[o].renderTarget=this;this._setTextureOptions(n),this.depthBuffer=n.depthBuffer,this.stencilBuffer=n.stencilBuffer,this.resolveColorBuffer=n.resolveColorBuffer,this.resolveDepthBuffer=n.resolveDepthBuffer,this.resolveStencilBuffer=n.resolveStencilBuffer,this.storeMultisampledColorBuffer=n.storeMultisampledColorBuffer,this.storeMultisampledDepthBuffer=n.storeMultisampledDepthBuffer,this.storeMultisampledStencilBuffer=n.storeMultisampledStencilBuffer,this._depthTexture=null,this.depthTexture=n.depthTexture,this.samples=n.samples,this.multiview=n.multiview,this.useArrayDepthTexture=n.useArrayDepthTexture}_setTextureOptions(t={}){let e={minFilter:Mn,generateMipmaps:!1,flipY:!1,internalFormat:null};t.mapping!==void 0&&(e.mapping=t.mapping),t.wrapS!==void 0&&(e.wrapS=t.wrapS),t.wrapT!==void 0&&(e.wrapT=t.wrapT),t.wrapR!==void 0&&(e.wrapR=t.wrapR),t.magFilter!==void 0&&(e.magFilter=t.magFilter),t.minFilter!==void 0&&(e.minFilter=t.minFilter),t.format!==void 0&&(e.format=t.format),t.type!==void 0&&(e.type=t.type),t.anisotropy!==void 0&&(e.anisotropy=t.anisotropy),t.colorSpace!==void 0&&(e.colorSpace=t.colorSpace),t.flipY!==void 0&&(e.flipY=t.flipY),t.generateMipmaps!==void 0&&(e.generateMipmaps=t.generateMipmaps),t.internalFormat!==void 0&&(e.internalFormat=t.internalFormat);for(let n=0;n<this.textures.length;n++)this.textures[n].setValues(e)}get texture(){return this.textures[0]}set texture(t){this.textures[0]=t}set depthTexture(t){this._depthTexture!==null&&this._depthTexture.renderTarget===this&&(this._depthTexture.renderTarget=null),t!==null&&t.renderTarget===null&&(t.renderTarget=this),this._depthTexture=t}get depthTexture(){return this._depthTexture}setSize(t,e,n=1){if(this.width!==t||this.height!==e||this.depth!==n){this.width=t,this.height=e,this.depth=n;for(let s=0,r=this.textures.length;s<r;s++)this.textures[s].image.width=t,this.textures[s].image.height=e,this.textures[s].image.depth=n,this.textures[s].isData3DTexture!==!0&&(this.textures[s].isArrayTexture=this.textures[s].image.depth>1);this.dispose()}this.viewport.set(0,0,t,e),this.scissor.set(0,0,t,e)}clone(){return new this.constructor().copy(this)}copy(t){this.width=t.width,this.height=t.height,this.depth=t.depth,this.scissor.copy(t.scissor),this.scissorTest=t.scissorTest,this.viewport.copy(t.viewport),this.textures.length=0;for(let e=0,n=t.textures.length;e<n;e++){this.textures[e]=t.textures[e].clone(),this.textures[e].isRenderTargetTexture=!0,this.textures[e].renderTarget=this;let s=Object.assign({},t.textures[e].image);this.textures[e].source=new cr(s)}if(this.depthBuffer=t.depthBuffer,this.stencilBuffer=t.stencilBuffer,this.resolveColorBuffer=t.resolveColorBuffer,this.resolveDepthBuffer=t.resolveDepthBuffer,this.resolveStencilBuffer=t.resolveStencilBuffer,this.storeMultisampledColorBuffer=t.storeMultisampledColorBuffer,this.storeMultisampledDepthBuffer=t.storeMultisampledDepthBuffer,this.storeMultisampledStencilBuffer=t.storeMultisampledStencilBuffer,t.depthTexture!==null)if(t.depthTexture.renderTarget===t){let e=t.depthTexture.clone();e.renderTarget=null,this.depthTexture=e}else this.depthTexture=t.depthTexture;return this.samples=t.samples,this.multiview=t.multiview,this.useArrayDepthTexture=t.useArrayDepthTexture,this}dispose(){this.dispatchEvent({type:"dispose"})}},Ke=class extends ul{constructor(t=1,e=1,n={}){super(t,e,n),this.isWebGLRenderTarget=!0}},la=class extends gn{constructor(t=null,e=1,n=1,s=1){super(null),this.isDataArrayTexture=!0,this.image={data:t,width:e,height:n,depth:s},this.magFilter=mn,this.minFilter=mn,this.wrapR=xi,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1,this.layerUpdates=new Set}copy(t){return super.copy(t),this.wrapR=t.wrapR,this}addLayerUpdate(t){this.layerUpdates.add(t)}clearLayerUpdates(){this.layerUpdates.clear()}};var dl=class extends gn{constructor(t=null,e=1,n=1,s=1){super(null),this.isData3DTexture=!0,this.image={data:t,width:e,height:n,depth:s},this.magFilter=mn,this.minFilter=mn,this.wrapR=xi,this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}copy(t){return super.copy(t),this.wrapR=t.wrapR,this}};var Ce=class i{static{i.prototype.isMatrix4=!0}constructor(t,e,n,s,r,a,o,c,l,h,f,u,d,g,_,m){this.elements=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1],t!==void 0&&this.set(t,e,n,s,r,a,o,c,l,h,f,u,d,g,_,m)}set(t,e,n,s,r,a,o,c,l,h,f,u,d,g,_,m){let p=this.elements;return p[0]=t,p[4]=e,p[8]=n,p[12]=s,p[1]=r,p[5]=a,p[9]=o,p[13]=c,p[2]=l,p[6]=h,p[10]=f,p[14]=u,p[3]=d,p[7]=g,p[11]=_,p[15]=m,this}identity(){return this.set(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1),this}clone(){return new i().fromArray(this.elements)}copy(t){let e=this.elements,n=t.elements;return e[0]=n[0],e[1]=n[1],e[2]=n[2],e[3]=n[3],e[4]=n[4],e[5]=n[5],e[6]=n[6],e[7]=n[7],e[8]=n[8],e[9]=n[9],e[10]=n[10],e[11]=n[11],e[12]=n[12],e[13]=n[13],e[14]=n[14],e[15]=n[15],this}copyPosition(t){let e=this.elements,n=t.elements;return e[12]=n[12],e[13]=n[13],e[14]=n[14],this}setFromMatrix3(t){let e=t.elements;return this.set(e[0],e[3],e[6],0,e[1],e[4],e[7],0,e[2],e[5],e[8],0,0,0,0,1),this}extractBasis(t,e,n){return this.determinantAffine()===0?(t.set(1,0,0),e.set(0,1,0),n.set(0,0,1),this):(t.setFromMatrixColumn(this,0),e.setFromMatrixColumn(this,1),n.setFromMatrixColumn(this,2),this)}makeBasis(t,e,n){return this.set(t.x,e.x,n.x,0,t.y,e.y,n.y,0,t.z,e.z,n.z,0,0,0,0,1),this}extractRotation(t){if(t.determinantAffine()===0)return this.identity();let e=this.elements,n=t.elements,s=1/ks.setFromMatrixColumn(t,0).length(),r=1/ks.setFromMatrixColumn(t,1).length(),a=1/ks.setFromMatrixColumn(t,2).length();return e[0]=n[0]*s,e[1]=n[1]*s,e[2]=n[2]*s,e[3]=0,e[4]=n[4]*r,e[5]=n[5]*r,e[6]=n[6]*r,e[7]=0,e[8]=n[8]*a,e[9]=n[9]*a,e[10]=n[10]*a,e[11]=0,e[12]=0,e[13]=0,e[14]=0,e[15]=1,this}makeRotationFromEuler(t){let e=this.elements,n=t.x,s=t.y,r=t.z,a=Math.cos(n),o=Math.sin(n),c=Math.cos(s),l=Math.sin(s),h=Math.cos(r),f=Math.sin(r);if(t.order==="XYZ"){let u=a*h,d=a*f,g=o*h,_=o*f;e[0]=c*h,e[4]=-c*f,e[8]=l,e[1]=d+g*l,e[5]=u-_*l,e[9]=-o*c,e[2]=_-u*l,e[6]=g+d*l,e[10]=a*c}else if(t.order==="YXZ"){let u=c*h,d=c*f,g=l*h,_=l*f;e[0]=u+_*o,e[4]=g*o-d,e[8]=a*l,e[1]=a*f,e[5]=a*h,e[9]=-o,e[2]=d*o-g,e[6]=_+u*o,e[10]=a*c}else if(t.order==="ZXY"){let u=c*h,d=c*f,g=l*h,_=l*f;e[0]=u-_*o,e[4]=-a*f,e[8]=g+d*o,e[1]=d+g*o,e[5]=a*h,e[9]=_-u*o,e[2]=-a*l,e[6]=o,e[10]=a*c}else if(t.order==="ZYX"){let u=a*h,d=a*f,g=o*h,_=o*f;e[0]=c*h,e[4]=g*l-d,e[8]=u*l+_,e[1]=c*f,e[5]=_*l+u,e[9]=d*l-g,e[2]=-l,e[6]=o*c,e[10]=a*c}else if(t.order==="YZX"){let u=a*c,d=a*l,g=o*c,_=o*l;e[0]=c*h,e[4]=_-u*f,e[8]=g*f+d,e[1]=f,e[5]=a*h,e[9]=-o*h,e[2]=-l*h,e[6]=d*f+g,e[10]=u-_*f}else if(t.order==="XZY"){let u=a*c,d=a*l,g=o*c,_=o*l;e[0]=c*h,e[4]=-f,e[8]=l*h,e[1]=u*f+_,e[5]=a*h,e[9]=d*f-g,e[2]=g*f-d,e[6]=o*h,e[10]=_*f+u}return e[3]=0,e[7]=0,e[11]=0,e[12]=0,e[13]=0,e[14]=0,e[15]=1,this}makeRotationFromQuaternion(t){return this.compose(dp,t,fp)}lookAt(t,e,n){let s=this.elements;return Fn.subVectors(t,e),Fn.lengthSq()===0&&(Fn.z=1),Fn.normalize(),Ki.crossVectors(n,Fn),Ki.lengthSq()===0&&(Math.abs(n.z)===1?Fn.x+=1e-4:Fn.z+=1e-4,Fn.normalize(),Ki.crossVectors(n,Fn)),Ki.normalize(),Mo.crossVectors(Fn,Ki),s[0]=Ki.x,s[4]=Mo.x,s[8]=Fn.x,s[1]=Ki.y,s[5]=Mo.y,s[9]=Fn.y,s[2]=Ki.z,s[6]=Mo.z,s[10]=Fn.z,this}multiply(t){return this.multiplyMatrices(this,t)}premultiply(t){return this.multiplyMatrices(t,this)}multiplyMatrices(t,e){let n=t.elements,s=e.elements,r=this.elements,a=n[0],o=n[4],c=n[8],l=n[12],h=n[1],f=n[5],u=n[9],d=n[13],g=n[2],_=n[6],m=n[10],p=n[14],S=n[3],w=n[7],y=n[11],E=n[15],M=s[0],I=s[4],v=s[8],C=s[12],L=s[1],N=s[5],P=s[9],B=s[13],F=s[2],W=s[6],rt=s[10],nt=s[14],dt=s[3],Q=s[7],ct=s[11],O=s[15];return r[0]=a*M+o*L+c*F+l*dt,r[4]=a*I+o*N+c*W+l*Q,r[8]=a*v+o*P+c*rt+l*ct,r[12]=a*C+o*B+c*nt+l*O,r[1]=h*M+f*L+u*F+d*dt,r[5]=h*I+f*N+u*W+d*Q,r[9]=h*v+f*P+u*rt+d*ct,r[13]=h*C+f*B+u*nt+d*O,r[2]=g*M+_*L+m*F+p*dt,r[6]=g*I+_*N+m*W+p*Q,r[10]=g*v+_*P+m*rt+p*ct,r[14]=g*C+_*B+m*nt+p*O,r[3]=S*M+w*L+y*F+E*dt,r[7]=S*I+w*N+y*W+E*Q,r[11]=S*v+w*P+y*rt+E*ct,r[15]=S*C+w*B+y*nt+E*O,this}multiplyScalar(t){let e=this.elements;return e[0]*=t,e[4]*=t,e[8]*=t,e[12]*=t,e[1]*=t,e[5]*=t,e[9]*=t,e[13]*=t,e[2]*=t,e[6]*=t,e[10]*=t,e[14]*=t,e[3]*=t,e[7]*=t,e[11]*=t,e[15]*=t,this}determinant(){let t=this.elements,e=t[0],n=t[4],s=t[8],r=t[12],a=t[1],o=t[5],c=t[9],l=t[13],h=t[2],f=t[6],u=t[10],d=t[14],g=t[3],_=t[7],m=t[11],p=t[15],S=c*d-l*u,w=o*d-l*f,y=o*u-c*f,E=a*d-l*h,M=a*u-c*h,I=a*f-o*h;return e*(_*S-m*w+p*y)-n*(g*S-m*E+p*M)+s*(g*w-_*E+p*I)-r*(g*y-_*M+m*I)}determinantAffine(){let t=this.elements,e=t[0],n=t[4],s=t[8],r=t[1],a=t[5],o=t[9],c=t[2],l=t[6],h=t[10];return e*(a*h-o*l)-n*(r*h-o*c)+s*(r*l-a*c)}transpose(){let t=this.elements,e;return e=t[1],t[1]=t[4],t[4]=e,e=t[2],t[2]=t[8],t[8]=e,e=t[6],t[6]=t[9],t[9]=e,e=t[3],t[3]=t[12],t[12]=e,e=t[7],t[7]=t[13],t[13]=e,e=t[11],t[11]=t[14],t[14]=e,this}setPosition(t,e,n){let s=this.elements;return t.isVector3?(s[12]=t.x,s[13]=t.y,s[14]=t.z):(s[12]=t,s[13]=e,s[14]=n),this}invert(){let t=this.elements,e=t[0],n=t[1],s=t[2],r=t[3],a=t[4],o=t[5],c=t[6],l=t[7],h=t[8],f=t[9],u=t[10],d=t[11],g=t[12],_=t[13],m=t[14],p=t[15],S=e*o-n*a,w=e*c-s*a,y=e*l-r*a,E=n*c-s*o,M=n*l-r*o,I=s*l-r*c,v=h*_-f*g,C=h*m-u*g,L=h*p-d*g,N=f*m-u*_,P=f*p-d*_,B=u*p-d*m,F=S*B-w*P+y*N+E*L-M*C+I*v;if(F===0)return this.set(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);let W=1/F;return t[0]=(o*B-c*P+l*N)*W,t[1]=(s*P-n*B-r*N)*W,t[2]=(_*I-m*M+p*E)*W,t[3]=(u*M-f*I-d*E)*W,t[4]=(c*L-a*B-l*C)*W,t[5]=(e*B-s*L+r*C)*W,t[6]=(m*y-g*I-p*w)*W,t[7]=(h*I-u*y+d*w)*W,t[8]=(a*P-o*L+l*v)*W,t[9]=(n*L-e*P-r*v)*W,t[10]=(g*M-_*y+p*S)*W,t[11]=(f*y-h*M-d*S)*W,t[12]=(o*C-a*N-c*v)*W,t[13]=(e*N-n*C+s*v)*W,t[14]=(_*w-g*E-m*S)*W,t[15]=(h*E-f*w+u*S)*W,this}scale(t){let e=this.elements,n=t.x,s=t.y,r=t.z;return e[0]*=n,e[4]*=s,e[8]*=r,e[1]*=n,e[5]*=s,e[9]*=r,e[2]*=n,e[6]*=s,e[10]*=r,e[3]*=n,e[7]*=s,e[11]*=r,this}getMaxScaleOnAxis(){let t=this.elements,e=t[0]*t[0]+t[1]*t[1]+t[2]*t[2],n=t[4]*t[4]+t[5]*t[5]+t[6]*t[6],s=t[8]*t[8]+t[9]*t[9]+t[10]*t[10];return Math.sqrt(Math.max(e,n,s))}makeTranslation(t,e,n){return t.isVector3?this.set(1,0,0,t.x,0,1,0,t.y,0,0,1,t.z,0,0,0,1):this.set(1,0,0,t,0,1,0,e,0,0,1,n,0,0,0,1),this}makeRotationX(t){let e=Math.cos(t),n=Math.sin(t);return this.set(1,0,0,0,0,e,-n,0,0,n,e,0,0,0,0,1),this}makeRotationY(t){let e=Math.cos(t),n=Math.sin(t);return this.set(e,0,n,0,0,1,0,0,-n,0,e,0,0,0,0,1),this}makeRotationZ(t){let e=Math.cos(t),n=Math.sin(t);return this.set(e,-n,0,0,n,e,0,0,0,0,1,0,0,0,0,1),this}makeRotationAxis(t,e){let n=Math.cos(e),s=Math.sin(e),r=1-n,a=t.x,o=t.y,c=t.z,l=r*a,h=r*o;return this.set(l*a+n,l*o-s*c,l*c+s*o,0,l*o+s*c,h*o+n,h*c-s*a,0,l*c-s*o,h*c+s*a,r*c*c+n,0,0,0,0,1),this}makeScale(t,e,n){return this.set(t,0,0,0,0,e,0,0,0,0,n,0,0,0,0,1),this}makeShear(t,e,n,s,r,a){return this.set(1,n,r,0,t,1,a,0,e,s,1,0,0,0,0,1),this}compose(t,e,n){let s=this.elements,r=e._x,a=e._y,o=e._z,c=e._w,l=r+r,h=a+a,f=o+o,u=r*l,d=r*h,g=r*f,_=a*h,m=a*f,p=o*f,S=c*l,w=c*h,y=c*f,E=n.x,M=n.y,I=n.z;return s[0]=(1-(_+p))*E,s[1]=(d+y)*E,s[2]=(g-w)*E,s[3]=0,s[4]=(d-y)*M,s[5]=(1-(u+p))*M,s[6]=(m+S)*M,s[7]=0,s[8]=(g+w)*I,s[9]=(m-S)*I,s[10]=(1-(u+_))*I,s[11]=0,s[12]=t.x,s[13]=t.y,s[14]=t.z,s[15]=1,this}decompose(t,e,n){let s=this.elements;t.x=s[12],t.y=s[13],t.z=s[14];let r=this.determinantAffine();if(r===0)return n.set(1,1,1),e.identity(),this;let a=ks.set(s[0],s[1],s[2]).length(),o=ks.set(s[4],s[5],s[6]).length(),c=ks.set(s[8],s[9],s[10]).length();r<0&&(a=-a),ni.copy(this);let l=1/a,h=1/o,f=1/c;return ni.elements[0]*=l,ni.elements[1]*=l,ni.elements[2]*=l,ni.elements[4]*=h,ni.elements[5]*=h,ni.elements[6]*=h,ni.elements[8]*=f,ni.elements[9]*=f,ni.elements[10]*=f,e.setFromRotationMatrix(ni),n.x=a,n.y=o,n.z=c,this}makePerspective(t,e,n,s,r,a,o=ai,c=!1){let l=this.elements,h=2*r/(e-t),f=2*r/(n-s),u=(e+t)/(e-t),d=(n+s)/(n-s),g,_;if(c)g=r/(a-r),_=a*r/(a-r);else if(o===ai)g=-(a+r)/(a-r),_=-2*a*r/(a-r);else if(o===ar)g=-a/(a-r),_=-a*r/(a-r);else throw new Error("THREE.Matrix4.makePerspective(): Invalid coordinate system: "+o);return l[0]=h,l[4]=0,l[8]=u,l[12]=0,l[1]=0,l[5]=f,l[9]=d,l[13]=0,l[2]=0,l[6]=0,l[10]=g,l[14]=_,l[3]=0,l[7]=0,l[11]=-1,l[15]=0,this}makeOrthographic(t,e,n,s,r,a,o=ai,c=!1){let l=this.elements,h=2/(e-t),f=2/(n-s),u=-(e+t)/(e-t),d=-(n+s)/(n-s),g,_;if(c)g=1/(a-r),_=a/(a-r);else if(o===ai)g=-2/(a-r),_=-(a+r)/(a-r);else if(o===ar)g=-1/(a-r),_=-r/(a-r);else throw new Error("THREE.Matrix4.makeOrthographic(): Invalid coordinate system: "+o);return l[0]=h,l[4]=0,l[8]=0,l[12]=u,l[1]=0,l[5]=f,l[9]=0,l[13]=d,l[2]=0,l[6]=0,l[10]=g,l[14]=_,l[3]=0,l[7]=0,l[11]=0,l[15]=1,this}equals(t){let e=this.elements,n=t.elements;for(let s=0;s<16;s++)if(e[s]!==n[s])return!1;return!0}fromArray(t,e=0){for(let n=0;n<16;n++)this.elements[n]=t[n+e];return this}toArray(t=[],e=0){let n=this.elements;return t[e]=n[0],t[e+1]=n[1],t[e+2]=n[2],t[e+3]=n[3],t[e+4]=n[4],t[e+5]=n[5],t[e+6]=n[6],t[e+7]=n[7],t[e+8]=n[8],t[e+9]=n[9],t[e+10]=n[10],t[e+11]=n[11],t[e+12]=n[12],t[e+13]=n[13],t[e+14]=n[14],t[e+15]=n[15],t}},ks=new D,ni=new Ce,dp=new D(0,0,0),fp=new D(1,1,1),Ki=new D,Mo=new D,Fn=new D,du=new Ce,fu=new Mi,zi=class i{constructor(t=0,e=0,n=0,s=i.DEFAULT_ORDER){this.isEuler=!0,this._x=t,this._y=e,this._z=n,this._order=s}get x(){return this._x}set x(t){this._x=t,this._onChangeCallback()}get y(){return this._y}set y(t){this._y=t,this._onChangeCallback()}get z(){return this._z}set z(t){this._z=t,this._onChangeCallback()}get order(){return this._order}set order(t){this._order=t,this._onChangeCallback()}set(t,e,n,s=this._order){return this._x=t,this._y=e,this._z=n,this._order=s,this._onChangeCallback(),this}clone(){return new this.constructor(this._x,this._y,this._z,this._order)}copy(t){return this._x=t._x,this._y=t._y,this._z=t._z,this._order=t._order,this._onChangeCallback(),this}setFromRotationMatrix(t,e=this._order,n=!0){let s=t.elements,r=s[0],a=s[4],o=s[8],c=s[1],l=s[5],h=s[9],f=s[2],u=s[6],d=s[10];switch(e){case"XYZ":this._y=Math.asin(be(o,-1,1)),Math.abs(o)<.9999999?(this._x=Math.atan2(-h,d),this._z=Math.atan2(-a,r)):(this._x=Math.atan2(u,l),this._z=0);break;case"YXZ":this._x=Math.asin(-be(h,-1,1)),Math.abs(h)<.9999999?(this._y=Math.atan2(o,d),this._z=Math.atan2(c,l)):(this._y=Math.atan2(-f,r),this._z=0);break;case"ZXY":this._x=Math.asin(be(u,-1,1)),Math.abs(u)<.9999999?(this._y=Math.atan2(-f,d),this._z=Math.atan2(-a,l)):(this._y=0,this._z=Math.atan2(c,r));break;case"ZYX":this._y=Math.asin(-be(f,-1,1)),Math.abs(f)<.9999999?(this._x=Math.atan2(u,d),this._z=Math.atan2(c,r)):(this._x=0,this._z=Math.atan2(-a,l));break;case"YZX":this._z=Math.asin(be(c,-1,1)),Math.abs(c)<.9999999?(this._x=Math.atan2(-h,l),this._y=Math.atan2(-f,r)):(this._x=0,this._y=Math.atan2(o,d));break;case"XZY":this._z=Math.asin(-be(a,-1,1)),Math.abs(a)<.9999999?(this._x=Math.atan2(u,l),this._y=Math.atan2(o,r)):(this._x=Math.atan2(-h,d),this._y=0);break;default:ue("Euler: .setFromRotationMatrix() encountered an unknown order: "+e)}return this._order=e,n===!0&&this._onChangeCallback(),this}setFromQuaternion(t,e,n){return du.makeRotationFromQuaternion(t),this.setFromRotationMatrix(du,e,n)}setFromVector3(t,e=this._order){return this.set(t.x,t.y,t.z,e)}reorder(t){return fu.setFromEuler(this),this.setFromQuaternion(fu,t)}equals(t){return t._x===this._x&&t._y===this._y&&t._z===this._z&&t._order===this._order}fromArray(t){return this._x=t[0],this._y=t[1],this._z=t[2],t[3]!==void 0&&(this._order=t[3]),this._onChangeCallback(),this}toArray(t=[],e=0){return t[e]=this._x,t[e+1]=this._y,t[e+2]=this._z,t[e+3]=this._order,t}_onChange(t){return this._onChangeCallback=t,this}_onChangeCallback(){}*[Symbol.iterator](){yield this._x,yield this._y,yield this._z,yield this._order}};zi.DEFAULT_ORDER="XYZ";var hr=class{constructor(){this.mask=1}set(t){this.mask=(1<<t|0)>>>0}enable(t){this.mask|=1<<t|0}enableAll(){this.mask=-1}toggle(t){this.mask^=1<<t|0}disable(t){this.mask&=~(1<<t|0)}disableAll(){this.mask=0}test(t){return(this.mask&t.mask)!==0}isEnabled(t){return(this.mask&(1<<t|0))!==0}},pp=0,pu=new D,Hs=new Mi,Pi=new Ce,bo=new D,Xr=new D,mp=new D,gp=new Mi,mu=new D(1,0,0),gu=new D(0,1,0),xu=new D(0,0,1),_u={type:"added"},xp={type:"removed"},Vs={type:"childadded",child:null},u0={type:"childremoved",child:null},en=class i extends yi{constructor(){super(),this.isObject3D=!0,Object.defineProperty(this,"id",{value:pp++}),this.uuid=Oi(),this.name="",this.type="Object3D",this.parent=null,this.children=[],this.up=i.DEFAULT_UP.clone();let t=new D,e=new zi,n=new Mi,s=new D(1,1,1);function r(){n.setFromEuler(e,!1)}function a(){e.setFromQuaternion(n,void 0,!1)}e._onChange(r),n._onChange(a),Object.defineProperties(this,{position:{configurable:!0,enumerable:!0,value:t},rotation:{configurable:!0,enumerable:!0,value:e},quaternion:{configurable:!0,enumerable:!0,value:n},scale:{configurable:!0,enumerable:!0,value:s},modelViewMatrix:{value:new Ce},normalMatrix:{value:new me}}),this.matrix=new Ce,this.matrixWorld=new Ce,this.matrixAutoUpdate=i.DEFAULT_MATRIX_AUTO_UPDATE,this.matrixWorldAutoUpdate=i.DEFAULT_MATRIX_WORLD_AUTO_UPDATE,this.matrixWorldNeedsUpdate=!1,this.layers=new hr,this.visible=!0,this.castShadow=!1,this.receiveShadow=!1,this.frustumCulled=!0,this.renderOrder=0,this.animations=[],this.customDepthMaterial=void 0,this.customDistanceMaterial=void 0,this.static=!1,this.userData={},this.pivot=null}onBeforeShadow(){}onAfterShadow(){}onBeforeRender(){}onAfterRender(){}applyMatrix4(t){this.matrixAutoUpdate&&this.updateMatrix(),this.matrix.premultiply(t),this.matrix.decompose(this.position,this.quaternion,this.scale)}applyQuaternion(t){return this.quaternion.premultiply(t),this}setRotationFromAxisAngle(t,e){this.quaternion.setFromAxisAngle(t,e)}setRotationFromEuler(t){this.quaternion.setFromEuler(t,!0)}setRotationFromMatrix(t){this.quaternion.setFromRotationMatrix(t)}setRotationFromQuaternion(t){this.quaternion.copy(t)}rotateOnAxis(t,e){return Hs.setFromAxisAngle(t,e),this.quaternion.multiply(Hs),this}rotateOnWorldAxis(t,e){return Hs.setFromAxisAngle(t,e),this.quaternion.premultiply(Hs),this}rotateX(t){return this.rotateOnAxis(mu,t)}rotateY(t){return this.rotateOnAxis(gu,t)}rotateZ(t){return this.rotateOnAxis(xu,t)}translateOnAxis(t,e){return pu.copy(t).applyQuaternion(this.quaternion),this.position.add(pu.multiplyScalar(e)),this}translateX(t){return this.translateOnAxis(mu,t)}translateY(t){return this.translateOnAxis(gu,t)}translateZ(t){return this.translateOnAxis(xu,t)}localToWorld(t){return this.updateWorldMatrix(!0,!1),t.applyMatrix4(this.matrixWorld)}worldToLocal(t){return this.updateWorldMatrix(!0,!1),t.applyMatrix4(Pi.copy(this.matrixWorld).invert())}lookAt(t,e,n){t.isVector3?bo.copy(t):bo.set(t,e,n);let s=this.parent;this.updateWorldMatrix(!0,!1),Xr.setFromMatrixPosition(this.matrixWorld),this.isCamera||this.isLight?Pi.lookAt(Xr,bo,this.up):Pi.lookAt(bo,Xr,this.up),this.quaternion.setFromRotationMatrix(Pi),s&&(Pi.extractRotation(s.matrixWorld),Hs.setFromRotationMatrix(Pi),this.quaternion.premultiply(Hs.invert()))}add(t){if(arguments.length>1){for(let e=0;e<arguments.length;e++)this.add(arguments[e]);return this}return t===this?(he("Object3D.add: object can't be added as a child of itself.",t),this):(t&&t.isObject3D?(t.removeFromParent(),t.parent=this,this.children.push(t),t.dispatchEvent(_u),Vs.child=t,this.dispatchEvent(Vs),Vs.child=null):he("Object3D.add: object not an instance of THREE.Object3D.",t),this)}remove(t){if(arguments.length>1){for(let n=0;n<arguments.length;n++)this.remove(arguments[n]);return this}let e=this.children.indexOf(t);return e!==-1&&(t.parent=null,this.children.splice(e,1),t.dispatchEvent(xp),u0.child=t,this.dispatchEvent(u0),u0.child=null),this}removeFromParent(){let t=this.parent;return t!==null&&t.remove(this),this}clear(){return this.remove(...this.children)}attach(t){return this.updateWorldMatrix(!0,!1),Pi.copy(this.matrixWorld).invert(),t.parent!==null&&(t.parent.updateWorldMatrix(!0,!1),Pi.multiply(t.parent.matrixWorld)),t.applyMatrix4(Pi),t.removeFromParent(),t.parent=this,this.children.push(t),t.updateWorldMatrix(!1,!0),t.dispatchEvent(_u),Vs.child=t,this.dispatchEvent(Vs),Vs.child=null,this}getObjectById(t){return this.getObjectByProperty("id",t)}getObjectByName(t){return this.getObjectByProperty("name",t)}getObjectByProperty(t,e){if(this[t]===e)return this;for(let n=0,s=this.children.length;n<s;n++){let a=this.children[n].getObjectByProperty(t,e);if(a!==void 0)return a}}getObjectsByProperty(t,e,n=[]){this[t]===e&&n.push(this);let s=this.children;for(let r=0,a=s.length;r<a;r++)s[r].getObjectsByProperty(t,e,n);return n}getWorldPosition(t){return this.updateWorldMatrix(!0,!1),t.setFromMatrixPosition(this.matrixWorld)}getWorldQuaternion(t){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose(Xr,t,mp),t}getWorldScale(t){return this.updateWorldMatrix(!0,!1),this.matrixWorld.decompose(Xr,gp,t),t}getWorldDirection(t){this.updateWorldMatrix(!0,!1);let e=this.matrixWorld.elements;return t.set(e[8],e[9],e[10]).normalize()}raycast(){}intersectsFrustum(){}traverse(t){t(this);let e=this.children;for(let n=0,s=e.length;n<s;n++)e[n].traverse(t)}traverseVisible(t){if(this.visible===!1)return;t(this);let e=this.children;for(let n=0,s=e.length;n<s;n++)e[n].traverseVisible(t)}traverseAncestors(t){let e=this.parent;e!==null&&(t(e),e.traverseAncestors(t))}updateMatrix(){this.matrix.compose(this.position,this.quaternion,this.scale);let t=this.pivot;if(t!==null){let e=t.x,n=t.y,s=t.z,r=this.matrix.elements;r[12]+=e-r[0]*e-r[4]*n-r[8]*s,r[13]+=n-r[1]*e-r[5]*n-r[9]*s,r[14]+=s-r[2]*e-r[6]*n-r[10]*s}this.matrixWorldNeedsUpdate=!0}updateMatrixWorld(t){this.matrixAutoUpdate&&this.updateMatrix(),(this.matrixWorldNeedsUpdate||t)&&(this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),this.matrixWorldNeedsUpdate=!1,t=!0);let e=this.children;for(let n=0,s=e.length;n<s;n++)e[n].updateMatrixWorld(t)}updateWorldMatrix(t,e,n=!1){let s=this.parent;if(t===!0&&s!==null&&s.updateWorldMatrix(!0,!1),this.matrixAutoUpdate&&this.updateMatrix(),(this.matrixWorldNeedsUpdate||n)&&(this.matrixWorldAutoUpdate===!0&&(this.parent===null?this.matrixWorld.copy(this.matrix):this.matrixWorld.multiplyMatrices(this.parent.matrixWorld,this.matrix)),this.matrixWorldNeedsUpdate=!1,n=!0),e===!0){let r=this.children;for(let a=0,o=r.length;a<o;a++)r[a].updateWorldMatrix(!1,!0,n)}}toJSON(t){let e=t===void 0||typeof t=="string",n={};e&&(t={geometries:{},materials:{},textures:{},images:{},shapes:{},skeletons:{},animations:{},nodes:{}},n.metadata={version:4.7,type:"Object",generator:"Object3D.toJSON"});let s={};s.uuid=this.uuid,s.type=this.type,s.name=this.name,s.castShadow=this.castShadow,s.receiveShadow=this.receiveShadow,s.visible=this.visible,s.frustumCulled=this.frustumCulled,s.renderOrder=this.renderOrder,s.static=this.static,s.matrixAutoUpdate=this.matrixAutoUpdate,Object.keys(this.userData).length>0&&(s.userData=this.userData),s.layers=this.layers.mask,s.matrix=this.matrix.toArray(),s.up=this.up.toArray(),this.pivot!==null&&(s.pivot=this.pivot.toArray()),this.morphTargetDictionary!==void 0&&(s.morphTargetDictionary=Object.assign({},this.morphTargetDictionary)),this.morphTargetInfluences!==void 0&&(s.morphTargetInfluences=this.morphTargetInfluences.slice()),this.isInstancedMesh&&(s.type="InstancedMesh",s.count=this.count,s.instanceMatrix=this.instanceMatrix.toJSON(),this.instanceColor!==null&&(s.instanceColor=this.instanceColor.toJSON())),this.isBatchedMesh&&(s.type="BatchedMesh",s.perObjectFrustumCulled=this.perObjectFrustumCulled,s.sortObjects=this.sortObjects,s.drawRanges=this._drawRanges,s.reservedRanges=this._reservedRanges,s.geometryInfo=this._geometryInfo.map(o=>({...o,boundingBox:o.boundingBox?o.boundingBox.toJSON():void 0,boundingSphere:o.boundingSphere?o.boundingSphere.toJSON():void 0})),s.instanceInfo=this._instanceInfo.map(o=>({...o})),s.availableInstanceIds=this._availableInstanceIds.slice(),s.availableGeometryIds=this._availableGeometryIds.slice(),s.nextIndexStart=this._nextIndexStart,s.nextVertexStart=this._nextVertexStart,s.geometryCount=this._geometryCount,s.maxInstanceCount=this._maxInstanceCount,s.maxVertexCount=this._maxVertexCount,s.maxIndexCount=this._maxIndexCount,s.geometryInitialized=this._geometryInitialized,s.matricesTexture=this._matricesTexture.toJSON(t),s.indirectTexture=this._indirectTexture.toJSON(t),this._colorsTexture!==null&&(s.colorsTexture=this._colorsTexture.toJSON(t)),this.boundingSphere!==null&&(s.boundingSphere=this.boundingSphere.toJSON()),this.boundingBox!==null&&(s.boundingBox=this.boundingBox.toJSON()));function r(o,c){return o[c.uuid]===void 0&&(o[c.uuid]=c.toJSON(t)),c.uuid}if(this.isScene)this.background&&(this.background.isColor?s.background=this.background.toJSON():this.background.isTexture&&(s.background=this.background.toJSON(t).uuid)),this.environment&&this.environment.isTexture&&this.environment.isRenderTargetTexture!==!0&&(s.environment=this.environment.toJSON(t).uuid);else if(this.isMesh||this.isLine||this.isPoints){s.geometry=r(t.geometries,this.geometry);let o=this.geometry.parameters;if(o!==void 0&&o.shapes!==void 0){let c=o.shapes;if(Array.isArray(c))for(let l=0,h=c.length;l<h;l++){let f=c[l];r(t.shapes,f)}else r(t.shapes,c)}}if(this.isSkinnedMesh&&(s.bindMode=this.bindMode,s.bindMatrix=this.bindMatrix.toArray(),this.skeleton!==void 0&&(r(t.skeletons,this.skeleton),s.skeleton=this.skeleton.uuid)),this.material!==void 0)if(Array.isArray(this.material)){let o=[];for(let c=0,l=this.material.length;c<l;c++)o.push(r(t.materials,this.material[c]));s.material=o}else s.material=r(t.materials,this.material);if(this.children.length>0){s.children=[];for(let o=0;o<this.children.length;o++)s.children.push(this.children[o].toJSON(t).object)}if(this.animations.length>0){s.animations=[];for(let o=0;o<this.animations.length;o++){let c=this.animations[o];s.animations.push(r(t.animations,c))}}if(e){let o=a(t.geometries),c=a(t.materials),l=a(t.textures),h=a(t.images),f=a(t.shapes),u=a(t.skeletons),d=a(t.animations),g=a(t.nodes);o.length>0&&(n.geometries=o),c.length>0&&(n.materials=c),l.length>0&&(n.textures=l),h.length>0&&(n.images=h),f.length>0&&(n.shapes=f),u.length>0&&(n.skeletons=u),d.length>0&&(n.animations=d),g.length>0&&(n.nodes=g)}return n.object=s,n;function a(o){let c=[];for(let l in o){let h=o[l];delete h.metadata,c.push(h)}return c}}clone(t){return new this.constructor().copy(this,t)}copy(t,e=!0){if(this.name=t.name,this.up.copy(t.up),this.position.copy(t.position),this.rotation.order=t.rotation.order,this.quaternion.copy(t.quaternion),this.scale.copy(t.scale),this.pivot=t.pivot!==null?t.pivot.clone():null,this.matrix.copy(t.matrix),this.matrixWorld.copy(t.matrixWorld),this.matrixAutoUpdate=t.matrixAutoUpdate,this.matrixWorldAutoUpdate=t.matrixWorldAutoUpdate,this.matrixWorldNeedsUpdate=t.matrixWorldNeedsUpdate,this.layers.mask=t.layers.mask,this.visible=t.visible,this.castShadow=t.castShadow,this.receiveShadow=t.receiveShadow,this.frustumCulled=t.frustumCulled,this.renderOrder=t.renderOrder,this.static=t.static,this.animations=t.animations.slice(),this.userData=JSON.parse(JSON.stringify(t.userData)),e===!0)for(let n=0;n<t.children.length;n++){let s=t.children[n];this.add(s.clone())}return this}dispose(){this.dispatchEvent({type:"dispose"})}};en.DEFAULT_UP=new D(0,1,0);en.DEFAULT_MATRIX_AUTO_UPDATE=!0;en.DEFAULT_MATRIX_WORLD_AUTO_UPDATE=!0;var Je=class extends en{constructor(){super(),this.isGroup=!0,this.type="Group"}},_p={type:"move"},ur=class{constructor(){this._targetRay=null,this._grip=null,this._hand=null}getHandSpace(){return this._hand===null&&(this._hand=new Je,this._hand.matrixAutoUpdate=!1,this._hand.visible=!1,this._hand.joints={},this._hand.inputState={pinching:!1}),this._hand}getTargetRaySpace(){return this._targetRay===null&&(this._targetRay=new Je,this._targetRay.matrixAutoUpdate=!1,this._targetRay.visible=!1,this._targetRay.hasLinearVelocity=!1,this._targetRay.linearVelocity=new D,this._targetRay.hasAngularVelocity=!1,this._targetRay.angularVelocity=new D),this._targetRay}getGripSpace(){return this._grip===null&&(this._grip=new Je,this._grip.matrixAutoUpdate=!1,this._grip.visible=!1,this._grip.hasLinearVelocity=!1,this._grip.linearVelocity=new D,this._grip.hasAngularVelocity=!1,this._grip.angularVelocity=new D,this._grip.eventsEnabled=!1),this._grip}dispatchEvent(t){return this._targetRay!==null&&this._targetRay.dispatchEvent(t),this._grip!==null&&this._grip.dispatchEvent(t),this._hand!==null&&this._hand.dispatchEvent(t),this}connect(t){if(t&&t.hand){let e=this._hand;if(e)for(let n of t.hand.values())this._getHandJoint(e,n)}return this.dispatchEvent({type:"connected",data:t}),this}disconnect(t){return this.dispatchEvent({type:"disconnected",data:t}),this._targetRay!==null&&(this._targetRay.visible=!1),this._grip!==null&&(this._grip.visible=!1),this._hand!==null&&(this._hand.visible=!1),this}update(t,e,n){let s=null,r=null,a=null,o=this._targetRay,c=this._grip,l=this._hand;if(t&&e.session.visibilityState!=="visible-blurred"){if(l&&t.hand){a=!0;for(let _ of t.hand.values()){let m=e.getJointPose(_,n),p=this._getHandJoint(l,_);m!==null&&(p.matrix.fromArray(m.transform.matrix),p.matrix.decompose(p.position,p.rotation,p.scale),p.matrixWorldNeedsUpdate=!0,p.jointRadius=m.radius),p.visible=m!==null}let h=l.joints["index-finger-tip"],f=l.joints["thumb-tip"],u=h.position.distanceTo(f.position),d=.02,g=.005;l.inputState.pinching&&u>d+g?(l.inputState.pinching=!1,this.dispatchEvent({type:"pinchend",handedness:t.handedness,target:this})):!l.inputState.pinching&&u<=d-g&&(l.inputState.pinching=!0,this.dispatchEvent({type:"pinchstart",handedness:t.handedness,target:this}))}else c!==null&&t.gripSpace&&(r=e.getPose(t.gripSpace,n),r!==null&&(c.matrix.fromArray(r.transform.matrix),c.matrix.decompose(c.position,c.rotation,c.scale),c.matrixWorldNeedsUpdate=!0,r.linearVelocity?(c.hasLinearVelocity=!0,c.linearVelocity.copy(r.linearVelocity)):c.hasLinearVelocity=!1,r.angularVelocity?(c.hasAngularVelocity=!0,c.angularVelocity.copy(r.angularVelocity)):c.hasAngularVelocity=!1,c.eventsEnabled&&c.dispatchEvent({type:"gripUpdated",data:t,target:this})));o!==null&&(s=e.getPose(t.targetRaySpace,n),s===null&&r!==null&&(s=r),s!==null&&(o.matrix.fromArray(s.transform.matrix),o.matrix.decompose(o.position,o.rotation,o.scale),o.matrixWorldNeedsUpdate=!0,s.linearVelocity?(o.hasLinearVelocity=!0,o.linearVelocity.copy(s.linearVelocity)):o.hasLinearVelocity=!1,s.angularVelocity?(o.hasAngularVelocity=!0,o.angularVelocity.copy(s.angularVelocity)):o.hasAngularVelocity=!1,this.dispatchEvent(_p)))}return o!==null&&(o.visible=s!==null),c!==null&&(c.visible=r!==null),l!==null&&(l.visible=a!==null),this}_getHandJoint(t,e){if(t.joints[e.jointName]===void 0){let n=new Je;n.matrixAutoUpdate=!1,n.visible=!1,t.joints[e.jointName]=n,t.add(n)}return t.joints[e.jointName]}},Id={aliceblue:15792383,antiquewhite:16444375,aqua:65535,aquamarine:8388564,azure:15794175,beige:16119260,bisque:16770244,black:0,blanchedalmond:16772045,blue:255,blueviolet:9055202,brown:10824234,burlywood:14596231,cadetblue:6266528,chartreuse:8388352,chocolate:13789470,coral:16744272,cornflowerblue:6591981,cornsilk:16775388,crimson:14423100,cyan:65535,darkblue:139,darkcyan:35723,darkgoldenrod:12092939,darkgray:11119017,darkgreen:25600,darkgrey:11119017,darkkhaki:12433259,darkmagenta:9109643,darkolivegreen:5597999,darkorange:16747520,darkorchid:10040012,darkred:9109504,darksalmon:15308410,darkseagreen:9419919,darkslateblue:4734347,darkslategray:3100495,darkslategrey:3100495,darkturquoise:52945,darkviolet:9699539,deeppink:16716947,deepskyblue:49151,dimgray:6908265,dimgrey:6908265,dodgerblue:2003199,firebrick:11674146,floralwhite:16775920,forestgreen:2263842,fuchsia:16711935,gainsboro:14474460,ghostwhite:16316671,gold:16766720,goldenrod:14329120,gray:8421504,green:32768,greenyellow:11403055,grey:8421504,honeydew:15794160,hotpink:16738740,indianred:13458524,indigo:4915330,ivory:16777200,khaki:15787660,lavender:15132410,lavenderblush:16773365,lawngreen:8190976,lemonchiffon:16775885,lightblue:11393254,lightcoral:15761536,lightcyan:14745599,lightgoldenrodyellow:16448210,lightgray:13882323,lightgreen:9498256,lightgrey:13882323,lightpink:16758465,lightsalmon:16752762,lightseagreen:2142890,lightskyblue:8900346,lightslategray:7833753,lightslategrey:7833753,lightsteelblue:11584734,lightyellow:16777184,lime:65280,limegreen:3329330,linen:16445670,magenta:16711935,maroon:8388608,mediumaquamarine:6737322,mediumblue:205,mediumorchid:12211667,mediumpurple:9662683,mediumseagreen:3978097,mediumslateblue:8087790,mediumspringgreen:64154,mediumturquoise:4772300,mediumvioletred:13047173,midnightblue:1644912,mintcream:16121850,mistyrose:16770273,moccasin:16770229,navajowhite:16768685,navy:128,oldlace:16643558,olive:8421376,olivedrab:7048739,orange:16753920,orangered:16729344,orchid:14315734,palegoldenrod:15657130,palegreen:10025880,paleturquoise:11529966,palevioletred:14381203,papayawhip:16773077,peachpuff:16767673,peru:13468991,pink:16761035,plum:14524637,powderblue:11591910,purple:8388736,rebeccapurple:6697881,red:16711680,rosybrown:12357519,royalblue:4286945,saddlebrown:9127187,salmon:16416882,sandybrown:16032864,seagreen:3050327,seashell:16774638,sienna:10506797,silver:12632256,skyblue:8900331,slateblue:6970061,slategray:7372944,slategrey:7372944,snow:16775930,springgreen:65407,steelblue:4620980,tan:13808780,teal:32896,thistle:14204888,tomato:16737095,turquoise:4251856,violet:15631086,wheat:16113331,white:16777215,whitesmoke:16119285,yellow:16776960,yellowgreen:10145074},ji={h:0,s:0,l:0},So={h:0,s:0,l:0};function d0(i,t,e){return e<0&&(e+=1),e>1&&(e-=1),e<1/6?i+(t-i)*6*e:e<1/2?t:e<2/3?i+(t-i)*6*(2/3-e):i}var se=class{constructor(t,e,n){return this.isColor=!0,this.r=1,this.g=1,this.b=1,this.set(t,e,n)}set(t,e,n){if(e===void 0&&n===void 0){let s=t;s&&s.isColor?this.copy(s):typeof s=="number"?this.setHex(s):typeof s=="string"&&this.setStyle(s)}else this.setRGB(t,e,n);return this}setScalar(t){return this.r=t,this.g=t,this.b=t,this}setHex(t,e=Ye){return t=Math.floor(t),this.r=(t>>16&255)/255,this.g=(t>>8&255)/255,this.b=(t&255)/255,Se.colorSpaceToWorking(this,e),this}setRGB(t,e,n,s=Se.workingColorSpace){return this.r=t,this.g=e,this.b=n,Se.colorSpaceToWorking(this,s),this}setHSL(t,e,n,s=Se.workingColorSpace){if(t=lp(t,1),e=be(e,0,1),n=be(n,0,1),e===0)this.r=this.g=this.b=n;else{let r=n<=.5?n*(1+e):n+e-n*e,a=2*n-r;this.r=d0(a,r,t+1/3),this.g=d0(a,r,t),this.b=d0(a,r,t-1/3)}return Se.colorSpaceToWorking(this,s),this}setStyle(t,e=Ye){function n(r){r!==void 0&&parseFloat(r)<1&&ue("Color: Alpha component of "+t+" will be ignored.")}let s;if(s=/^(\w+)\(([^\)]*)\)/.exec(t)){let r,a=s[1],o=s[2];switch(a){case"rgb":case"rgba":if(r=/^\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return n(r[4]),this.setRGB(Math.min(255,parseInt(r[1],10))/255,Math.min(255,parseInt(r[2],10))/255,Math.min(255,parseInt(r[3],10))/255,e);if(r=/^\s*(\d+)\%\s*,\s*(\d+)\%\s*,\s*(\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return n(r[4]),this.setRGB(Math.min(100,parseInt(r[1],10))/100,Math.min(100,parseInt(r[2],10))/100,Math.min(100,parseInt(r[3],10))/100,e);break;case"hsl":case"hsla":if(r=/^\s*(\d*\.?\d+)\s*,\s*(\d*\.?\d+)\%\s*,\s*(\d*\.?\d+)\%\s*(?:,\s*(\d*\.?\d+)\s*)?$/.exec(o))return n(r[4]),this.setHSL(parseFloat(r[1])/360,parseFloat(r[2])/100,parseFloat(r[3])/100,e);break;default:ue("Color: Unknown color model "+t)}}else if(s=/^\#([A-Fa-f\d]+)$/.exec(t)){let r=s[1],a=r.length;if(a===3)return this.setRGB(parseInt(r.charAt(0),16)/15,parseInt(r.charAt(1),16)/15,parseInt(r.charAt(2),16)/15,e);if(a===6)return this.setHex(parseInt(r,16),e);ue("Color: Invalid hex color "+t)}else if(t&&t.length>0)return this.setColorName(t,e);return this}setColorName(t,e=Ye){let n=Id[t.toLowerCase()];return n!==void 0?this.setHex(n,e):ue("Color: Unknown color "+t),this}clone(){return new this.constructor(this.r,this.g,this.b)}copy(t){return this.r=t.r,this.g=t.g,this.b=t.b,this}copySRGBToLinear(t){return this.r=Bi(t.r),this.g=Bi(t.g),this.b=Bi(t.b),this}copyLinearToSRGB(t){return this.r=sr(t.r),this.g=sr(t.g),this.b=sr(t.b),this}convertSRGBToLinear(){return this.copySRGBToLinear(this),this}convertLinearToSRGB(){return this.copyLinearToSRGB(this),this}getHex(t=Ye){return Se.workingToColorSpace(Rn.copy(this),t),Math.round(be(Rn.r*255,0,255))*65536+Math.round(be(Rn.g*255,0,255))*256+Math.round(be(Rn.b*255,0,255))}getHexString(t=Ye){return("000000"+this.getHex(t).toString(16)).slice(-6)}getHSL(t,e=Se.workingColorSpace){Se.workingToColorSpace(Rn.copy(this),e);let n=Rn.r,s=Rn.g,r=Rn.b,a=Math.max(n,s,r),o=Math.min(n,s,r),c,l,h=(o+a)/2;if(o===a)c=0,l=0;else{let f=a-o;switch(l=h<=.5?f/(a+o):f/(2-a-o),a){case n:c=(s-r)/f+(s<r?6:0);break;case s:c=(r-n)/f+2;break;case r:c=(n-s)/f+4;break}c/=6}return t.h=c,t.s=l,t.l=h,t}getRGB(t,e=Se.workingColorSpace){return Se.workingToColorSpace(Rn.copy(this),e),t.r=Rn.r,t.g=Rn.g,t.b=Rn.b,t}getStyle(t=Ye){Se.workingToColorSpace(Rn.copy(this),t);let e=Rn.r,n=Rn.g,s=Rn.b;return t!==Ye?`color(${t} ${e.toFixed(3)} ${n.toFixed(3)} ${s.toFixed(3)})`:`rgb(${Math.round(e*255)},${Math.round(n*255)},${Math.round(s*255)})`}offsetHSL(t,e,n){return this.getHSL(ji),this.setHSL(ji.h+t,ji.s+e,ji.l+n)}add(t){return this.r+=t.r,this.g+=t.g,this.b+=t.b,this}addColors(t,e){return this.r=t.r+e.r,this.g=t.g+e.g,this.b=t.b+e.b,this}addScalar(t){return this.r+=t,this.g+=t,this.b+=t,this}sub(t){return this.r=Math.max(0,this.r-t.r),this.g=Math.max(0,this.g-t.g),this.b=Math.max(0,this.b-t.b),this}multiply(t){return this.r*=t.r,this.g*=t.g,this.b*=t.b,this}multiplyScalar(t){return this.r*=t,this.g*=t,this.b*=t,this}lerp(t,e){return this.r+=(t.r-this.r)*e,this.g+=(t.g-this.g)*e,this.b+=(t.b-this.b)*e,this}lerpColors(t,e,n){return this.r=t.r+(e.r-t.r)*n,this.g=t.g+(e.g-t.g)*n,this.b=t.b+(e.b-t.b)*n,this}lerpHSL(t,e){this.getHSL(ji),t.getHSL(So);let n=a0(ji.h,So.h,e),s=a0(ji.s,So.s,e),r=a0(ji.l,So.l,e);return this.setHSL(n,s,r),this}setFromVector3(t){return this.r=t.x,this.g=t.y,this.b=t.z,this}applyMatrix3(t){let e=this.r,n=this.g,s=this.b,r=t.elements;return this.r=r[0]*e+r[3]*n+r[6]*s,this.g=r[1]*e+r[4]*n+r[7]*s,this.b=r[2]*e+r[5]*n+r[8]*s,this}equals(t){return t.r===this.r&&t.g===this.g&&t.b===this.b}fromArray(t,e=0){return this.r=t[e],this.g=t[e+1],this.b=t[e+2],this}toArray(t=[],e=0){return t[e]=this.r,t[e+1]=this.g,t[e+2]=this.b,t}fromBufferAttribute(t,e){return this.r=t.getX(e),this.g=t.getY(e),this.b=t.getZ(e),this}toJSON(){return this.getHex()}*[Symbol.iterator](){yield this.r,yield this.g,yield this.b}},Rn=new se;se.NAMES=Id;var ca=class extends en{constructor(){super(),this.isScene=!0,this.type="Scene",this.background=null,this.environment=null,this.fog=null,this.backgroundBlurriness=0,this.backgroundIntensity=1,this.backgroundRotation=new zi,this.environmentIntensity=1,this.environmentRotation=new zi,this.overrideMaterial=null,typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}copy(t,e){return super.copy(t,e),t.background!==null&&(this.background=t.background.clone()),t.environment!==null&&(this.environment=t.environment.clone()),t.fog!==null&&(this.fog=t.fog.clone()),this.backgroundBlurriness=t.backgroundBlurriness,this.backgroundIntensity=t.backgroundIntensity,this.backgroundRotation.copy(t.backgroundRotation),this.environmentIntensity=t.environmentIntensity,this.environmentRotation.copy(t.environmentRotation),t.overrideMaterial!==null&&(this.overrideMaterial=t.overrideMaterial.clone()),this.matrixAutoUpdate=t.matrixAutoUpdate,this}toJSON(t){let e=super.toJSON(t);return this.fog!==null&&(e.object.fog=this.fog.toJSON()),e.object.backgroundBlurriness=this.backgroundBlurriness,e.object.backgroundIntensity=this.backgroundIntensity,e.object.backgroundRotation=this.backgroundRotation.toArray(),e.object.environmentIntensity=this.environmentIntensity,e.object.environmentRotation=this.environmentRotation.toArray(),e}},ii=new D,Li=new D,f0=new D,Ni=new D,Gs=new D,Ws=new D,vu=new D,p0=new D,m0=new D,g0=new D,x0=new $e,_0=new $e,v0=new $e,Fi=class i{constructor(t=new D,e=new D,n=new D){this.a=t,this.b=e,this.c=n}static getNormal(t,e,n,s){s.subVectors(n,e),ii.subVectors(t,e),s.cross(ii);let r=s.lengthSq();return r>0?s.multiplyScalar(1/Math.sqrt(r)):s.set(0,0,0)}static getBarycoord(t,e,n,s,r){ii.subVectors(s,e),Li.subVectors(n,e),f0.subVectors(t,e);let a=ii.dot(ii),o=ii.dot(Li),c=ii.dot(f0),l=Li.dot(Li),h=Li.dot(f0),f=a*l-o*o;if(f===0)return r.set(0,0,0),null;let u=1/f,d=(l*c-o*h)*u,g=(a*h-o*c)*u;return r.set(1-d-g,g,d)}static containsPoint(t,e,n,s){return this.getBarycoord(t,e,n,s,Ni)===null?!1:Ni.x>=0&&Ni.y>=0&&Ni.x+Ni.y<=1}static getInterpolation(t,e,n,s,r,a,o,c){return this.getBarycoord(t,e,n,s,Ni)===null?(c.x=0,c.y=0,"z"in c&&(c.z=0),"w"in c&&(c.w=0),null):(c.setScalar(0),c.addScaledVector(r,Ni.x),c.addScaledVector(a,Ni.y),c.addScaledVector(o,Ni.z),c)}static getInterpolatedAttribute(t,e,n,s,r,a){return x0.setScalar(0),_0.setScalar(0),v0.setScalar(0),x0.fromBufferAttribute(t,e),_0.fromBufferAttribute(t,n),v0.fromBufferAttribute(t,s),a.setScalar(0),a.addScaledVector(x0,r.x),a.addScaledVector(_0,r.y),a.addScaledVector(v0,r.z),a}static isFrontFacing(t,e,n,s){return ii.subVectors(n,e),Li.subVectors(t,e),ii.cross(Li).dot(s)<0}set(t,e,n){return this.a.copy(t),this.b.copy(e),this.c.copy(n),this}setFromPointsAndIndices(t,e,n,s){return this.a.copy(t[e]),this.b.copy(t[n]),this.c.copy(t[s]),this}setFromAttributeAndIndices(t,e,n,s){return this.a.fromBufferAttribute(t,e),this.b.fromBufferAttribute(t,n),this.c.fromBufferAttribute(t,s),this}clone(){return new this.constructor().copy(this)}copy(t){return this.a.copy(t.a),this.b.copy(t.b),this.c.copy(t.c),this}getArea(){return ii.subVectors(this.c,this.b),Li.subVectors(this.a,this.b),ii.cross(Li).length()*.5}getMidpoint(t){return t.addVectors(this.a,this.b).add(this.c).multiplyScalar(1/3)}getNormal(t){return i.getNormal(this.a,this.b,this.c,t)}getPlane(t){return t.setFromCoplanarPoints(this.a,this.b,this.c)}getBarycoord(t,e){return i.getBarycoord(t,this.a,this.b,this.c,e)}getInterpolation(t,e,n,s,r){return i.getInterpolation(t,this.a,this.b,this.c,e,n,s,r)}containsPoint(t){return i.containsPoint(t,this.a,this.b,this.c)}isFrontFacing(t){return i.isFrontFacing(this.a,this.b,this.c,t)}intersectsBox(t){return t.intersectsTriangle(this)}closestPointToPoint(t,e){let n=this.a,s=this.b,r=this.c,a,o;Gs.subVectors(s,n),Ws.subVectors(r,n),p0.subVectors(t,n);let c=Gs.dot(p0),l=Ws.dot(p0);if(c<=0&&l<=0)return e.copy(n);m0.subVectors(t,s);let h=Gs.dot(m0),f=Ws.dot(m0);if(h>=0&&f<=h)return e.copy(s);let u=c*f-h*l;if(u<=0&&c>=0&&h<=0)return a=c/(c-h),e.copy(n).addScaledVector(Gs,a);g0.subVectors(t,r);let d=Gs.dot(g0),g=Ws.dot(g0);if(g>=0&&d<=g)return e.copy(r);let _=d*l-c*g;if(_<=0&&l>=0&&g<=0)return o=l/(l-g),e.copy(n).addScaledVector(Ws,o);let m=h*g-d*f;if(m<=0&&f-h>=0&&d-g>=0)return vu.subVectors(r,s),o=(f-h)/(f-h+(d-g)),e.copy(s).addScaledVector(vu,o);let p=1/(m+_+u);return a=_*p,o=u*p,e.copy(n).addScaledVector(Gs,a).addScaledVector(Ws,o)}equals(t){return t.a.equals(this.a)&&t.b.equals(this.b)&&t.c.equals(this.c)}},bi=class{constructor(t=new D(1/0,1/0,1/0),e=new D(-1/0,-1/0,-1/0)){this.isBox3=!0,this.min=t,this.max=e}set(t,e){return this.min.copy(t),this.max.copy(e),this}setFromArray(t){this.makeEmpty();for(let e=0,n=t.length;e<n;e+=3)this.expandByPoint(si.fromArray(t,e));return this}setFromBufferAttribute(t){this.makeEmpty();for(let e=0,n=t.count;e<n;e++)this.expandByPoint(si.fromBufferAttribute(t,e));return this}setFromPoints(t){this.makeEmpty();for(let e=0,n=t.length;e<n;e++)this.expandByPoint(t[e]);return this}setFromCenterAndSize(t,e){let n=si.copy(e).multiplyScalar(.5);return this.min.copy(t).sub(n),this.max.copy(t).add(n),this}setFromObject(t,e=!1){return this.makeEmpty(),this.expandByObject(t,e)}clone(){return new this.constructor().copy(this)}copy(t){return this.min.copy(t.min),this.max.copy(t.max),this}makeEmpty(){return this.min.x=this.min.y=this.min.z=1/0,this.max.x=this.max.y=this.max.z=-1/0,this}isEmpty(){return this.max.x<this.min.x||this.max.y<this.min.y||this.max.z<this.min.z}getCenter(t){return this.isEmpty()?t.set(0,0,0):t.addVectors(this.min,this.max).multiplyScalar(.5)}getSize(t){return this.isEmpty()?t.set(0,0,0):t.subVectors(this.max,this.min)}expandByPoint(t){return this.min.min(t),this.max.max(t),this}expandByVector(t){return this.min.sub(t),this.max.add(t),this}expandByScalar(t){return this.min.addScalar(-t),this.max.addScalar(t),this}expandByObject(t,e=!1){t.updateWorldMatrix(!1,!1);let n=t.geometry;if(n!==void 0){let r=n.getAttribute("position");if(e===!0&&r!==void 0&&t.isInstancedMesh!==!0)for(let a=0,o=r.count;a<o;a++)t.isMesh===!0?t.getVertexPosition(a,si):si.fromBufferAttribute(r,a),si.applyMatrix4(t.matrixWorld),this.expandByPoint(si);else t.boundingBox!==void 0?(t.boundingBox===null&&t.computeBoundingBox(),Eo.copy(t.boundingBox)):(n.boundingBox===null&&n.computeBoundingBox(),Eo.copy(n.boundingBox)),Eo.applyMatrix4(t.matrixWorld),this.union(Eo)}let s=t.children;for(let r=0,a=s.length;r<a;r++)this.expandByObject(s[r],e);return this}containsPoint(t){return t.x>=this.min.x&&t.x<=this.max.x&&t.y>=this.min.y&&t.y<=this.max.y&&t.z>=this.min.z&&t.z<=this.max.z}containsBox(t){return this.min.x<=t.min.x&&t.max.x<=this.max.x&&this.min.y<=t.min.y&&t.max.y<=this.max.y&&this.min.z<=t.min.z&&t.max.z<=this.max.z}getParameter(t,e){return e.set((t.x-this.min.x)/(this.max.x-this.min.x),(t.y-this.min.y)/(this.max.y-this.min.y),(t.z-this.min.z)/(this.max.z-this.min.z))}intersectsBox(t){return t.max.x>=this.min.x&&t.min.x<=this.max.x&&t.max.y>=this.min.y&&t.min.y<=this.max.y&&t.max.z>=this.min.z&&t.min.z<=this.max.z}intersectsSphere(t){return this.clampPoint(t.center,si),si.distanceToSquared(t.center)<=t.radius*t.radius}intersectsPlane(t){let e,n;return t.normal.x>0?(e=t.normal.x*this.min.x,n=t.normal.x*this.max.x):(e=t.normal.x*this.max.x,n=t.normal.x*this.min.x),t.normal.y>0?(e+=t.normal.y*this.min.y,n+=t.normal.y*this.max.y):(e+=t.normal.y*this.max.y,n+=t.normal.y*this.min.y),t.normal.z>0?(e+=t.normal.z*this.min.z,n+=t.normal.z*this.max.z):(e+=t.normal.z*this.max.z,n+=t.normal.z*this.min.z),e<=-t.constant&&n>=-t.constant}intersectsTriangle(t){if(this.isEmpty())return!1;this.getCenter($r),wo.subVectors(this.max,$r),Xs.subVectors(t.a,$r),$s.subVectors(t.b,$r),qs.subVectors(t.c,$r),Qi.subVectors($s,Xs),ts.subVectors(qs,$s),_s.subVectors(Xs,qs);let e=[0,-Qi.z,Qi.y,0,-ts.z,ts.y,0,-_s.z,_s.y,Qi.z,0,-Qi.x,ts.z,0,-ts.x,_s.z,0,-_s.x,-Qi.y,Qi.x,0,-ts.y,ts.x,0,-_s.y,_s.x,0];return!y0(e,Xs,$s,qs,wo)||(e=[1,0,0,0,1,0,0,0,1],!y0(e,Xs,$s,qs,wo))?!1:(To.crossVectors(Qi,ts),e=[To.x,To.y,To.z],y0(e,Xs,$s,qs,wo))}clampPoint(t,e){return e.copy(t).clamp(this.min,this.max)}distanceToPoint(t){return this.clampPoint(t,si).distanceTo(t)}getBoundingSphere(t){return this.isEmpty()?t.makeEmpty():(this.getCenter(t.center),t.radius=this.getSize(si).length()*.5),t}intersect(t){return this.min.max(t.min),this.max.min(t.max),this.isEmpty()&&this.makeEmpty(),this}union(t){return this.min.min(t.min),this.max.max(t.max),this}applyMatrix4(t){return this.isEmpty()?this:(Di[0].set(this.min.x,this.min.y,this.min.z).applyMatrix4(t),Di[1].set(this.min.x,this.min.y,this.max.z).applyMatrix4(t),Di[2].set(this.min.x,this.max.y,this.min.z).applyMatrix4(t),Di[3].set(this.min.x,this.max.y,this.max.z).applyMatrix4(t),Di[4].set(this.max.x,this.min.y,this.min.z).applyMatrix4(t),Di[5].set(this.max.x,this.min.y,this.max.z).applyMatrix4(t),Di[6].set(this.max.x,this.max.y,this.min.z).applyMatrix4(t),Di[7].set(this.max.x,this.max.y,this.max.z).applyMatrix4(t),this.setFromPoints(Di),this)}translate(t){return this.min.add(t),this.max.add(t),this}equals(t){return t.min.equals(this.min)&&t.max.equals(this.max)}toJSON(){return{min:this.min.toArray(),max:this.max.toArray()}}fromJSON(t){return this.min.fromArray(t.min),this.max.fromArray(t.max),this}},Di=[new D,new D,new D,new D,new D,new D,new D,new D],si=new D,Eo=new bi,Xs=new D,$s=new D,qs=new D,Qi=new D,ts=new D,_s=new D,$r=new D,wo=new D,To=new D,vs=new D;function y0(i,t,e,n,s){for(let r=0,a=i.length-3;r<=a;r+=3){vs.fromArray(i,r);let o=s.x*Math.abs(vs.x)+s.y*Math.abs(vs.y)+s.z*Math.abs(vs.z),c=t.dot(vs),l=e.dot(vs),h=n.dot(vs);if(Math.max(-Math.max(c,l,h),Math.min(c,l,h))>o)return!1}return!0}var Qe=new D,Ao=new vt,vp=0,tn=class extends yi{constructor(t,e,n=!1){if(super(),Array.isArray(t))throw new TypeError("THREE.BufferAttribute: array should be a Typed Array.");this.isBufferAttribute=!0,Object.defineProperty(this,"id",{value:vp++}),this.name="",this.array=t,this.itemSize=e,this.count=t!==void 0?t.length/e:0,this.normalized=n,this.usage=rh,this.updateRanges=[],this.gpuType=Yn,this.version=0}onUploadCallback(){}set needsUpdate(t){t===!0&&this.version++}setUsage(t){return this.usage=t,this}addUpdateRange(t,e){this.updateRanges.push({start:t,count:e})}clearUpdateRanges(){this.updateRanges.length=0}copy(t){return this.name=t.name,this.array=new t.array.constructor(t.array),this.itemSize=t.itemSize,this.count=t.count,this.normalized=t.normalized,this.usage=t.usage,this.gpuType=t.gpuType,this}copyAt(t,e,n){t*=this.itemSize,n*=e.itemSize;for(let s=0,r=this.itemSize;s<r;s++)this.array[t+s]=e.array[n+s];return this}copyArray(t){return this.array.set(t),this}applyMatrix3(t){if(this.itemSize===2)for(let e=0,n=this.count;e<n;e++)Ao.fromBufferAttribute(this,e),Ao.applyMatrix3(t),this.setXY(e,Ao.x,Ao.y);else if(this.itemSize===3)for(let e=0,n=this.count;e<n;e++)Qe.fromBufferAttribute(this,e),Qe.applyMatrix3(t),this.setXYZ(e,Qe.x,Qe.y,Qe.z);return this}applyMatrix4(t){for(let e=0,n=this.count;e<n;e++)Qe.fromBufferAttribute(this,e),Qe.applyMatrix4(t),this.setXYZ(e,Qe.x,Qe.y,Qe.z);return this}applyNormalMatrix(t){for(let e=0,n=this.count;e<n;e++)Qe.fromBufferAttribute(this,e),Qe.applyNormalMatrix(t),this.setXYZ(e,Qe.x,Qe.y,Qe.z);return this}transformDirection(t){for(let e=0,n=this.count;e<n;e++)Qe.fromBufferAttribute(this,e),Qe.transformDirection(t),this.setXYZ(e,Qe.x,Qe.y,Qe.z);return this}set(t,e=0){return this.array.set(t,e),this}getComponent(t,e){let n=this.array[t*this.itemSize+e];return this.normalized&&(n=gi(n,this.array)),n}setComponent(t,e,n){return this.normalized&&(n=Ge(n,this.array)),this.array[t*this.itemSize+e]=n,this}getX(t){let e=this.array[t*this.itemSize];return this.normalized&&(e=gi(e,this.array)),e}setX(t,e){return this.normalized&&(e=Ge(e,this.array)),this.array[t*this.itemSize]=e,this}getY(t){let e=this.array[t*this.itemSize+1];return this.normalized&&(e=gi(e,this.array)),e}setY(t,e){return this.normalized&&(e=Ge(e,this.array)),this.array[t*this.itemSize+1]=e,this}getZ(t){let e=this.array[t*this.itemSize+2];return this.normalized&&(e=gi(e,this.array)),e}setZ(t,e){return this.normalized&&(e=Ge(e,this.array)),this.array[t*this.itemSize+2]=e,this}getW(t){let e=this.array[t*this.itemSize+3];return this.normalized&&(e=gi(e,this.array)),e}setW(t,e){return this.normalized&&(e=Ge(e,this.array)),this.array[t*this.itemSize+3]=e,this}setXY(t,e,n){return t*=this.itemSize,this.normalized&&(e=Ge(e,this.array),n=Ge(n,this.array)),this.array[t+0]=e,this.array[t+1]=n,this}setXYZ(t,e,n,s){return t*=this.itemSize,this.normalized&&(e=Ge(e,this.array),n=Ge(n,this.array),s=Ge(s,this.array)),this.array[t+0]=e,this.array[t+1]=n,this.array[t+2]=s,this}setXYZW(t,e,n,s,r){return t*=this.itemSize,this.normalized&&(e=Ge(e,this.array),n=Ge(n,this.array),s=Ge(s,this.array),r=Ge(r,this.array)),this.array[t+0]=e,this.array[t+1]=n,this.array[t+2]=s,this.array[t+3]=r,this}onUpload(t){return this.onUploadCallback=t,this}clone(){return new this.constructor(this.array,this.itemSize).copy(this)}toJSON(){let t={itemSize:this.itemSize,type:this.array.constructor.name,array:Array.from(this.array),normalized:this.normalized};return t.name=this.name,t.usage=this.usage,t.gpuType=this.gpuType,t}dispose(){this.dispatchEvent({type:"dispose"})}};var ha=class extends tn{constructor(t,e,n){super(new Uint16Array(t),e,n)}};var ua=class extends tn{constructor(t,e,n){super(new Uint32Array(t),e,n)}};var fe=class extends tn{constructor(t,e,n){super(new Float32Array(t),e,n)}},yp=new bi,qr=new D,M0=new D,Wn=class{constructor(t=new D,e=-1){this.isSphere=!0,this.center=t,this.radius=e}set(t,e){return this.center.copy(t),this.radius=e,this}setFromPoints(t,e){let n=this.center;e!==void 0?n.copy(e):yp.setFromPoints(t).getCenter(n);let s=0;for(let r=0,a=t.length;r<a;r++)s=Math.max(s,n.distanceToSquared(t[r]));return this.radius=Math.sqrt(s),this}copy(t){return this.center.copy(t.center),this.radius=t.radius,this}isEmpty(){return this.radius<0}makeEmpty(){return this.center.set(0,0,0),this.radius=-1,this}containsPoint(t){return t.distanceToSquared(this.center)<=this.radius*this.radius}distanceToPoint(t){return t.distanceTo(this.center)-this.radius}intersectsSphere(t){let e=this.radius+t.radius;return t.center.distanceToSquared(this.center)<=e*e}intersectsBox(t){return t.intersectsSphere(this)}intersectsPlane(t){return Math.abs(t.distanceToPoint(this.center))<=this.radius}clampPoint(t,e){let n=this.center.distanceToSquared(t);return e.copy(t),n>this.radius*this.radius&&(e.sub(this.center).normalize(),e.multiplyScalar(this.radius).add(this.center)),e}getBoundingBox(t){return this.isEmpty()?(t.makeEmpty(),t):(t.set(this.center,this.center),t.expandByScalar(this.radius),t)}applyMatrix4(t){return this.center.applyMatrix4(t),this.radius=this.radius*t.getMaxScaleOnAxis(),this}translate(t){return this.center.add(t),this}expandByPoint(t){if(this.isEmpty())return this.center.copy(t),this.radius=0,this;qr.subVectors(t,this.center);let e=qr.lengthSq();if(e>this.radius*this.radius){let n=Math.sqrt(e),s=(n-this.radius)*.5;this.center.addScaledVector(qr,s/n),this.radius+=s}return this}union(t){return t.isEmpty()?this:this.isEmpty()?(this.copy(t),this):(this.center.equals(t.center)===!0?this.radius=Math.max(this.radius,t.radius):(M0.subVectors(t.center,this.center).setLength(t.radius),this.expandByPoint(qr.copy(t.center).add(M0)),this.expandByPoint(qr.copy(t.center).sub(M0))),this)}equals(t){return t.center.equals(this.center)&&t.radius===this.radius}clone(){return new this.constructor().copy(this)}toJSON(){return{radius:this.radius,center:this.center.toArray()}}fromJSON(t){return this.radius=t.radius,this.center.fromArray(t.center),this}},Mp=0,Gn=new Ce,b0=new en,Ys=new D,On=new bi,Yr=new bi,pn=new D,Ae=class i extends yi{constructor(){super(),this.isBufferGeometry=!0,Object.defineProperty(this,"id",{value:Mp++}),this.uuid=Oi(),this.name="",this.type="BufferGeometry",this.index=null,this.indirect=null,this.indirectOffset=0,this.attributes={},this.morphAttributes={},this.morphTargetsRelative=!1,this.groups=[],this.boundingBox=null,this.boundingSphere=null,this.drawRange={start:0,count:1/0},this.userData={},this._transformed=!1}getIndex(){return this.index}setIndex(t){return Array.isArray(t)?this.index=new(ap(t)?ua:ha)(t,1):this.index=t,this}setIndirect(t,e=0){return this.indirect=t,this.indirectOffset=e,this}getIndirect(){return this.indirect}getAttribute(t){return this.attributes[t]}setAttribute(t,e){return this.attributes[t]=e,this}deleteAttribute(t){return delete this.attributes[t],this}hasAttribute(t){return this.attributes[t]!==void 0}addGroup(t,e,n=0){this.groups.push({start:t,count:e,materialIndex:n})}clearGroups(){this.groups=[]}setDrawRange(t,e){this.drawRange.start=t,this.drawRange.count=e}applyMatrix4(t){let e=this.attributes.position;e!==void 0&&(e.applyMatrix4(t),e.needsUpdate=!0);let n=this.attributes.normal;if(n!==void 0){let r=new me().getNormalMatrix(t);n.applyNormalMatrix(r),n.needsUpdate=!0}let s=this.attributes.tangent;return s!==void 0&&(s.transformDirection(t),s.needsUpdate=!0),this.boundingBox!==null&&this.computeBoundingBox(),this.boundingSphere!==null&&this.computeBoundingSphere(),this._transformed=!0,this}applyQuaternion(t){return Gn.makeRotationFromQuaternion(t),this.applyMatrix4(Gn),this}rotateX(t){return Gn.makeRotationX(t),this.applyMatrix4(Gn),this}rotateY(t){return Gn.makeRotationY(t),this.applyMatrix4(Gn),this}rotateZ(t){return Gn.makeRotationZ(t),this.applyMatrix4(Gn),this}translate(t,e,n){return Gn.makeTranslation(t,e,n),this.applyMatrix4(Gn),this}scale(t,e,n){return Gn.makeScale(t,e,n),this.applyMatrix4(Gn),this}lookAt(t){return b0.lookAt(t),b0.updateMatrix(),this.applyMatrix4(b0.matrix),this}center(){return this.computeBoundingBox(),this.boundingBox.getCenter(Ys).negate(),this.translate(Ys.x,Ys.y,Ys.z),this}setFromPoints(t){let e=this.getAttribute("position");if(e===void 0){let n=[];for(let s=0,r=t.length;s<r;s++){let a=t[s];n.push(a.x,a.y,a.z||0)}this.setAttribute("position",new fe(n,3))}else{let n=Math.min(t.length,e.count);for(let s=0;s<n;s++){let r=t[s];e.setXYZ(s,r.x,r.y,r.z||0)}t.length>e.count&&ue("BufferGeometry: Buffer size too small for points data. Use .dispose() and create a new geometry."),e.needsUpdate=!0}return this}computeBoundingBox(){this.boundingBox===null&&(this.boundingBox=new bi);let t=this.attributes.position,e=this.morphAttributes.position;if(t&&t.isGLBufferAttribute){he("BufferGeometry.computeBoundingBox(): GLBufferAttribute requires a manual bounding box.",this),this.boundingBox.set(new D(-1/0,-1/0,-1/0),new D(1/0,1/0,1/0));return}if(t!==void 0){if(this.boundingBox.setFromBufferAttribute(t),e)for(let n=0,s=e.length;n<s;n++){let r=e[n];On.setFromBufferAttribute(r),this.morphTargetsRelative?(pn.addVectors(this.boundingBox.min,On.min),this.boundingBox.expandByPoint(pn),pn.addVectors(this.boundingBox.max,On.max),this.boundingBox.expandByPoint(pn)):(this.boundingBox.expandByPoint(On.min),this.boundingBox.expandByPoint(On.max))}}else this.boundingBox.makeEmpty();(isNaN(this.boundingBox.min.x)||isNaN(this.boundingBox.min.y)||isNaN(this.boundingBox.min.z))&&he('BufferGeometry.computeBoundingBox(): Computed min/max have NaN values. The "position" attribute is likely to have NaN values.',this)}computeBoundingSphere(){this.boundingSphere===null&&(this.boundingSphere=new Wn);let t=this.attributes.position,e=this.morphAttributes.position;if(t&&t.isGLBufferAttribute){he("BufferGeometry.computeBoundingSphere(): GLBufferAttribute requires a manual bounding sphere.",this),this.boundingSphere.set(new D,1/0);return}if(t){let n=this.boundingSphere.center;if(On.setFromBufferAttribute(t),e)for(let r=0,a=e.length;r<a;r++){let o=e[r];Yr.setFromBufferAttribute(o),this.morphTargetsRelative?(pn.addVectors(On.min,Yr.min),On.expandByPoint(pn),pn.addVectors(On.max,Yr.max),On.expandByPoint(pn)):(On.expandByPoint(Yr.min),On.expandByPoint(Yr.max))}On.getCenter(n);let s=0;for(let r=0,a=t.count;r<a;r++)pn.fromBufferAttribute(t,r),s=Math.max(s,n.distanceToSquared(pn));if(e)for(let r=0,a=e.length;r<a;r++){let o=e[r],c=this.morphTargetsRelative;for(let l=0,h=o.count;l<h;l++)pn.fromBufferAttribute(o,l),c&&(Ys.fromBufferAttribute(t,l),pn.add(Ys)),s=Math.max(s,n.distanceToSquared(pn))}this.boundingSphere.radius=Math.sqrt(s),isNaN(this.boundingSphere.radius)&&he('BufferGeometry.computeBoundingSphere(): Computed radius is NaN. The "position" attribute is likely to have NaN values.',this)}}computeTangents(){let t=this.index,e=this.attributes;if(t===null||e.position===void 0||e.normal===void 0||e.uv===void 0){he("BufferGeometry: .computeTangents() failed. Missing required attributes (index, position, normal or uv)");return}let n=e.position,s=e.normal,r=e.uv,a=this.getAttribute("tangent");(a===void 0||a.count!==n.count)&&(a=new tn(new Float32Array(4*n.count),4),this.setAttribute("tangent",a));let o=[],c=[];for(let v=0;v<n.count;v++)o[v]=new D,c[v]=new D;let l=new D,h=new D,f=new D,u=new vt,d=new vt,g=new vt,_=new D,m=new D;function p(v,C,L){l.fromBufferAttribute(n,v),h.fromBufferAttribute(n,C),f.fromBufferAttribute(n,L),u.fromBufferAttribute(r,v),d.fromBufferAttribute(r,C),g.fromBufferAttribute(r,L),h.sub(l),f.sub(l),d.sub(u),g.sub(u);let N=1/(d.x*g.y-g.x*d.y);isFinite(N)&&(_.copy(h).multiplyScalar(g.y).addScaledVector(f,-d.y).multiplyScalar(N),m.copy(f).multiplyScalar(d.x).addScaledVector(h,-g.x).multiplyScalar(N),o[v].add(_),o[C].add(_),o[L].add(_),c[v].add(m),c[C].add(m),c[L].add(m))}let S=this.groups;S.length===0&&(S=[{start:0,count:t.count}]);for(let v=0,C=S.length;v<C;++v){let L=S[v],N=L.start,P=L.count;for(let B=N,F=N+P;B<F;B+=3)p(t.getX(B+0),t.getX(B+1),t.getX(B+2))}let w=new D,y=new D,E=new D,M=new D;function I(v){E.fromBufferAttribute(s,v),M.copy(E);let C=o[v];w.copy(C),w.sub(E.multiplyScalar(E.dot(C))).normalize(),y.crossVectors(M,C);let N=y.dot(c[v])<0?-1:1;a.setXYZW(v,w.x,w.y,w.z,N)}for(let v=0,C=S.length;v<C;++v){let L=S[v],N=L.start,P=L.count;for(let B=N,F=N+P;B<F;B+=3)I(t.getX(B+0)),I(t.getX(B+1)),I(t.getX(B+2))}this._transformed=!0}computeVertexNormals(){let t=this.index,e=this.getAttribute("position");if(e!==void 0){let n=this.getAttribute("normal");if(n===void 0||n.count!==e.count)n=new tn(new Float32Array(e.count*3),3),this.setAttribute("normal",n);else for(let u=0,d=n.count;u<d;u++)n.setXYZ(u,0,0,0);let s=new D,r=new D,a=new D,o=new D,c=new D,l=new D,h=new D,f=new D;if(t)for(let u=0,d=t.count;u<d;u+=3){let g=t.getX(u+0),_=t.getX(u+1),m=t.getX(u+2);s.fromBufferAttribute(e,g),r.fromBufferAttribute(e,_),a.fromBufferAttribute(e,m),h.subVectors(a,r),f.subVectors(s,r),h.cross(f),o.fromBufferAttribute(n,g),c.fromBufferAttribute(n,_),l.fromBufferAttribute(n,m),o.add(h),c.add(h),l.add(h),n.setXYZ(g,o.x,o.y,o.z),n.setXYZ(_,c.x,c.y,c.z),n.setXYZ(m,l.x,l.y,l.z)}else for(let u=0,d=e.count;u<d;u+=3)s.fromBufferAttribute(e,u+0),r.fromBufferAttribute(e,u+1),a.fromBufferAttribute(e,u+2),h.subVectors(a,r),f.subVectors(s,r),h.cross(f),n.setXYZ(u+0,h.x,h.y,h.z),n.setXYZ(u+1,h.x,h.y,h.z),n.setXYZ(u+2,h.x,h.y,h.z);this.normalizeNormals(),n.needsUpdate=!0}}normalizeNormals(){let t=this.attributes.normal;for(let e=0,n=t.count;e<n;e++)pn.fromBufferAttribute(t,e),pn.normalize(),t.setXYZ(e,pn.x,pn.y,pn.z)}toNonIndexed(){function t(o,c){let l=o.array,h=o.itemSize,f=o.normalized,u=new l.constructor(c.length*h),d=0,g=0;for(let _=0,m=c.length;_<m;_++){o.isInterleavedBufferAttribute?d=c[_]*o.data.stride+o.offset:d=c[_]*h;for(let p=0;p<h;p++)u[g++]=l[d++]}return new tn(u,h,f)}if(this.index===null)return ue("BufferGeometry.toNonIndexed(): BufferGeometry is already non-indexed."),this;let e=new i,n=this.index.array,s=this.attributes;for(let o in s){let c=s[o],l=t(c,n);e.setAttribute(o,l)}let r=this.morphAttributes;for(let o in r){let c=[],l=r[o];for(let h=0,f=l.length;h<f;h++){let u=l[h],d=t(u,n);c.push(d)}e.morphAttributes[o]=c}e.morphTargetsRelative=this.morphTargetsRelative;let a=this.groups;for(let o=0,c=a.length;o<c;o++){let l=a[o];e.addGroup(l.start,l.count,l.materialIndex)}return e}toJSON(){let t={metadata:{version:4.7,type:"BufferGeometry",generator:"BufferGeometry.toJSON"}};if(t.uuid=this.uuid,t.type=this.parameters!==void 0&&this._transformed===!0?"BufferGeometry":this.type,t.name=this.name,Object.keys(this.userData).length>0&&(t.userData=this.userData),this.parameters!==void 0&&this._transformed!==!0){let c=this.parameters;for(let l in c)c[l]!==void 0&&(t[l]=c[l]);return t}t.data={attributes:{}};let e=this.index;e!==null&&(t.data.index={type:e.array.constructor.name,array:Array.prototype.slice.call(e.array)});let n=this.attributes;for(let c in n){let l=n[c];t.data.attributes[c]=l.toJSON(t.data)}let s={},r=!1;for(let c in this.morphAttributes){let l=this.morphAttributes[c],h=[];for(let f=0,u=l.length;f<u;f++){let d=l[f];h.push(d.toJSON(t.data))}h.length>0&&(s[c]=h,r=!0)}r&&(t.data.morphAttributes=s,t.data.morphTargetsRelative=this.morphTargetsRelative);let a=this.groups;a.length>0&&(t.data.groups=JSON.parse(JSON.stringify(a)));let o=this.boundingSphere;return o!==null&&(t.data.boundingSphere=o.toJSON()),t}clone(){return new this.constructor().copy(this)}copy(t){this.index=null,this.attributes={},this.morphAttributes={},this.groups=[],this.boundingBox=null,this.boundingSphere=null;let e={};this.name=t.name;let n=t.index;n!==null&&this.setIndex(n.clone());let s=t.attributes;for(let l in s){let h=s[l];this.setAttribute(l,h.clone(e))}let r=t.morphAttributes;for(let l in r){let h=[],f=r[l];for(let u=0,d=f.length;u<d;u++)h.push(f[u].clone(e));this.morphAttributes[l]=h}this.morphTargetsRelative=t.morphTargetsRelative;let a=t.groups;for(let l=0,h=a.length;l<h;l++){let f=a[l];this.addGroup(f.start,f.count,f.materialIndex)}let o=t.boundingBox;o!==null&&(this.boundingBox=o.clone());let c=t.boundingSphere;return c!==null&&(this.boundingSphere=c.clone()),this.drawRange.start=t.drawRange.start,this.drawRange.count=t.drawRange.count,this.userData=t.userData,this._transformed=t._transformed,this}dispose(){this.dispatchEvent({type:"dispose"})}},da=class{constructor(t,e){this.isInterleavedBuffer=!0,this.array=t,this.stride=e,this.count=t!==void 0?t.length/e:0,this.usage=rh,this.updateRanges=[],this.version=0,this.uuid=Oi()}onUploadCallback(){}set needsUpdate(t){t===!0&&this.version++}setUsage(t){return this.usage=t,this}addUpdateRange(t,e){this.updateRanges.push({start:t,count:e})}clearUpdateRanges(){this.updateRanges.length=0}copy(t){return this.array=new t.array.constructor(t.array),this.count=t.count,this.stride=t.stride,this.usage=t.usage,this}copyAt(t,e,n){t*=this.stride,n*=e.stride;for(let s=0,r=this.stride;s<r;s++)this.array[t+s]=e.array[n+s];return this}set(t,e=0){return this.array.set(t,e),this}clone(t){t.arrayBuffers===void 0&&(t.arrayBuffers={}),this.array.buffer._uuid===void 0&&(this.array.buffer._uuid=Oi()),t.arrayBuffers[this.array.buffer._uuid]===void 0&&(t.arrayBuffers[this.array.buffer._uuid]=this.array.slice(0).buffer);let e=new this.array.constructor(t.arrayBuffers[this.array.buffer._uuid]),n=new this.constructor(e,this.stride);return n.setUsage(this.usage),n}onUpload(t){return this.onUploadCallback=t,this}toJSON(t){t.arrayBuffers===void 0&&(t.arrayBuffers={}),this.array.buffer._uuid===void 0&&(this.array.buffer._uuid=Oi()),t.arrayBuffers[this.array.buffer._uuid]===void 0&&(t.arrayBuffers[this.array.buffer._uuid]=Array.from(new Uint32Array(this.array.buffer)));let e={uuid:this.uuid,buffer:this.array.buffer._uuid,type:this.array.constructor.name,stride:this.stride};return e.usage=this.usage,e}},Ln=new D,dr=class i{constructor(t,e,n,s=!1){this.isInterleavedBufferAttribute=!0,this.name="",this.data=t,this.itemSize=e,this.offset=n,this.normalized=s}get count(){return this.data.count}get array(){return this.data.array}set needsUpdate(t){this.data.needsUpdate=t}applyMatrix4(t){for(let e=0,n=this.data.count;e<n;e++)Ln.fromBufferAttribute(this,e),Ln.applyMatrix4(t),this.setXYZ(e,Ln.x,Ln.y,Ln.z);return this}applyNormalMatrix(t){for(let e=0,n=this.count;e<n;e++)Ln.fromBufferAttribute(this,e),Ln.applyNormalMatrix(t),this.setXYZ(e,Ln.x,Ln.y,Ln.z);return this}transformDirection(t){for(let e=0,n=this.count;e<n;e++)Ln.fromBufferAttribute(this,e),Ln.transformDirection(t),this.setXYZ(e,Ln.x,Ln.y,Ln.z);return this}getComponent(t,e){let n=this.array[t*this.data.stride+this.offset+e];return this.normalized&&(n=gi(n,this.array)),n}setComponent(t,e,n){return this.normalized&&(n=Ge(n,this.array)),this.data.array[t*this.data.stride+this.offset+e]=n,this}setX(t,e){return this.normalized&&(e=Ge(e,this.array)),this.data.array[t*this.data.stride+this.offset]=e,this}setY(t,e){return this.normalized&&(e=Ge(e,this.array)),this.data.array[t*this.data.stride+this.offset+1]=e,this}setZ(t,e){return this.normalized&&(e=Ge(e,this.array)),this.data.array[t*this.data.stride+this.offset+2]=e,this}setW(t,e){return this.normalized&&(e=Ge(e,this.array)),this.data.array[t*this.data.stride+this.offset+3]=e,this}getX(t){let e=this.data.array[t*this.data.stride+this.offset];return this.normalized&&(e=gi(e,this.array)),e}getY(t){let e=this.data.array[t*this.data.stride+this.offset+1];return this.normalized&&(e=gi(e,this.array)),e}getZ(t){let e=this.data.array[t*this.data.stride+this.offset+2];return this.normalized&&(e=gi(e,this.array)),e}getW(t){let e=this.data.array[t*this.data.stride+this.offset+3];return this.normalized&&(e=gi(e,this.array)),e}setXY(t,e,n){return t=t*this.data.stride+this.offset,this.normalized&&(e=Ge(e,this.array),n=Ge(n,this.array)),this.data.array[t+0]=e,this.data.array[t+1]=n,this}setXYZ(t,e,n,s){return t=t*this.data.stride+this.offset,this.normalized&&(e=Ge(e,this.array),n=Ge(n,this.array),s=Ge(s,this.array)),this.data.array[t+0]=e,this.data.array[t+1]=n,this.data.array[t+2]=s,this}setXYZW(t,e,n,s,r){return t=t*this.data.stride+this.offset,this.normalized&&(e=Ge(e,this.array),n=Ge(n,this.array),s=Ge(s,this.array),r=Ge(r,this.array)),this.data.array[t+0]=e,this.data.array[t+1]=n,this.data.array[t+2]=s,this.data.array[t+3]=r,this}clone(t){if(t===void 0){oa("InterleavedBufferAttribute.clone(): Cloning an interleaved buffer attribute will de-interleave buffer data.");let e=[];for(let n=0;n<this.count;n++){let s=n*this.data.stride+this.offset;for(let r=0;r<this.itemSize;r++)e.push(this.data.array[s+r])}return new tn(new this.array.constructor(e),this.itemSize,this.normalized)}else return t.interleavedBuffers===void 0&&(t.interleavedBuffers={}),t.interleavedBuffers[this.data.uuid]===void 0&&(t.interleavedBuffers[this.data.uuid]=this.data.clone(t)),new i(t.interleavedBuffers[this.data.uuid],this.itemSize,this.offset,this.normalized)}toJSON(t){if(t===void 0){oa("InterleavedBufferAttribute.toJSON(): Serializing an interleaved buffer attribute will de-interleave buffer data.");let e=[];for(let n=0;n<this.count;n++){let s=n*this.data.stride+this.offset;for(let r=0;r<this.itemSize;r++)e.push(this.data.array[s+r])}return{itemSize:this.itemSize,type:this.array.constructor.name,array:e,normalized:this.normalized}}else return t.interleavedBuffers===void 0&&(t.interleavedBuffers={}),t.interleavedBuffers[this.data.uuid]===void 0&&(t.interleavedBuffers[this.data.uuid]=this.data.toJSON(t)),{isInterleavedBufferAttribute:!0,itemSize:this.itemSize,data:this.data.uuid,offset:this.offset,normalized:this.normalized}}},S0=new D,bp=new D,Sp=new me,ri=class{constructor(t=new D(1,0,0),e=0){this.isPlane=!0,this.normal=t,this.constant=e}set(t,e){return this.normal.copy(t),this.constant=e,this}setComponents(t,e,n,s){return this.normal.set(t,e,n),this.constant=s,this}setFromNormalAndCoplanarPoint(t,e){return this.normal.copy(t),this.constant=-e.dot(this.normal),this}setFromCoplanarPoints(t,e,n){let s=S0.subVectors(n,e).cross(bp.subVectors(t,e)).normalize();return this.setFromNormalAndCoplanarPoint(s,t),this}copy(t){return this.normal.copy(t.normal),this.constant=t.constant,this}normalize(){let t=1/this.normal.length();return this.normal.multiplyScalar(t),this.constant*=t,this}negate(){return this.constant*=-1,this.normal.negate(),this}distanceToPoint(t){return this.normal.dot(t)+this.constant}distanceToSphere(t){return this.distanceToPoint(t.center)-t.radius}projectPoint(t,e){return e.copy(t).addScaledVector(this.normal,-this.distanceToPoint(t))}intersectLine(t,e,n=!0){let s=t.delta(S0),r=this.normal.dot(s);if(r===0)return this.distanceToPoint(t.start)===0?e.copy(t.start):null;let a=-(t.start.dot(this.normal)+this.constant)/r;return n===!0&&(a<0||a>1)?null:e.copy(t.start).addScaledVector(s,a)}intersectsLine(t){let e=this.distanceToPoint(t.start),n=this.distanceToPoint(t.end);return e<0&&n>0||n<0&&e>0}intersectsBox(t){return t.intersectsPlane(this)}intersectsSphere(t){return t.intersectsPlane(this)}coplanarPoint(t){return t.copy(this.normal).multiplyScalar(-this.constant)}applyMatrix4(t,e){let n=e||Sp.getNormalMatrix(t),s=this.coplanarPoint(S0).applyMatrix4(t),r=this.normal.applyMatrix3(n).normalize();return this.constant=-s.dot(r),this}translate(t){return this.constant-=t.dot(this.normal),this}equals(t){return t.normal.equals(this.normal)&&t.constant===this.constant}clone(){return new this.constructor().copy(this)}toJSON(){return{normal:this.normal.toArray(),constant:this.constant}}fromJSON(t){return this.normal.fromArray(t.normal),this.constant=t.constant,this}},Ep=0,oi=class extends yi{constructor(){super(),this.isMaterial=!0,Object.defineProperty(this,"id",{value:Ep++}),this.uuid=Oi(),this.name="",this.type="Material",this.blending=us,this.side=hs,this.vertexColors=!1,this.opacity=1,this.transparent=!1,this.alphaHash=!1,this.blendSrc=Z0,this.blendDst=J0,this.blendEquation=ws,this.blendSrcAlpha=null,this.blendDstAlpha=null,this.blendEquationAlpha=null,this.blendColor=new se(0,0,0),this.blendAlpha=0,this.depthFunc=rr,this.depthTest=!0,this.depthWrite=!0,this.stencilWriteMask=255,this.stencilFunc=vd,this.stencilRef=0,this.stencilFuncMask=255,this.stencilFail=jo,this.stencilZFail=jo,this.stencilZPass=jo,this.stencilWrite=!1,this.clippingPlanes=null,this.clipIntersection=!1,this.clipShadows=!1,this.shadowSide=null,this.colorWrite=!0,this.precision=null,this.polygonOffset=!1,this.polygonOffsetFactor=0,this.polygonOffsetUnits=0,this.dithering=!1,this.alphaToCoverage=!1,this.premultipliedAlpha=!1,this.forceSinglePass=!1,this.allowOverride=!0,this.visible=!0,this.toneMapped=!0,this.userData={},this.version=0,this._alphaTest=0}get alphaTest(){return this._alphaTest}set alphaTest(t){this._alphaTest>0!=t>0&&this.version++,this._alphaTest=t}onBeforeRender(){}onBeforeCompile(){}customProgramCacheKey(){return this.onBeforeCompile.toString()}setValues(t){if(t!==void 0)for(let e in t){let n=t[e];if(n===void 0){ue(`Material: parameter '${e}' has value of undefined.`);continue}let s=this[e];if(s===void 0){ue(`Material: '${e}' is not a property of THREE.${this.type}.`);continue}s&&s.isColor?s.set(n):s&&s.isVector2&&n&&n.isVector2||s&&s.isEuler&&n&&n.isEuler||s&&s.isVector3&&n&&n.isVector3?s.copy(n):this[e]=n}}toJSON(t){let e=t===void 0||typeof t=="string";e&&(t={textures:{},images:{}});let n={metadata:{version:4.7,type:"Material",generator:"Material.toJSON"}};n.uuid=this.uuid,n.type=this.type,n.blending=this.blending,n.side=this.side,n.shadowSide=this.shadowSide,n.vertexColors=this.vertexColors,n.opacity=this.opacity,n.transparent=this.transparent,n.blendSrc=this.blendSrc,n.blendDst=this.blendDst,n.blendEquation=this.blendEquation,n.blendSrcAlpha=this.blendSrcAlpha,n.blendDstAlpha=this.blendDstAlpha,n.blendEquationAlpha=this.blendEquationAlpha,n.blendColor=this.blendColor.getHex(),n.blendAlpha=this.blendAlpha,n.depthFunc=this.depthFunc,n.depthTest=this.depthTest,n.depthWrite=this.depthWrite,n.colorWrite=this.colorWrite,n.clipIntersection=this.clipIntersection,n.clipShadows=this.clipShadows,n.stencilWriteMask=this.stencilWriteMask,n.stencilFunc=this.stencilFunc,n.stencilRef=this.stencilRef,n.stencilFuncMask=this.stencilFuncMask,n.stencilFail=this.stencilFail,n.stencilZFail=this.stencilZFail,n.stencilZPass=this.stencilZPass,n.stencilWrite=this.stencilWrite,n.polygonOffset=this.polygonOffset,n.polygonOffsetFactor=this.polygonOffsetFactor,n.polygonOffsetUnits=this.polygonOffsetUnits,n.dithering=this.dithering,n.alphaTest=this.alphaTest,n.alphaHash=this.alphaHash,n.alphaToCoverage=this.alphaToCoverage,n.premultipliedAlpha=this.premultipliedAlpha,n.forceSinglePass=this.forceSinglePass,n.allowOverride=this.allowOverride,n.visible=this.visible,n.toneMapped=this.toneMapped,n.name=this.name,this.color&&this.color.isColor&&(n.color=this.color.getHex()),this.roughness!==void 0&&(n.roughness=this.roughness),this.metalness!==void 0&&(n.metalness=this.metalness),this.sheen!==void 0&&(n.sheen=this.sheen),this.sheenColor&&this.sheenColor.isColor&&(n.sheenColor=this.sheenColor.getHex()),this.sheenRoughness!==void 0&&(n.sheenRoughness=this.sheenRoughness),this.emissive&&this.emissive.isColor&&(n.emissive=this.emissive.getHex()),this.emissiveIntensity!==void 0&&(n.emissiveIntensity=this.emissiveIntensity),this.specular&&this.specular.isColor&&(n.specular=this.specular.getHex()),this.specularIntensity!==void 0&&(n.specularIntensity=this.specularIntensity),this.specularColor&&this.specularColor.isColor&&(n.specularColor=this.specularColor.getHex()),this.shininess!==void 0&&(n.shininess=this.shininess),this.clearcoat!==void 0&&(n.clearcoat=this.clearcoat),this.clearcoatRoughness!==void 0&&(n.clearcoatRoughness=this.clearcoatRoughness),this.clearcoatMap&&this.clearcoatMap.isTexture&&(n.clearcoatMap=this.clearcoatMap.toJSON(t).uuid),this.clearcoatRoughnessMap&&this.clearcoatRoughnessMap.isTexture&&(n.clearcoatRoughnessMap=this.clearcoatRoughnessMap.toJSON(t).uuid),this.clearcoatNormalMap&&this.clearcoatNormalMap.isTexture&&(n.clearcoatNormalMap=this.clearcoatNormalMap.toJSON(t).uuid,n.clearcoatNormalScale=this.clearcoatNormalScale.toArray()),this.sheenColorMap&&this.sheenColorMap.isTexture&&(n.sheenColorMap=this.sheenColorMap.toJSON(t).uuid),this.sheenRoughnessMap&&this.sheenRoughnessMap.isTexture&&(n.sheenRoughnessMap=this.sheenRoughnessMap.toJSON(t).uuid),this.dispersion!==void 0&&(n.dispersion=this.dispersion),this.retroreflectivity!==void 0&&(n.retroreflectivity=this.retroreflectivity),this.iridescence!==void 0&&(n.iridescence=this.iridescence),this.iridescenceIOR!==void 0&&(n.iridescenceIOR=this.iridescenceIOR),this.iridescenceThicknessRange!==void 0&&(n.iridescenceThicknessRange=this.iridescenceThicknessRange),this.iridescenceMap&&this.iridescenceMap.isTexture&&(n.iridescenceMap=this.iridescenceMap.toJSON(t).uuid),this.iridescenceThicknessMap&&this.iridescenceThicknessMap.isTexture&&(n.iridescenceThicknessMap=this.iridescenceThicknessMap.toJSON(t).uuid),this.anisotropy!==void 0&&(n.anisotropy=this.anisotropy),this.anisotropyRotation!==void 0&&(n.anisotropyRotation=this.anisotropyRotation),this.anisotropyMap&&this.anisotropyMap.isTexture&&(n.anisotropyMap=this.anisotropyMap.toJSON(t).uuid),this.map&&this.map.isTexture&&(n.map=this.map.toJSON(t).uuid),this.matcap&&this.matcap.isTexture&&(n.matcap=this.matcap.toJSON(t).uuid),this.alphaMap&&this.alphaMap.isTexture&&(n.alphaMap=this.alphaMap.toJSON(t).uuid),this.lightMap&&this.lightMap.isTexture&&(n.lightMap=this.lightMap.toJSON(t).uuid,n.lightMapIntensity=this.lightMapIntensity),this.aoMap&&this.aoMap.isTexture&&(n.aoMap=this.aoMap.toJSON(t).uuid,n.aoMapIntensity=this.aoMapIntensity),this.bumpMap&&this.bumpMap.isTexture&&(n.bumpMap=this.bumpMap.toJSON(t).uuid,n.bumpScale=this.bumpScale),this.normalMap&&this.normalMap.isTexture&&(n.normalMap=this.normalMap.toJSON(t).uuid,n.normalMapType=this.normalMapType,n.normalScale=this.normalScale.toArray()),this.displacementMap&&this.displacementMap.isTexture&&(n.displacementMap=this.displacementMap.toJSON(t).uuid,n.displacementScale=this.displacementScale,n.displacementBias=this.displacementBias),this.roughnessMap&&this.roughnessMap.isTexture&&(n.roughnessMap=this.roughnessMap.toJSON(t).uuid),this.metalnessMap&&this.metalnessMap.isTexture&&(n.metalnessMap=this.metalnessMap.toJSON(t).uuid),this.emissiveMap&&this.emissiveMap.isTexture&&(n.emissiveMap=this.emissiveMap.toJSON(t).uuid),this.specularMap&&this.specularMap.isTexture&&(n.specularMap=this.specularMap.toJSON(t).uuid),this.specularIntensityMap&&this.specularIntensityMap.isTexture&&(n.specularIntensityMap=this.specularIntensityMap.toJSON(t).uuid),this.specularColorMap&&this.specularColorMap.isTexture&&(n.specularColorMap=this.specularColorMap.toJSON(t).uuid),this.envMap&&this.envMap.isTexture&&(n.envMap=this.envMap.toJSON(t).uuid,this.combine!==void 0&&(n.combine=this.combine)),this.envMapRotation!==void 0&&(n.envMapRotation=this.envMapRotation.toArray()),this.envMapIntensity!==void 0&&(n.envMapIntensity=this.envMapIntensity),this.reflectivity!==void 0&&(n.reflectivity=this.reflectivity),this.refractionRatio!==void 0&&(n.refractionRatio=this.refractionRatio),this.gradientMap&&this.gradientMap.isTexture&&(n.gradientMap=this.gradientMap.toJSON(t).uuid),this.transmission!==void 0&&(n.transmission=this.transmission),this.transmissionMap&&this.transmissionMap.isTexture&&(n.transmissionMap=this.transmissionMap.toJSON(t).uuid),this.thickness!==void 0&&(n.thickness=this.thickness),this.thicknessMap&&this.thicknessMap.isTexture&&(n.thicknessMap=this.thicknessMap.toJSON(t).uuid),this.attenuationDistance!==void 0&&(n.attenuationDistance=this.attenuationDistance),this.attenuationColor!==void 0&&(n.attenuationColor=this.attenuationColor.getHex()),this.size!==void 0&&(n.size=this.size),this.sizeAttenuation!==void 0&&(n.sizeAttenuation=this.sizeAttenuation),Array.isArray(this.clippingPlanes)&&this.clippingPlanes.length>0&&(n.clippingPlanes=this.clippingPlanes.map(r=>r.toJSON())),this.rotation!==void 0&&(n.rotation=this.rotation),this.depthPacking!==void 0&&(n.depthPacking=this.depthPacking),this.linewidth!==void 0&&(n.linewidth=this.linewidth),this.linecap!==void 0&&(n.linecap=this.linecap),this.linejoin!==void 0&&(n.linejoin=this.linejoin),this.dashSize!==void 0&&(n.dashSize=this.dashSize),this.gapSize!==void 0&&(n.gapSize=this.gapSize),this.scale!==void 0&&(n.scale=this.scale),this.wireframe!==void 0&&(n.wireframe=this.wireframe),this.wireframeLinewidth!==void 0&&(n.wireframeLinewidth=this.wireframeLinewidth),this.wireframeLinecap!==void 0&&(n.wireframeLinecap=this.wireframeLinecap),this.wireframeLinejoin!==void 0&&(n.wireframeLinejoin=this.wireframeLinejoin),this.flatShading!==void 0&&(n.flatShading=this.flatShading),this.fog!==void 0&&(n.fog=this.fog),Object.keys(this.userData).length>0&&(n.userData=this.userData);function s(r){let a=[];for(let o in r){let c=r[o];delete c.metadata,a.push(c)}return a}if(e){let r=s(t.textures),a=s(t.images);r.length>0&&(n.textures=r),a.length>0&&(n.images=a)}return n}fromJSON(t,e){if(t.uuid!==void 0&&(this.uuid=t.uuid),t.name!==void 0&&(this.name=t.name),t.color!==void 0&&this.color!==void 0&&this.color.setHex(t.color),t.roughness!==void 0&&(this.roughness=t.roughness),t.metalness!==void 0&&(this.metalness=t.metalness),t.sheen!==void 0&&(this.sheen=t.sheen),t.sheenColor!==void 0&&(this.sheenColor=new se().setHex(t.sheenColor)),t.sheenRoughness!==void 0&&(this.sheenRoughness=t.sheenRoughness),t.emissive!==void 0&&this.emissive!==void 0&&this.emissive.setHex(t.emissive),t.specular!==void 0&&this.specular!==void 0&&this.specular.setHex(t.specular),t.specularIntensity!==void 0&&(this.specularIntensity=t.specularIntensity),t.specularColor!==void 0&&this.specularColor!==void 0&&this.specularColor.setHex(t.specularColor),t.shininess!==void 0&&(this.shininess=t.shininess),t.clearcoat!==void 0&&(this.clearcoat=t.clearcoat),t.clearcoatRoughness!==void 0&&(this.clearcoatRoughness=t.clearcoatRoughness),t.dispersion!==void 0&&(this.dispersion=t.dispersion),t.retroreflectivity!==void 0&&(this.retroreflectivity=t.retroreflectivity),t.iridescence!==void 0&&(this.iridescence=t.iridescence),t.iridescenceIOR!==void 0&&(this.iridescenceIOR=t.iridescenceIOR),t.iridescenceThicknessRange!==void 0&&(this.iridescenceThicknessRange=t.iridescenceThicknessRange),t.transmission!==void 0&&(this.transmission=t.transmission),t.thickness!==void 0&&(this.thickness=t.thickness),t.attenuationDistance!==void 0&&(this.attenuationDistance=t.attenuationDistance),t.attenuationColor!==void 0&&this.attenuationColor!==void 0&&this.attenuationColor.setHex(t.attenuationColor),t.anisotropy!==void 0&&(this.anisotropy=t.anisotropy),t.anisotropyRotation!==void 0&&(this.anisotropyRotation=t.anisotropyRotation),t.fog!==void 0&&(this.fog=t.fog),t.flatShading!==void 0&&(this.flatShading=t.flatShading),t.blending!==void 0&&(this.blending=t.blending),t.combine!==void 0&&(this.combine=t.combine),t.side!==void 0&&(this.side=t.side),t.shadowSide!==void 0&&(this.shadowSide=t.shadowSide),t.opacity!==void 0&&(this.opacity=t.opacity),t.transparent!==void 0&&(this.transparent=t.transparent),t.alphaTest!==void 0&&(this.alphaTest=t.alphaTest),t.alphaHash!==void 0&&(this.alphaHash=t.alphaHash),t.depthFunc!==void 0&&(this.depthFunc=t.depthFunc),t.depthTest!==void 0&&(this.depthTest=t.depthTest),t.depthWrite!==void 0&&(this.depthWrite=t.depthWrite),t.colorWrite!==void 0&&(this.colorWrite=t.colorWrite),t.clippingPlanes!==void 0&&(this.clippingPlanes=t.clippingPlanes.map(n=>new ri().fromJSON(n))),t.clipIntersection!==void 0&&(this.clipIntersection=t.clipIntersection),t.clipShadows!==void 0&&(this.clipShadows=t.clipShadows),t.depthPacking!==void 0&&(this.depthPacking=t.depthPacking),t.blendSrc!==void 0&&(this.blendSrc=t.blendSrc),t.blendDst!==void 0&&(this.blendDst=t.blendDst),t.blendEquation!==void 0&&(this.blendEquation=t.blendEquation),t.blendSrcAlpha!==void 0&&(this.blendSrcAlpha=t.blendSrcAlpha),t.blendDstAlpha!==void 0&&(this.blendDstAlpha=t.blendDstAlpha),t.blendEquationAlpha!==void 0&&(this.blendEquationAlpha=t.blendEquationAlpha),t.blendColor!==void 0&&this.blendColor!==void 0&&this.blendColor.setHex(t.blendColor),t.blendAlpha!==void 0&&(this.blendAlpha=t.blendAlpha),t.stencilWriteMask!==void 0&&(this.stencilWriteMask=t.stencilWriteMask),t.stencilFunc!==void 0&&(this.stencilFunc=t.stencilFunc),t.stencilRef!==void 0&&(this.stencilRef=t.stencilRef),t.stencilFuncMask!==void 0&&(this.stencilFuncMask=t.stencilFuncMask),t.stencilFail!==void 0&&(this.stencilFail=t.stencilFail),t.stencilZFail!==void 0&&(this.stencilZFail=t.stencilZFail),t.stencilZPass!==void 0&&(this.stencilZPass=t.stencilZPass),t.stencilWrite!==void 0&&(this.stencilWrite=t.stencilWrite),t.wireframe!==void 0&&(this.wireframe=t.wireframe),t.wireframeLinewidth!==void 0&&(this.wireframeLinewidth=t.wireframeLinewidth),t.wireframeLinecap!==void 0&&(this.wireframeLinecap=t.wireframeLinecap),t.wireframeLinejoin!==void 0&&(this.wireframeLinejoin=t.wireframeLinejoin),t.rotation!==void 0&&(this.rotation=t.rotation),t.linewidth!==void 0&&(this.linewidth=t.linewidth),t.linecap!==void 0&&(this.linecap=t.linecap),t.linejoin!==void 0&&(this.linejoin=t.linejoin),t.dashSize!==void 0&&(this.dashSize=t.dashSize),t.gapSize!==void 0&&(this.gapSize=t.gapSize),t.scale!==void 0&&(this.scale=t.scale),t.polygonOffset!==void 0&&(this.polygonOffset=t.polygonOffset),t.polygonOffsetFactor!==void 0&&(this.polygonOffsetFactor=t.polygonOffsetFactor),t.polygonOffsetUnits!==void 0&&(this.polygonOffsetUnits=t.polygonOffsetUnits),t.dithering!==void 0&&(this.dithering=t.dithering),t.alphaToCoverage!==void 0&&(this.alphaToCoverage=t.alphaToCoverage),t.premultipliedAlpha!==void 0&&(this.premultipliedAlpha=t.premultipliedAlpha),t.forceSinglePass!==void 0&&(this.forceSinglePass=t.forceSinglePass),t.allowOverride!==void 0&&(this.allowOverride=t.allowOverride),t.visible!==void 0&&(this.visible=t.visible),t.toneMapped!==void 0&&(this.toneMapped=t.toneMapped),t.userData!==void 0&&(this.userData=t.userData),t.vertexColors!==void 0&&(typeof t.vertexColors=="number"?this.vertexColors=t.vertexColors>0:this.vertexColors=t.vertexColors),t.size!==void 0&&(this.size=t.size),t.sizeAttenuation!==void 0&&(this.sizeAttenuation=t.sizeAttenuation),t.map!==void 0&&(this.map=e[t.map]||null),t.matcap!==void 0&&(this.matcap=e[t.matcap]||null),t.alphaMap!==void 0&&(this.alphaMap=e[t.alphaMap]||null),t.bumpMap!==void 0&&(this.bumpMap=e[t.bumpMap]||null),t.bumpScale!==void 0&&(this.bumpScale=t.bumpScale),t.normalMap!==void 0&&(this.normalMap=e[t.normalMap]||null),t.normalMapType!==void 0&&(this.normalMapType=t.normalMapType),t.normalScale!==void 0){let n=t.normalScale;Array.isArray(n)===!1&&(n=[n,n]),this.normalScale=new vt().fromArray(n)}return t.displacementMap!==void 0&&(this.displacementMap=e[t.displacementMap]||null),t.displacementScale!==void 0&&(this.displacementScale=t.displacementScale),t.displacementBias!==void 0&&(this.displacementBias=t.displacementBias),t.roughnessMap!==void 0&&(this.roughnessMap=e[t.roughnessMap]||null),t.metalnessMap!==void 0&&(this.metalnessMap=e[t.metalnessMap]||null),t.emissiveMap!==void 0&&(this.emissiveMap=e[t.emissiveMap]||null),t.emissiveIntensity!==void 0&&(this.emissiveIntensity=t.emissiveIntensity),t.specularMap!==void 0&&(this.specularMap=e[t.specularMap]||null),t.specularIntensityMap!==void 0&&(this.specularIntensityMap=e[t.specularIntensityMap]||null),t.specularColorMap!==void 0&&(this.specularColorMap=e[t.specularColorMap]||null),t.envMap!==void 0&&(this.envMap=e[t.envMap]||null),t.envMapRotation!==void 0&&this.envMapRotation.fromArray(t.envMapRotation),t.envMapIntensity!==void 0&&(this.envMapIntensity=t.envMapIntensity),t.reflectivity!==void 0&&(this.reflectivity=t.reflectivity),t.refractionRatio!==void 0&&(this.refractionRatio=t.refractionRatio),t.lightMap!==void 0&&(this.lightMap=e[t.lightMap]||null),t.lightMapIntensity!==void 0&&(this.lightMapIntensity=t.lightMapIntensity),t.aoMap!==void 0&&(this.aoMap=e[t.aoMap]||null),t.aoMapIntensity!==void 0&&(this.aoMapIntensity=t.aoMapIntensity),t.gradientMap!==void 0&&(this.gradientMap=e[t.gradientMap]||null),t.clearcoatMap!==void 0&&(this.clearcoatMap=e[t.clearcoatMap]||null),t.clearcoatRoughnessMap!==void 0&&(this.clearcoatRoughnessMap=e[t.clearcoatRoughnessMap]||null),t.clearcoatNormalMap!==void 0&&(this.clearcoatNormalMap=e[t.clearcoatNormalMap]||null),t.clearcoatNormalScale!==void 0&&(this.clearcoatNormalScale=new vt().fromArray(t.clearcoatNormalScale)),t.iridescenceMap!==void 0&&(this.iridescenceMap=e[t.iridescenceMap]||null),t.iridescenceThicknessMap!==void 0&&(this.iridescenceThicknessMap=e[t.iridescenceThicknessMap]||null),t.transmissionMap!==void 0&&(this.transmissionMap=e[t.transmissionMap]||null),t.thicknessMap!==void 0&&(this.thicknessMap=e[t.thicknessMap]||null),t.anisotropyMap!==void 0&&(this.anisotropyMap=e[t.anisotropyMap]||null),t.sheenColorMap!==void 0&&(this.sheenColorMap=e[t.sheenColorMap]||null),t.sheenRoughnessMap!==void 0&&(this.sheenRoughnessMap=e[t.sheenRoughnessMap]||null),this}clone(){return new this.constructor().copy(this)}copy(t){this.name=t.name,this.blending=t.blending,this.side=t.side,this.vertexColors=t.vertexColors,this.opacity=t.opacity,this.transparent=t.transparent,this.blendSrc=t.blendSrc,this.blendDst=t.blendDst,this.blendEquation=t.blendEquation,this.blendSrcAlpha=t.blendSrcAlpha,this.blendDstAlpha=t.blendDstAlpha,this.blendEquationAlpha=t.blendEquationAlpha,this.blendColor.copy(t.blendColor),this.blendAlpha=t.blendAlpha,this.depthFunc=t.depthFunc,this.depthTest=t.depthTest,this.depthWrite=t.depthWrite,this.stencilWriteMask=t.stencilWriteMask,this.stencilFunc=t.stencilFunc,this.stencilRef=t.stencilRef,this.stencilFuncMask=t.stencilFuncMask,this.stencilFail=t.stencilFail,this.stencilZFail=t.stencilZFail,this.stencilZPass=t.stencilZPass,this.stencilWrite=t.stencilWrite;let e=t.clippingPlanes,n=null;if(e!==null){let s=e.length;n=new Array(s);for(let r=0;r!==s;++r)n[r]=e[r].clone()}return this.clippingPlanes=n,this.clipIntersection=t.clipIntersection,this.clipShadows=t.clipShadows,this.shadowSide=t.shadowSide,this.colorWrite=t.colorWrite,this.precision=t.precision,this.polygonOffset=t.polygonOffset,this.polygonOffsetFactor=t.polygonOffsetFactor,this.polygonOffsetUnits=t.polygonOffsetUnits,this.dithering=t.dithering,this.alphaTest=t.alphaTest,this.alphaHash=t.alphaHash,this.alphaToCoverage=t.alphaToCoverage,this.premultipliedAlpha=t.premultipliedAlpha,this.forceSinglePass=t.forceSinglePass,this.allowOverride=t.allowOverride,this.visible=t.visible,this.toneMapped=t.toneMapped,this.userData=JSON.parse(JSON.stringify(t.userData)),this}dispose(){this.dispatchEvent({type:"dispose"})}set needsUpdate(t){t===!0&&this.version++}},ki=class extends oi{constructor(t){super(),this.isSpriteMaterial=!0,this.type="SpriteMaterial",this.color=new se(16777215),this.map=null,this.alphaMap=null,this.rotation=0,this.sizeAttenuation=!0,this.transparent=!0,this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.color.copy(t.color),this.map=t.map,this.alphaMap=t.alphaMap,this.rotation=t.rotation,this.sizeAttenuation=t.sizeAttenuation,this.fog=t.fog,this}},Zs,Zr=new D,Js=new D,Ks=new D,js=new vt,Jr=new vt,Pd=new Ce,Ro=new D,Kr=new D,Co=new D,yu=new vt,E0=new vt,Mu=new vt,is=class extends en{constructor(t=new ki){if(super(),this.isSprite=!0,this.type="Sprite",Zs===void 0){Zs=new Ae;let e=new Float32Array([-.5,-.5,0,0,0,.5,-.5,0,1,0,.5,.5,0,1,1,-.5,.5,0,0,1]),n=new da(e,5);Zs.setIndex([0,1,2,0,2,3]),Zs.setAttribute("position",new dr(n,3,0,!1)),Zs.setAttribute("uv",new dr(n,2,3,!1))}this.geometry=Zs,this.material=t,this.center=new vt(.5,.5),this.count=1}intersectsFrustum(t){return t.intersectsSprite(this)}raycast(t,e){t.camera===null&&he('Sprite: "Raycaster.camera" needs to be set in order to raycast against sprites.'),Js.setFromMatrixScale(this.matrixWorld),Pd.copy(t.camera.matrixWorld),this.modelViewMatrix.multiplyMatrices(t.camera.matrixWorldInverse,this.matrixWorld),Ks.setFromMatrixPosition(this.modelViewMatrix),t.camera.isPerspectiveCamera&&this.material.sizeAttenuation===!1&&Js.multiplyScalar(-Ks.z);let n=this.material.rotation,s,r;n!==0&&(r=Math.cos(n),s=Math.sin(n));let a=this.center;Io(Ro.set(-.5,-.5,0),Ks,a,Js,s,r),Io(Kr.set(.5,-.5,0),Ks,a,Js,s,r),Io(Co.set(.5,.5,0),Ks,a,Js,s,r),yu.set(0,0),E0.set(1,0),Mu.set(1,1);let o=t.ray.intersectTriangle(Ro,Kr,Co,!1,Zr);if(o===null&&(Io(Kr.set(-.5,.5,0),Ks,a,Js,s,r),E0.set(0,1),o=t.ray.intersectTriangle(Ro,Co,Kr,!1,Zr),o===null))return;let c=t.ray.origin.distanceTo(Zr);c<t.near||c>t.far||e.push({distance:c,point:Zr.clone(),uv:Fi.getInterpolation(Zr,Ro,Kr,Co,yu,E0,Mu,new vt),face:null,object:this})}copy(t,e){return super.copy(t,e),t.center!==void 0&&this.center.copy(t.center),this.material=t.material,this}};function Io(i,t,e,n,s,r){js.subVectors(i,e).addScalar(.5).multiply(n),s!==void 0?(Jr.x=r*js.x-s*js.y,Jr.y=s*js.x+r*js.y):Jr.copy(js),i.copy(t),i.x+=Jr.x,i.y+=Jr.y,i.applyMatrix4(Pd)}var Po=new D,bu=new D,fa=class extends en{constructor(){super(),this.isLOD=!0,this._currentLevel=0,this.type="LOD",Object.defineProperties(this,{levels:{enumerable:!0,value:[]}}),this.autoUpdate=!0}copy(t){super.copy(t,!1);let e=t.levels;for(let n=0,s=e.length;n<s;n++){let r=e[n];this.addLevel(r.object.clone(),r.distance,r.hysteresis)}return this.autoUpdate=t.autoUpdate,this}addLevel(t,e=0,n=0){e=Math.abs(e);let s=this.levels,r;for(r=0;r<s.length&&!(e<s[r].distance);r++);return s.splice(r,0,{distance:e,hysteresis:n,object:t}),this.add(t),this}removeLevel(t){let e=this.levels;for(let n=0;n<e.length;n++)if(e[n].distance===t){let s=e.splice(n,1);return this.remove(s[0].object),!0}return!1}getCurrentLevel(){return this._currentLevel}getObjectForDistance(t){let e=this.levels;if(e.length>0){let n,s;for(n=1,s=e.length;n<s;n++){let r=e[n].distance;if(e[n].object.visible&&(r-=r*e[n].hysteresis),t<r)break}return e[n-1].object}return null}raycast(t,e){if(this.levels.length>0){Po.setFromMatrixPosition(this.matrixWorld);let s=t.ray.origin.distanceTo(Po);this.getObjectForDistance(s).raycast(t,e)}}update(t){let e=this.levels;if(e.length>1){Po.setFromMatrixPosition(t.matrixWorld),bu.setFromMatrixPosition(this.matrixWorld);let n=Po.distanceTo(bu)/t.zoom;e[0].object.visible=!0;let s,r;for(s=1,r=e.length;s<r;s++){let a=e[s].distance;if(e[s].object.visible&&(a-=a*e[s].hysteresis),n>=a)e[s-1].object.visible=!1,e[s].object.visible=!0;else break}for(this._currentLevel=s-1;s<r;s++)e[s].object.visible=!1}}toJSON(t){let e=super.toJSON(t);e.object.autoUpdate=this.autoUpdate,e.object.levels=[];let n=this.levels;for(let s=0,r=n.length;s<r;s++){let a=n[s];e.object.levels.push({object:a.object.uuid,distance:a.distance,hysteresis:a.hysteresis})}return e}},Ui=new D,w0=new D,Lo=new D,No=new D,Ss=class{constructor(t=new D,e=new D(0,0,-1)){this.origin=t,this.direction=e}set(t,e){return this.origin.copy(t),this.direction.copy(e),this}copy(t){return this.origin.copy(t.origin),this.direction.copy(t.direction),this}at(t,e){return e.copy(this.origin).addScaledVector(this.direction,t)}lookAt(t){return this.direction.copy(t).sub(this.origin).normalize(),this}recast(t){return this.origin.copy(this.at(t,Ui)),this}closestPointToPoint(t,e){e.subVectors(t,this.origin);let n=e.dot(this.direction);return n<0?e.copy(this.origin):e.copy(this.origin).addScaledVector(this.direction,n)}distanceToPoint(t){return Math.sqrt(this.distanceSqToPoint(t))}distanceSqToPoint(t){let e=Ui.subVectors(t,this.origin).dot(this.direction);return e<0?this.origin.distanceToSquared(t):(Ui.copy(this.origin).addScaledVector(this.direction,e),Ui.distanceToSquared(t))}distanceSqToSegment(t,e,n,s){w0.copy(t).add(e).multiplyScalar(.5),Lo.copy(e).sub(t).normalize(),No.copy(this.origin).sub(w0);let r=t.distanceTo(e)*.5,a=-this.direction.dot(Lo),o=No.dot(this.direction),c=-No.dot(Lo),l=No.lengthSq(),h=Math.abs(1-a*a),f,u,d,g;if(h>0)if(f=a*c-o,u=a*o-c,g=r*h,f>=0)if(u>=-g)if(u<=g){let _=1/h;f*=_,u*=_,d=f*(f+a*u+2*o)+u*(a*f+u+2*c)+l}else u=r,f=Math.max(0,-(a*u+o)),d=-f*f+u*(u+2*c)+l;else u=-r,f=Math.max(0,-(a*u+o)),d=-f*f+u*(u+2*c)+l;else u<=-g?(f=Math.max(0,-(-a*r+o)),u=f>0?-r:Math.min(Math.max(-r,-c),r),d=-f*f+u*(u+2*c)+l):u<=g?(f=0,u=Math.min(Math.max(-r,-c),r),d=u*(u+2*c)+l):(f=Math.max(0,-(a*r+o)),u=f>0?r:Math.min(Math.max(-r,-c),r),d=-f*f+u*(u+2*c)+l);else u=a>0?-r:r,f=Math.max(0,-(a*u+o)),d=-f*f+u*(u+2*c)+l;return n&&n.copy(this.origin).addScaledVector(this.direction,f),s&&s.copy(w0).addScaledVector(Lo,u),d}intersectSphere(t,e){if(t.radius<0)return null;Ui.subVectors(t.center,this.origin);let n=Ui.dot(this.direction),s=Ui.dot(Ui)-n*n,r=t.radius*t.radius;if(s>r)return null;let a=Math.sqrt(r-s),o=n-a,c=n+a;return c<0?null:o<0?this.at(c,e):this.at(o,e)}intersectsSphere(t){return t.radius<0?!1:this.distanceSqToPoint(t.center)<=t.radius*t.radius}distanceToPlane(t){let e=t.normal.dot(this.direction);if(e===0)return t.distanceToPoint(this.origin)===0?0:null;let n=-(this.origin.dot(t.normal)+t.constant)/e;return n>=0?n:null}intersectPlane(t,e){let n=this.distanceToPlane(t);return n===null?null:this.at(n,e)}intersectsPlane(t){let e=t.distanceToPoint(this.origin);return e===0||t.normal.dot(this.direction)*e<0}intersectBox(t,e){let n,s,r,a,o,c,l=1/this.direction.x,h=1/this.direction.y,f=1/this.direction.z,u=this.origin;return l>=0?(n=(t.min.x-u.x)*l,s=(t.max.x-u.x)*l):(n=(t.max.x-u.x)*l,s=(t.min.x-u.x)*l),h>=0?(r=(t.min.y-u.y)*h,a=(t.max.y-u.y)*h):(r=(t.max.y-u.y)*h,a=(t.min.y-u.y)*h),n>a||r>s||((r>n||isNaN(n))&&(n=r),(a<s||isNaN(s))&&(s=a),f>=0?(o=(t.min.z-u.z)*f,c=(t.max.z-u.z)*f):(o=(t.max.z-u.z)*f,c=(t.min.z-u.z)*f),n>c||o>s)||((o>n||n!==n)&&(n=o),(c<s||s!==s)&&(s=c),s<0)?null:this.at(n>=0?n:s,e)}intersectsBox(t){return this.intersectBox(t,Ui)!==null}intersectTriangle(t,e,n,s,r){let a=this.origin,o=this.direction,c=o.x,l=o.y,h=o.z,f=t.x-a.x,u=t.y-a.y,d=t.z-a.z,g=e.x-a.x,_=e.y-a.y,m=e.z-a.z,p=n.x-a.x,S=n.y-a.y,w=n.z-a.z,y=Math.abs(c),E=Math.abs(l),M=Math.abs(h),I,v,C,L,N,P,B,F,W,rt,nt,dt;if(y>=E&&y>=M?(C=c,P=f,W=g,dt=p,c>=0?(I=l,v=h,L=u,N=d,B=_,F=m,rt=S,nt=w):(I=h,v=l,L=d,N=u,B=m,F=_,rt=w,nt=S)):E>=M?(C=l,P=u,W=_,dt=S,l>=0?(I=h,v=c,L=d,N=f,B=m,F=g,rt=w,nt=p):(I=c,v=h,L=f,N=d,B=g,F=m,rt=p,nt=w)):(C=h,P=d,W=m,dt=w,h>=0?(I=c,v=l,L=f,N=u,B=g,F=_,rt=p,nt=S):(I=l,v=c,L=u,N=f,B=_,F=g,rt=S,nt=p)),C===0)return null;let Q=I/C,ct=v/C,O=1/C,St=L-Q*P,Et=N-ct*P,At=B-Q*W,Ot=F-ct*W,Dt=rt-Q*dt,tt=nt-ct*dt,it=Dt*Ot-tt*At,_t=St*tt-Et*Dt,bt=At*Et-Ot*St;if(s){if(it<0||_t<0||bt<0)return null}else if((it<0||_t<0||bt<0)&&(it>0||_t>0||bt>0))return null;let mt=it+_t+bt;if(mt===0)return null;let Ct=O*(it*P+_t*W+bt*dt);return(mt>0?Ct<0:Ct>0)?null:this.at(Ct/mt,r)}applyMatrix4(t){return this.origin.applyMatrix4(t),this.direction.transformDirection(t),this}equals(t){return t.origin.equals(this.origin)&&t.direction.equals(this.direction)}clone(){return new this.constructor().copy(this)}},nn=class extends oi{constructor(t){super(),this.isMeshBasicMaterial=!0,this.type="MeshBasicMaterial",this.color=new se(16777215),this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.specularMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new zi,this.combine=K0,this.reflectivity=1,this.refractionRatio=.98,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.color.copy(t.color),this.map=t.map,this.lightMap=t.lightMap,this.lightMapIntensity=t.lightMapIntensity,this.aoMap=t.aoMap,this.aoMapIntensity=t.aoMapIntensity,this.specularMap=t.specularMap,this.alphaMap=t.alphaMap,this.envMap=t.envMap,this.envMapRotation.copy(t.envMapRotation),this.combine=t.combine,this.reflectivity=t.reflectivity,this.refractionRatio=t.refractionRatio,this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this.wireframeLinecap=t.wireframeLinecap,this.wireframeLinejoin=t.wireframeLinejoin,this.fog=t.fog,this}},Su=new Ce,ys=new Ss,Do=new Wn,Eu=new D,Uo=new D,Fo=new D,Oo=new D,T0=new D,Bo=new D,wu=new D,zo=new D,ve=class extends en{constructor(t=new Ae,e=new nn){super(),this.isMesh=!0,this.type="Mesh",this.geometry=t,this.material=e,this.morphTargetDictionary=void 0,this.morphTargetInfluences=void 0,this.count=1,this.updateMorphTargets()}copy(t,e){return super.copy(t,e),t.morphTargetInfluences!==void 0&&(this.morphTargetInfluences=t.morphTargetInfluences.slice()),t.morphTargetDictionary!==void 0&&(this.morphTargetDictionary=Object.assign({},t.morphTargetDictionary)),this.material=Array.isArray(t.material)?t.material.slice():t.material,this.geometry=t.geometry,this}updateMorphTargets(){let e=this.geometry.morphAttributes,n=Object.keys(e);if(n.length>0){let s=e[n[0]];if(s!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let r=0,a=s.length;r<a;r++){let o=s[r].name||String(r);this.morphTargetInfluences.push(0),this.morphTargetDictionary[o]=r}}}}getVertexPosition(t,e){let n=this.geometry,s=n.attributes.position,r=n.morphAttributes.position,a=n.morphTargetsRelative;e.fromBufferAttribute(s,t);let o=this.morphTargetInfluences;if(r&&o){Bo.set(0,0,0);for(let c=0,l=r.length;c<l;c++){let h=o[c],f=r[c];h!==0&&(T0.fromBufferAttribute(f,t),a?Bo.addScaledVector(T0,h):Bo.addScaledVector(T0.sub(e),h))}e.add(Bo)}return e}intersectsFrustum(t){return t.intersectsObject(this)}raycast(t,e){let n=this.geometry,s=this.material,r=this.matrixWorld;s!==void 0&&(n.boundingSphere===null&&n.computeBoundingSphere(),Do.copy(n.boundingSphere),Do.applyMatrix4(r),ys.copy(t.ray).recast(t.near),!(Do.containsPoint(ys.origin)===!1&&(ys.intersectSphere(Do,Eu)===null||ys.origin.distanceToSquared(Eu)>(t.far-t.near)**2))&&(Su.copy(r).invert(),ys.copy(t.ray).applyMatrix4(Su),!(n.boundingBox!==null&&ys.intersectsBox(n.boundingBox)===!1)&&this._computeIntersections(t,e,ys)))}_computeIntersections(t,e,n){let s,r=this.geometry,a=this.material,o=r.index,c=r.attributes.position,l=r.attributes.uv,h=r.attributes.uv1,f=r.attributes.normal,u=r.groups,d=r.drawRange;if(o!==null)if(Array.isArray(a))for(let g=0,_=u.length;g<_;g++){let m=u[g],p=a[m.materialIndex],S=Math.max(m.start,d.start),w=Math.min(o.count,Math.min(m.start+m.count,d.start+d.count));for(let y=S,E=w;y<E;y+=3){let M=o.getX(y),I=o.getX(y+1),v=o.getX(y+2);s=ko(this,p,t,n,l,h,f,M,I,v),s&&(s.faceIndex=Math.floor(y/3),s.face.materialIndex=m.materialIndex,e.push(s))}}else{let g=Math.max(0,d.start),_=Math.min(o.count,d.start+d.count);for(let m=g,p=_;m<p;m+=3){let S=o.getX(m),w=o.getX(m+1),y=o.getX(m+2);s=ko(this,a,t,n,l,h,f,S,w,y),s&&(s.faceIndex=Math.floor(m/3),e.push(s))}}else if(c!==void 0)if(Array.isArray(a))for(let g=0,_=u.length;g<_;g++){let m=u[g],p=a[m.materialIndex],S=Math.max(m.start,d.start),w=Math.min(c.count,Math.min(m.start+m.count,d.start+d.count));for(let y=S,E=w;y<E;y+=3){let M=y,I=y+1,v=y+2;s=ko(this,p,t,n,l,h,f,M,I,v),s&&(s.faceIndex=Math.floor(y/3),s.face.materialIndex=m.materialIndex,e.push(s))}}else{let g=Math.max(0,d.start),_=Math.min(c.count,d.start+d.count);for(let m=g,p=_;m<p;m+=3){let S=m,w=m+1,y=m+2;s=ko(this,a,t,n,l,h,f,S,w,y),s&&(s.faceIndex=Math.floor(m/3),e.push(s))}}}};function wp(i,t,e,n,s,r,a,o){let c;if(t.side===bn?c=n.intersectTriangle(a,r,s,!0,o):c=n.intersectTriangle(s,r,a,t.side===hs,o),c===null)return null;zo.copy(o),zo.applyMatrix4(i.matrixWorld);let l=e.ray.origin.distanceTo(zo);return l<e.near||l>e.far?null:{distance:l,point:zo.clone(),object:i}}function ko(i,t,e,n,s,r,a,o,c,l){i.getVertexPosition(o,Uo),i.getVertexPosition(c,Fo),i.getVertexPosition(l,Oo);let h=wp(i,t,e,n,Uo,Fo,Oo,wu);if(h){let f=new D;Fi.getBarycoord(wu,Uo,Fo,Oo,f),s&&(h.uv=Fi.getInterpolatedAttribute(s,o,c,l,f,new vt)),r&&(h.uv1=Fi.getInterpolatedAttribute(r,o,c,l,f,new vt)),a&&(h.normal=Fi.getInterpolatedAttribute(a,o,c,l,f,new D),h.normal.dot(n.direction)>0&&h.normal.multiplyScalar(-1));let u={a:o,b:c,c:l,normal:new D,materialIndex:0};Fi.getNormal(Uo,Fo,Oo,u.normal),h.face=u,h.barycoord=f}return h}var pa=class extends gn{constructor(t=null,e=1,n=1,s,r,a,o,c,l=mn,h=mn,f,u){super(null,a,o,c,l,h,s,r,f,u),this.isDataTexture=!0,this.image={data:t,width:e,height:n},this.generateMipmaps=!1,this.flipY=!1,this.unpackAlignment=1}};var fr=class extends tn{constructor(t,e,n,s=1){super(t,e,n),this.isInstancedBufferAttribute=!0,this.meshPerAttribute=s}copy(t){return super.copy(t),this.meshPerAttribute=t.meshPerAttribute,this}toJSON(){let t=super.toJSON();return t.meshPerAttribute=this.meshPerAttribute,t.isInstancedBufferAttribute=!0,t}},Qs=new Ce,Tu=new Ce,Ho=[],Au=new bi,Tp=new Ce,jr=new ve,Qr=new Wn,ma=class extends ve{constructor(t,e,n){super(t,e),this.isInstancedMesh=!0,this.instanceMatrix=new fr(new Float32Array(n*16),16),this.instanceColor=null,this.morphTexture=null,this.count=n,this.boundingBox=null,this.boundingSphere=null;for(let s=0;s<n;s++)this.setMatrixAt(s,Tp)}computeBoundingBox(){let t=this.geometry,e=this.count;this.boundingBox===null&&(this.boundingBox=new bi),t.boundingBox===null&&t.computeBoundingBox(),this.boundingBox.makeEmpty();for(let n=0;n<e;n++)this.getMatrixAt(n,Qs),Au.copy(t.boundingBox).applyMatrix4(Qs),this.boundingBox.union(Au)}computeBoundingSphere(){let t=this.geometry,e=this.count;this.boundingSphere===null&&(this.boundingSphere=new Wn),t.boundingSphere===null&&t.computeBoundingSphere(),this.boundingSphere.makeEmpty();for(let n=0;n<e;n++)this.getMatrixAt(n,Qs),Qr.copy(t.boundingSphere).applyMatrix4(Qs),this.boundingSphere.union(Qr)}copy(t,e){return super.copy(t,e),this.instanceMatrix.copy(t.instanceMatrix),t.morphTexture!==null&&(this.morphTexture=t.morphTexture.clone()),t.instanceColor!==null&&(this.instanceColor=t.instanceColor.clone()),this.count=t.count,t.boundingBox!==null&&(this.boundingBox=t.boundingBox.clone()),t.boundingSphere!==null&&(this.boundingSphere=t.boundingSphere.clone()),this}getColorAt(t,e){return this.instanceColor===null?e.setRGB(1,1,1):e.fromArray(this.instanceColor.array,t*3)}getMatrixAt(t,e){return e.fromArray(this.instanceMatrix.array,t*16)}getMorphAt(t,e){let n=e.morphTargetInfluences,s=this.morphTexture.source.data.data,r=n.length+1,a=t*r+1;for(let o=0;o<n.length;o++)n[o]=s[a+o]}raycast(t,e){let n=this.matrixWorld,s=this.count;if(jr.geometry=this.geometry,jr.material=this.material,jr.material!==void 0&&(this.boundingSphere===null&&this.computeBoundingSphere(),Qr.copy(this.boundingSphere),Qr.applyMatrix4(n),t.ray.intersectsSphere(Qr)!==!1))for(let r=0;r<s;r++){this.getMatrixAt(r,Qs),Tu.multiplyMatrices(n,Qs),jr.matrixWorld=Tu,jr.raycast(t,Ho);for(let a=0,o=Ho.length;a<o;a++){let c=Ho[a];c.instanceId=r,c.object=this,e.push(c)}Ho.length=0}}setColorAt(t,e){return this.instanceColor===null&&(this.instanceColor=new fr(new Float32Array(this.instanceMatrix.count*3).fill(1),3)),e.toArray(this.instanceColor.array,t*3),this}setMatrixAt(t,e){return e.toArray(this.instanceMatrix.array,t*16),this}setMorphAt(t,e){let n=e.morphTargetInfluences,s=n.length+1;this.morphTexture===null&&(this.morphTexture=new pa(new Float32Array(s*this.count),s,this.count,Hl,Yn));let r=this.morphTexture.source.data.data,a=0;for(let l=0;l<n.length;l++)a+=n[l];let o=this.geometry.morphTargetsRelative?1:1-a,c=s*t;return r[c]=o,r.set(n,c+1),this}updateMorphTargets(){}dispose(){super.dispose(),this.morphTexture!==null&&(this.morphTexture.dispose(),this.morphTexture=null)}},Ms=new Wn,Ap=new vt(.5,.5),Vo=new D,pr=class{constructor(t=new ri,e=new ri,n=new ri,s=new ri,r=new ri,a=new ri){this.planes=[t,e,n,s,r,a]}set(t,e,n,s,r,a){let o=this.planes;return o[0].copy(t),o[1].copy(e),o[2].copy(n),o[3].copy(s),o[4].copy(r),o[5].copy(a),this}copy(t){let e=this.planes;for(let n=0;n<6;n++)e[n].copy(t.planes[n]);return this}setFromProjectionMatrix(t,e=ai,n=!1){let s=this.planes,r=t.elements,a=r[0],o=r[1],c=r[2],l=r[3],h=r[4],f=r[5],u=r[6],d=r[7],g=r[8],_=r[9],m=r[10],p=r[11],S=r[12],w=r[13],y=r[14],E=r[15];if(s[0].setComponents(l-a,d-h,p-g,E-S).normalize(),s[1].setComponents(l+a,d+h,p+g,E+S).normalize(),s[2].setComponents(l+o,d+f,p+_,E+w).normalize(),s[3].setComponents(l-o,d-f,p-_,E-w).normalize(),n)s[4].setComponents(c,u,m,y).normalize(),s[5].setComponents(l-c,d-u,p-m,E-y).normalize();else if(s[4].setComponents(l-c,d-u,p-m,E-y).normalize(),e===ai)s[5].setComponents(l+c,d+u,p+m,E+y).normalize();else if(e===ar)s[5].setComponents(c,u,m,y).normalize();else throw new Error("THREE.Frustum.setFromProjectionMatrix(): Invalid coordinate system: "+e);return this}intersectsObject(t){if(t.boundingSphere!==void 0)t.boundingSphere===null&&t.computeBoundingSphere(),Ms.copy(t.boundingSphere).applyMatrix4(t.matrixWorld);else{let e=t.geometry;e.boundingSphere===null&&e.computeBoundingSphere(),Ms.copy(e.boundingSphere).applyMatrix4(t.matrixWorld)}return this.intersectsSphere(Ms)}intersectsSprite(t){Ms.center.set(0,0,0);let e=Ap.distanceTo(t.center);return Ms.radius=.7071067811865476+e,Ms.applyMatrix4(t.matrixWorld),this.intersectsSphere(Ms)}intersectsSphere(t){let e=this.planes,n=t.center,s=-t.radius;for(let r=0;r<6;r++)if(e[r].distanceToPoint(n)<s)return!1;return!0}intersectsBox(t){let e=this.planes;for(let n=0;n<6;n++){let s=e[n];if(Vo.x=s.normal.x>0?t.max.x:t.min.x,Vo.y=s.normal.y>0?t.max.y:t.min.y,Vo.z=s.normal.z>0?t.max.z:t.min.z,s.distanceToPoint(Vo)<0)return!1}return!0}containsPoint(t){let e=this.planes;for(let n=0;n<6;n++)if(e[n].distanceToPoint(t)<0)return!1;return!0}clone(){return new this.constructor().copy(this)}};var li=class extends oi{constructor(t){super(),this.isLineBasicMaterial=!0,this.type="LineBasicMaterial",this.color=new se(16777215),this.map=null,this.linewidth=1,this.linecap="round",this.linejoin="round",this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.color.copy(t.color),this.map=t.map,this.linewidth=t.linewidth,this.linecap=t.linecap,this.linejoin=t.linejoin,this.fog=t.fog,this}},fl=new D,pl=new D,Ru=new Ce,ta=new Ss,Go=new Wn,A0=new D,Cu=new D,Hi=class extends en{constructor(t=new Ae,e=new li){super(),this.isLine=!0,this.type="Line",this.geometry=t,this.material=e,this.morphTargetDictionary=void 0,this.morphTargetInfluences=void 0,this.updateMorphTargets()}copy(t,e){return super.copy(t,e),this.material=Array.isArray(t.material)?t.material.slice():t.material,this.geometry=t.geometry,this}computeLineDistances(){let t=this.geometry;if(t.index===null){let e=t.attributes.position,n=[0];for(let s=1,r=e.count;s<r;s++)fl.fromBufferAttribute(e,s-1),pl.fromBufferAttribute(e,s),n[s]=n[s-1],n[s]+=fl.distanceTo(pl);t.setAttribute("lineDistance",new fe(n,1))}else ue("Line.computeLineDistances(): Computation only possible with non-indexed BufferGeometry.");return this}intersectsFrustum(t){return t.intersectsObject(this)}raycast(t,e){let n=this.geometry,s=this.matrixWorld,r=t.params.Line.threshold,a=n.drawRange;if(n.boundingSphere===null&&n.computeBoundingSphere(),Go.copy(n.boundingSphere),Go.applyMatrix4(s),Go.radius+=r,t.ray.intersectsSphere(Go)===!1)return;Ru.copy(s).invert(),ta.copy(t.ray).applyMatrix4(Ru);let o=r/((this.scale.x+this.scale.y+this.scale.z)/3),c=o*o,l=this.isLineSegments?2:1,h=n.index,u=n.attributes.position;if(h!==null){let d=Math.max(0,a.start),g=Math.min(h.count,a.start+a.count);for(let _=d,m=g-1;_<m;_+=l){let p=h.getX(_),S=h.getX(_+1),w=Wo(this,t,ta,c,p,S,_);w&&e.push(w)}if(this.isLineLoop){let _=h.getX(g-1),m=h.getX(d),p=Wo(this,t,ta,c,_,m,g-1);p&&e.push(p)}}else{let d=Math.max(0,a.start),g=Math.min(u.count,a.start+a.count);for(let _=d,m=g-1;_<m;_+=l){let p=Wo(this,t,ta,c,_,_+1,_);p&&e.push(p)}if(this.isLineLoop){let _=Wo(this,t,ta,c,g-1,d,g-1);_&&e.push(_)}}}updateMorphTargets(){let e=this.geometry.morphAttributes,n=Object.keys(e);if(n.length>0){let s=e[n[0]];if(s!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let r=0,a=s.length;r<a;r++){let o=s[r].name||String(r);this.morphTargetInfluences.push(0),this.morphTargetDictionary[o]=r}}}}};function Wo(i,t,e,n,s,r,a){let o=i.geometry.attributes.position;if(fl.fromBufferAttribute(o,s),pl.fromBufferAttribute(o,r),e.distanceSqToSegment(fl,pl,A0,Cu)>n)return;A0.applyMatrix4(i.matrixWorld);let l=t.ray.origin.distanceTo(A0);if(!(l<t.near||l>t.far))return{distance:l,point:Cu.clone().applyMatrix4(i.matrixWorld),index:a,face:null,faceIndex:null,barycoord:null,object:i}}var ml=class extends oi{constructor(t){super(),this.isPointsMaterial=!0,this.type="PointsMaterial",this.color=new se(16777215),this.map=null,this.alphaMap=null,this.size=1,this.sizeAttenuation=!0,this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.color.copy(t.color),this.map=t.map,this.alphaMap=t.alphaMap,this.size=t.size,this.sizeAttenuation=t.sizeAttenuation,this.fog=t.fog,this}},Iu=new Ce,O0=new Ss,Xo=new Wn,$o=new D,ga=class extends en{constructor(t=new Ae,e=new ml){super(),this.isPoints=!0,this.type="Points",this.geometry=t,this.material=e,this.morphTargetDictionary=void 0,this.morphTargetInfluences=void 0,this.updateMorphTargets()}copy(t,e){return super.copy(t,e),this.material=Array.isArray(t.material)?t.material.slice():t.material,this.geometry=t.geometry,this}intersectsFrustum(t){return t.intersectsObject(this)}raycast(t,e){let n=this.geometry,s=this.matrixWorld,r=t.params.Points.threshold,a=n.drawRange;if(n.boundingSphere===null&&n.computeBoundingSphere(),Xo.copy(n.boundingSphere),Xo.applyMatrix4(s),Xo.radius+=r,t.ray.intersectsSphere(Xo)===!1)return;Iu.copy(s).invert(),O0.copy(t.ray).applyMatrix4(Iu);let o=r/((this.scale.x+this.scale.y+this.scale.z)/3),c=o*o,l=n.index,f=n.attributes.position;if(l!==null){let u=Math.max(0,a.start),d=Math.min(l.count,a.start+a.count);for(let g=u,_=d;g<_;g++){let m=l.getX(g);$o.fromBufferAttribute(f,m),Pu($o,m,c,s,t,e,this)}}else{let u=Math.max(0,a.start),d=Math.min(f.count,a.start+a.count);for(let g=u,_=d;g<_;g++)$o.fromBufferAttribute(f,g),Pu($o,g,c,s,t,e,this)}}updateMorphTargets(){let e=this.geometry.morphAttributes,n=Object.keys(e);if(n.length>0){let s=e[n[0]];if(s!==void 0){this.morphTargetInfluences=[],this.morphTargetDictionary={};for(let r=0,a=s.length;r<a;r++){let o=s[r].name||String(r);this.morphTargetInfluences.push(0),this.morphTargetDictionary[o]=r}}}}};function Pu(i,t,e,n,s,r,a){let o=O0.distanceSqToPoint(i);if(o<e){let c=new D;O0.closestPointToPoint(i,c),c.applyMatrix4(n);let l=s.ray.origin.distanceTo(c);if(l<s.near||l>s.far)return;r.push({distance:l,distanceToRay:Math.sqrt(o),point:c,index:t,face:null,faceIndex:null,barycoord:null,object:a})}}var xa=class extends gn{constructor(t=[],e=ds,n,s,r,a,o,c,l,h){super(t,e,n,s,r,a,o,c,l,h),this.isCubeTexture=!0,this.flipY=!1}get images(){return this.image}set images(t){this.image=t}},Xn=class extends gn{constructor(t,e,n,s,r,a,o,c,l){super(t,e,n,s,r,a,o,c,l),this.isCanvasTexture=!0,this.needsUpdate=!0}};var ss=class extends gn{constructor(t,e,n=hi,s,r,a,o=mn,c=mn,l,h=vi,f=1){if(h!==vi&&h!==fs)throw new Error("THREE.DepthTexture: format must be either THREE.DepthFormat or THREE.DepthStencilFormat");let u={width:t,height:e,depth:f};super(u,s,r,a,o,c,h,n,l),this.isDepthTexture=!0,this.flipY=!1,this.generateMipmaps=!1,this.compareFunction=null}copy(t){return super.copy(t),this.source=new cr(Object.assign({},t.image)),this.compareFunction=t.compareFunction,this}toJSON(t){let e=super.toJSON(t);return e.compareFunction=this.compareFunction,e}},gl=class extends ss{constructor(t,e=hi,n=ds,s,r,a=mn,o=mn,c,l=vi){let h={width:t,height:t,depth:1},f=[h,h,h,h,h,h];super(t,t,e,n,s,r,a,o,c,l),this.image=f,this.isCubeDepthTexture=!0,this.isCubeTexture=!0}get images(){return this.image}set images(t){this.image=t}},_a=class extends gn{constructor(t=null){super(),this.sourceTexture=t,this.isExternalTexture=!0}copy(t){return super.copy(t),this.sourceTexture=t.sourceTexture,this}},mr=class i extends Ae{constructor(t=1,e=1,n=1,s=1,r=1,a=1){super(),this.type="BoxGeometry",this.parameters={width:t,height:e,depth:n,widthSegments:s,heightSegments:r,depthSegments:a};let o=this;s=Math.floor(s),r=Math.floor(r),a=Math.floor(a);let c=[],l=[],h=[],f=[],u=0,d=0;g("z","y","x",-1,-1,n,e,t,a,r,0),g("z","y","x",1,-1,n,e,-t,a,r,1),g("x","z","y",1,1,t,n,e,s,a,2),g("x","z","y",1,-1,t,n,-e,s,a,3),g("x","y","z",1,-1,t,e,n,s,r,4),g("x","y","z",-1,-1,t,e,-n,s,r,5),this.setIndex(c),this.setAttribute("position",new fe(l,3)),this.setAttribute("normal",new fe(h,3)),this.setAttribute("uv",new fe(f,2));function g(_,m,p,S,w,y,E,M,I,v,C){let L=y/I,N=E/v,P=y/2,B=E/2,F=M/2,W=I+1,rt=v+1,nt=0,dt=0,Q=new D;for(let ct=0;ct<rt;ct++){let O=ct*N-B;for(let St=0;St<W;St++){let Et=St*L-P;Q[_]=Et*S,Q[m]=O*w,Q[p]=F,l.push(Q.x,Q.y,Q.z),Q[_]=0,Q[m]=0,Q[p]=M>0?1:-1,h.push(Q.x,Q.y,Q.z),f.push(St/I),f.push(1-ct/v),nt+=1}}for(let ct=0;ct<v;ct++)for(let O=0;O<I;O++){let St=u+O+W*ct,Et=u+O+W*(ct+1),At=u+(O+1)+W*(ct+1),Ot=u+(O+1)+W*ct;c.push(St,Et,Ot),c.push(Et,At,Ot),dt+=6}o.addGroup(d,dt,C),d+=dt,u+=nt}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.width,t.height,t.depth,t.widthSegments,t.heightSegments,t.depthSegments)}};var va=class i extends Ae{constructor(t=1,e=32,n=0,s=Math.PI*2){super(),this.type="CircleGeometry",this.parameters={radius:t,segments:e,thetaStart:n,thetaLength:s},e=Math.max(3,e);let r=[],a=[],o=[],c=[],l=new D,h=new vt;a.push(0,0,0),o.push(0,0,1),c.push(.5,.5);for(let f=0,u=3;f<=e;f++,u+=3){let d=n+f/e*s;l.x=t*Math.cos(d),l.y=t*Math.sin(d),a.push(l.x,l.y,l.z),o.push(0,0,1),h.x=(a[u]/t+1)/2,h.y=(a[u+1]/t+1)/2,c.push(h.x,h.y)}for(let f=1;f<=e;f++)r.push(f,f+1,0);this.setIndex(r),this.setAttribute("position",new fe(a,3)),this.setAttribute("normal",new fe(o,3)),this.setAttribute("uv",new fe(c,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.radius,t.segments,t.thetaStart,t.thetaLength)}},Vi=class i extends Ae{constructor(t=1,e=1,n=1,s=32,r=1,a=!1,o=0,c=Math.PI*2){super(),this.type="CylinderGeometry",this.parameters={radiusTop:t,radiusBottom:e,height:n,radialSegments:s,heightSegments:r,openEnded:a,thetaStart:o,thetaLength:c};let l=this;s=Math.floor(s),r=Math.floor(r);let h=[],f=[],u=[],d=[],g=0,_=[],m=n/2,p=0;S(),a===!1&&(t>0&&w(!0),e>0&&w(!1)),this.setIndex(h),this.setAttribute("position",new fe(f,3)),this.setAttribute("normal",new fe(u,3)),this.setAttribute("uv",new fe(d,2));function S(){let y=new D,E=new D,M=0,I=(e-t)/n;for(let v=0;v<=r;v++){let C=[],L=v/r,N=L*(e-t)+t;for(let P=0;P<=s;P++){let B=P/s,F=B*c+o,W=Math.sin(F),rt=Math.cos(F);E.x=N*W,E.y=-L*n+m,E.z=N*rt,f.push(E.x,E.y,E.z),y.set(W,I,rt).normalize(),u.push(y.x,y.y,y.z),d.push(B,1-L),C.push(g++)}_.push(C)}for(let v=0;v<s;v++)for(let C=0;C<r;C++){let L=_[C][v],N=_[C+1][v],P=_[C+1][v+1],B=_[C][v+1];(t>0||C!==0)&&(h.push(L,N,B),M+=3),(e>0||C!==r-1)&&(h.push(N,P,B),M+=3)}l.addGroup(p,M,0),p+=M}function w(y){let E=g,M=new vt,I=new D,v=0,C=y===!0?t:e,L=y===!0?1:-1;for(let P=1;P<=s;P++)f.push(0,m*L,0),u.push(0,L,0),d.push(.5,.5),g++;let N=g;for(let P=0;P<=s;P++){let F=P/s*c+o,W=Math.cos(F),rt=Math.sin(F);I.x=C*rt,I.y=m*L,I.z=C*W,f.push(I.x,I.y,I.z),u.push(0,L,0),M.x=W*.5+.5,M.y=rt*.5*L+.5,d.push(M.x,M.y),g++}for(let P=0;P<s;P++){let B=E+P,F=N+P;y===!0?h.push(F,F+1,B):h.push(F+1,F,B),v+=3}l.addGroup(p,v,y===!0?1:2),p+=v}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.radiusTop,t.radiusBottom,t.height,t.radialSegments,t.heightSegments,t.openEnded,t.thetaStart,t.thetaLength)}},ya=class i extends Vi{constructor(t=1,e=1,n=32,s=1,r=!1,a=0,o=Math.PI*2){super(0,t,e,n,s,r,a,o),this.type="ConeGeometry",this.parameters={radius:t,height:e,radialSegments:n,heightSegments:s,openEnded:r,thetaStart:a,thetaLength:o}}static fromJSON(t){return new i(t.radius,t.height,t.radialSegments,t.heightSegments,t.openEnded,t.thetaStart,t.thetaLength)}};var Bn=class{constructor(){this.type="Curve",this.arcLengthDivisions=200,this.needsUpdate=!1,this.cacheArcLengths=null}getPoint(){ue("Curve: .getPoint() not implemented.")}getPointAt(t,e){let n=this.getUtoTmapping(t);return this.getPoint(n,e)}getPoints(t=5){let e=[];for(let n=0;n<=t;n++)e.push(this.getPoint(n/t));return e}getSpacedPoints(t=5){let e=[];for(let n=0;n<=t;n++)e.push(this.getPointAt(n/t));return e}getLength(){let t=this.getLengths();return t[t.length-1]}getLengths(t=this.arcLengthDivisions){if(this.cacheArcLengths&&this.cacheArcLengths.length===t+1&&!this.needsUpdate)return this.cacheArcLengths;this.needsUpdate=!1;let e=[],n,s=this.getPoint(0),r=0;e.push(0);for(let a=1;a<=t;a++)n=this.getPoint(a/t),r+=n.distanceTo(s),e.push(r),s=n;return this.cacheArcLengths=e,e}updateArcLengths(){this.needsUpdate=!0,this.getLengths()}getUtoTmapping(t,e=null){let n=this.getLengths(),s=0,r=n.length,a;e?a=e:a=t*n[r-1];let o=0,c=r-1,l;for(;o<=c;)if(s=Math.floor(o+(c-o)/2),l=n[s]-a,l<0)o=s+1;else if(l>0)c=s-1;else{c=s;break}if(s=c,n[s]===a)return s/(r-1);let h=n[s],u=n[s+1]-h,d=(a-h)/u;return(s+d)/(r-1)}getTangent(t,e){let s=t-1e-4,r=t+1e-4;s<0&&(s=0),r>1&&(r=1);let a=this.getPoint(s),o=this.getPoint(r),c=e||(a.isVector2?new vt:new D);return c.copy(o).sub(a).normalize(),c}getTangentAt(t,e){let n=this.getUtoTmapping(t);return this.getTangent(n,e)}computeFrenetFrames(t,e=!1){let n=new D,s=[],r=[],a=[],o=new D,c=new Ce;for(let d=0;d<=t;d++){let g=d/t;s[d]=this.getTangentAt(g,new D)}r[0]=new D,a[0]=new D;let l=Number.MAX_VALUE,h=Math.abs(s[0].x),f=Math.abs(s[0].y),u=Math.abs(s[0].z);h<=l&&(l=h,n.set(1,0,0)),f<=l&&(l=f,n.set(0,1,0)),u<=l&&n.set(0,0,1),o.crossVectors(s[0],n).normalize(),r[0].crossVectors(s[0],o),a[0].crossVectors(s[0],r[0]);for(let d=1;d<=t;d++){if(r[d]=r[d-1].clone(),a[d]=a[d-1].clone(),o.crossVectors(s[d-1],s[d]),o.length()>Number.EPSILON){o.normalize();let g=Math.acos(be(s[d-1].dot(s[d]),-1,1));r[d].applyMatrix4(c.makeRotationAxis(o,g))}a[d].crossVectors(s[d],r[d])}if(e===!0){let d=Math.acos(be(r[0].dot(r[t]),-1,1));d/=t,s[0].dot(o.crossVectors(r[0],r[t]))>0&&(d=-d);for(let g=1;g<=t;g++)r[g].applyMatrix4(c.makeRotationAxis(s[g],d*g)),a[g].crossVectors(s[g],r[g])}return{tangents:s,normals:r,binormals:a}}clone(){return new this.constructor().copy(this)}copy(t){return this.arcLengthDivisions=t.arcLengthDivisions,this}toJSON(){let t={metadata:{version:4.7,type:"Curve",generator:"Curve.toJSON"}};return t.arcLengthDivisions=this.arcLengthDivisions,t.type=this.type,t}fromJSON(t){return this.arcLengthDivisions=t.arcLengthDivisions,this}},gr=class extends Bn{constructor(t=0,e=0,n=1,s=1,r=0,a=Math.PI*2,o=!1,c=0){super(),this.isEllipseCurve=!0,this.type="EllipseCurve",this.aX=t,this.aY=e,this.xRadius=n,this.yRadius=s,this.aStartAngle=r,this.aEndAngle=a,this.aClockwise=o,this.aRotation=c}getPoint(t,e=new vt){let n=e,s=Math.PI*2,r=this.aEndAngle-this.aStartAngle,a=Math.abs(r)<Number.EPSILON;for(;r<0;)r+=s;for(;r>s;)r-=s;r<Number.EPSILON&&(a?r=0:r=s),this.aClockwise===!0&&!a&&(r===s?r=-s:r=r-s);let o=this.aStartAngle+t*r,c=this.aX+this.xRadius*Math.cos(o),l=this.aY+this.yRadius*Math.sin(o);if(this.aRotation!==0){let h=Math.cos(this.aRotation),f=Math.sin(this.aRotation),u=c-this.aX,d=l-this.aY;c=u*h-d*f+this.aX,l=u*f+d*h+this.aY}return n.set(c,l)}copy(t){return super.copy(t),this.aX=t.aX,this.aY=t.aY,this.xRadius=t.xRadius,this.yRadius=t.yRadius,this.aStartAngle=t.aStartAngle,this.aEndAngle=t.aEndAngle,this.aClockwise=t.aClockwise,this.aRotation=t.aRotation,this}toJSON(){let t=super.toJSON();return t.aX=this.aX,t.aY=this.aY,t.xRadius=this.xRadius,t.yRadius=this.yRadius,t.aStartAngle=this.aStartAngle,t.aEndAngle=this.aEndAngle,t.aClockwise=this.aClockwise,t.aRotation=this.aRotation,t}fromJSON(t){return super.fromJSON(t),this.aX=t.aX,this.aY=t.aY,this.xRadius=t.xRadius,this.yRadius=t.yRadius,this.aStartAngle=t.aStartAngle,this.aEndAngle=t.aEndAngle,this.aClockwise=t.aClockwise,this.aRotation=t.aRotation,this}},xl=class extends gr{constructor(t,e,n,s,r,a){super(t,e,n,n,s,r,a),this.isArcCurve=!0,this.type="ArcCurve"}};function oh(){let i=0,t=0,e=0,n=0;function s(r,a,o,c){i=r,t=o,e=-3*r+3*a-2*o-c,n=2*r-2*a+o+c}return{initCatmullRom:function(r,a,o,c,l){s(a,o,l*(o-r),l*(c-a))},initNonuniformCatmullRom:function(r,a,o,c,l,h,f){let u=(a-r)/l-(o-r)/(l+h)+(o-a)/h,d=(o-a)/h-(c-a)/(h+f)+(c-o)/f;u*=h,d*=h,s(a,o,u,d)},calc:function(r){let a=r*r,o=a*r;return i+t*r+e*a+n*o}}}var Lu=new D,Nu=new D,R0=new oh,C0=new oh,I0=new oh,xr=class extends Bn{constructor(t=[],e=!1,n="centripetal",s=.5){super(),this.isCatmullRomCurve3=!0,this.type="CatmullRomCurve3",this.points=t,this.closed=e,this.curveType=n,this.tension=s}getPoint(t,e=new D){let n=e,s=this.points,r=s.length,a=(r-(this.closed?0:1))*t,o=Math.floor(a),c=a-o;this.closed?o+=o>0?0:(Math.floor(Math.abs(o)/r)+1)*r:c===0&&o===r-1&&(o=r-2,c=1);let l,h;this.closed||o>0?l=s[(o-1)%r]:(Nu.subVectors(s[0],s[1]).add(s[0]),l=Nu);let f=s[o%r],u=s[(o+1)%r];if(this.closed||o+2<r?h=s[(o+2)%r]:(Lu.subVectors(s[r-1],s[r-2]).add(s[r-1]),h=Lu),this.curveType==="centripetal"||this.curveType==="chordal"){let d=this.curveType==="chordal"?.5:.25,g=Math.pow(l.distanceToSquared(f),d),_=Math.pow(f.distanceToSquared(u),d),m=Math.pow(u.distanceToSquared(h),d);_<1e-4&&(_=1),g<1e-4&&(g=_),m<1e-4&&(m=_),R0.initNonuniformCatmullRom(l.x,f.x,u.x,h.x,g,_,m),C0.initNonuniformCatmullRom(l.y,f.y,u.y,h.y,g,_,m),I0.initNonuniformCatmullRom(l.z,f.z,u.z,h.z,g,_,m)}else this.curveType==="catmullrom"&&(R0.initCatmullRom(l.x,f.x,u.x,h.x,this.tension),C0.initCatmullRom(l.y,f.y,u.y,h.y,this.tension),I0.initCatmullRom(l.z,f.z,u.z,h.z,this.tension));return n.set(R0.calc(c),C0.calc(c),I0.calc(c)),n}copy(t){super.copy(t),this.points=[];for(let e=0,n=t.points.length;e<n;e++){let s=t.points[e];this.points.push(s.clone())}return this.closed=t.closed,this.curveType=t.curveType,this.tension=t.tension,this}toJSON(){let t=super.toJSON();t.points=[];for(let e=0,n=this.points.length;e<n;e++){let s=this.points[e];t.points.push(s.toArray())}return t.closed=this.closed,t.curveType=this.curveType,t.tension=this.tension,t}fromJSON(t){super.fromJSON(t),this.points=[];for(let e=0,n=t.points.length;e<n;e++){let s=t.points[e];this.points.push(new D().fromArray(s))}return this.closed=t.closed,this.curveType=t.curveType,this.tension=t.tension,this}};function Du(i,t,e,n,s){let r=(n-t)*.5,a=(s-e)*.5,o=i*i,c=i*o;return(2*e-2*n+r+a)*c+(-3*e+3*n-2*r-a)*o+r*i+e}function Rp(i,t){let e=1-i;return e*e*t}function Cp(i,t){return 2*(1-i)*i*t}function Ip(i,t){return i*i*t}function na(i,t,e,n){return Rp(i,t)+Cp(i,e)+Ip(i,n)}function Pp(i,t){let e=1-i;return e*e*e*t}function Lp(i,t){let e=1-i;return 3*e*e*i*t}function Np(i,t){return 3*(1-i)*i*i*t}function Dp(i,t){return i*i*i*t}function ia(i,t,e,n,s){return Pp(i,t)+Lp(i,e)+Np(i,n)+Dp(i,s)}var Ma=class extends Bn{constructor(t=new vt,e=new vt,n=new vt,s=new vt){super(),this.isCubicBezierCurve=!0,this.type="CubicBezierCurve",this.v0=t,this.v1=e,this.v2=n,this.v3=s}getPoint(t,e=new vt){let n=e,s=this.v0,r=this.v1,a=this.v2,o=this.v3;return n.set(ia(t,s.x,r.x,a.x,o.x),ia(t,s.y,r.y,a.y,o.y)),n}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this.v3.copy(t.v3),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t.v3=this.v3.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this.v3.fromArray(t.v3),this}},_l=class extends Bn{constructor(t=new D,e=new D,n=new D,s=new D){super(),this.isCubicBezierCurve3=!0,this.type="CubicBezierCurve3",this.v0=t,this.v1=e,this.v2=n,this.v3=s}getPoint(t,e=new D){let n=e,s=this.v0,r=this.v1,a=this.v2,o=this.v3;return n.set(ia(t,s.x,r.x,a.x,o.x),ia(t,s.y,r.y,a.y,o.y),ia(t,s.z,r.z,a.z,o.z)),n}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this.v3.copy(t.v3),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t.v3=this.v3.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this.v3.fromArray(t.v3),this}},ba=class extends Bn{constructor(t=new vt,e=new vt){super(),this.isLineCurve=!0,this.type="LineCurve",this.v1=t,this.v2=e}getPoint(t,e=new vt){let n=e;return t===1?n.copy(this.v2):(n.copy(this.v2).sub(this.v1),n.multiplyScalar(t).add(this.v1)),n}getPointAt(t,e){return this.getPoint(t,e)}getTangent(t,e=new vt){return e.subVectors(this.v2,this.v1).normalize()}getTangentAt(t,e){return this.getTangent(t,e)}copy(t){return super.copy(t),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},vl=class extends Bn{constructor(t=new D,e=new D){super(),this.isLineCurve3=!0,this.type="LineCurve3",this.v1=t,this.v2=e}getPoint(t,e=new D){let n=e;return t===1?n.copy(this.v2):(n.copy(this.v2).sub(this.v1),n.multiplyScalar(t).add(this.v1)),n}getPointAt(t,e){return this.getPoint(t,e)}getTangent(t,e=new D){return e.subVectors(this.v2,this.v1).normalize()}getTangentAt(t,e){return this.getTangent(t,e)}copy(t){return super.copy(t),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},Sa=class extends Bn{constructor(t=new vt,e=new vt,n=new vt){super(),this.isQuadraticBezierCurve=!0,this.type="QuadraticBezierCurve",this.v0=t,this.v1=e,this.v2=n}getPoint(t,e=new vt){let n=e,s=this.v0,r=this.v1,a=this.v2;return n.set(na(t,s.x,r.x,a.x),na(t,s.y,r.y,a.y)),n}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},Ea=class extends Bn{constructor(t=new D,e=new D,n=new D){super(),this.isQuadraticBezierCurve3=!0,this.type="QuadraticBezierCurve3",this.v0=t,this.v1=e,this.v2=n}getPoint(t,e=new D){let n=e,s=this.v0,r=this.v1,a=this.v2;return n.set(na(t,s.x,r.x,a.x),na(t,s.y,r.y,a.y),na(t,s.z,r.z,a.z)),n}copy(t){return super.copy(t),this.v0.copy(t.v0),this.v1.copy(t.v1),this.v2.copy(t.v2),this}toJSON(){let t=super.toJSON();return t.v0=this.v0.toArray(),t.v1=this.v1.toArray(),t.v2=this.v2.toArray(),t}fromJSON(t){return super.fromJSON(t),this.v0.fromArray(t.v0),this.v1.fromArray(t.v1),this.v2.fromArray(t.v2),this}},wa=class extends Bn{constructor(t=[]){super(),this.isSplineCurve=!0,this.type="SplineCurve",this.points=t}getPoint(t,e=new vt){let n=e,s=this.points,r=(s.length-1)*t,a=Math.floor(r),o=r-a,c=s[a===0?a:a-1],l=s[a],h=s[a>s.length-2?s.length-1:a+1],f=s[a>s.length-3?s.length-1:a+2];return n.set(Du(o,c.x,l.x,h.x,f.x),Du(o,c.y,l.y,h.y,f.y)),n}copy(t){super.copy(t),this.points=[];for(let e=0,n=t.points.length;e<n;e++){let s=t.points[e];this.points.push(s.clone())}return this}toJSON(){let t=super.toJSON();t.points=[];for(let e=0,n=this.points.length;e<n;e++){let s=this.points[e];t.points.push(s.toArray())}return t}fromJSON(t){super.fromJSON(t),this.points=[];for(let e=0,n=t.points.length;e<n;e++){let s=t.points[e];this.points.push(new vt().fromArray(s))}return this}},yl=Object.freeze({__proto__:null,ArcCurve:xl,CatmullRomCurve3:xr,CubicBezierCurve:Ma,CubicBezierCurve3:_l,EllipseCurve:gr,LineCurve:ba,LineCurve3:vl,QuadraticBezierCurve:Sa,QuadraticBezierCurve3:Ea,SplineCurve:wa}),Ml=class extends Bn{constructor(){super(),this.type="CurvePath",this.curves=[],this.autoClose=!1}add(t){this.curves.push(t)}closePath(){let t=this.curves[0].getPoint(0),e=this.curves[this.curves.length-1].getPoint(1);if(!t.equals(e)){let n=t.isVector2===!0?"LineCurve":"LineCurve3";this.curves.push(new yl[n](e,t))}return this}getPoint(t,e){let n=t*this.getLength(),s=this.getCurveLengths(),r=0;for(;r<s.length;){if(s[r]>=n){let a=s[r]-n,o=this.curves[r],c=o.getLength(),l=c===0?0:1-a/c;return o.getPointAt(l,e)}r++}return null}getLength(){let t=this.getCurveLengths();return t[t.length-1]}updateArcLengths(){this.needsUpdate=!0,this.cacheLengths=null,this.getCurveLengths()}getCurveLengths(){if(this.cacheLengths&&this.cacheLengths.length===this.curves.length)return this.cacheLengths;let t=[],e=0;for(let n=0,s=this.curves.length;n<s;n++)e+=this.curves[n].getLength(),t.push(e);return this.cacheLengths=t,t}getSpacedPoints(t=40){let e=[];for(let n=0;n<=t;n++)e.push(this.getPoint(n/t));return this.autoClose&&e.push(e[0]),e}getPoints(t=12){let e=[],n;for(let s=0,r=this.curves;s<r.length;s++){let a=r[s],o=a.isEllipseCurve?t*2:a.isLineCurve||a.isLineCurve3?1:a.isSplineCurve?t*a.points.length:t,c=a.getPoints(o);for(let l=0;l<c.length;l++){let h=c[l];n&&n.equals(h)||(e.push(h),n=h)}}return this.autoClose&&e.length>1&&!e[e.length-1].equals(e[0])&&e.push(e[0]),e}copy(t){super.copy(t),this.curves=[];for(let e=0,n=t.curves.length;e<n;e++){let s=t.curves[e];this.curves.push(s.clone())}return this.autoClose=t.autoClose,this}toJSON(){let t=super.toJSON();t.autoClose=this.autoClose,t.curves=[];for(let e=0,n=this.curves.length;e<n;e++){let s=this.curves[e];t.curves.push(s.toJSON())}return t}fromJSON(t){super.fromJSON(t),this.autoClose=t.autoClose,this.curves=[];for(let e=0,n=t.curves.length;e<n;e++){let s=t.curves[e];this.curves.push(new yl[s.type]().fromJSON(s))}return this}},Ta=class extends Ml{constructor(t){super(),this.type="Path",this.currentPoint=new vt,t&&this.setFromPoints(t)}setFromPoints(t){this.moveTo(t[0].x,t[0].y);for(let e=1,n=t.length;e<n;e++)this.lineTo(t[e].x,t[e].y);return this}moveTo(t,e){return this.currentPoint.set(t,e),this}lineTo(t,e){let n=new ba(this.currentPoint.clone(),new vt(t,e));return this.curves.push(n),this.currentPoint.set(t,e),this}quadraticCurveTo(t,e,n,s){let r=new Sa(this.currentPoint.clone(),new vt(t,e),new vt(n,s));return this.curves.push(r),this.currentPoint.set(n,s),this}bezierCurveTo(t,e,n,s,r,a){let o=new Ma(this.currentPoint.clone(),new vt(t,e),new vt(n,s),new vt(r,a));return this.curves.push(o),this.currentPoint.set(r,a),this}splineThru(t){let e=[this.currentPoint.clone()].concat(t),n=new wa(e);return this.curves.push(n),this.currentPoint.copy(t[t.length-1]),this}arc(t,e,n,s,r,a){let o=this.currentPoint.x,c=this.currentPoint.y;return this.absarc(t+o,e+c,n,s,r,a),this}absarc(t,e,n,s,r,a){return this.absellipse(t,e,n,n,s,r,a),this}ellipse(t,e,n,s,r,a,o,c){let l=this.currentPoint.x,h=this.currentPoint.y;return this.absellipse(t+l,e+h,n,s,r,a,o,c),this}absellipse(t,e,n,s,r,a,o,c){let l=new gr(t,e,n,s,r,a,o,c);if(this.curves.length>0){let f=l.getPoint(0);f.equals(this.currentPoint)||this.lineTo(f.x,f.y)}this.curves.push(l);let h=l.getPoint(1);return this.currentPoint.copy(h),this}copy(t){return super.copy(t),this.currentPoint.copy(t.currentPoint),this}toJSON(){let t=super.toJSON();return t.currentPoint=this.currentPoint.toArray(),t}fromJSON(t){return super.fromJSON(t),this.currentPoint.fromArray(t.currentPoint),this}},Gi=class extends Ta{constructor(t){super(t),this.uuid=Oi(),this.type="Shape",this.holes=[]}getPointsHoles(t){let e=[];for(let n=0,s=this.holes.length;n<s;n++)e[n]=this.holes[n].getPoints(t);return e}extractPoints(t){return{shape:this.getPoints(t),holes:this.getPointsHoles(t)}}copy(t){super.copy(t),this.holes=[];for(let e=0,n=t.holes.length;e<n;e++){let s=t.holes[e];this.holes.push(s.clone())}return this}toJSON(){let t=super.toJSON();t.uuid=this.uuid,t.holes=[];for(let e=0,n=this.holes.length;e<n;e++){let s=this.holes[e];t.holes.push(s.toJSON())}return t}fromJSON(t){super.fromJSON(t),this.uuid=t.uuid,this.holes=[];for(let e=0,n=t.holes.length;e<n;e++){let s=t.holes[e];this.holes.push(new Ta().fromJSON(s))}return this}};function Up(i,t,e=2){let n=t&&t.length,s=n?t[0]*e:i.length,r=Ld(i,0,s,e,!0),a=[];if(!r||r.next===r.prev)return a;let o,c,l;if(n&&(r=kp(i,t,r,e)),i.length>80*e){o=i[0],c=i[1];let h=o,f=c;for(let u=e;u<s;u+=e){let d=i[u],g=i[u+1];d<o&&(o=d),g<c&&(c=g),d>h&&(h=d),g>f&&(f=g)}l=Math.max(h-o,f-c),l=l!==0?32767/l:0}return Aa(r,a,e,o,c,l,0),a}function Ld(i,t,e,n,s){let r;if(s===Kp(i,t,e,n)>0)for(let a=t;a<e;a+=n)r=Uu(a/n|0,i[a],i[a+1],r);else for(let a=e-n;a>=t;a-=n)r=Uu(a/n|0,i[a],i[a+1],r);return r&&_r(r,r.next)&&(Ca(r),r=r.next),r}function Es(i,t){if(!i)return i;t||(t=i);let e=i,n;do if(n=!1,!e.steiner&&(_r(e,e.next)||Ze(e.prev,e,e.next)===0)){if(Ca(e),e=t=e.prev,e===e.next)break;n=!0}else e=e.next;while(n||e!==t);return t}function Aa(i,t,e,n,s,r,a){if(!i)return;!a&&r&&Xp(i,n,s,r);let o=i;for(;i.prev!==i.next;){let c=i.prev,l=i.next;if(r?Op(i,n,s,r):Fp(i)){t.push(c.i,i.i,l.i),Ca(i),i=l.next,o=l.next;continue}if(i=l,i===o){a?a===1?(i=Bp(Es(i),t),Aa(i,t,e,n,s,r,2)):a===2&&zp(i,t,e,n,s,r):Aa(Es(i),t,e,n,s,r,1);break}}}function Fp(i){let t=i.prev,e=i,n=i.next;if(Ze(t,e,n)>=0)return!1;let s=t.x,r=e.x,a=n.x,o=t.y,c=e.y,l=n.y,h=Math.min(s,r,a),f=Math.min(o,c,l),u=Math.max(s,r,a),d=Math.max(o,c,l),g=n.next;for(;g!==t;){if(g.x>=h&&g.x<=u&&g.y>=f&&g.y<=d&&ea(s,o,r,c,a,l,g.x,g.y)&&Ze(g.prev,g,g.next)>=0)return!1;g=g.next}return!0}function Op(i,t,e,n){let s=i.prev,r=i,a=i.next;if(Ze(s,r,a)>=0)return!1;let o=s.x,c=r.x,l=a.x,h=s.y,f=r.y,u=a.y,d=Math.min(o,c,l),g=Math.min(h,f,u),_=Math.max(o,c,l),m=Math.max(h,f,u),p=B0(d,g,t,e,n),S=B0(_,m,t,e,n),w=i.prevZ,y=i.nextZ;for(;w&&w.z>=p&&y&&y.z<=S;){if(w.x>=d&&w.x<=_&&w.y>=g&&w.y<=m&&w!==s&&w!==a&&ea(o,h,c,f,l,u,w.x,w.y)&&Ze(w.prev,w,w.next)>=0||(w=w.prevZ,y.x>=d&&y.x<=_&&y.y>=g&&y.y<=m&&y!==s&&y!==a&&ea(o,h,c,f,l,u,y.x,y.y)&&Ze(y.prev,y,y.next)>=0))return!1;y=y.nextZ}for(;w&&w.z>=p;){if(w.x>=d&&w.x<=_&&w.y>=g&&w.y<=m&&w!==s&&w!==a&&ea(o,h,c,f,l,u,w.x,w.y)&&Ze(w.prev,w,w.next)>=0)return!1;w=w.prevZ}for(;y&&y.z<=S;){if(y.x>=d&&y.x<=_&&y.y>=g&&y.y<=m&&y!==s&&y!==a&&ea(o,h,c,f,l,u,y.x,y.y)&&Ze(y.prev,y,y.next)>=0)return!1;y=y.nextZ}return!0}function Bp(i,t){let e=i;do{let n=e.prev,s=e.next.next;!_r(n,s)&&Dd(n,e,e.next,s)&&Ra(n,s)&&Ra(s,n)&&(t.push(n.i,e.i,s.i),Ca(e),Ca(e.next),e=i=s),e=e.next}while(e!==i);return Es(e)}function zp(i,t,e,n,s,r){let a=i;do{let o=a.next.next;for(;o!==a.prev;){if(a.i!==o.i&&Yp(a,o)){let c=Ud(a,o);a=Es(a,a.next),c=Es(c,c.next),Aa(a,t,e,n,s,r,0),Aa(c,t,e,n,s,r,0);return}o=o.next}a=a.next}while(a!==i)}function kp(i,t,e,n){let s=[];for(let r=0,a=t.length;r<a;r++){let o=t[r]*n,c=r<a-1?t[r+1]*n:i.length,l=Ld(i,o,c,n,!1);l===l.next&&(l.steiner=!0),s.push(qp(l))}s.sort(Hp);for(let r=0;r<s.length;r++)e=Vp(s[r],e);return e}function Hp(i,t){let e=i.x-t.x;if(e===0&&(e=i.y-t.y,e===0)){let n=(i.next.y-i.y)/(i.next.x-i.x),s=(t.next.y-t.y)/(t.next.x-t.x);e=n-s}return e}function Vp(i,t){let e=Gp(i,t);if(!e)return t;let n=Ud(e,i);return Es(n,n.next),Es(e,e.next)}function Gp(i,t){let e=t,n=i.x,s=i.y,r=-1/0,a;if(_r(i,e))return e;do{if(_r(i,e.next))return e.next;if(s<=e.y&&s>=e.next.y&&e.next.y!==e.y){let f=e.x+(s-e.y)*(e.next.x-e.x)/(e.next.y-e.y);if(f<=n&&f>r&&(r=f,a=e.x<e.next.x?e:e.next,f===n))return a}e=e.next}while(e!==t);if(!a)return null;let o=a,c=a.x,l=a.y,h=1/0;e=a;do{if(n>=e.x&&e.x>=c&&n!==e.x&&Nd(s<l?n:r,s,c,l,s<l?r:n,s,e.x,e.y)){let f=Math.abs(s-e.y)/(n-e.x);Ra(e,i)&&(f<h||f===h&&(e.x>a.x||e.x===a.x&&Wp(a,e)))&&(a=e,h=f)}e=e.next}while(e!==o);return a}function Wp(i,t){return Ze(i.prev,i,t.prev)<0&&Ze(t.next,i,i.next)<0}function Xp(i,t,e,n){let s=i;do s.z===0&&(s.z=B0(s.x,s.y,t,e,n)),s.prevZ=s.prev,s.nextZ=s.next,s=s.next;while(s!==i);s.prevZ.nextZ=null,s.prevZ=null,$p(s)}function $p(i){let t,e=1;do{let n=i,s;i=null;let r=null;for(t=0;n;){t++;let a=n,o=0;for(let l=0;l<e&&(o++,a=a.nextZ,!!a);l++);let c=e;for(;o>0||c>0&&a;)o!==0&&(c===0||!a||n.z<=a.z)?(s=n,n=n.nextZ,o--):(s=a,a=a.nextZ,c--),r?r.nextZ=s:i=s,s.prevZ=r,r=s;n=a}r.nextZ=null,e*=2}while(t>1);return i}function B0(i,t,e,n,s){return i=(i-e)*s|0,t=(t-n)*s|0,i=(i|i<<8)&16711935,i=(i|i<<4)&252645135,i=(i|i<<2)&858993459,i=(i|i<<1)&1431655765,t=(t|t<<8)&16711935,t=(t|t<<4)&252645135,t=(t|t<<2)&858993459,t=(t|t<<1)&1431655765,i|t<<1}function qp(i){let t=i,e=i;do(t.x<e.x||t.x===e.x&&t.y<e.y)&&(e=t),t=t.next;while(t!==i);return e}function Nd(i,t,e,n,s,r,a,o){return(s-a)*(t-o)>=(i-a)*(r-o)&&(i-a)*(n-o)>=(e-a)*(t-o)&&(e-a)*(r-o)>=(s-a)*(n-o)}function ea(i,t,e,n,s,r,a,o){return!(i===a&&t===o)&&Nd(i,t,e,n,s,r,a,o)}function Yp(i,t){return i.next.i!==t.i&&i.prev.i!==t.i&&!Zp(i,t)&&(Ra(i,t)&&Ra(t,i)&&Jp(i,t)&&(Ze(i.prev,i,t.prev)||Ze(i,t.prev,t))||_r(i,t)&&Ze(i.prev,i,i.next)>0&&Ze(t.prev,t,t.next)>0)}function Ze(i,t,e){return(t.y-i.y)*(e.x-t.x)-(t.x-i.x)*(e.y-t.y)}function _r(i,t){return i.x===t.x&&i.y===t.y}function Dd(i,t,e,n){let s=Yo(Ze(i,t,e)),r=Yo(Ze(i,t,n)),a=Yo(Ze(e,n,i)),o=Yo(Ze(e,n,t));return!!(s!==r&&a!==o||s===0&&qo(i,e,t)||r===0&&qo(i,n,t)||a===0&&qo(e,i,n)||o===0&&qo(e,t,n))}function qo(i,t,e){return t.x<=Math.max(i.x,e.x)&&t.x>=Math.min(i.x,e.x)&&t.y<=Math.max(i.y,e.y)&&t.y>=Math.min(i.y,e.y)}function Yo(i){return i>0?1:i<0?-1:0}function Zp(i,t){let e=i;do{if(e.i!==i.i&&e.next.i!==i.i&&e.i!==t.i&&e.next.i!==t.i&&Dd(e,e.next,i,t))return!0;e=e.next}while(e!==i);return!1}function Ra(i,t){return Ze(i.prev,i,i.next)<0?Ze(i,t,i.next)>=0&&Ze(i,i.prev,t)>=0:Ze(i,t,i.prev)<0||Ze(i,i.next,t)<0}function Jp(i,t){let e=i,n=!1,s=(i.x+t.x)/2,r=(i.y+t.y)/2;do e.y>r!=e.next.y>r&&e.next.y!==e.y&&s<(e.next.x-e.x)*(r-e.y)/(e.next.y-e.y)+e.x&&(n=!n),e=e.next;while(e!==i);return n}function Ud(i,t){let e=z0(i.i,i.x,i.y),n=z0(t.i,t.x,t.y),s=i.next,r=t.prev;return i.next=t,t.prev=i,e.next=s,s.prev=e,n.next=e,e.prev=n,r.next=n,n.prev=r,n}function Uu(i,t,e,n){let s=z0(i,t,e);return n?(s.next=n.next,s.prev=n,n.next.prev=s,n.next=s):(s.prev=s,s.next=s),s}function Ca(i){i.next.prev=i.prev,i.prev.next=i.next,i.prevZ&&(i.prevZ.nextZ=i.nextZ),i.nextZ&&(i.nextZ.prevZ=i.prevZ)}function z0(i,t,e){return{i,x:t,y:e,prev:null,next:null,z:0,prevZ:null,nextZ:null,steiner:!1}}function Kp(i,t,e,n){let s=0;for(let r=t,a=e-n;r<e;r+=n)s+=(i[a]-i[r])*(i[r+1]+i[a+1]),a=r;return s}var k0=class{static triangulate(t,e,n=2){return Up(t,e,n)}},_i=class i{static area(t){let e=t.length,n=0;for(let s=e-1,r=0;r<e;s=r++)n+=t[s].x*t[r].y-t[r].x*t[s].y;return n*.5}static isClockWise(t){return i.area(t)<0}static triangulateShape(t,e){let n=[],s=[],r=[];Fu(t),Ou(n,t);let a=t.length;e.forEach(Fu);for(let c=0;c<e.length;c++)s.push(a),a+=e[c].length,Ou(n,e[c]);let o=k0.triangulate(n,s);for(let c=0;c<o.length;c+=3)r.push(o.slice(c,c+3));return r}};function Fu(i){let t=i.length;t>2&&i[t-1].equals(i[0])&&i.pop()}function Ou(i,t){for(let e=0;e<t.length;e++)i.push(t[e].x),i.push(t[e].y)}var Ia=class i extends Ae{constructor(t=new Gi([new vt(.5,.5),new vt(-.5,.5),new vt(-.5,-.5),new vt(.5,-.5)]),e={}){super(),this.type="ExtrudeGeometry",this.parameters={shapes:t,options:e},t=Array.isArray(t)?t:[t];let n=this,s=[],r=[];for(let o=0,c=t.length;o<c;o++){let l=t[o];a(l)}this.setAttribute("position",new fe(s,3)),this.setAttribute("uv",new fe(r,2)),this.computeVertexNormals();function a(o){let c=[],l=e.curveSegments!==void 0?e.curveSegments:12,h=e.steps!==void 0?e.steps:1,f=e.depth!==void 0?e.depth:1,u=e.bevelEnabled!==void 0?e.bevelEnabled:!0,d=e.bevelThickness!==void 0?e.bevelThickness:.2,g=e.bevelSize!==void 0?e.bevelSize:d-.1,_=e.bevelOffset!==void 0?e.bevelOffset:0,m=e.bevelSegments!==void 0?e.bevelSegments:3,p=e.extrudePath,S=e.UVGenerator!==void 0?e.UVGenerator:jp,w,y=!1,E,M,I,v;if(p){w=p.getSpacedPoints(h),y=!0,u=!1;let V=p.isCatmullRomCurve3?p.closed:!1;E=p.computeFrenetFrames(h,V),M=new D,I=new D,v=new D}u||(m=0,d=0,g=0,_=0);let C=o.extractPoints(l),L=C.shape,N=C.holes;if(!_i.isClockWise(L)){L=L.reverse();for(let V=0,ut=N.length;V<ut;V++){let xt=N[V];_i.isClockWise(xt)&&(N[V]=xt.reverse())}}function B(V){let xt=10000000000000001e-36,gt=V[0];for(let yt=1;yt<=V.length;yt++){let Bt=yt%V.length,Ut=V[Bt],Zt=Ut.x-gt.x,ee=Ut.y-gt.y,U=Zt*Zt+ee*ee,ne=Math.max(Math.abs(Ut.x),Math.abs(Ut.y),Math.abs(gt.x),Math.abs(gt.y)),re=xt*ne*ne;if(U<=re){V.splice(Bt,1),yt--;continue}gt=Ut}}B(L),N.forEach(B);let F=N.length,W=L;for(let V=0;V<F;V++){let ut=N[V];L=L.concat(ut)}function rt(V,ut,xt){return ut||he("ExtrudeGeometry: vec does not exist"),V.clone().addScaledVector(ut,xt)}let nt=L.length;function dt(V,ut,xt){let gt,yt,Bt,Ut=V.x-ut.x,Zt=V.y-ut.y,ee=xt.x-V.x,U=xt.y-V.y,ne=Ut*Ut+Zt*Zt,re=Ut*U-Zt*ee;if(Math.abs(re)>Number.EPSILON){let A=Math.sqrt(ne),x=Math.sqrt(ee*ee+U*U),G=ut.x-Zt/A,Y=ut.y+Ut/A,at=xt.x-U/x,Mt=xt.y+ee/x,Rt=((at-G)*U-(Mt-Y)*ee)/(Ut*U-Zt*ee);gt=G+Ut*Rt-V.x,yt=Y+Zt*Rt-V.y;let st=gt*gt+yt*yt;if(st<=2)return new vt(gt,yt);Bt=Math.sqrt(st/2)}else{let A=!1;Ut>Number.EPSILON?ee>Number.EPSILON&&(A=!0):Ut<-Number.EPSILON?ee<-Number.EPSILON&&(A=!0):Math.sign(Zt)===Math.sign(U)&&(A=!0),A?(gt=-Zt,yt=Ut,Bt=Math.sqrt(ne)):(gt=Ut,yt=Zt,Bt=Math.sqrt(ne/2))}return new vt(gt/Bt,yt/Bt)}let Q=[];for(let V=0,ut=W.length,xt=ut-1,gt=V+1;V<ut;V++,xt++,gt++)xt===ut&&(xt=0),gt===ut&&(gt=0),Q[V]=dt(W[V],W[xt],W[gt]);let ct=[],O,St=Q.concat();for(let V=0,ut=F;V<ut;V++){let xt=N[V];O=[];for(let gt=0,yt=xt.length,Bt=yt-1,Ut=gt+1;gt<yt;gt++,Bt++,Ut++)Bt===yt&&(Bt=0),Ut===yt&&(Ut=0),O[gt]=dt(xt[gt],xt[Bt],xt[Ut]);ct.push(O),St=St.concat(O)}let Et;if(m===0)Et=_i.triangulateShape(W,N);else{let V=[],ut=[];for(let xt=0;xt<m;xt++){let gt=xt/m,yt=d*Math.cos(gt*Math.PI/2),Bt=g*Math.sin(gt*Math.PI/2)+_;for(let Ut=0,Zt=W.length;Ut<Zt;Ut++){let ee=rt(W[Ut],Q[Ut],Bt);_t(ee.x,ee.y,-yt),gt===0&&V.push(ee)}for(let Ut=0,Zt=F;Ut<Zt;Ut++){let ee=N[Ut];O=ct[Ut];let U=[];for(let ne=0,re=ee.length;ne<re;ne++){let A=rt(ee[ne],O[ne],Bt);_t(A.x,A.y,-yt),gt===0&&U.push(A)}gt===0&&ut.push(U)}}Et=_i.triangulateShape(V,ut)}let At=Et.length,Ot=g+_;for(let V=0;V<nt;V++){let ut=u?rt(L[V],St[V],Ot):L[V];y?(I.copy(E.normals[0]).multiplyScalar(ut.x),M.copy(E.binormals[0]).multiplyScalar(ut.y),v.copy(w[0]).add(I).add(M),_t(v.x,v.y,v.z)):_t(ut.x,ut.y,0)}for(let V=1;V<=h;V++)for(let ut=0;ut<nt;ut++){let xt=u?rt(L[ut],St[ut],Ot):L[ut];y?(I.copy(E.normals[V]).multiplyScalar(xt.x),M.copy(E.binormals[V]).multiplyScalar(xt.y),v.copy(w[V]).add(I).add(M),_t(v.x,v.y,v.z)):_t(xt.x,xt.y,f/h*V)}for(let V=m-1;V>=0;V--){let ut=V/m,xt=d*Math.cos(ut*Math.PI/2),gt=g*Math.sin(ut*Math.PI/2)+_;for(let yt=0,Bt=W.length;yt<Bt;yt++){let Ut=rt(W[yt],Q[yt],gt);_t(Ut.x,Ut.y,f+xt)}for(let yt=0,Bt=N.length;yt<Bt;yt++){let Ut=N[yt];O=ct[yt];for(let Zt=0,ee=Ut.length;Zt<ee;Zt++){let U=rt(Ut[Zt],O[Zt],gt);y?_t(U.x,U.y+w[h-1].y,w[h-1].x+xt):_t(U.x,U.y,f+xt)}}}Dt(),tt();function Dt(){let V=s.length/3;if(u){let ut=0,xt=nt*ut;for(let gt=0;gt<At;gt++){let yt=Et[gt];bt(yt[2]+xt,yt[1]+xt,yt[0]+xt)}ut=h+m*2,xt=nt*ut;for(let gt=0;gt<At;gt++){let yt=Et[gt];bt(yt[0]+xt,yt[1]+xt,yt[2]+xt)}}else{for(let ut=0;ut<At;ut++){let xt=Et[ut];bt(xt[2],xt[1],xt[0])}for(let ut=0;ut<At;ut++){let xt=Et[ut];bt(xt[0]+nt*h,xt[1]+nt*h,xt[2]+nt*h)}}n.addGroup(V,s.length/3-V,0)}function tt(){let V=s.length/3,ut=0;it(W,ut),ut+=W.length;for(let xt=0,gt=N.length;xt<gt;xt++){let yt=N[xt];it(yt,ut),ut+=yt.length}n.addGroup(V,s.length/3-V,1)}function it(V,ut){let xt=V.length;for(;--xt>=0;){let gt=xt,yt=xt-1;yt<0&&(yt=V.length-1);for(let Bt=0,Ut=h+m*2;Bt<Ut;Bt++){let Zt=nt*Bt,ee=nt*(Bt+1),U=ut+gt+Zt,ne=ut+yt+Zt,re=ut+yt+ee,A=ut+gt+ee;mt(U,ne,re,A)}}}function _t(V,ut,xt){c.push(V),c.push(ut),c.push(xt)}function bt(V,ut,xt){Ct(V),Ct(ut),Ct(xt);let gt=s.length/3,yt=S.generateTopUV(n,s,gt-3,gt-2,gt-1);Qt(yt[0]),Qt(yt[1]),Qt(yt[2])}function mt(V,ut,xt,gt){Ct(V),Ct(ut),Ct(gt),Ct(ut),Ct(xt),Ct(gt);let yt=s.length/3,Bt=S.generateSideWallUV(n,s,yt-6,yt-3,yt-2,yt-1);Qt(Bt[0]),Qt(Bt[1]),Qt(Bt[3]),Qt(Bt[1]),Qt(Bt[2]),Qt(Bt[3])}function Ct(V){s.push(c[V*3+0]),s.push(c[V*3+1]),s.push(c[V*3+2])}function Qt(V){r.push(V.x),r.push(V.y)}}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}toJSON(){let t=super.toJSON(),e=this.parameters.shapes,n=this.parameters.options;return Qp(e,n,t)}static fromJSON(t,e){let n=[];for(let r=0,a=t.shapes.length;r<a;r++){let o=e[t.shapes[r]];n.push(o)}let s=t.options.extrudePath;return s!==void 0&&(t.options.extrudePath=new yl[s.type]().fromJSON(s)),new i(n,t.options)}},jp={generateTopUV:function(i,t,e,n,s){let r=t[e*3],a=t[e*3+1],o=t[n*3],c=t[n*3+1],l=t[s*3],h=t[s*3+1];return[new vt(r,a),new vt(o,c),new vt(l,h)]},generateSideWallUV:function(i,t,e,n,s,r){let a=t[e*3],o=t[e*3+1],c=t[e*3+2],l=t[n*3],h=t[n*3+1],f=t[n*3+2],u=t[s*3],d=t[s*3+1],g=t[s*3+2],_=t[r*3],m=t[r*3+1],p=t[r*3+2];return Math.abs(o-h)<Math.abs(a-l)?[new vt(a,1-c),new vt(l,1-f),new vt(u,1-g),new vt(_,1-p)]:[new vt(o,1-c),new vt(h,1-f),new vt(d,1-g),new vt(m,1-p)]}};function Qp(i,t,e){if(e.shapes=[],Array.isArray(i))for(let n=0,s=i.length;n<s;n++){let r=i[n];e.shapes.push(r.uuid)}else e.shapes.push(i.uuid);return e.options=Object.assign({},t),t.extrudePath!==void 0&&(e.options.extrudePath=t.extrudePath.toJSON()),e}var vr=class i extends Ae{constructor(t=[new vt(0,-.5),new vt(.5,0),new vt(0,.5)],e=12,n=0,s=Math.PI*2){super(),this.type="LatheGeometry",this.parameters={points:t,segments:e,phiStart:n,phiLength:s},e=Math.floor(e),s=be(s,0,Math.PI*2);let r=[],a=[],o=[],c=[],l=[],h=1/e,f=new D,u=new vt,d=new D,g=new D,_=new D,m=0,p=0;for(let S=0;S<=t.length-1;S++)switch(S){case 0:m=t[S+1].x-t[S].x,p=t[S+1].y-t[S].y,d.x=p*1,d.y=-m,d.z=p*0,_.copy(d),d.normalize(),c.push(d.x,d.y,d.z);break;case t.length-1:c.push(_.x,_.y,_.z);break;default:m=t[S+1].x-t[S].x,p=t[S+1].y-t[S].y,d.x=p*1,d.y=-m,d.z=p*0,g.copy(d),d.x+=_.x,d.y+=_.y,d.z+=_.z,d.normalize(),c.push(d.x,d.y,d.z),_.copy(g)}for(let S=0;S<=e;S++){let w=n+S*h*s,y=Math.sin(w),E=Math.cos(w);for(let M=0;M<=t.length-1;M++){f.x=t[M].x*y,f.y=t[M].y,f.z=t[M].x*E,a.push(f.x,f.y,f.z),u.x=S/e,u.y=M/(t.length-1),o.push(u.x,u.y);let I=c[3*M+0]*y,v=c[3*M+1],C=c[3*M+0]*E;l.push(I,v,C)}}for(let S=0;S<e;S++)for(let w=0;w<t.length-1;w++){let y=w+S*t.length,E=y,M=y+t.length,I=y+t.length+1,v=y+1;r.push(E,M,v),r.push(I,v,M)}this.setIndex(r),this.setAttribute("position",new fe(a,3)),this.setAttribute("uv",new fe(o,2)),this.setAttribute("normal",new fe(l,3))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.points,t.segments,t.phiStart,t.phiLength)}};var rs=class i extends Ae{constructor(t=1,e=1,n=1,s=1){super(),this.type="PlaneGeometry",this.parameters={width:t,height:e,widthSegments:n,heightSegments:s};let r=t/2,a=e/2,o=Math.floor(n),c=Math.floor(s),l=o+1,h=c+1,f=t/o,u=e/c,d=[],g=[],_=[],m=[];for(let p=0;p<h;p++){let S=p*u-a;for(let w=0;w<l;w++){let y=w*f-r;g.push(y,-S,0),_.push(0,0,1),m.push(w/o),m.push(1-p/c)}}for(let p=0;p<c;p++)for(let S=0;S<o;S++){let w=S+l*p,y=S+l*(p+1),E=S+1+l*(p+1),M=S+1+l*p;d.push(w,y,M),d.push(y,E,M)}this.setIndex(d),this.setAttribute("position",new fe(g,3)),this.setAttribute("normal",new fe(_,3)),this.setAttribute("uv",new fe(m,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.width,t.height,t.widthSegments,t.heightSegments)}},yr=class i extends Ae{constructor(t=.5,e=1,n=32,s=1,r=0,a=Math.PI*2){super(),this.type="RingGeometry",this.parameters={innerRadius:t,outerRadius:e,thetaSegments:n,phiSegments:s,thetaStart:r,thetaLength:a},n=Math.max(3,n),s=Math.max(1,s);let o=[],c=[],l=[],h=[],f=t,u=(e-t)/s,d=new D,g=new vt;for(let _=0;_<=s;_++){for(let m=0;m<=n;m++){let p=r+m/n*a;d.x=f*Math.cos(p),d.y=f*Math.sin(p),c.push(d.x,d.y,d.z),l.push(0,0,1),g.x=(d.x/e+1)/2,g.y=(d.y/e+1)/2,h.push(g.x,g.y)}f+=u}for(let _=0;_<s;_++){let m=_*(n+1);for(let p=0;p<n;p++){let S=p+m,w=S,y=S+n+1,E=S+n+2,M=S+1;o.push(w,y,M),o.push(y,E,M)}}this.setIndex(o),this.setAttribute("position",new fe(c,3)),this.setAttribute("normal",new fe(l,3)),this.setAttribute("uv",new fe(h,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.innerRadius,t.outerRadius,t.thetaSegments,t.phiSegments,t.thetaStart,t.thetaLength)}},Pa=class i extends Ae{constructor(t=new Gi([new vt(0,.5),new vt(-.5,-.5),new vt(.5,-.5)]),e=12){super(),this.type="ShapeGeometry",this.parameters={shapes:t,curveSegments:e};let n=[],s=[],r=[],a=[],o=0,c=0;if(Array.isArray(t)===!1)l(t);else for(let h=0;h<t.length;h++)l(t[h]),this.addGroup(o,c,h),o+=c,c=0;this.setIndex(n),this.setAttribute("position",new fe(s,3)),this.setAttribute("normal",new fe(r,3)),this.setAttribute("uv",new fe(a,2));function l(h){let f=s.length/3,u=h.extractPoints(e),d=u.shape,g=u.holes;_i.isClockWise(d)===!1&&(d=d.reverse());for(let m=0,p=g.length;m<p;m++){let S=g[m];_i.isClockWise(S)===!0&&(g[m]=S.reverse())}let _=_i.triangulateShape(d,g);for(let m=0,p=g.length;m<p;m++){let S=g[m];d=d.concat(S)}for(let m=0,p=d.length;m<p;m++){let S=d[m];s.push(S.x,S.y,0),r.push(0,0,1),a.push(S.x,S.y)}for(let m=0,p=_.length;m<p;m++){let S=_[m],w=S[0]+f,y=S[1]+f,E=S[2]+f;n.push(w,y,E),c+=3}}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}toJSON(){let t=super.toJSON(),e=this.parameters.shapes;return t1(e,t)}static fromJSON(t,e){let n=[];for(let s=0,r=t.shapes.length;s<r;s++){let a=e[t.shapes[s]];n.push(a)}return new i(n,t.curveSegments)}};function t1(i,t){if(t.shapes=[],Array.isArray(i))for(let e=0,n=i.length;e<n;e++){let s=i[e];t.shapes.push(s.uuid)}else t.shapes.push(i.uuid);return t}var $n=class i extends Ae{constructor(t=1,e=32,n=16,s=0,r=Math.PI*2,a=0,o=Math.PI){super(),this.type="SphereGeometry",this.parameters={radius:t,widthSegments:e,heightSegments:n,phiStart:s,phiLength:r,thetaStart:a,thetaLength:o},e=Math.max(3,Math.floor(e)),n=Math.max(2,Math.floor(n));let c=Math.min(a+o,Math.PI),l=0,h=[],f=new D,u=new D,d=[],g=[],_=[],m=[];for(let p=0;p<=n;p++){let S=[],w=p/n,y=a+w*o,E=t*Math.cos(y),M=Math.sqrt(t*t-E*E),I=0;p===0&&a===0?I=.5/e:p===n&&c===Math.PI&&(I=-.5/e);for(let v=0;v<=e;v++){let C=v/e,L=s+C*r;f.x=-M*Math.cos(L),f.y=E,f.z=M*Math.sin(L),g.push(f.x,f.y,f.z),u.copy(f).normalize(),_.push(u.x,u.y,u.z),m.push(C+I,1-w),S.push(l++)}h.push(S)}for(let p=0;p<n;p++)for(let S=0;S<e;S++){let w=h[p][S+1],y=h[p][S],E=h[p+1][S],M=h[p+1][S+1];(p!==0||a>0)&&d.push(w,y,M),(p!==n-1||c<Math.PI)&&d.push(y,E,M)}this.setIndex(d),this.setAttribute("position",new fe(g,3)),this.setAttribute("normal",new fe(_,3)),this.setAttribute("uv",new fe(m,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.radius,t.widthSegments,t.heightSegments,t.phiStart,t.phiLength,t.thetaStart,t.thetaLength)}};var Wi=class i extends Ae{constructor(t=1,e=.4,n=12,s=48,r=Math.PI*2,a=0,o=Math.PI*2){super(),this.type="TorusGeometry",this.parameters={radius:t,tube:e,radialSegments:n,tubularSegments:s,arc:r,thetaStart:a,thetaLength:o},n=Math.floor(n),s=Math.floor(s);let c=[],l=[],h=[],f=[],u=new D,d=new D,g=new D;for(let _=0;_<=n;_++){let m=a+_/n*o;for(let p=0;p<=s;p++){let S=p/s*r;d.x=(t+e*Math.cos(m))*Math.cos(S),d.y=(t+e*Math.cos(m))*Math.sin(S),d.z=e*Math.sin(m),l.push(d.x,d.y,d.z),u.x=t*Math.cos(S),u.y=t*Math.sin(S),g.subVectors(d,u).normalize(),h.push(g.x,g.y,g.z),f.push(p/s),f.push(_/n)}}for(let _=1;_<=n;_++)for(let m=1;m<=s;m++){let p=(s+1)*_+m-1,S=(s+1)*(_-1)+m-1,w=(s+1)*(_-1)+m,y=(s+1)*_+m;c.push(p,S,y),c.push(S,w,y)}this.setIndex(c),this.setAttribute("position",new fe(l,3)),this.setAttribute("normal",new fe(h,3)),this.setAttribute("uv",new fe(f,2))}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}static fromJSON(t){return new i(t.radius,t.tube,t.radialSegments,t.tubularSegments,t.arc,t.thetaStart,t.thetaLength)}};var La=class i extends Ae{constructor(t=new Ea(new D(-1,-1,0),new D(-1,1,0),new D(1,1,0)),e=64,n=1,s=8,r=!1){super(),this.type="TubeGeometry",this.parameters={path:t,tubularSegments:e,radius:n,radialSegments:s,closed:r};let a=t.computeFrenetFrames(e,r);this.tangents=a.tangents,this.normals=a.normals,this.binormals=a.binormals;let o=new D,c=new D,l=new vt,h=new D,f=[],u=[],d=[],g=[];_(),this.setIndex(g),this.setAttribute("position",new fe(f,3)),this.setAttribute("normal",new fe(u,3)),this.setAttribute("uv",new fe(d,2));function _(){for(let w=0;w<e;w++)m(w);m(r===!1?e:0),S(),p()}function m(w){h=t.getPointAt(w/e,h);let y=a.normals[w],E=a.binormals[w];for(let M=0;M<=s;M++){let I=M/s*Math.PI*2,v=Math.sin(I),C=-Math.cos(I);c.x=C*y.x+v*E.x,c.y=C*y.y+v*E.y,c.z=C*y.z+v*E.z,c.normalize(),u.push(c.x,c.y,c.z),o.x=h.x+n*c.x,o.y=h.y+n*c.y,o.z=h.z+n*c.z,f.push(o.x,o.y,o.z)}}function p(){for(let w=1;w<=e;w++)for(let y=1;y<=s;y++){let E=(s+1)*(w-1)+(y-1),M=(s+1)*w+(y-1),I=(s+1)*w+y,v=(s+1)*(w-1)+y;g.push(E,M,v),g.push(M,I,v)}}function S(){for(let w=0;w<=e;w++)for(let y=0;y<=s;y++)l.x=w/e,l.y=y/s,d.push(l.x,l.y)}}copy(t){return super.copy(t),this.parameters=Object.assign({},t.parameters),this}toJSON(){let t=super.toJSON();return t.path=this.parameters.path.toJSON(),t}static fromJSON(t){return new i(new yl[t.path.type]().fromJSON(t.path),t.tubularSegments,t.radius,t.radialSegments,t.closed)}};function Rs(i){let t={};for(let e in i){t[e]={};for(let n in i[e]){let s=i[e][n];if(Bu(s))s.isRenderTargetTexture?(ue("UniformsUtils: Textures of render targets cannot be cloned via cloneUniforms() or mergeUniforms()."),t[e][n]=null):t[e][n]=s.clone();else if(Array.isArray(s))if(Bu(s[0])){let r=[];for(let a=0,o=s.length;a<o;a++)r[a]=s[a].clone();t[e][n]=r}else t[e][n]=s.slice();else t[e][n]=s}}return t}function Cn(i){let t={};for(let e=0;e<i.length;e++){let n=Rs(i[e]);for(let s in n)t[s]=n[s]}return t}function Bu(i){return i&&(i.isColor||i.isMatrix3||i.isMatrix4||i.isVector2||i.isVector3||i.isVector4||i.isTexture||i.isQuaternion)}function e1(i){let t=[];for(let e=0;e<i.length;e++)t.push(i[e].clone());return t}function lh(i){let t=i.getRenderTarget();return t===null?i.outputColorSpace:t.isXRRenderTarget===!0?t.texture.colorSpace:Se.workingColorSpace}var Xi={clone:Rs,merge:Cn},n1=`void main() {
	gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
}`,i1=`void main() {
	gl_FragColor = vec4( 1.0, 0.0, 0.0, 1.0 );
}`,Oe=class extends oi{constructor(t){super(),this.isShaderMaterial=!0,this.type="ShaderMaterial",this.defines={},this.uniforms={},this.uniformsGroups=[],this.vertexShader=n1,this.fragmentShader=i1,this.linewidth=1,this.wireframe=!1,this.wireframeLinewidth=1,this.fog=!1,this.lights=!1,this.clipping=!1,this.forceSinglePass=!0,this.extensions={clipCullDistance:!1,multiDraw:!1},this.defaultAttributeValues={color:[1,1,1],uv:[0,0],uv1:[0,0]},this.index0AttributeName=void 0,this.uniformsNeedUpdate=!1,this.glslVersion=null,t!==void 0&&this.setValues(t)}copy(t){return super.copy(t),this.fragmentShader=t.fragmentShader,this.vertexShader=t.vertexShader,this.uniforms=Rs(t.uniforms),this.uniformsGroups=e1(t.uniformsGroups),this.defines=Object.assign({},t.defines),this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this.fog=t.fog,this.lights=t.lights,this.clipping=t.clipping,this.extensions=Object.assign({},t.extensions),this.glslVersion=t.glslVersion,this.defaultAttributeValues=Object.assign({},t.defaultAttributeValues),this.index0AttributeName=t.index0AttributeName,this.uniformsNeedUpdate=t.uniformsNeedUpdate,this}toJSON(t){let e=super.toJSON(t);e.glslVersion=this.glslVersion,e.uniforms={};for(let s in this.uniforms){let a=this.uniforms[s].value;a&&a.isTexture?e.uniforms[s]={type:"t",value:a.toJSON(t).uuid}:a&&a.isColor?e.uniforms[s]={type:"c",value:a.getHex()}:a&&a.isVector2?e.uniforms[s]={type:"v2",value:a.toArray()}:a&&a.isVector3?e.uniforms[s]={type:"v3",value:a.toArray()}:a&&a.isVector4?e.uniforms[s]={type:"v4",value:a.toArray()}:a&&a.isMatrix3?e.uniforms[s]={type:"m3",value:a.toArray()}:a&&a.isMatrix4?e.uniforms[s]={type:"m4",value:a.toArray()}:e.uniforms[s]={value:a}}Object.keys(this.defines).length>0&&(e.defines=this.defines),e.vertexShader=this.vertexShader,e.fragmentShader=this.fragmentShader,e.lights=this.lights,e.clipping=this.clipping;let n={};for(let s in this.extensions)this.extensions[s]===!0&&(n[s]=!0);return Object.keys(n).length>0&&(e.extensions=n),e}fromJSON(t,e){if(super.fromJSON(t,e),t.uniforms!==void 0)for(let n in t.uniforms){let s=t.uniforms[n];switch(this.uniforms[n]={},s.type){case"t":this.uniforms[n].value=e[s.value]||null;break;case"c":this.uniforms[n].value=new se().setHex(s.value);break;case"v2":this.uniforms[n].value=new vt().fromArray(s.value);break;case"v3":this.uniforms[n].value=new D().fromArray(s.value);break;case"v4":this.uniforms[n].value=new $e().fromArray(s.value);break;case"m3":this.uniforms[n].value=new me().fromArray(s.value);break;case"m4":this.uniforms[n].value=new Ce().fromArray(s.value);break;default:this.uniforms[n].value=s.value}}if(t.defines!==void 0&&(this.defines=t.defines),t.vertexShader!==void 0&&(this.vertexShader=t.vertexShader),t.fragmentShader!==void 0&&(this.fragmentShader=t.fragmentShader),t.glslVersion!==void 0&&(this.glslVersion=t.glslVersion),t.extensions!==void 0)for(let n in t.extensions)this.extensions[n]=t.extensions[n];return t.lights!==void 0&&(this.lights=t.lights),t.clipping!==void 0&&(this.clipping=t.clipping),this}},Mr=class extends Oe{constructor(t){super(t),this.isRawShaderMaterial=!0,this.type="RawShaderMaterial"}},zn=class extends oi{constructor(t){super(),this.isMeshStandardMaterial=!0,this.type="MeshStandardMaterial",this.defines={STANDARD:""},this.color=new se(16777215),this.roughness=1,this.metalness=0,this.map=null,this.lightMap=null,this.lightMapIntensity=1,this.aoMap=null,this.aoMapIntensity=1,this.emissive=new se(0),this.emissiveIntensity=1,this.emissiveMap=null,this.bumpMap=null,this.bumpScale=1,this.normalMap=null,this.normalMapType=Mc,this.normalScale=new vt(1,1),this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.roughnessMap=null,this.metalnessMap=null,this.alphaMap=null,this.envMap=null,this.envMapRotation=new zi,this.envMapIntensity=1,this.wireframe=!1,this.wireframeLinewidth=1,this.wireframeLinecap="round",this.wireframeLinejoin="round",this.flatShading=!1,this.fog=!0,this.setValues(t)}copy(t){return super.copy(t),this.defines={STANDARD:""},this.color.copy(t.color),this.roughness=t.roughness,this.metalness=t.metalness,this.map=t.map,this.lightMap=t.lightMap,this.lightMapIntensity=t.lightMapIntensity,this.aoMap=t.aoMap,this.aoMapIntensity=t.aoMapIntensity,this.emissive.copy(t.emissive),this.emissiveMap=t.emissiveMap,this.emissiveIntensity=t.emissiveIntensity,this.bumpMap=t.bumpMap,this.bumpScale=t.bumpScale,this.normalMap=t.normalMap,this.normalMapType=t.normalMapType,this.normalScale.copy(t.normalScale),this.displacementMap=t.displacementMap,this.displacementScale=t.displacementScale,this.displacementBias=t.displacementBias,this.roughnessMap=t.roughnessMap,this.metalnessMap=t.metalnessMap,this.alphaMap=t.alphaMap,this.envMap=t.envMap,this.envMapRotation.copy(t.envMapRotation),this.envMapIntensity=t.envMapIntensity,this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this.wireframeLinecap=t.wireframeLinecap,this.wireframeLinejoin=t.wireframeLinejoin,this.flatShading=t.flatShading,this.fog=t.fog,this}},Na=class extends zn{constructor(t){super(),this.isMeshPhysicalMaterial=!0,this.defines={STANDARD:"",PHYSICAL:""},this.type="MeshPhysicalMaterial",this.anisotropyRotation=0,this.anisotropyMap=null,this.clearcoatMap=null,this.clearcoatRoughness=0,this.clearcoatRoughnessMap=null,this.clearcoatNormalScale=new vt(1,1),this.clearcoatNormalMap=null,this.ior=1.5,Object.defineProperty(this,"reflectivity",{get:function(){return be(2.5*(this.ior-1)/(this.ior+1),0,1)},set:function(e){this.ior=(1+.4*e)/(1-.4*e)}}),this.iridescenceMap=null,this.iridescenceIOR=1.3,this.iridescenceThicknessRange=[100,400],this.iridescenceThicknessMap=null,this.sheenColor=new se(0),this.sheenColorMap=null,this.sheenRoughness=1,this.sheenRoughnessMap=null,this.transmissionMap=null,this.thickness=0,this.thicknessMap=null,this.attenuationDistance=1/0,this.attenuationColor=new se(1,1,1),this.specularIntensity=1,this.specularIntensityMap=null,this.specularColor=new se(1,1,1),this.specularColorMap=null,this._anisotropy=0,this._clearcoat=0,this._dispersion=0,this._iridescence=0,this._retroreflectivity=0,this._sheen=0,this._transmission=0,this.setValues(t)}get anisotropy(){return this._anisotropy}set anisotropy(t){this._anisotropy>0!=t>0&&this.version++,this._anisotropy=t}get clearcoat(){return this._clearcoat}set clearcoat(t){this._clearcoat>0!=t>0&&this.version++,this._clearcoat=t}get iridescence(){return this._iridescence}set iridescence(t){this._iridescence>0!=t>0&&this.version++,this._iridescence=t}get dispersion(){return this._dispersion}set dispersion(t){this._dispersion>0!=t>0&&this.version++,this._dispersion=t}get retroreflectivity(){return this._retroreflectivity}set retroreflectivity(t){this._retroreflectivity>0!=t>0&&this.version++,this._retroreflectivity=t}get sheen(){return this._sheen}set sheen(t){this._sheen>0!=t>0&&this.version++,this._sheen=t}get transmission(){return this._transmission}set transmission(t){this._transmission>0!=t>0&&this.version++,this._transmission=t}copy(t){return super.copy(t),this.defines={STANDARD:"",PHYSICAL:""},this.anisotropy=t.anisotropy,this.anisotropyRotation=t.anisotropyRotation,this.anisotropyMap=t.anisotropyMap,this.clearcoat=t.clearcoat,this.clearcoatMap=t.clearcoatMap,this.clearcoatRoughness=t.clearcoatRoughness,this.clearcoatRoughnessMap=t.clearcoatRoughnessMap,this.clearcoatNormalMap=t.clearcoatNormalMap,this.clearcoatNormalScale.copy(t.clearcoatNormalScale),this.dispersion=t.dispersion,this.ior=t.ior,this.iridescence=t.iridescence,this.iridescenceMap=t.iridescenceMap,this.iridescenceIOR=t.iridescenceIOR,this.iridescenceThicknessRange=[...t.iridescenceThicknessRange],this.iridescenceThicknessMap=t.iridescenceThicknessMap,this.retroreflectivity=t.retroreflectivity,this.sheen=t.sheen,this.sheenColor.copy(t.sheenColor),this.sheenColorMap=t.sheenColorMap,this.sheenRoughness=t.sheenRoughness,this.sheenRoughnessMap=t.sheenRoughnessMap,this.transmission=t.transmission,this.transmissionMap=t.transmissionMap,this.thickness=t.thickness,this.thicknessMap=t.thicknessMap,this.attenuationDistance=t.attenuationDistance,this.attenuationColor.copy(t.attenuationColor),this.specularIntensity=t.specularIntensity,this.specularIntensityMap=t.specularIntensityMap,this.specularColor.copy(t.specularColor),this.specularColorMap=t.specularColorMap,this}};var bl=class extends oi{constructor(t){super(),this.isMeshDepthMaterial=!0,this.type="MeshDepthMaterial",this.depthPacking=xd,this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.wireframe=!1,this.wireframeLinewidth=1,this.setValues(t)}copy(t){return super.copy(t),this.depthPacking=t.depthPacking,this.map=t.map,this.alphaMap=t.alphaMap,this.displacementMap=t.displacementMap,this.displacementScale=t.displacementScale,this.displacementBias=t.displacementBias,this.wireframe=t.wireframe,this.wireframeLinewidth=t.wireframeLinewidth,this}},Sl=class extends oi{constructor(t){super(),this.isMeshDistanceMaterial=!0,this.type="MeshDistanceMaterial",this.map=null,this.alphaMap=null,this.displacementMap=null,this.displacementScale=1,this.displacementBias=0,this.setValues(t)}copy(t){return super.copy(t),this.map=t.map,this.alphaMap=t.alphaMap,this.displacementMap=t.displacementMap,this.displacementScale=t.displacementScale,this.displacementBias=t.displacementBias,this}};var Da=class extends li{constructor(t){super(),this.isLineDashedMaterial=!0,this.type="LineDashedMaterial",this.scale=1,this.dashSize=3,this.gapSize=1,this.setValues(t)}copy(t){return super.copy(t),this.scale=t.scale,this.dashSize=t.dashSize,this.gapSize=t.gapSize,this}};function tr(i,t){return!i||i.constructor===t?i:typeof t.BYTES_PER_ELEMENT=="number"?new t(i):Array.prototype.slice.call(i)}function P0(i){return i!==void 0&&i.inTangents!==void 0&&i.outTangents!==void 0}var as=class{constructor(t,e,n,s){this.parameterPositions=t,this._cachedIndex=0,this.resultBuffer=s!==void 0?s:new e.constructor(n),this.sampleValues=e,this.valueSize=n,this.settings=null,this.DefaultSettings_={}}evaluate(t){let e=this.parameterPositions,n=this._cachedIndex,s=e[n],r=e[n-1];n:{t:{let a;e:{i:if(!(t<s)){for(let o=n+2;;){if(s===void 0){if(t<r)break i;return n=e.length,this._cachedIndex=n,this.copySampleValue_(n-1)}if(n===o)break;if(r=s,s=e[++n],t<s)break t}a=e.length;break e}if(!(t>=r)){let o=e[1];t<o&&(n=2,r=o);for(let c=n-2;;){if(r===void 0)return this._cachedIndex=0,this.copySampleValue_(0);if(n===c)break;if(s=r,r=e[--n-1],t>=r)break t}a=n,n=0;break e}break n}for(;n<a;){let o=n+a>>>1;t<e[o]?a=o:n=o+1}if(s=e[n],r=e[n-1],r===void 0)return this._cachedIndex=0,this.copySampleValue_(0);if(s===void 0)return n=e.length,this._cachedIndex=n,this.copySampleValue_(n-1)}this._cachedIndex=n,this.intervalChanged_(n,r,s)}return this.interpolate_(n,r,t,s)}getSettings_(){return this.settings||this.DefaultSettings_}copySampleValue_(t){let e=this.resultBuffer,n=this.sampleValues,s=this.valueSize,r=t*s;for(let a=0;a!==s;++a)e[a]=n[r+a];return e}interpolate_(){throw new Error("THREE.Interpolant: Call to abstract method.")}intervalChanged_(){}},El=class extends as{constructor(t,e,n,s){super(t,e,n,s),this._weightPrev=-0,this._offsetPrev=-0,this._weightNext=-0,this._offsetNext=-0,this.DefaultSettings_={endingStart:D0,endingEnd:D0}}intervalChanged_(t,e,n){let s=this.parameterPositions,r=t-2,a=t+1,o=s[r],c=s[a];if(o===void 0)switch(this.getSettings_().endingStart){case U0:r=t,o=2*e-n;break;case F0:r=s.length-2,o=e+s[r]-s[r+1];break;default:r=t,o=n}if(c===void 0)switch(this.getSettings_().endingEnd){case U0:a=t,c=2*n-e;break;case F0:a=1,c=n+s[1]-s[0];break;default:a=t-1,c=e}let l=(n-e)*.5,h=this.valueSize;this._weightPrev=l/(e-o),this._weightNext=l/(c-n),this._offsetPrev=r*h,this._offsetNext=a*h}interpolate_(t,e,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,c=t*o,l=c-o,h=this._offsetPrev,f=this._offsetNext,u=this._weightPrev,d=this._weightNext,g=(n-e)/(s-e),_=g*g,m=_*g,p=-u*m+2*u*_-u*g,S=(1+u)*m+(-1.5-2*u)*_+(-.5+u)*g+1,w=(-1-d)*m+(1.5+d)*_+.5*g,y=d*m-d*_;for(let E=0;E!==o;++E)r[E]=p*a[h+E]+S*a[l+E]+w*a[c+E]+y*a[f+E];return r}},wl=class extends as{constructor(t,e,n,s){super(t,e,n,s)}interpolate_(t,e,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,c=t*o,l=c-o,h=(n-e)/(s-e),f=1-h;for(let u=0;u!==o;++u)r[u]=a[l+u]*f+a[c+u]*h;return r}},Tl=class extends as{constructor(t,e,n,s){super(t,e,n,s)}interpolate_(t){return this.copySampleValue_(t-1)}},Al=class extends as{interpolate_(t,e,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,c=t*o,l=c-o,h=this.inTangents,f=this.outTangents;if(!h||!f){let g=(n-e)/(s-e),_=1-g;for(let m=0;m!==o;++m)r[m]=a[l+m]*_+a[c+m]*g;return r}let u=o*2,d=t-1;for(let g=0;g!==o;++g){let _=a[l+g],m=a[c+g],p=d*u+g*2,S=f[p],w=f[p+1],y=t*u+g*2,E=h[y],M=h[y+1],I=r1(n,e,S,E,s);r[g]=Fd(I,_,w,M,m)}return r}};function Fd(i,t,e,n,s){let r=1-i;return r*r*r*t+3*r*r*i*e+3*r*i*i*n+i*i*i*s}function s1(i,t,e,n,s){let r=1-i;return 3*r*r*(e-t)+6*r*i*(n-e)+3*i*i*(s-n)}function r1(i,t,e,n,s){let r=(i-t)/(s-t);for(let a=0;a<8;a++){let o=Fd(r,t,e,n,s)-i;if(Math.abs(o)<1e-10)break;let c=s1(r,t,e,n,s);if(Math.abs(c)<1e-10)break;r=Math.max(0,Math.min(1,r-o/c))}return r}var kn=class{constructor(t,e,n,s){if(t===void 0)throw new Error("THREE.KeyframeTrack: track name is undefined");if(e===void 0||e.length===0)throw new Error("THREE.KeyframeTrack: no keyframes in track named "+t);this.name=t,this.times=tr(e,this.TimeBufferType),this.values=tr(n,this.ValueBufferType),this.setInterpolation(s||this.DefaultInterpolation)}static toJSON(t){let e=t.constructor,n;if(e.toJSON!==this.toJSON)n=e.toJSON(t);else{n={name:t.name,times:tr(t.times,Array),values:tr(t.values,Array)};let s=t.getInterpolation();s!==t.DefaultInterpolation&&(n.interpolation=s),P0(t.settings)&&(n.settings={inTangents:tr(t.settings.inTangents,Array),outTangents:tr(t.settings.outTangents,Array)})}return n.type=t.ValueTypeName,n}InterpolantFactoryMethodDiscrete(t){return new Tl(this.times,this.values,this.getValueSize(),t)}InterpolantFactoryMethodLinear(t){return new wl(this.times,this.values,this.getValueSize(),t)}InterpolantFactoryMethodSmooth(t){return new El(this.times,this.values,this.getValueSize(),t)}InterpolantFactoryMethodBezier(t){let e=new Al(this.times,this.values,this.getValueSize(),t);return this.settings&&(e.inTangents=this.settings.inTangents,e.outTangents=this.settings.outTangents),e}setInterpolation(t){let e;switch(t){case sa:e=this.InterpolantFactoryMethodDiscrete;break;case ll:e=this.InterpolantFactoryMethodLinear;break;case Ko:e=this.InterpolantFactoryMethodSmooth;break;case N0:e=this.InterpolantFactoryMethodBezier;break}if(e===void 0){let n="unsupported interpolation for "+this.ValueTypeName+" keyframe track named "+this.name;if(this.createInterpolant===void 0)if(t!==this.DefaultInterpolation)this.setInterpolation(this.DefaultInterpolation);else throw new Error(n);return ue("KeyframeTrack:",n),this}return this.createInterpolant=e,this}getInterpolation(){switch(this.createInterpolant){case this.InterpolantFactoryMethodDiscrete:return sa;case this.InterpolantFactoryMethodLinear:return ll;case this.InterpolantFactoryMethodSmooth:return Ko;case this.InterpolantFactoryMethodBezier:return N0}}getValueSize(){return this.values.length/this.times.length}shift(t){if(t!==0){let e=this.times;for(let n=0,s=e.length;n!==s;++n)e[n]+=t}return this}scale(t){if(t!==1){let e=this.times;for(let n=0,s=e.length;n!==s;++n)e[n]*=t;P0(this.settings)&&(zu(this.settings.inTangents,t),zu(this.settings.outTangents,t))}return this}trim(t,e){let n=this.times,s=n.length,r=0,a=s-1;for(;r!==s&&n[r]<t;)++r;for(;a!==-1&&n[a]>e;)--a;if(++a,r!==0||a!==s){r>=a&&(a=Math.max(a,1),r=a-1);let o=this.getValueSize();this.times=n.slice(r,a),this.values=this.values.slice(r*o,a*o)}return this}validate(){let t=!0,e=this.getValueSize();e-Math.floor(e)!==0&&(he("KeyframeTrack: Invalid value size in track.",this),t=!1);let n=this.times,s=this.values,r=n.length;r===0&&(he("KeyframeTrack: Track is empty.",this),t=!1);let a=null;for(let o=0;o!==r;o++){let c=n[o];if(typeof c=="number"&&isNaN(c)){he("KeyframeTrack: Time is not a valid number.",this,o,c),t=!1;break}if(a!==null&&a>c){he("KeyframeTrack: Out of order keys.",this,o,c,a),t=!1;break}a=c}if(s!==void 0&&op(s))for(let o=0,c=s.length;o!==c;++o){let l=s[o];if(isNaN(l)){he("KeyframeTrack: Value is not a valid number.",this,o,l),t=!1;break}}return t}optimize(){let t=this.times.slice(),e=this.values.slice(),n=this.getValueSize(),s=this.getInterpolation()===Ko,r=t.length-1,a=1;for(let o=1;o<r;++o){let c=!1,l=t[o],h=t[o+1];if(l!==h&&(o!==1||l!==t[0]))if(s)c=!0;else{let f=o*n,u=f-n,d=f+n;for(let g=0;g!==n;++g){let _=e[f+g];if(_!==e[u+g]||_!==e[d+g]){c=!0;break}}}if(c){if(o!==a){t[a]=t[o];let f=o*n,u=a*n;for(let d=0;d!==n;++d)e[u+d]=e[f+d]}++a}}if(r>0){t[a]=t[r];for(let o=r*n,c=a*n,l=0;l!==n;++l)e[c+l]=e[o+l];++a}return a!==t.length?(this.times=t.slice(0,a),this.values=e.slice(0,a*n)):(this.times=t,this.values=e),this}clone(){let t=this.times.slice(),e=this.values.slice(),n=this.constructor,s=new n(this.name,t,e);return s.createInterpolant=this.createInterpolant,P0(this.settings)&&(s.settings={inTangents:this.settings.inTangents.slice(),outTangents:this.settings.outTangents.slice()}),s}};function zu(i,t){for(let e=0,n=i.length;e!==n;e+=2)i[e]*=t}kn.prototype.ValueTypeName="";kn.prototype.TimeBufferType=Float32Array;kn.prototype.ValueBufferType=Float32Array;kn.prototype.DefaultInterpolation=ll;var os=class extends kn{constructor(t,e,n){super(t,e,n)}};os.prototype.ValueTypeName="bool";os.prototype.ValueBufferType=Array;os.prototype.DefaultInterpolation=sa;os.prototype.InterpolantFactoryMethodLinear=void 0;os.prototype.InterpolantFactoryMethodSmooth=void 0;var Rl=class extends kn{constructor(t,e,n,s){super(t,e,n,s)}};Rl.prototype.ValueTypeName="color";var Cl=class extends kn{constructor(t,e,n,s){super(t,e,n,s)}};Cl.prototype.ValueTypeName="number";var Il=class extends as{constructor(t,e,n,s){super(t,e,n,s)}interpolate_(t,e,n,s){let r=this.resultBuffer,a=this.sampleValues,o=this.valueSize,c=(n-e)/(s-e),l=t*o;for(let h=l+o;l!==h;l+=4)Mi.slerpFlat(r,0,a,l-o,a,l,c);return r}},Ua=class extends kn{constructor(t,e,n,s){super(t,e,n,s)}InterpolantFactoryMethodLinear(t){return new Il(this.times,this.values,this.getValueSize(),t)}};Ua.prototype.ValueTypeName="quaternion";Ua.prototype.InterpolantFactoryMethodSmooth=void 0;var ls=class extends kn{constructor(t,e,n){super(t,e,n)}};ls.prototype.ValueTypeName="string";ls.prototype.ValueBufferType=Array;ls.prototype.DefaultInterpolation=sa;ls.prototype.InterpolantFactoryMethodLinear=void 0;ls.prototype.InterpolantFactoryMethodSmooth=void 0;var Pl=class extends kn{constructor(t,e,n,s){super(t,e,n,s)}};Pl.prototype.ValueTypeName="vector";var Qo={enabled:!1,files:{},add:function(i,t){this.enabled!==!1&&(ku(i)||(this.files[i]=t))},get:function(i){if(this.enabled!==!1&&!ku(i))return this.files[i]},remove:function(i){delete this.files[i]},clear:function(){this.files={}}};function ku(i){try{let t=i.slice(i.indexOf(":")+1);return new URL(t).protocol==="blob:"}catch{return!1}}var Ll=class{constructor(t,e,n){let s=this,r=!1,a=0,o=0,c,l=[];this.onStart=void 0,this.onLoad=t,this.onProgress=e,this.onError=n,this._abortController=null,this.itemStart=function(h){o++,r===!1&&s.onStart!==void 0&&s.onStart(h,a,o),r=!0},this.itemEnd=function(h){a++,s.onProgress!==void 0&&s.onProgress(h,a,o),a===o&&(r=!1,s.onLoad!==void 0&&s.onLoad())},this.itemError=function(h){s.onError!==void 0&&s.onError(h)},this.resolveURL=function(h){return h=h.normalize("NFC"),c?c(h):h},this.setURLModifier=function(h){return c=h,this},this.addHandler=function(h,f){return l.push(h,f),this},this.removeHandler=function(h){let f=l.indexOf(h);return f!==-1&&l.splice(f,2),this},this.getHandler=function(h){for(let f=0,u=l.length;f<u;f+=2){let d=l[f],g=l[f+1];if(d.global&&(d.lastIndex=0),d.test(h))return g}return null},this.abort=function(){return this.abortController.abort(),this._abortController=null,this}}get abortController(){return this._abortController||(this._abortController=new AbortController),this._abortController}},Od=new Ll,br=class{constructor(t){this.manager=t!==void 0?t:Od,this.crossOrigin="anonymous",this.withCredentials=!1,this.path="",this.resourcePath="",this.requestHeader={},typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}load(){}loadAsync(t,e){let n=this;return new Promise(function(s,r){n.load(t,s,e,r)})}parse(){}setCrossOrigin(t){return this.crossOrigin=t,this}setWithCredentials(t){return this.withCredentials=t,this}setPath(t){return this.path=t,this}setResourcePath(t){return this.resourcePath=t,this}setRequestHeader(t){return this.requestHeader=t,this}abort(){return this}};br.DEFAULT_MATERIAL_NAME="__DEFAULT";var er=new WeakMap,Nl=class extends br{constructor(t){super(t)}load(t,e,n,s){this.path!==void 0&&(t=this.path+t),t=this.manager.resolveURL(t);let r=this,a=Qo.get(`image:${t}`);if(a!==void 0){if(a.complete===!0)r.manager.itemStart(t),setTimeout(function(){e&&e(a),r.manager.itemEnd(t)},0);else{let f=er.get(a);f===void 0&&(f=[],er.set(a,f)),f.push({onLoad:e,onError:s})}return a}let o=or("img");function c(){h(),e&&e(this);let f=er.get(this)||[];for(let u=0;u<f.length;u++){let d=f[u];d.onLoad&&d.onLoad(this)}er.delete(this),r.manager.itemEnd(t)}function l(f){h(),s&&s(f),Qo.remove(`image:${t}`);let u=er.get(this)||[];for(let d=0;d<u.length;d++){let g=u[d];g.onError&&g.onError(f)}er.delete(this),r.manager.itemError(t),r.manager.itemEnd(t)}function h(){o.removeEventListener("load",c,!1),o.removeEventListener("error",l,!1)}return o.addEventListener("load",c,!1),o.addEventListener("error",l,!1),t.slice(0,5)!=="data:"&&this.crossOrigin!==void 0&&(o.crossOrigin=this.crossOrigin),Qo.add(`image:${t}`,o),r.manager.itemStart(t),o.src=t,o}};var Fa=class extends br{constructor(t){super(t)}load(t,e,n,s){let r=new gn,a=new Nl(this.manager);return a.setCrossOrigin(this.crossOrigin),a.setPath(this.path),a.load(t,function(o){r.image=o,r.needsUpdate=!0,e!==void 0&&e(r)},n,s),r}},Sr=class extends en{constructor(t,e=1){super(),this.isLight=!0,this.type="Light",this.color=new se(t),this.intensity=e}copy(t,e){return super.copy(t,e),this.color.copy(t.color),this.intensity=t.intensity,this}toJSON(t){let e=super.toJSON(t);return e.object.color=this.color.getHex(),e.object.intensity=this.intensity,e}},Oa=class extends Sr{constructor(t,e,n){super(t,n),this.isHemisphereLight=!0,this.type="HemisphereLight",this.position.copy(en.DEFAULT_UP),this.updateMatrix(),this.groundColor=new se(e)}copy(t,e){return super.copy(t,e),this.groundColor.copy(t.groundColor),this}toJSON(t){let e=super.toJSON(t);return e.object.groundColor=this.groundColor.getHex(),e}},L0=new Ce,Hu=new D,Vu=new D,Ba=class{constructor(t){this.camera=t,this.intensity=1,this.bias=0,this.biasNode=null,this.normalBias=0,this.radius=1,this.blurSamples=8,this.mapSize=new vt(512,512),this.mapType=Nn,this.map=null,this.mapPass=null,this.matrix=new Ce,this.autoUpdate=!0,this.needsUpdate=!1,this._frustum=new pr,this._frameExtents=new vt(1,1),this._viewportCount=1,this._viewports=[new $e(0,0,1,1)]}getViewportCount(){return this._viewportCount}getCamera(){return this.camera}getFrustum(){return this._frustum}updateMatrices(t){let e=this.camera;Hu.setFromMatrixPosition(t.matrixWorld),e.position.copy(Hu),Vu.setFromMatrixPosition(t.target.matrixWorld),e.lookAt(Vu),e.updateMatrixWorld(),this._updateMatrix(e,this.matrix,this._frustum)}_updateMatrix(t,e,n,s){L0.multiplyMatrices(t.projectionMatrix,t.matrixWorldInverse),n.setFromProjectionMatrix(L0,t.coordinateSystem,t.reversedDepth);let r=this._frameExtents,a=s?s.z/r.x:1,o=s?s.w/r.y:1,c=s?s.x/r.x:0,l=s?s.y/r.y:0;t.coordinateSystem===ar||t.reversedDepth?e.set(.5*a,0,0,.5*a+c,0,.5*o,0,.5*o+l,0,0,1,0,0,0,0,1):e.set(.5*a,0,0,.5*a+c,0,.5*o,0,.5*o+l,0,0,.5,.5,0,0,0,1),e.multiply(L0)}getViewport(t){return this._viewports[t]}getFrameExtents(){return this._frameExtents}dispose(){this.map&&this.map.dispose(),this.mapPass&&this.mapPass.dispose()}copy(t){return this.camera=t.camera.clone(),this.intensity=t.intensity,this.bias=t.bias,this.radius=t.radius,this.autoUpdate=t.autoUpdate,this.needsUpdate=t.needsUpdate,this.normalBias=t.normalBias,this.blurSamples=t.blurSamples,this.mapSize.copy(t.mapSize),this.biasNode=t.biasNode,this}clone(){return new this.constructor().copy(this)}toJSON(){let t={};return t.intensity=this.intensity,t.bias=this.bias,t.normalBias=this.normalBias,t.radius=this.radius,t.blurSamples=this.blurSamples,t.mapSize=this.mapSize.toArray(),t.camera=this.camera.toJSON(!1).object,delete t.camera.matrix,t}},Zo=new D,Jo=new Mi,mi=new D,za=class extends en{constructor(){super(),this.isCamera=!0,this.type="Camera",this.matrixWorldInverse=new Ce,this.projectionMatrix=new Ce,this.projectionMatrixInverse=new Ce,this.coordinateSystem=ai,this._reversedDepth=!1}get reversedDepth(){return this._reversedDepth}copy(t,e){return super.copy(t,e),this.matrixWorldInverse.copy(t.matrixWorldInverse),this.projectionMatrix.copy(t.projectionMatrix),this.projectionMatrixInverse.copy(t.projectionMatrixInverse),this.coordinateSystem=t.coordinateSystem,this}getWorldDirection(t){return super.getWorldDirection(t).negate()}updateMatrixWorld(t){super.updateMatrixWorld(t),this.matrixWorld.decompose(Zo,Jo,mi),mi.x===1&&mi.y===1&&mi.z===1?this.matrixWorldInverse.copy(this.matrixWorld).invert():this.matrixWorldInverse.compose(Zo,Jo,mi.set(1,1,1)).invert()}updateWorldMatrix(t,e,n=!1){super.updateWorldMatrix(t,e,n),this.matrixWorld.decompose(Zo,Jo,mi),mi.x===1&&mi.y===1&&mi.z===1?this.matrixWorldInverse.copy(this.matrixWorld).invert():this.matrixWorldInverse.compose(Zo,Jo,mi.set(1,1,1)).invert()}clone(){return new this.constructor().copy(this)}},es=new D,Gu=new vt,Wu=new vt,yn=class extends za{constructor(t=50,e=1,n=.1,s=2e3){super(),this.isPerspectiveCamera=!0,this.type="PerspectiveCamera",this.fov=t,this.zoom=1,this.near=n,this.far=s,this.focus=10,this.aspect=e,this.view=null,this.filmGauge=35,this.filmOffset=0,this.updateProjectionMatrix()}copy(t,e){return super.copy(t,e),this.fov=t.fov,this.zoom=t.zoom,this.near=t.near,this.far=t.far,this.focus=t.focus,this.aspect=t.aspect,this.view=t.view===null?null:Object.assign({},t.view),this.filmGauge=t.filmGauge,this.filmOffset=t.filmOffset,this}setFocalLength(t){let e=.5*this.getFilmHeight()/t;this.fov=cl*2*Math.atan(e),this.updateProjectionMatrix()}getFocalLength(){let t=Math.tan(r0*.5*this.fov);return .5*this.getFilmHeight()/t}getEffectiveFOV(){return cl*2*Math.atan(Math.tan(r0*.5*this.fov)/this.zoom)}getFilmWidth(){return this.filmGauge*Math.min(this.aspect,1)}getFilmHeight(){return this.filmGauge/Math.max(this.aspect,1)}getViewBounds(t,e,n){es.set(-1,-1,.5).applyMatrix4(this.projectionMatrixInverse),e.set(es.x,es.y).multiplyScalar(-t/es.z),es.set(1,1,.5).applyMatrix4(this.projectionMatrixInverse),n.set(es.x,es.y).multiplyScalar(-t/es.z)}getViewSize(t,e){return this.getViewBounds(t,Gu,Wu),e.subVectors(Wu,Gu)}setViewOffset(t,e,n,s,r,a){this.aspect=t/e,this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=t,this.view.fullHeight=e,this.view.offsetX=n,this.view.offsetY=s,this.view.width=r,this.view.height=a,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){let t=this.near,e=t*Math.tan(r0*.5*this.fov)/this.zoom,n=2*e,s=this.aspect*n,r=-.5*s,a=this.view;if(this.view!==null&&this.view.enabled){let c=a.fullWidth,l=a.fullHeight;r+=a.offsetX*s/c,e-=a.offsetY*n/l,s*=a.width/c,n*=a.height/l}let o=this.filmOffset;o!==0&&(r+=t*o/this.getFilmWidth()),this.projectionMatrix.makePerspective(r,r+s,e,e-n,t,this.far,this.coordinateSystem,this.reversedDepth),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(t){let e=super.toJSON(t);return e.object.fov=this.fov,e.object.zoom=this.zoom,e.object.near=this.near,e.object.far=this.far,e.object.focus=this.focus,e.object.aspect=this.aspect,this.view!==null&&(e.object.view=Object.assign({},this.view)),e.object.filmGauge=this.filmGauge,e.object.filmOffset=this.filmOffset,e}};var H0=class extends Ba{constructor(){super(new yn(90,1,.5,500)),this.isPointLightShadow=!0}},ka=class extends Sr{constructor(t,e,n=0,s=2){super(t,e),this.isPointLight=!0,this.type="PointLight",this.distance=n,this.decay=s,this.shadow=new H0}get power(){return this.intensity*4*Math.PI}set power(t){this.intensity=t/(4*Math.PI)}dispose(){super.dispose(),this.shadow.dispose()}copy(t,e){return super.copy(t,e),this.distance=t.distance,this.decay=t.decay,this.shadow=t.shadow.clone(),this}toJSON(t){let e=super.toJSON(t);return e.object.distance=this.distance,e.object.decay=this.decay,e.object.shadow=this.shadow.toJSON(),e}},cs=class extends za{constructor(t=-1,e=1,n=1,s=-1,r=.1,a=2e3){super(),this.isOrthographicCamera=!0,this.type="OrthographicCamera",this.zoom=1,this.view=null,this.left=t,this.right=e,this.top=n,this.bottom=s,this.near=r,this.far=a,this.updateProjectionMatrix()}copy(t,e){return super.copy(t,e),this.left=t.left,this.right=t.right,this.top=t.top,this.bottom=t.bottom,this.near=t.near,this.far=t.far,this.zoom=t.zoom,this.view=t.view===null?null:Object.assign({},t.view),this}setViewOffset(t,e,n,s,r,a){this.view===null&&(this.view={enabled:!0,fullWidth:1,fullHeight:1,offsetX:0,offsetY:0,width:1,height:1}),this.view.enabled=!0,this.view.fullWidth=t,this.view.fullHeight=e,this.view.offsetX=n,this.view.offsetY=s,this.view.width=r,this.view.height=a,this.updateProjectionMatrix()}clearViewOffset(){this.view!==null&&(this.view.enabled=!1),this.updateProjectionMatrix()}updateProjectionMatrix(){let t=(this.right-this.left)/(2*this.zoom),e=(this.top-this.bottom)/(2*this.zoom),n=(this.right+this.left)/2,s=(this.top+this.bottom)/2,r=n-t,a=n+t,o=s+e,c=s-e;if(this.view!==null&&this.view.enabled){let l=(this.right-this.left)/this.view.fullWidth/this.zoom,h=(this.top-this.bottom)/this.view.fullHeight/this.zoom;r+=l*this.view.offsetX,a=r+l*this.view.width,o-=h*this.view.offsetY,c=o-h*this.view.height}this.projectionMatrix.makeOrthographic(r,a,o,c,this.near,this.far,this.coordinateSystem,this.reversedDepth),this.projectionMatrixInverse.copy(this.projectionMatrix).invert()}toJSON(t){let e=super.toJSON(t);return e.object.zoom=this.zoom,e.object.left=this.left,e.object.right=this.right,e.object.top=this.top,e.object.bottom=this.bottom,e.object.near=this.near,e.object.far=this.far,this.view!==null&&(e.object.view=Object.assign({},this.view)),e}},V0=class extends Ba{constructor(){super(new cs(-5,5,5,-5,.5,500)),this.isDirectionalLightShadow=!0}},Er=class extends Sr{constructor(t,e){super(t,e),this.isDirectionalLight=!0,this.type="DirectionalLight",this.position.copy(en.DEFAULT_UP),this.updateMatrix(),this.target=new en,this.shadow=new V0}dispose(){super.dispose(),this.shadow.dispose()}copy(t){return super.copy(t),this.target=t.target.clone(),this.shadow=t.shadow.clone(),this}toJSON(t){let e=super.toJSON(t);return e.object.shadow=this.shadow.toJSON(),e.object.target=this.target.uuid,e}};var nr=-90,ir=1,Dl=class extends en{constructor(t,e,n){super(),this.type="CubeCamera",this.renderTarget=n,this.coordinateSystem=null,this.activeMipmapLevel=0;let s=new yn(nr,ir,t,e);s.layers=this.layers,this.add(s);let r=new yn(nr,ir,t,e);r.layers=this.layers,this.add(r);let a=new yn(nr,ir,t,e);a.layers=this.layers,this.add(a);let o=new yn(nr,ir,t,e);o.layers=this.layers,this.add(o);let c=new yn(nr,ir,t,e);c.layers=this.layers,this.add(c);let l=new yn(nr,ir,t,e);l.layers=this.layers,this.add(l)}updateCoordinateSystem(){let t=this.coordinateSystem,e=this.children.concat(),[n,s,r,a,o,c]=e;for(let l of e)this.remove(l);if(t===ai)n.up.set(0,1,0),n.lookAt(1,0,0),s.up.set(0,1,0),s.lookAt(-1,0,0),r.up.set(0,0,-1),r.lookAt(0,1,0),a.up.set(0,0,1),a.lookAt(0,-1,0),o.up.set(0,1,0),o.lookAt(0,0,1),c.up.set(0,1,0),c.lookAt(0,0,-1);else if(t===ar)n.up.set(0,-1,0),n.lookAt(-1,0,0),s.up.set(0,-1,0),s.lookAt(1,0,0),r.up.set(0,0,1),r.lookAt(0,1,0),a.up.set(0,0,-1),a.lookAt(0,-1,0),o.up.set(0,-1,0),o.lookAt(0,0,1),c.up.set(0,-1,0),c.lookAt(0,0,-1);else throw new Error("THREE.CubeCamera.updateCoordinateSystem(): Invalid coordinate system: "+t);for(let l of e)this.add(l),l.updateMatrixWorld()}update(t,e){this.parent===null&&this.updateMatrixWorld();let{renderTarget:n,activeMipmapLevel:s}=this;this.coordinateSystem!==t.coordinateSystem&&(this.coordinateSystem=t.coordinateSystem,this.updateCoordinateSystem());let[r,a,o,c,l,h]=this.children,f=t.getRenderTarget(),u=t.getActiveCubeFace(),d=t.getActiveMipmapLevel(),g=t.xr.enabled;t.xr.enabled=!1;let _=n.texture.generateMipmaps;n.texture.generateMipmaps=!1;let m=!1;t.isWebGLRenderer===!0?m=t.state.buffers.depth.getReversed():m=t.reversedDepthBuffer,t.setRenderTarget(n,0,s),m&&t.autoClear===!1&&t.clearDepth(),t.render(e,r),t.setRenderTarget(n,1,s),m&&t.autoClear===!1&&t.clearDepth(),t.render(e,a),t.setRenderTarget(n,2,s),m&&t.autoClear===!1&&t.clearDepth(),t.render(e,o),t.setRenderTarget(n,3,s),m&&t.autoClear===!1&&t.clearDepth(),t.render(e,c),t.setRenderTarget(n,4,s),m&&t.autoClear===!1&&t.clearDepth(),t.render(e,l),n.texture.generateMipmaps=_,t.setRenderTarget(n,5,s),m&&t.autoClear===!1&&t.clearDepth(),t.render(e,h),t.setRenderTarget(f,u,d),t.xr.enabled=g,n.texture.needsPMREMUpdate=!0}},Ul=class extends yn{constructor(t=[]){super(),this.isArrayCamera=!0,this.isMultiViewCamera=!1,this.cameras=t}},Ha=class{constructor(){this._previousTime=0,this._currentTime=0,this._startTime=performance.now(),this._delta=0,this._elapsed=0,this._timescale=1,this._document=null,this._pageVisibilityHandler=null}connect(t){this._document=t,t.hidden!==void 0&&(this._pageVisibilityHandler=a1.bind(this),t.addEventListener("visibilitychange",this._pageVisibilityHandler,!1))}disconnect(){this._pageVisibilityHandler!==null&&(this._document.removeEventListener("visibilitychange",this._pageVisibilityHandler),this._pageVisibilityHandler=null),this._document=null}getDelta(){return this._delta/1e3}getElapsed(){return this._elapsed/1e3}getTimescale(){return this._timescale}setTimescale(t){return this._timescale=t,this}reset(){return this._currentTime=performance.now()-this._startTime,this}dispose(){this.disconnect()}update(t){return this._pageVisibilityHandler!==null&&this._document.hidden===!0?this._delta=0:(this._previousTime=this._currentTime,this._currentTime=(t!==void 0?t:performance.now())-this._startTime,this._delta=(this._currentTime-this._previousTime)*this._timescale,this._elapsed+=this._delta),this}};function a1(){this._document.hidden===!1&&this.reset()}var ch="\\[\\]\\.:\\/",o1=new RegExp("["+ch+"]","g"),hh="[^"+ch+"]",l1="[^"+ch.replace("\\.","")+"]",c1=/((?:WC+[\/:])*)/.source.replace("WC",hh),h1=/(WCOD+)?/.source.replace("WCOD",l1),u1=/(?:\.(WC+)(?:\[(.+)\])?)?/.source.replace("WC",hh),d1=/\.(WC+)(?:\[(.+)\])?/.source.replace("WC",hh),f1=new RegExp("^"+c1+h1+u1+d1+"$"),p1=["material","materials","bones","map"],G0=class{constructor(t,e,n){let s=n||Xe.parseTrackName(e);this._targetGroup=t,this._bindings=t.subscribe_(e,s)}getValue(t,e){this.bind();let n=this._targetGroup.nCachedObjects_,s=this._bindings[n];s!==void 0&&s.getValue(t,e)}setValue(t,e){let n=this._bindings;for(let s=this._targetGroup.nCachedObjects_,r=n.length;s!==r;++s)n[s].setValue(t,e)}bind(){let t=this._bindings;for(let e=this._targetGroup.nCachedObjects_,n=t.length;e!==n;++e)t[e].bind()}unbind(){let t=this._bindings;for(let e=this._targetGroup.nCachedObjects_,n=t.length;e!==n;++e)t[e].unbind()}},Xe=class i{constructor(t,e,n){this.path=e,this.parsedPath=n||i.parseTrackName(e),this.node=i.findNode(t,this.parsedPath.nodeName),this.rootNode=t,this.getValue=this._getValue_unbound,this.setValue=this._setValue_unbound}static create(t,e,n){return t&&t.isAnimationObjectGroup?new i.Composite(t,e,n):new i(t,e,n)}static sanitizeNodeName(t){return t.replace(/\s/g,"_").replace(o1,"")}static parseTrackName(t){let e=f1.exec(t);if(e===null)throw new Error("THREE.PropertyBinding: Cannot parse trackName: "+t);let n={nodeName:e[2],objectName:e[3],objectIndex:e[4],propertyName:e[5],propertyIndex:e[6]},s=n.nodeName&&n.nodeName.lastIndexOf(".");if(s!==void 0&&s!==-1){let r=n.nodeName.substring(s+1);p1.indexOf(r)!==-1&&(n.nodeName=n.nodeName.substring(0,s),n.objectName=r)}if(n.propertyName===null||n.propertyName.length===0)throw new Error("THREE.PropertyBinding: can not parse propertyName from trackName: "+t);return n}static findNode(t,e){if(e===void 0||e===""||e==="."||e===-1||e===t.name||e===t.uuid)return t;if(t.skeleton){let n=t.skeleton.getBoneByName(e);if(n!==void 0)return n}if(t.children){let n=function(r){for(let a=0;a<r.length;a++){let o=r[a];if(o.name===e||o.uuid===e)return o;let c=n(o.children);if(c)return c}return null},s=n(t.children);if(s)return s}return null}_getValue_unavailable(){}_setValue_unavailable(){}_getValue_direct(t,e){t[e]=this.targetObject[this.propertyName]}_getValue_array(t,e){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)t[e++]=n[s]}_getValue_arrayElement(t,e){t[e]=this.resolvedProperty[this.propertyIndex]}_getValue_toArray(t,e){this.resolvedProperty.toArray(t,e)}_setValue_direct(t,e){this.targetObject[this.propertyName]=t[e]}_setValue_direct_setNeedsUpdate(t,e){this.targetObject[this.propertyName]=t[e],this.targetObject.needsUpdate=!0}_setValue_direct_setMatrixWorldNeedsUpdate(t,e){this.targetObject[this.propertyName]=t[e],this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_array(t,e){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)n[s]=t[e++]}_setValue_array_setNeedsUpdate(t,e){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)n[s]=t[e++];this.targetObject.needsUpdate=!0}_setValue_array_setMatrixWorldNeedsUpdate(t,e){let n=this.resolvedProperty;for(let s=0,r=n.length;s!==r;++s)n[s]=t[e++];this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_arrayElement(t,e){this.resolvedProperty[this.propertyIndex]=t[e]}_setValue_arrayElement_setNeedsUpdate(t,e){this.resolvedProperty[this.propertyIndex]=t[e],this.targetObject.needsUpdate=!0}_setValue_arrayElement_setMatrixWorldNeedsUpdate(t,e){this.resolvedProperty[this.propertyIndex]=t[e],this.targetObject.matrixWorldNeedsUpdate=!0}_setValue_fromArray(t,e){this.resolvedProperty.fromArray(t,e)}_setValue_fromArray_setNeedsUpdate(t,e){this.resolvedProperty.fromArray(t,e),this.targetObject.needsUpdate=!0}_setValue_fromArray_setMatrixWorldNeedsUpdate(t,e){this.resolvedProperty.fromArray(t,e),this.targetObject.matrixWorldNeedsUpdate=!0}_getValue_unbound(t,e){this.bind(),this.getValue(t,e)}_setValue_unbound(t,e){this.bind(),this.setValue(t,e)}bind(){let t=this.node,e=this.parsedPath,n=e.objectName,s=e.propertyName,r=e.propertyIndex;if(t||(t=i.findNode(this.rootNode,e.nodeName),this.node=t),this.getValue=this._getValue_unavailable,this.setValue=this._setValue_unavailable,!t){ue("PropertyBinding: No target node found for track: "+this.path+".");return}if(n){let l=e.objectIndex;switch(n){case"materials":if(!t.material){he("PropertyBinding: Can not bind to material as node does not have a material.",this);return}if(!t.material.materials){he("PropertyBinding: Can not bind to material.materials as node.material does not have a materials array.",this);return}t=t.material.materials;break;case"bones":if(!t.skeleton){he("PropertyBinding: Can not bind to bones as node does not have a skeleton.",this);return}t=t.skeleton.bones;for(let h=0;h<t.length;h++)if(t[h].name===l){l=h;break}break;case"map":if("map"in t){t=t.map;break}if(!t.material){he("PropertyBinding: Can not bind to material as node does not have a material.",this);return}if(!t.material.map){he("PropertyBinding: Can not bind to material.map as node.material does not have a map.",this);return}t=t.material.map;break;default:if(t[n]===void 0){he("PropertyBinding: Can not bind to objectName of node undefined.",this);return}t=t[n]}if(l!==void 0){if(t[l]===void 0){he("PropertyBinding: Trying to bind to objectIndex of objectName, but is undefined.",this,t);return}t=t[l]}}let a=t[s];if(a===void 0){let l=e.nodeName;he("PropertyBinding: Trying to update property for track: "+l+"."+s+" but it wasn't found.",t);return}let o=this.Versioning.None;this.targetObject=t,t.isMaterial===!0?o=this.Versioning.NeedsUpdate:t.isObject3D===!0&&(o=this.Versioning.MatrixWorldNeedsUpdate);let c=this.BindingType.Direct;if(r!==void 0){if(s==="morphTargetInfluences"){if(!t.geometry){he("PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.",this);return}if(!t.geometry.morphAttributes){he("PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.morphAttributes.",this);return}t.morphTargetDictionary[r]!==void 0&&(r=t.morphTargetDictionary[r])}c=this.BindingType.ArrayElement,this.resolvedProperty=a,this.propertyIndex=r}else a.fromArray!==void 0&&a.toArray!==void 0?(c=this.BindingType.HasFromToArray,this.resolvedProperty=a):Array.isArray(a)?(c=this.BindingType.EntireArray,this.resolvedProperty=a):this.propertyName=s;this.getValue=this.GetterByBindingType[c],this.setValue=this.SetterByBindingTypeAndVersioning[c][o]}unbind(){this.node=null,this.getValue=this._getValue_unbound,this.setValue=this._setValue_unbound}};Xe.Composite=G0;Xe.prototype.BindingType={Direct:0,EntireArray:1,ArrayElement:2,HasFromToArray:3};Xe.prototype.Versioning={None:0,NeedsUpdate:1,MatrixWorldNeedsUpdate:2};Xe.prototype.GetterByBindingType=[Xe.prototype._getValue_direct,Xe.prototype._getValue_array,Xe.prototype._getValue_arrayElement,Xe.prototype._getValue_toArray];Xe.prototype.SetterByBindingTypeAndVersioning=[[Xe.prototype._setValue_direct,Xe.prototype._setValue_direct_setNeedsUpdate,Xe.prototype._setValue_direct_setMatrixWorldNeedsUpdate],[Xe.prototype._setValue_array,Xe.prototype._setValue_array_setNeedsUpdate,Xe.prototype._setValue_array_setMatrixWorldNeedsUpdate],[Xe.prototype._setValue_arrayElement,Xe.prototype._setValue_arrayElement_setNeedsUpdate,Xe.prototype._setValue_arrayElement_setMatrixWorldNeedsUpdate],[Xe.prototype._setValue_fromArray,Xe.prototype._setValue_fromArray_setNeedsUpdate,Xe.prototype._setValue_fromArray_setMatrixWorldNeedsUpdate]];var q3=new Float32Array(1);var Xu=new Ce,Va=class{constructor(t,e,n=0,s=1/0){this.ray=new Ss(t,e),this.near=n,this.far=s,this.camera=null,this.layers=new hr,this.params={Mesh:{},Line:{threshold:1},LOD:{},Points:{threshold:1},Sprite:{}}}set(t,e){this.ray.set(t,e)}setFromCamera(t,e){e.isPerspectiveCamera?(this.ray.origin.setFromMatrixPosition(e.matrixWorld),this.ray.direction.set(t.x,t.y,.5).unproject(e).sub(this.ray.origin).normalize(),this.camera=e):e.isOrthographicCamera?(this.ray.origin.set(t.x,t.y,e.projectionMatrix.elements[14]).unproject(e),this.ray.direction.set(0,0,-1).transformDirection(e.matrixWorld),this.camera=e):he("Raycaster: Unsupported camera type: "+e.type)}setFromXRController(t){return Xu.identity().extractRotation(t.matrixWorld),this.ray.origin.setFromMatrixPosition(t.matrixWorld),this.ray.direction.set(0,0,-1).applyMatrix4(Xu),this}intersectObject(t,e=!0,n=[]){return W0(t,this,n,e),n.sort($u),n}intersectObjects(t,e=!0,n=[]){for(let s=0,r=t.length;s<r;s++)W0(t[s],this,n,e);return n.sort($u),n}};function $u(i,t){return i.distance-t.distance}function W0(i,t,e,n){let s=!0;if(i.layers.test(t.layers)&&i.raycast(t,e)===!1&&(s=!1),s===!0&&n===!0){let r=i.children;for(let a=0,o=r.length;a<o;a++)W0(r[a],t,e,!0)}}var X0=class i{static{i.prototype.isMatrix2=!0}constructor(t,e,n,s){this.elements=[1,0,0,1],t!==void 0&&this.set(t,e,n,s)}identity(){return this.set(1,0,0,1),this}fromArray(t,e=0){for(let n=0;n<4;n++)this.elements[n]=t[n+e];return this}set(t,e,n,s){let r=this.elements;return r[0]=t,r[2]=e,r[1]=n,r[3]=s,this}};function uh(i,t,e,n){let s=m1(n);switch(e){case ih:return i*t;case Hl:return i*t/s.components*s.byteLength;case Vl:return i*t/s.components*s.byteLength;case ps:return i*t*2/s.components*s.byteLength;case Gl:return i*t*2/s.components*s.byteLength;case sh:return i*t*3/s.components*s.byteLength;case Zn:return i*t*4/s.components*s.byteLength;case Wl:return i*t*4/s.components*s.byteLength;case ja:case Qa:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*8;case to:case eo:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*16;case $l:case Yl:return Math.max(i,16)*Math.max(t,8)/4;case Xl:case ql:return Math.max(i,8)*Math.max(t,8)/2;case Zl:case Jl:case jl:case Ql:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*8;case Kl:case no:case tc:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*16;case ec:return Math.floor((i+3)/4)*Math.floor((t+3)/4)*16;case nc:return Math.floor((i+4)/5)*Math.floor((t+3)/4)*16;case ic:return Math.floor((i+4)/5)*Math.floor((t+4)/5)*16;case sc:return Math.floor((i+5)/6)*Math.floor((t+4)/5)*16;case rc:return Math.floor((i+5)/6)*Math.floor((t+5)/6)*16;case ac:return Math.floor((i+7)/8)*Math.floor((t+4)/5)*16;case oc:return Math.floor((i+7)/8)*Math.floor((t+5)/6)*16;case lc:return Math.floor((i+7)/8)*Math.floor((t+7)/8)*16;case cc:return Math.floor((i+9)/10)*Math.floor((t+4)/5)*16;case hc:return Math.floor((i+9)/10)*Math.floor((t+5)/6)*16;case uc:return Math.floor((i+9)/10)*Math.floor((t+7)/8)*16;case dc:return Math.floor((i+9)/10)*Math.floor((t+9)/10)*16;case fc:return Math.floor((i+11)/12)*Math.floor((t+9)/10)*16;case pc:return Math.floor((i+11)/12)*Math.floor((t+11)/12)*16;case mc:case gc:case xc:return Math.ceil(i/4)*Math.ceil(t/4)*16;case _c:case vc:return Math.ceil(i/4)*Math.ceil(t/4)*8;case io:case yc:return Math.ceil(i/4)*Math.ceil(t/4)*16}throw new Error(`Unable to determine texture byte length for ${e} format.`)}function m1(i){switch(i){case Nn:case Q0:return{byteLength:1,components:1};case Ar:case th:case ln:return{byteLength:2,components:1};case zl:case kl:return{byteLength:2,components:4};case hi:case Bl:case Yn:return{byteLength:4,components:1};case eh:case nh:return{byteLength:4,components:3}}throw new Error(`THREE.TextureUtils: Unknown texture type ${i}.`)}typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("register",{detail:{revision:"186"}}));typeof window<"u"&&(window.__THREE__?ue("WARNING: Multiple instances of Three.js being imported."):window.__THREE__="186");function af(){let i=null,t=!1,e=null,n=null;function s(r,a){n=i.requestAnimationFrame(s),e(r,a)}return{start:function(){t!==!0&&e!==null&&i!==null&&(n=i.requestAnimationFrame(s),t=!0)},stop:function(){i!==null&&i.cancelAnimationFrame(n),t=!1},setAnimationLoop:function(r){e=r},setContext:function(r){i=r}}}function y1(i){let t=new WeakMap;function e(o,c){let l=o.array,h=o.usage,f=l.byteLength,u=i.createBuffer();i.bindBuffer(c,u),i.bufferData(c,l,h),o.onUploadCallback();let d;if(l instanceof Float32Array)d=i.FLOAT;else if(typeof Float16Array<"u"&&l instanceof Float16Array)d=i.HALF_FLOAT;else if(l instanceof Uint16Array)o.isFloat16BufferAttribute?d=i.HALF_FLOAT:d=i.UNSIGNED_SHORT;else if(l instanceof Int16Array)d=i.SHORT;else if(l instanceof Uint32Array)d=i.UNSIGNED_INT;else if(l instanceof Int32Array)d=i.INT;else if(l instanceof Int8Array)d=i.BYTE;else if(l instanceof Uint8Array)d=i.UNSIGNED_BYTE;else if(l instanceof Uint8ClampedArray)d=i.UNSIGNED_BYTE;else throw new Error("THREE.WebGLAttributes: Unsupported buffer data format: "+l);return{buffer:u,type:d,bytesPerElement:l.BYTES_PER_ELEMENT,version:o.version,size:f}}function n(o,c,l){let h=c.array,f=c.updateRanges;if(i.bindBuffer(l,o),f.length===0)i.bufferSubData(l,0,h);else{f.sort((d,g)=>d.start-g.start);let u=0;for(let d=1;d<f.length;d++){let g=f[u],_=f[d];_.start<=g.start+g.count+1?g.count=Math.max(g.count,_.start+_.count-g.start):(++u,f[u]=_)}f.length=u+1;for(let d=0,g=f.length;d<g;d++){let _=f[d];i.bufferSubData(l,_.start*h.BYTES_PER_ELEMENT,h,_.start,_.count)}c.clearUpdateRanges()}c.onUploadCallback()}function s(o){return o.isInterleavedBufferAttribute&&(o=o.data),t.get(o)}function r(o){o.isInterleavedBufferAttribute&&(o=o.data);let c=t.get(o);c&&(i.deleteBuffer(c.buffer),t.delete(o))}function a(o,c){if(o.isInterleavedBufferAttribute&&(o=o.data),o.isGLBufferAttribute){let h=t.get(o);(!h||h.version<o.version)&&t.set(o,{buffer:o.buffer,type:o.type,bytesPerElement:o.elementSize,version:o.version});return}let l=t.get(o);if(l===void 0)t.set(o,e(o,c));else if(l.version<o.version){if(l.size!==o.array.byteLength)throw new Error("THREE.WebGLAttributes: The size of the buffer attribute's array buffer does not match the original size. Resizing buffer attributes is not supported.");n(l.buffer,o,c),l.version=o.version}}return{get:s,remove:r,update:a}}var M1=`#ifdef USE_ALPHAHASH
	if ( diffuseColor.a < getAlphaHashThreshold( vPosition ) ) discard;
#endif`,b1=`#ifdef USE_ALPHAHASH
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
#endif`,S1=`#ifdef USE_ALPHAMAP
	diffuseColor.a *= texture2D( alphaMap, vAlphaMapUv ).g;
#endif`,E1=`#ifdef USE_ALPHAMAP
	uniform sampler2D alphaMap;
#endif`,w1=`#ifdef USE_ALPHATEST
	#ifdef ALPHA_TO_COVERAGE
	diffuseColor.a = smoothstep( alphaTest, alphaTest + fwidth( diffuseColor.a ), diffuseColor.a );
	if ( diffuseColor.a == 0.0 ) discard;
	#else
	if ( diffuseColor.a < alphaTest ) discard;
	#endif
#endif`,T1=`#ifdef USE_ALPHATEST
	uniform float alphaTest;
#endif`,A1=`#ifdef USE_AOMAP
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
#endif`,R1=`#ifdef USE_AOMAP
	uniform sampler2D aoMap;
	uniform float aoMapIntensity;
#endif`,C1=`#ifdef USE_BATCHING
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
#endif`,I1=`#ifdef USE_BATCHING
	mat4 batchingMatrix = getBatchingMatrix( getIndirectIndex( gl_DrawID ) );
#endif`,P1=`vec3 transformed = vec3( position );
#ifdef USE_ALPHAHASH
	vPosition = vec3( position );
#endif`,L1=`vec3 objectNormal = vec3( normal );
#ifdef USE_TANGENT
	vec3 objectTangent = vec3( tangent.xyz );
#endif`,N1=`float G_BlinnPhong_Implicit( ) {
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
} // validated`,D1=`#ifdef USE_IRIDESCENCE
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
#endif`,U1=`#ifdef USE_BUMPMAP
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
#endif`,F1=`#if NUM_CLIPPING_PLANES > 0
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
#endif`,O1=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
	uniform vec4 clippingPlanes[ NUM_CLIPPING_PLANES ];
#endif`,B1=`#if NUM_CLIPPING_PLANES > 0
	varying vec3 vClipPosition;
#endif`,z1=`#if NUM_CLIPPING_PLANES > 0
	vClipPosition = - mvPosition.xyz;
#endif`,k1=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA )
	diffuseColor *= vColor;
#endif`,H1=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA )
	varying vec4 vColor;
#endif`,V1=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
	varying vec4 vColor;
#endif`,G1=`#if defined( USE_COLOR ) || defined( USE_COLOR_ALPHA ) || defined( USE_INSTANCING_COLOR ) || defined( USE_BATCHING_COLOR )
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
#endif`,W1=`#define PI 3.141592653589793
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
} // validated`,X1=`#ifdef ENVMAP_TYPE_CUBE_UV
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
#endif`,$1=`vec3 transformedNormal = objectNormal;
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
#endif`,q1=`#ifdef USE_DISPLACEMENTMAP
	uniform sampler2D displacementMap;
	uniform float displacementScale;
	uniform float displacementBias;
#endif`,Y1=`#ifdef USE_DISPLACEMENTMAP
	transformed += normalize( objectNormal ) * ( texture2D( displacementMap, vDisplacementMapUv ).x * displacementScale + displacementBias );
#endif`,Z1=`#ifdef USE_EMISSIVEMAP
	vec4 emissiveColor = texture2D( emissiveMap, vEmissiveMapUv );
	#ifdef DECODE_VIDEO_TEXTURE_EMISSIVE
		emissiveColor = sRGBTransferEOTF( emissiveColor );
	#endif
	totalEmissiveRadiance *= emissiveColor.rgb;
#endif`,J1=`#ifdef USE_EMISSIVEMAP
	uniform sampler2D emissiveMap;
#endif`,K1="gl_FragColor = linearToOutputTexel( gl_FragColor );",j1=`vec4 LinearTransferOETF( in vec4 value ) {
	return value;
}
vec4 sRGBTransferEOTF( in vec4 value ) {
	return vec4( mix( pow( value.rgb * 0.9478672986 + vec3( 0.0521327014 ), vec3( 2.4 ) ), value.rgb * 0.0773993808, vec3( lessThanEqual( value.rgb, vec3( 0.04045 ) ) ) ), value.a );
}
vec4 sRGBTransferOETF( in vec4 value ) {
	return vec4( mix( pow( value.rgb, vec3( 0.41666 ) ) * 1.055 - vec3( 0.055 ), value.rgb * 12.92, vec3( lessThanEqual( value.rgb, vec3( 0.0031308 ) ) ) ), value.a );
}`,Q1=`#ifdef USE_ENVMAP
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
#endif`,tm=`#ifdef USE_ENVMAP
	uniform float envMapIntensity;
	uniform mat3 envMapRotation;
	#ifdef ENVMAP_TYPE_CUBE
		uniform samplerCube envMap;
	#else
		uniform sampler2D envMap;
	#endif
#endif`,em=`#ifdef USE_ENVMAP
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
#endif`,nm=`#ifdef USE_ENVMAP
	#if defined( USE_BUMPMAP ) || defined( USE_NORMALMAP ) || defined( PHONG ) || defined( LAMBERT )
		#define ENV_WORLDPOS
	#endif
	#ifdef ENV_WORLDPOS
		
		varying vec3 vWorldPosition;
	#else
		varying vec3 vReflect;
		uniform float refractionRatio;
	#endif
#endif`,im=`#ifdef USE_ENVMAP
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
#endif`,sm=`#ifdef USE_FOG
	vFogDepth = - mvPosition.z;
#endif`,rm=`#ifdef USE_FOG
	varying float vFogDepth;
#endif`,am=`#ifdef USE_FOG
	#ifdef FOG_EXP2
		float fogFactor = 1.0 - exp( - fogDensity * fogDensity * vFogDepth * vFogDepth );
	#else
		float fogFactor = smoothstep( fogNear, fogFar, vFogDepth );
	#endif
	gl_FragColor.rgb = mix( gl_FragColor.rgb, fogColor, fogFactor );
#endif`,om=`#ifdef USE_FOG
	uniform vec3 fogColor;
	varying float vFogDepth;
	#ifdef FOG_EXP2
		uniform float fogDensity;
	#else
		uniform float fogNear;
		uniform float fogFar;
	#endif
#endif`,lm=`#ifdef USE_GRADIENTMAP
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
}`,cm=`#ifdef USE_LIGHTMAP
	uniform sampler2D lightMap;
	uniform float lightMapIntensity;
#endif`,hm=`LambertMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularStrength = specularStrength;`,um=`varying vec3 vViewPosition;
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
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Lambert`,dm=`uniform bool receiveShadow;
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
#include <lightprobes_pars_fragment>`,fm=`#ifdef USE_ENVMAP
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
#endif`,pm=`ToonMaterial material;
material.diffuseColor = diffuseColor.rgb;`,mm=`varying vec3 vViewPosition;
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
#define RE_IndirectDiffuse		RE_IndirectDiffuse_Toon`,gm=`BlinnPhongMaterial material;
material.diffuseColor = diffuseColor.rgb;
material.specularColor = specular;
material.specularShininess = shininess;
material.specularStrength = specularStrength;`,xm=`varying vec3 vViewPosition;
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
#define RE_IndirectDiffuse		RE_IndirectDiffuse_BlinnPhong`,_m=`PhysicalMaterial material;
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
#endif`,vm=`uniform sampler2D dfgLUT;
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
}`,ym=`
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
#endif`,Mm=`#if defined( RE_IndirectDiffuse )
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
#endif`,bm=`#if defined( RE_IndirectDiffuse )
	#if defined( LAMBERT ) || defined( PHONG )
		irradiance += iblIrradiance;
	#endif
	RE_IndirectDiffuse( irradiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif
#if defined( RE_IndirectSpecular )
	RE_IndirectSpecular( radiance, iblIrradiance, clearcoatRadiance, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );
#endif`,Sm=`#ifdef USE_LIGHT_PROBES_GRID
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
#endif`,Em=`#if defined( USE_LOGARITHMIC_DEPTH_BUFFER )
	gl_FragDepth = vIsPerspective == 0.0 ? gl_FragCoord.z : log2( vFragDepth ) * logDepthBufFC * 0.5;
#endif`,wm=`#if defined( USE_LOGARITHMIC_DEPTH_BUFFER )
	uniform float logDepthBufFC;
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,Tm=`#ifdef USE_LOGARITHMIC_DEPTH_BUFFER
	varying float vFragDepth;
	varying float vIsPerspective;
#endif`,Am=`#ifdef USE_LOGARITHMIC_DEPTH_BUFFER
	vFragDepth = 1.0 + gl_Position.w;
	vIsPerspective = float( isPerspectiveMatrix( projectionMatrix ) );
#endif`,Rm=`#ifdef USE_MAP
	vec4 sampledDiffuseColor = texture2D( map, vMapUv );
	#ifdef DECODE_VIDEO_TEXTURE
		sampledDiffuseColor = sRGBTransferEOTF( sampledDiffuseColor );
	#endif
	diffuseColor *= sampledDiffuseColor;
#endif`,Cm=`#ifdef USE_MAP
	uniform sampler2D map;
#endif`,Im=`#if defined( USE_MAP ) || defined( USE_ALPHAMAP )
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
#endif`,Pm=`#if defined( USE_POINTS_UV )
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
#endif`,Lm=`float metalnessFactor = metalness;
#ifdef USE_METALNESSMAP
	vec4 texelMetalness = texture2D( metalnessMap, vMetalnessMapUv );
	metalnessFactor *= texelMetalness.b;
#endif`,Nm=`#ifdef USE_METALNESSMAP
	uniform sampler2D metalnessMap;
#endif`,Dm=`#ifdef USE_INSTANCING_MORPH
	float morphTargetInfluences[ MORPHTARGETS_COUNT ];
	float morphTargetBaseInfluence = texelFetch( morphTexture, ivec2( 0, gl_InstanceID ), 0 ).r;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		morphTargetInfluences[i] =  texelFetch( morphTexture, ivec2( i + 1, gl_InstanceID ), 0 ).r;
	}
#endif`,Um=`#if defined( USE_MORPHCOLORS )
	vColor *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		#if defined( USE_COLOR_ALPHA )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ) * morphTargetInfluences[ i ];
		#elif defined( USE_COLOR )
			if ( morphTargetInfluences[ i ] != 0.0 ) vColor += getMorph( gl_VertexID, i, 2 ).rgb * morphTargetInfluences[ i ];
		#endif
	}
#endif`,Fm=`#ifdef USE_MORPHNORMALS
	objectNormal *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) objectNormal += getMorph( gl_VertexID, i, 1 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,Om=`#ifdef USE_MORPHTARGETS
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
#endif`,Bm=`#ifdef USE_MORPHTARGETS
	transformed *= morphTargetBaseInfluence;
	for ( int i = 0; i < MORPHTARGETS_COUNT; i ++ ) {
		if ( morphTargetInfluences[ i ] != 0.0 ) transformed += getMorph( gl_VertexID, i, 0 ).xyz * morphTargetInfluences[ i ];
	}
#endif`,zm=`float faceDirection = gl_FrontFacing ? 1.0 : - 1.0;
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
vec3 nonPerturbedNormal = normal;`,km=`#ifdef USE_NORMALMAP_OBJECTSPACE
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
#endif`,Hm=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,Vm=`#ifndef FLAT_SHADED
	varying vec3 vNormal;
	#ifdef USE_TANGENT
		varying vec3 vTangent;
		varying vec3 vBitangent;
	#endif
#endif`,Gm=`#ifndef FLAT_SHADED
	vNormal = normalize( transformedNormal );
	#ifdef USE_TANGENT
		vTangent = normalize( transformedTangent );
		vBitangent = normalize( cross( vNormal, vTangent ) * tangent.w );
		#ifdef FLIP_SIDED
			vBitangent = - vBitangent;
		#endif
	#endif
#endif`,Wm=`#ifdef USE_NORMALMAP
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
#endif`,Xm=`#ifdef USE_CLEARCOAT
	vec3 clearcoatNormal = nonPerturbedNormal;
#endif`,$m=`#ifdef USE_CLEARCOAT_NORMALMAP
	vec3 clearcoatMapN = texture2D( clearcoatNormalMap, vClearcoatNormalMapUv ).xyz * 2.0 - 1.0;
	clearcoatMapN.xy *= clearcoatNormalScale;
	clearcoatNormal = normalize( tbn2 * clearcoatMapN );
#endif`,qm=`#ifdef USE_CLEARCOATMAP
	uniform sampler2D clearcoatMap;
#endif
#ifdef USE_CLEARCOAT_NORMALMAP
	uniform sampler2D clearcoatNormalMap;
	uniform vec2 clearcoatNormalScale;
#endif
#ifdef USE_CLEARCOAT_ROUGHNESSMAP
	uniform sampler2D clearcoatRoughnessMap;
#endif`,Ym=`#ifdef USE_IRIDESCENCEMAP
	uniform sampler2D iridescenceMap;
#endif
#ifdef USE_IRIDESCENCE_THICKNESSMAP
	uniform sampler2D iridescenceThicknessMap;
#endif`,Zm=`#ifdef OPAQUE
diffuseColor.a = 1.0;
#endif
#ifdef USE_TRANSMISSION
diffuseColor.a *= material.transmissionAlpha;
#endif
gl_FragColor = vec4( outgoingLight, diffuseColor.a );`,Jm=`vec3 packNormalToRGB( const in vec3 normal ) {
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
}`,Km=`#ifdef PREMULTIPLIED_ALPHA
	gl_FragColor.rgb *= gl_FragColor.a;
#endif`,jm=`vec4 mvPosition = vec4( transformed, 1.0 );
#ifdef USE_BATCHING
	mvPosition = batchingMatrix * mvPosition;
#endif
#ifdef USE_INSTANCING
	mvPosition = instanceMatrix * mvPosition;
#endif
mvPosition = modelViewMatrix * mvPosition;
gl_Position = projectionMatrix * mvPosition;`,Qm=`#ifdef DITHERING
	gl_FragColor.rgb = dithering( gl_FragColor.rgb );
#endif`,tg=`#ifdef DITHERING
	vec3 dithering( vec3 color ) {
		float grid_position = rand( gl_FragCoord.xy );
		vec3 dither_shift_RGB = vec3( 0.25 / 255.0, -0.25 / 255.0, 0.25 / 255.0 );
		dither_shift_RGB = mix( 2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position );
		return color + dither_shift_RGB;
	}
#endif`,eg=`float roughnessFactor = roughness;
#ifdef USE_ROUGHNESSMAP
	vec4 texelRoughness = texture2D( roughnessMap, vRoughnessMapUv );
	roughnessFactor *= texelRoughness.g;
#endif`,ng=`#ifdef USE_ROUGHNESSMAP
	uniform sampler2D roughnessMap;
#endif`,ig=`#if NUM_SPOT_LIGHT_COORDS > 0
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
#endif`,sg=`#if NUM_SPOT_LIGHT_COORDS > 0
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
#endif`,rg=`#if ( defined( USE_SHADOWMAP ) && ( NUM_DIR_LIGHT_SHADOWS > 0 || NUM_SUN_LIGHT_SHADOWS > 0 || NUM_POINT_LIGHT_SHADOWS > 0 ) ) || ( NUM_SPOT_LIGHT_COORDS > 0 )
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
#endif`,ag=`float getShadowMask() {
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
}`,og=`#ifdef USE_SKINNING
	mat4 boneMatX = getBoneMatrix( skinIndex.x );
	mat4 boneMatY = getBoneMatrix( skinIndex.y );
	mat4 boneMatZ = getBoneMatrix( skinIndex.z );
	mat4 boneMatW = getBoneMatrix( skinIndex.w );
#endif`,lg=`#ifdef USE_SKINNING
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
#endif`,cg=`#ifdef USE_SKINNING
	vec4 skinVertex = bindMatrix * vec4( transformed, 1.0 );
	vec4 skinned = vec4( 0.0 );
	skinned += boneMatX * skinVertex * skinWeight.x;
	skinned += boneMatY * skinVertex * skinWeight.y;
	skinned += boneMatZ * skinVertex * skinWeight.z;
	skinned += boneMatW * skinVertex * skinWeight.w;
	transformed = ( bindMatrixInverse * skinned ).xyz;
#endif`,hg=`#ifdef USE_SKINNING
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
#endif`,ug=`float specularStrength;
#ifdef USE_SPECULARMAP
	vec4 texelSpecular = texture2D( specularMap, vSpecularMapUv );
	specularStrength = texelSpecular.r;
#else
	specularStrength = 1.0;
#endif`,dg=`#ifdef USE_SPECULARMAP
	uniform sampler2D specularMap;
#endif`,fg=`#if defined( TONE_MAPPING )
	gl_FragColor.rgb = toneMapping( gl_FragColor.rgb );
#endif`,pg=`#ifndef saturate
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
vec3 CustomToneMapping( vec3 color ) { return color; }`,mg=`#ifdef USE_TRANSMISSION
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
#endif`,gg=`#ifdef USE_TRANSMISSION
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
#endif`,xg=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
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
#endif`,_g=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
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
#endif`,vg=`#if defined( USE_UV ) || defined( USE_ANISOTROPY )
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
#endif`,yg=`#if defined( USE_ENVMAP ) || defined( DISTANCE ) || defined ( USE_SHADOWMAP ) || defined ( USE_TRANSMISSION ) || NUM_SPOT_LIGHT_COORDS > 0
	vec4 worldPosition = vec4( transformed, 1.0 );
	#ifdef USE_BATCHING
		worldPosition = batchingMatrix * worldPosition;
	#endif
	#ifdef USE_INSTANCING
		worldPosition = instanceMatrix * worldPosition;
	#endif
	worldPosition = modelMatrix * worldPosition;
#endif`,Mg=`varying vec2 vUv;
uniform mat3 uvTransform;
void main() {
	vUv = ( uvTransform * vec3( uv, 1 ) ).xy;
	gl_Position = vec4( position.xy, 1.0, 1.0 );
}`,bg=`uniform sampler2D t2D;
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
}`,Sg=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,Eg=`#ifdef ENVMAP_TYPE_CUBE
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
}`,wg=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
	gl_Position.z = gl_Position.w;
}`,Tg=`uniform samplerCube tCube;
uniform float tFlip;
uniform float opacity;
varying vec3 vWorldDirection;
void main() {
	vec4 texColor = textureCube( tCube, vec3( tFlip * vWorldDirection.x, vWorldDirection.yz ) );
	gl_FragColor = texColor;
	gl_FragColor.a *= opacity;
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,Ag=`#include <common>
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
}`,Rg=`#if DEPTH_PACKING == 3200
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
}`,Cg=`#define DISTANCE
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
}`,Ig=`#define DISTANCE
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
}`,Pg=`varying vec3 vWorldDirection;
#include <common>
void main() {
	vWorldDirection = transformDirection( position, modelMatrix );
	#include <begin_vertex>
	#include <project_vertex>
}`,Lg=`uniform sampler2D tEquirect;
varying vec3 vWorldDirection;
#include <common>
void main() {
	vec3 direction = normalize( vWorldDirection );
	vec2 sampleUV = equirectUv( direction );
	gl_FragColor = texture2D( tEquirect, sampleUV );
	#include <tonemapping_fragment>
	#include <colorspace_fragment>
}`,Ng=`uniform float scale;
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
}`,Dg=`uniform vec3 diffuse;
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
}`,Ug=`#include <common>
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
}`,Fg=`uniform vec3 diffuse;
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
}`,Og=`#define LAMBERT
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
}`,Bg=`#define LAMBERT
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
}`,zg=`#define MATCAP
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
}`,kg=`#define MATCAP
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
}`,Hg=`#define NORMAL
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
}`,Vg=`#define NORMAL
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
}`,Gg=`#define PHONG
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
}`,Wg=`#define PHONG
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
}`,Xg=`#define STANDARD
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
}`,$g=`#define STANDARD
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
}`,qg=`#define TOON
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
}`,Yg=`#define TOON
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
}`,Zg=`uniform float size;
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
}`,Jg=`uniform vec3 diffuse;
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
}`,Kg=`#include <common>
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
}`,jg=`uniform vec3 color;
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
}`,Qg=`uniform float rotation;
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
}`,t2=`uniform vec3 diffuse;
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
}`,Me={alphahash_fragment:M1,alphahash_pars_fragment:b1,alphamap_fragment:S1,alphamap_pars_fragment:E1,alphatest_fragment:w1,alphatest_pars_fragment:T1,aomap_fragment:A1,aomap_pars_fragment:R1,batching_pars_vertex:C1,batching_vertex:I1,begin_vertex:P1,beginnormal_vertex:L1,bsdfs:N1,iridescence_fragment:D1,bumpmap_pars_fragment:U1,clipping_planes_fragment:F1,clipping_planes_pars_fragment:O1,clipping_planes_pars_vertex:B1,clipping_planes_vertex:z1,color_fragment:k1,color_pars_fragment:H1,color_pars_vertex:V1,color_vertex:G1,common:W1,cube_uv_reflection_fragment:X1,defaultnormal_vertex:$1,displacementmap_pars_vertex:q1,displacementmap_vertex:Y1,emissivemap_fragment:Z1,emissivemap_pars_fragment:J1,colorspace_fragment:K1,colorspace_pars_fragment:j1,envmap_fragment:Q1,envmap_common_pars_fragment:tm,envmap_pars_fragment:em,envmap_pars_vertex:nm,envmap_physical_pars_fragment:fm,envmap_vertex:im,fog_vertex:sm,fog_pars_vertex:rm,fog_fragment:am,fog_pars_fragment:om,gradientmap_pars_fragment:lm,lightmap_pars_fragment:cm,lights_lambert_fragment:hm,lights_lambert_pars_fragment:um,lights_pars_begin:dm,lights_toon_fragment:pm,lights_toon_pars_fragment:mm,lights_phong_fragment:gm,lights_phong_pars_fragment:xm,lights_physical_fragment:_m,lights_physical_pars_fragment:vm,lights_fragment_begin:ym,lights_fragment_maps:Mm,lights_fragment_end:bm,lightprobes_pars_fragment:Sm,logdepthbuf_fragment:Em,logdepthbuf_pars_fragment:wm,logdepthbuf_pars_vertex:Tm,logdepthbuf_vertex:Am,map_fragment:Rm,map_pars_fragment:Cm,map_particle_fragment:Im,map_particle_pars_fragment:Pm,metalnessmap_fragment:Lm,metalnessmap_pars_fragment:Nm,morphinstance_vertex:Dm,morphcolor_vertex:Um,morphnormal_vertex:Fm,morphtarget_pars_vertex:Om,morphtarget_vertex:Bm,normal_fragment_begin:zm,normal_fragment_maps:km,normal_pars_fragment:Hm,normal_pars_vertex:Vm,normal_vertex:Gm,normalmap_pars_fragment:Wm,clearcoat_normal_fragment_begin:Xm,clearcoat_normal_fragment_maps:$m,clearcoat_pars_fragment:qm,iridescence_pars_fragment:Ym,opaque_fragment:Zm,packing:Jm,premultiplied_alpha_fragment:Km,project_vertex:jm,dithering_fragment:Qm,dithering_pars_fragment:tg,roughnessmap_fragment:eg,roughnessmap_pars_fragment:ng,shadowmap_pars_fragment:ig,shadowmap_pars_vertex:sg,shadowmap_vertex:rg,shadowmask_pars_fragment:ag,skinbase_vertex:og,skinning_pars_vertex:lg,skinning_vertex:cg,skinnormal_vertex:hg,specularmap_fragment:ug,specularmap_pars_fragment:dg,tonemapping_fragment:fg,tonemapping_pars_fragment:pg,transmission_fragment:mg,transmission_pars_fragment:gg,uv_pars_fragment:xg,uv_pars_vertex:_g,uv_vertex:vg,worldpos_vertex:yg,background_vert:Mg,background_frag:bg,backgroundCube_vert:Sg,backgroundCube_frag:Eg,cube_vert:wg,cube_frag:Tg,depth_vert:Ag,depth_frag:Rg,distance_vert:Cg,distance_frag:Ig,equirect_vert:Pg,equirect_frag:Lg,linedashed_vert:Ng,linedashed_frag:Dg,meshbasic_vert:Ug,meshbasic_frag:Fg,meshlambert_vert:Og,meshlambert_frag:Bg,meshmatcap_vert:zg,meshmatcap_frag:kg,meshnormal_vert:Hg,meshnormal_frag:Vg,meshphong_vert:Gg,meshphong_frag:Wg,meshphysical_vert:Xg,meshphysical_frag:$g,meshtoon_vert:qg,meshtoon_frag:Yg,points_vert:Zg,points_frag:Jg,shadow_vert:Kg,shadow_frag:jg,sprite_vert:Qg,sprite_frag:t2},Vt={common:{diffuse:{value:new se(16777215)},opacity:{value:1},map:{value:null},mapTransform:{value:new me},alphaMap:{value:null},alphaMapTransform:{value:new me},alphaTest:{value:0}},specularmap:{specularMap:{value:null},specularMapTransform:{value:new me}},envmap:{envMap:{value:null},envMapRotation:{value:new me},reflectivity:{value:1},ior:{value:1.5},refractionRatio:{value:.98},dfgLUT:{value:null}},aomap:{aoMap:{value:null},aoMapIntensity:{value:1},aoMapTransform:{value:new me}},lightmap:{lightMap:{value:null},lightMapIntensity:{value:1},lightMapTransform:{value:new me}},bumpmap:{bumpMap:{value:null},bumpMapTransform:{value:new me},bumpScale:{value:1}},normalmap:{normalMap:{value:null},normalMapTransform:{value:new me},normalScale:{value:new vt(1,1)}},displacementmap:{displacementMap:{value:null},displacementMapTransform:{value:new me},displacementScale:{value:1},displacementBias:{value:0}},emissivemap:{emissiveMap:{value:null},emissiveMapTransform:{value:new me}},metalnessmap:{metalnessMap:{value:null},metalnessMapTransform:{value:new me}},roughnessmap:{roughnessMap:{value:null},roughnessMapTransform:{value:new me}},gradientmap:{gradientMap:{value:null}},fog:{fogDensity:{value:25e-5},fogNear:{value:1},fogFar:{value:2e3},fogColor:{value:new se(16777215)}},lights:{ambientLightColor:{value:[]},lightProbe:{value:[]},sunLights:{value:[],properties:{direction:{},color:{}}},sunLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},sunShadowMatrix:{value:[]},sunShadowCascade:{value:[]},directionalLights:{value:[],properties:{direction:{},color:{}}},directionalLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},directionalShadowMatrix:{value:[]},spotLights:{value:[],properties:{color:{},position:{},direction:{},distance:{},coneCos:{},penumbraCos:{},decay:{}}},spotLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{}}},spotLightMap:{value:[]},spotLightMatrix:{value:[]},pointLights:{value:[],properties:{color:{},position:{},decay:{},distance:{}}},pointLightShadows:{value:[],properties:{shadowIntensity:1,shadowBias:{},shadowNormalBias:{},shadowRadius:{},shadowMapSize:{},shadowCameraNear:{},shadowCameraFar:{}}},pointShadowMatrix:{value:[]},hemisphereLights:{value:[],properties:{direction:{},skyColor:{},groundColor:{}}},rectAreaLights:{value:[],properties:{color:{},position:{},width:{},height:{}}},ltc_1:{value:null},ltc_2:{value:null},probesSH:{value:null},probesMin:{value:new D},probesMax:{value:new D},probesResolution:{value:new D}},points:{diffuse:{value:new se(16777215)},opacity:{value:1},size:{value:1},scale:{value:1},map:{value:null},alphaMap:{value:null},alphaMapTransform:{value:new me},alphaTest:{value:0},uvTransform:{value:new me}},sprite:{diffuse:{value:new se(16777215)},opacity:{value:1},center:{value:new vt(.5,.5)},rotation:{value:0},map:{value:null},mapTransform:{value:new me},alphaMap:{value:null},alphaMapTransform:{value:new me},alphaTest:{value:0}}},wi={basic:{uniforms:Cn([Vt.common,Vt.specularmap,Vt.envmap,Vt.aomap,Vt.lightmap,Vt.fog]),vertexShader:Me.meshbasic_vert,fragmentShader:Me.meshbasic_frag},lambert:{uniforms:Cn([Vt.common,Vt.specularmap,Vt.envmap,Vt.aomap,Vt.lightmap,Vt.emissivemap,Vt.bumpmap,Vt.normalmap,Vt.displacementmap,Vt.fog,Vt.lights,{emissive:{value:new se(0)},envMapIntensity:{value:1}}]),vertexShader:Me.meshlambert_vert,fragmentShader:Me.meshlambert_frag},phong:{uniforms:Cn([Vt.common,Vt.specularmap,Vt.envmap,Vt.aomap,Vt.lightmap,Vt.emissivemap,Vt.bumpmap,Vt.normalmap,Vt.displacementmap,Vt.fog,Vt.lights,{emissive:{value:new se(0)},specular:{value:new se(1118481)},shininess:{value:30},envMapIntensity:{value:1}}]),vertexShader:Me.meshphong_vert,fragmentShader:Me.meshphong_frag},standard:{uniforms:Cn([Vt.common,Vt.envmap,Vt.aomap,Vt.lightmap,Vt.emissivemap,Vt.bumpmap,Vt.normalmap,Vt.displacementmap,Vt.roughnessmap,Vt.metalnessmap,Vt.fog,Vt.lights,{emissive:{value:new se(0)},roughness:{value:1},metalness:{value:0},envMapIntensity:{value:1}}]),vertexShader:Me.meshphysical_vert,fragmentShader:Me.meshphysical_frag},toon:{uniforms:Cn([Vt.common,Vt.aomap,Vt.lightmap,Vt.emissivemap,Vt.bumpmap,Vt.normalmap,Vt.displacementmap,Vt.gradientmap,Vt.fog,Vt.lights,{emissive:{value:new se(0)}}]),vertexShader:Me.meshtoon_vert,fragmentShader:Me.meshtoon_frag},matcap:{uniforms:Cn([Vt.common,Vt.bumpmap,Vt.normalmap,Vt.displacementmap,Vt.fog,{matcap:{value:null}}]),vertexShader:Me.meshmatcap_vert,fragmentShader:Me.meshmatcap_frag},points:{uniforms:Cn([Vt.points,Vt.fog]),vertexShader:Me.points_vert,fragmentShader:Me.points_frag},dashed:{uniforms:Cn([Vt.common,Vt.fog,{scale:{value:1},dashSize:{value:1},totalSize:{value:2}}]),vertexShader:Me.linedashed_vert,fragmentShader:Me.linedashed_frag},depth:{uniforms:Cn([Vt.common,Vt.displacementmap]),vertexShader:Me.depth_vert,fragmentShader:Me.depth_frag},normal:{uniforms:Cn([Vt.common,Vt.bumpmap,Vt.normalmap,Vt.displacementmap,{opacity:{value:1}}]),vertexShader:Me.meshnormal_vert,fragmentShader:Me.meshnormal_frag},sprite:{uniforms:Cn([Vt.sprite,Vt.fog]),vertexShader:Me.sprite_vert,fragmentShader:Me.sprite_frag},background:{uniforms:{uvTransform:{value:new me},t2D:{value:null},backgroundIntensity:{value:1}},vertexShader:Me.background_vert,fragmentShader:Me.background_frag},backgroundCube:{uniforms:{envMap:{value:null},backgroundBlurriness:{value:0},backgroundIntensity:{value:1},backgroundRotation:{value:new me}},vertexShader:Me.backgroundCube_vert,fragmentShader:Me.backgroundCube_frag},cube:{uniforms:{tCube:{value:null},tFlip:{value:-1},opacity:{value:1}},vertexShader:Me.cube_vert,fragmentShader:Me.cube_frag},equirect:{uniforms:{tEquirect:{value:null}},vertexShader:Me.equirect_vert,fragmentShader:Me.equirect_frag},distance:{uniforms:Cn([Vt.common,Vt.displacementmap,{referencePosition:{value:new D},nearDistance:{value:1},farDistance:{value:1e3}}]),vertexShader:Me.distance_vert,fragmentShader:Me.distance_frag},shadow:{uniforms:Cn([Vt.lights,Vt.fog,{color:{value:new se(0)},opacity:{value:1}}]),vertexShader:Me.shadow_vert,fragmentShader:Me.shadow_frag}};wi.physical={uniforms:Cn([wi.standard.uniforms,{clearcoat:{value:0},clearcoatMap:{value:null},clearcoatMapTransform:{value:new me},clearcoatNormalMap:{value:null},clearcoatNormalMapTransform:{value:new me},clearcoatNormalScale:{value:new vt(1,1)},clearcoatRoughness:{value:0},clearcoatRoughnessMap:{value:null},clearcoatRoughnessMapTransform:{value:new me},dispersion:{value:0},retroreflectivity:{value:0},iridescence:{value:0},iridescenceMap:{value:null},iridescenceMapTransform:{value:new me},iridescenceIOR:{value:1.3},iridescenceThicknessMinimum:{value:100},iridescenceThicknessMaximum:{value:400},iridescenceThicknessMap:{value:null},iridescenceThicknessMapTransform:{value:new me},sheen:{value:0},sheenColor:{value:new se(0)},sheenColorMap:{value:null},sheenColorMapTransform:{value:new me},sheenRoughness:{value:1},sheenRoughnessMap:{value:null},sheenRoughnessMapTransform:{value:new me},transmission:{value:0},transmissionMap:{value:null},transmissionMapTransform:{value:new me},transmissionSamplerSize:{value:new vt},transmissionSamplerMap:{value:null},thickness:{value:0},thicknessMap:{value:null},thicknessMapTransform:{value:new me},attenuationDistance:{value:0},attenuationColor:{value:new se(0)},specularColor:{value:new se(1,1,1)},specularColorMap:{value:null},specularColorMapTransform:{value:new me},specularIntensity:{value:1},specularIntensityMap:{value:null},specularIntensityMapTransform:{value:new me},anisotropyVector:{value:new vt},anisotropyMap:{value:null},anisotropyMapTransform:{value:new me}}]),vertexShader:Me.meshphysical_vert,fragmentShader:Me.meshphysical_frag};var Ec={r:0,b:0,g:0},e2=new Ce,of=new me;of.set(-1,0,0,0,1,0,0,0,1);function n2(i,t,e,n,s,r){let a=new se(0),o=s===!0?0:1,c,l,h=null,f=0,u=null;function d(S){let w=S.isScene===!0?S.background:null;if(w&&w.isTexture){let y=S.backgroundBlurriness>0;w=t.get(w,y)}return w}function g(S){let w=!1,y=d(S);y===null?m(a,o):y&&y.isColor&&(m(y,1),w=!0);let E=i.xr.getEnvironmentBlendMode();E==="additive"?e.buffers.color.setClear(0,0,0,1,r):E==="alpha-blend"&&e.buffers.color.setClear(0,0,0,0,r),(i.autoClear||w)&&(e.buffers.depth.setTest(!0),e.buffers.depth.setMask(!0),e.buffers.color.setMask(!0),i.clear(i.autoClearColor,i.autoClearDepth,i.autoClearStencil))}function _(S,w){let y=d(w);y&&(y.isCubeTexture||y.mapping===Ja)?(l===void 0&&(l=new ve(new mr(1,1,1),new Oe({name:"BackgroundCubeMaterial",uniforms:Rs(wi.backgroundCube.uniforms),vertexShader:wi.backgroundCube.vertexShader,fragmentShader:wi.backgroundCube.fragmentShader,side:bn,depthTest:!1,depthWrite:!1,fog:!1,allowOverride:!1})),l.geometry.deleteAttribute("normal"),l.geometry.deleteAttribute("uv"),l.onBeforeRender=function(E,M,I){this.matrixWorld.copyPosition(I.matrixWorld)},Object.defineProperty(l.material,"envMap",{get:function(){return this.uniforms.envMap.value}}),n.update(l)),l.material.uniforms.envMap.value=y,l.material.uniforms.backgroundBlurriness.value=w.backgroundBlurriness,l.material.uniforms.backgroundIntensity.value=w.backgroundIntensity,l.material.uniforms.backgroundRotation.value.setFromMatrix4(e2.makeRotationFromEuler(w.backgroundRotation)).transpose(),y.isCubeTexture&&y.isRenderTargetTexture===!1&&l.material.uniforms.backgroundRotation.value.premultiply(of),l.material.toneMapped=Se.getTransfer(y.colorSpace)!==Le,(h!==y||f!==y.version||u!==i.toneMapping)&&(l.material.needsUpdate=!0,h=y,f=y.version,u=i.toneMapping),l.layers.enableAll(),S.unshift(l,l.geometry,l.material,0,0,null)):y&&y.isTexture&&(c===void 0&&(c=new ve(new rs(2,2),new Oe({name:"BackgroundMaterial",uniforms:Rs(wi.background.uniforms),vertexShader:wi.background.vertexShader,fragmentShader:wi.background.fragmentShader,side:hs,depthTest:!1,depthWrite:!1,fog:!1,allowOverride:!1})),c.geometry.deleteAttribute("normal"),Object.defineProperty(c.material,"map",{get:function(){return this.uniforms.t2D.value}}),n.update(c)),c.material.uniforms.t2D.value=y,c.material.uniforms.backgroundIntensity.value=w.backgroundIntensity,c.material.toneMapped=Se.getTransfer(y.colorSpace)!==Le,y.matrixAutoUpdate===!0&&y.updateMatrix(),c.material.uniforms.uvTransform.value.copy(y.matrix),(h!==y||f!==y.version||u!==i.toneMapping)&&(c.material.needsUpdate=!0,h=y,f=y.version,u=i.toneMapping),c.layers.enableAll(),S.unshift(c,c.geometry,c.material,0,0,null))}function m(S,w){S.getRGB(Ec,lh(i)),e.buffers.color.setClear(Ec.r,Ec.g,Ec.b,w,r)}function p(){l!==void 0&&(l.geometry.dispose(),l.material.dispose(),l=void 0),c!==void 0&&(c.geometry.dispose(),c.material.dispose(),c=void 0)}return{getClearColor:function(){return a},setClearColor:function(S,w=1){a.set(S),o=w,m(a,o)},getClearAlpha:function(){return o},setClearAlpha:function(S){o=S,m(a,o)},render:g,addToRenderList:_,dispose:p}}function i2(i,t){let e=i.getParameter(i.MAX_VERTEX_ATTRIBS),n={},s=u(null),r=s,a=!1;function o(N,P,B,F,W){let rt=!1,nt=f(N,F,B,P);r!==nt&&(r=nt,l(r.object)),rt=d(N,F,B,W),rt&&g(N,F,B,W),W!==null&&t.update(W,i.ELEMENT_ARRAY_BUFFER),(rt||a)&&(a=!1,y(N,P,B,F),W!==null&&i.bindBuffer(i.ELEMENT_ARRAY_BUFFER,t.get(W).buffer))}function c(){return i.createVertexArray()}function l(N){return i.bindVertexArray(N)}function h(N){return i.deleteVertexArray(N)}function f(N,P,B,F){let W=F.wireframe===!0,rt=n[P.id];rt===void 0&&(rt={},n[P.id]=rt);let nt=N.isInstancedMesh===!0?N.id:0,dt=rt[nt];dt===void 0&&(dt={},rt[nt]=dt);let Q=dt[B.id];Q===void 0&&(Q={},dt[B.id]=Q);let ct=Q[W];return ct===void 0&&(ct=u(c()),Q[W]=ct),ct}function u(N){let P=[],B=[],F=[];for(let W=0;W<e;W++)P[W]=0,B[W]=0,F[W]=0;return{geometry:null,program:null,wireframe:!1,newAttributes:P,enabledAttributes:B,attributeDivisors:F,object:N,attributes:{},index:null}}function d(N,P,B,F){let W=r.attributes,rt=P.attributes,nt=0,dt=B.getAttributes();for(let Q in dt)if(dt[Q].location>=0){let O=W[Q],St=rt[Q];if(St===void 0&&(Q==="instanceMatrix"&&N.instanceMatrix&&(St=N.instanceMatrix),Q==="instanceColor"&&N.instanceColor&&(St=N.instanceColor)),O===void 0||O.attribute!==St||St&&O.data!==St.data)return!0;nt++}return r.attributesNum!==nt||r.index!==F}function g(N,P,B,F){let W={},rt=P.attributes,nt=0,dt=B.getAttributes();for(let Q in dt)if(dt[Q].location>=0){let O=rt[Q];O===void 0&&(Q==="instanceMatrix"&&N.instanceMatrix&&(O=N.instanceMatrix),Q==="instanceColor"&&N.instanceColor&&(O=N.instanceColor));let St={};St.attribute=O,O&&O.data&&(St.data=O.data),W[Q]=St,nt++}r.attributes=W,r.attributesNum=nt,r.index=F}function _(){let N=r.newAttributes;for(let P=0,B=N.length;P<B;P++)N[P]=0}function m(N){p(N,0)}function p(N,P){let B=r.newAttributes,F=r.enabledAttributes,W=r.attributeDivisors;B[N]=1,F[N]===0&&(i.enableVertexAttribArray(N),F[N]=1),W[N]!==P&&(i.vertexAttribDivisor(N,P),W[N]=P)}function S(){let N=r.newAttributes,P=r.enabledAttributes;for(let B=0,F=P.length;B<F;B++)P[B]!==N[B]&&(i.disableVertexAttribArray(B),P[B]=0)}function w(N,P,B,F,W,rt,nt){nt===!0?i.vertexAttribIPointer(N,P,B,W,rt):i.vertexAttribPointer(N,P,B,F,W,rt)}function y(N,P,B,F){_();let W=F.attributes,rt=B.getAttributes(),nt=P.defaultAttributeValues;for(let dt in rt){let Q=rt[dt];if(Q.location>=0){let ct=W[dt];if(ct===void 0&&(dt==="instanceMatrix"&&N.instanceMatrix&&(ct=N.instanceMatrix),dt==="instanceColor"&&N.instanceColor&&(ct=N.instanceColor)),ct!==void 0){let O=ct.normalized,St=ct.itemSize,Et=t.get(ct);if(Et===void 0)continue;let At=Et.buffer,Ot=Et.type,Dt=Et.bytesPerElement,tt=Ot===i.INT||Ot===i.UNSIGNED_INT||ct.gpuType===Bl;if(ct.isInterleavedBufferAttribute){let it=ct.data,_t=it.stride,bt=ct.offset;if(it.isInstancedInterleavedBuffer){for(let mt=0;mt<Q.locationSize;mt++)p(Q.location+mt,it.meshPerAttribute);N.isInstancedMesh!==!0&&F._maxInstanceCount===void 0&&(F._maxInstanceCount=it.meshPerAttribute*it.count)}else for(let mt=0;mt<Q.locationSize;mt++)m(Q.location+mt);i.bindBuffer(i.ARRAY_BUFFER,At);for(let mt=0;mt<Q.locationSize;mt++)w(Q.location+mt,St/Q.locationSize,Ot,O,_t*Dt,(bt+St/Q.locationSize*mt)*Dt,tt)}else{if(ct.isInstancedBufferAttribute){for(let it=0;it<Q.locationSize;it++)p(Q.location+it,ct.meshPerAttribute);N.isInstancedMesh!==!0&&F._maxInstanceCount===void 0&&(F._maxInstanceCount=ct.meshPerAttribute*ct.count)}else for(let it=0;it<Q.locationSize;it++)m(Q.location+it);i.bindBuffer(i.ARRAY_BUFFER,At);for(let it=0;it<Q.locationSize;it++)w(Q.location+it,St/Q.locationSize,Ot,O,St*Dt,St/Q.locationSize*it*Dt,tt)}}else if(nt!==void 0){let O=nt[dt];if(O!==void 0)switch(O.length){case 2:i.vertexAttrib2fv(Q.location,O);break;case 3:i.vertexAttrib3fv(Q.location,O);break;case 4:i.vertexAttrib4fv(Q.location,O);break;default:i.vertexAttrib1fv(Q.location,O)}}}}S()}function E(){C();for(let N in n){let P=n[N];for(let B in P){let F=P[B];for(let W in F){let rt=F[W];for(let nt in rt)h(rt[nt].object),delete rt[nt];delete F[W]}}delete n[N]}}function M(N){if(n[N.id]===void 0)return;let P=n[N.id];for(let B in P){let F=P[B];for(let W in F){let rt=F[W];for(let nt in rt)h(rt[nt].object),delete rt[nt];delete F[W]}}delete n[N.id]}function I(N){for(let P in n){let B=n[P];for(let F in B){let W=B[F];if(W[N.id]===void 0)continue;let rt=W[N.id];for(let nt in rt)h(rt[nt].object),delete rt[nt];delete W[N.id]}}}function v(N){for(let P in n){let B=n[P],F=N.isInstancedMesh===!0?N.id:0,W=B[F];if(W!==void 0){for(let rt in W){let nt=W[rt];for(let dt in nt)h(nt[dt].object),delete nt[dt];delete W[rt]}delete B[F],Object.keys(B).length===0&&delete n[P]}}}function C(){L(),a=!0,r!==s&&(r=s,l(r.object))}function L(){s.geometry=null,s.program=null,s.wireframe=!1}return{setup:o,reset:C,resetDefaultState:L,dispose:E,releaseStatesOfGeometry:M,releaseStatesOfObject:v,releaseStatesOfProgram:I,initAttributes:_,enableAttribute:m,disableUnusedAttributes:S}}function s2(i,t,e){let n;function s(c){n=c}function r(c,l){i.drawArrays(n,c,l),e.update(l,n,1)}function a(c,l,h){h!==0&&(i.drawArraysInstanced(n,c,l,h),e.update(l,n,h))}function o(c,l,h){if(h===0)return;t.get("WEBGL_multi_draw").multiDrawArraysWEBGL(n,c,0,l,0,h);let u=0;for(let d=0;d<h;d++)u+=l[d];e.update(u,n,1)}this.setMode=s,this.render=r,this.renderInstances=a,this.renderMultiDraw=o}function r2(i,t,e,n){let s;function r(){if(s!==void 0)return s;if(t.has("EXT_texture_filter_anisotropic")===!0){let I=t.get("EXT_texture_filter_anisotropic");s=i.getParameter(I.MAX_TEXTURE_MAX_ANISOTROPY_EXT)}else s=0;return s}function a(I){return!(I!==Zn&&n.convert(I)!==i.getParameter(i.IMPLEMENTATION_COLOR_READ_FORMAT))}function o(I){let v=I===ln&&(t.has("EXT_color_buffer_half_float")||t.has("EXT_color_buffer_float"));return!(I!==Nn&&I!==Yn&&!v&&n.convert(I)!==i.getParameter(i.IMPLEMENTATION_COLOR_READ_TYPE))}function c(I){if(I==="highp"){if(i.getShaderPrecisionFormat(i.VERTEX_SHADER,i.HIGH_FLOAT).precision>0&&i.getShaderPrecisionFormat(i.FRAGMENT_SHADER,i.HIGH_FLOAT).precision>0)return"highp";I="mediump"}return I==="mediump"&&i.getShaderPrecisionFormat(i.VERTEX_SHADER,i.MEDIUM_FLOAT).precision>0&&i.getShaderPrecisionFormat(i.FRAGMENT_SHADER,i.MEDIUM_FLOAT).precision>0?"mediump":"lowp"}let l=e.precision!==void 0?e.precision:"highp",h=c(l);h!==l&&(ue("WebGLRenderer:",l,"not supported, using",h,"instead."),l=h);let f=e.logarithmicDepthBuffer===!0,u=e.reversedDepthBuffer===!0&&t.has("EXT_clip_control");e.reversedDepthBuffer===!0&&u===!1&&ue("WebGLRenderer: Unable to use reversed depth buffer due to missing EXT_clip_control extension. Fallback to default depth buffer.");let d=i.getParameter(i.MAX_TEXTURE_IMAGE_UNITS),g=i.getParameter(i.MAX_VERTEX_TEXTURE_IMAGE_UNITS),_=i.getParameter(i.MAX_TEXTURE_SIZE),m=i.getParameter(i.MAX_CUBE_MAP_TEXTURE_SIZE),p=i.getParameter(i.MAX_VERTEX_ATTRIBS),S=i.getParameter(i.MAX_VERTEX_UNIFORM_VECTORS),w=i.getParameter(i.MAX_VARYING_VECTORS),y=i.getParameter(i.MAX_FRAGMENT_UNIFORM_VECTORS),E=i.getParameter(i.MAX_SAMPLES),M=i.getParameter(i.SAMPLES);return{isWebGL2:!0,getMaxAnisotropy:r,getMaxPrecision:c,textureFormatReadable:a,textureTypeReadable:o,precision:l,logarithmicDepthBuffer:f,reversedDepthBuffer:u,maxTextures:d,maxVertexTextures:g,maxTextureSize:_,maxCubemapSize:m,maxAttributes:p,maxVertexUniforms:S,maxVaryings:w,maxFragmentUniforms:y,maxSamples:E,samples:M}}function a2(i){let t=this,e=null,n=0,s=!1,r=!1,a=new ri,o=new me,c={value:null,needsUpdate:!1};this.uniform=c,this.numPlanes=0,this.numIntersection=0,this.init=function(f,u){let d=f.length!==0||u||n!==0||s;return s=u,n=f.length,d},this.beginShadows=function(){r=!0,h(null)},this.endShadows=function(){r=!1},this.setGlobalState=function(f,u){e=h(f,u,0)},this.setState=function(f,u,d){let g=f.clippingPlanes,_=f.clipIntersection,m=f.clipShadows,p=i.get(f);if(!s||g===null||g.length===0||r&&!m)r?h(null):l();else{let S=r?0:n,w=S*4,y=p.clippingState||null;c.value=y,y=h(g,u,w,d);for(let E=0;E!==w;++E)y[E]=e[E];p.clippingState=y,this.numIntersection=_?this.numPlanes:0,this.numPlanes+=S}};function l(){c.value!==e&&(c.value=e,c.needsUpdate=n>0),t.numPlanes=n,t.numIntersection=0}function h(f,u,d,g){let _=f!==null?f.length:0,m=null;if(_!==0){if(m=c.value,g!==!0||m===null){let p=d+_*4,S=u.matrixWorldInverse;o.getNormalMatrix(S),(m===null||m.length<p)&&(m=new Float32Array(p));for(let w=0,y=d;w!==_;++w,y+=4)a.copy(f[w]).applyMatrix4(S,o),a.normal.toArray(m,y),m[y+3]=a.constant}c.value=m,c.needsUpdate=!0}return t.numPlanes=_,t.numIntersection=0,m}}var Ir=4,o2=6,l2=20,c2=256,so=new cs,Bd=new se,dh=null,fh=0,ph=0,mh=!1,h2=new D,Cs=new D,Tc=class{constructor(t){this._renderer=t,this._pingPongRenderTarget=null,this._lodMax=0,this._cubeSize=0,this._sizeLods=[],this._lodMeshes=[],this._backgroundBox=null,this._cubemapMaterial=null,this._equirectMaterial=null,this._blurMaterial=null,this._ggxMaterial=null}fromScene(t,e=0,n=.1,s=100,r={}){let{size:a=256,position:o=h2}=r;dh=this._renderer.getRenderTarget(),fh=this._renderer.getActiveCubeFace(),ph=this._renderer.getActiveMipmapLevel(),mh=this._renderer.xr.enabled,this._renderer.xr.enabled=!1,this._setSize(a);let c=this._allocateTargets();return c.depthBuffer=!0,this._sceneToCubeUV(t,n,s,c,o),e>0&&this._blur(c,0,0,e),this._applyPMREM(c),this._cleanup(c),c}fromEquirectangular(t,e=null){return this._fromTexture(t,e)}fromCubemap(t,e=null){return this._fromTexture(t,e)}compileCubemapShader(){this._cubemapMaterial===null&&(this._cubemapMaterial=Hd(),this._compileMaterial(this._cubemapMaterial))}compileEquirectangularShader(){this._equirectMaterial===null&&(this._equirectMaterial=kd(),this._compileMaterial(this._equirectMaterial))}dispose(){this._dispose(),this._cubemapMaterial!==null&&this._cubemapMaterial.dispose(),this._equirectMaterial!==null&&this._equirectMaterial.dispose(),this._backgroundBox!==null&&(this._backgroundBox.geometry.dispose(),this._backgroundBox.material.dispose())}_setSize(t){this._lodMax=Math.floor(Math.log2(t)),this._cubeSize=Math.pow(2,this._lodMax)}_dispose(){this._blurMaterial!==null&&this._blurMaterial.dispose(),this._ggxMaterial!==null&&this._ggxMaterial.dispose(),this._pingPongRenderTarget!==null&&this._pingPongRenderTarget.dispose();for(let t=0;t<this._lodMeshes.length;t++)this._lodMeshes[t].geometry.dispose()}_cleanup(t){this._renderer.setRenderTarget(dh,fh,ph),this._renderer.xr.enabled=mh,t.scissorTest=!1,Cr(t,0,0,t.width,t.height)}_fromTexture(t,e){t.mapping===ds||t.mapping===As?this._setSize(t.image.length===0?16:t.image[0].width||t.image[0].image.width):this._setSize(t.image.width/4),dh=this._renderer.getRenderTarget(),fh=this._renderer.getActiveCubeFace(),ph=this._renderer.getActiveMipmapLevel(),mh=this._renderer.xr.enabled,this._renderer.xr.enabled=!1;let n=e||this._allocateTargets();return this._textureToCubeUV(t,n),this._applyPMREM(n),this._cleanup(n),n}_allocateTargets(){let t=3*Math.max(this._cubeSize,112),e=4*this._cubeSize,n={magFilter:Mn,minFilter:Mn,generateMipmaps:!1,type:ln,format:Zn,colorSpace:ra,depthBuffer:!1},s=zd(t,e,n);if(this._pingPongRenderTarget===null||this._pingPongRenderTarget.width!==t||this._pingPongRenderTarget.height!==e){this._pingPongRenderTarget!==null&&this._dispose(),this._pingPongRenderTarget=zd(t,e,n);let{_lodMax:r}=this;({lodMeshes:this._lodMeshes,sizeLods:this._sizeLods}=u2(r)),this._blurMaterial=f2(r,t,e),this._ggxMaterial=d2(r,t,e)}return s}_compileMaterial(t){let e=new ve(new Ae,t);this._renderer.compile(e,so)}_sceneToCubeUV(t,e,n,s,r){let c=new yn(90,1,e,n),l=[1,-1,1,1,1,1],h=[1,1,1,-1,-1,-1],f=this._renderer,u=f.autoClear,d=f.toneMapping;f.getClearColor(Bd),f.toneMapping=ci,f.autoClear=!1,f.state.buffers.depth.getReversed()&&(f.setRenderTarget(s),f.clearDepth(),f.setRenderTarget(null)),this._backgroundBox===null&&(this._backgroundBox=new ve(new mr,new nn({name:"PMREM.Background",side:bn,depthWrite:!1,depthTest:!1})));let _=this._backgroundBox,m=_.material,p=!1,S=t.background;S?S.isColor&&(m.color.copy(S),t.background=null,p=!0):(m.color.copy(Bd),p=!0);for(let w=0;w<6;w++){let y=w%3;y===0?(c.up.set(0,l[w],0),c.position.set(r.x,r.y,r.z),c.lookAt(r.x+h[w],r.y,r.z)):y===1?(c.up.set(0,0,l[w]),c.position.set(r.x,r.y,r.z),c.lookAt(r.x,r.y+h[w],r.z)):(c.up.set(0,l[w],0),c.position.set(r.x,r.y,r.z),c.lookAt(r.x,r.y,r.z+h[w]));let E=this._cubeSize;Cr(s,y*E,w>2?E:0,E,E),f.setRenderTarget(s),p&&f.render(_,c),f.render(t,c)}f.toneMapping=d,f.autoClear=u,t.background=S}_textureToCubeUV(t,e){let n=this._renderer,s=t.mapping===ds||t.mapping===As;s?(this._cubemapMaterial===null&&(this._cubemapMaterial=Hd()),this._cubemapMaterial.uniforms.flipEnvMap.value=t.isRenderTargetTexture===!1?-1:1):this._equirectMaterial===null&&(this._equirectMaterial=kd());let r=s?this._cubemapMaterial:this._equirectMaterial,a=this._lodMeshes[0];a.material=r;let o=r.uniforms;o.envMap.value=t;let c=this._cubeSize;Cr(e,0,0,3*c,2*c),n.setRenderTarget(e),n.render(a,so)}_applyPMREM(t){let e=this._renderer,n=e.autoClear;e.autoClear=!1;let s=this._lodMeshes.length;for(let r=1;r<s;r++)this._applyGGXFilter(t,r-1,r);e.autoClear=n}_applyGGXFilter(t,e,n){let s=this._renderer,r=this._pingPongRenderTarget,a=this._ggxMaterial,o=this._lodMeshes[n];o.material=a;let c=a.uniforms,l=n/(this._lodMeshes.length-1),h=e/(this._lodMeshes.length-1),f=Math.sqrt(l*l-h*h),u=l*1.25,d=f*u,{_lodMax:g}=this,_=this._sizeLods[n],m=3*_*(n>g-Ir?n-g+Ir:0),p=4*(this._cubeSize-_);c.envMap.value=t.texture,c.roughness.value=d,c.mipInt.value=g-e,Cr(r,m,p,3*_,2*_),s.setRenderTarget(r),s.render(o,so),c.envMap.value=r.texture,c.roughness.value=0,c.mipInt.value=g-n,Cr(t,m,p,3*_,2*_),s.setRenderTarget(t),s.render(o,so)}_blur(t,e,n,s){let r=this._pingPongRenderTarget,a=Math.min(s,Math.PI)/Math.SQRT2;this._blurPass(t,r,e,n,a),this._blurPass(r,t,n,n,a)}_blurPass(t,e,n,s,r){let a=this._renderer,o=this._blurMaterial,c=this._lodMeshes[s];c.material=o;let l=o.uniforms;l.envMap.value=t.texture,l.sigma.value=r,l.mipInt.value=this._lodMax-n;let h=this._sizeLods[s],f=3*h*(s>this._lodMax-Ir?s-this._lodMax+Ir:0),u=4*(this._cubeSize-h);Cr(e,f,u,3*h,2*h),a.setRenderTarget(e),a.render(c,so)}};function u2(i){let t=[],e=[],n=i,s=i-Ir+1+o2;for(let r=0;r<s;r++){let a=Math.pow(2,n);t.push(a);let o=1/(a-2),c=-o,l=1+o,h=[c,c,l,c,l,l,c,c,l,l,c,l],f=6,u=6,d=3,g=new Float32Array(d*u*f),_=new Float32Array(d*u*f);for(let p=0;p<f;p++){let S=p%3*2/3-1,w=p>2?0:-1,y=[S,w,0,S+2/3,w,0,S+2/3,w+1,0,S,w,0,S+2/3,w+1,0,S,w+1,0];g.set(y,d*u*p);for(let E=0;E<u;E++){let M=h[E*2]*2-1,I=h[E*2+1]*2-1;p===0?Cs.set(1,I,M):p===1?Cs.set(-M,1,-I):p===2?Cs.set(-M,I,1):p===3?Cs.set(-1,I,-M):p===4?Cs.set(-M,-1,I):Cs.set(M,I,-1),Cs.toArray(_,(p*u+E)*d)}}let m=new Ae;m.setAttribute("position",new tn(g,d)),m.setAttribute("outputDirection",new tn(_,d)),e.push(new ve(m,null)),n>Ir&&n--}return{lodMeshes:e,sizeLods:t}}function zd(i,t,e){let n=new Ke(i,t,e);return n.texture.mapping=Ja,n.texture.name="PMREM.cubeUv",n.scissorTest=!0,n}function Cr(i,t,e,n,s){i.viewport.set(t,e,n,s),i.scissor.set(t,e,n,s)}function d2(i,t,e){return new Oe({name:"PMREMGGXConvolution",defines:{GGX_SAMPLES:c2,CUBEUV_TEXEL_WIDTH:1/t,CUBEUV_TEXEL_HEIGHT:1/e,CUBEUV_MAX_MIP:`${i}.0`},uniforms:{envMap:{value:null},roughness:{value:0},mipInt:{value:0}},vertexShader:Cc(),fragmentShader:`

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
		`,blending:qn,depthTest:!1,depthWrite:!1})}function f2(i,t,e){return new Oe({name:"SphericalGaussianBlur",defines:{SAMPLES:l2,CUBEUV_TEXEL_WIDTH:1/t,CUBEUV_TEXEL_HEIGHT:1/e,CUBEUV_MAX_MIP:`${i}.0`},uniforms:{envMap:{value:null},sigma:{value:0},mipInt:{value:0}},vertexShader:Cc(),fragmentShader:`

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
		`,blending:qn,depthTest:!1,depthWrite:!1})}function kd(){return new Oe({name:"EquirectangularToCubeUV",uniforms:{envMap:{value:null}},vertexShader:Cc(),fragmentShader:`

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
		`,blending:qn,depthTest:!1,depthWrite:!1})}function Hd(){return new Oe({name:"CubemapToCubeUV",uniforms:{envMap:{value:null},flipEnvMap:{value:-1}},vertexShader:Cc(),fragmentShader:`

			precision mediump float;
			precision mediump int;

			uniform float flipEnvMap;

			varying vec3 vOutputDirection;

			uniform samplerCube envMap;

			void main() {

				gl_FragColor = textureCube( envMap, vec3( flipEnvMap * vOutputDirection.x, vOutputDirection.yz ) );

			}
		`,blending:qn,depthTest:!1,depthWrite:!1})}function Cc(){return`

		precision mediump float;
		precision mediump int;

		attribute vec3 outputDirection;

		varying vec3 vOutputDirection;

		void main() {

			vOutputDirection = outputDirection;
			gl_Position = vec4( position, 1.0 );

		}
	`}var Ac=class extends Ke{constructor(t=1,e={}){super(t,t,e),this.isWebGLCubeRenderTarget=!0;let n={width:t,height:t,depth:1},s=[n,n,n,n,n,n];this.texture=new xa(s),this._setTextureOptions(e),this.texture.isRenderTargetTexture=!0}fromEquirectangularTexture(t,e){this.texture.type=e.type,this.texture.colorSpace=e.colorSpace,this.texture.generateMipmaps=e.generateMipmaps,this.texture.minFilter=e.minFilter,this.texture.magFilter=e.magFilter;let n={uniforms:{tEquirect:{value:null}},vertexShader:`

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
			`},s=new mr(5,5,5),r=new Oe({name:"CubemapFromEquirect",uniforms:Rs(n.uniforms),vertexShader:n.vertexShader,fragmentShader:n.fragmentShader,side:bn,blending:qn});r.uniforms.tEquirect.value=e;let a=new ve(s,r),o=e.minFilter;return e.minFilter===Si&&(e.minFilter=Mn),new Dl(1,10,this).update(t,a),e.minFilter=o,a.geometry.dispose(),a.material.dispose(),this}clear(t,e=!0,n=!0,s=!0){let r=t.getRenderTarget();for(let a=0;a<6;a++)t.setRenderTarget(this,a),t.clear(e,n,s);t.setRenderTarget(r)}};function p2(i){let t=new WeakMap,e=new WeakMap,n=null;function s(u,d=!1){return u==null?null:d?a(u):r(u)}function r(u){if(u&&u.isTexture){let d=u.mapping;if(d===Tr||d===Fl)if(t.has(u)){let g=t.get(u).texture;return o(g,u.mapping)}else{let g=u.image;if(g&&g.height>0){let _=new Ac(g.height);return _.fromEquirectangularTexture(i,u),t.set(u,_),u.addEventListener("dispose",l),o(_.texture,u.mapping)}else return null}}return u}function a(u){if(u&&u.isTexture){let d=u.mapping,g=d===Tr||d===Fl,_=d===ds||d===As;if(g||_){let m=e.get(u),p=m!==void 0?m.texture.pmremVersion:0;if(u.isRenderTargetTexture&&u.pmremVersion!==p)return n===null&&(n=new Tc(i)),m=g?n.fromEquirectangular(u,m):n.fromCubemap(u,m),m.texture.pmremVersion=u.pmremVersion,e.set(u,m),m.texture;if(m!==void 0)return m.texture;{let S=u.image;return g&&S&&S.height>0||_&&S&&c(S)?(n===null&&(n=new Tc(i)),m=g?n.fromEquirectangular(u):n.fromCubemap(u),m.texture.pmremVersion=u.pmremVersion,e.set(u,m),u.addEventListener("dispose",h),m.texture):null}}}return u}function o(u,d){return d===Tr?u.mapping=ds:d===Fl&&(u.mapping=As),u}function c(u){let d=0,g=6;for(let _=0;_<g;_++)u[_]!==void 0&&d++;return d===g}function l(u){let d=u.target;d.removeEventListener("dispose",l);let g=t.get(d);g!==void 0&&(t.delete(d),g.dispose())}function h(u){let d=u.target;d.removeEventListener("dispose",h);let g=e.get(d);g!==void 0&&(e.delete(d),g.dispose())}function f(){t=new WeakMap,e=new WeakMap,n!==null&&(n.dispose(),n=null)}return{get:s,dispose:f}}function m2(i){let t={};function e(n){if(t[n]!==void 0)return t[n];let s=i.getExtension(n);return t[n]=s,s}return{has:function(n){return e(n)!==null},init:function(){e("EXT_color_buffer_float"),e("WEBGL_clip_cull_distance"),e("OES_texture_float_linear"),e("EXT_color_buffer_half_float"),e("WEBGL_multisampled_render_to_texture"),e("WEBGL_render_shared_exponent")},get:function(n){let s=e(n);return s===null&&bs("WebGLRenderer: "+n+" extension not supported."),s}}}function g2(i,t,e,n){let s={},r=new WeakMap;function a(f){let u=f.target;u.index!==null&&t.remove(u.index);for(let g in u.attributes)t.remove(u.attributes[g]);u.removeEventListener("dispose",a),delete s[u.id];let d=r.get(u);d&&(t.remove(d),r.delete(u)),n.releaseStatesOfGeometry(u),u.isInstancedBufferGeometry===!0&&delete u._maxInstanceCount,e.memory.geometries--}function o(f,u){return s[u.id]===!0||(u.addEventListener("dispose",a),s[u.id]=!0,e.memory.geometries++),u}function c(f){let u=f.attributes;for(let d in u)t.update(u[d],i.ARRAY_BUFFER)}function l(f){let u=[],d=f.index,g=f.attributes.position,_=0;if(g===void 0)return;if(d!==null){let S=d.array;_=d.version;for(let w=0,y=S.length;w<y;w+=3){let E=S[w+0],M=S[w+1],I=S[w+2];u.push(E,M,M,I,I,E)}}else{let S=g.array;_=g.version;for(let w=0,y=S.length/3-1;w<y;w+=3){let E=w+0,M=w+1,I=w+2;u.push(E,M,M,I,I,E)}}let m=new(g.count>=65535?ua:ha)(u,1);m.version=_;let p=r.get(f);p&&t.remove(p),r.set(f,m)}function h(f){let u=r.get(f);if(u){let d=f.index;d!==null&&u.version<d.version&&l(f)}else l(f);return r.get(f)}return{get:o,update:c,getWireframeAttribute:h}}function x2(i,t,e){let n;function s(f){n=f}let r,a;function o(f){r=f.type,a=f.bytesPerElement}function c(f,u){i.drawElements(n,u,r,f*a),e.update(u,n,1)}function l(f,u,d){d!==0&&(i.drawElementsInstanced(n,u,r,f*a,d),e.update(u,n,d))}function h(f,u,d){if(d===0)return;t.get("WEBGL_multi_draw").multiDrawElementsWEBGL(n,u,0,r,f,0,d);let _=0;for(let m=0;m<d;m++)_+=u[m];e.update(_,n,1)}this.setMode=s,this.setIndex=o,this.render=c,this.renderInstances=l,this.renderMultiDraw=h}function _2(i){let t={geometries:0,textures:0},e={frame:0,calls:0,triangles:0,points:0,lines:0};function n(r,a,o){switch(e.calls++,a){case i.TRIANGLES:e.triangles+=o*(r/3);break;case i.LINES:e.lines+=o*(r/2);break;case i.LINE_STRIP:e.lines+=o*(r-1);break;case i.LINE_LOOP:e.lines+=o*r;break;case i.POINTS:e.points+=o*r;break;default:he("WebGLInfo: Unknown draw mode:",a);break}}function s(){e.calls=0,e.triangles=0,e.points=0,e.lines=0}return{memory:t,render:e,programs:null,autoReset:!0,reset:s,update:n}}function v2(i,t,e){let n=new WeakMap,s=new $e;function r(a,o,c){let l=a.morphTargetInfluences,h=o.morphAttributes.position||o.morphAttributes.normal||o.morphAttributes.color,f=h!==void 0?h.length:0,u=n.get(o);if(u===void 0||u.count!==f){let C=function(){I.dispose(),n.delete(o),o.removeEventListener("dispose",C)};u!==void 0&&u.texture.dispose();let d=o.morphAttributes.position!==void 0,g=o.morphAttributes.normal!==void 0,_=o.morphAttributes.color!==void 0,m=o.morphAttributes.position||[],p=o.morphAttributes.normal||[],S=o.morphAttributes.color||[],w=0;d===!0&&(w=1),g===!0&&(w=2),_===!0&&(w=3);let y=o.attributes.position.count*w,E=1;y>t.maxTextureSize&&(E=Math.ceil(y/t.maxTextureSize),y=t.maxTextureSize);let M=new Float32Array(y*E*4*f),I=new la(M,y,E,f);I.type=Yn,I.needsUpdate=!0;let v=w*4;for(let L=0;L<f;L++){let N=m[L],P=p[L],B=S[L],F=y*E*4*L;for(let W=0;W<N.count;W++){let rt=W*v;d===!0&&(s.fromBufferAttribute(N,W),M[F+rt+0]=s.x,M[F+rt+1]=s.y,M[F+rt+2]=s.z,M[F+rt+3]=0),g===!0&&(s.fromBufferAttribute(P,W),M[F+rt+4]=s.x,M[F+rt+5]=s.y,M[F+rt+6]=s.z,M[F+rt+7]=0),_===!0&&(s.fromBufferAttribute(B,W),M[F+rt+8]=s.x,M[F+rt+9]=s.y,M[F+rt+10]=s.z,M[F+rt+11]=B.itemSize===4?s.w:1)}}u={count:f,texture:I,size:new vt(y,E)},n.set(o,u),o.addEventListener("dispose",C)}if(a.isInstancedMesh===!0&&a.morphTexture!==null)c.getUniforms().setValue(i,"morphTexture",a.morphTexture,e);else{let d=0;for(let _=0;_<l.length;_++)d+=l[_];let g=o.morphTargetsRelative?1:1-d;c.getUniforms().setValue(i,"morphTargetBaseInfluence",g),c.getUniforms().setValue(i,"morphTargetInfluences",l)}c.getUniforms().setValue(i,"morphTargetsTexture",u.texture,e),c.getUniforms().setValue(i,"morphTargetsTextureSize",u.size)}return{update:r}}function y2(i,t,e,n,s){let r=new WeakMap;function a(l){let h=s.render.frame,f=l.geometry,u=t.get(l,f);if(r.get(u)!==h&&(t.update(u),r.set(u,h)),l.isInstancedMesh&&(l.hasEventListener("dispose",c)===!1&&l.addEventListener("dispose",c),r.get(l)!==h&&(e.update(l.instanceMatrix,i.ARRAY_BUFFER),l.instanceColor!==null&&e.update(l.instanceColor,i.ARRAY_BUFFER),r.set(l,h))),l.isSkinnedMesh){let d=l.skeleton;r.get(d)!==h&&(d.update(),r.set(d,h))}return u}function o(){r=new WeakMap}function c(l){let h=l.target;h.removeEventListener("dispose",c),n.releaseStatesOfObject(h),e.remove(h.instanceMatrix),h.instanceColor!==null&&e.remove(h.instanceColor)}return{update:a,dispose:o}}var M2={[Wa]:"LINEAR_TONE_MAPPING",[Xa]:"REINHARD_TONE_MAPPING",[$a]:"CINEON_TONE_MAPPING",[Ts]:"ACES_FILMIC_TONE_MAPPING",[Ya]:"AGX_TONE_MAPPING",[Za]:"NEUTRAL_TONE_MAPPING",[qa]:"CUSTOM_TONE_MAPPING"};function b2(i,t,e,n,s,r){let a=new Ke(t,e,{type:i,depthBuffer:s,stencilBuffer:r,samples:n?4:0,storeMultisampledDepthBuffer:!1,storeMultisampledStencilBuffer:!1,resolveDepthBuffer:!1,resolveStencilBuffer:!1}),o=null,c=null,l=new Ae;l.setAttribute("position",new fe([-1,3,0,-1,-1,0,3,-1,0],3)),l.setAttribute("uv",new fe([0,2,0,0,2,0],2));let h=new Mr({uniforms:{tDiffuse:{value:null}},vertexShader:`
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
			}`,depthTest:!1,depthWrite:!1}),f=new ve(l,h),u=new cs(-1,1,1,-1,0,1),d=null,g=null,_=!1,m,p=null,S=[],w=!1;this.setSize=function(y,E){a.setSize(y,E),o!==null&&o.setSize(y,E),c!==null&&c.setSize(y,E);for(let M=0;M<S.length;M++){let I=S[M];I.setSize&&I.setSize(y,E)}},this.setEffects=function(y){S=y,w=S.length>0&&S[0].isRenderPass===!0;let E=a.width,M=a.height;S.length>0&&o===null&&(o=new Ke(E,M,{type:ln,depthBuffer:!1,stencilBuffer:!1}),c=new Ke(E,M,{type:ln,depthBuffer:!1,stencilBuffer:!1}));for(let I=0;I<S.length;I++){let v=S[I];v.setSize&&v.setSize(E,M)}},this.begin=function(y,E){if(_||y.toneMapping===ci&&S.length===0)return!1;if(p=E,E!==null){let M=E.width,I=E.height;(a.width!==M||a.height!==I)&&this.setSize(M,I)}return w===!1&&y.setRenderTarget(a),m=y.toneMapping,y.toneMapping=ci,!0},this.hasRenderPass=function(){return w},this.end=function(y,E){y.toneMapping=m,_=!0;let M=a,I=o;for(let v=0;v<S.length;v++){let C=S[v];C.enabled!==!1&&(C.render(y,I,M,E),C.needsSwap!==!1&&(M=I,I=I===o?c:o))}if(d!==y.outputColorSpace||g!==y.toneMapping){d=y.outputColorSpace,g=y.toneMapping,h.defines={},Se.getTransfer(d)===Le&&(h.defines.SRGB_TRANSFER="");let v=M2[g];v&&(h.defines[v]=""),h.needsUpdate=!0}h.uniforms.tDiffuse.value=M.texture,y.setRenderTarget(p),y.render(f,u),p=null,_=!1},this.isCompositing=function(){return _},this.dispose=function(){a.dispose(),o!==null&&o.dispose(),c!==null&&c.dispose(),l.dispose(),h.dispose()}}var lf=new gn,_h=new ss(1,1),cf=new la,hf=new dl,uf=new xa,Vd=[],Gd=[],Wd=new Float32Array(16),Xd=new Float32Array(9),$d=new Float32Array(4);function Lr(i,t,e){let n=i[0];if(n<=0||n>0)return i;let s=t*e,r=Vd[s];if(r===void 0&&(r=new Float32Array(s),Vd[s]=r),t!==0){n.toArray(r,0);for(let a=1,o=0;a!==t;++a)o+=e,i[a].toArray(r,o)}return r}function cn(i,t){if(i.length!==t.length)return!1;for(let e=0,n=i.length;e<n;e++)if(i[e]!==t[e])return!1;return!0}function hn(i,t){for(let e=0,n=t.length;e<n;e++)i[e]=t[e]}function Ic(i,t){let e=Gd[t];e===void 0&&(e=new Int32Array(t),Gd[t]=e);for(let n=0;n!==t;++n)e[n]=i.allocateTextureUnit();return e}function S2(i,t){let e=this.cache;e[0]!==t&&(i.uniform1f(this.addr,t),e[0]=t)}function E2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y)&&(i.uniform2f(this.addr,t.x,t.y),e[0]=t.x,e[1]=t.y);else{if(cn(e,t))return;i.uniform2fv(this.addr,t),hn(e,t)}}function w2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z)&&(i.uniform3f(this.addr,t.x,t.y,t.z),e[0]=t.x,e[1]=t.y,e[2]=t.z);else if(t.r!==void 0)(e[0]!==t.r||e[1]!==t.g||e[2]!==t.b)&&(i.uniform3f(this.addr,t.r,t.g,t.b),e[0]=t.r,e[1]=t.g,e[2]=t.b);else{if(cn(e,t))return;i.uniform3fv(this.addr,t),hn(e,t)}}function T2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z||e[3]!==t.w)&&(i.uniform4f(this.addr,t.x,t.y,t.z,t.w),e[0]=t.x,e[1]=t.y,e[2]=t.z,e[3]=t.w);else{if(cn(e,t))return;i.uniform4fv(this.addr,t),hn(e,t)}}function A2(i,t){let e=this.cache,n=t.elements;if(n===void 0){if(cn(e,t))return;i.uniformMatrix2fv(this.addr,!1,t),hn(e,t)}else{if(cn(e,n))return;$d.set(n),i.uniformMatrix2fv(this.addr,!1,$d),hn(e,n)}}function R2(i,t){let e=this.cache,n=t.elements;if(n===void 0){if(cn(e,t))return;i.uniformMatrix3fv(this.addr,!1,t),hn(e,t)}else{if(cn(e,n))return;Xd.set(n),i.uniformMatrix3fv(this.addr,!1,Xd),hn(e,n)}}function C2(i,t){let e=this.cache,n=t.elements;if(n===void 0){if(cn(e,t))return;i.uniformMatrix4fv(this.addr,!1,t),hn(e,t)}else{if(cn(e,n))return;Wd.set(n),i.uniformMatrix4fv(this.addr,!1,Wd),hn(e,n)}}function I2(i,t){let e=this.cache;e[0]!==t&&(i.uniform1i(this.addr,t),e[0]=t)}function P2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y)&&(i.uniform2i(this.addr,t.x,t.y),e[0]=t.x,e[1]=t.y);else{if(cn(e,t))return;i.uniform2iv(this.addr,t),hn(e,t)}}function L2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z)&&(i.uniform3i(this.addr,t.x,t.y,t.z),e[0]=t.x,e[1]=t.y,e[2]=t.z);else{if(cn(e,t))return;i.uniform3iv(this.addr,t),hn(e,t)}}function N2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z||e[3]!==t.w)&&(i.uniform4i(this.addr,t.x,t.y,t.z,t.w),e[0]=t.x,e[1]=t.y,e[2]=t.z,e[3]=t.w);else{if(cn(e,t))return;i.uniform4iv(this.addr,t),hn(e,t)}}function D2(i,t){let e=this.cache;e[0]!==t&&(i.uniform1ui(this.addr,t),e[0]=t)}function U2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y)&&(i.uniform2ui(this.addr,t.x,t.y),e[0]=t.x,e[1]=t.y);else{if(cn(e,t))return;i.uniform2uiv(this.addr,t),hn(e,t)}}function F2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z)&&(i.uniform3ui(this.addr,t.x,t.y,t.z),e[0]=t.x,e[1]=t.y,e[2]=t.z);else{if(cn(e,t))return;i.uniform3uiv(this.addr,t),hn(e,t)}}function O2(i,t){let e=this.cache;if(t.x!==void 0)(e[0]!==t.x||e[1]!==t.y||e[2]!==t.z||e[3]!==t.w)&&(i.uniform4ui(this.addr,t.x,t.y,t.z,t.w),e[0]=t.x,e[1]=t.y,e[2]=t.z,e[3]=t.w);else{if(cn(e,t))return;i.uniform4uiv(this.addr,t),hn(e,t)}}function B2(i,t,e){let n=this.cache,s=e.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s);let r;this.type===i.SAMPLER_2D_SHADOW?(_h.compareFunction=e.isReversedDepthBuffer()?Sc:bc,r=_h):r=lf,e.setTexture2D(t||r,s)}function z2(i,t,e){let n=this.cache,s=e.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s),e.setTexture3D(t||hf,s)}function k2(i,t,e){let n=this.cache,s=e.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s),e.setTextureCube(t||uf,s)}function H2(i,t,e){let n=this.cache,s=e.allocateTextureUnit();n[0]!==s&&(i.uniform1i(this.addr,s),n[0]=s),e.setTexture2DArray(t||cf,s)}function V2(i){switch(i){case 5126:return S2;case 35664:return E2;case 35665:return w2;case 35666:return T2;case 35674:return A2;case 35675:return R2;case 35676:return C2;case 5124:case 35670:return I2;case 35667:case 35671:return P2;case 35668:case 35672:return L2;case 35669:case 35673:return N2;case 5125:return D2;case 36294:return U2;case 36295:return F2;case 36296:return O2;case 35678:case 36198:case 36298:case 36306:case 35682:return B2;case 35679:case 36299:case 36307:return z2;case 35680:case 36300:case 36308:case 36293:return k2;case 36289:case 36303:case 36311:case 36292:return H2}}function G2(i,t){i.uniform1fv(this.addr,t)}function W2(i,t){let e=Lr(t,this.size,2);i.uniform2fv(this.addr,e)}function X2(i,t){let e=Lr(t,this.size,3);i.uniform3fv(this.addr,e)}function $2(i,t){let e=Lr(t,this.size,4);i.uniform4fv(this.addr,e)}function q2(i,t){let e=Lr(t,this.size,4);i.uniformMatrix2fv(this.addr,!1,e)}function Y2(i,t){let e=Lr(t,this.size,9);i.uniformMatrix3fv(this.addr,!1,e)}function Z2(i,t){let e=Lr(t,this.size,16);i.uniformMatrix4fv(this.addr,!1,e)}function J2(i,t){i.uniform1iv(this.addr,t)}function K2(i,t){i.uniform2iv(this.addr,t)}function j2(i,t){i.uniform3iv(this.addr,t)}function Q2(i,t){i.uniform4iv(this.addr,t)}function tx(i,t){i.uniform1uiv(this.addr,t)}function ex(i,t){i.uniform2uiv(this.addr,t)}function nx(i,t){i.uniform3uiv(this.addr,t)}function ix(i,t){i.uniform4uiv(this.addr,t)}function sx(i,t,e){let n=this.cache,s=t.length,r=Ic(e,s);cn(n,r)||(i.uniform1iv(this.addr,r),hn(n,r));let a;this.type===i.SAMPLER_2D_SHADOW?a=_h:a=lf;for(let o=0;o!==s;++o)e.setTexture2D(t[o]||a,r[o])}function rx(i,t,e){let n=this.cache,s=t.length,r=Ic(e,s);cn(n,r)||(i.uniform1iv(this.addr,r),hn(n,r));for(let a=0;a!==s;++a)e.setTexture3D(t[a]||hf,r[a])}function ax(i,t,e){let n=this.cache,s=t.length,r=Ic(e,s);cn(n,r)||(i.uniform1iv(this.addr,r),hn(n,r));for(let a=0;a!==s;++a)e.setTextureCube(t[a]||uf,r[a])}function ox(i,t,e){let n=this.cache,s=t.length,r=Ic(e,s);cn(n,r)||(i.uniform1iv(this.addr,r),hn(n,r));for(let a=0;a!==s;++a)e.setTexture2DArray(t[a]||cf,r[a])}function lx(i){switch(i){case 5126:return G2;case 35664:return W2;case 35665:return X2;case 35666:return $2;case 35674:return q2;case 35675:return Y2;case 35676:return Z2;case 5124:case 35670:return J2;case 35667:case 35671:return K2;case 35668:case 35672:return j2;case 35669:case 35673:return Q2;case 5125:return tx;case 36294:return ex;case 36295:return nx;case 36296:return ix;case 35678:case 36198:case 36298:case 36306:case 35682:return sx;case 35679:case 36299:case 36307:return rx;case 35680:case 36300:case 36308:case 36293:return ax;case 36289:case 36303:case 36311:case 36292:return ox}}var vh=class{constructor(t,e,n){this.id=t,this.addr=n,this.cache=[],this.type=e.type,this.setValue=V2(e.type)}},yh=class{constructor(t,e,n){this.id=t,this.addr=n,this.cache=[],this.type=e.type,this.size=e.size,this.setValue=lx(e.type)}},Mh=class{constructor(t){this.id=t,this.seq=[],this.map={}}setValue(t,e,n){let s=this.seq;for(let r=0,a=s.length;r!==a;++r){let o=s[r];o.setValue(t,e[o.id],n)}}},gh=/(\w+)(\])?(\[|\.)?/g;function qd(i,t){i.seq.push(t),i.map[t.id]=t}function cx(i,t,e){let n=i.name,s=n.length;for(gh.lastIndex=0;;){let r=gh.exec(n),a=gh.lastIndex,o=r[1],c=r[2]==="]",l=r[3];if(c&&(o=o|0),l===void 0||l==="["&&a+2===s){qd(e,l===void 0?new vh(o,i,t):new yh(o,i,t));break}else{let f=e.map[o];f===void 0&&(f=new Mh(o),qd(e,f)),e=f}}}var Pr=class{constructor(t,e){this.seq=[],this.map={};let n=t.getProgramParameter(e,t.ACTIVE_UNIFORMS);for(let a=0;a<n;++a){let o=t.getActiveUniform(e,a),c=t.getUniformLocation(e,o.name);cx(o,c,this)}let s=[],r=[];for(let a of this.seq)a.type===t.SAMPLER_2D_SHADOW||a.type===t.SAMPLER_CUBE_SHADOW||a.type===t.SAMPLER_2D_ARRAY_SHADOW?s.push(a):r.push(a);s.length>0&&(this.seq=s.concat(r))}setValue(t,e,n,s){let r=this.map[e];r!==void 0&&r.setValue(t,n,s)}setOptional(t,e,n){let s=e[n];s!==void 0&&this.setValue(t,n,s)}static upload(t,e,n,s){for(let r=0,a=e.length;r!==a;++r){let o=e[r],c=n[o.id];c.needsUpdate!==!1&&o.setValue(t,c.value,s)}}static seqWithValue(t,e){let n=[];for(let s=0,r=t.length;s!==r;++s){let a=t[s];a.id in e&&n.push(a)}return n}};function Yd(i,t,e){let n=i.createShader(t);return i.shaderSource(n,e),i.compileShader(n),n}var hx=37297,ux=0;function dx(i,t){let e=i.split(`
`),n=[],s=Math.max(t-6,0),r=Math.min(t+6,e.length);for(let a=s;a<r;a++){let o=a+1;n.push(`${o===t?">":" "} ${o}: ${e[a]}`)}return n.join(`
`)}var Zd=new me;function fx(i){Se._getMatrix(Zd,Se.workingColorSpace,i);let t=`mat3( ${Zd.elements.map(e=>e.toFixed(4))} )`;switch(Se.getTransfer(i)){case aa:return[t,"LinearTransferOETF"];case Le:return[t,"sRGBTransferOETF"];default:return ue("WebGLProgram: Unsupported color space: ",i),[t,"LinearTransferOETF"]}}function Jd(i,t,e){let n=i.getShaderParameter(t,i.COMPILE_STATUS),r=(i.getShaderInfoLog(t)||"").trim();if(n&&r==="")return"";let a=/ERROR: 0:(\d+)/.exec(r);if(a){let o=parseInt(a[1]);return e.toUpperCase()+`

`+r+`

`+dx(i.getShaderSource(t),o)}else return r}function px(i,t){let e=fx(t);return[`vec4 ${i}( vec4 value ) {`,`	return ${e[1]}( vec4( value.rgb * ${e[0]}, value.a ) );`,"}"].join(`
`)}var mx={[Wa]:"Linear",[Xa]:"Reinhard",[$a]:"Cineon",[Ts]:"ACESFilmic",[Ya]:"AgX",[Za]:"Neutral",[qa]:"Custom"};function gx(i,t){let e=mx[t];return e===void 0?(ue("WebGLProgram: Unsupported toneMapping:",t),"vec3 "+i+"( vec3 color ) { return LinearToneMapping( color ); }"):"vec3 "+i+"( vec3 color ) { return "+e+"ToneMapping( color ); }"}var wc=new D;function xx(){Se.getLuminanceCoefficients(wc);let i=wc.x.toFixed(4),t=wc.y.toFixed(4),e=wc.z.toFixed(4);return["float luminance( const in vec3 rgb ) {",`	const vec3 weights = vec3( ${i}, ${t}, ${e} );`,"	return dot( weights, rgb );","}"].join(`
`)}function _x(i){return[i.extensionClipCullDistance?"#extension GL_ANGLE_clip_cull_distance : require":"",i.extensionMultiDraw?"#extension GL_ANGLE_multi_draw : require":""].filter(ao).join(`
`)}function vx(i){let t=[];for(let e in i){let n=i[e];n!==!1&&t.push("#define "+e+" "+n)}return t.join(`
`)}function yx(i,t){let e={},n=i.getProgramParameter(t,i.ACTIVE_ATTRIBUTES);for(let s=0;s<n;s++){let r=i.getActiveAttrib(t,s),a=r.name,o=1;r.type===i.FLOAT_MAT2&&(o=2),r.type===i.FLOAT_MAT3&&(o=3),r.type===i.FLOAT_MAT4&&(o=4),e[a]={type:r.type,location:i.getAttribLocation(t,a),locationSize:o}}return e}function ao(i){return i!==""}function Kd(i,t){let e=t.numSpotLightShadows+t.numSpotLightMaps-t.numSpotLightShadowsWithMaps;return i.replace(/NUM_SUN_LIGHTS/g,t.numSunLights).replace(/NUM_DIR_LIGHTS/g,t.numDirLights).replace(/NUM_SPOT_LIGHTS/g,t.numSpotLights).replace(/NUM_SPOT_LIGHT_MAPS/g,t.numSpotLightMaps).replace(/NUM_SPOT_LIGHT_COORDS/g,e).replace(/NUM_RECT_AREA_LIGHTS/g,t.numRectAreaLights).replace(/NUM_POINT_LIGHTS/g,t.numPointLights).replace(/NUM_HEMI_LIGHTS/g,t.numHemiLights).replace(/NUM_SUN_LIGHT_SHADOWS/g,t.numSunLightShadows).replace(/NUM_DIR_LIGHT_SHADOWS/g,t.numDirLightShadows).replace(/NUM_SPOT_LIGHT_SHADOWS_WITH_MAPS/g,t.numSpotLightShadowsWithMaps).replace(/NUM_SPOT_LIGHT_SHADOWS/g,t.numSpotLightShadows).replace(/NUM_POINT_LIGHT_SHADOWS/g,t.numPointLightShadows)}function jd(i,t){return i.replace(/NUM_CLIPPING_PLANES/g,t.numClippingPlanes).replace(/UNION_CLIPPING_PLANES/g,t.numClippingPlanes-t.numClipIntersection)}var Mx=/^[ \t]*#include +<([\w\d./]+)>/gm;function bh(i){return i.replace(Mx,Sx)}var bx=new Map;function Sx(i,t){let e=Me[t];if(e===void 0){let n=bx.get(t);if(n!==void 0)e=Me[n],ue('WebGLRenderer: Shader chunk "%s" has been deprecated. Use "%s" instead.',t,n);else throw new Error("THREE.WebGLProgram: Can not resolve #include <"+t+">")}return bh(e)}var Ex=/#pragma unroll_loop_start\s+for\s*\(\s*int\s+i\s*=\s*(\d+)\s*;\s*i\s*<\s*(\d+)\s*;\s*i\s*\+\+\s*\)\s*{([\s\S]+?)}\s+#pragma unroll_loop_end/g;function Qd(i){return i.replace(Ex,wx)}function wx(i,t,e,n){let s="";for(let r=parseInt(t);r<parseInt(e);r++)s+=n.replace(/\[\s*i\s*\]/g,"[ "+r+" ]").replace(/UNROLLED_LOOP_INDEX/g,r);return s}function tf(i){let t=`precision ${i.precision} float;
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
#define LOW_PRECISION`),t}var Tx={[Ga]:"SHADOWMAP_TYPE_PCF",[wr]:"SHADOWMAP_TYPE_VSM"};function Ax(i){return Tx[i.shadowMapType]||"SHADOWMAP_TYPE_BASIC"}var Rx={[ds]:"ENVMAP_TYPE_CUBE",[As]:"ENVMAP_TYPE_CUBE",[Ja]:"ENVMAP_TYPE_CUBE_UV"};function Cx(i){return i.envMap===!1?"ENVMAP_TYPE_CUBE":Rx[i.envMapMode]||"ENVMAP_TYPE_CUBE"}var Ix={[As]:"ENVMAP_MODE_REFRACTION"};function Px(i){return i.envMap===!1?"ENVMAP_MODE_REFLECTION":Ix[i.envMapMode]||"ENVMAP_MODE_REFLECTION"}var Lx={[K0]:"ENVMAP_BLENDING_MULTIPLY",[pd]:"ENVMAP_BLENDING_MIX",[md]:"ENVMAP_BLENDING_ADD"};function Nx(i){return i.envMap===!1?"ENVMAP_BLENDING_NONE":Lx[i.combine]||"ENVMAP_BLENDING_NONE"}function Dx(i){let t=i.envMapCubeUVHeight;if(t===null)return null;let e=Math.log2(t)-2,n=1/t;return{texelWidth:1/(3*Math.max(Math.pow(2,e),112)),texelHeight:n,maxMip:e}}function Ux(i,t,e,n){let s=i.getContext(),r=e.defines,a=e.vertexShader,o=e.fragmentShader,c=Ax(e),l=Cx(e),h=Px(e),f=Nx(e),u=Dx(e),d=_x(e),g=vx(r),_=s.createProgram(),m,p,S=e.glslVersion?"#version "+e.glslVersion+`
`:"";e.isRawShaderMaterial?(m=["#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,g].filter(ao).join(`
`),m.length>0&&(m+=`
`),p=["#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,g].filter(ao).join(`
`),p.length>0&&(p+=`
`)):(m=[tf(e),"#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,g,e.extensionClipCullDistance?"#define USE_CLIP_DISTANCE":"",e.batching?"#define USE_BATCHING":"",e.batchingColor?"#define USE_BATCHING_COLOR":"",e.instancing?"#define USE_INSTANCING":"",e.instancingColor?"#define USE_INSTANCING_COLOR":"",e.instancingMorph?"#define USE_INSTANCING_MORPH":"",e.useFog&&e.fog?"#define USE_FOG":"",e.useFog&&e.fogExp2?"#define FOG_EXP2":"",e.map?"#define USE_MAP":"",e.envMap?"#define USE_ENVMAP":"",e.envMap?"#define "+h:"",e.lightMap?"#define USE_LIGHTMAP":"",e.aoMap?"#define USE_AOMAP":"",e.bumpMap?"#define USE_BUMPMAP":"",e.normalMap?"#define USE_NORMALMAP":"",e.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",e.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",e.displacementMap?"#define USE_DISPLACEMENTMAP":"",e.emissiveMap?"#define USE_EMISSIVEMAP":"",e.anisotropy?"#define USE_ANISOTROPY":"",e.anisotropyMap?"#define USE_ANISOTROPYMAP":"",e.clearcoatMap?"#define USE_CLEARCOATMAP":"",e.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",e.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",e.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",e.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",e.specularMap?"#define USE_SPECULARMAP":"",e.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",e.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",e.roughnessMap?"#define USE_ROUGHNESSMAP":"",e.metalnessMap?"#define USE_METALNESSMAP":"",e.alphaMap?"#define USE_ALPHAMAP":"",e.alphaHash?"#define USE_ALPHAHASH":"",e.transmission?"#define USE_TRANSMISSION":"",e.transmissionMap?"#define USE_TRANSMISSIONMAP":"",e.thicknessMap?"#define USE_THICKNESSMAP":"",e.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",e.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",e.mapUv?"#define MAP_UV "+e.mapUv:"",e.alphaMapUv?"#define ALPHAMAP_UV "+e.alphaMapUv:"",e.lightMapUv?"#define LIGHTMAP_UV "+e.lightMapUv:"",e.aoMapUv?"#define AOMAP_UV "+e.aoMapUv:"",e.emissiveMapUv?"#define EMISSIVEMAP_UV "+e.emissiveMapUv:"",e.bumpMapUv?"#define BUMPMAP_UV "+e.bumpMapUv:"",e.normalMapUv?"#define NORMALMAP_UV "+e.normalMapUv:"",e.displacementMapUv?"#define DISPLACEMENTMAP_UV "+e.displacementMapUv:"",e.metalnessMapUv?"#define METALNESSMAP_UV "+e.metalnessMapUv:"",e.roughnessMapUv?"#define ROUGHNESSMAP_UV "+e.roughnessMapUv:"",e.anisotropyMapUv?"#define ANISOTROPYMAP_UV "+e.anisotropyMapUv:"",e.clearcoatMapUv?"#define CLEARCOATMAP_UV "+e.clearcoatMapUv:"",e.clearcoatNormalMapUv?"#define CLEARCOAT_NORMALMAP_UV "+e.clearcoatNormalMapUv:"",e.clearcoatRoughnessMapUv?"#define CLEARCOAT_ROUGHNESSMAP_UV "+e.clearcoatRoughnessMapUv:"",e.iridescenceMapUv?"#define IRIDESCENCEMAP_UV "+e.iridescenceMapUv:"",e.iridescenceThicknessMapUv?"#define IRIDESCENCE_THICKNESSMAP_UV "+e.iridescenceThicknessMapUv:"",e.sheenColorMapUv?"#define SHEEN_COLORMAP_UV "+e.sheenColorMapUv:"",e.sheenRoughnessMapUv?"#define SHEEN_ROUGHNESSMAP_UV "+e.sheenRoughnessMapUv:"",e.specularMapUv?"#define SPECULARMAP_UV "+e.specularMapUv:"",e.specularColorMapUv?"#define SPECULAR_COLORMAP_UV "+e.specularColorMapUv:"",e.specularIntensityMapUv?"#define SPECULAR_INTENSITYMAP_UV "+e.specularIntensityMapUv:"",e.transmissionMapUv?"#define TRANSMISSIONMAP_UV "+e.transmissionMapUv:"",e.thicknessMapUv?"#define THICKNESSMAP_UV "+e.thicknessMapUv:"",e.vertexTangents&&e.flatShading===!1?"#define USE_TANGENT":"",e.vertexNormals?"#define HAS_NORMAL":"",e.vertexColors?"#define USE_COLOR":"",e.vertexAlphas?"#define USE_COLOR_ALPHA":"",e.vertexUv1s?"#define USE_UV1":"",e.vertexUv2s?"#define USE_UV2":"",e.vertexUv3s?"#define USE_UV3":"",e.pointsUvs?"#define USE_POINTS_UV":"",e.flatShading?"#define FLAT_SHADED":"",e.skinning?"#define USE_SKINNING":"",e.morphTargets?"#define USE_MORPHTARGETS":"",e.morphNormals&&e.flatShading===!1?"#define USE_MORPHNORMALS":"",e.morphColors?"#define USE_MORPHCOLORS":"",e.morphTargetsCount>0?"#define MORPHTARGETS_TEXTURE_STRIDE "+e.morphTextureStride:"",e.morphTargetsCount>0?"#define MORPHTARGETS_COUNT "+e.morphTargetsCount:"",e.doubleSided?"#define DOUBLE_SIDED":"",e.flipSided?"#define FLIP_SIDED":"",e.shadowMapEnabled?"#define USE_SHADOWMAP":"",e.shadowMapEnabled?"#define "+c:"",e.sizeAttenuation?"#define USE_SIZEATTENUATION":"",e.numLightProbes>0?"#define USE_LIGHT_PROBES":"",e.logarithmicDepthBuffer?"#define USE_LOGARITHMIC_DEPTH_BUFFER":"",e.reversedDepthBuffer?"#define USE_REVERSED_DEPTH_BUFFER":"","uniform mat4 modelMatrix;","uniform mat4 modelViewMatrix;","uniform mat4 projectionMatrix;","uniform mat4 viewMatrix;","uniform mat3 normalMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;","#ifdef USE_INSTANCING","	attribute mat4 instanceMatrix;","#endif","#ifdef USE_INSTANCING_COLOR","	attribute vec3 instanceColor;","#endif","#ifdef USE_INSTANCING_MORPH","	uniform sampler2D morphTexture;","#endif","attribute vec3 position;","attribute vec3 normal;","attribute vec2 uv;","#ifdef USE_UV1","	attribute vec2 uv1;","#endif","#ifdef USE_UV2","	attribute vec2 uv2;","#endif","#ifdef USE_UV3","	attribute vec2 uv3;","#endif","#ifdef USE_TANGENT","	attribute vec4 tangent;","#endif","#if defined( USE_COLOR_ALPHA )","	attribute vec4 color;","#elif defined( USE_COLOR )","	attribute vec3 color;","#endif","#ifdef USE_SKINNING","	attribute vec4 skinIndex;","	attribute vec4 skinWeight;","#endif",`
`].filter(ao).join(`
`),p=[tf(e),"#define SHADER_TYPE "+e.shaderType,"#define SHADER_NAME "+e.shaderName,g,e.useFog&&e.fog?"#define USE_FOG":"",e.useFog&&e.fogExp2?"#define FOG_EXP2":"",e.alphaToCoverage?"#define ALPHA_TO_COVERAGE":"",e.map?"#define USE_MAP":"",e.matcap?"#define USE_MATCAP":"",e.envMap?"#define USE_ENVMAP":"",e.envMap?"#define "+l:"",e.envMap?"#define "+h:"",e.envMap?"#define "+f:"",u?"#define CUBEUV_TEXEL_WIDTH "+u.texelWidth:"",u?"#define CUBEUV_TEXEL_HEIGHT "+u.texelHeight:"",u?"#define CUBEUV_MAX_MIP "+u.maxMip+".0":"",e.lightMap?"#define USE_LIGHTMAP":"",e.aoMap?"#define USE_AOMAP":"",e.bumpMap?"#define USE_BUMPMAP":"",e.normalMap?"#define USE_NORMALMAP":"",e.normalMapObjectSpace?"#define USE_NORMALMAP_OBJECTSPACE":"",e.normalMapTangentSpace?"#define USE_NORMALMAP_TANGENTSPACE":"",e.packedNormalMap?"#define USE_PACKED_NORMALMAP":"",e.emissiveMap?"#define USE_EMISSIVEMAP":"",e.anisotropy?"#define USE_ANISOTROPY":"",e.anisotropyMap?"#define USE_ANISOTROPYMAP":"",e.clearcoat?"#define USE_CLEARCOAT":"",e.clearcoatMap?"#define USE_CLEARCOATMAP":"",e.clearcoatRoughnessMap?"#define USE_CLEARCOAT_ROUGHNESSMAP":"",e.clearcoatNormalMap?"#define USE_CLEARCOAT_NORMALMAP":"",e.dispersion?"#define USE_DISPERSION":"",e.retroreflection?"#define USE_RETROREFLECTION":"",e.iridescence?"#define USE_IRIDESCENCE":"",e.iridescenceMap?"#define USE_IRIDESCENCEMAP":"",e.iridescenceThicknessMap?"#define USE_IRIDESCENCE_THICKNESSMAP":"",e.specularMap?"#define USE_SPECULARMAP":"",e.specularColorMap?"#define USE_SPECULAR_COLORMAP":"",e.specularIntensityMap?"#define USE_SPECULAR_INTENSITYMAP":"",e.roughnessMap?"#define USE_ROUGHNESSMAP":"",e.metalnessMap?"#define USE_METALNESSMAP":"",e.alphaMap?"#define USE_ALPHAMAP":"",e.alphaTest?"#define USE_ALPHATEST":"",e.alphaHash?"#define USE_ALPHAHASH":"",e.sheen?"#define USE_SHEEN":"",e.sheenColorMap?"#define USE_SHEEN_COLORMAP":"",e.sheenRoughnessMap?"#define USE_SHEEN_ROUGHNESSMAP":"",e.transmission?"#define USE_TRANSMISSION":"",e.transmissionMap?"#define USE_TRANSMISSIONMAP":"",e.thicknessMap?"#define USE_THICKNESSMAP":"",e.vertexTangents&&e.flatShading===!1?"#define USE_TANGENT":"",e.vertexColors||e.instancingColor?"#define USE_COLOR":"",e.vertexAlphas||e.batchingColor?"#define USE_COLOR_ALPHA":"",e.vertexUv1s?"#define USE_UV1":"",e.vertexUv2s?"#define USE_UV2":"",e.vertexUv3s?"#define USE_UV3":"",e.pointsUvs?"#define USE_POINTS_UV":"",e.gradientMap?"#define USE_GRADIENTMAP":"",e.flatShading?"#define FLAT_SHADED":"",e.doubleSided?"#define DOUBLE_SIDED":"",e.flipSided?"#define FLIP_SIDED":"",e.shadowMapEnabled?"#define USE_SHADOWMAP":"",e.shadowMapEnabled?"#define "+c:"",e.premultipliedAlpha?"#define PREMULTIPLIED_ALPHA":"",e.numLightProbes>0?"#define USE_LIGHT_PROBES":"",e.numLightProbeGrids>0?"#define USE_LIGHT_PROBES_GRID":"",e.decodeVideoTexture?"#define DECODE_VIDEO_TEXTURE":"",e.decodeVideoTextureEmissive?"#define DECODE_VIDEO_TEXTURE_EMISSIVE":"",e.logarithmicDepthBuffer?"#define USE_LOGARITHMIC_DEPTH_BUFFER":"",e.reversedDepthBuffer?"#define USE_REVERSED_DEPTH_BUFFER":"","uniform mat4 viewMatrix;","uniform vec3 cameraPosition;","uniform bool isOrthographic;",e.toneMapping!==ci?"#define TONE_MAPPING":"",e.toneMapping!==ci?Me.tonemapping_pars_fragment:"",e.toneMapping!==ci?gx("toneMapping",e.toneMapping):"",e.dithering?"#define DITHERING":"",e.opaque?"#define OPAQUE":"",Me.colorspace_pars_fragment,px("linearToOutputTexel",e.outputColorSpace),xx(),e.useDepthPacking?"#define DEPTH_PACKING "+e.depthPacking:"",`
`].filter(ao).join(`
`)),a=bh(a),a=Kd(a,e),a=jd(a,e),o=bh(o),o=Kd(o,e),o=jd(o,e),a=Qd(a),o=Qd(o),e.isRawShaderMaterial!==!0&&(S=`#version 300 es
`,m=[d,"#define attribute in","#define varying out","#define texture2D texture"].join(`
`)+`
`+m,p=["#define varying in",e.glslVersion===ah?"":"layout(location = 0) out highp vec4 pc_fragColor;",e.glslVersion===ah?"":"#define gl_FragColor pc_fragColor","#define gl_FragDepthEXT gl_FragDepth","#define texture2D texture","#define textureCube texture","#define texture2DProj textureProj","#define texture2DLodEXT textureLod","#define texture2DProjLodEXT textureProjLod","#define textureCubeLodEXT textureLod","#define texture2DGradEXT textureGrad","#define texture2DProjGradEXT textureProjGrad","#define textureCubeGradEXT textureGrad"].join(`
`)+`
`+p);let w=S+m+a,y=S+p+o,E=Yd(s,s.VERTEX_SHADER,w),M=Yd(s,s.FRAGMENT_SHADER,y);s.attachShader(_,E),s.attachShader(_,M),e.index0AttributeName!==void 0?s.bindAttribLocation(_,0,e.index0AttributeName):e.hasPositionAttribute===!0&&s.bindAttribLocation(_,0,"position"),s.linkProgram(_);function I(N){if(i.debug.checkShaderErrors){let P=s.getProgramInfoLog(_)||"",B=s.getShaderInfoLog(E)||"",F=s.getShaderInfoLog(M)||"",W=P.trim(),rt=B.trim(),nt=F.trim(),dt=!0,Q=!0;if(s.getProgramParameter(_,s.LINK_STATUS)===!1)if(dt=!1,typeof i.debug.onShaderError=="function")i.debug.onShaderError(s,_,E,M);else{let ct=Jd(s,E,"vertex"),O=Jd(s,M,"fragment");he("WebGLProgram: Shader Error "+s.getError()+" - VALIDATE_STATUS "+s.getProgramParameter(_,s.VALIDATE_STATUS)+`

Material Name: `+N.name+`
Material Type: `+N.type+`

Program Info Log: `+W+`
`+ct+`
`+O)}else W!==""?ue("WebGLProgram: Program Info Log:",W):(rt===""||nt==="")&&(Q=!1);Q&&(N.diagnostics={runnable:dt,programLog:W,vertexShader:{log:rt,prefix:m},fragmentShader:{log:nt,prefix:p}})}s.deleteShader(E),s.deleteShader(M),v=new Pr(s,_),C=yx(s,_)}let v;this.getUniforms=function(){return v===void 0&&I(this),v};let C;this.getAttributes=function(){return C===void 0&&I(this),C};let L=e.rendererExtensionParallelShaderCompile===!1;return this.isReady=function(){return L===!1&&(L=s.getProgramParameter(_,hx)),L},this.destroy=function(){n.releaseStatesOfProgram(this),s.deleteProgram(_),this.program=void 0},this.type=e.shaderType,this.name=e.shaderName,this.id=ux++,this.cacheKey=t,this.usedTimes=1,this.program=_,this.vertexShader=E,this.fragmentShader=M,this}var Fx=0,Sh=class{constructor(){this.shaderCache=new Map,this.materialCache=new Map}update(t,e,n){let s=this._getShaderCacheForMaterial(t);return s.has(e)===!1&&(s.add(e),e.usedTimes++),s.has(n)===!1&&(s.add(n),n.usedTimes++),this}remove(t){let e=this.materialCache.get(t);for(let n of e)n.usedTimes--,n.usedTimes===0&&this.shaderCache.delete(n.code);return this.materialCache.delete(t),this}getVertexShaderStage(t){return this._getShaderStage(t.vertexShader)}getFragmentShaderStage(t){return this._getShaderStage(t.fragmentShader)}dispose(){this.shaderCache.clear(),this.materialCache.clear()}_getShaderCacheForMaterial(t){let e=this.materialCache,n=e.get(t);return n===void 0&&(n=new Set,e.set(t,n)),n}_getShaderStage(t){let e=this.shaderCache,n=e.get(t);return n===void 0&&(n=new Eh(t),e.set(t,n)),n}},Eh=class{constructor(t){this.id=Fx++,this.code=t,this.usedTimes=0}};function Ox(i){return i===ps||i===no||i===io}function Bx(i,t,e,n,s,r){let a=new hr,o=new Sh,c=new Set,l=[],h=new Map,f=n.logarithmicDepthBuffer,u=n.precision,d={MeshDepthMaterial:"depth",MeshDistanceMaterial:"distance",MeshNormalMaterial:"normal",MeshBasicMaterial:"basic",MeshLambertMaterial:"lambert",MeshPhongMaterial:"phong",MeshToonMaterial:"toon",MeshStandardMaterial:"physical",MeshPhysicalMaterial:"physical",MeshMatcapMaterial:"matcap",LineBasicMaterial:"basic",LineDashedMaterial:"dashed",PointsMaterial:"points",ShadowMaterial:"shadow",SpriteMaterial:"sprite"};function g(v){return c.add(v),v===0?"uv":`uv${v}`}function _(v,C,L,N,P,B){let F=N.fog,W=P.geometry,rt=v.isMeshStandardMaterial||v.isMeshLambertMaterial||v.isMeshPhongMaterial?N.environment:null,nt=v.isMeshStandardMaterial||v.isMeshLambertMaterial&&!v.envMap||v.isMeshPhongMaterial&&!v.envMap,dt=t.get(v.envMap||rt,nt),Q=dt&&dt.mapping===Ja?dt.image.height:null,ct=d[v.type];v.precision!==null&&(u=n.getMaxPrecision(v.precision),u!==v.precision&&ue("WebGLProgram.getParameters:",v.precision,"not supported, using",u,"instead."));let O=W.morphAttributes.position||W.morphAttributes.normal||W.morphAttributes.color,St=O!==void 0?O.length:0,Et=0;W.morphAttributes.position!==void 0&&(Et=1),W.morphAttributes.normal!==void 0&&(Et=2),W.morphAttributes.color!==void 0&&(Et=3);let At,Ot,Dt,tt;if(ct){let xe=wi[ct];At=xe.vertexShader,Ot=xe.fragmentShader}else{At=v.vertexShader,Ot=v.fragmentShader;let xe=o.getVertexShaderStage(v),Gt=o.getFragmentShaderStage(v);o.update(v,xe,Gt),Dt=xe.id,tt=Gt.id}let it=i.getRenderTarget(),_t=i.state.buffers.depth.getReversed(),bt=P.isInstancedMesh===!0,mt=P.isBatchedMesh===!0,Ct=!!v.map,Qt=!!v.matcap,V=!!dt,ut=!!v.aoMap,xt=!!v.lightMap,gt=!!v.bumpMap&&v.wireframe===!1,yt=!!v.normalMap,Bt=!!v.displacementMap,Ut=!!v.emissiveMap,Zt=!!v.metalnessMap,ee=!!v.roughnessMap,U=v.anisotropy>0,ne=v.clearcoat>0,re=v.dispersion>0,A=v.retroreflectivity>0,x=v.iridescence>0,G=v.sheen>0,Y=v.transmission>0,at=U&&!!v.anisotropyMap,Mt=ne&&!!v.clearcoatMap,Rt=ne&&!!v.clearcoatNormalMap,st=ne&&!!v.clearcoatRoughnessMap,ft=x&&!!v.iridescenceMap,Pt=x&&!!v.iridescenceThicknessMap,Ht=G&&!!v.sheenColorMap,Nt=G&&!!v.sheenRoughnessMap,Tt=!!v.specularMap,Xt=!!v.specularColorMap,Jt=!!v.specularIntensityMap,le=Y&&!!v.transmissionMap,z=Y&&!!v.thicknessMap,Ft=!!v.gradientMap,T=!!v.alphaMap,q=v.alphaTest>0,ht=!!v.alphaHash,X=!!v.extensions,zt=ci;v.toneMapped&&(it===null||it.isXRRenderTarget===!0)&&(zt=i.toneMapping);let wt={shaderID:ct,shaderType:v.type,shaderName:v.name,vertexShader:At,fragmentShader:Ot,defines:v.defines,customVertexShaderID:Dt,customFragmentShaderID:tt,isRawShaderMaterial:v.isRawShaderMaterial===!0,glslVersion:v.glslVersion,precision:u,batching:mt,batchingColor:mt&&P._colorsTexture!==null,instancing:bt,instancingColor:bt&&P.instanceColor!==null,instancingMorph:bt&&P.morphTexture!==null,outputColorSpace:it===null?i.outputColorSpace:it.isXRRenderTarget===!0?it.texture.colorSpace:Se.workingColorSpace,alphaToCoverage:!!v.alphaToCoverage,map:Ct,matcap:Qt,envMap:V,envMapMode:V&&dt.mapping,envMapCubeUVHeight:Q,aoMap:ut,lightMap:xt,bumpMap:gt,normalMap:yt,displacementMap:Bt,emissiveMap:Ut,normalMapObjectSpace:yt&&v.normalMapType===_d,normalMapTangentSpace:yt&&v.normalMapType===Mc,packedNormalMap:yt&&v.normalMapType===Mc&&Ox(v.normalMap.format),metalnessMap:Zt,roughnessMap:ee,anisotropy:U,anisotropyMap:at,clearcoat:ne,clearcoatMap:Mt,clearcoatNormalMap:Rt,clearcoatRoughnessMap:st,dispersion:re,retroreflection:A,iridescence:x,iridescenceMap:ft,iridescenceThicknessMap:Pt,sheen:G,sheenColorMap:Ht,sheenRoughnessMap:Nt,specularMap:Tt,specularColorMap:Xt,specularIntensityMap:Jt,transmission:Y,transmissionMap:le,thicknessMap:z,gradientMap:Ft,opaque:v.transparent===!1&&v.blending===us&&v.alphaToCoverage===!1,alphaMap:T,alphaTest:q,alphaHash:ht,combine:v.combine,mapUv:Ct&&g(v.map.channel),aoMapUv:ut&&g(v.aoMap.channel),lightMapUv:xt&&g(v.lightMap.channel),bumpMapUv:gt&&g(v.bumpMap.channel),normalMapUv:yt&&g(v.normalMap.channel),displacementMapUv:Bt&&g(v.displacementMap.channel),emissiveMapUv:Ut&&g(v.emissiveMap.channel),metalnessMapUv:Zt&&g(v.metalnessMap.channel),roughnessMapUv:ee&&g(v.roughnessMap.channel),anisotropyMapUv:at&&g(v.anisotropyMap.channel),clearcoatMapUv:Mt&&g(v.clearcoatMap.channel),clearcoatNormalMapUv:Rt&&g(v.clearcoatNormalMap.channel),clearcoatRoughnessMapUv:st&&g(v.clearcoatRoughnessMap.channel),iridescenceMapUv:ft&&g(v.iridescenceMap.channel),iridescenceThicknessMapUv:Pt&&g(v.iridescenceThicknessMap.channel),sheenColorMapUv:Ht&&g(v.sheenColorMap.channel),sheenRoughnessMapUv:Nt&&g(v.sheenRoughnessMap.channel),specularMapUv:Tt&&g(v.specularMap.channel),specularColorMapUv:Xt&&g(v.specularColorMap.channel),specularIntensityMapUv:Jt&&g(v.specularIntensityMap.channel),transmissionMapUv:le&&g(v.transmissionMap.channel),thicknessMapUv:z&&g(v.thicknessMap.channel),alphaMapUv:T&&g(v.alphaMap.channel),vertexTangents:!!W.attributes.tangent&&(yt||U),vertexNormals:!!W.attributes.normal,vertexColors:v.vertexColors,vertexAlphas:v.vertexColors===!0&&!!W.attributes.color&&W.attributes.color.itemSize===4,pointsUvs:P.isPoints===!0&&!!W.attributes.uv&&(Ct||T),fog:!!F,useFog:v.fog===!0,fogExp2:!!F&&F.isFogExp2,flatShading:v.wireframe===!1&&(v.flatShading===!0||W.attributes.normal===void 0&&yt===!1&&(v.isMeshLambertMaterial||v.isMeshPhongMaterial||v.isMeshStandardMaterial||v.isMeshPhysicalMaterial)),sizeAttenuation:v.sizeAttenuation===!0,logarithmicDepthBuffer:f,reversedDepthBuffer:_t,skinning:P.isSkinnedMesh===!0,hasPositionAttribute:W.attributes.position!==void 0,morphTargets:W.morphAttributes.position!==void 0,morphNormals:W.morphAttributes.normal!==void 0,morphColors:W.morphAttributes.color!==void 0,morphTargetsCount:St,morphTextureStride:Et,numSunLights:C.sun.length,numDirLights:C.directional.length,numPointLights:C.point.length,numSpotLights:C.spot.length,numSpotLightMaps:C.spotLightMap.length,numRectAreaLights:C.rectArea.length,numHemiLights:C.hemi.length,numSunLightShadows:C.sunShadowMap.length,numDirLightShadows:C.directionalShadowMap.length,numPointLightShadows:C.pointShadowMap.length,numSpotLightShadows:C.spotShadowMap.length,numSpotLightShadowsWithMaps:C.numSpotLightShadowsWithMaps,numLightProbes:C.numLightProbes,numLightProbeGrids:B.length,numClippingPlanes:r.numPlanes,numClipIntersection:r.numIntersection,dithering:v.dithering,shadowMapEnabled:i.shadowMap.enabled&&L.length>0,shadowMapType:i.shadowMap.type,toneMapping:zt,decodeVideoTexture:Ct&&v.map.isVideoTexture===!0&&Se.getTransfer(v.map.colorSpace)===Le,decodeVideoTextureEmissive:Ut&&v.emissiveMap.isVideoTexture===!0&&Se.getTransfer(v.emissiveMap.colorSpace)===Le,premultipliedAlpha:v.premultipliedAlpha,doubleSided:v.side===Sn,flipSided:v.side===bn,useDepthPacking:v.depthPacking>=0,depthPacking:v.depthPacking||0,index0AttributeName:v.index0AttributeName,extensionClipCullDistance:X&&v.extensions.clipCullDistance===!0&&e.has("WEBGL_clip_cull_distance"),extensionMultiDraw:(X&&v.extensions.multiDraw===!0||mt)&&e.has("WEBGL_multi_draw"),rendererExtensionParallelShaderCompile:e.has("KHR_parallel_shader_compile"),customProgramCacheKey:v.customProgramCacheKey()};return wt.vertexUv1s=c.has(1),wt.vertexUv2s=c.has(2),wt.vertexUv3s=c.has(3),c.clear(),wt}function m(v){let C=[];if(v.shaderID?C.push(v.shaderID):(C.push(v.customVertexShaderID),C.push(v.customFragmentShaderID)),v.defines!==void 0)for(let L in v.defines)C.push(L),C.push(v.defines[L]);return v.isRawShaderMaterial===!1&&(p(C,v),S(C,v),C.push(i.outputColorSpace)),C.push(v.customProgramCacheKey),C.join()}function p(v,C){v.push(C.precision),v.push(C.outputColorSpace),v.push(C.envMapMode),v.push(C.envMapCubeUVHeight),v.push(C.mapUv),v.push(C.alphaMapUv),v.push(C.lightMapUv),v.push(C.aoMapUv),v.push(C.bumpMapUv),v.push(C.normalMapUv),v.push(C.displacementMapUv),v.push(C.emissiveMapUv),v.push(C.metalnessMapUv),v.push(C.roughnessMapUv),v.push(C.anisotropyMapUv),v.push(C.clearcoatMapUv),v.push(C.clearcoatNormalMapUv),v.push(C.clearcoatRoughnessMapUv),v.push(C.iridescenceMapUv),v.push(C.iridescenceThicknessMapUv),v.push(C.sheenColorMapUv),v.push(C.sheenRoughnessMapUv),v.push(C.specularMapUv),v.push(C.specularColorMapUv),v.push(C.specularIntensityMapUv),v.push(C.transmissionMapUv),v.push(C.thicknessMapUv),v.push(C.combine),v.push(C.fogExp2),v.push(C.sizeAttenuation),v.push(C.morphTargetsCount),v.push(C.morphAttributeCount),v.push(C.numSunLights),v.push(C.numDirLights),v.push(C.numPointLights),v.push(C.numSpotLights),v.push(C.numSpotLightMaps),v.push(C.numHemiLights),v.push(C.numRectAreaLights),v.push(C.numSunLightShadows),v.push(C.numDirLightShadows),v.push(C.numPointLightShadows),v.push(C.numSpotLightShadows),v.push(C.numSpotLightShadowsWithMaps),v.push(C.numLightProbes),v.push(C.shadowMapType),v.push(C.toneMapping),v.push(C.numClippingPlanes),v.push(C.numClipIntersection),v.push(C.depthPacking)}function S(v,C){a.disableAll(),C.instancing&&a.enable(0),C.instancingColor&&a.enable(1),C.instancingMorph&&a.enable(2),C.matcap&&a.enable(3),C.envMap&&a.enable(4),C.normalMapObjectSpace&&a.enable(5),C.normalMapTangentSpace&&a.enable(6),C.clearcoat&&a.enable(7),C.iridescence&&a.enable(8),C.alphaTest&&a.enable(9),C.vertexColors&&a.enable(10),C.vertexAlphas&&a.enable(11),C.vertexUv1s&&a.enable(12),C.vertexUv2s&&a.enable(13),C.vertexUv3s&&a.enable(14),C.vertexTangents&&a.enable(15),C.anisotropy&&a.enable(16),C.alphaHash&&a.enable(17),C.batching&&a.enable(18),C.dispersion&&a.enable(19),C.retroreflection&&a.enable(24),C.batchingColor&&a.enable(20),C.gradientMap&&a.enable(21),C.packedNormalMap&&a.enable(22),C.vertexNormals&&a.enable(23),v.push(a.mask),a.disableAll(),C.fog&&a.enable(0),C.useFog&&a.enable(1),C.flatShading&&a.enable(2),C.logarithmicDepthBuffer&&a.enable(3),C.reversedDepthBuffer&&a.enable(4),C.skinning&&a.enable(5),C.morphTargets&&a.enable(6),C.morphNormals&&a.enable(7),C.morphColors&&a.enable(8),C.premultipliedAlpha&&a.enable(9),C.shadowMapEnabled&&a.enable(10),C.doubleSided&&a.enable(11),C.flipSided&&a.enable(12),C.useDepthPacking&&a.enable(13),C.dithering&&a.enable(14),C.transmission&&a.enable(15),C.sheen&&a.enable(16),C.opaque&&a.enable(17),C.pointsUvs&&a.enable(18),C.decodeVideoTexture&&a.enable(19),C.decodeVideoTextureEmissive&&a.enable(20),C.alphaToCoverage&&a.enable(21),C.numLightProbeGrids>0&&a.enable(22),C.hasPositionAttribute&&a.enable(23),v.push(a.mask)}function w(v){let C=d[v.type],L;if(C){let N=wi[C];L=Xi.clone(N.uniforms)}else L=v.uniforms;return L}function y(v,C){let L=h.get(C);return L!==void 0?++L.usedTimes:(L=new Ux(i,C,v,s),l.push(L),h.set(C,L)),L}function E(v){if(--v.usedTimes===0){let C=l.indexOf(v);l[C]=l[l.length-1],l.pop(),h.delete(v.cacheKey),v.destroy()}}function M(v){o.remove(v)}function I(){o.dispose()}return{getParameters:_,getProgramCacheKey:m,getUniforms:w,acquireProgram:y,releaseProgram:E,releaseShaderCache:M,programs:l,dispose:I}}function zx(){let i=new WeakMap;function t(a){return i.has(a)}function e(a){let o=i.get(a);return o===void 0&&(o={},i.set(a,o)),o}function n(a){i.delete(a)}function s(a,o,c){i.get(a)[o]=c}function r(){i=new WeakMap}return{has:t,get:e,remove:n,update:s,dispose:r}}function kx(i,t){return i.groupOrder!==t.groupOrder?i.groupOrder-t.groupOrder:i.renderOrder!==t.renderOrder?i.renderOrder-t.renderOrder:i.material.id!==t.material.id?i.material.id-t.material.id:i.materialVariant!==t.materialVariant?i.materialVariant-t.materialVariant:i.z!==t.z?i.z-t.z:i.id-t.id}function ef(i,t){return i.groupOrder!==t.groupOrder?i.groupOrder-t.groupOrder:i.renderOrder!==t.renderOrder?i.renderOrder-t.renderOrder:i.z!==t.z?t.z-i.z:i.id-t.id}function nf(){let i=[],t=0,e=[],n=[],s=[];function r(){t=0,e.length=0,n.length=0,s.length=0}function a(u){let d=0;return u.isInstancedMesh&&(d+=2),u.isSkinnedMesh&&(d+=1),d}function o(u,d,g,_,m,p){let S=i[t];return S===void 0?(S={id:u.id,object:u,geometry:d,material:g,materialVariant:a(u),groupOrder:_,renderOrder:u.renderOrder,z:m,group:p},i[t]=S):(S.id=u.id,S.object=u,S.geometry=d,S.material=g,S.materialVariant=a(u),S.groupOrder=_,S.renderOrder=u.renderOrder,S.z=m,S.group=p),t++,S}function c(u,d,g,_,m,p,S){S.reversedDepth===!0&&(m=-m);let w=o(u,d,g,_,m,p);g.transmission>0?n.push(w):g.transparent===!0?s.push(w):e.push(w)}function l(u,d,g,_,m,p){let S=o(u,d,g,_,m,p);g.transmission>0?n.unshift(S):g.transparent===!0?s.unshift(S):e.unshift(S)}function h(u,d){e.length>1&&e.sort(u||kx),n.length>1&&n.sort(d||ef),s.length>1&&s.sort(d||ef)}function f(){for(let u=t,d=i.length;u<d;u++){let g=i[u];if(g.id===null)break;g.id=null,g.object=null,g.geometry=null,g.material=null,g.group=null}}return{opaque:e,transmissive:n,transparent:s,init:r,push:c,unshift:l,finish:f,sort:h}}function Hx(){let i=new WeakMap;function t(n,s){let r=i.get(n),a;return r===void 0?(a=new nf,i.set(n,[a])):s>=r.length?(a=new nf,r.push(a)):a=r[s],a}function e(){i=new WeakMap}return{get:t,dispose:e}}function Vx(){let i={};return{get:function(t){if(i[t.id]!==void 0)return i[t.id];let e;switch(t.type){case"SunLight":case"DirectionalLight":e={direction:new D,color:new se};break;case"SpotLight":e={position:new D,direction:new D,color:new se,distance:0,coneCos:0,penumbraCos:0,decay:0};break;case"PointLight":e={position:new D,color:new se,distance:0,decay:0};break;case"HemisphereLight":e={direction:new D,skyColor:new se,groundColor:new se};break;case"RectAreaLight":e={color:new se,position:new D,halfWidth:new D,halfHeight:new D};break}return i[t.id]=e,e}}}function Gx(){let i={};return{get:function(t){if(i[t.id]!==void 0)return i[t.id];let e;switch(t.type){case"SunLight":case"DirectionalLight":e={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new vt};break;case"SpotLight":e={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new vt};break;case"PointLight":e={shadowIntensity:1,shadowBias:0,shadowNormalBias:0,shadowRadius:1,shadowMapSize:new vt,shadowCameraNear:1,shadowCameraFar:1e3};break}return i[t.id]=e,e}}}var Wx=0;function Xx(i,t){return(t.castShadow?2:0)-(i.castShadow?2:0)+(t.map?1:0)-(i.map?1:0)}function $x(i){let t=new Vx,e=Gx(),n={version:0,hash:{sunLength:-1,directionalLength:-1,pointLength:-1,spotLength:-1,rectAreaLength:-1,hemiLength:-1,numSunShadows:-1,numDirectionalShadows:-1,numPointShadows:-1,numSpotShadows:-1,numSpotMaps:-1,numLightProbes:-1},ambient:[0,0,0],probe:[],sun:[],sunShadow:[],sunShadowMap:[],sunShadowMatrix:[],sunShadowCascade:[],directional:[],directionalShadow:[],directionalShadowMap:[],directionalShadowMatrix:[],spot:[],spotLightMap:[],spotShadow:[],spotShadowMap:[],spotLightMatrix:[],rectArea:[],rectAreaLTC1:null,rectAreaLTC2:null,point:[],pointShadow:[],pointShadowMap:[],pointShadowMatrix:[],hemi:[],numSpotLightShadowsWithMaps:0,numLightProbes:0};for(let l=0;l<9;l++)n.probe.push(new D);let s=new D,r=new Ce,a=new Ce;function o(l){let h=0,f=0,u=0;for(let P=0;P<9;P++)n.probe[P].set(0,0,0);let d=0,g=0,_=0,m=0,p=0,S=0,w=0,y=0,E=0,M=0,I=0,v=0,C=0,L=0;l.sort(Xx);for(let P=0,B=l.length;P<B;P++){let F=l[P],W=F.color,rt=F.intensity,nt=F.distance,dt=null;if(F.shadow&&F.shadow.map&&(F.shadow.map.texture.format===ps?dt=F.shadow.map.texture:dt=F.shadow.map.depthTexture||F.shadow.map.texture),F.isAmbientLight)h+=W.r*rt,f+=W.g*rt,u+=W.b*rt;else if(F.isLightProbe){for(let Q=0;Q<9;Q++)n.probe[Q].addScaledVector(F.sh.coefficients[Q],rt);L++}else if(F.isSunLight){let Q=t.get(F);if(Q.color.copy(F.color).multiplyScalar(F.intensity),F.castShadow){let ct=F.shadow,O=e.get(F);O.shadowIntensity=ct.intensity,O.shadowBias=ct.bias,O.shadowNormalBias=ct.normalBias,O.shadowRadius=ct.radius,O.shadowMapSize.copy(ct.mapSize).multiply(ct.getFrameExtents()),n.sunShadow[g]=O,n.sunShadowMap[g]=dt;let St=ct.getViewportCount();for(let Et=0;Et<St;Et++)n.sunShadowMatrix[_+Et]=ct.getMatrix(Et),n.sunShadowCascade[_+Et]=ct._cascadeData[Et];_+=St,g++}n.sun[d]=Q,d++}else if(F.isDirectionalLight){let Q=t.get(F);if(Q.color.copy(F.color).multiplyScalar(F.intensity),F.castShadow){let ct=F.shadow,O=e.get(F);O.shadowIntensity=ct.intensity,O.shadowBias=ct.bias,O.shadowNormalBias=ct.normalBias,O.shadowRadius=ct.radius,O.shadowMapSize=ct.mapSize,n.directionalShadow[m]=O,n.directionalShadowMap[m]=dt,n.directionalShadowMatrix[m]=F.shadow.matrix,E++}n.directional[m]=Q,m++}else if(F.isSpotLight){let Q=t.get(F);Q.position.setFromMatrixPosition(F.matrixWorld),Q.color.copy(W).multiplyScalar(rt),Q.distance=nt,Q.coneCos=Math.cos(F.angle),Q.penumbraCos=Math.cos(F.angle*(1-F.penumbra)),Q.decay=F.decay,n.spot[S]=Q;let ct=F.shadow;if(F.map&&(n.spotLightMap[v]=F.map,v++,ct.updateMatrices(F),F.castShadow&&C++),n.spotLightMatrix[S]=ct.matrix,F.castShadow){let O=e.get(F);O.shadowIntensity=ct.intensity,O.shadowBias=ct.bias,O.shadowNormalBias=ct.normalBias,O.shadowRadius=ct.radius,O.shadowMapSize=ct.mapSize,n.spotShadow[S]=O,n.spotShadowMap[S]=dt,I++}S++}else if(F.isRectAreaLight){let Q=t.get(F);Q.color.copy(W).multiplyScalar(rt),Q.halfWidth.set(F.width*.5,0,0),Q.halfHeight.set(0,F.height*.5,0),n.rectArea[w]=Q,w++}else if(F.isPointLight){let Q=t.get(F);if(Q.color.copy(F.color).multiplyScalar(F.intensity),Q.distance=F.distance,Q.decay=F.decay,F.castShadow){let ct=F.shadow,O=e.get(F);O.shadowIntensity=ct.intensity,O.shadowBias=ct.bias,O.shadowNormalBias=ct.normalBias,O.shadowRadius=ct.radius,O.shadowMapSize=ct.mapSize,O.shadowCameraNear=ct.camera.near,O.shadowCameraFar=ct.camera.far,n.pointShadow[p]=O,n.pointShadowMap[p]=dt,n.pointShadowMatrix[p]=F.shadow.matrix,M++}n.point[p]=Q,p++}else if(F.isHemisphereLight){let Q=t.get(F);Q.skyColor.copy(F.color).multiplyScalar(rt),Q.groundColor.copy(F.groundColor).multiplyScalar(rt),n.hemi[y]=Q,y++}}w>0&&(i.has("OES_texture_float_linear")===!0?(n.rectAreaLTC1=Vt.LTC_FLOAT_1,n.rectAreaLTC2=Vt.LTC_FLOAT_2):(n.rectAreaLTC1=Vt.LTC_HALF_1,n.rectAreaLTC2=Vt.LTC_HALF_2)),n.ambient[0]=h,n.ambient[1]=f,n.ambient[2]=u;let N=n.hash;(N.sunLength!==d||N.directionalLength!==m||N.pointLength!==p||N.spotLength!==S||N.rectAreaLength!==w||N.hemiLength!==y||N.numSunShadows!==g||N.numDirectionalShadows!==E||N.numPointShadows!==M||N.numSpotShadows!==I||N.numSpotMaps!==v||N.numLightProbes!==L)&&(n.sun.length=d,n.directional.length=m,n.spot.length=S,n.rectArea.length=w,n.point.length=p,n.hemi.length=y,n.sunShadow.length=g,n.sunShadowMap.length=g,n.sunShadowMatrix.length=_,n.sunShadowCascade.length=_,n.directionalShadow.length=E,n.directionalShadowMap.length=E,n.directionalShadowMatrix.length=E,n.pointShadow.length=M,n.pointShadowMap.length=M,n.pointShadowMatrix.length=M,n.spotShadow.length=I,n.spotShadowMap.length=I,n.spotLightMatrix.length=I+v-C,n.spotLightMap.length=v,n.numSpotLightShadowsWithMaps=C,n.numLightProbes=L,N.sunLength=d,N.directionalLength=m,N.pointLength=p,N.spotLength=S,N.rectAreaLength=w,N.hemiLength=y,N.numSunShadows=g,N.numDirectionalShadows=E,N.numPointShadows=M,N.numSpotShadows=I,N.numSpotMaps=v,N.numLightProbes=L,n.version=Wx++)}function c(l,h){let f=0,u=0,d=0,g=0,_=0,m=0,p=h.matrixWorldInverse;for(let S=0,w=l.length;S<w;S++){let y=l[S];if(y.isSunLight){let E=n.sun[f];E.direction.setFromMatrixPosition(y.matrixWorld),E.direction.transformDirection(p),f++}else if(y.isDirectionalLight){let E=n.directional[u];E.direction.setFromMatrixPosition(y.matrixWorld),s.setFromMatrixPosition(y.target.matrixWorld),E.direction.sub(s),E.direction.transformDirection(p),u++}else if(y.isSpotLight){let E=n.spot[g];E.position.setFromMatrixPosition(y.matrixWorld),E.position.applyMatrix4(p),E.direction.setFromMatrixPosition(y.matrixWorld),s.setFromMatrixPosition(y.target.matrixWorld),E.direction.sub(s),E.direction.transformDirection(p),g++}else if(y.isRectAreaLight){let E=n.rectArea[_];E.position.setFromMatrixPosition(y.matrixWorld),E.position.applyMatrix4(p),a.identity(),r.copy(y.matrixWorld),r.premultiply(p),a.extractRotation(r),E.halfWidth.set(y.width*.5,0,0),E.halfHeight.set(0,y.height*.5,0),E.halfWidth.applyMatrix4(a),E.halfHeight.applyMatrix4(a),_++}else if(y.isPointLight){let E=n.point[d];E.position.setFromMatrixPosition(y.matrixWorld),E.position.applyMatrix4(p),d++}else if(y.isHemisphereLight){let E=n.hemi[m];E.direction.setFromMatrixPosition(y.matrixWorld),E.direction.transformDirection(p),m++}}}return{setup:o,setupView:c,state:n}}function sf(i){let t=new $x(i),e=[],n=[],s=[];function r(u){f.camera=u,e.length=0,n.length=0,s.length=0}function a(u){e.push(u)}function o(u){n.push(u)}function c(u){s.push(u)}function l(){t.setup(e)}function h(u){t.setupView(e,u)}let f={lightsArray:e,shadowsArray:n,lightProbeGridArray:s,camera:null,lights:t,transmissionRenderTarget:{},textureUnits:0};return{init:r,state:f,setupLights:l,setupLightsView:h,pushLight:a,pushShadow:o,pushLightProbeGrid:c}}function qx(i){let t=new WeakMap;function e(s,r=0){let a=t.get(s),o;return a===void 0?(o=new sf(i),t.set(s,[o])):r>=a.length?(o=new sf(i),a.push(o)):o=a[r],o}function n(){t=new WeakMap}return{get:e,dispose:n}}var Yx=`void main() {
	gl_Position = vec4( position, 1.0 );
}`,Zx=`uniform sampler2D shadow_pass;
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
}`,Jx=[new D(1,0,0),new D(-1,0,0),new D(0,1,0),new D(0,-1,0),new D(0,0,1),new D(0,0,-1)],Kx=[new D(0,-1,0),new D(0,-1,0),new D(0,0,1),new D(0,0,-1),new D(0,-1,0),new D(0,-1,0)],rf=new Ce,ro=new D,xh=new D;function jx(i,t,e){let n=new pr,s=new vt,r=new vt,a=new $e,o=new bl,c=new Sl,l={},h=e.maxTextureSize,f={[hs]:bn,[bn]:hs,[Sn]:Sn},u=new Oe({defines:{VSM_SAMPLES:8},uniforms:{shadow_pass:{value:null},resolution:{value:new vt},radius:{value:4}},vertexShader:Yx,fragmentShader:Zx}),d=u.clone();d.defines.HORIZONTAL_PASS=1;let g=new Ae;g.setAttribute("position",new tn(new Float32Array([-1,-1,.5,3,-1,.5,-1,3,.5]),3));let _=new ve(g,u),m=this;this.enabled=!1,this.autoUpdate=!0,this.needsUpdate=!1,this.type=Ga;let p=this.type;this.render=function(M,I,v){if(m.enabled===!1||m.autoUpdate===!1&&m.needsUpdate===!1||M.length===0)return;this.type===Zu&&(ue("WebGLShadowMap: PCFSoftShadowMap has been removed. Using PCFShadowMap instead."),this.type=Ga);let C=i.getRenderTarget(),L=i.getActiveCubeFace(),N=i.getActiveMipmapLevel(),P=i.state;P.setBlending(qn),P.buffers.depth.getReversed()===!0?P.buffers.color.setClear(0,0,0,0):P.buffers.color.setClear(1,1,1,1),P.buffers.depth.setTest(!0),P.setScissorTest(!1);let B=p!==this.type;B&&I.traverse(function(F){F.material&&(Array.isArray(F.material)?F.material.forEach(W=>W.needsUpdate=!0):F.material.needsUpdate=!0)});for(let F=0,W=M.length;F<W;F++){let rt=M[F],nt=rt.shadow;if(nt===void 0){ue("WebGLShadowMap:",rt,"has no shadow.");continue}if(nt.autoUpdate===!1&&nt.needsUpdate===!1)continue;s.copy(nt.mapSize);let dt=nt.getFrameExtents();s.multiply(dt),r.copy(nt.mapSize),(s.x>h||s.y>h)&&(s.x>h&&(r.x=Math.floor(h/dt.x),s.x=r.x*dt.x,nt.mapSize.x=r.x),s.y>h&&(r.y=Math.floor(h/dt.y),s.y=r.y*dt.y,nt.mapSize.y=r.y));let Q=i.state.buffers.depth.getReversed();if(nt.camera._reversedDepth=Q,nt.map===null||B===!0){if(nt.map!==null&&(nt.map.depthTexture!==null&&(nt.map.depthTexture.dispose(),nt.map.depthTexture=null),nt.map.dispose()),this.type===wr){if(rt.isPointLight){ue("WebGLShadowMap: VSM shadow maps are not supported for PointLights. Use PCF or BasicShadowMap instead.");continue}nt.map=new Ke(s.x,s.y,{format:ps,type:ln,minFilter:Mn,magFilter:Mn,generateMipmaps:!1}),nt.map.texture.name=rt.name+".shadowMap",nt.map.depthTexture=new ss(s.x,s.y,Yn),nt.map.depthTexture.name=rt.name+".shadowMapDepth",nt.map.depthTexture.format=vi,nt.map.depthTexture.compareFunction=null,nt.map.depthTexture.minFilter=mn,nt.map.depthTexture.magFilter=mn}else rt.isPointLight?(nt.map=new Ac(s.x),nt.map.depthTexture=new gl(s.x,hi)):(nt.map=new Ke(s.x,s.y),nt.map.depthTexture=new ss(s.x,s.y,hi)),nt.map.depthTexture.name=rt.name+".shadowMap",nt.map.depthTexture.format=vi,this.type===Ga?(nt.map.depthTexture.compareFunction=Q?Sc:bc,nt.map.depthTexture.minFilter=Mn,nt.map.depthTexture.magFilter=Mn):(nt.map.depthTexture.compareFunction=null,nt.map.depthTexture.minFilter=mn,nt.map.depthTexture.magFilter=mn);nt.camera.updateProjectionMatrix()}nt.map.isWebGLCubeRenderTarget!==!0&&(nt.map.width!==s.x||nt.map.height!==s.y)&&nt.map.setSize(s.x,s.y);let ct=nt.map.isWebGLCubeRenderTarget?6:nt.getViewportCount();rt.isPointLight!==!0&&nt.updateMatrices(rt,v);for(let O=0;O<ct;O++){let St=nt.getCamera(O);if(rt.isPointLight){let Et=nt.camera,At=nt.matrix,Ot=rt.distance||Et.far;Ot!==Et.far&&(Et.far=Ot,Et.updateProjectionMatrix()),ro.setFromMatrixPosition(rt.matrixWorld),Et.position.copy(ro),xh.copy(Et.position),xh.add(Jx[O]),Et.up.copy(Kx[O]),Et.lookAt(xh),Et.updateMatrixWorld(),At.makeTranslation(-ro.x,-ro.y,-ro.z),rf.multiplyMatrices(Et.projectionMatrix,Et.matrixWorldInverse),nt._frustum.setFromProjectionMatrix(rf,Et.coordinateSystem,Et.reversedDepth)}if(nt.map.isWebGLCubeRenderTarget)i.setRenderTarget(nt.map,O),i.clear();else{O===0&&(i.setRenderTarget(nt.map),i.clear());let Et=nt.getViewport(O);a.set(r.x*Et.x,r.y*Et.y,r.x*Et.z,r.y*Et.w),P.viewport(a)}n=nt.getFrustum(O),y(I,v,St,rt,this.type)}nt.isPointLightShadow!==!0&&this.type===wr&&S(nt,v),nt.needsUpdate=!1}p=this.type,m.needsUpdate=!1,i.setRenderTarget(C,L,N)};function S(M,I){let v=t.update(_);u.defines.VSM_SAMPLES!==M.blurSamples&&(u.defines.VSM_SAMPLES=M.blurSamples,d.defines.VSM_SAMPLES=M.blurSamples,u.needsUpdate=!0,d.needsUpdate=!0),M.mapPass===null?M.mapPass=new Ke(s.x,s.y,{format:ps,type:ln}):(M.mapPass.width!==M.map.width||M.mapPass.height!==M.map.height)&&M.mapPass.setSize(M.map.width,M.map.height),u.uniforms.shadow_pass.value=M.map.depthTexture,u.uniforms.resolution.value.set(M.map.width,M.map.height),u.uniforms.radius.value=M.radius,i.setRenderTarget(M.mapPass),i.clear(),i.renderBufferDirect(I,null,v,u,_,null),d.uniforms.shadow_pass.value=M.mapPass.texture,d.uniforms.resolution.value.set(M.map.width,M.map.height),d.uniforms.radius.value=M.radius,i.setRenderTarget(M.map),i.clear(),i.renderBufferDirect(I,null,v,d,_,null)}function w(M,I,v,C){let L=null,N=v.isPointLight===!0?M.customDistanceMaterial:M.customDepthMaterial;if(N!==void 0)L=N;else if(L=v.isPointLight===!0?c:o,i.localClippingEnabled&&I.clipShadows===!0&&Array.isArray(I.clippingPlanes)&&I.clippingPlanes.length!==0||I.displacementMap&&I.displacementScale!==0||I.alphaMap&&I.alphaTest>0||I.map&&I.alphaTest>0||I.alphaToCoverage===!0){let P=L.uuid,B=I.uuid,F=l[P];F===void 0&&(F={},l[P]=F);let W=F[B];W===void 0&&(W=L.clone(),F[B]=W,I.addEventListener("dispose",E)),L=W}if(L.visible=I.visible,L.wireframe=I.wireframe,C===wr?L.side=I.shadowSide!==null?I.shadowSide:I.side:L.side=I.shadowSide!==null?I.shadowSide:f[I.side],L.alphaMap=I.alphaMap,L.alphaTest=I.alphaToCoverage===!0?.5:I.alphaTest,L.map=I.map,L.clipShadows=I.clipShadows,L.clippingPlanes=I.clippingPlanes,L.clipIntersection=I.clipIntersection,L.displacementMap=I.displacementMap,L.displacementScale=I.displacementScale,L.displacementBias=I.displacementBias,L.wireframeLinewidth=I.wireframeLinewidth,L.linewidth=I.linewidth,v.isPointLight===!0&&L.isMeshDistanceMaterial===!0){let P=i.properties.get(L);P.light=v}return L}function y(M,I,v,C,L){if(M.visible===!1)return;if(M.layers.test(I.layers)&&(M.isMesh||M.isLine||M.isPoints)&&(M.castShadow||M.receiveShadow&&L===wr)&&(!M.frustumCulled||M.intersectsFrustum(n))){M.modelViewMatrix.multiplyMatrices(v.matrixWorldInverse,M.matrixWorld);let B=t.update(M),F=M.material;if(Array.isArray(F)){let W=B.groups;for(let rt=0,nt=W.length;rt<nt;rt++){let dt=W[rt],Q=F[dt.materialIndex];if(Q&&Q.visible){let ct=w(M,Q,C,L);M.onBeforeShadow(i,M,I,v,B,ct,dt),i.renderBufferDirect(v,null,B,ct,M,dt),M.onAfterShadow(i,M,I,v,B,ct,dt)}}}else if(F.visible){let W=w(M,F,C,L);M.onBeforeShadow(i,M,I,v,B,W,null),i.renderBufferDirect(v,null,B,W,M,null),M.onAfterShadow(i,M,I,v,B,W,null)}}let P=M.children;for(let B=0,F=P.length;B<F;B++)y(P[B],I,v,C,L)}function E(M){M.target.removeEventListener("dispose",E);for(let v in l){let C=l[v],L=M.target.uuid;L in C&&(C[L].dispose(),delete C[L])}}}function Qx(i,t){function e(){let z=!1,Ft=new $e,T=null,q=new $e(0,0,0,0);return{setMask:function(ht){T!==ht&&!z&&(i.colorMask(ht,ht,ht,ht),T=ht)},setLocked:function(ht){z=ht},setClear:function(ht,X,zt,wt,xe){xe===!0&&(ht*=wt,X*=wt,zt*=wt),Ft.set(ht,X,zt,wt),q.equals(Ft)===!1&&(i.clearColor(ht,X,zt,wt),q.copy(Ft))},reset:function(){z=!1,T=null,q.set(-1,0,0,0)}}}function n(){let z=!1,Ft=!1,T=null,q=null,ht=null;return{setReversed:function(X){if(Ft!==X){let zt=t.get("EXT_clip_control");X?zt.clipControlEXT(zt.LOWER_LEFT_EXT,zt.ZERO_TO_ONE_EXT):zt.clipControlEXT(zt.LOWER_LEFT_EXT,zt.NEGATIVE_ONE_TO_ONE_EXT),Ft=X;let wt=ht;ht=null,this.setClear(wt)}},getReversed:function(){return Ft},setTest:function(X){X?it(i.DEPTH_TEST):_t(i.DEPTH_TEST)},setMask:function(X){T!==X&&!z&&(i.depthMask(X),T=X)},setFunc:function(X){if(Ft&&(X=Cd[X]),q!==X){switch(X){case tl:i.depthFunc(i.NEVER);break;case el:i.depthFunc(i.ALWAYS);break;case nl:i.depthFunc(i.LESS);break;case rr:i.depthFunc(i.LEQUAL);break;case il:i.depthFunc(i.EQUAL);break;case sl:i.depthFunc(i.GEQUAL);break;case rl:i.depthFunc(i.GREATER);break;case al:i.depthFunc(i.NOTEQUAL);break;default:i.depthFunc(i.LEQUAL)}q=X}},setLocked:function(X){z=X},setClear:function(X){ht!==X&&(ht=X,Ft&&(X=1-X),i.clearDepth(X))},reset:function(){z=!1,T=null,q=null,ht=null,Ft=!1}}}function s(){let z=!1,Ft=null,T=null,q=null,ht=null,X=null,zt=null,wt=null,xe=null;return{setTest:function(Gt){z||(Gt?it(i.STENCIL_TEST):_t(i.STENCIL_TEST))},setMask:function(Gt){Ft!==Gt&&!z&&(i.stencilMask(Gt),Ft=Gt)},setFunc:function(Gt,ie,ke){(T!==Gt||q!==ie||ht!==ke)&&(i.stencilFunc(Gt,ie,ke),T=Gt,q=ie,ht=ke)},setOp:function(Gt,ie,ke){(X!==Gt||zt!==ie||wt!==ke)&&(i.stencilOp(Gt,ie,ke),X=Gt,zt=ie,wt=ke)},setLocked:function(Gt){z=Gt},setClear:function(Gt){xe!==Gt&&(i.clearStencil(Gt),xe=Gt)},reset:function(){z=!1,Ft=null,T=null,q=null,ht=null,X=null,zt=null,wt=null,xe=null}}}let r=new e,a=new n,o=new s,c=new WeakMap,l=new WeakMap,h={},f={},u={},d=new WeakMap,g=[],_=null,m=!1,p=null,S=null,w=null,y=null,E=null,M=null,I=null,v=new se(0,0,0),C=0,L=!1,N=null,P=null,B=null,F=null,W=null,rt=i.getParameter(i.MAX_COMBINED_TEXTURE_IMAGE_UNITS),nt=!1,dt=0,Q=i.getParameter(i.VERSION);Q.indexOf("WebGL")!==-1?(dt=parseFloat(/^WebGL (\d)/.exec(Q)[1]),nt=dt>=1):Q.indexOf("OpenGL ES")!==-1&&(dt=parseFloat(/^OpenGL ES (\d)/.exec(Q)[1]),nt=dt>=2);let ct=null,O={},St=i.getParameter(i.SCISSOR_BOX),Et=i.getParameter(i.VIEWPORT),At=new $e().fromArray(St),Ot=new $e().fromArray(Et);function Dt(z,Ft,T,q){let ht=new Uint8Array(4),X=i.createTexture();i.bindTexture(z,X),i.texParameteri(z,i.TEXTURE_MIN_FILTER,i.NEAREST),i.texParameteri(z,i.TEXTURE_MAG_FILTER,i.NEAREST);for(let zt=0;zt<T;zt++)z===i.TEXTURE_3D||z===i.TEXTURE_2D_ARRAY?i.texImage3D(Ft,0,i.RGBA,1,1,q,0,i.RGBA,i.UNSIGNED_BYTE,ht):i.texImage2D(Ft+zt,0,i.RGBA,1,1,0,i.RGBA,i.UNSIGNED_BYTE,ht);return X}let tt={};tt[i.TEXTURE_2D]=Dt(i.TEXTURE_2D,i.TEXTURE_2D,1),tt[i.TEXTURE_CUBE_MAP]=Dt(i.TEXTURE_CUBE_MAP,i.TEXTURE_CUBE_MAP_POSITIVE_X,6),tt[i.TEXTURE_2D_ARRAY]=Dt(i.TEXTURE_2D_ARRAY,i.TEXTURE_2D_ARRAY,1,1),tt[i.TEXTURE_3D]=Dt(i.TEXTURE_3D,i.TEXTURE_3D,1,1),r.setClear(0,0,0,1),a.setClear(1),o.setClear(0),it(i.DEPTH_TEST),a.setFunc(rr),gt(!1),yt($0),it(i.CULL_FACE),ut(qn);function it(z){h[z]!==!0&&(i.enable(z),h[z]=!0)}function _t(z){h[z]!==!1&&(i.disable(z),h[z]=!1)}function bt(z,Ft){return u[z]!==Ft?(i.bindFramebuffer(z,Ft),u[z]=Ft,z===i.DRAW_FRAMEBUFFER&&(u[i.FRAMEBUFFER]=Ft),z===i.FRAMEBUFFER&&(u[i.DRAW_FRAMEBUFFER]=Ft),!0):!1}function mt(z,Ft){let T=g,q=!1;if(z){T=d.get(Ft),T===void 0&&(T=[],d.set(Ft,T));let ht=z.textures;if(T.length!==ht.length||T[0]!==i.COLOR_ATTACHMENT0){for(let X=0,zt=ht.length;X<zt;X++)T[X]=i.COLOR_ATTACHMENT0+X;T.length=ht.length,q=!0}}else T[0]!==i.BACK&&(T[0]=i.BACK,q=!0);q&&i.drawBuffers(T)}function Ct(z){return _!==z?(i.useProgram(z),_=z,!0):!1}let Qt={[ws]:i.FUNC_ADD,[Ku]:i.FUNC_SUBTRACT,[ju]:i.FUNC_REVERSE_SUBTRACT};Qt[Qu]=i.MIN,Qt[td]=i.MAX;let V={[ed]:i.ZERO,[nd]:i.ONE,[id]:i.SRC_COLOR,[Z0]:i.SRC_ALPHA,[cd]:i.SRC_ALPHA_SATURATE,[od]:i.DST_COLOR,[rd]:i.DST_ALPHA,[sd]:i.ONE_MINUS_SRC_COLOR,[J0]:i.ONE_MINUS_SRC_ALPHA,[ld]:i.ONE_MINUS_DST_COLOR,[ad]:i.ONE_MINUS_DST_ALPHA,[hd]:i.CONSTANT_COLOR,[ud]:i.ONE_MINUS_CONSTANT_COLOR,[dd]:i.CONSTANT_ALPHA,[fd]:i.ONE_MINUS_CONSTANT_ALPHA};function ut(z,Ft,T,q,ht,X,zt,wt,xe,Gt){if(z===qn){m===!0&&(_t(i.BLEND),m=!1);return}if(m===!1&&(it(i.BLEND),m=!0),z!==Ju){if(z!==p||Gt!==L){if((S!==ws||E!==ws)&&(i.blendEquation(i.FUNC_ADD),S=ws,E=ws),Gt)switch(z){case us:i.blendFuncSeparate(i.ONE,i.ONE_MINUS_SRC_ALPHA,i.ONE,i.ONE_MINUS_SRC_ALPHA);break;case on:i.blendFunc(i.ONE,i.ONE);break;case q0:i.blendFuncSeparate(i.ZERO,i.ONE_MINUS_SRC_COLOR,i.ZERO,i.ONE);break;case Y0:i.blendFuncSeparate(i.DST_COLOR,i.ONE_MINUS_SRC_ALPHA,i.ZERO,i.ONE);break;default:he("WebGLState: Invalid blending: ",z);break}else switch(z){case us:i.blendFuncSeparate(i.SRC_ALPHA,i.ONE_MINUS_SRC_ALPHA,i.ONE,i.ONE_MINUS_SRC_ALPHA);break;case on:i.blendFuncSeparate(i.SRC_ALPHA,i.ONE,i.ONE,i.ONE);break;case q0:he("WebGLState: SubtractiveBlending requires material.premultipliedAlpha = true");break;case Y0:he("WebGLState: MultiplyBlending requires material.premultipliedAlpha = true");break;default:he("WebGLState: Invalid blending: ",z);break}w=null,y=null,M=null,I=null,v.set(0,0,0),C=0,p=z,L=Gt}return}ht=ht||Ft,X=X||T,zt=zt||q,(Ft!==S||ht!==E)&&(i.blendEquationSeparate(Qt[Ft],Qt[ht]),S=Ft,E=ht),(T!==w||q!==y||X!==M||zt!==I)&&(i.blendFuncSeparate(V[T],V[q],V[X],V[zt]),w=T,y=q,M=X,I=zt),(wt.equals(v)===!1||xe!==C)&&(i.blendColor(wt.r,wt.g,wt.b,xe),v.copy(wt),C=xe),p=z,L=!1}function xt(z,Ft){z.side===Sn?_t(i.CULL_FACE):it(i.CULL_FACE);let T=z.side===bn;Ft&&(T=!T),gt(T),z.blending===us&&z.transparent===!1?ut(qn):ut(z.blending,z.blendEquation,z.blendSrc,z.blendDst,z.blendEquationAlpha,z.blendSrcAlpha,z.blendDstAlpha,z.blendColor,z.blendAlpha,z.premultipliedAlpha),a.setFunc(z.depthFunc),a.setTest(z.depthTest),a.setMask(z.depthWrite),r.setMask(z.colorWrite);let q=z.stencilWrite;o.setTest(q),q&&(o.setMask(z.stencilWriteMask),o.setFunc(z.stencilFunc,z.stencilRef,z.stencilFuncMask),o.setOp(z.stencilFail,z.stencilZFail,z.stencilZPass)),Ut(z.polygonOffset,z.polygonOffsetFactor,z.polygonOffsetUnits),z.alphaToCoverage===!0?it(i.SAMPLE_ALPHA_TO_COVERAGE):_t(i.SAMPLE_ALPHA_TO_COVERAGE)}function gt(z){N!==z&&(z?i.frontFace(i.CW):i.frontFace(i.CCW),N=z)}function yt(z){z!==qu?(it(i.CULL_FACE),z!==P&&(z===$0?i.cullFace(i.BACK):z===Yu?i.cullFace(i.FRONT):i.cullFace(i.FRONT_AND_BACK))):_t(i.CULL_FACE),P=z}function Bt(z){z!==B&&(nt&&i.lineWidth(z),B=z)}function Ut(z,Ft,T){z?(it(i.POLYGON_OFFSET_FILL),(F!==Ft||W!==T)&&(F=Ft,W=T,a.getReversed()&&(Ft=-Ft),i.polygonOffset(Ft,T))):_t(i.POLYGON_OFFSET_FILL)}function Zt(z){z?it(i.SCISSOR_TEST):_t(i.SCISSOR_TEST)}function ee(z){z===void 0&&(z=i.TEXTURE0+rt-1),ct!==z&&(i.activeTexture(z),ct=z)}function U(z,Ft,T){T===void 0&&(ct===null?T=i.TEXTURE0+rt-1:T=ct);let q=O[T];q===void 0&&(q={type:void 0,texture:void 0},O[T]=q),(q.type!==z||q.texture!==Ft)&&(ct!==T&&(i.activeTexture(T),ct=T),i.bindTexture(z,Ft||tt[z]),q.type=z,q.texture=Ft)}function ne(){let z=O[ct];z!==void 0&&z.type!==void 0&&(i.bindTexture(z.type,null),z.type=void 0,z.texture=void 0)}function re(){try{i.compressedTexImage2D(...arguments)}catch(z){he("WebGLState:",z)}}function A(){try{i.compressedTexImage3D(...arguments)}catch(z){he("WebGLState:",z)}}function x(){try{i.texSubImage2D(...arguments)}catch(z){he("WebGLState:",z)}}function G(){try{i.texSubImage3D(...arguments)}catch(z){he("WebGLState:",z)}}function Y(){try{i.compressedTexSubImage2D(...arguments)}catch(z){he("WebGLState:",z)}}function at(){try{i.compressedTexSubImage3D(...arguments)}catch(z){he("WebGLState:",z)}}function Mt(){try{i.texStorage2D(...arguments)}catch(z){he("WebGLState:",z)}}function Rt(){try{i.texStorage3D(...arguments)}catch(z){he("WebGLState:",z)}}function st(){try{i.texImage2D(...arguments)}catch(z){he("WebGLState:",z)}}function ft(){try{i.texImage3D(...arguments)}catch(z){he("WebGLState:",z)}}function Pt(z){return f[z]!==void 0?f[z]:i.getParameter(z)}function Ht(z,Ft){f[z]!==Ft&&(i.pixelStorei(z,Ft),f[z]=Ft)}function Nt(z){At.equals(z)===!1&&(i.scissor(z.x,z.y,z.z,z.w),At.copy(z))}function Tt(z){Ot.equals(z)===!1&&(i.viewport(z.x,z.y,z.z,z.w),Ot.copy(z))}function Xt(z,Ft){let T=l.get(Ft);T===void 0&&(T=new WeakMap,l.set(Ft,T));let q=T.get(z);q===void 0&&(q=i.getUniformBlockIndex(Ft,z.name),T.set(z,q))}function Jt(z,Ft){let q=l.get(Ft).get(z);c.get(Ft)!==q&&(i.uniformBlockBinding(Ft,q,z.__bindingPointIndex),c.set(Ft,q))}function le(){i.disable(i.BLEND),i.disable(i.CULL_FACE),i.disable(i.DEPTH_TEST),i.disable(i.POLYGON_OFFSET_FILL),i.disable(i.SCISSOR_TEST),i.disable(i.STENCIL_TEST),i.disable(i.SAMPLE_ALPHA_TO_COVERAGE),i.blendEquation(i.FUNC_ADD),i.blendFunc(i.ONE,i.ZERO),i.blendFuncSeparate(i.ONE,i.ZERO,i.ONE,i.ZERO),i.blendColor(0,0,0,0),i.colorMask(!0,!0,!0,!0),i.clearColor(0,0,0,0),i.depthMask(!0),i.depthFunc(i.LESS),a.setReversed(!1),i.clearDepth(1),i.stencilMask(4294967295),i.stencilFunc(i.ALWAYS,0,4294967295),i.stencilOp(i.KEEP,i.KEEP,i.KEEP),i.clearStencil(0),i.cullFace(i.BACK),i.frontFace(i.CCW),i.polygonOffset(0,0),i.activeTexture(i.TEXTURE0),i.bindFramebuffer(i.FRAMEBUFFER,null),i.bindFramebuffer(i.DRAW_FRAMEBUFFER,null),i.bindFramebuffer(i.READ_FRAMEBUFFER,null),i.useProgram(null),i.lineWidth(1),i.scissor(0,0,i.canvas.width,i.canvas.height),i.viewport(0,0,i.canvas.width,i.canvas.height),i.pixelStorei(i.PACK_ALIGNMENT,4),i.pixelStorei(i.UNPACK_ALIGNMENT,4),i.pixelStorei(i.UNPACK_FLIP_Y_WEBGL,!1),i.pixelStorei(i.UNPACK_PREMULTIPLY_ALPHA_WEBGL,!1),i.pixelStorei(i.UNPACK_COLORSPACE_CONVERSION_WEBGL,i.BROWSER_DEFAULT_WEBGL),i.pixelStorei(i.PACK_ROW_LENGTH,0),i.pixelStorei(i.PACK_SKIP_PIXELS,0),i.pixelStorei(i.PACK_SKIP_ROWS,0),i.pixelStorei(i.UNPACK_ROW_LENGTH,0),i.pixelStorei(i.UNPACK_IMAGE_HEIGHT,0),i.pixelStorei(i.UNPACK_SKIP_PIXELS,0),i.pixelStorei(i.UNPACK_SKIP_ROWS,0),i.pixelStorei(i.UNPACK_SKIP_IMAGES,0),h={},f={},ct=null,O={},u={},d=new WeakMap,g=[],_=null,m=!1,p=null,S=null,w=null,y=null,E=null,M=null,I=null,v=new se(0,0,0),C=0,L=!1,N=null,P=null,B=null,F=null,W=null,At.set(0,0,i.canvas.width,i.canvas.height),Ot.set(0,0,i.canvas.width,i.canvas.height),r.reset(),a.reset(),o.reset()}return{buffers:{color:r,depth:a,stencil:o},enable:it,disable:_t,bindFramebuffer:bt,drawBuffers:mt,useProgram:Ct,setBlending:ut,setMaterial:xt,setFlipSided:gt,setCullFace:yt,setLineWidth:Bt,setPolygonOffset:Ut,setScissorTest:Zt,activeTexture:ee,bindTexture:U,unbindTexture:ne,compressedTexImage2D:re,compressedTexImage3D:A,texImage2D:st,texImage3D:ft,pixelStorei:Ht,getParameter:Pt,updateUBOMapping:Xt,uniformBlockBinding:Jt,texStorage2D:Mt,texStorage3D:Rt,texSubImage2D:x,texSubImage3D:G,compressedTexSubImage2D:Y,compressedTexSubImage3D:at,scissor:Nt,viewport:Tt,reset:le}}function t3(i,t,e,n,s,r,a){let o=t.has("WEBGL_multisampled_render_to_texture")?t.get("WEBGL_multisampled_render_to_texture"):null,c=typeof navigator>"u"?!1:/OculusBrowser/g.test(navigator.userAgent),l=new vt,h=new WeakMap,f=new Set,u,d=new WeakMap,g=!1;try{g=typeof OffscreenCanvas<"u"&&new OffscreenCanvas(1,1).getContext("2d")!==null}catch{}function _(A,x){return g?new OffscreenCanvas(A,x):or("canvas")}function m(A,x,G){let Y=1,at=re(A);if((at.width>G||at.height>G)&&(Y=G/Math.max(at.width,at.height)),Y<1)if(typeof HTMLImageElement<"u"&&A instanceof HTMLImageElement||typeof HTMLCanvasElement<"u"&&A instanceof HTMLCanvasElement||typeof ImageBitmap<"u"&&A instanceof ImageBitmap||typeof VideoFrame<"u"&&A instanceof VideoFrame){let Mt=Math.floor(Y*at.width),Rt=Math.floor(Y*at.height);u===void 0&&(u=_(Mt,Rt));let st=x?_(Mt,Rt):u;return st.width=Mt,st.height=Rt,st.getContext("2d").drawImage(A,0,0,Mt,Rt),ue("WebGLRenderer: Texture has been resized from ("+at.width+"x"+at.height+") to ("+Mt+"x"+Rt+")."),st}else return"data"in A&&ue("WebGLRenderer: Image in DataTexture is too big ("+at.width+"x"+at.height+")."),A;return A}function p(A){return A.generateMipmaps}function S(A){i.generateMipmap(A)}function w(A){return A.isWebGLCubeRenderTarget?i.TEXTURE_CUBE_MAP:A.isWebGL3DRenderTarget?i.TEXTURE_3D:A.isWebGLArrayRenderTarget||A.isCompressedArrayTexture?i.TEXTURE_2D_ARRAY:i.TEXTURE_2D}function y(A,x,G,Y,at,Mt=!1){if(A!==null){if(i[A]!==void 0)return i[A];ue("WebGLRenderer: Attempt to use non-existing WebGL internal format '"+A+"'")}let Rt;Y&&(Rt=t.get("EXT_texture_norm16"),Rt||ue("WebGLRenderer: Unable to use normalized textures without EXT_texture_norm16 extension"));let st=x;if(x===i.RED&&(G===i.FLOAT&&(st=i.R32F),G===i.HALF_FLOAT&&(st=i.R16F),G===i.UNSIGNED_BYTE&&(st=i.R8),G===i.UNSIGNED_SHORT&&Rt&&(st=Rt.R16_EXT),G===i.SHORT&&Rt&&(st=Rt.R16_SNORM_EXT)),x===i.RED_INTEGER&&(G===i.UNSIGNED_BYTE&&(st=i.R8UI),G===i.UNSIGNED_SHORT&&(st=i.R16UI),G===i.UNSIGNED_INT&&(st=i.R32UI),G===i.BYTE&&(st=i.R8I),G===i.SHORT&&(st=i.R16I),G===i.INT&&(st=i.R32I)),x===i.RG&&(G===i.FLOAT&&(st=i.RG32F),G===i.HALF_FLOAT&&(st=i.RG16F),G===i.UNSIGNED_BYTE&&(st=i.RG8),G===i.UNSIGNED_SHORT&&Rt&&(st=Rt.RG16_EXT),G===i.SHORT&&Rt&&(st=Rt.RG16_SNORM_EXT)),x===i.RG_INTEGER&&(G===i.UNSIGNED_BYTE&&(st=i.RG8UI),G===i.UNSIGNED_SHORT&&(st=i.RG16UI),G===i.UNSIGNED_INT&&(st=i.RG32UI),G===i.BYTE&&(st=i.RG8I),G===i.SHORT&&(st=i.RG16I),G===i.INT&&(st=i.RG32I)),x===i.RGB_INTEGER&&(G===i.UNSIGNED_BYTE&&(st=i.RGB8UI),G===i.UNSIGNED_SHORT&&(st=i.RGB16UI),G===i.UNSIGNED_INT&&(st=i.RGB32UI),G===i.BYTE&&(st=i.RGB8I),G===i.SHORT&&(st=i.RGB16I),G===i.INT&&(st=i.RGB32I)),x===i.RGBA_INTEGER&&(G===i.UNSIGNED_BYTE&&(st=i.RGBA8UI),G===i.UNSIGNED_SHORT&&(st=i.RGBA16UI),G===i.UNSIGNED_INT&&(st=i.RGBA32UI),G===i.BYTE&&(st=i.RGBA8I),G===i.SHORT&&(st=i.RGBA16I),G===i.INT&&(st=i.RGBA32I)),x===i.RGB&&(G===i.UNSIGNED_SHORT&&Rt&&(st=Rt.RGB16_EXT),G===i.SHORT&&Rt&&(st=Rt.RGB16_SNORM_EXT),G===i.UNSIGNED_INT_5_9_9_9_REV&&(st=i.RGB9_E5),G===i.UNSIGNED_INT_10F_11F_11F_REV&&(st=i.R11F_G11F_B10F)),x===i.RGBA){let ft=Mt?aa:Se.getTransfer(at);G===i.FLOAT&&(st=i.RGBA32F),G===i.HALF_FLOAT&&(st=i.RGBA16F),G===i.UNSIGNED_BYTE&&(st=ft===Le?i.SRGB8_ALPHA8:i.RGBA8),G===i.UNSIGNED_SHORT&&Rt&&(st=Rt.RGBA16_EXT),G===i.SHORT&&Rt&&(st=Rt.RGBA16_SNORM_EXT),G===i.UNSIGNED_SHORT_4_4_4_4&&(st=i.RGBA4),G===i.UNSIGNED_SHORT_5_5_5_1&&(st=i.RGB5_A1)}return(st===i.R16F||st===i.R32F||st===i.RG16F||st===i.RG32F||st===i.RGBA16F||st===i.RGBA32F)&&t.get("EXT_color_buffer_float"),st}function E(A,x){let G;return A?x===null||x===hi||x===Rr?G=i.DEPTH24_STENCIL8:x===Yn?G=i.DEPTH32F_STENCIL8:x===Ar&&(G=i.DEPTH24_STENCIL8,ue("DepthTexture: 16 bit depth attachment is not supported with stencil. Using 24-bit attachment.")):x===null||x===hi||x===Rr?G=i.DEPTH_COMPONENT24:x===Yn?G=i.DEPTH_COMPONENT32F:x===Ar&&(G=i.DEPTH_COMPONENT16),G}function M(A,x){return p(A)===!0||A.isFramebufferTexture&&A.minFilter!==mn&&A.minFilter!==Mn?Math.log2(Math.max(x.width,x.height))+1:A.mipmaps!==void 0&&A.mipmaps.length>0?A.mipmaps.length:A.isCompressedTexture&&Array.isArray(A.image)?x.mipmaps.length:1}function I(A){let x=A.target;x.removeEventListener("dispose",I),C(x),x.isVideoTexture&&h.delete(x),x.isHTMLTexture&&f.delete(x)}function v(A){let x=A.target;x.removeEventListener("dispose",v),N(x)}function C(A){let x=n.get(A);if(x.__webglInit===void 0)return;let G=A.source,Y=d.get(G);if(Y){let at=Y[x.__cacheKey];at.usedTimes--,at.usedTimes===0&&L(A),Object.keys(Y).length===0&&d.delete(G)}n.remove(A)}function L(A){let x=n.get(A);i.deleteTexture(x.__webglTexture);let G=A.source,Y=d.get(G);delete Y[x.__cacheKey],a.memory.textures--}function N(A){let x=n.get(A);if(A.depthTexture&&(A.depthTexture.dispose(),n.remove(A.depthTexture)),A.isWebGLCubeRenderTarget)for(let Y=0;Y<6;Y++){if(Array.isArray(x.__webglFramebuffer[Y]))for(let at=0;at<x.__webglFramebuffer[Y].length;at++)i.deleteFramebuffer(x.__webglFramebuffer[Y][at]);else i.deleteFramebuffer(x.__webglFramebuffer[Y]);x.__webglDepthbuffer&&i.deleteRenderbuffer(x.__webglDepthbuffer[Y])}else{if(Array.isArray(x.__webglFramebuffer))for(let Y=0;Y<x.__webglFramebuffer.length;Y++)i.deleteFramebuffer(x.__webglFramebuffer[Y]);else i.deleteFramebuffer(x.__webglFramebuffer);if(x.__webglDepthbuffer&&i.deleteRenderbuffer(x.__webglDepthbuffer),x.__webglMultisampledFramebuffer&&i.deleteFramebuffer(x.__webglMultisampledFramebuffer),x.__webglColorRenderbuffer)for(let Y=0;Y<x.__webglColorRenderbuffer.length;Y++)x.__webglColorRenderbuffer[Y]&&i.deleteRenderbuffer(x.__webglColorRenderbuffer[Y]);x.__webglDepthRenderbuffer&&i.deleteRenderbuffer(x.__webglDepthRenderbuffer)}let G=A.textures;for(let Y=0,at=G.length;Y<at;Y++){let Mt=n.get(G[Y]);Mt.__webglTexture&&(i.deleteTexture(Mt.__webglTexture),a.memory.textures--),n.remove(G[Y])}n.remove(A)}let P=0;function B(){P=0}function F(){return P}function W(A){P=A}function rt(){let A=P;return A>=s.maxTextures&&ue("WebGLTextures: Trying to use "+(A+1)+" texture units while this GPU supports only "+s.maxTextures),P+=1,A}function nt(A){let x=[];return x.push(A.wrapS),x.push(A.wrapT),x.push(A.wrapR||0),x.push(A.magFilter),x.push(A.minFilter),x.push(A.anisotropy),x.push(A.internalFormat),x.push(A.format),x.push(A.type),x.push(A.generateMipmaps),x.push(A.premultiplyAlpha),x.push(A.flipY),x.push(A.unpackAlignment),x.push(A.colorSpace),x.join()}function dt(A,x){let G=n.get(A);if(A.isVideoTexture&&U(A),A.isRenderTargetTexture===!1&&A.isExternalTexture!==!0&&A.version>0&&G.__version!==A.version){let Y=A.image;if(Y===null)ue("WebGLRenderer: Texture marked for update but no image data found.");else if(Y.complete===!1)ue("WebGLRenderer: Texture marked for update but image is incomplete");else{_t(G,A,x);return}}else A.isExternalTexture&&(G.__webglTexture=A.sourceTexture?A.sourceTexture:null);e.bindTexture(i.TEXTURE_2D,G.__webglTexture,i.TEXTURE0+x)}function Q(A,x){let G=n.get(A);if(A.isRenderTargetTexture===!1&&A.version>0&&G.__version!==A.version){_t(G,A,x);return}else A.isExternalTexture&&(G.__webglTexture=A.sourceTexture?A.sourceTexture:null);e.bindTexture(i.TEXTURE_2D_ARRAY,G.__webglTexture,i.TEXTURE0+x)}function ct(A,x){let G=n.get(A);if(A.isRenderTargetTexture===!1&&A.version>0&&G.__version!==A.version){_t(G,A,x);return}e.bindTexture(i.TEXTURE_3D,G.__webglTexture,i.TEXTURE0+x)}function O(A,x){let G=n.get(A);if(A.isCubeDepthTexture!==!0&&A.version>0&&G.__version!==A.version){bt(G,A,x);return}e.bindTexture(i.TEXTURE_CUBE_MAP,G.__webglTexture,i.TEXTURE0+x)}let St={[ns]:i.REPEAT,[xi]:i.CLAMP_TO_EDGE,[ol]:i.MIRRORED_REPEAT},Et={[mn]:i.NEAREST,[gd]:i.NEAREST_MIPMAP_NEAREST,[Ka]:i.NEAREST_MIPMAP_LINEAR,[Mn]:i.LINEAR,[Ol]:i.LINEAR_MIPMAP_NEAREST,[Si]:i.LINEAR_MIPMAP_LINEAR},At={[yd]:i.NEVER,[wd]:i.ALWAYS,[Md]:i.LESS,[bc]:i.LEQUAL,[bd]:i.EQUAL,[Sc]:i.GEQUAL,[Sd]:i.GREATER,[Ed]:i.NOTEQUAL};function Ot(A,x){if(x.type===Yn&&t.has("OES_texture_float_linear")===!1&&(x.magFilter===Mn||x.magFilter===Ol||x.magFilter===Ka||x.magFilter===Si||x.minFilter===Mn||x.minFilter===Ol||x.minFilter===Ka||x.minFilter===Si)&&ue("WebGLRenderer: Unable to use linear filtering with floating point textures. OES_texture_float_linear not supported on this device."),i.texParameteri(A,i.TEXTURE_WRAP_S,St[x.wrapS]),i.texParameteri(A,i.TEXTURE_WRAP_T,St[x.wrapT]),(A===i.TEXTURE_3D||A===i.TEXTURE_2D_ARRAY)&&i.texParameteri(A,i.TEXTURE_WRAP_R,St[x.wrapR]),i.texParameteri(A,i.TEXTURE_MAG_FILTER,Et[x.magFilter]),i.texParameteri(A,i.TEXTURE_MIN_FILTER,Et[x.minFilter]),x.compareFunction&&(i.texParameteri(A,i.TEXTURE_COMPARE_MODE,i.COMPARE_REF_TO_TEXTURE),i.texParameteri(A,i.TEXTURE_COMPARE_FUNC,At[x.compareFunction])),t.has("EXT_texture_filter_anisotropic")===!0){if(x.magFilter===mn||x.minFilter!==Ka&&x.minFilter!==Si||x.type===Yn&&t.has("OES_texture_float_linear")===!1)return;if(x.anisotropy>1||n.get(x).__currentAnisotropy){let G=t.get("EXT_texture_filter_anisotropic");i.texParameterf(A,G.TEXTURE_MAX_ANISOTROPY_EXT,Math.min(x.anisotropy,s.getMaxAnisotropy())),n.get(x).__currentAnisotropy=x.anisotropy}}}function Dt(A,x){let G=!1;A.__webglInit===void 0&&(A.__webglInit=!0,x.addEventListener("dispose",I));let Y=x.source,at=d.get(Y);at===void 0&&(at={},d.set(Y,at));let Mt=nt(x);if(Mt!==A.__cacheKey){at[Mt]===void 0&&(at[Mt]={texture:i.createTexture(),usedTimes:0},a.memory.textures++,G=!0),at[Mt].usedTimes++;let Rt=at[A.__cacheKey];Rt!==void 0&&(at[A.__cacheKey].usedTimes--,Rt.usedTimes===0&&L(x)),A.__cacheKey=Mt,A.__webglTexture=at[Mt].texture}return G}function tt(A,x,G){return Math.floor(Math.floor(A/G)/x)}function it(A,x,G,Y){let Mt=A.updateRanges;if(Mt.length===0)e.texSubImage2D(i.TEXTURE_2D,0,0,0,x.width,x.height,G,Y,x.data);else{Mt.sort((Ht,Nt)=>Ht.start-Nt.start);let Rt=0;for(let Ht=1;Ht<Mt.length;Ht++){let Nt=Mt[Rt],Tt=Mt[Ht],Xt=Nt.start+Nt.count,Jt=tt(Tt.start,x.width,4),le=tt(Nt.start,x.width,4);Tt.start<=Xt+1&&Jt===le&&tt(Tt.start+Tt.count-1,x.width,4)===Jt?Nt.count=Math.max(Nt.count,Tt.start+Tt.count-Nt.start):(++Rt,Mt[Rt]=Tt)}Mt.length=Rt+1;let st=e.getParameter(i.UNPACK_ROW_LENGTH),ft=e.getParameter(i.UNPACK_SKIP_PIXELS),Pt=e.getParameter(i.UNPACK_SKIP_ROWS);e.pixelStorei(i.UNPACK_ROW_LENGTH,x.width);for(let Ht=0,Nt=Mt.length;Ht<Nt;Ht++){let Tt=Mt[Ht],Xt=Math.floor(Tt.start/4),Jt=Math.ceil(Tt.count/4),le=Xt%x.width,z=Math.floor(Xt/x.width),Ft=Jt,T=1;e.pixelStorei(i.UNPACK_SKIP_PIXELS,le),e.pixelStorei(i.UNPACK_SKIP_ROWS,z),e.texSubImage2D(i.TEXTURE_2D,0,le,z,Ft,T,G,Y,x.data)}A.clearUpdateRanges(),e.pixelStorei(i.UNPACK_ROW_LENGTH,st),e.pixelStorei(i.UNPACK_SKIP_PIXELS,ft),e.pixelStorei(i.UNPACK_SKIP_ROWS,Pt)}}function _t(A,x,G){let Y=i.TEXTURE_2D;(x.isDataArrayTexture||x.isCompressedArrayTexture)&&(Y=i.TEXTURE_2D_ARRAY),x.isData3DTexture&&(Y=i.TEXTURE_3D);let at=Dt(A,x),Mt=x.source;e.bindTexture(Y,A.__webglTexture,i.TEXTURE0+G);let Rt=n.get(Mt);if(Mt.version!==Rt.__version||at===!0){if(e.activeTexture(i.TEXTURE0+G),(typeof ImageBitmap<"u"&&x.image instanceof ImageBitmap)===!1){let T=Se.getPrimaries(Se.workingColorSpace),q=x.colorSpace===ui?null:Se.getPrimaries(x.colorSpace),ht=x.colorSpace===ui||T===q?i.NONE:i.BROWSER_DEFAULT_WEBGL;e.pixelStorei(i.UNPACK_FLIP_Y_WEBGL,x.flipY),e.pixelStorei(i.UNPACK_PREMULTIPLY_ALPHA_WEBGL,x.premultiplyAlpha),e.pixelStorei(i.UNPACK_COLORSPACE_CONVERSION_WEBGL,ht)}e.pixelStorei(i.UNPACK_ALIGNMENT,x.unpackAlignment);let ft=m(x.image,!1,s.maxTextureSize);ft=ne(x,ft);let Pt=r.convert(x.format,x.colorSpace),Ht=r.convert(x.type),Nt=y(x.internalFormat,Pt,Ht,x.normalized,x.colorSpace,x.isVideoTexture);Ot(Y,x);let Tt,Xt=x.mipmaps,Jt=x.isVideoTexture!==!0,le=Rt.__version===void 0||at===!0,z=Mt.dataReady,Ft=M(x,ft);if(x.isDepthTexture)Nt=E(x.format===fs,x.type),le&&(Jt?e.texStorage2D(i.TEXTURE_2D,1,Nt,ft.width,ft.height):e.texImage2D(i.TEXTURE_2D,0,Nt,ft.width,ft.height,0,Pt,Ht,null));else if(x.isDataTexture)if(Xt.length>0){Jt&&le&&e.texStorage2D(i.TEXTURE_2D,Ft,Nt,Xt[0].width,Xt[0].height);for(let T=0,q=Xt.length;T<q;T++)Tt=Xt[T],Jt?z&&e.texSubImage2D(i.TEXTURE_2D,T,0,0,Tt.width,Tt.height,Pt,Ht,Tt.data):e.texImage2D(i.TEXTURE_2D,T,Nt,Tt.width,Tt.height,0,Pt,Ht,Tt.data);x.generateMipmaps=!1}else Jt?(le&&e.texStorage2D(i.TEXTURE_2D,Ft,Nt,ft.width,ft.height),z&&it(x,ft,Pt,Ht)):e.texImage2D(i.TEXTURE_2D,0,Nt,ft.width,ft.height,0,Pt,Ht,ft.data);else if(x.isCompressedTexture)if(x.isCompressedArrayTexture){Jt&&le&&e.texStorage3D(i.TEXTURE_2D_ARRAY,Ft,Nt,Xt[0].width,Xt[0].height,ft.depth);for(let T=0,q=Xt.length;T<q;T++)if(Tt=Xt[T],x.format!==Zn)if(Pt!==null)if(Jt){if(z)if(x.layerUpdates.size>0){let ht=uh(Tt.width,Tt.height,x.format,x.type);for(let X of x.layerUpdates){let zt=Tt.data.subarray(X*ht/Tt.data.BYTES_PER_ELEMENT,(X+1)*ht/Tt.data.BYTES_PER_ELEMENT);e.compressedTexSubImage3D(i.TEXTURE_2D_ARRAY,T,0,0,X,Tt.width,Tt.height,1,Pt,zt)}}else e.compressedTexSubImage3D(i.TEXTURE_2D_ARRAY,T,0,0,0,Tt.width,Tt.height,ft.depth,Pt,Tt.data)}else e.compressedTexImage3D(i.TEXTURE_2D_ARRAY,T,Nt,Tt.width,Tt.height,ft.depth,0,Tt.data,0,0);else ue("WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()");else Jt?z&&e.texSubImage3D(i.TEXTURE_2D_ARRAY,T,0,0,0,Tt.width,Tt.height,ft.depth,Pt,Ht,Tt.data):e.texImage3D(i.TEXTURE_2D_ARRAY,T,Nt,Tt.width,Tt.height,ft.depth,0,Pt,Ht,Tt.data);x.layerUpdates.size>0&&x.clearLayerUpdates()}else{Jt&&le&&e.texStorage2D(i.TEXTURE_2D,Ft,Nt,Xt[0].width,Xt[0].height);for(let T=0,q=Xt.length;T<q;T++)Tt=Xt[T],x.format!==Zn?Pt!==null?Jt?z&&e.compressedTexSubImage2D(i.TEXTURE_2D,T,0,0,Tt.width,Tt.height,Pt,Tt.data):e.compressedTexImage2D(i.TEXTURE_2D,T,Nt,Tt.width,Tt.height,0,Tt.data):ue("WebGLRenderer: Attempt to load unsupported compressed texture format in .uploadTexture()"):Jt?z&&e.texSubImage2D(i.TEXTURE_2D,T,0,0,Tt.width,Tt.height,Pt,Ht,Tt.data):e.texImage2D(i.TEXTURE_2D,T,Nt,Tt.width,Tt.height,0,Pt,Ht,Tt.data)}else if(x.isDataArrayTexture)if(Jt){if(le&&e.texStorage3D(i.TEXTURE_2D_ARRAY,Ft,Nt,ft.width,ft.height,ft.depth),z)if(x.layerUpdates.size>0){let T=uh(ft.width,ft.height,x.format,x.type);for(let q of x.layerUpdates){let ht=ft.data.subarray(q*T/ft.data.BYTES_PER_ELEMENT,(q+1)*T/ft.data.BYTES_PER_ELEMENT);e.texSubImage3D(i.TEXTURE_2D_ARRAY,0,0,0,q,ft.width,ft.height,1,Pt,Ht,ht)}x.clearLayerUpdates()}else e.texSubImage3D(i.TEXTURE_2D_ARRAY,0,0,0,0,ft.width,ft.height,ft.depth,Pt,Ht,ft.data)}else e.texImage3D(i.TEXTURE_2D_ARRAY,0,Nt,ft.width,ft.height,ft.depth,0,Pt,Ht,ft.data);else if(x.isData3DTexture)Jt?(le&&e.texStorage3D(i.TEXTURE_3D,Ft,Nt,ft.width,ft.height,ft.depth),z&&e.texSubImage3D(i.TEXTURE_3D,0,0,0,0,ft.width,ft.height,ft.depth,Pt,Ht,ft.data)):e.texImage3D(i.TEXTURE_3D,0,Nt,ft.width,ft.height,ft.depth,0,Pt,Ht,ft.data);else if(x.isFramebufferTexture){if(le)if(Jt)e.texStorage2D(i.TEXTURE_2D,Ft,Nt,ft.width,ft.height);else{let T=ft.width,q=ft.height;for(let ht=0;ht<Ft;ht++)e.texImage2D(i.TEXTURE_2D,ht,Nt,T,q,0,Pt,Ht,null),T>>=1,q>>=1}}else if(x.isHTMLTexture){if("texElementImage2D"in i){let T=i.canvas;if(T.hasAttribute("layoutsubtree")||T.setAttribute("layoutsubtree","true"),ft.parentNode!==T){T.appendChild(ft),f.add(x),T.onpaint=q=>{let ht=q.changedElements;for(let X of f)ht.includes(X.image)&&(X.needsUpdate=!0)},T.requestPaint();return}if(i.texElementImage2D.length===3)i.texElementImage2D(i.TEXTURE_2D,i.RGBA8,ft);else{let ht=i.RGBA,X=i.RGBA,zt=i.UNSIGNED_BYTE;i.texElementImage2D(i.TEXTURE_2D,0,ht,X,zt,ft)}i.texParameteri(i.TEXTURE_2D,i.TEXTURE_MIN_FILTER,i.LINEAR),i.texParameteri(i.TEXTURE_2D,i.TEXTURE_WRAP_S,i.CLAMP_TO_EDGE),i.texParameteri(i.TEXTURE_2D,i.TEXTURE_WRAP_T,i.CLAMP_TO_EDGE)}}else if(Xt.length>0){if(Jt&&le){let T=re(Xt[0]);e.texStorage2D(i.TEXTURE_2D,Ft,Nt,T.width,T.height)}for(let T=0,q=Xt.length;T<q;T++)Tt=Xt[T],Jt?z&&e.texSubImage2D(i.TEXTURE_2D,T,0,0,Pt,Ht,Tt):e.texImage2D(i.TEXTURE_2D,T,Nt,Pt,Ht,Tt);x.generateMipmaps=!1}else if(Jt){if(le){let T=re(ft);e.texStorage2D(i.TEXTURE_2D,Ft,Nt,T.width,T.height)}z&&e.texSubImage2D(i.TEXTURE_2D,0,0,0,Pt,Ht,ft)}else e.texImage2D(i.TEXTURE_2D,0,Nt,Pt,Ht,ft);p(x)&&S(Y),Rt.__version=Mt.version,x.onUpdate&&x.onUpdate(x)}A.__version=x.version}function bt(A,x,G){if(x.image.length!==6)return;let Y=Dt(A,x),at=x.source;e.bindTexture(i.TEXTURE_CUBE_MAP,A.__webglTexture,i.TEXTURE0+G);let Mt=n.get(at);if(at.version!==Mt.__version||Y===!0){e.activeTexture(i.TEXTURE0+G);let Rt=Se.getPrimaries(Se.workingColorSpace),st=x.colorSpace===ui?null:Se.getPrimaries(x.colorSpace),ft=x.colorSpace===ui||Rt===st?i.NONE:i.BROWSER_DEFAULT_WEBGL;e.pixelStorei(i.UNPACK_FLIP_Y_WEBGL,x.flipY),e.pixelStorei(i.UNPACK_PREMULTIPLY_ALPHA_WEBGL,x.premultiplyAlpha),e.pixelStorei(i.UNPACK_ALIGNMENT,x.unpackAlignment),e.pixelStorei(i.UNPACK_COLORSPACE_CONVERSION_WEBGL,ft);let Pt=x.isCompressedTexture||x.image[0].isCompressedTexture,Ht=x.image[0]&&x.image[0].isDataTexture,Nt=[];for(let X=0;X<6;X++)!Pt&&!Ht?Nt[X]=m(x.image[X],!0,s.maxCubemapSize):Nt[X]=Ht?x.image[X].image:x.image[X],Nt[X]=ne(x,Nt[X]);let Tt=Nt[0],Xt=r.convert(x.format,x.colorSpace),Jt=r.convert(x.type),le=y(x.internalFormat,Xt,Jt,x.normalized,x.colorSpace),z=x.isVideoTexture!==!0,Ft=Mt.__version===void 0||Y===!0,T=at.dataReady,q=M(x,Tt);Ot(i.TEXTURE_CUBE_MAP,x);let ht;if(Pt){z&&Ft&&e.texStorage2D(i.TEXTURE_CUBE_MAP,q,le,Tt.width,Tt.height);for(let X=0;X<6;X++){ht=Nt[X].mipmaps;for(let zt=0;zt<ht.length;zt++){let wt=ht[zt];x.format!==Zn?Xt!==null?z?T&&e.compressedTexSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+X,zt,0,0,wt.width,wt.height,Xt,wt.data):e.compressedTexImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+X,zt,le,wt.width,wt.height,0,wt.data):ue("WebGLRenderer: Attempt to load unsupported compressed texture format in .setTextureCube()"):z?T&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+X,zt,0,0,wt.width,wt.height,Xt,Jt,wt.data):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+X,zt,le,wt.width,wt.height,0,Xt,Jt,wt.data)}}}else{if(ht=x.mipmaps,z&&Ft){ht.length>0&&q++;let X=re(Nt[0]);e.texStorage2D(i.TEXTURE_CUBE_MAP,q,le,X.width,X.height)}for(let X=0;X<6;X++)if(Ht){z?T&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+X,0,0,0,Nt[X].width,Nt[X].height,Xt,Jt,Nt[X].data):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+X,0,le,Nt[X].width,Nt[X].height,0,Xt,Jt,Nt[X].data);for(let zt=0;zt<ht.length;zt++){let xe=ht[zt].image[X].image;z?T&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+X,zt+1,0,0,xe.width,xe.height,Xt,Jt,xe.data):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+X,zt+1,le,xe.width,xe.height,0,Xt,Jt,xe.data)}}else{z?T&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+X,0,0,0,Xt,Jt,Nt[X]):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+X,0,le,Xt,Jt,Nt[X]);for(let zt=0;zt<ht.length;zt++){let wt=ht[zt];z?T&&e.texSubImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+X,zt+1,0,0,Xt,Jt,wt.image[X]):e.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+X,zt+1,le,Xt,Jt,wt.image[X])}}}p(x)&&S(i.TEXTURE_CUBE_MAP),Mt.__version=at.version,x.onUpdate&&x.onUpdate(x)}A.__version=x.version}function mt(A,x,G,Y,at,Mt){let Rt=r.convert(G.format,G.colorSpace),st=r.convert(G.type),ft=y(G.internalFormat,Rt,st,G.normalized,G.colorSpace),Pt=n.get(x),Ht=n.get(G);if(Ht.__renderTarget=x,!Pt.__hasExternalTextures){let Nt=Math.max(1,x.width>>Mt),Tt=Math.max(1,x.height>>Mt);at===i.TEXTURE_3D||at===i.TEXTURE_2D_ARRAY?e.texImage3D(at,Mt,ft,Nt,Tt,x.depth,0,Rt,st,null):e.texImage2D(at,Mt,ft,Nt,Tt,0,Rt,st,null)}e.bindFramebuffer(i.FRAMEBUFFER,A),ee(x)?o.framebufferTexture2DMultisampleEXT(i.FRAMEBUFFER,Y,at,Ht.__webglTexture,0,Zt(x)):(at===i.TEXTURE_2D||at>=i.TEXTURE_CUBE_MAP_POSITIVE_X&&at<=i.TEXTURE_CUBE_MAP_NEGATIVE_Z)&&i.framebufferTexture2D(i.FRAMEBUFFER,Y,at,Ht.__webglTexture,Mt),e.bindFramebuffer(i.FRAMEBUFFER,null)}function Ct(A,x,G){if(i.bindRenderbuffer(i.RENDERBUFFER,A),x.depthBuffer){let Y=x.depthTexture,at=Y&&Y.isDepthTexture?Y.type:null,Mt=E(x.stencilBuffer,at),Rt=x.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT;ee(x)?o.renderbufferStorageMultisampleEXT(i.RENDERBUFFER,Zt(x),Mt,x.width,x.height):G?i.renderbufferStorageMultisample(i.RENDERBUFFER,Zt(x),Mt,x.width,x.height):i.renderbufferStorage(i.RENDERBUFFER,Mt,x.width,x.height),i.framebufferRenderbuffer(i.FRAMEBUFFER,Rt,i.RENDERBUFFER,A)}else{let Y=x.textures;for(let at=0;at<Y.length;at++){let Mt=Y[at],Rt=r.convert(Mt.format,Mt.colorSpace),st=r.convert(Mt.type),ft=y(Mt.internalFormat,Rt,st,Mt.normalized,Mt.colorSpace);ee(x)?o.renderbufferStorageMultisampleEXT(i.RENDERBUFFER,Zt(x),ft,x.width,x.height):G?i.renderbufferStorageMultisample(i.RENDERBUFFER,Zt(x),ft,x.width,x.height):i.renderbufferStorage(i.RENDERBUFFER,ft,x.width,x.height)}}i.bindRenderbuffer(i.RENDERBUFFER,null)}function Qt(A,x,G){let Y=x.isWebGLCubeRenderTarget===!0;if(e.bindFramebuffer(i.FRAMEBUFFER,A),!(x.depthTexture&&x.depthTexture.isDepthTexture))throw new Error("THREE.WebGLTextures: renderTarget.depthTexture must be an instance of THREE.DepthTexture.");let at=n.get(x.depthTexture);if(at.__renderTarget=x,(!at.__webglTexture||x.depthTexture.image.width!==x.width||x.depthTexture.image.height!==x.height)&&(x.depthTexture.image.width=x.width,x.depthTexture.image.height=x.height,x.depthTexture.needsUpdate=!0),Y){if(at.__webglInit===void 0&&(at.__webglInit=!0,x.depthTexture.addEventListener("dispose",I)),at.__webglTexture===void 0){at.__webglTexture=i.createTexture(),e.bindTexture(i.TEXTURE_CUBE_MAP,at.__webglTexture),Ot(i.TEXTURE_CUBE_MAP,x.depthTexture);let Pt=r.convert(x.depthTexture.format),Ht=r.convert(x.depthTexture.type),Nt;x.depthTexture.format===vi?Nt=i.DEPTH_COMPONENT24:x.depthTexture.format===fs&&(Nt=i.DEPTH24_STENCIL8);for(let Tt=0;Tt<6;Tt++)i.texImage2D(i.TEXTURE_CUBE_MAP_POSITIVE_X+Tt,0,Nt,x.width,x.height,0,Pt,Ht,null)}}else dt(x.depthTexture,0);let Mt=at.__webglTexture,Rt=Zt(x),st=Y?i.TEXTURE_CUBE_MAP_POSITIVE_X+G:i.TEXTURE_2D,ft=x.depthTexture.format===fs?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT;if(x.depthTexture.format===vi)ee(x)?o.framebufferTexture2DMultisampleEXT(i.FRAMEBUFFER,ft,st,Mt,0,Rt):i.framebufferTexture2D(i.FRAMEBUFFER,ft,st,Mt,0);else if(x.depthTexture.format===fs)ee(x)?o.framebufferTexture2DMultisampleEXT(i.FRAMEBUFFER,ft,st,Mt,0,Rt):i.framebufferTexture2D(i.FRAMEBUFFER,ft,st,Mt,0);else throw new Error("THREE.WebGLTextures: Unknown depthTexture format.")}function V(A){let x=n.get(A),G=A.isWebGLCubeRenderTarget===!0;if(x.__boundDepthTexture!==A.depthTexture){let Y=A.depthTexture;if(x.__depthDisposeCallback&&x.__depthDisposeCallback(),Y){let at=()=>{delete x.__boundDepthTexture,delete x.__depthDisposeCallback,Y.removeEventListener("dispose",at)};Y.addEventListener("dispose",at),x.__depthDisposeCallback=at}x.__boundDepthTexture=Y}if(A.depthTexture&&!x.__autoAllocateDepthBuffer)if(G)for(let Y=0;Y<6;Y++)Qt(x.__webglFramebuffer[Y],A,Y);else{let Y=A.texture.mipmaps;Y&&Y.length>0?Qt(x.__webglFramebuffer[0],A,0):Qt(x.__webglFramebuffer,A,0)}else if(G){x.__webglDepthbuffer=[];for(let Y=0;Y<6;Y++)if(e.bindFramebuffer(i.FRAMEBUFFER,x.__webglFramebuffer[Y]),x.__webglDepthbuffer[Y]===void 0)x.__webglDepthbuffer[Y]=i.createRenderbuffer(),Ct(x.__webglDepthbuffer[Y],A,!1);else{let at=A.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT,Mt=x.__webglDepthbuffer[Y];i.bindRenderbuffer(i.RENDERBUFFER,Mt),i.framebufferRenderbuffer(i.FRAMEBUFFER,at,i.RENDERBUFFER,Mt)}}else{let Y=A.texture.mipmaps;if(Y&&Y.length>0?e.bindFramebuffer(i.FRAMEBUFFER,x.__webglFramebuffer[0]):e.bindFramebuffer(i.FRAMEBUFFER,x.__webglFramebuffer),x.__webglDepthbuffer===void 0)x.__webglDepthbuffer=i.createRenderbuffer(),Ct(x.__webglDepthbuffer,A,!1);else{let at=A.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT,Mt=x.__webglDepthbuffer;i.bindRenderbuffer(i.RENDERBUFFER,Mt),i.framebufferRenderbuffer(i.FRAMEBUFFER,at,i.RENDERBUFFER,Mt)}}e.bindFramebuffer(i.FRAMEBUFFER,null)}function ut(A,x,G){let Y=n.get(A);x!==void 0&&mt(Y.__webglFramebuffer,A,A.texture,i.COLOR_ATTACHMENT0,i.TEXTURE_2D,0),G!==void 0&&V(A)}function xt(A){let x=A.texture,G=n.get(A),Y=n.get(x);A.addEventListener("dispose",v);let at=A.textures,Mt=A.isWebGLCubeRenderTarget===!0,Rt=at.length>1;if(Rt||(Y.__webglTexture===void 0&&(Y.__webglTexture=i.createTexture()),Y.__version=x.version,a.memory.textures++),Mt){G.__webglFramebuffer=[];for(let st=0;st<6;st++)if(x.mipmaps&&x.mipmaps.length>0){G.__webglFramebuffer[st]=[];for(let ft=0;ft<x.mipmaps.length;ft++)G.__webglFramebuffer[st][ft]=i.createFramebuffer()}else G.__webglFramebuffer[st]=i.createFramebuffer()}else{if(x.mipmaps&&x.mipmaps.length>0){G.__webglFramebuffer=[];for(let st=0;st<x.mipmaps.length;st++)G.__webglFramebuffer[st]=i.createFramebuffer()}else G.__webglFramebuffer=i.createFramebuffer();if(Rt)for(let st=0,ft=at.length;st<ft;st++){let Pt=n.get(at[st]);Pt.__webglTexture===void 0&&(Pt.__webglTexture=i.createTexture(),a.memory.textures++)}if(A.samples>0&&ee(A)===!1){G.__webglMultisampledFramebuffer=i.createFramebuffer(),G.__webglColorRenderbuffer=[],e.bindFramebuffer(i.FRAMEBUFFER,G.__webglMultisampledFramebuffer);for(let st=0;st<at.length;st++){let ft=at[st];G.__webglColorRenderbuffer[st]=i.createRenderbuffer(),i.bindRenderbuffer(i.RENDERBUFFER,G.__webglColorRenderbuffer[st]);let Pt=r.convert(ft.format,ft.colorSpace),Ht=r.convert(ft.type),Nt=y(ft.internalFormat,Pt,Ht,ft.normalized,ft.colorSpace,A.isXRRenderTarget===!0),Tt=Zt(A);i.renderbufferStorageMultisample(i.RENDERBUFFER,Tt,Nt,A.width,A.height),i.framebufferRenderbuffer(i.FRAMEBUFFER,i.COLOR_ATTACHMENT0+st,i.RENDERBUFFER,G.__webglColorRenderbuffer[st])}i.bindRenderbuffer(i.RENDERBUFFER,null),A.depthBuffer&&(G.__webglDepthRenderbuffer=i.createRenderbuffer(),Ct(G.__webglDepthRenderbuffer,A,!0)),e.bindFramebuffer(i.FRAMEBUFFER,null)}}if(Mt){e.bindTexture(i.TEXTURE_CUBE_MAP,Y.__webglTexture),Ot(i.TEXTURE_CUBE_MAP,x);for(let st=0;st<6;st++)if(x.mipmaps&&x.mipmaps.length>0)for(let ft=0;ft<x.mipmaps.length;ft++)mt(G.__webglFramebuffer[st][ft],A,x,i.COLOR_ATTACHMENT0,i.TEXTURE_CUBE_MAP_POSITIVE_X+st,ft);else mt(G.__webglFramebuffer[st],A,x,i.COLOR_ATTACHMENT0,i.TEXTURE_CUBE_MAP_POSITIVE_X+st,0);p(x)&&S(i.TEXTURE_CUBE_MAP),e.unbindTexture()}else if(Rt){for(let st=0,ft=at.length;st<ft;st++){let Pt=at[st],Ht=n.get(Pt),Nt=i.TEXTURE_2D;(A.isWebGL3DRenderTarget||A.isWebGLArrayRenderTarget)&&(Nt=A.isWebGL3DRenderTarget?i.TEXTURE_3D:i.TEXTURE_2D_ARRAY),e.bindTexture(Nt,Ht.__webglTexture),Ot(Nt,Pt),mt(G.__webglFramebuffer,A,Pt,i.COLOR_ATTACHMENT0+st,Nt,0),p(Pt)&&S(Nt)}e.unbindTexture()}else{let st=i.TEXTURE_2D;if((A.isWebGL3DRenderTarget||A.isWebGLArrayRenderTarget)&&(st=A.isWebGL3DRenderTarget?i.TEXTURE_3D:i.TEXTURE_2D_ARRAY),e.bindTexture(st,Y.__webglTexture),Ot(st,x),x.mipmaps&&x.mipmaps.length>0)for(let ft=0;ft<x.mipmaps.length;ft++)mt(G.__webglFramebuffer[ft],A,x,i.COLOR_ATTACHMENT0,st,ft);else mt(G.__webglFramebuffer,A,x,i.COLOR_ATTACHMENT0,st,0);p(x)&&S(st),e.unbindTexture()}A.depthBuffer&&V(A)}function gt(A){let x=A.textures;for(let G=0,Y=x.length;G<Y;G++){let at=x[G];if(p(at)){let Mt=w(A),Rt=n.get(at).__webglTexture;e.bindTexture(Mt,Rt),S(Mt),e.unbindTexture()}}}let yt=[],Bt=[];function Ut(A){if(A.samples>0){if(ee(A)===!1){let x=A.textures,G=A.width,Y=A.height,at=i.COLOR_BUFFER_BIT,Mt=A.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT,Rt=n.get(A),st=x.length>1;if(st)for(let Pt=0;Pt<x.length;Pt++)e.bindFramebuffer(i.FRAMEBUFFER,Rt.__webglMultisampledFramebuffer),i.framebufferRenderbuffer(i.FRAMEBUFFER,i.COLOR_ATTACHMENT0+Pt,i.RENDERBUFFER,null),e.bindFramebuffer(i.FRAMEBUFFER,Rt.__webglFramebuffer),i.framebufferTexture2D(i.DRAW_FRAMEBUFFER,i.COLOR_ATTACHMENT0+Pt,i.TEXTURE_2D,null,0);e.bindFramebuffer(i.READ_FRAMEBUFFER,Rt.__webglMultisampledFramebuffer);let ft=A.texture.mipmaps;ft&&ft.length>0?e.bindFramebuffer(i.DRAW_FRAMEBUFFER,Rt.__webglFramebuffer[0]):e.bindFramebuffer(i.DRAW_FRAMEBUFFER,Rt.__webglFramebuffer);for(let Pt=0;Pt<x.length;Pt++){if(A.resolveDepthBuffer&&(A.depthBuffer&&(at|=i.DEPTH_BUFFER_BIT),A.stencilBuffer&&A.resolveStencilBuffer&&(at|=i.STENCIL_BUFFER_BIT)),st){i.framebufferRenderbuffer(i.READ_FRAMEBUFFER,i.COLOR_ATTACHMENT0,i.RENDERBUFFER,Rt.__webglColorRenderbuffer[Pt]);let Ht=n.get(x[Pt]).__webglTexture;i.framebufferTexture2D(i.DRAW_FRAMEBUFFER,i.COLOR_ATTACHMENT0,i.TEXTURE_2D,Ht,0)}i.blitFramebuffer(0,0,G,Y,0,0,G,Y,at,i.NEAREST),c===!0&&(yt.length=0,Bt.length=0,yt.push(i.COLOR_ATTACHMENT0+Pt),A.depthBuffer&&A.storeMultisampledDepthBuffer===!1&&(yt.push(Mt),Bt.push(Mt),i.invalidateFramebuffer(i.DRAW_FRAMEBUFFER,Bt)),i.invalidateFramebuffer(i.READ_FRAMEBUFFER,yt))}if(e.bindFramebuffer(i.READ_FRAMEBUFFER,null),e.bindFramebuffer(i.DRAW_FRAMEBUFFER,null),st)for(let Pt=0;Pt<x.length;Pt++){e.bindFramebuffer(i.FRAMEBUFFER,Rt.__webglMultisampledFramebuffer),i.framebufferRenderbuffer(i.FRAMEBUFFER,i.COLOR_ATTACHMENT0+Pt,i.RENDERBUFFER,Rt.__webglColorRenderbuffer[Pt]);let Ht=n.get(x[Pt]).__webglTexture;e.bindFramebuffer(i.FRAMEBUFFER,Rt.__webglFramebuffer),i.framebufferTexture2D(i.DRAW_FRAMEBUFFER,i.COLOR_ATTACHMENT0+Pt,i.TEXTURE_2D,Ht,0)}e.bindFramebuffer(i.DRAW_FRAMEBUFFER,Rt.__webglMultisampledFramebuffer)}else if(A.depthBuffer&&A.storeMultisampledDepthBuffer===!1&&c){let x=A.stencilBuffer?i.DEPTH_STENCIL_ATTACHMENT:i.DEPTH_ATTACHMENT;i.invalidateFramebuffer(i.DRAW_FRAMEBUFFER,[x])}}}function Zt(A){return Math.min(s.maxSamples,A.samples)}function ee(A){let x=n.get(A);return A.samples>0&&t.has("WEBGL_multisampled_render_to_texture")===!0&&x.__useRenderToTexture!==!1}function U(A){let x=a.render.frame;h.get(A)!==x&&(h.set(A,x),A.update())}function ne(A,x){let G=A.colorSpace,Y=A.format,at=A.type;return A.isCompressedTexture===!0||A.isVideoTexture===!0||G!==ra&&G!==ui&&(Se.getTransfer(G)===Le?(Y!==Zn||at!==Nn)&&ue("WebGLTextures: sRGB encoded textures have to use RGBAFormat and UnsignedByteType."):he("WebGLTextures: Unsupported texture color space:",G)),x}function re(A){return typeof HTMLImageElement<"u"&&A instanceof HTMLImageElement?(l.width=A.naturalWidth||A.width,l.height=A.naturalHeight||A.height):typeof VideoFrame<"u"&&A instanceof VideoFrame?(l.width=A.displayWidth,l.height=A.displayHeight):(l.width=A.width,l.height=A.height),l}this.allocateTextureUnit=rt,this.resetTextureUnits=B,this.getTextureUnits=F,this.setTextureUnits=W,this.setTexture2D=dt,this.setTexture2DArray=Q,this.setTexture3D=ct,this.setTextureCube=O,this.rebindTextures=ut,this.setupRenderTarget=xt,this.updateRenderTargetMipmap=gt,this.updateMultisampleRenderTarget=Ut,this.setupDepthRenderbuffer=V,this.setupFrameBufferTexture=mt,this.useMultisampledRTT=ee,this.isReversedDepthBuffer=function(){return e.buffers.depth.getReversed()}}function e3(i,t){function e(n,s=ui){let r,a=Se.getTransfer(s);if(n===Nn)return i.UNSIGNED_BYTE;if(n===zl)return i.UNSIGNED_SHORT_4_4_4_4;if(n===kl)return i.UNSIGNED_SHORT_5_5_5_1;if(n===eh)return i.UNSIGNED_INT_5_9_9_9_REV;if(n===nh)return i.UNSIGNED_INT_10F_11F_11F_REV;if(n===Q0)return i.BYTE;if(n===th)return i.SHORT;if(n===Ar)return i.UNSIGNED_SHORT;if(n===Bl)return i.INT;if(n===hi)return i.UNSIGNED_INT;if(n===Yn)return i.FLOAT;if(n===ln)return i.HALF_FLOAT;if(n===ih)return i.ALPHA;if(n===sh)return i.RGB;if(n===Zn)return i.RGBA;if(n===vi)return i.DEPTH_COMPONENT;if(n===fs)return i.DEPTH_STENCIL;if(n===Hl)return i.RED;if(n===Vl)return i.RED_INTEGER;if(n===ps)return i.RG;if(n===Gl)return i.RG_INTEGER;if(n===Wl)return i.RGBA_INTEGER;if(n===ja||n===Qa||n===to||n===eo)if(a===Le)if(r=t.get("WEBGL_compressed_texture_s3tc_srgb"),r!==null){if(n===ja)return r.COMPRESSED_SRGB_S3TC_DXT1_EXT;if(n===Qa)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT;if(n===to)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT;if(n===eo)return r.COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT}else return null;else if(r=t.get("WEBGL_compressed_texture_s3tc"),r!==null){if(n===ja)return r.COMPRESSED_RGB_S3TC_DXT1_EXT;if(n===Qa)return r.COMPRESSED_RGBA_S3TC_DXT1_EXT;if(n===to)return r.COMPRESSED_RGBA_S3TC_DXT3_EXT;if(n===eo)return r.COMPRESSED_RGBA_S3TC_DXT5_EXT}else return null;if(n===Xl||n===$l||n===ql||n===Yl)if(r=t.get("WEBGL_compressed_texture_pvrtc"),r!==null){if(n===Xl)return r.COMPRESSED_RGB_PVRTC_4BPPV1_IMG;if(n===$l)return r.COMPRESSED_RGB_PVRTC_2BPPV1_IMG;if(n===ql)return r.COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;if(n===Yl)return r.COMPRESSED_RGBA_PVRTC_2BPPV1_IMG}else return null;if(n===Zl||n===Jl||n===Kl||n===jl||n===Ql||n===no||n===tc)if(r=t.get("WEBGL_compressed_texture_etc"),r!==null){if(n===Zl||n===Jl)return a===Le?r.COMPRESSED_SRGB8_ETC2:r.COMPRESSED_RGB8_ETC2;if(n===Kl)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ETC2_EAC:r.COMPRESSED_RGBA8_ETC2_EAC;if(n===jl)return r.COMPRESSED_R11_EAC;if(n===Ql)return r.COMPRESSED_SIGNED_R11_EAC;if(n===no)return r.COMPRESSED_RG11_EAC;if(n===tc)return r.COMPRESSED_SIGNED_RG11_EAC}else return null;if(n===ec||n===nc||n===ic||n===sc||n===rc||n===ac||n===oc||n===lc||n===cc||n===hc||n===uc||n===dc||n===fc||n===pc)if(r=t.get("WEBGL_compressed_texture_astc"),r!==null){if(n===ec)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR:r.COMPRESSED_RGBA_ASTC_4x4_KHR;if(n===nc)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR:r.COMPRESSED_RGBA_ASTC_5x4_KHR;if(n===ic)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR:r.COMPRESSED_RGBA_ASTC_5x5_KHR;if(n===sc)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR:r.COMPRESSED_RGBA_ASTC_6x5_KHR;if(n===rc)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR:r.COMPRESSED_RGBA_ASTC_6x6_KHR;if(n===ac)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR:r.COMPRESSED_RGBA_ASTC_8x5_KHR;if(n===oc)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR:r.COMPRESSED_RGBA_ASTC_8x6_KHR;if(n===lc)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR:r.COMPRESSED_RGBA_ASTC_8x8_KHR;if(n===cc)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR:r.COMPRESSED_RGBA_ASTC_10x5_KHR;if(n===hc)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR:r.COMPRESSED_RGBA_ASTC_10x6_KHR;if(n===uc)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR:r.COMPRESSED_RGBA_ASTC_10x8_KHR;if(n===dc)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR:r.COMPRESSED_RGBA_ASTC_10x10_KHR;if(n===fc)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR:r.COMPRESSED_RGBA_ASTC_12x10_KHR;if(n===pc)return a===Le?r.COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR:r.COMPRESSED_RGBA_ASTC_12x12_KHR}else return null;if(n===mc||n===gc||n===xc)if(r=t.get("EXT_texture_compression_bptc"),r!==null){if(n===mc)return a===Le?r.COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT:r.COMPRESSED_RGBA_BPTC_UNORM_EXT;if(n===gc)return r.COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT;if(n===xc)return r.COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT}else return null;if(n===_c||n===vc||n===io||n===yc)if(r=t.get("EXT_texture_compression_rgtc"),r!==null){if(n===_c)return r.COMPRESSED_RED_RGTC1_EXT;if(n===vc)return r.COMPRESSED_SIGNED_RED_RGTC1_EXT;if(n===io)return r.COMPRESSED_RED_GREEN_RGTC2_EXT;if(n===yc)return r.COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT}else return null;return n===Rr?i.UNSIGNED_INT_24_8:i[n]!==void 0?i[n]:null}return{convert:e}}var n3=`
void main() {

	gl_Position = vec4( position, 1.0 );

}`,i3=`
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

}`,wh=class{constructor(){this.texture=null,this.mesh=null,this.depthNear=0,this.depthFar=0}init(t,e){if(this.texture===null){let n=new _a(t.texture);(t.depthNear!==e.depthNear||t.depthFar!==e.depthFar)&&(this.depthNear=t.depthNear,this.depthFar=t.depthFar),this.texture=n}}getMesh(t){if(this.texture!==null&&this.mesh===null){let e=t.cameras[0].viewport,n=new Oe({vertexShader:n3,fragmentShader:i3,uniforms:{depthColor:{value:this.texture},depthWidth:{value:e.z},depthHeight:{value:e.w}}});this.mesh=new ve(new rs(20,20),n)}return this.mesh}reset(){this.texture=null,this.mesh=null}getDepthTexture(){return this.texture}},Th=class extends yi{constructor(t,e){super();let n=this,s=null,r=1,a=null,o="local-floor",c=1,l=null,h=null,f=null,u=null,d=null,g=null,_=typeof XRWebGLBinding<"u",m=new wh,p={},S=e.getContextAttributes(),w=null,y=null,E=[],M=[],I=new vt,v=null,C=null,L=new yn;L.viewport=new $e;let N=new yn;N.viewport=new $e;let P=[L,N],B=new Ul,F=null,W=null;this.cameraAutoUpdate=!0,this.enabled=!1,this.isPresenting=!1,this.getController=function(tt){let it=E[tt];return it===void 0&&(it=new ur,E[tt]=it),it.getTargetRaySpace()},this.getControllerGrip=function(tt){let it=E[tt];return it===void 0&&(it=new ur,E[tt]=it),it.getGripSpace()},this.getHand=function(tt){let it=E[tt];return it===void 0&&(it=new ur,E[tt]=it),it.getHandSpace()};function rt(tt){let it=M.indexOf(tt.inputSource);if(it===-1)return;let _t=E[it];_t!==void 0&&(_t.update(tt.inputSource,tt.frame,l||a),_t.dispatchEvent({type:tt.type,data:tt.inputSource}))}function nt(){s.removeEventListener("select",rt),s.removeEventListener("selectstart",rt),s.removeEventListener("selectend",rt),s.removeEventListener("squeeze",rt),s.removeEventListener("squeezestart",rt),s.removeEventListener("squeezeend",rt),s.removeEventListener("end",nt),s.removeEventListener("inputsourceschange",dt);for(let tt=0;tt<E.length;tt++){let it=M[tt];it!==null&&(M[tt]=null,E[tt].disconnect(it))}F=null,W=null,m.reset();for(let tt in p)delete p[tt];if(t.setRenderTarget(w),d=null,u=null,f=null,s=null,y=null,Dt.stop(),n.isPresenting=!1,t.setPixelRatio(v),t.setSize(I.width,I.height,!1),C!==null){let tt=C.camera;tt.fov=C.fov,tt.zoom=C.zoom,tt.updateProjectionMatrix(),C=null}n.dispatchEvent({type:"sessionend"})}this.setFramebufferScaleFactor=function(tt){r=tt,n.isPresenting===!0&&ue("WebXRManager: Cannot change framebuffer scale while presenting.")},this.setReferenceSpaceType=function(tt){o=tt,n.isPresenting===!0&&ue("WebXRManager: Cannot change reference space type while presenting.")},this.getReferenceSpace=function(){return l||a},this.setReferenceSpace=function(tt){l=tt},this.getBaseLayer=function(){return u!==null?u:d},this.getBinding=function(){return f===null&&_&&(f=new XRWebGLBinding(s,e)),f},this.getFrame=function(){return g},this.getSession=function(){return s},this.setSession=async function(tt){if(s=tt,s!==null){if(w=t.getRenderTarget(),s.addEventListener("select",rt),s.addEventListener("selectstart",rt),s.addEventListener("selectend",rt),s.addEventListener("squeeze",rt),s.addEventListener("squeezestart",rt),s.addEventListener("squeezeend",rt),s.addEventListener("end",nt),s.addEventListener("inputsourceschange",dt),S.xrCompatible!==!0&&await e.makeXRCompatible(),v=t.getPixelRatio(),t.getSize(I),_&&"createProjectionLayer"in XRWebGLBinding.prototype){let _t=null,bt=null,mt=null;S.depth&&(mt=S.stencil?e.DEPTH24_STENCIL8:e.DEPTH_COMPONENT24,_t=S.stencil?fs:vi,bt=S.stencil?Rr:hi);let Ct={colorFormat:e.RGBA8,depthFormat:mt,scaleFactor:r};f=this.getBinding(),u=f.createProjectionLayer(Ct),s.updateRenderState({layers:[u]}),t.setPixelRatio(1),t.setSize(u.textureWidth,u.textureHeight,!1),y=new Ke(u.textureWidth,u.textureHeight,{format:Zn,type:Nn,depthTexture:new ss(u.textureWidth,u.textureHeight,bt,void 0,void 0,void 0,void 0,void 0,void 0,_t),stencilBuffer:S.stencil,colorSpace:t.outputColorSpace,samples:S.antialias?4:0,resolveDepthBuffer:u.ignoreDepthValues===!1,resolveStencilBuffer:u.ignoreDepthValues===!1,storeMultisampledDepthBuffer:u.ignoreDepthValues===!1,storeMultisampledStencilBuffer:u.ignoreDepthValues===!1})}else{let _t={antialias:S.antialias,alpha:!0,depth:S.depth,stencil:S.stencil,framebufferScaleFactor:r};d=new XRWebGLLayer(s,e,_t),s.updateRenderState({baseLayer:d}),t.setPixelRatio(1),t.setSize(d.framebufferWidth,d.framebufferHeight,!1),y=new Ke(d.framebufferWidth,d.framebufferHeight,{format:Zn,type:Nn,colorSpace:t.outputColorSpace,stencilBuffer:S.stencil,resolveDepthBuffer:d.ignoreDepthValues===!1,resolveStencilBuffer:d.ignoreDepthValues===!1,storeMultisampledDepthBuffer:d.ignoreDepthValues===!1,storeMultisampledStencilBuffer:d.ignoreDepthValues===!1})}y.isXRRenderTarget=!0,this.setFoveation(c),l=null,a=await s.requestReferenceSpace(o),Dt.setContext(s),Dt.start(),n.isPresenting=!0,n.dispatchEvent({type:"sessionstart"})}},this.getEnvironmentBlendMode=function(){if(s!==null)return s.environmentBlendMode},this.getDepthTexture=function(){return m.getDepthTexture()};function dt(tt){for(let it=0;it<tt.removed.length;it++){let _t=tt.removed[it],bt=M.indexOf(_t);bt>=0&&(M[bt]=null,E[bt].disconnect(_t))}for(let it=0;it<tt.added.length;it++){let _t=tt.added[it],bt=M.indexOf(_t);if(bt===-1){for(let Ct=0;Ct<E.length;Ct++)if(Ct>=M.length){M.push(_t),bt=Ct;break}else if(M[Ct]===null){M[Ct]=_t,bt=Ct;break}if(bt===-1)break}let mt=E[bt];mt&&mt.connect(_t)}}let Q=new D,ct=new D;function O(tt,it,_t){Q.setFromMatrixPosition(it.matrixWorld),ct.setFromMatrixPosition(_t.matrixWorld);let bt=Q.distanceTo(ct),mt=it.projectionMatrix.elements,Ct=_t.projectionMatrix.elements,Qt=mt[14]/(mt[10]-1),V=mt[14]/(mt[10]+1),ut=(mt[9]+1)/mt[5],xt=(mt[9]-1)/mt[5],gt=(mt[8]-1)/mt[0],yt=(Ct[8]+1)/Ct[0],Bt=Qt*gt,Ut=Qt*yt,Zt=bt/(-gt+yt),ee=Zt*-gt;if(it.matrixWorld.decompose(tt.position,tt.quaternion,tt.scale),tt.translateX(ee),tt.translateZ(Zt),tt.matrixWorld.compose(tt.position,tt.quaternion,tt.scale),tt.matrixWorldInverse.copy(tt.matrixWorld).invert(),mt[10]===-1)tt.projectionMatrix.copy(it.projectionMatrix),tt.projectionMatrixInverse.copy(it.projectionMatrixInverse);else{let U=Qt+Zt,ne=V+Zt,re=Bt-ee,A=Ut+(bt-ee),x=ut*V/ne*U,G=xt*V/ne*U;tt.projectionMatrix.makePerspective(re,A,x,G,U,ne),tt.projectionMatrixInverse.copy(tt.projectionMatrix).invert()}}function St(tt,it){it===null?tt.matrixWorld.copy(tt.matrix):tt.matrixWorld.multiplyMatrices(it.matrixWorld,tt.matrix),tt.matrixWorldInverse.copy(tt.matrixWorld).invert()}this.updateCamera=function(tt){if(s===null)return;let it=tt.near,_t=tt.far;m.texture!==null&&(m.depthNear>0&&(it=m.depthNear),m.depthFar>0&&(_t=m.depthFar)),B.near=N.near=L.near=it,B.far=N.far=L.far=_t,(F!==B.near||W!==B.far)&&(s.updateRenderState({depthNear:B.near,depthFar:B.far}),F=B.near,W=B.far),B.layers.mask=tt.layers.mask|6,L.layers.mask=B.layers.mask&-5,N.layers.mask=B.layers.mask&-3;let bt=tt.parent,mt=B.cameras;St(B,bt);for(let Ct=0;Ct<mt.length;Ct++)St(mt[Ct],bt);mt.length===2?O(B,L,N):B.projectionMatrix.copy(L.projectionMatrix),C===null&&tt.isPerspectiveCamera&&(C={camera:tt,fov:tt.fov,zoom:tt.zoom}),Et(tt,B,bt)};function Et(tt,it,_t){_t===null?tt.matrix.copy(it.matrixWorld):(tt.matrix.copy(_t.matrixWorld),tt.matrix.invert(),tt.matrix.multiply(it.matrixWorld)),tt.matrix.decompose(tt.position,tt.quaternion,tt.scale),tt.updateMatrixWorld(!0),tt.projectionMatrix.copy(it.projectionMatrix),tt.projectionMatrixInverse.copy(it.projectionMatrixInverse),tt.isPerspectiveCamera&&(tt.fov=cl*2*Math.atan(1/tt.projectionMatrix.elements[5]),tt.zoom=1)}this.getCamera=function(){return B},this.getFoveation=function(){if(!(u===null&&d===null))return c},this.setFoveation=function(tt){c=tt,u!==null&&(u.fixedFoveation=tt),d!==null&&d.fixedFoveation!==void 0&&(d.fixedFoveation=tt)},this.hasDepthSensing=function(){return m.texture!==null},this.getDepthSensingMesh=function(){return m.getMesh(B)},this.getCameraTexture=function(tt){return p[tt]};let At=null;function Ot(tt,it){if(h=it.getViewerPose(l||a),g=it,h!==null){let _t=h.views;d!==null&&(t.setRenderTargetFramebuffer(y,d.framebuffer),t.setRenderTarget(y));let bt=!1;_t.length!==B.cameras.length&&(B.cameras.length=0,bt=!0);for(let V=0;V<_t.length;V++){let ut=_t[V],xt=null;if(d!==null)xt=d.getViewport(ut);else{let yt=f.getViewSubImage(u,ut);xt=yt.viewport,V===0&&(t.setRenderTargetTextures(y,yt.colorTexture,yt.depthStencilTexture),t.setRenderTarget(y))}let gt=P[V];gt===void 0&&(gt=new yn,gt.layers.enable(V),gt.viewport=new $e,P[V]=gt),gt.matrix.fromArray(ut.transform.matrix),gt.matrix.decompose(gt.position,gt.quaternion,gt.scale),gt.projectionMatrix.fromArray(ut.projectionMatrix),gt.projectionMatrixInverse.copy(gt.projectionMatrix).invert(),gt.viewport.set(xt.x,xt.y,xt.width,xt.height),V===0&&(B.matrix.copy(gt.matrix),B.matrix.decompose(B.position,B.quaternion,B.scale)),bt===!0&&B.cameras.push(gt)}let mt=s.enabledFeatures;if(mt&&mt.includes("depth-sensing")&&s.depthUsage=="gpu-optimized"&&_){f=n.getBinding();let V=f.getDepthInformation(_t[0]);V&&V.isValid&&V.texture&&m.init(V,s.renderState)}if(mt&&mt.includes("camera-access")&&_){t.state.unbindTexture(),f=n.getBinding();for(let V=0;V<_t.length;V++){let ut=_t[V].camera;if(ut){let xt=p[ut];xt||(xt=new _a,p[ut]=xt);let gt=f.getCameraImage(ut);xt.sourceTexture=gt}}}}for(let _t=0;_t<E.length;_t++){let bt=M[_t],mt=E[_t];bt!==null&&mt!==void 0&&mt.update(bt,it,l||a)}At&&At(tt,it),it.detectedPlanes&&n.dispatchEvent({type:"planesdetected",data:it}),g=null}let Dt=new af;Dt.setAnimationLoop(Ot),this.setAnimationLoop=function(tt){At=tt},this.dispose=function(){}}},s3=new Ce,df=new me;df.set(-1,0,0,0,1,0,0,0,1);function r3(i,t){function e(m,p){m.matrixAutoUpdate===!0&&m.updateMatrix(),p.value.copy(m.matrix)}function n(m,p){p.color.getRGB(m.fogColor.value,lh(i)),p.isFog?(m.fogNear.value=p.near,m.fogFar.value=p.far):p.isFogExp2&&(m.fogDensity.value=p.density)}function s(m,p,S,w,y){p.isNodeMaterial?p.uniformsNeedUpdate=!1:p.isMeshBasicMaterial?r(m,p):p.isMeshLambertMaterial?(r(m,p),p.envMap&&(m.envMapIntensity.value=p.envMapIntensity)):p.isMeshToonMaterial?(r(m,p),f(m,p)):p.isMeshPhongMaterial?(r(m,p),h(m,p),p.envMap&&(m.envMapIntensity.value=p.envMapIntensity)):p.isMeshStandardMaterial?(r(m,p),u(m,p),p.isMeshPhysicalMaterial&&d(m,p,y)):p.isMeshMatcapMaterial?(r(m,p),g(m,p)):p.isMeshDepthMaterial?r(m,p):p.isMeshDistanceMaterial?(r(m,p),_(m,p)):p.isMeshNormalMaterial?r(m,p):p.isLineBasicMaterial?(a(m,p),p.isLineDashedMaterial&&o(m,p)):p.isPointsMaterial?c(m,p,S,w):p.isSpriteMaterial?l(m,p):p.isShadowMaterial?(m.color.value.copy(p.color),m.opacity.value=p.opacity):p.isShaderMaterial&&(p.uniformsNeedUpdate=!1)}function r(m,p){m.opacity.value=p.opacity,p.color&&m.diffuse.value.copy(p.color),p.emissive&&m.emissive.value.copy(p.emissive).multiplyScalar(p.emissiveIntensity),p.map&&(m.map.value=p.map,e(p.map,m.mapTransform)),p.alphaMap&&(m.alphaMap.value=p.alphaMap,e(p.alphaMap,m.alphaMapTransform)),p.bumpMap&&(m.bumpMap.value=p.bumpMap,e(p.bumpMap,m.bumpMapTransform),m.bumpScale.value=p.bumpScale,p.side===bn&&(m.bumpScale.value*=-1)),p.normalMap&&(m.normalMap.value=p.normalMap,e(p.normalMap,m.normalMapTransform),m.normalScale.value.copy(p.normalScale),p.side===bn&&m.normalScale.value.negate()),p.displacementMap&&(m.displacementMap.value=p.displacementMap,e(p.displacementMap,m.displacementMapTransform),m.displacementScale.value=p.displacementScale,m.displacementBias.value=p.displacementBias),p.emissiveMap&&(m.emissiveMap.value=p.emissiveMap,e(p.emissiveMap,m.emissiveMapTransform)),p.specularMap&&(m.specularMap.value=p.specularMap,e(p.specularMap,m.specularMapTransform)),p.alphaTest>0&&(m.alphaTest.value=p.alphaTest);let S=t.get(p),w=S.envMap,y=S.envMapRotation;w&&(m.envMap.value=w,m.envMapRotation.value.setFromMatrix4(s3.makeRotationFromEuler(y)).transpose(),w.isCubeTexture&&w.isRenderTargetTexture===!1&&m.envMapRotation.value.premultiply(df),m.reflectivity.value=p.reflectivity,m.ior.value=p.ior,m.refractionRatio.value=p.refractionRatio),p.lightMap&&(m.lightMap.value=p.lightMap,m.lightMapIntensity.value=p.lightMapIntensity,e(p.lightMap,m.lightMapTransform)),p.aoMap&&(m.aoMap.value=p.aoMap,m.aoMapIntensity.value=p.aoMapIntensity,e(p.aoMap,m.aoMapTransform))}function a(m,p){m.diffuse.value.copy(p.color),m.opacity.value=p.opacity,p.map&&(m.map.value=p.map,e(p.map,m.mapTransform))}function o(m,p){m.dashSize.value=p.dashSize,m.totalSize.value=p.dashSize+p.gapSize,m.scale.value=p.scale}function c(m,p,S,w){m.diffuse.value.copy(p.color),m.opacity.value=p.opacity,m.size.value=p.size*S,m.scale.value=w*.5,p.map&&(m.map.value=p.map,e(p.map,m.uvTransform)),p.alphaMap&&(m.alphaMap.value=p.alphaMap,e(p.alphaMap,m.alphaMapTransform)),p.alphaTest>0&&(m.alphaTest.value=p.alphaTest)}function l(m,p){m.diffuse.value.copy(p.color),m.opacity.value=p.opacity,m.rotation.value=p.rotation,p.map&&(m.map.value=p.map,e(p.map,m.mapTransform)),p.alphaMap&&(m.alphaMap.value=p.alphaMap,e(p.alphaMap,m.alphaMapTransform)),p.alphaTest>0&&(m.alphaTest.value=p.alphaTest)}function h(m,p){m.specular.value.copy(p.specular),m.shininess.value=Math.max(p.shininess,1e-4)}function f(m,p){p.gradientMap&&(m.gradientMap.value=p.gradientMap)}function u(m,p){m.metalness.value=p.metalness,p.metalnessMap&&(m.metalnessMap.value=p.metalnessMap,e(p.metalnessMap,m.metalnessMapTransform)),m.roughness.value=p.roughness,p.roughnessMap&&(m.roughnessMap.value=p.roughnessMap,e(p.roughnessMap,m.roughnessMapTransform)),p.envMap&&(m.envMapIntensity.value=p.envMapIntensity)}function d(m,p,S){m.ior.value=p.ior,p.sheen>0&&(m.sheenColor.value.copy(p.sheenColor).multiplyScalar(p.sheen),m.sheenRoughness.value=p.sheenRoughness,p.sheenColorMap&&(m.sheenColorMap.value=p.sheenColorMap,e(p.sheenColorMap,m.sheenColorMapTransform)),p.sheenRoughnessMap&&(m.sheenRoughnessMap.value=p.sheenRoughnessMap,e(p.sheenRoughnessMap,m.sheenRoughnessMapTransform))),p.clearcoat>0&&(m.clearcoat.value=p.clearcoat,m.clearcoatRoughness.value=p.clearcoatRoughness,p.clearcoatMap&&(m.clearcoatMap.value=p.clearcoatMap,e(p.clearcoatMap,m.clearcoatMapTransform)),p.clearcoatRoughnessMap&&(m.clearcoatRoughnessMap.value=p.clearcoatRoughnessMap,e(p.clearcoatRoughnessMap,m.clearcoatRoughnessMapTransform)),p.clearcoatNormalMap&&(m.clearcoatNormalMap.value=p.clearcoatNormalMap,e(p.clearcoatNormalMap,m.clearcoatNormalMapTransform),m.clearcoatNormalScale.value.copy(p.clearcoatNormalScale),p.side===bn&&m.clearcoatNormalScale.value.negate())),p.dispersion>0&&(m.dispersion.value=p.dispersion),p.retroreflectivity>0&&(m.retroreflectivity.value=p.retroreflectivity),p.iridescence>0&&(m.iridescence.value=p.iridescence,m.iridescenceIOR.value=p.iridescenceIOR,m.iridescenceThicknessMinimum.value=p.iridescenceThicknessRange[0],m.iridescenceThicknessMaximum.value=p.iridescenceThicknessRange[1],p.iridescenceMap&&(m.iridescenceMap.value=p.iridescenceMap,e(p.iridescenceMap,m.iridescenceMapTransform)),p.iridescenceThicknessMap&&(m.iridescenceThicknessMap.value=p.iridescenceThicknessMap,e(p.iridescenceThicknessMap,m.iridescenceThicknessMapTransform))),p.transmission>0&&(m.transmission.value=p.transmission,m.transmissionSamplerMap.value=S.texture,m.transmissionSamplerSize.value.set(S.width,S.height),p.transmissionMap&&(m.transmissionMap.value=p.transmissionMap,e(p.transmissionMap,m.transmissionMapTransform)),m.thickness.value=p.thickness,p.thicknessMap&&(m.thicknessMap.value=p.thicknessMap,e(p.thicknessMap,m.thicknessMapTransform)),m.attenuationDistance.value=p.attenuationDistance,m.attenuationColor.value.copy(p.attenuationColor)),p.anisotropy>0&&(m.anisotropyVector.value.set(p.anisotropy*Math.cos(p.anisotropyRotation),p.anisotropy*Math.sin(p.anisotropyRotation)),p.anisotropyMap&&(m.anisotropyMap.value=p.anisotropyMap,e(p.anisotropyMap,m.anisotropyMapTransform))),m.specularIntensity.value=p.specularIntensity,m.specularColor.value.copy(p.specularColor),p.specularColorMap&&(m.specularColorMap.value=p.specularColorMap,e(p.specularColorMap,m.specularColorMapTransform)),p.specularIntensityMap&&(m.specularIntensityMap.value=p.specularIntensityMap,e(p.specularIntensityMap,m.specularIntensityMapTransform))}function g(m,p){p.matcap&&(m.matcap.value=p.matcap)}function _(m,p){let S=t.get(p).light;m.referencePosition.value.setFromMatrixPosition(S.matrixWorld),m.nearDistance.value=S.shadow.camera.near,m.farDistance.value=S.shadow.camera.far}return{refreshFogUniforms:n,refreshMaterialUniforms:s}}function a3(i,t,e,n){let s={},r={},a=[],o=i.getParameter(i.MAX_UNIFORM_BUFFER_BINDINGS);function c(y,E){let M=E.program;n.uniformBlockBinding(y,M)}function l(y,E){let M=s[y.id];M===void 0&&(m(y),M=h(y),s[y.id]=M,y.addEventListener("dispose",S));let I=E.program;n.updateUBOMapping(y,I);let v=t.render.frame;r[y.id]!==v&&(u(y),r[y.id]=v)}function h(y){let E=f();y.__bindingPointIndex=E;let M=i.createBuffer(),I=y.__size,v=y.usage;return i.bindBuffer(i.UNIFORM_BUFFER,M),i.bufferData(i.UNIFORM_BUFFER,I,v),i.bindBuffer(i.UNIFORM_BUFFER,null),i.bindBufferBase(i.UNIFORM_BUFFER,E,M),M}function f(){for(let y=0;y<o;y++)if(a.indexOf(y)===-1)return a.push(y),y;return he("WebGLRenderer: Maximum number of simultaneously usable uniforms groups reached."),0}function u(y){let E=s[y.id],M=y.uniforms,I=y.__cache;i.bindBuffer(i.UNIFORM_BUFFER,E);for(let v=0,C=M.length;v<C;v++){let L=M[v];if(Array.isArray(L))for(let N=0,P=L.length;N<P;N++)d(L[N],v,N,I);else d(L,v,0,I)}i.bindBuffer(i.UNIFORM_BUFFER,null)}function d(y,E,M,I){if(_(y,E,M,I)===!0){let v=y.__offset,C=y.value;if(Array.isArray(C)){let L=0;for(let N=0;N<C.length;N++){let P=C[N],B=p(P);g(P,y.__data,L),typeof P!="number"&&typeof P!="boolean"&&!P.isMatrix3&&!ArrayBuffer.isView(P)&&(L+=B.storage/Float32Array.BYTES_PER_ELEMENT)}}else g(C,y.__data,0);i.bufferSubData(i.UNIFORM_BUFFER,v,y.__data)}}function g(y,E,M){typeof y=="number"||typeof y=="boolean"?E[0]=y:y.isMatrix3?(E[0]=y.elements[0],E[1]=y.elements[1],E[2]=y.elements[2],E[3]=0,E[4]=y.elements[3],E[5]=y.elements[4],E[6]=y.elements[5],E[7]=0,E[8]=y.elements[6],E[9]=y.elements[7],E[10]=y.elements[8],E[11]=0):ArrayBuffer.isView(y)?E.set(new y.constructor(y.buffer,y.byteOffset,E.length)):y.toArray(E,M)}function _(y,E,M,I){let v=y.value,C=E+"_"+M;if(I[C]===void 0)return typeof v=="number"||typeof v=="boolean"?I[C]=v:ArrayBuffer.isView(v)?I[C]=v.slice():I[C]=v.clone(),!0;{let L=I[C];if(typeof v=="number"||typeof v=="boolean"){if(L!==v)return I[C]=v,!0}else{if(ArrayBuffer.isView(v))return!0;if(L.equals(v)===!1)return L.copy(v),!0}}return!1}function m(y){let E=y.uniforms,M=0,I=16;for(let C=0,L=E.length;C<L;C++){let N=Array.isArray(E[C])?E[C]:[E[C]];for(let P=0,B=N.length;P<B;P++){let F=N[P],W=Array.isArray(F.value)?F.value:[F.value];for(let rt=0,nt=W.length;rt<nt;rt++){let dt=W[rt],Q=p(dt),ct=M%I,O=ct%Q.boundary,St=ct+O;M+=O,St!==0&&I-St<Q.storage&&(M+=I-St),F.__data=new Float32Array(Q.storage/Float32Array.BYTES_PER_ELEMENT),F.__offset=M,M+=Q.storage}}}let v=M%I;return v>0&&(M+=I-v),y.__size=M,y.__cache={},this}function p(y){let E={boundary:0,storage:0};return typeof y=="number"||typeof y=="boolean"?(E.boundary=4,E.storage=4):y.isVector2?(E.boundary=8,E.storage=8):y.isVector3||y.isColor?(E.boundary=16,E.storage=12):y.isVector4?(E.boundary=16,E.storage=16):y.isMatrix3?(E.boundary=48,E.storage=48):y.isMatrix4?(E.boundary=64,E.storage=64):y.isTexture?ue("WebGLRenderer: Texture samplers can not be part of an uniforms group."):ArrayBuffer.isView(y)?(E.boundary=16,E.storage=y.byteLength):ue("WebGLRenderer: Unsupported uniform value type.",y),E}function S(y){let E=y.target;E.removeEventListener("dispose",S);let M=a.indexOf(E.__bindingPointIndex);a.splice(M,1),i.deleteBuffer(s[E.id]),delete s[E.id],delete r[E.id]}function w(){for(let y in s)i.deleteBuffer(s[y]);a=[],s={},r={}}return{bind:c,update:l,dispose:w}}var o3=new Uint16Array([12469,15057,12620,14925,13266,14620,13807,14376,14323,13990,14545,13625,14713,13328,14840,12882,14931,12528,14996,12233,15039,11829,15066,11525,15080,11295,15085,10976,15082,10705,15073,10495,13880,14564,13898,14542,13977,14430,14158,14124,14393,13732,14556,13410,14702,12996,14814,12596,14891,12291,14937,11834,14957,11489,14958,11194,14943,10803,14921,10506,14893,10278,14858,9960,14484,14039,14487,14025,14499,13941,14524,13740,14574,13468,14654,13106,14743,12678,14818,12344,14867,11893,14889,11509,14893,11180,14881,10751,14852,10428,14812,10128,14765,9754,14712,9466,14764,13480,14764,13475,14766,13440,14766,13347,14769,13070,14786,12713,14816,12387,14844,11957,14860,11549,14868,11215,14855,10751,14825,10403,14782,10044,14729,9651,14666,9352,14599,9029,14967,12835,14966,12831,14963,12804,14954,12723,14936,12564,14917,12347,14900,11958,14886,11569,14878,11247,14859,10765,14828,10401,14784,10011,14727,9600,14660,9289,14586,8893,14508,8533,15111,12234,15110,12234,15104,12216,15092,12156,15067,12010,15028,11776,14981,11500,14942,11205,14902,10752,14861,10393,14812,9991,14752,9570,14682,9252,14603,8808,14519,8445,14431,8145,15209,11449,15208,11451,15202,11451,15190,11438,15163,11384,15117,11274,15055,10979,14994,10648,14932,10343,14871,9936,14803,9532,14729,9218,14645,8742,14556,8381,14461,8020,14365,7603,15273,10603,15272,10607,15267,10619,15256,10631,15231,10614,15182,10535,15118,10389,15042,10167,14963,9787,14883,9447,14800,9115,14710,8665,14615,8318,14514,7911,14411,7507,14279,7198,15314,9675,15313,9683,15309,9712,15298,9759,15277,9797,15229,9773,15166,9668,15084,9487,14995,9274,14898,8910,14800,8539,14697,8234,14590,7790,14479,7409,14367,7067,14178,6621,15337,8619,15337,8631,15333,8677,15325,8769,15305,8871,15264,8940,15202,8909,15119,8775,15022,8565,14916,8328,14804,8009,14688,7614,14569,7287,14448,6888,14321,6483,14088,6171,15350,7402,15350,7419,15347,7480,15340,7613,15322,7804,15287,7973,15229,8057,15148,8012,15046,7846,14933,7611,14810,7357,14682,7069,14552,6656,14421,6316,14251,5948,14007,5528,15356,5942,15356,5977,15353,6119,15348,6294,15332,6551,15302,6824,15249,7044,15171,7122,15070,7050,14949,6861,14818,6611,14679,6349,14538,6067,14398,5651,14189,5311,13935,4958,15359,4123,15359,4153,15356,4296,15353,4646,15338,5160,15311,5508,15263,5829,15188,6042,15088,6094,14966,6001,14826,5796,14678,5543,14527,5287,14377,4985,14133,4586,13869,4257,15360,1563,15360,1642,15358,2076,15354,2636,15341,3350,15317,4019,15273,4429,15203,4732,15105,4911,14981,4932,14836,4818,14679,4621,14517,4386,14359,4156,14083,3795,13808,3437,15360,122,15360,137,15358,285,15355,636,15344,1274,15322,2177,15281,2765,15215,3223,15120,3451,14995,3569,14846,3567,14681,3466,14511,3305,14344,3121,14037,2800,13753,2467,15360,0,15360,1,15359,21,15355,89,15346,253,15325,479,15287,796,15225,1148,15133,1492,15008,1749,14856,1882,14685,1886,14506,1783,14324,1608,13996,1398,13702,1183]),Ei=null;function l3(){return Ei===null&&(Ei=new pa(o3,16,16,ps,ln),Ei.name="DFG_LUT",Ei.minFilter=Mn,Ei.magFilter=Mn,Ei.wrapS=xi,Ei.wrapT=xi,Ei.generateMipmaps=!1,Ei.needsUpdate=!0),Ei}var Rc=class{constructor(t={}){let{canvas:e=Td(),context:n=null,depth:s=!0,stencil:r=!1,alpha:a=!1,antialias:o=!1,premultipliedAlpha:c=!0,preserveDrawingBuffer:l=!1,powerPreference:h="default",failIfMajorPerformanceCaveat:f=!1,reversedDepthBuffer:u=!1,outputBufferType:d=Nn}=t;this.isWebGLRenderer=!0;let g;if(n!==null){if(typeof WebGLRenderingContext<"u"&&n instanceof WebGLRenderingContext)throw new Error("THREE.WebGLRenderer: WebGL 1 is not supported since r163.");g=n.getContextAttributes().alpha}else g=a;let _=d,m=new Set([Wl,Gl,Vl]),p=new Set([Nn,hi,Ar,Rr,zl,kl]),S=new Uint32Array(4),w=new Int32Array(4),y=new D,E=null,M=null,I=[],v=[],C=null;this.domElement=e,this.debug={checkShaderErrors:!0,diagnostics:{keywords:!1},onShaderError:null},this.autoClear=!0,this.autoClearColor=!0,this.autoClearDepth=!0,this.autoClearStencil=!0,this.sortObjects=!0,this.clippingPlanes=[],this.localClippingEnabled=!1,this.toneMapping=ci,this.toneMappingExposure=1,this.transmissionResolutionScale=1;let L=this,N=!1,P=null,B=null,F=null,W=null;this._outputColorSpace=Ye;let rt=0,nt=0,dt=null,Q=-1,ct=null,O=new $e,St=new $e,Et=null,At=new se(0),Ot=0,Dt=e.width,tt=e.height,it=1,_t=null,bt=null,mt=new $e(0,0,Dt,tt),Ct=new $e(0,0,Dt,tt),Qt=!1,V=new pr,ut=!1,xt=!1,gt=new Ce,yt=new D,Bt=new $e,Ut={background:null,fog:null,environment:null,overrideMaterial:null,isScene:!0},Zt=!1;function ee(){return dt===null?it:1}let U=n;function ne(b,H){return e.getContext(b,H)}let re,A,x,G,Y,at,Mt,Rt,st,ft,Pt,Ht,Nt,Tt,Xt,Jt,le,z,Ft,T,q,ht,X;try{let b={alpha:!0,depth:s,stencil:r,antialias:o,premultipliedAlpha:c,preserveDrawingBuffer:l,powerPreference:h,failIfMajorPerformanceCaveat:f};if("setAttribute"in e&&e.setAttribute("data-engine",`three.js r${"186"}`),e.addEventListener("webglcontextlost",xe,!1),e.addEventListener("webglcontextrestored",Gt,!1),e.addEventListener("webglcontextcreationerror",ie,!1),U===null){let H="webgl2";if(U=ne(H,b),U===null)throw ne(H)?new Error("THREE.WebGLRenderer: Error creating WebGL context with your selected attributes."):new Error("THREE.WebGLRenderer: Error creating WebGL context.")}zt()}catch(b){throw e.removeEventListener("webglcontextlost",xe,!1),e.removeEventListener("webglcontextrestored",Gt,!1),e.removeEventListener("webglcontextcreationerror",ie,!1),he("WebGLRenderer: "+b.message),b}function zt(){re=new m2(U),re.init(),q=new e3(U,re),A=new r2(U,re,t,q),x=new Qx(U,re),A.reversedDepthBuffer&&u&&x.buffers.depth.setReversed(!0),B=U.createFramebuffer(),F=U.createFramebuffer(),W=U.createFramebuffer(),G=new _2(U),Y=new zx,at=new t3(U,re,x,Y,A,q,G),Mt=new p2(L),Rt=new y1(U),ht=new i2(U,Rt),st=new g2(U,Rt,G,ht),ft=new y2(U,st,Rt,ht,G),z=new v2(U,A,at),Xt=new a2(Y),Pt=new Bx(L,Mt,re,A,ht,Xt),Ht=new r3(L,Y),Nt=new Hx,Tt=new qx(re),le=new n2(L,Mt,x,ft,g,c),Jt=new jx(L,ft,A),X=new a3(U,G,A,x),Ft=new s2(U,re,G),T=new x2(U,re,G),G.programs=Pt.programs,L.capabilities=A,L.extensions=re,L.properties=Y,L.renderLists=Nt,L.shadowMap=Jt,L.state=x,L.info=G}_!==Nn&&(C=new b2(_,e.width,e.height,o,s,r));let wt=new Th(L,U);this.xr=wt,this.getContext=function(){return U},this.getContextAttributes=function(){return U.getContextAttributes()},this.forceContextLoss=function(){let b=re.get("WEBGL_lose_context");b&&b.loseContext()},this.forceContextRestore=function(){let b=re.get("WEBGL_lose_context");b&&b.restoreContext()},this.getPixelRatio=function(){return it},this.setPixelRatio=function(b){b!==void 0&&(it=b,this.setSize(Dt,tt,!1))},this.getSize=function(b){return b.set(Dt,tt)},this.setSize=function(b,H,J=!0){if(wt.isPresenting){ue("WebGLRenderer: Can't change size while VR device is presenting.");return}Dt=b,tt=H,e.width=Math.floor(b*it),e.height=Math.floor(H*it),J===!0&&(e.style.width=b+"px",e.style.height=H+"px"),C!==null&&C.setSize(e.width,e.height),this.setViewport(0,0,b,H)},this.getDrawingBufferSize=function(b){return b.set(Dt*it,tt*it).floor()},this.setDrawingBufferSize=function(b,H,J){Dt=b,tt=H,it=J,e.width=Math.floor(b*J),e.height=Math.floor(H*J),this.setViewport(0,0,b,H)},this.setEffects=function(b){if(_===Nn){he("WebGLRenderer: setEffects() requires outputBufferType set to HalfFloatType or FloatType.");return}if(b){for(let H=0;H<b.length;H++)if(b[H].isOutputPass===!0){ue("WebGLRenderer: OutputPass is not needed in setEffects(). Tone mapping and color space conversion are applied automatically.");break}}C.setEffects(b||[])},this.getCurrentViewport=function(b){return b.copy(O)},this.getViewport=function(b){return b.copy(mt)},this.setViewport=function(b,H,J,K){b.isVector4?mt.set(b.x,b.y,b.z,b.w):mt.set(b,H,J,K),x.viewport(O.copy(mt).multiplyScalar(it).round())},this.getScissor=function(b){return b.copy(Ct)},this.setScissor=function(b,H,J,K){b.isVector4?Ct.set(b.x,b.y,b.z,b.w):Ct.set(b,H,J,K),x.scissor(St.copy(Ct).multiplyScalar(it).round())},this.getScissorTest=function(){return Qt},this.setScissorTest=function(b){x.setScissorTest(Qt=b)},this.setOpaqueSort=function(b){_t=b},this.setTransparentSort=function(b){bt=b},this.getClearColor=function(b){return b.copy(le.getClearColor())},this.setClearColor=function(){le.setClearColor(...arguments)},this.getClearAlpha=function(){return le.getClearAlpha()},this.setClearAlpha=function(){le.setClearAlpha(...arguments)},this.clear=function(b=!0,H=!0,J=!0){let K=0;if(b){let j=!1;if(dt!==null){let kt=dt.texture.format;j=m.has(kt)}if(j){let kt=dt.texture.type,$t=p.has(kt),Lt=le.getClearColor(),Kt=le.getClearAlpha(),qt=Lt.r,pe=Lt.g,ye=Lt.b;$t?(S[0]=qt,S[1]=pe,S[2]=ye,S[3]=Kt,U.clearBufferuiv(U.COLOR,0,S)):(w[0]=qt,w[1]=pe,w[2]=ye,w[3]=Kt,U.clearBufferiv(U.COLOR,0,w))}else K|=U.COLOR_BUFFER_BIT}H&&(K|=U.DEPTH_BUFFER_BIT,this.state.buffers.depth.setMask(!0)),J&&(K|=U.STENCIL_BUFFER_BIT,this.state.buffers.stencil.setMask(4294967295)),K!==0&&U.clear(K)},this.clearColor=function(){this.clear(!0,!1,!1)},this.clearDepth=function(){this.clear(!1,!0,!1)},this.clearStencil=function(){this.clear(!1,!1,!0)},this.setNodesHandler=function(b){b.setRenderer(this),P=b},this.dispose=function(){e.removeEventListener("webglcontextlost",xe,!1),e.removeEventListener("webglcontextrestored",Gt,!1),e.removeEventListener("webglcontextcreationerror",ie,!1),le.dispose(),Nt.dispose(),Tt.dispose(),Y.dispose(),Mt.dispose(),ft.dispose(),ht.dispose(),X.dispose(),Pt.dispose(),wt.dispose(),wt.removeEventListener("sessionstart",po),wt.removeEventListener("sessionend",fi),Vn.stop()};function xe(b){b.preventDefault(),oa("WebGLRenderer: Context Lost."),N=!0}function Gt(){oa("WebGLRenderer: Context Restored."),N=!1;let b=G.autoReset,H=Jt.enabled,J=Jt.autoUpdate,K=Jt.needsUpdate,j=Jt.type;zt(),G.autoReset=b,Jt.enabled=H,Jt.autoUpdate=J,Jt.needsUpdate=K,Jt.type=j}function ie(b){he("WebGLRenderer: A WebGL context could not be created. Reason: ",b.statusMessage)}function ke(b){let H=b.target;H.removeEventListener("dispose",ke),xn(H)}function xn(b){Kn(b),Y.remove(b)}function Kn(b){let H=Y.get(b).programs;H!==void 0&&(H.forEach(function(J){Pt.releaseProgram(J)}),b.isShaderMaterial&&Pt.releaseShaderCache(b))}this.renderBufferDirect=function(b,H,J,K,j,kt){H===null&&(H=Ut);let $t=j.isMesh&&j.matrixWorld.determinantAffine()<0,Lt=Jc(b,H,J,K,j);x.setMaterial(K,$t);let Kt=J.index,qt=1;if(K.wireframe===!0){if(Kt=st.getWireframeAttribute(J),Kt===void 0)return;qt=2}let pe=J.drawRange,ye=J.attributes.position,jt=pe.start*qt,ge=(pe.start+pe.count)*qt;kt!==null&&(jt=Math.max(jt,kt.start*qt),ge=Math.min(ge,(kt.start+kt.count)*qt)),Kt!==null?(jt=Math.max(jt,0),ge=Math.min(ge,Kt.count)):ye!=null&&(jt=Math.max(jt,0),ge=Math.min(ge,ye.count));let Ie=ge-jt;if(Ie<0||Ie===1/0)return;ht.setup(j,K,Lt,J,Kt);let He,Ne=Ft;if(Kt!==null&&(He=Rt.get(Kt),Ne=T,Ne.setIndex(He)),j.isMesh)K.wireframe===!0?(x.setLineWidth(K.wireframeLinewidth*ee()),Ne.setMode(U.LINES)):Ne.setMode(U.TRIANGLES);else if(j.isLine){let sn=K.linewidth;sn===void 0&&(sn=1),x.setLineWidth(sn*ee()),j.isLineSegments?Ne.setMode(U.LINES):j.isLineLoop?Ne.setMode(U.LINE_LOOP):Ne.setMode(U.LINE_STRIP)}else j.isPoints?Ne.setMode(U.POINTS):j.isSprite&&Ne.setMode(U.TRIANGLES);if(j.isBatchedMesh)if(re.get("WEBGL_multi_draw"))Ne.renderMultiDraw(j._multiDrawStarts,j._multiDrawCounts,j._multiDrawCount);else{let sn=j._multiDrawStarts,Yt=j._multiDrawCounts,un=j._multiDrawCount,we=Kt?Rt.get(Kt).bytesPerElement:1,In=Y.get(K).currentProgram.getUniforms();for(let Dn=0;Dn<un;Dn++)In.setValue(U,"_gl_DrawID",Dn),Ne.render(sn[Dn]/we,Yt[Dn])}else if(j.isInstancedMesh)Ne.renderInstances(jt,Ie,j.count);else if(J.isInstancedBufferGeometry){let sn=J._maxInstanceCount!==void 0?J._maxInstanceCount:1/0,Yt=Math.min(J.instanceCount,sn);Ne.renderInstances(jt,Ie,Yt)}else Ne.render(jt,Ie)};function Or(b,H,J,K){P!==null&&b.isNodeMaterial&&P.setObject(K,b),ut===!0&&Xt.setState(b,J,!1),b.transparent===!0&&b.side===Sn&&b.forceSinglePass===!1?(b.side=bn,b.needsUpdate=!0,Ls(b,H,K),b.side=hs,b.needsUpdate=!0,Ls(b,H,K),b.side=Sn):Ls(b,H,K)}this.compile=function(b,H,J=null){J===null&&(J=b),P!==null&&P.renderStart(b,H,J),M=Tt.get(J),M.init(H),v.push(M),J.traverseVisible(function(j){j.isLight&&j.layers.test(H.layers)&&(M.pushLight(j),j.castShadow&&M.pushShadow(j))}),b!==J&&b.traverseVisible(function(j){j.isLight&&j.layers.test(H.layers)&&(M.pushLight(j),j.castShadow&&M.pushShadow(j))}),M.setupLights(),P!==null&&P.updateLights(M.state.lightsArray),xt=this.localClippingEnabled,ut=Xt.init(this.clippingPlanes,xt),ut===!0&&Xt.setGlobalState(this.clippingPlanes,H),P!==null&&Jt.render(M.state.shadowsArray,J,H);let K=new Set;return b.traverse(function(j){if(!(j.isMesh||j.isPoints||j.isLine||j.isSprite))return;let kt=j.material;if(kt)if(Array.isArray(kt))for(let $t=0;$t<kt.length;$t++){let Lt=kt[$t];Or(Lt,J,H,j),K.add(Lt)}else Or(kt,J,H,j),K.add(kt)}),M=v.pop(),P!==null&&P.renderEnd(),K},this.compileAsync=function(b,H,J=null){let K=this.compile(b,H,J);return new Promise(j=>{function kt(){if(K.forEach(function($t){let Kt=Y.get($t).currentProgram;(Kt===void 0||Kt.isReady())&&K.delete($t)}),K.size===0){j(b);return}setTimeout(kt,10)}re.get("KHR_parallel_shader_compile")!==null?kt():setTimeout(kt,10)})};let jn=null;function gs(b){jn&&jn(b)}function po(){Vn.stop()}function fi(){Vn.start()}let Vn=new af;Vn.setAnimationLoop(gs),typeof self<"u"&&Vn.setContext(self),this.setAnimationLoop=function(b){jn=b,wt.setAnimationLoop(b),b===null?Vn.stop():Vn.start()},wt.addEventListener("sessionstart",po),wt.addEventListener("sessionend",fi),this.render=function(b,H){if(H!==void 0&&H.isCamera!==!0){he("WebGLRenderer.render: camera is not an instance of THREE.Camera.");return}if(N===!0)return;P!==null&&P.renderStart(b,H);let J=wt.enabled===!0&&wt.isPresenting===!0,K=C!==null&&(dt===null||J)&&C.begin(L,dt);if(b.matrixWorldAutoUpdate===!0&&b.updateMatrixWorld(),H.parent===null&&H.matrixWorldAutoUpdate===!0&&H.updateMatrixWorld(),wt.enabled===!0&&wt.isPresenting===!0&&(C===null||C.isCompositing()===!1)&&(wt.cameraAutoUpdate===!0&&wt.updateCamera(H),H=wt.getCamera()),b.isScene===!0&&b.onBeforeRender(L,b,H,dt),M=Tt.get(b,v.length),M.init(H),M.state.textureUnits=at.getTextureUnits(),v.push(M),gt.multiplyMatrices(H.projectionMatrix,H.matrixWorldInverse),V.setFromProjectionMatrix(gt,ai,H.reversedDepth),xt=this.localClippingEnabled,ut=Xt.init(this.clippingPlanes,xt),E=Nt.get(b,I.length),E.init(),I.push(E),wt.enabled===!0&&wt.isPresenting===!0){let $t=L.xr.getDepthSensingMesh();$t!==null&&de($t,H,-1/0,L.sortObjects)}de(b,H,0,L.sortObjects),E.finish(),P!==null&&P.updateLights(M.state.lightsArray),L.sortObjects===!0&&E.sort(_t,bt),Zt=wt.enabled===!1||wt.isPresenting===!1||wt.hasDepthSensing()===!1,Zt&&le.addToRenderList(E,b),this.info.render.frame++,this.info.autoReset===!0&&this.info.reset(),ut===!0&&Xt.beginShadows();let j=M.state.shadowsArray;if(Jt.render(j,b,H),ut===!0&&Xt.endShadows(),(K&&C.hasRenderPass())===!1){let $t=E.opaque,Lt=E.transmissive;if(M.setupLights(),H.isArrayCamera){let Kt=H.cameras;if(Lt.length>0)for(let qt=0,pe=Kt.length;qt<pe;qt++){let ye=Kt[qt];$i($t,Lt,b,ye)}Zt&&le.render(b);for(let qt=0,pe=Kt.length;qt<pe;qt++){let ye=Kt[qt];Ti(E,b,ye,ye.viewport)}}else Lt.length>0&&$i($t,Lt,b,H),Zt&&le.render(b),Ti(E,b,H)}dt!==null&&nt===0&&(at.updateMultisampleRenderTarget(dt),at.updateRenderTargetMipmap(dt)),K&&C.end(L),b.isScene===!0&&b.onAfterRender(L,b,H),ht.resetDefaultState(),Q=-1,ct=null,v.pop(),v.length>0?(M=v[v.length-1],at.setTextureUnits(M.state.textureUnits),ut===!0&&Xt.setGlobalState(L.clippingPlanes,M.state.camera)):M=null,I.pop(),I.length>0?E=I[I.length-1]:E=null,P!==null&&P.renderEnd()};function de(b,H,J,K){if(b.visible===!1)return;if(b.layers.test(H.layers)){if(b.isGroup)J=b.renderOrder;else if(b.isLOD)b.autoUpdate===!0&&b.update(H);else if(b.isLightProbeGrid)M.pushLightProbeGrid(b);else if(b.isLight)M.pushLight(b),b.castShadow&&M.pushShadow(b);else if(b.isSprite){if(!b.frustumCulled||b.intersectsFrustum(V)){K&&Bt.setFromMatrixPosition(b.matrixWorld).applyMatrix4(gt);let $t=ft.update(b),Lt=b.material;Lt.visible&&E.push(b,$t,Lt,J,Bt.z,null,H)}}else if((b.isMesh||b.isLine||b.isPoints)&&(!b.frustumCulled||b.intersectsFrustum(V))){let $t=ft.update(b),Lt=b.material;if(K&&(b.boundingSphere!==void 0?(b.boundingSphere===null&&b.computeBoundingSphere(),Bt.copy(b.boundingSphere.center)):($t.boundingSphere===null&&$t.computeBoundingSphere(),Bt.copy($t.boundingSphere.center)),Bt.applyMatrix4(b.matrixWorld).applyMatrix4(gt)),Array.isArray(Lt)){let Kt=$t.groups;for(let qt=0,pe=Kt.length;qt<pe;qt++){let ye=Kt[qt],jt=Lt[ye.materialIndex];jt&&jt.visible&&E.push(b,$t,jt,J,Bt.z,ye,H)}}else Lt.visible&&E.push(b,$t,Lt,J,Bt.z,null,H)}}let kt=b.children;for(let $t=0,Lt=kt.length;$t<Lt;$t++)de(kt[$t],H,J,K)}function Ti(b,H,J,K){let{opaque:j,transmissive:kt,transparent:$t}=b;M.setupLightsView(J),ut===!0&&Xt.setGlobalState(L.clippingPlanes,J),K&&x.viewport(O.copy(K)),j.length>0&&_n(j,H,J),kt.length>0&&_n(kt,H,J),$t.length>0&&_n($t,H,J),x.buffers.depth.setTest(!0),x.buffers.depth.setMask(!0),x.buffers.color.setMask(!0),x.setPolygonOffset(!1)}function $i(b,H,J,K){if((J.isScene===!0?J.overrideMaterial:null)!==null)return;if(M.state.transmissionRenderTarget[K.id]===void 0){let jt=re.has("EXT_color_buffer_half_float")||re.has("EXT_color_buffer_float");M.state.transmissionRenderTarget[K.id]=new Ke(1,1,{generateMipmaps:!0,type:jt?ln:Nn,minFilter:Si,samples:Math.max(4,A.samples),stencilBuffer:r,resolveDepthBuffer:!1,resolveStencilBuffer:!1,storeMultisampledDepthBuffer:!1,storeMultisampledStencilBuffer:!1,colorSpace:Se.workingColorSpace})}let kt=M.state.transmissionRenderTarget[K.id],$t=K.viewport||O;kt.setSize($t.z*L.transmissionResolutionScale,$t.w*L.transmissionResolutionScale);let Lt=L.getRenderTarget(),Kt=L.getActiveCubeFace(),qt=L.getActiveMipmapLevel();L.setRenderTarget(kt),L.getClearColor(At),Ot=L.getClearAlpha(),Ot<1&&L.setClearColor(16777215,.5),L.clear(),Zt&&le.render(J);let pe=L.toneMapping;L.toneMapping=ci;let ye=K.viewport;if(K.viewport!==void 0&&(K.viewport=void 0),M.setupLightsView(K),ut===!0&&Xt.setGlobalState(L.clippingPlanes,K),_n(b,J,K),at.updateMultisampleRenderTarget(kt),at.updateRenderTargetMipmap(kt),re.has("WEBGL_multisampled_render_to_texture")===!1){let jt=!1;for(let ge=0,Ie=H.length;ge<Ie;ge++){let He=H[ge],{object:Ne,geometry:sn,material:Yt,group:un}=He;if(Yt.side===Sn&&Ne.layers.test(K.layers)){let we=Yt.side;Yt.side=bn,Yt.needsUpdate=!0,xs(Ne,J,K,sn,Yt,un),Yt.side=we,Yt.needsUpdate=!0,jt=!0}}jt===!0&&(at.updateMultisampleRenderTarget(kt),at.updateRenderTargetMipmap(kt))}L.setRenderTarget(Lt,Kt,qt),L.setClearColor(At,Ot),ye!==void 0&&(K.viewport=ye),L.toneMapping=pe}function _n(b,H,J){let K=H.isScene===!0?H.overrideMaterial:null;for(let j=0,kt=b.length;j<kt;j++){let $t=b[j],{object:Lt,geometry:Kt,group:qt}=$t,pe=$t.material;pe.allowOverride===!0&&K!==null&&(pe=K),Lt.layers.test(J.layers)&&xs(Lt,H,J,Kt,pe,qt)}}function xs(b,H,J,K,j,kt){P!==null&&j.isNodeMaterial&&P.setObject(b,j),b.onBeforeRender(L,H,J,K,j,kt),b.modelViewMatrix.multiplyMatrices(J.matrixWorldInverse,b.matrixWorld),b.normalMatrix.getNormalMatrix(b.modelViewMatrix),j.onBeforeRender(L,H,J,K,b,kt),j.transparent===!0&&j.side===Sn&&j.forceSinglePass===!1?(j.side=bn,j.needsUpdate=!0,L.renderBufferDirect(J,H,K,j,b,kt),j.side=hs,j.needsUpdate=!0,L.renderBufferDirect(J,H,K,j,b,kt),j.side=Sn):L.renderBufferDirect(J,H,K,j,b,kt),b.onAfterRender(L,H,J,K,j,kt)}function Ls(b,H,J){H.isScene!==!0&&(H=Ut);let K=Y.get(b),j=M.state.lights,kt=M.state.shadowsArray,$t=j.state.version,Lt=Pt.getParameters(b,j.state,kt,H,J,M.state.lightProbeGridArray),Kt=Pt.getProgramCacheKey(Lt),qt=K.programs;K.environment=b.isMeshStandardMaterial||b.isMeshLambertMaterial||b.isMeshPhongMaterial?H.environment:null,K.fog=H.fog;let pe=b.isMeshStandardMaterial||b.isMeshLambertMaterial&&!b.envMap||b.isMeshPhongMaterial&&!b.envMap;K.envMap=Mt.get(b.envMap||K.environment,pe),K.envMapRotation=K.environment!==null&&b.envMap===null?H.environmentRotation:b.envMapRotation,qt===void 0&&(b.addEventListener("dispose",ke),qt=new Map,K.programs=qt);let ye=qt.get(Kt);if(ye!==void 0){if(K.currentProgram===ye&&K.lightsStateVersion===$t)return go(b,Lt),ye}else Lt.uniforms=Pt.getUniforms(b),P!==null&&b.isNodeMaterial&&P.build(b,J,Lt),b.onBeforeCompile(Lt,L),ye=Pt.acquireProgram(Lt,Kt),qt.set(Kt,ye),K.uniforms=Lt.uniforms;let jt=K.uniforms;return(!b.isShaderMaterial&&!b.isRawShaderMaterial||b.clipping===!0)&&(jt.clippingPlanes=Xt.uniform),go(b,Lt),K.needsLights=Kc(b),K.lightsStateVersion=$t,K.needsLights&&(jt.ambientLightColor.value=j.state.ambient,jt.lightProbe.value=j.state.probe,jt.sunLights.value=j.state.sun,jt.sunLightShadows.value=j.state.sunShadow,jt.directionalLights.value=j.state.directional,jt.directionalLightShadows.value=j.state.directionalShadow,jt.spotLights.value=j.state.spot,jt.spotLightShadows.value=j.state.spotShadow,jt.rectAreaLights.value=j.state.rectArea,jt.ltc_1.value=j.state.rectAreaLTC1,jt.ltc_2.value=j.state.rectAreaLTC2,jt.pointLights.value=j.state.point,jt.pointLightShadows.value=j.state.pointShadow,jt.hemisphereLights.value=j.state.hemi,jt.sunShadowMatrix.value=j.state.sunShadowMatrix,jt.sunShadowCascade.value=j.state.sunShadowCascade,jt.directionalShadowMatrix.value=j.state.directionalShadowMatrix,jt.spotLightMatrix.value=j.state.spotLightMatrix,jt.spotLightMap.value=j.state.spotLightMap,jt.pointShadowMatrix.value=j.state.pointShadowMatrix),K.lightProbeGrid=M.state.lightProbeGridArray.length>0,K.currentProgram=ye,K.uniformsList=null,ye}function mo(b){if(b.uniformsList===null){let H=b.currentProgram.getUniforms();b.uniformsList=Pr.seqWithValue(H.seq,b.uniforms)}return b.uniformsList}function go(b,H){let J=Y.get(b);J.outputColorSpace=H.outputColorSpace,J.batching=H.batching,J.batchingColor=H.batchingColor,J.instancing=H.instancing,J.instancingColor=H.instancingColor,J.instancingMorph=H.instancingMorph,J.skinning=H.skinning,J.morphTargets=H.morphTargets,J.morphNormals=H.morphNormals,J.morphColors=H.morphColors,J.morphTargetsCount=H.morphTargetsCount,J.numClippingPlanes=H.numClippingPlanes,J.numIntersection=H.numClipIntersection,J.vertexAlphas=H.vertexAlphas,J.vertexTangents=H.vertexTangents,J.toneMapping=H.toneMapping}function Zc(b,H){if(b.length===0)return null;if(b.length===1)return b[0].texture!==null?b[0]:null;y.setFromMatrixPosition(H.matrixWorld);for(let J=0,K=b.length;J<K;J++){let j=b[J];if(j.texture!==null&&j.boundingBox.containsPoint(y))return j}return null}function Jc(b,H,J,K,j){H.isScene!==!0&&(H=Ut),at.resetTextureUnits();let kt=H.fog,$t=K.isMeshStandardMaterial||K.isMeshLambertMaterial||K.isMeshPhongMaterial?H.environment:null,Lt=dt===null?L.outputColorSpace:dt.isXRRenderTarget===!0?dt.texture.colorSpace:Se.workingColorSpace,Kt=K.isMeshStandardMaterial||K.isMeshLambertMaterial&&!K.envMap||K.isMeshPhongMaterial&&!K.envMap,qt=Mt.get(K.envMap||$t,Kt),pe=K.vertexColors===!0&&!!J.attributes.color&&J.attributes.color.itemSize===4,ye=!!J.attributes.tangent&&(!!K.normalMap||K.anisotropy>0),jt=!!J.morphAttributes.position,ge=!!J.morphAttributes.normal,Ie=!!J.morphAttributes.color,He=ci;K.toneMapped&&(dt===null||dt.isXRRenderTarget===!0)&&(He=L.toneMapping);let Ne=J.morphAttributes.position||J.morphAttributes.normal||J.morphAttributes.color,sn=Ne!==void 0?Ne.length:0,Yt=Y.get(K),un=M.state.lights;if(ut===!0&&(xt===!0||b!==ct)){let Ve=b===ct&&K.id===Q;Xt.setState(K,b,Ve)}let we=!1;K.version===Yt.__version?(Yt.needsLights&&Yt.lightsStateVersion!==un.state.version||Yt.outputColorSpace!==Lt||j.isBatchedMesh&&Yt.batching===!1||!j.isBatchedMesh&&Yt.batching===!0||j.isBatchedMesh&&Yt.batchingColor===!0&&j._colorsTexture===null||j.isBatchedMesh&&Yt.batchingColor===!1&&j._colorsTexture!==null||j.isInstancedMesh&&Yt.instancing===!1||!j.isInstancedMesh&&Yt.instancing===!0||j.isSkinnedMesh&&Yt.skinning===!1||!j.isSkinnedMesh&&Yt.skinning===!0||j.isInstancedMesh&&Yt.instancingColor===!0&&j.instanceColor===null||j.isInstancedMesh&&Yt.instancingColor===!1&&j.instanceColor!==null||j.isInstancedMesh&&Yt.instancingMorph===!0&&j.morphTexture===null||j.isInstancedMesh&&Yt.instancingMorph===!1&&j.morphTexture!==null||Yt.envMap!==qt||K.fog===!0&&Yt.fog!==kt||Yt.numClippingPlanes!==void 0&&(Yt.numClippingPlanes!==Xt.numPlanes||Yt.numIntersection!==Xt.numIntersection)||Yt.vertexAlphas!==pe||Yt.vertexTangents!==ye||Yt.morphTargets!==jt||Yt.morphNormals!==ge||Yt.morphColors!==Ie||Yt.toneMapping!==He||Yt.morphTargetsCount!==sn||!!Yt.lightProbeGrid!=M.state.lightProbeGridArray.length>0)&&(we=!0):(we=!0,Yt.__version=K.version);let In=Yt.currentProgram;we===!0&&(In=Ls(K,H,j),P&&K.isNodeMaterial&&P.onUpdateProgram(K,In,Yt));let Dn=!1,Qn=!1,Ai=!1,Pe=In.getUniforms(),Re=Yt.uniforms;if(x.useProgram(In.program)&&(Dn=!0,Qn=!0,Ai=!0),K.id!==Q&&(Q=K.id,Qn=!0),Yt.needsLights){let Ve=Zc(M.state.lightProbeGridArray,j);Yt.lightProbeGrid!==Ve&&(Yt.lightProbeGrid=Ve,Qn=!0)}if(Dn||ct!==b){x.buffers.depth.getReversed()&&b.reversedDepth!==!0&&(b._reversedDepth=!0,b.updateProjectionMatrix()),Pe.setValue(U,"projectionMatrix",b.projectionMatrix),Pe.setValue(U,"viewMatrix",b.matrixWorldInverse);let pi=Pe.map.cameraPosition;pi!==void 0&&pi.setValue(U,yt.setFromMatrixPosition(b.matrixWorld)),A.logarithmicDepthBuffer&&Pe.setValue(U,"logDepthBufFC",2/(Math.log(b.far+1)/Math.LN2)),(K.isMeshPhongMaterial||K.isMeshToonMaterial||K.isMeshLambertMaterial||K.isMeshBasicMaterial||K.isMeshStandardMaterial||K.isShaderMaterial)&&Pe.setValue(U,"isOrthographic",b.isOrthographicCamera===!0),ct!==b&&(ct=b,Qn=!0,Ai=!0)}if(Yt.needsLights&&(un.state.sunShadowMap.length>0&&Pe.setValue(U,"sunShadowMap",un.state.sunShadowMap,at),un.state.directionalShadowMap.length>0&&Pe.setValue(U,"directionalShadowMap",un.state.directionalShadowMap,at),un.state.spotShadowMap.length>0&&Pe.setValue(U,"spotShadowMap",un.state.spotShadowMap,at),un.state.pointShadowMap.length>0&&Pe.setValue(U,"pointShadowMap",un.state.pointShadowMap,at)),j.isSkinnedMesh){Pe.setOptional(U,j,"bindMatrix"),Pe.setOptional(U,j,"bindMatrixInverse");let Ve=j.skeleton;Ve&&(Ve.boneTexture===null&&Ve.computeBoneTexture(),Pe.setValue(U,"boneTexture",Ve.boneTexture,at))}j.isBatchedMesh&&(Pe.setOptional(U,j,"batchingTexture"),Pe.setValue(U,"batchingTexture",j._matricesTexture,at),Pe.setOptional(U,j,"batchingIdTexture"),Pe.setValue(U,"batchingIdTexture",j._indirectTexture,at),Pe.setOptional(U,j,"batchingColorTexture"),j._colorsTexture!==null&&Pe.setValue(U,"batchingColorTexture",j._colorsTexture,at));let ti=J.morphAttributes;if((ti.position!==void 0||ti.normal!==void 0||ti.color!==void 0)&&z.update(j,J,In),(Qn||Yt.receiveShadow!==j.receiveShadow)&&(Yt.receiveShadow=j.receiveShadow,Pe.setValue(U,"receiveShadow",j.receiveShadow)),(K.isMeshStandardMaterial||K.isMeshLambertMaterial||K.isMeshPhongMaterial)&&K.envMap===null&&H.environment!==null&&(Re.envMapIntensity.value=H.environmentIntensity),Re.dfgLUT!==void 0&&(Re.dfgLUT.value=l3()),Qn){if(Pe.setValue(U,"toneMappingExposure",L.toneMappingExposure),Yt.needsLights&&Ns(Re,Ai),kt&&K.fog===!0&&Ht.refreshFogUniforms(Re,kt),Ht.refreshMaterialUniforms(Re,K,it,tt,M.state.transmissionRenderTarget[b.id]),Yt.needsLights&&Yt.lightProbeGrid){let Ve=Yt.lightProbeGrid;Re.probesSH.value=Ve.texture,Re.probesMin.value.copy(Ve.boundingBox.min),Re.probesMax.value.copy(Ve.boundingBox.max),Re.probesResolution.value.copy(Ve.resolution)}Pr.upload(U,mo(Yt),Re,at)}if(K.isShaderMaterial&&K.uniformsNeedUpdate===!0&&(Pr.upload(U,mo(Yt),Re,at),K.uniformsNeedUpdate=!1),K.isSpriteMaterial&&Pe.setValue(U,"center",j.center),Pe.setValue(U,"modelViewMatrix",j.modelViewMatrix),Pe.setValue(U,"normalMatrix",j.normalMatrix),Pe.setValue(U,"modelMatrix",j.matrixWorld),K.uniformsGroups!==void 0){let Ve=K.uniformsGroups;for(let pi=0,qi=Ve.length;pi<qi;pi++){let je=Ve[pi];X.update(je,In),X.bind(je,In)}}return In}function Ns(b,H){b.ambientLightColor.needsUpdate=H,b.lightProbe.needsUpdate=H,b.sunLights.needsUpdate=H,b.sunLightShadows.needsUpdate=H,b.directionalLights.needsUpdate=H,b.directionalLightShadows.needsUpdate=H,b.pointLights.needsUpdate=H,b.pointLightShadows.needsUpdate=H,b.spotLights.needsUpdate=H,b.spotLightShadows.needsUpdate=H,b.rectAreaLights.needsUpdate=H,b.hemisphereLights.needsUpdate=H}function Kc(b){return b.isMeshLambertMaterial||b.isMeshToonMaterial||b.isMeshPhongMaterial||b.isMeshStandardMaterial||b.isShadowMaterial||b.isShaderMaterial&&b.lights===!0}this.getActiveCubeFace=function(){return rt},this.getActiveMipmapLevel=function(){return nt},this.getRenderTarget=function(){return dt},this.setRenderTargetTextures=function(b,H,J){let K=Y.get(b);K.__autoAllocateDepthBuffer=b.resolveDepthBuffer===!1,K.__autoAllocateDepthBuffer===!1&&(K.__useRenderToTexture=!1),Y.get(b.texture).__webglTexture=H,Y.get(b.depthTexture).__webglTexture=K.__autoAllocateDepthBuffer?void 0:J,K.__hasExternalTextures=!0},this.setRenderTargetFramebuffer=function(b,H){let J=Y.get(b);J.__webglFramebuffer=H,J.__useDefaultFramebuffer=H===void 0},this.setRenderTarget=function(b,H=0,J=0){dt=b,rt=H,nt=J;let K=null,j=!1,kt=!1;if(b){let Lt=Y.get(b);if(Lt.__useDefaultFramebuffer!==void 0){x.bindFramebuffer(U.FRAMEBUFFER,Lt.__webglFramebuffer),O.copy(b.viewport),St.copy(b.scissor),Et=b.scissorTest,x.viewport(O),x.scissor(St),x.setScissorTest(Et),Q=-1;return}else if(Lt.__webglFramebuffer===void 0)at.setupRenderTarget(b);else if(Lt.__hasExternalTextures)at.rebindTextures(b,Y.get(b.texture).__webglTexture,Y.get(b.depthTexture).__webglTexture);else if(b.depthBuffer){let pe=b.depthTexture;if(Lt.__boundDepthTexture!==pe){if(pe!==null&&Y.has(pe)&&(b.width!==pe.image.width||b.height!==pe.image.height))throw new Error("THREE.WebGLRenderer: Attached DepthTexture is initialized to the incorrect size.");at.setupDepthRenderbuffer(b)}}let Kt=b.texture;(Kt.isData3DTexture||Kt.isDataArrayTexture||Kt.isCompressedArrayTexture)&&(kt=!0);let qt=Y.get(b).__webglFramebuffer;b.isWebGLCubeRenderTarget?(Array.isArray(qt[H])?K=qt[H][J]:K=qt[H],j=!0):b.samples>0&&at.useMultisampledRTT(b)===!1?K=Y.get(b).__webglMultisampledFramebuffer:Array.isArray(qt)?K=qt[J]:K=qt,O.copy(b.viewport),St.copy(b.scissor),Et=b.scissorTest}else O.copy(mt).multiplyScalar(it).floor(),St.copy(Ct).multiplyScalar(it).floor(),Et=Qt;if(J!==0&&(K=B),x.bindFramebuffer(U.FRAMEBUFFER,K)&&x.drawBuffers(b,K),x.viewport(O),x.scissor(St),x.setScissorTest(Et),j){let Lt=Y.get(b.texture);U.framebufferTexture2D(U.FRAMEBUFFER,U.COLOR_ATTACHMENT0,U.TEXTURE_CUBE_MAP_POSITIVE_X+H,Lt.__webglTexture,J)}else if(kt){let Lt=H;for(let Kt=0;Kt<b.textures.length;Kt++){let qt=Y.get(b.textures[Kt]);U.framebufferTextureLayer(U.FRAMEBUFFER,U.COLOR_ATTACHMENT0+Kt,qt.__webglTexture,J,Lt)}}else if(b!==null&&J!==0){let Lt=Y.get(b.texture);U.framebufferTexture2D(U.FRAMEBUFFER,U.COLOR_ATTACHMENT0,U.TEXTURE_2D,Lt.__webglTexture,J)}Q=-1};function xo(b){let H=Y.get(b);return(H.__readFormat!==b.format||H.__readType!==b.type)&&(H.__readFormat=b.format,H.__readType=b.type,H.__formatReadable=A.textureFormatReadable(b.format),H.__typeReadable=A.textureTypeReadable(b.type)),H}this.readRenderTargetPixels=function(b,H,J,K,j,kt,$t,Lt=0){if(!(b&&b.isWebGLRenderTarget)){he("WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");return}let Kt=Y.get(b).__webglFramebuffer;if(b.isWebGLCubeRenderTarget&&$t!==void 0&&(Kt=Kt[$t]),Kt){x.bindFramebuffer(U.FRAMEBUFFER,Kt);try{let qt=b.textures[Lt],pe=qt.format,ye=qt.type;b.textures.length>1&&U.readBuffer(U.COLOR_ATTACHMENT0+Lt);let jt=xo(qt);if(jt.__formatReadable===!1){he("WebGLRenderer.readRenderTargetPixels: renderTarget is not in RGBA or implementation defined format.");return}if(jt.__typeReadable===!1){he("WebGLRenderer.readRenderTargetPixels: renderTarget is not in UnsignedByteType or implementation defined type.");return}H>=0&&H<=b.width-K&&J>=0&&J<=b.height-j&&U.readPixels(H,J,K,j,q.convert(pe),q.convert(ye),kt)}finally{let qt=dt!==null?Y.get(dt).__webglFramebuffer:null;x.bindFramebuffer(U.FRAMEBUFFER,qt)}}},this.readRenderTargetPixelsAsync=async function(b,H,J,K,j,kt,$t,Lt=0){if(!(b&&b.isWebGLRenderTarget))throw new Error("THREE.WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.");let Kt=Y.get(b).__webglFramebuffer;if(b.isWebGLCubeRenderTarget&&$t!==void 0&&(Kt=Kt[$t]),Kt)if(H>=0&&H<=b.width-K&&J>=0&&J<=b.height-j){x.bindFramebuffer(U.FRAMEBUFFER,Kt);let qt=b.textures[Lt],pe=qt.format,ye=qt.type;b.textures.length>1&&U.readBuffer(U.COLOR_ATTACHMENT0+Lt);let jt=xo(qt);if(jt.__formatReadable===!1)throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in RGBA or implementation defined format.");if(jt.__typeReadable===!1)throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in UnsignedByteType or implementation defined type.");let ge=U.createBuffer();U.bindBuffer(U.PIXEL_PACK_BUFFER,ge),U.bufferData(U.PIXEL_PACK_BUFFER,kt.byteLength,U.STREAM_READ),U.readPixels(H,J,K,j,q.convert(pe),q.convert(ye),0),U.bindBuffer(U.PIXEL_PACK_BUFFER,null);let Ie=dt!==null?Y.get(dt).__webglFramebuffer:null;x.bindFramebuffer(U.FRAMEBUFFER,Ie);let He=U.fenceSync(U.SYNC_GPU_COMMANDS_COMPLETE,0);return U.flush(),await Rd(U,He,4),U.bindBuffer(U.PIXEL_PACK_BUFFER,ge),U.getBufferSubData(U.PIXEL_PACK_BUFFER,0,kt),U.bindBuffer(U.PIXEL_PACK_BUFFER,null),U.deleteBuffer(ge),U.deleteSync(He),kt}else throw new Error("THREE.WebGLRenderer.readRenderTargetPixelsAsync: requested read bounds are out of range.")},this.copyFramebufferToTexture=function(b,H=null,J=0){let K=Math.pow(2,-J),j=Math.floor(b.image.width*K),kt=Math.floor(b.image.height*K),$t=H!==null?H.x:0,Lt=H!==null?H.y:0;at.setTexture2D(b,0),U.copyTexSubImage2D(U.TEXTURE_2D,J,0,0,$t,Lt,j,kt),x.unbindTexture()},this.copyTextureToTexture=function(b,H,J=null,K=null,j=0,kt=0){let $t,Lt,Kt,qt,pe,ye,jt,ge,Ie,He=b.isCompressedTexture?b.mipmaps[kt]:b.image;if(J!==null)$t=J.max.x-J.min.x,Lt=J.max.y-J.min.y,Kt=J.isBox3?J.max.z-J.min.z:1,qt=J.min.x,pe=J.min.y,ye=J.isBox3?J.min.z:0;else{let Re=Math.pow(2,-j);$t=Math.floor(He.width*Re),Lt=Math.floor(He.height*Re),b.isDataArrayTexture?Kt=He.depth:b.isData3DTexture?Kt=Math.floor(He.depth*Re):Kt=1,qt=0,pe=0,ye=0}K!==null?(jt=K.x,ge=K.y,Ie=K.z):(jt=0,ge=0,Ie=0);let Ne=q.convert(H.format),sn=q.convert(H.type),Yt;H.isData3DTexture?(at.setTexture3D(H,0),Yt=U.TEXTURE_3D):H.isDataArrayTexture||H.isCompressedArrayTexture?(at.setTexture2DArray(H,0),Yt=U.TEXTURE_2D_ARRAY):(at.setTexture2D(H,0),Yt=U.TEXTURE_2D),x.activeTexture(U.TEXTURE0),x.pixelStorei(U.UNPACK_FLIP_Y_WEBGL,H.flipY),x.pixelStorei(U.UNPACK_PREMULTIPLY_ALPHA_WEBGL,H.premultiplyAlpha),x.pixelStorei(U.UNPACK_ALIGNMENT,H.unpackAlignment);let un=x.getParameter(U.UNPACK_ROW_LENGTH),we=x.getParameter(U.UNPACK_IMAGE_HEIGHT),In=x.getParameter(U.UNPACK_SKIP_PIXELS),Dn=x.getParameter(U.UNPACK_SKIP_ROWS),Qn=x.getParameter(U.UNPACK_SKIP_IMAGES);x.pixelStorei(U.UNPACK_ROW_LENGTH,He.width),x.pixelStorei(U.UNPACK_IMAGE_HEIGHT,He.height),x.pixelStorei(U.UNPACK_SKIP_PIXELS,qt),x.pixelStorei(U.UNPACK_SKIP_ROWS,pe),x.pixelStorei(U.UNPACK_SKIP_IMAGES,ye);let Ai=b.isDataArrayTexture||b.isData3DTexture,Pe=H.isDataArrayTexture||H.isData3DTexture;if(b.isDepthTexture){let Re=Y.get(b),ti=Y.get(H),Ve=Y.get(Re.__renderTarget),pi=Y.get(ti.__renderTarget);x.bindFramebuffer(U.READ_FRAMEBUFFER,Ve.__webglFramebuffer),x.bindFramebuffer(U.DRAW_FRAMEBUFFER,pi.__webglFramebuffer);for(let qi=0;qi<Kt;qi++)Ai&&(U.framebufferTextureLayer(U.READ_FRAMEBUFFER,U.COLOR_ATTACHMENT0,Y.get(b).__webglTexture,j,ye+qi),U.framebufferTextureLayer(U.DRAW_FRAMEBUFFER,U.COLOR_ATTACHMENT0,Y.get(H).__webglTexture,kt,Ie+qi)),U.blitFramebuffer(qt,pe,$t,Lt,jt,ge,$t,Lt,U.DEPTH_BUFFER_BIT,U.NEAREST);x.bindFramebuffer(U.READ_FRAMEBUFFER,null),x.bindFramebuffer(U.DRAW_FRAMEBUFFER,null)}else if(j!==0||b.isRenderTargetTexture||Y.has(b)){let Re=Y.get(b),ti=Y.get(H);x.bindFramebuffer(U.READ_FRAMEBUFFER,F),x.bindFramebuffer(U.DRAW_FRAMEBUFFER,W);for(let Ve=0;Ve<Kt;Ve++)Ai?U.framebufferTextureLayer(U.READ_FRAMEBUFFER,U.COLOR_ATTACHMENT0,Re.__webglTexture,j,ye+Ve):U.framebufferTexture2D(U.READ_FRAMEBUFFER,U.COLOR_ATTACHMENT0,U.TEXTURE_2D,Re.__webglTexture,j),Pe?U.framebufferTextureLayer(U.DRAW_FRAMEBUFFER,U.COLOR_ATTACHMENT0,ti.__webglTexture,kt,Ie+Ve):U.framebufferTexture2D(U.DRAW_FRAMEBUFFER,U.COLOR_ATTACHMENT0,U.TEXTURE_2D,ti.__webglTexture,kt),j!==0?U.blitFramebuffer(qt,pe,$t,Lt,jt,ge,$t,Lt,U.COLOR_BUFFER_BIT,U.NEAREST):Pe?U.copyTexSubImage3D(Yt,kt,jt,ge,Ie+Ve,qt,pe,$t,Lt):U.copyTexSubImage2D(Yt,kt,jt,ge,qt,pe,$t,Lt);x.bindFramebuffer(U.READ_FRAMEBUFFER,null),x.bindFramebuffer(U.DRAW_FRAMEBUFFER,null)}else Pe?b.isDataTexture||b.isData3DTexture?U.texSubImage3D(Yt,kt,jt,ge,Ie,$t,Lt,Kt,Ne,sn,He.data):H.isCompressedArrayTexture?U.compressedTexSubImage3D(Yt,kt,jt,ge,Ie,$t,Lt,Kt,Ne,He.data):U.texSubImage3D(Yt,kt,jt,ge,Ie,$t,Lt,Kt,Ne,sn,He):b.isDataTexture?U.texSubImage2D(U.TEXTURE_2D,kt,jt,ge,$t,Lt,Ne,sn,He.data):b.isCompressedTexture?U.compressedTexSubImage2D(U.TEXTURE_2D,kt,jt,ge,He.width,He.height,Ne,He.data):U.texSubImage2D(U.TEXTURE_2D,kt,jt,ge,$t,Lt,Ne,sn,He);x.pixelStorei(U.UNPACK_ROW_LENGTH,un),x.pixelStorei(U.UNPACK_IMAGE_HEIGHT,we),x.pixelStorei(U.UNPACK_SKIP_PIXELS,In),x.pixelStorei(U.UNPACK_SKIP_ROWS,Dn),x.pixelStorei(U.UNPACK_SKIP_IMAGES,Qn),kt===0&&H.generateMipmaps&&U.generateMipmap(Yt),x.unbindTexture()},this.initRenderTarget=function(b){Y.get(b).__webglFramebuffer===void 0&&at.setupRenderTarget(b)},this.initTexture=function(b){b.isCubeTexture?at.setTextureCube(b,0):b.isData3DTexture?at.setTexture3D(b,0):b.isDataArrayTexture||b.isCompressedArrayTexture?at.setTexture2DArray(b,0):at.setTexture2D(b,0),x.unbindTexture()},this.resetState=function(){rt=0,nt=0,dt=null,x.reset(),ht.reset()},typeof __THREE_DEVTOOLS__<"u"&&__THREE_DEVTOOLS__.dispatchEvent(new CustomEvent("observe",{detail:this}))}get coordinateSystem(){return ai}get outputColorSpace(){return this._outputColorSpace}set outputColorSpace(t){this._outputColorSpace=t;let e=this.getContext();e.drawingBufferColorSpace=Se._getDrawingBufferColorSpace(t),e.unpackColorSpace=Se._getUnpackColorSpace()}};var Nr={name:"CopyShader",uniforms:{tDiffuse:{value:null},opacity:{value:1}},vertexShader:`

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


		}`};var Hn=class{constructor(){this.isPass=!0,this.enabled=!0,this.needsSwap=!0,this.clear=!1,this.renderToScreen=!1}setSize(){}render(){console.error("THREE.Pass: .render() must be implemented in derived pass.")}dispose(){}},c3=new cs(-1,1,1,-1,0,1),Ah=class extends Ae{constructor(){super(),this.setAttribute("position",new fe([-1,3,0,-1,-1,0,3,-1,0],3)),this.setAttribute("uv",new fe([0,2,0,0,2,0],2))}},h3=new Ah,ms=class{constructor(t){this._mesh=new ve(h3,t)}dispose(){this._mesh.geometry.dispose()}render(t){t.render(this._mesh,c3)}get material(){return this._mesh.material}set material(t){this._mesh.material=t}};var Pc=class extends Hn{constructor(t,e="tDiffuse"){super(),this.textureID=e,this.uniforms=null,this.material=null,t instanceof Oe?(this.uniforms=t.uniforms,this.material=t):t&&(this.uniforms=Xi.clone(t.uniforms),this.material=new Oe({name:t.name!==void 0?t.name:"unspecified",defines:Object.assign({},t.defines),uniforms:this.uniforms,vertexShader:t.vertexShader,fragmentShader:t.fragmentShader})),this._fsQuad=new ms(this.material)}render(t,e,n){this.uniforms[this.textureID]&&(this.uniforms[this.textureID].value=n.texture),this._fsQuad.material=this.material,this.renderToScreen?(t.setRenderTarget(null),this._fsQuad.render(t)):(t.setRenderTarget(e),this.clear&&t.clear(t.autoClearColor,t.autoClearDepth,t.autoClearStencil),this._fsQuad.render(t))}dispose(){this.material.dispose(),this._fsQuad.dispose()}};var lo=class extends Hn{constructor(t,e){super(),this.scene=t,this.camera=e,this.clear=!0,this.needsSwap=!1,this.inverse=!1}render(t,e,n){let s=t.getContext(),r=t.state;r.buffers.color.setMask(!1),r.buffers.depth.setMask(!1),r.buffers.color.setLocked(!0),r.buffers.depth.setLocked(!0);let a,o;this.inverse?(a=0,o=1):(a=1,o=0),r.buffers.stencil.setTest(!0),r.buffers.stencil.setOp(s.REPLACE,s.REPLACE,s.REPLACE),r.buffers.stencil.setFunc(s.ALWAYS,a,4294967295),r.buffers.stencil.setClear(o),r.buffers.stencil.setLocked(!0),t.setRenderTarget(n),this.clear&&t.clear(),t.render(this.scene,this.camera),t.setRenderTarget(e),this.clear&&t.clear(),t.render(this.scene,this.camera),r.buffers.color.setLocked(!1),r.buffers.depth.setLocked(!1),r.buffers.color.setMask(!0),r.buffers.depth.setMask(!0),r.buffers.stencil.setLocked(!1),r.buffers.stencil.setFunc(s.EQUAL,1,4294967295),r.buffers.stencil.setOp(s.KEEP,s.KEEP,s.KEEP),r.buffers.stencil.setLocked(!0)}},Lc=class extends Hn{constructor(){super(),this.needsSwap=!1}render(t){t.state.buffers.stencil.setLocked(!1),t.state.buffers.stencil.setTest(!1)}};var Nc=class{constructor(t,e){if(this.renderer=t,this._pixelRatio=t.getPixelRatio(),e===void 0){let n=t.getSize(new vt);this._width=n.width,this._height=n.height,e=new Ke(this._width*this._pixelRatio,this._height*this._pixelRatio,{type:ln}),e.texture.name="EffectComposer.rt1"}else this._width=e.width,this._height=e.height;this.renderTarget1=e,this.renderTarget2=e.clone(),this.renderTarget2.texture.name="EffectComposer.rt2",this.writeBuffer=this.renderTarget1,this.readBuffer=this.renderTarget2,this.renderToScreen=!0,this.passes=[],this.copyPass=new Pc(Nr),this.copyPass.material.blending=qn,this.timer=new Ha}swapBuffers(){let t=this.readBuffer;this.readBuffer=this.writeBuffer,this.writeBuffer=t}addPass(t){this.passes.push(t),t.setSize(this._width*this._pixelRatio,this._height*this._pixelRatio)}insertPass(t,e){this.passes.splice(e,0,t),t.setSize(this._width*this._pixelRatio,this._height*this._pixelRatio)}removePass(t){let e=this.passes.indexOf(t);e!==-1&&this.passes.splice(e,1)}isLastEnabledPass(t){for(let e=t+1;e<this.passes.length;e++)if(this.passes[e].enabled)return!1;return!0}render(t){this.timer.update(),t===void 0&&(t=this.timer.getDelta());let e=this.renderer.getRenderTarget(),n=!1;for(let s=0,r=this.passes.length;s<r;s++){let a=this.passes[s];if(a.enabled!==!1){if(a.renderToScreen=this.renderToScreen&&this.isLastEnabledPass(s),a.render(this.renderer,this.writeBuffer,this.readBuffer,t,n),a.needsSwap){if(n){let o=this.renderer.getContext(),c=this.renderer.state.buffers.stencil;c.setFunc(o.NOTEQUAL,1,4294967295),this.copyPass.render(this.renderer,this.writeBuffer,this.readBuffer,t),c.setFunc(o.EQUAL,1,4294967295)}this.swapBuffers()}lo!==void 0&&(a instanceof lo?n=!0:a instanceof Lc&&(n=!1))}}this.renderer.setRenderTarget(e)}reset(t){if(t===void 0){let e=this.renderer.getSize(new vt);this._pixelRatio=this.renderer.getPixelRatio(),this._width=e.width,this._height=e.height,t=this.renderTarget1.clone(),t.setSize(this._width*this._pixelRatio,this._height*this._pixelRatio)}this.renderTarget1.dispose(),this.renderTarget2.dispose(),this.renderTarget1=t,this.renderTarget2=t.clone(),this.writeBuffer=this.renderTarget1,this.readBuffer=this.renderTarget2}setSize(t,e){this._width=t,this._height=e;let n=this._width*this._pixelRatio,s=this._height*this._pixelRatio;this.renderTarget1.setSize(n,s),this.renderTarget2.setSize(n,s);for(let r=0;r<this.passes.length;r++)this.passes[r].setSize(n,s)}setPixelRatio(t){this._pixelRatio=t,this.setSize(this._width,this._height)}dispose(){this.renderTarget1.dispose(),this.renderTarget2.dispose(),this.copyPass.dispose()}};var Dc=class extends Hn{constructor(t,e,n=null,s=null,r=null){super(),this.scene=t,this.camera=e,this.overrideMaterial=n,this.clearColor=s,this.clearAlpha=r,this.clear=!0,this.clearDepth=!1,this.needsSwap=!1,this.isRenderPass=!0,this._oldClearColor=new se}render(t,e,n){let s=t.autoClear;t.autoClear=!1;let r,a;this.overrideMaterial!==null&&(a=this.scene.overrideMaterial,this.scene.overrideMaterial=this.overrideMaterial),this.clearColor!==null&&(t.getClearColor(this._oldClearColor),t.setClearColor(this.clearColor,t.getClearAlpha())),this.clearAlpha!==null&&(r=t.getClearAlpha(),t.setClearAlpha(this.clearAlpha)),this.clearDepth==!0&&t.clearDepth(),t.setRenderTarget(this.renderToScreen?null:n),this.clear===!0&&t.clear(t.autoClearColor,t.autoClearDepth,t.autoClearStencil),t.render(this.scene,this.camera),this.clearColor!==null&&t.setClearColor(this._oldClearColor),this.clearAlpha!==null&&t.setClearAlpha(r),this.overrideMaterial!==null&&(this.scene.overrideMaterial=a),t.autoClear=s}};var ff={name:"LuminosityHighPassShader",uniforms:{tDiffuse:{value:null},luminosityThreshold:{value:1},smoothWidth:{value:1},defaultColor:{value:new se(0)},defaultOpacity:{value:0}},vertexShader:`

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

		}`};var Dr=class i extends Hn{constructor(t,e=1,n,s){super(),this.strength=e,this.radius=n,this.threshold=s,this.resolution=t!==void 0?new vt(t.x,t.y):new vt(256,256),this.clearColor=new se(0,0,0),this.needsSwap=!1,this.renderTargetsHorizontal=[],this.renderTargetsVertical=[],this.nMips=5;let r=Math.round(this.resolution.x/2),a=Math.round(this.resolution.y/2);this.renderTargetBright=new Ke(r,a,{type:ln,depthBuffer:!1}),this.renderTargetBright.texture.name="UnrealBloomPass.bright",this.renderTargetBright.texture.generateMipmaps=!1;for(let h=0;h<this.nMips;h++){let f=new Ke(r,a,{type:ln,depthBuffer:!1});f.texture.name="UnrealBloomPass.h"+h,f.texture.generateMipmaps=!1,this.renderTargetsHorizontal.push(f);let u=new Ke(r,a,{type:ln,depthBuffer:!1});u.texture.name="UnrealBloomPass.v"+h,u.texture.generateMipmaps=!1,this.renderTargetsVertical.push(u),r=Math.round(r/2),a=Math.round(a/2)}let o=ff;this.highPassUniforms=Xi.clone(o.uniforms),this.highPassUniforms.luminosityThreshold.value=s,this.highPassUniforms.smoothWidth.value=.01,this.materialHighPassFilter=new Oe({uniforms:this.highPassUniforms,vertexShader:o.vertexShader,fragmentShader:o.fragmentShader}),this.separableBlurMaterials=[];let c=[6,10,14,18,22];r=Math.round(this.resolution.x/2),a=Math.round(this.resolution.y/2);for(let h=0;h<this.nMips;h++)this.separableBlurMaterials.push(this._getSeparableBlurMaterial(c[h])),this.separableBlurMaterials[h].uniforms.invSize.value=new vt(1/r,1/a),r=Math.round(r/2),a=Math.round(a/2);this.compositeMaterial=this._getCompositeMaterial(this.nMips),this.compositeMaterial.uniforms.blurTexture1.value=this.renderTargetsVertical[0].texture,this.compositeMaterial.uniforms.blurTexture2.value=this.renderTargetsVertical[1].texture,this.compositeMaterial.uniforms.blurTexture3.value=this.renderTargetsVertical[2].texture,this.compositeMaterial.uniforms.blurTexture4.value=this.renderTargetsVertical[3].texture,this.compositeMaterial.uniforms.blurTexture5.value=this.renderTargetsVertical[4].texture,this.compositeMaterial.uniforms.bloomStrength.value=e,this.compositeMaterial.uniforms.bloomRadius.value=.1;let l=[1,.8,.6,.4,.2];this.compositeMaterial.uniforms.bloomFactors.value=l,this.bloomTintColors=[new D(1,1,1),new D(1,1,1),new D(1,1,1),new D(1,1,1),new D(1,1,1)],this.compositeMaterial.uniforms.bloomTintColors.value=this.bloomTintColors,this.copyUniforms=Xi.clone(Nr.uniforms),this.blendMaterial=new Oe({uniforms:this.copyUniforms,vertexShader:Nr.vertexShader,fragmentShader:Nr.fragmentShader,premultipliedAlpha:!0,blending:on,depthTest:!1,depthWrite:!1,transparent:!0}),this._oldClearColor=new se,this._oldClearAlpha=1,this._basic=new nn,this._fsQuad=new ms(null)}dispose(){for(let t=0;t<this.renderTargetsHorizontal.length;t++)this.renderTargetsHorizontal[t].dispose();for(let t=0;t<this.renderTargetsVertical.length;t++)this.renderTargetsVertical[t].dispose();this.renderTargetBright.dispose();for(let t=0;t<this.separableBlurMaterials.length;t++)this.separableBlurMaterials[t].dispose();this.compositeMaterial.dispose(),this.blendMaterial.dispose(),this._basic.dispose(),this._fsQuad.dispose()}setSize(t,e){let n=Math.round(t/2),s=Math.round(e/2);this.renderTargetBright.setSize(n,s);for(let r=0;r<this.nMips;r++)this.renderTargetsHorizontal[r].setSize(n,s),this.renderTargetsVertical[r].setSize(n,s),this.separableBlurMaterials[r].uniforms.invSize.value=new vt(1/n,1/s),n=Math.round(n/2),s=Math.round(s/2)}render(t,e,n,s,r){t.getClearColor(this._oldClearColor),this._oldClearAlpha=t.getClearAlpha();let a=t.autoClear;t.autoClear=!1,t.setClearColor(this.clearColor,0),r&&t.state.buffers.stencil.setTest(!1),this.renderToScreen&&(this._fsQuad.material=this._basic,this._basic.map=n.texture,t.setRenderTarget(null),t.clear(),this._fsQuad.render(t)),this.highPassUniforms.tDiffuse.value=n.texture,this.highPassUniforms.luminosityThreshold.value=this.threshold,this._fsQuad.material=this.materialHighPassFilter,t.setRenderTarget(this.renderTargetBright),t.clear(),this._fsQuad.render(t);let o=this.renderTargetBright;for(let c=0;c<this.nMips;c++)this._fsQuad.material=this.separableBlurMaterials[c],this.separableBlurMaterials[c].uniforms.colorTexture.value=o.texture,this.separableBlurMaterials[c].uniforms.direction.value=i.BlurDirectionX,t.setRenderTarget(this.renderTargetsHorizontal[c]),t.clear(),this._fsQuad.render(t),this.separableBlurMaterials[c].uniforms.colorTexture.value=this.renderTargetsHorizontal[c].texture,this.separableBlurMaterials[c].uniforms.direction.value=i.BlurDirectionY,t.setRenderTarget(this.renderTargetsVertical[c]),t.clear(),this._fsQuad.render(t),o=this.renderTargetsVertical[c];this._fsQuad.material=this.compositeMaterial,this.compositeMaterial.uniforms.bloomStrength.value=this.strength,this.compositeMaterial.uniforms.bloomRadius.value=this.radius,this.compositeMaterial.uniforms.bloomTintColors.value=this.bloomTintColors,t.setRenderTarget(this.renderTargetsHorizontal[0]),t.clear(),this._fsQuad.render(t),this._fsQuad.material=this.blendMaterial,this.copyUniforms.tDiffuse.value=this.renderTargetsHorizontal[0].texture,r&&t.state.buffers.stencil.setTest(!0),this.renderToScreen?(t.setRenderTarget(null),this._fsQuad.render(t)):(t.setRenderTarget(n),this._fsQuad.render(t)),t.setClearColor(this._oldClearColor,this._oldClearAlpha),t.autoClear=a}_getSeparableBlurMaterial(t){let e=[],n=t/3;for(let a=0;a<t;a++)e.push(.39894*Math.exp(-.5*a*a/(n*n))/n);let s=[],r=[];for(let a=1;a<t;a+=2){let o=e[a],c=a+1<t?e[a+1]:0,l=o+c;s.push((a*o+(a+1)*c)/l),r.push(l)}return new Oe({defines:{KERNEL_PAIRS:s.length},uniforms:{colorTexture:{value:null},invSize:{value:new vt(.5,.5)},direction:{value:new vt(.5,.5)},centerWeight:{value:e[0]},gaussianOffsets:{value:s},gaussianWeights:{value:r}},vertexShader:`

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

				}`})}_getCompositeMaterial(t){return new Oe({defines:{NUM_MIPS:t},uniforms:{blurTexture1:{value:null},blurTexture2:{value:null},blurTexture3:{value:null},blurTexture4:{value:null},blurTexture5:{value:null},bloomStrength:{value:1},bloomFactors:{value:null},bloomTintColors:{value:null},bloomRadius:{value:0}},vertexShader:`

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

				}`})}};Dr.BlurDirectionX=new vt(1,0);Dr.BlurDirectionY=new vt(0,1);var co={name:"OutputShader",uniforms:{tDiffuse:{value:null},toneMappingExposure:{value:1}},vertexShader:`
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

		}`};var Uc=class extends Hn{constructor(){super(),this.isOutputPass=!0,this.uniforms=Xi.clone(co.uniforms),this.material=new Mr({name:co.name,uniforms:this.uniforms,vertexShader:co.vertexShader,fragmentShader:co.fragmentShader}),this._fsQuad=new ms(this.material),this._outputColorSpace=null,this._toneMapping=null}render(t,e,n){this.uniforms.tDiffuse.value=n.texture,this.uniforms.toneMappingExposure.value=t.toneMappingExposure,(this._outputColorSpace!==t.outputColorSpace||this._toneMapping!==t.toneMapping)&&(this._outputColorSpace=t.outputColorSpace,this._toneMapping=t.toneMapping,this.material.defines={},Se.getTransfer(this._outputColorSpace)===Le&&(this.material.defines.SRGB_TRANSFER=""),this._toneMapping===Wa?this.material.defines.LINEAR_TONE_MAPPING="":this._toneMapping===Xa?this.material.defines.REINHARD_TONE_MAPPING="":this._toneMapping===$a?this.material.defines.CINEON_TONE_MAPPING="":this._toneMapping===Ts?this.material.defines.ACES_FILMIC_TONE_MAPPING="":this._toneMapping===Ya?this.material.defines.AGX_TONE_MAPPING="":this._toneMapping===Za?this.material.defines.NEUTRAL_TONE_MAPPING="":this._toneMapping===qa&&(this.material.defines.CUSTOM_TONE_MAPPING=""),this.material.needsUpdate=!0),this.renderToScreen===!0?(t.setRenderTarget(null),this._fsQuad.render(t)):(t.setRenderTarget(e),this.clear&&t.clear(t.autoClearColor,t.autoClearDepth,t.autoClearStencil),this._fsQuad.render(t))}dispose(){this.material.dispose(),this._fsQuad.dispose()}};function pf(i,t,e=256){let n=i.image;if(!(n instanceof HTMLCanvasElement)||Math.max(n.width,n.height)<=e)return;let s=document.createElement("canvas"),r=e/Math.max(n.width,n.height);s.width=Math.max(1,Math.round(n.width*r)),s.height=Math.max(1,Math.round(n.height*r));let a=s.getContext("2d"),o=Object.getOwnPropertyDescriptor(gn.prototype,"needsUpdate").set,c=()=>{a.drawImage(n,0,0,s.width,s.height),o.call(i,!0)};i.image=s,Object.defineProperty(i,"needsUpdate",{configurable:!0,set(l){l&&(c(),t())}}),c()}function mf(i){let t=new Set([i.outer,i.inner,i.hit,i.ring,...i.bOuter,...i.streaks]);for(let e of i.stdParts.concat(i.heavy)){let n=[];e.traverse(s=>{s.isGroup&&n.push(s)});for(let s of n){let r=new Map;for(let a of s.children){if(!a.isMesh||a.children.length||t.has(a))continue;let o=`${a.geometry.uuid}/${a.material.uuid}`;r.has(o)||r.set(o,[]),r.get(o).push(a)}for(let a of r.values()){if(a.length<2)continue;let o=a[0],c=new ma(o.geometry,o.material,a.length);a.forEach((l,h)=>{l.updateMatrix(),c.setMatrixAt(h,l.matrix),s.remove(l)}),c.computeBoundingSphere(),s.add(c)}}}}function gf(i,t,e,n=40){let s=a=>a.x*Math.cos(e)-a.z*Math.sin(e),r=new Map(i.map(a=>[a,a.tgt.x]));for(let a=0;a<n;a++)for(let o=0;o<i.length;o++)for(let c=o+1;c<i.length;c++){let l=i[o],h=i[c],f=s(h.tgt)-s(l.tgt),u=(h.tgt.y-l.tgt.y)*.3,d=Math.hypot(f,u);if(d<t){let g=r.get(h)-r.get(l),_=(t-d)/2,m=g!==0?Math.sign(g):f>=0?1:-1;l.tgt.x-=_*m,h.tgt.x+=_*m,l.nudge-=_*m,h.nudge+=_*m}}}function xf(i){let e=new D(0,-55,-8),n=new D(-.93,.07,-.36).normalize(),s=`vec3 m289(vec3 x){return x-floor(x*(1./289.))*289.;} vec4 m289(vec4 x){return x-floor(x*(1./289.))*289.;} vec4 perm(vec4 x){return m289(((x*34.)+1.)*x);} vec4 tis(vec4 r){return 1.79284291400159-.85373472095314*r;}
float snoise(vec3 v){ const vec2 C=vec2(1./6.,1./3.); const vec4 D=vec4(0.,.5,1.,2.); vec3 i=floor(v+dot(v,C.yyy)); vec3 x0=v-i+dot(i,C.xxx); vec3 g=step(x0.yzx,x0.xyz); vec3 l=1.-g; vec3 i1=min(g.xyz,l.zxy); vec3 i2=max(g.xyz,l.zxy); vec3 x1=x0-i1+C.xxx; vec3 x2=x0-i2+C.yyy; vec3 x3=x0-D.yyy; i=m289(i);
 vec4 p=perm(perm(perm(i.z+vec4(0.,i1.z,i2.z,1.))+i.y+vec4(0.,i1.y,i2.y,1.))+i.x+vec4(0.,i1.x,i2.x,1.)); float n_=.142857142857; vec3 ns=n_*D.wyz-D.xzx; vec4 j=p-49.*floor(p*ns.z*ns.z); vec4 x_=floor(j*ns.z); vec4 y_=floor(j-7.*x_); vec4 x=x_*ns.x+ns.yyyy; vec4 y=y_*ns.x+ns.yyyy; vec4 h=1.-abs(x)-abs(y); vec4 b0=vec4(x.xy,y.xy); vec4 b1=vec4(x.zw,y.zw); vec4 s0=floor(b0)*2.+1.; vec4 s1=floor(b1)*2.+1.; vec4 sh=-step(h,vec4(0.));
 vec4 a0=b0.xzyw+s0.xzyw*sh.xxyy; vec4 a1=b1.xzyw+s1.xzyw*sh.zzww; vec3 p0=vec3(a0.xy,h.x); vec3 p1=vec3(a0.zw,h.y); vec3 p2=vec3(a1.xy,h.z); vec3 p3=vec3(a1.zw,h.w); vec4 nr=tis(vec4(dot(p0,p0),dot(p1,p1),dot(p2,p2),dot(p3,p3))); p0*=nr.x; p1*=nr.y; p2*=nr.z; p3*=nr.w;
 vec4 m=max(.6-vec4(dot(x0,x0),dot(x1,x1),dot(x2,x2),dot(x3,x3)),0.); m=m*m; return 42.*dot(m*m,vec4(dot(p0,x0),dot(p1,x1),dot(p2,x2),dot(p3,x3))); }
float fbm6(vec3 p){ float s=0., a=.5; for(int i=0;i<6;i++){ s+=a*snoise(p); p=p*2.03+vec3(1.7,9.2,3.1); a*=.5; } return s; }
float fbm4(vec3 p){ float s=0., a=.5; for(int i=0;i<4;i++){ s+=a*snoise(p); p=p*2.1+vec3(4.1,2.3,7.7); a*=.5; } return s; }`,r=new Je;r.position.copy(e),i.add(r);let a=new Oe({uniforms:{sun:{value:n},t:{value:0}},vertexShader:"varying vec3 vP; varying vec3 vWN; varying vec3 vWP; void main(){ vP=position; vWN=normalize(mat3(modelMatrix)*normal); vec4 w=modelMatrix*vec4(position,1.); vWP=w.xyz; gl_Position=projectionMatrix*viewMatrix*w; }",fragmentShader:`uniform vec3 sun; uniform float t; varying vec3 vP; varying vec3 vWN; varying vec3 vWP;
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
}`}),o=new ve(new $n(46,128,96),a);r.add(o);let c=new ve(new $n(46*1.028,96,64),new Oe({side:bn,transparent:!0,depthWrite:!1,blending:on,uniforms:{sun:{value:n}},vertexShader:"varying vec3 vN; varying vec3 wN; void main(){ vN=normalize(normalMatrix*normal); wN=normalize(mat3(modelMatrix)*normal); gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",fragmentShader:"uniform vec3 sun; varying vec3 vN; varying vec3 wN; void main(){ float i=pow(max(0.,.76-dot(vN,vec3(0.,0.,1.))),3.2); float s=.12+1.6*smoothstep(-.35,.55,dot(wN,sun)); vec3 c=mix(vec3(.2,.5,1.),vec3(.7,.88,1.),smoothstep(.3,.9,dot(wN,sun))); gl_FragColor=vec4(c*i*s*1.25,1.); }"}));return r.add(c),{update(l){a.uniforms.t.value=l,o.rotation.y=l*.002},dispose(){r.traverse(l=>{l.geometry?.dispose(),l.material?.dispose()}),i.remove(r)}}}var di=i=>i,u3={openai:di({colour:"#ececec",base:"#f3f3f1",ink:"#111214",cap:"#111214",trim:["#111214"],pattern:"lattice",glyph:"openai-white.svg"}),anthropic:di({colour:"#d97757",base:"#f0eee6",ink:"#d97757",cap:"#d97757",trim:["#191919"],pattern:"split",glyph:"claude.svg"}),alibaba:di({colour:"#ff6a00",base:"#ff6a00",ink:"#ffffff",cap:"#ffffff",trim:["#6950ef"],pattern:"diagonal",glyph:"alibaba.svg"}),xiaomi:di({colour:"#ff6900",base:"#ffffff",ink:"#ff6900",cap:"#ff6900",trim:["#ff6900","#ffffff"],pattern:"rings",glyph:"xiaomi.svg"}),google:di({colour:"#4285f4",base:"#ffffff",ink:"#4285f4",inks:["#4285f4","#ea4335","#fbbc05","#34a853"],cap:"#4285f4",trim:["#4285f4","#ea4335","#fbbc05","#34a853"],pattern:"lattice",glyph:"gemini.svg"}),kimi:di({colour:"#007cff",base:"#007cff",ink:"#ffffff",cap:"#121212",trim:["#121212"],pattern:"rings",glyph:"kimi-white.svg"}),minimax:di({colour:"#e73562",base:"#e73562",ink:"#ffffff",cap:"#ffffff",trim:["#ffffff"],pattern:"rings",glyph:"minimax.svg"}),zhipuai:di({colour:"#b9c2cc",base:"#1a1d21",ink:"#ffffff",cap:"#ffffff",trim:["#ffffff","#1a1d21"],pattern:"lattice",glyph:"zai-white.svg"}),xai:di({colour:"#8f96a0",base:"#0b0b0c",ink:"#f2f2f2",cap:"#0b0b0c",trim:["#f2f2f2"],pattern:"diagonal",glyph:"x-white.svg"}),meta:di({colour:"#0467df",base:"#ffffff",ink:"#0467df",cap:"#0467df",trim:["#0467df"],pattern:"diagonal",glyph:"meta.svg"}),deepseek:di({colour:"#4d6bfe",base:"#4d6bfe",ink:"#ffffff",cap:"#ffffff",trim:["#ffffff"],pattern:"diagonal",glyph:"deepseek.svg"})};function Ur(i,t="#b8b0a8"){return u3[i]??{colour:t,base:t,ink:"#ffffff",cap:"#ffffff",trim:["#ffffff"],pattern:"rings",glyph:null}}function Fc(i,t=!1){let e=i[0].index!==null,n=new Set(Object.keys(i[0].attributes)),s=new Set(Object.keys(i[0].morphAttributes)),r={},a={},o=i[0].morphTargetsRelative,c=new Ae,l=0;for(let h=0;h<i.length;++h){let f=i[h],u=0;if(e!==(f.index!==null))return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". All geometries must have compatible attributes; make sure index attribute exists among all geometries, or in none of them."),null;for(let d in f.attributes){if(!n.has(d))return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+'. All geometries must have compatible attributes; make sure "'+d+'" attribute exists among all geometries, or in none of them.'),null;r[d]===void 0&&(r[d]=[]),r[d].push(f.attributes[d]),u++}if(u!==n.size)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". Make sure all geometries have the same number of attributes."),null;if(o!==f.morphTargetsRelative)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". .morphTargetsRelative must be consistent throughout all geometries."),null;for(let d in f.morphAttributes){if(!s.has(d))return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+".  .morphAttributes must be consistent throughout all geometries."),null;a[d]===void 0&&(a[d]=[]),a[d].push(f.morphAttributes[d])}if(t){let d;if(e)d=f.index.count;else if(f.attributes.position!==void 0)d=f.attributes.position.count;else return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed with geometry at index "+h+". The geometry must have either an index or a position attribute"),null;c.addGroup(l,d,h),l+=d}}if(e){let h=0,f=[];for(let u=0;u<i.length;++u){let d=i[u].index;for(let g=0;g<d.count;++g)f.push(d.getX(g)+h);h+=i[u].attributes.position.count}c.setIndex(f)}for(let h in r){let f=_f(r[h]);if(!f)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed while trying to merge the "+h+" attribute."),null;c.setAttribute(h,f)}for(let h in a){let f=a[h][0].length;if(f!==0){c.morphAttributes=c.morphAttributes||{},c.morphAttributes[h]=[];for(let u=0;u<f;++u){let d=[];for(let _=0;_<a[h].length;++_)d.push(a[h][_][u]);let g=_f(d);if(!g)return console.error("THREE.BufferGeometryUtils: .mergeGeometries() failed while trying to merge the "+h+" morphAttribute."),null;c.morphAttributes[h].push(g)}}}return c}function _f(i){let t,e,n,s=-1,r=0;for(let l=0;l<i.length;++l){let h=i[l];if(t===void 0&&(t=h.array.constructor),t!==h.array.constructor)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.array must be of consistent array types across matching attributes."),null;if(e===void 0&&(e=h.itemSize),e!==h.itemSize)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.itemSize must be consistent across matching attributes."),null;if(n===void 0&&(n=h.normalized),n!==h.normalized)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.normalized must be consistent across matching attributes."),null;if(s===-1&&(s=h.gpuType),s!==h.gpuType)return console.error("THREE.BufferGeometryUtils: .mergeAttributes() failed. BufferAttribute.gpuType must be consistent across matching attributes."),null;r+=h.count*e}let a=new t(r),o=new tn(a,e,n),c=0;for(let l=0;l<i.length;++l){let h=i[l];if(h.isInterleavedBufferAttribute){let f=c/e;for(let u=0,d=h.count;u<d;u++)for(let g=0;g<e;g++){let _=h.getComponent(u,g);o.setComponent(u+f,g,_)}}else a.set(h.array,c);c+=h.count*e}return s!==void 0&&(o.gpuType=s),o}var ho={falcon9:{id:"falcon9",shape:"falcon9",atlas:{w:852,h:1024,cap:[.993,.9941,.9977,.998]},parts:[{name:"core",uv:[0,0,.9014,1],top:1.6,end:-1.1295,profile:[[1.6,.018],[1.5886,.0552],[1.5771,.0765],[1.5657,.0934],[1.5543,.1083],[1.5429,.1218],[1.5314,.1343],[1.52,.1459],[1.5086,.1566],[1.4971,.1664],[1.4857,.1756],[1.4743,.1839],[1.4629,.1914],[1.4514,.1981],[1.44,.2041],[1.4286,.2094],[1.4171,.2139],[1.4057,.2178],[1.3943,.2211],[1.3829,.2238],[1.3714,.226],[1.36,.2275],[1.3486,.2282],[1.3371,.2287],[1.3257,.229],[1.3143,.2291],[1.3029,.2291],[1.2914,.229],[1.28,.2289],[1.2686,.2287],[1.2571,.2286],[1.2457,.2284],[1.2343,.2282],[1.2229,.2281],[1.2114,.2279],[1.2,.2278],[1.1886,.2278],[1.1771,.2281],[1.1657,.2285],[1.1543,.2284],[1.1429,.2281],[1.1314,.228],[1.12,.228],[1.1086,.228],[1.0971,.2279],[1.0857,.2277],[1.0743,.2275],[1.0629,.2274],[1.0514,.2271],[1.04,.2264],[1.0286,.2247],[1.0171,.2213],[1.0057,.216],[.9943,.2087],[.9829,.2001],[.9714,.1909],[.96,.1818],[.9486,.1735],[.9371,.1672],[.9257,.1629],[.9143,.1598],[.9029,.1574],[.8914,.1563],[.88,.1559],[.8686,.1557],[.8571,.1557],[.8457,.156],[.8343,.1564],[.8229,.1567],[.8114,.1568],[.8,.1567],[.7886,.1566],[.7771,.1567],[.7657,.157],[.7543,.1575],[.7429,.1576],[.7314,.1576],[.72,.1575],[.7086,.1574],[.6971,.1574],[.6857,.1576],[.6743,.1577],[.6629,.1575],[.6514,.157],[.64,.1568],[.6286,.1566],[.6171,.1565],[.6057,.1564],[.5943,.1564],[.5829,.1568],[.5714,.1589],[.56,.1642],[.5486,.1742],[.5371,.1896],[.5257,.2095],[.5143,.2305],[.5029,.2478],[.4914,.2566],[.48,.2521],[.4686,.232],[.4571,.2026],[.4457,.1795],[.4343,.1697],[.4229,.1675],[.4114,.1671],[.4,.1666],[.3886,.1659],[.3771,.1655],[.3657,.1652],[.3543,.1651],[.3429,.165],[.3314,.1649],[.32,.1648],[.3086,.1646],[.2971,.1645],[.2857,.1644],[.2743,.1643],[.2629,.1642],[.2514,.164],[.24,.164],[.2286,.1638],[.2171,.1637],[.2057,.1636],[.1943,.1636],[.1829,.1639],[.1714,.1645],[.16,.1653],[.1486,.1659],[.1371,.166],[.1257,.1659],[.1143,.1658],[.1029,.1657],[.0914,.1656],[.08,.1655],[.0686,.1654],[.0571,.1653],[.0457,.1651],[.0343,.165],[.0229,.1649],[.0114,.1648],[0,.1647],[-.0114,.1646],[-.0229,.1645],[-.0343,.1644],[-.0457,.1642],[-.0571,.1641],[-.0686,.164],[-.08,.164],[-.0914,.164],[-.1029,.1642],[-.1143,.1645],[-.1257,.1645],[-.1371,.1643],[-.1486,.1643],[-.16,.1646],[-.1714,.165],[-.1829,.1655],[-.1943,.1657],[-.2057,.1657],[-.2171,.1656],[-.2286,.1655],[-.24,.1654],[-.2514,.1653],[-.2629,.1652],[-.2743,.1651],[-.2857,.165],[-.2971,.1649],[-.3086,.1647],[-.32,.1646],[-.3314,.1645],[-.3429,.1644],[-.3543,.1643],[-.3657,.1644],[-.3771,.165],[-.3886,.1666],[-.4,.1684],[-.4114,.1694],[-.4229,.1696],[-.4343,.1696],[-.4457,.1695],[-.4571,.1694],[-.4686,.1692],[-.48,.1692],[-.4914,.169],[-.5029,.1689],[-.5143,.1688],[-.5257,.1687],[-.5371,.1686],[-.5486,.1685],[-.56,.1683],[-.5714,.1682],[-.5829,.1681],[-.5943,.168],[-.6057,.1679],[-.6171,.1678],[-.6286,.1677],[-.64,.1676],[-.6514,.1675],[-.6629,.1673],[-.6743,.1673],[-.6857,.1671],[-.6971,.167],[-.7086,.1669],[-.72,.1668],[-.7314,.1667],[-.7429,.1666],[-.7543,.1665],[-.7657,.1664],[-.7771,.1663],[-.7886,.1661],[-.8,.166],[-.8114,.1659],[-.8229,.1658],[-.8343,.1657],[-.8457,.1656],[-.8571,.1655],[-.8686,.1654],[-.88,.1653],[-.8914,.1652],[-.9029,.1651],[-.9143,.165],[-.9257,.1649],[-.9371,.1647],[-.9486,.1646],[-.96,.1645],[-.9714,.1644],[-.9829,.1643],[-.9943,.1642],[-1.0057,.1641],[-1.0171,.164],[-1.0286,.1639],[-1.04,.1638],[-1.0514,.1637],[-1.0629,.1636],[-1.0743,.1635],[-1.0857,.1634],[-1.0971,.1633],[-1.1086,.1631],[-1.12,.1631],[-1.1276,.163]],at:[[0,0]],fins:[{side:-1,uv:[.9014,.6426,.9894,1],x0:-.2226,x1:0,y0:-.4381,y1:-1.1352,outline:[[-.4381,.1721,.1662],[-.4438,.1751,.1662],[-.4495,.1751,.1662],[-.4552,.1751,.1662],[-.461,.1781,.1662],[-.4667,.1781,.1662],[-.4724,.1781,.1662],[-.4781,.1781,.1662],[-.4838,.181,.1662],[-.4895,.181,.1662],[-.4952,.181,.1662],[-.501,.181,.1662],[-.5067,.181,.1662],[-.5124,.184,.1662],[-.5181,.184,.1662],[-.5238,.184,.1662],[-.5295,.184,.1662],[-.5352,.184,.1662],[-.541,.187,.1662],[-.5467,.187,.1662],[-.5524,.187,.1662],[-.5581,.1899,.1662],[-.5638,.1899,.1662],[-.5695,.1899,.1662],[-.5752,.1899,.1662],[-.581,.1899,.1662],[-.5867,.187,.1662],[-.5924,.1899,.1662],[-.5981,.1899,.1662],[-.6038,.1899,.1662],[-.6095,.1899,.1662],[-.6152,.1899,.1662],[-.621,.1899,.1662],[-.6267,.1899,.1662],[-.6324,.1899,.1662],[-.6381,.1899,.1662],[-.6438,.1899,.1662],[-.6495,.1899,.1662],[-.6552,.1899,.1662],[-.661,.1929,.1662],[-.6667,.1929,.1662],[-.6724,.1929,.1662],[-.6781,.1929,.1662],[-.6838,.1929,.1662],[-.6895,.1929,.1662],[-.6952,.1929,.1662],[-.701,.1929,.1662],[-.7067,.1959,.1662],[-.7124,.1959,.1662],[-.7181,.1959,.1662],[-.7238,.1959,.1662],[-.7295,.1959,.1662],[-.7352,.1959,.1662],[-.741,.1959,.1662],[-.7467,.1959,.1662],[-.7524,.1959,.1662],[-.7581,.1988,.1662],[-.7638,.1988,.1662],[-.7695,.1988,.1662],[-.7752,.1988,.1662],[-.781,.1988,.1662],[-.7867,.1988,.1662],[-.7924,.1988,.1662],[-.7981,.1988,.1662],[-.8038,.2018,.1662],[-.8095,.2018,.1662],[-.8152,.2018,.1662],[-.821,.2018,.1662],[-.8267,.2018,.1662],[-.8324,.2018,.1662],[-.8381,.2018,.1662],[-.8438,.2018,.1662],[-.8495,.2018,.1662],[-.8552,.2018,.1662],[-.861,.2047,.1662],[-.8667,.2047,.1662],[-.8724,.2047,.1662],[-.8781,.2047,.1662],[-.8838,.2047,.1662],[-.8895,.2047,.1662],[-.8952,.2047,.1662],[-.901,.2077,.1662],[-.9067,.2077,.1662],[-.9124,.2077,.1662],[-.9181,.2077,.1662],[-.9238,.2077,.1662],[-.9295,.2077,.1662],[-.9352,.2077,.1662],[-.941,.2077,.1662],[-.9467,.2107,.1662],[-.9524,.2107,.1662],[-.9581,.2107,.1662],[-.9638,.2107,.1662],[-.9695,.2107,.1662],[-.9752,.2107,.1662],[-.981,.2107,.1662],[-.9867,.2136,.1662],[-.9924,.2136,.1662],[-.9981,.2136,.1662],[-1.0038,.2136,.1662],[-1.0095,.2136,.1662],[-1.0152,.2136,.1662],[-1.021,.2166,.1662],[-1.0267,.2196,.1662],[-1.0324,.2196,.1662],[-1.0381,.2196,.1662],[-1.0438,.2107,.1662],[-1.0495,.2047,.1662],[-1.0552,.1988,.1662],[-1.061,.1988,.1662],[-1.0667,.1988,.1662],[-1.0724,.2018,.1662],[-1.0781,.2018,.1662],[-1.0838,.2018,.1662],[-1.0895,.2018,.1662],[-1.0952,.2018,.1662],[-1.101,.2047,.1662],[-1.1067,.2047,.1662],[-1.1124,.2047,.1662],[-1.1181,.2047,.1662],[-1.1238,.1988,.1662],[-1.1295,.1899,.1662],[-1.1333,.184,.1662]]},{side:1,uv:[.9014,.2832,.9906,.6406],x0:0,x1:.2255,y0:-.4381,y1:-1.1352,outline:[[-.4381,.1721,.1662],[-.4438,.1751,.1662],[-.4495,.1751,.1662],[-.4552,.1751,.1662],[-.461,.1781,.1662],[-.4667,.1781,.1662],[-.4724,.1781,.1662],[-.4781,.1781,.1662],[-.4838,.181,.1662],[-.4895,.181,.1662],[-.4952,.181,.1662],[-.501,.181,.1662],[-.5067,.184,.1662],[-.5124,.184,.1662],[-.5181,.184,.1662],[-.5238,.184,.1662],[-.5295,.184,.1662],[-.5352,.187,.1662],[-.541,.187,.1662],[-.5467,.187,.1662],[-.5524,.1899,.1662],[-.5581,.1929,.1662],[-.5638,.1929,.1662],[-.5695,.1929,.1662],[-.5752,.1899,.1662],[-.581,.1899,.1662],[-.5867,.1899,.1662],[-.5924,.1899,.1662],[-.5981,.1899,.1662],[-.6038,.1899,.1662],[-.6095,.1929,.1662],[-.6152,.1929,.1662],[-.621,.1929,.1662],[-.6267,.1929,.1662],[-.6324,.1929,.1662],[-.6381,.1929,.1662],[-.6438,.1929,.1662],[-.6495,.1929,.1662],[-.6552,.1929,.1662],[-.661,.1929,.1662],[-.6667,.1959,.1662],[-.6724,.1959,.1662],[-.6781,.1959,.1662],[-.6838,.1959,.1662],[-.6895,.1959,.1662],[-.6952,.1959,.1662],[-.701,.1959,.1662],[-.7067,.1959,.1662],[-.7124,.1959,.1662],[-.7181,.1959,.1662],[-.7238,.1988,.1662],[-.7295,.1988,.1662],[-.7352,.1988,.1662],[-.741,.1988,.1662],[-.7467,.1988,.1662],[-.7524,.1988,.1662],[-.7581,.1988,.1662],[-.7638,.2018,.1662],[-.7695,.2018,.1662],[-.7752,.2018,.1662],[-.781,.2018,.1662],[-.7867,.2018,.1662],[-.7924,.2018,.1662],[-.7981,.2018,.1662],[-.8038,.2018,.1662],[-.8095,.2047,.1662],[-.8152,.2047,.1662],[-.821,.2047,.1662],[-.8267,.2047,.1662],[-.8324,.2047,.1662],[-.8381,.2047,.1662],[-.8438,.2047,.1662],[-.8495,.2077,.1662],[-.8552,.2077,.1662],[-.861,.2077,.1662],[-.8667,.2077,.1662],[-.8724,.2077,.1662],[-.8781,.2077,.1662],[-.8838,.2077,.1662],[-.8895,.2107,.1662],[-.8952,.2107,.1662],[-.901,.2107,.1662],[-.9067,.2107,.1662],[-.9124,.2107,.1662],[-.9181,.2107,.1662],[-.9238,.2107,.1662],[-.9295,.2136,.1662],[-.9352,.2136,.1662],[-.941,.2136,.1662],[-.9467,.2136,.1662],[-.9524,.2136,.1662],[-.9581,.2136,.1662],[-.9638,.2136,.1662],[-.9695,.2166,.1662],[-.9752,.2166,.1662],[-.981,.2166,.1662],[-.9867,.2166,.1662],[-.9924,.2166,.1662],[-.9981,.2196,.1662],[-1.0038,.2196,.1662],[-1.0095,.2196,.1662],[-1.0152,.2225,.1662],[-1.021,.2225,.1662],[-1.0267,.2225,.1662],[-1.0324,.2225,.1662],[-1.0381,.2225,.1662],[-1.0438,.2166,.1662],[-1.0495,.2107,.1662],[-1.0552,.2018,.1662],[-1.061,.2018,.1662],[-1.0667,.2018,.1662],[-1.0724,.2047,.1662],[-1.0781,.2047,.1662],[-1.0838,.2047,.1662],[-1.0895,.2047,.1662],[-1.0952,.2047,.1662],[-1.101,.2047,.1662],[-1.1067,.2047,.1662],[-1.1124,.2047,.1662],[-1.1181,.2047,.1662],[-1.1238,.2047,.1662],[-1.1295,.1959,.1662],[-1.1333,.1899,.1662]]}],finsAround:4,finsFrom:null,engines:{ring:8,centre:!0,f:.34,colour:[32,26,19],profile:[[-1.1295,.1892],[-1.1333,.1833],[-1.1371,.1803],[-1.141,.1818],[-1.1448,.1817],[-1.1486,.1846],[-1.1524,.186],[-1.1562,.1874],[-1.16,.1888],[-1.1638,.1902],[-1.1676,.1917],[-1.1714,.1931],[-1.1752,.1945],[-1.179,.1959],[-1.1829,.1973],[-1.1867,.1987],[-1.1905,.2001],[-1.1943,.2001],[-1.1981,.2015],[-1.2019,.2029],[-1.2057,.2028],[-1.2095,.1984],[-1.2133,.1854],[-1.2171,.1506],[-1.221,.1505],[-1.2248,.1476],[-1.2286,.1302],[-1.2324,.055],[-1.2362,.0521],[-1.24,.0405]]}}],badge:{y:.9137,d:.2397,r:.1598},band:[.7607,.7796],head:{top:1.6,cut:1.0666,mean:.7703,r:.2696}},falconHeavy:{id:"falcon-heavy",shape:"falconHeavy",atlas:{w:1236,h:1024,cap:[.9951,.9941,.9984,.998]},parts:[{name:"core",uv:[0,0,.6214,1],top:1.6,end:-1.1103,profile:[[1.6,.0148],[1.5884,.0342],[1.5768,.0518],[1.5652,.0675],[1.5535,.0822],[1.5419,.0952],[1.5303,.1071],[1.5187,.1182],[1.5071,.1283],[1.4955,.1375],[1.4838,.1459],[1.4722,.1535],[1.4606,.1604],[1.449,.1666],[1.4374,.1721],[1.4258,.1771],[1.4142,.1814],[1.4025,.1851],[1.3909,.1882],[1.3793,.1907],[1.3677,.1927],[1.3561,.1942],[1.3445,.1952],[1.3328,.1959],[1.3212,.1961],[1.3096,.1961],[1.298,.196],[1.2864,.1959],[1.2748,.1958],[1.2631,.1957],[1.2515,.1956],[1.2399,.1955],[1.2283,.1955],[1.2167,.1958],[1.2051,.1962],[1.1935,.1964],[1.1818,.1964],[1.1702,.1963],[1.1586,.1962],[1.147,.1961],[1.1354,.196],[1.1238,.1959],[1.1121,.1958],[1.1005,.1957],[1.0889,.1956],[1.0773,.1955],[1.0657,.1954],[1.0541,.1953],[1.0425,.1952],[1.0308,.1951],[1.0192,.195],[1.0076,.1948],[.996,.1946],[.9844,.1938],[.9728,.192],[.9611,.1887],[.9495,.1842],[.9379,.1788],[.9263,.1731],[.9147,.1673],[.9031,.1617],[.8915,.1567],[.8798,.1525],[.8682,.1495],[.8566,.1479],[.845,.1473],[.8334,.1472],[.8218,.1471],[.8101,.147],[.7985,.1469],[.7869,.1469],[.7753,.1468],[.7637,.1467],[.7521,.1467],[.7404,.1468],[.7288,.1469],[.7172,.1471],[.7056,.1473],[.694,.1476],[.6824,.1479],[.6708,.1483],[.6591,.1487],[.6475,.1491],[.6359,.1496],[.6243,.1501],[.6127,.1507],[.6011,.1513],[.5894,.1519],[.5778,.1526],[.5662,.1533],[.5546,.1539],[.543,.1546],[.5314,.1554],[.5198,.1561],[.5081,.1568],[.4965,.1575],[.4849,.1583],[.4733,.159],[.4617,.1598],[.4501,.1605],[.4384,.1613],[.4268,.162],[.4152,.1627],[.4036,.1634],[.392,.164],[.3804,.1646],[.3688,.1651],[.3571,.1655],[.3455,.1659],[.3339,.1663],[.3223,.1664],[.3107,.1663],[.2991,.1662],[.2874,.1662],[.2758,.1661],[.2642,.166],[.2526,.1659],[.241,.1658],[.2294,.1657],[.2178,.1657],[.2061,.1656],[.1945,.1655],[.1829,.1654],[.1713,.1653],[.1597,.1653],[.1481,.1652],[.1364,.1651],[.1248,.1651],[.1132,.1653],[.1016,.1657],[.09,.1657],[.0784,.1655],[.0667,.1653],[.0551,.1654],[.0435,.1657],[.0319,.1658],[.0203,.1659],[.0087,.1663],[-.0029,.1666],[-.0146,.1667],[-.0262,.1667],[-.0378,.1666],[-.0494,.1665],[-.061,.1664],[-.0726,.1664],[-.0843,.1663],[-.0959,.1662],[-.1075,.1661],[-.1191,.166],[-.1307,.1659],[-.1423,.1659],[-.1539,.1658],[-.1656,.1657],[-.1772,.1656],[-.1888,.1656],[-.2004,.1657],[-.212,.1661],[-.2236,.1664],[-.2353,.1665],[-.2469,.1665],[-.2585,.1664],[-.2701,.1663],[-.2817,.1662],[-.2933,.1662],[-.3049,.1661],[-.3166,.166],[-.3282,.1659],[-.3398,.1658],[-.3514,.1657],[-.363,.1657],[-.3746,.1656],[-.3863,.1655],[-.3979,.1654],[-.4095,.1653],[-.4211,.1653],[-.4327,.1652],[-.4443,.1651],[-.456,.1651],[-.4676,.1653],[-.4792,.1656],[-.4908,.1659],[-.5024,.166],[-.514,.166],[-.5256,.1659],[-.5373,.1658],[-.5489,.1657],[-.5605,.1656],[-.5721,.1656],[-.5837,.1655],[-.5953,.1654],[-.607,.1653],[-.6186,.1652],[-.6302,.1651],[-.6418,.1651],[-.6534,.165],[-.665,.1649],[-.6766,.1648],[-.6883,.1648],[-.6999,.1647],[-.7115,.1646],[-.7231,.1645],[-.7347,.1644],[-.7463,.1643],[-.758,.1643],[-.7696,.1642],[-.7812,.1641],[-.7928,.164],[-.8044,.1639],[-.816,.1639],[-.8276,.1638],[-.8393,.1637],[-.8509,.1636],[-.8625,.1636],[-.8741,.1635],[-.8857,.1634],[-.8973,.1633],[-.909,.1632],[-.9206,.1631],[-.9322,.1631],[-.9438,.163],[-.9554,.1629],[-.967,.1628],[-.9787,.1628],[-.9903,.1627],[-1.0019,.1626],[-1.0135,.1625],[-1.0251,.1625],[-1.0367,.1624],[-1.0483,.1623],[-1.06,.1622],[-1.0716,.1621],[-1.0832,.1621],[-1.0948,.162],[-1.1064,.1619],[-1.1103,.1619]],at:[[0,0]],fins:[],finsAround:0,finsFrom:"booster",engines:{ring:8,centre:!0,f:.34,colour:[57,54,51],profile:[[-1.1103,.1592],[-1.1142,.1579],[-1.118,.1578],[-1.1219,.1578],[-1.1258,.1591],[-1.1297,.1591],[-1.1335,.1591],[-1.1374,.159],[-1.1413,.1564],[-1.1451,.1484],[-1.149,.1404],[-1.1529,.1377],[-1.1568,.1377],[-1.1606,.1377],[-1.1645,.1403],[-1.1684,.143],[-1.1722,.1456],[-1.1761,.1456],[-1.18,.1482],[-1.1839,.1508],[-1.1877,.1508],[-1.1916,.1534],[-1.1955,.1547],[-1.1993,.156],[-1.2032,.1586],[-1.2071,.1586],[-1.211,.1612],[-1.2148,.1625],[-1.2187,.1638],[-1.2226,.1664],[-1.2264,.1637],[-1.2303,.1479],[-1.2342,.1307],[-1.2381,.1069]]}},{name:"booster",uv:[.6214,.0498,.932,1],top:.7714,end:-1.1103,profile:[[.7714,.0142],[.7598,.0316],[.7482,.0465],[.7366,.0588],[.725,.0697],[.7133,.0796],[.7017,.0886],[.6901,.0969],[.6785,.1045],[.6669,.1114],[.6553,.1178],[.6437,.1235],[.632,.1286],[.6204,.1332],[.6088,.1371],[.5972,.1406],[.5856,.1436],[.574,.146],[.5623,.1478],[.5507,.1495],[.5391,.1512],[.5275,.1533],[.5159,.1559],[.5043,.1589],[.4927,.1618],[.481,.1646],[.4694,.1669],[.4578,.1685],[.4462,.1692],[.4346,.1687],[.423,.1671],[.4113,.1646],[.3997,.1616],[.3881,.158],[.3765,.1553],[.3649,.1542],[.3533,.1539],[.3416,.1537],[.33,.1533],[.3184,.1527],[.3068,.1523],[.2952,.1522],[.2836,.1521],[.272,.152],[.2603,.1519],[.2487,.1518],[.2371,.1519],[.2255,.1521],[.2139,.1525],[.2023,.1528],[.1906,.1528],[.179,.1528],[.1674,.1527],[.1558,.1526],[.1442,.1525],[.1326,.1525],[.121,.1524],[.1093,.1523],[.0977,.1522],[.0861,.1522],[.0745,.1523],[.0629,.1527],[.0513,.153],[.0396,.1532],[.028,.1532],[.0164,.1531],[.0048,.1529],[-.0068,.1526],[-.0184,.1521],[-.03,.1516],[-.0417,.1514],[-.0533,.1513],[-.0649,.1514],[-.0765,.1517],[-.0881,.152],[-.0997,.1522],[-.1114,.1522],[-.123,.1522],[-.1346,.1521],[-.1462,.152],[-.1578,.1519],[-.1694,.1519],[-.181,.1518],[-.1927,.1517],[-.2043,.1516],[-.2159,.1517],[-.2275,.1519],[-.2391,.1523],[-.2507,.1526],[-.2624,.1526],[-.274,.1526],[-.2856,.1525],[-.2972,.1524],[-.3088,.1523],[-.3204,.1519],[-.3321,.1515],[-.3437,.151],[-.3553,.1508],[-.3669,.1509],[-.3785,.1512],[-.3901,.1516],[-.4017,.1517],[-.4134,.1516],[-.425,.1516],[-.4366,.1516],[-.4482,.1519],[-.4598,.1528],[-.4714,.1539],[-.4831,.1548],[-.4947,.1551],[-.5063,.1551],[-.5179,.1551],[-.5295,.155],[-.5411,.1549],[-.5527,.1548],[-.5644,.1547],[-.576,.1547],[-.5876,.1546],[-.5992,.1545],[-.6108,.1544],[-.6224,.1544],[-.6341,.1543],[-.6457,.1542],[-.6573,.1541],[-.6689,.1541],[-.6805,.154],[-.6921,.1539],[-.7037,.1538],[-.7154,.1538],[-.727,.1537],[-.7386,.1536],[-.7502,.1536],[-.7618,.1535],[-.7734,.1534],[-.7851,.1533],[-.7967,.1533],[-.8083,.1532],[-.8199,.1531],[-.8315,.153],[-.8431,.1529],[-.8548,.1529],[-.8664,.1528],[-.878,.1527],[-.8896,.1526],[-.9012,.1526],[-.9128,.1525],[-.9244,.1524],[-.9361,.1524],[-.9477,.1523],[-.9593,.1522],[-.9709,.1521],[-.9825,.1521],[-.9941,.152],[-1.0058,.1519],[-1.0174,.1518],[-1.029,.1518],[-1.0406,.1517],[-1.0522,.1516],[-1.0638,.1516],[-1.0754,.1515],[-1.0871,.1514],[-1.0987,.1513],[-1.1103,.1513]],at:[[-1.5708,.3464],[1.5708,.3464]],fins:[{side:-1,uv:[.932,.709,.9935,1],x0:-.2041,x1:0,y0:-.5392,y1:-1.1161,outline:[[-.5392,.1584,.1531],[-.545,.1611,.1531],[-.5508,.1638,.1531],[-.5566,.1638,.1531],[-.5624,.1638,.1531],[-.5682,.1638,.1531],[-.574,.1638,.1531],[-.5799,.1638,.1531],[-.5857,.1665,.1531],[-.5915,.1665,.1531],[-.5973,.1665,.1531],[-.6031,.1665,.1531],[-.6089,.1665,.1531],[-.6147,.1692,.1531],[-.6205,.1692,.1531],[-.6263,.1692,.1531],[-.6321,.1692,.1531],[-.6379,.1692,.1531],[-.6437,.1692,.1531],[-.6495,.1692,.1531],[-.6554,.1692,.1531],[-.6612,.1718,.1531],[-.667,.1718,.1531],[-.6728,.1718,.1531],[-.6786,.1718,.1531],[-.6844,.1718,.1531],[-.6902,.1718,.1531],[-.696,.1745,.1531],[-.7018,.1745,.1531],[-.7076,.1745,.1531],[-.7134,.1745,.1531],[-.7192,.1745,.1531],[-.725,.1745,.1531],[-.7309,.1745,.1531],[-.7367,.1772,.1531],[-.7425,.1772,.1531],[-.7483,.1772,.1531],[-.7541,.1772,.1531],[-.7599,.1772,.1531],[-.7657,.1772,.1531],[-.7715,.1772,.1531],[-.7773,.1799,.1531],[-.7831,.1799,.1531],[-.7889,.1799,.1531],[-.7947,.1799,.1531],[-.8005,.1799,.1531],[-.8064,.1799,.1531],[-.8122,.1799,.1531],[-.818,.1826,.1531],[-.8238,.1826,.1531],[-.8296,.1826,.1531],[-.8354,.1826,.1531],[-.8412,.1826,.1531],[-.847,.1826,.1531],[-.8528,.1853,.1531],[-.8586,.1853,.1531],[-.8644,.1853,.1531],[-.8702,.1853,.1531],[-.876,.1853,.1531],[-.8819,.1853,.1531],[-.8877,.1853,.1531],[-.8935,.1853,.1531],[-.8993,.1879,.1531],[-.9051,.1879,.1531],[-.9109,.1879,.1531],[-.9167,.1879,.1531],[-.9225,.1879,.1531],[-.9283,.1906,.1531],[-.9341,.1906,.1531],[-.9399,.1906,.1531],[-.9457,.1906,.1531],[-.9515,.1906,.1531],[-.9574,.1933,.1531],[-.9632,.1933,.1531],[-.969,.1933,.1531],[-.9748,.1933,.1531],[-.9806,.1933,.1531],[-.9864,.1933,.1531],[-.9922,.196,.1531],[-.998,.196,.1531],[-1.0038,.196,.1531],[-1.0096,.196,.1531],[-1.0154,.196,.1531],[-1.0212,.196,.1531],[-1.027,.196,.1531],[-1.0329,.1987,.1531],[-1.0387,.1987,.1531],[-1.0445,.1987,.1531],[-1.0503,.1987,.1531],[-1.0561,.2014,.1531],[-1.0619,.2014,.1531],[-1.0677,.2014,.1531],[-1.0735,.2014,.1531],[-1.0793,.2014,.1531],[-1.0851,.1906,.1531],[-1.0909,.1853,.1531],[-1.0967,.1772,.1531],[-1.1025,.1692,.1531],[-1.1084,.1665,.1531],[-1.1142,.1665,.1531]]}],finsAround:4,finsFrom:null,engines:{ring:8,centre:!0,f:.34,colour:[60,58,55],profile:[[-1.1103,.1645],[-1.1142,.1645],[-1.118,.1645],[-1.1219,.1644],[-1.1258,.1671],[-1.1297,.167],[-1.1335,.167],[-1.1374,.167],[-1.1413,.1643],[-1.1451,.1563],[-1.149,.151],[-1.1529,.151],[-1.1568,.1457],[-1.1606,.1456],[-1.1645,.1483],[-1.1684,.1509],[-1.1722,.1535],[-1.1761,.1535],[-1.18,.1561],[-1.1839,.1587],[-1.1877,.1587],[-1.1916,.1613],[-1.1955,.1639],[-1.1993,.1639],[-1.2032,.1665],[-1.2071,.1692],[-1.211,.1691],[-1.2148,.1717],[-1.2187,.1744],[-1.2226,.169],[-1.2264,.1585],[-1.2303,.132],[-1.2342,.0924]]}}],badge:{y:.9137,d:.251,r:.1673},band:[.7551,.774],head:{top:1.6,cut:1.0723,mean:.7752,r:.2062}},newGlenn:{id:"new-glenn",shape:"newGlenn",atlas:{w:897,h:1142,cap:[.9933,.9947,.9978,.9982]},parts:[{name:"core",uv:[0,.1033,.8562,1],top:1.6,end:-1.1485,profile:[[1.6,.0169],[1.5886,.0402],[1.5771,.0587],[1.5657,.0741],[1.5543,.0879],[1.5428,.1001],[1.5314,.1112],[1.5199,.1216],[1.5085,.1311],[1.4971,.1398],[1.4856,.1476],[1.4742,.1546],[1.4628,.1608],[1.4513,.1666],[1.4399,.1717],[1.4285,.1762],[1.417,.1798],[1.4056,.1828],[1.3941,.1851],[1.3827,.1868],[1.3713,.1879],[1.3598,.1885],[1.3484,.1888],[1.337,.1889],[1.3255,.1888],[1.3141,.1887],[1.3027,.1885],[1.2912,.1883],[1.2798,.1881],[1.2683,.1879],[1.2569,.1878],[1.2455,.1876],[1.234,.1874],[1.2226,.1873],[1.2112,.1871],[1.1997,.187],[1.1883,.1871],[1.1769,.1873],[1.1654,.1876],[1.154,.1877],[1.1426,.1876],[1.1311,.1875],[1.1197,.1873],[1.1082,.1871],[1.0968,.1871],[1.0854,.1875],[1.0739,.1881],[1.0625,.1882],[1.0511,.1874],[1.0396,.1865],[1.0282,.186],[1.0168,.1858],[1.0053,.1856],[.9939,.1854],[.9824,.1852],[.971,.1851],[.9596,.1849],[.9481,.1848],[.9367,.1846],[.9253,.1845],[.9138,.1845],[.9024,.1848],[.891,.1851],[.8795,.1852],[.8681,.1852],[.8566,.1852],[.8452,.1855],[.8338,.1858],[.8223,.1859],[.8109,.1858],[.7995,.1856],[.788,.1855],[.7766,.1853],[.7652,.1852],[.7537,.1853],[.7423,.1856],[.7308,.1859],[.7194,.1859],[.708,.1858],[.6965,.1856],[.6851,.1854],[.6737,.1852],[.6622,.1854],[.6508,.1862],[.6394,.1869],[.6279,.1869],[.6165,.1864],[.605,.1862],[.5936,.1866],[.5822,.1873],[.5707,.1879],[.5593,.1881],[.5479,.188],[.5364,.1878],[.525,.1877],[.5136,.1875],[.5021,.1873],[.4907,.1872],[.4792,.1871],[.4678,.187],[.4564,.1869],[.4449,.1869],[.4335,.1869],[.4221,.1869],[.4106,.187],[.3992,.1872],[.3878,.1873],[.3763,.1876],[.3649,.1879],[.3534,.1883],[.342,.1888],[.3306,.1894],[.3191,.19],[.3077,.1902],[.2963,.1902],[.2848,.1901],[.2734,.19],[.262,.1898],[.2505,.1896],[.2391,.1895],[.2277,.1893],[.2162,.1891],[.2048,.189],[.1933,.1888],[.1819,.1887],[.1705,.1885],[.159,.1883],[.1476,.1883],[.1362,.1883],[.1247,.1887],[.1133,.1893],[.1019,.1898],[.0904,.19],[.079,.19],[.0675,.1899],[.0561,.1898],[.0447,.1896],[.0332,.1894],[.0218,.1893],[.0104,.1891],[-.0011,.189],[-.0125,.1888],[-.0239,.1887],[-.0354,.1885],[-.0468,.1884],[-.0583,.1885],[-.0697,.1888],[-.0811,.1891],[-.0926,.1891],[-.104,.1891],[-.1154,.1893],[-.1269,.1896],[-.1383,.1898],[-.1497,.1897],[-.1612,.1896],[-.1726,.1894],[-.1841,.1893],[-.1955,.1891],[-.2069,.189],[-.2184,.1889],[-.2298,.189],[-.2412,.1898],[-.2527,.192],[-.2641,.1961],[-.2755,.2008],[-.287,.2041],[-.2984,.2054],[-.3099,.2056],[-.3213,.2055],[-.3327,.2053],[-.3442,.2051],[-.3556,.205],[-.367,.2048],[-.3785,.2046],[-.3899,.2045],[-.4013,.2043],[-.4128,.2042],[-.4242,.204],[-.4357,.2038],[-.4471,.2036],[-.4585,.2035],[-.47,.2033],[-.4814,.2032],[-.4928,.203],[-.5043,.2028],[-.5157,.2027],[-.5271,.2025],[-.5386,.2023],[-.55,.2022],[-.5614,.202],[-.5729,.2018],[-.5843,.2017],[-.5958,.2015],[-.6072,.2014],[-.6186,.2012],[-.6301,.2011],[-.6415,.2009],[-.6529,.2007],[-.6644,.2006],[-.6758,.2004],[-.6872,.2003],[-.6987,.2001],[-.7101,.1999],[-.7216,.1998],[-.733,.1996],[-.7444,.1995],[-.7559,.1993],[-.7673,.1991],[-.7787,.199],[-.7902,.1988],[-.8016,.1987],[-.813,.1985],[-.8245,.1984],[-.8359,.1982],[-.8474,.198],[-.8588,.1979],[-.8702,.1977],[-.8817,.1976],[-.8931,.1974],[-.9045,.1973],[-.916,.1971],[-.9274,.197],[-.9388,.1968],[-.9503,.1966],[-.9617,.1965],[-.9732,.1963],[-.9846,.1962],[-.996,.196],[-1.0075,.1959],[-1.0189,.1957],[-1.0303,.1956],[-1.0418,.1954],[-1.0532,.1953],[-1.0646,.1951],[-1.0761,.195],[-1.0875,.1948],[-1.099,.1947],[-1.1104,.1945],[-1.1218,.1944],[-1.1333,.1942],[-1.1447,.1941],[-1.1485,.194]],at:[[0,0]],fins:[{side:-1,uv:[.8562,.9002,.971,1],x0:-.3011,x1:.0015,y0:.5517,y1:.3344,outline:[[.5517,.1865,.1865],[.546,.2012,.1865],[.5402,.2159,.1865],[.5345,.2306,.1865],[.5288,.2423,.1865],[.5231,.2541,.1865],[.5174,.2688,.1865],[.5117,.2834,.1865],[.5059,.2952,.1865],[.5002,.2982,.1865],[.4945,.2982,.1865],[.4888,.2982,.1866],[.4831,.2982,.1866],[.4773,.2982,.1866],[.4716,.2982,.1866],[.4659,.2982,.1867],[.4602,.2952,.1867],[.4545,.2834,.1868],[.4488,.2746,.1869],[.443,.2629,.1869],[.4373,.2541,.187],[.4316,.2453,.1871],[.4259,.2335,.1872],[.4202,.2247,.1873],[.4144,.2247,.1874],[.4087,.2247,.1875],[.403,.2247,.1877],[.3973,.2247,.1879],[.3916,.2247,.188],[.3859,.2247,.1882],[.3801,.2247,.1884],[.3744,.2247,.1886],[.3687,.2218,.1889],[.363,.213,.1891],[.3573,.2042,.1894],[.3515,.1953,.1897],[.3458,.1924,.19],[.3401,.1894,.1904],[.3363,.1894,.1906]]},{side:1,uv:[.8562,.7986,.9721,.8984],x0:-.0015,x1:.304,y0:.5517,y1:.3344,outline:[[.5517,.1865,.1865],[.546,.1953,.1865],[.5402,.2042,.1865],[.5345,.213,.1865],[.5288,.2247,.1865],[.5231,.2365,.1865],[.5174,.2482,.1865],[.5117,.26,.1865],[.5059,.2717,.1865],[.5002,.2805,.1865],[.4945,.2893,.1865],[.4888,.2982,.1866],[.4831,.3011,.1866],[.4773,.3011,.1866],[.4716,.3011,.1866],[.4659,.3011,.1867],[.4602,.3011,.1867],[.4545,.3011,.1868],[.4488,.3011,.1869],[.443,.2952,.1869],[.4373,.2834,.187],[.4316,.2746,.1871],[.4259,.2658,.1872],[.4202,.257,.1873],[.4144,.2453,.1874],[.4087,.2335,.1875],[.403,.2247,.1877],[.3973,.2218,.1879],[.3916,.2218,.188],[.3859,.2218,.1882],[.3801,.2247,.1884],[.3744,.2247,.1886],[.3687,.2247,.1889],[.363,.2247,.1891],[.3573,.2218,.1894],[.3515,.2159,.1897],[.3458,.2071,.19],[.3401,.1983,.1904],[.3363,.1924,.1906]]},{side:-1,uv:[.8562,.4002,.9911,.7968],x0:-.3253,x1:.0013,y0:-.2908,y1:-1.1542,outline:[[-.2908,.2038,.1986],[-.2965,.2065,.1992],[-.3022,.2092,.1995],[-.3079,.2146,.1997],[-.3137,.2146,.1997],[-.3194,.2173,.1998],[-.3251,.22,.1998],[-.3308,.2227,.1998],[-.3365,.2254,.1998],[-.3423,.2281,.1998],[-.348,.2308,.1998],[-.3537,.2335,.1998],[-.3594,.2389,.1998],[-.3651,.2416,.1998],[-.3708,.2443,.1998],[-.3766,.247,.1998],[-.3823,.2497,.1998],[-.388,.2524,.1998],[-.3937,.2551,.1998],[-.3994,.2578,.1998],[-.4052,.2605,.1998],[-.4109,.2632,.1998],[-.4166,.2659,.1998],[-.4223,.2686,.1998],[-.428,.2713,.1998],[-.4337,.274,.1998],[-.4395,.2767,.1998],[-.4452,.2794,.1998],[-.4509,.2821,.1998],[-.4566,.2848,.1998],[-.4623,.2875,.1998],[-.4681,.2902,.1998],[-.4738,.2929,.1998],[-.4795,.2956,.1998],[-.4852,.2983,.1998],[-.4909,.301,.1998],[-.4966,.3037,.1998],[-.5024,.3037,.1998],[-.5081,.3064,.1998],[-.5138,.3091,.1998],[-.5195,.3091,.1998],[-.5252,.3118,.1998],[-.531,.3118,.1998],[-.5367,.3145,.1998],[-.5424,.3145,.1998],[-.5481,.3145,.1998],[-.5538,.3145,.1998],[-.5595,.3145,.1998],[-.5653,.3172,.1998],[-.571,.3172,.1998],[-.5767,.3172,.1998],[-.5824,.3172,.1998],[-.5881,.3172,.1998],[-.5939,.3172,.1998],[-.5996,.3172,.1998],[-.6053,.3172,.1998],[-.611,.3172,.1998],[-.6167,.3172,.1998],[-.6224,.3199,.1998],[-.6282,.3199,.1998],[-.6339,.3199,.1998],[-.6396,.3199,.1998],[-.6453,.3199,.1998],[-.651,.3199,.1998],[-.6568,.3199,.1998],[-.6625,.3199,.1998],[-.6682,.3199,.1998],[-.6739,.3199,.1998],[-.6796,.3199,.1998],[-.6853,.3226,.1998],[-.6911,.3226,.1998],[-.6968,.3226,.1998],[-.7025,.3226,.1998],[-.7082,.3226,.1998],[-.7139,.3226,.1998],[-.7197,.3226,.1998],[-.7254,.3226,.1998],[-.7311,.3199,.1998],[-.7368,.3199,.1998],[-.7425,.3199,.1998],[-.7482,.3199,.1998],[-.754,.3199,.1998],[-.7597,.3172,.1998],[-.7654,.3172,.1998],[-.7711,.3172,.1998],[-.7768,.3172,.1998],[-.7826,.3172,.1998],[-.7883,.3145,.1998],[-.794,.3145,.1998],[-.7997,.3145,.1998],[-.8054,.3145,.1998],[-.8111,.3145,.1998],[-.8169,.3118,.1998],[-.8226,.3118,.1998],[-.8283,.3118,.1998],[-.834,.3118,.1998],[-.8397,.3091,.1998],[-.8454,.3091,.1998],[-.8512,.3091,.1998],[-.8569,.3091,.1998],[-.8626,.3091,.1998],[-.8683,.3091,.1998],[-.874,.3064,.1998],[-.8798,.3064,.1998],[-.8855,.3064,.1998],[-.8912,.3064,.1998],[-.8969,.3064,.1998],[-.9026,.3064,.1998],[-.9083,.3037,.1998],[-.9141,.3037,.1998],[-.9198,.3037,.1998],[-.9255,.3037,.1998],[-.9312,.3037,.1998],[-.9369,.3037,.1998],[-.9427,.3037,.1998],[-.9484,.301,.1998],[-.9541,.301,.1998],[-.9598,.301,.1998],[-.9655,.301,.1998],[-.9712,.301,.1998],[-.977,.2983,.1998],[-.9827,.2983,.1998],[-.9884,.2983,.1998],[-.9941,.2983,.1998],[-.9998,.2983,.1998],[-1.0056,.2956,.1998],[-1.0113,.2956,.1998],[-1.017,.2929,.1998],[-1.0227,.2902,.1998],[-1.0284,.2875,.1998],[-1.0341,.2848,.1998],[-1.0399,.2848,.1998],[-1.0456,.2848,.1998],[-1.0513,.2848,.1998],[-1.057,.2848,.1998],[-1.0627,.2848,.1998],[-1.0685,.2848,.1998],[-1.0742,.2848,.1998],[-1.0799,.2848,.1998],[-1.0856,.2848,.1998],[-1.0913,.2848,.1998],[-1.097,.2848,.1998],[-1.1028,.2848,.1998],[-1.1085,.2848,.1998],[-1.1142,.2848,.1998],[-1.1199,.2848,.1998],[-1.1256,.2848,.1998],[-1.1314,.2821,.1998],[-1.1371,.2821,.1998],[-1.1428,.2794,.1998],[-1.1485,.274,.1998],[-1.1523,.2686,.1998]]},{side:1,uv:[.8562,.0018,.99,.3984],x0:-.0013,x1:.3226,y0:-.2908,y1:-1.1542,outline:[[-.2908,.2038,.1986],[-.2965,.2065,.1992],[-.3022,.2092,.1995],[-.3079,.2119,.1997],[-.3137,.2146,.1997],[-.3194,.2173,.1998],[-.3251,.22,.1998],[-.3308,.2227,.1998],[-.3365,.2281,.1998],[-.3423,.2308,.1998],[-.348,.2335,.1998],[-.3537,.2362,.1998],[-.3594,.2389,.1998],[-.3651,.2416,.1998],[-.3708,.2443,.1998],[-.3766,.247,.1998],[-.3823,.2497,.1998],[-.388,.2524,.1998],[-.3937,.2551,.1998],[-.3994,.2578,.1998],[-.4052,.2605,.1998],[-.4109,.2632,.1998],[-.4166,.2659,.1998],[-.4223,.2686,.1998],[-.428,.2713,.1998],[-.4337,.274,.1998],[-.4395,.2767,.1998],[-.4452,.2794,.1998],[-.4509,.2821,.1998],[-.4566,.2848,.1998],[-.4623,.2875,.1998],[-.4681,.2902,.1998],[-.4738,.2929,.1998],[-.4795,.2956,.1998],[-.4852,.2983,.1998],[-.4909,.301,.1998],[-.4966,.3037,.1998],[-.5024,.3037,.1998],[-.5081,.3064,.1998],[-.5138,.3091,.1998],[-.5195,.3091,.1998],[-.5252,.3118,.1998],[-.531,.3118,.1998],[-.5367,.3118,.1998],[-.5424,.3145,.1998],[-.5481,.3145,.1998],[-.5538,.3145,.1998],[-.5595,.3145,.1998],[-.5653,.3145,.1998],[-.571,.3145,.1998],[-.5767,.3145,.1998],[-.5824,.3172,.1998],[-.5881,.3172,.1998],[-.5939,.3172,.1998],[-.5996,.3172,.1998],[-.6053,.3172,.1998],[-.611,.3172,.1998],[-.6167,.3172,.1998],[-.6224,.3172,.1998],[-.6282,.3172,.1998],[-.6339,.3172,.1998],[-.6396,.3172,.1998],[-.6453,.3172,.1998],[-.651,.3172,.1998],[-.6568,.3199,.1998],[-.6625,.3199,.1998],[-.6682,.3199,.1998],[-.6739,.3199,.1998],[-.6796,.3199,.1998],[-.6853,.3199,.1998],[-.6911,.3199,.1998],[-.6968,.3199,.1998],[-.7025,.3199,.1998],[-.7082,.3199,.1998],[-.7139,.3199,.1998],[-.7197,.3199,.1998],[-.7254,.3199,.1998],[-.7311,.3199,.1998],[-.7368,.3199,.1998],[-.7425,.3199,.1998],[-.7482,.3199,.1998],[-.754,.3172,.1998],[-.7597,.3172,.1998],[-.7654,.3172,.1998],[-.7711,.3172,.1998],[-.7768,.3172,.1998],[-.7826,.3145,.1998],[-.7883,.3145,.1998],[-.794,.3145,.1998],[-.7997,.3145,.1998],[-.8054,.3118,.1998],[-.8111,.3118,.1998],[-.8169,.3118,.1998],[-.8226,.3118,.1998],[-.8283,.3118,.1998],[-.834,.3091,.1998],[-.8397,.3091,.1998],[-.8454,.3091,.1998],[-.8512,.3091,.1998],[-.8569,.3064,.1998],[-.8626,.3064,.1998],[-.8683,.3064,.1998],[-.874,.3064,.1998],[-.8798,.3064,.1998],[-.8855,.3037,.1998],[-.8912,.3037,.1998],[-.8969,.3037,.1998],[-.9026,.3037,.1998],[-.9083,.3037,.1998],[-.9141,.3037,.1998],[-.9198,.3037,.1998],[-.9255,.301,.1998],[-.9312,.301,.1998],[-.9369,.301,.1998],[-.9427,.301,.1998],[-.9484,.301,.1998],[-.9541,.301,.1998],[-.9598,.2983,.1998],[-.9655,.2983,.1998],[-.9712,.2983,.1998],[-.977,.2983,.1998],[-.9827,.2983,.1998],[-.9884,.2983,.1998],[-.9941,.2956,.1998],[-.9998,.2956,.1998],[-1.0056,.2956,.1998],[-1.0113,.2929,.1998],[-1.017,.2902,.1998],[-1.0227,.2875,.1998],[-1.0284,.2875,.1998],[-1.0341,.2848,.1998],[-1.0399,.2848,.1998],[-1.0456,.2848,.1998],[-1.0513,.2848,.1998],[-1.057,.2848,.1998],[-1.0627,.2848,.1998],[-1.0685,.2848,.1998],[-1.0742,.2848,.1998],[-1.0799,.2848,.1998],[-1.0856,.2848,.1998],[-1.0913,.2848,.1998],[-1.097,.2848,.1998],[-1.1028,.2848,.1998],[-1.1085,.2848,.1998],[-1.1142,.2848,.1998],[-1.1199,.2848,.1998],[-1.1256,.2848,.1998],[-1.1314,.2821,.1998],[-1.1371,.2821,.1998],[-1.1428,.2794,.1998],[-1.1485,.2713,.1998],[-1.1523,.2659,.1998]]}],finsAround:2,finsFrom:null,engines:{ring:6,centre:!0,f:.3,colour:[80,79,78],profile:[[-1.1485,.2648],[-1.1523,.2595],[-1.1561,.2516],[-1.1599,.2463],[-1.1638,.241],[-1.1676,.2461],[-1.1714,.2487],[-1.1752,.2512],[-1.179,.2538],[-1.1828,.255],[-1.1866,.2576],[-1.1904,.2601],[-1.1943,.2614],[-1.1981,.2639],[-1.2019,.2652],[-1.2057,.2664],[-1.2095,.2689],[-1.2133,.2702],[-1.2171,.2714],[-1.2209,.2687],[-1.2248,.2543],[-1.2286,.1734],[-1.2324,.1773],[-1.2362,.1759],[-1.24,.1576]]}}],badge:{y:.9137,d:.2768,r:.1845},band:[.7422,.7611],head:{top:1.6,cut:1.0852,mean:.6111,r:.2159}},vulcan:{id:"vulcan",shape:"vulcan",atlas:{w:1160,h:1024,cap:[.9948,.9941,.9983,.998]},parts:[{name:"core",uv:[0,0,.6621,1],top:1.6,end:-1.0752,profile:[[1.6,.0147],[1.5884,.0337],[1.5767,.0482],[1.5651,.0614],[1.5535,.0738],[1.5418,.0854],[1.5302,.0963],[1.5186,.1066],[1.5069,.1166],[1.4953,.1261],[1.4837,.1351],[1.4721,.1436],[1.4604,.1518],[1.4488,.1595],[1.4372,.1668],[1.4255,.1735],[1.4139,.1798],[1.4023,.1856],[1.3906,.1911],[1.379,.1963],[1.3674,.2012],[1.3557,.2057],[1.3441,.2099],[1.3325,.2137],[1.3208,.2171],[1.3092,.2202],[1.2976,.2228],[1.286,.2252],[1.2743,.2273],[1.2627,.229],[1.2511,.2305],[1.2394,.2316],[1.2278,.2323],[1.2162,.2327],[1.2045,.2328],[1.1929,.2326],[1.1813,.2325],[1.1696,.2326],[1.158,.2325],[1.1464,.2325],[1.1347,.2326],[1.1231,.2327],[1.1115,.2326],[1.0998,.2322],[1.0882,.2317],[1.0766,.2315],[1.065,.2314],[1.0533,.2311],[1.0417,.2307],[1.0301,.2306],[1.0184,.2308],[1.0068,.2311],[.9952,.2312],[.9835,.2311],[.9719,.2309],[.9603,.2307],[.9486,.2304],[.937,.2298],[.9254,.2292],[.9137,.2289],[.9021,.2287],[.8905,.2287],[.8789,.2288],[.8672,.229],[.8556,.2289],[.844,.2285],[.8323,.2282],[.8207,.2279],[.8091,.2279],[.7974,.228],[.7858,.2278],[.7742,.2273],[.7625,.227],[.7509,.2266],[.7393,.2254],[.7276,.2226],[.716,.2181],[.7044,.2128],[.6928,.2072],[.6811,.2015],[.6695,.196],[.6579,.1907],[.6462,.1855],[.6346,.1806],[.623,.1765],[.6113,.1743],[.5997,.1747],[.5881,.1766],[.5764,.1791],[.5648,.1818],[.5532,.1846],[.5415,.1876],[.5299,.1906],[.5183,.1938],[.5066,.1969],[.495,.2],[.4834,.2031],[.4718,.2062],[.4601,.2088],[.4485,.2104],[.4369,.2108],[.4252,.2104],[.4136,.2102],[.402,.2102],[.3903,.2101],[.3787,.21],[.3671,.2099],[.3554,.2098],[.3438,.2097],[.3322,.2095],[.3205,.2094],[.3089,.2093],[.2973,.2093],[.2857,.2094],[.274,.2094],[.2624,.2091],[.2508,.2088],[.2391,.2086],[.2275,.2084],[.2159,.2083],[.2042,.2082],[.1926,.208],[.181,.2079],[.1693,.2078],[.1577,.2077],[.1461,.2075],[.1344,.2074],[.1228,.2073],[.1112,.2072],[.0995,.2071],[.0879,.2069],[.0763,.2068],[.0647,.2067],[.053,.2066],[.0414,.2065],[.0298,.2063],[.0181,.2062],[.0065,.2061],[-.0051,.206],[-.0168,.2059],[-.0284,.2057],[-.04,.2056],[-.0517,.2055],[-.0633,.2054],[-.0749,.2052],[-.0866,.2051],[-.0982,.205],[-.1098,.2049],[-.1214,.2048],[-.1331,.2046],[-.1447,.2045],[-.1563,.2044],[-.168,.2043],[-.1796,.2042],[-.1912,.2041],[-.2029,.2039],[-.2145,.2038],[-.2261,.2037],[-.2378,.2036],[-.2494,.2035],[-.261,.2033],[-.2727,.2032],[-.2843,.2031],[-.2959,.203],[-.3075,.2029],[-.3192,.2028],[-.3308,.2026],[-.3424,.2025],[-.3541,.2024],[-.3657,.2023],[-.3773,.2022],[-.389,.202],[-.4006,.2019],[-.4122,.2018],[-.4239,.2017],[-.4355,.2016],[-.4471,.2015],[-.4588,.2013],[-.4704,.2012],[-.482,.2011],[-.4937,.201],[-.5053,.2009],[-.5169,.2008],[-.5285,.2007],[-.5402,.2005],[-.5518,.2004],[-.5634,.2003],[-.5751,.2002],[-.5867,.2001],[-.5983,.2],[-.61,.1999],[-.6216,.1997],[-.6332,.1996],[-.6449,.1995],[-.6565,.1994],[-.6681,.1993],[-.6798,.1992],[-.6914,.1991],[-.703,.199],[-.7146,.1988],[-.7263,.1987],[-.7379,.1986],[-.7495,.1985],[-.7612,.1984],[-.7728,.1983],[-.7844,.1982],[-.7961,.1981],[-.8077,.1979],[-.8193,.1978],[-.831,.1977],[-.8426,.1976],[-.8542,.1975],[-.8659,.1974],[-.8775,.1973],[-.8891,.1972],[-.9008,.1971],[-.9124,.1969],[-.924,.1968],[-.9356,.1967],[-.9473,.1966],[-.9589,.1965],[-.9705,.1964],[-.9822,.1963],[-.9938,.1962],[-1.0054,.1961],[-1.0171,.196],[-1.0287,.1958],[-1.0403,.1957],[-1.052,.1956],[-1.0636,.1955],[-1.0752,.1954]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:2,centre:!1,f:.5,colour:[62,59,55],profile:[[-1.0752,.1556],[-1.0791,.1542],[-1.083,.1516],[-1.0869,.149],[-1.0907,.1464],[-1.0946,.1464],[-1.0985,.1464],[-1.1024,.1489],[-1.1062,.1489],[-1.1101,.1514],[-1.114,.1527],[-1.1179,.154],[-1.1217,.1565],[-1.1256,.159],[-1.1295,.159],[-1.1334,.1615],[-1.1373,.1628],[-1.1411,.164],[-1.145,.1653],[-1.1489,.1665],[-1.1528,.1691],[-1.1566,.169],[-1.1605,.1716],[-1.1644,.1715],[-1.1683,.1728],[-1.1722,.174],[-1.176,.1753],[-1.1799,.1765],[-1.1838,.1778],[-1.1877,.179],[-1.1915,.1803],[-1.1954,.1802],[-1.1993,.1827],[-1.2032,.1827],[-1.207,.184],[-1.2109,.1852],[-1.2148,.1852],[-1.2187,.1864],[-1.2226,.1864],[-1.2264,.1863],[-1.2303,.1812],[-1.2342,.1684],[-1.2381,.1416]]}},{name:"booster",uv:[.6621,.3447,.9931,1],top:.2159,end:-1.083,profile:[[.2159,.0039],[.2042,.011],[.1926,.0173],[.181,.0238],[.1693,.0299],[.1577,.0355],[.1461,.041],[.1344,.0465],[.1228,.0521],[.1112,.0579],[.0995,.0635],[.0879,.069],[.0763,.0741],[.0647,.0782],[.053,.0806],[.0414,.0813],[.0298,.0814],[.0181,.0815],[.0065,.0818],[-.0051,.0826],[-.0168,.0834],[-.0284,.0838],[-.04,.0839],[-.0517,.0838],[-.0633,.0838],[-.0749,.0837],[-.0866,.0837],[-.0982,.0838],[-.1098,.0839],[-.1214,.0837],[-.1331,.0835],[-.1447,.0834],[-.1563,.0834],[-.168,.0833],[-.1796,.0833],[-.1912,.0832],[-.2029,.0832],[-.2145,.0831],[-.2261,.0831],[-.2378,.0831],[-.2494,.083],[-.261,.0829],[-.2727,.0829],[-.2843,.0829],[-.2959,.0828],[-.3075,.0828],[-.3192,.0829],[-.3308,.083],[-.3424,.0828],[-.3541,.0826],[-.3657,.0825],[-.3773,.0825],[-.389,.0824],[-.4006,.0824],[-.4122,.0823],[-.4239,.0823],[-.4355,.0822],[-.4471,.0822],[-.4588,.0821],[-.4704,.0821],[-.482,.0821],[-.4937,.0821],[-.5053,.0821],[-.5169,.0822],[-.5285,.0821],[-.5402,.0819],[-.5518,.0818],[-.5634,.0817],[-.5751,.0817],[-.5867,.0816],[-.5983,.0816],[-.61,.0815],[-.6216,.0815],[-.6332,.0814],[-.6449,.0814],[-.6565,.0813],[-.6681,.0813],[-.6798,.0813],[-.6914,.0813],[-.703,.0813],[-.7146,.0812],[-.7263,.0811],[-.7379,.081],[-.7495,.081],[-.7612,.0809],[-.7728,.0809],[-.7844,.0808],[-.7961,.0808],[-.8077,.0807],[-.8193,.0807],[-.831,.0806],[-.8426,.0806],[-.8542,.0806],[-.8659,.0806],[-.8775,.0807],[-.8891,.0808],[-.9008,.0808],[-.9124,.0805],[-.924,.0803],[-.9356,.0803],[-.9473,.0802],[-.9589,.0801],[-.9705,.0801],[-.9822,.0801],[-.9938,.08],[-1.0054,.08],[-1.0171,.0799],[-1.0287,.0798],[-1.0403,.0792],[-1.052,.0775],[-1.0636,.0749],[-1.0752,.0726],[-1.083,.0715]],at:[[-1.5708,.3099],[1.5708,.3099]],fins:[],finsAround:0,finsFrom:null,engines:{ring:0,centre:!0,f:1,colour:[88,83,79],profile:[[-1.083,.0694],[-1.0869,.0668],[-1.0907,.0668],[-1.0946,.0668],[-1.0985,.0642],[-1.1024,.0642],[-1.1062,.0616],[-1.1101,.0539],[-1.114,.0462],[-1.1179,.0462],[-1.1217,.0462],[-1.1256,.0487],[-1.1295,.0487],[-1.1334,.0513],[-1.1373,.0513],[-1.1411,.0538],[-1.145,.0538],[-1.1489,.0564],[-1.1528,.0564],[-1.1566,.0589],[-1.1605,.0589],[-1.1644,.0614],[-1.1683,.0614],[-1.1722,.064],[-1.176,.064],[-1.1799,.0665],[-1.1838,.0665],[-1.1877,.069],[-1.1915,.069],[-1.1954,.0716],[-1.1993,.0716],[-1.2032,.0741],[-1.207,.0741],[-1.2109,.0664],[-1.2148,.0281]]}}],badge:{y:.9137,d:.3434,r:.2289},band:[.7089,.7278],head:{top:1.6,cut:1.1185,mean:.8006,r:.2444}},cz2f:{id:"long-march-2f",shape:"cz2f",atlas:{w:1160,h:1024,cap:[.9948,.9941,.9983,.998]},parts:[{name:"core",uv:[0,0,.6621,1],top:1.5981,end:-1.1021,profile:[[1.5981,.0102],[1.5864,.0199],[1.5747,.0267],[1.5631,.031],[1.5514,.0329],[1.5398,.0333],[1.5281,.0336],[1.5165,.0345],[1.5048,.0363],[1.4932,.0387],[1.4815,.0404],[1.4698,.0395],[1.4582,.0379],[1.4465,.0378],[1.4349,.0389],[1.4232,.0405],[1.4116,.0435],[1.3999,.0497],[1.3883,.0568],[1.3766,.0581],[1.365,.0526],[1.3533,.047],[1.3416,.0455],[1.33,.0466],[1.3183,.0486],[1.3067,.0508],[1.295,.0533],[1.2834,.0559],[1.2717,.0587],[1.2601,.0614],[1.2484,.064],[1.2367,.0668],[1.2251,.07],[1.2134,.074],[1.2018,.0791],[1.1901,.084],[1.1785,.0891],[1.1668,.0963],[1.1552,.1056],[1.1435,.1157],[1.1318,.1259],[1.1202,.1358],[1.1085,.1455],[1.0969,.1551],[1.0852,.1644],[1.0736,.1734],[1.0619,.1818],[1.0503,.1889],[1.0386,.1945],[1.0269,.1982],[1.0153,.1999],[1.0036,.2004],[.992,.2006],[.9803,.201],[.9687,.2016],[.957,.202],[.9454,.202],[.9337,.202],[.9221,.2021],[.9104,.2028],[.8987,.2042],[.8871,.2056],[.8754,.2056],[.8638,.2041],[.8521,.2024],[.8405,.2015],[.8288,.2012],[.8172,.2011],[.8055,.2012],[.7938,.2016],[.7822,.2024],[.7705,.2026],[.7589,.2016],[.7472,.1997],[.7356,.1962],[.7239,.1908],[.7123,.1844],[.7006,.1786],[.6889,.175],[.6773,.1736],[.6656,.1731],[.654,.1728],[.6423,.1731],[.6307,.1738],[.619,.1735],[.6074,.1717],[.5957,.1696],[.584,.1682],[.5724,.1675],[.5607,.1676],[.5491,.1681],[.5374,.1686],[.5258,.1688],[.5141,.1687],[.5025,.1686],[.4908,.1686],[.4792,.1687],[.4675,.1694],[.4558,.1707],[.4442,.172],[.4325,.1724],[.4209,.1718],[.4092,.1709],[.3976,.1703],[.3859,.1701],[.3743,.1704],[.3626,.171],[.3509,.1715],[.3393,.1716],[.3276,.1716],[.316,.1715],[.3043,.1716],[.2927,.1722],[.281,.1732],[.2694,.174],[.2577,.1738],[.246,.1733],[.2344,.173],[.2227,.1731],[.2111,.1736],[.1994,.174],[.1878,.1737],[.1761,.1728],[.1645,.1719],[.1528,.1716],[.1411,.1719],[.1295,.1721],[.1178,.172],[.1062,.1715],[.0945,.1712],[.0829,.1713],[.0712,.1713],[.0596,.1713],[.0479,.1715],[.0363,.1717],[.0246,.1717],[.0129,.1716],[.0013,.1716],[-.0104,.1717],[-.022,.1719],[-.0337,.1721],[-.0453,.1718],[-.057,.1714],[-.0686,.1711],[-.0803,.1711],[-.092,.171],[-.1036,.1709],[-.1153,.1708],[-.1269,.1707],[-.1386,.1707],[-.1502,.1706],[-.1619,.1705],[-.1735,.1705],[-.1852,.1704],[-.1969,.1703],[-.2085,.1703],[-.2202,.1702],[-.2318,.1701],[-.2435,.1701],[-.2551,.17],[-.2668,.1699],[-.2784,.1698],[-.2901,.1698],[-.3018,.1697],[-.3134,.1696],[-.3251,.1696],[-.3367,.1695],[-.3484,.1694],[-.36,.1694],[-.3717,.1693],[-.3833,.1692],[-.395,.1692],[-.4066,.1691],[-.4183,.169],[-.43,.1689],[-.4416,.1689],[-.4533,.1688],[-.4649,.1687],[-.4766,.1687],[-.4882,.1686],[-.4999,.1685],[-.5115,.1684],[-.5232,.1684],[-.5349,.1683],[-.5465,.1682],[-.5582,.1682],[-.5698,.1681],[-.5815,.168],[-.5931,.168],[-.6048,.1679],[-.6164,.1678],[-.6281,.1678],[-.6398,.1677],[-.6514,.1677],[-.6631,.1676],[-.6747,.1675],[-.6864,.1674],[-.698,.1674],[-.7097,.1673],[-.7213,.1672],[-.733,.1671],[-.7447,.1671],[-.7563,.167],[-.768,.1669],[-.7796,.1669],[-.7913,.1668],[-.8029,.1667],[-.8146,.1667],[-.8262,.1666],[-.8379,.1665],[-.8495,.1665],[-.8612,.1664],[-.8729,.1663],[-.8845,.1663],[-.8962,.1662],[-.9078,.1661],[-.9195,.1661],[-.9311,.166],[-.9428,.1659],[-.9544,.1659],[-.9661,.1658],[-.9778,.1657],[-.9894,.1657],[-1.0011,.1656],[-1.0127,.1655],[-1.0244,.1655],[-1.036,.1654],[-1.0477,.1654],[-1.0593,.1653],[-1.071,.1652],[-1.0827,.1652],[-1.0943,.1651],[-1.1021,.165]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:4,centre:!1,f:.42,colour:[76,74,72],profile:[[-1.1021,.3699],[-1.106,.3661],[-1.1098,.2617],[-1.1137,.3565],[-1.1176,.2597],[-1.1215,.2616],[-1.1254,.1516],[-1.1293,.1308],[-1.1332,.1194],[-1.137,.1213],[-1.1409,.1212],[-1.1448,.1174],[-1.1487,.1098],[-1.1526,.1041],[-1.1565,.0985],[-1.1604,.0965],[-1.1642,.089],[-1.1681,.0908],[-1.172,.0927],[-1.1759,.0965],[-1.1798,.1003],[-1.1837,.1021],[-1.1876,.104],[-1.1914,.1078],[-1.1953,.1097],[-1.1992,.1134],[-1.2031,.1153],[-1.207,.2344],[-1.2109,.1191],[-1.2147,.1228],[-1.2186,.1228],[-1.2225,.1266],[-1.2264,.1303],[-1.2303,.1265],[-1.2342,.1171],[-1.2381,.0869]]}},{name:"booster",uv:[.6621,.5381,.9931,1],top:-.1852,end:-1.1021,profile:[[-.1852,.0175],[-.1969,.044],[-.2085,.0547],[-.2202,.0633],[-.2318,.0716],[-.2435,.0795],[-.2551,.0873],[-.2668,.0951],[-.2784,.1029],[-.2901,.1109],[-.3018,.1189],[-.3134,.1266],[-.3251,.1336],[-.3367,.1393],[-.3484,.1427],[-.36,.1441],[-.3717,.1444],[-.3833,.1443],[-.395,.144],[-.4066,.1438],[-.4183,.1438],[-.43,.1437],[-.4416,.1437],[-.4533,.1436],[-.4649,.1435],[-.4766,.1435],[-.4882,.1434],[-.4999,.1434],[-.5115,.1437],[-.5232,.1444],[-.5349,.1454],[-.5465,.1462],[-.5582,.1467],[-.5698,.1468],[-.5815,.1468],[-.5931,.1467],[-.6048,.1467],[-.6164,.1466],[-.6281,.1466],[-.6398,.1465],[-.6514,.1464],[-.6631,.1464],[-.6747,.1463],[-.6864,.1463],[-.698,.1462],[-.7097,.1462],[-.7213,.1461],[-.733,.146],[-.7447,.146],[-.7563,.1462],[-.768,.1466],[-.7796,.1467],[-.7913,.1466],[-.8029,.1472],[-.8146,.1483],[-.8262,.149],[-.8379,.1493],[-.8495,.1492],[-.8612,.1492],[-.8729,.1491],[-.8845,.1491],[-.8962,.149],[-.9078,.149],[-.9195,.1489],[-.9311,.1489],[-.9428,.1489],[-.9544,.1492],[-.9661,.1502],[-.9778,.1514],[-.9894,.1521],[-1.0011,.1523],[-1.0127,.1522],[-1.0244,.1521],[-1.036,.1521],[-1.0477,.152],[-1.0593,.151],[-1.071,.1467],[-1.0827,.1367],[-1.0943,.1241],[-1.1021,.117]],at:[[.7854,.401],[2.3562,.401],[3.927,.401],[5.4978,.401]],fins:[],finsAround:0,finsFrom:null,engines:{ring:0,centre:!0,f:1,colour:[76,73,70],profile:[[-1.1021,.1024],[-1.106,.0986],[-1.1098,.0948],[-1.1137,.0834],[-1.1176,.0834],[-1.1215,.0834],[-1.1254,.091],[-1.1293,.091],[-1.1332,.0834],[-1.137,.0872],[-1.1409,.0909],[-1.1448,.0909],[-1.1487,.0947],[-1.1526,.0985],[-1.1565,.1022],[-1.1604,.1022],[-1.1642,.106],[-1.1681,.1098],[-1.172,.1098],[-1.1759,.1135],[-1.1798,.1135],[-1.1837,.1173],[-1.1876,.1173],[-1.1914,.121],[-1.1953,.1248],[-1.1992,.1248],[-1.2031,.1172],[-1.207,.0869]]}}],badge:{y:.9137,d:.3036,r:.2024},band:[.7287,.7477],head:{top:1.1835,cut:1.0702,mean:.8821,r:.2161}},cz5:{id:"long-march-5",shape:"cz5",atlas:{w:1255,h:1024,cap:[.9952,.9941,.9984,.998]},parts:[{name:"core",uv:[0,0,.612,1],top:1.6,end:-1.0981,profile:[[1.6,.0202],[1.5882,.049],[1.5763,.0688],[1.5645,.0849],[1.5527,.0991],[1.5409,.1121],[1.529,.1238],[1.5172,.1345],[1.5054,.1444],[1.4936,.1537],[1.4817,.1625],[1.4699,.1705],[1.4581,.178],[1.4463,.1849],[1.4344,.1914],[1.4226,.1974],[1.4108,.2032],[1.399,.2087],[1.3871,.2138],[1.3753,.2184],[1.3635,.2226],[1.3517,.2265],[1.3398,.2299],[1.328,.233],[1.3162,.2358],[1.3044,.2382],[1.2925,.2403],[1.2807,.2419],[1.2689,.2431],[1.2571,.2438],[1.2452,.2441],[1.2334,.2438],[1.2216,.2435],[1.2098,.2432],[1.1979,.2431],[1.1861,.2429],[1.1743,.2428],[1.1625,.2427],[1.1506,.2429],[1.1388,.2432],[1.127,.2434],[1.1152,.2434],[1.1033,.2433],[1.0915,.2431],[1.0797,.243],[1.0679,.2428],[1.056,.2427],[1.0442,.2425],[1.0324,.2424],[1.0206,.2422],[1.0087,.2421],[.9969,.242],[.9851,.2419],[.9733,.2422],[.9614,.2425],[.9496,.2429],[.9378,.2433],[.926,.2436],[.9141,.2436],[.9023,.2435],[.8905,.2434],[.8787,.2433],[.8668,.2431],[.855,.243],[.8432,.2428],[.8314,.2427],[.8195,.2426],[.8077,.2425],[.7959,.2417],[.7841,.2397],[.7722,.2367],[.7604,.2331],[.7486,.2294],[.7368,.2257],[.7249,.2223],[.7131,.2192],[.7013,.2166],[.6895,.2143],[.6776,.2123],[.6658,.2109],[.654,.2104],[.6422,.2102],[.6303,.2103],[.6185,.2105],[.6067,.2102],[.5949,.2098],[.583,.2095],[.5712,.2094],[.5594,.2092],[.5476,.2091],[.5357,.209],[.5239,.2089],[.5121,.2087],[.5003,.2086],[.4884,.2085],[.4766,.2084],[.4648,.2083],[.453,.2081],[.4411,.208],[.4293,.2079],[.4175,.2078],[.4057,.2076],[.3938,.2075],[.382,.2074],[.3702,.2073],[.3584,.2072],[.3465,.207],[.3347,.2069],[.3229,.2068],[.3111,.2067],[.2992,.2065],[.2874,.2064],[.2756,.2063],[.2638,.2062],[.2519,.2061],[.2401,.2059],[.2283,.2058],[.2165,.2057],[.2046,.2056],[.1928,.2054],[.181,.2053],[.1692,.2052],[.1573,.2051],[.1455,.205],[.1337,.2048],[.1219,.2047],[.11,.2046],[.0982,.2045],[.0864,.2044],[.0746,.2042],[.0627,.2041],[.0509,.204],[.0391,.2039],[.0273,.2038],[.0154,.2037],[.0036,.2036],[-.0082,.2034],[-.02,.2033],[-.0319,.2032],[-.0437,.2031],[-.0555,.2029],[-.0673,.2028],[-.0792,.2027],[-.091,.2026],[-.1028,.2025],[-.1146,.2024],[-.1265,.2023],[-.1383,.2021],[-.1501,.202],[-.1619,.2019],[-.1738,.2018],[-.1856,.2017],[-.1974,.2015],[-.2092,.2014],[-.2211,.2013],[-.2329,.2012],[-.2447,.2011],[-.2565,.201],[-.2684,.2009],[-.2802,.2007],[-.292,.2006],[-.3038,.2005],[-.3157,.2004],[-.3275,.2003],[-.3393,.2002],[-.3511,.2001],[-.363,.1999],[-.3748,.1998],[-.3866,.1997],[-.3984,.1996],[-.4103,.1995],[-.4221,.1994],[-.4339,.1993],[-.4457,.1991],[-.4576,.199],[-.4694,.1989],[-.4812,.1988],[-.493,.1987],[-.5049,.1986],[-.5167,.1985],[-.5285,.1984],[-.5403,.1982],[-.5522,.1981],[-.564,.198],[-.5758,.1979],[-.5876,.1978],[-.5995,.1977],[-.6113,.1976],[-.6231,.1975],[-.6349,.1974],[-.6468,.1973],[-.6586,.1971],[-.6704,.197],[-.6822,.1969],[-.6941,.1968],[-.7059,.1967],[-.7177,.1966],[-.7295,.1965],[-.7414,.1964],[-.7532,.1963],[-.765,.1962],[-.7768,.196],[-.7887,.1959],[-.8005,.1958],[-.8123,.1957],[-.8241,.1956],[-.836,.1955],[-.8478,.1954],[-.8596,.1953],[-.8715,.1952],[-.8833,.1951],[-.8951,.1949],[-.9069,.1948],[-.9188,.1947],[-.9306,.1946],[-.9424,.1945],[-.9542,.1944],[-.9661,.1943],[-.9779,.1942],[-.9897,.1941],[-1.0015,.194],[-1.0134,.1939],[-1.0252,.1938],[-1.037,.1936],[-1.0488,.1935],[-1.0607,.1934],[-1.0725,.1933],[-1.0843,.1932],[-1.0961,.1931]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:2,centre:!1,f:.5,colour:[44,40,35],profile:[[-1.0981,.178],[-1.102,.1792],[-1.106,.1804],[-1.1099,.1829],[-1.1139,.1841],[-1.1178,.1854],[-1.1217,.1878],[-1.1257,.1903],[-1.1296,.1903],[-1.1336,.1928],[-1.1375,.1927],[-1.1415,.1952],[-1.1454,.1977],[-1.1493,.1977],[-1.1533,.1989],[-1.1572,.2001],[-1.1612,.2001],[-1.1651,.2026],[-1.169,.2025],[-1.173,.2037],[-1.1769,.205],[-1.1809,.2049],[-1.1848,.2061],[-1.1888,.2074],[-1.1927,.2086],[-1.1966,.2085],[-1.2006,.211],[-1.2045,.211],[-1.2085,.2109],[-1.2124,.2122],[-1.2163,.2134],[-1.2203,.2133],[-1.2242,.2133],[-1.2282,.2133],[-1.2321,.2082],[-1.2361,.1906],[-1.24,.1379]]}},{name:"booster",uv:[.612,.25,.9179,1],top:.4135,end:-1.0981,profile:[[.4135,.0016],[.4017,.009],[.3899,.0182],[.3781,.0264],[.3662,.0345],[.3544,.0426],[.3426,.0507],[.3308,.0587],[.3189,.0664],[.3071,.0742],[.2953,.0822],[.2835,.0903],[.2716,.0983],[.2598,.1064],[.248,.1142],[.2362,.1214],[.2243,.1275],[.2125,.1321],[.2007,.1346],[.1889,.1356],[.177,.1355],[.1652,.1345],[.1534,.1334],[.1416,.1328],[.1297,.1325],[.1179,.1325],[.1061,.1324],[.0943,.1323],[.0824,.1322],[.0706,.1322],[.0588,.1325],[.047,.1333],[.0351,.134],[.0233,.1344],[.0115,.1344],[-3e-4,.1344],[-.0122,.1343],[-.024,.1345],[-.0358,.1352],[-.0476,.136],[-.0595,.1364],[-.0713,.1365],[-.0831,.1366],[-.0949,.1368],[-.1068,.137],[-.1186,.1369],[-.1304,.1369],[-.1422,.1375],[-.1541,.1381],[-.1659,.1384],[-.1777,.1385],[-.1895,.1384],[-.2014,.1383],[-.2132,.1383],[-.225,.1384],[-.2368,.1389],[-.2487,.1397],[-.2605,.1402],[-.2723,.1404],[-.2841,.1403],[-.296,.1403],[-.3078,.1402],[-.3196,.1402],[-.3314,.1405],[-.3433,.1412],[-.3551,.1419],[-.3669,.1423],[-.3787,.1423],[-.3906,.1422],[-.4024,.1422],[-.4142,.1421],[-.426,.1421],[-.4379,.1425],[-.4497,.1432],[-.4615,.1439],[-.4733,.1442],[-.4852,.1442],[-.497,.1441],[-.5088,.144],[-.5206,.144],[-.5325,.144],[-.5443,.1443],[-.5561,.1449],[-.5679,.1457],[-.5798,.146],[-.5916,.146],[-.6034,.146],[-.6152,.1459],[-.6271,.1458],[-.6389,.1458],[-.6507,.1459],[-.6625,.1464],[-.6744,.1471],[-.6862,.1477],[-.698,.1479],[-.7098,.1478],[-.7217,.1478],[-.7335,.148],[-.7453,.1486],[-.7571,.1494],[-.769,.1498],[-.7808,.1499],[-.7926,.1498],[-.8044,.1497],[-.8163,.1496],[-.8281,.1496],[-.8399,.1498],[-.8517,.1504],[-.8636,.1517],[-.8754,.1537],[-.8872,.1562],[-.899,.1592],[-.9109,.1625],[-.9227,.1659],[-.9345,.1692],[-.9463,.1724],[-.9582,.1752],[-.97,.1775],[-.9818,.1791],[-.9936,.1799],[-1.0055,.1798],[-1.0173,.1785],[-1.0291,.176],[-1.0409,.172],[-1.0528,.1664],[-1.0646,.1592],[-1.0764,.1512],[-1.0882,.1438],[-1.0961,.14]],at:[[1.0297,.5171],[2.6005,.5171],[-1.0297,.5171],[-2.6005,.5171]],fins:[{side:-1,uv:[.9179,.8867,.9936,1],x0:-.24,x1:.0013,y0:-.8577,y1:-1.0863,outline:[[-.8577,.1562,.1502],[-.8636,.1587,.1509],[-.8695,.1613,.1519],[-.8754,.1638,.153],[-.8813,.1689,.1542],[-.8872,.1714,.1556],[-.8931,.1739,.1571],[-.899,.179,.1587],[-.905,.1815,.1603],[-.9109,.1841,.162],[-.9168,.1892,.1638],[-.9227,.1917,.1655],[-.9286,.1943,.1672],[-.9345,.1968,.1689],[-.9404,.2019,.1706],[-.9463,.2044,.1722],[-.9523,.2069,.1737],[-.9582,.212,.1751],[-.9641,.2146,.1763],[-.97,.2171,.1775],[-.9759,.2196,.1784],[-.9818,.2247,.1792],[-.9877,.2273,.1798],[-.9936,.2298,.1801],[-.9996,.2349,.1802],[-1.0055,.2374,.1801],[-1.0114,.2374,.1796],[-1.0173,.2374,.1789],[-1.0232,.2374,.1778],[-1.0291,.2374,.1764],[-1.035,.2374,.1747],[-1.0409,.2374,.1725],[-1.0469,.2374,.17],[-1.0528,.2374,.167],[-1.0587,.2374,.1636],[-1.0646,.2374,.1599],[-1.0705,.2374,.1559],[-1.0764,.2044,.1519],[-1.0823,.1511,.148],[-1.0843,.146,.1468]]}],finsAround:2,finsFrom:null,engines:{ring:2,centre:!1,f:.5,colour:[60,59,58],profile:[[-1.0981,.13],[-1.102,.1274],[-1.106,.1299],[-1.1099,.1324],[-1.1139,.1324],[-1.1178,.1248],[-1.1217,.1248],[-1.1257,.1273],[-1.1296,.1298],[-1.1336,.1323],[-1.1375,.1348],[-1.1415,.1373],[-1.1454,.1398],[-1.1493,.1398],[-1.1533,.1422],[-1.1572,.1447],[-1.1612,.1447],[-1.1651,.1472],[-1.169,.1497],[-1.173,.1497],[-1.1769,.1522],[-1.1809,.1521],[-1.1848,.1546],[-1.1888,.1546],[-1.1927,.1571],[-1.1966,.157],[-1.2006,.1595],[-1.2045,.1595],[-1.2085,.1595],[-1.2124,.1619],[-1.2163,.1619],[-1.2203,.1569],[-1.2242,.1343]]}}],badge:{y:.9137,d:.3654,r:.2436},band:[.6978,.7168],head:{top:1.6,cut:1.1295,mean:.7207,r:.2563}},cz3b:{id:"long-march-3b",shape:"cz3b",atlas:{w:1237,h:1024,cap:[.9951,.9941,.9984,.998]},parts:[{name:"core",uv:[0,0,.6209,1],top:1.6,end:-1.2151,profile:[[1.6,.0174],[1.5885,.0445],[1.577,.0633],[1.5656,.0779],[1.5541,.0909],[1.5426,.1025],[1.5311,.1132],[1.5196,.123],[1.5081,.132],[1.4967,.1404],[1.4852,.1483],[1.4737,.1559],[1.4622,.1632],[1.4507,.1703],[1.4392,.1771],[1.4278,.1835],[1.4163,.1897],[1.4048,.1958],[1.3933,.2018],[1.3818,.2076],[1.3704,.2131],[1.3589,.2183],[1.3474,.2234],[1.3359,.2283],[1.3244,.2329],[1.3129,.2372],[1.3015,.241],[1.29,.2443],[1.2785,.2466],[1.267,.2478],[1.2555,.2481],[1.244,.2481],[1.2326,.2481],[1.2211,.248],[1.2096,.2479],[1.1981,.2478],[1.1866,.2477],[1.1751,.2476],[1.1637,.2475],[1.1522,.2474],[1.1407,.2474],[1.1292,.2473],[1.1177,.2472],[1.1063,.2471],[1.0948,.2471],[1.0833,.2473],[1.0718,.2481],[1.0603,.2489],[1.0488,.2493],[1.0374,.2489],[1.0259,.2484],[1.0144,.248],[1.0029,.2477],[.9914,.2466],[.9799,.2438],[.9685,.2389],[.957,.2325],[.9455,.2257],[.934,.2189],[.9225,.2123],[.9111,.2059],[.8996,.1994],[.8881,.1928],[.8766,.1863],[.8651,.1804],[.8536,.1756],[.8422,.1725],[.8307,.1715],[.8192,.1724],[.8077,.1746],[.7962,.1766],[.7847,.1777],[.7733,.1776],[.7618,.1767],[.7503,.1753],[.7388,.174],[.7273,.1734],[.7158,.1731],[.7044,.1731],[.6929,.1731],[.6814,.1734],[.6699,.1738],[.6584,.174],[.647,.1742],[.6355,.1742],[.624,.1742],[.6125,.1741],[.601,.174],[.5895,.174],[.5781,.1739],[.5666,.1738],[.5551,.1738],[.5436,.1737],[.5321,.1737],[.5206,.1736],[.5092,.1735],[.4977,.1735],[.4862,.1734],[.4747,.1734],[.4632,.1733],[.4518,.1733],[.4403,.1733],[.4288,.1737],[.4173,.1746],[.4058,.1757],[.3943,.1764],[.3829,.176],[.3714,.1748],[.3599,.1736],[.3484,.1729],[.3369,.1727],[.3254,.1726],[.314,.1725],[.3025,.1725],[.291,.1724],[.2795,.1723],[.268,.1723],[.2565,.1724],[.2451,.1728],[.2336,.1732],[.2221,.1735],[.2106,.1735],[.1991,.1734],[.1877,.1734],[.1762,.1734],[.1647,.1733],[.1532,.1733],[.1417,.1734],[.1302,.1737],[.1188,.1741],[.1073,.1743],[.0958,.1743],[.0843,.1741],[.0728,.1741],[.0613,.1742],[.0499,.1742],[.0384,.1743],[.0269,.1746],[.0154,.1751],[.0039,.1751],[-.0075,.1745],[-.019,.1735],[-.0305,.1727],[-.042,.1719],[-.0535,.1712],[-.065,.1705],[-.0764,.1699],[-.0879,.1693],[-.0994,.1687],[-.1109,.1682],[-.1224,.1677],[-.1339,.1673],[-.1453,.1669],[-.1568,.1665],[-.1683,.1661],[-.1798,.1658],[-.1913,.1654],[-.2027,.1652],[-.2142,.1649],[-.2257,.1647],[-.2372,.1645],[-.2487,.1643],[-.2602,.1641],[-.2716,.164],[-.2831,.1639],[-.2946,.1638],[-.3061,.1637],[-.3176,.1637],[-.3291,.1637],[-.3405,.1637],[-.352,.1637],[-.3635,.1637],[-.375,.1637],[-.3865,.1638],[-.398,.1639],[-.4094,.164],[-.4209,.1641],[-.4324,.1642],[-.4439,.1643],[-.4554,.1645],[-.4668,.1646],[-.4783,.1648],[-.4898,.165],[-.5013,.1652],[-.5128,.1653],[-.5243,.1656],[-.5357,.1658],[-.5472,.166],[-.5587,.1662],[-.5702,.1664],[-.5817,.1666],[-.5932,.1669],[-.6046,.1671],[-.6161,.1673],[-.6276,.1676],[-.6391,.1678],[-.6506,.1681],[-.662,.1683],[-.6735,.1685],[-.685,.1688],[-.6965,.169],[-.708,.1692],[-.7195,.1694],[-.7309,.1697],[-.7424,.1699],[-.7539,.1701],[-.7654,.1703],[-.7769,.1705],[-.7884,.1707],[-.7998,.1708],[-.8113,.171],[-.8228,.1712],[-.8343,.1713],[-.8458,.1715],[-.8573,.1716],[-.8687,.1717],[-.8802,.1718],[-.8917,.1719],[-.9032,.1719],[-.9147,.172],[-.9261,.172],[-.9376,.172],[-.9491,.172],[-.9606,.172],[-.9721,.172],[-.9836,.1719],[-.995,.1718],[-1.0065,.1715],[-1.018,.171],[-1.0295,.1704],[-1.041,.1701],[-1.0525,.1709],[-1.0639,.1729],[-1.0754,.1758],[-1.0869,.1786],[-1.0984,.1792],[-1.1099,.1746],[-1.1213,.1659],[-1.1328,.1608],[-1.1443,.1637],[-1.1558,.1708],[-1.1673,.1781],[-1.1788,.1843],[-1.1902,.1893],[-1.2017,.1929],[-1.2132,.1951]],at:[[0,0]],fins:[],finsAround:0,finsFrom:null,engines:{ring:4,centre:!1,f:.45,colour:[46,44,42],profile:[[-1.2151,.1986],[-1.2189,.2],[-1.2228,.2],[-1.2266,.2014],[-1.2304,.197],[-1.2343,.1868],[-1.2381,.1649]]}},{name:"booster",uv:[.6209,.4502,.9313,1],top:-.0363,end:-1.1118,profile:[[-.0363,.0057],[-.0477,.0241],[-.0592,.0337],[-.0707,.0416],[-.0822,.0486],[-.0937,.0552],[-.1051,.0617],[-.1166,.0681],[-.1281,.0747],[-.1396,.0814],[-.1511,.0881],[-.1626,.0944],[-.174,.0998],[-.1855,.1037],[-.197,.1058],[-.2085,.1066],[-.22,.1067],[-.2315,.1067],[-.2429,.1066],[-.2544,.1068],[-.2659,.1073],[-.2774,.1083],[-.2889,.1091],[-.3004,.1094],[-.3118,.1094],[-.3233,.1094],[-.3348,.1093],[-.3463,.1093],[-.3578,.1092],[-.3692,.1092],[-.3807,.1092],[-.3922,.1092],[-.4037,.1091],[-.4152,.1091],[-.4267,.109],[-.4381,.109],[-.4496,.109],[-.4611,.1089],[-.4726,.1089],[-.4841,.1088],[-.4956,.1088],[-.507,.1088],[-.5185,.1088],[-.53,.1087],[-.5415,.1087],[-.553,.1086],[-.5644,.1086],[-.5759,.1086],[-.5874,.1085],[-.5989,.1085],[-.6104,.1086],[-.6219,.1088],[-.6333,.1093],[-.6448,.1101],[-.6563,.1108],[-.6678,.1111],[-.6793,.1109],[-.6908,.1103],[-.7022,.11],[-.7137,.1103],[-.7252,.1107],[-.7367,.111],[-.7482,.111],[-.7596,.1109],[-.7711,.1109],[-.7826,.1109],[-.7941,.1108],[-.8056,.1108],[-.8171,.1107],[-.8285,.1107],[-.84,.1108],[-.8515,.1112],[-.863,.1122],[-.8745,.1136],[-.886,.1148],[-.8974,.1156],[-.9089,.1162],[-.9204,.1166],[-.9319,.1167],[-.9434,.1166],[-.9549,.1164],[-.9663,.116],[-.9778,.1156],[-.9893,.1151],[-1.0008,.1146],[-1.0123,.1141],[-1.0237,.1137],[-1.0352,.1133],[-1.0467,.1131],[-1.0582,.1128],[-1.0697,.1114],[-1.0812,.1064],[-1.0926,.0968],[-1.1041,.0871],[-1.1118,.0826]],at:[[.9146,.4364],[2.4853,.4364],[-.9146,.4364],[-2.4853,.4364]],fins:[{side:-1,uv:[.9313,.9131,.9935,1],x0:-.225,x1:.0015,y0:-.8802,y1:-1.0505,outline:[[-.8802,.1162,.1139],[-.886,.122,.1145],[-.8917,.1279,.115],[-.8974,.1338,.1154],[-.9032,.1397,.1158],[-.9089,.1456,.116],[-.9147,.1514,.1163],[-.9204,.1544,.1164],[-.9261,.1632,.1165],[-.9319,.1691,.1166],[-.9376,.175,.1166],[-.9434,.1809,.1166],[-.9491,.1868,.1165],[-.9549,.1926,.1163],[-.9606,.1985,.1162],[-.9663,.2044,.116],[-.9721,.2132,.1159],[-.9778,.2191,.1156],[-.9836,.222,.1154],[-.9893,.222,.1152],[-.995,.222,.115],[-1.0008,.222,.1147],[-1.0065,.222,.1145],[-1.0123,.222,.1143],[-1.018,.222,.1141],[-1.0237,.222,.1139],[-1.0295,.222,.1137],[-1.0352,.222,.1136],[-1.041,.222,.1135],[-1.0467,.1132,.1134],[-1.0486,.1132,.1133]]}],finsAround:2,finsFrom:null,engines:{ring:0,centre:!0,f:1,colour:[46,44,42],profile:[[-1.1118,.0747],[-1.1156,.0835],[-1.1194,.0893],[-1.1233,.0805],[-1.1271,.0688],[-1.1309,.0688],[-1.1347,.0717],[-1.1386,.0717],[-1.1424,.0746],[-1.1462,.0775],[-1.1501,.0775],[-1.1539,.0804],[-1.1577,.0834],[-1.1615,.0833],[-1.1654,.0863],[-1.1692,.0892],[-1.173,.0892],[-1.1768,.0921],[-1.1807,.0921],[-1.1845,.095],[-1.1883,.095],[-1.1922,.092],[-1.196,.0833],[-1.1998,.057]]}}],badge:{y:.9137,d:.312,r:.208},band:[.7245,.7435],head:{top:1.6,cut:1.1028,mean:.7484,r:.2618}},heavy:{id:"starship",shape:"heavy",atlas:{w:1029,h:1136,cap:[.9942,.9947,.9981,.9982]},parts:[{name:"core",uv:[0,.0986,.7464,1],top:1.6,end:-1.1224,profile:[[1.6,.0103],[1.5884,.0383],[1.5769,.0539],[1.5653,.0677],[1.5537,.0807],[1.5422,.0926],[1.5306,.1039],[1.519,.1146],[1.5075,.1248],[1.4959,.1347],[1.4843,.1444],[1.4727,.1536],[1.4612,.1626],[1.4496,.1712],[1.438,.1796],[1.4265,.1874],[1.4149,.1949],[1.4033,.2021],[1.3918,.2091],[1.3802,.216],[1.3686,.223],[1.3571,.2298],[1.3455,.2364],[1.3339,.2426],[1.3224,.2485],[1.3108,.254],[1.2992,.2593],[1.2877,.2642],[1.2761,.2688],[1.2645,.2731],[1.253,.2771],[1.2414,.2808],[1.2298,.2843],[1.2182,.2875],[1.2067,.2904],[1.1951,.2931],[1.1835,.2955],[1.172,.2978],[1.1604,.2998],[1.1488,.3015],[1.1373,.3031],[1.1257,.3045],[1.1141,.3057],[1.1026,.3067],[1.091,.3075],[1.0794,.3082],[1.0679,.3087],[1.0563,.3091],[1.0447,.3093],[1.0332,.3094],[1.0216,.3094],[1.01,.3092],[.9985,.309],[.9869,.3088],[.9753,.3085],[.9637,.3083],[.9522,.3081],[.9406,.308],[.929,.3082],[.9175,.3086],[.9059,.309],[.8943,.309],[.8828,.3089],[.8712,.3087],[.8596,.3085],[.8481,.3084],[.8365,.3085],[.8249,.3087],[.8134,.3088],[.8018,.309],[.7902,.3091],[.7787,.309],[.7671,.3087],[.7555,.3085],[.744,.3083],[.7324,.3081],[.7208,.308],[.7092,.3081],[.6977,.3082],[.6861,.3082],[.6745,.3082],[.663,.3083],[.6514,.3084],[.6398,.3083],[.6283,.3081],[.6167,.308],[.6051,.308],[.5936,.3081],[.582,.3082],[.5704,.308],[.5589,.3078],[.5473,.3077],[.5357,.3078],[.5242,.3079],[.5126,.308],[.501,.308],[.4895,.3081],[.4779,.3082],[.4663,.3082],[.4547,.3083],[.4432,.3084],[.4316,.3085],[.42,.3084],[.4085,.3084],[.3969,.3085],[.3853,.3086],[.3738,.3085],[.3622,.3083],[.3506,.3081],[.3391,.3078],[.3275,.3076],[.3159,.3076],[.3044,.3078],[.2928,.3083],[.2812,.3086],[.2697,.3086],[.2581,.3084],[.2465,.3082],[.2349,.3079],[.2234,.3077],[.2118,.3077],[.2002,.3079],[.1887,.3084],[.1771,.3087],[.1655,.3087],[.154,.3085],[.1424,.3083],[.1308,.308],[.1193,.3078],[.1077,.3076],[.0961,.3075],[.0846,.3075],[.073,.3077],[.0614,.3077],[.0499,.3078],[.0383,.3079],[.0267,.308],[.0152,.308],[.0036,.308],[-.008,.3082],[-.0196,.3083],[-.0311,.3083],[-.0427,.3084],[-.0543,.3084],[-.0658,.3082],[-.0774,.3081],[-.089,.308],[-.1005,.308],[-.1121,.3081],[-.1237,.3082],[-.1352,.3082],[-.1468,.3081],[-.1584,.3082],[-.1699,.3083],[-.1815,.3083],[-.1931,.3084],[-.2046,.3085],[-.2162,.3086],[-.2278,.3087],[-.2393,.3088],[-.2509,.3089],[-.2625,.3089],[-.2741,.3089],[-.2856,.3089],[-.2972,.3091],[-.3088,.3092],[-.3203,.3093],[-.3319,.3096],[-.3435,.31],[-.355,.3105],[-.3666,.3108],[-.3782,.3109],[-.3897,.3107],[-.4013,.3105],[-.4129,.3103],[-.4244,.3101],[-.436,.3098],[-.4476,.3096],[-.4591,.3094],[-.4707,.3091],[-.4823,.3089],[-.4938,.3087],[-.5054,.3085],[-.517,.3083],[-.5286,.308],[-.5401,.3078],[-.5517,.3076],[-.5633,.3074],[-.5748,.3071],[-.5864,.3069],[-.598,.3067],[-.6095,.3065],[-.6211,.3063],[-.6327,.306],[-.6442,.3058],[-.6558,.3056],[-.6674,.3054],[-.6789,.3052],[-.6905,.3049],[-.7021,.3047],[-.7136,.3045],[-.7252,.3043],[-.7368,.3041],[-.7484,.3038],[-.7599,.3036],[-.7715,.3034],[-.7831,.3032],[-.7946,.303],[-.8062,.3027],[-.8178,.3025],[-.8293,.3023],[-.8409,.3021],[-.8525,.3019],[-.864,.3017],[-.8756,.3014],[-.8872,.3012],[-.8987,.301],[-.9103,.3008],[-.9219,.3006],[-.9334,.3004],[-.945,.3002],[-.9566,.3],[-.9681,.2997],[-.9797,.2995],[-.9913,.2993],[-1.0029,.2991],[-1.0144,.2989],[-1.026,.2987],[-1.0376,.2985],[-1.0491,.2983],[-1.0607,.2981],[-1.0723,.2979],[-1.0838,.2976],[-1.0954,.2974],[-1.107,.2972],[-1.1185,.297],[-1.1224,.297]],at:[[0,0]],fins:[{side:-1,uv:[.7464,.8477,.9252,1],x0:-.4382,x1:0,y0:1.3532,y1:1.0197,outline:[[1.3532,.2286,.2293],[1.3474,.2334,.2327],[1.3416,.2405,.2359],[1.3359,.2477,.2391],[1.3301,.2548,.2421],[1.3243,.2619,.2451],[1.3185,.2691,.2481],[1.3127,.2762,.2509],[1.3069,.2834,.2537],[1.3012,.2905,.2563],[1.2954,.2976,.2589],[1.2896,.3048,.2615],[1.2838,.312,.2639],[1.278,.3191,.2663],[1.2722,.3262,.2686],[1.2664,.3334,.2709],[1.2607,.3405,.273],[1.2549,.3477,.2751],[1.2491,.3548,.2772],[1.2433,.362,.2791],[1.2375,.3691,.281],[1.2317,.3762,.2828],[1.226,.3834,.2846],[1.2202,.3905,.2863],[1.2144,.3977,.2879],[1.2086,.4024,.2895],[1.2028,.4096,.291],[1.197,.4143,.2925],[1.1913,.4191,.2939],[1.1855,.4191,.2952],[1.1797,.4191,.2965],[1.1739,.4215,.2977],[1.1681,.4215,.2989],[1.1623,.4215,.3],[1.1566,.4239,.301],[1.1508,.4239,.302],[1.145,.4239,.303],[1.1392,.4263,.3039],[1.1334,.4263,.3047],[1.1276,.4286,.3056],[1.1218,.4286,.3063],[1.1161,.431,.307],[1.1103,.431,.3077],[1.1045,.431,.3083],[1.0987,.4334,.3089],[1.0929,.4334,.3094],[1.0871,.4334,.3099],[1.0814,.4358,.3104],[1.0756,.4358,.3108],[1.0698,.4334,.3112],[1.064,.431,.3115],[1.0582,.4191,.3118],[1.0524,.4096,.3121],[1.0467,.3953,.3123],[1.0409,.3834,.3125],[1.0351,.3715,.3127],[1.0293,.3596,.3128],[1.0235,.312,.3129],[1.0216,.312,.313]]},{side:1,uv:[.7464,.6937,.9252,.846],x0:0,x1:.4382,y0:1.3532,y1:1.0197,outline:[[1.3532,.2334,.2293],[1.3474,.2405,.2327],[1.3416,.25,.2359],[1.3359,.2572,.2391],[1.3301,.2619,.2421],[1.3243,.2691,.2451],[1.3185,.2762,.2481],[1.3127,.2834,.2509],[1.3069,.2905,.2537],[1.3012,.2976,.2563],[1.2954,.3048,.2589],[1.2896,.312,.2615],[1.2838,.3191,.2639],[1.278,.3262,.2663],[1.2722,.3334,.2686],[1.2664,.3405,.2709],[1.2607,.3453,.273],[1.2549,.3524,.2751],[1.2491,.3596,.2772],[1.2433,.3691,.2791],[1.2375,.3739,.281],[1.2317,.381,.2828],[1.226,.3881,.2846],[1.2202,.3953,.2863],[1.2144,.4024,.2879],[1.2086,.4096,.2895],[1.2028,.4143,.291],[1.197,.4167,.2925],[1.1913,.4191,.2939],[1.1855,.4191,.2952],[1.1797,.4191,.2965],[1.1739,.4215,.2977],[1.1681,.4215,.2989],[1.1623,.4239,.3],[1.1566,.4239,.301],[1.1508,.4239,.302],[1.145,.4263,.303],[1.1392,.4263,.3039],[1.1334,.4263,.3047],[1.1276,.4286,.3056],[1.1218,.4286,.3063],[1.1161,.431,.307],[1.1103,.431,.3077],[1.1045,.431,.3083],[1.0987,.4334,.3089],[1.0929,.4334,.3094],[1.0871,.4334,.3099],[1.0814,.4358,.3104],[1.0756,.4358,.3108],[1.0698,.431,.3112],[1.064,.4239,.3115],[1.0582,.4143,.3118],[1.0524,.4024,.3121],[1.0467,.3905,.3123],[1.0409,.3786,.3125],[1.0351,.3667,.3127],[1.0293,.3548,.3128],[1.0235,.3143,.3129],[1.0216,.3143,.313]]},{side:-1,uv:[.7464,.3477,.9922,.6919],x0:-.5301,x1:0,y0:-.3743,y1:-1.1282,outline:[[-.3743,.3059,.3036],[-.3801,.308,.3037],[-.3859,.3101,.3038],[-.3917,.3101,.3038],[-.3974,.3122,.3038],[-.4032,.3143,.3038],[-.409,.3164,.3038],[-.4148,.3206,.3038],[-.4206,.3226,.3038],[-.4264,.3248,.3038],[-.4322,.3268,.3038],[-.4379,.3289,.3038],[-.4437,.3331,.3038],[-.4495,.3373,.3038],[-.4553,.3415,.3038],[-.4611,.3457,.3038],[-.4669,.3499,.3038],[-.4726,.3541,.3038],[-.4784,.3583,.3038],[-.4842,.3625,.3038],[-.49,.3666,.3038],[-.4958,.3708,.3038],[-.5016,.3729,.3038],[-.5073,.3771,.3038],[-.5131,.3813,.3038],[-.5189,.3855,.3038],[-.5247,.3897,.3038],[-.5305,.3939,.3038],[-.5363,.3981,.3038],[-.5421,.4023,.3038],[-.5478,.4064,.3038],[-.5536,.4106,.3038],[-.5594,.4148,.3038],[-.5652,.419,.3038],[-.571,.4232,.3038],[-.5768,.4274,.3038],[-.5825,.4316,.3038],[-.5883,.4358,.3038],[-.5941,.4379,.3038],[-.5999,.4421,.3038],[-.6057,.4463,.3038],[-.6115,.4504,.3038],[-.6172,.4546,.3038],[-.623,.4588,.3038],[-.6288,.463,.3038],[-.6346,.4672,.3038],[-.6404,.4714,.3038],[-.6462,.4756,.3038],[-.6519,.4777,.3038],[-.6577,.4819,.3038],[-.6635,.4861,.3038],[-.6693,.4903,.3038],[-.6751,.4944,.3038],[-.6809,.4986,.3038],[-.6867,.5028,.3038],[-.6924,.5049,.3038],[-.6982,.507,.3038],[-.704,.5091,.3038],[-.7098,.5091,.3038],[-.7156,.5091,.3038],[-.7214,.5091,.3038],[-.7271,.5091,.3038],[-.7329,.5091,.3038],[-.7387,.5091,.3038],[-.7445,.5112,.3038],[-.7503,.5112,.3038],[-.7561,.5112,.3038],[-.7618,.5112,.3038],[-.7676,.5112,.3038],[-.7734,.5133,.3038],[-.7792,.5133,.3038],[-.785,.5133,.3038],[-.7908,.5133,.3038],[-.7966,.5133,.3038],[-.8023,.5154,.3038],[-.8081,.5154,.3038],[-.8139,.5154,.3038],[-.8197,.5154,.3038],[-.8255,.5154,.3038],[-.8313,.5154,.3038],[-.837,.5175,.3038],[-.8428,.5175,.3038],[-.8486,.5175,.3038],[-.8544,.5175,.3038],[-.8602,.5175,.3038],[-.866,.5196,.3038],[-.8717,.5196,.3038],[-.8775,.5196,.3038],[-.8833,.5196,.3038],[-.8891,.5196,.3038],[-.8949,.5217,.3038],[-.9007,.5217,.3038],[-.9064,.5217,.3038],[-.9122,.5217,.3038],[-.918,.5217,.3038],[-.9238,.5238,.3038],[-.9296,.5238,.3038],[-.9354,.5238,.3038],[-.9412,.5238,.3038],[-.9469,.5259,.3038],[-.9527,.5259,.3038],[-.9585,.5259,.3038],[-.9643,.5259,.3038],[-.9701,.5259,.3038],[-.9759,.528,.3038],[-.9816,.528,.3038],[-.9874,.528,.3038],[-.9932,.5259,.3038],[-.999,.5217,.3038],[-1.0048,.5112,.3038],[-1.0106,.4986,.3038],[-1.0163,.484,.3038],[-1.0221,.4693,.3038],[-1.0279,.4546,.3038],[-1.0337,.4379,.3038],[-1.0395,.4253,.3038],[-1.0453,.4086,.3038],[-1.0511,.396,.3038],[-1.0568,.3813,.3038],[-1.0626,.3666,.3038],[-1.0684,.3541,.3038],[-1.0742,.3541,.3038],[-1.08,.3541,.3038],[-1.0858,.3541,.3038],[-1.0915,.3541,.3038],[-1.0973,.3541,.3038],[-1.1031,.3541,.3038],[-1.1089,.352,.3038],[-1.1147,.3436,.3038],[-1.1205,.3352,.3038],[-1.1262,.3268,.3038]]},{side:1,uv:[.7464,.0018,.9922,.346],x0:0,x1:.5301,y0:-.3743,y1:-1.1282,outline:[[-.3743,.308,.3036],[-.3801,.3101,.3037],[-.3859,.3122,.3038],[-.3917,.3143,.3038],[-.3974,.3164,.3038],[-.4032,.3185,.3038],[-.409,.3206,.3038],[-.4148,.3226,.3038],[-.4206,.3268,.3038],[-.4264,.3289,.3038],[-.4322,.331,.3038],[-.4379,.3331,.3038],[-.4437,.3373,.3038],[-.4495,.3394,.3038],[-.4553,.3436,.3038],[-.4611,.3478,.3038],[-.4669,.3499,.3038],[-.4726,.3541,.3038],[-.4784,.3583,.3038],[-.4842,.3625,.3038],[-.49,.3666,.3038],[-.4958,.3708,.3038],[-.5016,.375,.3038],[-.5073,.3792,.3038],[-.5131,.3834,.3038],[-.5189,.3876,.3038],[-.5247,.3918,.3038],[-.5305,.396,.3038],[-.5363,.4002,.3038],[-.5421,.4044,.3038],[-.5478,.4086,.3038],[-.5536,.4127,.3038],[-.5594,.4148,.3038],[-.5652,.4211,.3038],[-.571,.4253,.3038],[-.5768,.4295,.3038],[-.5825,.4316,.3038],[-.5883,.4358,.3038],[-.5941,.44,.3038],[-.5999,.4442,.3038],[-.6057,.4484,.3038],[-.6115,.4526,.3038],[-.6172,.4567,.3038],[-.623,.4609,.3038],[-.6288,.4651,.3038],[-.6346,.4693,.3038],[-.6404,.4735,.3038],[-.6462,.4756,.3038],[-.6519,.4798,.3038],[-.6577,.484,.3038],[-.6635,.4882,.3038],[-.6693,.4924,.3038],[-.6751,.4966,.3038],[-.6809,.5007,.3038],[-.6867,.5049,.3038],[-.6924,.507,.3038],[-.6982,.5091,.3038],[-.704,.5091,.3038],[-.7098,.5112,.3038],[-.7156,.5112,.3038],[-.7214,.5112,.3038],[-.7271,.5112,.3038],[-.7329,.5133,.3038],[-.7387,.5133,.3038],[-.7445,.5133,.3038],[-.7503,.5133,.3038],[-.7561,.5133,.3038],[-.7618,.5154,.3038],[-.7676,.5154,.3038],[-.7734,.5154,.3038],[-.7792,.5154,.3038],[-.785,.5154,.3038],[-.7908,.5154,.3038],[-.7966,.5175,.3038],[-.8023,.5175,.3038],[-.8081,.5175,.3038],[-.8139,.5175,.3038],[-.8197,.5175,.3038],[-.8255,.5175,.3038],[-.8313,.5175,.3038],[-.837,.5196,.3038],[-.8428,.5196,.3038],[-.8486,.5196,.3038],[-.8544,.5196,.3038],[-.8602,.5196,.3038],[-.866,.5196,.3038],[-.8717,.5217,.3038],[-.8775,.5217,.3038],[-.8833,.5217,.3038],[-.8891,.5217,.3038],[-.8949,.5217,.3038],[-.9007,.5217,.3038],[-.9064,.5238,.3038],[-.9122,.5238,.3038],[-.918,.5238,.3038],[-.9238,.5238,.3038],[-.9296,.5238,.3038],[-.9354,.5238,.3038],[-.9412,.5259,.3038],[-.9469,.5259,.3038],[-.9527,.5259,.3038],[-.9585,.5259,.3038],[-.9643,.5259,.3038],[-.9701,.528,.3038],[-.9759,.528,.3038],[-.9816,.528,.3038],[-.9874,.5259,.3038],[-.9932,.5238,.3038],[-.999,.5196,.3038],[-1.0048,.507,.3038],[-1.0106,.4924,.3038],[-1.0163,.4777,.3038],[-1.0221,.463,.3038],[-1.0279,.4484,.3038],[-1.0337,.4337,.3038],[-1.0395,.4211,.3038],[-1.0453,.4044,.3038],[-1.0511,.3897,.3038],[-1.0568,.375,.3038],[-1.0626,.3625,.3038],[-1.0684,.3562,.3038],[-1.0742,.3562,.3038],[-1.08,.3562,.3038],[-1.0858,.3562,.3038],[-1.0915,.3541,.3038],[-1.0973,.3541,.3038],[-1.1031,.3541,.3038],[-1.1089,.3499,.3038],[-1.1147,.3436,.3038],[-1.1205,.3352,.3038],[-1.1262,.3289,.3038]]}],finsAround:2,finsFrom:null,engines:{ring:3,centre:3,f:.3,colour:[75,68,59],profile:[[-1.1224,.3256],[-1.1262,.3204],[-1.1301,.3142],[-1.134,.31],[-1.1378,.3059],[-1.1417,.3017],[-1.1455,.2965],[-1.1494,.2883],[-1.1532,.2759],[-1.1571,.2636],[-1.161,.2533],[-1.1648,.2431],[-1.1687,.243],[-1.1725,.243],[-1.1764,.2439],[-1.1802,.2439],[-1.1841,.2438],[-1.1879,.2417],[-1.1918,.2396],[-1.1957,.2355],[-1.1995,.2293],[-1.2034,.2201],[-1.2072,.2058],[-1.2111,.1864],[-1.2149,.0845],[-1.2188,.0814],[-1.2226,.0784],[-1.2265,.0722],[-1.2304,.0651],[-1.2342,.0529],[-1.2381,.0325]]}}],badge:{y:.9137,d:.4632,r:.3088},band:[.6489,.6679],head:null}};var Ih={falcon9:"falcon9",falconHeavy:"falcon-heavy",newGlenn:"new-glenn",vulcan:"vulcan",cz2f:"long-march-2f",cz5:"long-march-5",cz3b:"long-march-3b",heavy:"starship"},vf=Object.keys(Ih);var f3=[64,18],Oc=(i,t,e)=>i+(t-i)*e;function yf(i,t){if(i.length<3)return i;let e=new Uint8Array(i.length);e[0]=e[i.length-1]=1;let n=[[0,i.length-1]];for(;n.length;){let[s,r]=n.pop(),[a,o]=i[s],[c,l]=i[r],h=c-a,f=l-o,u=Math.hypot(h,f)||1,d=-1,g=-1;for(let _=s+1;_<r;_++){let m=Math.abs(f*(i[_][0]-a)-h*(i[_][1]-o))/u;m>d&&(d=m,g=_)}d>t&&(e[g]=1,n.push([s,g],[g,r]))}return i.filter((s,r)=>e[r])}var p3=[.0015,.005];function m3(i,t,e){let[n,s,r,a]=i.uv,o=yf(i.profile,e).map(([f,u])=>new vt(Math.max(4e-4,u),f)).reverse();o.push(new vt(1e-4,i.profile[0][0]+4e-4));let c=new vr(o,t),l=c.attributes.uv,h=c.attributes.position;for(let f=0;f<l.count;f++){let u=Math.min(1,Math.max(0,(h.getY(f)-i.end)/(i.top-i.end)));l.setXY(f,Oc(n,r,l.getX(f)),Oc(s,a,u))}return c}function g3(i,t,e){let n=i.profile[i.profile.length-1][1],s=new va(n,e);s.rotateX(Math.PI/2),s.translate(0,i.end,0);let[r,a,o,c]=t.cap,l=s.attributes.uv;for(let h=0;h<l.count;h++)l.setXY(h,(r+o)/2,(a+c)/2);return s}function x3(i,t){let e=new Gi,n=i.outline.map(([f,u,d])=>{let g=t?t(f,d):0;return[f,Math.max(d,u)+g,d+g]});n.forEach(([f,u],d)=>d?e.lineTo(u,f):e.moveTo(u,f));for(let f=n.length-1;f>=0;f--)e.lineTo(n[f][2]-.004,n[f][0]);let s=new Pa(e),[r,a,o,c]=i.uv,l=s.attributes.position,h=s.attributes.uv;for(let f=0;f<l.count;f++){let u=l.getY(f),d=l.getX(f);if(t){let _=i.outline[0];for(let m of i.outline)Math.abs(m[0]-u)<Math.abs(_[0]-u)&&(_=m);d-=t(u,_[2])}let g=i.side*d;h.setXY(f,Oc(r,o,(g-i.x0)/(i.x1-i.x0)),Oc(a,c,(u-i.y1)/(i.y0-i.y1)))}return s}function _3(i,t){return t===4?i.side<0?[Math.PI,Math.PI/2,-Math.PI/2]:[0]:[i.side<0?Math.PI:0]}function v3(i,t,e){if(!i||i.profile.length<3)return[];let n=Math.max(...i.profile.map(([,h])=>h)),s=i.ring?n*(1-i.f):0,r=n-s,a=i.profile.filter(([,h])=>h-s>r*.25);if(a.length<3)return[];let o=yf(a,e).map(([h,f])=>new vt(Math.max(4e-4,f-s),h)).reverse(),c=new vr(o,Math.max(10,t>>1)),l=[];if(i.ring)for(let h=0;h<i.ring;h++)l.push([s,h/i.ring*Math.PI*2+Math.PI/i.ring,1]);if(i.centre===!0)l.push([0,0,1]);else if(typeof i.centre=="number")for(let h=0;h<i.centre;h++)l.push([s*.38,h/i.centre*Math.PI*2,.62]);return l.map(([h,f,u])=>{let d=c.clone();return d.scale(u,1,u),d.translate(Math.sin(f)*h,(1-u)*.05,Math.cos(f)*h),d})}var y3=([i,t])=>new Ce().makeTranslation(Math.sin(i)*t,0,Math.cos(i)*t).multiply(new Ce().makeRotationY(i+Math.PI/2)),Rh=new Map;function Mf(i,t){let e=`${i}|${t?1:0}`;if(Rh.has(e))return Rh.get(e);let n=ho[i],s=f3.map(l=>t?Math.max(12,l>>1):l).map((l,h)=>{let f=p3[h]*(t?1.6:1),u=[],d=[],g=n.parts.find(_=>_.name==="booster");for(let _ of n.parts){let m=[m3(_,l,f),g3(_,n.atlas,l)],p=_.fins.length?_:_.finsFrom==="booster"&&g?g:null;if(p)for(let y of p.fins){let E=p!==_?(M,I)=>{let v=_.profile[0];for(let C of _.profile)Math.abs(C[0]-M)<Math.abs(v[0]-M)&&(v=C);return v[1]-I}:null;for(let M of _3(y,p===_?_.finsAround:4)){let I=x3(y,E);I.rotateY(M),m.push(I)}}let S=v3(_.engines,l,f),w=_.name==="core"?[null]:_.at;for(let y of w){let E=y?y3(y):null;for(let M of m)u.push(E?M.clone().applyMatrix4(E):M);for(let M of S)d.push(E?M.clone().applyMatrix4(E):M)}}return{hull:Fc(u),bells:d.length?Fc(d):null}}),r=0,a=s[0].hull.attributes.position;for(let l=0;l<a.count;l++)r=Math.max(r,Math.hypot(a.getX(l),a.getZ(l)));let o=[];for(let l of n.parts)if(l.name!=="core"&&l.engines)for(let[h,f]of l.at){let u=Math.max(...l.engines.profile.map(([,d])=>d));o.push({x:Math.sin(h)*f,z:Math.cos(h)*f,r:u})}let c={levels:s,span:r,nozzles:o};return Rh.set(e,c),c}var Ch=new Map;function bf(i){if(Ch.has(i))return Ch.get(i);let t=ho[i],e=t.parts.find(o=>o.name==="core"),n=o=>{let c=e.profile[0];for(let l of e.profile)Math.abs(l[0]-o)<Math.abs(c[0]-o)&&(c=l);return c[1]},s=i==="heavy"?-.25:0,r=[];for(let o of[0,Math.PI]){let l=[],h=[],f=[],u=t.badge.d;for(let g=0;g<=10;g++)for(let _=0;_<=10;_++){let m=(_/10-.5)*u,p=(g/10-.5)*u,S=t.badge.y+p,w=n(S)+.004,y=o+s+m/w;l.push(Math.sin(y)*w,S,Math.cos(y)*w),h.push(_/10,g/10)}for(let g=0;g<10;g++)for(let _=0;_<10;_++){let m=g*11+_,p=m+1,S=m+10+1,w=S+1;f.push(m,p,w,m,w,S)}let d=new Ae;d.setAttribute("position",new fe(l,3)),d.setAttribute("uv",new fe(h,2)),d.setIndex(f),d.computeVertexNormals(),r.push(d)}let a=Fc(r);return Ch.set(i,a),a}function Sf(i){let t=ho[i];if(!t?.head)return null;let e=t.parts.find(s=>s.name==="core").profile,n=s=>{for(let r=1;r<e.length;r++)if(e[r][0]<=s){let[a,o]=e[r-1],[c,l]=e[r];return a===c?l:l+(o-l)*(s-c)/(a-c)}return e[e.length-1][1]};return{cut:t.head.cut,top:t.head.top,r:n}}var M3=`
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
#endif`;function Ef(i,{near:t,envMap:e,head:n,band:s,pattern:r}){let a=ho[i],o=i==="heavy",c=a.parts.find(g=>g.name==="core"),l=Math.max(...c.profile.map(([,g])=>g))*1.06,h=t?Na:zn,f=new h({metalness:1,roughness:1,side:Sn,alphaTest:.5,envMap:e,envMapIntensity:o?2.6:.95,...t?{clearcoat:o?0:.3,clearcoatRoughness:.35,bumpScale:o?0:1.1}:{}}),u=2.84/120,d={uHeadOn:{value:n&&a.head?1:0},uHead:{value:new se(n??"#ffffff")},uMean:{value:a.head?.mean??.7},uCut:{value:a.head?.cut??99},uTop:{value:a.head&&a.head.top<1.59?a.head.top:99},uFeather:{value:.4*u},uCoreR:{value:l},uBand:{value:new vt(a.band[0],a.band[1])},uBandC:{value:new se(s??"#888888")},uPat:{value:r?.texture??null},uPatOn:{value:r?.texture?1:0},uSpan:{value:new vt(a.head?.cut??0,a.head?.top??1)}};return o&&f.color.setScalar(1.35),f.userData.livery=d,f.defines={MP_LIVERY:""},f.onBeforeCompile=g=>{Object.assign(g.uniforms,d),g.vertexShader=g.vertexShader.replace("#include <common>",`#include <common>
varying vec3 vObj;`).replace("#include <begin_vertex>",`#include <begin_vertex>
vObj = position;`),g.fragmentShader=g.fragmentShader.replace("#include <common>",`#include <common>
varying vec3 vObj;
uniform float uHeadOn, uMean, uCut, uTop, uFeather, uCoreR, uPatOn;
uniform vec3 uHead, uBandC;
uniform vec2 uBand, uSpan;
uniform sampler2D uPat;`).replace("#include <map_fragment>","#include <map_fragment>"+M3)},f.customProgramCacheKey=()=>`mp-hull-${t?1:0}`,f}var wf=(i,t,e)=>`${i}art/rockets/${Ih[t]}-${e}.webp`,Tf=(i,t)=>`${i}art/rockets/${Ih[t]}-mat.webp`;var b3={openai:"us",anthropic:"us",xai:"us",google:"us",meta:"us",zhipuai:"cn",kimi:"cn",minimax:"cn",alibaba:"cn",deepseek:"cn",xiaomi:"cn",tencent:"cn",volcengine:"cn"},S3={us:["falcon9","newGlenn","falconHeavy","vulcan"],cn:["cz2f","cz5","cz3b"]},Af=new Set(["xai"]);function Bc(i,t,e){let n=[...i].sort((s,r)=>t(r)-t(s));return n.slice(0,3).find(s=>Af.has(e(s)))??n[0]}var zc=i=>{let t=2166136261;for(let e=0;e<i.length;e++)t=Math.imul(t^i.charCodeAt(e),16777619);return t>>>0},kc=(i,t)=>{if(Af.has(i))return"falcon9";let e=S3[b3[i]==="cn"?"cn":"us"];return e[(zc(i)+t)%e.length]},Rf=(i,t)=>kc(i,zc(t));function Cf(i,t={}){let e=t.studio??null,n={},s=O=>n[O]||"#b8b0a8",r={openai:"OpenAI",anthropic:"Anthropic",zhipuai:"ZHIPU",xai:"xAI",alibaba:"Qwen",deepseek:"DeepSeek",kimi:"Kimi",minimax:"MiniMax",xiaomi:"Xiaomi",tencent:"Tencent",google:"Google",meta:"Meta"},a=t.assetBase??__LF_ENV__.BASE_URL,o={logos:Object.fromEntries(Object.entries({openai:"openai-white.svg",anthropic:"claude-rounded.svg",zhipuai:"zhipu.svg",xai:"x-white.svg",alibaba:"qwen.svg",deepseek:"deepseek.svg",kimi:"kimi-white.svg",minimax:"minimax.svg",google:"gemini.svg",xiaomi:"xiaomi.svg",meta:null}).filter(([,O])=>O).map(([O,St])=>[O,`${a}brands/${St}`]))},c="varying vec2 vUv; varying float vR; void main(){ vUv=uv; vR=abs(dot(normalize(normalMatrix*normal),vec3(0.,0.,1.))); gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",l="uniform float t; uniform float k; uniform vec3 c0; uniform vec3 c1; varying vec2 vUv; varying float vR; void main(){ float a=vUv.y; float fl=.82+.18*sin(t*38.+a*22.)+.08*sin(t*61.+vUv.x*40.); float dia=.85+.15*sin(a*26.-t*20.); float alpha=pow(1.-a,1.5)*fl*dia*k*(.35+.65*pow(vR,1.2)); vec3 col=mix(c0,c1,smoothstep(0.,.55,a)); gl_FragColor=vec4(col*alpha*1.7,alpha); }",h="uniform float t; uniform float k; uniform vec3 gc; uniform vec3 sc; uniform float sm; varying vec2 vUv; varying float vR; void main(){ float y=vUv.y; float n=.75+.25*sin(t*3.+y*30.+vUv.x*20.); float glow=pow(y,3.)*.7; float smoke=pow(y,1.2)*(1.-y)*sm*n; vec3 col=gc*glow+sc*smoke; float a=(glow+smoke)*k*pow(vR,1.4); gl_FragColor=vec4(col*a,a); }",f="uniform float t; uniform float k; varying vec2 vUv; varying float vR; float h(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); } float nz(vec2 p){ vec2 i=floor(p),f=fract(p); f=f*f*(3.-2.*f); return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y); } void main(){ float y=vUv.y; vec2 p=vec2(vUv.x*6.,y*5.+t*1.6); float n=nz(p)*.6+nz(p*2.3)*.4; float a=smoothstep(.2,.75,y)*(1.-smoothstep(.92,1.,y))*smoothstep(.3,.72,n)*k*pow(vR,.6)*.85; vec3 c=mix(vec3(.30,.27,.25),vec3(.62,.36,.2),smoothstep(.55,1.,y)); gl_FragColor=vec4(c*(.75+.25*n),a); }",u={hi:{o:["#8cc8ff","#1d5cff"],i:["#e2f1ff","#4f9dff"],light:"#7fb6ff",gc:[.45,.7,1],sc:[.55,.65,.85],sm:.35,soot:!1,label:"\u9AD8\u6548 \xB7 \u84DD\u7130",tip:"\u540C\u6837\u7684\u6210\u672C\u80FD\u529B\u660E\u663E\u66F4\u9AD8\uFF0C\u6216\u6CA1\u6709\u4EFB\u4F55\u6A21\u578B\u6BD4\u5B83\u53C8\u4FBF\u5B9C\u53C8\u5F3A"},mid:{o:["#ffd9a0","#ff5a24"],i:["#ffffff","#8fd0ff"],light:"#ffa060",gc:[1,.55,.25],sc:[.6,.66,.8],sm:.5,soot:!1,label:"\u6807\u51C6",tip:"\u80FD\u529B\u4E0E\u6210\u672C\u5927\u81F4\u5728\u8D8B\u52BF\u7EBF\u4E0A"},lo:{o:["#ff9446","#9a2406"],i:["#ffcf90","#e0601c"],light:"#ff7a3a",gc:[.9,.38,.12],sc:[.28,.24,.22],sm:.75,soot:!0,label:"\u4F4E\u6548 \xB7 \u9ED1\u70DF",tip:"\u540C\u6837\u7684\u6210\u672C\uFF0C\u80FD\u529B\u660E\u663E\u4F4E\u4E8E\u8D8B\u52BF\u7EBF"}},d=new Map,g=new Map;function _(O){return d.has(O)||d.set(O,new Promise(St=>{let Et=new Image;Et.onload=()=>St(Et),Et.onerror=()=>St(null),Et.src=O.includes("/")?O:`${a}brands/${O}`})),d.get(O)}function m(O,St){let Et=`${O.src}|${St}`;if(!g.has(Et)){let At=document.createElement("canvas");At.width=At.height=128;let Ot=At.getContext("2d");Ot.drawImage(O,0,0,128,128),Ot.globalCompositeOperation="source-in",Ot.fillStyle=St,Ot.fillRect(0,0,128,128),g.set(Et,At)}return g.get(Et)}let p=-1.24,S=1.6,w=(S-p)/120,y=typeof innerWidth=="number"&&innerWidth<600,E=y?256:512,M={openai:"#f3f3f1",xai:"#2e3238",zhipuai:"#b9c2cc"},I={alibaba:"qwen.svg",xiaomi:"xiaomi-mi.svg"},v={xiaomi:["#ff8a33","#ff6900","#e65c00"]},C={xiaomi:.8},L=i??(e?(e.mapping=Tr,e):null),N=new Fa,P=new Map,B=(O,St)=>(P.has(O)||P.set(O,new Promise(Et=>N.load(O,At=>{At.colorSpace=St?Ye:ui,At.anisotropy=4,At.userData.shared=!0,Et(At)},void 0,()=>Et(null)))),P.get(O)),F=new Map;function W(O,St,Et){let At=`${Et}|${O}|${St}`;return F.has(At)||F.set(At,(async()=>{let Ot=Sf(Et);if(!Ot)return null;let Dt=Ur(O,St),tt=Dt.glyph?await _(Dt.glyph):null,it=O==="xai"?M.xai:Dt.base,_t=Ot.top-Ot.cut,bt=_t>.2,mt=y?256:512,Ct=mt/2,Qt=document.createElement("canvas");Qt.width=mt,Qt.height=Ct;let V=Qt.getContext("2d"),ut=ne=>Ct*(1-ne),xt=ne=>Ot.cut+ne*_t,gt=bt?{lattice:[.17,.43,.69],diagonal:[.17,.43,.69],rings:[.25,.58],split:[.22,.62]}[Dt.pattern]:[.4],yt=Math.max(...gt.map(ne=>Ot.r(xt(ne)))),Bt=.46,Ut=.8,Zt=gt.length>1?(gt[1]-gt[0])*_t:_t,ee=Math.min(.085,Zt*(bt?.62:.5));if(V.fillStyle=it,V.fillRect(0,0,mt,Ct),bt&&Dt.pattern==="split"&&(V.fillStyle=Dt.ink,V.fillRect(0,0,mt,ut(Bt))),bt&&Dt.pattern==="rings"){let ne=Math.max(1,.014/_t*Ct);for(let re of gt)for(let A of[-.12,.12])V.fillStyle=Dt.ink,V.fillRect(0,ut(re+A)-ne/2,mt,ne)}if(bt&&Dt.pattern==="diagonal"){V.save(),V.strokeStyle=Dt.ink,V.globalAlpha=.35,V.lineWidth=mt/170;for(let ne=-mt;ne<mt*2;ne+=mt/6)V.beginPath(),V.moveTo(ne,ut(.08)),V.lineTo(ne+mt*.55,ut(Ut)),V.stroke();V.restore()}if(tt&&gt.forEach((ne,re)=>{let A=Ot.r(xt(ne)),x=Math.max(.25,A/yt),G=Dt.pattern==="rings",Y=ee*(G?.85:1),at=Math.max(3,Math.round((G?8:5)*x)),Mt=mt/at,Rt=Y/(2*Math.PI*A)*mt,st=Y/_t*Ct,ft=Dt.pattern==="diagonal"?re*Mt/2:re%2?Mt/2:0;for(let Pt=-1;Pt<=at;Pt++){let Ht=Dt.pattern==="split"&&ne>Bt?it:Dt.inks?Dt.inks[((Pt+re)%Dt.inks.length+Dt.inks.length)%Dt.inks.length]:Dt.ink;V.save(),V.translate(Pt*Mt+ft,ut(ne)),V.scale(Rt/st,1),Dt.pattern==="diagonal"&&V.rotate(-.45),V.drawImage(m(tt,Ht),-st/2,-st/2,st,st),V.restore()}}),V.fillStyle=Dt.cap,V.fillRect(0,0,mt,ut(Ut)),bt){let ne=[...Dt.trim,...Dt.trim];ne.forEach((re,A)=>{V.fillStyle=re,V.fillRect(A*mt/ne.length,ut(.055),mt/ne.length+1,Ct*.055+1)})}let U=new Xn(Qt);return U.colorSpace=Ye,U.wrapS=ns,U.anisotropy=4,U.userData.shared=!0,U})()),F.get(At)}let rt=new Map;function nt(O,St){let Et=`${O}|${St}`;if(!rt.has(Et)){let Ot=document.createElement("canvas");Ot.width=Ot.height=256;let Dt=new Xn(Ot);Dt.colorSpace=Ye,Dt.anisotropy=4,Dt.userData.shared=!0;let tt=_t=>{let bt=Ot.getContext("2d"),mt=256/2,Ct=256/2-1;bt.clearRect(0,0,256,256);let Qt=bt.createRadialGradient(mt-Ct*.3,mt-Ct*.35,Ct*.05,mt,mt,Ct),V=v[O];if(Qt.addColorStop(0,V?.[0]??"#2c3443"),Qt.addColorStop(.6,V?.[1]??"#11151d"),Qt.addColorStop(1,V?.[2]??"#07090d"),bt.beginPath(),bt.arc(mt,mt,Ct,0,Math.PI*2),bt.fillStyle=Qt,bt.fill(),bt.save(),bt.clip(),bt.beginPath(),bt.ellipse(mt-Ct*.12,mt-Ct*.58,Ct*.7,Ct*.3,-.25,0,7),bt.fillStyle="rgba(255,255,255,.08)",bt.fill(),bt.restore(),bt.beginPath(),bt.arc(mt,mt,256*.47,0,Math.PI*2),bt.strokeStyle=St,bt.lineWidth=256*.045,bt.stroke(),_t){let ut=194.56*(C[O]??1);bt.drawImage(m(_t,"#ffffff"),mt-ut/2,mt-ut/2,ut,ut)}else bt.fillStyle="#ffffff",bt.font=`800 ${Math.round(256*.5)}px 'Manrope', sans-serif`,bt.textAlign="center",bt.textBaseline="middle",bt.fillText((r[O]??O)[0]??"?",mt,mt+256*.03);Dt.needsUpdate=!0};tt(null);let it=I[O]??Ur(O).glyph??o.logos[O];it&&_(it).then(_t=>_t&&tt(_t)),rt.set(Et,Dt)}return rt.get(Et)}let dt=t.lodDistance??7;function Q(O,St,Et,At,Ot,Dt,tt){let it=Mf(O,y),_t=O==="heavy",bt=Ur(St,Et).colour,mt=_t?null:M[St]??bt,Ct=new Je;Ct.rotation.y=.4*Math.PI;let Qt=new fa;Ct.add(Qt);let V=new zn({map:nt(St,bt),transparent:!0,alphaTest:.5,roughness:.32,metalness:.15,envMap:L,envMapIntensity:.8,polygonOffset:!0,polygonOffsetFactor:-2}),ut=new zn({color:_t?"#9a9590":"#6d6a66",metalness:.9,roughness:.38,side:Sn,transparent:!0,forceSinglePass:!0,envMap:L,envMapIntensity:1.2});At.push(V,ut);let xt=bf(O);xt.userData.shared=!0;let gt=it.levels.map((yt,Bt)=>{yt.hull.userData.shared=!0,yt.bells&&(yt.bells.userData.shared=!0);let Ut=Ef(O,{near:Bt===0&&!y,envMap:L,head:mt,band:bt});Object.defineProperty(Ut,"transparent",{get(){return this.opacity<.999},set(){},configurable:!0}),Ut.forceSinglePass=!0,At.push(Ut);let Zt=new Je,ee=new ve(yt.hull,Ut);return ee.visible=!1,Zt.add(ee,new ve(xt,V)),yt.bells&&Zt.add(new ve(yt.bells,ut)),Qt.addLevel(Zt,Bt===0?0:dt),{mat:Ut,body:ee}});Promise.all([B(wf(a,O,E),!0),B(Tf(a,O),!1)]).then(([yt,Bt])=>{if(yt)for(let{mat:Ut,body:Zt}of gt)Ut.map=yt,Ut.isMeshPhysicalMaterial?(Ut.metalnessMap=Ut.roughnessMap=Bt,_t||(Ut.bumpMap=yt)):(Ut.metalness=_t?.75:.04,Ut.roughness=_t?.36:.42),Ut.needsUpdate=!0,Zt.visible=!0}),mt&&t.headPattern!==!1&&W(St,bt,O).then(yt=>{if(yt)for(let{mat:Bt}of gt){let Ut=Bt.userData.livery;Ut.uPat.value=yt,Ut.uPatOn.value=1}});for(let yt of it.nozzles){let Bt=Dt(yt.r*.95,.6+yt.r*2,Ot("#ffd9a0","#ff5a24"));Bt.position.x=yt.x,Bt.position.z=yt.z,Ct.add(Bt),tt.push(Bt)}return Ct.userData.span=it.span,Ct}function ct(O){let St=s(O.dev),Et=new Je,At=[],Ot=Tt=>(At.push(Tt),Tt),Dt=vf.includes(O.shape)&&O.shape!=="heavy"?O.shape:kc(O.dev,zc(O.id)),tt=document.createElement("canvas");tt.width=tt.height=2;let it=new Xn(tt),_t=it,bt=it,mt=Ot(new zn({map:it})),Ct=(Tt,Xt)=>new Oe({transparent:!0,depthWrite:!1,blending:on,uniforms:{t:{value:0},k:{value:1},c0:{value:new se(Tt)},c1:{value:new se(Xt)}},vertexShader:c,fragmentShader:l}),Qt=(Tt,Xt,Jt)=>{let le=new ya(Tt,Xt,32,1,!0);le.rotateX(Math.PI),le.translate(0,-Xt/2,0);let z=new ve(le,Jt);return z.position.y=p+.02,z},V=new Je;Et.add(V);let ut=[],xt=Q(Dt,O.dev,St,At,Ct,Qt,ut);V.add(xt);let gt=xt.userData.span,yt=[V],Bt=Qt(.26,1.7,Ct("#ffd9a0","#ff5a24")),Ut=Qt(.12,.95,Ct("#ffffff","#8fd0ff"));Et.add(Bt,Ut);let Zt=new ka("#ffa060",1.5,6,2);Zt.position.y=-1.7,Et.add(Zt);let ee=new Je;ee.position.y=.15,ee.visible=!1;let U=new ve(new Wi(.6,.016,10,160),new nn({color:"#d99a2b",transparent:!0,opacity:.95}));U.rotation.x=Math.PI/2-.38,ee.add(U);let ne=new ve(new $n(.036,16,12),new nn({color:"#ffd27a"}));ne.position.set(.6,0,0),U.add(ne);let re=new Je;re.visible=!1,Et.add(re);let A=Q("heavy",O.dev,St,At,Ct,Qt,[]);re.add(A);let x=p,G=A.userData.span,Y=ee,at=new Je;at.visible=!1,Et.add(at);let Mt=new Gi;Mt.moveTo(0,0),Mt.lineTo(.34,-.5),Mt.lineTo(.36,-.66),Mt.lineTo(0,-.46),Mt.closePath(),new Ia(Mt,{depth:.022,bevelEnabled:!0,bevelThickness:.008,bevelSize:.008,bevelSegments:2}).translate(0,0,-.011);let st=new nn({color:"#bfe6ff",transparent:!0,opacity:.6,blending:on,depthWrite:!1});At.push(st);let ft=[];for(let Tt=0;Tt<7;Tt++){let Xt=Tt/7*Math.PI*2,Jt=new ve(new Vi(.006,.006,.9,6),st.clone());Jt.position.set(Math.cos(Xt)*.48,0,Math.sin(Xt)*.48),Jt.userData.o=Tt*.37%1,at.add(Jt),ft.push(Jt)}let Pt=ut,Ht=new ve(new Wi(1.15,.03,10,96),new nn({color:"#ffd37a",transparent:!0})),Nt=new ve(new $n(1,8,8),new nn({visible:!1}));return Nt.scale.set(Math.max(.9,gt*2.4),1.6,Math.max(.9,gt*2.4)),Nt.position.y=.15,Et.add(Nt),{g:Et,shape:Dt,span:gt,mats:At,outer:Bt,inner:Ut,light:Zt,ring:Ht,hit:Nt,heavy:re,bOuter:Pt,heavyNozzle:x,heavySpan:G,halo:Y,stdParts:yt,racer:at,streaks:ft,steel:mt,hullMap:it,boltMap:_t,steelMap:bt}}return{shapeFor:kc,raw(O){n[O.dev]=O.colour;let St=ct({id:O.id,name:O.name,dev:O.dev,shape:O.shape});return St.hit.userData.modelId=O.id,Object.assign(St,{SOOT_F:f,FUEL:u,FLAME_V:c,TRAIL_F:h,NOZZLE_Y:p}),St},make(O,St,Et=!1){n[O.developerId]=O.colour;let At=ct({id:O.id,name:O.name,dev:O.developerId,shape:O.shape});At.hit.userData.modelId=O.id,At.heavy.visible=St,At.racer.visible=!St&&O.racer,At.stdParts.forEach(it=>it.visible=!St),At.halo.visible=!1,At.steel.map=St?At.steelMap:O.racer?At.boltMap:At.hullMap,At.steel.metalness=St?.92:.35,At.steel.roughness=St?.2:.34,O.fuel==="lo"&&(At.outer.material.fragmentShader=f,At.outer.material.blending=us,At.outer.material.needsUpdate=!0);let Ot=u[O.fuel];for(let[it,_t]of[[At.outer,Ot.o],[At.inner,Ot.i]])it.material.uniforms.c0.value.set(_t[0]),it.material.uniforms.c1.value.set(_t[1]);At.light.color.set(Ot.light);let Dt=O.cost===0?0:Math.max(.15,Math.min(1,(Math.log10(O.cost??.1)+2.2)/2.8));At.outer.scale.set(.8+Dt*.6,.6+Dt*1.2,.8+Dt*.6),At.inner.scale.set(1,.7+Dt*.6,1),At.light.intensity=.6+Dt*1.4;let tt=new Je;return At.g.add(tt),Et&&(At.outer.visible=!1,At.inner.visible=!1,At.bOuter.forEach(it=>it.visible=!1),At.light.intensity=0),{root:At.g,flame:tt,tipHeight:1.6,span:St?At.heavySpan:At.span,hit:At.hit,animate(it){At.outer.material.uniforms.t.value=At.inner.material.uniforms.t.value=it,At.outer.material.uniforms.k.value=At.inner.material.uniforms.k.value=Et||O.cost===0?0:1,At.bOuter.forEach(_t=>{_t.material.uniforms.t.value=it,_t.material.uniforms.k.value=Et||O.cost===0?0:1}),At.g.rotation.y=-.2-.4*Math.PI},dispose(){let it=new Set,_t=new Set,bt=new Set;At.g.traverse(mt=>{mt.geometry&&!mt.geometry.userData.shared&&it.add(mt.geometry);for(let Ct of Array.isArray(mt.material)?mt.material:mt.material?[mt.material]:[]){_t.add(Ct);for(let Qt of Object.values(Ct))Qt?.isTexture&&Qt!==i&&!Qt.userData.shared&&bt.add(Qt)}}),it.forEach(mt=>mt.dispose()),_t.forEach(mt=>mt.dispose()),bt.forEach(mt=>mt.dispose())}}},dispose(){}}}var Jn={floor:0,minSpan:30,padAbove:3,padBelow:5,round:10,emptyMax:60,tickStep:10,fineTickStep:5,fineTickSpan:40,bandBelow:4,bandAbove:3,bandMinSpan:14,bandDefault:[44,60],gaugeMin:30,gaugeMax:100,stops:[{at:40,zh:"\u8FD1\u5730\u8F68\u9053",en:"Low Earth orbit"},{at:50,zh:"\u6708\u7403",en:"Moon",body:"moon"},{at:60,zh:"\u706B\u661F",en:"Mars",body:"mars"},{at:70,zh:"\u6728\u661F",en:"Jupiter",body:"jupiter"},{at:80,zh:"\u571F\u661F",en:"Saturn",body:"saturn"},{at:90,zh:"\u65E5\u7403\u5C42\u9876",en:"Heliopause"},{at:100,zh:"\u661F\u8FB0\u5927\u6D77",en:"The stars",final:!0}]},Ph=(i=Jn)=>i.stops[i.stops.length-1].at;function Lh(i,t=Jn,e){let n,s;if(!i.length)n=t.floor,s=t.emptyMax;else{let r=t.round,a=Math.ceil((Math.max(...i)+t.padAbove)/r)*r,o=Math.max(t.floor,Math.floor((Math.min(...i)-t.padBelow)/r)*r);a-o<t.minSpan&&(o=Math.max(t.floor,a-t.minSpan)),n=o,s=Math.max(a,o+t.minSpan)}return e?.min!=null&&(n=e.min),e?.max!=null&&(s=e.max),{abilityMin:n,abilityMax:s}}function Nh(i,t,e=Jn,n){let s=t-i,r=n&&n>0?n:s>e.fineTickSpan?e.tickStep:e.fineTickStep;return Array.from({length:Math.floor(s/r)+1},(a,o)=>i+o*r)}function Dh(i,t=Jn,e){let n=t.bandDefault[0],s=t.bandDefault[1];return i.length&&(n=Math.floor(Math.min(...i))-t.bandBelow,s=Math.max(Math.ceil(Math.max(...i))+t.bandAbove,n+t.bandMinSpan)),e?.min!=null&&(n=e.min),e?.max!=null&&(s=e.max),{min:n,max:s}}function Uh(i,t=Jn){let e=t.gaugeMin,n=t.gaugeMax;return(Math.max(e,Math.min(n,i))-e)/(n-e)*100}function Hc(i,t){let e=typeof i=="function"?i():i,n=s=>{let r=e?.[s];return typeof r=="number"&&Number.isFinite(r)?r:t[s]};return{top:n("top"),right:n("right"),bottom:n("bottom"),left:n("left")}}function Vc(i,t,e){return{x:i.left,r:t-i.right,y:i.top,b:e-i.bottom}}var Fh=.6,Oh=3,If=.45,Gc=()=>({zoom:1,panX:0,panY:0});function Wc(i,t,e){let n=t*If,s=e*If;return{zoom:Math.min(Oh,Math.max(Fh,i.zoom)),panX:Math.min(n,Math.max(-n,i.panX)),panY:Math.min(s,Math.max(-s,i.panY))}}function Bh(i,t,e,n,s,r){let a=Math.min(Oh,Math.max(Fh,i.zoom*t)),o=a/i.zoom;return Wc({zoom:a,panX:i.panX+(e.x-n.x)*(1-o),panY:i.panY+(e.y-n.y)*(1-o)},s,r)}function Pf(i,t,e){let n=e?1:.2;return i.zoom+=(t.zoom-i.zoom)*n,i.panX+=(t.panX-i.panX)*n,i.panY+=(t.panY-i.panY)*n,Math.abs(t.zoom-i.zoom)<1e-4&&(i.zoom=t.zoom),Math.abs(t.panX-i.panX)<.01&&(i.panX=t.panX),Math.abs(t.panY-i.panY)<.01&&(i.panY=t.panY),i}var Lf="http://www.w3.org/2000/svg",E3="button, a, input, select, textarea, details",w3=i=>i==null?"\u2014":(i<.1?i.toFixed(3):i<1?i.toFixed(2):i.toFixed(1).replace(/\.0$/,""))+"\xD7",Fr=i=>String(i).replace(/[&<>"]/g,t=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"})[t]),Nf=!1,T3={top:48,right:32,bottom:72,left:32},A3={top:48,right:16,bottom:78,left:16};function zh(i){let t=i.container,e=i.logo??(R=>`<span>${Fr(R.slice(0,1).toUpperCase())}</span>`),n=R=>{let k=document.createElement("div");return k.className=R,k},s=n("lf-scene"),r=n("lf-plates"),a=document.createElementNS(Lf,"svg"),o=n("lf-voyage");s.setAttribute("role","group"),a.setAttribute("class","lf-leaders"),r.appendChild(a),t.append(s,r,o);let c=i.language??"zh",l=()=>c==="zh",h=()=>{s.setAttribute("aria-label",l()?"\u7ACB\u4F53\u53D1\u5C04\u573A\uFF1A\u6BCF\u679A\u706B\u7BAD\u662F\u4E00\u4E2A\u6A21\u578B\uFF0C\u9AD8\u5EA6\u662F\u80FD\u529B\uFF0C\u5C3E\u7130\u7C97\u7EC6\u662F\u6210\u672C\uFF0C\u7EB5\u6DF1\u662F\u822A\u65F6\uFF1B\u53EF\u62D6\u52A8\u65CB\u8F6C":"3D launch field: each rocket is a model; altitude is ability, plume is cost, depth is task time; drag to rotate"),o.setAttribute("aria-label",l()?"\u80FD\u529B\u822A\u7A0B\u5C3A":"Ability voyage gauge")};h();let f=i.scale??Jn,u=f.stops,d=Ph(f),g=i.axis??null,_=()=>Hc(i.insets,F()?A3:T3),m=()=>i.focusInsets?Hc(i.focusInsets,_()):_(),p=typeof i.ignoreTargets=="function"?i.ignoreTargets:R=>!!R.closest?.(i.ignoreTargets??E3),S=i.reducedMotion??matchMedia("(prefers-reduced-motion: reduce)").matches,w=i.reducedMotion===!0,y=i.rocketScale??1,E={models:[]},M={},I=new Set,v=null,C=null,L=null,N=R=>E.models.find(k=>k.dev===R)?.colour??"#b8b0a8",P=0,B=0,F=()=>P<720,W=innerWidth<720,rt=W?13:15,nt=4,dt=W?-6.5:-9,Q=-dt,ct=3.2,O=W?-5.5:-8.5,St=2.3,Et=46,At=new D(0,-Et-9,-8),Ot=()=>0,Dt=f.bandDefault[0],tt=f.bandDefault[1],it=R=>Math.max(1.4,(R-Dt)/(tt-Dt)*rt+nt),_t=-1.3,bt=.5,mt=1,Ct=R=>dt+.8+(Math.log10(R)-_t)/(bt-_t)*(Q-dt-1.6),Qt=R=>R==null?St:1.2-R/mt*(1.2-O-.6),V=(R,k,Z)=>new D(R,k,Z),ut;try{ut=new Rc({antialias:!0,powerPreference:"high-performance",preserveDrawingBuffer:!1})}catch(R){throw s.remove(),r.remove(),o.remove(),R}ut.setPixelRatio(Math.min(devicePixelRatio,2)),ut.outputColorSpace=Ye,ut.toneMapping=Ts,ut.toneMappingExposure=1.05,s.appendChild(ut.domElement);let xt=new ca;xt.background=new se("#010205");let gt=new yn(30,1,.1,4e3),yt=[],Bt=R=>(yt.push(R),R),Ut=V(-.93,.07,-.36).normalize(),Zt=V(.5,.55,.68).normalize(),ee=new Er("#ffe4c4",2.6);ee.position.copy(Ut).multiplyScalar(50),xt.add(ee);let U=new Er("#d8e6ff",1.25);U.position.copy(Zt).multiplyScalar(50),xt.add(U),xt.add(new Oa("#7d9cd6","#0d2a5c",.45));let ne=(R,k,Z)=>[(Math.atan2(R.z,R.x)/(2*Math.PI)+.5)*k,(1-(Math.asin(R.y)/Math.PI+.5))*Z],re=(()=>{let Z=document.createElement("canvas");Z.width=1024,Z.height=512;let $=Z.getContext("2d"),pt=$.createLinearGradient(0,0,0,512);[[0,"#06080f"],[.44,"#121a2c"],[.49,"#5d93d6"],[.5,"#bfe2ff"],[.52,"#2a64b4"],[.6,"#0d2752"],[.8,"#061330"],[1,"#02060f"]].forEach(([Wt,te])=>pt.addColorStop(Wt,te)),$.fillStyle=pt,$.fillRect(0,0,1024,512);let ot=(Wt,te,_e,lt)=>{let[ce,oe]=ne(Wt,1024,512);for(let ae of[-1024,0,1024]){$.save(),$.translate(ce+ae,oe),$.scale(te,_e);let De=$.createRadialGradient(0,0,0,0,0,1);lt.forEach(([Ue,Te])=>De.addColorStop(Ue,Te)),$.fillStyle=De,$.beginPath(),$.arc(0,0,1,0,Math.PI*2),$.fill(),$.restore()}};ot(Zt,120,70,[[0,"rgba(235,242,255,1)"],[.55,"rgba(200,220,255,.75)"],[1,"rgba(200,220,255,0)"]]),ot(V(.7,.35,-.6).normalize(),40,110,[[0,"rgba(150,195,255,.9)"],[1,"rgba(150,195,255,0)"]]),ot(V(-.2,.75,.6).normalize(),220,26,[[0,"rgba(255,255,255,.55)"],[1,"rgba(255,255,255,0)"]]),ot(Ut,70,40,[[0,"rgba(255,250,235,1)"],[.2,"rgba(255,220,170,1)"],[1,"rgba(255,170,90,0)"]]);for(let Wt=0;Wt<260;Wt++){let te=Math.random()*1024,_e=512*(.56+Math.random()*.4);$.fillStyle=`rgba(255,${150+Math.random()*60|0},80,${.3+Math.random()*.5})`,$.fillRect(te,_e,1.5,1.5)}let It=new Xn(Z);return It.colorSpace=Ye,It.wrapS=ns,It.minFilter=Si,Bt(It)})(),A=Cf(null,{studio:re,assetBase:i.assetBase}),x=xf(xt),G=(R,k=128)=>{let Z=document.createElement("canvas");Z.width=Z.height=k;let $=Z.getContext("2d"),pt=$.createRadialGradient(k/2,k/2,0,k/2,k/2,k/2);R.forEach(([It,Wt])=>pt.addColorStop(It,Wt)),$.fillStyle=pt,$.fillRect(0,0,k,k);let ot=new Xn(Z);return ot.colorSpace=Ye,Bt(ot)},Y=G([[0,"rgba(255,255,255,1)"],[.25,"rgba(255,255,255,.45)"],[1,"rgba(255,255,255,0)"]]),at;{let k=new Float32Array(9600),Z=new Float32Array(3200),$=new Float32Array(3200);for(let oe=0;oe<3200;oe++){let ae=Math.random()*2-1,De=Math.random()*Math.PI*2,Ue=1500,Te=Math.sqrt(1-ae*ae);k.set([Ue*Te*Math.cos(De),Ue*ae,Ue*Te*Math.sin(De)],oe*3),Z[oe]=Math.random()*6.28,$[oe]=Math.random()**4*3.4+.7}let pt=new Ae;pt.setAttribute("position",new tn(k,3)),pt.setAttribute("ph",new tn(Z,1)),pt.setAttribute("sz",new tn($,1)),at=new Oe({transparent:!0,depthWrite:!1,uniforms:{t:{value:0}},vertexShader:"attribute float ph; attribute float sz; uniform float t; varying float a; void main(){ a=.6+.4*sin(t*1.1+ph); gl_PointSize=sz*(.75+.25*a)*1.5; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",fragmentShader:"varying float a; void main(){ float d=length(gl_PointCoord-.5); gl_FragColor=vec4(vec3(.92,.95,1.),a*smoothstep(.5,0.,d)); }"}),xt.add(new ga(pt,at));let ot=document.createElement("canvas");ot.width=1024,ot.height=512;let It=ot.getContext("2d");[[300,220,320,"rgba(70,90,170,.22)"],[640,180,280,"rgba(40,90,170,.18)"],[820,290,220,"rgba(150,80,140,.10)"]].forEach(([oe,ae,De,Ue])=>{let Te=It.createRadialGradient(oe,ae,0,oe,ae,De);Te.addColorStop(0,Ue),Te.addColorStop(1,"rgba(0,0,0,0)"),It.fillStyle=Te,It.fillRect(0,0,1024,512)});let Wt=Bt(new Xn(ot));Wt.colorSpace=Ye;let te=new ve(new rs(2600,1300),new nn({map:Wt,transparent:!0,depthWrite:!1,blending:on}));te.position.set(200,420,-1300),xt.add(te);let _e=Ut.clone().multiplyScalar(1100).add(At),lt=new is(new ki({map:G([[0,"rgba(255,255,250,1)"],[.06,"rgba(255,245,225,1)"],[.16,"rgba(255,200,140,.5)"],[.45,"rgba(255,150,80,.08)"],[1,"rgba(255,120,60,0)"]],256),blending:on,depthWrite:!1}));lt.position.copy(_e),lt.scale.setScalar(340),xt.add(lt);let ce=new is(new ki({map:Y,color:"#9cc8ff",blending:on,depthWrite:!1,opacity:.55}));ce.position.copy(_e),ce.scale.set(1500,14,1),xt.add(ce)}let Mt=[],Rt=new Je,st=0;document.fonts?.ready.then(()=>st++),xt.add(Rt);function ft(R,k,Z,$,pt=2){let ot=[];for(let It=0;It<=pt;It++)ot.push(V(Z+($-Z)*(It/pt),R,k));return ot}let Pt=R=>{let k=document.createElement("canvas");k.width=256,k.height=128;let Z=k.getContext("2d");R(Z,256,128);let $=Bt(new Xn(k));return $.colorSpace=Ye,$},Ht=(()=>{let R=7;return()=>(R=R*16807%2147483647)/2147483647})(),Nt={moon:Pt((R,k,Z)=>{R.fillStyle="#b9bcc2",R.fillRect(0,0,k,Z);for(let $=0;$<70;$++){let pt=2+Ht()*9;R.fillStyle=`rgba(${Ht()<.5?"70,74,82":"225,228,232"},.35)`,R.beginPath(),R.arc(Ht()*k,Ht()*Z,pt,0,7),R.fill()}}),mars:Pt((R,k,Z)=>{R.fillStyle="#b4532c",R.fillRect(0,0,k,Z);for(let $=0;$<50;$++)R.fillStyle=`rgba(${Ht()<.6?"90,36,22":"214,120,72"},.35)`,R.beginPath(),R.ellipse(Ht()*k,Ht()*Z,6+Ht()*26,3+Ht()*10,0,0,7),R.fill();R.fillStyle="rgba(255,250,245,.8)",R.fillRect(0,0,k,7),R.fillRect(0,Z-6,k,6)}),jupiter:Pt((R,k,Z)=>{let $=["#d8c4a4","#b98d63","#e7dcc8","#a8714b","#d9b98e","#c69c74","#efe6d6"];for(let pt=0;pt<Z;pt+=6)R.fillStyle=$[(pt/6+(Ht()*2|0))%$.length],R.fillRect(0,pt,k,6);R.fillStyle="#b5523a",R.beginPath(),R.ellipse(170,82,16,8,0,0,7),R.fill()}),saturn:Pt((R,k,Z)=>{let $=["#e6d3a6","#d4bb85","#efe2c0","#c9ad78"];for(let pt=0;pt<Z;pt+=8)R.fillStyle=$[pt/8%$.length],R.fillRect(0,pt,k,8)})},Tt=R=>{R.traverse(k=>{k.geometry?.dispose(),k.isInstancedMesh&&k.dispose();for(let Z of[].concat(k.material||[]))Z.dispose()}),R.clear()};function Xt(R){Tt(Rt),Mt.forEach($=>$.el.remove()),Mt.length=0;let k=($,pt,ot="",It=null,Wt=0)=>{let te=document.createElement("div");te.className="ltag "+ot,te.innerHTML=$,r.appendChild(te),Mt.push({el:te,v:pt,far:It,radius:Wt,atFar:!1})};for(let $ of u){let pt=$.at,ot=$.body&&Nt[$.body];if(pt<Dt||pt>tt)continue;let It=!!$.final,Wt=ft(it(pt),O,dt+.5,Q-.5),te=new Hi(new Ae().setFromPoints(Wt),It?new Da({color:"#ffd37a",dashSize:.3,gapSize:.2}):new li({color:"#cfe2ff",transparent:!0,opacity:.16}));It&&te.computeLineDistances(),Rt.add(te);let _e=V(Q+.2,Wt[0].y,O);if(ot){let lt=new ve(new $n($.body==="jupiter"?.6:.42,48,32),new zn({map:ot,roughness:.9}));if(lt.position.copy(_e),lt.userData.spin=!0,Rt.add(lt),$.body==="saturn"){let ce=new ve(new yr(.62,.95,64),new zn({color:"#d9c6a0",transparent:!0,opacity:.75,side:Sn,roughness:.8}));ce.position.copy(_e),ce.rotation.x=-1.2,ce.rotation.y=.3,Rt.add(ce)}}k(`${l()?$.zh:$.en}<small>Index ${pt}</small>`,_e,(It?"kar":"")+(ot?" body":""),Wt[0].clone(),ot?$.body==="saturn"?.95:$.body==="jupiter"?.6:.42:0)}let Z=u.find($=>$.at>tt);Z&&W&&k(l()?`\u2191 \u4E0B\u4E00\u7AD9 ${Z.zh} \xB7 ${Z.at}<small>${R>=d?"\u5DF2\u9A76\u5165\u661F\u8FB0\u5927\u6D77":`\u7EC8\u70B9 \u661F\u8FB0\u5927\u6D77 ${d}\u3000\u9886\u5148\u8005\u8FD8\u5DEE ${(d-R).toFixed(1)}`}</small>`:`\u2191 Next stop ${Z.en} \xB7 ${Z.at}<small>${R>=d?"Out among the stars":`Destination: the stars at ${d} \xB7 the leader is ${(d-R).toFixed(1)} away`}</small>`,V(dt+.5,Ot()+it(tt)+1.2,O),"next")}{let R=Q-dt+3,k=ct-O+2,Z=new ve(new rs(R,k),new Oe({transparent:!0,depthWrite:!1,blending:on,uniforms:{size:{value:new vt(R,k)}},vertexShader:"varying vec2 vUv; void main(){ vUv=uv; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }",fragmentShader:"uniform vec2 size; varying vec2 vUv; void main(){ vec2 p=vUv*size; vec2 g=abs(fract(p-.5)-.5)/fwidth(p); float line=1.-min(min(g.x,g.y),1.); vec2 e=min(vUv,1.-vUv)*size; float fade=smoothstep(0.,2.5,min(e.x,e.y)); float back=mix(.35,1.,vUv.y); gl_FragColor=vec4(vec3(.45,.68,1.)*(line*.16+.025)*fade*back,1.); }"}));Z.rotation.x=-Math.PI/2,Z.position.set((dt+Q)/2+.5,-.01,(ct+O)/2),xt.add(Z)}let Jt=new Je;xt.add(Jt);let le=[];function z(R,k,Z){let $=document.createElement("div");$.className="tick3 "+(Z??""),$.textContent=R,r.appendChild($),le.push({el:$,v:k})}let Ft=()=>{let R=[];for(let k=Math.floor(_t)-1;k<=Math.ceil(bt)+1;k++)for(let Z of[1,3]){let $=Z*10**k;Math.log10($)>=_t&&Math.log10($)<=bt&&R.push($)}return R};function T(){Tt(Jt),le.forEach(Z=>Z.el.remove()),le.length=0;let R=[];for(let Z=0;Z<=60;Z++){let $=dt+(Q-dt)*(Z/60);R.push(V($,Ot()+.03,ct))}Jt.add(new Hi(new Ae().setFromPoints(R),new li({color:"#ffb27a",transparent:!0,opacity:.8})));for(let Z of Ft()){let $=Ct(Z);if($<dt||$>Q)continue;let pt=Ot();Jt.add(new Hi(new Ae().setFromPoints([V($,pt,ct),V($,pt+.25,ct)]),new li({color:"#ffb27a"}))),z(w3(Z),V($,pt-.35,ct+.2))}z(l()?"\u6CB9\u8017 \xB7 \u6210\u672C\u500D\u7387 \u2192":"Fuel \xB7 cost ratio \u2192",V(Q-1.2,Ot()-1,ct+.4),"axis");let k=[];for(let Z=0;Z<=40;Z++){let $=ct-(ct-O)*(Z/40);k.push(V(Q+.6,Ot()+.03,$))}Jt.add(new Hi(new Ae().setFromPoints(k),new li({color:"#c9b3ff",transparent:!0,opacity:.8})));for(let Z of[.25,.5,1,2,3])Z<=mt&&z((l()?"\u822A\u65F6 ":"Time ")+Z+"\xD7",V(Q+1.2,Ot(),Qt(Z)));z(l()?"\u822A\u65F6\u672A\u77E5 \xB7 \u524D\u6392":"Time unknown \xB7 front row",V(dt+1.2,Ot()+.1,St),"lane")}let q=new Vi(.1,.55,1,32,1,!0);q.translate(0,-.5,0);let ht=new Vi(.2,.7,1,32,1,!0);ht.translate(0,-.5,0);let X=new Map;function zt(R){let k=X.get(R.id);if(k)return k;let Z=A.raw({id:R.id,name:R.name,dev:R.dev,colour:R.colour,shape:R.shape}),$=new Set([Z.hullMap,Z.boltMap,Z.steelMap]),pt=oe=>{for(let ae of Object.values(oe))ae?.isTexture&&ae!==re&&$.add(ae)};Z.mats.forEach(pt),Z.g.traverse(oe=>{for(let ae of[].concat(oe.material||[]))pt(ae)});for(let oe of $)yt.includes(oe)||yt.push(oe),pf(oe,()=>{},oe.image?.width===oe.image?.height?256:512);mf(Z);let ot=new ve(q,new Oe({transparent:!0,depthWrite:!1,blending:on,uniforms:{t:{value:0},k:{value:1},gc:{value:new D(1,.55,.25)},sc:{value:new D(.6,.66,.8)},sm:{value:.5}},vertexShader:Z.FLAME_V,fragmentShader:Z.TRAIL_F})),It=new ve(ht,new Oe({transparent:!0,depthWrite:!1,uniforms:{t:{value:0},k:{value:0}},vertexShader:Z.FLAME_V,fragmentShader:Z.SOOT_F})),Wt=new Hi(new Ae().setFromPoints([V(0,0,0),V(0,-1,0)]),new li({color:R.colour,transparent:!0,opacity:.22})),te=new ve(new yr(.2,.28,48),new nn({color:R.colour,transparent:!0,opacity:.7,side:Sn}));te.rotation.x=-Math.PI/2;let _e=new is(new ki({map:Y,color:R.colour,blending:on,depthWrite:!1,transparent:!0,opacity:.3})),lt=new is(new ki({map:Y,color:"#b8c2d2",transparent:!0,depthWrite:!1,opacity:0})),ce=new Je;return ce.add(Z.g,Z.ring),xt.add(ce,ot,It,Wt,te,_e,lt),k={m:R,...Z,root:ce,trail:ot,soot:It,drop:Wt,pad:te,padGlow:_e,smoke:lt,fuelKind:null,pos:V(0,0,0),tgt:V(0,0,0),born:performance.now()+X.size*160,flare:1,phase:Math.random()*6.28,screen:{x:0,y:0,z:0},base:{x:0,y:0,z:0}},X.set(R.id,k),k}let wt=null;function xe(R){let k=R.m.fuel??"mid";if(R.fuelKind===k)return;R.fuelKind=k;let Z=R.FUEL[k];for(let $ of[R.outer,...R.bOuter])$.material.uniforms.c0.value.set(Z.o[0]),$.material.uniforms.c1.value.set(Z.o[1]);R.inner.material.uniforms.c0.value.set(Z.i[0]),R.inner.material.uniforms.c1.value.set(Z.i[1]),R.light.color.set(Z.light),R.trail.material.uniforms.gc.value.set(...Z.gc),R.trail.material.uniforms.sc.value.set(...Z.sc),R.trail.material.uniforms.sm.value=Z.sm}let Gt={yaw:-.26,pitch:.12},ie={yaw:-.2,pitch:.16},ke=null,xn=null,Kn;function Or(){let R=E.models.filter($=>I.has($.id)&&M[$.id]);if(wt=Bc(R,$=>M[$.id][1],$=>$.dev)?.id??null,!R.length)return;let k=R.map($=>M[$.id][2]);if(_t=Math.log10(Math.min(...k))-.22,bt=Math.log10(Math.max(...k))+.22,bt-_t<1){let $=(_t+bt)/2;_t=$-.5,bt=$+.5}mt=Math.max(.6,...R.map($=>M[$.id][3]??0))*1.15;let Z=R.map($=>M[$.id][1]);({min:Dt,max:tt}=Dh(Z,f,g??void 0));for(let $ of R){let pt=zt($),ot=M[$.id];pt.m=$,pt.focusPoints?.length!==$.e.length+2&&(pt.focusPoints=Array.from({length:$.e.length+2},()=>V(0,0,0))),pt.tgt.set(Ct(ot[2]),it(ot[1]),Qt(ot[3])),pt.nudge=0}gf(R.map($=>X.get($.id)),W?1:1.3,(W?ie:Gt).yaw);for(let $ of X.values())$.started||($.pos.copy($.tgt),$.started=!0);jh(),T(),Xt(Math.max(...Z)),ke=null,Kn=void 0}let jn=new Je;xt.add(jn);let gs=[];function po(R){if(Tt(jn),gs.forEach(ot=>ot.el.remove()),gs.length=0,Kn=R,!R)return;let k=E.models.find(ot=>ot.id===R);if(!k||!X.has(R))return;let Z=k.colour,$=X.get(R)?.nudge??0,pt=k.e.map(ot=>{let It=Ct(ot[2])+$,Wt=Qt(ot[3]);return V(It,Ot()+it(ot[1]),Wt)});pt.length>1&&jn.add(new ve(new La(new xr(pt,!1,"centripetal"),120,.022,8,!1),new nn({color:Z,transparent:!0,opacity:.5,blending:on,depthWrite:!1}))),k.e.forEach((ot,It)=>{let Wt=new ve(new $n(.1,16,12),new nn({color:ot[3]==null||ot[4]?"#0b1020":Z}));if(Wt.position.copy(pt[It]),jn.add(Wt),ot[3]==null||ot[4]){let _e=new ve(new Wi(.1,.025,8,24),new nn({color:Z}));_e.position.copy(pt[It]),_e.userData.bill=!0,jn.add(_e)}let te=document.createElement("div");te.className="bl3"+(ot[0]===k.rec?" rec":"")+(ot===M[k.id]?" cur":""),te.textContent=`${ot[0]} ${ot[1].toFixed(1)}${ot[4]?l()?" \xB7 \u4F30\u65F6":" \xB7 est. time":ot[3]==null?l()?" \xB7 \u672A\u6D4B\u65F6":" \xB7 time unknown":""}`,te.style.setProperty("--c",Z),r.appendChild(te),gs.push({el:te,v:pt[It]})})}let fi=new Nc(ut,new Ke(1,1,{type:ln}));fi.addPass(new Dc(xt,gt));let Vn=new Dr(new vt(256,256),.75,.28,.86);fi.addPass(Vn),fi.addPass(new Uc);let de={yaw:Gt.yaw,pitch:Gt.pitch,vy:0,vp:0,drag:null},Ti=V(0,10,-2.4),$i=Ti.clone(),_n=0,xs=()=>Vc(_(),P,B),Ls=(R,k=R.tgt)=>V(k.x,Ot()+k.y,k.z),mo=gt.clone(),go=V(0,0,0),Zc=V(0,0,0),Jc=V(0,0,0),Ns={look:V(0,0,0),d:0,fy:0};function Kc(R){let k=R.nudge??0,Z=R.focusPoints;Z[0].set(R.tgt.x,Ot()+R.tgt.y+2.2,R.tgt.z),Z[1].set(R.tgt.x,Ot()+R.tgt.y-2.4,R.tgt.z);for(let oe=0;oe<R.m.e.length;oe++){let ae=R.m.e[oe];Z[oe+2].set(Ct(ae[2])+k,Ot()+it(ae[1]),Qt(ae[3]))}let $=go.copy(Z[0]),pt=Zc.copy(Z[0]);for(let oe of Z)$.min(oe),pt.max(oe);let ot=Ns.look.copy($).add(pt).multiplyScalar(.5),It=Vc(m(),P,B),Wt=It.y,te=It.b,_e=ie,lt=mo;lt.aspect=P/B,lt.clearViewOffset(),lt.updateProjectionMatrix();let ce=24;for(let oe=0;oe<6;oe++){lt.position.set(ot.x+ce*Math.sin(_e.yaw)*Math.cos(_e.pitch),ot.y+ce*Math.sin(_e.pitch),ot.z+ce*Math.cos(_e.yaw)*Math.cos(_e.pitch)),lt.lookAt(ot),lt.updateMatrixWorld();let ae=1/0,De=-1/0,Ue=1/0,Te=-1/0;for(let et of Z){let qe=Jc.copy(et).project(lt),vn=(qe.x*.5+.5)*P,dn=(-qe.y*.5+.5)*B;ae=Math.min(ae,vn),De=Math.max(De,vn),Ue=Math.min(Ue,dn),Te=Math.max(Te,dn)}ce*=Math.max((De-ae)/(P-120),(Te-Ue)/Math.max(120,te-Wt))*1.12}return Ns.d=Math.max(8,ce),Ns.fy=(Wt+te)/2,Ns}function xo(){let R=[V(dt,Ot(),ct),V(Q,Ot(),ct)];for(let It of X.values())if(I.has(It.m.id)){let Wt=Ls(It);R.push(Wt.clone().add(V(0,2.2,0)),Wt.clone().add(V(0,-2.4,0)))}let k=xs(),Z=F()?ie:Gt,$=gt.clone();$.aspect=P/B,$.clearViewOffset(),$.updateProjectionMatrix();let pt=40,ot;for(let It=0;It<6;It++){$.position.set(Ti.x+pt*Math.sin(Z.yaw)*Math.cos(Z.pitch),Ti.y+pt*Math.sin(Z.pitch),Ti.z+pt*Math.cos(Z.yaw)*Math.cos(Z.pitch)),$.lookAt(Ti),$.updateMatrixWorld();let Wt=R.map(te=>{let _e=te.clone().project($);return[(_e.x*.5+.5)*P,(-_e.y*.5+.5)*B]});ot={x0:Math.min(...Wt.map(te=>te[0])),x1:Math.max(...Wt.map(te=>te[0])),y0:Math.min(...Wt.map(te=>te[1])),y1:Math.max(...Wt.map(te=>te[1]))},pt*=Math.max((ot.x1-ot.x0)/(k.r-k.x),(ot.y1-ot.y0)/(k.b-k.y))*1.02}ke={d:pt,ox:(ot.x0+ot.x1)/2-(k.x+k.r)/2,oy:(ot.y0+ot.y1)/2-(k.y+k.b)/2-(F()?24:0)}}function b(){P=t.clientWidth,B=t.clientHeight,!(!P||!B)&&(ut.setSize(P,B),gt.aspect=P/B,gt.updateProjectionMatrix(),fi.setSize(P,B),Vn.resolution.set(P,B),ke=null,st++,E.models.length&&jh())}let H=new ResizeObserver(b);H.observe(t),b();let J=ut.domElement,K=new Va,j=new vt,kt=R=>{let k=J.getBoundingClientRect();j.set((R.clientX-k.left)/k.width*2-1,-((R.clientY-k.top)/k.height)*2+1),K.setFromCamera(j,gt);let Z=[...X.values()].filter(pt=>I.has(pt.m.id)).map(pt=>pt.hit),$=K.intersectObjects(Z)[0];return $?[...X.values()].find(pt=>pt.hit===$.object).m.id:null},$t=R=>i.onSelect?.(R===L?null:R),Lt={zoom:!!i.controls?.zoom,pan:!!i.controls?.pan},Kt=Gc(),qt=Gc(),pe={x:0,y:0},ye=null,jt=()=>Object.assign(qt,Gc());(Lt.zoom||Lt.pan)&&(s.style.touchAction="none");let ge=new Map,Ie=null,He=()=>{let[R,k]=[...ge.values()];return{dist:Math.max(1,Math.hypot(R.x-k.x,R.y-k.y)),mid:{x:(R.x+k.x)/2,y:(R.y+k.y)/2}}},Ne=R=>{let k=J.getBoundingClientRect();return{x:R.clientX-k.left,y:R.clientY-k.top}},sn=R=>{if(R.pointerType==="touch"&&(Lt.zoom||Lt.pan)){if(ge.set(R.pointerId,Ne(R)),ge.size===2){de.drag=null,s.classList.remove("dragging"),Ie={...He(),view:{...qt}};return}if(ge.size>2)return}de.drag={x:R.clientX,y:R.clientY,yaw:de.yaw,pitch:de.pitch,still:!0,pan:Lt.pan&&!R.shiftKey,panX:qt.panX,panY:qt.panY},J.setPointerCapture(R.pointerId),s.classList.add("dragging")},Yt=R=>{if(ge.has(R.pointerId)&&ge.set(R.pointerId,Ne(R)),Ie&&ge.size>=2){let k=He(),Z=Lt.zoom?Bh(Ie.view,k.dist/Ie.dist,Ie.mid,pe,P,B):{...Ie.view};Lt.pan&&(Z.panX+=k.mid.x-Ie.mid.x,Z.panY+=k.mid.y-Ie.mid.y),Object.assign(qt,Wc(Z,P,B));return}if(de.drag){if(Math.hypot(R.clientX-de.drag.x,R.clientY-de.drag.y)>4&&(de.drag.still=!1),!de.drag.still){if(de.drag.pan){Object.assign(qt,Wc({zoom:qt.zoom,panX:de.drag.panX+(R.clientX-de.drag.x),panY:de.drag.panY+(R.clientY-de.drag.y)},P,B));return}de.yaw=de.drag.yaw-(R.clientX-de.drag.x)*.005,de.pitch=Math.min(.9,Math.max(-.05,de.drag.pitch+(R.clientY-de.drag.y)*.0035)),de.vy=de.vp=0}return}R.pointerType!=="touch"&&(v=kt(R),s.classList.toggle("over",!!v))},un=R=>{if(ge.delete(R.pointerId)&&Ie){ge.size<2&&(Ie=null);return}let k=de.drag;if(de.drag=null,s.classList.remove("dragging"),k?.still){let Z=kt(R);Z?$t(Z):L&&!F()&&i.onSelect?.(null)}},we=R=>{ge.delete(R.pointerId),ge.size<2&&(Ie=null),de.drag=null,s.classList.remove("dragging")},In=()=>{de.drag||(v=null)},Dn=R=>{R.preventDefault();let k=R.deltaY*(R.deltaMode===1?16:R.deltaMode===2?B:1);Object.assign(qt,Bh(qt,Math.exp(-k*.0015),Ne(R),pe,P,B))},Qn=R=>{R.preventDefault(),jt()};J.addEventListener("pointerdown",sn),J.addEventListener("pointermove",Yt),J.addEventListener("pointerup",un),(Lt.zoom||Lt.pan)&&J.addEventListener("pointercancel",we),J.addEventListener("pointerleave",In),Lt.zoom&&J.addEventListener("wheel",Dn,{passive:!1}),(Lt.zoom||Lt.pan)&&J.addEventListener("dblclick",Qn);let Ai=R=>{R.preventDefault(),i.onFail?.()};J.addEventListener("webglcontextlost",Ai);let Pe="",Re=new D,ti=new D(0,1,0),Ve=new D,pi=new D,qi={x:0,y:0,z:0},je=(R,k=qi)=>(Re.copy(R).project(gt),k.x=(Re.x*.5+.5)*P,k.y=(-Re.y*.5+.5)*B,k.z=Re.z,k),Ds=null,Zh=R=>{if(Ds||!t.contains(R.target)||o.contains(R.target)||p(R.target))return;let k=null,Z=12;for(let $ of r.querySelectorAll(".plate")){let pt=$.getBoundingClientRect(),ot=Math.max(pt.left-R.clientX,0,R.clientX-pt.right),It=Math.max(pt.top-R.clientY,0,R.clientY-pt.bottom),Wt=Math.hypot(ot,It);Wt<=Z&&(Z=Wt,k=$)}k&&(Ds={id:k.dataset.id,x:R.clientX,y:R.clientY})},Jh=R=>{let k=Ds;Ds=null,k&&Math.hypot(R.clientX-k.x,R.clientY-k.y)<14&&$t(k.id)},Kh=()=>Ds=null;addEventListener("pointerdown",Zh,!0),addEventListener("pointerup",Jh),addEventListener("pointercancel",Kh);let jc=new D,_o={x:0,y:0,z:0},Qc={x:0,y:0,z:0};function tp(){jc.setFromMatrixColumn(gt.matrixWorld,0);let R=[];for(let k of X.values()){if(!I.has(k.m.id)||!k.screen)continue;let Z=k.root.scale.y,$=k.root.position.x,pt=k.root.position.y,ot=k.root.position.z,It=je(Re.set($,pt+1.6*Z,ot),_o);if(It.z>=1)continue;let Wt=It.x,te=It.y,_e=je(Re.set($,pt-1.24*Z,ot),_o),lt=_e.x,ce=_e.y,oe=je(Re.set($,pt,ot),_o).x,ae=Math.abs(je(Re.set($,pt,ot).addScaledVector(jc,(k.span||.3)*Z),Qc).x-oe);R.push({id:k.m.id,x:Math.min(Wt,lt)-ae,y:te,w:Math.abs(Wt-lt)+ae*2,h:ce-te,nx:Wt,ny:te})}return R}function ep(R,k,Z){let $=[];for(let pt of Mt){let ot=pt.el,It=je(pt.v,_o);if(ot.classList.contains("next")){F()?(It.x=18,It.y=Z.y-26):It.y=Math.max(It.y,128),ot.style.transform=`translate(${It.x}px, ${It.y}px)`,ot.style.opacity=It.z<1?R*(1-_n):0;continue}let Wt=It.x,te=It.y,_e=It.z<1&&R*(1-_n)>.3;if(ot.style.opacity=It.z<1?R*(1-_n):0,pt.radius&&_e){let We=Math.abs(je(Re.copy(pt.v).addScaledVector(jc,pt.radius),Qc).x-Wt);$.push({x:Wt-We,y:te-We,w:We*2,h:We*2})}pt.epoch!==st&&(pt.w=pt.h=0),pt.epoch=st;let lt=pt.w||(pt.w=ot.offsetWidth),ce=pt.h||(pt.h=ot.offsetHeight);if(!lt){ot.style.transform=`translate(${Wt}px, ${te}px)`;continue}let oe=pt.radius?{x:Wt+20,y:te-ce/2}:{x:Wt+2,y:te-ce-4},ae=je(pt.far,Qc),De=Math.max(ae.x+4,Z.x+8),Ue=Math.abs(Wt-ae.x)>1?(De-ae.x)/(Wt-ae.x):0,Te={x:De,y:ae.y+Ue*(te-ae.y)-ce-3},et=We=>k.reduce((Ri,En)=>Ri+(We.x<En.x+En.w+4&&En.x<We.x+lt+4&&We.y<En.y+En.h*1.4&&En.y<We.y+ce+2?2:0)+(Math.abs(En.ny-(We.y+ce/2))<ce/2+18&&We.x<En.nx+212&&En.nx-212<We.x+lt?1:0),0)+(We.x<Z.x-10||We.x+lt>Z.r+10?2:0),qe=et(oe),vn=et(Te);!pt.atFar&&qe>0&&vn<qe&&ae.z<1?pt.atFar=!0:pt.atFar&&(qe===0||vn>qe)&&(pt.atFar=!1),ot.classList.toggle("far",pt.atFar);let dn=pt.atFar?Te:oe;ot.style.transform=pt.atFar?`translate(${Te.x}px, ${Te.y}px)`:`translate(${Wt}px, ${te}px)`,_e&&$.push({x:dn.x,y:dn.y,w:lt,h:ce})}return $}function np(R,k){let Z=E.models.filter(lt=>I.has(lt.id)&&M[lt.id]).sort((lt,ce)=>M[ce.id][1]-M[lt.id][1]),$=Z.map(lt=>lt.id+M[lt.id][0]+c).join("|");$!==Pe&&(r.querySelectorAll(".plate").forEach(lt=>lt.remove()),a.replaceChildren(),Z.forEach((lt,ce)=>{let oe=M[lt.id],ae=document.createElement("div");ae.className="plate",ae.dataset.id=lt.id,ae.style.setProperty("--c",lt.colour);let De=/^(Claude|DeepSeek|Kimi)\s/.exec(lt.name)?.[0]??"";ae.innerHTML=`<span class="rank">${ce+1}</span><span class="lg">${e(lt.dev)}</span><b><span class="nf">${Fr(De)}</span>${Fr(lt.name.slice(De.length))}${lt.racer?`<i class="rz" title="${l()?"\u7ADE\u901F\uFF1A\u5B8C\u5DE5\u5FEB\u4E14\u51FA\u5B57\u5FEB":"Racer: fast tasks and fast output"}">\u26A1</i>`:""}</b><span class="lcdc"><span class="v">${oe[1].toFixed(1)}</span><span class="ef">${Fr(oe[0])}${oe[0]===lt.rec?"<i>\u2605</i>":""}</span></span>`,ae.title=`${lt.name} \xB7 ${oe[0]} \xB7 ${oe[1].toFixed(1)}`,ae.onmouseenter=()=>v=lt.id,ae.onmouseleave=()=>v=null,ae.onpointerdown=Te=>{Ds={id:lt.id,x:Te.clientX,y:Te.clientY}},r.appendChild(ae);let Ue=document.createElementNS(Lf,"line");Ue.setAttribute("stroke",lt.colour),a.appendChild(Ue),ae.leader=Ue}),Pe=$);let pt=xs(),ot=[],It=tp(),Wt=ep(k,It,pt);globalThis.__mpLabelProbe&&(globalThis.__mpLabelProbe.fixed=Wt);let te=[...r.querySelectorAll(".plate")].map(lt=>({p:lt,r:X.get(lt.dataset.id)})).filter(lt=>lt.r?.screen),_e=F()?6:9;te.forEach(({p:lt,r:ce},oe)=>{let ae=lt.dataset.id,De=R===ae;lt.classList.toggle("hot",De);let Ue=lt.classList.contains("dot"),Te=lt.classList.contains("tight"),et=lt.offsetHeight,qe=ce.screen.x,vn=ce.screen.y;!Ue&&!Te&&(lt._full=lt.offsetWidth,lt._lead=lt.querySelector(".nf")?.offsetWidth??0);let dn=lt._full??lt.offsetWidth,We=(ze,rn,an)=>ot.find(Fe=>ze<Fe.x+Fe.w+4&&Fe.x<ze+an+4&&rn<Fe.y+Fe.h+3&&Fe.y<rn+et+3)??Wt.find(Fe=>ze<Fe.x+Fe.w+2&&Fe.x<ze+an+2&&rn<Fe.y+Fe.h+2&&Fe.y<rn+et+2),Ri=(ze,rn)=>{let an=Math.max(vn-et/2,...ot.filter(Fe=>ze<Fe.x+Fe.w+30&&Fe.x<ze+rn+30).map(Fe=>Fe.y+2));for(let Fe=0;Fe<60;Fe++){let wn=We(ze,an,rn);if(!wn)return an;an=wn.y+wn.h+(wn.chip?3:2)+.01}return an},En=(ze,rn,an)=>{let Fe=ze+an/2<qe?ze+an:ze,wn=Math.max(rn+4,Math.min(rn+et-4,vn)),Wr=Math.hypot(Fe-qe,wn-vn),yo=Wr*.6+Math.max(0,Wr-120)*2.5;for(let Tn of It){let Bs=Math.min(ze+an,Tn.x+Tn.w)-Math.max(ze,Tn.x),au=Math.min(rn+et,Tn.y+Tn.h)-Math.max(rn,Tn.y);if(Bs<=0||au<=0)continue;let ou=Bs*au;yo+=Tn.id===ae?400:Math.min(1,ou/260)*60+ou/et*2.2+(Tn.nx>ze&&Tn.nx<ze+an&&Tn.ny>rn-4&&Tn.ny<rn+et?90:0)}return yo},Yi=(ze,rn,an,Fe)=>{for(let wn of[1,-1])an.forEach((Wr,yo)=>{let Tn=wn>0?Math.min(pt.r+10-ze,qe+Wr):Math.max(pt.x-10,qe-Wr-ze),Bs=Ri(Tn,ze);Fe.push({x:Tn,y:Bs,w:ze,tight:rn,slot:wn*(yo+1),cost:En(Tn,Bs,ze)+(wn<0?4:0)+(rn?10:0)+(We(Tn,Bs,ze)?1e3:0)})});return Fe},Ci=(ze,rn)=>{let an=ze[0];for(let wn of ze)wn.cost<an.cost&&(an=wn);let Fe=ze.find(wn=>wn.slot===lt._slot&&wn.tight===rn);return Fe&&Fe.cost<=an.cost+30?Fe:an},kr=[12,34,60,92,130],Hr=Yi(dn,!1,kr,[]);lt._lead>0&&!De&&Yi(dn-lt._lead,!0,kr,Hr);let Be=Ci(Hr,Te&&!Ue),Ii=!De&&oe>=_e&&Be.cost>(Ue?125:180);Ii&&(Be=Ci(Yi(lt._dot??et,!1,[8,22],[]),!1)),Ii!==Ue&&lt.classList.toggle("dot",Ii),Ii&&Ue&&(lt._dot=lt.offsetWidth);let Pn=!Ii&&Be.tight;Pn!==Te&&lt.classList.toggle("tight",Pn),lt._slot=Be.slot;let Un=Be.w;ot.push({x:Be.x,y:Be.y,w:Un,h:et,chip:!0}),globalThis.__mpLabelProbe&&(lt._pick=Be),lt._x=lt._x==null||Math.abs(lt._x-Be.x)>80?Be.x:lt._x+(Be.x-lt._x)*.25,lt._y=lt._y==null||Math.abs(lt._y-Be.y)>80?Be.y:lt._y+(Be.y-lt._y)*.25,lt.style.transform=`translate(${lt._x}px, ${lt._y}px)`;let ei=R&&R!==lt.dataset.id&&It.find(ze=>ze.id===R),Vr=ei&&lt._x<ei.x+ei.w+6&&ei.x-6<lt._x+Un&&lt._y<ei.y+ei.h&&ei.y<lt._y+et,Fs=Vr?.04:R&&!De?L?.42:.22:Math.min(1,Math.max(0,(performance.now()-ce.born-1200)/600));lt.style.opacity=Fs,lt.style.pointerEvents=Vr&&!L?"none":"";let Zi=lt._x+Un/2<qe,Os=Zi?lt._x+Un:lt._x,fn=lt._y+et/2,Ji=Math.hypot(Os-qe,fn-vn)>16,Gr=lt.leader;Gr.setAttribute("x1",qe+(Zi?-4:4)),Gr.setAttribute("y1",vn),Gr.setAttribute("x2",Os),Gr.setAttribute("y2",fn),Gr.style.opacity=Ji?Fs*.6:0});for(let lt of le){let ce=je(lt.v);lt.el.style.transform=`translate(${ce.x}px, ${ce.y}px)`,lt.el.style.opacity=ce.z<1?k*(1-_n):0}for(let lt of gs){let ce=je(lt.v);lt.el.style.transform=`translate(${ce.x}px, ${ce.y}px)`}}let vo=[];function jh(){if(W)return;let R=ot=>Uh(ot,f),k=E.models.filter(ot=>I.has(ot.id)&&M[ot.id]).sort((ot,It)=>M[It.id][1]-M[ot.id][1]),Z=k.length?M[k[0].id][1]:0;o.style.left=(i.gaugeLeft?i.gaugeLeft():_().left-92)+"px";let $=`<div class="vbar"></div><div class="lead">${l()?`\u9886\u5148 ${Z.toFixed(1)} \xB7 \u8DDD\u661F\u8FB0\u5927\u6D77 ${(d-Z).toFixed(1)}`:`Leader ${Z.toFixed(1)} \xB7 ${(d-Z).toFixed(1)} to the stars`}</div><div class="vwin" style="bottom:${R(Dt)}%;height:${R(tt)-R(Dt)}%" title="${l()?"3D \u89C6\u91CE\u91CC\u7684\u5206\u6570\u6BB5":"Score band shown in 3D"}"></div>`;$+=u.map(ot=>`<div class="vt ${ot.final?"agi":""}" style="bottom:${R(ot.at)}%"><b>${ot.final?l()?`\u2605 ${ot.zh}`:`\u2605 ${ot.en}`:l()?ot.zh:ot.en}</b>${ot.at}</div>`).join("");let pt=[];$+=k.map(ot=>{let It=M[ot.id][1],Wt=pt.filter(te=>Math.abs(te-It)<.9).length;return pt.push(It),`<span class="vdot" data-id="${Fr(ot.id)}" style="--c:${ot.colour};bottom:${R(It)}%;left:${11-Wt*9}px" title="${Fr(ot.name)} \xB7 ${It.toFixed(1)}"></span>`}).join(""),o.innerHTML=$,vo=[...o.querySelectorAll(".vdot")],vo.forEach(ot=>{ot.onmouseenter=()=>v=ot.dataset.id,ot.onmouseleave=()=>v=null,ot.onclick=()=>$t(ot.dataset.id)})}let Br=[];function ip(R){for(let k of E.models){if(!I.has(k.id)||!M[k.id])continue;let Z=R[k.id],$=M[k.id][1],pt=X.get(k.id);if(Z==null||$<=Z||!pt)continue;let ot=u.filter(It=>It.at>Z&&It.at<=$).pop();ot&&(pt.cross=ot)}}let Qh=new Wi(1,.035,8,96);function sp(R,k){let Z=new ve(Qh,new nn({color:k.final?"#ffd37a":"#9fd8ff",transparent:!0,blending:on,depthWrite:!1}));Z.position.copy(R.root.position),Z.rotation.x=Math.PI/2,xt.add(Z);let $=document.createElement("div");$.className="burst",$.textContent=k.final?l()?"\u2605 \u9A76\u51FA\u592A\u9633\u7CFB \xB7 \u5954\u5411\u661F\u8FB0\u5927\u6D77":"\u2605 Leaving the solar system \xB7 out to the stars":l()?`\u2726 \u8D8A\u8FC7${k.zh}`:`\u2726 Past ${k.en}`,r.appendChild($),Br.push({ring:Z,el:$,r:R,t0:performance.now()})}function rp(R){for(let k=Br.length-1;k>=0;k--){let Z=Br[k],$=(R-Z.t0)/1400;if($>=1){xt.remove(Z.ring),Z.ring.material.dispose(),Z.el.remove(),Br.splice(k,1);continue}let pt=1-Math.pow(1-$,3);Z.ring.scale.setScalar(.4+pt*3.2),Z.ring.material.opacity=(1-$)*.9;let ot=je(Re.copy(Z.r.root.position).addScaledVector(ti,1.9));Z.el.style.transform=`translate(${ot.x}px, ${ot.y-pt*26}px)`,Z.el.style.opacity=$<.15?$/.15:1-Math.max(0,($-.6)/.4)}}let Us=0,t0=performance.now(),e0=t0,n0=!1,i0=0,tu=!0,eu=!1,zr=0,s0=0,nu=0,iu=!i.onSlow,su=new IntersectionObserver(([R])=>tu=R?.isIntersecting??!0);su.observe(t);function ru(R){if(i0=requestAnimationFrame(ru),document.hidden||!tu||!P||!E.models.length){zr=0;return}!iu&&n0&&R-t0>1500&&(zr&&R-zr<1e3&&(s0+=R-zr,nu++),zr=R,s0>=3e3&&(iu=!0,nu*1e3/s0<20&&i.onSlow()));let k=R/1e3,Z=S?1:Math.min(1,(R-e0)/1800),$=L??v??C;if(!de.drag||de.drag.still){let et=F()?ie:Gt,qe=S||$?0:Math.sin(k/3.6)*.03;de.vy=de.vy*.85+(et.yaw+qe-de.yaw)*.03,de.yaw+=de.vy,de.vp=de.vp*.85+(et.pitch-de.pitch)*.03,de.pitch+=de.vp}if(ke||xo(),!xn)xn={...ke};else if(S)Object.assign(xn,ke);else for(let et of["d","ox","oy"])xn[et]+=(ke[et]-xn[et])*.06;let pt=L&&I.has(L)&&X.get(L),ot=xs();_n+=((pt?1:0)-_n)*(S?1:.06);let It=F()&&pt?Kc(pt):null;$i.lerp(It?It.look:pt?Ve.copy(pt.root.position).addScaledVector(ti,.3):Ti,S?1:.08);let Wt=S?1:Math.min(1,(R-e0)/5200),te=1-Math.pow(1-Wt,3),_e=de.pitch-.07*(1-te);Us*=.93;let lt=It?It.fy:(ot.y+ot.b)/2;L!==ye&&(ye=L,jt()),Pf(Kt,qt,S);let ce=It?It.d:Math.min(26,xn.d*.55),oe=(xn.d+(ce-xn.d)*_n)*(1-.2*(1-te))/Kt.zoom,ae=xn.ox+(P/2-(ot.x+ot.r)/2-xn.ox)*_n-Kt.panX,De=xn.oy+(B/2-lt-xn.oy)*_n-Kt.panY;pe.x=P/2-ae,pe.y=B/2-De,gt.position.set($i.x+oe*Math.sin(de.yaw)*Math.cos(_e),$i.y+oe*Math.sin(_e),$i.z+oe*Math.cos(de.yaw)*Math.cos(_e)),gt.lookAt($i),Us>.01&&gt.position.add(pi.set(Math.sin(k*61),Math.sin(k*47+1),Math.sin(k*53+2)).multiplyScalar(.007*oe*Us)),gt.setViewOffset(P,B,ae,De,P,B),Vn.strength=.8-.38*_n+.55*Us,ut.toneMappingExposure=1.05-.15*_n,x.update(S?0:k),at.uniforms.t.value=k,Rt.children.forEach(et=>{et.userData.spin&&(et.rotation.y=k*.15)}),$!==Kn&&po($);let Ue=(F()?.68:.88)*y,Te=w?0:k;for(let et of X.values()){let qe=I.has(et.m.id)&&!!M[et.m.id];if(qe||(et.soot.visible=!1),et.root.visible=et.trail.visible=et.drop.visible=et.pad.visible=et.padGlow.visible=et.smoke.visible=qe,!qe)continue;et.pos.lerp(et.tgt,S?1:.08),et.flare+=(1-et.flare)*.035;let vn=R-et.born,dn=S?1:Math.max(0,Math.min(1,vn/650)),We=S?1:Math.max(0,Math.min(1,(vn-550)/2400)),Ri=We<.5?4*We**3:1-Math.pow(-2*We+2,3)/2,En=dn*(1-We),Yi=dn*(1-Ri),Ci=Ot(),kr=Ci+1.5+(et.pos.y-1.5)*Ri,Hr=M[et.m.id],Be=Math.max(.15,Math.min(1,(Math.log10(Hr[2])+2.2)/2.8))*et.flare+En*.9,Ii=$===et.m.id||v===et.m.id,Pn=$&&!Ii?.2:1;et.root.position.set(et.pos.x,kr+(S?0:Math.sin(k*1.1+et.phase)*.06),et.pos.z),xe(et);let Un=et.m.id===wt;et.heavy.visible=Un;let ei=!Un&&et.m.racer;et.racer.visible=ei,et.stdParts.forEach(fn=>fn.visible=!Un);let Vr=Un?et.steelMap:ei?et.boltMap:et.hullMap;et.steel.metalness=Un?.92:.35,et.steel.roughness=Un?.2:.34,et.steel.map!==Vr&&(et.steel.map=Vr,et.steel.needsUpdate=!0),ei&&et.streaks.forEach(fn=>{let Ji=S?fn.userData.o:(k*1.6+fn.userData.o)%1;fn.position.y=1.2-Ji*2.8,fn.material.opacity=.65*Math.sin(Ji*Math.PI)*Pn});let Fs=Un?et.heavyNozzle:et.NOZZLE_Y;et.outer.position.y=et.inner.position.y=Fs+.02,et.light.position.y=Fs-.45,et.halo&&(et.halo.rotation.y=S?0:k*.7),et.root.scale.setScalar(Ue*(Ii?1.12:1)*(Un?1.18:1));{let fn=L===et.m.id||et.m.id===wt?de.yaw-.4*Math.PI:k*.12+et.phase,Ji=et.g.rotation.y;et.g.rotation.y=Ji+Math.atan2(Math.sin(fn-Ji),Math.cos(fn-Ji))*(S?1:.08)}et.g.rotation.z=S?0:Math.sin(k*.7+et.phase)*.02,et.mats.forEach(fn=>fn.opacity=Pn),et.outer.material.uniforms.t.value=et.inner.material.uniforms.t.value=et.trail.material.uniforms.t.value=et.soot.material.uniforms.t.value=Te;for(let fn of et.bOuter)fn.material.uniforms.t.value=Te,fn.material.uniforms.k.value=Pn*(.15+.85*dn),fn.scale.set(.8+Be*.6,.6+Be*1.2,.8+Be*.6);et.outer.material.uniforms.k.value=et.inner.material.uniforms.k.value=Pn*(.15+.85*dn),et.trail.material.uniforms.k.value=Pn*.8*dn,et.outer.scale.set((.8+Be*.6)*(et.racer.visible?.75:1),(.6+Be*1.2)*(et.racer.visible?1.45:1),(.8+Be*.6)*(et.racer.visible?.75:1)),et.inner.scale.set(1,.7+Be*.6,1),et.light.intensity=(.6+Be*1.4)*Pn,et.ring.visible=Ii&&L!==et.m.id&&Hr[0]===et.m.rec,et.ring.quaternion.copy(gt.quaternion),et.ring.material.opacity=Pn;let Zi=et.root.position.y+Fs*et.root.scale.y,Os=Math.max(.05,Zi-Ci);et.trail.position.set(et.pos.x,Zi-.3,et.pos.z),et.trail.scale.set(.5+Be*.8,Math.max(.05,Math.min(Os-.3,2.6+Be*1.2)),.5+Be*.8),et.soot.visible=et.fuelKind==="lo",et.soot.position.set(et.pos.x,Zi-.5,et.pos.z),et.soot.scale.set(.55+Be*.5,Math.max(.05,Math.min(Os-.5,1.6+Be*.9)),.55+Be*.5),et.soot.material.uniforms.k.value=Pn*dn,et.drop.position.set(et.pos.x,Zi,et.pos.z),et.drop.scale.y=Os,et.drop.material.opacity=.22*Pn,et.pad.position.set(et.pos.x,Ci+.02,et.pos.z),et.pad.material.opacity=.7*Pn,et.padGlow.position.set(et.pos.x,Ci+.1,et.pos.z),et.padGlow.scale.setScalar(1.4+3.2*Yi),et.padGlow.material.opacity=Pn*Math.max(.3*Ri,.7*Yi),et.smoke.position.set(et.pos.x,Ci+.5+We*.8,et.pos.z),et.smoke.scale.setScalar(1.2+2.5*dn+4.5*We),et.smoke.material.opacity=.3*Yi*Pn,et.smoke.visible=Yi>0,et.cross&&We>=1&&kr-Ci>=it(et.cross.at)-.05&&(et.cross.at>=Dt-.01&&sp(et,et.cross),et.cross=null),et.screen=je(Re.set(et.pos.x,et.root.position.y+1.2*et.root.scale.y,et.pos.z),et.screen),je(Re.set(et.pos.x,Zi-.8,et.pos.z),et.base)}jn.children.forEach(et=>{et.userData.bill&&et.quaternion.copy(gt.quaternion)}),rp(R),fi.render(),np($,Z),vo.forEach(et=>et.classList.toggle("hot",et.dataset.id===$)),i.onFrame?.()}if(i0=requestAnimationFrame(ru),globalThis.__mpLabelProbe){let R=new D,k=new Wn,Z=new D,$=ot=>({x:+ot.x.toFixed(1),y:+ot.y.toFixed(1),w:+ot.w.toFixed(1),h:+ot.h.toFixed(1)}),pt=(ot,It)=>{let Wt=ot.getBoundingClientRect();return $({x:Wt.left-It.left,y:Wt.top-It.top,w:Wt.width,h:Wt.height})};Object.assign(globalThis.__mpLabelProbe,{view:()=>({yaw:de.yaw,pitch:de.pitch,W:P,H:B,narrow:F(),region:xs(),zoom:_n}),boxes(){let ot=t.getBoundingClientRect(),It=[...r.querySelectorAll(".plate")].map(lt=>({id:lt.dataset.id,opacity:+lt.style.opacity||0,collapsed:lt.classList.contains("dot"),tight:lt.classList.contains("tight"),target:lt._pick&&{x:Math.round(lt._pick.x),y:Math.round(lt._pick.y),w:Math.round(lt._pick.w),cost:Math.round(lt._pick.cost),slot:lt._pick.slot},...pt(lt,ot)})),Wt=[...r.querySelectorAll(".ltag, .tick3")].map(lt=>({kind:lt.classList.contains("tick3")?"tick":lt.classList.contains("next")?"next":"orbit",text:lt.textContent,opacity:+getComputedStyle(lt).opacity||0,...pt(lt,ot)})),te=[];Rt.children.forEach(lt=>{if(!lt.userData.spin)return;lt.geometry.computeBoundingSphere(),k.copy(lt.geometry.boundingSphere).applyMatrix4(lt.matrixWorld);let ce=je(k.center),oe=ce.x,ae=ce.y,De=ce.z;Z.setFromMatrixColumn(gt.matrixWorld,0);let Ue=je(R.copy(k.center).addScaledVector(Z,k.radius)),Te=Math.hypot(Ue.x-oe,Ue.y-ae);De<1&&te.push($({x:oe-Te,y:ae-Te,w:Te*2,h:Te*2}))});let _e=[];for(let lt of X.values()){if(!I.has(lt.m.id))continue;lt.root.updateWorldMatrix(!0,!1);let ce=(lt.span||.3)*lt.root.scale.x,oe=je(R.set(0,1.6,0).applyMatrix4(lt.root.matrixWorld)),ae=oe.x,De=oe.y,Ue=oe.z,Te=je(R.set(0,-1.24,0).applyMatrix4(lt.root.matrixWorld)),et=Te.x,qe=Te.y;Z.setFromMatrixColumn(gt.matrixWorld,0);let vn=R.set(0,.18,0).applyMatrix4(lt.root.matrixWorld).clone(),dn=je(vn),We=dn.x,Ri=je(vn.addScaledVector(Z,ce)),En=Math.abs(Ri.x-We);Ue<1&&_e.push({id:lt.m.id,nose:{x:+ae.toFixed(1),y:+De.toFixed(1)},depth:+Ue.toFixed(4),...$({x:Math.min(ae,et)-En,y:De,w:Math.abs(ae-et)+En*2,h:qe-De})})}return{chips:It,tags:Wt,planets:te,hulls:_e}}})}return{update(R){let k=Object.fromEntries(Object.entries(M).map(([ot,It])=>[ot,It[1]])),Z=I,$=R.language!=null&&R.language!==c;$&&(c=R.language,h()),R.axis!==void 0&&(g=R.axis),E={models:R.models};for(let ot of Object.keys(M))delete M[ot];for(let ot of R.models)ot.sel&&(M[ot.id]=ot.sel);I=new Set(R.shown.filter(ot=>M[ot])),R.focus!==void 0?L=R.focus&&I.has(R.focus)?R.focus:null:L&&!I.has(L)&&(L=null),C=R.hint&&I.has(R.hint)?R.hint:null;let pt=performance.now();if(n0){let ot=[...I].filter(It=>!Z.has(It));Or(),ot.forEach((It,Wt)=>{let te=X.get(It);te&&(te.born=pt+Wt*120)}),ip(k)}else{t0=pt;let ot=Nf;e0=ot?pt-6e3:pt,Or(),E.models.filter(It=>I.has(It.id)).sort((It,Wt)=>M[Wt.id][1]-M[It.id][1]).forEach((It,Wt)=>zt(It).born=ot?pt-4e3:pt+700+Wt*300),n0=Nf=!0}$&&(Pe="")},thrust(){w||(Us=1)},setOptions(R){R.reducedMotion!==void 0&&(S=R.reducedMotion??matchMedia("(prefers-reduced-motion: reduce)").matches,w=R.reducedMotion===!0,w&&(Us=0)),R.rocketScale!==void 0&&(y=R.rocketScale??1)},setSelection(R){L=R&&I.has(R)?R:null},resetView(){jt()},dispose(){if(!eu){eu=!0,cancelAnimationFrame(i0),H.disconnect(),su.disconnect(),removeEventListener("pointerdown",Zh,!0),removeEventListener("pointerup",Jh),removeEventListener("pointercancel",Kh);for(let R of X.values()){R.mats.forEach(k=>k.dispose()),R.halo?.traverse(k=>{k.geometry?.dispose(),k.material?.dispose()}),R.root.traverse(k=>{k.isInstancedMesh&&k.dispose(),k.geometry?.dispose();for(let Z of Array.isArray(k.material)?k.material:k.material?[k.material]:[]){for(let $ of Object.values(Z))$?.isTexture&&$!==re&&$.dispose();Z.dispose()}});for(let k of[R.trail,R.soot,R.drop,R.pad,R.padGlow,R.smoke])k.material.dispose(),k.geometry!==q&&k.geometry!==ht&&k.geometry?.dispose()}q.dispose(),ht.dispose(),Qh.dispose(),Tt(Rt),Tt(Jt),Tt(jn),x.dispose(),A.dispose(),yt.forEach(R=>R.dispose()),xt.traverse(R=>{R.geometry?.dispose(),R.material?.dispose?.()}),fi.passes.forEach(R=>R.dispose()),Vn.materialHighPassFilter.dispose(),fi.dispose(),J.removeEventListener("pointerdown",sn),J.removeEventListener("pointermove",Yt),J.removeEventListener("pointerup",un),J.removeEventListener("pointerleave",In),J.removeEventListener("pointercancel",we),J.removeEventListener("wheel",Dn),J.removeEventListener("dblclick",Qn),J.removeEventListener("webglcontextlost",Ai),ge.clear(),ut.forceContextLoss(),ut.dispose(),xt.clear(),X.clear(),yt.length=0,Mt.length=le.length=gs.length=Br.length=0,vo.length=0,s.remove(),r.remove(),o.remove(),s.replaceChildren(),r.replaceChildren(),o.replaceChildren()}}}}var R3={n:4.6,sagTop:.035,sagBot:.015},C3=1440,I3=.09,P3=.5,Df=560,Is=.97,Uf=.95;function Ff(i,t=R3){let e=Math.cos(i),n=Math.sin(i),s=2/t.n,r=Math.sign(e)*Math.abs(e)**s,a=Math.sign(n)*Math.abs(n)**s;return a<0?a+=2*t.sagTop*r*r*-a:a-=2*t.sagBot*r*r*a,{x:r,y:a}}function kh(i,t,{steps:e=C3,sx:n=1,sy:s=1}={}){let r=[];for(let a=0;a<e;a++){let{x:o,y:c}=Ff(a/e*Math.PI*2);r.push({x:i/2*(1+o*n),y:t/2*(1+c*s)})}return r}function Of(i,t,e=I3){let n=Math.min(i,t),s=e*n,r=Math.max(40,(n-470)/2);return{px:Math.round(Math.min(s,r)),capped:s>r+.5}}var L3=i=>{let t=Math.max(0,Math.min(1,i));return t*t*t*(t*(t*6-15)+10)};function Hh(i,t){let e=P3,n=Math.max(1,Math.round(i*e)),s=Math.max(1,Math.round(t*e)),r=n*s,a=kh(n,s),o=new Float32Array(r),c=n+s,l=Math.SQRT2,h=[];for(let p=0;p<s;p++){let S=p+.5;h.length=0;for(let w=0,y=a.length-1;w<a.length;y=w++){let E=a[w],M=a[y];E.y>S!=M.y>S&&h.push(E.x+(S-E.y)/(M.y-E.y)*(M.x-E.x))}h.sort((w,y)=>w-y);for(let w=0;w+1<h.length;w+=2){let y=Math.max(0,Math.ceil(h[w]-.5)),E=Math.min(n-1,Math.floor(h[w+1]-.5));for(let M=y;M<=E;M++)o[p*n+M]=c}}let f=0;for(let p=0;p<r;p++)o[p]&&f++;for(let p=0;p<s;p++)for(let S=0;S<n;S++){let w=p*n+S;o[w]&&(o[w]=Math.min(o[w],S?o[w-1]+1:1,p?o[w-n]+1:1,S&&p?o[w-n-1]+l:l,S<n-1&&p?o[w-n+1]+l:l))}for(let p=s-1;p>=0;p--)for(let S=n-1;S>=0;S--){let w=p*n+S;o[w]&&(o[w]=Math.min(o[w],S<n-1?o[w+1]+1:1,p<s-1?o[w+n]+1:1,S<n-1&&p<s-1?o[w+n+1]+l:l,S&&p<s-1?o[w+n-1]+l:l))}let{px:u,capped:d}=Of(i,t),g=Math.max(1,u*e),_=new Uint8Array(r),m=0;for(let p=0;p<r;p++){let S=Math.round(255*L3(o[p]/g));_[p]=S,S>=Math.round(255*Is)&&m++}return{W:i,H:t,w:n,h:s,alpha:_,featherPx:u,capped:d,area:f/r,clear:m/r,at(p,S){let w=Math.round(p*e),y=Math.round(S*e);return w<0||y<0||w>=n||y>=s?0:_[y*n+w]/255}}}function Bf(i){let{W:t,H:e}=i;return{topOp:(c,l)=>{for(let h=0;h<e;h+=2)if(i.at(c,h)>=l)return h;return e},botOp:(c,l)=>{for(let h=e-1;h>=0;h-=2)if(i.at(c,h)>=l)return h;return 0},leftOp:(c,l)=>{for(let h=0;h<t;h+=2)if(i.at(h,c)>=l)return h;return t},rightOp:(c,l)=>{for(let h=t-1;h>=0;h-=2)if(i.at(h,c)>=l)return h;return 0},span:(c,l,h,f)=>{let u=h(c);for(let d=c;d<=l;d+=6)u=f(u,h(d));return f(u,h(l))}}}function N3(i){let{W:t,H:e}=i,{topOp:n,botOp:s,leftOp:r,span:a}=Bf(i),o=Math.max(248,Math.min(300,Math.round(.2*t))),c=.8,l=r(e*.55,c)+4,h={x:l,y:0,h:-1/0};for(let f=l;f<l+86;f+=4){let u=a(f,f+o,g=>n(g,c),Math.max)+4,d=a(f,f+o,g=>s(g,c),Math.min)-4;d-u>h.h+6&&(h={x:f,y:u,h:d-u})}return D3(h,o,e)}function D3(i,t,e){let n=i.h>=Df,s=n?{x:i.x,y:i.y,w:t,h:i.h}:{x:10,y:10,w:t,h:e-20};return{...s,inside:n,dense:s.h<660,legend:s.h<600?"hidden":s.h>=720?"open":"closed"}}function Vh(i){let{W:t,H:e}=i,{topOp:n,botOp:s,rightOp:r,span:a}=Bf(i),o=N3(i),c=o.x+o.w,l=t>=1e3,h=c+(l?112:28),f=t-a(Math.round(e*.25),Math.round(e*.85),m=>r(m,Is),Math.min)+34,u=t-f,d=a(h,u,m=>n(m,Is),Math.max)+8,g=e-a(h,u,m=>s(m,Is),Math.min)+50,_=Math.round((h+u)/2);return{W:t,H:e,menu:o,insets:{left:h,right:f,top:d,bottom:g},gauge:{show:l,left:c+20,top:a(c+20,c+120,m=>n(m,Is),Math.max)+40,bottom:e-a(c+20,c+120,m=>s(m,Is),Math.min)+8},focus:{x:_,bottom:e-a(_-230,_+230,m=>s(m,Is),Math.min)+6}}}var U3="lineup-v1";var zf=i=>typeof i=="number"&&Number.isFinite(i);function kf(i){if(new Set(i.map(d=>d.id)).size!==i.length)throw Error("duplicate_lineup_model");let t=i.filter(d=>zf(d.ability)&&zf(d.cost)&&d.cost>0),e=new Set(t.map(d=>d.id)),n=i.filter(d=>!e.has(d.id)).map(d=>({id:d.id,status:"incomplete",tags:[],dominatedBy:null}));if(t.length<2)return null;let s=(d,g)=>d.cost-g.cost||g.ability-d.ability||(d.id<g.id?-1:d.id>g.id?1:0),r=[...t].sort(s)[0],a=r.cost,o=t.map(d=>{let g=t.filter(_=>_!==d&&(_.cost<d.cost&&_.ability>=d.ability-1||_.cost===d.cost&&_.ability>d.ability)).sort(s)[0];return{id:d.id,ability:d.ability,cost:d.cost,costRelative:d.cost/a,tags:[],dominatedBy:g?{id:g.id,kind:Math.abs(g.ability-d.ability)<=1?"equivalent":"weaker"}:null}}),c=o.filter(d=>!d.dominatedBy).sort(s),l=Math.max(...o.map(d=>d.ability)),h=o.filter(d=>d.ability>=l-1).sort(s)[0],f=o.find(d=>d.id===r.id),u=null;for(let d of c){if(d===f||d.cost===f.cost)continue;let g=(d.ability-f.ability)/Math.log2(d.cost/f.cost);(!u||g>u.gain)&&(u={row:d,gain:g})}f.tags.push("cheapest"),h.tags.push("strongest"),u&&u.row.tags.push("best_value");for(let d of o)d.dominatedBy&&d.tags.push(d.dominatedBy.kind==="equivalent"?"equivalent_costlier":"dominated");return{method:U3,tie:1,baseline:f.id,frontier:c.map(d=>d.id),steps:c.slice(1).map((d,g)=>({from:c[g].id,to:d.id,abilityDelta:d.ability-c[g].ability,costRatio:d.cost/c[g].cost})),members:[...o,...n]}}function Gh(i){return i.search?"clear-search":i.focus?"leave-focus":"close"}var Hf=["fleet","effort","methodology"],F3=/^[a-z0-9][a-z0-9._-]{0,119}$/i;function Wh(i,t={}){if(!Hf.includes(i)||t==null||typeof t!="object"||Array.isArray(t))return null;let e=Object.keys(t);if(!e.length)return{target:i,params:{}};let n=t.m;return i==="effort"&&e.length===1&&e[0]==="m"&&typeof n=="string"&&F3.test(n)?{target:"effort",params:{m:n}}:null}var Xh={strongest:["Strongest","\u6700\u5F3A"],best_value:["Best value","\u6700\u503C"],cheapest:["Cheapest","\u6700\u7701"],dominated:["Outclassed","\u6709\u66F4\u4F18"],equivalent_costlier:["Pricier twin","\u6709\u66F4\u7701"]},Vf={None:"\u5173",Off:"\u5173",Min:"\u6781\u4F4E",Low:"\u4F4E",Med:"\u4E2D",Medium:"\u4E2D",High:"\u9AD8",XHigh:"\u8D85\u9AD8",Max:"\u6700\u9AD8",Ultra:"Ultra",Default:"\u9ED8\u8BA4"},Ps=i=>i.e.find(t=>t[0]===i.rec)??i.e.at(-1);function Xc(i){let t=kf(i.map(n=>{let s=Ps(n);return{id:n.id,ability:s?.[1]??null,cost:s?.[2]??null}})),e=new Map;for(let n of i){let s=t?.members.find(a=>a.id===n.id),r=["strongest","best_value","cheapest","dominated","equivalent_costlier"].find(a=>s?.tags.includes(a))??null;e.set(n.id,{tag:r,costRelative:s?.costRelative??null,dominatedBy:s?.dominatedBy?.id??null})}return e}var Gf=i=>i==="dominated"||i==="equivalent_costlier",Wf=i=>i==null?"\u2013":"\xD7"+(i>=10?i.toFixed(0):i>=1.995?i.toFixed(1):i.toFixed(2));function Xf(i,t=34,e=13){let n=i.filter(d=>d!=null&&Number.isFinite(d));if(n.length<3)return null;let s=Math.min(...n),r=Math.max(...n),a=Math.max(r-s,3),o="",c=!1,l=NaN,h={x:0,y:0},f=NaN;for(let d=0;d<i.length;d++){let g=i[d];if(g==null||!Number.isFinite(g)){c=!1;continue}let _=d/Math.max(1,i.length-1)*(t-4)+2,m=2+(g-s)/a*(e-4);o+=`${c?"L":"M"}${_.toFixed(1)} ${m.toFixed(1)}`,c=!0,h={x:_,y:m},f=g,Number.isNaN(l)&&(l=g)}let u=f<l?"up":f>l?"down":"flat";return{d:o,end:h,first:l,last:f,trend:u}}var $h=10;function qh(i,t,e=$h){return i.includes(t)?i.length>1?{ids:i.filter(n=>n!==t)}:{refused:"last"}:i.length>=e?{refused:"full"}:{ids:[...i,t]}}function $f(i,t,e){let n=[],s=new Map,r=8,a=(o,c,l,h)=>!n.some(f=>o<f.x+f.width+4&&o+l+4>f.x&&c<f.y+f.height+4&&c+h+4>f.y);for(let o of[...i].sort((c,l)=>(c.order??c.y)-(l.order??l.y)||c.id.localeCompare(l.id))){let c=o.order!==void 0&&n.length?n.at(-1).y:r,l=(u,d)=>({x:Math.max(r,Math.min(t-o.width-r,u)),y:Math.max(c,Math.min(e-o.height-r,d))}),h=l(o.x+12,o.y-20),f=!1;for(let u=0;u<18&&!f;u++){let d=u===0?-20:u%2?-20-Math.ceil(u/2)*(o.height+5):-20+Math.ceil(u/2)*(o.height+5);for(let g of[12,-o.width-12]){let _=l(o.x+g,o.y+d);if(a(_.x,_.y,o.width,o.height)){h=_,f=!0;break}}}if(!f){for(let u=c;u<e-o.height-r&&!f;u+=o.height+5)for(let d=r;d<t-o.width-r;d+=o.width+6)if(a(d,u,o.width,o.height)){h={x:d,y:u},f=!0;break}}n.push({...h,width:o.width,height:o.height}),s.set(o.id,h)}return s}var $c=(i,t,e=0)=>i.left<t.right+e&&t.left<i.right+e&&i.top<t.bottom+e&&t.top<i.bottom+e;function O3(i,t){if(i==="axis")return 0;if(i==="lane")return 4;let e=t.trim(),n=/^(\d+(?:\.\d+)?)×$/.exec(e);if(n){let s=Math.log10(Number(n[1]));return Math.abs(s-Math.round(s))<1e-9?1:3}return/\b1×$/.test(e)?2:3}function qf(i,t){let e=u=>u.right-u.left<=0,n=u=>Math.min(t.opacityAt(u.left,u.top),t.opacityAt(u.right,u.top),t.opacityAt(u.left,u.bottom),t.opacityAt(u.right,u.bottom))<t.minOpacity,s=[...t.menu?[t.menu]:[],...t.blocks,...i.chips.filter(u=>u.visible).map(u=>u.rect)],r=new Array(i.ticks.length).fill(!1),a=[];i.ticks.map((u,d)=>({i:d,t:u,p:O3(u.cls,u.text)})).sort((u,d)=>u.p-d.p||u.i-d.i).forEach(({i:u,t:d})=>{let g=e(d.rect)||n(d.rect)||s.some(_=>$c(d.rect,_,6))||a.some(_=>$c(d.rect,_,8));r[u]=g,g||a.push(d.rect)});let o=u=>!!t.menu&&$c(u,t.menu,2),c=i.chips.map(u=>o(u.rect)),l=i.orbits.map(o),h=new Array(i.paths.length).fill(!1),f=i.chips.filter(u=>u.hot).map(u=>u.rect);return i.paths.map((u,d)=>({i:d,t:u})).sort((u,d)=>Number(d.t.rec)-Number(u.t.rec)||u.i-d.i).forEach(({i:u,t:d})=>{let g=e(d.rect)||o(d.rect)||f.some(_=>$c(d.rect,_,3));h[u]=g,g||f.push(d.rect)}),{ticks:r,paths:h,chips:c,orbits:l}}var Ee=i=>String(i).replace(/[&<>"]/g,t=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"})[t]),Yf='<svg viewBox="0 0 12 12" aria-hidden="true"><path d="M2.5 2.5l7 7M9.5 2.5l-7 7"/></svg>',B3={h:'<path d="M8 13V3M4 7l4-4 4 4"/>',f:'<path d="M8 14c-2.6 0-4.3-1.8-4.3-4.1 0-2.6 2.3-3.9 2.6-6.9 1.9 1 3 2.6 2.9 4.3.7-.5 1.1-1.2 1.2-2 1.2 1.1 1.9 2.7 1.9 4.4C12.3 12.2 10.6 14 8 14z"/>',d:'<circle cx="8" cy="8.5" r="5.3"/><path d="M8 5.6v3l2 1.4"/>',s:'<path d="M8 2.6l1.6 3.5 3.8.4-2.8 2.6.8 3.8L8 11l-3.4 1.9.8-3.8-2.8-2.6 3.8-.4z"/>',r:'<path d="M8 1.8c2 1.6 2.9 4 2.6 7.2l-1.2 2.2H6.6L5.4 9C5.1 5.8 6 3.4 8 1.8zM6.4 11.4L5 14l2-.9M9.6 11.4L11 14l-2-.9"/>'},uo=i=>`<svg viewBox="0 0 16 16" aria-hidden="true">${B3[i]}</svg>`;function z3(i){let t=i.container,e=t.ownerDocument,n=e.defaultView??window,s=i.limit??$h,r=i.menu!==!1,a=i.language,o=i.contrast??"normal",c=()=>a==="zh",l=(T,q)=>c()?q:T,h=i.logo??(T=>`<span>${Ee(T.slice(0,1).toUpperCase())}</span>`),f=(T,q)=>{let ht=e.createElement(T);return ht.className=q,ht};t.classList.add("lfw");let u=f("div","lfw-dim"),d=f("div","lfw-view"),g=f("div","lfw-sky"),_=f("canvas","lfw-outline"),m=f("aside","lfw-menu"),p=f("div","lfw-keys"),S=f("div","lfw-focus"),w=f("div","lfw-toast");u.hidden=i.dim===!1;for(let T of[u,g,_])T.setAttribute("aria-hidden","true");S.hidden=!0,m.hidden=!r,w.setAttribute("role","status"),w.setAttribute("aria-live","polite"),t.append(u,d,_,m,p,S,w);let y=[],E=new Map,M=[],I=new Set,v={},C=new Set,L=null,N="",P=null,B=null,F=null,W="fleet",rt="mine",nt="",dt=!1,Q=new Map,ct=null,O=null,St=()=>{let T=t.clientWidth,q=t.clientHeight;return!T||!q?!1:(ct&&ct.W===T&&ct.H===q||(ct=Hh(T,q),O=Vh(ct),Dt()),!0)},Et=(T,q)=>{let ht=e.createElement("canvas");ht.width=T.w,ht.height=T.h;let X=ht.getContext("2d"),zt=X.createImageData(T.w,T.h);for(let wt=0;wt<T.alpha.length;wt++)zt.data[wt*4]=zt.data[wt*4+1]=zt.data[wt*4+2]=255,zt.data[wt*4+3]=q?255-T.alpha[wt]:T.alpha[wt];return X.putImageData(zt,0,0),`url(${ht.toDataURL("image/png")})`},At=(T,q)=>{T.style.maskImage=q,T.style.setProperty("-webkit-mask-image",q)};function Ot(){if(!ct)return;let T=n.devicePixelRatio||1,{W:q,H:ht}=ct;_.width=Math.round(q*T),_.height=Math.round(ht*T);let X=_.getContext("2d");if(!X||(X.setTransform(T,0,0,T,0,0),X.clearRect(0,0,q,ht),o!=="more"))return;let zt=kh(q,ht,{sx:.996,sy:.994});X.beginPath(),zt.forEach((wt,xe)=>xe?X.lineTo(wt.x,wt.y):X.moveTo(wt.x,wt.y)),X.closePath(),X.lineWidth=1,X.strokeStyle="rgba(186,204,232,.55)",X.stroke()}function Dt(){if(!ct||!O)return;At(d,Et(ct,!1)),u.hidden||At(u,Et(ct,!0)),Ot();let T=O.menu;t.classList.toggle("lfw-rim",!T.inside),t.classList.toggle("lfw-dense",T.dense),t.classList.toggle("lfw-mini",T.legend==="hidden"),t.classList.toggle("lfw-tiny",!O.gauge.show),t.style.setProperty("--lfw-mw",T.w+"px"),Object.assign(m.style,{left:T.x+"px",top:T.y+"px",width:T.w+"px",height:T.h+"px"}),S.style.left=O.focus.x+"px",S.style.bottom=O.focus.bottom+"px",S.style.maxWidth=Math.max(320,O.W-(T.x+T.w)-60)+"px",t.style.setProperty("--lf-gauge-top",O.gauge.top+"px"),t.style.setProperty("--lf-gauge-bottom",O.gauge.bottom+"px"),r&&x()}let tt=T=>{let q=Q.get(T.id);return q&&T.e.find(ht=>ht[0]===q)||T.sel||Ps(T)||null},it=()=>y.map(T=>({...T,sel:tt(T)})),_t=()=>y.filter(T=>M.includes(T.id)&&tt(T)).sort((T,q)=>tt(q)[1]-tt(T)[1]),bt=null,mt=()=>!St()||!O?{}:r?O.insets:{...O.insets,left:O.menu.x+28},Ct=()=>bt?.update({models:it(),shown:M,focus:P,hint:F??B,language:a}),Qt=(T,q)=>{let ht=T.getBoundingClientRect();return{left:ht.left-q.left,top:ht.top-q.top,right:ht.right-q.left,bottom:ht.bottom-q.top}};function V(){if(!ct)return;let T=t.getBoundingClientRect(),q=ct,ht=[...d.querySelectorAll(".tick3")],X=[...d.querySelectorAll(".bl3")],zt=[...d.querySelectorAll(".plate")],wt=[...d.querySelectorAll(".ltag")],xe=qf({ticks:ht.map(Gt=>({cls:Gt.classList.contains("axis")?"axis":Gt.classList.contains("lane")?"lane":"",text:Gt.textContent??"",rect:Qt(Gt,T)})),paths:X.map(Gt=>({rec:Gt.classList.contains("rec"),rect:Qt(Gt,T)})),chips:zt.map(Gt=>({rect:Qt(Gt,T),visible:+(Gt.style.opacity||1)>.3,hot:Gt.classList.contains("hot")})),orbits:wt.map(Gt=>Qt(Gt,T))},{opacityAt:(Gt,ie)=>q.at(Gt,ie),minOpacity:Uf,menu:r&&!m.hidden?Qt(m,T):null,blocks:[p,...S.hidden?[]:[S]].map(Gt=>Qt(Gt,T))});ht.forEach((Gt,ie)=>Gt.classList.toggle("lf-hid",xe.ticks[ie])),X.forEach((Gt,ie)=>Gt.classList.toggle("lf-hid",xe.paths[ie])),zt.forEach((Gt,ie)=>Gt.classList.toggle("lf-hid",xe.chips[ie])),wt.forEach((Gt,ie)=>Gt.classList.toggle("lf-hid",xe.orbits[ie]))}function ut(){p.innerHTML=`<p class="lfw-hint">${P?`${l("Click empty space or","\u70B9\u7A7A\u767D\u5904\u6216\u6309")} <kbd>Esc</kbd> ${l("to go back","\u8FD4\u56DE\u5168\u666F")}`:`${l("Drag to rotate","\u62D6\u52A8\u65CB\u8F6C")} \xB7 ${l("click a rocket to fly in","\u70B9\u706B\u7BAD\u98DE\u8FD1")} \xB7 <kbd>Esc</kbd> ${l("closes","\u5173\u95ED")}`}</p><button type="button" class="lfw-site" data-site="fleet">${l("Full fleet on the website","\u5728\u7F51\u7AD9\u4E0A\u770B\u5B8C\u6574\u8230\u961F")} <span aria-hidden="true">\u2197</span></button><button type="button" class="lfw-x" data-close aria-label="${Ee(l("Close (Esc)","\u5173\u95ED\uFF08Esc\uFF09"))}" title="${Ee(l("Close \xB7 Esc","\u5173\u95ED \xB7 Esc"))}">${Yf}</button>`}let xt=T=>T==="Default"?l("Default","\u9ED8\u8BA4"):c()?(Vf[T]??T)+"\u6863":T,gt=(T,q)=>`${q===T.rec?"\u2605 ":""}${xt(q)}`,yt=T=>`<span class="lfw-mini">${h(T)}</span>`,Bt=T=>C.has(T.id)?`<em class="lfw-prov" title="${Ee(l("Provisional score: too few benchmark results yet; it can still move","\u6682\u5B9A\u5206\uFF1A\u57FA\u51C6\u7ED3\u679C\u8FD8\u4E0D\u591F\u591A\uFF0C\u4E4B\u540E\u53EF\u80FD\u53D8\u52A8"))}">${l("provisional","\u6682\u5B9A")}</em>`:"",Ut=T=>{let q=Xf(v[T]??[]);return q?`<svg class="lfw-spk ${q.trend}" width="34" height="13" viewBox="0 0 34 13" role="img" aria-label="${Ee(l(`OpenRouter usage rank, 30 days: #${q.first} \u2192 #${q.last}`,`OpenRouter \u7528\u91CF\u6392\u540D 30 \u5929\uFF1A#${q.first} \u2192 #${q.last}`))}"><path d="${q.d}"/><circle cx="${q.end.x.toFixed(1)}" cy="${q.end.y.toFixed(1)}" r="1.8"/></svg>`:`<span class="lfw-spk-na" title="${Ee(l("Not ranked on OpenRouter in the last 30 days","\u8FD1 30 \u5929\u672A\u8FDB\u5165 OpenRouter \u6392\u540D"))}">\u2013</span>`},Zt=T=>T.name.replace(/^Claude /,"");function ee(){let T=_t(),q=Xc(T),ht=[...T].sort((wt,xe)=>(Ps(wt)?.[2]??1/0)-(Ps(xe)?.[2]??1/0))[0],X=T.map((wt,xe)=>{let Gt=q.get(wt.id),ie=tt(wt),ke=Gt.dominatedBy&&E.get(Gt.dominatedBy);return`<li class="lfw-row ${Gf(Gt.tag)?"out":""} ${P===wt.id?"on":""}" data-id="${Ee(wt.id)}" style="--c:${Ee(wt.colour)}">
        <button type="button" class="lfw-go" data-go="${Ee(wt.id)}" title="${Ee(ke?l(`${Zt(ke)} costs less with at least the same ability`,`${Zt(ke)} \u66F4\u4FBF\u5B9C\uFF0C\u80FD\u529B\u4E0D\u4F4E\u4E8E\u5B83`):l("Fly to this rocket","\u98DE\u8FD1\u8FD9\u53F0\u706B\u7BAD"))}">
          <span class="lfw-lamp">${xe+1}</span>
          <span class="nm">${yt(wt.dev)}<b>${Ee(Zt(wt))}</b>${Bt(wt)}</span>
          <span class="sub">${Gt.tag?`<i class="lfw-tag tag-${Gt.tag}">${l(...Xh[Gt.tag])}</i>`:""}<span class="cx" title="${Ee(l("Cost per task as a multiple of the cheapest model on the field","\u6BCF\u4EFB\u52A1\u8D39\u7528\uFF0C\u76F8\u5BF9\u573A\u4E0A\u6700\u7701\u7684\u4E00\u53F0"))}">${Wf(Gt.costRelative)}</span><span class="tr">${Ut(wt.id)}</span></span>
          <span class="vl"><b>${ie[1].toFixed(1)}</b><small class="${ie[0]===wt.rec?"rec":""}">${Ee(gt(wt,ie[0]))}</small></span>
        </button>
        <button type="button" class="lfw-rm" data-rm="${Ee(wt.id)}" ${M.length<=1?"disabled":""} aria-label="${Ee(l(`Remove ${wt.name} from the field`,`\u628A ${wt.name} \u64A4\u4E0B\u53D1\u5C04\u573A`))}" title="${Ee(l("Remove from the field","\u64A4\u4E0B\u53D1\u5C04\u573A"))}">${Yf}</button>
      </li>`}).join(""),zt=O?.menu.legend==="open";return`<div class="lfw-colh"><span><i class="lbl">${l("On the field","\u573A\u4E0A")} </i><b>${T.length}</b>/${s}</span><span class="ix" title="${Ee(l("ModelPlan ability index at the effort shown under each number (\u2605 = recommended effort)","ModelPlan \u80FD\u529B\u6307\u6570\uFF0C\u6309\u6BCF\u4E2A\u6570\u5B57\u4E0B\u9762\u6807\u7684\u6863\u4F4D\uFF08\u2605 = \u63A8\u8350\u6863\uFF09"))}">${l("ModelPlan ability index","ModelPlan \u80FD\u529B\u6307\u6570")}</span></div>
      <ol class="lfw-list">${X}</ol>
      <p class="lfw-key"><span><svg width="16" height="8" aria-hidden="true"><path d="M1 6 L5 3 L9 5 L15 1" fill="none" stroke="#a2a4a8" stroke-width="1.2"/></svg>${l("30-day usage trend (OpenRouter rank)","30 \u5929\u7528\u91CF\u8D70\u52BF\uFF08OpenRouter \u6392\u540D\uFF09")}</span>${ht?`<span><b class="cxk">\xD7</b>${l("cost vs the cheapest here","\u8D39\u7528\uFF0C\u76F8\u5BF9\u573A\u4E0A\u6700\u7701\u7684")} (${Ee(Zt(ht))} \u2605)</span>`:""}</p>
      <details class="lfw-legend" ${zt?"open":""}><summary>${l("How to read this chart","\u600E\u4E48\u770B\u8FD9\u5F20\u56FE")}</summary><dl>
        <dt>${uo("h")}</dt><dd><b>${l("Height","\u9AD8\u5EA6")}</b>${l("ModelPlan ability index","ModelPlan \u80FD\u529B\u6307\u6570")}</dd>
        <dt>${uo("f")}</dt><dd><b>${l("Flame","\u5C3E\u7130")}</b>${l("cost ","\u6210\u672C ")}<em class="fz hi">${l("cheap","\u84DD\u7701")}</em> \xB7 <em class="fz mid">${l("mid","\u6A59\u4E2D")}</em> \xB7 <em class="fz lo">${l("dear","\u9ED1\u8D35")}</em></dd>
        <dt>${uo("d")}</dt><dd><b>${l("Depth","\u7EB5\u6DF1")}</b>${l("task time (est.)","\u8017\u65F6\uFF08\u4F30\u7B97\uFF09")}</dd>
        <dt>${uo("s")}</dt><dd><b>${l("Star","\u63A8\u8350\u6863")}</b>${l("best-value effort","\u6700\u503C\u7684\u6863\u4F4D")}</dd>
        <dt>${uo("r")}</dt><dd><b>${l("Starship","\u661F\u8230")}</b>${l("top, or xAI in top 3","\u6700\u5F3A\uFF08xAI \u524D\u4E09\u4F18\u5148\uFF09")}</dd></dl>
        <button type="button" class="lfw-link" data-site="methodology">${l("How we work it out","\u600E\u4E48\u7B97\u7684")} <span aria-hidden="true">\u2197</span></button></details>
      <div class="lfw-act"><button type="button" class="pri" data-tab="pick"><span aria-hidden="true">+</span> ${l("Pick models","\u9009\u6A21\u578B")}</button><button type="button" data-site="effort">${l("Compare on site","\u53BB\u7F51\u7AD9\u5BF9\u6BD4")} <span aria-hidden="true">\u2197</span></button></div>`}let U=T=>I.has(T.id)||M.includes(T.id),ne=()=>[...y].sort((T,q)=>(Ps(q)?.[1]??-1)-(Ps(T)?.[1]??-1));function re(){let T=nt.trim().toLowerCase(),q=ie=>!T||`${ie.name} ${ie.dev}`.toLowerCase().includes(T),ht=ne(),X=ht.filter(ie=>(rt==="all"||U(ie))&&q(ie)),zt=rt==="mine"&&T?ht.filter(ie=>!U(ie)&&q(ie)):[],wt=M.length>=s,xe=_t().map(ie=>ie.id),Gt=ie=>{let ke=M.includes(ie.id),xn=!ke&&wt,Kn=tt(ie);return`<li class="${ke?"is-on":""} ${xn?"is-full":""} ${P===ie.id?"focused":""}" data-id="${Ee(ie.id)}" style="--c:${Ee(ie.colour)}">
        <button type="button" class="lfw-lamp lfw-tg" data-tg="${Ee(ie.id)}" aria-pressed="${ke}" ${xn?`aria-disabled="true" title="${Ee(l(`The field holds ${s}; remove one first`,`\u573A\u4E0A\u6700\u591A ${s} \u53F0\uFF0C\u5148\u64A4\u4E0B\u4E00\u53F0`))}"`:""} aria-label="${Ee(ke?l(`Retract ${ie.name}`,`\u64A4\u56DE ${ie.name}`):l(`Launch ${ie.name}`,`\u53D1\u5C04 ${ie.name}`))}">${ke?xe.indexOf(ie.id)+1:""}</button>
        <button type="button" class="lfw-pn" data-pk="${Ee(ie.id)}"><span class="l1">${yt(ie.dev)}<b>${Ee(ie.name)}</b></span><span class="l2">${Kn?`<small class="${Kn[0]===ie.rec?"rec":""}">${Ee(gt(ie,Kn[0]))}</small>`:""}${Bt(ie)}</span></button>
        <span class="lfw-ps">${Kn?Kn[1].toFixed(1):"\u2013"}</span></li>`};return!X.length&&!zt.length?`<li class="lfw-empty">${l("No matching models","\u6CA1\u6709\u5339\u914D\u7684\u6A21\u578B")}</li>`:(X.length?X.map(Gt).join(""):`<li class="lfw-empty sm">${l("None of your tools runs a match.","\u4F60\u7684\u5DE5\u5177\u91CC\u6CA1\u6709\u5339\u914D\u7684\u6A21\u578B\u3002")}</li>`)+(zt.length?`<li class="lfw-div" aria-hidden="true">${l("Other models","\u5176\u4ED6\u6A21\u578B")}</li>`+zt.map(Gt).join(""):"")}function A(){let T=y.filter(U).length,q=M.length>=s,ht=!!L&&L.length===M.length&&L.every(X=>M.includes(X));return`<label class="lfw-search"><svg viewBox="0 0 16 16" aria-hidden="true"><circle cx="7" cy="7" r="4.6"/><path d="M10.4 10.4L14 14"/></svg><input type="search" autocomplete="off" spellcheck="false" value="${Ee(nt)}" placeholder="${Ee(l("Search models","\u641C\u7D22\u6A21\u578B"))}" aria-label="${Ee(l("Search models","\u641C\u7D22\u6A21\u578B"))}"></label>
      <div class="lfw-scope"><div class="lfw-seg" role="group" aria-label="${Ee(l("Scope","\u8303\u56F4"))}"><button type="button" data-scope="mine" aria-pressed="${rt==="mine"}">${l("Mine","\u6211\u7684")} <small>${T}</small></button><button type="button" data-scope="all" aria-pressed="${rt==="all"}">${l("All","\u5168\u90E8")} <small>${y.length}</small></button></div>
        <span class="lfw-cnt ${q?"full":""}"><b>${M.length}</b>/${s} ${l("on the field","\u4E0A\u573A")}</span></div>
      <p class="lfw-note">${q?`<span class="warn">${l(`The field is full (${s}). Tap a lit lamp to retract one first.`,`\u573A\u4E0A\u5DF2\u6EE1 ${s} \u53F0\uFF1A\u5148\u70B9\u4EAE\u7740\u7684\u5706\u706F\u64A4\u4E0B\u4E00\u53F0\u3002`)}</span>`:rt==="mine"?l("Mine: models your connected tools can run, plus anything on the field.","\u6211\u7684\uFF1A\u4F60\u8FDE\u63A5\u7684\u5DE5\u5177\u80FD\u8DD1\u7684\u6A21\u578B\uFF0C\u4EE5\u53CA\u5DF2\u5728\u573A\u4E0A\u7684\u3002"):l("Every model ModelPlan tracks, strongest first. Tap a lamp to launch or retract.","ModelPlan \u8DDF\u8E2A\u7684\u5168\u90E8\u6A21\u578B\uFF0C\u6309\u80FD\u529B\u6392\u5E8F\u3002\u70B9\u5706\u706F\u53D1\u5C04\u6216\u64A4\u56DE\u3002")}</p>
      <ul class="lfw-pick">${re()}</ul>
      <div class="lfw-act">${L?`<button type="button" data-reset ${ht?"disabled":""}>${l("Default fleet","\u6062\u590D\u9ED8\u8BA4")}</button>`:""}<button type="button" class="pri" data-tab="fleet">${l("Done","\u5B8C\u6210")}</button></div>`}function x(){if(!r||dt)return;let T=e.activeElement,q=T instanceof HTMLInputElement&&m.contains(T),ht=q?T.selectionStart:null;if(m.setAttribute("aria-label",l("Models on the field","\u573A\u4E0A\u6A21\u578B")),m.innerHTML=`<header class="lfw-h"><p class="lfw-kick">${l("Launch field","\u53D1\u5C04\u573A")}</p>${N?`<span class="lfw-asof" title="${Ee(l("Data snapshot","\u6570\u636E\u5FEB\u7167"))}">${l("data","\u6570\u636E")} ${Ee(N.slice(5,10))}</span>`:""}</header>
      <div class="lfw-tabs" role="tablist"><button type="button" role="tab" data-tab="fleet" aria-selected="${W==="fleet"}">${l("Worth it?","\u54EA\u4E2A\u6700\u503C")}</button><button type="button" role="tab" data-tab="pick" aria-selected="${W==="pick"}">${l("Pick models","\u9009\u6A21\u578B")} <small>${M.length}/${s}</small></button></div>
      <div class="lfw-body ${W}">${W==="fleet"?ee():A()}</div>`,q){let X=m.querySelector(".lfw-search input");X?.focus({preventScroll:!0}),X&&ht!=null&&X.setSelectionRange(ht,ht)}}let G=()=>{let T=m.querySelector(".lfw-pick");T&&(T.innerHTML=re())};function Y(){let T=P?E.get(P):void 0;if(S.hidden=!T,t.classList.toggle("lfw-zoomed",!!T),ut(),!T)return;let q=Xc(_t()).get(T.id),ht=tt(T);S.innerHTML=`<div class="fh"><button type="button" class="lfw-back" data-back>${l("Back to fleet","\u8FD4\u56DE\u5168\u666F")} <kbd>Esc</kbd></button>
        ${yt(T.dev)}<b>${Ee(T.name)}</b>${Bt(T)}${q?.tag?`<i class="lfw-tag tag-${q.tag}">${l(...Xh[q.tag])}</i>`:""}
        <button type="button" class="lfw-link" data-site="effort" data-m="${Ee(T.slug??T.id)}">${l("Effort details","\u6863\u4F4D\u8BE6\u60C5")} <span aria-hidden="true">\u2197</span></button></div>
      ${T.e.length>1?`<div class="lfw-ladder" role="group" aria-label="${Ee(l("Change effort","\u5207\u6362\u6863\u4F4D"))}">${T.e.map(X=>`<button type="button" data-eff="${Ee(X[0])}" aria-pressed="${ht?.[0]===X[0]}" class="${X[0]===T.rec?"rec":""}"><span>${X[0]===T.rec?"<i>\u2605</i>":""}${Ee(xt(X[0]))}</span><small>${X[1].toFixed(1)}</small></button>`).join("")}</div>`:""}
      <p class="lfw-ix">${l("ModelPlan ability index","ModelPlan \u80FD\u529B\u6307\u6570")} \xB7 ${l("height = the effort lit above","\u9AD8\u5EA6 = \u4E0A\u9762\u4EAE\u7740\u7684\u6863\u4F4D")}</p>`}let at=0,Mt=T=>{w.textContent=T,w.classList.add("on"),n.clearTimeout(at),at=n.setTimeout(()=>w.classList.remove("on"),2600)},Rt=(T,q={})=>{let ht=Wh(T,q);ht&&i.onOpenSite?.(ht.target,ht.params)};function st(T,q){if(T&&!E.has(T)&&(T=null),T&&!M.includes(T)){let ht=qh(M,T,s);if("refused"in ht){Mt(l(`The field holds ${s}. Retract one first.`,`\u573A\u4E0A\u6700\u591A ${s} \u53F0\uFF0C\u5148\u64A4\u4E0B\u4E00\u53F0\u3002`));return}ft(ht.ids,!0)}T!==P&&(P=T,Y(),x(),Ct(),q&&i.onSelect?.(P))}function ft(T,q){M=T.slice(0,s),P&&!M.includes(P)&&(P=null,Y()),x(),Ct(),q&&i.onShownChange?.([...M])}let Pt=T=>{let q=qh(M,T,s);"refused"in q?Mt(q.refused==="last"?l("Keep at least one rocket on the field","\u573A\u4E0A\u81F3\u5C11\u7559\u4E00\u53F0\u706B\u7BAD"):l(`The field holds ${s}. Retract one first.`,`\u573A\u4E0A\u6700\u591A ${s} \u53F0\uFF0C\u5148\u64A4\u4E0B\u4E00\u53F0\u3002`)):ft(q.ids,!0)},Ht=T=>{Q.clear(),nt="",P=null,Y(),x(),Ct(),i.onClose?.(T)},Nt=T=>{let q=T.target;if(!q?.closest||q.closest(".lfw-view"))return;let ht=zt=>q.closest(zt),X;(X=ht("[data-site]"))?(T.preventDefault(),Rt(X.dataset.site,X.dataset.m?{m:X.dataset.m}:{})):ht("[data-close]")?Ht("key"):ht("[data-back]")?st(null,!0):(X=ht("[data-eff]"))&&P?(Q.set(P,X.dataset.eff),Y(),x(),Ct()):(X=ht("[data-tab]"))?(W=X.dataset.tab==="pick"?"pick":"fleet",x(),W==="pick"&&m.querySelector(".lfw-search input")?.focus({preventScroll:!0})):(X=ht("[data-scope]"))?(rt=X.dataset.scope==="all"?"all":"mine",x()):(X=ht("[data-rm]"))?Pt(X.dataset.rm):(X=ht("[data-go]"))?st(X.dataset.go,!0):(X=ht("[data-tg]"))?Pt(X.dataset.tg):(X=ht("[data-pk]"))?st(X.dataset.pk,!0):ht("[data-reset]")&&L&&ft(L.slice(0,s),!0)},Tt=T=>{let q=T.target;q.closest?.(".lfw-search")&&(nt=q.value,G())},Xt=T=>{let q=T.target.closest?.(".lfw-row, .lfw-pick li"),ht=q?.dataset.id&&M.includes(q.dataset.id)?q.dataset.id:null;ht!==F&&(F=ht,Ct())},Jt=()=>{F&&(F=null,Ct())},le=T=>{if(T.key!=="Escape"||dt)return;T.preventDefault();let q=Gh({search:nt,focus:P});if(q==="clear-search"){nt="";let ht=m.querySelector(".lfw-search input");ht&&(ht.value=""),G()}else q==="leave-focus"?st(null,!0):Ht("esc")};t.addEventListener("click",Nt),t.addEventListener("input",Tt),m.addEventListener("pointerover",Xt),m.addEventListener("pointerleave",Jt),n.addEventListener("keydown",le);let z=new ResizeObserver(()=>St());z.observe(t),ut(),bt=zh({container:d,language:a,assetBase:i.assetBase,logo:i.logo,scale:i.scale,axis:i.axis,insets:mt,gaugeLeft:()=>St()&&O?r?O.gauge.left:O.menu.x:0,rocketScale:i.rocketScale??1.24,reducedMotion:i.reducedMotion,onSelect:T=>st(T,!0),onFail:i.onFail,onSlow:i.onSlow,onFrame:V});let Ft=d.querySelector(".lf-scene");return d.insertBefore(g,Ft?Ft.nextSibling:d.firstChild),St(),{update(T){if(!dt){y=T.models,E=new Map(y.map(q=>[q.id,q])),M=T.shown.filter(q=>E.has(q)).slice(0,s),T.language&&(a=T.language),T.mine&&(I=new Set(T.mine)),T.trend&&(v=T.trend),T.provisional&&(C=new Set(T.provisional)),T.defaults!==void 0&&(L=T.defaults),T.asOf!==void 0&&(N=T.asOf),T.hint!==void 0&&(B=T.hint);for(let q of[...Q.keys()])E.has(q)||Q.delete(q);T.focus!==void 0?P=T.focus&&M.includes(T.focus)?T.focus:null:P&&!M.includes(P)&&(P=null),St(),Y(),x(),Ct()}},setOptions(T){dt||(T.contrast&&(o=T.contrast,Ot()),T.reducedMotion!==void 0&&bt?.setOptions({reducedMotion:T.reducedMotion}),T.language&&T.language!==a&&(a=T.language,Y(),x(),Ct()))},setSelection(T){dt||(P=T&&M.includes(T)?T:null,Y(),x(),Ct())},layout:()=>O,dispose(){if(!dt){dt=!0,Q.clear(),n.clearTimeout(at),z.disconnect(),n.removeEventListener("keydown",le),t.removeEventListener("click",Nt),t.removeEventListener("input",Tt),m.removeEventListener("pointerover",Xt),m.removeEventListener("pointerleave",Jt),bt?.dispose(),bt=null;for(let T of[u,d,_,m,p,S,w])T.remove();t.classList.remove("lfw","lfw-rim","lfw-dense","lfw-mini","lfw-tiny","lfw-zoomed");for(let T of["--lfw-mw","--lf-gauge-top","--lf-gauge-bottom"])t.style.removeProperty(T)}}}}var k3="1.1.0";var Zf={height:47,scales:[2,3],sprites:{"cz2f-alibaba":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-alibaba":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-alibaba":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-alibaba":{w:20,h:48,ax:10,tip:1,nz:48},"falcon9-anthropic":{w:12,h:49,ax:6,tip:1,nz:48},"newGlenn-anthropic":{w:14,h:49,ax:7,tip:1,nz:48},"falconHeavy-anthropic":{w:22,h:49,ax:11,tip:1,nz:48},"vulcan-anthropic":{w:16,h:50,ax:8,tip:1,nz:48},"heavy-anthropic":{w:20,h:48,ax:10,tip:1,nz:48},"cz2f-deepseek":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-deepseek":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-deepseek":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-deepseek":{w:20,h:48,ax:10,tip:1,nz:48},"falcon9-google":{w:12,h:49,ax:6,tip:1,nz:48},"newGlenn-google":{w:14,h:49,ax:7,tip:1,nz:48},"falconHeavy-google":{w:22,h:49,ax:11,tip:1,nz:48},"vulcan-google":{w:16,h:50,ax:8,tip:1,nz:48},"heavy-google":{w:20,h:48,ax:10,tip:1,nz:48},"cz2f-kimi":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-kimi":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-kimi":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-kimi":{w:20,h:48,ax:10,tip:1,nz:48},"falcon9-meta":{w:12,h:49,ax:6,tip:1,nz:48},"newGlenn-meta":{w:14,h:49,ax:7,tip:1,nz:48},"falconHeavy-meta":{w:22,h:49,ax:11,tip:1,nz:48},"vulcan-meta":{w:16,h:50,ax:8,tip:1,nz:48},"heavy-meta":{w:20,h:48,ax:10,tip:1,nz:48},"cz2f-minimax":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-minimax":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-minimax":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-minimax":{w:20,h:48,ax:10,tip:1,nz:48},"falcon9-openai":{w:12,h:49,ax:6,tip:1,nz:48},"newGlenn-openai":{w:14,h:49,ax:7,tip:1,nz:48},"falconHeavy-openai":{w:22,h:49,ax:11,tip:1,nz:48},"vulcan-openai":{w:16,h:50,ax:8,tip:1,nz:48},"heavy-openai":{w:20,h:48,ax:10,tip:1,nz:48},"cz2f-tencent":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-tencent":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-tencent":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-tencent":{w:20,h:48,ax:10,tip:1,nz:48},"cz2f-volcengine":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-volcengine":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-volcengine":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-volcengine":{w:20,h:48,ax:10,tip:1,nz:48},"falcon9-xai":{w:12,h:49,ax:6,tip:1,nz:48},"newGlenn-xai":{w:14,h:49,ax:7,tip:1,nz:48},"falconHeavy-xai":{w:22,h:49,ax:11,tip:1,nz:48},"vulcan-xai":{w:16,h:50,ax:8,tip:1,nz:48},"heavy-xai":{w:20,h:48,ax:10,tip:1,nz:48},"cz2f-xiaomi":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-xiaomi":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-xiaomi":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-xiaomi":{w:20,h:48,ax:10,tip:1,nz:48},"cz2f-zhipuai":{w:18,h:49,ax:9,tip:1,nz:48},"cz5-zhipuai":{w:24,h:50,ax:12,tip:1,nz:48},"cz3b-zhipuai":{w:20,h:50,ax:10,tip:1,nz:48},"heavy-zhipuai":{w:20,h:48,ax:10,tip:1,nz:48}}};function qc(i,t,e){return i.ability===null||i.cost===null||i.cost<0||!t.costBasisId||i.costBasisId!==t.costBasisId?null:{x:i.cost===0?-9.2:-8+16*(Math.log2(i.cost)-Math.log2(e)-t.costMin)/(t.costMax-t.costMin),y:3+18*(i.ability-t.abilityMin)/(t.abilityMax-t.abilityMin),z:i.time===null?5.7:4-10*i.time/t.timeMax,unknownTime:i.time===null}}function Yh(i,t=Jn){let e=new Set(i.shown),n=i.models.filter(a=>e.has(a.id)&&a.sel).map(a=>{let o=a.sel;return{id:a.id,name:a.name,developerId:a.dev,colour:a.colour,ability:o[1],provisional:!1,cost:o[2],costBasisId:"ratio",time:o[3],estimated:o[4],effort:o[0],fuel:a.fuel,shape:a.shape}}),s=n.flatMap(a=>a.cost!==null&&a.cost>0?[Math.log2(a.cost)]:[]),r=i.models.flatMap(a=>a.e.flatMap(o=>o[3]!==null?[o[3]]:[]));return{engines:n,bounds:{costBasisId:"ratio",costMin:Math.min(-1,Math.min(...s)-.5),costMax:Math.max(1,Math.max(...s)+.5),...Lh(n.flatMap(a=>a.ability!==null?[a.ability]:[]),t,i.axis??void 0),timeMax:Math.max(1,...r)},baseline:1,focus:i.focus??null,language:i.language,step:i.axis?.step}}var fo={hi:["#e9f6ff","#6fb8ff"],mid:["#fff1d6","#ff9a4a"],lo:["#d9b49a","#5a3a2c"]},Jf=i=>i.name.replace(/^Claude /,""),Kf=Zf.sprites,Yc=i=>String(i).replace(/[&<>"]/g,t=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"})[t]),V3=(i,t)=>{let e=`${t?"heavy":i.shape??Rf(i.developerId,i.id)}-${i.developerId}`;return Kf[e]?{key:e,...Kf[e]}:void 0},G3=()=>__LF_ENV__?.BASE_URL??"./";function W3(i,t,e,n,s,r,a){let o=V3(i,s),c=(typeof devicePixelRatio=="number"?devicePixelRatio:1)*r>2?3:2,l=Ur(i.developerId,i.colour),h=s?"#c9ced4":l.base,f=s?"#8b929b":l.trim[0]??l.ink,u=s?"#7d848d":l.colour,d=fo[i.fuel],g=Math.min(7,3+Math.sqrt(n)*.8),_=Math.min(46,14+Math.sqrt(n)*5),m=`<g class="rk"><ellipse cx="${t}" cy="${e+47+_*.35}" rx="${g*2.2}" ry="${_*.55}" fill="${d[1]}" opacity=".22" filter="url(#flatBlur)"></ellipse><path d="M${t-g} ${e+44} Q${t-g*.7} ${e+44+_*.6} ${t} ${e+44+_} Q${t+g*.7} ${e+44+_*.6} ${t+g} ${e+44} Z" fill="url(#flame-${i.fuel})"></path>`;return o?m+=`<image href="${Yc(`${a}art/rockets/flat/${o.key}@${c}x.webp`)}" x="${t-o.ax}" y="${e+44-o.nz}" width="${o.w}" height="${o.h}"></image>`:m+=`<path d="M${t-4} ${e+37} L${t+4} ${e+37} L${t+5.5} ${e+44} L${t-5.5} ${e+44} Z" fill="url(#flatBell)"></path><path d="M${t-5} ${e+27} L${t-11} ${e+37} L${t-11} ${e+40} L${t-5} ${e+36} Z" fill="${u}"></path><path d="M${t+5} ${e+27} L${t+11} ${e+37} L${t+11} ${e+40} L${t+5} ${e+36} Z" fill="${u}"></path><rect x="${t-5}" y="${e+9}" width="10" height="29" rx="1.5" fill="${s?"url(#flatSteel)":"url(#flatHull)"}"></rect><rect x="${t-5}" y="${e+14}" width="10" height="2.2" fill="${f}"></rect><circle cx="${t}" cy="${e+21}" r="1.7" fill="#0b0e15" stroke="${f}" stroke-width=".7"></circle><path d="M${t-5} ${e+9.5} Q${t-5} ${e+1.5} ${t} ${e-3} Q${t+5} ${e+1.5} ${t+5} ${e+9.5} Z" fill="${h}"></path><path d="M${t-5} ${e+9.5} Q${t-5} ${e+1.5} ${t} ${e-3} L${t} ${e+9.5} Z" fill="#ffffff" opacity=".18"></path><path d="M${t-1.6} ${e-1.4} Q${t} ${e-3.6} ${t+1.6} ${e-1.4} Z" fill="${s?"#f6d38a":l.cap}"></path>`,m+"</g>"}var X3=(()=>{let i=(t,e)=>`<linearGradient id="${t}" x1="0" y1="0" x2="1" y2="0">${e.map(([n,s])=>`<stop offset="${n}" stop-color="${s}"></stop>`).join("")}</linearGradient>`;return'<defs><linearGradient id="flatGlow" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9fd8ff" stop-opacity=".5"></stop><stop offset="1" stop-color="#9fd8ff" stop-opacity="0"></stop></linearGradient>'+i("flatHull",[["0","#8f949b"],[".35","#f4f1ec"],[".7","#d8d4ce"],["1","#6d7178"]])+i("flatSteel",[["0","#5d636b"],[".35","#dfe3e8"],[".65","#a9b0b8"],["1","#4b5057"]])+i("flatBell",[["0","#24272c"],[".45","#6b707a"],["1","#1c1e22"]])+Object.keys(fo).map(t=>`<linearGradient id="flame-${t}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${fo[t][0]}"></stop><stop offset=".35" stop-color="${fo[t][1]}" stop-opacity=".9"></stop><stop offset="1" stop-color="${fo[t][1]}" stop-opacity="0"></stop></linearGradient>`).join("")+'<filter id="flatBlur" x="-1" y="-1" width="3" height="3"><feGaussianBlur stdDeviation="4"></feGaussianBlur></filter></defs>'})(),jf=i=>i==="zh"?"\u4E8C\u7EF4\u53D1\u5C04\u573A\uFF0C\u80FD\u529B\u4E0E\u53C2\u8003\u6210\u672C":"2D launch field, ability and reference cost";function Qf(i,t,e,n={}){let{engines:s,bounds:r,baseline:a,focus:o}=i,c=n.assetBase??G3(),l=n.scale??Jn,h=t,f=e,u=64,d=66,g=75,_=f-80,m=h>640&&f>560,p=i.language==="zh",S=s.filter(N=>qc(N,r,a)),w=N=>u+(qc(N,r,a).x+9.2)/18.4*(h-u-d),y=N=>_-(N.ability-r.abilityMin)/(r.abilityMax-r.abilityMin)*(_-g),E=N=>Math.round(62+Jf(N).length*6.1+(N.ability??0).toFixed(1).length*6),M=$f(S.map(N=>({id:N.id,order:-(N.ability??0),x:w(N),y:y(N),width:E(N),height:24})),h,_+30),I=S.filter(N=>!N.provisional),v=Bc(I,N=>N.ability,N=>N.developerId)?.id,C=new Map([...I].sort((N,P)=>(P.ability??0)-(N.ability??0)).map((N,P)=>[N.id,P+1])),L=X3;Nh(r.abilityMin,r.abilityMax,l,i.step).forEach((N,P)=>{let B=_-(_-g)*(N-r.abilityMin)/(r.abilityMax-r.abilityMin);L+=`<g><line x1="${u}" x2="${h-d+12}" y1="${B}" y2="${B}" stroke="#5a748733"></line><text x="${u-15}" y="${B+4}" text-anchor="end" fill="#acb5bf" font-size="11">${P===0&&N>0?p?`${N} \u8D77`:`from ${N}`:N.toFixed(0)}</text></g>`}),L+=`<text x="${u+1}" y="${g-28}" fill="#f0c28f" font-size="12">${p?"\u9AD8\u5EA6 \xB7 \u80FD\u529B Index":"Height \xB7 ability Index"}</text>`;for(let N=0;N<7;N++){let P=r.costMin+(r.costMax-r.costMin)*N/6,B=u+48+N*(h-u-d-50)/6;L+=`<g><line x1="${B}" x2="${B}" y1="${g}" y2="${_}" stroke="#5a748722"></line><text x="${B}" y="${_+26}" text-anchor="middle" fill="#b5a693" font-size="10">${Math.pow(2,P).toFixed(Math.pow(2,P)<1?2:0)}\xD7</text></g>`}for(let N of[0,1])for(let P of S){let B=w(P),F=y(P),W=(P.cost??0)/a,rt=P.time===null?0:Math.min(92,12+70*P.time/r.timeMax),nt=M.get(P.id),dt=E(P),Q=(P.ability??0).toFixed(1).length*6+10;L+=`<g tabindex="0" role="button" data-id="${Yc(P.id)}" aria-label="${Yc(`${P.name} ${P.effort}`)}" class="${o===P.id?"focus":""}${o&&o!==P.id?" dim":""}">`,N===0?(L+=`<line x1="${B}" x2="${B}" y1="${F+44}" y2="${_}" stroke="${P.colour}" opacity=".14"></line>`,rt>0&&(L+=`<path d="M${B-2.5} ${F+70}L${B} ${F+70+rt}L${B+2.5} ${F+70}" fill="url(#flatGlow)" stroke="${P.estimated?"#adbef655":"none"}"${P.estimated?' stroke-dasharray="3 3"':""}></path>`),L+=`<g${m?` transform="translate(${B} ${F}) scale(1.3) translate(${-B} ${-F})"`:""}>${W3(P,B,F,W,P.id===v,m?1.3:1,c)}</g>`):L+=`<line x1="${B+(nt.x>B?7:-7)}" y1="${F+4}" x2="${nt.x>B?nt.x:nt.x+dt}" y2="${nt.y+12}" stroke="${P.colour}" opacity=".4" stroke-width=".8"></line><g class="plate2d" transform="translate(${nt.x} ${nt.y})"><rect width="${dt}" height="24" rx="12" fill="#191a1c" fill-opacity=".82" stroke="${P.colour}" stroke-opacity=".5"></rect><circle cx="12" cy="12" r="8" fill="${P.colour}"></circle><text x="12" y="15.5" text-anchor="middle" class="rk-n">${C.get(P.id)??"~"}</text><text x="25" y="16" class="rk-name">${Yc(Jf(P))}</text><rect x="${dt-Q-4}" y="4" width="${Q}" height="16" rx="5" style="fill: var(--lf-lcd-ink, #070c16); stroke: var(--lf-lcd-edge, #2a3a55);"></rect><text x="${dt-4-Q/2}" y="16" text-anchor="middle" class="rk-v">${P.ability?.toFixed(1)??""}</text></g>`,L+="</g>"}return L+=`<text x="${h-d+8}" y="${_+54}" text-anchor="end" fill="#efb37a" font-size="11">${p?"\u53C2\u8003\u6210\u672C \xD7 \xB7 \u6DE1\u62D6\u5C3E\u4E3A\u822A\u65F6\uFF0C\u865A\u7EBF\u4E3A\u4F30\u7B97":"Reference cost \xD7 \xB7 faint trail is task time; dashed is estimated"}</text>`,L}function $3(i){let t="http://www.w3.org/2000/svg",e=document.createElementNS(t,"svg");e.setAttribute("class","lf-flat"+(i.className?" "+i.className:"")),e.setAttribute("role","img"),i.container.appendChild(e);let n={w:820,h:580},s=null,r=!1,a=()=>{if(r||!s)return;let f=document.activeElement,u=f&&e.contains(f)?f.getAttribute("data-id"):null;e.setAttribute("viewBox",`0 0 ${n.w} ${n.h}`),e.setAttribute("aria-label",jf(s.language)),e.innerHTML=Qf(s,n.w,n.h,{assetBase:i.assetBase,scale:i.scale}),u&&e.querySelector(`g[role="button"][data-id="${CSS.escape(u)}"]`)?.focus()},o=new ResizeObserver(([f])=>{let u={w:Math.max(320,Math.round(f.contentRect.width)),h:Math.max(360,Math.round(f.contentRect.height))};u.w===n.w&&u.h===n.h||(n=u,a())});o.observe(e);let c=f=>f.target?.closest?.('g[role="button"][data-id]'),l=f=>{let u=c(f);u&&i.onSelect?.(u.getAttribute("data-id"))},h=f=>{let u=c(f);u&&(f.key==="Enter"||f.key===" ")&&(f.preventDefault(),i.onSelect?.(u.getAttribute("data-id")))};return e.addEventListener("click",l),e.addEventListener("keydown",h),{update(f){s="models"in f?Yh(f,i.scale):{...f,language:f.language??i.language??"zh"},a()},setSelection(f){s&&(s={...s,focus:f},a())},dispose(){r||(r=!0,o.disconnect(),e.removeEventListener("click",l),e.removeEventListener("keydown",h),e.remove())}}}export{Jn as ABILITY_SCALE,k3 as LAUNCH_FIELD_VERSION,Df as MENU_INSIDE_MIN_H,Hf as SITE_TARGETS,Oh as USER_ZOOM_MAX,Fh as USER_ZOOM_MIN,Lh as abilityRange,Nh as abilityTicks,Ff as canopyPoint,$3 as createFlatLaunch,zh as createLaunchField,z3 as createLaunchWindow,Ph as destination,Gh as escAction,Of as featherWidth,Dh as fieldBand,qc as fieldCoordinates,jf as flatAriaLabel,Yh as flatInputFromField,Xc as fleetVerdicts,Uh as gaugePercent,Vh as layoutWindow,Hh as rasterWindow,Vc as regionFromInsets,Qf as renderFlatSvg,Hc as resolveInsets,Wh as siteRequest};

/*! three.js 0.186.1 | MIT License
 * The MIT License
 * 
 * Copyright © 2010-2026 three.js authors
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
