#!/usr/bin/env node
const fs = require("fs");
const path = require("path");

async function asyncFilter(arr, pred) {
    const filtered = [];
    for (const elem of arr) {
        if (await pred(elem)) {
            filtered.push(elem);
        }
    }
    return filtered;
}

// Get a list of all _unmanaged_ files in node_modules.
// This means every file in node_modules that is _not_ a symlink to the Nix store.
async function getUnmanagedFiles(storePrefix) {
  const files = await fs.promises.readdir("node_modules");

  return await asyncFilter(files, async file => {
    const filePath = path.join("node_modules", file);

    // Is file a symlink
    const stat = await fs.promises.lstat(filePath);
    if (!stat.isSymbolicLink()) {
      return true;
    }

    // Is file in the store
    const linkTarget = await fs.promises.readlink(filePath);
    return ! linkTarget.startsWith(storePrefix);
  });
}

async function main() {
  const args = process.argv.slice(2);
  const storePrefix = args[0];
  const sourceModules = args[1];

  // Ensure node_modules exists
  try {
    await fs.promises.mkdir("node_modules");
  } catch(err) {
    if (err.code !== "EEXIST") {
      throw err;
    }
  }

  // Get deny list of files that we don't manage.
  // We do manage nix store symlinks, but not other files.
  // For example: If a .vite was present in both our
  // source node_modules and the non-store node_modules we don't want to overwrite
  // the non-store one.
  const unmanaged = await getUnmanagedFiles(storePrefix);

  const sourceFiles = await fs.promises.readdir(sourceModules);
  await Promise.all(sourceFiles.map(async file => {
    const sourcePath = path.join(sourceModules, file);
    const targetPath = path.join("node_modules", file);

    // Skip file if it's not a symlink to a store path
    if (unmanaged.includes(file)) {
      console.log(`Cowardly refusing to link {file}`);
      return;
    }

    // Link to a temporary dummy path and rename.
    // This is to get some degree of atomicity.
    await fs.promises.symlink(sourcePath, targetPath + "-nix-hook-temp");
    await fs.promises.rename(targetPath + "-nix-hook-temp", targetPath);
  }));
}

main();
