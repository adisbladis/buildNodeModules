{
  description = "buildNodeModules - The dumbest way to build NodeJS yet!";

  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      lib = lib.listToAttrs (map (system: lib.nameValuePair system (
        import ./. {
          inherit lib;
          pkgs = nixpkgs.legacyPackages.${system};
        }
      )) lib.systems.flakeExposed);

      checks.x86_64-linux.default =
        self.lib.x86_64-linux.buildNodeModules {
          packageRoot = ./fixtures/kitchen_sink;
          nodejs = pkgs.nodejs;
        };

      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [
          pkgs.nodejs
        ];
      };
    };
}
