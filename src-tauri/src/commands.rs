use std::{collections::HashMap, fs, path::PathBuf};

use base64::{engine::general_purpose, Engine as _};
use serde::{Deserialize, Serialize};

use crate::storage;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LauncherInfo {
    pub app_version: String,
    pub platform: String,
    pub portable: bool,
    pub fallback_used: bool,
    pub data_dir: String,
    pub assets_dir: String,
    pub exports_dir: String,
    pub logs_dir: String,
    pub temp_dir: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrepareExportDestinationRequest {
    pub file_name: String,
    pub mime_type: String,
    pub extension: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WriteExportFileRequest {
    pub path: String,
    pub extension: String,
    pub data_base64: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SaveDesktopStateRequest {
    pub state_json: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RestoreImportAssetsRequest {
    pub package_id: Option<String>,
    pub source_name: Option<String>,
    pub assets_base64: HashMap<String, String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ReadAssetRequest {
    pub path: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ReadAssetResult {
    pub data_base64: String,
    pub mime_type: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RestoreImportAssetsResult {
    pub restored_paths: HashMap<String, String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DesktopStateResult {
    pub state_json: Option<String>,
    pub database_path: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ExportDestinationResult {
    pub action: String,
    pub path: Option<String>,
}

impl From<storage::DataDirs> for LauncherInfo {
    fn from(value: storage::DataDirs) -> Self {
        Self {
            app_version: env!("CARGO_PKG_VERSION").to_string(),
            platform: std::env::consts::OS.to_string(),
            portable: value.portable,
            fallback_used: value.fallback_used,
            data_dir: value.data_dir.display().to_string(),
            assets_dir: value.assets_dir.display().to_string(),
            exports_dir: value.exports_dir.display().to_string(),
            logs_dir: value.logs_dir.display().to_string(),
            temp_dir: value.temp_dir.display().to_string(),
        }
    }
}

#[tauri::command]
pub fn launcher_info() -> Result<LauncherInfo, String> {
    storage::ensure_data_dirs().map(LauncherInfo::from)
}

#[tauri::command]
pub fn ensure_data_dirs() -> Result<LauncherInfo, String> {
    storage::ensure_data_dirs().map(LauncherInfo::from)
}

#[tauri::command]
pub fn prepare_export_destination(
    request: PrepareExportDestinationRequest,
) -> Result<ExportDestinationResult, String> {
    let dirs = storage::ensure_data_dirs()?;
    let extension = normalize_extension(&request.extension);
    let label = export_filter_label(&request.mime_type, &extension);

    let mut dialog = rfd::FileDialog::new()
        .set_directory(dirs.exports_dir)
        .set_file_name(&request.file_name);
    if !extension.is_empty() {
        let filters = [extension.as_str()];
        dialog = dialog.add_filter(&label, &filters);
    }

    let path = match dialog.save_file() {
        Some(path) => path,
        None => {
            return Ok(ExportDestinationResult {
                action: "canceled".to_string(),
                path: None,
            });
        }
    };

    Ok(ExportDestinationResult {
        action: "selected".to_string(),
        path: Some(ensure_extension(path, &extension).display().to_string()),
    })
}

#[tauri::command]
pub fn write_export_file(request: WriteExportFileRequest) -> Result<ExportDestinationResult, String> {
    let extension = normalize_extension(&request.extension);
    let path = ensure_extension(PathBuf::from(&request.path), &extension);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    let bytes = general_purpose::STANDARD
        .decode(request.data_base64)
        .map_err(|error| error.to_string())?;
    fs::write(&path, bytes).map_err(|error| error.to_string())?;
    Ok(ExportDestinationResult {
        action: "saved".to_string(),
        path: Some(path.display().to_string()),
    })
}

#[tauri::command]
pub fn load_desktop_state() -> Result<DesktopStateResult, String> {
    let database = crate::desktop_db::DesktopDatabase::open()?;
    let state_json = database.load_state_json()?;
    Ok(DesktopStateResult {
        state_json,
        database_path: database.path().display().to_string(),
    })
}

#[tauri::command]
pub fn save_desktop_state(request: SaveDesktopStateRequest) -> Result<DesktopStateResult, String> {
    let mut database = crate::desktop_db::DesktopDatabase::open()?;
    database.save_state_json(&request.state_json)?;
    Ok(DesktopStateResult {
        state_json: Some(request.state_json),
        database_path: database.path().display().to_string(),
    })
}

#[tauri::command]
pub fn restore_import_assets(
    request: RestoreImportAssetsRequest,
) -> Result<RestoreImportAssetsResult, String> {
    let dirs = storage::ensure_data_dirs()?;
    let package_dir = safe_directory_name(
        request
            .package_id
            .as_deref()
            .filter(|value| !value.trim().is_empty())
            .or(request.source_name.as_deref())
            .unwrap_or("imported_package"),
    );
    let mut restored_paths = HashMap::new();

    for (package_path, data_base64) in request.assets_base64 {
        let relative_package_path = safe_asset_path(&package_path)?;
        let bytes = general_purpose::STANDARD
            .decode(data_base64)
            .map_err(|error| error.to_string())?;
        if bytes.is_empty() {
            continue;
        }

        let local_relative_path = PathBuf::from("assets")
            .join("imported_plan_assets")
            .join(&package_dir)
            .join(relative_package_path);
        let local_full_path = dirs.data_dir.join(&local_relative_path);
        if let Some(parent) = local_full_path.parent() {
            fs::create_dir_all(parent).map_err(|error| error.to_string())?;
        }
        fs::write(&local_full_path, bytes).map_err(|error| error.to_string())?;
        restored_paths.insert(package_path, local_relative_path.display().to_string());
    }

    Ok(RestoreImportAssetsResult { restored_paths })
}

#[tauri::command]
pub fn read_asset(request: ReadAssetRequest) -> Result<ReadAssetResult, String> {
    let dirs = storage::ensure_data_dirs()?;
    let relative_path = safe_local_asset_path(&request.path)?;
    let full_path = dirs.data_dir.join(&relative_path);
    let bytes = fs::read(&full_path)
        .map_err(|error| format!("failed to read {}: {error}", full_path.display()))?;

    Ok(ReadAssetResult {
        data_base64: general_purpose::STANDARD.encode(bytes),
        mime_type: mime_type_for_path(&relative_path),
    })
}

fn normalize_extension(extension: &str) -> String {
    extension.trim().trim_start_matches('.').to_ascii_lowercase()
}

fn ensure_extension(path: PathBuf, extension: &str) -> PathBuf {
    if extension.is_empty() || path.extension().is_some() {
        return path;
    }
    path.with_extension(extension)
}

fn export_filter_label(mime_type: &str, extension: &str) -> String {
    match extension {
        "sjhplan" => "MiriaGo data package".to_string(),
        "csv" => "CSV file".to_string(),
        _ if !mime_type.is_empty() => mime_type.to_string(),
        _ => "Export file".to_string(),
    }
}

fn safe_asset_path(path: &str) -> Result<PathBuf, String> {
    if !path.starts_with("assets/") || path.ends_with('/') || path.contains('\\') {
        return Err(format!("unsafe asset path: {path}"));
    }
    let mut relative = PathBuf::new();
    for segment in path.split('/') {
        if segment.is_empty() || segment == "." || segment == ".." {
            return Err(format!("unsafe asset path: {path}"));
        }
        relative.push(segment);
    }
    Ok(relative)
}

fn safe_local_asset_path(path: &str) -> Result<PathBuf, String> {
    if !path.starts_with("assets/") || path.ends_with('/') || path.contains('\\') {
        return Err(format!("unsafe local asset path: {path}"));
    }
    let mut relative = PathBuf::new();
    for segment in path.split('/') {
        if segment.is_empty() || segment == "." || segment == ".." {
            return Err(format!("unsafe local asset path: {path}"));
        }
        relative.push(segment);
    }
    Ok(relative)
}

fn mime_type_for_path(path: &std::path::Path) -> String {
    match path
        .extension()
        .and_then(|extension| extension.to_str())
        .map(|extension| extension.to_ascii_lowercase())
        .as_deref()
    {
        Some("png") => "image/png",
        Some("webp") => "image/webp",
        Some("gif") => "image/gif",
        Some("svg") => "image/svg+xml",
        Some("jpg") | Some("jpeg") => "image/jpeg",
        _ => "application/octet-stream",
    }
    .to_string()
}

fn safe_directory_name(value: &str) -> String {
    let mut safe = String::new();
    let mut previous_underscore = false;
    for character in value.chars() {
        let valid = character.is_ascii_alphanumeric() || matches!(character, '-' | '_');
        if valid {
            safe.push(character);
            previous_underscore = false;
        } else if !previous_underscore {
            safe.push('_');
            previous_underscore = true;
        }
    }
    let trimmed = safe.trim_matches('_').to_string();
    if trimmed.is_empty() {
        "imported_package".to_string()
    } else {
        trimmed
    }
}
