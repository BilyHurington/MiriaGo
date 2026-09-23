use std::{
    collections::HashMap,
    fs::{self, File, OpenOptions},
    io::{Read, Write},
    path::{Component, Path, PathBuf},
    sync::atomic::{AtomicU64, Ordering},
    time::{SystemTime, UNIX_EPOCH},
};

use base64::{engine::general_purpose, Engine as _};

pub(super) const MAX_ASSET_BYTES: usize = 64 * 1024 * 1024;
// Keep these asset ceilings aligned with Dart's default PlanImportLimits.
const MAX_IMPORT_ASSETS: usize = 4096;
const MAX_IMPORT_BYTES: usize = 256 * 1024 * 1024;
const MAX_EXPORT_BYTES: usize = 512 * 1024 * 1024;

pub(super) fn safe_asset_path(path: &str) -> Result<PathBuf, String> {
    if !path.starts_with("assets/") || path.len() > 4096 {
        return Err("unsafe asset path".to_string());
    }
    for segment in path.split('/') {
        // Check Windows syntax on every host before constructing a native PathBuf.
        let stem = segment
            .split('.')
            .next()
            .unwrap_or_default()
            .trim_end_matches(' ')
            .to_ascii_uppercase();
        let reserved = matches!(
            stem.as_str(),
            "CON" | "PRN" | "AUX" | "NUL" | "CONIN$" | "CONOUT$"
        ) || ["COM", "LPT"].iter().any(|prefix| {
            stem.strip_prefix(prefix).is_some_and(|suffix| {
                matches!(
                    suffix,
                    "1" | "2"
                        | "3"
                        | "4"
                        | "5"
                        | "6"
                        | "7"
                        | "8"
                        | "9"
                        | "\u{b9}"
                        | "\u{b2}"
                        | "\u{b3}"
                )
            })
        });
        if segment.is_empty()
            || segment == "."
            || segment == ".."
            || segment.len() > 255
            || segment.ends_with(['.', ' '])
            || segment.chars().any(|c| {
                c.is_control() || matches!(c, '\\' | ':' | '<' | '>' | '"' | '|' | '?' | '*')
            })
            || reserved
        {
            return Err("unsafe asset path".to_string());
        }
    }
    Ok(PathBuf::from(path))
}

fn reject_link(metadata: &fs::Metadata) -> Result<(), String> {
    if metadata.file_type().is_symlink() {
        return Err("linked paths are not allowed".to_string());
    }
    #[cfg(windows)]
    {
        use std::os::windows::fs::MetadataExt;
        if metadata.file_attributes() & 0x400 != 0 {
            return Err("reparse points are not allowed".to_string());
        }
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt;
        if metadata.is_file() && metadata.nlink() > 1 {
            return Err("hard-linked files are not allowed".to_string());
        }
    }
    Ok(())
}

fn check_directory(path: &Path) -> Result<(), String> {
    let metadata = fs::symlink_metadata(path).map_err(|error| error.to_string())?;
    reject_link(&metadata)?;
    if !metadata.is_dir() {
        return Err("asset parent is not a directory".to_string());
    }
    Ok(())
}

fn check_file_or_missing(path: &Path) -> Result<(), String> {
    match fs::symlink_metadata(path) {
        Ok(metadata) => {
            reject_link(&metadata)?;
            if !metadata.is_file() {
                return Err("destination is not a regular file".to_string());
            }
            Ok(())
        }
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error.to_string()),
    }
}

fn create_directory(path: &Path) -> std::io::Result<()> {
    let mut builder = fs::DirBuilder::new();
    #[cfg(unix)]
    {
        use std::os::unix::fs::DirBuilderExt;
        builder.mode(0o700);
    }
    builder.create(path)
}

pub(super) fn resolve_asset_path(
    root: &Path,
    relative: &Path,
    create_parents: bool,
) -> Result<PathBuf, String> {
    // Internal PathBuf joins use backslashes on Windows. Validate components and
    // reconstruct the portable form; untrusted strings are checked before this.
    let portable = relative
        .components()
        .map(|component| match component {
            Component::Normal(name) => name.to_str().ok_or("invalid asset path encoding"),
            _ => Err("asset path must contain only normal relative components"),
        })
        .collect::<Result<Vec<_>, _>>()?
        .join("/");
    let relative = safe_asset_path(&portable)?;
    check_directory(root)?;
    let root = root.canonicalize().map_err(|error| error.to_string())?;
    let full = root.join(&relative);
    let mut current = root;
    for component in relative
        .parent()
        .ok_or("missing asset parent")?
        .components()
    {
        current.push(component);
        if create_parents {
            match create_directory(&current) {
                Ok(()) => {}
                Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => {}
                Err(error) => return Err(error.to_string()),
            }
        }
        match fs::symlink_metadata(&current) {
            Ok(_) => check_directory(&current)?,
            Err(error) if !create_parents && error.kind() == std::io::ErrorKind::NotFound => {}
            Err(error) => return Err(error.to_string()),
        }
    }
    check_file_or_missing(&full)?;
    Ok(full)
}

