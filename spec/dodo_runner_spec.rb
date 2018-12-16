# frozen_string_literal: true

require 'rspec'
require 'active_support/core_ext/numeric/time'

RSpec.describe Dodo::Runner do
  let(:live) { false }
  let(:daemonise) { false }
  let(:progress) do
    progress = double
    allow(progress).to receive(:+).and_return(progress)
    progress
  end
  let(:opts) { { live: live, daemonise: daemonise, progress: progress } }
  let(:n) { 5 }
  let(:block) { proc { true } }
  let(:offsets) { Array.new(5) { start + rand(10.days) } }
  let(:moments) do
    offsets.map do |offset|
      Dodo::ContextualMoment.new(Dodo::Moment.new(&block), offset, context)
    end
  end
  let(:window) do
    window = Dodo::Window.new(3.weeks) {}
    moments.each { |moment| window << moment }
    window
  end
  let(:start) { 2.weeks.ago }
  let(:context) { Dodo::Context.new }
  let(:runner) { described_class.new opts }

  describe '#initialize' do
    subject { runner }
    context 'without any opts' do
      let(:runner) { described_class.new }
      it 'should initialise successfully' do
        subject
      end
    end
    context 'with opts' do
      it 'should initialise successfully' do
        subject
      end
    end
  end
  describe '#live?' do
    subject { runner.live? }
    context 'when initialised without any opts' do
      let(:runner) { described_class.new }
      it 'should return false' do
        expect(subject).to be false
      end
    end
    context 'with opts' do
      it 'should return the value of the opt provided' do
        expect(subject).to be live
      end
    end
  end
  describe '#daemonise?' do
    subject { runner.daemonise? }
    context 'when initialised without any opts' do
      let(:runner) { described_class.new }
      it 'should return false' do
        expect(subject).to be false
      end
    end
    context 'with opts' do
      it 'should return the value of the opt provided' do
        expect(subject).to be daemonise
      end
    end
  end
  describe '#call' do
    before do
      allow(window).to receive(:enum).and_return moments
    end

    subject { runner.call window, start, context, opts }

    context 'with a context provided' do

      it 'should invoke window.enum with start' do
        expect(window).to receive(:enum).with(start, context, opts)
        subject
      end
      it 'should evaluate each moment within context' do
        moments.map do |moment|
          expect(moment).to receive(:evaluate).ordered
        end
        subject
      end
      it 'should update the progress each time it calls a moment' do
        expect(progress).to receive(:+).exactly(moments.size).times
        subject
      end
      context 'with daemonize = false' do
        it 'does not run as a daemon' do
          expect(Process).not_to receive(:daemon)
          subject
        end
      end
      context 'with daemonise = true' do
        let(:daemonise) { true }
        it 'runs as a daemon' do
          expect(Process).to receive(:daemon).with no_args
          subject
        end
      end
    end
    context 'without any context provided' do
      let(:context) { nil }
      it 'should complete successfully having created a new context' do
        subject
      end
    end
    context 'with live = true' do
      let(:live) { true }

      before { Timecop.freeze }
      after { Timecop.return }

      context 'with instant being some point in the future' do
        let(:start) { 1.minute.from_now }
        before do
          allow(runner).to receive(:sleep)
        end

        it 'should sleep until moment.offset' do
          moments.each do |moment|
            expect(runner).to receive(:sleep).with(moment.offset - Time.now).ordered
          end
          subject
        end
      end
      context 'with instant being some point in the past' do
        it 'should not sleep' do
          expect(runner).not_to receive :sleep
        end
      end
    end
    context 'with live = false' do
      context 'with instant being some point in the past' do
        it 'should not sleep' do
          expect(runner).not_to receive :sleep
        end
      end
    end
  end
end
