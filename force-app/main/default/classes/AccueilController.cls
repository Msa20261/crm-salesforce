public with sharing class AccueilController {

    // ===== KPI =====
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getKPI() {
        Date debutMois = Date.today().toStartOfMonth();

        Integer nbLeads = [SELECT COUNT() FROM Lead WHERE CreatedDate >= :debutMois AND IsConverted = false];
        Integer nbOpps  = [SELECT COUNT() FROM Opportunity WHERE IsClosed = false];
        Integer nbContrats = [SELECT COUNT() FROM Contract WHERE Status = 'Activated'];
        Integer nbTaches = [SELECT COUNT() FROM Task WHERE OwnerId = :UserInfo.getUserId() AND Status != 'Completed' AND ActivityDate = TODAY];

        Map<String, Integer> kpi = new Map<String, Integer>();
        kpi.put('leads', nbLeads);
        kpi.put('opportunites', nbOpps);
        kpi.put('contrats', nbContrats);
        kpi.put('taches', nbTaches);
        return kpi;
    }

    // ===== ACTIVITE RECENTE =====
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getActiviteRecente() {
        List<Map<String, String>> activites = new List<Map<String, String>>();

        for (Lead l : [SELECT Id, Name, Status, CreatedDate FROM Lead
                       WHERE OwnerId = :UserInfo.getUserId()
                       ORDER BY CreatedDate DESC LIMIT 3]) {
            Map<String, String> m = new Map<String, String>();
            m.put('id', l.Id);
            m.put('nom', l.Name);
            m.put('type', 'Lead');
            m.put('statut', l.Status);
            m.put('date', String.valueOf(l.CreatedDate.date()));
            m.put('icone', 'standard:lead');
            activites.add(m);
        }

        for (Opportunity o : [SELECT Id, Name, StageName, CloseDate FROM Opportunity
                              WHERE OwnerId = :UserInfo.getUserId()
                              ORDER BY LastModifiedDate DESC LIMIT 3]) {
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

    // ===== TACHES DU JOUR =====
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getTachesJour() {
        List<Map<String, String>> taches = new List<Map<String, String>>();

        for (Task t : [SELECT Id, Subject, Priority, Status, ActivityDate FROM Task
                       WHERE OwnerId = :UserInfo.getUserId()
                       AND Status != 'Completed'
                       AND ActivityDate <= TODAY
                       ORDER BY Priority DESC, ActivityDate ASC LIMIT 5]) {
            Map<String, String> m = new Map<String, String>();
            m.put('id', t.Id);
            m.put('sujet', t.Subject);
            m.put('priorite', t.Priority);
            m.put('statut', t.Status);
            m.put('date', t.ActivityDate != null ? String.valueOf(t.ActivityDate) : '');
            taches.add(m);
        }

        return taches;
    }
}
