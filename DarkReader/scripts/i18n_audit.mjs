#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const appRoot = path.join(repoRoot, 'DarkReader');
const extensionRoot = path.join(repoRoot, 'DarkReaderExtension');

const localeNames = ['en', 'zh-Hans', 'ja'];
const localeFiles = Object.fromEntries(
  localeNames.map((name) => [name, path.join(appRoot, `${name}.lproj`, 'Localizable.strings')])
);

function readFile(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function parseStringsKeys(filePath) {
  const content = readFile(filePath);
  const keys = new Set();
  const regex = /^\s*"((?:\\.|[^"])*)"\s*=\s*"/gm;
  let match;
  while ((match = regex.exec(content)) !== null) {
    const key = match[1].replace(/\\"/g, '"').replace(/\\n/g, '\n');
    keys.add(key);
  }
  return keys;
}

function listSwiftFiles(dir) {
  const out = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name.endsWith('.lproj') || entry.name === 'build') continue;
      out.push(...listSwiftFiles(fullPath));
      continue;
    }
    if (entry.isFile() && entry.name.endsWith('.swift')) out.push(fullPath);
  }
  return out;
}

function extractRequiredSwiftKeys(swiftContent) {
  const patterns = [
    /Text\("((?:\\.|[^"])*)"/g,
    /Button\("((?:\\.|[^"])*)"/g,
    /\.navigationTitle\("((?:\\.|[^"])*)"/g,
    /\.alert\("((?:\\.|[^"])*)"/g,
    /NSLocalizedString\("((?:\\.|[^"])*)"/g,
    /LocalizedStringKey\("((?:\\.|[^"])*)"/g
  ];

  const keys = new Set();
  for (const regex of patterns) {
    let match;
    while ((match = regex.exec(swiftContent)) !== null) {
      const key = match[1].replace(/\\"/g, '"');
      if (!key.trim()) continue;
      if (key.includes('\\(')) continue;
      if (/^[0-9% ./:_-]+$/.test(key)) continue;
      if (/^[#A-Za-z0-9]+$/.test(key) && key.length <= 2) continue;
      keys.add(key);
    }
  }
  return keys;
}

function hasCJK(text) {
  return /[\u3400-\u9FFF\uF900-\uFAFF]/u.test(text);
}

function flattenObjectKeys(obj, prefix = '') {
  const keys = new Set();
  for (const [k, v] of Object.entries(obj)) {
    const p = prefix ? `${prefix}.${k}` : k;
    if (v && typeof v === 'object' && !Array.isArray(v)) {
      const nested = flattenObjectKeys(v, p);
      for (const key of nested) keys.add(key);
      continue;
    }
    keys.add(p);
  }
  return keys;
}

function parsePopupI18n(popupPath) {
  const content = readFile(popupPath);
  const match = content.match(/const\s+I18N\s*=\s*(\{[\s\S]*?\n\});/);
  if (!match) {
    throw new Error('Failed to locate I18N object in popup.js');
  }
  const i18nObject = vm.runInNewContext(`(${match[1]})`);

  const staticTKeys = new Set();
  const tRegex = /\bt\('([^']+)'\)/g;
  let tMatch;
  while ((tMatch = tRegex.exec(content)) !== null) {
    staticTKeys.add(tMatch[1]);
  }

  return {
    i18nObject,
    staticTKeys
  };
}

let hasError = false;

for (const [locale, filePath] of Object.entries(localeFiles)) {
  if (!fs.existsSync(filePath)) {
    console.error(`[FAIL] Missing locale file: ${path.relative(repoRoot, filePath)}`);
    hasError = true;
  }
}

if (!hasError) {
  const localeKeys = Object.fromEntries(
    Object.entries(localeFiles).map(([locale, filePath]) => [locale, parseStringsKeys(filePath)])
  );

  const requiredSwiftKeys = new Set();
  for (const filePath of listSwiftFiles(appRoot)) {
    const content = readFile(filePath);
    for (const key of extractRequiredSwiftKeys(content)) {
      requiredSwiftKeys.add(key);
    }
  }

  const missingByLocale = {
    en: [],
    'zh-Hans': [],
    ja: []
  };

  for (const key of requiredSwiftKeys) {
    if (!localeKeys.en.has(key)) {
      missingByLocale.en.push(key);
    }

    if (!localeKeys.ja.has(key)) {
      missingByLocale.ja.push(key);
    }

    const zhHas = localeKeys['zh-Hans'].has(key);
    if (!zhHas && !hasCJK(key)) {
      missingByLocale['zh-Hans'].push(key);
    }
  }

  for (const locale of localeNames) {
    if (missingByLocale[locale].length > 0) {
      console.error(`[FAIL] ${locale} missing ${missingByLocale[locale].length} required app keys`);
      for (const key of missingByLocale[locale].slice(0, 30)) {
        console.error(`  - ${key}`);
      }
      if (missingByLocale[locale].length > 30) {
        console.error('  - ...');
      }
      hasError = true;
    }
  }

  const popupPath = path.join(extensionRoot, 'Resources', 'popup.js');
  const { i18nObject, staticTKeys } = parsePopupI18n(popupPath);

  for (const lang of ['zhHans', 'en', 'ja']) {
    if (!(lang in i18nObject)) {
      console.error(`[FAIL] popup.js missing I18N.${lang}`);
      hasError = true;
    }
  }

  if (!hasError) {
    const popupKeySets = {
      zhHans: flattenObjectKeys(i18nObject.zhHans),
      en: flattenObjectKeys(i18nObject.en),
      ja: flattenObjectKeys(i18nObject.ja)
    };

    const baseline = popupKeySets.zhHans;
    for (const lang of ['en', 'ja']) {
      const missing = [...baseline].filter((key) => !popupKeySets[lang].has(key));
      const extra = [...popupKeySets[lang]].filter((key) => !baseline.has(key));

      if (missing.length > 0) {
        console.error(`[FAIL] popup.js ${lang} missing ${missing.length} i18n keys`);
        for (const key of missing.slice(0, 20)) {
          console.error(`  - ${key}`);
        }
        if (missing.length > 20) console.error('  - ...');
        hasError = true;
      }
      if (extra.length > 0) {
        console.error(`[FAIL] popup.js ${lang} has ${extra.length} extra i18n keys not in zhHans baseline`);
        for (const key of extra.slice(0, 20)) {
          console.error(`  - ${key}`);
        }
        if (extra.length > 20) console.error('  - ...');
        hasError = true;
      }
    }

    for (const key of staticTKeys) {
      for (const lang of ['zhHans', 'en', 'ja']) {
        if (!popupKeySets[lang].has(key)) {
          console.error(`[FAIL] popup.js ${lang} missing key referenced by t(): ${key}`);
          hasError = true;
        }
      }
    }
  }
}

if (hasError) {
  process.exit(1);
}

console.log('i18n audit passed: app and popup localization coverage is complete.');
