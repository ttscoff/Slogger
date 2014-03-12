=begin
Plugin: YahooFinanceLogger
Description: Logs a portfolio of prices from Yahoo finance
Author: [Hilton Lipschitz](http://www.hiltmon.com)
Configuration:
  - tickers: an array of valid Yahoo tickers to log
  - show_details: If true, adds day and 52 week high and low, volume, P/E and Market Cap
Notes:
  - Does not run on weekends as the markets are closed (but does run on holidays)
  - Runs in real time, so if run during the day, will get as at the run time values
=end

config = {
  'description' => [
    'Logs up to yesterday\`s Yahoo Finance prices',
    'tickers are a list of the Yahoo Finance Tickers you want (^GSPC => S&P500, ^IXIC => NasDaq, ^DJI => DowJones, AAPL => Apple Inc, AUDUSD=X => AUD/USD, USDJPY=X => USD/JPY, ^TNX => 10-Year Bond)',
    'show_details adds day and 52 week high and low, volume, P/E and Market Cap'
  ],
  'tickers' => [ '^GSPC', '^IXIC', '^DJI', 'AAPL', 'GOOG' ], # A list of Yahoo Finance Tickers to log
  'show_details' => true,
  'tags' => '#social #finance'
}

$slog.register_plugin({ 'class' => 'YahooFinanceLogger', 'config' => config })

require 'CSV'
    
class YahooFinanceLogger < Slogger

  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('tickers') || config['tickers'] == []
        @log.warn("<YahooFinanceLogger> has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      end
    else
      @log.warn("<YahooFinanceLogger> has not been configured or a feed is invalid, please edit your slogger_config file.")
      return
    end
    @log.info("Logging <YahooFinanceLogger> Tickers")

    tickers = config['tickers']
    @tags = config['tags'] || ''
    tags = "\n\n#{@tags}\n" unless @tags == ''
    show_details = (config['show_details'] == true)

    # This logger gets real-time data from Yahoo, so whatever time you run it, that's the data
    # I prefer to run my Slogger late at night, so this gets me the day's close
    weekday_now = Time.now.strftime('%a')
    if weekday_now == 'Sat' || weekday_now == 'Sun'
      @log.warn("Its a weekend, nothing to do.")
      return
    end
    
    symbols = tickers.join("+")
    symbols = tickers.join("+")
    uri = URI(URI.escape("http://download.finance.yahoo.com/d/quotes.csv?s=#{symbols}&f=nl1c1oghjkpvrj1"))
    
    res = Net::HTTP.get_response(uri)
    unless res.is_a?(Net::HTTPSuccess)
      @log.warn("Unable to get data from Yahoo Finance.")
      return
    end
    
    data = CSV.parse(res.body)
    
    content = []
    data.each do |row|
      if show_details == true
        content << "* **#{row[0]}**: #{commas(row[1])} (#{row[2]}%)\n  Low: #{commas(row[4])} (52 Low: #{commas(row[6])})\n  High: #{commas(row[5])} (52 High: #{commas(row[7])})\n  Volume: #{commas(row[9])}\n  P/E Ratio: #{commas(row[10])}\n  Market Cap: #{commas(row[11])}"
      else
        content << "* **#{row[0]}**: #{commas(row[1])} (#{row[2]}%)"
      end
    end

    # And log it
    options = {}
    options['content'] = "## Today\'s Markets\n\n#{content.join("\n\n")}\n\n#{tags}"
    options['datestamp'] = Time.now.utc.iso8601
    # options['starred'] = true
    # options['uuid'] = %x{uuidgen}.gsub(/-/,'').strip

    sl = DayOne.new
    sl.to_dayone(options)
  end
  
  def commas(value)
    value.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
  end
end
