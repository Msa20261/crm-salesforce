@isTest
private class OpportunityCarteControllerTest {

    @isTest
    static void testGetOpportunitiesAvecAdresse_retourneOppAvecAdresse() {
        Account a = new Account(Name = 'Compte Carte Opp',
                                BillingCity = 'Paris', BillingStreet = '5 Rue de Rivoli',
                                BillingPostalCode = '75001');
        insert a;
        // Insert avant startTest : le @future géocodage s'exécutera après le test (hors contexte)
        insert new Opportunity(
            Name = 'Opp Carte Paris', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30), AccountId = a.Id
        );

        Test.startTest();
        List<OpportunityCarteController.OppInfo> result = OpportunityCarteController.getOpportunitiesAvecAdresse();
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Une opportunité avec adresse doit être retournée');
        System.assertEquals('Opp Carte Paris', result[0].nom);
        System.assertEquals('Paris', result[0].ville);
        System.assertEquals('5 Rue de Rivoli', result[0].rue);
        System.assertEquals('Compte Carte Opp', result[0].compteNom);
        System.assertEquals(Date.today().year(), result[0].anneeCreation);
    }

    @isTest
    static void testGetOpportunitiesAvecAdresse_oppSansAdresse_exclue() {
        Account a = new Account(Name = 'Compte Sans Adresse Carte');
        insert a; // Pas de BillingCity ni BillingStreet
        insert new Opportunity(
            Name = 'Opp Sans Adresse', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30), AccountId = a.Id
        );

        Test.startTest();
        List<OpportunityCarteController.OppInfo> result = OpportunityCarteController.getOpportunitiesAvecAdresse();
        Test.stopTest();

        for (OpportunityCarteController.OppInfo info : result) {
            System.assertNotEquals('Opp Sans Adresse', info.nom,
                'Les opportunités sans adresse ne doivent pas être retournées');
        }
    }

    @isTest
    static void testGetOpportunitiesAvecAdresse_champsMappesCorrectement() {
        Account a = new Account(Name = 'Compte Mapping',
                                BillingCity = 'Lyon', BillingPostalCode = '69001');
        insert a;
        insert new Opportunity(
            Name = 'Opp Mapping', StageName = 'Qualification',
            CloseDate = Date.today().addDays(60), Amount = 25000,
            AccountId = a.Id
        );

        Test.startTest();
        List<OpportunityCarteController.OppInfo> result = OpportunityCarteController.getOpportunitiesAvecAdresse();
        Test.stopTest();

        System.assertEquals(1, result.size());
        OpportunityCarteController.OppInfo info = result[0];
        System.assertEquals('Qualification', info.stageName);
        System.assertEquals(25000, info.montant);
        System.assertEquals(a.Id, info.compteId);
        System.assertNotEquals(null, info.dateCloture);
    }
}
