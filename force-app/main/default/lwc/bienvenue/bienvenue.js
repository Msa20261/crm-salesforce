import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import userId from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/User.Name';
import getKPI from '@salesforce/apex/AccueilController.getKPI';
import getActiviteRecente from '@salesforce/apex/AccueilController.getActiviteRecente';
import getTachesJour from '@salesforce/apex/AccueilController.getTachesJour';

export default class Bienvenue extends NavigationMixin(LightningElement) {
    userId = userId;
    kpi = { leads: 0, opportunites: 0, contrats: 0, taches: 0 };
    activites = [];
    taches = [];

    @wire(getRecord, { recordId: '$userId', fields: [NAME_FIELD] })
    utilisateur;

    @wire(getKPI)
    wiredKpi({ data }) {
        if (data) this.kpi = data;
    }

    @wire(getActiviteRecente)
    wiredActivites({ data }) {
        if (data) this.activites = data;
    }

    @wire(getTachesJour)
    wiredTaches({ data }) {
        if (data) this.taches = data;
    }

    get nomUtilisateur() {
        return this.utilisateur?.data?.fields?.Name?.value ?? 'Utilisateur';
    }

    get dateAujourdhui() {
        return new Date().toLocaleDateString('fr-FR', {
            weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
        });
    }

    naviguerLeads() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Lead', actionName: 'list' } });
    }
    naviguerOpportunites() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Opportunity', actionName: 'list' } });
    }
    naviguerComptes() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Account', actionName: 'list' } });
    }
    naviguerContrats() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Contract', actionName: 'list' } });
    }
    naviguerRapports() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Report', actionName: 'list' } });
    }
    naviguerKPI() {
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: 'Dashboard', actionName: 'list' } });
    }
}
