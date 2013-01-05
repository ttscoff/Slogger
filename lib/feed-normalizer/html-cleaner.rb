require 'rubygems'
require 'hpricot'
require 'cgi'

module FeedNormalizer

  # Various methods for cleaning up HTML and preparing it for safe public
  # consumption.
  #
  # Documents used for refrence:
  # - http://www.w3.org/TR/html4/index/attributes.html
  # - http://en.wikipedia.org/wiki/List_of_XML_and_HTML_character_entity_references
  # - http://feedparser.org/docs/html-sanitization.html
  # - http://code.whytheluckystiff.net/hpricot/wiki
  class HtmlCleaner

    # allowed html elements.
    HTML_ELEMENTS = %w(
      a abbr acronym address area b bdo big blockquote br button caption center
      cite code col colgroup dd del dfn dir div dl dt em fieldset font h1 h2 h3
      h4 h5 h6 hr i img ins kbd label legend li map menu ol optgroup p pre q s
      samp small span strike strong sub sup table tbody td tfoot th thead tr tt
      u ul var
    )

    # allowed attributes.
    HTML_ATTRS = %w(
      abbr accept accept-charset accesskey align alt axis border cellpadding
      cellspacing char charoff charset checked cite class clear cols colspan
      color compact coords datetime dir disabled for frame headers height href
      hreflang hspace id ismap label lang longdesc maxlength media method
      multiple name nohref noshade nowrap readonly rel rev rows rowspan rules
      scope selected shape size span src start summary tabindex target title
      type usemap valign value vspace width
    )

    # allowed attributes, but they can contain URIs, extra caution required.
    # NOTE: That means this doesnt list *all* URI attrs, just the ones that are allowed.
    HTML_URI_ATTRS = %w(
      href src cite usemap longdesc
    )

    DODGY_URI_SCHEMES = %w(
      javascript vbscript mocha livescript data
    )

    class << self

      # Does this:
      # - Unescape HTML
      # - Parse HTML into tree
      # - Find 'body' if present, and extract tree inside that tag, otherwise parse whole tree
      # - Each tag:
      #   - remove tag if not whitelisted
      #   - escape HTML tag contents
      #   - remove all attributes not on whitelist
      #   - extra-scrub URI attrs; see dodgy_uri?
      #
      # Extra (i.e. unmatched) ending tags and comments are removed.
      def clean(str)
        str = unescapeHTML(str)

        doc = Hpricot(str, :fixup_tags => true)
        doc = subtree(doc, :body)

        # get all the tags in the document
        # Somewhere near hpricot 0.4.92 "*" starting to return all elements,
        # including text nodes instead of just tagged elements.
        tags = (doc/"*").inject([]) { |m,e| m << e.name if(e.respond_to?(:name) && e.name =~ /^\w+$/) ; m }.uniq

        # Remove tags that aren't whitelisted.
        remove_tags!(doc, tags - HTML_ELEMENTS)
        remaining_tags = tags & HTML_ELEMENTS

        # Remove attributes that aren't on the whitelist, or are suspicious URLs.
        (doc/remaining_tags.join(",")).each do |element|
          element.raw_attributes.reject! do |attr,val|
            !HTML_ATTRS.include?(attr) || (HTML_URI_ATTRS.include?(attr) && dodgy_uri?(val))
          end

          element.raw_attributes = element.raw_attributes.build_hash {|a,v| [a, add_entities(v)]}
        end unless remaining_tags.empty?

        doc.traverse_text {|t| t.set(add_entities(t.to_html))}

        # Return the tree, without comments. Ugly way of removing comments,
        # but can't see a way to do this in Hpricot yet.
        doc.to_s.gsub(/<\!--.*?-->/mi, '')
      end

      # For all other feed elements:
      # - Unescape HTML.
      # - Parse HTML into tree (taking 'body' as root, if present)
      # - Takes text out of each tag, and escapes HTML.
      # - Returns all text concatenated.
      def flatten(str)
        str.gsub!("\n", " ")
        str = unescapeHTML(str)

        doc = Hpricot(str, :xhtml_strict => true)
        doc = subtree(doc, :body)

        out = []
        doc.traverse_text {|t| out << add_entities(t.to_html)}

        return out.join
      end

      # Returns true if the given string contains a suspicious URL,
      # i.e. a javascript link.
      #
      # This method rejects javascript, vbscript, livescript, mocha and data URLs.
      # It *could* be refined to only deny dangerous data URLs, however.
      def dodgy_uri?(uri)
        uri = uri.to_s

        # special case for poorly-formed entities (missing ';')
        # if these occur *anywhere* within the string, then throw it out.
        return true if (uri =~ /&\#(\d+|x[0-9a-f]+)[^;\d]/mi)

        # Try escaping as both HTML or URI encodings, and then trying
        # each scheme regexp on each
        [unescapeHTML(uri), CGI.unescape(uri)].each do |unesc_uri|
          DODGY_URI_SCHEMES.each do |scheme|

            regexp = "#{scheme}:".gsub(/./) do |char|
              "([\000-\037\177\s]*)#{char}"
            end

            # regexp looks something like
            # /\A([\000-\037\177\s]*)j([\000-\037\177\s]*)a([\000-\037\177\s]*)v([\000-\037\177\s]*)a([\000-\037\177\s]*)s([\000-\037\177\s]*)c([\000-\037\177\s]*)r([\000-\037\177\s]*)i([\000-\037\177\s]*)p([\000-\037\177\s]*)t([\000-\037\177\s]*):/mi
            return true if (unesc_uri =~ %r{\A#{regexp}}mi)
          end
        end

        nil
      end

      # unescapes HTML. If xml is true, also converts XML-only named entities to HTML.
      def unescapeHTML(str, xml = true)
        CGI.unescapeHTML(xml ? str.gsub("&apos;", "&#39;") : str)
      end

      # Adds entities where possible.
      # Works like CGI.escapeHTML, but will not escape existing entities;
      # i.e. &#123; will NOT become &amp;#123;
      #
      # This method could be improved by adding a whitelist of html entities.
      def add_entities(str)
        str.to_s.gsub(/\"/n, '&quot;').gsub(/>/n, '&gt;').gsub(/</n, '&lt;').gsub(/&(?!(\#\d+|\#x([0-9a-f]+)|\w{2,8});)/nmi, '&amp;')
      end

      private

      # Everything below elment, or the just return the doc if element not present.
      def subtree(doc, element)
        doc.at("//#{element}/*") || doc
      end

      def remove_tags!(doc, tags)
        (doc/tags.join(",")).remove unless tags.empty?
      end

    end
  end
end


module Enumerable #:nodoc:
  def build_hash
    result = {}
    self.each do |elt|
      key, value = yield elt
      result[key] = value
    end
    result
  end
end

# http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/207625
#  Subject: A simple Hpricot text setter
#  From: Chris Gehlker <canyonrat mac.com>
#  Date: Fri, 11 Aug 2006 03:19:13 +0900
class Hpricot::Text #:nodoc:
  def set(string)
    @content = string
    self.raw_string = string
  end
end

