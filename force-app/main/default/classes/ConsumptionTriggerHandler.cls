public with sharing class ConsumptionTriggerHandler {

    // Seuil : alerte si le solde restant tombe sous 20% du montant acheté
    private static final Decimal SEUIL_PROVISION_PCT = 20;

    public static void handleAfterInsertUpdate(List<Consumption__c> consumptions) {

        // Récupère les Contract_Line__c concernés
        Set<Id> contractLineIds = new Set<Id>();
        for (Consumption__c c : consumptions) {
            if (c.Contract_Line__c != null) contractLineIds.add(c.Contract_Line__c);
        }

        // Charge les alertes déjà ouvertes pour éviter les doublons
        Map<String, Boolean> alertesExistantes = new Map<String, Boolean>();
        for (Alert__c a : [
            SELECT Contract_Line__c, Type_Alerte__c
            FROM Alert__c
            WHERE Contract_Line__c IN :contractLineIds
            AND Statut__c != 'Résolue'
        ]) {
            alertesExistantes.put(a.Contract_Line__c + '_' + a.Type_Alerte__c, true);
        }

        // Récupère contrat, propriétaire contrat, propriétaire compte et AccountId
        Map<Id, String> contractLineToOwnerEmail    = new Map<Id, String>();
        Map<Id, String> contractLineToOwnerName     = new Map<Id, String>();
        Map<Id, String> contractLineToContractName  = new Map<Id, String>();
        Map<Id, String> contractLineToAccountOwnerEmail = new Map<Id, String>();
        Map<Id, String> contractLineToAccountOwnerName  = new Map<Id, String>();
        Map<Id, Id>     contractLineToAccountId         = new Map<Id, Id>();

        // Map contract line → Set d'User IDs pour les notifications cloche
        Map<Id, Set<Id>> contractLineToUserIds = new Map<Id, Set<Id>>();

        for (Contract_Line__c cl : [
            SELECT Id, Contract__r.OwnerId, Contract__r.Owner.Email, Contract__r.Owner.Name, Contract__r.Name,
                   Contract__r.AccountId,
                   Contract__r.Account.OwnerId, Contract__r.Account.Owner.Email, Contract__r.Account.Owner.Name
            FROM Contract_Line__c
            WHERE Id IN :contractLineIds
        ]) {
            contractLineToOwnerEmail.put(cl.Id, cl.Contract__r.Owner.Email);
            contractLineToOwnerName.put(cl.Id, cl.Contract__r.Owner.Name);
            contractLineToContractName.put(cl.Id, cl.Contract__r.Name);
            if (cl.Contract__r.AccountId != null) {
                contractLineToAccountId.put(cl.Id, cl.Contract__r.AccountId);
            }
            if (cl.Contract__r.Account.Owner.Email != null) {
                contractLineToAccountOwnerEmail.put(cl.Id, cl.Contract__r.Account.Owner.Email);
                contractLineToAccountOwnerName.put(cl.Id, cl.Contract__r.Account.Owner.Name);
            }
            // Collecte les User IDs pour les notifications cloche
            Set<Id> uids = new Set<Id>();
            if (cl.Contract__r.OwnerId != null)         uids.add(cl.Contract__r.OwnerId);
            if (cl.Contract__r.Account.OwnerId != null)  uids.add(cl.Contract__r.Account.OwnerId);
            contractLineToUserIds.put(cl.Id, uids);
        }

        // Récupère les contacts (avec email) associés aux comptes
        Set<Id> accountIds = new Set<Id>(contractLineToAccountId.values());
        Map<Id, List<Contact>> accountToContacts = new Map<Id, List<Contact>>();
        for (Contact ct : [
            SELECT Id, FirstName, LastName, Email, AccountId
            FROM Contact
            WHERE AccountId IN :accountIds AND Email != null
        ]) {
            if (!accountToContacts.containsKey(ct.AccountId)) {
                accountToContacts.put(ct.AccountId, new List<Contact>());
            }
            accountToContacts.get(ct.AccountId).add(ct);
        }

        // Construit la map Contract_Line → liste de contacts
        Map<Id, List<Contact>> contractLineToContacts = new Map<Id, List<Contact>>();
        for (Id clId : contractLineToAccountId.keySet()) {
            Id accId = contractLineToAccountId.get(clId);
            if (accountToContacts.containsKey(accId)) {
                contractLineToContacts.put(clId, accountToContacts.get(accId));
            }
        }

        // Récupère aussi l'email du créateur de la consommation (user connecté)
        String createurEmail = UserInfo.getUserEmail();
        String createurName  = UserInfo.getName();

        List<Alert__c> alertesACreer = new List<Alert__c>();
        // Stocke les messages à envoyer par email : clé = ownerEmail, valeur = liste de messages
        Map<String, List<String>> emailsAEnvoyer = new Map<String, List<String>>();
        Map<String, String> ownerNames = new Map<String, String>();

        for (Consumption__c c : consumptions) {
            if (c.Contract_Line__c == null) continue;

            Decimal achete   = c.Montant_Achete__c   != null ? c.Montant_Achete__c   : 0;
            Decimal consomme = c.Montant_Consomme__c != null ? c.Montant_Consomme__c : 0;
            Decimal restant  = c.Montant_Restant__c  != null ? c.Montant_Restant__c  : achete - consomme;
            Decimal moyenne  = c.Consommation_Moyenne__c != null ? c.Consommation_Moyenne__c : 0;

            String ownerEmail        = contractLineToOwnerEmail.get(c.Contract_Line__c);
            String ownerName         = contractLineToOwnerName.get(c.Contract_Line__c);
            String contractName      = contractLineToContractName.get(c.Contract_Line__c);
            String accountOwnerEmail = contractLineToAccountOwnerEmail.get(c.Contract_Line__c);
            String accountOwnerName  = contractLineToAccountOwnerName.get(c.Contract_Line__c);
            List<Contact> contacts   = contractLineToContacts.containsKey(c.Contract_Line__c)
                                       ? contractLineToContacts.get(c.Contract_Line__c)
                                       : new List<Contact>();

            // --- Condition 1 : Surfacturation (Consommé > Acheté) ---
            if (consomme > achete && achete >= 0) {
                String cle = c.Contract_Line__c + '_Surfacturation';
                if (!alertesExistantes.containsKey(cle)) {
                    Decimal pct = achete > 0 ? ((consomme - achete) / achete * 100).setScale(1) : 100;
                    String msg = 'Surfacturation détectée : ' + consomme.setScale(2) + '€ consommés pour ' + achete.setScale(2) + '€ achetés (dépassement de ' + pct + '%).';
                    alertesACreer.add(new Alert__c(
                        Contract_Line__c = c.Contract_Line__c,
                        Type_Alerte__c   = 'Surfacturation',
                        Statut__c        = 'Nouvelle',
                        Date_Alerte__c   = Date.today(),
                        Seuil_Depasse__c = pct,
                        Message__c       = msg
                    ));
                    alertesExistantes.put(cle, true);
                    ajouterEmail(emailsAEnvoyer, ownerNames, ownerEmail, ownerName, '[SURFACTURATION] ' + contractName + ' — ' + msg);
                    ajouterEmail(emailsAEnvoyer, ownerNames, createurEmail, createurName, '[SURFACTURATION] ' + contractName + ' — ' + msg);
                    ajouterEmail(emailsAEnvoyer, ownerNames, accountOwnerEmail, accountOwnerName, '[SURFACTURATION] ' + contractName + ' — ' + msg);
                    for (Contact ct : contacts) ajouterEmail(emailsAEnvoyer, ownerNames, ct.Email, (ct.FirstName != null ? ct.FirstName + ' ' : '') + ct.LastName, '[SURFACTURATION] ' + contractName + ' — ' + msg);
                }
            }

            // --- Condition 2 : Provision dépassée (Restant < 20% de l'acheté) ---
            if (achete > 0 && restant < (achete * SEUIL_PROVISION_PCT / 100)) {
                String cle = c.Contract_Line__c + '_Provision_Depassee';
                if (!alertesExistantes.containsKey(cle)) {
                    Decimal pctRestant = (restant / achete * 100).setScale(1);
                    String msg = 'Solde insuffisant : ' + restant.setScale(2) + '€ restants (' + pctRestant + '% du budget). Seuil d\'alerte : ' + SEUIL_PROVISION_PCT + '%.';
                    alertesACreer.add(new Alert__c(
                        Contract_Line__c = c.Contract_Line__c,
                        Type_Alerte__c   = 'Provision_Depassee',
                        Statut__c        = 'Nouvelle',
                        Date_Alerte__c   = Date.today(),
                        Seuil_Depasse__c = SEUIL_PROVISION_PCT - pctRestant,
                        Message__c       = msg
                    ));
                    alertesExistantes.put(cle, true);
                    ajouterEmail(emailsAEnvoyer, ownerNames, ownerEmail, ownerName, '[PROVISION DÉPASSÉE] ' + contractName + ' — ' + msg);
                    ajouterEmail(emailsAEnvoyer, ownerNames, createurEmail, createurName, '[PROVISION DÉPASSÉE] ' + contractName + ' — ' + msg);
                    ajouterEmail(emailsAEnvoyer, ownerNames, accountOwnerEmail, accountOwnerName, '[PROVISION DÉPASSÉE] ' + contractName + ' — ' + msg);
                    for (Contact ct : contacts) ajouterEmail(emailsAEnvoyer, ownerNames, ct.Email, (ct.FirstName != null ? ct.FirstName + ' ' : '') + ct.LastName, '[PROVISION DÉPASSÉE] ' + contractName + ' — ' + msg);
                }
            }

            // --- Condition 3 : Consommation anormale (Consommé > Moyenne × 1.5) ---
            if (moyenne > 0 && consomme > moyenne * 1.5) {
                String cle = c.Contract_Line__c + '_Consommation_Anormale';
                if (!alertesExistantes.containsKey(cle)) {
                    Decimal seuilMoyenne = (moyenne * 1.5).setScale(2);
                    Decimal pct = ((consomme - seuilMoyenne) / seuilMoyenne * 100).setScale(1);
                    String msg = 'Consommation anormale : ' + consomme.setScale(2) + '€ consommés, soit ' + pct + '% au-dessus de 1.5× la moyenne (' + seuilMoyenne + '€).';
                    alertesACreer.add(new Alert__c(
                        Contract_Line__c = c.Contract_Line__c,
                        Type_Alerte__c   = 'Consommation_Anormale',
                        Statut__c        = 'Nouvelle',
                        Date_Alerte__c   = Date.today(),
                        Seuil_Depasse__c = pct,
                        Message__c       = msg
                    ));
                    alertesExistantes.put(cle, true);
                    ajouterEmail(emailsAEnvoyer, ownerNames, ownerEmail, ownerName, '[CONSOMMATION ANORMALE] ' + contractName + ' — ' + msg);
                    ajouterEmail(emailsAEnvoyer, ownerNames, createurEmail, createurName, '[CONSOMMATION ANORMALE] ' + contractName + ' — ' + msg);
                    ajouterEmail(emailsAEnvoyer, ownerNames, accountOwnerEmail, accountOwnerName, '[CONSOMMATION ANORMALE] ' + contractName + ' — ' + msg);
                    for (Contact ct : contacts) ajouterEmail(emailsAEnvoyer, ownerNames, ct.Email, (ct.FirstName != null ? ct.FirstName + ' ' : '') + ct.LastName, '[CONSOMMATION ANORMALE] ' + contractName + ' — ' + msg);
                }
            }
        }

        if (!alertesACreer.isEmpty()) {
            insert alertesACreer;
            envoyerNotifications(alertesACreer, contractLineToUserIds);
        }

        if (!emailsAEnvoyer.isEmpty()) {
            envoyerEmails(emailsAEnvoyer, ownerNames);
        }
    }

    private static void envoyerNotifications(List<Alert__c> alertes, Map<Id, Set<Id>> contractLineToUserIds) {
        try {
            List<CustomNotificationType> types = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Alerte_Consommation' LIMIT 1];
            if (types.isEmpty()) return;
            String notifTypeId = types[0].Id;

            for (Alert__c a : alertes) {
                Set<Id> userIds = contractLineToUserIds.get(a.Contract_Line__c);
                if (userIds == null || userIds.isEmpty()) continue;

                Set<String> recipientIds = new Set<String>();
                for (Id uid : userIds) recipientIds.add(String.valueOf(uid));

                String titre = a.Type_Alerte__c == 'Surfacturation'
                    ? 'Surfacturation détectée'
                    : a.Type_Alerte__c == 'Provision_Depassee'
                        ? 'Solde insuffisant'
                        : 'Consommation anormale';

                Messaging.CustomNotification notif = new Messaging.CustomNotification();
                notif.setNotificationTypeId(notifTypeId);
                notif.setTitle(titre);
                notif.setBody(a.Message__c);
                notif.setTargetId(a.Id);
                notif.send(recipientIds);
            }
        } catch (Exception e) {
            System.debug('Envoi notification cloche échoué : ' + e.getMessage());
        }
    }

    private static void ajouterEmail(Map<String, List<String>> emailsMap, Map<String, String> namesMap,
                                      String email, String name, String message) {
        if (email == null) return;
        if (!emailsMap.containsKey(email)) {
            emailsMap.put(email, new List<String>());
            namesMap.put(email, name != null ? name : email);
        }
        emailsMap.get(email).add(message);
    }

    private static void envoyerEmails(Map<String, List<String>> emailsAEnvoyer, Map<String, String> ownerNames) {
        try {
            List<OrgWideEmailAddress> owea = [SELECT Id FROM OrgWideEmailAddress WHERE IsAllowAllProfiles = true ORDER BY Address LIMIT 5];
            Id oweaId = null;
            for (OrgWideEmailAddress o : owea) { oweaId = o.Id; break; }

            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            for (String email : emailsAEnvoyer.keySet()) {
                List<String> alertes = emailsAEnvoyer.get(email);
                String nom = ownerNames.get(email);

                String corps = 'Bonjour ' + nom + ',\n\n';
                corps += alertes.size() == 1
                    ? 'Une nouvelle alerte a été générée dans le CRM Upmind Ludwig :\n\n'
                    : alertes.size() + ' nouvelles alertes ont été générées dans le CRM Upmind Ludwig :\n\n';
                for (String alerte : alertes) {
                    corps += '• ' + alerte + '\n';
                }
                corps += '\nConnectez-vous sur Salesforce pour consulter et traiter ces alertes.\n\n';
                corps += 'Cordialement,\nCRM Upmind Ludwig';

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                if (oweaId != null) mail.setOrgWideEmailAddressId(oweaId);
                mail.setToAddresses(new List<String>{ email });
                mail.setSubject('🔔 ' + alertes.size() + ' alerte(s) consommation — CRM Upmind Ludwig');
                mail.setPlainTextBody(corps);
                emails.add(mail);
            }

            if (!emails.isEmpty()) Messaging.sendEmail(emails);
        } catch (Exception e) {
            System.debug('Envoi email alerte échoué : ' + e.getMessage());
        }
    }
}
