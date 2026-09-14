import { LightningElement, api } from "lwc";

export default class KpiCard extends LightningElement {
  @api value = 0;
  @api label = "";
  @api iconName = "standard:metrics";
  @api colorKey = "opp";

  get ariaLabel() {
    return `${this.label} : ${this.value}`;
  }

  handleKeyDown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      event.currentTarget.click();
    }
  }
}
