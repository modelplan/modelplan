// SPDX-License-Identifier: MIT
import { defineConfig } from '../../cockpit/node_modules/@playwright/test/index.mjs';
import { fileURLToPath } from 'node:url';
export default defineConfig({
  testDir:fileURLToPath(new URL('./browser',import.meta.url)),
  outputDir:fileURLToPath(new URL('../../cockpit/.tmp/test-results',import.meta.url)),
  snapshotPathTemplate:fileURLToPath(new URL('../../official-visuals/cockpit-baselines/{projectName}/{arg}{ext}',import.meta.url)),
  fullyParallel:false,workers:1,retries:0,timeout:30000,
  projects:[{name:`webkit-linux-${process.arch}`,use:{browserName:'webkit',viewport:{width:636,height:890},deviceScaleFactor:1}}],
  use:{baseURL:'http://127.0.0.1:41783',headless:true},
  webServer:{command:`node ${fileURLToPath(new URL('./serve.mjs',import.meta.url))}`,url:'http://127.0.0.1:41783',reuseExistingServer:false},
});
