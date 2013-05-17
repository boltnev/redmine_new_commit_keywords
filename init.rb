require 'redmine'
require 'dispatcher'

Dispatcher.to_prepare :redmine_new_commit_keywords do

  require_dependency 'changeset'
  unless Changeset.included_modules.include? RedmineNewCommitKeywords::ChangesetPatch
    Changeset.send(:include, RedmineNewCommitKeywords::ChangesetPatch)
  end

end

Redmine::Plugin.register :redmine_new_commit_keywords do
  name 'Redmine New Commit Keywords plugin'
  author 'Elins'
  description 'This is a plugin for Redmine for default commit keywords extension'
  version '0.0.1'

  settings :default => {
      :regexp_to_change_status_by_commit => 'Статус|статус',
      :regexp_to_change_done_ratio_by_commit => 'Готовность|готовность',
      :regexp_to_refer_issue_by_commit => 'Задача|задача'
  }, :partial => 'settings/commit_regexp'
end

REPOSITORY_KEYWORDS = YAML.load_file(File.dirname(__FILE__) + '/config/keywords.yml')
