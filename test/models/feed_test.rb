require 'test_helper'

describe Feed do

  let(:feed) { create(:feed) }
  let(:feed_response) { create(:feed_response) }

  describe 'entries and updates' do

    let (:feed_entry) { create(:feed_entry) }

    it 'can find an existing entry by entry_id' do
      entry = OpenStruct.new
      entry.entry_id = feed_entry.entry_id
      feed_entry.feed.find_entry(entry).wont_be_nil
    end
  end

  describe 'http requests' do
    if use_webmock?

      before {
        stub_request(:get, 'http://feeds.99percentinvisible.org/99percentinvisible').
          to_return(:status => 200, :body => test_file('/fixtures/99percentinvisible.xml'), :headers => {})


        stub_request(:get, 'http://www.npr.org/rss/podcast.php?id=510289').
          to_return(:status => 200, :body => test_file('/fixtures/99percentinvisible.xml'), :headers => {})
      }

      it 'will retrieve or use last valid response' do

        response = feed.updated_response
        feed.updated_response.wont_be_nil

        stub_request(:get, 'http://feeds.99percentinvisible.org/99percentinvisible').
          to_return(:status => 200, :body => test_file('/fixtures/99percentinvisible.xml'), :headers => { 'Expires' => 1.day.since.httpdate, 'Date' => Time.now.httpdate })

        response = feed.updated_response
        feed.updated_response.must_be_nil
      end

      it 'can retrieve a podcast feed' do
        response = feed.retrieve
        response.wont_be_nil
        response.must_be_instance_of(FeedResponse)
      end

      it 'can retrieve a podcast feed url with query params' do
        feed = Feed.create!(feed_url: 'http://www.npr.org/rss/podcast.php?id=510289')
        response = feed.retrieve
        response.wont_be_nil
        response.must_be_instance_of(FeedResponse)
      end

      it 'can validate if a response is modified' do
        resp = feed.validate_response(feed_response)
        resp.wont_be_nil

        stub_request(:get, 'http://feeds.99percentinvisible.org/99percentinvisible').
          to_return(:status => 304, :body => test_file('/fixtures/99percentinvisible.xml'), :headers => {})

        resp = feed.validate_response(feed_response)
        resp.must_be_nil
      end

      it 'sets http headers for feed request' do
        feed_response.last_modified = 1.hour.ago
        feed_response.etag = 'thisisnotarealetag'
        http_response = feed.feed_http_response(feed_response)

        http_response.env.request_headers.wont_be_nil
        http_response.env.request_headers['If-Modified-Since'].wont_be_nil
        http_response.env.request_headers['If-None-Match'].must_equal 'thisisnotarealetag'
      end

    end
  end

  it 'returns the uri for the feed' do
    feed.uri.must_be_instance_of(Addressable::URI)
    feed.uri.to_s.must_equal 'http://feeds.99percentinvisible.org/99percentinvisible'
  end

  it 'returns uri query params' do
    feed = Feed.new(feed_url: 'http://www.npr.org/rss/podcast.php?id=510289')
    feed.uri.query_values['id'].must_equal '510289'
  end

  it 'can create a new connection' do
    conn = feed.connection
    conn.wont_be_nil
    conn.url_prefix.to_s.must_equal 'http://feeds.99percentinvisible.org/'
  end

  it 'sets a custom user agent' do
    conn = feed.connection
    conn.headers['User-Agent'].wont_match /Faraday/
    conn.headers['User-Agent'].must_match /^PRX Crier/
  end

  it 'can get last successful response' do
    response = feed_response
    response.wont_be_nil
    feed = feed_response.feed
    feed.last_successful_response.must_equal response
  end
end
