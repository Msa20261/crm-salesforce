@RestResource(urlMapping='/ping/*')
global with sharing class PingRestService {
  public class PingResponse {
    public String status;
    public String message;
    public String organizationId;
    public String timestamp;
  }

  @HttpGet
  global static void ping() {
    RestResponse res = RestContext.response;

    PingResponse resultat = new PingResponse();
    resultat.status = 'ok';
    resultat.message = 'Ping CRM Upmind Salesforce reussi';
    resultat.organizationId = UserInfo.getOrganizationId();
    resultat.timestamp = String.valueOf(Datetime.now());

    res.statusCode = 200;
    res.addHeader('Content-Type', 'application/json');
    res.responseBody = Blob.valueOf(JSON.serialize(resultat));
  }
}
