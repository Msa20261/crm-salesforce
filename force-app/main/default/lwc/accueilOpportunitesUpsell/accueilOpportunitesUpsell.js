import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getOpportunitesUpsell from "@salesforce/apex/AccueilController.getOpportunitesUpsell";

export default class AccueilOpportunitesUpsell extends NavigationMixin(
  LightningElement
) {
  opportunites = [];
  erreur = false;

  @wire(getOpportunitesUpsell)
  wiredOpportunites({ data, error }) {
    if (data) {
      this.opportunites = data;
      this.erreur = false;
    } else if (error) {
      this.erreur = true;
      // eslint-disable-next-line no-console
      console.error("Erreur AccueilController.getOpportunitesUpsell", error);
    }
  }

  get estVide() {
    return this.opportunites.length === 0;
  }

  get opportunitesAffichees() {
    return this.opportunites.map((o) => ({
      id: o.id,
      nom: o.nom,
      meta: `${o.compte} · ${o.stage}`,
      trailing: `${o.montant} €`
    }));
  }

  naviguerOpportunite(event) {
    const recordId = event.currentTarget.dataset.id;
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: { recordId, actionName: "view" }
    });
  }
}
