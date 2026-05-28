import { LightningElement, api, wire } from "lwc";
import {
  getRecord,
  getFieldValue,
  getRecordNotifyChange
} from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import creerRdv from "@salesforce/apex/RdvController.creerRdv";
import creerCompteRendu from "@salesforce/apex/RdvController.creerCompteRendu";
import getDernierRdvLead from "@salesforce/apex/RdvController.getDernierRdvLead";
import getUsers from "@salesforce/apex/RdvController.getUsers";
import LEAD_STATUS from "@salesforce/schema/Lead.Status";
import LEAD_FIRSTNAME from "@salesforce/schema/Lead.FirstName";
import LEAD_LASTNAME from "@salesforce/schema/Lead.LastName";
import LEAD_CREATEDBYID from "@salesforce/schema/Lead.CreatedById";

const FIELDS = [LEAD_STATUS, LEAD_FIRSTNAME, LEAD_LASTNAME, LEAD_CREATEDBYID];

// Constantes module-level : pas de recalcul à chaque render
const TYPE_OPTIONS = [
  { label: "Appel téléphone", value: "Call" },
  { label: "Appel visio", value: "Email" },
  { label: "Déjeuner", value: "Meeting" },
  { label: "Email", value: "Other" }
];
const STATUT_OPTIONS = [
  { label: "Pas encore effectué", value: "Not Started" },
  { label: "En cours", value: "In Progress" },
  { label: "Attente de réponse", value: "Waiting on someone else" },
  { label: "Pas de réponse", value: "Deferred" },
  { label: "Effectué", value: "Completed" }
];
const PRIORITE_OPTIONS = [
  { label: "Élevé", value: "High" },
  { label: "Normal", value: "Normal" }
];

export default class PopupRdv extends LightningElement {
  @api recordId;

  // ── MODAL RDV ──────────────────────────────────────────────────────────────
  modalOuvert = false;
  chargement = false;
  erreur = null;

  sujet = "";
  typeRdv = "";
  dateEcheance = "";
  heureDebut = "09:00";
  heureFin = "10:00";
  assigneA = "";
  statut = "Not Started";
  priorite = "Normal";
  commentaire = "";

  // ── MODAL COMPTE RENDU ─────────────────────────────────────────────────────
  modalCROuvert = false;
  chargementCR = false;
  erreurCR = null;

  dateRdvCR = "";
  heureDebutCR = "";
  heureFinCR = "";
  typeRdvCR = "";
  titreRdvOriginal = "";
  avecQui = "";
  interetDetecte = "";
  notesRdv = "";
  prochaineAction = "";
  dateProchaineAction = "";

  // ── DONNÉES ────────────────────────────────────────────────────────────────
  users = [];

  @wire(getRecord, { recordId: "$recordId", fields: FIELDS })
  lead;

  @wire(getUsers)
  wiredUsers({ data }) {
    if (data) this.users = data.map((u) => ({ label: u.Name, value: u.Id }));
  }

  // ── GETTERS ────────────────────────────────────────────────────────────────

  get afficherBouton() {
    return getFieldValue(this.lead.data, LEAD_STATUS) === "RDV à organiser";
  }

  get afficherBoutonRdvFait() {
    return getFieldValue(this.lead.data, LEAD_STATUS) === "RDV Fait";
  }

  get nomLead() {
    if (!this.lead.data) return "";
    const p = getFieldValue(this.lead.data, LEAD_FIRSTNAME) || "";
    const n = getFieldValue(this.lead.data, LEAD_LASTNAME) || "";
    return (p + " " + n).trim();
  }

  get leadCreatedById() {
    return getFieldValue(this.lead.data, LEAD_CREATEDBYID);
  }

  get typeOptions() {
    return TYPE_OPTIONS;
  }
  get statutOptions() {
    return STATUT_OPTIONS;
  }
  get prioriteOptions() {
    return PRIORITE_OPTIONS;
  }

  // ── MODAL RDV — OUVERTURE / FERMETURE ─────────────────────────────────────

  ouvrirModal() {
    this.modalOuvert = true;
    this.erreur = null;
  }
  fermerModal() {
    this.modalOuvert = false;
    this._reinitRdv();
  }

  // ── MODAL RDV — HANDLERS ───────────────────────────────────────────────────

  handleSujet(e) {
    this.sujet = e.detail.value;
  }
  handleType(e) {
    this.typeRdv = e.detail.value;
  }
  handleDate(e) {
    this.dateEcheance = e.detail.value;
  }
  handleHeureDebut(e) {
    this.heureDebut = e.detail.value;
  }
  handleHeureFin(e) {
    this.heureFin = e.detail.value;
  }
  handleAssigne(e) {
    this.assigneA = e.detail.value;
  }
  handleStatut(e) {
    this.statut = e.detail.value;
  }
  handlePriorite(e) {
    this.priorite = e.detail.value;
  }
  handleCommentaire(e) {
    this.commentaire = e.detail.value;
  }

