use std::path::{Path, PathBuf};

use rusqlite::{params, Connection, OptionalExtension, Transaction};
use serde_json::{json, Value};

use crate::storage;

const STATE_KEY: &str = "app_state";

pub struct DesktopDatabase {
    path: PathBuf,
    connection: Connection,
}

impl DesktopDatabase {
    pub fn open() -> Result<Self, String> {
        let dirs = storage::ensure_data_dirs()?;
        let path = dirs.data_dir.join("miriago.sqlite");
        let connection = Connection::open(&path).map_err(|error| error.to_string())?;
        let mut database = Self { path, connection };
        database.migrate()?;
        Ok(database)
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn load_state_json(&self) -> Result<Option<String>, String> {
        if self.plan_count()? == 0 {
            return self.load_legacy_state_json();
        }
        self.load_relational_state_json().map(Some)
    }

    fn load_relational_state_json(&self) -> Result<String, String> {
        let state = json!({
            "schemaVersion": 1,
            "activePlanId": self.active_plan_id()?,
            "settings": self.load_settings_json()?,
            "plans": self.load_plans_json()?,
            "visitRecords": self.load_visit_records_json()?,
        });
        serde_json::to_string(&state).map_err(|error| error.to_string())
    }

    pub fn save_state_json(&mut self, state_json: &str) -> Result<(), String> {
        let state: Value = serde_json::from_str(state_json).map_err(|error| error.to_string())?;
        let tx = self
            .connection
            .transaction()
            .map_err(|error| error.to_string())?;
        save_backup_state(&tx, state_json)?;
        replace_relational_state(&tx, &state)?;
        tx.commit().map_err(|error| error.to_string())
    }

    pub fn set_active_plan(&mut self, plan_id: &str) -> Result<(), String> {
        self.update_with_backup(|tx| set_active_plan_in_tx(tx, Some(plan_id)))
    }

    pub fn save_settings_json(&mut self, settings_json: &str) -> Result<(), String> {
        let settings: Value =
            serde_json::from_str(settings_json).map_err(|error| error.to_string())?;
        self.update_with_backup(|tx| {
            tx.execute("DELETE FROM app_settings WHERE id = 'default'", [])
                .map_err(|error| error.to_string())?;
            insert_settings(tx, Some(&settings))
        })
    }

    pub fn save_plan_bundle_json(
        &mut self,
        plan_json: &str,
        visit_records_json: &str,
        active_plan_id: Option<&str>,
    ) -> Result<(), String> {
        let plan: Value = serde_json::from_str(plan_json).map_err(|error| error.to_string())?;
        let visit_records: Value =
            serde_json::from_str(visit_records_json).map_err(|error| error.to_string())?;
        let plan_id = required_string(&plan, "id")?.to_string();
        self.update_with_backup(|tx| {
            replace_plan_bundle(tx, &plan_id, &plan, &visit_records, active_plan_id)
        })
    }

    pub fn delete_plan(
        &mut self,
        plan_id: &str,
        active_plan_id: Option<&str>,
    ) -> Result<(), String> {
        self.update_with_backup(|tx| {
            delete_plan_rows(tx, plan_id)?;
            set_active_plan_in_tx(tx, active_plan_id)
        })
    }

    pub fn save_visit_record_json(&mut self, record_json: &str) -> Result<(), String> {
        let record: Value = serde_json::from_str(record_json).map_err(|error| error.to_string())?;
        let record_id = required_string(&record, "id")?.to_string();
        self.update_with_backup(|tx| {
            tx.execute(
                "DELETE FROM visit_records WHERE id = ?1",
                params![record_id],
            )
            .map_err(|error| error.to_string())?;
            insert_visit_record(tx, &record)
        })
    }

    pub fn delete_visit_record(&mut self, record_id: &str) -> Result<(), String> {
        self.update_with_backup(|tx| {
            tx.execute(
                "DELETE FROM visit_records WHERE id = ?1",
                params![record_id],
            )
            .map_err(|error| error.to_string())?;
            Ok(())
        })
    }

    fn migrate(&mut self) -> Result<(), String> {
        self.connection
            .execute_batch(
                "
                PRAGMA journal_mode = WAL;
                CREATE TABLE IF NOT EXISTS app_meta (
                  key TEXT PRIMARY KEY NOT NULL,
                  value TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS app_state (
                  key TEXT PRIMARY KEY NOT NULL,
                  value TEXT NOT NULL,
                  updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS plans (
                  id TEXT PRIMARY KEY NOT NULL,
                  name TEXT NOT NULL,
                  area TEXT NOT NULL,
                  memo TEXT NOT NULL DEFAULT '',
                  current_group_id TEXT,
                  active INTEGER NOT NULL DEFAULT 0,
                  order_index INTEGER NOT NULL DEFAULT 0,
                  created_at TEXT NOT NULL,
                  updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS works (
                  id TEXT NOT NULL,
                  plan_id TEXT NOT NULL,
                  bangumi_id INTEGER,
                  bangumi_subject_type TEXT,
                  title TEXT NOT NULL,
                  subtitle TEXT NOT NULL,
                  city TEXT NOT NULL,
                  source TEXT NOT NULL,
                  PRIMARY KEY (plan_id, id)
                );
                CREATE TABLE IF NOT EXISTS plan_groups (
                  id TEXT NOT NULL,
                  plan_id TEXT NOT NULL,
                  name TEXT NOT NULL,
                  order_index INTEGER NOT NULL DEFAULT 0,
                  order_mode TEXT NOT NULL DEFAULT 'unordered',
                  anchor_name TEXT,
                  anchor_latitude REAL,
                  anchor_longitude REAL,
                  anchor_point_id TEXT,
                  note TEXT,
                  created_at TEXT NOT NULL,
                  PRIMARY KEY (plan_id, id)
                );
                CREATE TABLE IF NOT EXISTS points (
                  id TEXT NOT NULL,
                  plan_id TEXT NOT NULL,
                  work_id TEXT NOT NULL,
                  name TEXT NOT NULL,
                  subtitle TEXT NOT NULL,
                  latitude REAL NOT NULL,
                  longitude REAL NOT NULL,
                  episode_label TEXT NOT NULL,
                  reference_label TEXT NOT NULL,
                  source TEXT NOT NULL,
                  source_id TEXT,
                  reference_image_url TEXT,
                  reference_thumbnail_path TEXT,
                  reference_full_image_path TEXT,
                  source_url TEXT,
                  note TEXT,
                  group_id TEXT,
                  group_order_index INTEGER,
                  sort_order INTEGER NOT NULL DEFAULT 0,
                  is_current INTEGER NOT NULL DEFAULT 0,
                  completed_at TEXT,
                  PRIMARY KEY (plan_id, id)
                );
                CREATE TABLE IF NOT EXISTS visit_records (
                  id TEXT PRIMARY KEY NOT NULL,
                  plan_id TEXT NOT NULL,
                  point_id TEXT NOT NULL,
                  work_id TEXT NOT NULL,
                  photo_path TEXT NOT NULL,
                  original_photo_path TEXT,
                  graded_photo_path TEXT,
                  color_grading_mode TEXT,
                  color_grading_params_json TEXT,
                  color_grading_intensity REAL,
                  reference_image_path TEXT,
                  reference_image_url TEXT,
                  reference_mode TEXT NOT NULL,
                  captured_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS app_settings (
                  id TEXT PRIMARY KEY NOT NULL,
                  ui_scale REAL NOT NULL DEFAULT 1.0,
                  camera_capture_aspect_ratio TEXT NOT NULL DEFAULT 'auto',
                  camera_fallback_aspect_ratio TEXT NOT NULL DEFAULT 'native',
                  camera_min_zoom REAL NOT NULL DEFAULT 0.6,
                  camera_max_zoom REAL NOT NULL DEFAULT 5.0,
                  reference_image_scale REAL NOT NULL DEFAULT 1.0,
                  nearest_assign_distance_meters REAL NOT NULL DEFAULT 350.0,
                  theme_palette TEXT NOT NULL DEFAULT 'classicGreen',
                  map_tile_provider TEXT NOT NULL DEFAULT 'openFreeMap',
                  open_free_map_style TEXT NOT NULL DEFAULT 'liberty',
                  anitabi_image_source TEXT NOT NULL DEFAULT 'auto',
                  anitabi_site_base_url TEXT NOT NULL DEFAULT 'https://www.anitabi.cn',
                  anitabi_static_data_base_url TEXT NOT NULL DEFAULT 'https://www.anitabi.cn/d',
                  anitabi_api_base_url TEXT NOT NULL DEFAULT 'https://api.anitabi.cn',
                  anitabi_official_image_base_url TEXT NOT NULL DEFAULT 'https://image.anitabi.cn',
                  anitabi_mirror_image_base_url TEXT NOT NULL DEFAULT 'https://img-tc.anitabi.cn',
                  navigation_app TEXT NOT NULL DEFAULT 'googleMaps',
                  valhalla_base_url TEXT NOT NULL DEFAULT 'https://valhalla1.openstreetmap.de',
                  custom_xyz_tile_url TEXT NOT NULL DEFAULT '',
                  custom_maplibre_style_url TEXT NOT NULL DEFAULT '',
                  comparison_export_config_json TEXT NOT NULL DEFAULT '',
                  comparison_export_config_migrated INTEGER NOT NULL DEFAULT 1,
                  anitabi_remote_state_json TEXT NOT NULL DEFAULT '',
                  route_planner_skill_tip_shown INTEGER NOT NULL DEFAULT 0,
                  route_planner_skill_promotion_dismissed INTEGER NOT NULL DEFAULT 0,
                  hide_imported_points_on_import_map INTEGER NOT NULL DEFAULT 0,
                  map_show_thumbnail_markers INTEGER NOT NULL DEFAULT 0,
                  map_show_group_areas INTEGER NOT NULL DEFAULT 1,
                  import_map_show_thumbnail_markers INTEGER NOT NULL DEFAULT 0,
                  import_map_show_group_areas INTEGER NOT NULL DEFAULT 0,
                  map_thumbnail_visible_threshold INTEGER NOT NULL DEFAULT 40,
                  map_thumbnail_concurrent_loads INTEGER NOT NULL DEFAULT 10,
                  show_plan_group_progress INTEGER NOT NULL DEFAULT 1,
                  map_marker_clustering_enabled INTEGER NOT NULL DEFAULT 1,
                  map_marker_cluster_radius INTEGER NOT NULL DEFAULT 40,
                  map_marker_cluster_max_zoom INTEGER NOT NULL DEFAULT 21,
                  map_group_area_radius_meters INTEGER NOT NULL DEFAULT 160,
                  map_marker_scale REAL NOT NULL DEFAULT 0.9,
                  map_max_zoom INTEGER NOT NULL DEFAULT 22
                );
                CREATE TABLE IF NOT EXISTS asset_metadata (
                  path TEXT PRIMARY KEY NOT NULL,
                  kind TEXT NOT NULL,
                  original_package_path TEXT,
                  created_at TEXT NOT NULL
                );
                INSERT INTO app_meta (key, value)
                VALUES ('schema_version', '3')
                ON CONFLICT(key) DO UPDATE SET value = excluded.value;
                ",
            )
            .map_err(|error| error.to_string())?;
        self.ensure_app_settings_columns()?;
        self.migrate_map_zoom_defaults()?;
        self.ensure_plan_columns()?;
        self.ensure_points_columns()?;
        self.ensure_work_and_visit_record_columns()?;
        self.normalize_anitabi_image_urls()?;

        if self.plan_count()? == 0 {
            if let Some(snapshot) = self.load_legacy_state_json()? {
                self.save_state_json(&snapshot)?;
                self.connection
                    .execute(
                        "INSERT INTO app_meta (key, value)
                         VALUES ('snapshot_migrated_to_relations', strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
                         ON CONFLICT(key) DO NOTHING",
                        [],
                    )
                    .map_err(|error| error.to_string())?;
            }
        }
        Ok(())
    }

    fn migrate_map_zoom_defaults(&self) -> Result<(), String> {
        let already_applied = self
            .connection
            .query_row(
                "SELECT 1 FROM app_meta WHERE key = 'map_zoom_defaults_v2'",
                [],
                |_| Ok(()),
            )
            .optional()
            .map_err(|error| error.to_string())?
            .is_some();
        if already_applied {
            return Ok(());
        }

        self.connection
            .execute(
                "UPDATE app_settings
                 SET map_max_zoom = 22
                 WHERE map_max_zoom = 20",
                [],
            )
            .map_err(|error| error.to_string())?;
        self.connection
            .execute(
                "UPDATE app_settings
                 SET map_marker_cluster_max_zoom = 21
                 WHERE map_marker_cluster_max_zoom = 18",
                [],
            )
            .map_err(|error| error.to_string())?;
        self.connection
            .execute(
                "INSERT INTO app_meta (key, value)
                 VALUES ('map_zoom_defaults_v2', '1')",
                [],
            )
            .map_err(|error| error.to_string())?;
        Ok(())
    }

    fn normalize_anitabi_image_urls(&self) -> Result<(), String> {
        self.connection
            .execute(
                "UPDATE points
                 SET reference_image_url =
                   replace(reference_image_url, '://img-tc.anitabi.cn/', '://image.anitabi.cn/')
                 WHERE reference_image_url LIKE '%://img-tc.anitabi.cn/%'",
                [],
            )
            .map_err(|error| error.to_string())?;
        self.connection
            .execute(
                "UPDATE visit_records
                 SET reference_image_url =
                   replace(reference_image_url, '://img-tc.anitabi.cn/', '://image.anitabi.cn/')
                 WHERE reference_image_url LIKE '%://img-tc.anitabi.cn/%'",
                [],
            )
            .map_err(|error| error.to_string())?;
        Ok(())
    }

    fn ensure_app_settings_columns(&self) -> Result<(), String> {
        let mut statement = self
            .connection
            .prepare("PRAGMA table_info(app_settings)")
            .map_err(|error| error.to_string())?;
        let rows = statement
            .query_map([], |row| row.get::<_, String>(1))
            .map_err(|error| error.to_string())?;
        let mut columns = Vec::new();
        for row in rows {
            columns.push(row.map_err(|error| error.to_string())?);
        }

        for (name, definition) in [
            ("font_scale", "REAL NOT NULL DEFAULT 1.0"),
            ("theme_mode", "TEXT NOT NULL DEFAULT 'light'"),
            (
                "photo_location_strategy",
                "TEXT NOT NULL DEFAULT 'askOnFirstCapture'",
            ),
            ("save_visit_photo_to_gallery", "INTEGER NOT NULL DEFAULT 1"),
            (
                "auto_save_comparison_to_gallery",
                "INTEGER NOT NULL DEFAULT 0",
            ),
            ("comparison_show_pilgrim_name", "INTEGER NOT NULL DEFAULT 0"),
            ("comparison_pilgrim_name", "TEXT NOT NULL DEFAULT ''"),
            ("custom_theme_color_name", "TEXT NOT NULL DEFAULT '自定义'"),
            (
                "custom_theme_color_value",
                "INTEGER NOT NULL DEFAULT 4279682728",
            ),
            ("custom_theme_colors", "TEXT NOT NULL DEFAULT '[]'"),
            (
                "custom_camera_aspect_ratio_width",
                "REAL NOT NULL DEFAULT 1.0",
            ),
            (
                "custom_camera_aspect_ratio_height",
                "REAL NOT NULL DEFAULT 1.0",
            ),
            (
                "dismiss_plan_actions_on_outside_tap",
                "INTEGER NOT NULL DEFAULT 1",
            ),
            ("hide_completed_points_on_map", "INTEGER NOT NULL DEFAULT 1"),
            ("map_tile_provider", "TEXT NOT NULL DEFAULT 'openFreeMap'"),
            ("open_free_map_style", "TEXT NOT NULL DEFAULT 'liberty'"),
            ("anitabi_image_source", "TEXT NOT NULL DEFAULT 'auto'"),
            (
                "anitabi_site_base_url",
                "TEXT NOT NULL DEFAULT 'https://www.anitabi.cn'",
            ),
            (
                "anitabi_static_data_base_url",
                "TEXT NOT NULL DEFAULT 'https://www.anitabi.cn/d'",
            ),
            (
                "anitabi_api_base_url",
                "TEXT NOT NULL DEFAULT 'https://api.anitabi.cn'",
            ),
            (
                "anitabi_official_image_base_url",
                "TEXT NOT NULL DEFAULT 'https://image.anitabi.cn'",
            ),
            (
                "anitabi_mirror_image_base_url",
                "TEXT NOT NULL DEFAULT 'https://img-tc.anitabi.cn'",
            ),
            ("navigation_app", "TEXT NOT NULL DEFAULT 'googleMaps'"),
            (
                "valhalla_base_url",
                "TEXT NOT NULL DEFAULT 'https://valhalla1.openstreetmap.de'",
            ),
            ("custom_xyz_tile_url", "TEXT NOT NULL DEFAULT ''"),
            ("custom_maplibre_style_url", "TEXT NOT NULL DEFAULT ''"),
            ("comparison_export_config_json", "TEXT NOT NULL DEFAULT ''"),
            ("anitabi_remote_state_json", "TEXT NOT NULL DEFAULT ''"),
            (
                "route_planner_skill_tip_shown",
                "INTEGER NOT NULL DEFAULT 0",
            ),
            (
                "route_planner_skill_promotion_dismissed",
                "INTEGER NOT NULL DEFAULT 0",
            ),
            (
                "hide_imported_points_on_import_map",
                "INTEGER NOT NULL DEFAULT 0",
            ),
            ("map_show_thumbnail_markers", "INTEGER NOT NULL DEFAULT 0"),
            ("map_show_group_areas", "INTEGER NOT NULL DEFAULT 1"),
            (
                "import_map_show_thumbnail_markers",
                "INTEGER NOT NULL DEFAULT 0",
            ),
            ("import_map_show_group_areas", "INTEGER NOT NULL DEFAULT 0"),
            (
                "comparison_export_config_migrated",
                "INTEGER NOT NULL DEFAULT 1",
            ),
            (
                "map_thumbnail_visible_threshold",
                "INTEGER NOT NULL DEFAULT 40",
            ),
            (
                "map_thumbnail_concurrent_loads",
                "INTEGER NOT NULL DEFAULT 10",
            ),
            ("show_plan_group_progress", "INTEGER NOT NULL DEFAULT 1"),
            (
                "map_marker_clustering_enabled",
                "INTEGER NOT NULL DEFAULT 1",
            ),
            ("map_marker_cluster_radius", "INTEGER NOT NULL DEFAULT 40"),
            ("map_marker_cluster_max_zoom", "INTEGER NOT NULL DEFAULT 21"),
            (
                "map_group_area_radius_meters",
                "INTEGER NOT NULL DEFAULT 160",
            ),
            ("map_marker_scale", "REAL NOT NULL DEFAULT 0.9"),
            ("map_max_zoom", "INTEGER NOT NULL DEFAULT 22"),
            ("continuous_map_location", "INTEGER NOT NULL DEFAULT 1"),
            ("map_appearance", "TEXT NOT NULL DEFAULT 'automatic'"),
        ] {
            if columns.iter().any(|column| column == name) {
                continue;
            }
            self.connection
                .execute(
                    &format!("ALTER TABLE app_settings ADD COLUMN {name} {definition}"),
                    [],
                )
                .map_err(|error| error.to_string())?;
        }
        Ok(())
    }

    fn ensure_plan_columns(&self) -> Result<(), String> {
        let mut statement = self
            .connection
            .prepare("PRAGMA table_info(plans)")
            .map_err(|error| error.to_string())?;
        let rows = statement
            .query_map([], |row| row.get::<_, String>(1))
            .map_err(|error| error.to_string())?;
        let mut columns = Vec::new();
        for row in rows {
            columns.push(row.map_err(|error| error.to_string())?);
        }

        if !columns.iter().any(|column| column == "memo") {
            self.connection
                .execute(
                    "ALTER TABLE plans ADD COLUMN memo TEXT NOT NULL DEFAULT ''",
                    [],
                )
                .map_err(|error| error.to_string())?;
        }
        if !columns.iter().any(|column| column == "order_index") {
            self.connection
                .execute(
                    "ALTER TABLE plans ADD COLUMN order_index INTEGER NOT NULL DEFAULT 0",
                    [],
                )
                .map_err(|error| error.to_string())?;
            self.connection
                .execute(
                    "UPDATE plans
                     SET order_index = (
                       SELECT COUNT(*)
                       FROM plans AS earlier
                       WHERE earlier.created_at < plans.created_at
                          OR (
                            earlier.created_at = plans.created_at
                            AND earlier.id < plans.id
                          )
                     )",
                    [],
                )
                .map_err(|error| error.to_string())?;
        }
        Ok(())
    }

    fn ensure_points_columns(&self) -> Result<(), String> {
        let mut statement = self
            .connection
            .prepare("PRAGMA table_info(points)")
            .map_err(|error| error.to_string())?;
        let rows = statement
            .query_map([], |row| row.get::<_, String>(1))
            .map_err(|error| error.to_string())?;
        let mut columns = Vec::new();
        for row in rows {
            columns.push(row.map_err(|error| error.to_string())?);
        }

        if !columns.iter().any(|column| column == "note") {
            self.connection
                .execute("ALTER TABLE points ADD COLUMN note TEXT", [])
                .map_err(|error| error.to_string())?;
        }
        Ok(())
    }

    fn ensure_work_and_visit_record_columns(&self) -> Result<(), String> {
        for (table, names) in [
            ("works", &["bangumi_subject_type", "cover_image_url"][..]),
            (
                "visit_records",
                &[
                    "work_title",
                    "work_subtitle",
                    "point_name",
                    "point_subtitle",
                ][..],
            ),
        ] {
            let mut statement = self
                .connection
                .prepare(&format!("PRAGMA table_info({table})"))
                .map_err(|error| error.to_string())?;
            let columns = statement
                .query_map([], |row| row.get::<_, String>(1))
                .map_err(|error| error.to_string())?
                .collect::<rusqlite::Result<Vec<_>>>()
                .map_err(|error| error.to_string())?;
            for name in names {
                if !columns.iter().any(|column| column == name) {
                    self.connection
                        .execute(&format!("ALTER TABLE {table} ADD COLUMN {name} TEXT"), [])
                        .map_err(|error| error.to_string())?;
                }
            }
        }
        Ok(())
    }

    fn load_legacy_state_json(&self) -> Result<Option<String>, String> {
        self.connection
            .query_row(
                "SELECT value FROM app_state WHERE key = ?1",
                params![STATE_KEY],
                |row| row.get::<_, String>(0),
            )
            .optional()
            .map_err(|error| error.to_string())
    }

    fn update_with_backup(
        &mut self,
        update: impl FnOnce(&Transaction<'_>) -> Result<(), String>,
    ) -> Result<(), String> {
        // A shared connection borrow lets the loaders see this transaction's writes.
        // Nested transactions are still rejected by SQLite at runtime.
        let tx = self
            .connection
            .unchecked_transaction()
            .map_err(|error| error.to_string())?;
        update(&tx)?;
        // Never fall back to the old snapshot when deleting the last plan.
        let state_json = self.load_relational_state_json()?;
        save_backup_state(&tx, &state_json)?;
        tx.commit().map_err(|error| error.to_string())
    }

    fn plan_count(&self) -> Result<i64, String> {
        self.connection
            .query_row("SELECT COUNT(*) FROM plans", [], |row| row.get::<_, i64>(0))
            .map_err(|error| error.to_string())
    }

    fn active_plan_id(&self) -> Result<Option<String>, String> {
        self.connection
            .query_row(
                "SELECT id FROM plans WHERE active = 1 ORDER BY created_at ASC LIMIT 1",
                [],
                |row| row.get::<_, String>(0),
            )
            .optional()
            .map_err(|error| error.to_string())
    }

    fn load_settings_json(&self) -> Result<Value, String> {
        self.connection
            .query_row(
                "SELECT ui_scale, camera_capture_aspect_ratio, camera_fallback_aspect_ratio,
                        camera_min_zoom, camera_max_zoom, reference_image_scale,
                        nearest_assign_distance_meters, theme_palette,
                        map_tile_provider, open_free_map_style, anitabi_image_source,
                        anitabi_site_base_url, anitabi_static_data_base_url,
                        anitabi_api_base_url, anitabi_official_image_base_url,
                        anitabi_mirror_image_base_url,
                        navigation_app, valhalla_base_url,
                        custom_xyz_tile_url, custom_maplibre_style_url,
                        comparison_export_config_json,
                        comparison_export_config_migrated,
                        map_thumbnail_visible_threshold, map_thumbnail_concurrent_loads,
                        show_plan_group_progress,
                        map_marker_clustering_enabled, map_marker_cluster_radius,
                        map_marker_cluster_max_zoom,
                        map_group_area_radius_meters, map_marker_scale,
                        map_max_zoom, continuous_map_location, map_appearance,
                        font_scale, theme_mode, photo_location_strategy,
                        save_visit_photo_to_gallery, auto_save_comparison_to_gallery,
                        comparison_show_pilgrim_name, comparison_pilgrim_name,
                        custom_theme_color_name, custom_theme_color_value, custom_theme_colors,
                        custom_camera_aspect_ratio_width, custom_camera_aspect_ratio_height,
                        dismiss_plan_actions_on_outside_tap, hide_completed_points_on_map,
                        anitabi_remote_state_json, route_planner_skill_tip_shown,
                        route_planner_skill_promotion_dismissed,
                        hide_imported_points_on_import_map,
                        map_show_thumbnail_markers,
                        map_show_group_areas,
                        import_map_show_thumbnail_markers,
                        import_map_show_group_areas
                 FROM app_settings WHERE id = 'default'",
                [],
                |row| {
                    let custom_theme_colors: Vec<Value> =
                        serde_json::from_str(&row.get::<_, String>(42)?).map_err(|error| {
                            rusqlite::Error::FromSqlConversionFailure(
                                42,
                                rusqlite::types::Type::Text,
                                Box::new(error),
                            )
                        })?;
                    let mut settings = json!({
                        "uiScale": row.get::<_, f64>(0)?,
                        "cameraCaptureAspectRatio": row.get::<_, String>(1)?,
                        "cameraFallbackAspectRatio": row.get::<_, String>(2)?,
                        "cameraMinZoom": row.get::<_, f64>(3)?,
                        "cameraMaxZoom": row.get::<_, f64>(4)?,
                        "referenceImageScale": row.get::<_, f64>(5)?,
                        "nearestAssignDistanceMeters": row.get::<_, f64>(6)?,
                        "themePalette": row.get::<_, String>(7)?,
                        "mapTileProvider": row.get::<_, String>(8)?,
                        "openFreeMapStyle": row.get::<_, String>(9)?,
                        "anitabiImageSource": row.get::<_, String>(10)?,
                        "anitabiSiteBaseUrl": row.get::<_, String>(11)?,
                        "anitabiStaticDataBaseUrl": row.get::<_, String>(12)?,
                        "anitabiApiBaseUrl": row.get::<_, String>(13)?,
                        "anitabiOfficialImageBaseUrl": row.get::<_, String>(14)?,
                        "anitabiMirrorImageBaseUrl": row.get::<_, String>(15)?,
                        "navigationApp": row.get::<_, String>(16)?,
                        "valhallaBaseUrl": row.get::<_, String>(17)?,
                        "customXyzTileUrl": row.get::<_, String>(18)?,
                        "customMapLibreStyleUrl": row.get::<_, String>(19)?,
                        "comparisonExportConfigJson": row.get::<_, String>(20)?,
                        "comparisonExportConfigMigrated": row.get::<_, bool>(21)?,
                        "mapThumbnailVisibleThreshold": row.get::<_, i64>(22)?,
                        "mapThumbnailConcurrentLoads": row.get::<_, i64>(23)?,
                        "showPlanGroupProgress": row.get::<_, bool>(24)?,
                        "mapMarkerClusteringEnabled": row.get::<_, bool>(25)?,
                        "mapMarkerClusterRadius": row.get::<_, i64>(26)?,
                        "mapMarkerClusterMaxZoom": row.get::<_, i64>(27)?,
                        "mapGroupAreaRadiusMeters": row.get::<_, i64>(28)?,
                        "mapMarkerScale": row.get::<_, f64>(29)?,
                        "mapMaxZoom": row.get::<_, i64>(30)?,
                        "continuousMapLocation": row.get::<_, bool>(31)?,
                        "mapAppearance": row.get::<_, String>(32)?,
                    });
                    settings["fontScale"] = json!(row.get::<_, f64>(33)?);
                    settings["themeMode"] = json!(row.get::<_, String>(34)?);
                    settings["photoLocationStrategy"] = json!(row.get::<_, String>(35)?);
                    settings["saveVisitPhotoToGallery"] = json!(row.get::<_, bool>(36)?);
                    settings["autoSaveComparisonToGallery"] = json!(row.get::<_, bool>(37)?);
                    settings["comparisonShowPilgrimName"] = json!(row.get::<_, bool>(38)?);
                    settings["comparisonPilgrimName"] = json!(row.get::<_, String>(39)?);
                    settings["customThemeColorName"] = json!(row.get::<_, String>(40)?);
                    settings["customThemeColorValue"] = json!(row.get::<_, i64>(41)?);
                    settings["customThemeColors"] = json!(custom_theme_colors);
                    settings["customCameraAspectRatioWidth"] = json!(row.get::<_, f64>(43)?);
                    settings["customCameraAspectRatioHeight"] = json!(row.get::<_, f64>(44)?);
                    settings["dismissPlanActionsOnOutsideTap"] = json!(row.get::<_, bool>(45)?);
                    settings["hideCompletedPointsOnMap"] = json!(row.get::<_, bool>(46)?);
                    settings["anitabiRemoteStateJson"] = json!(row.get::<_, String>(47)?);
                    settings["routePlannerSkillTipShown"] = json!(row.get::<_, bool>(48)?);
                    settings["routePlannerSkillPromotionDismissed"] =
                        json!(row.get::<_, bool>(49)?);
                    settings["hideImportedPointsOnImportMap"] = json!(row.get::<_, bool>(50)?);
                    settings["mapShowThumbnailMarkers"] = json!(row.get::<_, bool>(51)?);
                    settings["mapShowGroupAreas"] = json!(row.get::<_, bool>(52)?);
                    settings["importMapShowThumbnailMarkers"] = json!(row.get::<_, bool>(53)?);
                    settings["importMapShowGroupAreas"] = json!(row.get::<_, bool>(54)?);
                    Ok(settings)
                },
            )
            .optional()
            .map(|value| value.unwrap_or_else(default_settings_json))
            .map_err(|error| error.to_string())
    }

    fn load_plans_json(&self) -> Result<Vec<Value>, String> {
        let mut statement = self
            .connection
            .prepare(
                "SELECT id, name, area, memo, current_group_id, created_at, updated_at
                 FROM plans ORDER BY order_index ASC, created_at ASC, id ASC",
            )
            .map_err(|error| error.to_string())?;
        let rows = statement
            .query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, String>(3)?,
                    row.get::<_, Option<String>>(4)?,
                    row.get::<_, String>(5)?,
                    row.get::<_, String>(6)?,
                ))
            })
            .map_err(|error| error.to_string())?;

        let mut plans = Vec::new();
        for row in rows {
            let (id, name, area, memo, current_group_id, created_at, updated_at) =
                row.map_err(|error| error.to_string())?;
            let points = self.load_points_json(&id)?;
            let current_point_id = points
                .iter()
                .find(|point| {
                    point
                        .get("isCurrent")
                        .and_then(Value::as_bool)
                        .unwrap_or(false)
                })
                .and_then(|point| point.get("id").and_then(Value::as_str))
                .map(str::to_string);
            let completed_point_ids = points
                .iter()
                .filter(|point| {
                    point
                        .get("completedAt")
                        .is_some_and(|value| !value.is_null())
                })
                .filter_map(|point| point.get("id").and_then(Value::as_str))
                .map(str::to_string)
                .collect::<Vec<_>>();
            let points = points
                .into_iter()
                .map(|mut point| {
                    if let Some(object) = point.as_object_mut() {
                        object.remove("isCurrent");
                        object.remove("completedAt");
                    }
                    point
                })
                .collect::<Vec<_>>();
            plans.push(json!({
                "id": id,
                "name": name,
                "area": area,
                "memo": memo,
                "createdAt": created_at,
                "updatedAt": updated_at,
                "currentPointId": current_point_id,
                "currentGroupId": current_group_id,
                "completedPointIds": completed_point_ids,
                "works": self.load_works_json(&id)?,
                "groups": self.load_groups_json(&id)?,
                "points": points,
            }));
        }
        Ok(plans)
    }

    fn load_works_json(&self, plan_id: &str) -> Result<Vec<Value>, String> {
        let mut statement = self
            .connection
            .prepare(
                "SELECT id, bangumi_id, bangumi_subject_type, title, subtitle, city, source,
                        cover_image_url
                 FROM works WHERE plan_id = ?1 ORDER BY rowid ASC",
            )
            .map_err(|error| error.to_string())?;
        let rows = statement
            .query_map(params![plan_id], |row| {
                Ok(json!({
                    "id": row.get::<_, String>(0)?,
                    "bangumiId": row.get::<_, Option<i64>>(1)?,
                    "bangumiSubjectType": row.get::<_, Option<String>>(2)?,
                    "title": row.get::<_, String>(3)?,
                    "subtitle": row.get::<_, String>(4)?,
                    "city": row.get::<_, String>(5)?,
                    "source": row.get::<_, String>(6)?,
                    "coverImageUrl": row.get::<_, Option<String>>(7)?,
                }))
            })
            .map_err(|error| error.to_string())?;
        collect_rows(rows)
    }

    fn load_groups_json(&self, plan_id: &str) -> Result<Vec<Value>, String> {
        let mut statement = self
            .connection
            .prepare(
                "SELECT id, name, order_index, order_mode, anchor_name, anchor_latitude,
                        anchor_longitude, anchor_point_id, note, created_at
                 FROM plan_groups WHERE plan_id = ?1 ORDER BY order_index ASC",
            )
            .map_err(|error| error.to_string())?;
        let rows = statement
            .query_map(params![plan_id], |row| {
                Ok(json!({
                    "id": row.get::<_, String>(0)?,
                    "name": row.get::<_, String>(1)?,
                    "orderIndex": row.get::<_, i64>(2)?,
                    "orderMode": row.get::<_, String>(3)?,
                    "anchorName": row.get::<_, Option<String>>(4)?,
                    "anchorLatitude": row.get::<_, Option<f64>>(5)?,
                    "anchorLongitude": row.get::<_, Option<f64>>(6)?,
                    "anchorPointId": row.get::<_, Option<String>>(7)?,
                    "note": row.get::<_, Option<String>>(8)?,
                    "createdAt": row.get::<_, String>(9)?,
                }))
            })
            .map_err(|error| error.to_string())?;
        collect_rows(rows)
    }

    fn load_points_json(&self, plan_id: &str) -> Result<Vec<Value>, String> {
        let mut statement = self
            .connection
            .prepare(
                "SELECT id, work_id, name, subtitle, latitude, longitude, episode_label,
                        reference_label, source, source_id, reference_image_url,
                        reference_thumbnail_path, reference_full_image_path, source_url,
                        note, group_id, group_order_index, is_current, completed_at
                 FROM points WHERE plan_id = ?1 ORDER BY sort_order ASC",
            )
            .map_err(|error| error.to_string())?;
        let rows = statement
            .query_map(params![plan_id], |row| {
                Ok(json!({
                    "id": row.get::<_, String>(0)?,
                    "workId": row.get::<_, String>(1)?,
                    "name": row.get::<_, String>(2)?,
                    "subtitle": row.get::<_, String>(3)?,
                    "latitude": row.get::<_, f64>(4)?,
                    "longitude": row.get::<_, f64>(5)?,
                    "episodeLabel": row.get::<_, String>(6)?,
                    "referenceLabel": row.get::<_, String>(7)?,
                    "source": row.get::<_, String>(8)?,
                    "sourceId": row.get::<_, Option<String>>(9)?,
                    "referenceImageUrl": canonical_reference_url(row.get::<_, Option<String>>(10)?),
                    "referenceThumbnailPath": row.get::<_, Option<String>>(11)?,
                    "referenceFullImagePath": row.get::<_, Option<String>>(12)?,
                    "sourceUrl": row.get::<_, Option<String>>(13)?,
                    "note": row.get::<_, Option<String>>(14)?,
                    "groupId": row.get::<_, Option<String>>(15)?,
                    "groupOrderIndex": row.get::<_, Option<i64>>(16)?,
                    "isCurrent": row.get::<_, i64>(17)? != 0,
                    "completedAt": row.get::<_, Option<String>>(18)?,
                }))
            })
            .map_err(|error| error.to_string())?;
        collect_rows(rows)
    }

    fn load_visit_records_json(&self) -> Result<Vec<Value>, String> {
        let mut statement = self
            .connection
            .prepare(
                "SELECT id, plan_id, point_id, work_id, photo_path, original_photo_path,
                        graded_photo_path, color_grading_mode, color_grading_params_json,
                        color_grading_intensity, reference_image_path, reference_image_url,
                        reference_mode, captured_at, work_title, work_subtitle,
                        point_name, point_subtitle
                 FROM visit_records ORDER BY captured_at ASC",
            )
            .map_err(|error| error.to_string())?;
        let rows = statement
            .query_map([], |row| {
                Ok(json!({
                    "id": row.get::<_, String>(0)?,
                    "planId": row.get::<_, String>(1)?,
                    "pointId": row.get::<_, String>(2)?,
                    "workId": row.get::<_, String>(3)?,
                    "photoPath": row.get::<_, String>(4)?,
                    "originalPhotoPath": row.get::<_, Option<String>>(5)?,
                    "gradedPhotoPath": row.get::<_, Option<String>>(6)?,
                    "colorGradingMode": row.get::<_, Option<String>>(7)?,
                    "colorGradingParamsJson": row.get::<_, Option<String>>(8)?,
                    "colorGradingIntensity": row.get::<_, Option<f64>>(9)?,
                    "referenceImagePath": row.get::<_, Option<String>>(10)?,
                    "referenceImageUrl": canonical_reference_url(row.get::<_, Option<String>>(11)?),
                    "referenceMode": row.get::<_, String>(12)?,
                    "capturedAt": row.get::<_, String>(13)?,
                    "workTitle": row.get::<_, Option<String>>(14)?,
                    "workSubtitle": row.get::<_, Option<String>>(15)?,
                    "pointName": row.get::<_, Option<String>>(16)?,
                    "pointSubtitle": row.get::<_, Option<String>>(17)?,
                }))
            })
            .map_err(|error| error.to_string())?;
        collect_rows(rows)
    }
}

fn collect_rows(
    rows: rusqlite::MappedRows<'_, impl FnMut(&rusqlite::Row<'_>) -> rusqlite::Result<Value>>,
) -> Result<Vec<Value>, String> {
    let mut values = Vec::new();
    for row in rows {
        values.push(row.map_err(|error| error.to_string())?);
    }
    Ok(values)
}

fn save_backup_state(tx: &Transaction<'_>, state_json: &str) -> Result<(), String> {
    tx.execute(
        "INSERT INTO app_state (key, value, updated_at)
         VALUES (?1, ?2, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
         ON CONFLICT(key) DO UPDATE SET
           value = excluded.value,
           updated_at = excluded.updated_at",
        params![STATE_KEY, state_json],
    )
    .map_err(|error| error.to_string())?;
    Ok(())
}

fn replace_relational_state(tx: &Transaction<'_>, state: &Value) -> Result<(), String> {
    tx.execute_batch(
        "
        DELETE FROM visit_records;
        DELETE FROM points;
        DELETE FROM plan_groups;
        DELETE FROM works;
        DELETE FROM plans;
        DELETE FROM app_settings;
        ",
    )
    .map_err(|error| error.to_string())?;

    insert_settings(tx, state.get("settings"))?;
    let active_plan_id = state.get("activePlanId").and_then(Value::as_str);
    for (order_index, plan) in array_value(state.get("plans")).into_iter().enumerate() {
        insert_plan(tx, plan, active_plan_id, Some(order_index as i64))?;
    }
    for record in array_value(state.get("visitRecords")) {
        insert_visit_record(tx, record)?;
    }
    Ok(())
}

fn replace_plan_bundle(
    tx: &Transaction<'_>,
    plan_id: &str,
    plan: &Value,
    visit_records: &Value,
    active_plan_id: Option<&str>,
) -> Result<(), String> {
    let order_index = tx
        .query_row(
            "SELECT order_index FROM plans WHERE id = ?1",
            params![plan_id],
            |row| row.get::<_, i64>(0),
        )
        .optional()
        .map_err(|error| error.to_string())?;
    delete_plan_graph_rows(tx, plan_id)?;
    tx.execute(
        "DELETE FROM visit_records WHERE plan_id = ?1",
        params![plan_id],
    )
    .map_err(|error| error.to_string())?;
    if active_plan_id.is_some() {
        set_active_plan_in_tx(tx, active_plan_id)?;
    }
    insert_plan(tx, plan, active_plan_id, order_index)?;
    for record in array_value(Some(visit_records)) {
        insert_visit_record(tx, record)?;
    }
    Ok(())
}

fn delete_plan_rows(tx: &Transaction<'_>, plan_id: &str) -> Result<(), String> {
    delete_plan_graph_rows(tx, plan_id)?;
    tx.execute(
        "DELETE FROM visit_records WHERE plan_id = ?1",
        params![plan_id],
    )
    .map_err(|error| error.to_string())?;
    Ok(())
}

fn delete_plan_graph_rows(tx: &Transaction<'_>, plan_id: &str) -> Result<(), String> {
    for statement in [
        "DELETE FROM points WHERE plan_id = ?1",
        "DELETE FROM plan_groups WHERE plan_id = ?1",
        "DELETE FROM works WHERE plan_id = ?1",
        "DELETE FROM plans WHERE id = ?1",
    ] {
        tx.execute(statement, params![plan_id])
            .map_err(|error| error.to_string())?;
    }
    Ok(())
}

fn set_active_plan_in_tx(tx: &Transaction<'_>, active_plan_id: Option<&str>) -> Result<(), String> {
    tx.execute("UPDATE plans SET active = 0", [])
        .map_err(|error| error.to_string())?;
    if let Some(plan_id) = active_plan_id {
        tx.execute(
            "UPDATE plans SET active = 1 WHERE id = ?1",
            params![plan_id],
        )
        .map_err(|error| error.to_string())?;
    }
    Ok(())
}

fn insert_settings(tx: &Transaction<'_>, settings: Option<&Value>) -> Result<(), String> {
    let settings = settings.unwrap_or(&Value::Null);
    tx.execute(
        "INSERT INTO app_settings (
           id, ui_scale, camera_capture_aspect_ratio, camera_fallback_aspect_ratio,
           camera_min_zoom, camera_max_zoom, reference_image_scale,
           nearest_assign_distance_meters, theme_palette, map_tile_provider,
           open_free_map_style, anitabi_image_source,
           anitabi_site_base_url, anitabi_static_data_base_url,
           anitabi_api_base_url, anitabi_official_image_base_url,
           anitabi_mirror_image_base_url, navigation_app, valhalla_base_url,
           custom_xyz_tile_url, custom_maplibre_style_url,
           comparison_export_config_json, comparison_export_config_migrated,
           map_thumbnail_visible_threshold, map_thumbnail_concurrent_loads,
           show_plan_group_progress,
           map_marker_clustering_enabled, map_marker_cluster_radius,
           map_marker_cluster_max_zoom, map_group_area_radius_meters,
           map_marker_scale, map_max_zoom, continuous_map_location, map_appearance,
           font_scale, theme_mode, photo_location_strategy,
           save_visit_photo_to_gallery, auto_save_comparison_to_gallery,
           comparison_show_pilgrim_name, comparison_pilgrim_name,
           custom_theme_color_name, custom_theme_color_value, custom_theme_colors,
           custom_camera_aspect_ratio_width, custom_camera_aspect_ratio_height,
           dismiss_plan_actions_on_outside_tap, hide_completed_points_on_map,
           anitabi_remote_state_json, route_planner_skill_tip_shown,
           route_planner_skill_promotion_dismissed,
           hide_imported_points_on_import_map,
           map_show_thumbnail_markers,
           map_show_group_areas,
           import_map_show_thumbnail_markers,
           import_map_show_group_areas
         ) VALUES ('default', ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22, ?23, ?24, ?25, ?26, ?27, ?28, ?29, ?30, ?31, ?32, ?33, ?34, ?35, ?36, ?37, ?38, ?39, ?40, ?41, ?42, ?43, ?44, ?45, ?46, ?47, ?48, ?49, ?50, ?51, ?52, ?53, ?54, ?55)",
        params![
            f64_value(settings, "uiScale", 1.0),
            string_value(settings, "cameraCaptureAspectRatio", "auto"),
            string_value(settings, "cameraFallbackAspectRatio", "native"),
            f64_value(settings, "cameraMinZoom", 0.6),
            f64_value(settings, "cameraMaxZoom", 5.0),
            f64_value(settings, "referenceImageScale", 1.0),
            f64_value(settings, "nearestAssignDistanceMeters", 350.0),
            string_value(settings, "themePalette", "classicGreen"),
            string_value(settings, "mapTileProvider", "openFreeMap"),
            string_value(settings, "openFreeMapStyle", "liberty"),
            string_value(settings, "anitabiImageSource", "auto"),
            string_value(settings, "anitabiSiteBaseUrl", "https://www.anitabi.cn"),
            string_value(
                settings,
                "anitabiStaticDataBaseUrl",
                "https://www.anitabi.cn/d",
            ),
            string_value(settings, "anitabiApiBaseUrl", "https://api.anitabi.cn"),
            string_value(
                settings,
                "anitabiOfficialImageBaseUrl",
                "https://image.anitabi.cn",
            ),
            string_value(
                settings,
                "anitabiMirrorImageBaseUrl",
                "https://img-tc.anitabi.cn",
            ),
            string_value(settings, "navigationApp", "googleMaps"),
            string_value(
                settings,
                "valhallaBaseUrl",
                "https://valhalla1.openstreetmap.de",
            ),
            string_value(settings, "customXyzTileUrl", ""),
            string_value(settings, "customMapLibreStyleUrl", ""),
            string_value(settings, "comparisonExportConfigJson", ""),
            bool_value(settings, "comparisonExportConfigMigrated", true),
            i64_value(settings, "mapThumbnailVisibleThreshold", 40).clamp(0, 200),
            i64_value(settings, "mapThumbnailConcurrentLoads", 10).clamp(1, 30),
            bool_value(settings, "showPlanGroupProgress", true),
            bool_value(settings, "mapMarkerClusteringEnabled", true),
            i64_value(settings, "mapMarkerClusterRadius", 40).clamp(32, 120),
            i64_value(settings, "mapMarkerClusterMaxZoom", 21).clamp(10, 22),
            i64_value(settings, "mapGroupAreaRadiusMeters", 160).clamp(25, 500),
            f64_value(settings, "mapMarkerScale", 0.9).clamp(0.6, 1.2),
            i64_value(settings, "mapMaxZoom", 22).clamp(16, 24),
            bool_value(settings, "continuousMapLocation", true),
            string_value(settings, "mapAppearance", "automatic"),
            f64_value(settings, "fontScale", 1.0),
            string_value(settings, "themeMode", "light"),
            string_value(settings, "photoLocationStrategy", "askOnFirstCapture"),
            bool_value(settings, "saveVisitPhotoToGallery", true),
            bool_value(settings, "autoSaveComparisonToGallery", false),
            bool_value(settings, "comparisonShowPilgrimName", false),
            string_value(settings, "comparisonPilgrimName", ""),
            string_value(settings, "customThemeColorName", "自定义"),
            i64_value(settings, "customThemeColorValue", 0xFF16C6A8),
            serde_json::to_string(array_value(settings.get("customThemeColors")))
                .map_err(|error| error.to_string())?,
            f64_value(settings, "customCameraAspectRatioWidth", 1.0),
            f64_value(settings, "customCameraAspectRatioHeight", 1.0),
            bool_value(settings, "dismissPlanActionsOnOutsideTap", true),
            bool_value(settings, "hideCompletedPointsOnMap", true),
            string_value(settings, "anitabiRemoteStateJson", ""),
            bool_value(settings, "routePlannerSkillTipShown", false),
            bool_value(settings, "routePlannerSkillPromotionDismissed", false),
            bool_value(settings, "hideImportedPointsOnImportMap", false),
            bool_value(settings, "mapShowThumbnailMarkers", false),
            bool_value(settings, "mapShowGroupAreas", true),
            bool_value(settings, "importMapShowThumbnailMarkers", false),
            bool_value(settings, "importMapShowGroupAreas", false),
        ],
    )
    .map_err(|error| error.to_string())?;
    Ok(())
}

fn insert_plan(
    tx: &Transaction<'_>,
    plan: &Value,
    active_plan_id: Option<&str>,
    order_index: Option<i64>,
) -> Result<(), String> {
    let plan_id = required_string(plan, "id")?;
    let order_index = match order_index {
        Some(value) => value,
        None => tx
            .query_row(
                "SELECT COALESCE(MAX(order_index), -1) + 1 FROM plans",
                [],
                |row| row.get::<_, i64>(0),
            )
            .map_err(|error| error.to_string())?,
    };
    tx.execute(
        "INSERT INTO plans (
           id, name, area, memo, current_group_id, active, order_index,
           created_at, updated_at
         )
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
        params![
            plan_id,
            string_value(plan, "name", "桌面端计划"),
            string_value(plan, "area", ""),
            string_value(plan, "memo", ""),
            optional_string(plan, "currentGroupId"),
            (active_plan_id == Some(plan_id)) as i64,
            order_index,
            string_value(plan, "createdAt", "1970-01-01T00:00:00.000"),
            string_value(plan, "updatedAt", "1970-01-01T00:00:00.000"),
        ],
    )
    .map_err(|error| error.to_string())?;

    for work in array_value(plan.get("works")) {
        insert_work(tx, plan_id, work)?;
    }
    for group in array_value(plan.get("groups")) {
        insert_group(tx, plan_id, group)?;
    }
    let completed = plan
        .get("completedPointIds")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(Value::as_str)
                .collect::<std::collections::HashSet<_>>()
        })
        .unwrap_or_default();
    let current_point_id = plan.get("currentPointId").and_then(Value::as_str);
    for (index, point) in array_value(plan.get("points")).iter().enumerate() {
        insert_point(tx, plan_id, point, index, current_point_id, &completed)?;
    }
    Ok(())
}

