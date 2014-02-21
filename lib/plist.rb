# = plist
#
# Copyright 2006-2010 Ben Bleything and Patrick May
# Distributed under the MIT License
#

module Plist ; end

# === Create a plist
# You can dump an object to a plist in one of two ways:
#
# * <tt>Plist::Emit.dump(obj)</tt>
# * <tt>obj.to_plist</tt>
#   * This requires that you mixin the <tt>Plist::Emit</tt> module, which is already done for +Array+ and +Hash+.
#
# The following Ruby classes are converted into native plist types:
#   Array, Bignum, Date, DateTime, Fixnum, Float, Hash, Integer, String, Symbol, Time, true, false
# * +Array+ and +Hash+ are both recursive; their elements will be converted into plist nodes inside the <array> and <dict> containers (respectively).
# * +IO+ (and its descendants) and +StringIO+ objects are read from and their contents placed in a <data> element.
# * User classes may implement +to_plist_node+ to dictate how they should be serialized; otherwise the object will be passed to <tt>Marshal.dump</tt> and the result placed in a <data> element.
#
# For detailed usage instructions, refer to USAGE[link:files/docs/USAGE.html] and the methods documented below.
module Plist::Emit
  # Helper method for injecting into classes.  Calls <tt>Plist::Emit.dump</tt> with +self+.
  def to_plist(envelope = true)
    return Plist::Emit.dump(self, envelope)
  end

  # Helper method for injecting into classes.  Calls <tt>Plist::Emit.save_plist</tt> with +self+.
  def save_plist(filename)
    Plist::Emit.save_plist(self, filename)
  end

  # The following Ruby classes are converted into native plist types:
  #   Array, Bignum, Date, DateTime, Fixnum, Float, Hash, Integer, String, Symbol, Time
  #
  # Write us (via RubyForge) if you think another class can be coerced safely into one of the expected plist classes.
  #
  # +IO+ and +StringIO+ objects are encoded and placed in <data> elements; other objects are <tt>Marshal.dump</tt>'ed unless they implement +to_plist_node+.
  #
  # The +envelope+ parameters dictates whether or not the resultant plist fragment is wrapped in the normal XML/plist header and footer.  Set it to false if you only want the fragment.
  def self.dump(obj, envelope = true)
    output = plist_node(obj)

    output = wrap(output) if envelope

    return output
  end

  # Writes the serialized object's plist to the specified filename.
  def self.save_plist(obj, filename)
    File.open(filename, 'wb') do |f|
      f.write(obj.to_plist)
    end
  end

  private
  def self.plist_node(element)
    output = ''

    if element.respond_to? :to_plist_node
      output << element.to_plist_node
    else
      case element
      when Array
        if element.empty?
          output << "<array/>\n"
        else
          output << tag('array') {
            element.collect {|e| plist_node(e)}
          }
        end
      when Hash
        if element.empty?
          output << "<dict/>\n"
        else
          inner_tags = []

          element.keys.sort.each do |k|
            v = element[k]
            inner_tags << tag('key', CGI::escapeHTML(k.to_s))
            inner_tags << plist_node(v)
          end

          output << tag('dict') {
            inner_tags
          }
        end
      when true, false
        output << "<#{element}/>\n"
      when Time
        output << tag('date', element.utc.strftime('%Y-%m-%dT%H:%M:%SZ'))
      when Date # also catches DateTime
        output << tag('date', element.strftime('%Y-%m-%dT%H:%M:%SZ'))
      when String, Symbol, Fixnum, Bignum, Integer, Float
        output << tag(element_type(element), CGI::escapeHTML(element.to_s))
      when IO, StringIO
        element.rewind
        contents = element.read
        # note that apple plists are wrapped at a different length then
        # what ruby's base64 wraps by default.
        # I used #encode64 instead of #b64encode (which allows a length arg)
        # because b64encode is b0rked and ignores the length arg.
        data = "\n"
        Base64::encode64(contents).gsub(/\s+/, '').scan(/.{1,68}/o) { data << $& << "\n" }
        output << tag('data', data)
      else
        output << comment( 'The <data> element below contains a Ruby object which has been serialized with Marshal.dump.' )
        data = "\n"
        Base64::encode64(Marshal.dump(element)).gsub(/\s+/, '').scan(/.{1,68}/o) { data << $& << "\n" }
        output << tag('data', data )
      end
    end

    return output
  end

  def self.comment(content)
    return "<!-- #{content} -->\n"
  end

  def self.tag(type, contents = '', &block)
    out = nil

    if block_given?
      out = IndentedString.new
      out << "<#{type}>"
      out.raise_indent

      out << block.call

      out.lower_indent
      out << "</#{type}>"
    else
      out = "<#{type}>#{contents.to_s}</#{type}>\n"
    end

    return out.to_s
  end

  def self.wrap(contents)
    output = ''

    output << '<?xml version="1.0" encoding="UTF-8"?>' + "\n"
    output << '<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' + "\n"
    output << '<plist version="1.0">' + "\n"

    output << contents

    output << '</plist>' + "\n"

    return output
  end

  def self.element_type(item)
    case item
    when String, Symbol
      'string'

    when Fixnum, Bignum, Integer
      'integer'

    when Float
      'real'

    else
      raise "Don't know about this data type... something must be wrong!"
    end
  end
  private
  class IndentedString #:nodoc:
    attr_accessor :indent_string

    def initialize(str = "\t")
      @indent_string = str
      @contents = ''
      @indent_level = 0
    end

    def to_s
      return @contents
    end

    def raise_indent
      @indent_level += 1
    end

    def lower_indent
      @indent_level -= 1 if @indent_level > 0
    end

    def <<(val)
      if val.is_a? Array
        val.each do |f|
          self << f
        end
      else
        # if it's already indented, don't bother indenting further
        unless val =~ /\A#{@indent_string}/
          indent = @indent_string * @indent_level

          @contents << val.gsub(/^/, indent)
        else
          @contents << val
        end

        # it already has a newline, don't add another
        @contents << "\n" unless val =~ /\n$/
      end
    end
  end
