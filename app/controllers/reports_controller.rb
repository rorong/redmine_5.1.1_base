# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2023  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class ReportsController < ApplicationController
  menu_item :issues
  before_action :find_project, :authorize, :find_issue_statuses

  include ReportsHelper
  def issue_report
    with_subprojects = Setting.display_subprojects_issues?
    @issue_by = params[:tab]
    @result = get_report_detail(@issue_by, with_subprojects)

    respond_to do |format|
      format.html do
        render :template => "reports/issue_report"
      end
      format.csv do
        send_data(issue_report_to_csv(@result[:field_name], @result[:rows], @result[:data]),
          :type => 'text/csv; header=present',
          :filename => "report-#{@result[:detail]}.csv")
      end
      format.pdf do
        if params[:email_with_attachment]
          attachment = {}
          if params[:attachment_type] == 'csv'
            attachment[:filename] = "report-#{@result[:detail]}.csv"
            attachment[:content] = issue_report_to_csv(@result[:field_name], @result[:rows], @result[:data])
          else
            attachment[:filename] = "report-#{@result[:detail]}.pdf"
            attachment[:content] = render_to_string pdf: attachment[:filename], template: "reports/issue_report"
          end
          user_ids = params[:users] || [User.current.id]
          user_ids.each do |id|
            user = User.find(id)
            subject = params[:subject].present? ? params[:subject] : 'All Issue Attachment'
            Mailer.send_email_with_attachment(user, subject, attachment, params[:message])
          end

          flash[:notice] = 'Email sent with attachment successfully!'
          redirect_to request.referrer
        else
          render pdf: "report-#{@result[:detail]}", template: "reports/issue_report",disposition: 'attachment'
        end
      end
    end
  end

  def get_report_detail(issue_by, with_subprojects)
  result_hash = {}

  case issue_by
  when "version"
    result_hash[:rows] = @project.shared_versions.sorted + [Version.new(name: "[#{l(:label_none)}]")]
    result_hash[:data] = Issue.by_version(@project, with_subprojects)
    result_hash[:field_name] = "fixed_version_id"
  when "priority"
    result_hash[:rows] = IssuePriority.all.reverse
    result_hash[:data] = Issue.by_priority(@project, with_subprojects)
    result_hash[:field_name] = "priority_id"
  when "category"
    result_hash[:rows] = @project.issue_categories + [IssueCategory.new(name: "[#{l(:label_none)}]")]
    result_hash[:data] = Issue.by_category(@project, with_subprojects)
    result_hash[:field_name] = "category_id"
  when "assigned_to"
    result_hash[:rows] = (Setting.issue_group_assignment? ? @project.principals : @project.users).sorted + [User.new(firstname: "[#{l(:label_none)}]")]
    result_hash[:data] = Issue.by_assigned_to(@project, with_subprojects)
    result_hash[:field_name] = "assigned_to_id"
  when "author"
    result_hash[:rows] = @project.users.sorted
    result_hash[:data] = Issue.by_author(@project, with_subprojects)
    result_hash[:field_name] = "author_id"
  when "subproject"
    result_hash[:rows] = @project.descendants.visible
    result_hash[:data] = Issue.by_subproject(@project) || []
    result_hash[:field_name] = "project_id"
  else "tracker"
    result_hash[:rows] = @project.rolled_up_trackers(with_subprojects).visible
    result_hash[:data] = Issue.by_tracker(@project, with_subprojects)
    result_hash[:field_name] = "tracker_id"
  end
  result_hash[:detail] = issue_by || "tracker"

  result_hash
end

  def issue_report_details
    with_subprojects = Setting.display_subprojects_issues?
    case params[:detail]
    when "tracker"
      @field = "tracker_id"
      @rows = @project.rolled_up_trackers(with_subprojects).visible
      @data = Issue.by_tracker(@project, with_subprojects)
      @report_title = l(:field_tracker)
    when "version"
      @field = "fixed_version_id"
      @rows = @project.shared_versions.sorted + [Version.new(:name => "[#{l(:label_none)}]")]
      @data = Issue.by_version(@project, with_subprojects)
      @report_title = l(:field_version)
    when "priority"
      @field = "priority_id"
      @rows = IssuePriority.all.reverse
      @data = Issue.by_priority(@project, with_subprojects)
      @report_title = l(:field_priority)
    when "category"
      @field = "category_id"
      @rows = @project.issue_categories + [IssueCategory.new(:name => "[#{l(:label_none)}]")]
      @data = Issue.by_category(@project, with_subprojects)
      @report_title = l(:field_category)
    when "assigned_to"
      @field = "assigned_to_id"
      @rows = (Setting.issue_group_assignment? ? @project.principals : @project.users).sorted + [User.new(:firstname => "[#{l(:label_none)}]")]
      @data = Issue.by_assigned_to(@project, with_subprojects)
      @report_title = l(:field_assigned_to)
    when "author"
      @field = "author_id"
      @rows = @project.users.sorted
      @data = Issue.by_author(@project, with_subprojects)
      @report_title = l(:field_author)
    when "subproject"
      @field = "project_id"
      @rows = @project.descendants.visible
      @data = Issue.by_subproject(@project) || []
      @report_title = l(:field_subproject)
    else
      render_404
    end
    respond_to do |format|
      format.html
      format.csv do
        send_data(issue_report_details_to_csv(@field, @statuses, @rows, @data),
                  :type => 'text/csv; header=present',
                  :filename => "report-#{params[:detail]}.csv")
      end
    end
  end

  private

  def find_issue_statuses
    @statuses = @project.rolled_up_statuses.sorted.to_a
  end
end
