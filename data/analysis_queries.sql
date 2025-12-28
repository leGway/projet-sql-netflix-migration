--évolution avec variation du CA par rapport au mois précédant
WITH ca_mensuel AS (
SELECT
DATE_TRUNC('month', date_echeance) AS mois,
SUM(montant) AS chiffre_affaires
FROM subscription.factures
WHERE statut_paiement = 'PAYE'
GROUP BY DATE_TRUNC('month', date_echeance)
)
SELECT
mois,
chiffre_affaires,
chiffre_affaires - LAG(chiffre_affaires) OVER (ORDER BY mois) AS variation_absolue,
ROUND(
(chiffre_affaires - LAG(chiffre_affaires) OVER (ORDER BY mois)) * 100.0
/ NULLIF(LAG(chiffre_affaires) OVER (ORDER BY mois), 0),
2
) AS variation_pct
FROM ca_mensuel
ORDER BY mois;

--suivre le taux d’impayés mensuel et détecter les tendances et variations d’un mois sur l’autre grâce aux fonctions analytiques
WITH taux_rejets_mensuel AS (
SELECT
DATE_TRUNC('month', date_echeance) AS mois,
COUNT() FILTER (WHERE statut_paiement IN ('PAYE', 'REJETE')) AS total_factures_finalisees,
COUNT() FILTER (WHERE statut_paiement = 'REJETE') AS factures_rejetees,
ROUND(
COUNT() FILTER (WHERE statut_paiement = 'REJETE') * 100.0
/ NULLIF(COUNT() FILTER (WHERE statut_paiement IN ('PAYE', 'REJETE')), 0),
2
) AS taux_rejet_pct
FROM subscription.factures
GROUP BY DATE_TRUNC('month', date_echeance)
)
SELECT
mois,
total_factures_finalisees,
factures_rejetees,
taux_rejet_pct,
ROUND(
taux_rejet_pct - LAG(taux_rejet_pct) OVER (ORDER BY mois),
2
) AS variation_absolue_pct,
ROUND(
(taux_rejet_pct - LAG(taux_rejet_pct) OVER (ORDER BY mois)) * 100.0
/ NULLIF(LAG(taux_rejet_pct) OVER (ORDER BY mois), 0),
2
) AS variation_relative_pct
FROM taux_rejets_mensuel
ORDER BY mois;

--Average Revenue per User (ARPU) global par mois
WITH arpu_mensuel AS (
SELECT
DATE_TRUNC('month', f.date_echeance) AS mois,
AVG(f.montant) AS arpu_moyen
FROM subscription.factures f
JOIN subscription.abonnements_clients a
ON f.id_abonnement = a.id_abonnement
WHERE f.statut_paiement = 'PAYE'
GROUP BY DATE_TRUNC('month', f.date_echeance)
)
SELECT
mois,
ROUND(arpu_moyen, 2) AS arpu_moyen,
ROUND(
arpu_moyen - LAG(arpu_moyen) OVER (ORDER BY mois),
2
) AS variation_absolue,
ROUND(
(arpu_moyen - LAG(arpu_moyen) OVER (ORDER BY mois)) * 100.0
/ NULLIF(LAG(arpu_moyen) OVER (ORDER BY mois), 0),
2
) AS variation_pct
FROM arpu_mensuel
ORDER BY mois;

--ARPU par utilisateur et par mois avec taux d'évolution
WITH arpu_mensuel AS (
SELECT
a.customer_id,
DATE_TRUNC('month', f.date_echeance) AS mois,
ROUND(AVG(f.montant), 2) AS arpu
FROM subscription.factures f
JOIN subscription.abonnements_clients a
ON f.id_abonnement = a.id_abonnement
WHERE f.statut_paiement = 'PAYE'
GROUP BY a.customer_id, DATE_TRUNC('month', f.date_echeance)
)
SELECT
customer_id,
mois,
arpu,
ROUND(
arpu - LAG(arpu) OVER (PARTITION BY customer_id ORDER BY mois),
2
) AS variation_absolue,
ROUND(
(arpu - LAG(arpu) OVER (PARTITION BY customer_id ORDER BY mois)) * 100.0
/ NULLIF(LAG(arpu) OVER (PARTITION BY customer_id ORDER BY mois), 0),
2
) AS variation_pct
FROM arpu_mensuel
ORDER BY customer_id, mois;

--savoir combien chaque client a réellement payé et combien de factures sont impayées.
SELECT
c.customer_id,
c.nom,
c.prenom,
COUNT(f.id_facture) AS nb_factures,
SUM(f.montant) AS montant_total,
SUM(CASE WHEN f.statut_paiement = 'PAYE' THEN f.montant ELSE 0 END) AS montant_paye,
SUM(CASE WHEN f.statut_paiement = 'REJETE' THEN f.montant ELSE 0 END) AS montant_rejete
FROM subscription.customer c
JOIN subscription.abonnements_clients a
ON c.customer_id = a.customer_id
JOIN subscription.factures f
ON a.id_abonnement = f.id_abonnement
GROUP BY c.customer_id, c.nom, c.prenom
ORDER BY montant_total DESC;

-- Évolution du Nombre d'Abonnements Actifs par Mois
WITH abonnes_mensuels AS (
    SELECT
        DATE_TRUNC('month', date_debut) AS mois,
        COUNT(DISTINCT customer_id) AS nb_abonnes_actifs
    FROM subscription.abonnements_clients
    WHERE statut = 'ACTIF'
    GROUP BY DATE_TRUNC('month', date_debut)
)
SELECT
    mois,
    nb_abonnes_actifs AS "Nombre d'abonnés",
    nb_abonnes_actifs - LAG(nb_abonnes_actifs) OVER (ORDER BY mois) AS "Variation absolue",
    ROUND(
        (nb_abonnes_actifs - LAG(nb_abonnes_actifs) OVER (ORDER BY mois)) * 100.0
        / NULLIF(LAG(nb_abonnes_actifs) OVER (ORDER BY mois), 0),
        2
    ) AS "Variation (%)"
