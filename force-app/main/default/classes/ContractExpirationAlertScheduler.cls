public with sharing class ContractExpirationAlertScheduler implements Schedulable {
  // Seuils : préavis à 60 jours, alerte urgente à 30 jours avant l'échéance
  private static final Integer PREAVIS_JOURS = 60;
  private static final Integer IMMINENTE_JOURS = 30;

  public void execute(SchedulableContext ctx) {
    verifierEcheances();
  }

  public static void verifierEcheances() {
    Date aujourdhui = Date.today();
    Date limitePreavis = aujourdhui.addDays(PREAVIS_JOURS);

    List<Contract> contrats = [
      SELECT
        Id,
        ContractNumber,
        EndDate,
        OwnerId,
        Owner.Email,
        Owner.Name,
        AccountId,
        Account.OwnerId,
        Account.Owner.Email,
        Account.Owner.Name
      FROM Contract
      WHERE
        Status = 'Activated'
        AND EndDate != NULL
        AND EndDate >= :aujourdhui
        AND EndDate <= :limitePreavis
    ];
    if (contrats.isEmpty())
      return;

    Set<Id> contractIds = new Set<Id>();
    for (Contract c : contrats)
      contractIds.add(c.Id);

    // Alertes déjà ouvertes, pour éviter les doublons
    Map<String, Boolean> alertesExistantes = new Map<String, Boolean>();
    for (Alert__c a : [
      SELECT Contract__c, Type_Alerte__c
      FROM Alert__c
      WHERE Contract__c IN :contractIds AND Statut__c != 'Résolue'
    ]) {
      alertesExistantes.put(a.Contract__c + '_' + a.Type_Alerte__c, true);
    }

    // Contacts avec email, par compte
    Set<Id> accountIds = new Set<Id>();
    for (Contract c : contrats)
      if (c.AccountId != null)
        accountIds.add(c.AccountId);
    Map<Id, List<Contact>> accountToContacts = new Map<Id, List<Contact>>();
    for (Contact ct : [
      SELECT Id, FirstName, LastName, Email, AccountId
      FROM Contact
      WHERE AccountId IN :accountIds AND Email != NULL
    ]) {
      if (!accountToContacts.containsKey(ct.AccountId))
        accountToContacts.put(ct.AccountId, new List<Contact>());
      accountToContacts.get(ct.AccountId).add(ct);
    }

    List<Alert__c> alertesACreer = new List<Alert__c>();
    Map<Id, Set<Id>> contractToUserIds = new Map<Id, Set<Id>>();
    Map<String, List<String>> emailsAEnvoyer = new Map<String, List<String>>();
    Map<String, String> nomsDestinataires = new Map<String, String>();

    for (Contract c : contrats) {
      Integer joursRestants = aujourdhui.daysBetween(c.EndDate);
      String type = joursRestants <= IMMINENTE_JOURS
        ? 'Fin_Contrat_Imminente'
        : 'Preavis_Fin_Contrat';
      String cle = c.Id + '_' + type;
      if (alertesExistantes.containsKey(cle))
        continue;

      String msg =
        'Le contrat ' +
        c.ContractNumber +
        ' arrive à échéance le ' +
        c.EndDate.format() +
        ' (dans ' +
        joursRestants +
        ' jours).';
      alertesACreer.add(
        new Alert__c(
          Contract__c = c.Id,
          Type_Alerte__c = type,
          Statut__c = 'Nouvelle',
          Date_Alerte__c = aujourdhui,
          Message__c = msg
        )
      );
      alertesExistantes.put(cle, true);

      Set<Id> uids = new Set<Id>();
      if (c.OwnerId != null)
        uids.add(c.OwnerId);
      if (c.Account.OwnerId != null)
        uids.add(c.Account.OwnerId);
      contractToUserIds.put(c.Id, uids);

      String prefixe = type == 'Fin_Contrat_Imminente'
        ? '[FIN DE CONTRAT IMMINENTE] '
        : '[PRÉAVIS FIN DE CONTRAT] ';
      ajouterEmail(
        emailsAEnvoyer,
        nomsDestinataires,
        c.Owner.Email,
        c.Owner.Name,
        prefixe + msg
      );
      if (c.Account.Owner.Email != null) {
        ajouterEmail(
          emailsAEnvoyer,
          nomsDestinataires,
          c.Account.Owner.Email,
          c.Account.Owner.Name,
          prefixe + msg
        );
      }
      List<Contact> contacts = accountToContacts.containsKey(c.AccountId)
        ? accountToContacts.get(c.AccountId)
        : new List<Contact>();
      for (Contact ct : contacts) {
        ajouterEmail(
          emailsAEnvoyer,
          nomsDestinataires,
          ct.Email,
          (ct.FirstName != null ? ct.FirstName + ' ' : '') + ct.LastName,
          prefixe + msg
        );
      }
    }

    if (!alertesACreer.isEmpty()) {
      insert alertesACreer;
      envoyerNotifications(alertesACreer, contractToUserIds);
    }
    if (!emailsAEnvoyer.isEmpty()) {
      envoyerEmails(emailsAEnvoyer, nomsDestinataires);
    }
  }

  private static void envoyerNotifications(
    List<Alert__c> alertes,
    Map<Id, Set<Id>> contractToUserIds
  ) {
    try {
      List<CustomNotificationType> types = [
        SELECT Id
        FROM CustomNotificationType
        WHERE DeveloperName = 'Alerte_Contrat'
        LIMIT 1
      ];
      if (types.isEmpty())
        return;
      String notifTypeId = types[0].Id;

      for (Alert__c a : alertes) {
        Set<Id> userIds = contractToUserIds.get(a.Contract__c);
        if (userIds == null || userIds.isEmpty())
          continue;

        Set<String> recipientIds = new Set<String>();
        for (Id uid : userIds)
          recipientIds.add(String.valueOf(uid));

        String titre = a.Type_Alerte__c == 'Fin_Contrat_Imminente'
          ? 'Fin de contrat imminente'
          : 'Préavis fin de contrat';

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

  private static void ajouterEmail(
    Map<String, List<String>> emailsMap,
    Map<String, String> namesMap,
    String email,
    String name,
    String message
  ) {
    if (email == null)
      return;
    if (!emailsMap.containsKey(email)) {
      emailsMap.put(email, new List<String>());
      namesMap.put(email, name != null ? name : email);
    }
    emailsMap.get(email).add(message);
  }

  private static void envoyerEmails(
    Map<String, List<String>> emailsAEnvoyer,
    Map<String, String> noms
  ) {
    try {
      List<OrgWideEmailAddress> oweaList = [
        SELECT Id, Address
        FROM OrgWideEmailAddress
        WHERE IsAllowAllProfiles = TRUE
        ORDER BY Address
        LIMIT 5
      ];
      Id oweaId = null;
      for (OrgWideEmailAddress o : oweaList) {
        if (o.Address.contains('upmind.fr')) {
          oweaId = o.Id;
          break;
        }
      }
      if (oweaId == null && !oweaList.isEmpty())
        oweaId = oweaList[0].Id;

      List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
      for (String email : emailsAEnvoyer.keySet()) {
        List<String> alertes = emailsAEnvoyer.get(email);
        String nom = noms.get(email);
        String nbAlertes = alertes.size() == 1
          ? 'Une alerte de fin de contrat a été générée'
          : alertes.size() + ' alertes de fin de contrat ont été générées';

        String html =
          htmlEntete() +
          '<p style="color:#333;font-size:16px;margin-top:0;">Bonjour ' +
          nom +
          ',</p>' +
          '<p style="color:#555;">' +
          nbAlertes +
          ' dans le CRM Upmind Ludwig :</p>';
        for (String alerte : alertes) {
          String couleur = alerte.startsWith('[FIN DE CONTRAT IMMINENTE]')
            ? '#C62828'
            : '#1B5E9E';
          String bg = alerte.startsWith('[FIN DE CONTRAT IMMINENTE]')
            ? '#FFEBEE'
            : '#E8F0FA';
          html +=
            '<div style="border-left:4px solid ' +
            couleur +
            ';background:' +
            bg +
            ';padding:12px 16px;margin:8px 0;border-radius:0 4px 4px 0;">' +
            '<p style="margin:0;color:#333;font-size:14px;">' +
            alerte +
            '</p>' +
            '</div>';
        }
        html +=
          '<p style="color:#555;margin-top:24px;">Connectez-vous sur Salesforce pour consulter et traiter ces alertes.</p>' +
          '<p style="color:#555;margin-bottom:0;">Cordialement,<br><strong>CRM Upmind Ludwig</strong></p>' +
          htmlPied();

        String texte =
          'Bonjour ' +
          nom +
          ',\n\n' +
          nbAlertes +
          ' dans le CRM Upmind Ludwig :\n\n';
        for (String alerte : alertes) {
          texte += '• ' + alerte + '\n';
        }
        texte += '\nConnectez-vous sur Salesforce pour consulter et traiter ces alertes.\n\nCordialement,\nCRM Upmind Ludwig';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        if (oweaId != null)
          mail.setOrgWideEmailAddressId(oweaId);
        mail.setToAddresses(new List<String>{ email });
        mail.setSubject(
          '[ALERTE] ' +
            alertes.size() +
            ' alerte(s) fin de contrat — CRM Upmind Ludwig'
        );
        mail.setHtmlBody(html);
        mail.setPlainTextBody(texte);
        emails.add(mail);
      }

      if (!emails.isEmpty())
        Messaging.sendEmail(emails);
    } catch (Exception e) {
      System.debug(
        'Envoi email alerte fin de contrat échoué : ' + e.getMessage()
      );
    }
  }

  private static String htmlEntete() {
    return '<html><body style="margin:0;padding:0;background:#f4f6f9;font-family:Arial,Helvetica,sans-serif;">' +
      '<table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:30px 20px;">' +
      '<table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,0.1);">' +
      '<tr><td style="background:#1B3A6B;padding:24px;text-align:center;border-radius:8px 8px 0 0;">' +
      '<h1 style="color:#fff;margin:0;font-size:22px;">Alertes Fin de Contrat</h1>' +
      '<p style="color:#a8c4e8;margin:4px 0 0 0;font-size:14px;">CRM Upmind Ludwig</p>' +
      '</td></tr><tr><td style="padding:32px;">';
  }

  private static String htmlPied() {
    return '</td></tr>' +
      '<tr><td style="background:#f4f6f9;padding:16px;text-align:center;border-top:1px solid #e8e8e8;border-radius:0 0 8px 8px;">' +
      '<p style="color:#aaa;font-size:12px;margin:0;">CRM Upmind Ludwig &mdash; Ne pas répondre à cet email</p>' +
      '</td></tr></table></td></tr></table></body></html>';
  }
}
