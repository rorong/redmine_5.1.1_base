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

module ReportsHelper

  def aggregate(data, criteria)
    a = 0
    data.each do |row|
      match = 1
      reject_criteria = ["1-week", "2-week", "3-week", "4-plus-week"]
      criteria.reject { |key, _| reject_criteria.include?(key) }.each do |k, v|
        unless (row[k].to_s == v.to_s) || (k == 'closed' && (v == 0 ? ['f', false] : ['t', true]).include?(row[k]))
          match = 0
        end
      end unless criteria.nil?

      if match == 1
        if criteria["1-week"]
          a = a + row["1-week"].to_i
        elsif criteria["2-week"]
          a = a + row["2-week"].to_i
        elsif criteria["3-week"]
          a = a + row["3-week"].to_i
        elsif criteria["4-plus-week"]
          a = a + row["4-plus-week"].to_i
        else
          a = a + row["total"].to_i
        end
      end

    end unless data.nil?
    a
  end

  def aggregate_link(data, criteria, *args)
    a = aggregate data, criteria
    a > 0 ? link_to(h(a), *args) : '-'
  end

  def aggregate_path(project, field, row, options={})
    parameters = {:set_filter => 1, :subproject_id => '!*', field => (row.id || '!*')}.merge(options)
    project_issues_path(row.is_a?(Project) ? row : project, parameters)
  end

  def issue_report_details_to_csv(field_name, statuses, rows, data)
    Redmine::Export::CSV.generate(:encoding => params[:encoding]) do |csv|
      # csv headers
      headers = [''] + statuses.map(&:name) + [l(:label_open_issues_plural), l(:label_closed_issues_plural), l(:label_total)]
      csv << headers

      # csv lines
      rows.each do |row|
        csv <<
          [row.name] +
          statuses.map{|s| aggregate(data, { field_name => row.id, 'status_id' => s.id })} +
          [aggregate(data, { field_name => row.id, 'closed' => 0 })] +
          [aggregate(data, { field_name => row.id, 'closed' => 1 })] +
          [aggregate(data, { field_name => row.id })]
      end
    end
  end

  def issue_report_to_csv(field_name, rows, data)
    Redmine::Export::CSV.generate(:encoding => params[:encoding]) do |csv|
      # csv headers
      headers = [''] + ["0-7 days", "7-14 days", "14-28 days", ">28 days", l(:label_total)]
      csv << headers

      # csv lines
      rows.each do |row|
        csv <<
          [row.name] +
          [aggregate(data, { field_name => row.id, "closed" => 0, "1-week" => true })] +
          [aggregate(data, { field_name => row.id, "closed" => 0, "2-week" => true })] +
          [aggregate(data, { field_name => row.id, "closed" => 0, "3-week" => true })] +
          [aggregate(data, { field_name => row.id, "closed" => 0, "4-plus-week" => true })] +
          [aggregate(data, { field_name => row.id })]
      end
    end
  end

  def issue_report_tabs
    tabs =
      [
        {:name => 'tracker', :onclick => 'report/issue_report', :label => "label_tracker"},
        {:name => 'version', :onclick => 'report/issue_report', :label => "label_version"},
        {:name => 'priority', :onclick => 'report/issue_report',
         :label => "label_priority"},
        {:name => 'category', :onclick => 'report/issue_report', :label => "label_category"},
        {:name => 'assigned_to', :onclick => 'report/issue_report', :label => "label_assigned_to"},
        {:name => 'author', :onclick => 'report/issue_report', :label => "label_author"}
      ]
    tabs << {:name => 'subproject', :onclick => 'report/issue_report', :label => "label_subproject"} if @project.children.any?
    tabs
  end
end
