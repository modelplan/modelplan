// SPDX-License-Identifier: MIT
// Engine-table pages with plugin columns (owner D124 layout rule, 2026-11-10):
//   columns = max(3, subscriptions + plugins), at most 6 per page, subscriptions first, plugins after them.
// With 1–2 subscriptions a plugin takes an empty slot of the 3-wide table; only when subscriptions fill the three
// slots does a plugin add a column. Subscriptions win: an unpinned plugin only fills a free slot (on the last page)
// and is otherwise not shown. A pinned plugin (at most two) always stays on page 1, which then carries fewer
// subscriptions; the rest move to later pages.
export const PER_PAGE=6;
export const MIN_COLUMNS=3;
export const MAX_PINNED_COLUMNS=2;
export interface LayoutPage {
  /** Subscriptions [from, to) in the user's order. */
  readonly from:number;readonly to:number;
  /** Plugin ids on this page, in the user's plugin order, drawn after the subscriptions. */
  readonly plugins:readonly string[];
  /** Columns drawn: subscriptions + plugins + empty "+" slots. */
  readonly slots:number;
}
export interface PluginLayout {readonly pages:readonly LayoutPage[];readonly hidden:readonly string[]}
export function pluginLayout(subscriptions:number,plugins:readonly {readonly id:string;readonly pinned:boolean}[]):PluginLayout {
  const subs=Math.max(0,Math.floor(subscriptions)||0);
  const pinnedIds=new Set(plugins.filter(p=>p.pinned).slice(0,MAX_PINNED_COLUMNS).map(p=>p.id));
  const unpinned=plugins.filter(p=>!pinnedIds.has(p.id));
  const inOrder=(chosen:Set<string>)=>plugins.filter(p=>chosen.has(p.id)).map(p=>p.id);
  if(subs+pinnedIds.size<=PER_PAGE){
    const free=PER_PAGE-subs-pinnedIds.size,chosen=new Set([...pinnedIds,...unpinned.slice(0,free).map(p=>p.id)]);
    const shown=inOrder(chosen);
    return {pages:[{from:0,to:subs,plugins:shown,slots:Math.max(MIN_COLUMNS,subs+shown.length)}],hidden:unpinned.slice(free).map(p=>p.id)};
  }
  // More than one page: every page keeps the six-column width, as the subscription-only table already does.
  const first=PER_PAGE-pinnedIds.size,pages:{from:number;to:number;plugins:string[];slots:number}[]=[{from:0,to:first,plugins:inOrder(pinnedIds),slots:PER_PAGE}];
  for(let from=first;from<subs;from+=PER_PAGE)pages.push({from,to:Math.min(subs,from+PER_PAGE),plugins:[],slots:PER_PAGE});
  const last=pages[pages.length-1],free=PER_PAGE-(last.to-last.from);
  last.plugins=inOrder(new Set(unpinned.slice(0,free).map(p=>p.id)));
  return {pages,hidden:unpinned.slice(free).map(p=>p.id)};
}
/** The page that shows subscription `index`. */
export const pageOfSubscription=(layout:PluginLayout,index:number)=>Math.max(0,layout.pages.findIndex(p=>index>=p.from&&index<p.to));
