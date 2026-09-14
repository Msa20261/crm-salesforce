import { createElement } from "lwc";
import KpiCard from "c/kpiCard";

describe("c-kpi-card", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("affiche la valeur et le libellé fournis", () => {
    const element = createElement("c-kpi-card", { is: KpiCard });
    element.value = 12;
    element.label = "Leads ce mois";
    element.iconName = "standard:lead";
    element.colorKey = "lead";
    document.body.appendChild(element);

    const valeur = element.shadowRoot.querySelector(".kpi-valeur");
    const label = element.shadowRoot.querySelector(".kpi-label");
    expect(valeur.textContent).toBe("12");
    expect(label.textContent).toBe("Leads ce mois");
  });

  it("propage le clic natif au parent", () => {
    const element = createElement("c-kpi-card", { is: KpiCard });
    document.body.appendChild(element);

    const handler = jest.fn();
    element.addEventListener("click", handler);
    element.shadowRoot.querySelector(".kpi-card").click();

    expect(handler).toHaveBeenCalledTimes(1);
  });
});
