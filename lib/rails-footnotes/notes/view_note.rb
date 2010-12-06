require "#{File.dirname(__FILE__)}/abstract_note"

module Footnotes
  module Notes
    class ViewNote < AbstractNote
        @@alert_time = 500.0
        @@loaded = false
        @@view_subscriber = nil

        def initialize(controller)
          super
          @controller = controller
        end

        def self.start!(controller)
          @@view_subscriber = Footnotes::Notes::ViewSubscriber.new
          ActiveSupport::LogSubscriber.attach_to(:action_view, @@view_subscriber)
        end

        def self.to_sym
          :views
        end

        def title
          total_time = @@view_subscriber.events.select{ |e| e.name =~ /render_template/ }[0].duration
          "<span style=\"background-color:#{generate_red_color(total_time)}\">View Render (#{"%.3f" % total_time}ms)</span>"
        end

        def content
          html = ''
          page = @@view_subscriber.events.select{ |e| e.name =~ /render_template/ }[0]
          partials = @@view_subscriber.events.select{ |e| e.name =~ /render_partial/ }
          partial_time = partials.inject(0) {|sum, item| sum += item.duration}

          view = page.payload[:identifier].gsub(File.join(Rails.root,"app/views/"),"")
          layout = page.payload[:layout].gsub(File.join(Rails.root,"app/views/"),"")

          rows = [["View", "Layout", "View Render (ms)", "Partial(s) Render (ms)", "Total Render (ms)"],
                  [escape(view), escape(layout), "#{'%.3f' % (page.duration - partial_time)}",
                   "<a href=\"#\" onclick=\"Footnotes.hideAllAndToggle('partials_debug_info');return false;\">#{'%.3f' % partial_time}</a>",
                   "#{'%.3f' % page.duration}"]]

          puts rows.inspect

          mount_table(rows)
        end

        def self.load
          self.loaded = true unless loaded
        end

        def generate_red_color(value)
          if value > @@alert_time
            "#f00"
          else
            "#aaa"
          end
        end
      end

      class ViewSubscriber < ActiveSupport::LogSubscriber
        attr_accessor :events
        def initialize
          @events = Array.new
          super
        end

        def render_template(event)
          @events << event.dup
        end
        alias :render_partial :render_template
        alias :render_collection :render_template
    end
  end
end
