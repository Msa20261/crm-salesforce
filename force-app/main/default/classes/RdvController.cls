public with sharing class RdvController {
  // ─── CRÉER RDV : Event (calendrier) + Task (reminder) ─────────────────────

  @AuraEnabled
  public static Id creerRdv(
    String sujet,
    String description,
    String dateEcheance,
    String heureDebut,
    String heureFin,
    String statut,
    String priorite,
    String typeRdv,
    Id assigneA,
    Id leadId
  ) {
    Id ownerId = assigneA != null ? assigneA : UserInfo.getUserId();

    // Query lead une seule fois pour nom + email (réutilisé dans emails)
    Lead leadRec = null;
    String nomLead = '';
    if (leadId != null) {
      leadRec = [
        SELECT FirstName, LastName, Email
        FROM Lead
        WHERE Id = :leadId
        LIMIT 1
      ];
      nomLead = ((leadRec.FirstName != null ? leadRec.FirstName + ' ' : '') +
        leadRec.LastName)
        .trim();
    }

    String sujetComplet = String.isNotBlank(nomLead)
      ? sujet + ' — ' + nomLead
      : sujet;
    String hDebut = String.isNotBlank(heureDebut) ? heureDebut : '09:00';
    String hFin = String.isNotBlank(heureFin) ? heureFin : '10:00';

    // Event → visible dans le Calendrier Salesforce + sync Einstein Activity Capture / Outlook
    Event ev = new Event();
    ev.Subject = sujetComplet;
    ev.Description = description;
    ev.StartDateTime = DateTime.valueOf(dateEcheance + ' ' + hDebut + ':00');
    ev.EndDateTime = DateTime.valueOf(dateEcheance + ' ' + hFin + ':00');
    ev.OwnerId = ownerId;
    ev.WhoId = leadId;
    ev.Type = typeRdv;

    // Task → reminder de réaliser le RDV (apparaît dans les activités à faire)
    Task t = new Task();
    t.Subject = 'RDV à réaliser : ' + sujetComplet;
    t.Description = description;
    t.ActivityDate = Date.valueOf(dateEcheance);
    t.Status = statut;
    t.Priority = priorite;
    t.Type = typeRdv;
    t.OwnerId = ownerId;
    t.WhoId = leadId;

    // 1 seul DML pour les deux objets
    insert new List<SObject>{ ev, t };

    try {
      envoyerEmails(
        assigneA,
        leadRec,
        sujet,
        Date.valueOf(dateEcheance),
        UserInfo.getUserId(),
        hDebut,
        hFin
      );
    } catch (Exception e) {
      System.debug('Envoi email RDV échoué : ' + e.getMessage());
    }

    return ev.Id;
  }

  // ─── CRÉER COMPTE RENDU : Task complétée (standard) ───────────────────────

  @AuraEnabled
  public static Id creerCompteRendu(
    Id leadId,
    String notes,
    String typeRdv,
    String avecQui,
    String interetDetecte,
    String prochaineAction,
    String dateProchaineAction
  ) {
    String nomLead = '';
    Lead leadRec = null;
    if (leadId != null) {
      leadRec = [
        SELECT FirstName, LastName, Email
        FROM Lead
        WHERE Id = :leadId
        LIMIT 1
      ];
      nomLead = ((leadRec.FirstName != null ? leadRec.FirstName + ' ' : '') +
        leadRec.LastName)
        .trim();
    }

    // Corps structuré stocké dans Description de la Task
    List<String> parts = new List<String>();
    if (String.isNotBlank(avecQui))
      parts.add('Avec : ' + avecQui);
    if (String.isNotBlank(typeRdv))
      parts.add('Type : ' + typeRdv);
    if (String.isNotBlank(interetDetecte))
      parts.add('Intérêt détecté : ' + interetDetecte);
    if (String.isNotBlank(notes))
      parts.add('Compte rendu :\n' + notes);
    if (String.isNotBlank(prochaineAction))
      parts.add('Prochaine action : ' + prochaineAction);
    if (String.isNotBlank(dateProchaineAction))
      parts.add('Date prochaine action : ' + dateProchaineAction);

    Task cr = new Task();
    cr.Subject = 'CR — ' + nomLead;
    cr.Status = 'Completed';
    cr.Priority = 'Normal';
    cr.Type = typeRdv;
    cr.WhoId = leadId;
    cr.OwnerId = UserInfo.getUserId();
    cr.ActivityDate = Date.today();
    cr.Description = String.join(parts, '\n\n');
    insert cr;

    try {
      envoyerEmailRecapCR(leadRec, typeRdv);
    } catch (Exception e) {
      System.debug('Envoi email récap CR échoué : ' + e.getMessage());
    }

    return cr.Id;
  }

  // ─── DERNIER RDV DU LEAD (pour pré-remplir le CR) ─────────────────────────

  @AuraEnabled(cacheable=true)
  public static Map<String, String> getDernierRdvLead(Id leadId) {
    Map<String, String> result = new Map<String, String>();
    List<Event> events = [
      SELECT Id, Subject, StartDateTime, EndDateTime, Type
      FROM Event
      WHERE WhoId = :leadId
      ORDER BY StartDateTime DESC
      LIMIT 1
    ];
    if (!events.isEmpty()) {
      Event ev = events[0];
      result.put('date', String.valueOf(ev.StartDateTime.date()));
      result.put('type', ev.Type != null ? ev.Type : '');
      result.put('sujet', ev.Subject != null ? ev.Subject : '');
      result.put(
        'heureDebut',
        ev.StartDateTime != null ? ev.StartDateTime.format('HH:mm') : ''
      );
      result.put(
        'heureFin',
        ev.EndDateTime != null ? ev.EndDateTime.format('HH:mm') : ''
      );
    }
    return result;
  }

  // ─── UTILISATEURS ACTIFS ───────────────────────────────────────────────────

  @AuraEnabled(cacheable=true)
  public static List<User> getUsers() {
    return [
      SELECT Id, Name, Email
      FROM User
      WHERE IsActive = TRUE
      ORDER BY Name
      LIMIT 100
    ];
  }

  // ─── EMAILS NOTIFICATION RDV ───────────────────────────────────────────────

  private static void envoyerEmails(
    Id assigneId,
    Lead leadRec,
    String sujet,
    Date dateRdv,
    Id createurId,
    String heureDebut,
    String heureFin
  ) {
    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    String dateFormatee = dateRdv.format();
    String horaire = heureDebut + ' – ' + heureFin;
    String sujetEmail = 'RDV planifié : ' + sujet + ' — ' + dateFormatee;
    Id oweaId = getOweaUpmindId();

    // Emails aux utilisateurs (assigné + créateur)
    Set<Id> userIds = new Set<Id>();
    if (assigneId != null)
      userIds.add(assigneId);
    if (createurId != null)
      userIds.add(createurId);

    if (!userIds.isEmpty()) {
      for (User u : [
        SELECT Id, Name, Email
        FROM User
        WHERE Id IN :userIds AND IsActive = TRUE
      ]) {
        if (u.Email == null)
          continue;
        Boolean estAssigne = (u.Id == assigneId);
        Boolean estCreateur = (u.Id == createurId);
        String intro = estAssigne && !estCreateur
          ? 'Un rendez-vous vous a été assigné dans le CRM Upmind Ludwig.'
          : estCreateur && !estAssigne
              ? 'Vous avez créé un rendez-vous dans le CRM Upmind Ludwig.'
              : 'Vous avez créé et êtes assigné à ce rendez-vous dans le CRM Upmind Ludwig.';

        String html =
          htmlEntete('CRM Upmind Ludwig') +
          '<p style="color:#333;font-size:16px;margin-top:0;">Bonjour ' +
          u.Name +
          ',</p>' +
          '<p style="color:#555;">' +
          intro +
          '</p>' +
          '<div style="background:#f4f6f9;border-left:4px solid #1B3A6B;padding:16px;margin:24px 0;border-radius:0 4px 4px 0;">' +
          '<p style="margin:6px 0;color:#333;"><strong>Sujet :</strong> ' +
          sujet +
          '</p>' +
          '<p style="margin:6px 0;color:#333;"><strong>Date :</strong> ' +
          dateFormatee +
          '</p>' +
          '<p style="margin:6px 0;color:#333;"><strong>Horaire :</strong> ' +
          horaire +
          '</p>' +
          '</div>' +
          '<p style="color:#555;">Connectez-vous sur Salesforce pour voir les détails.</p>' +
          '<p style="color:#555;margin-bottom:0;">Cordialement,<br><strong>CRM Upmind Ludwig</strong></p>' +
          htmlPied();

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        if (oweaId != null)
          mail.setOrgWideEmailAddressId(oweaId);
        mail.setToAddresses(new List<String>{ u.Email });
        mail.setSubject(sujetEmail);
        mail.setHtmlBody(html);
        mail.setPlainTextBody(
          'Bonjour ' +
            u.Name +
            ',\n\n' +
            intro +
            '\n\nSujet   : ' +
            sujet +
            '\nDate    : ' +
            dateFormatee +
            '\nHoraire : ' +
            horaire +
            '\n\nConnectez-vous sur Salesforce.\n\nCordialement,\nCRM Upmind Ludwig'
        );
        emails.add(mail);
      }
    }

    // Email de confirmation au lead
    if (leadRec != null && leadRec.Email != null) {
      String prenom = leadRec.FirstName != null
        ? leadRec.FirstName
        : leadRec.LastName;
      String html =
        htmlEntete('Confirmation de rendez-vous') +
        '<p style="color:#333;font-size:16px;margin-top:0;">Bonjour ' +
        prenom +
        ',</p>' +
        '<p style="color:#555;">Nous vous confirmons votre rendez-vous avec notre équipe.</p>' +
        '<div style="background:#f4f6f9;border-left:4px solid #1B3A6B;padding:16px;margin:24px 0;border-radius:0 4px 4px 0;">' +
        '<p style="margin:6px 0;color:#333;"><strong>Sujet :</strong> ' +
        sujet +
        '</p>' +
        '<p style="margin:6px 0;color:#333;"><strong>Date :</strong> ' +
        dateFormatee +
        '</p>' +
        '<p style="margin:6px 0;color:#333;"><strong>Horaire :</strong> ' +
        horaire +
        '</p>' +
        '</div>' +
        '<p style="color:#555;">N\'hésitez pas à nous contacter pour toute question.</p>' +
        '<p style="color:#555;margin-bottom:0;">Cordialement,<br><strong>L\'équipe Upmind</strong></p>' +
        htmlPied();

      Messaging.SingleEmailMessage mailLead = new Messaging.SingleEmailMessage();
      if (oweaId != null)
        mailLead.setOrgWideEmailAddressId(oweaId);
      mailLead.setToAddresses(new List<String>{ leadRec.Email });
      mailLead.setSubject('Confirmation de rendez-vous — ' + sujet);
      mailLead.setHtmlBody(html);
      mailLead.setPlainTextBody(
        'Bonjour ' +
          prenom +
          ',\n\nNous vous confirmons un rendez-vous.' +
          '\n\nSujet   : ' +
          sujet +
          '\nDate    : ' +
          dateFormatee +
          '\nHoraire : ' +
          horaire +
          '\n\nCordialement,\nL\'équipe Upmind'
      );
      emails.add(mailLead);
    }

    if (!emails.isEmpty())
      Messaging.sendEmail(emails);
  }

  // ─── EMAIL RÉCAP CR AU LEAD (sans les notes internes) ──────────────────────

  private static void envoyerEmailRecapCR(Lead leadRec, String typeRdv) {
    if (leadRec == null || leadRec.Email == null)
      return;

    String prenom = leadRec.FirstName != null
      ? leadRec.FirstName
      : leadRec.LastName;
    String dateFormatee = Date.today().format();
    Id oweaId = getOweaUpmindId();

    String html =
      htmlEntete('Récapitulatif de notre rendez-vous') +
      '<p style="color:#333;font-size:16px;margin-top:0;">Bonjour ' +
      prenom +
      ',</p>' +
      '<p style="color:#555;">Nous vous remercions pour le temps accordé lors de notre échange.</p>' +
      '<div style="background:#f4f6f9;border-left:4px solid #1B3A6B;padding:16px;margin:24px 0;border-radius:0 4px 4px 0;">' +
      '<p style="margin:6px 0;color:#333;"><strong>Date :</strong> ' +
      dateFormatee +
      '</p>' +
      (String.isNotBlank(typeRdv)
        ? '<p style="margin:6px 0;color:#333;"><strong>Type :</strong> ' +
          typeRdv +
          '</p>'
        : '') +
      '</div>' +
      '<p style="color:#555;">Notre équipe reviendra vers vous prochainement. N\'hésitez pas à nous contacter pour toute question.</p>' +
      '<p style="color:#555;margin-bottom:0;">Cordialement,<br><strong>L\'équipe Upmind</strong></p>' +
      htmlPied();

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    if (oweaId != null)
      mail.setOrgWideEmailAddressId(oweaId);
    mail.setToAddresses(new List<String>{ leadRec.Email });
    mail.setSubject('Récapitulatif de notre rendez-vous');
    mail.setHtmlBody(html);
    mail.setPlainTextBody(
      'Bonjour ' +
        prenom +
        ',\n\nNous vous remercions pour le temps accordé lors de notre échange.' +
        '\n\nDate : ' +
        dateFormatee +
        (String.isNotBlank(typeRdv) ? '\nType : ' + typeRdv : '') +
        '\n\nNotre équipe reviendra vers vous prochainement.' +
        '\n\nCordialement,\nL\'équipe Upmind'
    );
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
  }

  // ─── ORG-WIDE EMAIL ADDRESS (préférence upmind.fr) ─────────────────────────

  private static Id getOweaUpmindId() {
    List<OrgWideEmailAddress> oweaList = [
      SELECT Id, Address
      FROM OrgWideEmailAddress
      WHERE IsAllowAllProfiles = TRUE
      ORDER BY Address
      LIMIT 5
    ];
    for (OrgWideEmailAddress o : oweaList) {
      if (o.Address.contains('upmind.fr')) {
        return o.Id;
      }
    }
    return oweaList.isEmpty() ? null : oweaList[0].Id;
  }

  // ─── TEMPLATES EMAIL ───────────────────────────────────────────────────────

  private static String htmlEntete(String titre) {
    return '<html><body style="margin:0;padding:0;background:#f4f6f9;font-family:Arial,Helvetica,sans-serif;">' +
      '<table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:30px 20px;">' +
      '<table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,0.1);">' +
      '<tr><td style="background:#1B3A6B;padding:24px;text-align:center;border-radius:8px 8px 0 0;">' +
      '<h1 style="color:#fff;margin:0;font-size:22px;">' +
      titre +
      '</h1>' +
      '</td></tr><tr><td style="padding:32px;">';
  }

  private static String htmlPied() {
    return '</td></tr>' +
      '<tr><td style="background:#f4f6f9;padding:16px;text-align:center;border-top:1px solid #e8e8e8;border-radius:0 0 8px 8px;">' +
      '<p style="color:#aaa;font-size:12px;margin:0;">CRM Upmind Ludwig &mdash; Ne pas répondre à cet email</p>' +
      '</td></tr></table></td></tr></table></body></html>';
  }
}
