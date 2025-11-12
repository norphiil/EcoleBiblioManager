-- ========================================
-- SCHÉMA SQL POUR SUPABASE (POSTGRESQL)
-- EBM - École Biblio Manager
-- Remplace Google Sheets
-- ========================================

-- ========== TABLE: books ==========
CREATE TABLE IF NOT EXISTS books (
  isbn TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  author TEXT NOT NULL,
  description TEXT,
  publisher TEXT,
  publish_year INTEGER,
  publish_place TEXT,
  page_count INTEGER,
  subjects JSONB DEFAULT '[]'::jsonb,
  cover_image_url TEXT,
  group_id TEXT,
  status TEXT NOT NULL DEFAULT 'available',  -- 'available' | 'borrowed' | 'reserved'
  borrowed_by TEXT,
  borrower_class_name TEXT,
  borrowed_date TIMESTAMP WITH TIME ZONE,
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_books_title ON books(title);
CREATE INDEX IF NOT EXISTS idx_books_author ON books(author);
CREATE INDEX IF NOT EXISTS idx_books_status ON books(status);
CREATE INDEX IF NOT EXISTS idx_books_group_id ON books(group_id);
CREATE INDEX IF NOT EXISTS idx_books_borrowed_by ON books(borrowed_by);

-- Trigger pour mettre à jour last_modified automatiquement
CREATE OR REPLACE FUNCTION update_books_last_modified()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_modified = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER books_last_modified_trigger
  BEFORE UPDATE ON books
  FOR EACH ROW
  EXECUTE FUNCTION update_books_last_modified();

-- ========== TABLE: groups (groupes de rangement) ==========
CREATE TABLE IF NOT EXISTS groups (
  key TEXT PRIMARY KEY,
  title TEXT NOT NULL UNIQUE,
  color TEXT DEFAULT '#2196F3',  -- Couleur hex
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_groups_title ON groups(title);

-- ========== TABLE: classes ==========
CREATE TABLE IF NOT EXISTS classes (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_classes_name ON classes(name);

-- ========== TABLE: students (élèves) ==========
CREATE TABLE IF NOT EXISTS students (
  id TEXT PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  class_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_students_first_name ON students(first_name);
CREATE INDEX IF NOT EXISTS idx_students_last_name ON students(last_name);
CREATE INDEX IF NOT EXISTS idx_students_class_id ON students(class_id);

-- ========== TABLE: borrow_history (historique d'emprunts) ==========
CREATE TABLE IF NOT EXISTS borrow_history (
  id TEXT PRIMARY KEY,
  book_isbn TEXT NOT NULL,
  borrower_name TEXT NOT NULL,
  borrower_class_id TEXT,
  borrowed_at TIMESTAMP WITH TIME ZONE NOT NULL,
  returned_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (book_isbn) REFERENCES books(isbn) ON DELETE CASCADE,
  FOREIGN KEY (borrower_class_id) REFERENCES classes(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_borrow_history_book_isbn ON borrow_history(book_isbn);
CREATE INDEX IF NOT EXISTS idx_borrow_history_borrower_name ON borrow_history(borrower_name);
CREATE INDEX IF NOT EXISTS idx_borrow_history_borrowed_at ON borrow_history(borrowed_at DESC);
CREATE INDEX IF NOT EXISTS idx_borrow_history_returned_at ON borrow_history(returned_at);

-- ========================================
-- DONNÉES INITIALES (OPTIONNEL)
-- ========================================

-- Groupes par défaut
INSERT INTO groups (key, title, color) VALUES
  ('jeunesse', 'Jeunesse', '#4CAF50'),
  ('roman', 'Roman', '#2196F3'),
  ('bd', 'Bandes Dessinées', '#FF9800'),
  ('documentaire', 'Documentaire', '#9C27B0'),
  ('autre', 'Autre', '#607D8B')
ON CONFLICT (key) DO NOTHING;

-- ========================================
-- POLITIQUES RLS (ROW LEVEL SECURITY)
-- ========================================
-- À activer selon vos besoins de sécurité

-- Désactiver RLS pour commencer (mode public)
ALTER TABLE books DISABLE ROW LEVEL SECURITY;
ALTER TABLE groups DISABLE ROW LEVEL SECURITY;
ALTER TABLE classes DISABLE ROW LEVEL SECURITY;
ALTER TABLE students DISABLE ROW LEVEL SECURITY;
ALTER TABLE borrow_history DISABLE ROW LEVEL SECURITY;

-- Si vous voulez activer RLS plus tard (accès authentifié uniquement) :
/*
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all operations" ON books FOR ALL USING (true);

ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all operations" ON groups FOR ALL USING (true);

ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all operations" ON classes FOR ALL USING (true);

ALTER TABLE students ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all operations" ON students FOR ALL USING (true);

ALTER TABLE borrow_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all operations" ON borrow_history FOR ALL USING (true);
*/

-- ========================================
-- NOTES D'UTILISATION
-- ========================================
/*
1. Copiez ce script dans le SQL Editor de Supabase
2. Exécutez-le pour créer toutes les tables
3. Vérifiez dans Table Editor que les tables sont créées
4. Les triggers automatiques mettront à jour last_modified
5. Les index amélioreront les performances des requêtes
6. RLS est désactivé par défaut (accès public via anon key)

STRUCTURE DES DONNÉES:
- books: Tous les livres de la bibliothèque
- groups: Catégories de rangement (étagères)
- classes: Classes d'élèves
- students: Liste des élèves avec leur classe
- borrow_history: Journal de tous les emprunts/retours

MIGRATION DEPUIS GOOGLE SHEETS:
Pour migrer vos données existantes:
1. Exportez chaque feuille Google Sheets en CSV
2. Utilisez l'import CSV de Supabase (Table Editor > Import Data)
3. Ou utilisez l'application Flutter pour sync initiale
*/
