@isTest
private class PingRestServiceTest {
  @isTest
  static void testPingRepondOk() {
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/ping/';
    req.httpMethod = 'GET';
    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    PingRestService.ping();
    Test.stopTest();

    RestResponse res = RestContext.response;
    System.assertEquals(200, res.statusCode, 'Le ping doit repondre 200');
    String body = res.responseBody.toString();
    System.assert(
      body.contains('"status":"ok"'),
      'La reponse doit contenir status ok'
    );
    System.assert(
      body.contains('"message":"Ping CRM Upmind Salesforce reussi"'),
      'La reponse doit contenir un message caracteristique'
    );
  }
}
