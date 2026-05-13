public with sharing class CarteClientsController {

    public class AccountInfo {
        @AuraEnabled public Id id;
        @AuraEnabled public String nom;
        @AuraEnabled public String rue;
        @AuraEnabled public String ville;
        @AuraEnabled public String codePostal;
        @AuraEnabled public String pays;
        @AuraEnabled public Integer nbContrats;
        @AuraEnabled public Boolean aAdresse;
    }

    @AuraEnabled(cacheable=true)
    public static List<AccountInfo> getAccountsAvecContrat() {
        Map<Id, Integer> nbContrats = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT AccountId, COUNT(Id) nb
            FROM Contract
            GROUP BY AccountId
        ]) {
            nbContrats.put((Id)ar.get('AccountId'), (Integer)ar.get('nb'));
        }

        List<AccountInfo> result = new List<AccountInfo>();
        for (Account a : [
            SELECT Id, Name, BillingStreet, BillingCity, BillingPostalCode, BillingCountry
            FROM Account
            WHERE Id IN :nbContrats.keySet()
            ORDER BY Name
        ]) {
            AccountInfo info = new AccountInfo();
            info.id        = a.Id;
            info.nom       = a.Name;
            info.rue       = a.BillingStreet;
            info.ville     = a.BillingCity;
            info.codePostal = a.BillingPostalCode;
            info.pays      = a.BillingCountry != null ? a.BillingCountry : 'France';
            info.nbContrats = nbContrats.get(a.Id);
            info.aAdresse  = (a.BillingCity != null);
            result.add(info);
        }
        return result;
    }
}
