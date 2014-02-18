require_relative 'spec_helper'
require 'stravalogger'

describe StravaLogger do
  let(:strava) {
    StravaLogger.new.tap do |strava|
      strava.config = {
        'StravaLogger' => {
        }
      }
    end
  }

  it 'warns if config not found' do
    strava.config.delete('StravaLogger')
    strava.log.should_receive(:warn).with('Strava has not been configured or is invalid, please edit your slogger_config file.')
    strava.do_log
  end

  it 'warns if access_token is not set' do
    strava.config['StravaLogger']['strava_access_token'] = '   '
    strava.log.should_receive(:warn).with('Strava access token has not been configured, please edit your slogger_config file.')
    strava.do_log
  end

  it 'grabs the feed' do
    VCR.use_cassette('strava') do
      strava.config['StravaLogger']['strava_access_token'] = 'the_access_token'
      strava.do_log
    end
  end
end
