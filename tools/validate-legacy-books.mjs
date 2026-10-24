import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const hash = data => crypto.createHash('sha256').update(data).digest('hex');
const read = file => {
  const raw = new TextDecoder('utf-8', {fatal: true}).decode(fs.readFileSync(file));
  if (/[\u0000-\u0008\ufffd]/.test(raw)) throw Error('Invalid legacy book encoding');
  return {raw, data: JSON.parse(raw)};
};
const macros = text => (text.match(/\$\([^)]*\)|\/\$|@[a-z_]+@|@!/g) || []).sort();
const safe = relative => {
  if (path.isAbsolute(relative) || relative.includes('\\') || relative.split('/').some(p => !p || p === '.' || p === '..')) throw Error('Unsafe legacy book path');
  return relative;
};
function walk(dir, prefix = '') {
  return fs.readdirSync(dir, {withFileTypes: true}).flatMap(e => {
    if (e.isSymbolicLink()) throw Error('No legacy book symlinks');
    return e.isDirectory() ? walk(path.join(dir, e.name), prefix + e.name + '/') : [prefix + e.name];
  });
}
export function validateLegacyBooks(root, sourceRoot) {
  const base = path.join(root, 'legacy-books'), meta = read(path.join(base, 'legacy-book-index.json')).data;
  if (meta.schema !== 1 || meta.minecraft !== '1.18.2') throw Error('Invalid legacy book manifest');
  const expected = [], books = [], ids = new Set();
  for (const book of meta.books) {
    if (ids.has(book.id) || !['MIT', 'Apache-2.0'].includes(book.license)) throw Error('Duplicate or unreviewed legacy book');
    ids.add(book.id);
    if (!/^[a-f0-9]{64}$/.test(book.jarSha256)) throw Error('Invalid source JAR hash');
    let strings = 0;
    for (const file of book.files) {
      const name = safe(book.mod + '/' + file.path);
      if (!/^data\/[a-z_]+\/patchouli_books\/[a-z_]+\/ja_jp\/.+\.json$/.test(file.path)) throw Error('Legacy payload must contain only Japanese book JSON');
      expected.push(name);
      const {raw, data} = read(path.join(base, 'payload', name));
      if (hash(raw) !== file.sha256) throw Error('Legacy payload hash mismatch: ' + name);
      let original;
      if (sourceRoot) {
        const source = read(path.join(sourceRoot, safe(file.sourceFile)));
        if (hash(source.raw) !== file.sourceHash) throw Error('Legacy book source hash mismatch: ' + name);
        original = source.data;
      }
      const fields = new Set();
      for (const field of file.fields) {
        if (fields.has(field.pointer) || !/^\/(?:[a-zA-Z0-9_]+\/)*[a-zA-Z0-9_]+$/.test(field.pointer)) throw Error('Invalid legacy text pointer');
        fields.add(field.pointer);
        const keys = field.pointer.slice(1).split('/');
        let container = data, source = original;
        for (const key of keys.slice(0, -1)) {container = container[key]; if (source) source = source[key];}
        const key = keys.at(-1), text = container[key];
        if (typeof text !== 'string' || !/[\u3040-\u30ff\u3400-\u9fff]/.test(text)) throw Error('Missing legacy Japanese text');
        if (JSON.stringify(macros(text)) !== JSON.stringify([...field.macros].sort())) throw Error('Changed Patchouli macro: ' + name + field.pointer);
        if (source && hash(source[key]) !== field.sourceHash) throw Error('Legacy source text changed');
        container[key] = null;
      }
      if (hash(JSON.stringify(data)) !== file.structureHash) throw Error('Changed legacy book recipe/image/link structure: ' + name);
      strings += file.fields.length;
    }
    books.push({id: book.id, files: book.files.length, strings, distribution: 'client JAR translation patch', license: book.license});
  }
  if (new Set(expected).size !== expected.length || JSON.stringify(walk(path.join(base, 'payload')).sort()) !== JSON.stringify(expected.sort())) throw Error('Legacy book file coverage differs');
  return {count: books.length, strings: books.reduce((n,b) => n+b.strings,0), files: expected.length, sourceVerified: Boolean(sourceRoot), books};
}
