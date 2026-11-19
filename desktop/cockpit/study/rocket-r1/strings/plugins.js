// SPDX-License-Identifier: MIT
// Cockpit plugin columns (D293, CKP-PLG-50…54): the framework's words and the bundled plugins' words.
// Every drawn string has a long form and a short form (<key>Short); the page takes the short one when the long one
// does not fit its box (prototype-engine fit()). An entry is [budgetClass, zh-CN, en].
import {register} from '../i18n.js';

register('plugin', {
  // The key and the big screen.
  keyAria: ['aria', '{name} · 插件 · 点开大屏，右键更多', '{name} · plugin · click for its screen, right-click for more'],
  menuAria: ['aria', '{name} 插件菜单', '{name} plugin menu'],
  remove: ['line', '从驾驶舱移除', 'Remove from the cockpit'],
  removeShort: ['silk', '移除', 'Remove'],
  screenAria: ['aria', '{name} 插件大屏', '{name} plugin screen'],
  close: ['silk', '关闭', 'Close'],
  closeShort: ['silk', '关', 'Close'],
  // The empty-slot "+" menu.
  addMenu: ['aria', '添加到引擎表', 'Add to the engine table'],
  connect: ['line', '连接一个订阅', 'Connect a subscription'],
  connectShort: ['lcd', '连接订阅', 'Connect'],
  detected: ['lcd', '已检测到', 'Detected'],
  detectedShort: ['lcd', '检测到', 'Found'],
  notConnected: ['line', '未连接', 'Not connected'],
  notConnectedShort: ['lcd', '未连', 'Off'],
  connectGo: ['silk', '连接', 'Connect'],
  allSubscriptions: ['line', '全部订阅…', 'All subscriptions…'],
  allSubscriptionsShort: ['lcd', '全部…', 'All…'],
  addPlugin: ['line', '添加一个插件', 'Add a plugin'],
  addPluginShort: ['lcd', '添加插件', 'Add plugin'],
  addGo: ['silk', '添加', 'Add'],
  added: ['lcd', '✓ 已添加', '✓ Added'],
  addedShort: ['lcd', '✓', '✓'],
  // The framework placeholder plugin (off by default).
  placeholderTitle: ['lcd', '占位插件', 'Placeholder'],
  placeholderTitleShort: ['silk', '占位', 'Holder'],
  placeholderSummary: ['text', '显示应用推来的最后一个数，用来试插件框架。', 'Shows the last number the app sent; for trying plugins.'],
  placeholderTag: ['lcd', '最近读数', 'Last value'],
  placeholderTagShort: ['lcd', '读数', 'Value'],
  placeholderEvery: ['lcd', '每 {n} 秒', 'every {n} s'],
  placeholderEveryShort: ['lcd', '{n}秒', '{n}s'],
  placeholderFoot: ['lcd', '插件框架', 'Framework'],
  placeholderFootShort: ['lcd', '框架', 'Frame'],
  placeholderScreenValue: ['line', '最近读数', 'Last value'],
  placeholderScreenEvery: ['line', '更新间隔', 'Update interval'],
});
