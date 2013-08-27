require 'active_support/core_ext/hash'
module ChattyBunny
	# receives messages and gives a reply
	class Server
		class << self
			extend RPCBase

			# Since all servers can reply to any request, there's no
			# random component name in the queue & the name equals the base + role
			# e.g: staging-auth-api-server
			def queue_name
				"#{base_name}-server"
			end

			attr_reader :domain
			# Once this method has run it's block, polling begins
			def define_domain(name, &block)
				@domain = name
				self.instance_eval &block
				begin_polling
			end

			# register the handler for a specific method
			def on_method(method_name, &block)
				self.class.define_method method_name.to_sym, block
			end
			
			private

			# send back the id to the target_queue
			def reply(msg, destination, ref)
				#puts "Replying to #{destination} regarding #{ref}"
				response = { 	:reference => ref, 
								:code => 200, 
								:message => msg }
				sqs_client.queues.create(destination).send_message response.to_json
			end

			# Checks that a msg has destination, method and params
			def validate(body_hash)
				body_hash[:params] && body_hash[:method] && body_hash[:destination]
			end

			# Called by the polling thread
			def process(msg)
				begin
					#puts "Server #{self}: Received #{msg.id} #{msg.body}"
					body = body_to_hash msg
					if validate(body)
						result = self.send body[:method].to_sym, body[:params], msg
						reply result, body[:destination], msg.id
						#puts "RESULT: #{result}"
					else
						raise "Invalid message for ChattyBunny, check that method, destionation and params are set."
					end
				rescue => e
					puts "\nUnexpected exception - #{e}"
					puts "Message body was: #{msg.body}"
					puts "Ignoring message & deleting\n"
				ensure
					# Return true or the polling block will close
					return true
				end
			end

		end		
	end
end