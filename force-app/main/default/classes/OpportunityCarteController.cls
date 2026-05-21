public with sharing class OpportunityCarteController {

    public class OppInfo {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  nom;
        @AuraEnabled public String  stageName;
        @AuraEnabled public Decimal montant;
        @AuraEnabled public Date    dateCloture;
        @AuraEnabled public Id      compteId;
        @AuraEnabled public String  compteNom;
        @AuraEnabled public String  rue;
        @AuraEnabled public String  ville;
        @AuraEnabled public String  codePostal;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public Decimal latitudeOpp;
        @AuraEnabled public Decimal longitudeOpp;
        @AuraEnabled public Integer anneeCreation;
    }

    @AuraEnabled(cacheable=true)
    public static List<OppInfo> getOpportunitiesAvecAdresse() {
        List<OppInfo> result = new List<OppInfo>();
        for (Opportunity opp : [
            SELECT Id, Name, StageName, Amount, CloseDate, CreatedDate,
                   AccountId, Account.Name,
                   Account.BillingLatitude, Account.BillingLongitude,
                   adresse__Street__s, adresse__City__s, adresse__PostalCode__s,
                   Latitude__c, Longitude__c
            FROM Opportunity
            WHERE AccountId != null
              AND (adresse__City__s != null OR adresse__Street__s != null)
            ORDER BY Name
        ]) {
            OppInfo info     = new OppInfo();
            info.id          = opp.Id;
            info.nom         = opp.Name;
            info.stageName   = opp.StageName;
            info.montant     = opp.Amount;
            info.dateCloture = opp.CloseDate;
            info.compteId    = opp.AccountId;
            info.compteNom   = opp.Account.Name;
            info.rue         = opp.adresse__Street__s;
            info.ville       = opp.adresse__City__s;
            info.codePostal  = opp.adresse__PostalCode__s;
            info.latitude    = opp.Account.BillingLatitude;
            info.longitude   = opp.Account.BillingLongitude;
            info.latitudeOpp   = opp.Latitude__c;
            info.longitudeOpp  = opp.Longitude__c;
            info.anneeCreation = opp.CreatedDate.year();
            result.add(info);
        }
        return result;
    }
}
