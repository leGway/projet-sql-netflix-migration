# 🎬 Projet SQL : Transformation de DVD Rental vers le Streaming
**Cours :** MBDIA 2025 | **Deadline :** 12 Janvier 2026 à 9h30

## 1. Contexte & Mission 📜
Au début des années 2000, Netflix était une entreprise de location de DVD. La base de données `DVD Rental` que nous utilisons représente cette époque. Votre mission est de concevoir une nouvelle fonctionnalité pour transformer ce modèle vers un **service de streaming moderne**.

**Objectifs pédagogiques :**
* Conception de bases de données relationnelles.
* Maîtrise SQL (SELECT, JOIN, GROUP BY, HAVING, etc.).
* Génération de rapports métiers (Business Intelligence).

---

## 2. Fonctionnalités (Choisir UNE seule) 🚀
Chaque groupe doit implémenter **une** des fonctionnalités suivantes (liste non exhaustive) :

### Option 1 : Système de Streaming et Visionnage
* Tracker le temps de visionnage et les reprises de lecture (bookmarks).
* Tables suggérées : `streaming_sessions`, `viewing_history`.

### Option 2 : Abonnements Multi-niveaux
* Types d'abonnements (Basic, Standard, Premium) avec limitations (écrans, qualité).
* Tables suggérées : `subscription_plans`, `customer_subscriptions`, `subscription_history`.

### Option 3 : Système de Recommandations
* Catégories de préférences, notation, avis.
* Tables suggérées : `user_preferences`, `film_ratings`, `recommendations`.

### Option 4 : Contenu Original et Séries TV
* Gestion des séries, saisons et épisodes.
* Tables suggérées : `tv_series`, `seasons`, `episodes`, `episode_views`.

### Option 5 : Profils Utilisateurs Multiples
* Plusieurs profils par compte (famille, enfants).
* Tables suggérées : `user_profiles`, `profile_preferences`, `profile_viewing_history`.

### Option 6 : Téléchargement Offline
* Gestion des téléchargements, expiration et limites de stockage.
* Tables suggérées : `downloads`, `download_limits`.

### Option 7 : Analytics & KPIs
* Tableau de bord, taux de rétention, revenus.
* Tables suggérées : `viewing_metrics`, `customer_metrics`.

### Option 8 : Multilingue & Accessibilité
* Gestion des pistes audio et sous-titres.
* Tables suggérées : `audio_tracks`, `subtitles`, `profile_language_preferences`.

---

## 3. Livrables Attendus 📦

### A. Le Document PDF (Rapport final)
À livrer sur la plateforme Learn. Comprend 2 parties :
1.  **Présentation (5-10 pages) :** Photos de l'équipe, description fonctionnelle, diagramme ERD complet, bénéfices métier.
2.  **Détail Technique :**
    * 1 page par table créée (structure + screenshot de 10 lignes de données).
    * 1 page par requête SQL (code complet + explication + screenshot du résultat).

### B. Le Code SQL
* **Structure :** Création de **4 à 10 nouvelles tables**.
* **Requêtes :**
    * 1 requête `CREATE TABLE` par nouvelle table.
    * **10 à 15 requêtes `SELECT`** pour exploiter la donnée.
    * Contraintes : Au moins **4** `JOIN` et **3** `GROUP BY` supplémentaires.

### C. Présentation Orale (15 min)
* **Intro (2 min) :** Contexte métier.
* **Modélisation (3 min) :** Schéma ERD.
* **Démonstration SQL (8 min) :** Chaque membre présente son code.
* **Conclusion (2 min) :** Bénéfices et perspectives.

---

## 4. Critères d'Évaluation 🏆

| Critère | Poids | Description |
| :--- | :--- | :--- |
| **Pertinence** | 10% | Innovation, utilité métier, réalisme. |
| **Modèle de données** | 25% | Normalisation, relations, clés étrangères. |
| **Qualité SQL** | 30% | Syntaxe, bonnes pratiques, complexité. |
| **Présentation** | 15% | Clarté, structure, respect du temps. |
| **Documentation** | 10% | Complétude, clarté des schémas. |
| **Travail d'équipe** | 10% | Répartition équitable. |

**Bonus (+10%) :** Vidéo démo, optimisation performance, ou créativité exceptionnelle.

---

## 5. Ressources & Outils 🛠️
* **Base de données :** PostgreSQL (DVD Rental Sample Database).
* **Modélisation :** [dbdiagram.io](https://dbdiagram.io) ou draw.io.
* **Bonnes pratiques :**
    * Nom des tables au **pluriel** (ex: `subscriptions`).
    * Colonnes en `snake_case`.
    * Toujours définir une **Primary Key**.
    * Commenter le code SQL.

---
*Projet basé sur le document "Projet SQL MBDIA 2025".*
