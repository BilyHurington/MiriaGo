#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

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
        .run(tauri::generate_context!())
        .expect("failed to run MiriaGo desktop launcher");
}
