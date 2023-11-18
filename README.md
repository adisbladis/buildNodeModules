# buildNodeModules

The dumbest node to Nix packaging solution yet!

## How it works

### How node_modules is built

- Map over package-lock.json packages, invoke correct fetcher

- Update package.json & package-lock.lock to point to store paths
URLs are rewritten to `file:...` dependencies that link to the Nix store.

- Run `npm install`

### How node_modules is linked
Our configure/shell hook links individual directories inside the Nix built `node_modules` directory.
This is to work around issues like https://github.com/nix-community/npmlock2nix/issues/86 and that tools like `vite` expects a writable node_modules.

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
