import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {validateBook} from './validate-book.mjs';
export const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const stable=a=>JSON.stringify([...a].sort());
export function signature(s){return {
  formats:s.match(/%(?:\d+\$)?[sdif]|%%/g)||[],
  colors:(s.match(/[&§][0-9a-fk-or]/gi)||[]).map(x=>x.toLowerCase()),
  urls:s.match(/https?:\/\/[^\s&]+/g)||[],
  references:s.match(/\$[a-z_]+(?::[a-z_]+)?(?:\/[a-z_]+)*|#[a-z_]+:[a-z_]+/g)||[],
};}
export function validate(sourceRoot,bookSourceRoot){
 const index=read(path.join(root,'translation-index.json')),meta=read(path.join(root,'pack-source.json'));
 const bookMeta=read(path.join(root,'book-index.json'));
 const assets=path.join(root,'resourcepack/assets'),values=new Map();
 for(const ns of fs.readdirSync(assets)){
  if(!/^[a-z0-9_]+$/.test(ns))throw Error('Invalid namespace '+ns);
  const file=path.join(assets,ns,'lang/ja_jp.json'),raw=fs.readFileSync(file,'utf8');if(raw.charCodeAt(0)===0xfeff)throw Error('BOM: '+ns);
  const keyLines=[...raw.matchAll(/^\s*"([^"\\]+)":/gm)].map(m=>m[1]);if(new Set(keyLines).size!==keyLines.length)throw Error('Duplicate JSON key: '+ns);
  const obj=JSON.parse(raw);for(const [k,v] of Object.entries(obj)){if(typeof v!=='string'||v.includes('\ufffd')||/[\u0000-\u0008]/.test(v))throw Error('Invalid text: '+k);values.set(ns+':'+k,v);}
 }
 const menu=fs.readFileSync(path.join(root,'client-overlay/config/fancymenu/custom_locals/astralmenu/ja_jp.local'),'utf8');
 for(const line of menu.split(/\r?\n/)){const m=line.match(/^([^=]+?)\s*=\s?(.*)$/);if(m){const k='astralmenu:'+m[1].trim();if(values.has(k))throw Error('Duplicate menu key');values.set(k,m[2]);}}
 const extras=bookMeta.languageEntries.map(row=>row.namespace+':'+row.key);
 if(new Set(extras).size!==extras.length||index.some(row=>extras.includes(row.namespace+':'+row.key)))throw Error('Duplicate book/base language entry');
 if(values.size!==meta.sourceEntries+(meta.additionalEntries||0)+extras.length||index.length+extras.length!==values.size)throw Error('Translation coverage differs from source index');
 const seen=new Set(),english={};
 for(const row of index){const id=row.namespace+':'+row.key;if(seen.has(id))throw Error('Duplicate index key');seen.add(id);if(!values.has(id))throw Error('Missing '+id);const text=values.get(id);
  for(const [kind,tokens]of Object.entries(row.signature))if(stable(signature(text)[kind])!==stable(tokens))throw Error('Changed '+kind+': '+id);
  if(sourceRoot&&row.sourceFile){if(crypto.createHash('sha256').update(fs.readFileSync(path.join(sourceRoot,row.sourceFile))).digest('hex')!==row.sourceFileHash)throw Error('Supplemental source mismatch');}
  else if(sourceRoot&&row.namespace==='astralmenu'){
   const raw=fs.readFileSync(path.join(sourceRoot,'config/fancymenu/custom_locals/astralmenu/en_us.local'),'utf8');const lines=Object.fromEntries(raw.split(/\r?\n/).map(s=>s.match(/^([^=]+?)\s*=\s?(.*)$/)).filter(Boolean).map(m=>[m[1].trim(),m[2]]));if(crypto.createHash('sha256').update(lines[row.key]).digest('hex')!==row.sourceHash)throw Error('Menu source mismatch: '+id);
  }else if(sourceRoot){
   const ns=row.namespace;if(!english[ns])english[ns]=read(path.join(sourceRoot,'kubejs/assets',ns,'lang/en_us.json'));
   const original=english[ns][row.key];if(typeof original!=='string'||crypto.createHash('sha256').update(original).digest('hex')!==row.sourceHash)throw Error('Source mismatch: '+id);
  }
 }
 if(read(path.join(root,'resourcepack/pack.mcmeta')).pack.pack_format!==8)throw Error('Expected 1.18 resource format 8');
 const book=validateBook(root,values,bookSourceRoot);
 const result={status:'PASS',total:values.size+book.strings,resourceStrings:meta.resourceEntries,menuStrings:meta.menuEntries,book,namespaces:fs.readdirSync(assets).length,checks:['UTF-8 JSON/menu syntax','complete source-index coverage','format arguments','formatting codes','URLs and tag/search references','book recipe/item/NBT/layout structure','complete book JSON and section labels','source fingerprints'+(sourceRoot?' checked against local upstream files':' retained in index')],inGameVerified:false};
 return result;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))console.log(JSON.stringify(validate(process.argv[2],process.argv[3]),null,2));
