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

        List<OrgWideEmailAddress> oweaList = [SELECT Id, Address FROM OrgWideEmailAddress WHERE IsAllowAllProfiles = true ORDER BY Address LIMIT 5];
        Id oweaId = null;
        for (OrgWideEmailAddress o : oweaList) {
            if (o.Address.contains('upmind.fr')) { oweaId = o.Id; break; }
        }
        if (oweaId == null && !oweaList.isEmpty()) oweaId = oweaList[0].Id;

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

                String html = htmlEntete('CRM Upmind Ludwig') +
                    '<p style="color:#333;font-size:16px;margin-top:0;">Bonjour ' + u.Name + ',</p>' +
                    '<p style="color:#555;">' + intro + '</p>' +
                    '<div style="background:#f4f6f9;border-left:4px solid #1B3A6B;padding:16px;margin:24px 0;border-radius:0 4px 4px 0;">' +
                    '<p style="margin:6px 0;color:#333;"><strong>Sujet :</strong> ' + sujet + '</p>' +
                    '<p style="margin:6px 0;color:#333;"><strong>Date :</strong> ' + dateFormatee + '</p>' +
                    '</div>' +
                    '<p style="color:#555;">Connectez-vous sur Salesforce pour voir les détails.</p>' +
                    '<p style="color:#555;margin-bottom:0;">Cordialement,<br><strong>CRM Upmind Ludwig</strong></p>' +
                    htmlPied();

                Messaging.SingleEmailMessage emailUser = new Messaging.SingleEmailMessage();
                if (oweaId != null) emailUser.setOrgWideEmailAddressId(oweaId);
                emailUser.setToAddresses(new List<String>{ u.Email });
                emailUser.setSubject(sujetEmail);
                emailUser.setHtmlBody(html);
                emailUser.setPlainTextBody('Bonjour ' + u.Name + ',\n\n' + intro + '\n\nSujet : ' + sujet + '\nDate  : ' + dateFormatee + '\n\nConnectez-vous sur Salesforce pour voir les détails.\n\nCordialement,\nCRM Upmind Ludwig');
                emails.add(emailUser);
            }
        }

        Lead l = [SELECT FirstName, LastName, Email FROM Lead WHERE Id = :leadId LIMIT 1];
        if (l.Email != null) {
            String prenom = l.FirstName != null ? l.FirstName : l.LastName;
            String html = htmlEntete('Confirmation de rendez-vous') +
                '<p style="color:#333;font-size:16px;margin-top:0;">Bonjour ' + prenom + ',</p>' +
                '<p style="color:#555;">Nous vous confirmons votre rendez-vous avec notre équipe.</p>' +
                '<div style="background:#f4f6f9;border-left:4px solid #1B3A6B;padding:16px;margin:24px 0;border-radius:0 4px 4px 0;">' +
                '<p style="margin:6px 0;color:#333;"><strong>Sujet :</strong> ' + sujet + '</p>' +
                '<p style="margin:6px 0;color:#333;"><strong>Date :</strong> ' + dateFormatee + '</p>' +
                '</div>' +
                '<p style="color:#555;">N\'hésitez pas à nous contacter pour toute question.</p>' +
                '<p style="color:#555;margin-bottom:0;">Cordialement,<br><strong>L\'équipe Upmind</strong></p>' +
                htmlPied();

            Messaging.SingleEmailMessage emailLead = new Messaging.SingleEmailMessage();
            if (oweaId != null) emailLead.setOrgWideEmailAddressId(oweaId);
            emailLead.setToAddresses(new List<String>{ l.Email });
            emailLead.setSubject('Confirmation de rendez-vous — ' + sujet);
            emailLead.setHtmlBody(html);
            emailLead.setPlainTextBody('Bonjour ' + prenom + ',\n\nNous vous confirmons un rendez-vous.\n\nSujet : ' + sujet + '\nDate  : ' + dateFormatee + '\n\nN\'hésitez pas à nous contacter pour toute question.\n\nCordialement,\nL\'équipe Upmind');
            emails.add(emailLead);
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

    private static String htmlEntete(String titre) {
        return '<html><body style="margin:0;padding:0;background:#f4f6f9;font-family:Arial,Helvetica,sans-serif;">' +
            '<table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:30px 20px;">' +
            '<table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,0.1);">' +
            '<tr><td style="background:#1B3A6B;padding:24px;text-align:center;border-radius:8px 8px 0 0;">' +
            '<h1 style="color:#fff;margin:0;font-size:22px;">' + titre + '</h1>' +
            '</td></tr><tr><td style="padding:32px;">';
    }

    private static String htmlPied() {
        return '</td></tr>' +
            '<tr><td style="background:#f4f6f9;padding:16px;text-align:center;border-top:1px solid #e8e8e8;border-radius:0 0 8px 8px;">' +
            '<p style="color:#aaa;font-size:12px;margin:0;">CRM Upmind Ludwig &mdash; Ne pas répondre à cet email</p>' +
            '</td></tr></table></td></tr></table></body></html>';
    }
}
