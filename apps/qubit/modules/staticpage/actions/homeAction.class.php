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

class StaticPageHomeAction extends StaticPageIndexAction
{
    public function execute($request)
    {
        // If the redirect-home plugin is enabled and a target fonds has been
        // configured, redirect there instead of showing the static home page.
        $configuration = $this->getContext()->getConfiguration();

        if ($configuration->isPluginEnabled('arRedirectHomePlugin')) {
            $setting = QubitSetting::getByName('redirect_home_information_object_id');

            if (null !== $setting && null !== $setting->id) {
                $value = $setting->getValue(['sourceCulture' => true]);

                if ('' !== (string) $value) {
                    $targetId = (int) $value;

                    if (QubitInformationObject::ROOT_ID !== $targetId) {
                        $fonds = QubitInformationObject::getById($targetId);

                        if (null !== $fonds && null !== $fonds->id) {
                            $this->redirect([$fonds, 'module' => 'informationobject']);
                        }
                    }
                }
            }
        }

        parent::execute($request);
    }
}
