#!/usr/bin/env bash

# Import limine common functions and environment variables
LIMINE_FUNCTIONS_PATH=/usr/lib/limine/limine-common-functions
# shellcheck disable=SC1090
if [[ -f "${LIMINE_FUNCTIONS_PATH}" ]]; then
    source "${LIMINE_FUNCTIONS_PATH}" || {
        echo -e "\033[1;31m Error: Failed to source '${LIMINE_FUNCTIONS_PATH}'.\033[0m" >&2
        exit 1
    }
    initialize_header || exit 1
else
    # Fallback for systems without limine common functions
    echo ">>> [limine-booster] Starting Booster initramfs generation..."
    MACHINE_ID=$(cat /etc/machine-id)
    ESP_PATH="/boot"
fi

process_all=0
kernel_targets=()
removed_kernels=()
has_kernel_changes=0
has_system_changes=0

# Extract package name from existing limine.conf entries by kernel version
extract_package_from_limine_conf() {
    local kernel_version="$1"
    local config_file="/boot/limine.conf"

    # Input validation
    [[ -n "${kernel_version}" ]] || return 1

    if [[ ! -f "${config_file}" ]]; then
        return 1
    fi

    # Look for entries that contain this kernel version
    # Pattern: //package_name version_info
    local pkg_name=""
    while IFS= read -r line; do
        if [[ "${line}" =~ ^[[:space:]]*//([a-zA-Z0-9_-]+)[[:space:]]+.*"${kernel_version}".* ]]; then
            pkg_name="${BASH_REMATCH[1]}"
            echo "${pkg_name}"
            return 0
        fi
    done < "${config_file}"

    # Alternative: match linux package entries with version pattern matching
    while IFS= read -r line; do
        if [[ "${line}" =~ ^[[:space:]]*//([a-zA-Z0-9_-]*linux[a-zA-Z0-9_-]*)[[:space:]]+ ]]; then
            pkg_name="${BASH_REMATCH[1]}"
            # Check if package name appears in kernel version
            if echo "${kernel_version}" | grep -q "${pkg_name#linux-}" 2>/dev/null; then
                echo "${pkg_name}"
                return 0
            fi
        fi
    done < "${config_file}"

    return 1
}

# Process pacman hook input and categorize changes
while read -r line; do
    if [[ "${line}" == */vmlinuz ]]; then
        # Direct kernel file changes
        kernel_dir="/${line%/vmlinuz}"
        kernel_targets+=("${kernel_dir}")
        has_kernel_changes=1

        # Check if this is a removal (kernel directory no longer exists)
        if [[ ! -d "${kernel_dir}" ]]; then
            removed_kernels+=("${kernel_dir}")
        fi
    elif [[ "${line}" =~ usr/lib/firmware/ ]] || \
         [[ "${line}" =~ usr/src/.*/dkms\.conf ]] || \
         [[ "${line}" =~ usr/lib/modules/.*/extramodules/ ]]; then
        # System-wide changes that affect all installed kernels
        has_system_changes=1
    fi
done

# Determine processing mode based on detected changes
if [[ ${has_system_changes} -eq 1 ]] || [[ ${#kernel_targets[@]} -eq 0 && ${has_kernel_changes} -eq 0 ]]; then
    echo ">>> [limine-booster] System changes detected, processing all kernels..."
    process_all=1
    kernel_targets=(/usr/lib/modules/*)
elif [[ ${has_kernel_changes} -eq 1 ]]; then
    echo ">>> [limine-booster] Kernel-specific changes detected, processing ${#kernel_targets[@]} kernels..."
fi

# Use limine mutex lock if available
if command -v mutex_lock &> /dev/null; then
    mutex_lock "limine-booster-install"
fi

# Clean up any existing duplicate files in /boot root from previous installations
cleanup_existing_duplicates() {
    echo ">>> [limine-booster] Cleaning up existing duplicate files..."

    # Find all booster and vmlinuz files in /boot root that might be duplicates
    for booster_file in /boot/booster-*.img; do
        if [[ -f "${booster_file}" ]]; then
            local pkg_name=$(basename "${booster_file}" | sed 's/^booster-//' | sed 's/\.img$//')
            local organized_file="/boot/${MACHINE_ID}/${pkg_name}/booster-${pkg_name}.img"

            # If organized version exists, remove the duplicate
            if [[ -f "${organized_file}" ]]; then
                echo "Removing duplicate booster file: ${booster_file}"
                rm -f "${booster_file}" 2>/dev/null || echo "WARNING: Failed to remove ${booster_file}"
            fi
        fi
    done

    for vmlinuz_file in /boot/vmlinuz-*; do
        if [[ -f "${vmlinuz_file}" ]]; then
            local pkg_name=$(basename "${vmlinuz_file}" | sed 's/^vmlinuz-//')
            local organized_file="/boot/${MACHINE_ID}/${pkg_name}/vmlinuz-${pkg_name}"

            # If organized version exists, remove the duplicate
            if [[ -f "${organized_file}" ]]; then
                echo "Removing duplicate vmlinuz file: ${vmlinuz_file}"
                rm -f "${vmlinuz_file}" 2>/dev/null || echo "WARNING: Failed to remove ${vmlinuz_file}"
            fi
        fi
    done
}

# Clean up existing duplicates
cleanup_existing_duplicates

# Reset limine enroll config if available
if command -v reset_enroll_config &> /dev/null; then
    reset_enroll_config
fi

# Process removed kernels first (cleanup before adding new entries)
for removed_dir in "${removed_kernels[@]}"; do
    if [[ -n "${removed_dir}" && -n "${removed_dir##*/}" ]]; then
        # Extract kernel version from directory path
        kVer="${removed_dir##*/}"
        echo "Removing entries for deleted kernel: ${kVer}"

        # Determine package name for the removed kernel
        pkgBase=""
        # First try: check if pkgbase file still exists
        if [[ -f "${removed_dir}/pkgbase" ]]; then
            pkgBase="$(<"${removed_dir}/pkgbase")"
        else
            # Fallback: extract package name from existing limine.conf entries
            pkgBase=$(extract_package_from_limine_conf "${kVer}")

            # Last resort: pattern matching based on kernel version
            if [[ -z "${pkgBase}" ]]; then
                case "${kVer}" in
                    *-nitrous*) pkgBase="linux-nitrous" ;;
                    *-cachyos-lts*) pkgBase="linux-cachyos-lts" ;;
                    *-cachyos-rc*) pkgBase="linux-cachyos-rc" ;;
                    *-cachyos-bore*) pkgBase="linux-cachyos-bore" ;;
                    *-cachyos-bmq*) pkgBase="linux-cachyos-bmq" ;;
                    *-cachyos-pds*) pkgBase="linux-cachyos-pds" ;;
                    *-cachyos-tt*) pkgBase="linux-cachyos-tt" ;;
                    *-cachyos*) pkgBase="linux-cachyos" ;;
                    *-zen*) pkgBase="linux-zen" ;;
                    *-lts*) pkgBase="linux-lts" ;;
                    *-hardened*) pkgBase="linux-hardened" ;;
                    *-rt*) pkgBase="linux-rt" ;;
                    *-rt-lts*) pkgBase="linux-rt-lts" ;;
                    *-xanmod*) pkgBase="linux-xanmod" ;;
                    *-clear*) pkgBase="linux-clear" ;;
                    *-arch*) pkgBase="linux" ;;
                    *)
                        # Advanced extraction for custom/AUR kernels
                        # Pattern: X.Y.Z-N-SUFFIX -> linux-SUFFIX
                        if [[ "${kVer}" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?-[0-9]+-(.+)$ ]]; then
                            suffix="${BASH_REMATCH[2]}"
                            # Remove common arch suffixes
                            suffix=$(echo "${suffix}" | sed -E 's/-(x86_64|ARCH)$//')
                            if [[ "${suffix}" != "ARCH" && "${suffix}" != "arch" ]]; then
                                pkgBase="linux-${suffix}"
                            else
                                pkgBase="linux"
                            fi
                        else
                            # Default fallback
                            pkgBase="linux"
                        fi
                        ;;
                esac
            fi
        fi

        if [[ -n "${pkgBase}" ]]; then
            echo "Detected removed package: ${pkgBase}"
            # Remove Limine entries and clean up files
            if ! /usr/bin/limine-booster-remove "${pkgBase}" 2>/dev/null; then
                echo "WARNING: Failed to clean up entry for ${pkgBase}" >&2
            fi
        else
            echo "WARNING: Could not determine package name for removed kernel: ${kVer}" >&2
        fi
    fi