fn check_absolute_target(path: &Path) -> Result<(), String> {
    if !path.is_absolute() {
        return Err("destination must be absolute".to_string());
    }
    let mut current = PathBuf::new();
    for component in path
        .parent()
        .ok_or("missing destination parent")?
        .components()
    {
        if matches!(component, Component::ParentDir | Component::CurDir) {
            return Err("destination is not normalized".to_string());
        }
        current.push(component);
        if matches!(component, Component::Prefix(_)) {
            continue;
        }
        check_directory(&current)?;
    }
    check_file_or_missing(path)
}

fn decoded_length(encoded: &str) -> Result<usize, String> {
    if encoded.len() % 4 != 0 {
        return Err("invalid base64 length".to_string());
    }
    let padding = encoded
        .as_bytes()
        .iter()
        .rev()
        .take_while(|&&b| b == b'=')
        .count();
    if padding > 2 {
        return Err("invalid base64 padding".to_string());
    }
    (encoded.len() / 4)
        .checked_mul(3)
        .and_then(|n| n.checked_sub(padding))
        .ok_or_else(|| "invalid base64 length".to_string())
}

pub(super) fn decode_bounded(encoded: &str, limit: usize) -> Result<Vec<u8>, String> {
    if decoded_length(encoded)? > limit {
        return Err("decoded data exceeds byte limit".to_string());
    }
    let bytes = general_purpose::STANDARD
        .decode(encoded)
        .map_err(|error| error.to_string())?;
    if bytes.len() > limit {
        return Err("decoded data exceeds byte limit".to_string());
    }
    Ok(bytes)
}

pub(super) fn read_bounded(path: &Path, limit: usize) -> Result<Vec<u8>, String> {
    check_absolute_target(path)?;
    let file = File::open(path).map_err(|error| error.to_string())?;
    let metadata = file.metadata().map_err(|error| error.to_string())?;
    reject_link(&metadata)?;
    if !metadata.is_file() {
        return Err("asset is not a regular file".to_string());
    }
    if metadata.len() > limit as u64 {
        return Err(format!(
            "ASSET_BYTE_LIMIT: {} bytes exceeds {}",
            metadata.len(),
            limit
        ));
    }
    let mut bytes = Vec::new();
    file.take(limit as u64 + 1)
        .read_to_end(&mut bytes)
        .map_err(|error| error.to_string())?;
    if bytes.len() > limit {
        return Err(format!(
            "ASSET_BYTE_LIMIT: at least {} bytes exceeds {}",
            bytes.len(),
            limit
        ));
    }
    Ok(bytes)
}

