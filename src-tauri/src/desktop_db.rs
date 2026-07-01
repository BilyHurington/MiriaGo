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
        let state = json!({
            "schemaVersion": 1,
            "activePlanId": self.active_plan_id()?,
            "settings": self.load_settings_json()?,
            "plans": self.load_plans_json()?,
            "visitRecords": self.load_visit_records_json()?,
        });
        serde_json::to_string(&state)
            .map(Some)
            .map_err(|error| error.to_string())
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
        let tx = self
            .connection
            .transaction()
            .map_err(|error| error.to_string())?;
        set_active_plan_in_tx(&tx, Some(plan_id))?;
        tx.commit().map_err(|error| error.to_string())?;
        self.refresh_backup_state()
    }

    pub fn save_settings_json(&mut self, settings_json: &str) -> Result<(), String> {
        let settings: Value =
            serde_json::from_str(settings_json).map_err(|error| error.to_string())?;
        let tx = self
            .connection
            .transaction()
            .map_err(|error| error.to_string())?;
        tx.execute("DELETE FROM app_settings WHERE id = 'default'", [])
            .map_err(|error| error.to_string())?;
        insert_settings(&tx, Some(&settings))?;
        tx.commit().map_err(|error| error.to_string())?;
        self.refresh_backup_state()
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
        let tx = self
            .connection
            .transaction()
            .map_err(|error| error.to_string())?;
        replace_plan_bundle(&tx, &plan_id, &plan, &visit_records, active_plan_id)?;
        tx.commit().map_err(|error| error.to_string())?;
        self.refresh_backup_state()
    }

    pub fn delete_plan(
        &mut self,
        plan_id: &str,
        active_plan_id: Option<&str>,
    ) -> Result<(), String> {
        let tx = self
            .connection
            .transaction()
            .map_err(|error| error.to_string())?;
        delete_plan_rows(&tx, plan_id)?;
        set_active_plan_in_tx(&tx, active_plan_id)?;
        tx.commit().map_err(|error| error.to_string())?;
        self.refresh_backup_state()
    }

    pub fn save_visit_record_json(&mut self, record_json: &str) -> Result<(), String> {
        let record: Value = serde_json::from_str(record_json).map_err(|error| error.to_string())?;
        let record_id = required_string(&record, "id")?.to_string();
        let tx = self
            .connection
            .transaction()
            .map_err(|error| error.to_string())?;
        tx.execute(
            "DELETE FROM visit_records WHERE id = ?1",
            params![record_id],
        )
        .map_err(|error| error.to_string())?;
        insert_visit_record(&tx, &record)?;
        tx.commit().map_err(|error| error.to_string())?;
        self.refresh_backup_state()
    }

    pub fn delete_visit_record(&mut self, record_id: &str) -> Result<(), String> {
        let tx = self
            .connection
            .transaction()
            .map_err(|error| error.to_string())?;
        tx.execute(
            "DELETE FROM visit_records WHERE id = ?1",
            params![record_id],
        )
        .map_err(|error| error.to_string())?;
        tx.commit().map_err(|error| error.to_string())?;
        self.refresh_backup_state()
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
                  custom_xyz_tile_url TEXT NOT NULL DEFAULT '',
                  custom_maplibre_style_url TEXT NOT NULL DEFAULT '',
                  map_thumbnail_visible_threshold INTEGER NOT NULL DEFAULT 40,
                  map_thumbnail_concurrent_loads INTEGER NOT NULL DEFAULT 10
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
        self.ensure_plan_columns()?;
        self.ensure_points_columns()?;
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
            ("map_tile_provider", "TEXT NOT NULL DEFAULT 'openFreeMap'"),
            ("open_free_map_style", "TEXT NOT NULL DEFAULT 'liberty'"),
            ("anitabi_image_source", "TEXT NOT NULL DEFAULT 'auto'"),
            ("custom_xyz_tile_url", "TEXT NOT NULL DEFAULT ''"),
            ("custom_maplibre_style_url", "TEXT NOT NULL DEFAULT ''"),
            (
                "map_thumbnail_visible_threshold",
                "INTEGER NOT NULL DEFAULT 40",
            ),
            (
                "map_thumbnail_concurrent_loads",
                "INTEGER NOT NULL DEFAULT 10",
            ),
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
                .execute("ALTER TABLE plans ADD COLUMN memo TEXT NOT NULL DEFAULT ''", [])
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

    fn refresh_backup_state(&mut self) -> Result<(), String> {
        let Some(state_json) = self.load_state_json()? else {
            return Ok(());
        };
        let tx = self
            .connection
            .transaction()
            .map_err(|error| error.to_string())?;
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
                        custom_xyz_tile_url, custom_maplibre_style_url,
                        map_thumbnail_visible_threshold, map_thumbnail_concurrent_loads
                 FROM app_settings WHERE id = 'default'",
                [],
                |row| {
                    Ok(json!({
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
                        "customXyzTileUrl": row.get::<_, String>(11)?,
                        "customMapLibreStyleUrl": row.get::<_, String>(12)?,
                        "mapThumbnailVisibleThreshold": row.get::<_, i64>(13)?,
                        "mapThumbnailConcurrentLoads": row.get::<_, i64>(14)?,
                    }))
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
                 FROM plans ORDER BY created_at ASC",
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
                "SELECT id, bangumi_id, bangumi_subject_type, title, subtitle, city, source
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
                        reference_mode, captured_at
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
    for plan in array_value(state.get("plans")) {
        insert_plan(tx, plan, active_plan_id)?;
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
    delete_plan_graph_rows(tx, plan_id)?;
    tx.execute(
        "DELETE FROM visit_records WHERE plan_id = ?1",
        params![plan_id],
    )
    .map_err(|error| error.to_string())?;
    if active_plan_id.is_some() {
        set_active_plan_in_tx(tx, active_plan_id)?;
    }
    insert_plan(tx, plan, active_plan_id)?;
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
           open_free_map_style, anitabi_image_source, custom_xyz_tile_url,
           custom_maplibre_style_url, map_thumbnail_visible_threshold,
           map_thumbnail_concurrent_loads
         ) VALUES ('default', ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15)",
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
            string_value(settings, "customXyzTileUrl", ""),
            string_value(settings, "customMapLibreStyleUrl", ""),
            i64_value(settings, "mapThumbnailVisibleThreshold", 40).clamp(0, 200),
            i64_value(settings, "mapThumbnailConcurrentLoads", 10).clamp(1, 30),
        ],
    )
    .map_err(|error| error.to_string())?;
    Ok(())
}

