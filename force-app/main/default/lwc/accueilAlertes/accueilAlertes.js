import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getMesAlertes from "@salesforce/apex/AccueilController.getMesAlertes";

export default class AccueilAlertes extends NavigationMixin(LightningElement) {
  alertes = [];
  erreur = false;

  @wire(getMesAlertes)
  wiredAlertes({ data, error }) {
    if (data) {
      this.alertes = data;
      this.erreur = false;
    } else if (error) {
      this.erreur = true;
      // eslint-disable-next-line no-console
      console.error("Erreur AccueilController.getMesAlertes", error);
    }
  }

  get estVide() {
    return this.alertes.length === 0;
  }

  naviguerAlerte(event) {
    const recordId = event.currentTarget.dataset.id;
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: { recordId, actionName: "view" }
    });
  }
}
