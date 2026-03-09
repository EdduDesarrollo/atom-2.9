<?php decorate_with('layout_2col.php'); ?>

<?php slot('sidebar'); ?>

  <?php echo get_component('settings', 'menu'); ?>

<?php end_slot(); ?>

<?php slot('title'); ?>

  <h1><?php echo __('Redirect home settings'); ?></h1>

<?php end_slot(); ?>

<?php slot('content'); ?>

  <?php echo $form->renderGlobalErrors(); ?>

  <?php echo $form->renderFormTag(url_for(
    ['module' => 'arRedirectHomeSettings', 'action' => 'settings']
  )); ?>

    <?php echo $form->renderHiddenFields(); ?>

    <div id="content">

      <fieldset class="collapsible">

        <legend>
          <a href="#">
            <span class="element-invisible">
              <?php echo __('Hide'); ?>
            </span>
            <?php echo __('Redirect Home Settings'); ?>
          </a>
          <span class="summary"></span>
        </legend>

        <div class="fieldset-wrapper">

          <?php echo $form->redirect_home_information_object_id
              ->label(__('Fonds used as home redirect target'))
              ->help(__('Select which top-level fonds the home page should redirect to. Leave blank to keep the default home.'))
              ->renderRow(); ?>

        </div>

      </fieldset>

    </div>

    <section class="actions">
      <ul>
        <li>
          <input class="c-btn c-btn-submit" type="submit"
            value="<?php echo __('Save'); ?>"
          />
        </li>
      </ul>
    </section>

  </form>

<?php end_slot(); ?>

