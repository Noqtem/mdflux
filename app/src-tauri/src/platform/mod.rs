//! Small platform boundary for supported release targets.
//!
//! MDFlux supports `windows-x64`, `linux-x64-glibc`, `macos-arm64`, and `macos-x64`.
//! Other targets receive an explicit error instead of failing inside unresolved cfg modules.

use std::path::Path;

/// Platform identifiers supported by the application.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlatformId {
    WindowsX64,
    LinuxX64Glibc,
    MacosArm64,
    MacosX64,
}

impl PlatformId {
    pub fn as_str(self) -> &'static str {
        match self {
            PlatformId::WindowsX64 => "windows-x64",
            PlatformId::LinuxX64Glibc => "linux-x64-glibc",
            PlatformId::MacosArm64 => "macos-arm64",
            PlatformId::MacosX64 => "macos-x64",
        }
    }

    pub fn from_str(s: &str) -> Result<Self, String> {
        match s {
            "windows-x64" => Ok(PlatformId::WindowsX64),
            "linux-x64-glibc" => Ok(PlatformId::LinuxX64Glibc),
            "macos-arm64" => Ok(PlatformId::MacosArm64),
            "macos-x64" => Ok(PlatformId::MacosX64),
            other => Err(format!(
                "Unsupported platform identifier '{other}'. MDFlux supports windows-x64, linux-x64-glibc, macos-arm64, and macos-x64."
            )),
        }
    }
}

/// Platform-specific constants and paths for provisioning and bundled runtimes.
#[derive(Debug, Clone)]
pub struct PlatformSpec {
    pub id: PlatformId,
    pub uv_url: &'static str,
    pub uv_sha256: &'static str,
    pub uv_archive: &'static str,
    pub uv_bin: &'static str,
    pub venv_python_bin: &'static str,
    pub bundled_python_bin: &'static str,
    pub uv_label: &'static str,
}

#[cfg(all(target_os = "windows", target_arch = "x86_64"))]
pub fn current_platform() -> Result<PlatformSpec, String> {
    Ok(PlatformSpec {
        id: PlatformId::WindowsX64,
        uv_url:
            "https://github.com/astral-sh/uv/releases/download/0.5.11/uv-x86_64-pc-windows-msvc.zip",
        uv_sha256: "3e8203e6434b45427f20824419f8d8d53f970a76d94ccdcad07f8498fa01a9d0",
        uv_archive: "uv.zip",
        uv_bin: "uv.exe",
        venv_python_bin: "Scripts/python.exe",
        bundled_python_bin: "python.exe",
        uv_label: "uv 0.5.11 - Python package manager (Windows x64)",
    })
}

#[cfg(all(target_os = "linux", target_arch = "x86_64"))]
pub fn current_platform() -> Result<PlatformSpec, String> {
    Ok(PlatformSpec {
        id: PlatformId::LinuxX64Glibc,
        uv_url: "https://github.com/astral-sh/uv/releases/download/0.5.11/uv-x86_64-unknown-linux-gnu.tar.gz",
        uv_sha256: "14411de26cdea5f5139fafaf2b675b1c633e744dd49c6d6a9fc8817ec065158b",
        uv_archive: "uv.tar.gz",
        uv_bin: "uv",
        venv_python_bin: "bin/python",
        bundled_python_bin: "bin/python3",
        uv_label: "uv 0.5.11 - Python package manager (Linux x64)",
    })
}

#[cfg(all(target_os = "macos", target_arch = "aarch64"))]
pub fn current_platform() -> Result<PlatformSpec, String> {
    Ok(PlatformSpec {
        id: PlatformId::MacosArm64,
        uv_url: "https://github.com/astral-sh/uv/releases/download/0.5.11/uv-aarch64-apple-darwin.tar.gz",
        uv_sha256: "695f3640d5b1a4e28de7e36e3a2e14072852dcc6c70bf9e4deec6ada00d516b4",
        uv_archive: "uv.tar.gz",
        uv_bin: "uv",
        venv_python_bin: "bin/python",
        bundled_python_bin: "bin/python3",
        uv_label: "uv 0.5.11 - Python package manager (macOS Apple Silicon)",
    })
}

