import { LightningElement, api, wire } from 'lwc';
import getConsommations from '@salesforce/apex/CrmDashboardController.getConsommations';

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });

function fmt(val) { return val != null ? EUR.format(val) : '—'; }
function pct(conso, achete) {
    if (!achete || achete === 0) return 0;
    return Math.round((conso / achete) * 100);
}
function barColor(p) {
    if (p >= 100) return '#e45b5b';
    if (p >= 80)  return '#f4a623';
    return '#4bca81';
}

export default class ConsumptionTimeline extends LightningElement {
    @api recordId;

    isLoading = true;
    erreur    = false;
    _data     = [];

    @wire(getConsommations, { contractLineId: '$recordId' })
    wiredConso({ data, error }) {
        this.isLoading = false;
        if (data)  this._data = data;
        if (error) this.erreur = true;
    }

    get hasConsommations() { return this._data.length > 0; }

    get periodes() {
        return this._data.map(c => {
            const p    = pct(c.Montant_Consomme__c, c.Montant_Achete__c);
            const color = barColor(p);
            return {
                ...c,
                pct:          p,
                consoFormatee: fmt(c.Montant_Consomme__c),
                acheteFormate: fmt(c.Montant_Achete__c),
                restantFormate: fmt(c.Montant_Restant__c),
                labelPeriode:  this._labelPeriode(c.Periode_Debut__c, c.Periode_Fin__c),
                barStyle:      `width:${Math.min(p, 100)}%;background:${color}`,
                cssPct:        p >= 100 ? 'pct-label pct-red' : p >= 80 ? 'pct-label pct-orange' : 'pct-label pct-green',
                cssSource:     'source-badge ' + (c.Source__c === 'Ludwig API' ? 'source-api' : 'source-manuel')
            };
        });
    }

    _labelPeriode(debut, fin) {
        const opts = { month: 'short', year: 'numeric' };
        const d = debut ? new Date(debut).toLocaleDateString('fr-FR', opts) : '?';
        const f = fin   ? new Date(fin).toLocaleDateString('fr-FR', opts)   : '?';
        return `${d} → ${f}`;
    }

    // Totaux globaux
    get totalAchete()  { return fmt(this._data.reduce((s, c) => s + (c.Montant_Achete__c  || 0), 0)); }
    get totalConso()   { return fmt(this._data.reduce((s, c) => s + (c.Montant_Consomme__c || 0), 0)); }
    get totalRestant() { return fmt(this._data.reduce((s, c) => s + (c.Montant_Restant__c  || 0), 0)); }

    get pctGlobal() {
        const achete = this._data.reduce((s, c) => s + (c.Montant_Achete__c  || 0), 0);
        const conso  = this._data.reduce((s, c) => s + (c.Montant_Consomme__c || 0), 0);
        return pct(conso, achete);
    }

    get pctGlobalClass() {
        const p = this.pctGlobal;
        return p >= 100 ? 'kpi-val kpi-pct pct-red' : p >= 80 ? 'kpi-val kpi-pct pct-orange' : 'kpi-val kpi-pct pct-green';
    }

    get globalBarStyle() {
        const p = this.pctGlobal;
        return `width:${Math.min(p, 100)}%;background:${barColor(p)}`;
    }
}
