require 'simple-rss'

# Monkey patches for outstanding issues logged in the simple-rss project.
#   * Add support for issued time field:
#     http://rubyforge.org/tracker/index.php?func=detail&aid=13980&group_id=893&atid=3517
#   * The '+' symbol is lost when escaping fields.
#     http://rubyforge.org/tracker/index.php?func=detail&aid=10852&group_id=893&atid=3517
#
class SimpleRSS
  @@item_tags << :issued

  undef clean_content
  def clean_content(tag, attrs, content)
    content = content.to_s
    case tag
      when :pubDate, :lastBuildDate, :published, :updated, :expirationDate, :modified, :'dc:date', :issued
        Time.parse(content) rescue unescape(content)
      when :author, :contributor, :skipHours, :skipDays
        unescape(content.gsub(/<.*?>/,''))
      else
        content.empty? && "#{attrs} " =~ /href=['"]?([^'"]*)['" ]/mi ? $1.strip : unescape(content)
    end
  end

  undef unescape
  def unescape(s)
   if s =~ /^(<!\[CDATA\[|\]\]>)/
     # Raw HTML is inside the CDATA, so just remove the CDATA wrapper.
     s.gsub(/(<!\[CDATA\[|\]\]>)/,'').strip
   elsif s =~ /[<>]/
     # Already looks like HTML.
     s
   else
     # Make it HTML.
     FeedNormalizer::HtmlCleaner.unescapeHTML(s)
   end
 end
end

module FeedNormalizer

  # The SimpleRSS parser can handle both RSS and Atom feeds.
  class SimpleRssParser < Parser

    def self.parser
      SimpleRSS
    end

    def self.parse(xml, loose)
      begin
        atomrss = parser.parse(xml)
      rescue Exception => e
        #puts "Parser #{parser} failed because #{e.message.gsub("\n",', ')}"
        return nil
      end

      package(atomrss)
    end

    # Fairly low priority; a slower, liberal parser.
    def self.priority
      900
    end

    protected

    def self.package(atomrss)
      feed = Feed.new(self)

      # root elements
      feed_mapping = {
        :generator => :generator,
        :title => :title,
        :last_updated => [:updated, :lastBuildDate, :pubDate, :dc_date],
        :copyright => [:copyright, :rights],
        :authors => [:author, :webMaster, :managingEditor, :contributor],
        :urls => :link,
        :description => [:description, :subtitle],
        :ttl => :ttl
      }

      map_functions!(feed_mapping, atomrss, feed)

      # custom channel elements
      feed.id = feed_id(atomrss)
      feed.image = image(atomrss)


      # entry elements
      entry_mapping = {
        :date_published => [:pubDate, :published, :dc_date, :issued],
        :urls => :link,
        :description => [:description, :summary],
        :content => [:content, :content_encoded, :description],
        :title => :title,
        :authors => [:author, :contributor, :dc_creator],
        :categories => :category,
        :last_updated => [:updated, :dc_date, :pubDate]
      }

      atomrss.entries.each do |atomrss_entry|
        feed_entry = Entry.new
        map_functions!(entry_mapping, atomrss_entry, feed_entry)

        # custom entry elements
        feed_entry.id = atomrss_entry.guid || atomrss_entry[:id] # entries are a Hash..
        feed_entry.copyright = atomrss_entry.copyright || (atomrss.respond_to?(:copyright) ? atomrss.copyright : nil)

        feed.entries << feed_entry
      end

      feed
    end

    def self.image(parser)
      if parser.respond_to?(:image) && parser.image
        if parser.image =~ /<url>/ # RSS image contains an <url> spec
          parser.image.scan(/<url>(.*?)<\/url>/).to_s
        else
          parser.image # Atom contains just the url
        end
      elsif parser.respond_to?(:logo) && parser.logo
        parser.logo
      end
    end

    def self.feed_id(parser)
      overridden_value(parser, :id) || ("#{parser.link}" if parser.respond_to?(:link))
    end

    # gets the value returned from the method if it overriden, otherwise nil.
    def self.overridden_value(object, method)
      object.class.public_instance_methods(false).include? method
    end

  end
end
