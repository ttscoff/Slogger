=begin
Plugin: OliveTree Bible Reader Plugin
Description: Track annotations from OliveTree's Bible Reader
Author: [Micah Cooper](http://meebles.org)
Configuration:
  option_1_name: [ "example_value1" , "example_value2", ... ]
  option_2_name: example_value
Notes:
  - This plugin pulls annotations from OliveTree Bible Reader and adds to Slogger
  - This plugin is unofficial and does not use published APIs. As such, it may break at any time and without notice.
=end

require 'multimap'

config = { # description and a primary key (username, url, etc.) required
  'description' => ['Track annotations from OliveTree\'s Bible Reader',
                    'otUser is your OliveTree.com username (email address)',
                    'otPass is your OliveTree.com password'],
  'otUser' => '',
  'otPass' => '',
  #'annotationCategories' => [],
  'lastSequenceNumber' => 0,
  ##'additional_config_option' => false,
  'tags' => '#social #Bible' # A good idea to provide this with an appropriate default setting
}
# Update the class key to match the unique classname below
$slog.register_plugin({ 'class' => 'OTBibleLogger', 'config' => config })

# unique class name: leave '< Slogger' but change ServiceLogger (e.g. LastFMLogger)
class OTBibleLogger < Slogger
  def doSetup


  end

  def bigQuery
    bookName = ['', 'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua', 'Judges', 'Ruth',
           '1 Samuel', '2 Samuel', '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles',
                       'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalm', 'Proverbs', 'Ecclesiastes', 'Song of Solomon',
           'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos', 'Obadiah',
           'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi', 'Matthew',
           'Mark', 'Luke', 'John', 'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
                       'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians', '1 Timothy',
                       '2\+Timothy', 'Titus', 'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter', '1 John',
           '2 John', '3 John', 'Jude', 'Revelation']


    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('otUser') || config['otUser'] == []
        @log.warn("<Service> has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        username = config['otUser']
        password = config['otPass']
        cfgSeqNum = config['lastSequenceNumber'] || 0
      end
    else
      exit
    end
    username = config['otUser']
    password = config['otPass']
    cfgSeqNum = config['lastSequenceNumber'] || 0
    #queryURL = 'https://sync.olivetree.com/syncables.xml?device_id=<MYID>&above=321&managed_data_set=managed_annotations&sync_client_protocol_version=4&reader_version=com.olivetree.BibleReaderMac_5.4.2.1_OS_10.9.3'
    queryURL = 'https://sync.olivetree.com/syncables.xml'
    uri = URI(queryURL)
    params = {:device_id=> "001", :above=> cfgSeqNum, :managed_data_set=> "managed_annotations", :sync_client_protocol_version=> "4", :reader_version=> "slogger"}
    uri.query = URI.encode_www_form( params )
    req = Net::HTTP::Get.new(uri)
    req.basic_auth username, password

    res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) {|http|
      http.request(req)
    }

    xml_data = res.body
    doc = REXML::Document.new(xml_data);
    annoCats = REXML::XPath.match(doc, '///[@type="AnnotationCategory"]')
    annoCats.each do |annoCat|
      parentCategoryID = annoCat.elements['parent-category-id'].text
      name = annoCat.elements['name'].text
      id = annoCat.elements['client-id'].text

      # We're sticking the categories right into our config file

      parentText = ''
      if 1 < parentCategoryID.to_i
        parentText = config[parentCategoryID] || ''
      end

      config[id] = parentText + ' :: ' + name

    end


    # Tags are 3NF to allow many-to-many it appears
    # UserTags is one entry, annotations are another, and then there's a 3rd
    # value joining the two.

    annoTags = REXML::XPath.match(doc, '///[@type="UserTag"]')
    annoTags.each do |annoTag|
      name = annoTag.elements['name'].text
      id = annoTag.elements['client-id'].text

      # We're sticking the tags right into our config file for perpetual use
      config[id] = name
    end



    # Now we're going on a tag hunt
    # This was within each annotation find, but that was slow and silly
    tagAssocs = Multimap.new
    doc.elements.each('///[@type="AnnotationUserTag"]') do |e|
      annotationID = e.elements['annotation-id'].text
      userTagID = e.elements['user-tag-id'].text
      tagAssocs[annotationID] = userTagID
    end

    annos = REXML::XPath.match(doc, '///[@type="Annotation"]')
    annos.each do |anno|
      annoContent = anno.elements['content'].text || ''
      annoID = anno.elements['client-id'].text || ''

      annoCreatedDate = Time.at(anno.elements['created-date'].text.to_i) || 0
      annoModDate = Time.at(anno.elements['modified-date'].text.to_i) || 0
      annoTitle = anno.elements['title'].text || ''
      annoEndPhrase = anno.elements['end-phrase'].text || ''
      annoStartPhrase = anno.elements['start-phrase'].text || ''
      annoCat = anno.elements['annotation-category-id'].text || ''
      annoWordCat = config[annoCat] || ''
      annoBookBegin = bookName[anno.elements['book-begin'].text.to_i] || ''
      annoBookEnd = bookName[anno.elements['book-end'].text.to_i] || ''
      annoChapStart = anno.elements['chapter-begin'].text || ''
      annoChapEnd = anno.elements['chapter-end'].text || ''
      annoVerseStart = anno.elements['verse-begin'].text || ''
      annoVerseEnd = anno.elements['verse-end'].text || ''

      # we stuck our associations in a multimap earlier
      # now we query that multimap for each annotation to see if it has
      # an associated tag
      aTags = []
      annoTagAssocs = tagAssocs[annoID] || ''

      annoTagAssocs.each do |aTA|
        aTags.push(config[aTA])
        #@log.info(config[aTA])
      end

      if 'true' != anno.elements['book-begin'].attributes['nil']
        verseSelection = ''
        verseSelection = verseSelection + annoBookBegin

        if annoChapStart != ''
          verseSelection = verseSelection + ' ' + annoChapStart
        end
        #verseSelection = verseSelection + annoChapStart
        if annoVerseStart
          verseSelection = verseSelection + ':' + annoVerseStart
        end

        verseSelectionEnd = ''
        if anno.elements['book-begin'].text.to_i < anno.elements['book-end'].text.to_i

          verseSelectionEnd = verseSelectionEnd + annoBookEnd
          if annoChapEnd
            verseSelectionEnd = verseSelectionEnd + ' ' + annoChapEnd
            verseSelectionEnd = verseSelectionEnd + ':' + annoVerseEnd
          else
            verseSelectionEnd = verseSelectionEnd + verseSelectionEnd
          end
          if verseSelectionEnd != ''
            verseSelection = verseSelection + ' – ' + verseSelectionEnd
          end
        elsif anno.elements['book-begin'].text.to_i < anno.elements['book-end'].text.to_i

          if annoChapEnd
            verseSelectionEnd = verseSelectionEnd + ' ' + annoChapEnd
            verseSelectionEnd = verseSelectionEnd + ':' + annoVerseEnd
          else
            verseSelectionEnd = verseSelectionEnd + verseSelectionEnd
          end
          if verseSelectionEnd != ''
            verseSelection = verseSelection + ' – ' + verseSelectionEnd
          end
        end
      end

      # Pull desired standard tags from config
      tags = config['tags'] || ''
      tags = tags.scan(/#([A-Za-z0-9]+)/m).map { |tag| tag[0].strip }.delete_if {|tag| tag =~ /^\d+$/ }.uniq.sort

      # Pull Annotation Category (with hierarchy) and push onto tag array
      tags = tags.push(annoWordCat)
      # Push the Name of the Bible book if there is one
      tags = tags.push(annoBookBegin)
      # Grab those tags from way up
      aTags.each do |thisTag|
        tags = tags.push(thisTag)
      end

      options = {}
      options['content'] = "#{annoTitle}\n\n#{verseSelection}\n\n#{annoContent}"
      options['datestamp'] = annoModDate.utc.iso8601
      options['starred'] = false
      options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip
      options['tags'] = tags




      # Create a journal entry
      # to_dayone accepts all of the above options as a hash
      # generates an entry base on the datestamp key or defaults to "now"
      sl = DayOne.new
      sl.to_dayone(options)


    end

    # This section returns the highest sequence number in our run and then updates config
    seqNums = REXML::XPath.each(doc, '//sequence-number')
    bunchONums = []
    #seqNumMax = seqNums.max
    seqNums.each do |seqNum|
      bunchONums.push(seqNum.text.to_i)
    end

    seqNumMax = bunchONums.max
    #@log.info( seqNumMax )
    config['lastSequenceNumber'] = seqNumMax

    return config



  end


  # every plugin must contain a do_log function which creates a new entry using the DayOne class (example below)
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('otUser') || config['otUser'] == []
        @log.warn("<Service> has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        username = config['otUser']
        password = config['otPass']
        cfgSeqNum = config['lastSequenceNumber'] || 0
      end
    else
      @log.warn("OliveTree has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging OliveTree posts for #{username}")

    ##additional_config_option = config['additional_config_option'] || false
    tags = config['tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''

    today = @timespan

    # Perform necessary functions to retrieve posts

    # First, we query the status URL to determine highest sequence number
    annoXML = config['annotationXML'] || ''

    statusURL = 'https://sync.olivetree.com/syncables/status.xml?device_id=001&do_not_lock=true&sync_client_protocol_version=4'
    uri = URI(statusURL)
    req = Net::HTTP::Get.new(uri)
    req.basic_auth username, password
    ##req.use_ssl = true

    res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) {|http|
      http.request(req)
    }

    xml_data = res.body
    doc = REXML::Document.new(xml_data);
    doc.root.each_element('//customer') { |item|
        qrdSeqNumEl = item.elements['sequence-number'] || 0
        qrdSeqNum = qrdSeqNumEl.get_text.value # comes in as text
        intQrdSeqNum = qrdSeqNum.to_i # convert to integer

        # This part is this way just for debugging — otherwise, it works awesome!
        # config = bigQuery # comment this out
        # uncomment these
        i = config['lastSequenceNumber']
        runCount = 0
        while i < intQrdSeqNum do
          config = bigQuery
          i = config['lastSequenceNumber']
          # runaway prevention
          runCount += 1
          if runCount > 20
            break
          end
        end


        return config

    }



    # create an options array to pass to 'to_dayone'
    # all options have default fallbacks, so you only need to create the options you want to specify

    # To create an image entry, use `sl.to_dayone(options) if sl.save_image(imageurl,options['uuid'])`
    # save_image takes an image path and a uuid that must be identical the one passed to to_dayone
    # save_image returns false if there's an error

  end



  def helper_function(args)
    # add helper functions within the class to handle repetitive tasks
  end
end
