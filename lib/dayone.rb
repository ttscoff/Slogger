require 'fileutils'
require 'digest/md5'
require 'pp'

class DayOne < Slogger
  def to_dayone(options = {})
    @dayonepath = storage_path
    markdown = @dayonepath =~ /Journal[._]dayone\/?$/ ? false : true
    content = options['content'] || ''
    # Defaults to tags passed as options, but falls back to hashtags if option isn't present
    tags = options['tags'] || content.scan(/#([A-Za-z0-9]+)/m).map { |tag| tag[0] }.delete_if {|tag| tag =~ /^\d+$/ }.uniq.sort
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
    if options['location']
       location = true
       lat = options['lat']
       long = options['long']
       place = options['place'] || ''
    end

    # entry = CGI.escapeHTML(content.unpack('C*').pack('U*').gsub(/[^[:punct:]\w\s]+/,' ')) unless content.nil?

    # @dayonepath = storage_path
    encoding_options = {
      :invalid           => :replace,  # Replace invalid byte sequences
      :undef             => :replace,  # Replace anything not defined in ASCII
      :replace           => ''         # Use a blank for those replacements
    }

    @log.info("=====[ Saving entry to entries/#{uuid} ]")
    ext = markdown ? ".md" : ".doentry"
    entry_dir = File.join(File.expand_path(@dayonepath), "entries")
    Dir.mkdir(entry_dir, 0700) unless File.directory?(entry_dir)
    fh = File.new("#{entry_dir}/#{uuid}#{ext}",'w+')

    begin
      fh.puts @template.result(binding).encode(Encoding.find('ASCII'), encoding_options)
    rescue
      fh.puts @template.result(binding)
    end
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

  def levenshtein_distance(s, t)
    m = s.size
    n = t.size
    d = Array.new(m+1) { Array.new(n+1) }
    for i in 0..m
      d[i][0] = i
    end
    for j in 0..n
      d[0][j] = j
    end
    for j in 0...n
      for i in 0...m
        if s[i,1] == t[j,1]
          d[i+1][j+1] = d[i][j]
        else
          d[i+1][j+1] = [d[i  ][j+1] + 1, # deletion
                         d[i+1][j  ] + 1, # insertion
                         d[i  ][j  ] + 1  # substitution
                        ].min
        end
      end
    end
    d[m][n]
  end

  def dedup(similar=false)
    files = Dir.glob(File.join(storage_path, 'entries', '*.doentry'))
    to_keep = []
    to_delete = []
    similar_threshold = 30

    if (similar)
      dot_counter = 0
      files.each {|file|
        next if to_keep.include?(file) || to_delete.include?(file)
        photo_path = File.join(storage_path, 'photos')
        photo = File.join(photo_path, File.basename(file,'.doentry')+'.jpg')
        if File.exists?(photo)
          to_keep.push(file)
          next
        end

        to_keep.push(file)

        data = Plist::parse_xml(file)
        date = data['Creation Date'].strftime('%Y%m%d')
        lines = data['Entry Text'].split("\n")
        lines.delete_if {|line| line =~ /^\s*$/ }
        text1 = lines.join('')[0..30]

        files.each {|file2|
          next if to_keep.include?(file2) || to_delete.include?(file2)
          photo = File.join(photo_path, File.basename(file,'.doentry')+'.jpg')
          if File.exists?(photo)
            to_keep.push(file)
            next
          end

          data2 = Plist::parse_xml(file2)

          if data2['Creation Date'].strftime('%Y%m%d') == date
            lines2 = data2['Entry Text'].split("\n")
            lines2.delete_if {|line| line =~ /^\s*$/ }
            text2 = lines2.join('')[0..30]

            distance = Levenshtein.normalized_distance(text1, text2, threshold=nil) * 100
            if distance < similar_threshold
              distance2 = Levenshtein.normalized_distance(lines.join('')[0..500], lines2.join('')[0..500])
              if distance2 > similar_threshold
                printf "\r%02.4f: %s => %s\n" % [distance, File.basename(file), File.basename(file2)]
                dot_counter = 0
                if lines2.join("\n").length > lines.join("\n").length
                  to_delete.push(file)
                  to_keep.delete(file)
                else
                  to_delete.push(file2)
                  to_keep.delete(file2)
                end
              end
            else
              print "."
              dot_counter += 1
              if dot_counter == 91
                print "\r"
                dot_counter = 0
              end
              to_keep.push(file2)
            end
            # if distance < similar_threshold
            #   puts "#{distance}: #{File.basename(file)} => #{File.basename(file2)}"
            #   if lines2.join("\n").length > lines.join("\n").length
            #     to_delete.push(file)
            #     to_keep.delete(file)
            #   else
            #     to_delete.push(file2)
            #     to_keep.delete(file2)
            # end
          end
        }
      }
      exit
    else
      hashes = []
      files.each {|file|
        data = Plist::parse_xml(file)
        tags = data['Tags'].nil? ? '' : data['Tags'].join('')
        hashes.push({ 'filename' => file, 'date' => data['Creation Date'], 'hash' => Digest::MD5.hexdigest(data['Entry Text']+tags+data['Starred'].to_s) })
      }

      hashes.sort_by!{|entry| entry['date']}

      existing = []
      to_delete = []
      hashes.each {|entry|
        if existing.include?(entry['hash'])
          to_delete.push(entry['filename'])
        else
          existing.push(entry['hash'])
        end
      }
      to_delete.uniq!
    end

    images = Dir.glob(File.join(storage_path, 'photos', '*.jpg'))
    image_hashes = []

    images_to_delete = []
    images.each {|image|
      image_hashes.push({ 'filename' => image, 'hash' => Digest::MD5.file(image), 'date' => File.stat(image).ctime })
    }

    image_hashes.sort_by!{|image| image['date']}

    images_existing = []
    images_to_delete = []
    image_hashes.each {|image|
      if images_existing.include?(image['hash'])
        images_to_delete.push(image['filename'])
      else
        images_existing.push(image['hash'])
      end
    }

    # puts "Ready to move #{to_delete.length} files to the Trash?"
    trash = File.expand_path('~/Desktop/DayOneDuplicates')

    FileUtils.mkdir_p(File.join(trash,"photos")) unless File.directory?(File.join(trash,"photos"))
    FileUtils.mkdir_p(File.join(trash,"entries")) unless File.directory?(File.join(trash,"entries"))

    photo_path = File.join(storage_path, 'photos')

    to_delete.each {|file|

      photo = File.join(photo_path, File.basename(file,'.doentry')+'.jpg')
      if File.exists?(photo)
        images_to_delete.delete(photo)
        FileUtils.mv(photo,File.join(trash,'photos'))
      end

      FileUtils.mv(file,File.join(trash,'entries'))
    }

    entry_path = File.join(storage_path, 'entries')
    images_deleted = 0

    images_to_delete.each {|file|

      entry = File.join(entry_path, File.basename(file,'.jpg')+'.doentry')
      next if File.exists?(entry)

      if File.exists?(file)
        FileUtils.mv(file,File.join(trash,"photos"))
        images_deleted += 1
      end
    }

    @log.info("Moved #{to_delete.length} entries/photos to #{trash}.")
    @log.info("Found and moved #{images_deleted} images without entries.")
    # %x{open -a Finder #{trash}}
  end
end
