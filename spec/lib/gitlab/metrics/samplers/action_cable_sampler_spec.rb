# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Metrics::Samplers::ActionCableSampler do
  let(:action_cable) { instance_double(ActionCable::Server::Base) }

  subject { described_class.new(action_cable: action_cable) }

  describe '#interval' do
    it 'samples every five seconds by default' do
      expect(subject.interval).to eq(5)
    end

    it 'samples at other intervals if requested' do
      expect(described_class.new(11).interval).to eq(11)
    end
  end

  describe '#sample' do
    let(:pool) { instance_double(Concurrent::ThreadPoolExecutor) }

    before do
      allow(action_cable).to receive_message_chain(:worker_pool, :executor).and_return(pool)
      allow(action_cable).to receive(:connections).and_return([])
      allow(pool).to receive(:min_length).and_return(1)
      allow(pool).to receive(:max_length).and_return(2)
      allow(pool).to receive(:length).and_return(3)
      allow(pool).to receive(:largest_length).and_return(4)
      allow(pool).to receive(:completed_task_count).and_return(5)
      allow(pool).to receive(:queue_length).and_return(6)
    end

    shared_examples 'collects metrics' do |expected_labels|
      it 'includes active connections' do
        expect(subject.metrics[:active_connections]).to receive(:set).with(expected_labels, 0)

        subject.sample
      end

      it 'includes minimum worker pool size' do
        expect(subject.metrics[:pool_min_size]).to receive(:set).with(expected_labels, 1)

        subject.sample
      end

      it 'includes maximum worker pool size' do
        expect(subject.metrics[:pool_max_size]).to receive(:set).with(expected_labels, 2)

        subject.sample
      end

      it 'includes current worker pool size' do
        expect(subject.metrics[:pool_current_size]).to receive(:set).with(expected_labels, 3)

        subject.sample
      end

      it 'includes largest worker pool size' do
        expect(subject.metrics[:pool_largest_size]).to receive(:set).with(expected_labels, 4)

        subject.sample
      end

      it 'includes worker pool completed task count' do
        expect(subject.metrics[:pool_completed_tasks]).to receive(:set).with(expected_labels, 5)

        subject.sample
      end

      it 'includes worker pool pending task count' do
        expect(subject.metrics[:pool_pending_tasks]).to receive(:set).with(expected_labels, 6)

        subject.sample
      end
    end

    context 'for in-app mode' do
      before do
        expect(Gitlab::ActionCable::Config).to receive(:in_app?).and_return(true)
      end

      it_behaves_like 'collects metrics', server_mode: 'in-app'
    end

    context 'for standalone mode' do
      before do
        expect(Gitlab::ActionCable::Config).to receive(:in_app?).and_return(false)
      end

      it_behaves_like 'collects metrics', server_mode: 'standalone'
    end
  end
end
