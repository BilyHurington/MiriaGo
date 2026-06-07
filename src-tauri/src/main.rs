mod commands;
mod desktop_db;
mod storage;

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            commands::launcher_info,
            commands::ensure_data_dirs,
            commands::prepare_export_destination,
            commands::write_export_file,
            commands::load_desktop_state,
            commands::save_desktop_state,
            commands::restore_import_assets,
            commands::read_asset
        ])
        .run(tauri::generate_context!())
        .expect("failed to run MiriaGo desktop launcher");
}
