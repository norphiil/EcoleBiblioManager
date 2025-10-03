/**
 * API Google Apps Script pour EBM (École Biblio Manager)
 * 
 * Ce script permet à l'application Flutter de lire/écrire dans Google Sheets
 * sans authentification OAuth complexe.
 * 
 * Instructions d'installation :
 * 1. Ouvrir https://script.google.com/
 * 2. Nouveau projet
 * 3. Coller ce code
 * 4. Remplacer SPREADSHEET_ID par votre ID de feuille
 * 5. Déployer > Nouveau déploiement > Application web
 * 6. Accès : "Tout le monde"
 * 7. Copier l'URL de déploiement
 */

// REMPLACER PAR VOTRE ID DE FEUILLE GOOGLE SHEETS
const SPREADSHEET_ID = '17EjJAybIlPFzfbXdZ02Kyf5eYE-BStF0Ht1HWxEdKMo';

// Noms des feuilles
const SHEETS = {
  BOOKS: 'Livres',
  GROUPS: 'Groupes'
};

/**
 * Point d'entrée principal - gère toutes les requêtes
 */
function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const { action, sheet, params } = data;
    
    switch (action) {
      case 'test':
        return createResponse({ status: 'success', message: 'API fonctionnelle' });
        
      case 'getAll':
        return createResponse(getAllData(sheet));
        
      case 'add':
        return createResponse(addRow(sheet, params.data || params));
        
      case 'update':
        return createResponse(updateRow(sheet, params.id, params.data));
        
      case 'delete':
        return createResponse(deleteRow(sheet, params.id));
        
      case 'search':
        return createResponse(searchRows(sheet, params));
        
      case 'initializeSheets':
        return createResponse(initializeAllSheets());
        
      default:
        throw new Error(`Action non supportée: ${action}`);
    }
    
  } catch (error) {
    return createResponse({ error: error.message }, 400);
  }
}

/**
 * Gère les requêtes GET (pour les tests et comme fallback pour POST)
 */
function doGet(e) {
  // Si on a des paramètres, c'est un appel API via GET (fallback pour POST)
  if (e.parameter && e.parameter.action) {
    try {
      const action = e.parameter.action;
      const sheet = e.parameter.sheet || '';
      const params = e.parameter.params ? JSON.parse(e.parameter.params) : {};
      
      switch (action) {
        case 'test':
          return createResponse({ status: 'success', message: 'API fonctionnelle' });
          
        case 'getAll':
          return createResponse(getAllData(sheet));
          
        case 'add':
          return createResponse(addRow(sheet, params.data || params));
          
        case 'update':
          return createResponse(updateRow(sheet, params.id, params.data));
          
        case 'delete':
          return createResponse(deleteRow(sheet, params.id));
          
        case 'search':
          return createResponse(searchRows(sheet, params));
          
        case 'initializeSheets':
          return createResponse(initializeAllSheets());
          
        default:
          throw new Error(`Action non supportée: ${action}`);
      }
    } catch (error) {
      return createResponse({ error: error.message }, 400);
    }
  }
  
  // Sinon, c'est juste un test de connexion
  return createResponse({ 
    status: 'success', 
    message: 'EBM Google Sheets API est active',
    timestamp: new Date().toISOString()
  });
}

/**
 * Initialise toutes les feuilles avec les en-têtes appropriés
 */
function initializeAllSheets() {
  const spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
  
  const results = {};
  
  // Initialise la feuille des livres (utilise isbn comme identifiant unique)
  results.books = initializeSheet(spreadsheet, SHEETS.BOOKS, [
    'isbn', 'title', 'author', 'publisher', 'publishYear', 
    'publishPlace', 'subjects', 'pageCount', 'coverImageUrl', 
    'groupId', 'status', 'borrowedBy', 'borrowedDate', 'dueDate', 
    'createdAt', 'updatedAt'
  ]);
  
  // Initialise la feuille des groupes
  results.groups = initializeSheet(spreadsheet, SHEETS.GROUPS, [
    'id', 'title', 'key', 'logoPath', 'keywords', 'description', 
    'createdAt', 'updatedAt'
  ]);
  
  return results;
}

/**
 * Initialise une feuille spécifique
 */
