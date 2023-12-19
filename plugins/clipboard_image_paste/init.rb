#*******************************************************************************
# clipboard_image_paste Redmine plugin.
#
# Authors:
# - Richard Pecl & others (see README)
#
# Terms of use:
# - GNU GENERAL PUBLIC LICENSE Version 2
#*******************************************************************************

require 'redmine'
require 'dispatcher' unless Rails::VERSION::MAJOR >= 3

Redmine::Plugin.register :clipboard_image_paste do
  name        'Clipboard image paste'
  author      'Richard Pecl'
  description 'Paste cropped image from clipboard as attachment'
  url         'http://www.redmine.org/plugins/clipboard_image_paste'
  version     '1.13'
  requires_redmine :version_or_higher => '1.4.0'

  configfile = File.join(File.dirname(__FILE__), 'config', 'settings.yml')
  $clipboard_image_paste_config = YAML::load_file(configfile)

  redmineVer = Redmine::VERSION.to_a
  $clipboard_image_paste_has_jquery = redmineVer[0] > 2 || (redmineVer[0] == 2 && redmineVer[1] >= 2)
  $clipboard_image_paste_remove_alpha = redmineVer[0] < 2 || (redmineVer[0] == 2 && redmineVer[1] <= 5)
end

if Rails.version > '6.0' && Rails.autoloaders.zeitwerk_enabled?
    $LOAD_PATH << File.expand_path('../lib/clipboard_image_paste', __FILE__)
    require_dependency 'hooks'
    require_dependency 'attachment_patch'
elsif Rails::VERSION::MAJOR >= 3 && Rails::VERSION::MAJOR < 6
  Rails.configuration.to_prepare do
    require_dependency 'clipboard_image_paste/hooks'
    require_dependency 'clipboard_image_paste/attachment_patch'
  end
else
  Dispatcher.to_prepare :clipboard_image_paste do
    require_dependency 'clipboard_image_paste/hooks'
    require_dependency 'clipboard_image_paste/attachment_patch'
  end
end
