require 'socket'
require 'ansi/code'
require '../config/environment.rb'


BBS_NAME = "Ben's Big BBS"

USERS_ONLINE = Hash.new


def get_input(socket, prompt = "", allow_return = false)
	r = nil
	while (r.blank?)
		if prompt != ""
			socket.write ANSI.blue + "[" + ANSI.red + prompt
		end
		socket.write ANSI.blue + "]" + ANSI.white + ": "
		r = socket.gets
		return "" if allow_return and r.blank?
	end
	return(r.strip)
end

def display_screen(socket, filename)
	f = File.open(File.join(Rails.root, 'bin', 'screens', filename))
	while (line = f.gets)
		socket.puts(line)
	end
	f.close
end

def display_greeting(socket)

	display_screen(socket, "welcome.ans")

 	socket.puts ANSI.white + "\n\nWelcome to " + ANSI.red + BBS_NAME + ANSI.white + "!"
    socket.puts ANSI.white + "Server time: #{Time.now.strftime('%l:%m %p %b %e, %Y').strip}\n\n"

	socket.puts ANSI.white + "Enter your username or \"new\" to register.\n\n"

	username = get_input(socket, "Username")
	if username == "new"
		new_user(socket)
	else
		user = nil
		retries = 3
		while(!user and retries > 0)
			password = get_input(socket, "Password")
			u = User.where(username: username).first
	        if u and u.valid_password?(password)
	        	user = u
	        	USERS_ONLINE[socket] = user
	        	display_main_menu(socket)
	        else
	        	display_error(socket, "Incorrect password!")
	        	retries = retries - 1
	        end			
		end
	end
end

def display_error(socket, message)
	socket.puts ANSI.white + "\n*** " + ANSI.red + message + ANSI.white + " ***\n"
end

def display_message(socket, message)
	socket.puts ANSI.white + "\n--[ " + ANSI.blue + message + ANSI.white + " ]--\n"
end

def current_user(socket)
	return USERS_ONLINE[socket]
end

def display_messages_menu(socket)

	socket.puts "\n\nMessages\n\n"

	socket.puts "N) New Message"

	socket.puts "L) List Messages (#{Message.count})"

	socket.puts "M) Main Menu"

	i = get_input(socket).downcase

	case i
	when 'n'
		display_new_message(socket)
	when 'l'
		display_list_messages(socket)
	when 'm'
		display_main_menu(socket)
	else
		display_messages_menu(socket)
	end
end

def display_new_message(socket, message = nil)
	socket.puts "\n\nNew message\n\n"
	subject = "Re: #{message.subject.gsub('Re: ', '')}"
	if message
		socket.puts "Subject: #{subject}"
	else
		subject = get_input(socket, "Subject")
	end
	body = get_input(socket, "Message")

	socket.puts "Send message? (Y/N)"
	c = get_input(socket).downcase
	if (c == 'y')
		m = Message.create(subject: subject, body: body, user_id: current_user(socket).id)
		if message
			m.message = message
			m.save
		end
		display_message(socket, "Message saved!")
	end
	display_messages_menu(socket)
end

def display_list_messages(socket, page = 0)
	messages = Message.all.order('created_at desc').limit(10).offset(page * 10)
	if messages.size > 0

		socket.puts "\nID\tDate\t\t\tUser\tSubject"
		socket.puts "--\t----\t\t\t----\t-------"
		for message in messages
			socket.puts "#{message.id}\t#{message.created_at.strftime('%l:%m %p %b %e, %Y').strip}\t#{message.user.username}\t#{message.subject}"
		end
	else
		socket.puts "No more messages!"
	end


	socket.puts "M) Messages Menu, #) Read Message, <Return> Next Page"
	i = get_input(socket, "", true).downcase

	case i
	when 'm'
		display_messages_menu(socket)
	when ''
		display_list_messages(socket, page + 1)
	else
		display_read_message(socket, i, page)
	end
end


def display_read_message(socket, id, page)
	message = Message.where(id: id).first
	if message
		socket.puts "--[ Message ##{message.id} ]--"
		socket.puts "From:\t\t#{message.user.username}"
		socket.puts "Subject:\t#{message.subject}"
		socket.puts "Date\t\t#{message.created_at.strftime('%l:%m %p %b %e, %Y')}\n"
		socket.puts message.body
		socket.puts "--"
		i = get_input(socket, "R) Reply, <Return> Continue", true)
		case i
		when 'r'
			display_new_message(socket, message)
		end
		display_list_messages(socket, page)
	else
		display_error(socket, "Message ID not found!")
		display_list_messages(socket, page)
	end
end

def display_main_menu(socket)
	user = current_user(socket)
	socket.puts "\n\nMain menu\n\nM) Messages\nG) Goodbye"
	socket.puts "User: #{user.username}" 

	i = get_input(socket).downcase

	case i
	when 'm'
		display_messages_menu(socket)
	when 'g'
		return
	else
		display_main_menu(socket)
	end
end

def new_user(socket)
	socket.puts ANSI.white + "\n\n[-- New user registration --]"

	new_user = nil
	while (new_user.blank?)
		username = get_input(socket, "Select username")
		u = User.where(username: username).first
		if u
			socket.puts ANSI.white + "That user already exists!"
		else
			new_user = User.new(username: username)
		end
	end

	password = nil
	confirm_password = nil


	while(password.blank?)
		password = get_input(socket, "Select password")
		confirm_password = get_input(socket, "Confirm password")
		if password != confirm_password
			display_error(socket, "Passwords don't match!")
			password = nil
		end
	end

	new_user.password = password
	new_user.password_confirmation = confirm_password
	new_user.email = SecureRandom.hex(10) + "@benbox.io"
	new_user.save


	USERS_ONLINE[socket] = new_user

	display_message(socket, "Welcome to #{BBS_NAME}!")

	display_main_menu(socket)



end

def display_terminated(client)
	client.puts "\n\n*** CONNECTION TERMINATED ***\n\n"
end

server = TCPServer.new 2000
loop do
  Thread.start(server.accept) do |client|
  	display_greeting(client)

  	display_terminated(client)
    client.close
  end
end