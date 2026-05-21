def run_shared_players_export(output_dir, label)
  exporter = SharedPlayersExporter.new(output_dir)
  results = exporter.call

  puts "[#{label}] output_dir=#{exporter.output_dir}"
  results.each do |resource, count|
    puts "[#{label}] #{resource}=#{count}"
  end
end

namespace :export_for_clubhouse do
  desc "Export shared player master CSV files for Clubhouse"
  task :players, [:output_dir] => :environment do |_, args|
    run_shared_players_export(args[:output_dir], "export_for_clubhouse:players")
  end
end

desc "Export shared player master CSV files for Clubhouse"
task :export_for_clubhouse, [:output_dir] => :environment do |_, args|
  run_shared_players_export(args[:output_dir], "export_for_clubhouse")
end
