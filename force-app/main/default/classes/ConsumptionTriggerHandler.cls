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

        List<Alert__c> alertesACreer = new List<Alert__c>();

        for (Consumption__c c : consumptions) {
            if (c.Contract_Line__c == null) continue;

            Decimal achete   = c.Montant_Achete__c   != null ? c.Montant_Achete__c   : 0;
            Decimal consomme = c.Montant_Consomme__c != null ? c.Montant_Consomme__c : 0;
            Decimal restant  = c.Montant_Restant__c  != null ? c.Montant_Restant__c  : achete - consomme;
            Decimal moyenne  = c.Consommation_Moyenne__c != null ? c.Consommation_Moyenne__c : 0;

            // --- Condition 1 : Surfacturation (Consommé > Acheté) ---
            if (consomme > achete && achete >= 0) {
                String cle = c.Contract_Line__c + '_Surfacturation';
                if (!alertesExistantes.containsKey(cle)) {
                    Decimal pct = achete > 0 ? ((consomme - achete) / achete * 100).setScale(1) : 100;
                    alertesACreer.add(new Alert__c(
                        Contract_Line__c = c.Contract_Line__c,
                        Type_Alerte__c   = 'Surfacturation',
                        Statut__c        = 'Nouvelle',
                        Date_Alerte__c   = Date.today(),
                        Seuil_Depasse__c = pct,
                        Message__c       = 'Surfacturation détectée : ' + consomme.setScale(2) + '€ consommés pour ' + achete.setScale(2) + '€ achetés (dépassement de ' + pct + '%).'
                    ));
                    alertesExistantes.put(cle, true);
                }
            }

            // --- Condition 2 : Provision dépassée (Restant < 20% de l'acheté) ---
            if (achete > 0 && restant < (achete * SEUIL_PROVISION_PCT / 100)) {
                String cle = c.Contract_Line__c + '_Provision_Depassee';
                if (!alertesExistantes.containsKey(cle)) {
                    Decimal pctRestant = (restant / achete * 100).setScale(1);
                    alertesACreer.add(new Alert__c(
                        Contract_Line__c = c.Contract_Line__c,
                        Type_Alerte__c   = 'Provision_Depassee',
                        Statut__c        = 'Nouvelle',
                        Date_Alerte__c   = Date.today(),
                        Seuil_Depasse__c = SEUIL_PROVISION_PCT - pctRestant,
                        Message__c       = 'Solde insuffisant : ' + restant.setScale(2) + '€ restants (' + pctRestant + '% du budget). Seuil d\'alerte : ' + SEUIL_PROVISION_PCT + '%.'
                    ));
                    alertesExistantes.put(cle, true);
                }
            }

            // --- Condition 3 : Consommation anormale (Consommé > Moyenne × 1.5) ---
            if (moyenne > 0 && consomme > moyenne * 1.5) {
                String cle = c.Contract_Line__c + '_Consommation_Anormale';
                if (!alertesExistantes.containsKey(cle)) {
                    Decimal seuilMoyenne = (moyenne * 1.5).setScale(2);
                    Decimal pct = ((consomme - seuilMoyenne) / seuilMoyenne * 100).setScale(1);
                    alertesACreer.add(new Alert__c(
                        Contract_Line__c = c.Contract_Line__c,
                        Type_Alerte__c   = 'Consommation_Anormale',
                        Statut__c        = 'Nouvelle',
                        Date_Alerte__c   = Date.today(),
                        Seuil_Depasse__c = pct,
                        Message__c       = 'Consommation anormale : ' + consomme.setScale(2) + '€ consommés, soit ' + pct + '% au-dessus de 1.5× la moyenne (' + seuilMoyenne + '€).'
                    ));
                    alertesExistantes.put(cle, true);
                }
            }
        }

        if (!alertesACreer.isEmpty()) {
            insert alertesACreer;
        }
    }
}
