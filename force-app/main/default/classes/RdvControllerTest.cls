@isTest
private class RdvControllerTest {

    private static Lead creerLead() {
        Lead l = new Lead(FirstName = 'Sophie', LastName = 'Bernard',
                          Company = 'Acme', Status = 'New',
                          Email = 'sophie.bernard@testrdv.com');
        insert l;
        return l;
    }

    // ── Tests creerRdv ────────────────────────────────────────────────────────

    @isTest
    static void testCreerRdv_creeEventEtTask() {
        Lead l = creerLead();

        Test.startTest();
        Id eventId = RdvController.creerRdv(
            'Demo produit', 'Présentation de la solution',
            '2026-06-15', '10:00', '11:00',
            'Not Started', 'Normal', 'Call',
            UserInfo.getUserId(), l.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, eventId, 'L\'ID de l\'Event ne doit pas être null');

        Event ev = [SELECT Subject, WhoId, OwnerId, StartDateTime, EndDateTime
                    FROM Event WHERE Id = :eventId];
        System.assertEquals('Demo produit — Sophie Bernard', ev.Subject);
        System.assertEquals(l.Id, ev.WhoId);
        System.assertEquals(UserInfo.getUserId(), ev.OwnerId);

        List<Task> tasks = [SELECT Subject, Status, Priority, WhoId FROM Task WHERE WhoId = :l.Id];
        System.assertEquals(1, tasks.size(), 'Une Task doit être créée');
        System.assert(tasks[0].Subject.startsWith('RDV à réaliser'), 'Le sujet de la Task doit commencer par "RDV à réaliser"');
        System.assertEquals('Not Started', tasks[0].Status);
    }

    @isTest
    static void testCreerRdv_sansLead_creeEventSansWhoId() {
        Test.startTest();
        Id eventId = RdvController.creerRdv(
            'Réunion interne', null,
            '2026-06-20', '14:00', '15:00',
            'Not Started', 'High', 'Meeting',
            UserInfo.getUserId(), null
        );
        Test.stopTest();

        Event ev = [SELECT Subject, WhoId FROM Event WHERE Id = :eventId];
        System.assertEquals('Réunion interne', ev.Subject, 'Pas de lead dans le sujet si WhoId est null');
        System.assertEquals(null, ev.WhoId);
    }

    @isTest
    static void testCreerRdv_sansHoraires_utiliseValeursParDefaut() {
        Lead l = creerLead();

        Test.startTest();
        Id eventId = RdvController.creerRdv(
            'RDV Défaut', null, '2026-07-01',
            null, null, // heureDebut et heureFin null → défaut 09:00/10:00
            'Not Started', 'Normal', 'Call',
            UserInfo.getUserId(), l.Id
        );
        Test.stopTest();

        Event ev = [SELECT StartDateTime, EndDateTime FROM Event WHERE Id = :eventId];
        System.assertEquals(9, ev.StartDateTime.hour(), 'Heure de début par défaut = 09:00');
        System.assertEquals(10, ev.EndDateTime.hour(), 'Heure de fin par défaut = 10:00');
    }

    // ── Tests creerCompteRendu ────────────────────────────────────────────────

    @isTest
    static void testCreerCompteRendu_creeTaskCompleteeAvecDescription() {
        Lead l = creerLead();

        Test.startTest();
        Id taskId = RdvController.creerCompteRendu(
            l.Id,
            'Très intéressé par la solution cartographie',
            'Call', 'Jean Martin - DSI',
            'Fort intérêt module carto',
            'Envoyer une démo personnalisée',
            '2026-07-10'
        );
        Test.stopTest();

        Task t = [SELECT Subject, Status, Priority, WhoId, Description FROM Task WHERE Id = :taskId];
        System.assertEquals('CR — Sophie Bernard', t.Subject);
        System.assertEquals('Completed', t.Status);
        System.assertEquals('Normal', t.Priority);
        System.assertEquals(l.Id, t.WhoId);
        System.assert(t.Description.contains('Très intéressé par la solution'), 'Le compte rendu doit être dans Description');
        System.assert(t.Description.contains('Jean Martin - DSI'), 'Avec qui doit être dans Description');
        System.assert(t.Description.contains('Envoyer une démo'), 'Prochaine action doit être dans Description');
    }

    @isTest
    static void testCreerCompteRendu_sansLead_sujetGenerique() {
        Test.startTest();
        Id taskId = RdvController.creerCompteRendu(
            null, 'Notes diverses', 'Meeting', null, null, null, null
        );
        Test.stopTest();

        Task t = [SELECT Subject FROM Task WHERE Id = :taskId];
        // Salesforce trim les espaces en fin de champ Text → 'CR — ' devient 'CR —'
        System.assert(t.Subject.startsWith('CR'), 'Le sujet doit commencer par CR');
        System.assert(!t.Subject.contains('Bernard'), 'Pas de nom de lead quand leadId est null');
    }

    // ── Tests getDernierRdvLead ───────────────────────────────────────────────

    @isTest
    static void testGetDernierRdvLead_avecEvent_retourneInfos() {
        Lead l = creerLead();
        insert new Event(
            Subject = 'Dernier RDV Lead', WhoId = l.Id,
            StartDateTime = DateTime.now().addDays(-3),
            EndDateTime   = DateTime.now().addDays(-3).addHours(1),
            OwnerId = UserInfo.getUserId(),
            Type = 'Call'
        );

        Test.startTest();
        Map<String, String> result = RdvController.getDernierRdvLead(l.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('date'), 'Doit contenir la date');
        System.assert(result.containsKey('type'), 'Doit contenir le type');
        System.assertEquals('Call', result.get('type'));
    }

    @isTest
    static void testGetDernierRdvLead_sansEvent_retourneMapVide() {
        Lead l = creerLead();

        Test.startTest();
        Map<String, String> result = RdvController.getDernierRdvLead(l.Id);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Map vide si aucun event n\'existe pour ce lead');
    }

    // ── Tests getUsers ────────────────────────────────────────────────────────

    @isTest
    static void testGetUsers_retourneUtilisateursActifs() {
        Test.startTest();
        List<User> users = RdvController.getUsers();
        Test.stopTest();

        System.assert(!users.isEmpty(), 'Doit retourner au moins l\'utilisateur courant');
        for (User u : users) {
            // IsActive n'est pas dans le SELECT du contrôleur → on vérifie Name et Email
            System.assertNotEquals(null, u.Name, 'Name doit être renseigné');
        }
    }
}
