require "#{File.dirname(__FILE__)}/log_note"

module Footnotes
  module Notes
    class PartialsNote < LogNote
      @@partial_subscriber = nil
      cattr_accessor :partial_subscriber

      def initialize(controller)
        super
        @controller = controller
      end

      def self.start!(controller)
        @@partial_subscriber = Footnotes::Notes::PartialSubscriber.new
        ActiveSupport::LogSubscriber.attach_to(:action_view, @@partial_subscriber)
      end

      def row
        :edit
      end

      def title
        "Partials (#{partials.size})"
      end

      def content
        rows = partials.map do |filename|
          href = Footnotes::Filter.prefix(filename,1,1)
          shortened_name=filename.gsub(File.join(Rails.root,"app/views/"),"")
          [%{<a href="#{href}">#{shortened_name}</a>},"#{@partial_times[filename].sum}ms", @partial_counts[filename]]
        end
        mount_table(rows.unshift(%w(Partial Time Count)), :summary => "Partials for #{title}")
      end

      def self.load
        self.loaded = true unless loaded
      end

      protected
      #Generate a list of partials that were rendered, also build up render times and counts.
      #This is memoized so we can use its information in the title easily.
      def partials
        @partials ||= begin
          partials = []
          @partial_counts = {}
          @partial_times = {}
          @@partial_subscriber.events.each do |event|
            partial = event.payload[:identifier]
            @partial_times[partial] ||= []
            @partial_times[partial] << event.duration
            @partial_counts[partial] ||= 0
            @partial_counts[partial] += 1
            partials << partial unless partials.include?(partial)
          end
          partials.reverse
        end
      end
    end
    class PartialSubscriber < ActiveSupport::LogSubscriber
      attr_accessor :events
      def initialize
        @events = Array.new
        super
      end

      def render_partial(event)
        @events << event.dup
      end
    end
  end
end
