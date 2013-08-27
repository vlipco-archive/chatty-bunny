require 'json'
require 'aws-sdk'
# for ActiveSupport::HashWithIndifferentAccess.new
require 'active_support/hash_with_indifferent_access'

module ChattyBunny

	module RPCBase
		def self.extended(base)

			base.class_eval do

				attr_reader :environment

				def use_environment(sqs_environment)
					@environment = sqs_environment
				end

				# Domain accessors are defined on client/server slightly differently

				def base_name
					"#{environment}-#{domain}"
				end

				def sqs_client
					@sqs_client ||= AWS::SQS.new
				end

				def sqs_queue
					@sqs_queue = sqs_client.queues.create(queue_name)
				end

				def polling
					@polling ||= false
				end

				# Creates a new thread and starts polling
				def begin_polling
					@polling = true
					#puts "Starting to poll from #{queue_name} in new thread"
					t = Thread.new do 
						sqs_queue.poll do |msg|
							next process(msg)
						end
					end
					t.abort_on_exception = true
				end

				def body_to_hash(msg)
					HashWithIndifferentAccess.new JSON.parse!(msg.body)
				end
			end

		end
	
	end
	
end
