@RestResource(urlMapping='/tokenConsumption/*')
global with sharing class TokenConsumptionRestService {
  public class TokenConsumptionException extends Exception {
  }

  public class ConsumptionRequest {
    public String identifiantExterneCompte;
    public String contractLineId;
    public Decimal montantConsomme;
    public Decimal montantAchete;
    public Date periodeDebut;
    public Date periodeFin;
  }

  public class ConsumptionResponse {
    public Boolean success;
    public String consumptionId;
    public String erreur;
  }

  @HttpPost
  global static void creerConsommation() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;
    ConsumptionResponse resultat = new ConsumptionResponse();

    try {
      ConsumptionRequest payload = (ConsumptionRequest) JSON.deserialize(
        req.requestBody.toString(),
        ConsumptionRequest.class
      );

      if (payload.montantConsomme == null) {
        throw new TokenConsumptionException('montantConsomme est obligatoire.');
      }

      Id contractLineId = resoudreContractLine(payload);

      Consumption__c conso = new Consumption__c(
        Contract_Line__c = contractLineId,
        Montant_Consomme__c = payload.montantConsomme,
        Montant_Achete__c = payload.montantAchete,
        Periode_Debut__c = payload.periodeDebut != null
          ? payload.periodeDebut
          : Date.today(),
        Periode_Fin__c = payload.periodeFin,
        Source__c = 'Ludwig API'
      );
      insert conso;

      resultat.success = true;
      resultat.consumptionId = conso.Id;
      res.statusCode = 201;
    } catch (TokenConsumptionException e) {
      resultat.success = false;
      resultat.erreur = e.getMessage();
      res.statusCode = 400;
    } catch (Exception e) {
      resultat.success = false;
      resultat.erreur = 'Erreur interne : ' + e.getMessage();
      res.statusCode = 500;
    }

    res.addHeader('Content-Type', 'application/json');
    res.responseBody = Blob.valueOf(JSON.serialize(resultat));
  }

  // Priorite au contractLineId explicite ; sinon resolution via l'identifiant externe du compte,
  // en exigeant une ligne de contrat active unique (evite d'imputer la conso a la mauvaise ligne).
  private static Id resoudreContractLine(ConsumptionRequest payload) {
    if (String.isNotBlank(payload.contractLineId)) {
      return (Id) payload.contractLineId;
    }
    if (String.isBlank(payload.identifiantExterneCompte)) {
      throw new TokenConsumptionException(
        'identifiantExterneCompte ou contractLineId requis.'
      );
    }

    List<Account> comptes = [
      SELECT Id
      FROM Account
      WHERE Identifiant_Externe__c = :payload.identifiantExterneCompte
      LIMIT 1
    ];
    if (comptes.isEmpty()) {
      throw new TokenConsumptionException(
        'Aucun compte trouve pour identifiantExterneCompte=' +
        payload.identifiantExterneCompte
      );
    }

    List<Contract_Line__c> lignes = [
      SELECT Id
      FROM Contract_Line__c
      WHERE
        Contract__r.AccountId = :comptes[0].Id
        AND Contract__r.Status = 'Activated'
      ORDER BY CreatedDate DESC
    ];
    if (lignes.isEmpty()) {
      throw new TokenConsumptionException(
        'Aucune ligne de contrat active trouvee pour ce compte.'
      );
    }
    if (lignes.size() > 1) {
      throw new TokenConsumptionException(
        'Plusieurs lignes de contrat actives pour ce compte : preciser contractLineId.'
      );
    }
    return lignes[0].Id;
  }
}
