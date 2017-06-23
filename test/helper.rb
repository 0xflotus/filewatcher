# frozen_string_literal: true

require 'bacon'
begin
  require 'pry-byebug'
rescue LoadError
  nil
end

class WatchRun
  TMP_DIR = File.join(__dir__, 'tmp')

  attr_reader :filewatcher, :thread, :watched, :processed

  def initialize(
    filename: File.join(TMP_DIR, 'tmp_file.txt'),
    directory: false,
    filewatcher: Filewatcher.new(File.join(TMP_DIR, '**', '*')),
    action: :update,
    interval: 0.1
  )
    @filename = filename
    @directory = directory
    @filewatcher = filewatcher
    @action = action
    @filewatcher.interval = @interval = interval
  end

  def start
    File.write(@filename, 'content1') unless @action == :create

    @thread = thread_initialize
    sleep @interval * 2 # thread needs a chance to start
  end

  def run
    start

    make_changes
    sleep @interval * 2 # thread needs a chance to catch changes

    stop
  end

  def stop
    FileUtils.rm_r(@filename) if File.exist?(@filename)
    @thread.exit
  end

  private

  def thread_initialize
    @watched ||= 0
    Thread.new(
      @filewatcher, @processed = []
    ) do |filewatcher, processed|
      filewatcher.watch do |changes|
        increment_watched
        processed.concat(changes.keys)
      end
    end
  end

  def increment_watched
    @watched += 1
  end

  def make_changes
    return FileUtils.remove(@filename) if @action == :delete
    return FileUtils.mkdir_p(@filename) if @directory
    File.write(@filename, 'content2')
  end
end

class ShellWatchRun
  EXECUTABLE = File.join(__dir__, '..', 'bin', 'filewatcher')

  attr_reader :output

  def initialize(
    options: '',
    printing: '',
    output: File.join(WatchRun::TMP_DIR, 'env')
  )
    @options = options
    @printing = printing
    @output = output
  end

  def start
    @pid = spawn(
      "#{EXECUTABLE} #{@options} '#{WatchRun::TMP_DIR}/foo*'" \
      " 'printf \"#{@printing}\" > #{@output}'"
    )
    Process.detach(@pid)
    sleep 4
  end

  def run
    start

    make_changes

    stop
  end

  def stop
    Process.kill('HUP', @pid)
  end

  private

  def make_changes
    FileUtils.touch "#{WatchRun::TMP_DIR}/foo.txt"
    sleep 2
  end
end

def include_all_files(elements)
  ->(it) { elements.all? { |element| it.include? File.expand_path(element) } }
end