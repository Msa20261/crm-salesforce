import { LightningElement, api, wire } from "lwc";
import getConsommationTrimestrielle from "@salesforce/apex/CrmDashboardController.getConsommationTrimestrielle";

const EUR = new Intl.NumberFormat("fr-FR", {
  style: "currency",
  currency: "EUR",
  maximumFractionDigits: 0
});

function fmt(val) {
  return val != null ? EUR.format(val) : "—";
}
function pct(conso, achete) {
  if (!achete || achete === 0) return 0;
  return Math.round((conso / achete) * 100);
}
function barColor(p) {
  if (p >= 100) return "#e45b5b";
  if (p >= 80) return "#f4a623";
  return "#4bca81";
}

export default class ConsumptionQuarterlyView extends LightningElement {
  @api recordId;

  isLoading = true;
  erreur = false;
  _data = [];

  @wire(getConsommationTrimestrielle, { contractLineId: "$recordId" })
  wiredTrimestres({ data, error }) {
    this.isLoading = false;
    if (data) this._data = data;
    if (error) this.erreur = true;
  }

  get hasDonnees() {
    return this._data.some((t) => t.achete > 0 || t.consomme > 0);
  }

  get trimestres() {
    return this._data.map((t, idx) => {
      const p = pct(t.consomme, t.achete);
      const color = barColor(p);
      return {
        ...t,
        key: idx,
        label: `T-${4 - idx}`,
        periodeLabel: this._labelPeriode(t.debut, t.fin),
        pct: p,
        consoFormatee: fmt(t.consomme),
        acheteFormate: fmt(t.achete),
        restantFormate: fmt(t.restant),
        barStyle: `width:${Math.min(p, 100)}%;background:${color}`,
        cssPct:
          p >= 100
            ? "pct-label pct-red"
            : p >= 80
              ? "pct-label pct-orange"
              : "pct-label pct-green"
      };
    });
  }

  get totalAchete() {
    return fmt(this._data.reduce((s, t) => s + (t.achete || 0), 0));
  }
  get totalConso() {
    return fmt(this._data.reduce((s, t) => s + (t.consomme || 0), 0));
  }
  get totalRestant() {
    return fmt(this._data.reduce((s, t) => s + (t.restant || 0), 0));
  }

  get pctGlobal() {
    const achete = this._data.reduce((s, t) => s + (t.achete || 0), 0);
    const conso = this._data.reduce((s, t) => s + (t.consomme || 0), 0);
    return pct(conso, achete);
  }

  get pctGlobalClass() {
    const p = this.pctGlobal;
    return p >= 100
      ? "kpi-val kpi-pct pct-red"
      : p >= 80
        ? "kpi-val kpi-pct pct-orange"
        : "kpi-val kpi-pct pct-green";
  }

  _labelPeriode(debut, fin) {
    const opts = { month: "short", year: "numeric" };
    const d = debut ? new Date(debut).toLocaleDateString("fr-FR", opts) : "?";
    const f = fin ? new Date(fin).toLocaleDateString("fr-FR", opts) : "?";
    return `${d} → ${f}`;
  }
}
