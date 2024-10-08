#!/usr/bin/env bash
#
# Copyright (C) 2023 Kneba <abenkenary3@gmail.com>
#

#
# Function to show an informational message
#

msg() {
	echo
    echo -e "\e[1;32m$*\e[0m"
    echo
}

err() {
    echo -e "\e[1;41m$*\e[0m"
}

cdir() {
	cd "$1" 2>/dev/null || \
		err "The directory $1 doesn't exists !"
}

# Main
MainPath="$(pwd)"
MainClangPath="${MainPath}/clang"
ClangPath="${MainClangPath}"
MainGCCaPath="${MainPath}/GCC64"
MainGCCbPath="${MainPath}/GCC32"
GCCaPath="${MainGCCaPath}"
GCCbPath="${MainGCCbPath}"

# Identity
VERSION=4.9.337
KERNELNAME=TheOneMemory
CODENAME=RMX1971
VARIANT=Stable

LINKER=ld.lld

# Show manufacturer info
MANUFACTURERINFO="Realme Computer Inc."

# Clone Kernel Source
git clone --depth=1 https://github.com/strongreasons/android_kernel_realme_sdm710 kernel

# Clone Toolchain
ClangPath=${MainClangPath}
[[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
mkdir $ClangPath
rm -rf $ClangPath/*
msg "|| Cloning sdclang toolchain ||"
git clone --depth=1 https://github.com/kdrag0n/proton-clang $ClangPath

# Clone GCC
#mkdir $GCCaPath
#rm -rf $GCCaPath/*
#mkdir $GCCbPath
#rm -rf $GCCbPath/*

#msg "|| Cloning GCC toolchain ||"
#git clone --depth=1 https://github.com/RyuujiX/aarch64-linux-android-4.9 $GCCaPath
#git clone --depth=1 https://github.com/RyuujiX/arm-linux-androideabi-4.9 $GCCbPath

# Prepared
KERNEL_ROOTDIR=$(pwd)/kernel # IMPORTANT ! Fill with your kernel source root directory.
export KBUILD_BUILD_USER=queen # Change with your own name or else.
IMAGE=$(pwd)/kernel/out/arch/arm64/boot/Image.gz-dtb
CLANG_VER="Snapdragon clang version 14.1.5"
#LLD_VER="$("$ClangPath"/bin/ld.lld --version | head -n 1)"
export KBUILD_COMPILER_STRING=$("$ClangPath"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
#ClangMoreStrings="AR=llvm-ar NM=llvm-nm AS=llvm-as STRIP=llvm-strip OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf HOSTAR=llvm-ar HOSTAS=llvm-as LD_LIBRARY_PATH=$ClangPath/lib LD=ld.lld HOSTLD=ld.lld"
export PATH=$ClangPath/bin:${PATH}
DATE=$(date +"%Y%m%d-%H%M")
START=$(date +"%s")

# Java
command -v java > /dev/null 2>&1

# Telegram
export BOT_MSG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"

# Telegram messaging
tg_post_msg() {
  curl -s -X POST "$BOT_MSG_URL" -d chat_id="$TG_CHAT_ID" \
    -d "disable_web_page_preview=true" \
    -d "parse_mode=html" \
    -d text="$1"
}
# Compiler
compile(){
cd ${KERNEL_ROOTDIR}
msg "|| Cooking kernel. . . ||"
export HASH_HEAD=$(git rev-parse --short HEAD)
export COMMIT_HEAD=$(git log --oneline -1)
make -j$(nproc) O=out ARCH=arm64 sdm670-perf_defconfig
make -j$(nproc) ARCH=arm64 SUBARCH=arm64 O=out \
    PATH=$ClangPath/bin:${PATH} \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    CC=clang \
    AR=llvm-ar \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    LD="$LINKER"

   if ! [ -a "$IMAGE" ]; then
	finerr
	exit 1
   fi

   msg "|| Cloning AnyKernel ||"
   git clone --depth=1 https://github.com/kaderbava/AnyKernel3 AnyKernel
	cp $IMAGE AnyKernel
}
# Push kernel to telegram
function push() {
    cd AnyKernel
    curl -F document="@$ZIP_FINAL.zip" "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="🔐<b>Build Done</b>
        - <code>$((DIFF / 60)) minute(s) $((DIFF % 60)) second(s)... </code>

        <b>📅 Build Date: </b>
        -<code>$DATE</code>

        <b>🐧 Linux Version: </b>
        -<code>$VERSION</code>

         <b>💿 Compiler: </b>
        -<code>$KBUILD_COMPILER_STRING</code>

        <b>📱 Device: </b>
        -<code>$DEVICE_CODENAME($MANUFACTURERINFO)</code>

        <b>🆑 Changelog: </b>
        - <code>$COMMIT_HEAD</code>
        <b></b>
        #$KERNELNAME #$VARIANT"
}
# Find Error
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="❌ Tetap menyerah...Pasti bisa!!!"
    exit 1
}
# Zipping
function zipping() {
    cd AnyKernel
    zip -r9 $KERNELNAME-$CODENAME-"$DATE" . -x ".git*" -x "README.md" -x "./*placeholder" "*.zip"

    ZIP_FINAL="$KERNELNAME-$CODENAME-$DATE"

    msg "|| Signing Zip ||"
    tg_post_msg "<code>🔑 Signing Zip file with AOSP keys..</code>"

    curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
    java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
    ZIP_FINAL="$ZIP_FINAL-signed"
    cd ..
}

compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
