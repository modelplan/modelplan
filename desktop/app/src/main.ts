import { isTauri } from "./platform.ts";
import { devPlatform } from "./platform-dev.ts";
import { tauriPlatform } from "./platform-tauri.ts";
import { startApp } from "./app.ts";

const root = document.getElementById("app");
if (root)
  startApp(
    root,
    isTauri() ? tauriPlatform() : devPlatform(),
    __MP_BRANDING__.logo,
    __MP_BRANDING__.name,
  );