fn insert_work(tx: &Transaction<'_>, plan_id: &str, work: &Value) -> Result<(), String> {
    tx.execute(
        "INSERT INTO works (
           id, plan_id, bangumi_id, bangumi_subject_type, title, subtitle, city, source,
           cover_image_url
         ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
        params![
            required_string(work, "id")?,
            plan_id,
            optional_i64(work, "bangumiId"),
            optional_string(work, "bangumiSubjectType"),
            string_value(work, "title", "作品"),
            string_value(work, "subtitle", ""),
            string_value(work, "city", ""),
            string_value(work, "source", "manual"),
            optional_string(work, "coverImageUrl"),
        ],
    )
    .map_err(|error| error.to_string())?;
    Ok(())
}

fn insert_group(tx: &Transaction<'_>, plan_id: &str, group: &Value) -> Result<(), String> {
    tx.execute(
        "INSERT INTO plan_groups (
           id, plan_id, name, order_index, order_mode, anchor_name, anchor_latitude,
           anchor_longitude, anchor_point_id, note, created_at
         ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
        params![
            required_string(group, "id")?,
            plan_id,
            string_value(group, "name", "分组"),
            i64_value(group, "orderIndex", 0),
            string_value(group, "orderMode", "unordered"),
            optional_string(group, "anchorName"),
            optional_f64(group, "anchorLatitude"),
            optional_f64(group, "anchorLongitude"),
            optional_string(group, "anchorPointId"),
            optional_string(group, "note"),
            string_value(group, "createdAt", "1970-01-01T00:00:00.000"),
        ],
    )
    .map_err(|error| error.to_string())?;
    Ok(())
}

