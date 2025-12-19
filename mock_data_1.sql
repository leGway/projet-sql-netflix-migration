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
DATA INSERT 
 * OBJECTIF :
 *   - Peupler le modèle avec des données fictives réalistes
 *   - Couvrir plusieurs cas métier : churn, réabonnement, upgrades,
 *     downgrades, impayés
 *   - Permettre le calcul de KPI : MRR, churn, mix de formules
********************************************************************/

/********************************************************************
 * 1) FORMULES D'ABONNEMENT
 * DESCRIPTION :
 *   - Catalogue commercial de l’offre
 *   - Sert de référence pour les prix et la capacité (écrans, résolution)
 * REMARQUES :
 *   - Le prix est copié dans la table de facturation pour figer l’historique
 ********************************************************************/

INSERT INTO formules_abonnement (id_formule, nom_formule, prix, nb_ecrans_max, resolution, description) VALUES
(1, 'Basic',   8.99, 1, 'HD',   'Formule d''entrée de gamme'),
(2, 'Standard',12.99, 2, 'FHD',  'Formule standard'),
(3, 'Premium',15.99, 4, '4K',   'Formule premium');

/********************************************************************
 * 2) CLIENTS
 * DESCRIPTION :
 *   - Référentiel des clients finaux
 *   - Contient les informations d’identité et l’état d’activité
 * REMARQUES :
 *   - Le champ "active" permet d’identifier les comptes clôturés
 *   - Les domaines d’e‑mail variés permettent de tester des segmentations
 ********************************************************************/

INSERT INTO customer (customer_id, nom, prenom, email, active) VALUES
(1,  'Dupont',     'Alice',    'alice.dupont@gmail.com',        TRUE),
(2,  'Martin',     'Bruno',    'bruno.martin@example.com',      TRUE),
(3,  'Durand',     'Chloe',    'chloe.durand@hotmail.com',      TRUE),
(4,  'Bernard',    'David',    'david.bernard@gmail.com',       FALSE),
(5,  'Petit',      'Emma',     'emma.petit@example.com',        TRUE),
(6,  'Robert',     'Lucas',    'lucas.robert@hotmail.com',      TRUE),
(7,  'Richard',    'Manon',    'manon.richard@gmail.com',       TRUE),
(8,  'Moreau',     'Hugo',     'hugo.moreau@example.com',       TRUE),
(9,  'Laurent',    'Camille',  'camille.laurent@hotmail.com',   FALSE),
(10, 'Simon',      'Jules',    'jules.simon@gmail.com',         TRUE),
(11, 'Michel',     'Lea',      'lea.michel@example.com',        TRUE),
(12, 'Lefebvre',   'Tom',      'tom.lefebvre@hotmail.com',      TRUE),
(13, 'Leroy',      'Sarah',    'sarah.leroy@gmail.com',         TRUE),
(14, 'Roux',       'Nathan',   'nathan.roux@example.com',       TRUE),
(15, 'Morin',      'Clara',    'clara.morin@hotmail.com',       FALSE),
 
/********************************************************************
 * 3) ABONNEMENTS CLIENTS
 * DESCRIPTION :
 *   - Chaque ligne représente un contrat d’abonnement pour un client
 *   - Historisé : les lignes ne sont pas supprimées en cas de résiliation
 * CAS COUVERTS :
 *   - Churn simple (abonnement résilié)
 *   - Réabonnement / upgrade (Alice : Basic -> Premium)
 *   - Abonnements toujours actifs pour les analyses MRR courantes
 ********************************************************************/
 
INSERT INTO abonnements_clients
(id_abonnement, customer_id, id_formule, date_debut, date_fin, statut, date_prochain_paiement, renouvellement_auto)
VALUES
-- Alice Dupont : Basic puis upgrade Premium
(101,  1, 1, '2025-01-05', '2025-04-01', 'RESILIE', '2025-03-05', TRUE),
(102,  1, 3, '2025-04-01', NULL,          'ACTIF',   '2025-12-01', TRUE),

-- Bruno Martin : Standard résilié
(201,  2, 2, '2025-02-10', '2025-06-15', 'RESILIE', '2025-06-10', FALSE),

