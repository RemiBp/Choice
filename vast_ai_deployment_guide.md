# Guide de Déploiement du Générateur de Posts sur Vast.ai

Ce guide explique comment déployer le générateur automatique de posts sur votre instance Vast.ai et comment corriger les erreurs de formatage dans le fichier setup_vast_ai.py.

## 1. Correction des Erreurs dans setup_vast_ai.py

Le fichier contient des erreurs de formatage au niveau des fonctions `print_header` et `print_step`. Voici comment les corriger:

1. Connectez-vous à votre instance Vast.ai
2. Ouvrez le fichier setup_vast_ai.py avec un éditeur:
   ```bash
   nano setup_vast_ai.py
   ```
3. Localisez les fonctions `print_header` et `print_step` (vers les lignes 368-376)
4. Remplacez ces fonctions par les versions corrigées suivantes:

```python
def print_header(message):
    """Affiche un en-tête avec formatage"""
    print(f"\n{BOLD}{BLUE}{'=' * 80}{RESET}")
    print(f"{BOLD}{BLUE}{'=' * 30} {message} {'=' * 30}{RESET}")
    print(f"{BOLD}{BLUE}{'=' * 80}{RESET}\n")

def print_step(message):
    """Affiche un message d'étape avec formatage"""
    print(f"\n{BOLD}{GREEN}===> {message}{RESET}")
```

La correction principale consiste à remplacer les `"\` et `\` utilisés pour les sauts de ligne par la séquence d'échappement standard `\n`.

## 2. Déploiement des Fichiers sur Vast.ai

### Fichiers à Déployer

Vous devez déployer ces 4 fichiers sur votre instance Vast.ai:

1. `post_generator.py` - Le générateur de posts principal
2. `run_post_generator.py` - Script de lancement du générateur
3. `POST_GENERATOR_README.md` - Documentation détaillée
4. `setup_vast_ai.py` - Script de configuration (avec les corrections ci-dessus)

### Structure des Répertoires

Sur votre instance Vast.ai, créez cette structure de répertoires:

```
/workspace/
├── scripts/
│   ├── PostGenerator/
│   │   ├── post_generator.py
│   │   └── run_post_generator.py
│   ├── (autres dossiers existants)
├── setup_vast_ai.py
└── POST_GENERATOR_README.md
```

### Méthode de Transfert

#### Option 1: Via SCP (depuis votre machine locale)

```bash
# Créer les répertoires nécessaires sur l'instance
ssh user@votre-instance-vast-ai "mkdir -p /workspace/scripts/PostGenerator"

# Transférer les fichiers
scp ../../choice_app/backend/scripts/vast_ai_scripts/post_generator.py user@votre-instance-vast-ai:/workspace/scripts/PostGenerator/
scp ../../choice_app/backend/scripts/vast_ai_scripts/run_post_generator.py user@votre-instance-vast-ai:/workspace/scripts/PostGenerator/
scp ../../choice_app/backend/scripts/vast_ai_scripts/POST_GENERATOR_README.md user@votre-instance-vast-ai:/workspace/
scp ../../choice_app/backend/scripts/vast_ai_scripts/setup_vast_ai.py user@votre-instance-vast-ai:/workspace/
```

#### Option 2: Via Interface Web Vast.ai

Si vous utilisez l'interface web Jupyter de Vast.ai:
1. Accédez à l'interface Jupyter
2. Créez les répertoires nécessaires avec le bouton "New" > "Folder"
3. Utilisez le bouton "Upload" pour télécharger chaque fichier dans le répertoire approprié

## 3. Configuration de l'Environnement

Après avoir déployé les fichiers et corrigé setup_vast_ai.py, exécutez la configuration:

```bash
cd /workspace
python setup_vast_ai.py --posts
```

Cette commande:
- Installera les dépendances requises
- Configurera le modèle DeepSeek
- Créera le script de lancement run_vast.py
- Créera les répertoires logs et checkpoints

## 4. Exécution du Générateur de Posts

Vous pouvez maintenant exécuter le générateur de posts de deux façons:

### Option 1: Via le Script Principal

```bash
# Exécution normale (actif entre 3h et 7h du matin)
python run_vast.py --posts

# Forcer l'exécution même en dehors des heures actives
python run_vast.py --posts --force

# Désactiver l'IA (génération de contenu plus simple)
python run_vast.py --posts --skip-ai
```

### Option 2: Directement via le Script Dédié

```bash
cd /workspace/scripts/PostGenerator
python run_post_generator.py --force
```

## 5. Vérification du Fonctionnement

Pour vérifier que tout fonctionne correctement:

### Consulter les Logs

```bash
cat /workspace/logs/posts_output.log
```

### Vérifier l'État des Checkpoints

```bash
python run_vast.py --status
```

### Vérifier la Base de Données

Si vous pouvez accéder à MongoDB depuis votre instance:

```bash
mongo choice_app --eval "db.Posts.find({is_automated: true}).sort({time_posted: -1}).limit(5).pretty()"
```

## 6. Automatisation avec Cron (Optionnel)

Pour que le système s'exécute automatiquement tous les jours à 3h00:

```bash
# Ouvrir l'éditeur crontab
crontab -e

# Ajouter cette ligne
0 3 * * * cd /workspace && python run_vast.py --posts >> /workspace/logs/cron_output.log 2>&1
```

## 7. Dépannage

Si vous rencontrez des problèmes:

1. **Erreur d'authentification DeepSeek**:
   - Vérifiez que DeepSeek est correctement installé avec `python -c "import deepseek; print(deepseek.__version__)"`
   - Essayez d'ajouter manuellement une clé API dans `post_generator.py`

2. **Erreur MongoDB "limit must be positive"**:
   - Vérifiez que toutes les collections MongoDB existent
   - Essayez avec l'option `--force` pour réinitialiser

3. **Erreur de chemin**:
   - Assurez-vous que tous les fichiers sont dans les bons répertoires
   - Vérifiez les permissions avec `ls -la /workspace/scripts/PostGenerator/`