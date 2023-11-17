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
      libTests = import ./tests.nix {
        inherit pkgs lib;
        testFunc = x: x; # Don't run runTests, we use nix-unit
      };

      packages.x86_64-linux.default =
        buildNodeModules {
          packageRoot = ./fixtures/kitchen_sink;
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
