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

class arRedirectHomeIndexAction extends sfAction
{
    public function execute($request)
    {
        // Read configured target fonds ID
        $setting = QubitSetting::getByName('redirect_home_information_object_id');

        $targetId = null;
        if (null !== $setting && null !== $setting->id) {
            $value = $setting->getValue(['sourceCulture' => true]);

            if ('' !== (string) $value) {
                $targetId = (int) $value;
            }
        }

        if (null !== $targetId && QubitInformationObject::ROOT_ID !== $targetId) {
            $fonds = QubitInformationObject::getById($targetId);

            if (null !== $fonds && null !== $fonds->id) {
                $this->redirect([$fonds, 'module' => 'informationobject']);
            }
        }

        // Fallback to default home behavior when there is no valid configuration.
        // The default "homepage" route passes slug=home to staticpage/home, así que
        // replicamos ese parámetro explícitamente antes de hacer forward.
        $request->setParameter('slug', 'home');
        $this->forward('staticpage', 'home');
    }
}

