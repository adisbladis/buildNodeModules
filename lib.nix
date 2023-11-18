{ lib, pkgs }:

let
  inherit (builtins) match elemAt toJSON removeAttrs;
  inherit (lib) importJSON;
  inherit (pkgs) fetchurl stdenv callPackages;

in
lib.fix (self: {
  # Fetch a module from package-lock.json -> packages
  fetchModule =
    { module
    , packageRoot ? null
    }: (
      if module ? "resolved" then
        (
          let
            # Parse scheme from URL
            mUrl = match "(.+)://(.+)" module.resolved;
            scheme = elemAt mUrl 0;
          in
          (
            if mUrl == null then
              (
                assert packageRoot != null; {
                  # TODO: Verify path is well formed
                  outPath = packageRoot + "/${module.resolved}";
                }
              )
            else if (scheme == "http" || scheme == "https") then
              (
                fetchurl {
                  url = module.resolved;
                  hash = module.integrity;
                }
              )
            else if lib.hasPrefix "git" module.resolved then
              (
                builtins.fetchGit {
                  url = module.resolved;
                }
              )
            else throw "Unsupported URL scheme: ${scheme}"
          )
        )
      else null
    );

  # Build node modules from package.json & package-lock.json
  buildNodeModules =
    { packageRoot ? null
    , package ? importJSON (packageRoot + "/package.json")
    , packageLock ? importJSON (packageRoot + "/package-lock.json")
    , nodejs
    , ...
    }@attrs:
    let
      packageLock' = packageLock // {
        packages =
          lib.mapAttrs
            (_: module:
              let
                src = self.fetchModule {
                  inherit module packageRoot;
                };
              in
              (removeAttrs module [
                "link"
              ]) // lib.optionalAttrs (src != null) {
                resolved = "file:${src}";
              })
            packageLock.packages;
      };

      # Substitute dependency references in package.json with Nix store paths
      packageJSON' = package // {
        dependencies = lib.mapAttrs (name: _: packageLock'.packages.${"node_modules/${name}"}.resolved) package.dependencies;
      };

    in
    stdenv.mkDerivation (removeAttrs attrs [ "packageRoot" "package" "packageLock" "nodejs" ] // {
      pname = "${package.name}-node-modules";
      inherit (package) version;

      nativeBuildInputs = attrs.nativeBuildInputs or [ ] ++ [
        nodejs
        pkgs.gitMinimal
      ];

      env = attrs.env or { } // {
        npm_config_nodedir = pkgs.srcOnly nodejs;
        npm_config_node_gyp = "${nodejs}/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js";
      };

      passAsFile = [ "package" "packageLock" ];
      package = toJSON packageJSON';
      packageLock = toJSON packageLock';

      dontUnpack = true;
      dontBuild = true;

      configurePhase = ''
        runHook preConfigure

        export HOME=$(mktemp -d)
        npm config set offline true
        npm config set progress false

        mkdir $out
        cp "$packagePath" $out/package.json
        cp "$packageLockPath" $out/package-lock.json

        runHook postConfigure
      '';

      installPhase = ''
        runHook preBuild

        cd $out
        npm install
        patchShebangs node_modules
        cd -

        runHook postBuild
      '';
    });

  # Manage node_modules outside of the store with hooks
  hooks = callPackages ./hooks { };
})
