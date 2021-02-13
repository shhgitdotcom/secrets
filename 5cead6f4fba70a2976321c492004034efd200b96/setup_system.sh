#!/bin/bash

set -o pipefail
set -o errexit
set -o nounset
set -o errtrace
shopt -s inherit_errexit

####################################################################################################
# VARIABLES/CONSTANTS
####################################################################################################

c_components_dir=$(readlink -f "$(dirname "$0")")/components
c_projects_dir=$(readlink -f "$(dirname "$0")")/projects
c_extra_libs_dir=$c_projects_dir/libs_extra

c_debug_log_file=$(basename "$0").log

c_toolchain_address=https://github.com/riscv/riscv-gnu-toolchain.git
c_linux_repo_address=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
c_fedora_image_address=https://dl.fedoraproject.org/pub/alt/risc-v/repo/virt-builder-images/images/Fedora-Minimal-Rawhide-20200108.n.0-sda.raw.xz
c_opensbi_tarball_address=https://github.com/riscv/opensbi/releases/download/v0.9/opensbi-0.9-rv-bin.tar.xz
c_busybear_repo_address=https://github.com/michaeljclark/busybear-linux.git
c_qemu_repo_address=https://github.com/saveriomiroddi/qemu-pinning.git
c_parsec_benchmark_address=git@github.com:saveriomiroddi/parsec-benchmark-tweaked.git
c_parsec_sim_inputs_address=https://parsec.cs.princeton.edu/download/3.0/parsec-3.0-input-sim.tar.gz
c_parsec_native_inputs_address=https://parsec.cs.princeton.edu/download/3.0/parsec-3.0-input-native.tar.gz
c_zlib_repo_address=https://github.com/madler/zlib.git
c_pigz_repo_address=https://github.com/madler/pigz.git
# Bash v5.1 (make) has a bug on parallel compilation (see https://gitweb.gentoo.org/repo/gentoo.git/commit/?id=4c2ebbf4b8bc660beb98cc2d845c73375d6e4f50).
# It can be patched, but it's not worth the hassle.
c_bash_tarball_address=https://ftp.gnu.org/gnu/bash/bash-5.0.tar.gz
c_liblzma_repo_address=https://github.com/xz-mirror/xz.git

# The file_path can be anything, as long as it ends with '.pigz_input', so that it's picked up by the
# benchmark script.
c_pigz_input_file_address=https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/debian-live-10.7.0-amd64-mate.iso

c_busybear_raw_image_path=$c_projects_dir/busybear-linux/busybear.bin
c_busybear_prepared_image_path=$c_components_dir/busybear.bin
export c_busybear_image_size=20480 # integer; number of megabytes
c_fedora_image_size=20G
c_fedora_run_memory=8G
c_local_ssh_port=10000
c_local_fedora_raw_image_path=$c_projects_dir/$(echo "$c_fedora_image_address" | perl -ne 'print /([^\/]+)\.xz$/')
c_local_fedora_prepared_image_path="${c_local_fedora_raw_image_path/.raw/.prepared.raw}"
c_fedora_temp_build_image_path=$(dirname "$(mktemp)")/fedora.temp.build.raw
c_local_parsec_inputs_path=$c_projects_dir/parsec-inputs
c_local_parsec_benchmark_path=$c_projects_dir/parsec-benchmark
c_qemu_binary=$c_projects_dir/qemu-pinning/bin/debug/native/qemu-system-riscv64
c_qemu_pidfile=${XDG_RUNTIME_DIR:-/tmp}/$(basename "$0").qemu.pid
c_bash_binary=$c_projects_dir/$(echo "$c_bash_tarball_address" | perl -ne 'print /([^\/]+)\.tar.\w+$/')/bash
c_local_mount_dir=/mnt

