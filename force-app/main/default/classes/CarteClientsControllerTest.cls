@isTest
private class CarteClientsControllerTest {

    @isTest
    static void testGetAccountsAvecContrat_retourneCompteEtNbContrats() {
        Account a = new Account(
            Name = 'Compte Carte Client',
            BillingCity = 'Lyon', BillingStreet = '3 Quai des Brotteaux',
            BillingPostalCode = '69006', BillingCountry = 'France'
        );
        insert a;
        insert new Contract(AccountId = a.Id, StartDate = Date.today(), ContractTerm = 12);

        Test.startTest();
        List<CarteClientsController.AccountInfo> result = CarteClientsController.getAccountsAvecContrat();
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Un seul compte avec contrat');
        System.assertEquals('Compte Carte Client', result[0].nom);
        System.assertEquals('Lyon', result[0].ville);
        System.assertEquals('3 Quai des Brotteaux', result[0].rue);
        System.assertEquals(1, result[0].nbContrats);
    }

    @isTest
    static void testGetAccountsAvecContrat_multipleContrats() {
        Account a = new Account(Name = 'Compte Multi Contrats', BillingCity = 'Paris');
        insert a;
        insert new List<Contract>{
            new Contract(AccountId = a.Id, StartDate = Date.today(), ContractTerm = 12),
            new Contract(AccountId = a.Id, StartDate = Date.today(), ContractTerm = 6)
        };

        Test.startTest();
        List<CarteClientsController.AccountInfo> result = CarteClientsController.getAccountsAvecContrat();
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(2, result[0].nbContrats, 'Doit compter 2 contrats');
    }

    @isTest
    static void testGetAccountsAvecContrat_paysTitleCase() {
        Account a = new Account(Name = 'Compte Allemagne', BillingCity = 'Berlin',
                                BillingCountry = 'ALLEMAGNE');
        insert a;
        insert new Contract(AccountId = a.Id, StartDate = Date.today(), ContractTerm = 12);

        Test.startTest();
        List<CarteClientsController.AccountInfo> result = CarteClientsController.getAccountsAvecContrat();
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('Allemagne', result[0].pays, 'Le pays doit être normalisé en Title Case');
    }

    @isTest
    static void testGetAccountsAvecContrat_compteSansAdresse_aAdresseFalse() {
        Account a = new Account(Name = 'Compte Sans Adresse GPS');
        insert a;
        insert new Contract(AccountId = a.Id, StartDate = Date.today(), ContractTerm = 12);

        Test.startTest();
        List<CarteClientsController.AccountInfo> result = CarteClientsController.getAccountsAvecContrat();
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(false, result[0].aAdresse, 'aAdresse doit être false sans ville ni coordonnées');
    }

    @isTest
    static void testGetAccountsAvecContrat_compteAvecVille_aAdresseTrue() {
        Account a = new Account(Name = 'Compte Avec Ville', BillingCity = 'Nantes');
        insert a;
        insert new Contract(AccountId = a.Id, StartDate = Date.today(), ContractTerm = 12);

        Test.startTest();
        List<CarteClientsController.AccountInfo> result = CarteClientsController.getAccountsAvecContrat();
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].aAdresse, 'aAdresse doit être true si la ville est renseignée');
    }

    @isTest
    static void testGetAccountsAvecContrat_sansContrat_retourneListeVide() {
        insert new Account(Name = 'Compte Seul Sans Contrat', BillingCity = 'Marseille');

        Test.startTest();
        List<CarteClientsController.AccountInfo> result = CarteClientsController.getAccountsAvecContrat();
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Aucun compte sans contrat ne doit être retourné');
    }
}