fn insert_plan(
    tx: &Transaction<'_>,
    plan: &Value,
    active_plan_id: Option<&str>,
) -> Result<(), String> {
    let plan_id = required_string(plan, "id")?;
    tx.execute(
        "INSERT INTO plans (id, name, area, memo, current_group_id, active, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
        params![
            plan_id,
            string_value(plan, "name", "桌面端计划"),
            string_value(plan, "area", ""),
            string_value(plan, "memo", ""),
            optional_string(plan, "currentGroupId"),
            (active_plan_id == Some(plan_id)) as i64,
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
           id, plan_id, bangumi_id, bangumi_subject_type, title, subtitle, city, source
         ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
        params![
            required_string(work, "id")?,
            plan_id,
            optional_i64(work, "bangumiId"),
            optional_string(work, "bangumiSubjectType"),
            string_value(work, "title", "作品"),
            string_value(work, "subtitle", ""),
            string_value(work, "city", ""),
            string_value(work, "source", "manual"),
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
           reference_mode, captured_at
         ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14)",
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
        ],
    )
    .map_err(|error| error.to_string())?;
    Ok(())
}

fn default_settings_json() -> Value {
    json!({
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
        "customXyzTileUrl": "",
        "customMapLibreStyleUrl": "",
        "mapThumbnailVisibleThreshold": 40,
        "mapThumbnailConcurrentLoads": 10,
    })
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

fn optional_i64(value: &Value, key: &str) -> Option<i64> {
    value.get(key).and_then(Value::as_i64)
}

fn f64_value(value: &Value, key: &str, fallback: f64) -> f64 {
    value.get(key).and_then(Value::as_f64).unwrap_or(fallback)
}

fn optional_f64(value: &Value, key: &str) -> Option<f64> {
    value.get(key).and_then(Value::as_f64)
}
