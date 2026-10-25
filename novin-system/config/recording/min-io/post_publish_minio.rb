require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.on("-m", "--meeting-id ID", "Meeting ID") do |v|
    options[:meeting_id] = v
  end
  opts.on("-f", "--format FORMAT", "Format") do |v|
    options[:format] = v
  end
end.parse!

meeting_id = options[:meeting_id]
playback_format = options[:format]

if playback_format == 'presentation' && !meeting_id.nil?
  system("/usr/local/bigbluebutton/core/scripts/post_publish/post_publish_minio.sh -m #{meeting_id}")
end
