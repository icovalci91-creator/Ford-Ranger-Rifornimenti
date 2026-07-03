// Impacchetta la webapp (cartella padre) in www/ per Capacitor.
import { cpSync, rmSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const www = join(here, 'www');

const files = ['index.html', 'logo.png', 'apple-touch-icon.png', 'preload_bimestri.json'];

rmSync(www, { recursive: true, force: true });
mkdirSync(www, { recursive: true });
for (const f of files) {
  cpSync(join(root, f), join(www, f));
  console.log('copiato', f);
}
console.log('www/ pronta');
