#!/usr/bin/env bash

# Import functions and environment variables
LIMINE_FUNCTIONS_PATH=/usr/lib/limine/limine-common-functions
# shellcheck disable=SC1090
if [[ -f "${LIMINE_FUNCTIONS_PATH}" ]]; then
    source "${LIMINE_FUNCTIONS_PATH}" || {
        echo -e "\033[1;31m Error: Failed to source '${LIMINE_FUNCTIONS_PATH}'.\033[0m" >&2
        exit 1
    }
    initialize_header || exit 1
else
    # Fallback for systems without limine-common-functions
    echo ">>> [limine-booster] Starting Booster initramfs generation..."
    MACHINE_ID=$(cat /etc/machine-id)
    ESP_PATH="/boot"
fi

process_all=0
kernel_targets=()
removed_kernels=()
has_kernel_changes=0
has_system_changes=0

# Read input and categorize changes
while read -r line; do
    if [[ "${line}" == */vmlinuz ]]; then
        # Direct kernel changes
        kernel_dir="/${line%/vmlinuz}"
        kernel_targets+=("${kernel_dir}")
        has_kernel_changes=1
        
        # Check if this is a removal (kernel directory no longer exists)
        if [[ ! -d "${kernel_dir}" ]]; then
            removed_kernels+=("${kernel_dir}")
        fi
    elif [[ "${line}" =~ usr/lib/firmware/ ]] || \
         [[ "${line}" =~ usr/lib/initcpio/ ]] || \
         [[ "${line}" =~ usr/src/.*/dkms\.conf ]] || \
         [[ "${line}" =~ usr/lib/modules/.*/extramodules/ ]]; then
        # System changes that affect all kernels
        has_system_changes=1
    fi
done

# Determine processing mode
if [[ ${has_system_changes} -eq 1 ]] || [[ ${#kernel_targets[@]} -eq 0 && ${has_kernel_changes} -eq 0 ]]; then
    echo ">>> [limine-booster] System changes detected, processing all kernels..."
    process_all=1
    kernel_targets=(/usr/lib/modules/*)
elif [[ ${has_kernel_changes} -eq 1 ]]; then
    echo ">>> [limine-booster] Kernel-specific changes detected, processing ${#kernel_targets[@]} kernels..."
fi

# Mutex lock if function is available
if command -v mutex_lock &> /dev/null; then
    mutex_lock "limine-booster-install"
fi

# Reset enroll config if function is available
if command -v reset_enroll_config &> /dev/null; then
    reset_enroll_config
fi

# Handle removed kernels first
for removed_dir in "${removed_kernels[@]}"; do
    if [[ -n "${removed_dir}" ]]; then
        # Extract package name from removed kernel directory
        kVer="${removed_dir##*/}"
        echo "Removing entries for deleted kernel: ${kVer}"
        
        # Try to determine package name from kernel version
        pkgBase=""
        case "${kVer}" in
            *-lts) pkgBase="linux-lts" ;;
            *-zen*) pkgBase="linux-zen" ;;
            *-cachyos-rc*) pkgBase="linux-cachyos-rc" ;;
            *-cachyos*) pkgBase="linux-cachyos" ;;
            *) 
                # Try to extract package name from kernel version pattern
                pkgBase=$(echo "${kVer}" | sed -E 's/^[0-9]+\.[0-9]+.*-[0-9]+-(.+)$/linux-\1/' | sed 's/-$//')
                [[ "${pkgBase}" == "linux-" ]] && pkgBase="linux"
                ;;
        esac
        
        if [[ -n "${pkgBase}" ]]; then
            echo "Detected removed package: ${pkgBase}"
            # Remove Limine entry and clean up files
            /usr/bin/limine-booster-remove "${pkgBase}" 2>/dev/null || {
                echo "WARNING: Failed to clean up entry for ${pkgBase}" >&2
            }
        fi
    fi
done

# Process existing/new kernel directories
for line in "${kernel_targets[@]}"; do
    # Skip if this was a removed kernel (already handled above)
    if [[ " ${removed_kernels[*]} " =~ " ${line} " ]]; then
        continue
    fi
    
    if ! pacman -Qqo "${line}/pkgbase" &>/dev/null; then
        # Skip kernel if pkgBase does not belong to any package
        continue
    fi

    pkgBase="$(<"${line}/pkgbase")"
    kVer="${line##*/}"

    kDirPath="${ESP_PATH}/${MACHINE_ID}/${pkgBase}"
    
    booster_path="${kDirPath}/booster-${pkgBase}.img"
    vmlinuz_path="${kDirPath}/vmlinuz-${pkgBase}"

    # Create kernel directory
    install -dm700 "${kDirPath}"
    install -Dm600 "${line}/vmlinuz" "${vmlinuz_path}"

    echo "Building Booster initramfs for ${pkgBase} (${kVer})"
    
    # Build Booster image
    if ! booster build --force --kernel-version "${kVer}" "${booster_path}"; then
        echo "ERROR: Booster build failed for kernel ${kVer}" >&2
        continue
    fi
    
    # Use our script for proper entry management
    if [[ ${process_all} -eq 1 ]]; then
        # For system-wide changes, use manual sync mode
        /usr/bin/limine-booster-update 2>/dev/null || {
            echo "ERROR: Failed to update Limine entries" >&2
        }
        break  # Only need to run once for all kernels
    else
        # For specific kernel changes, use hook mode
        /usr/bin/limine-booster-update "${line}/vmlinuz" 2>/dev/null || {
            echo "ERROR: Failed to update Limine entry for ${pkgBase}" >&2
        }
    fi
    
    echo "Kernel stored in: ${vmlinuz_path}"
    echo "Booster initramfs stored in: ${booster_path}"
done

# Enroll config if function is available
if command -v enroll_config &> /dev/null; then
    enroll_config
fi

# Unlock mutex if function is available
if command -v mutex_unlock &> /dev/null; then
    mutex_unlock
fi