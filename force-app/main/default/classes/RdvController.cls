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
            envoyerEmails(assigneA, leadId, sujet, Date.valueOf(dateEcheance), UserInfo.getUserId());
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

    // Envoie un email à l'utilisateur assigné, au créateur du RDV et à la piste
    private static void envoyerEmails(Id assigneId, Id leadId, String sujet, Date dateRdv, Id createurId) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        String dateFormatee = dateRdv.format();
        String sujetEmail   = 'RDV planifié : ' + sujet + ' — ' + dateFormatee;

        // Adresse expéditeur vérifiée dans l'org (priorité upmind.fr, sinon première disponible)
        List<OrgWideEmailAddress> oweaList = [SELECT Id, Address FROM OrgWideEmailAddress WHERE IsAllowAllProfiles = true ORDER BY Address LIMIT 5];
        Id oweaId = null;
        for (OrgWideEmailAddress o : oweaList) {
            if (o.Address.contains('upmind.fr')) { oweaId = o.Id; break; }
        }
        if (oweaId == null && !oweaList.isEmpty()) oweaId = oweaList[0].Id;

        // Collecte les IDs des utilisateurs internes à notifier (assigné + créateur, sans doublons)
        Set<Id> userIds = new Set<Id>();
        if (assigneId != null) userIds.add(assigneId);
        if (createurId != null) userIds.add(createurId);

        if (!userIds.isEmpty()) {
            List<User> users = [SELECT Id, Name, Email FROM User WHERE Id IN :userIds AND IsActive = true];
            for (User u : users) {
                if (u.Email == null) continue;
                Boolean estAssigne = (u.Id == assigneId);
                Boolean estCreateur = (u.Id == createurId);
                String intro = estAssigne && !estCreateur
                    ? 'Un rendez-vous vous a été assigné dans le CRM Upmind Ludwig.'
                    : estCreateur && !estAssigne
                        ? 'Vous avez créé un rendez-vous dans le CRM Upmind Ludwig.'
                        : 'Vous avez créé et êtes assigné à ce rendez-vous dans le CRM Upmind Ludwig.';

                Messaging.SingleEmailMessage emailUser = new Messaging.SingleEmailMessage();
                if (oweaId != null) emailUser.setOrgWideEmailAddressId(oweaId);
                emailUser.setToAddresses(new List<String>{ u.Email });
                emailUser.setSubject(sujetEmail);
                emailUser.setPlainTextBody(
                    'Bonjour ' + u.Name + ',\n\n' +
                    intro + '\n\n' +
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
            if (oweaId != null) emailLead.setOrgWideEmailAddressId(oweaId);
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