done

# Process existing/new kernel directories for entry creation
for line in "${kernel_targets[@]}"; do
    # Skip kernels that were already removed (handled above)
    if [[ " ${removed_kernels[*]} " =~ " ${line} " ]]; then
        continue
    fi

    # Skip if pkgbase file is not owned by any package
    if ! pacman -Qqo "${line}/pkgbase" &>/dev/null; then
        continue
    fi

    if [[ ! -f "${line}/pkgbase" ]]; then
        echo "WARNING: pkgbase file missing for ${line}" >&2
        continue
    fi

    pkgBase="$(<"${line}/pkgbase")"
    kVer="${line##*/}"

    # Validate extracted data
    if [[ -z "${pkgBase}" || -z "${kVer}" ]]; then
        echo "WARNING: Invalid package or kernel version data for ${line}" >&2
        continue
    fi

    kDirPath="${ESP_PATH}/${MACHINE_ID}/${pkgBase}"

    booster_path="${kDirPath}/booster-${pkgBase}.img"
    vmlinuz_path="${kDirPath}/vmlinuz-${pkgBase}"

    # Create kernel directory with secure permissions
    if ! install -dm700 "${kDirPath}"; then
        echo "ERROR: Failed to create kernel directory: ${kDirPath}" >&2
        continue
    fi

    # Copy kernel image to boot directory
    if ! install -Dm600 "${line}/vmlinuz" "${vmlinuz_path}"; then
        echo "ERROR: Failed to install kernel: ${vmlinuz_path}" >&2
        continue
    fi

    echo "Building Booster initramfs for ${pkgBase} (${kVer})"

    # Build Booster initramfs image
    if ! booster build --force --kernel-version "${kVer}" "${booster_path}"; then
        echo "ERROR: Booster build failed for kernel ${kVer}" >&2
        continue
    fi

    # Update Limine configuration with proper entry management
    if [[ ${process_all} -eq 1 ]]; then
        # System-wide changes: process all kernels at once
        if ! /usr/bin/limine-booster-update 2>/dev/null; then
            echo "ERROR: Failed to update Limine entries" >&2
        fi
        break  # Only need to run once for all kernels
    else
        # Kernel-specific changes: process individual kernel
        if ! /usr/bin/limine-booster-update "${line}/vmlinuz" 2>/dev/null; then
            echo "ERROR: Failed to update Limine entry for ${pkgBase}" >&2
        fi
    fi

    echo "Kernel stored in: ${vmlinuz_path}"
    echo "Booster initramfs stored in: ${booster_path}"

    # Clean up duplicate files created by standard booster hooks in /boot root
    duplicate_booster="/boot/booster-${pkgBase}.img"
    duplicate_vmlinuz="/boot/vmlinuz-${pkgBase}"

    if [[ -f "${duplicate_booster}" ]]; then
        echo "Removing duplicate booster file: ${duplicate_booster}"
        rm -f "${duplicate_booster}" 2>/dev/null || echo "WARNING: Failed to remove ${duplicate_booster}"
    fi

    if [[ -f "${duplicate_vmlinuz}" ]]; then
        echo "Removing duplicate vmlinuz file: ${duplicate_vmlinuz}"
        rm -f "${duplicate_vmlinuz}" 2>/dev/null || echo "WARNING: Failed to remove ${duplicate_vmlinuz}"
    fi
done

# Enroll limine config if available
if command -v enroll_config &> /dev/null; then
    enroll_config
fi

# Release limine mutex if available
if command -v mutex_unlock &> /dev/null; then
    mutex_unlock
fi
