1=>
sudo nano /usr/local/bigbluebutton/core/scripts/post_publish/copy_events.rb

#content:
#!/usr/bin/ruby
require 'optimist'
require 'fileutils'

# دریافت پارامترهای ارسالی از سمت سیستم BBB
opts = Optimist::options do
  opt :meeting_id, "Meeting ID", :type => String
  opt :format, "Playback format name", :type => String
end

meeting_id = opts[:meeting_id]

# اگر آیدی خالی بود خارج شود
if meeting_id.nil? || meeting_id.empty?
  exit 1
end

# تعریف مسیرها
raw_events_path = "/var/bigbluebutton/recording/raw/#{meeting_id}/events.xml"
published_dir = "/var/bigbluebutton/published/presentation/#{meeting_id}"

# کپی فایل در صورت وجود هر دو مسیر
if File.exist?(raw_events_path) && Dir.exist?(published_dir)
  dest_file = "#{published_dir}/events.xml"
  FileUtils.cp(raw_events_path, dest_file)
  
  # تنظیم سطح دسترسی برای دانلود وب
  FileUtils.chmod(0644, dest_file)
end


2=>
sudo chown bigbluebutton:bigbluebutton /usr/local/bigbluebutton/core/scripts/post_publish/copy_events.rb
3=>
sudo chmod 755 /usr/local/bigbluebutton/core/scripts/post_publish/copy_events.rb