linkNodeModulesHook() {
    echo "Executing linkNodeModulesHook"
    runHook preShellHook

    @nodejs@ @script@ @storePrefix@ "${nodeModules}/node_modules"
    if test -f node_modules/.bin; then
        export PATH=$(readlink -f node_modules/.bin):$PATH
    fi

    runHook postShellHook
    echo "Finished executing linkNodeModulesShellHook"
}

if [ -z "${dontLinkNodeModules:-}" ] && [ -z "${shellHook-}" ]; then
    echo "Using linkNodeModulesHook shell hook"
    shellHook=linkNodeModulesHook
fi


if [ -z "${dontLinkNodeModules:-}" ]; then
    echo "Using linkNodeModulesHook preConfigure hook"
    preConfigureHooks+=(linkNodeModulesHook)
fi
