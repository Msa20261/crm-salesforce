import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getOpportunitesUpsell from "@salesforce/apex/AccueilController.getOpportunitesUpsell";

export default class AccueilOpportunitesUpsell extends NavigationMixin(
  LightningElement
) {
  opportunites = [];

  @wire(getOpportunitesUpsell)
  wiredOpportunites({ data }) {
    if (data) this.opportunites = data;
  }

  naviguerOpportunite(event) {
    const recordId = event.currentTarget.dataset.id;
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: { recordId, actionName: "view" }
    });
  }
}
