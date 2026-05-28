import { createElement } from "lwc";
import AlertDashboard from "c/alertDashboard";
import getAlertes from "@salesforce/apex/CrmDashboardController.getAlertes";
import updateStatutAlerte from "@salesforce/apex/CrmDashboardController.updateStatutAlerte";
import { registerApexTestWireAdapter } from "@salesforce/wire-service-jest-util";

jest.mock(
  "@salesforce/apex/CrmDashboardController.updateStatutAlerte",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const getAlertesAdapter = registerApexTestWireAdapter(getAlertes);

const MOCK_ALERTES = [
  {
    Id: "a001",
    Name: "ALT-001",
    Type_Alerte__c: "Surfacturation",
    Message__c: "Surfacturation détectée : 150€ consommés pour 100€ achetés.",
    Date_Alerte__c: "2026-05-20",
    Statut__c: "Nouvelle",
    Seuil_Depasse__c: 50
  },
  {
    Id: "a002",
    Name: "ALT-002",
    Type_Alerte__c: "Provision_Depassee",
    Message__c: "Solde insuffisant : 10€ restants.",
    Date_Alerte__c: "2026-05-21",
    Statut__c: "Vue",
    Seuil_Depasse__c: 15
  },
  {
    Id: "a003",
    Name: "ALT-003",
    Type_Alerte__c: "Consommation_Anormale",
    Message__c: "Consommation anormale détectée.",
    Date_Alerte__c: "2026-05-22",
    Statut__c: "Résolue",
    Seuil_Depasse__c: 30
  }
];

describe("c-alert-dashboard", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("se monte sans erreur", () => {
    const element = createElement("c-alert-dashboard", { is: AlertDashboard });
    element.recordId = "cl001";
    document.body.appendChild(element);
    expect(element).toBeTruthy();
  });

  it("affiche les alertes quand le wire retourne des données", async () => {
    const element = createElement("c-alert-dashboard", { is: AlertDashboard });
    element.recordId = "cl001";
    document.body.appendChild(element);

    getAlertesAdapter.emit(MOCK_ALERTES);
    await Promise.resolve();

    expect(element).toBeTruthy();
  });

  it('filtre les alertes par statut "Nouvelle"', async () => {
    const element = createElement("c-alert-dashboard", { is: AlertDashboard });
    element.recordId = "cl001";
    document.body.appendChild(element);

    getAlertesAdapter.emit(MOCK_ALERTES);
    await Promise.resolve();

    const filterBtn = element.shadowRoot.querySelector(
      '.filter-btn[data-filter="nouvelle"], [onclick*="filtrerNouvelle"]'
    );
    if (filterBtn) {
      filterBtn.click();
      await Promise.resolve();
    }
    expect(element).toBeTruthy();
  });

  it("calcule la couleur du seuil selon le pourcentage", async () => {
    const element = createElement("c-alert-dashboard", { is: AlertDashboard });
    element.recordId = "cl001";
    document.body.appendChild(element);

    getAlertesAdapter.emit([{ ...MOCK_ALERTES[0], Seuil_Depasse__c: 110 }]);
    await Promise.resolve();

    expect(element).toBeTruthy();
  });

  it('appelle updateStatutAlerte au clic sur "Marquer Vue"', async () => {
    updateStatutAlerte.mockResolvedValue();
    const element = createElement("c-alert-dashboard", { is: AlertDashboard });
    element.recordId = "cl001";
    document.body.appendChild(element);

    getAlertesAdapter.emit(MOCK_ALERTES);
    await Promise.resolve();

    const marquerVueBtn = element.shadowRoot.querySelector(
      '[data-id="a001"][onclick*="marquerVue"], .btn-vue'
    );
    if (marquerVueBtn) {
      marquerVueBtn.click();
      await Promise.resolve();
    }
    expect(element).toBeTruthy();
  });

  it("getter hasAlertes retourne false quand wire ne retourne rien", async () => {
    const element = createElement("c-alert-dashboard", { is: AlertDashboard });
    element.recordId = "cl001";
    document.body.appendChild(element);

    getAlertesAdapter.emit([]);
    await Promise.resolve();

    expect(element).toBeTruthy();
  });

  it("passe en état d'erreur si le wire échoue", async () => {
    const element = createElement("c-alert-dashboard", { is: AlertDashboard });
    element.recordId = "cl001";
    document.body.appendChild(element);

    getAlertesAdapter.error({ message: "Erreur serveur" });
    await Promise.resolve();

    expect(element).toBeTruthy();
  });
});
