@isTest
public class NominatimMock implements HttpCalloutMock {
    private Integer statusCode;
    private String body;

    public NominatimMock() {
        this.statusCode = 200;
        this.body = '[{"lat":"48.8566","lon":"2.3522","display_name":"Paris, France"}]';
    }

    public NominatimMock(Integer statusCode, String body) {
        this.statusCode = statusCode;
        this.body = body;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(this.statusCode);
        res.setBody(this.body);
        return res;
    }
}
