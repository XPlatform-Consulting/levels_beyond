require 'logger'
require 'fileutils'

require 'levels_beyond/reach_engine/api/utilities'

class SeedFile

  attr_accessor :logger, :file_path, :prefix, :suffix, :extension

  def initialize(args = { })
    @logger = args[:logger] ||= Logger.new(STDERR)
    @file_path = args[:file_path]
    @prefix = args[:file_name_prefix] ||= ''
    @suffix = args[:file_name_suffix] ||= ''
    @extension = File.extname(@file_path)
  end

  def copy_to(destination_folder, id = nil)
    name = "#{prefix}#{id}#{suffix}#{extension}"
    _target_path = File.join(destination_folder, name)
    logger.debug { "Copying seed file: '#{file_path}' => '#{_target_path}'" }
    FileUtils.cp(file_path, _target_path)
  end

end

class FolderPopulator

  attr_accessor :logger, :seed_file_paths, :seed_files, :target_folder_path, :number_of_files_to_generate

  attr_reader :initialized

  def initialize(args = { })
    @logger = args[:logger] ||= Logger.new(STDERR)

    @seed_file_paths = args[:seed_file_path] ||= args[:seed_file_paths]
    if @seed_file_paths
      @seed_files = Dir.glob(@seed_file_paths).uniq.map { |sfp| SeedFile.new( args.merge(:file_path => sfp) ) }
      @number_of_files_to_generate = args[:number_of_files_to_generate] || 1
      @initialized = true
    else
      @initialized = false
    end

    @target_folder_path = args[:target_folder_path]
  end

  def get_seed_file(method = :first)
    seed_files.first
  end

  def populate_folder(args = { })
    return unless initialized
    _number_of_files_to_generate = args[:number_of_files_to_generate] || number_of_files_to_generate

    _target_folder_path = args[:target_folder_path] || target_folder_path
    raise ArgumentError, 'target folder path must be specified.' unless _target_folder_path

    file_counter_padding_length = _number_of_files_to_generate.to_s.length

    (1.._number_of_files_to_generate).each do |file_number|
      time_string = Time.now.strftime('%Y%m%d%H%M%S')
      file_id = "#{time_string}#{file_number.to_s.rjust(file_counter_padding_length, '0')}"
      get_seed_file.copy_to(_target_folder_path, file_id)
    end

  end

end

