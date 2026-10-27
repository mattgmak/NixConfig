// dist/index.js is built by the package's prepare script on `npm i` (pi-ext-deps-install),
// so it is absent on a fresh clone until deps are installed.
//
// pi-bolt is a compiled bun binary and its extension loader cannot resolve this package's
// bare node_modules deps at runtime (@cursor/sdk, @bufbuild/protobuf), so pi-ext-deps-install also
// builds pi-bolt-bundle.js with those deps inlined. Node hosts keep using dist/.
//
// The package build copies pi-bolt-bundle.js into the store loader folder
// (pi-bolt-compiled.nix). A store copy without the bundle stays quiet here instead of
// logging a failed import.
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";

const isBunHost = typeof (process.versions as { bun?: string }).bun === "string";
const spec: string = isBunHost
  ? "./pi-bolt-bundle.js"
  : "../vendor/fitchmultz/pi-cursor-sdk/dist/index.js";

export default async function (api: unknown) {
  if (isBunHost && !existsSync(fileURLToPath(new URL(spec, import.meta.url)))) return;
  const mod = (await import(spec)) as { default?: unknown };
  const factory = mod.default ?? mod;
  return typeof factory === "function" ? factory(api) : factory;
}
