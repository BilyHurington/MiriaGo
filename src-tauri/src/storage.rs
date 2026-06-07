use std::{env, fs, path::PathBuf};

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
    let portable_dir = portable_data_dir();
    match create_data_dirs(portable_dir.clone(), true, false) {
        Ok(dirs) => Ok(dirs),
        Err(_) => {
            let fallback_dir = fallback_data_dir()?;
            create_data_dirs(fallback_dir, false, true)
        }
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

fn portable_data_dir() -> PathBuf {
    let current_exe = env::current_exe().unwrap_or_else(|_| PathBuf::from("."));

    if cfg!(target_os = "macos") {
        if let Some(app_bundle) = current_exe
            .ancestors()
            .find(|path| path.extension().is_some_and(|extension| extension == "app"))
        {
            if let Some(parent) = app_bundle.parent() {
                return parent.join("MiriaGoData");
            }
        }
    }

    current_exe
        .parent()
        .map(|parent| parent.join("data"))
        .unwrap_or_else(|| PathBuf::from("data"))
}

fn fallback_data_dir() -> Result<PathBuf, String> {
    let base = dirs::data_dir()
        .ok_or_else(|| "could not resolve system data directory".to_string())?;
    Ok(base.join("MiriaGo"))
}
