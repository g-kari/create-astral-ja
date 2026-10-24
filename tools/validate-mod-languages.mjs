import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

export function validateModLanguages(root, values, signature, sourceRoot) {
  const meta = JSON.parse(fs.readFileSync(path.join(root, 'mod-language-index.json'), 'utf8'));
  const seen = new Set(), sources = new Map(), counts = {};
  for (const row of meta.entries) {
    const id = row.namespace + ':' + row.key, text = values.get(id);
    if (seen.has(id) || typeof text !== 'string' || !/[\u3040-\u30ff\u3400-\u9fff]/.test(text)) throw Error('Missing, duplicate, or untranslated MOD string: ' + id);
    seen.add(id);
    const actual = signature(text);
    for (const [kind, tokens] of Object.entries(row.signature)) {
      if (JSON.stringify([...actual[kind]].sort()) !== JSON.stringify([...tokens].sort())) throw Error('Changed MOD ' + kind + ': ' + id);
    }
    if (!['MIT','CC0-1.0','Unlicense','Apache-2.0','LGPL-3.0-only'].includes(row.license)) throw Error('Unreviewed additional MOD license: ' + id);
    if (row.category === 'description' && /^item\.[^.]+\.[^.]+$|^block\.[^.]+\.[^.]+$/.test(row.key)) throw Error('Item names are outside the new description scope: ' + id);
    if (row.notice && !fs.existsSync(path.join(root, row.notice))) throw Error('Missing source rights notice: ' + id);
    if (row.notice) {
      const notice = fs.readFileSync(path.join(root, row.notice), 'utf8');
      const markers = {'MIT':'Permission is hereby granted, free of charge', 'CC0-1.0':'CC0 1.0', 'Unlicense':'free and unencumbered software', 'Apache-2.0':'Apache License, Version 2.0', 'LGPL-3.0-only':'GNU LESSER GENERAL PUBLIC LICENSE'};
      if (!notice.includes(markers[row.license])) throw Error('License metadata does not match bundled rights notice: ' + id);
    }
    if (sourceRoot) {
      if (!row.sourceFile || row.sourceFile.includes('\\') || path.isAbsolute(row.sourceFile) || row.sourceFile.split('/').some(p => !p || p === '.' || p === '..')) throw Error('Invalid MOD source path');
      if (!sources.has(row.sourceFile)) sources.set(row.sourceFile, JSON.parse(fs.readFileSync(path.join(sourceRoot, row.sourceFile), 'utf8')));
      const source = sources.get(row.sourceFile);
      const original = row.sourcePointer ? row.sourcePointer.slice(1).split('/').reduce((value,key) => value?.[key],source) : source[row.key];
      if (typeof original !== 'string' || crypto.createHash('sha256').update(original).digest('hex') !== row.sourceHash) throw Error('MOD source fingerprint mismatch: ' + id);
    }
    counts[row.mod] = (counts[row.mod] || 0) + 1;
  }
  return {strings: seen.size, counts, sourceVerified: Boolean(sourceRoot)};
}
