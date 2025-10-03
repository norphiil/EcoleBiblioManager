# Configuration Google Apps Script

## Instructions :

### **Étape 1 : Créer le Google Apps Script**

1. **Aller sur [script.google.com](https://script.google.com/)**
2. **Nouveau projet**
3. **Coller le code du fichier google_apps_script_api.js** que j'ai créé
4. **Modifier la ligne 12** :
   ```javascript
   const SPREADSHEET_ID = 'sheetID';
   ```
5. **Déployer :**
   - Cliquer sur "Déployer" > "Nouveau déploiement"
   - Type : "Application web"
   - Accès : "Tout le monde"
   - Cliquer sur "Déployer"
   - **Copier l'URL générée** (ressemble à `https://script.google.com/macros/s/XXX/exec`)

### **Étape 2 : Configurer l'application Flutter**

1. **Créer le fichier .env** (copier depuis .env.example)
2. **Ajouter l'URL du script** :
   ```env
   GOOGLE_APPS_SCRIPT_URL=https://script.google.com/macros/s/VOTRE_ID_SCRIPT/exec
   ```
