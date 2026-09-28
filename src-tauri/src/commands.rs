use std::{
    collections::HashMap,
    fs,
    path::PathBuf,
    process::Command,
    sync::{LazyLock, Mutex},
};

use base64::{engine::general_purpose, Engine as _};
use serde::{Deserialize, Serialize};

use crate::storage;

#[path = "desktop_file_io.rs"]
mod file_io;

/// Serializes desktop database commands now that they run off the main
/// thread; the Flutter side already issues writes one at a time.
static DESKTOP_DB: Mutex<()> = Mutex::new(());

fn lock_desktop_db() -> std::sync::MutexGuard<'static, ()> {
    DESKTOP_DB
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// Runs file, database and network work on the blocking pool so the main
/// thread (and with it the window) never waits on it. Synchronous Tauri
/// commands run on the main thread.
async fn run_blocking<T: Send + 'static>(
    work: impl FnOnce() -> Result<T, String> + Send + 'static,
) -> Result<T, String> {
    tauri::async_runtime::spawn_blocking(work)
        .await
        .map_err(|error| error.to_string())?
}

static EXPORT_AUTHORIZATION: Mutex<file_io::ExportAuthorization> =
    Mutex::new(file_io::ExportAuthorization::new());
static IMPORT_RESTORATIONS: LazyLock<Mutex<file_io::ImportRestorations>> =
    LazyLock::new(|| Mutex::new(file_io::ImportRestorations::default()));

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
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ImportAssetsTokenRequest {
    pub restore_token: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ReadAssetRequest {
    pub path: String,
    pub max_bytes: Option<u64>,
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
    pub base_url: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DesktopLogRequest {
    pub message: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OpenDesktopDirectoryRequest {
    pub target: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ReadAssetResult {
    pub data_base64: String,
    pub mime_type: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AssetFileResult {
    pub existed: bool,
    pub byte_length: u64,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RestoreImportAssetsResult {
    pub restored_paths: HashMap<String, String>,
    pub restore_token: Option<String>,
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
pub fn append_desktop_log(request: DesktopLogRequest) -> Result<(), String> {
    let message: String = request.message.chars().take(8000).collect();
    crate::startup_log::write(&format!("flutter: {message}"));
    Ok(())
}

#[tauri::command]
pub fn open_desktop_directory(request: OpenDesktopDirectoryRequest) -> Result<(), String> {
    let dirs = storage::ensure_data_dirs()?;
    let path = match request.target.as_str() {
        "data" => dirs.data_dir,
        "logs" => dirs.logs_dir,
        _ => return Err("unsupported desktop directory target".to_string()),
    };

    #[cfg(target_os = "windows")]
    let status = Command::new("explorer").arg(&path).status();
    #[cfg(target_os = "macos")]
    let status = Command::new("open").arg(&path).status();
    #[cfg(all(not(target_os = "windows"), not(target_os = "macos")))]
    let status = Command::new("xdg-open").arg(&path).status();

    status
        .map_err(|error| format!("failed to open {}: {error}", path.display()))?
        .success()
        .then_some(())
        .ok_or_else(|| format!("failed to open {}", path.display()))
}

#[tauri::command]
pub fn prepare_export_destination(
    request: PrepareExportDestinationRequest,
) -> Result<ExportDestinationResult, String> {
    let mut authorization = EXPORT_AUTHORIZATION
        .lock()
        .map_err(|error| error.to_string())?;
    authorization.clear();
    let extension = file_io::validated_extension(&request.extension)?;
    let dirs = storage::ensure_data_dirs()?;
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

    let path = authorization.authorize(path, &extension)?;
    Ok(ExportDestinationResult {
        action: "selected".to_string(),
        path: Some(path),
    })
}

#[tauri::command]
pub async fn write_export_file(
    request: WriteExportFileRequest,
) -> Result<ExportDestinationResult, String> {
    run_blocking(move || write_export_file_blocking(request)).await
}

fn write_export_file_blocking(
    request: WriteExportFileRequest,
) -> Result<ExportDestinationResult, String> {
    let path = EXPORT_AUTHORIZATION
        .lock()
        .map_err(|error| error.to_string())?
        .write(&request.path, &request.extension, &request.data_base64)?;
    Ok(ExportDestinationResult {
        action: "saved".to_string(),
        path: Some(path),
    })
}

#[tauri::command]
pub async fn load_desktop_state() -> Result<DesktopStateResult, String> {
    run_blocking(load_desktop_state_blocking).await
}

fn load_desktop_state_blocking() -> Result<DesktopStateResult, String> {
    let _db = lock_desktop_db();
    crate::startup_log::write("opening desktop database");
    let result = (|| {
        let database = crate::desktop_db::DesktopDatabase::open()?;
        let state_json = database.load_state_json()?;
        Ok(DesktopStateResult {
            state_json,
            database_path: database.path().display().to_string(),
        })
    })();
    match &result {
        Ok(value) => crate::startup_log::write(&format!(
            "desktop database ready path={}",
            value.database_path
        )),
        Err(error) => crate::startup_log::write(&format!("desktop database failed: {error}")),
    }
    result
}

#[tauri::command]
pub async fn save_desktop_state(
    request: SaveDesktopStateRequest,
) -> Result<DesktopStateResult, String> {
    run_blocking(move || save_desktop_state_blocking(request)).await
}

fn save_desktop_state_blocking(
    request: SaveDesktopStateRequest,
) -> Result<DesktopStateResult, String> {
    let _db = lock_desktop_db();
    let mut database = crate::desktop_db::DesktopDatabase::open()?;
    database.save_state_json(&request.state_json)?;
    Ok(DesktopStateResult {
        state_json: Some(request.state_json),
        database_path: database.path().display().to_string(),
    })
}

#[tauri::command]
pub async fn save_desktop_plan_bundle(
    request: SaveDesktopPlanBundleRequest,
) -> Result<DesktopStateResult, String> {
    run_blocking(move || save_desktop_plan_bundle_blocking(request)).await
}

fn save_desktop_plan_bundle_blocking(
    request: SaveDesktopPlanBundleRequest,
) -> Result<DesktopStateResult, String> {
    let _db = lock_desktop_db();
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
pub async fn delete_desktop_plan(
    request: DeleteDesktopPlanRequest,
) -> Result<DesktopStateResult, String> {
    run_blocking(move || delete_desktop_plan_blocking(request)).await
}

fn delete_desktop_plan_blocking(
    request: DeleteDesktopPlanRequest,
) -> Result<DesktopStateResult, String> {
    let _db = lock_desktop_db();
    let mut database = crate::desktop_db::DesktopDatabase::open()?;
    database.delete_plan(&request.plan_id, request.active_plan_id.as_deref())?;
    Ok(DesktopStateResult {
        state_json: None,
        database_path: database.path().display().to_string(),
    })
}

#[tauri::command]
pub async fn set_desktop_active_plan(
    request: SetDesktopActivePlanRequest,
) -> Result<DesktopStateResult, String> {
    run_blocking(move || set_desktop_active_plan_blocking(request)).await
}

fn set_desktop_active_plan_blocking(
    request: SetDesktopActivePlanRequest,
) -> Result<DesktopStateResult, String> {
    let _db = lock_desktop_db();
    let mut database = crate::desktop_db::DesktopDatabase::open()?;
    database.set_active_plan(&request.plan_id)?;
    Ok(DesktopStateResult {
        state_json: None,
        database_path: database.path().display().to_string(),
    })
}

#[tauri::command]
pub async fn save_desktop_settings(
    request: SaveDesktopSettingsRequest,
) -> Result<DesktopStateResult, String> {
    run_blocking(move || save_desktop_settings_blocking(request)).await
}

fn save_desktop_settings_blocking(
    request: SaveDesktopSettingsRequest,
) -> Result<DesktopStateResult, String> {
    let _db = lock_desktop_db();
    let mut database = crate::desktop_db::DesktopDatabase::open()?;
    database.save_settings_json(&request.settings_json)?;
    Ok(DesktopStateResult {
        state_json: None,
        database_path: database.path().display().to_string(),
    })
}

#[tauri::command]
pub async fn save_desktop_visit_record(
    request: SaveDesktopVisitRecordRequest,
) -> Result<DesktopStateResult, String> {
    run_blocking(move || save_desktop_visit_record_blocking(request)).await
}

fn save_desktop_visit_record_blocking(
    request: SaveDesktopVisitRecordRequest,
) -> Result<DesktopStateResult, String> {
    let _db = lock_desktop_db();
    let mut database = crate::desktop_db::DesktopDatabase::open()?;
    database.save_visit_record_json(&request.record_json)?;
    Ok(DesktopStateResult {
        state_json: None,
        database_path: database.path().display().to_string(),
    })
}

#[tauri::command]
pub async fn delete_desktop_visit_record(
    request: DeleteDesktopVisitRecordRequest,
) -> Result<DesktopStateResult, String> {
    run_blocking(move || delete_desktop_visit_record_blocking(request)).await
}

fn delete_desktop_visit_record_blocking(
    request: DeleteDesktopVisitRecordRequest,
) -> Result<DesktopStateResult, String> {
    let _db = lock_desktop_db();
    let mut database = crate::desktop_db::DesktopDatabase::open()?;
    database.delete_visit_record(&request.record_id)?;
    Ok(DesktopStateResult {
        state_json: None,
        database_path: database.path().display().to_string(),
    })
}

#[tauri::command]
pub async fn restore_import_assets(
    request: RestoreImportAssetsRequest,
) -> Result<RestoreImportAssetsResult, String> {
    run_blocking(move || restore_import_assets_blocking(request)).await
}

fn restore_import_assets_blocking(
    request: RestoreImportAssetsRequest,
) -> Result<RestoreImportAssetsResult, String> {
    let dirs = storage::ensure_data_dirs()?;
    // Retain the IPC fields for compatibility; neither is a filesystem authority.
    let _ = (request.package_id, request.source_name);
    let (restored_paths, restore_token) = IMPORT_RESTORATIONS
        .lock()
        .map_err(|error| error.to_string())?
        .restore(&dirs.data_dir, request.assets_base64)?;
    Ok(RestoreImportAssetsResult {
        restored_paths,
        restore_token,
    })
}

#[tauri::command]
pub async fn cleanup_import_assets(request: ImportAssetsTokenRequest) -> Result<(), String> {
    run_blocking(move || cleanup_import_assets_blocking(request)).await
}

fn cleanup_import_assets_blocking(request: ImportAssetsTokenRequest) -> Result<(), String> {
    IMPORT_RESTORATIONS
        .lock()
        .map_err(|error| error.to_string())?
        .cleanup(&request.restore_token)
}

#[tauri::command]
pub async fn finalize_import_assets(request: ImportAssetsTokenRequest) -> Result<(), String> {
    run_blocking(move || finalize_import_assets_blocking(request)).await
}

fn finalize_import_assets_blocking(request: ImportAssetsTokenRequest) -> Result<(), String> {
    IMPORT_RESTORATIONS
        .lock()
        .map_err(|error| error.to_string())?
        .finalize(&request.restore_token)
}

#[tauri::command]
pub async fn write_asset(request: WriteAssetRequest) -> Result<ReadAssetResult, String> {
    run_blocking(move || write_asset_blocking(request)).await
}

fn write_asset_blocking(request: WriteAssetRequest) -> Result<ReadAssetResult, String> {
    let dirs = storage::ensure_data_dirs()?;
    let relative_path = safe_local_asset_path(&request.path)?;
    let bytes = file_io::decode_bounded(&request.data_base64, file_io::MAX_ASSET_BYTES)?;
    if bytes.is_empty() {
        return Err("asset data is empty".to_string());
    }

    let full_path = file_io::resolve_asset_path(&dirs.data_dir, &relative_path, true)?;
    file_io::atomic_write(&full_path, &bytes)?;

    Ok(ReadAssetResult {
        data_base64: general_purpose::STANDARD.encode(bytes),
        mime_type: mime_type_for_path(&relative_path),
    })
}

#[tauri::command]
pub async fn read_asset(request: ReadAssetRequest) -> Result<ReadAssetResult, String> {
    run_blocking(move || read_asset_blocking(request)).await
}

fn read_asset_blocking(request: ReadAssetRequest) -> Result<ReadAssetResult, String> {
    let dirs = storage::ensure_data_dirs()?;
    let relative_path = safe_local_asset_path(&request.path)?;
    let full_path = file_io::resolve_asset_path(&dirs.data_dir, &relative_path, false)?;
    let limit = asset_read_limit(request.max_bytes)?;
    let bytes = file_io::read_bounded(&full_path, limit)?;

    Ok(ReadAssetResult {
        data_base64: general_purpose::STANDARD.encode(bytes),
        mime_type: mime_type_for_path(&relative_path),
    })
}

fn asset_read_limit(requested: Option<u64>) -> Result<usize, String> {
    match requested {
        None => Ok(file_io::MAX_ASSET_BYTES),
        Some(value) if value > 0 && value <= file_io::MAX_ASSET_BYTES as u64 => Ok(value as usize),
        _ => Err("maxBytes must be between 1 and the asset byte limit".to_string()),
    }
}

#[tauri::command]
pub async fn inspect_reference_cache_asset(
    request: ReadAssetRequest,
) -> Result<AssetFileResult, String> {
    run_blocking(move || inspect_reference_cache_asset_blocking(request)).await
}

fn inspect_reference_cache_asset_blocking(
    request: ReadAssetRequest,
) -> Result<AssetFileResult, String> {
    let dirs = storage::ensure_data_dirs()?;
    let relative_path = safe_reference_cache_path(&request.path)?;
    let full_path = file_io::resolve_asset_path(&dirs.data_dir, &relative_path, false)?;
    match fs::metadata(&full_path) {
        Ok(metadata) => Ok(AssetFileResult {
            existed: metadata.is_file(),
            byte_length: if metadata.is_file() {
                metadata.len()
            } else {
                0
            },
        }),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(AssetFileResult {
            existed: false,
            byte_length: 0,
        }),
        Err(error) => Err(format!(
            "failed to inspect {}: {error}",
            full_path.display()
        )),
    }
}

#[tauri::command]
pub async fn delete_reference_cache_asset(
    request: ReadAssetRequest,
) -> Result<AssetFileResult, String> {
    run_blocking(move || delete_reference_cache_asset_blocking(request)).await
}

fn delete_reference_cache_asset_blocking(
    request: ReadAssetRequest,
) -> Result<AssetFileResult, String> {
    let dirs = storage::ensure_data_dirs()?;
    let relative_path = safe_reference_cache_path(&request.path)?;
    let full_path = file_io::resolve_asset_path(&dirs.data_dir, &relative_path, false)?;
    let byte_length = match fs::metadata(&full_path) {
        Ok(metadata) if metadata.is_file() => metadata.len(),
        Ok(_) => return Err("reference cache path is not a file".to_string()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            return Ok(AssetFileResult {
                existed: false,
                byte_length: 0,
            })
        }
        Err(error) => return Err(error.to_string()),
    };
    fs::remove_file(&full_path)
        .map_err(|error| format!("failed to delete {}: {error}", full_path.display()))?;
    Ok(AssetFileResult {
        existed: true,
        byte_length,
    })
}

#[tauri::command]
pub async fn fetch_anitabi_static_json(
    request: FetchAnitabiStaticJsonRequest,
) -> Result<AnitabiStaticJsonResult, String> {
    run_blocking(move || fetch_anitabi_static_json_blocking(request)).await
}

fn fetch_anitabi_static_json_blocking(
    request: FetchAnitabiStaticJsonRequest,
) -> Result<AnitabiStaticJsonResult, String> {
    let file_name = safe_anitabi_static_file_name(&request.file_name)?;
    let query = request
        .version
        .as_deref()
        .and_then(safe_anitabi_static_version)
        .map(|version| format!("?v={version}"))
        .unwrap_or_default();
    let base_url = safe_public_https_base_url(&request.base_url)?;
    let primary_url = format!("{base_url}/{file_name}{query}");
    let body = fetch_text(&primary_url)?;
    Ok(AnitabiStaticJsonResult { body })
}

fn safe_public_https_base_url(value: &str) -> Result<String, String> {
    let parsed = reqwest::Url::parse(value.trim()).map_err(|_| "invalid HTTPS base URL")?;
    if parsed.scheme() != "https"
        || parsed.host_str().is_none()
        || !parsed.username().is_empty()
        || parsed.password().is_some()
        || parsed.query().is_some()
        || parsed.fragment().is_some()
    {
        return Err("invalid HTTPS base URL".to_string());
    }
    let host = parsed.host_str().unwrap_or_default().to_ascii_lowercase();
    if is_local_or_private_host(&host) {
        return Err("local or private hosts are not allowed".to_string());
    }
    Ok(value.trim().trim_end_matches('/').to_string())
}

fn is_local_or_private_host(host: &str) -> bool {
    if host == "localhost"
        || host.ends_with(".localhost")
        || host.ends_with(".local")
        || host == "::1"
    {
        return true;
    }
    let octets = host
        .split('.')
        .map(str::parse::<u8>)
        .collect::<Result<Vec<_>, _>>();
    let Ok(octets) = octets else {
        return false;
    };
    if octets.len() != 4 {
        return false;
    }
    matches!(
        (octets[0], octets[1]),
        (0, _) | (10, _) | (127, _) | (169, 254) | (172, 16..=31) | (192, 168)
    )
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
    file_io::safe_asset_path(path)
}

fn safe_local_asset_path(path: &str) -> Result<PathBuf, String> {
    safe_asset_path(path)
}

fn safe_reference_cache_path(path: &str) -> Result<PathBuf, String> {
    let relative = safe_local_asset_path(path)?;
    if path.starts_with("assets/reference_full/")
        || path.starts_with("assets/reference_thumbnails/")
    {
        Ok(relative)
    } else {
        Err(format!(
            "path is not a downloadable reference cache: {path}"
        ))
    }
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

/// Largest Anitabi static file accepted (the index is about 2 MB).
const MAX_ANITABI_STATIC_BYTES: u64 = 16 * 1024 * 1024;

fn fetch_text(url: &str) -> Result<String, String> {
    use std::io::Read as _;

    let response = reqwest::blocking::Client::builder()
        .user_agent("MiriaGo desktop launcher")
        .connect_timeout(std::time::Duration::from_secs(10))
        .timeout(std::time::Duration::from_secs(40))
        .build()
        .map_err(|error| error.to_string())?
        .get(url)
        .send()
        .map_err(|error| error.to_string())?;
    if !response.status().is_success() {
        return Err(format!("request failed: {}", response.status()));
    }
    if response
        .content_length()
        .is_some_and(|length| length > MAX_ANITABI_STATIC_BYTES)
    {
        return Err("response too large".to_string());
    }
    let mut body = Vec::new();
    response
        .take(MAX_ANITABI_STATIC_BYTES + 1)
        .read_to_end(&mut body)
        .map_err(|error| error.to_string())?;
    if body.len() as u64 > MAX_ANITABI_STATIC_BYTES {
        return Err("response too large".to_string());
    }
    String::from_utf8(body).map_err(|error| error.to_string())
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

#[cfg(test)]
mod tests {
    use super::{
        safe_asset_path, safe_local_asset_path, safe_public_https_base_url,
        safe_reference_cache_path,
    };

    #[test]
    fn asset_read_optional_budget_preserves_default_and_rejects_expansion() {
        use super::{asset_read_limit, ReadAssetRequest};
        let old: ReadAssetRequest =
            serde_json::from_str(r#"{"path":"assets/reference_full/test.jpg"}"#).unwrap();
        assert_eq!(asset_read_limit(old.max_bytes).unwrap(), 64 * 1024 * 1024);
        let capped: ReadAssetRequest = serde_json::from_str(
            r#"{"path":"assets/reference_full/test.jpg","maxBytes":33554432}"#,
        )
        .unwrap();
        assert_eq!(
            asset_read_limit(capped.max_bytes).unwrap(),
            32 * 1024 * 1024
        );
        assert!(asset_read_limit(Some(0)).is_err());
        assert!(asset_read_limit(Some(64 * 1024 * 1024 + 1)).is_err());
        assert!(asset_read_limit(Some(u64::MAX)).is_err());
    }

    #[test]
    fn asset_read_smaller_budget_does_not_modify_original() {
        let root = std::env::temp_dir().join(format!(
            "miriago-read-cap-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::create_dir(&root).unwrap();
        let root = root.canonicalize().unwrap();
        let path = root.join("original.png");
        std::fs::write(&path, [1, 2, 3, 4]).unwrap();
        let result = super::file_io::read_bounded(&path, 3);
        assert!(result.unwrap_err().starts_with("ASSET_BYTE_LIMIT:"));
        assert_eq!(
            super::file_io::read_bounded(&path, 4).unwrap(),
            vec![1, 2, 3, 4]
        );
        assert_eq!(std::fs::read(&path).unwrap(), vec![1, 2, 3, 4]);
        std::fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn anitabi_static_base_url_rejects_unsafe_hosts() {
        assert_eq!(
            safe_public_https_base_url("https://www.anitabi.cn/d").unwrap(),
            "https://www.anitabi.cn/d"
        );
        assert!(safe_public_https_base_url("http://ww.anitabi.cn/d").is_err());
        assert!(safe_public_https_base_url("https://localhost:8080/d").is_err());
        assert!(safe_public_https_base_url("https://192.168.1.2/d").is_err());
        assert!(safe_public_https_base_url("https://example.com/d?token=x").is_err());
    }

    #[test]
    fn asset_paths_allow_safe_relative_assets() {
        assert!(safe_asset_path("assets/full_references/point.jpg").is_ok());
        assert!(safe_local_asset_path("assets/reference_full/point.webp").is_ok());
    }

    #[test]
    fn cache_cleanup_only_accepts_downloaded_reference_namespaces() {
        assert!(safe_reference_cache_path("assets/reference_full/point.webp").is_ok());
        assert!(safe_reference_cache_path("assets/reference_thumbnails/point.webp").is_ok());
        assert!(safe_reference_cache_path(
            "assets/imported_plan_assets/pkg/assets/full_references/point.webp"
        )
        .is_err());
        assert!(safe_reference_cache_path("assets/user_reference_images/point.webp").is_err());
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
