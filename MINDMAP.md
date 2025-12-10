```mermaid
mindmap
  root((Projet SQL<br/>MBDIA 2025))
    Mission et Contexte
      Contexte Historique
        :: icon(fa fa-history)
        Location DVD par correspondance
      Contexte Actuel
        :: icon(fa fa-film)
        Géant du Streaming
      Objectif
        Concevoir une fonctionnalité de Streaming
      Base de données
        DVD Rental existante
      Contrainte
        Code SQL fonctionnel requis
    Objectifs Pédagogiques
      :: icon(fa fa-graduation-cap)
      Conception BD Relationnelle
      Maîtriser SQL
        SELECT, JOIN, GROUP BY
      Rapports Métiers
    Idées de Fonctionnalités
      :: icon(fa fa-lightbulb)
      1. Streaming et Visionnage
        Tracker le temps
        Gérer les reprises (bookmarks)
        Tables: streaming_sessions, viewing_history
      2. Abonnements
        Niveaux (Basic, Premium)
        Facturation récurrente
        Tables: subscription_plans, customer_subscriptions
      3. Recommandations
        Analyse historique
        Notation et Avis
        Tables: user_preferences, film_ratings
      4. Contenu Original et Séries
        Saisons et Episodes
        Tables: tv_series, episodes
      5. Profils Utilisateurs
        Multi-profils (Famille)
        Contrôle parental
        Tables: user_profiles, profile_preferences
      6. Offline et Téléchargement
        Gestion du stockage
        Limites et expiration
        Tables: downloads, download_limits
      7. Analytics et KPIs
        Tableau de bord
