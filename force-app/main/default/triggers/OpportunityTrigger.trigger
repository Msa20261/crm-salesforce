trigger OpportunityTrigger on Opportunity (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isUpdate) {
            // Marquer les adresses changées AVANT que handleBeforeInsertUpdate les écrase avec l'adresse du compte
            GeocodageOpportunityHandler.marquerChangements(Trigger.new, Trigger.oldMap);
        }
        OpportunityTriggerHandler.handleBeforeInsertUpdate(Trigger.new);
    }
    if (Trigger.isAfter) {
        if (Trigger.isUpdate) {
            OpportunityTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
        GeocodageOpportunityHandler.planifierGeocodage(
            Trigger.new,
            Trigger.isInsert ? null : Trigger.oldMap
        );
    }
}
