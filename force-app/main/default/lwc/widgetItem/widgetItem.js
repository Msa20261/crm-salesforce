import { LightningElement, api } from "lwc";

export default class WidgetItem extends LightningElement {
  @api title = "";
  @api meta = "";
  @api badge = "";
  @api trailing = "";

  get ariaLabel() {
    return `${this.title} - ${this.meta}`;
  }

  handleKeyDown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      event.currentTarget.click();
    }
  }
}
