import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import creerRdv from '@salesforce/apex/RdvController.creerRdv';
import getUsers from '@salesforce/apex/RdvController.getUsers';
import LEAD_STATUS from '@salesforce/schema/Lead.Status';
import LEAD_FIRSTNAME from '@salesforce/schema/Lead.FirstName';
import LEAD_LASTNAME from '@salesforce/schema/Lead.LastName';
import LEAD_CREATEDBYID from '@salesforce/schema/Lead.CreatedById';

const FIELDS = [LEAD_STATUS, LEAD_FIRSTNAME, LEAD_LASTNAME, LEAD_CREATEDBYID];

export default class PopupRdv extends LightningElement {
    @api recordId;

    @track modalOuvert = false;
    @track modalCROuvert = false;
    @track chargement = false;
    @track erreur = null;

    // Champs du formulaire
    @track sujet = '';
    @track typeRdv = '';
    @track dateEcheance = '';
    @track assigneA = '';
    @track statut = 'Not Started';
    @track priorite = 'Normal';
    @track commentaire = '';

    @track users = [];

    // Récupère le statut de la piste
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    lead;

    // Récupère la liste des utilisateurs actifs
    @wire(getUsers)
    wiredUsers({ data, error }) {
        if (data) {
            this.users = data.map(u => ({ label: u.Name, value: u.Id }));
        }
    }

    // Affiche le bouton uniquement si statut = "RDV à organiser"
    get afficherBouton() {
        const s = getFieldValue(this.lead.data, LEAD_STATUS);
        return s === 'RDV à organiser';
    }

    // Affiche le bouton Compte Rendu si statut = "RDV Fait"
    get afficherBoutonRdvFait() {
        const s = getFieldValue(this.lead.data, LEAD_STATUS);
        return s === 'RDV Fait';
    }

    // Id du créateur de la piste pour pré-remplir "Effectué par"
    get leadCreatedById() {
        return getFieldValue(this.lead.data, LEAD_CREATEDBYID);
    }

    // Nom complet du lead pour affichage dans le popup
    get nomLead() {
        if (!this.lead.data) return '';
        const prenom = getFieldValue(this.lead.data, LEAD_FIRSTNAME) || '';
        const nom    = getFieldValue(this.lead.data, LEAD_LASTNAME)  || '';
        return (prenom + ' ' + nom).trim();
    }

    get typeOptions() {
        return [
            { label: 'Appel téléphone', value: 'Call' },
            { label: 'Appel visio', value: 'Email' },
            { label: 'Déjeuner', value: 'Meeting' },
            { label: 'Email', value: 'Other' }
        ];
    }

    get statutOptions() {
        return [
            { label: 'Pas encore effectué', value: 'Not Started' },
            { label: 'Ouvert', value: 'Ouvert' },
            { label: 'En cours', value: 'In Progress' },
            { label: 'Attente de réponse', value: 'Waiting on someone else' },
            { label: 'Pas de réponse', value: 'Deferred' },
            { label: 'Effectué', value: 'Completed' }
        ];
    }

    get prioriteOptions() {
        return [
            { label: 'Élevé', value: 'High' },
            { label: 'Normal', value: 'Normal' }
        ];
    }

    ouvrirModal() {
        this.modalOuvert = true;
        this.erreur = null;
    }

    fermerModal() {
        this.modalOuvert = false;
        this.reinitialiser();
    }

    ouvrirModalCR() {
        this.modalCROuvert = true;
    }

    fermerModalCR() {
        this.modalCROuvert = false;
    }

    handleSuccessCR() {
        this.fermerModalCR();
        this.dispatchEvent(new ShowToastEvent({
            title: 'Compte rendu enregistré !',
            message: 'Le compte rendu du RDV a été créé avec succès.',
            variant: 'success'
        }));
        getRecordNotifyChange([{ recordId: this.recordId }]);
    }

    handleErrorCR(event) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Erreur',
            message: event.detail.detail,
            variant: 'error'
        }));
    }

    reinitialiser() {
        this.sujet = '';
        this.typeRdv = '';
        this.dateEcheance = '';
        this.assigneA = '';
        this.statut = 'Not Started';
        this.priorite = 'Normal';
        this.commentaire = '';
        this.erreur = null;
    }

    handleSujet(e)       { this.sujet = e.detail.value; }
    handleType(e)        { this.typeRdv = e.detail.value; }
    handleDate(e)        { this.dateEcheance = e.detail.value; }
    handleAssigne(e)     { this.assigneA = e.detail.value; }
    handleStatut(e)      { this.statut = e.detail.value; }
    handlePriorite(e)    { this.priorite = e.detail.value; }
    handleCommentaire(e) { this.commentaire = e.detail.value; }

    async handleSubmit() {
        this.erreur = null;

        if (!this.sujet || !this.dateEcheance) {
            this.erreur = 'Le sujet et la date d\'échéance sont obligatoires.';
            return;
        }

        this.chargement = true;
        try {
            await creerRdv({
                sujet: this.sujet,
                description: this.commentaire,
                dateEcheance: this.dateEcheance,
                statut: this.statut,
                priorite: this.priorite,
                typeRdv: this.typeRdv,
                assigneA: this.assigneA || null,
                leadId: this.recordId
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Rendez-vous créé !',
                message: 'Le RDV a été créé et les notifications envoyées.',
                variant: 'success'
            }));

            this.fermerModal();

        } catch (e) {
            this.erreur = e.body?.message || 'Une erreur est survenue. Veuillez réessayer.';
        } finally {
            this.chargement = false;
        }
    }
}
