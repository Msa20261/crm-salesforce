@isTest
private class CrmDashboardControllerTest {

    // ── Setup ─────────────────────────────────────────────────────────────────

    private static Map<String, Id> creerDonnees() {
        Account a = new Account(Name = 'Compte Dashboard Test');
        insert a;

        Contract c = new Contract(AccountId = a.Id, StartDate = Date.today(), ContractTerm = 12);
        insert c;

        Contract_Line__c cl = new Contract_Line__c(Contract__c = c.Id, Montant__c = 5000);
        insert cl;

        Alert__c alerte = new Alert__c(
            Contract_Line__c = cl.Id,
            Type_Alerte__c   = 'Surfacturation',
            Statut__c        = 'Nouvelle',
            Date_Alerte__c   = Date.today(),
            Message__c       = 'Test alerte dashboard'
        );
        insert alerte;

        Consumption__c conso = new Consumption__c(
            Contract_Line__c    = cl.Id,
            Montant_Achete__c   = 1000,
            Montant_Consomme__c = 600,
            Periode_Debut__c    = Date.today().toStartOfMonth(),
            Periode_Fin__c      = Date.today()
        );
        insert conso;

        return new Map<String, Id>{
            'contractId'     => c.Id,
            'contractLineId' => cl.Id,
            'alerteId'       => alerte.Id
        };
    }

    // ── Tests getAlertes ──────────────────────────────────────────────────────

    @isTest
    static void testGetAlertes_retourneAlertesDeLaLigne() {
        Map<String, Id> ids = creerDonnees();

        Test.startTest();
        List<Alert__c> alertes = CrmDashboardController.getAlertes(ids.get('contractLineId'));
        Test.stopTest();

        System.assertEquals(1, alertes.size(), 'Une alerte doit être retournée');
        System.assertEquals('Surfacturation', alertes[0].Type_Alerte__c);
        System.assertEquals('Nouvelle', alertes[0].Statut__c);
    }

    @isTest
    static void testGetAlertes_ligneNulle_retourneListeVide() {
        Test.startTest();
        List<Alert__c> alertes = CrmDashboardController.getAlertes(null);
        Test.stopTest();
        System.assertEquals(0, alertes.size(), 'Liste vide si contractLineId est null');
    }

    // ── Tests updateStatutAlerte ──────────────────────────────────────────────

    @isTest
    static void testUpdateStatutAlerte_passageAResolue() {
        Map<String, Id> ids = creerDonnees();

        Test.startTest();
        CrmDashboardController.updateStatutAlerte(ids.get('alerteId'), 'Résolue');
        Test.stopTest();

        Alert__c a = [SELECT Statut__c FROM Alert__c WHERE Id = :ids.get('alerteId')];
        System.assertEquals('Résolue', a.Statut__c, 'Le statut doit être mis à jour en Résolue');
    }

    @isTest
    static void testUpdateStatutAlerte_passageAVue() {
        Map<String, Id> ids = creerDonnees();

        Test.startTest();
        CrmDashboardController.updateStatutAlerte(ids.get('alerteId'), 'Vue');
        Test.stopTest();

        Alert__c a = [SELECT Statut__c FROM Alert__c WHERE Id = :ids.get('alerteId')];
        System.assertEquals('Vue', a.Statut__c, 'Le statut doit être mis à jour en Vue');
    }

    // ── Tests getConsommations ────────────────────────────────────────────────

    @isTest
    static void testGetConsommations_retourneConsommationsDeLaLigne() {
        Map<String, Id> ids = creerDonnees();

        Test.startTest();
        List<Consumption__c> consos = CrmDashboardController.getConsommations(ids.get('contractLineId'));
        Test.stopTest();

        System.assertEquals(1, consos.size(), 'Une consommation doit être retournée');
        System.assertEquals(1000, consos[0].Montant_Achete__c);
        System.assertEquals(600, consos[0].Montant_Consomme__c);
    }

    // ── Tests getContractSummary ──────────────────────────────────────────────

    @isTest
    static void testGetContractSummary_retourneResume() {
        Map<String, Id> ids = creerDonnees();

        Test.startTest();
        Map<String, Object> summary = CrmDashboardController.getContractSummary(ids.get('contractId'));
        Test.stopTest();

        System.assertNotEquals(null, summary);
        System.assert(summary.containsKey('contrat'), 'Doit contenir la clé contrat');
        System.assert(summary.containsKey('lignes'), 'Doit contenir la clé lignes');
        System.assert(summary.containsKey('nbLignes'), 'Doit contenir la clé nbLignes');
        System.assert(summary.containsKey('totalConso'), 'Doit contenir la clé totalConso');
        System.assert(summary.containsKey('totalAchete'), 'Doit contenir la clé totalAchete');
        System.assert(summary.containsKey('nbAlertes'), 'Doit contenir la clé nbAlertes');
        System.assert(summary.containsKey('nbFactures'), 'Doit contenir la clé nbFactures');

        System.assertEquals(1, (Integer) summary.get('nbLignes'), 'Une ligne de contrat');
        System.assertEquals(1, (Integer) summary.get('nbAlertes'), 'Une alerte Nouvelle');
        System.assertEquals(1000, (Decimal) summary.get('totalAchete'), 'Total acheté = 1000');
        System.assertEquals(600, (Decimal) summary.get('totalConso'), 'Total consommé = 600');
    }

    @isTest
    static void testGetContractSummary_contratInexistant_retourneMapVide() {
        // Créer et supprimer un contrat pour obtenir un ID valide mais orphelin
        Account a = new Account(Name = 'Compte Fantome');
        insert a;
        Contract c = new Contract(AccountId = a.Id, StartDate = Date.today(), ContractTerm = 12);
        insert c;
        Id contractId = c.Id;
        delete c;

        Test.startTest();
        Map<String, Object> summary = CrmDashboardController.getContractSummary(contractId);
        Test.stopTest();

        System.assertEquals(0, summary.size(), 'Map vide si le contrat n\'existe pas');
    }
}
