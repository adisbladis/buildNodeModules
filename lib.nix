{ lib, pkgs }:

let
  inherit (builtins) match elemAt toJSON removeAttrs;
  inherit (lib) importJSON;
  inherit (pkgs) fetchurl;

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

  buildNodeModules =
    { packageRoot ? null
    , package ? importJSON (packageRoot + "/package.json")
    , packageLock ? importJSON (packageRoot + "/package-lock.json")
    , nodejs
    ,
    }:
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
    pkgs.runCommand "node-modules"
      {
        nativeBuildInputs = [
          nodejs
          pkgs.gitMinimal
        ];

        env.npm_config_nodedir = pkgs.srcOnly nodejs;
        env.npm_config_node_gyp = "${nodejs}/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js";

        passAsFile = [ "package" "packageLock" ];
        package = toJSON packageJSON';
        packageLock = toJSON packageLock';

      } ''
      export HOME=$(mktemp -d)

      mkdir $out
      cd $out

      cp "$packagePath" package.json
      cp "$packageLockPath" package-lock.json

      npm config set offline true
      npm config set progress false

      npm install
    '';

})
