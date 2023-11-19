# shellcheck shell=bash

npmConfigHook() {
    echo "Executing npmConfigHook"

    if [ -n "${npmRoot-}" ]; then
      pushd "$npmRoot"
    fi

    echo "Configuring npm"

    export dontNpmPrune=true  # Opt out of pruning behaviour used by fetchNpmDeps
    export HOME="$TMPDIR"
    export npm_config_nodedir="@nodeSrc@"
    export npm_config_node_gyp="@nodeGyp@"
    npm config set offline true
    npm config set progress false

    echo "Installing patched package.json/package-lock.json"

    cp --no-preserve=mode "${nodeModules}/package.json" "package.json"
    cp --no-preserve=mode "${nodeModules}/package-lock.json" "package-lock.json"

    echo "Installing dependencies"

    if ! npm install --ignore-scripts $npmInstallFlags "${npmInstallFlagsArray[@]}" $npmFlags "${npmFlagsArray[@]}"; then
        echo
        echo "ERROR: npm failed to install dependencies"
        echo
        echo "Here are a few things you can try, depending on the error:"
        echo '1. Set `npmFlags = [ "--legacy-peer-deps" ]`'
        echo

        exit 1
    fi

    patchShebangs node_modules

    npm rebuild $npmRebuildFlags "${npmRebuildFlagsArray[@]}" $npmFlags "${npmFlagsArray[@]}"

    patchShebangs node_modules

    # Canonicalize symlinks from relative paths to the Nix store.
    node @canonicalizeSymlinksScript@ @storePrefix@

    if [ -n "${npmRoot-}" ]; then
      popd
    fi

    echo "Finished npmConfigHook"
}

postPatchHooks+=(npmConfigHook)
