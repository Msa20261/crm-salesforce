import { LightningElement, api } from "lwc";
import { loadScript, loadStyle } from "lightning/platformResourceLoader";
import LEAFLET from "@salesforce/resourceUrl/Leaflet_Zip";
import MARKERCLUSTER from "@salesforce/resourceUrl/MarkerCluster_Zip";

// Couleur de la punaise selon l'étape — vert = gagné, rouge = perdu, jaune = en cours
function couleurEtape(stageName) {
  if (stageName === "Closed Won") return "#2E7D32";
  if (stageName === "Closed Lost") return "#C62828";
  return "#FBC02D";
}

// Punaise SVG générée en code (pas de fichier image à héberger)
function iconePunaise(couleur) {
  const svg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="30" height="42" viewBox="0 0 30 42">' +
    '<path d="M15 0C6.7 0 0 6.7 0 15c0 10.5 15 27 15 27s15-16.5 15-27C30 6.7 23.3 0 15 0z" ' +
    'fill="' +
    couleur +
    '" stroke="#ffffff" stroke-width="1.5"/>' +
    '<circle cx="15" cy="15" r="6" fill="#ffffff"/></svg>';
  // eslint-disable-next-line no-undef
  return "data:image/svg+xml;base64," + window.btoa(svg);
}

export default class CarteLeaflet extends LightningElement {
  erreur = null;
  isLoading = true;

  _leafletLoaded = false;
  _map = null;
  _marqueursLayer = null;
  _opportunities = [];

  // Reçoit les opportunités filtrées du composant parent
  @api
  get opportunities() {
    return this._opportunities;
  }
  set opportunities(value) {
    this._opportunities = value || [];
    // Si la carte est déjà initialisée, rafraîchir les marqueurs immédiatement
    if (this._map) {
      this._rafraichirMarqueurs();
    }
  }

  connectedCallback() {
    Promise.all([
      loadStyle(this, LEAFLET + "/leaflet.css"),
      loadScript(this, LEAFLET + "/leaflet.js")
    ])
      // leaflet.markercluster dépend de L, doit charger après leaflet.js
      .then(() =>
        Promise.all([
          loadStyle(this, MARKERCLUSTER + "/MarkerCluster.css"),
          loadStyle(this, MARKERCLUSTER + "/MarkerCluster.Default.css"),
          loadScript(this, MARKERCLUSTER + "/leaflet.markercluster.js")
        ])
      )
      .then(() => {
        this._leafletLoaded = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
          const container = this.template.querySelector(".carte-container");
          if (!container) return;
          this._buildMap(container);
          // Afficher les opportunités déjà transmises par le parent
          if (this._opportunities.length > 0) {
            this._rafraichirMarqueurs();
          }
        }, 0);
      })
      .catch((err) => {
        this.isLoading = false;
        this.erreur =
          "Impossible de charger Leaflet : " + (err.message || String(err));
      });
  }

  _buildMap(container) {
    // eslint-disable-next-line no-undef
    const L = window.L;
    this._map = L.map(container).setView([46.603354, 1.888334], 6);

    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      maxZoom: 18
    }).addTo(this._map);

    // Regroupe les punaises proches ; se comporte comme un LayerGroup (clearLayers/addTo)
    this._marqueursLayer = L.markerClusterGroup({
      maxClusterRadius: 45,
      spiderfyOnMaxZoom: true,
      showCoverageOnHover: false
    }).addTo(this._map);
    this.isLoading = false;
  }

  _rafraichirMarqueurs() {
    // eslint-disable-next-line no-undef
    const L = window.L;
    this._marqueursLayer.clearLayers();

    const avecCoords = this._opportunities.filter(
      (o) => o.latitudeOpp && o.longitudeOpp
    );
    if (avecCoords.length === 0) return;

    const bounds = [];
    avecCoords.forEach((o) => {
      const lat = parseFloat(o.latitudeOpp);
      const lng = parseFloat(o.longitudeOpp);
      bounds.push([lat, lng]);

      const adresse = [o.codePostal, o.ville].filter(Boolean).join(" ");
      const montant = o.montant
        ? o.montant.toLocaleString("fr-FR", {
            style: "currency",
            currency: "EUR"
          })
        : "—";

      const popup = `
                <div style="min-width:210px;font-family:sans-serif;line-height:1.5">
                    <div style="font-size:10px;color:#E65100;font-weight:700;text-transform:uppercase;margin-bottom:2px">
                        Opportunité
                    </div>
                    <strong style="font-size:14px;color:#1B3A6B">${o.nom}</strong><br/>
                    <span style="font-size:12px;color:#555">${o.compteNom || ""}</span><br/>
                    ${o.rue ? `<span style="font-size:11px">${o.rue}</span><br/>` : ""}
                    ${adresse ? `<span style="font-size:11px">${adresse}</span><br/>` : ""}
                    <span style="font-size:12px;color:#2E7D32;font-weight:600">${montant}</span>
                    &nbsp;·&nbsp;
                    <span style="font-size:11px;color:#555">${o.stageName || ""}</span><br/>
                    <a href="/lightning/r/Opportunity/${o.id}/view" target="_blank"
                       style="color:#0070d2;font-size:12px">Ouvrir la fiche →</a>
                </div>`;

      const icon = L.icon({
        iconUrl: iconePunaise(couleurEtape(o.stageName)),
        iconSize: [30, 42],
        iconAnchor: [15, 42],
        popupAnchor: [0, -38]
      });

      L.marker([lat, lng], { icon })
        .bindPopup(popup)
        .addTo(this._marqueursLayer);
    });

    this._map.fitBounds(bounds, { padding: [40, 40] });
  }

  disconnectedCallback() {
    if (this._map) {
      this._map.remove();
      this._map = null;
    }
  }
}
