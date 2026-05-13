import { LightningElement, wire, track } from 'lwc';
import getAccountsAvecContrat from '@salesforce/apex/CarteClientsController.getAccountsAvecContrat';

export default class CarteClients extends LightningElement {
    @track markers = [];
    @track sansAdresse = [];

    totalClients  = 0;
    nbAvecAdresse = 0;
    nbSansAdresse = 0;

    @wire(getAccountsAvecContrat)
    wiredData({ data, error }) {
        if (data) {
            this.totalClients = data.length;

            const avecAdresse = data.filter(a => a.aAdresse);
            const sansAdresse = data.filter(a => !a.aAdresse);

            this.nbAvecAdresse = avecAdresse.length;
            this.nbSansAdresse = sansAdresse.length;

            this.markers = avecAdresse.map(a => ({
                location: {
                    Street:     a.rue       || '',
                    City:       a.ville,
                    PostalCode: a.codePostal || '',
                    Country:    a.pays       || 'France'
                },
                title:       a.nom,
                description: a.nbContrats + ' contrat(s)'
            }));

            this.sansAdresse = sansAdresse.map(a => ({
                id:         a.id,
                nom:        a.nom,
                nbContrats: a.nbContrats,
                url:        '/lightning/r/Account/' + a.id + '/view'
            }));
        }
    }

    get hasMarkers() {
        return this.markers.length > 0;
    }

    get hasSansAdresse() {
        return this.sansAdresse.length > 0;
    }
}
