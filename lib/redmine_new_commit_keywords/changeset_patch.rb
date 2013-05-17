module RedmineNewCommitKeywords
  module ChangesetPatch
    def self.included(base)

      unloadable

      base.send(:include, InstanceMethods)
      base.extend(ClassMethods)
      base.class_eval do
        alias_method_chain :scan_comment_for_issue_ids, :additional_keywords

        # Находит все задачи, указанные в комментарии к фиксации
        def find_referenced_issue_by_id(id)

          return nil if id.blank?

          issue = Issue.find_by_id(id.to_i, :include => :project)

          if issue
            issue = nil if issue.project.nil?
          end

          issue

        end

        private :find_referenced_issue_by_id

      end

    end

    module ClassMethods

      # Методы, возвращают регулярные выражения для
      # 1) Связи с задачами
      # #7784, #8772
      def issue_re
        regexp =  Rails::Plugin::REPOSITORY_KEYWORDS["regexp"]["refer_issue_by_commit"]
        /(?:#{regexp})[\s]*=[\s]*#?[\d]+/i
      end

      # 2) Изменения статуса
      # Буквы ё и Ё в названиях статусов
      def issue_status_re
        regexp =  Rails::Plugin::REPOSITORY_KEYWORDS["regexp"]["change_status_by_commit"]

        all_statuses_names = IssueStatus.all.map do |status|
          status_names = [status.name]
          if status.name.include?('ё')
            status_names << status.name.gsub('ё', 'е')
          end
          if status.name.include?('Ё')
            status_names << status.name.gsub('Ё', 'Е')
          end
          status_names.join('|')
        end

        /(?:#{regexp})[\s]*=[\s]*(?:#{all_statuses_names.join('|')})/i
      end

      # 3) Изменения процента готовности
      def done_ratio_re
        regexp = Rails::Plugin::REPOSITORY_KEYWORDS["regexp"]["change_done_ratio_by_commit"]
        /(?:#{regexp})[\s]*=[\s]*[\d]+/i
      end

    end

    module InstanceMethods

      ## Необходимая константа из Changeset
      ## (#7784)
      TIMELOG_RE = Changeset::TIMELOG_RE

      ## Переопределение стандартного метода для работы с новыми ключевыми
      ## словами для фиксаций.
      ## (#7784)
      def scan_comment_for_issue_ids_with_additional_keywords
        return if comments.blank?
        begin
          User.current = user

          # keywords used to reference issues
          ref_keywords = Setting.commit_ref_keywords.downcase.split(',').collect(&:strip)
          ref_keywords_any = ref_keywords.delete('*')
          # keywords used to fix issues
          fix_keywords = Setting.commit_fix_keywords.downcase.split(',').collect(&:strip)

          kw_regexp = (ref_keywords + fix_keywords).collect { |kw| Regexp.escape(kw) }.join('|')

          referenced_issues = []

          fixed_issues = []

          comments.scan(/([\s\(\[,-]|^)((#{kw_regexp})[\s:]+)?(#\d+(\s+@#{TIMELOG_RE})?([\s,;&]+#\d+(\s+@#{TIMELOG_RE})?)*)(?=[[:punct:]]|\s|<|$)/i) do |match|
            action, refs = match[2], match[3]
            next unless action.present? || ref_keywords_any

            refs.scan(/#(\d+)(\s+@#{TIMELOG_RE})?/).each do |m|
              issue, hours = find_referenced_issue_by_id(m[0].to_i), m[2]
              if issue
                referenced_issues << issue
                fix_issue(issue) if fix_keywords.include?(action.to_s.downcase)
                fixed_issues << issue if fix_keywords.include?(action.to_s.downcase)
                log_time(issue, hours) if hours && Setting.commit_logtime_enabled?
              end
            end
          end

          comments.scan(Changeset.issue_re) do |match|
            issue_id = match.scan(/[\d]+/).first
            issue = find_referenced_issue_by_id(issue_id.to_i)
            referenced_issues << issue
          end

          issue_to_change = \
                  referenced_issues.select { |i| !fixed_issues.index(i) }.last

          if issue_to_change
            issue_to_change.init_journal(user)

            comments.scan(Changeset.done_ratio_re) do |match|

              update_related_issue_done_ratio(issue_to_change, match)

              @done_ratio_changed = true
            end

            comments.scan(Changeset.issue_status_re) do |match|

              update_related_issue_status(issue_to_change, match)

              @status_changed = true

            end

            if (@status_changed || @done_ratio_changed)
              issue_to_change.save
            end
          end

          referenced_issues.uniq!
          self.issues = referenced_issues unless referenced_issues.empty?
        rescue => e
          debugger
          puts e.backtrace
        ensure
          User.current = AnonymousUser.first
        end

      end

      ## Метод для изменения процента готовности по сообщению фиксации
      ## (#7784)
      def update_related_issue_done_ratio(issue, match)
        issue.done_ratio = match.split(/[\s]*=[\s]*/).last.to_i
      end

      ## Метод для изменения статуса по сообщению фиксации
      ## (#7784)
      def update_related_issue_status(issue, match)
        status_to_change = \
                       IssueStatus.find_by_name(match.split(/[\s]*=[\s]*/).last)

        if issue.new_statuses_allowed_to(user).index(status_to_change)

          issue.status = status_to_change

        end
      end

    end

  end
end
