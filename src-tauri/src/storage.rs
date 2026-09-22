use std::{
    env, fs,
    io::Write,
    path::{Path, PathBuf},
    sync::atomic::{AtomicU64, Ordering},
};

#[derive(Debug)]
pub struct DataDirs {
    pub portable: bool,
    pub fallback_used: bool,
    pub data_dir: PathBuf,
    pub assets_dir: PathBuf,
    pub exports_dir: PathBuf,
    pub logs_dir: PathBuf,
    pub temp_dir: PathBuf,
}

pub fn ensure_data_dirs() -> Result<DataDirs, String> {
    if cfg!(target_os = "macos") {
        let data_dir = system_data_dir()?;
        return create_data_dirs(data_dir, false, false);
    }

    let portable_dir = portable_data_dir();
    if cfg!(target_os = "linux") {
        return linux_data_dirs(
            &portable_dir,
            &system_data_dir()?,
            env::var_os("APPIMAGE").is_some() || env::var_os("APPDIR").is_some(),
        );
    }
    match create_data_dirs(portable_dir.clone(), true, false) {
        Ok(dirs) => Ok(dirs),
        Err(_) => {
            let fallback_dir = system_data_dir()?;
            create_data_dirs(fallback_dir, false, true)
        }
    }
}

fn has_user_data(dir: &Path) -> bool {
    dir.join("miriago.sqlite").exists()
        || fs::read_dir(dir.join("assets"))
            .map(|mut entries| entries.next().is_some())
            .unwrap_or(false)
}

fn linux_data_dirs(
    portable_dir: &Path,
    system_dir: &Path,
    appimage: bool,
) -> Result<DataDirs, String> {
    // AppImage executables live inside a mount or extraction directory, not
    // beside the user's AppImage file. Never store new data there.
    if appimage {
        if has_user_data(portable_dir) {
            return Err(format!(
                "Existing data in AppImage directory {}. Back up and move MiriaGoData to {} before continuing; no data was moved or deleted.",
                portable_dir.display(), system_dir.display()
            ));
        }
        return create_data_dirs(system_dir.to_path_buf(), false, false);
    }

    let existing_portable = has_user_data(portable_dir);
    // A shipped MiriaGoData directory opts the ZIP into portable mode. Retain
    // an existing system database when a previously unwritable ZIP is moved.
    if !portable_dir.is_dir() || (!existing_portable && has_user_data(system_dir)) {
        return create_data_dirs(system_dir.to_path_buf(), false, false);
    }
    match create_data_dirs(portable_dir.to_path_buf(), true, false) {
        Ok(dirs) => Ok(dirs),
        Err(error) if existing_portable => Err(format!(
            "Existing portable data is not writable: {error}. Restore write access or back up and move the entire MiriaGoData directory; refusing to open an empty database elsewhere."
        )),
        Err(_) => create_data_dirs(system_dir.to_path_buf(), false, true),
    }
}

fn create_data_dirs(
    data_dir: PathBuf,
    portable: bool,
    fallback_used: bool,
) -> Result<DataDirs, String> {
    let assets_dir = data_dir.join("assets");
    let exports_dir = data_dir.join("exports");
    let logs_dir = data_dir.join("logs");
    let temp_dir = data_dir.join("temp");

    for dir in [&data_dir, &assets_dir, &exports_dir, &logs_dir, &temp_dir] {
        fs::create_dir_all(dir)
            .map_err(|error| format!("failed to create {}: {error}", dir.display()))?;
        verify_writable(dir)?;
    }

    Ok(DataDirs {
        portable,
        fallback_used,
        data_dir,
        assets_dir,
        exports_dir,
        logs_dir,
        temp_dir,
    })
}

fn verify_writable(dir: &Path) -> Result<(), String> {
    static NEXT_PROBE: AtomicU64 = AtomicU64::new(0);
    let path = dir.join(format!(
        ".miriago-write-probe-{}-{}",
        std::process::id(),
        NEXT_PROBE.fetch_add(1, Ordering::Relaxed)
    ));
    let mut file = fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&path)
        .map_err(|error| format!("cannot write to {}: {error}", dir.display()))?;
    let result = file.write_all(b"miriago");
    drop(file);
    let cleanup = fs::remove_file(&path);
    result
        .and(cleanup)
        .map_err(|error| format!("cannot write to {}: {error}", dir.display()))
}

fn portable_data_dir() -> PathBuf {
    let current_exe = env::current_exe().unwrap_or_else(|_| PathBuf::from("."));
    portable_data_dir_for_exe(current_exe)
}

fn portable_data_dir_for_exe(current_exe: PathBuf) -> PathBuf {
    current_exe
        .parent()
        .map(|parent| parent.join("MiriaGoData"))
        .unwrap_or_else(|| PathBuf::from("MiriaGoData"))
}

fn system_data_dir() -> Result<PathBuf, String> {
    let base =
        dirs::data_dir().ok_or_else(|| "could not resolve system data directory".to_string())?;
    Ok(base.join("MiriaGo"))
}

