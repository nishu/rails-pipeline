
require 'spec_helper'
require 'pipeline_helper'

describe RailsPipeline::Subscriber do
  before do
    @test_emitter = TestEmitter.new({foo: "bar"}, without_protection: true)

    @test_message = @test_emitter.create_message("2_0", false)
    @subscriber = TestSubscriber.new
  end

  it "should handle correct messages" do
    expect(@subscriber).to receive(:handle_payload).once
    @subscriber.handle_envelope(@test_message)
  end

  it "should raise exception on malformed messages" do
    @test_message = RailsPipeline::EncryptedMessage.new(salt: "jhkjehd", iv: "khdkjehdkejhdkjehdkjhed")
    expect(@subscriber).not_to receive(:handle_payload)
    expect{@subscriber.handle_envelope(@test_message)}.to raise_error
  end


  context "with decrypted payload" do
    before do
      @payload_str = @subscriber.class.decrypt(@test_message)
      clazz = Object.const_get(@test_message.type_info)
      @payload = clazz.parse(@payload_str)
    end

    it "should get the version right" do
      expect(@payload.class.name).to eq "TestEmitter_2_0"
      version = @subscriber._version(@payload)
      expect(version).to eq "2_0"
    end

    context "with registered target class" do
      before do
        RailsPipeline::Subscriber.register(TestEmitter_2_0, TestModel)
      end

      it "should map to the right target" do
        expect(@subscriber.target_class(@payload)).to eq TestModel
      end

      it "should instantiate a target" do
        expect(TestModel).to receive(:new).once.and_call_original
        allow_any_instance_of(TestModel).to receive(:save!)
        target = @subscriber.handle_payload(@payload)
        expect(target.foo).to eq @payload.foo
      end
    end

    context "with a registered target Proc" do
      before do
        @called = false
        RailsPipeline::Subscriber.register(TestEmitter_2_0, Proc.new {
          @called = true
        })
      end

      it "should map to the right target" do
        expect(@subscriber.target_class(@payload).is_a?(Proc)).to eq true
      end

      it "should run the proc" do
        @subscriber.handle_payload(@payload)
        expect(@called).to eq true
      end
    end


    context "without registered target" do
      before do
        RailsPipeline::Subscriber.register(TestEmitter_2_0, nil)
      end

      it "should not instantiate a target" do
        @subscriber.handle_payload(@payload)
      end
    end
  end

end
