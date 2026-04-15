source "https://rubygems.org"

ruby "3.3.0"

gem "rails", "~> 8.0.5"
gem "rubot", git: "https://github.com/bootstrapital/rubot.git"
gem "ruby_llm"
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"
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

gem "dockerfile-rails", ">= 1.7", :group => :development
