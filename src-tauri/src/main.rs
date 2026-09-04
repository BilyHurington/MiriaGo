#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod desktop_db;
mod startup_log;
mod storage;

fn main() {
    startup_log::install_panic_hook();
    startup_log::write(&format!(
        "launcher starting version={} platform={}",
        env!("CARGO_PKG_VERSION"),
        std::env::consts::OS
    ));

    let result = tauri::Builder::default()
        .on_page_load(|_, payload| {
            startup_log::write(&format!(
                "webview page load event={:?} url={}",
                payload.event(),
                payload.url()
            ));
        })
        .invoke_handler(tauri::generate_handler![
            commands::launcher_info,
            commands::ensure_data_dirs,
            commands::append_desktop_log,
            commands::open_desktop_directory,
            commands::prepare_export_destination,
            commands::write_export_file,
            commands::load_desktop_state,
            commands::save_desktop_state,
            commands::save_desktop_plan_bundle,
            commands::delete_desktop_plan,
            commands::set_desktop_active_plan,
            commands::save_desktop_settings,
            commands::save_desktop_visit_record,
            commands::delete_desktop_visit_record,
            commands::restore_import_assets,
            commands::write_asset,
            commands::read_asset,
            commands::fetch_anitabi_static_json
        ])
        .run(tauri::generate_context!());
    if let Err(error) = result {
        startup_log::write(&format!("launcher stopped with error: {error}"));
        let log_hint = storage::ensure_data_dirs()
            .map(|dirs| dirs.logs_dir.join("startup.log").display().to_string())
            .unwrap_or_else(|_| "startup.log".to_string());
        let _ = rfd::MessageDialog::new()
            .set_title("MiriaGo 启动失败")
            .set_description(format!(
                "无法创建应用窗口。请检查 WebView 运行环境，详细信息已写入：\n{log_hint}"
            ))
            .set_level(rfd::MessageLevel::Error)
            .show();
        panic!("failed to run MiriaGo desktop launcher: {error}");
    }
}
