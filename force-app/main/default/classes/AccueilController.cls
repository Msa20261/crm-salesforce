public with sharing class AccueilController {
  // ===== KPI =====
  @AuraEnabled(cacheable=true)
  public static Map<String, Integer> getKPI() {
    Date debutMois = Date.today().toStartOfMonth();

    Integer nbLeads = [
      SELECT COUNT()
      FROM Lead
      WHERE CreatedDate >= :debutMois AND IsConverted = FALSE
    ];
    Integer nbOpps = [SELECT COUNT() FROM Opportunity WHERE IsClosed = FALSE];
    Integer nbContrats = [
      SELECT COUNT()
      FROM Contract
      WHERE Status = 'Activated'
    ];
    Integer nbTaches = [
      SELECT COUNT()
      FROM Task
      WHERE
        OwnerId = :UserInfo.getUserId()
        AND Status != 'Completed'
        AND ActivityDate = TODAY
    ];
    Integer nbComptesRendus = [
      SELECT COUNT()
      FROM Compte_Rendu_RDV__c
      WHERE Date_RDV__c >= :debutMois
    ];

    Map<String, Integer> kpi = new Map<String, Integer>();
    kpi.put('leads', nbLeads);
    kpi.put('opportunites', nbOpps);
    kpi.put('contrats', nbContrats);
    kpi.put('taches', nbTaches);
    kpi.put('comptesRendus', nbComptesRendus);
    return kpi;
  }

  // ===== ACTIVITE RECENTE =====
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getActiviteRecente() {
    List<Map<String, String>> activites = new List<Map<String, String>>();

    for (Lead l : [
      SELECT Id, Name, Status, CreatedDate
      FROM Lead
      WHERE OwnerId = :UserInfo.getUserId()
      ORDER BY CreatedDate DESC
      LIMIT 3
    ]) {
      Map<String, String> m = new Map<String, String>();
      m.put('id', l.Id);
      m.put('nom', l.Name);
      m.put('type', 'Lead');
      m.put('statut', l.Status);
      m.put('date', String.valueOf(l.CreatedDate.date()));
      m.put('icone', 'standard:lead');
      activites.add(m);
    }

    for (Opportunity o : [
      SELECT Id, Name, StageName, CloseDate
      FROM Opportunity
      WHERE OwnerId = :UserInfo.getUserId()
      ORDER BY LastModifiedDate DESC
      LIMIT 3
    ]) {
      Map<String, String> m = new Map<String, String>();
      m.put('id', o.Id);
      m.put('nom', o.Name);
      m.put('type', 'Opportunité');
      m.put('statut', o.StageName);
      m.put('date', String.valueOf(o.CloseDate));
      m.put('icone', 'standard:opportunity');
      activites.add(m);
    }

    return activites;
  }

  // ===== ALERTES SUR MES COMPTES/CONTRATS =====
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getMesAlertes() {
    Id uid = UserInfo.getUserId();
    List<Map<String, String>> alertes = new List<Map<String, String>>();

    for (Alert__c al : [
      SELECT
        Id,
        Type_Alerte__c,
        Message__c,
        Date_Alerte__c,
        Contract__c,
        Contract__r.Account.Name,
        Contract_Line__c,
        Contract_Line__r.Contract__r.Account.Name
      FROM Alert__c
      WHERE
        Statut__c = 'Nouvelle'
        AND (Contract__r.OwnerId = :uid
        OR Contract__r.Account.OwnerId = :uid
        OR Contract_Line__r.Contract__r.OwnerId = :uid
        OR Contract_Line__r.Contract__r.Account.OwnerId = :uid)
      ORDER BY Date_Alerte__c DESC
      LIMIT 5
    ]) {
      Map<String, String> m = new Map<String, String>();
      m.put('id', al.Id);
      m.put('type', al.Type_Alerte__c);
      m.put('message', al.Message__c);
      m.put(
        'date',
        al.Date_Alerte__c != null ? String.valueOf(al.Date_Alerte__c) : ''
      );
      m.put(
        'compte',
        al.Contract__c != null
          ? al.Contract__r.Account.Name
          : al.Contract_Line__r.Contract__r.Account.Name
      );
      alertes.add(m);
    }

    return alertes;
  }

  // ===== OPPORTUNITES OUVERTES SUR COMPTES SOUS CONTRAT ACTIF (UPSELL) =====
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getOpportunitesUpsell() {
    List<Map<String, String>> opps = new List<Map<String, String>>();

    for (Opportunity o : [
      SELECT Id, Name, StageName, Amount, Account.Name
      FROM Opportunity
      WHERE
        OwnerId = :UserInfo.getUserId()
        AND IsClosed = FALSE
        AND AccountId IN (
          SELECT AccountId
          FROM Contract
          WHERE Status = 'Activated'
        )
      ORDER BY CloseDate ASC
      LIMIT 5
    ]) {
      Map<String, String> m = new Map<String, String>();
      m.put('id', o.Id);
      m.put('nom', o.Name);
      m.put('compte', o.Account.Name);
      m.put('stage', o.StageName);
      m.put(
        'montant',
        o.Amount != null ? String.valueOf(o.Amount.setScale(0)) : '0'
      );
      opps.add(m);
    }

    return opps;
  }

  // ===== TACHES DU JOUR =====
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getTachesJour() {
    List<Map<String, String>> taches = new List<Map<String, String>>();

    for (Task t : [
      SELECT Id, Subject, Priority, Status, ActivityDate
      FROM Task
      WHERE
        OwnerId = :UserInfo.getUserId()
        AND Status != 'Completed'
        AND ActivityDate <= TODAY
      ORDER BY Priority DESC, ActivityDate ASC
      LIMIT 5
    ]) {
      Map<String, String> m = new Map<String, String>();
      m.put('id', t.Id);
      m.put('sujet', t.Subject);
      m.put('priorite', t.Priority);
      m.put('statut', t.Status);
      m.put(
        'date',
        t.ActivityDate != null ? String.valueOf(t.ActivityDate) : ''
      );
      taches.add(m);
    }

    return taches;
  }
}
