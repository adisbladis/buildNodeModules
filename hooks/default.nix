{ callPackage, lib }:
{
  linkNodeModulesHook = callPackage ({
    makeSetupHook,
    nodejs,
  }:
    makeSetupHook {
      name = "node-modules-hook.sh";
      substitutions = {
        nodejs = lib.getExe nodejs;
        script = ./node-modules-hook.js;
        storePrefix = builtins.storeDir;
      };
    } ./node-modules-hook.sh) {};
}
