import { createElement } from "lwc";
import WidgetItem from "c/widgetItem";

describe("c-widget-item", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("affiche le titre et le meta fournis", () => {
    const element = createElement("c-widget-item", { is: WidgetItem });
    element.title = "Acme Corp";
    element.meta = "Surfacturation détectée";
    document.body.appendChild(element);

    expect(
      element.shadowRoot.querySelector(".widget-item-titre").textContent
    ).toBe("Acme Corp");
    expect(
      element.shadowRoot.querySelector(".widget-item-meta").textContent
    ).toBe("Surfacturation détectée");
  });

  it("affiche le badge quand fourni, sinon rien", () => {
    const withBadge = createElement("c-widget-item", { is: WidgetItem });
    withBadge.badge = "Surfacturation";
    document.body.appendChild(withBadge);
    expect(
      withBadge.shadowRoot.querySelector(".widget-badge").textContent
    ).toBe("Surfacturation");

    const sansBadge = createElement("c-widget-item", { is: WidgetItem });
    document.body.appendChild(sansBadge);
    expect(sansBadge.shadowRoot.querySelector(".widget-badge")).toBeNull();
  });

  it("affiche le montant à droite quand fourni, sinon la flèche", () => {
    const avecMontant = createElement("c-widget-item", { is: WidgetItem });
    avecMontant.trailing = "5000 €";
    document.body.appendChild(avecMontant);
    expect(
      avecMontant.shadowRoot.querySelector(".widget-item-montant").textContent
    ).toBe("5000 €");
    expect(
      avecMontant.shadowRoot.querySelector(".widget-item-arrow")
    ).toBeNull();

    const sansMontant = createElement("c-widget-item", { is: WidgetItem });
    document.body.appendChild(sansMontant);
    expect(
      sansMontant.shadowRoot.querySelector(".widget-item-montant")
    ).toBeNull();
    expect(
      sansMontant.shadowRoot.querySelector(".widget-item-arrow")
    ).not.toBeNull();
  });

  it("propage le clic natif au parent", () => {
    const element = createElement("c-widget-item", { is: WidgetItem });
    document.body.appendChild(element);

    const handler = jest.fn();
    element.addEventListener("click", handler);
    element.shadowRoot.querySelector(".widget-item").click();

    expect(handler).toHaveBeenCalledTimes(1);
  });

  it("est accessible au clavier (tabindex, role, aria-label)", () => {
    const element = createElement("c-widget-item", { is: WidgetItem });
    element.title = "Acme Corp";
    element.meta = "Surfacturation détectée";
    document.body.appendChild(element);

    const item = element.shadowRoot.querySelector(".widget-item");
    expect(item.getAttribute("tabindex")).toBe("0");
    expect(item.getAttribute("role")).toBe("button");
    expect(item.getAttribute("aria-label")).toBe(
      "Acme Corp - Surfacturation détectée"
    );
  });

  it("déclenche le clic sur Entrée et sur Espace", () => {
    const element = createElement("c-widget-item", { is: WidgetItem });
    document.body.appendChild(element);

    const handler = jest.fn();
    element.addEventListener("click", handler);
    const item = element.shadowRoot.querySelector(".widget-item");

    item.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }));
    item.dispatchEvent(new KeyboardEvent("keydown", { key: " " }));

    expect(handler).toHaveBeenCalledTimes(2);
  });
});
