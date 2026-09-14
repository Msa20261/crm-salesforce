import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getKPI from "@salesforce/apex/AccueilController.getKPI";

export default class AccueilKpi extends NavigationMixin(LightningElement) {
  kpi = {
    leads: 0,
    opportunites: 0,
    taches: 0,
    comptesRendus: 0,
    contrats: 0
  };

  @wire(getKPI)
  wiredKpi({ data }) {
    if (data) this.kpi = data;
  }

  naviguerLeads() {
    this[NavigationMixin.Navigate]({
      type: "standard__objectPage",
      attributes: { objectApiName: "Lead", actionName: "list" },
      state: { filterName: "AllOpenLeads" }
    });
  }

  naviguerOpportunites() {
    this[NavigationMixin.Navigate]({
      type: "standard__objectPage",
      attributes: { objectApiName: "Opportunity", actionName: "list" },
      state: { filterName: "Default_Opportunity_Pipeline" }
    });
  }

  naviguerTaches() {
    this[NavigationMixin.Navigate]({
      type: "standard__objectPage",
      attributes: { objectApiName: "Task", actionName: "list" },
      state: { filterName: "OpenTasks" }
    });
  }

  naviguerComptesRendus() {
    this[NavigationMixin.Navigate]({
      type: "standard__objectPage",
      attributes: { objectApiName: "Compte_Rendu_RDV__c", actionName: "list" },
      state: { filterName: "Nouveaux_Comptes_Rendus" }
    });
  }

  naviguerContrats() {
    this[NavigationMixin.Navigate]({
      type: "standard__objectPage",
      attributes: { objectApiName: "Contract", actionName: "list" },
      state: { filterName: "AllActivatedContracts" }
    });
  }
}