#[cfg(test)]
mod tests {
    use std::{
        fs,
        path::PathBuf,
        sync::atomic::{AtomicU64, Ordering},
    };

    use super::{linux_data_dirs, portable_data_dir_for_exe};

    struct TestDirs(PathBuf);

    impl TestDirs {
        fn new() -> Self {
            static NEXT: AtomicU64 = AtomicU64::new(0);
            let path = std::env::temp_dir().join(format!(
                "miriago-storage-test-{}-{}",
                std::process::id(),
                NEXT.fetch_add(1, Ordering::Relaxed)
            ));
            fs::create_dir_all(&path).unwrap();
            Self(path)
        }

        fn portable(&self) -> PathBuf {
            self.0.join("zip/MiriaGoData")
        }
        fn system(&self) -> PathBuf {
            self.0.join("system/MiriaGo")
        }
    }

    impl Drop for TestDirs {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn linux_installed_and_appimage_use_system_data() {
        let root = TestDirs::new();
        for appimage in [false, true] {
            let dirs = linux_data_dirs(&root.portable(), &root.system(), appimage).unwrap();
            assert_eq!(dirs.data_dir, root.system());
            assert!(!dirs.portable);
            assert!(!root.portable().exists());
        }
    }

    #[test]
    fn linux_portable_preserves_database_and_assets_across_reopen() {
        let root = TestDirs::new();
        fs::create_dir_all(root.portable()).unwrap();
        let dirs = linux_data_dirs(&root.portable(), &root.system(), false).unwrap();
        let db_path = dirs.data_dir.join("miriago.sqlite");
        let db = rusqlite::Connection::open(&db_path).unwrap();
        db.execute_batch("CREATE TABLE test(value TEXT); INSERT INTO test VALUES ('retained');")
            .unwrap();
        drop(db);
        fs::write(dirs.assets_dir.join("photo.jpg"), b"photo").unwrap();
        let reopened = linux_data_dirs(&root.portable(), &root.system(), false).unwrap();
        assert!(reopened.portable);
        let db = rusqlite::Connection::open(reopened.data_dir.join("miriago.sqlite")).unwrap();
        assert_eq!(
            db.query_row("SELECT value FROM test", [], |row| row.get::<_, String>(0))
                .unwrap(),
            "retained"
        );
        assert_eq!(
            fs::read(reopened.assets_dir.join("photo.jpg")).unwrap(),
            b"photo"
        );
        assert!(!root.system().exists());
    }

    #[test]
    fn linux_empty_zip_retains_previous_system_database() {
        let root = TestDirs::new();
        fs::create_dir_all(root.portable()).unwrap();
        fs::create_dir_all(root.system()).unwrap();
        fs::write(root.system().join("miriago.sqlite"), b"existing").unwrap();
        assert_eq!(
            linux_data_dirs(&root.portable(), &root.system(), false)
                .unwrap()
                .data_dir,
            root.system()
        );
    }

    #[test]
    fn linux_appimage_never_uses_writable_extracted_directory() {
        let root = TestDirs::new();
        fs::create_dir_all(root.portable()).unwrap();
        assert_eq!(
            linux_data_dirs(&root.portable(), &root.system(), true)
                .unwrap()
                .data_dir,
            root.system()
        );
        fs::write(root.portable().join("miriago.sqlite"), b"legacy").unwrap();
        assert!(linux_data_dirs(&root.portable(), &root.system(), true).is_err());
        assert_eq!(
            fs::read(root.portable().join("miriago.sqlite")).unwrap(),
            b"legacy"
        );
    }

    #[test]
    fn linux_new_portable_failure_falls_back_but_existing_data_does_not() {
        let root = TestDirs::new();
        fs::create_dir_all(root.portable()).unwrap();
        fs::write(root.portable().join("assets"), b"not a directory").unwrap();
        let dirs = linux_data_dirs(&root.portable(), &root.system(), false).unwrap();
        assert!(dirs.fallback_used);
        assert_eq!(dirs.data_dir, root.system());
        fs::write(root.portable().join("miriago.sqlite"), b"legacy").unwrap();
        assert!(linux_data_dirs(&root.portable(), &root.system(), false).is_err());
    }

    #[cfg(unix)]
    #[test]
    fn existing_directory_requires_write_permission() {
        use std::os::unix::fs::PermissionsExt;
        let root = TestDirs::new();
        let path = root.0.join("readonly");
        fs::create_dir(&path).unwrap();
        fs::set_permissions(&path, fs::Permissions::from_mode(0o555)).unwrap();
        let result = super::verify_writable(&path);
        fs::set_permissions(&path, fs::Permissions::from_mode(0o755)).unwrap();
        assert!(result.is_err(), "Run storage tests as a non-root user");
    }

    #[test]
    fn non_macos_portable_data_dir_uses_miriago_data_next_to_exe() {
        let exe = PathBuf::from("/opt/MiriaGo/MiriaGo.exe");

        assert_eq!(
            portable_data_dir_for_exe(exe),
            PathBuf::from("/opt/MiriaGo/MiriaGoData")
        );
    }
}
