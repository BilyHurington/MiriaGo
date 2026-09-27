use super::*;

struct TestDirectory(PathBuf);

impl TestDirectory {
    fn new() -> Self {
        let path = std::env::temp_dir().join(unique_name("miriago-file-io-test"));
        create_directory(&path).unwrap();
        Self(path.canonicalize().unwrap())
    }

    fn entries(&self) -> usize {
        fs::read_dir(&self.0).unwrap().count()
    }
}

impl Drop for TestDirectory {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).unwrap();
    }
}

fn assets(entries: &[(&str, &[u8])]) -> HashMap<String, String> {
    entries
        .iter()
        .map(|(path, bytes)| (path.to_string(), general_purpose::STANDARD.encode(bytes)))
        .collect()
}

#[test]
fn windows_path_syntax_is_rejected_on_every_host() {
    for path in [
        "C:/assets/a.jpg",
        "C:assets/a.jpg",
        "//server/share/assets/a.jpg",
        r"\\server\share\assets\a.jpg",
        r"\\?\C:\assets\a.jpg",
        "assets/C:/a.jpg",
        "assets/C:a.jpg",
        "assets/image.jpg:stream",
        "assets/image.jpg::$DATA",
        r"assets\..\outside.jpg",
        r"assets/a\..\..\outside.jpg",
        "assets/../outside.jpg",
        "assets/./a.jpg",
        "assets//a.jpg",
        "assets/a/",
        "assets/a\0.jpg",
        "assets/a\n.jpg",
        "assets/a?b.jpg",
        "assets/a*.jpg",
        "assets/CON",
        "assets/aux.png",
        "assets/NUL.txt",
        "assets/prn/a.jpg",
        "assets/CON .jpg",
        "assets/COM1.jpg",
        "assets/LPT9.png",
        "assets/COM\u{b9}.jpg",
        "assets/a. /b.jpg",
        "assets/a./b.jpg",
        "assets/a /b.jpg",
    ] {
        assert!(safe_asset_path(path).is_err(), "{path}");
        assert!(super::super::safe_local_asset_path(path).is_err(), "{path}");
    }
    for path in [
        "assets/photo.jpg",
        "assets/full_references/a-b_1.png",
        "assets/COM10.jpg",
    ] {
        assert!(safe_asset_path(path).is_ok(), "{path}");
    }
}

#[test]
fn bounded_base64_checks_exact_decoded_bytes_and_invalid_input() {
    for size in 0..=9 {
        let bytes = vec![42; size];
        let encoded = general_purpose::STANDARD.encode(&bytes);
        assert_eq!(decode_bounded(&encoded, size).unwrap(), bytes);
        if size > 0 {
            assert!(decode_bounded(&encoded, size - 1).is_err());
        }
    }
    for encoded in ["a", "abc", "====", "!!!!", "AA=A", "AAAA\n", "AB=="] {
        assert!(decode_bounded(encoded, 10).is_err(), "{encoded}");
    }
}

#[test]
fn repeated_imports_use_exclusive_directories_and_preserve_existing_assets() {
    let root = TestDirectory::new();
    let old = root
        .0
        .join("assets/imported_plan_assets/external_package_id/assets/photo.jpg");
    fs::create_dir_all(old.parent().unwrap()).unwrap();
    fs::write(&old, b"existing user asset").unwrap();
    let first = restore_assets(&root.0, assets(&[("assets/photo.jpg", b"first")]))
        .unwrap()
        .paths;
    let second = restore_assets(&root.0, assets(&[("assets/photo.jpg", b"second")]))
        .unwrap()
        .paths;
    assert_ne!(first["assets/photo.jpg"], second["assets/photo.jpg"]);
    assert_eq!(
        fs::read(root.0.join(&first["assets/photo.jpg"])).unwrap(),
        b"first"
    );
    assert_eq!(
        fs::read(root.0.join(&second["assets/photo.jpg"])).unwrap(),
        b"second"
    );
    assert_eq!(fs::read(old).unwrap(), b"existing user asset");
}