-- Chloe Durand : Premium actif
(301,  3, 3, '2025-03-01', NULL,          'ACTIF',   '2025-12-01', TRUE),

-- David Bernard : Basic ancien résilié
(401,  4, 1, '2024-10-01', '2025-01-01', 'RESILIE', '2024-12-01', FALSE),

-- Emma Petit : Standard actif
(505,  5, 2, '2025-01-15', NULL,          'ACTIF',   '2025-12-15', TRUE),

-- Lucas Robert : Basic résilié
(606,  6, 1, '2024-12-01', '2025-05-01', 'RESILIE', '2025-04-01', FALSE),

-- Manon Richard : Premium actif
(707,  7, 3, '2025-02-20', NULL,          'ACTIF',   '2025-12-20', TRUE),

-- Hugo Moreau : Basic actif
(808,  8, 1, '2025-03-05', NULL,          'ACTIF',   '2025-12-05', TRUE),

-- Camille Laurent : Standard résilié
(909,  9, 2, '2024-11-10', '2025-03-10', 'RESILIE', '2025-02-10', FALSE),

-- Jules Simon : Premium actif
(1010, 10, 3, '2025-04-01', NULL,         'ACTIF',   '2025-12-01', TRUE),

-- Lea Michel : Basic actif
(1111, 11, 1, '2025-02-01', NULL,         'ACTIF',   '2025-12-01', TRUE),

-- Tom Lefebvre : Standard résilié
(1212, 12, 2, '2024-09-15', '2025-02-15', 'RESILIE', '2025-01-15', FALSE),

-- Sarah Leroy : Premium actif
(1313, 13, 3, '2025-03-10', NULL,         'ACTIF',   '2025-12-10', TRUE),

-- Nathan Roux : Basic actif
(1414, 14, 1, '2025-01-20', NULL,         'ACTIF',   '2025-12-20', TRUE),

-- Clara Morin : Standard résilié
(1515, 15, 2, '2024-08-05', '2025-01-05', 'RESILIE', '2024-12-05', FALSE);


/********************************************************************
 * 4) FACTURES
 * DESCRIPTION :
 *   - Facturation mensuelle associée à chaque abonnement
 *   - Montant figé au moment de l’émission
 * CAS COUVERTS :
 *   - Paiements réussis (PAYE)
 *   - Impayés / rejets (REJETE) pour l’analyse du risque et du churn
 *   - Paiements en attente (EN_ATTENTE) pour simuler des retards
 ********************************************************************/

INSERT INTO factures
(id_facture, id_abonnement, montant, date_emission, date_echeance, statut_paiement, date_paiement)
VALUES
-- 101 : Basic, 2025-01-05 → 2025-04-01 (résilié)
(10001, 101, 8.99,  '2025-01-05', '2025-01-05', 'PAYE',      '2025-01-05'),
(10002, 101, 8.99,  '2025-02-05', '2025-02-05', 'PAYE',      '2025-02-05'),
(10003, 101, 8.99,  '2025-03-05', '2025-03-05', 'REJETE',    NULL),

-- 102 : Premium, actif depuis 2025-04-01
(10011, 102, 15.99, '2025-04-01', '2025-04-01', 'PAYE',      '2025-04-01'),
(10012, 102, 15.99, '2025-05-01', '2025-05-01', 'PAYE',      '2025-05-01'),
(10013, 102, 15.99, '2025-06-01', '2025-06-01', 'EN_ATTENTE',NULL),

-- 201 : Standard, 2025-02-10 → 2025-06-15 (dernière facture en mai)
(10021, 201, 12.99, '2025-02-10', '2025-02-10', 'PAYE',      '2025-02-10'),
(10022, 201, 12.99, '2025-03-10', '2025-03-10', 'PAYE',      '2025-03-10'),
(10023, 201, 12.99, '2025-04-10', '2025-04-10', 'PAYE',      '2025-04-10'),
(10024, 201, 12.99, '2025-05-10', '2025-05-10', 'REJETE',    NULL),

