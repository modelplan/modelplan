// SPDX-License-Identifier: MIT
// The bundled cockpit plugins, in registry order (mirrored by ModelPlanSettings CockpitPluginCatalogue.builtIn).
import {placeholderPlugin,type CockpitPlugin} from './plugin-registry.js';
import {calendarPlugin} from './calendar-plugin.js';
export const builtinPlugins:readonly CockpitPlugin[]=Object.freeze([placeholderPlugin,calendarPlugin]);
