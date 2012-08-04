class DayOne < SocialLogger
  def initialize
    dayonedir = %x{ls ~/Library/Mobile\\ Documents/|grep dayoneapp}.strip
    @dayonepath = File.expand_path("~/Library/Mobile\ Documents/#{dayonedir}/Documents/Journal_dayone/")
    @template = ERB.new <<-XMLTEMPLATE
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Creation Date</key>
  <date><%= datestamp %></date>
  <key>Entry Text</key>
  <string><%= entry %></string>
  <key>Starred</key>
  <<%= starred %>/>
  <key>UUID</key>
  <string><%= uuid %></string>
</dict>
</plist>
XMLTEMPLATE
  end
  attr_accessor :dayonepath

  def to_dayone(options = {})
    content = options['content'] || ''
    uuid = options['uuid'] || %x{uuidgen}.gsub(/-/,'').strip
    starred = options['starred'] || false
    datestamp = options['datestamp'] || Time.now.utc.iso8601

    if @debug || options['debug']
      $stderr.puts "Logging: "+content
      return
    end

    entry = CGI.escapeHTML(content.unpack('C*').pack('U*').gsub(/[^[:punct:]\w\s]+/,' ')) unless content.nil?

    fh = File.new(File.expand_path(@dayonepath+'/entries/'+uuid+".doentry"),'w+')
    fh.puts @template.result(binding)
    fh.close
    return true
  end

  def save_image(imageurl,uuid)
    source = imageurl.gsub(/^https/,'http')
    match = source.match(/(\..{3,4})($|\?|%22)/)
    unless match.nil?
      ext = match[1]
    else
      Logger.new(STDERR).warn("Attempted to save #{imageurl} but extension could not be determined")
      ext = '.jpg'
    end
    target = @dayonepath + '/photos/'+uuid+ext
    begin
      Net::HTTP.get_response(URI.parse(imageurl)) do |http|
        data = http.body
        open( File.expand_path(target), "wb" ) { |file| file.write(data) }
      end
      return self.process_image(target)
    rescue Exception => e
      p e
      return false
    end
  end

  def process_image(image)
    orig = File.expand_path(image)
    match = orig.match(/(\..{3,4})/)
    return false if match.nil?
    ext = match[1]
    %x{sips -Z 800 "#{orig}"}
    unless ext =~ /\.jpg$/
      case ext
      when '.jpeg'
        target = orig.gsub(/\.jpeg$/,'.jpg')
        FileUtils.mv(orig,target)
        return target
      when /\.(png|gif)/
        target = orig.gsub(/#{ext}$/,'.jpg')
        %x{/usr/local/bin/convert "#{orig}" "#{target}"}
        File.delete(orig)
        return target
      else
        return false
      end
    end
    return image
  end

  def store_single_photo(file, options = {})
    options['content'] ||= ''
    options['uuid'] ||= %x{uuidgen}.gsub(/-/,'').strip
    options['starred'] ||= false
    options['datestamp'] ||= Time.now.utc.iso8601

    res = self.process_image(File.expand_path(file))

    FileUtils.copy(res,File.expand_path(@dayonepath+"/photos/"+options['uuid']+".jpg")) if res

    return self.to_dayone(options)
  end
end
