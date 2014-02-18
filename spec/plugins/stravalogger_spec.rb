require_relative 'spec_helper'
require 'stravalogger'

describe StravaLogger do
  let(:strava) {
    StravaLogger.new
  }

  it "grabs the feed and posts new entries" do
    strava.do_log
  end
end
