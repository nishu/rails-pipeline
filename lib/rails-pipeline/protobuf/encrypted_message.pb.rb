#!/usr/bin/env ruby
# Generated by the protocol buffer compiler. DO NOT EDIT!

require 'protocol_buffers'

module RailsPipeline
  # forward declarations
  class EncryptedMessage < ::ProtocolBuffers::Message; end

  class EncryptedMessage < ::ProtocolBuffers::Message
    set_fully_qualified_name "RailsPipeline.EncryptedMessage"

    required :string, :salt, 1
    required :string, :iv, 2
    required :string, :ciphertext, 3
    optional :string, :owner_info, 4
    optional :string, :type_info, 5
  end

end
