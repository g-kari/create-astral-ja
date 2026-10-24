import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import {root,validate} from './validate.mjs';

const check=validate();
const version=JSON.parse(fs.readFileSync(path.join(root,'package.json'),'utf8')).version;
if(!/^\d+\.\d+\.\d+$/.test(version))throw Error('Invalid release version');
const out=path.join(root,'dist');fs.mkdirSync(out,{recursive:true});
const table=Array.from({length:256},(_,i)=>{let c=i;for(let n=0;n<8;n++)c=(c&1)?0xedb88320^(c>>>1):c>>>1;return c>>>0;});
function crc32(data){let c=0xffffffff;for(const b of data)c=table[(c^b)&255]^(c>>>8);return (c^0xffffffff)>>>0;}
function walk(dir,prefix=''){let files=[];for(const e of fs.readdirSync(dir,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name,'en'))){const name=prefix+e.name;if(e.isSymbolicLink())throw Error('No symlinks in packs');if(e.isDirectory())files.push(...walk(path.join(dir,e.name),name+'/'));else files.push([name,fs.readFileSync(path.join(dir,e.name))]);}return files;}
function zip(name,entries){let offset=0;const blocks=[],central=[];for(const [filename,data]of entries){if(filename.split('/').some(p=>p==='..')||filename.startsWith('/'))throw Error('Invalid ZIP member');const n=Buffer.from(filename),compressed=zlib.deflateRawSync(data,{level:9}),crc=crc32(data),header=Buffer.alloc(30);header.writeUInt32LE(0x04034b50);header.writeUInt16LE(20,4);header.writeUInt16LE(0x800,6);header.writeUInt16LE(8,8);header.writeUInt16LE(0x5821,12);header.writeUInt32LE(crc,14);header.writeUInt32LE(compressed.length,18);header.writeUInt32LE(data.length,22);header.writeUInt16LE(n.length,26);
 const c=Buffer.alloc(46);c.writeUInt32LE(0x02014b50);c.writeUInt16LE(20,4);c.writeUInt16LE(20,6);c.writeUInt16LE(0x800,8);c.writeUInt16LE(8,10);c.writeUInt16LE(0x5821,14);c.writeUInt32LE(crc,16);c.writeUInt32LE(compressed.length,20);c.writeUInt32LE(data.length,24);c.writeUInt16LE(n.length,28);c.writeUInt32LE(offset,42);blocks.push(header,n,compressed);central.push(c,n);offset+=header.length+n.length+compressed.length;
 }const directory=Buffer.concat(central),end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(entries.length,8);end.writeUInt16LE(entries.length,10);end.writeUInt32LE(directory.length,12);end.writeUInt32LE(offset,16);const data=Buffer.concat([...blocks,directory,end]);fs.writeFileSync(path.join(out,name),data);
 for(const alg of ['sha1','sha256'])fs.writeFileSync(path.join(out,name+'.'+alg),crypto.createHash(alg).update(data).digest('hex')+'  '+name+'\n');return {name,bytes:data.length,sha1:crypto.createHash('sha1').update(data).digest('hex')};
}
const notices=[...['LICENSING.md','UPSTREAM-LICENSE.md','HEPHAESTUS-LICENSE.txt'].map(n=>[n,fs.readFileSync(path.join(root,n))]),...walk(path.join(root,'third-party-licenses'),'third-party-licenses/')];
const pack=zip(`Create-Astral-2.1.5b-Japanese-v${version}.zip`,[...walk(path.join(root,'resourcepack')),...notices]);
zip(`Create-Astral-2.1.5b-Japanese-Menu-v${version}.zip`,[...walk(path.join(root,'client-overlay')),...notices]);
const url=`https://github.com/g-kari/create-astral-ja/releases/download/v${version}/`+pack.name;
fs.writeFileSync(path.join(out,'server-resource-pack.properties'),`# Merge these entries with server.properties; restart the server when appropriate.\nresource-pack=${url}\nresource-pack-sha1=${pack.sha1}\nrequire-resource-pack=false\nresource-pack-prompt={"text":"Create: Astral Japanese translation"}\n`);
fs.writeFileSync(path.join(out,'verification.json'),JSON.stringify({...check,pack},null,2)+'\n');console.log(JSON.stringify({...check,pack},null,2));
