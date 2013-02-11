require ENV['SLOGGER_HOME'] + '/lib/feed-normalizer/structures'
require ENV['SLOGGER_HOME'] + '/lib/feed-normalizer/html-cleaner'

module FeedNormalizer

  # The root parser object. Every parser must extend this object.
  class Parser

    # Parser being used.
    def self.parser
      nil
    end

    # Parses the given feed, and returns a normalized representation.
    # Returns nil if the feed could not be parsed.
    def self.parse(feed, loose)
      nil
    end

    # Returns a number to indicate parser priority.
    # The lower the number, the more likely the parser will be used first,
    # and vice-versa.
    def self.priority
      0
    end

    protected

    # Some utility methods that can be used by subclasses.

    # sets value, or appends to an existing value
    def self.map_functions!(mapping, src, dest)

      mapping.each do |dest_function, src_functions|
        src_functions = [src_functions].flatten # pack into array

        src_functions.each do |src_function|
          value = if src.respond_to?(src_function)
            src.send(src_function)
          elsif src.respond_to?(:has_key?)
            src[src_function]
          end

          unless value.to_s.empty?
            append_or_set!(value, dest, dest_function)
            break
          end
        end

      end
    end

    def self.append_or_set!(value, object, object_function)
      if object.send(object_function).respond_to? :push
        object.send(object_function).push(value)
      else
        object.send(:"#{object_function}=", value)
      end
    end

    private

    # Callback that ensures that every parser gets registered.
    def self.inherited(subclass)
      ParserRegistry.register(subclass)
    end

  end


  # The parser registry keeps a list of current parsers that are available.
  class ParserRegistry

    @@parsers = []

    def self.register(parser)
      @@parsers << parser
    end

    # Returns a list of currently registered parsers, in order of priority.
    def self.parsers
      @@parsers.sort_by { |parser| parser.priority }
    end

  end


  class FeedNormalizer

    # Parses the given xml and attempts to return a normalized Feed object.
    # Setting +force_parser+ to a suitable parser will mean that parser is
    # used first, and if +try_others+ is false, it is the only parser used,
    # otherwise all parsers in the ParserRegistry are attempted, in
    # order of priority.
    #
    # ===Available options
    #
    # * <tt>:force_parser</tt> - instruct feed-normalizer to try the specified
    #   parser first. Takes a class, such as RubyRssParser, or SimpleRssParser.
    #
    # * <tt>:try_others</tt> - +true+ or +false+, defaults to +true+.
    #   If +true+, other parsers will be used as described above. The option
    #   is useful if combined with +force_parser+ to only use a single parser.
    #
    # * <tt>:loose</tt> - +true+ or +false+, defaults to +false+.
    #
    #   Specifies parsing should be done loosely. This means that when
    #   feed-normalizer would usually throw away data in order to meet
    #   the requirement of keeping resulting feed outputs the same regardless
    #   of the underlying parser, the data will instead be kept. This currently
    #   affects the following items:
    #   * <em>Categories:</em> RSS allows for multiple categories per feed item.
    #     * <em>Limitation:</em> SimpleRSS can only return the first category
    #       for an item.
    #     * <em>Result:</em> When loose is true, the extra categories are kept,
    #       of course, only if the parser is not SimpleRSS.
    def self.parse(xml, opts = {})

      # Get a string ASAP, as multiple read()'s will start returning nil..
      xml = xml.respond_to?(:read) ? xml.read : xml.to_s

      if opts[:force_parser]
        result = opts[:force_parser].parse(xml, opts[:loose])

        return result if result
        return nil if opts[:try_others] == false
      end

      ParserRegistry.parsers.each do |parser|
        result = parser.parse(xml, opts[:loose])
        return result if result
      end

      # if we got here, no parsers worked.
      return nil
    end
  end


  parser_dir = File.dirname(__FILE__) + '/parsers'

  # Load up the parsers
  Dir.open(parser_dir).each do |fn|
    next unless fn =~ /[.]rb$/
    require "parsers/#{fn}"
  end

end

