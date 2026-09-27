use std::{
    fs::{self, OpenOptions},
    io::Write,
    panic,
    time::{SystemTime, UNIX_EPOCH},
};

const MAX_LOG_BYTES: u64 = 1024 * 1024;

pub fn install_panic_hook() {
    let default_hook = panic::take_hook();
    panic::set_hook(Box::new(move |info| {
        write(&format!("panic: {info}"));
        default_hook(info);
    }));
}

pub fn write(message: &str) {
    let Ok(dirs) = crate::storage::ensure_data_dirs() else {
        return;
    };
    let path = dirs.logs_dir.join("startup.log");
    if path.metadata().map(|value| value.len()).unwrap_or(0) > MAX_LOG_BYTES {
        let previous = dirs.logs_dir.join("startup.previous.log");
        let _ = fs::remove_file(&previous);
        let _ = fs::rename(&path, previous);
    }

    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|value| value.as_secs())
        .unwrap_or(0);
    if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) {
        let sanitized = message.replace(['\r', '\n'], " ");
        let _ = writeln!(file, "[{timestamp}] {sanitized}");
    }
}