-- 301 : Premium, actif depuis 2025-03-01
(10031, 301, 15.99, '2025-03-01', '2025-03-01', 'PAYE',      '2025-03-01'),
(10032, 301, 15.99, '2025-04-01', '2025-04-01', 'PAYE',      '2025-04-01'),
(10033, 301, 15.99, '2025-05-01', '2025-05-01', 'PAYE',      '2025-05-01'),

-- 401 : Basic, 2024-10-01 → 2025-01-01 (dernière facture en décembre)
(10041, 401, 8.99,  '2024-10-01', '2024-10-01', 'PAYE',      '2024-10-01'),
(10042, 401, 8.99,  '2024-11-01', '2024-11-01', 'PAYE',      '2024-11-01'),
(10043, 401, 8.99,  '2024-12-01', '2024-12-01', 'REJETE',    NULL),

-- 505 : Standard, actif depuis 2025-01-15
(10501, 505, 12.99, '2025-01-15', '2025-01-15', 'PAYE',      '2025-01-15'),
(10502, 505, 12.99, '2025-02-15', '2025-02-15', 'PAYE',      '2025-02-15'),
(10503, 505, 12.99, '2025-03-15', '2025-03-15', 'EN_ATTENTE',NULL),

-- 606 : Basic, 2024-12-01 → 2025-05-01
(10601, 606, 8.99,  '2024-12-01', '2024-12-01', 'PAYE',      '2024-12-01'),
(10602, 606, 8.99,  '2025-01-01', '2025-01-01', 'PAYE',      '2025-01-01'),
(10603, 606, 8.99,  '2025-02-01', '2025-02-01', 'PAYE',      '2025-02-01'),
(10604, 606, 8.99,  '2025-03-01', '2025-03-01', 'REJETE',    NULL),

-- 707 : Premium, actif depuis 2025-02-20
(10701, 707, 15.99, '2025-02-20', '2025-02-20', 'PAYE',      '2025-02-20'),
(10702, 707, 15.99, '2025-03-20', '2025-03-20', 'PAYE',      '2025-03-20'),
(10703, 707, 15.99, '2025-04-20', '2025-04-20', 'EN_ATTENTE',NULL),

-- 808 : Basic, actif depuis 2025-03-05
(10801, 808, 8.99,  '2025-03-05', '2025-03-05', 'PAYE',      '2025-03-05'),
(10802, 808, 8.99,  '2025-04-05', '2025-04-05', 'PAYE',      '2025-04-05'),
(10803, 808, 8.99,  '2025-05-05', '2025-05-05', 'EN_ATTENTE',NULL),

-- 909 : Standard, 2024-11-10 → 2025-03-10
(10901, 909, 12.99, '2024-11-10', '2024-11-10', 'PAYE',      '2024-11-10'),
(10902, 909, 12.99, '2024-12-10', '2024-12-10', 'PAYE',      '2024-12-10'),
(10903, 909, 12.99, '2025-01-10', '2025-01-10', 'REJETE',    NULL),

-- 1010 : Premium, actif depuis 2025-04-01
(11001, 1010, 15.99, '2025-04-01', '2025-04-01', 'PAYE',     '2025-04-01'),
(11002, 1010, 15.99, '2025-05-01', '2025-05-01', 'PAYE',     '2025-05-01'),
(11003, 1010, 15.99, '2025-06-01', '2025-06-01', 'EN_ATTENTE',NULL),

-- 1111 : Basic, actif depuis 2025-02-01
(11101, 1111, 8.99,  '2025-02-01', '2025-02-01', 'PAYE',     '2025-02-01'),
(11102, 1111, 8.99,  '2025-03-01', '2025-03-01', 'PAYE',     '2025-03-01'),
(11103, 1111, 8.99,  '2025-04-01', '2025-04-01', 'EN_ATTENTE',NULL),

-- 1212 : Standard, 2024-09-15 → 2025-02-15
(11201, 1212, 12.99, '2024-09-15', '2024-09-15', 'PAYE',     '2024-09-15'),
(11202, 1212, 12.99, '2024-10-15', '2024-10-15', 'PAYE',     '2024-10-15'),
(11203, 1212, 12.99, '2024-11-15', '2024-11-15', 'REJETE',   NULL),

