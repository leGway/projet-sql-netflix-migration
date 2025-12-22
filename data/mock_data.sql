/********************************************************************
 * INIT SCHEMA SUBSCRIPTION - DVDRental
 * SGBD : PostgreSQL
 ********************************************************************/

BEGIN;

------------------------------------------------------------
-- 1. SCHEMA
------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS subscription;
SET search_path TO subscription;

------------------------------------------------------------
-- 2. TABLES METIER
------------------------------------------------------------

-- FORMULES
CREATE TABLE formules_abonnement (
    id_formule INTEGER PRIMARY KEY,
    nom_formule VARCHAR(50) NOT NULL,
    prix NUMERIC(10,2) NOT NULL,
    nb_ecrans_max INTEGER,
    resolution VARCHAR(20),
    description TEXT
);

-- ABONNEMENTS
CREATE TABLE abonnements_clients (
    id_abonnement INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    id_formule INTEGER NOT NULL,
    date_debut DATE NOT NULL,
    date_fin DATE,
    statut VARCHAR(20) NOT NULL CHECK (statut IN ('ACTIF','RESILIE','SUSPENDU')),
    date_prochain_paiement DATE,
    renouvellement_auto BOOLEAN DEFAULT TRUE,

    CONSTRAINT fk_customer
        FOREIGN KEY (customer_id)
        REFERENCES public.customer(customer_id),

    CONSTRAINT fk_formule
        FOREIGN KEY (id_formule)
        REFERENCES subscription.formules_abonnement(id_formule)
);

-- FACTURES
CREATE TABLE factures (
    id_facture INTEGER PRIMARY KEY,
    id_abonnement INTEGER NOT NULL,
    montant NUMERIC(10,2) NOT NULL,
    date_emission DATE NOT NULL,
    date_echeance DATE NOT NULL,
    statut_paiement VARCHAR(20) CHECK (statut_paiement IN ('PAYE','EN_ATTENTE','REJETE')),
    date_paiement DATE,

    CONSTRAINT fk_facture_abonnement
        FOREIGN KEY (id_abonnement)
        REFERENCES subscription.abonnements_clients(id_abonnement)
);

-- HISTORIQUE
CREATE TABLE historique_changements (
    id_historique INTEGER PRIMARY KEY,
    id_abonnement INTEGER NOT NULL,
    date_changement TIMESTAMP NOT NULL,
    id_ancienne_formule INTEGER,
    id_nouvelle_formule INTEGER,
    type_changement VARCHAR(30),

    CONSTRAINT fk_hist_abonnement
        FOREIGN KEY (id_abonnement)
        REFERENCES subscription.abonnements_clients(id_abonnement),

    CONSTRAINT fk_hist_old
        FOREIGN KEY (id_ancienne_formule)
        REFERENCES subscription.formules_abonnement(id_formule),

    CONSTRAINT fk_hist_new
        FOREIGN KEY (id_nouvelle_formule)
        REFERENCES subscription.formules_abonnement(id_formule)
);

------------------------------------------------------------
-- 3. DONNEES
------------------------------------------------------------

-- FORMULES
INSERT INTO formules_abonnement VALUES
(1,'Basic',8.99,1,'HD','Entrée de gamme'),
(2,'Standard',12.99,2,'FHD','Offre intermédiaire'),
(3,'Premium',15.99,4,'4K','Offre premium');

-- ABONNEMENTS (clients existants dvdrental)
INSERT INTO abonnements_clients VALUES
(101,1,1,'2025-01-05','2025-04-01','RESILIE','2025-03-05',TRUE),
(102,1,3,'2025-04-01',NULL,'ACTIF','2025-12-01',TRUE),
(201,2,2,'2025-02-10','2025-06-15','RESILIE','2025-06-10',FALSE),
(301,3,3,'2025-03-01',NULL,'ACTIF','2025-12-01',TRUE),
(401,4,1,'2024-10-01','2025-01-01','RESILIE','2024-12-01',FALSE),
(505,5,2,'2025-01-15',NULL,'ACTIF','2025-12-15',TRUE);

-- FACTURES
INSERT INTO factures VALUES
(10001,101,8.99,'2025-01-05','2025-01-05','PAYE','2025-01-05'),
(10002,101,8.99,'2025-02-05','2025-02-05','PAYE','2025-02-05'),
(10003,101,8.99,'2025-03-05','2025-03-05','REJETE',NULL),
(10011,102,15.99,'2025-04-01','2025-04-01','PAYE','2025-04-01'),
(10012,102,15.99,'2025-05-01','2025-05-01','PAYE','2025-05-01'),
(10021,201,12.99,'2025-02-10','2025-02-10','PAYE','2025-02-10');

-- HISTORIQUE
INSERT INTO historique_changements VALUES
(1,102,'2025-04-01 10:00:00',1,3,'UPGRADE'),
(2,201,'2025-06-15 09:00:00',2,NULL,'RESILIATION'),
(3,401,'2025-01-01 08:30:00',1,NULL,'RESILIATION');

------------------------------------------------------------
-- 4. VUES METIER / KPI
------------------------------------------------------------

-- ABONNEMENTS ACTIFS
CREATE VIEW v_abonnements_actifs AS
SELECT
    a.id_abonnement,
    a.customer_id,
    f.nom_formule,
    f.prix,
    a.date_debut,
    a.date_prochain_paiement
FROM abonnements_clients a
JOIN formules_abonnement f ON a.id_formule = f.id_formule
WHERE a.statut = 'ACTIF';

-- MRR
CREATE VIEW v_mrr AS
SELECT
    DATE_TRUNC('month', date_echeance) AS mois,
    SUM(montant) AS mrr
FROM factures
WHERE statut_paiement = 'PAYE'
GROUP BY 1
ORDER BY 1;

-- CHURN
CREATE VIEW v_churn AS
SELECT
    DATE_TRUNC('month', date_fin) AS mois,
    COUNT(*) AS nb_resiliations
FROM abonnements_clients
WHERE statut = 'RESILIE'
GROUP BY 1
ORDER BY 1;

-- REABONNEMENTS
CREATE VIEW v_reabonnement AS
SELECT
    customer_id,
    COUNT(*) AS nb_abonnements
FROM abonnements_clients
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- CHANGEMENTS DE FORMULE
CREATE VIEW v_changements_formule AS
SELECT
    h.date_changement,
    h.type_changement,
    f1.nom_formule AS ancienne_formule,
    f2.nom_formule AS nouvelle_formule
FROM historique_changements h
LEFT JOIN formules_abonnement f1 ON h.id_ancienne_formule = f1.id_formule
LEFT JOIN formules_abonnement f2 ON h.id_nouvelle_formule = f2.id_formule;

COMMIT;
