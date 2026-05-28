@isTest
private class ConsumptionTriggerHandlerTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Contract_Line__c creerLigneContrat() {
        Account a = new Account(Name = 'Compte Conso Test');
        insert a;
        // Contact pour recevoir les emails d'alerte
        insert new Contact(FirstName = 'Alice', LastName = 'Durand',
                           Email = 'alice.durand@test.com', AccountId = a.Id);
        Contract c = new Contract(AccountId = a.Id, StartDate = Date.today(), ContractTerm = 12);
        insert c;
        Contract_Line__c cl = new Contract_Line__c(Contract__c = c.Id, Montant__c = 5000);
        insert cl;
        return cl;
    }

    // ── Tests alertes ─────────────────────────────────────────────────────────

    @isTest
    static void testAlerteSurfacturation_consommeSuperieureAchat() {
        Contract_Line__c cl = creerLigneContrat();

        Test.startTest();
        insert new Consumption__c(
            Contract_Line__c    = cl.Id,
            Montant_Achete__c   = 100,
            Montant_Consomme__c = 150 // 150 > 100 → Surfacturation (Montant_Restant__c est un champ formule)
        );
        Test.stopTest();

        // consomme > achete → Surfacturation ET Provision_Depassee sont toutes deux déclenchées
        // (restant = achete - consomme < 0 < seuil 20%) : on vérifie spécifiquement Surfacturation
        List<Alert__c> alertes = [SELECT Type_Alerte__c, Statut__c, Seuil_Depasse__c
                                   FROM Alert__c WHERE Contract_Line__c = :cl.Id
                                   AND Type_Alerte__c = 'Surfacturation'];
        System.assertEquals(1, alertes.size(), 'Une alerte Surfacturation doit être créée');
        System.assertEquals('Surfacturation', alertes[0].Type_Alerte__c);
        System.assertEquals('Nouvelle', alertes[0].Statut__c);
        System.assert(alertes[0].Seuil_Depasse__c > 0, 'Le seuil dépassé doit être > 0');
    }

    @isTest
    static void testAlerteProvisionDepassee_restantSousSeuilDe20Pct() {
        Contract_Line__c cl = creerLigneContrat();

        Test.startTest();
        insert new Consumption__c(
            Contract_Line__c    = cl.Id,
            Montant_Achete__c   = 100,
            Montant_Consomme__c = 85 // restant formule = 100-85 = 15 < 20% de 100 → Provision_Depassee
        );
        Test.stopTest();

        List<Alert__c> alertes = [SELECT Type_Alerte__c FROM Alert__c
                                   WHERE Contract_Line__c = :cl.Id
                                   AND Type_Alerte__c = 'Provision_Depassee'];
        System.assertEquals(1, alertes.size(), 'Une alerte Provision_Depassee doit être créée');
    }

    @isTest
    static void testAlerteConsommationAnormale_consommeSuperieureUneVirguleCinqFoisMoyenne() {
        Contract_Line__c cl = creerLigneContrat();

        Test.startTest();
        insert new Consumption__c(
            Contract_Line__c        = cl.Id,
            Montant_Achete__c       = 500,
            Montant_Consomme__c     = 200, // 200 > 100 × 1.5 = 150 → Consommation_Anormale
            Consommation_Moyenne__c = 100
        );
        Test.stopTest();

        List<Alert__c> alertes = [SELECT Type_Alerte__c FROM Alert__c
                                   WHERE Contract_Line__c = :cl.Id
                                   AND Type_Alerte__c = 'Consommation_Anormale'];
        System.assertEquals(1, alertes.size(), 'Une alerte Consommation_Anormale doit être créée');
    }

    @isTest
    static void testPasDoublonAlerte_alerteExistanteNonReouverte() {
        Contract_Line__c cl = creerLigneContrat();
        insert new Alert__c(
            Contract_Line__c = cl.Id, Type_Alerte__c = 'Surfacturation',
            Statut__c = 'Nouvelle', Date_Alerte__c = Date.today(),
            Message__c = 'Alerte existante'
        );

        Test.startTest();
        insert new Consumption__c(
            Contract_Line__c    = cl.Id,
            Montant_Achete__c   = 100,
            Montant_Consomme__c = 150
        );
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Alert__c
                         WHERE Contract_Line__c = :cl.Id AND Type_Alerte__c = 'Surfacturation'];
        System.assertEquals(1, count, 'Pas de doublon si une alerte Surfacturation est déjà ouverte');
    }

    @isTest
    static void testConsommationNormale_aucuneAlerte() {
        Contract_Line__c cl = creerLigneContrat();

        Test.startTest();
        insert new Consumption__c(
            Contract_Line__c        = cl.Id,
            Montant_Achete__c       = 100,
            Montant_Consomme__c     = 50, // restant formule = 50 ≥ 20% de 100, pas de surfacturation
            Consommation_Moyenne__c = 40  // 50 < 40 × 1.5 = 60 → pas d'anomalie
        );
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Alert__c WHERE Contract_Line__c = :cl.Id];
        System.assertEquals(0, count, 'Aucune alerte pour une consommation normale');
    }

    @isTest
    static void testUpdateConsommation_declencheAlerteApresModification() {
        Contract_Line__c cl = creerLigneContrat();
        Consumption__c conso = new Consumption__c(
            Contract_Line__c    = cl.Id,
            Montant_Achete__c   = 100,
            Montant_Consomme__c = 50
        );
        insert conso;

        Test.startTest();
        conso.Montant_Consomme__c = 150; // passe en surfacturation
        update conso;
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Alert__c
                         WHERE Contract_Line__c = :cl.Id AND Type_Alerte__c = 'Surfacturation'];
        System.assertEquals(1, count, 'L\'update doit déclencher la création d\'une alerte Surfacturation');
    }
}
