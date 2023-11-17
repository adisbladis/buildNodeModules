{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
, testFunc ? lib.debug.runTests
}:
let
  inherit (import ./lib.nix { inherit pkgs lib; }) fetchModule;

  fixture = lib.importJSON ./fixtures/kitchen_sink/package-lock.json;
  getModule = mod: fixture.packages.${mod};
  packageRoot = ./fixtures/kitchen_sink;
  inherit (builtins) typeOf baseNameOf;

in
testFunc {
  testFetchHttp = {
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

  testFetchGit = {
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

  testFetchPath = {
    expr =
      let
        src = fetchModule {
          module = getModule "node_modules/trivial";
          inherit packageRoot;
        };
      in
      builtins.trace src.outPath ({ type = typeOf src.outPath; base = baseNameOf src.outPath; });
    expected = { type = "path"; base = "trivial"; };
  };
}
