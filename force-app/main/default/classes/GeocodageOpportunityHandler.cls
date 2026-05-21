public class GeocodageOpportunityHandler {

    private static final String NOMINATIM_URL =
        'https://nominatim.openstreetmap.org/search?format=json&limit=1&q=';

    // IDs marqués dans le BEFORE trigger, avant que handleBeforeInsertUpdate écrase adresse__c
    private static Set<Id> idsAGeocoder = new Set<Id>();

    // Appelé dans le BEFORE UPDATE, avant que l'adresse soit écrasée par le compte
    public static void marquerChangements(List<Opportunity> opps, Map<Id, Opportunity> oldMap) {
        System.debug(LoggingLevel.DEBUG, '[Geocodage] marquerChangements - nb opps=' + opps.size());
        for (Opportunity opp : opps) {
            Boolean change = adresseChangee(opp, oldMap);
            System.debug(LoggingLevel.DEBUG, '[Geocodage] Opp=' + opp.Id + ' nom=' + opp.Name
                + ' rue=' + opp.adresse__Street__s
                + ' ville=' + opp.adresse__City__s
                + ' cp=' + opp.adresse__PostalCode__s
                + ' | adresse changee=' + change);
            if (change) {
                idsAGeocoder.add(opp.Id);
                System.debug(LoggingLevel.DEBUG, '[Geocodage] Marque pour geocodage : ' + opp.Id);
            }
        }
    }

    // Appelé dans le AFTER trigger — utilise les IDs pré-marqués pour les updates
    public static void planifierGeocodage(List<Opportunity> opps, Map<Id, Opportunity> oldMap) {
        Boolean isInsert = oldMap == null;
        System.debug(LoggingLevel.DEBUG, '[Geocodage] planifierGeocodage - contexte=' + (isInsert ? 'INSERT' : 'UPDATE') + ' nb opps=' + opps.size());

        for (Opportunity opp : opps) {
            Boolean aGeocoderCetteOpp;
            if (isInsert) {
                // INSERT : géocoder si adresse présente
                aGeocoderCetteOpp = opp.adresse__City__s != null || opp.adresse__Street__s != null;
                System.debug(LoggingLevel.DEBUG, '[Geocodage] INSERT Opp=' + opp.Id + ' adresse presente=' + aGeocoderCetteOpp);
            } else {
                // UPDATE : se fier aux IDs marqués AVANT l'écrasement par le before trigger
                aGeocoderCetteOpp = idsAGeocoder.contains(opp.Id);
                System.debug(LoggingLevel.DEBUG, '[Geocodage] UPDATE Opp=' + opp.Id + ' dans liste a geocoder=' + aGeocoderCetteOpp);
            }

            if (!aGeocoderCetteOpp) continue;

            String adresse = construireAdresse(opp);
            if (String.isBlank(adresse)) {
                System.debug(LoggingLevel.DEBUG, '[Geocodage] Adresse vide apres construction - ignore : ' + opp.Id);
                continue;
            }

            System.debug(LoggingLevel.DEBUG, '[Geocodage] Geocodage planifie : ' + opp.Id + ' adresse=' + adresse);
            geocoder(opp.Id, adresse);
        }
    }

    // Appel HTTP asynchrone — obligatoire pour les callouts depuis un trigger
    @future(callout=true)
    public static void geocoder(Id oppId, String adresse) {
        String endpoint = NOMINATIM_URL + EncodingUtil.urlEncode(adresse, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(10000);
        req.setHeader('Accept-Language', 'fr');
        // Nominatim exige un User-Agent identifiant l'application
        req.setHeader('User-Agent', 'UpmindLudwigCRM/1.0 msavane@upmind.fr');

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[Geocodage] Erreur callout : ' + e.getMessage());
            return;
        }

        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            System.debug(LoggingLevel.WARN, '[Geocodage] Réponse inattendue : ' + res.getStatusCode());
            return;
        }

        List<Object> resultats = (List<Object>) JSON.deserializeUntyped(res.getBody());
        if (resultats.isEmpty()) {
            System.debug(LoggingLevel.WARN, '[Geocodage] Aucun résultat pour : ' + adresse);
            return;
        }

        Map<String, Object> premier = (Map<String, Object>) resultats[0];
        Decimal latitude  = Decimal.valueOf((String) premier.get('lat'));
        Decimal longitude = Decimal.valueOf((String) premier.get('lon'));

        System.debug('[Geocodage] ' + adresse + ' → lat=' + latitude + ' lon=' + longitude);

        try {
            update new Opportunity(
                Id           = oppId,
                Latitude__c  = latitude,
                Longitude__c = longitude
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[Geocodage] Erreur update : ' + e.getMessage());
        }
    }

    // Vérifie si l'adresse compound a changé (ou est nouvelle sur insert)
    private static Boolean adresseChangee(Opportunity opp, Map<Id, Opportunity> oldMap) {
        if (oldMap == null) {
            return opp.adresse__City__s != null || opp.adresse__Street__s != null;
        }
        Opportunity ancien = oldMap.get(opp.Id);
        return opp.adresse__Street__s     != ancien.adresse__Street__s
            || opp.adresse__City__s       != ancien.adresse__City__s
            || opp.adresse__PostalCode__s != ancien.adresse__PostalCode__s;
    }

    private static String construireAdresse(Opportunity opp) {
        List<String> parties = new List<String>();
        if (String.isNotBlank(opp.adresse__Street__s))    parties.add(opp.adresse__Street__s);
        if (String.isNotBlank(opp.adresse__PostalCode__s)) parties.add(opp.adresse__PostalCode__s);
        if (String.isNotBlank(opp.adresse__City__s))      parties.add(opp.adresse__City__s);
        return String.join(parties, ', ');
    }
}
