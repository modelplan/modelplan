//! The ModelPlan menu bar app: a tray item with a short line of text, a popover with the shell's
//! UI (app/), an expandable window, and one command that asks the `modelplan` CLI for the personal
//! snapshot. The app itself reads no harness files and no credentials: the CLI does the reading,
//! exactly as in the plugins.

use std::ffi::OsString;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

use tauri::menu::{Menu, MenuItem};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::{AppHandle, Manager, RunEvent, WebviewUrl, WebviewWindowBuilder, WindowEvent};
use tauri_plugin_positioner::{Position, WindowExt};

const TRAY: &str = "main";
const POPOVER: &str = "popover";
const WINDOW: &str = "main";
const CLI_TIMEOUT: Duration = Duration::from_secs(60);
const SHELL_TIMEOUT: Duration = Duration::from_secs(4);

/// When the popover last hid because it lost focus: a click on the tray icon hides it that way
/// first, and must not show it again at once.
static HIDDEN_AT: Mutex<Option<Instant>> = Mutex::new(None);

/// The PATH a terminal would have. Apps opened from Finder get a minimal one, and the CLI looks
/// for `codex` (Codex's account reading) and CodexBar on it.
static LOGIN_PATH: OnceLock<OsString> = OnceLock::new();

/// Runs a program with a deadline, returning stdout, or an error with the last stderr line.
fn exec(cmd: &mut Command, timeout: Duration) -> Result<Vec<u8>, String> {
    let mut child = cmd
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("cli_start: {e}"))?;
    let mut out = child.stdout.take().ok_or("cli_stdout")?;
    let mut err = child.stderr.take().ok_or("cli_stderr")?;
    let reader = std::thread::spawn(move || {
        let mut b = Vec::new();
        out.read_to_end(&mut b).map(|_| b)
    });
    let errors = std::thread::spawn(move || {
        let mut s = String::new();
        let _ = err.read_to_string(&mut s);
        s
    });
    let start = Instant::now();
    let status = loop {
        if let Some(s) = child.try_wait().map_err(|e| e.to_string())? {
            break s;
        }
        if start.elapsed() > timeout {
            let _ = child.kill();
            let _ = child.wait();
            return Err("cli_timeout".into());
        }
        std::thread::sleep(Duration::from_millis(40));
    };
    let stdout = reader
        .join()
        .map_err(|_| "cli_read")?
        .map_err(|e| e.to_string())?;
    let stderr = errors.join().unwrap_or_default();
    if !status.success() {
        let last = stderr
            .lines()
            .rev()
            .find(|l| !l.trim().is_empty())
            .unwrap_or("");
        return Err(format!("cli_exit {}: {last}", status.code().unwrap_or(-1)));
    }
    Ok(stdout)
}

fn login_path() -> &'static OsString {
    LOGIN_PATH.get_or_init(|| {
        let current = std::env::var_os("PATH").unwrap_or_default();
        if !cfg!(target_os = "macos") {
            return current;
        }
        let shell = std::env::var("SHELL").unwrap_or_else(|_| "/bin/zsh".into());
        let probe = exec(
            Command::new(shell).args(["-ilc", "printf '__MP_PATH__%s__MP_PATH__' \"$PATH\""]),
            SHELL_TIMEOUT,
        );
        let found = probe.ok().and_then(|b| {
            let s = String::from_utf8_lossy(&b).into_owned();
            s.split("__MP_PATH__").nth(1).map(str::to_owned)
        });
        let mut dirs: Vec<PathBuf> = found
            .filter(|p| !p.is_empty())
            .map(|p| std::env::split_paths(&p).collect())
            .unwrap_or_else(|| std::env::split_paths(&current).collect());
        for d in ["/opt/homebrew/bin", "/usr/local/bin"] {
            if !dirs.iter().any(|x| x == Path::new(d)) {
                dirs.push(d.into());
            }
        }
        std::env::join_paths(dirs).unwrap_or(current)
    })
}

/// version orders "0.5.25" style directory names; anything else sorts first.
fn version(s: &str) -> Vec<u64> {
    s.split('.').map(|p| p.parse().unwrap_or(0)).collect()
}

/// The CLI to ask: MODELPLAN_CLI, else the one bundled next to the app's executable, else the
/// newest the plugins installed (~/.cache/modelplan-cli/<version>/), else one on the PATH.
fn cli() -> Option<PathBuf> {
    if let Some(p) = std::env::var_os("MODELPLAN_CLI").map(PathBuf::from) {
        return p.is_file().then_some(p);
    }
    if let Some(p) = std::env::current_exe()
        .ok()
        .and_then(|e| e.parent().map(|d| d.join("modelplan")))
    {
        if p.is_file() {
            return Some(p);
        }
    }
    let home = std::env::var_os("HOME").map(PathBuf::from);
    if let Some(h) = &home {
        let cache = h.join(".cache/modelplan-cli");
        let mut found: Vec<(Vec<u64>, PathBuf)> = std::fs::read_dir(&cache)
            .into_iter()
            .flatten()
            .flatten()
            .filter_map(|e| {
                let p = e.path().join("modelplan");
                p.is_file()
                    .then(|| (version(&e.file_name().to_string_lossy()), p))
            })
            .collect();
        found.sort();
        if let Some((_, p)) = found.pop() {
            return Some(p);
        }
    }
    std::env::split_paths(login_path())
        .map(|d| d.join("modelplan"))
        .find(|p| p.is_file())
}

