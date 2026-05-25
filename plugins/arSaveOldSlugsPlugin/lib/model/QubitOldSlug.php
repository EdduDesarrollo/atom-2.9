<?php

/*
 * Helper ligero para trabajar con la tabla old_slug sin depender de que
 * exista un modelo Propel generado. La tabla se crea mediante la migración
 * arMigration9000 (ver docs/PLUGINS_DESARROLLADOS.md).
 */

class QubitOldSlug
{
    public $id;
    public $slug;
    public $objectId;
    public $createdAt;

    public function __construct(array $row = [])
    {
        if ($row) {
            $this->id = isset($row['id']) ? (int) $row['id'] : null;
            $this->slug = $row['slug'] ?? null;
            $this->objectId = isset($row['object_id']) ? (int) $row['object_id'] : null;
            $this->createdAt = $row['created_at'] ?? null;
        }
    }

    /**
     * Registra un slug antiguo para un objeto dado.
     */
    public static function record($slugText, $objectId)
    {
        $slugText = (string) $slugText;
        $objectId = (int) $objectId;

        if ('' === $slugText || 0 === $objectId) {
            return;
        }

        $databaseManager = new sfDatabaseManager(sfContext::getInstance()->getConfiguration());
        $conn = $databaseManager->getDatabase('propel')->getConnection();

        $stmt = $conn->prepare(
            'INSERT INTO old_slug (slug, object_id, created_at) VALUES (?, ?, NOW())'
        );

        try {
            $stmt->execute([$slugText, $objectId]);
        } catch (Exception $e) {
            // Si falla (por ejemplo, por una restricción de unicidad), no rompemos la petición.
        }
    }

    /**
     * Busca el slug en la tabla histórica y devuelve la entrada más reciente, o null.
     */
    public static function findBySlug($slugText)
    {
        $slugText = (string) $slugText;

        if ('' === $slugText) {
            return null;
        }

        $databaseManager = new sfDatabaseManager(sfContext::getInstance()->getConfiguration());
        $conn = $databaseManager->getDatabase('propel')->getConnection();

        $stmt = $conn->prepare(
            'SELECT id, slug, object_id, created_at
               FROM old_slug
              WHERE slug = ?
           ORDER BY created_at DESC
              LIMIT 1'
        );

        $stmt->execute([$slugText]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        if (false === $row) {
            return null;
        }

        return new QubitOldSlug($row);
    }
}

