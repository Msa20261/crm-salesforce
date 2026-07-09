@isTest
private class ContractExpirationAlertSchedulerTest {
  // ── Helpers ───────────────────────────────────────────────────────────────

  // EndDate n'est pas modifiable directement (calculé depuis StartDate + ContractTerm en mois),
  // donc on part de la date de fin voulue et on remonte d'1 mois pour l'obtenir exactement.
  private static Contract creerContratActif(Integer joursAvantEcheance) {
    Account a = new Account(Name = 'Compte Contrat Test ' + joursAvantEcheance);
    insert a;
    insert new Contact(
      FirstName = 'Bruno',
      LastName = 'Lefèvre',
      Email = 'bruno.lefevre@test.com',
      AccountId = a.Id
    );
    // Un Contract ne peut pas être inséré directement en statut Activated,
    // il faut l'insérer en Draft puis l'activer par un update séparé.
    Date dateFinCible = Date.today().addDays(joursAvantEcheance);
    Contract c = new Contract(
      AccountId = a.Id,
      StartDate = dateFinCible.addMonths(-1),
      ContractTerm = 1
    );
    insert c;
    c.Status = 'Activated';
    update c;
    return c;
  }

  // ── Tests ─────────────────────────────────────────────────────────────────

  @isTest
  static void testPreavisFinContrat_45joursAvantEcheance() {
    Contract c = creerContratActif(45);

    Test.startTest();
    ContractExpirationAlertScheduler.verifierEcheances();
    Test.stopTest();

    List<Alert__c> alertes = [
      SELECT Type_Alerte__c, Statut__c
      FROM Alert__c
      WHERE Contract__c = :c.Id
    ];
    System.assertEquals(
      1,
      alertes.size(),
      'Une alerte de préavis doit être créée à 45 jours'
    );
    System.assertEquals('Preavis_Fin_Contrat', alertes[0].Type_Alerte__c);
    System.assertEquals('Nouvelle', alertes[0].Statut__c);
  }

  @isTest
  static void testFinContratImminente_20joursAvantEcheance() {
    Contract c = creerContratActif(20);

    Test.startTest();
    ContractExpirationAlertScheduler.verifierEcheances();
    Test.stopTest();

    List<Alert__c> alertes = [
      SELECT Type_Alerte__c
      FROM Alert__c
      WHERE Contract__c = :c.Id
    ];
    System.assertEquals(
      1,
      alertes.size(),
      'Une alerte imminente doit être créée à 20 jours'
    );
    System.assertEquals('Fin_Contrat_Imminente', alertes[0].Type_Alerte__c);
  }

  @isTest
  static void testEcheanceLointaine_aucuneAlerte() {
    creerContratActif(90); // hors fenêtre de 60 jours

    Test.startTest();
    ContractExpirationAlertScheduler.verifierEcheances();
    Test.stopTest();

    Integer count = [
      SELECT COUNT()
      FROM Alert__c
      WHERE Type_Alerte__c IN ('Preavis_Fin_Contrat', 'Fin_Contrat_Imminente')
    ];
    System.assertEquals(
      0,
      count,
      'Pas d\'alerte tant que l\'échéance est à plus de 60 jours'
    );
  }

  @isTest
  static void testContratNonActive_aucuneAlerte() {
    Account a = new Account(Name = 'Compte Draft Test');
    insert a;
    Contract c = new Contract(
      AccountId = a.Id,
      Status = 'Draft',
      StartDate = Date.today().addDays(20).addMonths(-1),
      ContractTerm = 1
    );
    insert c;

    Test.startTest();
    ContractExpirationAlertScheduler.verifierEcheances();
    Test.stopTest();

    Integer count = [SELECT COUNT() FROM Alert__c WHERE Contract__c = :c.Id];
    System.assertEquals(0, count, 'Pas d\'alerte pour un contrat non activé');
  }

  @isTest
  static void testPasDoublon_alerteImminenteDejaOuverte() {
    Contract c = creerContratActif(20);
    insert new Alert__c(
      Contract__c = c.Id,
      Type_Alerte__c = 'Fin_Contrat_Imminente',
      Statut__c = 'Nouvelle',
      Date_Alerte__c = Date.today(),
      Message__c = 'Alerte existante'
    );

    Test.startTest();
    ContractExpirationAlertScheduler.verifierEcheances();
    Test.stopTest();

    Integer count = [
      SELECT COUNT()
      FROM Alert__c
      WHERE Contract__c = :c.Id AND Type_Alerte__c = 'Fin_Contrat_Imminente'
    ];
    System.assertEquals(
      1,
      count,
      'Pas de doublon si une alerte imminente est déjà ouverte'
    );
  }

  @isTest
  static void testSchedulable_executeAppelleVerifierEcheances() {
    creerContratActif(20);

    Test.startTest();
    String jobId = System.schedule(
      'Test Alerte Fin Contrat',
      '0 0 3 * * ?',
      new ContractExpirationAlertScheduler()
    );
    Test.stopTest();

    System.assertNotEquals(null, jobId, 'Le job planifié doit être créé');
  }
}
