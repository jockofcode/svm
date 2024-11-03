require 'socket'

class Svm::SocketTtyConnection
  TELNET_COMMANDS = {
    WILL: 251,
    WONT: 252,
    DO: 253,
    DONT: 254,
    IAC: 255,
    ECHO: 1,
    SGA: 3
  }

  def initialize(port = 4567)
    @port = port
    @input_buffer = Queue.new
    @output_buffer = Queue.new
    @running = false
    @clients = []
    @threads = []
  end

  def start
    @running = true
    start_server
    start_output_thread
  end

  def stop
    @running = false
    @server&.close
    @clients.each(&:close)
    @threads.each(&:kill)
    @threads.clear
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

  def start_server
    @server = TCPServer.new(@port)
    server_thread = Thread.new do
      while @running
        begin
          client = @server.accept
          handle_client(client) if @running
        rescue IOError, Errno::EBADF
          break unless @running
        end
      end
    end
    @threads << server_thread
  end

  def handle_client(client)
    @clients << client
    negotiate_telnet(client)
    
    # Only create client thread if we're still running
    return unless @running
    
    client_thread = Thread.new do
      while @running
        begin
          data = client.readpartial(1024)
          data.bytes.each do |byte|
            next if byte == TELNET_COMMANDS[:IAC]
            @input_buffer << byte
          end
        rescue EOFError, IOError
          break
        end
      end
    end
    @threads << client_thread
  rescue ThreadError
    # If we can't create a thread, clean up the client
    @clients.delete(client)
    client.close
  end

  def negotiate_telnet(client)
    # Tell client we WILL ECHO and WILL SGA (Suppress Go Ahead)
    client.write([
      TELNET_COMMANDS[:IAC], TELNET_COMMANDS[:WILL], TELNET_COMMANDS[:ECHO],
      TELNET_COMMANDS[:IAC], TELNET_COMMANDS[:WILL], TELNET_COMMANDS[:SGA]
    ].pack('C*'))
  end

  def start_output_thread
    output_thread = Thread.new do
      while @running
        begin
          byte = @output_buffer.pop(true) # non-blocking pop
          @clients.each do |client|
            begin
              client.write(byte.chr)
              client.flush
            rescue IOError
              @clients.delete(client)
              client.close
            end
          end
        rescue ThreadError
          # Queue is empty, sleep briefly
          sleep 0.1
        end
      end
    end
    @threads << output_thread
  end
end 