-- ========================================
-- SCHÉMA V2 - AVEC SOFT DELETE ET AUDIT
-- Remplace le schéma V1
-- ========================================

-- ========== MIGRATION: Ajouter colonnes de timestamp à books ==========
ALTER TABLE books ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE books ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE books ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- Mettre à jour les livres existants
UPDATE books SET created_at = COALESCE(created_at, NOW()), updated_at = COALESCE(updated_at, NOW()) WHERE created_at IS NULL OR updated_at IS NULL;

-- ========== MIGRATION: Ajouter colonnes de timestamp à groups ==========
ALTER TABLE groups ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- ========== MIGRATION: Ajouter colonnes de timestamp à classes ==========
ALTER TABLE classes ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE classes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE classes ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

UPDATE classes SET created_at = COALESCE(created_at, NOW()), updated_at = COALESCE(updated_at, NOW()) WHERE created_at IS NULL OR updated_at IS NULL;

-- ========== MIGRATION: Ajouter colonnes de timestamp à students ==========
ALTER TABLE students ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE students ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE students ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

UPDATE students SET created_at = COALESCE(created_at, NOW()), updated_at = COALESCE(updated_at, NOW()) WHERE created_at IS NULL OR updated_at IS NULL;

-- ========== MIGRATION: Ajouter colonnes de timestamp à borrow_history ==========
ALTER TABLE borrow_history ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- ========== TABLE: changelog (Audit trail) ==========
-- Enregistre toutes les modifications pour un sync propre
CREATE TABLE IF NOT EXISTS changelog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL, -- 'book', 'student', 'class', 'group', 'borrow_history'
  entity_id TEXT NOT NULL, -- isbn, id, key, etc
  operation TEXT NOT NULL, -- 'create', 'update', 'delete'
  changes JSONB, -- {"field": "old_value -> new_value"}
  created_by TEXT, -- user/device ID (optionnel)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  synced BOOLEAN DEFAULT FALSE,
  synced_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_changelog_entity ON changelog(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_changelog_synced ON changelog(synced, created_at DESC);

-- ========== VIEWS: Entités non supprimées (pour lectures normales) ==========
CREATE OR REPLACE VIEW books_active AS
SELECT * FROM books WHERE deleted_at IS NULL;

CREATE OR REPLACE VIEW classes_active AS
SELECT * FROM classes WHERE deleted_at IS NULL;

CREATE OR REPLACE VIEW students_active AS
SELECT * FROM students WHERE deleted_at IS NULL;

CREATE OR REPLACE VIEW groups_active AS
SELECT * FROM groups WHERE deleted_at IS NULL;

-- ========== TRIGGERS: Mettre à jour updated_at automatiquement ==========
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour books
DROP TRIGGER IF EXISTS books_updated_at_trigger ON books;
CREATE TRIGGER books_updated_at_trigger
  BEFORE UPDATE ON books
  FOR EACH ROW
  WHEN (OLD IS DISTINCT FROM NEW)
  EXECUTE FUNCTION update_updated_at();

-- Trigger pour classes
DROP TRIGGER IF EXISTS classes_updated_at_trigger ON classes;
CREATE TRIGGER classes_updated_at_trigger
  BEFORE UPDATE ON classes
  FOR EACH ROW
  WHEN (OLD IS DISTINCT FROM NEW)
  EXECUTE FUNCTION update_updated_at();

-- Trigger pour students
DROP TRIGGER IF EXISTS students_updated_at_trigger ON students;
CREATE TRIGGER students_updated_at_trigger
  BEFORE UPDATE ON students
  FOR EACH ROW
  WHEN (OLD IS DISTINCT FROM NEW)
  EXECUTE FUNCTION update_updated_at();

-- ========== FONCTIONS HELPER: Gestion des suppressions ==========

-- Marquer une entité comme supprimée (soft delete)
CREATE OR REPLACE FUNCTION soft_delete_book(isbn_param TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE books SET deleted_at = NOW() WHERE isbn = isbn_param AND deleted_at IS NULL;
  INSERT INTO changelog (entity_type, entity_id, operation) 
    VALUES ('book', isbn_param, 'delete');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION soft_delete_student(id_param TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE students SET deleted_at = NOW() WHERE id = id_param AND deleted_at IS NULL;
  INSERT INTO changelog (entity_type, entity_id, operation) 
    VALUES ('student', id_param, 'delete');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION soft_delete_class(id_param TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE classes SET deleted_at = NOW() WHERE id = id_param AND deleted_at IS NULL;
  INSERT INTO changelog (entity_type, entity_id, operation) 
    VALUES ('class', id_param, 'delete');
END;
$$ LANGUAGE plpgsql;

-- Obtenir le changelog non synchro
CREATE OR REPLACE FUNCTION get_pending_changes()
RETURNS TABLE(id UUID, entity_type TEXT, entity_id TEXT, operation TEXT, changes JSONB, created_at TIMESTAMP WITH TIME ZONE) AS $$
SELECT id, entity_type, entity_id, operation, changes, created_at 
FROM changelog 
WHERE synced = FALSE 
ORDER BY created_at ASC;
$$ LANGUAGE sql;

-- Marquer le changelog comme synchro
CREATE OR REPLACE FUNCTION mark_changelog_synced(changelog_ids UUID[])
RETURNS VOID AS $$
BEGIN
  UPDATE changelog SET synced = TRUE, synced_at = NOW() WHERE id = ANY(changelog_ids);
END;
$$ LANGUAGE plpgsql;

-- ========== INDEX supplémentaires pour performances ==========
CREATE INDEX IF NOT EXISTS idx_books_deleted_at ON books(deleted_at);
CREATE INDEX IF NOT EXISTS idx_classes_deleted_at ON classes(deleted_at);
CREATE INDEX IF NOT EXISTS idx_students_deleted_at ON students(deleted_at);
CREATE INDEX IF NOT EXISTS idx_groups_deleted_at ON groups(deleted_at);

-- ========== DONNÉES INITIALES ==========
INSERT INTO groups (key, title, color) VALUES
  ('jeunesse', 'Jeunesse', '#4CAF50'),
  ('roman', 'Roman', '#2196F3'),
  ('bd', 'Bandes Dessinées', '#FF9800'),
  ('documentaire', 'Documentaire', '#9C27B0'),
  ('autre', 'Autre', '#607D8B')
ON CONFLICT (key) DO NOTHING;

-- ========== RLS: Désactivé par défaut ==========
ALTER TABLE books DISABLE ROW LEVEL SECURITY;
ALTER TABLE groups DISABLE ROW LEVEL SECURITY;
ALTER TABLE classes DISABLE ROW LEVEL SECURITY;
ALTER TABLE students DISABLE ROW LEVEL SECURITY;
ALTER TABLE borrow_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE changelog DISABLE ROW LEVEL SECURITY;
