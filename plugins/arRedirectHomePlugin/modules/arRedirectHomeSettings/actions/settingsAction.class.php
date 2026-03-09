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

class arRedirectHomeSettingsSettingsAction extends SettingsEditAction
{
    // Arrays not allowed in class constants
    public static $NAMES = [
        'redirect_home_information_object_id',
    ];

    public function earlyExecute()
    {
        parent::earlyExecute();

        $this->updateMessage = $this->i18n->__('Redirect home settings saved.');

        $this->settingDefaults = [
            'redirect_home_information_object_id' => '',
        ];
    }

    protected function addField($name)
    {
        if ('redirect_home_information_object_id' !== $name) {
            return;
        }

        // Build list of top-level information objects (children of ROOT)
        $choices = [
            '' => $this->i18n->__('(Do not redirect home)'),
        ];

        $root = QubitInformationObject::getRoot();

        foreach ($root->informationObjectsRelatedByparentId->orderBy('lft') as $io) {
            // Use ID as key and object string representation (title) as label
            $choices[$io->id] = (string) $io;
        }

        $this->form->setValidator(
            $name,
            new sfValidatorChoice(
                [
                    'choices' => array_keys($choices),
                    'required' => false,
                ]
            )
        );

        $this->form->setWidget(
            $name,
            new sfWidgetFormChoice(
                [
                    'choices' => $choices,
                ]
            )
        );
    }
}

