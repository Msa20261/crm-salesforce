@RestResource(urlMapping='/ping/*')
global with sharing class PingRestService {
  @HttpGet
  global static void ping() {
    RestResponse res = RestContext.response;
    res.statusCode = 200;
    res.addHeader('Content-Type', 'application/json');
    res.responseBody = Blob.valueOf(
      '{"status":"ok","organizationId":"' +
        UserInfo.getOrganizationId() +
        '","timestamp":"' +
        String.valueOf(Datetime.now()) +
        '"}'
    );
  }
}