FROM abonnes_mensuels
ORDER BY mois;

-- Taux de Résiliation Mensuel avec Tendance
WITH churn_mensuel AS (
    SELECT
        DATE_TRUNC('month', date_fin) AS mois,
        COUNT(*) FILTER (WHERE statut = 'RESILIE') AS nb_resiliations,
        COUNT(*) FILTER (WHERE statut IN ('ACTIF', 'RESILIE')) AS total_abonnements,
        ROUND(
            COUNT(*) FILTER (WHERE statut = 'RESILIE') * 100.0
            / NULLIF(COUNT(*) FILTER (WHERE statut IN ('ACTIF', 'RESILIE')), 0),
            2
        ) AS taux_churn_pct
    FROM subscription.abonnements_clients
    WHERE date_fin IS NOT NULL
    GROUP BY DATE_TRUNC('month', date_fin)
)
SELECT
    mois,
    nb_resiliations AS "Résiliations",
    total_abonnements AS "Total abonnements",
    taux_churn_pct AS "Taux de churn (%)",
    ROUND(
        taux_churn_pct - LAG(taux_churn_pct) OVER (ORDER BY mois),
        2
    ) AS "Variation absolue (pts)",
    ROUND(
        (taux_churn_pct - LAG(taux_churn_pct) OVER (ORDER BY mois)) * 100.0
        / NULLIF(LAG(taux_churn_pct) OVER (ORDER BY mois), 0),
        2
    ) AS "Variation relative (%)"
FROM churn_mensuel
ORDER BY mois;

-- Évolution du MRR par Formule par Mois
WITH mrr_par_formule AS (
    SELECT
        DATE_TRUNC('month', a.date_debut) AS mois,
        f.nom_formule,
        SUM(f.prix) AS mrr_formule
    FROM subscription.abonnements_clients a
    JOIN subscription.formules_abonnement f ON a.id_formule = f.id_formule
    WHERE a.statut = 'ACTIF'
    GROUP BY DATE_TRUNC('month', a.date_debut), f.nom_formule
)
SELECT
    mois,
    nom_formule AS "Formule",
    ROUND(mrr_formule, 2) AS "MRR (€)",
    ROUND(
        mrr_formule - LAG(mrr_formule) OVER (PARTITION BY nom_formule ORDER BY mois),
        2
    ) AS "Variation MRR (€)",
    ROUND(
        (mrr_formule - LAG(mrr_formule) OVER (PARTITION BY nom_formule ORDER BY mois)) * 100.0
        / NULLIF(LAG(mrr_formule) OVER (PARTITION BY nom_formule ORDER BY mois), 0),
        2
    ) AS "Croissance (%)"
FROM mrr_par_formule
ORDER BY nom_formule, mois;

-- Nombre d'Upgrades et Downgrades par Mois avec Tendance
WITH mouvements_mensuels AS (
    SELECT
        DATE_TRUNC('month', date_changement) AS mois,
        COUNT(*) FILTER (WHERE type_changement = 'UPGRADE') AS nb_upgrades,
        COUNT(*) FILTER (WHERE type_changement = 'DOWNGRADE') AS nb_downgrades,
        COUNT(*) FILTER (WHERE type_changement = 'RESILIATION') AS nb_resiliations,
        COUNT(*) AS total_mouvements
    FROM subscription.historique_changements
    GROUP BY DATE_TRUNC('month', date_changement)
)
SELECT
    mois,
    nb_upgrades AS "Upgrades",
    nb_downgrades AS "Downgrades",
    nb_resiliations AS "Résiliations",
    total_mouvements AS "Total mouvements",
    -- Variation des upgrades
    nb_upgrades - LAG(nb_upgrades) OVER (ORDER BY mois) AS "Δ Upgrades",
    -- Variation des downgrades
    nb_downgrades - LAG(nb_downgrades) OVER (ORDER BY mois) AS "Δ Downgrades",
    -- Ratio upgrades/downgrades
    ROUND(
        CASE 
            WHEN nb_downgrades > 0 THEN nb_upgrades::NUMERIC / nb_downgrades
            ELSE nb_upgrades::NUMERIC
        END,
        2
    ) AS "Ratio Up/Down"
FROM mouvements_mensuels
ORDER BY mois;

-- Durée de Vie Moyenne des Abonnements par Formule
WITH duree_abonnements AS (
    SELECT
        f.nom_formule,
        a.statut,
        CASE 
            WHEN a.date_fin IS NOT NULL THEN a.date_fin - a.date_debut
            ELSE CURRENT_DATE - a.date_debut
        END AS duree_jours
    FROM subscription.abonnements_clients a
    JOIN subscription.formules_abonnement f ON a.id_formule = f.id_formule
)
SELECT
    nom_formule AS "Formule",
    COUNT(*) AS "Nb abonnements",
    ROUND(AVG(duree_jours), 0) AS "Durée moyenne (jours)",
    ROUND(AVG(duree_jours) / 30.0, 1) AS "Durée moyenne (mois)",
    MIN(duree_jours) AS "Durée min (jours)",
    MAX(duree_jours) AS "Durée max (jours)"
FROM duree_abonnements
GROUP BY nom_formule
ORDER BY "Durée moyenne (jours)" DESC;
