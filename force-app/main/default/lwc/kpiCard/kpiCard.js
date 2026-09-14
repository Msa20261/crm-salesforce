import { LightningElement, api } from "lwc";

export default class KpiCard extends LightningElement {
  @api value = 0;
  @api label = "";
  @api iconName = "standard:metrics";
  @api colorKey = "opp";
}