fn insert_point(
    tx: &Transaction<'_>,
    plan_id: &str,
    point: &Value,
    sort_order: usize,
    current_point_id: Option<&str>,
    completed: &std::collections::HashSet<&str>,
) -> Result<(), String> {
    let point_id = required_string(point, "id")?;
    let completed_at = completed
        .contains(point_id)
        .then(|| string_value(point, "completedAt", "1970-01-01T00:00:00.000"));
    tx.execute(
        "INSERT INTO points (
           id, plan_id, work_id, name, subtitle, latitude, longitude, episode_label,
           reference_label, source, source_id, reference_image_url, reference_thumbnail_path,
           reference_full_image_path, source_url, note, group_id, group_order_index, sort_order,
           is_current, completed_at
         ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21)",
        params![
            point_id,
            plan_id,
            string_value(point, "workId", ""),
            string_value(point, "name", "点位"),
            string_value(point, "subtitle", ""),
            f64_value(point, "latitude", 0.0),
            f64_value(point, "longitude", 0.0),
            string_value(point, "episodeLabel", ""),
            string_value(point, "referenceLabel", ""),
            string_value(point, "source", "manual"),
            optional_string(point, "sourceId"),
            optional_reference_url(point, "referenceImageUrl"),
            optional_string(point, "referenceThumbnailPath"),
            optional_string(point, "referenceFullImagePath"),
            optional_string(point, "sourceUrl"),
            optional_string(point, "note"),
            optional_string(point, "groupId"),
            optional_i64(point, "groupOrderIndex"),
            sort_order as i64,
            (current_point_id == Some(point_id)) as i64,
            completed_at,
        ],
    )
    .map_err(|error| error.to_string())?;
    Ok(())
}

