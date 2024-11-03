require 'spec_helper'
require 'svm/socket_tty_connection'

RSpec.describe Svm::SocketTtyConnection do
  let(:tty) { described_class.new }
  let(:test_port) { 4567 }
  let(:mock_client) { double('TCPSocket') }
  let(:mock_server) { double('TCPServer', accept: mock_client, close: nil) }

  before(:each) do
    allow(TCPServer).to receive(:new).and_return(mock_server)
    allow(mock_client).to receive(:write)
    allow(mock_client).to receive(:close)
    allow(mock_client).to receive(:flush)
    @read_queue = Queue.new
    allow(mock_client).to receive(:readpartial) do
      @read_queue.pop
    end
  end

  after(:each) do
    tty.stop if tty.instance_variable_get(:@running)
    sleep 0.1 # Allow threads to clean up
  end

  describe 'initialization' do
    it 'initializes with default port' do
      expect(tty.instance_variable_get(:@port)).to eq(test_port)
    end

    it 'initializes with empty buffers' do
      expect(tty.instance_variable_get(:@input_buffer)).to be_empty
      expect(tty.instance_variable_get(:@output_buffer)).to be_empty
    end
  end

  describe 'client handling' do
    it 'negotiates telnet on client connection' do
      expect(mock_client).to receive(:write) do |data|
        bytes = data.unpack('C*')
        expect(bytes).to include(
          Svm::SocketTtyConnection::TELNET_COMMANDS[:IAC],
          Svm::SocketTtyConnection::TELNET_COMMANDS[:WILL],
          Svm::SocketTtyConnection::TELNET_COMMANDS[:ECHO]
        )
      end

      tty.start
      sleep 0.1 # Allow server thread to process
      tty.stop
    end

    it 'handles client input' do
      tty.start
      sleep 0.1 # Allow server thread to process
      
      # Simulate client sending data
      @read_queue << "test"
      sleep 0.1 # Allow processing
      
      # Verify the data was processed
      expect(tty.byte_available?).to be true
      expect(tty.read_byte).to eq('t'.ord)
      tty.stop
    end
  end

  describe 'data handling' do
    it 'buffers output bytes' do
      tty.write_byte(65) # ASCII 'A'
      expect(tty.instance_variable_get(:@output_buffer).size).to eq(1)
    end

    it 'reports byte availability correctly' do
      expect(tty.byte_available?).to be false
      tty.instance_variable_get(:@input_buffer) << 65
      expect(tty.byte_available?).to be true
    end

    it 'reads bytes in order' do
      input_buffer = tty.instance_variable_get(:@input_buffer)
      input_buffer << 65 << 66 << 67 # ASCII 'A', 'B', 'C'
      
      expect(tty.read_byte).to eq(65)
      expect(tty.read_byte).to eq(66)
      expect(tty.read_byte).to eq(67)
    end
  end

  describe 'cleanup' do
    let(:mock_server) { double('TCPServer', close: nil) }
    let(:mock_client) { double('TCPSocket', close: nil) }

    before do
      allow(TCPServer).to receive(:new).and_return(mock_server)
      tty.instance_variable_set(:@server, mock_server)
      tty.instance_variable_set(:@clients, [mock_client])
    end

    it 'closes server and clients on stop' do
      expect(mock_server).to receive(:close)
      expect(mock_client).to receive(:close)
      tty.stop
    end
  end
end 