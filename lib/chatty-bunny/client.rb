module ChattyBunny
	
	# send messages and expects a reply
	class Client
		class << self

			extend RPCBase

			attr_reader :domain

			attr_reader :responses

			def responses
				@responses ||= HashWithIndifferentAccess.new
			end

			def use_domain(dom)
				@domain = dom
			end

			def queue_name
				"#{base_name}-client-#{numeric_id}"
			end


			def server_queue_name
				"#{base_name}-server"
			end

			def server_queue
				@server_queue ||= sqs_client.queues.create server_queue_name
			end

			def rpc_methods(*methods)
				methods.each do |m|
					self.define_singleton_method m.to_sym, Proc.new {|*args| rpc_call __method__, args }
				end
			end

			def rpc_call(method, args)
				msg = {destination: queue_name, params: args, method: method}
				#puts "Client - #{self}: Requesting #{method} from #{server_queue_name} (#{msg})"
				request = server_queue.send_message msg.to_json
				# block until timeout
				max_time = Time.now.to_i + 5
				response = nil 
				while Time.now.to_i < max_time
					if responses[request.id]
						response = responses[request.id][:message]
						responses.delete request.id
						break
					end
				end
				response
			end

			private

			# Called when a new message arrives (response from a server)
			def process(msg)
				body = body_to_hash msg
				ref = body[:reference]
				responses[ref] = body
				#puts "RESPONSES UPDATED:"
				#puts responses
				#puts "ARRIVED: #{msg.body}"
			end

			# Have a random ID to enable concurrent processes with the same behavior
			attr_writer :numeric_id

			def numeric_id
				@numeric_id ||= rand.to_s[2..6]
			end
		end
	end

end