fn insert_visit_record(tx: &Transaction<'_>, record: &Value) -> Result<(), String> {
    tx.execute(
        "INSERT INTO visit_records (
           id, plan_id, point_id, work_id, photo_path, original_photo_path,
           graded_photo_path, color_grading_mode, color_grading_params_json,
           color_grading_intensity, reference_image_path, reference_image_url,
           reference_mode, captured_at, work_title, work_subtitle, point_name, point_subtitle
         ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18)",
        params![
            required_string(record, "id")?,
            string_value(record, "planId", ""),
            string_value(record, "pointId", ""),
            string_value(record, "workId", ""),
            string_value(record, "photoPath", ""),
            optional_string(record, "originalPhotoPath"),
            optional_string(record, "gradedPhotoPath"),
            optional_string(record, "colorGradingMode"),
            optional_string(record, "colorGradingParamsJson"),
            optional_f64(record, "colorGradingIntensity"),
            optional_string(record, "referenceImagePath"),
            optional_reference_url(record, "referenceImageUrl"),
            string_value(record, "referenceMode", "none"),
            string_value(record, "capturedAt", "1970-01-01T00:00:00.000"),
            optional_string(record, "workTitle"),
            optional_string(record, "workSubtitle"),
            optional_string(record, "pointName"),
            optional_string(record, "pointSubtitle"),
        ],
    )
    .map_err(|error| error.to_string())?;
    Ok(())
}

