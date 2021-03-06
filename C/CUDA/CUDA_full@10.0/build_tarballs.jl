using BinaryBuilder

include("../../../fancy_toys.jl")

name = "CUDA_full"
version = v"10.0.130"

sources_linux = [
    FileSource("https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_410.48_linux",
               "92351f0e4346694d0fcb4ea1539856c9eb82060c25654463bfd8574ec35ee39a", "installer.run")
]
sources_macos = [
    FileSource("https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_mac",
               "4f76261ed46d0d08a597117b8cacba58824b8bb1e1d852745658ac873aae5c8e", "installer.dmg")
]
sources_windows = [
    FileSource("https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_411.31_win10",
               "9dae54904570272c1fcdb10f5f19c71196b4fdf3ad722afa0862a238d7c75e6f", "installer.exe")
]

script = raw"""
cd ${WORKSPACE}/srcdir

# use a temporary directory to avoid running out of tmpfs in srcdir on Travis
temp=${WORKSPACE}/tmpdir
mkdir ${temp}

apk add p7zip

if [[ ${target} == x86_64-linux-gnu ]]; then
    sh installer.run --tmpdir="${temp}" --extract="${temp}"
    cd ${temp}
    sh cuda-linux.*.run --noexec --keep
    cd pkg
    find .

    # clean-up
    rm -r libnsight libnvvp nsightee_plugins jre NsightCompute-1.0 doc

    mv * ${prefix}
    cd ${prefix}

    install_license EULA.txt
elif [[ ${target} == x86_64-apple-darwin* ]]; then
    7z x installer.dmg 5.hfs -o${temp}
    cd ${temp}
    7z x 5.hfs
    tar -zxf CUDAMacOSXInstaller/CUDAMacOSXInstaller.app/Contents/Resources/payload/cuda_mac_installer_tk.tar.gz
    cd Developer/NVIDIA/CUDA-*/
    find .

    # clean-up
    rm -r libnsight libnvvp nsightee_plugins jre NsightCompute-1.0 doc

    mv * ${prefix}
    cd ${prefix}

    install_license EULA.txt
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    7z x installer.exe -o${temp}
    cd ${temp}
    find .

    for project in cuobjdump memcheck nvcc cupti nvdisasm curand cusparse npp cufft \
                   cublas cudart cusolver nvrtc nvgraph nvprof nvprune; do
        [[ -d ${project} ]] || { echo "${project} does not exist!"; exit 1; }
        cp -a ${project}/* ${prefix}
    done

    install_license EULA.txt

    # fixup
    chmod +x ${prefix}/bin/*.exe

    # clean-up
    rm ${prefix}/*.nvi
fi
"""

products = Product[
    # this JLL isn't meant for use by Julia packages, but only as build dependency
]

dependencies = []

non_reg_ARGS = filter(arg -> arg != "--register", ARGS)

if should_build_platform("x86_64-linux-gnu")
    build_tarballs(non_reg_ARGS, name, version, sources_linux, script,
                   [Linux(:x86_64)], products, dependencies;
                   skip_audit=true)
end

if should_build_platform("x86_64-apple-darwin14")
    build_tarballs(non_reg_ARGS, name, version, sources_macos, script,
                   [MacOS(:x86_64)], products, dependencies;
                   skip_audit=true)
end

if should_build_platform("x86_64-w64-mingw32")
    build_tarballs(ARGS, name, version, sources_windows, script,
                   [Windows(:x86_64)], products, dependencies;
                   skip_audit=true)
end
