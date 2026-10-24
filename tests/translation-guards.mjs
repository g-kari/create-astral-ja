import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {root, signature} from '../tools/validate.mjs';
import {validateModLanguages} from '../tools/validate-mod-languages.mjs';
import {validateLegacyBooks} from '../tools/validate-legacy-books.mjs';

const values = new Map();
for (const ns of fs.readdirSync(path.join(root, 'resourcepack/assets'))) {
  const lang = JSON.parse(fs.readFileSync(path.join(root, 'resourcepack/assets', ns, 'lang/ja_jp.json'), 'utf8'));
  for (const [key, text] of Object.entries(lang)) values.set(ns + ':' + key, text);
}
const variable = [...values].find(([key,text]) => key.startsWith('yigd:') && text.includes('${owner.name}'));
assert.ok(variable, 'Expected a grave-owner template to exercise the guard');
values.set(variable[0], variable[1].replace('${owner.name}', '${owner.nom}'));
assert.throws(() => validateModLanguages(root, values, signature), /Changed MOD variables/);

const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'create-astral-ja-guards-'));
try {
  fs.cpSync(path.join(root, 'legacy-books'), path.join(temp, 'legacy-books'), {recursive:true});
  const manifestFile = path.join(temp, 'legacy-books/legacy-book-index.json');
  const original = fs.readFileSync(manifestFile, 'utf8');
  const run = (predicate, mutate, message) => {
    const meta = JSON.parse(original);
    const file = meta.books.flatMap(book => book.files.map(file => ({book,file}))).find(predicate);
    assert.ok(file, 'Expected an appropriate book page');
    const payload = path.join(temp, 'legacy-books/payload', file.book.mod, file.file.path);
    const saved = fs.readFileSync(payload);
    try {
      const data = JSON.parse(saved); mutate(data, file.file);
      const raw = JSON.stringify(data); fs.writeFileSync(payload, raw);
      file.file.sha256 = crypto.createHash('sha256').update(raw).digest('hex');
      fs.writeFileSync(manifestFile, JSON.stringify(meta));
      assert.throws(() => validateLegacyBooks(temp), message);
    } finally {fs.writeFileSync(payload, saved); fs.writeFileSync(manifestFile, original);}
  };
  run(({file}) => file.path.includes('/entries/'), data => {data.category='wrong:category';}, /Changed legacy book recipe\/image\/link structure/);
  run(({file}) => file.fields.some(field => field.macros.length), (data,file) => {
    const field=file.fields.find(field=>field.macros.length), keys=field.pointer.slice(1).split('/');
    let target=data; for(const key of keys.slice(0,-1)) target=target[key];
    target[keys.at(-1)]=target[keys.at(-1)].replace(field.macros[0],'');
  }, /Changed Patchouli macro/);
  validateLegacyBooks(temp);
  console.log('PASS: owner placeholders, book links/structure and Patchouli macros reject corruption.');
} finally {
  const parent=path.resolve(os.tmpdir()), resolved=path.resolve(temp);
  if(path.dirname(resolved)!==parent || !path.basename(resolved).startsWith('create-astral-ja-guards-')) throw Error('Unexpected cleanup path');
  fs.rmSync(resolved,{recursive:true,force:true});
}
