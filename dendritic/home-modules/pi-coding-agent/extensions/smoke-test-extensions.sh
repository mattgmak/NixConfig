#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "Testing pi-lens builder parse..."
node --check vendor/mattgmak/pi-lens/clients/review-graph/builder.ts

echo "Testing pi-permission-system imports SDK getPackageDir..."
node --input-type=module <<'EOF'
const fs = await import('node:fs');
const src = fs.readFileSync('vendor/gotgenes/pi-packages/packages/pi-permission-system/src/index.ts', 'utf8');
if (!src.includes('import { getAgentDir, getPackageDir }')) {
  throw new Error('vendor pi-permission-system should import getPackageDir from SDK');
}
if (src.includes('function getPackageDir()')) {
  throw new Error('vendor pi-permission-system should not use local getPackageDir shim');
}
console.log('permission-system imports ok');
EOF

echo "Testing pi-cursor-sdk dist (built by pi-npm-i prepare)..."
test -f vendor/fitchmultz/pi-cursor-sdk/dist/index.js
node --check vendor/fitchmultz/pi-cursor-sdk/dist/index.js
echo "pi-cursor-sdk dist ok"

echo "Testing pi-agent-browser-native dist (built by pi-npm-i)..."
test -f vendor/fitchmultz/pi-agent-browser-native/dist/extensions/agent-browser/index.js
node --check vendor/fitchmultz/pi-agent-browser-native/dist/extensions/agent-browser/index.js
echo "pi-agent-browser-native dist ok"

echo "All extension smoke tests passed"