fn default_settings_json() -> Value {
    let mut settings = json!({
        "uiScale": 1.0,
        "cameraCaptureAspectRatio": "auto",
        "cameraFallbackAspectRatio": "native",
        "cameraMinZoom": 0.6,
        "cameraMaxZoom": 5.0,
        "referenceImageScale": 1.0,
        "nearestAssignDistanceMeters": 350.0,
        "themePalette": "classicGreen",
        "mapTileProvider": "openFreeMap",
        "openFreeMapStyle": "liberty",
        "anitabiImageSource": "auto",
        "anitabiSiteBaseUrl": "https://www.anitabi.cn",
        "anitabiStaticDataBaseUrl": "https://www.anitabi.cn/d",
        "anitabiApiBaseUrl": "https://api.anitabi.cn",
        "anitabiOfficialImageBaseUrl": "https://image.anitabi.cn",
        "anitabiMirrorImageBaseUrl": "https://img-tc.anitabi.cn",
        "navigationApp": "googleMaps",
        "valhallaBaseUrl": "https://valhalla1.openstreetmap.de",
        "customXyzTileUrl": "",
        "customMapLibreStyleUrl": "",
        "comparisonExportConfigJson": "",
        "comparisonExportConfigMigrated": true,
        "mapThumbnailVisibleThreshold": 40,
        "mapThumbnailConcurrentLoads": 10,
        "showPlanGroupProgress": true,
        "mapMarkerClusteringEnabled": true,
        "mapMarkerClusterRadius": 40,
        "mapMarkerClusterMaxZoom": 21,
        "mapGroupAreaRadiusMeters": 160,
        "mapMarkerScale": 0.9,
        "mapMaxZoom": 22,
        "continuousMapLocation": true,
        "mapAppearance": "automatic",
    });
    settings["fontScale"] = json!(1.0);
    settings["themeMode"] = json!("light");
    settings["photoLocationStrategy"] = json!("askOnFirstCapture");
    settings["saveVisitPhotoToGallery"] = json!(true);
    settings["autoSaveComparisonToGallery"] = json!(false);
    settings["comparisonShowPilgrimName"] = json!(false);
    settings["comparisonPilgrimName"] = json!("");
    settings["customThemeColorName"] = json!("自定义");
    settings["customThemeColorValue"] = json!(0xFF16C6A8_i64);
    settings["customThemeColors"] = json!([]);
    settings["customCameraAspectRatioWidth"] = json!(1.0);
    settings["customCameraAspectRatioHeight"] = json!(1.0);
    settings["dismissPlanActionsOnOutsideTap"] = json!(true);
    settings["hideCompletedPointsOnMap"] = json!(true);
    settings["anitabiRemoteStateJson"] = json!("");
    settings["routePlannerSkillTipShown"] = json!(false);
    settings["routePlannerSkillPromotionDismissed"] = json!(false);
    settings["hideImportedPointsOnImportMap"] = json!(false);
    settings["mapShowThumbnailMarkers"] = json!(false);
    settings["mapShowGroupAreas"] = json!(true);
    settings["importMapShowThumbnailMarkers"] = json!(false);
    settings["importMapShowGroupAreas"] = json!(false);
    settings
}