#[test]
fn import_limits_are_checked_before_creating_any_directories() {
    let root = TestDirectory::new();
    for (input, count, single, total) in [
        (assets(&[("assets/a", b"a"), ("assets/b", b"b")]), 1, 10, 10),
        (assets(&[("assets/a", b"abc")]), 1, 2, 10),
        (assets(&[("assets/a", b"ab"), ("assets/b", b"cd")]), 2, 2, 3),
        (assets(&[("assets/C:escape", b"a")]), 1, 10, 10),
    ] {
        assert!(
            restore_assets_with(&root.0, input, count, single, total, |_, _| panic!(
                "preflight must reject"
            ))
            .is_err()
        );
        assert_eq!(root.entries(), 0);
    }
    let too_many = (0..=MAX_IMPORT_ASSETS)
        .map(|i| (format!("assets/{i}"), String::new()))
        .collect();
    assert!(restore_assets(&root.0, too_many).is_err());
    assert_eq!(root.entries(), 0);
}

#[test]
fn import_budget_boundary_and_empty_assets_are_supported() {
    let root = TestDirectory::new();
    let restored = restore_assets_with(
        &root.0,
        assets(&[("assets/a", b"ab"), ("assets/b", b"cd")]),
        2,
        2,
        4,
        |path, bytes| {
            exclusive_file(path)
                .unwrap()
                .write_all(bytes)
                .map_err(|e| e.to_string())
        },
    )
    .unwrap();
    assert_eq!(restored.paths.len(), 2);
    assert!(restore_assets(&root.0, HashMap::new())
        .unwrap()
        .paths
        .is_empty());
    let import_root = root.0.join("assets/imported_plan_assets");
    let before = fs::read_dir(&import_root).unwrap().count();
    assert!(restore_assets(&root.0, assets(&[("assets/empty", b"")]))
        .unwrap()
        .paths
        .is_empty());
    assert_eq!(fs::read_dir(import_root).unwrap().count(), before);
}

#[test]
fn failed_import_cleans_only_its_own_directory() {
    let root = TestDirectory::new();
    let old = restore_assets(&root.0, assets(&[("assets/old", b"keep")]))
        .unwrap()
        .paths;
    let import_root = root.0.join("assets/imported_plan_assets");
    let before = fs::read_dir(&import_root).unwrap().count();
    let mut input = assets(&[("assets/a", b"written first")]);
    input.insert("assets/z".to_string(), "!!!!".to_string());
    assert!(restore_assets(&root.0, input).is_err());
    assert_eq!(fs::read_dir(&import_root).unwrap().count(), before);
    let mut writes = 0;
    let result = restore_assets_with(
        &root.0,
        assets(&[("assets/a", b"a"), ("assets/b", b"b")]),
        2,
        10,
        20,
        |path, bytes| {
            writes += 1;
            exclusive_file(path).unwrap().write_all(bytes).unwrap();
            if writes == 2 {
                Err("injected disk error".to_string())
            } else {
                Ok(())
            }
        },
    );
    assert!(result.unwrap_err().contains("injected disk error"));
    assert_eq!(writes, 2);
    assert_eq!(fs::read_dir(&import_root).unwrap().count(), before);
    assert_eq!(fs::read(root.0.join(&old["assets/old"])).unwrap(), b"keep");
}

#[test]
fn import_file_directory_conflicts_roll_back_the_batch() {
    let root = TestDirectory::new();
    assert!(restore_assets(&root.0, assets(&[("assets/a", b"a"), ("assets/a/b", b"b")])).is_err());
    assert_eq!(
        fs::read_dir(root.0.join("assets/imported_plan_assets"))
            .unwrap()
            .count(),
        0
    );
}

#[test]
fn atomic_write_failure_preserves_target_and_cleans_staging_file() {
    let root = TestDirectory::new();
    let path = root.0.join("existing.csv");
    fs::write(&path, b"original").unwrap();
    let error = atomic_write_with(&path, |file| {
        file.write_all(b"partial")?;
        Err(std::io::Error::other("injected write error"))
    })
    .unwrap_err();
    assert!(error.contains("injected write error"));
    assert_eq!(fs::read(&path).unwrap(), b"original");
    assert_eq!(root.entries(), 1);
    atomic_write(&path, b"replacement").unwrap();
    assert_eq!(fs::read(&path).unwrap(), b"replacement");
    assert_eq!(root.entries(), 1);
}

