{ lib
, stdenv
, fetchNpmLock
, callPackages
}:

let
  inherit (builtins) toJSON removeAttrs;
  inherit (lib) importJSON;

  getName = package: package.name or "unknown";
  getVersion = package: package.version or "0.0.0";

in
{
  # Build node modules from package.json & package-lock.json
  buildNodeModules =
    { npmRoot ? null
    , package ? importJSON (npmRoot + "/package.json")
    , packageLock ? importJSON (npmRoot + "/package-lock.json")
    , nodejs
    , ...
    }@attrs:
    stdenv.mkDerivation (removeAttrs attrs [ "npmRoot" "package" "packageLock" "nodejs" ] // {
      pname = "${getName package}-node-modules";
      version = getVersion package;

      dontUnpack = true;

      npmDeps = fetchNpmLock {
        inherit npmRoot package packageLock;
      };

      nativeBuildInputs = [
        nodejs
        nodejs.passthru.python
        fetchNpmLock.npmConfigHook
      ];

      package = toJSON package;
      packageLock = toJSON packageLock;
      passAsFile = [ "package" "packageLock" ];

      postPatch = ''
        cp --no-preserve=mode "$packagePath" package.json
        cp --no-preserve=mode "$packageLockPath" package-lock.json
      '';

      installPhase = ''
        runHook preInstall
        mkdir $out
        cp package.json $out/
        cp package-lock.json $out/
        [[ -d node_modules ]] && mv node_modules $out/
        runHook postInstall
      '';
    });

  # Manage node_modules outside of the store with hooks
  hooks = callPackages ./hooks { };
}
