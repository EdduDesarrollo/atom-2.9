<?php

/*
 * This file is part of the Access to Memory (AtoM) software.
 *
 * Access to Memory (AtoM) is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Access to Memory (AtoM) is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Access to Memory (AtoM).  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * Migración AGU (custom): tabla old_slug para arSaveOldSlugsPlugin.
 *
 * El número 9000 reserva un rango alto para migraciones propias de AGU y evita
 * colisionar con arMigration0194, arMigration0195, etc. que añade Artefactual
 * en futuras versiones de AtoM. El archivo DEBE llamarse arMigration9000.class.php
 * y la clase arMigration9000 (convención de tools:upgrade-sql).
 *
 * @package    AccesstoMemory
 * @subpackage migration
 */
class arMigration9000
{
    public const VERSION = 9000;
    public const MIN_MILESTONE = 2;

    public function up($configuration)
    {
        if ($this->isAlreadyApplied()) {
            return true;
        }

        $sql = <<<'SQL'
CREATE TABLE IF NOT EXISTS `old_slug` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `slug` VARCHAR(255) NOT NULL,
  `object_id` INT UNSIGNED NOT NULL,
  `created_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_old_slug_slug` (`slug`),
  KEY `idx_old_slug_object` (`object_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
SQL;

        QubitPdo::modify($sql);

        return true;
    }

    /**
     * Idempotente: upgrade-sql puede volver a invocar esta migración porque el
     * contador de versión de BD sigue en ~194 y VERSION es 9000.
     */
    private function isAlreadyApplied()
    {
        $sql = "SHOW TABLES LIKE 'old_slug'";

        return false !== QubitPdo::fetchColumn($sql);
    }
}