#[test]
fn atomic_rename_failure_does_not_delete_the_destination() {
    let root = TestDirectory::new();
    let path = root.0.join("destination.csv");
    let error = atomic_write_with(&path, |file| {
        file.write_all(b"new")?;
        fs::create_dir(&path)?;
        fs::write(path.join("keep"), b"original")
    })
    .unwrap_err();
    assert!(error.contains("regular file"));
    assert_eq!(fs::read(path.join("keep")).unwrap(), b"original");
    assert_eq!(root.entries(), 1);
}

#[test]
fn export_requires_exact_dialog_path_and_extension_and_is_one_shot() {
    let root = TestDirectory::new();
    let path = root.0.join("export.csv");
    fs::write(&path, b"original").unwrap();
    let encoded = general_purpose::STANDARD.encode(b"replacement");
    let mut authorization = ExportAuthorization::new();
    assert!(authorization
        .write(path.to_str().unwrap(), "csv", &encoded)
        .is_err());
    let authorized = authorization.authorize(path.clone(), "csv").unwrap();
    assert!(authorization
        .write(root.0.join("other.csv").to_str().unwrap(), "csv", &encoded)
        .is_err());
    assert!(authorization
        .write(&authorized, "sjhplan", &encoded)
        .is_err());
    assert!(authorization
        .write(
            &format!("{}/./export.csv", root.0.display()),
            "csv",
            &encoded
        )
        .is_err());
    assert_eq!(fs::read(&path).unwrap(), b"original");
    authorization.write(&authorized, ".CSV", &encoded).unwrap();
    assert_eq!(fs::read(&path).unwrap(), b"replacement");
    assert!(authorization.write(&authorized, "csv", &encoded).is_err());
    assert_eq!(root.entries(), 1);
}

#[test]
fn export_failure_allows_retry_but_cancel_or_new_dialog_revokes_it() {
    let root = TestDirectory::new();
    let mut authorization = ExportAuthorization::new();
    let selected = authorization
        .authorize(root.0.join("a.csv"), "csv")
        .unwrap();
    assert!(authorization.write(&selected, "csv", "!!!!").is_err());
    assert_eq!(root.entries(), 0);
    fs::create_dir(&selected).unwrap();
    assert!(authorization.write(&selected, "csv", "YQ==").is_err());
    fs::remove_dir(&selected).unwrap();
    authorization.write(&selected, "csv", "YQ==").unwrap();
    let selected = authorization
        .authorize(root.0.join("a.csv"), "csv")
        .unwrap();
    authorization.clear();
    assert!(authorization.write(&selected, "csv", "Yg==").is_err());
    let old = authorization
        .authorize(root.0.join("a.csv"), "csv")
        .unwrap();
    let new = authorization
        .authorize(root.0.join("b.csv"), "csv")
        .unwrap();
    assert!(authorization.write(&old, "csv", "Yg==").is_err());
    authorization.write(&new, "csv", "Yg==").unwrap();
    assert_eq!(fs::read(root.0.join("a.csv")).unwrap(), b"a");
    assert_eq!(fs::read(root.0.join("b.csv")).unwrap(), b"b");
}

#[test]
fn failed_export_authorization_checks_preserve_the_valid_overwrite_grant() {
    let root = TestDirectory::new();
    let path = root.0.join("existing.CSV");
    fs::write(&path, b"original").unwrap();
    let mut authorization = ExportAuthorization::new();
    let selected = authorization.authorize(path.clone(), "csv").unwrap();
    for (requested_path, extension, payload) in [
        (selected.as_str(), "../csv", "YQ=="),
        (selected.as_str(), "sjhplan", "YQ=="),
        (selected.as_str(), "csv", "!!!!"),
        ("C:\\not-authorized\\existing.CSV", "csv", "YQ=="),
        ("\\\\server\\share\\existing.CSV", "csv", "YQ=="),
    ] {
        assert!(authorization
            .write(requested_path, extension, payload)
            .is_err());
        assert_eq!(fs::read(&path).unwrap(), b"original");
        assert_eq!(root.entries(), 1);
    }
    authorization
        .write(&selected, "csv", "cmVwbGFjZW1lbnQ=")
        .unwrap();
    assert_eq!(fs::read(&path).unwrap(), b"replacement");
    assert!(authorization.write(&selected, "csv", "YQ==").is_err());
}

