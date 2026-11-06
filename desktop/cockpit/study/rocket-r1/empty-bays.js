// Empty bays share the table LCD; keep their row boxes and add controls.
// label has already passed the host's HTML escape function.
export const emptyKey = (label) =>
  `<button type="button" class="ek ek-bay" data-add-subscription data-tip="${label}" aria-label="${label}" data-mat="part"><span class="bay-dash" aria-hidden="true">—</span></button>`;
export const emptyColumn = (model, slot, label) =>
  `<button type="button" class="ec ec-bay" data-slot="${slot}" data-add-subscription data-tip="${label}" aria-label="${label}" tabindex="-1">${model.rows.map(() => `<span class="qcell none" aria-hidden="true"></span>`).join("")}<span class="qrow" aria-hidden="true"></span>${model.reserve ? '<span class="qrow" aria-hidden="true"></span>' : ""}</button>`;
