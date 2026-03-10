<?php

/*
 * This file is part of the Access to Memory (AtoM) software.
 *
 * Access to Memory (AtoM) is free software: you can redistribute it and/or
 * modify it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * Access to Memory (AtoM) is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * Access to Memory (AtoM).  If not, see <http://www.gnu.org/licenses/>.
 */

class arSaveOldSlugsPluginConfiguration extends sfPluginConfiguration
{
    public static $summary = 'Persist and resolve old slugs so that legacy URLs keep working after slug changes.';

    public static $version = '0.1.0';

    public function initialize()
    {
        // Sólo registramos el plugin cuando estamos en el contexto de una
        // aplicación Symfony completa.
        if (!$this->configuration instanceof sfApplicationConfiguration) {
            return;
        }
    }
}

