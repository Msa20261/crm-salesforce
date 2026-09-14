import { createElement } from "lwc";
import WidgetCard from "c/widgetCard";

describe("c-widget-card", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("affiche le titre et l'icône fournis", () => {
    const element = createElement("c-widget-card", { is: WidgetCard });
    element.title = "Mon widget";
    element.iconName = "utility:warning";
    document.body.appendChild(element);

    const titre = element.shadowRoot.querySelector(".widget-header span");
    expect(titre.textContent).toBe("Mon widget");
  });

  it("affiche le message d'erreur quand erreur est vrai", () => {
    const element = createElement("c-widget-card", { is: WidgetCard });
    element.erreur = true;
    element.erreurMessage = "Erreur de test";
    document.body.appendChild(element);

    const erreur = element.shadowRoot.querySelector(".widget-error");
    expect(erreur.textContent).toBe("Erreur de test");
  });

  it("affiche le message vide quand vide est vrai", () => {
    const element = createElement("c-widget-card", { is: WidgetCard });
    element.vide = true;
    element.videMessage = "Rien à afficher";
    document.body.appendChild(element);

    const vide = element.shadowRoot.querySelector(".widget-empty");
    expect(vide.textContent).toBe("Rien à afficher");
  });

  it("affiche la liste (slot) quand ni erreur ni vide", () => {
    const element = createElement("c-widget-card", { is: WidgetCard });
    document.body.appendChild(element);

    const liste = element.shadowRoot.querySelector(".widget-list");
    expect(liste).not.toBeNull();
  });
});
