import * as esbuild from 'esbuild';
import { rm } from 'fs/promises';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const distDir = join(__dirname, 'dist');

await rm(distDir, { recursive: true, force: true });

const handlers = ['webhook_handler', 'consumer_handler'];

for (const handler of handlers) {
  await esbuild.build({
    entryPoints: [join(__dirname, 'src', `${handler}.mjs`)],
    bundle: true,
    platform: 'node',
    target: 'node22',
    outfile: join(distDir, `${handler}.mjs`),
    format: 'esm',
    banner: {
      js: `
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
      `
    }
  });
}

console.log('Build complete');
