// SPDX-License-Identifier: MIT
import { createServer } from 'node:http';
import { readFile,realpath } from 'node:fs/promises';
import { resolve,sep,extname } from 'node:path';
import { fileURLToPath } from 'node:url';
const root=await realpath(fileURLToPath(new URL('../../cockpit/.tmp/official/',import.meta.url)));
const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.woff2':'font/woff2','.png':'image/png','.json':'application/json'};
const server=createServer(async(req,res)=>{
  try{
    if(req.method!=='GET')throw Error();
    const path=decodeURIComponent(new URL(req.url,'http://127.0.0.1').pathname);
    const file=await realpath(resolve(root,'.'+(path==='/'?'/index.html':path)));
    if(!file.startsWith(root+sep))throw Error();
    res.setHeader('Content-Type',mime[extname(file)]??'text/plain');res.setHeader('Cache-Control','no-store');
    res.end(await readFile(file));
  }catch{res.writeHead(404);res.end();}
});
server.listen(41783,'127.0.0.1');
for(const signal of ['SIGTERM','SIGINT'])process.once(signal,()=>server.close());
