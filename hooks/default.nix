{ callPackage, lib,  makeSetupHook, srcOnly, nodejs }:
{
  linkNodeModulesHook = makeSetupHook {
      name = "node-modules-hook.sh";
      substitutions = {
        nodejs = lib.getExe nodejs;
        script = ./link-node-modules.js;
        storePrefix = builtins.storeDir;
      };
    } ./link-node-modules-hook.sh;
}
