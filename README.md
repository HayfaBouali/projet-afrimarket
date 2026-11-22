# Projet AfriMarket : lakehouse Bronze / Silver

**Étudiante :** Hayfa Bouali, Cycle Ingénieur Génie Logiciel, 3ᵉ année, ESSAT Gabès
**Module :** Big Data
**Enseignant :** Hachicha Hassan

## Contexte

AfriMarket est une entreprise e-commerce présente dans 8 villes d'Afrique francophone
(Abidjan, Brazzaville, Cotonou, Dakar, Douala, Kinshasa, Libreville, Lomé) avec
4 catégories de produits (Électronique, Mode, Beauté, Maison).

Le fichier source `afrimarket_dataset_senior.csv` contient 10 100 commandes
(juillet à décembre 2025) sur 14 colonnes. Le projet construit un pipeline
en architecture médaillon (Bronze puis Silver) sur une plateforme lakehouse :
stockage SeaweedFS (API S3), tables Apache Iceberg, catalogue Nessie et
traitements PySpark via Spark Connect.

## Structure du dépôt

```
projet_afrimarket/
├── data/                       fichier source afrimarket_dataset_senior.csv
├── notebooks/
│   ├── devoir_afrimarketBronze.ipynb   Parties A, B et C (ingestion et audit)
│   └── devoir_afrimarketSilver.ipynb   Partie D (construction de la Silver)
├── demarrer.bat                lancement de la plateforme Docker
├── pyproject.toml / uv.lock    dépendances Python
└── README.md
```

## Prérequis

- Docker Desktop (au moins 6 Go de mémoire alloués : avec moins, le conteneur
  `lakehouse-spark-connect-1` est tué avec le code 137)
- `uv` (gestionnaire d'environnements Python)
- La plateforme lakehouse démarrée : SeaweedFS (port 8333), Nessie,
  Spark master et worker, Spark Connect (port 15002)

## Installation et exécution

```powershell
uv sync
.\demarrer.bat
docker ps
```

Vérifier que `lakehouse-spark-connect-1` est à l'état `Up`, puis ouvrir les
notebooks dans VS Code avec le noyau `.venv` du projet et les exécuter dans cet ordre :

1. `notebooks/devoir_afrimarketBronze.ipynb`
2. `notebooks/devoir_afrimarketSilver.ipynb`

Le notebook Silver lit la table Bronze dans le catalogue : il peut être relancé
seul tant que `lake.bronze.commandes_raw` existe (10 100 lignes).

## Contenu des notebooks

### Bronze

| Question | Travail réalisé |
|---|---|
| Q1 | Dépôt du CSV dans le bucket `lakehouse` (clé `landing/afrimarket/commandes/`) avec boto3, puis liste des objets avec leur taille |
| Q2 | Lecture PySpark avec un schéma explicite : 14 colonnes en STRING, en-tête sur la première ligne |
| Q3 | Colonnes techniques `_source_fichier`, `_date_ingestion`, `_num_ligne`, écriture dans `lake.bronze.commandes_raw` (Iceberg) |
| Q4 | Audit des doublons : 100 identifiants en double, 100 lignes en trop (chacun apparaît 2 fois) |
| Q5 | Anomalies sur `ville` (« Kinshassa », 605 lignes) et `statut_commande` (« retournée », 826 lignes), corrigées |
| Q6 | Incohérences catégorie / nom de produit : 439 lignes |

### Silver

| Question | Travail réalisé |
|---|---|
| Q7 | Fonction `dedoublonner(df)` (`Window` et `row_number`) : 10 000 lignes |
| Q8 | Typage avec `try_cast`, correction de `ville`, jointure avec `ref_villes`, contrôle des pays nuls, recalcul de `categorie`, normalisation du statut |
| Q9 | Corrections, indicateurs (`flag_prix_corrige`, `flag_remise_corrigee`), `motifs_rejet` (ARRAY<STRING>), séparation commandes / rejets |
| Q10 | Colonnes calculées (`montant_brut`, `ca_net`, `marge_contribution`, `annee_mois`) et `MERGE INTO lake.silver.commandes` |

## Résultats clés

| Indicateur | Valeur |
|---|---|
| Lignes dans la Bronze | 10 100 |
| Identifiants en double | 100 |
| Lignes après dédoublonnage | 10 000 |
| Lignes incohérentes catégorie / produit | 439 |
| Commandes valides (`lake.silver.commandes`) | 8 836 |
| Commandes rejetées (`lake.silver.commandes_rejets`) | 1 164 |
| Taux de rejet | 11,64 % |
| Conservation | 10 000 = 8 836 + 1 164 |

Motifs de rejet : `PRIX_SENTINELLE` (600) et `QUANTITE_NULLE` (600), dont 36 lignes
cumulent les deux. Corrections : 22 prix négatifs ramenés à leur valeur absolue,
600 remises négatives ramenées à 0.

## Partie A (QCM)

1. C (Zstd) 2. B (répartition de la lecture des partitions) 3. B (nettoyer, dédoublonner, typer) 4. C (ELT) 5. B (envoyer des messages vers les topics)

## Points d'attention

- **MERGE INTO** : sur cette plateforme, un `MERGE INTO` dont la source est une vue
  temporaire échoue (`INTERNAL_ERROR` de planification Spark Connect). Le résultat du
  calcul est donc écrit dans la table intermédiaire `lake.silver.commandes_stg`, puis
  fusionné depuis cette table. Le `MERGE` est idempotent : le relancer laisse
  8 836 lignes.
- **Table `ref_villes`** : fournie par le sujet ; elle a été recréée dans le notebook
  Silver pour pouvoir pratiquer le devoir.
- **Mode ajout de la Bronze** : la cellule d'écriture utilise `createOrReplace()`
  pour éviter de doubler les lignes si elle est relancée (le sujet demande `append`).
- **Mémoire** : arrêter les conteneurs inutiles (Kafka, Airflow, Spark Thrift) libère
  de la mémoire pour Spark Connect.