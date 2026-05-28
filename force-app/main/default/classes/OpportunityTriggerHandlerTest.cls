@isTest
private class OpportunityTriggerHandlerTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    // Compte SANS adresse : évite les callouts de géocodage
    private static Account creerCompteSansAdresse(String nom) {
        Account a = new Account(Name = nom);
        insert a;
        return a;
    }

    // Produit + entrée pricebook standard pour tester les lignes de contrat
    private static Id creerPricebookEntry() {
        Product2 p = new Product2(Name = 'Produit Test OppHandler', IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id   = p.Id,
            UnitPrice    = 500,
            IsActive     = true
        );
        insert pbe;
        return pbe.Id;
    }

    // ── Tests handleBeforeInsertUpdate ────────────────────────────────────────

    @isTest
    static void testBeforeInsert_copieAdresseFacturationDuCompte() {
        Account a = new Account(Name = 'Compte Avec Adresse',
                                BillingStreet = '10 Rue des Lilas',
                                BillingCity = 'Bordeaux',
                                BillingPostalCode = '33000');
        insert a;

        Test.setMock(HttpCalloutMock.class, new NominatimMock());
        Test.startTest();
        Opportunity opp = new Opportunity(
            Name = 'Opp Copie Adresse', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30), AccountId = a.Id
        );
        insert opp;
        Test.stopTest();

        Opportunity result = [SELECT adresse__Street__s, adresse__City__s, adresse__PostalCode__s
                               FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('10 Rue des Lilas', result.adresse__Street__s);
        System.assertEquals('Bordeaux', result.adresse__City__s);
        System.assertEquals('33000', result.adresse__PostalCode__s);
    }

    @isTest
    static void testBeforeInsert_compteSansAdresse_pasDeCopie() {
        Account a = creerCompteSansAdresse('Compte Vide');
        Opportunity opp = new Opportunity(
            Name = 'Opp Compte Vide', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30), AccountId = a.Id
        );
        insert opp;

        Opportunity result = [SELECT adresse__City__s, adresse__Street__s FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(null, result.adresse__City__s, 'Pas de ville copiée si le compte n\'en a pas');
        System.assertEquals(null, result.adresse__Street__s, 'Pas de rue copiée si le compte n\'en a pas');
    }

    // ── Tests handleAfterUpdate – Closed Won ──────────────────────────────────

    @isTest
    static void testAfterUpdate_closedWon_creeContrat() {
        Account a = creerCompteSansAdresse('Compte Closed Won');
        Opportunity opp = new Opportunity(
            Name = 'Opp A Clore', StageName = 'Prospecting',
            CloseDate = Date.today(), AccountId = a.Id
        );
        insert opp;

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        List<Contract> contrats = [SELECT Id, AccountId, Name, Status FROM Contract
                                   WHERE Opportunity__c = :opp.Id];
        System.assertEquals(1, contrats.size(), 'Un contrat doit être créé au Closed Won');
        System.assertEquals(a.Id, contrats[0].AccountId, 'Le contrat doit être lié au compte de l\'opportunité');
        System.assertEquals('Opp A Clore', contrats[0].Name, 'Le nom du contrat doit correspondre à l\'opportunité');
        System.assertEquals('Draft', contrats[0].Status);

        Opportunity oppMaj = [SELECT ContractId, Contrat_Associe__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(contrats[0].Id, oppMaj.ContractId, 'ContractId doit être stampé sur l\'opp');
        System.assertEquals(contrats[0].Id, oppMaj.Contrat_Associe__c, 'Contrat_Associe__c doit être stampé');
    }

    @isTest
    static void testAfterUpdate_closedWon_avecProduits_creeLignesContrat() {
        Account a = creerCompteSansAdresse('Compte Produits');
        Id pbeId = creerPricebookEntry();

        Opportunity opp = new Opportunity(
            Name = 'Opp Avec Produits', StageName = 'Prospecting',
            CloseDate = Date.today(), AccountId = a.Id,
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert opp;

        insert new OpportunityLineItem(
            OpportunityId    = opp.Id,
            PricebookEntryId = pbeId,
            Quantity         = 3,
            UnitPrice        = 500
        );

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        List<Contract> contrats = [SELECT Id FROM Contract WHERE Opportunity__c = :opp.Id];
        System.assertEquals(1, contrats.size());

        List<Contract_Line__c> lignes = [SELECT Quantite__c, Montant__c, Prix_Unitaire__c
                                         FROM Contract_Line__c WHERE Contract__c = :contrats[0].Id];
        System.assertEquals(1, lignes.size(), 'Une ligne par produit doit être créée');
        System.assertEquals(3, lignes[0].Quantite__c);
        System.assertEquals(1500, lignes[0].Montant__c); // 3 × 500
        System.assertEquals(500, lignes[0].Prix_Unitaire__c);
    }

    @isTest
    static void testAfterUpdate_dejaClosedWon_pasDeDuplication() {
        Account a = creerCompteSansAdresse('Compte Deja Clos');
        // L'opportunité est insérée directement en Closed Won → aucun changement de statut
        Opportunity opp = new Opportunity(
            Name = 'Opp Deja Closed', StageName = 'Closed Won',
            CloseDate = Date.today(), AccountId = a.Id
        );
        insert opp;

        // Un update sans changement de statut ne doit pas créer de contrat
        Test.startTest();
        opp.Name = 'Opp Deja Closed - Renommee';
        update opp;
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Contract WHERE Opportunity__c = :opp.Id];
        System.assertEquals(0, count, 'Pas de contrat si le statut ne change pas vers Closed Won');
    }

    @isTest
    static void testAfterUpdate_pasClosedWon_pasDeContrat() {
        Account a = creerCompteSansAdresse('Compte Pas Clos');
        Opportunity opp = new Opportunity(
            Name = 'Opp Pas Clos', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30), AccountId = a.Id
        );
        insert opp;

        Test.startTest();
        opp.StageName = 'Qualification'; // change de stage mais pas Closed Won
        update opp;
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Contract WHERE Opportunity__c = :opp.Id];
        System.assertEquals(0, count, 'Aucun contrat si le nouveau stage n\'est pas Closed Won');
    }
}
