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

      # TODO: Come up with a name
      selfLib = import ./lib.nix { inherit pkgs lib; };
      inherit (selfLib) fetchModule buildNodeModules;

      system = "x86_64-linux";
    in
    {
      libTests =
        let
          fixture = lib.importJSON ./fixtures/kitchen_sink/package-lock.json;
          getModule = mod: fixture.packages.${mod};
          projectRoot = ./fixtures/kitchen_sink;
          inherit (builtins) typeOf baseNameOf;

        in
        {
          fetchModule = {

            testHttp = {
              expr =
                let
                  src = fetchModule {
                    module = getModule "node_modules/accepts";
                  };
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
                  src = fetchModule {
                    module = getModule "node_modules/node-fetch";
                  };
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
                  src = fetchModule {
                    module = getModule "node_modules/trivial";
                    inherit projectRoot;
                  };
                in
                builtins.trace src.outPath ({ type = typeOf src.outPath; base = baseNameOf src.outPath; });
              expected = { type = "path"; base = "trivial"; };
            };
          };
        };

      packages.x86_64-linux.default =
        buildNodeModules {
          projectRoot = ./fixtures/kitchen_sink;
          nodejs = pkgs.nodejs;
        };

      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [
          pkgs.nodejs
          nix-unit.packages.${system}.default
        ];
      };

    };
}
