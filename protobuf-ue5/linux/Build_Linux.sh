#!/bin/bash

set -ex

if [[ -z "${PROTOBUF_UE5_VERSION}" ]]; then
  echo "PROTOBUF_UE5_VERSION is not set, exit."
  exit 1
else
  echo "PROTOBUF_UE5_VERSION: ${PROTOBUF_UE5_VERSION}"
fi

if [[ -z "${PROTOBUF_UE5_PREFIX}" ]]; then
  echo "PROTOBUF_UE5_PREFIX is not set, exit."
  exit 1
else
  echo "PROTOBUF_UE5_PREFIX: ${PROTOBUF_UE5_PREFIX}"
fi

if [[ -z "${UE5_CLANG_VERSION}" ]]; then
  echo "UE5_CLANG_VERSION is not set, exit."
  exit 1
else
  echo "UE5_CLANG_VERSION: ${UE5_CLANG_VERSION}"
fi

if [[ -z "${UE5_ZLIB_VERSION}" ]]; then
  echo "UE5_ZLIB_VERSION is not set, exit."
  exit 1
else
  echo "UE5_ZLIB_VERSION: ${UE5_ZLIB_VERSION}"
fi

if [[ -z "${UE5_ROOT}" ]]; then
  echo "UE5_ROOT is not set, exit."
  exit 1
else
  echo "UE5_ROOT: ${UE5_ROOT}"
fi

if [[ -d "${UE5_ROOT}" ]]; then
  echo "ok: UE5_ROOT exist."
else
  echo "error: UE5_ROOT no exist."
  exit 1
fi

echo "MYCFLAGS: ${MYCFLAGS}"
echo "MYLDFLAGS: ${MYLDFLAGS}"

# protobuf
readonly PROTOBUF_URL=https://github.com/google/protobuf/releases/download/v${PROTOBUF_UE5_VERSION}/protobuf-cpp-${PROTOBUF_UE5_VERSION}.tar.gz
readonly PROTOBUF_DIR=protobuf-${PROTOBUF_UE5_VERSION}
readonly PROTOBUF_TAR=${PROTOBUF_DIR}.tar.gz

readonly UE5_CLANG_ROOT="${UE5_ROOT}/Engine/Extras/ThirdPartyNotUE/SDKs/HostLinux/Linux_x64/${UE5_CLANG_VERSION}/x86_64-unknown-linux-gnu"
readonly UE5_LIBCXX_ROOT="${UE5_ROOT}/Engine/Source/ThirdParty/Unix/LibCxx"
readonly UE5_ZLIB_DIR="${UE5_ROOT}/Engine/Source/ThirdParty/zlib/${UE5_ZLIB_VERSION}/lib/Unix/x86_64-unknown-linux-gnu"

if [[ -d "${UE5_CLANG_ROOT}" ]]; then
  echo "ok: UE5_CLANG_ROOT: ${UE5_CLANG_ROOT} exist."
else
  echo "error: UE5_CLANG_ROOT: ${UE5_CLANG_ROOT} no exist."
  exit 1
fi

if [[ -d "${UE5_LIBCXX_ROOT}" ]]; then
  echo "ok: UE5_LIBCXX_ROOT: ${UE5_LIBCXX_ROOT} exist."
else
  echo "error: UE5_LIBCXX_ROOT: ${UE5_LIBCXX_ROOT} no exist."
  exit 1
fi

if [[ -d "${UE5_ZLIB_DIR}" ]]; then
  echo "ok: UE5_ZLIB_DIR: ${UE5_ZLIB_DIR} exist."
else
  echo "error: UE5_ZLIB_DIR: ${UE5_ZLIB_DIR} no exist."
  exit 1
fi

mkdir -p "${PROTOBUF_UE5_PREFIX}"

echo "Downloading: ${PROTOBUF_URL}"
wget -q -O ${PROTOBUF_TAR} ${PROTOBUF_URL}
tar zxf ${PROTOBUF_TAR}

# using UE5 toolchain clang
export CC="${UE5_CLANG_ROOT}/bin/clang --sysroot=${UE5_CLANG_ROOT}"
export CXX="${UE5_CLANG_ROOT}/bin/clang++ --sysroot=${UE5_CLANG_ROOT}"

# the LLVM linker
export CFLAGS="-fuse-ld=lld ${MYCFLAGS}"

export CXXFLAGS="-fPIC                    \
  -O2                                     \
  -DNDEBUG                                \
  -Wno-unused-command-line-argument       \
  -nostdinc++                             \
  -I${UE5_LIBCXX_ROOT}/include            \
  -I${UE5_LIBCXX_ROOT}/include/c++/v1     \
  ${CFLAGS}"

# (1) for libc++.a  libc++abi.a
# (2) for libz.a
# (3) -L for lib*.a
# (4) -B This option specifies where to find the executables, libraries, include files, and data files of the compiler itself.
export LDFLAGS="-L${UE5_LIBCXX_ROOT}/lib/Unix/x86_64-unknown-linux-gnu \
  -L${UE5_ZLIB_DIR}                                                     \
  -L${UE5_CLANG_ROOT}/usr/lib64                                         \
  -B${UE5_CLANG_ROOT}/usr/lib64                                         \
  ${MYLDFLAGS}"

# for clang
export LIBS="-lc++ -lc++abi"

pushd ${PROTOBUF_DIR}
  ./autogen.sh
  ./configure                               \
    --disable-shared                        \
    --disable-debug                         \
    --disable-dependency-tracking           \
    --prefix="${PROTOBUF_UE5_PREFIX}"

  make -j$(nproc)
  make check
  make install

  objdump -h "${PROTOBUF_UE5_PREFIX}/lib/libprotobuf.a" | head -n 25
popd

