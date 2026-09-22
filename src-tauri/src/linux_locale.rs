#[cfg(target_os = "linux")]
pub fn configure(app: &tauri::App) -> Result<(), Box<dyn std::error::Error>> {
    use std::ffi::CStr;
    use tauri::Manager;
    use webkit2gtk::{WebContextExt, WebViewExt};

    // GTK has initialized LC_CTYPE by setup time. Query only: never change
    // the process locale used by the rest of the application.
    let locale = unsafe {
        let value = libc::setlocale(libc::LC_CTYPE, std::ptr::null());
        if value.is_null() {
            String::new()
        } else {
            CStr::from_ptr(value).to_string_lossy().into_owned()
        }
    };
    if needs_language_override(&locale) {
        let window = app
            .get_webview_window("main")
            .ok_or("main webview missing")?;
        window.with_webview(|webview| {
            if let Some(context) = webview.inner().context() {
                context.set_preferred_languages(&["en-US"]);
                crate::startup_log::write("WebKit preferred language normalized for POSIX locale");
            } else {
                crate::startup_log::write(
                    "WebKit locale normalization failed: context unavailable",
                );
            }
        })?;
    }
    Ok(())
}

fn needs_language_override(locale: &str) -> bool {
    let base = locale.trim().split(['.', '@']).next().unwrap_or("");
    base.is_empty() || base.eq_ignore_ascii_case("C") || base.eq_ignore_ascii_case("POSIX")
}

#[cfg(test)]
mod tests {
    use super::needs_language_override;

    #[test]
    fn c_and_posix_locales_receive_a_valid_preferred_language() {
        for locale in ["C", "C.UTF-8", "C.utf8", "POSIX", "POSIX.UTF-8", ""] {
            assert!(needs_language_override(locale));
        }
    }

    #[test]
    fn normal_system_locales_are_untouched() {
        for locale in [
            "zh_CN.UTF-8",
            "ja_JP.UTF-8",
            "de_DE@euro",
            "en_US.UTF-8",
            "en-US",
        ] {
            assert!(!needs_language_override(locale));
        }
    }
}