#[cfg(all(target_os = "macos", target_arch = "x86_64"))]
pub fn current_platform() -> Result<PlatformSpec, String> {
    Ok(PlatformSpec {
        id: PlatformId::MacosX64,
        uv_url: "https://github.com/astral-sh/uv/releases/download/0.5.11/uv-x86_64-apple-darwin.tar.gz",
        uv_sha256: "7e23d1d892c23f9e74245c4fd3d3e246438ce9b34460f85eee61f784de137b0b",
        uv_archive: "uv.tar.gz",
        uv_bin: "uv",
        venv_python_bin: "bin/python",
        bundled_python_bin: "bin/python3",
        uv_label: "uv 0.5.11 - Python package manager (macOS Intel)",
    })
}

#[cfg(not(any(
    all(target_os = "windows", target_arch = "x86_64"),
    all(target_os = "linux", target_arch = "x86_64"),
    all(target_os = "macos", target_arch = "aarch64"),
    all(target_os = "macos", target_arch = "x86_64")
)))]
pub fn current_platform() -> Result<PlatformSpec, String> {
    Err(format!(
        "MDFlux does not support this operating system/architecture ({}/{}). \
         Supported targets: windows-x64, linux-x64-glibc, macos-arm64, macos-x64.",
        std::env::consts::OS,
        std::env::consts::ARCH
    ))
}

/// Available physical memory in MiB for batch worker sizing.
#[cfg(windows)]
pub fn available_ram_mb() -> Option<u64> {
    #[repr(C)]
    struct MemStatus {
        length: u32,
        memory_load: u32,
        total_phys: u64,
        avail_phys: u64,
        total_pagefile: u64,
        avail_pagefile: u64,
        total_virtual: u64,
        avail_virtual: u64,
        avail_ext_virtual: u64,
    }
    extern "system" {
        fn GlobalMemoryStatusEx(buffer: *mut MemStatus) -> i32;
    }
    let mut s: MemStatus = unsafe { std::mem::zeroed() };
    s.length = std::mem::size_of::<MemStatus>() as u32;
    if unsafe { GlobalMemoryStatusEx(&mut s) } != 0 {
        Some(s.avail_phys / (1024 * 1024))
    } else {
        None
    }
}

#[cfg(target_os = "linux")]
pub fn available_ram_mb() -> Option<u64> {
    let text = std::fs::read_to_string("/proc/meminfo").ok()?;
    for line in text.lines() {
        let Some(rest) = line.strip_prefix("MemAvailable:") else {
            continue;
        };
        let kb: u64 = rest.split_whitespace().next()?.parse().ok()?;
        return Some(kb / 1024);
    }
    None
}

