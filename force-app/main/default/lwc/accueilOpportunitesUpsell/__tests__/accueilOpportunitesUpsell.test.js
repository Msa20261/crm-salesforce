import { createElement } from "lwc";
import AccueilOpportunitesUpsell from "c/accueilOpportunitesUpsell";
import getOpportunitesUpsell from "@salesforce/apex/AccueilController.getOpportunitesUpsell";
import { registerApexTestWireAdapter } from "@salesforce/wire-service-jest-util";

const getOpportunitesUpsellAdapter = registerApexTestWireAdapter(
  getOpportunitesUpsell
);

const MOCK_OPPORTUNITES = [
  {
    id: "006002",
    nom: "Upsell Acme",
    compte: "Acme Corp",
    stage: "Negotiation",
    montant: "5000"
  }
];

describe("c-accueil-opportunites-upsell", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("affiche le message par défaut quand aucune opportunité", () => {
    const element = createElement("c-accueil-opportunites-upsell", {
      is: AccueilOpportunitesUpsell
    });
    document.body.appendChild(element);

    const vide = element.shadowRoot.querySelector(".widget-empty");
    expect(vide).not.toBeNull();
  });

  it("affiche les opportunités quand le wire retourne des données", async () => {
    const element = createElement("c-accueil-opportunites-upsell", {
      is: AccueilOpportunitesUpsell
    });
    document.body.appendChild(element);

    getOpportunitesUpsellAdapter.emit(MOCK_OPPORTUNITES);
    await Promise.resolve();

    const items = element.shadowRoot.querySelectorAll(".widget-item");
    expect(items.length).toBe(1);
  });
});
