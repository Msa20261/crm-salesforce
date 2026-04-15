import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAlertes from '@salesforce/apex/CrmDashboardController.getAlertes';
import updateStatutAlerte from '@salesforce/apex/CrmDashboardController.updateStatutAlerte';

const TYPE_COLORS = {
    'Surfacturation':        'type-red',
    'Provision_Depassee':    'type-orange',
    'Consommation_Anormale': 'type-purple'
};
const TYPE_LABELS = {
    'Surfacturation':        'Surfacturation',
    'Provision_Depassee':    'Provision dépassée',
    'Consommation_Anormale': 'Conso. anormale'
};

export default class AlertDashboard extends LightningElement {
    @api recordId;

    @track filtre = 'tous';
    isLoading = false;
    erreur    = false;
    _wiredResult;

    @wire(getAlertes, { contractLineId: '$recordId' })
    wiredAlertes(result) {
        this._wiredResult = result;
        this.isLoading = false;
        if (result.error) { this.erreur = true; }
    }

    get alertes() {
        if (!this._wiredResult?.data) return [];
        return this._wiredResult.data.map(a => ({
            ...a,
            cssCard:     'alert-card statut-' + (a.Statut__c || '').toLowerCase().replace('é','e').replace('è','e'),
            cssType:     'tag-type ' + (TYPE_COLORS[a.Type_Alerte__c] || 'type-gray'),
            cssStatut:   'tag-statut statut-tag-' + (a.Statut__c || '').toLowerCase().replace('é','e').replace('è','e'),
            dateFormatee: a.Date_Alerte__c
                ? new Date(a.Date_Alerte__c).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' })
                : '',
            seuilStyle:  'width:' + Math.min(a.Seuil_Depasse__c || 0, 100) + '%;background:' + this._seuilColor(a.Seuil_Depasse__c),
            isNouvelle:  a.Statut__c === 'Nouvelle',
            isVue:       a.Statut__c === 'Vue',
            typeLabel:   TYPE_LABELS[a.Type_Alerte__c] || a.Type_Alerte__c
        }));
    }

    get hasAlertes() { return this.alertes.length > 0; }

    get alertesFiltrees() {
        if (this.filtre === 'tous') return this.alertes;
        const map = { nouvelle: 'Nouvelle', vue: 'Vue', resolue: 'Résolue' };
        return this.alertes.filter(a => a.Statut__c === map[this.filtre]);
    }

    _seuilColor(pct) {
        if (!pct) return '#4bca81';
        if (pct >= 100) return '#e45b5b';
        if (pct >= 80)  return '#f4a623';
        return '#4bca81';
    }

    // Filtres
    filtrerTous()     { this.filtre = 'tous'; }
    filtrerNouvelle() { this.filtre = 'nouvelle'; }
    filtrerVue()      { this.filtre = 'vue'; }
    filtrerResolue()  { this.filtre = 'resolue'; }

    get btnTousClass()     { return 'filter-btn' + (this.filtre === 'tous'     ? ' active' : ''); }
    get btnNouvelleClass() { return 'filter-btn' + (this.filtre === 'nouvelle' ? ' active' : ''); }
    get btnVueClass()      { return 'filter-btn' + (this.filtre === 'vue'      ? ' active' : ''); }
    get btnResolueClass()  { return 'filter-btn' + (this.filtre === 'resolue'  ? ' active' : ''); }

    // Actions
    marquerVue(evt) { this._updateStatut(evt.currentTarget.dataset.id, 'Vue'); }
    resoudre(evt)   { this._updateStatut(evt.currentTarget.dataset.id, 'Résolue'); }

    _updateStatut(id, statut) {
        this.isLoading = true;
        updateStatutAlerte({ alerteId: id, statut })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Succès',
                    message: 'Alerte mise à jour : ' + statut,
                    variant: 'success'
                }));
                return refreshApex(this._wiredResult);
            })
            .catch(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Erreur',
                    message: 'Impossible de mettre à jour l\'alerte.',
                    variant: 'error'
                }));
            })
            .finally(() => { this.isLoading = false; });
    }
}
