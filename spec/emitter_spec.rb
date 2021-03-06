require 'spec_helper'

require_relative 'pipeline_helper'


describe RailsPipeline::Emitter do
  before do
    @test_emitter = TestEmitter.new({foo: "bar"}, without_protection: true)
    @test_model = TestModelWithTable.new
    @default_emitter = DefaultEmitter.new({foo: "baz"}, without_protection: true)
    TestModelWithTable.pipeline_method_cache = {}
    TestEmitter.pipeline_method_cache = {}
    DefaultEmitter.pipeline_method_cache = {}
  end

  it "should derive the topic name" do
    TestEmitter.topic_name.should eql "harrys-#{Rails.env}-v1-test_emitters"
    TestEmitter.topic_name("2_1").should eql "harrys-#{Rails.env}-v2-test_emitters"
    TestEmitter.topic_name("2").should eql "harrys-#{Rails.env}-v2-test_emitters"
  end

  it "should detect all pipeline versions in class" do
    pipeline_versions = TestEmitter.pipeline_versions
    pipeline_versions.length.should eql 2
    pipeline_versions.should include "1_1"
    pipeline_versions.should include "2_0"

    DefaultEmitter.pipeline_versions.length.should eql 1
    DefaultEmitter.pipeline_versions.should eql ["1_0"]
  end

  context "with only default version" do
    it "should produce all attributes" do
      data = @default_emitter.to_pipeline_1_0
      expect(data.foo).to eq("baz")
      expect(data.class).to eq(DefaultEmitter_1_0)
    end

    it "should emit one version" do
      @default_emitter.should_receive(:publish).once
      @default_emitter.emit
    end

    it "should encrypt the payload" do
      DefaultEmitter.should_receive(:encrypt).once { |data|
        obj = DefaultEmitter_1_0.parse(data)
        expect(obj.foo).to eq "baz"
      }.and_call_original
      @default_emitter.should_receive(:publish).once
      @default_emitter.emit
    end

    it "should have the correct encrypted payload" do
      DefaultEmitter.should_receive(:encrypt).once.and_call_original
      # Just verify that the right encrypted data gets sent to publish
      @default_emitter.should_receive(:publish).once do |topic, serialized_message|
        topic.should eql "harrys-#{Rails.env}-v1-default_emitters"
        message = RailsPipeline::EncryptedMessage.parse(serialized_message)
        expect(message.type_info).to eq(DefaultEmitter_1_0.to_s)

        plaintext = DefaultEmitter.decrypt(message)
        obj = DefaultEmitter_1_0.parse(plaintext)
        expect(obj.foo).to eq("baz")
      end
      @default_emitter.emit
    end
  end

  context "with defined version" do
    it "should produce expected version when called explicitly" do
      data = @test_emitter.to_pipeline_1_1
      data.foo.should eql "bar"
      data.extrah.should eql "hi"
    end

    it "should emit multiple versions" do
      @test_emitter.should_receive(:publish).twice
      @test_emitter.emit
    end
  end

  context 'event type' do
    context 'created' do
      it "sets event type correctly in enveloppe" do
        @test_model.should_receive(:publish).once do |topic, serialized_message|
          topic.should eq("harrys-#{Rails.env}-v1-test_model_with_tables")
          message = RailsPipeline::EncryptedMessage.parse(serialized_message)
          expect(message.event_type).to eq(RailsPipeline::EncryptedMessage::EventType::CREATED)
        end
        @test_model.save!
      end
    end

    context 'updated' do
      it "sets event type correctly in enveloppe" do
        @test_model.save!
        expect(@test_model).to receive(:publish).once do |topic, serialized_message|
          expect(topic).to eq("harrys-#{Rails.env}-v1-test_model_with_tables")
          message = RailsPipeline::EncryptedMessage.parse(serialized_message)
          expect(message.event_type).to eq(RailsPipeline::EncryptedMessage::EventType::UPDATED)
        end
        @test_model.save!
      end
    end

    context 'deleted' do
      it "sets event type correctly in enveloppe" do
        @test_model.save!
        expect(@test_model).to receive(:publish).once do |topic, serialized_message|
          expect(topic).to eq("harrys-#{Rails.env}-v1-test_model_with_tables")
          message = RailsPipeline::EncryptedMessage.parse(serialized_message)
          expect(message.event_type).to eq(RailsPipeline::EncryptedMessage::EventType::DELETED)
        end
        @test_model.destroy
      end
    end
  end

  context 'methods cache' do
    context 'empty cache' do
      before { @test_model.save! }
      it 'caches the pipeline versions' do
        TestModelWithTable.pipeline_method_cache[RailsPipeline::PipelineVersion.new('1_1')].should eq(:to_pipeline_1_1)
      end
    end

    context 'non empty cache' do

      before do
        # warms the cache
        TestModelWithTable.pipeline_versions
      end
      it "reads from cache" do
        version = RailsPipeline::PipelineVersion.new('1_1')
        TestModelWithTable.should_not_receive(:instance_methods)
        # TestModelWithTable.pipeline_method_cache.should_receive(:[]).with(version).once.and_call_original
        @test_model.save!
      end
    end
  end
end
