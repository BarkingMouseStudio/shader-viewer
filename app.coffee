### REQUIRES ###
connect = require 'connect'
compiler = require "#{__dirname}/lib/compiler"
fs = require 'fs'
http = require 'http'
io = require 'socket.io'
path = require 'path'
prompt = require 'prompt'
watch = require 'watch'
_ = require 'underscore'


### CONSTANTS ###
FOLDERS = [ 'fragments', 'images', 'models', 'vertexs' ]


### HELPER FUNCTIONS ###
parseArgs = (args) ->
  args = args[2..]
  options = {}
  i = 0
  while i < args.length
    options[args[i++]] = args[i++]
  return options

parsePath = (filePath) ->
  segments = filePath.split('/')
  file = segments.pop()
  type = segments.pop()
  return [file, type]


### OPTIONS ###
options = parseArgs(process.argv)
directory = path.resolve(process.cwd(), options['--dir'])
port = options['--port'] or 3000


### SETUP SERVER ###
app = connect()
app.use(compiler(src: "#{__dirname}/src", dest: "#{__dirname}/public", enable: ['coffeescript', 'less'])) # looks for coffee and sass files to compile
app.use(connect.logger(format: '[:date] [:response-time] [:status] [:method] [:url]'))
app.use(connect.bodyParser()) # pre-parses JSON body responses
app.use(connect.static("#{__dirname}/public"))
app.use(connect.static(directory))

server = http.createServer(app)
server.listen port, ->
  console.log "Server at http://localhost:#{port}"


### START MONITORING ###
io = io.listen(server)
io.set('log level', 1)

io.sockets.on 'connection', (socket) ->

  # Read a file and send it's contents to the client
  emit = (event, file) ->
    [name, type] = parsePath file
    
    return unless name.indexOf('.') isnt 0 and type in FOLDERS
    
    socket.emit "file:#{event}", {name: name, type: type}
      
  # Loop through existing files and send to the client
  emitFiles = (folder) ->
    fs.readdir "#{directory}/#{folder}", (err,files) ->
      for file in files
        # send the full path "#{directory}/#{folder}/#{file}"
        emit 'created', "#{directory}/#{folder}/#{file}"

  # readdir isn't recursive so we need to loop through the folders
  emitFiles folder for folder in FOLDERS
  
  # Monitor for new files and changes to existing files
  watch.createMonitor directory, (monitor) ->
    monitor.on 'created', (f, stat) ->
      console.log "created #{f}"
      emit 'created', f
    monitor.on 'changed', (f, curr, prev) ->
      console.log "changed #{f}"
      emit 'changed', f
    monitor.on 'removed', (f, stat) ->
      console.log "removed #{f}"
      emit 'removed', f


### CREATE FOLDERS ###
fs.readdir directory, (err,files) ->
  # Return if we don't have any missing any folders
  return if _.intersection(FOLDERS, files).length is FOLDERS.length

  # Ask if we want to add missing folders
  prompt.message = 'Question'
  prompt.start()

  question =
    name: 'folders'
    message: 'Auto-create required sub-folders? yes/no'
    validator: /y[es]*|n[o]?/
    warning: 'Really? It\'s just a yes or no question...'
    default: 'yes'

  # Make any directories that don't exist
  prompt.get question, (err, result) ->
    if result.folders is 'yes'
      for type in FOLDERS
        fs.mkdir "#{directory}/#{type}" unless _.contains(files, type)