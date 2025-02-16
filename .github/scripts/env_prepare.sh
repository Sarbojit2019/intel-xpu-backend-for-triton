JOB_WORKSPACE=${1:-triton-preci}
TORCH_REPO=${2:-https://github.com/pytorch/pytorch.git}
TORCH_BRANCH=${3:-release/2.1}
TORCH_COMMIT=${4:-209f2fa8ff86652f67d75c2f19bf9cb9942fd018}
IPEX_REPO=${5:-https://github.com/intel/intel-extension-for-pytorch.git}
IPEX_BRANCH=${6:-xpu-main-pre}
IPEX_COMMIT=${7:-7980a37028023037b4f0b47617c5fc3343a6d09b}
ONEAPI_VER=${8:-2024.0}

echo -e "[ INFO ] oneAPI Basekit version: ${ONEAPI_VER}"

installed_torch_git_version=$(python -c "import torch;print(torch.version.git_version)"|| true)
echo -e "[ INFO ] Installed Torch Hash: $installed_torch_git_version"
current_torch_git_version=${TORCH_COMMIT}
echo -e "[ INFO ] Current Torch Hash: $current_torch_git_version"
if [[ -z "$(pip list | grep torch)" || "$installed_torch_git_version" != "$current_torch_git_version" ]];then
    echo -e "========================================================================="
    echo "Public torch BUILD"
    echo -e "========================================================================="
    rm -rf ${HOME}/${JOB_WORKSPACE}/pytorch
    rm -rf ${HOME}/${JOB_WORKSPACE}/intel-extension-for-pytorch
    cd ${HOME}/${JOB_WORKSPACE}
    pip uninstall torch -y
    git clone -b ${TORCH_BRANCH} ${TORCH_REPO}
    git clone -b ${IPEX_BRANCH} ${IPEX_REPO}
    pushd pytorch || exit 1
    git checkout ${TORCH_COMMIT}
    git submodule sync
    git submodule update --init --recursive --jobs 0
    git apply ../patches/pytorch/*.patch
    git apply ../intel-extension-for-pytorch/torch_patches/*.patch
    conda install -y astunparse numpy ninja pyyaml setuptools cmake cffi typing_extensions future six requests dataclasses mkl-include
    conda install -y -f mkl==2021.4.0 # (workaround): fixed version due to undefinded symbol. Once 2024 released, fix this
    python setup.py bdist_wheel 2>&1 | tee pytorch_build.log
    pip install dist/*.whl
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo -e "[ERROR] Public-torch BUILD FAIL"
        exit 1
    fi
    popd
else
    echo -e "========================================================================="
    echo "Public-torch READY"
    echo -e "========================================================================="
fi

source ${HOME}/env_triton.sh ${ONEAPI_VER}
installed_IPEX_git_version=$(python -c "import torch, intel_extension_for_pytorch;print(intel_extension_for_pytorch.__ipex_gitrev__)"|| true)
echo -e "[ INFO ] Installed IPEX Hash: $installed_IPEX_git_version"
current_IPEX_git_version=${IPEX_COMMIT}
current_IPEX_version=${current_IPEX_git_version: 0: 9}
echo -e "[ INFO ] Current IPEX Hash: $current_IPEX_version"
if [[ -z "$(pip list | grep intel-extension-for-pytorch)" || "$installed_IPEX_git_version" != "$current_IPEX_version" ]];then
    echo -e "========================================================================="
    echo "IPEX BUILD"
    echo -e "========================================================================="
    rm -rf ${HOME}/${JOB_WORKSPACE}/intel-extension-for-pytorch
    cd ${HOME}/${JOB_WORKSPACE}
    pip uninstall intel_extension_for_pytorch -y
    git clone -b ${IPEX_BRANCH} ${IPEX_REPO}
    pushd intel-extension-for-pytorch || exit 1
    git checkout ${IPEX_COMMIT}
    git submodule sync
    git submodule update --init --recursive --jobs 0
    git apply ../patches/ipex/*.patch
    pip install -r requirements.txt
    python setup.py bdist_wheel 2>&1 | tee ipex_build.log
    pip install dist/*.whl
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo -e "[ERROR] IPEX BUILD FAIL"
        exit 1
    fi
    popd
else
    echo -e "========================================================================="
    echo "IPEX READY"
    echo -e "========================================================================="
fi