-- 1313 : Premium, actif depuis 2025-03-10
(11301, 1313, 15.99, '2025-03-10', '2025-03-10', 'PAYE',     '2025-03-10'),
(11302, 1313, 15.99, '2025-04-10', '2025-04-10', 'PAYE',     '2025-04-10'),

-- 1414 : Basic, actif depuis 2025-01-20
(11401, 1414, 8.99,  '2025-01-20', '2025-01-20', 'PAYE',     '2025-01-20'),
(11402, 1414, 8.99,  '2025-02-20', '2025-02-20', 'PAYE',     '2025-02-20'),

-- 1515 : Standard, 2024-08-05 → 2025-01-05
(11501, 1515, 12.99, '2024-08-05', '2024-08-05', 'PAYE',     '2024-08-05'),
(11502, 1515, 12.99, '2024-09-05', '2024-09-05', 'PAYE',     '2024-09-05'),
(11503, 1515, 12.99, '2024-10-05', '2024-10-05', 'REJETE',   NULL);


/********************************************************************
 * 5) HISTORIQUE DES CHANGEMENTS D’OFFRE
 * DESCRIPTION :
 *   - Trace tous les événements de changement de formule :
 *     UPGRADE, DOWNGRADE, RESILIATION
 *   - Sert de base à la vue v_changements_formule
 * CAS COUVERTS :
 *   - Migrations de plan (Basic -> Premium, Premium -> Standard, etc.)
 *   - Résiliations explicites pour le suivi du churn
 ********************************************************************/

INSERT INTO historique_changements
(id_historique, id_abonnement, date_changement,
 id_ancienne_formule, id_nouvelle_formule, type_changement)
VALUES
-- Alice Dupont : passage Basic -> Premium (nouvel abonnement 102)
(1,  102, '2025-04-01 10:00:00', 1, 3, 'UPGRADE'),

-- Bruno Martin : résiliation de son abonnement Standard
(2,  201, '2025-06-15 09:00:00', 2, NULL, 'RESILIATION'),

-- Chloe Durand : aucun changement de formule (abonnement 301 reste Premium ACTIF)
-- -> pas de ligne spécifique

-- David Bernard : résiliation de son abonnement Basic
(3,  401, '2025-01-01 08:30:00', 1, NULL, 'RESILIATION'),

-- Emma Petit : projet d'upgrade Standard -> Premium (abonnement 505 actif)
(4,  505, '2025-07-15 09:00:00', 2, 3, 'UPGRADE'),

-- Lucas Robert : résiliation de son abonnement Basic
(5,  606, '2025-05-01 09:15:00', 1, NULL, 'RESILIATION'),

-- Manon Richard : downgrade Premium -> Standard, abonnement reste ACTIF
(6,  707, '2025-06-20 18:00:00', 3, 2, 'DOWNGRADE'),

-- Hugo Moreau : upgrade Basic -> Standard, abonnement reste ACTIF
(7,  808, '2025-08-05 12:00:00', 1, 2, 'UPGRADE'),

-- Camille Laurent : résiliation de son abonnement Standard
(8,  909, '2025-03-10 11:00:00', 2, NULL, 'RESILIATION'),

-- Jules Simon : aucun changement de formule (Premium ACTIF)
-- -> pas de ligne spécifique

-- Lea Michel : upgrade Basic -> Standard
(9,  1111, '2025-05-01 10:00:00', 1, 2, 'UPGRADE'),

-- Tom Lefebvre : résiliation de son abonnement Standard
(10, 1212, '2025-02-15 10:45:00', 2, NULL, 'RESILIATION'),

-- Sarah Leroy : aucun changement (Premium ACTIF)

-- Nathan Roux : aucun changement (Basic ACTIF)

-- Clara Morin : résiliation de son abonnement Standard
(11, 1515, '2025-01-05 14:20:00', 2, NULL, 'RESILIATION');


/********************************************************************
FIN DU FICHIER
********************************************************************/
