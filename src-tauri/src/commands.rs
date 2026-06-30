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
pub struct SaveDesktopPlanBundleRequest {
    pub plan_json: String,
    pub visit_records_json: String,
    pub active_plan_id: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DeleteDesktopPlanRequest {
    pub plan_id: String,
    pub active_plan_id: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SetDesktopActivePlanRequest {
    pub plan_id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SaveDesktopSettingsRequest {
    pub settings_json: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SaveDesktopVisitRecordRequest {
    pub record_json: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DeleteDesktopVisitRecordRequest {
    pub record_id: String,
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

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WriteAssetRequest {
    pub path: String,
    pub data_base64: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FetchAnitabiStaticJsonRequest {
    pub file_name: String,
    pub version: Option<String>,
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

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AnitabiStaticJsonResult {
    pub body: String,
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
pub fn write_export_file(
    request: WriteExportFileRequest,
) -> Result<ExportDestinationResult, String> {
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
pub fn save_desktop_plan_bundle(
    request: SaveDesktopPlanBundleRequest,
) -> Result<DesktopStateResult, String> {
    let mut database = crate::desktop_db::DesktopDatabase::open()?;
    database.save_plan_bundle_json(
        &request.plan_json,
        &request.visit_records_json,
        request.active_plan_id.as_deref(),
    )?;
    Ok(DesktopStateResult {
        state_json: None,
        database_path: database.path().display().to_string(),
    })
}

#[tauri::command]
pub fn delete_desktop_plan(
    request: DeleteDesktopPlanRequest,
) -> Result<DesktopStateResult, String> {
    let mut database = crate::desktop_db::DesktopDatabase::open()?;
    database.delete_plan(&request.plan_id, request.active_plan_id.as_deref())?;
    Ok(DesktopStateResult {
        state_json: None,
        database_path: database.path().display().to_string(),
    })
}

#[tauri::command]
pub fn set_desktop_active_plan(
    request: SetDesktopActivePlanRequest,
) -> Result<DesktopStateResult, String> {
    let mut database = crate::desktop_db::DesktopDatabase::open()?;
    database.set_active_plan(&request.plan_id)?;
    Ok(DesktopStateResult {
        state_json: None,
        database_path: database.path().display().to_string(),
    })
}

#[tauri::command]
pub fn save_desktop_settings(
    request: SaveDesktopSettingsRequest,
) -> Result<DesktopStateResult, String> {
    let mut database = crate::desktop_db::DesktopDatabase::open()?;
    database.save_settings_json(&request.settings_json)?;
    Ok(DesktopStateResult {
        state_json: None,
        database_path: database.path().display().to_string(),
    })
}

#[tauri::command]
pub fn save_desktop_visit_record(
    request: SaveDesktopVisitRecordRequest,
) -> Result<DesktopStateResult, String> {
    let mut database = crate::desktop_db::DesktopDatabase::open()?;
    database.save_visit_record_json(&request.record_json)?;
    Ok(DesktopStateResult {
        state_json: None,
        database_path: database.path().display().to_string(),
    })
}

#[tauri::command]
pub fn delete_desktop_visit_record(
    request: DeleteDesktopVisitRecordRequest,
) -> Result<DesktopStateResult, String> {
    let mut database = crate::desktop_db::DesktopDatabase::open()?;
    database.delete_visit_record(&request.record_id)?;
    Ok(DesktopStateResult {
        state_json: None,
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
        restored_paths.insert(
            package_path.replace('\\', "/"),
            relative_path_string(&local_relative_path),
        );
    }

    Ok(RestoreImportAssetsResult { restored_paths })
}

#[tauri::command]
pub fn write_asset(request: WriteAssetRequest) -> Result<ReadAssetResult, String> {
    let dirs = storage::ensure_data_dirs()?;
    let relative_path = safe_local_asset_path(&request.path)?;
    let bytes = general_purpose::STANDARD
        .decode(request.data_base64)
        .map_err(|error| error.to_string())?;
    if bytes.is_empty() {
        return Err("asset data is empty".to_string());
    }

    let full_path = dirs.data_dir.join(&relative_path);
    if let Some(parent) = full_path.parent() {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    fs::write(&full_path, &bytes).map_err(|error| error.to_string())?;

    Ok(ReadAssetResult {
        data_base64: general_purpose::STANDARD.encode(bytes),
        mime_type: mime_type_for_path(&relative_path),
    })
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

#[tauri::command]
pub fn fetch_anitabi_static_json(
    request: FetchAnitabiStaticJsonRequest,
) -> Result<AnitabiStaticJsonResult, String> {
    let file_name = safe_anitabi_static_file_name(&request.file_name)?;
    let query = request
        .version
        .as_deref()
        .and_then(safe_anitabi_static_version)
        .map(|version| format!("?v={version}"))
        .unwrap_or_default();
    let primary_url = format!("https://www.anitabi.cn/d/{file_name}{query}");
    let fallback_url = format!("https://anitabi.cn/d/{file_name}{query}");

    let body = fetch_text(&primary_url).or_else(|_| fetch_text(&fallback_url))?;
    Ok(AnitabiStaticJsonResult { body })
}

fn normalize_extension(extension: &str) -> String {
    extension
        .trim()
        .trim_start_matches('.')
        .to_ascii_lowercase()
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

fn safe_anitabi_static_file_name(file_name: &str) -> Result<String, String> {
    let Some(stem) = file_name
        .strip_prefix('g')
        .and_then(|value| value.strip_suffix(".json"))
    else {
        return Err(format!("invalid Anitabi static file name: {file_name}"));
    };
    if !stem.chars().all(|character| character.is_ascii_digit()) {
        return Err(format!("invalid Anitabi static file name: {file_name}"));
    }
    Ok(file_name.to_string())
}

fn safe_anitabi_static_version(version: &str) -> Option<String> {
    let trimmed = version.trim();
    if trimmed.is_empty() {
        return None;
    }
    if !trimmed
        .chars()
        .all(|character| character.is_ascii_alphanumeric() || character == '-' || character == '_')
    {
        return None;
    }
    Some(trimmed.to_string())
}

fn fetch_text(url: &str) -> Result<String, String> {
    let response = reqwest::blocking::Client::builder()
        .user_agent("MiriaGo desktop launcher")
        .build()
        .map_err(|error| error.to_string())?
        .get(url)
        .send()
        .map_err(|error| error.to_string())?;
    if !response.status().is_success() {
        return Err(format!("request failed: {}", response.status()));
    }
    response.text().map_err(|error| error.to_string())
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

fn relative_path_string(path: &std::path::Path) -> String {
    path.components()
        .map(|component| component.as_os_str().to_string_lossy())
        .collect::<Vec<_>>()
        .join("/")
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

#[cfg(test)]
mod tests {
    use super::{safe_asset_path, safe_local_asset_path};

    #[test]
    fn asset_paths_allow_safe_relative_assets() {
        assert!(safe_asset_path("assets/full_references/point.jpg").is_ok());
        assert!(safe_local_asset_path("assets/reference_full/point.webp").is_ok());
    }

    #[test]
    fn asset_paths_reject_traversal_and_absolute_paths() {
        for path in [
            "/assets/reference_full/point.jpg",
            "assets/../point.jpg",
            "assets//point.jpg",
            r"assets\point.jpg",
            "tmp/point.jpg",
        ] {
            assert!(safe_asset_path(path).is_err(), "{path}");
            assert!(safe_local_asset_path(path).is_err(), "{path}");
        }
    }
}
