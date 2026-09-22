// GLib reads these in priority order. C/POSIX describe a process locale, not a
// BCP-47 language; WebKitGTK can expose C.UTF-8 as an invalid navigator tag.
#[cfg(target_os = "linux")]
pub fn prepare() {
    let values = ["LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"].map(|key| std::env::var(key).ok());
    if let Some(language) = language_override(&values) {
        // Called first in main, before GTK/WebKit or any worker threads start.
        std::env::set_var("LANGUAGE", language);
    }
}

fn language_override(values: &[Option<String>]) -> Option<String> {
    let selected = values
        .iter()
        .flatten()
        .find(|value| !value.trim().is_empty());
    let Some(selected) = selected else {
        return Some("en_US:en".to_string());
    };
    let languages: Vec<_> = selected
        .split(':')
        .filter(|value| {
            let base = value.trim().split(['.', '@']).next().unwrap_or("");
            !base.is_empty()
                && !base.eq_ignore_ascii_case("C")
                && !base.eq_ignore_ascii_case("POSIX")
        })
        .collect();
    if languages.len() == selected.split(':').count() {
        return None;
    }
    Some(if languages.is_empty() {
        "en_US:en".to_string()
    } else {
        languages.join(":")
    })
}

#[cfg(test)]
mod tests {
    use super::language_override;

    #[test]
    fn c_and_posix_locales_receive_a_valid_preferred_language() {
        for locale in ["C", "C.UTF-8", "C.utf8", "POSIX", "POSIX.UTF-8", ""] {
            assert_eq!(
                language_override(&[None, Some(locale.into())]),
                Some("en_US:en".into())
            );
        }
        assert_eq!(language_override(&[None, None]), Some("en_US:en".into()));
    }

    #[test]
    fn normal_languages_and_priority_are_preserved() {
        for locale in [
            "zh_CN.UTF-8",
            "ja_JP.UTF-8",
            "de_DE@euro",
            "fr:en_US",
            "en-US",
        ] {
            assert_eq!(
                language_override(&[Some(locale.into()), Some("C.UTF-8".into())]),
                None
            );
        }
        assert_eq!(
            language_override(&[
                Some("".into()),
                Some("ja_JP.UTF-8".into()),
                Some("C".into())
            ]),
            None
        );
        assert_eq!(
            language_override(&[Some("C.UTF-8".into()), Some("ja_JP.UTF-8".into())]),
            Some("en_US:en".into())
        );
    }

    #[test]
    fn mixed_list_keeps_valid_user_preferences_in_order() {
        assert_eq!(
            language_override(&[Some("ja_JP:C.UTF-8:en_US:POSIX".into())]),
            Some("ja_JP:en_US".into())
        );
    }
}
