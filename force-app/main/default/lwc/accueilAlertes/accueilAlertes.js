import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getMesAlertes from "@salesforce/apex/AccueilController.getMesAlertes";

export default class AccueilAlertes extends NavigationMixin(LightningElement) {
  alertes = [];

  @wire(getMesAlertes)
  wiredAlertes({ data }) {
    if (data) this.alertes = data;
  }

  naviguerAlerte(event) {
    const recordId = event.currentTarget.dataset.id;
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: { recordId, actionName: "view" }
    });
  }
}