fn array_value(value: Option<&Value>) -> &[Value] {
    value
        .and_then(Value::as_array)
        .map(Vec::as_slice)
        .unwrap_or(&[])
}

fn required_string<'a>(value: &'a Value, key: &str) -> Result<&'a str, String> {
    value
        .get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| format!("missing required string: {key}"))
}

fn string_value(value: &Value, key: &str, fallback: &str) -> String {
    value
        .get(key)
        .and_then(Value::as_str)
        .unwrap_or(fallback)
        .to_string()
}

fn optional_string(value: &Value, key: &str) -> Option<String> {
    value.get(key).and_then(Value::as_str).map(str::to_string)
}

fn optional_reference_url(value: &Value, key: &str) -> Option<String> {
    canonical_reference_url(optional_string(value, key))
}

fn canonical_reference_url(url: Option<String>) -> Option<String> {
    let url = url?;
    let trimmed = url.trim();
    if trimmed.is_empty() {
        return None;
    }
    Some(trimmed.replace("://img-tc.anitabi.cn/", "://image.anitabi.cn/"))
}

fn i64_value(value: &Value, key: &str, fallback: i64) -> i64 {
    value.get(key).and_then(Value::as_i64).unwrap_or(fallback)
}

fn bool_value(value: &Value, key: &str, fallback: bool) -> bool {
    value.get(key).and_then(Value::as_bool).unwrap_or(fallback)
}

fn optional_i64(value: &Value, key: &str) -> Option<i64> {
    value.get(key).and_then(Value::as_i64)
}

fn f64_value(value: &Value, key: &str, fallback: f64) -> f64 {
    value.get(key).and_then(Value::as_f64).unwrap_or(fallback)
}

fn optional_f64(value: &Value, key: &str) -> Option<f64> {
    value.get(key).and_then(Value::as_f64)
}

#[cfg(test)]
mod tests {
    use super::*;

    struct TemporaryDatabase {
        directory: PathBuf,
    }

    impl TemporaryDatabase {
        fn new() -> Self {
            static NEXT_ID: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
            let directory = std::env::temp_dir().join(format!(
                "miriago-desktop-db-test-{}-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos(),
                NEXT_ID.fetch_add(1, std::sync::atomic::Ordering::Relaxed),
            ));
            std::fs::create_dir(&directory).unwrap();
            Self { directory }
        }

        fn connect(&self) -> DesktopDatabase {
            let path = self.directory.join("test.sqlite");
            let connection = Connection::open(&path).unwrap();
            DesktopDatabase { path, connection }
        }

        fn open(&self) -> DesktopDatabase {
            let mut database = self.connect();
            database.migrate().unwrap();
            database
        }
    }

    impl Drop for TemporaryDatabase {
        fn drop(&mut self) {
            std::fs::remove_dir_all(&self.directory).unwrap();
        }
    }

    // Every key emitted by desktop_repository_state.dart, with non-default values.
    fn complete_state() -> Value {
        let mut settings = json!({
                "uiScale": 0.85,
                "fontScale": 1.25,
                "themeMode": "dark",
                "cameraCaptureAspectRatio": "custom",
                "cameraFallbackAspectRatio": "square1x1",
                "cameraMinZoom": 0.8,
                "cameraMaxZoom": 4.0,
                "referenceImageScale": 1.2,
                "photoLocationStrategy": "waitOnConfirmation",
                "nearestAssignDistanceMeters": 420.0,
                "themePalette": "aurora",
                "mapTileProvider": "customXyz",
                "openFreeMapStyle": "bright",
                "anitabiImageSource": "mirror",
                "anitabiSiteBaseUrl": "https://site.example/anitabi",
                "anitabiStaticDataBaseUrl": "https://static.example/data",
                "anitabiApiBaseUrl": "https://api.example/v2",
                "anitabiOfficialImageBaseUrl": "https://images.example/official",
                "anitabiMirrorImageBaseUrl": "https://images.example/mirror",
                "navigationApp": "amap",
                "valhallaBaseUrl": "https://route.example/api",
                "customXyzTileUrl": "https://tiles.example/{z}/{x}/{y}.png",
                "customMapLibreStyleUrl": "https://tiles.example/style.json",
                "saveVisitPhotoToGallery": false,
                "autoSaveComparisonToGallery": true,
                "comparisonShowPilgrimName": true,
                "comparisonPilgrimName": "巡礼者 \"A\"",
        });
        settings.as_object_mut().unwrap().extend(
            json!({
                    "comparisonExportConfigJson": "{\"outputWidth\":\"w2560\"}",
                    "comparisonExportConfigMigrated": false,
                    "customThemeColorName": "海色 'A'",
                    "customThemeColorValue": 0xFF123456_i64,
                    "customThemeColors": [
                        {"name": "海色 'A'", "value": 0xFF123456_i64},
                        {"name": "White \"B\"", "value": 0xFFFFFFFF_i64}
                    ],
                    "customCameraAspectRatioWidth": 7.5,
                    "customCameraAspectRatioHeight": 4.5,
                    "mapThumbnailVisibleThreshold": 55,
                    "mapThumbnailConcurrentLoads": 7,
                    "showPlanGroupProgress": false,
                    "dismissPlanActionsOnOutsideTap": false,
                    "hideCompletedPointsOnMap": false,
                    "anitabiRemoteStateJson": "{\"autoUpdate\":false}",
                    "routePlannerSkillTipShown": true,
                    "routePlannerSkillPromotionDismissed": true,
                    "hideImportedPointsOnImportMap": true,
                    "mapShowThumbnailMarkers": true,
                    "mapShowGroupAreas": false,
                    "importMapShowThumbnailMarkers": true,
                    "importMapShowGroupAreas": true,
                    "mapMarkerClusteringEnabled": false,
                    "mapMarkerClusterRadius": 56,
                    "mapMarkerClusterMaxZoom": 20,
                    "mapGroupAreaRadiusMeters": 225,
                    "mapMarkerScale": 1.1,
                    "mapMaxZoom": 23,
                    "mapAppearance": "light",
                    "continuousMapLocation": false
            })
            .as_object()
            .unwrap()
            .clone(),
        );
        json!({
            "schemaVersion": 1,
            "activePlanId": "plan-1",
            "settings": settings,
            "plans": [{
                "id": "plan-1", "name": "Plan", "area": "Tokyo", "memo": "Memo",
                "createdAt": "2026-01-01T12:00:00.000",
                "updatedAt": "2026-02-01T12:00:00.000",
                "currentPointId": "point-1", "currentGroupId": "group-1",
                "completedPointIds": ["point-1"],
                "works": [{
                    "id": "work-1", "bangumiId": 1234, "bangumiSubjectType": "anime",
                    "coverImageUrl": "https://images.example/cover.jpg",
                    "title": "Current work", "subtitle": "Current work subtitle",
                    "city": "Tokyo", "source": "bangumi"
                }],
                "groups": [{
                    "id": "group-1", "name": "Group", "orderIndex": 2,
                    "orderMode": "manual", "anchorName": "Station",
                    "anchorLatitude": 35.0, "anchorLongitude": 139.0,
                    "anchorPointId": "point-1", "note": "Group note",
                    "createdAt": "2026-01-01T12:00:00.000"
                }],
                "points": [{
                    "id": "point-1", "workId": "work-1", "name": "Current point",
                    "subtitle": "Current point subtitle", "latitude": 35.1, "longitude": 139.1,
                    "episodeLabel": "EP 1", "referenceLabel": "00:12:34", "source": "anitabi",
                    "sourceId": "source-1", "referenceImageUrl": "https://images.example/ref.jpg",
                    "referenceThumbnailPath": "assets/thumb.jpg",
                    "referenceFullImagePath": "assets/ref.jpg", "sourceUrl": "https://source.example/1",
                    "note": "Point note", "groupId": "group-1", "groupOrderIndex": 3
                }]
            }],
            "visitRecords": [{
                "id": "record-1", "planId": "plan-1", "pointId": "point-1", "workId": "work-1",
                "workTitle": "Historical work", "workSubtitle": "Historical work subtitle",
                "pointName": "Historical point", "pointSubtitle": "Historical point subtitle",
                "photoPath": "assets/photo.jpg", "originalPhotoPath": "assets/original.jpg",
                "gradedPhotoPath": "assets/graded.jpg", "colorGradingMode": "manual",
                "colorGradingParamsJson": "{\"exposure\":0.25}", "colorGradingIntensity": 0.75,
                "referenceImagePath": "assets/ref.jpg", "referenceImageUrl": "https://images.example/ref.jpg",
                "referenceMode": "image", "capturedAt": "2026-02-01T13:00:00.000"
            }]
        })
    }

    fn loaded_state(database: &DesktopDatabase) -> Value {
        serde_json::from_str(&database.load_state_json().unwrap().unwrap()).unwrap()
    }

    #[test]
    fn round_trip_fixture_covers_every_dart_serialized_field() {
        let source = include_str!("../../lib/desktop/desktop_repository_state.dart");
        let state = complete_state();
        for (serializer, fixture) in [
            ("_settingsJson", &state["settings"]),
            ("_planJson", &state["plans"][0]),
            ("_workJson", &state["plans"][0]["works"][0]),
            ("_groupJson", &state["plans"][0]["groups"][0]),
            ("_pointJson", &state["plans"][0]["points"][0]),
            ("_visitRecordJson", &state["visitRecords"][0]),
        ] {
            // These serializers declare their literal JSON keys on separate lines.
            let declaration = format!("Map<String, Object?> {serializer}(");
            let body = source
                .split_once(&declaration)
                .unwrap()
                .1
                .split_once("\n}")
                .unwrap()
                .0;
            let keys: std::collections::BTreeSet<_> = body
                .lines()
                .filter_map(|line| {
                    line.trim()
                        .strip_prefix('\'')?
                        .split_once("':")
                        .map(|(key, _)| key)
                })
                .collect();
            let fixture_keys = fixture
                .as_object()
                .unwrap()
                .keys()
                .map(String::as_str)
                .collect();
            assert_eq!(keys, fixture_keys, "{serializer} field coverage");
        }
    }

