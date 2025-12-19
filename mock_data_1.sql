/********************************************************************
 * FICHIER : mock_data.sql
 * OBJECTIF :
 *   - Créer la base de données
 *   - Créer le schéma logique
 *   - Créer les tables métier
 *   - Créer des vues analytiques pour le métier
 *
 * CONTEXTE :
 *   Plateforme d’abonnements avec historisation complète :
 *   - Clients
 *   - Abonnements
 *   - Facturation mensuelle
 *   - Historique des changements de formule
 *
 * SGBD :
 *   PostgreSQL
 ********************************************************************/


/********************************************************************
 * 1. CREATION DE LA BASE DE DONNEES
 *    (à exécuter avec un rôle ayant les droits CREATE DATABASE)
 ********************************************************************/

CREATE DATABASE abonnement_db;

/*
 Après la création de la base, se connecter à celle-ci :
 \c abonnement_db;
*/


/********************************************************************
 * 2. CREATION DU SCHEMA LOGIQUE
 *    Permet d’isoler les objets métier
 ********************************************************************/

CREATE SCHEMA IF NOT EXISTS subscription;

/* Définition du schéma par défaut */
SET search_path TO subscription;


/********************************************************************
 * 3. CREATION DES TABLES
 ********************************************************************/


/********************************************************************
 * TABLE : customer
 * DESCRIPTION :
 *   Stocke les informations d’identité des clients.
 *   Un client peut avoir plusieurs abonnements dans le temps.
 ********************************************************************/

CREATE TABLE customer (
    customer_id INTEGER PRIMARY KEY,
    nom VARCHAR(100),
    prenom VARCHAR(100),
    email VARCHAR(150) UNIQUE,
    active BOOLEAN DEFAULT TRUE
);


/********************************************************************
 * TABLE : formules_abonnement
 * DESCRIPTION :
 *   Catalogue des offres commerciales.
 *   Le prix est stocké ici mais sera copié dans les factures
 *   afin de figer l’historique financier.
 ********************************************************************/

CREATE TABLE formules_abonnement (
    id_formule INTEGER PRIMARY KEY,
    nom_formule VARCHAR(50) NOT NULL,
    prix DECIMAL(10,2) NOT NULL,
    nb_ecrans_max INTEGER,
    resolution VARCHAR(20),
    description TEXT
);


/********************************************************************
 * TABLE : abonnements_clients
 * DESCRIPTION :
 *   Représente un contrat d’abonnement entre un client et une formule.
 *   - Historisé (aucune suppression)
 *   - Un client peut avoir plusieurs abonnements successifs
 ********************************************************************/

CREATE TABLE abonnements_clients (
    id_abonnement INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    id_formule INTEGER NOT NULL,
    date_debut DATE NOT NULL,
    date_fin DATE,
    statut VARCHAR(20) NOT NULL, -- ACTIF, RESILIE, SUSPENDU
    date_prochain_paiement DATE,
    renouvellement_auto BOOLEAN DEFAULT TRUE,

    CONSTRAINT fk_abonnement_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id),

    CONSTRAINT fk_abonnement_formule
        FOREIGN KEY (id_formule)
        REFERENCES formules_abonnement(id_formule)
);


/********************************************************************
 * TABLE : factures
 * DESCRIPTION :
 *   Table de facturation mensuelle.
 *   Un abonnement actif génère une facture par mois.
 *   Permet la gestion des impayés sans résiliation immédiate.
 ********************************************************************/

CREATE TABLE factures (
    id_facture INTEGER PRIMARY KEY,
    id_abonnement INTEGER NOT NULL,
    montant DECIMAL(10,2) NOT NULL,
    date_emission DATE,
    date_echeance DATE,
    statut_paiement VARCHAR(20), -- PAYE, EN_ATTENTE, REJETE
    date_paiement DATE,

    CONSTRAINT fk_facture_abonnement
        FOREIGN KEY (id_abonnement)
        REFERENCES abonnements_clients(id_abonnement)
);


