import { createElement } from "lwc";
import AccueilAlertes from "c/accueilAlertes";
import getMesAlertes from "@salesforce/apex/AccueilController.getMesAlertes";
import { registerApexTestWireAdapter } from "@salesforce/wire-service-jest-util";

const getMesAlertesAdapter = registerApexTestWireAdapter(getMesAlertes);

const MOCK_ALERTES = [
  {
    id: "a01",
    type: "Surfacturation",
    message: "Surfacturation détectée",
    date: "2026-09-01",
    compte: "Acme Corp"
  }
];

describe("c-accueil-alertes", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("indique au widget-card qu'il n'y a aucune alerte", () => {
    const element = createElement("c-accueil-alertes", {
      is: AccueilAlertes
    });
    document.body.appendChild(element);

    const carte = element.shadowRoot.querySelector("c-widget-card");
    expect(carte.vide).toBe(true);
    expect(carte.erreur).toBe(false);
  });

  it("affiche les alertes quand le wire retourne des données", async () => {
    const element = createElement("c-accueil-alertes", {
      is: AccueilAlertes
    });
    document.body.appendChild(element);

    getMesAlertesAdapter.emit(MOCK_ALERTES);
    await Promise.resolve();

    const carte = element.shadowRoot.querySelector("c-widget-card");
    const items = element.shadowRoot.querySelectorAll("c-widget-item");
    expect(carte.vide).toBe(false);
    expect(items.length).toBe(1);
    expect(items[0].title).toBe("Acme Corp");
    expect(items[0].meta).toBe("Surfacturation détectée");
    expect(items[0].badge).toBe("Surfacturation");
  });

  it("indique au widget-card une erreur si le wire échoue", async () => {
    const element = createElement("c-accueil-alertes", {
      is: AccueilAlertes
    });
    document.body.appendChild(element);

    getMesAlertesAdapter.error({ message: "Erreur serveur" });
    await Promise.resolve();

    const carte = element.shadowRoot.querySelector("c-widget-card");
    expect(carte.erreur).toBe(true);
  });
});
