@isTest
private class LeadScoringServiceTest {
  @isTest
  static void testCalculerScore_rdvFaitEtPrioritaire_scoreEleve() {
    Integer score = LeadScoringService.calculerScore(
      'RDV Fait',
      Date.today().addDays(3),
      'Prioritaire',
      Date.today()
    );

    System.assert(
      score >= 90,
      'Un statut RDV Fait, un RDV à venir, une priorité prioritaire et aucune stagnation doivent donner un score très élevé, obtenu : ' +
      score
    );
    System.assert(score <= 99, 'Le score ne doit jamais dépasser 99');
  }

  @isTest
  static void testCalculerScore_openEtStagnation_scoreFaible() {
    Integer score = LeadScoringService.calculerScore(
      'Open',
      null,
      'Réservé',
      Date.today().addDays(-90)
    );

    System.assert(
      score <= 30,
      'Un statut Open, aucun RDV, une priorité Réservé et une forte stagnation doivent donner un score faible, obtenu : ' +
      score
    );
    System.assert(score >= 1, 'Le score ne doit jamais être inférieur à 1');
  }

  @isTest
  static void testCalculerScore_valeursNull_neLevePasDErreur() {
    Integer score = LeadScoringService.calculerScore(null, null, null, null);
    System.assertNotEquals(null, score);
  }

  @isTest
  static void testAvantEnregistrement_insertionStampeUneDateDuJour() {
    Test.startTest();
    Lead l = new Lead(
      FirstName = 'Jean',
      LastName = 'Scoring Test',
      Company = 'Acme Scoring',
      Status = 'Open'
    );
    insert l;
    Test.stopTest();

    Lead resultat = [
      SELECT Score__c, Derniere_Maj_Metier__c
      FROM Lead
      WHERE Id = :l.Id
    ];
    System.assertEquals(
      Date.today(),
      resultat.Derniere_Maj_Metier__c,
      'La date de mise à jour métier doit être stampée à la création'
    );
    System.assertNotEquals(
      null,
      resultat.Score__c,
      'Le score doit être calculé dès la création'
    );
  }

  @isTest
  static void testAvantEnregistrement_leadNotQualified_pasDeScore() {
    Test.startTest();
    Lead l = new Lead(
      FirstName = 'Jean',
      LastName = 'Not Qualified Test',
      Company = 'Acme Scoring',
      Status = 'Not Qualified'
    );
    insert l;
    Test.stopTest();

    Lead resultat = [SELECT Score__c FROM Lead WHERE Id = :l.Id];
    System.assertEquals(
      null,
      resultat.Score__c,
      'Un lead Not Qualified ne doit pas être scoré'
    );
  }

  @isTest
  static void testAvantEnregistrement_modifSansChampMetier_neReStampePasLaDate() {
    Lead l = new Lead(
      FirstName = 'Jean',
      LastName = 'Scoring Test 2',
      Company = 'Acme Scoring',
      Status = 'Open'
    );
    insert l;

    update new Lead(
      Id = l.Id,
      Derniere_Maj_Metier__c = Date.today().addDays(-40)
    );

    Test.startTest();
    update new Lead(Id = l.Id, Description = 'Note interne');
    Test.stopTest();

    Lead resultat = [SELECT Derniere_Maj_Metier__c FROM Lead WHERE Id = :l.Id];
    System.assertEquals(
      Date.today().addDays(-40),
      resultat.Derniere_Maj_Metier__c,
      'Une modification non-métier ne doit pas rafraîchir la date de mise à jour métier'
    );
  }

  @isTest
  static void testRecalculerLeadsOuverts_metAJourLeScoreSansToucherLaDateMetier() {
    Lead l = new Lead(
      FirstName = 'Jean',
      LastName = 'Scoring Test 3',
      Company = 'Acme Scoring',
      Status = 'RDV Fait',
      Priorit_de_prospection__c = 'Prioritaire'
    );
    insert l;
    Decimal scoreInitial = [SELECT Score__c FROM Lead WHERE Id = :l.Id]
    .Score__c;

    update new Lead(
      Id = l.Id,
      Derniere_Maj_Metier__c = Date.today().addDays(-40)
    );

    Test.startTest();
    LeadScoringService.recalculerLeadsOuverts();
    Test.stopTest();

    Lead resultat = [
      SELECT Score__c, Derniere_Maj_Metier__c
      FROM Lead
      WHERE Id = :l.Id
    ];
    System.assertEquals(
      Date.today().addDays(-40),
      resultat.Derniere_Maj_Metier__c,
      'Le recalcul quotidien ne doit jamais modifier la date de mise à jour métier'
    );
    System.assert(
      resultat.Score__c < scoreInitial,
      'Le score doit baisser une fois la stagnation détectée par le recalcul quotidien'
    );
  }

  @isTest
  static void testRecalculerLeadsOuverts_ignoreLesNotQualified() {
    Lead l = new Lead(
      FirstName = 'Jean',
      LastName = 'Not Qualified Test 2',
      Company = 'Acme Scoring',
      Status = 'Not Qualified'
    );
    insert l;

    Test.startTest();
    LeadScoringService.recalculerLeadsOuverts();
    Test.stopTest();

    Lead resultat = [SELECT Score__c FROM Lead WHERE Id = :l.Id];
    System.assertEquals(
      null,
      resultat.Score__c,
      'Un lead Not Qualified ne doit jamais être inclus dans le recalcul'
    );
  }
}
