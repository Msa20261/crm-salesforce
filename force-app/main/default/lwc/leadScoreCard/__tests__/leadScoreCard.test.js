import { createElement } from "lwc";
import LeadScoreCard from "c/leadScoreCard";
import { getRecord } from "lightning/uiRecordApi";
import { registerLdsTestWireAdapter } from "@salesforce/wire-service-jest-util";

const getRecordAdapter = registerLdsTestWireAdapter(getRecord);

function mockLead(score) {
  return {
    fields: {
      Score__c: { value: score }
    }
  };
}

describe("c-lead-score-card", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("affiche un score élevé en vert", async () => {
    const element = createElement("c-lead-score-card", {
      is: LeadScoreCard
    });
    element.recordId = "00Qxx0000000001";
    document.body.appendChild(element);

    getRecordAdapter.emit(mockLead(85));
    await Promise.resolve();

    const cercle = element.shadowRoot.querySelector(".score-circle");
    expect(cercle.dataset.niveau).toBe("eleve");
    expect(cercle.textContent).toBe("85");
  });

  it("affiche un score faible en rouge", async () => {
    const element = createElement("c-lead-score-card", {
      is: LeadScoreCard
    });
    element.recordId = "00Qxx0000000002";
    document.body.appendChild(element);

    getRecordAdapter.emit(mockLead(15));
    await Promise.resolve();

    const cercle = element.shadowRoot.querySelector(".score-circle");
    expect(cercle.dataset.niveau).toBe("faible");
  });

  it("affiche un message quand le score est indisponible (lead exclu du scoring)", async () => {
    const element = createElement("c-lead-score-card", {
      is: LeadScoreCard
    });
    element.recordId = "00Qxx0000000003";
    document.body.appendChild(element);

    getRecordAdapter.emit(mockLead(null));
    await Promise.resolve();

    const vide = element.shadowRoot.querySelector(".score-empty");
    expect(vide).not.toBeNull();
  });

  it("affiche un message d'erreur si le wire échoue", async () => {
    const element = createElement("c-lead-score-card", {
      is: LeadScoreCard
    });
    element.recordId = "00Qxx0000000004";
    document.body.appendChild(element);

    getRecordAdapter.error({ message: "Erreur serveur" });
    await Promise.resolve();

    const erreur = element.shadowRoot.querySelector(".score-error");
    expect(erreur).not.toBeNull();
  });
});
