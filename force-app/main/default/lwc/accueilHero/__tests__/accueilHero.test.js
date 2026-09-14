import { createElement } from "lwc";
import AccueilHero from "c/accueilHero";

describe("c-accueil-hero", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("utilise 'Utilisateur' comme nom de fallback si getRecord ne retourne pas de données", () => {
    const element = createElement("c-accueil-hero", { is: AccueilHero });
    document.body.appendChild(element);

    const titre = element.shadowRoot.querySelector(".nom-utilisateur");
    expect(titre.textContent).toBe("Utilisateur");
  });

  it("dateAujourdhui retourne une chaîne non vide", () => {
    const element = createElement("c-accueil-hero", { is: AccueilHero });
    document.body.appendChild(element);

    const badge = element.shadowRoot.querySelector(".date-badge span");
    expect(badge.textContent.length).toBeGreaterThan(0);
  });
});
