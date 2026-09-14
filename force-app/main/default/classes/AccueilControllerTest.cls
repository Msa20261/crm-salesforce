@isTest
private class AccueilControllerTest {
  @testSetup
  static void setup() {
    Account a = new Account(Name = 'Compte AccueilTest');
    insert a;

    insert new Lead(
      FirstName = 'Jean',
      LastName = 'Dupont',
      Company = 'Acme',
      Status = 'New'
    );

    insert new Opportunity(
      Name = 'Opp AccueilTest',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      AccountId = a.Id
    );

    insert new Task(
      Subject = 'Appel AccueilTest',
      Status = 'Not Started',
      Priority = 'Normal',
      ActivityDate = Date.today()
    );
  }

  @isTest
  static void testGetKPI_retourneLesClesRequises() {
    Test.startTest();
    Map<String, Integer> kpi = AccueilController.getKPI();
    Test.stopTest();

    System.assertNotEquals(null, kpi, 'KPI ne doit pas être null');
    System.assert(kpi.containsKey('leads'), 'Clé leads manquante');
    System.assert(
      kpi.containsKey('opportunites'),
      'Clé opportunites manquante'
    );
    System.assert(kpi.containsKey('contrats'), 'Clé contrats manquante');
    System.assert(kpi.containsKey('taches'), 'Clé taches manquante');
    System.assert(
      kpi.containsKey('comptesRendus'),
      'Clé comptesRendus manquante'
    );
    System.assert(
      kpi.get('opportunites') >= 1,
      'Doit compter au moins l\'opportunité créée'
    );
    System.assert(kpi.get('leads') >= 0, 'Leads doit être >= 0');
    System.assert(kpi.get('contrats') >= 0, 'Contrats doit être >= 0');
  }

  @isTest
  static void testGetActiviteRecente_retourneOpportunite() {
    Test.startTest();
    List<Map<String, String>> activites = AccueilController.getActiviteRecente();
    Test.stopTest();

    System.assertNotEquals(null, activites);
    Boolean hasOpp = false;
    for (Map<String, String> m : activites) {
      if ('Opportunité'.equals(m.get('type'))) {
        hasOpp = true;
        System.assertNotEquals(null, m.get('id'));
        System.assertNotEquals(null, m.get('nom'));
        System.assertEquals('standard:opportunity', m.get('icone'));
        break;
      }
    }
    System.assert(
      hasOpp,
      'L\'activité récente doit inclure au moins une Opportunité'
    );
  }

  // Le Contract ne peut pas être inséré directement en Activated : Draft puis update.
  private static Contract creerContratActifPourCompte(Id accountId) {
    Contract c = new Contract(
      AccountId = accountId,
      StartDate = Date.today().addMonths(-1),
      ContractTerm = 12
    );
    insert c;
    c.Status = 'Activated';
    update c;
    return c;
  }

  @isTest
  static void testGetMesAlertes_retourneAlerteSurMonCompte() {
    Account a = new Account(Name = 'Compte Alerte Test');
    insert a;
    Contract c = creerContratActifPourCompte(a.Id);
    insert new Alert__c(
      Contract__c = c.Id,
      Type_Alerte__c = 'Surfacturation',
      Statut__c = 'Nouvelle',
      Date_Alerte__c = Date.today(),
      Message__c = 'Surfacturation détectée'
    );

    Test.startTest();
    List<Map<String, String>> alertes = AccueilController.getMesAlertes();
    Test.stopTest();

    System.assertNotEquals(null, alertes);
    System.assertEquals(1, alertes.size(), 'Une alerte doit être retournée');
    System.assertEquals('Surfacturation', alertes[0].get('type'));
    System.assertEquals('Compte Alerte Test', alertes[0].get('compte'));
  }

  @isTest
  static void testGetOpportunitesUpsell_retourneOpportuniteSurCompteSousContrat() {
    Account a = new Account(Name = 'Compte Upsell Test');
    insert a;
    creerContratActifPourCompte(a.Id);
    Opportunity oppSousContrat = new Opportunity(
      Name = 'Opp Upsell Test',
      StageName = 'Negotiation',
      CloseDate = Date.today().addDays(15),
      AccountId = a.Id
    );
    insert oppSousContrat;

    Test.startTest();
    List<Map<String, String>> opps = AccueilController.getOpportunitesUpsell();
    Test.stopTest();

    System.assertNotEquals(null, opps);
    Boolean trouvee = false;
    Boolean oppSansContratPresente = false;
    for (Map<String, String> m : opps) {
      if (oppSousContrat.Id == (Id) m.get('id')) {
        trouvee = true;
        System.assertEquals('Compte Upsell Test', m.get('compte'));
      }
      if ('Opp AccueilTest'.equals(m.get('nom'))) {
        oppSansContratPresente = true;
      }
    }
    System.assert(
      trouvee,
      'L\'opportunité sur le compte sous contrat actif doit être retournée'
    );
    System.assert(
      !oppSansContratPresente,
      'Une opportunité sur un compte sans contrat actif ne doit pas apparaître'
    );
  }

  @isTest
  static void testGetTachesJour_retourneLaTacheDuJour() {
    Test.startTest();
    List<Map<String, String>> taches = AccueilController.getTachesJour();
    Test.stopTest();

    System.assertNotEquals(null, taches);
    System.assertEquals(
      1,
      taches.size(),
      'Une seule tâche doit être retournée'
    );
    System.assertEquals('Appel AccueilTest', taches[0].get('sujet'));
    System.assertEquals('Not Started', taches[0].get('statut'));
    System.assertEquals('Normal', taches[0].get('priorite'));
  }

  @isTest
  static void testGetTachesJour_tacheCompleteeExclue() {
    insert new Task(
      Subject = 'Tache Completee',
      Status = 'Completed',
      Priority = 'Normal',
      ActivityDate = Date.today()
    );

    Test.startTest();
    List<Map<String, String>> taches = AccueilController.getTachesJour();
    Test.stopTest();

    for (Map<String, String> t : taches) {
      System.assertNotEquals(
        'Completed',
        t.get('statut'),
        'Les tâches Completed ne doivent pas apparaître'
      );
    }
  }
}
