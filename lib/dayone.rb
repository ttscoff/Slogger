require 'fileutils'

class DayOne < Slogger
  def to_dayone(options = {})
    @dayonepath = storage_path
    markdown = @dayonepath =~ /Journal[._]dayone\/?$/ ? false : true
    content = options['content'] || ''
    tags = content.scan(/#([A-Za-z0-9]+)/m).map { |tag| tag[0] }.delete_if {|tag| tag =~ /^\d+$/ }.uniq.sort
    unless markdown
      uuid = options['uuid'] || %x{uuidgen}.gsub(/-/,'').strip
      datestamp = options['datestamp'] || Time.now.utc.iso8601
      entry = CGI.escapeHTML(content) unless content.nil?
    else
      img_path = false
      uuid = options['uuid'] || false
      if uuid
        for ext in %w[jpg jpeg gif tiff svg png]
          img_path = "../photos/#{uuid}.#{ext}" if File.exists?(@dayonepath+"/photos/#{uuid}.#{ext}")
        end
      end
      entry = content.nil? ? '' : content
      if img_path
        entry = "![](#{img_path})\n\n" + entry
      end
      uuid = Time.now.strftime('%Y-%m-%d_%I%M%S')+"_"+(rand(5000).to_s)
      if options['datestamp']
        datestamp = Date.parse(options['datestamp']).strftime('%x')
      else
        datestamp = Time.now.strftime('%x')
      end
    end
    starred = options['starred'] || false

    # entry = CGI.escapeHTML(content.unpack('C*').pack('U*').gsub(/[^[:punct:]\w\s]+/,' ')) unless content.nil?

    # @dayonepath = storage_path
    @log.info("=====[ Saving entry to entries/#{uuid} ]")
    ext = markdown ? ".md" : ".doentry"
    entry_dir = File.join(File.expand_path(@dayonepath), "entries")
    Dir.mkdir(entry_dir, 0700) unless File.directory?(entry_dir)
    fh = File.new("#{entry_dir}/#{uuid}#{ext}",'w+')
    fh.puts @template.result(binding)
    fh.close
    return true
  end

  def save_image(imageurl,uuid)
    @dayonepath = Slogger.new.storage_path
    source = imageurl.gsub(/^https/,'http')
    match = source.match(/(\..{3,4})($|\?|%22)/)
    ext = match.nil? ? match[1] : '.jpg'
    target = @dayonepath + "/photos/#{uuid}.jpg"
    begin
      Net::HTTP.get_response(URI.parse(imageurl)) do |http|
        data = http.body
        @log.info("Retrieving image -\n           Source: #{imageurl}\n      Target UUID: #{uuid}")
        if data == false || data == 'false'
          @log.warn("Download failed")
          return false
        else
          path = File.expand_path(target)
          dir = File.dirname(path)
          FileUtils::mkdir_p(dir)
          open( path, "wb" ) { |file| file.write(data) }
        end
      end
      return target
    rescue Exception => e
      p e
      return false
    end
  end

  def process_image(image)
    orig = File.expand_path(image)

    match = orig.match(/(\..{3,4})$/)
    return false if match.nil?
    ext = match[1]
    @log.info("Resizing image #{File.basename(orig)}")
    res = %x{sips -Z 2100 "#{orig}" 2>&1}
    unless ext =~ /\.jpg$/
      case ext
      when '.jpeg'
        @log.info("81")
        target = orig.gsub(/\.jpeg$/,'.jpg')
        FileUtils.mv(orig,target)
        return target
      # when /\.(png|gif|tiff)$/
      #   if File.exists?('/usr/local/bin/convert')
      #     target = orig.gsub(/#{ext}$/,'.jpg')
      #     @log.info("Converting #{orig} to JPEG")
      #     %x{/usr/local/bin/convert "#{orig}" -background white -mosaic +matte "#{target}"}
      #     File.delete(orig)
      #     return target
      #   else
      #     @log.warn("Image could not be converted to JPEG format and may not show up in Day One. Please install ImageMagick (available through brew).")
      #     return orig
      #   end
      #   return orig
      else
        return orig
      end
    end
    return orig
  end

  def store_single_photo(file, options = {}, copy = false)

    options['content'] ||= File.basename(file,'.jpg') if @config['image_filename_is_title']
    options['uuid'] ||= %x{uuidgen}.gsub(/-/,'').strip
    options['starred'] ||= false
    options['datestamp'] ||= Time.now.utc.iso8601
    photo_dir = File.join(File.expand_path(Slogger.new.storage_path), "photos")
    Dir.mkdir(photo_dir, 0700) unless File.directory?(photo_dir)

    target_path = File.join(photo_dir,options['uuid']+".jpg")

    if copy
      FileUtils.copy(File.expand_path(file),target_path)
      file = target_path
    end

    res = self.process_image(File.expand_path(file))
    if res
      return self.to_dayone(options)
    end
  end
end
