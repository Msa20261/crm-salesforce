public class OpportunityTriggerHandler {

    public static void handleAfterUpdate(List<Opportunity> newOpps, Map<Id, Opportunity> oldMap) {

        // Sélectionner uniquement les Opportunités qui passent en Closed Won
        List<Opportunity> closedWonOpps = new List<Opportunity>();
        for (Opportunity opp : newOpps) {
            if (opp.StageName == 'Closed Won' && oldMap.get(opp.Id).StageName != 'Closed Won') {
                closedWonOpps.add(opp);
            }
        }

        if (closedWonOpps.isEmpty()) return;

        creerContrats(closedWonOpps);
    }

    private static void creerContrats(List<Opportunity> opps) {

        // Récupérer les produits de chaque Opportunité
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity opp : opps) oppIds.add(opp.Id);

        Map<Id, List<OpportunityLineItem>> oliParOpp = new Map<Id, List<OpportunityLineItem>>();
        for (OpportunityLineItem oli : [
            SELECT Id, OpportunityId, Product2Id, UnitPrice, Quantity, TotalPrice
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oppIds
        ]) {
            if (!oliParOpp.containsKey(oli.OpportunityId)) {
                oliParOpp.put(oli.OpportunityId, new List<OpportunityLineItem>());
            }
            oliParOpp.get(oli.OpportunityId).add(oli);
        }

        // Créer les Contrats
        List<Contract> contrats = new List<Contract>();
        for (Opportunity opp : opps) {
            Contract c = new Contract();
            c.AccountId      = opp.AccountId;
            c.Opportunity__c = opp.Id;
            c.Name           = opp.Name;
            c.StartDate      = opp.CloseDate != null ? opp.CloseDate : Date.today();
            c.ContractTerm   = 12;
            c.Status         = 'Draft';
            c.OwnerId        = opp.OwnerId;
            contrats.add(c);
        }
        insert contrats;

        // Associer chaque Opportunité à son Contrat créé
        Map<Id, Id> oppVersContrat = new Map<Id, Id>();
        for (Integer i = 0; i < opps.size(); i++) {
            oppVersContrat.put(opps[i].Id, contrats[i].Id);
        }

        // Créer les Lignes de Contrat — snapshot figé des produits
        List<Contract_Line__c> lignes = new List<Contract_Line__c>();
        for (Opportunity opp : opps) {
            Id contratId = oppVersContrat.get(opp.Id);
            List<OpportunityLineItem> olis = oliParOpp.get(opp.Id);
            if (olis == null) continue;

            for (OpportunityLineItem oli : olis) {
                Contract_Line__c ligne = new Contract_Line__c();
                ligne.Contract__c               = contratId;
                ligne.Opportunity_Line_Item__c  = oli.Id;
                ligne.Produit__c                = oli.Product2Id;
                ligne.Prix_Unitaire__c          = oli.UnitPrice;
                ligne.Quantite__c               = oli.Quantity;
                ligne.Montant__c                = oli.TotalPrice;
                lignes.add(ligne);
            }
        }

        if (!lignes.isEmpty()) insert lignes;
    }
}
