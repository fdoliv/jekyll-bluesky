# lib/jekyll_bluesky.rb
require 'jekyll'
require 'http'
require 'json'
require 'time' 

puts 'Plugin jekyll-bluesky load successfully!'

module Jekyll
  class BlueskyPlugin < Liquid::Tag
    def initialize(tag_name, text, tokens)
      super
      args = text.strip.split
      @actor = args[0]
      @limit = args[1] || '10'
      Jekyll.logger.debug "Initializing tag bluesky with actor: #{@actor}, limit: #{@limit}"
    end

    def render(context)
      Jekyll.logger.debug 'Rendering bluesky tag...'
      Jekyll::Client.fetch_post(@actor, @limit)
    end
  end

  class Client
    API_URL = 'https://public.api.bsky.app'

    def self.fetch_post(actor, limit)
      response = HTTP.get("#{API_URL}/xrpc/app.bsky.feed.getAuthorFeed?actor=#{actor}&limit=#{limit}&filter=posts_and_author_threads")
      if response.status.success?
        data = JSON.parse(response.body)
        format_post(data)
      else
        error_details =
          begin
            JSON.parse(response.body)
          rescue JSON::ParserError
            response.body.to_s
          end

        "Error fetching post from Bluesky (status: #{response.status}). Details: #{error_details}"
      end
    end

    def self.format_post(data)
      posts = data['feed']
      styles = <<~HTML
        <style>
          @font-face {
            font-family: 'InterVariable';
            src: url("https://web-cdn.bsky.app/static/media/InterVariable.c504db5c06caaf7cdfba.woff2") format('woff2');
            font-weight: 300 1000;
            font-style: normal;
            font-display: swap;
          }
          .bluesky-post {
            border-bottom: 1px solid #e1e8ed;
            padding: 12px;
            width: 500px;
            font-family: 'InterVariable', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Liberation Sans', Helvetica, Arial, sans-serif;
            background: #fff;
            margin-bottom: 10px;
          }
          .bluesky-header {
            display: inline-flex;
            align-items: center;
            justify-content: flex-start;
            gap: 8px;
          }
          .bluesky-avatar {
            width: 40px;
            height: 40px;
            border-radius: 50%;
          }
          .bluesky-author-info {
            display: flex;
            flex-direction: column;
            align-items: flex-start;
          }
          .author-name {
            font-weight: bold;
            font-size: 14px;
            color: #000;
          }
          .author-handle {
            font-size: 12px;
            color: #657786;
          }
          .bluesky-content {
            font-size: 14px;
            line-height: 1.5;
            color: #14171A;
            margin-top: 8px;
          }
          .bluesky-footer {
            display: flex;
            justify-content: space-between;
            font-size: 12px;
            color: #657786;
            margin-top: 10px;
          }
          .icon {
            cursor: pointer;
          }
        </style>
      HTML

      formatted_posts = posts.map do |post|
        post_data = post['post']
        author = post_data['author']
        record = post_data['record']
        embed = post_data['embed']

        text = record['text'].gsub("\n", "<br>")
        author_name = author['displayName']
        author_handle = author['handle']
        post_time = calculate_post_time(record['createdAt'])

        image_html = ''
        if embed && embed['$type'] == 'app.bsky.embed.images#view'
          image_html = embed['images'].map do |image|
            <<~HTML
              <img src="#{image['thumb']}" alt="#{image['alt']}" class="bluesky-image" />
            HTML
          end.join
        end

        <<~HTML
          <div class="bluesky-post">
            <div class="bluesky-header">
              <img src="#{author['avatar']}" alt="#{author_name}" class="bluesky-avatar" />
              <div class="bluesky-author-info">
                <span class="author-name">#{author_name}</span>
                <span class="author-handle">@#{author_handle} · #{post_time}</span>
              </div>
            </div>
            <div class="bluesky-content">
              <p>#{text}</p>
              #{image_html}
            </div>
            <div class="bluesky-footer">
              <span class="icon">💬 #{post_data['replyCount']}</span>
              <span class="icon">🔁 #{post_data['repostCount']}</span>
              <span class="icon">❤️ #{post_data['likeCount']}</span>
              <span class="icon">···</span>
            </div>
          </div>
        HTML
      end.join("\n")

      styles + formatted_posts
    end

    def self.calculate_post_time(created_at)
      post_time = Time.parse(created_at)
      current_time = Time.now
      difference_in_seconds = (current_time - post_time).round

      if difference_in_seconds < 60
        "#{difference_in_seconds}s"
      elsif difference_in_seconds < 3600
        "#{(difference_in_seconds / 60).round}m"
      elsif difference_in_seconds < 86400
        "#{(difference_in_seconds / 3600).round}h"
      else
        "#{(difference_in_seconds / 86400).round}d"
      end
    end
  end
end

Liquid::Template.register_tag 'bluesky', Jekyll::BlueskyPlugin
