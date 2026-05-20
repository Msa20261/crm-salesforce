import { LightningElement, wire, track } from 'lwc';
import getAccountsAvecContrat from '@salesforce/apex/CarteClientsController.getAccountsAvecContrat';

export default class CarteClients extends LightningElement {
    @track markers = [];
    @track sansAdresse = [];
    @track erreur = null;
    isLoading = true;

    totalClients  = 0;
    nbAvecAdresse = 0;
    nbSansAdresse = 0;

    @wire(getAccountsAvecContrat)
    wiredData({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.erreur = null;
            this.totalClients = data.length;

            const avecAdresse = data.filter(a => a.aAdresse);
            const sansAdresse = data.filter(a => !a.aAdresse);

            this.nbAvecAdresse = avecAdresse.length;
            this.nbSansAdresse = sansAdresse.length;

            this.markers = avecAdresse.map(a => {
                const location = (a.latitude && a.longitude)
                    ? { Latitude: a.latitude, Longitude: a.longitude }
                    : { Street: a.rue || '', City: a.ville, PostalCode: a.codePostal || '', Country: a.pays || 'France' };
                return {
                    location,
                    title:       a.nom,
                    description: a.nbContrats + ' contrat(s)'
                };
            });

            this.sansAdresse = sansAdresse.map(a => ({
                id:         a.id,
                nom:        a.nom,
                nbContrats: a.nbContrats,
                url:        '/lightning/r/Account/' + a.id + '/view'
            }));
        } else if (error) {
            this.erreur = (error.body && error.body.message) ? error.body.message : 'Erreur lors du chargement de la carte.';
        }
    }

    get hasMarkers() {
        return this.markers.length > 0;
    }

    get hasSansAdresse() {
        return this.sansAdresse.length > 0;
    }
}
