=begin
Plugin: FeedAFever
Description: Capture what you've read from your personal FeedAFever site
Author: [Micah Cooper](http://www.meebles.org)
Configuration:
  option_1_name: [ "example_value1" , "example_value2", ... ]
  option_2_name: example_value
Notes:
  - multi-line notes with additional description and information (optional)
=end

require 'digest'
require 'json'
require 'sqlite3'

config = { # description and a primary key (username, url, etc.) required
  'description' => ['FeedAFever logger',
                    'This plugin requires sqlite3 and creates a local cache of your fever items'],
  'fafEmailAddr' => '', # Your Fever email address
  'fafPass' => '', # Your Fever password
  'fafURL' => '', # Your Fever URL 
  'tags' => '#social #blogging #rss' 
}

$db = SQLite3::Database.new "feedafever.db"

# Update the class key to match the unique classname below
$slog.register_plugin({ 'class' => 'FeedAFever', 'config' => config })

# unique class name: leave '< Slogger' but change ServiceLogger (e.g. LastFMLogger)
class FeedAFever < Slogger
  # every plugin must contain a do_log function which creates a new entry using the DayOne class (example below)
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing

  def updateUnread
    if @config.key?(self.class.name)
      config = @config[self.class.name]
    end
    username = config['fafEmailAddr']
    password = config['fafPass']
    apiString = username + ":" + password
    md5 = Digest::MD5.new
    apiKey = md5.update apiString

    hostString = config['fafURL']
    if (!hostString.end_with?("/"))
      hostString = hostString + "/"
    end

    queryURL = hostString + "?api&unread_item_ids"

    uri = URI.parse(queryURL)
    http = Net::HTTP.new(uri.host, uri.port)

    apiKeyString = apiKey.to_s

    req = Net::HTTP::Post.new(uri.request_uri)
    req.set_form_data('api_key' => apiKey)
    res = Net::HTTP.start(
      uri.host, uri.port,
      :use_ssl => uri.scheme == 'https',
      :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |https|
      https.request(req)
    end

    #db = SQLite3::Database.new "test.db"
    $db.execute "CREATE TABLE IF NOT EXISTS feverUnread (urID INTEGER PRIMARY KEY, 
      urRead INTEGER,
      urProcessed INTEGER DEFAULT 0,
      UNIQUE(urID)
      )"

    my_hash = JSON.parse(res.body)
    #puts res.body

    allItems = my_hash['unread_item_ids']

    itemSplit = allItems.split(",");
    itemSplit.each do |item|
      #puts 'unreadID: ' + item
      ins = $db.prepare("INSERT OR REPLACE INTO feverUnread('urID', 'urRead', 'urProcessed') VALUES (?,0,1)")
      ins.bind_params(item)
      insRes = ins.execute
    end
    #allItems.each do |item|
    #  unread = item
    #  puts 'unread id: ' + unread
    #end



  end

  def getItems(startItem)
    if @config.key?(self.class.name)
      config = @config[self.class.name]
    end

    username = config['fafEmailAddr']
    password = config['fafPass']
    apiString = username + ":" + password
    md5 = Digest::MD5.new
    apiKey = md5.update apiString

    hostString = config['fafURL']
    if (!hostString.end_with?("/"))
      hostString = hostString + "/"
    end
    if (startItem == 0)
      queryURL = hostString + "?api&items"
    else
      queryURL = hostString + "?api&items&since_id=" + startItem.to_s
    end

    uri = URI.parse(queryURL)
    http = Net::HTTP.new(uri.host, uri.port)

    apiKeyString = apiKey.to_s

    req = Net::HTTP::Post.new(uri.request_uri)
    req.set_form_data('api_key' => apiKey)
    res = Net::HTTP.start(
      uri.host, uri.port,
      :use_ssl => uri.scheme == 'https',
      :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |https|
      https.request(req)
    end

    #db = SQLite3::Database.new "test.db"

    my_hash = JSON.parse(res.body)
    #puts res.body
    
    totalItems = my_hash['total_items']

    #puts my_hash['total_items']

    allItems = my_hash['items']
    itemCount = allItems.count
    #puts 'count: ' + itemCount.to_s

    #puts allItems[1]

    allItems.each do |item|
      itemID = item['id']
      itemFeedID = item['feed_id']
      itemTitle = item['title']
      itemAuthor = item['author']
      itemHTML = item['html']
      itemURL = item['url']
      itemSaved = item['is_saved']
      itemRead = item['is_read']
      itemCreated = item['created_on_time']

      #puts itemID.to_s + ' :: ' + itemAuthor.to_s + ' :: ' + itemRead.to_s

      #ins = db.prepare("INSERT INTO feverItems('itemID', 'itemFeedID', 'itemTitle', 'itemAuthor', 'itemURL', 'itemSaved', 'itemRead', 'itemCreated' values (?,?,?,?,?,?,?,?)")
      #ins.bind_params(itemID, itemFeedID, itemTitle, itemAuthor, itemHTML, itemURL, itemSaved, itemRead, itemCreated)
      #insRes = ins.execute
      ins = $db.prepare("INSERT OR REPLACE INTO feverItems('itemID', 'itemFeedID', 'itemTitle', 'itemAuthor', 'itemURL', 'itemSaved', 'itemRead', 'itemCreated', 'itemProcessed') VALUES (?,?,?,?,?,?,?,?,0)")
      ins.bind_params(itemID, itemFeedID, itemTitle, itemAuthor, itemURL, itemSaved, itemRead, itemCreated)
      insRes = ins.execute
    end

    maxItem = 0

    $db.execute("SELECT MAX(itemID) FROM feverItems") do |row|
      maxItem = row[0]
    end

    totCount = 0
    $db.execute("SELECT COUNT(itemID) FROM feverItems") do |row|
      totCount = row[0]
    end

    puts 'Downloading ' + totCount.to_s + ' entries of ' + totalItems.to_s

    return itemCount, maxItem
  end

  def buildFeedList
    config = @config[self.class.name]
    username = config['fafEmailAddr']
    password = config['fafPass']
    apiString = username + ":" + password
    md5 = Digest::MD5.new
    apiKey = md5.update apiString 
    #db = SQLite3::Database.new "test.db"

    hostString = config['fafURL']
    if (!hostString.end_with?("/"))
      hostString = hostString + "/"
    end
    queryURL = hostString + "?api&feeds"


    uri = URI.parse(queryURL)
    http = Net::HTTP.new(uri.host, uri.port)

    apiKeyString = apiKey.to_s

    req = Net::HTTP::Post.new(uri.request_uri)
    req.set_form_data('api_key' => apiKey)
    res = Net::HTTP.start(
      uri.host, uri.port,
      :use_ssl => uri.scheme == 'https',
      :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |https|
      https.request(req)
    end


    #db = SQLite3::Database.new "test.db"
    $db.execute "CREATE TABLE IF NOT EXISTS feverFeeds (feedID INTEGER PRIMARY KEY, 
      feedFaviconID INTEGER,
      feedTitle TEXT,
      feedURL TEXT,
      feedSiteURL TEXT,
      feedIsSpark INTEGER,
      feedUpdated DATETIME,
      feedProcessed INTEGER DEFAULT 0,
      UNIQUE(feedID)
      )"

    my_hash = JSON.parse(res.body)
    allFeeds = my_hash['feeds']
    feedCount = allFeeds.count
    puts 'feed count: ' + feedCount.to_s

    allFeeds.each do |feed|
      feedID = feed['id']
      feedTitle = feed['title']
      feedURL = feed['url']
      feedSiteURL = feed['site_url']
      feedIsSpark = feed['is_spark']
      feedUpdated = feed['last_updated_on_time']
      #feedProcessed = 0

      #puts itemID.to_s + ' :: ' + itemAuthor.to_s + ' :: ' + itemRead.to_s

      #ins = db.prepare("INSERT INTO feverItems('itemID', 'itemFeedID', 'itemTitle', 'itemAuthor', 'itemURL', 'itemSaved', 'itemRead', 'itemCreated' values (?,?,?,?,?,?,?,?)")
      #ins.bind_params(itemID, itemFeedID, itemTitle, itemAuthor, itemHTML, itemURL, itemSaved, itemRead, itemCreated)
      #insRes = ins.execute
      ins = $db.prepare("INSERT OR REPLACE INTO feverFeeds('feedID', 'feedTitle', 'feedURL', 'feedSiteURL', 'feedIsSpark', 'feedUpdated') VALUES (?,?,?,?,?,?)")
      ins.bind_params(feedID, feedTitle, feedURL, feedSiteURL, feedIsSpark, feedUpdated)
      insRes = ins.execute
    end

  end

  def dailyProcess
    #sql = "SELECT fi.rowid, fi.itemID, fi.itemFeedID, fi.itemTitle, fi.itemAuthor, fi.itemURL, fi.itemSaved, fi.itemRead, fi.itemCreated, fi.itemProcessed FROM feverItems fi WHERE fi.itemProcessed = 0 EXCEPT SELECT fu.urID FROM feverUnread fu;" # gets every item except the ones that are unread (= the read items)
    sql = "SELECT fi.rowid FROM feverItems fi WHERE fi.itemProcessed = 0 EXCEPT SELECT fu.urID FROM feverUnread fu;" # gets every item except the ones that are unread (= the read items)
    readArticles = "### Read Articles \n <ul>"
    readCount = 0

    #db = SQLite3::Database.new "test.db"
    #sql = "SELECT rowid, itemID, itemFeedID, itemTitle, itemAuthor, itemURL, itemSaved, itemRead, itemCreated, itemProcessed FROM feverItems WHERE itemRead='1' AND itemProcessed='0' AND itemCreated >= " + startDate.to_s + " AND itemCreated < " + endDate.to_s
    $db.execute(sql) do |row|
      stm = $db.prepare("SELECT rowid, itemID, itemFeedID, itemTitle, itemAuthor, itemURL, itemSaved, itemRead, itemCreated, itemProcessed FROM feverItems WHERE rowid = ?")
      stm.bind_params (row[0]) 
      rs = stm.execute
      ret = rs.next

    #db.execute ("SELECT rowid, itemID, itemFeedID, itemTitle, itemAuthor, itemURL, itemSaved, itemRead, itemCreated, itemProcessed FROM feverItems WHERE itemRead='1' AND itemProcessed='0' AND itemCreated >= startDate AND itemCreated < endDate") do |row|
      # doing this the civilized way resulted in strange errors, so doing it old fashioned
      rowid = ret[0]
      itemID = ret[1]
      itemFeedID = ret[2]
      itemTitle = ret[3]
      itemAuthor = ret[4]
      itemURL = ret[5]

      if (itemAuthor.length > 0) 
        authNote = " (" + itemAuthor + ")"
      else
        authNote = ""
      end
      ins = $db.prepare("UPDATE feverItems SET itemProcessed = 1 WHERE rowid = ?")
      ins.bind_params(rowid)
      ins.execute



      readArticles = readArticles + "<li><a href=\"" + itemURL + "\">" + itemTitle + "</a>" + authNote + "</li>"
      readCount = readCount + 1
    end

    tags = config['tags'] || ''
    tags = tags.scan(/#([A-Za-z0-9]+)/m).map { |tag| tag[0].strip }.delete_if {|tag| tag =~ /^\d+$/ }.uniq.sort

    if readCount > 0
      readArticles = readArticles + "</ul>\n"
      readTitle = '## Fever Activity'
      options = {}
      options['content'] = "# Fever Activity\n\n" + readArticles
      options['datestamp'] = Time.now.utc.iso8601
      #options['datestamp'] = endTimeStamp.utc.iso8601
      options['starred'] = false
      options['tags'] = tags
      options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip

      return options
    else
      return nil
    end    

  end

  def processEntries(startDate, endDate)

    #db = SQLite3::Database.new "test.db"

    # SELECT fi.itemID FROM feverItems fi EXCEPT SELECT fu.urID FROM feverUnread fu;

    savedItems = "### Saved Items\n<ul>"
    savedCount = 0
    sql = "SELECT rowid, itemID, itemFeedID, itemTitle, itemAuthor, itemURL, itemSaved, itemRead, itemProcessed FROM feverItems WHERE itemSaved = 1 AND itemProcessed = 0 AND itemCreated >= " + startDate.to_s + " AND itemCreated < " + endDate.to_s
    #db.execute ("SELECT rowid, itemID, itemFeedID, itemTitle, itemAuthor, itemURL, itemSaved, itemRead, itemProcessed FROM feverItems WHERE itemSaved = 1 AND itemProcessed = 0 AND itemCreated >= startDate AND itemCreated < endDate") do |row|
    $db.execute(sql) do |row|
      rowid = row[0]
      itemID = row[1]
      itemFeedID = row[2]
      itemTitle = row[3]
      itemAuthor = row[4]
      itemURL = row[5]

      savedCount = savedCount + 1

      if (itemAuthor.length > 0) 
        authNote = " (" + itemAuthor + ")"
      else
        authNote = ""
      end

      savedItems = savedItems + '<li><a href="' + itemURL + '">' + itemTitle + "</a>" + authNote + "</li>"

      ins = $db.prepare("UPDATE feverItems SET itemProcessed = 1 WHERE rowid = ?")
      ins.bind_params(rowid)
      ins.execute

    end
    if (savedCount > 0)
      savedItems = savedItems + "</ul>\n"
    else
      savedItems = ''
    end


    skippedFeeds = "### Feeds (Probably) Skipped\n<ul>"
    skipCount = 0
    sql = "SELECT DISTINCT ff.feedTitle, ff.feedURL FROM feverItems AS fi JOIN feverFeeds AS ff ON fi.itemFeedID = ff.feedID WHERE fi.itemRead = '1' AND fi.itemProcessed = '0' AND itemCreated >= " + startDate.to_s + " AND itemCreated < " + endDate.to_s + " GROUP BY fi.itemCreated HAVING COUNT(1) > 1;"
    $db.execute(sql) do |row|
    #db.execute ("SELECT DISTINCT ff.feedTitle, ff.feedURL FROM feverItems AS fi JOIN feverFeeds AS ff ON fi.itemFeedID = ff.feedID WHERE fi.itemRead = '1' AND fi.itemProcessed = '0' AND itemCreated >= startDate AND itemCreated < endDate GROUP BY fi.itemCreated HAVING COUNT(1) > 1;") do |row|
      skipCount = skipCount + 1
      skippedFeeds = skippedFeeds + '<li><a href="' + row[1] + '">' + row[0] + '</a></li>'
    end 
    skippedFeeds = skippedFeeds + '</ul>'

    if (skipCount > 0)
      sql2 = "SELECT rowid, itemID, itemFeedID, itemCreated FROM feverItems WHERE itemRead = '1' AND itemProcessed = '0' AND itemCreated >= " + startDate.to_s + " AND itemCreated < " + endDate.to_s + " GROUP BY itemCreated HAVING COUNT(1) > 1;"
      #db.execute ("SELECT rowid, itemID, itemFeedID, itemCreated FROM feverItems WHERE itemRead = '1' AND itemProcessed = '0' AND itemCreated >= startDate AND itemCreated < endDate GROUP BY itemCreated HAVING COUNT(1) > 1;") do |row|
      $db.execute(sql2) do |row|
        rowid = row[0]
        itemID = row[1]
        itemFeedID = row[2]
        itemCreated = row[3]

        ins = $db.prepare("UPDATE feverItems SET itemProcessed = '1' WHERE rowid=?")
        ins.bind_params(rowid)
        ins.execute



      end

      skippedFeeds = skippedFeeds + "</ul>\n"
    else
      skippedFeeds = ''
    end


    #return

    readArticles = "### Read Articles \n <ul>"
    readCount = 0
    sql = "SELECT rowid, itemID, itemFeedID, itemTitle, itemAuthor, itemURL, itemSaved, itemRead, itemCreated, itemProcessed FROM feverItems WHERE itemRead='1' AND itemProcessed='0' AND itemCreated >= " + startDate.to_s + " AND itemCreated < " + endDate.to_s
    $db.execute(sql) do |row|
    #db.execute ("SELECT rowid, itemID, itemFeedID, itemTitle, itemAuthor, itemURL, itemSaved, itemRead, itemCreated, itemProcessed FROM feverItems WHERE itemRead='1' AND itemProcessed='0' AND itemCreated >= startDate AND itemCreated < endDate") do |row|
      # doing this the civilized way resulted in strange errors, so doing it old fashioned
      rowid = row[0]
      itemID = row[1]
      itemFeedID = row[2]
      itemTitle = row[3]
      itemAuthor = row[4]
      itemURL = row[5]

      if (itemAuthor.length > 0) 
        authNote = " (" + itemAuthor + ")"
      else
        authNote = ""
      end


      readArticles = readArticles + "<li><a href=\"" + itemURL + "\">" + itemTitle + "</a>" + authNote + "</li>"

      ins = $db.prepare("UPDATE feverItems SET itemProcessed = '1' WHERE rowid=?")
      ins.bind_params(rowid)
      ins.execute
      readCount = readCount + 1

    end

    tags = config['tags'] || ''
    tags = tags.scan(/#([A-Za-z0-9]+)/m).map { |tag| tag[0].strip }.delete_if {|tag| tag =~ /^\d+$/ }.uniq.sort

    if readCount > 0
      endTimeStamp = Time.at(endDate)

      readArticles = readArticles + "</ul>\n"
      readTitle = '## Fever Activity'
      options = {}
      options['content'] = "# Fever Activity\n\n" + savedItems + readArticles + skippedFeeds
      #options['datestamp'] = Time.now.utc.iso8601
      options['datestamp'] = endTimeStamp.utc.iso8601
      options['starred'] = false
      options['tags'] = tags
      options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip

      return options
    else
      return nil
    end    

    

    #return entryText
    
  end


  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('fafEmailAddr') || config['fafPass'] == []
        @log.warn("<Service> has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        username = config['fafEmailAddr']
        password = config['fafPass']
        apiString = username + ":" + password
        md5 = Digest::MD5.new
        apiKey = md5.update apiString
        ##apiKey = md5(apiString)
        ##puts apiKey
      end
    else
      @log.warn("<Service> has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end

    buildFeedList

    maxItem = 0

    #db = SQLite3::Database.new "test.db"
    $db.execute "CREATE TABLE IF NOT EXISTS feverItems (itemID INTEGER PRIMARY KEY, 
      itemFeedID INTEGER,
      itemTitle TEXT,
      itemAuthor TEXT,
      itemHTML TEXT,
      itemURL TEXT,
      itemSaved INTEGER,
      itemRead INTEGER,
      itemCreated DATETIME,
      itemProcessed INTEGER,
      UNIQUE(itemID)
      )"

    $db.execute("SELECT MAX(itemID) FROM feverItems") do |row|
      maxItem = row[0]
      #puts 'maxItem: ' + maxItem.to_s
      #maxItem = row['itemID'].to_i
      #testNum = maxItem + 1
      #puts testNum.to_s
    end    

    updateUnread

    #giRes = getItems(0)
    #puts giRes[0].to_s
    #puts giRes[1].to_s
    startNum = maxItem
    resCount = 0

    giRes = getItems(startNum)
    resCount = giRes[0]
    startNum = giRes[1]

    puts 'resCount: ' + resCount.to_s
    if (resCount == 0)
      puts "No new read fever entries"
      #return
    else
      while resCount > 0 do
        giRes = getItems(startNum)
        resCount = giRes[0]
        startNum = giRes[1]
        #puts resCount.to_s + ' :: ' + startNum.to_s
      end
    end

    options = dailyProcess
    if (options != nil)  # check to make sure there's a point to posting today's activity before we do it
      # Create a journal entry
      # to_dayone accepts all of the above options as a hash
      # generates an entry base on the datestamp key or defaults to "now"
      sl = DayOne.new
      sl.to_dayone(options) 
    end


=begin
I had dreams of being able to go back in time and catching previous entries, but
it appears I was mistaken on how read entries work in FaF, so I need to end this line 
of thinking

    nowTime = Time.now.utc.to_i
    targetDate = @timespan.to_i
    puts "TargetDate: " + targetDate.to_s
    puts "timespan: " + timespan.to_i.to_s
    puts 'Nowtime: ' + nowTime.to_s

    rev = 0
    while (targetDate < nowTime) do
      endDate = targetDate + 60 * 60 * 24
      options = processEntries(targetDate, endDate)  
      puts targetDate.to_s + ' :: ' + endDate.to_s
      targetDate = endDate
      rev += 1
      puts 'rev: ' + rev.to_s


      if (options != nil)  # check to make sure there's a point to posting today's activity before we do it
        # Create a journal entry
        # to_dayone accepts all of the above options as a hash
        # generates an entry base on the datestamp key or defaults to "now"
        sl = DayOne.new
        sl.to_dayone(options) 
     # else
     #   break
      end      
      
    end
    #return
=end
   

  end

  def helper_function(args)
    # add helper functions within the class to handle repetitive tasks
  end
end
