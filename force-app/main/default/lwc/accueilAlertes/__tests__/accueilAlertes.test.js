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

  it("affiche le message par défaut quand aucune alerte", () => {
    const element = createElement("c-accueil-alertes", {
      is: AccueilAlertes
    });
    document.body.appendChild(element);

    const vide = element.shadowRoot.querySelector(".widget-empty");
    expect(vide).not.toBeNull();
  });

  it("affiche les alertes quand le wire retourne des données", async () => {
    const element = createElement("c-accueil-alertes", {
      is: AccueilAlertes
    });
    document.body.appendChild(element);

    getMesAlertesAdapter.emit(MOCK_ALERTES);
    await Promise.resolve();

    const items = element.shadowRoot.querySelectorAll(".widget-item");
    expect(items.length).toBe(1);
  });

  it("affiche un message d'erreur si le wire échoue", async () => {
    const element = createElement("c-accueil-alertes", {
      is: AccueilAlertes
    });
    document.body.appendChild(element);

    getMesAlertesAdapter.error({ message: "Erreur serveur" });
    await Promise.resolve();

    const erreur = element.shadowRoot.querySelector(".widget-error");
    expect(erreur).not.toBeNull();
  });
});
