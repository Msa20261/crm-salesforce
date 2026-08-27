@isTest
private class TokenConsumptionRestServiceTest {
  @TestSetup
  static void setup() {
    Account acc = new Account(
      Name = 'Compte Test API',
      Identifiant_Externe__c = 'EXT-001'
    );
    insert acc;

    Contract ctr = new Contract(
      AccountId = acc.Id,
      Status = 'Draft',
      StartDate = Date.today(),
      ContractTerm = 12
    );
    insert ctr;
    ctr.Status = 'Activated';
    update ctr;

    Contract_Line__c ligne = new Contract_Line__c(
      Contract__c = ctr.Id,
      Montant__c = 1000
    );
    insert ligne;
  }

  private static RestResponse envoyerRequete(String body) {
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/tokenConsumption/';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(body);
    RestContext.request = req;
    RestContext.response = new RestResponse();
    TokenConsumptionRestService.creerConsommation();
    return RestContext.response;
  }

  @isTest
  static void testCreationReussieParIdentifiantExterne() {
    Test.startTest();
    RestResponse res = envoyerRequete(
      '{"identifiantExterneCompte":"EXT-001","montantConsomme":150.5,"montantAchete":1000,"periodeDebut":"2026-08-01"}'
    );
    Test.stopTest();

    System.assertEquals(201, res.statusCode);
    List<Consumption__c> conso = [
      SELECT Id, Montant_Consomme__c, Source__c
      FROM Consumption__c
    ];
    System.assertEquals(1, conso.size());
    System.assertEquals('Ludwig API', conso[0].Source__c);
  }

  @isTest
  static void testCompteInconnu() {
    Test.startTest();
    RestResponse res = envoyerRequete(
      '{"identifiantExterneCompte":"INCONNU","montantConsomme":50}'
    );
    Test.stopTest();

    System.assertEquals(400, res.statusCode);
  }

  @isTest
  static void testMontantManquant() {
    Test.startTest();
    RestResponse res = envoyerRequete('{"identifiantExterneCompte":"EXT-001"}');
    Test.stopTest();

    System.assertEquals(400, res.statusCode);
  }

  @isTest
  static void testContractLineIdExplicite() {
    Contract_Line__c ligne = [SELECT Id FROM Contract_Line__c LIMIT 1];

    Test.startTest();
    RestResponse res = envoyerRequete(
      '{"contractLineId":"' + ligne.Id + '","montantConsomme":200}'
    );
    Test.stopTest();

    System.assertEquals(201, res.statusCode);
  }
}
