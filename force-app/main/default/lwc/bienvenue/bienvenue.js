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

    get salutation() {
        const h = new Date().getHours();
        if (h < 12) return '☀️ Bonjour,';
        if (h < 18) return '💼 Bon après-midi,';
        return '🌙 Bonsoir,';
    }

    get messageDuJour() {
        const messages = [
            'Prêt à conquérir de nouveaux clients aujourd\'hui ? Votre pipeline vous attend ! 🚀',
            'Chaque lead est une opportunité. Chaque opportunité est une victoire en devenir. 🏆',
            'Les meilleurs deals se font avec méthode et persévérance — vous avez les deux. 💪',
            'Votre journée commence ici. Transformez vos prospects en partenaires. ✨',
            'Un nouveau jour, de nouvelles opportunités. Le pipeline ne dort jamais ! ⚡',
            'Focus, ambition, résultats — c\'est votre journée idéale sur Upmind Ludwig. 🎯',
            'Terminez la semaine en beauté, vos objectifs sont à portée de main. 🌟'
        ];
        return messages[new Date().getDay()];
    }

    get citationDuJour() {
        const citations = [
            'Le succès, c\'est tomber sept fois et se relever huit. — Proverbe japonais',
            'La vente commence quand le client dit non. — Elmer Wheeler',
            'Votre réseau est votre valeur nette. — Porter Gale',
            'Chaque non vous rapproche d\'un oui. — Babe Ruth',
            'L\'enthousiasme est la base de tout progrès. — Henry Ford',
            'La différence entre possible et impossible dépend de votre volonté. — Tommy Lasorda',
            'Les opportunités ne se trouvent pas, elles se créent. — Chris Grosser'
        ];
        return citations[new Date().getDay()];
    }

    naviguerLeads() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Lead', actionName: 'list' },
            state: { filterName: 'AllOpenLeads' }
        });
    }
    naviguerOpportunites() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Opportunity', actionName: 'list' },
            state: { filterName: 'Default_Opportunity_Pipeline' }
        });
    }
    naviguerTaches() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Task', actionName: 'list' },
            state: { filterName: 'OpenTasks' }
        });
    }
    naviguerComptesRendus() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Compte_Rendu_RDV__c', actionName: 'list' },
            state: { filterName: 'Nouveaux_Comptes_Rendus' }
        });
    }

    naviguerTache(event) {
        const taskId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: taskId, actionName: 'view' }
        });
    }
}
