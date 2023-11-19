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

  npmConfigHook = makeSetupHook
    {
      name = "npm-config-hook";
      substitutions = {
        nodeSrc = srcOnly nodejs;
        nodeGyp = "${nodejs}/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js";
        canonicalizeSymlinksScript = ./canonicalize-symlinks.js;
        storePrefix = builtins.storeDir;
      };
    } ./npm-config-hook.sh;
}
