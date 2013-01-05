require 'rss'

# For some reason, this is only included in the RDF Item by default.
class RSS::Rss::Channel::Item # :nodoc:
  include RSS::ContentModel
end

module FeedNormalizer
  class RubyRssParser < Parser

    def self.parser
      RSS::Parser
    end

    def self.parse(xml, loose)
      begin
        rss = parser.parse(xml)
      rescue Exception => e
        #puts "Parser #{parser} failed because #{e.message.gsub("\n",', ')}"
        return nil
      end

      rss ? package(rss, loose) : nil
    end

    # Fairly high priority; a fast and strict parser.
    def self.priority
      100
    end

    protected

    def self.package(rss, loose)
      feed = Feed.new(self)

      # channel elements
      feed_mapping = {
        :generator => :generator,
        :title => :title,
        :urls => :link,
        :description => :description,
        :copyright => :copyright,
        :authors => :managingEditor,
        :last_updated => [:lastBuildDate, :pubDate, :dc_date],
        :id => :guid,
        :ttl => :ttl
      }

      # make two passes, to catch all possible root elements
      map_functions!(feed_mapping, rss, feed)
      map_functions!(feed_mapping, rss.channel, feed)

      # custom channel elements
      feed.image = rss.image ? rss.image.url : nil
      feed.skip_hours = skip(rss, :skipHours)
      feed.skip_days = skip(rss, :skipDays)

      # item elements
      item_mapping = {
        :date_published => [:pubDate, :dc_date],
        :urls => :link,
        :description => :description,
        :content => [:content_encoded, :description],
        :title => :title,
        :authors => [:author, :dc_creator],
        :last_updated => [:pubDate, :dc_date] # This is effectively an alias for date_published for this parser.
      }

      rss.items.each do |rss_item|
        feed_entry = Entry.new
        map_functions!(item_mapping, rss_item, feed_entry)

        # custom item elements
        feed_entry.id = rss_item.guid.content if rss_item.respond_to?(:guid) && rss_item.guid
        feed_entry.copyright = rss.copyright if rss_item.respond_to? :copyright
        feed_entry.categories = loose ?
                                  rss_item.categories.collect{|c|c.content} :
                                  [rss_item.categories.first.content] rescue []

        feed.entries << feed_entry
      end

      feed
    end

    def self.skip(parser, attribute)
      attributes = case attribute
        when :skipHours: :hours
        when :skipDays: :days
      end
      channel = parser.channel

      return nil unless channel.respond_to?(attribute) && a = channel.send(attribute)
      a.send(attributes).collect{|e| e.content}
    end

  end
end