/********************************************************************
 * TABLE : historique_changements
 * DESCRIPTION :
 *   Historise tous les changements de formule :
 *   - upgrade
 *   - downgrade
 *   - migration
 *   Utilisée pour audit et analyse comportementale.
 ********************************************************************/

CREATE TABLE historique_changements (
    id_historique INTEGER PRIMARY KEY,
    id_abonnement INTEGER NOT NULL,
    date_changement TIMESTAMP NOT NULL,
    id_ancienne_formule INTEGER,
    id_nouvelle_formule INTEGER,
    type_changement VARCHAR(50),

    CONSTRAINT fk_hist_abonnement
        FOREIGN KEY (id_abonnement)
        REFERENCES abonnements_clients(id_abonnement),

    CONSTRAINT fk_hist_ancienne_formule
        FOREIGN KEY (id_ancienne_formule)
        REFERENCES formules_abonnement(id_formule),

    CONSTRAINT fk_hist_nouvelle_formule
        FOREIGN KEY (id_nouvelle_formule)
        REFERENCES formules_abonnement(id_formule)
);


/********************************************************************
 * 4. VUES METIER / ANALYTIQUES
 ********************************************************************/


/********************************************************************
 * VUE : v_abonnements_actifs
 * USAGE :
 *   - Parc client actif
 *   - Suivi produit / opérations
 ********************************************************************/

CREATE VIEW v_abonnements_actifs AS
SELECT
    a.id_abonnement,
    c.customer_id,
    c.nom,
    c.prenom,
    f.nom_formule,
    f.prix,
    a.date_debut,
    a.date_prochain_paiement
FROM abonnements_clients a
JOIN customer c ON a.customer_id = c.customer_id
JOIN formules_abonnement f ON a.id_formule = f.id_formule
WHERE a.statut = 'ACTIF';


/********************************************************************
 * VUE : v_mrr
 * USAGE :
 *   - Monthly Recurring Revenue
 *   - KPI Finance / Direction
 ********************************************************************/

CREATE VIEW v_mrr AS
SELECT
    DATE_TRUNC('month', date_echeance) AS mois,
    SUM(montant) AS mrr
FROM factures
WHERE statut_paiement = 'PAYE'
GROUP BY DATE_TRUNC('month', date_echeance);


/********************************************************************
 * VUE : v_churn
 * USAGE :
 *   - Analyse des résiliations
 *   - KPI rétention
 ********************************************************************/

CREATE VIEW v_churn AS
SELECT
    DATE_TRUNC('month', date_fin) AS mois,
    COUNT(*) AS nb_resiliations
FROM abonnements_clients
WHERE statut = 'RESILIE'
GROUP BY DATE_TRUNC('month', date_fin);


/********************************************************************
 * VUE : v_resubscription
 * USAGE :
 *   - Identification des clients réabonnés
 *   - Analyse fidélité long terme
 ********************************************************************/

CREATE VIEW v_resubscription AS
SELECT
    customer_id,
    COUNT(*) AS nb_abonnements
FROM abonnements_clients
GROUP BY customer_id
HAVING COUNT(*) > 1;


/********************************************************************
 * VUE : v_changements_formule
 * USAGE :
 *   - Analyse des upgrades / downgrades
 *   - Décisions pricing & produit
 ********************************************************************/

CREATE VIEW v_changements_formule AS
SELECT
    h.date_changement,
    h.type_changement,
    fa.nom_formule AS ancienne_formule,
    fn.nom_formule AS nouvelle_formule
FROM historique_changements h
LEFT JOIN formules_abonnement fa ON h.id_ancienne_formule = fa.id_formule
LEFT JOIN formules_abonnement fn ON h.id_nouvelle_formule = fn.id_formule;


/********************************************************************
 * FIN DU FICHIER
 ********************************************************************/