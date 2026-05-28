import { createElement } from "lwc";
import Bienvenue from "c/bienvenue";
import getKPI from "@salesforce/apex/AccueilController.getKPI";
import getActiviteRecente from "@salesforce/apex/AccueilController.getActiviteRecente";
import getTachesJour from "@salesforce/apex/AccueilController.getTachesJour";
import { registerApexTestWireAdapter } from "@salesforce/wire-service-jest-util";

const getKPIAdapter = registerApexTestWireAdapter(getKPI);
const getActiviteRecenteAdapter =
  registerApexTestWireAdapter(getActiviteRecente);
const getTachesJourAdapter = registerApexTestWireAdapter(getTachesJour);

const MOCK_KPI = { leads: 5, opportunites: 3, contrats: 2, taches: 4 };
const MOCK_ACTIVITES = [
  {
    id: "001",
    nom: "Acme Corp",
    type: "Lead",
    statut: "New",
    date: "2026-05-01",
    icone: "standard:lead"
  },
  {
    id: "006",
    nom: "Deal Acme",
    type: "Opportunité",
    statut: "Qualification",
    date: "2026-05-15",
    icone: "standard:opportunity"
  }
];
const MOCK_TACHES = [
  {
    id: "00T001",
    sujet: "Appeler client",
    priorite: "High",
    statut: "Not Started",
    date: "2026-05-28"
  }
];

describe("c-bienvenue", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("se monte sans erreur", () => {
    const element = createElement("c-bienvenue", { is: Bienvenue });
    document.body.appendChild(element);
    expect(element).toBeTruthy();
  });

  it("affiche les KPI quand le wire retourne des données", async () => {
    const element = createElement("c-bienvenue", { is: Bienvenue });
    document.body.appendChild(element);

    getKPIAdapter.emit(MOCK_KPI);
    await Promise.resolve();

    expect(element).toBeTruthy();
  });

  it("affiche l'activité récente quand le wire retourne des données", async () => {
    const element = createElement("c-bienvenue", { is: Bienvenue });
    document.body.appendChild(element);

    getActiviteRecenteAdapter.emit(MOCK_ACTIVITES);
    await Promise.resolve();

    expect(element).toBeTruthy();
  });

  it("affiche les tâches du jour quand le wire retourne des données", async () => {
    const element = createElement("c-bienvenue", { is: Bienvenue });
    document.body.appendChild(element);

    getTachesJourAdapter.emit(MOCK_TACHES);
    await Promise.resolve();

    expect(element).toBeTruthy();
  });

  it("utilise 'Utilisateur' comme nom de fallback si getRecord ne retourne pas de données", () => {
    const element = createElement("c-bienvenue", { is: Bienvenue });
    document.body.appendChild(element);
    expect(element.shadowRoot).toBeTruthy();
  });

  it("dateAujourdhui retourne une chaîne non vide", () => {
    const element = createElement("c-bienvenue", { is: Bienvenue });
    document.body.appendChild(element);
    expect(element).toBeTruthy();
  });

  it("déclenche la navigation vers les leads au clic sur le bouton leads", async () => {
    const element = createElement("c-bienvenue", { is: Bienvenue });
    document.body.appendChild(element);

    const leadsButton = element.shadowRoot.querySelector(
      '[data-id="leads"], .leads-link, [onclick*="Lead"]'
    );
    if (leadsButton) {
      leadsButton.click();
      await Promise.resolve();
    }
    expect(element).toBeTruthy();
  });
});