function initializeSheet(spreadsheet, sheetName, headers) {
  try {
    let sheet = spreadsheet.getSheetByName(sheetName);
    
    // Crée la feuille si elle n'existe pas
    if (!sheet) {
      sheet = spreadsheet.insertSheet(sheetName);
    }
    
    // Ajoute les en-têtes si la feuille est vide
    const range = sheet.getRange(1, 1, 1, headers.length);
    const existingHeaders = range.getValues()[0];
    
    if (existingHeaders.every(cell => cell === '')) {
      range.setValues([headers]);
      
      // Style des en-têtes
      range.setFontWeight('bold');
      range.setBackground('#4285f4');
      range.setFontColor('white');
    }
    
    return { 
      status: 'success', 
      message: `Feuille ${sheetName} initialisée`,
      headers: headers
    };
    
  } catch (error) {
    return { 
      status: 'error', 
      message: `Erreur lors de l'initialisation de ${sheetName}: ${error.message}`
    };
  }
}

/**
 * Récupère toutes les données d'une feuille
 */
function getAllData(sheetName) {
  const spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
  const sheet = spreadsheet.getSheetByName(sheetName);
  
  if (!sheet) {
    throw new Error(`Feuille '${sheetName}' non trouvée`);
  }
  
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  const rows = data.slice(1);
  
  return {
    status: 'success',
    message: 'Données récupérées',
    data: rows.map(row => {
      const obj = {};
      headers.forEach((header, index) => {
        // Forcer l'ISBN en chaîne pour éviter les problèmes de comparaison
        obj[header] = (header === 'isbn') ? String(row[index] || '') : (row[index] || '');
      });
      return obj;
    })
  };
}

/**
 * Ajoute une nouvelle ligne
 */
function addRow(sheetName, rowData) {
  const spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
  const sheet = spreadsheet.getSheetByName(sheetName);
  
  if (!sheet) {
    throw new Error(`Feuille '${sheetName}' non trouvée`);
  }
  
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  
  // Pour les livres, l'ISBN est l'identifiant unique
  // Pour les groupes, on génère toujours un ID
  let identifierField = 'id';
  let identifierValue = rowData.id;
  
  if (sheetName === SHEETS.BOOKS) {
    identifierField = 'isbn';
    identifierValue = rowData.isbn;
    
    if (!identifierValue) {
      throw new Error('ISBN obligatoire pour ajouter un livre');
    }
  } else {
    // Pour les groupes, génère un ID si pas fourni
    if (!identifierValue) {
      identifierValue = Utilities.getUuid();
      rowData.id = identifierValue;
    }
  }
  
  identifierValue = String(identifierValue);
  
  // VÉRIFICATION : Si l'identifiant existe déjà, retourner l'objet existant (idempotence)
  const identifierIndex = headers.indexOf(identifierField);
  if (identifierIndex !== -1) {
    const data = sheet.getDataRange().getValues();
    const existingRowIndex = data.findIndex((row, index) => 
      index > 0 && String(row[identifierIndex]) === identifierValue
    );
    
    if (existingRowIndex !== -1) {
      // L'identifiant existe déjà, retourner l'objet existant au lieu de créer un doublon
      const existingRow = data[existingRowIndex];
      const existingObj = {};
      headers.forEach((header, index) => {
        existingObj[header] = (header === 'isbn' || header === 'id') ? String(existingRow[index] || '') : (existingRow[index] || '');
      });
      
      return { 
        status: 'success', 
        message: 'Objet déjà existant (idempotence)',
        data: existingObj
      };
    }
  }
  
  const values = headers.map(header => rowData[header] || '');
  
  // Ajoute les timestamps
  const now = new Date().toISOString();
  const createdAtIndex = headers.indexOf('createdAt');
  const updatedAtIndex = headers.indexOf('updatedAt');
  
  if (createdAtIndex !== -1) {
    values[createdAtIndex] = now;
    rowData.createdAt = now;
  }
  if (updatedAtIndex !== -1) {
    values[updatedAtIndex] = now;
    rowData.updatedAt = now;
  }
  
  sheet.appendRow(values);
  
  // Retourne l'objet complet
  return { 
    status: 'success', 
    message: 'Ligne ajoutée',
    data: rowData
  };
}

