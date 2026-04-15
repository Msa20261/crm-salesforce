import { LightningElement, api, wire } from 'lwc';
import getContractSummary from '@salesforce/apex/CrmDashboardController.getContractSummary';

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
function fmt(val) { return val != null ? EUR.format(val) : '—'; }
function fmtDate(d) {
    return d ? new Date(d).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';
}
function barColor(p) {
    if (p >= 100) return '#e45b5b';
    if (p >= 80)  return '#f4a623';
    return '#4bca81';
}

export default class ContractSummaryPanel extends LightningElement {
    @api recordId;

    isLoading = true;
    _summary  = null;

    @wire(getContractSummary, { contractId: '$recordId' })
    wiredSummary({ data, error }) {
        this.isLoading = false;
        if (data && Object.keys(data).length > 0) this._summary = data;
    }

    get hasData() { return !!this._summary; }

    get contrat()        { return this._summary?.contrat || {}; }
    get contractNumber() { return this.contrat.ContractNumber || ''; }
    get contractStatus() { return this.contrat.Status || ''; }

    get statusClass() {
        const s = (this.contrat.Status || '').toLowerCase();
        if (s === 'activated') return 'status-badge status-active';
        if (s === 'draft')     return 'status-badge status-draft';
        return 'status-badge status-other';
    }

    get nbLignes()  { return this._summary?.nbLignes  ?? 0; }
    get nbAlertes() { return this._summary?.nbAlertes ?? 0; }
    get nbFactures(){ return this._summary?.nbFactures ?? 0; }
    get hasAlertes(){ return this.nbAlertes > 0; }

    get totalConsoFmt()  { return fmt(this._summary?.totalConso);  }
    get totalAcheteFmt() { return fmt(this._summary?.totalAchete); }
    get montantFactures(){ return fmt(this._summary?.montantFactures); }

    get montantAbonnement() { return fmt(this.contrat.Montant_Abonnement__c); }
    get montantToken()      { return fmt(this.contrat.Montant_Token_Estime__c); }
    get fraisGestion()      { return fmt(this.contrat.Frais_Gestion__c); }
    get typeFacturation()   { return this.contrat.Type_Facturation__c || '—'; }

    get hasTokenDates() {
        return !!(this.contrat.Date_Debut_Token__c || this.contrat.Date_Fin_Token__c);
    }
    get periodeToken() {
        return fmtDate(this.contrat.Date_Debut_Token__c) + ' → ' + fmtDate(this.contrat.Date_Fin_Token__c);
    }

    get pctConso() {
        const achete = this._summary?.totalAchete || 0;
        const conso  = this._summary?.totalConso  || 0;
        if (!achete) return 0;
        return Math.round((conso / achete) * 100);
    }

    get pctClass() {
        const p = this.pctConso;
        return p >= 100 ? 'pct-val pct-red' : p >= 80 ? 'pct-val pct-orange' : 'pct-val pct-green';
    }

    get consoBarStyle() {
        const p = this.pctConso;
        return `width:${Math.min(p, 100)}%;background:${barColor(p)}`;
    }
}
