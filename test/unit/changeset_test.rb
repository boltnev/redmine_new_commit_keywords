# encoding: utf-8
require File.dirname(__FILE__) + '/../test_helper'

class ChangesetTest < ActiveSupport::TestCase
  
  fixtures :all
       
  # Тестирование новых ключевых слов фиксации.

  RESOLVED = IssueStatus.find_by_name("Решен")

  def setup

    @fix_keyword = Setting.commit_fix_keywords.split(",").first
    @repository = Project.find(1).repository
    @user = User.find(4)
    
    @issue1 = Issue.find(31)
    @issue2 = Issue.find(32)
    @issue3 = Issue.find(33)
    I18n::locale = :ru

  end

  def test_make_simple_commits

    @changeset = Changeset.create(:repository   => @repository,
                                  :revision     => 100,
                                  :committer    => @user.login,
                                  :committed_on => Time.now - 5,
                                  :comments     => "Задача = ##{@issue1.id}\n")

    
    @changeset.scan_comment_for_issue_ids


    assert_equal [@issue1], @changeset.issues

    @changeset2 = Changeset.create(:repository   => @repository,
                                  :revision     => 101,
                                  :committer    => @user.login,
                                  :committed_on => Time.now - 5,
                                  :comments     => "Задача = ##{@issue1.id}, Задача=##{@issue2.id}")


    @changeset2.scan_comment_for_issue_ids

    assert_equal [@issue1, @issue2], @changeset2.issues


    @changeset3 = Changeset.create(:repository   => @repository,
                                  :revision     => 102,
                                  :committer    => @user.login,
                                  :committed_on => Time.now - 5,
                                  :comments     => "Задача = ##{@issue1.id}, Задача=##{@issue2.id}, #{@fix_keyword} ##{@issue3.id}")

    @changeset3.scan_comment_for_issue_ids

    
    assert_equal [@issue3, @issue1, @issue2 ], @changeset3.issues


  end

  def test_done_ratio

    @changeset = Changeset.create(:repository   => @repository,
                                  :revision     => 100,
                                  :committer    => @user.login,
                                  :committed_on => Time.now - 5,
                                  :comments     => "Задача = ##{@issue1.id}, Готовность = 55%\n")


    @changeset.scan_comment_for_issue_ids

    assert 55, @issue1.reload.done_ratio
  end

  def test_make_commit_for_fixed_issue
  
    @changeset = Changeset.create(:repository   => @repository,
                                  :revision     => 103,
                                  :committer    => @user.login,
                                  :committed_on => Time.now - 5,
                                  :comments     => "Задача = ##{@issue1.id}, Статус = Решен\n")

    
    @changeset.scan_comment_for_issue_ids
    
    assert_equal [@issue1], @changeset.issues

    @issue1 = Issue.find(@issue1.id)
    
    assert_equal  RESOLVED, @issue1.status


  end

end
