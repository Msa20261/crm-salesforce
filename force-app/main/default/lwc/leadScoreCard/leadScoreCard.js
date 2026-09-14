import { LightningElement, api, wire } from "lwc";
import { getRecord } from "lightning/uiRecordApi";
import SCORE_FIELD from "@salesforce/schema/Lead.Score__c";

export default class LeadScoreCard extends LightningElement {
  @api recordId;
  score;
  erreur = false;

  @wire(getRecord, { recordId: "$recordId", fields: [SCORE_FIELD] })
  wiredLead({ data, error }) {
    if (data) {
      this.erreur = false;
      this.score = data.fields.Score__c.value;
    } else if (error) {
      this.erreur = true;
      // eslint-disable-next-line no-console
      console.error("Erreur chargement du score du lead", error);
    }
  }

  get scoreDisponible() {
    return this.score !== null && this.score !== undefined;
  }

  get niveau() {
    if (!this.scoreDisponible) {
      return "neutre";
    }
    if (this.score >= 70) {
      return "eleve";
    }
    if (this.score >= 40) {
      return "moyen";
    }
    return "faible";
  }

  get labelNiveau() {
    if (!this.scoreDisponible) {
      return "";
    }
    if (this.score >= 70) {
      return "Priorité haute";
    }
    if (this.score >= 40) {
      return "Priorité moyenne";
    }
    return "Priorité basse";
  }
}
