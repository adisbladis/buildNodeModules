{ lib, pkgs }:

let
  inherit (builtins) match elemAt;
  inherit (pkgs) fetchurl;

in
lib.fix (self: {

  # Fetch a module from package-lock.json -> packages
  fetchModule = {
    module,
    projectRoot ? null
  }: (
    if module ? "resolved" then
      (
        let
          # Parse scheme from URL
          mUrl = match "(.+)://(.+)" module.resolved;
          scheme = elemAt mUrl 0;
        in
        (
          if mUrl == null then (assert projectRoot != null; {
            # TODO: Verify path is well formed
            outPath = projectRoot + "/${module.resolved}";
          })
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

  buildNodeModules = {
    projectRoot ? null,
    package ? lib.importJSON (projectRoot + "/package.json"),
    packageLock ? lib.importJSON (projectRoot + "/package-lock.json"),
    nodejs,
  }:
  let
    packageLock' = packageLock // {
      packages =
        lib.mapAttrs (_: module: let
          src = self.fetchModule {
            inherit module projectRoot;
          };
        in (builtins.removeAttrs module [
          "link"
        ]) // lib.optionalAttrs (src != null) {
          resolved = "file:${src}";
      }) packageLock.packages;
    };

    packageJSON' = package // {
      dependencies = lib.mapAttrs (name: _: packageLock'.packages.${"node_modules/${name}"}.resolved) package.dependencies;
    };

  in
  pkgs.runCommand "node-modules" {
    nativeBuildInputs = [
      nodejs
      pkgs.git
    ];
    passAsFile = [ "package" "packageLock" ];
    package = builtins.toJSON packageJSON';
    packageLock = builtins.toJSON packageLock';
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