    fn state_with_two_plans() -> Value {
        let mut state = complete_state();
        let mut second_plan = state["plans"][0].clone();
        second_plan["id"] = json!("plan-2");
        state["plans"].as_array_mut().unwrap().push(second_plan);
        state
    }

    #[test]
    fn backup_write_failure_rolls_back_every_incremental_operation() {
        for event in ["INSERT", "UPDATE"] {
            for operation in [
                "set_active_plan",
                "save_settings_json",
                "save_plan_bundle_json",
                "delete_plan",
                "save_visit_record_json",
                "delete_visit_record",
            ] {
                let temporary = TemporaryDatabase::new();
                let expected = state_with_two_plans();
                {
                    let mut database = temporary.open();
                    database.save_state_json(&expected.to_string()).unwrap();
                    let backup = database.load_legacy_state_json().unwrap();
                    database
                        .connection
                        .execute_batch(&format!(
                            "CREATE TRIGGER fail_backup BEFORE {event} ON app_state
                         BEGIN SELECT RAISE(ABORT, 'injected backup failure'); END;"
                        ))
                        .unwrap();
                    let result = match operation {
                        "set_active_plan" => database.set_active_plan("plan-2"),
                        "save_settings_json" => {
                            database.save_settings_json(r#"{"themeMode":"light"}"#)
                        }
                        "save_plan_bundle_json" => {
                            let mut plan = expected["plans"][0].clone();
                            plan["name"] = json!("Changed plan");
                            plan["works"][0]["coverImageUrl"] = json!("changed-cover.png");
                            database.save_plan_bundle_json(&plan.to_string(), "[]", Some("plan-2"))
                        }
                        "delete_plan" => database.delete_plan("plan-1", Some("plan-2")),
                        "save_visit_record_json" => {
                            let mut record = expected["visitRecords"][0].clone();
                            record["workTitle"] = json!("Changed snapshot");
                            database.save_visit_record_json(&record.to_string())
                        }
                        "delete_visit_record" => database.delete_visit_record("record-1"),
                        _ => unreachable!(),
                    };
                    assert!(
                        result.unwrap_err().contains("injected backup failure"),
                        "{operation}: {event} trigger must fail the operation"
                    );
                    assert_eq!(loaded_state(&database), expected, "{operation}: {event}");
                    assert_eq!(database.load_legacy_state_json().unwrap(), backup);
                    assert!(database.connection.is_autocommit());
                }
                assert_eq!(
                    loaded_state(&temporary.open()),
                    expected,
                    "{operation}: {event}"
                );
            }
        }
    }

    #[test]
    fn backup_read_failure_rolls_back_the_relational_update() {
        let mut database = memory_database();
        database
            .save_state_json(&state_with_two_plans().to_string())
            .unwrap();
        let backup = database.load_legacy_state_json().unwrap();
        database
            .connection
            .execute(
                "UPDATE app_settings SET custom_theme_colors = 'invalid json'",
                [],
            )
            .unwrap();
        assert!(database.set_active_plan("plan-2").is_err());
        assert_eq!(
            database.active_plan_id().unwrap().as_deref(),
            Some("plan-1")
        );
        assert_eq!(database.load_legacy_state_json().unwrap(), backup);
        assert!(database.connection.is_autocommit());
    }

    #[test]
    fn active_plan_and_deletions_update_backup_without_resurrecting_last_plan() {
        let temporary = TemporaryDatabase::new();
        let mut expected = state_with_two_plans();
        {
            let mut database = temporary.open();
            database.save_state_json(&expected.to_string()).unwrap();
            database.set_active_plan("plan-2").unwrap();
            expected["activePlanId"] = json!("plan-2");
            assert_eq!(loaded_state(&database), expected);
            database.delete_visit_record("record-1").unwrap();
            expected["visitRecords"] = json!([]);
            assert_eq!(loaded_state(&database), expected);
            database.delete_plan("plan-1", Some("plan-2")).unwrap();
            expected["plans"].as_array_mut().unwrap().remove(0);
            assert_eq!(loaded_state(&database), expected);
        }
        {
            let mut database = temporary.open();
            assert_eq!(loaded_state(&database), expected);
            database
                .connection
                .execute_batch(
                    "CREATE TRIGGER fail_backup BEFORE UPDATE ON app_state
                 BEGIN SELECT RAISE(ABORT, 'injected backup failure'); END;",
                )
                .unwrap();
            assert!(database.delete_plan("plan-2", None).is_err());
            assert_eq!(loaded_state(&database), expected);
            database
                .connection
                .execute_batch("DROP TRIGGER fail_backup")
                .unwrap();
            database.delete_plan("plan-2", None).unwrap();
            expected["plans"] = json!([]);
            expected["activePlanId"] = Value::Null;
            assert_eq!(loaded_state(&database), expected);
        }
        let database = temporary.open();
        assert_eq!(database.plan_count().unwrap(), 0);
        assert_eq!(loaded_state(&database), expected);
    }

    #[test]
    fn all_serialized_fields_survive_save_and_restart() {
        let temporary = TemporaryDatabase::new();
        let expected = complete_state();
        {
            let mut database = temporary.open();
            database.save_state_json(&expected.to_string()).unwrap();
        }
        let mut database = temporary.open();
        assert_eq!(loaded_state(&database), expected);
        database.migrate().unwrap();
        assert_eq!(loaded_state(&database), expected);
    }

    #[test]
    fn incremental_saves_survive_restart_and_keep_historical_names() {
        let temporary = TemporaryDatabase::new();
        let mut expected = complete_state();
        {
            let mut database = temporary.open();
            database.save_state_json(&expected.to_string()).unwrap();
            expected["plans"][0]["works"][0]["title"] = json!("Renamed work");
            expected["plans"][0]["works"][0]["bangumiSubjectType"] = json!("game");
            expected["plans"][0]["works"][0]["coverImageUrl"] = json!("assets/new-cover.png");
            expected["plans"][0]["points"][0]["name"] = json!("Renamed point");
            database
                .save_plan_bundle_json(
                    &expected["plans"][0].to_string(),
                    &expected["visitRecords"].to_string(),
                    Some("plan-1"),
                )
                .unwrap();
            expected["settings"]["themeMode"] = json!("system");
            expected["settings"]["fontScale"] = json!(1.1);
            expected["settings"]["customThemeColors"][0]["value"] = json!(0xFF765432_i64);
            database
                .save_settings_json(&expected["settings"].to_string())
                .unwrap();
            expected["visitRecords"][0]["workSubtitle"] = json!("Edited historical subtitle");
            database
                .save_visit_record_json(&expected["visitRecords"][0].to_string())
                .unwrap();
        }
        let database = temporary.open();
        assert_eq!(loaded_state(&database), expected);
        let backup: Value =
            serde_json::from_str(&database.load_legacy_state_json().unwrap().unwrap()).unwrap();
        assert_eq!(backup, expected);
    }

    #[test]
    fn nullable_metadata_and_empty_theme_colors_can_be_cleared() {
        let temporary = TemporaryDatabase::new();
        let mut expected = complete_state();
        {
            let mut database = temporary.open();
            database.save_state_json(&expected.to_string()).unwrap();
            for key in ["bangumiSubjectType", "coverImageUrl"] {
                expected["plans"][0]["works"][0][key] = Value::Null;
            }
            for key in ["workTitle", "workSubtitle", "pointName", "pointSubtitle"] {
                expected["visitRecords"][0][key] = Value::Null;
            }
            expected["settings"]["customThemeColors"] = json!([]);
            expected["settings"]["customThemeColorName"] = json!("");
            expected["settings"]["comparisonPilgrimName"] = json!("");
            database.save_state_json(&expected.to_string()).unwrap();
        }
        {
            let mut database = temporary.open();
            assert_eq!(loaded_state(&database), expected);
            for key in ["bangumiSubjectType", "coverImageUrl"] {
                expected["plans"][0]["works"][0][key] = json!("");
            }
            for key in ["workTitle", "workSubtitle", "pointName", "pointSubtitle"] {
                expected["visitRecords"][0][key] = json!("");
            }
            database.save_state_json(&expected.to_string()).unwrap();
        }
        assert_eq!(loaded_state(&temporary.open()), expected);
    }

    #[test]
    fn old_relational_columns_migrate_without_resetting_values() {
        let temporary = TemporaryDatabase::new();
        let mut expected = complete_state();
        {
            let mut database = temporary.open();
            database.save_state_json(&expected.to_string()).unwrap();
            for (column, key) in [
                ("font_scale", "fontScale"),
                ("theme_mode", "themeMode"),
                ("photo_location_strategy", "photoLocationStrategy"),
                ("save_visit_photo_to_gallery", "saveVisitPhotoToGallery"),
                (
                    "auto_save_comparison_to_gallery",
                    "autoSaveComparisonToGallery",
                ),
                ("comparison_show_pilgrim_name", "comparisonShowPilgrimName"),
                ("comparison_pilgrim_name", "comparisonPilgrimName"),
                ("custom_theme_color_name", "customThemeColorName"),
                ("custom_theme_color_value", "customThemeColorValue"),
                ("custom_theme_colors", "customThemeColors"),
                (
                    "custom_camera_aspect_ratio_width",
                    "customCameraAspectRatioWidth",
                ),
                (
                    "custom_camera_aspect_ratio_height",
                    "customCameraAspectRatioHeight",
                ),
                (
                    "dismiss_plan_actions_on_outside_tap",
                    "dismissPlanActionsOnOutsideTap",
                ),
                ("hide_completed_points_on_map", "hideCompletedPointsOnMap"),
                ("anitabi_remote_state_json", "anitabiRemoteStateJson"),
                ("route_planner_skill_tip_shown", "routePlannerSkillTipShown"),
                (
                    "route_planner_skill_promotion_dismissed",
                    "routePlannerSkillPromotionDismissed",
                ),
                (
                    "hide_imported_points_on_import_map",
                    "hideImportedPointsOnImportMap",
                ),
                ("map_show_thumbnail_markers", "mapShowThumbnailMarkers"),
                ("map_show_group_areas", "mapShowGroupAreas"),
                (
                    "import_map_show_thumbnail_markers",
                    "importMapShowThumbnailMarkers",
                ),
                ("import_map_show_group_areas", "importMapShowGroupAreas"),
            ] {
                database
                    .connection
                    .execute(
                        &format!("ALTER TABLE app_settings DROP COLUMN {column}"),
                        [],
                    )
                    .unwrap();
                expected["settings"][key] = default_settings_json()[key].clone();
            }
            for (column, key) in [
                ("bangumi_subject_type", "bangumiSubjectType"),
                ("cover_image_url", "coverImageUrl"),
            ] {
                database
                    .connection
                    .execute(&format!("ALTER TABLE works DROP COLUMN {column}"), [])
                    .unwrap();
                expected["plans"][0]["works"][0][key] = Value::Null;
            }
            for (column, key) in [
                ("work_title", "workTitle"),
                ("work_subtitle", "workSubtitle"),
                ("point_name", "pointName"),
                ("point_subtitle", "pointSubtitle"),
            ] {
                database
                    .connection
                    .execute(
                        &format!("ALTER TABLE visit_records DROP COLUMN {column}"),
                        [],
                    )
                    .unwrap();
                expected["visitRecords"][0][key] = Value::Null;
            }
        }
        {
            let mut database = temporary.open();
            assert_eq!(loaded_state(&database), expected);
            database.migrate().unwrap();
            assert_eq!(loaded_state(&database), expected);
            database
                .save_state_json(&complete_state().to_string())
                .unwrap();
        }
        assert_eq!(loaded_state(&temporary.open()), complete_state());
    }

    #[test]
    fn legacy_snapshot_migration_retains_all_serialized_fields() {
        let temporary = TemporaryDatabase::new();
        let expected = complete_state();
        {
            let database = temporary.connect();
            database
                .connection
                .execute_batch(
                    "CREATE TABLE app_state (
                   key TEXT PRIMARY KEY NOT NULL,
                   value TEXT NOT NULL,
                   updated_at TEXT NOT NULL
                 );",
                )
                .unwrap();
            database
                .connection
                .execute(
                    "INSERT INTO app_state VALUES (?1, ?2, '2026-01-01')",
                    params![STATE_KEY, expected.to_string()],
                )
                .unwrap();
        }
        {
            let mut database = temporary.open();
            assert_eq!(loaded_state(&database), expected);
            database.migrate().unwrap();
            assert_eq!(loaded_state(&database), expected);
        }
        assert_eq!(loaded_state(&temporary.open()), expected);
    }