#[cfg(unix)]
#[test]
fn export_permission_failure_preserves_existing_file_and_allows_retry() {
    use std::os::unix::fs::PermissionsExt;
    let root = TestDirectory::new();
    let path = root.0.join("existing.csv");
    fs::write(&path, b"original").unwrap();
    let mut authorization = ExportAuthorization::new();
    let selected = authorization.authorize(path.clone(), "csv").unwrap();
    let permissions = fs::metadata(&root.0).unwrap().permissions();
    fs::set_permissions(&root.0, fs::Permissions::from_mode(0o500)).unwrap();
    let failed = authorization.write(&selected, "csv", "YQ==");
    fs::set_permissions(&root.0, permissions).unwrap();
    assert!(failed.is_err(), "Run permission tests as a non-root user");
    assert_eq!(fs::read(&path).unwrap(), b"original");
    assert_eq!(root.entries(), 1);
    authorization.write(&selected, "csv", "YQ==").unwrap();
    assert_eq!(fs::read(&path).unwrap(), b"a");
    assert_eq!(root.entries(), 1);
}

#[cfg(windows)]
#[test]
fn windows_export_sharing_violation_preserves_existing_file_and_allows_retry() {
    use std::os::windows::fs::OpenOptionsExt;
    let root = TestDirectory::new();
    let path = root.0.join("existing.csv");
    fs::write(&path, b"original").unwrap();
    let mut authorization = ExportAuthorization::new();
    let selected = authorization.authorize(path.clone(), "csv").unwrap();
    let blocker = OpenOptions::new()
        .read(true)
        .share_mode(0)
        .open(&path)
        .unwrap();
    let failed = authorization.write(&selected, "csv", "YQ==");
    drop(blocker);
    assert!(failed.is_err());
    assert_eq!(fs::read(&path).unwrap(), b"original");
    assert_eq!(root.entries(), 1);
    authorization.write(&selected, "csv", "YQ==").unwrap();
    assert_eq!(fs::read(&path).unwrap(), b"a");
    assert_eq!(root.entries(), 1);
}

#[test]
fn export_extension_cannot_redirect_or_silently_overwrite_another_file() {
    let root = TestDirectory::new();
    let mut authorization = ExportAuthorization::new();
    for extension in ["", "../csv", "csv/a", "csv\\a", "csv:stream", "csv\0"] {
        assert!(authorization
            .authorize(root.0.join("file"), extension)
            .is_err());
    }
    assert!(authorization
        .authorize(root.0.join("file.exe"), "csv")
        .is_err());
    assert!(authorization
        .authorize(root.0.join("file.csv:stream.csv"), "csv")
        .is_err());
    assert!(authorization
        .authorize(PathBuf::from("relative.csv"), "csv")
        .is_err());
    fs::write(root.0.join("file.csv"), b"keep").unwrap();
    assert!(authorization.authorize(root.0.join("file"), "csv").is_err());
    assert_eq!(fs::read(root.0.join("file.csv")).unwrap(), b"keep");
    let selected = authorization.authorize(root.0.join("new"), "csv").unwrap();
    assert_eq!(selected, root.0.join("new.csv").to_str().unwrap());
}

#[test]
fn ipc_export_command_rejects_arbitrary_paths_without_a_dialog() {
    let root = TestDirectory::new();
    let path = root.0.join("unauthorized.csv");
    let result = super::super::write_export_file(super::super::WriteExportFileRequest {
        path: path.to_str().unwrap().to_string(),
        extension: "csv".to_string(),
        data_base64: "YQ==".to_string(),
    });
    assert!(result.is_err());
    assert_eq!(root.entries(), 0);
}

#[cfg(unix)]
#[test]
fn asset_resolution_and_import_reject_symlinked_parents_and_leaf_files() {
    use std::os::unix::fs::symlink;
    let root = TestDirectory::new();
    let outside = TestDirectory::new();
    fs::write(outside.0.join("secret"), b"keep").unwrap();
    fs::create_dir(root.0.join("assets")).unwrap();
    symlink(&outside.0, root.0.join("assets/reference_full")).unwrap();
    for create in [false, true] {
        assert!(
            resolve_asset_path(&root.0, Path::new("assets/reference_full/secret"), create).is_err()
        );
    }
    symlink(outside.0.join("secret"), root.0.join("assets/linked")).unwrap();
    symlink(outside.0.join("missing"), root.0.join("assets/dangling")).unwrap();
    for path in ["assets/linked", "assets/dangling"] {
        assert!(resolve_asset_path(&root.0, Path::new(path), false).is_err());
        assert!(resolve_asset_path(&root.0, Path::new(path), true).is_err());
    }
    symlink(&outside.0, root.0.join("assets/imported_plan_assets")).unwrap();
    assert!(restore_assets(&root.0, assets(&[("assets/secret", b"replace")])).is_err());
    assert_eq!(outside.entries(), 1);
    assert_eq!(fs::read(outside.0.join("secret")).unwrap(), b"keep");
}

