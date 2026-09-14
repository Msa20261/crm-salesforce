public with sharing class LeadScoringScheduler implements Schedulable {
  public void execute(SchedulableContext ctx) {
    LeadScoringService.recalculerLeadsOuverts();
  }
}
