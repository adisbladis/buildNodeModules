{
  description = "A very basic flake";

  inputs = {
    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-unit }:
    let
      inherit (nixpkgs) lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      inherit (pkgs) fetchurl;

      system = "x86_64-linux";
    in
    {
      libTests =
        let
          fixture = lib.importJSON ./fixtures/kitchen_sink/package-lock.json;
          getModule = mod: fixture.packages.${mod};
          inherit (builtins) typeOf baseNameOf elemAt match;

          projectRoot = ./fixtures/kitchen_sink;

          fetchModule = module: (
            if module ? "link" then {
              outPath = projectRoot + "/${module.resolved}";
            }
            else if module ? "resolved" then
              (
                let
                  # Parse scheme from URL
                  mUrl = match "(.+)://(.+)" module.resolved;
                  scheme = elemAt mUrl 0;
                in
                assert mUrl != null; (
                  if (scheme == "http" || scheme == "https") then
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
                  else throw "Unsupported URL scheme '${scheme}' in URL '${module.resolved}'"
                )
              )
            else throw "Module could not be fetched. Module has neither path dependency or URL."
          );

        in
        {
          testHttp = {
            expr =
              let
                src = fetchModule (getModule "node_modules/accepts");
              in
              {
                inherit (src) url outputHash;
              };
            expected = {
              outputHash = "sha512-PYAthTa2m2VKxuvSD3DPC/Gy+U+sOA1LAuT8mkmRuvw+NACSaeXEQ+NHcVF7rONl6qcaxV3Uuemwawk+7+SJLw==";
              url = "https://registry.npmjs.org/accepts/-/accepts-1.3.8.tgz";
            };
          };

          testGit = {
            expr =
              let
                src = fetchModule (getModule "node_modules/node-fetch");
              in
              {
                inherit (src) rev submodules;
              };
            expected = {
              rev = "8b3320d2a7c07bce4afc6b2bf6c3bbddda85b01f";
              submodules = false;
            };
          };

          testPath = {
            expr =
              let
                src = fetchModule (getModule "node_modules/trivial");
              in
              { type = typeOf src.outPath; base = baseNameOf src.outPath; };
            expected = { type = "path"; base = "trivial"; };
          };
        };

      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [
          pkgs.nodejs
          nix-unit.packages.${system}.default
        ];
      };

    };
}