#[cfg(unix)]
#[test]
fn hardlinks_and_symlinked_export_destinations_are_rejected() {
    use std::os::unix::fs::symlink;
    let root = TestDirectory::new();
    let original = root.0.join("original.csv");
    fs::write(&original, b"keep").unwrap();
    let link = root.0.join("link.csv");
    symlink(&original, &link).unwrap();
    let mut authorization = ExportAuthorization::new();
    assert!(authorization.authorize(link.clone(), "csv").is_err());
    let selected = authorization
        .authorize(root.0.join("new.csv"), "csv")
        .unwrap();
    symlink(&original, &selected).unwrap();
    assert!(authorization.write(&selected, "csv", "YQ==").is_err());
    assert!(read_bounded(&link, 100).is_err());
    fs::create_dir(root.0.join("assets")).unwrap();
    fs::hard_link(&original, root.0.join("assets/hardlink")).unwrap();
    assert!(resolve_asset_path(&root.0, Path::new("assets/hardlink"), false).is_err());
    assert_eq!(fs::read(original).unwrap(), b"keep");
}

#[test]
fn bounded_asset_read_rejects_oversized_files() {
    let root = TestDirectory::new();
    let path = root.0.join("asset");
    fs::write(&path, b"1234").unwrap();
    assert_eq!(read_bounded(&path, 4).unwrap(), b"1234");
    assert!(read_bounded(&path, 3).is_err());
}

#[test]
fn native_path_joins_resolve_safely_on_windows_and_unix() {
    let root = TestDirectory::new();
    let relative = PathBuf::from("assets").join("nested").join("photo.jpg");
    let path = resolve_asset_path(&root.0, &relative, true).unwrap();
    atomic_write(&path, b"photo").unwrap();
    assert_eq!(read_bounded(&path, 100).unwrap(), b"photo");
    assert_eq!(resolve_asset_path(&root.0, &relative, false).unwrap(), path);
    assert!(resolve_asset_path(&root.0, Path::new("assets/../escape"), true).is_err());
    assert_eq!(
        resolve_asset_path(&root.0, Path::new("assets/missing/a.jpg"), false).unwrap(),
        root.0.join("assets/missing/a.jpg")
    );
}

#[test]
fn import_cleanup_token_owns_only_its_restore_and_finalize_revokes_deletion() {
    let root = TestDirectory::new();
    let old = root.0.join("old-user-asset");
    fs::write(&old, b"keep").unwrap();
    let mut registry = ImportRestorations::default();
    let (first, first_token) = registry
        .restore(&root.0, assets(&[("assets/a", b"first")]))
        .unwrap();
    let (second, second_token) = registry
        .restore(&root.0, assets(&[("assets/a", b"second")]))
        .unwrap();
    let first_token = first_token.unwrap();
    let second_token = second_token.unwrap();
    assert_ne!(first_token, second_token);
    assert_eq!(
        general_purpose::URL_SAFE_NO_PAD
            .decode(&first_token)
            .unwrap()
            .len(),
        32
    );
    let first_directory = registry.pending[&first_token].path.clone();
    assert!(registry.cleanup(old.to_str().unwrap()).is_err());
    assert!(registry.cleanup(&second["assets/a"]).is_err());
    assert_eq!(fs::read(&old).unwrap(), b"keep");
    assert_eq!(
        fs::read(root.0.join(&second["assets/a"])).unwrap(),
        b"second"
    );
    registry.cleanup(&first_token).unwrap();
    assert!(!first_directory.exists());
    assert!(!root.0.join(&first["assets/a"]).exists());
    assert!(registry.cleanup(&first_token).is_err());
    registry.finalize(&second_token).unwrap();
    assert!(registry.cleanup(&second_token).is_err());
    assert!(registry.finalize(&second_token).is_err());
    assert_eq!(
        fs::read(root.0.join(&second["assets/a"])).unwrap(),
        b"second"
    );
    assert_eq!(fs::read(&old).unwrap(), b"keep");
    assert!(registry.pending.is_empty());
}

