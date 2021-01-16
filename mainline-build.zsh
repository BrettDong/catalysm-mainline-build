#!/usr/bin/zsh -xe

export CURRENT_BUILD_NUMBER="${UPSTREAM_BUILD_NUMBER}"
if [[ -z "${UPSTREAM_BUILD_NUMBER}" ]]; then
    export CURRENT_BUILD_NUMBER="${BUILD_NUMBER}"
fi

echo "Building ${Platform} ${Graphics} #${CURRENT_BUILD_NUMBER}..."

BUILD_VER=$( git describe --tags --always --dirty --match "[0-9A-Z]*.[0-9A-Z]*" )
MAJOR_VER=$( echo $BUILD_VER | cut -d '-' -f1 )
echo "This build is version ${BUILD_VER}, and the time is $(date)"

if [[ -z "${COMPILE_THREAD_COUNT}" ]]; then
    export COMPILE_THREAD_COUNT="1"
fi

if [[ -z "${CLANG_BINARY}" ]]; then
    export CLANG_BINARY="clang++"
fi

export CXX="g++"
export LD="g++"
export DIST="bindist"
export PACKAGES="cataclysmdda-*"

## Set up environment
case "${Platform}" in
    "Windows")
        PLATFORM="i686-w64-mingw32.static"
        export CROSS="/home/narc/mxe/usr/bin/${PLATFORM}-"
        export NATIVE="win32"
    ;;
    "Windows_x64")
        PLATFORM="x86_64-w64-mingw32.static"
        export CROSS="/home/narc/mxe/usr/bin/${PLATFORM}-"
        export NATIVE="win64"
    ;;
    "Linux")
        export NATIVE="linux32"
        if [[ -z "${USE_GCC}" ]]; then
            export CLANG=1
        fi
    ;;
    "Linux_x64")
        export NATIVE="linux64"
        export CXX="g++-5"
        export LD="g++-5"
    ;;
    "OSX")
        PLATFORM="x86_64-apple-darwin15"
        export CROSS="/usr/local/osxcross/osxcross/target/bin/${PLATFORM}-"
        export OSXCROSS=1
        export NATIVE="osx"
        export OSX_MIN="10.7"
        export USE_HOME_DIR=1
        export DIST="dmgdist"
        export PACKAGES="Cataclysm*.dmg"
        export CLANG=1
        export CXX="clang++"
        export LD="clang++"
        export LIBSDIR=/usr/local/osxcross/libs
    ;;
    "Android")
        export ANDROID_SDK_ROOT=/opt/android-sdk
        export ANDROID_HOME=/opt/android-sdk
        export ANDROID_NDK_ROOT=/opt/android-sdk/ndk-bundle
        export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools
        export PATH=$PATH:$ANDROID_SDK_ROOT/tools
        export PATH=$PATH:$ANDROID_NDK_ROOT
    ;;
esac

case "${Graphics}" in
    # Leaving this as a case, even with just the one. It's easier to expand later this way.
    "Tiles")
        export TILES=1
        export SOUND=1
        if [[ "${Platform}" == "OSX" ]] ; then
            export FRAMEWORK=1
            export FRAMEWORKSDIR=/usr/local/osxcross/Frameworks
        fi;
    ;;
esac

export CCACHE=1
export LUA=1
export LANGUAGES="all"

if [[ -z "${DEBUG}" ]]; then
    export RELEASE=1
else
    export CURRENT_BUILD_NUMBER="${CURRENT_BUILD_NUMBER}-debug"
fi

if [[ "${Platform}" == "Android" ]]; then
    rm -rf android/app/build/outputs/apk/release
    cd android
    ./gradlew clean
    ./gradlew assembleRelease
    cd ..
else
    ${CROSS}${=CXX} --version

    make clean

    ## Compile, ...
    make -j${COMPILE_THREAD_COUNT}

    if [[ "${Platform}" == "Linux" || "${Platform}" == "Linux_x64" ]]; then
        make json-check
    fi

    if [[ -z "${PACKAGE}" ]]; then
        exit 0
    fi

    echo "Pulling translations from Transifex"
    set +x
    tx pull --all --force --minimum-perc 80 --resource cataclysm-dda.master-cataclysm-dda
    set -x

    ## ...package...
    make ${DIST}
fi

## Rename the package for deployment
if [[ "${Platform}" == "OSX" ]] ; then
    mv "Cataclysm.dmg" "Cataclysm-${MAJOR_VER}-${Platform}-${Graphics}-${CURRENT_BUILD_NUMBER}.dmg"
elif [[ "${Platform}" == "Android" ]] ; then
    mv "android/app/build/outputs/apk/release/"*".apk" "Cataclysm-${MAJOR_VER}-${CURRENT_BUILD_NUMBER}.apk"
else
    for D in cataclysmdda-*; do
        S="$D"
        D="${D/%.tar.gz/-${Platform}-${Graphics}-${CURRENT_BUILD_NUMBER}.tar.gz}"
        D="${D/%.zip/-${Platform}-${Graphics}-${CURRENT_BUILD_NUMBER}.zip}"
        mv "$S" "$D"
    done
fi