c_compiler_binary=$c_projects_dir/riscv-gnu-toolchain/build/bin/riscv64-unknown-linux-gnu-gcc
c_riscv_firmware_file=share/opensbi/lp64/generic/firmware/fw_dynamic.bin # relative
c_pigz_input_file=$c_components_dir/$(basename "$c_pigz_input_file_address").pigz_input
c_pigz_binary_file=$c_projects_dir/pigz/pigz
c_libz_file=$c_projects_dir/zlib/libz.so.1
c_liblzma_file=$c_projects_dir/xz/liblzma.so.5

c_help='Usage: $(basename "$0")

Downloads/compiles all the components required for a benchmark run: toolchain, Linux kernel, Busybear, QEMU, benchmarked programs and their data.

Components are stored in `'"$c_components_dir"'`, and projects in `'"$c_projects_dir"'`; if any component is present, it'\''s not downloaded/compiled again.

The toolchain project is very large. If existing already on the machine, building can be avoided by symlinking the repo under `'"$c_projects_dir"'`.

Prepares the image with the required files (stored in the root home).
'

v_current_loop_device=

####################################################################################################
# MAIN FUNCTIONS
####################################################################################################

function decode_cmdline_args {
  # Poor man's options decoding.
  #
  if [[ $# -ne 0 ]]; then
    echo "$c_help"
    exit 0
  fi
}

function create_directories {
  mkdir -p "$c_components_dir"
  mkdir -p "$c_projects_dir"
  mkdir -p "$c_extra_libs_dir"
}

function init_debug_log {
  exec 5> "$c_debug_log_file"
  BASH_XTRACEFD="5"
  set -x
}

# Ask sudo permissions only once over the runtime of the script.
#
function cache_sudo {
  sudo -v

  while true; do
    sleep 60
    kill -0 "$$" || exit
    sudo -nv
  done 2>/dev/null &
}

function register_exit_hook {
  function _exit_hook {
    pkill -f "$(basename "$c_qemu_binary")" || true
    rm -f "$c_qemu_pidfile"

    rm -f "$c_fedora_temp_build_image_path"

    if mountpoint -q "$c_local_mount_dir"; then
      sudo umount "$c_local_mount_dir"
    fi

    if [[ -n $v_current_loop_device ]]; then
      sudo losetup -d "$v_current_loop_device"
      v_current_loop_device=
    fi
  }

  trap _exit_hook EXIT
}

function add_toolchain_binaries_to_path {
  export PATH="$c_projects_dir/riscv-gnu-toolchain/build/bin:$PATH"
}

function install_base_packages {
  sudo apt update
  sudo apt install -y git build-essential sshpass pigz gnuplot libguestfs-tools
}

function download_projects {
  local project_addresses=(
    "$c_toolchain_address"
    "$c_linux_repo_address"
    "$c_busybear_repo_address"
    "$c_qemu_repo_address"
    "$c_parsec_benchmark_address"
    "$c_zlib_repo_address"
    "$c_pigz_repo_address"
    "$c_liblzma_repo_address"
  )

  cd "$c_projects_dir"

  for project_address in "${project_addresses[@]}"; do
    if [[ $project_address == *"parsec-benchmark-tweaked"* ]]; then
      project_basename=parsec-benchmark
    else
      project_basename=$(echo "$project_address" | perl -ne 'print /([^\/]+)\.git$/')
    fi

    if [[ $project_basename == "busybear-linux" || $project_basename == "riscv-gnu-toolchain" ]]; then
      local recursive_option=(--recursive)
    else
      local recursive_option=()
    fi

    if [[ -d $project_basename ]]; then
      echo "\`$project_basename\` project found; not cloning..."
    else
      git clone "${recursive_option[@]}" "$project_address"
    fi
  done

  # Tarballs

  if [[ -f $c_local_fedora_raw_image_path ]]; then
    echo "\`$(basename "$c_local_fedora_raw_image_path")\` image found; not downloading..."
  else
    wget --output-document=/dev/stdout "$c_fedora_image_address" | xz -d > "$c_local_fedora_raw_image_path"
  fi

  local opensbi_project_basename
  opensbi_project_basename=$(echo "$c_opensbi_tarball_address" | perl -ne 'print /([^\/]+)\.tar.\w+$/')

  if [[ -d $c_projects_dir/$opensbi_project_basename ]]; then
    echo "\`$opensbi_project_basename\` project found; not downloading..."
  else
    wget --output-document=/dev/stdout "$c_opensbi_tarball_address" | tar xJ --directory="$c_projects_dir"
  fi

  if [[ -d $c_local_parsec_inputs_path ]]; then
    echo "Parsec inputs project found; not downloading..."
  else
    wget --output-document=/dev/stdout "$c_parsec_sim_inputs_address" |
      tar xz --directory="$c_projects_dir" --transform="s/^parsec-3.0/$(basename "$c_local_parsec_inputs_path")/"

    wget --output-document=/dev/stdout "$c_parsec_native_inputs_address" |
      tar xz --directory="$c_projects_dir" --transform="s/^parsec-3.0/$(basename "$c_local_parsec_inputs_path")/"
  fi

  if [[ -d $(dirname "$c_bash_binary") ]]; then
    echo "Bash project found; not downloading..."
  else
    wget --output-document=/dev/stdout "$c_bash_tarball_address" | tar xz --directory="$c_projects_dir"
  fi

  # Pigz input

  if [[ -f $c_pigz_input_file ]]; then
    echo "Pigz input file found; not downloading..."
  else
    wget "$c_pigz_input_file_address" -O "$c_pigz_input_file"
  fi
}

function build_toolchain {
  sudo apt install -y autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev libgmp-dev gawk \
           bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat1-dev

  cd "$c_projects_dir/riscv-gnu-toolchain"

  ./configure --prefix="$PWD/build"
  make linux
}

# This step is required by Busybear; see https://github.com/michaeljclark/busybear-linux/issues/10.
#
function prepare_toolchain {
  echo "Preparing the toolchain..."

  cd "$c_projects_dir/riscv-gnu-toolchain/build/sysroot/usr/include/gnu"

  if [[ ! -e stubs-lp64.h ]]; then
    ln -s stubs-lp64d.h stubs-lp64.h
  fi
}

function prepare_linux_kernel {
  echo "Preparing the Linux kernel..."

  # Some required packages are installed ahead (flex, bison...).

  cd "$c_projects_dir/linux-stable"

  git checkout arch/riscv/Kconfig

  git checkout v5.9.6

  patch -p0 << DIFF
--- arch/riscv/Kconfig	2021-01-31 13:34:53.745703592 +0100
+++ arch/riscv/Kconfig.256cpus	2021-01-31 13:42:50.703249777 +0100
@@ -271,8 +271,8 @@
 	  If you don't know what to do here, say N.
 
 config NR_CPUS
-	int "Maximum number of CPUs (2-32)"
-	range 2 32
+	int "Maximum number of CPUs (2-256)"
+	range 2 256
 	depends on SMP
 	default "8"
DIFF

  make CC="$c_compiler_binary" ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- defconfig

  # Changes:
  #
  # - timer frequency: 100 Hz
  # - max cpus: 256
  #
  patch -p0 << DIFF
--- .config	2021-01-29 22:47:04.394433735 +0100
+++ .config.100hz_256cpus	2021-01-29 22:46:43.262537170 +0100
@@ -245,7 +245,7 @@
 # CONFIG_MAXPHYSMEM_2GB is not set
 CONFIG_MAXPHYSMEM_128GB=y
 CONFIG_SMP=y
-CONFIG_NR_CPUS=8
+CONFIG_NR_CPUS=256
 # CONFIG_HOTPLUG_CPU is not set
 CONFIG_TUNE_GENERIC=y
 CONFIG_RISCV_ISA_C=y
@@ -255,11 +255,11 @@
 #
 # Kernel features
 #
-# CONFIG_HZ_100 is not set
-CONFIG_HZ_250=y
+CONFIG_HZ_100=y
+# CONFIG_HZ_250 is not set
 # CONFIG_HZ_300 is not set
 # CONFIG_HZ_1000 is not set
-CONFIG_HZ=250
+CONFIG_HZ=100
 CONFIG_SCHED_HRTICK=y
 # CONFIG_SECCOMP is not set
 CONFIG_RISCV_SBI_V01=y
DIFF
}

function prepare_busybear {
  echo "Preparing BusyBear..."

  cd "$c_projects_dir/busybear-linux"

  # 100 MB ought to be enough for everybody, but raise it to $c_busybear_image_size anyway.
  # IMAGE_SIZE is the `count` of a `dd bs=1M` (which actually accepts size suffixes).
  #
  perl -i -pe "s/^IMAGE_SIZE=\K.*/$c_busybear_image_size/" conf/busybear.config

  # Correct the networking to use QEMU's user networking. Busybear's default networking setup (bridging)
  # is overkill and generally not working.
  #
  cat > etc/network/interfaces << CFG
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
        address 10.0.2.15
        netmask 255.255.255.0
        broadcast 10.0.2.255
        gateway 10.0.2.2
CFG
}

function prepare_qemu {
  echo "Preparing QEMU..."

  cd "$c_projects_dir/qemu-pinning"

  git checkout include/hw/riscv/virt.h

  git checkout v5.2.0-pinning

  # Allow more than v8 CPUs for the RISC-V virt machine.
  #
  perl -i -pe 's/^#define VIRT_(CPU|SOCKET)S_MAX \K.*/256/' include/hw/riscv/virt.h
}

function build_linux_kernel {
  cd "$c_projects_dir/linux-stable"

  linux_kernel_file=arch/riscv/boot/Image

  if [[ -f $linux_kernel_file ]]; then
    echo "Compiled Linux kernel found; not compiling/copying..."
  else
    make ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- -j "$(nproc)"

    cp "$linux_kernel_file" "$c_components_dir"/
  fi
}

function build_busybear {
  cd "$c_projects_dir/busybear-linux"

  if [[ -f $c_busybear_raw_image_path ]]; then
    echo "Busybear image found; not building..."
  else
    echo 'WATCH OUT!! Busybear may fail without useful messages. If this happens, add `set -x` on top of its `build.sh` script.'

    make
  fi
}

function build_qemu {
  cd "$c_projects_dir/qemu-pinning"

  if [[ -f $c_qemu_binary ]]; then
    echo "QEMU binary found; not compiling/copying..."
  else
    ./build_pinning_qemu_binary.sh --target=riscv64 --yes

    cp "$c_qemu_binary" "$c_components_dir"/
  fi
}

function build_bash {
  cd "$(dirname "$c_bash_binary")"

  if [[ -f $c_bash_binary ]]; then
    echo "Bash binary found; not compiling..."
  else
    # See http://www.linuxfromscratch.org/lfs/view/development/chapter06/bash.html.
    #
    # $LFS_TGT is blank, so it's not set, and we're not performing the install, either.
    #
    ./configure --host="$(support/config.guess)" CC="$(basename "$c_compiler_binary")" --enable-static-link --without-bash-malloc

    make -j "$(nproc)"
  fi
}

# Depends on QEMU.
#
function prepare_fedora {
  echo "Preparing Fedora..."

  # Chunky procedure, so don't redo it if the file exists.
  #
  if [[ -f $c_local_fedora_prepared_image_path ]]; then
    echo "Prepared fedora image found; not processing..."
  else
    ####################################
    # Extend image
    ####################################

    truncate -s "$c_fedora_image_size" "$c_local_fedora_prepared_image_path"
    sudo virt-resize -v -x --expand /dev/sda4 "$c_local_fedora_raw_image_path" "$c_local_fedora_prepared_image_path"
    chown "$USER:" "$c_local_fedora_prepared_image_path"

    ######################################
    # Set passwordless sudo
    ######################################

    mount_image "$c_local_fedora_prepared_image_path" 4

    # Sud-bye!
    sudo sed -i '/%wheel.*NOPASSWD: ALL/ s/^# //' "$c_local_mount_dir/etc/sudoers"

    umount_current_image

    ####################################
    # Start Fedora
    ####################################

    start_fedora "$c_local_fedora_prepared_image_path"

    ####################################
    # Disable long-running service
    ####################################

    run_fedora_command 'sudo systemctl mask man-db-cache-update'

    ####################################
    # Install packages and copy PARSEC
    ####################################

    run_fedora_command 'sudo dnf groupinstall -y "Development Tools" "Development Libraries"'
    run_fedora_command 'sudo dnf install -y tar gcc-c++ texinfo parallel rsync'
    # To replace with xargs once the script is releasable.
    run_fedora_command 'echo "will cite" | parallel --citation || true'
    # Conveniences
    run_fedora_command 'sudo dnf install -y vim pv zstd the_silver_searcher rsync htop'

    shutdown_fedora

    # This (and other occurrences) could trivially be copied via SSH, but QEMU hangs if so (see note
    # in start_fedora()).
    #
    mount_image "$c_local_fedora_prepared_image_path" 4
    sudo rsync -av --info=progress2 --no-inc-recursive --exclude=.git "$c_local_parsec_benchmark_path" "$c_local_mount_dir"/home/riscv/ | grep '/$'
    umount_current_image
  fi
}

function copy_opensbi_firmware {
  cd "$c_projects_dir"/opensbi-*-rv-bin/

  cp "$c_riscv_firmware_file" "$c_components_dir"/
}

# One of the libs required by vips can be conveniently copied from Fedora.
#
function copy_fedora_riscv_libs {
    mount_image "$c_local_fedora_prepared_image_path" 4

    sudo cp "$c_local_mount_dir"/lib64/libxml2.so.2 "$c_extra_libs_dir"/  | grep '/$'

    umount_current_image
}

function build_pigz {
  if [[ -f $c_pigz_binary_file ]]; then
    echo "pigz binary found; not compiling/copying..."
  else
    cd "$c_projects_dir/zlib"

    # For the zlib project included in the RISC-V toolchain, append `--host=x86_64`.
    #
    CC="$c_compiler_binary" ./configure
    make

    cd "$c_projects_dir/pigz"

    make "CC=$c_compiler_binary -I $c_projects_dir/zlib -L $c_projects_dir/zlib"

    cp "$c_pigz_binary_file" "$c_components_dir"/
  fi
}

function build_parsec {
  # double check the name
  #
  local sample_built_package=$c_projects_dir/parsec-benchmark/pkgs/apps/blackscholes/inst/riscv64-linux.gcc/bin/blackscholes

  if [[ -f $sample_built_package ]]; then
    echo "Sample PARSEC package found ($(basename "$sample_built_package")); not building..."
  else
    # Technically, we could leave the QEMU hanging around and copy directly from the VM to the BusyBear
    # image in the appropriate stage, but better to separate stages very clearly.
    #
    echo "Building PARSEC suite in the Fedora VM, and copying it back..."

    cp "$c_local_fedora_prepared_image_path" "$c_fedora_temp_build_image_path"

    start_fedora "$c_fedora_temp_build_image_path"

    # Some packages depend on zlib, so we build it first.
    #
    run_fedora_command "
      cd parsec-benchmark &&
      bin/parsecmgmt -a build -p zlib &&
      parallel bin/parsecmgmt -a build -p ::: parmacs gsl libjpeg libxml2
    "

    # vips is by far the slowest, so we start compiling it first.
    #
    # Packages excluded:
    #
    # - canneal (ASM)
    # - raytrace (ASM)
    # - x264 (ASM)
    # - facesim (segfaults; has ASM but it's not compiled)
    #
    local parsec_packages=(
      parsec.vips
      parsec.blackscholes
      parsec.bodytrack
      parsec.dedup
      parsec.ferret
      parsec.fluidanimate
      parsec.freqmine
      parsec.streamcluster
      parsec.swaptions
      splash2x.barnes
      splash2x.cholesky
      splash2x.fft
      splash2x.fmm
      splash2x.lu_cb
      splash2x.lu_ncb
      splash2x.ocean_cp
      splash2x.ocean_ncp
      splash2x.radiosity
      splash2x.radix
      splash2x.raytrace
      splash2x.volrend
      splash2x.water_nsquared
      splash2x.water_spatial
    )

    # The optimal number of parallel processes can't be easily assessed. Considering that each build
    # has nproc max jobs, and that builds work in bursts, 12.5% builds/nproc (e.g. 4 on 32) should be
    # reasonable.
    # The build time is dominated anyway by `vips`, which is significantly longer than the other ones.

    run_fedora_command "
      cd parsec-benchmark &&
      parallel --max-procs=12.5% bin/parsecmgmt -a build -p ::: ${parsec_packages[*]}
    "

    shutdown_fedora

    mount_image "$c_fedora_temp_build_image_path" 4
    rsync -av --info=progress2 --no-inc-recursive "$c_local_mount_dir"/home/riscv/parsec-benchmark/ "$c_local_parsec_benchmark_path" | grep '/$'
    umount_current_image
  fi
}

function build_liblzma {
  if [[ -f $c_liblzma_file ]]; then
    echo "liblzma library found; not compiling/copying..."
  else
    git -C "$c_projects_dir/xz" checkout v4.999.9beta

    WRITEME: copy to the vm image, and start

    WRITEME: dnf install gettext-devel libtool

    ./autogen.sh
    # --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-assembler \
    ./configure

    cd src/liblzma

    make -j "$(nproc)"

    # Note that we change the name here (`.so.0` -> `.so.5`)
    #
    run_fedora_command "cat xz/src/liblzma/.libs/liblzma.so.0" > "$c_liblzma_file"

    WRITEME: shutdown

    # YAY!
    #
    # https://lists.cs.princeton.edu/pipermail/parsec-users/2008-April/000081.html
    #
    cd parsec-benchmark/pkgs/apps/vips/src
    # Several non-core functionalities are not enabled/compiled, unless the libraries are installed.
    #
    ./configure
    make LDFLAGS=-all-static -j "$(nproc)"


    # [PARSEC] Running '
    # env CXXFLAGS=-I/home/saverio/code/riscv_images/projects/parsec-benchmark/pkgs/libs/glib/inst/amd64-linux.gcc/include -I/home/saverio/code/riscv_images/projects/parsec-benchmark/pkgs/libs/zlib/inst/amd64-linux.gcc/include -O3 -g -funroll-loops -fprefetch-loop-arrays -fpermissive -fno-exceptions -static-libgcc -Wl,--hash-style=both,--as-needed -DPARSEC_VERSION=3.0-beta-20150206 -fexceptions LDFLAGS=-L/home/saverio/code/riscv_images/projects/parsec-benchmark/pkgs/libs/glib/inst/amd64-linux.gcc/lib -L/home/saverio/code/riscv_images/projects/parsec-benchmark/pkgs/libs/zlib/inst/amd64-linux.gcc/lib -L/usr/lib64 -L/usr/lib PKG_CONFIG_PATH=/home/saverio/code/riscv_images/projects/parsec-benchmark/pkgs/libs/glib/inst/amd64-linux.gcc/lib/pkgconfig:/home/saverio/code/riscv_images/projects/parsec-benchmark/pkgs/libs/libxml2/inst/amd64-linux.gcc/lib/pkgconfig: LIBS= -lstdc++ /home/saverio/code/riscv_images/projects/parsec-benchmark/pkgs/apps/vips/src/configure --disable-shared --disable-cxx --without-fftw3 --without-magick --without-liboil --without-lcms --without-OpenEXR --without-matio --without-pangoft2 --without-tiff --without-jpeg --without-zip --without-png --without-libexif --without-python --without-x --without-perl --without-v4l --without-cimg --enable-threads --build= --host= --prefix=/home/saverio/code/riscv_images/projects/parsec-benchmark/pkgs/apps/vips/inst/amd64-linux.gcc
    # ':

    # [PARSEC] Running '
    # env CXXFLAGS=-I/home/saverio/code/riscv_images/projects/parsec-benchmark/pkgs/libs/glib/inst/amd64-linux.gcc/include -I/home/saverio/code/riscv_images/projects/parsec-benchmark/pkgs/libs/zlib/inst/amd64-linux.gcc/include -O3 -g -funroll-loops -fprefetch-loop-arrays -fpermissive -fno-exceptions -static-libgcc -Wl,--hash-style=both,--as-needed -DPARSEC_VERSION=3.0-beta-20150206 -fexceptions LDFLAGS=-L/home/saverio/code/riscv_images/projects/parsec-benchmark/pkgs/libs/glib/inst/amd64-linux.gcc/lib -L/home/saverio/code/riscv_images/projects/parsec-benchmark/pkgs/libs/zlib/inst/amd64-linux.gcc/lib -L/usr/lib64 -L/usr/lib PKG_CONFIG_PATH=/home/saverio/code/riscv_images/projects/parsec-benchmark/pkgs/libs/glib/inst/amd64-linux.gcc/lib/pkgconfig:/home/saverio/code/riscv_images/projects/parsec-benchmark/pkgs/libs/libxml2/inst/amd64-linux.gcc/lib/pkgconfig: LIBS= -lstdc++ make -j 32
    # ':

    WRITME: libxml2
    ssfe 'cat /home/riscv/parsec-benchmark/pkgs/libs/libxml2/src/.libs/libxml2.so.2' > libs_extra/libxml2.so.2
    for f in libs_extra/*; do cat $f | ssbyb "cat > /lib/$(basename $f)"; done
    cat zlib/libz.so | ssbyb "cat > /lib/libz.so.1"
    ssbyb
    export HOSTTYPE=riscv64
    cd parsec-benchmark
    bin/parsecmgmt -a run -p vips -i simdev -n $(nproc)

#     CC="$c_compiler_binary" ./configure \
#       --host=x86_64
# 
#     make -j "$(nproc)"
    
  
#     CC="$c_compiler_binary" ./configure
#     make
# 
#     cd "$c_projects_dir/pigz"
# 
#     make "CC=$c_compiler_binary -I $c_projects_dir/zlib -L $c_projects_dir/zlib"
# 
#     cp "$c_pigz_binary_file" "$c_components_dir"/
  fi
}

# For simplicity, just run it without checking if the files already exist.
#
# Note that libs are better copied rather than rsync'd, since they are often symlinks.
#
function prepare_final_image_with_data {
  if [[ ! -f $c_busybear_prepared_image_path ]]; then
    echo "BusyBear prepared image not found, copying..."

    cp "$c_busybear_raw_image_path" "$c_busybear_prepared_image_path"
  fi

  mount_image "$c_busybear_prepared_image_path"

  # Pigz(-related)
  #
  sudo rsync -av          "$c_pigz_binary_file" "$c_local_mount_dir"/root/
  sudo cp -v              "$c_libz_file"        "$c_local_mount_dir"/lib/
  sudo rsync -av --append "$c_pigz_input_file"  "$c_local_mount_dir"/root/

  # PARSEC + Inputs
  #
  sudo rsync -av --info=progress2 --no-inc-recursive --exclude=.git \
    "$c_local_parsec_benchmark_path" "$c_local_mount_dir"/root/ |
    grep '/$'

  sudo rsync -av --info=progress2 --no-inc-recursive --append \
    "$c_local_parsec_inputs_path"/ "$c_local_mount_dir"/root/parsec-benchmark/ |
    grep '/$'

  # Extra libs

  sudo cp -v "$c_extra_libs_dir"/* "$c_local_mount_dir"/lib/

  # Bash (also set as default shell)

  sudo cp "$c_bash_binary" "$c_local_mount_dir"/bin/
  sudo ln -sf bash "$c_local_mount_dir"/bin/sh

  # Done!

  umount_current_image
}

function print_completion_message {
  echo "Preparation completed!"
}

####################################################################################################
# HELPERS
####################################################################################################

# $1: disk image
#
function start_fedora {
  local kernel_image=$c_components_dir/Image
  local bios_image=$c_components_dir/fw_dynamic.bin
  local disk_image=$1
  local image_format=${disk_image##*.}

  "$c_qemu_binary" \
    -daemonize \
    -display none \
    -pidfile "$c_qemu_pidfile" \
    -machine virt \
    -smp "$(nproc)",cores="$(nproc)",sockets=1,threads=1 \
    -accel tcg,thread=multi \
    -m "$c_fedora_run_memory" \
    -kernel "$kernel_image" \
    -bios "$bios_image" \
    -append "root=/dev/vda4 ro console=ttyS0" \
    -object rng-random,filename=/dev/urandom,id=rng0 \
    -device virtio-rng-device,rng=rng0 \
    -device virtio-blk-device,drive=hd0 \
    -drive file="$disk_image",format="$image_format",id=hd0 \
    -device virtio-net-device,netdev=usernet \
    -netdev user,id=usernet,hostfwd=tcp::"$c_local_ssh_port"-:22

  while ! nc -z localhost "$c_local_ssh_port"; do sleep 1; done

  run_fedora_command -o ConnectTimeout=30 exit

  # Something's odd going on here. One minute or two into the installation of the development packages,
  # the VM connection would drop, causing dnf to fail, and the port on the host to stay open, but without
  # the SSH service starting the handshake. This points either to the QEMU networking having some issue,
  # or to some internal Fedora service dropping the connection, although the latter seems unlikely,
  # as repeated connection to the port shouldn't prevent the problem it to happen.
  #
  set +x
  {
    while nc -z localhost "$c_local_ssh_port"; do
      curl localhost:"$c_local_ssh_port" 2> /dev/null || true
      sleep 1
    done
  } &
  set -x
}

# $@: ssh params
#
function run_fedora_command {
  sshpass -p 'fedora_rocks!' \
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -p "$c_local_ssh_port" riscv@localhost "$@"
}

function shutdown_fedora {
  # Watch out - halting via ssh causes an error, since the connection is truncated.
  #
  run_fedora_command "sudo halt" || true

  # Shutdown is asynchronous, so just wait for the pidfile to go.
  #
  while [[ -f $c_qemu_pidfile ]]; do
    sleep 0.5
  done
}

# $1: image, $2 (optional): partition number
#
function mount_image {
  local image=$1
  local image_partition=${2:+p$2}

  v_current_loop_device=$(sudo losetup --show --find --partscan "$image")
  sudo mount "${v_current_loop_device}${image_partition}" "$c_local_mount_dir"
}

function umount_current_image {
  sudo umount "$c_local_mount_dir"
  sudo losetup -d "$v_current_loop_device"
  v_current_loop_device=
}

####################################################################################################
# EXECUTION
####################################################################################################

decode_cmdline_args "$@"
create_directories
init_debug_log
cache_sudo
register_exit_hook

install_base_packages
add_toolchain_binaries_to_path

download_projects

# This needs to be built in advance, due to the kernel configuration.
build_toolchain

prepare_toolchain
prepare_linux_kernel
prepare_busybear
prepare_qemu

build_linux_kernel
build_busybear
copy_opensbi_firmware
build_qemu
build_bash

# This needs to be prepared late, due the QEMU binary dependency.
prepare_fedora

build_parsec
copy_fedora_riscv_libs
build_pigz
build_liblzma

prepare_final_image_with_data

print_completion_message
