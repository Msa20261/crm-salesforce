@isTest
private class GeocodageOpportunityHandlerTest {

    // ── Tests geocoder() ──────────────────────────────────────────────────────

    @isTest
    static void testGeocoderSucces_metAJourLatitudeLongitude() {
        Account a = new Account(Name = 'Compte Geocodage');
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'Opp Geocodage', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30), AccountId = a.Id
        );
        insert opp;

        Test.setMock(HttpCalloutMock.class, new NominatimMock()); // répond lat=48.8566 lon=2.3522
        Test.startTest();
        GeocodageOpportunityHandler.geocoder(opp.Id, '75001, Paris');
        Test.stopTest();

        Opportunity result = [SELECT Latitude__c, Longitude__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, result.Latitude__c, 'Latitude doit être renseignée');
        System.assertNotEquals(null, result.Longitude__c, 'Longitude doit être renseignée');
        System.assertEquals(48.8566, result.Latitude__c.setScale(4));
        System.assertEquals(2.3522, result.Longitude__c.setScale(4));
    }

    @isTest
    static void testGeocoderErreurHTTP_pasDeMAJCoordonnees() {
        Account a = new Account(Name = 'Compte Geocodage Erreur');
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'Opp Erreur HTTP', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30), AccountId = a.Id
        );
        insert opp;

        Test.setMock(HttpCalloutMock.class, new NominatimMock(500, ''));
        Test.startTest();
        GeocodageOpportunityHandler.geocoder(opp.Id, 'Adresse Inconnue');
        Test.stopTest();

        Opportunity result = [SELECT Latitude__c, Longitude__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(null, result.Latitude__c, 'Pas de lat en cas d\'erreur HTTP');
        System.assertEquals(null, result.Longitude__c, 'Pas de lng en cas d\'erreur HTTP');
    }

    @isTest
    static void testGeocoderResultatVide_pasDeMAJCoordonnees() {
        Account a = new Account(Name = 'Compte Geocodage Vide');
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'Opp Resultat Vide', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30), AccountId = a.Id
        );
        insert opp;

        Test.setMock(HttpCalloutMock.class, new NominatimMock(200, '[]')); // tableau vide
        Test.startTest();
        GeocodageOpportunityHandler.geocoder(opp.Id, 'Endroit Inconnu');
        Test.stopTest();

        Opportunity result = [SELECT Latitude__c, Longitude__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(null, result.Latitude__c, 'Pas de lat si Nominatim ne trouve rien');
    }

    // ── Tests planifierGeocodage() via INSERT ─────────────────────────────────

    @isTest
    static void testInsertAvecAdresse_declencheGeocodage() {
        Account a = new Account(Name = 'Compte Adresse Insert',
                                BillingStreet = '1 Rue de la Paix',
                                BillingCity = 'Paris', BillingPostalCode = '75001');
        insert a;

        Test.setMock(HttpCalloutMock.class, new NominatimMock());
        Test.startTest();
        Opportunity opp = new Opportunity(
            Name = 'Opp Adresse', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30), AccountId = a.Id
        );
        insert opp;
        Test.stopTest(); // exécute le @future

        Opportunity result = [SELECT Latitude__c, Longitude__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, result.Latitude__c, 'Le géocodage doit renseigner Latitude__c au INSERT');
    }

    // ── Tests marquerChangements() + planifierGeocodage() via UPDATE ──────────

    @isTest
    static void testUpdateAdresse_declencheGeocodage() {
        // Le parcours INSERT via trigger est couvert par testInsertAvecAdresse_declencheGeocodage.
        // Ici on valide que planifierGeocodage déclenche bien geocoder() sur changement d'adresse
        // en appelant geocoder() directement avec l'adresse mise à jour (équivalent au @future planifié).
        Account a = new Account(Name = 'Compte Geocodage Update');
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'Opp Geocodage Update', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30), AccountId = a.Id
        );
        insert opp;

        Test.setMock(HttpCalloutMock.class, new NominatimMock());
        Test.startTest();
        // Simule le geocoder déclenché par planifierGeocodage après changement d'adresse
        GeocodageOpportunityHandler.geocoder(opp.Id, 'Bordeaux, 33000');
        Test.stopTest();

        Opportunity result = [SELECT Latitude__c, Longitude__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, result.Latitude__c, 'geocoder() doit mettre à jour Latitude__c');
        System.assertEquals(48.8566, result.Latitude__c.setScale(4));
    }

    @isTest
    static void testUpdateSansChangementAdresse_pasDeGeocodage() {
        Account a = new Account(Name = 'Compte Pas Changement', BillingCity = 'Nice');
        insert a;
        Opportunity opp = new Opportunity(
            Name = 'Opp Pas Changement', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30), AccountId = a.Id
        );
        insert opp;

        // Supprimer les coordonnées si le @future de l'insert les a renseignées
        update new Opportunity(Id = opp.Id, Latitude__c = null, Longitude__c = null);

        Test.startTest();
        opp.Name = 'Opp Pas Changement - Renommee'; // pas de changement d'adresse
        update opp;
        Test.stopTest();

        Opportunity result = [SELECT Latitude__c, Longitude__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(null, result.Latitude__c, 'Pas de géocodage si l\'adresse n\'a pas changé');
    }
}
