public with sharing class CrmDashboardController {

    // ── ALERTES ────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Alert__c> getAlertes(Id contractLineId) {
        return [
            SELECT Id, Name, Type_Alerte__c, Message__c,
                   Date_Alerte__c, Statut__c, Seuil_Depasse__c
            FROM   Alert__c
            WHERE  Contract_Line__c = :contractLineId
            ORDER  BY Date_Alerte__c DESC
            LIMIT  50
        ];
    }

    @AuraEnabled
    public static void updateStatutAlerte(Id alerteId, String statut) {
        Alert__c a = new Alert__c(Id = alerteId, Statut__c = statut);
        update a;
    }

    // ── CONSOMMATIONS ──────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Consumption__c> getConsommations(Id contractLineId) {
        return [
            SELECT Id, Name, Periode_Debut__c, Periode_Fin__c,
                   Montant_Achete__c, Montant_Consomme__c,
                   Montant_Restant__c, Source__c
            FROM   Consumption__c
            WHERE  Contract_Line__c = :contractLineId
            ORDER  BY Periode_Debut__c DESC
            LIMIT  24
        ];
    }

    // ── CONTRACT SUMMARY ──────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getContractSummary(Id contractId) {
        Map<String, Object> result = new Map<String, Object>();

        List<Contract> contracts = [
            SELECT Id, ContractNumber, Status, StartDate, EndDate,
                   AccountId, Account.Name,
                   Montant_Abonnement__c, Montant_Token_Estime__c,
                   Frais_Gestion__c, Type_Facturation__c,
                   Date_Debut_Token__c, Date_Fin_Token__c
            FROM   Contract
            WHERE  Id = :contractId
            LIMIT  1
        ];
        if (contracts.isEmpty()) return result;
        result.put('contrat', contracts[0]);

        // lignes de contrat
        List<Contract_Line__c> lignes = [
            SELECT Id, Name, Type_Ligne__c, Montant__c, Quantite__c,
                   Prix_Unitaire__c, Frais_Gestion__c
            FROM   Contract_Line__c
            WHERE  Contract__c = :contractId
        ];
        result.put('lignes', lignes);
        result.put('nbLignes', lignes.size());

        // totaux consommation
        AggregateResult[] consoConso = [
            SELECT SUM(Montant_Consomme__c) totalConso,
                   SUM(Montant_Achete__c)   totalAchete
            FROM   Consumption__c
            WHERE  Contract_Line__r.Contract__c = :contractId
        ];
        result.put('totalConso',   consoConso[0].get('totalConso'));
        result.put('totalAchete',  consoConso[0].get('totalAchete'));

        // alertes ouvertes
        Integer nbAlertes = [
            SELECT COUNT() FROM Alert__c
            WHERE  Contract_Line__r.Contract__c = :contractId
            AND    Statut__c = 'Nouvelle'
        ];
        result.put('nbAlertes', nbAlertes);

        // factures
        AggregateResult[] factures = [
            SELECT COUNT(Id) total, SUM(Montant__c) montantTotal
            FROM   Invoice__c
            WHERE  Contract__c = :contractId
        ];
        result.put('nbFactures',      factures[0].get('total'));
        result.put('montantFactures', factures[0].get('montantTotal'));

        return result;
    }
}
