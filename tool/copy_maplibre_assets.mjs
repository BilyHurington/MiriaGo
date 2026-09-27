import { copyFile, mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const source = join(root, 'node_modules', 'maplibre-gl', 'dist');
const destination = join(root, 'web', 'vendor', 'maplibre-gl');

await mkdir(destination, { recursive: true });
for (const file of ['maplibre-gl.js', 'maplibre-gl.css', 'LICENSE.txt']) {
  await copyFile(join(source, file), join(destination, file));
}
