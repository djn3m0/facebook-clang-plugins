#!/bin/bash
set -e

# Simple installation script for llvm/clang.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_RELATIVE_PATH="$(basename "${BASH_SOURCE[0]}")"
CLANG_RELATIVE_SRC="src/clang-snapshot-20-11-15.tar.xz"
CLANG_SRC="$SCRIPT_DIR/$CLANG_RELATIVE_SRC"
CLANG_PATCH="$SCRIPT_DIR/src/AttrDump.inc.patch"
CLANG_PREFIX="$SCRIPT_DIR"
CLANG_INSTALLED_VERSION_FILE="$SCRIPT_DIR/installed.version"

platform=`uname`

if [ $platform == 'Darwin' ]; then
    CONFIGURE_ARGS=(
        --prefix="$CLANG_PREFIX"
        --enable-libcpp
        --enable-cxx11
        --disable-assertions
        --enable-optimized
        --enable-bindings=none
    )
    SHA256SUM="shasum -a 256 -p"
elif [ $platform == 'Linux' ]; then
    CONFIGURE_ARGS=(
        --prefix="$CLANG_PREFIX"
        --enable-cxx11
        --disable-assertions
        --enable-optimized
        --enable-bindings=none
    )
    SHA256SUM="sha256sum"
else
    echo "Clang setup: platform $platform is currently not supported by this script"; exit 1
fi

pushd "$SCRIPT_DIR"
if $SHA256SUM -c "$CLANG_INSTALLED_VERSION_FILE" >& /dev/null; then
    echo "Clang is already installed according to $CLANG_INSTALLED_VERSION_FILE"
    echo "Nothing to do, exiting."
    exit 0
fi
popd

# start the installation
echo "Installing clang..."
TMP=`mktemp -d /tmp/clang-setup.XXXXXX`
pushd "$TMP"

if tar --version | grep -q 'GNU'; then
    # GNU tar is too verbose if the tarball was created on MacOS
    QUIET_TAR="--warning=no-unknown-keyword"
fi
tar --extract $QUIET_TAR --file "$CLANG_SRC"

llvm/configure "${CONFIGURE_ARGS[@]}"

make -j 8 && make install
cp Release/bin/clang "$CLANG_PREFIX/bin/clang"
strip -x "$CLANG_PREFIX/bin/clang"
popd

# AttrDump.inc is autogenerated file so we can't patch it in clang source
pushd $CLANG_PREFIX
patch -p0 -i "$CLANG_PATCH"
popd

rm -rf "$TMP"

pushd "$SCRIPT_DIR"
# remember that we installed this version
$SHA256SUM "$CLANG_RELATIVE_SRC" "$SCRIPT_RELATIVE_PATH" > "$CLANG_INSTALLED_VERSION_FILE"
popd
