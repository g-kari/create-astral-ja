import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {isDeepStrictEqual} from 'node:util';

const hash = data => crypto.createHash('sha256').update(data).digest('hex');
const readText = file => {
  const text = new TextDecoder('utf-8', {fatal: true, ignoreBOM: true}).decode(fs.readFileSync(file));
  if (text.charCodeAt(0) === 0xfeff || /[\u0000-\u0008\ufffd]/.test(text)) throw Error('Invalid UTF-8 book text: ' + file);
  return text;
};
const readJSON = file => JSON.parse(readText(file));
const sorted = values => [...values].sort();
function checkText(text, signature, id) {
  if (typeof text !== 'string' || !/[\u3040-\u30ff\u3400-\u9fff]/u.test(text)) throw Error('Untranslated book text: ' + id);
  const actual = {
    formats: text.match(/%(?:\d+\$)?[sdif]|%%/g) || [],
    colors: (text.match(/[&§][0-9a-fk-or]/gi) || []).map(x => x.toLowerCase()),
    urls: text.match(/https?:\/\/[^\s&]+/g) || [],
  };
  for (const [kind, tokens] of Object.entries(signature)) {
    if (!isDeepStrictEqual(sorted(actual[kind]), sorted(tokens))) throw Error('Changed book ' + kind + ': ' + id);
  }
}
function lines(text) {
  const result = new Map();
  for (const line of text.split(/\r?\n/)) {
    if (!line.trim() || line.startsWith('#')) continue;
    const delimiter = line.indexOf('=');
    if (delimiter < 1) throw Error('Invalid book language line');
    const key = line.slice(0, delimiter);
    if (result.has(key)) throw Error('Duplicate book label: ' + key);
    result.set(key, line.slice(delimiter + 1));
  }
  return result;
}
function walk(dir, prefix = '') {
  return fs.readdirSync(dir, {withFileTypes: true}).flatMap(entry => {
    if (entry.isSymbolicLink()) throw Error('No symlinks in book');
    const relative = prefix + entry.name;
    return entry.isDirectory() ? walk(path.join(dir, entry.name), relative + '/') : [relative];
  });
}
function safeRelative(name) {
  if (!name || name.includes('\\') || name.split('/').some(part => !part || part === '.' || part === '..') || path.isAbsolute(name)) throw Error('Invalid book path');
  return name;
}
function validateOneBook(root, languageValues, sourceRoot, meta) {
  const directory = path.join(root, 'resourcepack', safeRelative(meta.resourcePath));
  const expected = meta.files.map(file => safeRelative(file.path));
  if (new Set(expected).size !== expected.length || !isDeepStrictEqual(sorted(walk(directory)), sorted(expected))) throw Error('Book file coverage differs from index');
  let strings = 0;
  for (const file of meta.files) {
    const raw = readText(path.join(directory, file.path));
    const source = sourceRoot ? readText(path.join(sourceRoot, safeRelative(meta.sourcePath), file.path)) : null;
    if (source !== null && hash(source) !== file.sourceHash) throw Error('Book source fingerprint mismatch: ' + file.path);
    const seen = new Set();
    if (file.path === 'language.lang') {
      const values = lines(raw), originals = source === null ? null : lines(source);
      if (!isDeepStrictEqual(sorted([...values.keys()]), sorted(file.fields.map(field => field.key)))) throw Error('Book label coverage differs');
      for (const field of file.fields) {
        checkText(values.get(field.key), field.signature, field.key);
        if (originals && hash(originals.get(field.key)) !== field.sourceHash) throw Error('Book label source mismatch');
      }
    } else {
      const obj = JSON.parse(raw), original = source === null ? null : JSON.parse(source);
      for (const field of file.fields) {
        if (seen.has(field.pointer) || !/^\/(?:[A-Za-z0-9_]+\/)*[A-Za-z0-9_]+$/.test(field.pointer)) throw Error('Invalid or duplicate book field');
        seen.add(field.pointer);
        const keys = field.pointer.slice(1).split('/');
        let container = obj, originalContainer = original;
        for (const key of keys.slice(0, -1)) { container = container[key]; if (originalContainer) originalContainer = originalContainer[key]; }
        const key = keys.at(-1);
        checkText(container[key], field.signature, file.path + field.pointer);
        if (originalContainer && hash(originalContainer[key]) !== field.sourceHash) throw Error('Book field source mismatch');
        container[key] = null;
      }
      // Hashing the remaining structure protects recipe IDs, item IDs, NBT,
      // images, layout, paragraph flags, and numeric game values from edits.
      if (hash(JSON.stringify(obj)) !== file.structureHash) throw Error('Changed book structure or gameplay reference: ' + file.path);
    }
    strings += file.fields.length;
  }
  const seenLanguage = new Set();
  for (const row of meta.languageEntries || []) {
    const id = row.namespace + ':' + row.key;
    if (seenLanguage.has(id)) throw Error('Duplicate book item language key');
    seenLanguage.add(id);
    checkText(languageValues.get(id), row.signature, id);
    if (sourceRoot) {
      const original = readJSON(path.join(sourceRoot, 'assets', row.namespace, 'lang/en_us.json'))[row.key];
      if (hash(original) !== row.sourceHash) throw Error('Book item language source mismatch');
    }
  }
  return {id: meta.book, files: expected.length, strings, languageStrings: seenLanguage.size, sourceVerified: Boolean(sourceRoot), coverTranslated: meta.coverTranslated};
}
export function validateBook(root, languageValues, sourceRoot) {
  const meta = readJSON(path.join(root, 'book-index.json'));
  const books = [meta, ...(meta.additionalBooks || [])].map(book => validateOneBook(root, languageValues, sourceRoot, book));
  return {count: books.length, files: books.reduce((n, book) => n + book.files, 0), strings: books.reduce((n, book) => n + book.strings, 0), languageStrings: books.reduce((n, book) => n + book.languageStrings, 0), sourceVerified: Boolean(sourceRoot), books};
}
