import { LightningElement, api } from "lwc";

export default class WidgetCard extends LightningElement {
  @api title = "";
  @api iconName = "standard:metrics";
  @api erreur = false;
  @api erreurMessage = "Impossible de charger les données.";
  @api vide = false;
  @api videMessage = "Aucune donnée.";
}
