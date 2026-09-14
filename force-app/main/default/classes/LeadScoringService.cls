public with sharing class LeadScoringService {
  private static final Integer POIDS_STATUT = 30;
  private static final Integer POIDS_RDV = 25;
  private static final Integer POIDS_PRIORITE = 20;
  private static final Integer POIDS_FRAICHEUR = 25;

  private static Boolean estExclu(Lead l) {
    return l.IsConverted || l.Status == 'Not Qualified';
  }

  // ===== Appelé depuis le trigger, avant insert/update =====
  public static void avantEnregistrement(
    List<Lead> nouvelles,
    Map<Id, Lead> anciennes
  ) {
    for (Lead l : nouvelles) {
      if (estExclu(l)) {
        continue;
      }

      Lead ancien = anciennes != null ? anciennes.get(l.Id) : null;
      Boolean champMetierModifie =
        ancien == null ||
        l.Status != ancien.Status ||
        l.Date_de_rendez_vous__c != ancien.Date_de_rendez_vous__c ||
        l.Priorit_de_prospection__c != ancien.Priorit_de_prospection__c;

      if (champMetierModifie) {
        l.Derniere_Maj_Metier__c = Date.today();
      } else if (l.Derniere_Maj_Metier__c == null) {
        l.Derniere_Maj_Metier__c = Date.today();
      }

      l.Score__c = calculerScore(
        l.Status,
        l.Date_de_rendez_vous__c,
        l.Priorit_de_prospection__c,
        l.Derniere_Maj_Metier__c
      );
    }
  }

  // ===== Appelé chaque nuit par LeadScoringScheduler =====
  // Ne met à jour QUE Score__c : ne doit jamais toucher Derniere_Maj_Metier__c,
  // sinon le signal de fraîcheur serait remis à zéro à chaque exécution.
  public static void recalculerLeadsOuverts() {
    List<Lead> ouverts = [
      SELECT
        Id,
        Status,
        Date_de_rendez_vous__c,
        Priorit_de_prospection__c,
        Derniere_Maj_Metier__c
      FROM Lead
      WHERE IsConverted = FALSE AND Status != 'Not Qualified'
    ];
    if (ouverts.isEmpty()) {
      return;
    }

    List<Lead> aMettreAJour = new List<Lead>();
    for (Lead l : ouverts) {
      Integer nouveauScore = calculerScore(
        l.Status,
        l.Date_de_rendez_vous__c,
        l.Priorit_de_prospection__c,
        l.Derniere_Maj_Metier__c
      );
      aMettreAJour.add(new Lead(Id = l.Id, Score__c = nouveauScore));
    }
    update aMettreAJour;
  }

  // ===== Calcul du score (0-100 pondéré, borné à [1,99]) =====
  @TestVisible
  private static Integer calculerScore(
    String statut,
    Date dateRdv,
    String prioriteProspection,
    Date derniereMajMetier
  ) {
    Integer scoreStatut = scoreStatut(statut);
    Integer scoreRdv = scoreRdv(dateRdv);
    Integer scorePriorite = scorePriorite(prioriteProspection);
    Integer scoreFraicheur = scoreFraicheur(derniereMajMetier);

    Decimal composite =
      (scoreStatut * POIDS_STATUT +
      scoreRdv * POIDS_RDV +
      scorePriorite * POIDS_PRIORITE +
      scoreFraicheur * POIDS_FRAICHEUR) / 100.0;

    Integer score = Math.round(composite);
    return Math.max(1, Math.min(99, score));
  }

  private static Integer scoreStatut(String statut) {
    if (statut == 'RDV Fait' || statut == 'Qualified') {
      return 100;
    }
    if (statut == 'RDV organisé') {
      return 85;
    }
    if (statut == 'RDV à organiser') {
      return 70;
    }
    if (statut == 'A Rappeler' || statut == 'Nurturing') {
      return 50;
    }
    return 30;
  }

  private static Integer scoreRdv(Date dateRdv) {
    if (dateRdv == null) {
      return 20;
    }
    if (dateRdv >= Date.today()) {
      return 100;
    }
    // dateRdv.daysBetween(today) = aujourd'hui - dateRdv.
    Integer joursDepuis = dateRdv.daysBetween(Date.today());
    return joursDepuis <= 30 ? 70 : 20;
  }

  private static Integer scorePriorite(String prioriteProspection) {
    if (prioriteProspection == 'Prioritaire') {
      return 100;
    }
    if (prioriteProspection == 'SF') {
      return 70;
    }
    if (prioriteProspection == 'Réservé') {
      return 40;
    }
    return 50;
  }

  private static Integer scoreFraicheur(Date derniereMajMetier) {
    if (derniereMajMetier == null) {
      return 100;
    }
    // derniereMajMetier.daysBetween(today) = aujourd'hui - derniereMajMetier.
    Integer joursDepuisMaj = derniereMajMetier.daysBetween(Date.today());
    if (joursDepuisMaj < 7) {
      return 100;
    }
    if (joursDepuisMaj < 15) {
      return 60;
    }
    if (joursDepuisMaj < 30) {
      return 25;
    }
    return 0;
  }
}
