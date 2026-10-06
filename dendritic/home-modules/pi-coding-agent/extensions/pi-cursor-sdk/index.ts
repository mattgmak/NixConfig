// dist/index.js is built by the package's prepare script on `npm i` (pi-npm-i),
// so it is absent on a fresh clone until deps are installed.
//
// pi-bolt is a compiled bun binary and its extension loader cannot resolve this package's
// bare node_modules deps at runtime (@cursor/sdk, @bufbuild/protobuf), so pi-npm-i also
// builds pi-bolt-bundle.js with those deps inlined. Node hosts keep using dist/.
const isBunHost = typeof (process.versions as { bun?: string }).bun === "string";
const spec: string = isBunHost
  ? "./pi-bolt-bundle.js"
  : "../vendor/fitchmultz/pi-cursor-sdk/dist/index.js";

export default async function (api: unknown) {
  const mod = (await import(spec)) as { default?: unknown };
  const factory = mod.default ?? mod;
  return typeof factory === "function" ? factory(api) : factory;
}