#[cfg(target_os = "macos")]
pub fn available_ram_mb() -> Option<u64> {
    #[repr(C)]
    struct VmStatistics64 {
        free_count: u32,
        active_count: u32,
        inactive_count: u32,
        wire_count: u32,
        zero_fill_count: u64,
        reactivations: u64,
        pageins: u64,
        pageouts: u64,
        faults: u64,
        cow_faults: u64,
        lookups: u64,
        hits: u64,
        purges: u64,
        purgeable_count: u32,
        speculative_count: u32,
        decompressions: u64,
        compressions: u64,
        swapins: u64,
        swapouts: u64,
        compressor_page_count: u32,
        throttled_count: u32,
        external_page_count: u32,
        internal_page_count: u32,
        total_uncompressed_pages_in_compressor: u64,
    }
    extern "C" {
        fn mach_host_self() -> u32;
        fn mach_task_self() -> u32;
        fn mach_port_deallocate(task: u32, name: u32) -> i32;
        fn host_statistics64(
            host_priv: u32,
            flavor: i32,
            host_info_out: *mut VmStatistics64,
            host_info_out_cnt: *mut u32,
        ) -> i32;
        fn sysconf(name: i32) -> i64;
    }
    const HOST_VM_INFO64: i32 = 4;
    const HOST_VM_INFO64_COUNT: u32 =
        (std::mem::size_of::<VmStatistics64>() / std::mem::size_of::<i32>()) as u32;
    const _SC_PAGESIZE: i32 = 29; // Darwin sysconf(_SC_PAGESIZE)

    let mut vm_stat: VmStatistics64 = unsafe { std::mem::zeroed() };
    let mut count = HOST_VM_INFO64_COUNT;
    let host_port = unsafe { mach_host_self() };
    let ret = unsafe {
        host_statistics64(
            host_port,
            HOST_VM_INFO64,
            &mut vm_stat,
            &mut count,
        )
    };
    unsafe {
        mach_port_deallocate(mach_task_self(), host_port);
    }
    if ret == 0 {
        let page_size = unsafe { sysconf(_SC_PAGESIZE) };
        if page_size > 0 {
            let free_pages = vm_stat.free_count as u64 + vm_stat.inactive_count as u64;
            let free_bytes = free_pages * (page_size as u64);
            return Some(free_bytes / (1024 * 1024));
        }
    }
    None
}

#[cfg(not(any(windows, target_os = "linux", target_os = "macos")))]
pub fn available_ram_mb() -> Option<u64> {
    None
}

#[cfg(unix)]
pub fn set_executable(path: &Path) -> Result<(), String> {
    use std::os::unix::fs::PermissionsExt;
    let mut perms = std::fs::metadata(path)
        .map_err(|e| e.to_string())?
        .permissions();
    perms.set_mode(0o755);
    std::fs::set_permissions(path, perms).map_err(|e| e.to_string())
}

#[cfg(not(unix))]
pub fn set_executable(_path: &Path) -> Result<(), String> {
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn platform_id_roundtrip() {
        for id in [
            PlatformId::WindowsX64,
            PlatformId::LinuxX64Glibc,
            PlatformId::MacosArm64,
            PlatformId::MacosX64,
        ] {
            assert_eq!(PlatformId::from_str(id.as_str()).unwrap(), id);
        }
    }

    #[test]
    fn unsupported_platform_identifier_is_explicit() {
        let err = PlatformId::from_str("freebsd-x64").unwrap_err();
        assert!(err.contains("Unsupported platform identifier"));
    }

    #[test]
    fn current_platform_matches_compile_target() {
        let spec = current_platform().expect("test target must be supported");
        #[cfg(all(target_os = "windows", target_arch = "x86_64"))]
        assert_eq!(spec.id, PlatformId::WindowsX64);
        #[cfg(all(target_os = "linux", target_arch = "x86_64"))]
        assert_eq!(spec.id, PlatformId::LinuxX64Glibc);
        #[cfg(all(target_os = "macos", target_arch = "aarch64"))]
        assert_eq!(spec.id, PlatformId::MacosArm64);
        #[cfg(all(target_os = "macos", target_arch = "x86_64"))]
        assert_eq!(spec.id, PlatformId::MacosX64);
    }

    #[test]
    fn python_paths_follow_platform_layout() {
        let spec = current_platform().unwrap();
        #[cfg(target_os = "windows")]
        {
            assert_eq!(spec.venv_python_bin, "Scripts/python.exe");
            assert_eq!(spec.bundled_python_bin, "python.exe");
        }
        #[cfg(any(target_os = "linux", target_os = "macos"))]
        {
            assert_eq!(spec.venv_python_bin, "bin/python");
            assert_eq!(spec.bundled_python_bin, "bin/python3");
        }
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn macos_ram_detection() {
        let ram = available_ram_mb();
        assert!(ram.is_some(), "available_ram_mb should return Some on macOS");
        assert!(ram.unwrap() > 0, "available RAM should be positive");
    }
}
