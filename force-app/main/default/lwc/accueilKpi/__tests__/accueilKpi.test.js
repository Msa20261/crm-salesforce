import { createElement } from "lwc";
import AccueilKpi from "c/accueilKpi";
import getKPI from "@salesforce/apex/AccueilController.getKPI";
import { registerApexTestWireAdapter } from "@salesforce/wire-service-jest-util";

// Le stub par défaut de lightning/navigation devient en lecture seule dès
// qu'un composant est instancié (le moteur LWC scelle le prototype), ce qui
// empêche jest.restoreAllMocks() (appelé automatiquement en fin de fichier)
// de fonctionner avec un jest.spyOn classique. On remplace donc le module
// par un mock dédié dont le [Navigate] délègue simplement à mockNavigate.
const mockNavigate = jest.fn();
jest.mock("lightning/navigation", () => {
  const Navigate = Symbol("Navigate");
  const NavigationMixin = (Base) =>
    class extends Base {
      [Navigate](...args) {
        mockNavigate(...args);
      }
    };
  NavigationMixin.Navigate = Navigate;
  return { NavigationMixin };
});

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
    mockNavigate.mockClear();
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

  it("navigue vers la liste des leads ouverts au clic sur la carte Leads", () => {
    const element = createElement("c-accueil-kpi", { is: AccueilKpi });
    document.body.appendChild(element);

    element.shadowRoot.querySelectorAll("c-kpi-card")[0].click();

    expect(mockNavigate).toHaveBeenCalledWith({
      type: "standard__objectPage",
      attributes: { objectApiName: "Lead", actionName: "list" },
      state: { filterName: "AllOpenLeads" }
    });
  });

  it("navigue vers le pipeline d'opportunités au clic sur la carte Opportunités", () => {
    const element = createElement("c-accueil-kpi", { is: AccueilKpi });
    document.body.appendChild(element);

    element.shadowRoot.querySelectorAll("c-kpi-card")[1].click();

    expect(mockNavigate).toHaveBeenCalledWith({
      type: "standard__objectPage",
      attributes: { objectApiName: "Opportunity", actionName: "list" },
      state: { filterName: "Default_Opportunity_Pipeline" }
    });
  });

  it("navigue vers les tâches ouvertes au clic sur la carte Tâches", () => {
    const element = createElement("c-accueil-kpi", { is: AccueilKpi });
    document.body.appendChild(element);

    element.shadowRoot.querySelectorAll("c-kpi-card")[2].click();

    expect(mockNavigate).toHaveBeenCalledWith({
      type: "standard__objectPage",
      attributes: { objectApiName: "Task", actionName: "list" },
      state: { filterName: "OpenTasks" }
    });
  });

  it("navigue vers les comptes rendus RDV au clic sur la carte dédiée", () => {
    const element = createElement("c-accueil-kpi", { is: AccueilKpi });
    document.body.appendChild(element);

    element.shadowRoot.querySelectorAll("c-kpi-card")[3].click();

    expect(mockNavigate).toHaveBeenCalledWith({
      type: "standard__objectPage",
      attributes: { objectApiName: "Compte_Rendu_RDV__c", actionName: "list" },
      state: { filterName: "Nouveaux_Comptes_Rendus" }
    });
  });

  it("navigue vers les contrats activés au clic sur la carte Contrats", () => {
    const element = createElement("c-accueil-kpi", { is: AccueilKpi });
    document.body.appendChild(element);

    element.shadowRoot.querySelectorAll("c-kpi-card")[4].click();

    expect(mockNavigate).toHaveBeenCalledWith({
      type: "standard__objectPage",
      attributes: { objectApiName: "Contract", actionName: "list" },
      state: { filterName: "AllActivatedContracts" }
    });
  });
});
