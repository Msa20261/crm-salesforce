public with sharing class RdvController {

    // Crée la Task et envoie les emails
    @AuraEnabled
    public static Id creerRdv(String sujet, String description, String dateEcheance,
                               String statut, String priorite, String typeRdv,
                               Id assigneA, Id leadId) {
        Task t = new Task();
        t.Subject     = sujet;
        t.Description = description;
        t.ActivityDate = Date.valueOf(dateEcheance);
        t.Status      = statut;
        t.Priority    = priorite;
        t.Type        = typeRdv;
        t.OwnerId     = assigneA != null ? assigneA : UserInfo.getUserId();
        t.WhoId       = leadId;
        insert t;

        // Crée aussi un Event pour que le RDV apparaisse sur le Calendrier Salesforce
        Event ev = new Event();
        ev.Subject         = sujet;
        ev.Description     = description;
        ev.StartDateTime   = DateTime.valueOf(dateEcheance + ' 09:00:00');
        ev.EndDateTime     = DateTime.valueOf(dateEcheance + ' 10:00:00');
        ev.OwnerId         = assigneA != null ? assigneA : UserInfo.getUserId();
        ev.WhoId           = leadId;
        ev.Type            = typeRdv;
        insert ev;

        try {
            envoyerEmails(assigneA, leadId, sujet, Date.valueOf(dateEcheance));
        } catch (Exception e) {
            System.debug('Envoi email échoué : ' + e.getMessage());
        }

        return t.Id;
    }

    // Retourne la liste des utilisateurs actifs
    @AuraEnabled(cacheable=true)
    public static List<User> getUsers() {
        return [
            SELECT Id, Name, Email
            FROM User
            WHERE IsActive = true
            ORDER BY Name
            LIMIT 100
        ];
    }

    // Envoie un email à l'utilisateur assigné et à la piste
    private static void envoyerEmails(Id userId, Id leadId, String sujet, Date dateRdv) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        String dateFormatee = dateRdv.format();
        String sujetEmail   = 'RDV planifié : ' + sujet + ' — ' + dateFormatee;

        // Email à l'utilisateur assigné
        if (userId != null) {
            User u = [SELECT Name, Email FROM User WHERE Id = :userId LIMIT 1];
            if (u.Email != null) {
                Messaging.SingleEmailMessage emailUser = new Messaging.SingleEmailMessage();
                emailUser.setSenderDisplayName('CRM Upmind Ludwig');
                emailUser.setToAddresses(new List<String>{ u.Email });
                emailUser.setSubject(sujetEmail);
                emailUser.setPlainTextBody(
                    'Bonjour ' + u.Name + ',\n\n' +
                    'Un rendez-vous vous a été assigné dans le CRM Upmind Ludwig.\n\n' +
                    'Sujet  : ' + sujet + '\n' +
                    'Date   : ' + dateFormatee + '\n\n' +
                    'Connectez-vous sur Salesforce pour voir les détails.\n\n' +
                    'Cordialement,\nCRM Upmind Ludwig'
                );
                emails.add(emailUser);
            }
        }

        // Email à la piste
        Lead l = [SELECT FirstName, LastName, Email FROM Lead WHERE Id = :leadId LIMIT 1];
        if (l.Email != null) {
            Messaging.SingleEmailMessage emailLead = new Messaging.SingleEmailMessage();
            emailLead.setSenderDisplayName('CRM Upmind Ludwig');
            emailLead.setToAddresses(new List<String>{ l.Email });
            emailLead.setSubject('Confirmation de rendez-vous — ' + sujet);
            emailLead.setPlainTextBody(
                'Bonjour ' + (l.FirstName != null ? l.FirstName : l.LastName) + ',\n\n' +
                'Nous vous confirmons un rendez-vous.\n\n' +
                'Sujet : ' + sujet + '\n' +
                'Date  : ' + dateFormatee + '\n\n' +
                'N\'hésitez pas à nous contacter pour toute question.\n\n' +
                'Cordialement,\nL\'équipe Upmind'
            );
            emails.add(emailLead);
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
}
