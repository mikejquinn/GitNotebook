require "digest"
require "open-uri"
module Gravatar
  def self.hashed_email(email)
    Digest::MD5.hexdigest(email.strip.downcase)
  end

  module SinatraHelpers
    def self.included(klass)
      klass.class_eval do
        helpers do
          def gravatar_image_tag(email, size, options = {})
            options = options.dup.merge({size: size})
            html_options = options.delete(:html_options) || {}
            html_options.map{ |(k,v)| "#{k}='#{v}'" }.join(" ")
            options = options.map{ |(k,v)| "#{URI::encode(k.to_s)}=#{URI::encode(v.to_s)}" }.join("&")
            url = "http://www.gravatar.com/avatar/#{Gravatar.hashed_email(email)}.jpg?#{options}"
            "<img width='#{size}' height='#{size}' src='#{url}' />"
          end
        end
      end
    end
  end
end
