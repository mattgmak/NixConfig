#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "Testing pi-lens builder parse..."
node --check vendor/pi-lens/clients/review-graph/builder.ts

echo "Testing pi-permission-system imports SDK getPackageDir..."
node --input-type=module <<'EOF'
const fs = await import('node:fs');
const src = fs.readFileSync('vendor/pi-packages/packages/pi-permission-system/src/index.ts', 'utf8');
if (!src.includes('import { getAgentDir, getPackageDir }')) {
  throw new Error('vendor pi-permission-system should import getPackageDir from SDK');
}
if (src.includes('function getPackageDir()')) {
  throw new Error('vendor pi-permission-system should not use local getPackageDir shim');
}
console.log('permission-system imports ok');
EOF

echo "All extension smoke tests passed"
