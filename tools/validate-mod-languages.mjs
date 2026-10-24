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
    if (row.license !== 'MIT') throw Error('Unreviewed additional MOD license: ' + id);
    if (sourceRoot) {
      if (!row.sourceFile || row.sourceFile.includes('\\') || path.isAbsolute(row.sourceFile) || row.sourceFile.split('/').some(p => !p || p === '.' || p === '..')) throw Error('Invalid MOD source path');
      if (!sources.has(row.sourceFile)) sources.set(row.sourceFile, JSON.parse(fs.readFileSync(path.join(sourceRoot, row.sourceFile), 'utf8')));
      const original = sources.get(row.sourceFile)[row.key];
      if (typeof original !== 'string' || crypto.createHash('sha256').update(original).digest('hex') !== row.sourceHash) throw Error('MOD source fingerprint mismatch: ' + id);
    }
    counts[row.mod] = (counts[row.mod] || 0) + 1;
  }
  return {strings: seen.size, counts, sourceVerified: Boolean(sourceRoot)};
}
