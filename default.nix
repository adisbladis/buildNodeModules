{ lib, pkgs }:

let
  inherit (builtins) match elemAt toJSON removeAttrs;
  inherit (lib) importJSON mapAttrs;
  inherit (pkgs) fetchurl stdenv callPackages runCommand;

  matchGitHubReference = match "github(.com)?:.+";

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

  fetchNodeModules =
    { packageRoot ? null
    , package ? importJSON (packageRoot + "/package.json")
    , packageLock ? importJSON (packageRoot + "/package-lock.json")
    , pname ? package.name or "unknown"
    , version ? package.version or "0.0.0"
    }:
    let
      packageLock' = packageLock // {
        packages =
          mapAttrs
            (_: module:
              let
                src = self.fetchModule {
                  inherit module packageRoot;
                };
              in
              (removeAttrs module [
                "link"
                "funding"
              ]) // lib.optionalAttrs (src != null) {
                resolved = "file:${src}";
              } // lib.optionalAttrs (module ? dependencies) {
                dependencies = mapAttrs
                  (name: version: (
                    # If the version is `latest` substitute the constraint with the
                    # version of the dependency from the top-level of package-lock.
                    if version == "latest" then packageLock'.packages.${"node_modules/${name}"}.version
                    # If the version is a github reference rewrite it with the version
                    # of the dependency from the top-level of package-lock.
                    else if matchGitHubReference version != null then packageLock'.packages.${"node_modules/${name}"}.version
                    # Regular version constraint
                    else version
                  ))
                  module.dependencies;
              })
            packageLock.packages;
      };

      # Substitute dependency references in package.json with Nix store paths
      packageJSON' = package // {
        dependencies = mapAttrs (name: _: packageLock'.packages.${"node_modules/${name}"}.resolved) package.dependencies;
      } // lib.optionalAttrs (package ? devDependencies) {
        devDependencies = mapAttrs (name: _: packageLock'.packages.${"node_modules/${name}"}.resolved) package.devDependencies;
      };

      pname = package.name or "unknown";

    in
    runCommand "${pname}-${version}-sources"
      {
        inherit pname version;

        passAsFile = [ "package" "packageLock" ];

        package = toJSON packageJSON';
        packageLock = toJSON packageLock';
      } ''
      mkdir $out
      cp "$packagePath" $out/package.json
      cp "$packageLockPath" $out/package-lock.json
    '';

  # Build node modules from package.json & package-lock.json
  buildNodeModules =
    { packageRoot ? null
    , package ? importJSON (packageRoot + "/package.json")
    , packageLock ? importJSON (packageRoot + "/package-lock.json")
    , nodejs
    , ...
    }@attrs:
    stdenv.mkDerivation (removeAttrs attrs [ "packageRoot" "package" "packageLock" "nodejs" ] // {
      pname = "${package.name}-node-modules";
      inherit (package) version;

      dontUnpack = true;

      nodeModules = self.fetchNodeModules {
        inherit packageRoot package packageLock;
      };

      nativeBuildInputs = [
        nodejs
        nodejs.passthru.python
        self.hooks.npmConfigHook
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
        mv node_modules $out/
        runHook postInstall
      '';
    });

  # Manage node_modules outside of the store with hooks
  hooks = callPackages ./hooks { };
})
