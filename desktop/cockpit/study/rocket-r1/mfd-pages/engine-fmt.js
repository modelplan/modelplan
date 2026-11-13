// SPDX-License-Identifier: MIT
// The engine-only adapter pre-escapes all display strings. Keep the original
// formatter intact for other consumers, and avoid escaping those values twice.
export {dhm,tok,when,hm,relativeMoment} from './fmt.js';
export const esc=value=>String(value??'');
