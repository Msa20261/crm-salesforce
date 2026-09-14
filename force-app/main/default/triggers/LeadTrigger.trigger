trigger LeadTrigger on Lead(before insert, before update) {
  LeadScoringService.avantEnregistrement(
    Trigger.new,
    Trigger.isInsert ? null : Trigger.oldMap
  );
}
