class DayOne < Slogger
  def to_dayone(options = {})
    content = options['content'] || ''
    uuid = options['uuid'] || %x{uuidgen}.gsub(/-/,'').strip
    starred = options['starred'] || false
    datestamp = options['datestamp'] || Time.now.utc.iso8601

    # entry = CGI.escapeHTML(content.unpack('C*').pack('U*').gsub(/[^[:punct:]\w\s]+/,' ')) unless content.nil?
    entry = CGI.escapeHTML(content) unless content.nil?
    @dayonepath = storage_path
    @log.info("Saving entry to #{@dayonepath}/entries/#{uuid}.doentry")
    fh = File.new(File.expand_path(@dayonepath+'/entries/'+uuid+".doentry"),'w+')
    fh.puts @template.result(binding)
    fh.close
    return true
  end

  def save_image(imageurl,uuid)
    @dayonepath = Slogger.new.storage_path
    source = imageurl.gsub(/^https/,'http')
    match = source.match(/(\..{3,4})($|\?|%22)/)
    unless match.nil?
      ext = match[1]
    else
      @log.warn("Attempted to save #{imageurl} but extension could not be determined")
      ext = '.jpg'
    end
    target = @dayonepath + '/photos/'+uuid+ext
    begin
      Net::HTTP.get_response(URI.parse(imageurl)) do |http|
        data = http.body
        @log.info("Retrieving image: #{imageurl} to #{target}")
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
    match = orig.match(/(\..{3,4})$/)
    return false if match.nil?
    ext = match[1]
    @log.info("Resizing image #{orig}")
    orig = %x{orig="#{orig}";sips -Z 800 --out $TMPDIR/${orig##*/} "$orig";echo $TMPDIR${orig##*/}}
    unless ext =~ /\.jpg$/
      case ext
      when '.jpeg'
        target = orig.gsub(/\.jpeg$/,'.jpg')
        FileUtils.mv(orig,target)
        return target
      when /\.(png|gif|tiff)$/
        # if File.exists?('/usr/local/bin/convert')
        #   target = orig.gsub(/#{ext}$/,'.jpg')
        #   @log.info("Converting #{orig} to JPEG")
        #   %x{/usr/local/bin/convert "#{orig}" "#{target}"}
        #   File.delete(orig)
        #   return target
        # else
        #   @log.warn("Image could not be converted to JPEG format and may not show up in Day One. Please install ImageMagick.")
        #   return orig
        # end
        return orig
      else
        return orig
      end
    end
    return orig
  end

  def store_single_photo(file, options = {}, copy = false)

    options['content'] ||= ''
    options['uuid'] ||= %x{uuidgen}.gsub(/-/,'').strip
    options['starred'] ||= false
    options['datestamp'] ||= Time.now.utc.iso8601
    target_path = File.expand_path(Slogger.new.storage_path+"/photos/"+options['uuid']+".jpg")

    if copy
      FileUtils.copy(File.expand_path(file),target_path)
    end

    res = self.process_image(File.expand_path(file))
    if res
      options['content'] = File.basename(res,'.jpg') if options['content'] == ''
      return self.to_dayone(options)
    end
  end
end
