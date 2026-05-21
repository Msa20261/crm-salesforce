import { LightningElement, wire, track } from 'lwc';
import getOpportunitiesAvecAdresse from '@salesforce/apex/OpportunityCarteController.getOpportunitiesAvecAdresse';

export default class CartographieOpportunites extends LightningElement {
    @track erreur     = null;
    @track filtreCompte = '';
    @track filtreEtape  = '';
    @track filtreAnnee  = '';

    isLoading = true;
    _allOpps  = [];

    @wire(getOpportunitiesAvecAdresse)
    wiredOpps({ data, error }) {
        if (data) {
            this._allOpps = data;
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
            this.erreur = (error.body && error.body.message) ? error.body.message : 'Erreur de chargement.';
        }
    }

    // Options filtre Compte — triées alphabétiquement
    get optionsComptes() {
        const seen = new Set();
        const opts = [{ label: 'Tous les comptes', value: '' }];
        [...this._allOpps]
            .sort((a, b) => (a.compteNom || '').localeCompare(b.compteNom || ''))
            .forEach(o => {
                if (o.compteId && !seen.has(o.compteId)) {
                    seen.add(o.compteId);
                    opts.push({ label: o.compteNom, value: o.compteId });
                }
            });
        return opts;
    }

    // Options filtre Étape — triées alphabétiquement
    get optionsEtapes() {
        const stages = [...new Set(this._allOpps.map(o => o.stageName).filter(Boolean))].sort();
        return [
            { label: 'Toutes les étapes', value: '' },
            ...stages.map(s => ({ label: s, value: s }))
        ];
    }

    // Options filtre Année — triées du plus récent au plus ancien
    get optionsAnnees() {
        const years = [...new Set(this._allOpps.map(o => o.anneeCreation).filter(Boolean))].sort((a, b) => b - a);
        return [
            { label: 'Toutes les années', value: '' },
            ...years.map(y => ({ label: String(y), value: String(y) }))
        ];
    }

    // Opportunités filtrées transmises à l'enfant
    get filteredOpps() {
        return this._allOpps.filter(o => {
            if (this.filtreCompte && o.compteId !== this.filtreCompte)         return false;
            if (this.filtreEtape  && o.stageName !== this.filtreEtape)         return false;
            if (this.filtreAnnee  && String(o.anneeCreation) !== this.filtreAnnee) return false;
            return true;
        });
    }

    get nbResultats() {
        return this.filteredOpps.length;
    }

    handleFiltreCompte(event) { this.filtreCompte = event.detail.value; }
    handleFiltreEtape(event)  { this.filtreEtape  = event.detail.value; }
    handleFiltreAnnee(event)  { this.filtreAnnee  = event.detail.value; }

    reinitialiserFiltres() {
        this.filtreCompte = '';
        this.filtreEtape  = '';
        this.filtreAnnee  = '';
    }
}
