require 'spec_helper'

# Bring up all stackstorm services
#
shared_examples 'start st2 services' do
  before(:context) do
    puts '===> Starting st2 services...'
    remote_start_services(spec[:service_list])

    puts "===> Wait for st2 services to start #{spec[:wait_for_start]} sec..."
    sleep spec[:wait_for_start]
  end
end

# Share example showing remote logs of failed st2 services
#
shared_examples 'show service log on failure' do
  before(:context) { @failed_services = [] }

  after(:each, prompt_on_failure: true) do |example|
    @failed_services << example if example.exception
  end

  after(:all) do
    unless @failed_services.empty?
      puts '===> Showing output from log files of the failed services'
      @failed_services.each do |example|
        service = example.metadata[:described_class]
        lines_num = spec[:loglines_to_show]

        unless service.is_a? Serverspec::Type::Service
          fail 'Serverspec service is required to be described class!'
        end

        output = remote_grab_service_logs(service.name, lines_num)
        unless output.empty?
          puts "\nlast #{lines_num} lines from log file of service " \
               "#{service.name}"
          puts '>>>', output
        end
      end
    end
  end
end

# Main services check up
#
describe 'st2 services check' do
  include_examples 'start st2 services'
  include_examples 'show service log on failure'

  context 'external' do
    # buggy buggy netcat and serverspec!
    describe host(ENV['RABBITMQHOST']) do
      it { is_expected.to be_reachable }
      # the next is buggy :(, thus disabled
      # it { is_expected.to be_reachable.with(port: 5672) }
    end

    describe host(ENV['MONGODBHOST']) do
      it { is_expected.to be_reachable }
      # it { is_expected.to be_reachable.with(port: 27_017) }
    end
  end

  spec[:service_list].each do |name|
    describe service(name), prompt_on_failure: true do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end
end