    #[test]
    fn default_settings_match_inserted_and_migrated_defaults() {
        let mut database = memory_database();
        let expected = database.load_settings_json().unwrap();
        database.save_settings_json("{}").unwrap();
        assert_eq!(database.load_settings_json().unwrap(), expected);
        database
            .connection
            .execute("DELETE FROM app_settings", [])
            .unwrap();
        database
            .connection
            .execute("INSERT INTO app_settings (id) VALUES ('default')", [])
            .unwrap();
        assert_eq!(database.load_settings_json().unwrap(), expected);
    }

    fn memory_database() -> DesktopDatabase {
        let connection = Connection::open_in_memory().expect("open in-memory database");
        let mut database = DesktopDatabase {
            path: PathBuf::from(":memory:"),
            connection,
        };
        database.migrate().expect("migrate database");
        database
    }

    #[test]
    fn map_display_settings_round_trip() {
        let mut database = memory_database();
        database
            .save_settings_json(
                r#"{
                  "navigationApp": "amap",
                  "valhallaBaseUrl": "https://route.example/api",
                  "anitabiSiteBaseUrl": "https://site.example/anitabi",
                  "anitabiStaticDataBaseUrl": "https://static.example/data",
                  "anitabiApiBaseUrl": "https://api.example/v2",
                  "anitabiOfficialImageBaseUrl": "https://images.example/official",
                  "anitabiMirrorImageBaseUrl": "https://images.example/mirror",
                  "comparisonExportConfigJson": "{\"outputWidth\":\"w2560\"}",
                  "comparisonExportConfigMigrated": true,
                  "showPlanGroupProgress": false,
                  "mapMarkerClusteringEnabled": false,
                  "mapMarkerClusterRadius": 56,
                  "mapMarkerClusterMaxZoom": 20,
                  "mapGroupAreaRadiusMeters": 225,
                  "mapMarkerScale": 1.1,
                  "mapMaxZoom": 23,
                  "continuousMapLocation": false
                }"#,
            )
            .expect("save settings");

        let settings = database.load_settings_json().expect("load settings");
        assert_eq!(settings["navigationApp"], "amap");
        assert_eq!(settings["valhallaBaseUrl"], "https://route.example/api");
        assert_eq!(
            settings["anitabiSiteBaseUrl"],
            "https://site.example/anitabi"
        );
        assert_eq!(
            settings["anitabiStaticDataBaseUrl"],
            "https://static.example/data"
        );
        assert_eq!(settings["anitabiApiBaseUrl"], "https://api.example/v2");
        assert_eq!(
            settings["anitabiOfficialImageBaseUrl"],
            "https://images.example/official"
        );
        assert_eq!(
            settings["anitabiMirrorImageBaseUrl"],
            "https://images.example/mirror"
        );
        assert_eq!(
            settings["comparisonExportConfigJson"],
            r#"{"outputWidth":"w2560"}"#
        );
        assert_eq!(settings["comparisonExportConfigMigrated"], true);
        assert_eq!(settings["showPlanGroupProgress"], false);
        assert_eq!(settings["mapMarkerClusteringEnabled"], false);
        assert_eq!(settings["mapMarkerClusterRadius"], 56);
        assert_eq!(settings["mapMarkerClusterMaxZoom"], 20);
        assert_eq!(settings["mapGroupAreaRadiusMeters"], 225);
        assert_eq!(settings["mapMarkerScale"], 1.1);
        assert_eq!(settings["mapMaxZoom"], 23);
        assert_eq!(settings["continuousMapLocation"], false);
    }

    #[test]
    fn continuous_location_migrates_existing_settings_without_resetting_them() {
        let mut database = memory_database();
        database
            .save_settings_json(r#"{"mapMaxZoom":23,"navigationApp":"amap"}"#)
            .unwrap();
        database
            .connection
            .execute(
                "ALTER TABLE app_settings DROP COLUMN continuous_map_location",
                [],
            )
            .unwrap();
        database.migrate().unwrap();
        let settings = database.load_settings_json().unwrap();
        assert_eq!(settings["continuousMapLocation"], true);
        assert_eq!(settings["mapMaxZoom"], 23);
        assert_eq!(settings["navigationApp"], "amap");
        let mut updated = settings;
        updated["continuousMapLocation"] = json!(false);
        database.save_settings_json(&updated.to_string()).unwrap();
        database.migrate().unwrap();
        assert_eq!(
            database.load_settings_json().unwrap()["continuousMapLocation"],
            false
        );
    }

    #[test]
    fn map_appearance_migrates_and_round_trips_without_resetting_settings() {
        let mut database = memory_database();
        database
            .save_settings_json(r#"{"mapMaxZoom":23,"continuousMapLocation":false}"#)
            .unwrap();
        database
            .connection
            .execute("ALTER TABLE app_settings DROP COLUMN map_appearance", [])
            .unwrap();
        database.migrate().unwrap();
        let mut settings = database.load_settings_json().unwrap();
        assert_eq!(settings["mapAppearance"], "automatic");
        assert_eq!(settings["mapMaxZoom"], 23);
        assert_eq!(settings["continuousMapLocation"], false);
        settings["mapAppearance"] = json!("light");
        database.save_settings_json(&settings.to_string()).unwrap();
        database.migrate().unwrap();
        assert_eq!(
            database.load_settings_json().unwrap()["mapAppearance"],
            "light"
        );
    }

    #[test]
    fn map_display_columns_are_added_to_existing_settings_table() {
        let mut database = memory_database();
        database
            .save_settings_json(r#"{"uiScale": 0.9}"#)
            .expect("save existing settings");
        database
            .connection
            .execute(
                "ALTER TABLE app_settings DROP COLUMN map_group_area_radius_meters",
                [],
            )
            .expect("drop radius column");
        database
            .connection
            .execute("ALTER TABLE app_settings DROP COLUMN map_marker_scale", [])
            .expect("drop scale column");
        database
            .connection
            .execute("ALTER TABLE app_settings DROP COLUMN map_max_zoom", [])
            .expect("drop max zoom column");
        database
            .connection
            .execute("ALTER TABLE app_settings DROP COLUMN navigation_app", [])
            .expect("drop navigation column");
        database
            .connection
            .execute("ALTER TABLE app_settings DROP COLUMN valhalla_base_url", [])
            .expect("drop Valhalla column");
        database
            .connection
            .execute(
                "ALTER TABLE app_settings DROP COLUMN map_marker_clustering_enabled",
                [],
            )
            .expect("drop clustering enabled column");
        database
            .connection
            .execute(
                "ALTER TABLE app_settings DROP COLUMN map_marker_cluster_radius",
                [],
            )
            .expect("drop cluster radius column");
        database
            .connection
            .execute(
                "ALTER TABLE app_settings DROP COLUMN map_marker_cluster_max_zoom",
                [],
            )
            .expect("drop cluster zoom column");
        database
            .connection
            .execute(
                "ALTER TABLE app_settings DROP COLUMN show_plan_group_progress",
                [],
            )
            .expect("drop plan group progress column");
        for column in [
            "anitabi_site_base_url",
            "anitabi_static_data_base_url",
            "anitabi_api_base_url",
            "anitabi_official_image_base_url",
            "anitabi_mirror_image_base_url",
            "comparison_export_config_json",
            "comparison_export_config_migrated",
        ] {
            database
                .connection
                .execute(
                    &format!("ALTER TABLE app_settings DROP COLUMN {column}"),
                    [],
                )
                .expect("drop Anitabi service column");
        }

        database
            .ensure_app_settings_columns()
            .expect("restore map display columns");
        let settings = database.load_settings_json().expect("load settings");
        assert_eq!(settings["uiScale"], 0.9);
        assert_eq!(settings["navigationApp"], "googleMaps");
        assert_eq!(
            settings["valhallaBaseUrl"],
            "https://valhalla1.openstreetmap.de"
        );
        assert_eq!(settings["anitabiSiteBaseUrl"], "https://www.anitabi.cn");
        assert_eq!(
            settings["anitabiStaticDataBaseUrl"],
            "https://www.anitabi.cn/d"
        );
        assert_eq!(settings["anitabiApiBaseUrl"], "https://api.anitabi.cn");
        assert_eq!(
            settings["anitabiOfficialImageBaseUrl"],
            "https://image.anitabi.cn"
        );
        assert_eq!(
            settings["anitabiMirrorImageBaseUrl"],
            "https://img-tc.anitabi.cn"
        );
        assert_eq!(settings["comparisonExportConfigJson"], "");
        assert_eq!(settings["comparisonExportConfigMigrated"], true);
        assert_eq!(settings["showPlanGroupProgress"], true);
        assert_eq!(settings["mapMarkerClusteringEnabled"], true);
        assert_eq!(settings["mapMarkerClusterRadius"], 40);
        assert_eq!(settings["mapMarkerClusterMaxZoom"], 21);
        assert_eq!(settings["mapGroupAreaRadiusMeters"], 160);
        assert_eq!(settings["mapMarkerScale"], 0.9);
        assert_eq!(settings["mapMaxZoom"], 22);
    }

    #[test]
    fn previous_map_zoom_defaults_are_migrated_once() {
        let mut database = memory_database();
        database
            .connection
            .execute(
                "INSERT OR REPLACE INTO app_settings (
                   id, map_marker_cluster_max_zoom, map_max_zoom
                 ) VALUES ('default', 18, 20)",
                [],
            )
            .expect("insert old defaults");
        database
            .connection
            .execute(
                "DELETE FROM app_meta WHERE key = 'map_zoom_defaults_v2'",
                [],
            )
            .expect("reset migration marker");

        database
            .migrate_map_zoom_defaults()
            .expect("migrate old defaults");
        let settings = database.load_settings_json().expect("load settings");
        assert_eq!(settings["mapMarkerClusterMaxZoom"], 21);
        assert_eq!(settings["mapMaxZoom"], 22);

        database
            .save_settings_json(r#"{"mapMarkerClusterMaxZoom":18,"mapMaxZoom":20}"#)
            .expect("save explicit settings");
        database
            .migrate_map_zoom_defaults()
            .expect("skip completed migration");
        let explicit = database.load_settings_json().expect("reload settings");
        assert_eq!(explicit["mapMarkerClusterMaxZoom"], 18);
        assert_eq!(explicit["mapMaxZoom"], 20);
    }
}