fn unique_name(prefix: &str) -> String {
    static NEXT: AtomicU64 = AtomicU64::new(0);
    format!(
        "{prefix}-{}-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    )
}

fn exclusive_file(path: &Path) -> std::io::Result<File> {
    let mut options = OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    options.open(path)
}

pub(super) fn atomic_write(path: &Path, bytes: &[u8]) -> Result<(), String> {
    atomic_write_with(path, |file| file.write_all(bytes))
}

fn atomic_write_with(
    path: &Path,
    write: impl FnOnce(&mut File) -> std::io::Result<()>,
) -> Result<(), String> {
    check_absolute_target(path)?;
    let parent = path.parent().ok_or("missing destination parent")?;
    let staged = parent.join(unique_name(".miriago-write"));
    let mut file = exclusive_file(&staged).map_err(|error| error.to_string())?;
    let result = write(&mut file).and_then(|()| file.sync_all());
    drop(file);
    let result = result.map_err(|error| error.to_string()).and_then(|()| {
        check_absolute_target(path)?;
        fs::rename(&staged, path).map_err(|error| error.to_string())
    });
    if let Err(error) = result {
        return match fs::remove_file(&staged) {
            Ok(()) => Err(error),
            Err(cleanup) => Err(format!("{error}; failed to clean staging file: {cleanup}")),
        };
    }
    Ok(())
}

#[derive(Debug, Default)]
struct RestoredAssets {
    paths: HashMap<String, String>,
    directory: Option<OwnedImportDirectory>,
}

fn restore_assets(root: &Path, assets: HashMap<String, String>) -> Result<RestoredAssets, String> {
    restore_assets_with(
        root,
        assets,
        MAX_IMPORT_ASSETS,
        MAX_ASSET_BYTES,
        MAX_IMPORT_BYTES,
        |path, bytes| {
            let mut file = exclusive_file(path).map_err(|error| error.to_string())?;
            file.write_all(bytes)
                .and_then(|()| file.sync_all())
                .map_err(|error| error.to_string())
        },
    )
}

fn restore_assets_with(
    root: &Path,
    assets: HashMap<String, String>,
    count_limit: usize,
    asset_limit: usize,
    total_limit: usize,
    mut write: impl FnMut(&Path, &[u8]) -> Result<(), String>,
) -> Result<RestoredAssets, String> {
    if assets.len() > count_limit {
        return Err("import asset count exceeds limit".to_string());
    }
    let mut total = 0usize;
    for (path, encoded) in &assets {
        safe_asset_path(path)?;
        let length = decoded_length(encoded)?;
        total = total
            .checked_add(length)
            .ok_or("import byte count overflow")?;
        if length > asset_limit || total > total_limit {
            return Err("import decoded bytes exceed limit".to_string());
        }
    }
    if assets.is_empty() {
        return Ok(RestoredAssets::default());
    }
    let package_name = unique_name("import");
    let relative_dir = PathBuf::from("assets/imported_plan_assets").join(package_name);
    // Resolve a prospective child to create and validate only the shared parents.
    let directory = resolve_asset_path(root, &relative_dir, true)?;
    create_directory(&directory).map_err(|error| error.to_string())?;
    let result = (|| {
        let identity = fs::symlink_metadata(&directory).map_err(|error| error.to_string())?;
        reject_link(&identity)?;
        let mut restored = HashMap::new();
        let mut entries: Vec<_> = assets.into_iter().collect();
        entries.sort_by(|a, b| a.0.cmp(&b.0));
        for (path, encoded) in entries {
            let bytes = decode_bounded(&encoded, asset_limit)?;
            if bytes.is_empty() {
                continue;
            }
            let relative = relative_dir.join(safe_asset_path(&path)?);
            let full = resolve_asset_path(root, &relative, true)?;
            write(&full, &bytes)?;
            restored.insert(
                path,
                relative
                    .components()
                    .map(|c| c.as_os_str().to_string_lossy())
                    .collect::<Vec<_>>()
                    .join("/"),
            );
        }
        let owned = (!restored.is_empty()).then(|| OwnedImportDirectory {
            path: directory.clone(),
            identity,
        });
        Ok::<_, String>(RestoredAssets {
            paths: restored,
            directory: owned,
        })
    })();
    if result
        .as_ref()
        .map_or(true, |restored| restored.paths.is_empty())
    {
        if let Err(cleanup) = fs::remove_dir_all(&directory) {
            return Err(format!(
                "{}; failed to clean import directory: {cleanup}",
                result.err().unwrap_or_default()
            ));
        }
    }
    result
}

#[derive(Debug)]
struct OwnedImportDirectory {
    path: PathBuf,
    identity: fs::Metadata,
}

impl OwnedImportDirectory {
    fn cleanup(&self) -> Result<(), String> {
        // Only paths captured at exclusive directory creation enter this registry.
        // Reject replacement directories and links before any recursive deletion.
        for ancestor in self.path.ancestors() {
            check_directory(ancestor)?;
        }
        let current = fs::symlink_metadata(&self.path).map_err(|error| error.to_string())?;
        if !same_directory_identity(&self.identity, &current) {
            return Err("restored asset directory ownership changed".to_string());
        }
        let mut pending = vec![self.path.clone()];
        while let Some(directory) = pending.pop() {
            for entry in fs::read_dir(directory).map_err(|error| error.to_string())? {
                let path = entry.map_err(|error| error.to_string())?.path();
                let metadata = fs::symlink_metadata(&path).map_err(|error| error.to_string())?;
                reject_link(&metadata)?;
                if metadata.is_dir() {
                    pending.push(path);
                } else if !metadata.is_file() {
                    return Err("restored asset directory contains a non-regular file".to_string());
                }
            }
        }
        fs::remove_dir_all(&self.path).map_err(|error| error.to_string())
    }
}

fn same_directory_identity(original: &fs::Metadata, current: &fs::Metadata) -> bool {
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt;
        original.dev() == current.dev() && original.ino() == current.ino()
    }
    #[cfg(windows)]
    {
        use std::os::windows::fs::MetadataExt;
        original.creation_time() == current.creation_time()
    }
}

