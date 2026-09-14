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

  naviguerOpportunite(event) {
    const recordId = event.currentTarget.dataset.id;
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: { recordId, actionName: "view" }
    });
  }
}
