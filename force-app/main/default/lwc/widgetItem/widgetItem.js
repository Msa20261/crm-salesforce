import { LightningElement, api } from "lwc";

export default class WidgetItem extends LightningElement {
  @api title = "";
  @api meta = "";
  @api badge = "";
  @api trailing = "";
}
