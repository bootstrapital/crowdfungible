source "https://rubygems.org"

ruby "3.3.0"

gem "rails", "~> 8.0.5"
gem "rubot", path: "/Users/datadavis/Documents/GitHub/rubot"
gem "ruby_llm"
gem "sprockets-rails"
gem "sqlite3", "~> 2.0"
gem "puma", ">= 5.0"
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
  gem "brakeman", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
