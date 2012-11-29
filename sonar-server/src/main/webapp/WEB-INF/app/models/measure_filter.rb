#
# Sonar, entreprise quality control tool.
# Copyright (C) 2008-2012 SonarSource
# mailto:contact AT sonarsource DOT com
#
# Sonar is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# Sonar is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with Sonar; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02
#
require 'set'
class MeasureFilter < ActiveRecord::Base

  # Row in the table of results
  class Result
    attr_reader :snapshot, :measures_by_metric, :links

    def initialize(snapshot)
      @snapshot = snapshot
      @measures_by_metric = {}
      @links = nil
    end

    def resource
      snapshot.resource
    end

    # For internal use
    def add_measure(measure)
      @measures_by_metric[measure.metric] = measure
    end

    # For internal use
    def add_link(link)
      @links ||= []
      @links << link
    end

    def measure(metric)
      @measures_by_metric[metric]
    end

    def measures
      @measures_by_metric.values
    end
  end

  CRITERIA_SEPARATOR = '|'
  CRITERIA_KEY_VALUE_SEPARATOR = ','

  belongs_to :user
  has_many :measure_filter_favourites, :dependent => :delete_all

  validates_presence_of :name, :message => Api::Utils.message('measure_filter.missing_name')
  validates_length_of :name, :maximum => 100, :message => Api::Utils.message('measure_filter.name_too_long')
  validates_length_of :description, :allow_nil => true, :maximum => 4000

  attr_reader :pagination, :security_exclusions, :base_result, :results, :display

  def sort_key
    criteria['sort']
  end

  def sort_asc?
    criteria['asc']=='true'
  end

  # array of the metrics to use when loading measures
  def metrics
    @metrics ||= []
  end

  def metrics=(array)
    @metrics = array
  end

  def require_links=(flag)
    @require_links=flag
  end

  # boolean flag that indicates if project links should be loaded
  def require_links?
    @require_links
  end

  def criteria(key=nil)
    @criteria ||= {}
    if key
      @criteria[key.to_s]
    else
      @criteria
    end
  end

  def criteria=(hash)
    @criteria = {}
    hash.each_pair do |k, v|
      if k && v && !v.empty? && v!=['']
        @criteria[k.to_s]=v
      end
    end
  end

  def load_criteria_from_data
    if self.data
      @criteria = self.data.split(CRITERIA_SEPARATOR).inject({}) do |h, s|
        k, v=s.split('=')
        if k && v
          v=v.split(CRITERIA_KEY_VALUE_SEPARATOR) if v.include?(CRITERIA_KEY_VALUE_SEPARATOR)
          h[k]=v
        end
        h
      end
    else
      @criteria = {}
    end
  end

  def convert_criteria_to_data
    string_data = []
    if @criteria
      @criteria.each_pair do |k, v|
        string_value = (v.is_a?(String) ? v : v.join(CRITERIA_KEY_VALUE_SEPARATOR))
        string_data << "#{k}=#{string_value}"
      end
    end
    self.data = string_data.join(CRITERIA_SEPARATOR)
  end

  def enable_default_display
    set_criteria_default_value('display', 'list')
  end

  # ==== Options
  # :user : the authenticated user
  def execute(controller, options={})
    init_results
    init_display(options)
    user = options[:user]
    rows=Api::Utils.java_facade.executeMeasureFilter2(criteria, (user ? user.id : nil))
    snapshot_ids = filter_authorized_snapshot_ids(rows, controller)
    load_results(snapshot_ids)
    self
  end

  # API used by Displays
  def set_criteria_value(key, value)
    if value
      @criteria[key.to_s]=value
    else
      @criteria.delete(key)
    end
  end

  # API used by Displays
  def set_criteria_default_value(key, value)
    set_criteria_value(key, value) unless criteria.has_key?(key)
  end

  def url_params
    criteria.merge({'id' => self.id})
  end

  private

  def init_results
    @pagination = Api::Pagination.new
    @security_exclusions = nil
    @results = nil
    @base_result = nil
    self
  end

  def init_display(options)
    @display = MeasureFilterDisplay.create(self, options)
  end

  def filter_authorized_snapshot_ids(rows, controller)
    project_ids = rows.map { |row| row.getResourceRootId() }.compact.uniq
    authorized_project_ids = controller.select_authorized(:user, project_ids)
    snapshot_ids = rows.map { |row| row.getSnapshotId() if authorized_project_ids.include?(row.getResourceRootId()) }.compact
    @security_exclusions = (snapshot_ids.size<rows.size)
    @pagination.count = snapshot_ids.size
    snapshot_ids[@pagination.offset .. (@pagination.offset+@pagination.limit)]
  end

  def load_results(snapshot_ids)
    @results = []
    metric_ids = metrics.map(&:id)

    if !snapshot_ids.empty?
      results_by_snapshot_id = {}
      snapshots = Snapshot.find(:all, :include => ['project'], :conditions => ['id in (?)', snapshot_ids])
      snapshots.each do |snapshot|
        result = Result.new(snapshot)
        results_by_snapshot_id[snapshot.id] = result
      end

      # @results must be in the same order than the snapshot ids
      snapshot_ids.each do |sid|
        @results << results_by_snapshot_id[sid]
      end

      unless metric_ids.empty?
        measures = ProjectMeasure.find(:all, :conditions =>
          ['rule_priority is null and rule_id is null and characteristic_id is null and person_id is null and snapshot_id in (?) and metric_id in (?)', snapshot_ids, metric_ids]
        )
        measures.each do |measure|
          result = results_by_snapshot_id[measure.snapshot_id]
          result.add_measure(measure)
        end
      end

      if require_links?
        project_ids = []
        results_by_project_id = {}
        snapshots.each do |snapshot|
          project_ids << snapshot.project_id
          results_by_project_id[snapshot.project_id] = results_by_snapshot_id[snapshot.id]
        end
        links = ProjectLink.find(:all, :conditions => {:project_id => project_ids}, :order => 'link_type')
        links.each do |link|
          results_by_project_id[link.project_id].add_link(link)
        end
      end
    end
    if criteria['base'].present?
      base_snapshot = Snapshot.find(:first, :include => 'project', :conditions => ['projects.kee=? and islast=?', criteria['base'], true])
      if base_snapshot
        @base_result = Result.new(base_snapshot)
        unless metric_ids.empty?
          base_measures = ProjectMeasure.find(:all, :conditions =>
            ['rule_priority is null and rule_id is null and characteristic_id is null and person_id is null and snapshot_id=? and metric_id in (?)', base_snapshot.id, metric_ids]
          )
          base_measures.each do |base_measure|
            @base_result.add_measure(base_measure)
          end
        end
      end
    end
  end

  def validate
    # validate uniqueness of name
    if id
      # update existing filter
      count = MeasureFilter.count('id', :conditions => ['name=? and user_id=? and id<>?', name, user_id, id])
    else
      # new filter
      count = MeasureFilter.count('id', :conditions => ['name=? and user_id=?', name, user_id])
    end
    errors.add_to_base('Name already exists') if count>0

    if shared
      count = MeasureFilter.count('id', :conditions => ['name=? and shared=? and user_id!=?', name, true, user_id])
      errors.add_to_base('Other users already shared filters with the same name') if count>0
    end

    errors.add_to_base('Only shared filters can be flagged as system filter') if system && !shared
  end
end