trigger ConsumptionTrigger on Consumption__c (after insert, after update) {
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        ConsumptionTriggerHandler.handleAfterInsertUpdate(Trigger.new);
    }
}