end

# we need to add this so sorting hash keys works properly
class Symbol #:nodoc:
  def <=> (other)
    self.to_s <=> other.to_s
  end
end

class Array #:nodoc:
  include Plist::Emit
end

class Hash #:nodoc:
  include Plist::Emit
end

# === Load a plist file
# This is the main point of the library:
#
#   r = Plist::parse_xml( filename_or_xml )
module Plist
# Note that I don't use these two elements much:
#
#  + Date elements are returned as DateTime objects.
#  + Data elements are implemented as Tempfiles
#
# Plist::parse_xml will blow up if it encounters a data element.
# If you encounter such an error, or if you have a Date element which
# can't be parsed into a Time object, please send your plist file to
# plist@hexane.org so that I can implement the proper support.
  def Plist::parse_xml( filename_or_xml )
    listener = Listener.new
    #parser = REXML::Parsers::StreamParser.new(File.new(filename), listener)
    parser = StreamParser.new(filename_or_xml, listener)
    parser.parse
    listener.result
  end

  class Listener
    #include REXML::StreamListener

    attr_accessor :result, :open

    def initialize
      @result = nil
      @open   = Array.new
    end


    def tag_start(name, attributes)
      @open.push PTag::mappings[name].new
    end

    def text( contents )
      @open.last.text = contents if @open.last
    end

    def tag_end(name)
      last = @open.pop
      if @open.empty?
        @result = last.to_ruby
      else
        @open.last.children.push last
      end
    end
  end

  class StreamParser
    def initialize( plist_data_or_file, listener )
      if plist_data_or_file.respond_to? :read
        @xml = plist_data_or_file.read
      elsif File.exists? plist_data_or_file
        @xml = File.read( plist_data_or_file )
      else
        @xml = plist_data_or_file
      end

      @listener = listener
    end

    TEXT       = /([^<]+)/
    XMLDECL_PATTERN = /<\?xml\s+(.*?)\?>*/um
    DOCTYPE_PATTERN = /\s*<!DOCTYPE\s+(.*?)(\[|>)/um
    COMMENT_START = /\A<!--/u
    COMMENT_END = /.*?-->/um


    def parse
      plist_tags = PTag::mappings.keys.join('|')
      start_tag  = /<(#{plist_tags})([^>]*)>/i
      end_tag    = /<\/(#{plist_tags})[^>]*>/i

      require 'strscan'

      @scanner = StringScanner.new( @xml )
      until @scanner.eos?
        if @scanner.scan(COMMENT_START)
          @scanner.scan(COMMENT_END)
        elsif @scanner.scan(XMLDECL_PATTERN)
        elsif @scanner.scan(DOCTYPE_PATTERN)
        elsif @scanner.scan(start_tag)
          @listener.tag_start(@scanner[1], nil)
          if (@scanner[2] =~ /\/$/)
            @listener.tag_end(@scanner[1])
          end
        elsif @scanner.scan(TEXT)
          @listener.text(@scanner[1])
        elsif @scanner.scan(end_tag)
          @listener.tag_end(@scanner[1])
        else
          raise "Unimplemented element"
        end
      end
    end
  end

  class PTag
    @@mappings = { }
    def PTag::mappings
      @@mappings
    end

    def PTag::inherited( sub_class )
      key = sub_class.to_s.downcase
      key.gsub!(/^plist::/, '' )
      key.gsub!(/^p/, '')  unless key == "plist"

      @@mappings[key] = sub_class
    end

    attr_accessor :text, :children
    def initialize
      @children = Array.new
    end

    def to_ruby
      raise "Unimplemented: " + self.class.to_s + "#to_ruby on #{self.inspect}"
    end
  end

  class PList < PTag
    def to_ruby
      children.first.to_ruby if children.first
    end
  end

  class PDict < PTag
    def to_ruby
      dict = Hash.new
      key = nil

      children.each do |c|
        if key.nil?
          key = c.to_ruby
        else
          dict[key] = c.to_ruby
          key = nil
        end
      end

      dict
    end
  end

  class PKey < PTag
    def to_ruby
      CGI::unescapeHTML(text || '')
    end
  end

  class PString < PTag
    def to_ruby
      CGI::unescapeHTML(text || '')
    end
  end

  class PArray < PTag
    def to_ruby
      children.collect do |c|
        c.to_ruby
      end
    end
  end

  class PInteger < PTag
    def to_ruby
      text.to_i
    end
  end

  class PTrue < PTag
    def to_ruby
      true
    end
  end

  class PFalse < PTag
    def to_ruby
      false
    end
  end

  class PReal < PTag
    def to_ruby
      text.to_f
    end
  end

  require 'date'
  class PDate < PTag
    def to_ruby
      DateTime.parse(text)
    end
  end

  require 'base64'
  class PData < PTag
    def to_ruby
      data = Base64.decode64(text.gsub(/\s+/, ''))

      begin
        return Marshal.load(data)
      rescue Exception => e
        io = StringIO.new
        io.write data
        io.rewind
        return io
      end
    end
  end
end


module Plist
  VERSION = '3.1.0'
end