  async handleSubmit() {
    this.erreur = null;
    if (!this.sujet || !this.dateEcheance) {
      this.erreur = "Le sujet et la date sont obligatoires.";
      return;
    }
    this.chargement = true;
    try {
      await creerRdv({
        sujet: this.sujet,
        description: this.commentaire,
        dateEcheance: this.dateEcheance,
        heureDebut: this.heureDebut,
        heureFin: this.heureFin,
        statut: this.statut,
        priorite: this.priorite,
        typeRdv: this.typeRdv,
        assigneA: this.assigneA || null,
        leadId: this.recordId
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Rendez-vous créé !",
          message:
            "L'Event (calendrier) et la Task ont été créés. Emails envoyés.",
          variant: "success"
        })
      );
      this.fermerModal();
    } catch (e) {
      this.erreur =
        e.body?.message || "Une erreur est survenue. Veuillez réessayer.";
    } finally {
      this.chargement = false;
    }
  }

  _reinitRdv() {
    this.sujet = "";
    this.typeRdv = "";
    this.dateEcheance = "";
    this.heureDebut = "09:00";
    this.heureFin = "10:00";
    this.assigneA = "";
    this.statut = "Not Started";
    this.priorite = "Normal";
    this.commentaire = "";
    this.erreur = null;
  }

  // ── MODAL COMPTE RENDU — OUVERTURE / FERMETURE ────────────────────────────

  async ouvrirModalCR() {
    this.modalCROuvert = true;
    this.erreurCR = null;
    try {
      // Pré-remplit automatiquement depuis le dernier Event créé pour ce lead
      const rdv = await getDernierRdvLead({ leadId: this.recordId });
      if (rdv) {
        if (rdv.date) this.dateRdvCR = rdv.date;
        if (rdv.heureDebut) this.heureDebutCR = rdv.heureDebut;
        if (rdv.heureFin) this.heureFinCR = rdv.heureFin;
        if (rdv.type) this.typeRdvCR = rdv.type;
        if (rdv.sujet) this.titreRdvOriginal = rdv.sujet;
      }
    } catch {
      // Silencieux : les champs restent vides si aucun Event trouvé
    }
  }
  fermerModalCR() {
    this.modalCROuvert = false;
    this._reinitCR();
  }

  // ── MODAL COMPTE RENDU — HANDLERS ─────────────────────────────────────────

  handleDateRdvCR(e) {
    this.dateRdvCR = e.detail.value;
  }
  handleTypeRdvCR(e) {
    this.typeRdvCR = e.detail.value;
  }
  handleAvecQui(e) {
    this.avecQui = e.detail.value;
  }
  handleInteretDetecte(e) {
    this.interetDetecte = e.detail.value;
  }
  handleNotesRdv(e) {
    this.notesRdv = e.detail.value;
  }
  handleProchaineAction(e) {
    this.prochaineAction = e.detail.value;
  }
  handleDateProchaineCR(e) {
    this.dateProchaineAction = e.detail.value;
  }

  async handleSubmitCR() {
    this.erreurCR = null;
    if (!this.notesRdv) {
      this.erreurCR = "Le compte rendu est obligatoire.";
      return;
    }
    this.chargementCR = true;
    try {
      await creerCompteRendu({
        leadId: this.recordId,
        notes: this.notesRdv,
        typeRdv: this.typeRdvCR,
        avecQui: this.avecQui,
        interetDetecte: this.interetDetecte,
        prochaineAction: this.prochaineAction,
        dateProchaineAction: this.dateProchaineAction
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Compte rendu enregistré !",
          message: "La Task de compte rendu a été créée avec succès.",
          variant: "success"
        })
      );
      getRecordNotifyChange([{ recordId: this.recordId }]);
      this.fermerModalCR();
    } catch (e) {
      this.erreurCR =
        e.body?.message || "Une erreur est survenue. Veuillez réessayer.";
    } finally {
      this.chargementCR = false;
    }
  }

  _reinitCR() {
    this.dateRdvCR = "";
    this.heureDebutCR = "";
    this.heureFinCR = "";
    this.typeRdvCR = "";
    this.titreRdvOriginal = "";
    this.avecQui = "";
    this.interetDetecte = "";
    this.notesRdv = "";
    this.prochaineAction = "";
    this.dateProchaineAction = "";
    this.erreurCR = null;
  }
}