/// The personal snapshot (docs/personal-snapshot.md), as the CLI prints it.
#[tauri::command]
async fn snapshot() -> Result<String, String> {
    tauri::async_runtime::spawn_blocking(|| -> Result<String, String> {
        let cli = cli().ok_or("cli_missing")?;
        let out = exec(
            Command::new(cli)
                .args(["desktop", "--json"])
                .env("PATH", login_path()),
            CLI_TIMEOUT,
        )?;
        String::from_utf8(out).map_err(|e| e.to_string())
    })
    .await
    .map_err(|e| e.to_string())?
}

/// The text beside the menu bar icon (macOS) and the tooltip.
#[tauri::command]
fn set_menu_bar(app: AppHandle, title: String, tooltip: String) -> Result<(), String> {
    let tray = app.tray_by_id(TRAY).ok_or("no_tray")?;
    tray.set_title(if title.is_empty() { None } else { Some(title) })
        .map_err(|e| e.to_string())?;
    tray.set_tooltip(Some(if tooltip.is_empty() {
        "ModelPlan".to_owned()
    } else {
        tooltip
    }))
    .map_err(|e| e.to_string())
}

/// Opens the full window (one at a time).
#[tauri::command]
fn expand(app: AppHandle) -> Result<(), String> {
    if let Some(p) = app.get_webview_window(POPOVER) {
        let _ = p.hide();
    }
    if let Some(w) = app.get_webview_window(WINDOW) {
        w.show().map_err(|e| e.to_string())?;
        return w.set_focus().map_err(|e| e.to_string());
    }
    WebviewWindowBuilder::new(&app, WINDOW, WebviewUrl::App("index.html".into()))
        .title("ModelPlan")
        .inner_size(760.0, 720.0)
        .min_inner_size(420.0, 480.0)
        .build()
        .map(|_| ())
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn quit(app: AppHandle) {
    app.exit(0);
}

fn toggle_popover(app: &AppHandle) {
    let Some(w) = app.get_webview_window(POPOVER) else {
        return;
    };
    if w.is_visible().unwrap_or(false) {
        let _ = w.hide();
        return;
    }
    let just_hidden = HIDDEN_AT
        .lock()
        .ok()
        .and_then(|t| *t)
        .is_some_and(|t| t.elapsed() < Duration::from_millis(250));
    if just_hidden {
        return;
    }
    let _ = w.move_window_constrained(Position::TrayBottomCenter);
    let _ = w.show();
    let _ = w.set_focus();
}

pub fn run() {
    let app = tauri::Builder::default()
        .plugin(tauri_plugin_positioner::init())
        .plugin(tauri_plugin_http::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::new().build())
        .invoke_handler(tauri::generate_handler![
            snapshot,
            set_menu_bar,
            expand,
            quit
        ])
        .setup(|app| {
            // A menu bar app: no Dock icon.
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);
            // Resolve the login PATH off the main thread before the first snapshot needs it.
            std::thread::spawn(|| {
                login_path();
            });
            let open = MenuItem::with_id(app, "open", "Open ModelPlan", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&open, &quit])?;
            TrayIconBuilder::with_id(TRAY)
                .icon(tauri::include_image!("icons/tray.png"))
                .icon_as_template(true)
                .tooltip("ModelPlan")
                .menu(&menu)
                // Left click opens the popover; the menu is on right click (and on Linux, where
                // tray clicks are not reported).
                .show_menu_on_left_click(false)
                .on_menu_event(|app, e| match e.id().as_ref() {
                    "open" => {
                        let _ = expand(app.clone());
                    }
                    "quit" => app.exit(0),
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    tauri_plugin_positioner::on_tray_event(tray.app_handle(), &event);
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        toggle_popover(tray.app_handle());
                    }
                })
                .build(app)?;
            Ok(())
        })
        .on_window_event(|window, event| {
            if window.label() == POPOVER {
                if let WindowEvent::Focused(false) = event {
                    let _ = window.hide();
                    if let Ok(mut t) = HIDDEN_AT.lock() {
                        *t = Some(Instant::now());
                    }
                }
            }
        })
        .build(tauri::generate_context!())
        .expect("error while building the ModelPlan app");
    app.run(|_, event| {
        // Closing the window keeps the menu bar item; only Quit ends the app.
        if let RunEvent::ExitRequested {
            code: None, api, ..
        } = event
        {
            api.prevent_exit();
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn versions_sort_numerically() {
        let mut v = vec![
            version("0.5.9"),
            version("0.5.25"),
            version("0.10.0"),
            version("x"),
        ];
        v.sort();
        assert_eq!(
            v,
            vec![
                version("x"),
                version("0.5.9"),
                version("0.5.25"),
                version("0.10.0")
            ]
        );
    }

    #[test]
    fn exec_returns_stdout_and_reports_failures() {
        assert_eq!(
            exec(Command::new("sh").args(["-c", "printf ok"]), CLI_TIMEOUT).unwrap(),
            b"ok"
        );
        let err = exec(
            Command::new("sh").args(["-c", "echo first >&2; echo boom >&2; exit 3"]),
            CLI_TIMEOUT,
        )
        .unwrap_err();
        assert_eq!(err, "cli_exit 3: boom");
        assert_eq!(
            exec(
                Command::new("sh").args(["-c", "sleep 5"]),
                Duration::from_millis(200)
            )
            .unwrap_err(),
            "cli_timeout"
        );
    }
}