#[test]
fn replaced_owned_directory_is_not_deleted_and_cleanup_can_retry() {
    let root = TestDirectory::new();
    let mut registry = ImportRestorations::default();
    let (_, token) = registry
        .restore(&root.0, assets(&[("assets/a", b"a")]))
        .unwrap();
    let token = token.unwrap();
    let owned = registry.pending[&token].path.clone();
    let moved = root.0.join("moved-original");
    fs::rename(&owned, &moved).unwrap();
    fs::create_dir(&owned).unwrap();
    fs::write(owned.join("unrelated"), b"keep").unwrap();
    assert!(registry.cleanup(&token).is_err());
    assert_eq!(fs::read(owned.join("unrelated")).unwrap(), b"keep");
    assert!(registry.pending.contains_key(&token));
    fs::remove_file(owned.join("unrelated")).unwrap();
    fs::remove_dir(&owned).unwrap();
    fs::rename(&moved, &owned).unwrap();
    registry.cleanup(&token).unwrap();
    assert!(!owned.exists());
}

#[test]
fn import_tokens_are_not_reusable_in_another_process_registry() {
    let root = TestDirectory::new();
    let mut registry = ImportRestorations::default();
    let (paths, token) = registry
        .restore(&root.0, assets(&[("assets/a", b"a")]))
        .unwrap();
    let token = token.unwrap();
    let mut another = ImportRestorations::default();
    assert!(another.cleanup(&token).is_err());
    assert!(another.finalize(&token).is_err());
    assert_eq!(fs::read(root.0.join(&paths["assets/a"])).unwrap(), b"a");
    registry.cleanup(&token).unwrap();
}

#[test]
fn empty_and_failed_restores_do_not_issue_cleanup_authority() {
    let root = TestDirectory::new();
    let mut registry = ImportRestorations::default();
    for input in [HashMap::new(), assets(&[("assets/empty", b"")])] {
        let (paths, token) = registry.restore(&root.0, input).unwrap();
        assert!(paths.is_empty());
        assert!(token.is_none());
    }
    let mut input = assets(&[("assets/a", b"a")]);
    input.insert("assets/z".to_string(), "!!!!".to_string());
    assert!(registry.restore(&root.0, input).is_err());
    assert!(registry.pending.is_empty());
    assert_eq!(
        fs::read_dir(root.0.join("assets/imported_plan_assets"))
            .unwrap()
            .count(),
        0
    );
}

#[cfg(unix)]
#[test]
fn cleanup_rejects_nested_links_without_deleting_their_targets() {
    use std::os::unix::fs::symlink;
    let root = TestDirectory::new();
    let outside = TestDirectory::new();
    fs::write(outside.0.join("keep"), b"keep").unwrap();
    let mut registry = ImportRestorations::default();
    let (_, token) = registry
        .restore(&root.0, assets(&[("assets/a", b"a")]))
        .unwrap();
    let token = token.unwrap();
    let owned = registry.pending[&token].path.clone();
    symlink(&outside.0, owned.join("link")).unwrap();
    assert!(registry.cleanup(&token).is_err());
    assert_eq!(fs::read(outside.0.join("keep")).unwrap(), b"keep");
    assert!(owned.join("assets/a").exists());
    fs::remove_file(owned.join("link")).unwrap();
    registry.cleanup(&token).unwrap();
    assert!(!owned.exists());
}

#[test]
fn cleanup_ipc_accepts_only_tokens_and_rejects_path_deletion_requests() {
    use super::super::{cleanup_import_assets, finalize_import_assets, ImportAssetsTokenRequest};
    for request in [
        r#"{"path":"/tmp/user-data"}"#,
        r#"{"restoreToken":"unknown","path":"/tmp/user-data"}"#,
    ] {
        assert!(serde_json::from_str::<ImportAssetsTokenRequest>(request).is_err());
    }
    assert!(cleanup_import_assets(ImportAssetsTokenRequest {
        restore_token: "unknown".to_string()
    })
    .is_err());
    assert!(finalize_import_assets(ImportAssetsTokenRequest {
        restore_token: "unknown".to_string()
    })
    .is_err());
}
