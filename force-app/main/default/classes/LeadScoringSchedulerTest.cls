@isTest
private class LeadScoringSchedulerTest {
  @isTest
  static void testExecute_refleteLaStagnationParRapportAuScoreInitial() {
    Lead l = new Lead(
      FirstName = 'Jean',
      LastName = 'Scheduler Test',
      Company = 'Acme Scheduler',
      Status = 'RDV Fait',
      Priorit_de_prospection__c = 'Prioritaire'
    );
    insert l;
    Decimal scoreFrais = [SELECT Score__c FROM Lead WHERE Id = :l.Id].Score__c;

    update new Lead(
      Id = l.Id,
      Derniere_Maj_Metier__c = Date.today().addDays(-40)
    );

    Test.startTest();
    new LeadScoringScheduler().execute(null);
    Test.stopTest();

    Decimal scoreApresStagnation = [
      SELECT Score__c
      FROM Lead
      WHERE Id = :l.Id
    ]
    .Score__c;
    System.assert(
      scoreApresStagnation < scoreFrais,
      'Le job planifié doit refléter la stagnation détectée par rapport au score initial'
    );
  }

  @isTest
  static void testSchedulable_estBienPlanifiable() {
    Test.startTest();
    String jobId = System.schedule(
      'Test Recalcul Score Leads',
      '0 0 5 * * ?',
      new LeadScoringScheduler()
    );
    Test.stopTest();

    System.assertNotEquals(null, jobId, 'Le job planifié doit être créé');
  }
}