fn restore_token() -> Result<String, String> {
    let mut bytes = [0u8; 32];
    #[cfg(unix)]
    File::open("/dev/urandom")
        .and_then(|mut random| random.read_exact(&mut bytes))
        .map_err(|error| error.to_string())?;
    #[cfg(windows)]
    {
        #[link(name = "bcrypt")]
        extern "system" {
            fn BCryptGenRandom(
                algorithm: *mut std::ffi::c_void,
                buffer: *mut u8,
                length: u32,
                flags: u32,
            ) -> i32;
        }
        // SAFETY: the OS fills the live 32-byte buffer using its preferred RNG.
        let status = unsafe {
            BCryptGenRandom(
                std::ptr::null_mut(),
                bytes.as_mut_ptr(),
                bytes.len() as u32,
                2,
            )
        };
        if status < 0 {
            return Err("could not generate import ownership token".to_string());
        }
    }
    Ok(general_purpose::URL_SAFE_NO_PAD.encode(bytes))
}

#[derive(Default)]
pub(super) struct ImportRestorations {
    pending: HashMap<String, OwnedImportDirectory>,
}

impl ImportRestorations {
    pub(super) fn restore(
        &mut self,
        root: &Path,
        assets: HashMap<String, String>,
    ) -> Result<(HashMap<String, String>, Option<String>), String> {
        if self.pending.len() >= 128 {
            return Err("too many unfinished asset restorations".to_string());
        }
        let token = restore_token()?;
        if self.pending.contains_key(&token) {
            return Err("import ownership token collision".to_string());
        }
        let restored = restore_assets(root, assets)?;
        let token = restored.directory.map(|directory| {
            self.pending.insert(token.clone(), directory);
            token
        });
        Ok((restored.paths, token))
    }

    pub(super) fn cleanup(&mut self, token: &str) -> Result<(), String> {
        self.pending
            .get(token)
            .ok_or("unknown or consumed import ownership token")?
            .cleanup()?;
        self.pending.remove(token);
        Ok(())
    }

    pub(super) fn finalize(&mut self, token: &str) -> Result<(), String> {
        self.pending
            .remove(token)
            .ok_or("unknown or consumed import ownership token")?;
        Ok(())
    }
}

pub(super) fn validated_extension(extension: &str) -> Result<String, String> {
    let extension = extension
        .trim()
        .trim_start_matches('.')
        .to_ascii_lowercase();
    if extension.is_empty()
        || extension.len() > 16
        || !extension.chars().all(|c| c.is_ascii_alphanumeric())
    {
        return Err("invalid export extension".to_string());
    }
    Ok(extension)
}

pub(super) struct ExportAuthorization {
    selected: Option<(String, String)>,
}

impl ExportAuthorization {
    pub(super) const fn new() -> Self {
        Self { selected: None }
    }

    pub(super) fn clear(&mut self) {
        self.selected = None;
    }

    // Only the native save-dialog handler may issue an authorization.
    pub(super) fn authorize(
        &mut self,
        mut path: PathBuf,
        extension: &str,
    ) -> Result<String, String> {
        self.clear();
        let extension = validated_extension(extension)?;
        if !path.is_absolute() {
            return Err("save-dialog destination must be absolute".to_string());
        }
        let filename = path
            .file_name()
            .and_then(|s| s.to_str())
            .ok_or("invalid export filename")?;
        safe_asset_path(&format!("assets/{filename}"))?;
        if path.extension().is_none() {
            path.set_extension(&extension);
            if fs::symlink_metadata(&path).is_ok() {
                return Err(
                    "select the existing file with its extension to confirm replacement"
                        .to_string(),
                );
            }
        }
        if !path
            .extension()
            .and_then(|s| s.to_str())
            .is_some_and(|s| s.eq_ignore_ascii_case(&extension))
        {
            return Err("selected file extension does not match export type".to_string());
        }
        let parent = path
            .parent()
            .ok_or("missing export parent")?
            .canonicalize()
            .map_err(|error| error.to_string())?;
        let path = parent.join(path.file_name().ok_or("missing export filename")?);
        check_absolute_target(&path)?;
        let path = path
            .to_str()
            .ok_or("invalid export path encoding")?
            .to_string();
        self.selected = Some((path.clone(), extension));
        Ok(path)
    }

    pub(super) fn write(
        &mut self,
        path: &str,
        extension: &str,
        encoded: &str,
    ) -> Result<String, String> {
        let extension = validated_extension(extension)?;
        let selected = self
            .selected
            .as_ref()
            .ok_or("export destination was not authorized by a save dialog")?;
        if selected.0 != path || selected.1 != extension {
            return Err(
                "export path or extension does not match save-dialog authorization".to_string(),
            );
        }
        let bytes = decode_bounded(encoded, MAX_EXPORT_BYTES)?;
        atomic_write(Path::new(path), &bytes)?;
        // Keep authorization on failure for retry, but consume it on success.
        self.clear();
        Ok(path.to_string())
    }
}

#[cfg(test)]
#[path = "desktop_file_io_tests.rs"]
mod tests;
