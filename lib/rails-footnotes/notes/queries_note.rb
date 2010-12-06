require "#{File.dirname(__FILE__)}/abstract_note"

module Footnotes
  module Notes
    class QueriesNote < AbstractNote
      @@alert_db_time = 16.0
      @@alert_sql_number = 8
      @@sql = []
      @@include_when_new_relic_installed = false
      @@loaded = false
      @@query_subscriber = nil
      cattr_accessor :sql, :alert_db_time, :alert_sql_number, :alert_explain, :loaded, :sql_explain, :instance_writter => false
      cattr_reader :include_when_new_relic_installed

      def self.include_when_new_relic_installed=(include_me)
        @@include_when_new_relic_installed = include_me
        load if include_me
      end

      def self.start!(controller)
        @@sql = []
        @@query_subscriber = Footnotes::Notes::QuerySubscriber.new
        # There appears to be nothing wrong with registering with a non-existant notifier, so we just attach to both :-).
        ActiveSupport::LogSubscriber.attach_to(:data_mapper, @@query_subscriber)
        ActiveSupport::LogSubscriber.attach_to(:active_record, @@query_subscriber)
      end

      def self.to_sym
        :queries
      end

      def title
        queries = @@query_subscriber.events.length
        total_time = @@query_subscriber.events.inject(0){|sum, item| sum += item.payload[:duration]} / 1000.0
        query_color = generate_red_color(@@query_subscriber.events.length, alert_sql_number)
        db_color    = generate_red_color(total_time, alert_db_time)

        <<-TITLE
        <span style="background-color:#{query_color}">Queries (#{queries})</span>
        <span style="background-color:#{db_color}">DB (#{"%.3f" % total_time}ms)</span>
        TITLE
      end

      def stylesheet
        <<-STYLESHEET
        #queries_debug_info table td, #queries_debug_info table th{border:1px solid #A00; padding:0 3px; text-align:center;}
        #queries_debug_info table thead, #queries_debug_info table tbody {color:#A00;}
        #queries_debug_info p {background-color:#F3F3FF; border:1px solid #CCC; margin:12px; padding:4px 6px;}
        #queries_debug_info a:hover {text-decoration:underline;}
        STYLESHEET
      end

      def content
        html = ''

        @@query_subscriber.events.each_with_index do |item, i|
          html << <<-HTML
          #{print_name_and_time(item.payload[:name], item.payload[:duration] / 1000.0)}&nbsp;
          <span id="explain_#{i}">#{print_query(item.payload[:sql])}</span><br />
          HTML
        end

        return html
      end

      def self.load
        self.loaded = true unless loaded
      end

      protected
      def print_name_and_time(name, time)
        "<span style='background-color:#{generate_red_color(time, alert_ratio)}'>#{escape(name || 'SQL')} (#{'%.3fms' % time})</span>"
      end

      def print_query(query)
        escape(query.to_s.gsub(/(\s)+/, ' ').gsub('`', ''))
      end

      def generate_red_color(value, alert)
        c = ((value.to_f/alert).to_i - 1) * 16
        c = 0  if c < 0
        c = 15 if c > 15

        c = (15-c).to_s(16)
        "#ff#{c*4}"
      end

      def alert_ratio
        alert_db_time / alert_sql_number
      end

    end

    class QuerySubscriber < ActiveSupport::LogSubscriber
      attr_accessor :events

      def self.runtime=(value)
        Thread.current["orm_sql_runtime"] = value
      end

      def self.runtime
        Thread.current["orm_sql_runtime"] ||= 0
      end

      def self.reset_runtime
        rt, self.runtime = runtime, 0
        rt
      end

      def initialize
        @events = Array.new
        super
      end

      def sql(event)
        @events << event.dup
      end
    end
  end
end

Footnotes::Notes::QueriesNote.load
