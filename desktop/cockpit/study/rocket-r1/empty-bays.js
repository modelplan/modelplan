// Empty bays share the table LCD; keep their row boxes and add controls.
// label has already passed the host's HTML escape function.
export const emptyKey = (label) =>
  `<button type="button" class="ek ek-bay" data-add-subscription data-tip="${label}" aria-label="${label}" data-mat="part"><span class="bay-dash" aria-hidden="true">—</span></button>`;
// CKP-ENG-56 (D95, folded in from #793): at most one quiet "+ Add a subscription" per page, in the first empty bay: an
// etched plus drawn in CSS with the bay's own label small under it. The other empty bays stay plain.
const addMark = (label) => `<span class="ec-add" aria-hidden="true"><span class="ec-plus"></span><span class="ec-add-label">${label.replace(/^[＋+]\s*/, "")}</span></span>`;
export const emptyColumn = (model, slot, label, add = false) =>
  `<button type="button" class="ec ec-bay" data-slot="${slot}" data-add-subscription data-tip="${label}" aria-label="${label}" tabindex="-1">${model.rows.map(() => `<span class="qcell none" aria-hidden="true"></span>`).join("")}<span class="qrow" aria-hidden="true"></span>${model.reserve ? '<span class="qrow" aria-hidden="true"></span>' : ""}${add ? addMark(label) : ""}</button>`;