class WatchFolderGenerator

  #attr_accessor :watch_folder_roots, :seed_files

  attr_accessor :logger,
                :watch_folder_root_path,
                :number_of_watch_folders_to_create,
                :watch_folder_name_prefix,
                :watch_folder_counter_padding_length,
                :generated_folder_paths

  attr_accessor :seed_file_path, :file_counter_per_watch_folder, :file_name_prefix, :file_name_extension, :folder_populator

  attr_accessor :reach_engine_watch_folder_generation_enabled,
                :reach_engine,
                :watch_folder_subject

  def initialize(args = { })
    initialize_logger(args)
    initialize_folder_populator(args)
    initialize_reach_engine(args)
  end

  def initialize_logger(args = { })
    @logger = args[:logger] ||= Logger.new(STDOUT)
  end

  def initialize_folder_populator(args = { })
    @folder_populator = FolderPopulator.new(args)

    @watch_folder_root_path = args[:watch_folder_root_path]
    @watch_folder_name_prefix = args[:watch_folder_file_system_name_prefix]
    @watch_folder_name_suffix = args[:watch_folder_file_system_name_suffix]
    @number_of_watch_folders_to_create = args[:number_of_watch_folders_to_create] ||= 1
    @generated_folder_paths = [ ]
  end

  def initialize_reach_engine(args = { })
    @reach_engine_watch_folder_generation_enabled = args.fetch(:generate_reach_engine_watch_folder, true)
    return unless generate_reach_engine_watch_folder

    @watch_folder_reach_engine_name_prefix = args[:watch_folder_reach_engine_name_prefix]
    @watch_folder_reach_engine_name_suffix = args[:watch_folder_reach_engine_name_suffix]
    @watch_folder_subject = args[:watch_folder_subject]
    @watch_folder_subject.insert('[', 0) unless watch_folder_subject.start_with?('[')
    @watch_folder_subject += ']' unless watch_folder_subject.end_with?(']')

    @reach_engine = LevelsBeyond::ReachEngine::API::Utilities.new(args)
  end

  def generate_new_folder_path(watch_folder_number = 0)
    time_string = Time.now.strftime('%Y%m%d%H%M%S')
    new_folder_name = "#{watch_folder_name_prefix}#{time_string}#{watch_folder_number.to_s.rjust(watch_folder_counter_padding_length, '0')}"
    new_folder_path = File.join(watch_folder_root_path, new_folder_name)
    new_folder_path
  end

  # Triggers the creation of a folder on the file system
  #
  # Note: If no :new_folder_path is provided then a folder path will be generated using (#generate_new_folder_path)
  #
  # @param [Hash] args
  # @option args [String] :new_folder_path
  # @option args [Integer|String] :watch_folder_number
  # @return [String|<String>] The response from FileUtils.mkdir_p
  def generate_new_file_system_folder(args = { })
    new_folder_path = args[:new_folder_path] || generate_new_folder_path(args[:watch_folder_number])
    logger.debug { "Generating New File System Folder: '#{new_folder_path}'" }
    FileUtils.mkdir_p(new_folder_path)
  end

  # Triggers the creation of the catch folder in Reach Engine
  #
  # @param [Hash] args
  # @option args [String] :watch_folder_subject
  def generate_reach_engine_watch_folder(args = { })
    return unless reach_engine_watch_folder_generation_enabled

    watch_folder_path = args[:watch_folder_path]
    watch_folder_name = args[:watch_folder_name] ||= File.dirname(watch_folder_path).split('/').last

    reach_engine.create_watch_folder_and_ingest_assets_into_collection(args.merge(:name => watch_folder_name, :watch_folder => watch_folder_path, :subject => watch_folder_subject).merge(args))
  end

  def run
    @watch_folder_counter_padding_length = number_of_watch_folders_to_create.to_s.length

    (1..number_of_watch_folders_to_create).each do |watch_folder_number|
      new_folder_path = generate_new_file_system_folder(:watch_folder_number => watch_folder_number)
      if new_folder_path
        generated_folder_paths << new_folder_path

        # generate reach engine watch folder
        generate_reach_engine_watch_folder(:watch_folder_path => new_folder_path)

        folder_populator.populate_folder(:target_folder_path => new_folder_path)
      end
    end
  end

  # def self.run(args = { })
  #   seed_file_path = args.fetch(:seed_file_path, '/assets/test.mov')
  #
  #   if seed_file_path
  #     file_name_prefix = args[:file_name_prefix] ||= ''
  #     file_name_extension = File.extname(seed_file_path)
  #     file_count_per_watch_folder = 10
  #   end
  #
  #   watch_folder_root = args[:watch_folder_root] ||= '/assets/test/watch_folder'
  #
  #
  #   watch_folder_count = 10
  #   watch_folder_prefix = ''
  #
  #   file_counter_padding_length = file_count_per_watch_folder.to_s.length
  #   watch_folder_counter_padding_length = watch_folder_count.to_s.length
  #
  #   (1..watch_folder_count).each do |counter|
  #
  #     time_string = Time.now.strftime('%Y%m%d%H%M%S')
  #     new_folder_name = "#{watch_folder_prefix}#{time_string}#{counter.to_s.rjust(watch_folder_counter_padding_length, '0')}"
  #     new_folder_path = File.join(watch_folder_root, new_folder_name)
  #
  #     FileUtils.mkdir_p(new_folder_path)
  #
  #     if seed_file_path
  #       (1..file_count_per_watch_folder).each do |counter|
  #         target_file_name = "#{file_name_prefix}#{time_string}#{counter.to_s.rjust(file_counter_padding_length, '0')}#{file_name_extension}"
  #         target_file_path = File.join(new_folder_path, target_file_name)
  #         File.copy(seed_file_path, target_file_path)
  #       end if file_count_per_watch_folder
  #     end
  #
  #   end
  #
  # end

end
