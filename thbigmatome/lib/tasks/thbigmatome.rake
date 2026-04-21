namespace :thbigmatome do
  desc "Export shared player master data for Clubhouse"
  task :export_players, [:output_dir] => :environment do |_, args|
    exporter = SharedPlayersExporter.new(args[:output_dir])
    results = exporter.call

    puts "[thbigmatome:export_players] output_dir=#{exporter.output_dir}"
    results.each do |resource, count|
      puts "[thbigmatome:export_players] #{resource}=#{count}"
    end
  end
end
