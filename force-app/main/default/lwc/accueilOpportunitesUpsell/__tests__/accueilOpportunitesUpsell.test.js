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

  it("indique au widget-card qu'il n'y a aucune opportunité", () => {
    const element = createElement("c-accueil-opportunites-upsell", {
      is: AccueilOpportunitesUpsell
    });
    document.body.appendChild(element);

    const carte = element.shadowRoot.querySelector("c-widget-card");
    expect(carte.vide).toBe(true);
    expect(carte.erreur).toBe(false);
  });

  it("affiche les opportunités quand le wire retourne des données", async () => {
    const element = createElement("c-accueil-opportunites-upsell", {
      is: AccueilOpportunitesUpsell
    });
    document.body.appendChild(element);

    getOpportunitesUpsellAdapter.emit(MOCK_OPPORTUNITES);
    await Promise.resolve();

    const carte = element.shadowRoot.querySelector("c-widget-card");
    const items = element.shadowRoot.querySelectorAll("c-widget-item");
    expect(carte.vide).toBe(false);
    expect(items.length).toBe(1);
    expect(items[0].title).toBe("Upsell Acme");
    expect(items[0].meta).toBe("Acme Corp · Negotiation");
    expect(items[0].trailing).toBe("5000 €");
  });

  it("indique au widget-card une erreur si le wire échoue", async () => {
    const element = createElement("c-accueil-opportunites-upsell", {
      is: AccueilOpportunitesUpsell
    });
    document.body.appendChild(element);

    getOpportunitesUpsellAdapter.error({ message: "Erreur serveur" });
    await Promise.resolve();

    const carte = element.shadowRoot.querySelector("c-widget-card");
    expect(carte.erreur).toBe(true);
  });
});
