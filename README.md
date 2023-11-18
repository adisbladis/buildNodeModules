# buildNodeModules

The dumbest node to Nix packaging solution yet!

## How it works

- Map over package-lock.json packages, invoke correct fetcher

- Update package.json & package-lock.lock to point to store paths
URLs are rewritten to `file:...` dependencies that link to the Nix store.

- Run `npm install`

## Usage

``` nix
stdenv.mkDerivation {
  pname = "my-website";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [
    buildNodeModules.hooks.linkNodeModulesHook
    nodejs
  ];

  nodeModules = buildNodeModules.buildNodeModules {
    packageRoot = ./.;
    inherit nodejs;
  };

  buildPhase = ''
    npm run build
  '';

  installPhase = ''
    cp -r dist $out
  '';
}
```