/**
 * Met à jour une ligne existante
 */
function updateRow(sheetName, id, newData) {
  const spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
  const sheet = spreadsheet.getSheetByName(sheetName);
  
  if (!sheet) {
    throw new Error(`Feuille '${sheetName}' non trouvée`);
  }
  
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  
  // Pour les livres, utilise isbn comme identifiant, sinon id
  const identifierField = (sheetName === SHEETS.BOOKS) ? 'isbn' : 'id';
  const identifierIndex = headers.indexOf(identifierField);
  
  if (identifierIndex === -1) {
    throw new Error(`Colonne ${identifierField} non trouvée`);
  }
  
  // Trouve la ligne à mettre à jour (comparaison en string pour éviter les problèmes de type)
  const rowIndex = data.findIndex((row, index) => index > 0 && String(row[identifierIndex]) === String(id));
  
  if (rowIndex === -1) {
    throw new Error(`Ligne avec ID ${id} non trouvée`);
  }
  
  // Met à jour les données
  const updatedValues = [...data[rowIndex]];
  Object.keys(newData).forEach(key => {
    const columnIndex = headers.indexOf(key);
    if (columnIndex !== -1) {
      // Forcer l'ID en chaîne pour éviter les problèmes de type
      updatedValues[columnIndex] = (key === 'id') ? String(newData[key]) : newData[key];
    }
  });
  
  // Met à jour updatedAt
  const updatedAtIndex = headers.indexOf('updatedAt');
  const now = new Date().toISOString();
  if (updatedAtIndex !== -1) {
    updatedValues[updatedAtIndex] = now;
  }
  
  sheet.getRange(rowIndex + 1, 1, 1, headers.length).setValues([updatedValues]);
  
  // Construire l'objet de retour avec toutes les données
  const resultData = {};
  headers.forEach((header, index) => {
    resultData[header] = updatedValues[index];
  });
  
  return { 
    status: 'success', 
    message: 'Ligne mise à jour',
    data: resultData
  };
}

/**
 * Supprime une ligne
 */
function deleteRow(sheetName, id) {
  const spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
  const sheet = spreadsheet.getSheetByName(sheetName);
  
  if (!sheet) {
    throw new Error(`Feuille '${sheetName}' non trouvée`);
  }
  
  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  
  // Pour les livres, utilise isbn comme identifiant, sinon id
  const identifierField = (sheetName === SHEETS.BOOKS) ? 'isbn' : 'id';
  const identifierIndex = headers.indexOf(identifierField);
  
  if (identifierIndex === -1) {
    throw new Error(`Colonne ${identifierField} non trouvée`);
  }
  
  // Trouve la ligne à supprimer (comparaison en string pour éviter les problèmes de type)
  const rowIndex = data.findIndex((row, index) => index > 0 && String(row[identifierIndex]) === String(id));
  
  if (rowIndex === -1) {
    throw new Error(`Ligne avec ID ${id} non trouvée`);
  }
  
  sheet.deleteRow(rowIndex + 1);
  
  return { 
    status: 'success', 
    message: 'Ligne supprimée' 
  };
}

/**
 * Recherche dans une feuille
 */
function searchRows(sheetName, searchParams) {
  const allData = getAllData(sheetName);
  
  let filteredData = allData.data;
  
  // Applique les filtres
  Object.keys(searchParams).forEach(key => {
    if (searchParams[key]) {
      filteredData = filteredData.filter(row => {
        const value = String(row[key] || '').toLowerCase();
        const search = String(searchParams[key]).toLowerCase();
        return value.includes(search);
      });
    }
  });
  
  return {
    status: 'success',
    message: `${filteredData.length} résultat(s) trouvé(s)`,
    data: filteredData
  };
}

/**
 * Crée une réponse JSON
 */
function createResponse(data, status = 200) {
  const output = ContentService.createTextOutput(JSON.stringify(data));
  output.setMimeType(ContentService.MimeType.JSON);
  
  if (status !== 200) {
    // Pour les erreurs, on retourne quand même 200 mais avec le statut dans les données
    data.httpStatus = status;
  }
  
  return output;
}