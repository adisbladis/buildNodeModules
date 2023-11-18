{ callPackage, lib,  makeSetupHook, srcOnly, nodejs }:
{
  linkNodeModulesHook = makeSetupHook {
      name = "node-modules-hook.sh";
      substitutions = {
        nodejs = lib.getExe nodejs;
        script = ./node-modules-hook.js;
        storePrefix = builtins.storeDir;
      };
    } ./node-modules-hook.sh;

  npmConfigHook = makeSetupHook
    {
      name = "npm-config-hook";
      substitutions = {
        nodeSrc = srcOnly nodejs;
        nodeGyp = "${nodejs}/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js";
      };
    } ./npm-config-hook.sh;
}
