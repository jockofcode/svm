require 'io/console'
require 'thread'

class Svm::TtyConnection
  def initialize
    @input_buffer = Queue.new
    @output_buffer = Queue.new
    @running = false
  end

  def start
    @running = true
    start_input_thread
    start_output_thread
  end

  def stop
    @running = false
  end

  def write_byte(byte)
    @output_buffer << byte
  end

  def read_byte
    @input_buffer.pop
  end

  def byte_available?
    !@input_buffer.empty?
  end

  private

  def start_input_thread
    Thread.new do
      while @running
        if char = STDIN.getch
          @input_buffer << char.ord
          break if char == "\u0003" # Ctrl+C
        end
      end
    end
  end

  def start_output_thread
    Thread.new do
      while @running
        if byte = @output_buffer.pop
          print byte.chr
          STDOUT.flush
        end
      end
    end
  end
end 