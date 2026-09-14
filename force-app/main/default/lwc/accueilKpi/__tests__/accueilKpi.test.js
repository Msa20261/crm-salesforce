import { createElement } from "lwc";
import AccueilKpi from "c/accueilKpi";
import getKPI from "@salesforce/apex/AccueilController.getKPI";
import { registerApexTestWireAdapter } from "@salesforce/wire-service-jest-util";

const getKPIAdapter = registerApexTestWireAdapter(getKPI);

const MOCK_KPI = {
  leads: 5,
  opportunites: 3,
  taches: 4,
  comptesRendus: 2,
  contrats: 1
};

describe("c-accueil-kpi", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("affiche les 5 cartes KPI avec les valeurs du wire", async () => {
    const element = createElement("c-accueil-kpi", { is: AccueilKpi });
    document.body.appendChild(element);

    getKPIAdapter.emit(MOCK_KPI);
    await Promise.resolve();

    const cartes = element.shadowRoot.querySelectorAll("c-kpi-card");
    expect(cartes.length).toBe(5);
    expect(cartes[0].value).toBe(5);
    expect(cartes[1].value).toBe(3);
    expect(cartes[2].value).toBe(4);
    expect(cartes[3].value).toBe(2);
    expect(cartes[4].value).toBe(1);
  });

  it("affiche un message d'erreur si le wire échoue", async () => {
    const element = createElement("c-accueil-kpi", { is: AccueilKpi });
    document.body.appendChild(element);

    getKPIAdapter.error({ message: "Erreur serveur" });
    await Promise.resolve();

    const erreur = element.shadowRoot.querySelector(".kpi-error");
    expect(erreur).not.toBeNull();
    expect(element.shadowRoot.querySelectorAll("c-kpi-card").length).toBe(0);
  });
});
