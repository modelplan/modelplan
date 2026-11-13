// SPDX-License-Identifier: MIT
// CKP-MFD-24: the MFD's secondary website links. The page never sends a URL over the bridge; it names one of the
// typed public pages and native builds the address. Anything else is not a website link.
const value=/^[A-Za-z0-9._-]{1,64}$/;
const pages:Readonly<Record<string,(url:URL)=>string|null>>={'/plans':u=>u.searchParams.get('seller'),'/effort':u=>u.searchParams.get('model'),'/methodology':u=>u.hash.slice(1)};
export function websiteAction(href:string):string|null {
 let url:URL;try{url=new URL(href);}catch{return null;}
 const read=pages[url.pathname];
 if(url.protocol!=='https:'||url.hostname!=='modelplan.ai'||url.port||url.username||!read)return null;
 const found=read(url);
 return found&&value.test(found)?url.pathname.slice(1)+'/'+found:null;
}
export function websiteFields(action:string):{page:string;value:string}|null {
 const at=action.indexOf('/'),page=action.slice(0,at),rest=action.slice(at+1);
 return at>0&&Object.hasOwn(pages,'/'+page)&&value.test(rest)?{page,value:rest}:null;
}
